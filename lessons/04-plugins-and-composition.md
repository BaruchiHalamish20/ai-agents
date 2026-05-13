# Lesson 4 — Composition: bundling agent + skill + hook as a plugin

> **Goal:** Take the trilogy you built in lessons 1–3 (agent + skill +
> hook) and learn to **bundle and distribute** it as a self-contained
> *plugin*. Then prove the architectural lesson by building the same
> trilogy a second time, on a different data source, and noticing what
> changes and what doesn't.
>
> **Time:** ~75 minutes.
> **You will touch:** a new top-level folder `tzevaadom-alerts-suite/`
> mirroring `pikud-alerts-suite/`, the `/schedule` slash command (one
> new routine), and optionally `reports/tzevaadom/` when you check
> artifacts.
>
> **Source of truth:**
> - Plugins — <https://code.claude.com/docs/en/plugins.md>
> - Routines / `/schedule` — <https://code.claude.com/docs/en/routines.md>
> - TzevaAdom API (community-documented) — see
>   `tzevaadom-alerts-suite/skills/tzevaadom-report/SKILL.md`
>   for the verified endpoint list.

---

## 1. Concept — what a plugin is, and why two stacks teach more than one

### The four layers you've already met

| Layer    | Created in | Lives at                              |
|----------|------------|---------------------------------------|
| Agent    | Lesson 1   | `.claude/agents/<name>.md`            |
| Skill    | Lesson 2   | `.claude/skills/<name>/SKILL.md`      |
| Hook     | Lesson 3   | `.claude/settings.json` + a script    |
| Routine  | Lesson 3   | Anthropic cloud account (not in repo) |

Three of those four live in conventional in-project paths. They work
in isolation. What they don't do is *travel as a unit*. If you wanted
to share your alert workflow with a teammate or another repo, you'd
have to copy three different files from three different locations and
hope you didn't miss one.

A **plugin** is the unit that fixes this. It is a folder with a
manifest (`.claude-plugin/plugin.json`) and an opinionated layout:

```
<plugin-name>/
├── .claude-plugin/
│   └── plugin.json              ← manifest (name, version, description)
├── agents/
│   └── <agent>.md
├── hooks/
│   ├── hooks.json               ← event → handler map
│   └── <handler>.sh
└── skills/
    └── <skill>/
        └── SKILL.md
```

The contract is simple: drop the folder anywhere Claude Code looks
for plugins (a marketplace, a local directory, a git submodule) and
all three components are discovered together.

You already have one plugin in this repo: `pikud-alerts-suite/`. It's
the lesson-1-through-3 work bundled. Open it now and notice that
**there is nothing new in it** — every file you see was previously at
`.claude/<agents|skills|hooks>/`. The plugin form is a packaging
choice, not a rewrite.

### Why we now build a second plugin

The most expensive bug in lesson 3 — the cloud routine's 403 fetching
oref.org.il — was **not** a bug in your agent, skill, hook, routine,
or PR pipeline. It was a property of the data source: Pikud HaOref's
CDN blocks non-Israeli egress IPs. No amount of refactoring the
orchestration would have fixed it.

That observation is the heart of this lesson. The trigger model
(routine), the report writer (skill), the context injector (hook),
and the PR pipeline are all **orthogonal to the data source**. If you
swap the data source — same trigger, same hook, same PR flow, same
report shape, different upstream — the bug goes away and nothing else
changes.

We prove it by building the same trilogy on TzevaAdom (a community
alert API). The exercise is essentially "do lesson 1 + lesson 2 +
lesson 3 again, in 75 minutes this time, on a different upstream,
bundled as a plugin from the start." The point is felt, not told.

### What an honest plugin gives you (and doesn't)

Honest list of what bundling buys:

- **One folder to share.** Drop it into another repo or a plugin
  marketplace and everything ships together.
- **`${CLAUDE_PLUGIN_ROOT}` in hook scripts.** Hook commands resolve
  paths *relative to the plugin*, not the project root. This is what
  makes the plugin portable — copy it elsewhere and the hook still
  works.
- **A natural unit of independence.** Two plugins in the same repo
  can have their own agent/skill/hook without naming conflicts.
