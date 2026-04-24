# Domain Research — E-008 ui-audit skill foundation
<!-- generated: 2026-04-23 by domain-researcher -->

## 1. Playwright MCP Tool Surface (CAP-009)

### Minimum required tools

| Tool | Purpose | Required for CAP-009 |
|---|---|---|
| `browser_navigate` | Load page | Yes — `url` required |
| `browser_snapshot` | First-pass selector discovery, render confirmation | Yes |
| `browser_evaluate` | Ground-truth DOM extraction (single call, labeled object) | Yes — primary |
| `browser_wait_for` | Settle after navigate | Yes — spinner/skeleton wait |
| `browser_console_messages` | Error capture per page | Yes |
| `browser_network_requests` | Failed request capture per page | Yes |

No other tools are needed for CAP-009. `browser_take_screenshot` and `browser_click` are optional for later caps.

### `browser_evaluate` schema (from live tool)

```
Parameters: function (required string), element (optional), ref (optional), filename (optional)
```

- **No size/payload limit** is declared in the JSON-Schema. Playwright's underlying `page.evaluate()` serializes the return value via structured-clone; the practical cap is the MCP transport frame limit (~1 MB for most stdio transports), but nothing is documented. To stay safe: extract only the labeled scalar set per page (numbers, short strings), not innerHTML blobs or full DOM arrays.
- `filename` parameter: if provided, the evaluate result is saved to disk rather than returned inline. Use this for large payloads (e.g., interactive-element arrays of 100+ entries) to avoid bloating Claude's context.
- Return value must be JSON-serializable (structured-clone rules: no functions, no DOM nodes, no undefined).

### `browser_snapshot` schema

```
Parameters: depth (optional number), filename (optional)
```

- `depth` parameter caps the ARIA tree depth — useful for large pages to avoid truncation artifacts.
- `filename` saves snapshot to markdown file; use for pages where the snapshot exceeds 50 KB.

### `browser_wait_for` schema

```
Parameters: text (wait for appearance), textGone (wait for disappearance), time (seconds)
```

- **No `networkidle` parameter.** The tool only supports text-based or time-based waits.
- **Settle idiom for CAP-009 (derived from blitz:browse §3.1):**
  1. `browser_navigate(url)` — returns when page load event fires
  2. `browser_wait_for(textGone: <spinner text>)` if known
  3. `browser_wait_for(time: 1)` as fallback settle
  4. Max total wait cap: 10 s then proceed (matches blitz:browse)
  - There is no native `networkidle` in this MCP adapter; time-based + textGone is the correct substitute.

### `browser_network_requests` schema

```
Required params: static (bool), requestBody (bool), requestHeaders (bool)
Optional: filename, filter (regexp string)
```

- All three booleans are **required** in the JSON-Schema (no defaults applied by Claude). Story spec must explicitly pass `static: false, requestBody: false, requestHeaders: false` for minimal extraction.
- `filter` regexp is available to narrow to API endpoints only (e.g., `"/api/.*"`).

### `browser_console_messages` schema

```
Required: level (enum: "error" | "warning" | "info" | "debug")
Optional: filename, all (bool — cross-navigation history)
```

- Level enum is severity-inclusive-upward: `"error"` returns only errors; `"info"` returns all.
- Use `level: "error"` for failure-only capture per page tick.

---

## 2. JSONL Append Safety (CAP-009 loop ticks)

### Precedent: blitz:browse

From `skills/browse/reference.md` §crawl-ledger:
- `crawl-ledger.jsonl` and `fix-log.jsonl` are described as "append-only, crash-safe"
- Write order: **JSONL appends first, then JSON overwrites** — JSONL is the crash-recovery source
- No `flock` is used; design relies on single-session sequential writes

### Verdict for CAP-009

`>>` append is **race-safe enough** for single-session loop ticks. Rationale:
- Skills execute sequentially within a session; no concurrent writer to `page-data-registry.jsonl` during a single `blitz:ui-audit` run
- The `session-protocol.md` conflict matrix prevents two ui-audit sessions from running simultaneously (WRITE lock on `docs/crawls/`)
- `flock` adds complexity with zero benefit for the single-writer case — do not add it
- Risk vector: crash mid-write leaves a partial final line. Mitigate: construct the full JSONL string in memory before appending; on Phase 1 load, validate with `jq -c '.'` and drop any malformed last line

### Recommended load-time guard

```bash
jq -c '.' docs/crawls/page-data-registry.jsonl 2>/dev/null \
  > /tmp/pdr-clean.jsonl && mv /tmp/pdr-clean.jsonl docs/crawls/page-data-registry.jsonl
```

---

## 3. ARIA A11y Tree Truncation (§3.2 backup)

### Evidence backing §3.2's claim

