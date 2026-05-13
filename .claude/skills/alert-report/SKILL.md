---
name: alert-report
description: Fetch Pikud HaOref (Israeli Home Front Command) alerts and write a bilingual Markdown report under reports/. Args — hours (integer, default 24), region (Hebrew substring filter on area names), and an optional --debug flag.
argument-hint: "[hours] [region] [--debug]"
arguments: [hours, region]
allowed-tools: WebFetch, Bash, Read, Write, Glob
---

# `/alert-report` — Pikud HaOref alert report skill

Fetches Pikud HaOref alert data, applies a `last_n_hours` window, optionally
filters the activity table to a Hebrew region substring, and writes a
bilingual Markdown report under `reports/`. Runs **inline** in the calling
session — every tool call is visible in the conversation (unlike the
`pikud-alerts` agent, which runs in an isolated context).

When `--debug` is passed, a full `## Debug log` section is appended to the
report capturing every URL fetched, every HTTP status, parse decisions, and
all filter counts.

---

## How to run

The slash command takes up to two positional args plus one optional flag.
Positional args are bound to `$hours` and `$region` by the platform (see
the `arguments:` frontmatter field above). The `--debug` flag is parsed
manually inside this skill — there is no native flag parser in Claude Code.

**Recommended form:** `/alert-report <hours> <region> --debug`
(positionals first, flag last).

| Invocation                              | hours | region    | debug | Effect                                                |
|-----------------------------------------|-------|-----------|-------|-------------------------------------------------------|
| `/alert-report`                         | 24    | —         | off   | Default 24h window, full activity table.              |
| `/alert-report 48`                      | 48    | —         | off   | 48h window, full activity table.                      |
| `/alert-report 48 חוף`                  | 48    | `חוף`     | off   | 48h window, filter to areas containing `חוף`.         |
| `/alert-report 48 חוף --debug`          | 48    | `חוף`     | **on**| Same as above + `## Debug log` section in the report. |
| `/alert-report 6 --debug`               | 6     | —         | **on**| 6h window, no region filter, debug on.                |
| `/alert-report --debug`                 | 24    | —         | **on**| All defaults + debug on.                              |
| `/alert-report abc`                     | —     | —         | —     | **Parse error** — `abc` is not an integer. No file written. |

Worth knowing:
- The `--debug` flag is **case-sensitive** and must appear as a standalone
  whitespace-separated token. Passing `Debug` or embedding it inside a
  region string does not enable debug.
- If you genuinely want a region literally named `debug`, write
  `/alert-report 48 debug` (no `--` prefix) — the skill does not interpret
  bare `debug` as the flag, only `--debug`.
- Argument parse errors abort cleanly — no half-written report.

---

## Argument parsing

Inputs available from the platform:
- `$hours` — first positional token (declared via `arguments: [hours, region]`).
- `$region` — second positional token.
- `$ARGUMENTS` — the full whitespace-separated argument string.

Process in this order:

### Step 1 — debug flag detection

Scan `$ARGUMENTS` for a standalone token equal to `--debug`. If found,
set `debug = true` and remove that token from further consideration.
Otherwise `debug = false`.

### Step 2 — clean positional values

Strip surrounding whitespace and commas from `$hours` and `$region`:
- `hours_clean = strip(',', strip_whitespace($hours))`
- `region_clean = strip(',', strip_whitespace($region))`

### Step 3 — handle the case where `--debug` was passed in positional slot 0 or 1

If `hours_clean == "--debug"` → treat it as the flag (set `debug = true`)
and clear `hours_clean`. Then re-take the next remaining token from
`$ARGUMENTS` as hours, and the one after as region.

If `region_clean == "--debug"` → treat it as the flag (set `debug = true`)
and clear `region_clean`.

(Recommended UX is `--debug` last, so this branch is for safety, not
common use.)

### Step 4 — validate and dispatch

