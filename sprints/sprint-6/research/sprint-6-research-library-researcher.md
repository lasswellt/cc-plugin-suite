# Library Researcher — Sprint-6 / E-008 ui-audit Skill Foundation

**Date:** 2026-04-23 | **Session:** library-researcher for sprint-plan-4e3c67f0

---

## 1. Skill Frontmatter — Model, Effort, Allowed-Tools

### Confirmed patterns (from codebase)

Every SKILL.md uses a YAML frontmatter block. Required fields observed across all skills:

```yaml
---
name: <skill-name>
description: <one-liner>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep[, ToolSearch][, WebSearch, WebFetch][, Agent]
model: opus | sonnet
compatibility: ">=2.1.XX"
---
```

**`model: opus`** — correct for ui-audit. All quality-category skills that spawn agents or do complex reasoning use `opus`: `codebase-audit`, `quality-metrics`, `perf-profile`, `integration-check`. Sonnet is used for lighter mechanical tasks (`code-sweep`, `completeness-gate`, `dep-health`). ui-audit is reasoning-heavy → `opus`.

**`effort:` field** — does NOT exist in any current SKILL.md frontmatter in this repo. The skill-registry.json also has no `effort` field (all 34 entries omit it). Do not add an `effort:` key; it is not a recognized frontmatter field in this plugin suite.

**`allowed-tools` with `ToolSearch`** — required when the skill loads Playwright MCP dynamically. Browse (`skills/browse/SKILL.md` line 4) uses exactly:
```
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
```
`ToolSearch` is the mechanism for loading deferred MCP tools at runtime (confirmed: tools like `mcp__plugin_playwright_playwright__browser_navigate` appear deferred until ToolSearch fetches their schema). ui-audit must include `ToolSearch` in `allowed-tools`. No `WebSearch`/`WebFetch` needed for the audit skill itself.

**`compatibility`** — Browse uses `">=2.1.50"`, sprint-plan uses `">=2.1.71"` (added Agent). If ui-audit uses Agent for role-matrix parallelism, use `">=2.1.71"`; otherwise `">=2.1.50"` matches browse.

**Recommended frontmatter for ui-audit:**
```yaml
---
name: ui-audit
description: Cross-page data-consistency and quality auditor. Extracts labeled values via browser_evaluate, enforces invariants across pages and roles, tracks STABLE/CHANGED/FLAPPING state. Use when: "audit UI consistency", "check data matches", "run ui-audit".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
compatibility: ">=2.1.50"
---
```

---

## 2. Playwright MCP Tool Name Stability

The tool names used by `blitz:browse` (the closest sibling skill) are the canonical reference. From `skills/browse/SKILL.md` lines 83–90 and `skills/browse/reference.md`:

| Tool referenced in browse | Available in MCP (confirmed via deferred tool list) |
|---|---|
| `browser_navigate` | `mcp__plugin_playwright_playwright__browser_navigate` ✓ |
| `browser_snapshot` | `mcp__plugin_playwright_playwright__browser_snapshot` ✓ |
| `browser_evaluate` | `mcp__plugin_playwright_playwright__browser_evaluate` ✓ |
| `browser_console_messages` | `mcp__plugin_playwright_playwright__browser_console_messages` ✓ |
| `browser_network_requests` | `mcp__plugin_playwright_playwright__browser_network_requests` ✓ |

All five names the ui-audit skill plans to use are confirmed stable and present in the current environment. The ToolSearch query to load them is:
```
select:mcp__plugin_playwright_playwright__browser_navigate,mcp__plugin_playwright_playwright__browser_snapshot,mcp__plugin_playwright_playwright__browser_evaluate,mcp__plugin_playwright_playwright__browser_console_messages,mcp__plugin_playwright_playwright__browser_network_requests
```

No renames detected. The `browse` SKILL.md uses short names (`browser_navigate`) in prose descriptions while the actual MCP tool is the fully-qualified `mcp__plugin_playwright_playwright__*` form. The SKILL.md instruction pattern is:
```
Use ToolSearch to find and load all Playwright MCP browser tools:
- `browser_navigate` — navigate to URLs
```
ui-audit should follow the same pattern (prose short names, ToolSearch loads full names at runtime).

---

## 3. jq Version Compatibility

**Environment:** jq-1.7 (confirmed). Baseline assumption for this repo: jq ≥1.6.

**`group_by` with null keys** — tested live:
```bash
printf '{"label":null,"v":1}\n{"label":"x","v":2}\n...' | jq -s 'group_by(.label) | map(max_by(.v))'
```
Result: null-keyed entries are sorted into their own group (first group, before string keys). This is jq's defined behavior since 1.6 — null sorts before strings in jq comparisons. **Not a crash; safe to use.**

**Gotcha**: If a page extraction returns null for a label (e.g., selector not found), the reducer groups it separately with key `null`. The reducer should filter out null-key groups before emitting invariant checks:
```bash
jq -s 'group_by(.label) | map(select(.[0].label != null)) | ...'
```

