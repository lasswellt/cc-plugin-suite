---
name: code-sweep
description: "Iterative code improvement with loop support. Scans 30 checks across 7 categories: cleanup, correctness, optimization, convention, security, reduction, robustness. Auto-fixes what it can, reports the rest. Each /loop tick makes incremental progress. Use when user says 'sweep', 'cleanup', 'improve code', 'code quality', 'find TODOs', 'dead code', 'optimize'."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
compatibility: ">=2.1.71"
argument-hint: "<scope> | --fix | --scan-only | --fix-all | --deep | --loop | --category <list> | --checks <list>"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For grep patterns, state schemas, auto-fix strategies, and severity rules, see [reference.md](reference.md)
- For context window hygiene, see [context-management.md](/_shared/context-management.md)

All output must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder sections.

---

# Code Sweep Skill

Iterative code improvement following the **Observe-Diff-Act-Report** reconciliation pattern. Scans 30 checks across 7 categories (cleanup, correctness, optimization, convention, security, reduction, robustness) with 11 auto-fixable patterns. Designed for `/loop` compatibility — each invocation scans for issues, optionally fixes the highest-priority auto-fixable finding, and exits cleanly for the next tick.

**Categories**: Cleanup | Correctness | Optimization | Convention | Security | Reduction | Robustness

Execute every phase in order. Do NOT skip phases.

**Loop tick budget: < 2 minutes total.**

---

## SAFETY RULES (NON-NEGOTIABLE)

1. **In `--scan-only` mode (default), this skill is READ-ONLY** — never modify source files.
2. **In `--fix` mode, fix exactly ONE finding per invocation** — then verify and commit.
3. **In `--fix-all` mode, fix one CATEGORY at a time** — verify after each category.
4. **Never auto-fix findings marked `fixable: false`** in reference.md.
5. **Always verify after fixing** — run the project's verify command (typecheck + lint). If verification fails, revert ALL changes from this tick and mark the finding as `needs-human`.
6. **Never delete files** — orphaned file detection has too many false positives for auto-removal.
7. **Never modify test files** — test findings are informational only.
8. **Circuit breaker** — if 2 consecutive fix attempts fail verification in a session, switch to `--scan-only` for the remainder and warn the user.

---

## Phase 0: SETUP — Parse Arguments and Register Session

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

### 0.1 Parse Arguments

Extract from `$ARGUMENTS`:

| Flag | Behavior | Loop-Safe |
|------|----------|-----------|
| `--scan-only` (default) | Read-only scan, update ledger + snapshot | Yes |
| `--fix` | Scan + fix top auto-fixable finding | Yes (one fix per tick) |
| `--fix-all` | Batch fix all auto-fixable by category | No (use manually) |
| `--deep` | Include Tier 3 analysis (knip if available, full orphan scan) | Yes (slow, cached) |
| `--loop` | Alias for `--fix` with full autonomy — no prompts, auto-commit | Yes |
| `--category <list>` | Comma-separated category filter: cleanup, correctness, optimization, convention, security, reduction, robustness (default: all) | Yes |
| `--checks <list>` | Comma-separated list of check IDs to run (default: all enabled) | Yes |
| `<scope>` | Directory or file path to scan (default: project source directories) | Yes |

When `--loop` is specified:
- Set autonomy to `full` — no user prompts, all decisions auto-approved
- Implicitly enable `--fix`
- Auto-commit and push after successful fixes
- Exit immediately after one fix cycle

### 0.2 Load Configuration

Read `.code-sweep.json` from the project root (if it exists). Schema is in reference.md.

If `.code-sweep.json` does not exist, use defaults:
- **scope**: `["src/", "functions/", "server/", "pages/", "components/", "composables/", "stores/", "lib/", "utils/", "api/", "middleware/"]` (whichever exist)
- **exclude**: `["**/node_modules/**", "**/dist/**", "**/.nuxt/**", "**/.output/**", "**/coverage/**", "**/.cc-sessions/**", "**/__snapshots__/**", "**/generated/**", "**/vendor/**"]`
- **checks**: all enabled
- **verify_command**: auto-detect (see Phase 4)
- **max_fixes_per_tick**: 1
- **todo_age_threshold_days**: 180