| `hours_clean`     | `region_clean`     | Behaviour                                              |
|-------------------|--------------------|--------------------------------------------------------|
| empty             | empty              | hours = 24, no region filter                           |
| positive integer  | empty              | hours = `hours_clean`, no region filter                |
| positive integer  | non-empty token    | hours = `hours_clean`, region filter = `region_clean`  |
| anything else     | (any)              | **abort** — see error path below                       |

`region_clean` is treated as opaque text (Hebrew is expected). It is
**not** validated against any list — any non-empty string is accepted as
a substring filter.

### Error path (parse failure)

Print exactly one line to the conversation:

```
/alert-report — invalid arguments. Expected: /alert-report [hours] [region] [--debug]. Got: hours="<raw>" region="<raw>". Example: /alert-report 48 חוף --debug
```

Do **not** fetch any URL, do **not** write any file. Return after the
error. A bad arg never produces a half-built report.

---

## Data sources (try in this order)

1. **Live alerts JSON:** `https://www.oref.org.il/WarningMessages/alert/alerts.json`
   - Empty body or `{}` means no active alert.
   - A populated `data` array means an alert is in progress.
2. **History AJAX endpoint** (use for the `last_n_hours` window):
   `https://alerts-history.oref.org.il/Shared/Ajax/GetAlarmsHistory.aspx?lang=he&fromDate=DD.MM.YYYY&toDate=DD.MM.YYYY&mode=0`
   - Reliable historical-entries source via WebFetch.
   - Returns rows with time, area name (Hebrew), category text.
   - **Times are already in Israel local time (IDT in summer, IST in
     winter).** Do NOT label them as UTC and do NOT add a 2/3-hour
     offset.
3. **Avoid these — known to fail under WebFetch, document but don't rely
   on:**
   - `https://www.oref.org.il/eng/alerts-history` and `/alerts-history` —
     JS-rendered SPA, WebFetch sees an empty HTML shell.
   - `https://www.oref.org.il/WarningMessages/History/AlertsHistory.json`
     — returns HTTP 403 to programmatic clients.

### Fetching with browser headers (mandatory fallback on 403)

Some clients — notably the Anthropic cloud sandbox used by `/schedule`
routines — receive `HTTP 403 Forbidden` from `oref.org.il` when fetching
via plain `WebFetch`. Two root causes are possible: (a) **User-Agent /
Origin filtering** on the CDN, or (b) **geo-blocking** of non-IL egress
IPs. We can't tell which one applies without probing. So every fetch in
this skill follows a two-step pattern:

1. **First attempt:** `WebFetch` against the URL.
2. **If, and only if, the response is `403 Forbidden`** — retry via
   `Bash` + `curl` with a full browser-style header set:

   ```bash
   curl -sS -o /tmp/oref-resp.bin -w '%{http_code}\n' \
     -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" \
     -H "Accept: application/json, text/javascript, */*; q=0.01" \
     -H "Accept-Language: he-IL,he;q=0.9,en-US;q=0.8,en;q=0.7" \
     -H "Referer: https://www.oref.org.il/" \
     -H "Origin: https://www.oref.org.il" \
     -H "X-Requested-With: XMLHttpRequest" \
     "$URL"
   # Body is in /tmp/oref-resp.bin; status code is the captured stdout.
   ```

   `X-Requested-With: XMLHttpRequest` is specifically needed by the
   history AJAX endpoint; the live JSON endpoint tolerates it.

3. **Interpreting the probe result:**
   - **WebFetch 403 → curl 200** → root cause was header/WAF filtering.
     Proceed with the curl-fetched body as the canonical response.
   - **WebFetch 403 → curl 403** → root cause is geo-blocking
     (or a deeper IP allowlist). No header set can fix this from outside
     Israel. Skip to the next endpoint and, if all are blocked, emit the
     "Data unavailable" report.

The fallback is a **probe**, not a permanent transport — call it only on
the 403 path, not on every fetch. WebFetch is preferred when it works
because its outputs already flow through Claude Code's content
extraction; curl returns raw bytes that the skill has to parse itself.

