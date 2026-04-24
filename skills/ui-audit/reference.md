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

**Label-name validation (prototype-pollution guard).** Before interpolation, reject any label name that matches `/^(__proto__|constructor|prototype)$/`. These keys are forbidden by this skill even though they are otherwise valid JSON — allowing them lets a hostile `.ui-audit.json` author set prototype entries on the `browser_evaluate` return object and then trigger prototype-polluted behavior in downstream jq/node coercion. On match: exit 1 with `[ui-audit] Forbidden label name in .ui-audit.json: "${label}"`.

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

**Information-flow note.** Raw DOM `.textContent` for each labeled element — which may include PII visible to the authenticated role (usernames, emails, order amounts, etc.) — is persisted verbatim in `docs/crawls/page-data-registry.jsonl`, aggregated into `docs/crawls/ui-audit-report.md`, and may appear in `raw` fields of activity-feed events. This is by design (cross-page invariant comparisons need the exact value), but it means these three files inherit the sensitivity class of the highest-privilege role the skill audits. Do not commit them to public repos. `.gitignore` suggestion: `docs/crawls/page-data-registry.jsonl` and `docs/crawls/ui-audit-report.md`.

## Phase INTERACTIVE — Every button / link / tab

Runs in `buttons` and `full` modes. Skipped in `data`, `consistency`, `heuristics`, and `events`-only modes.

Per-page procedure: enumerate → 6 static checks → focus probe → safe-click (gated) → summarize.

### I.1 Enumeration (single `browser_evaluate` call)

Returns every ARIA-role + native HTML interactive element on the page. Zero side effects. De-dup via `Set` so an element matching both ARIA role and native tag appears once.

```js
(() => {
  const ROLES = ['button','link','checkbox','radio','tab','menuitem','combobox','listbox','switch','slider','spinbutton'];
  const roleQ = ROLES.map(r => `[role="${r}"]`).join(',');
  const nativeQ = 'button,a[href],input:not([type=hidden]),select,textarea,[tabindex]';
  return [...new Set([
    ...document.querySelectorAll(roleQ),
    ...document.querySelectorAll(nativeQ),
  ])].map(el => ({
    tag:           el.tagName.toLowerCase(),
    role:          el.getAttribute('role') ?? el.tagName.toLowerCase(),
    label:         el.getAttribute('aria-label')
                     ?? el.getAttribute('aria-labelledby')
                     ?? el.textContent?.trim().slice(0, 80)
                     ?? el.getAttribute('placeholder')
                     ?? null,
    tabindex:      el.getAttribute('tabindex'),
    hrefOrOnclick: el.getAttribute('href') ?? el.getAttribute('onclick') ?? null,
    classes:       el.className,
    outerSnip:     el.outerHTML.slice(0, 120),
    visible:       !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length),
    ariaHidden:    el.getAttribute('aria-hidden') === 'true',
  }));
})()
```

### I.2 Per-page summary line

Once per page (after I.1 + I.3 + I.4), append one aggregate JSONL:

```jsonl
{"ts":"<ISO>","role":"<role>","page":"<path>","label":"interactive_audit_summary","raw":null,"parsed":null,"hash":"<sha8>","selector":null,"tick":<n>,"detail":{"total":<n>,"labeled":<n>,"dead_href":<n>,"no_handler":<n>,"tabindex_broken":<n>,"no_focus_state":<n>,"safe_clicked":<n>,"click_errors":<n>}}
```

### I.3 Per-element checks (6 static + 1 probe)

Applied to each element returned by I.1. Findings emit as `button_finding` JSONL lines with `detail: {issue, element_label, tag, tabindex, selector_snip, severity}`.

