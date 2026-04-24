---
id: S6-002
title: "Register ui-audit in skill-registry.json + add session-protocol conflict rows"
epic: E-008
capability: CAP-008
status: done
priority: P0
points: 1
depends_on: [S6-001]
assigned_agent: infra-dev
files:
  - .claude-plugin/skill-registry.json
  - skills/_shared/session-protocol.md
verify:
  - "jq -e '.skills[] | select(.name==\"ui-audit\")' .claude-plugin/skill-registry.json >/dev/null"
  - "jq -e '.skills[] | select(.name==\"ui-audit\") | .model == \"opus\" and .modifies_code == false and .category == \"quality\"' .claude-plugin/skill-registry.json >/dev/null"
  - "grep -c 'ui-audit' skills/_shared/session-protocol.md | awk '{exit ($1 >= 3) ? 0 : 1}'"
done: "skill-registry entry validates via jq schema checks; conflict matrix has 3 ui-audit rows (self/browse-loop/sprint-dev)."
---

## Description

Register ui-audit for discoverability + declare session conflicts.

## Acceptance Criteria

1. `.claude-plugin/skill-registry.json` contains a `ui-audit` entry with all 9 mandatory fields: `name`, `category` (`quality`), `description`, `model` (`opus`), `modifies_code` (`false`), `uses_agents` (`true`), `uses_sessions` (`true`), `dependencies` (`["browse"]`), `maturity` (`experimental`).
2. `skills/_shared/session-protocol.md` conflict matrix gains 3 rows for ui-audit:
   - `ui-audit × ui-audit` = BLOCK (same-session clash)
   - `ui-audit × browse (loop)` = WARN (both write `docs/crawls/`)
   - `ui-audit × sprint-dev` = OK (read-only analysis)
3. Row format matches existing table format in `session-protocol.md:215-250`.

## Implementation Notes

- Registry entry template — mirror `browse`'s entry byte-for-byte except for field values.
- `dependencies: ["browse"]` because ui-audit reads `docs/crawls/*` state written by browse (soft dep — ui-audit falls back to lightweight internal crawl when state absent, per CAP-008 AC7).
- Conflict matrix: read the file, locate the pipe-table, append 3 rows in alphabetical position.

## Dependencies

S6-001 — SKILL.md must exist first so the registry entry's `description` matches the SKILL.md frontmatter.
