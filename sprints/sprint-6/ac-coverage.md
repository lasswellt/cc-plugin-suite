# AC Coverage — Sprint 6 / E-008

| Capability | AC | Story | Covered |
|---|---|---|---|
| CAP-008 | AC1 skills/ui-audit/SKILL.md + reference.md exist with opus+effort:low | S6-001, S6-004 | Yes |
| CAP-008 | AC2 CHECKS.md + PATTERNS.md exist | S6-013 | Yes |
| CAP-008 | AC3 skill-registry.json entry | S6-002 | Yes |
| CAP-008 | AC4 session-protocol.md conflict matrix rows | S6-002 | Yes |
| CAP-008 | AC5 .ui-audit.json.example at repo root with all three invariant blocks | S6-003 | Yes |
| CAP-008 | AC6 Mode routing implemented for 9 declared modes | S6-001 | Yes |
| CAP-008 | AC7 Phase 0 + Phase 1 executable against project with prior browse state | S6-001, S6-006 | Yes |
| CAP-009 | AC1 Extraction phase runs browser_evaluate with user-declared label map | S6-007 | Yes |
| CAP-009 | AC2 One JSONL line per (role, page, label) to page-data-registry.jsonl | S6-007 | Yes |
| CAP-009 | AC3 Each line includes raw, parsed, hash, selector, tick, role | S6-007 | Yes |
| CAP-009 | AC4 browse/reference.md latest-tick.json schema includes page_data_registry field | S6-005 | Yes |
| CAP-009 | AC5 Integration test 3 pages × 2 labels = 6 registry lines | S6-012 | Yes |
| CAP-010 | AC1 jq reducer groups by label, detects cross-page divergence | S6-008 | Yes |
| CAP-010 | AC2 equal/gte/lte invariant checks evaluate correctly | S6-009 | Yes |
| CAP-010 | AC3 Tolerance honored on numeric checks | S6-009 | Yes |
| CAP-010 | AC4 FLAPPING detected after ≥3 ticks of oscillation | S6-010 | Yes |
| CAP-010 | AC5 STALE detected on revert within 2 ticks | S6-010 | Yes |
| CAP-010 | AC6 invariant_fail events to .cc-sessions/activity-feed.jsonl | S6-009 | Yes |
| CAP-010 | AC7 Test: seeded registry with known divergence produces expected findings | S6-012 | Yes |
| CAP-013 | AC1 docs/crawls/ui-audit-report.md written on every run | S6-011 | Yes |
| CAP-013 | AC2 Findings grouped by severity tier | S6-011 | Yes |
| CAP-013 | AC3 Stdout summary with counts + top 3 invariant failures | S6-011 | Yes |
| CAP-013 | AC4 skill_complete event to activity-feed with detail block | S6-011 | Yes |

**AC Coverage: 23/23 (100%)**

No gaps. No waivers needed. SPIDR bulk-story guard: no story matches any trigger regex; max `files.length` is 3 (S6-012 fixture); all within the ≤8 threshold.
