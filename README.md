# cc-plugin-suite

Production-grade development skills for Vue.js, Nuxt, and GCP Firebase projects. A Claude Code plugin that provides sprint workflows, code review, performance profiling, release management, dependency health, documentation generation, migration support, and self-improvement loops.

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
- **python3** — required by hooks for JSON parsing
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

## Skills (25)

### Core Development Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **research** | Investigates libraries, APIs, and architecture patterns. Spawns parallel research agents. | `/cc-plugin-suite:research <topic>` |
| **refactor** | Safe, incremental refactoring with test verification after each step. | `/cc-plugin-suite:refactor <file> <goal>` |
| **fix-issue** | Resolves GitHub issues end-to-end: fetch, research, implement, verify, update. | `/cc-plugin-suite:fix-issue <issue-number>` |
| **test-gen** | Generates tests matching project conventions (Vitest/Jest auto-detect). | `/cc-plugin-suite:test-gen <file-path>` |
| **ui-build** | 5-phase UI workflow: Discover, Analyze, Design, Implement, Refine. | `/cc-plugin-suite:ui-build` |
| **browse** | Automated browser testing via Playwright MCP. Captures console/network errors. | `/cc-plugin-suite:browse [full\|smoke\|page <path>\|fix]` |
| **bootstrap** | Scaffolds new projects, features, or packages with proper conventions. | `/cc-plugin-suite:bootstrap <type> <name>` |

### Sprint Lifecycle Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **sprint-plan** | Plans sprints from roadmap epics with research-backed stories. | `/cc-plugin-suite:sprint-plan` |
| **sprint-dev** | Implements sprints with coordinated agent teams in isolated worktrees. | `/cc-plugin-suite:sprint-dev` |
| **sprint-review** | Reviews sprint quality with automated checks and parallel reviewer agents. | `/cc-plugin-suite:sprint-review` |
| **roadmap** | Generates phased implementation roadmaps from research documents. | `/cc-plugin-suite:roadmap [full\|refresh\|extend\|status]` |

### Quality & Metrics Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **codebase-audit** | 5-pillar quality audit (Architecture, Performance, Security, Maintainability, Robustness). | `/cc-plugin-suite:codebase-audit` |
| **completeness-gate** | Scans code for placeholder patterns and production readiness issues. | `/cc-plugin-suite:completeness-gate [scope]` |
| **quality-metrics** | Collects, stores, and visualizes code quality metrics over time. | `/cc-plugin-suite:quality-metrics <mode>` |
| **perf-profile** | Profiles bundle size, runtime performance, and Lighthouse scores. | `/cc-plugin-suite:perf-profile <mode>` |
| **dep-health** | Audits dependencies for vulnerabilities, outdated packages, and license compliance. | `/cc-plugin-suite:dep-health <mode>` |

### Documentation & Release Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **doc-gen** | Generates API docs, component docs, architecture diagrams, and changelogs. | `/cc-plugin-suite:doc-gen <mode>` |
| **release** | Manages semantic versioning, changelogs, and GitHub releases. | `/cc-plugin-suite:release <mode>` |
| **migrate** | Handles framework and library migrations with incremental safety. | `/cc-plugin-suite:migrate <target>` |

### Orchestrator Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **ask** | Task intake — classifies vague requests and dispatches to the right skill(s). | `/cc-plugin-suite:ask <request>` |
| **sprint** | Full sprint cycle: plan → implement → review. | `/cc-plugin-suite:sprint [flags]` |
| **implement** | Sprint implementation phase only. | `/cc-plugin-suite:implement [flags]` |
| **review** | Sprint review and quality gate only. | `/cc-plugin-suite:review [flags]` |
| **ship** | End-to-end shipping: review → completeness gate → quality metrics → release. | `/cc-plugin-suite:ship [version]` |
| **retrospective** | Self-improvement loop: analyzes sessions and generates improvement proposals. | `/cc-plugin-suite:retrospective` |

## Agents (6)

| Agent | Role | Model |
|-------|------|-------|
| **architect** | Read-only architecture analysis (coupling, cohesion, dependency graphs) | sonnet |
| **backend-dev** | Cloud Functions / Zod / Firestore backend implementation | sonnet |
| **frontend-dev** | Vue 3 / Pinia frontend with UI framework variant support | sonnet |
| **reviewer** | Code quality and security review with 10-category checklist | sonnet |
| **test-writer** | Test generation (Vitest/Jest) with AAA pattern, coverage awareness, and regression tests | sonnet |
| **doc-writer** | Documentation generation (API docs, component docs, ADRs, migration guides) | sonnet |

## Hooks (6)

| Hook | Trigger | Behavior |
|------|---------|----------|
| **pre-edit-guard** | PreToolUse (Write\|Edit) | Blocks edits to protected files (.env, lock files, secrets, node_modules) |
| **pre-edit-backup** | PreToolUse (Write\|Edit) | Creates timestamped backups in /tmp/cc-backups/ before edits |
| **post-edit-format** | PostToolUse (Write\|Edit) | Auto-formats with Prettier or Biome (auto-detected) |
| **post-edit-lint** | PostToolUse (Write\|Edit) | Auto-lints with ESLint or Biome (auto-detected) |
| **post-edit-test** | PostToolUse (Write\|Edit) | Runs matching test file after source edits |
| **pre-commit-validate** | PreToolUse (Bash) | Validates staged files for banned patterns and secrets before git commit |

