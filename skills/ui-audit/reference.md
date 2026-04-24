# ui-audit — reference.md

Phase procedures + schemas + JS templates for `skills/ui-audit/SKILL.md`. Read this file when executing the skill's phases.

---

## Schemas

### `.ui-audit.json` (project root)

Top-level keys:

```yaml
baseUrl: string              # Base URL for the target app, e.g. "http://localhost:3000"
pages: object                # Label map: path -> { label -> {selector, type} }
invariants: array            # Cross-page numeric/text invariants (this sprint: equal/gte/lte)
event_invariants: array      # Analytics event schemas — skeleton, populated in E-011
role_invariants: array       # Per-role invariants — skeleton, populated in E-012
role_leak_patterns: array    # Regex strings for role-leak scan — skeleton, populated in E-012
```

`pages[path][label]` shape:
```yaml
selector: string             # CSS selector. Must match one element at eval time.
type: "text" | "number" | "currency" | "count"
```

`invariants[i]` shape:
```yaml
id: string                   # e.g. "INV-001"
description: string
sources:                     # Two or more — each identifies one observation.
  - {page: string, key: string}
check: "equal" | "gte" | "lte"
tolerance: number            # Default 0. For 'equal': |a-b| <= tolerance.
```

See `.ui-audit.json.example` at repo root for a filled template.

### `docs/crawls/page-data-registry.jsonl`

Append-only. One line per observation. Latest-wins-by-`(role, page, label, ts)`.

```jsonl
{"ts":"<ISO-8601>","role":"<role-or-__default__>","page":"<path>","label":"<label>","raw":"<exact scraped string or null>","parsed":<Number|string|null>,"hash":"<8-char hex>","selector":"<css>","tick":<int>,"detail":{<optional per-flag metadata>}}
```

Field semantics:
- `role`: defaults to `"__default__"` when the skill is not in multi-role mode (E-012 introduces real role values).
- `raw`: exact `.textContent.trim()` return — never a11y-tree text. See rule below.
- `parsed`: type-coerced per label `type`. `null` when `raw` was null or coercion failed.
- `hash`: `printf '%s' "$raw" | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-8`. NOT md5sum (not portable on macOS).
- `detail`: optional freeform object — used by quality flags, flapping detection, event-invariants, and heuristics to carry additional structure without bloating the primary fields.

### `docs/crawls/ui-audit-report.md`

Overwritten on every non-`consistency`-only run. Severity-grouped; see Phase 6 for the template.

---

## Phase 0 — CONTEXT

See `SKILL.md` § "Phase 0: CONTEXT". Session registration + arg parse + config load + browse-state overlap check live in the main SKILL.md. This reference file does not duplicate that procedure — it only holds the deeper procedures for phases 1 through 6.

---

## Phase 1 — LOAD STATE

### 1.1 Detect prior browse state

```bash
# Try the cheap read path first
if [ -r docs/crawls/crawl-visited.json ] && [ -r docs/crawls/hierarchy.json ]; then
  STATE_SOURCE=browse
else
  STATE_SOURCE=fallback
fi
```

If `STATE_SOURCE=browse`:
- Read `docs/crawls/crawl-visited.json` — derive the page list from its top-level keys (one per visited path).
- Read `docs/crawls/hierarchy.json` — use the nav graph if Phase 6 reporter wants to group findings by nav parent.
- Read `docs/crawls/latest-tick.json` — if `status == "crawling"`, emit WARN but continue.

Exit Phase 1 with `PAGE_LIST` populated.

### 1.2 Fallback — lightweight internal crawl

If `STATE_SOURCE=fallback`:

1. Load Playwright MCP tools via `ToolSearch`:
   ```
   ToolSearch: query="select:browser_navigate,browser_snapshot,browser_evaluate,browser_wait_for,browser_console_messages,browser_network_requests"
   ```
   If any of the 6 tools is missing, print:
   `[ui-audit] Playwright MCP tools unavailable — install the playwright plugin or run blitz:browse first.`
   and exit 1.

2. Build `PAGE_LIST` from `.ui-audit.json[pages]` keys. If empty (e.g., `data` mode with no config), exit Phase 1 with `PAGE_LIST = []` and log INFO — Phase 2 will no-op.

