# Sprint Plan Reference

Supporting schemas, templates, and logic for the sprint-plan skill.

**Companion protocols:**
- [carry-forward-registry.md](/_shared/carry-forward-registry.md) — The append-only JSONL registry. Sprint-plan reads it in Phase 0 for mandatory planning inputs and writes to it in Phase 4.1 when auto-waiving acceptance criteria.

---

## Story File Format (YAML Frontmatter Schema)

Every story file uses this frontmatter schema:

```yaml
---
id: "S1-001"                          # Sprint number + zero-padded sequence
title: "Create user profile schema"    # Short, imperative title
epic: "E003"                           # Parent epic ID
status: "planned"                      # Always "planned" at creation
priority: "high"                       # high | medium | low
points: 3                              # Fibonacci: 1, 2, 3, 5, 8
depends_on:                            # Story IDs this blocks on
  - "S1-000"                           # (empty list if no dependencies)
assigned_agent: "backend-dev"          # backend-dev | frontend-dev | test-writer | infra-dev
files:                                 # Files this story creates or modifies
  - "src/models/user-profile.ts"
  - "src/schemas/user-profile.schema.ts"
verify:                                # Shell commands that must pass for story completion
  - "npx tsc --noEmit"
  - "npx vitest run src/schemas/user-profile.test.ts"
done: "UserProfile schema exists, validates correctly, and has passing tests"
github_issue: null                     # Populated after issue creation
carry_forward: false                   # true if from a previous sprint
research_refs:                         # Research findings referenced
  - "domain-researcher:auth-patterns"
  - "codebase-analyst:existing-models"
registry_entries:                      # Optional: carry-forward registry ids this story advances
  - id: "cf-2026-04-02-modal-consistency"
    delta: 10                          # Units of progress this story contributes (files, components, etc.)
---
```

### `registry_entries` — Story → Registry Link

Optional. When present, sprint-dev writes a `progress` event line to `.cc-sessions/carry-forward.jsonl` for each referenced id when the story is marked `done`. This gives live coverage visibility during implementation — the registry updates as work lands, not only at sprint-review close.

**Fields per entry:**
- **`id`** (required) — An existing carry-forward registry id. Sprint-dev hard-fails if the id doesn't exist in the registry.
- **`delta`** (optional) — Integer units of progress this story contributes toward `scope.target`. If omitted, sprint-dev falls back to `len(story.files)` as a best-effort estimate. Authors should set `delta` explicitly whenever the story's file list is a poor proxy for its contribution (e.g., a single-file refactor that removes `class="modal-overlay"` from 40 files counts as a delta of 40, not 1).

