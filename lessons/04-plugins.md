# Lesson 4 — Plugins: ship the workflow as one unit

> **Goal:** Take the three artifacts from lessons 1–3 — the `pikud-alerts`
> agent, the `/alert-report` skill, the `SessionStart` hook — and wrap
> them in a single Claude Code **plugin** called `pikud-alerts-suite`.
> By the end you can load the whole bundle with one CLI flag, version
> it, and hand it to a teammate. As a bonus, the agent-cache trap from
> lesson 1 (manual edit doesn't reload mid-session) disappears: plugin
> agents are live-reloaded by `/reload-plugins`.
>
> **Time:** ~50 minutes.
> **You will touch:** a new folder at the repo root (`pikud-alerts-suite/`),
> copies of the agent / skill / hook from `.claude/`, and the existing
> `.claude/settings.json` (to remove the standalone hook entry once the
> plugin's version takes over).
>
> **Source of truth:**
> - Plugins overview — <https://code.claude.com/docs/en/plugins.md>
> - Plugins reference — <https://code.claude.com/docs/en/plugins-reference.md>
> - Marketplaces (stretch) — <https://code.claude.com/docs/en/plugin-marketplaces.md>

---

## 1. Concept — what is a plugin, and why now?

A plugin is **one folder** containing a manifest plus any combination of
skills, agents, hooks, MCP servers, LSP servers, monitors, default
settings, and binaries. The exact same folder can be loaded three ways:

- `claude --plugin-dir ./my-plugin` for local development
- `claude --plugin-url https://.../my-plugin.zip` for a one-off remote load
- `/plugin install my-plugin@my-marketplace` for distribution

Lessons 1–3 lived in `.claude/` — that's the "standalone" path. It's
ideal for one project. A plugin is the **same building blocks wrapped
in a manifest** with a name that namespaces everything inside.

### Standalone vs plugin — when to convert

| Approach     | Invocation                          | Best for                                                              |
|--------------|-------------------------------------|-----------------------------------------------------------------------|
| Standalone   | `/alert-report`                     | Personal, one project, quick experiments                              |
| Plugin       | `/pikud-alerts-suite:alert-report`  | Sharing, versioning, multi-project reuse, distributable releases      |

The pivot moment is when you want to **share** or **version**. Lessons
1–3 produced artifacts that work on your machine. Lesson 4 is the
"ship it" lesson.

### Three things change when you wrap as a plugin

1. **Namespacing.** `/alert-report` becomes `/pikud-alerts-suite:alert-report`.
   Slightly more typing; total conflict resistance. Same applies to the
   agent — it surfaces in `/agents` as `pikud-alerts-suite:pikud-alerts`.
2. **Hook location.** The `hooks` block you put in `.claude/settings.json`
   in lesson 3 moves into `hooks/hooks.json` inside the plugin folder.
   **Same JSON shape**, different file, with one canonical change: script
   paths use `${CLAUDE_PLUGIN_ROOT}` so they resolve no matter where the
   plugin is installed.
3. **Reload semantics.** The cache rule from lesson 1 — *"manual edits to
   `.claude/agents/<name>.md` don't reload until session restart"* — is a
   standalone-only constraint. Once the agent file lives inside a plugin,
   `/reload-plugins` re-registers it without a restart. Worth a moment
   of disbelief: it's the same agent file.

### What a plugin can contain (one row per directory)

| Directory          | Holds                                                            | We'll use it?           |
|--------------------|------------------------------------------------------------------|-------------------------|
| `.claude-plugin/`  | `plugin.json` manifest                                           | ✅                      |
| `skills/`          | Skills as `<name>/SKILL.md`                                      | ✅ (`alert-report`)     |
| `agents/`          | Sub-agent Markdown files                                         | ✅ (`pikud-alerts`)     |
| `hooks/`           | `hooks.json` (same shape as `.claude/settings.json`)             | ✅ (SessionStart)       |
| `commands/`        | Flat-file legacy skills                                          | ❌ — `skills/` is current |
| `.mcp.json`        | External MCP servers                                             | ❌                      |
| `.lsp.json`        | Language servers                                                 | ❌                      |
| `monitors/`        | Background watchers                                              | ❌                      |
| `bin/`             | Executables added to the Bash tool's `PATH`                      | ❌                      |
| `settings.json`    | Default settings (only `agent` and `subagentStatusLine` accepted) | ❌                      |
| `output-styles/`   | Output style definitions                                         | ❌                      |
| `themes/`          | Color themes                                                     | ❌                      |

We use three of the twelve. The plugin will be small, self-contained,
and easy to debug — exactly the shape worth handing to a teammate.

### A gotcha to state up front (the #1 plugin bug)

> **Common mistake:** Don't put `agents/`, `skills/`, `hooks/`, or
> `commands/` inside `.claude-plugin/`. **Only `plugin.json` goes inside
> `.claude-plugin/`.** All other directories live at the plugin root.

If your plugin loads but components are missing, this is the first
thing to check.

### One restriction on plugin-shipped agents

The reference docs are explicit: plugin agents support `name`,
`description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`,
`skills`, `memory`, `background`, and `isolation` in their frontmatter.
**For security, `hooks`, `mcpServers`, and `permissionMode` are not
supported** for plugin-shipped agents — they can be set only on
standalone agents in `.claude/agents/`. The `pikud-alerts` agent uses
none of these, so the migration is safe; just know the rule before
you ship a different agent.

---

## 2. Spec — what we're building

**Name:** `pikud-alerts-suite`.

**Layout target:**

```text
pikud-alerts-suite/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── pikud-alerts.md            # copy of .claude/agents/pikud-alerts.md
│   └── pikud-alerts.NOTES.md      # documentation sidecar, not loaded
├── skills/
│   └── alert-report/
│       └── SKILL.md               # copy of .claude/skills/alert-report/SKILL.md
└── hooks/
    ├── hooks.json
    └── inject-latest-alert-summary.sh
```

**Outputs after install:**

- Skill `/pikud-alerts-suite:alert-report` (same args / `--debug` flag as before).
- Agent visible in `/agents` as `pikud-alerts-suite:pikud-alerts`,
  invokable conversationally with the same `pikud-alerts` name as before.
- `SessionStart` hook fires from the plugin every new session.
- Audit log moves from `.claude/hooks/.audit.log` to
  `${CLAUDE_PLUGIN_DATA}/audit.log` — the canonical persistent location
  for plugin state.

**Out of scope (v1):**

- Publishing to a marketplace (covered in the stretch section and the
  next lesson).
- Modifying agent / skill / hook *logic* — this lesson is repackaging,
  not refactoring.
- MCP / LSP / monitors / binaries / themes.

**Success criteria:**

- `claude --plugin-dir ./pikud-alerts-suite` boots Claude Code with the
  suite loaded; `--debug` output lists all three components registered.
- `/pikud-alerts-suite:alert-report 24` produces the same bilingual report
  the old `/alert-report 24` did.
- A new session opens with the latest report summary injected, without
  prompting — confirming the hook is firing from the plugin.
- Editing `pikud-alerts-suite/agents/pikud-alerts.md` and running
  `/reload-plugins` picks up the change without a session restart.
  (Compare to lesson 1, where this required a full restart.)
- The original files under `.claude/` can be deleted; the plugin
  versions take over cleanly.

---

## 3. Plan — design decisions

| Decision                              | Choice                                          | Why                                                                                                          |
|---------------------------------------|-------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Plugin name                           | `pikud-alerts-suite`                            | Bundles agent + skill + hook; "suite" signals plural artifacts.                                              |
| Plugin location                       | `./pikud-alerts-suite/` (repo root)             | Adjacent to `.claude/`; tracked by git; clean separation from standalone artifacts.                          |
| Versioning                            | Explicit `version: "1.0.0"`                     | Pinned semver beats commit-SHA churn — every push isn't a "release". Bump when you ship.                     |
| Skill namespace                       | Inherited from `name`                           | `/pikud-alerts-suite:alert-report`. Verbose, but conflict-proof.                                             |
| Agent migration                       | Copy, then delete original                      | Symlinks across `.claude/` and the plugin folder confuse discovery; two copies guarantee drift.              |
| Hook script path                      | `${CLAUDE_PLUGIN_ROOT}/hooks/inject-...sh`      | Canonical placeholder. Absolute-resolved at runtime no matter where the plugin is installed.                  |
| Audit log location                    | `${CLAUDE_PLUGIN_DATA}/audit.log`               | Survives plugin updates (unlike `${CLAUDE_PLUGIN_ROOT}` which is overwritten on update).                     |
| Keep standalone `.claude/` artifacts? | **No**, delete after verifying plugin works     | Avoids drift; plugin is the single source of truth.                                                          |
| Load method                           | `--plugin-dir ./pikud-alerts-suite`             | No marketplace required for local dev; documented as the canonical local-test path.                          |

---

## 4. Tasks — hands-on

### Task 1 — Scaffold the plugin folder

```bash
mkdir -p pikud-alerts-suite/.claude-plugin
mkdir -p pikud-alerts-suite/agents
mkdir -p pikud-alerts-suite/skills/alert-report
mkdir -p pikud-alerts-suite/hooks
```

Critical: only `plugin.json` goes inside `.claude-plugin/`. Every
component directory is at the plugin root.

### Task 2 — Write the manifest

Create `pikud-alerts-suite/.claude-plugin/plugin.json`:

```json
{
  "name": "pikud-alerts-suite",
  "description": "Pikud HaOref alert workflow — agent, skill, and SessionStart hook bundled. Fetches Israeli Home Front Command alerts and produces bilingual Markdown reports under reports/.",
  "version": "1.0.0",
  "author": {
    "name": "Baruchi Halamish"
  },
  "homepage": "https://github.com/<your-org>/ai-agents",
  "repository": "https://github.com/<your-org>/ai-agents",
  "license": "MIT",
  "keywords": ["pikud-haoref", "alerts", "israel", "monitoring"]
}
```

Field-by-field worth pausing on:

- **`name`** doubles as the namespace prefix for every component. Pick
  it once, pick it deliberately — every user invocation will type it.
- **`version`** pins the cache key. With `"1.0.0"` set, users get
  updates only when you bump it. Omit it and Claude Code uses the git
  commit SHA, so every commit is treated as an update — fine while
  iterating, noisy once others depend on you. Per the reference:
  > "If you set `version` in `plugin.json`, you must bump it every
  > time you want users to receive changes. Pushing new commits alone
  > is not enough."
- **`description`** is what users see in the plugin manager and `/plugin`
  UI. First impression — keep it specific.

### Task 3 — Migrate the skill

Copy the existing skill verbatim:

```bash
cp .claude/skills/alert-report/SKILL.md \
   pikud-alerts-suite/skills/alert-report/SKILL.md
```

No content changes. The skill's argument parsing, region filter,
`--debug` flag, and bilingual output rules are all preserved. After
load, invoke as:

```
/pikud-alerts-suite:alert-report 48 חוף --debug
```

Same semantics as the old `/alert-report 48 חוף --debug`, just
namespaced.

### Task 4 — Migrate the agent

Copy the agent and its NOTES sidecar:

```bash
cp .claude/agents/pikud-alerts.md       pikud-alerts-suite/agents/pikud-alerts.md
cp .claude/agents/pikud-alerts.NOTES.md pikud-alerts-suite/agents/pikud-alerts.NOTES.md
```

Two things worth knowing:

- The NOTES file's filename (`pikud-alerts.NOTES.md`) doesn't match the
  `<name>.md` pattern, so Claude Code's plugin agent loader ignores it
  — same behavior as in the standalone case. It travels with the agent
  as documentation.
- After loading, the agent appears in `/agents` as
  `pikud-alerts-suite:pikud-alerts`. The conversational invocation name
  is still `pikud-alerts` (the agent's frontmatter `name` field) — no
  user-facing change to the `Use the pikud-alerts agent...` prompt.

Sanity-check the agent's frontmatter does **not** declare any of:
`hooks`, `mcpServers`, `permissionMode`. Those three are forbidden for
plugin-shipped agents. The current `pikud-alerts` agent uses none of
them, so you're safe — but if you later add one of those to a
standalone agent and forget to remove it before packaging, plugin load
will fail.

### Task 5 — Migrate the hook script

Copy the script:

```bash
cp .claude/hooks/inject-latest-alert-summary.sh \
   pikud-alerts-suite/hooks/inject-latest-alert-summary.sh
chmod +x pikud-alerts-suite/hooks/inject-latest-alert-summary.sh
```

Then make one small edit at the top of the script: move the audit log
from a fixed project-relative path to the plugin's persistent data
directory. Replace the `echo ... >> .claude/hooks/.audit.log` line with:

```bash
mkdir -p "${CLAUDE_PLUGIN_DATA:-.}"
echo "$(date -Iseconds) inject-latest-alert-summary fired" \
  >> "${CLAUDE_PLUGIN_DATA:-.}/audit.log"
```

Why `${CLAUDE_PLUGIN_DATA}` instead of `${CLAUDE_PLUGIN_ROOT}`?

> *"`${CLAUDE_PLUGIN_ROOT}` changes when the plugin updates... do not
> write state here. `${CLAUDE_PLUGIN_DATA}` is a persistent directory
> for plugin state that survives updates."*

The audit log is exactly the kind of state that should outlive a
version bump. Using `${CLAUDE_PLUGIN_DATA}` makes the plugin upgrade-safe
on day one.

The `:-.` fallback handles `--plugin-dir` development mode, where
`CLAUDE_PLUGIN_DATA` may not be set — the script writes to cwd as a
graceful degradation instead of crashing.

### Task 6 — Register the hook in `hooks.json`

Create `pikud-alerts-suite/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-latest-alert-summary.sh"
          }
        ]
      }
    ]
  }
}
```

Note: this is **the same JSON shape** as the `hooks` object in
`.claude/settings.json` from lesson 3 — only the script path changed,
to use the canonical placeholder. The plugin docs are explicit:

> *"Copy the `hooks` object from your `.claude/settings.json` or
> `settings.local.json`, since the format is the same."*

That's the entire hook migration.

### Task 7 — Load the plugin and verify

Start a fresh session with the plugin loaded:

```bash
claude --plugin-dir ./pikud-alerts-suite
```

Three quick smoke tests, in order:

1. **Skill present.** Type `/` and verify `/pikud-alerts-suite:alert-report`
   appears in the list. Run it:
   ```
   /pikud-alerts-suite:alert-report 6
   ```
   Should produce a 6-hour bilingual report under `reports/`, identical
   in shape to the lesson 2 output.

2. **Agent present.** Run `/agents` and confirm
   `pikud-alerts-suite:pikud-alerts` is listed. Trigger it
   conversationally:
   > "Use the pikud-alerts agent to write today's alert report.
   > last_n_hours = 6."

   The main Claude delegates the same way as before — the namespace
   prefix is a *UI* detail; the agent's conversational name is
   unchanged.

3. **Hook fires.** Open one more new session, then check the audit
   log:
   ```bash
   tail -n 5 ~/.claude/plugins/data/*pikud-alerts-suite*/audit.log 2>/dev/null \
     || cat ./audit.log
   ```
   You should see one ISO timestamp per session-start.

   *Note:* with `--plugin-dir` (local dev), `CLAUDE_PLUGIN_DATA` is set
   by the harness if the plugin is fully registered; if it falls back
   to the `:-.` cwd path, you'll find `audit.log` in your current
   working directory. Either is fine for the smoke test — both prove
   the hook is firing from the plugin, not from a stale standalone
   config.

### Task 8 — Prove the cache trap is gone

This is the satisfying moment. With Claude Code still running, edit
`pikud-alerts-suite/agents/pikud-alerts.md` — make any visible change
(e.g., add a sentinel sentence at the end of the system prompt). Then
in the active session:

```
/reload-plugins
```

Without restarting, the plugin re-registers. Trigger the agent
again; it now runs with the edited prompt. Compare to lesson 1: same
edit, on a standalone agent file, would have required a full session
restart.

The doc's exact words:
> *"As you make changes to your plugin, run `/reload-plugins` to pick
> up the updates without restarting. This reloads plugins, skills,
> agents, hooks, plugin MCP servers, and plugin LSP servers."*

Monitors are the one exception (need a restart) — irrelevant here, but
worth filing away.

### Task 9 — Decommission the standalone copies

Once the plugin works end-to-end, delete the originals so there's no
drift:

```bash
rm -rf .claude/agents/pikud-alerts.md
rm -rf .claude/agents/pikud-alerts.NOTES.md
rm -rf .claude/skills/alert-report
rm -rf .claude/hooks/inject-latest-alert-summary.sh
```

And remove the `SessionStart` hook entry from `.claude/settings.json`
(leaving the file with `{}` or removing the `hooks` block, depending
on what else is in there). Otherwise both versions of the hook will
fire on each session start — same script, two registrations.

Re-run the smoke tests from Task 7 to confirm everything still works
purely from the plugin.

---

## 5. Verification checklist

- [ ] `pikud-alerts-suite/.claude-plugin/plugin.json` validates as JSON
      and contains `name`, `description`, `version`.
- [ ] `agents/`, `skills/`, and `hooks/` are at the plugin **root**,
      not inside `.claude-plugin/`.
- [ ] `claude --debug --plugin-dir ./pikud-alerts-suite` boots with the
      plugin loaded and the debug log shows the skill, agent, and hook
      all registered.
- [ ] `/pikud-alerts-suite:alert-report 6` produces a report under
      `reports/` with the bilingual structure.
- [ ] `/agents` lists `pikud-alerts-suite:pikud-alerts`; conversational
      `pikud-alerts` delegation still works.
- [ ] The audit log gains a new ISO-timestamped line every new session.
- [ ] Editing an agent file inside the plugin + `/reload-plugins`
      picks up the change without a session restart.
- [ ] No duplicate `pikud-alerts` agent, `alert-report` skill, or
      `SessionStart` hook remains under `.claude/`.
- [ ] `git status` shows the new plugin folder, the removed standalone
      artifacts, and a (possibly) trimmed `.claude/settings.json`.

---

## 6. Stretch (optional)

Pick one before declaring the plugin shippable.

1. **Add a `userConfig` field for region default.** Currently the
   `region` argument defaults to "no filter". Add a `userConfig` block
   to `plugin.json` that prompts the user for `default_region` when
   they install the plugin, and have the skill fall back to it when
   `$region` is empty. Reference: `${user_config.default_region}` is
   substituted inline anywhere the placeholder appears.
2. **Add a `commands/validate-plugin.md` skill** that runs
   `claude plugin validate` against the plugin root and reports back.
   Useful as a one-keystroke sanity check before pushing.
3. **Convert the explicit version to git-SHA versioning.** Remove the
   `version` field from `plugin.json`, push a new commit, and verify
   `/plugin update` (if you've installed via a marketplace) picks up
   the change. Then revert. Notice how each model is right for a
   different lifecycle stage — git-SHA for live iteration, semver
   for shipped releases.
4. **Publish via a tiny private marketplace.** Create
   `marketplace.json` at the repo root with one entry pointing at
   `./pikud-alerts-suite/`, push the repo, and install with
   `/plugin marketplace add <repo-url>` then
   `/plugin install pikud-alerts-suite@<marketplace-name>`. The plugin
   now installs across machines without anyone copying folders. (Full
   marketplace mechanics are the topic of the next lesson — this
   stretch is a sneak preview.)
5. **Add a `PreToolUse` hook to the plugin** that blocks `Bash` commands
   matching `rm -rf reports/`. This demonstrates plugin-shipped guard
   rails: a teammate who installs your plugin inherits the safety
   policy automatically.

---

## 7. Bonus example — a second plugin for PDF → Markdown context loading

The mechanics you just used for `pikud-alerts-suite` aren't specific to
alerts. To prove the pattern generalizes, here's a totally different
plugin built in the same shape: it takes a PDF, converts it to a
Markdown sibling file, and surfaces the content in Claude's context
window in the same turn.

### Why this is a different problem

The alert plugin is about **fetching live external data on demand**.
This second plugin is about **turning offline documents into context**
— the typical RAG-prep workflow without a vector store: a paper, a
contract, an architecture doc. Same packaging mechanics, different
domain, no overlap.

Two ways content reaches the context window through a plugin:

1. **Skill output** — when the user invokes the skill, anything Claude
   produces while running the skill is naturally in the conversation,
   and therefore in the context.
2. **Hook `additionalContext`** — at a lifecycle event (session start
   etc.), inject text the model sees before its next turn. This is
   what lesson 3's `SessionStart` hook did for the alert summary.

The bonus plugin uses pattern (1). A stretch variant adds pattern (2).

### Mini-spec

**Name:** `pdf-context-loader`.

**Layout:**

```text
pdf-context-loader/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── pdf-to-md/
        └── SKILL.md
```

That's the entire plugin. No agent, no hook — one skill, one
manifest. The smallest viable plugin.

**Skill contract:**

- Invocation: `/pdf-context-loader:pdf-to-md <pdf-path> [pages]`
- Reads the PDF via Claude Code's native `Read` tool (which supports
  PDFs up to 20 pages per request, with `pages` for ranges).
- Writes the converted content as a Markdown file next to the PDF:
  `paper.pdf` → `paper.md`.
- After writing, reads the new `.md` back into the conversation so the
  text is in the context window for whatever the user wants to do
  next (summarize, ask questions, cite, translate).
- Errors cleanly on missing file, non-PDF input, or pages outside
  range — no partial write.

### Task A — Scaffold the plugin

```bash
mkdir -p pdf-context-loader/.claude-plugin
mkdir -p pdf-context-loader/skills/pdf-to-md
```

### Task B — Write the manifest

`pdf-context-loader/.claude-plugin/plugin.json`:

```json
{
  "name": "pdf-context-loader",
  "description": "Convert a PDF to a Markdown sibling file and load the content into the conversation context. Uses Claude Code's native PDF Read support — no external binaries.",
  "version": "1.0.0",
  "author": { "name": "Baruchi Halamish" },
  "license": "MIT",
  "keywords": ["pdf", "context", "markdown", "rag-prep"]
}
```

### Task C — Write the skill

`pdf-context-loader/skills/pdf-to-md/SKILL.md`:

```markdown
---
name: pdf-to-md
description: Convert a PDF to a Markdown sibling file and load the content into the conversation context.
argument-hint: "<pdf-path> [pages]"
arguments: [pdf_path, pages]
allowed-tools: Read, Write, Glob
---

# pdf-to-md — convert a PDF to context-ready Markdown

## How to run

| Invocation                              | pdf_path        | pages   | Effect                                              |
|-----------------------------------------|-----------------|---------|-----------------------------------------------------|
| `/pdf-context-loader:pdf-to-md`         | —               | —       | **Parse error** — pdf_path is required.             |
| `/pdf-context-loader:pdf-to-md a.pdf`   | `a.pdf`         | —       | Convert default page range (Read's first 10 pages). |
| `/pdf-context-loader:pdf-to-md a.pdf 1-5` | `a.pdf`       | `1-5`   | Convert pages 1–5 only.                              |
| `/pdf-context-loader:pdf-to-md a.pdf 3` | `a.pdf`         | `3`     | Convert page 3 only.                                 |

## Argument parsing

1. If `$pdf_path` is empty → abort with `pdf-to-md: pdf_path is required.` and write nothing.
2. If `$pdf_path` doesn't end in `.pdf` (case-insensitive) → abort with `pdf-to-md: expected a .pdf file, got "<value>".` and write nothing.
3. If the file does not exist at `$pdf_path` → abort with `pdf-to-md: file not found at "<value>".` and write nothing.
4. `$pages` is optional. When set, it must match the `Read` tool's `pages` syntax (`"N"`, `"N-M"`). Pass it through unchanged.

## Steps

1. Use the `Read` tool to read `$pdf_path`. If `$pages` is non-empty,
   pass it as the `pages` argument.
2. Convert the page content into clean Markdown:
   - One H1 derived from the document title (first prominent line on
     page 1) or the filename without extension if the title isn't
     obvious.
   - Preserve heading hierarchy (H2/H3) where headings are detectable.
   - Bullet lists and numbered lists preserved.
   - Tables converted to GitHub-flavored Markdown tables when feasible;
     fall back to fenced code blocks if structure is ambiguous.
   - Code blocks preserved with language hints when inferable.
   - Page-break markers as a horizontal rule (`---`) between pages.
3. Determine the output path: strip `.pdf` (case-insensitive) from
   `$pdf_path` and append `.md`. Example: `./docs/paper.pdf` →
   `./docs/paper.md`. If the output file already exists, **overwrite**
   it (this is a conversion utility, not an append).
4. Use the `Write` tool to save the Markdown to that path.
5. Use the `Read` tool to read the freshly written `.md` back. This
   step is what places the content in the conversation context — the
   user can immediately ask follow-up questions about it.
6. End with one summary line in the conversation:
   `✅ Converted <pdf_path> → <md_path> (<N> pages, <M> chars). Content loaded into context.`

## Hard rules

- **No external binaries.** Only the `Read` and `Write` tools. No
  `pdftotext`, no `pandoc`, no Python — the skill must work on any
  machine that runs Claude Code.
- **No mutation of the source PDF.** Convert-only.
- **No write on abort.** Any parse-error or precondition failure must
  return cleanly without creating a partial `.md`.
- **Overwrite is the default.** Re-running on the same PDF replaces
  the previous `.md`; don't append, don't write `paper-2.md`.
```

### Task D — Test it

Load the plugin alongside the alert suite (multiple `--plugin-dir`
flags compose):

```bash
claude --plugin-dir ./pikud-alerts-suite \
       --plugin-dir ./pdf-context-loader
```

Drop any PDF into the working directory — for example, a paper
downloaded with `curl`. Then:

```
/pdf-context-loader:pdf-to-md ./paper.pdf
```

After the skill finishes, ask a follow-up that depends on the
content being in context, e.g.:

> *"Summarize section 3 of the paper in three bullets."*

If Claude answers from the converted Markdown without re-reading the
PDF, the context-injection pattern worked. If it re-reads, step 5 of
the skill was skipped — fix the skill body.

### Three things this bonus example teaches

1. **A plugin can be a single skill.** The smallest viable plugin is a
   manifest plus one `SKILL.md`. You don't need to pack three
   components in to justify packaging — *namespacing and versioning
   are sufficient reasons*.
2. **The context window is just text in the conversation.** "Loading
   into context" sounds magical; it's literally "the skill reads the
   file and that read is in the transcript." No vector store, no
   embedding, no special API. This demystifies a chunk of the AI tooling
   landscape.
3. **Plugins compose at load time.** Two `--plugin-dir` flags, two
   namespaces, zero conflicts. The same is true at install time:
   users can have a dozen marketplaces and dozens of installed
   plugins, with all skills addressable via their unique
   `<plugin-name>:<skill-name>` prefix.

### Stretch — preload PDFs at session start

Add a `hooks/hooks.json` with a `SessionStart` hook that scans a
configurable folder (e.g., `./docs/`) for the most recently modified
`.md` file and injects its first 2 KB as `additionalContext`. Now
opening Claude Code in a project with prepped docs gives you
auto-loaded context without typing anything — the alert-suite pattern,
applied to documents.

The mechanics are identical to lesson 3's hook: shell script returning
JSON on stdout, registered in `hooks/hooks.json` with the
`${CLAUDE_PLUGIN_ROOT}` placeholder. The only thing that changes is
what the script reads.

---

## What you should now believe

- **A plugin is the same building blocks, in a folder, under a name.**
  Lessons 1–3 built three artifacts. Lesson 4 didn't invent anything
  new — it relocated those artifacts and added a manifest. The cost
  of "going plugin" is one JSON file and one `mkdir`.
- **Namespacing is the whole point of going plugin.** Once your work is
  reusable across projects and teammates, name collisions become a
  real risk. `pikud-alerts-suite:alert-report` is verbose and that's
  the feature, not a bug.
- **`${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` separate code
  from state.** `ROOT` is replaced on every update; `DATA` survives.
  This is the same code-vs-state distinction you make when deploying a
  service — config and binaries vs persistent data — applied to plugins.
- **Plugins erase the agent-cache trap.** The single rule from lesson 1
  that bit you (manual edits don't reload) was a property of
  *standalone* agents. Plugin agents are reloadable with
  `/reload-plugins`. If your team iterates often, this alone is reason
  to package even single-project artifacts as plugins.
- **Versioning is a deliberate choice, not a default.** Explicit semver
  → users see updates only when you bump. Git-SHA → users see every
  commit. Pick the one that matches the lifecycle stage you're in —
  and switch when the stage changes.
- **Distribution is a separate concern.** This lesson ended at
  `--plugin-dir`. Marketplaces, `--plugin-url` zips, and submission to
  the official Anthropic marketplace are all just *different ways to
  put the same folder in front of a user*. The folder is the artifact.

---

## Next up — Lesson 5

You now have a versioned, reloadable, namespaced plugin that runs on
one machine. The next lesson covers **plugin marketplaces** — the
mechanism that turns "one folder on my disk" into "one install
command for the team":

- `marketplace.json` structure: declaring one or more plugins in a
  single index file at the root of a git repo.
- The three source types (`github`, `url`, relative path) and when
  each is appropriate.
- Install scopes (`user`, `project`, `local`, `managed`) and how
  `--scope project` makes a plugin part of the repo contract via
  `enabledPlugins` in `.claude/settings.json`.
- The trust model for installing third-party plugins, and what changes
  when you publish to the official Anthropic marketplace vs hosting
  your own private one.

After lesson 5, you'll have done the full lifecycle: model-triggered
(agent), user-triggered (skill), system-triggered (hooks / loops /
routines), packaged (plugin), distributed (marketplace). That's the
working surface of Claude Code for an engineering organization.
