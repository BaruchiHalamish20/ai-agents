# SKILL.md — section template

A reference for the recurring structure of `SKILL.md` files in this repo.
Use it as a starting skeleton when authoring a new skill, then drop sections
you don't need.

---

## 1. YAML front matter (required)

```yaml
---
name: skill-name
description: One short sentence — what the skill does. Shown in the skill picker.
when_to_use: |
  Trigger conditions. When should Claude invoke this skill vs. ignore it?
  Phrase as observable user intent, not internal mechanics.
---
```

The three fields above are what Claude reads to decide whether to invoke the
skill. Keep `description` tight; put nuance in `when_to_use`.

---

## 2. Body sections (in roughly this order)

### `## How to run`
Invocation shape. The slash-command form, what gets executed (agent, script,
inline Claude), and the canonical example calls.

### `## Argument parsing`
How to interpret arguments — positional vs flags, defaults, validation, what
to do on bad input. One subsection or bullet per argument.

### `## Required binary` *(only if applicable)*
External binaries the skill depends on (e.g. `pandoc`, `libreoffice`). Where
to find them, how to detect them, what to do if missing.

### `## Data sources` *(only if applicable)*
External APIs / endpoints the skill calls. List them in the order they should
be tried (primary → fallback).

### `## Window math` / `## Filtering` *(domain-specific)*
Transforms applied to inputs before the main work — time-window math,
region/city filters, normalization rules.

### `## Building the queue` / `## Steps`
The ordered work the skill performs. Numbered steps preferred when order
matters.

### `## <mode> mode` *(one per mode flag)*
One section per behavioral mode — e.g. `## List mode (--list)`,
`## Convert mode (default)`, `## Debug mode (--debug)`. Describes inputs,
outputs, and side-effects of that mode specifically.

### `## Debug instrumentation` *(only if `--debug` exists)*
What extra output `--debug` emits, where it goes, format.

### `## Output contract` **(non-negotiable section)**
Exactly where files are written, naming convention (timestamp format, suffix
rules), directory structure guarantees, what gets returned to the user. This
is the part the rest of the system depends on.

### `## Report structure` *(when emitting a structured document)*
The literal template for the artifact, with subsections matching the
artifact's headings:

- `## Summary`
- `## Active alerts` *(or equivalent primary section)*
- `## Recent activity`
- `## Sources`
- `## Notes`
- `## Debug log` *(when `--debug`)*

### `## Language rules` *(when output has locale/format constraints)*
Bilingual rules, code-fence style, date/time formatting, capitalization, etc.

### `## After writing`
Post-write steps — print the output path, summarize to the user, update an
index, trigger a follow-up.

### `## Hard rules` *(always last)*
The non-negotiables. What the skill must never do, must always do, must never
assume. Short bulleted list. Usually 3–8 items.

---

## 3. Minimum viable spine

If you strip everything optional, every skill in this repo still has:

1. `How to run`
2. `Argument parsing`
3. (domain steps — `Steps` or `Building the queue` or `Data sources`)
4. `Output contract`
5. `Hard rules`

Add modes, debug, report structure, and language rules only when the skill
actually has them.

---

## 4. Authoring checklist

- [ ] Front matter `name` matches the directory name.
- [ ] `description` fits on one line.
- [ ] `when_to_use` lists at least one positive trigger and one anti-trigger.
- [ ] Every CLI flag mentioned in `How to run` has a matching `## <mode>` section.
- [ ] `Output contract` specifies the exact path pattern (no placeholders left).
- [ ] `Hard rules` includes "never write outside the declared output directory".
- [ ] If the skill calls an external API, `Data sources` lists fallbacks.
- [ ] If the skill depends on a timestamp, the caller-provided format is stated explicitly.
