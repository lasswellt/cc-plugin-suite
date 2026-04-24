---
id: S6-010
title: "Flapping/STALE/NULL_TRANSITION tick-diff taxonomy"
epic: E-008
capability: CAP-010
status: done
priority: P1
points: 2
depends_on: [S6-004, S6-007]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'FLAPPING' skills/ui-audit/reference.md"
  - "grep -q 'STALE' skills/ui-audit/reference.md"
  - "grep -q 'NULL_TRANSITION' skills/ui-audit/reference.md"
  - "grep -qE '3 ticks' skills/ui-audit/reference.md"
done: "Tick-diff detector reads last ≥3 observations for each (role,page,label), classifies STABLE/CHANGED/STALE/FLAPPING/NULL_TRANSITION, and emits findings for the non-STABLE states."
---

## Description

Hash-based tick-over-tick diff surfaces cache jitter + transient nulls. Reads ≥3 most-recent observations per (role, page, label). Classifies per research doc §3.5.

## Acceptance Criteria

1. Classifier implemented in reference.md as a documented procedure (jq script + bash wrapper).
2. Five states produced: `STABLE` (silent), `CHANGED` (update registry, log `value_change`), `STALE` (reverted within 2 ticks), `FLAPPING` (oscillates ≥3 ticks), `NULL_TRANSITION` (real → null, flag immediately).
3. Each non-STABLE state emits a finding into the Phase 3 output bundle.
4. Requires ≥3 ticks of history to detect FLAPPING; fewer ticks degrade gracefully to CHANGED/STABLE only.

## Implementation Notes

- Per-value hash from S6-007 extraction step is the input — no new hashing here.
- FLAPPING detection algorithm:
  ```
  last_N = last 3 hashes for (role,page,label), most-recent first
  if len(last_N) == 3 and last_N[0] != last_N[1] and last_N[0] == last_N[2]: FLAPPING
  ```
- STALE detection: if current hash matches the hash from 2 ticks ago but not the previous tick.
- NULL_TRANSITION: current `parsed === null` AND any of last 3 non-null.

## Dependencies

S6-004, S6-007.
