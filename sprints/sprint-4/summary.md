**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Sprint 4 — Summary

**Planned:** 2026-04-18
**Phase:** 3 (State + Gating) per roadmap phase-plan
**Epics:** E-005 only (E-006 + E-007 deferred to Sprint 5 per Option A)
**Stories:** 4 (all E-005 scope)

## Story distribution

| Role | Count | Stories |
|---|---|---|
| doc-writer | 2 | S4-002, S4-004 |
| backend-dev | 2 | S4-001, S4-003 |

## Dependencies

```
S4-001 (intensity schema)    ── independent
S4-002 (9 LITE markers)      ── independent
S4-004 (activity-feed rule)  ── independent
S4-003 (drop task-type-gating) ── depends on S4-002
```

3/4 parallel-executable. S4-003 is 1 JSONL line after S4-002 lands.

## Registry coverage

| Entry | Target | Completion trigger |
|---|---|---|
| cf-output-intensity-profile | 1 | S4-001 → complete |
| cf-lite-exemption-markers | 9 | S4-002 → complete |
| cf-task-type-gating | 5 (superseded) | S4-003 → dropped |
| cf-activity-feed-message-rule | 1 | S4-004 → complete |

Rollover counts (at sprint start): all 4 entries at count=2 (incremented by Sprint-2 and Sprint-3 Invariant 2). Sprint 4 addresses them → rollover count halts; no escalation risk.

## Deferred to Sprint 5 (Phase 4)

- cf-agent-prompt-boilerplate (CAP-006 / E-006) — extract boilerplate fragment + refactor 7 UNSAFE reference.md to import
- cf-spawn-protocol-warning-upgrade (CAP-007 / E-007) — now unblocked since Sprint 3 delivered S3-002

Both will auto-inject from Sprint-4-review Invariant 4 into `sprints/sprint-5-planning-inputs.json` with rollover count = 3. **Sprint 5 is the last chance to address them before row 6a escalation.**

## Out of scope

- Full roadmap refresh (`/blitz:roadmap refresh`) to transition E-001..E-005 from `pending` to `done`. Stale state noted in Sprint 3 review Invariant 3 (vacuous pass). Defer to post-Sprint-5 cleanup.

## Risks

1. **Rollover count crossing threshold in Sprint 5.** 2 entries (cf-agent-prompt-boilerplate, cf-spawn-protocol-warning-upgrade) will be at rollover=3 after Sprint 4 reviews out. If Sprint 5 doesn't address them, row 6a fires in Sprint 6's tick — escalation banner + /loop cannot auto-advance. Planning must make Sprint 5 cover both.

2. **S4-003 superseded-drop is the second drop event in the registry** (first was S3-004 / cf-compress-safe-references-wave2). The drop protocol is validated by two real use cases now: preservation-boundary and supersede-by-newer-entry.

3. **Option A commits to a 2-sprint remaining runway** for full caveman absorption (this Sprint 4 + Sprint 5). Option B (bundle everything in Sprint 4) would finish in this sprint but at 7-8 stories — larger. Autonomy=full defaults to A.
