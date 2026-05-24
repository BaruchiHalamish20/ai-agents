# tzevaadom-alerts-suite

Bundles the TzevaAdom (community-source) alert workflow as a single plugin.

---

## Overview

`tzevaadom-alerts-suite` is the **community-source counterpart** to `pikud-alerts-suite`. Same intent — fetch Israeli rocket/siren alert data, summarize it, write a Markdown report — but a different upstream: the open `api.tzevaadom.co.il` API instead of the official `oref.org.il` endpoints. The two plugins are deliberately independent so students can compare them side by side and observe that *the trigger model is orthogonal to the data source*.

The skill (`/tzevaadom-report`) runs **inline** in the calling session so every tool call is visible in the conversation; the agent (`tzevaadom-alerts`) runs in an isolated context and returns a six-line summary. Both write reports to `reports/tzevaadom/` (note the subdirectory — keeps community-source reports separate from the official Pikud HaOref reports under `reports/`).

---

## Plugin contents

- **Agent** `agents/tzevaadom-alerts.md` — fetches data from `api.tzevaadom.co.il`, writes a Markdown report under `reports/tzevaadom/`. Tools restricted to `WebFetch, Read, Write, Glob`. Requires the calling Claude to pass `current time is YYYY-MM-DD HH:MM IDT` in the prompt — the agent has no clock of its own.
- **Skill** `skills/tzevaadom-report/SKILL.md` — `/tzevaadom-report [hours] [city] [--debug]`. Inline equivalent of the agent: applies a `last_n_hours` window, optional Hebrew substring filter on the cities array, writes a bilingual Markdown report. `--debug` appends a full `## Debug log` capturing every URL, every HTTP status, and all filter counts.
- **`SessionStart` hook** `hooks/inject-tzevaadom-summary.sh` — injects the most recent TzevaAdom report's summary into the new session's context, so Claude knows the latest community-source alert state without re-fetching.

The lessons that built each piece live in `../lessons/01-custom-agent.md`, `02-skills.md`, `03-hooks-and-schedules.md`, and `04-plugins.md`.

---

## Testing the plugin

**Hook (no Claude required):**

```bash
tzevaadom-alerts-suite/hooks/inject-tzevaadom-summary.sh ; echo "exit=$?"
# expect: prints the latest reports/tzevaadom/*.md summary, exit=0
# (silent if no report exists yet — that's a valid state)
```

**Skill inside Claude Code:**

```
/tzevaadom-report 6
```

Should fetch the last 6 hours of TzevaAdom alerts and write a new report under `reports/tzevaadom/YYYY-MM-DD-HHMM.md`. Re-run with `--debug` to see every `WebFetch` URL, every HTTP status, and the parse decisions.

**Agent invocation (model-triggered):**

Ask Claude something like *"give me a tzevaadom alert report for the last 12 hours filtered to שניר"*. Claude should dispatch the `tzevaadom-alerts` agent after first capturing the Israel local time. Verify a new file appears under `reports/tzevaadom/`.
