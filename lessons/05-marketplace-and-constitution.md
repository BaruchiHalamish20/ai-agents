# Lesson 5 — Marketplace + plugin-scoped constitution

> **Goal:** Turn the three plugins you packaged in lesson 4 into a
> distributable catalog and write the team's rules for what's allowed
> in that catalog. Two acts:
>
> - **Act 1 — Marketplace.** Build `.claude-plugin/marketplace.json` at
>   the repo root listing all three plugins. Validate it. Install from
>   it. Pre-declare it in `.claude/settings.json` so anyone who clones
>   the repo is auto-prompted to install.
> - **Act 2 — Constitution.** Write `.claude-plugin/constitution.md`
>   defining seven articles: naming, components, versioning, paths,
>   hooks/safety, skills, agents. Audit each existing plugin against
>   the articles. Decide what to fix, what to document as known
>   deviation.
>
> **Time:** ~60 minutes (longer than past lessons — two acts).
> **You will touch:** new `.claude-plugin/marketplace.json`, new
> `.claude-plugin/constitution.md`, possibly the existing
> `.claude/settings.json` (you already have a partial setup from
> lesson 4).
>
> **Source of truth:**
> - Marketplaces — <https://code.claude.com/docs/en/plugin-marketplaces.md>
> - Discover and install plugins — <https://code.claude.com/docs/en/discover-plugins.md>
> - Plugin settings — <https://code.claude.com/docs/en/settings.md#plugin-settings>

---

## 1. Concept

### A marketplace is a catalog, not a registry

A marketplace is one JSON file that says *"here are the plugins I sanction, and where to find each one."* That's it. No central authority. No approval gates by default. The mechanics are:

1. **Author** publishes a `.claude-plugin/marketplace.json` (in a git repo, on a server, or on disk).
2. **User** registers it: `/plugin marketplace add owner/repo` (or a path, or a URL).
3. **User** installs individual plugins: `/plugin install plugin-name@marketplace-name`.

That's the entire surface. **The smarts and the safety come from *you*, not from the platform** — which is exactly why Act 2 exists.

### The three trigger models, now packaged and distributed

| Lesson | Trigger model    | Artifact                  |
|--------|------------------|---------------------------|
| 1      | Model-triggered  | Agent                     |
| 2      | User-triggered   | Skill                     |
| 3      | System-triggered | Hooks / loops / routines  |
| 4      | (packaging)      | Plugin                    |
| **5**  | (distribution + governance) | **Marketplace + constitution** |

Lessons 1–4 produced *artifacts*. Lesson 5 produces *the system that ships them and the rules that govern them*. This is the lesson where Claude Code stops being "a tool I use on my laptop" and starts being "an extension surface my team builds and operates collectively."

### Why a constitution

Anyone can list anything in a `marketplace.json`. The platform doesn't check naming, versioning, hook safety, or path correctness beyond JSON syntax. If you ship a marketplace to your team without rules, you'll spend the next six months mediating disputes about which plugin should own which path and why nobody can disable the alerts plugin without breaking deletion safety (sound familiar?).

A **plugin-scoped constitution** is the document that turns implicit rules into explicit ones. It says, for the plugins in *this* catalog:

- What's allowed (kebab-case names, semver for shipped plugins).
- What's forbidden (catch-all `PreToolUse` hooks, hard-coded paths instead of `${CLAUDE_PLUGIN_ROOT}`).
- What's case-by-case (cross-plugin guardrails — like `pikud-alerts-suite/hooks/block-removing-reports.sh` — must be explicitly documented).

In SDD terms: the constitution is the layer above specs and plans. *Specs say "what this plugin does."* The constitution says *"what bar every spec in this catalog must clear."*

### Plugin-scoped vs project-wide

This lesson is **plugin-scoped**. The constitution governs the plugin catalog, not the codebase. Lesson 6 will write the **project-wide SDD constitution** governing the spec → plan → tasks workflow for the whole repo. Today's constitution lives in `.claude-plugin/constitution.md` (next to the marketplace it governs); lesson 6's will live at the repo root.

