# Course Summary — Key Points to Remember

> Bullet-form digest of lessons 1–6. Main concepts only — no tasks, no
> commands. Read top-to-bottom in 5 minutes.

---

## The big picture (one-screen mental model)

- **Three trigger models** cover every workflow:
  - **Model-triggered** → Agent
  - **User-triggered** → Skill
  - **System-triggered** → Hook / `/loop` / `/schedule` routine
- **Trilogy = the unit of work**: agent + skill + hook (+ optional routine).
- **Plugin** = packaging the trilogy as one folder.
- **Marketplace** = catalog of plugins.
- **Constitution** = the rules above all of it.

---

## Lesson 1 — Custom agents

- An agent is **just a Markdown file** under `.claude/agents/<name>.md`.
- Frontmatter = the contract: `name`, `description`, `tools`, `model`.
- System prompt = the implementation; constraints belong there.
- Runs in its **own context window**, isolated from main Claude.
- Main Claude sees only the **final return**, not intermediate reasoning.
- **`description` quality decides if the agent gets used** — vague = dead code.
- Use an agent when: many tool calls, need second opinion, parallel work.
- Don't use an agent when: quick answer, user wants to steer mid-flight.

---

## Lesson 2 — Skills (user-triggered)

- A skill is a **folder** at `.claude/skills/<name>/SKILL.md`.
- Triggered by user typing `/<skill-name> <args>`.
- Runs **inline in the current session** — every step visible, interruptible.
- `allowed-tools` **grants** access, does not restrict.
- **Live reload**: edit → re-run, no session restart.
- Skill vs Agent:
  - Skill = user-triggered, inline, costs main-context tokens.
  - Agent = model-triggered, isolated, free of main-context cost.
- Skill triggering is **deterministic** (user types it);
  agent triggering is **probabilistic** (model reads description).

---

## Lesson 3 — Hooks, loops, and schedules (system-triggered)

- **Hooks** fire on Claude Code events (`SessionStart`, `PreToolUse`, etc.).
- **`/loop`** = local + short + ephemeral (1 min min, ≤ 7 days).
- **`/schedule` routine** = cloud + long + persistent (1 hour min).
- Decision rule:
  - Laptop closed? → routine.
  - Active incident monitoring? → `/loop`.
  - Reaction to Claude Code event? → hook.
- **Honest limits to remember:**
  - A hook **cannot** type into the conversation as the user.
  - It returns JSON: `additionalContext`, `updatedInput`, or exit-code-2 block.
  - A hook injecting data **must** include behavioral guidance ("don't re-fetch unless…") — otherwise Claude re-fetches anyway.
- **Routines are NOT in git** — they live in your claude.ai account.
- Three ways to manage routines: `/schedule`, web UI, HTTP API.
- API is the only path treating routines as code.

---

## Lesson 4 — Plugins (packaging)

- A plugin is **one folder** with a manifest + components.
- Layout:
  - **Only `plugin.json` goes inside `.claude-plugin/`.**
  - Everything else (`agents/`, `skills/`, `hooks/`) at the **plugin root**.
- Plugins introduce **no new behaviors** — just packaging + naming.
- **Namespacing** is the point: `/alert-report` → `/pikud-alerts-suite:alert-report`.
- Two environment variables to internalize:
  - `${CLAUDE_PLUGIN_ROOT}` = code (overwritten on update).
  - `${CLAUDE_PLUGIN_DATA}` = state (survives updates).
- **Plugin agents are live-reloadable** via `/reload-plugins` — no restart.
- Versioning:
  - Explicit semver → users update only when you bump.
  - Omit `version` → every commit treated as a release.
- Plugins CAN ship hooks at the plugin root (`hooks/hooks.json`) — that's normal.
- But plugin-shipped **agents** cannot declare `hooks`, `mcpServers`, or `permissionMode` *inside their own frontmatter* (security: prevents an agent from smuggling permissions past the user). Standalone agents in `.claude/agents/` can.

