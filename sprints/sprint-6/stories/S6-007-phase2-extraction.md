---
id: S6-007
title: "Phase 2 DATA EXTRACTION — browser_evaluate label executor + JSONL writer"
epic: E-008
capability: CAP-009
status: done
priority: P0
points: 3
depends_on: [S6-004, S6-006]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
  - skills/ui-audit/SKILL.md
verify:
  - "grep -q '## Phase 2 — DATA EXTRACTION' skills/ui-audit/reference.md"
  - "grep -q 'browser_evaluate' skills/ui-audit/reference.md"
  - "grep -q 'page-data-registry.jsonl' skills/ui-audit/reference.md"
  - "grep -qE 'raw.*parsed.*hash.*selector' skills/ui-audit/reference.md"
done: "Phase 2 documents per-page procedure: navigate → snapshot (render confirm) → evaluate (label map) → quality regex → append JSONL line per (role,page,label)."
---

## Description

Core extraction loop. Per page: navigate, confirm render via snapshot, invoke browser_evaluate with user's label-map, coerce types, hash raw, append one JSONL line per (role, page, label) observation to `docs/crawls/page-data-registry.jsonl`.

## Acceptance Criteria

1. Phase 2 procedure in reference.md specifies the 5 steps: navigate → wait+snapshot → browser_evaluate(label-map) → parse (Number/string) + hash → append JSONL.
2. JSONL line shape: `{ts, role, page, label, raw, parsed, hash, selector, tick, detail?}`. `role` defaults `__default__` when multi-role mode not active.
3. Extraction payload built from `.ui-audit.json[page]` entries. Missing page entry → skip page with INFO log (not error).
4. Parse by declared `type`: `number` → `Number(raw.replace(/[^\d.-]/g,''))`; `currency` → strip currency symbols + separators then Number; `count` → parseInt; `text` → keep raw.
5. Hash: `printf '%s' "$raw" | (sha256sum 2>/dev/null || shasum -a 256) | cut -c1-8`.
6. JSONL append via `>>`. No `flock` (single-session safe per domain-researcher).
7. Fencepost test: 3 pages × 2 labels each = 6 registry lines produced on a fixture run (tested in S6-012).

## Implementation Notes

- `browser_evaluate` has no declared size limit, but has a `filename` param for offloading large results. Scalar extractions stay inline; if a label returns >1KB, write to `${SESSION_TMP_DIR}/extract-<tick>.json` and reference by path in `detail`.
- Crash-safety: on Phase 1 load, run `jq -c '.' < page-data-registry.jsonl > /dev/null 2>&1 || tail -n +2` (strip partial last line from prior crash).
- Role field: leave as `__default__` in this sprint. Multi-role logic lands in E-012.

## Dependencies

S6-004 (skeleton), S6-006 (page list).
