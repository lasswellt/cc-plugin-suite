---
id: S5-002
title: Upgrade spawn-protocol §7 WARNING → BLOCKER
epic: E-007
capability: CAP-007
registry_id: cf-2026-04-18-spawn-protocol-warning-upgrade
status: planned
github_issue: 15
priority: high
points: 1
depends_on: []
assigned_agent: doc-writer
files:
  - skills/_shared/spawn-protocol.md
verify:
  - "! grep -q 'WARNING (not BLOCKER)' skills/_shared/spawn-protocol.md"
  - "grep -qE 'BLOCKER.*terse-output|sprint-review.*fails' skills/_shared/spawn-protocol.md"
done: spawn-protocol.md:328 no longer contains "WARNING (not BLOCKER)"; text now states the check is a BLOCKER.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` Phase B.4, the current `spawn-protocol.md:328` enforcement clause reads "Sprint-review flags the absence of this snippet from an Agent prompt template as a WARNING (not BLOCKER)". Sprint 3 S3-002 delivered 7/7 UNSAFE reference.md compliance. The gate is now safe to upgrade.

## Acceptance Criteria

1. `skills/_shared/spawn-protocol.md` line ~328 (the enforcement clause) no longer contains "WARNING (not BLOCKER)".
2. Replacement text states that sprint-review fails the sprint if an Agent() prompt template omits the OUTPUT STYLE snippet. Example: "Sprint-review enforces this snippet's presence as a BLOCKER: any Agent() prompt template that omits it causes the sprint to fail until the gap is closed."
3. Verify: `grep -q 'WARNING (not BLOCKER)' skills/_shared/spawn-protocol.md` returns 1 (no match).
4. Verify: `grep -qE 'BLOCKER.*terse-output|sprint-review.*fails'` returns 0 (match present).

## Implementation Notes

Minimal edit. Surgical `Edit` tool call to replace the WARNING clause. Do not touch surrounding content.

## Dependencies

None. Parallel to S5-001 and S5-003.
