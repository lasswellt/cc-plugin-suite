# Research: Making /sprint Compatible with /loop

**Date**: 2026-03-25
**Type**: Feature Investigation
**Status**: Complete
**Agents**: 3/3 succeeded

---

## Summary

The `/sprint` skill (plan -> implement -> review) cannot currently be used with `/loop` because it always starts from scratch, blocks on stale session conflicts, and requires user confirmation at phase boundaries. The fix is to add a **reconciliation layer** at `/sprint` entry that reads current sprint state from disk, determines the correct phase, and dispatches automatically -- following the controller pattern used by Kubernetes, Terraform, and ArgoCD. The existing `/next` skill already has the exact decision tree needed; the main work is embedding that logic into `/sprint`, adding stale session cleanup to the session protocol, and suppressing user prompts in loop mode.

---

## Research Questions

### 1. What does /loop expect from skills it invokes?

`/loop` is a built-in Claude Code feature that re-invokes a slash command at a fixed interval (e.g., `/loop 10m /blitz:sprint`). It expects:
- The target skill can be called repeatedly without side effects from prior invocations
- Each invocation is self-bootstrapping (reads state from disk, not memory)
- The skill exits cleanly after doing its work so the next interval can fire
- No special args or env vars are passed -- the skill receives the same invocation each time

### 2. What state detection does /sprint currently have?

**Pre-flight checks** (from `skills/sprint/SKILL.md`):
1. Roadmap exists (roadmap-registry.json or epic-registry.json)
2. Epics available and unblocked
3. No conflicting sessions (reads all `.cc-sessions/*.json`)
4. Clean git working tree (warn only)

**Missing for /loop compatibility**:
- No sprint-status-based routing (always runs plan -> implement -> review)
- `--resume` flag exists but must be explicitly passed
- No stale session cleanup (crashed sessions leave `status: active`)
- User confirmation required between phases

### 3. How should session conflicts be handled for /loop?

The session protocol detects stale **locks** (>4h + dead PID) but not stale **session JSON files**. A crashed `/sprint` leaves its session file with `status: active`, blocking the next `/loop` invocation.

**Fix**: Add stale session detection to `session-protocol.md`:
- A session JSON is stale if: `status: active` AND (`pid` not running OR session older than 4 hours)
- On stale detection: update `status` to `failed`, release any locks, log cleanup event
- This must happen during session registration (step 5) before conflict checking

### 4. What existing mechanisms support idempotent behavior?

| Mechanism | Location | Supports /loop? |
|-----------|----------|----------------|
| STATE.md checkpoint | checkpoint-protocol.md | Yes -- sprint-dev can resume from any story |
| HANDOFF.json | checkpoint-protocol.md | Partially -- requires user prompt to resume |
| `--resume` flag | sprint/SKILL.md | Partially -- must be explicitly passed |
| sprint-registry.json status | sprint-dev Phase 1.6/4.7 | Yes -- lifecycle state is on disk |
| /next decision tree | next/SKILL.md | Yes -- maps state to correct next action |

### 5. What's the right granularity for /loop invocations?

**One phase per invocation** is the recommended pattern. Each `/loop` tick should:
1. Read sprint state (fast -- file reads only)
2. Determine which phase to run
3. Execute that phase
4. Exit cleanly

This matches the reconciliation pattern and avoids the problem of long-running multi-phase operations blocking the loop interval.

---

## Findings

### Finding 1: The /next Decision Tree is Directly Reusable

The `/next` skill (`skills/next/SKILL.md`) has a priority-ordered decision tree that maps current project state to the correct next action:

```
1. In-progress sprint WITH STATE.md    -> /blitz:implement --resume
2. In-progress sprint WITHOUT STATE.md -> /blitz:implement --sprint N
3. Sprint with status "review"         -> /blitz:review --sprint N
4. Sprint with status "reviewed"       -> /blitz:ship
5. Sprint with status "planned"        -> /blitz:implement --sprint N
6. Roadmap with unblocked epics        -> /blitz:sprint-plan
7. All epics blocked/done              -> /blitz:roadmap extend
8. No roadmap                          -> /blitz:roadmap full
```

This is the exact routing logic `/sprint` needs for loop compatibility. Currently `/next` only **suggests** -- it doesn't execute. The design question is whether to make `/next` executable or embed the logic in `/sprint`.

*Source: codebase-analyst, skills/next/SKILL.md*

### Finding 2: Sprint State Machine is Fully Tracked on Disk

The sprint lifecycle is captured in `sprint-registry.json`:

