---
name: conform
description: Conforms a blitz-style plugin directory to the current Anthropic-canonical SKILL.md and companion-file conventions. Detects drift in frontmatter (missing effort/model/OUTPUT STYLE snippet, descriptions over 1024 chars, bodies over 500 lines), companion file layout (legacy reference.md vs canonical references/main.md, stray CHECKS.md/PATTERNS.md, conflict-catalog.json outside assets/), hook wiring, registry remnants (skill-registry.json), version sync. Use after upgrading the blitz plugin to a new version, when forking or auditing an external blitz-style plugin, when CI flags lint violations, or when migrating a project that was bootstrapped on an older blitz version. Reports findings; --fix applies mechanical migrations idempotently using the v1.9.0 migration scripts archived in scripts/maint/v1.9.0/. Read-only by default — never writes without --fix.
when_to_use: After upgrading the blitz plugin, when auditing a fork, when CI flags SKILL.md frontmatter or companion-file layout drift, when migrating an older blitz-bootstrapped project to current spec.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: opus
effort: low
argument-hint: "[target-dir] [--fix | --report-only] [--scope frontmatter|layout|hooks|all]"
disable-model-invocation: false
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Conform

You are the conformance auditor + migration runner. You bring an existing blitz-style plugin directory into spec with the current canonical conventions (v1.9.1+) using the validators and migration scripts already present in this plugin.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md). Print `[conform]` prefixed status lines at every phase transition, finding, and dispatch. Log `skill_start`, `audit_complete`, `migration_applied`, and `skill_complete` events to `.cc-sessions/activity-feed.jsonl`.

**Read-only by default.** Never write to the target without an explicit `--fix` argument. If `--fix` is omitted, end at Phase 6 (REPORT) — no migration ever runs.

## Additional Resources

- For the canonical SKILL.md frontmatter contract enforced by lint, see [/_shared/terse-output.md](/_shared/terse-output.md) §Canonical Exemptions and `hooks/scripts/skill-frontmatter-validate.sh`.
- For the companion file layout (`references/`, `assets/`, `scripts/`), see Anthropic skill-authoring guidance and `scripts/maint/v1.9.0/blitz-restructure.py`.
- For the migration scripts and their idempotency contracts, see [scripts/maint/v1.9.0/README.md](/_shared/../scripts/maint/v1.9.0/README.md).

---

## Phase 0: PARSE — Determine Target and Mode

1. **Register session.** Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

2. **Resolve target directory.** Default to `${CLAUDE_PLUGIN_ROOT}` (the current blitz install). If first positional arg is a directory path, use it. Reject paths outside `${HOME}` unless explicit `--allow-system-paths` flag passed.

3. **Determine mode.**
   - `--fix` → audit + migrate (writes mechanical fixes)
   - `--report-only` (default if neither flag passed) → audit only, no writes
   - `--scope <frontmatter|layout|hooks|all>` → restrict checks to one category (default: all)

4. **Sanity check target.** Refuse to proceed unless the target contains either:
   - `.claude-plugin/plugin.json` (a plugin install), OR
   - `skills/*/SKILL.md` (a skill collection)

   If neither found, exit with `NOT_A_PLUGIN_DIR` and one-line guidance.

---

## Phase 1: DETECT — Inventory Target

Walk the target and capture:

| Inventory item | Probe |
|---|---|
| SKILL.md files | `find <target>/skills -maxdepth 2 -name SKILL.md` |
| Companion file layout | for each skill, glob `reference.md`, `references/`, `CHECKS.md`, `PATTERNS.md`, `*.json` outside `assets/` |
| Hook scripts present | `find <target>/hooks/scripts -name '*.sh' -o -name '*.py'` |
| Hooks wired | parse `<target>/hooks/hooks.json` and extract command paths |
| Version files | `<target>/.claude-plugin/plugin.json`, `<target>/.claude-plugin/marketplace.json`, `<target>/installer/install.sh` |
| Legacy registry | `<target>/.claude-plugin/skill-registry.json` (deleted in v1.9.0; presence = drift) |
| Shared protocols | `find <target>/skills/_shared -name '*.md'` |

Emit one verbose-progress line per category counted. Stash the inventory in a temp file for later phases.

---

## Phase 2: AUDIT — Run Validators

Run each validator against the inventoried target. Capture exit codes + output.

| Validator | What it checks |
|---|---|
| `hooks/scripts/skill-frontmatter-validate.sh skills/*/SKILL.md` | name ≤64 chars, third-person description ≤1024 chars, body ≤500 lines, OUTPUT STYLE snippet present, required fields when invokable |
| `hooks/scripts/markdown-link-validate.sh` | broken relative `.md` links across `skills/` |
| `hooks/scripts/reference-compression-validate.sh` | compressed `references/main.md` matches `.original` sibling structure |
| `scripts/check-version-sync.sh` | `plugin.json` ↔ `marketplace.json` ↔ `installer/install.sh` banner |

For each finding, classify:

- **MECHANICAL** — fixable by an existing script in `scripts/maint/v1.9.0/`. Examples: missing `effort:` field, missing OUTPUT STYLE snippet, `reference.md` files needing rename, verbose preamble that needs trimming.
- **MANUAL** — needs human judgment. Examples: SKILL.md body >500 lines (move what to references?), description >1024 chars (which trigger phrases to keep?), legacy `skill-registry.json` consumers (which fields are still load-bearing?).
- **NO ACTION** — informational only.

Record the classification per finding into the audit log.

---

## Phase 3: PLAN — Categorize Findings

Build the migration plan as a table:

| Finding | Category | Fix script | Idempotent? |
|---|---|---|---|
| 4 SKILL.md missing effort: field | MECHANICAL | `blitz-fix-frontmatter.sh` | yes |
| 12 SKILL.md missing OUTPUT STYLE snippet | MECHANICAL | `blitz-fix-frontmatter.sh` | yes |
| 8 reference.md files (legacy layout) | MECHANICAL | `blitz-restructure.py` | yes |
| 6 SKILL.md verbose session preamble | MECHANICAL | `blitz-trim-preamble.py` | yes |
| `skill-registry.json` exists | MECHANICAL | manual delete + grep consumers | partial |
| 2 SKILL.md body >500 lines | MANUAL | — | n/a |
| 1 SKILL.md description 1180 chars | MANUAL | — | n/a |

Print the plan as a verbose-progress table. If `--report-only`, jump to Phase 6.

---

## Phase 4: MIGRATE (only if `--fix`) — Apply Mechanical Fixes

Run the migration scripts in dependency order. **Each script must run successfully (exit 0) before the next starts.**

1. **Frontmatter additions** (`scripts/maint/v1.9.0/blitz-fix-frontmatter.sh`)
   - Adds missing `effort:` field
   - Adds verbatim OUTPUT STYLE snippet below Additional Resources block
   - Idempotent: skips files already conformant

2. **Companion file restructure** (`scripts/maint/v1.9.0/blitz-restructure.py`)
   - Two-phase: rewrite cross-refs first, then move files
   - Renames `reference.md` → `references/main.md` (+ `.original` siblings)
   - Renames `CHECKS.md`/`PATTERNS.md` → `references/checks.md`/`patterns.md`
   - Moves `conflict-catalog.json` → `assets/`
   - Idempotent: filters source list to files that exist

3. **Verbose preamble trim** (`scripts/maint/v1.9.0/blitz-trim-preamble.py`)
   - Compresses ~500-char session-registration preambles to ~270-char canonical citation
   - Idempotent: regex matches only the verbose form

4. **Description rewrite** (`scripts/maint/v1.9.0/blitz-rewrite-desc.py`)
   - **NOTE: skill-name keyed.** Only applies to skills whose names match this plugin's catalog (the 36 in this repo). External plugin skills are skipped — manual review required.

5. **Cross-reference audit** (`scripts/maint/v1.9.0/blitz-xref-audit.py`)
   - Read-only verification pass after restructure
   - Exits non-zero on broken refs

After each script, append a `migration_applied` event to the activity feed with the script name + per-file delta count.

---

## Phase 5: VERIFY — Re-run Validators

Re-run all Phase 2 validators against the migrated tree. Compare exit codes:

- All validators exit 0 → migration successful, transition to REPORT
- Any validator exits non-zero → **HALT** with diff vs Phase 2 audit:
  - If new findings appeared (regression), report and exit 1
  - If finding count decreased but not to 0 (partial fix), classify the residue as MANUAL and report

Never auto-rollback. The `.original` backups created by `pre-edit-backup.sh` (if active in target) preserve pre-migration state.

---

## Phase 6: REPORT

Write a single-page summary to stdout (and `${TARGET}/.cc-sessions/conform-report.md` if `--fix` was passed):

```
# Conform Report — <target> — <ISO-date>

Mode: report-only | fix
Scope: all | frontmatter | layout | hooks

## Inventory
  N SKILL.md files
  N hook scripts (M wired in hooks.json)
  N shared protocols
  Plugin version: X.Y.Z

## Findings (Phase 2)
  MECHANICAL: <count> (auto-fixable)
  MANUAL: <count> (require human review)
  NO ACTION: <count> (informational)

## Migrations applied (Phase 4) — only present if --fix
  blitz-fix-frontmatter.sh: <N> files modified
  blitz-restructure.py: <N> files moved, <N> ref substitutions
  blitz-trim-preamble.py: <N> files trimmed, <X> bytes saved

## Verification (Phase 5)
  skill-frontmatter-validate.sh: PASS | FAIL (<details>)
  markdown-link-validate.sh: PASS | FAIL (<details>)
  reference-compression-validate.sh: PASS | FAIL (<details>)
  check-version-sync.sh: PASS | FAIL (<details>)

## Manual follow-ups
  - <file>:<line>  <issue>  <suggested action>
  - ...

Final state: CONFORMANT | DRIFT_REMAINING | REGRESSED
```

Append a `task_complete` event with `summary: "conform <mode> <target> — <final state>"`.

---

## Safety Rules (NON-NEGOTIABLE)

1. **No writes without `--fix`**. Default mode is read-only. Refuse any write tool call unless `--fix` was parsed.
2. **No writes to `.git/`, `node_modules/`, or any path matching `pre-edit-guard.sh` protected list.** Honor existing hook protections in the target.
3. **No script execution outside `scripts/maint/v1.9.0/`** during MIGRATE. The skill is a thin orchestrator over those scripts; never invent new mechanical fixes inline.
4. **Halt on first regression in VERIFY**. Do not continue migrating after a validator regression.
5. **Activity-feed audit trail required**. Every migration must log a `migration_applied` event with script name + file count, even on partial application.

## Out of scope

- Code-level refactoring (use `/blitz:refactor`)
- Stack/framework migrations (use `/blitz:migrate`)
- Bootstrapping a new plugin from scratch (use `/blitz:bootstrap`)
- Conflicts between user CLAUDE.md and plugin behavior (use `/blitz:setup`)
- Health probe of running plugin (use `/blitz:health`)

`conform` is exclusively about bringing a plugin's *structure* into spec with the current canonical conventions.
