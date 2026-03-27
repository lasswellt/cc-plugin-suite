# Browse — Reference Material

## Error Classification Taxonomy

### Console Error Categories

| Category | Pattern | Severity | Example |
|----------|---------|----------|---------|
| **Uncaught Exception** | `Uncaught TypeError`, `Uncaught ReferenceError` | Critical | `Uncaught TypeError: Cannot read properties of undefined (reading 'map')` |
| **Unhandled Promise** | `Unhandled Promise Rejection` | Critical | `Unhandled Promise Rejection: NetworkError when attempting to fetch resource` |
| **Render Error** | `Failed to mount`, `render error`, `hydration mismatch` | Critical | `[Vue warn]: Failed to mount component: template or render function not defined` |
| **Chunk Load Failure** | `Loading chunk`, `Failed to fetch dynamically imported module` | Critical | `Error: Loading chunk vendors-node_modules_xxx failed` |
| **Security** | `Content Security Policy`, `Mixed Content`, `CORS` | Critical | `Refused to load the script because it violates the Content Security Policy` |
| **API Error** | Application-thrown errors from API calls | Error | `Error: Request failed with status code 403` |
| **Component Warning** | `[Vue warn]`, `Invalid prop`, `Missing required prop` | Error | `[Vue warn]: Invalid prop: type check failed for prop "items"` |
| **Missing Resource** | `404`, `Failed to load resource` | Error | `GET http://localhost:3000/api/users 404 (Not Found)` |
| **Deprecation** | `deprecated`, `will be removed` | Warning | `[Deprecation] The feature will be removed in a future version` |
| **Vue Dev Warning** | `[Vue devtools]`, `[HMR]`, `[vite]` | Known Noise | `[vite] hot updated: /src/components/Header.vue` |
| **Extension Error** | Chrome extension URLs, `chrome-extension://` | Known Noise | `Error in chrome-extension://xxx/content.js` |
| **Favicon** | `favicon.ico` | Known Noise | `GET http://localhost:3000/favicon.ico 404` |

### Network Failure Categories

| Status Range | Category | Severity | Typical Cause |
|-------------|----------|----------|---------------|
| **0** | Connection Failed | Critical | Server down, CORS blocked, network error |
| **500-599** | Server Error | Critical | Backend crash, unhandled exception |
| **401** | Unauthorized | Error | Token expired, auth misconfigured |
| **403** | Forbidden | Error | Insufficient permissions |
| **404** | Not Found | Error | Wrong endpoint URL, missing resource |
| **400** | Bad Request | Error | Malformed request, validation failure |
| **408** | Timeout | Warning | Slow backend, large payload |
| **429** | Rate Limited | Warning | Too many requests |
| **300-399** | Redirect | Info | Expected behavior, but note redirect chains |

### Content Quality Issues

| Issue | Detection Method | Severity |
|-------|-----------------|----------|
| **Placeholder text** | Regex match for "Lorem ipsum", "TODO", "FIXME", "example.com" | Warning |
| **Mock data** | Regex match for "John Doe", "Jane Doe", "foo@bar", "test@test" | Warning |
| **Broken images** | `<img>` with error event or empty/missing `src` | Error |
| **Dead links** | `href="#"`, `href="javascript:void(0)"`, `href=""` | Warning |
| **Empty data views** | Container visible but no content, no empty state message | Error |
| **Console.log left in** | `console.log` in production build output | Info |
| **Unstyled content** | Flash of unstyled content, missing CSS | Error |

---

## Error Recovery Procedures

### Browser Crash Recovery
```
1. Detect: Browser tool calls fail or timeout
2. Action: Close browser (browser_close)
3. Wait: 2 seconds
4. Action: Record finding — Critical: "Browser crash on [route]"
5. Action: Open new browser (browser_navigate to BASE_URL)
6. Verify: Page loads successfully
7. Continue: Resume crawl from next route
8. Note: If crash repeats on same route, skip permanently
```

