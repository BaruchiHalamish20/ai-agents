---
name: convert-to-pdf
description: Batch-convert Word documents (.doc/.docx) under to-convert-word-files/ to PDFs under converted-pdf-files/. With no arguments, processes every file that is missing or stale. Args — pattern (glob filter, default = all), plus optional --list (dry-run) and --debug flags.
argument-hint: "[pattern] [--list] [--debug]"
arguments: [pattern]
allowed-tools: Read, Glob, Bash
---

# `/convert-to-pdf` — Word-to-PDF batch converter skill

Enumerates source files under `to-convert-word-files/`, decides which
need conversion (missing or stale `.pdf` in `converted-pdf-files/`),
and runs the conversion binary once per file to produce the output.

Unlike the markdown converter, this skill does **not** dispatch a
per-file agent — DOCX→PDF is a mechanical binary transform, not an
interpretive read. The skill drives the converter directly via Bash.

---

## Required binary

The skill needs one of these installed and on `PATH`:

1. **LibreOffice headless** (preferred) — `soffice` or `libreoffice`
   binary. Invocation: `soffice --headless --convert-to pdf <file> --outdir <dir>`.
2. **Pandoc** (fallback) — requires a LaTeX engine (xelatex/pdflatex).
   Invocation: `pandoc <file> -o <out.pdf>`. Quality is lower than
   LibreOffice for complex Word documents; use only if soffice is
   unavailable.

Detection order at run time:
- Probe with `command -v soffice`, then `command -v libreoffice`,
  then `command -v pandoc`. Use the first one that resolves to a
  path. **Do not** invoke the binary with `--version` for detection
  — on Windows, `soffice --version` (without `--headless`) can spawn
  a console window that prompts on first launch and blocks the
  Bash tool waiting on Enter.
- If none are available, abort with a clear error and do not convert
  anything.

---

## How to run

| Invocation                                  | pattern              | list  | debug | Effect                                                                  |
|---------------------------------------------|----------------------|-------|-------|-------------------------------------------------------------------------|
| `/convert-to-pdf`                           | `**/*.{doc,docx}`    | off   | off   | Convert every pending file under `to-convert-word-files/`.              |
| `/convert-to-pdf reports/*.docx`            | `reports/*.docx`     | off   | off   | Convert pending DOCX files in `to-convert-word-files/reports/` only.    |
| `/convert-to-pdf --list`                    | (all)                | **on**| off   | Print the pending queue. Do NOT convert.                                |
| `/convert-to-pdf --list --debug`            | (all)                | **on**| **on**| Print the queue with per-file mtime details.                            |
| `/convert-to-pdf *.docx --debug`            | `*.docx`             | off   | **on**| Convert pending DOCX files at the top level, with per-file debug.       |

Worth knowing:
- Both flags are **case-sensitive** standalone tokens. `Debug` or
  `LIST` won't be detected.
- A bare token that looks like a flag without `--` (e.g. `list`,
  `debug`) is treated as a glob pattern, not a flag.
- Argument parse errors abort cleanly — nothing is converted.

---

## Argument parsing

Inputs from the platform:
- `$1` — first positional token (a glob, relative to `to-convert-word-files/`).
- `$ARGUMENTS` — the full whitespace-separated argument string.

### Step 1 — flag detection

Scan `$ARGUMENTS` for the standalone tokens `--list` and `--debug`.
Each found token sets the corresponding boolean and is removed from
further consideration.

### Step 2 — clean positional value

`pattern_clean = strip(',', strip_whitespace($1))`

If `pattern_clean == "--list"` or `pattern_clean == "--debug"`, treat
it as the flag (set the boolean) and clear `pattern_clean`.

### Step 3 — default pattern

If `pattern_clean` is empty, use `**/*.{doc,docx}`.

### Step 4 — validate

- Must not start with `/`.
- Must not contain `../`.

If either rule is violated, abort with one error line and exit.

### Error path (parse failure)

