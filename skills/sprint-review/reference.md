# Sprint Review Reference

Supporting templates, checklists, and rules for the sprint-review skill.

---

## Review Report Template

```markdown
# Sprint ${SPRINT_NUMBER} Review Report

**Date:** ${DATE}
**Status:** ${PASS | CONDITIONAL | FAIL}
**Reviewer:** Automated + Agent Team

---

## Executive Summary

Sprint ${SPRINT_NUMBER} implemented ${STORIES_DONE}/${STORIES_TOTAL} stories across
${EPIC_COUNT} epics. ${SUMMARY_SENTENCE}.

---

## Quality Gates

| Gate | Before Auto-Fix | After Auto-Fix | Status |
|------|----------------|----------------|--------|
| Type-check | ${N} errors | ${N} errors | PASS/FAIL |
| Lint | ${N} errors, ${N} warnings | ${N} errors, ${N} warnings | PASS/FAIL |
| Unit Tests | ${N}/${N} passed | ${N}/${N} passed | PASS/FAIL |
| Build | PASS/FAIL | PASS/FAIL | PASS/FAIL |

---

## Review Findings

### Critical (Must Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 42 | Description of critical issue | security-reviewer |

### Major (Should Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 88 | Description of major issue | backend-reviewer |

### Minor (Optional Fix)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 15 | Description of minor issue | pattern-reviewer |

### Info (Suggestions)

| # | File | Line | Finding | Reviewer |
|---|------|------|---------|----------|
| 1 | path/to/file.ts | 30 | Suggestion for improvement | frontend-reviewer |

---

## Auto-Fix Summary

| Category | Found | Fixed | Remaining | Skipped |
|----------|-------|-------|-----------|---------|
| Type errors | ${N} | ${N} | ${N} | ${N} |
| Lint errors | ${N} | ${N} | ${N} | ${N} |
| Import fixes | ${N} | ${N} | ${N} | ${N} |
| Missing exports | ${N} | ${N} | ${N} | ${N} |
| Naming issues | ${N} | ${N} | ${N} | ${N} |
| **Total** | **${N}** | **${N}** | **${N}** | **${N}** |

---

## Story Status

| Story ID | Title | Agent | Status | Notes |
|----------|-------|-------|--------|-------|
| S${N}-001 | Story title | backend-dev | done | — |
| S${N}-002 | Story title | frontend-dev | done | Minor lint issue |
| S${N}-003 | Story title | test-writer | incomplete | 2 tests failing |

---

## Recommendations

### Before Merge (Required)
1. ${ACTION_ITEM}

### Before Next Sprint (Recommended)
1. ${ACTION_ITEM}

### Future Improvements (Optional)
1. ${ACTION_ITEM}
```

---

## Quality Gate Checklist

Complete checklist of all automated quality gates with pass/fail criteria.

### Type-Check Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| TypeScript compilation | Zero errors (`tsc --noEmit` exits 0) | Any type error |
| Strict mode compliance | No `any` types introduced in new code | New `any` types without justification |
| Missing type exports | All public types exported from barrel files | Type used externally but not exported |

### Lint Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| ESLint errors | Zero errors | Any error (warnings are acceptable) |
| Auto-fixable issues | All auto-fixable issues resolved | Auto-fixable issues left unresolved |
| Custom rules | Project-specific rules pass | Project-specific rule violations |

### Test Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| Test execution | All tests run without crashes | Test runner crashes or hangs |
| Test pass rate | 100% pass (for changed packages) | Any test failure |
| Coverage (if configured) | No decrease in coverage | Coverage decreased |
| New code coverage | New files have at least one test | New files with zero tests |

### Build Gate

| Check | Pass Criteria | Fail Criteria |
|-------|--------------|---------------|
| Build completion | Build exits 0 | Build error |
| Bundle size (if configured) | Within configured limits | Exceeds limits |
| No runtime errors | Build output has no error markers | Build output contains errors |

---

## Auto-Fix Strategies by Error Category

### Type Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| `Type 'X' is not assignable to type 'Y'` | Add type assertion or fix the source type | `value as ExpectedType` or fix producer |
| `Property 'X' does not exist on type 'Y'` | Add property to interface or fix property name | Add to type definition |
| `Object is possibly 'undefined'` | Add null check or optional chaining | `obj?.property` or `if (obj) {}` |
| `Cannot find name 'X'` | Add missing import | `import { X } from './source'` |
| `Type 'X' is missing properties` | Add missing required properties | Add defaults or make optional |
| `Argument of type 'X' is not assignable` | Fix argument type or update parameter type | Match types at call site |
| `Cannot find module 'X'` | Fix import path or install package | Correct relative/absolute path |

### Lint Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| `no-unused-vars` | Remove or prefix with underscore | `_unusedVar` or delete |
| `no-unused-imports` | Remove the import statement | Delete line |
| `prefer-const` | Change `let` to `const` | `const x = ...` |
| `no-explicit-any` | Replace `any` with specific type | Infer type from usage |
| `eqeqeq` | Replace `==` with `===` | Strict equality |
| `no-console` | Remove console.log or wrap in debug check | Delete or `if (DEBUG)` |
| `quotes` / `semi` | Apply auto-fix | `eslint --fix` |
| `indent` / `max-len` | Apply auto-fix | `eslint --fix` |

### Import/Export Errors

| Error Pattern | Fix Strategy | Example |
|---|---|---|
| Missing export | Add to barrel file (index.ts) | `export { Thing } from './thing'` |
| Wrong import path | Fix relative or alias path | Correct to project convention |
| Circular import | Restructure — extract shared types to separate file | Move shared types to `types/` |
| Missing package | Check if it should be installed or is a typo | `npm install <pkg>` or fix name |
| Default vs named | Match export style | `import X` vs `import { X }` |

