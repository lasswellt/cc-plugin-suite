---
name: sprint-review
description: Reviews sprint quality with automated checks and parallel reviewer agents. Runs type-check, lint, tests, build verification. Spawns security, backend, frontend, and pattern reviewers. Auto-fixes common failures. Use when user says "review sprint", "check quality", "run review".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch
disable-model-invocation: true
model: opus
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Reference
See `${CLAUDE_SKILL_DIR}/reference.md` for review report template, quality gate checklist, auto-fix strategies, changed package detection rules, and review finding format.

---

# Sprint Review Skill

Review sprint quality through automated checks and parallel reviewer agents. Run type-check, lint, tests, and build verification. Spawn specialized reviewers for security, backend, frontend, and patterns. Auto-fix common failures. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: CONTEXT — Load Sprint State

1. **Find the sprint to review.** Read `sprint-registry.json` and find the sprint with `status: review` or `status: in-progress`. If the user specified a sprint number, use that. If no sprint is ready for review, inform the user and STOP.

2. **Load incomplete stories.** Read all story files in `${SPRINT_DIR}/stories/`. Categorize:
   - `done` — Implemented, ready for review.
   - `incomplete` — Partially done, flag for attention.
   - `blocked` — Skipped during implementation, note in report.

3. **Build codebase inventory.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```

4. **Detect changed files.** Compare against the sprint's base commit:
   ```bash
   # Find the merge base (commit before sprint started)
   SPRINT_BASE=$(git log --oneline --all | grep -i "sprint-${SPRINT_NUMBER}" | tail -1 | cut -d' ' -f1)
   # If no sprint commit found, use a reasonable default
   git diff --name-only ${SPRINT_BASE}..HEAD 2>/dev/null || git diff --name-only HEAD~20..HEAD
   ```

5. **Detect changed packages.** From the changed files, determine which packages/workspaces were modified (see reference.md for detection rules).

6. **Load registry.** Read `sprint-registry.json` for sprint metadata.

**Gate:** At least one story must have `status: done` and changed files must be detectable.

---

## Phase 1: AUTOMATED CHECKS — Quality Gates

Run all automated checks. Record pass/fail for each. Do NOT stop on first failure — run all checks and collect all results.

### 1.1 Type-Check

```bash
# Detect type-check command from package.json scripts
npm run type-check 2>&1 || npx tsc --noEmit 2>&1
```

Record:
- Pass/Fail
- Error count
- Error list (file, line, message) for auto-fix phase

### 1.2 Lint

```bash
# Detect lint command from package.json scripts
npm run lint 2>&1 || npx eslint . 2>&1
```

Record:
- Pass/Fail
- Warning count, error count
- Error list for auto-fix phase

### 1.3 Unit Tests (Changed Packages Only)

Run tests only for changed packages to save time:

```bash
# For monorepo with workspaces
# Run tests in each changed package
for pkg in ${CHANGED_PACKAGES}; do
  (cd "$pkg" && npm run test 2>&1) || true
done

# For single-package projects
npm run test -- --changed 2>&1 || npm run test 2>&1
```

Record:
- Total tests, passed, failed, skipped
- Failure details (test name, file, assertion message)

### 1.4 Build Verification

```bash
npm run build 2>&1
```

Record:
- Pass/Fail
- Error details if failed

### 1.5 Quality Gate Summary

Write intermediate results to `/tmp/sprint-${SPRINT_NUMBER}-quality-gates.json`:
```json
{
  "type_check": { "pass": true, "errors": 0, "details": [] },
  "lint": { "pass": false, "errors": 3, "warnings": 12, "details": [] },
  "tests": { "pass": true, "total": 45, "passed": 45, "failed": 0 },
  "build": { "pass": true, "errors": 0 }
}
```

---

## Phase 2: CODE REVIEW — Parallel Reviewer Agents

### 2.1 Create Review Team

Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-review`.

### 2.2 Prepare Review Context

Collect the diff for reviewers:
```bash
git diff ${SPRINT_BASE}..HEAD > /tmp/sprint-${SPRINT_NUMBER}-full-diff.patch
```

