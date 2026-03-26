# Research: Claude Code Recent Improvements — Blitz Plugin Gaps

**Date**: 2026-03-25
**Type**: Feature Investigation
**Status**: Complete
**Agents**: 3/3 succeeded

---

## Summary

Claude Code has shipped significant improvements in March 2026 that the blitz plugin does not yet leverage. The highest-impact gaps are: (1) sprint-dev still manually manages worktrees via bash when dedicated `EnterWorktree`/`ExitWorktree` tools now exist, (2) seven new hook events (`CwdChanged`, `FileChanged`, `SessionStart`, `TeammateIdle`, `TaskCompleted`, `Elicitation`, `ElicitationResult`) are available but unharnessed, (3) `CronCreate`/`CronDelete` scheduling tools exist but are unused — they complement the `/loop` support we just added, (4) the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` flag may no longer be needed as agent teams went production-stable in March, and (5) PID-based stale session detection (`$$`) is broken since each bash invocation gets a new PID.

---

## Research Questions

### 1. What new Claude Code features have been released in the last 2 weeks?

**March 25 (v2.1.83)**: `managed-settings.d/` drop-in directory, `CwdChanged`/`FileChanged` hook events, `--console` flag, turn duration toggle.

**March 19 (v2.1.79)**: MCP elicitation support (structured mid-task input), `Elicitation`/`ElicitationResult` hooks, `--channels` permission relay, fixed `--resume` dropping parallel tool results.

**March 12 (v2.1.74)**: Actionable `/context` suggestions, `autoMemoryDirectory` setting, `--bare` flag for scripted calls.

**March 5 (v2.1.71)**: `/loop` command, Agent Teams on Bedrock/Vertex/Foundry, `last_assistant_message` in Stop/SubagentStop hooks.

**Earlier**: `/simplify`, `/batch` commands, HTTP hooks, voice mode, channels, Auto Mode (research preview).

### 2. Are there new tool capabilities blitz skills could leverage?

Yes — `EnterWorktree`/`ExitWorktree` for worktree management, `CronCreate`/`CronDelete`/`CronList` for scheduling, `RemoteTrigger` for remote execution. All available in the tool environment but unused.

### 3. Have there been changes to the agent/team system?

Agent Teams went production-stable in March. Key additions: `agent_id`/`agent_type` fields in hook inputs, `TeammateIdle` hook (exit code 2 keeps teammate working), `TaskCompleted` hook (exit code 2 blocks completion), nested teammate spawning fixed, memory leak fixed.

### 4. Are there new hook types or configuration options?

7 new hook events: `CwdChanged`, `FileChanged`, `SessionStart`, `TeammateIdle`, `TaskCompleted`, `Elicitation`, `ElicitationResult`. HTTP hooks (POST JSON to URL) now supported alongside shell commands. Hook source display in permission prompts.

### 5. Has the skill system been updated?

Skills and commands are now unified. Skills can restrict tools, override models, hook lifecycle events, and run in forked contexts. Auto-namespaced (`plugin-name:skill-name`). Fixed: skill hooks firing twice per event.

### 6. Are there deprecations or breaking changes?

`TaskOutput` tool deprecated (use `Read` on output file). `/output-style` deprecated (use `/config`). Legacy SDK removed — must use `@anthropic-ai/claude-agent-sdk`. Windows managed settings path changed.

---

## Findings

### Finding 1: EnterWorktree/ExitWorktree Tools Replace Manual Worktree Management

Sprint-dev (Phase 2.3) manually creates worktrees via `git worktree add -b ...` and tells agents their working directory via message instructions. Claude Code now has dedicated `EnterWorktree`/`ExitWorktree` tools that provide proper worktree isolation with auto-cleanup when no changes are made.

**Impact**: High. Current approach is fragile — cleanup uses `git worktree remove ... 2>/dev/null` which silently swallows errors and can lose uncommitted changes. The dedicated tools handle this correctly.

**Fix**: Replace Phase 2.3/4.4 manual worktree bash commands with `EnterWorktree`/`ExitWorktree` tool calls. Update agent spawn instructions to use `isolation: "worktree"` parameter on Agent tool.

*Sources: web-researcher (v2.1.72 changelog), codebase-analyst (sprint-dev/SKILL.md audit)*

### Finding 2: Seven New Hook Events Available

Blitz currently uses only `PreToolUse` and `PostToolUse` (9 hooks total). Claude Code now supports:

| New Event | Blitz Use Case |
|-----------|---------------|
| `SessionStart` | Auto-load project context, run health check, display activity feed |
| `TeammateIdle` | Auto-assign next story to idle agents (exit code 2 keeps them working) |
| `TaskCompleted` | Validate story completion against DoD (exit code 2 blocks if incomplete) |
| `CwdChanged` | Re-detect stack when user switches directories |
| `FileChanged` | Auto-format, auto-lint, auto-test on file changes (more precise than PostToolUse on Edit) |
| `Elicitation` | MCP servers requesting structured input during skills |
| `ElicitationResult` | Capture elicitation responses for logging |

Additionally, **HTTP hooks** allow sending JSON to a URL instead of running shell commands — useful for external integrations (Slack notifications, CI triggers).

*Source: web-researcher (v2.1.83 + v2.1.79 changelogs)*

### Finding 3: CronCreate/CronDelete Scheduling Tools Available but Unused

`CronCreate`, `CronDelete`, and `CronList` tools are available in the environment. These provide more robust scheduling than `/loop` for periodic skill execution:

| Skill | Schedule | Rationale |
|-------|----------|-----------|
| `dep-health` | Weekly | Catch outdated/vulnerable dependencies |
| `quality-metrics` | Daily | Track quality trends over time |
| `completeness-gate` | Post-commit | Catch placeholders before they age |
| `retrospective` | After each sprint | Auto-analyze completed sessions |

The `/schedule` skill is already listed in the system but has no blitz implementation.

*Source: codebase-analyst (tool environment audit)*

### Finding 4: Experimental Agent Teams Flag May Be Obsolete

The installer sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in project settings. Agent Teams was launched Feb 5, 2026 as experimental. By March 2026, stability improvements (nested spawning, memory leak fixes) and expanded platform support (Bedrock, Vertex, Foundry) suggest it has graduated to stable.

**Risk**: If Anthropic removes the experimental flag, the env var becomes a no-op (harmless). But relying on it delays awareness of any API changes in the stable version.

**Fix**: Test agent spawning without the flag. If it works, remove it from the installer and document the minimum CLI version required.

*Sources: web-researcher (v2.1.71 changelog), codebase-analyst (installer audit)*

### Finding 5: PID-Based Stale Session Detection is Broken

The session protocol tracks session PID via `$$` in bash and checks staleness via `kill -0 $pid`. However, `$$` returns the subshell PID which changes between bash invocations — it does not represent the Claude Code session PID. This means:
- Stale session detection cannot reliably determine if a session is alive
- The stale cleanup we just added to session-protocol.md inherits this flaw

**Fix**: Replace PID tracking with timestamp-based staleness only (session older than threshold = stale). Alternatively, use the activity feed's last write timestamp — if a session hasn't logged to the feed in >30 minutes, it's likely dead.

*Source: codebase-analyst (session-protocol audit)*

### Finding 6: Silent Error Suppression Masks Failures

Multiple patterns across the plugin suppress errors silently:
- `git worktree remove ... 2>/dev/null` — can lose uncommitted changes
- Hook scripts use `|| true` — failures invisible
- `cat ... 2>/dev/null || echo "..."` — masks missing file errors

**Fix**: Replace `2>/dev/null` with proper error handling. Log errors to the activity feed. Use exit codes to distinguish "file not found" (expected) from "permission denied" (unexpected).

*Source: codebase-analyst*

### Finding 7: SKILL.md Frontmatter Capabilities Not Fully Leveraged

Claude Code now supports additional SKILL.md frontmatter fields that blitz skills don't use:

| Field | Current Usage | Opportunity |
|-------|--------------|-------------|
| `allowed-tools` | Used by 2 skills | Should be on all skills to restrict tool access |
| `compatibility` | Not used | Pin minimum CLI version (e.g., `>=2.1.71` for /loop) |
| `dependencies` | Not used | Declare software dependencies (node, git) |
| `metadata` | Not used | Add category, maturity, etc. (currently in registry only) |

*Source: docs-researcher (SKILL.md specification)*

### Finding 8: Agent Hook Fields Enable Better Monitoring

Hook inputs now include `agent_id` and `agent_type` fields. Blitz hooks could use these to:
- Track which agent triggered an edit (for activity feed attribution)
- Apply different validation rules per agent type
- Monitor agent-specific patterns (e.g., frontend-dev editing backend files = deviation)

*Source: web-researcher (v2.1.71 changelog)*

### Finding 9: MCP Elicitation Enables Interactive Skills Without Prompts

MCP servers can now request structured input from the user mid-task. This could replace the prompt-based confirmation pattern in skills like sprint-plan (AC waiver) and sprint (plan confirmation) — providing a structured dialog rather than free-text prompts.

*Source: web-researcher (v2.1.79 changelog)*

### Finding 10: Stack Detection Runs on Every Skill Without Caching

Every skill includes `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` which runs bash on every invocation. Results are not cached. For `/loop` scenarios where skills are re-invoked frequently, this adds unnecessary overhead.

**Fix**: Cache stack detection results in a file (e.g., `.cc-sessions/stack-profile.json`) with a TTL (e.g., 1 hour). Invalidate on `CwdChanged` hook event.

*Source: codebase-analyst*

---

## Compatibility Analysis

| Blitz Component | CC Feature | Compatible? | Gap |
|----------------|-----------|-------------|-----|
| sprint-dev worktrees | EnterWorktree/ExitWorktree | No — manual bash | Replace with tools |
| hooks/hooks.json | New hook events (7+) | No — only Pre/PostToolUse | Add new events |
| Session protocol | PID tracking | Broken | Switch to timestamp-based |
| Agent spawning | EXPERIMENTAL flag | Fragile | Test without flag |
| SKILL.md frontmatter | compatibility, dependencies | Not used | Add to all skills |
| /sprint --loop | CronCreate/CronDelete | Not used | Complement /loop |
| Activity feed | JSONL append | Race condition risk | Use atomic append |
| Hook scripts | HTTP hooks | Not used | Add webhook support |
| Interactive skills | MCP elicitation | Not used | Structured dialogs |

---

## Recommendation

Implement improvements in three priority tiers:

### Tier 1: Critical (fix broken/fragile things)
1. **Fix PID tracking** — Replace `$$` with timestamp-based staleness in session-protocol.md
2. **Remove experimental flag dependency** — Test and remove `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
3. **Fix silent error suppression** — Replace `2>/dev/null` in worktree cleanup and hooks

