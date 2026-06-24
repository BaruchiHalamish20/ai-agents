---
name: plugin-constitution-check
description: Audit a single plugin folder against the seven articles of .claude-plugin/constitution.md. Args — plugin (folder path, required) and an optional --debug flag. Writes a Markdown audit report under reports/constitution/.
argument-hint: "<plugin-path> [--debug]"
arguments: [plugin]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# `/plugin-constitution-check` — Plugin constitution auditor

Audits one plugin folder against every article of
`.claude-plugin/constitution.md` and writes a Markdown report under
`reports/constitution/`. Read-only against the audited plugin — never
mutates it.

The audit returns a per-article verdict from {`pass`, `deviation`,
`fail`, `n/a`}:

- **pass** — article fully satisfied.
- **deviation** — partial compliance OR a compliant exception that is
  documented in the plugin's README.
- **fail** — article violated, no documented justification.
- **n/a** — article does not apply (e.g. Article VII for a plugin
  shipping no agents).

A single deviation does not fail the audit; the table is the artifact,
not a green/red light.

---

## How to run

| Invocation                                             | plugin                  | debug | Effect                                                            |
|--------------------------------------------------------|-------------------------|-------|-------------------------------------------------------------------|
| `/plugin-constitution-check pikud-alerts-suite`        | `pikud-alerts-suite`    | off   | Audit that folder, write report.                                  |
| `/plugin-constitution-check ./markdown-suite --debug`  | `./markdown-suite`      | **on**| Same, plus a `## Debug log` section listing every check evaluated.|
| `/plugin-constitution-check`                           | —                       | —     | **Parse error** — plugin path is required. No file written.       |
| `/plugin-constitution-check does-not-exist`            | —                       | —     | **Parse error** — path missing or not a directory. No file written. |

Worth knowing:
- The path may be relative (resolved against repo root) or absolute.
- A trailing slash is fine; it is stripped before use.
- This skill never writes anything inside the audited plugin — only to
  `reports/constitution/`.

---

## Argument parsing

Inputs available from the platform:

- `$plugin` — first positional token (declared via `arguments: [plugin]`).
- `$ARGUMENTS` — the full whitespace-separated argument string.

### Step 1 — debug flag detection

Scan `$ARGUMENTS` for a standalone token equal to `--debug`. If found,
set `debug = true` and remove that token from further consideration.
Otherwise `debug = false`.

### Step 2 — clean the plugin path

- `plugin_clean = strip_trailing_slash(strip_whitespace($plugin))`
- If `plugin_clean == "--debug"`, treat it as the flag and re-take the
  next token from `$ARGUMENTS` as the plugin path.

### Step 3 — validate the path

Run `Bash`: `test -d "<plugin_clean>" && test -f "<plugin_clean>/.claude-plugin/plugin.json"` (or equivalent `Read` probe). If either fails, **abort cleanly**:

- Print to the user: a one-line error stating which check failed (path
  missing, not a directory, or `.claude-plugin/plugin.json` missing).
- **Do NOT write any report file.** Parse-error path is no-op (Article VI of
  the constitution applied to this skill itself).

### Step 4 — derive metadata

From the validated path:

- `plugin_name = basename(plugin_clean)` (for naming check and report filename).
- `now_local` = `Bash`: `TZ=Asia/Jerusalem date "+%Y-%m-%d %H:%M %Z"` —
  used in the report header.
- `report_stamp` = `Bash`: `TZ=Asia/Jerusalem date "+%Y-%m-%d-%H%M"` —
  used in the report filename.

---

## The seven audits

Run each in order. Record for every article: **verdict** + **evidence**
(file path + line/excerpt) + **note** (one sentence). The report's table
condenses verdict + note; the per-article subsections below the table
hold the evidence.

### Article I — Naming

Checks:

1. `plugin_name` matches `^[a-z][a-z0-9-]*$` (kebab-case, lowercase, no
   underscores, no spaces, no uppercase).
2. Has more than one of {`agents/`, `skills/`, `hooks/`, `commands/`,
   `mcpServers` in plugin.json} ⇒ name SHOULD end with `-suite`.
   Single-component ⇒ name SHOULD end with one of `-tool`, `-helper`,
   `-runner`, `-converter` (this is SHOULD, not MUST — a missing suffix
   downgrades to `deviation`, never `fail`, if articles otherwise pass).
3. `plugin_name` appears in `.claude-plugin/marketplace.json` (read the
   marketplace from the repo root) — divergence between folder name and
   marketplace `name` is a `fail`.

**Tools:** `Read` on `<plugin>/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`; `Glob` for component folders.

### Article II — Required components

Checks:

1. `<plugin>/.claude-plugin/plugin.json` exists and parses as JSON with
   non-empty `name`, `description`, `version` fields.
2. `<plugin>/README.md` exists.
3. README contains a heading line for each of: `Overview`, `Plugin contents`,
   `Testing the plugin`. Match is case-sensitive on the heading text; the
   level (`#`, `##`, `###`) is not constrained.
