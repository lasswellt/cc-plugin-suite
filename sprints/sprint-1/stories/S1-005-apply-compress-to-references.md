---
id: S1-005
title: Apply /blitz:compress to 12 SAFE reference.md files
epic: caveman-concepts-absorbed
status: planned
priority: P2
points: 3
depends_on: [S1-001, S1-003]
assigned_agent: backend-dev
files:
  - skills/browse/reference.md
  - skills/browse/reference.md.original
  - skills/sprint-review/reference.md
  - skills/sprint-review/reference.md.original
  - skills/test-gen/reference.md
  - skills/test-gen/reference.md.original
  - skills/ui-build/reference.md
  - skills/ui-build/reference.md.original
  - skills/refactor/reference.md
  - skills/refactor/reference.md.original
  - skills/research/reference.md
  - skills/research/reference.md.original
  - skills/retrospective/reference.md
  - skills/retrospective/reference.md.original
  - skills/release/reference.md
  - skills/release/reference.md.original
  - skills/dep-health/reference.md
  - skills/dep-health/reference.md.original
  - skills/quality-metrics/reference.md
  - skills/quality-metrics/reference.md.original
  - skills/migrate/reference.md
  - skills/migrate/reference.md.original
  - skills/codebase-map/reference.md
  - skills/codebase-map/reference.md.original
verify:
  - "test $(find skills -name 'reference.md.original' | wc -l) -eq 12"
  - "bash hooks/scripts/reference-compression-validate.sh"
done: "12 .original backups exist; validator passes; aggregate prose-line reduction ≥15% across the 12 files; no .original exists for any of the 7 UNSAFE/RISKY skills."
---

# S1-005 — Apply /blitz:compress to 12 SAFE reference.md files

## Description

Invoke the newly-built `/blitz:compress` skill (S1-003) on each of the 12 SAFE reference.md files identified in the research. For each, the skill writes a `.original` backup, rewrites the source in-place to terse form, and runs the validator. Commit compressed file + backup together per file.

## Acceptance Criteria

1. Exactly 12 `reference.md.original` backups exist (one per SAFE skill).
2. `hooks/scripts/reference-compression-validate.sh` exits 0 against the full set.
3. No `.original` file exists for any UNSAFE/RISKY skill (code-sweep, completeness-gate, sprint-dev, sprint-plan, codebase-audit, integration-check, doc-gen, roadmap, bootstrap, setup, fix-issue).
4. Each compressed `reference.md` has strictly fewer lines than its `.original` sibling.
5. Aggregate reduction across the 12 files is ≥15% (~25% target).
6. Spot-check: 2 randomly-selected files read side-by-side with their originals — no semantic drift.

## Implementation Notes

For each SAFE skill, invoke:
```
/blitz:compress skills/<skill>/reference.md
```

Order of application doesn't matter; per-file failures don't block the batch. If `/blitz:compress` refuses any file due to UNSAFE-marker detection (2.3), document the refusal and move on — that skill gets reclassified, not force-compressed.

After all 12 runs:
- `bash hooks/scripts/reference-compression-validate.sh` — expect exit 0
- Commit: `git add skills/*/reference.md*` and commit

## Dependencies

- S1-001 (validator wired into hooks, runs in Phase 3 of the compress skill)
- S1-003 (`/blitz:compress` skill exists and is registered)

## Risks

- UNSAFE-marker logic is heuristic. If it refuses a SAFE file incorrectly, manually review and override by removing the trigger phrase or using `output_style: exact` frontmatter only where appropriate. Document each refusal.
- If ≥3 of the 12 files fail validation, investigate whether `/blitz:compress` preservation rules need tightening before scaling further.
