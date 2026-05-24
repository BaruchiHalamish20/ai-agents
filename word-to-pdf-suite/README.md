# word-to-pdf-suite

Bundles the Word (`.doc` / `.docx`) → PDF batch conversion workflow as a single plugin.

---

## Overview

`word-to-pdf-suite` keeps `converted-pdf-files/` in sync with whatever is sitting under `to-convert-word-files/`. The skill enumerates the queue (missing or stale by mtime) and drives an external converter binary directly — there is **no per-file agent**, because DOCX→PDF is a mechanical binary transform, not an interpretive read. Pair this plugin with `markdown-suite` to chain DOCX → PDF → Markdown in one workflow.

Detection at run time: prefers `soffice` / `libreoffice` (headless), falls back to `pandoc` (needs a LaTeX engine for PDF output). If neither is available, the skill aborts cleanly with a clear error rather than producing partial output.

---

## Plugin contents

- **Skill** `skills/convert-to-pdf/SKILL.md` — `/convert-to-pdf [pattern] [--list] [--debug]`. Batch converter: enumerates `.doc` / `.docx` under `to-convert-word-files/`, classifies each as `missing` / `stale` / `up-to-date`, invokes the detected converter once per pending file, reports a final summary. `--list` is a dry-run; `--debug` prints the binary detected, per-file mtimes, the exact command run, and elapsed wall time.

The plugin ships **no agent and no hooks** — it's a pure user-triggered tool. A SessionStart conversion-queue notification could be added later mirroring `markdown-suite`, but for v1 the skill is self-contained.

The lessons that built each piece live in `../lessons/02-skills.md` and `../lessons/04-plugins.md`.

---

## Testing the plugin

**Dry-run inside Claude Code:**

```
/convert-to-pdf --list
```

Should print the pending queue with one line per file and **not** convert anything. Word lock files (`~$*.docx`) are silently skipped.

**Binary detection check (no Claude required):**

```bash
command -v soffice || command -v libreoffice || command -v pandoc
# expect: a path to whichever converter is installed
# if all three are missing, /convert-to-pdf will abort with a clear error
```

**End-to-end conversion:**

Drop a small `.docx` into `to-convert-word-files/`, then:

```
/convert-to-pdf
```

Verify a corresponding `.pdf` appears under `converted-pdf-files/` with the same relative path. Re-running with no changes should report all files `up-to-date` and skip them. From there, `/convert-to-md` will pick the PDF up and convert it to Markdown — the two suites compose.