### Composition reveal (second plugin)

- Building a parallel plugin on a different data source proved:
- **The data source is orthogonal to the orchestration.**
- The cloud-routine 403 bug was in the upstream, not in any of the code.

---

## Lesson 5 — Patterns + Marketplace + Plugin constitution

### Third plugin (markdown-converter)

- Building on a different *domain* (document conversion) proved:
- **The task is orthogonal to the architecture too.**
- New pattern: **orchestrator + worker**
  - Skill = batch orchestrator (enumerates, dispatches).
  - Agent = per-file worker in isolated context.
- Generalizes to any batch: translation, code review, test gen, summarization.
- **Right number of triggers = the number that match the task.**
  Forcing cron on a human-triggered task is anti-pattern.

### Marketplace

- A marketplace = **one JSON file** (`.claude-plugin/marketplace.json`).
- No central authority, no approval gates — just a catalog.
- Three management surfaces: `/plugin`, web UI, HTTP API.
- **One-click team onboarding** = `extraKnownMarketplaces` + `enabledPlugins` in `.claude/settings.json`.

### Plugin-scoped constitution (7 articles)

- The platform enforces only JSON validity. Trust comes from rules **you** write.
- Seven articles to govern the catalog:
  1. **Naming** — kebab-case, `-suite` suffix for bundles.
  2. **Required components** — `plugin.json`, `README.md`, "what hook does NOT do" section.
  3. **Versioning** — explicit semver, never diverge from marketplace entry.
  4. **Paths and state** — `${CLAUDE_PLUGIN_ROOT}` for code, `${CLAUDE_PLUGIN_DATA}` for state.
  5. **Hooks and safety** — `PreToolUse` needs matcher; blockers name themselves in stderr.
  6. **Skills** — validate args before any irreversible work; destructive opts-in.
  7. **Agents** — explicit `tools:`, emit `## Sources` in artifacts.
- The constitution is the **missing middle** between artifact and shipping.

---

## Lesson 6 — Project-wide SDD constitution

### The SDD hierarchy

```
CONSTITUTION → SPEC → PLAN → TASKS → CODE
```

- Each layer forecloses a specific failure mode:
  - **Constitution** — inconsistent standards across team.
  - **Spec** — drift mid-work and re-litigation of scope.
  - **Plan** — re-litigating decisions six months later.
  - **Tasks** — work can't be paused/resumed.

### CONSTITUTION.md ≠ CLAUDE.md

- **CLAUDE.md** = how Claude behaves in a session.
- **CONSTITUTION.md** = how the team works.
- Test: *"Does the rule change Claude's response in-session, or a human's PR review?"*
- The constitution must **not** be auto-loaded — one-line pointer from CLAUDE.md is enough.

### Ten articles (the project bar)

1. **SDD hierarchy** — every non-trivial change must follow it.
2. **Specs** — inputs/outputs/out-of-scope/success criteria, append-only.
3. **Plans** — decisions table + alternatives rejected + order of operations.
4. **Tasks** — one-commit-each, externally checkable, journal not backlog.
5. **Branches/commits** — atomic, type-prefix, AI attribution trailer.
6. **PR review** — must link to spec; reviewers check articles explicitly.
7. **Testing** — test what can be tested; document manual verification for the rest.
8. **AI usage** — human review before merge; AI is collaborator, not committer.
9. **Relation to CLAUDE.md** — separation test from above.
10. **Amendments/audit** — quarterly ritual; 3 deviations on one article → amend it.

### Enforcement reality

- **Almost no automated enforcement out of the box.**
- Articles enforced by: PR reviewers + amendment process + audit ritual.
- Premature automation ossifies rules that haven't proven themselves.

---

## The 8 mental models to keep forever

