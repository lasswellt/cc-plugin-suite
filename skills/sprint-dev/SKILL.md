---
name: sprint-dev
description: Implements planned sprints with coordinated agent teams. Spawns backend-dev, frontend-dev, and test-writer agents in isolated worktrees. Distributes stories as tasks with dependency ordering and monitors progress. Use when user says "implement sprint", "develop stories", "start coding".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, TeamCreate, SendMessage, TaskCreate, TaskUpdate, TaskList
disable-model-invocation: false
model: opus
compatibility: ">=2.1.71"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For agent prompt templates, coordination patterns, and story distribution rules, see [reference.md](reference.md)
- For checkpoint/resume behavior, see [checkpoint-protocol.md](/_shared/checkpoint-protocol.md)
- For agent deviation handling, see [deviation-protocol.md](/_shared/deviation-protocol.md)
- For context window hygiene, see [context-management.md](/_shared/context-management.md)
- For the carry-forward registry (written on story completion in Phase 3.2), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)

---

# Sprint Development Skill

Implement a planned sprint by spawning coordinated agent teams in isolated worktrees, distributing stories as tasks with dependency ordering, and monitoring progress through completion. Execute every phase in order. Do NOT skip phases.

## Execution Mode

Check for a `--mode` flag. If not specified, default to `autonomous`. **If autonomy is `high` or `full` (e.g., loop mode with bypass permissions), always override to `autonomous` regardless of the `--mode` flag.**

| Mode | Behavior |
|---|---|
| `autonomous` | Default. Orchestrator manages everything. No pauses except for errors. |
| `checkpoint` | Pause after each wave completion. Present wave results to user, ask for confirmation before starting next wave. Allows user to review progress incrementally. |
| `interactive` | Present each story to the user before assigning it to an agent. Ask for approach confirmation. Pair-programming style. |

---

## Phase 0: CONTEXT — Load Project State

0. **Register session.** Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, agent spawn, story distribution, and progress dashboard per verbose-progress.md.
1. **Check for checkpoint (STATE.md).** Before anything else, check if the target sprint has a `STATE.md` file:
   ```bash
   SPRINT_DIR="sprints/sprint-${SPRINT_NUMBER}"
   cat "${SPRINT_DIR}/STATE.md" 2>/dev/null | head -5
   ```
   If STATE.md exists, follow the **resume flow** from [checkpoint-protocol.md](/_shared/checkpoint-protocol.md):
   - Validate staleness (>24h = warn user, ask whether to resume or start fresh). **If autonomy is `high` or `full` (e.g., loop mode), skip the staleness prompt and auto-resume regardless of age.** Log a `decision` event noting the auto-resume.
   - Validate worktrees (`git worktree list`).
   - Rebuild `agent_tracker` from STATE.md tables.
   - Skip to Phase 3 with remaining stories.
   - Log a `decision` event: "Resuming sprint ${N} from checkpoint".

   If STATE.md does not exist, continue with normal flow.

1b. **Check for incomplete sprints.** Search for `sprint-registry.json` and check for sprints with `status: in-progress`. If one exists, resume it (skip to Phase 1 with that sprint). Warn the user. *(If autonomy is `high` or `full`, log the warning and auto-resume without prompting.)*
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

## Phase 0.5: DISCOVER — Learn Project Conventions

Before any agent writes code, research the codebase to build a conventions guide.

### 0.5.1 Read Representative Files

Read 2-3 existing files from each layer:
- **Backend**: Cloud functions, Zod schemas, services
- **Stores**: Pinia stores, composables
- **Pages/Components**: Vue pages, feature components
- **Tests**: Unit tests, integration tests

### 0.5.2 Build Conventions Guide

From the files read, document:
- **Auth pattern**: How auth is checked (middleware, per-function, etc.)
- **Error format**: How errors are structured and returned
- **Response shape**: Standard response envelope
- **Validation approach**: Zod, Joi, or manual — and where schemas live
- **Component style**: Script setup, Options API, or mixed
- **CSS approach**: Tailwind, Quasar, Vuetify, or scoped CSS
- **Store pattern**: Setup syntax vs options syntax, naming conventions
- **Loading UI**: Skeleton loaders, spinners, or conditional rendering
- **Test structure**: AAA, BDD, or custom — describe/it nesting style
- **File naming**: kebab-case, camelCase, PascalCase per directory

