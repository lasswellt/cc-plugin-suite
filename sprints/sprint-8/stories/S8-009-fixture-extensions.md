---
id: S8-009
title: "Fixture extensions for quality flags + heuristics"
epic: E-009
capability: CAP-011
status: done
priority: P1
points: 2
depends_on: [S8-005, S8-008]
assigned_agent: test-writer
files:
  - skills/ui-audit/tests/fixture-app.html
  - skills/ui-audit/tests/fixture-ui-audit.json
  - skills/ui-audit/tests/run-fixture.sh
verify:
  - "bash skills/ui-audit/tests/run-fixture.sh"
  - "grep -qE 'STALE_ZERO|BROKEN_TOTAL|FORMAT_MISMATCH' skills/ui-audit/tests/run-fixture.sh"
done: "fixture-app.html gets a new /#/quality section seeding 3 rows + 1 footer total with a deliberate off-by-one + a TBD placeholder + a static '0' on a label whose historical observations in fixture-ui-audit.json include non-zero. run-fixture.sh adds assertions for BROKEN_TOTAL + PLACEHOLDER (configurable pattern TBD) + STALE_ZERO + one FORMAT_MISMATCH simulation."
---

## Description

Seed the fixture with deliberate quality-flag triggers and heuristic-category triggers. Keep the fixture self-contained (no real browser eval needed for shell assertions).

## Acceptance Criteria

1. `fixture-app.html` `/#/quality` section:
   - `<span class="tbd">TBD</span>` to trigger PLACEHOLDER (configured pattern)
   - `<span class="stale-zero">0</span>` paired with fixture seed history ≥3 non-zero observations
   - `<table>` with 3 `<td class="row-total">100</td>` `<td>...</td>` `<td>...</td>` rows + `<td class="footer-total">301</td>` footer (deliberate off-by-one → BROKEN_TOTAL)
2. `fixture-app.html` `/#/heuristic` section:
   - `<table>` with numeric column lacking `tabular-nums` → NUMERIC_COLUMN_NOT_TABULAR
   - `<p>You have three items</p>` → WRITTEN_OUT_COUNT
3. `fixture-ui-audit.json` extended with:
   - `placeholder_patterns: ["TBD", "_REPLACE_"]`
   - `totals: [{id: "T-F1", parent: {page: "/#/quality", key: "footer_total"}, children: [{page: "/#/quality", key: "row_total"}], tolerance: 0}]`
   - Seed history section (new — documented as test-only) that pre-populates fake historical observations into `page-data-registry.jsonl` so STALE_ZERO + FORMAT_MISMATCH have history to compare
4. `run-fixture.sh` adds assertions:
   - PLACEHOLDER finding present for the TBD span
   - STALE_ZERO finding present for stale-zero span
   - BROKEN_TOTAL finding present with `delta: 1` (3×100 vs 301)
   - FORMAT_MISMATCH simulation (synthesize two observations with different format tuples)
5. Script still exits 0 on pass; non-zero with diagnostic on fail.

## Implementation Notes

- Seed history: write 3 fake JSONL lines to a temp registry before running the reducer, then assert findings. Keep real `docs/crawls/` untouched.
- Heuristic fixture rows (Cat 9 / Cat 16) can be inspected statically — run-fixture.sh can grep for `tabular-nums` absence on the numeric column and pattern-match the "three items" copy. Doesn't need a real browser.
- Don't chain heuristic assertions into the numeric/interactive blocks' pass message — add a new `Quality: N findings ← expected` + `Heuristics: N findings ← expected` summary line.

## Dependencies

S8-005 (Phase 4 coordinator — without it, quality findings aren't emitted). S8-008 (Phase 5 coordinator — same for heuristics).
