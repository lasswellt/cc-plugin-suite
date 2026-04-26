#!/usr/bin/env bash
# skill-frontmatter-validate.sh — Anthropic-canonical SKILL.md lint.
#
# Usage:
#   skill-frontmatter-validate.sh [skill-path...]
#   skill-frontmatter-validate.sh --all   # scan skills/*/SKILL.md
#
# Exit:
#   0 — all SKILL.md files conform
#   1 — one or more files violate the canonical contract
#
# Checks (each skill must satisfy):
#   1. YAML frontmatter parses
#   2. name: present, ≤64 chars, lowercase + digits + hyphens, no "anthropic"/"claude"
#   3. description: present, non-empty, ≤1024 chars
#   4. model: present (opus|sonnet|haiku) — required when disable-model-invocation is false or absent
#   5. effort: present (low|medium|high)
#   6. allowed-tools: present unless disable-model-invocation: true
#   7. argument-hint: present if SKILL.md body references "$1"/"$@"/positional args
#   8. Body length ≤ 500 lines (excluding frontmatter)
#   9. Canonical OUTPUT STYLE snippet present verbatim
#  10. compatibility: present, ">=" semver pin

set -u
SCRIPT_NAME="$(basename "$0")"
BLITZ_ROOT="${BLITZ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RC=0
SNIPPET_RE='OUTPUT STYLE: (terse-technical|lite|full|ultra) per /_shared/terse-output\.md'

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [skill-path...] | --all
  Validates SKILL.md files against Anthropic-canonical conventions.
  Without arguments, validates skills/*/SKILL.md under \$BLITZ_ROOT (or cwd).
EOF
}

# Resolve target list
TARGETS=()
if [ "$#" -eq 0 ] || [ "${1:-}" = "--all" ]; then
  while IFS= read -r f; do TARGETS+=("$f"); done < <(find "${BLITZ_ROOT}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | sort)
else
  for arg in "$@"; do
    [ "$arg" = "--help" ] && { usage; exit 0; }
    TARGETS+=("$arg")
  done
fi

[ "${#TARGETS[@]}" -eq 0 ] && { echo "[$SCRIPT_NAME] No SKILL.md files found" >&2; exit 1; }

fail() {
  printf '  ✗ %s: %s\n' "$1" "$2" >&2
  RC=1
}

validate_one() {
  local f="$1"
  local rel="${f#$BLITZ_ROOT/}"
  [ ! -f "$f" ] && { fail "$rel" "file not found"; return; }

  # Extract frontmatter (between first two lines starting with ---)
  local fm body
  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$f")
  body=$(awk '/^---$/{c++; next} c>=2{print}' "$f")
  [ -z "$fm" ] && { fail "$rel" "missing YAML frontmatter"; return; }

  # Parse fields
  local name desc model effort allowed dmi argh compat
  name=$(printf '%s\n' "$fm" | awk -F': *' '/^name:/{print $2; exit}' | tr -d '"')
  desc=$(printf '%s\n' "$fm" | awk -F': *' '/^description:/{$1=""; sub(/^ */,""); print; exit}' | sed 's/^"\(.*\)"$/\1/')
  model=$(printf '%s\n' "$fm" | awk -F': *' '/^model:/{print $2; exit}' | tr -d '"')
  effort=$(printf '%s\n' "$fm" | awk -F': *' '/^effort:/{print $2; exit}' | tr -d '"')
  allowed=$(printf '%s\n' "$fm" | awk -F': *' '/^allowed-tools:/{$1=""; sub(/^ */,""); print; exit}')
  dmi=$(printf '%s\n' "$fm" | awk -F': *' '/^disable-model-invocation:/{print $2; exit}' | tr -d '"')
  argh=$(printf '%s\n' "$fm" | awk -F': *' '/^argument-hint:/{$1=""; sub(/^ */,""); print; exit}')
  compat=$(printf '%s\n' "$fm" | awk -F': *' '/^compatibility:/{print $2; exit}' | tr -d '"')

  # 2. name
  [ -z "$name" ] && fail "$rel" "frontmatter missing 'name:'"
  [ "${#name}" -gt 64 ] && fail "$rel" "name '$name' exceeds 64 chars"
  echo "$name" | grep -qE '^[a-z0-9-]+$' || fail "$rel" "name '$name' must be lowercase + digits + hyphens"
  case "$name" in *anthropic*|*claude*) fail "$rel" "name contains reserved word 'anthropic' or 'claude'";; esac

  # 3. description
  [ -z "$desc" ] && fail "$rel" "frontmatter missing 'description:'"
  [ "${#desc}" -gt 1024 ] && fail "$rel" "description length ${#desc} exceeds 1024 chars"

  # 6. allowed-tools (unless disable-model-invocation: true)
  if [ "$dmi" != "true" ]; then
    [ -z "$allowed" ] && fail "$rel" "missing 'allowed-tools:' (required when disable-model-invocation is not true)"
    # 4. model — required when invokable
    [ -z "$model" ] && fail "$rel" "frontmatter missing 'model:' (required when disable-model-invocation is not true)"
    case "$model" in opus|sonnet|haiku|"") ;; *) fail "$rel" "model '$model' must be opus|sonnet|haiku";; esac
  fi

  # 5. effort — required for ALL
  [ -z "$effort" ] && fail "$rel" "frontmatter missing 'effort:'"
  case "$effort" in low|medium|high|"") ;; *) fail "$rel" "effort '$effort' must be low|medium|high";; esac

  # 10. compatibility
  [ -z "$compat" ] && fail "$rel" "frontmatter missing 'compatibility:'"
  echo "$compat" | grep -qE '^>=[0-9]+\.[0-9]+\.[0-9]+$' || fail "$rel" "compatibility '$compat' must be '>=X.Y.Z'"

  # 8. body length
  local body_lines
  body_lines=$(printf '%s\n' "$body" | wc -l)
  [ "$body_lines" -gt 500 ] && fail "$rel" "body is $body_lines lines (cap 500); push overflow to references/"

  # 9. OUTPUT STYLE snippet
  printf '%s\n' "$body" | grep -qE "$SNIPPET_RE" || fail "$rel" "missing canonical OUTPUT STYLE snippet (see /_shared/terse-output.md and /_shared/spawn-protocol.md §7)"
}

for f in "${TARGETS[@]}"; do validate_one "$f"; done

if [ "$RC" -eq 0 ]; then
  echo "[$SCRIPT_NAME] OK: ${#TARGETS[@]} SKILL.md files conform"
else
  echo "[$SCRIPT_NAME] FAIL: violations above" >&2
fi
exit "$RC"