| Check | Condition | Severity |
|---|---|---|
| `NO_LABEL` | `label == null \|\| label === ''` AND `visible && !ariaHidden` | HIGH (WCAG 2.1 AA) |
| `DEAD_HREF` | `hrefOrOnclick === '#' \|\| hrefOrOnclick === 'javascript:void(0)'` | MED |
| `EMPTY_HANDLER` | Native `<button>` or `[role=button]` AND `onclick === ''` attribute AND not inside a `<form>` | MED |
| `TABINDEX_POSITIVE` | `parseInt(tabindex,10) >= 1` | MED |
| `TABINDEX_NEGATIVE_VISIBLE` | `tabindex === '-1'` AND `visible && !ariaHidden` (**R7: re-check after 500ms settle**) | MED |
| `NO_FOCUS_STATE` | Focus probe (see I.4) returns no visible focus indicator | HIGH (WCAG 2.1 AA) |

**R7 mitigation — TABINDEX_NEGATIVE_VISIBLE settle window.** Frameworks (Vue, React, Svelte) inject `tabindex` dynamically on mount. If the initial enumeration finds `tabindex === '-1'` on a visible element, wait 500ms (`browser_wait_for(time: 0.5)`) then re-run enumeration for that element only. If still `-1`, emit the finding. Otherwise, suppress — the framework injected the real value during mount.

### I.4 Focus probe (NO_FOCUS_STATE)

Per-element `browser_evaluate`. Cost is bounded — cap at **10 focus probes per page** (emit `focus_probe_capped` INFO finding with total count if exceeded).

```js
(selector) => {
  const el = document.querySelector(selector);
  if (!el) return {ok: false, reason: 'element-gone'};
  el.focus();
  const s = window.getComputedStyle(el);
  const hasRing =
    s.outlineWidth !== '0px' ||
    s.boxShadow !== 'none' ||
    el.matches(':focus-visible');
  return {ok: true, hasRing, outlineWidth: s.outlineWidth, boxShadow: s.boxShadow};
}
```

If `hasRing === false`, emit `NO_FOCUS_STATE`. If `ok === false`, the element disappeared between enumeration and probe (shadow-DOM timing, route transition) — emit `focus_probe_element_gone` INFO.

### I.5 Safe-click pass

After enumeration + static checks + focus probe, the skill may click elements that pass both the destructive classifier AND a type heuristic. Post-click, it captures any console error or 4xx/5xx network response attributed to that click as a `CLICK_ERROR` finding.

**Destructive-label classifier.** Keep in sync with `SKILL.md` Safety Rule 1 — same verb list.

```js
const DESTRUCTIVE_LABELS = /delete|remove|logout|sign.?out|cancel|submit|pay|confirm|save|update|apply|publish|send|subscribe|unsubscribe|create|add|archive|disable|revoke|destroy|drop|purge|reset|terminate/i;
const DESTRUCTIVE_HREF   = /\/logout|\/delete|\/remove|\/signout|\/destroy/i;
const isSafe = !DESTRUCTIVE_LABELS.test(label ?? '') && !DESTRUCTIVE_HREF.test(hrefOrOnclick ?? '');
```

**Type heuristic.** Only these element types are clicked even when `isSafe` is true:

| Allowed type | Detection rule |
|---|---|
| ARIA tab | `role === 'tab'` OR ancestor has `role=tablist` |
| Pagination | text matches `/^(next|prev|previous|first|last|page \d+|\d+)$/i` |
| Sort header | element is `<th>` or `[role=columnheader]` with click handler |
| Accordion toggle | `[aria-expanded]` attribute present |
| Expander / "Show more" | text matches `/^(show more|show less|expand|collapse|more|less|view all|see more)$/i` |

Extensible via `.ui-audit.json[interactive_click_allowlist]: [<css-selector>, ...]` (doc-only; default empty). Operators can widen the allow-list for project-specific widgets, but both the destructive classifier AND the allow-list must pass.

**Execution per safe click.**

```
START_TS = now()
browser_click(element)
browser_wait_for(time: 1)     # 1s for post-click events to settle
CONSOLE = browser_console_messages(since = START_TS)
NETWORK = browser_network_requests(since = START_TS, static: false, requestBody: false)
ERRORS = CONSOLE.filter(m => m.level === 'error')
NET_FAIL = NETWORK.filter(r => r.status >= 400 || r.status === 0)
if (ERRORS.length > 0 || NET_FAIL.length > 0) {
  emit CLICK_ERROR finding with {label, severity: "CRITICAL", errors: ERRORS, network: NET_FAIL}
}
```

