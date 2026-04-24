# Sprint-6 Codebase Research — ui-audit Skill Foundation (E-008)
# codebase-analyst agent — 2026-04-24

---

## 1. Skill Frontmatter Template

Source: `skills/browse/SKILL.md` lines 1-11

```yaml
---
name: browse
description: <one-liner matching skill-registry entry>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
compatibility: ">=2.1.50"
argument-hint: "[mode] [target] -- modes: ..."
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
```

**Field order (exact):**
1. `name`
2. `description`
3. `allowed-tools`
4. `model`
5. `compatibility`
6. `argument-hint`

**Phase 0 session-registration boilerplate** — `skills/browse/SKILL.md` lines 47-51:
```markdown
## Phase 0: Parse Arguments

### 0.0 Register Session
Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the
[verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session
directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions,
read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed.
Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.
```

Copy this block verbatim for ui-audit Phase 0.0.

**detect-stack pattern** — `skills/browse/SKILL.md` line 11:
```
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
```
Use identical line in ui-audit SKILL.md to inject stack detection output.

---

## 2. Conflict Matrix

Source: `skills/_shared/session-protocol.md` lines 215-250

Table header and row format:
```markdown
| Session A | Session B | Resolution |
|-----------|-----------|------------|
| browse (loop) | browse (loop) | **BLOCK** — concurrent crawls |
| browse (loop) | sprint-dev | WARN — browse may fix files sprint-dev is editing |
| browse (full/smoke/page) | browse (full/smoke/page) | OK — read-only, session-scoped |
```

**New rows needed for ui-audit:**
```markdown
| ui-audit | ui-audit | **BLOCK** — concurrent audits write overlapping state |
| ui-audit | browse (loop) | WARN — both write to docs/crawls/ |
| ui-audit | sprint-dev | OK — read-only audit during implementation |
```

Add these rows at the end of the conflict matrix table (`session-protocol.md` after line 250).

---

## 3. Skill-Registry Entry

Source: `.claude-plugin/skill-registry.json`

**All required fields on an entry** (from browse entry, lines 161-170):
```json
{
  "name": "browse",
  "category": "core-dev",
  "description": "...",
  "model": "opus",
  "modifies_code": true,
  "uses_agents": false,
  "uses_sessions": true,
  "dependencies": [],
  "maturity": "stable"
}
```

**ui-audit entry to add** (mirror browse; initial maturity = beta):
```json
{
  "name": "ui-audit",
  "category": "core-dev",
  "description": "UI consistency auditor — reads browse crawl state, extracts per-page data registry, detects cross-page design inconsistencies, reports layout/color/typography violations",
  "model": "opus",
  "modifies_code": false,
  "uses_agents": true,
  "uses_sessions": true,
  "dependencies": ["browse"],
  "maturity": "beta"
}
```

Insert after the `browse` entry (after line 170 in skill-registry.json).

---

## 4. Browse State File Schemas

All schemas from `skills/browse/reference.md` lines 369-531.

### `docs/crawls/crawl-visited.json` (ref lines 406-438)
```json
{
  "pages": {
    "/dashboard": {
      "title": "Dashboard",
      "visited_tick": 2,
      "visited_at": "2026-03-27T04:25:00Z",
      "status": "has_issues",
      "links_found": 8,
      "findings_count": 3,
      "fixes_applied": 1
    }
  }
}
```
Key per-page fields: `title`, `visited_tick`, `visited_at`, `status`, `links_found`, `findings_count`, `fixes_applied`.

### `docs/crawls/hierarchy.json` (ref lines 443-469)
```json
{
  "nodes": {
    "/dashboard": {
      "title": "Dashboard",
      "depth": 1,
      "discovered_from": "/",
      "also_linked_from": ["/settings"],
      "children": ["/dashboard/analytics"],
      "nav_context": "nav",
      "external_links": []
    }
  }
}
```
Key fields: `nodes{}` keyed by relative URL. Each node: `title`, `depth`, `discovered_from`, `also_linked_from`, `children`, `nav_context`, `external_links`.

### `docs/crawls/latest-tick.json` (ref lines 512-531)
```json
{
  "tick": 14,
  "page_visited": "/settings/profile",
  "pages_visited_total": 14,
  "pages_queued": 23,
  "findings_total": 7,
  "fixes_applied": 3,
  "fixes_failed": 1,
  "hierarchy_depth": 3,
  "status": "crawling",
  "circuit_breaker_cooldown": 0,
  "consecutive_fix_failures": 0,
  "updated_at": "2026-03-27T05:25:00Z"
}
```
**CAP-009 addition:** `page_data_registry` field to add at top-level:
```json
"page_data_registry": "docs/crawls/page-data-registry.json"
```
This field is added by ui-audit Phase 2 (extraction) so subsequent ticks and audit runs know where per-page structured data lives.

### `docs/crawls/crawl-ledger.jsonl` (ref lines 482-499)
Append-only JSONL. One finding per line. Key fields: `id`, `page`, `type`, `severity`, `category`, `message`, `source_file`, `status`, `found_tick`, `fixed_tick`.

---

## 5. Playwright MCP Tool Load Pattern

Source: `skills/browse/SKILL.md` lines 82-95 (Phase 1.2)

