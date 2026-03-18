#!/usr/bin/env bash
set -euo pipefail

# Pre-edit guard hook
# Blocks edits to protected files.
# Reads JSON from stdin with tool_input.file_path.
# Exit 0 = allow, Exit 2 = block.

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  # No file path found — allow (might be a non-file operation)
  exit 0
fi

# Get just the filename for pattern matching
FILENAME=$(basename "$FILE_PATH")

# --- Protected file patterns ---

# Block .env files (except .env.development and .env.example)
if [[ "$FILENAME" =~ ^\.env ]]; then
  if [[ "$FILENAME" == ".env.development" || "$FILENAME" == ".env.example" ]]; then
    exit 0
  fi
  echo "BLOCKED: Editing $FILENAME is not allowed. Only .env.development and .env.example may be edited." >&2
  exit 2
fi

# Block lock files
if [[ "$FILENAME" == "package-lock.json" || \
      "$FILENAME" == "pnpm-lock.yaml" || \
      "$FILENAME" == "yarn.lock" || \
      "$FILENAME" == "bun.lockb" || \
      "$FILENAME" == "composer.lock" || \
      "$FILENAME" == "Gemfile.lock" || \
      "$FILENAME" == "poetry.lock" ]]; then
  echo "BLOCKED: Editing lock file $FILENAME is not allowed. Use the package manager to update dependencies." >&2
  exit 2
fi

# Block secret/key files
if [[ "$FILENAME" =~ \.(pem|key|p12|pfx|keystore|jks)$ || \
      "$FILENAME" == "credentials.json" || \
      "$FILENAME" == "service-account.json" || \
      "$FILENAME" =~ ^.*serviceAccount.*\.json$ || \
      "$FILENAME" =~ ^.*secret.*\.json$ ]]; then
  echo "BLOCKED: Editing secret/key file $FILENAME is not allowed." >&2
  exit 2
fi

# Block git internals
if [[ "$FILE_PATH" == *"/.git/"* || "$FILE_PATH" == ".git/"* ]]; then
  echo "BLOCKED: Editing git internal files is not allowed." >&2
  exit 2
fi

# Block node_modules
if [[ "$FILE_PATH" == *"/node_modules/"* || "$FILE_PATH" == "node_modules/"* ]]; then
  echo "BLOCKED: Editing files inside node_modules is not allowed." >&2
  exit 2
fi

# All checks passed — allow the edit
exit 0
