**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Domain — Output Shaping

## Capabilities

- **CAP-004** — Caveman-review output format in sprint-review + review (Phase 2)
- **CAP-005** — Intensity persistence + LITE exemption markers + activity-feed rule (Phase 3)

## Mission

Shape what the skills actually emit at runtime — not just whether the terse directive is present (that's directive-propagation), but what format and intensity the output takes. Two thrusts:

1. **Review format** (CAP-004) — absorb caveman-review's `L<line>: <severity-prefix> <problem>. <fix>.` pattern with 🔴/🟡/🔵/❓ prefixes and LGTM short-circuit. Sprint-review findings are the most re-read artifact per cycle; single highest-leverage output-format change.
2. **Intensity gating** (CAP-005) — per-section LITE markers on 9 reasoning/safety-sensitive skills (security findings, root-cause chains, breaking-change entries, never-auto-apply rationale). Supersedes the whole-skill `output_style_policy` approach from CAP-full-absorption doc's Finding 8 (see capability-index dedup log).

## Existing modules

- `skills/sprint-review/reference.md` — CAP-004 primary edit target
- `skills/review/reference.md` — CAP-004 secondary edit target
- `.cc-sessions/developer-profile.json` — CAP-005 schema-extension target
- `skills/_shared/verbose-progress.md` — CAP-005 activity-feed rule target
- Target skills for LITE markers: completeness-gate, codebase-audit, research, retrospective, sprint-review, release, migrate, fix-issue, bootstrap

## No new modules

All edits are additive in-place to existing files.

## Safety invariant

LITE markers must preserve reasoning chains. Per Renze 2024 (math degradation) and Prompt-Compression-in-the-Wild (code-gen harm) cited in the source research docs, over-compressing security findings, root-cause chains, or breaking-change explanations actively harms output correctness. Story E005-S02 specifies which sections per skill get the marker; Story E005-S03 transitions the superseded cf-task-type-gating entry to `dropped` so the registry doesn't show two ways to accomplish the same thing.
