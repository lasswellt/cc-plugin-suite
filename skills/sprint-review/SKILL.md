---
name: sprint-review
description: Reviews sprint quality with automated checks and parallel reviewer agents. Runs type-check, lint, tests, build verification. Spawns security, backend, frontend, and pattern reviewers. Auto-fixes common failures. Use when user says "review sprint", "check quality", "run review".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, TeamCreate, SendMessage
disable-model-invocation: false
model: opus
compatibility: ">=2.1.71"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For review report template, reviewer checklists, and auto-fix strategies, see [reference.md](reference.md)
- For context window hygiene (reviewer agents), see [context-management.md](/_shared/context-management.md)
- For checkpoint awareness, see [checkpoint-protocol.md](/_shared/checkpoint-protocol.md)
- For handling reviewer agent escalations, see [deviation-protocol.md](/_shared/deviation-protocol.md)
- For the carry-forward registry enforced by Phase 3.5 (hard gate), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For subagent type selection, see [subagent-types.md](/_shared/subagent-types.md)
- For agent workload sizing and defensive patterns, see [agent-workload-sizing.md](/_shared/agent-workload-sizing.md)

All auto-fix code must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations.

---

# Sprint Review Skill

Review sprint quality through automated checks and parallel reviewer agents. Run type-check, lint, tests, and build verification. Spawn specialized reviewers for security, backend, frontend, and patterns. Auto-fix common failures. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: CONTEXT — Load Sprint State

0. **Register session.** Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

1. **Find the sprint to review.** Read `sprint-registry.json` and find the sprint with `status: review` or `status: in-progress`. If the user specified a sprint number, use that. If no sprint is ready for review, inform the user and STOP.

1b. **Check for STATE.md.** If the sprint has a `STATE.md` checkpoint file, read it for context on blocked stories and their reasons. Include blocked story details in the review report. See [checkpoint-protocol.md](/_shared/checkpoint-protocol.md).

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

Write intermediate results to `${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-quality-gates.json`:
```json
{
  "type_check": { "pass": true, "errors": 0, "details": [] },
  "lint": { "pass": false, "errors": 3, "warnings": 12, "details": [] },
  "tests": { "pass": true, "total": 45, "passed": 45, "failed": 0 },
  "build": { "pass": true, "errors": 0 }
}
```

---

## Phase 1.5: PATTERN ANALYSIS — Anti-Mock Scan and Convention Check

### 1.5.1 Anti-Mock Scan

Scan all changed files for placeholder/mock code:
```bash
git diff --name-only ${SPRINT_BASE}..HEAD | xargs grep -n -E \
  '(TODO|FIXME|PLACEHOLDER|STUB|Not implemented|throw new Error.*implement|return \{\}|return \[\])' 2>/dev/null
```

Any matches are **Critical findings** — code is not production-ready. Record each match with file, line, and pattern.

### 1.5.2 Convention Compliance

Check changed files against project conventions:
- **Backend files**: Have auth/validation patterns? Use project's error format?
- **Frontend files**: Handle loading, empty, and error states (three-state pattern)?
- **Store actions**: Call real APIs (not returning hardcoded data)?
- **Test files**: Assert meaningfully (not just `toBeDefined()` or `expect(true).toBe(true)`)?

### 1.5.3 Architectural Compliance

Check for improper cross-layer imports:
- Frontend files should not import directly from server/functions directories
- Backend files should not import Vue components
- Test files should not import from other test files' internals

### 1.5.4 Completeness Check

- Verify all files listed in done stories actually exist
- Check for silently dropped circuit-breaker stories (stories that were blocked but not documented)

### 1.6 Integration Check (Conditional)

If the sprint introduced new modules, routes, stores, or API endpoints, run integration-check to validate cross-module wiring:

```bash
# Detect if sprint introduced new modules
NEW_MODULES=$(git diff --name-only ${SPRINT_BASE}..HEAD | grep -E 'stores/|composables/|pages/|server/api/' | head -20)
if [ -n "$NEW_MODULES" ]; then
  echo "New modules detected — running integration check"
fi
```

If new modules are detected, invoke `/blitz:integration-check all` and map findings to review severity levels:
- Integration-check **high** → Review **Major**
- Integration-check **medium** → Review **Minor**
- Integration-check **low** → Review **Info**

