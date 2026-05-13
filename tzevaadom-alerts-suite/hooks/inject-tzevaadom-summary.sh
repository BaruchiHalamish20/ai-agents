#!/usr/bin/env bash
# Reads the newest reports/tzevaadom/*.md and emits its Summary section
# as additionalContext for Claude to load at session start.
#
# This hook is TzevaAdom-only — it deliberately does not look at the
# top-level reports/*.md files (those belong to pikud-alerts-suite).
# Two independent hooks, two independent context injections.
set -euo pipefail

mkdir -p .claude/hooks
echo "$(date -Iseconds) inject-tzevaadom-summary fired" >> .claude/hooks/.audit.log

LATEST="$(ls -t reports/tzevaadom/*.md 2>/dev/null | head -n1 || true)"
if [[ -z "${LATEST}" ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"No prior TzevaAdom alert reports found under reports/tzevaadom/."}}\n'
  exit 0
fi

MTIME="$(date -r "${LATEST}" -Iseconds 2>/dev/null || stat -c '%y' "${LATEST}" 2>/dev/null || echo unknown)"

# Extract the "## Summary" section (between "## Summary" and the next H2).
SUMMARY="$(awk '/^## Summary/{flag=1; next} /^## /{flag=0} flag' "${LATEST}")"

PAYLOAD="A TzevaAdom alert report was generated at ${MTIME}.
File: ${LATEST}

Summary:
${SUMMARY}

Instructions for Claude:
- When the user asks about current/recent TzevaAdom alert state, answer from the summary above.
- Do NOT invoke the /tzevaadom-report skill or the tzevaadom-alerts agent unless the user explicitly asks for fresh data, a new time window, or a city filter, or if the timestamp above is older than 6 hours relative to the current Israel local time.
- This summary is from the TzevaAdom community source. The Pikud HaOref official source is handled by a separate plugin and a separate report."

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
  "$(printf '%s' "${PAYLOAD}" | jq -Rs '.')"
