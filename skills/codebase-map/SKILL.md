---
name: codebase-map
description: "Analyzes an existing codebase across 4 dimensions: Technology, Architecture, Quality, and Concerns. Produces a CODEBASE-MAP.md for brownfield project onboarding."
allowed-tools: Read, Bash, Glob, Grep
model: sonnet
compatibility: ">=2.1.50"
argument-hint: "(no arguments — analyzes the current project)"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

# Codebase Mapper

Produce a comprehensive, prescriptive analysis of an existing codebase. The output helps developers understand the project before planning sprints, refactoring, or onboarding new team members. Execute every phase in order. Do NOT skip phases.

**This skill is read-only. It does NOT modify any code.**

---

## Phase 0: CONTEXT — Register and Inventory

### 0.0 Register Session

Follow the session protocol from [session-protocol.md](/_shared/session-protocol.md) **and** the [verbose-progress.md](/_shared/verbose-progress.md) protocol.

### 0.1 Build File Inventory

```bash
# Count files by type
find . -not -path '*/node_modules/*' -not -path '*/.git/*' -name '*.ts' -o -name '*.tsx' -o -name '*.vue' -o -name '*.js' -o -name '*.jsx' -o -name '*.json' -o -name '*.css' -o -name '*.scss' | wc -l

# Directory structure (top 3 levels)
find . -maxdepth 3 -type d -not -path '*/node_modules/*' -not -path '*/.git/*' | sort
```

### 0.2 Read Package Configuration

Read `package.json`, workspace configs, and any framework config files.

---

## Phase 1: TECHNOLOGY — Stack Profile

Analyze and document:

1. **Framework & runtime**: Vue/Nuxt/React/Next, Node version, TypeScript config
2. **Package manager**: npm/pnpm/yarn, workspace structure
3. **UI framework**: Tailwind/Quasar/Vuetify/MUI, design tokens
4. **State management**: Pinia/Vuex/Redux, store patterns
5. **Backend**: API framework, database, ORM, serverless functions
6. **Testing**: Test runner, coverage setup, test patterns
7. **Build & deploy**: Bundler, CI/CD, hosting, environment config
8. **Key dependencies**: Major libraries with version notes

Output: Technology section of CODEBASE-MAP.md

---

## Phase 2: ARCHITECTURE — Structure Analysis

Analyze and document:

1. **Module boundaries**: Which directories are self-contained modules vs shared
2. **Entry points**: Main app entry, route definitions, API entry points
3. **Data flow**: How data moves from backend → store → component
4. **Shared utilities**: Composables, helpers, utilities — what exists and where
5. **Integration points**: Where modules connect to each other
6. **Configuration layers**: Environment, feature flags, runtime config

For each module, note:
- File count, approximate LOC
- Exports consumed by other modules
- External dependencies

Output: Architecture section of CODEBASE-MAP.md

---

## Phase 3: QUALITY — Health Assessment

Analyze and document:

1. **TypeScript strictness**: Read tsconfig, count `any` usage, check strict flags
   ```bash
   grep -r ":\s*any" --include="*.ts" --include="*.vue" -l . | grep -v node_modules | wc -l
   ```
2. **Test coverage**: Test file count vs source file count, coverage config
   ```bash
   find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | wc -l
   ```
3. **TODO/FIXME hotspots**: Count and locate
   ```bash
   grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.vue" --include="*.js" . | grep -v node_modules | head -30
   ```
4. **Large files** (potential complexity hotspots):
   ```bash
   find . -name "*.ts" -o -name "*.vue" | grep -v node_modules | xargs wc -l 2>/dev/null | sort -rn | head -20
   ```
5. **Empty/stub functions**: Potential incomplete implementations
   ```bash
   grep -rn "return {}\|return \[\]\|throw.*not implemented" --include="*.ts" --include="*.vue" . | grep -v node_modules | head -20
   ```

Output: Quality section of CODEBASE-MAP.md

---

## Phase 4: CONCERNS — Risk Areas

Analyze and document:

1. **Fragile areas**: Files with high churn (many recent commits), large files, deeply nested logic
   ```bash
   git log --oneline --name-only -100 | grep -E '\.(ts|vue|js)$' | sort | uniq -c | sort -rn | head -20
   ```
2. **Missing error handling**: Async operations without try/catch
3. **Security concerns**: Hardcoded secrets, missing auth checks, exposed endpoints
4. **Dependency risks**: Outdated major versions, deprecated packages, known vulnerabilities
   ```bash
   npm audit --json 2>/dev/null | head -50
   ```
5. **Documentation gaps**: Undocumented APIs, missing README sections
6. **Accessibility gaps**: Missing ARIA attributes, keyboard navigation issues (for UI projects)

Output: Concerns section of CODEBASE-MAP.md

---

## Phase 5: OUTPUT — Generate CODEBASE-MAP.md

Write a comprehensive `CODEBASE-MAP.md` at the project root with all 4 sections. Format:

```markdown
# Codebase Map — <project-name>

Generated: <ISO-8601>
Analyzed by: blitz codebase-map

## Technology
<from Phase 1>

## Architecture
<from Phase 2>

## Quality
<from Phase 3>

## Concerns
<from Phase 4>

## Recommendations
- <prioritized list of suggested improvements, each with file paths>
```

Print a summary to the user:

```
[codebase-map] Complete ✓
  Files analyzed: N
  Modules identified: N
  Quality score: N/100
  Concerns flagged: N
  Output: CODEBASE-MAP.md
```
