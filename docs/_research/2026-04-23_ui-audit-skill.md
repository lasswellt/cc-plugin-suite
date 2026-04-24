<!-- no-registry: skill-design research — capability scope emerges in sprint-plan; no pre-committed artifact counts -->

# blitz:ui-audit — Continuous Cross-Page Consistency & Data-Quality Auditor

**Type:** Feature Investigation | **Date:** 2026-04-23 | **Stack:** cc-plugin-suite (Claude Code skills)

---

## 1. Summary

New skill `blitz:ui-audit` fills gaps `blitz:browse` does not cover. Five coverage dimensions: (1) **numeric/fact consistency** — values for the same logical entity match across pages (`open invoices: 47` on dashboard == list count on /invoices); (2) **interactive element coverage** — every button/link/tab enumerated, labeled, keyboard-reachable, focus-visible, handler-present, safe-clicks exercised without errors; (3) **analytics event consistency** — same event name/props across pages via runtime `dataLayer`+`sendBeacon`+network interception; (4) **per-permissions-role matrix** — entire audit runs per role (anonymous/viewer/member/admin/superadmin), registry namespaced by role, cross-role invariants catch privilege boundaries (role leaks, data divergence); (5) **UI/UX heuristics** — Vercel guidelines + UX Pro Max severity tiering + a11y. Visual-regression tools (Percy/Chromatic/Applitools) explicitly mask numeric changes as noise and ignore role matrix entirely — no mainstream tool solves these together. Build standalone sibling skill in `quality` category. Extraction via Playwright MCP `browser_evaluate` (ground-truth `.textContent`, single round-trip). Persist labeled values + button findings + events + per-role observations to `docs/crawls/page-data-registry.jsonl` (append-only, latest-wins-by-id, `role` field defaults `__default__`). Invariants declared in project-root `.ui-audit.json` (three blocks: `invariants`, `event_invariants`, `role_invariants`). Loop-mode tick cycles `(role, page)` pairs — `/loop 2m` processes one pair per tick; full 5-role × 20-page matrix completes in ~200 min (nightly CI territory). `anonymous + admin` smoke at ~80 min.

---

## 2. Research Questions

| Q | Answer |
|---|---|
| Extend `browse` or new skill? | **New sibling.** Tick-budget pressure (browse 27–115s); separation-of-concerns (crawl+fix vs audit); precedent (`integration-check` read-only sibling to `sprint-dev`). |
| Best extraction primitive? | **`browser_evaluate`** returning object literal. Ground-truth `.textContent`, multi-value single round-trip. Use `browser_snapshot` only for render-confirm + first-tick discovery (a11y tree truncates numbers). |
| Registry schema? | Append-only JSONL: `{ts,page,label,value,raw,hash,tick}`. Reducer: `jq -s 'group_by(.label)'` → flag cross-page mismatches. |
| Invariant declaration? | `.ui-audit.json` at project root: `{invariants:[{id,sources:[{page,key}],check:equal|gte,tolerance}]}`. User-editable. |
| Firecrawl fit? | Optional fallback only. `/extract` endpoint gives schema-based LLM extraction — useful when selectors are fragile (CMS), but 2–5s/page + API key. Not default. |
| Prior art? | ATUSA (IEEE TSE 2011) — DOM invariants as Ajax test oracles. Direct conceptual match. |
| Flapping / cache jitter? | Hash `raw`; categorize STABLE/CHANGED/STALE/FLAPPING (oscillates ≥3 ticks between two values). |

---

## 3. Findings

### 3.1 Gap analysis vs existing `blitz:browse`

Browse (`skills/browse/SKILL.md`, loop mode phases 3-LOOP–7-LOOP) covers:
- Console errors + network failures (Phase 4.3) — complete
- Placeholder regex (`Lorem ipsum`, `TODO`, `John Doe`) — generic, not domain-aware
<!-- no-registry: describes browse's existing behavior, not a ui-audit deliverable -->
- Structural cross-page comparison (Phase 5.6: breadcrumbs presence, card_count, table_row_count, heading hierarchy) — outlier detection after ≥10 pages
- Auto-fix (Phase 6) — bounded, verified

Browse does **not**: extract labeled domain values, define cross-page invariants, assert `values on A == values on B`, track value history, detect cache flapping.

State files Browse writes (`docs/crawls/`) are readable by the new skill — no re-crawl needed when `latest-tick.json.status == complete`:
- `crawl-visited.json` — per-page `structure` block
- `hierarchy.json` — nav graph
- `crawl-ledger.jsonl` — findings log

### 3.2 Extraction technique (Playwright MCP)

