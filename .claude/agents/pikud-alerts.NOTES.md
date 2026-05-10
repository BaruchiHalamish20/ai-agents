# pikud-alerts — local overrides log

This file is **not** loaded by Claude Code as an agent (filename does not
match `<name>.md`). It exists to document temporary, hand-applied edits to
`.claude/agents/pikud-alerts.md` so that:

1. A reviewer reading the agent file knows where to look for any active
   overrides (a one-line HTML pointer at the top of the agent body links
   here).
2. Anyone can determine *what was changed*, *where*, *why*, and
   *when to revert* — without running `git diff`.

Each override gets its own dated entry. Mark the status checkboxes as you
move through the lifecycle.

---

## 2026-05-10 — Failure injection (Lesson 1, stretch goal #3)

- **Target file:** `.claude/agents/pikud-alerts.md`
- **Section:** "Data sources (try in this order)" → bullet 1 ("Live alerts JSON")
- **Approximate line:** 58 (search for `**Live alerts JSON:**`)

**Before:**
```markdown
1. **Live alerts JSON:** `https://www.oref.org.il/WarningMessages/alert/alerts.json`
```

**After (test mode):**
```markdown
<!-- TEST MODE: URL below intentionally broken to exercise the failure path. Revert to alerts.json before next real run. -->
1. **Live alerts JSON:** `https://www.oref.org.il/WarningMessages/alert/alerts-DOES-NOT-EXIST.json`
```

- **Why:** Force the agent into the "Data unavailable — reason: …" path
  to verify it fails cleanly per the rule at line 75–76 of the agent body
  (`If the live + history-AJAX endpoints both fail, do not invent data.
  Write the report anyway, with a clear "Data unavailable — reason: …"
  section.`).
- **Expected behaviour after override:**
  1. Agent attempts the broken URL → 404.
  2. Agent falls through to the history AJAX endpoint (still real).
  3. Report is written with a "Data unavailable" note for the live channel
     and normal data for the history channel.
  4. No fabricated active-alert entries.
- **Revert:** Restore the URL to
  `https://www.oref.org.il/WarningMessages/alert/alerts.json` and remove
  the `<!-- TEST MODE: ... -->` comment line.
- **Status:**
  - [ ] applied to `pikud-alerts.md`
  - [ ] tested (agent run completed; "Data unavailable" path observed)
  - [ ] reverted

---

## 2026-05-10 — `debug` parameter added (permanent change, not an override)

This is a real spec change to `pikud-alerts.md`, not a temporary override —
it is documented here so anyone reading the NOTES file knows the parameter
exists and how to drive it.

### What it does
Adds a `debug` *(boolean, optional, default `false`)* input parameter. When
`true`, the agent appends a `## Debug log` section to the report containing:
- every URL fetched (with tool: WebFetch / Read / Glob)
- HTTP status / body size / item count for each fetch
- parse decisions (JSON vs HTML vs empty/BOM, row counts, rows dropped)
- fallback path taken (which source failed, which was tried next, which
  were skipped and why)
- the clock value used for "now" and where it came from

When `false` or omitted, the report is clean — no Debug log section is
written.

### How to invoke
Pass `debug=true` in the calling prompt to the agent. The orchestrator
typically launches the agent like this:

```
Use the pikud-alerts agent to write today's alert report.
last_n_hours = 48
debug = true
```

The agent reads parameters by name from the prompt, so any of these
phrasings work: `debug=true`, `debug = true`, `debug: true`, or
`with debug=true`.

### Why this is useful
Subagents run in their own context window — you only see their final
summary. When the agent reports something surprising (e.g. "both endpoints
unreachable" while you can curl them yourself), there is no way to
inspect what URLs it actually tried, which fallback it chose, or how it
parsed the response. With `debug=true`, that hidden state is written
directly into the report file, where the calling Claude (or a human) can
read it. Recommended whenever:
- a previous run produced unexpectedly empty output
- you have changed an endpoint or added a new fallback and want to confirm
  the order of attempts
- the failure-injection override (entry above) is active and you want to
  see exactly which fallback path the agent followed

### How to disable
Either omit the parameter entirely, or pass `debug=false`. There is no
state to revert — the parameter defaults off.

---

## How to add a new override entry

Copy the template below to the top of the dated-entries section.

```markdown
## YYYY-MM-DD — <one-line title>

- **Target file:** `.claude/agents/pikud-alerts.md`
- **Section:** <name of the H2/H3 section in the agent body>
- **Approximate line:** <N> (search for `<unique substring>`)

**Before:**
```
<paste exact original block>
```

**After:**
```
<paste exact replacement block>
```

- **Why:** <one or two sentences>
- **Expected behaviour after override:** <bullet points>
- **Revert:** <exact restore instructions>
- **Status:**
  - [ ] applied
  - [ ] tested
  - [ ] reverted
```
