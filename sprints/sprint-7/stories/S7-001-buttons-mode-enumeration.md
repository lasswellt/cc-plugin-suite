---
id: S7-001
title: "Buttons mode routing + Phase INTERACTIVE section + enumeration JS"
epic: E-010
capability: CAP-014
status: done
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/SKILL.md
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'Phase INTERACTIVE' skills/ui-audit/reference.md"
  - "grep -qE \"ROLES.*'button'.*'link'\" skills/ui-audit/reference.md"
  - "grep -q 'interactive_audit_summary' skills/ui-audit/reference.md"
done: "SKILL.md declares 'buttons' mode behavior; reference.md gains Phase INTERACTIVE section with the ARIA-role + native-HTML enumeration browser_evaluate payload from research doc §3.7."
---

## Description

Wire `buttons` mode. Enumerate every interactive element per page (ARIA roles + native HTML) via single `browser_evaluate` call. Zero side effects — the enumeration is the contract; clicking happens in S7-003.

## Acceptance Criteria

1. `SKILL.md` §0.1 `buttons` mode row updated from "Implementation in E-010" to the real behavior: "enumerate all interactive elements on each page, emit findings for labeling/keyboard/focus/handler checks, optionally safe-click (see Phase INTERACTIVE)."
2. `reference.md` gains a new `## Phase INTERACTIVE — Every button / link / tab` section (after Phase 2, before Phase 3) with the enumeration JS verbatim from research doc §3.7 (ARIA roles: button/link/checkbox/radio/tab/menuitem/combobox/listbox/switch/slider/spinbutton + native HTML `button,a[href],input,select,textarea,[tabindex]`).
3. Enumeration payload returns `[{tag, role, label, tabindex, hrefOrOnclick, outerSnip, classes}]` as documented.
4. Per-page enumeration write: one `interactive_audit_summary` JSONL line with aggregate counts `{total, labeled, dead_href, no_handler, tabindex_broken, safe_clicked, click_errors}`. Clicks remain 0 at this story (no click pass until S7-003).

## Implementation Notes

- Research doc section to copy verbatim: `docs/_research/2026-04-23_ui-audit-skill.md` §3.7 first JS block.
- Phase INTERACTIVE runs per-page, same cadence as Phase 2 (one `browser_evaluate` call per page visit in `buttons` / `full` modes). In `data`/`consistency`/`heuristics` modes, skip.
- De-duplicate: the enumeration uses `new Set([...roles, ...native])` — an element matching both ARIA role and native tag appears once.

## Dependencies

None.
