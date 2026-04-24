---
id: S7-012
title: "Role-leak HTML scan (configurable patterns, CRITICAL severity)"
epic: E-012
capability: CAP-016
status: planned
priority: P1
points: 1
depends_on: [S7-010]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/PATTERNS.md
verify:
  - "grep -qE 'role[_-]leak|ROLE[_-]LEAK' skills/ui-audit/reference.md"
  - "grep -q 'role_leak_patterns' skills/ui-audit/reference.md"
  - "grep -q 'role_leak_patterns' skills/ui-audit/PATTERNS.md || grep -q 'role[_-]leak' skills/ui-audit/PATTERNS.md"
done: "Phase ROLE documents the HTML-source regex scan (document.documentElement.outerHTML against .ui-audit.json.role_leak_patterns + built-in defaults /data-admin-only/ /admin.?panel/); CRITICAL finding on any match when logged in as non-admin role."
---

## Description

Backstop: even if an admin-only feature correctly hides itself from the viewport, its DOM may still leak into HTML source. Scan is cheap (one `browser_evaluate` per page per non-admin role) and catches hydration bugs that leak admin markup.

## Acceptance Criteria

1. Phase ROLE § Role-leak scan documented with verbatim JS from research doc §3.9:
   ```js
   const html = document.documentElement.outerHTML;
   const patterns = [/* defaults + .ui-audit.json.role_leak_patterns */];
   const matches = patterns.filter(re => re.test(html));
   ```
2. Built-in default patterns: `/data-admin-only/i`, `/admin.?panel/i`, `/<script[^>]*>.*?admin.*?<\/script>/is`. Extensible via `.ui-audit.json.role_leak_patterns` (array of regex strings).
3. Scan runs ONLY when current role is non-admin. Skip in anonymous (anonymous has no baseline to compare; use role_invariants instead).
4. Any match → `ROLE_LEAK` finding, severity CRITICAL, detail `{role, page, matched_patterns: [...]}`.
5. `PATTERNS.md` gains a "Role-leak patterns" section documenting the built-ins + extension contract.

## Implementation Notes

- JS regex strings from config need safe compile: `new RegExp(str, 'i')` with try/catch — a malformed pattern from `.ui-audit.json` should emit a CONFIG_ERROR finding, not crash the skill.
- The scan is intentionally coarse. False positives are expected and operators tune by extending `role_leak_patterns`. An app-agnostic sensitive-data detector would be a future feature; for now, pattern-list is enough.

## Dependencies

S7-010.
