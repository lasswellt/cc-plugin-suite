# Migration — Reference Material

Codemod registry, risk assessment matrix, breaking change analysis templates, and rollback procedures used by the migrate skill.

---

## Codemod Registry

Common migrations with available automated transforms. Check availability before falling back to manual migration.

### Frontend Framework Upgrades

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Vue 2 → Vue 3 | `@vue/compat` | `npx @vue/compat` | Compatibility build; enables incremental migration. Covers ~90% of breaking changes. |
| Vue 2 → Vue 3 (transforms) | `vue-codemod` | `npx vue-codemod src/ --all` | AST-based transforms for template and script changes. |
| Vue 3.x → 3.y (minor) | N/A | Manual | Minor upgrades rarely have codemods; check changelog. |
| Nuxt 2 → Nuxt 3 | `nuxi` | `npx nuxi upgrade` | Handles config migration. Manual work needed for composables and `$fetch`. |
| Nuxt 3.x → 3.y | `nuxi` | `npx nuxi upgrade` | Usually handles minor upgrades cleanly. |
| React class → hooks | `react-codemod` | `npx react-codemod rename-unsafe-lifecycles` | Partial coverage; complex components need manual work. |
| Angular N → N+1 | `@angular/cli` | `npx ng update @angular/core@<version>` | Best-in-class migration tooling. Usually handles everything. |

### Test Runner Migrations

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Jest → Vitest | `jest-to-vitest` | `npx jest-to-vitest .` | Converts imports and config. Manual work for `jest.mock` → `vi.mock`. |
| Mocha → Vitest | N/A | Manual | No automated tool; rewrite describe/it imports and assertions. |
| Mocha → Jest | `jest-codemods` | `npx jest-codemods .` | Handles Mocha, Chai, Sinon → Jest conversions. |
| Jasmine → Jest | `jest-codemods` | `npx jest-codemods .` | Good coverage for Jasmine syntax. |

### Linting & Formatting

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| ESLint legacy → flat config | `@eslint/migrate-config` | `npx @eslint/migrate-config .eslintrc.json` | Converts config file format. Plugin compatibility must be verified manually. |
| ESLint 8 → 9 | `@eslint/migrate-config` | Same as above | Major change is flat config; codemod handles config, not rule changes. |
| TSLint → ESLint | `tslint-to-eslint-config` | `npx tslint-to-eslint-config` | Converts config and rules. Manual cleanup usually needed. |
| Prettier 2 → 3 | N/A | Manual | Minimal breaking changes; update config options manually. |

### Module System

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| CJS → ESM | `cjs-to-esm` | `npx cjs-to-esm .` | Converts `require()` to `import`. Does not handle dynamic requires. |
| CJS → ESM (TypeScript) | N/A | Manual | Add `"type": "module"` to `package.json`, update imports with extensions. |

### Build Tool Migrations

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Webpack → Vite | `wp2vite` | `npx wp2vite` | Generates Vite config from webpack config. Manual adjustment usually needed. |
| Create React App → Vite | N/A | Manual | Delete CRA config, create `vite.config.ts`, update scripts. |
| Vue CLI → Vite | N/A | Manual | Similar to CRA migration. Remove `vue.config.js`, create `vite.config.ts`. |

### State Management

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Vuex → Pinia | N/A | Manual | No automated tool. Rewrite stores one at a time. |
| Pinia 2 → Pinia 3 | N/A | Manual | Check changelog for breaking changes. Usually minimal. |
| Options API → Composition API | `vue-composition-api-codemod` | `npx vue-composition-api-codemod src/` | Partial coverage; complex components need manual work. |

---

## Risk Assessment Matrix

Cross-reference files affected with breaking change severity to determine overall migration risk.

### Files Affected × Breaking Change Severity

|  | No Breaking Changes | Minor Deprecations | API Renames/Removals | Architectural Changes |
|--|--------------------|--------------------|---------------------|-----------------------|
| **<10 files** | Low | Low | Medium | Medium |
| **10-30 files** | Low | Medium | Medium | High |
| **31-50 files** | Low | Medium | High | High |
| **51-100 files** | Medium | High | High | Critical |
| **>100 files** | Medium | High | Critical | Critical |

### Risk Level Definitions

| Risk Level | Description | Recommended Approach |
|-----------|-------------|---------------------|
| **Low** | Routine upgrade with minimal impact. | Proceed with standard verification gates. |
| **Medium** | Upgrade with some breaking changes, but codemods or clear migration paths exist. | Run codemods first, then manual fixes. Extra attention to verification. |
| **High** | Significant breaking changes across many files. Manual work required. | Break into multiple sub-migrations. Consider feature branch. Allow extra time. |
| **Critical** | Deep architectural changes or multiple simultaneous major upgrades. | Strongly consider incremental approach (upgrade to intermediate versions first). May need dedicated sprint. |

---

## Breaking Change Analysis Template

Use this template to document each breaking change before starting migration.

