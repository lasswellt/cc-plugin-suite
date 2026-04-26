#!/usr/bin/env bash
# task-completed-validate.sh — Validate task completion against Definition of Done
# Exit code 2 blocks task completion and sends feedback
# Exit code 0 allows task completion
# Non-blocking by default: exits 0

set -euo pipefail

INPUT=$(cat)

# Extract task info
TASK_SUBJECT=$(echo "$INPUT" | grep -o '"subject"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"subject"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
AGENT_TYPE=$(echo "$INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

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

# Skip validation if not in a blitz project
[ -z "$ROOT" ] && exit 0

# Only validate sprint story tasks (format: "S{N}-{NNN}: ..." or "S{N}-G{NNN}: ..." for gap-closure)
if [[ ! "$TASK_SUBJECT" =~ ^S[0-9]+-G?[0-9]+: ]]; then
  exit 0
fi

# Quick check for placeholder patterns in recently modified files
RECENT_FILES=$(git diff --name-only HEAD~1 HEAD -- '*.ts' '*.tsx' '*.vue' '*.js' '*.jsx' 2>/dev/null || true)

PLACEHOLDERS_FOUND=0
for file in $RECENT_FILES; do
  [ -f "$ROOT/$file" ] || continue
  if grep -qE '(TODO:\s*implement|throw new Error.*Not implemented|return \{\}|return \[\]|PLACEHOLDER|STUB)' "$ROOT/$file" 2>/dev/null; then
    PLACEHOLDERS_FOUND=1
    echo "[task-validate] WARNING: Placeholder found in $file"
  fi
done

if [ "$PLACEHOLDERS_FOUND" -eq 1 ]; then
  echo "[task-validate] Task '$TASK_SUBJECT' has placeholder implementations. Please complete them before marking done."
  # Exit 2 to block completion and send feedback
  exit 2
fi

# Log completion to activity feed
FEED="$ROOT/.cc-sessions/activity-feed.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"${AGENT_TYPE:-unknown}\",\"skill\":\"hook\",\"event\":\"task_validated\",\"message\":\"Task completed and validated: $TASK_SUBJECT\",\"detail\":{}}" >> "$FEED" 2>/dev/null || true

exit 0
