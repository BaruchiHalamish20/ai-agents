# Lesson 5 — Plugin patterns: when only the task changes

> **Goal:** Build a third plugin on a *completely different domain*
> (PDF/HTML → Markdown conversion) and feel how the same trilogy
> pattern — agent + skill + hook — keeps working without you having
> to re-think the architecture. By the end of this lesson you should
> believe that **the trilogy is the unit of work**, and that adding a
> new workflow to a Claude Code project is a 30–45 minute exercise
> once the muscle memory exists.
>
> **Time:** ~30 minutes if you follow the established naming and
> layout from lessons 3–4; ~60 minutes if you deviate.
> **You will touch:** a new top-level folder
> `markdown-suite/`, two new top-level folders
> `converted-pdf-files/` and `converted-md-files/`, the
> root marketplace at `.claude-plugin/marketplace.json`, and
> `.claude/settings.json`'s `enabledPlugins` map. No new CLI
> ceremony.
>
> **Source of truth:**
> - Plugins — <https://code.claude.com/docs/en/plugins.md>
> - Sub-agent dispatch from a skill —
>   <https://code.claude.com/docs/en/sub-agents.md>

---

## 1. Concept — the trilogy is the unit, not the alerts

Lessons 1–3 built one workflow: Pikud HaOref alerts.
Lesson 4 cloned it: TzevaAdom alerts on the same trilogy shape.
Lesson 5 clones it again on a totally different task.

The point of doing it a third time is to make a different kind of
proof. Lesson 4's reveal was that *the data source is orthogonal*.
This lesson's reveal is **the task is orthogonal too**. Alerts vs.
document conversion are completely different problem domains — yet
the plugin shape, the trigger model, and the orchestration patterns
do not change at all.

### Architectural symmetry across the three plugins

| Layer            | `pikud-alerts-suite`           | `tzevaadom-alerts-suite`              | `markdown-suite`                            |
|------------------|--------------------------------|---------------------------------------|-------------------------------------------------------|
| Agent            | `pikud-alerts.md`              | `tzevaadom-alerts.md`                 | `markdown-converter.md`                                |
| Skill            | `/alert-report`                | `/tzevaadom-report`                   | `/convert-to-md`                                       |
| Hook event       | SessionStart                   | SessionStart                          | SessionStart                                           |
| Hook script      | `inject-latest-alert-summary.sh` | `inject-tzevaadom-summary.sh`       | `inject-conversion-queue.sh`                           |
| Output medium    | `reports/*.md`                 | `reports/tzevaadom/*.md`              | `converted-md-files/**/*.md`                       |
| Cloud routine    | `pikud-monthly-digest`         | `tzevaadom-monthly-digest`            | *(none — task is human-triggered, not time-triggered)* |

Three different problems. One architecture. Three plugins.

### One new pattern this lesson introduces

Up to now, the agent and the skill were **parallel entry points** —
either one could do the job, the only difference was context
isolation (agent = clean sub-agent context, skill = inline in the
calling conversation). For the markdown converter we use a different
relationship:

| Plugin              | Agent role                    | Skill role                                                  |
|---------------------|-------------------------------|-------------------------------------------------------------|
| pikud / tzevaadom   | Background worker (alt UX)    | Inline worker (alt UX)                                      |
| markdown-converter  | **Single-file worker**        | **Batch orchestrator** — dispatches the agent per file      |

The skill enumerates the queue, decides what needs conversion, and
**dispatches the agent once per file**. Each per-file conversion runs
in its own isolated sub-agent context, so converting a 200-page PDF
does not pollute the orchestrator's context with the document's full
text. The skill sees only the agent's short summary line per file.

This is the **orchestrator + worker** pattern, and it's the natural
shape any time the batch unit is too big to fit in a single context
without crowding everything else out.

---

## 2. Spec — the markdown-suite contract

**Inputs:** Source files dropped under `converted-pdf-files/`.
Supported extensions: `.pdf`, `.html`, `.htm` (case-insensitive).
Nested directories allowed.

