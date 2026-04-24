---
id: S8-001
title: "FORMAT_MISMATCH detector — separator/currency drift vs history"
epic: E-009
capability: CAP-011
status: done
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/CHECKS.md
verify:
  - "grep -q 'FORMAT_MISMATCH' skills/ui-audit/reference.md"
  - "grep -qE 'currency_symbol|decimal_sep' skills/ui-audit/reference.md"
done: "reference.md Phase 4 documents a FORMAT_MISMATCH detector that extracts format-shape tuples ({currency_symbol, decimal_sep, thousands_sep}) from each raw observation, computes the historical mode per (role,page,label), and flags the current observation when its tuple diverges. CHECKS.md FORMAT_MISMATCH section gets the TODO replaced with a pointer to the new reference.md section."
---

## Description

Detect when a numeric/currency value changes its rendered format across time — decimal separator flips from `.` to `,`, currency symbol vanishes, thousands separator swaps, etc. Cache invalidation + locale bugs show up here first.

## Acceptance Criteria

1. Detector runs in Phase 4 as a reducer over `page-data-registry.jsonl` latest-2 observations per `(role, page, label)`. Requires ≥2 observations for a `(role, page, label)` with `type ∈ {number, currency}`; skipped otherwise.
2. Format extraction from `raw` string:
   - `currency_symbol`: matches `/^\s*([^\d\s.,-]+)/`; null if numeric-leading
   - `decimal_sep`: last `.` or `,` before end-of-string (heuristic; document limitations)
   - `thousands_sep`: non-terminal grouping char
   - `negative_style`: `null | "leading-minus" | "trailing-minus" | "parens"`
3. Compares latest tuple to the mode of the prior 3+ observations. Divergence → FORMAT_MISMATCH finding severity MED.
4. Configurable tolerance: allow `null` `currency_symbol` (no-symbol observations often legitimate).
5. `CHECKS.md` FORMAT_MISMATCH TODO replaced with cross-reference to `reference.md § Phase 4 § FORMAT_MISMATCH`.

## Implementation Notes

- The existing Phase 4 coordinator is a stub (`<!-- Phase 4 coordinator here. Full body lands in E-009. -->`). This story is the first to replace that stub with a real section; subsequent stories (S8-002, S8-003, S8-005) add neighboring subsections.
- jq-based reducer — don't re-enter the browser. All format extraction runs in bash/node against registry history.
- Format extraction heuristics are imperfect. Document known false-positive cases (e.g., "42" has no separators — skip rather than false-flag).

## Dependencies

None (first story in Phase 4 buildout; independent of the other Phase 4 detectors).
