# Retrospective Proposals — 2026-04-16

Based on session data from `.cc-sessions/activity-feed.jsonl` (375 entries), `.cc-sessions/*.json` (3 old completed sessions from March 2026), and git history since v1.1.2.

**Analysis period**: 2026-03-25 (earliest session JSON) to 2026-04-16 (current session).

**Primary signal**: One massive 2026-04-16 session that shipped 5 releases (v1.1.3, v1.1.4, v1.2.0, v1.2.1, v1.3.0), produced 3 research docs, and delivered 12-file-change Sprint 1 + 6-file Sprint 2a + 12-file Sprint 2b. This session dominates the dataset and most patterns below are derived from it.

---

## Patterns Identified

### Failure patterns

**F1 — Architectural fix ≠ symptom fix.** v1.1.3's Agent-based SCAN refactor for code-sweep was architecturally correct but didn't resolve the user's reported error. The skill itself inherited `[1m]` context before Phase 2 could spawn any workers, so the fix targeted work that never ran. Shipped v1.1.4 within the hour to set `model: opus` on the orchestrator — the actual symptom fix. **Lesson**: verify the fix targets the failure mode, not a related mode that seems likely.

**F2 — Explore subagent_type picked for write-required work.** During the 2026-04-16 plugin-agent-strategy research, the SDK routed 2 of 4 research agents to read-only `Explore`. Those agents couldn't write findings files, returned findings as inline text, and the orchestrator had to write the files post-hoc. Token cost paid; work duplicated. This failure drove the next research thread (subagent-type-selection) and the v1.2.0 fix.

### Efficiency patterns

**E1 — Iterative-release rhythm worked.** 5 releases in one session (v1.1.3 → v1.3.0) shipped incremental value without rework. Each release addressed one concern and left the tree in a clean, releasable state. Commit split pattern (docs first, then implementation) kept diffs readable.

**E2 — TaskCreate/TaskUpdate usage was effective.** Multi-step sprints (Sprint 1 = 12 tasks, Sprint 2a = 5, Sprint 2b = 6) were tracked with TaskCreate and consistently marked in-progress → completed. No tasks went stale.

**E3 — Skill bypass when the skill is being fixed.** Sprint 1 was executed inline rather than via `sprint-plan` + `sprint-dev` because those skills had the zero-caps workload bug being fixed. Correct pragmatic call, but reveals a gap: the plugin cannot reliably dogfood its own fix-on-itself workflows while critical bugs remain.

### Quality patterns

**Q1 — Version-sync hook caught no drift.** The v1.1.1 pre-commit version-sync script prevented version-file drift across all 5 releases this session. Hook is working as intended.

**Q2 — No revert commits.** Zero `git revert` or fixup commits across 5 releases. High-quality commit discipline this session.

**Q3 — Research docs followed the scope YAML protocol.** All 3 research docs emitted machine-readable `scope:` YAML blocks for carry-forward registry ingestion. Protocol adherence solid.

### Coverage patterns

**C1 — HEARTBEAT/PARTIAL partially rolled out.** v1.2.0 added the shared protocol; v1.2.1 inlined snippets in sprint-dev and doc-gen. The remaining agent-spawning skills (research, sprint-plan Phase 2, sprint-review, codebase-audit, roadmap Phases 5/7, and the three new parallel-worker skills in v1.3.0) reference the shared doc but don't inline the concrete HEARTBEAT/PARTIAL prompt text. Not a bug (Medium class doesn't strictly require it), but uneven adoption.

**C2 — `/blitz:setup` is beta and unvalidated.** MVP shipped in v1.3.0 but has not been run against a real CLAUDE.md file. The 10 regex patterns in `conflict-catalog.json` are untested against actual user writing styles.

**C3 — `ask` routing table coverage gap**. Only one row for the new `setup` skill; the `retrospective` skill itself has only one keyword entry. If a user says "reflect on the work so far" or "postmortem" the router won't classify it.

**C4 — Research skill picked Explore for some agents**. When I spawned research agents this session using `/blitz:research`, the skill template didn't specify `subagent_type` so the SDK heuristic picked Explore for 2 of 4. v1.2.0 added guidance to the skill but the prompt template change was minimal. The template should inline an explicit `subagent_type: general-purpose` directive in the `Agent` tool call guidance.

---

## Proposals

### Safe (auto-applicable)

### Proposal S1: Add routing keywords for retrospective and setup

- **Pattern observed**: C3 above — ask routing has thin coverage for these newer skills.
- **Proposed change**: Extend the routing row for retrospective to `"retrospective", "retro", "postmortem", "reflect", "improve plugin"` and for setup to also match `"doctor", "check claude.md", "config check", "conflict check"`.
- **File**: `skills/ask/SKILL.md`
- **Expected impact**: Better intent-to-skill mapping for natural-language requests.
- **Classification rationale**: Routing-table text edit with no effect on skill behavior. Safe.

### Proposal S2: Add agent-spawn-without-subagent_type grep pattern to code-sweep

