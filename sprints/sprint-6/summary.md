# Sprint 6 — ui-audit Foundation

**Date:** 2026-04-23
**Epics:** E-008 (ui-audit skill foundation — scaffold + extraction + consistency + reporter)
**Capabilities:** CAP-008, CAP-009, CAP-010, CAP-013
**Stories:** 13

## Story count by agent role

| Agent | Stories |
|---|---|
| infra-dev | 6 (S6-001, S6-002, S6-003, S6-004, S6-005, S6-013) |
| backend-dev | 6 (S6-006, S6-007, S6-008, S6-009, S6-010, S6-011) |
| test-writer | 1 (S6-012) |
| frontend-dev | 0 |

## Dependency graph

```
S6-001 (scaffold) ───┬── S6-002 (registry+conflict)
                     ├── S6-003 (config example)
                     ├── S6-004 (reference skeleton) ─┬── S6-006 (Phase 1 LOAD STATE) ──┐
                     │                                ├── S6-007 (Phase 2 EXTRACT) <────┤
                     │                                │                                 │
                     │                                ├── S6-008 (Phase 3 DIVERGE) ◄────┘
                     │                                ├── S6-009 (Phase 3 INVARIANTS)
                     │                                ├── S6-010 (FLAPPING/STALE)
                     │                                └── S6-011 (Phase 6 REPORT)
                     └── S6-013 (CHECKS/PATTERNS skeletons)

S6-005 (browse schema) — independent, parallel
S6-012 (integration test) — gated on S6-007, S6-008, S6-009, S6-011
```

Parallelizable: S6-002, S6-003, S6-004, S6-005, S6-013 can all run after S6-001 in parallel. S6-008 + S6-010 can parallel after S6-007.

## Research highlights

From `sprints/sprint-6/research/`:

- **domain-researcher:** Playwright MCP `browser_wait_for` lacks networkidle; use textGone + time-fallback. `browser_evaluate` single round-trip safe for object returns. JSONL `>>` append is race-safe for single-session (matches `crawl-ledger.jsonl` pattern). Add `select(.ts != null)` guard to jq reducers.
- **library-researcher:** `effort: low` not yet used in repo (first adoption); Claude Code docs confirm support. `md5sum` non-portable — use `sha256sum 2>/dev/null || shasum -a 256 | cut -c1-8`. 9 mandatory skill-registry fields, maturity `experimental`.
- **codebase-analyst:** browse state schemas in `skills/browse/reference.md:406,443,512`. Conflict matrix table at `session-protocol.md:215-250`. Story verify: field conventions: inline shell strings, 2-4 items, `test -f`/`grep -q` pattern.

## Carry-forward

None (prior sprint's carry-forward registry is empty).

## Risks

- **R-sprint-6.1 — `effort:` frontmatter adoption.** First use in repo. If parser rejects the field, S6-001 verify fails → fix by stripping and opening a retro ticket. Documented in S6-001 implementation notes.
- **R-sprint-6.2 — Playwright MCP tool availability.** S6-006 depends on ToolSearch finding `browser_*` tools. If Playwright MCP plugin not installed, skill must error clearly (documented in S6-006 fallback branch).
- **R-sprint-6.3 — Fixture portability.** S6-012 uses `python3 -m http.server`. On systems without python, fallback to `npx http-server` adds latency. Fixture timeout should be generous (30s).

## Spidr splits

None. No story triggered the bulk-story guard.