- **A natural unit of disable.** Plugins can be enabled per-routine
  via the `enabled_plugins` field — useful when a routine should run
  *one* of N plugins, not all of them.

What bundling does **not** buy:

- It does not make routines repo-resident. A routine is still in your
  claude.ai account, not in git. Two people with the same plugin do
  not automatically have the same routine schedule.
- It does not magically resolve credential or geo-block issues for
  cloud routines. Your plugin still has to work where it runs.
- It does not enforce isolation. Two plugins can write to the same
  `reports/` directory and stomp each other if you let them. Naming
  discipline (`reports/tzevaadom/` vs `reports/*.md`) is yours to
  enforce.

---

## 2. Spec — what to build (contract before code)

Following SDD: state the contract first.

**Inputs:** Nothing new — Lesson 3 left you with the Pikud HaOref
plugin bundled at `pikud-alerts-suite/` and a working monthly routine.

**Outputs:** A parallel plugin and a parallel routine.

1. **New plugin** `tzevaadom-alerts-suite/` with:
   - `.claude-plugin/plugin.json`
   - `agents/tzevaadom-alerts.md` — fetches from
     `api.tzevaadom.co.il`, no HTML parsing, writes to
     `reports/tzevaadom/`.
   - `agents/tzevaadom-alerts.NOTES.md` — empty stub for future
     overrides, mirroring `pikud-alerts.NOTES.md`.
   - `skills/tzevaadom-report/SKILL.md` — `/tzevaadom-report [hours]
     [city] [--debug]`. **Note the argument name:** `city`, not
     `region`. This is a *deliberate* difference from `/alert-report`
     because TzevaAdom's source data is per-city, not per-administrative-area.
   - `hooks/hooks.json` — SessionStart hook entry using
     `${CLAUDE_PLUGIN_ROOT}/hooks/inject-tzevaadom-summary.sh`.
   - `hooks/inject-tzevaadom-summary.sh` — reads newest
     `reports/tzevaadom/*.md` only. Does NOT look at top-level
     `reports/*.md` — that's pikud's territory. The two hooks fire
     independently at SessionStart, each injecting its own summary.

2. **New routine** `tzevaadom-monthly-digest`:
   - Cron `0 6 1 * *` — same time as `pikud-monthly-digest`.
   - 48-hour lookback window.
   - PR-to-master pattern, branch `reports/tzevaadom-auto-YYYY-MM-DD`.
   - `enabled_plugins: ["tzevaadom-alerts-suite"]` in the routine
     config (key field that scopes the cloud session to this plugin's
     content).

**Out of scope (v1):**

- WebSocket variant of TzevaAdom's live API (`wss://ws.tzevaadom.co.il/socket?platform=WEB`).
  Real-time monitoring is a different trigger model — `/loop` or a
  long-lived hook process — not a once-a-month cron.
- City i18n (`https://www.tzevaadom.co.il/static/cities.json`). The
  skill prints Hebrew city names; English transliterations are
  added only when the agent already knows them, never invented.
- Cross-referencing the two reports. Pikud and TzevaAdom sometimes
  disagree on which towns were under alert; reconciling them is a
  different (and richer) workflow that would warrant its own lesson.
- Publishing the plugin to a marketplace. The folder is correctly
  shaped for that step, but we don't push it externally here.

**Success criteria:**

- `/tzevaadom-report 48` produces a Markdown file under
  `reports/tzevaadom/` with real activity data (not "Data unavailable")
  when run locally.
- Opening a fresh Claude Code session causes Claude to reference
  *both* the latest Pikud report and the latest TzevaAdom report,
  without being asked — two independent hooks fire at SessionStart.
- The `tzevaadom-monthly-digest` routine fires once on the 1st of the
  next month, produces a report file, and opens a PR. **Critically,
  it succeeds where the Pikud routine failed**, because TzevaAdom is
  not geo-blocked.

---

## 3. Plan — design decisions and the orthogonality reveal

