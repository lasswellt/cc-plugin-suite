# Session Protocol

Shared reference for multi-session safety. All skills that write shared state must follow this protocol to prevent collisions when multiple Claude Code sessions run concurrently.

**Companion protocols:**
- [verbose-progress.md](verbose-progress.md) — Required verbose output and activity feed logging. All skills MUST follow both protocols.
- [checkpoint-protocol.md](checkpoint-protocol.md) — STATE.md for session recovery (sprint-dev and multi-story skills).
- [context-management.md](context-management.md) — Context window hygiene for orchestrators and agents.
- [deviation-protocol.md](deviation-protocol.md) — Tiered deviation handling for agents.
- [session-report-template.md](session-report-template.md) — Session report format.

---

## Session Registration

Execute this preamble **before any other work** in the skill:

```
1. Generate SESSION_ID: "<skill-name>-<8-char-random-hex>"
   Example: sprint-dev-a3f7c1b2

2. Create session directory:
   mkdir -p .cc-sessions/

3. Write .cc-sessions/${SESSION_ID}.json:
   {
     "session_id": "<SESSION_ID>",
     "skill": "<skill-name>",
     "started": "<ISO-8601>",
     "pid": "$$",
     "status": "active",
     "working_on": "<brief description>",
     "locks_held": [],
     "tmp_dir": ".cc-sessions/${SESSION_ID}/tmp/"
   }

4. Create session temp directory:
   mkdir -p .cc-sessions/${SESSION_ID}/tmp/

5. Read ALL .cc-sessions/*.json files.
   Check for conflicting sessions using the conflict matrix below.
   If a conflict is found, ABORT with a conflict report.

6. Read the activity feed (.cc-sessions/activity-feed.jsonl) —
   print a summary of recent activity (last 30 minutes) per
   verbose-progress.md. This provides cross-instance awareness.

6b. Read the model profile (.claude-plugin/model-profiles.json) if it exists.
    Note the active profile and its behavioral adjustments:
    - quality: extra verification passes, more research agents, don't skip optional phases
    - balanced: default behavior
    - budget: fewer research agents, skip optional phases (browser verification, E2E), higher thresholds

6c. Read the developer profile (.cc-sessions/developer-profile.json) if it exists.
    Note the user's preferences (verbosity, autonomy, commit style, etc.).
    Adapt skill behavior accordingly:
    - verbosity=concise: reduce progress output, skip optional status lines
    - verbosity=detailed: add extra context at decision points
    - autonomy=high: skip clarification for unambiguous requests
    - autonomy=low: always confirm before major actions
    The profile is advisory only — explicit user instructions always override it.

### Autonomy Levels

The developer profile's `autonomy` field maps to these suite-wide behavior levels:

| Level | Value | Behavior |
|-------|-------|----------|
| **Low** | `autonomy: "low"` | Always confirm before: file edits, git operations, skill dispatches, agent spawns. Present plan before every action. |
| **Medium** | `autonomy: "medium"` | Confirm before: destructive operations (delete, overwrite, force-push), new package installs, scope changes. Proceed without confirmation for: standard edits, test runs, non-destructive git. |
| **High** | `autonomy: "high"` | Confirm before: push to remote, rollback/reset operations, scope changes exceeding 2x original estimate. Skip confirmation for: all local operations, standard git commits, agent spawns. |
| **Full** | `autonomy: "full"` | Auto-approve all operations except: `git push` (always confirm), rollback to previous sprint state (always confirm), deleting user-created files outside sprint scope (always confirm). These safety overrides cannot be bypassed. |

**Default:** If no developer profile exists or `autonomy` is not set, use **medium**.

Skills should check the autonomy level at these decision points:
- `ask`: Whether to skip Phase 2 (Clarify) — skip at high/full for unambiguous requests
- `sprint-dev`: Whether to use `autonomous`, `checkpoint`, or `interactive` mode — map low→interactive, medium→checkpoint, high/full→autonomous
- `quick`: Whether to commit automatically — auto-commit at high/full
- All skills: Whether to present plan before execution — always at low, optional at medium, skip at high/full

7. Log skill_start to the activity feed per verbose-progress.md.

8. **(Optional) Write workflow tracking file.** Skills with `disable-model-invocation: true` and explicit phases SHOULD write:
   ```json
   .cc-sessions/${SESSION_ID}-workflow.json:
   {
     "session_id": "<SESSION_ID>",
     "skill": "<skill-name>",
     "current_phase": 0,
     "last_completed_phase": -1,
     "phases": ["CONTEXT", "DISCOVER", "LOAD", "CREATE_TEAM", "IMPLEMENT", "INTEGRATE"]
   }
   ```
   Update `current_phase` and `last_completed_phase` at each phase transition. This enables the workflow-guard hook to detect out-of-order phase execution.

9. Print session registration confirmation per verbose-progress.md:
   [<skill-name>] Session registered: <SESSION_ID>
   [<skill-name>]   ├─ Checking for conflicts...
   [<skill-name>]   ├─ <conflict status> ✓
   [<skill-name>]   ├─ Recent activity: <summary>
   [<skill-name>]   └─ Ready to proceed
```

