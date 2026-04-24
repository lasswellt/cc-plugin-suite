---
id: S6-006
title: "Phase 1 LOAD STATE — read browse crawl artifacts or lightweight internal crawl"
epic: E-008
capability: CAP-008
status: done
priority: P0
points: 3
depends_on: [S6-004]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/SKILL.md
verify:
  - "grep -q '## Phase 1 — LOAD STATE' skills/ui-audit/reference.md"
  - "grep -q 'crawl-visited.json' skills/ui-audit/reference.md"
  - "grep -q 'hierarchy.json' skills/ui-audit/reference.md"
  - "grep -q 'lightweight internal crawl' skills/ui-audit/reference.md"
done: "Phase 1 procedure documents reading docs/crawls/{crawl-visited,hierarchy}.json and a fallback lightweight crawl using browser_navigate + route manifest when state absent."
---

## Description

Ui-audit must work whether browse has run or not. Reads browse state when present; otherwise does a minimal Playwright MCP crawl (navigate each route, no fix, no screenshots) to build the page list.

## Acceptance Criteria

1. Phase 1 procedure specifies reading `docs/crawls/crawl-visited.json` (pages map) and `docs/crawls/hierarchy.json` (nav graph).
2. Detects `docs/crawls/latest-tick.json.status == "crawling"` and emits WARN (conflict matrix behavior).
3. Fallback path: if `crawl-visited.json` absent, run an internal crawl via `browser_navigate` over the route manifest. No fix, no screenshots, no interactions. Produces an ephemeral page list.
4. Fallback path preserves Playwright MCP tool availability check (ToolSearch pattern from browse Phase 1.2).
5. SKILL.md invokes the reference.md Phase 1 procedure and stores page list for Phase 2.

## Implementation Notes

- Browse Phase 1.2 tool-loading pattern (codebase-analyst research):
  ```
  ToolSearch: query=\"select:browser_navigate,browser_snapshot,browser_evaluate,browser_wait_for,browser_console_messages,browser_network_requests\"
  ```
- `browser_wait_for` has NO networkidle (domain-researcher). Use `textGone(spinner)` + `time:1` fallback; max 10s.
- `browser_network_requests` params: explicitly pass `{static:false, requestBody:false, requestHeaders:false}` — no useful defaults exist.
- State-reading pattern: try/read/fallback. Do NOT error on missing state; that's the fallback path's trigger.

## Dependencies

S6-004 — needs reference.md skeleton.
