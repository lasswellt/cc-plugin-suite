# Fix Issue — Reference Material

Root cause analysis templates, common bug patterns, and regression test patterns.

---

## Root Cause Analysis Template

For each bug, work through this template before writing any fix:

### 1. Symptom
What the user or test observes (error message, wrong behavior, crash).

### 2. Reproduction
Minimal steps to reproduce. If the issue is intermittent, note conditions.

### 3. Fault Localization
| Technique | How |
|-----------|-----|
| Stack trace | Read error stack, identify originating file:line |
| Git blame | Check recent changes to the failing area |
| Binary search | Use `git bisect` for regressions |
| Input tracing | Follow the data from entry point to failure point |
| Dependency check | Verify imported modules provide expected exports |

### 4. Root Cause Categories

| Category | Symptoms | Typical Fix |
|----------|----------|-------------|
| **Type mismatch** | Runtime TypeError, undefined property access | Fix type definition or add runtime validation |
| **Missing null check** | "Cannot read property of null/undefined" | Add null guard or optional chaining |
| **Race condition** | Intermittent failures, timing-dependent | Add await, mutex, or reorder operations |
| **Stale state** | UI shows old data, cached values persist | Invalidate cache, force reactivity trigger |
| **Import error** | Module not found, circular dependency | Fix path, restructure imports |
| **API contract mismatch** | 4xx/5xx errors, wrong response shape | Align frontend expectation with backend contract |
| **Environment mismatch** | Works locally, fails in CI/prod | Check env vars, build config, runtime differences |
| **Regression** | Previously working feature now broken | Find the breaking commit, revert or fix |

### 5. Fix Strategy
- **Minimal fix:** Change the fewest lines possible to resolve the root cause.
- **Defensive fix:** Add guards to prevent the same class of bug elsewhere.
- **Systemic fix:** If the pattern recurs, refactor to eliminate the bug class.

Choose minimal fix unless the bug reveals a systemic pattern.

---

## Common Bug Patterns

### Frontend Patterns

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Missing loading state | Component renders before data arrives | Add `v-if="loading"` guard |
| Unhandled promise rejection | Console shows unhandled rejection | Add `.catch()` or try/catch |
| Reactive state not updating | UI stale after mutation | Use `ref()` not plain variable, or trigger `$forceUpdate` |
| Route guard bypass | Protected page accessible without auth | Check middleware order, verify guard logic |
| Event handler not firing | Click/submit does nothing | Check event binding syntax, `@click` vs `:click` |

### Backend Patterns

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Missing auth check | API returns data without token | Add auth middleware/verification |
| Validation bypass | Invalid data accepted | Add Zod/schema validation at handler entry |
| Error swallowing | Empty catch block | Log error and return proper error response |
| N+1 query | Slow endpoint, many DB calls in logs | Batch queries, use joins or aggregation |
| Missing CORS header | Browser blocks request | Configure CORS in server config |

### TypeScript Patterns

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Unsafe `any` cast | Runtime type error despite passing tsc | Replace `any` with proper type |
| Missing discriminant | Switch/if doesn't cover all cases | Add exhaustive check |
| Optional chaining overuse | Silent `undefined` propagation | Add explicit null checks with error messages |

---

## Regression Test Patterns

After fixing a bug, always write a regression test that:

1. **Reproduces the original failure** — the test must fail without the fix applied
2. **Verifies the fix** — the test passes with the fix
3. **Names the bug** — test name references the issue: `it('should not crash when user is null (fixes #123)')`

### Regression Test Template

```typescript
describe('regression: #<issue-number>', () => {
  it('should <expected behavior> when <condition that triggered bug>', () => {
    // Arrange — set up the exact conditions that caused the bug
    const input = /* the problematic input */

    // Act — trigger the code path that failed
    const result = functionUnderTest(input)

    // Assert — verify correct behavior
    expect(result).toEqual(/* expected output */)
  })
})
```

### When NOT to Write a Regression Test

- Fix is in configuration only (tsconfig, eslint, build config)
- Fix is a typo in a string literal with no logic
- The area already has comprehensive tests that would catch a recurrence
