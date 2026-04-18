---
id: S2-002
title: Add /_shared/terse-output.md reference to 6 remaining SKILL.md (ask, sprint, ship, next, health, todo)
epic: E-001
capability: CAP-001
registry_id: cf-2026-04-18-terse-directive-skill-gap
status: planned
github_issue: 2
priority: high
points: 1
depends_on: []
assigned_agent: doc-writer
files:
  - skills/ask/SKILL.md
  - skills/sprint/SKILL.md
  - skills/ship/SKILL.md
  - skills/next/SKILL.md
  - skills/health/SKILL.md
  - skills/todo/SKILL.md
verify:
  - "test $(grep -l '/_shared/terse-output.md' skills/*/SKILL.md | wc -l) -ge 31"
done: 31 SKILL.md files reference /_shared/terse-output.md (25 previously + 6 new in this story).
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

6 SKILL.md files produce user-facing output but lack the terse-output reference: `ask`, `sprint`, `ship`, `next`, `health`, `todo`. Per `docs/_research/2026-04-18_caveman-full-absorption.md` Finding 4, adding the reference to these 6 closes the substantive gap; remaining 3 (`implement`, `review`, `quick`) stay exempt as genuinely thin aliases.

## Acceptance Criteria

1. `skills/ask/SKILL.md`, `skills/sprint/SKILL.md`, `skills/ship/SKILL.md`, `skills/next/SKILL.md`, `skills/health/SKILL.md`, `skills/todo/SKILL.md` each contain a `/_shared/terse-output.md` reference.
2. Reference is in the Additional Resources section (or the nearest analog per existing structure of each file).
3. `grep -l '/_shared/terse-output.md' skills/*/SKILL.md | wc -l` returns ≥31 after the edits.

## Implementation Notes

Pattern to insert in the Additional Resources section of each SKILL.md:

```markdown
- For terse-output style directives, see [/_shared/terse-output.md](/_shared/terse-output.md)
```

Check each file's existing Additional Resources block format and match it. Do not re-add if already present (idempotency).

## Dependencies

None. Runs in parallel with S2-001.
