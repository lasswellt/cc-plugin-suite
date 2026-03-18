---
name: roadmap
description: Generates phased implementation roadmaps from research documents. Extracts capabilities, assesses codebase state, clusters features into domains, resolves dependencies, and produces epic-ready implementation plans. Use when user says "generate roadmap", "plan phases", "roadmap status", "extend roadmap".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, TeamCreate, SendMessage
disable-model-invocation: true
model: opus
argument-hint: "[full | refresh | extend | status]"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For capability schema, document classification, and Phases 5-8 procedures, see [reference.md](reference.md)

---

# Roadmap Generation Skill

Generate phased implementation roadmaps from research documents. Execute the appropriate mode based on arguments. Do NOT skip phases.

---

## Mode Routing

Parse `$ARGUMENTS` to determine execution mode:

| Argument | Mode | Description |
|----------|------|-------------|
| `full` (default) | Full Generation | Run all phases (0-8). Use when no roadmap exists. |
| `refresh` | Refresh | Re-read research docs, update capabilities, re-assess codebase state, regenerate phases. Preserves completed work. |
| `extend` | Extend | Add new capabilities from new research docs. Append to existing roadmap without disrupting current phases. |
| `status` | Status | Report current roadmap progress: completed/in-progress/pending epics, blockers, and next actions. |

If no argument is provided, default to `full`.

**For `status` mode**: Skip to Phase 0 context loading, then print a status report and STOP. Do not generate anything.

**For `refresh` mode**: Run Phases 0-4, then selectively re-run Phases 5-8 only for changed domains.

**For `extend` mode**: Run Phase 0, then Phase 1 for new documents only, skip to Phase 4 for dependency re-resolution, then Phases 5-8 for new domains only.

---

## Phase 0: CONTEXT — Load Project State

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md). Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, and check for conflicting sessions before proceeding.

### 0.1 Locate Registry Files

Search for existing roadmap artifacts:
```
Glob: **/roadmap-registry.json, **/epic-registry.json, **/roadmap/**/*.md, **/docs/roadmap/**/*
```

### 0.2 Load Research Index

Search for research documents:
```
Glob: **/docs/_research/**/*.md, **/docs/research/**/*.md, **/research/**/*.md, **/_research/**/*.md
```

If no research documents found, inform the user that research documents are required and STOP.

### 0.3 Build Codebase Inventory

Run:
```bash
find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
```

Read root `package.json` and workspace configs. Identify:
- Project structure (monorepo vs single package)
- Existing packages/modules and their purposes
- Current dependencies and versions

### 0.4 Load Existing Roadmap (if any)

If a roadmap registry exists:
- Read the registry JSON.
- Note completed epics, in-progress epics, and pending epics.
- Load the capability index if it exists.

For `status` mode: Print the status report now and STOP.

```markdown
# Roadmap Status Report

**Last Updated**: <date>
**Total Capabilities**: N
**Total Epics**: N

## Phase Summary
| Phase | Epics | Completed | In Progress | Pending | Blocked |
|-------|-------|-----------|-------------|---------|---------|

## Next Actions
<list unblocked epics ready to start>

## Blockers
<list blocked epics and what they are waiting on>
```

**Gate:** For `full` mode, you must have at least 1 research document. For `refresh`/`extend`, you must have an existing roadmap.

---

## Phase 1: RESEARCH INGESTION — Extract Capabilities

### 1.1 Discover Research Documents

Read every file found in Phase 0.2. For each document:

1. **Classify the document** using the 8-type classification table from `reference.md`:
   - `product_definition` — Vision, goals, target users, value propositions
   - `feature_spec` — Detailed feature descriptions, user stories, acceptance criteria
   - `competitive_analysis` — Market research, competitor features, differentiators
   - `nfr` — Non-functional requirements (performance, security, accessibility)
   - `architecture` — System design, data models, API contracts, infrastructure
   - `brand_ux` — Design system, UX guidelines, brand voice, accessibility standards
   - `integration_spec` — Third-party integrations, API contracts, protocols
   - `operational` — Deployment, monitoring, CI/CD, runbooks

2. **Extract capabilities** from the document. A capability is a discrete unit of functionality that can be implemented. Assign sequential IDs: `CAP-001`, `CAP-002`, etc.

### 1.2 Capability Extraction Rules

For each capability, capture:
```yaml
id: CAP-NNN
title: "<short descriptive title>"
source_document: "<relative-path>"
document_type: "<classification>"
description: "<2-3 sentences>"
user_value: "<who benefits and how>"
acceptance_criteria:
  - "<testable criterion>"
complexity: low | medium | high | very_high
domain_hint: "<suggested domain cluster>"
dependencies_hint: ["<CAP-IDs this likely depends on>"]
research_needed: true | false
research_triggers: ["<questions that need answering>"]
```

