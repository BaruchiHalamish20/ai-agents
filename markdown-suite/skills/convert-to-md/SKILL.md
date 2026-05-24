---
name: convert-to-md
description: Batch-convert PDF/HTML files under converted-pdf-files/ to Markdown under converted-md-files/. With no arguments, processes every file that is missing or stale. Args — pattern (glob filter, default = all), plus optional --list (dry-run) and --debug flags.
argument-hint: "[pattern] [--list] [--debug]"
arguments: [pattern]
allowed-tools: Read, Write, Glob, Bash, Agent
---

# `/convert-to-md` — Markdown batch converter skill

Enumerates source files under `converted-pdf-files/`, decides
which need conversion (missing or stale `.md` in
`converted-md-files/`), and dispatches the `markdown-converter`
agent once per file to produce the output.

The skill is the **batch orchestrator**; the agent is the
**single-file worker**. This split is deliberate — each file gets a
clean isolated agent context so converting a 200-page PDF doesn't
pollute the orchestrator's context with the document's full text.

---

## How to run

The slash command takes one optional positional arg plus up to two
flags.

**Recommended form:** `/convert-to-md [pattern] [--list] [--debug]`
(positional first, flags last).

| Invocation                              | pattern              | list  | debug | Effect                                                              |
|-----------------------------------------|----------------------|-------|-------|---------------------------------------------------------------------|
| `/convert-to-md`                        | `**/*.{pdf,html,htm}`| off   | off   | Convert every pending file under `converted-pdf-files/`.        |
| `/convert-to-md papers/*.pdf`           | `papers/*.pdf`       | off   | off   | Convert pending PDFs in `converted-pdf-files/papers/` only.     |
| `/convert-to-md --list`                 | (all)                | **on**| off   | Print the pending queue. Do NOT convert.                            |
| `/convert-to-md --list --debug`         | (all)                | **on**| **on**| Print the queue with per-file mtime details.                        |
| `/convert-to-md *.html --debug`         | `*.html`             | off   | **on**| Convert pending HTML files at the top level, with per-file debug.   |

Worth knowing:
- Both flags are **case-sensitive** and must appear as standalone
  whitespace-separated tokens. `Debug` or `LIST` won't be detected.
- A bare token that looks like a flag without `--` (e.g. `list`,
  `debug`) is treated as a glob pattern, not a flag.
- Argument parse errors abort cleanly — nothing is converted, no
  state changes.

---

## Argument parsing

Inputs from the platform:
- `$pattern` — first positional token (a glob, relative to
  `converted-pdf-files/`).
- `$ARGUMENTS` — the full whitespace-separated argument string.

Process in this order:

### Step 1 — flag detection

Scan `$ARGUMENTS` for the standalone tokens `--list` and `--debug`.
Each found token sets the corresponding boolean and is removed from
further consideration.

### Step 2 — clean positional value

Strip surrounding whitespace and commas from `$pattern`:
- `pattern_clean = strip(',', strip_whitespace($pattern))`

If `pattern_clean == "--list"` or `pattern_clean == "--debug"`, treat
it as the flag (set the boolean) and clear `pattern_clean`.

### Step 3 — default pattern

If `pattern_clean` is empty, use `**/*.{pdf,html,htm}` (recursive, all
supported extensions).

### Step 4 — validate

The pattern must be a non-absolute, no-parent-escape glob:
- Must not start with `/`.
- Must not contain `../`.

If either rule is violated, abort with an error line and exit. Do
not run any conversion.

### Error path (parse failure)

Print exactly one line to the conversation:

```
/convert-to-md — invalid arguments. Expected: /convert-to-md [pattern] [--list] [--debug]. Got: pattern="<raw>" args="<raw>". Example: /convert-to-md papers/*.pdf --debug
```

Do **not** dispatch any conversion, do **not** write any file.

---

## Building the queue

