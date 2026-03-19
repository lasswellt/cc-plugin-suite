# Context Management Protocol

Guidelines for keeping context windows lean during multi-story, multi-agent orchestration. Prevents quality degradation from context bloat — a common failure mode in long-running development sessions.

**Companion protocols:**
- [session-protocol.md](session-protocol.md) — Session registration and file locking
- [verbose-progress.md](verbose-progress.md) — Activity feed logging
- [checkpoint-protocol.md](checkpoint-protocol.md) — STATE.md for session recovery

---

## Problem

When agents process multiple stories sequentially, their context window accumulates:
- Full story specs for every completed story
- All verification output (type-check logs, test results)
- All SYNC/UNBLOCK/ASSIST messages from the orchestrator
- Implementation details from earlier stories

By story 4-5, the context is ~60% full. By story 7-8, quality degrades — the model loses focus on the current story and may reference stale information from earlier work.

---

## Rules for Orchestrators (sprint-dev, sprint, ship)

### 1. Summarize, Don't Relay

When relaying agent completions to other agents or tracking progress:

**Bad** (wastes context):
```
[backend-dev] DONE: S3-001 — Created user profile schema and validation.
  Full implementation details... (50 lines of code output)
  Type-check output... (20 lines)
  Test results... (30 lines)
```

**Good** (context-efficient):
```
[backend-dev] DONE: S3-001 ✓
  Files: src/schemas/user-profile.ts, src/types/user-profile.ts
  Exports: UserProfile, UserProfileSchema, validateUserProfile
  Verify: type-check PASS, tests PASS
```

### 2. Compact UNBLOCK Messages

When unblocking a dependent story, include only what the waiting agent needs:

```
UNBLOCK: S3-001 is complete. You can now start S3-005.
  Files: src/schemas/user-profile.ts
  Key exports: UserProfile (type), UserProfileSchema (zod)
  Import: import { UserProfile } from '@/schemas/user-profile'
```

Do NOT include: full implementation code, type-check output, story description, or acceptance criteria.

### 3. Periodic Context Summaries

After every 3 completed stories (or at wave boundaries), print a compact summary instead of re-listing all progress:

```
[sprint-dev] Wave 1 complete — 5/12 stories done
  Ready for Wave 2: S3-005, S3-006, S3-007
  Blocked: S3-010 (waiting on S3-008)
```

### 4. Offload to STATE.md

Rather than keeping all progress in context memory, write it to STATE.md (per checkpoint-protocol.md) and reference it:

```
[sprint-dev] Progress saved to STATE.md — see sprints/sprint-3/STATE.md for full tracker
```

---

## Rules for Agents (backend-dev, frontend-dev, test-writer)

### 1. Self-Contained DONE Summaries

When reporting story completion, produce a summary that stands alone. Do not reference previous stories by position ("as I did above", "similar to the last story"):

**Bad**:
```
DONE: S3-004 — Same pattern as S3-001, added aggregation logic.
```

**Good**:
```
DONE: S3-004 — Created dashboard data aggregation service.
  Files: src/services/dashboard-aggregation.ts
  Exports: aggregateDashboardData(userId: string): Promise<DashboardData>
  Depends on: src/schemas/user-profile.ts (UserProfile type)
  Verify: type-check PASS
```

### 2. Focus on Current Story

When starting a new story:
- Read the story spec fresh — do not rely on memory of what was discussed earlier.
- Reference files by path, not by "the file I created earlier".
- If you need context from a completed story, re-read the relevant file rather than recalling from context.

### 3. Compact Verification Output

When reporting verification results, summarize instead of dumping full output:

**Bad** (wastes context):
```
$ npx tsc --noEmit
src/services/dashboard.ts:42:5 - error TS2322: Type 'string' is not assignable to type 'number'.
... (50 more lines of type-check output)
```

**Good**:
```
Type-check: FAIL — 1 error in src/services/dashboard.ts:42 (string/number mismatch)
```

Only include full output if reporting a BLOCKED story where the orchestrator needs details to help.

### 4. Prune Before Starting a New Story

Before starting each new story, mentally reset:
- The current story spec is your primary context.
- Files you've already committed are in git — reference them by path, not by memory.
- Messages from the orchestrator about OTHER stories are informational, not actionable.

---

## Context Monitor Hook

The context monitor hook (`hooks/scripts/context-monitor.sh`) tracks approximate context utilization by counting tool input/output characters across the session.

### Warning Thresholds

| Level | Threshold | Action |
|---|---|---|
| Info | ~50% | No action. Normal operation. |
| Warning | ~60% | Emit: `"Context utilization ~60%. Consider summarizing completed work."` |
| High | ~80% | Emit: `"Context utilization high (~80%). Complete current task, then consider spawning a fresh agent for remaining work."` |

### How It Works

The hook maintains a running character count in `.cc-sessions/context-char-count`. It increments on every tool use (reading the tool output size from stdin). The thresholds are approximate — they use a rough 4-chars-per-token estimate against a 200k token window.

### Response to Warnings

**At 60%:**
- Orchestrators: Write a checkpoint (STATE.md), print a compact summary, continue.
- Agents: Summarize completed stories in a single paragraph, continue current story.

**At 80%:**
- Orchestrators: Write a checkpoint, save all state to STATE.md, and consider: if many stories remain, it may be better to complete the current wave and resume in a new session.
- Agents: Complete the current story, report DONE, and let the orchestrator decide whether to assign more work or spawn a fresh agent.
