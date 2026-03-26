# Code Sweep — Reference Material

Grep patterns, auto-fix strategies, state schemas, and severity rules for the code-sweep skill.

---

## Grep Patterns by Check

### Tier 1: High Confidence (every tick)

| # | Check ID | Regex Pattern | File Glob | False-Positive Mitigation | Fixable |
|---|----------|--------------|-----------|--------------------------|---------|
| 1 | `todo-fixme` | `(TODO\|FIXME\|HACK\|XXX\|TEMP\|WORKAROUND)(\(.*?\))?:?\s` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude lines with `sweep-ignore`. Severity based on location. | No |
| 2 | `console-log` | `console\.(log\|debug\|dir\|table\|time\|timeEnd\|trace)\s*\(` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude `*logger*`, `*logging*`, `*debug*` paths. Exclude lines with `// keep`, `// debug`, `sweep-ignore`. Exclude test files. | Yes |
| 3 | `empty-catch` | `catch\s*\([^)]*\)\s*\{\s*\}` (multiline) | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Check for `// intentional` or `// noop` comments. Still flag but lower severity. | Yes |
| 4 | `placeholder-throw` | `throw\s+new\s+Error\s*\(\s*['"](?:not implemented\|TODO\|not yet\|NYI\|FIXME\|PLACEHOLDER)` (case-insensitive) | `*.ts, *.tsx, *.js, *.jsx` | None — always a violation in source. | No |
| 5 | `empty-function` | Function declaration followed by `\{\s*(//[^\n]*)?\s*\}` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore interface declarations, abstract methods, `// noop`, `// intentional`. | No |
| 6 | `noop-handler` | `\(\)\s*=>\s*\{\s*\}` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude `vi.fn()`, `jest.fn()`, explicit noop utilities. | No |
| 7 | `placeholder-returns` | `return\s*\{\s*\}` and `return\s*\[\s*\]` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Ignore guard clauses (`if (!x) return {}`). Ignore functions named `*empty*` or `*default*`. | No |
| 8 | `hardcoded-secret` | `(?:api[_-]?key\|apikey\|secret\|password\|token\|credential)\s*[:=]\s*['"][A-Za-z0-9+/=]{8,}['"]` and known prefixes `AIza\|sk-\|ghp_\|AKIA` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude test files, `.env.example`, fixture files. | No |
| 9 | `typescript-any` | `:\s*any\b` and `as\s+any\b` and `<any>` | `*.ts, *.tsx, *.vue` | Exclude comments, generated files, type stubs. Exclude `sweep-ignore`. | Semi |
| 10 | `skipped-test` | `it\.skip\(\|xit\(\|describe\.skip\(\|test\.skip\(` | `*.test.*, *.spec.*` | None — always a violation. | Yes |
| 11 | `loose-equality` | `[^!=]==[^=]` (exclude `== null`, `== undefined`) | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude comments and strings. Exclude `== null`/`== undefined`. | Yes |
| 12 | `return-await` | `return\s+await\s+` | `*.ts, *.tsx, *.js, *.jsx` | Exclude occurrences inside try blocks (where return await IS needed). | Yes |
| 13 | `optional-chaining` | `(\w+)\s*&&\s*\1\.(\w+)` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude method calls with side effects (`.push()`, `.splice()`, etc.). Only fix property reads. | Yes |
| 14 | `redundant-else` | `} else {` preceded by `return\|throw` in the if-block | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Check 5 lines of context. Low false positives. | Yes |
| 15 | `nullish-coalescing` | `(\w+)\s*!==?\s*(?:null\|undefined)\s*\?\s*\1\s*:` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Low false positives for explicit null/undefined ternary. | Yes |
| 16 | `immediate-return-var` | `(const\|let)\s+(\w+)\s*=\s*([^;]+);\s*\n\s*return\s+\2;` (multiline) | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude destructuring. Exclude variables providing documentation value. | Yes |

### Tier 2: Medium Confidence (once per session)

