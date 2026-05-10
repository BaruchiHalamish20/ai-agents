# Reference — How to debug a Claude Code agent

Practitioner guide to debugging custom sub-agents in Claude Code. Use as
a teaching slide, a troubleshooting checklist, or a pattern library when
your agent does the wrong thing and you can't tell why.

> **Source of truth (mechanics):** Anthropic's official sub-agents docs —
> <https://code.claude.com/docs/en/sub-agents.md>
>
> The mechanics (how agents are loaded, isolated, invoked) come from the
> docs above. The *techniques* in this file are practitioner patterns
> derived from working with the platform. If a mechanic ever drifts, the
> docs win.

---

## TL;DR

You cannot see an agent's reasoning, intermediate tool calls, or model
output that didn't make the final return. The main Claude only sees the
agent's ≤ 10-line summary inside the `Agent` tool-use block.

So debugging is **forcing the agent to surface its own state in observable
artifacts** — files, return messages, instrumented prompts. There are
six techniques, in increasing order of effort, plus two Claude-Code-specific
gotchas to rule out first.

---

## The hard fact

The `Agent` tool boundary is opaque by design. The agent's:

- `WebFetch` calls and their responses
- internal model reasoning / scratchpad
- retries, fallbacks, decisions to skip a step
- silent tool-permission denials

…are all hidden from the calling session. The only signals you get are:

1. The agent's final return message (≤ 10 lines, by its own contract).
2. Files the agent wrote (its deliverable).
3. The wall-clock duration and token usage of the `Agent` tool-use block.

Everything else — you have to instrument.

---

## Six debugging techniques

Listed in increasing order of effort. Stop at the first one that gives
you the signal you need.

### 1. Read the deliverable — especially Sources and Notes

Agents that write a file are the best-instrumented. The file persists
after the agent exits, and it usually leaks state.

