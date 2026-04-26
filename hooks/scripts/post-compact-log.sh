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
# Coerce snapshot fields to JSON-valid types (numeric or null). Prior version
# embedded raw "unknown" string into a numeric position, producing invalid JSON.
SPRINT_JSON=$(jq 'if (.sprint | type) == "number" then .sprint else null end' "$SNAPSHOT_FILE" 2>/dev/null || echo "null")
DONE_JSON=$(jq '.stories_done // 0 | tonumber? // 0' "$SNAPSHOT_FILE" 2>/dev/null || echo "0")
REM_JSON=$(jq '.stories_remaining // 0 | tonumber? // 0' "$SNAPSHOT_FILE" 2>/dev/null || echo "0")
CF_JSON=$(jq '.carry_forward_active // 0 | tonumber? // 0' "$SNAPSHOT_FILE" 2>/dev/null || echo "0")

# Build line via jq for safe JSON encoding.
jq -nc \
  --arg ts "$TS" \
  --argjson sprint "$SPRINT_JSON" \
  --argjson done "$DONE_JSON" \
  --argjson rem "$REM_JSON" \
  --argjson cf "$CF_JSON" \
  '{
    ts: $ts,
    session: "hook-post-compact",
    skill: "freeform",
    event: "decision",
    message: ("Context compacted. Sprint \($sprint // "unknown"): \($done) stories done, \($rem) remaining, \($cf) CF active. Resume: /blitz:implement --resume"),
    detail: {sprint: $sprint, stories_done: $done, stories_remaining: $rem, cf_active: $cf}
  }' >> "$ACTIVITY_FEED" 2>/dev/null || true

echo "[blitz:post-compact] Sprint ${SPRINT_JSON}: ${DONE_JSON} done, ${REM_JSON} remaining. Activity feed updated." >&2
exit 0
