---
id: S7-003
title: "Safe-click classifier + click execution + click-error capture"
epic: E-010
capability: CAP-014
status: done
priority: P0
points: 2
depends_on: [S7-002]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -qE 'DESTRUCTIVE_LABELS|DESTRUCTIVE_HREF' skills/ui-audit/reference.md"
  - "grep -q 'isSafe' skills/ui-audit/reference.md"
  - "grep -q 'browser_click' skills/ui-audit/reference.md"
  - "grep -q 'safe_clicked' skills/ui-audit/reference.md"
done: "Phase INTERACTIVE documents the destructive-label classifier regex, safe-click gating procedure, and post-click error capture (console errors + network failures attributed to that click)."
---

## Description

After enumeration + checks, execute `browser_click` on elements classified safe. Capture any console error or network 4xx/5xx that fires within 1s of the click as a `CLICK_ERROR` finding attributed to that element.

## Acceptance Criteria

1. Phase INTERACTIVE includes the destructive classifier (research doc §3.7):
   ```js
   const DESTRUCTIVE_LABELS = /delete|remove|logout|sign.?out|cancel|submit|pay|confirm|save|update|apply|publish|send|subscribe/i;
   const DESTRUCTIVE_HREF   = /\/logout|\/delete|\/remove|\/signout/i;
   const isSafe = !DESTRUCTIVE_LABELS.test(label ?? '') && !DESTRUCTIVE_HREF.test(hrefOrOnclick ?? '');
   ```
   Destructive verb list MUST match SKILL.md Safety Rule 1 (updated in sprint-6 review). Keep the two lists in sync — add a cross-reference note.
2. Only `isSafe && elementType ∈ {tab, accordion-toggle, pagination, sort-header, expander}` elements are clicked. Tabs + pagination are detected via heuristic: element text matches `/^(next|prev|previous|page \d+|\d+)$/i` OR `role=tab` OR inside `[role=tablist]`. Everything else is audit-only.
3. Per safe-click: `browser_click` → `browser_wait_for(time: 1)` → `browser_console_messages` + `browser_network_requests` since click ts. Any new error-level console message or `status >= 400` network response → `CLICK_ERROR` finding with severity CRITICAL + element label + error details.
4. `safe_clicked` count in `interactive_audit_summary` reflects actual clicks performed. `click_errors` count reflects CLICK_ERROR findings.
5. Click cap per page: max 10 safe clicks (prevents runaway on list pages with 50+ tabs). Emit INFO `safe_click_capped` when hit.

## Implementation Notes

- Post-click capture uses `browser_console_messages(sinceTs)` + `browser_network_requests(filter)` — check Playwright MCP tool signatures for the actual parameter names.
- Tab / pagination heuristic is narrow on purpose. If the app uses custom widgets not matching the heuristic, the element is audit-only — operators can extend via `.ui-audit.json[interactive_click_allowlist]` (doc-only; default empty).
- Safety: any element that made it to the click path must pass BOTH `isSafe` AND the heuristic. Single-gate bypass is not allowed.

## Dependencies

S7-002.