4. **Conditional check:** if any file under `<plugin>/hooks/` references
   `exit 2`, `"decision": "block"`, or `"decision":"block"` (grep), then
   README MUST contain a heading containing the phrase
   `What this hook does NOT do` (case-insensitive). Absence ⇒ `fail`.
   If no blocking hook exists, this sub-check is `n/a` and does not
   affect the verdict.

**Tools:** `Read` for plugin.json + README; `Grep` for heading detection
and for blocking-hook detection.

### Article III — Versioning

Checks:

1. `plugin.json.version` matches `^\d+\.\d+\.\d+(-[\w.]+)?$` (semver, with
   optional pre-release). Anything starting with a git SHA-like
   `^[0-9a-f]{7,}$` or empty ⇒ `fail`.
2. If `plugin.json.version` has MAJOR ≥ 2, the README MUST contain a
   heading `## Breaking changes`. Absence ⇒ `fail`. (For MAJOR < 2 this
   sub-check is `n/a`.)
3. Marketplace consistency: locate the matching entry in
   `.claude-plugin/marketplace.json` (`plugins[].name == plugin_name`).
   If that entry has a `version` field, it MUST equal
   `plugin.json.version`. If it is omitted, that is acceptable (the
   constitution explicitly allows omission). Mismatch ⇒ `fail`.

**Tools:** `Read` on the two JSON files.

### Article IV — Paths and state

Checks:

1. Grep every file in `<plugin>/.claude-plugin/` and `<plugin>/hooks/`
   plus any `hooks.json`, `.mcp.json`, `.lsp.json` files inside the
   plugin tree, for hardcoded absolute paths (e.g. patterns matching
   `^/`, `^C:\\`, `^/Users/`, `^/home/`, `^/root/`) that are not
   prefixed by `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_PLUGIN_DATA}`.
   Any match in those files ⇒ `fail` and list the offending file:line.
2. Inverse check: any script invoked from those configs that uses paths
   relative to the plugin SHOULD use `${CLAUDE_PLUGIN_ROOT}` —
   `grep -rn 'CLAUDE_PLUGIN_ROOT\|CLAUDE_PLUGIN_DATA' <plugin>/` should
   return at least one hit if the plugin ships any config that
   references a script. Zero hits when the plugin clearly has hooks
   ⇒ `deviation` (not `fail` — could be a config-less plugin).
3. Heuristic check for state-in-ROOT: grep plugin scripts for writes
   to `${CLAUDE_PLUGIN_ROOT}/...` of typical state extensions
   (`.log`, `.cache`, `.db`, `.state`, `audit.log`). Any hit ⇒ `fail`
   (state must go to DATA, not ROOT).

**Tools:** `Grep` (use the `-n` line-number mode); `Glob` to enumerate
config files first.

### Article V — Hooks and safety

Checks:

1. Find every `hooks.json` (or `hooks` block in `plugin.json`) under
   `<plugin>/`. For each `PreToolUse` entry, the entry MUST have a
   `matcher` field set to a non-empty string. Missing/empty matcher
   ⇒ `fail`, with the file path of the offending entry.
2. For each shell hook under `<plugin>/hooks/` that exits with status 2
   or emits `"decision": "block"`, grep the same file for a stderr
   message matching the literal substring `Blocked by ` followed by the
   plugin name (case-insensitive on the name). Missing message ⇒
   `fail` and quote the file/line of the exit-2/decision-block site.
3. Cross-plugin scope: if any file under `<plugin>/hooks/` references
   paths outside the plugin root (e.g. `reports/`, `lessons/`, `..`,
   anything not inside `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_PLUGIN_DATA}`),
   then the README MUST contain language acknowledging that scope
   (look for the substring `cross-plugin` or `project-wide guardrail`).
   If the README acknowledges it ⇒ `deviation` (documented
   exception, per the `pikud-alerts-suite` precedent). If not ⇒ `fail`.

**Tools:** `Read` + `Grep`. If no hooks exist at all, the entire
article is `n/a`.

### Article VI — Skills

For each `SKILL.md` under `<plugin>/skills/*/SKILL.md`:

1. Read the frontmatter. Count positional args from the `arguments:`
   field (or from `argument-hint`). If ≥ 2 positional args are
   declared, the frontmatter MUST include `arguments: [arg1, arg2, ...]`
   (a list, not `$ARGUMENTS` only). Missing list with 2+ args
   ⇒ `deviation`.
2. Argument-validation discipline (manual heuristic — not fully
   automatable): grep the SKILL.md body for the literal phrases
   `parse error`, `abort`, or `do NOT write` near the argument-handling
   section. Absence ⇒ `deviation` (the body may still validate, but
   the contract is not in writing).
