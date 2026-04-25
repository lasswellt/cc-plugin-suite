# Code Doctor — Reference Material

> **Scope boundary:** This skill owns framework-API correctness (Firestore, VueFire, Vue 3, Pinia), dead exports, and duplication candidates. Generic dead-code and style checks belong in `blitz:code-sweep`. Do not add generic quality rules here.

Load on-demand. Read only the section(s) needed for the current phase.

---

## A. Rule Table

Rules are grouped by category. The `auto_fix` column marks low-risk transforms safe for `--fix` mode.

### Firestore Rules

| id | severity | auto_fix | pattern (grep) | file_glob | false_positive_note |
|----|----------|----------|----------------|-----------|---------------------|
| F1 | major | false | `for\s*\(.*\bawait\b.*getDocs\|for\s*await.*getDocs` | `**/*.{ts,vue}` | Skip if loop body constructs a batch query itself |
| F2 | critical | false | `onSnapshot\(` in file AND `onUnmounted` absent in same file | `**/*.vue` | Check the whole file — cleanup may be in a separate composable called from this file; judge in Phase 2 |
| F3 | major | false | `serverTimestamp\(\)` in same file as `.data\(\)` or `.get\(` on same document ref | `**/*.{ts,vue}` | Only flag if read happens on same tx/snapshot, not separate ops |
| F5 | major | true | `\.docs\.map\s*\(\s*\w+\s*=>\s*\w+\.data\(\)\s*\)` | `**/*.{ts,vue}` | No known false positives |
| F6 | major | false | `getDocs\s*\(\s*collection\s*\(` — check: no `query\(` wrapper AND no `.limit\(` chain in same expression | `**/*.{ts,vue}` | Allow if wrapped in `query(collection(...), limit(...))` |
| F7 | critical | false | Inside `runTransaction` body: `\btx\.(set\|update\|delete)\b` appears before `\btx\.get\b` | `**/*.{ts,vue}` | Rare; confirm with LLM judge |
| F8 | minor | false | `updateDoc\s*\(` not preceded by existence check or `setDoc.*merge.*true` in same function | `**/*.{ts,vue}` | High false-positive rate — demote to advisory |
| F9 | major | false | Same `doc\(db,\s*'<collection>'` path referenced in >2 component files with `onSnapshot` | `**/*.vue` | Cross-file; use grep + manual review |
| F10 | minor | false | `import.*firestore\.rules` | `**/*.{ts,vue}` | Rules file imported in src code |

### VueFire Rules

| id | severity | auto_fix | pattern (grep) | file_glob | false_positive_note |
|----|----------|----------|----------------|-----------|---------------------|
| V1 | critical | false | `\b(useDocument\|useCollection\|useObject)\s*\(` in file that is NOT a `.vue` `<script setup>` block and NOT inside `setup()` | `**/*.{ts,vue}` | Composables called from other composables are fine; judge in Phase 2 |
| V2 | major | false | `useDocument\|useCollection` result used as `\b\w+\b\s*\.(?!value)` (property access without `.value`) in `<script setup>` | `**/*.vue` | Template refs auto-unwrap; only flag script-side access |
| V3 | minor | true | File contains `useFirestore\(\)` called 2+ times | `**/*.{ts,vue}` | Count occurrences per file; fix: extract to top-of-file const |
| V4 | major | false | `useCollection\s*\(\s*collection\s*\(` without `query\(` wrapper | `**/*.{ts,vue}` | Flag if no query filter — unbounded reactive collection |
| V5 | major | false | `useDocument` called with dynamic id not inside `computed\(\)` | `**/*.{ts,vue}` | Static ids are fine; flag `useDocument(doc(db, col, someVar))` outside computed |

### Vue 3 Rules

