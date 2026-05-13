# Plugin lifecycle — develop → install → update → switch scope

End-to-end reference for a Claude Code plugin: building it, registering it
in a marketplace, installing it at each of the three scope levels (User /
Project / Local), verifying state, updating, and moving between scopes.

---

## 1. Develop the plugin

### 1.1 Directory layout

A plugin is just a folder with a manifest plus any of the optional component
subdirectories.

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # required — the manifest
├── skills/                  # optional — slash-invocable skills
│   └── my-skill/
│       └── SKILL.md
├── agents/                  # optional — sub-agents
│   └── my-agent.md
├── commands/                # optional — custom slash commands
│   └── my-command.md
├── hooks/                   # optional — event hooks
│   └── hooks.json
└── mcp/                     # optional — MCP servers shipped with the plugin
    └── mcp.json
```

### 1.2 Minimal `plugin.json`

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "One line, shown in the picker.",
  "author": { "name": "Your Name" }
}
```

### 1.3 Test locally (no marketplace yet)

While iterating, just point Claude Code at the folder directly:

```text
/plugin marketplace add ./my-plugin
/plugin install my-plugin@my-plugin
```

This is fastest for the inner-dev loop — no commit, no push.

### 1.4 Validate

```bash
claude plugin validate .
```

Checks `plugin.json` schema, skill/agent/command frontmatter, and
`hooks/hooks.json`. Exit code 0 = clean.

---

## 2. Publish via a marketplace

Create `.claude-plugin/marketplace.json` (at the **marketplace** root — can
be the same repo as your plugins, or a dedicated registry repo):

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Acme DevOps" },
  "plugins": [
    { "name": "my-plugin", "source": "./my-plugin" }
  ]
}
```

Register the marketplace once (declarative form — see `doc/marketplaces.md`
for the full source-type table):

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": { "source": "directory", "path": "." }
    }
  }
}
```

From here, installs use the canonical form `<plugin>@<marketplace>`:
`my-plugin@my-marketplace`.

---

## 3. The three install scopes

| Scope | Available where | Lives in (enable flag) | Typical use |
|---|---|---|---|
| **User** | Every project this user opens | `~/.claude/settings.json` → `enabledPlugins` | Personal tools you want everywhere |
| **Project** | Only this project | `<project>/.claude/settings.json` → `enabledPlugins` | Team-shared tools (checked into git) |
| **Local** | Only this project, only this developer | `<project>/.claude/settings.local.json` → `enabledPlugins` | Per-developer overrides (gitignored) |

### Install commands

```text
/plugin install my-plugin@my-marketplace --scope user
/plugin install my-plugin@my-marketplace --scope project
/plugin install my-plugin@my-marketplace --scope local
```

> ⚠ `/plugin install <name>@<marketplace>` **without** `--scope` defaults to
> **user** silently — no picker, no prompt. The interactive picker only
> appears when you run bare `/plugin` and select the plugin from the
> Discover tab.

After any install: `/reload-plugins` to activate without restarting.

---

## 4. Where to verify — per scope

Three files matter regardless of scope, plus the right `settings.json`:

### 4.1 The install ledger (always the same file)

`~/.claude/plugins/installed_plugins.json`

Read the `scope` field:

```json
"my-plugin@my-marketplace": [{
  "scope": "project",            // user | project | local
  "projectPath": "C:\\…\\my-app", // present only for project + local scopes
  "installPath": "C:\\Users\\…\\.claude\\plugins\\cache\\my-marketplace\\my-plugin\\1.0.0",
  "version": "1.0.0",
  "gitCommitSha": "…"
}]
```

**Quick eyeball test:** if `projectPath` is present → project or local scope;
if absent → user scope.

### 4.2 The enable flag — different file per scope

| Scope | File to check |
|---|---|
| User | `~/.claude/settings.json` |
| Project | `<project>/.claude/settings.json` |
| Local | `<project>/.claude/settings.local.json` |

Each should contain:

```json
{
  "enabledPlugins": {
    "my-plugin@my-marketplace": true
  }
}
```

The install ledger says the plugin **exists**; `enabledPlugins` says it's
**active**. Both must align for the plugin to actually load.

### 4.3 The plugin contents (always the same path)

`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`

This is a **snapshot copy** taken at install time. Edits to the source repo
do not flow through automatically — you must `/plugin update` (see §5).

### 4.4 The marketplace registry (always the same file)

`~/.claude/plugins/known_marketplaces.json` — every marketplace Claude has
seen, with last-fetched timestamps. Inspect this when an install fails with
"unknown marketplace".

---