---

## 2. Spec

### Act 1 — Marketplace

**Inputs:** the three plugins from lesson 4 (`pikud-alerts-suite`, `tzevaadom-alerts-suite`, `markdown-suite`), already at the repo root.

**Outputs:**
- `.claude-plugin/marketplace.json` at the repo root listing all three.
- Validated by `claude plugin validate .` (no errors, no blocking warnings).
- Installable via `/plugin marketplace add .` followed by `/plugin install <name>@ai-agents-local`.
- Pre-declared in `.claude/settings.json` so anyone who clones the repo is auto-prompted on first session.

**Out of scope (Act 1):**
- GitHub-hosted marketplace (stretch goal — push the repo).
- Managed settings / `strictKnownMarketplaces` (enterprise lockdown, separate lesson).
- npm / git-subdir source variants (covered in Plan as alternatives, not built).

### Act 2 — Constitution

**Inputs:** the three plugins (now distributable), Acts 1's marketplace.

**Outputs:**
- `.claude-plugin/constitution.md` with **seven articles**: naming, required components, versioning, paths and state, hooks and safety, skills, agents.
- Each article includes the rule, the rationale, and a concrete reference to which existing plugin demonstrates it.
- An "audit" section at the end of the lesson listing how the three existing plugins score against the constitution — pass, deviation (documented), or fail (must fix).

**Out of scope (Act 2):**
- Automated constitutional enforcement (stretch goal: write a `/plugin-constitution-check` skill).
- Project-wide SDD constitution (lesson 6).

### Success criteria (whole lesson)

- `claude plugin validate .` returns zero errors against the marketplace.
- `/plugin list` shows all three plugins enabled from `ai-agents-local`.
- A fresh clone of this repo, in a fresh session, auto-prompts for `ai-agents-local` and lets the user install the three plugins with a single confirm.
- `.claude-plugin/constitution.md` exists, has all seven articles, and the audit section lists at least one item per existing plugin (pass, deviation, or fail).

---

## 3. Plan

| Decision                              | Choice                                       | Why                                                                                                                                |
|---------------------------------------|----------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Marketplace name                      | `ai-agents-local`                            | Already what's in `extraKnownMarketplaces`; consistent with installed plugin IDs (`pikud-alerts-suite@ai-agents-local`).            |
| Marketplace manifest location         | `.claude-plugin/marketplace.json` (repo root) | Canonical location per the docs (`claude plugin validate` expects this exact path).                                                |
| Plugin source type                    | Relative path (`./pikud-alerts-suite`)        | Same repo. Lets you keep iterating; `/plugin marketplace update` re-fetches local state. GitHub source is the publish-it-later move. |
| `strict` mode                         | `true` (default, implicit)                    | Each plugin already has its own `plugin.json`; marketplace entry just points at it. No restructuring needed.                       |
| Constitution location                 | `.claude-plugin/constitution.md`              | Sibling to the marketplace.json — visually signals the constitution governs *this catalog*, not the whole codebase.                |
| Number of constitutional articles     | 7                                             | Enough to cover naming, structure, versioning, paths, hooks, skills, agents. Fewer than 10 keeps it readable in one sitting.        |
| Enforcement mechanism                 | Manual review against checklist               | Constitutional compliance is a judgment exercise. Automating it (stretch goal) makes sense after the articles are stable.          |
| Where the "exceptions" go             | The plugin's own README (per-plugin) + the constitution's audit section (catalog-wide) | Lesson 4 already established `pikud-alerts-suite/README.md` as the home for documented deviations. Reuse the pattern.              |

---

## 4. Tasks

### Act 1 — Build the marketplace

#### Task 1 — Create the marketplace manifest

If `.claude-plugin/marketplace.json` doesn't exist yet, create it. (If you already created one based on hints from earlier sessions, replace it with the canonical version below.)