Include integration-check findings in the Phase 2 review context so reviewer agents are aware of wiring gaps.

---

## Phase 2: CODE REVIEW — Parallel Reviewer Agents

### 2.1 Create Review Team

Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-review`.

> **Subagent type**: Reviewer agents must call `Write` to persist findings to
> tmp files. Spawn each with `subagent_type: general-purpose` — include the
> explicit line "You are a general-purpose agent with Write access — your task
> is INCOMPLETE if your output file does not exist" in every `SendMessage` body.
> Never rely on SDK heuristics. See [subagent-types.md](/_shared/subagent-types.md).

### 2.2 Prepare Review Context

Collect the diff for reviewers:
```bash
git diff ${SPRINT_BASE}..HEAD > ${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-full-diff.patch
```

Also list all new and modified files with their sizes for assignment:
```bash
git diff --stat ${SPRINT_BASE}..HEAD
```

### 2.3 Spawn Reviewer Agents

Spawn 3-4 specialized reviewers. Each writes findings to session-scoped temp files.

**Weight class**: Medium (per [agent-workload-sizing.md](/_shared/agent-workload-sizing.md)). Each reviewer prompt MUST include:
- Diff slice bounded by domain (max 500 lines of diff per reviewer — slice the full diff by changed-file path prefix)
- Max 15 file reads per reviewer
- Max 25 tool calls per reviewer
- Max 300-line output
- 5-minute wall-clock budget
- Write-as-you-go: "Append each finding to your output file immediately after identifying it"

| Agent Name | Focus | Output File |
|---|---|---|
| `security-reviewer` | Auth, input validation, secrets, injection, XSS, CSRF | `${SESSION_TMP_DIR}/sprint-${N}-review-security.md` |
| `backend-reviewer` | API design, error handling, data validation, performance | `${SESSION_TMP_DIR}/sprint-${N}-review-backend.md` |
| `frontend-reviewer` | Component design, accessibility, UX, responsive, state mgmt | `${SESSION_TMP_DIR}/sprint-${N}-review-frontend.md` |
| `pattern-reviewer` | Code consistency, naming, DRY, architecture, test coverage | `${SESSION_TMP_DIR}/sprint-${N}-review-patterns.md` |

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

Wait for all reviewers to complete. **Before reading any file, validate output presence**:

```bash
MISSING_COUNT=0
EXPECTED_FILES=(
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-security.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-backend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-frontend.md"
  "${SESSION_TMP_DIR}/sprint-${SPRINT_NUMBER}-review-patterns.md"
)
for f in "${EXPECTED_FILES[@]}"; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    MISSING_COUNT=$((MISSING_COUNT+1))
    # Log failure to .cc-sessions/activity-feed.jsonl
  fi
done
```

**Gate**: If `MISSING_COUNT >= 2` (half or more reviewers failed), ABORT Phase 2 and report to user. A security-domain miss is particularly dangerous — never silently ship a review with the security reviewer missing.

If `MISSING_COUNT == 1`: retry the failed reviewer once with a narrower scope (one domain/file prefix). If still failed, the final report MUST explicitly state that domain X was not reviewed.

**Also check for `PARTIAL: true` markers** in successful files. Treat PARTIAL reviewers as half-coverage; note MISSING sections in the final report.

If all files are present and non-empty: read their output files. Merge cross-findings (deduplicate by file+line).

Categorize all findings:
- **Critical**: Security vulnerabilities, data loss risks, auth bypasses. MUST fix before merge.
- **Major**: Broken functionality, missing error handling, accessibility violations. Should fix.
- **Minor**: Code style, naming, minor performance. Fix if time permits.
- **Info**: Suggestions, alternative approaches, future improvements. Document only.

---

## Phase 2.5: BROWSER VERIFICATION (Best-Effort)

If Playwright MCP is available and a dev server can start:

### 2.5.1 Identify Changed Routes

From changed page files, determine which routes were added or modified.

### 2.5.2 Smoke Test

Navigate to each changed route. For each page:
- Check for console errors (Critical or Error severity)
- Check for placeholder/sample data visible on screen (Warning)
- Check for broken layouts or missing content (Warning)

### 2.5.3 Integrate Findings

Add browser findings to the review report:
- Console errors → Error or Critical severity
- Placeholder data visible → Warning severity
- Visual issues → Minor severity

Skip gracefully if Playwright is unavailable — document as a gap in the report, not a failure.

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

## Phase 3.6: REGISTRY INVARIANTS — Carry-Forward Hard Gate

This phase is a **hard gate**: failing any invariant fails the sprint close. Its purpose is to make silent scope drops impossible by auditing the carry-forward registry against the current sprint's state. See [carry-forward-registry.md](/_shared/carry-forward-registry.md) for the full protocol and `docs/_research/2026-04-08_sprint-carryforward-registry.md` for the incident that motivated it.

### 3.6.1 Load the Registry

Reduce `.cc-sessions/carry-forward.jsonl` to latest-wins state:

```bash
REGISTRY=$(jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo '[]')
```

Load the current sprint's manifest (`sprints/sprint-${SPRINT_NUMBER}/manifest.json`) and `sprint-registry.json`. Load `docs/roadmap/epic-registry.json` if it exists. Identify every research doc referenced (directly or transitively) by any story, epic, or capability in this sprint — call this `SPRINT_RESEARCH_DOCS`.

### 3.6.2 Invariant 1 — Quantified Scope Has a Registry Entry

For every doc in `SPRINT_RESEARCH_DOCS`:

1. Scan the doc's Summary, Findings, and Recommendation sections for quantified language — regex `\d+\s+(files|components|modals|routes|tests|endpoints|pages|views|tables|migrations|fields|records)`.

2. If a match is found:
   - **Acceptable case A:** the doc has a `scope:` YAML frontmatter block covering the match, AND the block's `id` exists in the registry → pass.
   - **Acceptable case B:** the match is inside an HTML comment `<!-- no-registry: <reason> -->` → pass.
   - **Failure case:** neither — **FAIL** this invariant. Print the offending file and line range. Require the author to either (a) add a `scope:` block and re-run `/blitz:roadmap extend` before sprint close or (b) annotate the line with a `no-registry` comment and a reason.

Record matching results as `invariant_1: {pass|fail, violations: [...]}` in the report.

### 3.6.3 Invariant 2 — Active Entries Are Touched or Explicitly Deferred

For every registry entry with `status ∈ {active, partial}`:

- **Touched:** `last_touched.sprint == sprint-${SPRINT_NUMBER}` → pass.
- **Explicitly deferred:** the latest line for the entry has `event: "deferred"` with a non-empty `notes` AND was written during this sprint → pass.
- **Waivered this sprint:** the entry id appears in the current manifest's `registry_entries_touched`, AND the registry has a matching `event: "auto_waived"` line dated within this sprint → pass. This catches sprint-plan Phase 4.1 auto-waivers.
- **Otherwise:** **FAIL** this invariant. Increment `rollover_count` in a new registry line:
  ```jsonl
  {"id":"<entry-id>","ts":"<ISO-8601>","event":"correction","rollover_count":<prev+1>,"notes":"sprint-review Invariant 2: entry not touched in sprint-${SPRINT_NUMBER}"}
  ```
  Require the operator to (a) link a story in this sprint that advanced the entry, (b) write a `deferred` event with a reason, or (c) write a `dropped` event with `drop_reason` + `revival_candidate`.

**Waiver accounting sub-check:** cross-reference manifest `waived_ac_count > 0` against the registry. For every sprint with waivers, there MUST be at least one `event: "auto_waived"` line written during the sprint for an entry whose `parent.epic` appears in the sprint manifest's `epics` array. Missing mirror → Invariant 2 failure.

**Rollover escalation:** if any entry crosses `rollover_count >= 3` as a result of this invariant, print a loud escalation banner to stdout AND record the entry as `blocker: rollover-escalation` in the report. These entries are no longer eligible for auto-inject in Invariant 4 — they require mandatory human review before the next sprint can plan around them. This prevents infinite `/loop` bouncing on stuck work.

### 3.6.4 Invariant 3 — Roadmap Completion Claims Match Registry Coverage

Read `docs/roadmap/roadmap-registry.json` and `docs/roadmap/tracker.md` (if they exist) and extract any completion claims — typically "N/N epics complete" in the registry JSON or a completion column in the tracker.

For every epic marked `status: done|complete` that has a non-empty `registry_entries` field in the epic registry:

- Every referenced registry id MUST have `status == complete` in the latest-wins registry.
- Any mismatch → **FAIL** this invariant with a precise delta:
  ```
  MISMATCH: Epic EPIC-105 claims status=done, but registry entry
    cf-2026-04-02-modal-consistency is status=partial at coverage=0.646
    (delivered 84/130 files). Registry is authoritative — either close
    the gap or revert the epic to status=in-progress.
  ```

Fix path: roll the epic's status back to `in-progress` OR write a `dropped`/`deferred` event on the offending entry with a reason. Do NOT silently change the registry entry to `complete` — that is the drop this whole mechanism exists to prevent.

### 3.6.5 Invariant 4 — Auto-Inject Uncompleted Active Entries Into Next Sprint

For every registry entry with `status == active` AND `coverage < 1.0` AND `rollover_count < 3` (entries at 3+ are escalated, see 3.6.3):

Write the entry's id to `sprints/sprint-$((SPRINT_NUMBER + 1))-planning-inputs.json`:

```json
{
  "source_sprint": "sprint-${SPRINT_NUMBER}",
  "auto_injected": "<ISO-8601>",
  "reason": "Invariant 4 auto-inject from sprint-review",
  "mandatory_entries": [
    {
      "id": "cf-...",
      "parent": { "capability": "CAP-...", "epic": "EPIC-..." },
      "remaining_scope": { "unit": "files", "target": 130, "actual": 84 },
      "rollover_count": 1
    }
  ]
}
```

The next invocation of `sprint-plan` will read this file in Phase 0 step 8 and must either (a) generate stories against each `mandatory_entries` item or (b) the operator must explicitly `defer`/`drop` the entry before planning runs. This is **Linear cycle semantics**: nothing silently falls out of view. See [carry-forward-registry.md](/_shared/carry-forward-registry.md).

Partial entries (`status == partial`) are not auto-injected here — they carry their own state forward via the normal reader path (sprint-plan Phase 0 step 8 reads both active and partial entries). Only `active` with `coverage < 1.0` needs the explicit file marker for visibility.

### 3.6.6 Invariants Report

Write invariants results to the sprint review report under a `## Registry Invariants` section. Include:

- Per-invariant pass/fail status
- Violations with file/entry references
- `rollover_count` updates
- Entries auto-injected into the next sprint
- Any escalations at `rollover_count >= 3`

**Hard gate decision:**

- **All four invariants pass** → Phase 3.6 passes, proceed to Phase 4 (Report) with `review_status` unchanged by this phase.
- **Any invariant fails** → Phase 3.6 fails. The sprint close transitions to `CONDITIONAL` at best (see Phase 4.2 overall status table), and the failing invariants are listed under `Critical` findings in the report. The sprint CANNOT be marked `PASS` while registry invariants are failing. In `autonomy=full`, the failures are logged to the activity feed and the sprint is marked `CONDITIONAL` — the next `/loop` tick must address the failures before proceeding.

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
| **PASS** | All quality gates pass. No critical or major findings. **All four Phase 3.6 registry invariants pass.** |
| **CONDITIONAL** | Quality gates pass but major findings exist. Or: minor gate failures with no critical findings. Or: **any Phase 3.6 registry invariant fails** — the sprint cannot reach PASS while carry-forward state is inconsistent. |
| **FAIL** | Any quality gate fails after auto-fix. Or: critical findings exist. Or: **a Phase 3.6 invariant failure escalates to `rollover_count >= 3`** on any entry and the operator has not resolved it. |

### 4.3 Update Sprint Registry

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

### 4.5.5 Record Quality Metrics

After the review commit, collect a quality metrics snapshot for trend tracking:
```
Invoke: /blitz:quality-metrics collect
```
This stores a timestamped JSON snapshot in `docs/metrics/` that can be used for trend analysis across sprints. The metrics are informational and do not gate the review.

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
- **Git diff base not found**: Fall back to `HEAD~20` or ask user for the base commit. *(If autonomy is `high` or `full`, use `HEAD~20` without prompting.)*
- **No test runner found**: Skip test gate, mark as "SKIPPED" (not "FAIL") in report.
