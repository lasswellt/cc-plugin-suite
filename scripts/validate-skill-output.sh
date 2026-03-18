#!/usr/bin/env bash
set -euo pipefail

# Validate skill output files by type
# Usage: validate-skill-output.sh --type code|docs|config|stories|report --files <file1> [file2...]
# Exit 0 = pass, Exit 1 = fail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_error()   { echo -e "${RED}ERROR${NC}: $*" >&2; }
print_warning() { echo -e "${YELLOW}WARN${NC}: $*" >&2; }
print_pass()    { echo -e "${GREEN}PASS${NC}: $*"; }

usage() {
  echo "Usage: $0 --type code|docs|config|stories|report --files <file1> [file2...]" >&2
  exit 1
}

TYPE=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --files) shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do FILES+=("$1"); shift; done ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$TYPE" || ${#FILES[@]} -eq 0 ]]; then
  usage
fi

TOTAL_FILES=0
TOTAL_VIOLATIONS=0
FAILED_FILES=0

# --- Code validation: 9 banned patterns ---
validate_code() {
  local file="$1"
  local violations=0

  local patterns=(
    'return \{\}'
    'return \[\]'
    'return null'
    "throw new Error\('Not implemented'\)"
    "throw new Error\('TODO'\)"
    '//\s*TODO:\s*implement'
    '//\s*FIXME'
    '//\s*PLACEHOLDER'
    '//\s*STUB'
    'console\.log'
  )
  local labels=(
    "return {} placeholder"
    "return [] placeholder"
    "return null placeholder"
    "throw Not implemented"
    "throw TODO"
    "TODO: implement comment"
    "FIXME comment"
    "PLACEHOLDER comment"
    "STUB comment"
    "console.log left behind"
  )

  for i in "${!patterns[@]}"; do
    local matches
    matches=$(grep -nE "${patterns[$i]}" "$file" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        local lineno="${line%%:*}"
        print_error "$file:$lineno: ${labels[$i]}"
        violations=$((violations + 1))
      done <<< "$matches"
    fi
  done

  # Empty function bodies: opening brace followed by optional whitespace/comments then closing brace
  local empty_fn
  empty_fn=$(grep -nP '^\s*\{[\s]*\}' "$file" 2>/dev/null || true)
  if [[ -n "$empty_fn" ]]; then
    while IFS= read -r line; do
      local lineno="${line%%:*}"
      print_error "$file:$lineno: empty function body"
      violations=$((violations + 1))
    done <<< "$empty_fn"
  fi

  # Empty catch blocks: catch(...) { }
  local empty_catch
  empty_catch=$(grep -nP 'catch\s*\([^)]*\)\s*\{\s*\}' "$file" 2>/dev/null || true)
  if [[ -n "$empty_catch" ]]; then
    while IFS= read -r line; do
      local lineno="${line%%:*}"
      print_error "$file:$lineno: empty catch block"
      violations=$((violations + 1))
    done <<< "$empty_catch"
  fi

  # Event handlers that are no-ops: () => {}
  local noop_handlers
  noop_handlers=$(grep -nP '\(\)\s*=>\s*\{\s*\}' "$file" 2>/dev/null || true)
  if [[ -n "$noop_handlers" ]]; then
    while IFS= read -r line; do
      local lineno="${line%%:*}"
      print_error "$file:$lineno: no-op event handler () => {}"
      violations=$((violations + 1))
    done <<< "$noop_handlers"
  fi

  # Store actions returning hardcoded data (heuristic: return followed by literal array/object on same line)
  local hardcoded
  hardcoded=$(grep -nP 'return\s+\[.*[''"].+[''"].*\]' "$file" 2>/dev/null || true)
  if [[ -n "$hardcoded" ]]; then
    while IFS= read -r line; do
      local lineno="${line%%:*}"
      print_error "$file:$lineno: possible hardcoded data in return"
      violations=$((violations + 1))
    done <<< "$hardcoded"
  fi

  # Functions that only log and return (heuristic: console.log followed by return on next-ish lines)
  local log_return
  log_return=$(grep -nP 'console\.(log|warn|error)\(' "$file" 2>/dev/null || true)
  # Already counted console.log above, skip double-counting here

  echo "$violations"
}

# --- Docs validation ---
validate_docs() {
  local file="$1"
  local violations=0

  # Check headings exist
  if ! grep -qP '^#' "$file" 2>/dev/null; then
    print_error "$file: no headings found (expected lines starting with #)"
    violations=$((violations + 1))
  fi

  # Check for empty sections (heading immediately followed by another heading)
  local empty_sections
  empty_sections=$(grep -nP '^#{1,6}\s' "$file" 2>/dev/null | while IFS= read -r line; do
    lineno="${line%%:*}"
    next=$((lineno + 1))
    next_line=$(sed -n "${next}p" "$file" 2>/dev/null || true)
    if [[ "$next_line" =~ ^#+ ]]; then
      echo "$lineno"
    fi
  done || true)
  if [[ -n "$empty_sections" ]]; then
    while IFS= read -r lineno; do
      print_warning "$file:$lineno: empty section (heading immediately followed by heading)"
      violations=$((violations + 1))
    done <<< "$empty_sections"
  fi

  # Minimum 100 characters
  local char_count
  char_count=$(wc -c < "$file")
  if [[ "$char_count" -lt 100 ]]; then
    print_error "$file: too short ($char_count chars, minimum 100)"
    violations=$((violations + 1))
  fi

  echo "$violations"
}

# --- Config validation ---
validate_config() {
  local file="$1"
  local violations=0

  if [[ "$file" =~ \.json$ ]]; then
    if ! python3 -m json.tool "$file" > /dev/null 2>&1; then
      print_error "$file: invalid JSON"
      violations=$((violations + 1))
    fi
  elif [[ "$file" =~ \.(yaml|yml)$ ]]; then
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
      print_error "$file: invalid YAML"
      violations=$((violations + 1))
    fi
  else
    print_warning "$file: unsupported config format (expected .json, .yaml, or .yml)"
  fi

  echo "$violations"
}

# --- Stories validation ---
validate_stories() {
  local file="$1"
  local violations=0

  # Check for frontmatter
  local first_line
  first_line=$(head -1 "$file")
  if [[ "$first_line" != "---" ]]; then
    print_error "$file: missing frontmatter (file must start with ---)"
    violations=$((violations + 1))
    echo "$violations"
    return
  fi

  # Extract frontmatter content (between first and second ---)
  local frontmatter
  frontmatter=$(sed -n '2,/^---$/p' "$file" | head -n -1)

  for field in title status points; do
    if ! echo "$frontmatter" | grep -qP "^${field}:" 2>/dev/null; then
      print_error "$file: missing required frontmatter field: $field"
      violations=$((violations + 1))
    fi
  done

  echo "$violations"
}

# --- Report validation ---
validate_report() {
  local file="$1"
  local violations=0

  # Check for ## Summary section
  if ! grep -qP '^## Summary' "$file" 2>/dev/null; then
    print_error "$file: missing '## Summary' section"
    violations=$((violations + 1))
  fi

  # Minimum 200 characters
  local char_count
  char_count=$(wc -c < "$file")
  if [[ "$char_count" -lt 200 ]]; then
    print_error "$file: too short ($char_count chars, minimum 200)"
    violations=$((violations + 1))
  fi

  echo "$violations"
}

# --- Main loop ---
for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    print_error "$file: file not found"
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
    FAILED_FILES=$((FAILED_FILES + 1))
    TOTAL_FILES=$((TOTAL_FILES + 1))
    continue
  fi

  TOTAL_FILES=$((TOTAL_FILES + 1))
  file_violations=0

  case "$TYPE" in
    code)    file_violations=$(validate_code "$file") ;;
    docs)    file_violations=$(validate_docs "$file") ;;
    config)  file_violations=$(validate_config "$file") ;;
    stories) file_violations=$(validate_stories "$file") ;;
    report)  file_violations=$(validate_report "$file") ;;
    *)       print_error "Unknown type: $TYPE"; usage ;;
  esac

  if [[ "$file_violations" -gt 0 ]]; then
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + file_violations))
    FAILED_FILES=$((FAILED_FILES + 1))
  fi
done

echo ""
if [[ "$TOTAL_VIOLATIONS" -eq 0 ]]; then
  print_pass "$TOTAL_FILES files validated, 0 violations"
  exit 0
else
  print_error "FAIL: $TOTAL_VIOLATIONS violations found in $FAILED_FILES files"
  exit 1
fi