## 5. Update use cases

### 5.1 The source changed and you want the new version

```text
/plugin update my-plugin@my-marketplace
```

Re-fetches the marketplace manifest, then re-pulls the plugin. The
`installedAt` stays put; `lastUpdated` and `gitCommitSha` change.

### 5.2 You're actively editing a plugin in your own repo

The cache is a snapshot — your in-repo edits aren't seen until you update.
Options:

- After each edit: `/plugin update my-plugin@my-marketplace && /reload-plugins`.
- Or set `"autoUpdate": true` on the marketplace entry so each session
  startup re-pulls the manifest.
- Fastest dev loop: skip the marketplace entirely and run
  `/plugin marketplace add ./<plugin-dir>` against the live folder — every
  `/reload-plugins` picks up your changes.

### 5.3 Bulk update all plugins from a marketplace

```text
/plugin marketplace update my-marketplace
```

Refreshes the manifest and updates every installed plugin sourced from it.

### 5.4 A new version was released that breaks you

`installed_plugins.json` keeps `gitCommitSha` — that's your rollback anchor.
Uninstall and reinstall pinned to the older commit via marketplace
`ref`/`sha` if your marketplace exposes it.

---

## 6. Switching scope

The install ledger has no in-place "change scope" verb — you uninstall and
reinstall.

### 6.1 User → Project (the common case)

You installed something personal, then your team wanted it too.

```text
/plugin uninstall my-plugin@my-marketplace --scope user
/plugin install   my-plugin@my-marketplace --scope project
/reload-plugins
```

Then move the `"my-plugin@my-marketplace": true` line:

- **Remove** from `~/.claude/settings.json` → `enabledPlugins`
- **Add** to `<project>/.claude/settings.json` → `enabledPlugins`
- Commit the project settings change.

Verify in `~/.claude/plugins/installed_plugins.json` that `scope` flipped to
`"project"` and `projectPath` appeared.

### 6.2 Project → User

You decide a project-scoped plugin is actually personal infrastructure you
want everywhere.

```text
/plugin uninstall my-plugin@my-marketplace --scope project
/plugin install   my-plugin@my-marketplace --scope user
/reload-plugins
```

Move the enable flag the other direction: out of `<project>/.claude/settings.json`,
into `~/.claude/settings.json`.

### 6.3 Project → Local (overriding for just yourself)

The team has the plugin enabled at project scope, but you want a different
version locally without disturbing teammates.

```text
/plugin uninstall my-plugin@my-marketplace --scope project
/plugin install   my-plugin@my-marketplace --scope local
```

Then move the enable flag into `<project>/.claude/settings.local.json` (this
file is — and should remain — gitignored).

### 6.4 Local → Project (promoting a personal override to the team)

You experimented locally; it's working; now share it.

```text
/plugin uninstall my-plugin@my-marketplace --scope local
/plugin install   my-plugin@my-marketplace --scope project
```

Move the enable flag from `settings.local.json` → `settings.json` and
commit.

### 6.5 Manual edits to `installed_plugins.json` — risky

You *can* hand-edit `~/.claude/plugins/installed_plugins.json` to change
`scope` and add/remove `projectPath`. It will be respected on next session
start. But:

- The next `/plugin install/uninstall/update` may normalize the file and
  revert manual edits.
- No validation runs on manual edits — typos silently break loading.
- The two `enabledPlugins` files (user + project + local) must still be
  reconciled by hand.

Use the uninstall+reinstall route unless you're patching a corrupt state.

---

## 7. Quick troubleshooting matrix

| Symptom | Check |
|---|---|
| Plugin doesn't appear after install | `installed_plugins.json` has the entry? `enabledPlugins` in the right `settings.json`? Did you `/reload-plugins`? |
| Installed but inactive in **only one project** | Plugin is user-scoped but not enabled in user `settings.json`; or project `settings.json` overrides it to `false`. |
| Edits to plugin source not visible | Cache is a snapshot — run `/plugin update` or set `autoUpdate: true` on the marketplace. |
| "Unknown marketplace" on install | Marketplace not in `known_marketplaces.json` — register via `extraKnownMarketplaces` or `/plugin marketplace add`. |
| Wrong scope after install | `/plugin install` defaulted to user. Uninstall and reinstall with explicit `--scope project` / `--scope local`. |

---

## 8. Cross-references

- `doc/marketplaces.md` — source types, S3/git hosting, governance keys.
- `doc/skill-md-template.md` — section template for `SKILL.md` files inside
  a plugin.
- Plugin manifest schema: <https://code.claude.com/docs/en/plugins-reference.md>
