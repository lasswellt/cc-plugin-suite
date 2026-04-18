**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Sprint 3 — Summary

**Planned:** 2026-04-18
**Status:** planned
**Phase:** 2 (Runtime Propagation) per `docs/roadmap/phase-plan.json`
**Epics:** E-003 (runtime write-phase directive), E-004 (review format absorption)
**Stories:** 4 total (1 gap-closure + 3 forward-epic)

## Story distribution

| Role | Count | Stories |
|---|---|---|
| doc-writer | 3 | S3-001, S3-002, S3-003 |
| backend-dev | 1 | S3-004 |

## Dependencies

All 4 stories independent. Fully parallel-executable.

```
S3-001 (8 SKILL.md)  ── doc-writer
S3-002 (7 UNSAFE ref) ── doc-writer
S3-003 (review fmt)  ── doc-writer
S3-004 (Sprint-2 gap)── backend-dev
```

## Registry coverage

| Entry | Target | Parent | Phase completion |
|---|---|---|---|
| cf-write-phase-directive-inserts | 8 | E-003 / CAP-003 | S3-001 done → complete |
| cf-unsafe-ref-agent-prompt-injection | 7 | E-003 / CAP-003 | S3-002 done → complete |
| cf-review-format-absorption | 2 | E-004 / CAP-004 | S3-003 done → complete |
| cf-compress-safe-references-wave2 | 7 | E-002 / CAP-002 | S3-004 done → complete OR dropped OR deferred |

## Research

**Skipped.** Work specs live in `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` Phase A (A.1-A.3) and `docs/_research/2026-04-18_caveman-full-absorption.md` Recommendation Phase 5. Both docs were compressed in Sprint 2 S2-005 but scope blocks byte-identical.

## Deferred to Sprint 4 (Phase 3)

Per roadmap phase-plan.json, these 5 registry entries are visible in `sprint-3-planning-inputs.json` but belong to E-005 (CAP-005 state+gating) or E-006 (CAP-006 boilerplate dedup) — Phase 3 / Sprint 4:

- cf-output-intensity-profile (CAP-005)
- cf-lite-exemption-markers (CAP-005)
- cf-task-type-gating (CAP-005, superseded — will transition to `dropped`)
- cf-activity-feed-message-rule (CAP-005)
- cf-agent-prompt-boilerplate (CAP-006)

They'll auto-inject again from Sprint-3-review's Invariant 4 into `sprint-4-planning-inputs.json` when Sprint 3 reviews out; rollover_count increments to 2. Escalation threshold is 3 — still safe.

## Out of scope (deferred to Sprint 5 — Phase 4)

- cf-spawn-protocol-warning-upgrade (CAP-007) — WARNING → BLOCKER. Gated behind CAP-003 + one clean post-rollout sprint per phase-plan.

## Risks

1. **Sprint 3 edits overlap Sprint 2 edits.** S2-002 added terse-output refs to 6 SKILL.md. S3-001 edits 8 SKILL.md — 3 files overlap (research, sprint-review, roadmap already have terse-output link but need the inline directive at write-site). No conflict; additive edits. Verify each SKILL.md isn't double-edited.

2. **Manual edits on UNSAFE reference.md.** S3-002 requires hand-edit of 7 files that `/blitz:compress` refuses. Risk: accidental formatting drift. Mitigation: use `Edit` tool with precise old_string matches; diff-review each change.

3. **Sprint-review invariants after Sprint 3.** If S3-002 lands, spawn-protocol.md:328 WARNING would stop firing (snippet is now present in all UNSAFE files). Safe to bump WARNING→BLOCKER in Sprint 5. If S3-002 partials, Sprint 4 must finish it before CAP-007.