### Tier 2: High Value (adopt new capabilities)
4. **Use EnterWorktree/ExitWorktree** in sprint-dev instead of manual git commands
5. **Add new hook events** — `SessionStart`, `TeammateIdle`, `TaskCompleted` at minimum
6. **Add CronCreate scheduling** for periodic skills (dep-health, quality-metrics)
7. **Cache stack detection** with TTL + CwdChanged invalidation

### Tier 3: Nice to Have (modernization)
8. **Add `compatibility` field** to all SKILL.md frontmatter
9. **Use `agent_id`/`agent_type`** in hook scripts for agent-aware monitoring
10. **Explore MCP elicitation** for structured confirmations
11. **Support HTTP hooks** alongside shell hooks
12. **Add CLI version check** to installer

---

## Implementation Sketch

### 1. Fix PID tracking (session-protocol.md)

Replace the PID-based staleness check:
```markdown
## Current (broken):
Check if PID is running: kill -0 $pid 2>/dev/null

## New (timestamp-based):
A session is stale if:
- status: active AND started >4h ago, OR
- status: active AND no activity feed entry from this session in the last 30 minutes
  (check: grep for session ID in last 50 lines of activity-feed.jsonl)
```

### 2. Remove experimental flag (installer)

In `installer/src/agents.js` and any settings injection:
```diff
- CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
+ # Agent teams are GA as of Claude Code v2.1.71 (March 2026)
+ # No experimental flag needed
```