```bash
mkdir -p .claude-plugin
```

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "ai-agents-local",
  "owner": {
    "name": "Baruchi Halamish",
    "email": "bhalamish20@gmail.com"
  },
  "description": "Local development marketplace for the RoiTeachme AI-agents course. Three plugins covering Pikud HaOref alerts (oref.org.il), Tzeva Adom alerts, and PDF→Markdown conversion.",
  "plugins": [
    {
      "name": "pikud-alerts-suite",
      "source": "./pikud-alerts-suite",
      "description": "Pikud HaOref alert workflow — agent + skill + SessionStart hook + cross-plugin reports/ guardrail.",
      "version": "1.0.0",
      "keywords": ["pikud-haoref", "alerts", "israel"]
    },
    {
      "name": "tzevaadom-alerts-suite",
      "source": "./tzevaadom-alerts-suite",
      "description": "Tzeva Adom alert workflow — alternative alert source bundled identically to pikud-alerts-suite.",
      "version": "1.0.0",
      "keywords": ["tzeva-adom", "alerts", "israel"]
    },
    {
      "name": "markdown-suite",
      "source": "./markdown-suite",
      "description": "PDF → Markdown conversion plugin with SessionStart conversion-queue notification.",
      "version": "1.0.0",
      "keywords": ["pdf", "markdown", "context", "rag-prep"]
    }
  ]
}
```

Three field-by-field notes:

- **`name`** is public-facing. Every install command will use it: `/plugin install <plugin>@ai-agents-local`. Avoid reserved names (the docs list `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace`, and several others; full list in the marketplaces reference).
- **`source: "./<plugin-folder>"`** is a *relative path source*. Per the docs: *"Paths resolve relative to the marketplace root, which is the directory containing `.claude-plugin/`."* So `./pikud-alerts-suite` from `.claude-plugin/marketplace.json` resolves to `<repo>/pikud-alerts-suite`. Do **not** use `../` to reach outside the marketplace root.
- **`version` per plugin** here is for the marketplace entry; each plugin also has its own `plugin.json` with `version: "1.0.0"`. The docs warn: *"Avoid setting `version` in both `plugin.json` and the marketplace entry. The `plugin.json` value always wins silently."* Keep one source of truth — the plugin's own manifest — and consider removing `version` from the marketplace entries once you ship.

#### Task 2 — Validate

From the repo root:

```bash
claude plugin validate .
```

Expected output: zero errors, zero blocking warnings. Common failure modes the docs call out:

- `File not found: .claude-plugin/marketplace.json` — typo in the directory name.
- `Invalid JSON syntax: Unexpected token...` — JSON error, usually a trailing comma.
- `Duplicate plugin name "x" found in marketplace` — two entries share `name`.
- `Plugin name "x" is not kebab-case` — only a warning, but the claude.ai marketplace rejects non-kebab names.

If you have any errors, fix before moving on. The validator also lints every plugin's `plugin.json`, skill/agent frontmatter, and `hooks/hooks.json` — so this is a one-command sanity check for the whole catalog.

#### Task 3 — Add and install (local)

You already have `extraKnownMarketplaces` and `enabledPlugins` set in `.claude/settings.json` from lesson 4. To re-prove the wiring works end-to-end, walk through the manual flow:

```
/plugin marketplace remove ai-agents-local
/plugin marketplace add .
/plugin install pikud-alerts-suite@ai-agents-local
/plugin install tzevaadom-alerts-suite@ai-agents-local
/plugin install markdown-suite@ai-agents-local
/plugin list
```

`/plugin list` should show all three with their version, marketplace, and enabled status.

> **Caveat:** `/plugin marketplace remove` also uninstalls any plugins from it. The docs are explicit: *"Removing a marketplace also uninstalls any plugins you installed from it. To refresh a marketplace without losing installed plugins, use `/plugin marketplace update` instead."* For a non-destructive refresh after editing `marketplace.json`, use:
>
> ```
> /plugin marketplace update ai-agents-local
> ```

#### Task 4 — Make the marketplace travel with the repo

Confirm `.claude/settings.json` already has the bootstrap entries from your lesson 4 work:

```json
"extraKnownMarketplaces": {
  "ai-agents-local": {
    "source": {
      "source": "directory",
      "path": "."
    }
  }
},
"enabledPlugins": {
  "pikud-alerts-suite@ai-agents-local": true,
  "tzevaadom-alerts-suite@ai-agents-local": true,
  "markdown-suite@ai-agents-local": true
}
```

Two things worth understanding about this block:

- **`extraKnownMarketplaces`** declares marketplaces *available* to this project. Anyone cloning the repo and starting Claude Code will be offered them. **It does not auto-install plugins** — the user still confirms once.
- **`enabledPlugins`** is the install set. Setting `"pikud-alerts-suite@ai-agents-local": true` here means "install + enable this plugin on first run." This is what makes the team experience one-click. (Note: from the docs, `--scope project` on `/plugin install` writes here automatically.)

If anything is missing, add it. `.claude/settings.json` is checked into git, so the next person who clones gets the same setup.

#### Task 5 — Verify the team-clone flow (optional but recommended)

In a separate temp directory, simulate a fresh clone:

```bash
git clone <this-repo> /tmp/ai-agents-fresh
cd /tmp/ai-agents-fresh
claude --debug
```

Watch the debug log. On first session start in a project with `extraKnownMarketplaces`, Claude Code prompts to add the marketplace; with `enabledPlugins` set, it offers to install + enable the listed plugins in one batch. If both prompts fire and one-confirm completes, the team-onboarding contract works.

### Act 2 — Write the constitution

#### Task 6 — Create the constitution file

Create `.claude-plugin/constitution.md` with seven articles. The content below is a starting draft — adopt it as-is, then evolve it as your catalog grows.

```markdown
# Constitution — ai-agents-local marketplace