### 0.5.3 Identify Reusable Assets

Search for existing composables, utilities, and shared components:
```bash
find . -path '*/composables/*' -o -path '*/utils/*' -o -path '*/shared/*' -o -path '*/components/base/*' | grep -v node_modules | head -30
```

Build a **REUSE THESE — do not recreate** list with file paths and what each provides.

**Gate:** Conventions guide must be complete before spawning agents.

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

### 1.4 Build Dependency Graph and Compute Waves

Construct a DAG from story `depends_on` fields. Then compute execution waves:

1. **Wave 0**: All stories with no dependencies (can start immediately).
2. **Wave N**: All stories whose dependencies are ALL in Waves 0..N-1.
3. **Critical path**: Longest dependency chain (determines minimum wave count).

Print the wave execution plan:
```
[sprint-dev] Wave Execution Plan:
  Wave 0 (parallel): S${N}-001, S${N}-002, S${N}-008 (schemas + types)
  Wave 1 (parallel): S${N}-003, S${N}-004 (backend logic, depends on Wave 0)
  Wave 2 (parallel): S${N}-005, S${N}-007 (frontend + tests, depends on Wave 1)
  Critical path: S${N}-001 → S${N}-004 → S${N}-005 (3 waves minimum)
```

Also identify:
- **Ready stories**: Wave 0 stories (can start immediately).
- **Blocked stories**: Stories in Wave 1+ (have dependencies that are not yet complete).

### 1.5 Load Carry-Forward Items

If the manifest has `carry_forward` entries, load those stories and add them to the graph.

### 1.6 Update Sprint Status

