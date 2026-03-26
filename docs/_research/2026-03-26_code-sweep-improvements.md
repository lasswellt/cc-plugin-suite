# Research: Code-Sweep Improvements — Beyond Cleanup to Code Improvement

**Date**: 2026-03-26
**Type**: Architecture Decision
**Status**: Complete
**Agents**: 3/3 succeeded (codebase-analyst, web-researcher, library-docs)

---

## Summary

The current code-sweep skill has 13 checks that all fall into 3 narrow buckets: cleanup, placeholder detection, and dead code. It has **zero** checks for optimization, convention alignment, security, correctness enforcement, or code reduction. Research across the existing codebase-audit checklists, industry tools (Semgrep, SonarQube, Biome), and academic studies identifies **13 high-value new checks** that expand code-sweep into 6 categories. The research-backed ordering is: conventions first (74% reduction), then correctness (44%), then security (32%). Seven of the new patterns are auto-fixable with verification, and all fit within the <2 minute loop tick budget.

---

## Research Questions

### 1. What code improvement categories should be added beyond cleanup?

**Answer**: Five new categories, each mapped from the existing codebase-audit pillars:

| New Category | Maps To (Audit Pillar) | Checks Added |
|-------------|----------------------|--------------|
| **Correctness** | Robustness + Maintainability | `placeholder-returns`, `log-and-return`, `loose-equality`, `skipped-test` |
| **Optimization** | Performance | `return-await`, `sequential-await`, `optional-chaining`, `n-plus-one` |
| **Convention** | Architecture + Maintainability | `typescript-any`, `file-length`, `naming-consistency` |
| **Security** | Security | `hardcoded-secret`, `v-html-xss` |
| **Reduction** | Maintainability | `redundant-else`, `immediate-return-var`, `nullish-coalescing` |

Plus 2 Vue-specific checks: `missing-v-for-key`, `three-state-ui`.

### 2. Which improvements are safe to auto-fix in a loop tick vs. report-only?

**Answer**: Using Biome's model (safe = semantics-preserving, unsafe = may change semantics):

**Auto-fixable (safe):**
| Pattern | Fix | Risk |
|---------|-----|------|
| `loose-equality` | `==` -> `===` (exclude `== null`) | Low |
| `return-await` | Remove `await` (outside try blocks) | Low |
| `optional-chaining` | `x && x.y` -> `x?.y` (reads only) | Low |
| `redundant-else` | Remove else wrapper after return/throw | Low |
| `immediate-return-var` | Inline variable into return | Low |
| `skipped-test` | Remove `.skip` from test calls | Low |
| `nullish-coalescing` | `x != null ? x : d` -> `x ?? d` | Low |

**Semi-auto (needs typecheck verification):**
| Pattern | Fix | Risk |
|---------|-----|------|
| `typescript-any` | `: any` -> `: unknown` | Medium — may need type guards |

**Report-only (needs human judgment):**
All convention detection, security findings, Vue patterns, sequential-await, n-plus-one, placeholder-returns, file-length, naming-consistency, hardcoded-secret, v-html-xss.

### 3. How can the skill detect pattern inconsistencies and align code to project conventions?

**Answer**: Three approaches ranked by feasibility:

1. **Mechanical enforcement** (grep/glob): File naming consistency (detect mixed kebab/camel/pascal per directory), import ordering (detect external-after-internal), mixed error handling patterns (throw vs console.error vs return-error in same file types), mixed async patterns (`.then()` alongside `await` in same file).

2. **Convention inference**: Count dominant patterns per directory/file-type and flag outliers. E.g., if 90% of files use `kebab-case.ts`, flag the 10% that use `camelCase.ts`. This leverages the NATURALIZE principle — infer local conventions from the codebase itself.

3. **LLM-assisted** (future): Semantic naming quality, architectural pattern consistency. Not suitable for grep-level detection.

For the current skill, approach 1 is immediately implementable. Approach 2 can be added as a Tier 2 check.

### 4. What correctness checks can be done at grep/read level without running the code?

**Answer**: Five high-value patterns:

| Check | Pattern | Confidence |
|-------|---------|-----------|
| `loose-equality` | `[^!=]==[^=]` | High — almost always a bug in TS |
| `placeholder-returns` | `return\s*\{\s*\}` / `return\s*\[\s*\]` | High — proven in completeness-gate |
| `log-and-return` | Function body = only console.* + return | High — proven pattern |
| `skipped-test` | `it\.skip\|xit\|describe\.skip` | Very high — never intentional in CI |
| `typescript-any` | `:\s*any\b` / `as\s+any` | High — enforces DoD rule |

Lower-confidence patterns that need AST: non-null assertions (`!`), unhandled promises, missing null checks. These are better left to `tsc --strict`.

### 5. How should the skill prioritize improvements vs. cleanups in the fix queue?

**Answer**: Research-backed ordering (from "Static Analysis as Feedback Loop", Aug 2025):

```
Priority 1: Convention enforcement (74% issue reduction, lowest risk)
Priority 2: Code reduction/simplification (high confidence auto-fixes)
Priority 3: Correctness enforcement (44% reduction, moderate risk)
Priority 4: Optimization (needs careful verification)
Priority 5: Security hardening (32% reduction, needs human review)
Priority 6: Cleanup (existing checks — already working)
```

Within each priority level, auto-fixable issues rank above report-only.

### 6. What from the codebase-audit could be adapted as automatable improvements?

**Answer**: 13 checks extracted from the 5-pillar checklists:

- **Architecture**: circular-import detection (Tier 3, report-only)
- **Performance**: sequential-await, n-plus-one, return-await (Tier 1-2)
- **Security**: hardcoded-secret, v-html-xss (Tier 1)
- **Maintainability**: typescript-any, file-length, nesting-depth (Tier 1-2)
- **Robustness**: three-state-ui, skipped-test (Tier 1-2)

Plus 4 checks from completeness-gate not yet in code-sweep: `placeholder-returns`, `log-and-return`, `three-state-ui`, `unwired-store-actions`.

---

## Findings

### Finding 1: The Definition-of-Done Enforcement Gap

**Source**: codebase-analyst

The project's `definition-of-done.md` has 6 rules enforceable by automated scanning, but code-sweep currently enforces only 2 (console.log, commented-code). The missing 4 are:

| DoD Rule | Proposed Check | Detection |
|----------|---------------|-----------|
| No `any` types | `typescript-any` | `:\s*any\b` / `as\s+any` |
| No hardcoded secrets/keys/URLs | `hardcoded-secret` | API key/password/token patterns |
| No `it.skip`/`xit`/`describe.skip` | `skipped-test` | Direct grep |
| No placeholder returns | `placeholder-returns` | `return\s*\{\s*\}` |

Adding these makes code-sweep the "DoD enforcement engine."

### Finding 2: Seven New Auto-Fixable Patterns

**Source**: library-docs (concrete patterns) + web-researcher (safety validation)

Beyond the existing 4 auto-fixable checks (console-log, empty-catch, unused-import, commented-code), 7 new patterns are safe to auto-fix:

1. **Loose equality** → strict equality (exclude `== null`)
2. **Return await** → remove await (outside try blocks)
3. **Missing optional chaining** → `x?.y` (reads only)
4. **Nullish coalescing** → `x ?? default`
5. **Redundant else** → remove else after return/throw
6. **Immediate return variable** → inline into return
7. **Skipped tests** → remove `.skip`

This brings auto-fixable checks from 4 to 11, significantly increasing the value per loop tick.

### Finding 3: Research-Backed Iteration Ordering

**Source**: web-researcher (academic studies)

The "Static Analysis as Feedback Loop" study (Aug 2025) using GPT-4o + static analysis found:
- Conventions: 74% issue reduction (fastest, safest)
- Correctness: 44% reduction
- Security: 32% reduction
- Functionality: only 7% (needs tests, not static analysis)
- Diminishing returns after ~10 iterations
- Multi-issue batching outperforms single-issue-per-iteration

**Implication**: The fix priority queue should process convention fixes before correctness fixes before security reports.

### Finding 4: Completeness-Gate Checks Should Be Ported

**Source**: codebase-analyst

