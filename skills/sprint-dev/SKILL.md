---
name: sprint-dev
description: Implements planned sprints with coordinated agent teams. Spawns backend-dev, frontend-dev, and test-writer agents in isolated worktrees. Distributes stories as tasks with dependency ordering and monitors progress. Use when user says "implement sprint", "develop stories", "start coding".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch
disable-model-invocation: true
model: opus
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Reference
See `${CLAUDE_SKILL_DIR}/reference.md` for agent prompt templates, coordination patterns, story distribution rules, and seed data protocol.

---

# Sprint Development Skill

Implement a planned sprint by spawning coordinated agent teams in isolated worktrees, distributing stories as tasks with dependency ordering, and monitoring progress through completion. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: CONTEXT — Load Project State

1. **Check for incomplete sprints.** Search for `sprint-registry.json` and check for sprints with `status: in-progress`. If one exists, resume it (skip to Phase 1 with that sprint). Warn the user.
2. **Build codebase inventory.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
   Read root `package.json` and workspace config to understand structure.
3. **Verify build health.** Run a type-check and build to establish baseline:
   ```bash
   # Detect and run appropriate commands
   npm run type-check 2>&1 | tail -20  # or equivalent
   npm run build 2>&1 | tail -20       # or equivalent
   ```
   Record baseline error count. If baseline has errors, note them as pre-existing.
4. **Load detected stack.** Note framework, package manager, test runner, and build system from the stack profile above.

**Gate:** Build must succeed (or pre-existing errors must be cataloged) before spawning agents.

---

## Phase 1: LOAD SPRINT — Find and Parse Planned Sprint

### 1.1 Find Latest Planned Sprint

Read `sprint-registry.json` and find the sprint with `status: planned`. If the user specified a sprint number, use that instead.

```bash
# Find sprint directory
SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
```

### 1.2 Load Sprint Manifest

Read `${SPRINT_DIR}/manifest.json` to get epic list and story count.

### 1.3 Load All Stories

Read every story file in `${SPRINT_DIR}/stories/`. For each story, extract:
- `id`, `title`, `assigned_agent`, `depends_on`, `priority`, `points`, `files`

### 1.4 Build Dependency Graph

Construct a DAG from story `depends_on` fields. Identify:
- **Ready stories**: No unmet dependencies (can start immediately).
- **Blocked stories**: Have dependencies that are not yet complete.
- **Critical path**: Longest dependency chain (determines minimum completion time).

### 1.5 Load Carry-Forward Items

If the manifest has `carry_forward` entries, load those stories and add them to the graph.

### 1.6 Update Sprint Status

Update `sprint-registry.json`: set sprint status to `in-progress`, record `started_date`.

---

## Phase 2: CREATE TEAM AND TASKS — Spawn Agents with Worktree Isolation