**Registry Lock — `sprint-registry.json`**: Before writing, acquire a file-based lock per [session-protocol.md](/_shared/session-protocol.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `sprint-registry.json.lock` and append `lock_released` to the operation log.

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

### 2.3 Spawn Agents with Worktree Isolation

Spawn each agent using the `Agent` tool with `isolation: "worktree"`. This gives each agent an isolated git worktree that is automatically cleaned up if no changes are made.

```
Agent(
  name: "<role>",
  subagent_type: "blitz:<role>",
  team_name: "sprint-${SPRINT_NUMBER}-dev",
  isolation: "worktree",
  prompt: "<agent instructions — see below>"
)
```

**Note:** The `isolation: "worktree"` parameter replaces manual `git worktree add` commands. Each agent gets its own branch and working directory automatically. Worktrees with no changes are auto-cleaned on agent completion; worktrees with changes are preserved for merging.

**Weight class**: Heavy (per [spawn-protocol.md](/_shared/spawn-protocol.md)). Dev agents implement multiple stories with reads+writes+verify per story.

**Per-wave story cap (CRITICAL)**: distribute at most **4 stories per agent per wave**. If a single wave assigns more than 4 stories to any one agent, split the excess to the next wave — even if this creates an otherwise-empty wave. A 6-story agent needs ~54 tool calls (5 reads + 3 writes + 1 verify × 6), well past the ~20/turn server cap.

Include in the agent prompt:
1. Agent role and responsibilities (see reference.md for prompt templates).
2. List of assigned stories in dependency order, with their `verify` and `done` fields. Capped at 4 stories per wave per agent.
3. **Budget declaration** (add verbatim to prompt):
   ```
   BUDGET:
   - Max stories this wave: 4 (already enforced by orchestrator)
   - Max file reads per story: 6
   - Max tool calls total: 40 (if you hit 30, finish current story and stop)
   - Wall-clock: 8 min
   ```
4. Project conventions (detected stack, coding patterns, naming conventions).
5. Commit message format: `feat(sprint-${N}/<role>): S${N}-XXX <description>`.
6. Project conventions guide from Phase 0.5 (full text, not a file reference).
7. Reusable assets list — composables, utilities, and shared components agents must use.
8. Anti-mock rules — Every function must be fully implemented, no placeholders. See [Definition of Done](/_shared/definition-of-done.md).
9. Deviation handling rules — Follow the [Deviation Handling Protocol](/_shared/deviation-protocol.md). Auto-fix small issues, report deviations, escalate architectural changes.
10. Wave assignment — Tell each agent which wave their stories belong to, so they understand the execution order context.
11. Context management rules — Follow the [Context Management Protocol](/_shared/context-management.md). Self-contained DONE summaries, reference files by path not memory, compact verification output, prune context between stories.
12. **HEARTBEAT + PARTIAL protocol** (add verbatim to prompt):
    ```
    HEARTBEAT: After each story DONE, write a file ${SESSION_TMP_DIR}/agent-<role>-progress.md
    appending: HEARTBEAT: S${N}-XXX done at <ISO-timestamp>. Use date -u +%Y-%m-%dT%H:%M:%SZ.

    PARTIAL: If you have fewer than 3 tool calls remaining, STOP before starting
    a new story. Append to your progress file:
      PARTIAL: true
      COMPLETED: [list of story ids finished]
      REMAINING: [list of story ids unstarted]
      CONFIDENCE: low|medium|high
    Send PARTIAL: <N> done, <M> remaining to orchestrator via the DONE/BLOCKED
    protocol and end.
    ```

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
    "failed_attempts": 0     // circuit breaker counter
  }
}
```

Worktree paths are managed by the Agent tool's `isolation: "worktree"` parameter and do not need manual tracking.

**Circuit breaker:** If an agent fails the same story 3 times, mark the story as `blocked`, notify the orchestrator, and move the agent to the next available story.

---

## Phase 3: IMPLEMENT — Monitor and Coordinate

### 3.1 Agent Work Loop

Each agent follows this loop for each assigned story:

1. **Read story** — Parse frontmatter and body. Note `verify` and `done` fields if present.
2. **Implement** — Create/modify files as specified. Follow implementation notes and code snippets. Follow the [Deviation Handling Protocol](/_shared/deviation-protocol.md) for unexpected issues.
3. **Verify** — Run the story's `verify` commands if defined. If no `verify` field, fall back to type-check:
   ```bash
   # If story has verify commands, run each one:
   cd <worktree> && <verify_command_1> && <verify_command_2> ...
   # Otherwise fall back to generic type-check:
   cd <worktree> && npm run type-check 2>&1
   ```
4. **Check done criteria** — Verify the story's `done` field is satisfied (all stated conditions are met).
5. **Commit** — If verification passes:
   ```bash
   git add -A && git commit -m "feat(sprint-${N}/<role>): S${N}-XXX <title>"
   ```
6. **Complete** — Update task status to `completed` via `TaskUpdate`.
7. **Next** — Request next story from orchestrator.

### 3.2 Orchestrator Monitoring Loop

The orchestrator (you) must:

1. **Poll progress** every 2-3 agent messages. Use `TaskList` to check status. Track wave-level completion — when all stories in a wave complete, print a wave progress report per [verbose-progress.md](/_shared/verbose-progress.md) and unblock all Wave N+1 stories.
1a. **Write carry-forward registry progress on story `DONE:`.** When an agent signals `DONE:` for a story, before updating STATE.md, check the completed story's frontmatter for a `registry_entries` field (see `skills/sprint-plan/reference.md` Story File Format). For each referenced entry:

    a. **Validate the id.** Reduce the registry with `jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl` and confirm the id exists and is `status ∈ {active, partial}`. If the id is unknown → hard-fail with a loud error (the story's `registry_entries` references a non-existent entry — the author must fix the story). If the status is already `complete|dropped|deferred` → log a warning, skip the write, and continue (the story is working against a closed entry, which may indicate stale planning).

    b. **Compute the new `delivered.actual`.** Read the current latest-wins line for the entry. Add the story's `delta` (or `len(story.files)` if `delta` is omitted). Clamp at `scope.target` so coverage cannot exceed 1.0.

    c. **Determine the new `status`.** If `new_actual >= scope.target` → `status: complete`. Else → `status: partial`. Precompute `coverage = new_actual / scope.target`.

    d. **Append a `progress` line** to `.cc-sessions/carry-forward.jsonl`:
       ```jsonl
       {"id":"<registry-id>","ts":"<ISO-8601>","event":"progress","delivered":{"unit":"<unit>","actual":<new_actual>,"last_sprint":"sprint-${SPRINT_NUMBER}"},"coverage":<computed>,"status":"<partial|complete>","last_touched":{"sprint":"sprint-${SPRINT_NUMBER}","date":"<ISO-8601>"},"children":["<story-id>"],"notes":"Advanced by <story-id> (delta: <delta>)"}
       ```

    e. **Log the activity-feed mirror:**
       ```jsonl
       {"ts":"<ISO-8601>","session":"${SESSION_ID}","skill":"sprint-dev","event":"registry_progress","message":"Story <story-id> advanced <registry-id> by <delta> (coverage <old> → <new>)","detail":{"story_id":"<story-id>","registry_id":"<registry-id>","delta":<delta>,"coverage":<new>}}
       ```

    **Inference fallback:** if a completed story has no `registry_entries` field but its parent epic has non-empty `registry_entries` in `epic-registry.json`, infer the link with `delta: 1` for each entry, and tag the `notes` as `"Inferred from parent epic; explicit delta recommended"`. This prevents silent zero-progress on stories whose authors forgot to set the field, but it's strictly a safety net — the `TaskUpdate` that transitions the task to `completed` should print a one-line warning in the orchestrator log noting the inference.

    **No-op path:** stories with no `registry_entries` AND a parent epic with no `registry_entries` get no write. This is normal — not every story is linked to a quantified scope entry. Infrastructure stories, test-only stories, and spike outcomes often fall into this bucket.

1b. **Update STATE.md** — After each story completion (or at wave boundaries), update `${SPRINT_DIR}/STATE.md` per [checkpoint-protocol.md](/_shared/checkpoint-protocol.md). This enables session recovery if interrupted. Include wave progress.
1c. **Commit and push at wave boundaries** — When a wave completes, commit all changes and push to the remote. This ensures progress is persisted and visible to other sessions (especially in `/loop` mode where the next tick runs in a fresh context):
   ```bash
   git add -A
   git commit -m "feat(sprint-${N}): wave ${WAVE} complete — ${COMPLETED}/${TOTAL} stories"
   git push origin HEAD
   ```
   Also push after each integration fix round (Phase 4.3) and at sprint completion (Phase 4.9).
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
5. **Context hygiene** — Follow the [Context Management Protocol](/_shared/context-management.md):
   - Summarize agent completions (files + exports), don't relay full output.
   - Print compact progress at wave boundaries (every wave completion).
   - Offload progress to STATE.md rather than keeping it all in context.
   - If context monitor warns at ~60%+, write checkpoint and summarize.

### 3.3 Cross-Agent Communication Protocol

Agents communicate through the orchestrator using prefixed messages:

| Prefix | Direction | Purpose |
|---|---|---|
| `DONE:` | Agent -> Orchestrator | Story completed, requesting next |
| `BLOCKED:` | Agent -> Orchestrator | Cannot proceed, needs help |
| `DEVIATION:` | Agent -> Orchestrator | Auto-added code outside story scope (see [deviation-protocol.md](/_shared/deviation-protocol.md)) |
| `ESCALATE:` | Agent -> Orchestrator | Needs decision on architectural/scope change (see [deviation-protocol.md](/_shared/deviation-protocol.md)) |
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

## Phase 3.5: INTEGRATION CHECKS AND UI/UX PASS (MANDATORY)

This phase is **mandatory** and must not be skipped, even if no explicit UI stories exist.

### 3.5.0 Run Integration Check (Optional)

Before the UI/UX pass, optionally run `/blitz:integration-check` to verify cross-module wiring:
- Export-to-import tracing (are new exports consumed?)
- Route coverage (do new pages have navigation?)
- Store wiring (are new stores connected to components?)

If integration-check finds high-severity issues, address them before the UI pass.

### 3.5.1 Spawn Integration Agent

After all `frontend-dev` stories are complete (or in parallel with final frontend stories), spawn or reuse an agent for integration work:

Agent: `frontend-dev` (reuse) or `ui-integrator` (new)

**Weight class**: Medium (per [spawn-protocol.md](/_shared/spawn-protocol.md)).

**Spawn parameters**:
- `subagent_type: blitz:frontend-dev` (has Write + Edit — required for integration edits)
- `isolation: "worktree"` on a dedicated `sprint-${N}/integration` branch
- Budget declared in prompt: max 15 file reads, 25 tool calls, 5-min wall-clock
- Write-as-you-go: append a progress line to `${SESSION_TMP_DIR}/agent-ui-integrator-progress.md` after each checklist item completed
- HEARTBEAT protocol (same snippet as Phase 2.3 dev agents — 12th bullet)

**Fallback if agent fails**:
- If the integration agent exits without completing the Integration Checklist, the orchestrator MUST:
  1. Read the progress file to identify which checklist items completed.
  2. For remaining items: either re-spawn with narrower scope (single checklist item) OR complete inline from the orchestrator if the remaining work is <3 checklist items.
  3. Do NOT proceed to Phase 3.5.3 Integration Commit until every checklist item is confirmed done (either by agent or orchestrator) — a silent half-integration shipped to main has been the most common sprint-dev failure pattern.

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

### 4.2 Full Build Verification (Selective Re-Runs)

Run the initial full verification sweep:
```bash
npm run type-check 2>&1
npm run lint 2>&1
npm run test 2>&1       # or test runner equivalent
npm run build 2>&1
```

**After the first full sweep, use selective re-verification to save time:**

| Check | Re-run Strategy |
|-------|----------------|
| Type-check | Always re-run (full — type errors cascade) |
| Build | Always re-run (full — build errors cascade) |
| Tests | Re-run only tests in changed packages: `npm run test -- --filter <changed-packages>` |
| Lint | Re-lint only modified files: `npx eslint <modified-files>` |

Track time savings:
```
Verification: full sweep 45s → selective re-run 12s (73% faster)
```

The **final fix round** (last iteration of Phase 4.3) always gets one full sweep to catch any cross-package regressions.

### 4.2.5 Completeness Gate

Run the completeness gate on all files changed during the sprint:
```bash
# Collect all files modified in this sprint
CHANGED_FILES=$(git diff --name-only sprint-${SPRINT_NUMBER}/base..HEAD -- '*.ts' '*.tsx' '*.vue')
```
Invoke: `/blitz:completeness-gate` with the sprint's source directories.
If the score is below C (70), flag critical findings in the integration report but do not block — the sprint review will make the final call.

### 4.2.1 Cross-Phase Regression Testing

If `SPRINT_NUMBER > 1`, run regression tests from prior sprints to catch unintended breakage:

1. **Identify pre-existing test files:**
   ```bash
   # Find test files that existed before this sprint started
   git diff --name-only --diff-filter=A ${SPRINT_BASE}..HEAD -- '*.test.*' '*.spec.*' > ${SESSION_TMP_DIR}/new-tests.txt
   git ls-files '*.test.*' '*.spec.*' | grep -v -F -f ${SESSION_TMP_DIR}/new-tests.txt > ${SESSION_TMP_DIR}/pre-existing-tests.txt
   ```

2. **Run pre-existing tests selectively:**
   ```bash
   # Run only pre-existing tests (not new sprint tests)
   cat ${SESSION_TMP_DIR}/pre-existing-tests.txt | xargs npx vitest run --reporter=verbose 2>&1
   ```

3. **Flag regressions as Critical:**
   Any pre-existing test that now fails is a **Critical** regression. These take priority over new test failures.

4. **Attempt fix (max 2 rounds):**
   - Round 1: Analyze the regression. If the new code changed behavior intentionally, the old test needs updating. If the change was unintentional, fix the new code.
   - Round 2: If still failing, document the regression and flag for manual review.

5. **Report:**
   ```
   Cross-Phase Regression:
     Pre-existing tests: N
     Still passing: M
     Regressions found: K (Critical)
     Fixed: J
     Remaining: K-J (requires manual review)
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

