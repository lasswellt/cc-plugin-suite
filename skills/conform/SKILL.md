---
name: conform
description: Conforms an existing project's blitz runtime artifacts to the current canonical schemas in skills/_shared/. Detects drift in `.cc-sessions/` (carry-forward.jsonl, activity-feed.jsonl, developer-profile.json), sprint artifacts (manifest, stories, STATE.md), roadmap JSON files, and research docs (`scope:` blocks). Fixes legacy story-frontmatter (missing registry_entries, old autonomy fields), normalizes activity-feed entries to the verbose-progress.md schema, repairs STATE.md required fields, removes orphan locks. Use after upgrading blitz, when sprint-dev/review complains about missing schema fields, when carry-forward escalations look stale, or when a project bootstrapped on older blitz needs to be brought into spec. Read-only by default — `--fix` applies migrations idempotently. Plugin-fork mode (SKILL.md / companion file / hook drift) via `--scope plugin`.
when_to_use: After upgrading blitz in an existing project, when sprint-dev complains about missing story frontmatter fields, when carry-forward shows stale escalations or duplicate IDs, when activity-feed entries fail schema validation, when a STATE.md from an older sprint is missing fields, when forking the plugin and auditing structural drift.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: low
argument-hint: "[target-dir] [--fix | --report-only] [--scope project|plugin|all]"
disable-model-invocation: false
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Conform

You are the conformance auditor + migration runner. You bring an existing **project's** blitz runtime artifacts (or a plugin **fork's** structure) into spec with the current canonical schemas defined in `skills/_shared/`.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md). Print `[conform]` prefixed status lines at every phase transition, finding, and dispatch. Log `skill_start`, `audit_complete`, `migration_applied`, and `skill_complete` events to `.cc-sessions/activity-feed.jsonl`.

**Read-only by default.** Never write to the target without an explicit `--fix` argument. If `--fix` is omitted, end at Phase 6 (REPORT) — no migration ever runs.

## Two scopes

| Scope | Target | Use case |
|---|---|---|
| **`project`** (default) | `.cc-sessions/`, `sprints/`, `docs/roadmap/`, `docs/_research/`, `STATE.md` | A repo that uses blitz to run sprints. Brings runtime artifacts into spec after a plugin upgrade. |
| **`plugin`** | `skills/*/SKILL.md`, `skills/_shared/`, `hooks/`, `.claude-plugin/` | A blitz fork or the plugin source itself. Brings structure into spec (frontmatter, companion files, hook wiring). |
| **`all`** | both | Full sweep — uncommon; usually only useful when auditing a self-modifying plugin install. |

## Additional Resources

- For the carry-forward registry schema (entry shape, lifecycle events, hard-gate algorithm), see [carry-forward-registry.md](/_shared/carry-forward-registry.md)
- For the activity-feed JSONL schema (`ts`, `session`, `skill`, `event`, `message`, `detail` fields + ≤200/300-char message rule), see [verbose-progress.md](/_shared/verbose-progress.md)
- For the canonical story frontmatter (producer/consumer matrix, validation algorithm, `registry_entries` field), see [story-frontmatter.md](/_shared/story-frontmatter.md)
- For pipeline state handoff (which artifact each skill produces/requires, STATE.md required fields), see [state-handoff.md](/_shared/state-handoff.md)
- For autonomy field schema (`developer-profile.json`), see [session-protocol.md](/_shared/session-protocol.md) §Autonomy Levels
- For plugin-mode migration scripts and idempotency contracts, see [scripts/maint/v1.9.0/README.md](/_shared/../../../scripts/maint/v1.9.0/README.md)

---

## Phase 0: PARSE — Determine Target, Mode, Scope

1. **Register session.** Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

2. **Resolve target directory.** Default to `pwd`. If first positional arg is a directory path, use it. Reject paths outside `${HOME}` unless explicit `--allow-system-paths` flag passed.

3. **Determine mode.**
   - `--fix` → audit + migrate (writes mechanical fixes)
   - `--report-only` (default if neither flag passed) → audit only, no writes

4. **Determine scope.**
   - `--scope project` (default) → consumer-repo runtime artifacts
   - `--scope plugin` → plugin source (SKILL.md frontmatter, companion files, hooks)
   - `--scope all` → both

5. **Sanity check target.** Refuse to proceed unless the target contains at least one of:
   - `.cc-sessions/` (any blitz-managed project)
   - `sprints/` (sprint-managed project)
   - `.claude-plugin/plugin.json` (plugin source)
   - `skills/*/SKILL.md` (skill collection)

   If none found, exit with `NOT_A_BLITZ_DIR` and one-line guidance pointing at `/blitz:bootstrap` or `/blitz:setup`.