If both the live and history-AJAX endpoints fail after this two-step
probe, do not invent data. Write the report anyway, with a clear
"Data unavailable — reason: …" section that **names which step failed
for each endpoint** (WebFetch 403, curl 403, curl-non-200, parse error,
etc.) so the diagnosis is in the report itself.

---

## Window math (applying `last_n_hours`)

1. Take the **current Israel local time** as your "now". Skills run
   inline, so use whatever time anchor exists in the calling
   conversation's context. If genuinely unknown, fall back to the date
   from the system context and note in the report that an exact cutoff
   could not be applied.
2. Compute `cutoff = now - last_n_hours` (in IDT/IST, the source's native
   timezone — never convert).
3. Query the history endpoint with `fromDate = date(cutoff)` and
   `toDate = date(now)` (in `DD.MM.YYYY`). If the cutoff lands on a
   prior day, the query must span both dates.
4. Discard rows older than `cutoff`. Keep rows from `cutoff` to `now`,
   inclusive.

---

## Region filter (applied after time filter, before write)

If a region was provided (`region_clean` is non-empty), filter the kept
rows: keep only rows whose Hebrew area name **contains `region_clean`
as a substring**.

- Match is case-sensitive on the source's Hebrew strings.
- No transliteration matching — `Hanita` will NOT match `חניתה`.
- Match against the Hebrew area name only, not the category, not the
  English transliteration.

Record two counters:
- `M = rows after time filter` (before region filter)
- `N = rows after region filter` (`= M` if no region was provided)

If `region` was provided and `N == 0`, still write the report — show the
empty activity section, and flag in Notes:
`Region filter "<value>" matched 0 of M rows in the time window.`

---

## Debug instrumentation (only when `debug = true`)

When `debug` is true, append a final `## Debug log` section to the report
file (after `## Notes`). When `debug` is false, this section is **omitted
entirely** (not "left empty").

The debug log is a flat list of `[step N]` entries, one per significant
event:

1. **Argument parse result** — raw `$ARGUMENTS`, extracted flag tokens,
   resulting `hours` / `region` / `debug` values.
2. **Time anchor used for "now"** — value, source (calling conversation,
   system context, or "unknown — date-only fallback").
3. **Computed window** — `cutoff` and `now` as full timestamps, plus
   `fromDate`/`toDate` used for the history query.
