#!/usr/bin/env bash
# PreToolUse hook — creates backup before file edits
# Always exits 0 (non-blocking)
set -euo pipefail

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || true)

# Skip if no file path or file doesn't exist (new file creation)
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Compute a relative path for the backup directory structure
RELATIVE_PATH="${FILE_PATH#/}"

# Create backup directory mirroring the original path structure
BACKUP_DIR="/tmp/cc-backups/$(dirname "$RELATIVE_PATH")"
mkdir -p "$BACKUP_DIR"

# Copy with timestamp suffix
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp "$FILE_PATH" "/tmp/cc-backups/${RELATIVE_PATH}.${TIMESTAMP}"

# Rotate: keep at most 10 backups per file, delete oldest
BACKUP_BASE="/tmp/cc-backups/${RELATIVE_PATH}"
BACKUP_COUNT=$(ls -1 "${BACKUP_BASE}".* 2>/dev/null | wc -l || echo 0)
if [[ "$BACKUP_COUNT" -gt 10 ]]; then
  DELETE_COUNT=$((BACKUP_COUNT - 10))
  ls -1t "${BACKUP_BASE}".* 2>/dev/null | tail -n "$DELETE_COUNT" | xargs rm -f
fi

exit 0