---

## Phase 1: DETECT — Inventory Target Artifacts

### Project scope (default)

Walk the target and capture:

| Inventory item | Probe | Schema source |
|---|---|---|
| Activity feed | `.cc-sessions/activity-feed.jsonl` (line count + size) | verbose-progress.md |
| Carry-forward entries | `.cc-sessions/carry-forward.jsonl` (count + per-status breakdown) | carry-forward-registry.md |
| Developer profile | `.cc-sessions/developer-profile.json` (autonomy field present?) | session-protocol.md §Autonomy Levels |
| Active sessions | `.cc-sessions/*.json` with `status: active` (count + ages) | session-protocol.md §Session Registration |
| Orphan locks | `.cc-sessions/*.lock` not paired with an active session | session-protocol.md §File-Based Locking |
| Sprints | `sprints/sprint-*/` (count, latest sprint number) | state-handoff.md |
| Sprint manifests | `sprints/sprint-N/manifest.{json,md}` | state-handoff.md |
| Stories | `sprints/sprint-N/stories/*.md` (frontmatter sample) | story-frontmatter.md |
| STATE.md files | `sprints/sprint-N/STATE.md`, `STATE.md` (root) | state-handoff.md |
| Roadmap | `docs/roadmap/{capability-index,epic-registry,phase-plan,domain-index}.json`, `docs/roadmap/ROADMAP.md`, `docs/roadmap/gap-analysis.md` | roadmap skill output schema |
| Research docs | `docs/_research/*.md` (count, scope-block presence) | research skill output schema |
| Review reports | `sprints/sprint-N/review-report.md` | sprint-review.md output schema |

Emit one verbose-progress line per category. Stash the inventory in a temp file.

### Plugin scope (only if `--scope plugin` or `all`)

| Inventory item | Probe |
|---|---|
| SKILL.md files | `find <target>/skills -maxdepth 2 -name SKILL.md` |
| Companion file layout | for each skill, glob legacy `reference.md`, `CHECKS.md`, `PATTERNS.md`, `*.json` outside `assets/` |
| Hook scripts present | `find <target>/hooks/scripts -name '*.sh' -o -name '*.py'` |
| Hooks wired | parse `<target>/hooks/hooks.json` |
| Version files | `<target>/.claude-plugin/plugin.json`, `marketplace.json`, `installer/install.sh` |
| Legacy registry | `<target>/.claude-plugin/skill-registry.json` (deleted in v1.9.0) |
| Shared protocols | `find <target>/skills/_shared -name '*.md'` |

---

## Phase 2: AUDIT — Validate Against Canonical Schemas

### Project-scope checks

For each artifact category, validate every line/file against the schema in the linked shared protocol. Findings classified as:

- **MECHANICAL** — auto-fixable (missing-but-trivially-derivable field, normalizable timestamp, schema-version migration)
- **MANUAL** — needs human judgment (stale escalation that needs a real disposition, contradictory state)
- **NO ACTION** — informational

| Check | Validator |
|---|---|
| `activity-feed.jsonl` lines parse as JSON, have required fields (`ts`, `session`, `skill`, `event`, `message`, `detail`) per verbose-progress.md schema. Message ≤300 chars (audit threshold). | `python3 -c "for l in open(f): json.loads(l); assert all(k in d for k in [...])"` |
| `carry-forward.jsonl` entries follow the lifecycle event schema (`event in {created, correction, progress, complete, dropped, deferred, escalated}`). No duplicate IDs. No `rollover_count >= 3` without explicit ESCALATION disposition. | Apply the canonical Reader Algorithm from carry-forward-registry.md §Reader Algorithm with `MODE=audit` |
| `developer-profile.json` has `autonomy` field with value in `{low, medium, high, full}`. | `jq '.autonomy' < developer-profile.json` |
| Story files have current frontmatter — required fields per story-frontmatter.md producer/consumer matrix (`id`, `title`, `epic_id`, `acceptance_criteria`, `registry_entries`). | Schema-validate each `sprints/sprint-*/stories/*.md` frontmatter block |
| STATE.md files have required fields per state-handoff.md (`sprint`, `phase`, `last_completed`, `current_session`, `cf_active_count`). | Field-presence check |
| Active sessions older than 4 hours flagged as stale per session-protocol.md. | Compare `started` timestamp to now |
| Orphan locks (lock file with no matching active session JSON) — flag for cleanup. | Set diff between `*.lock` and active `*.json` files |
| Roadmap JSON files (capability-index, epic-registry, phase-plan, domain-index) parse cleanly + have required top-level fields per their writer skill's output schema. | `jq -e .` + field probes |
| Research docs with `scope:` blocks — verify each scope entry has a corresponding `created` event in `carry-forward.jsonl`. Un-ingested entries are MECHANICAL (re-run `roadmap extend`). | Cross-reference scope IDs vs registry IDs |
| Review reports for completed sprints exist + reference the registry by ID. | Glob + grep |

