---
scope:
  - id: cf-2026-04-16-subagent-type-fix
    unit: skills
    target: 4
    description: |
      Specify subagent_type explicitly on every agent-spawning site in
      the four at-risk skills (research, sprint-plan, sprint-review,
      codebase-audit). Prefer converting TeamCreate+SendMessage spawns
      to the Agent tool (which accepts subagent_type directly); failing
      that, include a mandatory subagent_type: general-purpose
      instruction in each SendMessage body. Each skill must reference
      the new skills/_shared/subagent-types.md guidance doc from its
      Additional Resources block.
    acceptance:
      - grep_present:
          pattern: 'subagent_type'
          path: 'skills/research/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'subagent_type'
          path: 'skills/sprint-plan/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'subagent_type'
          path: 'skills/sprint-review/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'subagent_type'
          path: 'skills/codebase-audit/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'subagent-types.md'
          path: 'skills/research/SKILL.md'
          min: 1
  - id: cf-2026-04-16-subagent-types-shared-doc
    unit: files
    target: 1
    description: |
      Create skills/_shared/subagent-types.md as the authoritative
      guidance document for subagent type selection in blitz skills.
      Must include: the full list of built-in Claude Code subagent
      types with tool allowlists; the list of blitz plugin agents
      (agents/*.md) with their tool sets and read-only/write-capable
      status; a decision matrix mapping task type to recommended
      subagent_type; the architect-is-read-only foot-gun; and the
      model-inheritance behavior including [1m] implications.
    acceptance:
      - shell: 'test -f skills/_shared/subagent-types.md'
      - grep_present:
          pattern: 'Decision Matrix'
          path: 'skills/_shared/subagent-types.md'
          min: 1
      - grep_present:
          pattern: 'general-purpose'
          path: 'skills/_shared/subagent-types.md'
          min: 1
      - grep_present:
          pattern: 'Explore'
          path: 'skills/_shared/subagent-types.md'
          min: 1
---

# Subagent Type Selection — Research 2026-04-16

## Summary

Claude Code ships five built-in subagent types (Explore, Plan, general-purpose, statusline-setup, claude-code-guide) plus blitz's six plugin agents (architect, backend-dev, frontend-dev, test-writer, reviewer, doc-writer). The critical distinction is **write capability**: `Explore`, `Plan`, and blitz's `architect` are strictly read-only (no Write/Edit/NotebookEdit). When a skill spawns subagents via `TeamCreate`+`SendMessage` without specifying `subagent_type`, the SDK picks by heuristic and can land on `Explore`, which silently breaks any workflow that expects agents to write findings to disk — exactly the bug this project hit in the prior /blitz:research run. Four blitz skills are at risk today (`research`, `sprint-plan`, `sprint-review`, `codebase-audit`); two (`sprint-dev`, `code-sweep`) already specify subagent_type correctly. Recommendation: create `skills/_shared/subagent-types.md` as the authoritative guidance doc, and update the four at-risk skills to specify `subagent_type: general-purpose` at every spawn site.

## Research Questions

1. **What subagent types does Claude Code expose, and what can each do?**
2. **When should a blitz skill prefer Explore vs general-purpose vs a blitz plugin agent?**
3. **How should this guidance be codified so skill authors can't reproduce the Explore-for-write-work foot-gun?**
4. **Which existing blitz skills are at risk today, and what's the minimal fix?**

## Findings

### 1. Built-in Claude Code subagent types

Source: https://code.claude.com/docs/en/sub-agents (verified current 2026-04-16).

| Name | Purpose | Tools (CAN use) | Tools (CANNOT use) | Default Model | Invocation |
|---|---|---|---|---|---|
| **Explore** | Fast, read-only codebase search | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit, ExitPlanMode | Haiku | Manual or auto-delegated |
| **Plan** | Plan-mode pre-flight research | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit, ExitPlanMode | Inherits | Auto-delegated during plan mode only |
| **general-purpose** | Complex multi-step tasks requiring read + write | All tools (`*`) | None | Inherits | Manual, default fallback |
| **statusline-setup** | Configure status line via `/statusline` | Read, Edit only | N/A | Sonnet | Auto — don't invoke directly |
| **claude-code-guide** | Answer Claude Code meta-questions | Read, Grep, Glob, WebFetch, WebSearch | Write, Edit, Agent | Haiku | Auto — don't invoke directly |

**Key quote on Explore** (Anthropic docs): "A fast, read-only agent optimized for searching and analyzing codebases... Claude delegates to Explore when it needs to search or understand a codebase without making changes."

**Key quote on general-purpose**: "Claude delegates to general-purpose when the task requires both exploration and modification, complex reasoning to interpret results, or multiple dependent steps."

**Explore is Haiku**: complex analytical tasks may produce poor results compared to Sonnet/Opus. For nuanced research, `general-purpose` with `model: sonnet` is safer.

### 2. Blitz plugin agents

Source: `/home/tom/development/blitz/agents/` (6 files verified).

| Agent | Tools | Read-Only? | Default Model | Specialty |
|---|---|---|---|---|
| `architect` | Read, Glob, Grep, Bash | **YES** (strictly) | sonnet | Structural analysis, dependency graphs |
| `reviewer` | Read, **Write**, Bash, Glob, Grep | No (Write for findings only) | sonnet | Code quality/security review with written findings |
| `doc-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Documentation generation |
| `backend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Cloud Functions, Zod, Firestore |
| `frontend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Vue 3 / Pinia implementation |
| `test-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Unit / integration / E2E tests |

**Foot-gun**: blitz `architect` is strictly read-only but its own description implies writing findings to `${SESSION_TMP_DIR}/architect-findings.md` — it cannot. The orchestrator must write architect findings from the agent's text return, same failure mode as Explore.

**Plugin agent caveat**: plugin agents silently ignore `permissionMode`, `hooks`, and `mcpServers` frontmatter. Those fields only work in `.claude/agents/` or `~/.claude/agents/` (outside plugin directories).

### 3. Current blitz skill usage — 4 at-risk, 2 OK

| Skill | Spawn Mechanism | `subagent_type` | Work Type | Verdict |
|---|---|---|---|---|
| `sprint-dev` | `Agent` tool | `blitz:<role>` (plugin agents) | Edit source code | **OK** |
| `code-sweep` | `Agent` tool | `general-purpose` explicit | Write findings JSON | **OK** |
| `research` | `TeamCreate`+`SendMessage` | **Not specified** | Write `.md` to tmp | **RISKY** |
| `sprint-plan` | `TeamCreate`+`SendMessage` | **Not specified** | Write `.md` to tmp | **RISKY** |
| `sprint-review` | `TeamCreate`+`SendMessage` | **Not specified** | Write `.md` to tmp | **RISKY** |
| `codebase-audit` | `TeamCreate`+`SendMessage` | **Not specified** | Write `findings/*.md` | **RISKY** |
| `roadmap` | No agent spawn | N/A | Orchestrator writes directly | OK |

**Root cause of the risk**: `TeamCreate`+`SendMessage` does not accept a `subagent_type` parameter — the SDK picks by heuristic. When agent prompts look read-only-ish (e.g., `codebase-analyst` is explicitly told "Do NOT use web search"), the heuristic biases toward `Explore`. This is exactly what produced the 2-of-4 read-only bug observed in the 2026-04-16 plugin-agent-strategy research run.

The `Agent` tool, in contrast, takes `subagent_type` as an explicit field — using it guarantees the type. This is why `sprint-dev` and (post-v1.1.3) `code-sweep` are safe.

### 4. Model and context inheritance

Resolution order (highest priority first):
1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
2. Per-invocation `model` parameter from orchestrator
3. Subagent definition's `model` frontmatter
4. Main conversation's model (inherit default)

**Default is `inherit`** — including `[1m]` flags. This is exactly the behavior that produced the v1.1.3 → v1.1.4 code-sweep crash: a Sonnet-declared skill inherited `[1m]` from the Opus parent and Sonnet 4.6 can't run 1M without `/extra-usage`.

**To force non-1M subagents**: set explicit `model: sonnet` / `model: opus` (no `[1m]`) in the subagent frontmatter, or set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` globally.

### 5. Anthropic's official guidance

Anthropic does **not** publish a "default subagent" recommendation or a spawn-vs-inline decision tree. Two quotes are relevant:

> "Use one [a subagent] when a side task would flood your main conversation with search results, logs, or file contents you won't reference again."

> "Design focused subagents: each subagent should excel at one specific task. Limit tool access: grant only necessary permissions for security and focus."

The doc pattern consistently favors **custom subagents with explicit tool allowlists** over generic types. Blitz's 6 plugin agents already follow this pattern — the gap is that the skills spawning them sometimes reach for SDK heuristics instead.

## Compatibility Analysis

All fixes proposed are compatible with the existing blitz architecture:

- **Adding `subagent_type: general-purpose` to `SendMessage` bodies or converting to `Agent` tool spawns** is a text change to existing SKILL.md files. No schema changes, no new dependencies, no model changes.
- **New `skills/_shared/subagent-types.md`** follows the established shared-doc pattern (session-protocol.md, checkpoint-protocol.md, verbose-progress.md, context-management.md, carry-forward-registry.md).
- **No frontmatter changes needed**. A `preferred-subagent-type` field was considered and rejected — a single skill can spawn agents of different types, so per-skill metadata can't capture per-spawn nuance.

**Interaction with the 2026-04-16 plugin-agent-strategy research**: this work complements cf-2026-04-16-refactor-candidates (codebase-map, integration-check, quality-metrics refactors). Those refactors should adopt the subagent-type convention from day one — specifying `subagent_type: general-purpose` on their new Agent-tool spawns.

## Recommendation

**Ship four bundled changes in a single minor release (v1.2.0 alongside the setup-skill MVP or as its own v1.2.x patch series):**

1. **Create `skills/_shared/subagent-types.md`** — authoritative guidance doc with: built-in types table, blitz plugin agents table, decision matrix, foot-gun list, model-inheritance rules.
2. **Update the four at-risk skills** to specify `subagent_type: general-purpose` at every spawn site: `research`, `sprint-plan`, `sprint-review`, `codebase-audit`. Either convert to the `Agent` tool (structural fix) or add explicit instruction to each `SendMessage` body (advisory fix). Structural fix is preferred where feasible.
3. **Link the shared doc from every spawning skill's Additional Resources** so future authors encounter the guidance during their first pass through the skill.
4. **Add a reviewer checklist item** in `skills/sprint-review/reference.md`: "Any new `TeamCreate`+`SendMessage` or `Agent` spawn must specify `subagent_type`. Absence is a BLOCKER."

**Rationale**: The fix is small (text changes to 4 SKILL.md files + 1 new shared doc), the risk is low (no code or schema changes), and the impact is high (eliminates a silent-failure class that users will otherwise keep hitting).

## Implementation Sketch

### A. Create `skills/_shared/subagent-types.md`

Structure (≤180 lines):

1. **Purpose** — one paragraph on why this doc exists.
2. **Built-in Claude Code types** — table from Finding 1.
3. **Blitz plugin agents** — table from Finding 2 with the `architect is read-only` foot-gun highlighted.
4. **Decision Matrix** — task type → recommended subagent_type:
   - Read-only codebase search returning text → `Explore`
   - Research writing findings to file → `general-purpose`
   - Edit source code → `blitz:<role>` (backend-dev / frontend-dev / test-writer)
   - Write docs → `blitz:doc-writer`
   - Code review with findings file → `blitz:reviewer`
   - Architecture analysis with report → `general-purpose` (architect is read-only)
5. **Model inheritance rules** — default is inherit; explicit `model: sonnet` prevents `[1m]` inheritance; env var override.
6. **Foot-guns** — Explore-for-write work, architect is read-only, subagents can't spawn sub-subagents, Haiku quality ceiling on Explore, skills not inherited.

### B. Update each at-risk skill

**Example for `skills/research/SKILL.md` Phase 1.2**:

```diff
-Use `TeamCreate` to create a team named `research-${TOPIC_SLUG}`.
+Use `TeamCreate` to create a team named `research-${TOPIC_SLUG}`.
+
+> **Subagent type**: All research agents must call `Write` to produce
+> findings files. Spawn with `subagent_type: general-purpose` — either
+> via the `Agent` tool (preferred) or by including an explicit
+> "You are a general-purpose agent with Write access" line in every
+> `SendMessage` body. Never rely on SDK heuristics for write-required
+> work. See [subagent-types.md](/_shared/subagent-types.md).
```

**Example for `skills/codebase-audit/SKILL.md` Phase 1.2**:

```diff
-Spawn all 10 agents using `SendMessage`. Each agent runs with `model: "sonnet"`,
-`mode: "auto"`, `run_in_background: true`.
+Spawn all 10 agents using `SendMessage`. Each agent runs with
+`model: "sonnet"`, `mode: "auto"`, `run_in_background: true`,
+**`subagent_type: general-purpose`**. Agents must Write findings
+incrementally — do NOT use `subagent_type: Explore`.
```

**Example for `skills/sprint-review/SKILL.md` Phase 2.3**:

```diff
-Spawn 3-4 specialized reviewers. Each writes findings to session-scoped temp files.
+Spawn 3-4 specialized reviewers using `subagent_type: general-purpose`.
+Each writes findings to session-scoped temp files — Write access is required.
```

Same shape applies to `skills/sprint-plan/SKILL.md` Phase 2.x research-agent spawns.

### C. Add Additional Resources line

Each of the 4 at-risk skills adds one line:

```markdown
## Additional Resources
- For subagent type selection, see [subagent-types.md](/_shared/subagent-types.md)
```

### D. Reviewer checklist update

Add to `skills/sprint-review/reference.md` review checklist:

```markdown
- [ ] Every `Agent` tool call and `SendMessage`-based spawn specifies `subagent_type`.
- [ ] Subagents that must Write files use `general-purpose` or a blitz:<role> agent with Write in its tool list.
```

## Risks

- **Switching `TeamCreate`+`SendMessage` to `Agent` tool may break existing cross-steering (`STEER:`) patterns.** The `STEER:` convention relies on sibling agents being reachable via SendMessage. Mitigation: keep `TeamCreate` for the coordination channel, but spawn the actual work via `Agent` (or, if must stay with SendMessage, add `subagent_type` to the message body as explicit instruction rather than structural guarantee).
- **`subagent_type: general-purpose` workers are more expensive than `Explore` (which uses Haiku).** Mitigation: use `general-purpose` only when Write is required; for pure-read analysis, continue to prefer `Explore`. The decision matrix makes this explicit.
- **Explicit `model: sonnet` on subagents to avoid `[1m]` inheritance may conflict with user preferences.** If a user runs `/extra-usage` and wants Sonnet 1M for research, our explicit model forecloses that. Mitigation: document that `CLAUDE_CODE_SUBAGENT_MODEL` env var overrides the frontmatter, so users who want 1M can set it themselves.
- **Guidance-doc drift**: as new subagent types land in Claude Code or new blitz agents are added, subagent-types.md will drift. Mitigation: add a pre-release gate in `/blitz:release` that greps `agents/*.md` and verifies every agent appears in subagent-types.md. Small CI step, catches drift at release time.
- **Reviewer-checklist enforcement depends on sprint-review being run.** If sprint-review is skipped for a PR, a spawn without `subagent_type` can still land. Mitigation: also add a lint rule to `hooks/scripts/pre-commit-validate.sh` that flags SKILL.md changes introducing `TeamCreate`/`SendMessage`/`Agent` without a nearby `subagent_type`.

## References

### Authoritative docs
- https://code.claude.com/docs/en/sub-agents — subagent reference
- https://code.claude.com/docs/en/model-config — model resolution order
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices — skill author guidance

### Blitz source
- `/home/tom/development/blitz/agents/architect.md` (read-only)
- `/home/tom/development/blitz/agents/reviewer.md` (Write + no Edit)
- `/home/tom/development/blitz/agents/backend-dev.md`, `frontend-dev.md`, `test-writer.md`, `doc-writer.md` (full write)
- `/home/tom/development/blitz/skills/sprint-dev/SKILL.md` — reference for `subagent_type: blitz:<role>` usage
- `/home/tom/development/blitz/skills/code-sweep/SKILL.md` (post-v1.1.3) — reference for `subagent_type: general-purpose` usage
- `/home/tom/development/blitz/skills/research/SKILL.md`, `sprint-plan/SKILL.md`, `sprint-review/SKILL.md`, `codebase-audit/SKILL.md` — skills to fix

### Related prior research
- `docs/_research/2026-04-16_plugin-agent-strategy.md` — parent research thread; this doc is a follow-up to the "observation worth noting" in that doc's Risks section.

### Session artifacts
- `.cc-sessions/research-c1df62a2/tmp/research/subagent-types.md`
- `.cc-sessions/research-c1df62a2/tmp/research/blitz-usage.md`
