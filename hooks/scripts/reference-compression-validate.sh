#!/usr/bin/env bash
# PreToolUse hook — validates that any compressed references/main.md still preserves
# the structural elements of its sibling references/main.md.original backup.
#
# Dual-mode:
#   - With hook JSON on stdin (PreToolUse/Bash): only fires on `git commit`,
#     exits 2 on drift to block the commit.
#   - Without JSON on stdin (direct invocation / CI / verify): runs checks
#     unconditionally, exits 1 on drift.
#
# Checks (between <file>.original and <file>):
#   1. Count of fenced code-block delimiter lines (``` lines)
#   2. Sorted-unique set of http(s) URLs
#   3. List of heading lines (^#+ )
#   4. Count of table-row lines (^|)

set -uo pipefail

HOOK_MODE=0
EXIT_BLOCK=1

# If stdin is a pipe and contains JSON, run in hook mode.
if [[ ! -t 0 ]]; then
  INPUT="$(cat || true)"
  if [[ -n "$INPUT" ]] && echo "$INPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    HOOK_MODE=1
    EXIT_BLOCK=2
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null || true)
    # Only validate on git commit
    if [[ "$COMMAND" != *"git commit"* ]]; then
      exit 0
    fi
  fi
fi

# Repo root — script lives at hooks/scripts/, so root is two levels up
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAILED=0
CHECKED=0

# Find all compressed pairs (iterates zero times when none exist — exit 0)
while IFS= read -r orig; do
  [[ -z "$orig" ]] && continue
  compressed="${orig%.original}"
  if [[ ! -f "$compressed" ]]; then
    echo "FAIL $orig: sibling $compressed missing"
    FAILED=1
    continue
  fi
  CHECKED=$((CHECKED + 1))

  # 1. Code-fence delimiter parity
  of=$(grep -c '^```' "$orig" || true)
  cf=$(grep -c '^```' "$compressed" || true)
  if [[ "$of" != "$cf" ]]; then
    echo "FAIL $compressed: code-fence count $cf != $of (original)"
    FAILED=1
  fi

  # 2. URL set parity
  url_diff=$(diff <(grep -oE 'https?://[^ )<>"'"'"']+' "$orig"    | sort -u) \
                 <(grep -oE 'https?://[^ )<>"'"'"']+' "$compressed" | sort -u) || true)
  if [[ -n "$url_diff" ]]; then
    echo "FAIL $compressed: URL set drift"
    echo "$url_diff" | sed 's/^/  /'
    FAILED=1
  fi

  # 3. Heading list parity (exact lines must match)
  head_diff=$(diff <(grep -E '^#+ ' "$orig") <(grep -E '^#+ ' "$compressed") || true)
  if [[ -n "$head_diff" ]]; then
    echo "FAIL $compressed: heading drift"
    echo "$head_diff" | sed 's/^/  /'
    FAILED=1
  fi

  # 4. Table-row count parity
  ot=$(grep -c '^|' "$orig" || true)
  ct=$(grep -c '^|' "$compressed" || true)
  if [[ "$ot" != "$ct" ]]; then
    echo "FAIL $compressed: table-row count $ct != $ot (original)"
    FAILED=1
  fi
done < <(find skills -type f -path '*/references/main.md.original' 2>/dev/null)

if [[ "$FAILED" -ne 0 ]]; then
  echo "reference-compression-validate: $FAILED check(s) failed across $CHECKED pair(s)"
  exit "$EXIT_BLOCK"
fi

# Stay silent in hook mode when all good; be chatty when invoked manually.
if [[ "$HOOK_MODE" -eq 0 ]]; then
  echo "reference-compression-validate: OK ($CHECKED pair(s) checked)"
fi
exit 0
