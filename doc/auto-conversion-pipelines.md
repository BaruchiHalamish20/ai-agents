# Auto-Conversion Pipelines — Triggering Skills on File Drops

This project has two conversion skills:

| Source folder              | Skill                                        | Output folder           |
|----------------------------|----------------------------------------------|-------------------------|
| `to-convert-word-files/`   | `/word-to-pdf-suite:convert-to-pdf`          | `converted-pdf-files/`  |
| `converted-pdf-files/`     | `/markdown-converter-suite:convert-to-md`    | `converted-md-files/`   |

Drop a `.docx` and you eventually want a `.md`. The two skills already
chain (PDFs land in the second skill's source folder), so the question
is **how to fire them automatically** when files arrive.

---

## TL;DR — pick one

| Approach                                  | Latency        | Setup                           | Runs when?            | Notes                                     |
|-------------------------------------------|----------------|---------------------------------|------------------------|-------------------------------------------|
| **(a) FileSystemWatcher + `claude -p`**   | ~10 s          | one-time scheduled task at logon| always (background)    | **recommended** — true event-driven       |
| **(b) `/schedule` cron routine**          | minutes        | one slash command               | every N min, always    | simplest if real-time isn't required      |
| **(c) `/loop` in a Claude session**       | minutes        | none persistent                 | only while session open| good for one-off batch days               |

> **Why event-driven wins:** the FileSystemWatcher fires within a second
> of the file landing and converts immediately after a short quiet
> period. Polling burns Claude tokens every tick whether there's work
> or not, and adds a fixed latency floor equal to the tick interval.
> If you drop files sporadically, events are both cheaper and faster.

---

## Option (a) — FileSystemWatcher service [recommended]

### How it works

1. A long-running PowerShell process arms a `FileSystemWatcher` on each
   source folder.
2. Every `Created` / `Changed` / `Renamed` event for a relevant
   extension (`.doc`, `.docx`, `.pdf`, `.html`, `.htm`) updates a
   per-folder **sentinel file** with the current timestamp. Word lock
   files (`~$*`) are ignored.
3. A 2-second tick loop checks each sentinel. When the most recent
   event is older than the **quiet period** (8 s by default), the
   sentinel is consumed and the corresponding skill is invoked
   headlessly:
   ```
   claude -p "/word-to-pdf-suite:convert-to-pdf"
   ```
4. Each skill enumerates its own queue (missing or stale outputs), so
   coalescing many events into a single invocation is correct and
   cheap.

The quiet period is what makes large-file copies safe: Windows fires
events the moment the destination placeholder appears, but the bytes
keep streaming. Waiting 8 s of quiet after the *last* event means the
copy has settled before we touch it.

### Files

| Path                                          | Purpose                                |
|-----------------------------------------------|----------------------------------------|
| `.claude/hooks/watch-and-convert.ps1`         | the watcher service                    |
| `.claude/hooks/install-watcher-task.ps1`      | registers the Windows scheduled task   |
| `.claude/hooks/watch-and-convert.log`         | per-event + per-run log (rolls forever)|
| `.claude/hooks/watch-sentinels/`              | runtime sentinel files (auto-managed)  |

### Install (one time)

```powershell
# From any PowerShell 7 prompt:
pwsh -NoProfile -File "C:\softech\MaarachHadigital\roi-course\RoiTeachme\work\ai-agents\.claude\hooks\install-watcher-task.ps1"
```

This registers a scheduled task named **`ClaudeWatcher-AiAgents`** that
runs `watch-and-convert.ps1` at every user logon, hidden, with restart
on failure. No admin elevation needed — it runs as your own user with
`Limited` privileges.

### Start it now (without logging out)

```powershell
Start-ScheduledTask -TaskName ClaudeWatcher-AiAgents
```

### Verify it's running

```powershell
Get-ScheduledTask -TaskName ClaudeWatcher-AiAgents | Get-ScheduledTaskInfo
Get-Process pwsh | Where-Object { $_.MainWindowTitle -eq '' }     # background pwsh
Get-Content '.\.claude\hooks\watch-and-convert.log' -Tail 20 -Wait
```

Drop a test file into `to-convert-word-files/` and watch the log: you
should see an `event Created …` line within a second, then `-> firing
/word-to-pdf-suite:convert-to-pdf` ~8 s later.

### Stop / disable

```powershell
Stop-ScheduledTask     -TaskName ClaudeWatcher-AiAgents   # one-off stop
Disable-ScheduledTask  -TaskName ClaudeWatcher-AiAgents   # don't auto-start at logon
Unregister-ScheduledTask -TaskName ClaudeWatcher-AiAgents -Confirm:$false   # remove
```

### Viewing the log

Everything the watcher does is appended to
**`.claude/hooks/watch-and-convert.log`**. Pick the form that matches
what you're trying to see:

```powershell
# Tail live (recommended while testing) — Ctrl-C to stop
Get-Content ".\.claude\hooks\watch-and-convert.log" -Tail 30 -Wait

# Last 50 lines snapshot
Get-Content ".\.claude\hooks\watch-and-convert.log" -Tail 50

# Only the fired / done markers (skip the noisy per-event lines)
Get-Content ".\.claude\hooks\watch-and-convert.log" | Select-String '->|<-'

# One watcher only
Get-Content ".\.claude\hooks\watch-and-convert.log" | Select-String 'convert-to-pdf'
Get-Content ".\.claude\hooks\watch-and-convert.log" | Select-String 'convert-to-md'

# From bash if you prefer
tail -f .claude/hooks/watch-and-convert.log
grep -E '->|<-' .claude/hooks/watch-and-convert.log
```

A healthy run looks like:

```
2026-05-13 14:22:10  watcher service started (quiet=8s, tick=2s)
2026-05-13 14:22:11  watcher armed: word on C:\...\to-convert-word-files
2026-05-13 14:22:11  watcher armed: pdf  on C:\...\converted-pdf-files
2026-05-13 14:23:47  event Created C:\...\to-convert-word-files\report.docx
2026-05-13 14:23:55  -> firing /word-to-pdf-suite:convert-to-pdf
2026-05-13 14:24:12     (claude output, indented)
2026-05-13 14:24:12  <- done /word-to-pdf-suite:convert-to-pdf
```

The log rolls forever (no built-in rotation). Truncate it when it
gets large:

```powershell
Clear-Content ".\.claude\hooks\watch-and-convert.log"
```

### Debugging

If something looks wrong, work through these in order — most issues
fall out at step 1 or 2.

**1. Is the watcher process running?**

```powershell
Get-ScheduledTask -TaskName ClaudeWatcher-AiAgents | Get-ScheduledTaskInfo
```

Look at `LastRunTime` and `LastTaskResult` (0 = OK, anything else is
an error code). Then confirm the actual `pwsh` process is alive:

```powershell
Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" |
  Where-Object { $_.CommandLine -match 'watch-and-convert' } |
  Select-Object ProcessId, CommandLine
```

If nothing comes back, the task either hasn't fired yet or crashed.
Start it manually:

```powershell
Start-ScheduledTask -TaskName ClaudeWatcher-AiAgents
```

**2. Is the log empty or stale?**

```powershell
Get-Item ".\.claude\hooks\watch-and-convert.log" |
  Select-Object FullName, Length, LastWriteTime
```

If `LastWriteTime` is old and you just dropped a file, the watcher
isn't seeing the folder. Re-check the `$ProjectRoot` and folder names
at the top of `watch-and-convert.ps1`.

**3. Run the watcher in the foreground to see errors live**

The scheduled task runs hidden — any startup error vanishes silently.
Reproduce in a visible window:

```powershell
pwsh -NoProfile -File ".\.claude\hooks\watch-and-convert.ps1"
```

Drop a test file, watch the console for `event …` and `-> firing …`
lines. Ctrl-C to stop. Common surprises:

- Console window closes immediately → a parse error in the script.
  Run with `pwsh -NoExit -File ...` so the window stays open with the
  error visible.
- `Register-ObjectEvent` warning about MessageData → harmless on
  PowerShell 7, ignore.
- `claude: command not found` → `claude.cmd` isn't on the PATH of the
  user the scheduled task runs as. Fix the PATH or change the script
  to call the full path (`where.exe claude` shows it).

**4. Verify what `claude -p` actually returned**

The watcher captures `claude -p` stdout/stderr into the log with a
3-space indent. If the skill is firing but doing nothing visible,
scroll the log between a `-> firing` and its matching `<- done` —
the indented lines are exactly what Claude printed.

To reproduce the headless call by hand:

```powershell
Push-Location "C:\softech\MaarachHadigital\roi-course\RoiTeachme\work\ai-agents"
claude -p "/word-to-pdf-suite:convert-to-pdf"
Pop-Location
```

**5. Verbose mode — emit events even when no skill fires**

If you suspect events aren't being picked up at all, drop the
extension filter temporarily. In `watch-and-convert.ps1`, inside the
`$action` block, comment out the `Extensions` check:

```powershell
# if ($w.Extensions -notcontains $ext) { return }
```

Restart the watcher. Now *every* file-system event in the watched
folders is logged, including hidden-file noise — useful for proving
the watcher is alive and seeing the right folder. **Revert before
leaving it running**, or you'll fire the skill on garbage.

**6. Increase the log verbosity for one run**

Add a single line at the top of the tick loop in
`watch-and-convert.ps1`:

```powershell
Write-Log "tick: word.sentinel=$([bool](Test-Path $watchers[0].Sentinel)) pdf.sentinel=$([bool](Test-Path $watchers[1].Sentinel))"
```

This logs once every `$TickSec` (2 s by default) so you can see the
sentinels appear and disappear. Remove it after debugging.

**7. Last resort — sentinel diff**

The sentinels live under `.claude/hooks/watch-sentinels/`. If you see
events in the log but no `-> firing` line, check whether the sentinel
exists and what timestamp it holds:

```powershell
Get-ChildItem ".\.claude\hooks\watch-sentinels\"
Get-Content   ".\.claude\hooks\watch-sentinels\word.sentinel"
```

A sentinel that keeps getting touched indicates a file is still being
written (its `Changed` event fires every few seconds and resets the
quiet-period clock). Raise `$QuietSec` or wait for the copy to finish.

### Tuning

Edit the top of `watch-and-convert.ps1`:

- `$QuietSec` — raise if you copy multi-GB files and they aren't done
  in 8 s. Lower if you want snappier response on small files.
- `$TickSec`  — how often the sentinel is checked. Don't go below 1 s.
- `$watchers` — add or remove source/skill pairs here. Each entry is
  self-contained (folder, extensions, skill command, sentinel path).

### Caveats

- Running `claude -p` while you also have an interactive Claude Code
  session open in the same project is fine — they're independent
  processes — but if you're mid-edit you may see the headless session
  write the same files. The skills are designed to be idempotent, so
  this is harmless but can be confusing in `git status`.
- The watcher is per-user. If two people work on the same machine,
  each user gets their own scheduled task.
- Files copied **over SMB / network share** can fire events
  differently. Test before relying on it for remote drops.

### Bootstrapping from a Claude Code SessionStart hook (optional)

If you'd rather have the watcher come up **only when Claude Code is
open** (and shut down when it's not), skip the scheduled task and add a
SessionStart hook to your project settings instead. Add this to
`.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -WindowStyle Hidden -Command \"if (-not (Get-Process -Name pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.CommandLine -match 'watch-and-convert' })) { Start-Process pwsh -ArgumentList '-NoProfile','-WindowStyle','Hidden','-File','${CLAUDE_PROJECT_DIR}\\\\.claude\\\\hooks\\\\watch-and-convert.ps1' -WindowStyle Hidden }\""
          }
        ]
      }
    ]
  }
}
```

That command checks whether the watcher is already running; if not, it
launches it detached. The watcher then keeps running until you sign
out — Claude Code doesn't terminate it on exit, but it's hidden from
the taskbar and consumes ~30 MB.

Pick **scheduled task** for production-style "always on," or
**SessionStart hook** for "only during Claude work sessions."

---

## Option (b) — `/schedule` cron routine

Use this when:
- You don't need second-level latency (a 5-minute lag is fine).
- You don't want a permanent background process.

### Setup

In a Claude Code session, run:

```
/schedule
```

Then create a routine that runs both skills every 5 minutes:

```
Create a routine named "watch-and-convert" that runs every 5 minutes
and executes:
  /word-to-pdf-suite:convert-to-pdf
  /markdown-converter-suite:convert-to-md
```

The `/schedule` skill builds a cron entry that fires a fresh Claude
remote-agent run on that cadence. Both skills are no-ops when their
queues are empty, so the polling itself is cheap.

### Trade-offs vs Option (a)

- Each tick spins up a fresh Claude run regardless of whether work
  exists — small token cost per tick.
- Latency = `tick_interval / 2` on average, `tick_interval` worst case.
- No machine-local infra: the schedule lives server-side, so it
  survives your laptop being off (but it also fires when your laptop
  is off, which may or may not matter to you).

---

## Option (c) — `/loop` while you're at the keyboard

Use this when:
- You have a one-time batch day ("I just dumped 200 Word files in
  there, keep converting until done").
- You're going to be in the session anyway.

### Setup

In a Claude Code session:

```
/loop 2m /word-to-pdf-suite:convert-to-pdf
```

The harness re-fires the prompt every 2 minutes until you stop the
loop. You can chain with `&&` to also run the markdown step, or open a
second loop in a second session.

### Trade-offs vs Option (a)

- Only runs while the session is open. Close the window, no more
  conversions.
- Foreground: the loop occupies the session's main turn.
- Best for short, focused work — not a long-term solution.

---

## Picking one in practice

- **Always-on workstation, files trickle in throughout the day:**
  Option (a) with the scheduled task.
- **Only convert when you sit down to work:** Option (a) but skip the
  scheduled task and use the SessionStart hook variant.
- **Batch days only, infrequent use:** Option (c) — `/loop`.
- **Convert nightly regardless of presence:** Option (b) — `/schedule`
  with a once-a-day routine.

The event-driven approach is the closest analog to a "real" file
pipeline (think Logic Apps, Event Grid, S3 + Lambda, inotifywait).
Polling is a fine fallback when latency isn't a constraint, but it's
strictly less efficient.