```
(none) --[sprint-plan]--> planned --[sprint-dev]--> in-progress --[sprint-dev]--> review --[sprint-review]--> reviewed --[ship]--> done
```

Additionally, `STATE.md` tracks per-story progress within `in-progress`, and story frontmatter tracks individual story status. All state is file-based and readable without expensive operations.

*Source: codebase-analyst*

### Finding 3: The Controller/Reconciliation Pattern is the Right Model

The dominant pattern for idempotent multi-phase CLIs comes from Kubernetes operators:

```
Observe -> Diff -> Act -> Report
```

Applied to `/sprint`:
1. **Observe**: Read sprint-registry.json, STATE.md, session files
2. **Diff**: Compare current state against "sprint complete" desired state
3. **Act**: Execute the one phase that advances toward completion
4. **Report**: Log what was done and exit

Key principle: **the reconciler doesn't care about history -- it only cares about the delta between "what is" and "what should be."**

*Source: web-researcher*

### Finding 4: Stale Session Cleanup is the Critical Blocker

The session protocol has stale lock detection but NOT stale session detection. This means:
- First `/loop` invocation starts `/sprint`, creates session with `status: active`
- Sprint completes or crashes
- If crash: session remains `status: active`
- Next `/loop` invocation reads stale session, sees conflict, BLOCKs

**Fix**: Add to session-protocol.md step 5:
```
For each session with status: active:
  - Check if PID is still running (kill -0 $pid 2>/dev/null)
  - Check if session is older than 4 hours
  - If PID dead OR session >4h old: mark as failed, release locks, log cleanup
```

*Source: codebase-analyst, cross-referenced with web-researcher anti-patterns*

### Finding 5: User Prompts Must Be Suppressible

`/sprint` currently prompts the user at:
- Phase 1: "Present the plan to the user and ask for confirmation before proceeding"
- Phase 1.5 (gap closure): "Present the gap-closure plan and ask for confirmation"
- STATE.md staleness: "Warn user, ask whether to resume or start fresh"

In `/loop` mode, these must be auto-approved. The autonomy level system already supports this (high/full = skip confirmations).

*Source: codebase-analyst, session-protocol.md autonomy levels*

---

## Compatibility Analysis

### Integration with Existing Architecture

| Component | Compatibility | Notes |
|-----------|--------------|-------|
| Session protocol | Needs stale session cleanup | 1 section to add |
| Checkpoint protocol | Fully compatible | STATE.md + HANDOFF.json already support resume |
| Sprint registry | Fully compatible | Status lifecycle on disk, file-locked |
| /next decision tree | Directly reusable | Embed or reference |
| Autonomy levels | Supports prompt suppression | Map loop -> high autonomy |
| Activity feed | Fully compatible | Loop invocations log normally |
| Conflict matrix | Compatible after stale fix | Stale sessions cleaned before conflict check |

### No New Dependencies Required

This is purely a SKILL.md instruction change + session protocol enhancement. No new tools, libraries, or infrastructure needed.

---

## Recommendation

**Approach: Add a reconciliation layer to `/sprint` with a `--loop` flag.**

This is preferred over "use `/loop` with `/next`" because:
1. `/sprint` is the natural entry point users already know
2. The reconciliation logic is small (file reads + decision tree)
3. Keeps `/next` as a read-only advisor (clean separation of concerns)
4. Allows `/sprint --loop` to be the documented pattern

The `--loop` flag (or auto-detection when invoked by `/loop`) triggers:
- Skip user confirmations (set autonomy to high)
- Auto-resume from checkpoints without prompting
- Stale session cleanup before conflict check
- One-phase-per-invocation execution model
- Clean "nothing to do" exit when all phases complete

---

## Implementation Sketch

### 1. Update `skills/_shared/session-protocol.md` -- Stale Session Cleanup

Add to step 5 (conflict detection), before checking the conflict matrix:

```markdown
### 5a. Stale Session Cleanup

Before checking conflicts, clean up stale sessions:

For each .cc-sessions/*.json with status: active:
  1. Read the session's PID field
  2. Check if PID is running: kill -0 $pid 2>/dev/null
  3. If PID is NOT running OR session started >4h ago:
     - Update session status to "failed"
     - Set "failed_reason": "stale_session_cleanup"
     - Release any locks listed in "locks_held"
     - Log cleanup to activity feed:
       {"event":"warning","message":"Cleaned up stale session <SID>"}
```

### 2. Update `skills/sprint/SKILL.md` -- Add Reconciliation Layer

Add new sections before existing pre-flight validation:

