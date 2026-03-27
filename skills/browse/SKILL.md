---
name: browse
description: Automated browser testing, site crawling, and visual analysis via Playwright MCP. Navigates pages, clicks safe interactive elements, captures console errors and failed network requests. Classifies findings and optionally auto-fixes source issues. In loop mode, crawls one page per tick, builds a navigational hierarchy, performs visual/design analysis via screenshots, detects cross-page inconsistencies, and auto-fixes issues. Use when user says "test pages", "smoke test", "check console errors", "browse test", "crawl site", "check design".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
compatibility: ">=2.1.50"
argument-hint: "[mode] [target] -- modes: full | smoke | page <path> | fix | --loop"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

You are an automated browser tester, site crawler, and visual design analyst. You navigate every reachable page in the application, interact with safe UI elements, capture errors, classify them, and optionally auto-fix source issues. In `--loop` mode, you crawl one page per tick, discover links from the rendered DOM, build a navigational hierarchy of the entire site, perform visual analysis to detect missing data and design inconsistencies, and auto-fix issues as you go.

## Additional Resources
- For error classification taxonomy, fix templates, interaction safety rules, crawl state schemas, URL normalization rules, visual analysis methods, and cross-page comparison techniques, see [reference.md](reference.md)

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER click destructive buttons** — Do not click anything labeled: Delete, Remove, Archive, Disable, Revoke, Destroy, Drop, Purge, Reset, Terminate, or any synonyms. When in doubt, do not click.

2. **NEVER fill and submit forms** — Do not type into input fields and submit. You may click tabs, pagination, sort headers, and accordions. You may NOT fill text fields, select dropdowns with new values, or press Save/Submit/Create.

3. **NEVER interact with confirmation dialogs** — If a dialog appears (confirm, alert, prompt), press Escape immediately. Never click OK, Confirm, Yes, or Accept.

4. **Each page visit is independent** — Do not rely on state from a previous page visit. Do not assume data created on one page exists on another.

5. **In fix mode, apply only minimal changes** — Fix only what is broken. Do not refactor, restyle, or "improve" code. The smallest change that resolves the error is the correct fix.

6. **NEVER interact with logout/sign-out buttons** — Logging out would break the entire test session.

7. **NEVER modify or delete data** — You are a read-only observer. Toggle switches, checkboxes that change data, and edit-in-place fields are off-limits.

---

## Phase 0: Parse Arguments

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

Parse the invocation arguments to determine mode and target.

| Mode | Argument | Behavior |
|------|----------|----------|
| **Full** | `full` or no argument | Crawl all routes |
| **Smoke** | `smoke` | Crawl first 10 routes only |
| **Page** | `page <path>` | Test only the specified path (e.g., `page /dashboard`) |
| **Fix** | `fix` | Full crawl + auto-fix detected issues |
| **Loop** | `--loop` | One page per tick, auto-fix, auto-commit, build site hierarchy. Use with `/loop 5m`. |

Store the parsed mode for use in subsequent phases.

---

## Phase 1: Prerequisites

### 1.1 Verify Dev Server
```bash
# Check if dev server is running on common ports
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || \
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 || \
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
```

If no dev server is running:
1. Find the dev script in `package.json`
2. Tell the user: "No dev server detected. Please start it with `[detected command]` and re-run this skill."
3. **Stop execution.** Do not attempt to start the dev server yourself.

Record the `BASE_URL` (e.g., `http://localhost:3000`).

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

### 1.3 Load Route Manifest

**Skip this step in `--loop` mode** — loop mode discovers routes from the rendered DOM, not from files.

Discover all application routes:

1. **File-based routing** (Nuxt): Glob `pages/**/*.vue` and derive routes
2. **Explicit router**: Read `src/router/index.ts` or `src/router/routes.ts` or similar
3. **Search**: Grep for `path:` in router files

Build a route list:
```
[
  { path: "/", name: "home" },
  { path: "/dashboard", name: "dashboard" },
  ...
]
```

Exclude:
- Routes with dynamic segments that require specific IDs (e.g., `/users/:id`) unless sample data is discoverable
- Authentication callback routes (`/auth/callback`, `/oauth/*`)
- Wildcard/catch-all routes (`/:pathMatch(.*)*`)

Sort routes: static routes first, then routes with optional params.

---

## Phase 2: Verify Authentication

1. Navigate to `BASE_URL`
2. Wait for page to stabilize (no loading indicators, content visible)
3. Take a snapshot
4. Check if the page shows a login form or redirected to a login URL

**If login is required:**
- Tell the user: "Authentication is required. Please log in manually in the browser, then re-run this skill."
- **Stop execution.** Do not attempt to fill login credentials.

