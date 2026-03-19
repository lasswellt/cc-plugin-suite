---
name: integration-check
description: "Validates cross-module wiring: export-to-import tracing, route coverage, auth guard coverage, store-to-component wiring. Read-only analysis."
allowed-tools: Read, Bash, Glob, Grep
model: sonnet
argument-hint: "[scope: all | routes | exports | auth | stores]"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

# Integration Checker

Validate that modules are properly wired together after multi-module development work. Checks that exports have consumers, routes have navigation entries, auth guards are in place, and stores are connected to components.

**This skill is read-only. It does NOT modify any code.**

All findings follow the [Definition of Done](/_shared/definition-of-done.md) standards.

---

## Phase 0: CONTEXT

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol.

### 0.1 Parse Scope

| Argument | Checks Run |
|---|---|
| `all` (default) | All 5 check categories |
| `routes` | Route coverage only |
| `exports` | Export-to-import tracing only |
| `auth` | Auth guard coverage only |
| `stores` | Store-to-component wiring only |

### 0.2 Build File Inventory

```bash
find . -name '*.ts' -o -name '*.vue' -o -name '*.js' | grep -v node_modules | grep -v .git | sort
```

---

## Phase 1: EXPORT-TO-IMPORT TRACING

For each source file that exports functions, types, or components:

1. **Find all exports:**
   ```bash
   grep -rn "^export " --include="*.ts" --include="*.vue" . | grep -v node_modules | grep -v test | grep -v spec
   ```

2. **For each export, find importers:**
   ```bash
   grep -rn "from.*<module-path>" --include="*.ts" --include="*.vue" . | grep -v node_modules
   ```

3. **Flag orphaned exports** — exports with zero importers (excluding index/barrel files and entry points).

**Output:** List of orphaned exports with file paths.

---

## Phase 2: ROUTE COVERAGE

1. **Find all route definitions** (Vue Router, Nuxt pages, or file-based routing):
   ```bash
   # Vue Router
   grep -rn "path:" --include="*.ts" --include="*.js" . | grep -i "route" | grep -v node_modules
   # Nuxt file-based
   ls pages/**/*.vue 2>/dev/null
   ```

2. **Find navigation entries** — links, router-link, navigateTo calls:
   ```bash
   grep -rn "router-link\|navigateTo\|router.push\|<NuxtLink" --include="*.vue" --include="*.ts" . | grep -v node_modules
   ```

3. **Flag unreachable routes** — routes with no navigation entry pointing to them.

**Output:** List of unreachable routes.

---

## Phase 3: AUTH GUARD COVERAGE

1. **Identify protected routes** — routes that should require authentication:
   ```bash
   # Routes with meta.auth or middleware
   grep -rn "auth\|middleware\|requiresAuth\|meta:" --include="*.ts" --include="*.js" . | grep -i "route" | grep -v node_modules
   ```

2. **Identify sensitive API endpoints** — server functions handling user data:
   ```bash
   grep -rn "defineEventHandler\|onCall\|onRequest" --include="*.ts" . | grep -v node_modules
   ```

3. **Check each sensitive endpoint has auth verification:**
   ```bash
   # For each endpoint file, check for auth check patterns
   grep -l "verifyIdToken\|requireAuth\|auth\.currentUser\|getAuth" --include="*.ts" . | grep -v node_modules
   ```

4. **Flag unprotected endpoints** — sensitive operations without auth checks.

**Output:** List of unprotected routes and endpoints.

---

## Phase 4: STORE-TO-COMPONENT WIRING

1. **Find all stores/composables:**
   ```bash
   grep -rn "defineStore\|export function use" --include="*.ts" . | grep -v node_modules | grep -v test
   ```

2. **For each store, find consuming components:**
   ```bash
   grep -rn "use<StoreName>\|import.*from.*stores" --include="*.vue" --include="*.ts" . | grep -v node_modules
   ```

3. **Flag orphaned stores** — stores with no consuming components.

4. **Check API wiring** — store actions that should call API/service functions:
   ```bash
   # Find store actions that only set local state without API calls
   ```

**Output:** List of orphaned stores and unwired actions.

---

## Phase 5: API-TO-STORE WIRING

1. **Find all API/service functions:**
   ```bash
   grep -rn "export.*async function\|export const.*= async" --include="*.ts" . | grep -E "api|service|server" | grep -v node_modules
   ```

2. **For each API function, check if a store action calls it.**

3. **Flag orphaned API functions** — API functions with no store consumers.

**Output:** List of orphaned API functions.

---

## Phase 5.5: FORM-TO-HANDLER WIRING

Verify that forms are connected to their submission handlers and that handlers reach API endpoints.

1. **Find all forms:**
   ```bash
   grep -rn "<form\|<q-form\|<v-form\|@submit\|handleSubmit\|onSubmit" --include="*.vue" . | grep -v node_modules
   ```

2. **For each form, trace the submit handler:**
   - Find the `@submit` or `@submit.prevent` binding
   - Trace the handler function to verify it calls a store action or API function
   - Verify the API function exists and is implemented (not a stub)

3. **Flag disconnected forms:**
   - Forms with no `@submit` handler → **High** severity
   - Forms with a handler that doesn't call any API/store action → **Medium** severity
   - Forms whose handler calls a stub or placeholder function → **High** severity

**Output:** List of disconnected or partially-wired forms.

---

## Phase 5.7: STATE-TO-RENDER WIRING

Verify that reactive state declarations are actually rendered in templates.

1. **Find reactive state declarations:**
   ```bash
   grep -rn "ref<\|reactive<\|computed<\|defineStore" --include="*.ts" --include="*.vue" . | grep -v node_modules | grep -v test
   ```

2. **For each state variable in a component or composable:**
   - Check if it appears in a `<template>` section (directly or via a computed property)
   - Check if it is returned from a composable's return statement
   - Check if it is used in a `watch` or `watchEffect`

3. **Flag orphaned state:**
   - State declared but never rendered, watched, or returned → **Medium** severity
   - Store state with no consuming component (already covered in Phase 4, cross-reference here)

**Output:** List of orphaned reactive state variables.

---

## Phase 6: REPORT

Print a structured findings report:

```
Integration Check Report
========================
Scope: all
Files analyzed: N

Export-to-Import Tracing:
  ✓ N exports have consumers
  ⚠ M orphaned exports (no importers):
    - src/utils/legacy-helper.ts → formatDate()
    - src/schemas/deprecated-schema.ts → OldSchema

Route Coverage:
  ✓ N routes reachable via navigation
  ⚠ M unreachable routes:
    - /admin/debug (no nav entry)

Auth Guard Coverage:
  ✓ N endpoints protected
  ⚠ M unprotected sensitive endpoints:
    - src/server/api/users/delete.ts (no auth check)

Store Wiring:
  ✓ N stores have consumers
  ⚠ M orphaned stores:
    - useDeprecatedStore (no component imports it)

API Wiring:
  ✓ N API functions called by stores
  ⚠ M orphaned API functions:
    - fetchLegacyData (no store calls it)

Overall: N findings (H high, M medium, L low)
```

Classify severity:
- **High:** Unprotected auth endpoints, orphaned API functions that suggest missing features
- **Medium:** Unreachable routes, orphaned stores
- **Low:** Orphaned exports (may be intentionally public API)
