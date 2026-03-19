# Completeness Gate — Reference Material

Grep patterns, severity classification rules, output schemas, and override configuration for the completeness-gate skill.

---

## Grep Patterns by Check

| # | Check ID | Regex Pattern | File Glob | False-Positive Mitigation |
|---|----------|--------------|-----------|--------------------------|
| 1 | `placeholder-returns` | `return\s*\{\s*\}` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore guard clauses (`if (!x) return {}`). Ignore utility functions explicitly documented as returning empty objects. Check surrounding context for TODO comments. |
| 2 | `placeholder-returns` | `return\s*\[\s*\]` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore filter/search functions that legitimately return empty arrays. Check if the function name suggests emptiness is valid (e.g., `getEmptyState`). |
| 3 | `not-implemented-throws` | `throw\s+new\s+Error\s*\(\s*['"](?:Not implemented\|TODO\|not yet\|NYI\|FIXME\|PLACEHOLDER)` (case-insensitive) | `*.ts, *.tsx, *.js, *.jsx` | None — these are always violations in source files. In test files, mark as `in_test: true`. |
| 4 | `empty-function-bodies` | Function declaration followed by `\{\s*(//[^\n]*)?\s*\}` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore interface method signatures, abstract declarations, and intentional no-op callbacks (look for `// intentional` or `// noop` comments). |
| 5 | `todo-fixme-comments` | `//\s*(TODO\|FIXME\|PLACEHOLDER\|STUB\|HACK\|XXX):?\s` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Distinguish severity by location: business logic = high, utility code = low. Ignore comments in test files (mark `in_test`). |
| 6 | `empty-catch-blocks` | `catch\s*\([^)]*\)\s*\{\s*\}` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Check for intentional swallowing (e.g., `catch (_)` followed by a comment). Still flag but as medium severity. |
| 7 | `log-and-return` | Multi-line: function body contains only `console\.(log\|warn\|error)\(` and optionally `return` | `*.ts, *.tsx, *.js, *.jsx` | Ignore logger utility files. Read full function body to confirm no other logic exists. |
| 8 | `noop-handlers` | `\(\)\s*=>\s*\{\s*\}` and `\(\)\s*=>\s*undefined` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore test mocks (`vi.fn()`, `jest.fn()`). Ignore explicit no-op utilities (`const noop = () => {}`). |
| 9 | `hardcoded-sample-data` | `(?:const\|let)\s+\w+\s*(?::\s*\w+(?:\[\])?\s*)?=\s*\[` followed by 3+ object literals | `*.ts, *.tsx, *.js, *.jsx` | Exclude files in `fixtures/`, `seeds/`, `mocks/`, `__tests__/`, `test-utils/`. Check property names for placeholder indicators (`John`, `Jane`, `example`, `sample`, `test`). |
| 10 | `console-log-leftovers` | `console\.log\(` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude files matching `*logger*`, `*logging*`, `*debug*`. Exclude lines with `// keep` or `// debug` annotations. |
| 11 | `three-state-ui` | Presence of `useAsyncData\|useFetch\|useLazyFetch\|\$fetch\|store\.\w+Action` in `<script>` WITHOUT corresponding `v-if=".*(?:loading\|pending\|isLoading)"` and `v-if=".*(?:error\|isError)"` in `<template>` | `*.vue` | Only flag if the component has a `<template>` section. Ignore components that delegate loading/error to a parent wrapper. |
| 12 | `unwired-store-actions` | Store action function bodies that lack calls to `fetch\|\\$fetch\|axios\|httpsCallable\|api\.\|service\.\|useFetch` | `stores/*.ts, store/*.ts` | Ignore actions that are pure state mutations (e.g., `setLoading`, `resetState`). Check if the action dispatches to another action that makes the API call. |
| 13 | `artifact-verification` | N/A — three-level check (existence, substance, wiring) | Story `files` fields | Only runs when sprint context is available. Level 3 excludes entry points (`pages/**`, `server/api/**`, `main.*`, `app.*`, `index.*`). |

---

## Severity Classification Rules

### Critical

Findings that indicate code will **fail at runtime** or has **incomplete core functionality**.

| Check ID | Condition for Critical |
|----------|----------------------|
| `not-implemented-throws` | In any non-test source file |
| `empty-function-bodies` | In store actions, API route handlers, middleware, or auth-related files |

**Examples:**
- `throw new Error('Not implemented')` in `stores/payment.ts`
- Empty `authenticate()` function in `middleware/auth.ts`

### High

Findings that indicate **incomplete implementations** that will produce incorrect behavior.

| Check ID | Condition for High |
|----------|-------------------|
| `placeholder-returns` | In store actions, composables, or API handlers |
| `todo-fixme-comments` | In store actions, API handlers, or security-related code |
| `noop-handlers` | Bound to user-facing interactions (click, submit, change) |
| `unwired-store-actions` | Action is called from a component but makes no API call |

**Examples:**
- `return {}` in `useAuth().getProfile()`
- `// TODO: validate input` in `functions/createOrder.ts`
- `onClick={() => {}}` on a submit button

### Medium

Findings that indicate **code quality issues** that degrade maintainability or user experience.

| Check ID | Condition for Medium |
|----------|---------------------|
| `console-log-leftovers` | In any source file (not logger utilities) |
| `hardcoded-sample-data` | In any non-test, non-fixture source file |
| `three-state-ui` | Component fetches data but lacks loading or error handling |
| `empty-catch-blocks` | In any source file |

