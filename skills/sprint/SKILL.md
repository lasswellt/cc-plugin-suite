---
name: sprint
description: "Full sprint cycle: plan, implement, review"
argument-hint: "--epics EP-001,EP-002 | --plan-only | --skip-review"
disable-model-invocation: true
---

# Sprint Cycle Orchestrator

You orchestrate a full sprint cycle: **plan → implement → review**.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[sprint]` prefixed status lines at every phase transition, decision point, and when dispatching to sub-skills. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Flag Parsing

Parse the following flags from the user's arguments:

- `--plan-only`: Run only the planning phase, then stop.
- `--skip-review`: Run planning and implementation, but skip the review phase.
- `--epics EP-001,EP-002`: Limit the sprint scope to the specified epic IDs.
- `--resume`: Resume an interrupted sprint. Skips planning, goes directly to sprint-dev which will detect STATE.md and resume from the last checkpoint. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).
- `--gaps`: Gap closure mode. Chains: sprint-review → sprint-plan --gaps → sprint-dev. Finds quality gaps and generates fix stories automatically.
- `--mode <autonomous|checkpoint|interactive>`: Execution mode passed through to sprint-dev. `autonomous` (default) runs everything; `checkpoint` pauses after each wave for user review; `interactive` confirms each story before starting.

If no flags are provided, run all three phases in sequence.

## Pre-Flight Validation

Before starting any phase, verify:

1. **Roadmap exists**: Check for `roadmap-registry.json` or `epic-registry.json`. If neither exists, inform the user that a roadmap is needed first and stop.
2. **Epics available**: If `--epics` was specified, confirm each epic ID exists and is unblocked. If no epics are specified, confirm at least one epic has unmet dependencies resolved.
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active sprint-plan, sprint-dev, or sprint-review sessions. If a conflict exists, warn the user and stop.
4. **Clean working tree**: Run `git status --porcelain`. If there are uncommitted changes, warn the user.

All phases enforce the [Definition of Done](/_shared/definition-of-done.md). No phase is complete if delivered code contains placeholder implementations.

## Phase 1: Sprint Planning

If `--resume` was specified, skip this phase entirely and proceed to Phase 2.

Invoke the **sprint-plan** skill.

- If `--epics` was specified, pass the epic IDs as context.
- The planning skill will produce a sprint backlog with prioritized stories.
- Present the plan to the user and ask for confirmation before proceeding.
- If `--plan-only` was specified, stop here after presenting the plan.

## Phase 1.5: Gap Closure (if --gaps)

If `--gaps` was specified:
1. First invoke **sprint-review** to identify quality issues in the current sprint.
2. Then invoke **sprint-plan --gaps** to generate fix stories from the review findings.
3. Present the gap-closure plan to the user and ask for confirmation.
4. Proceed to Phase 2 with the gap-closure stories.

## Phase 2: Sprint Implementation

Invoke the **sprint-dev** skill.

- Pass the confirmed sprint backlog from Phase 1 (or gap-closure stories from Phase 1.5).
- If `--mode` was specified, pass it through to sprint-dev.
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