`browser_evaluate` payload returns a labeled object in one call:
```js
(() => {
  const pick = (sel) => document.querySelector(sel)?.textContent.trim() ?? null;
  return {
    openInvoices: pick('[data-metric="open-invoices"] .value'),
    revenue:      pick('.revenue-total'),
    planTier:     pick('[data-user-plan]'),
  };
})()
```
Accessibility-tree text from `browser_snapshot` truncates long numbers and can reformat — do NOT use for registry writes. Ground truth = DOM `.textContent`.

### 3.3 Registry + invariants

Registry line (append-only):
```jsonl
{"ts":"2026-04-23T22:58:00Z","page":"/dashboard","label":"open_invoices","raw":"47","parsed":47,"hash":"a1b2","selector":"[data-metric=…]","tick":22}
{"ts":"2026-04-23T22:59:00Z","page":"/invoices","label":"open_invoices","raw":"46","parsed":46,"hash":"c3d4","selector":".invoice-list .badge","tick":23}
```
Invariant config:
```json
{ "id":"INV-001","sources":[{"page":"/dashboard","key":"open_invoices"},{"page":"/invoices","key":"open_invoices"}],"check":"equal","tolerance":0 }
```
Reducer evaluates each tick; emits `invariant_fail` to activity feed + report.

### 3.4 Data-quality checks (per-value, in-extraction JS)

| Flag | Rule |
|---|---|
| `NULL_VALUE` | `parsed === null` |
| `PLACEHOLDER` | `/lorem\|TODO\|FIXME\|N\/A\|--\|\?\?\?/i` on raw |
| `FORMAT_MISMATCH` | currency/decimal separator differs from prior observations for same label |
| `STALE_ZERO` | `parsed === 0` but registry history shows non-zero for same `(page,label)` |
| `BROKEN_TOTAL` | sum(child values) ≠ parent total (footer vs rows) |
| `NEGATIVE_COUNT` | `parsed < 0` on count field |

### 3.5 Flapping / tick diff

Per-value hash compared tick-over-tick:
- STABLE (same hash) / CHANGED (update registry) / STALE (reverted within 2 ticks → cache jitter) / FLAPPING (oscillates between two values ≥3 ticks) / NULL_TRANSITION (real→null, flag immediately).

### 3.6 Ideas borrowed from referenced skills

| Skill | Technique adopted |
|---|---|
| **Firecrawl Skill+CLI** | Schema-based per-page extraction; `--limit` crawl bound; `--main-only` stripping; mode flags. `/extract` as optional LLM fallback. |
| **UI/UX Pro Max** | 4-tier severity (CRITICAL/HIGH/MED/LOW); `--domain ux` dedicated pass; master+per-page override config pattern → global invariants + per-route overrides. |
| **Vercel Web Interface Guidelines** | 17-category rule taxonomy; live-fetch rules from URL at runtime (not baked); `file:line` finding format; anti-pattern blocklist. Categories 9 (Nav+State, URL reflects filters) and 16 (Content+Copy, numerals for counts) directly relevant. |
| **Bencium UX Designer** | Multi-file layout (SKILL.md + CHECKS.md + PATTERNS.md + ACCESSIBILITY.md); always-ask-first protocol (target URL, auth, expected labels before loop starts); controlled vs exploratory mode split. |
| **Unlighthouse** | Per-page Lighthouse scores as optional tier (track perf/a11y/SEO trend in registry). |

---

### 3.7 Interactive element coverage (every button, link, tab)

Enumerate — do not click-indiscriminately. Single `browser_evaluate` returns the full interactive set per page with zero side-effects:

```js
(() => {
  const ROLES = ['button','link','checkbox','radio','tab','menuitem','combobox','listbox','switch','slider','spinbutton'];
  const roleQ = ROLES.map(r => `[role="${r}"]`).join(',');
  const nativeQ = 'button,a[href],input:not([type=hidden]),select,textarea,[tabindex]';
  return [...new Set([...document.querySelectorAll(roleQ), ...document.querySelectorAll(nativeQ)])].map(el => ({
    tag: el.tagName.toLowerCase(),
    role: el.getAttribute('role') ?? el.tagName.toLowerCase(),
    label: el.getAttribute('aria-label') ?? el.textContent?.trim().slice(0,80) ?? el.getAttribute('placeholder') ?? null,
    tabindex: el.getAttribute('tabindex'),
    hrefOrOnclick: el.getAttribute('href') ?? el.getAttribute('onclick') ?? null,
    outerSnip: el.outerHTML.slice(0,120),
  }));
})()
```

Per-element checks → finding format `page:button_label:issue`:

| Check | Condition | Code |
|---|---|---|
| Missing label | `label` null/empty | `NO_LABEL` |
| Dead href | `href === '#'` | `DEAD_HREF` |
| Empty handler | `onclick === ''` | `EMPTY_HANDLER` |
| Bad tabindex | integer ≥1 | `TABINDEX_POSITIVE` |
| Hidden from keyboard | `tabindex === '-1'` on visible non-decorative element | `TABINDEX_NEGATIVE_VISIBLE` |
| Missing focus ring | `getComputedStyle(el).outlineWidth === '0px' && boxShadow === 'none'` after `el.focus()` | `NO_FOCUS_STATE` |

**Safe-click classifier** (before any `browser_click`):
```js
const DESTRUCTIVE_LABELS = /delete|remove|logout|sign.?out|cancel|submit|pay|confirm/i;
const DESTRUCTIVE_HREF   = /\/logout|\/delete|\/remove/i;
const isSafe = !DESTRUCTIVE_LABELS.test(label ?? '') && !DESTRUCTIVE_HREF.test(hrefOrOnclick ?? '');
```
Only `isSafe` elements get clicked. Destructive elements are audit-only (label+a11y check, no interaction). Reuses `blitz:browse` safety rules.

Coverage summary line per page tick:
```jsonl
{"page":"/dashboard","label":"interactive_audit_summary","total":42,"labeled":40,"dead_href":1,"no_handler":0,"tabindex_broken":2,"safe_clicked":18,"click_errors":0,"tick":7}
```

### 3.8 Analytics event consistency (every event matches across pages)

Three interception layers, stacked (apps mix transports):

- **Layer A — `window.dataLayer` push proxy** (GA4/GTM). Inject immediately after `browser_navigate` returns, before any interaction:
  ```js
  window.__auditEventLog = [];
  const _push = (window.dataLayer ||= []).push.bind(window.dataLayer);
  window.dataLayer.push = (...a) => (window.__auditEventLog.push({layer:'dataLayer',ts:Date.now(),payload:JSON.parse(JSON.stringify(a))}), _push(...a));
  ```
- **Layer B — `navigator.sendBeacon` wrap** (GA4 hit transport):
  ```js
  const _b = navigator.sendBeacon.bind(navigator);
  navigator.sendBeacon = (url,data) => (window.__auditEventLog.push({layer:'beacon',ts:Date.now(),url,body:typeof data==='string'?data:'[binary]'}), _b(url,data));
  ```
- **Layer C — network-level** via `browser_network_requests`. Filter hostnames: `api.segment.io`, `app.posthog.com`, `api2.amplitude.com`, `/g/collect` (GA4).

Drain the log after each action: `window.__auditEventLog.splice(0)`. Both original `push` and `sendBeacon` still run — events reach production analytics unchanged.

Registry extension (label `analytics_event`):
```jsonl
{"page":"/checkout","label":"analytics_event","detail":{"event_name":"begin_checkout","layer":"dataLayer","action_trigger":"click:Proceed","props":{"currency":"USD","value":99}},"hash":"abc1","tick":12}
```
Key: `(page, action_trigger) → {event_name, props}`.

Cross-page drift detection (consistency phase):
```bash
jq -s '[.[]|select(.label=="analytics_event")]
  | group_by(.detail.event_name)
  | map({event: .[0].detail.event_name, pages: (group_by(.page) | map({page:.[0].page, props_hash:.[0].hash}))})
  | map(select(.pages|length>1))
  | map(select((.pages|map(.props_hash)|unique|length)>1))' docs/crawls/page-data-registry.jsonl
```
Emits events firing on >1 page with diverging prop schemas (event drift).

Invariant config (`.ui-audit.json`):
```json
"event_invariants": [
  {"id":"EV-001","event_name":"page_view","required_props":["page_path","page_title"],"forbidden_props":["user_email"],"scope":"all_pages"},
  {"id":"EV-002","event_name":"cta_click","required_props":["cta_label","cta_location"],"scope":"pages_with_cta"}
]
```

Prior art: Segment Typewriter (SDK-level, not runtime), Snowplow Micro (overkill for GA4/Segment stacks), GA4 DebugView (manual). Runtime dataLayer proxy + network-level is the selected default — zero deps, works across any analytics stack.

### 3.9 Per-permissions-role audit matrix (every page × every role)

Full audit multiplies: crawl the site **once per role**, separate registry namespace per role, cross-role invariants catch permission bugs (role leaks, data mismatches).

**Roles** (skip-if-env-var-absent):
```
AUDIT_ANONYMOUS=true                           # no login
AUDIT_VIEWER_EMAIL / _PASS
AUDIT_MEMBER_EMAIL / _PASS
AUDIT_ADMIN_EMAIL  / _PASS
AUDIT_SUPERADMIN_EMAIL / _PASS
```
Pre-provisioned test accounts required. Do NOT create accounts dynamically.

