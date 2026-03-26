---
name: sprint
description: "Full sprint cycle: plan, implement, review. Supports --loop for use with /loop."
argument-hint: "--epics EP-001,EP-002 | --plan-only | --skip-review | --loop"
disable-model-invocation: true
compatibility: ">=2.1.71"
---

# Sprint Cycle Orchestrator

You orchestrate a full sprint cycle: **plan → implement → review**.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[sprint]` prefixed status lines at every phase transition, decision point, and when dispatching to sub-skills. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

## Flag Parsing

Parse the following flags from the user's arguments:

- `--plan-only`: Run only the planning phase, then stop.
- `--skip-review`: Run planning and implementation, but skip the review phase.
- `--epics EP-001,EP-002`: Limit the sprint scope to the specified epic IDs.
- `--resume`: Resume an interrupted sprint. Skips planning, goes directly to sprint-dev which will detect STATE.md and resume from the last checkpoint. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).
- `--gaps`: Gap closure mode. Chains: sprint-review → sprint-plan --gaps → sprint-dev. Finds quality gaps and generates fix stories automatically.
- `--mode <autonomous|checkpoint|interactive>`: Execution mode passed through to sprint-dev. `autonomous` (default) runs everything; `checkpoint` pauses after each wave for user review; `interactive` confirms each story before starting.
- `--loop`: Fully autonomous loop mode. Enables state-based reconciliation: reads current sprint state, executes **one phase**, then exits cleanly so `/loop` can re-invoke. Sets autonomy to `full` — all decisions are auto-approved, no user prompts, no confirmations, no pauses. Designed for use with `/loop <interval> /blitz:sprint --loop` under bypass permissions.

If no flags are provided, run all three phases in sequence.

---

## Loop Mode: Reconciliation Phase (--loop only)

When `--loop` is specified, replace the normal plan → implement → review flow with a **reconciliation loop** that detects current state and advances one phase per invocation. This follows the Observe → Diff → Act → Report pattern.

### Step 1: Observe — Read Current State

Perform fast, read-only state detection:

```bash
# Sprint registry
cat sprint-registry.json 2>/dev/null || echo "NO_REGISTRY"

# Latest sprint STATE.md (if in-progress)
LATEST=$(cat sprint-registry.json 2>/dev/null | grep -o '"number": *[0-9]*' | tail -1 | grep -o '[0-9]*')
cat "sprints/sprint-${LATEST}/STATE.md" 2>/dev/null | head -10 || echo "NO_STATE"

# Roadmap
cat roadmap-registry.json 2>/dev/null | head -5 || echo "NO_ROADMAP"
cat epic-registry.json 2>/dev/null | head -5 || echo "NO_EPICS"