| Decision                          | Choice                                          | Why                                                                                              |
|-----------------------------------|-------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Plugin name                       | `tzevaadom-alerts-suite`                        | Parallel to `pikud-alerts-suite`. Reading the two folder names side by side teaches the lesson.   |
| Output path                       | `reports/tzevaadom/`                            | Subfolder isolates the two plugins' artifacts; hooks can target one without seeing the other.    |
| City filter argument              | `city`                                          | Reflects the source schema (records have a `cities[]` array). Different from pikud's `region`.   |
| Threat code → label rendering     | Embedded map in the skill                       | Self-contained. The canonical mapping lives in `amitfin/oref_alert`; we copy a subset.            |
| Time filter unit                  | Epoch seconds (UTC)                             | TzevaAdom publishes `time` as epoch UTC. Filter in epoch; convert to IDT/IST for display only.   |
| Routine cron                      | `0 6 1 * *` (1st of month, ~09:00 IDT)          | Same as pikud's monthly routine. Two reports drop within minutes — easy comparison demo.         |
| Routine model                     | `claude-haiku-4-5`                              | Same as pikud's. Cheap, fast, sufficient for a structured-JSON skill.                            |
| PR branch                         | `reports/tzevaadom-auto-YYYY-MM-DD`             | Distinct from pikud's `reports/auto-YYYY-MM-DD`. Two routines never collide on branch names.     |
| Geo-block fallback                | None                                            | TzevaAdom is on Cloudflare, no geo-block. **The probe section we added to `/alert-report` is unnecessary here** — and that absence is the point of this lesson. |

### The "swap the data source" reveal

If you put the two stacks side by side and run a diff in your head,
**everything that matters about the orchestration is identical**:

| Concern               | Pikud HaOref stack                              | TzevaAdom stack                                 |
|-----------------------|-------------------------------------------------|-------------------------------------------------|
| Trigger model         | SessionStart hook, slash skill, monthly routine | SessionStart hook, slash skill, monthly routine |
| Output medium         | Markdown file → git PR                          | Markdown file → git PR                          |
| Tools allowed         | WebFetch, Bash, Read, Write, Edit, Glob, Grep   | WebFetch, Bash, Read, Write, Edit, Glob, Grep   |
| Cron expression       | `0 6 1 * *`                                     | `0 6 1 * *`                                     |
| Report shape          | Hebrew H1, English H2s, bilingual rows          | Hebrew H1, English H2s, bilingual rows          |

What's different:

| Concern               | Pikud HaOref                                    | TzevaAdom                                       |
|-----------------------|-------------------------------------------------|-------------------------------------------------|
| Upstream URL          | `oref.org.il/WarningMessages/...`               | `api.tzevaadom.co.il/...`                       |
| Upstream format       | HTML/JSON hybrid, geo-blocked, WAF-filtered     | Pure JSON, public, Cloudflare, no geo-block     |
| Time format           | Already IDT/IST                                 | Epoch UTC                                       |
| Filter field          | Area name (Hebrew, flat string per row)         | Cities array (Hebrew, per record)               |
| Filter arg name       | `region`                                        | `city`                                          |
| Header probe needed   | Yes (added in lesson 3)                         | No                                              |

Two lists, same length. The orthogonality is not a slogan — you can
see it in the columns.

---

## 4. Tasks — hands-on

These are intentionally terse. You've done each of these moves once
already; the exercise here is doing them again on different inputs
and noticing how little context-switching it takes.

### Task 1 — Scaffold the plugin folder

Create the directory structure:

```
tzevaadom-alerts-suite/
├── .claude-plugin/
├── agents/
├── hooks/
└── skills/tzevaadom-report/
```

(The files come in the next tasks.)

### Task 2 — Write `plugin.json`

Author the manifest at `tzevaadom-alerts-suite/.claude-plugin/plugin.json`.
Mirror `pikud-alerts-suite/.claude-plugin/plugin.json`'s shape; change
the `name`, `description`, and `keywords` to reflect the TzevaAdom
source. Keep version `1.0.0`.

### Task 3 — Write the agent

Write `tzevaadom-alerts-suite/agents/tzevaadom-alerts.md`.

Key differences from `pikud-alerts.md`:
- Frontmatter `tools:` stays `WebFetch, Read, Write, Glob` — no
  `Bash` needed for this source. TzevaAdom's API does not require a
  header-probe fallback.
