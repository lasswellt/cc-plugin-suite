---
id: S8-005
title: "Phase 4 coordinator — aggregate inline + reducer findings, emit to reporter"
epic: E-009
capability: CAP-011
status: done
priority: P0
points: 2
depends_on: [S8-001, S8-002, S8-003]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'Phase 4 — QUALITY' skills/ui-audit/reference.md"
  - "grep -qE 'aggregates.*finding|finding.*aggregate' skills/ui-audit/reference.md"
done: "reference.md Phase 4 stub replaced with real coordinator that (a) collects inline flags from Phase 2 extraction (NULL_VALUE/PLACEHOLDER/NEGATIVE_COUNT), (b) runs reducer-based detectors (FORMAT_MISMATCH/STALE_ZERO/BROKEN_TOTAL), (c) emits consolidated quality_flag JSONL lines, (d) passes counts to Phase 6 reporter."
---

## Description

Phase 4 currently has a `<!-- Phase 4 coordinator here. Full body lands in E-009 -->` stub. Replace with the real coordinator that runs all 6 quality flags and hands results to the reporter.

## Acceptance Criteria

1. `reference.md ## Phase 4 — QUALITY` section replaces the stub. Sections:
   - 4.1 Inline flag collection — Phase 2 already writes `quality_flag` JSONL lines for NULL_VALUE / PLACEHOLDER / NEGATIVE_COUNT. Phase 4 reads the registry's latest-wins slice of those.
   - 4.2 Reducer detectors — runs FORMAT_MISMATCH (S8-001), STALE_ZERO (S8-002), BROKEN_TOTAL (S8-003) reducers. Each emits new `quality_flag` JSONL lines.
   - 4.3 Aggregation — total findings per flag per severity. Activity-feed event `quality_pass_complete` with counts.
   - 4.4 Reporter handoff — Phase 6 reporter already accepts `quality_flag`-labeled findings by severity; no changes needed there.
2. Skipped in `consistency`-only and `heuristics`-only modes. Runs in `full`, `smoke`, `data`, `role <name>`, `--loop`.
3. Phase 4 is idempotent — re-running on an unchanged registry emits identical findings (modulo ts).

## Implementation Notes

- No new browser calls. Phase 4 is purely a reducer stage over `docs/crawls/page-data-registry.jsonl`.
- Run the 3 reducer detectors in parallel via backgrounded jq processes if page count >30 — otherwise inline sequential.

## Dependencies

S8-001, S8-002, S8-003 (the detectors this coordinator wires together).