## Architecture

```
cc-plugin-suite/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest (v0.2.0)
│   └── marketplace.json         # Self-hosted marketplace catalog
├── scripts/
│   ├── detect-stack.sh          # Dynamic stack detection
│   ├── validate-skill-output.sh # Skill output validation (code, docs, config, stories, reports)
│   └── validate-plugin-structure.sh # Plugin structure integrity checks
├── skills/                      # 25 skills with SKILL.md + reference.md
│   ├── _shared/
│   │   ├── definition-of-done.md
│   │   └── session-protocol.md
│   ├── ask/                     # Orchestrator: task intake router
│   ├── bootstrap/               # Project/feature/package scaffolding
│   ├── browse/                  # Browser testing via Playwright
│   ├── codebase-audit/          # 5-pillar quality audit
│   ├── completeness-gate/       # Production readiness scanner
│   ├── dep-health/              # Dependency health audit
│   ├── doc-gen/                 # Documentation generation
│   ├── fix-issue/               # GitHub issue resolution
│   ├── implement/               # Sprint implementation orchestrator
│   ├── migrate/                 # Framework/library migration
│   ├── perf-profile/            # Performance profiling
│   ├── quality-metrics/         # Quality metrics tracking
│   ├── refactor/                # Safe incremental refactoring
│   ├── release/                 # Release management
│   ├── research/                # Topic investigation
│   ├── retrospective/           # Self-improvement analysis
│   ├── review/                  # Sprint review orchestrator
│   ├── roadmap/                 # Implementation roadmap
│   ├── ship/                    # End-to-end shipping orchestrator
│   ├── sprint/                  # Full sprint cycle orchestrator
│   ├── sprint-dev/              # Sprint implementation with agents
│   ├── sprint-plan/             # Sprint planning
│   ├── sprint-review/           # Sprint quality review
│   ├── test-gen/                # Test generation
│   └── ui-build/                # UI workflow
├── agents/                      # 6 specialized agents
│   ├── architect.md
│   ├── backend-dev.md
│   ├── doc-writer.md
│   ├── frontend-dev.md
│   ├── reviewer.md
│   └── test-writer.md
└── hooks/                       # 6 pre/post hooks
    ├── hooks.json
    └── scripts/
        ├── pre-edit-guard.sh
        ├── pre-edit-backup.sh
        ├── post-edit-format.sh
        ├── post-edit-lint.sh
        ├── post-edit-test.sh
        └── pre-commit-validate.sh
```

## Quality Philosophy

This plugin enforces a zero-tolerance policy for placeholder code through machine-readable checks at every stage:

1. **Definition of Done** (`_shared/definition-of-done.md`) — 9 banned patterns that all code-producing skills and agents must check
2. **Completeness Gate** — automated scanner that can be invoked standalone or chained into any workflow
3. **Agent Self-Validation** — every dev agent runs a completeness check on its own output before reporting done
4. **Commit Validation** — pre-commit hook scans staged files for banned patterns
5. **Plugin Structure Validation** — `scripts/validate-plugin-structure.sh` ensures all skills, agents, and hooks are properly structured

## Release Workflow

The `ship` skill chains quality gates into a single shipping workflow:

```
sprint-review → completeness-gate → quality-metrics collect → release prepare → release verify → release publish
```

Each step must pass before proceeding. Quality gates cannot be skipped.

### Adaptive Skills

Every skill injects the project's tech stack profile at invocation time:

```markdown
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
```

This enables skills to adapt their patterns for Tailwind vs Quasar vs Vuetify, Vitest vs Jest, RBAC vs OpenFGA, etc. — without manual configuration.

### Progressive Disclosure

SKILL.md files stay under 500 lines. Detailed reference material lives in `reference.md` files that Claude loads on demand when it needs specific templates or schemas, keeping the initial prompt lean.

## Agent Permission Mode

Plugin agents do not support the `permissionMode` frontmatter field — it is silently ignored by Claude Code. All plugin agents run with default permission prompts regardless of what is specified.

To get `acceptEdits` behavior for an agent, copy it from the plugin cache into your project's `.claude/agents/` directory where it becomes a project-level agent with full frontmatter support:

```bash
cp ~/.claude/plugins/cache/cc-plugin-suite/agents/backend-dev.md .claude/agents/backend-dev.md
```

Then add `permissionMode: acceptEdits` to the project-level copy.

## Skill Permissions

The `allowed-tools` field in skill frontmatter grants auto-permission — tools listed are automatically approved without prompting while the skill is active. It does not restrict which tools the skill can use; unlisted tools can still be used with user approval.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally with `claude --plugin-dir .`
4. Run `./scripts/validate-plugin-structure.sh` to check integrity
5. Verify skills appear and load correctly
6. Submit a pull request

## License

MIT
