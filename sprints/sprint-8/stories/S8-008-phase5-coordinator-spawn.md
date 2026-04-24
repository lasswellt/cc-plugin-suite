---
id: S8-008
title: "Phase 5 coordinator — severity tiering + parallel sonnet spawn when pages >30"
epic: E-009
capability: CAP-012
status: done
priority: P0
points: 2
depends_on: [S8-006, S8-007]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'Phase 5 — HEURISTICS' skills/ui-audit/reference.md"
  - "grep -qE 'model: \"sonnet\"|model: sonnet' skills/ui-audit/reference.md"
  - "grep -qE 'inline.*30|30.*parallel' skills/ui-audit/reference.md"
done: "reference.md Phase 5 stub replaced with coordinator: runs Vercel Cat 9 + Cat 16 inline when pages ≤30, spawns parallel sonnet Agent workers per category when >30. Severity tier mapping (CRITICAL/HIGH/MED/LOW) documented. Spawn snippet uses explicit model: sonnet per research doc §6.1."
---

## Description

Phase 5 currently stubs to "no-op — see E-009". Replace with the real coordinator that runs the Cat 9 (S8-006) and Cat 16 (S8-007) heuristics.

## Acceptance Criteria

1. `reference.md ## Phase 5 — HEURISTICS` section replaces the stub. Sections:
   - 5.1 Category dispatcher — checks `.ui-audit.json[heuristics][enabled_categories]` (default: `["nav_state", "content_copy"]`, i.e., 9 + 16). Skip disabled.
   - 5.2 Scale decision — if `pages.length <= 30`, run inline; else spawn parallel sonnet workers per enabled category.
   - 5.3 Severity tier table — explicit mapping CRITICAL (a11y blocker / touch-target fail) / HIGH (WCAG AA) / MED (UX degradation) / LOW (copy polish).
   - 5.4 Reporter handoff — emits `heuristic` JSONL lines with `detail.rule_id` + `detail.severity`. Phase 6 reporter already groups by severity.
2. Spawn pattern for parallel mode uses the canonical snippet from research doc § 6.1 — EXPLICIT `model: "sonnet"` on every `Agent` spawn to prevent `[1m]` inheritance. Include the snippet verbatim in reference.md as a copyable template.
3. No new browser calls at the coordinator level — each category's checks own their browser interactions.
4. Activity-feed event `heuristic_pass_complete` with per-category finding counts.

## Implementation Notes

- The `model: "sonnet"` requirement is load-bearing. Omitting it re-introduces the bug documented in research doc § 6.1 (and saved memory `feedback_skill_model_1m_inheritance.md`). Cite both in the reference.md spawn snippet's docblock.
- Parallel workers per category — one sonnet Agent for Category 9, one for Category 16. Each writes findings to `${SESSION_TMP_DIR}/heuristic-cat{N}-findings.jsonl`. Coordinator merges after both complete.

## Dependencies

S8-006, S8-007 (the categories this coordinator dispatches).
