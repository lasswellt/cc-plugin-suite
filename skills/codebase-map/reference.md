# Codebase Map — Reference Material

Quality scoring rubric, dimension checklists, and example output formats for the codebase-map skill.

---

## Quality Scoring Rubric

Each dimension is scored on a 1-5 scale:

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Excellent | Industry best practices, well-documented, consistent |
| 4 | Good | Minor gaps, mostly consistent, functional |
| 3 | Adequate | Some issues, inconsistent in places, works but fragile |
| 2 | Poor | Significant issues, inconsistent, technical debt |
| 1 | Critical | Broken, missing critical patterns, blocking development |

### Overall Score
```
Overall = (Technology × 0.2) + (Architecture × 0.3) + (Quality × 0.3) + (Concerns × 0.2)
```

Architecture and Quality are weighted higher because they most directly impact development velocity.

---

## Dimension Checklists

### Technology Dimension
- [ ] Framework and version identified
- [ ] Package manager identified
- [ ] Build tool identified
- [ ] Test runner identified
- [ ] CSS framework/approach identified
- [ ] State management approach identified
- [ ] Backend/API approach identified
- [ ] TypeScript configuration assessed
- [ ] Dependency health (outdated count, vulnerability count)
- [ ] Monorepo structure (if applicable)

### Architecture Dimension
- [ ] Directory structure mapped (2-3 levels)
- [ ] Layer separation assessed (pages, components, stores, services, types)
- [ ] Routing approach documented
- [ ] State management patterns documented
- [ ] API integration patterns documented
- [ ] Shared code organization assessed
- [ ] Circular dependency check
- [ ] Module boundary clarity
- [ ] Entry points identified
- [ ] Build output structure

### Quality Dimension
- [ ] TypeScript strictness level
- [ ] Test coverage (estimated from test file count vs source file count)
- [ ] Linting configuration present and enforced
- [ ] Consistent naming conventions
- [ ] Error handling patterns
- [ ] Loading/empty/error state patterns (for UI projects)
- [ ] Code duplication assessment
- [ ] Documentation presence (JSDoc, README, inline comments)
- [ ] Git hygiene (commit message format, branch strategy)
- [ ] CI/CD pipeline present

### Concerns Dimension
- [ ] Authentication/authorization patterns
- [ ] Input validation approach
- [ ] Secrets management (no hardcoded secrets)
- [ ] CORS and security headers
- [ ] Performance patterns (lazy loading, caching, pagination)
- [ ] Accessibility compliance
- [ ] Internationalization readiness
- [ ] Logging and monitoring
- [ ] Error reporting (Sentry, etc.)
- [ ] Environment configuration management

---

## Example Output Format

```markdown
# Codebase Map: <project-name>

Generated: <date>
Overall Score: 3.6/5.0

## Technology Profile
| Attribute | Value |
|-----------|-------|
| Framework | Nuxt 3.8 |
| Language | TypeScript 5.3 (strict) |
| Package Manager | pnpm 8.x |
| Test Runner | Vitest 1.x |
| CSS | Tailwind CSS 3.x |
| State | Pinia |
| Backend | Nitro (server/) |

Score: 4/5 — Modern stack, well-configured.

## Architecture
<Mermaid diagram>

Score: 3/5 — Good layer separation but some circular dependencies in stores.

## Quality
Score: 3/5 — TypeScript strict mode on, but test coverage is ~40%.

## Concerns
Score: 4/5 — Auth middleware present, input validation via Zod.

## Recommendations
1. [High] Add tests for stores/ directory (0% coverage)
2. [Medium] Resolve circular dependency: stores/auth ↔ stores/user
3. [Low] Add JSDoc to exported composables
```

---

## Grep Patterns for Detection

| What | Pattern | Files |
|------|---------|-------|
| Framework | `"nuxt"`, `"vue"`, `"react"`, `"next"`, `"svelte"` in package.json | `package.json` |
| TypeScript strict | `"strict": true` | `tsconfig.json` |
| Test files | `*.test.*`, `*.spec.*` | `**/*` |
| Store files | `defineStore`, `createStore` | `*.ts` |
| Composables | `export function use` | `*.ts` |
| API routes | `defineEventHandler`, `export default` in server/ | `server/**/*.ts` |
| Auth patterns | `middleware/auth`, `requireAuth`, `verifyIdToken` | `*.ts` |
| Zod schemas | `z.object`, `z.string`, `z.number` | `*.ts` |
