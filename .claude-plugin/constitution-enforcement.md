---
title: Enforcing constitution.md across skills, agents, and plugins
companion_to: .claude-plugin/constitution.md
owner: Baruchi Halamish
last_revised: 2026-06-07
---

# Enforcing `constitution.md`

The auditor (`/plugin-constitution-check`) is already in place — it reads
`.claude-plugin/constitution.md` and writes a per-plugin verdict to
`reports/constitution/`. **Auditing is not enforcement.** The skill itself
says: *"It does not fail the conversation on a `fail` verdict. The report
is informational; gating belongs in PR review."*

This document lists the layers you can stack on top of the auditor to
turn the constitution from advisory text into a real gate. Pick the
layers that match your blast-radius tolerance.

| Layer | Effort | Blocks what | When to add |
|-------|--------|-------------|-------------|
| 1. On-demand audit | already done | nothing | baseline |
| 2. Catalog-wide batch | ~10 min | nothing (visibility only) | first |
| 3. Pre-commit hook | ~30 min | local commits with `fail` verdicts | small team / solo |
| 4. CI gate (GitHub Actions) | ~1 h | merging PRs with `fail` verdicts | any team with PRs |
| 5. Audit table journal | ongoing | marketplace listing | always |

---

## Layer 1 — On-demand audit (current state)

Single-plugin invocation:

```bash
/plugin-constitution-check pikud-alerts-suite
/plugin-constitution-check tzevaadom-alerts-suite
/plugin-constitution-check markdown-suite
/plugin-constitution-check word-to-pdf-suite
```

Each call writes `reports/constitution/<plugin>-<YYYY-MM-DD-HHMM>.md`.
Read-only against the audited plugin. No gating, no blocking — just a
verdict table per article.

**What this catches:** nothing automatically. You have to look.

---

## Layer 2 — Catalog-wide batch

A loop over every entry in `.claude-plugin/marketplace.json`. Two
options.

### Option A — shell script (`scripts/audit-all.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

plugins=$(jq -r '.plugins[].name' .claude-plugin/marketplace.json)
fails=0

for plugin in $plugins; do
  echo ">>> Auditing $plugin"
  # Invoke the skill via the CLI — or paste the call into Claude Code.
  # If running headless, the skill body is callable via Bash on its inputs.
  claude --skill plugin-constitution-check "$plugin" || fails=$((fails+1))
done

echo "Done. $fails plugin(s) raised a non-zero exit."
exit $fails
```

### Option B — `/loop` self-paced

In Claude Code, run:

```
/loop /plugin-constitution-check
```

with no interval, letting the model walk the marketplace list. Faster to
prototype, harder to put in CI.

**What this catches:** drift you forgot to look at. Still no enforcement —
the script's exit code is only as honest as the auditor's roll-up parsing
(see Layer 4 for the real gate).

---

## Layer 3 — Pre-commit / pre-push hook

The first layer that actually **blocks**. Add a hook in
`.claude/settings.json` that runs the audit on any plugin whose folder
appears in the staged diff, parses the roll-up line, and exits non-zero
if any `fail` verdict appears.

Use the `update-config` skill to wire this; the rough shape is:

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit:*)",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_ROOT}/scripts/audit-changed-plugins.sh"
          }
        ]
      }
    ]
  }
}
```

`audit-changed-plugins.sh` does:

1. `git diff --cached --name-only` → derive the set of plugin folders touched.
2. For each, run `/plugin-constitution-check <plugin>`.
3. Parse the report's roll-up line (`N pass, M deviation, K fail, J n/a`).
4. If `K > 0`, print `Blocked by plugin-constitution-check: <plugin> has K fail verdict(s).` to stderr and `exit 2`.

The `Blocked by` prefix is mandated by Article V of the constitution
itself.

**What this catches:** local commits that introduce a `fail`. Doesn't
help if contributors push from elsewhere — that's Layer 4.

**Trade-off:** every commit pays the audit latency. Fine for a four-plugin
catalog, would be heavier at 40.

---

## Layer 4 — CI gate (GitHub Actions)

