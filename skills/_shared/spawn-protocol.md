# Subagent Spawn Protocol

Authoritative guidance for blitz skills that spawn subagents. Covers subagent type selection, workload sizing, defensive patterns (HEARTBEAT / PARTIAL), and wave-based dependency execution. Every skill that spawns agents MUST follow this protocol.

**Why this doc exists**: Three separate docs (subagent-types.md, agent-workload-sizing.md, waves.md) were consolidated here in v1.4.0. They addressed overlapping concerns and were always linked together. This single file is the one stop for skill authors.

---

## Contents

1. [Subagent Type Selection](#1-subagent-type-selection) — which built-in type or blitz:<role> to pick, foot-guns, decision matrix
2. [Workload Sizing](#2-workload-sizing) — Light/Medium/Heavy weight classes, caps, mandatory patterns, banned patterns
3. [HEARTBEAT and PARTIAL Protocols](#3-heartbeat-and-partial-protocols) — prompt snippets for Medium/Heavy agents
4. [Wave Execution](#4-wave-execution) — topological DAG scheduling, opt-in rules, when NOT to use waves
5. [Model and Context Inheritance](#5-model-and-context-inheritance) — the `[1m]` trap, resolution order, env override
6. [Reviewer Checklist Summary](#6-reviewer-checklist-summary) — what sprint-review flags as BLOCKERs

---

## 1. Subagent Type Selection

Source: [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) — verified 2026-04-16.

### Built-in Claude Code Subagent Types

| Name | Purpose | Tools (CAN use) | Tools (CANNOT use) | Default Model |
|---|---|---|---|---|
| **Explore** | Fast, read-only codebase search | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Haiku |
| **Plan** | Plan-mode pre-flight research | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Inherits |
| **general-purpose** | Complex multi-step tasks requiring read + write | All tools (`*`) | None | Inherits |
| **statusline-setup** | Configure status line via `/statusline` | Read, Edit only | N/A | Sonnet |
| **claude-code-guide** | Answer Claude Code meta-questions | Read, Grep, Glob, WebFetch, WebSearch | Write, Edit, Agent | Haiku |

**Anthropic's guidance**:
> *Explore*: "A fast, read-only agent optimized for searching and analyzing codebases."
> *general-purpose*: "Claude delegates to general-purpose when the task requires both exploration and modification, complex reasoning to interpret results, or multiple dependent steps."

`statusline-setup` and `claude-code-guide` are auto-invoked by the harness. Do not select them directly in skill spawns.

### Blitz Plugin Agents

Source: `agents/` directory. Verified 2026-04-16.

| Agent | Tools | Read-Only? | Default Model | Specialty |
|---|---|---|---|---|
| `blitz:architect` | Read, Glob, Grep, Bash | **YES (strictly)** | sonnet | Structural analysis, dependency graphs |
| `blitz:reviewer` | Read, **Write**, Bash, Glob, Grep | No (Write for findings only) | sonnet | Code quality/security review with written findings |
| `blitz:doc-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Documentation generation |
| `blitz:backend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Cloud Functions, Zod, Firestore |
| `blitz:frontend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Vue 3 / Pinia implementation |
| `blitz:test-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Unit / integration / E2E tests |

**Foot-gun**: `blitz:architect` is strictly read-only. If a spawn site expects `architect` to write findings files, the orchestrator must write them from the agent's text return — same failure mode as Explore.

**Plugin-agent caveat**: `permissionMode`, `hooks`, and `mcpServers` frontmatter are silently ignored for plugin agents. If you need those fields, copy the agent file to `~/.claude/agents/`.

### Decision Matrix

| Task type | Recommended subagent_type | Rationale |
|---|---|---|
| Read-only codebase search, findings returned as text | `Explore` | Fast Haiku, no write needed |
| **Research that MUST write findings to a file** | **`general-purpose`** | **Explore cannot Write. Never rely on heuristic defaults for write-required work.** |
| Focused grep/glob for a specific pattern | `Explore` | Fast, single-purpose |
| Web research + file writing | `general-purpose` | Has WebSearch + Write |
| Implementation (edit source files) | `blitz:backend-dev` / `blitz:frontend-dev` / `blitz:test-writer` | Role-specific conventions baked into the agent |
| Documentation writing | `blitz:doc-writer` | Designed for docs output |
| Code review with written findings | `blitz:reviewer` | Write for findings; cannot modify source |
| Architecture analysis with written report | `general-purpose` | `blitz:architect` is read-only — orchestrator must write report from agent text, OR spawn a `general-purpose` agent instead |

**Rule of thumb**: if the agent needs to call `Write` or `Edit`, it MUST be `general-purpose` or a `blitz:<role>` agent with Write in its tool list. Anything else will silently fail.

### Foot-Guns

1. **Explore picked for write-required work** — the bug that motivated v1.2.0. Always specify `subagent_type` explicitly when writes are required.
2. **`blitz:architect` is read-only despite its name** — use `general-purpose` if analysis must produce a file.
3. **Plugin-agent `permissionMode` is silently ignored** — use `.claude/agents/` (not plugin dirs) if you need that field.
4. **Haiku quality ceiling on Explore** — complex reasoning tasks may produce poor results. Use `general-purpose` with `model: sonnet` for nuanced analysis.
5. **`TeamCreate`+`SendMessage` does not accept `subagent_type`** — the SDK picks by heuristic. Use the `Agent` tool instead (v1.4.0 migrated all spawning skills to this).
6. **Model inheritance propagates `[1m]`** — v1.1.3 crashed a Sonnet-declared skill invoked from a 1M parent. Declare explicit `model:` without `[1m]`.

---

## 2. Workload Sizing

**Why**: In April 2026, a reliability audit found that blitz skills lost tokens repeatedly because several spawn sites declared zero caps on file reads, web searches, output length, or turns. Since Claude Code now caps server-side tool calls at ~20 per turn (Feb 2026 regression) and all tokens are billed regardless of outcome, unbounded agents routinely failed silently mid-work. Weight classes and mandatory patterns follow.

### Weight Class Table

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

### Mandatory Patterns by Class

**Light class**
- Output-file existence check: the orchestrator MUST validate that the agent's expected output file exists and is non-empty before consuming the result.

**Medium class** — Light + these:
- Write-as-you-go: agent prompt must instruct the agent to write findings to the output file incrementally, not accumulate in memory. Stub the file at start.
- Wall-clock timeout in prompt: state the 5-minute budget explicitly so the agent self-paces.
- HEARTBEAT markers (see section 3) — recommended, not strict requirement.

**Heavy class** — Medium + these:
- HEARTBEAT markers: agent writes `HEARTBEAT: <phase-name> at <ISO-timestamp>` at the start of each phase (at least 3 phases).
- PARTIAL return format: agent emits a PARTIAL block when approaching the turn limit.
- Turn-budget declaration: agent prompt explicitly states `You have a budget of 40 tool calls. After 35, stop and write PARTIAL.`

### Banned Patterns

These produce zero-output failures with full token cost. They are BLOCKERs in sprint-review.

1. **Unbounded file set** — prompts saying "read all files", "scan the entire codebase", or passing an unlimited file list.
2. **Unbounded diff / input** — passing "the entire sprint diff" or "the whole PR" to reviewer agents without size caps.
3. **"Write the full document at the end, not incrementally"** — guarantees zero output on timeout. (Exception: code-sweep tier agents writing a single JSON array are a structural exception where the array IS the incremental payload; scope already capped by tier.)
4. **Orchestrator reads agent output with no existence check** — proceeds on missing/empty files and silently produces degraded results.
5. **Retry without narrowing scope** — retrying the exact same prompt after `error_max_turns` burns tokens identically. Narrow the scope, or do not retry.

### Fail-Fast Rationale

All tokens are billed regardless of task outcome. No refunds for `error_max_turns`, `error_max_budget_usd`, `error_during_execution`, or context-exhaustion. Documented incidents: one auto-compact loop burned 695M cache-read tokens (anthropics/claude-code#22758); one output-file loop wrote 359 GB (#29557). Subagent overhead is ~7× vs single-session for equivalent work.

**Therefore**: prefer hard caps that fail fast over permissive caps that try to salvage. Set `max_turns` and `max_budget_usd` in the SDK when available. Never retry without narrowing scope. HEARTBEAT and PARTIAL are secondary safety — the first-order fix is bounding the workload so it fits in a single agent's budget.

### Orchestrator-Side Validation

Every skill that spawns agents MUST include this check before consuming agent output:

```bash
for f in ${SESSION_TMP_DIR}/<expected-outputs>.md; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # Log to .cc-sessions/activity-feed.jsonl
  fi
done

# Skill-specific threshold (e.g., abort if MISSING_COUNT >= 2 of 4)
if [ "$MISSING_COUNT" -ge "$FAIL_THRESHOLD" ]; then
  echo "Aborting: too many agents failed to produce output"
  exit 1
fi
```

---

## 3. HEARTBEAT and PARTIAL Protocols

### HEARTBEAT — mid-run liveness signal

Add this block verbatim to Medium (optional) and Heavy (required) agent prompts:

```
HEARTBEAT PROTOCOL:
At the start of each phase, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats across your task. Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ`
to produce the timestamp.
```

**Orchestrator consumption**: count HEARTBEAT lines during polling. A file with 2+ heartbeats but no final result is partially-alive; a file with 0 heartbeats after wall-clock expiry is presumed dead.

### PARTIAL — graceful degradation on budget exhaustion

Add this block verbatim to Heavy (required) agent prompts:

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
- Cross-reference `MISSING` against the expected deliverable list. Flag known-required sections that landed in MISSING.
- For narrow retry: re-spawn ONLY on items in the MISSING list, not the full task.

---

## 4. Wave Execution

A **wave** is a topological layer of a dependency DAG: maximal set of work units whose declared prerequisites are satisfied by prior waves, enabling parallelism within each wave.

### Gate: Do You Actually Have a DAG?

**Waves deliver value only when there is a directed dependency graph between units of work.** Before adopting:

- Do your work units have declared `depends_on: [<id>...]` fields?
- Are any of those dependencies non-trivial (i.e., unit B actually cannot start until unit A finishes)?

**If no**: your work is a flat pool of independent units. Do NOT adopt waves. Run a simple parallel spawn with a polling completion check. Examples of flat pools in blitz: `codebase-audit` (10 independent pillars), `research` (2-4 independent investigators), `sprint-plan` (parallel researchers), `codebase-map` (4 independent dimensions), `integration-check` (3 domain agents).

**If yes**: waves are appropriate.

**Current adopters**: `sprint-dev` (story DAG from `depends_on` fields).

**Potential future adopters**: `roadmap` Phase 7 (foundation epics before feature epics — weak case; optional).

### Dependency Resolution Algorithm

**Input**: work units with optional `depends_on: [<id>...]` field.

**Algorithm** (Kahn's topological sort layered):
1. Compute in-degree for each unit from the `depends_on` edges.
2. **Wave 0**: all units with in-degree 0.
3. **Wave N**: all units whose dependencies are ALL in Waves 0..N-1.
4. Continue until all units are assigned to a wave.

**Invalid**: a cycle causes some units to never reach in-degree 0. Hard-fail with a cycle report. Do not attempt partial execution.

**Critical path**: the longest dependency chain determines the minimum wave count.

### Size Caps

**No built-in size cap.** The calling skill decides how many parallel agents are available per wave. If a single wave exceeds available slots, sub-batch within the wave using a caller-specified priority ordering. `sprint-dev` uses: `schema/type > server > store > component > test`.

### Worker Pool Semantics

- **Within a wave**: all units may execute in parallel.
- **Between waves**: no unit in Wave N may start until all units in Wave N-1 are complete (or explicitly skipped with documented reason).
- **Completion polling**: orchestrator polls completion via `TaskList`, not sleep-wait. Output-file existence checks (Section 2) confirm each unit actually wrote its deliverable.

### Progress Reporting Hooks

- **Wave start**: print wave number, size, unit ids starting.
- **Unit completion**: update tracker; check wave-complete condition.
- **Wave completion**: emit Wave Progress per [verbose-progress.md](verbose-progress.md); write checkpoint per [checkpoint-protocol.md](checkpoint-protocol.md); commit + push (`<type>(<skill>): wave N complete`).

### Checkpoint Behavior

Wave boundaries are the natural pause points:
- **`autonomous`**: no user pause; commit + push only.
- **`checkpoint`**: pause after wave completion; present results; await confirmation.
- **`interactive`**: per-unit confirmation; waves still computed but control at unit granularity.

STATE.md must include a Wave Progress table when a skill uses waves (schema in [checkpoint-protocol.md](checkpoint-protocol.md)).

### Opting In

1. Declare a dependency graph on your work units.
2. Compute waves via the algorithm above.
3. Reference this doc's Wave section in your Additional Resources.
4. Implement the progress hooks above.
5. Add a Wave Progress table to your STATE.md schema if you use checkpointing.

### Risks (do not use waves if)

- **Cargo-cult adoption**: future authors reach for waves as a "standard pattern" without a real DAG. The Gate section is the guard.
- **Soft dependencies**: if dependencies are informational (e.g., "it would be nice if backend review saw security first"), the bookkeeping cost exceeds the scheduling benefit. Leave such cases as flat pools.

---

## 5. Model and Context Inheritance

Resolution order (highest priority first):
1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
2. Per-invocation `model` parameter (Agent tool argument)
3. Subagent definition's `model:` frontmatter
4. Main conversation's model (inheritance default)

**Default is `inherit`** — including `[1m]` flags. A Sonnet-declared subagent invoked from an Opus `[1m]` parent inherits `[1m]` too, then crashes at load because Sonnet 4.6 requires `/extra-usage` for 1M.

**To force a specific model without `[1m]`**: set explicit `model: sonnet` / `model: opus` (no `[1m]`) in the subagent frontmatter or the Agent tool call.

**To override globally**: `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` forces all subagents regardless of frontmatter.

**Subagents cannot spawn subagents**: the harness prevents infinite nesting. Chain from the main conversation, not from within another subagent.

**Subagents do not inherit skills**: list any required skills explicitly in the subagent definition's `skills:` frontmatter field.

---

## 6. Reviewer Checklist Summary

Sprint-review (`/blitz:sprint-review`) must flag these as BLOCKERs on any new or modified agent-spawn site:

- [ ] `subagent_type` declared explicitly at every spawn (no heuristic fallback)
- [ ] Weight class declared (Light / Medium / Heavy) in the prompt template
- [ ] Mandatory patterns present for the declared class:
  - Light: output-file existence check
  - Medium: + write-as-you-go + wall-clock timeout in prompt
  - Heavy: + HEARTBEAT + PARTIAL + turn-budget declaration
- [ ] None of the banned patterns used (unbounded files, unbounded diff, write-at-end)
- [ ] Orchestrator validates output file exists and is non-empty before consuming
- [ ] Model declared explicitly (not relying on inheritance) if the skill is invokable from `[1m]` parents

Absence of any item is a BLOCKER, not a suggestion.

---

## How to Reference This Doc

Every blitz skill that spawns subagents should add to its Additional Resources block:

```markdown
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
```

---

## Related Protocols

- [session-protocol.md](session-protocol.md) — session IDs, locking, activity feed
- [checkpoint-protocol.md](checkpoint-protocol.md) — STATE.md schema for resumable orchestrators
- [verbose-progress.md](verbose-progress.md) — progress reporting conventions
- [context-management.md](context-management.md) — context window hygiene
- [deviation-protocol.md](deviation-protocol.md) — agent escalation handling
- [definition-of-done.md](definition-of-done.md) — quality gate standards

## Historical Reference

This doc merges three previously separate files (v1.4.0 consolidation):
- `subagent-types.md` → Section 1 + 5
- `agent-workload-sizing.md` → Sections 2 + 3
- `waves.md` → Section 4

The corresponding research docs remain in `docs/_research/`:
- `2026-04-16_subagent-type-selection.md`
- `2026-04-16_agent-reliability.md`
- `2026-04-16_plugin-agent-strategy.md`