**If logged in:**
- Record the authenticated state and continue.

---

## Phase 3: Route Crawl

Initialize counters:
```
routesVisited = 0
routesFailed = 0
findings = []
browserAge = 0
```

### For Each Route:

#### 3.1 Navigate
- Navigate to `BASE_URL + route.path`
- Wait for readiness:
  1. Wait for network idle (no pending requests for 500ms)
  2. Wait for content landmarks (heading, main content area, or data table)
  3. Wait for loading indicators to disappear (spinners, skeletons, progress bars)
  4. Maximum wait: 10 seconds, then proceed with whatever is loaded

#### 3.2 Capture Console Errors
- Read all console messages since navigation
- Filter to `error` and `warning` levels
- Record each with: level, message text, source URL, route path

#### 3.3 Capture Network Failures
- Read all network requests since navigation
- Filter to: status >= 400, status === 0 (failed), CORS errors
- Record each with: method, URL, status code, route path
- Ignore known noise: favicon.ico 404, browser extension requests, analytics failures

#### 3.4 Snapshot and Content Quality
- Take an accessibility snapshot
- Check for:
  - **Mock/placeholder data**: Text containing "Lorem ipsum", "test", "TODO", "FIXME", "example.com", "John Doe", "Jane Doe", "foo", "bar"
  - **Broken images**: Images with error state or empty `src`
  - **Dead links**: Links with `href="#"` or `href="javascript:void(0)"`
  - **Empty containers**: Visible sections with no content (missing empty state)
  - **Overlapping text**: Text nodes that might overlap (check via screenshot if suspicious)

#### 3.5 Safe Interactions
Interact ONLY with these element types:
- **Tabs**: Click each tab, snapshot after switch
- **Pagination**: Click "next page" if available, snapshot
- **Sort headers**: Click a table column header to trigger sort, snapshot
- **Accordions/Expanders**: Click to expand collapsed sections, snapshot
- **Navigation sub-menus**: Hover to reveal, but do not click navigation away

After each interaction:
- Wait 1 second for UI to settle
- Check for new console errors
- Check for new network failures

**NEVER interact with**: buttons (except tabs), form inputs, toggles, checkboxes, links that navigate away, anything inside a modal/dialog.

#### 3.6 Browser Recycling
Increment `browserAge` after each route. When `browserAge >= 50`:
- Close the browser
- Open a new browser instance
- Re-navigate to the current route
- Reset `browserAge = 0`

This prevents memory leaks from accumulating across many page visits.

#### 3.7 Progress Reporting
Every 10 routes, output a progress summary:
```
Progress: [N]/[total] routes visited | [errors] errors found | [warnings] warnings
```

---

## Phase 4: Error Classification

Classify every finding into one of these severity levels:

### Critical (must fix before release)
- JavaScript runtime errors (uncaught exceptions, undefined references)
- Network 500 errors (server crashes)
- White screen / render failure (page shows nothing)
- Security errors (mixed content, CSP violations)

### Error (should fix soon)
- Network 400-499 errors (bad requests, unauthorized, not found)
- Console errors from application code (not third-party)
- Missing data states (no loading, no empty state, no error handling)
- Broken images or failed resource loads

### Warning (fix when convenient)
- Console warnings from application code
- Deprecation warnings
- Mock/placeholder data in production-like views
- Accessibility issues (missing labels, poor contrast)
- Dead links (`href="#"`)

### Info (track but do not fix)
- Third-party library warnings
- Browser-specific warnings
- Performance observations (slow loads)

### Known Noise (ignore)
- Favicon 404
- Browser extension errors
- Hot Module Replacement messages
- Vue devtools messages
- Source map warnings

See reference.md for the full classification taxonomy with examples.

---

## Phase 5: Auto-Fix (fix mode only)

**Only runs when mode is `fix`.**

For each Critical and Error finding:

### 5.1 Trace to Source
1. Read the error message and stack trace (if available)
2. Identify the source file and line number
3. Read the source file to understand context
4. Identify the root cause

### 5.2 Apply Minimal Fix
- Fix ONLY the specific error — do not refactor surrounding code
- Common fixes (see reference.md for templates):
  - **Undefined variable**: Add null check or optional chaining
  - **Missing import**: Add the import statement
  - **Type error**: Fix the type mismatch
  - **Network 404**: Fix the API endpoint path
  - **Missing error state**: Add basic error handling
  - **Missing loading state**: Add loading skeleton

### 5.3 Re-verify
After applying a fix:
1. Navigate back to the affected route
2. Check that the original error is gone
3. Check that no new errors appeared
4. Record the fix: file path, change description, before/after

