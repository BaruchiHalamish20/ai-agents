#!/usr/bin/env bash
# Reads the newest reports/*.md and emits its Summary section as
# additionalContext for Claude to load at session start.
set -euo pipefail

mkdir -p "${CLAUDE_PLUGIN_DATA:-.}"
echo "$(date -Iseconds) inject-latest-alert-summary fired" \
  >> "${CLAUDE_PLUGIN_DATA:-.}/audit.log"

LATEST="$(ls -t reports/*.md 2>/dev/null | head -n1 || true)"
if [[ -z "${LATEST}" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No prior alert reports found under reports/."}}\n'
  exit 0
fi

MTIME="$(date -r "${LATEST}" -Iseconds 2>/dev/null || stat -c '%y' "${LATEST}" 2>/dev/null || echo unknown)"

# Extract the "## Summary" section (between "## Summary" and the next H2).
SUMMARY="$(awk '/^## Summary/{flag=1; next} /^## /{flag=0} flag' "${LATEST}")"

PAYLOAD="A Pikud HaOref alert report was generated at ${MTIME}.
File: ${LATEST}

Summary:
${SUMMARY}

Instructions for Claude:
- When the user asks about current/recent alert state, answer from the summary above.
- Do NOT invoke the /alert-report skill or the pikud-alerts agent unless the user explicitly asks for fresh data, a new time window, or a region filter, or if the timestamp above is older than 6 hours relative to the current Israel local time."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
  "$(printf '%s' "${PAYLOAD}" | jq -Rs '.')"