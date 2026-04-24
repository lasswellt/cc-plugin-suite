---
id: S6-013
title: "CHECKS.md + PATTERNS.md skeletons (placeholders for E-009)"
epic: E-008
capability: CAP-008
status: planned
priority: P2
points: 1
depends_on: [S6-001]
assigned_agent: infra-dev
files:
  - skills/ui-audit/CHECKS.md
  - skills/ui-audit/PATTERNS.md
verify:
  - "test -f skills/ui-audit/CHECKS.md"
  - "test -f skills/ui-audit/PATTERNS.md"
  - "grep -q 'NULL_VALUE' skills/ui-audit/CHECKS.md"
  - "grep -q 'Vercel' skills/ui-audit/PATTERNS.md"
done: "CHECKS.md lists the 6 data-quality flag names + brief stubs; PATTERNS.md has Vercel-rule section stub with upstream URL reference. Both files clearly marked as skeletons to be filled by E-009."
---

## Description

CAP-008 AC2 requires CHECKS.md + PATTERNS.md to exist. Full content belongs to E-009 (CAP-011 + CAP-012). This story ships skeletons so the foundation sprint ACs close.

## Acceptance Criteria

1. `skills/ui-audit/CHECKS.md` — one section per data-quality flag: `NULL_VALUE`, `PLACEHOLDER`, `FORMAT_MISMATCH`, `STALE_ZERO`, `BROKEN_TOTAL`, `NEGATIVE_COUNT`. Each section has a 1-line description + `<!-- TODO(E-009 / CAP-011): implementation -->`.
2. `skills/ui-audit/PATTERNS.md` — headings for Vercel categories 9 (Nav+State) and 16 (Content+Copy) + severity tier reference + `<!-- TODO(E-009 / CAP-012) -->`. Include the upstream URL `https://vercel.com/design/guidelines` as a reference comment.
3. Both files open with an `> SKELETON — populated in E-009 — DO NOT treat as shipping checklist.` callout.

## Implementation Notes

- These files MUST exist (per CAP-008 AC2) but are not authoritative until E-009 fills them. Marking them `SKELETON` prevents premature use.

## Dependencies

S6-001.
