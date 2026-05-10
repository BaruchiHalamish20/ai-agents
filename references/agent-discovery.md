# Reference — How Claude Code discovers agents

Authoritative summary of the agent registry: where Claude Code looks, when it
looks, and what wins when names collide. Use this as a teaching slide or a
troubleshooting checklist.

> **Source of truth:** Anthropic's official sub-agents docs —
> <https://code.claude.com/docs/en/sub-agents.md>
> The rules below paraphrase that page. If they ever drift, the docs win.

---

## TL;DR

1. Agents are **Markdown files** (`<name>.md`) discovered at **session startup**.
2. There are **5 scopes** Claude Code scans, with a strict precedence order.
3. The **`/agents` slash command** is the only way to load an agent *live*
   (without restart). Manual file edits require a session restart.
4. **`/add-dir` does NOT scan for agents** — it only grants filesystem access.

---

## The 5 scopes (highest precedence first)

| # | Scope        | Location                                         | Lifetime / availability                    | When you'd use it                                                      |
|---|--------------|--------------------------------------------------|--------------------------------------------|------------------------------------------------------------------------|
| 1 | **Managed**  | Pushed by org-level managed settings             | Whatever the org policy says               | Enterprise guardrails — admins force agents on every employee          |
| 2 | **CLI flag** | `claude --agents <path>` at startup              | This session only                          | Throwaway / experimental agents you don't want to commit               |
| 3 | **Project**  | `<project-root>/.claude/agents/<name>.md`        | Sessions started with this dir as cwd      | **The default for shipped, repo-scoped agents.** What this lab uses.   |
| 4 | **User**     | `~/.claude/agents/<name>.md`                     | Every session, every project, every cwd    | Personal tools you want available everywhere                           |
| 5 | **Plugin**   | Bundled inside an installed Claude Code plugin   | Whenever the plugin is loaded              | Distribution via the plugin marketplace                                |

On Windows the user-scope path resolves to `C:\Users\<you>\.claude\agents\`.

### Precedence rule

If the **same agent `name`** exists in two scopes, the **higher-precedence
scope wins** and the lower one is ignored. You don't get a merge or an
error — just a silent override.

Practical implication: a managed agent named `code-reviewer` will eclipse
your project agent of the same name. Rename one of them or you'll wonder
why your edits "don't take effect".

---

## When does discovery happen?

| Event                                              | Triggers a rescan? |
|----------------------------------------------------|--------------------|
| Session startup                                    | ✅ Yes — full scan of all 5 scopes                                |
| You manually edit `.claude/agents/<name>.md`       | ❌ No — restart required                                          |
| You run `/agents` and create/edit an agent in UI   | ✅ Yes — takes effect *immediately* in the current session         |
| You run `/add-dir <path>`                          | ❌ No — only widens filesystem permissions, no agent scan          |
| You `cd` into a different project                  | ❌ No — discovery is anchored at the cwd the session *started* in  |

---

## Diagnostic checklist — "my custom agent isn't showing up"

Run through these in order. ~95% of the time the failure is one of the first three.

1. **Right file path?** `<scope>/agents/<name>.md` — and the dir is exactly
   `agents/`, not `agent/`, not `.agents/`.
2. **Right scope for your situation?** A project-scope agent only loads when
   the session was *started* with that project as cwd.
3. **Did you restart after creating/editing the file manually?** Or did you
   create it through `/agents` (which wouldn't need a restart)?
4. **Frontmatter valid?** No tabs, correct indentation, closing `---`,
   `name`/`description`/`tools` present.
5. **Filename matches the `name:` field?** Not strictly required by the
   parser, but strongly recommended — divergence is a common source of "I
   thought I was editing the right file".
6. **Higher-precedence scope shadowing it?** A managed or CLI-flag agent
   with the same name silently wins.

---

## Fast verification, no restart, no guessing

Inside any Claude Code session, ask:

> List the agents available in this project, then attempt a dry-run call to
> `<your-agent-name>` so I can see whether it's actually wired up.

If the agent **shows up in the list AND can be invoked**, it's truly loaded.
If it shows up but the invocation fails with "unknown agent type" — you have
a stale UI listing and need to restart. The empirical test beats reading
docs every time.

---

## How this maps to the lab

- **Phase 1 (this lab):** all custom agents live in **scope 3 (project)**.
  Students learn the canonical, shippable pattern.
- **Phase 2 (enterprise re-skin):** we'll demonstrate **scope 1 (managed)** —
  how an organization can push a `code-reviewer` or `security-auditor` agent
  onto every developer's Claude Code, and what governance that requires.
- **Personal use (after the lab):** drop frequently-used agents into
  **scope 4 (user)** so they ride along in every session you open, in any
  repo. Recommended for tools you'd otherwise paste into every project.
