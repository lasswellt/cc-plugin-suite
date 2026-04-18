---
scope:
  - id: cf-2026-04-16-setup-skill-mvp
    unit: patterns
    target: 10
    description: |
      Ship an MVP /blitz:setup skill that detects conflicts between the
      user's CLAUDE.md and blitz skill behaviors. MVP covers two CLAUDE.md
      scopes (~/.claude/CLAUDE.md and ./CLAUDE.md), 10 known-conflict
      patterns in skills/setup/conflict-catalog.json, regex-only detection
      (no LLM pass), and report-only output (no --fix yet).
    acceptance:
      - shell: 'test -f skills/setup/SKILL.md'
      - shell: 'test -f skills/setup/conflict-catalog.json'
      - shell: 'jq ".conflicts | length >= 10" skills/setup/conflict-catalog.json'
      - grep_present:
          pattern: 'name: setup'
          min: 1
  - id: cf-2026-04-16-refactor-candidates
    unit: skills
    target: 3
    description: |
      Refactor three skills (codebase-map, integration-check,
      quality-metrics) to spawn parallel agent workers, each using the
      code-sweep v1.1.3 pattern (opus orchestrator, explicit sonnet
      workers via Agent tool, JSON findings files in session tmp dir).
    acceptance:
      - grep_present:
          pattern: 'Agent'
          path: 'skills/codebase-map/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'Agent'
          path: 'skills/integration-check/SKILL.md'
          min: 1
      - grep_present:
          pattern: 'Agent'
          path: 'skills/quality-metrics/SKILL.md'
          min: 1
  - id: cf-2026-04-16-waves-shared-doc
    unit: files
    target: 1
    description: |
      Extract the wave definition out of sprint-dev Phase 1.4 into a
      shared spec at skills/_shared/waves.md. Update sprint-dev,
      verbose-progress.md, checkpoint-protocol.md, and
      context-management.md to reference the shared doc rather than
      re-describing the concept.
    acceptance:
      - shell: 'test -f skills/_shared/waves.md'
      - grep_present:
          pattern: 'waves.md'
          path: 'skills/sprint-dev/SKILL.md'
          min: 1
---

# Plugin Agent Strategy — Research 2026-04-16

## Summary

The blitz plugin already implements strong agent-orchestration patterns in 7 of its 31 skills, but three concrete opportunities exist: (1) refactor `codebase-map`, `integration-check`, and `quality-metrics` to spawn parallel workers (same pattern as `codebase-audit` and post-v1.1.3 `code-sweep`) — this yields meaningful wall-time and context savings with low implementation risk; (2) extract the "wave" execution concept from `sprint-dev` Phase 1.4 into a shared `skills/_shared/waves.md` spec, but **resist the temptation to elevate it further** — only one skill (`sprint-dev`) has a real dependency DAG, and forcing wave semantics onto flat-pool orchestrators like `research` and `codebase-audit` is cargo-cult; (3) ship a `/blitz:setup` doctor skill that detects conflicts between the user's CLAUDE.md rules and blitz skill behaviors (auto-commit, auto-push, branch naming, package manager assumptions), modeled on the ESLint/Prettier allowlist pattern. Across all three, the meta-lesson from peer plugins (wshobson/agents, oh-my-claudecode, barkain workflow-orchestration) is that **explicit per-agent model selection** beats inheritance — blitz's own v1.1.4 1M-context inheritance bug is a direct example.

## Research Questions

1. **How well does blitz leverage agents across its 31 skills, and which skills should be refactored to spawn workers?**
2. **Should the "wave" concept (currently buried in sprint-dev) be elevated as a shared primitive used by other orchestrators?**
3. **What should a `/blitz:setup` skill look like that detects conflicts between the user's CLAUDE.md and blitz skill behaviors?**

## Findings

### 1. Current agent usage across blitz

Seven skills spawn agents today:

| Skill | Mechanism | Workers | Parallelism |
|---|---|---|---|
| `sprint-dev` | `Agent` (worktree) + `TeamCreate`/`SendMessage` | 3-5 (backend/frontend/test/infra) | Parallel within wave, sequential across |
| `sprint-plan` | `TeamCreate`/`SendMessage` | 3-4 researchers | Flat parallel |
| `research` | `TeamCreate`/`SendMessage` | 2-4 investigators | Flat parallel |
| `codebase-audit` | `TeamCreate`/`SendMessage` (explicit `model: sonnet`) | 10 pillar auditors | Flat parallel |
| `roadmap` | `TeamCreate`/`SendMessage` (Phases 5, 7) | 3-8 per-domain | Parallel |
| `sprint-review` | `TeamCreate`/`SendMessage` | 4 reviewers | Flat parallel |
| `code-sweep` (v1.1.3+) | `Agent` tool (explicit `model: sonnet`) | 1-3 tier workers | Parallel |

The `STEER:` cross-steering pattern in `research` and `sprint-plan` is clever (fire-and-forget peer messages between agents) but has no ack mechanism, so cross-steered findings can be silently truncated if the receiving agent is already near its output budget. `sprint-dev`'s richer prefix protocol (`DONE:`/`BLOCKED:`/`DEVIATION:`/`ESCALATE:`) routes through the orchestrator and is more robust.

### 2. Refactor candidates

Ranked by ROI:

1. **`codebase-map` — HIGH** — 4 independent dimensions (Technology, Architecture, Quality, Concerns) → 4 sonnet agents writing tmp findings → ~75% orchestrator context reduction. Same pattern as `codebase-audit`.
2. **`integration-check` — MEDIUM-HIGH** — 7 independent check categories → halves wall time on large codebases; already invoked inside sprint-dev where agent infra is hot.
3. **`quality-metrics` — MEDIUM** — 5 slow external-tool collectors (tsc, eslint, vitest, build, completeness) → parallel spawn cuts 2-3 min sequential to ~45 sec.
4. **`sprint-review` Phase 1** — MEDIUM — automated checks (tsc/lint/tests/build) run sequentially; Phase 2 already uses agents, infra trivial to extend.
5. **`completeness-gate` — LOW-MEDIUM** — 11 tier-agents (code-sweep pattern); ROI scales with codebase size.

**Explicitly not worth refactoring**: `todo`, `next`, `quick`, `health` (trivial), `dep-health` (sequential-by-necessity), `test-gen` (single-file target), `migrate` (sequential safety invariant).

### 3. The wave concept

**Canonical definition** (`sprint-dev/SKILL.md:133-148` Phase 1.4):

> Construct a DAG from story `depends_on` fields. Compute execution waves: Wave 0 = no deps; Wave N = deps all in 0..N-1; Critical path = longest chain.

It's a topological layer — maximal set of work units whose prerequisites are satisfied by prior waves, parallelizable within the wave. Wave boundaries are checkpoint/commit/push moments. No size caps, no agent capacity limits — purely dependency-driven.

**Current placement is fragmented** across four files:
- sprint-dev Phase 1.4 (definition)
- verbose-progress.md (progress format)
- checkpoint-protocol.md (STATE.md schema)
- context-management.md (compact summary trigger)

**No `skills/_shared/waves.md` exists.** The natural home for a waves spec is this path, following the pattern of `checkpoint-protocol.md` (operational primitive with schema + behavior rules).

**Critical: most other orchestrators should NOT adopt waves.** Only `sprint-dev` has a real dependency DAG between work units. `codebase-audit` (10 agents), `sprint-plan` (3-4 researchers), `research` (2-4 investigators), and `sprint-review` (4 reviewers) are **flat pools of independent agents** — waves would add bookkeeping overhead with zero scheduling benefit. Only `roadmap` Phase 7 has a weak case (foundation-epics-before-feature-epics). The spec must gate adoption on "do you have a real DAG?".

### 4. Peer plugin patterns