**Examples:**
- `console.log('debug:', response)` left in production code
- `const users = [{ name: 'John' }, { name: 'Jane' }]` in a component
- Vue component using `useFetch` without showing a loading spinner

### Low

Findings that are **informational** or represent minor improvements.

| Check ID | Condition for Low |
|----------|------------------|
| `todo-fixme-comments` | In utility functions, helpers, or non-critical code |
| `noop-handlers` | In non-user-facing or optional interaction paths |
| Any check in test files | All test file findings are capped at Low |

**Examples:**
- `// TODO: optimize this loop` in `utils/transform.ts`
- `() => {}` as a default callback parameter

---

## JSON Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["timestamp", "scope", "files_scanned", "score", "grade", "summary", "findings"],
  "properties": {
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO-8601 timestamp of when the scan completed"
    },
    "scope": {
      "type": "string",
      "description": "The scope that was scanned (path or 'all')"
    },
    "files_scanned": {
      "type": "object",
      "properties": {
        "source": { "type": "integer", "minimum": 0 },
        "test": { "type": "integer", "minimum": 0 }
      },
      "required": ["source", "test"]
    },
    "score": {
      "type": "number",
      "minimum": 0,
      "maximum": 100
    },
    "grade": {
      "type": "string",
      "enum": ["A", "B", "C", "D", "F"]
    },
    "summary": {
      "type": "object",
      "properties": {
        "critical": { "type": "integer", "minimum": 0 },
        "high": { "type": "integer", "minimum": 0 },
        "medium": { "type": "integer", "minimum": 0 },
        "low": { "type": "integer", "minimum": 0 },
        "total": { "type": "integer", "minimum": 0 },
        "suppressed": { "type": "integer", "minimum": 0 }
      },
      "required": ["critical", "high", "medium", "low", "total", "suppressed"]
    },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["check_id", "severity", "file", "line", "snippet", "message", "in_test"],
        "properties": {
          "check_id": {
            "type": "string",
            "enum": [
              "placeholder-returns",
              "not-implemented-throws",
              "empty-function-bodies",
              "todo-fixme-comments",
              "empty-catch-blocks",
              "log-and-return",
              "noop-handlers",
              "hardcoded-sample-data",
              "console-log-leftovers",
              "three-state-ui",
              "unwired-store-actions",
              "artifact-verification"
            ]
          },
          "severity": {
            "type": "string",
            "enum": ["critical", "high", "medium", "low"]
          },
          "file": {
            "type": "string",
            "description": "Relative path from project root"
          },
          "line": {
            "type": "integer",
            "minimum": 1,
            "description": "Line number of the finding"
          },
          "snippet": {
            "type": "string",
            "description": "The matching source line, trimmed to 120 characters max"
          },
          "message": {
            "type": "string",
            "description": "Human-readable explanation of the issue"
          },
          "in_test": {
            "type": "boolean",
            "description": "True if the finding is in a test file"
          }
        }
      }
    }
  }
}
```

---

## Score Calculation

### Formula

```
raw_score = 100 - (critical * 10) - (high * 5) - (medium * 2) - (low * 0.5)
score = clamp(raw_score, 0, 100)
```

Only non-suppressed findings count toward the score. Test file findings (severity capped at Low) contribute at the Low rate (0.5 per finding).

### Worked Examples

**Example 1: Clean codebase**
- Findings: 0 critical, 0 high, 2 medium, 5 low
- Score: 100 - 0 - 0 - 4 - 2.5 = 93.5 (round to 94)
- Grade: **A**

**Example 2: Moderate issues**
- Findings: 0 critical, 3 high, 8 medium, 10 low
- Score: 100 - 0 - 15 - 16 - 5 = 64
- Grade: **D**

**Example 3: Significant problems**
- Findings: 2 critical, 5 high, 12 medium, 8 low
- Score: 100 - 20 - 25 - 24 - 4 = 27
- Grade: **F**

**Example 4: Perfect score**
- Findings: none
- Score: 100
- Grade: **A**

---

## Project Override Schema

The `.completeness-gate.json` file in the project root allows suppressing known or accepted findings.

### Full Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "ignore": {
      "type": "object",
      "properties": {
        "files": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Glob patterns for files to exclude entirely from scanning"
        },
        "checks": {
          "type": "array",
          "items": {
            "type": "string",
            "enum": [
              "placeholder-returns",
              "not-implemented-throws",
              "empty-function-bodies",
              "todo-fixme-comments",
              "empty-catch-blocks",
              "log-and-return",
              "noop-handlers",
              "hardcoded-sample-data",
              "console-log-leftovers",
              "three-state-ui",
              "unwired-store-actions",
              "artifact-verification"
            ]
          },
          "description": "Check IDs to skip entirely"
        },
        "inline": {
          "type": "string",
          "default": "completeness-ignore",
          "description": "Comment marker that suppresses the finding on that line. When a source line contains this marker as a comment, the finding for that line is suppressed."
        }
      }
    }
  }
}
```

### Example Configuration

```json
{
  "ignore": {
    "files": [
      "src/legacy/**",
      "src/generated/**",
      "scripts/**"
    ],
    "checks": ["console-log-leftovers"],
    "inline": "completeness-ignore"
  }
}
```

### Inline Suppression

Add the configured marker as a trailing comment to suppress a specific line:

```typescript
// This is an intentional empty return for the default case
return {} // completeness-ignore

// This TODO is tracked in the issue tracker and is accepted
// TODO: migrate to new API after v3 release // completeness-ignore
```

Only the finding on that specific line is suppressed. The suppression is recorded in the report's `suppressed` count.
