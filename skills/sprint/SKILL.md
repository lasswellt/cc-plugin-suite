---
name: sprint
description: "Full sprint cycle: plan, implement, review. Supports --loop for use with /loop."
argument-hint: "--epics EP-001,EP-002 | --plan-only | --skip-review | --loop"
disable-model-invocation: false
compatibility: ">=2.1.71"
---


**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Fragments OK, drop filler/pleasantries/hedging. Preserve code, paths, commands, YAML/JSON verbatim.
# Sprint Cycle Orchestrator

You orchestrate a full sprint cycle: **plan → implement → review**.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md) throughout. Print `[sprint]` prefixed status lines at every phase transition, decision point, and when dispatching to sub-skills. Log `skill_start` and `skill_complete` events to the activity feed (`.cc-sessions/activity-feed.jsonl`).

**Carry-forward awareness is mandatory in `--loop` mode.** The reconciliation loop reads `.cc-sessions/carry-forward.jsonl` every tick and treats active/partial entries as load-bearing state. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the full protocol. Silent scope drops are prevented by the decision-tree split at rows 6a-6d below.

## Flag Parsing

Parse the following flags from the user's arguments:

- `--plan-only`: Run only the planning phase, then stop.
- `--skip-review`: Run planning and implementation, but skip the review phase.
- `--epics EP-001,EP-002`: Limit the sprint scope to the specified epic IDs.
- `--resume`: Resume an interrupted sprint. Skips planning, goes directly to sprint-dev which will detect STATE.md and resume from the last checkpoint. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).
- `--gaps`: Gap closure mode. Chains: sprint-review → sprint-plan --gaps → sprint-dev. Finds quality gaps and generates fix stories automatically.
- `--mode <autonomous|checkpoint|interactive>`: Execution mode passed through to sprint-dev. `autonomous` (default) runs everything; `checkpoint` pauses after each wave for user review; `interactive` confirms each story before starting.
- `--loop`: Fully autonomous loop mode. Enables state-based reconciliation: reads current sprint state, executes **one phase**, then exits cleanly so `/loop` can re-invoke. Sets autonomy to `full` — all decisions are auto-approved, no user prompts, no confirmations, no pauses. Designed for use with `/loop <interval> /blitz:sprint --loop` under bypass permissions.

  **Scheduling tiers for `--loop`:**
  | Tier | How | Persistence | Min interval | Use case |
  |------|-----|-------------|-------------|---------|
  | `/loop` + CronCreate | Session-scoped | Requires active session | 1 min | Interactive dev sprints |
  | Desktop scheduled task | Survives session restart | Requires machine | 1 min | Overnight local runs |
  | Routine (cloud) | Machine-independent | Fully autonomous | 1 hour | Nightly CI, weekly sweeps |

  **Self-scheduling in loop mode:** After Step 3 (Act) completes, use `ScheduleWakeup` to register the next tick — this keeps the loop alive through idle periods without requiring the user to keep a terminal open:
  ```
  ScheduleWakeup(
    delaySeconds: 270,   # under 5-min cache TTL; adjust per sprint cadence
    prompt: "/blitz:sprint --loop",
    reason: "next sprint reconciliation tick"
  )
  ```
  Do NOT use `ScheduleWakeup` if the user explicitly invoked `/loop <interval>` — that already handles scheduling. Use it only when `--loop` is invoked directly (not via `/loop`). Detect via `CLAUDE_CODE_LOOP_MANAGED` env var: if `"1"`, skip `ScheduleWakeup`.

  **Session expiry:** CronCreate-backed sessions expire after 7 days. For runs longer than 7 days, use a cloud Routine (see `/schedule`).

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

