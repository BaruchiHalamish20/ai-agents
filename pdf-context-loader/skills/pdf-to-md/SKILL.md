---
name: pdf-to-md
description: Convert a PDF to a Markdown sibling file and load the content into the conversation context.
argument-hint: "<pdf-path> [pages]"
arguments: [pdf_path, pages]
allowed-tools: Read, Write, Glob
---

# pdf-to-md — convert a PDF to context-ready Markdown

## How to run

| Invocation                              | pdf_path        | pages   | Effect                                              |
|-----------------------------------------|-----------------|---------|-----------------------------------------------------|
| `/pdf-context-loader:pdf-to-md`         | —               | —       | **Parse error** — pdf_path is required.             |
| `/pdf-context-loader:pdf-to-md a.pdf`   | `a.pdf`         | —       | Convert default page range (Read's first 10 pages). |
| `/pdf-context-loader:pdf-to-md a.pdf 1-5` | `a.pdf`       | `1-5`   | Convert pages 1–5 only.                              |
| `/pdf-context-loader:pdf-to-md a.pdf 3` | `a.pdf`         | `3`     | Convert page 3 only.                                 |

## Argument parsing

1. If `$pdf_path` is empty → abort with `pdf-to-md: pdf_path is required.` and write nothing.
2. If `$pdf_path` doesn't end in `.pdf` (case-insensitive) → abort with `pdf-to-md: expected a .pdf file, got "<value>".` and write nothing.
3. If the file does not exist at `$pdf_path` → abort with `pdf-to-md: file not found at "<value>".` and write nothing.
4. `$pages` is optional. When set, it must match the `Read` tool's `pages` syntax (`"N"`, `"N-M"`). Pass it through unchanged.

## Steps

1. Use the `Read` tool to read `$pdf_path`. If `$pages` is non-empty,
   pass it as the `pages` argument.
2. Convert the page content into clean Markdown:
   - One H1 derived from the document title (first prominent line on
     page 1) or the filename without extension if the title isn't
     obvious.
   - Preserve heading hierarchy (H2/H3) where headings are detectable.
   - Bullet lists and numbered lists preserved.
   - Tables converted to GitHub-flavored Markdown tables when feasible;
     fall back to fenced code blocks if structure is ambiguous.
   - Code blocks preserved with language hints when inferable.
   - Page-break markers as a horizontal rule (`---`) between pages.
3. Determine the output path: strip `.pdf` (case-insensitive) from
   `$pdf_path` and append `.md`. Example: `./docs/paper.pdf` →
   `./docs/paper.md`. If the output file already exists, **overwrite**
   it (this is a conversion utility, not an append).
4. Use the `Write` tool to save the Markdown to that path.
5. Use the `Read` tool to read the freshly written `.md` back. This
   step is what places the content in the conversation context — the
   user can immediately ask follow-up questions about it.
6. End with one summary line in the conversation:
   `✅ Converted <pdf_path> → <md_path> (<N> pages, <M> chars). Content loaded into context.`

## Hard rules

- **No external binaries.** Only the `Read` and `Write` tools. No
  `pdftotext`, no `pandoc`, no Python — the skill must work on any
  machine that runs Claude Code.
- **No mutation of the source PDF.** Convert-only.
- **No write on abort.** Any parse-error or precondition failure must
  return cleanly without creating a partial `.md`.
- **Overwrite is the default.** Re-running on the same PDF replaces
  the previous `.md`; don't append, don't write `paper-2.md`.