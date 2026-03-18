#!/usr/bin/env bash
set -uo pipefail

# Post-edit format hook
# Auto-formats edited files using the project's formatter.
# Detects prettier or biome. Always exits 0.

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only format supported file types
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|vue|css|scss|json|md|html|yaml|yml)$ ]]; then
  exit 0
fi

# Check that the file actually exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Find the project root by walking up from the file looking for package.json
find_project_root() {
  local dir
  dir=$(dirname "$FILE_PATH")
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root) || exit 0

# Detect formatter and run it
detect_and_format() {
  # Check for Prettier
  if [[ -f "$PROJECT_ROOT/.prettierrc" || \
        -f "$PROJECT_ROOT/.prettierrc.js" || \
        -f "$PROJECT_ROOT/.prettierrc.cjs" || \
        -f "$PROJECT_ROOT/.prettierrc.mjs" || \
        -f "$PROJECT_ROOT/.prettierrc.json" || \
        -f "$PROJECT_ROOT/.prettierrc.yaml" || \
        -f "$PROJECT_ROOT/.prettierrc.yml" || \
        -f "$PROJECT_ROOT/.prettierrc.toml" || \
        -f "$PROJECT_ROOT/prettier.config.js" || \
        -f "$PROJECT_ROOT/prettier.config.cjs" || \
        -f "$PROJECT_ROOT/prettier.config.mjs" ]]; then
    # Prettier config file found
    if command -v npx &>/dev/null; then
      npx --yes prettier --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi

  # Check for prettier in package.json dependencies
  if [[ -f "$PROJECT_ROOT/package.json" ]] && \
     jq -e '(.devDependencies.prettier // .dependencies.prettier) != null' "$PROJECT_ROOT/package.json" &>/dev/null; then
    if command -v npx &>/dev/null; then
      npx prettier --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi

  # Check for Biome
  if [[ -f "$PROJECT_ROOT/biome.json" || -f "$PROJECT_ROOT/biome.jsonc" ]]; then
    if command -v npx &>/dev/null; then
      npx --yes @biomejs/biome format --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi
}

detect_and_format

# Always exit 0 — formatting failure should not block edits
exit 0
