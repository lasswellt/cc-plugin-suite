# Sprint 8 — ui-audit Quality Flags + UI/UX Heuristics

**Date:** 2026-04-23
**Epics:** E-009 (data-quality flags + UI/UX heuristics)
**Capabilities:** CAP-011, CAP-012
**Stories:** 9 (8 backend-dev + 1 test-writer)
**Planner mode:** `research-reuse` — no new research agents spawned (research doc §§ 3.4, 3.6 + CHECKS.md/PATTERNS.md skeletons cover all implementation detail)

## Story map

```
CAP-011 data-quality (5):
  S8-001 FORMAT_MISMATCH detector (separator/currency drift)
  S8-002 STALE_ZERO detector (current 0 vs history non-zero)
  S8-003 BROKEN_TOTAL evaluator (parent/child sum check + config)
  S8-004 placeholder_patterns config extension
  S8-005 Phase 4 coordinator (aggregate inline + reducer flags)

CAP-012 heuristics (3):
  S8-006 Vercel Category 9 (URL reflects state)
  S8-007 Vercel Category 16 (tabular-nums + numerals for counts)
  S8-008 Phase 5 coordinator (severity tiers + parallel sonnet spawn)

Fixtures (1):
  S8-009 quality + heuristics fixture extensions
```

## Wave plan

```
Wave 0 (parallel, no deps): S8-001, S8-002, S8-003, S8-004, S8-006, S8-007
Wave 1 (parallel): S8-005 (CAP-011 coord, waits on S8-001/002/003) + S8-008 (CAP-012 coord, waits on S8-006/007)
Wave 2: S8-009 (waits on S8-005 + S8-008)
```

3 waves. Critical path: S8-003 → S8-005 → S8-009 (or S8-007 → S8-008 → S8-009).

## Story count by agent

| Agent | Stories |
|---|---|
| backend-dev | 8 (all phase-procedure edits in reference.md) |
| test-writer | 1 (S8-009 fixture extension) |
| frontend-dev | 0 |
| infra-dev | 0 |

## Risk notes

- **R-sprint-8.1 — same-file contention on reference.md.** 8 of 9 stories edit reference.md. Sequential in-session execution (sprint-6 + sprint-7 pattern) again.
- **R-sprint-8.2 — BROKEN_TOTAL repeat-per-row labels.** The current extraction contract is one `selector` per `label`. Rows in a table that each need a `row_total` observation don't fit cleanly. S8-003 documents this as a known extension point; if the fixture in S8-009 surfaces the gap, carve into a follow-up story in sprint-9.
- **R-sprint-8.3 — Phase 5 sonnet spawn is the skill's first Agent() use.** S8-008 will be the first `Agent` tool invocation from inside ui-audit. `model: "sonnet"` MUST be explicit (research doc §6.1 + saved memory). Sprint-review Invariant 5 covers `OUTPUT STYLE` in the spawn prompt — note that expectation in S8-008.

## Carry-forward

None.