**Outputs:** A `.md` file under `converted-md-files/` for each
source, preserving the relative path and replacing the extension.

```
converted-pdf-files/foo.pdf                       → converted-md-files/foo.md
converted-pdf-files/papers/2026/intro.html        → converted-md-files/papers/2026/intro.md
converted-pdf-files/A Tale Of Two.HTM             → converted-md-files/A Tale Of Two.md
```

**Out of scope (v1):**
- Image extraction. Embedded images become inline descriptions
  (`> **[Figure N: …]**`), not saved files.
- Non-PDF/HTML formats (Word, RTF, EPUB). Add later if needed.
- A cloud routine. Conversion is human-triggered — you drop a file,
  you decide when to process. Adding a `FileChanged` hook to
  auto-convert is a sensible stretch goal but not v1.
- Idempotency across machine times. We compare `mtime` only; if you
  `touch` a source without editing, the converter will redo the
  conversion. That's correct behavior for this design.

**Success criteria:**
- `/convert-to-md` with no args processes every pending file under
  `converted-pdf-files/` and writes a corresponding `.md`.
- `/convert-to-md --list` prints the queue without converting.
- A fresh session opens with Claude already knowing how many files
  are pending in the conversion queue, without you asking.
- Per-file failures do not abort the batch — the next file proceeds
  and the failure is reported inline.

---

## 3. Plan — design decisions

| Decision                                | Choice                                                | Why                                                                                                          |
|-----------------------------------------|-------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Plugin name                             | `markdown-suite`                            | Parallel to `pikud-alerts-suite`, `tzevaadom-alerts-suite`. Identical naming pattern teaches the symmetry.   |
| Source folder                           | `converted-pdf-files/`                            | Verb-y name signals "queue".                                                                                  |
| Destination folder                      | `converted-md-files/`                             | Past-participle name signals "done".                                                                          |
| Conversion engine                       | LLM-based (Read + Write)                              | Self-contained, no binary install (no pandoc). Quality matters more than fidelity for our use case.          |
| Subdirectory handling                   | 1:1 mapping, preserve nesting                         | Predictable. Lets you mirror a real document library.                                                         |
| Images                                  | Inline descriptions (`> **[Figure N: …]**`)           | No filesystem side-effects for image files. Extraction is a stretch goal.                                    |
| Overwrite policy                        | Re-convert if source mtime > dest mtime; else skip    | Cheap incremental runs. Lets you re-run the skill at any time without re-doing finished work.                |
| Skill default behavior (no args)        | Convert all pending                                   | Batch by default. The `--list` flag covers the dry-run case.                                                  |
| Agent dispatch                          | One agent invocation per file (orchestrator + worker) | Isolates per-file context. Lets the orchestrator handle 100 files without ballooning its own context window. |
| Per-file failure handling               | Continue the batch, report inline                     | One bad source should not block 99 good ones.                                                                |
| Hook behavior                           | Report queue status at SessionStart                   | Surfaces the existence of pending work without taking action. Honest scope.                                  |
| Cloud routine                           | None                                                  | Task is human-triggered. Time-triggered conversion is the wrong abstraction here.                            |

---

## 4. Tasks — hands-on

These are terse. By lesson 5 the moves should be familiar.

### Task 1 — Scaffold the plugin

```
markdown-suite/
├── .claude-plugin/
├── agents/
├── hooks/
└── skills/convert-to-md/
```

### Task 2 — Manifest

`markdown-suite/.claude-plugin/plugin.json` — same shape as
the other two plugins. Keywords: `markdown`, `converter`, `pdf`,
`html`, `documents`. Version `1.0.0`.

### Task 3 — Agent

`markdown-suite/agents/markdown-converter.md`.

Key contract points:
- Input parameters: `source_path` (required), `debug` (optional).
- Computes `dest_path` from `source_path` deterministically (swap
  prefix, swap extension).
- Tools: `Read`, `Write`, `Glob` only. No Bash, no WebFetch.
- Hard rule: never writes outside `converted-md-files/`.
- Hard rule: never modifies anything under
  `converted-pdf-files/` — sources are read-only.
