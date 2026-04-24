# AC Coverage — Sprint 8 / E-009

## E-009 / CAP-011 — Data-quality flags

| AC | Description | Story | Covered |
|---|---|---|---|
| 1 | 6 flags implemented: NULL_VALUE, PLACEHOLDER, FORMAT_MISMATCH, STALE_ZERO, BROKEN_TOTAL, NEGATIVE_COUNT | sprint-6 S6-007 (inline: NULL/PLACEHOLDER/NEGATIVE_COUNT) + S8-001 (FORMAT_MISMATCH) + S8-002 (STALE_ZERO) + S8-003 (BROKEN_TOTAL) | Yes |
| 2 | Placeholder regex configurable in .ui-audit.json | S8-004 | Yes |
| 3 | Broken-total parent/child declaration in config | S8-003 | Yes |
| 4 | Findings include page:label:flag format | S8-005 (coordinator ensures format) | Yes |

## E-009 / CAP-012 — UI/UX heuristic audit

| AC | Description | Story | Covered |
|---|---|---|---|
| 1 | Vercel rules source vendored + upstream URL | sprint-6 S6-013 (skeleton) + sprint-7 S7-012 (extension) + S8-006/S8-007 fill | Yes (prior + this) |
| 2 | Category 9 (Nav+State) evaluation | S8-006 | Yes |
| 2b | Category 16 (tabular-nums + numerals) evaluation | S8-007 | Yes |
| 3 | Severity tiering CRITICAL/HIGH/MED/LOW | S8-008 | Yes |
| 4 | Spawned sonnet workers pass model: sonnet explicitly | S8-008 | Yes |
| 5 | Inline execution when page count ≤30; parallel when >30 | S8-008 | Yes |

---

**AC Coverage: 9/9 (100%)**

No waivers. No SPIDR bulk-story triggers (max `files.length` = 3; no horizontal-scope language).

Fixture coverage of both capabilities: S8-009 (test-writer).
