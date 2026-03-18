---
name: implement
description: "Sprint implementation phase only"
argument-hint: "--sprint NNN | --stories STORY-XXX-001,STORY-XXX-002"
disable-model-invocation: true
---

# Sprint Implementation

You run the implementation phase of a sprint.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[implement]` prefixed status lines at every phase transition, decision point, and when dispatching to sprint-dev. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Flag Parsing

Parse the following flags from the user's arguments:

- `--sprint NNN`: Implement all stories for the specified sprint number.
- `--stories STORY-XXX-001,STORY-XXX-002`: Implement only the specified stories.

At least one flag must be provided. If neither is given, ask the user which
stories or sprint to implement.

## Pre-Flight Validation

Before invoking sprint-dev, verify:

1. **Sprint exists**: Read `sprint-registry.json` and confirm the target sprint has `status: planned` or `status: in-progress`. If not found, inform the user and stop.
2. **Stories exist**: Verify story files exist in `sprints/sprint-${N}/stories/`. If `--stories` was specified, confirm each story ID maps to an existing file.
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active `sprint-dev` sessions on the same sprint. If a conflict exists, warn the user and stop.
4. **Build baseline**: Confirm the project builds cleanly (or note pre-existing errors) before spawning agents.

All code produced must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations, no empty handlers, no stub returns.

## Execution

Invoke the **sprint-dev** skill with the parsed context:

- If `--sprint` was specified, pass the sprint number so the skill can look up
  the sprint backlog.
- If `--stories` was specified, pass the story IDs directly.

The sprint-dev skill will handle the actual implementation work: reading story
definitions, writing code, running tests, and verifying each story.

## Progress Reporting

- Report which story is being worked on as implementation proceeds.
- After all stories are complete, provide a summary of what was implemented and
  any issues encountered.