Surveyed 5 public Claude Code plugin suites:
- **wshobson/agents** — 3-tier Sonnet-orchestrates-Haiku, explicit `--model` flags at launch (no inheritance).
- **levnikolaevich/claude-code-skills** — cross-provider review (Codex + Gemini + Claude Opus) for 3× coverage.
- **barkain/claude-code-workflow-orchestration** — parallel wave scheduling with `CLAUDE_MAX_CONCURRENT` cap + plan-mode review before spawn.
- **Yeachan-Heo/oh-my-claudecode** — FREE→CHEAP→EXPENSIVE model routing, intent-based agent selection, claims 3-5× speedup + 30-50% token savings.
- **jeremylongshore/claude-code-plugins-plus-skills** — 340-plugin marketplace emphasizing reusable orchestration templates.

**Anthropic guidance** ([best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)) covers progressive disclosure and feedback loops but **does not publish a spawn-vs-inline decision tree**. Sub-agent docs mention four reasons to spawn: preserve main context, enforce tool constraints, specialize behavior, control cost.

**Dominant cost pattern**: workers default to Haiku/Sonnet; Opus reserved for orchestration. Peer plugins set `model:` explicitly per agent to avoid the exact inheritance bug blitz hit in v1.1.3.

**Community-documented pitfalls** relevant to blitz:
- Subagent context inheritance causes redundant codebase rescans (anthropics/claude-code#12790).
- Linear context multiplication from injected plugins (thedotmack/claude-mem#1464).
- Background agents silently fail when required tool permissions aren't pre-approved.
- Orchestrators become information bottlenecks when cross-agent findings must route through.
- Findings are lost entirely if agents time out before writing — write intermediate results to disk.

### 5. CLAUDE.md conflict detection

**Prior art sweep**: ESLint/Prettier's `eslint-config-prettier` CLI pattern (static allowlist of conflict rules) is the best analog. Husky/Lefthook detect hook conflicts via ownership markers. Claude Code itself has no `/doctor` or `/check` command — it concatenates CLAUDE.md scopes with no deduplication or conflict resolution.

**16 blitz skill behaviors** can conflict with user CLAUDE.md rules. Highest-risk:

| Severity | Behavior | Example conflict |
|---|---|---|
| HIGH | `sprint-dev` auto-commits per story | "never auto-commit" |
| HIGH | `sprint-dev` auto-pushes at wave boundaries | "never push without asking" |
| HIGH | `code-sweep --loop` auto-commit + auto-push | "always review before pushing" |
| HIGH | `release publish` pushes + creates GitHub release | "always create PR, never merge to main" |
| HIGH | Tool permissions (Agent, SendMessage, TeamCreate) not in allowlist | agent spawning silently fails |
| MEDIUM | `npm run *` verify commands | project uses pnpm/bun |
| MEDIUM | Commit format `feat(sprint-N/<role>):` | "commits must reference Jira tickets" |
| MEDIUM | `sprint-review` auto-fixes lint/type errors | "only report; never auto-fix" |
| LOW | Orchestrators use `opus` | "use haiku to control cost" |

**Top 10 CLAUDE.md rules** that commonly conflict (detailed in setup-skill findings): no-auto-commit, no-auto-push, no-unprompted-tests, custom commit format, custom branch naming, no-auto-branch, always-PR, no-auto-fix, non-npm package manager, model preference.

**Detection design**: hybrid — Stage 1 regex pattern library (zero LLM cost, <500ms) against a catalog at `skills/setup/conflict-catalog.json`; Stage 2 LLM semantic pass only on large files or ambiguous matches. One agent call per scope level max.

## Compatibility Analysis

All three workstreams are compatible with the existing blitz architecture:

- **Refactor candidates** use the same `Agent`-tool pattern established by v1.1.3 code-sweep; no new dependencies, no schema changes. Skills retain their frontmatter and phase structure.
- **Waves shared doc** is a docs refactor — no code changes needed beyond cross-reference updates in sprint-dev, verbose-progress.md, checkpoint-protocol.md, and context-management.md.
- **Setup skill** is a new skill; follows existing skill conventions (frontmatter, phases, session-protocol.md registration, activity-feed logging). Needs a new `skills/setup/conflict-catalog.json` data file.

**Lesson already-learned from v1.1.3/v1.1.4**: any skill that declares `model: sonnet` crashes at load when invoked from a `[1m]` parent session (Sonnet 4.6 needs `/extra-usage` for 1M, no way to strip `[1m]` flag in frontmatter). All three workstreams must follow the **opus orchestrator + explicit sonnet workers via Agent tool** pattern to survive this.

## Recommendation

**Ship three bundled efforts, in this order:**

1. **Setup skill MVP (v1.2.0)** — highest user-visible value. Ships the conflict-detection dictionary + report-only output. Surfaces the hidden runtime-surprise cost of CLAUDE.md conflicts that every current user already has.
2. **Refactor three skills to parallel workers (v1.3.0)** — `codebase-map`, `integration-check`, `quality-metrics`. Each is small, independent, ships separately behind a patch/minor. Establishes the orchestrator-worker pattern as the blitz default for analysis skills.
3. **Extract waves to shared spec (v1.3.0)** — documentation refactor. Validates the pattern by re-pointing sprint-dev to the spec. **Do not push waves into other skills unless they have a real DAG.** Second adopter candidate: `roadmap` Phase 7 (weak case, optional).

**Cross-cutting convention**: add a `## Model Selection` section to the `skills/_shared/session-protocol.md` that codifies the opus-orchestrator / explicit-sonnet-workers pattern and explicitly warns against relying on model inheritance. Reference the v1.1.3 bug as the case study.

## Implementation Sketch

### A. Setup skill MVP

Files to create:
- `skills/setup/SKILL.md` (frontmatter: `model: sonnet` is SAFE here — no agent spawning, bounded read-only work; 1M inheritance irrelevant because skill stays in one context)
- `skills/setup/reference.md` — detection algorithm + scope merge rules
- `skills/setup/conflict-catalog.json` — 10 patterns covering auto-commit, auto-push, test execution, commit format, branch naming, auto-branch, always-PR, auto-fix, package manager, model preference

Skill phases:
- Phase 0: session register, parse `--fix | --check | --scope <global|project|all>` flags
- Phase 1: probe `~/.claude/CLAUDE.md`, `./.claude/CLAUDE.md`, `./CLAUDE.md`, `./**/.claude/CLAUDE.md` (depth ≤3)
- Phase 2: Stage 1 regex scan; Stage 2 LLM pass only on Stage 1 match or files >200 lines
- Phase 3: validate tool permissions (`~/.claude/settings.json` and `.claude/settings.json` allow Agent, SendMessage, TeamCreate, TaskCreate)
- Phase 4: stack check (detect pnpm-lock/bun.lockb/yarn.lock; flag if default npm commands mismatch)
- Phase 5: report with severity grading + per-conflict remediation suggestion
- Phase 6: complete

Integration path:
- MVP: manual `/blitz:setup` only
- v1.3: invoked by `bootstrap` Phase 0
- v1.4: SessionStart hook with 24h result cache at `.cc-sessions/setup-check.json`

### B. Refactor three skills to parallel workers

For each of `codebase-map`, `integration-check`, `quality-metrics`:
- Change frontmatter: `model: opus`; add `Agent` to `allowed-tools`
- Replace main work phase with orchestrator block that spawns N parallel Agents (explicit `model: sonnet`) in a single assistant message
- Each agent writes findings JSON to `.cc-sessions/${SESSION_ID}/tmp/<unit>.json`
- Orchestrator reads all files, merges, proceeds to report

Prior-art reference: `skills/code-sweep/SKILL.md` Phase 2 post-v1.1.3 and the Tier Agent Prompt Template in `skills/code-sweep/reference.md`.

### C. Waves shared spec

Create `skills/_shared/waves.md` with: definition, dependency resolution algorithm (Kahn's topological sort), size-cap guidance, worker-pool semantics, progress-reporting hooks, checkpoint behavior, opt-in convention. ≤120 lines.

Update these files to reference the new doc instead of redefining the concept:
- `skills/sprint-dev/SKILL.md` Phase 1.4
- `skills/_shared/verbose-progress.md` Wave Progress Reporting section
- `skills/_shared/checkpoint-protocol.md` STATE.md schema
- `skills/_shared/context-management.md` compact-summary trigger

Add opt-in line to Additional Resources of any adopting skill:
```markdown
- For wave-based dependency ordering and execution protocol, see [waves.md](/_shared/waves.md)
```

## Risks

- **Cargo-cult wave adoption**: future authors will reach for waves as a "standard pattern" on flat-pool orchestrators. Mitigation: spec opens with a "do you have a real DAG?" gate; examples in `research`, `codebase-audit`, `sprint-plan` are called out explicitly as non-adopters.
- **Conflict catalog staleness**: as skills evolve, the catalog drifts. Mitigation: add a CI check (or pre-release gate in `/blitz:release`) that greps skill SKILL.md files for commit/push/test/model behaviors and fails if any are missing from the catalog.
- **Refactor regression risk**: three skills at once is a big diff. Mitigation: ship each behind its own PR + patch; verify with `/blitz:sprint-review` before each release.
- **Setup skill false positives**: overly broad regex patterns ("never" near "commit") will flag innocent CLAUDE.md sentences. Mitigation: anchor patterns to bullets/sentence structure, not arbitrary substrings; start with narrow HIGH-signal phrases and expand only based on user feedback.
- **Model inheritance bug resurfaces**: any refactor that declares `model: sonnet` in an orchestrator SKILL.md will reproduce v1.1.3's crash. Mitigation: session-protocol.md rule + reviewer checklist item.
- **Findings-loss-on-timeout** in research agents (already observed this session — two of four agents were read-only Explore agents that couldn't write files; orchestrator had to write findings from tool result text). Mitigation: the blitz research skill should prefer `general-purpose` subagents over `Explore` when file writes are required, or document fallback path.

## References

### Blitz codebase
- `skills/sprint-dev/SKILL.md:133-148` — wave definition
- `skills/_shared/verbose-progress.md:228-244` — wave progress format
- `skills/_shared/checkpoint-protocol.md:64-71` — STATE.md wave table
- `skills/_shared/context-management.md:61-67` — compact-summary wave trigger
- `skills/codebase-audit/SKILL.md:97-120` — 10-agent orchestration reference pattern
- `skills/code-sweep/SKILL.md:95-170` (post-v1.1.3) — Agent-tool orchestrator reference
- `skills/code-sweep/reference.md:7-78` — tier-agent prompt template

### Peer plugin suites
- https://github.com/wshobson/agents
- https://github.com/levnikolaevich/claude-code-skills
- https://github.com/barkain/claude-code-workflow-orchestration
- https://github.com/Yeachan-Heo/oh-my-claudecode
- https://github.com/jeremylongshore/claude-code-plugins-plus-skills

### Anthropic documentation
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://code.claude.com/docs/en/sub-agents
- https://claude.com/blog/subagents-in-claude-code

### Community-reported issues
- anthropics/claude-code#12790 — subagent context-inheritance rescanning
- thedotmack/claude-mem#1464 — linear context multiplication from plugins

### Session artifacts
- `.cc-sessions/research-78ecd26e/tmp/research/agent-patterns.md`
- `.cc-sessions/research-78ecd26e/tmp/research/peer-plugins.md`
- `.cc-sessions/research-78ecd26e/tmp/research/waves.md`
- `.cc-sessions/research-78ecd26e/tmp/research/setup-skill.md`
