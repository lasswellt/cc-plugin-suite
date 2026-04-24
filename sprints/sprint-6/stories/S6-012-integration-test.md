---
id: S6-012
title: "Integration test — fixture page + seeded labels + e2e verification"
epic: E-008
capability: CAP-009
status: planned
priority: P0
points: 2
depends_on: [S6-007, S6-008, S6-009, S6-011]
assigned_agent: test-writer
files:
  - skills/ui-audit/tests/fixture-app.html
  - skills/ui-audit/tests/fixture-ui-audit.json
  - skills/ui-audit/tests/run-fixture.sh
verify:
  - "test -x skills/ui-audit/tests/run-fixture.sh"
  - "bash skills/ui-audit/tests/run-fixture.sh"
done: "run-fixture.sh spins a static HTML fixture with 3 pages × 2 labels, runs ui-audit against it, asserts 6 registry lines produced, asserts 1 seeded invariant failure detected, asserts report.md generated."
---

## Description

End-to-end smoke test. Static HTML fixture with 3 pages, each declaring 2 labeled values. One label intentionally mismatched across pages to trigger an invariant failure. Script asserts the expected registry + report.

## Acceptance Criteria

1. `fixture-app.html` — 3 pages (`/dashboard`, `/invoices`, `/billing`) inline as hash-routed sections, each with 2 labeled `data-metric` elements.
2. `fixture-ui-audit.json` declares 6 labels + 1 invariant that MUST fail (intentional mismatch on `open_invoices` between `/dashboard` and `/invoices`).
3. `run-fixture.sh`:
   - Starts a static server (python3 -m http.server or similar) on a test port
   - Invokes ui-audit `full` mode against the fixture
   - Asserts `docs/crawls/page-data-registry.jsonl` has exactly 6 lines
   - Asserts `docs/crawls/ui-audit-report.md` contains the string `INV-001:FAIL`
   - Asserts `.cc-sessions/activity-feed.jsonl` tail contains an `invariant_fail` event
   - Cleans up (stops server, removes fixture state)
4. Script exits 0 on success, non-zero with diagnostic stderr on failure.

## Implementation Notes

- Self-contained fixture — no network, no real app. Just HTML with JS-controlled section visibility.
- Static server choice: `python3 -m http.server` if available; else `npx http-server`. Prefer python (fewer deps).
- Trap EXIT to kill server + delete fixture state files under `docs/crawls/` (but ONLY files the test created — do NOT blow away operator state).

## Dependencies

All extraction + consistency + reporter stories must be done.
