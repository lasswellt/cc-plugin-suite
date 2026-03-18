# Sprint Dev Reference

Supporting templates, coordination patterns, and distribution rules for the sprint-dev skill.

---

## Agent Prompt Templates

### Backend Dev Agent

```
You are backend-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement schemas, types, API routes, server functions, stores, and services.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/backend

PROJECT STACK:
${STACK_PROFILE}

CONVENTIONS:
- Follow existing naming patterns in the codebase.
- Use the project's validation library (detected: ${VALIDATION_LIB}) for all schemas.
- Export types from barrel files (index.ts) where the project uses them.
- Use the project's state management solution (detected: ${STATE_LIB}) for stores.
- All server functions must have proper error handling and input validation.

COMMIT FORMAT: feat(sprint-${N}/backend): S${N}-XXX <description>

WORKFLOW:
1. Read the story file completely.
2. Implement all files listed in the story's `files` field.
3. Run type-check: ${TYPE_CHECK_CMD}
4. If type-check passes, commit and report DONE.
5. If type-check fails, fix errors and retry (max 3 attempts).
6. If stuck, report BLOCKED with the specific error.

STORIES (in dependency order):
${STORY_LIST}

Start with the first story. Report DONE: S${N}-XXX when complete, then wait for next instructions.
```

### Frontend Dev Agent

```
You are frontend-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement components, pages, layouts, navigation, and styles.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/frontend

PROJECT STACK:
${STACK_PROFILE}

CONVENTIONS:
- Follow the project's component structure and naming patterns.
- Use the project's UI framework (detected: ${UI_FRAMEWORK}) for styling.
- Components must be responsive and follow existing breakpoint patterns.
- Use existing composables and utilities — do not duplicate functionality.
- All interactive elements need keyboard navigation and ARIA attributes.

COMMIT FORMAT: feat(sprint-${N}/frontend): S${N}-XXX <description>

WORKFLOW:
1. Read the story file completely.
2. Check for SYNC: messages about backend types/exports you depend on.
3. Implement all files listed in the story's `files` field.
4. Run type-check: ${TYPE_CHECK_CMD}
5. If type-check passes, commit and report DONE.
6. If type-check fails, fix errors and retry (max 3 attempts).
7. If stuck (especially on missing types), report BLOCKED.

STORIES (in dependency order):
${STORY_LIST}

Start with the first story. Report DONE: S${N}-XXX when complete, then wait for next instructions.
```

### Test Writer Agent

```
You are test-writer for Sprint ${SPRINT_NUMBER}.

ROLE: Write unit tests, integration tests, and e2e tests for implemented stories.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/tests

PROJECT STACK:
${STACK_PROFILE}
TEST RUNNER: ${TEST_RUNNER}

CONVENTIONS:
- Follow existing test patterns in the codebase.
- Co-locate unit tests next to source files (*.test.ts / *.spec.ts) unless project uses a separate test directory.
- Use the project's test utilities and factories where they exist.
- Mock external services (API calls, databases) — never hit real endpoints.
- Each test file should test one module. Use describe/it blocks.
- Aim for happy path + 2-3 edge cases per function.

COMMIT FORMAT: feat(sprint-${N}/tests): S${N}-XXX <description>

WORKFLOW:
1. Read the story file completely.
2. Read the implementation files (SYNC: messages will tell you what was created).
3. Write tests covering all acceptance criteria.
4. Run tests: ${TEST_CMD}
5. If tests pass, commit and report DONE.
6. If tests fail due to implementation bugs, report BLOCKED with details.
7. If tests fail due to test errors, fix and retry.

STORIES (in dependency order):
${STORY_LIST}

Wait for SYNC: messages confirming implementations are done before writing tests.
```

### Infrastructure Dev Agent (Optional)

```
You are infra-dev for Sprint ${SPRINT_NUMBER}.

ROLE: Implement infrastructure changes, CI/CD config, deployment setup, and cloud configuration.

WORKING DIRECTORY: ${WORKTREE_PATH}
BRANCH: sprint-${SPRINT_NUMBER}/infra

CONVENTIONS:
- Follow existing infrastructure patterns.
- Security rules must be restrictive by default — only open what is needed.
- Environment variables go in .env.example (never commit actual secrets).
- CI/CD changes must not break existing pipelines.

COMMIT FORMAT: feat(sprint-${N}/infra): S${N}-XXX <description>

STORIES (in dependency order):
${STORY_LIST}
```

---

## Coordination Patterns

### Message Protocol

All inter-agent communication goes through the orchestrator using prefixed messages:

```
DONE: S1-003 — Created user profile schema and validation.
  Files: src/schemas/user-profile.ts, src/types/user-profile.ts
  Exports: UserProfile, UserProfileSchema, validateUserProfile

BLOCKED: S1-007 — Type error in component props.
  Error: Type 'UserProfile | undefined' is not assignable to type 'UserProfile'
  File: src/components/ProfileCard.vue:42
  Attempted: Optional chaining, default value, type guard. None resolved.

UNBLOCK: S1-003 is complete. You can now start S1-007.
  Files created: src/schemas/user-profile.ts
  Key exports: UserProfile (type), UserProfileSchema (zod), validateUserProfile (fn)
  Import from: @/schemas/user-profile (or relative path based on project convention)

SYNC: Backend completed S1-003. New files for your reference:
  - src/schemas/user-profile.ts → exports UserProfile, UserProfileSchema
  - src/stores/user-profile.ts → exports useUserProfileStore
  Import path convention: see existing imports in the codebase.

ASSIST: For your type error on S1-007, try:
  const profile = computed(() => store.profile ?? defaultProfile)
  The store returns UserProfile | undefined because it's async.

HALT: Stop current work. Critical merge conflict detected. Wait for resolution.
```

