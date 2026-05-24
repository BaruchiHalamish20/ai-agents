# markdown-suite

Bundles the PDF/HTML → Markdown conversion workflow as a single plugin.

---

## Overview

`markdown-suite` keeps `converted-md-files/` in sync with whatever is sitting under `converted-pdf-files/`. The skill enumerates the queue, the agent does the per-file interpretive work, and a `SessionStart` hook tells you on every new session how many sources are still pending. The split between *batch orchestrator* (skill) and *single-file worker* (agent) is deliberate — each file gets a clean isolated agent context so converting a 200-page PDF doesn't pollute the orchestrator with the document's full text.

Source formats supported: `.pdf`, `.html`, `.htm` (case-insensitive). Output is Markdown with preserved heading hierarchy, lists, tables, code blocks, and inline image descriptions. The path layout under `converted-pdf-files/` is mirrored verbatim under `converted-md-files/` — only the extension flips to `.md`.

---

## Plugin contents

- **Agent** `agents/markdown-converter.md` — single-file worker. Reads one source under `converted-pdf-files/` and writes the Markdown rendering to `converted-md-files/`. Tools restricted to `Read, Write, Glob`.
- **Skill** `skills/convert-to-md/SKILL.md` — `/convert-to-md [pattern] [--list] [--debug]`. Batch orchestrator: enumerates the queue (missing or stale by mtime), dispatches the agent once per pending file, reports a final summary. `--list` is a dry-run; `--debug` adds per-file instrumentation and a `## Debug log` section to each output.
- **`SessionStart` hook** `hooks/inject-conversion-queue.sh` — reports the pending queue count (e.g. *"1 pending, 3 up-to-date"*) at session start. Reports only — never triggers conversion automatically.

The lessons that built each piece live in `../lessons/01-custom-agent.md`, `02-skills.md`, `03-hooks-and-schedules.md`, and `04-plugins.md`.

---

## Testing the plugin

**Hook (no Claude required):**

```bash
markdown-suite/hooks/inject-conversion-queue.sh ; echo "exit=$?"
# expect: a "Markdown conversion queue: N pending, M up-to-date" summary, exit=0
```

**Skill dry-run inside Claude Code:**

```
/convert-to-md --list
```

Should print the pending queue with one line per file and **not** write anything. Useful before a large run.

**End-to-end conversion:**

Drop a small PDF into `converted-pdf-files/`, then:

```
/convert-to-md
```

Verify a corresponding `.md` appears under `converted-md-files/` with the same relative path. Re-running with no changes should report all files `up-to-date` and skip them.
