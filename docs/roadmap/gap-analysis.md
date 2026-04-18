**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Gap Analysis — Caveman Full Absorption

Current state of each capability against target. Measured 2026-04-18.

## Coverage snapshot

| Capability | Scope entry | Target | Current | Delivered | Coverage |
|---|---|---|---|---|---|
| CAP-001 | cf-terse-directive-agents | 6 | 0 | 0 | 0.00 |
| CAP-001 | cf-terse-directive-skill-gap | 6 (=31 total) | 25 | 0 | 0.00 |
| CAP-001 | cf-terse-directive-shared-protocols | 10 (=11 total) | 2 | 0 | 0.00 |
| CAP-002 | cf-compress-safe-references-wave2 | 7 | 0 | 0 | 0.00 |
| CAP-002 | cf-compress-research-docs | 12 | 0 | 0 | 0.00 |
| CAP-003 | cf-write-phase-directive-inserts | 8 | 0 | 0 | 0.00 |
| CAP-003 | cf-unsafe-ref-agent-prompt-injection | 7 | 0 | 0 | 0.00 |
| CAP-004 | cf-review-format-absorption | 2 | 0 | 0 | 0.00 |
| CAP-005 | cf-output-intensity-profile | 1 | 0 | 0 | 0.00 |
| CAP-005 | cf-lite-exemption-markers | 9 | 0 | 0 | 0.00 |
| CAP-005 | cf-task-type-gating (superseded) | 5 | 0 | 0 | 0.00 |
| CAP-005 | cf-activity-feed-message-rule | 1 | 0 | 0 | 0.00 |
| CAP-006 | cf-agent-prompt-boilerplate | 1 | 0 | 0 | 0.00 |
| CAP-007 | cf-spawn-protocol-warning-upgrade | 2 | 0 | 0 | 0.00 |

Aggregate: 0/14 entries at nonzero coverage. 100% greenfield work.

## Existing infrastructure (reusable, no new build)

- `skills/_shared/terse-output.md` — directive spec; target file for all reference-injection work.
- `skills/_shared/spawn-protocol.md:307-329` — §7 mandate + canonical 5-line OUTPUT STYLE snippet (ready to copy-paste into UNSAFE reference.md).
- `skills/compress/SKILL.md` — runtime `/blitz:compress` handles all file-compression scope items.
- `hooks/scripts/reference-compression-validate.sh` — structural validator fires on commit for compressed pairs.
- `sprints/sprint-1/STATE.md` — precedent for the UNSAFE-classification rule.
- `.cc-sessions/developer-profile.json` — schema extension target for CAP-005.

## New infrastructure required

- `skills/_shared/agent-prompt-boilerplate.md` — new shared fragment for CAP-006. Contents TBD during Phase 5 (extract from the 7 UNSAFE reference.md files' redundant sections).

## Out-of-scope (flagged for operator)

- Structural template rewrites for research (8-section mandate), roadmap (multi-artifact sprawl), doc-gen (prose-by-spec). Deferred per doc2 Finding 10. Separate roadmap item later.
- Older research docs (11 files pre-dating the 2026-04-18 work) not ingested in this roadmap run. If/when ingested, will require a second roadmap `extend` pass.
- `/blitz:commit-style` skill and `/blitz:pr-describe` skill — explicit SKIP per CAP-full-absorption doc Finding 7. No scope entries.
- Wenyan mode, multi-editor distribution, per-turn reinforcement hook, statusline badge — explicit SKIPs, same source.
