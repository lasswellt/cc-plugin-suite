#!/usr/bin/env bash
# PostCompact hook — log compaction stats and restore context hints.
# Reads the snapshot written by pre-compact-snapshot.sh and appends a
# restoration hint to the activity feed so the next turn has context.

set -euo pipefail

SNAPSHOT_FILE=".cc-sessions/compact-state.json"
ACTIVITY_FEED=".cc-sessions/activity-feed.jsonl"

if [ ! -f "$SNAPSHOT_FILE" ]; then
  exit 0
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SPRINT=$(jq -r '.sprint // "unknown"' "$SNAPSHOT_FILE")
DONE=$(jq -r '.stories_done // 0' "$SNAPSHOT_FILE")
REMAINING=$(jq -r '.stories_remaining // 0' "$SNAPSHOT_FILE")
CF=$(jq -r '.carry_forward_active // 0' "$SNAPSHOT_FILE")

# Append restoration hint to activity feed
printf '{"ts":"%s","session":"hook-post-compact","skill":"freeform","event":"decision","message":"Context compacted. Sprint %s: %s stories done, %s remaining, %s CF active. Resume: /blitz:implement --resume","detail":{"sprint":%s,"stories_done":%s,"stories_remaining":%s,"cf_active":%s}}\n' \
  "$TS" "$SPRINT" "$DONE" "$REMAINING" "$CF" \
  "$SPRINT" "$DONE" "$REMAINING" "$CF" \
  >> "$ACTIVITY_FEED" 2>/dev/null || true

echo "[blitz:post-compact] Sprint ${SPRINT}: ${DONE} done, ${REMAINING} remaining. Activity feed updated." >&2
exit 0
