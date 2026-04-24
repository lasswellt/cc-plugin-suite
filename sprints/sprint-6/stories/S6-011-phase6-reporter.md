---
id: S6-011
title: "Phase 6 REPORTER — ui-audit-report.md + stdout + activity-feed"
epic: E-008
capability: CAP-013
status: planned
priority: P0
points: 2
depends_on: [S6-004, S6-008, S6-009, S6-010]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/SKILL.md
verify:
  - "grep -q '## Phase 6 — REPORT' skills/ui-audit/reference.md"
  - "grep -q 'docs/crawls/ui-audit-report.md' skills/ui-audit/reference.md"
  - "grep -q 'skill_complete' skills/ui-audit/reference.md"
  - "grep -qE 'severity.*CRITICAL.*HIGH.*MED.*LOW' skills/ui-audit/reference.md"
done: "Reporter aggregates findings from Phases 3/4/5 into docs/crawls/ui-audit-report.md (grouped by severity), prints stdout summary with top 3 invariant failures, logs skill_complete event."
---

## Description

Close the loop. Aggregate every finding emitted by Phases 3 (divergence + invariant), 4 (quality), 5 (heuristics — E-009 territory but reporter must accept its findings). Write markdown report. Print stdout summary. Log activity-feed completion event.

## Acceptance Criteria

1. `docs/crawls/ui-audit-report.md` written on every non-`consistency`-only run.
2. Findings grouped by severity tier (CRITICAL/HIGH/MED/LOW/INFO).
3. Each finding includes: severity, `page:label:flag` or `file:line`, brief description, timestamp, tick number.
4. Stdout summary: table with counts per severity + top 3 invariant failures by severity × age.
5. Activity-feed `skill_complete` event with detail block: `{findings_critical, findings_high, findings_med, findings_low, invariants_evaluated, invariants_failed, pages_visited, tick_count}`.
6. Report is idempotent — rerunning consistency-only mode on the same registry produces a byte-identical report (modulo timestamps).

## Implementation Notes

- Severity tier mapping (to be finalized by E-009's CAP-012 heuristics):
  - INV fail → HIGH
  - divergence uncovered by invariant → HIGH
  - FLAPPING → MED
  - STALE → LOW
  - NULL_TRANSITION → HIGH
  - Quality flags (S6-011 scope of E-009): deferred; reporter must accept `severity:` field from finding producers and render accordingly.
- Report skeleton:
  ```markdown
  # ui-audit report — <ts>
  ## Summary
  | Severity | Count |
  ## Critical
  ## High
  ## Med
  ## Low
  ## Info
  ```
- Activity-feed event format: `/_shared/verbose-progress.md`.

## Dependencies

S6-004 (skeleton), S6-008 (divergence), S6-009 (invariants), S6-010 (tick diff).
