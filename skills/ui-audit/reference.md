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

Per page, run the 5-step loop below. Emits one JSONL line per `(role, page, label)` observation. `role` is `__default__` in sprint-6 (multi-role arrives in E-012).

### 2.1 Navigate + settle

```
browser_navigate(url = baseUrl + path)
# Settle:
browser_wait_for(textGone = "<spinner-or-loading-label>", time = 1)
# Fallback hard timeout — no networkidle in Playwright MCP.
```

Max settle wait: 10 seconds. Proceed with whatever is rendered at timeout.

### 2.2 Render confirm (optional, first tick per page only)

```
browser_snapshot()
```

Used to verify the page rendered and — on the first tick per path — to discover candidate selectors the author may not yet have declared. **Never used for registry writes** (a11y tree can reformat numbers; see the ground-truth rule above).

### 2.3 Evaluate label map

Build the label map for this `path` from `.ui-audit.json[pages][path]`. If no entry, log INFO `[ui-audit] no labels declared for ${path} — skipping` and move to the next page.

```js
(() => {
  const pick = (sel) => {
    const el = document.querySelector(sel);
    return el ? el.textContent.trim() : null;
  };
  return {
    // e.g.:
    open_invoices: pick('[data-metric="open-invoices"] .value'),
    total_revenue: pick('.revenue-total'),
    // ... one entry per declared label in .ui-audit.json[pages][path]
  };
})()
```

Pass the compiled payload as the `script` parameter to `browser_evaluate`. Return value is a plain object keyed by label.

If the returned object is large (> ~1 KB), offload via `browser_evaluate`'s `filename` parameter and read the file — don't inline giant strings into the orchestrator context.

### 2.4 Coerce + hash + quality-flag (inline JS)

For each `(label, raw)` pair returned by the evaluate call:

```bash
LABEL_TYPE=$(jq -r ".pages[\"$PATH\"][\"$LABEL\"].type" .ui-audit.json)
SELECTOR=$(jq -r ".pages[\"$PATH\"][\"$LABEL\"].selector" .ui-audit.json)

case "$LABEL_TYPE" in
  number)   PARSED=$(echo "$RAW" | node -e 'let s=require("fs").readFileSync(0,"utf8").trim(); let n=Number(s.replace(/[^\d.-]/g,"")); console.log(Number.isFinite(n)?n:"null");') ;;
  currency) PARSED=$(echo "$RAW" | node -e 'let s=require("fs").readFileSync(0,"utf8").trim(); let n=Number(s.replace(/[^\d.-]/g,"")); console.log(Number.isFinite(n)?n:"null");') ;;
  count)    PARSED=$(echo "$RAW" | node -e 'let s=require("fs").readFileSync(0,"utf8").trim(); let n=parseInt(s.replace(/[^\d-]/g,""),10); console.log(Number.isFinite(n)?n:"null");') ;;
  text)     PARSED="$RAW" ;;
  *)        PARSED="$RAW" ;;
esac

HASH=$(printf '%s' "${RAW:-}" | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-8)
```

Inline quality flags (Phase 4 subset — full catalog in `CHECKS.md`):

- `NULL_VALUE` — `RAW` is null or empty.
- `PLACEHOLDER` — `RAW` matches `/lorem|TODO|FIXME|N\/A|--|\?\?\?|xxx|placeholder|fpo|coming soon/i`.
- `NEGATIVE_COUNT` — `LABEL_TYPE == count && PARSED < 0`.

Each flag emits an additional JSONL line with `label: "quality_flag"` and `detail: {flag, target_label, severity}` (schema in `CHECKS.md`).

### 2.5 Append to registry

One JSONL line per (role, page, label):

```bash
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TICK=$(jq -r '.ui_audit_matrix.tick // 0' docs/crawls/latest-tick.json 2>/dev/null || echo 0)
mkdir -p docs/crawls
jq -c -n \
  --arg ts "$TS" --arg role "${ROLE:-__default__}" --arg page "$PATH" --arg label "$LABEL" \
  --arg raw "$RAW" --argjson parsed "$PARSED" \
  --arg hash "$HASH" --arg selector "$SELECTOR" --argjson tick "$TICK" \
  '{ts:$ts, role:$role, page:$page, label:$label, raw:$raw, parsed:$parsed, hash:$hash, selector:$selector, tick:$tick}' \
  >> docs/crawls/page-data-registry.jsonl
```

After the page's labels are all written, emit one `registry_progress` activity-feed event (aggregate, not per-label).

## Phase 3 — CONSISTENCY

Reduces the append-only registry to latest-wins state, detects cross-page value divergence, and feeds the result to the invariant evaluator (next section).

