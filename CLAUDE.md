# CC Plugin Suite — Development Guidelines

## Activity Feed (Always-On)

**Every Claude Code session in this repo MUST maintain the activity feed, regardless of whether a skill is invoked.**

### On Conversation Start

1. Create `.cc-sessions/` if it doesn't exist: `mkdir -p .cc-sessions`
2. Read the last 20 lines of `.cc-sessions/activity-feed.jsonl` (if it exists)
3. Print a brief summary of recent activity from other sessions so the user knows what's been happening
4. Log your own session start:
   ```
   {"ts":"<ISO-8601>","session":"cli-<8-char-hex>","skill":"freeform","event":"session_start","message":"<brief description of what user asked>","detail":{}}
   ```

### On Every Substantive Action

Append a line to `.cc-sessions/activity-feed.jsonl` when you:
- Start working on a task (even without a skill): `event: "task_start"`
- Make a significant decision: `event: "decision"`
- Complete a file edit or creation: `event: "file_change"` with `detail: {"files": ["path1", "path2"]}`
- Run a build, test, or lint command: `event: "verification"` with `detail: {"command": "...", "result": "pass|fail"}`
- Complete the task: `event: "task_complete"` with `detail: {"summary": "..."}`

### Entry Format

```jsonl
{"ts":"<ISO-8601>","session":"<id>","skill":"freeform","event":"<type>","message":"<human-readable>","detail":{}}
```

For skill invocations, the skill name replaces `"freeform"`. The verbose-progress protocol in `skills/_shared/verbose-progress.md` has the full specification.

### Reading the Feed

Before starting work, always check recent activity. If another session is actively working on overlapping files, mention it to the user. Format:

```
Recent activity:
  [cli-a3f7c1b2] 5m ago — Editing skills/sprint-dev/SKILL.md (freeform)
  [sprint-dev-b4e8f2a1] 28m ago — Sprint 3 implementation complete (sprint-dev)
```

If no activity feed exists or is empty, skip the summary silently.

## Skill System

This repo contains 25 development skills in `skills/`. See `.claude-plugin/skill-registry.json` for the full registry. Skills are invoked via `/cc-plugin-suite:<skill-name>`.

## Shared Protocols

All skills follow two shared protocols in `skills/_shared/`:
- **session-protocol.md** — Multi-session safety (locks, conflict matrix, session registration)
- **verbose-progress.md** — Verbose output format and activity feed logging

## Hooks

Pre/post tool-use hooks are configured in `hooks/hooks.json`. These handle file protection, auto-formatting, auto-linting, auto-testing, and commit validation.
