---
id: S7-011
title: "role_invariants evaluator (equal / viewer_null / gte) + activity-feed events"
epic: E-012
capability: CAP-016
status: planned
priority: P0
points: 2
depends_on: [S7-010]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -qE 'role_invariants' skills/ui-audit/reference.md"
  - "grep -qE 'viewer_null' skills/ui-audit/reference.md"
  - "grep -q 'role_invariant_fail' skills/ui-audit/reference.md"
done: "Phase ROLE documents role_invariants evaluator schema + 3 checks (equal/viewer_null/gte) + activity-feed role_invariant_fail/pass events; integrates with existing registry role field."
---

## Description

Cross-role invariants. Read `.ui-audit.json.role_invariants[]`, pull observations by (role, page, key) from the reduced registry (registry already has `role` field per sprint-6), evaluate, emit pass/fail.

## Acceptance Criteria

1. Schema documented (matches research doc §3.9):
   ```json
   {"id":"ROLE-001","description":"<what>","sources":[{"role":"admin","page":"/users","key":"user_count"},...],"check":"equal|viewer_null|gte"}
   ```
2. Check semantics:
   - `equal`: all sources' `parsed` values identical (same as Phase 3 invariants; tolerance default 0)
   - `viewer_null`: first source (admin-tier) non-null AND every non-first source (viewer-tier) is null. Asserts privilege boundary.
   - `gte`: first source `parsed` ≥ every other source within tolerance
3. Evaluator jq script lives in reference.md (similar shape to Phase 3 invariant evaluator from sprint-6 S6-009 — reuse `lookup($src; $r)` idiom with the corrected `$src` variable binding).
4. Findings → `role_invariant_fail` with severity HIGH; PASS → `role_invariant_pass` verbose. `viewer_null` violations are particularly severe — if admin value is PRESENT and viewer value is ALSO present when it shouldn't be, severity escalates to CRITICAL (privilege boundary leak).
5. Integrates with existing reducer (the role-aware reducer from sprint-6 already groups by `[role, page, label]` — no reducer changes needed).

## Implementation Notes

- The `lookup` function in sprint-6 was `def lookup($src; $r)` with `$src` binding to prevent re-evaluation. Copy-paste that fix — don't re-introduce the filter-arg bug.
- `viewer_null` is an asymmetric check — first source MUST be non-null. If the admin observation itself is null, that's a different finding (`ADMIN_OBS_MISSING`) — don't conflate with a passing viewer_null.

## Dependencies

S7-010 (needs role-switched registry to exist).
