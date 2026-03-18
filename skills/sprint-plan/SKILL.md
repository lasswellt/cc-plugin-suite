---
name: sprint-plan
description: Plans sprints from roadmap epics with research-backed stories. Reads the dependency graph, selects next unblocked epics, spawns research agents, generates implementation stories, creates GitHub issues. Use when user says "plan sprint", "generate stories", "plan next sprint".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, TeamCreate, SendMessage
disable-model-invocation: true
model: opus
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Reference
!`cat ${CLAUDE_SKILL_DIR}/reference.md`

---

# Sprint Planning Skill

Plan a sprint by selecting unblocked epics from the roadmap, conducting parallel research, generating implementation stories, and publishing to GitHub issues. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: CONTEXT — Load Project State

1. **Locate registry files.** Search the repo for sprint/roadmap registry files:
   ```
   Glob: **/sprint-registry.json, **/roadmap-registry.json, **/epic-registry.json, **/epics/**/*.md
   ```
2. **Load the epic/roadmap registry.** Read whatever registry or epic index exists. If none found, inform the user that a roadmap must exist before sprint planning can proceed and STOP.
3. **Load the research index.** Search for `**/research-index.json` or `**/research/**/*.md`. Note which epics already have research.
4. **Build codebase inventory.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read the root `package.json` (if it exists) and any workspace config (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`) to understand project structure.
5. **Load sprint history.** Read `sprint-registry.json` (or equivalent) to determine the last completed sprint number. If no registry exists, this is Sprint 1.
6. **Check for incomplete stories.** Search for story files from previous sprints that have `status: incomplete` or `status: in-progress`. These carry forward.

**Gate:** You must have at least one epic available and a basic understanding of project structure before proceeding.

---

## Phase 1: INITIALIZE — Select Epics and Create Sprint

### 1.1 Topological Sort on Epic Registry

Parse the epic dependency graph. For each epic, check its `depends_on` field. Build a DAG and perform topological sort.

**Selection rules:**
- An epic is **unblocked** if all its dependencies have status `done` or `complete`.
- An epic is **in-progress** if it has stories in a previous sprint that are incomplete.
- Select **all unblocked epics** plus any **in-progress** epics (carry-forward).
- If the user specified particular epics, use those instead (but warn if they have unmet dependencies).
- Target 8-20 stories total per sprint. Select epics accordingly.

### 1.2 Determine Sprint Number

```
SPRINT_NUMBER = (last sprint number from registry) + 1
```

If no registry exists, `SPRINT_NUMBER = 1`.

### 1.3 Create Sprint Directory

```bash
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
mkdir -p "${SPRINT_DIR}/stories"
mkdir -p "${SPRINT_DIR}/research"
```

### 1.4 Write Sprint Manifest

Write `${SPRINT_DIR}/manifest.json`:
```json
{
  "sprint": <number>,
  "status": "planning",
  "created": "<ISO-8601>",
  "epics": ["<epic-id-1>", "<epic-id-2>"],
  "carry_forward": ["<story-id-from-previous>"],
  "story_count": 0
}
```

### 1.5 Sync with GitHub Issues (if available)

Check if `gh` CLI is available and authenticated:
```bash
gh auth status 2>&1
```
If available, note the repo owner/name for later issue creation. If not, skip GitHub integration gracefully.

---

## Phase 2: RESEARCH — Parallel Agent Investigation

### 2.1 Create Research Team

Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-research`.

### 2.2 Spawn Research Agents

Spawn 3-4 named agents using `SendMessage`. Each agent writes findings to `/tmp/` files as they go.

**Required agents:**

| Agent Name | Role | Focus |
|---|---|---|
| `domain-researcher` | Domain & API Research | External APIs, protocols, standards relevant to selected epics |
| `library-researcher` | Library & Ecosystem Research | Package versions, migration guides, compatibility, best practices |
| `codebase-analyst` | Codebase Analysis | Existing patterns, reusable code, integration points, potential conflicts |

**Optional agent (spawn if backend/cloud services detected):**

| Agent Name | Role | Focus |
|---|---|---|
| `infra-analyst` | Infrastructure Analysis | Cloud config, security rules, deployment pipeline, environment setup |

### 2.3 Agent Instructions

Send each agent a message with:
1. The list of selected epics (IDs, titles, descriptions).
2. Their specific research focus (see reference.md for prompt templates).
3. Output file path: `/tmp/sprint-${SPRINT_NUMBER}-research-<agent-name>.md`
4. Instruction to use `SendMessage` with `STEER:` prefix to redirect cross-cutting findings to sibling agents.

**Cross-steering protocol:**
```
SendMessage to <sibling-agent>:
STEER: <topic> — Found relevant info for your area: <summary>. Details in /tmp/sprint-N-research-<my-name>.md section <heading>.
```

### 2.4 Collect Research

Wait for all agents to complete. Read their output files:
```
/tmp/sprint-${SPRINT_NUMBER}-research-domain-researcher.md
/tmp/sprint-${SPRINT_NUMBER}-research-library-researcher.md
/tmp/sprint-${SPRINT_NUMBER}-research-codebase-analyst.md
/tmp/sprint-${SPRINT_NUMBER}-research-infra-analyst.md  (if spawned)
```

Copy research files into `${SPRINT_DIR}/research/`.

**Gate:** All research files must exist and contain substantive findings (not empty or error-only). If an agent failed, retry once. If still failed, proceed with available research and note the gap.

---

## Phase 3: GENERATE STORIES — Create Implementation Stories

### 3.1 Story Generation Rules

For **each selected epic**, generate **5-15 stories** following these rules:

1. **Granularity**: Each story should be completable by one agent in one session (roughly 1-3 files changed, 50-300 lines).
2. **Ordering**: Stories within an epic must declare dependencies. Schema/type stories come first, then logic, then UI, then tests.
3. **Completeness**: Every acceptance criterion in the epic must map to at least one story.
4. **Research integration**: Each story must reference relevant research findings where applicable.

### 3.2 Story File Format

Write each story to `${SPRINT_DIR}/stories/S${SPRINT_NUMBER}-XXX-<slug>.md` where XXX is a zero-padded sequence number.

Use the YAML frontmatter schema defined in `reference.md`. Every story MUST include:
- `id`, `title`, `epic`, `status` (always `planned`), `priority`, `points`
- `depends_on` (list of story IDs this blocks on)
- `assigned_agent` (one of: `backend-dev`, `frontend-dev`, `test-writer`, `infra-dev`)
- `files` (list of file paths this story will create or modify)

The body must include:
- **Description**: 2-4 sentences on what and why.
- **Acceptance Criteria**: Numbered list, each testable and specific.
- **Implementation Notes**: Key code patterns, imports, relevant research references.
- **Code Snippets**: Starter code where helpful (types, function signatures, test skeletons).
- **Dependencies**: Which stories or external things must be done first.

### 3.3 Dependency Graph Validation

After generating all stories, validate:
- No circular dependencies.
- All `depends_on` references point to valid story IDs.
- At least one story per epic has no dependencies (can start immediately).

### 3.4 Story Numbering

Stories are numbered globally across the sprint: `S${SPRINT_NUMBER}-001`, `S${SPRINT_NUMBER}-002`, etc. Order by epic, then by dependency depth within epic.

---

## Phase 4: VALIDATE AND PUBLISH

### 4.1 Acceptance Criteria Coverage Check

For each epic, verify that every AC maps to at least one story. Write a coverage matrix:

```
${SPRINT_DIR}/ac-coverage.md
```

Format:
```markdown
| Epic | AC | Story | Covered |
|------|-----|-------|---------|
| E001 | AC1 | S1-003 | Yes |
```

If any AC is uncovered, generate additional stories before proceeding.

### 4.2 Partition Stories to Agent Roles

Apply the partition rules from `reference.md`:

| Story Type | Assigned Agent |
|---|---|
| Schema, types, validation | `backend-dev` |
| API routes, server functions, cloud functions | `backend-dev` |
| Stores, state management, composables | `backend-dev` |
| Components, pages, layouts | `frontend-dev` |
| UI integration, navigation, design tokens | `frontend-dev` |
| Unit tests, integration tests, e2e tests | `test-writer` |
| Infrastructure, deployment, CI/CD | `infra-dev` |

Update each story's `assigned_agent` field accordingly.

### 4.3 Write Sprint Summary

Write `${SPRINT_DIR}/summary.md` with:
- Sprint number, date, selected epics
- Story count by agent role
- Dependency graph (text format)
- Research highlights
- Carry-forward items
- Risk notes

### 4.4 Create GitHub Issues (if available)

If GitHub CLI is available, for each story:
```bash
gh issue create --title "S${SPRINT_NUMBER}-XXX: <story title>" \
  --body "<story body>" \
  --label "sprint-${SPRINT_NUMBER}" \
  --label "<epic-id>"
```

Record issue numbers back into story frontmatter as `github_issue: <number>`.

### 4.5 Update Sprint Registry

Update `sprint-registry.json`:
```json
{
  "sprints": [
    {
      "number": <N>,
      "status": "planned",
      "planned_date": "<ISO-8601>",
      "epics": ["<epic-ids>"],
      "story_count": <N>,
      "stories": ["<story-ids>"]
    }
  ]
}
```

### 4.6 Git Commit

```bash
git add sprints/sprint-${SPRINT_NUMBER}/
git add sprint-registry.json
git commit -m "plan(sprint-${SPRINT_NUMBER}): generate ${STORY_COUNT} stories for epics ${EPIC_LIST}"
```

### 4.7 Final Output

Print a summary table to the user:

```
Sprint ${SPRINT_NUMBER} planned successfully.
- Epics: <list>
- Stories: <count> (backend: N, frontend: N, test: N, infra: N)
- GitHub issues: <created/skipped>
- Carry-forward: <count>
```

---

## Error Recovery

- **No epics available**: All epics are blocked or done. Inform user and suggest updating the roadmap.
- **Research agent failure**: Retry once. If still failing, proceed with partial research and flag gaps in summary.
- **Circular dependencies detected**: Report the cycle and ask user to resolve before continuing.
- **GitHub CLI unavailable**: Skip issue creation, note in summary. Stories are still valid without issues.
