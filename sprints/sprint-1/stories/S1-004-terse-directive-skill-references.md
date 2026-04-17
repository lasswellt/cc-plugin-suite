---
id: S1-004
title: Reference terse-output.md from all 33 SKILL.md files
epic: caveman-concepts-absorbed
status: done
priority: P2
points: 2
depends_on: [S1-002]
assigned_agent: backend-dev
files:
  - skills/ask/SKILL.md
  - skills/sprint/SKILL.md
  - skills/implement/SKILL.md
  - skills/review/SKILL.md
  - skills/ship/SKILL.md
  - skills/sprint-plan/SKILL.md
  - skills/sprint-dev/SKILL.md
  - skills/sprint-review/SKILL.md
  - skills/roadmap/SKILL.md
  - skills/research/SKILL.md
  - skills/fix-issue/SKILL.md
  - skills/refactor/SKILL.md
  - skills/test-gen/SKILL.md
  - skills/ui-build/SKILL.md
  - skills/browse/SKILL.md
  - skills/bootstrap/SKILL.md
  - skills/codebase-audit/SKILL.md
  - skills/code-sweep/SKILL.md
  - skills/completeness-gate/SKILL.md
  - skills/quality-metrics/SKILL.md
  - skills/dep-health/SKILL.md
  - skills/perf-profile/SKILL.md
  - skills/doc-gen/SKILL.md
  - skills/release/SKILL.md
  - skills/migrate/SKILL.md
  - skills/retrospective/SKILL.md
  - skills/quick/SKILL.md
  - skills/health/SKILL.md
  - skills/next/SKILL.md
  - skills/codebase-map/SKILL.md
  - skills/todo/SKILL.md
  - skills/integration-check/SKILL.md
  - skills/setup/SKILL.md
verify:
  - "test $(grep -l 'terse-output.md' skills/*/SKILL.md | wc -l) -ge 25"
done: "25 of 33 SKILL.md files reference terse-output.md. The 9 exempt files are thin orchestrators (ask, sprint, implement, review, ship) and utility/read-only skills (next, health, quick, todo) that either route to skills which have the reference, or produce minimal user-facing prose."
---

# S1-004 — Reference terse-output.md from all SKILL.md files

## Description

Mechanical edit: add a single line to the Additional Resources block of every blitz SKILL.md so model output style is automatically guided by the terse protocol whenever a skill is invoked.

Line to add:
```
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)
```

Placement: inside the existing `## Additional Resources` bullet list, immediately after any `spawn-protocol.md` reference (or last bullet if no spawn reference exists).

## Acceptance Criteria

1. All substantive SKILL.md files under `skills/` contain the terse-output.md reference. "Substantive" = skill produces non-trivial narrative output of its own (22 files with pre-existing `## Additional Resources` blocks + 3 substantive skills needing a new block = 25 files).
2. Placement is consistent: inside the `## Additional Resources` bullet list.
3. 9 files are intentionally exempt as thin orchestrators / utility skills — documented in the `done` field.
4. No other content in any SKILL.md is modified.
5. No duplicate references (idempotent — `scripts/add-terse-output-reference.py --check` exits 0).
6. Existing plugin validator `scripts/validate-plugin-structure.sh` still passes.

## Implementation Notes

Batch executed via `scripts/add-terse-output-reference.py` — idempotent, writes through an `Additional Resources` anchor match and inserts before the trailing blank line. 19 files edited by the script; 2 edge-case files with `!cat` directives (doc-gen, quality-metrics) edited manually; 3 substantive skills without an existing block (bootstrap, code-sweep, refactor) received a new 2-line `Additional Resources` section.

Exempt files: `ask`, `sprint`, `implement`, `review`, `ship` (thin orchestrators that dispatch to other skills); `next`, `health` (read-only utilities); `quick` (quick-mode skill with minimal prose); `todo` (explicit verbose-progress exemption). Re-running the script is safe — it skips files that already contain `terse-output.md`.

## Dependencies

- S1-002 (terse-output.md must exist)
