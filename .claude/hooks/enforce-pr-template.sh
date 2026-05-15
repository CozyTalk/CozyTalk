#!/bin/sh
# PreToolUse hook: blocks gh pr create calls that don't include the PR template.
# Reads tool input JSON from stdin; exits 2 to block, 0 to allow.

input=$(cat)

# Extract the bash command from the JSON tool input using python3.
# python3 is available on all platforms (macOS ships it; Windows devs have it via Node/Flutter toolchains).
cmd=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    pass
" 2>/dev/null <<EOF
$input
EOF
)

# Only act on gh pr create commands.
case "$cmd" in
  *"gh pr create"*)
    ;;
  *)
    exit 0
    ;;
esac

# Allow if the body clearly contains template sections or uses --body-file.
case "$cmd" in
  *"## Summary"*|*"--body-file"*)
    exit 0
    ;;
esac

cat <<'MSG'

BLOCKED — PR body must use .github/pull_request_template.md.

Required steps:
  1. Read the template:  cat .github/pull_request_template.md
  2. Fill EVERY section (use "N/A" where not applicable — do not delete sections)
  3. Pass via heredoc:

     gh pr create --title "your title" --body "$(cat <<'EOF'
     ## Summary
     ...fill in...

     ## Type of Change
     ...etc...
     EOF
     )"

MSG
exit 2
