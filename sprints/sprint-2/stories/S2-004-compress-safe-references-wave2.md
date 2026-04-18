---
id: S2-004
title: Compress 7 SAFE reference.md files (wave-2)
epic: E-002
capability: CAP-002
registry_id: cf-2026-04-18-compress-safe-references-wave2
status: planned
github_issue: 4
priority: high
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/doc-gen/reference.md
  - skills/perf-profile/reference.md
  - skills/roadmap/reference.md
  - skills/completeness-gate/reference.md
  - skills/bootstrap/reference.md
  - skills/setup/reference.md
  - skills/fix-issue/reference.md
verify:
  - "test $(find skills -path '*/reference.md.original' -newer sprints/sprint-2/manifest.json | wc -l) -ge 7"
  - "bash hooks/scripts/reference-compression-validate.sh"
done: 7 SAFE reference.md files have .original backups; structural validator passes.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Sprint 1 S1-005 compressed 10 SAFE reference.md; 7 SAFE files remain uncompressed (doc-gen, perf-profile, roadmap, completeness-gate, bootstrap, setup, fix-issue). Per `docs/_research/2026-04-18_caveman-full-absorption.md` recommendation §Phase 2, run `/blitz:compress` on each. Expected aggregate saving: 4-9 KB input per load based on S1-005 measured range (0.94% to 12.56% per file).

## Acceptance Criteria

1. `skills/doc-gen/reference.md.original` exists.
2. `skills/perf-profile/reference.md.original` exists.
3. `skills/roadmap/reference.md.original` exists.
4. `skills/completeness-gate/reference.md.original` exists.
5. `skills/bootstrap/reference.md.original` exists.
6. `skills/setup/reference.md.original` exists.
7. `skills/fix-issue/reference.md.original` exists.
8. `bash hooks/scripts/reference-compression-validate.sh` exits 0 — all pairs structurally valid.

## Implementation Notes

Invoke `/blitz:compress` on each target file. The skill handles backup + validation + restore-on-failure automatically. If any file is classified UNSAFE (contains "Agent Prompt Template"), the skill aborts that one target; verify remaining completions are recorded in STATE.md.

Run sequentially or as a batched invocation:

```bash
/blitz:compress skills/doc-gen/reference.md skills/perf-profile/reference.md skills/roadmap/reference.md skills/completeness-gate/reference.md skills/bootstrap/reference.md skills/setup/reference.md skills/fix-issue/reference.md
```

## Dependencies

None. Parallel to E-001 stories.