- **Pattern observed**: F2 and C4 — the SDK picks Explore when `subagent_type` isn't specified. v1.2.0 fixed 4 at-risk skills but a future author could reintroduce the bug.
- **Proposed change**: Add a new check `missing-subagent-type` to `skills/code-sweep/reference.md` Tier 2 table. Grep: `(TeamCreate|SendMessage|Agent\()` with negative lookahead for `subagent_type` within 20 lines. Severity: high. Fixable: no.
- **File**: `skills/code-sweep/reference.md`
- **Expected impact**: Code-sweep would catch regressions on the v1.2.0 subagent-type discipline.
- **Classification rationale**: Adding a non-auto-fixable grep pattern to a reference file. No skill behavior change. Safe per the classification matrix.

### Proposal S3: Update retrospective's minimum-session check to count activity-feed entries

- **Pattern observed**: E3 and C4 — this very retrospective run found only 3 old session JSONs but the activity-feed has 375 entries of real signal from the current session. The "minimum 3 completed sessions" gate almost aborted valid analysis.
- **Proposed change**: In `skills/retrospective/SKILL.md` Phase 0.1, after counting completed session JSONs, also count distinct `task_complete` events from `.cc-sessions/activity-feed.jsonl` in the last 30 days. Sum ≥ 3 passes the gate. Note the mixed signal in the analysis report.
- **File**: `skills/retrospective/SKILL.md`
- **Expected impact**: Retrospective works on projects (like this one) that log via activity-feed rather than full session protocol.
- **Classification rationale**: Gate-logic text edit in a single skill's Phase 0. No safety-rule change. No verification-gate removal. Safe.

---

### Review Required

### Proposal R1: Inline HEARTBEAT/PARTIAL snippets across remaining Medium-class agents

- **Pattern observed**: C1 — Medium-class agents in research, sprint-plan, sprint-review, codebase-audit, roadmap, codebase-map, integration-check, quality-metrics reference the shared workload doc but don't inline the concrete HEARTBEAT/PARTIAL prompt text. Uneven adoption.
- **Proposed change**: Audit every agent prompt template across these 8 skills. For Medium-class agents (not Light), inline a HEARTBEAT block; for Heavy-class agents, also inline PARTIAL.
- **File**: 8 skill files + their reference.md siblings.
- **Expected impact**: Uniform defensive-pattern coverage; agents that would otherwise silently die produce partial output instead.
- **Classification rationale**: Modifies agent prompts in 8 skills — changes skill behavior in subtle ways. Needs user sign-off before blanket application. Per the classification matrix: "updating agent instructions" requires review.

### Proposal R2: Consider merging subagent-types.md + agent-workload-sizing.md + waves.md into `spawn-protocol.md`

- **Pattern observed**: These 3 shared docs were written together on 2026-04-16, are always referenced together in Additional Resources, and share overlapping audience (skill authors spawning agents).
- **Proposed change**: Create a single `skills/_shared/spawn-protocol.md` that composes all three, with table-of-contents sections. Delete the 3 individual files. Update all skill references.
- **Expected impact**: Fewer docs to link; easier for new authors to find everything in one place. Tradeoff: bigger single file, loses the ability to link to just one topic.
- **Classification rationale**: Touches every agent-spawning skill's Additional Resources block and removes 2 shared-doc files. Needs user decision on the tradeoff.

### Proposal R3: Migrate TeamCreate+SendMessage spawn sites to Agent tool for structural subagent_type guarantee

- **Pattern observed**: F2 and subagent-type-selection research — `TeamCreate`+`SendMessage` doesn't accept `subagent_type` as a structural parameter. The SDK picks by heuristic. v1.2.0 mitigated by adding explicit instruction to the SendMessage body, but this is advisory not structural.
- **Proposed change**: Convert agent spawns in research, sprint-plan, sprint-review, codebase-audit, roadmap Phases 5/7 from `TeamCreate`+`SendMessage` to `Agent` tool calls. Keep `TeamCreate` only if cross-agent `STEER:` messaging is actively used.
- **Expected impact**: Structural guarantee that subagents get the right type; eliminates the Explore foot-gun.
- **Classification rationale**: Phase-level changes to 5+ skills, may break STEER: cross-steering where it's used. Needs review and testing.

---

### Never Auto-Apply

### Proposal N1: Delete stale research session directories from March 2026

- **Pattern observed**: `.cc-sessions/research-*` directories from March 2026 are still present (a99d6d29, bb3c6196, carryforward-50c5cee8, d30f962b, dd4bf825, f167a932). Each has a tmp/ subdirectory that may contain stale research.
- **Proposed change**: A cleanup script that removes session directories older than 30 days.
- **Why never auto-apply**: Session data is user-owned. May represent in-progress work the user hasn't consumed. Deletion is irreversible.
- **Recommendation**: User should manually review and decide retention policy.

### Proposal N2: Consolidate agent-spawning skills into one meta-skill

- **Pattern observed**: Many skills (7+) spawn agents with similar infrastructure (team create, prompt template, output validation, findings merge).
- **Proposed change**: A meta-skill or shared `agent-spawn-wrapper.md` that every skill invokes.
- **Why never auto-apply**: Major architectural rewrite; invalidates skill autonomy; high risk of regression.
- **Recommendation**: Evaluate as a v2.0 architecture decision only after at least 6 months of current-architecture usage data.
