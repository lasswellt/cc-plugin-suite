# Domain: UI/UX Continuous Audit

## Purpose

Cross-page semantic consistency + data-quality + interactive-element coverage + analytics-event drift + per-role audit matrix + UI/UX heuristics. Sibling to `blitz:browse`; read-only.

Fills the gap no mainstream tool addresses: "dashboard says 47, list page says 46." Visual-regression tools (Percy, Chromatic, Applitools) explicitly mask numeric changes. None run per-role audits.

## Capabilities

- **CAP-008** — Skill scaffold + config loader + mode routing (foundation)
- **CAP-009** — Page data extraction + labeled-value registry
- **CAP-010** — Consistency check + invariant evaluator + flapping detection
- **CAP-011** — Data-quality flags (null/placeholder/format/stale/broken-total/negative)
- **CAP-012** — UI/UX heuristic audit (Vercel rules + severity tiers + a11y)
- **CAP-013** — Reporter (markdown + stdout + activity-feed)
- **CAP-014** — Interactive element coverage (every button/link/tab)
- **CAP-015** — Analytics event consistency (dataLayer + sendBeacon + network)
- **CAP-016** — Per-permissions-role audit matrix (5 roles)

## Existing modules

- `skills/browse/SKILL.md`, `skills/browse/reference.md` — crawl+fix engine (state source at `docs/crawls/`)
- `skills/_shared/session-protocol.md` — conflict matrix, session registration
- Playwright MCP tools (already loaded by browse)

## New modules

- `skills/ui-audit/SKILL.md` + `reference.md` + `CHECKS.md` + `PATTERNS.md`
- `.ui-audit.json.example` at repo root (three invariant blocks)
- Conflict-matrix row in `session-protocol.md`
- 1-line schema extension to `skills/browse/reference.md` (`latest-tick.json.page_data_registry`)

## Phase mapping

- **Phase 5** — Foundation: CAP-008 → 013 (E-008, E-009)
- **Phase 6** — Coverage expansion: CAP-014, 015, 016 (E-010, E-011, E-012), all depend on E-008

## Research source

`docs/_research/2026-04-23_ui-audit-skill.md` (2026-04-23).

## Key constraints

- Orchestrator frontmatter: `model: opus` + `effort: low` (survives `[1m]` parent; heavy work in sonnet workers)
- Full 5-role × 20-page matrix ≈ 200 min at `/loop 2m` — nightly CI territory. Smoke mode (anonymous+admin) ≈ 80 min.
- No code modification: `modifies_code: false`. Audit only.
- Conflict with `browse --loop` loop: WARN (reads state browse is writing).
