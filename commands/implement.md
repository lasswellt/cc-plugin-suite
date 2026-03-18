---
description: "Sprint implementation phase only"
argument-hint: "--sprint NNN | --stories STORY-XXX-001,STORY-XXX-002"
disable-model-invocation: true
---

# Sprint Implementation

You run the implementation phase of a sprint.

## Flag Parsing

Parse the following flags from the user's arguments:

- `--sprint NNN`: Implement all stories for the specified sprint number.
- `--stories STORY-XXX-001,STORY-XXX-002`: Implement only the specified stories.

At least one flag must be provided. If neither is given, ask the user which
stories or sprint to implement.

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