3. Destructive-op opt-in: grep the body for words that suggest
   destructive behavior — `delete`, `overwrite`, `remove`, `rm`,
   `truncate`, plus network mutation verbs (`POST`, `PUT`, `DELETE`
   HTTP methods). If any are present, the frontmatter or body MUST
   reference a flag (e.g. `--force`, `--confirm`, `--apply`) gating the
   destructive path. Absence ⇒ `fail`.

If `<plugin>/skills/` does not exist, this article is `n/a`.

**Tools:** `Glob` for SKILL.md files; `Read` + `Grep` on each.

### Article VII — Agents

For each `<plugin>/agents/*.md`:

1. Frontmatter MUST declare `tools:` (the list of allowed tools).
   Missing ⇒ `fail`. `tools: *` or `tools: All` is acceptable as
   explicit declaration; an absent field is not.
2. Frontmatter MUST NOT declare any of: `hooks`, `mcpServers`,
   `permissionMode`. Presence of any ⇒ `fail` and list the offending
   key (these are platform-blocked, but the article is defense-in-depth).
3. If the agent body or description mentions external data fetching
   (heuristic: grep for `WebFetch`, `curl`, `http://`, `https://`, or
   the phrases `fetches`, `external API`), the body MUST reference a
   required `## Sources` section in the artifacts the agent produces.
   Absence ⇒ `deviation`.

If `<plugin>/agents/` does not exist, this article is `n/a`.

**Tools:** `Glob` + `Read` + `Grep`.

---

## Writing the report

After all seven audits are recorded, write the report to:

```
reports/constitution/<plugin_name>-<report_stamp>.md
```

(e.g. `reports/constitution/pikud-alerts-suite-2026-05-24-1830.md`.)
Create `reports/constitution/` via `Bash`: `mkdir -p reports/constitution`
if it does not exist.

### Report skeleton

```markdown
---
plugin: <plugin_name>
audited_against: .claude-plugin/constitution.md
generated_at: <now_local>
generated_by: /plugin-constitution-check
debug: <true|false>
---

# Constitution audit — `<plugin_name>`

Audited against `.claude-plugin/constitution.md` on <now_local>.

## Summary

| Article | Title              | Verdict     | Note                                                  |
|---------|--------------------|-------------|-------------------------------------------------------|
| I       | Naming             | pass / deviation / fail / n/a | one-line note from the audit               |
| II      | Required components| ...         | ...                                                   |
| III     | Versioning         | ...         | ...                                                   |
| IV      | Paths and state    | ...         | ...                                                   |
| V       | Hooks and safety   | ...         | ...                                                   |
| VI      | Skills             | ...         | ...                                                   |
| VII     | Agents             | ...         | ...                                                   |

**Roll-up:** `<N> pass, <M> deviation, <K> fail, <J> n/a`.

---

## Article I — Naming

- Verdict: **<verdict>**
- Evidence: <file:line or "n/a">
- Note: <one-sentence why>

(Repeat the same three-line block for Articles II through VII.)

---

## Recommended actions

Bulleted list of must-fix items (one per `fail` verdict) and
should-fix items (one per `deviation` worth chasing). Each item names
the file to edit and the article it satisfies.

If there are zero fails and zero deviations, this section reads
exactly: `- Nothing to fix; plugin is fully constitutional.`

---

## Sources

- `.claude-plugin/constitution.md`
- `<plugin>/.claude-plugin/plugin.json`
- `<plugin>/README.md` (or "missing")
- Every other file inspected, one bullet each.
```

### Debug section (only when `--debug` is set)

Append at the end:

```markdown
---

## Debug log

For each article (I–VII), one block:

### Article <N>
- Checks evaluated: <comma-separated list of sub-check IDs>
- Files read: <bulleted list with line counts>
- Grep patterns run: <bulleted list>
- Final verdict computation: <one sentence>
```

The debug log is the auditable trail. Without it, the report is a
verdict; with it, the report is a verdict you can argue with.

---

## After writing

Print one line to the user with the report path and the roll-up, e.g.:

```
Wrote reports/constitution/pikud-alerts-suite-2026-05-24-1830.md — 6 pass, 1 deviation, 0 fail, 0 n/a.
```

Do not paraphrase the verdicts inline — the report is the artifact;
the chat line is the pointer.

---

## What this skill does NOT do

- It does not mutate the audited plugin. No `Edit`/`Write` calls
  against any file inside `<plugin>/` — only inside `reports/constitution/`.
- It does not fail the conversation on a `fail` verdict. The report is
  informational; gating belongs in PR review (Article VI of the
  project-wide constitution, not this skill).
- It does not audit the *content* of articles — only their
  *mechanical* checks. "Is the README well-written?" is out of scope;
  "does the README have the three required headings?" is in scope.
- It does not look across plugins. One invocation, one plugin. To
  audit the whole catalog, call the skill four times (one per entry
  in `.claude-plugin/marketplace.json`).
- It does not enforce the project-wide `CONSTITUTION.md` (lesson 6) —
  only the plugin-scoped `.claude-plugin/constitution.md` (lesson 5).
  The two constitutions audit different things.
