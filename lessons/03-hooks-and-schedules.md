# Lesson 3 — Hooks & schedules: the third trigger model

> **Goal:** Make the alert workflow run *without you typing*. A hook fires
> when the session starts and pre-loads the latest alert state. A
> scheduled routine produces an hourly digest in the cloud, even when
> your laptop is asleep. A short-lived `/loop` polls the alert endpoint
> every few minutes during an active incident. By the end of this
> lesson, you'll have felt all three trigger models — model, user, and
> system — for the same workflow.
>
> **Time:** ~45 minutes.
> **You will touch:** `.claude/settings.json` (or `~/.claude/settings.json`),
> a small shell script under `.claude/hooks/`, and the `/schedule` /
> `/loop` slash commands. Optionally `reports/` if you check artifacts.
>
> **Source of truth:**
> - Hooks — <https://code.claude.com/docs/en/hooks.md>
> - Routines / `/schedule` — <https://code.claude.com/docs/en/routines.md>
> - `/loop` — <https://code.claude.com/docs/en/scheduled-tasks.md>

---

## 1. Concept — what changes when *the system* is the trigger?

### The trilogy you've now seen

| Trigger model       | Lesson | Who fires it                        | Where it runs                        |
|---------------------|--------|-------------------------------------|--------------------------------------|
| **Model-triggered** | 1      | Main Claude decides to delegate     | Isolated sub-agent context           |
| **User-triggered**  | 2      | You type a slash command            | Inline in the calling session        |
| **System-triggered**| 3      | A clock or event fires              | Hook process, local loop, or cloud   |

The third row is what this lesson teaches. There are three sub-mechanisms,
and the right one depends on *when the trigger lives*:

| Mechanism                           | Fires on                          | Lifetime          | Min interval | Where it runs           |
|-------------------------------------|-----------------------------------|-------------------|--------------|-------------------------|
| **Hooks** (`settings.json`)         | Claude Code events                | Across sessions   | event-driven | Local shell / HTTP / MCP |
| **`/loop`** (in-session)            | Interval ticks                    | ≤ 7 days, current session resumable | 1 minute     | Local Claude Code       |
| **`/schedule` → routine**           | Cron tick                         | Persistent (cloud account)          | 1 hour       | Anthropic cloud runner  |

### What a hook actually executes

Hooks declared in `.claude/settings.json` fire on events like
`SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`.
The hook handler can be one of five types — `command` (shell),
`http` (POST), `mcp_tool`, `prompt` (model yes/no), or `agent`
(read-only sub-agent).

Two important honest caveats — *do not teach these as features they
aren't*:

1. **A hook cannot type into the conversation as if you typed it.** It
   can return `additionalContext` (string injected into Claude's
   context) or `updatedInput` (modify a tool call) via JSON on stdout,
   or block a tool call via exit code 2. There is no "stdin pipe to
   the user prompt".
2. **Hook → skill chaining is not officially documented.** The reference
   shows hooks running shell/HTTP/MCP/prompt/agent. Don't promise "a
   hook that runs `/alert-report`" until/unless Anthropic documents that
   path.

### Routines (the cloud cron) vs `/loop` (the local cron)

`/schedule` creates **routines** — persistent cron-backed tasks that run
on Anthropic-hosted infrastructure, on a fresh Claude Code cloud session
each time, with a clean context window. Minimum interval 1 hour. Persists
in your claude.ai account, **not in git**.

`/loop` creates an in-session recurring run. Local. 1-minute minimum.
Expires after 7 days or when the session is closed and not resumed.
Bare `/loop <prompt>` lets the model self-pace; `/loop 5m <prompt>` locks
to a fixed interval.

The decision rule:

- **Need it to run when your laptop is closed?** → routine.
- **Active monitoring during an incident?** → `/loop`.
- **Reaction to a specific Claude Code event (session opened, tool
  called)?** → hook.

---

## 2. Spec — what to wire up around `/alert-report`

Following SDD: contract before code.

**Inputs:** The existing `pikud-alerts` agent (Lesson 1) and `/alert-report`
skill (Lesson 2). No new code in either — this lesson is about
*triggers*, not logic.

**Outputs:** Three new artifacts, one per mechanism.

1. **`SessionStart` hook** — when a Claude Code session opens in this
   project, read the most recent file in `reports/` and inject its
   `## Summary` section as `additionalContext`. So Claude knows the
   current alert state without you asking.