| # | Check ID | Detection Method | File Glob | False-Positive Mitigation | Fixable |
|---|----------|-----------------|-----------|--------------------------|---------|
| 17 | `unused-import` | Extract imported symbols, count occurrences in file (incl. `<template>` for Vue) | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude barrel re-export files. Check `<template>` in Vue files. Skip type-only in re-export files. | Yes |
| 18 | `commented-code` | 3+ consecutive `//` lines with code tokens: `import\|export\|const\|let\|var\|function\|return\|if \(\|else\|for \(\|while \(\|class\|interface\|await\|async` | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude JSDoc (`@param`, `@returns`), license headers, lines without code tokens. | Yes |
| 19 | `todo-age` | git blame on TODO lines, bucket by age | N/A (enriches `todo-fixme` findings) | Cache blame results. May be inaccurate for rebased code. | No |
| 20 | `log-and-return` | Multi-line: function body contains only `console\.(log\|warn\|error)\(` and optionally `return` | `*.ts, *.tsx, *.js, *.jsx` | Ignore logger utility files. Read full function body to confirm no other logic exists. | No |
| 21 | `three-state-ui` | Presence of `useAsyncData\|useFetch\|useLazyFetch\|\$fetch\|store\.\w+Action` in `<script>` WITHOUT loading/error handling in `<template>` | `*.vue` | Only flag if component has a `<template>`. Ignore components that delegate to parent wrapper. | No |
| 22 | `file-length` | `wc -l` on source files, flag > 300 lines (configurable) | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Exclude generated files, config files. Threshold configurable via `max_lines`. | No |
| 23 | `missing-v-for-key` | Lines with `v-for=` but without `:key` on the same element | `*.vue` | Low false positives. Almost always a bug. | No |

### Tier 3: Deep Analysis (only with `--deep`)

| # | Check ID | Detection Method | Preferred Tool | Fallback | Fixable |
|---|----------|-----------------|---------------|----------|---------|
| 24 | `orphaned-file` | Files not imported by any other file | `npx knip --include files --reporter json` | Grep all imports for each file's module path | No |
| 25 | `dead-export` | Exported symbols not imported anywhere | `npx knip --include exports --reporter json` | Grep for import of each exported symbol | No |
| 26 | `unused-dep` | Dependencies not imported in source | `npx knip --include dependencies --reporter json` | Grep source for each dependency name | Semi-auto |
| 27 | `sample-data` | Arrays of 3+ inline objects with placeholder property values | Grep: `(?:const\|let)\s+\w+\s*(?::\s*\w+(?:\[\])?\s*)?=\s*\[` | Check for placeholder names: `John`, `Jane`, `example`, `sample`, `test`, `foo`, `bar` | No |
| 28 | `unwired-store-actions` | Store action methods that lack `fetch\|\$fetch\|axios\|httpsCallable\|api\.\|service\.` calls | `stores/*.ts` | Ignore pure state mutations (`setLoading`, `resetState`). Check if action dispatches to another action. | No |
| 29 | `sequential-await` | 2+ consecutive `await` on independent calls (second doesn't use first's result) | `*.ts, *.tsx, *.js, *.jsx` | Read context to verify independence. High false-positive risk. | No |
| 30 | `n-plus-one` | `await` inside loop body (`forEach\|map\|for`) | `*.ts, *.tsx, *.js, *.jsx` | Multiline grep. Some loops intentionally await sequentially (rate limiting). | No |
| 31 | `v-html-xss` | `v-html=` usage in Vue templates | `*.vue` | Flag all usages. High severity if bound to variable, medium for static strings. | No |
| 32 | `nesting-depth` | Control flow nesting (`if\|for\|while\|switch`) > 4 levels deep | `*.ts, *.tsx, *.js, *.jsx, *.vue` | Approximate by tracking brace depth at control flow keywords. Threshold configurable. | No |

---

## Auto-Fix Strategies

### `console-log` — Remove Debug Logging

**Strategy:** Remove the entire line containing the console call.

**Steps:**
1. Read the file and locate the exact line
2. Check if the line is the sole content of a block (e.g., `if (debug) { console.log(x) }`) — if so, remove just the console call, not the block
3. Remove the line using `Edit`
4. If the removal leaves an empty line between two code lines, remove the empty line too

**Example:**
```typescript
// Before
function processUser(user: User) {
  console.log('processing:', user)  // ← remove this line
  return transform(user)
}

// After
function processUser(user: User) {
  return transform(user)
}
```

