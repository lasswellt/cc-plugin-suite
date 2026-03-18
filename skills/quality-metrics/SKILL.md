---
name: quality-metrics
description: "Collects, stores, and visualizes code quality metrics over time. Supports collect, dashboard, trend, and compare modes."
allowed-tools: Read, Write, Bash, Glob, Grep
model: sonnet
argument-hint: "<mode: collect|dashboard|trend|compare <date1> <date2>>"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For metric snapshot schema, dashboard templates, trend thresholds, and score calculation details, see:
!cat skills/quality-metrics/reference.md

---

# Continuous Quality Metrics

Collect code quality signals, store snapshots over time, and produce dashboards with trend analysis. Execute every phase in order. Do NOT skip phases.

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

### 0.1 Parse Mode

Extract mode from `$ARGUMENTS`. Default to `collect` if not specified.

| Mode | Description | Requirements |
|------|-------------|--------------|
| `collect` | Gather all metrics and store snapshot | None |
| `dashboard` | Generate markdown dashboard from latest snapshot | At least 1 snapshot |
| `trend` | Analyze metrics over time | At least 2 snapshots |
| `compare <date1> <date2>` | Side-by-side comparison of two snapshots | Both dates must have snapshots |

---

## Phase 1: COLLECT — Gather Metrics

Run each metric collector. If a tool is not available or the command fails, set that metric's score to `null` and continue with the remaining collectors.

### 1.1 TypeScript Strictness

```bash
npx tsc --noEmit 2>&1 | tail -5
```

Extract the error count from compiler output. Score calculation:
- 0 errors: score = 100
- N errors: score = max(0, 100 - N * 2)

### 1.2 Lint Score

```bash
npx eslint . --format json 2>&1
```

Extract error and warning counts from JSON output. Score calculation:
- score = max(0, 100 - errors * 5 - warnings * 1)

### 1.3 Test Results

```bash
npx vitest run --reporter=json 2>&1
```

If Vitest is not available, try the Jest equivalent:
```bash
npx jest --json 2>&1
```

Extract: total, passed, failed, skipped. Score calculation:
- score = (passed / total) * 100
- If total = 0, score = null

### 1.4 Build Status

```bash
npm run build 2>&1
```

Score:
- Exit code 0: score = 100
- Exit code non-zero: score = 0

### 1.5 Completeness Score

Check if the completeness-gate skill has been run recently:
```bash
ls -t docs/metrics/*.json 2>/dev/null | head -1
```

If a recent snapshot exists and contains a `completeness` field, use that score. Otherwise, set score = null.

### 1.6 Codebase Size

Count source files, lines, test files, and test lines:

```bash
# Source files and lines
find src/ -name '*.ts' -o -name '*.vue' | grep -v '.test.' | grep -v '.spec.' | wc -l
find src/ -name '*.ts' -o -name '*.vue' | grep -v '.test.' | grep -v '.spec.' | xargs cat 2>/dev/null | wc -l

# Test files and lines
find src/ -name '*.test.*' -o -name '*.spec.*' | wc -l
find src/ -name '*.test.*' -o -name '*.spec.*' | xargs cat 2>/dev/null | wc -l
```

Calculate test-to-code ratio = test_lines / source_lines.

### 1.7 Dependency Count

Read `package.json` and count:
- Production dependencies: keys in `dependencies`
- Dev dependencies: keys in `devDependencies`

---

## Phase 2: STORE — Save Snapshot

### 2.1 Create Metrics Directory

```bash
mkdir -p docs/metrics
```

### 2.2 Write Snapshot

Write to `docs/metrics/YYYY-MM-DD.json` using today's date:

```json
{
  "date": "YYYY-MM-DD",
  "timestamp": "<ISO-8601>",
  "scores": {
    "typescript": null,
    "lint": null,
    "tests": null,
    "build": null,
    "completeness": null
  },
  "details": {
    "typescript": { "errors": 0 },
    "lint": { "errors": 0, "warnings": 0 },
    "tests": { "total": 0, "passed": 0, "failed": 0, "skipped": 0 },
    "build": { "success": true },
    "codebase": {
      "source_files": 0,
      "source_lines": 0,
      "test_files": 0,
      "test_lines": 0,
      "test_ratio": 0.0
    },
    "dependencies": { "production": 0, "dev": 0 }
  },
  "overall_score": null
}
```

**Overall score** = average of all non-null scores. If all scores are null, overall_score = null.

### 2.3 Verify Snapshot

Re-read the written file and validate it parses as valid JSON:
```bash
python3 -m json.tool docs/metrics/YYYY-MM-DD.json > /dev/null 2>&1 && echo "VALID" || echo "INVALID"
```

---

## Phase 3: DASHBOARD — Generate Report

**Trigger:** Run this phase if mode is `dashboard` or `collect`.

### 3.1 Load Latest Snapshot

Read the most recent `docs/metrics/*.json` by sorting filenames lexicographically (they are date-based):

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort | tail -1
```

### 3.2 Load Previous Snapshot (if available)

If more than one snapshot exists, load the second-most-recent to compute deltas:

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort | tail -2 | head -1
```

### 3.3 Generate Dashboard

Write `docs/metrics/dashboard.md` with the following structure:

