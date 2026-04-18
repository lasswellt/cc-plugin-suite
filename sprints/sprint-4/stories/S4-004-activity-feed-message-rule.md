---
id: S4-004
title: Add activity-feed message length rule to verbose-progress.md
epic: E-005
capability: CAP-005
registry_id: cf-2026-04-18-activity-feed-message-rule
status: done
github_issue: 13
priority: low
points: 1
depends_on: []
assigned_agent: doc-writer
files:
  - skills/_shared/verbose-progress.md
verify:
  - "grep -qE 'message.*200 char|message.*length' skills/_shared/verbose-progress.md"
done: verbose-progress.md documents the ≤200-char soft rule for activity-feed `message` fields.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` §B.3 (and artifact-inventory finding §2.6), activity-feed `message` strings occasionally leak >500 chars. JSONL envelope is preservation-boundary; `message` value is the compression target. Add a soft length rule to verbose-progress.md so future sprint-review grep-audits can flag offenders.

## Acceptance Criteria

1. `skills/_shared/verbose-progress.md` documents: `message` field SHOULD be ≤200 chars. Overflow moves to `detail`.
2. Include a grep pattern for sprint-review: `"message":".\{300,\}"` catches >300-char offenders as a non-BLOCKER warning.
3. `grep -E 'message.*200 char|message.*length' skills/_shared/verbose-progress.md` matches.
4. No enforcement hook added this story (it's a documentation-level soft rule).

## Implementation Notes

Insert a new section in verbose-progress.md titled something like "## Activity-feed message length" (2-3 sentences). Keep the rule simple — hard rule is 300 chars for the grep-audit threshold; style target is 200 chars.

## Dependencies

None. Parallel to S4-001, S4-002.