### 3. EnterWorktree in sprint-dev (SKILL.md)

Replace Phase 2.3:
```markdown
## Current:
git worktree add -b sprint-${N}/<role> .worktrees/sprint-${N}/<role> HEAD

## New:
Use `isolation: "worktree"` parameter when spawning agents via the Agent tool.
Agents automatically get isolated worktrees with proper cleanup.
```

### 4. New hooks (hooks/hooks.json)

Add entries for new events:
```json
{
  "event": "SessionStart",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
  "description": "Load project context and display activity feed on session start"
},
{
  "event": "TaskCompleted",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/task-completed-validate.sh",
  "description": "Validate story completion against Definition of Done"
}
```

### 5. Stack detection cache

```bash
# In detect-stack.sh, add caching:
CACHE_FILE=".cc-sessions/stack-profile.json"
CACHE_TTL=3600  # 1 hour

if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# ... run detection, write to CACHE_FILE
```

### Files Changed

| File | Change | Priority |
|------|--------|----------|
| `skills/_shared/session-protocol.md` | Replace PID with timestamp staleness | Tier 1 |
| `installer/src/agents.js` | Remove experimental flag | Tier 1 |
| `skills/sprint-dev/SKILL.md` | Use EnterWorktree/ExitWorktree | Tier 2 |
| `hooks/hooks.json` | Add SessionStart, TaskCompleted hooks | Tier 2 |
| `hooks/session-start.sh` | New hook script | Tier 2 |
| `hooks/task-completed-validate.sh` | New hook script | Tier 2 |
| `scripts/detect-stack.sh` | Add caching with TTL | Tier 2 |
| `skills/*/SKILL.md` (all 31) | Add `compatibility` frontmatter | Tier 3 |
| `.claude-plugin/plugin.json` | Add minimum CC version | Tier 3 |

