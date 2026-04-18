**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Blitz Roadmap — Caveman Full Absorption

Generated 2026-04-18 via `/blitz:roadmap full` (narrow scope). Ingested 2 research docs, extracted 7 capabilities, clustered into 3 domains, sequenced into 4 phases.

## At a glance

| Phase | Duration | Capabilities | Parallelizable? |
|---|---|---|---|
| 1 — Foundation | 0.5-1 sprint | CAP-001, CAP-002 | Yes (2 workstreams) |
| 2 — Runtime propagation | 1 sprint | CAP-003, CAP-004 | Yes (2 workstreams) |
| 3 — State + gating + dedup | 1 sprint | CAP-005, CAP-006 | Yes (2 workstreams) |
| 4 — Enforcement | 0.25 sprint | CAP-007 | Serial (gates on clean sprint) |
| **Total** | **~3 sprints** | **7 capabilities** | 14 carry-forward entries |

## Critical path

`CAP-001 → CAP-003 → CAP-005 → CAP-007` (directive-propagation chain)
+ CAP-002 parallel to CAP-001
+ CAP-004 parallel to CAP-003
+ CAP-006 in Phase 3 after CAP-003 lands

## Capabilities

| ID | Title | Domain | Phase |
|---|---|---|---|
| CAP-001 | Extend terse-output directive coverage (agents, SKILL.md gap, shared protocols) | directive-propagation | 1 |
| CAP-002 | Wave-2 author-time compression (7 SAFE reference.md + 12 research docs) | content-optimization | 1 |
| CAP-003 | Inject runtime terse directive at write-sites and Agent() prompts | directive-propagation | 2 |
| CAP-004 | Adopt caveman-review output format in sprint-review + review | output-shaping | 2 |
| CAP-005 | Persist output intensity; add per-section LITE exemption markers | output-shaping | 3 |
| CAP-006 | Extract agent-prompt boilerplate to shared fragment; refactor 7 UNSAFE reference.md | content-optimization | 3 |
| CAP-007 | Upgrade spawn-protocol WARNING → BLOCKER | directive-propagation | 4 |

## Registry entries (14 total)

Every scope claim in the ingested research docs is registered under `.cc-sessions/carry-forward.jsonl`. Each entry has `parent.capability` and `parent.epic` backfilled post-Phase-7. Coverage recomputed on every `/blitz:roadmap refresh` run.

| Registry ID | Parent | Target |
|---|---|---|
| cf-2026-04-18-terse-directive-agents | CAP-001 / E-001 | 6 files |
| cf-2026-04-18-terse-directive-skill-gap | CAP-001 / E-001 | 6 files |
| cf-2026-04-18-terse-directive-shared-protocols | CAP-001 / E-001 | 10 files |
| cf-2026-04-18-compress-safe-references-wave2 | CAP-002 / E-002 | 7 files |
| cf-2026-04-18-compress-research-docs | CAP-002 / E-002 | 12 files |
| cf-2026-04-18-write-phase-directive-inserts | CAP-003 / E-003 | 8 files |
| cf-2026-04-18-unsafe-ref-agent-prompt-injection | CAP-003 / E-003 | 7 files |
| cf-2026-04-18-review-format-absorption | CAP-004 / E-004 | 2 files |
| cf-2026-04-18-output-intensity-profile | CAP-005 / E-005 | 1 file |
| cf-2026-04-18-lite-exemption-markers | CAP-005 / E-005 | 9 files |
| cf-2026-04-18-task-type-gating (superseded) | CAP-005 / E-005 | 5 files |
| cf-2026-04-18-activity-feed-message-rule | CAP-005 / E-005 | 1 file |
| cf-2026-04-18-agent-prompt-boilerplate | CAP-006 / E-006 | 1 file |
| cf-2026-04-18-spawn-protocol-warning-upgrade | CAP-007 / E-007 | 2 files |

## Coverage snapshot

0/14 entries delivered. See `docs/roadmap/gap-analysis.md` for full per-entry state.

## Out-of-scope (deferred)

- Structural template rewrites (research 8-section mandate, roadmap multi-artifact, doc-gen prose-by-spec). Source doc Finding 10. Later roadmap epic.
- 11 older research docs (pre-2026-04-18). Historical; not ingested in this roadmap run.
- Per-turn UserPromptSubmit reinforcement hook, statusline badge, wenyan mode, multi-editor distribution, `/blitz:commit-style` skill — explicit SKIPs per source research.

## Next actions

1. **Run `/blitz:sprint-plan`** — converts E-001 + E-002 into Sprint-2 stories (Phase 1 epics run in parallel; one sprint delivers both).
2. **Sprint-plan will create GitHub issues** for each story in E-001 (3 stories) and E-002 (2 stories) = 5 issues.
3. **Alternative immediate execution**: skip sprint-plan and run `/blitz:compress` directly on E-002's 19 files for quick wins. E-001 is 50 minutes of mechanical edits.

## Artifacts

- `docs/roadmap/capability-index.json` — 7 capabilities with scope metrics
- `docs/roadmap/gap-analysis.md` — coverage + existing-infra + out-of-scope
- `docs/roadmap/domain-index.json` — 3 domains
- `docs/roadmap/domains/{directive-propagation,content-optimization,output-shaping}/overview.md`
- `docs/roadmap/phase-plan.json` — 4 phases, critical path, parallel workstreams
- `docs/roadmap/epic-registry.json` — 7 epics, 14 stories, all tied to registry IDs
- `.cc-sessions/carry-forward.jsonl` — 28 lines (14 created + 14 correction)

## Sources

- `docs/_research/2026-04-18_caveman-full-absorption.md` (439 lines, 9 scope entries)
- `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` (381 lines, 5 scope entries)