Also list all new and modified files with their sizes for assignment:
```bash
git diff --stat ${SPRINT_BASE}..HEAD
```

### 2.3 Spawn Reviewer Agents

Spawn 3-4 specialized reviewers. Each writes findings to `/tmp/` files.

| Agent Name | Focus | Output File |
|---|---|---|
| `security-reviewer` | Auth, input validation, secrets, injection, XSS, CSRF | `/tmp/sprint-${N}-review-security.md` |
| `backend-reviewer` | API design, error handling, data validation, performance | `/tmp/sprint-${N}-review-backend.md` |
| `frontend-reviewer` | Component design, accessibility, UX, responsive, state mgmt | `/tmp/sprint-${N}-review-frontend.md` |
| `pattern-reviewer` | Code consistency, naming, DRY, architecture, test coverage | `/tmp/sprint-${N}-review-patterns.md` |

### 2.4 Reviewer Instructions

Each reviewer receives:
1. The full diff or relevant subset of changed files.
2. The list of story acceptance criteria for context.
3. Quality gate results from Phase 1.
4. Their specific review checklist (see reference.md).

### 2.5 Cross-Finding Protocol

Reviewers send cross-cutting findings to sibling reviewers via:
```
SendMessage to <sibling-reviewer>:
CROSS-FINDING: <category> — <summary>
File: <path>:<line>
Severity: critical | major | minor | info
Details: <description>
```

Examples:
- Security reviewer finds unvalidated input -> sends CROSS-FINDING to backend-reviewer.
- Pattern reviewer finds inconsistent component structure -> sends CROSS-FINDING to frontend-reviewer.
- Backend reviewer finds missing error boundary -> sends CROSS-FINDING to frontend-reviewer.

### 2.6 Collect Review Findings

Wait for all reviewers to complete. Read their output files. Merge cross-findings (deduplicate by file+line).

Categorize all findings:
- **Critical**: Security vulnerabilities, data loss risks, auth bypasses. MUST fix before merge.
- **Major**: Broken functionality, missing error handling, accessibility violations. Should fix.
- **Minor**: Code style, naming, minor performance. Fix if time permits.
- **Info**: Suggestions, alternative approaches, future improvements. Document only.

---

## Phase 3: AUTO-FIX — Resolve Common Failures

### 3.1 Auto-Fix Scope

Auto-fix ONLY these categories. **Never auto-fix security issues** — those require human review.

| Category | Auto-Fix Strategy | Max Attempts |
|---|---|---|
| Type errors | Add missing types, fix type mismatches, add null checks | 3 |
| Lint errors | Apply lint auto-fix, then manual fixes for remaining | 3 |
| Missing exports | Add exports to barrel files (index.ts) | 3 |
| Import errors | Fix import paths, add missing imports | 3 |
| Naming inconsistencies | Rename to match project conventions | 2 |
| Missing return types | Add explicit return types to functions | 2 |
| Unused imports | Remove unused imports | 1 |
| Unused variables | Prefix with underscore or remove if safe | 1 |

### 3.2 Auto-Fix Loop

For each fixable issue:

```
attempt = 0
while issue not resolved AND attempt < max_attempts:
    attempt += 1
    apply fix
    run relevant check (type-check, lint, or test)
    if check passes:
        commit: "fix(sprint-${N}/review): auto-fix <category> in <file>"
        mark resolved
    else:
        revert fix if it made things worse
        try alternative fix strategy
```

### 3.3 Fix Ordering

Fix in this order (earlier fixes often resolve later issues):
1. Missing imports and exports (resolves most type errors downstream).
2. Type errors (resolves downstream lint and test errors).
3. Lint errors (auto-fix first, then manual).
4. Naming inconsistencies.
5. Unused imports/variables (cosmetic, last).

### 3.4 Auto-Fix Boundaries

**DO NOT auto-fix:**
- Security findings (XSS, injection, auth bypass, secrets exposure).
- Logic errors (wrong business logic, incorrect calculations).
- Architecture issues (wrong abstraction, missing separation of concerns).
- Test assertion failures (the test might be correct and the code wrong).
- Performance issues (require design decisions).

These are documented in the report for human review.