# Carry-forward registry — latest-wins reduction, active/partial only
# (see skills/_shared/carry-forward-registry.md)
CF_ACTIVE=$(jq -s '
  group_by(.id)
  | map(max_by(.ts))
  | map(select(.status == "active" or .status == "partial"))
  | length
' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "0")

# Carry-forward rollover escalations (rollover_count >= 3)
CF_ESCALATED=$(jq -s '
  group_by(.id)
  | map(max_by(.ts))
  | map(select((.status == "active" or .status == "partial") and (.rollover_count // 0) >= 3))
  | length
' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "0")

# Next-sprint planning inputs auto-injected by previous sprint-review Invariant 4
NEXT_SPRINT=$((LATEST + 1))
CF_PENDING_INPUTS=$(test -f "sprints/sprint-${NEXT_SPRINT}-planning-inputs.json" && echo "1" || echo "0")

# Uningested research docs (newer than roadmap-registry.json, not yet in carry-forward)
INGESTED_IDS=$(jq -rs '[group_by(.id)[] | max_by(.ts).id] | join("\n")' \
  .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "")
UNINGESTED=$(find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null \
  | while read f; do
      IDS=$(grep -o 'id: cf-[^ ]*' "$f" 2>/dev/null | awk '{print $2}')
      if [ -z "$IDS" ]; then echo "$f"; continue; fi
      for id in $IDS; do
        echo "$INGESTED_IDS" | grep -qx "$id" || { echo "$f"; break; }
      done
    done)
UNINGESTED_COUNT=$(echo "$UNINGESTED" | grep -c '.' 2>/dev/null || echo 0)

# Active sessions (stale cleanup happens via session protocol step 5a)
ls .cc-sessions/*.json 2>/dev/null
```

### Step 2: Diff — Determine Next Action

Apply this priority-ordered decision tree (same logic as `/next`):

| # | Condition | Action | Dispatch |
|---|-----------|--------|----------|
| 0 | `$UNINGESTED_COUNT > 0` (research docs exist, not yet ingested into roadmap) | Ingest research first | Invoke **roadmap extend**, then exit cleanly so loop re-enters at row 1 |
| 1 | Sprint `in-progress` + STATE.md exists | Resume implementation | Invoke **sprint-dev** with `--resume` |
| 2 | Sprint `in-progress` + no STATE.md | Continue implementation | Invoke **sprint-dev** `--sprint N` |
| 3 | Sprint status `review` | Run review | Invoke **sprint-review** `--sprint N` |
| 4 | Sprint status `reviewed` + quality passing | Ship it | Invoke **ship** |
| 5 | Sprint status `planned` | Start implementation | Invoke **sprint-dev** `--sprint N` |
| 6a | No active sprint + **`CF_ESCALATED > 0`** | Escalate — operator review needed | Print escalation banner with entry ids and exit cleanly |
| 6b | No active sprint + **`CF_PENDING_INPUTS == 1`** (planning inputs file exists from prior review Invariant 4) | Plan gap-closure sprint against injected entries | Invoke **sprint-plan** (it will honor the planning-inputs file in Phase 0 step 8) |
| 6c | No active sprint + roadmap with unblocked epics | Plan next sprint | Invoke **sprint-plan** |
| 6d | No active sprint + **`CF_ACTIVE > 0`** (registry has active/partial entries even though epics look done) | Plan gap-closure sprint against registry | Invoke **sprint-plan** — it will read the registry in Phase 0 step 8 and select parent epics for re-planning |
| 7 | No active sprint + all epics blocked/done **AND `CF_ACTIVE == 0` AND `CF_PENDING_INPUTS == 0`** | Nothing to do | Print status and exit |
| 8 | No roadmap exists AND `CF_ACTIVE == 0` | Cannot proceed | Print "No roadmap. Run `/blitz:roadmap` first." and exit |

**Tie-breaking** (if multiple conditions match):
1. Resume interrupted work (STATE.md exists)
2. Complete in-progress work
3. Ship reviewed work
4. Start planned work
5. Resolve carry-forward escalations (row 6a) — blocks all further progress until human review
6. Plan new work from injected inputs (row 6b) before roadmap epics (row 6c)
7. Plan carry-forward gap closure (row 6d) before declaring idle (row 7)

**Why rows 6a-6d exist:** the prior state machine collapsed rows 6 and 7 together, so an idle roadmap with a non-empty carry-forward registry was indistinguishable from "nothing to do" — the exact silent-drop mode traced in `docs/_research/2026-04-08_sprint-carryforward-registry.md`. The four-way split makes registry state load-bearing: the loop cannot exit idle while there is pending carry-forward work, and it cannot bounce indefinitely on stuck entries because row 6a short-circuits `rollover_count >= 3` to human escalation.

### Step 3: Act — Execute One Phase

1. Set autonomy to `full` — suppress all user confirmation prompts across all sub-skills. This ensures fully autonomous operation with bypass permissions. The only safety overrides that remain are: `git push` (always logged), rollback to previous sprint state (always logged), deleting user files outside sprint scope (always logged). All other decisions are auto-approved.
2. Pass `--mode autonomous` to sprint-dev (if dispatching to implementation). Never use `checkpoint` or `interactive` mode in loop.
3. Dispatch to the identified sub-skill. All sub-skills inherit autonomy `full`.
4. **Commit and push** — After the sub-skill completes, ensure all changes are committed and pushed to the remote. This is critical in loop mode because each invocation runs in a fresh context — uncommitted/unpushed work would be invisible to the next tick.
   ```bash
   git add -A
   git status --porcelain | head -5  # Check if there's anything to commit
   git commit -m "feat(sprint-${N}): loop checkpoint — <phase completed>" || true
   git push origin HEAD || true
   ```
5. When the commit/push completes, **exit immediately**. Do NOT continue to the next phase. The next `/loop` tick will re-invoke `/sprint --loop`, which will re-evaluate state and dispatch the next phase.

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
  ├─ Carry-forward registry: 0 active, 0 partial, 0 pending inputs
  ├─ DECISION: Nothing to do
  └─ Idle — waiting for new epics or roadmap changes
```

If carry-forward work is pending (row 6d):

```
[sprint] Loop reconciliation:
  ├─ Sprint 3: reviewed (quality: PASS)
  ├─ All epics: done in epic-registry.json
  ├─ Carry-forward registry: 2 active, 1 partial (NOT idle)
  │    - cf-2026-04-02-modal-consistency: partial, coverage 0.646
  │    - cf-2026-04-05-api-error-handling: active, coverage 0.0
  │    - cf-2026-04-07-auth-rate-limits: partial, coverage 0.33
  ├─ DECISION: Plan gap-closure sprint
  │    Reason: registry has 3 entries with incomplete scope
  ├─ Dispatching: sprint-plan (will re-select parent epics)
  └─ Next /loop tick will re-evaluate after planning completes
```

If a carry-forward escalation is present (row 6a):

```
[sprint] Loop reconciliation:
  ├─ Sprint 3: reviewed (quality: CONDITIONAL)
  ├─ Carry-forward registry: 1 escalation (rollover_count >= 3)
  │    - cf-2026-04-02-modal-consistency: rollover_count=3
  │      Parent: CAP-133 / EPIC-105
  │      Last touched: sprint-197 (3 sprints ago)
  │      Reason: repeated auto-waivers; blocked by type-check failures
  ├─ DECISION: Escalate to human review
  │    Loop cannot auto-advance while this entry is stuck.
  │    Resolve with one of:
  │      a) /blitz:sprint-plan with explicit split targeting this entry
  │      b) Append `deferred` event to .cc-sessions/carry-forward.jsonl
  │         with a revisit date in notes
  │      c) Append `dropped` event with drop_reason + revival_candidate
  └─ Exiting — /loop will re-evaluate on next tick (will re-escalate
       until resolved)
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
1b. **Uningested research check**: Run the UNINGESTED detection from Loop Step 1. If any files found, print:
    ```
    [sprint] Uningested research detected:
      docs/_research/YYYY-MM-DD_<slug>.md
    [sprint] Auto-invoking /blitz:roadmap extend before sprint cycle…
    ```
    Invoke `/blitz:roadmap extend`, then re-read `roadmap-registry.json` / `epic-registry.json` and continue to step 2.
    If `roadmap extend` fails (e.g., malformed `scope:` block), surface the error with the doc path and stop — do not silently continue to sprint.
    *(In `--loop` mode: handled by row 0 of the decision tree — Pre-Flight skips this check.)*
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