Four completeness-gate checks have proven grep patterns and severity rules but are NOT in code-sweep:
- `placeholder-returns` — `return {}` / `return []`
- `log-and-return` — functions that only log + return
- `three-state-ui` — Vue components missing loading/error states
- `unwired-store-actions` — store actions without API calls

These are battle-tested patterns that can be directly ported.

### Finding 5: Vue-Specific Improvement Patterns

**Source**: library-docs

Four Vue-specific patterns add significant value for Vue/Nuxt projects:
- Missing `:key` in `v-for` (rendering bug)
- Reactive destructuring (loses reactivity)
- Options API vs Composition API detection (migration candidates)
- `ref()` wrapping large objects (performance)

Of these, `missing-v-for-key` is the highest value — it's a common bug with low false-positive risk.

---

## Recommendation

**Expand code-sweep from 13 to 26 checks across 6 categories.** Add 13 new checks organized into the existing tier system, with 7 new auto-fixable patterns. Restructure the fix priority queue to follow the research-backed ordering: conventions → reduction → correctness → optimization → security → cleanup.

### New Check Roster

#### Tier 1 Additions (fast, every tick)

| # | Check ID | Category | Fixable | Time |
|---|----------|----------|---------|------|
| 14 | `placeholder-returns` | Correctness | No | ~3s |
| 15 | `hardcoded-secret` | Security | No | ~5s |
| 16 | `typescript-any` | Convention | Semi | ~2s |
| 17 | `skipped-test` | Correctness | Yes | ~2s |
| 18 | `loose-equality` | Correctness | Yes | ~1s |
| 19 | `return-await` | Optimization | Yes | ~1s |
| 20 | `optional-chaining` | Reduction | Yes | ~2s |
| 21 | `redundant-else` | Reduction | Yes | ~2s |
| 22 | `nullish-coalescing` | Reduction | Yes | ~2s |
| 23 | `immediate-return-var` | Reduction | Yes | ~2s |

#### Tier 2 Additions (once per session)

| # | Check ID | Category | Fixable | Time |
|---|----------|----------|---------|------|
| 24 | `log-and-return` | Correctness | No | ~15s |
| 25 | `three-state-ui` | Robustness | No | ~15s |
| 26 | `file-length` | Convention | No | ~3s |
| 27 | `missing-v-for-key` | Correctness (Vue) | No | ~2s |

#### Tier 3 Additions (deep only)

| # | Check ID | Category | Fixable | Time |
|---|----------|----------|---------|------|
| 28 | `unwired-store-actions` | Correctness | No | ~20s |
| 29 | `sequential-await` | Optimization | No | ~10s |
| 30 | `n-plus-one` | Optimization | No | ~10s |
| 31 | `v-html-xss` | Security | No | ~5s |
| 32 | `nesting-depth` | Convention | No | ~15s |

### Updated Fix Priority Queue

```
1. Convention fixes (typescript-any semi-auto, file naming report)
2. Reduction fixes (redundant-else, immediate-return-var, optional-chaining, nullish-coalescing)
3. Correctness fixes (loose-equality, skipped-test, placeholder-returns report)
4. Optimization fixes (return-await)
5. Security reports (hardcoded-secret, v-html-xss)
6. Cleanup fixes (existing: console-log, empty-catch, unused-import, commented-code)
```

### Updated Category Taxonomy

| Category | Focus | Total Checks | Auto-fixable |
|----------|-------|-------------|-------------|
| **Cleanup** | Dead code, debug leftovers | 8 | 4 |
| **Correctness** | Code does what it claims | 8 | 2 |
| **Reduction** | Simplify, reduce verbosity | 4 | 4 |
| **Optimization** | Performance patterns | 3 | 1 |
| **Convention** | Project standards alignment | 3 | 0 (1 semi) |
| **Security** | Risky patterns | 2 | 0 |
| **Robustness** | UI resilience | 2 | 0 |
| **Total** | | **30** | **11 + 1 semi** |

---

## Implementation Sketch

### Changes to SKILL.md

