#!/usr/bin/env bash
# PreCompact hook — snapshot sprint state before context compaction.
# Prevents the most common sprint-dev failure mode: losing wave/story state
# when auto-compaction fires mid-sprint.

set -euo pipefail

SNAPSHOT_FILE=".cc-sessions/compact-state.json"

# Find any in-progress sprint
SPRINT_NUM=$(cat sprint-registry.json 2>/dev/null \
  | grep -B2 '"in-progress"' | grep '"number"' | grep -o '[0-9]*' | tail -1 || echo "")

if [ -z "$SPRINT_NUM" ]; then
  # No active sprint — nothing to snapshot
  exit 0
fi

SPRINT_DIR="sprints/sprint-${SPRINT_NUM}"
STATE_FILE="${SPRINT_DIR}/STATE.md"

# Build snapshot
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STORIES_DONE=0
STORIES_REMAINING=0

if [ -f "$STATE_FILE" ]; then
  STORIES_DONE=$(grep -c 'done' "$STATE_FILE" 2>/dev/null || echo 0)
  STORIES_REMAINING=$(grep -c 'pending\|in-progress' "$STATE_FILE" 2>/dev/null || echo 0)
fi

cat > "$SNAPSHOT_FILE" <<JSON
{
  "ts": "${TS}",
  "trigger": "pre-compact",
  "sprint": ${SPRINT_NUM},
  "sprint_dir": "${SPRINT_DIR}",
  "state_md_exists": $([ -f "$STATE_FILE" ] && echo true || echo false),
  "stories_done": ${STORIES_DONE},
  "stories_remaining": ${STORIES_REMAINING},
  "carry_forward_active": $(jq -s 'group_by(.id)|map(max_by(.ts))|map(select(.status=="active" or .status=="partial"))|length' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo 0)
}
JSON

echo "[blitz:pre-compact] Sprint ${SPRINT_NUM} state snapshot written to ${SNAPSHOT_FILE}" >&2
exit 0