This document governs what may be listed in the `ai-agents-local`
marketplace. Every plugin in the marketplace MUST conform to the
articles below, with deviations documented in the plugin's README and
acknowledged in this constitution's audit section.

Owner: Baruchi Halamish.
Last revised: <today's date>.
Applies to: every plugin entry in `.claude-plugin/marketplace.json`.

---

## Article I — Naming

1. Plugin names MUST be kebab-case, lowercase, no spaces, no underscores.
2. Bundle plugins (multi-component: agent + skill + hook) SHOULD use the
   `<domain>-suite` suffix (e.g. `pikud-alerts-suite`).
3. Single-purpose plugins SHOULD use a descriptive suffix indicating
   shape (`-tool`, `-helper`, `-runner`, `-converter`).
4. The marketplace prefix (`ai-agents-local`) is the namespace; plugin
   names must be unique within the marketplace.

**Why:** Naming inconsistency is the #1 source of plugin-discoverability
friction. A consistent prefix lets you grep, sort, and visually parse
the catalog. The `-suite` convention tells a user "this plugin owns
several components" before they read its README.

**Reference example:** `pikud-alerts-suite` (passes).

---

## Article II — Required components

Every plugin MUST include:

1. `.claude-plugin/plugin.json` with `name`, `description`, and `version`
   set explicitly (never omitted — see Article III).
2. A `README.md` at the plugin root with at least three sections:
   *Overview*, *Plugin contents*, *Testing the plugin*.
3. If the plugin ships a hook that can block tool calls, its README MUST
   include a *"What this hook does NOT do"* section listing the
   boundaries of the protection (per the precedent set by
   `pikud-alerts-suite/README.md`).

**Why:** A plugin without a README is a plugin nobody trusts. The three
mandatory sections answer the three questions every user asks when they
encounter an unknown plugin: *what is it?*, *what's inside?*, *can I
verify it works before relying on it?*

**Reference example:** `pikud-alerts-suite/README.md` (passes).

---

## Article III — Versioning

1. Plugins listed in the marketplace MUST have an explicit semver
   `version` in `plugin.json`. Git-SHA versioning is for experimental
   plugins not yet in the catalog.
2. Bumping MAJOR (`1.x` → `2.0`) requires a `## Breaking changes` entry
   in the plugin's README.
