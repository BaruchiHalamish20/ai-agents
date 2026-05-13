# Personal Organizations

Snapshot from `GET https://claude.ai/api/organizations` for account `bhalamish20@gmail.com`.

- **Account UUID:** `cb2a855b-b5e8-4933-9d1c-21e964c15b3d`
- **Captured:** 2026-05-11

---

## Org 1 — Claude Max subscription (claude.ai)

| Field | Value |
|---|---|
| Name | `bhalamish20@gmail.com's Organization` |
| UUID | `86a86ec0-8c4e-4684-95c1-87f8dfa29cce` |
| Numeric ID | `2491893` |
| Capabilities | `chat`, `claude_max` |
| Rate limit tier | `default_claude_max_5x` |
| Billing type | `stripe_subscription` |
| Merchant of record | `anthropic` |
| Free credits status | `available` |
| Data retention | `default` |
| Created | `2023-10-23T14:34:47Z` |
| Updated | `2026-05-10T17:44:16Z` |
| Parent org | none |

**Purpose:** this is your **claude.ai** workspace tied to your Claude Max subscription. It owns chat conversations, projects, and **Claude Code routines created via OAuth subscription auth** — including `trig_01CtHash8yBp4pnZZCNJvg8Q` (pikud-hourly-digest).

**Visible at:** https://claude.ai (main app), https://claude.ai/code/routines, https://claude.ai/settings/account

---

## Org 2 — API / Console (Individual)

| Field | Value |
|---|---|
| Name | `Baruchi's Individual Org` |
| UUID | `c88411e3-5961-4945-aa9f-452aecdfdd0c` |
| Numeric ID | `75999174` |
| Capabilities | `api`, `api_individual` |
| Rate limit tier | `auto_prepaid_tier_0` |
| Billing type | `prepaid` |
| Merchant of record | `anthropic` |
| Free credits status | `available` |
| Data retention | `default` |
| Created | `2025-10-30T20:49:45Z` |
| Updated | `2025-12-16T06:52:24Z` |
| Parent org | none |

**Purpose:** this is your **Anthropic Console** workspace for **API key usage** (prepaid credits). Used when calling the Claude API directly or when Claude Code is authed via `ANTHROPIC_API_KEY`.

**Visible at:** https://console.anthropic.com (API keys, usage, billing). **Not** shown in the claude.ai workspace switcher.

---

## Account vs Organization

- **Account UUID** (`cb2a855b-…`) = your user identity. Same across both orgs.
- **Organization UUID** = the workspace that owns a resource (routine, conversation, API key). Different per org.
- A personal user with both a Claude Max subscription and Console API usage will always have **two separate orgs**, even though it's one human.

## Where each org's Claude Code routines live

| Auth method on the CLI | Org that owns the routine | Visible on web at |
|---|---|---|
| OAuth (Claude Max subscription) | Org 1 — `86a86ec0-…` | https://claude.ai/code/routines |
| `ANTHROPIC_API_KEY` (Console) | Org 2 — `c88411e3-…` | API only — no claude.ai UI |

## How to find which organization you're currently working in

### From the Claude Code CLI

Run:

```bash
claude auth status --text
```

Example output (current state of this machine, 2026-05-11):

```
Login method: Claude Max account
Organization: bhalamish20@gmail.com's Organization
Email: bhalamish20@gmail.com
```

How to read it:

| Line in output                  | What it tells you                                                         |
|---------------------------------|---------------------------------------------------------------------------|
| `Login method: Claude Max account` | OAuth via Claude Max subscription → routines and usage land in **Org 1** (`86a86ec0-…`). |
| `Login method: API key`         | Authed via `ANTHROPIC_API_KEY` → calls bill to **Org 2** (`c88411e3-…`).  |
| `Organization: <name>`          | The human-readable org name. `bhalamish20@gmail.com's Organization` → Org 1. `Baruchi's Individual Org` → Org 2. |
| `Email:`                        | The account UUID's primary email — same across both orgs.                  |

### From the web

- **claude.ai** — sign in and look at the workspace switcher in the top-left. You'll only ever see **Org 1** here; Org 2 is API-only and never appears in the claude.ai UI.
- **console.anthropic.com** — sign in to confirm Org 2 exists; the workspace header shows `Baruchi's Individual Org`.

### From the raw API

```bash
curl -s -H "Cookie: <claude.ai session cookie>" \
  https://claude.ai/api/organizations | jq '.[] | {name, uuid, capabilities}'
```

Returns both orgs in one array with their capabilities (`claude_max` vs `api_individual`) — the most authoritative source if the CLI output is ambiguous.

### Switching the active org from the CLI

Claude Code's active auth is global per OS user, so "switching org" means switching auth method:

| Want to use…              | Do this                                                            |
|---------------------------|--------------------------------------------------------------------|
| Org 1 (Claude Max OAuth)  | `claude logout`, then `claude login` and pick "Claude account".    |
| Org 2 (API key)           | Set `ANTHROPIC_API_KEY=<key>` in your shell, then `claude logout` so Claude Code falls back to the env var. Verify with `claude auth status --text` — login method should read `API key`. |

Switching mid-session is not supported — finish the session, change auth, start a new one.