### `empty-catch` — Add Error Logging

**Strategy:** Insert `console.error(<param>)` inside the empty catch block.

**Steps:**
1. Read the file and locate the catch block
2. Extract the catch parameter name (e.g., `err`, `e`, `error`)
3. If no parameter name (bare `catch {}`), use `err` and add it as the parameter
4. Insert `console.error(<param>)` as the first line inside the catch body
5. Apply using `Edit`

**Example:**
```typescript
// Before
try {
  await saveData()
} catch (err) {}

// After
try {
  await saveData()
} catch (err) {
  console.error(err)
}
```

### `unused-import` — Remove Unused Specifiers

**Strategy:** Remove unused import specifiers. If all specifiers are unused, remove the entire import line.

**Steps:**
1. Read the file and locate the import statement
2. Identify which specifiers are unused (from the scan data)
3. If ALL specifiers are unused, remove the entire import line
4. If SOME specifiers are unused, remove only those from the `{ ... }` list
5. Apply using `Edit`
6. **MUST run typecheck after** — this is the highest-risk auto-fix

**Example:**
```typescript
// Before
import { useState, useEffect, useCallback } from 'react'
// useCallback is unused

// After
import { useState, useEffect } from 'react'
```

### `commented-code` — Delete Commented Block

**Strategy:** Delete consecutive lines of commented-out code.

**Steps:**
1. Read the file and locate the block (3+ consecutive `//` lines with code tokens)
2. Verify the block is NOT a JSDoc comment, license header, or explanatory comment
3. Remove the entire block using `Edit`
4. If removal leaves consecutive empty lines, collapse to a single empty line

**Example:**
```typescript
// Before
function getData() {
  // const oldData = fetchLegacy()
  // const transformed = transform(oldData)
  // return transformed
  return fetchNew()
}

// After
function getData() {
  return fetchNew()
}
```

### `skipped-test` — Remove .skip from Tests

**Strategy:** Remove `.skip` from test calls.

**Steps:**
1. Read the test file and locate the `.skip` call
2. Replace `it.skip(` with `it(`, `describe.skip(` with `describe(`, `test.skip(` with `test(`, `xit(` with `it(`
3. Apply using `Edit`

**Example:**
```typescript
// Before
it.skip('should validate user input', () => {
// After
it('should validate user input', () => {
```

### `loose-equality` — Strict Equality

**Strategy:** Replace `==` with `===` and `!=` with `!==`. Exclude `== null` and `== undefined`.

**Steps:**
1. Read the file and locate the loose equality
2. Verify it is NOT `== null` or `== undefined` (these are idiomatic)
3. Replace `==` with `===` or `!=` with `!==`
4. Apply using `Edit`

**Example:**
```typescript
// Before
if (status == 'active') { ... }
// After
if (status === 'active') { ... }
```

### `return-await` — Remove Unnecessary Await

**Strategy:** Remove `await` from `return await` outside try blocks.

**Steps:**
1. Read the file and locate the `return await` line
2. Check if it is inside a try block (read 20 lines of context). If inside try, SKIP — `return await` is needed there
3. Remove `await` keyword
4. Apply using `Edit`

**Example:**
```typescript
// Before
async function getData() {
  return await fetchData()
}
// After
async function getData() {
  return fetchData()
}
```

### `optional-chaining` — Convert Guard Pattern

**Strategy:** Replace `x && x.y` with `x?.y` for property reads only.

**Steps:**
1. Read the file and locate the guard pattern
2. Verify it is a property read, NOT a method call with side effects (`.push`, `.splice`, `.set`, etc.)
3. Replace `x && x.y` with `x?.y`. For triple chains: `x && x.y && x.y.z` -> `x?.y?.z`
4. Apply using `Edit`

**Example:**
```typescript
// Before
const name = user && user.profile && user.profile.name
// After
const name = user?.profile?.name
```

### `redundant-else` — Remove Else After Return

**Strategy:** Remove `} else {` wrapper when the preceding if-block ends with return/throw.

**Steps:**
1. Read the file and locate the `} else {` block
2. Verify the preceding if-block ends with `return` or `throw`
3. Remove `} else {` and the closing `}` of the else block
4. Dedent the else-body to match the surrounding indentation
5. Apply using `Edit`