**Auth state pattern** (Playwright `storageState` adapted for MCP):

Playwright Node API has `browserContext.storageState()`; MCP surface does not expose it. Harvest manually after scripted login:
```js
// After successful login, browser_evaluate:
({localStorage: Object.fromEntries(Object.entries(localStorage)),
  sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
  cookies: document.cookie})
```
Write result to `.auth/<role>.json` via `Write`. On role switch, either replay the login (reliable, slow) or inject localStorage+cookies (fast, brittle). Default: replay login per role transition; cache optional.

**Registry extension** — add `role` field (defaults to `"__default__"` for backward compat):
```jsonl
{"role":"admin","page":"/users","label":"user_count","raw":"142","parsed":142,"tick":3}
{"role":"viewer","page":"/users","label":"user_count","raw":null,"parsed":null,"tick":4}
```

**Role invariants** (`.ui-audit.json`):
```json
"role_invariants": [
  {"id":"ROLE-001","description":"Own email identical across authenticated roles",
   "sources":[{"role":"viewer","page":"/profile","key":"own_email"},{"role":"admin","page":"/profile","key":"own_email"}],
   "check":"equal"},
  {"id":"ROLE-002","description":"Admin user list not visible to viewer",
   "sources":[{"role":"admin","page":"/users","key":"user_count"},{"role":"viewer","page":"/users","key":"user_count"}],
   "check":"viewer_null"}
]
```
Checks: `equal` (both roles must match — e.g., own data), `viewer_null` (viewer must be null/absent, admin non-null — privilege boundary), `gte` (admin count ≥ viewer count — partial visibility).

**Role-leak detection** — scan HTML source when authenticated as non-admin:
```js
const html = document.documentElement.outerHTML;
[/data-admin-only/i, /admin.?panel/i, /<script[^>]*>.*?admin.*?<\/script>/is]
  .filter(re => re.test(html)).map(re => re.source)
```
Patterns are extensible via `.ui-audit.json[role_leak_patterns]`. Any match → `ROLE_LEAK` finding at severity CRITICAL (privilege boundary violation).

**Loop cadence — `(role, page)` tick cycle:**
```
tick N:   role=viewer, page=/dashboard  → extract + role-invariant eval
tick N+1: role=viewer, page=/invoices   → extract
tick N+2: role=admin,  page=/dashboard → extract + diff vs viewer
tick N+3: role=admin,  page=/invoices  → extract + ROLE-001 eval
…
```
<!-- no-registry: illustrative runtime calc — user's app dimensions, not artifact counts -->
Full matrix = `|roles| × |pages|` ticks. At `/loop 2m` with 5 roles × 20 pages = ~200 minutes (~3.3 h). Emit upfront warning: **recommend `full` multi-role mode for nightly CI only, not interactive sessions.** Smoke mode: `anonymous + admin` only (~80 min).

`latest-tick.json` extension:
```json
{"mode":"role_matrix","current_role":"admin","current_page_idx":4,
 "roles_complete":["anonymous","viewer"],"roles_pending":["admin","member","superadmin"]}
```

Tick state machine: `LOAD_AUTH[role] → NAVIGATE[page] → EXTRACT → QUALITY → EVENT_DRAIN → INVARIANTS → WRITE[role,page] → NEXT`.

---

## 4. Compatibility Analysis

- **Playwright MCP**: already used by `browse`. Zero new runtime deps. `browser_evaluate` + `browser_snapshot` + `browser_console_messages` are the full tool surface.
- **Browse state coupling**: `ui-audit` reads `docs/crawls/*` — add `page_data_registry` field to `latest-tick.json` schema (1-line PR to `browse/reference.md`).
- **Session protocol**: conforms to `skills/_shared/session-protocol.md`. Conflict matrix: `ui-audit × browse(loop) = WARN` (reads state being written); `ui-audit × sprint-dev = OK` (read-only).
- **No code modification**: `modifies_code: false` in registry. Reports only.
- **Firecrawl**: opt-in only (env var API key). Not required.

---

## 5. Recommendation

**Build `blitz:ui-audit` as a standalone sibling skill in category `quality`.**

### File layout
```
skills/ui-audit/
  SKILL.md                  # phases 0–6, safety rules, argument hint
  reference.md              # label-extraction JS templates, heuristic catalog, report template
  CHECKS.md                 # data-quality rule catalog (NULL_VALUE, PLACEHOLDER, …)
  PATTERNS.md               # Vercel-style anti-pattern DOM blocklist
```