### 3.1 Reduce registry

Write the reduced snapshot to `${SESSION_TMP_DIR}/reduced.json` for the evaluator to read:

```bash
jq -s '
  [.[] | select(.ts != null and .label != null and .label != "quality_flag" and .label != "heuristic")]
  | group_by([.role, .page, .label])
  | map(max_by(.ts))
' docs/crawls/page-data-registry.jsonl > "${SESSION_TMP_DIR}/reduced.json"
```

The `select` excludes `quality_flag` and `heuristic` meta-lines — those are findings, not observations. Only actual label observations reduce.

### 3.2 Cross-page divergence

A label appearing on multiple pages with different `parsed` values is a divergence. For each label with >1 distinct parsed value across pages:

```bash
jq -s '
  [.[] | select(.ts != null and .label != null and .label != "quality_flag" and .label != "heuristic")]
  | group_by(.label)
  | map({
      label: .[0].label,
      obs: (group_by([.role, .page])
            | map(max_by(.ts))
            | map({role, page, parsed, raw}))
    })
  | map(select((.obs | map(.parsed) | unique | length) > 1))
' docs/crawls/page-data-registry.jsonl > "${SESSION_TMP_DIR}/divergences.json"
```

Each entry in `divergences.json` is a candidate finding. The invariant evaluator (§ Phase 3 INVARIANTS) decides whether to suppress it (because a declared invariant with tolerance covers it) or emit it as `label:cross-page-divergence`.

### 3.3 Emit divergence findings

For every divergence not suppressed by invariants, emit:

```jsonl
{"ts":"<ISO>","role":"__default__","page":"<pages-listed>","label":"cross-page-divergence","raw":null,"parsed":null,"hash":"<sha8 of label+obs-values>","selector":null,"tick":<t>,"detail":{"target_label":"<label>","severity":"HIGH","observations":[{"role","page","parsed","raw"}...]}}
```

