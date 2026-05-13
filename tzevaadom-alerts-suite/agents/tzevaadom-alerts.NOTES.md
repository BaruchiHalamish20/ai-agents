# tzevaadom-alerts — local overrides log

This file is **not** loaded by Claude Code as an agent (filename does not
match `<name>.md`). It exists to document temporary, hand-applied edits
to `tzevaadom-alerts-suite/agents/tzevaadom-alerts.md` so that:

1. A reviewer reading the agent file knows where to look for any active
   overrides (a one-line HTML pointer at the top of the agent body links
   here).
2. Anyone can determine *what was changed*, *where*, *why*, and
   *when to revert* — without running `git diff`.

Each override gets its own dated entry. Mark the status checkboxes as
you move through the lifecycle.

---

## How to add a new override entry

Copy the template below to the top of the dated-entries section.

```markdown
## YYYY-MM-DD — <one-line title>

- **Target file:** `tzevaadom-alerts-suite/agents/tzevaadom-alerts.md`
- **Section:** <name of the H2/H3 section in the agent body>
- **Approximate line:** <N> (search for `<unique substring>`)

**Before:**
\```
<paste exact original block>
\```

**After:**
\```
<paste exact replacement block>
\```

- **Why:** <one or two sentences>
- **Expected behaviour after override:** <bullet points>
- **Revert:** <exact restore instructions>
- **Status:**
  - [ ] applied
  - [ ] tested
  - [ ] reverted
```

---

*(No active overrides yet. First entry will go here once an override is
applied.)*
