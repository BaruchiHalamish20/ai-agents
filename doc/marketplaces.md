# Claude Code marketplaces — quick reference

A marketplace is a registry that lists plugins. You register a marketplace
once (interactively via `/plugin marketplace add`, or declaratively via
`extraKnownMarketplaces` in `.claude/settings.json`); from then on Claude
Code can install/update plugins from it.

This doc summarizes the source types, the schema for `extraKnownMarketplaces`,
and how to host a marketplace yourself (including AWS S3).

---

## 1. Two ways to register

### Interactive (CLI)

```text
/plugin marketplace add <source>
```

### Declarative (settings.json)

```json
{
  "extraKnownMarketplaces": {
    "my-mp": {
      "source": { "source": "<type>", "<...>": "<...>" },
      "autoUpdate": true
    }
  }
}
```

Both accept the same set of source types — `extraKnownMarketplaces` is just
the persistent, version-controllable equivalent of running the CLI command.

---

## 2. Source types

| `source.source` | Required fields | When to use |
|---|---|---|
| `directory` | `path` | Local folder containing `.claude-plugin/marketplace.json`. Common for the host project itself. |
| `file` | `path` | Direct path to a `marketplace.json` (anywhere on disk). |
| `github` | `repo` (`owner/repo`) | GitHub-hosted marketplace. Optional: `ref` (branch/tag), `path` (subpath in repo), `sparsePaths`. |
| `git` | `url` | Any git URL — GitLab, Bitbucket, self-hosted, AWS CodeCommit, Azure DevOps. HTTPS or `git@`. Optional: `ref`, `path`, `sparsePaths`. |
| `url` | `url` | Direct HTTPS to a hosted `marketplace.json`. Use this for S3, CloudFront, or any web server. Optional: `headers` (e.g. auth). |
| `npm` | `package` | NPM package whose contents include a `marketplace.json`. |

This project currently uses `directory`:

```json
"ai-agents-local": {
  "source": { "source": "directory", "path": "." }
}
```

---

## 3. Hosting on AWS S3

There is no `s3://` source type. Serve `marketplace.json` over HTTPS and
register with `"source": "url"`.

**Public bucket:**

```json
"company-mp": {
  "source": {
    "source": "url",
    "url": "https://my-plugins-bucket.s3.amazonaws.com/marketplace.json"
  }
}
```

**Private bucket (presigned URL):** expiry-bound, so unsuitable for long-lived
team config — fine for one-off installs.

**Private bucket via CloudFront (recommended for teams):**

```json
"company-mp": {
  "source": {
    "source": "url",
    "url": "https://plugins.example.com/marketplace.json",
    "headers": { "Authorization": "Bearer $PLUGIN_REGISTRY_TOKEN" }
  }
}
```

CloudFront with signed cookies or a custom auth header gives you a stable
URL plus access control.

---

## 4. Hosting on a generic git server

```json
"internal-mp": {
  "source": {
    "source": "git",
    "url": "https://gitlab.example.com/devops/claude-plugins.git",
    "ref": "main"
  }
}
```

The marketplace manifest is expected at `.claude-plugin/marketplace.json`
inside the repo unless you override `path`.

For monorepos, use `sparsePaths` to clone only the plugin directories:

```json
"sparsePaths": [".claude-plugin", "plugins"]
```

---

## 5. The `marketplace.json` itself

Minimum valid structure:

```json
{
  "name": "company-plugins",
  "owner": { "name": "Acme DevOps" },
  "plugins": [
    {
      "name": "deploy-helper",
      "source": "./plugins/deploy-helper"
    }
  ]
}
```

- `name` — kebab-case, must match the marketplace's registered ID.
- `owner.name` — display name.
- `plugins[].source` — relative path (within the marketplace repo) or a
  remote source object (`github`, `git-subdir`, `npm`, `url`).

Place this at `.claude-plugin/marketplace.json` at the repo root (the
default Claude Code looks for).

---

## 6. Enterprise governance (managed settings)

Three policy-level keys, only meaningful in managed/MDM settings:

- `strictKnownMarketplaces` — exact-match allowlist; only these sources can
  be added at all. Use `hostPattern` / `pathPattern` entries to allow whole
  hosts (e.g. `^github\.acme\.com$`) without enumerating every repo.
- `blockedMarketplaces` — exact-match denylist; checked before download.
- `pluginTrustMessage` — extra text appended to the trust prompt shown
  before any plugin install.

Pair `strictKnownMarketplaces` (the policy gate) with `extraKnownMarketplaces`
(the registration) to ship a locked-down list to teammates.

---

## 7. Per-entry optional fields

Both source types accept:

- `autoUpdate` (boolean) — refresh manifest and installed plugins at startup.
- `installLocation` (string) — override the local cache path (rarely needed).

---

## 8. Reference

- Docs: <https://code.claude.com/docs/en/plugin-marketplaces.md>
- Schema: <https://json.schemastore.org/claude-code-settings.json>
- Schema field: `extraKnownMarketplaces` (see the full anyOf list of source variants).

---

## Note about adding remarks inside `.claude/settings.json`

The settings parser is **strict JSON** — it rejects `//` comments and refuses
unknown top-level keys (validated against the published schema). That is why
this reference lives in `doc/` rather than as a comment near the
`extraKnownMarketplaces` block.