**Example:**
```typescript
// Before
if (!user) {
  return null
} else {
  return user.name
}
// After
if (!user) {
  return null
}
return user.name
```

### `nullish-coalescing` — Simplify Null Check

**Strategy:** Replace verbose null/undefined ternary with `??`.

**Steps:**
1. Read the file and locate the ternary pattern
2. Verify the pattern is `x !== null ? x : default` or `x !== undefined ? x : default` or `x != null ? x : default`
3. Replace with `x ?? default`
4. Apply using `Edit`

**Example:**
```typescript
// Before
const val = x !== null && x !== undefined ? x : 'default'
// After
const val = x ?? 'default'
```

### `immediate-return-var` — Inline Return

**Strategy:** Inline a variable that is only used in the immediately following return.

**Steps:**
1. Read the file and locate the `const x = expr; return x;` pattern
2. Verify the variable is not a destructuring assignment
3. Replace both lines with `return expr;`
4. Apply using `Edit`

**Example:**
```typescript
// Before
const result = computeSomething(x, y)
return result
// After
return computeSomething(x, y)
```

---

## Category Classification

Every check belongs to exactly one category:

| Category | Description | Check IDs |
|----------|-------------|-----------|
| **Cleanup** | Dead code, debug leftovers, noise | `todo-fixme`, `console-log`, `empty-catch`, `unused-import`, `commented-code`, `todo-age`, `orphaned-file`, `dead-export`, `unused-dep` |
| **Correctness** | Code does what it claims | `placeholder-throw`, `empty-function`, `noop-handler`, `placeholder-returns`, `skipped-test`, `loose-equality`, `log-and-return`, `unwired-store-actions`, `sample-data`, `missing-v-for-key` |
| **Optimization** | Performance patterns | `return-await`, `sequential-await`, `n-plus-one` |
| **Convention** | Project standards alignment | `typescript-any`, `file-length`, `nesting-depth` |
| **Security** | Risky patterns | `hardcoded-secret`, `v-html-xss` |
| **Reduction** | Simplify, reduce verbosity | `optional-chaining`, `redundant-else`, `nullish-coalescing`, `immediate-return-var` |
| **Robustness** | UI resilience patterns | `three-state-ui` |

---

## Severity Classification

### Critical
| Check ID | Condition | Category |
|----------|-----------|----------|
| `placeholder-throw` | In any non-test source file | Correctness |
| `empty-function` | In store actions, API handlers, middleware, auth files | Correctness |
| `hardcoded-secret` | Any detected secret pattern in source | Security |

### High
| Check ID | Condition | Category |
|----------|-----------|----------|
| `todo-fixme` | In store actions, API handlers, or security code | Cleanup |
| `todo-fixme` | Aged > `todo_age_threshold_days` (red bucket) | Cleanup |
| `noop-handler` | Bound to user interactions (click, submit, change) | Correctness |
| `placeholder-throw` | In utility or helper code | Correctness |
| `placeholder-returns` | In store actions, composables, API handlers | Correctness |
| `log-and-return` | In business logic files | Correctness |
| `unwired-store-actions` | Action called from component but makes no API call | Correctness |
| `v-html-xss` | Bound to a variable (not static string) | Security |

### Medium
| Check ID | Condition | Category |
|----------|-----------|----------|
| `console-log` | In any non-test source file | Cleanup |
| `empty-catch` | In any source file | Cleanup |
| `orphaned-file` | File not imported anywhere | Cleanup |
| `sample-data` | In non-test, non-fixture source file | Correctness |
| `typescript-any` | In any source file | Convention |
| `skipped-test` | In any test file | Correctness |
| `three-state-ui` | Vue component fetching data without loading/error UI | Robustness |
| `missing-v-for-key` | `v-for` without `:key` | Correctness |
| `n-plus-one` | `await` inside loop body | Optimization |
| `file-length` | > 500 lines | Convention |
| `nesting-depth` | Depth 5-6 | Convention |
| `v-html-xss` | Bound to static string | Security |