```
/convert-to-pdf — invalid arguments. Expected: /convert-to-pdf [pattern] [--list] [--debug]. Got: pattern="<raw>" args="<raw>". Example: /convert-to-pdf reports/*.docx --debug
```

Do not convert anything, do not write any file.

---

## Building the queue

1. Use `Glob` against `to-convert-word-files/${pattern_clean}` to
   enumerate matching files. Filter case-insensitively to keep only
   `.doc` and `.docx`. **Skip Word lock files** (anything starting
   with `~$`) — these are open-in-Word markers, not real documents.
2. For each source file, compute:
   ```
   rel  = source path minus the "to-convert-word-files/" prefix
   dest = "converted-pdf-files/" + rel with extension swapped to ".pdf"
   ```
3. Use `Bash` to read mtimes (cross-platform):
   ```bash
   mtime() {
     stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
   }
   ```
4. Classify:
   - `pending — missing` if `dest` does not exist.
   - `pending — stale`   if `mtime(source) > mtime(dest)`.
   - `up-to-date`        if `mtime(dest) >= mtime(source)`.

---

## List mode (`--list`)

Print the queue **and stop**. Format:

```
Conversion queue (N pending, M up-to-date):
  - to-convert-word-files/foo.docx → converted-pdf-files/foo.pdf (missing)
  - to-convert-word-files/reports/2026/q1.docx → converted-pdf-files/reports/2026/q1.pdf (stale; source 2026-04-30 14:12, dest 2026-04-30 11:00)
```

Do not run any conversion. With `--list --debug`, append per-file
mtime details (epoch + human readable).

---

## Convert mode (default)

For each pending file in deterministic order (alphabetical by source
path):

1. Ensure the destination's parent directory exists:
   ```bash
   mkdir -p "$(dirname "$dest")"
   ```
2. Invoke the detected converter. Always redirect stdin from
   `/dev/null` so the binary can never block on an interactive
   prompt (relevant on Windows where soffice may otherwise wait
   for keyboard input on first launch).
   - **LibreOffice**:
     ```bash
     soffice --headless --convert-to pdf "$src" --outdir "$(dirname "$dest")" < /dev/null
     ```
     Note: soffice names the output `<basename>.pdf` in the outdir,
     which matches our convention. No rename needed unless the source
     basename differs from what soffice emits.
   - **Pandoc**:
     ```bash
     pandoc "$src" -o "$dest" < /dev/null
     ```
3. Verify the destination file was created and is non-empty. If not,
   record a per-file failure and continue.
4. Collect per-file result for the final summary.
5. After all files are done, emit:
   ```
   Conversion complete — N converted, K failed (out of M pending).
   Up-to-date files skipped: U.

     ✓ to-convert-word-files/foo.docx → converted-pdf-files/foo.pdf
     ✗ to-convert-word-files/reports/broken.docx → conversion failed: <stderr excerpt>
   ```

If a single file fails, **continue** with the rest. Do not abort the
batch.

---

## Debug mode (`--debug`)

When `--debug` is on:
- Print which converter binary was detected and its version.
- Per file, print the source/dest mtimes, classification reason, the
  exact command run, and elapsed wall time.
- Final summary includes total elapsed wall time and converter used.

When `--debug` is off, output stays terse — one line per file.

---

## Output contract

- Every successful conversion writes exactly one PDF under
  `converted-pdf-files/`, preserving the source's relative path and
  swapping the extension to `.pdf`.
- The skill writes **no** files outside `converted-pdf-files/`.
- Existing up-to-date PDFs are not touched.

---

## Hard rules

- Never write outside `converted-pdf-files/`.
- Never read or modify anything outside `to-convert-word-files/`.
- Parent-escape patterns (`../`) and absolute paths are rejected at
  argument validation.
- Skip `~$*` lock files silently — they are not real documents.
- Per-file failures do not abort the batch.
- `--list` is a pure read; it never writes anything.
- `--debug` only adds instrumentation — it never changes which files
  get converted.
- If no converter binary is available, abort the entire run with a
  clear error message. Do not attempt partial conversions.