**Click cap.** Max 10 safe clicks per page. On hit: emit `safe_click_capped` INFO with `{capped_at: 10, remaining: <count>}`.

**Safety invariant.** An element reaches the click path only if it passes `isSafe === true` AND matches the type heuristic AND is not in a modal/dialog AND is not inside `[aria-disabled=true]`. A single-gate bypass is a CRITICAL bug.





---

## Phase EVENTS — Analytics consistency

Runs in `events` and `full` modes. Injects 3 interception layers immediately after `browser_navigate` returns, BEFORE any user interaction.

### E.1 Three-layer interception

All three wrappers call their original transport last — events reach production analytics unchanged.

**Layer A — `window.dataLayer` push proxy** (GA4 / GTM):

```js
window.__auditEventLog = [];
const _push = (window.dataLayer ||= []).push.bind(window.dataLayer);
window.dataLayer.push = function(...args) {
  window.__auditEventLog.push({
    layer: 'dataLayer',
    ts: Date.now(),
    payload: JSON.parse(JSON.stringify(args))
  });
  return _push(...args);
};
```

**Layer B — `navigator.sendBeacon` wrap** (GA4 hit transport):

```js
const _beacon = navigator.sendBeacon.bind(navigator);
navigator.sendBeacon = function(url, data) {
  window.__auditEventLog.push({
    layer: 'beacon',
    ts: Date.now(),
    url,
    body: typeof data === 'string' ? data : '[binary]'
  });
  return _beacon(url, data);
};
```

**Layer C — Network-level (post-hoc)**. After each action, read `browser_network_requests({static:false, requestBody:true, requestHeaders:false})` and filter POST bodies by hostname. Default filter list:

- `api.segment.io` — Segment
- `app.posthog.com`, `*.i.posthog.com` — PostHog
- `api2.amplitude.com`, `*.amplitude.com` — Amplitude
- `www.google-analytics.com/g/collect`, `/g/collect` — GA4

Extensible via `.ui-audit.json[analytics_hostnames]: [...]` (array of strings; matched as substrings).

### E.2 Activation timing — R8 mitigation

Layers A + B are injected via `browser_evaluate` immediately after `browser_navigate` returns — before the safe-click pass, before any text-settle. If `window.dataLayer.length > 0` at inject time (events fired during initial parse), emit a finding:

```jsonl
{"label":"analytics_event_warning","detail":{"flag":"EVENTS_BEFORE_SPY","count":<n>,"severity":"LOW"}}
```

The count is `window.dataLayer.length` at inject time — those earlier entries are captured but lack the spy's timestamps.

### E.3 Registry schema — `analytics_event` lines

Each captured event becomes one JSONL line in `docs/crawls/page-data-registry.jsonl`. Keyed by `(page, action_trigger)` — the trigger encodes what caused the fire.

```jsonl
{"ts":"<ISO>","role":"<role>","page":"<path>","label":"analytics_event","raw":"<JSON.stringify payload>","parsed":null,"hash":"<sha8 of sorted-key props>","selector":null,"tick":<n>,"detail":{"event_name":"<name>","layer":"dataLayer|beacon|network","action_trigger":"<trigger>","props":<object>}}
```

**`action_trigger` values** (finite set):

| Value | When to use |
|---|---|
| `page_load` | Events captured in the drain before any safe-click (initial render) |
| `click:<label>` | Events captured within 1s of a safe-click on an element with `<label>` |
| `tab:<label>` | Tab-switch drain |
| `scroll` | Reserved for future scroll-triggered-event support |
| `timer:<ms>` | Reserved for future delayed-event support |
| `manual` | Fallback when no action can be attributed |

### E.4 Drain cadence

