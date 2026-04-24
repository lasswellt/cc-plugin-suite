---
id: S6-008
title: "Phase 3 CONSISTENCY — jq reducer + cross-page divergence detection"
epic: E-008
capability: CAP-010
status: planned
priority: P0
points: 2
depends_on: [S6-004, S6-007]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q '## Phase 3 — CONSISTENCY' skills/ui-audit/reference.md"
  - "grep -qE 'group_by.*label' skills/ui-audit/reference.md"
  - "grep -qE 'max_by.*ts' skills/ui-audit/reference.md"
done: "Phase 3 procedure includes the 2-stage jq reducer (group_by label → latest-per-page) with null-guards, and the divergence-detection logic that emits a finding when >1 distinct parsed value exists across pages for the same label."
---

## Description

Reduce the append-only JSONL to latest-per-(label,page) state, then detect cross-page value divergence. Emits findings unless covered by an invariant with tolerance (S6-009 handles tolerance).

## Acceptance Criteria

1. Phase 3 reducer documented as a concrete bash snippet:
   ```bash
   jq -s '
     [.[] | select(.ts != null and .label != null)]
     | group_by(.label)
     | map({
         label: .[0].label,
         obs: (group_by(.page) | map(max_by(.ts)) | map({page, parsed, raw, page}))
       })
   ' docs/crawls/page-data-registry.jsonl
   ```
2. Divergence rule: `label` groups where `obs | map(.parsed) | unique | length > 1` → emit finding `label:cross-page-divergence` with per-page values.
3. Null-guard `select(.ts != null and .label != null)` present (domain-researcher note — skip failed extractions).
4. Emits finding to `docs/crawls/ui-audit-report.md` at DRAFT stage + `invariant_fail` events to activity feed (full reporter lands in S6-011).
5. Divergences pre-suppressed when a matching invariant (S6-009) with tolerance covers them.

## Implementation Notes

- `group_by(.label)` on jq 1.6 is safe with null keys (library-researcher) but the pre-filter removes them anyway.
- Two-stage reduction: first group-by-label, then inner group-by-page + max-by-ts. This yields `latest value per page per label`.
- Output goes to `${SESSION_TMP_DIR}/divergences.json` for S6-009 to read alongside invariant results.

## Dependencies

S6-004 (skeleton), S6-007 (registry must be populated).
