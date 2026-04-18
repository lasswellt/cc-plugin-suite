# Changelog

All notable changes to the blitz plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] — 2026-04-18

### Caveman Full Absorption

Delivers the full 14-entry caveman-absorption work plan tracked in `docs/_research/2026-04-18_caveman-full-absorption.md` and `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md`. Spans 4 sprints (Sprint 2-5) and 14 `/loop` ticks of autonomous sprint-plan/dev/review cycles. 12 of 14 registry entries landed complete; 2 dropped with documented reasons (preservation-boundary and supersede). Zero silent drops.

### Added

- **Terse-output directive coverage** across every load-bearing context (`agents/*.md` ×6, `skills/*/SKILL.md` ×31, `skills/_shared/*.md` ×11). Every context that spawns or reads instructions now cross-references `/_shared/terse-output.md`.
- **Runtime directive injection** at 8 SKILL.md write-phases (`research`, `sprint-plan`, `sprint-review`, `retrospective`, `roadmap`, `release`, `fix-issue`, `todo`). Inline 5-line Output-style block ensures generated artifacts default to terse prose rather than verbose defaults.
- **Caveman-review output format** in `skills/sprint-review/reference.md` and `skills/review/reference.md`. Finding pattern: `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes. `LGTM` short-circuit. Auto-clarity for security/CVE findings.
- **Intensity persistence**: `output_intensity: lite|full|ultra` documented in `developer-profile.json`, `BLITZ_OUTPUT_INTENSITY` env override, precedence chain in `skills/_shared/terse-output.md` and interpolated into `spawn-protocol.md` §7 snippet.
- **LITE-intensity exemption markers** on 9 safety/reasoning-sensitive skills (`completeness-gate`, `codebase-audit`, `research`, `retrospective`, `sprint-review`, `release`, `migrate`, `fix-issue`, `bootstrap`). Prevents brevity-induced accuracy degradation per Renze 2024 + Prompt-Compression-in-the-Wild evidence.
- **Agent-prompt boilerplate shared fragment** at `skills/_shared/agent-prompt-boilerplate.md`. Canonical source for HEARTBEAT, PARTIAL, weight-class caps, session-registration preambles. Pattern A delivery (author-time reference; inline preserved per Invariant 5 safety).
- **Sprint-review Phase 3.6 Invariant 5** enforces OUTPUT STYLE snippet presence in every UNSAFE agent-prompt `reference.md`. Any missing snippet → Critical finding → sprint FAILs.
- **Activity-feed message length rule** in `skills/_shared/verbose-progress.md`: `message` ≤ 200 chars (soft) / 300 chars (grep audit threshold), overflow moves to `detail`.
- **Scope-block ingestion** scripts: `scripts/parse-scope-to-registry.py` and `scripts/backfill-registry-parents.py`. Used by `/blitz:roadmap` Phase 1.1.5 and Phase 7 backfill.
- **New skill directory**: `skills/review/reference.md` (previously missing; bonus delivery via S3-003).

### Changed

- `skills/_shared/spawn-protocol.md:328` — enforcement clause upgraded from `WARNING (not BLOCKER)` to hard BLOCKER. Paired with sprint-review Invariant 5.
- `skills/_shared/terse-output.md` — added `## Intensity override precedence` section documenting env > dev-profile > skill > default resolution.
- 18 input files compressed author-time (`/blitz:compress`): 6 SAFE `reference.md` (wave 2) + 12 `docs/_research/*.md`. Aggregate reduction ~-1.5% (~4 KB), scope-block YAML preserved byte-identical in all 6 research docs with `scope:` frontmatter.

### Fixed

- `skills/completeness-gate/reference.md` flagged UNSAFE at compression time (contains load-bearing `## Grep Patterns by Check` heading). Registry entry `cf-2026-04-18-compress-safe-references-wave2` transitioned to `dropped` with preservation-boundary rationale rather than forcing a partial delivery.

### Dropped (terminal, documented)

- `cf-2026-04-18-compress-safe-references-wave2` (0.857 coverage) — completeness-gate's grep-pattern heading is load-bearing; compression risk exceeds ~0.3% saving.
- `cf-2026-04-18-task-type-gating` — superseded by `cf-2026-04-18-lite-exemption-markers` (per-section markers are strictly more expressive than whole-skill `output_style_policy`). Capability-index `dedup_log` pre-announced the supersede at plan time.

### Documentation

- `docs/_research/2026-04-18_caveman-full-absorption.md` — 9 scope entries, 7 capabilities mapped into the roadmap.
- `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` — 5 scope entries, documents the 0%-runtime-reach propagation gap and its phased fix.
- `docs/roadmap/` — full roadmap ingested from the 2 research docs: 7 capabilities, 3 domains, 4 phases, 7 epics, 14 carry-forward registry entries with parent.capability + parent.epic backfill.
- 5 sprint scaffolds under `sprints/sprint-{1..5}/` with manifest, stories, STATE, ac-coverage, summary, and review-report per sprint.
- 16 GitHub issues (#1-#16) created across Sprint 2-5 for story tracking.

### Registry Contract

Carry-forward registry format (`.cc-sessions/carry-forward.jsonl`) validated across:

- 14 unique IDs with full `created` → `correction` → `progress` → `complete|dropped` lifecycle.
- Zero silent drops across 5 sprints.
- Zero rollover escalations (rollover_count capped at 2; `deferred` events used for scheduled-to-later entries).
- `Invariant 5` self-tested on its own dogfood at Sprint 5 review (7/7 UNSAFE `reference.md` carry the required snippet).

### Release Metadata

- Tag range: `v1.4.1` → `v1.5.0`
- Commits: 37 on `main` (40f8bcf..HEAD)
- Contributors: 1 (lasswellt, automated via `/blitz:sprint --loop`)
- Issues closed: #1-#16 (all stories from Sprint 2-5)
- Research source: 2 April-18 research docs (full absorption + runtime propagation)

[1.5.0]: https://github.com/lasswellt/cc-plugin-suite/releases/tag/v1.5.0
[1.4.1]: https://github.com/lasswellt/cc-plugin-suite/compare/v1.4.0...v1.4.1
