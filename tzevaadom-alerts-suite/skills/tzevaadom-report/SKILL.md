---
name: tzevaadom-report
description: Fetch TzevaAdom (community) alerts from api.tzevaadom.co.il and write a bilingual Markdown report under reports/tzevaadom/. Args — hours (integer, default 24), city (Hebrew substring filter on the cities array), and an optional --debug flag.
argument-hint: "[hours] [city] [--debug]"
arguments: [hours, city]
allowed-tools: WebFetch, Read, Write, Glob
---

# `/tzevaadom-report` — TzevaAdom alert report skill

Fetches TzevaAdom alert data from `api.tzevaadom.co.il`, applies a
`last_n_hours` window, optionally filters the activity table to a
Hebrew city substring, and writes a bilingual Markdown report under
`reports/tzevaadom/`. Runs **inline** in the calling session — every
tool call is visible in the conversation (unlike the `tzevaadom-alerts`
agent, which runs in an isolated context).

When `--debug` is passed, a full `## Debug log` section is appended to
the report capturing every URL fetched, every HTTP status, parse
decisions, and all filter counts.

This skill is the **community-source counterpart** to `/alert-report`
(which targets the official Pikud HaOref source). The two skills are
deliberately independent so that students can compare them side by
side and observe that *the trigger model is orthogonal to the data
source*.

---

## How to run

The slash command takes up to two positional args plus one optional
flag. Positional args are bound to `$hours` and `$city` by the platform
(see the `arguments:` frontmatter field above). The `--debug` flag is
parsed manually inside this skill — there is no native flag parser in
Claude Code.

**Recommended form:** `/tzevaadom-report <hours> <city> --debug`
(positionals first, flag last).

| Invocation                                  | hours | city          | debug | Effect                                                  |
|---------------------------------------------|-------|---------------|-------|---------------------------------------------------------|
| `/tzevaadom-report`                         | 24    | —             | off   | Default 24h window, full activity table.                |
| `/tzevaadom-report 48`                      | 48    | —             | off   | 48h window, full activity table.                        |
| `/tzevaadom-report 48 שדרות`                | 48    | `שדרות`       | off   | 48h window, filter to alerts whose cities include `שדרות`. |
| `/tzevaadom-report 48 שדרות --debug`        | 48    | `שדרות`       | **on**| Same as above + `## Debug log` section in the report.   |
| `/tzevaadom-report 6 --debug`               | 6     | —             | **on**| 6h window, no city filter, debug on.                    |
| `/tzevaadom-report --debug`                 | 24    | —             | **on**| All defaults + debug on.                                |
| `/tzevaadom-report abc`                     | —     | —             | —     | **Parse error** — `abc` is not an integer. No file written. |

Worth knowing:
- The `--debug` flag is **case-sensitive** and must appear as a
  standalone whitespace-separated token. Passing `Debug` or embedding
  it inside a city string does not enable debug.
- If you genuinely want a city literally named `debug`, write
  `/tzevaadom-report 48 debug` (no `--` prefix) — the skill does not
  interpret bare `debug` as the flag, only `--debug`.
- Argument parse errors abort cleanly — no half-written report.

---

## Argument parsing

Inputs available from the platform:
- `$hours` — first positional token.
- `$city` — second positional token.
- `$ARGUMENTS` — the full whitespace-separated argument string.

Process in this order:

### Step 1 — debug flag detection

Scan `$ARGUMENTS` for a standalone token equal to `--debug`. If found,
set `debug = true` and remove that token from further consideration.
Otherwise `debug = false`.

### Step 2 — clean positional values

Strip surrounding whitespace and commas from `$hours` and `$city`:
- `hours_clean = strip(',', strip_whitespace($hours))`
- `city_clean = strip(',', strip_whitespace($city))`

### Step 3 — handle the case where `--debug` was passed in positional slot 0 or 1

If `hours_clean == "--debug"` → treat it as the flag (set
`debug = true`) and clear `hours_clean`. Then re-take the next
remaining token from `$ARGUMENTS` as hours, and the one after as city.