### 5.4 Fix Limits
- Maximum 10 auto-fixes per run. If more are needed, report remaining issues for manual fix.
- If a fix introduces new errors, revert it and report as "needs manual fix."
- Never fix the same file more than 3 times in one run.

### 5.5 Fix Quality Gate

Auto-fixes must produce production-ready code. See [Definition of Done](/_shared/definition-of-done.md).

**BANNED in auto-fixes:**
- Replacing a real error with a silent `return` or empty catch block
- Adding `// TODO: fix properly` comments instead of actual fixes
- Suppressing errors with `@ts-ignore` or `eslint-disable` without resolving the root cause

---

## Phase 6: Report

Write a structured report to stdout.

### Report Format

```markdown
# Browse Test Report
**Date**: [ISO date]
**Mode**: [full | smoke | page | fix]
**Base URL**: [URL]
**Routes tested**: [N] / [total]
**Duration**: [time]

## Summary
| Severity | Count |
|----------|-------|
| Critical | [n]   |
| Error    | [n]   |
| Warning  | [n]   |
| Info     | [n]   |

## Critical Issues
### [Issue title]
- **Route**: [path]
- **Type**: [console error | network failure | render issue]
- **Message**: [error message]
- **Source**: [file:line if known]
- **Fix applied**: [Yes/No — only in fix mode]

## Error Issues
[same format]

## Warning Issues
[same format]

## Routes with No Issues
[list of clean routes — collapsed if many]

## Auto-Fix Summary (fix mode only)
| File | Change | Verified |
|------|--------|----------|
| [path] | [description] | [pass/fail] |
```

### Report Rules
- Group findings by route, then by severity
- Deduplicate identical errors across routes (note "seen on N routes")
- Include the specific console message or network request details
- For fix mode, include before/after for each fix
- If the run was interrupted, note which routes were not visited

---

## Error Recovery

If the browser crashes or becomes unresponsive:
1. Close the browser
2. Wait 2 seconds
3. Open a new browser instance
4. Skip the problematic route
5. Record it as a Critical finding: "Browser crash on route [path]"
6. Continue with the next route

If a page navigation times out (>15 seconds):
1. Record as Warning: "Navigation timeout on route [path]"
2. Take a screenshot of whatever loaded
3. Continue with the next route

If the dev server becomes unreachable:
1. Wait 5 seconds and retry once
2. If still unreachable, stop the crawl
3. Output partial report with note: "Dev server became unreachable after [N] routes"

---

## Loop Mode (`--loop`)

**When mode is `--loop`, Phases 0–2 still execute normally (session registration, prerequisites, auth check), then skip Phases 3–6 and execute these loop-specific phases instead.**

Loop mode is designed for `/loop 5m /blitz:browse --loop`. Each tick visits one page, discovers links, fixes issues, and exits. Over many ticks, this builds a complete navigational hierarchy of the site.

**Tick lifecycle**: `SEED → CRAWL → CRAWL → ... → RE-VERIFY → COMPLETE`

**Tick budget**: < 2 minutes per tick (hard timeout: 100 seconds). The 5-minute loop interval provides buffer. If any phase exceeds remaining time, skip to Phase 7-LOOP (Save State) and exit gracefully.

**Autonomy**: Full. Auto-approve all, auto-commit+push, no user prompts.

**Crawl limits** (prevent crawler traps):
- **Max depth**: 8 levels from root. Pages deeper than this are not enqueued.
- **Max pages**: 500 total. Override with `docs/crawls/.crawl-config.json` → `{ "max_pages": 1000 }`.
- **Max ticks**: 300 (25 hours at 5-min intervals). After this, complete regardless of queue.

**Browser lifecycle**: The Playwright MCP browser may or may not persist between ticks — each tick must NOT assume browser state from the previous tick. Always start with `browser_navigate` to the target page. Auth state (cookies, localStorage) is managed by the MCP server; if auth is lost, the recovery procedure handles it.

---

### Phase 3-LOOP: Load Crawl State

#### 3.0 Tick Overlap Guard
Before loading state, check for concurrent ticks:
1. Read `docs/crawls/latest-tick.json` (if exists)
2. If `updated_at` is less than 2 minutes ago → another tick is likely still running. Exit with: `[browse] Tick overlap detected. Previous tick updated ${seconds}s ago. Skipping.`
3. If `status` is `"auth_lost"` → exit with: `[browse] Auth lost. Please re-authenticate and delete docs/crawls/latest-tick.json to resume.`
4. If `status` is `"complete"` → exit with: `[browse] Crawl complete. To re-crawl, delete docs/crawls/ and re-run.`
5. If `status` is `"server_down"` → proceed (will retry server connection)

