#!/usr/bin/env bash
# teammate-idle.sh — Handle TeammateIdle hook event
# Exit code 2 sends feedback to the teammate and keeps them working
# Exit code 0 allows the teammate to go idle
# Non-blocking: defaults to exit 0 (allow idle)

set -euo pipefail

INPUT=$(cat)

# Extract agent info from hook input
AGENT_ID=$(echo "$INPUT" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"agent_id"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
AGENT_TYPE=$(echo "$INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

# Log to activity feed if in a blitz project
DIR="$(pwd)"
ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/.claude-plugin" ]; then
    ROOT="$DIR"
    break
  fi
  DIR="$(dirname "$DIR")"
done

if [ -n "$ROOT" ] && [ -n "$AGENT_ID" ]; then
  FEED="$ROOT/.cc-sessions/activity-feed.jsonl"
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"ts\":\"$TS\",\"session\":\"$AGENT_ID\",\"skill\":\"hook\",\"event\":\"teammate_idle\",\"message\":\"Agent $AGENT_ID ($AGENT_TYPE) went idle\",\"detail\":{\"agent_type\":\"$AGENT_TYPE\"}}" >> "$FEED" 2>/dev/null || true
fi

# Allow idle by default
exit 0
