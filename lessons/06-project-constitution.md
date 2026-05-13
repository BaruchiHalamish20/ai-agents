# Lesson 6 — Project-wide SDD constitution

> **Goal:** Write the constitution that governs how *all* work happens
> in this repo — not just plugin development. After lesson 5 you had
> rules for what may ship in the catalog; lesson 6 sets the rules for
> the spec → plan → tasks workflow that produces every change to the
> codebase.
>
> One act:
>
> - Author `CONSTITUTION.md` at the **repo root** with ten articles
>   covering the SDD hierarchy, specs, plans, tasks, branches, commits,
>   PR review, testing, AI-tool usage, and how the constitution
>   relates to `CLAUDE.md` and harness config.
> - Stand up the supporting directory structure: `specs/`, `plans/`,
>   `tasks/` — each with a template and a README.
> - Audit one *recent* change against the constitution. Did it follow
>   the workflow? If not, what would have been different?
>
> **Time:** ~75 minutes (the writing is fast; the *thinking* about
> your own team's bar is the slow part).
> **You will touch:** new `CONSTITUTION.md`, new `specs/`, new
> `plans/`, new `tasks/`, possibly small edits to `README.md` and
> `CLAUDE.md`.
>
> **Source of truth (background reading):**
> - Spec-Driven Development (Anthropic) — <https://docs.claude.com/en/docs/build-with-claude/sdd.md>
> - Claude Code best practices — <https://www.anthropic.com/engineering/claude-code-best-practices>
> - The plugin-scoped constitution you wrote in lesson 5 (the shape
>   generalizes).

---

## 1. Concept

### What "project-wide SDD constitution" means

Lesson 5 governed a **catalog** — the plugins listed in
`.claude-plugin/marketplace.json`. Lesson 6 governs the **work** —
every spec written, every plan approved, every task closed, every
commit landed, every PR merged, regardless of whether the change
touches plugins, lessons, hooks, reports, or this constitution
itself.

The distinction matters:

| Plugin-scoped constitution (lesson 5)         | Project-wide constitution (lesson 6)              |
|------------------------------------------------|---------------------------------------------------|
| Lives at `.claude-plugin/constitution.md`      | Lives at `CONSTITUTION.md` (repo root)            |
| Governs **artifacts** in a catalog             | Governs **workflow** producing all artifacts      |
| Audience: plugin authors + marketplace operator| Audience: every contributor to the repo           |
| 7 articles (naming → agents)                   | 10 articles (workflow → governance)               |
| Useful even without Claude Code               | Useful even without Claude Code (it's about SDD)  |
| Travels with the marketplace                   | Travels with the repo                             |

The project-wide constitution is **not Claude-Code-specific**. It says
*"here's how we change this codebase."* That's true whether the
contributor is a human, an agent, a contractor, or you six months from
now trying to remember what you decided.

### The SDD hierarchy

Spec-Driven Development is the framing Anthropic uses for working with
AI on serious code. Four layers, each constraining the one below:

```
CONSTITUTION   — "what bar must any change clear"     (project-wide, stable)
   ↓
SPEC           — "what this specific change must do"  (per-change, lives in specs/)
   ↓
PLAN           — "how we'll execute the spec"         (per-change, lives in plans/)
   ↓
TASKS          — "the discrete steps"                 (per-change, lives in tasks/)
   ↓
CODE           — "the result of executing tasks"      (the diff)
```

Each layer answers a different question and has a different shape:

- **Constitution** is *what the team always does*. Stable. Changes by
  amendment, not by commit.
- **Spec** is *what this change does and doesn't do*. Sharp boundary.
  Written once per change, referenced forever after.
- **Plan** is *how we'll execute the spec*. Includes decisions,
  trade-offs, the path not taken. Disposable but recorded.
- **Tasks** are *the discrete steps*. Granular enough to commit each
  one. Owned, time-boxed, checkable.

You already practiced this shape in lessons 1–5 — every lesson's
sections are *concept → spec → plan → tasks*. Lesson 6 extracts the
pattern and codifies it at the repo level.

### Why the constitution is separate from CLAUDE.md

`CLAUDE.md` (user-level, project-level, or imported) tells **Claude
how to behave**. It's harness configuration: tools, style, what
context to load. It's read every session.

`CONSTITUTION.md` tells **the team how to work**. It's a process
document. It's read once when you onboard, and re-read when there's
a dispute. Claude itself doesn't enforce it — humans do, via PR
review.

Confusing them is the most common SDD rollout mistake. Symptoms:
- Process rules ("specs must list out-of-scope") buried in
  CLAUDE.md, where they get re-loaded every session and pad context
  for no benefit.
- Behavior rules ("use TaskCreate for multi-step work") in
  CONSTITUTION.md, where humans don't read them often enough to
  remember and Claude never sees them.

Rule of thumb: *if a rule changes how Claude responds in a session,
it belongs in CLAUDE.md. If a rule changes how a human reviews a PR,
it belongs in CONSTITUTION.md.*

### What's enforced and what isn't

The plugin-scoped constitution had a clean enforcement story:
`claude plugin validate .` checks JSON validity, kebab-case names,
and required fields. The constitution articles that go beyond that
are enforced by audit.

The project-wide constitution has almost **no automated
enforcement** out of the box. The articles are enforced by:

1. **PR reviewers**, who check the diff against the relevant
   articles.
2. **The amendment process**, which forces you to either fix the
   violation or amend the article — never silently ignore it.
3. **The audit ritual** (Task 6 below), where you run the
   constitution against a recent change and find the drift before
   it compounds.

If you want enforcement, the stretch goals propose pre-commit hooks,
PR templates, and a CI check. Those are real but they come *after*
the articles stabilize. Premature automation locks in articles that
haven't yet proved themselves.

---

## 2. Spec

**Inputs:**
- The plugin-scoped constitution from lesson 5 (the shape generalizes).
- Your accumulated patterns from lessons 1–5 — every lesson followed
  spec → plan → tasks already; you've been practicing without naming
  it.
- The team you work with (or yourself + future-you) and what they'll
  actually do.

**Outputs:**
- `CONSTITUTION.md` at the **repo root** (not under `.claude/` or
  `.claude-plugin/`), declaring ten articles.
- `specs/`, `plans/`, `tasks/` directories at the repo root, each
  with a `README.md` (purpose) and a `template.md` (skeleton for a
  new entry).
- A one-time audit: pick a *recent change* from `git log` and write
  *what the spec, plan, and tasks would have looked like* if you'd
  written them up front. The gap teaches you which articles bite
  hardest in practice.

**Out of scope (v1):**
- Automated constitutional enforcement (pre-commit hooks, CI checks)
  — listed in stretch.
- Spec-Kit integration (a different tooling layer; the constitution
  is independent of any specific spec tool).
- Multi-repo constitution (this one governs *this* repo only).

**Success criteria:**
- `CONSTITUTION.md` exists at repo root, has all ten articles, each
  with a **rule**, a **why**, and a concrete **applicability** note
  (when does this article actually bite?).
- `specs/`, `plans/`, `tasks/` exist with README + template.
- One recent change has been audited against the constitution; the
  audit lives in `specs/AUDIT-<short-name>.md` and lists at least
  three findings (gaps + things that already passed).
- Anyone in your team can read `CONSTITUTION.md` in 15 minutes and
  agree on what's allowed and what isn't.

---

## 3. Plan

| Decision                                  | Choice                                         | Why                                                                                                                                |
|-------------------------------------------|------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Constitution file location                | `CONSTITUTION.md` at repo root                  | Not Claude-Code-specific. Stays visible on GitHub front page. `.claude-plugin/` would couple it to the plugin tooling — wrong.    |
| Filename convention                       | UPPERCASE — `CONSTITUTION.md`, `README.md`, `SECURITY.md` | Convention for top-level governance docs across most repos. Distinguishes them from regular `.md` files.                          |
| Article count                             | **10**                                          | More than 7 (plugin scope) because workflow has more failure modes than artifact shape. Fewer than 15 keeps it readable.            |
| Article shape                             | Rule, Why, Applicability, Reference                 | "Reference" is what makes the article concrete — every article cites a real file or git commit so it doesn't drift into platitudes.|
| `specs/` / `plans/` / `tasks/` location   | Repo root, sibling to `lessons/` and `reports/` | Standard SDD layout. `docs/specs` is a common alternative; reject that because it implies these are docs (they're not — they're commitments). |
| Per-change naming                          | `YYYY-MM-DD-short-slug.md` per file             | Time-sortable, greppable, survives reorgs. Same pattern as `reports/`.                                                              |
| What lives in `tasks/` vs in the PR        | `tasks/` = the *list*; PR description = the *status*  | The list is durable; status is ephemeral. Don't duplicate.                                                                          |
| Audit deliverable                          | `specs/AUDIT-<short-name>.md`                   | Audits *are* specs — they're a contract about how the workflow itself is performing. Same directory, prefixed for filterability.   |
| Enforcement                                | Manual review against checklist                 | Until articles stabilize, automating them ossifies the wrong rules. Revisit after the third audit.                                  |
| Version of the constitution                | Track via `## Revision history` section + a `version:` line in the frontmatter | The constitution itself follows SDD discipline — amendments leave a paper trail.                                                    |

---

## 4. Tasks

### Task 1 — Create the directory scaffolding

From the repo root:

```bash
mkdir -p specs plans tasks
```

For each directory, create a `README.md` that says (a) what lives
here and (b) the naming convention. Three short files, ~20 lines
each.

`specs/README.md`:

```markdown
# specs/

One file per non-trivial change. Each file contains:

- **Inputs** — what the change starts from.
- **Outputs** — concrete deliverables (files, behaviors, API surface).
- **Out of scope** — what this change explicitly does NOT do.
- **Success criteria** — observable checks that the change is done.

Naming: `YYYY-MM-DD-short-slug.md` (e.g. `2026-05-13-watcher-script.md`).

A change requires a spec when it would take more than ~1 hour OR
touches files outside its obvious blast radius. See
`CONSTITUTION.md` Article II.
```

`plans/README.md`:

```markdown
# plans/

One file per spec that needed a non-trivial execution path. Each
plan answers: *given the spec, what's the order of operations, what
decisions are involved, what alternatives were considered and
rejected, and where are the risks?*

Naming: `YYYY-MM-DD-short-slug.md` (matches the corresponding spec).

A plan is required when the spec implies multiple files, multiple
sessions, or any decision worth recording. See `CONSTITUTION.md`
Article III.
```

`tasks/README.md`:

```markdown
# tasks/

Per-change checklists. One file per change, owned and dated, with
each task individually checkable. Closed tasks stay in the file —
this is a journal, not a Kanban board.

Naming: `YYYY-MM-DD-short-slug.md`.

A task list is required for any change with 3+ discrete steps OR
when the work spans more than one session. See `CONSTITUTION.md`
Article IV.
```

### Task 2 — Templates

Drop a `template.md` in each of `specs/`, `plans/`, `tasks/`. These
are starting skeletons — copy + rename when you start a new change.

`specs/template.md`:

```markdown
---
title: <short title>
date: YYYY-MM-DD
status: draft | accepted | superseded
owner: <name>
---

# <Title>

## Inputs
-

## Outputs
-

## Out of scope
-

## Success criteria
-

## Related
- Spec:
- Plan:  plans/YYYY-MM-DD-<slug>.md
- Tasks: tasks/YYYY-MM-DD-<slug>.md
```

`plans/template.md`:

```markdown
---
title: <short title>
date: YYYY-MM-DD
spec: specs/YYYY-MM-DD-<slug>.md
status: draft | approved | executed | abandoned
---

# Plan — <Title>

## Decisions

| Decision | Choice | Why |
|----------|--------|-----|
|          |        |     |

## Alternatives rejected
-

## Risks
-

## Order of operations
1.
2.

## Done means
-
```

`tasks/template.md`:

```markdown
---
title: <short title>
date: YYYY-MM-DD
spec: specs/YYYY-MM-DD-<slug>.md
plan: plans/YYYY-MM-DD-<slug>.md
owner: <name>
---

# Tasks — <Title>

- [ ] Task 1 — description (est: …)
- [ ] Task 2 — description (est: …)
- [ ] Task 3 — description (est: …)

## Notes / blockers
-
```

### Task 3 — Author CONSTITUTION.md

Create `CONSTITUTION.md` at the repo root with the ten articles
below. Copy the content as-is, then edit the references to match
your repo's actual files.

```markdown
---
title: Project Constitution
version: 1.0.0
last_revised: YYYY-MM-DD
owner: <name>
applies_to: every change to this repository
---

# Project Constitution

This document governs how changes are made to this repository.
Every contributor (human, agent, paired session) is bound by it.
Amendments require a PR that updates this file and includes a
`## Revision history` entry below.

---

## Article I — The SDD hierarchy

1. Every non-trivial change MUST follow the hierarchy:
   **constitution → spec → plan → tasks → code.**
2. A trivial change (typo, single-file format fix, dependency
   bump with no API change) MAY skip spec/plan/tasks but MUST
   still pass Articles V–VIII (branches, commits, PR review,
   testing).
3. The hierarchy may be collapsed (e.g. spec and plan in one
   document) when the change is small enough that separating them
   would be ceremony — but the *content* of each layer MUST exist
   somewhere.

**Why:** Mixing layers is the most common failure mode. A spec
that includes implementation choices isn't a spec — it's a plan
that prevents you from re-thinking the implementation. A plan
without a spec is a guess.

**Applicability:** Any change estimated at >1 hour, OR touching
files outside the change's obvious blast radius, OR producing a
new public artifact (plugin, lesson, top-level doc).

**Reference:** `lessons/05-marketplace-and-constitution.md`
follows the hierarchy explicitly — sections 1–4 map to
constitution-concept → spec → plan → tasks.

---

## Article II — Specs

1. A spec MUST list **inputs**, **outputs**, **out of scope**, and
   **success criteria** — four named sections, in that order.
2. "Out of scope" is mandatory. A spec that doesn't say what it
   *won't* do is not a spec; it's a wish.
3. Specs live in `specs/` and are named `YYYY-MM-DD-short-slug.md`.
4. Specs are append-only. A spec that needs to change is either
   amended (status: `accepted` → `accepted (revised)`) or
   superseded by a new spec that links back to it.

**Why:** Spec drift is the silent killer of multi-session work.
Pinning a spec to a date and an immutable contract means you can
look back and know what was *originally* agreed.

**Applicability:** Required for every change where Article I
mandates a spec.

**Reference:** `specs/README.md`; the spec section of every lesson
(`## 2. Spec`).

---

## Article III — Plans

1. A plan MUST include a **decisions table** (decision / choice /
   why), an **alternatives rejected** list, and an **order of
   operations**.
2. Plans MAY be abandoned. An abandoned plan keeps its file with
   status `abandoned` and a one-line explanation of why.
3. Plans live in `plans/` and link to their spec in the frontmatter.

**Why:** The "alternatives rejected" line is what saves you the
next time the same option resurfaces. Without it, you re-litigate
old decisions every six months.

**Applicability:** Required when the spec implies multiple files,
multiple sessions, or any decision worth recording.

**Reference:** `plans/README.md`; the `## 3. Plan` decision table
in every lesson.

---

## Article IV — Tasks

1. Tasks MUST be small enough that each maps to a single commit.
2. Each task MUST be checkable from outside (a file exists, a test
   passes, a command exits 0) — not "I think it's done."
3. Completed tasks stay in the file. The task list is a journal,
   not a backlog.

**Why:** Granularity is what makes work resumable. A single task
that says "build the feature" can't be checked, can't be paused,
can't be picked up by someone else.

**Applicability:** Required for any change with 3+ discrete steps
or spanning more than one session.

**Reference:** `tasks/README.md`; lesson task lists in section 4
of each lesson.

---

## Article V — Branches and commits

1. Work MUST happen on a feature branch named
   `<owner>/<short-slug>` or `<type>/<short-slug>` (e.g.
   `feat/word-pdf-watcher`).
2. Commits MUST be atomic (one logical change per commit) and
   their messages MUST be of the form
   `<type>(<scope>): <imperative summary>` — e.g.
   `feat(watcher): add FileSystemWatcher service`.
3. Commits authored or co-authored by AI MUST include a
   `Co-Authored-By: <Model> <noreply@anthropic.com>` trailer.
   AI assistance is acknowledged, not hidden.
4. Force-pushes to `master`/`main` are forbidden. Force-pushes to
   feature branches are allowed up to PR open; after PR open,
   they require a PR comment explaining the rewrite.

**Why:** Atomic commits are bisectable. Type-prefix messages are
machine-readable for changelog generation. AI attribution makes
the history honest about how the code was produced.

**Applicability:** Every commit.

**Reference:** Recent git log — the existing `Co-Authored-By:
Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailers
demonstrate the attribution rule already in practice.

---

## Article VI — Pull requests and review

1. A PR is required for any change touching the constitution, the
   marketplace, plugins, hooks, settings, or any file under
   `lessons/`. Direct pushes to `master` are reserved for the
   reports/auto-* automation and personal scratch directories.
2. The PR description MUST link to the spec (and plan if one
   exists). A PR with no linked spec is rejected with a request
   to write one.
3. PR review MUST check Articles I–IV (workflow), V (commit
   hygiene), VII (testing), and VIII (AI usage) explicitly. The
   PR template enumerates these as a checklist.
4. A PR MUST NOT be merged with failing CI, unresolved review
   comments, or a stale status.

**Why:** The PR is where the constitution gets enforced.
Articles I–IV exist on disk regardless; what makes them binding
is that PR review checks them.

**Applicability:** Every change matching the trigger list above.

**Reference:** The lesson 5 marketplace PR (when it lands)
becomes the worked example.

---

## Article VII — Testing policy

1. Code paths that *can* be tested MUST be tested. "Can be tested"
   is defined as: pure logic, deterministic output, no required
   live external dependency.
2. Code paths that *can't* be tested (UI behavior, network calls
   to external services, hardware interactions) MUST have a
   documented manual verification recipe in the spec's
   "Success criteria" section.
3. A new spec MAY explicitly opt out of (1) with a stated reason
   in the spec. Opt-outs are visible in audit.

**Why:** Untested code is debt. Mandatory tests with mandatory
opt-out makes the debt visible; it doesn't pretend the debt
doesn't exist.

**Applicability:** Every code change. Documentation-only changes
are exempt.

**Reference:** Lesson 1's `pikud-alerts` agent has an implicit
manual verification recipe in `lessons/01-custom-agent.md` §5.

---

## Article VIII — AI tool usage

1. Any commit, file, or PR produced wholly or partly with AI
   assistance MUST be reviewed by a human before merge. AI is a
   collaborator, not a committer.
2. AI MUST NOT be the sole signer of: changes to this
   constitution, changes to the marketplace, changes to security
   settings, deletion of any directory containing more than three
   files.
3. Prompts that produce code MAY be archived under
   `prompts/YYYY-MM-DD-<slug>.md` for traceability when the
   prompt is the load-bearing artifact. (Optional unless the
   spec requires it.)
4. AI-generated output that the author has not read MUST NOT
   ship. "I told Claude to write tests" is not a substitute for
   reading the tests.

**Why:** AI-tool usage is the new gradient that didn't exist in
older constitutions. Skipping this article leaves you with one of
two failure modes: pretending AI wasn't used (dishonest) or
trusting AI output blindly (unsafe). The article is the middle
path.

**Applicability:** Every change. The discipline is to read what
ships, regardless of who wrote it.

**Reference:** This very lesson — its commit message will carry a
`Co-Authored-By:` trailer; this paragraph was reviewed by a human
before it landed.

---

## Article IX — Relation to CLAUDE.md and harness config

1. `CLAUDE.md` files (user, project, or imported) govern **how
   Claude behaves in a session**. The constitution governs **how
   the team works**. Rules belong in one or the other, not both.
2. When a rule is ambiguous (e.g. "always use TaskCreate for
   multi-step work" — is that behavior or process?), apply the
   test: *does the rule change Claude's response inside a
   session, or does it change a human's review of a PR?* The
   answer dictates the file.
3. The constitution MUST NOT be loaded into the session's context
   automatically (it would pad every conversation with rules
   Claude already enforces in PR review). It MAY be referenced
   from `CLAUDE.md` as a one-line pointer.

**Why:** Mixing concerns produces rule sprawl. The same line
ending up in three files invites drift; isolating concerns means
each file stays the canonical source of its own rules.

**Applicability:** Whenever you're tempted to add a rule and
aren't sure where it goes, apply the test in (2).

**Reference:** The user's global `~/.claude/CLAUDE.md` contains
behavior rules ("output expectations: production-ready artifacts");
this file contains process rules ("PRs MUST link to a spec").
They don't overlap.

---

## Article X — Amendments and audit

1. Amending this constitution requires a PR that updates the
   article, updates the `version:` field (semver), and adds a
   `## Revision history` line at the bottom.
2. An **audit ritual** runs at minimum quarterly: pick a recent
   change, walk through every article, score it pass / deviation
   / fail. File the result as `specs/AUDIT-YYYY-Qn.md`.
3. Three consecutive audits with the same deviation are a signal
   that the article is wrong — amend it.

**Why:** A constitution that can't be amended ossifies. A
constitution amended by feel drifts. The audit ritual is what
keeps it both *current* and *intentional*.

**Applicability:** Continuously. The audit is the only
non-skippable ritual.

**Reference:** Task 6 of `lessons/06-project-constitution.md`
walks the first audit.

---

## Revision history

- `1.0.0` (YYYY-MM-DD) — Initial ratification (lesson 6).
```

### Task 4 — Hook the constitution into discoverability

Two small edits to make the new structure visible.

In your **root `README.md`** (the repo's), add a short section:

```markdown
## Working in this repo

This project follows Spec-Driven Development. Every non-trivial
change starts with a spec under `specs/`, may have a plan under
`plans/`, and tracks discrete steps under `tasks/`.

The bar every change must clear is documented in
[`CONSTITUTION.md`](./CONSTITUTION.md). Read it before opening
your first PR.
```

In your project-level `.claude/CLAUDE.md` (create if missing), add
one line pointing at the constitution — *not the contents of it*:

```markdown
This project follows the rules in `CONSTITUTION.md` at the repo
root. Behaviorally, prefer minimal, direct changes; defer to the
constitution for process matters.
```

Note we are **not** importing CONSTITUTION.md via `@CONSTITUTION.md`.
That would load all ~10KB of rules into every session — wasteful and
contrary to Article IX(3). The one-line pointer is enough; Claude
will read the file when relevant.

### Task 5 — Pick a recent change and audit it

Find one change that landed in the last week or two. Easy
candidates:

```bash
git log --oneline -20
```

For the audit, pick something *non-trivial*. Looking at the recent
log: the `chore(reports): Pikud HaOref 48h digest 2026-05-11`
commit is a chore — not a great audit candidate. The earlier
`reports`, `bc6beee .gitignore`, and the merge of
`reports/auto-2026-05-11` are similar. Aim instead for *the
addition of a plugin* or *the watcher-and-convert work* — those
are the multi-file, multi-session changes the constitution is
designed to govern.

Suppose you pick the watcher work (the
`.claude/hooks/watch-and-convert.ps1` + scheduled task +
`doc/auto-conversion-pipelines.md` chain). Create
`specs/AUDIT-2026-05-13-watcher.md`:

```markdown
---
title: Audit — watcher service (retrospective)
date: 2026-05-13
target: doc/auto-conversion-pipelines.md and the watcher script
status: complete
---

# Audit — watcher service

Audited the work that landed `watch-and-convert.ps1`,
`install-watcher-task.ps1`, and `doc/auto-conversion-pipelines.md`
against the ten articles.

| Article | Score          | Note                                                                              |
|---------|----------------|-----------------------------------------------------------------------------------|
| I       | deviation      | Workflow was concept → code → docs; the spec was *implicit* in the conversation, not in `specs/`. |
| II      | fail           | No `specs/` entry was created up front. The doc that landed reads like a spec retrospectively — fold it back. |
| III     | n/a            | The change was small enough that an explicit plan would have been ceremony.       |
| IV      | deviation      | Tasks existed inline in chat (TaskCreate), but were not preserved in `tasks/`.    |
| V       | pass           | Commits were atomic with type-prefix; AI attribution trailer present.             |
| VI      | n/a            | Direct push; not gated by PR. Note: under the new constitution, this *would* require a PR (touches `.claude/`). |
| VII     | deviation      | No tests for the watcher. Manual verification recipe lives in the doc; counts as an Article VII opt-out by virtue of being a Windows-Scheduled-Task feature. |
| VIII    | pass           | Human reviewed every change before it landed.                                     |
| IX      | pass           | The doc lives at `doc/auto-conversion-pipelines.md`; CLAUDE.md was not mutated.   |
| X       | n/a            | First audit since constitution ratified.                                          |

## Findings (must-fix going forward)

1. **Spec retrofit.** Move the "What changed and why" section of
   `doc/auto-conversion-pipelines.md` (the first three sections) into
   `specs/2026-05-13-watcher-service.md`. Leave the *how-to* parts
   in the doc.
2. **Task list retrofit.** Re-create the task list from the
   conversation history into
   `tasks/2026-05-13-watcher-service.md`, all items checked.
3. **Process gap on direct push.** Under the new constitution, this
   work would have required a PR. Note that we proceeded without
   one *because the constitution did not exist yet at the time of
   the work* — the audit catches the gap, the new constitution
   forecloses repeats.

## What passed (worth preserving)

- The commit hygiene (atomic + attribution) was already correct.
- The deliverable doc (`doc/auto-conversion-pipelines.md`) is
  comprehensive — converting it to a spec is a re-organization,
  not a rewrite.
```

This audit is the unit of trust between the constitution and the
work. It says: *"on this date, we measured the gap between rule
and practice, and here's what we'll do about it."*

### Task 6 — Action one audit finding

Pick the most consequential finding from Task 5 and act on it now.
For the example above, the cheapest action is finding #1 —
retrofit the watcher work's spec.

Create `specs/2026-05-13-watcher-service.md` using the template
from Task 2, fill in inputs/outputs/out-of-scope/success criteria
from your memory of the work. Mark it `status: accepted` with a
note that it was authored retrospectively.

This isn't busywork — it's the **demonstration** that the
constitution and the directory structure cooperate. If retrofitting
a spec is painful, you'll feel the pain of skipping one next time.

### Task 7 — Commit

```bash
git add CONSTITUTION.md specs/ plans/ tasks/ README.md .claude/CLAUDE.md
git status   # double-check nothing unexpected
git commit -m "$(cat <<'EOF'
feat(governance): ratify project-wide SDD constitution

Adds CONSTITUTION.md at repo root (ten articles covering the SDD
hierarchy, specs, plans, tasks, branches, commits, PR review,
testing, AI usage, CLAUDE.md relation, and amendments). Stands up
specs/, plans/, tasks/ with README + template. Includes the first
audit (specs/AUDIT-2026-05-13-watcher.md) and the retrofit spec
that closes the most consequential finding.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note the commit message itself follows Article V (type-prefix,
imperative, attribution trailer).

---

## 5. Verification checklist

- [ ] `CONSTITUTION.md` exists at the repo root with all ten
      articles. Each article has rule, why, applicability, reference.
- [ ] `specs/`, `plans/`, `tasks/` directories exist with `README.md`
      and `template.md` in each.
- [ ] `README.md` (repo root) has the "Working in this repo" section
      pointing at `CONSTITUTION.md`.
- [ ] `.claude/CLAUDE.md` has a one-line pointer to the constitution
      (does NOT import its contents).
- [ ] At least one audit exists under `specs/AUDIT-*.md` with all ten
      articles scored.
- [ ] At least one audit finding has been actioned (a retrofitted
      spec, a task list, or an explicit deviation note).
- [ ] `git log` shows a commit with a type-prefix message and an AI
      attribution trailer.

---

## 6. Stretch (optional)

Pick one before declaring the lesson complete.

1. **PR template.** Add
   `.github/pull_request_template.md` with the Article VI checklist
   (links to spec, links to plan, Article V commit check, Article
   VII testing check, Article VIII review check). The constitution
   becomes a UI element.
2. **`/sdd-audit` skill.** Write a skill that takes a git revision
   range and walks the diff against each article, returning a
   pass / deviation / fail table. The audit ritual becomes
   one-command.
3. **Pre-commit hook.** Add `.git/hooks/pre-commit` (or the
   `pre-commit` package) that rejects commits whose first line
   doesn't match the `^<type>(<scope>): ` regex. Article V
   becomes binding at the keystroke level.
4. **Spec-Kit integration.** Anthropic's Spec-Kit is a CLI for
   maintaining specs and plans as YAML. Wire it to write to
   `specs/` / `plans/` directly. The constitution stays the law;
   Spec-Kit becomes the convenience.
5. **Constitution migration log.** Set up `CONSTITUTION-CHANGES.md`
   as the changelog of amendments, keeping each amendment's PR
   number and rationale. Useful once you're three amendments in
   and starting to lose track.

---

## What you should now believe

- **A constitution is not documentation; it's a commitment.** The
  difference is that documentation describes how things are, and a
  constitution describes how things must be. PR review is what
  turns description into commitment.
- **The hierarchy is the product, not the paperwork.** Constitution
  → spec → plan → tasks is a shape that prevents specific failure
  modes — spec drift, undocumented decisions, untraceable changes,
  blind AI usage. Each layer earns its place by foreclosing one of
  those failure modes.
- **AI usage is a first-class article, not an afterthought.**
  Article VIII exists because AI tools are now the most common
  collaborator and the only one whose authorship was previously
  unacknowledged. Naming AI as a co-author and demanding human
  review-before-merge is the discipline that makes AI assistance
  *responsible* rather than *opaque*.
- **CLAUDE.md and CONSTITUTION.md are different files for different
  audiences.** Conflating them is the rookie SDD mistake. Article
  IX is the test that keeps them separate.
- **The audit is the only ritual that matters.** If you only do one
  thing from this lesson, do the audit. Articles you don't
  re-examine quarterly are articles you've stopped enforcing.

---

## Next up — Lesson 7

You've governed the catalog (lesson 5) and the work (lesson 6).
Lesson 7 closes the loop on **operating** the system:

- The deployment / release process for plugins and constitutional
  amendments — how a change moves from "merged to master" to "every
  team member has it on their next session start."
- The observability layer — what to log, what to dashboard, what
  alerts (per-environment, not per-plugin) belong in the
  observability stack vs. ad hoc reports under `reports/`.
- The on-call rotation for plugin breakage — who responds when
  someone's session breaks after a plugin update, what the SLO is,
  what the rollback procedure looks like.
- Cost governance — token-cost budgets per plugin, per skill, per
  user; how the watcher service (lesson 6 audit subject!) gets a
  budget assigned and how overruns are surfaced.

After lesson 7 you'll have the full triangle — author, govern,
operate — for a Claude-Code-augmented engineering org. That's the
end state of the curriculum.
