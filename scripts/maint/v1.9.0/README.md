# v1.9.0 Migration Scripts

One-time scripts that performed the v1.9.0 Anthropic-canonical overhaul. **Already executed; preserved here for repeatability and audit trail.** Re-running on a clean checkout is idempotent (no-op).

| Script | Purpose | Outputs |
|---|---|---|
| `blitz-fix-frontmatter.sh` | Mechanical adder for missing `effort:` field + verbatim OUTPUT STYLE snippet across all 36 SKILL.md files | Modified SKILL.md frontmatter; reports per-file delta |
| `blitz-rewrite-desc.py` | 36 hand-crafted skill description rewrites (third-person, trigger-front-loaded, ≤1024 chars) | Rewritten `description:` field per SKILL.md |
| `blitz-trim-preamble.py` | Compresses verbose ~500-char session-registration preambles to canonical ~270-char citation | ~5.4 KB saved across 21 SKILL.md files |
| `blitz-restructure.py` | Companion-file restructure: `reference.md` → `references/main.md`, `CHECKS.md`/`PATTERNS.md` → `references/`, `conflict-catalog.json` → `assets/`. Two-phase (rewrite refs first, then move files) | 46 file moves + 202 cross-reference substitutions |
| `blitz-xref-audit.py` | Markdown link health scanner (BROKEN / SUSPECT detection). Used post-restructure to verify ref integrity | Stdout report; non-zero exit when broken refs found |

## Re-run safety

Each script is intentionally idempotent against the current state:

- `blitz-fix-frontmatter.sh` skips files that already contain the snippet
- `blitz-rewrite-desc.py` is keyed on skill name; re-running overwrites with same content
- `blitz-trim-preamble.py` regex matches only the verbose form (already-trimmed files unchanged)
- `blitz-restructure.py` filters source list to files that exist; missing sources produce no-op
- `blitz-xref-audit.py` is read-only

## Why archived (not deleted)

1. **Audit trail** — proves what was mechanically applied vs hand-edited during the v1.9.0 cycle
2. **Repeatability** — a forked plugin attempting the same conventions can lift these
3. **Pattern reference** — future migrations can adapt the two-phase rewrite-then-move pattern

For the full v1.9.0 changelog, see `CHANGELOG.md` § `[1.9.0] — 2026-04-26`.
