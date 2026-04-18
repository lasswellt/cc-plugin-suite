---
id: S4-001
title: Add output_intensity to developer-profile schema + BLITZ_OUTPUT_INTENSITY env var
epic: E-005
capability: CAP-005
registry_id: cf-2026-04-18-output-intensity-profile
status: planned
github_issue: 10
priority: high
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/_shared/terse-output.md
  - skills/_shared/spawn-protocol.md
verify:
  - "grep -c 'output_intensity' skills/_shared/terse-output.md skills/_shared/spawn-protocol.md 2>/dev/null | awk -F: '{s+=$2} END{print s}' | xargs test 2 -le"
  - "grep -q 'BLITZ_OUTPUT_INTENSITY' skills/_shared/terse-output.md || grep -q 'BLITZ_OUTPUT_INTENSITY' skills/_shared/spawn-protocol.md"
done: output_intensity referenced in at least 2 files; BLITZ_OUTPUT_INTENSITY env var documented.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_caveman-full-absorption.md` Recommendation §Phase 4, persist output intensity as a first-class field in blitz's existing developer-profile infra rather than building caveman's flag-file + JS-hook apparatus. Also documents the `BLITZ_OUTPUT_INTENSITY` env-var override.

## Acceptance Criteria

1. `skills/_shared/terse-output.md` documents `output_intensity: lite|full|ultra` as a skill-frontmatter field (or developer-profile.json field) with `lite` as default.
2. `BLITZ_OUTPUT_INTENSITY` env override mentioned in either terse-output.md or spawn-protocol.md.
3. spawn-protocol.md §7 snippet (lines 313-319) updated so the canonical OUTPUT STYLE interpolates `<intensity>` from the active source (env → dev-profile → skill frontmatter → default `lite`).
4. Verify commands pass: grep counts ≥2 and env-var present.

## Implementation Notes

Schema extension — no developer-profile.json change required in this story (the field is implicit when user writes it; blitz's existing dev-profile reader in skills/retrospective already handles unknown fields gracefully). If the file exists in the repo, add a commented example showing `"output_intensity": "lite"`. If it doesn't exist, that's fine.

Key edits:
1. `skills/_shared/terse-output.md`: Add a new section "## Intensity override precedence" that documents: env `BLITZ_OUTPUT_INTENSITY` → `~/.cc-sessions/developer-profile.json` `output_intensity` → skill SKILL.md frontmatter `output_intensity` → default `lite`.
2. `skills/_shared/spawn-protocol.md` §7: Reference the precedence chain so Agent() prompts can interpolate the active intensity.

## Dependencies

None. First story of E-005.