- A `## Sources` section that lists every URL fetched is the cheapest
  debug signal you can build into an agent's contract. If the URLs in
  Sources don't match the URLs in the agent's spec on disk, you have a
  cache problem (see Gotcha #1).
- A `## Notes` section for "anything the operator should know" gives the
  agent a place to vent when something didn't go to plan.

**Pattern:** every data-fetching agent should write a Sources block. Make
it part of the spec, not optional.

### 2. Compare the loaded agent vs the agent on disk

If the agent is doing something its disk file shouldn't allow, the loaded
copy is probably stale (the cache gotcha). Two ways to inspect what is
actually loaded:

- Run `/agents` in the Claude Code UI — shows the registry as Claude Code
  sees it right now.
- Ask the main Claude: *"List all agents and show their full system
  prompts."* If the prompt the platform reports differs from what's in
  `<name>.md`, the registration is stale.

Fix: restart the session, or edit through `/agents` (which reloads live —
unlike a manual file edit).

### 3. Reproduce the agent's work in the main session, manually

If the agent returns weird data, run the same tool calls yourself in the
main conversation. You bypass the agent's prompt and see raw responses.

This is how you discover problems like "the page is JS-rendered and
WebFetch sees an empty shell" or "this endpoint returns 403 to
programmatic clients" — issues that look like *no data* from the agent
but are actually *blocked sources*.

**Pattern:** always have a "what would I do without the agent" version of
the workflow. If you can't reproduce the agent's task by hand in three or
four tool calls, the agent's contract is probably too broad.

### 4. Add a `debug` parameter to the agent's spec

Document an input parameter:

```markdown
- **`debug`** *(boolean, optional, default `false`)* — when true, append a
  "Debug log" section to the report listing every URL fetched, every HTTP
  status code, every parse decision, and every fallback path taken.
```

Then invoke the agent with `debug=true`. The agent's hidden state spills
into the file, where you can read it after the run.

This pattern is durable — leave the `debug` parameter in production. It
costs nothing when off, and it's invaluable when something goes wrong
weeks later and you can't reproduce.

### 5. Ask the agent to be verbose *in its return message*

For a one-off debug run, override the 10-line rule from the calling side:

> "For this run, ignore your 'Response to the calling Claude' rule.
> Return everything: every URL fetched, every response status, every
> decision point. I'm debugging."

The agent will dump more state into its return. Cheaper than editing the
agent file when you only need one debug run.

### 6. Bisect with a minimum viable agent

If the agent is failing in a way you can't pin down, replace its body
with a one-liner — for example:

> "Write the string `hello` to `reports/debug.md` and return success."

If even that fails, the problem is infrastructure (frontmatter, tool
allowlist, scope, cache) — not your prompt. Then add complexity back one
block at a time, running between each step. Classic bisect.

---

## What you cannot do

Set expectations honestly:

- **You cannot see the agent's chain-of-thought** from the calling session.
- **You cannot set breakpoints, live-attach, or step through** an agent.
- **You cannot distinguish** *"model decided not to call the tool"* from
  *"tool call failed silently"* without instrumentation built into the
  agent itself.
- **You cannot recover state from a crashed run** — Claude Code does not
  save an agent transcript by default.

If you need any of those, you need a different design — typically a skill
running inline (visible step-by-step in the main conversation) rather
than an agent.

---

## Two Claude-Code-specific gotchas to rule out first

Before reaching for the six techniques above, check these two — they
account for ~80% of "my agent is acting weird" reports.

### Gotcha #1 — Stale agent cache

Manual edits to `.claude/agents/<name>.md` **do not reload mid-session**.
Claude Code does agent discovery at session startup. If you edited the
agent file after the session started, the running session is still
serving the *previous* version of the prompt to every sub-agent
invocation.

**Symptom:** the agent does something the current file should forbid, or
ignores something the current file should require. The Sources block (or
any "what URLs did you actually fetch" introspection) is the giveaway.

**Fix:** restart the session, or edit the agent through the `/agents`
slash command (which reloads live).

See <./agent-discovery.md> for the full discovery rules.

### Gotcha #2 — Tool allowlist mismatch

If the agent's prompt asks the agent to do something its frontmatter
`tools:` line doesn't permit, the agent does **not** error cleanly. It
improvises around the gap — often by hallucinating output, or by
returning a degenerate "I couldn't do that" message that looks like a
data-source failure.

**Symptom:** the agent's behaviour is technically possible but
inconsistent — sometimes it succeeds (when the request happens to fit
within its tool grant), sometimes it claims data is unavailable (when it
needs a tool it doesn't have).

**Fix:** read the prompt and the `tools:` line side-by-side. Every verb
in the prompt ("fetch", "list", "read prior reports", "write the file")
needs a corresponding tool in the allowlist.

---

## Diagnostic checklist — "my agent is doing something wrong"

Run through these in order. Most cases are resolved by step 3.

1. **Does the deliverable file exist?** If yes, read it. Sources/Notes
   often answer the question.
2. **Do the URLs/files referenced in the deliverable match the agent's
   spec on disk?** If no — Gotcha #1, stale cache. Restart or `/agents`.
3. **Does the prompt require a tool not in the `tools:` allowlist?**
   If yes — Gotcha #2. Add the tool or rewrite the prompt.
4. **Can you reproduce the agent's task by hand with raw tools in the
   main session?** If yes — the agent's prompt is wrong. If no — the
   data sources or your assumptions are wrong.
5. **Does the agent have a `debug` parameter?** Re-run with `debug=true`
   and read the Debug log section.
6. **Replace the agent body with a "hello world" one-liner and run.** If
   it still fails, infrastructure (frontmatter, scope, permissions) — not
   the prompt.

---

## How this maps to the lab

- **Lesson 1 builds an agent.** Students hit Gotcha #1 the first time
  they edit the agent file mid-session. Use that moment to introduce
  this reference.
- **Lesson 2 builds a skill.** The contrast is sharp — skills reload
  live and run inline, so most of the techniques here are unnecessary
  for skills. Use that contrast to reinforce *when* to choose an agent
  (cost: harder to debug) vs a skill (cost: pollutes main context).
- **Stretch goals — failure injection.** The pattern of swapping a URL
  to `https://httpstat.us/404` and verifying the agent's "data
  unavailable" path is the cleanest exercise for technique #1 (read the
  Sources block) and Gotcha #1 (the swap doesn't take effect without a
  reload).