#### 3.1 Load or Initialize State
1. Check if `docs/crawls/crawl-queue.json` exists.
2. **If it does NOT exist** (first tick / SEED):
   - Create `docs/crawls/` directory
   - Initialize `crawl-queue.json` with the root URL `/` as the only entry:
     ```json
     {
       "base_url": "<BASE_URL>",
       "queue": [
         { "url": "/", "parent": null, "nav_context": "root", "priority": 10, "depth": 0, "discovered_tick": 0 }
       ],
       "url_patterns_seen": [],
       "tick_count": 0,
       "started_at": "<ISO-8601>"
     }
     ```
   - Initialize empty `crawl-visited.json`, `hierarchy.json`, `crawl-ledger.jsonl`, `fix-log.jsonl`, `latest-tick.json`
3. **If it exists** (subsequent tick):
   - Load all state files from `docs/crawls/`
   - If any JSON file fails to parse: rename it to `.bak`, log warning, attempt to reconstruct from `crawl-ledger.jsonl` (append-only, most reliable). If reconstruction fails, re-seed from scratch.
   - Increment `tick_count`
   - Check crawl limits: if `tick_count > max_ticks` or visited pages > `max_pages`, set tick type to COMPLETE.
4. **Determine tick type**:
   - `SEED` — first tick, queue was just initialized
   - `CRAWL` — queue has entries
   - `RE-VERIFY` — queue is empty, but `crawl-visited.json` has pages with `status: "has_issues"` that haven't been re-verified
   - `COMPLETE` — queue is empty AND all pages are clean or re-verified. Print final site map and exit.

See reference.md for full state file schemas.

---

### Phase 4-LOOP: Visit One Page

#### 4.1 Pop Next Page
- Sort queue by `priority` (descending)
- Pop the highest-priority entry
- In RE-VERIFY mode: instead pop the first page with `status: "has_issues"` from `crawl-visited.json`

#### 4.2 Navigate
- Navigate to `BASE_URL + page.url`
- **Wait for full page load** — this is critical, the page must be fully rendered:
  1. Wait for network idle (no pending requests for 2 seconds)
  2. Wait for content landmarks (heading, main content area, or data table visible)
  3. Wait for loading indicators to disappear (spinners, skeletons, progress bars, `[aria-busy="true"]`)
  4. Maximum wait: 15 seconds, then proceed with whatever is loaded
  5. After the wait, pause an additional 2 seconds for any deferred rendering (lazy-loaded images, intersection observers)

#### 4.3 Capture Console Errors
- Read all console messages since navigation
- Filter to `error` and `warning` levels
- Record each with: level, message text, source URL, page path

#### 4.4 Capture Network Failures
- Read all network requests since navigation
- Filter to: status >= 400, status === 0 (failed), CORS errors
- Record each with: method, URL, status code, page path
- Ignore known noise: favicon.ico 404, browser extension requests, analytics failures

#### 4.5 Snapshot, Content Quality, and Structural Metadata
- Take an accessibility snapshot
- **Content quality checks:**
  - **Mock/placeholder data**: Text containing "Lorem ipsum", "TODO", "FIXME", "example.com", "John Doe", "Jane Doe"
  - **Broken images**: Images with error state or empty `src`
  - **Dead links**: Links with `href="#"` or `href="javascript:void(0)"`
  - **Empty containers**: Visible sections with no content (missing empty state)

- **Extract structural metadata** from the snapshot (see reference.md for full schema). Record for each page:
  - `has_breadcrumbs`, `has_pagination`, `has_sidebar`, `has_search`, `has_footer`
  - `card_count`, `table_row_count`, `image_count`, `broken_image_count`
  - `heading_levels` (which h1-h6 are present)
  - `nav_item_count` (how many items in primary nav)
  - `loading_indicators_present` (spinners, skeletons, `[aria-busy="true"]` still visible)
  - `empty_containers` (sections with no content and no empty-state message)
  - `content_density` — rough estimate: `low` (mostly whitespace), `medium`, `high`

  Store this metadata in `crawl-visited.json` under the page entry as `"structure": {...}`. This enables cross-page comparison after enough pages are visited (see Phase 5.6).

#### 4.6 Safe Interactions
Same rules as Phase 3.5 in non-loop mode. Interact ONLY with:
- **Tabs**: Click each tab, snapshot after switch
- **Pagination**: Click "next page" if available, snapshot
- **Sort headers**: Click a table column header, snapshot
- **Accordions/Expanders**: Click to expand, snapshot

