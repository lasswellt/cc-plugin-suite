---
id: S8-003
title: "BROKEN_TOTAL evaluator — parent/child relationship config + sum check"
epic: E-009
capability: CAP-011
status: planned
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/CHECKS.md
  - .ui-audit.json.example
verify:
  - "grep -q 'BROKEN_TOTAL' skills/ui-audit/reference.md"
  - "grep -q '\"totals\"' .ui-audit.json.example || grep -q 'totals:' skills/ui-audit/reference.md"
done: ".ui-audit.json schema gains a `totals` block declaring parent/children relationships; reference.md Phase 4 documents the sum evaluator (sum(children.parsed) vs parent.parsed with tolerance); .ui-audit.json.example demonstrates one total declaration; CHECKS.md BROKEN_TOTAL TODO replaced with pointer."
---

## Description

Detect when a page footer total doesn't match the sum of its rows. Requires author to declare the relationship (skill can't infer which labels are parent/child). Schema + evaluator + example.

## Acceptance Criteria

1. `.ui-audit.json` schema extended with top-level `totals` array:
   ```json
   "totals": [
     {
       "id": "T-001",
       "description": "Invoice list rows sum to footer total",
       "parent": {"page": "/invoices", "key": "footer_total"},
       "children": [{"page": "/invoices", "key": "row_total"}],
       "tolerance": 0.01
     }
   ]
   ```
   `children[].key` may resolve to multiple observations per page (e.g., if the registry has multiple values for the same label at different selectors); sum them all.
2. Evaluator (Phase 4) reads `totals[]`, for each: resolve parent + children against the reduced registry, compute `sum(children)`, compare to `parent` with tolerance.
3. Violation → BROKEN_TOTAL finding severity HIGH. Detail: `{total_id, parent_value, children_sum, delta, tolerance}`.
4. `.ui-audit.json.example` includes one illustrative `totals` entry with a doc comment.
5. CHECKS.md BROKEN_TOTAL TODO replaced with pointer.

## Implementation Notes

- Unlike FORMAT_MISMATCH and STALE_ZERO (auto-detect without config), this is opt-in. Without a declared `totals` block, the detector is a no-op.
- Tolerance is critical — sub-cent rounding on currency totals is common and not a bug. Default tolerance 0.01 if omitted.
- Extraction of repeat-per-row labels: if `key: "row_total"` has multiple matching selectors on a page (e.g., one per `<tr>`), each row should emit its own registry line with a unique selector. Document this requirement in § E-009 notes — extraction phase may need enhancement to support per-row keys cleanly. If complexity emerges, carve into a follow-up story.

## Dependencies

None directly — but interacts with extraction's single-selector-per-label contract. Document as a known extension point.
