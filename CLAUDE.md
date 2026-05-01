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

This repo contains **38 development skills** in `skills/` and **8 plugin agents** in `agents/`. Skills are auto-discovered by Claude Code from `skills/<name>/SKILL.md` (Anthropic-canonical layout — no central registry). Skills are invoked via `/blitz:<skill-name>`.

Every SKILL.md must satisfy the canonical frontmatter contract enforced by `hooks/scripts/skill-frontmatter-validate.sh`: third-person description ≤1024 chars, body ≤500 lines, required fields (`name`, `description`, `model`, `effort`, `compatibility`, `allowed-tools` when invokable), and the verbatim OUTPUT STYLE snippet from `/_shared/terse-output.md`.

**Holistic-machine entry point**: `agents/orchestrator.md` is activated as the plugin's main-thread agent via `.claude-plugin/settings.json {"agent": "orchestrator"}` (Claude Code ≥2.1.117). Freeform user input lands on the orchestrator; explicit slash commands bypass it. See `skills/_shared/agent-routing.md` for the constraint-aware routing protocol (subagents cannot spawn subagents → super-orchestrator skills stay slash-invoked).

## Shared Protocols

All skills follow the protocols in `skills/_shared/` (19 files). Required for every skill:
- **session-protocol.md** — Multi-session safety (locks, conflict matrix, session registration, autonomy levels)
- **verbose-progress.md** — Verbose output format and activity feed logging
- **terse-output.md** — Output style + canonical exemptions list

Required for the sprint family:
- **story-frontmatter.md** — Canonical YAML schema for sprint stories (producer/consumer matrix, validation algorithm)
- **state-handoff.md** — Pipeline contracts (which artifacts each skill produces/requires)
- **carry-forward-registry.md** — Carry-forward registry (canonical Reader Algorithm + writer contracts)

Required for skills that spawn agents:
- **spawn-protocol.md** — Subagent type selection, weight classes, HEARTBEAT/PARTIAL/WRAP_UP, three-tier timeout, stuck-loop detection, **Agent Output Contract** + **Token Budget & Reply Contract** (§9)
- **agent-prompt-boilerplate.md** — Author-time dedup target for recurring Agent() prompt sections (BUDGET, WRITE-AS-YOU-GO, HEARTBEAT/PARTIAL, CONFIRMATION). Cited via `<!-- import: -->` markers in 7 `references/main.md` files
- **token-budget.md** (v1.11+) — model routing matrix (60/35/5 Haiku/Sonnet/Opus), 1-hr cache TTL, JSON reply contract, lazy MCP/skill load, anti-patterns
- **agent-routing.md** (v1.11+) — orchestrator routing decision tree + the subagents-cannot-spawn-subagents constraint

Required for autonomous loops + quality:
- **ratchet-protocol.md** (v1.11+) — 7 monotonic metrics, schema, multi-agent worktree merge, auto-revert on regression
- **shortcut-taxonomy.md** (v1.11+) — 19 anti-shortcut detectors with grep patterns + escape-hatch rules
- **knowledge-protocol.md** (v1.11+) — `.cc-sessions/KNOWLEDGE.md` cross-session lessons format
- **frontend-design-heuristics.md** (v1.11+) — paraphrased aesthetic philosophy, NEVER list, density-vs-whitespace guidance

## Hooks

26 hook scripts wired through `hooks/hooks.json` across 8 events (`SessionStart`, `UserPromptExpansion`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, `TaskCompleted`, `TeammateIdle`). They handle file protection, auto-formatting, auto-linting, auto-testing, commit validation (frontmatter lint, version sync, link rot, reference compression), context monitoring, activity-feed logging, and **7 anti-shortcut blockers**: 5 P0 (block-no-verify, block-destructive-git, block-destructive-sql, block-test-deletion, post-edit-typecheck-block) plus 2 P1 (block-as-any-insertion, block-test-disabling). See [hooks/scripts/README.md](hooks/scripts/README.md) for the full index grouped by event.

## Quality Gates (v1.11+)

`sprint-review` Phase 3.6 enforces 7 invariants. Sprint cannot reach PASS while any fails:

1. Carry-forward Reader Algorithm — registry consistency
2. Reserved (canonical algorithm)
3. Epic completion — no `done` epics with `incomplete` registry entries
4. Reserved (canonical algorithm)
5. OUTPUT STYLE snippet present in every SKILL.md + agent-prompt template
6. **Ratchet** — 7 monotonic metrics never regress without carry-forward (`type_errors > 0` is absolute floor)
7. **Critic** — `agents/critic.md` adversarial review must emit LGTM (it runs the 19-detector shortcut taxonomy)