```markdown
### Breaking Change: <title>

- **Package**: <package-name>
- **Version**: Removed/changed in <version>
- **Type**: API Removal | API Rename | Behavioral Change | Config Change | Type Change
- **Severity**: High | Medium | Low

#### What Changed
<Description of the change>

#### Pattern to Grep
```bash
grep -rn "<pattern>" --include="*.ts" --include="*.vue" . | grep -v node_modules
```

#### Files Affected
<N> files (list key files)

#### Migration Path
- [ ] Codemod available: <yes/no — package name>
- [ ] Manual fix: <description of what to change>
- [ ] Before: `<old code>`
- [ ] After: `<new code>`

#### Risk
<High | Medium | Low> — <brief justification>
```

---

## Rollback Procedure

Step-by-step rollback for when automated rollback is not sufficient.

### Quick Rollback (Git-Based)

If migration commits were atomic and clean:
```bash
# Option 1: Reset to rollback branch
git log --oneline | head -20  # Review migration commits
git checkout <rollback-branch>
git branch -m main main-failed-migration  # Rename current main
git checkout -b main  # Create new main from rollback point

# Option 2: Revert migration commits
git revert --no-commit <oldest-migration-commit>..<latest-migration-commit>
git commit -m "revert: rollback <target> migration"
```

### Full Rollback (When Git State Is Complicated)

1. **Save current state** (in case partial migration is useful):
   ```bash
   git stash push -m "partial-migration-<target>-$(date +%Y%m%d)"
   ```

2. **Reset to rollback branch**:
   ```bash
   git checkout <rollback-branch>
   ```

3. **Reinstall dependencies**:
   ```bash
   rm -rf node_modules
   rm -f package-lock.json  # or pnpm-lock.yaml / yarn.lock
   npm install  # or pnpm install / yarn install
   ```

4. **Verify rollback**:
   ```bash
   npx tsc --noEmit 2>&1 | tail -10
   npm test 2>&1 | tail -20
   npm run build 2>&1 | tail -10
   ```

5. **Clean up branches**:
   ```bash
   # Only after confirming rollback is clean
   git branch -D <failed-migration-branch>  # if created
   ```

### Partial Rollback (Keep Some Migration Steps)

If some steps succeeded and you want to keep them:

1. Identify the last good commit:
   ```bash
   git log --oneline | grep "migrate(<target>)"
   ```

2. Reset to that commit:
   ```bash
   git reset --hard <last-good-commit>
   ```

3. Reinstall dependencies and verify.

---

## Common Migration Pitfalls

### Peer Dependency Hell
- **Symptom**: `npm install` fails with peer dependency conflicts.
- **Fix**: Upgrade peer dependencies first, or use `--legacy-peer-deps` as temporary workaround.
- **Prevention**: Check peer dependency requirements before upgrading the main package.

### Lock File Drift
- **Symptom**: Different behavior after migration on CI vs local.
- **Fix**: Delete lock file and regenerate. Commit the new lock file.

### Hidden Breaking Changes
- **Symptom**: Tests pass but runtime behavior is different.
- **Fix**: Check for behavioral changes (changed defaults, different error messages, altered timing).
- **Prevention**: Review changelog carefully, not just the "breaking changes" section.

### Transitive Dependency Breaks
- **Symptom**: Package you didn't upgrade starts failing.
- **Fix**: Check if the migrated package changed a shared transitive dependency. Pin the transitive dependency if needed.

### Config File Format Changes
- **Symptom**: Build tool can't parse config file after upgrade.
- **Fix**: Use the codemod if available. Otherwise, rewrite config from scratch using new documentation.

---

## Version Compatibility Quick Reference

### Vue Ecosystem

| Vue | Vue Router | Pinia | Vuetify | Quasar | Nuxt |
|-----|-----------|-------|---------|--------|------|
| 3.4+ | 4.x | 2.x | 3.x | 2.x (Vite) | 3.x |
| 3.0-3.3 | 4.x | 2.x | 3.x (early) | 2.x | 3.x (early) |
| 2.7 | 3.x | N/A (use Vuex) | 2.x | 1.x | 2.x |
| 2.6 | 3.x | N/A | 2.x | 1.x | 2.x |

### TypeScript Compatibility

| TypeScript | Node.js (min) | Vue | Vitest | ESLint |
|-----------|---------------|-----|--------|--------|
| 5.5+ | 18.18+ | 3.4+ | 2.x | 9.x |
| 5.0-5.4 | 16.20+ | 3.3+ | 1.x-2.x | 8.x-9.x |
| 4.9 | 14.17+ | 3.2+ | 0.x-1.x | 8.x |
| 4.7-4.8 | 14.17+ | 3.2+ | 0.x | 8.x |

### Node.js LTS Schedule

| Version | Status | End of Life |
|---------|--------|-------------|
| 22.x | Active LTS | April 2027 |
| 20.x | Maintenance LTS | April 2026 |
| 18.x | End of Life | April 2025 |
