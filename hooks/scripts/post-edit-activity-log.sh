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

# Generate a stable session ID from PID hierarchy (reused across the conversation)
SESSION_ID="cli-$(echo "$$-$PPID" | md5sum 2>/dev/null | cut -c1-8 || echo "unknown")"

# Make file path relative to project root
REL_PATH="${FILE_PATH#$ROOT/}"

# Append to activity feed
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$SESSION_ID\",\"skill\":\"freeform\",\"event\":\"file_change\",\"message\":\"Edited $REL_PATH\",\"detail\":{\"files\":[\"$REL_PATH\"]}}" >> "$SESSIONS_DIR/activity-feed.jsonl"

exit 0