### 0.3 Validate Scope

Verify at least one scope directory exists:
```bash
for dir in <scope-dirs>; do
  [ -d "$dir" ] && echo "SCOPE: $dir"
done
```

If no scope directories exist, inform the user and stop.

**Gate:** At least one source directory must exist.

---

## Phase 1: OBSERVE — Read Previous State

### 1.1 Load Last Snapshot

Read the most recent snapshot from `docs/sweeps/`:
```bash
ls -1 docs/sweeps/*.json 2>/dev/null | grep -v 'latest' | sort | tail -1
```

If no snapshot exists, this is the **first run** — skip delta comparison in Phase 3.

### 1.2 Load Ledger

Read `docs/sweeps/sweep-ledger.jsonl` if it exists. Parse into a map keyed by finding ID (`{category}-{file}-{line}-{symbol}`).

### 1.3 Detect Changed Files (Incremental Mode)

If a previous snapshot exists, find files changed since the last sweep:
```bash
LAST_DATE=$(cat docs/sweeps/latest.json 2>/dev/null | grep -o '"date":"[^"]*"' | head -1 | cut -d'"' -f4)
git log --since="${LAST_DATE}" --name-only --pretty=format: | sort -u | grep -E '\.(ts|tsx|js|jsx|vue)$'
```

If `--deep` is specified or this is the first run, scan ALL files in scope (not just changed).

### 1.4 Build File List

Use Glob to collect target files in scope:
```
*.ts, *.tsx, *.js, *.jsx, *.vue
```

Separate into:
- **Source files**: NOT matching `*.test.*`, `*.spec.*`, or in `__tests__/`
- **Test files**: Matching `*.test.*`, `*.spec.*`, or in `__tests__/`

Apply exclusion patterns from config.

Print: `[code-sweep] Scanning N source files + M test files in <scope>`

---

## Phase 2: SCAN — Run Check Categories

Run enabled checks in tier order. For each finding, record a finding object using the schema from reference.md.

**Tier order matters**: Tier 1 runs every tick. Tier 2 runs if budget permits or on first run. Tier 3 runs only with `--deep`.

### Tier 1: High Confidence, Fast (run every tick, ~8 seconds total)

#### 2.1 TODO/FIXME Comments
**Check ID**: `todo-fixme`

Grep for annotation comments in source files:
```
(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)(\(.*?\))?:?\s
```

Exclude lines containing the inline suppression marker (`sweep-ignore`).

**Severity**: High if in store actions, API handlers, or security code. Low otherwise.
**Fixable**: No — requires human judgment.

#### 2.2 Console.log Leftovers
**Check ID**: `console-log`

Grep for debug logging in source files:
```
console\.(log|debug|dir|table|time|timeEnd|trace)\s*\(
```

Exclude:
- Files matching `*logger*`, `*logging*`, `*debug*` in path
- Lines with `// keep`, `// debug`, `// sweep-ignore` comments
- Test files

**Severity**: Medium.
**Fixable**: Yes — remove the line (preserve surrounding context).

#### 2.3 Empty Catch Blocks
**Check ID**: `empty-catch`

Grep for catch blocks with empty or whitespace-only bodies:
```
catch\s*\([^)]*\)\s*\{\s*\}
```

Use multiline grep. Also check for single-line pattern: `catch (e) {}`.

**Severity**: Medium.
**Fixable**: Yes — insert `console.error(<param-name>)` inside the catch block.

#### 2.4 Placeholder Throws
**Check ID**: `placeholder-throw`

Grep for not-implemented throws:
```
throw\s+new\s+Error\s*\(\s*['"](?:not implemented|TODO|not yet|NYI|FIXME|PLACEHOLDER)
```
Case-insensitive.

**Severity**: Critical in business logic, High elsewhere.
**Fixable**: No — requires implementation.

#### 2.5 Empty Function Bodies
**Check ID**: `empty-function`

Grep for functions/methods with only whitespace between braces. Exclude:
- Interface declarations
- Abstract methods
- Intentional no-ops (commented with `// noop` or `// intentional`)

