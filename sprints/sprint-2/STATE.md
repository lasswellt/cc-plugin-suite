# Sprint 2 — STATE

**Last updated:** 2026-04-18T10:58:00Z
**Status:** review — implementation complete (4 done + 1 partial-accepted)
**Executor:** sprint-dev-79b8501e (tick 3); sprint-dev-7b9ebab9 (tick 2)

## Waves

| Wave | Stories | Status |
|---|---|---|
| 0 | S2-001..S2-005 | 5/5 advanced (1 partial-accepted) |

## Stories — final

| ID | Title | Status | Commit | Registry final |
|---|---|---|---|---|
| S2-001 | terse-output ref → 6 agent files | done | 2a61c71 | cf-terse-directive-agents 1.0 complete |
| S2-002 | terse-output ref → 6 SKILL.md gap | done | bec1d9f | cf-terse-directive-skill-gap 1.0 complete |
| S2-003 | terse-output cross-ref → 10 shared protocols | done | a51ae02 | cf-terse-directive-shared-protocols 1.0 complete |
| S2-004 | compress 7 SAFE reference.md | partial (6/7) | 5e5b2a9 | cf-compress-safe-references-wave2 0.857 partial |
| S2-005 | compress 12 research docs | done | tick-3 | cf-compress-research-docs 1.0 complete |

## Compression totals

| Wave | Files | Before (B) | After (B) | Δ |
|---|---|---|---|---|
| S2-004 (6 of 7 SAFE reference.md) | 6 | 63,960 | 63,148 | -1.27% |
| S2-005 (12 research docs) | 12 | 225,239 | 221,855 | -1.50% |
| **Wave 0 total** | **18** | **289,199** | **285,003** | **-1.45%** |

18 new `.original` pairs. Validator exit 0 across all 28 pairs repo-wide (10 from S1-005 + 18 from S2).

## Open items for sprint-review

1. **completeness-gate UNSAFE reclassification.** Research doc listed it SAFE; file actually contains `## Grep Patterns by Check`. Options:
   - Rename heading, re-run compression.
   - Accept uncompressed (grep patterns are load-bearing).
   - Waive via `<!-- no-registry: <reason> -->` comment.
   Sprint-review Invariant 1 will flag cf-compress-safe-references-wave2 status=partial; operator decides.

2. **Directive coverage at 47/51 load-bearing files** (agents + 31 SKILL.md + 11 shared protocols + `implement`/`review`/`quick` exempt + terse-output.md itself). Foundation for Phase-2 runtime-propagation work (Sprint 3).

3. **CF registry state:** 4 complete, 1 partial, 9 active. All parent.capability + parent.epic links backfilled.

## Blockers

None.
