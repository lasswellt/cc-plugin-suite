# Research: Loopable Code-Sweep Skill Design

**Date**: 2026-03-26
**Type**: Architecture Decision
**Status**: Complete
**Agents**: 3/3 succeeded (codebase-analyst, web-researcher, library-docs)

---

## Summary

The existing `codebase-audit` skill is a comprehensive 5-pillar, 10-agent read-only analysis that takes 5+ minutes and produces reports but never fixes anything. The `completeness-gate` is a lightweight read-only scanner with 11 check categories. Neither is designed for iterative, loopable cleanup.

We recommend creating a new `code-sweep` skill that combines scanning + fixing in a loop-compatible design, following the **Observe-Diff-Act-Report** reconciliation pattern from `sprint --loop` and the **ratchet pattern** from industry best practices. Each `/loop` tick scans for issues, picks the highest-priority auto-fixable finding, applies the fix, verifies it didn't break anything, commits, and exits -- making incremental progress with every iteration.

---

## Research Questions

### 1. What's the right granularity for a loopable cleanup skill?

**Answer**: Between completeness-gate (read-only, 11 checks, ~30s) and codebase-audit (10 agents, 5 pillars, 5+ min). The code-sweep skill should run **13 check categories** in 3 tiers, completing a full scan + one fix in **< 2 minutes** per loop tick. It uses no sub-agents (unlike codebase-audit's 10) -- just sequential grep/glob scans.

### 2. How should the skill track state between loop iterations?

**Answer**: Use a **JSONL ledger** (`docs/sweeps/sweep-ledger.jsonl`) with one line per finding, keyed by `category + file + line + identifier`. Each entry tracks `status` (found / fixed / wontfix / false-positive), `found_at`, `fixed_at`. Date-stamped snapshots (`docs/sweeps/YYYY-MM-DD.json`) provide aggregate metrics for trend tracking. This follows the ratchet pattern -- counts can only decrease, never increase.

### 3. What scan categories should be included?

**Answer**: 13 categories in 3 tiers:

| Tier | Category | Detection | Auto-Fix | Scan Time |
|------|----------|-----------|----------|-----------|
| **1** | TODO/FIXME comments | `(TODO\|FIXME\|HACK\|XXX)` regex | No (report + age) | <2s |
| **1** | Console.log leftovers | `console\.(log\|debug\|dir\|table)` | Yes (conditional) | <1s |
| **1** | Empty catch blocks | `catch\s*\([^)]*\)\s*\{\s*\}` multiline | Yes (add error logging) | <1s |
| **1** | Placeholder throws | `throw new Error.*not implemented` | No (report) | <2s |
| **1** | Empty function bodies | Opening/closing brace with only whitespace | No (report) | <1s |
| **1** | No-op event handlers | `\(\)\s*=>\s*\{\s*\}` | No (report) | <1s |
| **2** | Unused imports | Import extraction + usage count per file | Yes (high-confidence only) | 5-15s |
| **2** | Commented-out code | Multi-signal heuristic (3+ consecutive // with code tokens) | Yes (delete block) | 3-5s |
| **2** | Stale TODO aging | git blame on TODO lines, bucket by age | No (prioritize report) | 10-50s (cached) |
| **3** | Orphaned files | Knip or full grep import scan | No (report) | 30-60s |
| **3** | Dead exports | Knip or grep export-to-import tracing | No (report) | 30-120s |
| **3** | Unused dependencies | Knip or depcheck | Semi-auto (package.json edit) | 30s |
| **3** | Hardcoded sample data | Array pattern matching in non-test files | No (report) | <2s |

**Tier 1** runs every iteration (~8 seconds total). **Tier 2** runs once per sweep session (cached). **Tier 3** runs as an optional deep scan with knip or full grep analysis.

### 4. How should it handle the scan-vs-fix decision per iteration?

**Answer**: Dual-mode operation with a priority queue:

- **`--scan-only`** (default): Read-only scan, produces report. Safe for CI, idempotent, loop-compatible.
- **`--fix`**: Scan + auto-fix highest-priority fixable issue. Each tick fixes ONE issue, verifies (typecheck + lint), commits if passing, reverts if failing. Circuit breaker: if a fix breaks verification 2x in a row, mark it `needs-human` and move to next.
- **`--fix-all`**: Batch-fix all auto-fixable issues in one category at a time, verifying after each category.

Priority order for fixes:
1. Console.log removals (highest confidence, smallest blast radius)
2. Unused import removals (high confidence with TS verification)
3. Empty catch block fills (add `console.error(err)`)
4. Commented-out code removal (medium confidence, requires 3+ line blocks)

### 5. What does the Observe-Diff-Act-Report pattern look like for code cleanup?

**Answer**: Direct adaptation of sprint --loop's reconciliation:

```
OBSERVE (5s):
  Read docs/sweeps/latest.json (last scan results)
  Read .code-sweep.json (config: scope, enabled checks, fix mode)
  Read git diff since last sweep (changed files only for incremental scan)

DIFF (5s):
  Run Tier 1 scans on changed files (or full scope if first run)
  Compare findings against ledger -- compute delta
  Classify: new findings, regressions, existing, resolved
  Build priority queue: new > regressed > existing

ACT (30-60s):
  If --fix: pick top fixable finding, apply fix, verify
    If verify passes: commit with message "sweep: <category> in <file>"
    If verify fails: revert, mark "needs-human", try next
  If --scan-only: update ledger and snapshot, no file changes

REPORT (5s):
  Print delta summary: "Sweep #3: 42 found (3 fixed, 2 new, 5 resolved) -- down from 47"
  Update docs/sweeps/YYYY-MM-DD.json snapshot
  Update docs/sweeps/sweep-ledger.jsonl
  Exit for next /loop tick
```

### 6. How to integrate with existing skills?

**Answer**:
- **completeness-gate**: code-sweep subsumes its check categories (placeholder returns, TODOs, empty catches, console.log, etc.) but adds fix capability and state tracking. completeness-gate remains useful as a fast gate check; code-sweep is the iterative cleanup companion.
- **quality-metrics**: code-sweep snapshots (`docs/sweeps/YYYY-MM-DD.json`) can be consumed by quality-metrics as an additional metric source (sweep score = 100 - weighted findings).
- **codebase-audit**: Remains the comprehensive read-only audit for architecture, security, performance. code-sweep handles the maintainability/cleanup subset that's automatable.
- **scheduling.md**: Add code-sweep to the loop-compatible skills table. Recommended: `/loop 10m /blitz:code-sweep --fix`.

---

## Findings

### Finding 1: The Ratchet Pattern is the Ideal Model

**Source**: web-researcher (Notion's eslint-seatbelt, SonarQube's "new code")

The ratchet pattern enforces that quality metrics can only improve over time. Each sweep run establishes a baseline; subsequent runs can only decrease violation counts, never increase them. This naturally pairs with `/loop` -- each tick tightens the ratchet by fixing one issue.

**Implementation**: The sweep ledger acts as the ratchet. New findings are tracked. Fixed findings are recorded. If a previously-fixed issue reappears (regression), it gets elevated priority. The snapshot score can only go up over time.

### Finding 2: Knip is the Gold Standard for Deep Analysis but Optional

**Source**: web-researcher + library-docs (convergent)

Knip detects unused files, exports, and dependencies with high accuracy via full dependency graph analysis. It has 100+ framework plugins (Vue, Vite, Vitest, etc.) and JSON output mode. However, it requires `npm install` and runs the TS compiler under the hood.

**Recommendation**: Make knip an optional Tier 3 pre-scan. If `npx knip --reporter json` succeeds, cache its results and use them to enrich findings. If knip isn't available, fall back to grep-based detection (higher false positive rate but no dependency).

### Finding 3: Grep Patterns Provide ~80% of Value Without External Tools

**Source**: library-docs (detailed pattern analysis)

Tier 1 grep patterns (TODO, console.log, empty catch, placeholder throws) have low false-positive rates and scan a 500-file project in under 8 seconds. This covers the most impactful cleanup categories without requiring any npm tools. Tier 2 patterns (unused imports, commented-out code) add coverage but with higher false-positive risk.

### Finding 4: TODO Age Tracking via Git Blame Adds Prioritization

**Source**: library-docs

Running `git blame` on TODO lines reveals their age. TODOs older than 180 days are likely forgotten and should be surfaced first. This adds an actionable prioritization layer that no existing skill provides. Performance: ~0.1-0.5s per blame call, so cache results between iterations. Bucket into red (>180d), yellow (30-180d), green (<30d).

### Finding 5: One Fix Per Tick is the Safe Loop Strategy

**Source**: codebase-analyst (sprint --loop pattern analysis)

Sprint --loop executes exactly one phase per tick then exits. The code-sweep skill should follow the same pattern: fix ONE issue per tick, verify, commit, exit. This minimizes blast radius, ensures each change is independently verifiable, and creates a clean git history where each commit is a single sweep fix.

---

## Compatibility Analysis

### Integration with Plugin Suite

| Aspect | Compatibility | Notes |
|--------|--------------|-------|
| Session protocol | Full | Standard session registration, activity feed, conflict matrix |
| `/loop` | Full | Idempotent scan mode; fix mode follows one-fix-per-tick pattern |
| Conflict matrix | New entries needed | scan vs scan = OK; fix vs sprint-dev = WARN; fix vs fix = BLOCK |
| Scheduling | Compatible | Add to scheduling.md loop-compatible table |
| Quality metrics | Produces snapshots | `docs/sweeps/YYYY-MM-DD.json` consumable by quality-metrics |
| Completeness gate | Complementary | code-sweep adds fix capability + state tracking to similar checks |
| Codebase audit | Complementary | code-sweep handles automatable subset; audit handles deep analysis |

### Model Selection

Use `sonnet` (not opus). The skill runs grep patterns and makes small, formulaic edits. No architectural judgment needed. This keeps cost low for frequent `/loop` invocations.

### Tool Requirements

```
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
```

No agents, no web search, no teams. Lightweight by design.

---

## Recommendation

**Create a new `code-sweep` skill** with the following architecture:

### Skill Identity
- **Name**: `code-sweep`
- **Category**: `quality`
- **Model**: `sonnet`
- **modifies_code**: `true`
- **uses_agents**: `false`
- **Argument hint**: `<scope> | --fix | --scan-only | --fix-all | --loop | --deep | --checks <list>`

### Core Design Principles

1. **Loop-first**: Every invocation is a single tick. Scan, optionally fix ONE thing, report, exit.
2. **Ratchet enforcement**: Findings can only decrease over time. Regressions get elevated priority.
3. **Tiered scanning**: Tier 1 every tick (~8s), Tier 2 once per session (~20s cached), Tier 3 optional deep scan.
4. **Verify-before-commit**: Every auto-fix is verified with typecheck/lint before committing. Failed fixes are reverted.
5. **State persistence**: JSONL ledger for findings, date-stamped JSON snapshots for metrics, config file for project-specific overrides.

### Modes

| Mode | Behavior | Loop-Safe |
|------|----------|-----------|
| `--scan-only` (default) | Read-only scan, update ledger + snapshot | Yes |
| `--fix` | Scan + fix top auto-fixable issue | Yes (one fix per tick) |
| `--fix-all` | Batch fix all auto-fixable by category | No (use manually) |
| `--deep` | Run Tier 3 analysis (knip if available) | Yes (cached) |
| `--loop` | Alias for `--fix` with full autonomy, no prompts | Yes |

### Recommended Loop Usage

```
/loop 10m /blitz:code-sweep --loop
```

Each tick: scan (~8s) -> pick top fix -> apply -> verify -> commit -> report -> exit (~90s total).

Over time: 6 fixes/hour, ~48 fixes per 8-hour day. A codebase with 100 auto-fixable issues would be cleaned up in ~2 days of background looping.

---

## Implementation Sketch

### File Structure

```
skills/code-sweep/
  SKILL.md              # Main skill definition (phases, modes, checks)
  reference.md          # Grep patterns, severity rules, state schemas
```

### State Files (in project)

```
docs/sweeps/
  sweep-ledger.jsonl    # Append-only finding log (one line per finding)
  YYYY-MM-DD.json       # Date-stamped snapshot (aggregate counts + score)
  latest.json           # Copy of most recent snapshot
.code-sweep.json        # Project config (scope, enabled checks, allowlists)
```

### Ledger Entry Schema

```jsonl
{"id":"cs-001","cat":"console-log","file":"src/stores/auth.ts","line":42,"symbol":"console.log(user)","status":"found","found_at":"2026-03-26","severity":"medium","fixable":true}
{"id":"cs-001","cat":"console-log","file":"src/stores/auth.ts","line":42,"symbol":"console.log(user)","status":"fixed","fixed_at":"2026-03-27","fixed_by":"auto","commit":"abc1234"}
```

### Snapshot Schema

```json
{
  "date": "2026-03-26",
  "timestamp": "2026-03-26T12:00:00Z",
  "run_number": 3,
  "mode": "fix",
  "scope": "src/",
  "score": 78,
  "summary": {
    "total": 42,
    "by_status": { "found": 35, "fixed": 5, "wontfix": 1, "false_positive": 1 },
    "by_severity": { "critical": 2, "high": 8, "medium": 22, "low": 10 },
    "by_tier": { "tier1": 28, "tier2": 9, "tier3": 5 },
    "auto_fixable": 15,
    "delta": { "new": 2, "resolved": 5, "regressed": 0 }
  },
  "categories": {
    "todo-fixme": { "count": 12, "oldest_days": 245 },
    "console-log": { "count": 8, "fixable": 8 },
    "empty-catch": { "count": 3, "fixable": 3 },
    "placeholder-throws": { "count": 2, "fixable": 0 },
    "unused-imports": { "count": 6, "fixable": 4 },
    "commented-out-code": { "count": 4, "fixable": 3 },
    "orphaned-files": { "count": 3, "fixable": 0 },
    "dead-exports": { "count": 2, "fixable": 0 },
    "empty-functions": { "count": 1, "fixable": 0 },
    "noop-handlers": { "count": 1, "fixable": 0 }
  }
}
```

### SKILL.md Phase Structure

```
Phase 0: SETUP — Parse args, register session, read config
Phase 1: OBSERVE — Read last snapshot + ledger, detect changed files
Phase 2: SCAN — Run enabled check tiers, build findings list
Phase 3: DIFF — Compare against ledger, compute delta, build priority queue
Phase 4: ACT — If fix mode: pick top fixable, apply, verify, commit (or revert)
Phase 5: REPORT — Update ledger + snapshot, print delta summary, exit
```

### Config File Schema (`.code-sweep.json`)

```json
{
  "scope": ["src/", "functions/"],
  "exclude": ["**/generated/**", "**/vendor/**"],
  "checks": {
    "todo-fixme": { "enabled": true, "auto_fix": false },
    "console-log": { "enabled": true, "auto_fix": true, "exclude_files": ["**/logger.*"] },
    "empty-catch": { "enabled": true, "auto_fix": true },
    "unused-imports": { "enabled": true, "auto_fix": true },
    "commented-out-code": { "enabled": true, "auto_fix": true, "min_lines": 3 },
    "orphaned-files": { "enabled": true, "auto_fix": false },
    "dead-exports": { "enabled": true, "auto_fix": false }
  },
  "knip": { "enabled": true, "cache_ttl_hours": 24 },
  "verify_command": "npx tsc --noEmit && npx eslint . --quiet",
  "max_fixes_per_tick": 1,
  "todo_age_threshold_days": 180
}
```

### Conflict Matrix Additions

```
| code-sweep (scan) | code-sweep (scan) | OK — read-only |
| code-sweep (fix)  | code-sweep (fix)  | BLOCK — concurrent edits |
| code-sweep (fix)  | sprint-dev        | WARN — both modify source |
| code-sweep (fix)  | refactor          | BLOCK — both modify source |
| code-sweep (scan) | sprint-dev        | OK — read-only scan |
```

### Scheduling.md Addition

```
| `code-sweep` | 10m | `--loop` | Iterative code cleanup with auto-fix |
| `code-sweep` | Daily | `--scan-only --deep` | Full scan with Tier 3 analysis |
```

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Auto-fix breaks code | High | Verify with typecheck+lint after every fix. Revert on failure. Circuit breaker after 2 consecutive failures. |
| False positives in grep patterns | Medium | Conservative patterns with known exclusions. `.code-sweep.json` allowlists. `wontfix` status in ledger. |
| Knip not available | Low | Graceful fallback to grep-only Tier 1+2 (~80% of value). |
| Loop tick exceeds time budget | Medium | Tier 1 only for default scans. Tier 3 behind `--deep` flag. Target <90s per tick. |
| Conflicts with sprint-dev | Medium | Conflict matrix entry: WARN for fix mode. Scan mode is always safe. |
| Ledger grows unbounded | Low | Prune entries older than 90 days or with `fixed` status older than 30 days. |
| Git blame slow for TODO aging | Low | Cache blame results in session temp dir. Only re-run on changed files. |

---

## References

- **Notion's eslint-seatbelt ratchet pattern**: https://www.notion.com/blog/how-we-evolved-our-code-notions-ratcheting-system-using-custom-eslint-rules
- **Knip (dead code detection)**: https://knip.dev/
- **SonarQube "Clean as You Code"**: https://docs.sonarsource.com/sonarqube/latest/user-guide/clean-as-you-code/
- **Martin Fowler on codemods**: https://martinfowler.com/articles/codemods-api-refactoring.html
- **Existing blitz skills**: `skills/codebase-audit/SKILL.md`, `skills/completeness-gate/SKILL.md`, `skills/quality-metrics/SKILL.md`, `skills/sprint/SKILL.md` (loop reconciliation pattern)