Drain twice per page:
1. **Initial drain** — after `browser_navigate` + 1s settle, drain with `action_trigger: "page_load"`. Captures page-view + any auto-fired init events.
2. **Per-click drain** — after each safe-click (Phase INTERACTIVE § I.5), wait 1s, drain with `action_trigger: "click:<label>"`. Captures click-attributed events.

Drain is non-destructive to the page — events have already reached their original transports:

```js
(() => {
  const log = window.__auditEventLog || [];
  window.__auditEventLog = [];
  return log;
})()
```

### E.5 Props hash (drift detection)

Hash the props object with **key-sorted JSON** so prop order doesn't cause false drift:

```bash
# Given a props JSON object, compute the 8-char hash.
HASH=$(printf '%s' "$PROPS_JSON" | jq --sort-keys -c . | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-8)
```

Write `hash` on the JSONL line. Phase 3 drift detection (see § E.6 — S7-007) groups events by `event_name` and flags differing hashes across pages.

### E.6 Cross-page event drift (undeclared)

Same `event_name` firing on multiple pages with differing `hash` values (key-sorted props) → auto-flag as `event_drift`, severity MED.

```bash
jq -s '
  [.[] | select(.label == "analytics_event")]
  | group_by(.detail.event_name)
  | map({
      event_name: .[0].detail.event_name,
      pages: (group_by(.page)
              | map(max_by(.ts))
              | map({page, hash, props: .detail.props}))
    })
  | map(select(.pages | length > 1))
  | map(select((.pages | map(.hash) | unique | length) > 1))
' docs/crawls/page-data-registry.jsonl
```

Each result row → one `event_drift` finding:

```jsonl
{"ts":"<ISO>","role":"<role>","page":"<comma-joined-pages>","label":"event_drift","raw":null,"parsed":null,"hash":"<sha8 of event_name>","selector":null,"tick":<n>,"detail":{"event_name":"<name>","severity":"MED","observations":[{"page","hash","props"},...]}}
```

### E.7 `event_invariants` evaluator (declared)

Reads `.ui-audit.json[event_invariants][]`. Schema:

```json
{
  "id": "EV-001",
  "event_name": "page_view",
  "required_props": ["page_path", "page_title"],
  "forbidden_props": ["user_email", "password", "ssn", "credit_card", "token"],
  "scope": "all_pages | pages_with_cta | [<explicit page list>]"
}
```

**Scope resolution:**
- `all_pages` → every page visited this run
- `pages_with_cta` → pages where ≥1 safe-click was performed OR ≥1 label was declared
- explicit array → literal path list

**Evaluation.** For each invariant, for each in-scope page, for each `analytics_event` with matching `event_name`:
- **Required-props check:** `props` object has every key in `required_props`. Missing → violation.
- **Forbidden-props check:** `props` object has NO key in `forbidden_props`. Any match → violation.

Severity HIGH by default. **PII auto-escalation to CRITICAL:** any violation involving a forbidden-prop from the set `{user_email, password, ssn, credit_card, token, session_id, auth_token, api_key}` is CRITICAL regardless of declared severity. This catches real PII leaks in analytics payloads.

Each violation → `event_invariant_fail` finding + activity-feed event.





---

## Phase ROLE — Per-permissions-role cycle

Runs in `full`, `smoke`, and `role <name>` modes. Also drives the `(role, page)` cursor in `--loop` mode.

### R.1 Role enumeration + env contract

Five recognized roles, executed in this order:

```
anonymous → viewer → member → admin → superadmin
```

Env var contract:

```
AUDIT_ANONYMOUS=true                  # default true when unset; anonymous needs no creds
AUDIT_VIEWER_EMAIL     / AUDIT_VIEWER_PASS
AUDIT_MEMBER_EMAIL     / AUDIT_MEMBER_PASS
AUDIT_ADMIN_EMAIL      / AUDIT_ADMIN_PASS
AUDIT_SUPERADMIN_EMAIL / AUDIT_SUPERADMIN_PASS
```

