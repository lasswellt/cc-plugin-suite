---
id: S5-003
title: Add sprint-review Phase 3.6 Invariant 5 for OUTPUT STYLE snippet enforcement
epic: E-007
capability: CAP-007
registry_id: cf-2026-04-18-spawn-protocol-warning-upgrade
status: planned
github_issue: 16
priority: high
points: 1
depends_on: [S5-002]
assigned_agent: doc-writer
files:
  - skills/sprint-review/SKILL.md
verify:
  - "grep -c 'Invariant 5' skills/sprint-review/SKILL.md | xargs test 1 -le"
done: sprint-review/SKILL.md Phase 3.6 documents Invariant 5 (OUTPUT STYLE snippet required in every Agent() prompt template).
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Pair story to S5-002. After spawn-protocol.md declares the check a BLOCKER, sprint-review must actually enforce it at Phase 3.6. Add Invariant 5 that fails any sprint whose Agent() prompt templates lack the OUTPUT STYLE snippet.

## Acceptance Criteria

1. `skills/sprint-review/SKILL.md` Phase 3.6 section contains an `### Invariant 5` subsection.
2. Invariant 5 describes: grep the 7 UNSAFE reference.md files (or any other files containing agent prompts) for the canonical OUTPUT STYLE snippet; fail if any prompt lacks it.
3. Invariant 5 documented hard-gate: counts as a Critical finding, sprint → FAIL (not CONDITIONAL).
4. Verify: `grep -c 'Invariant 5' skills/sprint-review/SKILL.md` returns ≥1.

## Implementation Notes

Insert the new subsection after existing Invariant 4 in sprint-review/SKILL.md Phase 3.6. Canonical template:

```markdown
### 3.6.7 Invariant 5 — Agent-Prompt Output Style Snippet

Every agent-prompt template MUST inject the spawn-protocol §7 OUTPUT STYLE snippet. Since Sprint 3 S3-002, the 7 UNSAFE reference.md files all comply; this invariant enforces no regression.

For every file under `skills/*/reference.md`:

- Scan for agent-prompt blocks (heuristic: contains "You are X" or appears in a fenced code block referenced by an Agent() spawn template).
- Verify each block contains: `OUTPUT STYLE: <intensity> per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: ...`
- Missing snippet → Critical finding. Sprint → FAIL.

This replaces the prior WARNING-only check (see spawn-protocol.md §7 enforcement clause — updated in Sprint 5 S5-002).
```

## Dependencies

- S5-002 (upgrade WARNING → BLOCKER in spawn-protocol.md must land first so the sprint-review Invariant 5 aligns with the source enforcement declaration).
