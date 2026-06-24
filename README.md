# AI Agents & Skills — Hands-on Lab

A spec-driven, hands-on lab for learning how to build, install, and orchestrate
**agents** and **skills** in Claude Code. Each lesson follows the same structure
the lab itself teaches: **Spec → Plan → Tasks → Verification**.

> **Phase 1 theme — Pikud HaOref (Israeli Home Front Command) alerts.**
> Real public data, no API keys, immediately recognizable for Israeli learners.
> The same lab will be re-skinned for enterprise DevOps audiences in Phase 2.

---

## Why this lab exists

Most "agent tutorials" jump to frameworks. They skip the foundational question:
**what work belongs in an agent vs. inline in the conversation vs. a skill the
user invokes?** Picking the wrong shape makes agents that are too chatty, too
broad, or impossible to reuse. This lab builds the intuition first, on a small
real domain, then scales it to enterprise patterns.

---

## What you'll learn

By the end of the four lessons you will be able to:

1. Decide between an **agent**, a **skill**, and inline work for any given task.
2. Author a **custom agent** with a tight tool allowlist and a clear contract.
3. Author a **custom skill** that wraps a procedure for the user to invoke.
4. Install and use a **third-party agent** from the community.
5. **Orchestrate** agents and skills together (chain output → review → publish).

---

## Prerequisites

- **Claude Code** installed (CLI, IDE plugin, or desktop) and signed in.
- Git on PATH (Git Bash on Windows is fine).
- Internet access (the lab fetches public oref.org.il data).
- ~30 minutes per lesson.

---

## Install the marketplace from GitHub

This repo ships its own plugin catalog at `.claude-plugin/marketplace.json`
(named `ai-agents-local`). You can register that catalog from a GitHub remote
— no local clone needed — and install any of its plugins on demand.

### One-time setup

From any working directory, start Claude Code and run:

```
/plugin marketplace add BaruchiHalamish20/ai-agents
/plugin install pikud-alerts-suite@ai-agents-local
/plugin install tzevaadom-alerts-suite@ai-agents-local
/plugin install markdown-suite@ai-agents-local
/plugin install word-to-pdf-suite@ai-agents-local
/plugin list
```

`/plugin marketplace add <owner>/<repo>` fetches `marketplace.json` from the
default branch of the GitHub repo and registers it under the `name` field
in that file (`ai-agents-local`). Every subsequent `/plugin install` uses
that name — the GitHub source is invisible from that point on.

### Verify the registration is actually GitHub-backed

`/plugin` (no args) opens the picker TUI. Under the **Marketplaces** tab,
the `ai-agents-local` entry's source line should read
`BaruchiHalamish20/ai-agents`. If it shows a local filesystem path
(e.g. `C:\…\ai-agents`), you have a residual directory-source registration
from a previous local-path setup that's shadowing the GitHub one — marketplace
names are unique, so the older registration wins silently. Fix:

```
/plugin marketplace remove ai-agents-local
```

…then remove any `extraKnownMarketplaces.ai-agents-local` block from
`~/.claude/settings.json`, restart Claude Code, and re-run
`/plugin marketplace add BaruchiHalamish20/ai-agents`.

### Local-directory source (alternative)

If you cloned this repo and want to point at the working copy instead
(useful while iterating on the marketplace itself), `cd` into the repo and:

```
/plugin marketplace add .
```

The `marketplace.json` is byte-identical in both cases — only the registration
transport changes (`directory` vs `github`).

### Refresh after the manifest changes

Editing `marketplace.json` and re-pushing does **not** auto-update existing
installs. To pick up changes without uninstalling plugins:

```
/plugin marketplace update ai-agents-local
```

Avoid `/plugin marketplace remove` for refreshes — it uninstalls every plugin
that came from the marketplace.

---

## Lab map

```
ai-agents/
├── README.md                          ← you are here
├── .claude/
│   ├── agents/
│   │   ├── pikud-alerts.md            ← Lesson 1: custom agent
│   │   └── code-reviewer.md           ← Lesson 3: third-party agent (later)
│   └── skills/
│       └── alert-report/SKILL.md      ← Lesson 2: custom skill (later)
├── lessons/
│   ├── 01-custom-agent.md             ← start here
│   ├── 02-skills.md                   ← after Lesson 1
│   ├── 03-third-party-agents.md
│   └── 04-orchestration.md
├── references/
│   └── agent-discovery.md             ← the 5 scopes, precedence, diagnostics
└── reports/                           ← agent outputs land here
```

> 📖 **Reference docs** (factual material you can lift into slides):
> - [`references/agent-discovery.md`](references/agent-discovery.md) — the 5
>   scopes Claude Code scans, precedence order, when discovery happens, and a
>   diagnostic checklist for missing agents.

The single `.claude/` directory at the repo root is intentional: Claude Code
auto-discovers agents and skills from the project root. Splitting them per
lesson would break discovery.

---

## Core concepts in one table

| Thing      | Lives in                              | Triggered by                               | Best for                                                                      |
|------------|---------------------------------------|--------------------------------------------|-------------------------------------------------------------------------------|
| **Agent**  | `.claude/agents/<name>.md`            | Main Claude delegating via the Agent tool  | Isolated context, parallel work, focused expertise (review, research, audit)  |
| **Skill**  | `.claude/skills/<name>/SKILL.md`      | User typing `/<name>` (or model autoload)  | Procedures the *user* invokes; reasoning stays in the main conversation       |
| **Inline** | The current conversation              | Whatever the user typed                    | One-off work, exploratory questions, things needing the full conversation     |

Memorable rule of thumb:
- **Agent** = sub-process, own context, returns a result.
- **Skill** = recipe, runs in the main loop, user-triggered.
- **Inline** = just do the thing.

---

## How to run a lesson

1. Open this repo as the working directory in Claude Code.
2. Open `lessons/01-custom-agent.md` and follow the **Tasks** section.
3. After each lesson, commit your changes (so you can diff what changed).

---

## Phase 2 (preview — not built yet)

Once Phase 1 is complete, the same four lessons will be re-skinned for an
enterprise DevOps audience. The agent will monitor a Kubernetes events stream
or a CI/CD pipeline instead of oref alerts; the skill will produce an SRE
incident summary instead of an alert report. The mechanics stay identical —
only the domain changes — which is exactly the point of the lab structure.
