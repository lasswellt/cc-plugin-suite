---
name: next
description: "Determines the logical next action based on current project and sprint state"
argument-hint: "(no arguments — reads state automatically)"
model: sonnet
compatibility: ">=2.1.50"
disable-model-invocation: true
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

# Next Action Advisor

Read the current project state and determine the most logical next action. Suggest a concrete command the user can run.

**No session protocol required.** This skill is lightweight and read-only.

**Verbose progress exemption:** This skill intentionally skips verbose output. Freeform activity-feed logging from CLAUDE.md still applies.

---

## Phase 0: READ STATE

### 0.1 Check Sprint Registry

```bash
cat sprint-registry.json 2>/dev/null || echo "No sprint registry"
```

If the registry exists, find the most recent sprint and its status.

### 0.2 Check for STATE.md (In-Progress Sprint)

If a sprint is `in-progress`, check for a checkpoint file:

```bash
SPRINT_DIR="sprints/sprint-${LATEST_SPRINT_NUMBER}"
cat "${SPRINT_DIR}/STATE.md" 2>/dev/null | head -20
```

If STATE.md exists, note the number of completed/remaining stories.

### 0.3 Check Activity Feed

Read the last 10 lines of the activity feed for recent context:

```bash
tail -10 .cc-sessions/activity-feed.jsonl 2>/dev/null
```

### 0.4 Check Git State

```bash
git status --porcelain 2>/dev/null | head -10
git branch --show-current 2>/dev/null
```

### 0.5 Check for Roadmap

```bash
cat roadmap-registry.json 2>/dev/null | head -5 || echo "No roadmap registry"
cat epic-registry.json 2>/dev/null | head -5 || echo "No epic registry"
```

---

## Phase 1: DETERMINE NEXT ACTION

Use this decision tree:

```
1. Is there an in-progress sprint with STATE.md?
   → YES: "Resume sprint N" — /blitz:implement --resume

2. Is there an in-progress sprint WITHOUT STATE.md?
   → YES: "Continue sprint N" — /blitz:implement --sprint N

3. Is there a sprint with status "review"?
   → YES: "Review sprint N" — /blitz:review --sprint N

4. Is there a sprint with status "reviewed" and passing quality?
   → YES: "Ship the sprint" — /blitz:ship

5. Is there a sprint with status "planned" (not yet started)?
   → YES: "Implement sprint N" — /blitz:implement --sprint N

6. Does a roadmap exist with unblocked epics?
   → YES: "Plan the next sprint" — /blitz:sprint-plan

7. Does a roadmap exist but all epics are blocked or done?
   → YES: "Extend the roadmap" — /blitz:roadmap extend

8. No roadmap exists?
   → "Create a roadmap first" — /blitz:roadmap full

9. None of the above (no sprints, no roadmap)?
   → "Start with research or bootstrap" — /blitz:ask <describe your goal>
```

### Tie-Breaking

If multiple actions are possible (e.g., a reviewed sprint AND a planned sprint), prioritize:
1. Resume interrupted work (STATE.md exists)
2. Complete in-progress work
3. Ship reviewed work
4. Start planned work
5. Plan new work

---

## Phase 2: SUGGEST

Print a clear recommendation:

```
Next Action
===========
Based on current state:
  Sprint 3: in-progress (8/12 stories done, STATE.md checkpoint exists)
  Last activity: 2h ago — sprint-dev implementing S3-009

Recommendation:
  Resume sprint 3 implementation from checkpoint.

Command:
  /blitz:implement --resume

Alternative actions:
  - /blitz:sprint-review --sprint 2  (sprint 2 awaiting review)
  - /blitz:health                    (check plugin health)
```

If the git working tree has uncommitted changes, mention that first:

```
⚠ Uncommitted changes detected. Consider committing or stashing before proceeding.
```