```markdown
# Quality Dashboard

**Date**: YYYY-MM-DD
**Overall Score**: XX/100

## Scorecard

| Metric | Score | Status | Delta |
|--------|-------|--------|-------|
| TypeScript | XX | PASS/WARN/FAIL | +N/-N/= |
| Lint | XX | PASS/WARN/FAIL | +N/-N/= |
| Tests | XX | PASS/WARN/FAIL | +N/-N/= |
| Build | XX | PASS/WARN/FAIL | +N/-N/= |
| Completeness | XX | PASS/WARN/FAIL | +N/-N/= |

## Status Key

- PASS: score >= 80
- WARN: score >= 50 and < 80
- FAIL: score < 50

## Details

### TypeScript
- Errors: N

### Lint
- Errors: N
- Warnings: N

### Tests
- Total: N | Passed: N | Failed: N | Skipped: N

### Build
- Status: Success/Failure

### Codebase
- Source files: N (N lines)
- Test files: N (N lines)
- Test-to-code ratio: X.XX

### Dependencies
- Production: N
- Dev: N
```

**Status thresholds:**
- PASS: score >= 80
- WARN: score >= 50 and < 80
- FAIL: score < 50
- N/A: score is null

**Delta column:**
- If previous snapshot exists, show the numeric difference (e.g., +5, -3, =)
- If no previous snapshot, show "—"

---

## Phase 4: TREND — Analyze Over Time

**Trigger:** Run this phase if mode is `trend` or `compare`.

### 4.1 Load All Snapshots

Read all `docs/metrics/*.json` files, sorted by date ascending:

```bash
ls -1 docs/metrics/*.json 2>/dev/null | sort
```

Parse each file and collect into a time series.

### 4.2 Validate Snapshot Count

- For `trend` mode: require at least 2 snapshots. If fewer, report "Insufficient data — need at least 2 snapshots for trend analysis."
- For `compare` mode: require snapshots matching both requested dates. If an exact match is not found, use the nearest available date and note the substitution.

### 4.3 Analyze Trends

For each metric, compare the last 3 snapshots (or all available if fewer than 3):

| Direction | Condition |
|-----------|-----------|
| Improving | Latest score > average of prior scores |
| Declining | Latest score < average of prior scores by > 5 points |
| Stable | Change is within 5 points |

Calculate velocity = (latest - earliest) / number_of_intervals.

### 4.4 Detect Alerts

Flag any metric where:
- Score declined by more than 10 points between any two consecutive snapshots
- Score is below 50 (FAIL threshold)
- Score was previously PASS (>= 80) and is now WARN (< 80)

### 4.5 Write Trend Report

Write `docs/metrics/trend-report.md`:

```markdown
# Quality Trend Report

**Period**: YYYY-MM-DD to YYYY-MM-DD
**Snapshots**: N

## Trend Summary

| Metric | Current | Direction | Velocity | Alert |
|--------|---------|-----------|----------|-------|
| TypeScript | XX | Improving/Declining/Stable | +X.X/snapshot | — or ALERT |
| Lint | XX | ... | ... | ... |
| Tests | XX | ... | ... | ... |
| Build | XX | ... | ... | ... |
| Completeness | XX | ... | ... | ... |
| Overall | XX | ... | ... | ... |

## Alerts

- [ALERT] <metric> declined by N points between YYYY-MM-DD and YYYY-MM-DD
- ...

## Recommendations

- <Prioritized suggestions based on trends>
```

### 4.6 Compare Mode Output

If mode is `compare <date1> <date2>`, write a side-by-side comparison:

```markdown
# Quality Comparison: YYYY-MM-DD vs YYYY-MM-DD

| Metric | Date 1 | Date 2 | Delta | Direction |
|--------|--------|--------|-------|-----------|
| TypeScript | XX | XX | +/-N | Improved/Declined/Same |
| ... | ... | ... | ... | ... |
| Overall | XX | XX | +/-N | Improved/Declined/Same |

## Notable Changes
- <List of metrics with significant movement>
```

---

## Phase 5: REPORT — Present to User

Print a summary to the user based on the mode that was run:

### 5.1 Collect Summary

```
Quality Metrics Collected
=========================
Date: YYYY-MM-DD
Overall Score: XX/100

  TypeScript:   XX/100  PASS/WARN/FAIL
  Lint:         XX/100  PASS/WARN/FAIL
  Tests:        XX/100  PASS/WARN/FAIL
  Build:        XX/100  PASS/WARN/FAIL
  Completeness: XX/100  PASS/WARN/FAIL

Snapshot: docs/metrics/YYYY-MM-DD.json
Dashboard: docs/metrics/dashboard.md
```

### 5.2 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`.
2. Append `session_end` to the operation log.
3. Optionally remove session temp directory if no artifacts need preservation.

---

## Safety Rules

- **Read-only on source code.** This skill only reads source files; it never modifies application code.
- **Non-destructive metrics.** Commands like `tsc --noEmit` and `eslint` are read-only analysis. The `npm run build` command may produce build artifacts; this is expected.
- **Snapshot immutability.** Never overwrite an existing snapshot file. If `docs/metrics/YYYY-MM-DD.json` already exists, append a counter suffix (e.g., `YYYY-MM-DD-2.json`).
- **No credential exposure.** Do not log or store environment variable values, API keys, or tokens in snapshots.

---

## Error Recovery

- **Metric command fails**: Set that metric's score to `null`, record the error in `details`, and continue with the remaining collectors.
- **No previous snapshots for trend mode**: Report "Insufficient data — need at least 2 snapshots. Run `collect` mode first."
- **docs/metrics/ directory missing**: Create it automatically in Phase 2.
- **Compare dates do not match any snapshot**: Find the nearest available date for each requested date. Note the substitution in the comparison output.
- **JSON parse failure on existing snapshot**: Skip the malformed file and note it in the trend report. Do not delete or overwrite it.
- **No test runner detected**: Set tests score to `null`. Note "No test runner found (checked Vitest, Jest)."
- **No TypeScript configured**: Set typescript score to `null`. Note "No tsconfig.json found."
- **Build script missing**: Set build score to `null`. Note "No `build` script in package.json."
