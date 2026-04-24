# Changelog

All notable changes to the blitz plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] — 2026-04-23

### ui-audit — Continuous Cross-Page Consistency & UX Auditor

New skill `blitz:ui-audit` fills a gap no mainstream tool covers: semantic cross-page data consistency ("dashboard says 47, list page says 46" detection). Visual-regression tools (Percy, Chromatic, Applitools) explicitly mask numeric changes as noise. This skill extracts labeled values via Playwright MCP `browser_evaluate`, persists to an append-only registry, and asserts invariants across pages, roles, events, and interactive elements.

Delivered across 3 sprints (Sprint 6–8) and 35 stories. Research: `docs/_research/2026-04-23_ui-audit-skill.md`. All 5 epics closed (E-008 foundation + E-009 quality/heuristics + E-010 interactive + E-011 events + E-012 role matrix).

### Added

- **`blitz:ui-audit` skill** (`skills/ui-audit/`) — SKILL.md + reference.md + CHECKS.md + PATTERNS.md + tests/. 9 modes: `full`, `smoke`, `data`, `buttons`, `events`, `consistency`, `heuristics`, `role <name>`, `--loop`. Opus orchestrator + effort:low + sonnet Agent workers for parallel heuristic scans when pages >30.
- **Labeled-value registry** at `docs/crawls/page-data-registry.jsonl` — append-only, latest-wins-by-`(role, page, label)` via `jq group_by`. Reader protocol excludes 10 finding-label families to prevent feedback on re-run.
- **Cross-page invariants** — `.ui-audit.json` declares `invariants` (`equal`/`gte`/`lte` with tolerance), `event_invariants` (`required_props`/`forbidden_props`/`scope`), `role_invariants` (`equal`/`viewer_null`/`gte`), plus `totals` parent/child sums, `placeholder_patterns`, `role_leak_patterns`.
- **Interactive element coverage** — enumerates every ARIA-role + native interactive element per page; runs 6 static checks (NO_LABEL, DEAD_HREF, EMPTY_HANDLER, TABINDEX_POSITIVE, TABINDEX_NEGATIVE_VISIBLE, NO_FOCUS_STATE) + destructive-classifier-gated safe-click pass + CLICK_ERROR capture.
- **Analytics event consistency** — 3-layer interception (`window.dataLayer` push proxy + `navigator.sendBeacon` wrap + network filter for Segment/PostHog/Amplitude/GA4). Cross-page event drift detection + `event_invariants` with 20-key PII auto-escalation list (CRITICAL on `user_email`/`password`/`ssn`/`token`/etc leaked in analytics).
- **Per-permissions-role audit matrix** — 5 roles (anonymous/viewer/member/admin/superadmin) via env-var credentials, scripted login with R9 sentinel check after every role transition, storageState harvest at `.auth/<role>.json`, HTML-source role-leak scan. Loop matrix = `(role, page)` per tick, 2-pass termination, R10 ETA gate (`--yes`/`--ci` bypass on >60min runs).
- **6 data-quality flags**: NULL_VALUE + PLACEHOLDER + NEGATIVE_COUNT (inline Phase 2) + FORMAT_MISMATCH + STALE_ZERO + BROKEN_TOTAL (Phase 4 reducers).
- **Vercel Web Interface Guidelines heuristics** — Category 9 (URL reflects filter/tab/pagination state, consumes click records) + Category 16 (NUMERIC_COLUMN_NOT_TABULAR via `getComputedStyle(cell).fontVariantNumeric` + WRITTEN_OUT_COUNT regex scan).
- **Self-contained fixture test** (`skills/ui-audit/tests/run-fixture.sh`) — python3 static server + synthetic HTML fixture + shell assertions for 6 numeric + 3 interactive + 2 event + 4 quality + 2 heuristic scenarios. Runs without Claude Code or Playwright MCP.
- **Phase 7 LOOP MATRIX** — role×page cursor persisted in `docs/crawls/latest-tick.json.ui_audit_matrix`; `matrix_idle: true` after pass-2 completion.
- **Prompt-injection defense** on Phase 5 sonnet worker spawn — page-key sanitization at config-load (reject control chars) + `---BEGIN/END PAGE LIST---` delimiters with literal-interpretation framing in prompt.

### Changed

- `skills/browse/reference.md` — `latest-tick.json` schema gains `page_data_registry` field so browse can observe ui-audit state in one read.
- `skills/_shared/session-protocol.md` — conflict matrix adds 3 ui-audit rows (BLOCK self / WARN vs browse-loop / OK vs sprint-dev).
- `.claude-plugin/skill-registry.json` — ui-audit entry, category `quality`, `dependencies: ["browse"]`, `maturity: "experimental"`.
- `skills/sprint-review/SKILL.md` — Invariant 5 floor bumped 7→8 (ui-audit/reference.md carries an agent-prompt template).
- Plugin skill count: 33 → 35 (ui-audit; one skill-review housekeeping).

### Fixed

Review auto-fixes that landed this cycle and hardened the design:

- Fixture `awk /dev/stdin <<<"$HTML"` bug — would silently null-out interactive assertions on WSL (sprint-7 pattern review).
- Safety-rule verb-list divergence — SKILL.md Rule 1 and `DESTRUCTIVE_LABELS` regex now share the full 24-verb list (sprint-7 security review).
- `--yes` / `--ci` arg-parse gap — ETA-gate flags now documented in Phase 0.1 mode table with explicit env-var export (sprint-7 security review).
- dataLayer proxy circular-ref crash — wrapped in try/catch; original `_push` always called last (sprint-7 security review).
- PII auto-escalation list expanded from 8 → 20 keys with substring match (`phone`, `address`, `dob`, `ip_address`, passport, reset codes, etc).
- Phase 3 reducer exclude-label divergence — CONSISTENCY + FLAPPING reducers now share the 10-label canonical exclude set (sprint-8 pattern review).
- URL-token capture in Cat 9 findings — `scrub_url` helper redacts `token|session|auth|key|secret|password|reset|code|nonce|state|access_token|refresh_token` values before emission; state-change signal preserved via symmetric redaction (sprint-8 security review).
- Worker malformed-JSON silent-drop — Phase 5 coordinator now validates each spawned worker's output with `jq -c '.'` and preserves malformed output as `.malformed.<ts>` with CONFIG_ERROR (sprint-8 security review).
- placeholder_patterns ReDoS guard — rejects patterns >200 chars or containing nested quantifiers at config-load (sprint-8 housekeeping).

### Closed capabilities

9 new capabilities (CAP-008..CAP-016), all tracked in `docs/roadmap/capability-index.json`:

| ID | Title |
|---|---|
| CAP-008 | Scaffold skills/ui-audit/ |
| CAP-009 | Page data extraction + labeled-value registry |
| CAP-010 | Consistency + invariant evaluator + FLAPPING/STALE/NULL_TRANSITION |
| CAP-011 | Data-quality flags (6 flags, 3 reducers + 3 inline) |
| CAP-012 | UI/UX heuristic audit (Vercel Cat 9 + 16) |
| CAP-013 | Reporter (markdown + stdout + activity-feed) |
| CAP-014 | Interactive element coverage (buttons/links/tabs) |
| CAP-015 | Analytics event consistency |
| CAP-016 | Per-permissions-role audit matrix |

---

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
