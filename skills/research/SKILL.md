---
name: research
description: Investigates libraries, APIs, cloud services, and architecture patterns. Produces structured research documents with findings, recommendations, and code examples. Use when user says "research X", "investigate", "compare options", "what's the best approach for".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent
model: opus
compatibility: ">=2.1.71"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For research document template, research types, and section guidelines, see [reference.md](reference.md)
- For context window hygiene, see [context-management.md](/_shared/context-management.md)
- For quantified scope → registry ingestion, see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)

All research output must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder sections.

---

# Research Skill

Investigate a topic by spawning parallel research agents, collecting findings, and synthesizing a structured research document. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE TOPIC — Understand What to Research

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

### 0.1 Extract Research Topic

Parse the user's request to identify:
- **Topic**: The primary subject to research (library, API, pattern, architecture decision, etc.)
- **Topic slug**: Lowercase, hyphenated version for file naming (e.g., `auth-strategy`, `state-machine-libs`)
- **Research type**: One of: Library Evaluation, Architecture Decision, Feature Investigation, Comparison (see reference.md)
- **Scope constraints**: Any constraints the user mentioned (must work with X, needs Y, cannot use Z)
- **Decision context**: Why this research is needed (new feature, migration, performance issue, etc.)

### 0.2 Formulate Research Questions

Generate 3-6 specific research questions that must be answered. Examples:
- "Which library has the best TypeScript support?"
- "What are the breaking changes between v2 and v3?"
- "How does this integrate with the detected framework?"
- "What is the performance impact at scale?"
- "What are the security implications?"

### 0.3 Build Codebase Context

Quick scan of the project to understand constraints:
```bash
# Check for relevant existing implementations
find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -10
```
- Read root `package.json` to identify existing dependencies
- Note the detected stack profile (framework, build system, package manager)
- Identify any existing code related to the research topic

---

## Phase 1: SPAWN RESEARCH AGENTS — Parallel Investigation

### 1.1 Create Working Directory

```bash
RESEARCH_DIR="${SESSION_TMP_DIR}/research"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
rm -rf "${RESEARCH_DIR}"
mkdir -p "${RESEARCH_DIR}"
```

### 1.2 Determine Required Agents

Spawn 2-4 agents depending on the research type:

| Agent Name | Role | Always Spawned | Focus |
|---|---|---|---|
| `library-docs` | Library & Documentation Research | Yes | Official docs, API surface, version history, migration guides, known issues, changelogs |
| `web-researcher` | Web & Community Research | Yes | Blog posts, Stack Overflow, GitHub issues, benchmarks, community sentiment, alternatives |
| `codebase-analyst` | Codebase Analysis | Yes | Existing patterns, integration points, migration impact, affected files, dependency graph |
| `infra-analyst` | Infrastructure Analysis | If backend/cloud/infra detected | Cloud service docs, pricing, quotas, deployment implications, environment config |

### 1.3 Spawn Agents via Agent Tool

Spawn each agent in **a single assistant message** (so they run concurrently) using the `Agent` tool with:

- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails the write)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from the Opus orchestrator)
- `description: research <agent-name>`
- `prompt`: the agent prompt template from Section 1.5 below, filled with topic, questions, output path, and stack profile
- `run_in_background: true` (orchestrator polls output files in Phase 1.7)

Each agent prompt MUST include:

1. **Research topic and questions** — Full context of what to investigate.
2. **Detected stack profile** — So findings are relevant to the project.
3. **Output file path** — `${SESSION_TMP_DIR}/research/<agent-name>.md`
4. **Research limits** — See below.
5. **Write-as-you-go rule** — "Stub your output file with `# IN PROGRESS` before your first tool call. Append findings as you discover them. Do NOT accumulate in memory."

Cross-cutting findings are NOT routed peer-to-peer. The orchestrator synthesizes cross-domain findings in Phase 2 from the written output files. (The previous STEER: SendMessage protocol was removed in v1.4.0 — it was advisory-only, had no ack mechanism, and findings could be silently truncated when the receiving agent was near its output budget.)

### 1.5 Research Limits Per Agent

Each agent must respect these limits to stay focused:

| Agent | Max Web Searches | Max Files Read | Max Output Length |
|---|---|---|---|
| `library-docs` | 8 | 5 | 200 lines |
| `web-researcher` | 10 | 3 | 200 lines |
| `codebase-analyst` | 0 | 15 | 150 lines |
| `infra-analyst` | 6 | 8 | 150 lines |

### 1.6 Agent Prompt Templates

#### library-docs
```
You are library-docs, a research agent specializing in official documentation analysis.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/library-docs.md

TASKS:
1. Find official documentation for the topic/library.
2. Document the API surface relevant to the project's use case.
3. Check version compatibility with the project's stack.
4. Note any migration guides, breaking changes, or deprecations.
5. Find code examples that match the project's patterns.
6. Document known issues and workarounds.

Stub your output file with `# IN PROGRESS` before your first tool call. Append findings as you discover them.
```

#### web-researcher
```
You are web-researcher, a research agent specializing in community knowledge and real-world usage.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/web-researcher.md

