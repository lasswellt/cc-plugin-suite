---
id: S7-002
title: "6 per-element checks (NO_LABEL, DEAD_HREF, EMPTY_HANDLER, TABINDEX_POSITIVE, TABINDEX_NEGATIVE_VISIBLE, NO_FOCUS_STATE) + R7 settle window"
epic: E-010
capability: CAP-014
status: planned
priority: P0
points: 2
depends_on: [S7-001]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/CHECKS.md
verify:
  - "grep -q 'NO_LABEL' skills/ui-audit/reference.md"
  - "grep -q 'DEAD_HREF' skills/ui-audit/reference.md"
  - "grep -q 'EMPTY_HANDLER' skills/ui-audit/reference.md"
  - "grep -q 'TABINDEX_POSITIVE' skills/ui-audit/reference.md"
  - "grep -q 'TABINDEX_NEGATIVE_VISIBLE' skills/ui-audit/reference.md"
  - "grep -q 'NO_FOCUS_STATE' skills/ui-audit/reference.md"
  - "grep -qE '500 ?ms.*settle|settle.*500 ?ms' skills/ui-audit/reference.md"
done: "Phase INTERACTIVE documents all 6 checks with detection rules + severity + finding format; TABINDEX_MISSING re-checks after a 500ms settle window per R7; findings emit as button_finding registry lines."
---

## Description

Per-element checks translate the enumeration payload into findings. 5 checks run inline on the enumeration JS; NO_FOCUS_STATE runs a second focus-probe `browser_evaluate` pass (requires real focus state). R7 mitigation: frameworks inject tabindex dynamically on mount, so TABINDEX_NEGATIVE_VISIBLE re-runs after 500ms settle before emitting.

## Acceptance Criteria

1. 6 checks documented in `reference.md` Phase INTERACTIVE with detection rule + severity + finding format `page:button_label:CHECK`:
   - `NO_LABEL` (HIGH): `label` null/empty AND element is visible
   - `DEAD_HREF` (MED): `hrefOrOnclick === '#'` or `'javascript:void(0)'`
   - `EMPTY_HANDLER` (MED): native `<button>` or `[role=button]` with no `onclick`, no associated form, no explicit event listener (heuristic: `onclick === ''` attribute)
   - `TABINDEX_POSITIVE` (MED): `tabindex` is integer ≥1
   - `TABINDEX_NEGATIVE_VISIBLE` (MED): `tabindex === '-1'` AND element visible AND not `aria-hidden`. R7: re-check after 500ms settle.
   - `NO_FOCUS_STATE` (HIGH): focus probe: `el.focus(); getComputedStyle(el).outlineWidth === '0px' && boxShadow === 'none' && !el.matches(':focus-visible')`
2. CHECKS.md extended with a new "Interactive-element checks" subsection listing the 6 check names + linking to reference.md Phase INTERACTIVE for detection procedure.
3. Findings written as `label: "button_finding"` JSONL lines with `detail: {issue, element_label, tag, tabindex, selector_snip}`.
4. R7 mitigation: `TABINDEX_MISSING` downgrade to MED with settle-window re-check documented.

## Implementation Notes

- NO_FOCUS_STATE requires per-element `browser_evaluate` (focus state is not static). Budget: up to 10 focus probes per page to cap cost; emit `focus_probe_capped` INFO if >10 elements need probing.
- Settle pattern: `browser_wait_for(time: 0.5)` between enumeration and re-check. Not networkidle — Playwright MCP doesn't have that.
- Severity rationale: NO_LABEL + NO_FOCUS_STATE are WCAG 2.1 AA violations → HIGH. TABINDEX_* and DEAD_HREF are UX degradations → MED.

## Dependencies

S7-001.