### Navigation Timeout Recovery
```
1. Detect: Page not ready after 15 seconds
2. Action: Take screenshot of current state
3. Action: Record finding — Warning: "Navigation timeout on [route]"
4. Action: Check console for errors (may reveal cause)
5. Continue: Navigate to next route
6. Note: Timeout routes often indicate infinite loops or missing data
```

### Authentication Loss Recovery
```
1. Detect: Page redirects to login, or 401 responses appear
2. Action: Record finding — Critical: "Authentication lost at [route]"
3. Action: Stop crawl
4. Report: Output partial report
5. Instruct user: "Session expired. Please re-authenticate and re-run."
```

### Dev Server Unreachable Recovery
```
1. Detect: Navigation fails with connection refused
2. Action: Wait 5 seconds
3. Retry: Attempt navigation once more
4. If still failing: Stop crawl
5. Report: Output partial report with note
6. Instruct user: "Dev server appears to have stopped."
```

### Memory Pressure Recovery
```
1. Detect: Browser becomes sluggish, pages take >10s to load
2. Action: Close browser immediately
3. Action: Open new browser instance
4. Continue: Resume from current route
5. Reduce: Lower browser recycling threshold to every 25 routes
```

---

## Auto-Fix Templates

### Undefined Property Access
**Error**: `Cannot read properties of undefined (reading 'xxx')`
**Fix**: Add optional chaining
```typescript
// Before
const value = obj.nested.property

// After
const value = obj?.nested?.property
```

### Missing Null Check in Template
**Error**: `Cannot read properties of null (reading 'length')`
**Fix**: Add v-if guard or fallback
```vue
<!-- Before -->
<div>{{ items.length }} items</div>

<!-- After -->
<div>{{ items?.length ?? 0 }} items</div>
```

### Missing Import
**Error**: `xxx is not defined`
**Fix**: Add the missing import statement
```typescript
// Add to top of <script setup>
import { xxx } from '@/path/to/module'
```

### Wrong API Endpoint (404)
**Error**: `GET /api/old-endpoint 404`
**Fix**: Update the endpoint URL
```typescript
// Before
const response = await api.get('/api/old-endpoint')

// After
const response = await api.get('/api/correct-endpoint')
```

### Missing Error State
**Error**: Component shows blank when API fails
**Fix**: Add error handling to the template
```vue
<!-- Add after the loading check -->
<div v-else-if="error" class="error-state">
  <p>Failed to load data. Please try again.</p>
</div>
```

### Missing Loading State
**Error**: Component shows flash of empty content before data loads
**Fix**: Add loading guard
```vue
<!-- Add before the data display -->
<template v-if="loading">
  <!-- Use project's skeleton pattern -->
</template>
```

### Unhandled Promise Rejection
**Error**: `Unhandled Promise Rejection` in async function
**Fix**: Add try-catch
```typescript
// Before
const data = await fetchData()

// After
try {
  const data = await fetchData()
} catch (error) {
  console.error('Failed to fetch data:', error)
  // Set error state
}
```

### Missing Reactive Reference
**Error**: `xxx is not defined` in template, but variable exists in setup
**Fix**: Ensure the variable is returned or defined with ref/reactive
```typescript
// Before
let count = 0

// After
const count = ref(0)
```

### CORS Error
**Error**: `Access to fetch has been blocked by CORS policy`
**Fix**: This is a server-side fix. Record as "needs manual fix" with instruction:
```
Server needs to add CORS headers for the requesting origin.
Check: vite.config proxy, server CORS middleware, or API gateway config.
```

### Dynamic Import Failure
**Error**: `Failed to fetch dynamically imported module`
**Fix**: Add error handling to dynamic import
```typescript
// Before
const Component = defineAsyncComponent(() => import('./Component.vue'))

// After
const Component = defineAsyncComponent({
  loader: () => import('./Component.vue'),
  errorComponent: ErrorFallback,
  timeout: 10000,
})
```

