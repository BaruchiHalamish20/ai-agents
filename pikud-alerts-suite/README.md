# pikud-alerts-suite

Bundles the Pikud HaOref alert workflow as a single plugin:

- **Agent** `agents/pikud-alerts.md` — fetches data from oref.org.il.
- **Skill** `skills/alert-report/SKILL.md` — `/pikud-alerts-suite:alert-report [hours] [region] [--debug]`.
- **`SessionStart` hook** `hooks/inject-latest-alert-summary.sh` — injects the most recent report's summary into the new session's context.
- **`PreToolUse` hook** `hooks/block-removing-reports.sh` — *project-wide* guardrail that blocks any `Bash` command containing `rm` / `rmdir` / `unlink` and the substring `reports`. See below — this hook is not pikud-specific.

The lessons that built each piece live in `../lessons/01-custom-agent.md`, `02-skills.md`, `03-hooks-and-schedules.md`, and `04-plugins.md`.

---

## Why a project-wide guardrail lives in this plugin

The `block-removing-reports.sh` hook protects every plugin's reports output, not just this one's. It sits here because:

1. **This plugin owns `reports/`** — the `/alert-report` skill is what creates the files the guardrail protects. Proximity wins over abstraction.
2. **One copy is sufficient** — Claude Code hooks are session-scoped, not plugin-scoped (next section). Three plugins shipping the same hook is redundant; one plugin shipping it is enough.

But this choice has a real cost — see *"The coupling risk"* below.

---

## How a hook in this plugin fires when another plugin acts

**The single most important fact:** hooks are scoped to the *session*, not to the *plugin that initiated the action*. Once a plugin is enabled, its hooks subscribe to lifecycle events for everything in the session.

The model:

1. At session start (and on `/reload-plugins`), every enabled plugin's `hooks.json` registers as a **subscription** to its declared events (`PreToolUse`, `SessionStart`, etc.).
2. When *anything* triggers a `PreToolUse` event — main Claude, a routine, a `/loop`, a sub-agent invoked by `tzevaadom-alerts-suite`, even a skill from `markdown-converter-suite` — the harness consults *all* active subscriptions and runs every matching script.
3. The hook script receives a generic payload: `tool_name`, `tool_input`. It has no field telling it which plugin (or whether any plugin at all) initiated the call — and it doesn't need one.

Concretely:

```
Origin (any plugin or main Claude)
   └─ Bash tool call:  rm -rf reports/
        └─ PreToolUse event fires
             ├─ check all enabled PreToolUse subscriptions
             │     ├─ pikud-alerts-suite      → block-removing-reports.sh runs  ← exits 2, blocks
             │     ├─ tzevaadom-alerts-suite  → no PreToolUse subscription      ← nothing happens
             │     └─ markdown-converter-suite → no PreToolUse subscription     ← nothing happens
             └─ result: blocked
```

So a `rm -rf reports/` issued by a `tzevaadom-alerts-suite` skill — or by main Claude, or by a routine — is blocked by *this* plugin's hook. The hook doesn't know or care which plugin initiated the call.

---

## The coupling risk — read this before disabling the plugin

Putting a project-wide guardrail inside one plugin makes the guarantee **conditional on that plugin staying enabled**.

The day someone runs:

```
/plugin disable pikud-alerts-suite@ai-agents-local
```

…the guardrail silently disappears. The hook script still sits on disk; its subscription just isn't loaded into the session. Now `tzevaadom-alerts-suite`, `markdown-converter-suite`, and main Claude are all free to delete `reports/` with no warning. The protection didn't move; it isn't there.

This is the "accidental dependency" trap: deletion-safety is conceptually independent of "do we care about Pikud alerts?", but they're now coupled in practice.

### When this is fine

- Development / experimentation: you control which plugins are enabled, you know the implication.
- Single-developer projects where you'll notice the absence quickly.
- Teaching contexts (this is one) — the coupling is itself instructive.

### When this is wrong

- Production / team workflows where multiple people may toggle plugins without reading this README.
- Any context where the guardrail is a **safety guarantee**, not a convenience.

---

## Alternatives — where else this hook could live

| Location                              | Pros                                                              | Cons                                                                            |
|---------------------------------------|-------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `.claude/settings.json` (project-level) | Always loaded with the repo; survives any plugin enable/disable. | Doesn't travel when someone installs this plugin in a different repo.           |
| One plugin (here: `pikud-alerts-suite`) | Travels with the plugin to wherever it's installed.              | Vanishes when that plugin is disabled — silent loss of safety guarantee.        |
| A dedicated `project-guardrails` plugin | Travels; semantically clean ("this plugin = the guardrails").    | One more thing to install/enable. Same disable risk if disabled.                 |
| Managed settings (`-managed`)         | Force-enabled, can't be disabled by user; right for real orgs.    | Setup is heavier; usually only worth it inside an enterprise rollout.            |

For a real engineering organization, the policy belongs in `.claude/settings.json` or in a managed-settings-pinned guardrail plugin. Coupling deletion-safety to *"is the alerts plugin enabled?"* is an accidental dependency that bites later.

For this lesson, picking `pikud-alerts-suite` is fine — you're learning the trade, not shipping to production.

---

## Testing the guardrail without invoking Claude

The hook reads JSON on stdin and exits 2 on a blocked command, 0 otherwise. To verify it works without running Claude Code:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf reports/"}}' \
  | pikud-alerts-suite/hooks/block-removing-reports.sh ; echo "exit=$?"
# expect: stderr "Blocked by pikud-alerts-suite: …", exit=2

echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | pikud-alerts-suite/hooks/block-removing-reports.sh ; echo "exit=$?"
# expect: silent, exit=0
```

If both pass, the only thing left is a session restart (or `/reload-plugins`) so Claude Code picks up the hook subscription.

---

## What this hook does NOT do

A common misconception worth surfacing:

- ❌ It does **not** block `rm -rf reports/` typed by a human in their own terminal. Hooks observe Claude Code's tool boundary, not the operating system.
- ❌ It does **not** block deletions made by *other* programs (a cron job, a CI script, another editor).
- ❌ It does **not** prevent overwrites via the `Write` or `Edit` tools — the matcher is `Bash` only. Add `Write|Edit` to the matcher if you want overwrite protection too.

For OS-level deletion protection, use filesystem ACLs (`chattr +i` on Linux, NTFS Deny ACE on Windows) or rely on `git` for recovery. The hook is a Claude-Code-internal safety net, not a system-wide one.
