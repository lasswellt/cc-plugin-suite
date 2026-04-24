---
id: S6-004
title: "Write skills/ui-audit/reference.md skeleton — 6 phase procedures + schemas"
epic: E-008
capability: CAP-008
status: done
priority: P0
points: 2
depends_on: [S6-001]
assigned_agent: infra-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "test -f skills/ui-audit/reference.md"
  - "grep -q '## Phase 0' skills/ui-audit/reference.md"
  - "grep -q '## Phase 6' skills/ui-audit/reference.md"
  - "grep -q 'page-data-registry.jsonl' skills/ui-audit/reference.md"
  - "grep -q 'browser_evaluate' skills/ui-audit/reference.md"
done: "reference.md contains 6 phase sections (0 CONTEXT, 1 LOAD STATE, 2 EXTRACT, 3 CONSISTENCY, 4 QUALITY, 5 HEURISTICS, 6 REPORT) with the Phase 0/1 procedures filled; 2–5 are section stubs with TODO markers pointing at later stories."
---

## Description

Skeleton reference.md with all phase headings + schemas + the label-extraction JS template. Subsequent stories (S6-006..S6-011) fill in procedures per phase.

## Acceptance Criteria

1. `skills/ui-audit/reference.md` contains phase headings `## Phase 0` through `## Phase 6` (0 CONTEXT, 1 LOAD STATE, 2 DATA EXTRACTION, 3 CONSISTENCY + INVARIANTS, 4 QUALITY, 5 HEURISTICS, 6 REPORT).
2. Registry schema documented: fields `{ts, role, page, label, raw, parsed, hash, selector, tick, detail}` with `role` default `__default__`.
3. Label-extraction JS template present (the `pick()` payload from research doc §3.2).
4. Schemas for `.ui-audit.json` (invariants + event_invariants + role_invariants + role_leak_patterns).
5. Phase 0, 1 procedures fully written. Phases 2–6 are stubs with `<!-- procedures filled in S6-006 through S6-011 -->` markers.

## Implementation Notes

- Model on `skills/browse/reference.md` — split large pattern.
- Label-extraction template (verbatim from research doc §3.2):
  ```js
  (() => {
    const pick = (sel) => document.querySelector(sel)?.textContent.trim() ?? null;
    return { /* keys built from .ui-audit.json[page] */ };
  })()
  ```
- Append-safety note: domain-researcher confirms `>>` is safe for single-session writes; no `flock` needed (matches `crawl-ledger.jsonl` pattern).
- Hash idiom (library-researcher): use `sha256sum 2>/dev/null || shasum -a 256` with `cut -c1-8` — NOT `md5sum` (not portable on macOS).

## Dependencies

S6-001.
