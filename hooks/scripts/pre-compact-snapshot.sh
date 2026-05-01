#!/usr/bin/env bash
# PreCompact hook — snapshot sprint state AND write HANDOFF.json for cross-compaction
# auto-resume. Inspired by GSD's PreCompact→HANDOFF→SessionStart auto-resume loop.
#
# Two artifacts written:
#   .cc-sessions/compact-state.json — sprint-specific snapshot (legacy)
#   .cc-sessions/HANDOFF.json       — generic resume artifact for any in-flight work
#
# session-start.sh consumes HANDOFF.json on next session boot.

set -euo pipefail

mkdir -p .cc-sessions
SNAPSHOT_FILE=".cc-sessions/compact-state.json"
HANDOFF_FILE=".cc-sessions/HANDOFF.json"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# --- Find any in-progress sprint (legacy snapshot) ---
SPRINT_NUM=$(cat sprint-registry.json 2>/dev/null \
  | grep -B2 '"in-progress"' | grep '"number"' | grep -o '[0-9]*' | tail -1 || echo "")

if [ -n "$SPRINT_NUM" ]; then
  SPRINT_DIR="sprints/sprint-${SPRINT_NUM}"
  STATE_FILE="${SPRINT_DIR}/STATE.md"
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
fi

# --- HANDOFF.json — generic resume artifact (always written) ---
# Captures everything needed to pick up after compaction without the user
# re-explaining context.
SPRINT_FIELD="null"
[ -n "$SPRINT_NUM" ] && SPRINT_FIELD="\"sprint-${SPRINT_NUM}\""

PHASE="$(jq -r '.phase // "unknown"' ".cc-sessions/${SESSION_ID}-workflow.json" 2>/dev/null || echo "unknown")"
LAST_ACTIVITY="$(tail -1 .cc-sessions/activity-feed.jsonl 2>/dev/null | jq -r '.message // ""' 2>/dev/null || echo "")"

UNCOMMITTED_JSON="$(git status --porcelain 2>/dev/null | jq -R . | jq -sc . 2>/dev/null || echo '[]')"
BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Recent file changes (last 5 from activity feed)
RECENT_FILES="$(tail -50 .cc-sessions/activity-feed.jsonl 2>/dev/null \
  | jq -sc '[.[] | select(.event=="file_change") | .detail.files // []] | flatten | unique | .[0:10]' 2>/dev/null \
  || echo '[]')"

cat > "$HANDOFF_FILE" <<JSON
{
  "ts": "${TS}",
  "session": "${SESSION_ID}",
  "trigger": "pre-compact",
  "sprint": ${SPRINT_FIELD},
  "phase": "${PHASE}",
  "branch": "${BRANCH}",
  "head_sha": "${HEAD_SHA}",
  "uncommitted": ${UNCOMMITTED_JSON},
  "recent_files": ${RECENT_FILES},
  "last_activity": $(jq -Rs . <<< "$LAST_ACTIVITY"),
  "resume_hint": "Compaction fired. Read HANDOFF.json + last 30 activity-feed lines, restate the in-flight task in ≤3 sentences, then continue from the next dispatch."
}
JSON

echo "[blitz:pre-compact] HANDOFF written to ${HANDOFF_FILE}" >&2

# Append handoff event to activity feed
printf '{"ts":"%s","session":"%s","skill":"hook","event":"handoff_written","message":"PreCompact handoff captured","detail":{"phase":"%s","sprint":%s}}\n' \
  "$TS" "$SESSION_ID" "$PHASE" "$SPRINT_FIELD" \
  >> .cc-sessions/activity-feed.jsonl 2>/dev/null || true

exit 0
