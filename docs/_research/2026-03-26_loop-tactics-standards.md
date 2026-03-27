# Research: Loop Tactics for Standards-Driven Codebase Improvement

**Date**: 2026-03-26
**Type**: Architecture Decision
**Status**: Complete
**Agents**: 3/3 succeeded (codebase-analyst, web-researcher, library-docs)

---

## Summary

The current code-sweep skill has 30 static checks but no ability to discover what the codebase actually does, define that as a standard, or progressively align outliers. Research across industry patterns (Notion's eslint-seatbelt, Stripe's Sorbet, Google's Rosie), the existing skill architecture, and concrete algorithm design converges on a three-part extension: (1) a **convention discovery** phase that samples the codebase, counts pattern frequencies, and auto-proposes standards at a 70% adoption threshold; (2) a **file queue** that partitions large codebases into 30-file batches across loop ticks with priority scoring; and (3) a **ratchet mechanism** that enforces monotonic improvement — violation budgets can only decrease, never increase.

---

## Research Questions

### 1. How should code-sweep discover existing conventions?

**Answer**: The **Propose-Count-Decide** pattern. For each convention dimension (file naming, import ordering, error handling, async patterns, component style, export style, indentation, quote style):
1. Sample files using stratified sampling (40% recently modified, 30% most-imported, 20% random, 10% hotspots)
2. Extract the pattern each file uses
3. Count frequencies and classify: >70% adoption = auto-enforce, 30-70% = flag for human review, <30% = the codebase has a *different* convention — learn that instead

This follows ESLint's community practice and Prettier's "detect then standardize" philosophy. The key insight: **never propose a standard the codebase disagrees with.** Search first.

### 2. What's the right loop lifecycle?

**Answer**: **Tick type rotation** with a state-based decision tree:

```
Run 1:    DISCOVERY — Full convention scan + baseline (all files)
Run 2:    SCAN — Process next 30-file batch from queue
Run 3:    FIX — Fix top auto-fixable finding
Run 4:    SCAN — Next batch
Run 5:    FIX — Next fix
...
Run N*10: RE-DISCOVER — Re-validate conventions (they shift as code changes)
```

Decision logic: after discovery → scan; after scan → fix (if fixable findings exist) or scan (if nothing fixable); after fix → scan. Re-discover every 10th run or when config changes.

### 3. How to partition a large codebase across loop ticks?

**Answer**: **Persistent file queue** (`docs/sweeps/file-queue.json`) with priority scoring:

- **30 files per tick** (configurable) — fits within 90-second scan budget
- **Priority scoring** using 4 weighted factors: recently-modified (4x), most-imported/in-degree (3x), hotspot/findings-density (2x), alphabetical tiebreaker (1x)
- **Resume-safe**: checkpoint tracks last processed index; interrupted ticks re-scan their batch
- **Queue lifecycle**: initialized on first run, updated per tick, re-prioritized when exhausted

Partition strategies ranked by research: hotspot-first (highest ROI) > most-imported-first (ripple effect) > leaf-files-first (safest) > recently-modified (natural spread).

### 4. What's the "search first" pattern?

**Answer**: The **verify-before-enforce** workflow from Biome and ESLint:

```
PROPOSE → EVALUATE → ENFORCE → ALIGN → COMPLETE
```

- **PROPOSE**: Discovery algorithm finds a pattern with >30% adoption
- **EVALUATE**: Scan ALL files, compute adoption rate
  - >=70%: auto-enforce
  - 30-70%: needs human review (`--approve-standard <id>`)
  - <30%: no consensus, skip
- **ENFORCE**: Add to active standards, create ratchet entry, add violating files to queue
- **ALIGN**: Each fix tick resolves one violation; ratchet budget decreases monotonically
- **COMPLETE**: 100% compliance reached; standard prevents regression

The anti-pattern to avoid: enabling a rule without counting first. Always measure adoption before enforcing.

### 5. How should standards be stored?

**Answer**: Separate file `.code-sweep-standards.json` at project root (committed, versioned, reviewable). Contains:
- Discovered conventions with confidence scores and evidence
- Standard lifecycle states (proposed → enforced → aligned → complete)
- History tracking for trend analysis
- Pending-review queue for human decisions

This follows the config-as-code principle: config defines the *target*, the ratchet file tracks *current reality*, and the gap between them IS the work queue.

### 6. How do progressive alignment strategies work at scale?

**Answer**: Three proven patterns from industry:

1. **Notion's ratchet** (eslint-seatbelt): TSV file tracking (file, rule, violation_count). Budgets can only decrease. Pre-commit hooks auto-lower budget when fixes land. This IS the migration plan.

2. **Stripe's Sorbet** (file-level opt-in): Each file declares its compliance level. Different teams adopt at different rates. Centralized tooling + social enforcement (code review catches regressions).

3. **Google's Rosie** (ownership-based sharding): Partition changes by OWNERS boundaries. Cap outstanding shards. Auto-escalate unresponsive reviewers. Test intersection optimization.

For code-sweep, the **ratchet + file queue** combination gives us: visibility (metrics show progress), irreversibility (budgets only decrease), and tractability (30 files/tick = predictable velocity).

---

## Findings

### Finding 1: The 70% Threshold is Industry Standard

**Source**: All 3 agents converge

ESLint community practice, Biome's rule adoption metrics, and the library-docs algorithm all settle on 70% as the auto-enforcement threshold. Below 70% but above 30% requires human judgment. Below 30% means the proposed pattern is actually the minority — the codebase has a different convention. This prevents the tool from fighting the codebase.

### Finding 2: Ratchet Pattern is the Core Mechanism

**Source**: web-researcher (Notion, imbue-ai/ratchets) + library-docs (concrete schema)

The ratchet file is the single most important addition. It transforms a one-time scan into a sustained improvement engine:
- Initial scan creates the budget (violation count per standard)
- Each fix tick decreases the budget
- New violations that exceed the budget are flagged as regressions
- The ratchet file IS the migration plan — it shows exactly what's left to do

Tools: eslint-seatbelt, imbue-ai/ratchets, eslint-formatter-ratchet.

### Finding 3: Batch-Based Scanning Solves the Large Codebase Problem

**Source**: codebase-analyst (architecture gap) + library-docs (queue design)

The current code-sweep scans ALL files every tick (Tier 1). For 500+ file codebases, this doesn't scale for standards enforcement. The file queue with 30 files/tick batching solves this:
- First run: full scan, initialize queue sorted by priority
- Each subsequent tick: pop next batch, scan, fix one item
- Changed files (git diff) always get scanned regardless of queue position
- Queue wraps around and re-prioritizes when exhausted

### Finding 4: Stratified Sampling Produces Better Discovery

**Source**: library-docs (algorithm design)

Pure random sampling misses high-value files. Stratified sampling (40% recently modified, 30% most-imported, 20% random, 10% hotspots) captures both "active convention" (what developers write today) and "core convention" (what shapes the project). Cap at 200 files for codebases larger than that.

### Finding 5: Eight Convention Dimensions Cover Most Standards

**Source**: library-docs + codebase-analyst

| Dimension | Patterns to Detect | Detection Method |
|-----------|-------------------|-----------------|
| File naming | kebab-case, camelCase, PascalCase, snake_case | Regex on filenames |
| Import ordering | external-first, internal-first, ungrouped | Parse import blocks |
| Error handling | throw, return-error, console-error, silent | Grep function bodies |
| Async pattern | async-await, then-chains, mixed | Count await vs .then per file |
| Component style (Vue) | script-setup, options-api | Check `<script setup>` |
| Export style | named, default, barrel | Per-directory frequency |
| Indentation | tabs, spaces-2, spaces-4 | Read first 50 lines |
| Quote style | single, double | Count in import statements |

### Finding 6: Graduated Enforcement Prevents CI Breakage

**Source**: web-researcher (Agoda, Notion)

Standards should progress through enforcement levels: off → info → warn → error+budget → error+zero. This matches the PROPOSE → EVALUATE → ENFORCE lifecycle and prevents the anti-pattern of enabling a rule that produces hundreds of errors overnight.

---

## Recommendation

**Implement a three-part extension to code-sweep:**

### Part 1: Convention Discovery (Phase 1.5)
- New phase between OBSERVE and SCAN
- Runs on first invocation and every 10th run thereafter
- Samples up to 200 files with stratified sampling
- Detects 8 convention dimensions
- Stores results in `.code-sweep-standards.json`
- Auto-enforces at 70% adoption; flags 30-70% for review; skips <30%

### Part 2: File Queue for Large Codebases
- Persistent queue in `docs/sweeps/file-queue.json`
- Priority scoring: recently-modified (4x) + most-imported (3x) + hotspot (2x) + alphabetical (1x)
- 30 files per tick (configurable)
- Resume-safe with checkpointing
- Changed files always scanned; queued files scanned in batch order

### Part 3: Ratchet Mechanism
- Ratchet file at `docs/sweeps/ratchet.json`
- Per-standard violation budget that can only decrease
- Regression detection when violations exceed budget
- Trend tracking with velocity and ETA calculations

### New Flags
- `--discover`: Force convention discovery
- `--approve-standard <id>`: Approve a needs-review standard
- `--reject-standard <id>`: Reject/deprecate a standard
- `--standards-report`: Print compliance dashboard

---

## Implementation Sketch

### File Structure (new files)

```
.code-sweep-standards.json    # Discovered + defined standards (committed)
docs/sweeps/file-queue.json   # Persistent file processing queue
docs/sweeps/ratchet.json      # Per-standard violation budgets
```

### SKILL.md Changes

1. **Phase 0.1**: Add `--discover`, `--approve-standard`, `--reject-standard`, `--standards-report` flags
2. **New Phase 1.5: DISCOVER**: Convention discovery algorithm with 8 dimensions, stratified sampling, 70%/30% thresholds
3. **Phase 1 (OBSERVE)**: Load file queue and ratchet state alongside existing snapshot/ledger
4. **Phase 2 (SCAN)**: Batch-aware scanning — process queue batch + changed files, not all files
5. **Phase 3 (DIFF)**: Include standards violations in priority queue; ratchet regression detection
6. **Phase 4 (ACT)**: Standards-aware fix selection; ratchet budget update after fix
7. **Phase 5 (REPORT)**: Compliance dashboard with per-standard metrics, velocity, ETA

### Tick Type Decision Tree (loop mode)

```
if first_run or --discover:           → DISCOVERY tick
elif run_number % 10 == 0:            → RE-DISCOVERY tick
elif last_tick was scan AND fixable:   → FIX tick
else:                                  → SCAN tick
```

### reference.md Changes

1. Add `.code-sweep-standards.json` schema
2. Add `docs/sweeps/file-queue.json` schema
3. Add `docs/sweeps/ratchet.json` schema
4. Add convention detection patterns per dimension
5. Add compliance dashboard template for Phase 5

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Discovery produces wrong standard | Medium | 70% threshold + human review for ambiguous cases. User can override with `--reject-standard`. |
| File queue grows stale | Low | Re-prioritize when queue exhausted. Changed files always bypass queue. |
| Ratchet too strict (blocks legitimate pattern changes) | Medium | `--reject-standard` deprecates old standard. User can also edit `.code-sweep-standards.json` directly. |
| Discovery tick too slow for large codebases | Medium | Cap sampling at 200 files. 8 dimensions in ~30s. |
| Convention drift undetected | Low | Re-discovery every 10th run. Force with `--discover`. |
| Standards conflict with existing checks | Low | Standards use `cat: "std-<id>"` prefix; no overlap with existing check IDs. |
| Batch scanning misses cross-file issues | Medium | Tier 3 deep checks still run full-codebase with `--deep`. Batch scanning is for standards only. |

---

## References

- **Notion's eslint-seatbelt**: https://github.com/justjake/eslint-seatbelt
- **imbue-ai/ratchets**: https://github.com/imbue-ai/ratchets
- **eslint-formatter-ratchet**: https://github.com/ProductPlan/eslint-formatter-ratchet
- **suppress-biome-errors**: https://www.npmjs.com/package/@ton1517/suppress-biome-errors
- **Google SWE Book Ch. 22: Large-Scale Changes**: https://abseil.io/resources/swe-book/html/ch22.html
- **Stripe Sorbet**: https://sorbet.org/docs/gradual
- **Notion ratcheting blog**: https://www.notion.com/blog/how-we-evolved-our-code-notions-ratcheting-system-using-custom-eslint-rules
- **Agoda: Linting enforcement to education**: https://medium.com/agoda-engineering/how-to-make-linting-rules-work-from-enforcement-to-education-be7071d2fcf0
- **Martin Fowler on codemods**: https://martinfowler.com/articles/codemods-api-refactoring.html