If agents were spawned with `isolation: "worktree"`, worktrees with no changes are automatically cleaned up when agents complete. For worktrees that persist (because they have changes):

1. List remaining worktrees: `git worktree list`
2. After successful merge (Phase 4.1), remove merged worktrees:
   ```bash
   for ROLE in backend frontend tests infra; do
     WT=".worktrees/sprint-${SPRINT_NUMBER}/${ROLE}"
     if [ -d "$WT" ]; then
       git worktree remove "$WT" --force 2>&1 || \
         echo "WARNING: Could not remove worktree $WT — check for uncommitted changes"
     fi
   done
   ```
3. Log any removal failures to the activity feed as `warning` events.

### 4.5 E2E Verification (Best-Effort)

After build verification passes, run an automated browser smoke test if Playwright MCP is available:

1. **Check availability**: Verify Playwright MCP tools are accessible.
2. **Start dev server**: `npm run dev &` (or equivalent). Wait for ready signal.
3. **Smoke test changed routes**: Identify changed page files from the diff. Navigate to the first 10 routes.
4. **Evaluate results**:
   - 0 Critical + 0 Error = **PASS**
   - 1+ Critical = **CONDITIONAL** — include findings in sprint report
   - 1+ Error only = **PASS with notes**
5. **Clean up**: Kill the dev server process.