### 3.5 Post-Fix Verification

After all auto-fixes, re-run the full quality gate suite from Phase 1:
```bash
npm run type-check 2>&1
npm run lint 2>&1
npm run test 2>&1
npm run build 2>&1
```

Record improvement:
```
Before auto-fix: type-errors=12, lint-errors=8, test-failures=2
After auto-fix:  type-errors=0,  lint-errors=1,  test-failures=2
```

---

## Phase 4: REPORT — Write Review Report and Update Registry

### 4.1 Write Review Report

Write `${SPRINT_DIR}/review-report.md` using the template from reference.md. Include:

1. **Executive Summary** — Sprint number, date, overall status (PASS/CONDITIONAL/FAIL).
2. **Quality Gates** — Pass/fail table for all automated checks (before and after auto-fix).
3. **Review Findings** — All findings from reviewer agents, grouped by severity.
4. **Auto-Fix Summary** — What was fixed, what remains, what was skipped.
5. **Story Status** — Table of all stories with final status.
6. **Recommendations** — Prioritized list of manual fixes needed before merge.

### 4.2 Determine Overall Status

| Status | Criteria |
|---|---|
| **PASS** | All quality gates pass. No critical or major findings. |
| **CONDITIONAL** | Quality gates pass but major findings exist. Or: minor gate failures with no critical findings. |
| **FAIL** | Any quality gate fails after auto-fix. Or: critical findings exist. |

### 4.3 Update Sprint Registry

Update `sprint-registry.json`:
```json
{
  "number": <N>,
  "status": "reviewed",
  "review_date": "<ISO-8601>",
  "review_status": "PASS|CONDITIONAL|FAIL",
  "quality_gates": {
    "type_check": true,
    "lint": true,
    "tests": true,
    "build": true
  },
  "findings": {
    "critical": 0,
    "major": 2,
    "minor": 5,
    "info": 8
  },
  "auto_fixes_applied": 7,
  "stories_reviewed": 12,
  "stories_done": 10,
  "stories_incomplete": 1,
  "stories_blocked": 1
}
```

### 4.4 Shutdown Review Team

Send completion message to all reviewer agents and shutdown the team.

### 4.5 Git Commit

```bash
git add ${SPRINT_DIR}/review-report.md
git add sprint-registry.json
git commit -m "review(sprint-${N}): ${STATUS} — ${FINDINGS_CRITICAL}c/${FINDINGS_MAJOR}M/${FINDINGS_MINOR}m findings, ${AUTO_FIXES} auto-fixes"
```

### 4.6 Final Output

Print summary to user:

```
Sprint ${SPRINT_NUMBER} Review Complete: ${STATUS}

Quality Gates:
  Type-check: PASS/FAIL (N errors)
  Lint:       PASS/FAIL (N errors, N warnings)
  Tests:      PASS/FAIL (N passed, N failed)
  Build:      PASS/FAIL

Findings:
  Critical: N (MUST fix before merge)
  Major:    N (should fix)
  Minor:    N (optional)
  Info:     N (suggestions)

Auto-Fixes Applied: N
  Type errors fixed: N
  Lint errors fixed: N
  Import fixes: N

Stories: N done, N incomplete, N blocked

Report: ${SPRINT_DIR}/review-report.md
Next: ${RECOMMENDED_ACTION}
```

Where `RECOMMENDED_ACTION` is:
- PASS: "Ready to merge. Run `git merge sprint-${N}/merged` into main."
- CONDITIONAL: "Review major findings in report before merging."
- FAIL: "Fix critical issues before merging. See report for details."

---

## Error Recovery

- **Quality gate command not found**: Try alternative commands (e.g., `npx tsc --noEmit` if `npm run type-check` fails). Skip gracefully if no equivalent exists and note in report.
- **Reviewer agent failure**: Retry once. If still failing, proceed with available reviews and note the gap.
- **Auto-fix makes things worse**: Revert immediately using `git checkout -- <file>`. Move to next issue.
- **Git diff base not found**: Fall back to `HEAD~20` or ask user for the base commit.
- **No test runner found**: Skip test gate, mark as "SKIPPED" (not "FAIL") in report.