**Skip-if-absent.** For any non-anonymous role whose `EMAIL` env var is unset (or empty string), emit a `ROLE_SKIP` event and continue:

```jsonl
{"ts":"<ISO>","session":"<SESSION_ID>","skill":"ui-audit","event":"ROLE_SKIP","message":"Role <name> skipped — env vars absent","detail":{"role":"<name>","missing":["AUDIT_<ROLE>_EMAIL","AUDIT_<ROLE>_PASS"]}}
```

**No credential logging.** Only `{role, missing: [var names]}` is logged. `EMAIL` and `PASS` values are never written to any file. This is enforced by convention — violators are CRITICAL security regressions per SKILL.md Safety Rule 6.

### R.2 Mode-specific role selection

| Mode | Roles iterated |
|---|---|
| `full` | All 5 (minus skipped) |
| `smoke` | `anonymous` + `admin` (minus skipped) |
| `role <name>` | Just `<name>` (must not be skipped) |

ETA gate (R10) applies only to `full` (multi-role × all-pages × 2min/tick). Smoke and single-role are not gated — they are bounded under 1 hour by construction.

### R.3 Scripted login (default path)

Default transition between roles: log out → navigate to login → fill credentials from env → submit → wait for success landmark. Reliable across all cookie types (HttpOnly, SameSite, Secure). ~5s per transition.

```
browser_navigate(baseUrl + "/login")
browser_evaluate:
  document.querySelector(SELECTORS.email).value = process.env.AUDIT_<ROLE>_EMAIL;
  document.querySelector(SELECTORS.password).value = process.env.AUDIT_<ROLE>_PASS;
  document.querySelector(SELECTORS.submit).click();
browser_wait_for(text: SELECTORS.success_landmark, time: 5)
```

Selectors are overridable via `.ui-audit.json[login_flow]`:

```json
"login_flow": {
  "login_path": "/login",
  "email_selector":    "input[name=email]",
  "password_selector": "input[name=password]",
  "submit_selector":   "button[type=submit]",
  "success_landmark":  "Dashboard",
  "profile_path":      "/profile",
  "profile_email_selector": "[data-user-email], .user-email"
}
```

### R.4 storageState harvest + restore (opt-in fast path)

Opt in via `--fast-role-switch` flag. Harvest after successful login:

```js
(() => ({
  localStorage:   Object.fromEntries(Object.entries(localStorage)),
  sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
  cookies:        document.cookie,
  harvested_at:   new Date().toISOString()
}))()
```

Write the result to `.auth/<role>.json` (add `/.auth/` to `.gitignore`).

Restore path:

```
browser_navigate(baseUrl)   # must be same-origin for cookie injection
browser_evaluate: replay localStorage + sessionStorage via setItem loop;
                  for each cookie pair: document.cookie = "k=v; path=/"
```

**Limitation:** `document.cookie = ...` only sets non-HttpOnly cookies. Session cookies from most real auth systems are HttpOnly and cannot be injected this way. If the post-restore sentinel (R.5) fails, fall back to scripted login automatically.

### R.5 R9 sentinel check (MANDATORY)

After every role transition (both scripted-login and storageState-restore paths), sentinel-check that the skill is actually logged in as the expected role:

```
browser_navigate(baseUrl + SELECTORS.profile_path)
EMAIL = browser_evaluate:
  document.querySelector(SELECTORS.profile_email_selector)?.textContent?.trim() || null
assert EMAIL === process.env.AUDIT_<ROLE>_EMAIL
```

**On mismatch** (EMAIL !== expected) **or null**:
- Emit finding `ROLE_SWITCH_FAILED` with severity CRITICAL
- Record `{expected_role: <name>, observed_email: <masked-or-null>}`
- **Abort the role's audit** — do not proceed to Phase 2 extraction for this role
- Continue to the next role

Anonymous role skips R.5 entirely.

### R.6 Inter-role storage cleanup

