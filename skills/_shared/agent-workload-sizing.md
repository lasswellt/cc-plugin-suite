# Agent Workload Sizing

Authoritative guidance for blitz skill authors on sizing subagent workloads so agents don't time out, run out of context, or return nothing after burning tokens.

**Why this doc exists**: In April 2026, a reliability audit found that blitz skills lost tokens repeatedly because several spawning sites declared zero caps on file reads, web searches, output length, or turns. Since Claude Code now caps server-side tool calls at ~20 per turn (Feb 2026 regression) and all tokens are billed regardless of outcome, unbounded agents routinely failed silently mid-work. This doc defines weight classes, mandatory patterns, and banned practices.

---

## Weight Class Table

Pick the class that matches your agent's task. Each class comes with hard caps that MUST appear in the agent prompt.

| Class | Use case | Max file reads | Max web searches | Max tool calls | Max output | Wall-clock | Model |
|---|---|---|---|---|---|---|---|
| **Light** | Single-focus analysis; pattern check; library summary; grep/glob query | 8 | 5 | 15 | 150 ln | 3 min | sonnet |
| **Medium** | Multi-file synthesis; cross-cutting research; feature review; epic analysis | 15 | 8 | 25 | 250 ln | 5 min | sonnet |
| **Heavy** | Implementation; multi-story worktree; full-pillar audit | 25 | 0 | 40 | 400 ln | 8 min | opus orchestrator / sonnet workers |

**Rules**:
1. Every agent spawn MUST be in one of these three classes. If the task doesn't fit, split it into smaller agents by domain or file prefix.
2. Caps are defaults. Skills may override with documented rationale in their SKILL.md if the project scale demands it.
3. Turn budget (max tool calls) is not directly controllable via SDK today; bound it indirectly via file-read caps + output caps.
4. Heavy class requires the orchestrator to be `model: opus` and workers to be `model: sonnet` (explicit) to control cost.

---

## Mandatory Patterns by Class

### Light class

- **Output-file existence check**: the orchestrator MUST validate that the agent's expected output file exists and is non-empty before consuming the result.

### Medium class — Light + these:

- **Write-as-you-go**: agent prompt must instruct the agent to write findings to the output file incrementally, not accumulate in memory. Stub the file at the start.
- **Wall-clock timeout in prompt**: state the 5-minute budget explicitly so the agent self-paces.

### Heavy class — Medium + these:

- **HEARTBEAT markers**: agent writes `HEARTBEAT: <phase-name> at <ISO-timestamp>` to the output file at the start of each phase (at least 3 phases).
- **PARTIAL return format**: agent emits a PARTIAL block when it detects approaching the turn limit.
- **Turn-budget declaration**: agent prompt explicitly states `You have a budget of 40 tool calls. After 35, stop and write PARTIAL.`

---

## Banned Patterns

These patterns produce zero-output failures with full token cost. They are BLOCKERS in sprint-review.

1. **Unbounded file set** — prompts that say "read all files", "scan the entire codebase", or pass an unlimited file list.
2. **Unbounded diff / input** — passing "the entire sprint diff" or "the whole PR" to reviewer agents without size caps.
3. **"Write the full document at the end, not incrementally"** — guarantees zero output on timeout. (Exception: code-sweep tier agents writing a single JSON array are a structural exception where the array IS the incremental payload; their scope is already capped by tier.)
4. **Orchestrator reads agent output with no existence check** — proceeds on missing/empty files and silently produces degraded results.
5. **Retry without narrowing scope** — retrying the exact same prompt after `error_max_turns` burns tokens identically. Narrow the scope before retrying, or do not retry.

---

## HEARTBEAT Protocol

Add to the agent prompt for Heavy class:

```
HEARTBEAT PROTOCOL:
At the start of each phase, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats across your task. Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ`
to produce the timestamp.
```

**Orchestrator consumption**: count HEARTBEAT lines in the output file during polling. A file with 2+ heartbeats but no final result is partially-alive; a file with 0 heartbeats after wall-clock expiry is presumed dead.

---

## PARTIAL Protocol

Add to the agent prompt for Heavy class (and Medium at author's discretion):

```
PARTIAL DEGRADATION:
If you have 3 or fewer tool calls remaining (or detect approaching the turn
limit, output-token limit, or wall-clock budget), STOP and append this block
to the output file:
  ---
  PARTIAL: true
  COMPLETED: [list of sections finished]
  MISSING: [list of sections skipped]
  CONFIDENCE: low|medium|high
  ---
Then write a one-line confirmation to the caller: "PARTIAL: <N> sections
complete, <M> missing" and end.
```

**Orchestrator consumption**:
- If `PARTIAL: true` is present, treat as partial success. Warn the user.
- Cross-reference `MISSING` against the expected deliverable list. Flag any known-required sections that landed in MISSING.
- For narrow retry: re-spawn ONLY on items in the MISSING list, not the full task.

---

## Fail-Fast Rationale

All tokens are billed regardless of task outcome. There are no refunds for `error_max_turns`, `error_max_budget_usd`, `error_during_execution`, or context-exhaustion. Documented incidents: one auto-compact loop burned 695M cache-read tokens (anthropics/claude-code#22758); one output-file loop wrote 359 GB (anthropics/claude-code#29557). Subagent overhead is roughly 7× vs single-session for equivalent work.

**Therefore**: prefer hard caps that fail fast over permissive caps that try to salvage. Set `max_turns` and `max_budget_usd` in the SDK when available. Never retry without narrowing scope. The HEARTBEAT and PARTIAL patterns are secondary safety — the first-order fix is bounding the workload so it fits in a single agent's budget.

---

## Orchestrator-Side Validation

Every skill that spawns agents MUST include this check before consuming agent output:

```bash
for f in ${SESSION_TMP_DIR}/<expected-outputs>.md; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # log to activity feed
  fi
done

# Skill-specific threshold (e.g., abort if MISSING_COUNT >= 2 of 4)
if [ "$MISSING_COUNT" -ge "$FAIL_THRESHOLD" ]; then
  echo "Aborting: too many agents failed to produce output"
  exit 1
fi
```

---

## How to Reference This Doc

Every blitz skill that spawns subagents should add to its Additional Resources block:

```markdown
- For agent workload sizing and defensive patterns, see [agent-workload-sizing.md](/_shared/agent-workload-sizing.md)
```

Reviewers (`/blitz:sprint-review`) must flag any new agent-spawn site that:
- Lacks explicit weight-class declaration (Light / Medium / Heavy)
- Lacks the mandatory patterns for its declared class
- Uses a banned pattern (unbounded files, unbounded diff, write-at-end)
- Omits the orchestrator-side output-file existence check

...as a BLOCKER.

---

## Related

- [subagent-types.md](subagent-types.md) — which subagent type to pick (Explore vs general-purpose vs blitz:*)
- [waves.md](waves.md) — wave-based execution protocol for dependency-graph orchestration
- `docs/_research/2026-04-16_agent-reliability.md` — full audit findings and numerical ceilings