### Plugin-scope checks (only if `--scope plugin` or `all`)

| Validator | Source |
|---|---|
| `hooks/scripts/skill-frontmatter-validate.sh skills/*/SKILL.md` | repo |
| `hooks/scripts/markdown-link-validate.sh` | repo |
| `hooks/scripts/reference-compression-validate.sh` | repo |
| `scripts/check-version-sync.sh` | repo |
| Companion file layout: any legacy `reference.md`/`CHECKS.md`/`PATTERNS.md` outside `references/` or `assets/` | filesystem walk |
| Hook scripts in `hooks/scripts/` matched against `hooks.json` wiring (no orphans, no missing wires) | parse + diff |

Record classification per finding.

---

## Phase 3: PLAN — Categorize Findings

Build a migration plan as a table:

| Finding | Scope | Category | Fix approach | Idempotent? |
|---|---|---|---|---|
| 47 activity-feed entries missing `detail` field | project | MECHANICAL | inline Edit: append `"detail":{}` to lines lacking it | yes |
| 3 stories missing `registry_entries` field | project | MECHANICAL | inline Edit: derive from carry-forward.jsonl `created` events bound to story | yes |
| `developer-profile.json` missing `autonomy` field | project | MECHANICAL | inline Edit: add `"autonomy": "medium"` (safe default) with a TODO comment | yes |
| 1 stale active session (started 18h ago) | project | MANUAL | requires user disposition — close as `abandoned` or extend? | no |
| 4 carry-forward entries with `rollover_count: 3` no ESCALATION | project | MANUAL | requires real triage decision | no |
| 1 research doc with un-ingested scope block | project | MECHANICAL | suggest `/blitz:roadmap extend` | yes (delegated) |
| 8 SKILL.md missing OUTPUT STYLE snippet | plugin | MECHANICAL | run `scripts/maint/v1.9.0/blitz-fix-frontmatter.sh` | yes |
| 12 reference.md files (legacy layout) | plugin | MECHANICAL | run `scripts/maint/v1.9.0/blitz-restructure.py` | yes |
| 1 SKILL.md body >500 lines | plugin | MANUAL | move what to references/? | no |

Print plan as a verbose-progress table. If `--report-only`, jump to Phase 6.

---

## Phase 4: MIGRATE (only if `--fix`) — Apply Mechanical Fixes

### Project-scope fixes (inline)

The fixes are heterogeneous and reasoning-light; apply them one finding at a time using `Edit` and `Write`.

| Finding | Fix |
|---|---|
| Activity-feed missing `detail` field | Append `"detail":{}` to each affected JSONL line. Backup `.cc-sessions/activity-feed.jsonl.bak.<ts>` first. |
| Activity-feed message > 300 chars | Truncate `message` to ≤300 chars; move overflow into `detail.full_message`. |
| Carry-forward duplicate IDs | Keep most-recent entry by timestamp; append `dropped` event for older with reason `"deduped by /conform"`. |
| Story missing `registry_entries` | Re-derive: grep `carry-forward.jsonl` for `created` events whose `detail.story_id == story.id`; populate `registry_entries: [...]` in story frontmatter. |
| `developer-profile.json` missing `autonomy` | Add `"autonomy": "medium"` (canonical safe default per session-protocol.md). |
| Orphan lock files | Delete after confirming no live session holds them. |
| STATE.md missing required field | Derive from sprint manifest + carry-forward state; insert under canonical heading. |
| Un-ingested research scope blocks | **Defer** to `/blitz:roadmap extend` — emit a TODO line in the report; do not auto-invoke another skill from MIGRATE. |
| Stale active sessions (>4h) | **Defer** — MANUAL disposition required. |

### Plugin-scope fixes

Run the migration scripts in dependency order. Each must exit 0 before the next runs.

1. `scripts/maint/v1.9.0/blitz-fix-frontmatter.sh` — adds missing `effort:` + OUTPUT STYLE snippet
2. `scripts/maint/v1.9.0/blitz-restructure.py` — companion file rename (two-phase: refs first, then files)
3. `scripts/maint/v1.9.0/blitz-trim-preamble.py` — verbose-preamble trim
4. `scripts/maint/v1.9.0/blitz-rewrite-desc.py` — **only applies to canonical 36-skill names** (external plugin skills skipped)
5. `scripts/maint/v1.9.0/blitz-xref-audit.py` — read-only verification

