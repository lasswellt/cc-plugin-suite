#!/usr/bin/env bash
# Workflow Guard Hook
# PreToolUse hook for Bash.
# Tracks phase execution order for phased skills and warns on out-of-order execution.
# Reads phase tracking from .cc-sessions/<session>-workflow.json.

set -euo pipefail

SESSIONS_DIR=".cc-sessions"

# Only operate if a session is active
if [ ! -d "${SESSIONS_DIR}" ]; then
  exit 0
fi

# Find the most recent active session
ACTIVE_SESSION=""
for f in "${SESSIONS_DIR}"/*.json; do
  [ -f "$f" ] || continue
  # Skip non-session files (workflow files, profile, etc.)
  case "$(basename "$f")" in
    *-workflow.json|developer-profile.json|context-*.json) continue ;;
  esac
  if grep -q '"status": "active"' "$f" 2>/dev/null; then
    ACTIVE_SESSION="$f"
  fi
done

# No active session — nothing to guard
if [ -z "${ACTIVE_SESSION}" ]; then
  exit 0
fi

# Extract session ID from filename
SESSION_ID=$(basename "${ACTIVE_SESSION}" .json)
WORKFLOW_FILE="${SESSIONS_DIR}/${SESSION_ID}-workflow.json"

# If no workflow tracking file exists, this session doesn't use phased workflows
if [ ! -f "${WORKFLOW_FILE}" ]; then
  exit 0
fi

# Read current phase from workflow file
CURRENT_PHASE=$(python3 -c "
import json, sys
try:
    data = json.load(open('${WORKFLOW_FILE}'))
    print(data.get('current_phase', -1))
except:
    print(-1)
" 2>/dev/null)

LAST_PHASE=$(python3 -c "
import json, sys
try:
    data = json.load(open('${WORKFLOW_FILE}'))
    print(data.get('last_completed_phase', -1))
except:
    print(-1)
" 2>/dev/null)

# Validate: current phase should be >= last completed phase
if [ "${CURRENT_PHASE}" != "-1" ] && [ "${LAST_PHASE}" != "-1" ]; then
  if [ "${CURRENT_PHASE}" -lt "${LAST_PHASE}" ]; then
    echo "WARNING: Phase ${CURRENT_PHASE} is being executed, but Phase ${LAST_PHASE} was already completed." >&2
    echo "This may indicate an out-of-order phase execution. Check the skill workflow." >&2
  fi
fi

exit 0