1. **Three trigger models cover everything**: model, user, system.
2. **The trilogy is the unit of work** — agent + skill + hook (+ routine).
3. **Data source and task are both orthogonal to the architecture** — swap either, orchestration doesn't change.
4. **A plugin is packaging, not new behavior** — exists for distribution and namespacing.
5. **Marketplaces are dumb catalogs** — trust comes from your rules, not the platform.
6. **Constitutions are commitments, not documentation** — PR review turns description into commitment.
7. **AI usage is a first-class concern** — attribute it, review before merge.
8. **By the end, building a workflow is a checklist** — first plugin: a week. Third plugin: 30 min.

---

## FinOps — cost discipline (read before shipping anything that runs unattended)

- **Agents are NOT free.** Isolation saves your main context window, not your wallet — every agent turn is billed (its own system prompt + its own reasoning + its tools' outputs + the return).
- **Skills are cheaper *per run* but pollute your main context** — long skills push everything else out of the window, forcing summarization or session restarts later.
- **`/loop` is the easiest way to burn money silently.** A 1-min interval × 24 hours = 1,440 runs/day. Always pick the longest interval that still works.
- **Routines run in the Anthropic cloud and have their own bill** — they don't show up in your local session counter. Treat them like a cron job on a server you're paying for.
- **Prompt caching is free money.** Stable system prompts (agents, skills) get cached automatically; reorder content so the changing parts come last to maximize cache hits.
- **Hooks are nearly free** — local shell scripts, no LLM call. Prefer a hook over an agent when the task is "read a file and inject context."

### Model recommendations (use in the planning stage to control cost)

| Stage / use case                                            | Recommended model | Why                                                       |
|-------------------------------------------------------------|-------------------|-----------------------------------------------------------|
| **Planning / architecture / spec writing**                  | **Opus**          | Best reasoning. The plan you write here pays back 10× in execution. |
| **Multi-file implementation, code review**                  | **Sonnet**        | Strong code quality at ~1/5 the price of Opus.            |
| **Batch workers (per-file converter, per-row processor)**   | **Haiku**         | Fastest + cheapest. Sufficient for structured transforms. |
| **Scheduled routines / hourly digests**                     | **Haiku**         | Runs unattended on a clock — keep each fire cheap.        |
| **Agents that fetch + summarize**                           | **Haiku / Sonnet**| Most fetch-and-format agents don't need Opus.             |
| **Hooks (SessionStart context injection, etc.)**            | n/a (shell)       | Hooks are scripts, not LLM calls. Cost is ~zero.          |
| **Final review / sign-off on AI-generated code**            | **Opus** (or human) | Last line of defense. Worth the spend.                    |

### Cost-reduction bullets (apply at planning time, not after the bill arrives)

- **Pick the model per artifact, not per project.** Declare `model:` in the agent/skill frontmatter so the cheap ones don't accidentally inherit Opus.
- **Use Plan mode (Opus) → switch to Sonnet/Haiku for implementation.** Front-load thinking; back-load execution.
- **Prefer the orchestrator + worker pattern** for batches — each worker runs in a tight context with the cheapest model that does the job.
- **Cap loop intervals** — never `/loop 1m` for monitoring you could check hourly.
- **Disable plugins you're not using** via `enabledPlugins`. Every loaded plugin's hooks fire on session start, costing seconds and tokens.
- **Keep agent system prompts short.** Each token in the system prompt is re-read on every turn (unless cached).
- **Audit token usage monthly** — `claude /cost` shows the per-session breakdown; routines need to be checked separately in the claude.ai billing dashboard.

---

## File index

| Topic                              | File                                  |
|------------------------------------|---------------------------------------|
| Custom agents                      | `01-custom-agent.md`                  |
| Skills + slash commands            | `02-skills.md`                        |
| Hooks, `/loop`, routines           | `03-hooks-and-schedules.md`           |
| First plugin                       | `04-plugins.md`                       |
| Composition (second plugin)        | `04-plugins-and-composition.md`       |
| Patterns (third plugin)            | `05-plugin-patterns.md`               |
| Marketplace + plugin constitution  | `05-marketplace-and-constitution.md`  |
| Project-wide SDD constitution      | `06-project-constitution.md`          |