### 1.3 Deduplicate Capabilities

After extracting from all documents:
- Compare capabilities by title similarity and description overlap.
- If two capabilities from different documents describe the same thing, merge them. Keep the richer description and combine acceptance criteria.
- Record the merge in a dedup log.

### 1.4 Write Capability Index

Write `docs/roadmap/capability-index.json`:
```json
{
  "generated": "<ISO-8601>",
  "source_documents": [
    { "path": "<relative>", "type": "<classification>", "capabilities_extracted": 0 }
  ],
  "capabilities": [ "<capability objects>" ],
  "dedup_log": [ { "merged": "CAP-XXX", "into": "CAP-YYY", "reason": "..." } ]
}
```

**Gate:** At least 5 capabilities must be extracted. If fewer, warn the user that research may be insufficient.

---

## Phase 1B: RESEARCH ENRICHMENT — Fill Knowledge Gaps

### 1B.1 Build Research Agenda

From the capability index, collect all capabilities where `research_needed: true`. Group their `research_triggers` by theme.

Prioritize research by:
1. Capabilities with `complexity: very_high` or `high`
2. Capabilities involving external integrations
3. Capabilities with security or compliance implications

### 1B.2 Context7 Lookups (max 8)

Use ToolSearch to check for Context7 MCP tools. If available:
- Look up documentation for detected libraries/frameworks.
- Focus on APIs, migration guides, and best practices relevant to high-complexity capabilities.
- Cache results in `${SESSION_TMP_DIR}/roadmap-research/context7/`.

### 1B.3 Web Research (max 12)

Use WebSearch for:
- Best practices for identified architectural patterns.
- Pricing/limits for third-party services referenced in capabilities.
- Security advisories for planned integrations.
- Performance benchmarks for chosen technologies.

Cache results in `${SESSION_TMP_DIR}/roadmap-research/web/`.

### 1B.4 Synthesize Research Cache

Write `docs/roadmap/research-cache.json` using the schema from `reference.md`. Each entry includes:
- Source (context7 or web)
- Query used
- Key findings (bulleted)
- Confidence level (high, medium, low)
- Related capabilities (CAP-IDs)

---

## Phase 2: CODEBASE STATE ASSESSMENT — What Exists Today

### 2.1 Load Architecture Context

Read key architectural files:
- Framework config files
- Type definitions and schemas
- Existing route definitions
- Store/state management files
- Database schemas or rules

### 2.2 Build Evidence Matrix

For each capability, assess the current codebase state:

| Status | Meaning |
|--------|---------|
| `not_started` | No related code exists |
| `partial` | Some infrastructure exists but feature incomplete |
| `implemented` | Feature exists but may not match spec |
| `complete` | Feature matches all acceptance criteria |

For each capability, record:
```yaml
capability: CAP-NNN
status: not_started | partial | implemented | complete
evidence:
  - file: "<path>"
    relevance: "<what this file contributes>"
coverage: 0.0  # 0.0 to 1.0
gaps:
  - "<what's missing>"
```

### 2.3 Gap Analysis

Write `docs/roadmap/gap-analysis.md`:
- Capabilities with no codebase support (greenfield)
- Capabilities with partial support (extend/refactor)
- Capabilities already implemented (verify/skip)
- Infrastructure gaps (missing packages, services, configs)

---

## Phase 3: DOMAIN ANALYSIS — Feature Clustering

### 3.1 Feature Clustering

Group capabilities into domains based on:
- **Shared data models**: Capabilities that read/write the same entities
- **Shared workflows**: Capabilities that belong to the same user journey
- **Shared infrastructure**: Capabilities that need the same backend services
- **UI proximity**: Capabilities that appear in the same screens/sections

### 3.2 Architecture-Informed Mapping

Align domains to the detected project structure:
- Map domains to existing packages/modules where applicable.
- Identify new packages/modules needed for unmapped domains.
- Ensure each domain has a clear owner in the architecture.

### 3.3 Write Domain Index

For each domain, write `docs/roadmap/domains/<domain-slug>/overview.md` using the template from `reference.md`.

Write `docs/roadmap/domain-index.json`:
```json
{
  "domains": [
    {
      "slug": "<domain-slug>",
      "name": "<Domain Name>",
      "description": "<1-2 sentences>",
      "capabilities": ["CAP-NNN"],
      "existing_modules": ["<paths>"],
      "new_modules_needed": ["<proposed-paths>"],
      "estimated_complexity": "low|medium|high|very_high"
    }
  ]
}
```

---

## Phase 4: DEPENDENCY RESOLUTION — Sequencing

### 4.1 Build Dependency Graph

For each capability, resolve dependencies:
- **Data dependencies**: A depends on B's data model
- **Infrastructure dependencies**: A needs B's service to exist
- **UI dependencies**: A's screen requires B's component
- **Auth dependencies**: A needs B's auth/permission system

