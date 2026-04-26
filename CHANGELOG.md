# Changelog

All notable changes to the blitz plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0] — 2026-04-26

### Skill Suite Overhaul to Anthropic-Canonical Conventions

A full review of all 36 skills against Anthropic's official Skill authoring guidance (`code.claude.com/docs/en/skills`, `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`, `github.com/anthropics/skills`) and the production carry-forward / sprint-family contracts. Every skill now satisfies a single canonical contract enforced by a new lint hook.

### Breaking

- **Removed `.claude-plugin/skill-registry.json`** — non-canonical per Anthropic; skills are now auto-discovered from `skills/<name>/SKILL.md`. The only consumer (`skills/health/SKILL.md` Phase 3.1) was rewritten to walk SKILL.md files directly via the new lint hook.

### Added

- **`skills/_shared/story-frontmatter.md`** (NEW) — single canonical YAML schema for sprint stories. Producer/consumer matrix (sprint-plan writes; sprint-dev/sprint-review read). Validation algorithm (sprint-dev Phase 0). Closes the producer/consumer drift that contributed to the CAP-133 carry-forward incident.
- **`skills/_shared/state-handoff.md`** (NEW) — pipeline contracts for every artifact passed between bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship. Documents the producer/consumer/required-by table and the Phase 0 input-validation pattern.
- **`skills/_shared/carry-forward-registry.md`** §Reader Algorithm — single executable script that consolidates Invariants 1, 2, 4 + rollover-ceiling escalation. Sprint-plan / sprint-review / roadmap / dashboards now shell out to one canonical implementation; thresholds no longer drift across skills.
- **`skills/_shared/spawn-protocol.md`** §8 Agent Output Contract — unified SUCCESS / PARTIAL / MALFORMED / EMPTY / MISSING / TIMEOUT classifications and standard gate thresholds (N=1 → ABORT @ 1; N=2-3 → ABORT @ 2; N≥4 → ABORT @ ⌈N/2⌉). PARTIAL retry policy. Validator script. Skills that spawn agents now share one threshold table.
- **`skills/_shared/terse-output.md`** §Canonical Exemptions List — single authoritative list of sections that always use full prose (Safety, Root Cause, Risks, Destructive ops, First-time onboarding, Migration notices). Skills must not redefine the exemption set.
- **`hooks/scripts/skill-frontmatter-validate.sh`** (NEW) — Anthropic-canonical lint. Checks required frontmatter fields, name length (≤64 chars + reserved-word ban), description length (≤1024 chars), body length (≤500 lines), `effort:` presence, `model:` presence when invokable, and verbatim OUTPUT STYLE snippet. Wired into `hooks.json` PostToolUse Write|Edit chain and `pre-commit-validate.sh`.
- **Phase 0.0 Input Gate** — added to `sprint-plan` and `sprint-dev`; hard-fails with the missing-artifact path AND the producer skill name when an upstream input is missing (no more cryptic "no roadmap registry" errors on greenfield projects).

### Changed

- **All 36 SKILL.md files** — every skill now satisfies the canonical frontmatter contract: `effort:` field present (low/medium/high), `model:` explicit when invokable (no `[1m]` inheritance), verbatim OUTPUT STYLE snippet from `/_shared/terse-output.md` immediately below the Additional Resources block. Bodies trimmed to ≤500 lines (sprint-plan and sprint-dev pushed redundant content to canonical shared docs and reference.md).
- **`skills/sprint-plan/SKILL.md`** — Additional Resources cite story-frontmatter.md and state-handoff.md as load-bearing; Phase 2.4 cites spawn-protocol.md §8 Agent Output Contract instead of inline thresholds; Phase 1.4 lock cycle delegates to session-protocol.md §File-Based Locking Protocol.
- **`skills/sprint-dev/SKILL.md`** — Execution Mode now reads autonomy from `.cc-sessions/developer-profile.json` per session-protocol.md §Autonomy Levels (canonical: low → interactive, medium → checkpoint, high/full → autonomous-forced); Phase 0.0 gate validates upstream artifacts; Phase 3.1a registry write delegates to carry-forward-registry.md §Writers; Phase 3.5.0 integration-check **mandatory** (was "optional").
- **`skills/sprint-review/SKILL.md`** — Phase 3.6 invocation switched to canonical Reader Algorithm; Invariant 5 now scans **SKILL.md AND reference.md** (was reference.md only) — every SKILL.md without the canonical OUTPUT STYLE snippet auto-fails. Phase 2.6 cites spawn-protocol.md §8.
- **`skills/sprint/SKILL.md`, `skills/implement/SKILL.md`, `skills/review/SKILL.md`** — orchestrators now declare `model: opus`, `effort: low`, `allowed-tools`; descriptions rewritten in third person with explicit trigger phrases.
- **`skills/health/SKILL.md`** — Phase 3.1 rewritten to walk `skills/*/SKILL.md` via the new lint hook (was: parse `skill-registry.json`).
- **`hooks/scripts/pre-commit-validate.sh`** — adds SKILL.md frontmatter validation gate on staged SKILL.md files. Commits with violations are blocked.
- **`hooks/hooks.json`** — added `skill-frontmatter-validate.sh --all` to the PostToolUse Write|Edit chain.

