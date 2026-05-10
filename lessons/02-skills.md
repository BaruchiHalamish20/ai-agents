# Lesson 2 — Skills: turn the workflow into a `/command`

> **Goal:** Re-implement the alert workflow as a user-invokable
> `/alert-report` skill. Compare it side-by-side with the `pikud-alerts`
> agent from Lesson 1 and feel the difference between *"main Claude
> delegates"* and *"user triggers a procedure"*.
>
> **Time:** ~30 minutes.
> **You will touch:** `.claude/skills/alert-report/SKILL.md`, `reports/`.
>
> **Source of truth:** Anthropic's official custom-skills docs —
> <https://code.claude.com/docs/en/custom-skills.md>

---

## 1. Concept — what *is* a skill?

A **skill** is a Markdown file (`SKILL.md`) plus optional supporting files,
sitting in its own folder. It gives the user — and only secondarily the
model — a named procedure they can trigger with a slash command.

Mechanically:

- Lives at `.claude/skills/<name>/SKILL.md` (project) or
  `~/.claude/skills/<name>/SKILL.md` (user).
- Each skill is a **folder**, not a lone file. The folder can hold
  templates, scripts, prompts — whatever the procedure needs.
- Invoked by typing `/<skill-name> <args>`. Arguments land in the body via
  `$ARGUMENTS`, `$0`, `$1`, …
- Runs **inline in the calling session's context**. No subprocess, no
  fresh context window. (Optional `context: fork` flips this — but the
  default is inline.)
- Inherits the session's tool allowlist. The `allowed-tools:` field *grants*
  additional access for the duration of the skill — it does not restrict.
- **Live change detection:** edits take effect immediately. No restart
  required (unlike agents).

### Skill vs agent — the contrast that matters

| Dimension                  | Agent (Lesson 1)                          | Skill (this lesson)                              |
|----------------------------|-------------------------------------------|--------------------------------------------------|
| Who triggers it            | Main Claude *decides* to delegate         | **User** types `/skill-name args`                |
| Context                    | Fresh, isolated subprocess                | **Inline** with current conversation             |
| Tools                      | Restricted by `tools:` frontmatter        | Inherited from session; `allowed-tools` extends  |
| Args                       | Implicit (natural-language prompt)        | **Explicit** placeholders (`$ARGUMENTS`, `$1`)   |
| Result returned to         | Main Claude (≤ 10-line summary)           | The user (visible inline)                        |
| File-edit reload           | Session restart required                  | **Live reload**                                  |
| Mental model               | "Specialist consultant I hand work to"    | "A procedure I run myself"                       |

Two consequences worth internalizing now, before you build:

1. A skill **costs tokens in the main context**. An agent does not. If your
   procedure is 30 tool calls long, a skill will pollute your conversation.
2. A skill is **deterministically triggered by the user**. An agent is
   probabilistically triggered by the model's reading of its `description`.
   When the user *must* be in control, skill. When the model should decide,
   agent.

---

## 2. Spec — what `/alert-report` must do

Following SDD: contract before code.

**Inputs:** Zero or one argument — an integer N for `last_n_hours`. Examples:
- `/alert-report` — default window, 24 hours.
- `/alert-report 6` — last 6 hours only.
- `/alert-report 48` — last 48 hours.