2. **One routine via `/schedule`** — runs `/alert-report 24` every hour
   on the hour. Saves the result to a fresh report file in the repo (or
   sends to a connector if configured).
3. **One `/loop` snippet** — for monitoring an active situation: run
   `/alert-report 1` every 5 minutes, capped at 2 hours by the natural
   `/loop` 7-day expiry (you'll stop it manually with `Esc`).

**Out of scope (v1):**
- Hook → skill chaining (undocumented).
- Cross-machine routine sharing (routines are account-scoped, not
  source-controlled).
- Email / Slack delivery from routines (requires MCP connector setup
  beyond this lesson).

**Success criteria:**
- Opening a fresh Claude Code session in this project causes Claude to
  reference the latest alert state in its first reply, without you
  asking.
- The routine produces a new file under `reports/` (or a connector
  destination) every hour, with no human typing.
- Stopping a `/loop` with `Esc` cleans up — no orphaned state.

---

## 3. Plan — design decisions

| Decision                                  | Choice                                       | Why                                                                                              |
|-------------------------------------------|----------------------------------------------|--------------------------------------------------------------------------------------------------|
| Hook event                                | `SessionStart`                               | Fires once when you open the project; lowest noise, highest leverage moment.                      |
| Hook handler type                         | `command` (shell script)                     | Cheapest. POSIX-portable. The script reads the latest `reports/*.md` and emits JSON on stdout.    |
| Hook scope                                | Project (`.claude/settings.json`)            | Travels with the repo for any contributor. Same precedence rule as agents.                        |
| Hook output                               | `additionalContext` only                     | Honest with the platform — no fake "user typing". Just give Claude the context.                   |
| Routine schedule                          | `0 * * * *` (every hour)                     | One hour is the floor for routines. Hourly is plenty for a report.                                |
| Routine prompt                            | Natural language instructing `/alert-report` | Routines accept prompts; the cloud Claude invokes the skill the same way you do.                  |
| `/loop` interval                          | `5m`                                         | Tight enough for active monitoring, slow enough to avoid flooding `reports/`.                     |
| Where the routine writes                  | Repo via `Write` tool                        | Simplest. No connector setup. Output appears as ordinary report files.                            |

---

## 4. Tasks — hands-on

### Task 1 — Write the SessionStart hook script

Create `.claude/hooks/inject-latest-alert-summary.sh`:

```bash
#!/usr/bin/env bash
# Reads the newest reports/*.md and emits its Summary section as
# additionalContext for Claude to load at session start.
set -euo pipefail

LATEST="$(ls -t reports/*.md 2>/dev/null | head -n1 || true)"
if [[ -z "${LATEST}" ]]; then
  printf '{"hookSpecificOutput":{"additionalContext":"No prior alert reports found under reports/."}}\n'
  exit 0
fi

# Extract the "## Summary" section (between "## Summary" and the next H2).
SUMMARY="$(awk '/^## Summary/{flag=1; next} /^## /{flag=0} flag' "${LATEST}")"
PAYLOAD="Latest report: ${LATEST}\n\nSummary:\n${SUMMARY}"

# Emit JSON. jq would be cleaner; using printf to keep deps to bash + coreutils.
printf '{"hookSpecificOutput":{"additionalContext":%s}}\n' \
  "$(printf '%s' "${PAYLOAD}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
```

Make it executable: `chmod +x .claude/hooks/inject-latest-alert-summary.sh`.

### Task 2 — Wire the hook in `settings.json`

Edit `.claude/settings.json` (create it if missing):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/inject-latest-alert-summary.sh"
          }
        ]
      }
    ]
  }
}
```

### Task 3 — Verify the hook

Close and reopen Claude Code in this project (or start a fresh
session). In your first message, ask:

> "What's the current alert state?"

Claude should answer with a summary that came from the latest report
*without* you naming the file. If it doesn't, run the script directly
to confirm it produces valid JSON (`bash .claude/hooks/inject-latest-alert-summary.sh | jq .`),
then check `claude --debug` output for hook errors.

### Task 4 — Create the hourly routine

In Claude Code, type:

```
/schedule
```

When prompted (form or natural-language flow), supply:

- **Name:** `pikud-hourly-digest`
- **Prompt:** `Run /alert-report 24 inside this repository, then write the result to reports/ with the standard YYYY-MM-DD-HHmm.md filename. Do not commit. Return the path of the file written.`
- **Cron:** `0 * * * *` (top of every hour)
- **Repository:** this project (the routine needs access).

Confirm it appears under `/schedule list`.

### Task 5 — Verify the routine

Wait for the next top-of-hour, or use `/schedule run pikud-hourly-digest`
(if exposed) to fire it immediately. Confirm a new file appears in
`reports/` with a fresh timestamp. Note that routine runs happen in a
**fresh cloud session** — the routine has no memory of previous runs and
no awareness of your local conversation.

### Task 6 — Run a `/loop` for active monitoring

When something is unfolding (or just to test), run:

```
/loop 5m /alert-report 1
```

Every 5 minutes, the loop fires `/alert-report 1` (last 1 hour window).
Watch the `reports/` directory grow. Press `Esc` when you've seen
enough. The loop expires automatically after 7 days even if you forget.

---

## 5. Verification checklist

- [ ] `.claude/hooks/inject-latest-alert-summary.sh` is executable and
      produces valid JSON when run standalone.
- [ ] `.claude/settings.json` contains a `SessionStart` hook entry.
- [ ] A fresh session opens with Claude already aware of the latest
      report's summary, without prompting.
- [ ] `/schedule list` shows `pikud-hourly-digest` with cron `0 * * * *`.
- [ ] After the next hour boundary, `reports/` has a new file from the
      routine (timestamp ~ top of the hour).
- [ ] `/loop 5m /alert-report 1` runs at 5-minute intervals; `Esc` cancels
      it cleanly.
- [ ] `git status` shows the hook script and `settings.json` as the only
      added/modified files in this lesson (plus whatever the routine
      writes to `reports/` if you ran it).

---

## 6. Stretch (optional)

Pick one before declaring the trilogy complete:

1. **Hook on `PostToolUse`.** Add a hook that fires after the
   `/alert-report` skill writes a file and commits it to a feature
   branch automatically. Reason about whether automated commits are
   desirable here (they probably aren't — but it's an instructive
   exercise).
2. **Two coordinated routines.** Schedule a daily 09:00 routine that
   reads the previous 24 hours of `reports/*.md` and produces a single
   digest. Now you have a *meta-report* generator running on its own
   clock. Notice how the routine has no memory between runs — every
   digest is regenerated from scratch from on-disk state.
3. **Block a destructive tool.** Add a `PreToolUse` hook with matcher
   `Bash` that exits with code 2 (blocking) when the command starts
   with `rm -rf`. Run a test session with that hook on. Reflect on
   what hooks let you enforce that prompt-engineering alone can't.
4. **Move from `/loop` to a routine.** Take a 5-minute `/loop` you ran
   during a real incident, then convert its prompt to a one-shot
   routine that runs at a future fixed time (e.g. *"run this once at
   2026-05-15 06:00"*). Notice how the same prompt expresses both a
   live monitor and a scheduled future job depending on the trigger.

---

## What you should now believe

- **Three trigger models cover everything.** Model decides (agent), user
  decides (skill), system decides (hook / loop / routine). Most real
  workflows are a composition of two or three.
- **Hooks are deterministic glue, not magic.** They fire on platform
  events, return JSON, and integrate with Claude's context — but they
  do not pretend to be the user. Honest about that boundary, hooks are
  reliable; dishonest about it, they break.
- **Routines are out-of-process, in-cloud, account-scoped.** They are
  not part of the repo. Treat them as *organizational state* (like a
  cron tab on a server you share with your team), not *project state*.
- **`/loop` and `/schedule` are not interchangeable.** Same surface
  syntax, completely different semantics. Loop = local + short +
  ephemeral. Schedule = cloud + long + persistent. Picking the wrong
  one is the most common rookie mistake.
- **The same workflow expressed three different ways teaches you the
  difference.** Lesson 1 made the agent. Lesson 2 made the skill.
  Lesson 3 made it run on its own. The thing being run is identical.
  The trigger model is everything.

You've now built and felt the full Claude Code surface for orchestrating
work. From here, the lessons branch into specialization — observability,
governance, distribution (plugins), and enterprise rollout. None of those
introduce a new trigger model; they're variations on the three you now
own.