---

## Report Template Structure

```markdown
# Browse Test Report

**Date**: YYYY-MM-DD HH:mm
**Mode**: [full | smoke | page <path> | fix]
**Base URL**: [http://localhost:XXXX]
**Routes discovered**: [N total]
**Routes tested**: [N tested] / [N total]
**Routes skipped**: [N skipped] (dynamic params, auth callbacks, etc.)
**Duration**: [Xm Ys]

---

## Summary

| Severity | Count | Auto-fixed |
|----------|-------|------------|
| Critical | X     | X          |
| Error    | X     | X          |
| Warning  | X     | —          |
| Info     | X     | —          |

**Overall health**: [PASS | WARN | FAIL]
- PASS: 0 Critical, 0 Error
- WARN: 0 Critical, 1+ Error or 5+ Warning
- FAIL: 1+ Critical

---

## Critical Issues

### [Short description]
- **Route(s)**: `/path` (also seen on: `/other`, `/another` — N total)
- **Category**: [Console Error | Network Failure | Render Issue | Security]
- **Details**: [Full error message]
- **Stack trace** (if available):
  ```
  [stack trace, truncated to relevant frames]
  ```
- **Source file**: `src/path/to/file.ts:123` (if identifiable)
- **Auto-fix**: [Applied — description | Not attempted | Failed — reason]

---

## Error Issues

[Same format as Critical, grouped by route]

---

## Warning Issues

[Same format, collapsed if many]

---

## Info / Observations

- [Observation 1]
- [Observation 2]

---

## Clean Routes

<details>
<summary>[N] routes with no issues</summary>

- `/route1`
- `/route2`
- ...

</details>

---

## Auto-Fix Summary (fix mode only)

| # | File | Change | Lines Modified | Verified |
|---|------|--------|---------------|----------|
| 1 | `src/path/file.ts` | Added optional chaining for user.name | 1 | PASS |
| 2 | `src/path/other.vue` | Added error state template | 5 | PASS |
| 3 | `src/path/api.ts` | Fixed endpoint URL | 1 | FAIL — new 403 |

### Fixes Not Attempted
| Issue | Reason |
|-------|--------|
| CORS error on /api/external | Server-side fix required |
| Missing env variable | Configuration issue, not a code fix |

---

## Recommendations

1. [Highest priority recommendation]
2. [Second priority recommendation]
3. [Third priority recommendation]

---

## Test Environment

- **Framework**: [detected framework]
- **UI Framework**: [detected UI framework]
- **Browser**: Chromium (Playwright)
- **Viewport**: 1440x900 (desktop default)
```

---

## Safe Interaction Catalog

### Always Safe (interact freely)
| Element | Action | Condition |
|---------|--------|-----------|
| Tab buttons | Click | Part of a tab group (`role="tab"`) |
| Pagination controls | Click next/prev | Numbered pagination or next/prev buttons |
| Table sort headers | Click | Column headers with sort indicators |
| Accordions | Click to expand | Expand/collapse toggles |
| Breadcrumbs | Click | Navigation breadcrumb links within the app |
| Sidebar sections | Click to expand | Collapsible sidebar groups |
| "Show more" buttons | Click | Expands content without navigation |

### Conditionally Safe (interact with caution)
| Element | Action | Condition |
|---------|--------|-----------|
| Navigation links | Click | Only if target is in the route manifest |
| Dropdown menus | Open | Click to open, but do NOT select items that modify data |
| Search inputs | Type | Only in filter/search contexts, not create forms |
| View toggle (grid/list) | Click | Switches display mode only |

### Never Safe (do not interact)
| Element | Reason |
|---------|--------|
| Delete / Remove buttons | Destructive |
| Save / Submit / Create buttons | Data mutation |
| Form inputs (in create/edit contexts) | Data mutation |
| Toggle switches | Data mutation |
| Checkboxes (in data contexts) | Data mutation |
| Confirmation dialog buttons | May trigger destructive action |
| Logout / Sign out | Breaks session |
| Settings that persist | Data mutation |
| Import / Upload buttons | Data mutation |
| Approve / Reject buttons | Data mutation |