1. Use `Glob` against `converted-pdf-files/${pattern_clean}` to
   enumerate matching source files. Filter case-insensitively to keep
   only `.pdf`, `.html`, `.htm`.
2. For each source file, compute:
   ```
   rel  = source path minus the "converted-pdf-files/" prefix
   dest = "converted-md-files/" + rel with extension swapped to ".md"
   ```
3. Use `Bash` to read mtimes (cross-platform via the helper below):
   ```bash
   mtime() {
     stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
   }
   ```
4. Classify each file:
   - `pending — missing` if `dest` does not exist.
   - `pending — stale`   if `mtime(source) > mtime(dest)`.
   - `up-to-date`        if `mtime(dest) >= mtime(source)`.
5. The queue is the set of pending files (both reasons). `up-to-date`
   files are reported as a count only.

---

## List mode (`--list`)

Print the queue **and stop**. Format:

```
Conversion queue (N pending, M up-to-date):
  - converted-pdf-files/foo.pdf → converted-md-files/foo.md (missing)
  - converted-pdf-files/papers/2026/intro.html → converted-md-files/papers/2026/intro.md (stale; source 2026-04-30 14:12, dest 2026-04-30 11:00)
```

Do not dispatch the agent. Do not write any files. List mode is the
"would-be" preview — useful before a large run.

When `--list --debug` is combined, append per-file mtime details
(epoch seconds and human-readable both).

---

## Convert mode (default)

For each pending file in deterministic order (alphabetical by source
path):

1. Dispatch the `markdown-converter` agent with the prompt:
   ```
   Convert this source file to Markdown.
   source_path = <source>
   debug = <true|false from skill flag>
   ```
2. Wait for the agent to return.
3. Collect its response into a per-file result entry:
   - Source path
   - Destination path
   - Agent's one-sentence summary
   - Agent's counter line (`H1=…, H2=…, tables=…, images=…`)
   - Any error or approximation flagged by the agent
4. After all files are done, emit a final summary in the
   conversation:
   ```
   Conversion complete — N converted, K failed (out of M pending).
   Up-to-date files skipped: U.

     ✓ converted-pdf-files/foo.pdf → converted-md-files/foo.md
       Summary: <agent's summary>
       H1=…, H2=…, tables=…, images=…

     ✗ converted-pdf-files/papers/broken.html → conversion failed: <agent's error>
   ```

Order matters — alphabetical keeps the run reproducible and the
output diff-friendly. If a single file fails, **continue** with the
rest. Do not abort the batch on per-file errors; report the failure
inline and move on.

---

## Debug mode (`--debug`)

When `--debug` is on:
- Each agent invocation is called with `debug=true`, so each output
  `.md` gets its own `## Debug log` section.
- The skill's conversation output additionally prints, per file, the
  source/dest mtimes, the classification reason (missing vs stale),
  and the dispatch time.
- The final summary includes elapsed wall time.

When `--debug` is off, the conversation output stays terse —
one-line-per-file results only.

---

## Output contract

- Every successful conversion writes exactly one file under
  `converted-md-files/`, preserving the source's relative path
  and only swapping the extension to `.md`.
- The skill itself writes **no** files outside the per-file agent
  outputs. There is no skill-level log file. The conversation
  transcript and the audit-log line from the hook script are the
  only durable traces of a skill run.
- Existing `.md` files under `converted-md-files/` that are
  up-to-date are not touched.

---

## Hard rules

- Never write outside `converted-md-files/`.
- Never read or modify anything outside the configured source folder.
  The pattern is constrained to `converted-pdf-files/**`.
- Parent-escape patterns (`../`) and absolute paths are rejected at
  argument validation time.
- Conversion failures on individual files do not abort the batch.
  Per-file errors are reported and the run continues.
- `--debug` only adds instrumentation — it never changes which files
  get converted.
- `--list` is a pure read; it never writes anything.
- The agent owns the conversion logic; the skill owns the queue,
  dispatch order, and reporting. Do not duplicate conversion logic
  inside the skill itself.