# Active sessions (stale cleanup happens via session protocol step 5a)
ls .cc-sessions/*.json 2>/dev/null
```

### Step 2: Diff — Determine Next Action

Apply this priority-ordered decision tree (same logic as `/next`):

| # | Condition | Action | Dispatch |
|---|-----------|--------|----------|
| 1 | Sprint `in-progress` + STATE.md exists | Resume implementation | Invoke **sprint-dev** with `--resume` |
| 2 | Sprint `in-progress` + no STATE.md | Continue implementation | Invoke **sprint-dev** `--sprint N` |
| 3 | Sprint status `review` | Run review | Invoke **sprint-review** `--sprint N` |
| 4 | Sprint status `reviewed` + quality passing | Ship it | Invoke **ship** |
| 5 | Sprint status `planned` | Start implementation | Invoke **sprint-dev** `--sprint N` |
| 6 | No active sprint + roadmap with unblocked epics | Plan next sprint | Invoke **sprint-plan** |
| 7 | No active sprint + all epics blocked/done | Nothing to do | Print status and exit |
| 8 | No roadmap exists | Cannot proceed | Print "No roadmap. Run `/blitz:roadmap` first." and exit |

**Tie-breaking** (if multiple conditions match):
1. Resume interrupted work (STATE.md exists)
2. Complete in-progress work
3. Ship reviewed work
4. Start planned work
5. Plan new work

### Step 3: Act — Execute One Phase

1. Set autonomy to `full` — suppress all user confirmation prompts across all sub-skills. This ensures fully autonomous operation with bypass permissions. The only safety overrides that remain are: `git push` (always logged), rollback to previous sprint state (always logged), deleting user files outside sprint scope (always logged). All other decisions are auto-approved.
2. Pass `--mode autonomous` to sprint-dev (if dispatching to implementation). Never use `checkpoint` or `interactive` mode in loop.
3. Dispatch to the identified sub-skill. All sub-skills inherit autonomy `full`.
4. When the sub-skill completes, **exit immediately**. Do NOT continue to the next phase. The next `/loop` tick will re-invoke `/sprint --loop`, which will re-evaluate state and dispatch the next phase.

### Step 4: Report — Log and Exit

Print a concise reconciliation report:

```
[sprint] Loop reconciliation:
  ├─ Sprint 3: in-progress (8/12 stories, STATE.md checkpoint exists)
  ├─ DECISION: Resume implementation from checkpoint
  │  Reason: STATE.md found with 4 remaining stories
  ├─ Dispatching: sprint-dev --resume
  └─ Next /loop tick will re-evaluate after completion
```

If nothing to do:

```
[sprint] Loop reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ All epics: done or blocked
  ├─ DECISION: Nothing to do
  └─ Idle — waiting for new epics or roadmap changes
```

### Session Conflict Handling in Loop Mode

If a conflicting session is detected (after stale cleanup from session-protocol step 5a):
- Do NOT abort with an error. Instead, print a status message and exit cleanly:
  ```
  [sprint] Loop reconciliation:
    ├─ Active session detected: sprint-dev-a3f7c1b2 (started 5m ago)
    ├─ DECISION: Defer — active session is still working
    └─ Will retry on next /loop tick
  ```
- This prevents `/loop` from treating an active sprint as an error.

---

## Pre-Flight Validation

Before starting any phase (in both normal and loop mode), verify:

1. **Roadmap exists**: Check for `roadmap-registry.json` or `epic-registry.json`. If neither exists, inform the user that a roadmap is needed first and stop.
2. **Epics available**: If `--epics` was specified, confirm each epic ID exists and is unblocked. If no epics are specified, confirm at least one epic has unmet dependencies resolved. *(In loop mode, skip this check — the reconciliation tree handles it.)*
3. **No conflicting sessions**: Check `.cc-sessions/*.json` for active sprint-plan, sprint-dev, or sprint-review sessions. If a conflict exists, warn the user and stop. *(In loop mode, defer gracefully instead of stopping — see above.)*
4. **Clean working tree**: Run `git status --porcelain`. If there are uncommitted changes, warn the user. *(In loop mode, warn but do not stop.)*

All phases enforce the [Definition of Done](/_shared/definition-of-done.md). No phase is complete if delivered code contains placeholder implementations.

## Phase 1: Sprint Planning

If `--resume` was specified, skip this phase entirely and proceed to Phase 2.

Invoke the **sprint-plan** skill.

- If `--epics` was specified, pass the epic IDs as context.
- The planning skill will produce a sprint backlog with prioritized stories.
- Present the plan to the user and ask for confirmation before proceeding. *(In loop mode, auto-confirm.)*
- If `--plan-only` was specified, stop here after presenting the plan.

## Phase 1.5: Gap Closure (if --gaps)

If `--gaps` was specified:
1. First invoke **sprint-review** to identify quality issues in the current sprint.
2. Then invoke **sprint-plan --gaps** to generate fix stories from the review findings.
3. Present the gap-closure plan to the user and ask for confirmation. *(In loop mode, auto-confirm.)*
4. Proceed to Phase 2 with the gap-closure stories.

## Phase 2: Sprint Implementation

Invoke the **sprint-dev** skill.

- Pass the confirmed sprint backlog from Phase 1 (or gap-closure stories from Phase 1.5).
- If `--mode` was specified, pass it through to sprint-dev.
- The implementation skill will work through stories in priority order.
- Each story should be implemented and verified before moving to the next.

## Phase 3: Sprint Review

If `--skip-review` was NOT specified, invoke the **sprint-review** skill.

- Pass the list of completed stories and changed files from Phase 2.
- The review skill will run quality gates and produce a review report.
- Present the review findings to the user.

## Error Handling

- If any phase fails, report the failure clearly and ask the user how to proceed. *(In loop mode, log the failure to the activity feed and exit cleanly. The next /loop tick will re-evaluate.)*
- Do not silently skip phases.
- If implementation gets stuck on a story, report progress so far and ask for guidance. *(In loop mode, the sprint-dev circuit breaker handles stuck stories automatically.)*
