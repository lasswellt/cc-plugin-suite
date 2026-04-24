---
id: S6-001
title: "Scaffold skills/ui-audit/SKILL.md with frontmatter, argument parsing, Phase 0"
epic: E-008
capability: CAP-008
status: planned
priority: P0
points: 3
depends_on: []
assigned_agent: infra-dev
files:
  - skills/ui-audit/SKILL.md
verify:
  - "test -f skills/ui-audit/SKILL.md"
  - "grep -q '^name: ui-audit$' skills/ui-audit/SKILL.md"
  - "grep -q '^model: opus' skills/ui-audit/SKILL.md"
  - "grep -q '^effort: low' skills/ui-audit/SKILL.md"
  - "grep -q 'ToolSearch' skills/ui-audit/SKILL.md"
  - "grep -qE 'argument-hint:.*full.*smoke.*data.*buttons.*events.*consistency.*heuristics.*role.*--loop' skills/ui-audit/SKILL.md"
done: "SKILL.md loads without error, Phase 0 session-register runs, argument parser recognizes all 9 declared modes."
---

## Description

Create the ui-audit skill entry point. Frontmatter: `model: opus` + `effort: low` (opus survives `[1m]` parent; effort caps orchestrator spend — see research doc §6.1). Argument parser for 9 modes. Phase 0 session register copied verbatim from `browse/SKILL.md:47-51`.

## Acceptance Criteria

1. `skills/ui-audit/SKILL.md` exists with 6-field frontmatter in canonical order: `name`, `description`, `allowed-tools`, `model`, `compatibility`, `argument-hint`. Add `effort: low` between `model` and `compatibility`.
2. `allowed-tools` includes `ToolSearch` (required for dynamic Playwright MCP load).
3. `!${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` detect-stack block present (line 11 pattern).
4. Phase 0 CONTEXT contains session-registration boilerplate per `/_shared/session-protocol.md` + `/_shared/verbose-progress.md`.
5. Argument parser recognizes 9 modes: `full`, `smoke`, `data`, `buttons`, `events`, `consistency`, `heuristics`, `role <name>`, `--loop`. Unknown mode → error with usage message.
6. Loading the skill in a test session prints `[ui-audit] Phase 0: session <id>` without error.

## Implementation Notes

- Frontmatter template (copy + adapt):
  ```yaml
  ---
  name: ui-audit
  description: "Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts labeled value registry, asserts invariants, flags placeholders/nulls/flapping values. Read-only. Loop-safe."
  allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
  model: opus
  effort: low
  compatibility: ">=2.1.50"
  argument-hint: "[mode] -- modes: full | smoke | data | buttons | events | consistency | heuristics | role <name> | --loop"
  ---
  ```
- **`effort: low` note:** library-researcher found no prior use of `effort:` in this repo's 34 SKILL.md files, but Claude Code docs confirm support (https://code.claude.com/docs/en/model-config.md#adjust-effort-level). This sprint is the first adoption. If Claude Code version at author time does not parse `effort:`, strip the line and document the version gap in a sprint-review finding; do NOT silently drop.
- Phase 0 body: copy `skills/browse/SKILL.md:47-51` verbatim (session register + verbose-progress + activity-feed `skill_start` event).
- Argument parser: follow `browse/SKILL.md` Phase 0 argument-table pattern (lines 53-61). Store `MODE` for downstream phases.

## Dependencies

None — this is the bootstrap story.
