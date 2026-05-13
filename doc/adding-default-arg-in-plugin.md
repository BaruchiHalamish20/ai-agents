# Adding a default-argument value to a Claude Code plugin

How to make a plugin prompt the installer for a default value (e.g.
`default_region`) and have your skill / agent / hook fall back to it
when no explicit argument is supplied.

This is what Claude Code calls **`userConfig`** — an install-time
prompt declared in the plugin's manifest, whose value gets
substituted into your plugin's content at runtime.

> Worked example used throughout this doc: adding `default_region` to
> `pikud-alerts-suite` so that `/alert-report 48` (no region arg) falls
> back to a user-chosen Hebrew substring like `מנרה`.

---

## TL;DR — three edits + a refresh

1. **`<plugin>/.claude-plugin/plugin.json`** → add a `userConfig` block.
2. **`<plugin>/skills/<skill>/SKILL.md`** (or the agent / hook script) → reference `${user_config.<key>}`.
3. **Activate:** `/plugin marketplace update <name>` then `/plugin install <plugin>@<marketplace>` (or restart if enabled via `settings.json`'s `enabledPlugins`).

That's it. There is **no** `PluginInstall` / `PostInstall` hook event — `userConfig` is built into the install flow itself.

---

## 1. Declare the prompt in `plugin.json`

Add a `userConfig` object next to your existing manifest fields.
Each key is the config name; each value is a typed field schema.

```json
{
  "name": "pikud-alerts-suite",
  "description": "…",
  "version": "1.0.0",
  "keywords": ["…"],
  "userConfig": {
    "default_region": {
      "type": "string",
      "title": "Default region filter",
      "description": "Hebrew substring applied to area names when /alert-report is called with no region argument. Leave empty to mean 'no filter — show all areas'.",
      "required": false,
      "default": ""
    }
  }
}
```

### Field reference

| Field         | Required | Allowed values                                                  | What it does                                                              |
|---------------|----------|-----------------------------------------------------------------|---------------------------------------------------------------------------|
| `type`        | ✅       | `string`, `number`, `boolean`, `directory`, `file`              | Field type. Drives input validation.                                      |
| `title`       | ✅       | string                                                          | Label shown above the prompt at install time.                             |
| `description` | ✅       | string                                                          | Help text shown beneath the prompt.                                       |
| `required`    | optional | `true` / `false` (default `false`)                              | When `true`, install fails on empty input.                                |
| `default`     | optional | matches `type`                                                  | Pre-filled value if the user hits Enter without typing.                   |
| `sensitive`   | optional | `true` / `false` (default `false`)                              | Masks input and stores in OS keychain instead of `settings.json`.         |
| `multiple`    | optional | `true` / `false` (`string` only)                                | Accept an array of strings.                                               |
| `min` / `max` | optional | numbers (`number` only)                                         | Bounds.                                                                   |

You can declare more than one config field — the prompt walks through them all in declaration order at install time.

---

## 2. Reference it in your skill / agent / hook

The exact substitution syntax is:

```
${user_config.<KEY>}
```

Case-sensitive. The `<KEY>` is the name you used in `plugin.json`'s `userConfig` map.

### Where substitution is performed

| Surface                                  | Substituted? |
|------------------------------------------|--------------|
| Hook commands (the `command` field)      | ✅ Yes       |
| Monitor commands                         | ✅ Yes       |
| MCP server configs                       | ✅ Yes       |
| LSP server configs                       | ✅ Yes       |
| Skill body (`SKILL.md` Markdown content) | ✅ Yes — **only if non-sensitive** |
| Agent body (`<agent>.md` Markdown)       | ✅ Yes — **only if non-sensitive** |
| Sensitive values inside skill/agent text | ❌ No (security)                  |

The replacement happens **on disk before the content reaches the model**, so by the time the skill body is read, the literal `${user_config.default_region}` token is already swapped for the user's actual value (e.g. `מנרה`).

### Worked example — the `/alert-report` skill

Argument parsing already cleans `$region` into `region_clean`. The fallback gets inserted as a new step before validation:

```markdown
### Step 2 — clean positional values

Strip surrounding whitespace and commas from `$hours` and `$region`:
- `hours_clean = strip(',', strip_whitespace($hours))`
- `region_clean = strip(',', strip_whitespace($region))`

### Step 2.5 — user-config fallback for region

If `region_clean` is empty after Step 2, fall back to the install-time
default:

- `region_clean = "${user_config.default_region}"`

If the user accepted the empty default at install time, this is a
no-op and the skill proceeds with no region filter — same behavior
as before the fallback existed.
```

Two important details from this example:

- **Explicit beats implicit.** A user who calls `/alert-report 48 ""` with an explicit empty quoted region still bypasses the fallback. The fallback only fires when the positional arg is *absent*, not when it is *explicitly empty*.
- **The empty-default no-op pattern.** Setting `default: ""` in `plugin.json` means the prompt offers nothing. If the user doesn't fill it in, the skill behaves exactly as it did before you added `userConfig` — zero behavior change. Good for backward compatibility.

---

## 3. Where the answered value is stored

| Sensitive | Storage                                                                                                  |
|-----------|----------------------------------------------------------------------------------------------------------|
| `false`   | `~/.claude/settings.json` → `pluginConfigs[<plugin-id>@<marketplace>].options.<key>`                     |
| `true`    | OS keychain (macOS Keychain, Windows Credential Manager) or `~/.claude/.credentials.json` as fallback. ~2 KB total limit. |

Concrete layout (after a user types `מנרה` for our example):

```json
{
  "pluginConfigs": {
    "pikud-alerts-suite@ai-agents-local": {
      "options": {
        "default_region": "מנרה"
      }
    }
  }
}
```

You can hand-edit this file to seed a value without going through the prompt — useful for the `enabledPlugins` path (see caveats below).

---

## 4. Activating the change

Inside an already-running Claude Code session:

```text
/plugin marketplace update <marketplace-name>     # re-read the manifest changes
/plugin install <plugin-name>@<marketplace-name>  # re-prompts for userConfig
```

For our worked example, that's:

```text
/plugin marketplace update ai-agents-local
/plugin install pikud-alerts-suite@ai-agents-local
```

Alternative — restart Claude Code. On startup it re-reads
`plugin.json` and (in theory) re-prompts if the schema changed.

---

## 5. Caveats — the things the docs don't quite spell out

### The `enabledPlugins` path may skip the prompt

If your plugin is auto-enabled via `.claude/settings.json`'s
`enabledPlugins` map (the version-controlled path that teammates get
on first clone), the install-time prompt **probably does not fire** —
the docs don't explicitly say, but every other version-controlled
mechanism in Claude Code follows this pattern.

Workarounds:

1. **Hand-edit the value** into `~/.claude/settings.json`'s
   `pluginConfigs` block (shape shown above) before starting Claude
   Code.
2. **Trigger an interactive install** of the plugin: from a running
   session, `/plugin install <name>@<marketplace>` runs the prompt
   flow even when `enabledPlugins` has it enabled.
3. **Provide a sensible `default`** in `plugin.json` so the
   prompt-skipped path is harmless (the empty-default no-op pattern
   above is the safe option).

### Re-prompting after edits to `plugin.json`

If you edit a `userConfig` schema *after* the user already installed
the plugin (e.g. you add a new field), Claude Code's behavior is not
explicitly documented. The reliable path: bump the plugin's `version`
in `plugin.json`, then run `/plugin marketplace update` +
`/plugin install` again.

### Sensitive values are NOT substituted into skill / agent text

`${user_config.<secret_key>}` will refuse to substitute inside skill
or agent Markdown content if `sensitive: true`. Only command / config
surfaces (hooks, MCP, LSP) get the substitution. This is by design —
preventing secrets from leaking into model context.

If you need to *use* a secret inside an agent, the right pattern is
to put it in a hook that runs first and writes the value to a file
the agent reads — or use an MCP server that holds the secret. Don't
fight the `sensitive: true` boundary.

### `${user_config.X}` only works inside plugin-shipped files

This substitution mechanism is plugin-scoped. It will **not** work in
a stand-alone `.claude/skills/<name>/SKILL.md` outside a plugin
manifest, because there's no plugin manifest to declare the
`userConfig` schema in. If you want the same skill in two places
(once stand-alone for tutorial use, once inside a plugin for the
"real" path), keep the stand-alone copy simpler (hard-coded defaults
or no defaults) and only put the substitution in the plugin copy.

---

## 6. Checklist before you commit

- [ ] `plugin.json` validates as JSON (run it through a parser; bad
      JSON silently breaks the install).
- [ ] Each `userConfig.<key>` has `type` + `title` + `description`
      (the three required fields). Missing one = silent skip of the
      whole config block in some Claude Code versions.
- [ ] At least one `default` is set, OR `required: true` is set, OR
      both — never leave a config that has neither, because the
      "user pressed Enter" path then produces an undefined value.
- [ ] The skill / agent / hook body that references
      `${user_config.<key>}` correctly handles the case where the
      substitution resolves to an empty string (default `""`).
- [ ] The `sensitive: true` flag is on for anything you would not
      want printed in a tool-use trace or copied into context.
- [ ] You ran `/plugin marketplace update <name>` after editing
      `plugin.json` — otherwise the marketplace cache is stale and
      your changes don't apply.
- [ ] You tested both the "user filled in a value" and "user
      accepted the default" paths, because the second is the one
      that breaks first when you forget to set a sensible default.

---

## 7. Anti-patterns

- **Putting business logic in `userConfig` defaults.** Defaults are
  for sensible starting values, not for branching behavior. If your
  skill behaves *differently* based on whether `default_region` is
  empty vs. populated, that's fine — but the *decision* lives in the
  skill, not in the config field's metadata.
- **Storing API keys via non-sensitive `userConfig`.** They'll land
  in `~/.claude/settings.json` in plaintext. Use `sensitive: true`.
- **One config field per slash-command argument.** `userConfig`
  is for *installation defaults*, not a substitute for arguments.
  Don't move all of `[hours]`, `[region]`, `[--debug]` into config
  fields — the argument surface is what makes the skill interactive.
- **Forgetting `/plugin marketplace update`** after editing
  `plugin.json`. This is the #1 reason a `userConfig` change doesn't
  appear to do anything — the cache was stale.
- **Hand-editing `pluginConfigs` in `settings.json` without keeping
  the keys in sync** with the `plugin.json` schema. If you rename a
  field in `plugin.json`, the stored value under the old name is
  ignored and you'll think the substitution is broken.
