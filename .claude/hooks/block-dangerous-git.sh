#!/bin/bash
# PreToolUse hook: block dangerous git commands (bash variant, for the Bash tool
# / git-bash). The PowerShell variant (block-dangerous-git.ps1) is the one wired
# into settings.json; this is the portable fallback. Requires `jq`.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

DANGEROUS_PATTERNS=(
  "git push"
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "reset --hard"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. You do not have authority to run this command — the human commits, pushes, and opens the PR for this pack's work." >&2
    exit 2
  fi
done

exit 0
