---
id: S7-013
title: "Loop matrix cadence — (role,page) tick cycle + latest-tick.json extension + R10 ETA/--ci gating"
epic: E-012
capability: CAP-016
status: planned
priority: P0
points: 3
depends_on: [S7-009, S7-010, S7-011, S7-012]
assigned_agent: backend-dev
files:
  - skills/ui-audit/SKILL.md
  - skills/ui-audit/reference.md
verify:
  - "grep -qE 'roles_complete|roles_pending' skills/ui-audit/reference.md"
  - "grep -qE 'ui_audit_matrix|current_role' skills/ui-audit/reference.md"
  - "grep -qE '--yes|--ci|ETA' skills/ui-audit/SKILL.md"
done: "SKILL.md loop mode expanded: each tick processes one (role,page) pair, state-machine LOAD_AUTH→NAVIGATE→EXTRACT→QUALITY→EVENT_DRAIN→INVARIANTS→WRITE→NEXT; latest-tick.json gains ui_audit_matrix block with current_role/current_page_idx/roles_complete/roles_pending; ETA printed upfront on full mode + --yes/--ci gate at >60min."
---

## Description

Full multi-role matrix execution in loop mode. Tick runs one (role, page) pair; persists matrix cursor in `latest-tick.json`; `/loop 2m` drives the schedule. ETA + gate prevents surprise 3-hour runs.

## Acceptance Criteria

1. SKILL.md `--loop` mode section extended with the per-tick state machine:
   ```
   LOAD_AUTH[current_role] → NAVIGATE[current_page] → EXTRACT → QUALITY
   → EVENT_DRAIN → INVARIANTS (numeric + event + role) → WRITE[role,page]
   → ADVANCE CURSOR → NEXT
   ```
2. `latest-tick.json` schema extension (document in reference.md, add to the existing schema block):
   ```json
   {
     "ui_audit_matrix": {
       "mode": "role_matrix|single_role|single_page",
       "current_role": "<name>",
       "current_page_idx": <int>,
       "roles_complete": ["<name>", ...],
       "roles_pending": ["<name>", ...],
       "matrix_started": "<ISO>",
       "eta_seconds": <int>
     }
   }
   ```
3. ETA gate (R10 mitigation, full implementation):
   - On `full` mode entry, compute `eta = roles_active × len(pages) × 120s`
   - Print: `[ui-audit] ETA for full matrix: <roles>×<pages>×2min = <mins> minutes`
   - If `eta > 3600s` (60 min) AND no `--yes` AND no `--ci` flag: exit 1 with `[ui-audit] ETA exceeds 1 hour; pass --yes to proceed interactively, or --ci to run in automation.`
   - `--yes` and `--ci` are otherwise equivalent; the distinction is audit trail (--ci writes an extra activity-feed `ci_run` event).
4. Termination: after 2 full passes of the matrix (pass 1 seeds registry, pass 2 detects drift), emit `skill_complete` with `mode: "loop-matrix-complete"` and stop advancing the cursor (subsequent /loop ticks become no-ops with a `matrix_idle` log).
5. Cursor persistence: each tick commits `latest-tick.json` before exit so /loop's fresh context can resume.

## Implementation Notes

- R10: the research doc specifies `--yes`/`--ci` gate for interactive sessions. Treat `CLAUDE_CODE_AUTONOMY ∈ {high, full}` as implicit `--ci` so the gate doesn't block loops.
- ETA computation: `roles_active` accounts for skip-if-absent; don't count anonymous-only into a 5-role estimate if only anonymous is configured.
- 2-pass termination is intentional. Pass 1 populates the registry. Pass 2 runs the flapping detector (which needs ≥2 observations) and the tick-diff classifier from sprint-6 § 3F. After pass 2, re-runs are redundant until the app changes — hence `matrix_idle` as the steady state.

## Dependencies

S7-009 (role mode + env), S7-010 (login), S7-011 (role invariants), S7-012 (leak scan). This is the capstone story that ties all the E-012 pieces into the loop.