4. **Each fetch attempt** — tool used (`WebFetch` or `curl+headers`),
   URL, HTTP status, body size in bytes (or
   "empty" / "error: …"), parsed result (e.g. "0 active alerts", "47
   history rows").
5. **Parse decisions** — for each response: format detected
   (JSON / HTML / empty), row count before/after time filter, rows
   dropped and why.
6. **Region filter decision** — `M` (after time filter), `N` (after
   region filter), the substring used, examples of 1–2 matched and 1–2
   non-matched rows.
7. **Filename collision check** — Glob result, chosen filename
   (including any `-2`/`-3` suffix).
8. **Fallback paths** — any source that failed and which fallback was
   tried next; explicitly note "skipped" sources from the avoid list.
9. **Skill runtime context** — `${CLAUDE_SESSION_ID}`,
   `${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}` — these are runtime-injected
   placeholders that identify which session/effort-level/skill produced
   this run.

Format each entry as:

```markdown
- `[step N]` short description — key:value, key:value
```

Example:

```markdown
- `[step 1]` argument parse — raw="48 חוף --debug", flag tokens=["--debug"], hours=48, region="חוף", debug=true
- `[step 2]` time anchor — now=2026-05-10T14:30:00+03:00, source="calling conversation"
- `[step 3]` history fetch — url=https://alerts-history.../GetAlarmsHistory.aspx?...&fromDate=08.05.2026&toDate=10.05.2026, status=200, body=42 KB, parsed=101 rows
- `[step 4]` time filter — kept 47 of 101 (cutoff=2026-05-08T14:30, now=2026-05-10T14:30)
- `[step 5]` region filter — substring="חוף", matched=3 of 47, examples retained=["חוף בצת", "חוף אכזיב", "חוף הזיו"], examples dropped=["חניתה", "ברעם"]
- `[step 6]` write — reports/2026-05-10-1430.md (no collision)
- `[step 7]` runtime — session=${CLAUDE_SESSION_ID}, effort=${CLAUDE_EFFORT}, skill_dir=${CLAUDE_SKILL_DIR}
```

The point of the debug log is to make hidden state inspectable *after the
fact*, without re-running. Skills run inline so some of this is also
visible in the conversation as tool-use blocks, but the debug log is
durable, structured, and grep-able.

---

## Output contract

Write a single Markdown file to:

```
reports/YYYY-MM-DD-HHmm.md
```

- Use the local Israel time (IDT/IST) for the `HHmm` portion.
- If no current time is available, drop the `-HHmm` suffix and use
  `reports/YYYY-MM-DD.md`. Note the limitation in the report body.
- Before writing, use `Glob` on `reports/*.md` to avoid overwriting a
  file from the same minute. If a collision exists, append `-2`, `-3`, etc.

## Report structure

```markdown
# דו"ח התרעות פיקוד העורף — <local time>

## Summary
<≤ 3 sentences, plain English, what's happening right now>

## Active alerts
<list, or "None at this time">

## Recent activity (last N hours)
<state the exact window: from HH:MM on YYYY-MM-DD to HH:MM on YYYY-MM-DD IDT>
<if region filter active, also state: Region filter: "<value>" — N of M rows retained>
<table or bullets: time — area — type, post-filter>

## Sources
- <URL of each endpoint actually fetched>

## Notes
<anything the operator should know — e.g. "history endpoint returned 403", region match counts, parse fallbacks>

## Debug log
<only present when --debug was passed; flat list of [step N] entries — see Debug instrumentation section>
```

## Language rules (bilingual report)

The report is bilingual by design: **Hebrew title, English body**. Be
literal about which elements use which language — do not improvise.

- **H1 title:** Hebrew. Use exactly
  `# דו"ח התרעות פיקוד העורף — <local time>`. Numerals/dates/`IDT` stay
  in Latin script.
- **Section headers (`##`):** English (`## Summary`, `## Active alerts`,
  `## Recent activity (last N hours)`, `## Sources`, `## Notes`,
  `## Debug log`). Do NOT translate them to Hebrew.
- **Prose body:** English.
- **Alert area names in the activity table:** Hebrew (as the source
  returned them, e.g. `קריית שמונה`) with a parenthesized English
  transliteration (e.g. `קריית שמונה (Kiryat Shmona)`).
- **Alert type strings in the table:** Hebrew original paired with an
  English gloss (e.g. `ירי רקטות וטילים — Rocket and missile fire`).
- **URLs, filenames, parameter names, dates, times, debug log entries:**
  unchanged.

## After writing

In the conversation (not in the report file), print **two lines**:

1. Path of the file you wrote.
2. One-sentence summary that includes: hours window, region filter (if
   any), record count after filtering, active-alert status, and debug
   status. Example:
   `48h window, region "חוף" filter (3 of 47 rows retained), no active alerts, debug=on.`

That's it. The file is the deliverable; the conversation gets the
confirmation.

## Hard rules

- Never write outside `reports/`.
- Never fabricate alert data. If a source is empty or unreachable, say so
  in the Notes section.
- Never call out to non-oref.org.il endpoints.
- Follow the language rules literally — Hebrew H1, English H2s, bilingual
  area/type strings.
- Argument parse errors abort the run cleanly — no half-written file.
- Region filter is **substring on Hebrew only**. Do not silently match
  English transliterations or fuzzy-match.
- `--debug` is detected only as a standalone token equal to `--debug`
  (case-sensitive, with the `--` prefix). A bare `debug` token is treated
  as a region value, not the flag.
- The `## Debug log` section is **omitted entirely** when debug is off.
