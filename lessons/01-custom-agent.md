# Lesson 1 — Build your first custom agent

> **Goal:** Create a working `pikud-alerts` agent, invoke it from the main
> Claude conversation, and read the report it produces in `reports/`.
>
> **Time:** ~30 minutes.
> **You will touch:** `.claude/agents/pikud-alerts.md`, `reports/`.

---

## 1. Concept — what *is* an agent?

An **agent** is a Claude Code sub-process with:

- Its own system prompt (the agent's "job description").
- Its own context window — fresh, separate from the main conversation.
- A restricted tool allowlist (least privilege).
- A single deliverable it returns to the calling Claude.

You invoke it via the `Agent` tool (or the user types something that the main
Claude decides to delegate). The main Claude does **not** see the agent's
intermediate reasoning — only its final result. That isolation is the feature.

### When to reach for an agent

| Symptom                                                           | Agent? |
|-------------------------------------------------------------------|--------|
| The work needs many tool calls and would clutter main context     | ✅     |
| You want a *second opinion* (independent reasoning)               | ✅     |
| The work can run in parallel with other work                      | ✅     |
| The task is one or two tool calls and a quick answer              | ❌     |
| The user wants to see every step and steer mid-flight             | ❌     |

---

## 2. Spec — what `pikud-alerts` must do

Following the SDD pattern: write the contract *before* the code.

**Inputs:** A natural-language question about Pikud HaOref alerts. Examples:
- "What alerts are active right now?"
- "Write today's alert report."
- "Was there siren activity in the south in the last hour?"

**Outputs:**
1. A concise summary in the agent's response (≤ 10 lines).
2. A Markdown report written to `reports/YYYY-MM-DD-HHmm.md`.

**Tools allowed:** `WebFetch`, `Read`, `Write`, `Glob`. **Not** `Bash`,
**not** `Edit` outside `reports/`. Least privilege is part of the contract.

**Out of scope (v1):** historical analysis beyond 24h, push notifications,
multi-language output (Hebrew/English only on output, English in code).

**Success criteria:**
- Running the agent produces a file in `reports/` whose timestamp matches the
  invocation time.
- The agent never writes outside `reports/`.
- The agent gracefully handles "no active alerts" without erroring.

---

## 3. Plan — design decisions

| Decision                          | Choice                          | Why                                                                  |
|-----------------------------------|---------------------------------|----------------------------------------------------------------------|
| Model                             | `sonnet`                        | Fetch + summarize is not Opus-grade. Cheaper, faster, sufficient.    |
| Tool allowlist                    | `WebFetch, Read, Write, Glob`   | Enough to fetch, write a report, and check existing reports.         |
| Output location                   | `reports/`                      | Single place to glob + diff later. Keeps repo root clean.            |
| Filename convention               | `YYYY-MM-DD-HHmm.md`            | Lexicographic = chronological sort.                                  |
| Where to define the agent         | `.claude/agents/pikud-alerts.md`| Auto-discovered when this repo is the working directory.             |

---

## 4. Tasks — hands-on

### Task 1 — Read the agent file

Open `.claude/agents/pikud-alerts.md`. Note three things:

1. The **YAML frontmatter** (`name`, `description`, `tools`, `model`) — this is
   how Claude Code finds and configures the agent.
2. The **`description` field is critical** — main Claude reads it to decide
   whether to delegate to this agent. Vague descriptions = agent never used.
3. The **system prompt** below the frontmatter — that *is* the agent's
   personality and constraints.

### Task 2 — Verify discovery

In the Claude Code conversation, ask:

> "List the agents available in this project."

You should see `pikud-alerts` in the response. If you don't, the most common
causes are:
- Wrong working directory (must be the repo root).
- YAML frontmatter syntax error (check indentation, no tabs).

### Task 3 — Invoke the agent

In the conversation, ask:

> "Use the pikud-alerts agent to write today's alert report."

Watch what happens:
- Main Claude calls the `Agent` tool with `subagent_type: pikud-alerts`.
- The agent runs in its own context (you see a tool-use block, not the agent's
  internal turns).
- A new file appears under `reports/`.
- Main Claude summarizes back to you.

### Task 4 — Read the report

Open the newest file under `reports/`. Confirm:
- Timestamp in the filename matches when you ran it.
- The report has the structure the agent's system prompt promises (Summary,
  Active alerts, Recent activity).

---

## 5. Verification checklist

- [ ] `pikud-alerts` appears when you list agents.
- [ ] Invoking it creates a new file in `reports/`.
- [ ] The agent did **not** write anywhere else (run `git status` — only
      `reports/` and (maybe) the agent file should be touched).
- [ ] If oref.org.il is unreachable, the agent reported the failure cleanly
      instead of fabricating data.

---

## 6. Stretch (optional)

Pick one and try it before Lesson 2:

1. **Tighten the contract.** Add a `last_n_hours` parameter to the agent's
   system prompt and have it cover only that window.
2. **Two-language output.** Make the report bilingual (Hebrew title, English
   body). Note how the system prompt must be explicit — agents follow it
   literally.
3. **Failure injection.** Temporarily change the WebFetch URL inside the
   agent's prompt to a 404. Re-run. Does the agent fail safely? If not,
   fix the system prompt.

---

## What you should now believe

- An agent is **a Markdown file**. There is no framework, no code, no SDK.
- The **frontmatter is the API contract**. Tools, model, name, description.
- The **system prompt is the implementation**. Constraints go here, not in
  code.
- **Description quality determines whether the agent gets used.** If main
  Claude doesn't know when to call it, it never gets called.

Next up: **Lesson 2 — Skills**, where the same alert workflow becomes a
user-invokable `/alert-report` command and you'll feel the difference between
"main Claude delegates" and "user triggers a procedure".