### Documentation

- **`CLAUDE.md`** — fixed skill count (31 → 36); dropped `skill-registry.json` reference; added the canonical SKILL.md contract description and an expanded shared-protocol cross-reference list.
- **`README.md`** — fixed protocol count (9 → 12); dropped `skill-registry.json` from the architecture diagram; expanded the Shared Protocols table with three new entries (story-frontmatter.md, state-handoff.md, agent-prompt-boilerplate.md / scheduling.md / session-report-template.md).
- **`.claude-plugin/marketplace.json`** — version 1.6.0 → 1.9.0; description updated to "36 skills, 6 agents, 17 hook scripts".
- **`.claude-plugin/plugin.json`** — version 1.8.0 → 1.9.0.

### Why This Matters

A fresh Claude Code session can now invoke any skill from its SKILL.md alone. The sprint family round-trips cleanly because producer (sprint-plan) and consumers (sprint-dev, sprint-review) share one schema. Agent failure thresholds no longer drift between skills — one Agent Output Contract governs all spawns. The carry-forward registry has one Reader Algorithm; impossible-to-diverge implementations replace three near-duplicates. The OUTPUT STYLE snippet is now enforced by lint on every SKILL.md, eliminating the silent drift that triggered Invariant 5 failures.

## [1.8.0] — 2026-04-25

### April 2026 CC Platform Feature Adoption

Six CC platform features from the research backlog (`docs/_research/2026-04-25_blitz-skill-alignment.md`) implemented across skills and hooks.

### Added

- **`PreCompact` / `PostCompact` hooks** (`hooks/hooks.json` + `hooks/scripts/pre-compact-snapshot.sh` + `hooks/scripts/post-compact-log.sh`) — PreCompact fires before context compaction and writes a state snapshot (sprint number, wave progress, stories done/remaining, CF_ACTIVE count) to `.cc-sessions/compact-state.json`. PostCompact (async) reads the snapshot and appends a restoration hint to the activity feed so the next turn knows where to resume. Addresses the highest blitz failure mode: silent state loss during auto-compact on long sprints.
- **`UserPromptExpansion` hook** (`hooks/hooks.json` + `hooks/scripts/blitz-prompt-expansion.sh`) — fires on every `blitz:*` slash command expansion, reads the last 5 substantive activity-feed events, and injects them as `additionalContext` into the expansion prompt. Gives every skill instant awareness of prior session state without relying on Claude reading CLAUDE.md manually.

### Changed

