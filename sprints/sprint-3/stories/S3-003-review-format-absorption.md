---
id: S3-003
title: Adopt caveman-review output format in sprint-review + review reference.md
epic: E-004
capability: CAP-004
registry_id: cf-2026-04-18-review-format-absorption
status: done
github_issue: 8
priority: high
points: 2
depends_on: []
assigned_agent: doc-writer
files:
  - skills/sprint-review/reference.md
  - skills/review/reference.md
verify:
  - "test $(grep -l 'L<line>\\|🔴 bug\\|🟡 risk\\|🔵 nit\\|LGTM' skills/review/reference.md skills/sprint-review/reference.md | wc -l) -ge 2"
done: Both review reference.md files use the caveman-review finding format (`L<line>: <severity> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes, LGTM rule, auto-clarity for security).
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_caveman-full-absorption.md` Recommendation Phase 5, adopt caveman's line-level review-finding format in both `skills/review/reference.md` and `skills/sprint-review/reference.md`. This is the highest-leverage output-format edit in the Phase-2 scope (per research doc Finding 5 — sprint-review findings are the most re-read artifact per cycle).

## Acceptance Criteria

1. Both `skills/review/reference.md` and `skills/sprint-review/reference.md` document the `L<line>: <severity-prefix> <problem>. <fix>.` format as the mandatory per-finding shape.
2. Severity prefixes documented: 🔴 (bug / critical), 🟡 (risk / major), 🔵 (nit / minor), ❓ (question / info).
3. `LGTM` short-circuit rule documented: if no findings, reviewer writes `LGTM` and stops (not a multi-line "nothing to report").
4. Auto-clarity exemption documented: security / CVE-class findings drop terse format, write full prose explanation + reference.
5. `grep -l 'L<line>\|🔴 bug\|🟡 risk\|🔵 nit\|LGTM' skills/review/reference.md skills/sprint-review/reference.md | wc -l` returns ≥2.
6. Diff of one post-Sprint-3 sprint-review-report against a Sprint-2 review-report shows the new format applied; manual spot-check of readability.

## Implementation Notes

Source: `skills/caveman-review/SKILL.md` in the upstream caveman repo (already summarized in `docs/_research/2026-04-18_caveman-full-absorption.md` Finding 1 row). Key rules to absorb:

- Format: `L<line>: <problem>. <fix>.` (single-file) or `<file>:L<line>: <problem>. <fix>.` (multi-file).
- Severity prefix: 🔴 bug / 🟡 risk / 🔵 nit / ❓ q.
- Drop: "I noticed", "It seems", "You might consider", praise-per-comment, restating what the line does, hedging.
- Keep: exact line numbers, identifiers in backticks, concrete fix, why only when non-obvious.
- `LGTM` if nothing to report; stop there.
- Auto-clarity for security (CVE-class), architectural disagreements, onboarding contexts.

Rewrite the existing finding-template sections in both reference.md files to adopt these rules. Preserve structural headers (`### Critical`, `### Major`, etc.) since downstream parsers grep them — only the per-finding shape changes.

## Dependencies

None. Parallel to S3-001 and S3-002.