- Inline image descriptions; no extraction.

Also write a stub `markdown-converter.NOTES.md` for future
overrides, mirroring the other plugins' NOTES files.

### Task 4 — Skill

`markdown-suite/skills/convert-to-md/SKILL.md`.

Key contract points:
- Argument: `[pattern] [--list] [--debug]`.
- Argument-name reminder: `pattern`, not `region`/`city` — every
  plugin gets to pick the name that fits its data.
- Allowed tools: `Read, Write, Glob, Bash, Agent`. `Bash` is needed
  for `stat` to read mtimes; `Agent` is what lets the skill dispatch
  the per-file worker.
- Mtime helper:
  ```bash
  mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
  }
  ```
  This is the cross-platform incantation. GNU `stat -c %Y` is the
  Linux + Git Bash on Windows path; BSD `stat -f %m` is the macOS
  path; the `echo 0` fallback prevents arithmetic errors on
  exotic environments.
- Dispatch deterministically (alphabetical by source path).
- Per-file failures do not abort the batch.

### Task 5 — Hook script

`markdown-suite/hooks/inject-conversion-queue.sh`.

Mirrors the structure of the other two SessionStart hooks. The body
that differs:
- Enumerates `converted-pdf-files/` with `find … -iname "*.pdf"
  -o -iname "*.html" -o -iname "*.htm"`.
- For each source, checks whether the matching `.md` exists in
  `converted-md-files/` and is at least as new as the source.
- Builds a "queue" payload string with the pending files.
- Returns it as `additionalContext` with the same "do not auto-act"
  guidance as the other hooks.

`hooks.json` is one line of pointing-and-shooting:
`"command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-conversion-queue.sh"`.

### Task 6 — Wire the plugin into the marketplace

Update `.claude-plugin/marketplace.json` at the repo root: add a
third entry under `plugins`:

```json
{
  "name": "markdown-suite",
  "source": "./markdown-suite",
  "description": "PDF/HTML to Markdown batch converter — agent (single-file worker) + skill (batch orchestrator) + SessionStart hook (conversion queue status)."
}
```

Update `.claude/settings.json`'s `enabledPlugins`:

```json
"markdown-suite@ai-agents-local": true
```

No new CLI commands. Next time you start Claude Code in this
project, the plugin loads.

### Task 7 — Smoke-test locally

Drop a small PDF or HTML file into `converted-pdf-files/`.
Restart Claude Code, look for the queue line in the SessionStart
context (the hook should announce one pending file). Then run:

```
/convert-to-md --list
```

You should see the file in the queue. Then run:

```
/convert-to-md --debug
```

You should see one agent dispatch, one `.md` file appear in
`converted-md-files/`, and a one-line summary from the agent.

Verify:
- The output `.md` mirrors the source's structure (headings,
  lists, tables converted; images as `> **[Figure …]**`
  descriptions).
- Re-running `/convert-to-md` immediately produces "0 pending,
  1 up-to-date" — the mtime guard is working.
- `touch converted-pdf-files/<the-file>` (or saving the source
  again) followed by `/convert-to-md` re-converts the file.

---

## 5. Verification checklist

- [ ] `markdown-suite/.claude-plugin/plugin.json` parses
      as valid JSON with non-empty `name`, `version`, `description`.
- [ ] `markdown-suite/agents/markdown-converter.md` has
      the required frontmatter and refuses to write outside
      `converted-md-files/`.
- [ ] `markdown-suite/skills/convert-to-md/SKILL.md` is
      callable as `/convert-to-md` from a fresh Claude Code session.
- [ ] `markdown-suite/hooks/hooks.json` points at
      `${CLAUDE_PLUGIN_ROOT}/hooks/inject-conversion-queue.sh`.
- [ ] `markdown-suite/hooks/inject-conversion-queue.sh`
      is executable, returns valid JSON on stdout, and appends a
      line containing `inject-conversion-queue fired` to
      `.claude/hooks/.audit.log` on every session start.