**`-s` flag with JSONL input** — confirmed working. `jq -s` reads newline-delimited objects into a single array. The reducer pattern `jq -s 'group_by(.label) | map(max_by(.ts))'` works correctly on the append-only registry JSONL.

**jq 1.6 vs 1.7 differences relevant here:** None for `group_by`, `map`, `max_by`, `select`. These are stable across 1.6+.

---

## 4. Multi-File Skill Conventions

### Directory structure (from browse and sprint-plan)

```
skills/ui-audit/
  SKILL.md          # frontmatter + orchestration instructions
  reference.md      # schemas, invariant format, tool patterns, jq examples
```

Both `browse` and `sprint-plan` follow this two-file pattern. `reference.md` carries everything too long for SKILL.md: schemas, example code, edge cases, tool invocation patterns.

### Skill-registry.json required fields (all 9 must be present)

```json
{
  "name": "ui-audit",
  "category": "quality",
  "description": "...",
  "model": "opus",
  "modifies_code": false,
  "uses_agents": false,
  "uses_sessions": true,
  "dependencies": [],
  "maturity": "experimental"
}
```

- `category: "quality"` — matches sibling skills (`integration-check`, `codebase-audit`, etc.)
- `modifies_code: false` — ui-audit is read-only audit (no auto-fix in foundation sprint)
- `uses_sessions: true` — writes to `.cc-sessions/` and `docs/crawls/`
- `uses_agents: false` — unless CAP-013 reporter spawns agents (add `true` + bump compatibility to `>=2.1.71`)
- `maturity: "experimental"` — new skill, not yet stable
- All 9 fields are required; zero optional fields exist in the registry schema

### Reference to shared protocols

Skills consistently include at the top of SKILL.md:
```
Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) and [verbose-progress.md](/_shared/verbose-progress.md).
```
ui-audit must include this. The `_shared/` path is relative to the plugin root (resolved at runtime).

---

## 5. Hash Idiom — md5 vs sha256 Portability

**Tested on WSL2 (this environment):**
```
sha256sum: 37d2046a395c...566  -    (64-char hex + "  -")
sha1sum:   f572d396fae9...58f  -    (40-char hex + "  -")
md5sum:    b1946ac92492...84  -     (32-char hex + "  -")
```

**Portability verdict:**
- `md5sum` exists on Linux/WSL; macOS ships `md5` (not `md5sum`) — portable script needs `md5sum 2>/dev/null || md5 -q`
- `sha256sum` exists on Linux/WSL; macOS ships `shasum -a 256` — same problem
- **Recommendation: use `sha1sum` on Linux/WSL, or use the portable form:**
  ```bash
  hash_val=$(printf '%s' "$raw" | sha256sum 2>/dev/null | awk '{print $1}' \
    || printf '%s' "$raw" | shasum -a 256 | awk '{print $1}')
  ```
  Or simpler: since the hash is only used for tick-diff comparison (not cryptography), **use the first 8 chars of sha256**:
  ```bash
  printf '%s' "$raw" | sha256sum | cut -c1-8
  ```
  On macOS: `printf '%s' "$raw" | shasum -a 256 | cut -c1-8`

- **Best portable idiom (cross-platform, no dependency):**
  ```bash
  _hash() { printf '%s' "$1" | sha256sum 2>/dev/null || printf '%s' "$1" | shasum -a 256; }
  hash=$(_hash "$raw_value" | cut -c1-8)
  ```

**Avoid `md5sum` / `md5` for new code.** The macOS/Linux naming divergence is a real gotcha. SHA-256 with the fallback above is the correct approach.

---

## 6. Summary for Story Implementation Notes

| Area | Finding | Source |
|---|---|---|
| Frontmatter `model` | `opus` ✓ | skills/browse/SKILL.md, registry |
| Frontmatter `effort` | **Omit** — not a recognized field | All 34 SKILL.md files + registry |
| Frontmatter `allowed-tools` | Include `ToolSearch` for Playwright MCP dynamic loading | skills/browse/SKILL.md line 4 |
| Playwright tool names | All 5 target names stable and confirmed present | deferred tool list |
| ToolSearch pattern | Described in browse SKILL.md lines 83–90; ui-audit copies same pattern | skills/browse/SKILL.md |
| jq `group_by` + null | Safe — nulls group separately; add `select(.[0].label != null)` guard | live test jq-1.7 |
| jq baseline | 1.6+ — all used builtins (`group_by`, `max_by`, `map`, `select`) stable since 1.6 | — |
| Registry fields | 9 required fields, all mandatory, no optionals | skill-registry.json (34/34) |
| Multi-file layout | `SKILL.md` + `reference.md` in `skills/ui-audit/` | browse, sprint-plan patterns |
| Hash idiom | Use `sha256sum ... \|\| shasum -a 256 ...` fallback; take first 8 chars | live test |
| Category | `quality` | registry: integration-check, codebase-audit, etc. |