After each interaction:
- Wait 1 second for UI to settle
- Check for new console errors and network failures
- **Re-snapshot** — interactions (especially tabs) often reveal new content with new links. Collect links from each post-interaction snapshot for Phase 5-LOOP.

**NEVER interact with**: buttons (except tabs), form inputs, toggles, checkboxes, links that navigate away, anything inside a modal/dialog.

#### 4.7 Extract Page Title
- Read the page `<title>` or the first `<h1>` from the snapshot
- Store as the page's display name in the hierarchy

#### 4.8 Visual Analysis (Conditional Screenshot)

**This step is NOT taken on every tick.** Take a screenshot and perform visual analysis ONLY when one or more of these triggers are met:

1. **Empty container detected** — a content area is blank with no empty-state message
2. **Loading indicators still present** — spinners, skeletons, or `[aria-busy]` visible after full wait
3. **Structural anomaly** — page is missing a pattern that 80%+ of visited pages have (e.g., no breadcrumbs when most pages have them). Requires 10+ pages visited.
4. **Content density outlier** — page has significantly less content than sibling pages at the same hierarchy depth
5. **Every 10th tick** — periodic visual check regardless of triggers

**When triggered:**

1. **Resize browser** to 1280×720 (prevents oversized screenshot issues)
2. Take a **viewport-only screenshot** (never full-page — long pages can exceed 8000px and crash the session)
3. Analyze the screenshot for:

   **Data completeness:**
   - Tables with headers but no rows
   - Charts with axes but no data
   - Cards that are emptier than similar cards on other pages
   - Avatar/profile images that are generic placeholders
   - Sections that should have content but show only whitespace

   **Loading state issues:**
   - Stuck spinners or progress bars
   - Skeleton placeholders that never resolved to real content
   - Partially loaded content (some sections rendered, others blank)

   **Layout and design issues:**
   - Overlapping text or elements
   - Content overflowing its container (horizontal scroll)
   - Misaligned elements that break the visual grid
   - Inconsistent spacing compared to other pages
   - Z-index issues (elements hidden behind others)

   **Design consistency** (requires 10+ pages visited — compare against accumulated structural metadata):
   - Typography inconsistencies (different heading sizes for same-level content)
   - Color usage that doesn't match the established palette
   - Component variants used inconsistently (e.g., primary buttons where siblings use secondary)
   - Missing UI patterns present on sibling pages (pagination, search, filters)

4. Record visual findings in the ledger with `type: "visual"` and a subcategory:
   - `visual_data_missing` — page appears to have incomplete or missing data
   - `visual_loading_stuck` — loading state that didn't resolve
   - `visual_layout_broken` — layout/overflow/overlap issue
   - `visual_design_inconsistency` — inconsistent with established page patterns
   - `visual_empty_state` — empty area with no user-facing message

5. **Token budget**: One screenshot costs ~1,600 tokens. Keep visual analysis under 30 seconds.

---

### Phase 5-LOOP: Extract Links & Build Hierarchy

#### 5.1 Extract Links
Combine links from ALL snapshots taken during Phase 4 — the initial page snapshot AND every post-interaction snapshot (tabs, pagination, accordions may reveal new links). Deduplicate by href.

Use `browser_snapshot` to find all link elements. The accessibility tree returns refs for clickable elements including links with their text and href.

**Fallback**: If the snapshot doesn't expose hrefs, use `browser_evaluate` with:
```javascript
JSON.stringify(
  Array.from(document.querySelectorAll('a[href]')).map(a => ({
    href: a.href,
    text: a.textContent.trim().slice(0, 100),
    inNav: !!a.closest('nav, [role="navigation"], header'),
    inSidebar: !!a.closest('aside, [role="complementary"], .sidebar'),
    inFooter: !!a.closest('footer')
  }))
)
```

#### 5.2 Normalize & Filter URLs
For each extracted link, apply the normalization rules from reference.md:

1. Parse the URL. If relative, resolve against `BASE_URL`.
2. **Skip if**:
   - External origin (different host than `BASE_URL`)
   - `mailto:`, `tel:`, `javascript:`, `data:` scheme
   - Auth path: matches `/auth/*`, `/oauth/*`, `/login`, `/logout`, `/callback`, `/signup`, `/register`
   - File download: ends with `.pdf`, `.zip`, `.csv`, `.xlsx`, `.doc`, `.png`, `.jpg`, `.svg`
   - Already in `crawl-visited.json` (exact URL)
   - Already in queue (exact URL)
