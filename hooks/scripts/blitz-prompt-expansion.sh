#!/usr/bin/env bash
# UserPromptExpansion hook — injects activity-feed context into every blitz:* invocation.
# Fires when a /blitz:<skill> slash command expands. Reads last 5 activity-feed lines
# and appends them as context so skills have instant awareness of prior session state
# without requiring Claude to read CLAUDE.md manually.
#
# Hook input (stdin): JSON with command_name, command_args
# Hook output (stdout): JSON with additionalContext field

set -euo pipefail

ACTIVITY_FEED=".cc-sessions/activity-feed.jsonl"

# Read recent activity (last 5 substantive events, skip session_start noise)
RECENT_ACTIVITY=""
if [ -f "$ACTIVITY_FEED" ]; then
  RECENT_ACTIVITY=$(tail -20 "$ACTIVITY_FEED" 2>/dev/null \
    | grep -v '"event":"session_start"' \
    | tail -5 \
    | jq -r '"\(.ts | split("T")[1] | split(".")[0]) [\(.session | split("-")[0:2] | join("-"))] \(.skill)/\(.event): \(.message)"' 2>/dev/null \
    | head -5 \
    || echo "")
fi

if [ -z "$RECENT_ACTIVITY" ]; then
  # No context available — pass through without modification
  exit 0
fi

# Build additionalContext injection — use jq for safe JSON encoding
# (the prior sed/tr/sed sequence mangled backslashes from escaped quotes).
CONTEXT=$(printf 'Recent blitz activity:\n%s' "$RECENT_ACTIVITY")

jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "UserPromptExpansion", additionalContext: $ctx}}'

exit 0
