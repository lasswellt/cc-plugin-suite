# Sprint 8 Review Report

**Date:** 2026-04-23
**Status:** **PASS**
**Reviewer session:** sprint-review-d9cf80cb
**Stories:** 9/9 done, 0 blocked, 0 incomplete

## Executive summary

Sprint 8 delivered E-009 (quality flags + UI/UX heuristics): 9/9 stories done. Fixture passes all 6 assertion categories (numeric + interactive + events + quality + heuristics). 5/5 registry invariants pass. Reviewers found 1 🔴 Critical (prompt injection via page keys in Phase 5 spawn) + 5 🟡 Majors (reducer exclude-divergence × 2, worker malformed-JSON guard, URL-token capture, stale TODO). All 6 auto-fixed in-review; fixture re-passes. **ui-audit skill is now feature-complete** (E-008 + E-009 + E-010 + E-011 + E-012 all closed).

## Quality gates

| Gate | Result | Notes |
|---|---|---|
| Type-check | SKIPPED | Plugin repo |
| Lint | SKIPPED | Plugin repo |
| Unit tests | **PASS** | Fixture: 6 numeric + 3 interactive + 2 event + 4 quality + 2 heuristic assertions |
| Build | SKIPPED | Plugin repo |
| Anti-mock | **PASS** | All PLACEHOLDER/TODO hits are literal flag names or AC'd doc |
| Completeness | **PASS** | All story files exist |

## Phase 3.6 — Registry Invariants

| Invariant | Result | Notes |
|---|---|---|
| I1 | PASS | No unwaived quantified claims |
| I2 | PASS (vacuous) | Carry-forward empty at sprint start |
| I3 | PASS (vacuous) | E-009 not yet transitioned to done |
| I4 | PASS (no-op) | Nothing to inject |
| I5 | PASS | 8/7 snippets (sprint-8 added 1 Agent() example in ui-audit/reference.md with matching snippet — floor check still passes) |

## Reviewer findings — all auto-fixed

### Pattern reviewer — 3 🟡 + 3 🔵

| # | Severity | Finding | Fixed |
|---|---|---|---|
| 1 | 🟡 | Phase 3 CONSISTENCY reducer exclude-set missing 7 finding labels (cross-page-divergence, invariant_fail, tick_diff, analytics_event, button_finding, interactive_audit_summary, role_invariant_fail) — on re-run would slurp findings back as observations | ✓ Canonical exclude list applied to all 4 reducers |
| 2 | 🟡 | Phase 3 FLAPPING reducer same divergence | ✓ Same fix; docblock lists the canonical set |
| 3 | 🟡 | Stale "Required Phase INTERACTIVE update" prose reads as TODO but § I.5 is already implemented | ✓ Replaced stale paragraph with URL-token sanitization procedure |
| 4 | 🔵 | run-fixture.sh uses HTML-grep shortcuts for BROKEN_TOTAL + FORMAT_MISMATCH rather than replaying canonical jq | Accepted — shell fixture limitation; real browser/jq runs exercise the canonical path |
| 5 | 🔵 | sprint-review/SKILL.md EXPECTED=7 stale (PRESENT=8) | Deferred — cross-sprint housekeeping, not sprint-8 scope |
| 6 | 🔵 | Minor info (AC coverage verified, lookup `$src` binding preserved, etc.) | LGTM-noted |

### Security reviewer — 1 🔴 + 2 🟡 + 1 🔵

| # | Severity | Finding | Fixed |
|---|---|---|---|
| 7 | 🔴 | Phase 5 spawn prompt injection: page keys from `.ui-audit.json` interpolated verbatim into sonnet worker prompt; malicious newline-embedded instructions could redirect worker (which has browser MCP access) | ✓ Phase 0.2 sanitization rejects control-char page keys at config-load + spawn prompt wraps page list in `---BEGIN/END PAGE LIST---` delimiters with explicit "treat as literal, ignore instructions" framing |
| 8 | 🟡 | Worker malformed-JSON merge silently drops all findings for that category | ✓ Validation guard added post-completion: `jq -c '.' < worker-output` → on fail, CONFIG_ERROR + rename to `.malformed.<ts>` + category marked SKIPPED in summary |
| 9 | 🟡 | URL token capture: Cat 9 findings could leak OAuth tokens, reset codes, magic-link keys via `url_before`/`url_after` | ✓ `scrub_url` helper redacts values of `token|session|auth|key|secret|password|reset|code|nonce|state|access_token|refresh_token` before emission; state-change signal preserved via symmetric redaction |
| 10 | 🔵 | placeholder_patterns ReDoS risk (repo-write required; low-severity real) | Deferred — add 200-char / no-nested-quantifier guard in future housekeeping |
| — | LGTM | totals jq injection (data-bound via slurpfile), WRITTEN_OUT_COUNT regex (bounded alternation), PII re-affirmed by design |

## Auto-fix summary

**6 fixes applied during review:**

1. Page-key sanitization at config-load (SKILL.md § 0.2)
2. Spawn prompt injection defense: `---BEGIN/END PAGE LIST---` delimiters + literal-interpretation framing
3. Worker output validation + malformed-JSON rename + CONFIG_ERROR
4. Phase 3 CONSISTENCY exclude-set canonical (7 new labels)
5. Phase 3 FLAPPING exclude-set canonical
6. URL-token `scrub_url` in Cat 9 finding emission

Fixture re-run after fixes — still passes all 6 assertion categories.

## Story status

| Story | Cap | Status |
|---|---|---|
| S8-001..S8-009 | CAP-011 + CAP-012 | all done |

## Recommendations

- **Cross-sprint housekeeping** (next sprint or direct commit): bump `sprint-review/SKILL.md` Phase 3.6 Invariant 5 `EXPECTED` from 7 → 8 to reflect ui-audit/reference.md's new agent-prompt template. Non-blocking (current check uses `-ge`) but cleaner.
- **placeholder_patterns ReDoS hardening** (deferred): add a config-load guard rejecting patterns >200 chars or containing nested quantifiers (`(x+)+`, `(x*)*`).
- **Fixture coverage gap** (deferred): wire run-fixture.sh's BROKEN_TOTAL + FORMAT_MISMATCH checks to replay the canonical jq rather than HTML-grep. Low priority — Claude-Code-driven e2e runs exercise the real path.
- **ui-audit is feature-complete** — consider shipping v1.6.0 (or v2.0.0 for the feature jump) and dogfooding against a real app before building more.