3. `version` in the marketplace entry MUST be either omitted or
   identical to `plugin.json`. Per the Claude Code docs: *"The
   `plugin.json` value always wins silently"* — divergent values mask
   bugs.

**Why:** Explicit semver is the unit of trust between a plugin author
and a plugin user. Git-SHA versioning is fine for "I push, you pull,
we both move forward" — it's wrong for "I've shipped, you've installed,
we both need to know what version you're running."

**Reference example:** `pikud-alerts-suite/.claude-plugin/plugin.json`
declares `"version": "1.0.0"` (passes).

---

## Article IV — Paths and state

1. Plugin-relative paths in `hooks.json`, `.mcp.json`, `.lsp.json`, or
   any script invoked from those configs MUST use the
   `${CLAUDE_PLUGIN_ROOT}` placeholder. Hardcoded paths are forbidden.
2. Persistent plugin state (audit logs, caches, downloaded
   dependencies) MUST live under `${CLAUDE_PLUGIN_DATA}`. State written
   to `${CLAUDE_PLUGIN_ROOT}` is erased on plugin update.
3. A plugin MUST NOT read or write files outside its own ROOT or DATA,
   except for files the user explicitly references (e.g., a path
   passed as a skill argument).

**Why:** ROOT is overwritten on update; DATA is preserved. A plugin
that writes audit logs to ROOT loses its history on every version
bump — that's not a feature, that's a bug masquerading as one.

**Reference example:** `pikud-alerts-suite/hooks/inject-latest-alert-summary.sh`
writes to `${CLAUDE_PLUGIN_DATA}/audit.log` (passes).

---

## Article V — Hooks and safety

1. `PreToolUse` hooks in `hooks.json` MUST declare a `matcher`. A
   matcher-less PreToolUse hook fires on every tool call (Read, Glob,
   Bash, Write, …) — that's a hot-path performance bug and an
   accidental-overreach risk.
2. A hook that blocks an operation (exits 2 or returns a `decision: block`
   JSON response) MUST emit a stderr message that names the plugin
   that's blocking. Format: `Blocked by <plugin-name>: <reason>.` This
   lets the user know exactly which plugin to disable if they want to
   bypass.
3. Project-wide guardrails (e.g., delete-protection for shared
   directories) SHOULD live in `.claude/settings.json`, not in a single
   plugin — unless that plugin's README explicitly documents the
   cross-plugin scope (see `pikud-alerts-suite/README.md` for the
   documented exception in this catalog).

**Why:** Hook composition is session-scoped, not plugin-scoped (see
`pikud-alerts-suite/README.md` for the full explanation). Coupling a
project-wide safety guarantee to one plugin's enable state is an
accidental dependency. If a guardrail is plugin-specific, it lives
with the plugin; if it's project-wide, it lives in settings.

**Reference example:** `pikud-alerts-suite/hooks/block-removing-reports.sh`
is the *documented exception* — guardrail in a plugin, with the README
explaining the coupling cost.

---

## Article VI — Skills

1. Skills MUST validate arguments before performing any irreversible
   work. Parse-error paths MUST NOT write files.
2. Skills with 2+ positional arguments SHOULD use named positional via
   `arguments: [arg1, arg2]` in frontmatter. `$ARGUMENTS`, `$0`, `$1`
   are reserved for one-arg cases.
3. Skills with destructive side effects (delete, overwrite, network
   mutation, external API call with side effects) MUST be opt-in via
   an explicit flag, never the default behavior.

**Why:** A skill is user-triggered, but the user types it once and the
side effects unroll across many tool calls. "Validate before you
commit" is the same discipline you apply in a database transaction —
the surface is different, the principle is identical.

**Reference example:** `pikud-alerts-suite/skills/alert-report/SKILL.md`
parses `[hours] [region] [--debug]`, aborts on bad input with no file
written (passes).

---

## Article VII — Agents

