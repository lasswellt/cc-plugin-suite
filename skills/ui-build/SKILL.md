---
name: ui-build
description: Researches codebase design patterns then generates production-grade Vue 3 UI that feels native to the project. Runs a 5-phase workflow (Discover, Analyze, Design, Implement, Refine). Use when user says "build a page", "create UI", "add a form", "design component", "build UI for".
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, ToolSearch
model: opus
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

You build production-grade Vue 3 UI that feels native to any project. Follow the 5-phase workflow below strictly in order. Never skip phases. Each phase produces an artifact that feeds the next.

## Additional Resources
- For UX design principles, wireframe templates, and accessibility checklist, see [reference.md](reference.md)

---

## Phase 0: SESSION — Register and Check for Conflicts

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol. Generate a SESSION_ID, create session directory, set `SESSION_TMP_DIR=".cc-sessions/${SESSION_ID}/tmp/"`, check for conflicting sessions, read the activity feed for recent cross-instance activity, and log `skill_start` to the activity feed. Print verbose progress at every phase transition, decision point, and substep per verbose-progress.md.

---

## Phase 1: DISCOVER

**Goal**: Build a mental model of how this project constructs UI.

### 1.1 Design Tokens
- Find the theme/token source (CSS variables, Tailwind config, Quasar variables, Vuetify theme)
- Document: color palette names, spacing scale, typography scale, border-radius tokens, shadow tokens, z-index layers
- Use Glob to search: `**/*.css`, `**/tailwind.config.*`, `**/quasar.config.*`, `**/vuetify.*`, `**/variables.scss`, `**/variables.sass`

### 1.2 Component Inventory
- Identify shared/base components the project already provides
- Search: `**/components/base/**`, `**/components/shared/**`, `**/components/common/**`, `**/components/ui/**`
- For each, note: name, props interface, slots, emitted events

### 1.3 Page Anatomy
- Read 2-3 representative pages that are similar to what you will build
- Document: layout wrapper used, section structure, spacing patterns, how data flows in

### 1.4 Data Patterns
- Find stores (Pinia), composables, API clients relevant to the feature
- Document: data shapes (TypeScript interfaces), loading patterns, error handling conventions

### 1.5 Output
Write a discovery summary to your working memory. Include:
- Token map (color names, spacing scale)
- Reusable components list with signatures
- Layout wrapper(s) to use
- Data layer conventions (composable vs store, loading/error patterns)
- Naming conventions (file naming, component naming, CSS class naming)

---

## Phase 2: ANALYZE

**Goal**: Synthesize discovery into a machine-readable design profile.

### 2.1 Design Profile
Produce a mental design profile containing:

```
Framework: [Vue 3 + Vite | Nuxt 3 | ...]
UI Framework: [Tailwind CSS | Quasar | Vuetify | None]
Component Pattern: [SFC Composition API | SFC Options API | ...]
State Management: [Pinia | Vuex | Composables | ...]
CSS Strategy: [Utility-first | Scoped CSS | CSS Modules | ...]
Color Token Format: [CSS vars | Tailwind classes | Framework theme | ...]
Layout Wrapper: [component name or "none"]
Loading Pattern: [skeleton | spinner | overlay | ...]
Error Pattern: [inline | toast | error boundary | ...]
Empty State Pattern: [illustration + text | simple text | ...]
Naming - Files: [kebab-case | PascalCase | ...]
Naming - Components: [PascalCase with prefix | ...]
Naming - CSS: [BEM | utility | scoped | ...]
```

### 2.2 Validation
Cross-check the profile against actual code. If any field is uncertain, re-read source files to confirm.

---

## Phase 3: DESIGN

**Goal**: Clarify requirements and produce component specs before writing code.

### 3.1 Requirements Clarification
If the user's request is ambiguous on any of these, use the `AskUserQuestion` tool:
- What data does this page/component display?
- What actions can the user take?
- Are there role-based visibility rules?
- What should empty state / zero-data state look like?
- What is the navigation entry point?

### 3.2 Wireframe
Produce an ASCII wireframe showing:
- Layout grid (columns, rows)
- Component placement with names
- Responsive breakpoint behavior (sm/md/lg)

Use the wireframe template format from reference.md.

### 3.3 Component Specs
For each new component, produce a spec:
- **Name**: PascalCase, following project conventions
- **Props**: TypeScript interface with defaults
- **Emits**: Event names and payload types
- **Slots**: Named slots with expected content
- **States**: Loading, Empty, Error, Populated
- **Composition**: Child components used
- **Estimated lines**: Must be under 300