---

## Loop Mode — Crawl State Schemas

### `docs/crawls/crawl-queue.json`

Tracks pages discovered but not yet visited, plus URL pattern dedup.

```json
{
  "base_url": "http://localhost:3000",
  "queue": [
    {
      "url": "/dashboard",
      "parent": "/",
      "nav_context": "nav",
      "priority": 8.5,
      "depth": 1,
      "discovered_tick": 1
    }
  ],
  "url_patterns_seen": ["/users/:id", "/projects/:uuid"],
  "tick_count": 14,
  "started_at": "2026-03-27T04:15:00Z"
}
```

**Fields:**
- `base_url`: The dev server origin (e.g., `http://localhost:3000`)
- `queue[]`: Ordered list of pages to visit. Sorted by `priority` descending at read time.
- `queue[].url`: Relative path (e.g., `/dashboard/analytics`)
- `queue[].parent`: The page URL where this link was discovered
- `queue[].nav_context`: Where the link was found: `root`, `nav`, `sidebar`, `content`, `footer`
- `queue[].priority`: Computed score: `(10 - depth) × context_multiplier`
- `queue[].depth`: Number of clicks from root to reach this page
- `queue[].discovered_tick`: Which tick found this link
- `url_patterns_seen[]`: Normalized URL patterns for dedup (e.g., `/users/:id`)
- `tick_count`: Total ticks executed so far
- `started_at`: ISO-8601 timestamp of first tick

### `docs/crawls/crawl-visited.json`

Tracks pages already crawled and their status.

