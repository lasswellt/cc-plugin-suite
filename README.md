<div align="center">

```
   ─── ⚡ ──────────────────────────────────

   ██████╗ ██╗     ██╗████████╗███████╗
   ██╔══██╗██║     ██║╚══██╔══╝╚══███╔╝
   ██████╔╝██║     ██║   ██║     ███╔╝
   ██╔══██╗██║     ██║   ██║    ███╔╝
   ██████╔╝███████╗██║   ██║   ███████╗
   ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝

   ──────────────────────────────── ⚡ ───
```

**Production-grade Claude Code plugin for Vue/Nuxt + Firebase**

**33 skills** · **6 agents** · **12 hooks**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/badge/version-0.4.0-cyan)](https://github.com/lasswellt/blitz/releases)

</div>

---

## Quick Start

```bash
npx blitz-cc@latest
```

That's it. The installer auto-detects your stack, registers the plugin, configures permissions, and sets up hooks.

<details>
<summary><b>More install options</b></summary>

**Non-interactive:**

```bash
npx blitz-cc@latest --yes
```

**Bash fallback** (if Node.js is not available):

```bash
curl -fsSL https://raw.githubusercontent.com/lasswellt/blitz/main/installer/install.sh | bash
```

**From the marketplace (manual):**

```bash
/plugin marketplace add lasswellt/blitz
/plugin install blitz@blitz
```

**Local testing:**

```bash
claude --plugin-dir ./blitz
```

</details>

### What the installer does

```
  Checking environment...
    ├─ Claude CLI ✓ (v2.x)
    ├─ Node.js ✓
    ├─ python3 ✓
    └─ Platform: linux (WSL)

  Stack detection...
    ├─ Framework: Nuxt 3
    ├─ UI Framework: Quasar
    ├─ Backend: Firebase/GCP
    ├─ Package Manager: pnpm
    └─ Testing: Vitest

  Marketplace registration... ✓
  Plugin installation...      ✓
  Plugin enablement...        ✓
  Permissions setup...        ✓ (29 allow, 2 deny)
  Environment variables...    ✓
  Activity feed setup...      ✓
```

Stack-aware permissions are generated automatically — Tailwind, Quasar, Firebase, VueFire domains and CLI tools are allowed based on what's in your `package.json`.

---

## Supported Stacks

| Layer | Supported |
|-------|-----------|
| **Frameworks** | Vue 3 (Vite), Nuxt 3 |
| **UI Frameworks** | Tailwind CSS, Quasar, Vuetify *(auto-detected)* |
| **Backend** | Firebase/GCP, Cloud Functions v2 |
| **State** | Pinia, VueFire, XState |
| **Testing** | Vitest, Jest |
| **Build Systems** | pnpm workspaces, Nx, Turborepo |

Skills auto-detect the project's tech stack at invocation time — no manual configuration needed.

### Prerequisites

- **bash** — hooks and stack detection
- **Node.js / npx** — format and lint hooks (Prettier, ESLint, Biome)
- **python3** — hooks for JSON parsing

---

## Skills (33)

### Core Development Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **research** | Investigates libraries, APIs, and architecture patterns. Spawns parallel research agents. | `/blitz:research <topic>` |
| **refactor** | Safe, incremental refactoring with test verification after each step. | `/blitz:refactor <file> <goal>` |
| **fix-issue** | Resolves GitHub issues end-to-end: fetch, research, implement, verify, update. | `/blitz:fix-issue <issue-number>` |
| **test-gen** | Generates tests matching project conventions (Vitest/Jest auto-detect). | `/blitz:test-gen <file-path>` |
| **ui-build** | 5-phase UI workflow: Discover, Analyze, Design, Implement, Refine. | `/blitz:ui-build` |
| **browse** | Automated browser testing via Playwright MCP. Captures console/network errors. | `/blitz:browse [full\|smoke\|page <path>\|fix]` |
| **bootstrap** | Scaffolds new projects, features, or packages with proper conventions. | `/blitz:bootstrap <type> <name>` |
| **quick** | Fast ad-hoc changes without full skill ceremony — small fixes, typos, config tweaks. | `/blitz:quick <request>` |
| **codebase-map** | Analyzes existing codebase: Technology, Architecture, Quality, Concerns. Brownfield onboarding. | `/blitz:codebase-map` |
| **todo** | Track development todos and follow-up items — add, list, check, resolve. | `/blitz:todo <add\|list\|check\|resolve>` |

### Sprint Lifecycle Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **sprint-plan** | Plans sprints from roadmap epics with research-backed stories. | `/blitz:sprint-plan` |
| **sprint-dev** | Implements sprints with coordinated agent teams in isolated worktrees. | `/blitz:sprint-dev` |
| **sprint-review** | Reviews sprint quality with automated checks and parallel reviewer agents. | `/blitz:sprint-review` |
| **roadmap** | Generates phased implementation roadmaps from research documents. | `/blitz:roadmap [full\|refresh\|extend\|status]` |

### Quality & Metrics Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **codebase-audit** | 5-pillar quality audit (Architecture, Performance, Security, Maintainability, Robustness). | `/blitz:codebase-audit` |
| **completeness-gate** | Scans code for placeholder patterns and production readiness issues. | `/blitz:completeness-gate [scope]` |
| **quality-metrics** | Collects, stores, and visualizes code quality metrics over time. | `/blitz:quality-metrics <mode>` |
| **perf-profile** | Profiles bundle size, runtime performance, and Lighthouse scores. | `/blitz:perf-profile <mode>` |
| **dep-health** | Audits dependencies for vulnerabilities, outdated packages, and license compliance. | `/blitz:dep-health <mode>` |
| **integration-check** | Validates cross-module wiring: exports, routes, auth guards, store-to-component. | `/blitz:integration-check [scope]` |

### Documentation & Release Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **doc-gen** | Generates API docs, component docs, architecture diagrams, and changelogs. | `/blitz:doc-gen <mode>` |
| **release** | Manages semantic versioning, changelogs, and GitHub releases. | `/blitz:release <mode>` |
| **migrate** | Handles framework and library migrations with incremental safety. | `/blitz:migrate <target>` |

### Orchestrator Skills

| Skill | Description | Invocation |
|-------|-------------|------------|
| **ask** | Task intake — classifies vague requests and dispatches to the right skill(s). | `/blitz:ask <request>` |
| **sprint** | Full sprint cycle: plan → implement → review. | `/blitz:sprint [flags]` |
| **implement** | Sprint implementation phase only. | `/blitz:implement [flags]` |
| **review** | Sprint review and quality gate only. | `/blitz:review [flags]` |
| **ship** | End-to-end shipping: review → completeness gate → quality metrics → release. | `/blitz:ship [version]` |
| **retrospective** | Self-improvement loop: analyzes sessions, generates improvement proposals, updates developer profile. | `/blitz:retrospective` |
| **health** | Plugin health check — verifies hooks, sessions, registry, and structural integrity. | `/blitz:health` |
| **next** | Determines the logical next action based on current project and sprint state. | `/blitz:next` |

## Agents (6)

| Agent | Role | Model |
|-------|------|-------|
| **architect** | Read-only architecture analysis (coupling, cohesion, dependency graphs) | sonnet |
| **backend-dev** | Cloud Functions / Zod / Firestore backend implementation | sonnet |
| **frontend-dev** | Vue 3 / Pinia frontend with UI framework variant support | sonnet |
| **reviewer** | Code quality and security review with 10-category checklist | sonnet |
| **test-writer** | Test generation (Vitest/Jest) with AAA pattern, coverage awareness, and regression tests | sonnet |
| **doc-writer** | Documentation generation (API docs, component docs, ADRs, migration guides) | sonnet |

## Hooks (9)

| Hook | Trigger | Behavior |
|------|---------|----------|
| **pre-edit-guard** | PreToolUse (Write\|Edit) | Blocks edits to protected files (.env, lock files, secrets, node_modules) |
| **pre-edit-backup** | PreToolUse (Write\|Edit) | Creates timestamped backups in /tmp/cc-backups/ before edits |
| **post-edit-format** | PostToolUse (Write\|Edit) | Auto-formats with Prettier or Biome (auto-detected) |
| **post-edit-lint** | PostToolUse (Write\|Edit) | Auto-lints with ESLint or Biome (auto-detected) |
| **post-edit-test** | PostToolUse (Write\|Edit) | Runs matching test file after source edits |
| **analysis-paralysis-guard** | PostToolUse (Read\|Glob\|Grep + Write\|Edit) | Warns after 5+ consecutive read-only operations without edits |
| **context-monitor** | PostToolUse (Read\|Glob\|Grep + Bash) | Tracks context window utilization, warns at ~60% and ~80% |
| **workflow-guard** | PreToolUse (Bash) | Warns on out-of-order phase execution in phased skills |
| **pre-commit-validate** | PreToolUse (Bash) | Validates staged files for banned patterns and secrets before git commit |

## Model Profiles

Three behavioral profiles control skill thoroughness. Set in `.claude-plugin/model-profiles.json`.

| Profile | Research Agents | Verification | Optional Phases | Use Case |
|---------|----------------|-------------|-----------------|----------|
| **quality** | Max | 2 passes | All run | Critical features, production releases |
| **balanced** | Standard | 1 pass | All run | Default — everyday development |
| **budget** | Min | 1 pass | Skip browser/E2E | Quick iterations, prototyping |

## Architecture

```
blitz/
├── .claude-plugin/
│   ├── plugin.json                # Plugin manifest
│   ├── marketplace.json           # Marketplace catalog
│   ├── skill-registry.json        # Skill metadata registry
│   └── model-profiles.json        # Quality/balanced/budget profiles
├── installer/                     # npx blitz-cc installer
│   ├── bin/install.js             # Entry point
│   ├── src/                       # Zero-dependency Node.js modules
│   └── install.sh                 # Bash fallback (curl | bash)
├── scripts/
│   ├── detect-stack.sh            # Dynamic stack detection
│   ├── validate-skill-output.sh   # Skill output validation
│   └── validate-plugin-structure.sh
├── skills/                        # 33 skills (SKILL.md + reference.md)
│   ├── _shared/                   # 7 shared protocols
│   │   ├── session-protocol.md    # Multi-session safety
│   │   ├── verbose-progress.md    # Output format + activity feed
│   │   ├── definition-of-done.md  # 9 banned anti-patterns
│   │   ├── checkpoint-protocol.md # Sprint checkpoint/resume
│   │   ├── deviation-protocol.md  # 4-tier escalation rules
│   │   ├── context-management.md  # Lean context window rules
│   │   └── session-report-template.md
│   ├── ask/                       # Task intake router
│   ├── sprint/                    # Full sprint cycle orchestrator
│   ├── sprint-plan/               # Sprint planning
│   ├── sprint-dev/                # Agent team implementation
│   ├── sprint-review/             # Quality review
│   ├── ... (26 more)
│   └── ui-build/                  # UI workflow
├── agents/                        # 6 specialized agents
│   ├── architect.md               # Architecture analysis (read-only)
│   ├── backend-dev.md             # Cloud Functions / Zod / Firestore
│   ├── frontend-dev.md            # Vue 3 / Pinia / UI frameworks
│   ├── reviewer.md                # 10-category code review
│   ├── test-writer.md             # Vitest/Jest test generation
│   └── doc-writer.md              # API docs, ADRs, changelogs
└── hooks/                         # 9 pre/post hooks
    ├── hooks.json
    └── scripts/
        ├── pre-edit-guard.sh      # Block edits to protected files
        ├── pre-edit-backup.sh     # Timestamped backups
        ├── post-edit-format.sh    # Auto-format (Prettier/Biome)
        ├── post-edit-lint.sh      # Auto-lint (ESLint/Biome)
        ├── post-edit-test.sh      # Run matching tests
        ├── post-edit-activity-log.sh
        ├── pre-commit-validate.sh # Scan for banned patterns
        ├── workflow-guard.sh      # Phase order enforcement
        ├── context-monitor.sh     # Context window utilization
        └── analysis-paralysis-guard.sh
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

Plugin agents run with default permission prompts. To enable `acceptEdits` (no prompts when agents edit files), the installer can copy agents to your project:

```bash
npx blitz-cc@latest   # select "Copy agents with acceptEdits mode" when prompted
```

Or manually:

```bash
cp ~/.claude/plugins/cache/blitz/*/agents/backend-dev.md .claude/agents/backend-dev.md
# Then add `permissionMode: acceptEdits` to the frontmatter
```

## Skill Permissions

The `allowed-tools` field in skill frontmatter grants auto-permission — tools listed are automatically approved without prompting while the skill is active. It does not restrict which tools the skill can use; unlisted tools can still be used with user approval.

## Installer CLI

The `blitz-cc` installer is a zero-dependency Node.js package that handles the full setup.

```
Usage:
  npx blitz-cc@latest              Interactive install
  npx blitz-cc@latest --yes        Non-interactive with defaults
  npx blitz-cc@latest --uninstall  Remove Blitz from project

Options:
  --project <path>     Target project directory (default: cwd)
  --yes, -y            Accept all defaults
  --dry-run            Preview changes without writing
  --skip-agents        Skip agent copy step
  --skip-permissions   Skip permissions setup
  --uninstall          Remove Blitz from the project
  --verbose            Show detailed output
```

The installer is idempotent — safe to run multiple times. It merges settings without overwriting your existing configuration.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally with `claude --plugin-dir .`
4. Run `./scripts/validate-plugin-structure.sh` to check integrity
5. Verify skills appear and load correctly
6. Submit a pull request

## License

MIT