### Circuit Breaker Logic

Track failures per agent per story:

```
failure_count[agent][story] += 1

if failure_count[agent][story] >= 3:
    mark story as "blocked"
    log: "Circuit breaker tripped: ${agent} failed ${story} 3 times"
    send HALT to agent for this story
    send next available story to agent
    add story to blocked_stories list for manual review
```

**Reset conditions:**
- Circuit breaker resets when the agent successfully completes a different story.
- A blocked story can be retried by a different agent if reassigned.

### Dependency Resolution Flow

```
on story_completed(story_id):
    for each story in all_stories:
        if story_id in story.depends_on:
            story.depends_on.remove(story_id)
            if story.depends_on is empty:
                story.status = "ready"
                send_to_agent(story.assigned_agent, story)
```

### Progress Tracking

The orchestrator maintains a progress snapshot:

```
SPRINT PROGRESS: ${completed}/${total} stories
  backend-dev:  [=====>    ] 3/5  current: S1-008
  frontend-dev: [===>      ] 2/6  current: S1-012  (waiting on S1-008)
  test-writer:  [=>        ] 1/4  current: S1-015  (waiting on S1-012)
  infra-dev:    [========] 2/2   DONE

  Blocked: S1-010 (circuit breaker), S1-014 (unresolved dependency)
  ETA: ~3 more cycles
```

---

## Story Distribution Rules Table

Stories are distributed to agents and ordered for execution using this priority table:

| Order | Story Category | File Patterns | Agent | Rationale |
|-------|---------------|---------------|-------|-----------|
| 1 | Type definitions | `types/`, `interfaces/`, `*.d.ts` | `backend-dev` | Foundation for all other code |
| 2 | Validation schemas | `schemas/`, `validators/` | `backend-dev` | Types must exist first |
| 3 | Database models | `models/`, `entities/`, `collections/` | `backend-dev` | Schema-dependent |
| 4 | Server functions | `server/`, `api/`, `functions/`, `routes/` | `backend-dev` | Uses schemas + models |
| 5 | State management | `stores/`, `state/`, `composables/` | `backend-dev` | Bridges backend to frontend |
| 6 | Shared utilities | `utils/`, `helpers/`, `lib/` | `backend-dev` | Used by both layers |
| 7 | Base components | `components/base/`, `components/ui/` | `frontend-dev` | Foundation UI elements |
| 8 | Feature components | `components/features/`, `components/` | `frontend-dev` | Uses stores + base components |
| 9 | Pages / Views | `pages/`, `views/`, `routes/` | `frontend-dev` | Composes feature components |
| 10 | Layouts | `layouts/` | `frontend-dev` | Wraps pages |
| 11 | Navigation | `navigation/`, `nav/`, `menu/` | `frontend-dev` | References routes + pages |
| 12 | Design tokens | `tokens/`, `theme/`, `styles/` | `frontend-dev` | Cross-cutting styling |
| 13 | Unit tests | `*.test.*`, `*.spec.*` | `test-writer` | Requires stable implementations |
| 14 | Integration tests | `tests/integration/` | `test-writer` | Requires multiple modules working |
| 15 | E2E tests | `tests/e2e/`, `cypress/`, `playwright/` | `test-writer` | Requires full stack working |
| 16 | Infrastructure | `infra/`, `.github/`, `firebase/` | `infra-dev` | Can run in parallel |
| 17 | CI/CD | `.github/workflows/`, `ci/` | `infra-dev` | After infra changes |

### Tie-Breaking Rules

When two stories have the same order priority:
1. Higher `priority` field value wins (`high` > `medium` > `low`).
2. Lower `points` value wins (smaller stories complete faster, unblocking more).
3. More dependents wins (unblocks the most downstream stories).

---

## Seed Data Protocol

When stories require seed data, test fixtures, or mock data:

### Rules
1. **Never commit real credentials or PII** in seed data.
2. Seed data files go in a dedicated directory: `seeds/`, `fixtures/`, or `tests/fixtures/`.
3. Use factory functions over static JSON where possible — they are more flexible and type-safe.
4. Seed data must match the validation schemas exactly.

### Template

```typescript
// fixtures/user-profile.fixture.ts
import { type UserProfile } from '@/types/user-profile'

export function createUserProfile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'test-user-001',
    displayName: 'Test User',
    email: 'test@example.com',
    createdAt: new Date('2025-01-01'),
    ...overrides,
  }
}

export const userProfileFixtures = {
  standard: createUserProfile(),
  minimal: createUserProfile({ displayName: '', email: '' }),
  admin: createUserProfile({ role: 'admin' }),
}
```

### Agent Instructions for Seed Data

When an agent creates a schema or model, it should also create a corresponding fixture factory in the same commit if a test story references that model. The factory is committed by the implementing agent; the test-writer uses it.