**Severity**: Critical in store actions/API handlers/middleware. Medium elsewhere.
**Fixable**: No — requires implementation.

#### 2.6 No-Op Event Handlers
**Check ID**: `noop-handler`

Grep for empty arrow functions used as handlers:
```
\(\)\s*=>\s*\{\s*\}
```

Exclude test mocks (`vi.fn()`, `jest.fn()`), explicit no-op utilities.

**Severity**: High if bound to user interactions. Low otherwise.
**Fixable**: No — requires implementation.
**Category**: Correctness.

#### 2.7 Placeholder Returns
**Check ID**: `placeholder-returns`

Grep for empty object/array returns that indicate stub implementations:
```
return\s*\{\s*\}
return\s*\[\s*\]
```

Exclude guard clauses (`if (!x) return {}`), functions named `*empty*` or `*default*`.

**Severity**: High in store actions, composables, API handlers. Medium elsewhere.
**Fixable**: No — requires real implementation.
**Category**: Correctness.

#### 2.8 Hardcoded Secrets
**Check ID**: `hardcoded-secret`

Grep for high-confidence secret patterns:
```
(?:api[_-]?key|apikey|secret|password|token|credential)\s*[:=]\s*['"][A-Za-z0-9+/=]{8,}['"]
```
Also detect known prefixes: `AIza` (Google), `sk-` (OpenAI/Stripe), `ghp_` (GitHub), `AKIA` (AWS).

Exclude test files, `.env.example`, fixture files.

**Severity**: Critical.
**Fixable**: No — needs environment variable migration.
**Category**: Security.

#### 2.9 TypeScript `any` Usage
**Check ID**: `typescript-any`

Grep for explicit `any` types:
```
:\s*any\b
as\s+any\b
<any>
```

Exclude comments, generated files, type stubs, and lines with `sweep-ignore`.

**Severity**: Medium.
**Fixable**: Semi — can replace `: any` with `: unknown` but needs typecheck verification.
**Category**: Convention.

#### 2.10 Skipped Tests
**Check ID**: `skipped-test`

Grep test files for skipped test markers:
```
it\.skip\(|xit\(|describe\.skip\(|test\.skip\(
```

**Severity**: Medium.
**Fixable**: Yes — remove `.skip` from the test call (e.g., `it.skip(` -> `it(`).
**Category**: Correctness.

#### 2.11 Loose Equality
**Check ID**: `loose-equality`

Grep for `==` and `!=` (non-strict comparison):
```
[^!=]==[^=]
[^!]=!=[^=]
```

Exclude `== null` and `== undefined` (idiomatic null checks). Exclude comments and strings.

**Severity**: Low.
**Fixable**: Yes — replace `==` with `===` and `!=` with `!==`. Exclude `== null`/`== undefined`.
**Category**: Correctness.

#### 2.12 Unnecessary Return Await
**Check ID**: `return-await`

Grep for `return await` outside of try blocks:
```
return\s+await\s+
```

Exclude occurrences inside try blocks (where `return await` IS needed to catch rejections). Use multi-line context to check for enclosing try.

**Severity**: Low.
**Fixable**: Yes — remove `await` keyword from return statement.
**Category**: Optimization.

#### 2.13 Missing Optional Chaining
**Check ID**: `optional-chaining`

Grep for guard patterns that could use `?.`:
```
(\w+)\s*&&\s*\1\.(\w+)
```

Detects `x && x.y` patterns that could be `x?.y`.

Exclude method calls with side effects (only fix property reads, not `.push()`, `.splice()`, etc.).

**Severity**: Low.
**Fixable**: Yes — replace `x && x.y` with `x?.y` (property reads only).
**Category**: Reduction.

#### 2.14 Redundant Else After Return
**Check ID**: `redundant-else`

Detect `} else {` blocks where the preceding if-block ends with `return` or `throw`:

Read context around `} else {` — if the 5 lines before contain `return` or `throw` within the same if-block, the else wrapper is redundant.

**Severity**: Low.
**Fixable**: Yes — remove `} else {` wrapper and dedent the else-body.
**Category**: Reduction.