```markdown
### 1.2 Load Playwright MCP Tools
Use ToolSearch to find and load all Playwright MCP browser tools:
- `browser_navigate` — navigate to URLs
- `browser_snapshot` — capture accessibility snapshot
- `browser_click` — click elements
- `browser_press_key` — keyboard input
- `browser_take_screenshot` — capture visual state
- `browser_tabs` — list open tabs
- `browser_close` — close browser
- `browser_resize` — change viewport
- `browser_console_messages` — read console output
- `browser_network_requests` — read network activity

If Playwright MCP tools are not available, tell the user and stop.
```

**ui-audit Phase 1 should use the identical ToolSearch pattern.** Minimum tools needed: `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`. Copy the full block and trim to relevant tools.

---

## 6. jq Append-Latest-Wins Reducer

Source: `skills/_shared/carry-forward-registry.md` lines 21-24 and lines 185-188

**Primary location (inline doc comment):**
```bash
jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl
```
File: `skills/_shared/carry-forward-registry.md`, line 22-24

**Extended reader examples (lines 185-206):**
```bash
# Latest-wins reduction
jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl

# All active entries
jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.status == "active" or .status == "partial"))' \
  .cc-sessions/carry-forward.jsonl
```

**CAP-010 story ref:** "Uses carry-forward-registry.md latest-wins reducer pattern (`jq -s 'group_by(.id) | map(max_by(.ts))'`) to reduce page-data-registry JSONL to per-page latest record for cross-page invariant checks."

---

## 7. Story `verify:` Field Format

Source: `sprints/sprint-5/stories/S5-001-agent-prompt-boilerplate.md` lines 22-25 and `S5-002-spawn-protocol-warning-upgrade.md` lines 15-17.

**S5-001 verify block:**
```yaml
verify:
  - "test -f skills/_shared/agent-prompt-boilerplate.md"
  - "test $(grep -l 'agent-prompt-boilerplate' skills/*/reference.md | wc -l) -ge 7"
```

**S5-002 verify block:**
```yaml
verify:
  - "! grep -q 'WARNING (not BLOCKER)' skills/_shared/spawn-protocol.md"
  - "grep -qE 'BLOCKER.*terse-output|sprint-review.*fails' skills/_shared/spawn-protocol.md"
```

**Patterns:**
- Inline shell strings (not a script file reference)
- `test -f <path>` for file existence
- `grep -q` / `! grep -q` for presence/absence checks
- `test $(cmd | wc -l) -ge N` for count assertions
- Each check is independently runnable in < 1 second
- List length: 2-4 items typically

**ui-audit story verify examples (draft):**
```yaml
verify:
  - "test -f skills/ui-audit/SKILL.md"
  - "grep -q 'name: ui-audit' skills/ui-audit/SKILL.md"
  - "grep -q 'ui-audit' .claude-plugin/skill-registry.json"
```

---

## 8. marketplace.json — ui-audit Row Needed?

Source: `.claude-plugin/marketplace.json`

```json
{
  "name": "blitz",
  "metadata": {"description": "..."},
  "owner": {"name": "lasswellt"},
  "plugins": [
    {
      "name": "blitz",
      "source": "./",
      "description": "Production-grade development skills for Vue/Nuxt + Firebase with 33 skills, 6 agents, and 12 hooks",
      "version": "1.5.0"
    }
  ]
}
```

**Finding:** marketplace.json has only ONE entry — the whole blitz plugin. Individual skills are NOT listed here (they are in `skill-registry.json`). No new row needed for ui-audit.

**However:** the `description` field's skill count ("33 skills") will need bumping when ui-audit is added. That's a story task, not a new row.

---

## Summary for Story Writers

| Question | Answer | Source |
|----------|--------|--------|
| Frontmatter fields | name, description, allowed-tools, model, compatibility, argument-hint | browse/SKILL.md L1-7 |
| detect-stack line | `` !`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` `` | browse/SKILL.md L11 |
| Phase 0.0 boilerplate | Copy browse/SKILL.md L47-51 | browse/SKILL.md |
| Conflict matrix location | session-protocol.md L215-250 | session-protocol.md |
| Conflict row format | `\| Session A \| Session B \| Resolution \|` | session-protocol.md |
| Registry required fields | 9 fields: name, category, description, model, modifies_code, uses_agents, uses_sessions, dependencies, maturity | skill-registry.json L161-170 |
| crawl-visited.json schema | pages{} keyed by path, per-page: title/visited_tick/status/findings_count | browse/reference.md L406-438 |
| hierarchy.json schema | nodes{} keyed by path, per-node: title/depth/children/nav_context | browse/reference.md L443-469 |
| latest-tick.json schema | flat obj with tick/page_visited/findings_total/status | browse/reference.md L512-531 |
| latest-tick new field | `"page_data_registry": "docs/crawls/page-data-registry.json"` | new (CAP-009) |
| Playwright load pattern | ToolSearch → list browser_* tools, stop if unavailable | browse/SKILL.md L82-95 |
| jq reducer | `jq -s 'group_by(.id) \| map(max_by(.ts))'` | carry-forward-registry.md L22 |
| verify: field format | inline shell strings, 2-4 items, test -f / grep -q style | S5-001/S5-002 stories |
| marketplace.json | No new row; bump skill count in description when shipping | marketplace.json |
