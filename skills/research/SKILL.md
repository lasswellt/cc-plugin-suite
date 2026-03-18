---
name: research
description: Investigates libraries, APIs, cloud services, and architecture patterns. Produces structured research documents with findings, recommendations, and code examples. Use when user says "research X", "investigate", "compare options", "what's the best approach for".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, TeamCreate, SendMessage
model: opus
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Reference
!`cat ${CLAUDE_SKILL_DIR}/reference.md`

---

# Research Skill

Investigate a topic by spawning parallel research agents, collecting findings, and synthesizing a structured research document. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE TOPIC — Understand What to Research

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
RESEARCH_DIR="/tmp/research"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
rm -rf "${RESEARCH_DIR}"
mkdir -p "${RESEARCH_DIR}"
```

### 1.2 Create Research Team

Use `TeamCreate` to create a team named `research-${TOPIC_SLUG}`.

### 1.3 Determine Required Agents

Spawn 2-4 agents depending on the research type:

| Agent Name | Role | Always Spawned | Focus |
|---|---|---|---|
| `library-docs` | Library & Documentation Research | Yes | Official docs, API surface, version history, migration guides, known issues, changelogs |
| `web-researcher` | Web & Community Research | Yes | Blog posts, Stack Overflow, GitHub issues, benchmarks, community sentiment, alternatives |
| `codebase-analyst` | Codebase Analysis | Yes | Existing patterns, integration points, migration impact, affected files, dependency graph |
| `infra-analyst` | Infrastructure Analysis | If backend/cloud/infra detected | Cloud service docs, pricing, quotas, deployment implications, environment config |

### 1.4 Agent Instructions

Send each agent a message via `SendMessage` with:

1. **Research topic and questions** — Full context of what to investigate.
2. **Detected stack profile** — So findings are relevant to the project.
3. **Output file path** — `/tmp/research/<agent-name>.md`
4. **Research limits** — See below.
5. **Write-as-you-go rule** — "Write findings to your output file as you discover them. Do NOT accumulate in memory."
6. **Cross-steering protocol** — Use `STEER:` prefix via `SendMessage` to redirect cross-cutting findings to sibling agents.

**Cross-steering example:**
```
SendMessage to web-researcher:
STEER: migration-complexity — The library's official docs mention a codemods tool for v2->v3 migration.
Check community reports on how well it works in practice. Details in /tmp/research/library-docs.md section "Migration".
```

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
OUTPUT FILE: /tmp/research/library-docs.md

TASKS:
1. Find official documentation for the topic/library.
2. Document the API surface relevant to the project's use case.
3. Check version compatibility with the project's stack.
4. Note any migration guides, breaking changes, or deprecations.
5. Find code examples that match the project's patterns.
6. Document known issues and workarounds.

Write findings immediately to your output file. Use STEER: to redirect findings relevant to other agents.
```

#### web-researcher
```
You are web-researcher, a research agent specializing in community knowledge and real-world usage.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: /tmp/research/web-researcher.md

TASKS:
1. Search for recent blog posts, tutorials, and guides (prefer content from the last 12 months).
2. Check GitHub issues for common problems and their resolutions.
3. Find benchmarks or performance comparisons if relevant.
4. Assess community sentiment (adoption rate, maintenance activity, contributor count).
5. Identify alternatives and how they compare.
6. Note any "gotchas" or lessons learned from real-world usage.

Write findings immediately to your output file. Use STEER: to redirect findings relevant to other agents.
```

#### codebase-analyst
```
You are codebase-analyst, a research agent specializing in impact analysis.

TOPIC: ${TOPIC}
RESEARCH QUESTIONS: ${QUESTIONS}
PROJECT STACK: ${STACK_PROFILE}
OUTPUT FILE: /tmp/research/codebase-analyst.md

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
OUTPUT FILE: /tmp/research/infra-analyst.md

TASKS:
1. Check cloud service documentation for relevant features, quotas, and pricing.
2. Assess deployment pipeline impact (new build steps, environment variables, secrets).
3. Review security implications (new permissions, access patterns, data flow).
4. Evaluate environment configuration changes needed.
5. Check for compatibility with existing infrastructure setup.
6. Note monitoring and observability considerations.

Write findings immediately to your output file. Use STEER: to redirect findings relevant to other agents.
```

### 1.7 Wait for Completion

Poll for agent completion by checking output files:
```bash
for f in /tmp/research/*.md; do
  [ -s "$f" ] && echo "DONE: $f" || echo "PENDING: $f"
done
```

**Timeout:** If any agent has not produced output after 3 minutes, mark it as failed and proceed with available findings.

---

## Phase 2: COLLECT AND VALIDATE — Gather All Findings

### 2.1 Read All Agent Output Files

Read every file in `/tmp/research/`:
```
/tmp/research/library-docs.md
/tmp/research/web-researcher.md
/tmp/research/codebase-analyst.md
/tmp/research/infra-analyst.md  (if spawned)
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

Use the template from `reference.md`. The document MUST include all of these sections:

1. **Summary** — 3-5 sentence executive summary of findings and recommendation.
2. **Research Questions** — The questions posed, each with a concise answer.
3. **Findings** — Detailed findings organized by theme (not by agent). Each finding must cite its source.
4. **Compatibility Analysis** — How the topic fits with the detected stack. Include version compatibility, dependency conflicts, and integration complexity.
5. **Recommendation** — Clear, actionable recommendation with rationale. If comparing options, include a comparison matrix.
6. **Implementation Sketch** — High-level steps to implement the recommendation, adapted to the detected stack. Include key code patterns, file locations, and configuration changes.
7. **Risks** — Known risks, mitigations, and open questions.
8. **References** — Links to documentation, articles, and discussions cited in the findings.

### 3.2 Quality Gates

Before finalizing:
- Every research question has an answer (even if "insufficient data").
- Recommendation is specific and actionable (not "it depends").
- Implementation sketch references real project paths and patterns.
- No agent's findings are silently dropped.

### 3.3 Clean Up

```bash
rm -rf /tmp/research
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
