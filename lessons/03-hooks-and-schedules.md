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
> a small shell script under `.claude/hooks/`, `.gitignore` (one line for
> the hook's audit log), and the `/schedule` / `/loop` slash commands.
> Optionally `reports/` if you check artifacts.
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

echo "$(date -Iseconds) inject-latest-alert-summary fired" >> .claude/hooks/.audit.log

LATEST="$(ls -t reports/*.md 2>/dev/null | head -n1 || true)"
if [[ -z "${LATEST}" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No prior alert reports found under reports/."}}\n'
  exit 0
fi

MTIME="$(date -r "${LATEST}" -Iseconds 2>/dev/null || stat -c '%y' "${LATEST}" 2>/dev/null || echo unknown)"

# Extract the "## Summary" section (between "## Summary" and the next H2).
SUMMARY="$(awk '/^## Summary/{flag=1; next} /^## /{flag=0} flag' "${LATEST}")"

PAYLOAD="A Pikud HaOref alert report was generated at ${MTIME}.
File: ${LATEST}

Summary:
${SUMMARY}

Instructions for Claude:
- When the user asks about current/recent alert state, answer from the summary above.
- Do NOT invoke the /alert-report skill or the pikud-alerts agent unless the user explicitly asks for fresh data, a new time window, or a region filter, or if the timestamp above is older than 6 hours relative to the current Israel local time."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
  "$(printf '%s' "${PAYLOAD}" | jq -Rs '.')"
```

Make it executable: `chmod +x .claude/hooks/inject-latest-alert-summary.sh`.

Add the audit log to `.gitignore` so it doesn't get committed:

```
.claude/hooks/.audit.log
```

#### Why this shape — four things worth pausing on

1. **`jq -Rs '.'` for JSON encoding.** `jq` is already a sane dev-machine
   dependency (you used it in Task 3 to inspect output), so reusing it
   for the encoding side keeps the script free of Python and avoids the
   awkward `printf` quoting dance. `-R` reads raw input (no JSON
   parsing), `-s` slurps all stdin into a single string, `.` emits it
   as a properly-escaped JSON string literal.
2. **`hookEventName` in the response.** The `hookSpecificOutput` block's
   schema is event-specific, so the response must identify which event
   it's responding to. Omitting `hookEventName` is a silent
   misconfiguration — the harness may discard your `additionalContext`
   without an obvious error.
3. **The audit log.** Hooks run silently — there is no built-in
   per-fire log you can grep. A single `>> .audit.log` line gives you
   an immutable "did this hook actually fire?" signal you can inspect
   independently of Claude Code's own logging. Worth a few cents of
   disk; saves hours of "I think the hook is broken" debugging.
4. **Behavioral guidance, not just data.** The payload doesn't only
   inject the summary — it also tells Claude *when not to refetch*
   ("don't invoke the skill unless the user asks for fresh data or
   the timestamp is over 6 hours old"). Without that, Claude's default
   behavior on "what's the alert state?" is to invoke the skill and
   re-fetch — defeating the point of the hook. A hook that injects
   data without the corresponding behavioral guidance is half a hook.

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
*without* you naming the file. It should also **not** invoke
`/alert-report` or the `pikud-alerts` agent — the behavioral guidance
in the payload tells it to answer from the injected summary unless the
report is stale.

Three independent debug signals if it doesn't work:

1. **Does the hook fire at all?** Tail the audit log:
   `tail -n 5 .claude/hooks/.audit.log`. One new ISO timestamp per
   session start. If empty, the hook isn't wired or the script isn't
   executable.
2. **Does the script produce valid JSON?**
   `bash .claude/hooks/inject-latest-alert-summary.sh | jq .` — should
   print a parsed object with `hookSpecificOutput.hookEventName` and
   `hookSpecificOutput.additionalContext`. A `jq` parse error here
   means the script is broken; fix that before anything else.
3. **Does Claude Code accept the response?** Run with `claude --debug`
   and look for `additionalContext` being injected (or rejected with a
   schema error — usually a missing `hookEventName`).

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

## 5. Managing routines beyond `/schedule`

Task 4 used `/schedule` because it's the lowest-friction path inside Claude
Code. It's not the only path. Routines are server-side objects in your
claude.ai account — anything that can talk HTTP to claude.ai can manage
them. There are three management surfaces, all backed by the same
database:

| Path | When to reach for it | Auth |
|---|---|---|
| **Web UI** — <https://claude.ai/code/routines> | One-off changes; you want to *see* the routine you're editing | Browser session |
| **`/schedule`** inside Claude Code | Conversational create / list / update / run; you're already in a session | CLI auth (OAuth or API key) |
| **HTTP API** — `https://claude.ai/api/code/triggers` | Scripting, CI, "routines as code" | claude.ai session cookie or OAuth token |

The mechanic of routines created here is identical no matter the path.
A routine made via `/schedule` is editable in the web UI; a routine made
via `curl` is listable from `/schedule list`. There is no separate
"API routine" type — only one routine type, three doors.

### 5.1. The web UI

Open <https://claude.ai/code/routines> → **New routine**. The form asks
for the same fields the API does: name, cron, repo, prompt, model,
optional MCP connectors. Save and the routine is live. Use this when
you want to *see* the shape of a routine while editing it — the form
validates cron expressions and surfaces enabled/next-run state more
clearly than a curl response.

### 5.2. Finding your `sessionKey` cookie

The API authenticates browser-style: a `Cookie: sessionKey=…` header.
You copy that value from your logged-in browser session. There is no
separate "create an API key for claude.ai" step — the cookie *is* the
credential.

**Chrome / Edge:**

1. Open <https://claude.ai/> in your normal browser, signed in as the
   account that owns the routines.
2. Press **F12** → **Application** tab → **Storage** → **Cookies** →
   `https://claude.ai`.
3. Find the row whose Name column is **`sessionKey`**. Copy its
   **Value** column (it'll be a long opaque string).

**Firefox:**

1. Same URL, signed in.
2. **F12** → **Storage** tab → **Cookies** → `https://claude.ai`.
3. Click the `sessionKey` row → copy the value field.

**From the on-disk cookie store (alternative, rarely worth it):**

| Browser | Windows | macOS | Linux |
|---|---|---|---|
| Chrome | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Network\Cookies` | `~/Library/Application Support/Google/Chrome/Default/Cookies` | `~/.config/google-chrome/Default/Cookies` |
| Edge | `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Network\Cookies` | `~/Library/Application Support/Microsoft Edge/Default/Cookies` | `~/.config/microsoft-edge/Default/Cookies` |
| Firefox | `%APPDATA%\Mozilla\Firefox\Profiles\<profile>\cookies.sqlite` | `~/Library/Application Support/Firefox/Profiles/<profile>/cookies.sqlite` | `~/.mozilla/firefox/<profile>/cookies.sqlite` |

Both files are SQLite databases. Chrome/Edge encrypt the `value` column
with DPAPI (Windows) or Keychain (macOS), so reading it from disk
requires platform-specific decryption — usually not worth the effort
versus a 5-second copy from DevTools. Firefox stores cookie values in
plaintext in `moz_cookies`.

**Treat the cookie like a password.** Anyone holding it can act as you
on claude.ai until it expires.

- Never commit it to git. Never paste it in chat, a screenshot, a
  shared doc, or a CI log.
- If you have to put it in an env var, scope it to the current shell
  only (`export SESSION_KEY=...` then `unset SESSION_KEY` when done).
- Rotate immediately on suspected leak: sign out of all claude.ai
  sessions from <https://claude.ai/settings/account>, then sign back
  in. Old cookies are invalidated.
- For long-lived automation (CI, cron on a server), prefer a Claude
  Code OAuth token over the session cookie — tokens are revocable
  per-device from the account settings; the session cookie is not.

### 5.3. Calling the API with `curl`

Endpoint base: `https://claude.ai/api/code/triggers`.

| Method | Path | Action |
|---|---|---|
| `GET`  | `/api/code/triggers` | List all routines |
| `GET`  | `/api/code/triggers/{id}` | Fetch one |
| `POST` | `/api/code/triggers` | Create (body required) |
| `POST` | `/api/code/triggers/{id}` | Update (partial body) |
| `POST` | `/api/code/triggers/{id}/run` | Trigger an immediate run |

Deletion is **web UI only** — there is no `DELETE` endpoint.

Create the same hourly digest from Task 4 with `curl`:

```bash
SESSION_KEY="<paste value from DevTools>"
REPO="https://github.com/<you>/ai-agents"
ENV_ID="env_011CUZPQ9mczgxzSjjw36rjS"   # from /schedule's environment list

curl -sX POST https://claude.ai/api/code/triggers \
  -H "Content-Type: application/json" \
  -H "Cookie: sessionKey=${SESSION_KEY}" \
  -d '{
    "name": "pikud-hourly-digest",
    "cron_expression": "0 * * * *",
    "enabled": true,
    "job_config": {
      "ccr": {
        "environment_id": "'"${ENV_ID}"'",
        "session_context": {
          "model": "claude-haiku-4-5",
          "sources": [{"git_repository": {"url": "'"${REPO}"'"}}],
          "allowed_tools": ["Bash","Read","Write","Edit","Glob","Grep"]
        },
        "events": [{
          "data": {
            "uuid": "'"$(uuidgen | tr "[:upper:]" "[:lower:]")"'",
            "session_id": "",
            "type": "user",
            "parent_tool_use_id": null,
            "message": {
              "role": "user",
              "content": "Run /alert-report 24 in this repo. Write the report to reports/ and return the path."
            }
          }
        }]
      }
    }
  }' | jq .
```

The response includes the new routine's `id`. From there:

```bash
# List
curl -s -H "Cookie: sessionKey=${SESSION_KEY}" \
  https://claude.ai/api/code/triggers | jq '.data[] | {id, name, cron_expression, enabled, next_run_at}'

# Run now
curl -sX POST -H "Cookie: sessionKey=${SESSION_KEY}" \
  https://claude.ai/api/code/triggers/<id>/run

# Disable
curl -sX POST -H "Cookie: sessionKey=${SESSION_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  https://claude.ai/api/code/triggers/<id>
```

**Rules the API will enforce — write them on the wall:**

- **Cron is always UTC.** Convert from your local time yourself. The
  API will not reinterpret your expression.
- **Minimum interval is 1 hour.** `*/30 * * * *` is rejected.
- **One-off run:** swap `cron_expression` for
  `"run_once_at": "YYYY-MM-DDTHH:MM:SSZ"` (RFC3339 UTC, must be in the
  future). Fires once, then auto-disables.
- **Fresh UUIDv4 per create.** `events[].data.uuid` must be a
  lowercase v4 — generate one each time. Reusing a UUID across creates
  is undefined behavior.
- **Sandbox is stateless.** Every run starts a fresh checkout, no
  memory of previous runs. Anything you want to persist must be
  written to a commit, a PR, or an external channel inside the run.

### 5.4. When to prefer which path

| Situation | Use |
|---|---|
| You're already in a Claude Code session and want to create or tweak one routine | `/schedule` |
| You want to see / sort / disable a few routines visually | Web UI |
| You want a routine definition checked into git (IaC) and applied from CI | API + `curl` (or a thin wrapper script) |
| You're rotating a routine's prompt every week from a script | API |
| You need to delete a routine | Web UI (only option) |

The API path is the only one that lets you treat routines as code. If
you ever find yourself recreating the same routine across machines,
people, or accounts, write the JSON body once, check it into the repo,
and `curl` it in — it's the SDD treatment for routines themselves.

---

## 6. Verification checklist

- [ ] `.claude/hooks/inject-latest-alert-summary.sh` is executable and
      produces valid JSON when run standalone (`bash <script> | jq .`
      parses cleanly and includes both `hookEventName` and
      `additionalContext`).
- [ ] `.claude/settings.json` contains a `SessionStart` hook entry.
- [ ] `.claude/hooks/.audit.log` is listed in `.gitignore` and gains a
      new line every time a session starts.
- [ ] A fresh session opens with Claude already aware of the latest
      report's summary, without prompting — and **without** invoking
      `/alert-report` or the `pikud-alerts` agent.
- [ ] `/schedule list` shows `pikud-hourly-digest` with cron `0 * * * *`.
- [ ] After the next hour boundary, `reports/` has a new file from the
      routine (timestamp ~ top of the hour).
- [ ] `/loop 5m /alert-report 1` runs at 5-minute intervals; `Esc` cancels
      it cleanly.
- [ ] `git status` shows the hook script and `settings.json` as the only
      added/modified files in this lesson (plus whatever the routine
      writes to `reports/` if you ran it).

---

## 7. Stretch (optional)

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
