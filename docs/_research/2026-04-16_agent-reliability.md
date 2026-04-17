---
scope:
  - id: cf-2026-04-16-agent-workload-limits
    unit: skills
    target: 6
    description: |
      Apply the agent-workload-sizing heuristic (Light/Medium/Heavy class
      with defined caps on file reads, web searches, output lines, wall-
      clock timeout, and model) to every agent spawn site in the six
      skills currently at HIGH or CRITICAL reliability risk: sprint-plan,
      sprint-review, sprint-dev, doc-gen, roadmap, fix-issue. Each spawn
      site must declare explicit caps and write-as-you-go unless the
      agent is Light class.
    acceptance:
      - grep_present:
          pattern: 'max.*files|max.*reads|max_turns|max tool calls'
          path: 'skills/sprint-plan/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'max.*files|max.*reads|max_turns|max tool calls'
          path: 'skills/sprint-review/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'write.*as.*you.*go|write.*immediately|incremental'
          path: 'skills/sprint-plan/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'wall-clock|timeout'
          path: 'skills/sprint-review/SKILL.md'
          min: 1
  - id: cf-2026-04-16-agent-workload-sizing-doc
    unit: files
    target: 1
    description: |
      Create skills/_shared/agent-workload-sizing.md. Must include: the
      Light/Medium/Heavy weight class table (file reads, web searches,
      tool calls, output lines, timeout, model); mandatory patterns per
      weight class (write-as-you-go, HEARTBEAT, PARTIAL, output-file
      existence check); the four banned patterns (unbounded files,
      unbounded diff, "write full document at end", no retry defined);
      and the fail-fast rationale (all tokens billed regardless of
      outcome).
    acceptance:
      - shell: 'test -f skills/_shared/agent-workload-sizing.md'
      - grep_present:
          pattern: 'Light|Medium|Heavy'
          path: 'skills/_shared/agent-workload-sizing.md'
          min: 3
      - grep_present:
          pattern: 'HEARTBEAT|PARTIAL'
          path: 'skills/_shared/agent-workload-sizing.md'
          min: 2
  - id: cf-2026-04-16-silent-failure-fixes
    unit: sites
    target: 4
    description: |
      Fix the four silent-failure sites where the orchestrator proceeds
      without validating that spawned agents produced output:
      sprint-plan Phase 2.4, sprint-review Phase 2.6, roadmap Phases 5
      and 7, and fix-issue Phase 1.4. Each site must (a) poll for file
      existence and non-empty size, (b) warn or abort on missing output,
      (c) log the failure mode to the activity feed.
    acceptance:
      - grep_present:
          pattern: '-s.*\$.*\.md|test -s'
          path: 'skills/sprint-plan/SKILL.md'
          min: 1
      - grep_present:
          pattern: '-s.*\$.*\.md|test -s'
          path: 'skills/sprint-review/SKILL.md'
          min: 1
      - grep_present:
          pattern: '-s.*\$.*\.md|test -s'
          path: 'skills/fix-issue/SKILL.md'
          min: 1
---

# Agent Reliability — Research 2026-04-16

## Summary

Blitz skills are hemorrhaging tokens on agents that time out or return nothing because four root causes recur across the suite: (1) **unbounded workloads** — sprint-plan's 4 research agents, sprint-review's 4 reviewers, sprint-dev's dev agents, and doc-gen's 4 doc agents declare zero caps on file reads, web searches, output length, or turns, even though Claude Code now caps tool calls per turn at ~20 (a Feb 2026 regression); (2) **no write-as-you-go** in sprint-plan, sprint-review, sprint-dev, or doc-gen (doc-gen actively forbids it) — meaning any interruption produces zero usable output rather than partial findings; (3) **missing validation** — four orchestrator sites (sprint-plan 2.4, sprint-review 2.6, roadmap 5/7, fix-issue 1.4) proceed without checking that their spawned agents actually wrote the expected output file, silently producing degraded results; (4) **no HEARTBEAT / PARTIAL / turn-budget patterns anywhere** in the codebase, so the orchestrator cannot distinguish "agent stalled at 90%" from "agent dead from the start." Since all tokens are billed regardless of outcome and there are no refunds, the fix must lean **fail-fast** over salvage: define a Light/Medium/Heavy workload-sizing heuristic, ban unbounded spawns, and require orchestrator-side output validation before consuming agent results.

## Research Questions

1. **What are the documented failure modes of Claude Code subagents, and how often do they hit?**
2. **What numerical ceilings constrain subagent work, and what can the orchestrator observe while agents run?**
3. **Which blitz spawn sites have dangerous workload configurations today?**
4. **What defensive patterns would most directly eliminate the "tokens spent, nothing returned" failure class?**
5. **How should blitz codify "proper workload per agent" so skill authors can't regress?**