### Low
| Check ID | Condition | Category |
|----------|-----------|----------|
| `todo-fixme` | In utility/helper code, aged < 30 days | Cleanup |
| `unused-import` | In any source file | Cleanup |
| `commented-code` | In any source file | Cleanup |
| `dead-export` | Exported symbol not imported | Cleanup |
| `unused-dep` | Dependency not referenced in source | Cleanup |
| `noop-handler` | In non-user-facing paths | Correctness |
| `loose-equality` | In any source file | Correctness |
| `return-await` | Outside try blocks | Optimization |
| `optional-chaining` | Guard pattern replaceable with `?.` | Reduction |
| `redundant-else` | Else after return/throw | Reduction |
| `nullish-coalescing` | Verbose null ternary | Reduction |
| `immediate-return-var` | Variable before immediate return | Reduction |
| `sequential-await` | Independent consecutive awaits | Optimization |
| `file-length` | 300-500 lines | Convention |
| `nesting-depth` | Depth 4 | Convention |

### Test File Override
All findings in test files are capped at **Low** severity regardless of the check.

---

## Inline Suppression

Add `sweep-ignore` as a trailing comment to suppress a finding on that line:

```typescript
console.log('Server started on port', port) // sweep-ignore
```

Suppressed findings are excluded from the score and marked `status: "suppressed"` in the ledger.

---

## State Schemas

### Ledger Entry (`docs/sweeps/sweep-ledger.jsonl`)

One JSON object per line, append-only:

```json
{
  "id": "<check_id>-<file>-<line>-<hash>",
  "cat": "<check_id>",
  "category": "cleanup|correctness|optimization|convention|security|reduction|robustness",
  "file": "<relative-path>",
  "line": 0,
  "symbol": "<matching code snippet, trimmed to 80 chars>",
  "severity": "critical|high|medium|low",
  "fixable": true,
  "status": "found|fixed|resolved|wontfix|false-positive|needs-human|suppressed",
  "found_at": "YYYY-MM-DD",
  "fixed_at": "YYYY-MM-DD|null",
  "fixed_by": "auto|manual|null",
  "commit": "<short-hash>|null",
  "regressed": false,
  "run": 0
}
```

**Deduplication key:** `id` field. When appending, if an entry with the same `id` exists, the latest entry wins. Consumers should read the ledger in order and use the last entry per `id`.

### Snapshot (`docs/sweeps/YYYY-MM-DD.json`)

```json
{
  "date": "YYYY-MM-DD",
  "timestamp": "<ISO-8601>",
  "run_number": 0,
  "mode": "scan-only|fix|fix-all|loop",
  "scope": ["<scanned directories>"],
  "files_scanned": { "source": 0, "test": 0 },
  "score": 0,
  "grade": "A|B|C|D|F",
  "summary": {
    "total": 0,
    "by_status": {
      "found": 0,
      "fixed": 0,
      "resolved": 0,
      "wontfix": 0,
      "false_positive": 0,
      "needs_human": 0,
      "suppressed": 0
    },
    "by_severity": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
    "by_tier": { "tier1": 0, "tier2": 0, "tier3": 0 },
    "by_category": {
      "cleanup": 0,
      "correctness": 0,
      "optimization": 0,
      "convention": 0,
      "security": 0,
      "reduction": 0,
      "robustness": 0
    },
    "auto_fixable": 0,
    "delta": {
      "new": 0,
      "resolved": 0,
      "regressed": 0,
      "total_change": 0,
      "score_change": 0
    }
  },
  "categories": {
    "<check_id>": {
      "count": 0,
      "fixable": 0,
      "fixed_this_run": 0,
      "oldest_days": null
    }
  },
  "fixes_applied": [
    {
      "check_id": "<check_id>",
      "file": "<path>",
      "line": 0,
      "commit": "<short-hash>",
      "verified": true
    }
  ],
  "previous_score": null,
  "tiers_run": ["tier1", "tier2"]
}
```

### Project Config (`.code-sweep.json`)