| id | severity | auto_fix | pattern (grep) | file_glob | false_positive_note |
|----|----------|----------|----------------|-----------|---------------------|
| G1 | major | false | `v-if` and `v-for` on the same HTML element | `**/*.vue` | Check same opening tag |
| G2 | minor | false | `:key="index"` or `v-bind:key="index"` on `v-for` | `**/*.vue` | Skip if list is static/display-only (no reorder) |
| G3 | minor | false | `ref\s*\(\s*\{` — `ref()` wrapping an object that is later mutated with `.value.x =` | `**/*.{ts,vue}` | Prefer `reactive()` for mutable objects |
| G4 | minor | false | `this\.\$store\|this\.\$router` in `<script setup>` | `**/*.vue` | Options-API pattern in Composition API context |
| G5 | minor | false | Inline `style` binding with `px` string interpolation instead of computed property | `**/*.vue` | `:style="\`width: ${x}px\`"` pattern |

### Pinia Rules

| id | severity | auto_fix | pattern (grep) | file_glob | false_positive_note |
|----|----------|----------|----------------|-----------|---------------------|
| P1 | major | false | `store\.\w+\s*=\s*` outside a `defineStore` action body | `**/*.{ts,vue}` | High false-positive — confirm it's a direct state mutation not a local var assignment |
| P2 | minor | true | `watch\s*\(\s*\(\s*\)\s*=>\s*\w+Store\.\w+` without `storeToRefs` in same file | `**/*.{ts,vue}` | Fix: `const { x } = storeToRefs(store); watch(x, ...)` |
| P3 | minor | false | `useStore\(\)` called inside a non-setup function (not in `<script setup>`, not in composable returning reactive state) | `**/*.{ts,vue}` | Flag usage inside event handlers or lifecycle hooks defined outside setup |
| P4 | minor | false | Store state initialized with `ref()` at top level of `defineStore` — prefer plain value or `reactive()` | `**/*.ts` | Low impact; advisory only |

### Dead Export Rules

| id | severity | auto_fix | detection_method | file_glob | false_positive_note |
|----|----------|----------|------------------|-----------|---------------------|
| D1 | minor | false | `export (const\|function\|class\|type\|interface) \w+` with zero matching `import.*\w+` across repo | `**/*.{ts,vue}` | Exclude: index re-exports (`export * from`), files in `public/`, files with `@public` jsdoc tag |

### Duplication Rules

| id | severity | auto_fix | detection_method | file_glob | false_positive_note |
|----|----------|----------|------------------|-----------|---------------------|
| DUP1 | minor | false | Identical normalized 5-line blocks in 2+ source files | `**/*.{ts,vue}` | Normalize: trim whitespace, strip comments. Max 20 findings. |

---

## B. Severity Matrix

| severity | meaning | reported | blocks `--fix` | ratchet tracked |
|----------|---------|----------|-----------------|-----------------|
| critical | Data loss, memory leak, incorrect reads, security | always | yes | yes |
| major | Incorrect behavior, unbounded reads, perf risk | always | no | yes |
| minor | DRY, style, advisory | always | no | yes |

**Suppression:** `// code-doctor-ignore: <ruleId>` on the offending line silences that specific rule for that line. Log each suppression in the report appendix.

---

## C. JSON Output Schema (draft-07)

### Finding

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["ruleId","category","severity","file","line","message"],
  "properties": {
    "ruleId":     { "type": "string" },
    "category":   { "type": "string", "enum": ["firestore","vuefire","vue","pinia","dead","duplication"] },
    "severity":   { "type": "string", "enum": ["critical","major","minor"] },
    "file":       { "type": "string" },
    "line":       { "type": "integer", "minimum": 1 },
    "message":    { "type": "string" },
    "matchedText":{ "type": "string" },
    "fixRecipe":  { "type": "string" },
    "confirmed":  { "type": "boolean", "default": true },
    "suppressed": { "type": "boolean", "default": false }
  }
}
```

### Report

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["generatedAt","scope","rulesApplied","findings","ratchet"],
  "properties": {
    "generatedAt":  { "type": "string", "format": "date-time" },
    "scope":        { "type": "string" },
    "rulesApplied": { "type": "array", "items": { "type": "string" } },
    "mode":         { "type": "string", "enum": ["scan","fix","fix-all"] },
    "findings": {
      "type": "array",
      "items": { "$ref": "#/definitions/Finding" }
    },
    "dismissed": {
      "type": "array",
      "items": { "$ref": "#/definitions/Finding" },
      "description": "LLM-judge dismissed as false positive"
    },
    "ratchet": {
      "type": "object",
      "properties": {
        "critical": { "type": "integer" },
        "major":    { "type": "integer" },
        "minor":    { "type": "integer" },
        "delta":    {
          "type": "object",
          "properties": {
            "critical": { "type": "integer" },
            "major":    { "type": "integer" },
            "minor":    { "type": "integer" }
          }
        }
      }
    }
  }
}
```

