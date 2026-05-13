#!/usr/bin/env bash
# Block any Bash command that removes files under reports/.
set -euo pipefail

payload="$(cat)"
tool_name="$(echo "$payload"   | jq -r '.tool_name // ""')"
command_str="$(echo "$payload" | jq -r '.tool_input.command // ""')"

[[ "$tool_name" == "Bash" ]] || exit 0

if [[ "$command_str" =~ (^|[[:space:]\;\|\&])(rm|rmdir|unlink)([[:space:]]|$) ]] \
   && [[ "$command_str" =~ (^|[[:space:]/])reports([[:space:]/]|$) ]]; then
  echo "Blocked by pikud-alerts-suite: deletion under reports/ is not permitted." >&2
  exit 2
fi

exit 0
