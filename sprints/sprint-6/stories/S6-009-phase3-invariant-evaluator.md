---
id: S6-009
title: "Phase 3 INVARIANTS — equal/gte/lte evaluator with tolerance + activity-feed events"
epic: E-008
capability: CAP-010
status: done
priority: P0
points: 2
depends_on: [S6-004, S6-008]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -qE 'check.*equal' skills/ui-audit/reference.md"
  - "grep -qE 'check.*gte' skills/ui-audit/reference.md"
  - "grep -qE 'check.*lte' skills/ui-audit/reference.md"
  - "grep -q 'tolerance' skills/ui-audit/reference.md"
  - "grep -q 'invariant_fail' skills/ui-audit/reference.md"
done: "Invariant evaluator handles equal/gte/lte checks with numeric tolerance; writes invariant_fail events to .cc-sessions/activity-feed.jsonl; integrates with S6-008 divergence suppression."
---

## Description

Read `.ui-audit.json.invariants`. For each invariant, fetch the latest `parsed` values for each declared (page, key) source from the reduced registry. Evaluate check + tolerance. Emit pass/fail.

## Acceptance Criteria

1. Checks implemented: `equal` (all sources within tolerance of each other), `gte` (first source ≥ every other source within tolerance), `lte` (first source ≤ every other). Invariant schema per `.ui-audit.json.example` (S6-003).
2. Tolerance honored: `|a-b| ≤ tolerance` passes `equal`. Default tolerance `0` when unspecified.
3. On FAIL: emit finding `INV-<id>:FAIL` with per-source values + delta; write `invariant_fail` event to `.cc-sessions/activity-feed.jsonl` with full detail.
4. On PASS: silent (no finding) but log `invariant_pass` to activity feed at verbose level.
5. Divergence suppression: divergences from S6-008 are suppressed when a matching invariant with tolerance ≥ delta covers them. Suppression logged.
6. Unit-testable: given a fixture registry and `.ui-audit.json`, the evaluator produces deterministic output.

## Implementation Notes

- Invariant evaluation is a jq script over the reduced registry:
  ```bash
  jq --slurpfile cfg .ui-audit.json --slurpfile reg ${SESSION_TMP_DIR}/reduced.json '
    $cfg[0].invariants
    | map({
        id,
        values: (.sources | map({page, key, parsed: ($reg[0] | ...)})),
        check, tolerance: (.tolerance // 0)
      })
    | map(. + { passed: (...) })
  '
  ```
  Full jq in reference.md.
- Activity-feed event format per `skills/_shared/verbose-progress.md`.

## Dependencies

S6-004 (skeleton), S6-008 (reducer).