## Findings

### 1. Failure modes — 11 documented; 6 hit blitz today

| # | Failure | Symptom | Root cause | Frequency |
|---|---|---|---|---|
| 1 | Timeout / stream idle | `error_during_execution`; partial/no output | >5 min no data; retry added in v2.1.105 | Common |
| 2 | Context window exhaustion | Auto-compaction loop; output truncated | 200K cap on standard plans | Common in long research |
| 3 | Stall / sleep | Agent hangs indefinitely | Heartbeat lost during long action (issue #25068) | Moderate |
| 4 | Infinite loop | Extreme token burn — one case: 695M cache-read tokens (#22758); another: 359 GB temp file (#29557) | No exit condition on retry | Low frequency, catastrophic cost |
| 5 | Partial return (`error_max_turns`) | `result` field absent | `max_turns` hit before done | **Common without explicit cap** |
| 6 | Permission block (silent) | Agent believes write succeeded; nothing written | Subagent Task tool lost write ability (regression #13890) | Moderate |
| 7 | Per-turn tool call cap | `stop_reason: "pause_turn"` after ~20 calls | Server-side loop default: 10 iters / ~20 calls | **Common since Feb 2026 regression (#33969)** |
| 8 | Output token cap | Response truncated at 32K | Hardcoded; `CLAUDE_CODE_MAX_OUTPUT_TOKENS` ignored in subagents (#25569, #10738) | Common for large-file writers |
| 9 | Output format miss | No file; findings as inline text | Agent returned text instead of Write call | Common without enforcement |
| 10 | Orchestrator blindness | Generic failure string; parent hallucinates | No diagnostic context propagated (#25818) | Common |
| 11 | Permission approval hang | Subagent stalls on approval | Background agent requests edit approval silently | Low, unrecoverable without restart |

### 2. Numerical ceilings (April 2026)

| Limit | Default | Configurable? |
|---|---|---|
| max_turns | **No limit** | Yes — `max_turns` / `maxTurns` |
| max_budget | No limit | Yes — `max_budget_usd` |
| Per-turn tool calls | **~20 (server cap)** | **No** |
| Context window | 200K (standard) / 500K (Enterprise) / 1M (Sonnet/Opus 4.6) | No |
| Subagent output | **32K hard cap** | **No — env var ignored in subagents** |
| Stream idle | 5 min (retry in v2.1.105+) | Unknown |
| Auto-compact trigger | ~80% fill | No |

**Key gap observable by orchestrator**: no mid-run token-usage signal. Only post-completion via `ResultMessage`, or via output-file heartbeats the agent writes itself.

### 3. Blitz workload audit — 2 CRITICAL, 4 HIGH, 4 MEDIUM, 1 LOW

| Skill | Agents | Risk | Why |
|---|---|---|---|
| `sprint-plan` | 3 of 4 (domain/library/infra) | **CRITICAL** | Zero caps on any dimension + no write-as-you-go |
| `sprint-dev` | ui-integrator (Phase 3.5.1) | **CRITICAL** | No caps, no write-as-you-go, no fallback |
| `sprint-plan` | codebase-analyst | HIGH | No caps; implicit write-as-you-go only |
| `sprint-review` | all 4 reviewers | HIGH | Full sprint diff passed unbounded; no cap on diff size |
| `sprint-dev` | backend/frontend/test-writer | HIGH | Zero caps; circuit-breaker is story-level, not token/time |
| `doc-gen` | 3 of 4 | HIGH | Explicit "write full document, not incremental" (SKILL.md:207) |
| `roadmap` | Phases 5 & 7 agents | HIGH | Caps not stated; write-as-you-go is for orchestrator only |
| `doc-gen` | doc-changelog | MEDIUM | Same, but lower volume |
| `fix-issue` | research subagent | MEDIUM | 5-search cap only; writes at end |
| `research` | all 4 | MEDIUM | Caps present; no retry defined |
| `codebase-audit` | all 10 | MEDIUM | File caps + write-as-you-go; no turn/output cap |
| `code-sweep` | tier agents | **LOW** | Model explicit; bounded file set; JSON output; proceed-with-succeeded fallback |

**Root cause of the pain**: sprint-dev dev agents have zero caps — a 6-story backend-dev agent doing 5 reads + 3 writes + 1 verify per story = 54 tool calls minimum, well past the ~20/turn server cap with no circuit break on wall clock. sprint-review's unbounded diff pass is the second-biggest risk — a 40+ file sprint produces thousands of lines of diff × 4 reviewers.

### 4. Defensive patterns — 5 present, 3 absent everywhere

| Pattern | Status | Where |
|---|---|---|
| Write-as-you-go | Partial | present: research, codebase-audit, roadmap orchestrator. missing: sprint-plan, sprint-review, sprint-dev, fix-issue. **explicitly forbidden**: doc-gen (SKILL.md:207) |
| Wall-clock timeout declared | Partial | present: research (3 min), codebase-audit (5 min), doc-gen (5 min). missing: sprint-plan, sprint-review, sprint-dev, roadmap, fix-issue |
| Output-file existence check | Partial | present: research, codebase-audit, doc-gen. missing: sprint-plan, sprint-review, sprint-dev, roadmap, fix-issue |
| Retry-with-narrower-scope | Partial | present: sprint-plan (once), sprint-review (once). missing elsewhere; research explicitly no-retry |
| Fallback to inline when agent fails | Partial | present: sprint-dev (orchestrator handles story), codebase-audit (proceeds with available). missing elsewhere |
| **HEARTBEAT markers** | **ABSENT EVERYWHERE** | No skill instructs agents to emit periodic markers |
| **PARTIAL return format** | **ABSENT EVERYWHERE** | No agent prompt defines a PARTIAL block for graceful degradation |
| **Turn-budget declarations** | **ABSENT EVERYWHERE** | No skill sets `max_turns` or declares a turn budget in-prompt |

### 5. Silent orchestrator-failure sites

Four places where the orchestrator proceeds after agents run without validating that they actually produced output:

| Site | Failure mode | Impact |
|---|---|---|
| sprint-plan Phase 2.4 | No poll loop; retry-once then proceed | Proceeds to story generation with half the research; user sees a sprint plan with domain gaps |
| sprint-review Phase 2.6 | No output-file check after spawn | Review report silently missing a domain (e.g., security analysis absent from the final report) |
| roadmap Phases 5 & 7 | No output validation documented | Domain specs/epics silently absent from the roadmap |
| fix-issue Phase 1.4 | Orchestrator reads `issue-research.md` with no existence check | Root-cause analysis built on missing/empty research → incorrect fix |

### 6. Cost-of-failure economics

- **All tokens billed** regardless of outcome — no refund for timeouts, context exhaustion, or `error_max_turns`.
- `ResultMessage.total_cost_usd` reflects actual charges even on `error_*` subtypes.
- Subagent overhead: community reports ~7× token multiplier vs single-session for equivalent work.
- The 695M-token auto-compact loop (#22758) and 359 GB output-file loop (#29557) illustrate the catastrophic-cost tail risk.

**Implication**: mitigation must favor **fail-fast** over salvage. Set hard caps (`max_turns`, file-read caps, wall-clock timeout) to bound the blast radius. Salvaging partial work via HEARTBEAT/PARTIAL is secondary — important, but not the first-order fix.

## Compatibility Analysis

All proposed fixes are compatible with existing blitz architecture:

- **Adding caps to SKILL.md prompts** is a text change. No schema changes, no new dependencies.
- **New `skills/_shared/agent-workload-sizing.md`** follows the established shared-doc pattern (session-protocol.md, checkpoint-protocol.md, verbose-progress.md, context-management.md, subagent-types.md from the prior research).
- **Output-file validation** uses existing Bash patterns (`[ -s "$file" ]`) already in use by research and codebase-audit skills.
- **No external tool dependencies**: the patterns require only prompt text changes + orchestrator Bash checks. No new MCP servers or SDK flags.

**Interaction with prior research**:
- `docs/_research/2026-04-16_plugin-agent-strategy.md` proposed refactoring codebase-map, integration-check, quality-metrics to parallel workers. Those refactors must adopt this workload-sizing guidance on day one.
- `docs/_research/2026-04-16_subagent-type-selection.md` is a prerequisite — an agent with no Write capability cannot write-as-you-go regardless of how the prompt is worded. Ship the subagent-type fixes first.

## Recommendation

**Ship four bundled changes as v1.2.x patch series (independent of other in-flight work):**

1. **Create `skills/_shared/agent-workload-sizing.md`** — the authoritative guidance doc defining Light/Medium/Heavy weight classes with hard caps, mandatory defensive patterns, and banned patterns.
2. **Fix the 4 silent-failure sites** (sprint-plan 2.4, sprint-review 2.6, roadmap 5/7, fix-issue 1.4) with output-file existence checks and explicit N-of-M failure handling.
3. **Apply workload caps** to the 6 at-risk skills (sprint-plan, sprint-review, sprint-dev, doc-gen, roadmap, fix-issue) using the heuristic table. Add write-as-you-go to every Medium/Heavy agent.
4. **Introduce HEARTBEAT + PARTIAL protocol** — add to agent prompt templates across the suite, starting with the HIGH-risk skills. Orchestrator reads the output file partway through and after timeout to salvage partial work.

**Sequencing**: ship #1 + #2 first as a bug-fix patch (v1.2.0 — addresses the immediate "tokens spent, nothing returned" pain). Ship #3 + #4 as v1.3.0 once the sizing doc is stable and reviewer checklist updates have caught drift.

**Rationale**: these fixes are text-only changes with zero code risk. The economic argument is decisive — every run of sprint-plan or sprint-review today has a non-trivial chance of producing a degraded result while billing full tokens. Fixing the four silent-failure sites alone will eliminate the worst "paid but got nothing" cases.

## Implementation Sketch

### A. `skills/_shared/agent-workload-sizing.md`

Structure (≤200 lines):

1. **Purpose** — one paragraph on why this doc exists; reference the 2026-04-16 reliability research.
2. **Weight Class Table**:

| Class | Use case | Max file reads | Max web searches | Max tool calls | Max output | Wall-clock | Model |
|---|---|---|---|---|---|---|---|
| Light | Single-focus analysis; pattern check; library summary | 8 | 5 | 15 | 150 ln | 3 min | sonnet |
| Medium | Multi-file synthesis; feature review; epic analysis | 15 | 8 | 25 | 250 ln | 5 min | sonnet |
| Heavy | Implementation; multi-story worktree; full-pillar audit | 25 | 0 | 40 | 400 ln | 8 min | opus orchestrator / sonnet workers |

3. **Mandatory patterns by class**:
   - Light: output-file existence check after spawn
   - Medium: + write-as-you-go; + wall-clock timeout in prompt
   - Heavy: + HEARTBEAT markers every 3 tool calls; + PARTIAL return format; + turn-budget declaration in prompt
4. **Banned patterns**:
   - Unbounded file set ("all files", "entire codebase")
   - Unbounded diff pass ("entire sprint diff to 4 reviewers")
   - "Write the full document at the end, not incrementally"
   - Orchestrator reads agent output with no existence check
5. **HEARTBEAT + PARTIAL protocol specs** (prompt snippets).
6. **Fail-fast rationale** — all tokens billed; no refunds; catastrophic-cost tail risk.

### B. Four silent-failure-site fixes

**sprint-plan Phase 2.4** — add:
```bash
for f in ${SESSION_TMP_DIR}/sprint-${N}-research-*.md; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    # log to activity feed
    MISSING_COUNT=$((MISSING_COUNT+1))
  fi
done
# Abort if MISSING_COUNT >= 2, else proceed with warning
```

**sprint-review Phase 2.6** — same pattern for `sprint-${N}-review-*.md`.

**roadmap Phases 5 & 7** — add per-domain existence check before synthesis.

**fix-issue Phase 1.4** — verify `issue-research.md` exists and is >100 bytes before calling the root-cause step.

### C. Apply workload caps to 6 at-risk skills

**Example — sprint-plan reference.md:285 `domain-researcher` prompt**:

```diff
 You are domain-researcher, a research agent...
+
+BUDGET:
+- Max file reads: 8
+- Max web searches: 5
+- Max tool calls: 15 (if you hit 12, stop and write PARTIAL)
+- Max output: 200 lines
+- Wall-clock: 4 min
+
+WRITE-AS-YOU-GO: After each epic analyzed, append to your output file.
+Your task is INCOMPLETE if <output-path> does not exist.
```

**Example — sprint-review Phase 2.3 reviewer spawn**:

```diff
-Spawn 4 reviewers with the full sprint diff.
+For each reviewer, slice the sprint diff by domain (max 500 lines of diff
+per reviewer). Pass:
+- Diff slice (≤500 ln)
+- Max 15 file reads
+- Max 25 tool calls
+- Max 300 lines output
+- 5-min wall clock
+- Write each finding to output file immediately after identifying it
```

### D. HEARTBEAT + PARTIAL templates

**Prompt snippet all Medium/Heavy agents must include**:

```
HEARTBEAT PROTOCOL:
At the start of each phase, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats across your task.

PARTIAL DEGRADATION:
If you have 3 or fewer tool calls remaining (or detect approaching the
turn limit), STOP and append this block to the output file:
  PARTIAL: true
  COMPLETED: [list of sections finished]
  MISSING: [list of sections skipped]
  CONFIDENCE: low|medium|high
Then write a one-line confirmation and end.
```

**Orchestrator consumption**:
- If PARTIAL: true is present, treat as partial success; warn user; attempt narrow retry on MISSING sections only.
- Count HEARTBEAT lines as a liveness signal during polling.

## Risks

- **Prompt length grows**: adding BUDGET + WRITE-AS-YOU-GO + HEARTBEAT + PARTIAL sections to every agent prompt adds ~40 lines per prompt. For agents that already have 100-line prompts (sprint-dev dev agents), this pushes prompt size up further. Mitigation: extract the common blocks into reusable snippets in the workload-sizing doc and use `!` includes or templated text to keep SKILL.md DRY.
- **PARTIAL being trusted**: an agent claiming `PARTIAL: true CONFIDENCE: high` but having missed a critical domain is a false positive. Mitigation: orchestrator always cross-references PARTIAL against the expected deliverable list and warns when known-required sections are in the MISSING list.
- **Caps may be too tight for large projects**: 15 file reads may not be enough for a Medium task on a 2000-file monorepo. Mitigation: weight classes are defaults; skills can override with documented rationale in their SKILL.md.
- **Retries still burn tokens**: narrow-retry on failure doubles cost on already-failed agents. Mitigation: retry only when the failure mode suggests recovery is possible (PARTIAL with low confidence, missing output file) — do not retry on `error_max_turns` or `error_max_budget_usd` without reducing scope.
- **Server-side 20-tool-call-per-turn cap is outside our control** (#33969). Agents asked to do >20 calls in a single turn will fail regardless of prompt engineering. Mitigation: design agents for ≤15 tool calls to leave headroom, and break up Heavy workloads into multiple agents rather than single bloated ones.
- **HEARTBEAT adds token cost per phase** — each heartbeat line is ~40 tokens. For 10-phase workflows with 4 agents this is 1600 tokens of ops overhead. Mitigation: acceptable cost vs the alternative (zero output from a timed-out agent). Don't add heartbeats to Light class.

## References

### Authoritative docs
- https://code.claude.com/docs/en/agent-sdk/agent-loop — max_turns, max_budget_usd
- https://code.claude.com/docs/en/sub-agents — subagent isolation and output behavior
- https://code.claude.com/docs/en/best-practices
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — subagent 1K-2K token return pattern

### GitHub issues cited
- anthropics/claude-code#22758 — 695M-token auto-compact loop
- anthropics/claude-code#25569 / #10738 — subagent 32K output cap, env var ignored
- anthropics/claude-code#13890 — subagent write/MCP regression
- anthropics/claude-code#25818 — orchestrator blindness on subagent failure
- anthropics/claude-code#33969 — per-turn tool call cap regression (~20 from 60-80)
- anthropics/claude-code#25068 — 30-min stalls requiring keypress
- anthropics/claude-code#7091 — permission approval hang
- anthropics/claude-code#29557 — 359 GB output-file loop

### Community patterns
- https://github.com/disler/claude-code-hooks-multi-agent-observability
- https://github.com/simple10/agents-observe
- https://alirezarezvani.medium.com/claude-code-rewind-5-patterns-after-a-3-hour-disaster-a9de9bce0372

### Blitz source
- `skills/research/SKILL.md:109-117,203-208,228-231` — exemplar: caps table + existence-check loop
- `skills/codebase-audit/SKILL.md:97-144` — exemplar: 10-agent spawn with caps and N-of-M threshold
- `skills/sprint-plan/reference.md:285-407` — at-risk: agent prompts with no caps
- `skills/sprint-review/SKILL.md:197-234,573` — at-risk: unbounded diff; retry-once
- `skills/sprint-dev/SKILL.md:206-245,596` — at-risk: zero-cap dev agents
- `skills/doc-gen/SKILL.md:193-225` — at-risk: "write full document, not incremental"
- `skills/fix-issue/SKILL.md:138-153` — at-risk: no output-file existence check
- `skills/code-sweep/SKILL.md:95-170` — exemplar post-v1.1.3: agent-tool, explicit model, JSON contract, fallback

### Related blitz research
- `docs/_research/2026-04-16_plugin-agent-strategy.md` — parent research on agent architecture
- `docs/_research/2026-04-16_subagent-type-selection.md` — prerequisite for write-as-you-go (agents need Write capability)

### Session artifacts
- `.cc-sessions/research-657a25ff/tmp/research/external-reliability.md`
- `.cc-sessions/research-657a25ff/tmp/research/blitz-workload-audit.md`