**Inference fallback:** if a story has no `registry_entries` field but the parent epic has a non-empty `registry_entries` array in `epic-registry.json`, sprint-dev infers the link — but with `delta` forced to `1` (single-story pro-rata against the epic's children count). Authors are encouraged to set `registry_entries` explicitly for any story whose coverage contribution is non-trivial; the fallback is there to prevent silent zero-progress, not as a substitute for explicit tracking.

**Multi-entry stories:** a story can advance more than one registry entry simultaneously (e.g., a single commit that migrates modals AND normalizes z-index layers). Each entry gets its own `progress` line with its own `delta`.

See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the writer contract.

### Body Sections (required)

```markdown
## Description
2-4 sentences explaining what this story delivers and why it matters.

## Acceptance Criteria
1. [ ] Specific, testable criterion one
2. [ ] Specific, testable criterion two
3. [ ] Specific, testable criterion three

## Implementation Notes
- Key patterns to follow (reference existing code)
- Imports and dependencies needed
- Research findings that inform the approach

## Code Snippets
\`\`\`typescript
// Starter type definition, function signature, or test skeleton
\`\`\`

## Dependencies
- Blocks on: S1-000 (reason)
- Blocked by: nothing
```

### Gap-Closure Story Template

Used when `--gaps` mode is active. Stories generated from sprint review findings, completeness gate reports, or blocked story analysis.

```yaml
---
id: "S${N}-G001"                       # G prefix for gap-closure stories
title: "Fix: <finding title>"          # Imperative, prefixed with "Fix:"
epic: "gap-closure"                    # Always "gap-closure"
status: "planned"
priority: "high"                       # Derived from finding severity
points: 2                              # Gap stories are typically small (1-3)
type: "gap-closure"                    # Distinguishes from normal stories
depends_on: []
assigned_agent: "backend-dev"
files:
  - "src/path/to/affected-file.ts"
verify:
  - "npx tsc --noEmit"
  - "<test command for the specific fix>"
done: "<what the fix achieves>"
source_finding:                        # Traceability to the original finding
  report: "sprint-review"              # sprint-review | completeness-gate | STATE.md
  severity: "high"
  description: "Original finding text"
---
```

Body sections for gap-closure stories:
```markdown
## Finding
<Original finding from the review/gate report>

## Root Cause
<Why this gap exists — missing implementation, incomplete wiring, etc.>

## Fix
<Specific change to make, referencing existing code patterns>

## Verification
<How to confirm the fix addresses the finding>
```

---

## Story Partition Logic

Stories are assigned to agent roles based on the primary file types they touch.

### Assignment Rules Table

| File Pattern | Story Focus | Assigned Agent |
|---|---|---|
| `**/schemas/**`, `**/types/**`, `**/models/**` | Type definitions, validation schemas | `backend-dev` |
| `**/api/**`, `**/server/**`, `**/functions/**` | API routes, server handlers, cloud functions | `backend-dev` |
| `**/stores/**`, `**/composables/**`, `**/services/**` | State management, business logic, data services | `backend-dev` |
| `**/components/**`, `**/pages/**`, `**/layouts/**` | UI components, page views, layout templates | `frontend-dev` |
| `**/assets/**`, `**/styles/**`, `**/design-tokens/**` | Design tokens, CSS, static assets | `frontend-dev` |
| `**/*.test.*`, `**/*.spec.*`, `**/tests/**` | Unit tests, integration tests, e2e tests | `test-writer` |
| `**/firebase/**`, `**/infra/**`, `**/.github/**`, `**/ci/**` | Infrastructure, deployment, CI/CD config | `infra-dev` |
| `**/middleware/**`, `**/plugins/**` | Cross-cutting middleware, framework plugins | `backend-dev` |
| `**/config/**`, `**/env/**` | Configuration, environment setup | `infra-dev` |

### Conflict Resolution

When a story touches files matching multiple agents:
1. Assign to the agent whose files are **primary** (most lines changed).
2. If equal, prefer this priority: `backend-dev` > `frontend-dev` > `test-writer` > `infra-dev`.
3. Add a `coordination_note` to the story frontmatter naming the secondary agent.

### Balance Check

After partitioning, verify rough balance:
- No single agent has more than 50% of total story points.
- If imbalanced, consider splitting large stories or reassigning borderline stories.
- Test stories should be ~20-30% of total count (one test story per 2-3 implementation stories).

---

## Sprint Manifest JSON Schema

The per-sprint manifest lives at `sprints/sprint-${N}/manifest.json` and captures sprint-scoped state that is too volatile for the global `sprint-registry.json`. Sprint-plan writes this file at Phase 1.4; sprint-dev and sprint-review read and update it.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["sprint", "status", "created", "epics", "story_count"],
  "properties": {
    "sprint": { "type": "integer" },
    "status": {
      "type": "string",
      "enum": ["planning", "planned", "in-progress", "review", "reviewed", "done", "cancelled"]
    },
    "created": { "type": "string", "format": "date-time" },
    "epics": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Epic IDs selected for this sprint"
    },
    "carry_forward": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Story IDs carried forward from the previous sprint (incomplete stories)"
    },
    "story_count": { "type": "integer" },

    "waived_ac_count": {
      "type": "integer",
      "description": "Number of acceptance criteria auto-waived during Phase 4.1 under autonomy=high|full. Every waiver MUST also append a corresponding line to .cc-sessions/carry-forward.jsonl with event: 'auto_waived' — see skills/_shared/carry-forward-registry.md."
    },
    "reason_waivers": {
      "type": "string",
      "description": "Short phrase explaining why waivers were applied, e.g., 'autonomy=full'. Populated alongside waived_ac_count."
    },
    "registry_entries_touched": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of carry-forward registry ids (cf-*) that this sprint's stories advanced. Each entry MUST have been injected as a mandatory planning input OR explicitly claimed by a story in this sprint. Written during Phase 4.1 coverage check; audited in sprint-review Phase 3.5 Invariant 2."
    },
    "mandatory_planning_inputs_source": {
      "type": "string",
      "description": "Path to sprints/sprint-${N}-planning-inputs.json if the previous sprint-review auto-injected entries into this sprint. Empty when no carry-forward was pending."
    }
  }
}
```

**Waiver accounting:** `waived_ac_count` is the local mirror of what also gets written to the carry-forward registry. Sprint-review Phase 3.5 Invariant 2 cross-checks the two: for every `waived_ac_count > 0`, there MUST be a matching `event: "auto_waived"` line in `.cc-sessions/carry-forward.jsonl` for an entry whose parent epic appears in this manifest's `epics` field. Missing mirror → invariant failure.

---

## Sprint Registry JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "project": {
      "type": "string",
      "description": "Project name (auto-detected from package.json or directory)"
    },
    "current_sprint": {
      "type": "integer",
      "description": "The most recently planned sprint number"
    },
    "sprints": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["number", "status", "planned_date", "epics", "story_count", "stories"],
        "properties": {
          "number": { "type": "integer" },
          "status": {
            "type": "string",
            "enum": ["planned", "in-progress", "review", "done", "cancelled"]
          },
          "planned_date": { "type": "string", "format": "date-time" },
          "started_date": { "type": "string", "format": "date-time" },
          "completed_date": { "type": "string", "format": "date-time" },
          "epics": {
            "type": "array",
            "items": { "type": "string" }
          },
          "story_count": { "type": "integer" },
          "stories": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Story IDs (e.g., S1-001, S1-002)"
          },
          "carry_forward_from": {
            "type": "integer",
            "description": "Previous sprint number if stories were carried forward"
          },
          "agents": {
            "type": "object",
            "description": "Story count per agent role",
            "properties": {
              "backend-dev": { "type": "integer" },
              "frontend-dev": { "type": "integer" },
              "test-writer": { "type": "integer" },
              "infra-dev": { "type": "integer" }
            }
          },
          "github_milestone": {
            "type": "string",
            "description": "GitHub milestone URL if created"
          }
        }
      }
    }
  }
}
```