If `city_clean == "--debug"` → treat it as the flag (set
`debug = true`) and clear `city_clean`.

(Recommended UX is `--debug` last, so this branch is for safety, not
common use.)

### Step 4 — validate and dispatch

| `hours_clean`     | `city_clean`       | Behaviour                                              |
|-------------------|--------------------|--------------------------------------------------------|
| empty             | empty              | hours = 24, no city filter                             |
| positive integer  | empty              | hours = `hours_clean`, no city filter                  |
| positive integer  | non-empty token    | hours = `hours_clean`, city filter = `city_clean`      |
| anything else     | (any)              | **abort** — see error path below                       |

`city_clean` is treated as opaque text (Hebrew is expected). It is
**not** validated against any list — any non-empty string is accepted
as a substring filter.

### Error path (parse failure)

Print exactly one line to the conversation:

```
/tzevaadom-report — invalid arguments. Expected: /tzevaadom-report [hours] [city] [--debug]. Got: hours="<raw>" city="<raw>". Example: /tzevaadom-report 48 שדרות --debug
```

Do **not** fetch any URL, do **not** write any file. Return after the
error. A bad arg never produces a half-built report.

---

## Data sources (verified working — no fallback probe needed)

The TzevaAdom API is fully on Cloudflare, public, no auth, and has no
known geo-block — so unlike `/alert-report`, this skill does **not**
need a header-probe fallback. Plain `WebFetch` works from anywhere.

1. **Live alerts JSON:** `https://api.tzevaadom.co.il/notifications`
   - Returns a JSON array.
   - Empty array `[]` means no active alert at this moment.
   - A populated array means an alert is currently in progress. Each
     record has:
     - `notificationId` — string (UUID)
     - `time` — integer (epoch seconds UTC)
     - `threat` — integer (0–8, see table below)
     - `isDrill` — boolean
     - `cities` — array of Hebrew city/area names

2. **History endpoint:** `https://api.tzevaadom.co.il/alerts-history/`
   - Returns a JSON array of **incident groups**, newest first.
   - Each group has:
     - `id` — integer (corresponds to the URL `/en/alerts/<id>`)
     - `description` — string or null
     - `alerts[]` — array of records using the same shape as the live
       endpoint
   - **The endpoint takes no date-range parameters.** It returns
     roughly the last 24–48 hours of activity. Client-side time
     filtering is mandatory.

If both endpoints fail, do not invent data. Write the report anyway,
with a clear "Data unavailable — reason: …" section.

---

## Threat code → label map

The integer `threat` field maps to human-readable categories. Use this
table when rendering the activity rows. If a code is not in the table,
print `threat code <n>` rather than guessing.

| `threat` | English label                          | Hebrew label                |
|----------|----------------------------------------|-----------------------------|
| 0        | Rocket and missile fire                | ירי רקטות וטילים            |
| 1        | Hostile aircraft intrusion             | חדירת כלי טיס עוין          |
| 2        | Earthquake                             | רעידת אדמה                  |
| 3        | Hazardous materials event              | אירוע חומרים מסוכנים        |
| 4        | Suspected terrorist infiltration       | חשש לחדירת מחבלים           |
| 5        | Suspected tsunami                      | חשש לצונאמי                 |
| 6        | Drill — hostile aircraft               | תרגיל — חדירת כלי טיס       |
| 7        | Update                                 | עדכון                       |
| 8        | Test                                   | בדיקה                       |

(The canonical mapping lives in the community `amitfin/oref_alert`
Home Assistant integration. If you encounter a `threat` value outside
this range in a real response, render it as `threat code <n>` and log
it in the Notes section.)

---

## Window math (applying `last_n_hours`)

1. Take the **current Israel local time** as your "now". Skills run
   inline, so use whatever time anchor exists in the calling
   conversation's context. Convert to a UTC epoch in seconds:
   `now_epoch = unix_timestamp(now_utc)`.
