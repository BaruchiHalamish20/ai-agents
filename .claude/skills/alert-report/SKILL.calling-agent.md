---
name: alert-report
description: Pikud HaOref alert report — delegates the fetch/parse/write to the pikud-alerts subagent for isolated execution. Args — [hours] (integer, default 24), [region] (Hebrew substring filter on area names), [--debug] (flag, position-independent, off by default).
argument-hint: "[hours] [region] [--debug]"
allowed-tools: Agent, Bash, PowerShell, Read, Glob
---

# `/alert-report` (calling-agent variant) — Pikud HaOref report via subagent

This variant of the alert-report skill delegates the actual fetch / parse /
write work to the **`pikud-alerts`** subagent defined in
`.claude/agents/pikud-alerts.md`. The orchestrator's job is purely:

1. Parse arguments.
2. Fetch the current Israel local time (the agent has no built-in clock).
3. Invoke the subagent with a self-contained prompt.
4. Surface the subagent's two-line response to the user.

### When to use this variant vs `SKILL.md`

| Aspect                        | `SKILL.md` (inline)              | `SKILL.calling-agent.md` (this file) |
|-------------------------------|----------------------------------|--------------------------------------|
| WebFetch / parse calls        | Visible in main conversation     | Hidden inside subagent context       |
| Main-context pollution        | Higher (raw JSON / HTML rows)    | Minimal (only final summary)         |
| Debuggability of fetches      | Direct — every tool call shown   | Via `--debug` log appended to report |
| Cost                          | One agent (this one)             | Two agents (this + pikud-alerts)     |

Pick this variant when the surrounding conversation is doing other work
and you do not want the alert-report tool-call blobs in the main context.

## Argument parsing

Read `$ARGUMENTS` as a whitespace-separated token list. Two passes:

### Pass 1 — flag extraction

Scan all tokens. If any token is exactly `--debug` (or `debug` as a
standalone token), set `debug = true` and **remove that token** from the
list. Otherwise `debug = false`. `--debug` is position-independent.

### Pass 2 — positional args

After flag extraction, take the remaining tokens. Strip surrounding
whitespace and commas from each. Assign:

- `$0_clean` = first remaining token (hours)
- `$1_clean` = second remaining token (region)

Then dispatch on this table:

| `$0_clean`        | `$1_clean`         | Behaviour                                              |
|-------------------|--------------------|--------------------------------------------------------|
| empty             | empty              | hours = 24, no region filter                           |
| positive integer  | empty              | hours = `$0_clean`, no region filter                   |
| positive integer  | non-empty token    | hours = `$0_clean`, region filter = `$1_clean`         |
| anything else     | (any)              | **abort** — see error path below                       |

`$1_clean` is treated as opaque text (Hebrew expected). It is **not**
validated against any region list.

### Error path (parse failure)

Print exactly one line to the conversation:

```
/alert-report — invalid arguments. Expected: /alert-report [hours] [region] [--debug]. Got: $0="<raw>" $1="<raw>". Example: /alert-report 48 חוף --debug
```

Do **not** fetch the time, do **not** invoke the subagent, do **not**
write any file. Return after the error.

## Time anchor (required by the subagent)

The `pikud-alerts` agent has **no built-in clock** — its description
mandates that the calling Claude pass the current Israel local time
verbatim. Before invoking the agent, fetch it via:

- **Unix / git-bash:** `TZ=Asia/Jerusalem date "+%Y-%m-%d %H:%M %Z"`
- **PowerShell** (preferred on Windows; works even when `tzdata` is
  missing from git-bash):
  ```powershell
  $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('Israel Standard Time')
  $now = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
  $now.ToString('yyyy-MM-dd HH:mm')
  ```

If the bash command returns `GMT` / `UTC` instead of `IDT` / `IST` (some
Windows git-bash installs ship without `tzdata`), discard that result
and fall back to PowerShell. Never pass a UTC value to the agent
labelled as IDT — that will silently corrupt the cutoff math.