Skip gracefully if Playwright is unavailable — document as a gap, not a failure.

### 4.6 Shutdown Team

Gracefully shutdown the development team. Send `HALT:` to any remaining agents.

### 4.7 Update Sprint Registry

**Registry Lock — `sprint-registry.json`**: Before writing, acquire a file-based lock per [session-protocol.md](/_shared/session-protocol.md):
1. CHECK if `sprint-registry.json.lock` exists — if stale (session completed/failed or >4h old with dead PID), delete it.
2. ACQUIRE by writing `sprint-registry.json.lock` with `{ "session_id": "${SESSION_ID}", "acquired": "<ISO-8601>" }`.
3. VERIFY by re-reading the lock file — confirm it contains YOUR `SESSION_ID`. If not, wait up to 60s (check every 5s), then ABORT with conflict report.
4. OPERATE — read, modify, and write the registry file.
5. RELEASE — delete `sprint-registry.json.lock` and append `lock_released` to the operation log.

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

### 4.8 Update Story Statuses

For each story file, acquire `<story-file>.lock` before modifying the status field, then release after writing. This prevents concurrent sprint-review from reading partially-updated statuses.

For each story file, update frontmatter `status`:
- `done` — Implemented and passes verification.
- `incomplete` — Partially implemented or has failing tests.
- `blocked` — Could not be completed (circuit breaker triggered).

