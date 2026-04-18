---
id: S5-001
title: Extract agent-prompt boilerplate into shared fragment; refactor 7 UNSAFE reference.md to reference it
epic: E-006
capability: CAP-006
registry_id: cf-2026-04-18-agent-prompt-boilerplate
status: planned
github_issue: 14
priority: high
points: 3
depends_on: []
assigned_agent: backend-dev
files:
  - skills/_shared/agent-prompt-boilerplate.md
  - skills/codebase-audit/reference.md
  - skills/codebase-map/reference.md
  - skills/code-sweep/reference.md
  - skills/integration-check/reference.md
  - skills/quality-metrics/reference.md
  - skills/sprint-dev/reference.md
  - skills/sprint-plan/reference.md
verify:
  - "test -f skills/_shared/agent-prompt-boilerplate.md"
  - "test $(grep -l 'agent-prompt-boilerplate' skills/*/reference.md | wc -l) -ge 7"
done: skills/_shared/agent-prompt-boilerplate.md exists; 7 UNSAFE reference.md reference the shared fragment.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_caveman-full-absorption.md` Recommendation Phase 3, extract redundant HEARTBEAT spec + PARTIAL protocol + weight-class cap tables + session-registration template from the 7 UNSAFE reference.md files into a shared fragment at `skills/_shared/agent-prompt-boilerplate.md`. Refactor each reference.md to reference (not copy) the shared fragment.

**Critical:** this refactor must NOT change the byte-resolved prompt sent to agents at spawn time. The shared fragment is an author-time deduplication; at spawn time the orchestrator reads both the reference.md and the shared fragment and splices them together. Target: ~20-30% reduction on the ~12 K tokens/sprint of Agent() prompt-template input.

## Acceptance Criteria

1. `skills/_shared/agent-prompt-boilerplate.md` exists and contains the de-duplicated content verbatim from the 7 UNSAFE reference.md files (HEARTBEAT, PARTIAL, weight-class caps, session-reg).
2. Each of the 7 UNSAFE reference.md files references `agent-prompt-boilerplate.md` via an explicit import marker (e.g., `<!-- import: /_shared/agent-prompt-boilerplate.md -->` or a markdown link with instructions to Read).
3. Parity verification: dump the resolved prompt for one representative sprint-dev Agent() spawn (pre-refactor vs post-refactor) and diff — must be byte-identical or differ only on whitespace.
4. `grep -l 'agent-prompt-boilerplate' skills/*/reference.md | wc -l` returns ≥7.

## Implementation Notes

Spawn a dedicated agent for this work (similar to Sprint 3 S3-002 pattern). The agent should:

1. Read all 7 UNSAFE reference.md files. Identify the repeated sections (HEARTBEAT, PARTIAL, weight-class caps, session-reg template). These are typically 15-30 lines each, repeated across files.
2. Extract the common content to `skills/_shared/agent-prompt-boilerplate.md`. Use distinct section headers (`## HEARTBEAT protocol`, `## PARTIAL transcript protocol`, etc.) so orchestrator skills can reference specific sections.
3. For each of the 7 reference.md files, replace the inline copy with an import marker and a brief local note. Example pattern:
   ```markdown
   ## HEARTBEAT Protocol
   <!-- import: /_shared/agent-prompt-boilerplate.md#heartbeat-protocol -->
   See [/_shared/agent-prompt-boilerplate.md](/_shared/agent-prompt-boilerplate.md) §HEARTBEAT Protocol.
   ```
4. Orchestrator skills that dynamically assemble agent prompts must be updated to resolve these imports at spawn time. (Existing orchestrators already Read the reference.md; adding a secondary Read for the shared fragment is a ~2-line change per orchestrator.)
5. Parity test: for one sprint-dev agent spawn, capture the full resolved prompt text pre- and post-refactor. Diff them.

**Safety:** if import resolution is non-trivial (orchestrator changes exceed ~50 lines of skill edits), downgrade the story to "extract fragment only, leave references copy-paste for now" and carry-forward the import-refactor portion.

## Dependencies

None. Parallel to S5-002 and S5-003.