### Frontmatter
```yaml
---
name: ui-audit
description: Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts labeled value registry, asserts invariants, flags placeholders/nulls/flapping values. Read-only. Loop-safe.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus                    # MUST be opus — survives [1m] parent context; sonnet/haiku crash at load. See §6.1.
effort: low                    # Orchestrator is routing + synthesis, not heavy reasoning. Heavy work is in sonnet workers.
compatibility: ">=2.1.50"
argument-hint: "[mode] -- modes: full | data | consistency | heuristics | --loop"
---
```

Heavy work (heuristic scans, per-page extraction when parallelized) is delegated to spawned Agents with explicit `model: sonnet` — see §6.1 for the spawn pattern.

### Modes
- `full` — all phases, all configured roles, all pages. Nightly-CI duration (~200 min for 5×20 matrix).
- `smoke` — `anonymous + admin` roles only, all pages (~80 min). Default for PR checks.
- `data` — numeric extraction + registry only; current role only.
- `buttons` — interactive element enumeration + safe-click pass only; current role.
- `events` — analytics interception pass only; requires real user interaction (safe-clicks).
- `consistency` — reduce existing registry, evaluate invariants (numeric + event + role) only. No browser. Cheap.
- `heuristics` — Vercel + a11y + UX Pro Max tier checks only.
- `role <name>` — run `full` phases but only for a single named role.
- `--loop` — one `(role, page)` pair per tick. State machine per §3.9. Terminates after 2 full passes of the matrix (pass 1 builds registry, pass 2 detects drift).

### Comparison matrix: options evaluated

| Option | Effort | Reuse | Drift risk | Verdict |
|---|---|---|---|---|
| Extend `browse` with extraction phase | HIGH | HIGH | Tick budget blows past 2min; SKILL.md hits 500+ lines | REJECT |
| New `ui-audit` sibling, reads browse state | MED | HIGH | None — clean boundary | **SELECTED** |
| Standalone, independent crawler | HIGH | LOW | Duplicates browse navigation logic | REJECT |
| Firecrawl-only LLM extraction | LOW | MED | API cost, latency, key dep | REJECT (keep as fallback) |

---

## 6. Implementation Sketch

### Phase 0 — CONTEXT
Session register per `session-protocol.md`. Parse mode arg. Load `.ui-audit.json` (error if absent on `full`/`consistency`; stub with empty `invariants:[]` on `data` mode). Check `docs/crawls/latest-tick.json`; if `status=="crawling"`, WARN.

### Phase 1 — LOAD STATE
Read `docs/crawls/crawl-visited.json`, `hierarchy.json`. If absent → lightweight internal crawl (Playwright MCP, navigate route manifest, no fix, no screenshots). Build page list.

### Phase 2 — DATA EXTRACTION (per page)
1. `browser_navigate(baseUrl + path)`, wait for network idle + landmarks (reuse browse Phase 3.1 wait logic).
2. `browser_snapshot` — confirm render + discover candidate selectors (first-pass only per page).
3. `browser_evaluate` with label-map from `.ui-audit.json[page]` — one-shot object return.
4. Apply in-extraction quality JS (null/placeholder/negative/format regexes).
5. Append one JSONL line per `(page,label)` to `docs/crawls/page-data-registry.jsonl`.

### Phase 3 — CONSISTENCY CHECK
```bash
jq -s 'group_by(.label)
  | map({label: .[0].label,
         obs: group_by(.page) | map(max_by(.ts))})' \
  docs/crawls/page-data-registry.jsonl
```
For each `label` group with >1 distinct `parsed` across pages: emit finding (unless covered by explicit invariant with tolerance). Evaluate declared invariants from `.ui-audit.json`. Flapping detection: look back ≥3 ticks of same `(page,label)`.

### Phase 4 — QUALITY CHECKS
Aggregate per-page quality flags from extraction phase. Domain-aware: if label declared `currency` in config, FORMAT_MISMATCH fires on separator drift.

### Phase 5 — HEURISTIC AUDIT
Load Vercel Web Interface Guidelines from upstream URL at runtime (per Vercel skill pattern). Evaluate categories 9 (Nav+State) and 16 (Content+Copy, tabular-nums) against snapshots. Tier by severity (UI/UX Pro Max ladder): CRITICAL (a11y/contrast/touch target) / HIGH / MED / LOW.

### Phase 6 — REPORT
Write `docs/crawls/ui-audit-report.md` — `file:line` for code-citable findings, `page:label` for registry findings. Stdout summary: counts by severity + top 3 invariant failures. Log `skill_complete` to activity feed.

### 6.1 Model selection — surviving `[1m]` context inheritance

