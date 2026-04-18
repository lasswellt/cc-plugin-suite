---
id: S2-003
title: Cross-reference /_shared/terse-output.md from 10 shared protocol files
epic: E-001
capability: CAP-001
registry_id: cf-2026-04-18-terse-directive-shared-protocols
status: done
github_issue: 3
priority: medium
points: 1
depends_on: []
assigned_agent: doc-writer
files:
  - skills/_shared/verbose-progress.md
  - skills/_shared/session-protocol.md
  - skills/_shared/checkpoint-protocol.md
  - skills/_shared/context-management.md
  - skills/_shared/deviation-protocol.md
  - skills/_shared/definition-of-done.md
  - skills/_shared/scheduling.md
  - skills/_shared/carry-forward-registry.md
  - skills/_shared/session-report-template.md
  - skills/_shared/spawn-protocol.md
verify:
  - "test $(grep -l 'terse-output' skills/_shared/*.md | wc -l) -ge 11"
done: 11 shared protocol files cross-reference terse-output.md (including terse-output.md itself).
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

10 shared protocols under `skills/_shared/` govern output-bearing behavior but don't cross-reference the terse-output directive today. Add a "Related protocols" footer to each so the directive is discoverable from anywhere a shared protocol is loaded.

## Acceptance Criteria

1. Each of the 10 listed shared protocols contains `terse-output` string.
2. Reference appears in a "Related protocols" section (or nearest analog) near the bottom of the file.
3. `grep -l 'terse-output' skills/_shared/*.md | wc -l` returns ≥11 (the 10 new + terse-output.md itself).
4. `spawn-protocol.md` already references terse-output — verify the existing reference is preserved; do not duplicate.

## Implementation Notes

Footer pattern for each file:

```markdown
## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive referenced by this protocol.
```

Some files may already have a "Related" or "See also" section — append rather than duplicate the section header.

## Dependencies

None. Runs in parallel with S2-001 and S2-002.