### Session Temp Directory

All temporary files MUST be written to the session-scoped directory:
```
SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"
```

**Never write to `/tmp/` — it is shared across all sessions and causes collisions.**

| Skill | Old Path (DEPRECATED) | New Path |
|-------|----------------------|----------|
| research | `/tmp/research/*.md` | `${SESSION_TMP_DIR}/research/*.md` |
| codebase-audit | `/tmp/codebase-audit/` | `${SESSION_TMP_DIR}/codebase-audit/` |
| sprint-plan | `/tmp/sprint-N-research-*.md` | `${SESSION_TMP_DIR}/sprint-N-research-*.md` |
| sprint-review | `/tmp/sprint-N-*.json/.patch/.md` | `${SESSION_TMP_DIR}/sprint-N-*` |
| fix-issue | `/tmp/issue-research.md` | `${SESSION_TMP_DIR}/issue-research.md` |
| roadmap | `/tmp/roadmap-research/` | `${SESSION_TMP_DIR}/roadmap-research/` |
| reviewer agent | `/tmp/review-findings.md` | `${SESSION_TMP_DIR}/review-findings.md` |
| completeness-gate | — | `${SESSION_TMP_DIR}/completeness-gate.json` |
| quality-metrics | — | `${SESSION_TMP_DIR}/quality-metrics.json` |
| dep-health | — | `${SESSION_TMP_DIR}/dep-health-report.md` |
| doc-gen | — | `${SESSION_TMP_DIR}/doc-gen/` |
| perf-profile | — | `${SESSION_TMP_DIR}/perf-profile.md` |
| migrate | — | `${SESSION_TMP_DIR}/migrate-progress.json` |
| release | — | `${SESSION_TMP_DIR}/release-state.json` |
| retrospective | — | `${SESSION_TMP_DIR}/retrospective/` |

---

## File-Based Locking Protocol

For files that are written by multiple skills (registries, story statuses, manifests), use file-based locking:

### Lock Cycle

```
1. CHECK:   Does <file>.lock exist?
2. ACQUIRE: Write <file>.lock with { session_id, acquired: <ISO-8601> }
3. VERIFY:  Re-read <file>.lock — confirm it contains YOUR session_id
4. OPERATE: Read/modify/write the protected file
5. RELEASE: Delete <file>.lock
```

### Stale Lock Detection

A lock is **stale** if:
- The session JSON referenced in the lock has `status: completed` or `status: failed`, OR
- The session is older than 4 hours AND the PID is not running

If a lock is stale, delete it and acquire a fresh lock.

### Wait/Retry

If a lock is held by an active session:
- Wait up to 60 seconds, checking every 5 seconds
- If still held after 60 seconds, ABORT with a conflict report

### Files Requiring Locks

| File | Used By |
|------|---------|
| `sprint-registry.json` | sprint-plan, sprint-dev, sprint-review |
| `docs/roadmap/roadmap-registry.json` | roadmap |
| `docs/roadmap/epic-registry.json` | roadmap |
| `sprints/sprint-N/stories/*.md` (status field) | sprint-dev, sprint-review |
| `sprints/sprint-N/manifest.json` | sprint-dev, sprint-plan |