TASKS:
1. Search for recent blog posts, tutorials, and guides (prefer content from the last 12 months).
2. Check GitHub issues for common problems and their resolutions.
3. Find benchmarks or performance comparisons if relevant.
4. Assess community sentiment (adoption rate, maintenance activity, contributor count).
5. Identify alternatives and how they compare.
6. Note any "gotchas" or lessons learned from real-world usage.

Stub your output file with `# IN PROGRESS` before your first tool call. Append findings as you discover them.
```

#### codebase-analyst
```
You are codebase-analyst, a research agent specializing in impact analysis.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/codebase-analyst.md

TASKS:
1. Identify all files and modules related to the research topic.
2. Map the dependency graph of affected code.
3. Assess integration points where the topic would connect to existing code.
4. Identify existing patterns that should be followed or migrated.
5. Estimate migration effort (files to change, complexity of changes).
6. Note potential conflicts with existing dependencies.

Do NOT use web search. Focus entirely on the codebase. Write findings immediately to your output file.
```

#### infra-analyst (optional)
```
You are infra-analyst, a research agent specializing in infrastructure and deployment implications.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: ${SESSION_TMP_DIR}/research/infra-analyst.md

TASKS:
1. Check cloud service documentation for relevant features, quotas, and pricing.
2. Assess deployment pipeline impact (new build steps, environment variables, secrets).
3. Review security implications (new permissions, access patterns, data flow).
4. Evaluate environment configuration changes needed.
5. Check for compatibility with existing infrastructure setup.
6. Note monitoring and observability considerations.