### 3.4 Data Flow
Document:
- Which store/composable owns the data
- Fetch trigger (route guard, onMounted, watch)
- Mutation flow (optimistic vs pessimistic)
- Cache/invalidation strategy

---

## Phase 4: IMPLEMENT

**Goal**: Build bottom-up, smallest pieces first.

### Build Order (strict)
1. **TypeScript types** — interfaces, enums, type guards
2. **Composable / Store** — data fetching, state, actions
3. **Atom components** — smallest UI pieces (badges, chips, status indicators)
4. **Composite components** — cards, list items, form sections
5. **Page component** — orchestrates composites, handles layout
6. **Router entry** — add route definition
7. **Navigation entry** — add menu/nav item

### Implementation Gate

Before proceeding from implementation to Phase 5 (REFINE), verify:

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Type-check | 0 new errors | Fix before proceeding |
| Lint | 0 errors (warnings OK) | Fix before proceeding |
| Component size | No file > 300 lines | Extract sub-components |
| Three-state coverage | All data views have loading, error, and empty states | Add missing states |
| Hardcoded colors | None — design tokens only | Replace with tokens |

Run these checks after completing all implementation steps:
```bash
npm run type-check 2>&1 | tail -20
npx eslint <new-files> 2>&1 | tail -20
wc -l <new-vue-files> | sort -n | tail -5
```

If any check fails, fix before entering Phase 5. Maximum 3 fix iterations.

### Implementation Rules

#### Every data-displaying component MUST handle three states:
```vue
<template>
  <!-- LOADING STATE -->
  <LoadingSkeleton v-if="loading" />

  <!-- EMPTY STATE -->
  <EmptyState v-else-if="!items?.length" />

  <!-- ERROR STATE -->
  <ErrorDisplay v-else-if="error" :error="error" />

  <!-- POPULATED STATE -->
  <div v-else>
    <!-- actual content -->
  </div>
</template>
```

#### Code Quality Gates
- No component over 300 lines — extract sub-components
- No `any` types — use proper interfaces
- No hardcoded colors — use design tokens only
- No new layout wrappers if project has existing ones
- No `!important` overrides
- All user-facing strings must be extractable (no buried literals in template logic)
- Props must have TypeScript types and sensible defaults
- Emits must be typed

#### File Creation Pattern
```
# For each component:
1. Create the .vue file
2. Add TypeScript types if new (or extend existing)
3. Export from index if project uses barrel exports
4. Add to router if it's a page
```

---

## Phase 5: REFINE

**Goal**: Polish, verify, harden.

### 5.1 Quality Checklist
Run through every created file:
- [ ] Three states present (loading, empty, error) on every data view
- [ ] No hardcoded colors or magic numbers
- [ ] No component exceeds 300 lines
- [ ] Props are typed with defaults
- [ ] Emits are typed
- [ ] Naming follows project conventions
- [ ] Responsive behavior is defined (not just desktop)

### 5.1.5 Completeness Gate

Run the completeness gate on all created/modified UI files:
```bash
CHANGED_FILES=$(git diff --name-only HEAD~1 -- '*.vue' '*.ts')
```
Invoke: `/blitz:completeness-gate` scoped to the changed files.
Verify that three-state coverage (check 2.10) passes for all new data views. Any critical or high findings must be resolved before proceeding.

### 5.2 Accessibility Audit
For every interactive element:
- [ ] Buttons have accessible names
- [ ] Form inputs have labels
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for text)
- [ ] Focus order is logical
- [ ] ARIA attributes where needed (roles, labels, live regions)
- [ ] Keyboard navigation works (no mouse-only interactions)

### 5.3 Performance Check
- [ ] No N+1 data fetching (batch requests)
- [ ] Large lists use virtual scrolling or pagination
- [ ] Images have dimensions set (no layout shift)
- [ ] Heavy components use `defineAsyncComponent` if below the fold

### 5.4 Visual Validation (Optional — if Playwright MCP available)
Use ToolSearch to check for Playwright MCP tools. If available:
1. Navigate to the new page/component
2. Take screenshots at 3 viewports: 375px (mobile), 768px (tablet), 1440px (desktop)
3. Verify: no overflow, no overlapping elements, correct spacing, readable text

---