```json
{
  "pages": {
    "/": {
      "title": "Home",
      "visited_tick": 1,
      "visited_at": "2026-03-27T04:20:00Z",
      "status": "clean",
      "links_found": 12,
      "findings_count": 0,
      "fixes_applied": 0
    },
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

**Status values:**
- `clean` — No issues found
- `has_issues` — Issues found, some may be unfixed
- `fixed` — Had issues, all were auto-fixed
- `needs_re_verify` — A shared file was modified by a fix; this page imports that file and needs re-checking
- `unreachable` — Navigation failed 3+ times
- `re-verified` — Re-checked after fixes, now clean

### `docs/crawls/hierarchy.json`

Navigational graph stored as an adjacency list. Each node represents one page. The web is a directed graph, not a tree — a page like `/settings` may be linked from both the global nav and from `/dashboard/preferences`. The `discovered_from` field determines the display tree position; `also_linked_from` preserves the full link graph.

```json
{
  "nodes": {
    "/": {
      "title": "Home",
      "depth": 0,
      "discovered_from": null,
      "also_linked_from": [],
      "children": ["/dashboard", "/settings", "/users"],
      "nav_context": "root",
      "external_links": ["https://docs.example.com"]
    },
    "/dashboard": {
      "title": "Dashboard",
      "depth": 1,
      "discovered_from": "/",
      "also_linked_from": ["/settings"],
      "children": ["/dashboard/analytics", "/dashboard/reports"],
      "nav_context": "nav",
      "external_links": []
    }
  }
}
```

**Fields:**
- `nodes{}`: Keyed by relative URL path
- `title`: Page title from `<title>` or first `<h1>`
- `depth`: Distance from root (0 for `/`). Based on `discovered_from` chain, not shortest path.
- `discovered_from`: URL of the page that first linked here (null for root). Determines position in the display tree.
- `also_linked_from[]`: Other pages that also link to this page. Preserves the full link graph for navigation analysis.
- `children[]`: URLs discovered on this page that are internal
- `nav_context`: Where this page's link appeared on its parent
- `external_links[]`: External URLs found on this page (informational only)

### `docs/crawls/crawl-ledger.jsonl`

Append-only JSONL findings log. One finding per line.

```jsonl
{"id":"console-err-/dashboard-TypeError-abc123","page":"/dashboard","type":"console_error","severity":"critical","category":"Uncaught Exception","message":"Uncaught TypeError: Cannot read properties of undefined","source_file":"src/pages/dashboard.vue:42","status":"found","found_tick":2,"fixed_tick":null}
{"id":"network-404-/dashboard-api-users","page":"/dashboard","type":"network_failure","severity":"error","category":"Not Found","message":"GET /api/users 404","source_file":null,"status":"fixed","found_tick":2,"fixed_tick":2}
```

**Fields:**
- `id`: Dedup key: `{type}-{page}-{short_hash}`
- `page`: Route where the issue was found
- `type`: `console_error`, `console_warning`, `network_failure`, `content_quality`, `render_issue`
- `severity`: `critical`, `error`, `warning`, `info`
- `category`: From the Error Classification Taxonomy (above)
- `message`: Full error message
- `source_file`: Source file:line if identifiable
- `status`: `found`, `fixed`, `needs-human`, `wontfix`, `noise`
- `found_tick`: Tick number when discovered
- `fixed_tick`: Tick number when fixed (null if not fixed)

### `docs/crawls/fix-log.jsonl`

Append-only log of fix attempts.

```jsonl
{"tick":2,"page":"/dashboard","finding_id":"network-404-/dashboard-api-users","file":"src/api/users.ts","change":"Fixed API endpoint from /api/users to /api/v2/users","verified":true,"commit":"abc1234"}
{"tick":5,"page":"/settings","finding_id":"console-err-/settings-ref","file":"src/pages/settings.vue","change":"Added optional chaining for user.preferences","verified":false,"reverted":true,"reason":"Typecheck failed: TS2532"}
```

### `docs/crawls/latest-tick.json`

Snapshot of the most recent tick for quick status checks.

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

**Status values:**
- `crawling` — Normal operation, queue has entries
- `re-verifying` — Queue empty, re-checking pages with issues
- `complete` — All pages visited and clean
- `auth_lost` — Authentication expired, needs user intervention
- `server_down` — Dev server unreachable

---

## Loop Mode — URL Normalization Rules

### Dynamic Segment Patterns

When a new URL is found, normalize it to a pattern for dedup:

| Pattern | Regex | Replacement | Example |
|---------|-------|-------------|---------|
| UUID | `/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i` | `:uuid` | `/users/550e8400-e29b-41d4-a716-446655440000` → `/users/:uuid` |
| Numeric ID | Path segment matching `/^\d+$/` | `:id` | `/users/123` → `/users/:id` |
| Date | `/\d{4}-\d{2}-\d{2}/` | `:date` | `/reports/2026-03-27` → `/reports/:date` |
| Firestore ID | Path segment matching `/^[A-Za-z0-9]{20,}$/` | `:docid` | `/docs/abc123def456ghi789jk` → `/docs/:docid` |
| Slug with ID | `/[a-z-]+-\d+$/` | `:slug` | `/posts/my-post-123` → `/posts/:slug` |

### Normalization Steps (in order)

1. Parse URL, resolve relative paths against `BASE_URL`
2. Decode percent-encoded characters (`%20` → space, `%C3%A9` → `é`) before comparison
3. Extract pathname only (discard origin, query, fragment)
4. **Hash routing check**: if the app uses hash-based routing (`/#/page`), treat the hash as the pathname. Detect by checking if `BASE_URL` contains `/#/` or if root page has `#/` in its links.
5. Remove trailing slash (except for root `/`)
6. Apply dynamic segment patterns to each path segment
7. Compare normalized pattern against `url_patterns_seen[]`
8. If pattern already seen → skip. If new → add to `url_patterns_seen[]` and enqueue.

### Edge Cases