Claude Code propagates the `[1m]` flag from a parent session (`claude-opus-4-7[1m]`) into any skill sub-context regardless of the skill's declared `model`. Skills with `model: sonnet` or `model: haiku` crash at **load time** with `Extra usage is required for 1M context · run /extra-usage` — before Phase 0 can run. No frontmatter field (including `context: fork`) bypasses this; only Opus 4.7 handles 1M natively.

**Rule for this skill:**

1. **Orchestrator frontmatter MUST be `model: opus`.** `ui-audit/SKILL.md` is user-invoked (`/blitz:ui-audit`) and must load reliably from any parent, including `[1m]` Opus sessions. The earlier draft frontmatter in §5 specifies `model: sonnet` — **change to `model: opus`** before authoring.

2. **Heavy work goes to spawned Agents with explicit `model: sonnet`.** Agents get independent model + context; the `[1m]` flag does NOT propagate through `Agent` tool spawns. Sonnet workers keep per-tick cost low while the Opus orchestrator handles routing + synthesis.

3. **Spawn pattern (applies to Phase 5 heuristics sub-agents — OQ4, and any parallel extraction agents):**
   ```
   Agent(
     description: "ui-audit <agent-name>",
     subagent_type: "general-purpose",     // not Explore — workers must Write findings files
     model: "sonnet",                       // EXPLICIT — prevents [1m] inheritance from Opus orchestrator
     prompt: <task + output-file path + limits>,
     run_in_background: true,
   )
   ```
   The `model: "sonnet"` field is load-bearing — omitting it lets the orchestrator's model (Opus, possibly `[1m]`) inherit to the worker, re-introducing the crash.

4. **Inline-vs-spawn decision (refines OQ4):** if page count ≤30, run heuristic checks inline in the Opus orchestrator (cheap, no spawn overhead). If >30, spawn parallel sonnet workers per heuristic category (Vercel / a11y / UX-Pro-Max tiers) — the cost delta justifies the orchestration.

5. **Do NOT use `model: sonnet` on any skill frontmatter in this repo if the skill is directly user-invoked.** This is a repo-wide rule, not specific to ui-audit. Existing sonnet skills at risk: `test-gen, completeness-gate, dep-health, todo, integration-check, health, quality-metrics, codebase-map, next, quick` (per prior audit; verify current state before acting).

6. **If Claude Code adds a frontmatter field to control context-window inheritance** (e.g., `context-window: standard`), revisit and downgrade the orchestrator to sonnet — that would be the real fix.

#### Alias syntax — authoritative citations

Both places where this skill names a model accept bare aliases (`sonnet`/`opus`/`haiku`). No full ID needed, no quotes required in YAML.

