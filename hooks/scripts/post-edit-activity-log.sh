#!/usr/bin/env bash
# post-edit-activity-log.sh — Append file change events to the activity feed
# Fires after every Write|Edit tool use to maintain cross-instance awareness
# Non-blocking: always exits 0

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Skip if no file path detected
[ -z "$FILE_PATH" ] && exit 0

# Find project root (walk up looking for .claude-plugin/)
DIR="$(cd "$(dirname "$FILE_PATH" 2>/dev/null || echo ".")" && pwd)"
ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/.claude-plugin" ]; then
    ROOT="$DIR"
    break
  fi
  DIR="$(dirname "$DIR")"
done

# Fall back to current directory
[ -z "$ROOT" ] && ROOT="$(pwd)"

# Ensure .cc-sessions exists
SESSIONS_DIR="$ROOT/.cc-sessions"
mkdir -p "$SESSIONS_DIR"

# Generate a session ID from hook input if available, otherwise from agent_id or fallback
HOOK_SESSION=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
HOOK_AGENT=$(echo "$INPUT" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"agent_id"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
if [ -n "$HOOK_SESSION" ]; then
  SESSION_ID="$HOOK_SESSION"
elif [ -n "$HOOK_AGENT" ]; then
  SESSION_ID="$HOOK_AGENT"
else
  # Fallback: use a hash of the current timestamp minute for rough grouping
  SESSION_ID="cli-$(date +%Y%m%d%H%M | md5sum 2>/dev/null | cut -c1-8 || echo "unknown")"
fi

# Make file path relative to project root
REL_PATH="${FILE_PATH#$ROOT/}"

# Extract agent_type for attribution (if present in hook input)
HOOK_AGENT_TYPE=$(echo "$INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

# Append to activity feed with agent attribution
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
if [ -n "$HOOK_AGENT_TYPE" ]; then
  echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"freeform\",\"event\":\"file_change\",\"message\":\"Edited $REL_PATH\",\"detail\":{\"files\":[\"$REL_PATH\"],\"agent_type\":\"$HOOK_AGENT_TYPE\"}}" >> "$SESSIONS_DIR/activity-feed.jsonl"
else
  echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"freeform\",\"event\":\"file_change\",\"message\":\"Edited $REL_PATH\",\"detail\":{\"files\":[\"$REL_PATH\"]}}" >> "$SESSIONS_DIR/activity-feed.jsonl"
fi

exit 0