### 4.8.5 Blocked Story Accountability

For every story marked `blocked`:

1. **Document WHY** it was blocked (circuit breaker details, specific errors, missing dependencies).
2. **Document what work WAS completed** and what REMAINS.
3. **Create carry-forward entry** in the manifest's `carry_forward` array.
4. **Sprint summary MUST include a prominent warning** with blocked count and story IDs.

**Never silently drop blocked stories.** They must be visible in the sprint report and carry forward to the next sprint.

### 4.9 Final Commit and Push

```bash
git add -A
git commit -m "feat(sprint-${N}): complete sprint implementation — ${COMPLETED}/${TOTAL} stories"
git push origin HEAD
```

### 4.10 Final Output

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
- **Merge conflicts**: Attempt auto-resolution for trivial conflicts (added-added in different sections). For complex conflicts, present to user with context from both sides. *(If autonomy is `high` or `full`, attempt auto-resolution for all conflicts. If auto-resolution fails, mark the conflicting stories as `blocked`, log the conflict details to the activity feed and STATE.md, and continue with remaining stories.)*
- **Build fails after merge**: Systematically fix by category. If unfixable in 5 rounds, create a detailed issue list and ask user for guidance. *(If autonomy is `high` or `full`, log the issue list to STATE.md and the activity feed, mark the sprint as `review` with integration issues noted, and exit. The next `/loop` tick or manual review will handle it.)*
- **All agents stuck**: Likely a fundamental design issue. Report the common blocker and ask user to intervene. *(If autonomy is `high` or `full`, mark all remaining stories as `blocked` with reason "all agents stuck", write STATE.md checkpoint, update sprint status to `review` with blocked stories noted, log to activity feed, and exit cleanly.)*