3. No navigation is done in Phase 1 — Phase 2 owns the per-page visit loop. Phase 1 just produces the list.

### 1.3 Registry corruption guard

Before any later phase reads `docs/crawls/page-data-registry.jsonl`, validate the whole file:
```bash
if [ -f docs/crawls/page-data-registry.jsonl ]; then
  jq -c '.' docs/crawls/page-data-registry.jsonl >/dev/null 2>&1 || {
    CORRUPT="docs/crawls/page-data-registry.jsonl.corrupt.$(date +%s)"
    mv docs/crawls/page-data-registry.jsonl "$CORRUPT"
    echo "[ui-audit] WARN: corrupt registry preserved at $CORRUPT; starting fresh."
  }
fi
```

---

## Phase 2 — DATA EXTRACTION

<!-- Procedures filled in by S6-007 (wave 3). -->

## Phase 3 — CONSISTENCY

<!-- Procedures filled in by S6-008 (wave 4). -->

## Phase 3 — INVARIANTS

<!-- Procedures filled in by S6-009 (wave 5). -->

## Phase 3 — FLAPPING/STALE

<!-- Procedures filled in by S6-010 (wave 4, parallel with S6-008). -->

## Phase 4 — QUALITY

<!-- Phase 4 coordinator here. Per-flag detection details in CHECKS.md. Full body lands in E-009. For sprint-6: basic NULL_VALUE / PLACEHOLDER / NEGATIVE_COUNT run inline during Phase 2; this phase aggregates those findings into the report bundle. -->

## Phase 5 — HEURISTICS

<!-- Phase 5 coordinator here. Rule sources in PATTERNS.md. Full body lands in E-009. For sprint-6: no-op stub — emits INFO "heuristics not yet implemented — see E-009". -->

## Phase 6 — REPORT

<!-- Procedures filled in by S6-011 (wave 6). -->

---

## Shared templates

### Label-extraction JS payload (consumed by Phase 2)

Passed verbatim to `browser_evaluate`. The payload is built per-page by looking up `.ui-audit.json[pages][<path>]` and interpolating each label's `selector` + `type`.

```js
(() => {
  const pick = (sel) => {
    const el = document.querySelector(sel);
    return el ? el.textContent.trim() : null;
  };
  // Interpolated per page at skill-runtime:
  //   for each (label, {selector, type}) in pages[path]:
  //     emit `${JSON.stringify(label)}: pick(${JSON.stringify(selector)}),`
  return {
    /* <INTERPOLATED_LABEL_MAP> */
  };
})()
```

**Ground-truth rule:** never use `browser_snapshot` text for registry writes. The a11y tree reformats numbers (separator stripping for screen-reader reading) and can diverge from DOM `.textContent`. `browser_snapshot` is allowed for render-confirm and selector discovery only.

### JSONL append (single-session safe)

`>>` append is race-safe for a single ui-audit session (matches the `crawl-ledger.jsonl` precedent in `skills/browse/reference.md`). No `flock` needed. Across concurrent sessions the conflict matrix forces BLOCK (see `skills/_shared/session-protocol.md`).

### Latest-wins reducer

```bash
jq -s '
  [.[] | select(.ts != null and .label != null)]
  | group_by([.role, .page, .label])
  | map(max_by(.ts))
' docs/crawls/page-data-registry.jsonl
```

Null-guard on `.ts` and `.label` protects against partial-write rows a crash may leave (domain-researcher gate).

### Activity-feed event format

See `/_shared/verbose-progress.md`. Every event a ui-audit phase emits uses the `ui-audit` skill field:

```jsonl
{"ts":"<ISO-8601>","session":"<SESSION_ID>","skill":"ui-audit","event":"<event-type>","message":"<short>","detail":{<phase-specific>}}
```

Common event types this skill writes:
- `skill_start`, `skill_complete` — lifecycle (Phase 0 / Phase 6)
- `invariant_fail`, `invariant_pass` — Phase 3 invariants
- `flapping`, `stale`, `null_transition` — Phase 3 tick-diff
- `registry_progress` — when Phase 2 appends ≥1 line to the registry (tick-level aggregate, not per-line)
- `decision` — mode fallback, config missing, browse-state overlap WARN, etc.
