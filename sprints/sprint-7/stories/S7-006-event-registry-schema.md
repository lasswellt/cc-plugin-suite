---
id: S7-006
title: "Event registry schema + drain → append + action-trigger keying"
epic: E-011
capability: CAP-015
status: done
priority: P0
points: 2
depends_on: [S7-005]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'analytics_event' skills/ui-audit/reference.md"
  - "grep -q 'action_trigger' skills/ui-audit/reference.md"
  - "grep -q 'event_name' skills/ui-audit/reference.md"
done: "reference.md Phase EVENTS documents: (a) analytics_event registry line schema keyed on (page, action_trigger) → {event_name, layer, props}; (b) drain-after-click vs drain-per-page cadence decision; (c) props hash for drift detection."
---

## Description

Capture the drained event log as JSONL lines. Each line is keyed by (page, action_trigger) and carries the event name + layer (dataLayer/beacon/network) + props. Hash of props enables cross-page drift detection (same event name, different prop schemas).

## Acceptance Criteria

1. Registry line schema documented (matches research doc §3.8):
   ```jsonl
   {"ts":"<ISO>","role":"__default__","page":"<path>","label":"analytics_event","raw":"<json-stringified payload>","parsed":null,"hash":"<sha8 of props JSON>","selector":null,"tick":<n>,"detail":{"event_name":"<name>","layer":"dataLayer|beacon|network","action_trigger":"<action>","props":<object>}}
   ```
2. `action_trigger` values (finite set): `page_load`, `click:<element-label>`, `tab:<tab-label>`, `scroll`, `timer:<ms>`, `manual`. Default `page_load` for events fired during initial render; `click:<label>` for events fired within 1s of a safe-click. Anything else → `manual`.
3. Drain cadence: one drain per safe-click (captures click-attributed events) + one final drain at end-of-page (captures any residual). Each drain's events get their `action_trigger` from the triggering event (click label or `page_load` for the initial drain).
4. Hash: `sha256(JSON.stringify(props, Object.keys(props).sort())) | cut -c1-8` — key-sorted stringify so prop order doesn't cause false drift. Document the exact command.
5. JSONL append to `docs/crawls/page-data-registry.jsonl` (same file as observations — the `label: "analytics_event"` distinguishes). Phase 3 reducers already exclude this label from the observation reducer (sprint-6 Finding 2 fix).

## Implementation Notes

- The drain-per-click pattern was the chosen tradeoff per research doc OQ5: cheaper batching loses click-attribution. We pay the per-click drain cost to preserve the (action, event) association.
- Key-sorted stringify: `JSON.stringify(obj, Object.keys(obj).sort())` is a well-known idiom; document so future maintainers don't re-invent.

## Dependencies

S7-005.
