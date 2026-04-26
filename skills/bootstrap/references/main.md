# Bootstrap — Reference Material

Scaffold templates, file generation patterns, convention detection rules for bootstrap skill.

---

## Scaffold Templates by Type

### Feature Scaffold

| Layer | File Template | Naming Convention |
|-------|--------------|-------------------|
| Component | `src/components/<feature>/<Name>.vue` | PascalCase (match project) |
| Store | `src/stores/<name>.ts` | camelCase |
| Composable | `src/composables/use<Name>.ts` | camelCase with `use` prefix |
| Page | `pages/<name>.vue` (Nuxt) or router entry (Vite) | kebab-case |
| Test | Co-located `<Name>.test.ts` or `__tests__/<Name>.test.ts` | Match project convention |
| Types | `src/types/<name>.ts` | camelCase |

### Package Scaffold (Monorepo)

```
packages/<name>/
├── package.json
├── tsconfig.json
├── src/
│   └── index.ts
├── tests/
│   └── index.test.ts
└── vitest.config.ts (if Vitest)
```

### Project Scaffold (Greenfield)

#### Nuxt 3 + Tailwind
```
<project>/
├── app.vue
├── nuxt.config.ts
├── tailwind.config.ts
├── package.json
├── tsconfig.json
├── pages/
│   └── index.vue
├── components/
├── composables/
├── stores/
├── server/
│   └── api/
├── types/
└── tests/
```

#### Vue 3 + Vite + Tailwind
```
<project>/
├── src/
│   ├── App.vue
│   ├── main.ts
│   ├── router/
│   │   └── index.ts
│   ├── components/
│   ├── composables/
│   ├── stores/
│   ├── types/
│   └── assets/
├── vite.config.ts
├── tailwind.config.ts
├── package.json
├── tsconfig.json
└── tests/
```

---

## Convention Detection Patterns

| Convention | Detection Method | Fallback |
|-----------|-----------------|----------|
| File naming | Scan `components/` for case pattern | kebab-case |
| Component style | Check for `<script setup>` vs `<script>` | `<script setup lang="ts">` |
| Store syntax | Check for `defineStore` callback vs object | Setup syntax |
| Test location | Search for `*.test.*` file locations | Co-located |
| Test naming | Check `*.test.ts` vs `*.spec.ts` | `*.test.ts` |
| Import aliases | Check `tsconfig.json` paths | `@/` = `src/` |
| CSS approach | Check for Tailwind config, Quasar, Vuetify | Scoped CSS |
| Package manager | Check for lock files | pnpm |

---

## File Generation Patterns

### Vue Component Template
```vue
<script setup lang="ts">
interface Props {
  // props here
}

const props = withDefaults(defineProps<Props>(), {
  // defaults here
})

const emit = defineEmits<{
  // events here
}>()
</script>

<template>
  <div>
    <!-- content here -->
  </div>
</template>
```

### Pinia Store Template (Setup Syntax)
```typescript
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export const use<Name>Store = defineStore('<name>', () => {
  // State
  const items = ref<Item[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const itemCount = computed(() => items.value.length)

  // Actions
  async function fetchItems() {
    loading.value = true
    error.value = null
    try {
      // API call here
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch items'
    } finally {
      loading.value = false
    }
  }

  return { items, loading, error, itemCount, fetchItems }
})
```

### Test Template
```typescript
import { describe, it, expect, beforeEach } from 'vitest'

describe('<TargetName>', () => {
  beforeEach(() => {
    // Reset state
  })

  describe('happy path', () => {
    it('should handle typical input', () => {
      // Arrange
      // Act
      // Assert
    })
  })

  describe('error handling', () => {
    it('should handle invalid input', () => {
      // Arrange
      // Act
      // Assert
    })
  })
})
```

---

## Existing File Detection

Before creating any file, check if it already exists:

```bash
[ -f "<planned-path>" ] && echo "EXISTS — ask user" || echo "SAFE — create"
```

For barrel files (index.ts), check if directory already has one:
```bash
[ -f "<dir>/index.ts" ] && echo "APPEND export" || echo "CREATE barrel"
```