#### 2.15 Nullish Coalescing Opportunity
**Check ID**: `nullish-coalescing`

Grep for verbose null checks replaceable with `??`:
```
(\w+)\s*!==?\s*(?:null|undefined)\s*\?\s*\1\s*:
```

Detects `x !== null ? x : default` patterns.

**Severity**: Low.
**Fixable**: Yes — replace with `x ?? default`.
**Category**: Reduction.

#### 2.16 Immediate Return Variable
**Check ID**: `immediate-return-var`

Detect patterns where a variable is assigned and immediately returned on the next line:
```
(const|let)\s+(\w+)\s*=\s*([^;]+);\s*\n\s*return\s+\2;
```

Uses multiline grep. Exclude destructuring assignments and variables with documentation value.

**Severity**: Low.
**Fixable**: Yes — inline the expression into the return statement.
**Category**: Reduction.

### Tier 2: Medium Confidence, Run Once Per Session (~30 seconds)

#### 2.17 Unused Imports
**Check ID**: `unused-import`

For each source file:
1. Extract imported symbols: `import\s+\{([^}]+)\}` and `import\s+(\w+)\s+from`
2. For each symbol, count occurrences in the file (including `<template>` section for `.vue` files)
3. If a symbol appears only in the import line, flag as unused

Exclude:
- Type-only imports in files that re-export types
- Files with `export * from` (barrel files)
- Vue files where the symbol appears in `<template>` section

**Severity**: Low.
**Fixable**: Yes — remove the unused import specifier. If all specifiers in an import statement are unused, remove the entire line. Run typecheck to verify.

#### 2.18 Commented-Out Code
**Check ID**: `commented-code`

Multi-signal heuristic — flag blocks of 3+ consecutive lines starting with `//` that contain code-like tokens:
```
^\s*//\s*(import |export |const |let |var |function |return |if \(|else |for \(|while \(|class |interface |await |async )
```

Exclude:
- JSDoc blocks (`@param`, `@returns`, `@example`)
- License/copyright headers
- Explanatory comments (lines without code tokens)

**Severity**: Low.
**Fixable**: Yes — delete the commented block. Requires minimum 3 consecutive lines.

#### 2.19 Stale TODO Aging
**Check ID**: `todo-age`

For findings from check 2.1, run git blame to determine age:
```bash
git blame -L <line>,<line> --porcelain <file> | grep 'author-time'
```

Bucket by age:
- **Red**: >180 days (or `todo_age_threshold_days` from config)
- **Yellow**: 30-180 days
- **Green**: <30 days

Cache blame results in `${SESSION_TMP_DIR}/todo-ages.json` for reuse.

**Severity**: Upgrades TODO severity — Red TODOs become High, Yellow stay as-is.
**Fixable**: No.
**Category**: Cleanup.

#### 2.20 Log-and-Return Stubs
**Check ID**: `log-and-return`

Detect functions whose body consists solely of `console.log`/`console.warn`/`console.error` calls optionally followed by a return statement. These indicate stub implementations.

Read function bodies — flag if the only logic is logging.

**Severity**: High in business logic. Medium elsewhere.
**Fixable**: No — requires real implementation.
**Category**: Correctness.

#### 2.21 Three-State UI Coverage
**Check ID**: `three-state-ui`

For `.vue` files containing data-fetching patterns (`useAsyncData`, `useFetch`, `useLazyFetch`, `$fetch`, store action calls), check that the template also contains:
- Loading state handling (`v-if` with `loading`, `pending`, `isLoading`)
- Error state handling (`v-if` with `error`, `isError`)

Flag files that fetch data but lack either loading or error states.

**Severity**: Medium.
**Fixable**: No — needs design decision for loading/error UI.
**Category**: Robustness.

#### 2.22 File Length
**Check ID**: `file-length`

Check source file line counts. Flag files exceeding the configured threshold (default: 300 lines).

```bash
wc -l <file>
```

**Severity**: Low (>300 lines), Medium (>500 lines).
**Fixable**: No — needs decomposition planning.
**Category**: Convention.

#### 2.23 Missing `:key` in `v-for`
**Check ID**: `missing-v-for-key`

