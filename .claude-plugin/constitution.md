# Constitution — ai-agents-local marketplace

This document governs what may be listed in the `ai-agents-local`
marketplace. Every plugin in the marketplace MUST conform to the
articles below, with deviations documented in the plugin's README and
acknowledged in this constitution's audit section.

Owner: Baruchi Halamish.
Last revised: 19 may 2026
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

## Audit — current catalog (as of 25.5.2026)

| Plugin                     | Articles passing | Documented deviations                          | Must-fix                   |
|----------------------------|------------------|------------------------------------------------|----------------------------|
| `pikud-alerts-suite`       | I, II, III, IV, V, VI, VII | Article V — cross-plugin guardrail documented in README | — |
| `tzevaadom-alerts-suite`   | I, II, III, IV, V, VI, VII | —                                              |      |
| `markdown-suite`           | I, II, III, IV, V, VI, VII | —                                              |      |
| `word-to-pdf-suite`        | I, II, III, IV, V, VI, VII | —                                              |      |

Future audits SHOULD be appended to this table, not overwritten —
constitutional compliance is a journal, not a snapshot.