# Integration Check — Reference Material

Grep patterns per check category, severity classification, and framework-specific wiring patterns.

---

## Grep Patterns by Check Category

### Export-to-Import Tracing

| What | Grep Pattern | File Glob |
|------|-------------|-----------|
| Named exports | `^export (const\|function\|class\|type\|interface\|enum)` | `*.ts, *.tsx` |
| Default exports | `^export default` | `*.ts, *.tsx, *.vue` |
| Re-exports | `^export \{.*\} from\|^export \* from` | `*.ts` |
| Import consumers | `from ['"].*<module-path>['"]` | `*.ts, *.vue` |
| Dynamic imports | `import\(['"].*<module-path>['"]\)` | `*.ts, *.vue` |

### Route Coverage

| Framework | Route Definition Pattern | Navigation Pattern |
|-----------|------------------------|-------------------|
| Vue Router | `path: ['"]/<route>['"]` in router config | `<router-link to=`, `router.push(`, `router.replace(` |
| Nuxt | File existence in `pages/` directory | `<NuxtLink to=`, `navigateTo(`, `useRouter().push(` |
| File-based | `pages/**/*.vue` file listing | Any of the above |

### Auth Guard Coverage

| Framework | Auth Guard Pattern | Auth Check Pattern |
|-----------|-------------------|-------------------|
| Nuxt | `definePageMeta({ middleware: ['auth'] })` | `middleware/auth.ts` exists |
| Vue Router | `meta: { requiresAuth: true }` in route | `router.beforeEach` checks auth |
| Server | `defineEventHandler` in `server/api/` | Body contains `verifyIdToken\|requireAuth\|getAuth` |
| Firebase | `onCall\|onRequest` in `functions/` | Body contains `context.auth\|verifyIdToken` |

### Store-to-Component Wiring

| What | Pattern | Files |
|------|---------|-------|
| Store definition | `defineStore\(['"]<store-name>['"]` | `stores/*.ts` |
| Store consumer | `use<StoreName>Store\(\)` | `*.vue, *.ts` |
| Composable definition | `export function use<Name>` | `composables/*.ts` |
| Composable consumer | `use<Name>\(\)` | `*.vue, *.ts` |

### Form-to-Handler Wiring

| What | Pattern | Files |
|------|---------|-------|
| Form elements | `<form\|<q-form\|<v-form` | `*.vue` |
| Submit bindings | `@submit\|@submit\.prevent\|v-on:submit` | `*.vue` |
| Submit handlers | `(handleSubmit\|onSubmit\|submitForm)` | `*.vue, *.ts` |
| API calls in handlers | `\$fetch\|fetch\|axios\|useFetch\|api\.` | `*.ts, *.vue` |

### State-to-Render Wiring

| What | Pattern | Files |
|------|---------|-------|
| Ref declarations | `ref<\|ref(\|shallowRef<` | `*.ts, *.vue` |
| Reactive declarations | `reactive<\|reactive(` | `*.ts, *.vue` |
| Computed declarations | `computed<\|computed(` | `*.ts, *.vue` |
| Template usage | Variable name in `<template>` section | `*.vue` |
| Watch usage | `watch(\|watchEffect(` referencing variable | `*.ts, *.vue` |

---

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|---------|
| **High** | Missing auth on sensitive endpoints, orphaned API functions suggesting missing features, forms with no submit handler | Unprotected `DELETE /api/users/:id`, form without `@submit` |
| **Medium** | Unreachable routes, orphaned stores, orphaned state variables, forms calling stub handlers | `/admin/debug` with no nav link, `useOldStore` unused |
| **Low** | Orphaned exports (may be public API), state only used in watchers | Exported utility function with no current consumer |

---

## Framework-Specific Wiring Patterns

### Nuxt 3
- Routes are auto-generated from `pages/` — check file existence, not router config
- Middleware is file-based in `middleware/` — check `definePageMeta` in pages
- Server routes are in `server/api/` — auto-registered, check handler files
- Auto-imports: composables in `composables/` don't need explicit imports

### Vue 3 + Vue Router
- Routes defined in `src/router/index.ts` or similar config file
- Auth guards via `router.beforeEach` or per-route `meta` fields
- Components must be explicitly imported (no auto-import unless configured)

### Pinia Stores
- Defined with `defineStore` — look for store ID string
- Consumed via `use<Name>Store()` — match the store ID
- Actions should call service/API functions, not inline fetch calls

### Firebase/GCP Functions
- Cloud Functions defined with `onCall`, `onRequest`, `onDocumentCreated`, etc.
- Auth via `context.auth` (callable) or `verifyIdToken` (HTTP)
- Firestore rules are separate — check `firestore.rules` file