- Body says "writes to `reports/tzevaadom/`", not `reports/`.
- Data sources section lists `api.tzevaadom.co.il/notifications` and
  `api.tzevaadom.co.il/alerts-history/`.
- Includes the threat-code → label table inline.
- "Hard rules" section says "Never call out to non-`tzevaadom.co.il`
  endpoints" — mirroring pikud's "non-oref.org.il" rule.

Also write a stub `tzevaadom-alerts.NOTES.md` for future overrides.

### Task 4 — Write the skill

Write `tzevaadom-alerts-suite/skills/tzevaadom-report/SKILL.md`.

Key differences from `alert-report/SKILL.md`:
- Argument name: `city`, not `region`.
- Window math operates in **epoch seconds** (UTC), not local time. The
  "filter in source's native timezone" rule from `/alert-report` is
  source-specific: pikud's source publishes in IDT, TzevaAdom's
  publishes in UTC.
- City filter checks **any element** of `cities[]`. A record keeps
  if any city in the array matches the substring.
- No header-probe fallback section. TzevaAdom doesn't need it.

### Task 5 — Write the hook script and wire it

`tzevaadom-alerts-suite/hooks/inject-tzevaadom-summary.sh` mirrors
`inject-latest-alert-summary.sh` exactly, except:
- It globs `reports/tzevaadom/*.md` (not `reports/*.md`).
- Its `Instructions for Claude` payload mentions the
  `/tzevaadom-report` skill and `tzevaadom-alerts` agent (not the
  pikud counterparts).
- Its audit-log line says `inject-tzevaadom-summary fired` so you can
  tell the two hooks apart in `.claude/hooks/.audit.log`.

`tzevaadom-alerts-suite/hooks/hooks.json` declares the SessionStart
hook entry using `${CLAUDE_PLUGIN_ROOT}/hooks/inject-tzevaadom-summary.sh`.

### Task 6 — Smoke-test locally

From the project root, in a fresh Claude Code session:

```
/tzevaadom-report 48 --debug
```

Verify:

- A file appears under `reports/tzevaadom/` with a `YYYY-MM-DD-HHmm`
  timestamp.
- The `## Summary` is non-empty.
- The `## Recent activity` table contains real Hebrew city names.
- The `## Debug log` shows two successful WebFetch calls — one to
  `/notifications`, one to `/alerts-history/`.
- The `## Notes` section ends with the line
  `The alert report was generated from tzevaadom-alerts-suite plugin running on behalf of Claude Code`.

If something fails, the `## Debug log` will tell you which step. Read
it before re-running.

### Task 7 — Create the cloud routine

Run `/schedule` and create `tzevaadom-monthly-digest`:

- **Cron:** `0 6 1 * *` (same as pikud's)
- **Repo:** `https://github.com/<you>/ai-agents`
- **Model:** `claude-haiku-4-5`
- **Allowed tools:** `WebFetch, Bash, Read, Write, Edit, Glob, Grep`
- **Prompt:** instructs the cloud session to run `/tzevaadom-report 48`,
  check for content change against the most recent existing report in
  `reports/tzevaadom/`, and (if changed) commit to a branch named
  `reports/tzevaadom-auto-YYYY-MM-DD` and open a PR to master via
  `gh pr create`.
- **`enabled_plugins`** (if surfaced by `/schedule`): set to
  `["tzevaadom-alerts-suite"]` so the cloud session explicitly loads
  this plugin.

### Task 8 — Verify the routine end to end

Run the routine immediately (don't wait for the 1st of next month):

```
/schedule run tzevaadom-monthly-digest
```

Or via the API:

```bash
curl -sX POST -H "Cookie: sessionKey=$SESSION_KEY" \
  https://claude.ai/api/code/triggers/<routine-id>/run
```

Confirm:

- The run completes without 403 on the fetch step. **This is the
  payoff:** the pikud routine 403s in this same sandbox; the
  TzevaAdom routine does not. Same orchestration, different data
  source — the bug was never in your code.
- A new PR appears on GitHub under
  `reports/tzevaadom-auto-YYYY-MM-DD`.
- The PR body matches the title; the file is well-formed Markdown.

---

## 5. Verification checklist

- [ ] `tzevaadom-alerts-suite/.claude-plugin/plugin.json` parses as
      valid JSON with non-empty `name`, `version`, `description`.
- [ ] `tzevaadom-alerts-suite/agents/tzevaadom-alerts.md` has the
      required `name`, `description`, `tools`, `model` frontmatter
      and explicitly limits writes to `reports/tzevaadom/`.
- [ ] `tzevaadom-alerts-suite/skills/tzevaadom-report/SKILL.md` is
      callable as `/tzevaadom-report` from a fresh Claude Code session.
- [ ] `tzevaadom-alerts-suite/hooks/hooks.json` references
      `${CLAUDE_PLUGIN_ROOT}/hooks/inject-tzevaadom-summary.sh`.
- [ ] `tzevaadom-alerts-suite/hooks/inject-tzevaadom-summary.sh` is
      executable, returns valid JSON on stdout, and adds a line to
      `.claude/hooks/.audit.log` containing the substring
      `inject-tzevaadom-summary fired`.
- [ ] A fresh session opens with Claude already aware of *both* the
      latest Pikud HaOref report and the latest TzevaAdom report.
- [ ] `/schedule list` shows `tzevaadom-monthly-digest` with cron
      `0 6 1 * *` and `enabled: true`.
- [ ] `/schedule run tzevaadom-monthly-digest` produces a new PR on
      GitHub (branch `reports/tzevaadom-auto-<date>`).
- [ ] The PR's report file has real activity data, not "Data
      unavailable". **This is the orthogonality proof.**

---

## 6. Stretch (optional)

Pick one before declaring the lesson done:

1. **WebSocket variant.** Add a second skill, `/tzevaadom-watch`,
   that connects to `wss://ws.tzevaadom.co.il/socket?platform=WEB`,
   prints incoming alerts in real time, and exits on `Esc`. This is
   the **fourth trigger model**: an open connection. Notice how it
   doesn't fit the three from lesson 3 (model / user / system) — it
   is *event-driven* in a true push sense.
2. **Cross-source reconciliation report.** Write a third skill,
   `/alert-diff <hours>`, that reads the latest Pikud and TzevaAdom
   reports for an overlapping window and prints rows where the two
   sources disagree. The diff is itself the interesting deliverable
   — it tells you whether the two sources are seeing the same
   reality.
3. **Plugin marketplace publish.** Push `tzevaadom-alerts-suite/` to
   its own GitHub repo and install it from there into a *different*
   project. The fact that it works elsewhere with zero changes is
   the point of the plugin manifest.
4. **Disable Pikud, enable TzevaAdom on the routine.** Toggle
   `enabled` on `pikud-monthly-digest` to `false`, leave
   `tzevaadom-monthly-digest` on. Reflect on the fact that you have
   not deleted any code — only changed *which orchestration is live*
   right now. This is what the `enabled_plugins` field is for in real
   ops.

---

## What you should now believe

- **A plugin is a packaging boundary, not new behavior.** Every
  component inside a plugin you have built before. The plugin form
  exists for distribution and isolation, not capability.
- **The trigger model is orthogonal to the data source.** You proved
  this by rebuilding the same trilogy on a different upstream and
  watching the orchestration not change. The bug that ate an hour in
  lesson 3 was in the upstream, not in any of your code.
- **Two plugins can live in one repo and not collide.** Naming
  discipline (`reports/` vs `reports/tzevaadom/`) and the
  `${CLAUDE_PLUGIN_ROOT}` convention in hook scripts are what make
  this work. Plugins do not magically isolate themselves; the layout
  conventions do.
- **`enabled_plugins` is the routine-side switch.** The same way a
  hook can be on or off per session, a plugin can be on or off per
  routine. This is the unit of *operational* control once you have
  more than one workflow living in the same repo.
- **Lesson 1–3 were not the lesson — they were the setup.** The
  lesson is that those three rounds of work compose. Lesson 4 made
  the composition explicit. From here, every new workflow you build
  fits into the same shape: agent + skill + hook + routine, bundled
  as a plugin if it has more than one piece.

You now have the full Claude Code composition surface. The next
lessons (observability, governance, distribution) are operational
overlays on top of what you've built — not new primitives.
