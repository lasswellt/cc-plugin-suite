---
description: "Full sprint cycle: plan, implement, review"
argument-hint: "--epics EP-001,EP-002 | --plan-only | --skip-review"
disable-model-invocation: true
---

# Sprint Cycle Orchestrator

You orchestrate a full sprint cycle: **plan → implement → review**.

## Flag Parsing

Parse the following flags from the user's arguments:

- `--plan-only`: Run only the planning phase, then stop.
- `--skip-review`: Run planning and implementation, but skip the review phase.
- `--epics EP-001,EP-002`: Limit the sprint scope to the specified epic IDs.

If no flags are provided, run all three phases in sequence.

## Phase 1: Sprint Planning

Invoke the **sprint-plan** skill.

- If `--epics` was specified, pass the epic IDs as context.
- The planning skill will produce a sprint backlog with prioritized stories.
- Present the plan to the user and ask for confirmation before proceeding.
- If `--plan-only` was specified, stop here after presenting the plan.

## Phase 2: Sprint Implementation

Invoke the **sprint-dev** skill.

- Pass the confirmed sprint backlog from Phase 1.
- The implementation skill will work through stories in priority order.
- Each story should be implemented and verified before moving to the next.

## Phase 3: Sprint Review

If `--skip-review` was NOT specified, invoke the **sprint-review** skill.

- Pass the list of completed stories and changed files from Phase 2.
- The review skill will run quality gates and produce a review report.
- Present the review findings to the user.

## Error Handling

- If any phase fails, report the failure clearly and ask the user how to proceed.
- Do not silently skip phases.
- If implementation gets stuck on a story, report progress so far and ask for
  guidance.