**Outputs:**
1. A Markdown report written to `reports/YYYY-MM-DD-HHmm.md` (same shape
   as the agent's output — bilingual, IDT timestamps, etc.).
2. A short confirmation message in the conversation showing the file path
   and a one-line summary.

**Tools the skill needs:** `WebFetch`, `Read`, `Write`, `Glob`. Same set as
the agent, for the same reasons. Listed under `allowed-tools` so they're
pre-approved when the skill runs.

**Out of scope (v1):**
- Scheduling / recurring runs (that's Lesson 3 — hooks & cron).
- Notification delivery (Slack / email).
- Re-using the existing `pikud-alerts` agent. The stretch goal explores
  whether to compose them; v1 keeps the skill self-contained so the
  contrast with Lesson 1 is clean.

**Success criteria:**
- Typing `/alert-report` in any new session produces a report under
  `reports/`.
- Typing `/alert-report 6` produces a report whose "Recent activity"
  section is filtered to the last 6 hours, not 24.
- An invalid argument (e.g. `/alert-report abc`) fails cleanly — the skill
  reports the parse error and does not write a half-built file.

---

## 3. Plan — design decisions

| Decision                            | Choice                                | Why                                                                                                |
|-------------------------------------|---------------------------------------|----------------------------------------------------------------------------------------------------|
| Scope                               | Project (`.claude/skills/`)           | Same as the agent. Ships with the repo. Reviewable in PRs.                                          |
| Folder vs file                      | **Folder** (mandatory)                | Skills are folders by spec. Even a single-file skill is `<name>/SKILL.md`.                          |
| Argument placeholder                | `$ARGUMENTS`                          | One integer, no need for indexed `$1`.                                                              |
| Default when arg missing            | `24`                                  | Mirrors the agent's `last_n_hours` default — same mental model.                                     |
| `allowed-tools`                     | `WebFetch, Read, Write, Glob`         | Pre-approves the four tools the procedure actually needs. Avoids permission prompts mid-run.        |
| Reuse the agent?                    | **No** in v1                          | We want students to feel the inline-context cost firsthand before introducing skill→agent layering. |
| Bilingual report                    | Same rules as the agent               | Hebrew title, English body, bilingual table. Copy the language section verbatim from the agent.     |
| Live reload                         | Yes — implicit from the platform      | Edit `SKILL.md`, hit `/alert-report` again. No restart. Faster iteration than the agent loop.       |

---

## 4. Tasks — hands-on

### Task 1 — Scaffold the skill folder

Create the directory and file:

```
.claude/skills/alert-report/SKILL.md
```

Yes — `alert-report` is a folder. The contents go in `SKILL.md`.

### Task 2 — Write the frontmatter

The minimum useful frontmatter for `/alert-report`:

```yaml
---
name: alert-report
description: Fetch Pikud HaOref alerts and write a bilingual Markdown report under reports/. Optional integer argument = last_n_hours window (default 24).
argument-hint: "[hours]"
allowed-tools: WebFetch, Read, Write, Glob
---
```

Notes:
- `description` is for the user (autocomplete) and the model (deciding
  whether the skill is relevant). Keep it concrete.
- `argument-hint` shows up in the slash-command UI — write it for a human.
- `allowed-tools` is *additive* — it pre-approves these tools, it does not
  forbid others. Permission is still bounded by the session's settings.

### Task 3 — Write the body

Below the frontmatter, write the procedure as if you were instructing a
careful colleague. Borrow heavily from `.claude/agents/pikud-alerts.md` —
the data sources, the bilingual rules, the time-handling rules all apply
verbatim. Two adaptations:

1. **Argument parsing.** At the top of the body, parse `$ARGUMENTS` as an
   integer. If missing, default to 24. If non-integer, abort with a clear
   error message and do not write a file.
2. **No "DO NOT GUESS" current-time fallback.** Skills run inline, so the
   model already has whatever time information lives in the calling
   conversation's context. Use that — but still don't fabricate when
   genuinely unknown.

### Task 4 — Invoke the skill

In a Claude Code session inside this repo, type:

```
/alert-report
```

You should see Claude Code recognize the slash command, run the procedure
inline, and write a new file under `reports/`. Then try:

```
/alert-report 6
```

Confirm the "Recent activity" section reflects a 6-hour window, not 24.

### Task 5 — Compare with the agent

Run both back-to-back:

> "Use the pikud-alerts agent to write today's alert report. last_n_hours = 6"

…then…

```
/alert-report 6
```

Open both reports in `reports/`. They should be substantively identical.
The *experience* is what differs:

- The agent run shows up as a single `Agent` tool-use block — opaque.
- The skill run is visible step-by-step in your conversation — every
  `WebFetch`, every `Write`. You can interrupt mid-flight.

Both have their place. That's the lesson.

---

## 5. Verification checklist

- [ ] `.claude/skills/alert-report/SKILL.md` exists, valid YAML frontmatter.
- [ ] Typing `/` in a fresh session shows `alert-report` in autocomplete.
- [ ] `/alert-report` (no args) writes a report covering 24 hours.
- [ ] `/alert-report 6` writes a report covering 6 hours.
- [ ] `/alert-report abc` does **not** write a file — it reports the parse
      error inline.
- [ ] Editing `SKILL.md` and re-running takes effect immediately, no
      session restart needed.
- [ ] `git status` shows changes only to `.claude/skills/` and `reports/`.

---

## 6. Stretch (optional)

Pick one before Lesson 3:

1. **Compose, don't duplicate.** Rewrite the skill body so it invokes the
   `pikud-alerts` agent instead of fetching data itself. Discuss in 3
   sentences: when is skill-as-agent-frontend the right call, and when does
   it just add a layer?
2. **Indexed args.** Extend the skill to accept two args:
   `/alert-report <hours> <region>` where `<region>` filters the activity
   table to a substring match against the area name. Use `$0` and `$1`.
3. **Permission tightening.** Remove `WebFetch` from `allowed-tools`. Run
   the skill — note the permission prompt. Reason about why
   `allowed-tools` is *grant* rather than *restrict*, and what that means
   for least-privilege design.
4. **Failure injection.** Edit the skill body to call a 404 URL. Re-run.
   Does it fail cleanly the way the agent does, or does it leak
   half-written files into `reports/`? Fix whichever is worse.

---

## What you should now believe

- A skill is **a folder containing `SKILL.md`**. The folder is the unit;
  supporting files belong inside it.
- **Skills are user-triggered, agents are model-triggered.** That single
  difference cascades through context, cost, tooling, and UX.
- **Skills run inline; agents run isolated.** Inline is cheaper to iterate
  on and easier to debug. Isolated is cheaper for the main context and
  better for parallelism.
- **`allowed-tools` grants, it does not restrict.** Tool restriction in
  Claude Code is a session-level concern, not a skill-level one. If you
  need true tool isolation, that's an agent.
- **Live reload changes how you teach.** With agents, students wait for a
  session restart between iterations. With skills, the loop is: edit →
  `/skill` → observe → edit. Use that to your advantage in the lab.

Next up: **Lesson 3 — Hooks & schedules**, where the alert workflow becomes
something that runs *without* you typing anything: a hook fires on
session start, or a cron-style schedule produces an hourly digest. You'll
feel the third trigger model — *"the system runs it on a clock"* —
alongside the two you already know.