- [ ] `.claude-plugin/marketplace.json` lists three plugins:
      pikud-alerts-suite, tzevaadom-alerts-suite,
      markdown-suite.
- [ ] `.claude/settings.json`'s `enabledPlugins` has all three
      entries set to `true`.
- [ ] A fresh session opens with Claude aware of: the pikud alert
      summary, the tzevaadom alert summary, AND the conversion
      queue status. Three independent hooks, three independent
      injections.
- [ ] `/convert-to-md` with no args processes every pending file
      and writes corresponding `.md` files.
- [ ] `/convert-to-md --list` produces the queue without writing
      anything.
- [ ] Re-running `/convert-to-md` on a finished queue reports
      "0 pending".

---

## 6. Stretch (optional)

Pick one before declaring the lesson done:

1. **Image extraction.** Extend the agent to extract embedded images
   to `converted-md-files/<relpath>/_assets/figure-N.<ext>` and
   reference them with proper Markdown image syntax. Notice how this
   changes the agent's contract (now writes multiple files per
   source) but does not change the skill or the hook.
2. **`FileChanged` hook for auto-conversion.** Add a hook on the
   `FileChanged` event with a matcher for paths under
   `converted-pdf-files/`. The hook triggers `/convert-to-md`
   for the specific file that changed. Reflect on whether this is
   actually better than the explicit-trigger UX. (It usually isn't —
   surprise side effects on file save are unpleasant.)
3. **Pandoc fallback.** When a `.pdf` is over N pages or a `.html`
   contains complex tables that the LLM struggles with, shell out to
   `pandoc` if it's installed. Notice that adding `Bash` to the
   agent's tools is the one-line change; everything else is the same
   agent.
4. **Cloud routine for periodic re-conversion.** If you want, add a
   nightly routine that re-converts everything (or only stale
   files). Decide whether this is value-add or just compute waste.
5. **Fourth plugin in 20 minutes.** Pick any small task — translate
   files between languages, extract `TODO` comments to a report,
   generate test stubs for source files — and build a fourth plugin
   following the same pattern. Time yourself. If it took longer than
   30 minutes, ask which step slowed you down. The pattern is
   supposed to be muscle memory now.

---

## What you should now believe

- **The trilogy is the unit of work.** Agent + skill + hook +
  (optional) routine — that's a workflow. Adding a workflow to a
  project means building another instance of that shape, not
  inventing a new shape.
- **The task is orthogonal to the architecture.** Lesson 4 proved
  this for the *data source* (different upstream, same orchestration).
  Lesson 5 proved it for the *task* (different domain entirely, same
  orchestration). The architecture pays off precisely because it
  doesn't care what you're orchestrating.
- **Orchestrator + worker is the pattern for batch.** When the
  per-unit work is too big to live in one context, split the skill
  (batch enumerator) from the agent (per-unit worker). This
  generalizes to any batch task — translation, code review, test
  generation, document summarization. Same shape.
- **Three plugins in one repo is normal.** A `.claude-plugin/marketplace.json`
  at the root plus `enabledPlugins` in `.claude/settings.json` is
  enough to make them all auto-load. Teammates cloning the repo get
  the same set with one trust prompt. No copy-paste, no per-file
  registration.
- **Some plugins need no routine.** Pikud and TzevaAdom are
  time-triggered (the data changes whether you ask or not).
  Document conversion is *event-triggered* — you drop a file, you
  ask for it. Forcing a cron schedule on a human-triggered task is
  an anti-pattern. **The right number of triggers per plugin is the
  number that match the task.**
- **By lesson 5, building a workflow is a checklist exercise.** That
  is the win the architecture buys you. The first plugin took a
  week. The third takes half an hour. The next dozen are all the
  same effort.

You now have three working plugins, two cloud routines, three
SessionStart hooks, and a registered local marketplace. From here
the lessons branch into operational concerns — observability,
governance, distribution — none of which add a new core pattern.
You've collected the full set.
