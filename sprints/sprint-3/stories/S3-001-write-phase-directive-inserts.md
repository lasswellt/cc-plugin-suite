---
id: S3-001
title: Insert 5-line Output-style block at 8 SKILL.md write-phase locations
epic: E-003
capability: CAP-003
registry_id: cf-2026-04-18-write-phase-directive-inserts
status: done
github_issue: 6
priority: high
points: 2
depends_on: []
assigned_agent: doc-writer
files:
  - skills/research/SKILL.md
  - skills/sprint-plan/SKILL.md
  - skills/sprint-review/SKILL.md
  - skills/retrospective/SKILL.md
  - skills/roadmap/SKILL.md
  - skills/release/SKILL.md
  - skills/fix-issue/SKILL.md
  - skills/todo/SKILL.md
verify:
  - "test $(grep -l '\\*\\*Output style:\\*\\* terse-technical' skills/*/SKILL.md | wc -l) -ge 8"
done: 8 SKILL.md files contain the inline 5-line Output-style block at their Generate/Write phase.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK. Preserve code/paths/YAML verbatim.

## Description

Per `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` Phase A.1, the passive `terse-output.md` reference in Additional Resources does not propagate to runtime artifact generation. Each skill's Generate/Write phase must re-assert the directive inline so Claude interpolates it into the output prompt when producing research docs, review reports, retrospective proposals, etc.

## Acceptance Criteria

1. Each of the 8 listed SKILL.md files contains a block matching: `**Output style:** terse-technical per /_shared/terse-output.md. …` in the phase that writes user-facing prose artifacts.
2. `grep -l '\*\*Output style:\*\* terse-technical' skills/*/SKILL.md | wc -l` returns ≥8.
3. The block names compressible vs preserve-verbatim subsurfaces for the specific artifact each skill produces (e.g., research-skill block mentions Summary/Findings/Recommendation as compressible; scope YAML as preserved).

## Implementation Notes

Canonical 5-line block (adapt per-skill as needed):

```markdown
**Output style:** terse-technical per `/_shared/terse-output.md`. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, paths, commands, grep patterns, YAML/JSON, tables, error codes, dates, versions. No preamble, no trailing summary. Fragments OK. Intensity: `lite` (user-facing) or `full` (agent-internal). Auto-pause for security/irreversible/root-cause sections.
```

Per-skill insertion points (from research doc §A.1 table):

| File | Location |
|---|---|
| skills/research/SKILL.md | Before "Use the template" at Phase 3.1 doc-synthesis |
| skills/sprint-plan/SKILL.md | Before story body list at Phase 3.2 |
| skills/sprint-review/SKILL.md | Before "Write the review report" at Phase 4.1 |
| skills/retrospective/SKILL.md | Before proposals template at Phase 2 |
| skills/roadmap/SKILL.md | Before gap-analysis write at Phase 2.3 |
| skills/release/SKILL.md | Before release-notes HEREDOC at Phase 3.3 |
| skills/fix-issue/SKILL.md | Before comment template at Phase 4.2; also rewrite "1-2 sentence" fields to "1 fragment" |
| skills/todo/SKILL.md | Adds Additional-Resources link + directive block (currently has neither) |

## Dependencies

None. Parallel to S3-002 and S3-003.