Before the next role's login, clear all persistent state to prevent session contamination (R9):

```js
(() => {
  localStorage.clear();
  sessionStorage.clear();
  // Clear cookies by setting expired versions of every pair
  document.cookie.split(';').forEach(c => {
    const [name] = c.split('=').map(s => s.trim());
    document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
  });
})()
```

Note: this clears same-origin non-HttpOnly cookies only. HttpOnly session cookies are cleared by the target app's logout flow (if the auth flow uses one). If the target app doesn't have a logout endpoint, the scripted-login re-auth in R.3 overwrites the session cookie on success.

### R.7 `role_invariants` evaluator

Reads `.ui-audit.json[role_invariants][]`. Schema:

```json
{
  "id": "ROLE-001",
  "description": "<what privilege boundary this asserts>",
  "sources": [
    {"role": "admin",  "page": "/users", "key": "user_count"},
    {"role": "viewer", "page": "/users", "key": "user_count"}
  ],
  "check": "equal | viewer_null | gte",
  "tolerance": 0
}
```

**Check semantics:**

| `check` | Meaning | Severity on fail |
|---|---|---|
| `equal` | All sources' `parsed` values identical within tolerance (own-data invariant — "my email matches regardless of who's viewing") | HIGH |
| `viewer_null` | First source (admin-tier) non-null AND every non-first source null (privilege boundary — "viewer must not see admin-only data") | CRITICAL on boundary breach |
| `gte` | First source `parsed` ≥ every other within tolerance (partial-visibility — "admin sees ≥ everything viewer sees") | HIGH |

**Evaluator jq script.** Mirrors the Phase 3 invariant evaluator shape (sprint-6 § 3I.1). The `$src` variable-binding idiom is load-bearing — don't re-introduce the filter-arg bug from sprint-6's first draft.

```bash
jq --slurpfile cfg .ui-audit.json --slurpfile reg "${SESSION_TMP_DIR}/reduced.json" -n '
  def lookup($src; $r):
    $r | map(select(.role == $src.role and .page == $src.page and .label == $src.key)) | first;
  def is_num($x): ($x | type) == "number";
  def cmp_equal($a; $b; $tol):
    ($a != null and $b != null) and
    (if is_num($a) and is_num($b) then (($a - $b) | fabs) <= $tol else $a == $b end);
  def cmp_gte($a; $b; $tol): is_num($a) and is_num($b) and ($a + $tol) >= $b;

  $cfg[0].role_invariants // []
  | map({
      id, description, check,
      tolerance: (.tolerance // 0),
      values: (.sources | map({role, page, key, obs: lookup(.; $reg[0])})),
    })
  | map(. as $inv | . + {
      passed: (
        if ($inv.values | length) < 2 then false
        elif $inv.check == "equal" then
          all($inv.values[1:][]; cmp_equal($inv.values[0].obs.parsed; .obs.parsed; $inv.tolerance))
        elif $inv.check == "gte" then
          all($inv.values[1:][]; cmp_gte($inv.values[0].obs.parsed; .obs.parsed; $inv.tolerance))
        elif $inv.check == "viewer_null" then
          ($inv.values[0].obs.parsed != null)
          and all($inv.values[1:][]; .obs == null or .obs.parsed == null)
        else false end
      )
    })
' > "${SESSION_TMP_DIR}/role-invariant-results.json"
```

**`viewer_null` sub-cases:**
- Admin value PRESENT AND every viewer value `null`/absent → **PASS** (healthy privilege boundary).
- Admin value PRESENT AND any viewer value PRESENT → **FAIL CRITICAL** (privilege breach — viewer sees what admin sees).
- Admin value `null` → **distinct finding `ADMIN_OBS_MISSING`** (not a viewer_null fail; don't conflate — the admin observation itself is what's wrong).

**Emit events:** `role_invariant_fail` (HIGH or CRITICAL) / `role_invariant_pass` (verbose only). Findings written as `label: "role_invariant_fail"` JSONL lines.

### R.8 Role-leak HTML scan