3. Strip hash fragments (`#section` → removed)
4. Strip query parameters (visit base URL only)
5. Normalize trailing slashes (remove trailing `/`)
6. **Dynamic segment dedup**: Normalize the URL to a pattern:
   - UUID segments: `/[0-9a-f]{8}-[0-9a-f]{4}-...` → `:uuid`
   - Numeric IDs: `/\d+` (path segment that is all digits) → `:id`
   - Date strings: `/\d{4}-\d{2}-\d{2}` → `:date`
   - Firestore-style IDs: `/[A-Za-z0-9]{20,}` → `:docid`
   - Check if the normalized pattern exists in `url_patterns_seen[]`. If so, skip.
   - If not, add the pattern to `url_patterns_seen[]`.

#### 5.3 Classify & Enqueue
For each link that passes filtering:
1. Classify navigation context:
   - **nav**: Link is inside `<nav>`, `<header>`, or `role="navigation"` → priority multiplier ×2.0
   - **sidebar**: Inside `<aside>`, `role="complementary"`, or `.sidebar` → multiplier ×1.5
   - **content**: In main content area → multiplier ×1.0
   - **footer**: Inside `<footer>` → multiplier ×0.5
2. Compute priority: `(10 - depth) × context_multiplier`
   - `depth` = current page's depth + 1
3. Add to queue:
   ```json
   { "url": "/path", "parent": "<current_page_url>", "nav_context": "nav", "priority": 8.5, "depth": 2, "discovered_tick": 14 }
   ```

#### 5.4 Update Hierarchy
1. Add current page as a node in `hierarchy.json` (if not already present):
   ```json
   { "title": "Page Title", "depth": 1, "discovered_from": "/", "also_linked_from": [], "children": [], "nav_context": "nav", "external_links": [] }
   ```
   - `discovered_from` is the page that first linked here (determines tree position)
   - `also_linked_from` captures additional pages that link here (preserves full link graph)
2. If the page already exists in the hierarchy but is discovered again from a different parent, append to `also_linked_from[]`
3. Add newly discovered internal links as children of the current node
4. Record any external links in the node's `external_links[]` array
5. If the current page's `discovered_from` node exists, ensure this page is in its `children[]`

#### 5.5 Update Visited Map
Add/update the current page in `crawl-visited.json`:
```json
{
  "title": "Page Title",
  "visited_tick": 14,
  "visited_at": "<ISO-8601>",
  "status": "clean|has_issues",
  "links_found": 8,
  "findings_count": 2,
  "fixes_applied": 0,
  "structure": {
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
    "content_density": "medium"
  }
}
```

#### 5.6 Cross-Page Structural Comparison

**Run only after 10+ pages have been visited.** Compare the current page's structural metadata against accumulated patterns:

1. **Compute pattern baselines** from all visited pages:
   - What percentage have breadcrumbs? Pagination? Sidebar? Search?
   - What is the median card count, table row count, image count per page?
   - What is the typical nav item count?

2. **Flag anomalies** when the current page deviates:
   - **Missing common element**: If 80%+ of pages have breadcrumbs but this page doesn't → finding: `visual_design_inconsistency`
   - **Structural outlier**: If sibling pages (same hierarchy depth or same parent section) have 10+ table rows but this page has 0 → finding: `visual_data_missing`
   - **Nav count mismatch**: If nav item count differs from the mode → possible conditional nav rendering issue
   - **Content density outlier**: If this page is `low` density but siblings are `medium`/`high` → finding: `visual_data_missing`

3. Record structural comparison findings in the ledger with `type: "visual"` and relevant subcategory.

4. **Print anomalies** in the tick summary when found:
   ```
   [browse] Tick #22 — /projects
     ├─ ...
     ├─ Visual: Missing breadcrumbs (present on 18/20 other pages)
     └─ Visual: Table has 0 rows (siblings avg 12 rows)
   ```

---

### Phase 6-LOOP: Auto-Fix

For each Critical and Error finding on the current page (max 2 fixes per tick):

#### 6.1 Trace to Source
1. Read the error message and stack trace (if available)
2. Identify the source file and line number
3. Read the source file to understand context
4. Identify the root cause

**Tracing by finding type:**
- **Console errors with stack trace**: Follow the stack trace directly to the source file and line
- **Network 404**: Grep the codebase for the failing endpoint URL (e.g., search for `/api/users`). Check both the API definition and the calling component.
- **Network 401/403**: Likely auth config — check middleware, route guards, or API client headers. Often not auto-fixable.
- **Content quality (placeholder text)**: Grep for the exact text ("Lorem ipsum", "TODO") in source files under the page's component tree
- **Broken images**: Grep for the image filename or `src` attribute in templates
- **Dead links (`href="#"`)**: Grep for `href="#"` in the page's component and its children