| Case | Handling |
|------|----------|
| **Percent-encoded characters** | Decode before dedup: `/users/john%20doe` and `/users/john doe` are the same |
| **Case sensitivity** | Treat paths as case-sensitive (Linux servers are case-sensitive). `/Dashboard` ≠ `/dashboard` |
| **Hash routing (`/#/`)** | If app uses hash routing, extract path from hash: `/#/dashboard` → `/dashboard` |
| **Section anchors (`#section`)** | Strip: `/page#section` → `/page` |
| **Protocol-relative URLs** | `//example.com/page` → treat as external (different origin) |
| **Base path prefix** | If app is served at `/app/`, normalize: `/app/dashboard` → `/dashboard` (strip base path) |
| **Redirect chains** | If navigation results in URL change (redirect), record BOTH the original and final URL in visited. Use the final URL as the canonical. |
| **Query strings with semantic meaning** | Strip all query params by default. If you observe that `/page?tab=settings` loads entirely different content than `/page`, note it in findings as an observation but still strip. |

### Filter Rules (never enqueue)

| Rule | Pattern |
|------|---------|
| External origin | `new URL(href).origin !== new URL(BASE_URL).origin` |
| Non-HTTP scheme | `mailto:`, `tel:`, `javascript:`, `data:`, `blob:` |
| Auth paths | `/auth/*`, `/oauth/*`, `/login`, `/logout`, `/callback`, `/signup`, `/register`, `/forgot-password`, `/reset-password` |
| File downloads | Ends with: `.pdf`, `.zip`, `.csv`, `.xlsx`, `.doc`, `.docx`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.mp4`, `.mp3` |
| Already visited | Exact URL exists in `crawl-visited.json` |
| Already queued | Exact URL exists in `crawl-queue.json` queue |
| Pattern seen | Normalized pattern exists in `url_patterns_seen[]` |
| API endpoints | Starts with `/api/`, `/_/`, `/__/` |
| Static assets | Starts with `/_nuxt/`, `/static/`, `/assets/`, `/public/` |

---

## Loop Mode — Navigation Context Classification

When extracting links, classify each by its DOM context to prioritize navigation-critical pages.

### Detection Method

For each `<a>` element, check its ancestor chain:

| Context | Detection | Priority Multiplier |
|---------|-----------|-------------------|
| **nav** | Inside `<nav>`, `<header>`, `[role="navigation"]`, `.navbar`, `.nav-menu` | ×2.0 |
| **sidebar** | Inside `<aside>`, `[role="complementary"]`, `.sidebar`, `.side-nav`, `.drawer` | ×1.5 |
| **content** | Inside `<main>`, `[role="main"]`, `.content`, or none of the above | ×1.0 |
| **footer** | Inside `<footer>`, `.footer` | ×0.5 |

**Priority formula**: `(10 - depth) × context_multiplier`

Where `depth` is the current page's depth + 1 (the new link will be one level deeper).

### Examples

| Link Location | Depth | Priority |
|--------------|-------|----------|
| Root page nav link → `/dashboard` | 1 | (10-1) × 2.0 = **18.0** |
| Dashboard sidebar → `/dashboard/analytics` | 2 | (10-2) × 1.5 = **12.0** |
| Content area link → `/blog/post-1` | 2 | (10-2) × 1.0 = **8.0** |
| Footer link → `/privacy` | 1 | (10-1) × 0.5 = **4.5** |

---

## Loop Mode — Tick Budget Breakdown

Target: < 2 minutes per tick.

| Step | Estimated Time | Notes |
|------|---------------|-------|
| Load state files | 1–2s | Read 6 JSON/JSONL files |
| Navigate to page | 3–5s | Including DNS, TLS, initial load |
| Wait for full load | 5–15s | Network idle + content landmarks + deferred rendering |
| Capture errors | 2–3s | Console messages + network requests |
| Snapshot + quality | 3–5s | Accessibility tree + content checks |
| Safe interactions | 10–20s | Tabs, pagination, accordions (varies by page) |
| Extract links | 2–3s | Parse snapshot or evaluate script |
| Auto-fix (0–2 fixes) | 0–60s | Read source, edit, verify, commit |
| Save state | 1–2s | Write 6 files |
| **Total** | **27–115s** | Well within 2-minute target |

---

## Loop Mode — Completion Criteria

The crawl is **complete** when ALL of these are true:

1. `crawl-queue.json` queue is empty (no more pages to visit)
2. All pages in `crawl-visited.json` have been re-verified (status is `clean`, `fixed`, or `re-verified`)
3. OR: 3 consecutive ticks discovered zero new links and queue remains empty

After completion:
- Run cross-page visual audit (Phase 7.4)
- Set `latest-tick.json` status to `"complete"`
- Print the full site map tree
- Generate a final report summarizing all findings, fixes, visual audit, and the hierarchy
- Subsequent ticks will detect `complete` status and exit with: `[browse] Crawl already complete. To re-crawl, delete docs/crawls/ and re-run.`

---

## Loop Mode — Visual Analysis

### Structural Metadata Schema

Extracted from the accessibility snapshot on every tick. Stored in `crawl-visited.json` under each page's `"structure"` field.

```json
{
  "has_breadcrumbs": true,
  "has_pagination": false,
  "has_sidebar": true,
  "has_search": false,
  "has_footer": true,
  "card_count": 4,
  "table_row_count": 0,
  "image_count": 3,
  "broken_image_count": 0,
  "heading_levels": ["h1", "h2"],
  "nav_item_count": 7,
  "loading_indicators_present": false,
  "empty_containers": 0,
  "content_density": "low|medium|high"
}
```

**Detection methods from accessibility snapshot:**

| Field | How to Detect |
|-------|--------------|
| `has_breadcrumbs` | Look for `nav` with `aria-label="breadcrumb"` or element containing `>` separators with hierarchical links |
| `has_pagination` | Look for `nav` with `aria-label="pagination"` or elements with "Previous"/"Next" + page numbers |
| `has_sidebar` | Look for `aside`, `[role="complementary"]`, or element with sidebar/drawer class names |
| `has_search` | Look for `input[type="search"]`, `[role="search"]`, or input with placeholder containing "search" |
| `has_footer` | Look for `footer` element or `[role="contentinfo"]` |
| `card_count` | Count elements with card/panel-like structure (distinct bordered/shadowed containers) |
| `table_row_count` | Count `tr` elements inside `tbody` (0 = empty table) |
| `image_count` | Count `img` elements in content area (exclude nav icons, favicons) |
| `broken_image_count` | Count `img` with `alt` containing "error" or missing `src`, or with explicit error state |
| `heading_levels` | Collect unique heading levels (`h1`-`h6`) present on the page |
| `nav_item_count` | Count link elements inside the primary `nav` |
| `loading_indicators_present` | Check for: `[aria-busy="true"]`, elements with "loading"/"spinner"/"skeleton" in class/role, progress bars |
| `empty_containers` | Count visible containers (has a heading or label) with no child content and no "empty state" message |
| `content_density` | Estimate based on total text node count: <20 text nodes = `low`, 20-100 = `medium`, >100 = `high` |

### Visual Finding Types

Visual findings use `type: "visual"` in the crawl ledger. Subcategories:

| Subcategory | Severity | Description | Auto-fixable |
|-------------|----------|-------------|-------------|
| `visual_data_missing` | Warning | Page appears to have incomplete or missing data (empty table, chart with no data, sparse content) | No |
| `visual_loading_stuck` | Error | Loading state that didn't resolve (stuck spinner, unresolving skeleton) | No |
| `visual_layout_broken` | Error | Layout/overflow/overlap issue visible in screenshot | Sometimes — check for missing CSS class or container overflow |
| `visual_design_inconsistency` | Warning | Page is inconsistent with established patterns across the site | No |
| `visual_empty_state` | Warning | Content area is blank with no empty-state message for the user | Sometimes — can add a basic empty-state template |

### Screenshot Safety Rules

Screenshots are a powerful but expensive tool. Follow these rules strictly:

1. **Resize browser to 1280×720** before every screenshot — prevents oversized images that crash the session
2. **Viewport-only screenshots** — NEVER full-page. Long pages can produce images exceeding 8000px height, causing unrecoverable API errors
3. **One screenshot per tick maximum** — each costs ~1,600 tokens; multiple screenshots fill context rapidly
4. **PNG format preferred** — lossless, sharper text for analysis
5. **Conditional triggers only** — do NOT screenshot every page. Only when structural analysis flags an anomaly or on every 10th tick.
6. **Disable animations before capture** — inject CSS `* { animation: none !important; transition: none !important; }` via `browser_evaluate` before taking screenshot to avoid partial animation frames

### Cross-Page Comparison: Anomaly Detection

After 10+ pages have been visited, structural metadata enables pattern-based anomaly detection without screenshots:

**Global element detection** (identify elements present on 80%+ of pages):
```
For each boolean field (has_breadcrumbs, has_pagination, has_sidebar, has_search, has_footer):
  count = pages where field is true
  percentage = count / total_pages
  if percentage >= 0.8:
    mark as "global element"