2. Compute `cutoff_epoch = now_epoch - (last_n_hours * 3600)`.
3. Fetch `/alerts-history/` and **flatten** all `alerts[]` arrays from
   every incident group into a single list of records.
4. Discard records where `time < cutoff_epoch`. Keep records where
   `cutoff_epoch <= time <= now_epoch`.

**Always filter in epoch seconds (UTC), never in IDT/IST.** Converting
first risks DST-shift bugs around late-October / late-March. Render
in IDT/IST only for display.

---

## City filter (applied after time filter, before write)

If a city was provided (`city_clean` is non-empty), filter the kept
records: keep a record only if **any element** of its `cities` array
contains `city_clean` as a substring.

- Match is case-sensitive on the source's Hebrew strings.
- No transliteration matching — `Sderot` will NOT match `שדרות`.
- A record's `cities` may have multiple entries; one match keeps the
  record.

Record two counters:
- `M = records after time filter` (before city filter)
- `N = records after city filter` (`= M` if no city was provided)

If `city` was provided and `N == 0`, still write the report — show the
empty activity section, and flag in Notes:
`City filter "<value>" matched 0 of M alerts in the time window.`

---

## Debug instrumentation (only when `debug = true`)

When `debug` is true, append a final `## Debug log` section to the
report file (after `## Notes`). When `debug` is false, this section is
**omitted entirely** (not "left empty").

The debug log is a flat list of `[step N]` entries, one per significant
event:

1. **Argument parse result** — raw `$ARGUMENTS`, extracted flag tokens,
   resulting `hours` / `city` / `debug` values.
2. **Time anchor used for "now"** — value (IDT) and epoch seconds, plus
   the source (calling conversation, system context, or
   "unknown — date-only fallback").
3. **Computed window** — `cutoff_epoch` and `now_epoch`, plus the
   human-readable equivalents in IDT.
4. **Each WebFetch call** — URL, HTTP status, body size in bytes (or
   "empty" / "error: …"), parsed result (e.g. "0 active alerts",
   "12 incident groups").
5. **Flatten step** — incident-group count → individual-alert count.
6. **Time filter decision** — M (before), kept count (after), examples
   of 1–2 retained and 1–2 dropped with their epoch + IDT timestamps.
7. **City filter decision** — `M` (after time filter), `N` (after city
   filter), the substring used, examples of 1–2 matched and 1–2
   non-matched rows.
8. **Filename collision check** — Glob result on
   `reports/tzevaadom/*.md`, chosen filename (including any
   `-2`/`-3` suffix).
9. **Unknown threat codes** — list any `threat` values encountered
   that are not in the threat table; render decision applied.

Format each entry as:

```markdown
- `[step N]` short description — key:value, key:value
```

Example:

```markdown
- `[step 1]` argument parse — raw="48 שדרות --debug", flag tokens=["--debug"], hours=48, city="שדרות", debug=true
- `[step 2]` time anchor — now=2026-05-10T14:30:00+03:00 (epoch=1778847000), source="calling conversation"
- `[step 3]` history fetch — url=https://api.tzevaadom.co.il/alerts-history/, status=200, body=18 KB, parsed=12 incident groups
- `[step 4]` flatten — 12 groups → 57 alert records
- `[step 5]` time filter — kept 23 of 57 (cutoff=1778674200/2026-05-08T14:30 IDT, now=1778847000/2026-05-10T14:30 IDT)
- `[step 6]` city filter — substring="שדרות", matched=4 of 23, examples retained=["שדרות", "שדרות (מרכז)"], examples dropped=["קריית מלאכי", "ניר עם"]
- `[step 7]` write — reports/tzevaadom/2026-05-10-1430.md (no collision)
```

The point of the debug log is to make hidden state inspectable *after
the fact*, without re-running. Skills run inline so some of this is
also visible in the conversation as tool-use blocks, but the debug log
is durable, structured, and grep-able.

---

## Output contract

Write a single Markdown file to:

```
reports/tzevaadom/YYYY-MM-DD-HHmm.md
```

- Use the local Israel time (IDT/IST) for the `HHmm` portion.
- If no current time is available, drop the `-HHmm` suffix and use
  `reports/tzevaadom/YYYY-MM-DD.md`. Note the limitation in the report
  body.
- Before writing, use `Glob` on `reports/tzevaadom/*.md` to avoid
  overwriting a file from the same minute. If a collision exists,
  append `-2`, `-3`, etc.
- If `reports/tzevaadom/` does not exist yet, create it (any directory
  creation needed for the Write tool).

## Report structure

```markdown
# דו"ח התרעות צבע אדום — <local time>

## Summary
<≤ 3 sentences, plain English, what's happening right now>

## Active alerts
<list of active alerts from /notifications, or "None at this time">
<each row: cities (Hebrew + English transliteration when known) — threat label (Hebrew + English) — isDrill flag if true>

## Recent activity (last N hours)
<state the exact window: from HH:MM on YYYY-MM-DD to HH:MM on YYYY-MM-DD IDT>
<if city filter active, also state: City filter: "<value>" — N of M alerts retained>
<bullets or table: time (IDT) — cities (Hebrew) — threat label, post-filter>

## Sources
- <URL of each endpoint actually fetched>

## Notes
<anything the operator should know — e.g. "history endpoint returned 503", city match counts, unknown threat codes, parse fallbacks>
<write "The alert report was generated from tzevaadom-alerts-suite plugin running on behalf of Claude Code">


## Debug log
<only present when --debug was passed; flat list of [step N] entries — see Debug instrumentation section>
```

## Language rules (bilingual report)

The report is bilingual by design: **Hebrew title, English body**. Be
literal about which elements use which language — do not improvise.

- **H1 title:** Hebrew. Use exactly
  `# דו"ח התרעות צבע אדום — <local time>`. Numerals/dates/`IDT` stay
  in Latin script.
- **Section headers (`##`):** English (`## Summary`, `## Active alerts`,
  `## Recent activity (last N hours)`, `## Sources`, `## Notes`,
  `## Debug log`). Do NOT translate them to Hebrew.
- **Prose body:** English.
- **City names:** Hebrew (as the source returned them, e.g. `שדרות`)
  with a parenthesized English transliteration when known
  (e.g. `שדרות (Sderot)`). If you don't know a transliteration, just
  print the Hebrew — do not invent one.
- **Threat labels:** Hebrew original paired with the English label from
  the threat table (e.g. `ירי רקטות וטילים — Rocket and missile fire`).
- **URLs, filenames, parameter names, dates, times, debug log entries,
  epoch numbers:** unchanged.

## After writing

In the conversation (not in the report file), print **two lines**:

1. Path of the file you wrote.
2. One-sentence summary that includes: hours window, city filter (if
   any), record count after filtering, active-alert status, and debug
   status. Example:
   `48h window, city "שדרות" filter (4 of 23 alerts retained), no active alerts, debug=on.`

That's it. The file is the deliverable; the conversation gets the
confirmation.

## Hard rules

- Never write outside `reports/tzevaadom/`.
- Never fabricate alert data. If a source is empty or unreachable, say
  so in the Notes section.
- Never call out to non-`tzevaadom.co.il` endpoints. This skill
  deliberately does not cross-reference Pikud HaOref — that is the job
  of `/alert-report`.
- Follow the language rules literally — Hebrew H1, English H2s,
  bilingual city/threat strings.
- Argument parse errors abort the run cleanly — no half-written file.
- City filter is **substring on Hebrew only**. Do not silently match
  English transliterations or fuzzy-match.
- `--debug` is detected only as a standalone token equal to `--debug`
  (case-sensitive, with the `--` prefix). A bare `debug` token is
  treated as a city value, not the flag.
- The `## Debug log` section is **omitted entirely** when debug is off.
- Always filter time in epoch seconds (UTC). Convert to IDT/IST for
  display only.