1. Plugin-shipped agents MUST declare their toolset via `tools:`
   frontmatter — relying on the platform default is forbidden in this
   catalog (it makes the agent's blast radius implicit).
2. Plugin-shipped agents MUST NOT declare `hooks`, `mcpServers`, or
   `permissionMode` in frontmatter — these are blocked for plugin
   agents by Claude Code itself, so this article is a defense-in-depth
   reminder.
3. Agents that fetch external data MUST emit a `## Sources` section in
   any artifact they produce, listing every URL hit and any data that
   was unavailable. This is the agent equivalent of "show your work."

**Why:** Agents are opaque — the calling Claude can't see their tool
calls, only their final return. The `## Sources` section is the
single most useful debug signal you can demand (see
`references/agent-debugger.md`). Mandating it at the catalog level
turns a habit into a guarantee.

**Reference example:** `pikud-alerts-suite/agents/pikud-alerts.md`
emits a Sources section in every report (passes).

---

## Audit — current catalog (as of <today's date>)

| Plugin                     | Articles passing | Documented deviations                          | Must-fix                   |
|----------------------------|------------------|------------------------------------------------|----------------------------|
| `pikud-alerts-suite`       | I, II, III, IV, V, VI, VII | Article V — cross-plugin guardrail documented in README | — |
| `tzevaadom-alerts-suite`   | (to be audited)  | (to be audited)                                | (to be audited)            |
| `markdown-suite` | (to be audited)  | (to be audited)                                | (to be audited)            |

Future audits SHOULD be appended to this table, not overwritten —
constitutional compliance is a journal, not a snapshot.
```

#### Task 7 — Audit the existing plugins

For each of `tzevaadom-alerts-suite` and `markdown-suite`, walk through the seven articles and fill in the audit table. The structured process:

1. **Article I — Naming.** Read the folder name. Pass / deviate / fail.
2. **Article II — Required components.** Check for `plugin.json` (required fields), `README.md` (three sections). Most likely fail point: missing README. *That's a fix.*
3. **Article III — Versioning.** Open `plugin.json`. Is `version` set explicitly? Any divergence between `plugin.json` and the marketplace entry?
4. **Article IV — Paths and state.** Open `hooks.json`. Every script path use `${CLAUDE_PLUGIN_ROOT}`? Any audit logs or state living in ROOT instead of DATA?
5. **Article V — Hooks and safety.** Any `PreToolUse` hook without a matcher? Any blocking hook without a stderr-naming convention? After lesson 4 cleanup, the only remaining PreToolUse in the catalog is in `pikud-alerts-suite` (documented). The other two should have no PreToolUse — that's a *pass by absence*.
6. **Article VI — Skills.** Open each `SKILL.md`. Does it validate args before writing? Are destructive operations opt-in?
7. **Article VII — Agents.** Open each `<name>.md` in `agents/`. Does it declare `tools:`? Does its system prompt instruct it to emit `## Sources`?

#### Task 8 — Fix one finding (or document the deviation)

For the most consequential audit finding, do one of:

- **Fix:** apply the change to the plugin so it passes the article. Most likely candidate: add a `README.md` to `tzevaadom-alerts-suite` and `markdown-suite` if they don't have one yet.
- **Document deviation:** edit the plugin's `README.md` to acknowledge the deviation, the rationale, and the conditions under which the deviation would be revisited. Update the audit table to mark it as "deviation (documented)."
- **Defer:** if the finding is real but not actionable today, add it to the audit table as "must-fix" with a TODO date.

The point of the audit isn't to achieve 100% compliance on day one — it's to make the gap visible.

---

## 5. Verification checklist

- [ ] `.claude-plugin/marketplace.json` exists, validates with
      `claude plugin validate .` (zero errors).
- [ ] `/plugin list` shows three plugins, all enabled, all sourced from
      `ai-agents-local`.
- [ ] `.claude/settings.json` contains `extraKnownMarketplaces` and
      `enabledPlugins` entries for the three plugins.
- [ ] `.claude-plugin/constitution.md` exists with all seven articles.
- [ ] The audit table has at least one row per plugin (pass /
      deviation / must-fix).
- [ ] At least one audit finding has been actioned (fixed or
      documented).
- [ ] `git status` shows the new files; commit them so the next clone
      of the repo gets the full marketplace + constitution setup.

---

## 6. Stretch (optional)

Pick one before declaring the lesson complete.

1. **Push to GitHub.** Push the repo to a GitHub remote. Have a
   teammate (or a fresh clone) run
   `/plugin marketplace add <owner>/<repo>` instead of `add .`. Confirm
   the install flow works from a remote source. Notice the marketplace
   manifest doesn't change — only the *registration* of it does.
2. **`/plugin-constitution-check` skill.** Write a skill (in its own
   plugin or as a project-local skill) that takes a plugin folder path
   and audits it against each of the seven articles, returning a
   pass/deviation/fail table. The constitution becomes code.
3. **Add `strict: false` to one plugin** in `marketplace.json`. Try to
   load it. Read the error. Reflect on what `strict: false` actually
   gives you (the marketplace operator becomes the authority over the
   plugin author — useful for curating, dangerous if abused).
4. **Configure `strictKnownMarketplaces` in managed settings.** Add a
   `~/.claude/managed-settings.json` (or your OS's equivalent) with
   `"strictKnownMarketplaces": []` to lock down marketplace additions
   entirely. Try `/plugin marketplace add` something else. See it
   blocked. This is the enterprise lockdown surface.
5. **Add a CI workflow** at `.github/workflows/plugin-validate.yml`
   that runs `claude plugin validate .` on every PR. The constitution
   gets enforced by the SDLC.

---

## What you should now believe

- **Marketplaces are dumb catalogs.** The platform doesn't enforce
  anything beyond JSON validity. Whether your catalog is trustworthy
  depends entirely on the rules you write and the discipline of
  applying them. That's the constitution's job.
- **The constitution is the missing middle.** Lesson 4's plugins are
  artifacts. Lesson 5's marketplace is the shipping mechanism. The
  constitution sits between them — *the bar an artifact must clear
  before it ships.* Skip it and the marketplace becomes a junk drawer.
- **Hook composition is the load-bearing example.** The cross-plugin
  guardrail in `pikud-alerts-suite` is what Article V is *for*. The
  fact that you wrote a README documenting that deviation is the
  precedent — every subsequent deviation in this catalog references
  that pattern.
- **`extraKnownMarketplaces` + `enabledPlugins` is one-click team
  onboarding.** Setting them in `.claude/settings.json` means a fresh
  clone of the repo + a fresh Claude Code session = a one-confirm
  install of the entire plugin suite. That's the difference between
  "I shipped plugins" and "my team is running them tomorrow morning."
- **Plugin-scoped governance is the warmup for project-scoped governance.**
  Writing rules for *what's in the catalog* is easier than writing rules
  for *how we work on the codebase*. The seven articles here generalize
  to dozens in a project-wide constitution. Lesson 6 makes that jump.

---

## Next up — Lesson 6

You've now governed the plugin catalog. Lesson 6 extends the
constitutional approach to the **codebase as a whole** — the
SDD-scoped constitution:

- The constitution → specs → plans → tasks hierarchy applied to *all
  work* in the repo, not just plugin development.
- How the project-wide constitution differs in shape from the
  plugin-scoped one (more articles; covers commit messages, branch
  hygiene, PR review bar, testing policy, deployment cadence, AI-tool
  usage rules).
- Where the file lives (repo root, not `.claude-plugin/`), why it's
  not in `.claude/` (so it travels with the repo whether or not you
  use Claude Code), and how it cross-references Claude-Code-specific
  artifacts.
- How a project-wide constitution interacts with `CLAUDE.md` — *they
  are not the same document*, and confusing them is a common SDD
  rollout mistake.

After lesson 6, you'll have the full SDD governance surface for a
project that uses Claude Code as a primary engineering tool —
constitution governing the work, specs governing each change, plans
governing execution, tasks tracking progress, plugins shipping the
reusable bits, the marketplace distributing them, and the
plugin-scoped constitution gating the catalog.