Even when admin-only UI is hidden from the viewport, its DOM/script markup may leak into the HTML source — an SSR/hydration bug that reveals feature flags. Coarse but cheap backstop.

**Runs only when the current role is non-admin AND not anonymous.** Anonymous is skipped because there is no baseline comparison available; `role_invariants` (§ R.7) handles anonymous-vs-authenticated cases directly.

**Default patterns** (built-in, always on):

```js
const BUILTIN_PATTERNS = [
  /data-admin-only/i,
  /admin.?panel/i,
  /<script[^>]*>[\s\S]*?admin[\s\S]*?<\/script>/i,
];
```

**Extensible via** `.ui-audit.json[role_leak_patterns]: [<regex-string>, ...]`. Regexes are compiled with `new RegExp(str, 'i')` inside a try/catch — a malformed pattern emits a `CONFIG_ERROR` finding instead of crashing the skill.

**Execution per page per non-admin role:**

```
browser_evaluate: document.documentElement.outerHTML
matches = [...BUILTIN_PATTERNS, ...compiled_custom_patterns].filter(re => re.test(html));
if (matches.length > 0) {
  emit ROLE_LEAK finding with {role, page, matched_patterns: matches.map(r => r.source), severity: "CRITICAL"};
}
```

`ROLE_LEAK` severity is always CRITICAL — a positive match means admin-only markup reached a non-admin user's HTML payload, regardless of whether it was visible.

