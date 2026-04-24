# AC Coverage — Sprint 7 / E-010 + E-011 + E-012

## E-010 / CAP-014 — Interactive element coverage

| AC | Description | Story | Covered |
|---|---|---|---|
| 1 | browser_evaluate enumeration payload | S7-001 | Yes |
| 2 | 6 per-element checks | S7-002 | Yes |
| 3 | Destructive-click classifier (safe-click gating) | S7-003 | Yes |
| 4 | TABINDEX_MISSING 500ms settle (R7 mitigation) | S7-002 | Yes |
| 5 | Per-page interactive_audit_summary registry line | S7-001 (+S7-003 counts) | Yes |

## E-011 / CAP-015 — Analytics event consistency

| AC | Description | Story | Covered |
|---|---|---|---|
| 1 | dataLayer proxy + sendBeacon wrap injected after navigate | S7-005 | Yes |
| 2 | Network-level filter (Segment/PostHog/Amplitude/GA4) | S7-005 | Yes |
| 3 | Event log drained + registry lines written | S7-006 | Yes |
| 4 | Cross-page drift detection (jq) | S7-007 | Yes |
| 5 | event_invariants required/forbidden/scope | S7-007 | Yes |
| 6 | EVENTS_BEFORE_SPY flag (R8 mitigation) | S7-005 | Yes |

## E-012 / CAP-016 — Per-permissions-role matrix

| AC | Description | Story | Covered |
|---|---|---|---|
| 1 | 5 roles via env vars, skip-if-absent | S7-009 | Yes |
| 2 | Scripted login + storageState harvest | S7-010 | Yes |
| 3 | Sentinel check after role switch (R9) | S7-010 | Yes |
| 4 | Registry role field (__default__ preserved) | sprint-6 S6-007 (pre-existing) | Yes (prior) |
| 5 | role_invariants: equal, viewer_null, gte | S7-011 | Yes |
| 6 | Role-leak scan with configurable patterns | S7-012 | Yes |
| 7 | latest-tick.json ui_audit_matrix extension | S7-013 | Yes |
| 8 | ETA warning + --yes/--ci gating (R10) | S7-013 (+partial S7-009) | Yes |

---

**AC Coverage: 19/19 (100%)**

No waivers. No SPIDR bulk-story triggers (all stories ≤3 files, no horizontal-scope language).

**Pre-existing coverage** on CAP-016 AC4 (registry `role` field + `__default__` default) was shipped in sprint-6 S6-007. The E-012 stories consume that existing field; no re-implementation needed. Sprint-review will see this AC as covered via the prior-sprint story reference.