The only layer that survives a determined contributor.
`.github/workflows/constitution.yml`:

```yaml
name: constitution-audit
on:
  pull_request:
    paths:
      - '.claude-plugin/**'
      - '*-suite/**'
      - 'reports/constitution/**'

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Resolve changed plugins
        id: plugins
        run: |
          changed=$(git diff --name-only origin/${{ github.base_ref }}...HEAD \
            | grep -oE '^[a-z][a-z0-9-]*-suite' | sort -u)
          echo "list=$changed" >> "$GITHUB_OUTPUT"

      - name: Run constitution audit per plugin
        run: |
          fails=0
          for plugin in ${{ steps.plugins.outputs.list }}; do
            echo "::group::Auditing $plugin"
            ./scripts/audit-one.sh "$plugin" || fails=$((fails+1))
            echo "::endgroup::"
          done
          if [ "$fails" -gt 0 ]; then
            echo "::error::$fails plugin(s) failed the constitution audit."
            exit 1
          fi
```

`scripts/audit-one.sh` runs the skill (or replicates its mechanical
checks in plain bash for a CI environment without Claude) and exits
non-zero when the report's roll-up contains `0 fail`.

**What this catches:** any PR — including from branches you never see
locally — that introduces a constitutional violation. This is the
enforcement point the SKILL.md explicitly recommends:
*"gating belongs in PR review."*

**Trade-off:** CI minutes, and the audit script must run *without* the
Claude Code harness. The cheapest path: re-implement the seven mechanical
checks (they are all `Read` + `Grep` + JSON parsing) in a single
~150-line bash or Python script that lives at `scripts/audit-one.sh`.

---

## Layer 5 — Audit table as a journal

`constitution.md` ends with a table:

| Plugin | Articles passing | Documented deviations | Must-fix |

The constitution mandates: *"Future audits SHOULD be appended to this
table, not overwritten — constitutional compliance is a journal, not a
snapshot."*

Treat each row as a row in a ledger:

- When a new plugin lands, append a row.
- When an audit run flips a verdict, append a dated row (don't edit the
  old one).
- When a plugin is removed from `marketplace.json`, strike the row but
  keep it visible.

The table is the human-readable enforcement signal. A row with an open
`Must-fix` cell is the public contract: this plugin shouldn't be in the
marketplace until the cell clears.

**What this catches:** social drift. Reviewers and future-you can see at
a glance which plugins are in good standing without re-running the
auditor.

---

## Recommended adoption order

1. **Layer 2 first.** Write `scripts/audit-all.sh` and run it once. You
   get a snapshot of where the catalog stands today. ~10 minutes.
2. **Layer 5 immediately after.** Update the table in `constitution.md`
   with the verdicts you just generated. Now the journal is current.
3. **Layer 4 next.** Wire the GitHub Actions workflow. This is the only
   layer that *prevents* regressions; everything else just *detects*
   them.
4. **Layer 3 only if** you see violations slipping past local review.
   Most one-person catalogs don't need it.

Skip nothing in the middle. Each layer assumes the previous ones are in
place — the CI gate (Layer 4) reuses the per-plugin script you wrote for
Layer 2, and the journal (Layer 5) is what makes the CI failure
actionable instead of opaque.

---

## What enforcement does NOT mean

- It does not mean the auditor is right. The mechanical checks miss
  semantic issues (a well-formed README full of nonsense still passes
  Article II). Reviewers still review.
- It does not mean `fail` verdicts can't ship. The constitution allows
  *documented deviations* — a plugin can carry a deviation in the audit
  table indefinitely as long as the plugin's README explains why
  (Article V is the standing example).
- It does not mean the constitution is immutable. Articles can be
  revised; bump `Last revised` at the top of `constitution.md` and note
  the change in a `## Revision history` section. Enforcement enforces the
  current text, not the original text.

---

## Sources

- `.claude-plugin/constitution.md` — the articles being enforced.
- `.claude/skills/plugin-constitution-check/SKILL.md` — the auditor.
- `reports/constitution/` — verdict artifacts.
- `.claude-plugin/marketplace.json` — the canonical plugin list.
