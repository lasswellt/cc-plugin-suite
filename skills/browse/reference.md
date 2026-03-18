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