```markdown
## Flag Parsing (updated)

Add: --loop  (Loop mode: auto-detect state, suppress prompts, one-phase execution)

## Phase -1: RECONCILE (loop mode only)

If --loop is specified:

1. Set autonomy to "high" (suppress all confirmations)
2. Read sprint-registry.json to get latest sprint status
3. Check for STATE.md in the latest sprint directory
4. Apply the /next decision tree:

   | Current State | Action | Then |
   |---|---|---|
   | in-progress + STATE.md | Invoke sprint-dev --resume | Exit |
   | in-progress, no STATE.md | Invoke sprint-dev --sprint N | Exit |
   | review | Invoke sprint-review --sprint N | Exit |
   | reviewed + quality pass | Invoke ship | Exit |
   | planned | Invoke sprint-dev --sprint N | Exit |
   | done/shipped + unblocked epics | Invoke sprint-plan | Exit |
   | done/shipped + all blocked | Print "All epics complete or blocked. Nothing to do." | Exit |
   | no sprint + roadmap | Invoke sprint-plan | Exit |
   | no sprint + no roadmap | Print "No roadmap found. Run /blitz:roadmap first." | Exit |

5. After dispatching one phase, exit cleanly.
   /loop will re-invoke and the next reconciliation will determine the next phase.

Without --loop, run the existing plan -> implement -> review flow unchanged.
```

### 3. Update `skills/sprint-dev/SKILL.md` -- Auto-Resume in Loop Mode

In Phase 0, step 1 (checkpoint detection):
- If STATE.md exists AND autonomy is high: auto-resume without staleness prompt
- If STATE.md is >24h old AND autonomy is NOT high: prompt as before

### 4. Update `.claude-plugin/skill-registry.json`

Update the sprint entry's description and argument-hint to document `--loop`.

### 5. Files Changed

| File | Change Type | Size |
|------|------------|------|
| `skills/_shared/session-protocol.md` | Add stale session cleanup section | ~15 lines |
| `skills/sprint/SKILL.md` | Add --loop flag, reconciliation phase | ~40 lines |
| `skills/sprint-dev/SKILL.md` | Auto-resume when autonomy=high | ~5 lines |
| `.claude-plugin/skill-registry.json` | Update sprint description | ~2 lines |

---

## Risks

### 1. Runaway Loop (Low Risk)
If `/sprint` dispatches a phase that fails repeatedly, `/loop` will keep re-invoking and hitting the same failure.

**Mitigation**: The circuit breaker already exists in sprint-dev (3 failures = blocked). For plan/review phases, add a simple failure counter in the session JSON. After 3 consecutive failures of the same phase, exit with "Circuit breaker: phase X failed 3 times. Manual intervention needed."

### 2. Stale Session Cleanup Race (Low Risk)
Two `/loop` invocations could try to clean the same stale session simultaneously.

**Mitigation**: The cleanup is idempotent (marking `failed` twice is harmless). Lock files protect shared registries. Session JSONs are per-session so no write contention.

### 3. Long Phase Overlaps (Medium Risk)
If a phase takes longer than the `/loop` interval, the next invocation arrives while the previous is still running.

**Mitigation**: The session conflict check (after stale cleanup) will detect the active session and correctly BLOCK. The next `/loop` tick will try again. Recommend a `/loop` interval of 15-30 minutes for sprints (not 5m).

### 4. Sprint-Dev Resume Reliability (Low Risk)
STATE.md resume has been specified but may not be battle-tested in all edge cases.

**Mitigation**: The reconciliation layer adds no new complexity to sprint-dev -- it just auto-passes `--resume`. Any resume bugs are pre-existing and should be fixed regardless.

---

## References

- [Kubernetes Reconciliation Patterns](https://hkassaei.com/posts/kubernetes-and-reconciliation-patterns/)
- [Terraform State Management](https://www.gruntwork.io/blog/how-to-manage-terraform-state)
- [Idempotent Pipelines](https://dev.to/alexmercedcoder/idempotent-pipelines-build-once-run-safely-forever-2o2o)
- [GitHub Actions Re-run Docs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
- `skills/next/SKILL.md` -- Decision tree for state-based routing
- `skills/_shared/session-protocol.md` -- Session conflict detection and lock protocol
- `skills/_shared/checkpoint-protocol.md` -- STATE.md and HANDOFF.json formats
- `skills/sprint/SKILL.md` -- Current sprint orchestrator
- `skills/sprint-dev/SKILL.md` -- Implementation skill with checkpoint/resume
