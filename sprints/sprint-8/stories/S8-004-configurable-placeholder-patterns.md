---
id: S8-004
title: "Configurable placeholder_patterns in .ui-audit.json"
epic: E-009
capability: CAP-011
status: planned
priority: P1
points: 1
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/CHECKS.md
  - .ui-audit.json.example
verify:
  - "grep -q 'placeholder_patterns' skills/ui-audit/reference.md"
  - "grep -q 'placeholder_patterns' .ui-audit.json.example"
done: ".ui-audit.json supports `placeholder_patterns` array; reference.md Phase 2 § 2.4 PLACEHOLDER rule merges user patterns with defaults; .ui-audit.json.example shows syntax; CHECKS.md PLACEHOLDER entry notes extension contract."
---

## Description

The PLACEHOLDER flag currently matches a fixed regex (`/lorem|TODO|FIXME|N\/A|--|\?\?\?|xxx|placeholder|fpo|coming soon/i`). Projects need to add their own (e.g., `TBD`, `_REPLACE_ME_`, design-system default strings).

## Acceptance Criteria

1. `.ui-audit.json` accepts `placeholder_patterns: ["<regex string>", ...]` at top level. Default empty array.
2. Phase 2 § 2.4 PLACEHOLDER rule compiles `BUILTIN_PATTERN | user_patterns.reduce(OR)` and tests raw against the union. Patterns compiled with try/catch — malformed regex emits CONFIG_ERROR finding, not crash.
3. `.ui-audit.json.example` shows syntax with 2 example patterns.
4. CHECKS.md PLACEHOLDER entry notes the extension contract.

## Implementation Notes

- Compile user patterns ONCE at config-load time, not per-observation (perf).
- Config-error handling mirrors role_leak_patterns compile path.

## Dependencies

None.