Stub your output file with `# IN PROGRESS` before your first tool call. Append findings as you discover them.
```

### 1.7 Wait for Completion

Poll for agent completion by checking output files:
```bash
for f in ${SESSION_TMP_DIR}/research/*.md; do
  [ -s "$f" ] && echo "DONE: $f" || echo "PENDING: $f"
done
```

**Timeout:** If any agent has not produced output after 3 minutes, mark it as failed and proceed with available findings.

---

## Phase 2: COLLECT AND VALIDATE — Gather All Findings

### 2.1 Read All Agent Output Files

Read every file in `${SESSION_TMP_DIR}/research/`:
```
${SESSION_TMP_DIR}/research/library-docs.md
${SESSION_TMP_DIR}/research/web-researcher.md
${SESSION_TMP_DIR}/research/codebase-analyst.md
${SESSION_TMP_DIR}/research/infra-analyst.md  (if spawned)
```

### 2.2 Handle Agent Failures

For each missing or empty output file:
- Log the failure.
- If fewer than 2 agents succeeded, warn the user that research is incomplete.
- Do NOT retry. Proceed with available findings and note gaps.

### 2.3 Cross-Reference Findings

Look for:
- **Contradictions** — Does one agent's finding conflict with another's? Note and resolve.
- **Gaps** — Are any research questions unanswered? Note for the user.
- **Convergence** — Do multiple agents reach the same conclusion? Strengthen that finding.

---

## Phase 3: SYNTHESIZE — Produce Research Document

### 3.1 Generate Research Document

Write the final research document to:
```
docs/_research/YYYY-MM-DD_<topic-slug>.md
```

Create the directory if it does not exist:
```bash
mkdir -p docs/_research
```

**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, paths, commands, grep patterns, YAML/JSON frontmatter (especially `scope:`), tables, error codes, dates, versions. No preamble, no trailing summary. Fragments OK. Intensity: `lite` for user-facing Summary + Research-Questions + Risks (reasoning chain must survive); `full` for Findings narrative + Implementation Sketch. Auto-pause for security/irreversible/root-cause sections — write full prose.

**Terse exemptions (LITE intensity):** §7 Risks section + Open Questions (reasoning chain must survive compression). Full sentences + reasoning chain required in these sections. Resume terse on next section.

Use the template from `reference.md`. The document MUST include all of these sections:

1. **Summary** — 3-5 sentence executive summary of findings and recommendation.
2. **Research Questions** — The questions posed, each with a concise answer.
3. **Findings** — Detailed findings organized by theme (not by agent). Each finding must cite its source.
4. **Compatibility Analysis** — How the topic fits with the detected stack. Include version compatibility, dependency conflicts, and integration complexity.
5. **Recommendation** — Clear, actionable recommendation with rationale. If comparing options, include a comparison matrix.
6. **Implementation Sketch** — High-level steps to implement the recommendation, adapted to the detected stack. Include key code patterns, file locations, and configuration changes.
7. **Risks** — Known risks, mitigations, and open questions.
8. **References** — Links to documentation, articles, and discussions cited in the findings.

### 3.1.1 Emit Structured Scope (when quantified)

If any finding or recommendation contains a **quantified scope claim** — regex match: `\d+\s+(files|components|modals|routes|tests|endpoints|pages|views|tables|endpoints|migrations|fields|records)` in the Summary, Findings, or Recommendation sections — the research doc MUST include a `scope:` YAML frontmatter block at the top of the file, above the `# <title>` heading.

This block is the **machine-readable contract** that `roadmap extend` parses to create carry-forward registry entries. Without it, the quantified claim is prose and silently drops between sprints. With it, every uncovered item remains visible in planning inputs until completed, deferred, or dropped. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the full registry protocol.

**Format:**

```yaml
---
scope:
  - id: cf-YYYY-MM-DD-<short-slug>
    unit: files                              # files | components | routes | tests | endpoints | ...
    target: 130                              # Integer count
    description: |
      Migrate all modal components in apps/web/src/ to @mbk/ui Modal.vue,
      removing the legacy class="modal-overlay" pattern and deprecating
      shared/ConfirmDialog.vue.
    acceptance:
      # Executable DoD — each check must be verifiable by completeness-gate
      # without human interpretation. Prefer grep/shell/AST over prose.
      - grep_absent: 'class="modal-overlay"'
      - grep_absent: 'from.*shared/ConfirmDialog'
      - grep_present:
          pattern: 'from.*@mbk/ui.*Modal'
          min: 30
---

# <Research Doc Title>
...
```

**Rules:**

1. **One entry per distinct quantified claim.** A doc that says "migrate 130 files AND add 4 new components AND fix 12 tests" must emit three `scope:` entries, not one bundled entry.
2. **The `id` must be unique across the registry.** Use the research doc date as the stem, e.g., `cf-2026-04-02-modal-consistency`. The roadmap extend step will reject duplicate ids.
3. **`acceptance` must be executable.** Prefer `grep_absent`, `grep_present` (with `min` count), `ast_absent`, or `shell` commands over checklist prose. A DoD that requires human interpretation to verify will not be audited and will fail Invariant 1 at sprint-review time.
4. **If scope cannot be quantified,** do not fake a number. Write an explicit HTML comment above the quantified language: `<!-- no-registry: <reason> -->`. Acceptable reasons include "scope is exploratory — will be quantified after spike story" or "scope is qualitative UX research with no countable artifacts." `sprint-review` Invariant 1 will honor this comment.
5. **When the research doc is later ingested** by `/blitz:roadmap extend`, each `scope:` entry becomes both (a) a `scope_metric` on the derived Capability in `capability-index.json` and (b) a registry line in `.cc-sessions/carry-forward.jsonl` with `status: active`, `delivered.actual: 0`, `coverage: 0.0`. The registry is then authoritative.

**Cross-check before writing the doc:** scan your own Summary, Findings, and Recommendation for quantified language. If you count the word "all" near a noun that has a knowable cardinality (e.g., "migrate all 130 modals"), that is a quantified scope claim and needs a `scope:` entry.

### 3.2 Quality Gates

Before finalizing:
- Every research question has an answer (even if "insufficient data").
- Recommendation is specific and actionable (not "it depends").
- Implementation sketch references real project paths and patterns.
- No agent's findings are silently dropped.
- **Scope block present** whenever the doc contains quantified scope language — or an explicit `<!-- no-registry: <reason> -->` comment. No un-registered quantified claims are allowed to land in `docs/_research/`.

### 3.3 Clean Up

```bash
rm -rf ${SESSION_TMP_DIR}/research
```

---

## Phase 4: REPORT — Present to User

### 4.1 Output Summary

Print a concise summary to the user:

```
Research Complete: <topic>
========================
Document: docs/_research/YYYY-MM-DD_<topic-slug>.md
Agents: <succeeded>/<total> succeeded
Questions answered: <N>/<total>

Key Finding: <one-sentence top finding>
Recommendation: <one-sentence recommendation>
```

### 4.2 Follow-Up Suggestions

Based on the research type and findings, suggest next steps using the skill graph:

| Research Outcome | Suggested Skill | Rationale |
|---|---|---|
| Library selected, ready to integrate | `refactor` | Refactor existing code to use the new library |
| Architecture decision made | `sprint-plan` | Plan implementation stories |
| Feature approach decided | `ui-build` | Build the feature UI |
| Security concern identified | `codebase-audit` | Audit for related vulnerabilities |
| Performance approach selected | `test-gen` | Generate performance-related tests |

---

## Error Recovery

- **No web search available**: Skip `library-docs` and `web-researcher` web searches. Rely on `codebase-analyst` findings and inform the user that research is limited to codebase analysis.
- **Topic too broad**: Ask the user to narrow the scope. Suggest specific sub-topics.
- **No relevant codebase code found**: Note that this is a greenfield investigation. Skip codebase compatibility analysis and focus on stack-level compatibility.
- **Contradictory findings**: Present both sides with evidence. Let the recommendation acknowledge the trade-off.
- **Agent timeout**: Proceed with available findings. Note which agent timed out and what coverage was lost.
