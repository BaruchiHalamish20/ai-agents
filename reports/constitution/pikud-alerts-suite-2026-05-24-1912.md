---
plugin: pikud-alerts-suite
audited_against: .claude-plugin/constitution.md
generated_at: 2026-05-24 19:12 IDT
generated_by: /plugin-constitution-check
debug: false
---

# Constitution audit — `pikud-alerts-suite`

Audited against `.claude-plugin/constitution.md` on 2026-05-24 19:12 IDT.

## Summary

| Article | Title              | Verdict   | Note                                                                      |
|---------|--------------------|-----------|---------------------------------------------------------------------------|
| I       | Naming             | pass      | kebab-case, `-suite` suffix matches multi-component shape, marketplace name aligns. |
| II      | Required components| deviation | All required files present; the three required README headings are present in *intent* but not by literal name. |
| III     | Versioning         | pass      | `1.0.0` semver in `plugin.json`; marketplace entry matches.               |
| IV      | Paths and state    | **fail**  | SessionStart hook writes audit log to `.claude/hooks/.audit.log` — outside `${CLAUDE_PLUGIN_DATA}`. Constitution's own reference example claims `${CLAUDE_PLUGIN_DATA}/audit.log`; the code disagrees. |
| V       | Hooks and safety   | deviation | Cross-plugin guardrail intentionally documented in README — this is the precedent case the constitution names. |
| VI      | Skills             | pass      | `arguments: [hours, region]` declared; parse-error path explicitly aborts without writing. |
| VII     | Agents             | pass      | `tools:` declared; no forbidden frontmatter keys; `## Sources` section mandated in agent body. |

**Roll-up:** `4 pass, 2 deviation, 1 fail, 0 n/a`.

---

## Article I — Naming

- Verdict: **pass**
- Evidence:
  - Folder name: `pikud-alerts-suite` matches `^[a-z][a-z0-9-]*$`.
  - Multi-component: `pikud-alerts-suite/{agents,skills,hooks}/` all exist → `-suite` suffix is appropriate.
  - `.claude-plugin/marketplace.json:10` declares `"name": "pikud-alerts-suite"` — matches folder.
- Note: Catalog-aligned naming, no friction.

## Article II — Required components

- Verdict: **deviation**
- Evidence:
  - `pikud-alerts-suite/.claude-plugin/plugin.json` parses; `name`, `description`, `version` all non-empty (lines 2–4).
  - `pikud-alerts-suite/README.md` exists (121 lines).
  - **Conditional check (blocking hook):** `hooks/block-removing-reports.sh:14` uses `exit 2`. README contains a heading `## What this hook does NOT do` at line 112 — required heading present. ✓
  - **Three required headings:** Article II(2) calls for `Overview`, `Plugin contents`, `Testing the plugin`. The README's actual H2 headings are: `Why a project-wide guardrail lives in this plugin`, `How a hook in this plugin fires when another plugin acts`, `The coupling risk — read this before disabling the plugin`, `Alternatives — where else this hook could live`, `Testing the guardrail without invoking Claude`, `What this hook does NOT do`. None of the three literal headings appears.
- Note: The README's opening paragraphs (lines 1–10) function as Overview + Plugin contents in intent, and `Testing the guardrail without invoking Claude` is the testing section under a different name. The constitution's own audit table on line 177 marks this plugin as passing Article II, so the constitution-author and the literal rule disagree. **Resolution path:** either rename the headings to match Article II(2) verbatim, or soften Article II(2) from "MUST include three sections named X, Y, Z" to "MUST answer the three questions of what / what's inside / how to verify." Recommend the rename — it's the cheaper fix and keeps the rule mechanically auditable.

## Article III — Versioning

- Verdict: **pass**
- Evidence:
  - `pikud-alerts-suite/.claude-plugin/plugin.json:4` declares `"version": "1.0.0"` — valid semver.
  - MAJOR = 1, so the breaking-changes README requirement is `n/a`.
  - `.claude-plugin/marketplace.json:14` declares `"version": "1.0.0"` for this plugin — identical to `plugin.json`. No silent override risk.
- Note: Clean.

## Article IV — Paths and state