---

## Risks

### 1. EnterWorktree known bug (Low Risk)
March 19 bug: `EnterWorktree` tool does not invoke `WorktreeCreate`/`WorktreeRemove` hooks (but `--worktree` CLI flag does). If blitz relies on worktree hooks, this could be an issue.

**Mitigation**: Don't depend on worktree hooks. Use explicit worktree management where needed.

### 2. Hook event availability by CC version (Medium Risk)
New hook events (CwdChanged, etc.) are only available in v2.1.83+. Users on older versions would see these hooks fail.

**Mitigation**: Add `compatibility: ">=2.1.83"` to plugin.json. Hook scripts should check CC version and exit 0 gracefully if events aren't supported.

### 3. Experimental flag removal (Low Risk)
Removing `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` could break users on older CC versions where the flag is still required.

**Mitigation**: Keep the flag in the installer but add a comment. Only remove when minimum CC version is pinned to >=2.1.71.

### 4. JSONL race conditions (Medium Risk)
Activity feed append by multiple sessions has no atomic guarantee. Could cause corrupted lines.

**Mitigation**: Use `flock` for atomic append: `flock -x .cc-sessions/feed.lock -c "echo '...' >> activity-feed.jsonl"`. Or accept occasional corruption — JSONL readers can skip malformed lines.

---

## References

- [Claude Code Changelog](https://code.claude.com/docs/en/changelog) — v2.1.71 through v2.1.83
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Claude Code Worktrees Guide](https://claudefa.st/blog/guide/development/worktree-guide)
- [GitHub anthropics/claude-code releases](https://github.com/anthropics/claude-code/releases)
- [Anthropic Blog — Claude Code March 2026](https://techcrunch.com/2026/03/24/anthropic-hands-claude-code-more-control-but-keeps-it-on-a-leash/)
