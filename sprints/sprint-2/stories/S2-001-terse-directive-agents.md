---
id: S2-001
title: Add /_shared/terse-output.md reference to 6 agent definition files
epic: E-001
capability: CAP-001
registry_id: cf-2026-04-18-terse-directive-agents
status: planned
github_issue: 1
priority: high
points: 1
depends_on: []
assigned_agent: doc-writer
files:
  - agents/architect.md
  - agents/backend-dev.md
  - agents/doc-writer.md
  - agents/frontend-dev.md
  - agents/reviewer.md
  - agents/test-writer.md
verify:
  - "test $(grep -l 'terse-output' agents/*.md | wc -l) -eq 6"
done: All 6 agent files contain a `/_shared/terse-output.md` reference; grep returns exactly 6 matches.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Agent definition files load on every `Agent(subagent_type: blitz:<role>)` spawn. Currently 0/6 reference the terse-output directive — the largest single directive-coverage gap identified in Finding 4 of `docs/_research/2026-04-18_caveman-full-absorption.md`. Add one line per file pointing to `/_shared/terse-output.md`.

## Acceptance Criteria

1. Every file in `agents/*.md` (architect, backend-dev, doc-writer, frontend-dev, reviewer, test-writer) contains the string `terse-output`.
2. Reference line placed in the file's Additional Resources / Style section (near top, below any existing frontmatter).
3. No other edits — line-count delta per file should be +1 to +2.

## Implementation Notes

Insert this line near the top of each agent file (below frontmatter if present):

```markdown
**Output style:** terse-technical per [/_shared/terse-output.md](/_shared/terse-output.md). Preserve code, paths, commands, YAML/JSON verbatim. Fragments OK.
```

## Dependencies

None. First story of E-001.
