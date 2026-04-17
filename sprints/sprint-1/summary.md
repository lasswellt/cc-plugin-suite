# Sprint 1 — caveman-compress input-side pilot

**Mode:** lightweight (no full sprint-plan ceremony — no roadmap in this meta repo).
**Source:** `docs/_research/2026-04-16_caveman-compress-input-side.md`

## Stories

| ID | Title | Agent | Points | Depends on |
|---|---|---|---|---|
| S1-001 | Reference compression validator script | backend-dev | 2 | — |
| S1-002 | Batch wrapper for caveman-compress | backend-dev | 1 | S1-001 |
| S1-003 | Compress 12 SAFE reference.md files | backend-dev | 3 | S1-001, S1-002 |

**Total points:** 6. **Stories:** 3. **Agent distribution:** backend-dev 3.

## Dependency graph

```
S1-001 ── S1-002 ── S1-003
   └────────────────┘
```

S1-001 must land first. S1-002 and S1-003 can be sequential or S1-003 can wait on both.

## Expected outcomes

- 12 `reference.md` files compressed, ~15–25% total line reduction (~1,200–2,400 lines).
- 12 `.original.md` backups committed as source-of-truth.
- Pre-commit validator guards future edits.
- Seven files intentionally untouched (UNSAFE/RISKY classification — see research doc).

## Carry-forward / risks

- No existing roadmap or epic-registry — this sprint is scoped narrowly to research-doc execution.
- If validator catches damage, affected skills reclassify to RISKY and drop out of the 12-file target. Story S1-003 still counts as done if ≥10 of 12 pass (per AC floor of 15% line reduction across remaining).
- Python 3.10+ becomes an author-time (not end-user) dependency via caveman-compress.

## Registry links

Two carry-forward scope entries from the research doc are referenced:
- `cf-2026-04-16-reference-compression-validator` (satisfied by S1-001)
- `cf-2026-04-16-compress-safe-references` (satisfied by S1-003)

These are not yet ingested into `.cc-sessions/carry-forward.jsonl` because `/blitz:roadmap extend` was skipped. If roadmap tracking is desired later, re-run roadmap extend against the research doc.