## UI Framework Variants

### When UI Framework is Tailwind CSS:
- Use utility classes exclusively — never write custom CSS unless unavoidable
- Skeletons: `animate-pulse bg-slate-200 rounded` (adapt shade to project palette)
- Colors: use Tailwind color tokens from `tailwind.config.*` — never raw hex
- Spacing: use Tailwind spacing scale (`p-4`, `gap-6`, etc.)
- Responsive: use Tailwind breakpoint prefixes (`sm:`, `md:`, `lg:`)
- Dark mode: use `dark:` variant if project supports it
- Layout: use Tailwind `flex`, `grid` utilities
- Typography: use Tailwind text utilities (`text-sm`, `font-medium`, etc.)

### When UI Framework is Quasar:
- Use `<q-*>` components exclusively — never use raw HTML equivalents
- Skeletons: `<q-skeleton type="rect" />`, `<q-skeleton type="text" />`, `<q-skeleton type="circle" />`
- Colors: use Quasar color system (`color="primary"`, `text-color="grey-8"`)
- Spacing: use Quasar CSS helpers (`q-pa-md`, `q-mt-sm`, `q-gutter-md`)
- Layout: use `<q-page>`, `<q-card>`, `<q-list>`, `<q-item>` hierarchy
- Tables: use `<q-table>` with column definitions, not raw `<table>`
- Forms: use `<q-form>`, `<q-input>`, `<q-select>` with validation rules
- Dialogs: use `<q-dialog>` or `$q.dialog()` plugin
- Notifications: use `$q.notify()` — never build custom toast components
- Icons: use the project's configured icon set (Material Icons, etc.)

### When UI Framework is Vuetify:
- Use `<v-*>` components exclusively — never use raw HTML equivalents
- Skeletons: `<VSkeletonLoader type="card" />`, `<VSkeletonLoader type="table-row" />`
- Colors: use Vuetify theme colors (`color="primary"`, `class="text-error"`)
- Spacing: use Vuetify spacing helpers (`pa-4`, `mt-2`, `ga-4`)
- Layout: use `<VContainer>`, `<VRow>`, `<VCol>` grid system
- Tables: use `<VDataTable>` with headers array
- Forms: use `<VForm>`, `<VTextField>`, `<VSelect>` with rules
- Dialogs: use `<VDialog>` with `v-model`
- Snackbars: use `<VSnackbar>` — never build custom toast components

---

## Critical Anti-Patterns (NEVER DO THESE)

1. **Never hardcode hex/rgb colors** — Always use design tokens (CSS vars, Tailwind classes, framework theme colors). Hardcoded colors break theming and dark mode.

2. **Never ship fewer than three states on data views** — Every component displaying fetched data MUST have: loading skeleton, empty state, error state, and populated state. No exceptions.

3. **Never use `any` type** — Define proper TypeScript interfaces. If the shape is unknown, use `unknown` with type guards. `Record<string, unknown>` is acceptable for truly dynamic objects.

4. **Never invent new layout wrappers** — If the project has `<AppLayout>`, `<PageContainer>`, `<q-page>`, or similar, use them. Creating parallel layout systems causes visual inconsistency.

5. **Never ship a component over 300 lines** — Extract sub-components. A 500-line component is two 250-line components that are easier to test and reuse.

6. **Never fight the UI framework** — No `!important` overrides, no CSS that counteracts framework defaults. If you need to override, you are using the framework wrong. Find the correct prop, slot, or theme configuration.

7. **Never skip the discovery phase** — Building UI without understanding the project's existing patterns guarantees inconsistency. The 15 minutes spent in discovery saves hours of rework.

8. **Never assume desktop-only** — Every layout decision must account for mobile. Use the framework's responsive system from the start, not as an afterthought.

---

## Production Readiness (NON-NEGOTIABLE)

Every component and function must be fully implemented. See [Definition of Done](/_shared/definition-of-done.md).

**BANNED PATTERNS** — if any of these appear in your code, the work is not done:

- `return {}` / `return []` / `return null` as placeholder returns
- `throw new Error('Not implemented')` / `throw new Error('TODO')`
- Empty event handlers (`() => {}`, `@click=""`)
- Store actions that return hardcoded data instead of calling real APIs
- `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code should be
- Components that render static text where dynamic data should be

**SELF-CHECK:** For every component, ask: *"If this page went live right now, would every button, form, and data display actually work?"*
