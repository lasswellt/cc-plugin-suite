---
id: S8-007
title: "Vercel Category 16 heuristic — tabular-nums + numerals for counts"
epic: E-009
capability: CAP-012
status: done
priority: P1
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/PATTERNS.md
verify:
  - "grep -q 'Category 16' skills/ui-audit/reference.md"
  - "grep -qE 'tabular-nums|font-variant-numeric' skills/ui-audit/reference.md"
done: "reference.md Phase 5 § Category 16 documents 2 sub-checks: NUMERIC_COLUMN_NOT_TABULAR (scan table cells that look numeric, check computed font-variant-numeric), WRITTEN_OUT_COUNT (scan text for written-out numbers under 10 in count contexts). PATTERNS.md Category 16 TODO replaced with pointer."
---

## Description

Numeric table columns that don't use tabular-nums shift digit alignment when values change. Headings that say "three items" instead of "3" violate the numerals-for-counts rule. Both are MED-severity polish.

## Acceptance Criteria

1. Phase 5 § Category 16 documents 2 sub-checks:
   - `NUMERIC_COLUMN_NOT_TABULAR` — `browser_evaluate` scans `<table>` columns where ≥70% of cells match `/^-?\d/`. Checks `getComputedStyle(cell).fontVariantNumeric` for `tabular-nums`. Missing → finding severity MED.
   - `WRITTEN_OUT_COUNT` — scans `<h*>`, `<p>`, `<li>` text for patterns like `\b(one|two|three|...|nine)\s+(item|items|result|results|user|users|record|records|row|rows)\b`. Finding severity LOW.
2. Both checks run per-page via 2 `browser_evaluate` payloads.
3. Column detection threshold (70%) is configurable via `.ui-audit.json[heuristics][tabular_column_threshold]`. Default 0.7.
4. `PATTERNS.md` Category 16 TODO replaced with cross-reference.

## Implementation Notes

- WRITTEN_OUT_COUNT false-positive rate is high (idioms, proper nouns). LOW severity by design — surface without gate.
- NUMERIC_COLUMN_NOT_TABULAR cost: one evaluate per page. Cheap.
- Skip these checks on pages with no `<table>` elements (short-circuit via snapshot inspection).

## Dependencies

None.
