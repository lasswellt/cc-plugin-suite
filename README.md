# cc-plugin-suite

Production-grade development skills for Vue.js, Nuxt, and GCP Firebase projects. A Claude Code plugin that provides research, refactoring, sprint planning, code review, UI building, and browser testing workflows.

## Supported Stacks

- **Frameworks**: Vue 3 (Vite), Nuxt 3
- **UI Frameworks**: Tailwind CSS, Quasar, Vuetify (auto-detected)
- **Backend**: Firebase/GCP, Cloud Functions v2
- **State**: Pinia, VueFire, XState
- **Testing**: Vitest, Jest
- **Build Systems**: pnpm workspaces, Nx, Turborepo

Skills auto-detect the project's tech stack at invocation time via `scripts/detect-stack.sh` — no manual configuration needed.

## Prerequisites

- **bash** — required by all hooks and stack detection
- **Node.js / npx** — required by format and lint hooks (Prettier, ESLint, Biome)
- **python3** — required by edit hooks for JSON parsing
- **grep** — required by stack detection (universally available)

## Installation

### From the marketplace

```bash
/plugin marketplace add lasswellt/cc-plugin-suite
/plugin install cc-plugin-suite@cc-plugin-suite
```

### Local testing

```bash
claude --plugin-dir ./cc-plugin-suite
```

## Skills (11)

| Skill | Description | Invocation |
|-------|-------------|------------|
| **research** | Investigates libraries, APIs, and architecture patterns. Spawns parallel research agents. | `/cc-plugin-suite:research <topic>` |
| **refactor** | Safe, incremental refactoring with test verification after each step. | `/cc-plugin-suite:refactor <file> <goal>` |
| **fix-issue** | Resolves GitHub issues end-to-end: fetch, research, implement, verify, update. | `/cc-plugin-suite:fix-issue <issue-number>` |
| **test-gen** | Generates tests matching project conventions (Vitest/Jest auto-detect). | `/cc-plugin-suite:test-gen <file-path>` |
| **ui-build** | 5-phase UI workflow: Discover, Analyze, Design, Implement, Refine. | `/cc-plugin-suite:ui-build` |
| **browse** | Automated browser testing via Playwright MCP. Captures console/network errors. | `/cc-plugin-suite:browse [full\|smoke\|page <path>\|fix]` |
| **sprint-plan** | Plans sprints from roadmap epics with research-backed stories. | `/cc-plugin-suite:sprint-plan` |
| **sprint-dev** | Implements sprints with coordinated agent teams in isolated worktrees. | `/cc-plugin-suite:sprint-dev` |
| **sprint-review** | Reviews sprint quality with automated checks and parallel reviewer agents. | `/cc-plugin-suite:sprint-review` |
| **codebase-audit** | 5-pillar quality audit (Architecture, Performance, Security, Maintainability, Robustness). | `/cc-plugin-suite:codebase-audit` |
| **roadmap** | Generates phased implementation roadmaps from research documents. | `/cc-plugin-suite:roadmap [full\|refresh\|extend\|status]` |

## Commands (4)

| Command | Description |
|---------|-------------|
| `/cc-plugin-suite:ask <request>` | Task intake — classifies vague requests and dispatches to the right skill(s) |
| `/cc-plugin-suite:sprint [flags]` | Full sprint cycle: plan → implement → review |
| `/cc-plugin-suite:implement [flags]` | Sprint implementation phase only |
| `/cc-plugin-suite:review [flags]` | Sprint review and quality gate only |

## Agents (5)

| Agent | Role | Model |
|-------|------|-------|
| **architect** | Read-only architecture analysis (coupling, cohesion, dependency graphs) | sonnet |
| **backend-dev** | Cloud Functions / Zod / Firestore backend implementation | sonnet |
| **frontend-dev** | Vue 3 / Pinia frontend with UI framework variant support | sonnet |
| **reviewer** | Code quality and security review with 8-category checklist | sonnet |
| **test-writer** | Test generation (Vitest/Jest) with AAA pattern and factory functions | sonnet |

## Hooks

- **pre-edit-guard**: Blocks edits to protected files (.env, lock files, secrets, node_modules)
- **post-edit-format**: Auto-formats with Prettier or Biome (auto-detected)
- **post-edit-lint**: Auto-lints with ESLint or Biome (auto-detected)

## Architecture

```
cc-plugin-suite/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Self-hosted marketplace catalog
├── scripts/
│   └── detect-stack.sh          # Dynamic stack detection
├── skills/                      # 11 skills with SKILL.md + reference.md
├── agents/                      # 5 specialized agents
├── commands/                    # 4 orchestration commands
└── hooks/                       # Pre/post edit hooks
```

### Adaptive Skills

Every skill injects the project's tech stack profile at invocation time:

```markdown
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
```

This enables skills to adapt their patterns for Tailwind vs Quasar vs Vuetify, Vitest vs Jest, RBAC vs OpenFGA, etc. — without manual configuration.

### Progressive Disclosure

SKILL.md files stay under 500 lines. Detailed reference material lives in `reference.md` files loaded on demand, keeping the initial prompt lean.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally with `claude --plugin-dir .`
4. Verify skills appear and load correctly
5. Submit a pull request

## License

MIT