---

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
  def lookup($src; $r): $r | map(select(.page == $src.page and .label == $src.key)) | first;
  def cmp_equal($a; $b; $tol): ($a != null and $b != null) and (($a - $b) | fabs) <= $tol;
  def cmp_gte($a; $b; $tol):   ($a != null and $b != null) and ($a + $tol) >= $b;
  def cmp_lte($a; $b; $tol):   ($a != null and $b != null) and ($a - $tol) <= $b;

  $cfg[0].invariants
  | map({
      id,
      description,
      check,
      tolerance: (.tolerance // 0),
      values: (.sources | map({ page, key, obs: lookup(.; $reg[0]) })),
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

Aggregates every finding emitted by Phases 3 (divergence + invariant + tick-diff), 4 (quality flags), and 5 (heuristics — E-009 territory but this reporter accepts its findings today). Writes markdown + stdout + activity-feed completion event.

### 6.1 Collect findings

Findings are written into the same `docs/crawls/page-data-registry.jsonl` file as observations; the reducer filters them out by `label` (see § 3.1). For the report, we do the inverse — select finding lines only, grouped by severity.

```bash
jq -s '
  [.[] | select(.label == "invariant_fail"
              or .label == "cross-page-divergence"
              or .label == "tick_diff"
              or .label == "quality_flag"
              or .label == "heuristic")]
  | group_by(.detail.severity // "INFO")
' docs/crawls/page-data-registry.jsonl > "${SESSION_TMP_DIR}/findings-by-severity.json"
```

### 6.2 Compute severity defaults (sprint-6 baseline)

Reporter maps findings without explicit `detail.severity` using this table. Producers may override.

| Finding source | Label | Default severity |
|---|---|---|
| Invariant FAIL | `invariant_fail` | HIGH |
| Cross-page divergence (unsuppressed) | `cross-page-divergence` | HIGH |
| FLAPPING | `tick_diff` with `state: FLAPPING` | MED |
| STALE | `tick_diff` with `state: STALE` | LOW |
| NULL_TRANSITION | `tick_diff` with `state: NULL_TRANSITION` | HIGH |
| CHANGED | `tick_diff` with `state: CHANGED` | INFO |
| NULL_VALUE (quality flag) | `quality_flag` with `flag: NULL_VALUE` | HIGH (if label declared), MED otherwise |
| PLACEHOLDER | `quality_flag` with `flag: PLACEHOLDER` | HIGH |
| NEGATIVE_COUNT | `quality_flag` with `flag: NEGATIVE_COUNT` | HIGH |
| Heuristic | `heuristic` | From producer (see PATTERNS.md tiers) |

### 6.3 Write `docs/crawls/ui-audit-report.md`

Overwrite — each run replaces. Idempotent modulo timestamp.

```markdown
# ui-audit report

**Generated:** <ts>
**Mode:** <mode>
**Roles scanned:** <roles>
**Pages scanned:** <count>
**Ticks in this run:** <count>

## Summary

| Severity | Count |
|---|---|
| CRITICAL | <n> |
| HIGH | <n> |
| MED | <n> |
| LOW | <n> |
| INFO | <n> |

## Critical

<per-finding entry>

## High

<per-finding entry>

## Med

<per-finding entry>

## Low

<per-finding entry>

## Info

<collapsed unless --verbose>

---

## Per-finding entry format

- **[<severity>] <label>**
  - Where: `<page>:<target_label>` OR `<file>:<line>` (heuristics)
  - Detail: <one-line summary from finding.detail>
  - First seen: tick <n>
  - Last seen: tick <n>
```

### 6.4 Stdout summary

Print to stdout (captured by the orchestrator log):

```
[ui-audit] complete.
  Severity:  CRITICAL=<n>  HIGH=<n>  MED=<n>  LOW=<n>  INFO=<n>
  Invariants evaluated: <n>, failed: <n>
  Pages scanned: <n>  Ticks: <n>
  Report: docs/crawls/ui-audit-report.md
  Top 3 invariant failures (by severity × age):
    1. INV-NNN: <description>   (pages: ...)
    2. ...
    3. ...
```

Top-3 selection: sort `invariant_fail` findings by `(severity-rank desc, first-seen-tick asc)`, take 3. If fewer than 3 invariant failures, pad with top cross-page divergences.

### 6.5 Activity-feed `skill_complete`

```jsonl
{"ts":"<ts>","session":"<sid>","skill":"ui-audit","event":"skill_complete","message":"ui-audit <mode> complete","detail":{"mode":"<mode>","findings_critical":<n>,"findings_high":<n>,"findings_med":<n>,"findings_low":<n>,"findings_info":<n>,"invariants_evaluated":<n>,"invariants_failed":<n>,"pages_visited":<n>,"tick_count":<n>,"report_path":"docs/crawls/ui-audit-report.md"}}
```

### 6.6 Mode exceptions

- `consistency` mode: no `pages_visited` (no extraction). `tick_count = 0` (evaluating existing registry). Report identical shape.
- `data` mode: no Phase 3/5 output. Report skipped; stdout summary shows extraction counts only. Activity-feed event still written with null invariant fields.
- `--loop` mode: Phase 6 emits a rolling report each tick (same path, overwritten). `skill_complete` event is emitted once per tick with `mode: "loop-tick"`; a final `skill_complete` with `mode: "loop-matrix-complete"` fires when the full (role × page) matrix has been visited twice (pass 1 seeds registry, pass 2 detects drift).

### 6.7 Idempotence

Rerunning `consistency` mode on an unchanged registry produces byte-identical report content (only the `**Generated:**` timestamp differs). Reporter must sort findings deterministically:
1. By severity (CRITICAL > HIGH > MED > LOW > INFO)
2. Then by `target_label` alphabetically
3. Then by `page` alphabetically
4. Then by `tick` ascending



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
  [.[] | select(.ts != null and .label != null
                and .label != "quality_flag"
                and .label != "heuristic"
                and .label != "cross-page-divergence"
                and .label != "invariant_fail"
                and .label != "tick_diff")]
  | group_by([.role, .page, .label])
  | map(max_by(.ts))
' docs/crawls/page-data-registry.jsonl
```

Null-guard on `.ts` and `.label` protects against partial-write rows a crash may leave (domain-researcher gate). The extra `.label != ...` guards exclude **finding lines** (meta-events the phases write into the same file) so they never pollute the reduced observation state. See Phase 3 § 3.1 — the reducer there uses the same guards.

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