```json
{
  "scope": ["src/", "functions/"],
  "exclude": ["**/generated/**", "**/vendor/**"],
  "checks": {
    "todo-fixme": { "enabled": true, "auto_fix": false },
    "console-log": { "enabled": true, "auto_fix": true, "exclude_files": ["**/logger.*"] },
    "empty-catch": { "enabled": true, "auto_fix": true },
    "placeholder-throw": { "enabled": true, "auto_fix": false },
    "empty-function": { "enabled": true, "auto_fix": false },
    "noop-handler": { "enabled": true, "auto_fix": false },
    "placeholder-returns": { "enabled": true, "auto_fix": false },
    "hardcoded-secret": { "enabled": true, "auto_fix": false },
    "typescript-any": { "enabled": true, "auto_fix": false },
    "skipped-test": { "enabled": true, "auto_fix": true },
    "loose-equality": { "enabled": true, "auto_fix": true },
    "return-await": { "enabled": true, "auto_fix": true },
    "optional-chaining": { "enabled": true, "auto_fix": true },
    "redundant-else": { "enabled": true, "auto_fix": true },
    "nullish-coalescing": { "enabled": true, "auto_fix": true },
    "immediate-return-var": { "enabled": true, "auto_fix": true },
    "unused-import": { "enabled": true, "auto_fix": true },
    "commented-code": { "enabled": true, "auto_fix": true, "min_lines": 3 },
    "todo-age": { "enabled": true, "auto_fix": false },
    "log-and-return": { "enabled": true, "auto_fix": false },
    "three-state-ui": { "enabled": true, "auto_fix": false },
    "file-length": { "enabled": true, "auto_fix": false, "max_lines": 300 },
    "missing-v-for-key": { "enabled": true, "auto_fix": false },
    "orphaned-file": { "enabled": true, "auto_fix": false },
    "dead-export": { "enabled": true, "auto_fix": false },
    "unused-dep": { "enabled": true, "auto_fix": false },
    "sample-data": { "enabled": true, "auto_fix": false },
    "unwired-store-actions": { "enabled": true, "auto_fix": false },
    "sequential-await": { "enabled": true, "auto_fix": false },
    "n-plus-one": { "enabled": true, "auto_fix": false },
    "v-html-xss": { "enabled": true, "auto_fix": false },
    "nesting-depth": { "enabled": true, "auto_fix": false, "max_depth": 4 }
  },
  "knip": { "enabled": true, "cache_ttl_hours": 24 },
  "verify_command": null,
  "max_fixes_per_tick": 1,
  "todo_age_threshold_days": 180,
  "inline_suppress_marker": "sweep-ignore"
}
```

When `verify_command` is `null`, the skill auto-detects based on available tools (tsconfig.json for TypeScript, eslint config for linting).

---

## Score Calculation

### Formula

```
raw_score = 100 - (critical * 10) - (high * 5) - (medium * 2) - (low * 0.5)
score = clamp(raw_score, 0, 100)
```

Only active findings count (status `found` or `needs-human`). Suppressed, fixed, resolved, wontfix, and false-positive findings do not affect the score.

### Grade Thresholds

| Score | Grade |
|-------|-------|
| 90-100 | A |
| 80-89 | B |
| 70-79 | C |
| 60-69 | D |
| < 60 | F |

---

## Ledger Maintenance

The ledger is append-only and grows over time. To prevent unbounded growth:

- **Prune fixed entries** older than 30 days (they served their tracking purpose)
- **Prune resolved entries** older than 30 days
- **Keep wontfix/false-positive entries** indefinitely (they prevent re-flagging)
- **Keep found/needs-human entries** indefinitely (they represent active issues)
- Only one session should prune at a time

Pruning should run at the start of Phase 5 if the ledger exceeds 1000 lines.

---

## Knip Integration

When `knip.enabled` is true and `npx knip --version` succeeds:

1. **Cache knip results** in `${SESSION_TMP_DIR}/knip-cache.json`
2. **Cache TTL**: reuse cached results if they are newer than `knip.cache_ttl_hours`
3. **Run knip** for Tier 3 checks: `npx knip --reporter json 2>/dev/null`
4. **Parse output** and convert to finding objects

If knip is not installed or fails, fall back to grep-based detection and note reduced accuracy in the snapshot.

---

## Git Commit Message Format

Fixes applied by code-sweep use this commit message format:

```
sweep(<check_id>): <brief description> in <file>

Auto-fixed by /blitz:code-sweep
```

For batch fixes (`--fix-all`):
```
sweep(<check_id>): auto-fix N instances

Files: <file1>, <file2>, ...
Auto-fixed by /blitz:code-sweep
```