#### 6.2 Apply Minimal Fix
- Fix ONLY the specific error — do not refactor surrounding code
- Use the same fix templates as Phase 5 (non-loop mode) — see reference.md
- Common fixes: optional chaining, missing imports, wrong API endpoints, missing error states

#### 6.3 Verify
1. Run verify command (typecheck + lint, auto-detected)
2. **If pass**: commit with message `browse-fix(<page_path>): <description>`
3. **Wait 3 seconds** after commit — the dev server needs time to process the file change and complete HMR. Navigating too early hits a partially-rebuilt state.
4. **If fail**: revert ALL changes, mark finding as `needs-human` in ledger. If revert also fails (file not writable), log error and exit tick immediately.

#### 6.4 Fix Limits & Circuit Breaker
- **Max 2 fixes per tick** — keeps within time budget
- **Max 1 fix per file per tick** — prevents cascading failures from multiple edits to the same file
- **Circuit breaker state** (tracked in `latest-tick.json`):
  - `consecutive_fix_failures`: incremented on each failed fix, reset to 0 on any successful fix
  - `circuit_breaker_cooldown`: when `consecutive_fix_failures >= 3`, set to `current_tick + 3`
  - During cooldown (`tick < circuit_breaker_cooldown`): skip Phase 6 entirely, only crawl
  - After cooldown expires: resume fixing, counter stays at 0
- **Cascading invalidation**: if a fix modifies a shared file (composable, utility, store), mark all visited pages that import that file as `status: "needs_re_verify"` in `crawl-visited.json`. These pages rejoin the RE-VERIFY queue.

#### 6.5 Fix Quality Gate
Same rules as Phase 5.5 (non-loop mode):
- **BANNED**: silent `return`, empty catch, `// TODO` comments, `@ts-ignore` without resolution

---

### Phase 7-LOOP: Save State & Report

#### 7.1 Save State (Atomic Writes)

State files have interdependencies — a crash mid-write can leave inconsistent state. Use this write order (JSONL appends first, then JSON overwrites):

1. **Append** to `crawl-ledger.jsonl` — new findings (append-only, crash-safe)
2. **Append** to `fix-log.jsonl` — fix attempts (append-only, crash-safe)
3. **Write** `latest-tick.json` — tick snapshot (write last so overlap guard works)
4. **Write** `crawl-queue.json` — updated queue
5. **Write** `crawl-visited.json` — updated visited map
6. **Write** `hierarchy.json` — updated hierarchy

For JSON files (steps 3-6): write to a `.tmp` file first, then rename to final path. This ensures each file is either fully old or fully new, never partially written.

`latest-tick.json` snapshot:
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
  "updated_at": "<ISO-8601>"
}
```

#### 7.2 Print Tick Summary
```
[browse] Tick #14 — /settings/profile
  ├─ Links: 8 found, 5 new (3 already visited/queued)
  ├─ Findings: 1 error (fixed ✓), 2 warnings
  ├─ Visual: 1 design inconsistency (missing breadcrumbs)
  ├─ Fixes: 1 applied, 0 failed
  ├─ Queue: 23 remaining, max depth 3
  └─ Progress: 14/37 pages (37.8%)