- Verdict: **fail**
- Evidence:
  - (1) Hardcoded paths in configs: `hooks/hooks.json:8,19` both use `${CLAUDE_PLUGIN_ROOT}/...` — no hardcoded absolute paths found. ✓
  - (2) **State location:** `hooks/inject-latest-alert-summary.sh:6` writes:
    ```bash
    echo "$(date -Iseconds) inject-latest-alert-summary fired" >> .claude/hooks/.audit.log
    ```
    This is a project-relative path. It lives outside `${CLAUDE_PLUGIN_ROOT}` and outside `${CLAUDE_PLUGIN_DATA}` — it's session-cwd-relative state under `.claude/hooks/`. Article IV(2) requires persistent plugin state to live under `${CLAUDE_PLUGIN_DATA}`. **Violation.**
  - (3) Reads outside ROOT: `hooks/inject-latest-alert-summary.sh:8,17` reads `reports/*.md`. Cross-project reads are documented in `README.md` under the cross-plugin section — counts as a documented exception, but the *write* on line 6 is undocumented and is the real failure.
  - Constitution's reference text on line 94 claims the hook writes to `${CLAUDE_PLUGIN_DATA}/audit.log`. The code disagrees — this is drift between the constitution and the reference example.
- Note: Two-line fix: replace `.claude/hooks/.audit.log` with `${CLAUDE_PLUGIN_DATA}/audit.log` and `mkdir -p "${CLAUDE_PLUGIN_DATA}"` before the append. Also update or remove the stale audit log at the project root if it shouldn't be tracked.

## Article V — Hooks and safety

- Verdict: **deviation** (documented exception — the precedent case)
- Evidence:
  - (1) PreToolUse matcher: `hooks/hooks.json:15` declares `"matcher": "Bash"` — non-empty, scoped. ✓
  - (2) Blocking message: `hooks/block-removing-reports.sh:13` emits `Blocked by pikud-alerts-suite: deletion under reports/ is not permitted.` to stderr before `exit 2`. Format matches Article V(2). ✓
  - (3) Cross-plugin scope: `hooks/block-removing-reports.sh` protects `reports/`, which is shared across plugins. `README.md` documents the coupling explicitly under "Why a project-wide guardrail lives in this plugin" (lines 14–22) and "The coupling risk — read this before disabling the plugin" (lines 52–76). This is the documented exception that Article V(3) explicitly allows.
- Note: This is the **reference deviation** — the constitution names this plugin as the precedent. No action required.

## Article VI — Skills

- Verdict: **pass**
- Evidence:
  - `skills/alert-report/SKILL.md:5` declares `arguments: [hours, region]` — explicit named positional binding. ✓
  - Parse-error discipline: SKILL.md lines 119–128 specify a parse-error path that prints one error line and explicitly states "do **not** fetch any URL, do **not** write any file." ✓
  - Destructive ops: skill writes new reports under `reports/` (creation, not destruction). No `delete`/`overwrite`/`rm`/HTTP-mutation verbs in the body that would require opt-in gating. ✓
- Note: Clean.

## Article VII — Agents

- Verdict: **pass**
- Evidence:
  - `agents/pikud-alerts.md:4` declares `tools: WebFetch, Read, Write, Glob` — explicit list. ✓
  - No `hooks:`, `mcpServers:`, or `permissionMode:` keys in frontmatter (grep returned no matches). ✓
  - External data fetched (WebFetch + `https://www.oref.org.il/...`) → `## Sources` section required. `agents/pikud-alerts.md:148` declares `## Sources`. ✓
- Note: Clean.

---

## Recommended actions

- **Article IV (must-fix):** `pikud-alerts-suite/hooks/inject-latest-alert-summary.sh:6` — replace `.claude/hooks/.audit.log` with `"${CLAUDE_PLUGIN_DATA}/audit.log"` and `mkdir -p` the dir before append. Restores Article IV(2) compliance and aligns the code with the constitution's own reference text on line 94.
- **Article II (should-fix):** rename the README headings to match Article II(2) literally — add `## Overview`, `## Plugin contents`, `## Testing the plugin` (you can rename `## Testing the guardrail without invoking Claude` to `## Testing the plugin` and re-org the top of the file into `## Overview` + `## Plugin contents`). Alternative: amend Article II(2) to require the *content* not the *literal heading*. Either resolves the drift; mechanical auditability favors the rename.
- **Constitution drift (audit table):** the `## Audit` table on `.claude-plugin/constitution.md:177` marks this plugin as passing Article II and IV with the cross-plugin guardrail as the only deviation. This audit disagrees on IV. Update the audit row when the must-fix above lands.

## Sources

- `.claude-plugin/constitution.md`
- `.claude-plugin/marketplace.json`
- `pikud-alerts-suite/.claude-plugin/plugin.json`
- `pikud-alerts-suite/README.md`
- `pikud-alerts-suite/hooks/hooks.json`
- `pikud-alerts-suite/hooks/block-removing-reports.sh`
- `pikud-alerts-suite/hooks/inject-latest-alert-summary.sh`
- `pikud-alerts-suite/agents/pikud-alerts.md`
- `pikud-alerts-suite/skills/alert-report/SKILL.md`
