---
id: S7-009
title: "Role mode routing + env var contract + skip-if-absent"
epic: E-012
capability: CAP-016
status: done
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/SKILL.md
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'AUDIT_ADMIN_EMAIL\\|AUDIT_ANONYMOUS' skills/ui-audit/SKILL.md"
  - "grep -q 'Phase ROLE' skills/ui-audit/reference.md"
  - "grep -q 'skip-if-absent\\|skip if absent\\|ROLE_SKIP' skills/ui-audit/reference.md"
done: "SKILL.md role mode specifies the 5-role env var contract (AUDIT_<ROLE>_EMAIL/_PASS for VIEWER/MEMBER/ADMIN/SUPERADMIN; AUDIT_ANONYMOUS=true boolean); reference.md Phase ROLE documents the skip-if-absent policy + ROLE_SKIP activity-feed event."
---

## Description

Declare the env var contract. A role is `active` only if its credentials are present. Missing credentials → skip the role silently with a `ROLE_SKIP` log event. No dynamic user creation, per safety rule 6.

## Acceptance Criteria

1. `SKILL.md` Phase 0 arg-parse for `role <name>` mode updated to enumerate the 5 recognized role names: `anonymous`, `viewer`, `member`, `admin`, `superadmin`. Any other name → exit 1 with usage.
2. SKILL.md documents env var contract:
   ```
   AUDIT_ANONYMOUS=true             # or unset (true) — anonymous needs no creds
   AUDIT_VIEWER_EMAIL  / _PASS
   AUDIT_MEMBER_EMAIL  / _PASS
   AUDIT_ADMIN_EMAIL   / _PASS
   AUDIT_SUPERADMIN_EMAIL / _PASS
   ```
3. `reference.md` gains `## Phase ROLE — Per-permissions-role cycle` section (after Phase EVENTS) with:
   - Role enumeration loop
   - Skip-if-absent logic: missing `AUDIT_<ROLE>_EMAIL` (and role ≠ anonymous) → log `ROLE_SKIP` activity-feed event, continue
   - In `full` mode: iterate all 5 roles in order anonymous → viewer → member → admin → superadmin
   - In `smoke` mode: only anonymous + admin
   - In `role <name>` mode: only the named role
4. ETA gating (R10 mitigation, partial — full implementation in S7-013): on `full` mode, compute `roles_active * pages * 2min` and print upfront. If >60 min, require `--yes` (decline-on-interactive session flag) or `--ci`. Gate is documented; the CLI flag parsing can be a TODO if the flag wiring is nontrivial.
5. No credentials are logged anywhere — neither to stdout, activity-feed, nor report. Document this explicitly in SKILL.md § SAFETY RULES (extend Rule 6).

## Implementation Notes

- `AUDIT_ANONYMOUS` defaults to `true` when unset. Anonymous role always runs.
- Env var reading via Bash `${VAR:-}` with expansion; log only the presence boolean, never the value.
- Activity-feed `ROLE_SKIP` event format: `{role: <name>, reason: "env_vars_absent", missing: [<names>]}`.

## Dependencies

None.