### Naming Inconsistencies

| Pattern | Detection | Fix |
|---|---|---|
| Component naming | Component file name != component name | Rename to match file |
| Variable casing | camelCase violation in JS/TS | Rename to camelCase |
| File naming | Inconsistent with sibling files | Rename to match convention |
| Type naming | PascalCase violation | Rename to PascalCase |
| Constant naming | UPPER_SNAKE_CASE violation for true constants | Rename appropriately |

---

## Changed Package Detection Rules

### Monorepo (Workspaces)

```bash
# 1. Get all changed files relative to sprint base
CHANGED_FILES=$(git diff --name-only ${SPRINT_BASE}..HEAD)

# 2. Read workspace config to get package paths
# For pnpm: pnpm-workspace.yaml -> packages field
# For npm: package.json -> workspaces field
# For nx: nx.json -> projects or workspace.json

# 3. Match changed files to packages
for file in $CHANGED_FILES; do
  for pkg in $WORKSPACE_PACKAGES; do
    if [[ "$file" == "$pkg/"* ]]; then
      CHANGED_PACKAGES+=("$pkg")
    fi
  done
done

# 4. Deduplicate
CHANGED_PACKAGES=($(echo "${CHANGED_PACKAGES[@]}" | tr ' ' '\n' | sort -u))
```

### Single Package

For non-monorepo projects, the entire project is the changed package. Run all checks at root level.

### Detection Heuristics

| Config File | Workspace Detection Method |
|---|---|
| `pnpm-workspace.yaml` | Parse `packages:` array, expand globs |
| `package.json` (workspaces) | Parse `workspaces` array, expand globs |
| `nx.json` | Use `nx affected --plain` or parse `workspace.json` |
| `turbo.json` | Use `turbo run test --filter=...[${BASE}]` |
| `lerna.json` | Use `lerna changed --json` |
| None of above | Single package — check entire project |

### Scope Optimization

Only run tests for changed packages to save time:
```bash
# pnpm
pnpm --filter ...[$SPRINT_BASE] run test

# nx
nx affected --target=test --base=$SPRINT_BASE

# turbo
turbo run test --filter=...[${SPRINT_BASE}]

# fallback: run all tests
npm run test
```

---

## Review Finding Format

Each reviewer agent must format findings consistently.

### Finding Schema

```markdown
### FINDING: <short-title>

- **File:** `<file-path>:<line-number>`
- **Severity:** critical | major | minor | info
- **Category:** security | correctness | performance | accessibility | style | architecture
- **Reviewer:** <agent-name>

**Description:**
<2-4 sentences explaining the issue, why it matters, and the potential impact.>

**Evidence:**
\`\`\`typescript
// The problematic code
<code snippet from the diff>
\`\`\`

**Recommendation:**
\`\`\`typescript
// Suggested fix
<corrected code>
\`\`\`

**Auto-fixable:** yes | no
**References:** <link to docs, OWASP rule, etc.>
```

### Severity Guidelines

| Severity | Definition | Examples |
|---|---|---|
| **Critical** | Security vulnerability, data loss risk, auth bypass. Blocks merge. | SQL injection, exposed secrets, missing auth check, XSS |
| **Major** | Broken functionality, missing error handling, accessibility violation. | Unhandled promise rejection, missing form validation, no keyboard nav |
| **Minor** | Code quality, style, minor performance. Does not affect functionality. | Unnecessary re-renders, slightly wrong naming, missing JSDoc |
| **Info** | Suggestions for improvement. No current issue. | Alternative pattern suggestion, future optimization opportunity |

### Reviewer-Specific Checklists

#### Security Reviewer

- [ ] No hardcoded secrets, API keys, or credentials in code
- [ ] All user input is validated and sanitized before use
- [ ] Authentication checks on all protected routes/endpoints
- [ ] Authorization checks (user can only access their own data)
- [ ] No SQL/NoSQL injection vectors
- [ ] No XSS vectors (user content is escaped before rendering)
- [ ] CSRF protection on state-changing endpoints
- [ ] Sensitive data not logged or exposed in error messages
- [ ] Dependencies have no known critical vulnerabilities
- [ ] File uploads validated (type, size, content)

#### Backend Reviewer

- [ ] API endpoints follow REST conventions (or project's convention)
- [ ] All async operations have error handling (try/catch or .catch())
- [ ] Input validation on all public functions and API handlers
- [ ] Consistent error response format
- [ ] Database queries are efficient (no N+1, proper indexing hints)
- [ ] Rate limiting considered for public endpoints
- [ ] Proper HTTP status codes used
- [ ] Transactions used for multi-step mutations
- [ ] Environment-specific config not hardcoded

#### Frontend Reviewer

- [ ] Components follow single-responsibility principle
- [ ] Proper loading and error states for async operations
- [ ] Forms have validation feedback visible to users
- [ ] Interactive elements are keyboard accessible
- [ ] ARIA attributes on dynamic content
- [ ] Responsive design works at standard breakpoints
- [ ] No layout shifts during loading
- [ ] Images have alt text
- [ ] Color contrast meets WCAG AA
- [ ] State management follows project patterns

#### Pattern Reviewer

- [ ] New code follows existing project naming conventions
- [ ] No code duplication (DRY) — reuses existing utilities
- [ ] Proper separation of concerns (business logic vs presentation)
- [ ] File organization matches project structure conventions
- [ ] Imports follow project conventions (aliases, barrel files)
- [ ] No TODO/FIXME/HACK without linked issue
- [ ] Test coverage exists for new public APIs
- [ ] Types are specific (no unnecessary `any` or `unknown`)
- [ ] Functions are reasonably sized (< 50 lines preferred)
- [ ] Comments explain "why" not "what"
