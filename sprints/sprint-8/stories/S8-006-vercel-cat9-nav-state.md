---
id: S8-006
title: "Vercel Category 9 heuristic — URL reflects filter/tab/pagination state"
epic: E-009
capability: CAP-012
status: planned
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/PATTERNS.md
verify:
  - "grep -q 'Category 9' skills/ui-audit/reference.md"
  - "grep -qE 'URL.*state|state.*URL' skills/ui-audit/reference.md"
done: "reference.md Phase 5 § Category 9 documents the heuristic: click a tab / change a filter / navigate pagination, snapshot URL before+after, assert the URL changed (querystring or path). Finding STATE_NOT_IN_URL severity HIGH. PATTERNS.md Category 9 TODO replaced with pointer."
---

## Description

Vercel guideline: stateful UI must be deep-linkable. Click a tab — URL changes. Sort a table — URL reflects the sort. Apply a filter — querystring updates. Fail: reload loses state.

## Acceptance Criteria

1. Phase 5 heuristic runs after Phase INTERACTIVE (so we know what tabs/pagination exist on each page).
2. For each safe-clicked tab / sort header / pagination button:
   - Capture URL before the click
   - Perform click (already done in Phase INTERACTIVE § I.5)
   - Capture URL after 1s settle
   - Assert `before !== after`
3. If URL unchanged → `STATE_NOT_IN_URL` finding severity HIGH. Detail: `{page, element_label, element_type, url_before, url_after}`.
4. Runs only in `heuristics` or `full` modes. Skipped in `consistency`/`data`/`buttons`-only.
5. `PATTERNS.md` Category 9 TODO replaced with cross-reference.

## Implementation Notes

- URL capture via `browser_evaluate: window.location.href`.
- Don't re-click — Phase 5 consumes the click log from Phase INTERACTIVE § I.5 (may require Phase INTERACTIVE to preserve before/after URL in its click findings). If that hook is missing, add it — 3-line addition to the click block.
- Known false positive: apps using React Router / Vue Router with `replaceState` instead of `pushState`. Both still change `window.location.href`, so the heuristic holds.

## Dependencies

None (independent of S8-001..S8-005; Phase 5 ≠ Phase 4).