Build a directed acyclic graph (DAG). Detect and report cycles.

### 4.2 Apply Sequencing Rules

1. **Foundation first**: Auth, data models, shared infrastructure before features.
2. **Backend before frontend**: APIs and data layers before UI that consumes them.
3. **Core before extensions**: MVP features before enhancements.
4. **Independent domains in parallel**: Domains with no cross-dependencies can run simultaneously.
5. **Testing alongside implementation**: Test infrastructure in the same phase as the code it tests.

### 4.3 Calculate Critical Path

Identify the longest dependency chain. This determines the minimum number of phases.

### 4.4 Assign Implementation Phases

Group capabilities into phases:
- **Phase 1**: Foundation (auth, data models, core infrastructure, project setup)
- **Phase 2**: Core features (MVP capabilities, primary user flows)
- **Phase 3**: Extended features (secondary capabilities, integrations)
- **Phase 4**: Polish (NFRs, optimizations, advanced features)
- **Phase 5+**: Future (nice-to-haves, stretch goals)

Each phase should be independently deployable.

### 4.5 Identify Parallel Workstreams

Within each phase, identify capabilities that can be worked on simultaneously by different developers/teams.

### 4.6 Write Phase Plan

Write `docs/roadmap/phase-plan.json`:
```json
{
  "phases": [
    {
      "number": 1,
      "name": "<Phase Name>",
      "description": "<goal of this phase>",
      "capabilities": ["CAP-NNN"],
      "domains": ["<domain-slugs>"],
      "parallel_workstreams": [
        { "name": "<workstream>", "capabilities": ["CAP-NNN"] }
      ],
      "estimated_duration": "<weeks>",
      "entry_criteria": ["<what must be true to start>"],
      "exit_criteria": ["<what must be true to finish>"]
    }
  ],
  "critical_path": ["CAP-NNN -> CAP-NNN -> ..."],
  "total_estimated_duration": "<weeks>"
}
```

---

## Phases 5-8: IMPLEMENTATION SPECS, CROSS-CUTTING, EPICS, SUMMARY

These phases are loaded on demand from `reference.md` to keep this skill file lean. Read the "Phases 5-8 Detailed Procedures" section from `${CLAUDE_SKILL_DIR}/reference.md` before executing.

**Phase 5**: Spawn agents per domain to generate implementation specs (data models, API contracts, component trees, workflow diagrams).

**Phase 6**: Generate cross-cutting specs (auth system, error handling strategy, testing strategy, CI/CD pipeline, monitoring).

**Phase 7**: Spawn agents per phase to convert specs into epics with stories, acceptance criteria, and effort estimates.

**Phase 8**: Write summary, update indexes, generate tracker, write manifest.

---

## Autonomous Execution Rules

1. **Never ask for confirmation between phases.** Execute all phases in sequence. Only stop if a gate condition fails.
2. **Write artifacts incrementally.** Do not accumulate everything in memory. Write each document as it is completed.
3. **Prefer specificity over abstraction.** Generated specs should reference actual file paths, function names, and types from the codebase.
4. **Respect existing code.** If the codebase already has a pattern for something, the roadmap should use that pattern, not invent a new one.
5. **Cap research time.** Context7 lookups: max 8. Web searches: max 12. Do not spend more than 20% of total execution on research.
6. **Handle missing data gracefully.** If a research document is vague, extract what you can and flag gaps. Do not stop the pipeline.
7. **Maintain traceability.** Every epic must trace back to capabilities. Every capability must trace back to a source document.
8. **Phase gates are strict.** If a gate fails, stop and report why. Do not proceed with insufficient data.
9. **Parallelize where possible.** When spawning agents (Phases 5, 7), run them concurrently.
10. **Produce machine-readable outputs.** Every phase writes both human-readable markdown and machine-readable JSON. The JSON feeds downstream skills (sprint-plan, sprint-dev).

---

## Error Recovery

- **No research documents found**: Inform user. Suggest creating research docs in `docs/_research/` and provide the 8-type classification table.
- **Existing roadmap found on `full` mode**: Warn user that this will overwrite. Suggest `refresh` or `extend` instead. Proceed only if user confirms (or rename existing to `.bak`).
- **Circular dependencies detected**: Report the cycle with involved capabilities. Suggest breaking the cycle by splitting a capability. Do not proceed with phase assignment until resolved.
- **Agent failure in Phases 5/7**: Retry once. If still failing, generate specs manually for that domain and note reduced quality.
- **Insufficient capabilities**: If fewer than 5 capabilities extracted, warn that the roadmap may be too thin. Proceed but flag in the summary.
- **Conflicting research**: If two documents contradict each other, flag the conflict in the capability notes and use the more recent document as primary source.
