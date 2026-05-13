#!/usr/bin/env bash
# SessionStart hook for markdown-converter-suite.
#
# Scans converted-pdf-files/ for *.pdf, *.html, *.htm and reports
# how many of them still need to be converted (or re-converted because
# the source is newer than the existing .md output).
#
# Honest scope: this hook reports state only. It does NOT trigger any
# conversion — that would be a behavior side effect on session start,
# which is not what hooks are for. The user remains in control: run
# /convert-to-md when you want the work done.
set -euo pipefail

mkdir -p .claude/hooks
echo "$(date -Iseconds) inject-conversion-queue fired" >> .claude/hooks/.audit.log

SRC_DIR="converted-pdf-files"
DEST_DIR="converted-md-files"

if [[ ! -d "${SRC_DIR}" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No converted-pdf-files/ directory present. Create it and drop PDF/HTML files in to populate the conversion queue."}}\n'
  exit 0
fi

# Enumerate every PDF / HTML / HTM under SRC_DIR (recursive, case-insensitive).
SOURCES="$(find "${SRC_DIR}" -type f \( -iname "*.pdf" -o -iname "*.html" -o -iname "*.htm" \) 2>/dev/null | sort || true)"

if [[ -z "${SOURCES}" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"converted-pdf-files/ is empty (no PDF or HTML files)."}}\n'
  exit 0
fi

# Cross-platform mtime helper — GNU stat first, then BSD stat, then 0 as last resort.
mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

PENDING_LINES=""
PENDING_COUNT=0
UPTODATE_COUNT=0

while IFS= read -r src; do
  rel="${src#${SRC_DIR}/}"
  base="${rel%.*}"
  dest="${DEST_DIR}/${base}.md"

  if [[ ! -f "${dest}" ]]; then
    PENDING_LINES+="  - ${src} → ${dest} (no .md yet)"$'\n'
    PENDING_COUNT=$((PENDING_COUNT + 1))
  else
    src_m=$(mtime "${src}")
    dest_m=$(mtime "${dest}")
    if (( src_m > dest_m )); then
      PENDING_LINES+="  - ${src} → ${dest} (source newer than .md)"$'\n'
      PENDING_COUNT=$((PENDING_COUNT + 1))
    else
      UPTODATE_COUNT=$((UPTODATE_COUNT + 1))
    fi
  fi
done <<< "${SOURCES}"

if (( PENDING_COUNT == 0 )); then
  PAYLOAD="All ${UPTODATE_COUNT} file(s) under converted-pdf-files/ have up-to-date .md conversions in converted-md-files/."
else
  PAYLOAD="Markdown conversion queue: ${PENDING_COUNT} pending, ${UPTODATE_COUNT} up-to-date.

Pending:
${PENDING_LINES}
Instructions for Claude:
- Do NOT run /convert-to-md automatically. The queue is informational.
- If the user asks to process pending files, /convert-to-md with no arguments converts all of them.
- /convert-to-md --list does a dry-run (prints the queue without converting).
- /convert-to-md <glob> [--debug] processes a subset.
- The markdown-converter agent and /convert-to-md skill are part of the markdown-converter-suite plugin."
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
  "$(printf '%s' "${PAYLOAD}" | jq -Rs '.')"
