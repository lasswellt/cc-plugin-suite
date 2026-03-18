#!/usr/bin/env bash
set -uo pipefail

# Post-edit lint hook
# Auto-lints edited files using the project's linter.
# Detects eslint or biome. Outputs remaining lint errors as context.
# Always exits 0.

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only lint supported file types
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|vue)$ ]]; then
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

# Detect linter and run it
detect_and_lint() {
  # Check for ESLint config files
  if [[ -f "$PROJECT_ROOT/.eslintrc" || \
        -f "$PROJECT_ROOT/.eslintrc.js" || \
        -f "$PROJECT_ROOT/.eslintrc.cjs" || \
        -f "$PROJECT_ROOT/.eslintrc.mjs" || \
        -f "$PROJECT_ROOT/.eslintrc.json" || \
        -f "$PROJECT_ROOT/.eslintrc.yaml" || \
        -f "$PROJECT_ROOT/.eslintrc.yml" || \
        -f "$PROJECT_ROOT/eslint.config.js" || \
        -f "$PROJECT_ROOT/eslint.config.cjs" || \
        -f "$PROJECT_ROOT/eslint.config.mjs" || \
        -f "$PROJECT_ROOT/eslint.config.ts" ]]; then
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx eslint --fix "$FILE_PATH" 2>&1) || true
      # Output remaining errors as context for the AI
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi

  # Check for eslint in package.json dependencies
  if [[ -f "$PROJECT_ROOT/package.json" ]] && \
     jq -e '(.devDependencies.eslint // .dependencies.eslint) != null' "$PROJECT_ROOT/package.json" &>/dev/null; then
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx eslint --fix "$FILE_PATH" 2>&1) || true
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi

  # Check for Biome
  if [[ -f "$PROJECT_ROOT/biome.json" || -f "$PROJECT_ROOT/biome.jsonc" ]]; then
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx --yes @biomejs/biome lint --fix "$FILE_PATH" 2>&1) || true
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi
}

detect_and_lint

# Always exit 0 — lint failure should not block edits
exit 0