### 2.1 Create Development Team

Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-dev`.

### 2.2 Determine Required Agents

Based on story assignments, spawn only the agents that have stories:

| Agent Name | Role | Worktree Branch |
|---|---|---|
| `backend-dev` | Schemas, APIs, stores, services, cloud functions | `sprint-${N}/backend` |
| `frontend-dev` | Components, pages, layouts, navigation, styles | `sprint-${N}/frontend` |
| `test-writer` | Unit tests, integration tests, e2e tests | `sprint-${N}/tests` |
| `infra-dev` | Infrastructure, CI/CD, deployment (if stories exist) | `sprint-${N}/infra` |

### 2.3 Create Worktrees

For each agent, create an isolated git worktree:
```bash
git worktree add -b sprint-${SPRINT_NUMBER}/<role> .worktrees/<role> HEAD
```

### 2.4 Spawn Agents

For each agent, send spawn instructions via `SendMessage`. Include:
1. Agent role and responsibilities (see reference.md for prompt templates).
2. Working directory (worktree path).
3. List of assigned stories in dependency order.
4. Project conventions (detected stack, coding patterns, naming conventions).
5. Commit message format: `feat(sprint-${N}/<role>): S${N}-XXX <description>`.

### 2.5 Create Tasks with Dependency Ordering

For each story, create a task using `TaskCreate`:
- Title: `S${N}-XXX: <story title>`
- Assigned to: the appropriate agent
- Dependencies: mapped from story `depends_on`
- Status: `pending` (or `ready` if no dependencies)

### 2.6 Send Initial Instructions

Send each agent their first batch of **ready** stories (no unmet dependencies). Include full story content.

### 2.7 Track Agent State

Maintain an in-memory tracker:
```
agent_tracker = {
  "<agent-name>": {
    "agent_id": "<id>",
    "status": "active",      // active | stuck | completed
    "current_story": "S1-003",
    "completed": ["S1-001"],
    "failed_attempts": 0,    // circuit breaker counter
    "worktree": ".worktrees/<role>"
  }
}
```

**Circuit breaker:** If an agent fails the same story 3 times, mark the story as `blocked`, notify the orchestrator, and move the agent to the next available story.

---

## Phase 3: IMPLEMENT — Monitor and Coordinate

### 3.1 Agent Work Loop

Each agent follows this loop for each assigned story:

1. **Read story** — Parse frontmatter and body.
2. **Implement** — Create/modify files as specified. Follow implementation notes and code snippets.
3. **Type-check** — Run type-check in their worktree:
   ```bash
   cd <worktree> && npm run type-check 2>&1
   ```
4. **Commit** — If type-check passes:
   ```bash
   git add -A && git commit -m "feat(sprint-${N}/<role>): S${N}-XXX <title>"
   ```
5. **Complete** — Update task status to `completed` via `TaskUpdate`.
6. **Next** — Request next story from orchestrator.

### 3.2 Orchestrator Monitoring Loop

The orchestrator (you) must:

1. **Poll progress** every 2-3 agent messages. Use `TaskList` to check status.
2. **Unblock stories** — When a dependency completes, send newly-ready stories to the appropriate agent.
3. **Coordinate via SendMessage** — When an agent completes a story that another agent depends on:
   ```
   SendMessage to <waiting-agent>:
   UNBLOCK: S${N}-XXX is complete. You can now start S${N}-YYY.
   Files created: <list>. Key exports: <list>.
   ```
4. **Handle stuck agents** — If an agent reports errors or makes no progress:
   - Send a `ASSIST:` message with hints from other agents' completed work.
   - If still stuck after 2 assists, invoke circuit breaker.

### 3.3 Cross-Agent Communication Protocol

Agents communicate through the orchestrator using prefixed messages:

| Prefix | Direction | Purpose |
|---|---|---|
| `DONE:` | Agent -> Orchestrator | Story completed, requesting next |
| `BLOCKED:` | Agent -> Orchestrator | Cannot proceed, needs help |
| `UNBLOCK:` | Orchestrator -> Agent | Dependency resolved, new story available |
| `ASSIST:` | Orchestrator -> Agent | Help with current issue |
| `SYNC:` | Orchestrator -> Agent | File paths or exports from another agent |
| `HALT:` | Orchestrator -> Agent | Stop current work (critical issue) |

### 3.4 Story Distribution Rules

Stories are sent to agents in this priority order:

| Priority | Story Type | Rationale |
|---|---|---|
| 1 | Schema / type definitions | Everything else depends on types |
| 2 | Server functions / API routes | Backend logic before frontend |
| 3 | Stores / state management | Data layer before UI |
| 4 | Components / pages | UI after data layer exists |
| 5 | Navigation / layout integration | After components exist |
| 6 | Tests | After implementation is stable |

Within same priority, higher `priority` field stories go first, then lower `points` (smaller stories first).

---

## Phase 3.5: UI/UX INTEGRATION (MANDATORY)

This phase is **mandatory** and must not be skipped, even if no explicit UI stories exist.

### 3.5.1 Spawn Integration Agent

After all `frontend-dev` stories are complete (or in parallel with final frontend stories), spawn or reuse an agent for integration work:

Agent: `frontend-dev` (reuse) or `ui-integrator` (new)

### 3.5.2 Integration Checklist

The integration agent must verify and implement:

1. **Navigation entries** — Any new pages/routes have corresponding nav entries in the app's navigation config.
2. **Design tokens** — New components use existing design tokens (colors, spacing, typography). No hardcoded values.
3. **Layout consistency** — New pages use the correct layout wrapper. Responsive breakpoints match existing patterns.
4. **State wiring** — All new stores are properly initialized. Composables are registered where framework requires it.
5. **Accessibility** — New interactive elements have proper ARIA attributes, keyboard navigation, focus management.
6. **Loading states** — Async operations show loading indicators. Error states are handled.
7. **Route guards** — Protected routes have appropriate auth guards if the project uses authentication.

### 3.5.3 Integration Commit

```bash
git add -A && git commit -m "feat(sprint-${N}/integration): UI/UX integration pass"
```

---

## Phase 4: INTEGRATE — Merge and Verify

### 4.1 Merge Worktree Branches

Merge each agent's branch into the sprint branch:
```bash
git checkout -b sprint-${SPRINT_NUMBER}/merged
git merge sprint-${SPRINT_NUMBER}/backend --no-edit
git merge sprint-${SPRINT_NUMBER}/frontend --no-edit
git merge sprint-${SPRINT_NUMBER}/tests --no-edit
# Handle merge conflicts if any
```

### 4.2 Full Build Verification

Run complete verification suite:
```bash
npm run type-check 2>&1
npm run lint 2>&1
npm run test 2>&1       # or test runner equivalent
npm run build 2>&1
```

### 4.3 Fix Integration Issues

If verification fails:
1. Categorize errors (type errors, import errors, test failures, build errors).
2. Fix systematically — types first, then imports, then logic, then tests.
3. Max 5 fix iterations. If still failing, report remaining issues.
4. Commit each fix round:
   ```bash
   git commit -m "fix(sprint-${N}): resolve integration issues — round ${ROUND}"
   ```

### 4.4 Clean Up Worktrees

```bash
git worktree remove .worktrees/backend 2>/dev/null
git worktree remove .worktrees/frontend 2>/dev/null
git worktree remove .worktrees/tests 2>/dev/null
git worktree remove .worktrees/infra 2>/dev/null
```

### 4.5 Shutdown Team

Gracefully shutdown the development team. Send `HALT:` to any remaining agents.

### 4.6 Update Sprint Registry

Update `sprint-registry.json`:
```json
{
  "number": <N>,
  "status": "review",
  "completed_date": "<ISO-8601>",
  "stories_completed": <count>,
  "stories_blocked": <count>,
  "integration_issues": <count>
}
```

### 4.7 Update Story Statuses

For each story file, update frontmatter `status`:
- `done` — Implemented and passes verification.
- `incomplete` — Partially implemented or has failing tests.
- `blocked` — Could not be completed (circuit breaker triggered).

### 4.8 Final Commit

```bash
git add -A
git commit -m "feat(sprint-${N}): complete sprint implementation — ${COMPLETED}/${TOTAL} stories"
```

### 4.9 Final Output

Print summary to user:

```
Sprint ${SPRINT_NUMBER} implementation complete.
- Stories completed: X/Y
- Stories blocked: Z
- Build status: PASS/FAIL
- Type-check: PASS/FAIL (N errors)
- Tests: X passed, Y failed
- Integration issues fixed: N
- Branch: sprint-${SPRINT_NUMBER}/merged
```

---

## Error Recovery

- **Worktree creation fails**: Fall back to branch-only isolation (agents work on branches, merge sequentially).
- **Agent unresponsive**: After 3 message attempts with no response, mark agent as failed. Reassign stories to another agent or handle directly.
- **Merge conflicts**: Attempt auto-resolution for trivial conflicts (added-added in different sections). For complex conflicts, present to user with context from both sides.
- **Build fails after merge**: Systematically fix by category. If unfixable in 5 rounds, create a detailed issue list and ask user for guidance.
- **All agents stuck**: Likely a fundamental design issue. Report the common blocker and ask user to intervene.