- **Skill frontmatter `model:`** — [Claude Code Skills docs](https://code.claude.com/docs/en/skills.md): "Accepts the same values as `/model`... or `inherit` to keep the active model." The `/model` command accepts aliases per [Model Configuration](https://code.claude.com/docs/en/model-config.md): `sonnet` → "latest Sonnet", `opus` → "latest Opus". Aliases auto-resolve to the current family version (Sonnet 4.6 / Opus 4.7 as of 2026-04-23) and track upgrades over time.
- **Subagent frontmatter `model:`** — [Subagents docs](https://code.claude.com/docs/en/sub-agents.md): "`model`: Model to use: `sonnet`, `opus`, `haiku`, a full model ID (for example, `claude-opus-4-7`), or `inherit`. Defaults to `inherit`."
- **`Agent` tool `model` parameter** (in-session tool, what this skill uses at runtime) — JSON-Schema `enum: ["sonnet", "opus", "haiku"]`. Full IDs are NOT accepted here; only the three aliases. `"sonnet"` is therefore the correct value for spawn calls.

**Important nuance:** `inherit` (subagent default) is exactly what re-introduces the `[1m]` crash when the parent is `opus[1m]`. Spawns MUST pass an explicit `model: "sonnet"` — omitting the field inherits the parent including the `[1m]` flag.

#### `effort` — reasoning budget

Claude Code supports an `effort` field (`low` / `medium` / `high` / `xhigh` / `max`) in skill and subagent YAML frontmatter that caps adaptive reasoning spend ([model-config.md — Adjust effort level](https://code.claude.com/docs/en/model-config.md#adjust-effort-level)). Supported on Opus 4.7 / Opus 4.6 / Sonnet 4.6; Haiku does not support effort levels.

**Rule for this skill:**

- **Orchestrator frontmatter: `effort: low`.** The Opus orchestrator does routing, state reads, report assembly, and JSONL reducing — none of which benefit from deep reasoning. `low` is the right default and materially cuts per-tick cost (Opus base rate × low-effort budget ≪ Opus × default).
- **Persistent subagents** (if this skill ever ships markdown-defined subagents in `skills/ui-audit/agents/`): use `effort: low` on the frontmatter for the same reason — they are extraction workers, not reasoners.
- **In-session `Agent` tool spawns** (the runtime spawn pattern in §6.1): the `Agent` tool JSON-Schema does **NOT** expose an `effort` parameter — only `model`, `subagent_type`, `prompt`, etc. For ad-hoc workers, effort falls back to the session default (configurable via `effortLevel` in `settings.json` or the `/effort` command). If a worker genuinely needs bounded effort, define it as a persistent subagent markdown file with `effort:` in frontmatter instead of an ad-hoc spawn.
- **Do not set `effort` on haiku workers** — unsupported, will error or be silently ignored.

### Key files to create
- `skills/ui-audit/SKILL.md`
- `skills/ui-audit/reference.md`
- `skills/ui-audit/CHECKS.md`
- `skills/ui-audit/PATTERNS.md`
- Registry entry in `.claude-plugin/skill-registry.json`
- Conflict-matrix row in `skills/_shared/session-protocol.md`
- 1-line addition to `skills/browse/reference.md` (`latest-tick.json.page_data_registry` field)
- Example `.ui-audit.json.example` at repo root

---

## 7. Risks

**R1 — Selector fragility.** Apps without `data-*` attributes force selectors onto unstable class names. When a selector misses, the value silently becomes `null` and pollutes the registry with false NULL_VALUE flags. **Mitigation:** require labels be declared in `.ui-audit.json` with explicit selectors; on ≥2 consecutive `null` observations for a declared label, promote to `SELECTOR_BROKEN` (distinct from `NULL_VALUE`) and suggest Firecrawl `/extract` fallback mode. The reason this matters is that a noisy registry erodes user trust in the very first loop runs.

**R2 — Data that legitimately differs across pages.** A badge count on `/dashboard` may intentionally show *unread* notifications while `/inbox` shows *total*. Treating both as the same invariant produces false positives. <!-- no-registry: detection-threshold inequality, not an artifact count -->
**Mitigation:** invariants are opt-in (declared, not inferred). The skill does NOT infer cross-page invariants from matching labels alone — it only evaluates what the user declared in `.ui-audit.json`. On `data` mode, the skill may *suggest* candidate invariants (same label observed on ≥2 pages with matching values over ≥3 ticks) but never auto-activate them.

**R3 — Loop overlap with `browse --loop`.** Both skills want to own the browser. **Mitigation:** conflict-matrix WARN; ui-audit defers to browse if `latest-tick.json.status=="crawling"`. If the user truly wants continuous audit during active crawl, document the race condition and recommend sequential `/loop` cadence (browse every 5m, ui-audit every 15m offset).

**R4 — Registry unbounded growth.** Append-only JSONL grows without bound on long-running loops. **Mitigation:** nightly compaction via `jq -s 'group_by(.page+.label) | map(.[-100:]) | flatten'` keeps last 100 observations per `(page,label)`. Wire into existing session cleanup protocol.

**R5 — `[1m]` context inheritance crash.** Skills declared with `model: sonnet`/`haiku` crash at load when invoked from a `claude-opus-4-7[1m]` parent — before Phase 0 runs. Silent footgun: the crash looks like a missing-usage error, not a skill bug. **Mitigation:** orchestrator frontmatter `model: opus`; spawned Agents pass explicit `model: "sonnet"` to avoid Opus inheritance at worker level. Full pattern in §6.1. The reason this matters is that a sonnet orchestrator will work for most users and silently fail for the exact power users who run `[1m]` contexts — a bad failure mode.

**R6 — `.ui-audit.json` maintenance burden.** Users must hand-author label/selector mappings, which drift with UI refactors. **Mitigation:** in `data` mode with no config, emit a *suggested* config from first-tick snapshot heuristics (elements with `data-metric`, `data-test-id`, badges near numeric text) to bootstrap. Still user-curated; not auto-activated.

**R7 — Interactive element enumeration false-positives.** Custom components (`<div role="button">` without `tabindex`) appear in the enumeration but fail keyboard-reachability checks. Frameworks (Vue, React) sometimes inject `tabindex` dynamically on mount, so an early snapshot can show a transient missing state. **Mitigation:** surface `TABINDEX_MISSING` at MEDIUM severity (not CRITICAL); re-check after a 500ms settle window before writing the finding. Real a11y bugs persist after settle.

**R8 — Analytics spy timing.** The `dataLayer` proxy injected via `browser_evaluate` runs *after* DOMContentLoaded, so events fired during initial parse (SSR hydration, `gtag('config',…)`, early route-change pings) are missed. **Mitigation:** inject immediately after `browser_navigate` returns but before further interaction; flag `EVENTS_BEFORE_SPY` if `window.dataLayer.length > 0` at inject time (those entries pre-date the proxy and lack timestamps — record them but mark as low-fidelity). The reason this matters is that `page_view` is often the earliest event and the most important one to audit.

**R9 — Role session contamination.** Reusing the same browser context across roles leaks cookies/localStorage. A viewer pass after an admin pass may see admin-cached data and pass an invariant that should fail. **Mitigation:** between role transitions, `browser_evaluate` clears `localStorage.clear()`, `sessionStorage.clear()`, and document.cookie; then re-run the scripted login flow. On MCP surfaces that expose `browser_close`, prefer a full close+reopen per role (slower but guaranteed clean). Verify each role-switch with a sentinel check: first page after switch must reflect the *new* role's auth state (navigate to `/profile`, assert displayed email matches the expected role's fixture email) before running any audit phase for that role.

<!-- no-registry: illustrative runtime calc — user's app dimensions, not artifact counts -->
**R10 — Full-matrix runtime.** 5 roles × 20 pages × 2 min/tick = 200 min. Interactive users who run `/blitz:ui-audit full` expecting a 5-minute result will be unhappy. **Mitigation:** on invocation, print an ETA before starting: `ROLES=n PAGES=m ETA=n*m*2min`; prompt for confirmation on >60 min unless `--yes`. Default interactive mode is `smoke` (anonymous+admin). `full` requires explicit opt-in or `--ci` flag.

### Open Questions

- **OQ1** — Should `ui-audit` spawn Playwright MCP independently or require `browse` prerequisites phase already executed? Leaning toward independent init (lower friction) with early-exit if browse is loop-active.
- **OQ2** — Live-fetch Vercel rules at runtime (per Vercel skill) vs vendor them into `PATTERNS.md`? Vendor risks staleness; live-fetch risks offline failure. Recommend vendor-with-upstream-URL-noted.
- **OQ3** — Is invariant declaration YAML or JSON? JSON matches Playwright/Firecrawl schema world; YAML matches skill frontmatter. Lean JSON (machine-readable, no indentation traps).
- **OQ4** — Should heuristics phase spawn sub-agents (parallel Vercel/UX-Pro-Max/Bencium checkers) per `integration-check` pattern? Probably yes if page count >30; otherwise inline. Same threshold applies to the role-matrix phase — >30 `(role,page)` pairs pending, parallelize.
- **OQ5** — Should the loop drain the analytics event log after every safe-click, or batch per page? Batching is cheaper but risks losing association between click and event. Default: drain-per-click with a timestamp, reassemble in reporter.
- **OQ6** — Role-transition cost: replay login (~5s) vs restore storageState (~100ms but brittle). Default replay; offer `--fast-role-switch` flag for users who verify their storage snapshots work.

---

## 8. References

- `skills/browse/SKILL.md`, `skills/browse/reference.md` — existing crawl/fix engine
- `skills/_shared/session-protocol.md`, `carry-forward-registry.md`, `verbose-progress.md`, `terse-output.md`
- `skills/integration-check/SKILL.md` — read-only sibling precedent
- Playwright docs: [evaluating](https://playwright.dev/docs/evaluating), [MCP](https://playwright.dev/mcp/introduction)
- Playwright MCP deep-dive: https://autify.com/blog/playwright-mcp
- Firecrawl `/extract`: https://docs.firecrawl.dev/features/llm-extract
- Firecrawl skill (BexTuychiev): https://github.com/BexTuychiev/firecrawl-claude-code-skill
- UI/UX Pro Max: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- Vercel Web Interface Guidelines: https://vercel.com/design/guidelines + https://github.com/vercel-labs/agent-skills/blob/main/skills/web-design-guidelines/SKILL.md
- Bencium UX Designer: https://github.com/bencium/bencium-claude-code-design-skill
- Unlighthouse: https://unlighthouse.dev
- Percy vs Chromatic: https://medium.com/@crissyjoshua/percy-vs-chromatic-which-visual-regression-testing-tool-to-use-6cdce77238dc
- ATUSA (invariant-based web testing): https://dl.acm.org/doi/10.1109/TSE.2011.28
- LLM agent browser automation for analytics: https://nhinternesch.medium.com/llm-agent-based-browser-automation-for-digital-analytics-using-vs-code-playwright-mcp-server-56afbfd35e2b
- Satellite hash-diff testing: https://www.validatar.com/holistic-data-qa/satellite-hash-diff-testing-what-most-teams-miss
