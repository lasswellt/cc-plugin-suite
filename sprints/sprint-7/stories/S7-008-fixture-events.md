---
id: S7-008
title: "Fixture extension for analytics event audit (synthetic dataLayer fires + drift assertion)"
epic: E-011
capability: CAP-015
status: planned
priority: P0
points: 2
depends_on: [S7-007]
assigned_agent: test-writer
files:
  - skills/ui-audit/tests/fixture-app.html
  - skills/ui-audit/tests/fixture-ui-audit.json
  - skills/ui-audit/tests/run-fixture.sh
verify:
  - "bash skills/ui-audit/tests/run-fixture.sh"
  - "grep -qE 'event_drift|event_invariant_fail' skills/ui-audit/tests/run-fixture.sh"
done: "fixture-app.html inline-scripts 3 dataLayer pushes across 2 pages with intentional drift (page_view on /dashboard has {page_path}, on /invoices has {page_path, user_email}); fixture-ui-audit.json declares 1 event_invariant forbidding user_email; run-fixture.sh asserts 1 × event_drift + 1 × event_invariant_fail."
---

## Description

Exercise the event audit path end-to-end via synthetic dataLayer fires in the fixture HTML. No real analytics — pure simulation. Script scrapes the inline script blocks, builds a fake registry, and runs the drift + invariant reducers against it.

## Acceptance Criteria

1. `fixture-app.html` gains inline `<script>` blocks (one per section) that push to `window.dataLayer`:
   - `/#/dashboard`: `window.dataLayer.push({event: "page_view", page_path: "/dashboard", page_title: "Dashboard"})`
   - `/#/invoices`: `window.dataLayer.push({event: "page_view", page_path: "/invoices", page_title: "Invoices", user_email: "leaked@example.com"})`  ← intentional drift + forbidden prop
   - `/#/billing`: `window.dataLayer.push({event: "cta_click", cta_label: "Upgrade", cta_location: "hero"})`
2. `fixture-ui-audit.json` gains `event_invariants`:
   ```json
   [
     {"id":"EV-001","event_name":"page_view","required_props":["page_path","page_title"],"forbidden_props":["user_email"],"scope":"all_pages"}
   ]
   ```
3. `run-fixture.sh`:
   - Scrapes the 3 script blocks via grep
   - Synthesizes 3 `analytics_event` registry lines with hashes computed from key-sorted JSON
   - Runs the drift reducer → asserts exactly 1 drift (`page_view` has 2 distinct props_hashes across /dashboard and /invoices)
   - Runs the event_invariant evaluator for EV-001 → asserts exactly 1 violation (`user_email` forbidden) on /invoices
4. Asserts drift severity MED, invariant violation severity CRITICAL (auto-escalated per S7-007 PII list).

## Implementation Notes

- Scraping inline scripts: use the existing `grep -oE '<script[^>]*>[^<]+</script>'` pattern — doesn't need a full JS parser since the fixture uses flat object literals.
- JSON hashing in bash: `jq -c '.' | sha256sum | cut -c1-8` with key-sorted stringify preceded by `jq --sort-keys`.
- Keep the fixture script self-contained — no CDN-loaded analytics, no real network calls.

## Dependencies

S7-007.
