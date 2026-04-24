---
id: S8-002
title: "STALE_ZERO detector — current parsed=0 but history non-zero"
epic: E-009
capability: CAP-011
status: planned
priority: P0
points: 1
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/CHECKS.md
verify:
  - "grep -q 'STALE_ZERO' skills/ui-audit/reference.md"
  - "grep -qE 'max.*history.*parsed|parsed.*history' skills/ui-audit/reference.md"
done: "reference.md Phase 4 documents a STALE_ZERO detector that flags a (role,page,label) whose current parsed is 0 AND max(history.parsed) > 0. CHECKS.md STALE_ZERO TODO replaced with pointer."
---

## Description

A value that was non-zero and is now zero usually means a silent fetch failure: the API returned empty, the cache expired to a default, or a null coalesced to 0. Cheap reducer, high signal.

## Acceptance Criteria

1. Detector runs in Phase 4 over `page-data-registry.jsonl` per `(role, page, label)` with `type ∈ {number, count, currency}`. Text labels skipped.
2. Rule: `current.parsed === 0 && max(history.parsed) > 0` (history = prior 5 observations).
3. Requires ≥3 observations (else insufficient history — skip silently).
4. Finding severity MED. Detail: `{target_label, current_tick, last_non_zero_tick, last_non_zero_value}`.
5. `CHECKS.md` STALE_ZERO TODO replaced with cross-reference.

## Implementation Notes

- jq one-liner shape:
  ```bash
  jq -s '
    [.[] | select(.label != null and (.parsed | type) == "number")]
    | group_by([.role, .page, .label])
    | map({key: {role:.[0].role, page:.[0].page, label:.[0].label},
           hist: (sort_by(.ts) | .[-5:])})
    | map(. as $g | select(($g.hist | length) >= 3)
                  | select($g.hist[-1].parsed == 0)
                  | select(($g.hist[0:-1] | map(.parsed) | max) > 0))
  '
  ```
- Low-cost — runs in the same Phase 4 sweep as S8-001.

## Dependencies

None.
