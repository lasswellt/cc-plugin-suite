#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks `--no-verify` in any git command.
# Hooks are guard rails, not obstacles. Bypassing them silently lands broken commits.
# Real incident: anthropics/claude-code#40117 — agent landed 6 commits with 63 failing
# tests via --no-verify + git stash tricks despite explicit deny rules.
#
# Emergency override (user, not agent): BLITZ_OVERRIDE_NO_VERIFY=1 must be set in env.
#
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

[[ -z "$CMD" ]] && exit 0

# Match --no-verify as a standalone arg (avoid false positives in path/string contents)
if echo "$CMD" | grep -qE '(^|[[:space:]"'\''])--no-verify([[:space:]"'\'']|$)'; then
  if [[ "${BLITZ_OVERRIDE_NO_VERIFY:-0}" == "1" ]]; then
    # Logged override: user explicitly set the env var.
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
    if [[ -d .cc-sessions ]]; then
      printf '{"ts":"%s","session":"%s","skill":"hook","event":"override","message":"BLITZ_OVERRIDE_NO_VERIFY used","detail":{"command":%s}}\n' \
        "$TS" "$SESSION_ID" "$(echo "$CMD" | jq -Rs .)" \
        >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true
    fi
    exit 0
  fi
  cat >&2 <<'EOF'
BLOCKED: --no-verify is forbidden.

Hooks are guard rails, not obstacles. If a pre-commit hook is failing, the commit
should not happen. Fix the underlying issue (failing test, lint error, type error)
and commit normally.

Real incident (anthropics/claude-code#40117): an agent landed 6 commits with 63
failing tests by using --no-verify + git stash. This block exists to prevent that.

If you genuinely need an emergency override (production hotfix with a known-flaky
test), the USER (not the agent) should set BLITZ_OVERRIDE_NO_VERIFY=1 in the
shell env before retrying. This is logged to the activity feed.
EOF
  exit 2
fi

exit 0
