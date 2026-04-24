# ui-audit — Data-Quality Flag Catalog

> **SKELETON — populated in E-009 (CAP-011) — DO NOT treat as shipping checklist.**
>
> Sprint-6 ships the flag names + 1-line definitions so CAP-008 AC2 closes and Phase 4 (QUALITY) has a stable reference to link against. Implementation procedures land in E-009.

Findings produced by this module surface as `page:label:FLAG` in `docs/crawls/ui-audit-report.md` and as `label: "quality_flag"` entries in `docs/crawls/page-data-registry.jsonl`.

---

## NULL_VALUE

The extracted `parsed` value is `null` — the selector matched nothing, or matched an element with empty `.textContent`. Fires once per (role, page, label). Severity: HIGH when the label is declared in `.ui-audit.json` and the page is declared; MED otherwise.

<!-- TODO(E-009 / CAP-011): detection procedure — inline in extraction JS after .textContent.trim() coercion; emit flag when (raw === null || raw === '') and the label was declared for this page. -->

## PLACEHOLDER

Raw text matches a placeholder regex. Default pattern: `/lorem|TODO|FIXME|N\/A|--|\?\?\?|xxx|placeholder|fpo|coming soon/i`. Configurable via `.ui-audit.json[placeholder_patterns]`. Severity: HIGH (production placeholder leakage).

<!-- TODO(E-009 / CAP-011): detection — inline in extraction JS; run regex against raw before type-coercion. -->

## FORMAT_MISMATCH

The raw string's format (currency symbol, decimal separator, thousands separator, date format) differs from every prior observation of the same label on any page. Fires after ≥2 prior ticks for the same (page, label). Severity: MED.

<!-- TODO(E-009 / CAP-011): reducer — jq over registry history for the (page, label); normalize to {currency_symbol, decimal_sep, thousands_sep, date_fmt} shape; compare latest to the historical mode. -->

## STALE_ZERO

`parsed === 0` but the latest-wins registry history for the same (role, page, label) has ≥1 non-zero observation. Suggests cache miss or silent fetch failure rendered a placeholder zero. Severity: MED.

<!-- TODO(E-009 / CAP-011): reducer — check registry history per (role, page, label); flag when current is 0 AND max(history.parsed) > 0. -->

## BROKEN_TOTAL

Configured parent/child relationship: sum of declared child values != parent total within tolerance. Requires author to declare `{parent: "<label>", children: ["<label1>", "<label2>"], tolerance: 0}` in `.ui-audit.json[totals]`. Severity: HIGH.

<!-- TODO(E-009 / CAP-011): evaluator — jq over latest-wins registry state; for each declared total, sum children.parsed and compare to parent.parsed with tolerance. Emits one finding per violated total. -->

## NEGATIVE_COUNT

`parsed < 0` on a label whose type is `count`. Counts should not be negative in a healthy UI. Severity: HIGH.

<!-- TODO(E-009 / CAP-011): detection — inline in extraction JS; for labels with type='count', flag when Number.isFinite(parsed) && parsed < 0. -->

---

## Integration with reporter

The Phase 6 reporter (skills/ui-audit/reference.md § REPORT) consumes quality-flag findings as:

```jsonl
{"ts":"...","role":"...","page":"/dashboard","label":"quality_flag","raw":"","parsed":null,"detail":{"flag":"NULL_VALUE","target_label":"open_invoices","severity":"HIGH"},"hash":"...","tick":7}
```

Reporter groups these alongside invariant failures and heuristic findings by severity tier.