1. **blitz:browse §3.4** (this codebase): uses `browser_snapshot` only for structural checks (broken images, dead links) — never for extracting numeric values. All numeric extraction in browse is via `browser_evaluate`.
2. **Accessibility API intermediation**: `browser_snapshot` renders text through the ARIA accessibility tree, which can reformat numbers (e.g., screen-reader APIs may strip thousands separators for digit-by-digit reading, or abbreviate long values).
3. **No documented byte/node truncation limit** exists in the MCP adapter schema. The `filename` and `depth` params exist precisely because snapshots can be large — implying they are not silently hard-truncated, but may be unwieldy.

### Authoritative limits

No published hard truncation limit was found for `browser_snapshot` in the installed MCP schema. The practical concern is accessibility-API reformatting, not byte truncation.

**Conclusion**: §3.2's recommendation stands — use `browser_evaluate` + `.textContent.trim()` for all registry writes regardless of snapshot behavior. CHECKS.md must document this as a hard rule.

---

## 4. jq Group-By Reducer for (label, page) Keys (CAP-010)

### Carry-forward registry precedent (authoritative in this codebase)

From `skills/_shared/carry-forward-registry.md`:
```bash
# Latest-wins by single key (.id):
jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl
```

### Adapting to two-key (label, page) — Phase 3 reducer

Research doc §6 Phase 3:
```bash
jq -s 'group_by(.label)
  | map({label: .[0].label,
         obs: group_by(.page) | map(max_by(.ts))})' \
  docs/crawls/page-data-registry.jsonl
```

**Correctness**: correct. `group_by` uses string equality; nested `group_by(.page) | map(max_by(.ts))` produces latest-wins per `(label, page)` pair. `max_by(.ts)` on ISO-8601 strings is lexicographically correct.

**One issue**: if `.ts` is missing on a malformed line, `max_by(.ts)` returns null for that group. Add guard:
```bash
jq -s '[.[] | select(.ts != null)]
  | group_by(.label)
  | map({label: .[0].label,
         obs: (group_by(.page) | map(max_by(.ts)))})' \
  docs/crawls/page-data-registry.jsonl
```

### Divergence detection query (emit finding when >1 distinct .parsed)

```bash
jq -s '
  [.[] | select(.ts != null)]
  | group_by(.label)
  | map({
      label: .[0].label,
      obs: (group_by(.page) | map(max_by(.ts))),
      distinct_values: ([group_by(.page) | map(max_by(.ts)) | .[] | .parsed] | unique)
    })
  | map(select(.distinct_values | length > 1))
' docs/crawls/page-data-registry.jsonl
```

### Flapping detection query (tick-over-tick, CAP-010)

```bash
jq -s '
  [.[] | select(.ts != null)]
  | group_by([.label,.page])
  | map({
      key: [.[0].label, .[0].page],
      recent: (sort_by(.tick) | .[-3:]),
      hash_count: (sort_by(.tick) | .[-3:] | [.[].hash] | unique | length)
    })
  | map(select(.hash_count > 1))
' docs/crawls/page-data-registry.jsonl
```
`hash_count > 1` in last 3 ticks = FLAPPING candidate.

---

## 5. Key Findings Summary (for story authors)

| # | Finding | Story impact |
|---|---|---|
| F1 | `browser_wait_for` has NO networkidle; only text/textGone/time | Phase 2 wait idiom: textGone + time:1 fallback; no networkidle reference |
| F2 | `browser_evaluate` has `filename` param — offload large payloads to disk | Use for interactive-element arrays (100+ items); scalar extractions return inline |
| F3 | `browser_snapshot` has `depth` param | CHECKS.md: use `depth:3` on first-pass discovery; never use for numeric reads |
| F4 | `>>` append safe for single-session; no flock needed | SKILL.md Phase 5 write spec: append via Bash `>>`, validate on load |
| F5 | jq `group_by(.label) | map(max_by(.ts))` is proven in carry-forward-registry.md | CAP-010 reducer correct; add `.ts != null` guard |
| F6 | `browser_network_requests` requires all 3 bool params explicitly (no defaults) | Story must specify `static:false, requestBody:false, requestHeaders:false` |
| F7 | `browser_console_messages` level enum is severity-inclusive-upward | Use `level:"error"` for failure-only; document in CHECKS.md |
| F8 | a11y snapshot reformats numbers via accessibility API — not hard-truncation | CHECKS.md hard rule: all registry writes via browser_evaluate .textContent only |

## 6. References

- Live tool schemas inspected this session: `mcp__plugin_playwright_playwright__browser_evaluate`, `browser_snapshot`, `browser_wait_for`, `browser_navigate`, `browser_network_requests`, `browser_console_messages`
- `/home/tom/development/blitz/skills/browse/SKILL.md` §3.1, §3.4, §3.5 (wait idiom, numeric extraction precedent)
- `/home/tom/development/blitz/skills/_shared/carry-forward-registry.md` (latest-wins jq idiom)
- `/home/tom/development/blitz/docs/_research/2026-04-23_ui-audit-skill.md` §3.2, §3.3, §3.5, §6
- Playwright evaluating docs: https://playwright.dev/docs/evaluating
- Playwright MCP: https://playwright.dev/mcp/introduction
