# Session Protocol

Shared reference for multi-session safety. All skills that write shared state must follow this protocol to prevent collisions when multiple Claude Code sessions run concurrently.

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

---

## Session Cleanup

Every skill's final phase must:

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed` or `failed`
2. Release any held locks (delete `<file>.lock` files)
3. Optionally remove the session temp directory if no artifacts need to be preserved
4. Append `session_end` to the operation log
