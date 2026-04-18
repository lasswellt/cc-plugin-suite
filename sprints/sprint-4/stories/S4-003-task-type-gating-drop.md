---
id: S4-003
title: Transition cf-task-type-gating to dropped (superseded by cf-lite-exemption-markers)
epic: E-005
capability: CAP-005
registry_id: cf-2026-04-18-task-type-gating
status: planned
github_issue: 12
priority: low
points: 1
depends_on: [S4-002]
assigned_agent: backend-dev
files:
  - .cc-sessions/carry-forward.jsonl
verify:
  - "jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.id == \"cf-2026-04-18-task-type-gating\")) | .[0].status' .cc-sessions/carry-forward.jsonl | grep -q 'dropped'"
done: cf-2026-04-18-task-type-gating has status=dropped with a drop_reason citing cf-lite-exemption-markers as the supersede target.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

The research doc's capability-index explicitly marks cf-task-type-gating as superseded by cf-lite-exemption-markers (per the dedup log). After S4-002 lands the per-section LITE markers, transition cf-task-type-gating to `dropped` status with a clear reason.

## Acceptance Criteria

1. Append a `dropped` event to `.cc-sessions/carry-forward.jsonl` for cf-2026-04-18-task-type-gating.
2. `drop_reason` cites cf-lite-exemption-markers as the supersede source.
3. `revival_candidate: null` (no revival path — the per-section approach fully covers the whole-skill approach).
4. After S4-003 applies, the latest-wins registry view shows the entry as `status: dropped`.

## Implementation Notes

One JSONL line to append:

```jsonl
{"id":"cf-2026-04-18-task-type-gating","ts":"<ISO-8601>","event":"dropped","status":"dropped","drop_reason":"Superseded by cf-2026-04-18-lite-exemption-markers (per-section markers are the preferred approach over whole-skill output_style_policy per research doc 2026-04-18_runtime-artifact-terse-propagation Finding 6). S4-002 landed the per-section markers on 9 skills; whole-skill policy is redundant.","revival_candidate":null,"last_touched":{"sprint":"sprint-4","date":"<ISO-8601>"},"notes":"Capability-index dedup_log called this out at plan time; S4-003 executes the deferred drop."}
```

## Dependencies

- S4-002 (LITE-exemption markers must land first so the supersede is factually accurate).
