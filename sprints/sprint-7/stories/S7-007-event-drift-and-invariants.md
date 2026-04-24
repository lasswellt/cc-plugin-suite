---
id: S7-007
title: "Cross-page event drift detection + event_invariants evaluator (required/forbidden/scope)"
epic: E-011
capability: CAP-015
status: done
priority: P0
points: 2
depends_on: [S7-006]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'required_props' skills/ui-audit/reference.md"
  - "grep -q 'forbidden_props' skills/ui-audit/reference.md"
  - "grep -qE 'event_drift|cross-page.*event|event.*cross-page' skills/ui-audit/reference.md"
done: "reference.md Phase EVENTS documents: (a) cross-page drift jq reducer (same event_name fires on >1 page with different props_hash); (b) event_invariants evaluator for required_props + forbidden_props + scope (all_pages | pages_with_cta | explicit list)."
---

## Description

Two complementary detectors. **Drift** is undeclared (author hasn't specified what a given event SHOULD look like, but fires with diverging shapes across pages — auto-flag). **Invariants** are declared (required/forbidden prop sets per event name with explicit scope).

## Acceptance Criteria

1. Cross-page event drift reducer documented (research doc §3.8):
   ```bash
   jq -s '[.[]|select(.label=="analytics_event")]
     | group_by(.detail.event_name)
     | map({event: .[0].detail.event_name, pages: (group_by(.page) | map({page:.[0].page, props_hash:.[0].hash}))})
     | map(select(.pages|length>1))
     | map(select((.pages|map(.props_hash)|unique|length)>1))' docs/crawls/page-data-registry.jsonl
   ```
   Each result → `event_drift` finding, severity MED, detail lists the pages + their props_hashes.
2. event_invariants evaluator reads `.ui-audit.json.event_invariants[]` with schema:
   ```json
   {"id":"EV-001","event_name":"page_view","required_props":["page_path","page_title"],"forbidden_props":["user_email"],"scope":"all_pages|pages_with_cta|<explicit array>"}
   ```
3. For each invariant: resolve `scope` → set of pages; for each in-scope page, check every event with matching `event_name` for required-props presence + forbidden-props absence. Violations → `event_invariant_fail` finding, severity HIGH.
4. `scope: "pages_with_cta"` heuristic: any page where ≥1 registered label is declared, or where ≥1 click was performed. Document the heuristic.
5. Activity-feed `event_invariant_fail` / `event_drift` events per Phase 6 reporter's existing event-type list.

## Implementation Notes

- Required/forbidden is a bag-of-keys check, not deep shape. Future work (E-011 follow-up): JSON-Schema-based prop validation.
- If `forbidden_props` contains `user_email`, `password`, `ssn`, `credit_card`, `token` — severity auto-escalates to CRITICAL (likely PII leak in analytics payload). Document the auto-escalate list.
- Reporter extension: S7-011/S7-013 do NOT update Phase 6 reporter; the reporter already accepts `severity` from producers and groups by tier (sprint-6 design). Verify by grep.

## Dependencies

S7-006.
