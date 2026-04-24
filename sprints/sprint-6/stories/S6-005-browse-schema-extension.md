---
id: S6-005
title: "Add page_data_registry field to browse/reference.md latest-tick.json schema"
epic: E-008
capability: CAP-009
status: done
priority: P1
points: 1
depends_on: []
assigned_agent: infra-dev
files:
  - skills/browse/reference.md
verify:
  - "grep -q 'page_data_registry' skills/browse/reference.md"
done: "browse/reference.md latest-tick.json schema documents the `page_data_registry` field (path string, optional)."
---

## Description

1-line addition to browse's state schema so ui-audit can detect prior extraction passes and browse can observe ui-audit's output.

## Acceptance Criteria

1. `skills/browse/reference.md` `latest-tick.json` schema block (near line 512 per codebase-analyst research) documents a new top-level field:
   ```
   page_data_registry: string | null  // Path to docs/crawls/page-data-registry.jsonl if ui-audit has run in this project; null otherwise.
   ```
2. No other browse behavior changes. Browse does not read/write this field — ui-audit owns it.

## Implementation Notes

- Read `skills/browse/reference.md` to locate the latest-tick.json schema block. Insert the new field in alphabetical position (after `mode` or similar) with a terse one-line doc comment.
- This story is independent of S6-001..S6-004 (different file). Can run in parallel.

## Dependencies

None.