---

## D. Audit Document Template

```markdown
# Code Doctor Audit — YYYY-MM-DD

**Scope:** <scope arg>
**Mode:** scan | fix | fix-all
**Rules applied:** <comma list>
**Generated:** <ISO timestamp>

## Summary

| Severity | Count | Fixed |
|----------|-------|-------|
| Critical | N     | 0     |
| Major    | N     | 0     |
| Minor    | N     | N     |

## Critical Findings

### <ruleId> — <rule short description>

**File:** `<file>:<line>`
**Rule:** <full rule description>

```<lang>
<matchedText>
```

**Fix:** <fixRecipe>

---

## Major Findings

[same structure]

## Minor Findings

[same structure]

## Dismissed (LLM Judge)

| ruleId | file:line | reason |
|--------|-----------|--------|

## Suppressed

| ruleId | file:line |
|--------|-----------|

## Ratchet

Previous: critical=N, major=N, minor=N
Current:  critical=N, major=N, minor=N
Delta:    Δcritical=N, Δmajor=N, Δminor=N
```

---

## E. Config Override (`.code-doctor.json`)

Place in project root. All fields optional.

```json
{
  "scope": "src/",
  "ignore": ["D1", "G5"],
  "maxFindings": 50,
  "noConfirm": false,
  "rules": ["firestore", "vuefire", "vue", "pinia"]
}
```

| field | default | description |
|-------|---------|-------------|
| `scope` | `src/` or `.` | Root directory for scans |
| `ignore` | `[]` | Rule ids to skip entirely |
| `maxFindings` | `100` | Cap total findings (avoids noise on large codebases) |
| `noConfirm` | `false` | Skip LLM judge phase |
| `rules` | all detected | Restrict to specific rule sets |

---

## F. Ratchet Ledger

File: `.cc-sessions/code-doctor-ledger.jsonl`

Each entry:
```json
{"ts":"<ISO-8601>","session":"<SESSION_ID>","scope":"<scope>","critical":0,"major":3,"minor":7}
```

Logic:
1. Read last entry matching current `scope` (scope-scoped ratchet).
2. Compare current counts against last entry.
3. If any count increased, print `⚠ RATCHET FAIL` with delta per rule id.
4. Append new entry unconditionally.

First run (no prior entry): skip ratchet comparison, just append.

---

## G. Auto-Fix Recipes

Applies only to rules with `auto_fix: true`. Phase 4 uses these recipes directly.

### F5 — `.docs.map(d => d.data())` loses `id`

**Pattern:** `\.docs\.map\s*\(\s*(\w+)\s*=>\s*\1\.data\(\)\s*\)`
**Replacement:** `.docs.map(($1) => ({ id: $1.id, ...$1.data() }))`

### V3 — Duplicate `useFirestore()` calls

**Detection:** Count `useFirestore()` occurrences in file. If > 1:
1. Remove all but the first occurrence.
2. If subsequent calls assigned to different vars, unify: replace downstream usages of the duplicate var with the first var name.

### P2 — `watch(() => store.x)` without `storeToRefs`

**Before:**
```ts
const store = useMyStore()
watch(() => store.someValue, (val) => { ... })
```
**After:**
```ts
const store = useMyStore()
const { someValue } = storeToRefs(store)
watch(someValue, (val) => { ... })
```
Note: only apply if `storeToRefs` is already imported or can be added to an existing `pinia` import.
