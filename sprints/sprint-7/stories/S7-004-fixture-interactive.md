---
id: S7-004
title: "Fixture extension for interactive-element audit (test)"
epic: E-010
capability: CAP-014
status: done
priority: P0
points: 2
depends_on: [S7-003]
assigned_agent: test-writer
files:
  - skills/ui-audit/tests/fixture-app.html
  - skills/ui-audit/tests/run-fixture.sh
verify:
  - "bash skills/ui-audit/tests/run-fixture.sh"
  - "grep -q 'interactive_audit_summary\\|button_finding' skills/ui-audit/tests/run-fixture.sh"
done: "fixture-app.html gains 5+ interactive elements (unlabeled button, dead-href link, positive-tabindex input, destructive-labeled link, normal button); run-fixture.sh simulates the enumeration + classifier, asserts exactly 1 unlabeled + 1 dead-href + 1 tabindex-positive finding, asserts the destructive link is NOT clicked."
---

## Description

Extend the fixture to exercise the interactive-element path. Seed 5 elements with known issues; run-fixture.sh simulates the enumeration and asserts findings match the seeded problems 1:1.

## Acceptance Criteria

1. `fixture-app.html` gains a new `#/interactive` section with exactly these elements:
   - `<button>Click me</button>` — clean (baseline)
   - `<button></button>` — NO_LABEL
   - `<a href="#">dead</a>` — DEAD_HREF
   - `<input type="text" tabindex="5" aria-label="tab">` — TABINDEX_POSITIVE
   - `<a href="/delete/all" class="danger">Delete everything</a>` — destructive (MUST NOT click)
2. `fixture-ui-audit.json` gains the `/#/interactive` page entry with no labels (no data extraction — just enumeration).
3. `run-fixture.sh` gains an enumeration+classifier simulation block:
   - Parses the interactive section's HTML
   - Applies the destructive classifier regex
   - Applies the 4 synchronous checks (NO_LABEL, DEAD_HREF, EMPTY_HANDLER, TABINDEX_POSITIVE)
   - Asserts 1 × NO_LABEL, 1 × DEAD_HREF, 1 × TABINDEX_POSITIVE
   - Asserts the "Delete everything" link was classified `isSafe: false` (the destructive regex caught it)
4. Exit 0 on pass, non-zero on fail. Output one-line summary `[interactive fixture] 3/3 findings + destructive blocked`.

## Implementation Notes

- NO_FOCUS_STATE + CLICK_ERROR cannot be simulated in the shell-only fixture (they require a real browser). Defer those to the Claude-Code-driven e2e path. The shell fixture exercises the 4 static checks.
- The destructive assertion is the key safety test: if the regex stops matching due to a future edit to `DESTRUCTIVE_LABELS`, this test will fail and prevent a data-loss incident.

## Dependencies

S7-003 (classifier) and all prior E-010 stories.