If both methods fail, you have two choices:

1. **Date-only fallback:** pass `current time is YYYY-MM-DD (time
   unavailable)` to the agent. The agent will date-only the filename
   and note the limitation in the report.
2. **Abort:** print
   `/alert-report — could not determine current Israel local time. Aborting.`
   and stop. Choose abort if `last_n_hours` is small (≤ 6) — a
   date-only fallback over a short window is meaningless.

## Subagent invocation

Use the **Agent** tool with `subagent_type: pikud-alerts`. Build a
self-contained prompt that includes everything the agent needs (it does
not see this conversation):

```
current time is <YYYY-MM-DD HH:MM> IDT

last_n_hours = <hours>
debug = <true|false>
<if region provided:>
region_filter = "<$1_clean>"

Please produce the standard Pikud HaOref alert report under reports/.

<if region provided, add this paragraph:>
Region filter (additional instruction beyond your default contract):
after applying the last_n_hours time filter, further filter the
"Recent activity" rows so that only rows whose Hebrew area name
contains the substring "<$1_clean>" are retained. Match is
case-sensitive on the Hebrew string only — no transliteration, no
fuzzy match. Record before/after counts in the Notes section as:
  'Region filter "<$1_clean>" — N of M rows retained.'
If N == 0, still write the report with an empty activity section
and flag the empty match in Notes.
```

Notes on the prompt:

- The `current time is …` line is what the agent's description scans
  for — keep it on its own line, exactly that prefix.
- Pass `debug` as a literal `true` / `false` so the agent's
  parameter-extraction logic picks it up.
- The region-filter instruction is **per-invocation extra context**.
  The agent's `.md` contract does not bake in a region filter; we
  layer it on by prompt. If you forget this paragraph when a region
  was provided, the agent will return an unfiltered report — that's
  a silent failure, watch for it.
- Do **not** ask the agent to return the report contents inline.
  The file is the deliverable.

Run the agent in the **foreground** (default). You need its response
to print the summary line, so background mode is not appropriate.

## After invocation

The agent returns at most ~10 lines: a file path and a one-sentence
summary, possibly an error note. From its response:

1. Extract the report file path.
2. (Optional sanity check) call `Read` on the file to confirm it
   exists and is non-empty. If it is missing, surface that as an
   error — the agent's summary describes intent, not necessarily
   what landed on disk.
3. Print exactly two lines to the conversation:

   ```
   <report file path>
   <one-sentence summary: hours window, region filter (if any), record count, active-alert status, debug status>
   ```

   Example:
   ```
   reports/2026-05-10-1451.md
   48h window, region "חוף" filter (4 of 29 rows retained), no active alerts, debug=off.
   ```

If the agent reported an error (data unavailable, write failure,
etc.), pass the error through verbatim — do not retry, do not fall
back to an inline fetch. The user can re-run the slash command or
switch to the inline `SKILL.md` variant.

## Hard rules

- This skill **never** fetches `oref.org.il` directly. All fetching is
  done by the `pikud-alerts` subagent.
- This skill **never** writes to `reports/` directly. The subagent owns
  the file.
- The agent's identity (`pikud-alerts`) and file path
  (`.claude/agents/pikud-alerts.md`) are fixed — do not invoke any
  other agent for this task, and do not rename/relocate the agent file.
- Argument parse errors abort **before** the time fetch and **before**
  the subagent is invoked. Same error contract as `SKILL.md`.
- Region filter must be passed as an explicit per-invocation
  instruction in the subagent prompt — the agent does not support it
  natively. If region was provided and the prompt omits the filter
  paragraph, the report will be wrong.
- Never invent or substitute a current time. If both bash and
  PowerShell fail to produce an IDT/IST value, follow the date-only
  fallback or abort path described above.
- The two-line conversational output after invocation is the contract
  with the user — keep it to two lines, no more.
