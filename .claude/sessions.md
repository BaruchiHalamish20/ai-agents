# Claude Code session bookmarks — ai-agents project

Manually maintained map of session UUIDs to friendly names. Claude Code does
**not** support a `/rename` command; the picker (`claude -r`) only matches the
auto-generated `aiTitle`. Use this file to look up a UUID and resume directly:

```
claude -r <uuid>
```

Session JSONL files live in:
`~/.claude/projects/C--softech-MaarachHadigital-roi-course-RoiTeachme-work-ai-agents/`

---

## current-conversation
- **UUID:** `194a7774-8cf4-4d7c-ae50-eef0594e19a5`
- **Started:** 2026-05-10 07:57 IDT
- **Last activity:** 2026-05-10 12:00 IDT
- **Size:** 148 lines / 219 KB
- **AI title:** "Write daily alert report with pikud-alerts agent"
- **Focus:** Today's pikud-alerts runs (last_n_hours=48), then meta-discussion about session persistence, memory, and `/rename`.
- **Resume:** `claude -r 194a7774-8cf4-4d7c-ae50-eef0594e19a5`

## brief-restart
- **UUID:** `b63580c1-85fc-4b46-9bd9-de74667a5c05`
- **Started:** 2026-05-10 08:58 IDT
- **Last activity:** 2026-05-10 11:59 IDT
- **Size:** 11 lines / 15 KB
- **AI title:** "Generate 48-hour alert report with pikud-alerts"
- **Focus:** Started with the same pikud-alerts prompt; barely got past the first turn — likely a stub session opened in another terminal.
- **Resume:** `claude -r b63580c1-85fc-4b46-9bd9-de74667a5c05`

## original-pikud-thread
- **UUID:** `598ba2e0-4118-46dc-847d-954c62c6855b`
- **Started:** 2026-05-07 19:21 IDT
- **Last activity:** 2026-05-10 11:51 IDT
- **Size:** 346 lines / 778 KB
- **AI title:** "Write daily alert report with pikud-alerts"
- **Focus:** The original, multi-day pikud-alerts thread — built up the agent and produced reports across May 7–10. Largest history; richest context.
- **Resume:** `claude -r 598ba2e0-4118-46dc-847d-954c62c6855b`

---

## How to refresh this file

When sessions move on, regenerate by reading:
- File metadata: `ls -lt ~/.claude/projects/<this-project-dir>/*.jsonl`
- AI titles: `grep '"aiTitle"' <file>.jsonl | head -1`
- First user message: `head -3 <file>.jsonl | grep '"role":"user"'`