---

## Agent Prompt Templates

**Workload class for all sprint-plan research agents**: Medium (per `skills/_shared/spawn-protocol.md`). Every agent prompt below must open with:

```
You are a general-purpose agent with Write access. Your task is INCOMPLETE
if your output file does not exist when you finish.

BUDGET:
- Max file reads: 15
- Max web searches: 8 (0 for codebase-analyst)
- Max tool calls: 25
- Max output: 250 lines
- Wall-clock: 5 minutes

WRITE-AS-YOU-GO: Stub your output file with `# IN PROGRESS` before your
first research step. After each epic analyzed, append findings to the
file immediately. Do NOT accumulate in memory and write at the end.
```

### Domain Researcher

```
You are the domain-researcher for Sprint ${SPRINT_NUMBER} planning.

[Include the workload class block above as the first lines of this prompt.]

RESEARCH FOCUS: External APIs, domain standards, protocols, and patterns relevant to the selected epics.

SELECTED EPICS:
${EPIC_LIST}

INSTRUCTIONS:
1. For each epic, identify external APIs, services, or protocols involved.
2. Research current best practices, authentication patterns, rate limits, and error handling.
3. Look for official documentation, migration guides, and known gotchas.
4. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-domain-researcher.md — stub the file first, then append as you go.

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### External Dependencies
- <API/service name>: <key findings>
### Patterns & Best Practices
- <pattern>: <recommendation>
### Risks & Gotchas
- <issue>: <mitigation>

```

### Library Researcher

```
You are the library-researcher for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Package ecosystem, library versions, compatibility, migration paths, and implementation examples.

SELECTED EPICS:
${EPIC_LIST}

DETECTED STACK:
${STACK_PROFILE}

INSTRUCTIONS:
1. For each epic, identify required packages and their current stable versions.
2. Check compatibility with the detected stack (especially framework version).
3. Find implementation examples, especially for complex integrations.
4. Note any required peer dependencies or breaking changes.
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-library-researcher.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Required Packages
| Package | Version | Purpose | Compat Notes |
|---------|---------|---------|--------------|
### Implementation Examples
- <pattern>: <code reference or link>
### Migration / Breaking Changes
- <package>: <notes>

```

### Codebase Analyst

```
You are the codebase-analyst for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Existing code patterns, reusable modules, integration points, and potential conflicts.

SELECTED EPICS:
${EPIC_LIST}

PROJECT STRUCTURE:
${CODEBASE_INVENTORY}

INSTRUCTIONS:
1. For each epic, search the codebase for related existing code.
2. Identify reusable patterns (composables, utilities, components, schemas).
3. Map integration points where new code must connect to existing code.
4. Flag potential conflicts (naming collisions, import cycles, shared state).
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-codebase-analyst.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Existing Patterns to Reuse
- <file path>: <what it provides>
### Integration Points
- <file path>: <how new code connects>
### Potential Conflicts
- <issue>: <description and suggestion>
### Suggested File Locations
- <new file path>: <rationale based on existing conventions>

```

### Infrastructure Analyst (Optional)

```
You are the infra-analyst for Sprint ${SPRINT_NUMBER} planning.

RESEARCH FOCUS: Cloud configuration, security rules, deployment pipeline, environment variables, and infrastructure requirements.

SELECTED EPICS:
${EPIC_LIST}

INSTRUCTIONS:
1. Review existing infrastructure config (firebase.json, cloud functions, CI/CD).
2. Identify infrastructure changes needed for the selected epics.
3. Check security rules for required updates.
4. Note any environment variables or secrets that must be configured.
5. Write findings to: ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-research-infra-analyst.md

OUTPUT FORMAT:
## Epic: <epic-id> — <epic-title>
### Infrastructure Changes Required
- <resource>: <change description>
### Security Rules Updates
- <rule>: <current state> -> <required state>
### Environment Configuration
- <variable>: <purpose and where to set it>
### Deployment Considerations
- <consideration>: <details>

```
