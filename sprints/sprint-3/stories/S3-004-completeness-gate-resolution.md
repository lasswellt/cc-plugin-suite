---
id: S3-004
title: Resolve Sprint-2 completeness-gate partial (operator decision + close registry)
epic: E-002
capability: CAP-002
registry_id: cf-2026-04-18-compress-safe-references-wave2
status: planned
github_issue: 9
priority: medium
points: 1
depends_on: []
assigned_agent: backend-dev
files:
  - skills/completeness-gate/reference.md
  - .cc-sessions/carry-forward.jsonl
verify:
  - "jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.id == \"cf-2026-04-18-compress-safe-references-wave2\")) | .[0].status' .cc-sessions/carry-forward.jsonl | grep -qE '\"complete\"|\"dropped\"|\"deferred\"'"
done: cf-compress-safe-references-wave2 is no longer in active/partial state — either compressed-then-complete, or dropped with reason, or deferred with revisit date.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Sprint 2 ended with `cf-compress-safe-references-wave2` at coverage 0.857 (6/7) because `skills/completeness-gate/reference.md` contains `## Grep Patterns by Check` — an UNSAFE marker per sprint-1 rule 2.3. The research doc listed it SAFE; classification drift. Operator resolves one of three paths per review-report.md Minor Finding 1.

## Acceptance Criteria

1. Exactly one of the three resolution paths is applied:
   - **(a) Rename + compress.** Rename `## Grep Patterns by Check` heading to a non-triggering title (e.g., `## Detector Patterns by Check`). Verify the rename doesn't break any existing grep reference that looks up this heading (search SKILL.md for `Grep Patterns by Check` literal). If clean, re-run `/blitz:compress skills/completeness-gate/reference.md`. Append `progress` event: delivered.actual=7, coverage=1.0, status=complete.
   - **(b) Accept partial.** Append `dropped` event with `drop_reason: "grep-patterns-load-bearing; compression-risk-outweighs-0.3%-savings"` and `revival_candidate: null`.
   - **(c) Defer.** Append `deferred` event with `notes: "revisit after CAP-007 BLOCKER lands to confirm patterns still in use"` and a revisit date 60 days out.
2. registry entry transitions out of status=partial.
3. A decision event is logged to `.cc-sessions/activity-feed.jsonl` naming the path chosen.

## Implementation Notes

The operator's guidance will determine path. Absent explicit direction in autonomy=full mode, default to **path (b) — accept partial (drop with reason)**. Rationale: the `## Grep Patterns by Check` heading and the patterns beneath it are load-bearing for `skills/completeness-gate/SKILL.md`, which greps them as behavior-specification lookup keys. Compression risk exceeds the ~0.3% token saving (this file is 307 lines, mostly tables and pattern data).

## Dependencies

None. Runs in parallel with S3-001..S3-003.
