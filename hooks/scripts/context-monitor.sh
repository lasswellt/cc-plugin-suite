#!/usr/bin/env bash
# Context Monitor Hook
# PostToolUse hook for all tool types.
# Tracks approximate context window utilization by counting characters.
# Warns at ~60% and ~80% estimated utilization.

set -euo pipefail

COUNTER_DIR=".cc-sessions"
COUNTER_FILE="${COUNTER_DIR}/context-char-count"

# Ensure directory exists
mkdir -p "${COUNTER_DIR}"

# Approximate context window size in characters
# 200k tokens * ~4 chars/token = ~800k chars
MAX_CHARS=800000
WARN_60=$((MAX_CHARS * 60 / 100))
WARN_80=$((MAX_CHARS * 80 / 100))

# Read current count
if [ -f "${COUNTER_FILE}" ]; then
  TOTAL=$(cat "${COUNTER_FILE}" 2>/dev/null || echo "0")
  if ! [[ "${TOTAL}" =~ ^[0-9]+$ ]]; then
    TOTAL=0
  fi
else
  TOTAL=0
fi

# Estimate characters from this tool call
# Read stdin (hook receives tool output) and count chars
INPUT_CHARS=0
if [ ! -t 0 ]; then
  INPUT_CHARS=$(wc -c < /dev/stdin 2>/dev/null || echo "0")
fi

TOTAL=$((TOTAL + INPUT_CHARS))
echo "${TOTAL}" > "${COUNTER_FILE}"

# Calculate percentage
if [ "${MAX_CHARS}" -gt 0 ]; then
  PCT=$((TOTAL * 100 / MAX_CHARS))
else
  PCT=0
fi

# Warn at thresholds
if [ "${TOTAL}" -ge "${WARN_80}" ]; then
  echo "Context utilization high (~${PCT}%). Complete current task, then consider spawning a fresh agent for remaining work." >&2
elif [ "${TOTAL}" -ge "${WARN_60}" ]; then
  echo "Context utilization ~${PCT}%. Consider summarizing completed work." >&2
fi

exit 0
