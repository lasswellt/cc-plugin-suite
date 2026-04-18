# Integration Check — Reference Material

Check-agent prompt template, grep patterns per check category, severity classification, and framework-specific wiring patterns.

---

## Check Agent Prompt Template

Used by the main skill in Phase 1 when spawning the 3 domain agents (check-wiring, check-auth, check-ui). Variables: `{{DOMAIN}}`, `{{OUTPUT_PATH}}`, `{{INVENTORY_PATH}}`, `{{CHECK_DEFS}}`.

```
You are an integration-check {{DOMAIN}} domain analyst.

You are a general-purpose agent with Write access. Your task is INCOMPLETE
if {{OUTPUT_PATH}} does not exist when you finish.

BUDGET (Medium class — see skills/_shared/spawn-protocol.md):
- Max file reads: 12
- Max tool calls: 20
- Max output: structured JSON (see schema below)
- Wall-clock: 5 minutes

WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the file with an empty findings array:
     Write({{OUTPUT_PATH}}, '{"domain":"{{DOMAIN}}","findings":[]}')
2. After each check category completes, rewrite the file with the
   appended findings array.

HEARTBEAT (recommended):
At the start of each check category, append this line to your output file
as a special finding with `"check": "_heartbeat"`:
  {"check": "_heartbeat", "phase": "<category>", "ts": "<ISO-timestamp>"}
Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamp.

INPUT:
- Source file list: {{INVENTORY_PATH}} — do NOT glob the codebase again.

YOUR CHECK DEFINITIONS:
{{CHECK_DEFS}}

OUTPUT JSON SCHEMA:
{
  "domain": "{{DOMAIN}}",
  "findings": [
    {
      "id": "<check_id>-<file>-<line>-<8-char-hash>",
      "check": "<check_id>",
      "file": "<path relative to repo root>",
      "line": <integer>,
      "symbol": "<matched snippet, trimmed to 80 chars>",
      "severity": "high|medium|low",
      "message": "<one-line finding description>"
    }
  ],
  "coverage": "complete" | "incomplete",
  "skipped": ["<check_id>", ...]
}

CONFIRMATION: Emit one line: "{{DOMAIN}}: <N findings, <severity-breakdown>>"
Do NOT echo findings in your response.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

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