After each fix, append a `migration_applied` event with the script/finding name + per-file delta count.

---

## Phase 5: VERIFY — Re-run Validators

Re-run all Phase 2 checks against the migrated tree. Compare exit codes and finding counts:

- All validators clean → migration successful, transition to REPORT
- Finding count strictly decreased but not to 0 → classify residue as MANUAL, transition to REPORT with that residue listed
- New findings appeared (regression) → **HALT** with diff vs Phase 2 audit; do not continue

Never auto-rollback. Backup files (`.bak.<ts>`) preserve pre-migration state.

---

## Phase 6: REPORT

Write a single-page summary to stdout (and `${TARGET}/.cc-sessions/conform-report.md` if `--fix` was passed):

```
# Conform Report — <target> — <ISO-date>

Mode: report-only | fix
Scope: project | plugin | all

## Inventory
  Activity feed: <N> entries (<size>)
  Carry-forward: <N> entries (<active>/<complete>/<dropped>/<escalated>)
  Sprints: <N> (latest: sprint-<X>)
  Roadmap files: <N>
  Research docs: <N> (<un-ingested>)
  Active sessions: <N> (<stale>)
  [plugin] SKILL.md files: <N>
  [plugin] Hook scripts wired: <N>

## Findings (Phase 2)
  MECHANICAL: <count> (auto-fixable)
  MANUAL: <count> (require human review)
  NO ACTION: <count> (informational)

## Migrations applied (Phase 4) — only present if --fix
  activity-feed schema fixes: <N> lines updated
  carry-forward dedup: <N> entries
  story-frontmatter additions: <N> stories
  developer-profile autonomy backfill: applied | n/a
  STATE.md field additions: <N> files
  orphan lock cleanup: <N> deleted
  [plugin] blitz-fix-frontmatter.sh: <N> files
  [plugin] blitz-restructure.py: <N> files moved, <N> ref substitutions

## Verification (Phase 5)
  activity-feed schema: PASS | FAIL (<details>)
  carry-forward Reader Algorithm: PASS | FAIL | ESCALATION (<n>)
  story-frontmatter validation: PASS | FAIL (<details>)
  STATE.md required-fields: PASS | FAIL (<details>)
  [plugin] skill-frontmatter-validate: PASS | FAIL
  [plugin] markdown-link-validate: PASS | FAIL
  [plugin] check-version-sync: PASS | FAIL

## Manual follow-ups (require human action)
  - <file>:<line>  <issue>  <suggested action>
  - ...

## Deferred to other skills
  - 1 un-ingested research doc → run `/blitz:roadmap extend`
  - 4 carry-forward escalations → run `/blitz:next` to triage

Final state: CONFORMANT | DRIFT_REMAINING | REGRESSED
```

Append a `task_complete` event with `summary: "conform <mode> <scope> <target> — <final state>"`.

---

## Safety Rules (NON-NEGOTIABLE)

1. **No writes without `--fix`.** Default mode is read-only. Refuse any write tool call unless `--fix` was parsed.
2. **No writes to `.git/`, `node_modules/`, or any path matching `pre-edit-guard.sh` protected list.** Honor existing hook protections in the target.
3. **Backup before mutating** `.cc-sessions/*.jsonl` files. Backups go to `.cc-sessions/<file>.bak.<ts>`.
4. **No script execution outside `scripts/maint/v1.9.0/`** during plugin-mode MIGRATE. The skill is a thin orchestrator over those scripts; never invent new mechanical fixes inline for plugin-mode.
5. **Halt on first regression in VERIFY**. Do not continue migrating after a validator regression.
6. **Activity-feed audit trail required**. Every migration must log a `migration_applied` event with finding name + count, even on partial application.
7. **Never auto-invoke other blitz skills** from MIGRATE. If the fix is "run `/blitz:roadmap extend`", emit a TODO and let the user decide.

## Out of scope

- Code-level refactoring (use `/blitz:refactor`)
- Stack/framework migrations (use `/blitz:migrate`)
- Bootstrapping a new project (use `/blitz:bootstrap`)
- Conflicts between user CLAUDE.md and plugin behavior (use `/blitz:setup`)
- Health probe of currently-running plugin install (use `/blitz:health`)
- Triage of carry-forward escalations or "what's next" routing (use `/blitz:next`)
- Re-ingesting research docs into roadmap (use `/blitz:roadmap extend`)

`conform` is exclusively about bringing a project's *runtime artifacts* (or a plugin's *structure*) into spec with the current canonical schemas.
