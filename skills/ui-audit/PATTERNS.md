# ui-audit — UI/UX Heuristic Patterns

> **SKELETON — populated in E-009 (CAP-012) — DO NOT treat as shipping checklist.**
>
> Sprint-6 ships the heading structure + pointers to upstream rule sources so CAP-008 AC2 closes and Phase 5 (HEURISTICS) has a stable reference. Full rule implementations land in E-009.

Findings produced by this module surface as `file:line` (when the rule applies to source code) or `page:heuristic` (when the rule applies to rendered DOM) in `docs/crawls/ui-audit-report.md`.

---

## Severity tiers

| Tier | Examples | Gate? |
|---|---|---|
| **CRITICAL** | WCAG 2.1 AA contrast failures; missing aria-label on interactive; touch target <44×44pt | Yes — fails heuristics pass |
| **HIGH** | Missing focus-visible on interactives; cumulative layout shift triggers | Yes |
| **MED** | Non-tabular-nums numeric columns; missing `prefers-reduced-motion` gates | Warn |
| **LOW** | Copy issues (non-Title-Case headings, missing curly quotes, non-numerals in counts) | Info |

Tiering borrowed from UI/UX Pro Max + Vercel guidelines. See research doc §3.6.

---

## Rule source: Vercel Web Interface Guidelines

Upstream: https://vercel.com/design/guidelines
Mirror (for runtime fetch): https://github.com/vercel-labs/web-interface-guidelines

17 categories. This skeleton notes the two highest-priority ones for cross-page data consistency:

### Category 9 — Navigation & State

URL must reflect stateful UI (filters, tabs, pagination). Stateful views must be deep-linkable. Back/forward navigation must restore state.

<!-- TODO(E-009 / CAP-012): detection — per page, verify pagination/filter/tab state is reflected in URL querystring; flag state that exists in DOM but not URL. -->

### Category 16 — Content & Copy

Active voice. Title Case in headings. **Numerals for counts** (`"3 items"` not `"three items"`). **Tabular-nums for number columns** (`font-variant-numeric: tabular-nums` on numeric table cells).

<!-- TODO(E-009 / CAP-012): detection — scan rendered tables for numeric columns whose cells lack tabular-nums; scan count-context strings for written-out numbers under 10. -->

---

## Rule source: UI/UX Pro Max

Upstream: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

<!-- TODO(E-009 / CAP-012): borrow the 10-tier severity ladder + pre-delivery checklist rules for accessibility, touch targets, feedback timing, contrast. -->

---

## Rule source: Bencium UX Designer

Upstream: https://github.com/bencium/bencium-claude-code-design-skill

Anti-patterns worth auto-flagging: Inter / Roboto / Space Grotesk typefaces, `#3B82F6` SaaS blue, decorative shadows/gradients, glassmorphism clichés. Opinionated — gate behind `.ui-audit.json[enable_bencium_opinions]: true`.

<!-- TODO(E-009 / CAP-012): optional opinionated ruleset — gated so the default heuristics pass does not fire on teams using these typefaces intentionally. -->

---

## Role-leak patterns (CAP-016 / E-012 / sprint-7)

Regex patterns that trigger a `ROLE_LEAK` finding (always CRITICAL) when they match rendered HTML while logged in as a non-admin role. Full procedure in `skills/ui-audit/reference.md` § Phase ROLE § R.8.

### Built-in defaults (always active)

| Pattern | What it catches |
|---|---|
| `/data-admin-only/i` | Elements tagged with admin-only attribute the app forgot to strip server-side |
| `/admin.?panel/i` | String references to admin-panel class/component names in the rendered DOM |
| `/<script[^>]*>[\s\S]*?admin[\s\S]*?<\/script>/i` | Inline scripts mentioning admin — often leaked feature-flag bootstraps |

### Extension contract

Add project-specific patterns via `.ui-audit.json`:

```json
"role_leak_patterns": [
  "data-superadmin",
  "InternalDashboard",
  "\\\\bsudo-token\\\\b"
]
```

Each entry is compiled with `new RegExp(str, 'i')`. Malformed regex → `CONFIG_ERROR` finding at skill start (not runtime crash).

**Scope:** scan runs per-page for every authenticated non-admin role. Anonymous is excluded (no authenticated baseline to compare against; use `role_invariants` instead).

**False positives:** expected and tolerable. The scan is intentionally coarse. Operators tune the extension list iteratively — each false positive is a one-line config change.

---

## Integration with reporter

The Phase 5 heuristics pass consumes rules from the sources above and emits findings in:

```jsonl
{"ts":"...","role":"...","page":"/dashboard","label":"heuristic","raw":"","parsed":null,"detail":{"rule_id":"vercel-cat-16-tabular-nums","severity":"MED","where":"table.invoices tbody td.amount","source":"vercel"},"hash":"...","tick":7}
```

Reporter groups these alongside invariant failures and quality-flag findings by severity tier.