- **`skills/sprint-dev/SKILL.md`** Phase 3.2 — Monitoring loop now uses the `Monitor` tool (event-driven) as the primary progress-tracking mechanism. Agents append JSON lines to a sprint-scoped progress file; a `tail -f` monitor wakes the orchestrator on DONE/BLOCKED/wave_complete events, eliminating the per-turn polling cost on long sprints. `TaskList` polling retained as fallback when Monitor is unavailable.
- **`skills/sprint-dev/SKILL.md`** Phase 2.2 — Agent MCP scoping table added. When `.claude/agents/blitz-{backend,frontend,test}-dev.md` definitions exist, each agent is spawned with its typed `mcpServers` config (backend=Firestore/Firebase, frontend=Playwright, test=read-only). Falls back to full session MCP set if agent definition files are absent.
- **`skills/sprint-dev/SKILL.md`** Phase 4.11 (new) — `PushNotification` call at sprint completion: sends title, story counts, and GitHub URL as a mobile push via Remote Control. No-op when Remote Control is not configured.
- **`skills/ship/SKILL.md`** Phase 4.2 (new) — `PushNotification` call at ship completion: sends version, feature/fix counts, and release URL. No-op when Remote Control is not configured.
- **`skills/sprint/SKILL.md`** `--loop` flag — Documents CronCreate-backed scheduling tiers (session/desktop/cloud Routine) and adds `ScheduleWakeup` self-scheduling pattern for direct `--loop` invocations (skipped when `CLAUDE_CODE_LOOP_MANAGED=1`). Documents 7-day CronCreate session expiry; recommends cloud Routines for runs >7 days.
- **`skills/ui-audit/SKILL.md`** Loop mode — `ScheduleWakeup` pattern added to `--loop` table: each tick registers the next wakeup so the audit survives idle periods without a persistent terminal.
- **`.claude-plugin/skill-registry.json`** — version 1.4.0 → 1.5.0.

## [1.7.0] — 2026-04-25

### blitz:code-doctor + Research → Sprint Auto-Chain

New skill `blitz:code-doctor` audits framework-API correctness (Firestore, VueFire, Vue 3, Pinia) — detects anti-patterns, misuse, dead exports, and duplication candidates. Read-only by default; `--fix` applies low-risk auto-fixes.

Auto-chain closes the only blocking manual step in the blitz cycle: running `/research` then `/sprint` previously failed with "No roadmap. Run `/blitz:roadmap` first." because `sprint/SKILL.md` Pre-Flight never detected uningested `docs/_research/*.md`. Now `sprint` automatically detects and ingests research docs via `roadmap extend` before proceeding — in both normal and `--loop` modes. `next/SKILL.md` gains carry-forward registry awareness so it never reports "nothing to do" while active entries exist.

### Added

- **`blitz:code-doctor` skill** (`skills/code-doctor/`) — SKILL.md + reference.md. Opus orchestrator + sonnet Agent workers. Framework-API correctness audit: Firestore (misuse, subcollection patterns, transaction anti-patterns), VueFire (reactive binding correctness), Vue 3 (Options/Composition anti-patterns, reactivity misuse), Pinia (store coupling, action patterns). `--fix` mode for low-risk auto-fixes (read-only by default). Registered in skill-registry.json (`quality` category, `beta` maturity).
- **Research doc** `docs/_research/2026-04-25_blitz-skill-alignment.md` — full 3-agent cycle alignment analysis. Identified 3 skill gaps + 7 un-adopted April-2026 CC platform features. Scope block `cf-2026-04-25-sprint-from-research-autochain`.
- **Research doc** `docs/_research/2026-04-25_code-doctor-skill.md` — code-doctor capability research.

### Changed

- **`skills/sprint/SKILL.md`** — Loop Step 1 Observe gains `UNINGESTED` / `UNINGESTED_COUNT` detection (cross-checks `carry-forward.jsonl` to skip already-ingested docs, preventing duplicate-id hard-fail). Loop Step 2 decision tree gains row 0: "uningested research → roadmap extend, exit clean." Pre-Flight gains step 1b: auto-invokes `roadmap extend` in normal mode; fails loud on malformed `scope:` blocks.
- **`skills/research/SKILL.md`** — Phase 4.2 follow-up table reordered: `roadmap extend` first (mandatory ingestion step made explicit), `sprint` second (single-command auto-chain path), `sprint-plan` third.
- **`skills/next/SKILL.md`** — Phase 0 gains steps 0.6 (`CF_ACTIVE` / `CF_ESCALATED` reads from carry-forward registry) and 0.7 (`UNINGESTED_COUNT`). Decision tree gains rows 8b–8d: escalation banner for stuck entries, ingest-and-plan path, gap-closure path. `next` can no longer report "nothing to do" while carry-forward entries are active.
- **`.claude-plugin/skill-registry.json`** — code-doctor entry added; version 1.3.0 → 1.4.0.

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
