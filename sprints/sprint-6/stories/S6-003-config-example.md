---
id: S6-003
title: "Author .ui-audit.json.example with three invariant blocks"
epic: E-008
capability: CAP-008
status: planned
priority: P1
points: 1
depends_on: [S6-001]
assigned_agent: infra-dev
files:
  - .ui-audit.json.example
verify:
  - "test -f .ui-audit.json.example"
  - "jq -e '.invariants and .event_invariants and .role_invariants' .ui-audit.json.example >/dev/null"
  - "jq -e '.pages' .ui-audit.json.example >/dev/null"
done: ".ui-audit.json.example parses as JSON; has pages label-map + invariants + event_invariants + role_invariants keys with at least 1 sample entry each."
---

## Description

Ship a working config example so consumers can copy + adapt.

## Acceptance Criteria

1. `.ui-audit.json.example` at repo root, valid JSON.
2. Top-level keys: `baseUrl`, `pages` (label-map per page), `invariants` (cross-page numeric), `event_invariants` (analytics — skeleton for E-011), `role_invariants` (per-role — skeleton for E-012), `role_leak_patterns` (skeleton for E-012).
3. `pages` block has ≥2 example pages with ≥2 labels each, demonstrating `{ selector, type }` schema where `type ∈ {text, number, currency, count}`.
4. `invariants` block has 1 example with `id`, `sources: [{page,key}]`, `check: equal`, `tolerance: 0`.
5. Inline comments via `_comment` fields (JSON has no comments) explaining each block.

## Implementation Notes

- Schema shape from research doc §3.3:
  ```json
  {
    "baseUrl": "http://localhost:3000",
    "pages": {
      "/dashboard": {
        "open_invoices": {"selector": "[data-metric='open-invoices'] .value", "type": "number"},
        "total_revenue": {"selector": ".revenue-total", "type": "currency"}
      },
      "/invoices": {
        "open_invoices": {"selector": ".invoice-list .badge", "type": "count"}
      }
    },
    "invariants": [
      {
        "id": "INV-001",
        "description": "Open-invoice count matches dashboard + invoices list",
        "sources": [
          {"page": "/dashboard", "key": "open_invoices"},
          {"page": "/invoices",  "key": "open_invoices"}
        ],
        "check": "equal",
        "tolerance": 0
      }
    ],
    "event_invariants": [],
    "role_invariants": [],
    "role_leak_patterns": []
  }
  ```

## Dependencies

S6-001.
