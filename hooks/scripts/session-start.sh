#!/usr/bin/env bash
# session-start.sh — Initialize session context on SessionStart hook
# Displays recent activity feed and checks for stale sessions
# Non-blocking: always exits 0

set -euo pipefail

# Find project root
DIR="$(pwd)"
ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/.claude-plugin" ]; then
    ROOT="$DIR"
    break
  fi
  DIR="$(dirname "$DIR")"
done
[ -z "$ROOT" ] && ROOT="$(pwd)"

SESSIONS_DIR="$ROOT/.cc-sessions"

# Ensure .cc-sessions exists
mkdir -p "$SESSIONS_DIR"

# Display recent activity (last 10 entries)
FEED="$SESSIONS_DIR/activity-feed.jsonl"
if [ -f "$FEED" ] && [ -s "$FEED" ]; then
  LINES=$(tail -10 "$FEED" 2>/dev/null || true)
  if [ -n "$LINES" ]; then
    echo "[blitz] Recent activity:"
    echo "$LINES" | while IFS= read -r line; do
      SESSION=$(echo "$line" | grep -o '"session":"[^"]*"' | head -1 | sed 's/"session":"//;s/"$//' || true)
      MSG=$(echo "$line" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//' || true)
      SKILL=$(echo "$line" | grep -o '"skill":"[^"]*"' | head -1 | sed 's/"skill":"//;s/"$//' || true)
      [ -n "$MSG" ] && echo "  [$SESSION] $SKILL: $MSG"
    done
  fi
fi

# Check for stale sessions (active but last_activity > 30 min ago)
NOW=$(date +%s)
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
  if [ "$STATUS" = "active" ]; then
    STARTED=$(grep -o '"started"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"started"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
    if [ -n "$STARTED" ]; then
      START_EPOCH=$(date -d "$STARTED" +%s 2>/dev/null || echo "0")
      AGE=$(( NOW - START_EPOCH ))
      if [ "$AGE" -gt 14400 ]; then
        SID=$(basename "$f" .json)
        echo "[blitz] WARNING: Stale session detected: $SID (started ${AGE}s ago)"
      fi
    fi
  fi
done

exit 0
