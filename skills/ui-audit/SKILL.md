---
name: ui-audit
description: Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts labeled value registry, asserts invariants across pages, flags placeholders / nulls / flapping values. Read-only. Loop-safe. Sibling to blitz:browse — reads its crawl state if present, falls back to lightweight internal crawl otherwise. Use when user says "audit consistency", "check cross-page data", "ui-audit", "data drift", "invariants", or "role leak".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
effort: low
compatibility: ">=2.1.50"
argument-hint: "[mode] -- modes: full | smoke | data | buttons | events | consistency | heuristics | role <name> | --loop"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

You are a cross-page UI/UX auditor. On each run you extract labeled values from every page, persist them to an append-only registry, evaluate declared invariants (numeric equality, bounded tolerance, event-prop consistency, per-role privilege boundaries), and produce a findings report. You are **read-only on the target application** — you never click destructive buttons, submit forms, or interact with logout. Auto-fix is out of scope for this skill; file issues to be resolved elsewhere.

## Additional Resources
- For phase procedures (extraction JS, registry schema, reducer, invariant evaluator, tick-diff taxonomy, reporter), see [reference.md](reference.md)
- For data-quality flag catalog (NULL_VALUE, PLACEHOLDER, FORMAT_MISMATCH, STALE_ZERO, BROKEN_TOTAL, NEGATIVE_COUNT), see [CHECKS.md](CHECKS.md)
- For UI/UX heuristic rule set (Vercel guidelines + severity tiers + a11y), see [PATTERNS.md](PATTERNS.md)
- For session registration + conflict matrix, see [/_shared/session-protocol.md](/_shared/session-protocol.md)
- For verbose progress + activity-feed events, see [/_shared/verbose-progress.md](/_shared/verbose-progress.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER click destructive buttons** — Delete, Remove, Archive, Disable, Revoke, Destroy, Drop, Purge, Reset, Terminate. When in doubt, do not click.
2. **NEVER fill and submit forms** — tabs, pagination, sort headers, and accordion toggles are OK. Text fields + Submit / Save / Create are not.
3. **NEVER interact with confirmation dialogs** — press Escape immediately. Never click OK / Confirm / Yes / Accept.
4. **NEVER interact with logout / sign-out** — breaks the audit session.
5. **NEVER modify or delete target-app data** — no toggle switches that mutate, no edit-in-place fields.
6. **In `role` modes, never create users dynamically** — all role credentials must come from env vars (`AUDIT_<ROLE>_EMAIL` / `_PASS`); skip any role whose env vars are absent.

---

## Phase 0: CONTEXT

### 0.0 Register Session

Follow the session protocol from [/_shared/session-protocol.md](/_shared/session-protocol.md) **and** the [/_shared/verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions (see Conflict Matrix), read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

### 0.1 Parse Arguments

| Mode | Argument | Behavior |
|------|----------|----------|
| **Full** | `full` or no argument | All configured roles × all pages. Extraction + consistency + quality + heuristics + reporter. |
| **Smoke** | `smoke` | Only `anonymous` + `admin` roles (or single default role if none configured). All pages. |
| **Data** | `data` | Extraction + registry write only. No consistency, no heuristics. Current role only. |
| **Buttons** | `buttons` | Interactive element enumeration + safe-click pass only. (Implementation in E-010.) |
| **Events** | `events` | Analytics interception pass only. (Implementation in E-011.) |
| **Consistency** | `consistency` | Reduce existing registry, evaluate invariants. No browser. Cheap. |
| **Heuristics** | `heuristics` | Vercel + a11y + severity-tier checks. No data extraction. |
| **Role** | `role <name>` | Run `full` phases for a single named role. |
| **Loop** | `--loop` | One `(role, page)` pair per tick. Exits cleanly after the tick completes. Use with `/loop 2m /blitz:ui-audit --loop`. |

Unknown mode → exit 1 with usage message listing the above.

Store the parsed `MODE` and any `ROLE_FILTER` for use in later phases.

### 0.2 Load `.ui-audit.json`

Read `.ui-audit.json` at the project root.

| Mode | Behavior on missing config |
|---|---|
| `full`, `smoke`, `consistency`, `heuristics`, `role <name>` | Error — config required. Print `See .ui-audit.json.example at repo root for schema.` and exit 1. |
| `data` | Stub with `{baseUrl: detected, pages: {}, invariants: []}` and proceed (extraction has no labels to pull — emits INFO "no labels declared"). |
| `buttons`, `events` | Stub (implementations in E-010 / E-011 supply defaults). |

Validate the loaded JSON: top-level keys `baseUrl` (string), `pages` (object), `invariants` (array). Missing required key → error with a pointer to `.ui-audit.json.example`.

### 0.3 Browse-State Overlap Check

Read `docs/crawls/latest-tick.json` (if exists). If `status == "crawling"`, emit WARN: `[ui-audit] WARN: blitz:browse --loop active — reading state that may still be changing. Continuing.` Do not abort — this is per conflict matrix `WARN` outcome.

---

## Phase 1: LOAD STATE

See `reference.md` § **"Phase 1 — LOAD STATE"** for the full procedure. In brief:
1. Attempt to read `docs/crawls/crawl-visited.json` + `docs/crawls/hierarchy.json`. On success, derive the page list from those.
2. On absence, fall back to a lightweight internal crawl: load Playwright MCP tools via `ToolSearch`, navigate each route from the declared route manifest (or `.ui-audit.json[pages]` keys), no fix, no screenshots, no interactions.
3. On Playwright MCP unavailable → exit with error.

---

## Phase 2: DATA EXTRACTION

See `reference.md` § **"Phase 2 — DATA EXTRACTION"** for full procedure (per-page `browser_navigate` → settle → `browser_evaluate(label-map)` → type-coerce + hash + quality-flags → append JSONL line to `docs/crawls/page-data-registry.jsonl`).

Skipped in `consistency` and `heuristics` modes.

---

## Phase 3: CONSISTENCY + INVARIANTS

See `reference.md` §§ **"Phase 3 — CONSISTENCY"**, **"Phase 3 — INVARIANTS"**, and **"Phase 3 — FLAPPING/STALE"**. In brief:
- Reduce the append-only registry to latest-per-(role,page,label) state via `jq group_by`.
- Detect cross-page value divergence; suppress divergences covered by declared invariants.
- Evaluate `equal` / `gte` / `lte` invariants with tolerance. Emit `invariant_fail` + `invariant_pass` events to the activity feed.
- Run tick-over-tick hash diff to classify STABLE / CHANGED / STALE / FLAPPING / NULL_TRANSITION per (role, page, label).

---

## Phase 4: QUALITY CHECKS

See [CHECKS.md](CHECKS.md) for the flag catalog. Implementation body lands in E-009 / CAP-011. For sprint-6, this phase executes the basic NULL_VALUE / PLACEHOLDER / NEGATIVE_COUNT checks inline during extraction (Phase 2) and aggregates findings here.

---

## Phase 5: HEURISTICS

See [PATTERNS.md](PATTERNS.md). Implementation body lands in E-009 / CAP-012. For sprint-6, this phase is a no-op stub that emits INFO "heuristics not yet implemented — see E-009".

---

## Phase 6: REPORT

See `reference.md` § **"Phase 6 — REPORT"** for full procedure. Writes `docs/crawls/ui-audit-report.md`, prints a stdout severity summary + top 3 invariant failures, appends `skill_complete` event to the activity feed with a detail block containing finding counts.

---

## Loop Mode (`--loop`)

When invoked with `--loop`, Phases 0–1 run normally (session register, config load, state load), then one `(role, page)` pair per tick runs through Phases 2 → 3 → partial 6 (reporter emits a rolling report but does not call `skill_complete` until the full matrix closes). Tick state persists in `.cc-sessions/${SESSION_ID}/tmp/loop-state.json` and `docs/crawls/latest-tick.json` gains `ui_audit_matrix` fields (see reference.md).

Budget: tick <2 minutes. Full matrix runtime varies by `|roles| × |pages|`; emit ETA upfront. Recommend nightly CI for full 5-role runs; smoke (anonymous + admin) for PR gates.

---

## Error Recovery

- **Playwright MCP unavailable** — exit 1 with `[ui-audit] Playwright MCP not loaded. Install the playwright plugin or run blitz:browse first to confirm availability.`
- **`.ui-audit.json` invalid JSON** — exit 1 citing the line number from `jq . < .ui-audit.json 2>&1`.
- **Registry file corruption** — on Phase 1 load, run `jq -c '.' < docs/crawls/page-data-registry.jsonl >/dev/null 2>&1 || { mv docs/crawls/page-data-registry.jsonl docs/crawls/page-data-registry.jsonl.corrupt.$(date +%s); echo '[ui-audit] WARN: corrupt registry preserved; starting fresh.'; }`
- **Role env-var absent in `role <name>` mode** — exit 1 with the expected env-var names.