Finding writes to `docs/crawls/page-data-registry.jsonl` (the same registry file — findings are lines, observations are lines; the reducer's select filter keeps them separate). Activity-feed `divergence` event in parallel.

## Phase 3 — INVARIANTS

Reads `.ui-audit.json[invariants]`. For each invariant, fetches the `parsed` value at each `{page, key}` source from the reduced registry (§ 3.1 output) and applies the `check` with `tolerance`. Emits pass/fail events and pre-suppresses matching divergences from § 3.2.

### 3I.1 Evaluate each invariant

```bash
jq --slurpfile cfg .ui-audit.json --slurpfile reg "${SESSION_TMP_DIR}/reduced.json" -n '
  def lookup(src; $reg): $reg[0] | map(select(.page == src.page and .label == src.key)) | first;
  def cmp_equal($a; $b; $tol): ($a != null and $b != null) and (($a - $b) | fabs) <= $tol;
  def cmp_gte($a; $b; $tol):   ($a != null and $b != null) and ($a + $tol) >= $b;
  def cmp_lte($a; $b; $tol):   ($a != null and $b != null) and ($a - $tol) <= $b;

  $cfg[0].invariants
  | map({
      id,
      description,
      check,
      tolerance: (.tolerance // 0),
      values: (.sources | map({ page, key, obs: lookup(.; [$reg]) })),
    })
  | map(
      . as $inv |
      . + {
        passed: (
          if $inv.check == "equal" then
            # All source pairs must be within tolerance of the first.
            ($inv.values | . as $vs |
             (if ($vs | length) < 2 then false
              else all($vs[1:][]; cmp_equal($vs[0].obs.parsed; .obs.parsed; $inv.tolerance)) end))
          elif $inv.check == "gte" then
            ($inv.values | . as $vs |
             (if ($vs | length) < 2 then false
              else all($vs[1:][]; cmp_gte($vs[0].obs.parsed; .obs.parsed; $inv.tolerance)) end))
          elif $inv.check == "lte" then
            ($inv.values | . as $vs |
             (if ($vs | length) < 2 then false
              else all($vs[1:][]; cmp_lte($vs[0].obs.parsed; .obs.parsed; $inv.tolerance)) end))
          else false end
        ),
        missing_obs: ([.values[] | select(.obs == null)] | length)
      }
    )
' > "${SESSION_TMP_DIR}/invariant-results.json"
```

The script reads both `.ui-audit.json` and the reduced-registry snapshot, produces one result object per invariant with:
- `id`, `description`, `check`, `tolerance`
- `values: [{page, key, obs}]` — the observations pulled
- `passed: bool` — `true` if the check holds
- `missing_obs: int` — how many sources had no observation (null → finding separate)

### 3I.2 Emit events

For each invariant result:

```bash
# On FAIL:
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -cn --arg ts "$TS" --arg sid "$SESSION_ID" \
  --argjson inv "<result-object>" \
  '{ts:$ts, session:$sid, skill:"ui-audit", event:"invariant_fail",
    message:("Invariant " + $inv.id + " FAIL: " + $inv.description),
    detail:$inv}' \
  >> .cc-sessions/activity-feed.jsonl

# On MISSING OBSERVATION (null in one of the sources):
# event:"invariant_skipped_missing_obs" with detail including which source was null.

# On PASS: log verbose only (event:"invariant_pass") — off by default; emit if BLITZ_OUTPUT_INTENSITY=full or a verbose flag is set.
```

FAIL also writes a finding line to `docs/crawls/page-data-registry.jsonl`:

```jsonl
{"ts":"<ISO>","role":"__default__","page":"<combined>","label":"invariant_fail","raw":null,"parsed":null,"hash":"<sha8 of id>","selector":null,"tick":<t>,"detail":{"invariant_id":"INV-NNN","check":"equal|gte|lte","tolerance":<n>,"values":[{"page","key","parsed"}...],"severity":"HIGH"}}
```

### 3I.3 Divergence suppression

For each divergence from § 3.2, check whether any invariant's sources subset-covers the divergence's pages AND the invariant passed (with tolerance). If so, suppress the divergence — it's expected per author's declared rule. Log a `divergence_suppressed` activity-feed event for audit trail.

Divergences that match NO invariant fall through to § 3.3 (emit as finding).

### 3I.4 Check values

Semantics:

| `check` | Meaning | Pass condition |
|---|---|---|
| `equal` | All source values identical within tolerance | `∀ i,j: |v[i] - v[j]| ≤ tolerance` |
| `gte` | First source ≥ every other within tolerance | `∀ j>0: v[0] + tolerance ≥ v[j]` |
| `lte` | First source ≤ every other within tolerance | `∀ j>0: v[0] - tolerance ≤ v[j]` |

Numeric tolerance only. For `text`-typed labels, `tolerance: 0` and `check: "equal"` is the only valid combination.

## Phase 3 — FLAPPING/STALE

Tick-over-tick hash diff classifies each `(role, page, label)` into one of five states. Requires ≥3 prior observations to detect FLAPPING; fewer degrades gracefully.

### 3F.1 Build per-key history

```bash
jq -s '
  [.[] | select(.ts != null and .label != null and .label != "quality_flag" and .label != "heuristic" and .label != "cross-page-divergence")]
  | group_by([.role, .page, .label])
  | map({
      key: {role: .[0].role, page: .[0].page, label: .[0].label},
      hist: (sort_by(.ts) | reverse | .[0:3] | map({ts, hash, raw, parsed}))
    })
' docs/crawls/page-data-registry.jsonl > "${SESSION_TMP_DIR}/history.json"
```

`hist` is the 3 most-recent observations, newest first.

### 3F.2 Classify

For each `{key, hist}` entry:

| State | Rule | Severity | Silent? |
|---|---|---|---|
| `STABLE` | `len(hist) >= 2 && hist[0].hash == hist[1].hash` | — | Yes |
| `CHANGED` | `len(hist) >= 2 && hist[0].hash != hist[1].hash` (not matching STALE or FLAPPING) | INFO | No (log `value_change`) |
| `STALE` | `len(hist) >= 2 && hist[0].hash == hist.find(prev2).hash && hist[0].hash != hist[1].hash` — value reverted to what it was 2 ticks ago | LOW | No |
| `FLAPPING` | `len(hist) == 3 && hist[0].hash == hist[2].hash && hist[0].hash != hist[1].hash` — oscillates between two values over 3 ticks | MED | No |
| `NULL_TRANSITION` | `hist[0].parsed == null && any(hist[1..].parsed != null)` — real → null | HIGH | No |

Only `STABLE` is silent. All others emit a finding line:

```jsonl
{"ts":"<ISO>","role":"<r>","page":"<p>","label":"tick_diff","raw":null,"parsed":null,"hash":"<sha8>","selector":null,"tick":<t>,"detail":{"target_label":"<label>","state":"FLAPPING|STALE|CHANGED|NULL_TRANSITION","severity":"HIGH|MED|LOW|INFO","history_hashes":[<3>]}}
```

Plus activity-feed event (`flapping`, `stale`, `null_transition`, or `value_change`).

### 3F.3 Tick-count fallback

When `len(hist) < 3`, FLAPPING cannot be detected. That's expected on first + second tick — emit no finding for those pairs; just log INFO. STALE requires `len(hist) >= 3` too.

NULL_TRANSITION is detectable at `len(hist) >= 2`.



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
