---
id: S1-001
title: Reference compression validator script
epic: caveman-compress-input-side
status: done
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - hooks/scripts/reference-compression-validate.sh
  - hooks/hooks.json
verify:
  - "test -x hooks/scripts/reference-compression-validate.sh"
  - "bash -n hooks/scripts/reference-compression-validate.sh"
  - "bash hooks/scripts/reference-compression-validate.sh"  # passes when no .original files exist yet
done: "Validator script exists, is executable, passes shellcheck-equivalent (bash -n), and is wired into hooks.json as a pre-commit check."
---

# S1-001 — Reference compression validator script

## Description

Create `hooks/scripts/reference-compression-validate.sh`. For each `reference.md` that has a sibling `reference.md.original`, verify structural preservation: same number of fenced code blocks, same set of URLs, same heading list, same table-row count. Exit non-zero on any drift. Must run before any compressed file is committed.

This is the **prerequisite** for S1-003 — without it, caveman-compress damage is undetectable until a skill misbehaves at runtime.

## Acceptance Criteria

1. Script lives at `hooks/scripts/reference-compression-validate.sh` and is `chmod +x`.
2. For every `reference.md.original` under `skills/`, script diffs against the sibling `reference.md` for:
   - count of lines starting with ` ``` ` (code-fence parity)
   - sorted-unique set of `https?://...` URLs (no URL drift)
   - list of heading lines matching `^#+ ` (heading parity)
   - count of lines starting with `|` (table-row parity)
3. Script prints `FAIL <file>: <reason>` for each drift and exits 1 overall.
4. Script exits 0 cleanly when no `.original` files exist (S1-003 hasn't run yet).
5. Wired into `hooks/hooks.json` as a pre-commit hook.

## Implementation Notes

Reference implementation from research doc (`docs/_research/2026-04-16_caveman-compress-input-side.md`, Implementation Sketch Step 1). Use `set -euo pipefail`. Use `find skills -name 'reference.md.original'` as input list.

Preserve hook registration pattern already used by other entries in `hooks/hooks.json` — read that file first and match the existing style.

## Dependencies

None. This is the first story; S1-002 and S1-003 depend on it.