1. **Add 17 new check definitions** in Phase 2 (SCAN), organized under the existing tier structure
2. **Add category field** to each check (cleanup / correctness / reduction / optimization / convention / security / robustness)
3. **Update Phase 3 (DIFF) priority queue** to follow the research-backed ordering
4. **Add 7 new auto-fix strategies** in Phase 4 (ACT)
5. **Update Phase 5 (REPORT)** to show findings by category, not just by severity
6. **Add `--category <list>` flag** to run only specific categories

### Changes to reference.md

1. **Add grep patterns** for all 17 new checks (concrete patterns documented by library-docs)
2. **Add auto-fix strategies** for 7 new fixable patterns (before/after transformations)
3. **Add severity rules** for new categories
4. **Update snapshot schema** to include category breakdown
5. **Add `.code-sweep.json` entries** for new checks with enable/disable/auto-fix per check

### Changes to state schemas

**Snapshot** — add category breakdown:
```json
"by_category": {
  "cleanup": 12,
  "correctness": 8,
  "reduction": 4,
  "optimization": 2,
  "convention": 3,
  "security": 1,
  "robustness": 2
}
```

**Ledger** — add `category` field to each entry.

**Config** — add new check entries with defaults:
```json
"loose-equality": { "enabled": true, "auto_fix": true },
"return-await": { "enabled": true, "auto_fix": true },
"optional-chaining": { "enabled": true, "auto_fix": true },
"redundant-else": { "enabled": true, "auto_fix": true },
"nullish-coalescing": { "enabled": true, "auto_fix": true },
"immediate-return-var": { "enabled": true, "auto_fix": true },
"skipped-test": { "enabled": true, "auto_fix": true },
"typescript-any": { "enabled": true, "auto_fix": false },
"placeholder-returns": { "enabled": true, "auto_fix": false },
"hardcoded-secret": { "enabled": true, "auto_fix": false },
"file-length": { "enabled": true, "auto_fix": false, "max_lines": 300 },
"log-and-return": { "enabled": true, "auto_fix": false },
"three-state-ui": { "enabled": true, "auto_fix": false },
"missing-v-for-key": { "enabled": true, "auto_fix": false },
"unwired-store-actions": { "enabled": true, "auto_fix": false },
"sequential-await": { "enabled": true, "auto_fix": false },
"n-plus-one": { "enabled": true, "auto_fix": false },
"v-html-xss": { "enabled": true, "auto_fix": false },
"nesting-depth": { "enabled": true, "auto_fix": false, "max_depth": 4 }
```

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Auto-fix changes semantics | High | Only fix patterns validated as "safe" by Biome's model. Always verify with typecheck. Revert on failure. |
| `optional-chaining` auto-fix introduces null/undefined distinction bug | Medium | Only apply to property reads, not method calls. Exclude patterns where falsy values (0, '') matter. |
| `loose-equality` fix breaks `== null` intentional patterns | Medium | Explicitly exclude `== null` and `== undefined` from auto-fix. |
| `return-await` fix inside try block removes error catching | Medium | Only fix outside try blocks. Detect try context before applying. |
| `hardcoded-secret` false positives | Low | Use high-confidence patterns only: `AIza` prefix, `sk-` prefix, `password\s*[:=]\s*['"]`, base64 tokens > 20 chars. |
| Too many findings overwhelm user | Medium | Category-based filtering with `--category` flag. Show top 10 by default. |
| Scan time exceeds loop budget with all 30 checks | Medium | Tier system ensures only Tier 1 runs every tick (~25s for all new T1). Tier 2/3 are optional. |

---

## References

- **"Static Analysis as Feedback Loop"** (Aug 2025) — Research-backed iteration ordering
- **Biome safe/unsafe fix model** — https://biomejs.dev/
- **Notion's eslint-seatbelt ratchet** — https://www.notion.com/blog/how-we-evolved-our-code-notions-ratcheting-system-using-custom-eslint-rules
- **NATURALIZE convention inference** (Microsoft Research)
- **SonarQube rule catalog** — 6,500+ rules across 35+ languages
- **Semgrep** — https://semgrep.dev/
- **Existing blitz skills**: `skills/codebase-audit/reference.md`, `skills/completeness-gate/reference.md`, `skills/_shared/definition-of-done.md`
