#!/usr/bin/env bash
# Analysis Paralysis Guard
# PostToolUse hook for Read|Glob|Grep
# Warns when 5+ consecutive read-only operations occur without any Write/Edit.
# Counter is reset by post-edit hooks (Write/Edit triggers).

set -euo pipefail

COUNTER_DIR=".cc-sessions"
COUNTER_FILE="${COUNTER_DIR}/analysis-paralysis-counter"

# Ensure directory exists
mkdir -p "${COUNTER_DIR}"

# Read current count (default 0)
if [ -f "${COUNTER_FILE}" ]; then
  COUNT=$(cat "${COUNTER_FILE}" 2>/dev/null || echo "0")
  # Validate it's a number
  if ! [[ "${COUNT}" =~ ^[0-9]+$ ]]; then
    COUNT=0
  fi
else
  COUNT=0
fi

# Determine if this is a read-only tool or a write tool
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

case "${TOOL_NAME}" in
  Write|Edit)
    # Reset counter on write operations
    echo "0" > "${COUNTER_FILE}"
    exit 0
    ;;
  Read|Glob|Grep)
    # Increment counter on read operations
    COUNT=$((COUNT + 1))
    echo "${COUNT}" > "${COUNTER_FILE}"
    ;;
  *)
    # Unknown tool, ignore
    exit 0
    ;;
esac

# Warn at threshold
if [ "${COUNT}" -ge 5 ]; then
  echo "WARNING: ${COUNT} consecutive read-only operations without any edits." >&2
  echo "Consider making a concrete change, or ask the user for guidance if you're unsure how to proceed." >&2
fi

exit 0
