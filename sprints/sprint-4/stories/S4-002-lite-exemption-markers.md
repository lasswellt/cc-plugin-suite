---
id: S4-002
title: Add LITE-intensity exemption markers to 9 reasoning/safety-sensitive skills
epic: E-005
capability: CAP-005
registry_id: cf-2026-04-18-lite-exemption-markers
status: planned
github_issue: 11
priority: high
points: 2
depends_on: []
assigned_agent: doc-writer
files:
  - skills/completeness-gate/SKILL.md
  - skills/codebase-audit/SKILL.md
  - skills/research/SKILL.md
  - skills/retrospective/SKILL.md
  - skills/sprint-review/SKILL.md
  - skills/release/SKILL.md
  - skills/migrate/SKILL.md
  - skills/fix-issue/SKILL.md
  - skills/bootstrap/SKILL.md
verify:
  - "test $(grep -l 'LITE intensity\\|Terse exemptions\\|lite-only' skills/completeness-gate/SKILL.md skills/codebase-audit/SKILL.md skills/research/SKILL.md skills/retrospective/SKILL.md skills/sprint-review/SKILL.md skills/release/SKILL.md skills/migrate/SKILL.md skills/fix-issue/SKILL.md skills/bootstrap/SKILL.md | wc -l) -ge 9"
done: 9 skills carry a LITE-intensity marker naming the specific sections that stay at lite (full prose + reasoning chain preserved) while the rest of the skill output runs full terse.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` Finding 6, 9 skills produce sections where aggressive compression harms correctness (security findings, root-cause chains, breaking-change entries, never-auto-apply rationale). Per Renze 2024 + Prompt-Compression-in-the-Wild evidence, these sections must stay at LITE intensity (full sentences, reasoning chain preserved).

This story supersedes `cf-task-type-gating` — per-section markers are the preferred approach over whole-skill policy. S4-003 will transition cf-task-type-gating to `dropped` status after this story lands.

## Acceptance Criteria

Per-skill LITE markers:

| Skill | Section(s) requiring LITE |
|---|---|
| completeness-gate | severity:critical + category:security `message` field |
| codebase-audit | security-pillar risk narratives |
| research | §7 Risks + Open Questions |
| retrospective | Never-Auto-Apply classification rationale |
| sprint-review | critical/major finding explanations |
| release | breaking-change entries |
| migrate | breaking-change step explanations |
| fix-issue | Root Cause field |
| bootstrap | destructive-op confirmations |

For each skill, the marker names the section and states "LITE intensity" or "Terse exemptions". Canonical pattern to insert near the write-phase block (close to the S3-001 directive):

```markdown
**Terse exemptions (LITE intensity):** <section name>. Full sentences + reasoning chain required. Resume terse on next section.
```

Verify: `grep -l 'LITE intensity\|Terse exemptions\|lite-only' <9 skills>/SKILL.md` returns 9.

## Implementation Notes

Edit each of the 9 SKILL.md files. Place the exemption marker immediately after (or within) the S3-001 `**Output style:**` block so the intensity override is context-adjacent.

## Dependencies

None. Parallel to S4-001, S4-004.
