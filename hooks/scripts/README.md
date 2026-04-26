# Hook Scripts

19 scripts wired through `hooks/hooks.json`, covering 8 hook events. Every script reads its trigger from stdin (or runs unconditionally on `SessionStart`/`PreCompact`-style events). All exit non-blocking by default; only `pre-commit-validate.sh`, `pre-edit-guard.sh`, `task-completed-validate.sh`, `reference-compression-validate.sh`, and `skill-frontmatter-validate.sh` can BLOCK an action by exiting 2.

## By event

### `SessionStart` — fires once per conversation

| Script | Purpose |
|---|---|
| `session-start.sh` | Replays last 10 activity-feed entries, resets per-session context counter, warns on stale (>4h) active sessions |

### `UserPromptExpansion` — fires before each prompt is sent to the model

| Script | Purpose |
|---|---|
| `blitz-prompt-expansion.sh` | Injects recent activity-feed context into every `/blitz:*` invocation so spawned skills see prior session work |

### `PreToolUse` — fires before any tool execution; can BLOCK with exit 2

| Script | Matcher | Purpose |
|---|---|---|
| `pre-edit-guard.sh` | `Write\|Edit` | Blocks edits to protected paths (`.git/`, `node_modules/`, `.cc-sessions/*.lock`) |
| `pre-edit-backup.sh` | `Write\|Edit` | Snapshots file content to `.cc-sessions/backups/` before each edit |
| `pre-commit-validate.sh` | `Bash` | Fires on `git commit`. Validates SKILL.md frontmatter on staged files; calls `check-version-sync.sh`; blocks bump commits with version drift |
| `reference-compression-validate.sh` | `Bash` | Fires on `git commit`. Validates that any compressed `references/main.md` preserves all structure of its `.original` sibling (code fences, URLs, headings, tables) |
| `markdown-link-validate.sh` | `Bash` | Fires on `git commit`. Warns on broken relative `.md` links across `skills/` (skips fenced code, inline code, http URLs, anchors). Non-blocking; pre-commit-validate.sh prints warnings only |
| `workflow-guard.sh` | `Bash` | Detects anti-patterns in shell commands (`rm -rf` outside scratch, `git push --force` to main, etc.) |

### `PostToolUse` — fires after any tool execution; non-blocking

| Script | Matcher | Purpose |
|---|---|---|
| `post-edit-activity-log.sh` | `Write\|Edit` | Appends a `file_change` event to `.cc-sessions/activity-feed.jsonl` |
| `post-edit-format.sh` | `Write\|Edit` | Auto-formats edited files via project's formatter (prettier/eslint/biome auto-detect) |
| `post-edit-lint.sh` | `Write\|Edit` | Runs project linter against the edited file; non-blocking (warnings only) |
| `post-edit-test.sh` | `Write\|Edit` | Finds and runs matching test files for the edited source |
| `analysis-paralysis-guard.sh` | `Write\|Edit` `Read\|Glob\|Grep` | Detects long read-heavy phases without writes; nudges toward action |
| `skill-frontmatter-validate.sh` | `Write\|Edit` | Lints any modified SKILL.md against the Anthropic-canonical frontmatter contract |
| `context-monitor.sh` | `Read\|Glob\|Grep` `Bash` | Tracks per-session context-character count; warns at 80% of estimated cap |

### `PreCompact` — fires before context compaction

| Script | Purpose |
|---|---|
| `pre-compact-snapshot.sh` | Snapshots current sprint state (`STATE.md`, registry tail, todo list) so a post-compact session can recover |

### `PostCompact` — fires after context compaction completes

| Script | Purpose |
|---|---|
| `post-compact-log.sh` | Logs compaction stats and prints restoration hints to the user |

### `TaskCompleted` — fires when an in-progress task transitions to completed

| Script | Purpose |
|---|---|
| `task-completed-validate.sh` | Validates task completion against the Definition of Done (story-id format check, deliverable checklist) |

### `TeammateIdle` — fires when a sibling agent reports idle (multi-agent runs)

| Script | Purpose |
|---|---|
| `teammate-idle.sh` | Forwards idle events to the activity feed so orchestrators can detect stalls |

## Conventions

- **Stdin contract** — `PreToolUse` / `PostToolUse` / `UserPromptExpansion` hooks receive a JSON blob on stdin (`{"tool_name": ..., "tool_input": {...}}`). Other events pass minimal context.
- **Repo root discovery** — every script walks up from `pwd` to the nearest `.claude-plugin/` directory; falls back to `pwd`. Never hardcodes a path.
- **Non-blocking default** — all scripts `exit 0` on success. Only `pre-commit-validate.sh`, `pre-edit-guard.sh`, `task-completed-validate.sh`, `reference-compression-validate.sh`, and `skill-frontmatter-validate.sh` can return exit 2 to block the originating action.
- **Activity-feed appends** — when a hook needs to record an event, it writes a single JSONL line to `.cc-sessions/activity-feed.jsonl` per the format in `skills/_shared/verbose-progress.md`. Use `jq -nc` to build the JSON (never `printf` — escaping bugs).
- **Quiet by default** — hook scripts only emit output when there is something the user must see. Otherwise stay silent.

## Adding a new hook

1. Drop the script under `hooks/scripts/` with executable bit set (`chmod +x`).
2. Wire it into `hooks/hooks.json` under the appropriate event + matcher.
3. Add a row to the table above.
4. Test with a manual invocation (mock stdin via `echo '{"tool_name":"Bash"...}' | hooks/scripts/your-hook.sh`).