---

## Operation Log

Append-only JSONL log at `.cc-sessions/operations.log`:

```jsonl
{"ts":"<ISO-8601>","session":"<SESSION_ID>","op":"session_start","detail":{}}
{"ts":"<ISO-8601>","session":"<SESSION_ID>","op":"lock_acquired","detail":{"file":"sprint-registry.json"}}
{"ts":"<ISO-8601>","session":"<SESSION_ID>","op":"registry_write","detail":{"file":"sprint-registry.json","change":"status: planned -> in-progress"}}
{"ts":"<ISO-8601>","session":"<SESSION_ID>","op":"lock_released","detail":{"file":"sprint-registry.json"}}
{"ts":"<ISO-8601>","session":"<SESSION_ID>","op":"session_end","detail":{"status":"completed"}}
```

Logged operations: `session_start`, `session_end`, `lock_acquired`, `lock_released`, `registry_write`, `story_status`, `worktree_created`, `worktree_removed`, `branch_created`, `conflict_detected`

---

## Conflict Matrix

| Session A | Session B | Resolution |
|-----------|-----------|------------|
| sprint-dev (sprint N) | sprint-dev (sprint N) | **BLOCK** — same sprint |
| sprint-dev (sprint N) | sprint-dev (sprint M) | OK — namespace worktrees by sprint |
| sprint-dev | fix-issue | WARN — different branches, proceed with caution |
| sprint-dev | sprint-review (same sprint) | **BLOCK** — cannot review while implementing |
| sprint-plan | sprint-plan | **BLOCK** — one at a time |
| fix-issue (#N) | fix-issue (#N) | **BLOCK** — same issue |
| fix-issue (#N) | fix-issue (#M) | OK — different branches |
| research | research | OK — session-scoped, no shared state |
| roadmap | roadmap | **BLOCK** — one at a time |
| codebase-audit | codebase-audit | OK — session-scoped, read-only on codebase |
| completeness-gate | completeness-gate | OK — read-only, session-scoped |
| completeness-gate | sprint-dev | OK — read-only scan during implementation |
| quality-metrics | quality-metrics | OK — writes to date-stamped files |
| dep-health (upgrade) | dep-health (upgrade) | **BLOCK** — concurrent package modifications |
| dep-health (audit) | dep-health (audit) | OK — read-only |
| perf-profile | perf-profile | OK — read-only, session-scoped |
| migrate | migrate | **BLOCK** — concurrent migrations would conflict |
| migrate | sprint-dev | **BLOCK** — both modify source files |
| release (prepare) | release (prepare) | **BLOCK** — one release at a time |
| release | sprint-dev | WARN — release should happen after sprint completion |
| retrospective | retrospective | **BLOCK** — one at a time |
| doc-gen | doc-gen | OK — writes to timestamped files |
| bootstrap | bootstrap | OK — creates new files only |
| ship | ship | **BLOCK** — one shipping workflow at a time |

---

## Session Cleanup

Every skill's final phase must:

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed` or `failed`
2. Release any held locks (delete `<file>.lock` files)
3. Optionally remove the session temp directory if no artifacts need to be preserved
4. Append `session_end` to the operation log
4b. **Write HANDOFF.json** (if applicable) — If the session was interrupted or has follow-up work, write `${SESSION_TMP_DIR}/HANDOFF.json` per [checkpoint-protocol.md](checkpoint-protocol.md). Skills listed in the HANDOFF.json support table should always write a handoff on non-clean exits.
5. Log `skill_complete` to the activity feed (`.cc-sessions/activity-feed.jsonl`) with status and summary per [verbose-progress.md](verbose-progress.md)
6. **Generate session report** — Write a report to `.cc-sessions/reports/${SESSION_ID}.md` using the format from [session-report-template.md](session-report-template.md). Auto-populate from:
   - Activity feed entries for this session (actions, decisions, issues)
   - Git diff since session start (files changed)
   - Last verification results (type-check, tests, build, completeness)
   - Agent tracker state if applicable (stories completed, blocked, deviations)
7. Print skill completion message per verbose-progress.md
