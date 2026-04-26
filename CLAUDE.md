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

This repo contains **36 development skills** in `skills/`. Skills are auto-discovered by Claude Code from `skills/<name>/SKILL.md` (Anthropic-canonical layout — no central registry). Skills are invoked via `/blitz:<skill-name>`.

Every SKILL.md must satisfy the canonical frontmatter contract enforced by `hooks/scripts/skill-frontmatter-validate.sh`: third-person description ≤1024 chars, body ≤500 lines, required fields (`name`, `description`, `model`, `effort`, `compatibility`, `allowed-tools` when invokable), and the verbatim OUTPUT STYLE snippet from `/_shared/terse-output.md`.

## Shared Protocols

All skills follow the protocols in `skills/_shared/` (14 files). Required for every skill:
- **session-protocol.md** — Multi-session safety (locks, conflict matrix, session registration, autonomy levels)
- **verbose-progress.md** — Verbose output format and activity feed logging
- **terse-output.md** — Output style + canonical exemptions list

Required for the sprint family:
- **story-frontmatter.md** — Canonical YAML schema for sprint stories (producer/consumer matrix, validation algorithm)
- **state-handoff.md** — Pipeline contracts (which artifacts each skill produces/requires)
- **carry-forward-registry.md** — Carry-forward registry (canonical Reader Algorithm + writer contracts)

Required for skills that spawn agents:
- **spawn-protocol.md** — Subagent type selection, weight classes, HEARTBEAT/PARTIAL, **Agent Output Contract** (success/failure/partial gate thresholds — never redefine inline)
- **agent-prompt-boilerplate.md** — Author-time dedup target for recurring Agent() prompt sections (BUDGET, WRITE-AS-YOU-GO, HEARTBEAT/PARTIAL, CONFIRMATION). Cited via `<!-- import: -->` markers in 7 `references/main.md` files

## Hooks

19 hook scripts wired through `hooks/hooks.json` across 8 events (`SessionStart`, `UserPromptExpansion`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, `TaskCompleted`, `TeammateIdle`). They handle file protection, auto-formatting, auto-linting, auto-testing, commit validation (frontmatter lint, version sync, link rot, reference compression), context monitoring, and activity-feed logging. See [hooks/scripts/README.md](hooks/scripts/README.md) for the full index grouped by event.