For each page missing a global element:
  finding: visual_design_inconsistency
  message: "[element] missing — present on [count]/[total] other pages"
```

**Sibling comparison** (compare pages at same hierarchy depth or sharing a parent):
```
For pages sharing the same parent (e.g., all children of /dashboard):
  Compute: median card_count, median table_row_count, median content_density

  For each page in the group:
    if table_row_count == 0 AND median > 5:
      finding: visual_data_missing — "Table has 0 rows (siblings median: [N])"
    if content_density == "low" AND median_density in ["medium", "high"]:
      finding: visual_data_missing — "Low content density (siblings: [density])"
    if card_count == 0 AND median_card_count > 0:
      finding: visual_design_inconsistency — "No cards found (siblings have [N] cards)"
```

**Heading hierarchy check** (global consistency):
```
Compute most common heading pattern: e.g., most pages use [h1, h2, h3]

For each page:
  if page uses h3 as top-level heading but most pages use h1:
    finding: visual_design_inconsistency — "Top heading is h3 (expected h1)"
  if page skips heading levels (h1 → h3, no h2):
    finding: visual_design_inconsistency — "Heading levels skip h2"
```

### Cross-Page Visual Audit Prompt Template (COMPLETE phase)

Used when taking screenshots of page groups for final comparison:

```
You are analyzing [N] pages from the [section] section of a Vue/Nuxt application.
Each screenshot is labeled with its URL path.

Analyze these pages TOGETHER for the following:

1. DESIGN CONSISTENCY
   - Do all pages use the same layout structure (sidebar, header, content area)?
   - Are headings, fonts, and spacing consistent?
   - Are colors and component styles consistent?
   - Are buttons, cards, tables styled the same way?

2. MISSING ELEMENTS
   - Are navigation elements (breadcrumbs, sidebar, header) present on all pages?
   - Does any page lack pagination, search, or filters that siblings have?
   - Are empty states handled consistently (or are some pages just blank)?

3. DATA COMPLETENESS
   - Do any pages appear to have missing or incomplete data?
   - Are there empty tables, charts with no data, or sparse cards?
   - Do all pages with images have proper images (no broken/placeholder icons)?

4. LAYOUT QUALITY
   - Any overlapping text or elements?
   - Content overflowing containers?
   - Inconsistent alignment or grid structure?
   - Responsive issues visible (if viewport is not desktop)?

For each issue found, return:
- Page URL
- Issue category (consistency/missing/data/layout)
- Specific description
- Severity (error/warning)
```