```

#### 7.3 Site Map (every 10th tick)
Every 10 ticks, print the navigational hierarchy as a tree:
```
[browse] Site Map (14 pages visited, 23 queued):
/ (Home) ✓
├─ /dashboard (Dashboard) ✓
│  ├─ /dashboard/analytics (Analytics) ✓
│  └─ /dashboard/reports (Reports) [queued]
├─ /settings (Settings) ✓
│  ├─ /settings/profile (Profile) ✓ ← current
│  └─ /settings/billing (Billing) [queued]
├─ /users (Users) [queued]
└─ /projects (Projects) [queued]
```

Legend: `✓` = visited clean, `⚠` = has issues, `✗` = has unfixed issues, `[queued]` = not yet visited

#### 7.4 Cross-Page Visual Audit (on COMPLETE tick only)

When the crawl transitions to `COMPLETE` status, run a final design consistency audit before the final report:

1. **Group pages by section** — pages sharing the same first path segment (e.g., all `/dashboard/*`, all `/settings/*`)
2. **For each group of 3+ pages**, take viewport screenshots of up to 5 pages and pass them to the model simultaneously:

   > "These [N] screenshots are from the [section] section of a [framework] application. Analyze them together for:
   > 1. Design consistency: Do they share the same layout, spacing, typography, and color usage?
   > 2. Missing elements: Are structural patterns (breadcrumbs, headers, sidebars, footers) present on some but missing on others?
   > 3. Data completeness: Do any pages appear emptier or more sparse than their siblings?
   > 4. Visual quality: Any overlapping elements, overflow, misalignment, or broken images?
   > Return findings as a list with page URL, issue type, and description."

3. **Compare structural metadata** across all groups to find global patterns:
   - Which UI elements are truly global (present on 90%+ pages)? Flag pages missing them.
   - Are heading hierarchies consistent? (e.g., all pages use h1 for title, h2 for sections)
   - Is card/table rendering consistent across similar page types?

4. Record all findings as `type: "visual"` in the ledger. These are not auto-fixable but valuable for the report.

5. **Write visual audit summary** to `docs/crawls/visual-audit.md`:
   ```markdown
   # Visual Audit — [date]

   ## Global Patterns
   - Breadcrumbs: present on 42/47 pages (missing on: /projects, /reports, ...)
   - Sidebar: present on 45/47 pages
   - Pagination: present on 8/12 list pages (missing on: /users, ...)

   ## Design Consistency Issues
   ### /dashboard section (5 pages)
   - /dashboard/reports: Missing chart data, empty container without empty-state
   - /dashboard/analytics: Heading uses h3 instead of h2 (inconsistent with siblings)

   ## Data Completeness Issues
   - /projects: Table has 0 rows (siblings average 12)
   - /settings/billing: Card is missing 2 fields present on /settings/profile card
   ```

#### 7.5 Final Report
When `status` is `COMPLETE`:
```
[browse] ✓ Site crawl complete!
  ├─ Pages visited: 47
  ├─ Total findings: 12 (8 fixed, 4 needs-human)
  ├─ Visual findings: 6 (3 design inconsistency, 2 missing data, 1 layout)
  ├─ Hierarchy depth: 4
  ├─ Duration: 47 ticks (~4 hours)
  ├─ Visual audit: docs/crawls/visual-audit.md
  └─ Full site map: docs/crawls/hierarchy.json
```
Print the full site map tree. The skill will no-op on subsequent ticks (check `latest-tick.json` status).

#### 7.6 Session Cleanup
- Log to activity feed: `skill_complete` or `phase_complete` (per tick)
- Update session JSON: status and last_activity
- On COMPLETE: full session cleanup per session-protocol.md

---

### Loop Mode Error Recovery

**Browser not available at tick start:**
1. Use ToolSearch to reload Playwright MCP tools
2. Navigate to BASE_URL to start fresh
3. If still failing, log error and exit tick (retry on next tick)

**Page navigation fails:**
1. Record as Warning: "Navigation failed on [page]"
2. Move page to end of queue with reduced priority (halve current priority)
3. Track failure count per page in `crawl-queue.json` entry: `"nav_failures": N`
4. If same page fails 3 times, mark as `unreachable` in visited and skip permanently
5. Continue to save state and exit

**Authentication lost (redirect to login or 401 responses):**
1. Record as Critical in ledger
2. Set `latest-tick.json` status to `"auth_lost"`
3. Print message: "Authentication lost. Please re-authenticate in the browser, then delete `docs/crawls/latest-tick.json` or set its status to `crawling` to resume."
4. Exit tick. Subsequent ticks will detect `auth_lost` status and exit immediately until user intervenes.

**Dev server unreachable:**
1. Wait 5 seconds and retry once
2. If still unreachable, set status to `"server_down"`, exit tick
3. Next tick will retry automatically (server_down is not a terminal state)

**State file corruption:**
1. Detect: JSON parse error when loading any state file
2. Rename corrupted file to `<filename>.bak`
3. For `crawl-queue.json` or `crawl-visited.json`: attempt reconstruction from `crawl-ledger.jsonl` (most reliable, append-only)
4. For `hierarchy.json`: rebuild from `crawl-visited.json` parent references
5. If reconstruction fails: log error, re-seed from scratch (delete all state, restart crawl)

**Fix revert failure:**
1. If a fix fails verification AND the revert also fails
2. Log both errors to `fix-log.jsonl`
3. Mark finding as `needs-human`
4. Exit tick immediately — do not attempt further fixes or state writes
5. Next tick will detect the dirty state via `git status` and warn

**Tick timeout exceeded:**
1. If elapsed time > 100 seconds at any phase boundary
2. Skip remaining phases, jump directly to Phase 7-LOOP (Save State)
3. Log warning: `[browse] Tick #N exceeded time budget at Phase X. Saving state and exiting.`
4. Any unfinished work (links not extracted, fixes not attempted) will be handled on next tick
