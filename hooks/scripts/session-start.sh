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

# Reset the per-session context-utilization counter so warnings track THIS session.
# (Without this reset, the monotonic counter accumulates across sessions and stays
# above the 80% threshold forever after any long session.)
echo 0 > "$SESSIONS_DIR/context-char-count" 2>/dev/null || true

# Check for stale sessions (active but >4h old). Use a portable epoch parser:
# GNU date first, BSD date fallback, python3 last-ditch. If all fail, skip
# the session — better silent skip than every session reporting "stale".
parse_iso_epoch() {
  local iso="$1"
  date -d "$iso" +%s 2>/dev/null && return 0
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null && return 0
  python3 -c "from datetime import datetime; print(int(datetime.fromisoformat('$iso'.replace('Z', '+00:00')).timestamp()))" 2>/dev/null && return 0
  return 1
}

NOW=$(date +%s)
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
  [ "$STATUS" = "active" ] || continue
  STARTED=$(grep -o '"started"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"started"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
  [ -n "$STARTED" ] || continue
  START_EPOCH=$(parse_iso_epoch "$STARTED") || continue
  AGE=$(( NOW - START_EPOCH ))
  if [ "$AGE" -gt 14400 ]; then
    SID=$(basename "$f" .json)
    echo "[blitz] WARNING: Stale session detected: $SID (started ${AGE}s ago)"
  fi
done

exit 0