Grep `.vue` template sections for `v-for` without a corresponding `:key`:
```
v-for=
```
Flag lines containing `v-for` but NOT `:key` on the same element.

**Severity**: Medium — causes rendering bugs with list reordering.
**Fixable**: No — developer must choose the correct key field.
**Category**: Correctness.

### Tier 3: Deep Analysis (only with `--deep`, ~90-150 seconds)

#### 2.24 Orphaned Files
**Check ID**: `orphaned-file`

**If knip is available** (`npx knip --version` succeeds):
```bash
npx knip --include files --reporter json 2>/dev/null
```
Parse JSON output for unused files.

**If knip is not available**, use grep-based detection:
1. For each source file, extract its module path
2. Grep entire project for imports of that module
3. If no imports found, flag as potentially orphaned

Exclude known entry points: `pages/**`, `layouts/**`, `middleware/**`, `plugins/**`, `server/api/**`, `main.*`, `app.*`, `index.*`, `nuxt.config.*`, `vite.config.*`.

**Severity**: Medium.
**Fixable**: No — too many false positives.

#### 2.25 Dead Exports
**Check ID**: `dead-export`

**If knip is available:**
```bash
npx knip --include exports --reporter json 2>/dev/null
```

**If knip is not available**, use grep-based detection:
1. Find all named exports: `export\s+(const|let|var|function|class|interface|type|enum)\s+(\w+)`
2. For each export, grep project for imports containing that symbol
3. If no imports found, flag as potentially dead

**Severity**: Low.
**Fixable**: No — risk of dynamic usage.

#### 2.26 Unused Dependencies
**Check ID**: `unused-dep`

**If knip is available:**
```bash
npx knip --include dependencies --reporter json 2>/dev/null
```

**If knip is not available**, read `package.json` dependencies and grep for imports:
```bash
for dep in <dependencies>; do
  grep -r "from ['\"]${dep}" src/ --include='*.ts' --include='*.vue' | head -1
done
```

Exclude framework-level dependencies that are used via config (e.g., `@nuxt/*`, `vite`, `typescript`).

**Severity**: Low.
**Fixable**: Semi-auto — can remove from `package.json`, but needs `npm install` to verify.

#### 2.27 Hardcoded Sample Data
**Check ID**: `sample-data`

Grep for large inline object arrays in non-test files:
```
(?:const|let)\s+\w+\s*(?::\s*\w+(?:\[\])?\s*)?=\s*\[
```
Flag arrays of 3+ inline objects with placeholder property values (`John`, `Jane`, `example`, `sample`, `test`, `foo`, `bar`).

Exclude: files in `fixtures/`, `seeds/`, `mocks/`, `__tests__/`, `test-utils/`.

**Severity**: Medium.
**Fixable**: No — needs real data source.
**Category**: Correctness.

#### 2.28 Unwired Store Actions
**Check ID**: `unwired-store-actions`

Scan store files (files in `stores/` or using `defineStore`) for actions that do not call any API/service function. Look for action methods that lack `fetch`, `$fetch`, `axios`, `httpsCallable`, `api.`, or service function calls.

**Severity**: High.
**Fixable**: No — needs API integration.
**Category**: Correctness.

#### 2.29 Sequential Await
**Check ID**: `sequential-await`

Grep for 2+ consecutive `await` statements on independent calls (calls that don't depend on the previous result):
```
await\s+\w+
```

Read context to check if the second `await` uses the result of the first. If independent, they should be wrapped in `Promise.all`.

**Severity**: Low.
**Fixable**: No — must verify independence before wrapping in `Promise.all`.
**Category**: Optimization.

#### 2.30 N+1 Query Patterns
**Check ID**: `n-plus-one`

Grep for `await` inside loop bodies (`for`, `forEach`, `map`):
```
\.(forEach|map|for)\s*\(.*\{[\s\S]*?await\s+
```

Use multiline grep to detect async operations inside iteration.

**Severity**: Medium.
**Fixable**: No — needs batch API design.
**Category**: Optimization.

#### 2.31 XSS via v-html
**Check ID**: `v-html-xss`

Grep `.vue` files for `v-html` usage:
```
v-html=
```

Flag all usages — `v-html` renders raw HTML and is a potential XSS vector. Especially dangerous when bound to user-controlled data.

**Severity**: High if bound to variable (not a static string). Medium for static strings.
**Fixable**: No — needs sanitization review.
**Category**: Security.

#### 2.32 Nesting Depth
**Check ID**: `nesting-depth`

For each source file, count the maximum nesting depth of `if`/`for`/`while`/`switch` blocks. Flag functions with nesting depth > 4 (configurable via `max_nesting_depth`).

Approximate by tracking brace depth at lines containing control flow keywords.

**Severity**: Medium (depth 5-6). Low (depth 4).
**Fixable**: No — needs refactoring (extract functions, early returns).
**Category**: Convention.

---

## Phase 3: DIFF — Compare Against Previous State

### 3.1 Assign Finding IDs

For each finding, compute a stable ID:
```
{check_id}-{file_path}-{line}-{symbol_or_snippet_hash}
```

The ID must be stable across runs so findings can be tracked.

### 3.2 Compare Against Ledger

For each finding:
- If ID exists in ledger with `status: found` — **existing** finding (carry forward)
- If ID exists in ledger with `status: fixed` — **regression** (re-opened, elevated priority)
- If ID exists in ledger with `status: wontfix` or `false-positive` — **suppressed** (skip)
- If ID is not in ledger — **new** finding

For each ledger entry not found in current scan:
- Mark as **resolved** (the issue was fixed outside of code-sweep)

### 3.3 Build Priority Queue

Sort findings for the fix queue using two dimensions: **freshness** and **category priority**.

**Freshness order** (outer sort):
1. **Regressions** first (previously fixed, now reappeared)
2. **New findings** next (just introduced)
3. **Existing findings** last (carried forward from previous scans)

**Category priority** (inner sort, research-backed ordering for maximum impact):
1. **Convention** fixes (74% issue reduction in studies)
2. **Reduction** fixes (high-confidence simplification)
3. **Correctness** fixes (44% reduction)
4. **Optimization** fixes (needs careful verification)
5. **Security** reports (32% reduction, mostly report-only)
6. **Cleanup** fixes (existing checks)
7. **Robustness** reports

Within each category, sort by:
1. Severity: critical > high > medium > low
2. Fixable: auto-fixable first
3. Age: oldest first (for TODOs with age data)

### 3.4 Compute Delta

Calculate:
- `new_count`: findings not in previous ledger
- `resolved_count`: previous findings no longer present
- `regressed_count`: previously fixed findings that reappeared
- `total_delta`: current total - previous total

---

## Phase 4: ACT — Apply Fixes (if enabled)

**Skip this phase entirely if mode is `--scan-only`.**

### 4.0 Auto-Detect Verify Command

If `verify_command` is not set in config, detect:
```bash
# Check for TypeScript
[ -f "tsconfig.json" ] && VERIFY_TS="npx tsc --noEmit"

# Check for ESLint
[ -f ".eslintrc*" ] || [ -f "eslint.config.*" ] && VERIFY_LINT="npx eslint . --quiet"

# Combine available checks
VERIFY_CMD="${VERIFY_TS:+$VERIFY_TS && }${VERIFY_LINT:+$VERIFY_LINT}"
```

If no verify command can be detected, warn and proceed without verification (but log this as a risk).

### 4.1 Select Fix Target

Pop the highest-priority **fixable** finding from the queue.

If no fixable findings remain, print `[code-sweep] No auto-fixable findings remaining` and skip to Phase 5.

### 4.2 Apply Fix

Apply the fix strategy from reference.md for the finding's check category:

| Check ID | Fix Strategy | Category |
|----------|-------------|----------|
| `console-log` | Remove the line with `Edit`. If the line is the only statement in a block, remove just the `console.*` call. | Cleanup |
| `empty-catch` | Insert `console.error(<catch-param>)` as the first line inside the catch block using `Edit`. | Cleanup |
| `unused-import` | Remove the unused specifier from the import statement using `Edit`. If all specifiers are unused, remove the entire import line. | Cleanup |
| `commented-code` | Delete the consecutive block of commented-out code lines using `Edit`. | Cleanup |
| `skipped-test` | Remove `.skip` from the test call (e.g., `it.skip(` -> `it(`). | Correctness |
| `loose-equality` | Replace `==` with `===` and `!=` with `!==`. Exclude `== null` and `== undefined`. | Correctness |
| `return-await` | Remove `await` from `return await expr` (only outside try blocks). | Optimization |
| `optional-chaining` | Replace `x && x.y` with `x?.y` (property reads only, not method calls with side effects). | Reduction |
| `redundant-else` | Remove `} else {` wrapper and dedent the else-body when preceding if-block ends with return/throw. | Reduction |
| `nullish-coalescing` | Replace `x !== null ? x : default` with `x ?? default`. | Reduction |
| `immediate-return-var` | Inline the variable assignment into the return statement: `const r = expr; return r;` -> `return expr;`. | Reduction |

For each fix:
1. Read the file to confirm the finding still exists at the expected location.
2. Apply the edit.
3. Log the fix: `[code-sweep] Fixed: <check_id> in <file>:<line>`

### 4.3 Verify Fix

Run the verify command:
```bash
eval "${VERIFY_CMD}" 2>&1
```

**If verification passes:**
- Log success to activity feed
- Proceed to commit

**If verification fails:**
- Revert ALL changes from this tick:
  ```bash
  git checkout -- <modified-files>
  ```
- Mark the finding as `needs-human` in the ledger
- Increment the circuit breaker counter
- Log: `[code-sweep] Fix reverted: verification failed for <check_id> in <file>:<line>`

**Circuit breaker:** If `consecutive_failures >= 2`, switch to `--scan-only` for the rest of this session:
```
[code-sweep] Circuit breaker tripped: 2 consecutive fix failures. Switching to scan-only mode.
```

### 4.4 Commit Fix

If in `--loop` or `--fix` mode and verification passed:
```bash
git add <modified-files>
git commit -m "sweep(<check_id>): <brief description> in <file>"
```

If in `--loop` mode, also push:
```bash
git push origin HEAD || true
```

In `--fix-all` mode, accumulate fixes per category and commit once per category:
```bash
git add <all-modified-files-for-category>
git commit -m "sweep(<check_id>): auto-fix N instances"
```

### 4.5 Repeat (fix-all mode only)

If `--fix-all` is specified:
1. After committing one category, move to the next fixable category in priority order
2. Run verification after each category
3. If a category's verification fails, revert that category and continue to the next
4. Stop after all fixable categories are processed

---

## Phase 5: REPORT — Update State and Print Summary

### 5.1 Update Ledger

Append new and changed entries to `docs/sweeps/sweep-ledger.jsonl`:

```bash
mkdir -p docs/sweeps
```

For each finding:
- New findings: append with `status: "found"`
- Fixed findings (from Phase 4): append with `status: "fixed"`
- Resolved findings (gone from scan): append with `status: "resolved"`
- Regressed findings: append with `status: "found"` and `"regressed": true`

Use the ledger entry schema from reference.md.

### 5.2 Write Snapshot

Write a date-stamped snapshot to `docs/sweeps/YYYY-MM-DD.json` using the snapshot schema from reference.md.

If a snapshot for today already exists, append a counter: `YYYY-MM-DD-2.json`.

Also write/overwrite `docs/sweeps/latest.json` as a copy of the current snapshot.

### 5.3 Calculate Score

```
score = 100 - (critical * 10) - (high * 5) - (medium * 2) - (low * 0.5)
```
Clamp to 0-100. Exclude suppressed findings (`wontfix`, `false-positive`).

Assign grade: A (90-100), B (80-89), C (70-79), D (60-69), F (<60).

### 5.4 Print Summary

```
Code Sweep: <GRADE> (<score>/100)
======================================
Mode: <scan-only|fix|fix-all|loop>  |  Scope: <scope>
Files scanned: N source + M test
Run: #<run_number>  |  Previous score: <prev_score>/100

Findings: <total> (Critical: N, High: N, Medium: N, Low: N)
  New: +N  |  Resolved: -N  |  Regressed: N  |  Auto-fixable: N
  Delta: <+/-N from previous>

By category:
  Cleanup: N  |  Correctness: N  |  Optimization: N
  Convention: N  |  Security: N  |  Reduction: N  |  Robustness: N

<if --fix mode and a fix was applied>
Fixed this tick:
  [<severity>] <file>:<line> — <message> (<check_id>)

<if fixes remain>
Next auto-fixable:
  [<severity>] <file>:<line> — <message> (<check_id>)

Top issues:
  1. [<severity>] <file>:<line> — <message>
  2. [<severity>] <file>:<line> — <message>
  3. [<severity>] <file>:<line> — <message>
  4. [<severity>] <file>:<line> — <message>
  5. [<severity>] <file>:<line> — <message>

Snapshot: docs/sweeps/YYYY-MM-DD.json
Ledger: docs/sweeps/sweep-ledger.jsonl
```

Show up to 10 top issues, ordered by severity then file path.

If score is 100:
```
Code Sweep: A (100/100)
  No issues found. Codebase is clean.
```

### 5.5 Ratchet Check

If a previous snapshot exists, compare scores:
- If score improved: `[code-sweep] Ratchet: score improved +N (was <prev>, now <current>)`
- If score declined: `[code-sweep] Ratchet warning: score declined -N (was <prev>, now <current>). <new_count> new issues introduced.`
- If stable: `[code-sweep] Ratchet: stable at <score>/100`

### 5.6 Follow-Up Suggestions

| Condition | Suggestion |
|-----------|------------|
| Critical findings exist | `Run /blitz:fix-issue to resolve critical items` |
| Many TODOs aged >180 days | `Consider a TODO cleanup sprint` |
| Orphaned files detected | `Review orphaned files manually — they may be dead code or framework entry points` |
| Score < 60 | `Run /blitz:codebase-audit for a comprehensive quality review` |
| All auto-fixable done | `Run /blitz:code-sweep --deep for Tier 3 analysis` |
| Score improving over time | `Quality is trending up — keep sweeping` |
| Many correctness findings | `Run /blitz:code-sweep --category correctness --fix to focus on correctness` |
| Security findings detected | `Review hardcoded secrets and XSS patterns immediately` |
| Convention findings high | `Run /blitz:code-sweep --category convention --fix-all for convention alignment pass` |
| Reduction opportunities | `Run /blitz:code-sweep --category reduction --fix-all for code simplification` |

### 5.7 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Append `session_end` to the operations log
4. Log `skill_complete` to the activity feed
5. Print skill completion per verbose-progress.md

---

## Error Recovery

- **No source files in scope**: Report score 100, grade A. No findings.
- **Grep command fails**: Log the failed check, continue with remaining checks. Note incomplete coverage in snapshot.
- **`.code-sweep.json` is invalid JSON**: Warn and proceed with defaults.
- **Verify command not available**: Warn `"No verify command detected — fixes will not be verified"`. In `--loop` mode, refuse to fix without verification (safety).
- **Knip not available for --deep**: Fall back to grep-based detection. Note reduced accuracy in snapshot.
- **Git blame fails**: Skip TODO aging for affected files. Note in snapshot.
- **Fix breaks verification**: Revert, mark `needs-human`, continue to next finding.
- **All fixes fail**: Switch to `--scan-only`, warn user. Log to activity feed.
- **Concurrent code-sweep (fix mode)**: Conflict matrix blocks. Scan mode is always OK.
- **Ledger file corrupted**: Rename to `.bak`, start fresh ledger, warn user.
- **Snapshot already exists for today**: Append counter suffix (`YYYY-MM-DD-2.json`).

---

## Conflict Matrix Entries

| Session A | Session B | Resolution |
|-----------|-----------|------------|
| code-sweep (scan) | code-sweep (scan) | OK — read-only |
| code-sweep (fix) | code-sweep (fix) | **BLOCK** — concurrent edits |
| code-sweep (fix) | sprint-dev | WARN — both modify source |
| code-sweep (fix) | refactor | **BLOCK** — both modify source |
| code-sweep (scan) | sprint-dev | OK — read-only scan |
| code-sweep (scan) | Any | OK — read-only |
