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

**37 skills** · **6 agents** · **19 hooks** · **8 hook events**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/github/v/release/lasswellt/cc-plugin-suite?color=cyan)](https://github.com/lasswellt/cc-plugin-suite/releases)

</div>

---

## Quick Start

```bash
npx blitz-cc@latest
```

The installer auto-detects your stack, registers the plugin, configures permissions, and sets up hooks.

<details>
<summary><b>More install options</b></summary>

**Non-interactive:**

```bash
npx blitz-cc@latest --yes
```

**Bash fallback** (if Node.js is not available):

```bash
curl -fsSL https://raw.githubusercontent.com/lasswellt/cc-plugin-suite/main/installer/install.sh | bash
```

**From the marketplace (manual):**

```bash
/plugin marketplace add lasswellt/blitz
/plugin install blitz@blitz
```

**Local development:**

```bash
claude --plugin-dir ./blitz
/reload-plugins   # hot-reload after edits
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
| **State** | Pinia, VueFire |
| **Testing** | Vitest, Jest |
| **Build Systems** | pnpm workspaces, Nx, Turborepo |

Skills auto-detect the project's tech stack at invocation time — no manual configuration needed.

### Prerequisites

- **Claude Code** ≥ v2.1.71
- **bash** — hooks and stack detection
- **Node.js / npx** — installer + format/lint hooks (Prettier, ESLint, Biome)
- **python3** — JSON parsing in hooks
- **jq** — carry-forward registry operations

---

## The Blitz Cycle

Blitz implements an opinionated development cycle from research to shipped code:

```
/blitz:research <topic>
        │ writes docs/_research/YYYY-MM-DD_<slug>.md
        │ with scope: YAML frontmatter (quantified claims)
        ▼
/blitz:sprint  ← auto-detects uningested research,
        │         chains roadmap extend if needed
        ▼
  roadmap extend → seeds epic-registry.json + carry-forward.jsonl
        ▼
  sprint-plan   → stories with dependency ordering
        ▼
  sprint-dev    → parallel agents in isolated worktrees
        ▼
  sprint-review → quality gates (type-check, lint, tests, build)
        ▼
/blitz:ship     → completeness-gate → release → PushNotification
```

Every scope claim from research is tracked in `.cc-sessions/carry-forward.jsonl` as an append-only registry. Sprint-review enforces that no quantified scope silently drops between cycles. The loop cannot declare "done" while the registry has active entries.

### Autonomous Loop

```bash
/loop 5m /blitz:sprint --loop
```

Each tick the reconciliation engine reads current state, executes exactly one phase (ingest → plan → implement → review), commits progress, and exits. The loop re-enters on the next tick. Fully autonomous under bypass permissions.

---

## Skills (37)

### Orchestrators

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **ask** | Classifies vague requests and dispatches to the right skill | `/blitz:ask <request>` |
| **sprint** | Full cycle: plan → implement → review. Auto-chains `roadmap extend` when uningested research docs are detected. | `/blitz:sprint [--plan-only\|--skip-review\|--loop\|--gaps\|--resume\|--epics E-001]` |
| **implement** | Sprint implementation phase only | `/blitz:implement [--sprint N\|--resume]` |
| **review** | Sprint review and quality gate only | `/blitz:review [--sprint N]` |
| **ship** | review → completeness-gate → quality-metrics → release → PushNotification | `/blitz:ship [version]` |
| **next** | Reads sprint/roadmap/carry-forward state and recommends the logical next command | `/blitz:next` |

### Sprint Lifecycle

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **research** | Spawns parallel research agents (library-docs, web-researcher, codebase-analyst), synthesizes structured research doc with `scope:` YAML frontmatter | `/blitz:research <topic>` |
| **roadmap** | Generates phased roadmaps from research docs. `extend` ingests new docs into the carry-forward registry. | `/blitz:roadmap [full\|refresh\|extend\|status]` |
| **sprint-plan** | Plans a sprint from unblocked epics. Reads carry-forward.jsonl as mandatory planning input. Spawns GitHub issues. | `/blitz:sprint-plan [--sprint N\|--gaps]` |
| **sprint-dev** | Spawns backend/frontend/test agents in isolated worktrees. Monitor-tool event-driven progress tracking. Merges branches on completion. | `/blitz:sprint-dev [--sprint N\|--resume\|--mode autonomous\|checkpoint\|interactive]` |
| **sprint-review** | Parallel reviewer agents (security, backend, frontend, pattern). Enforces 5 carry-forward invariants. Auto-injects planning inputs for next sprint. | `/blitz:sprint-review [--sprint N]` |

### Code Quality

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **code-doctor** | Framework-API correctness audit: Firestore anti-patterns, VueFire binding, Vue 3 reactivity misuse, Pinia store coupling. Read-only by default. | `/blitz:code-doctor [--fix]` |
| **code-sweep** | 30 checks across 7 categories. Ratchet mechanism ensures quality only improves. Loop-safe. | `/blitz:code-sweep [--loop\|--category <name>]` |
| **codebase-audit** | 5-pillar audit: Architecture, Performance, Security, Maintainability, Robustness | `/blitz:codebase-audit` |
| **completeness-gate** | Scans for placeholder patterns and production-readiness issues. Returns structured findings with `file:line` refs. | `/blitz:completeness-gate [scope]` |
| **integration-check** | Export-to-import tracing, route coverage, auth guard coverage, store-to-component wiring. Read-only. | `/blitz:integration-check [scope]` |
| **ui-audit** | Cross-page semantic consistency + data-quality + UX heuristics. Extracts labeled value registry, asserts invariants, flags placeholders/nulls/flapping. Loop-safe. | `/blitz:ui-audit [full\|smoke\|data\|buttons\|events\|consistency\|heuristics\|role <name>\|--loop]` |
| **quality-metrics** | Collects, stores, and visualizes code quality metrics over time | `/blitz:quality-metrics [collect\|dashboard\|trend\|compare]` |
| **perf-profile** | Bundle size, runtime performance, Lighthouse scores | `/blitz:perf-profile [bundle\|runtime\|lighthouse]` |
| **dep-health** | Vulnerabilities, outdated packages, license compliance | `/blitz:dep-health [audit\|upgrade\|report]` |

### Core Development

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **ui-build** | 5-phase workflow (Discover, Analyze, Design, Implement, Refine). Generates Vue 3 UI native to the project's design system. | `/blitz:ui-build <feature description>` |
| **browse** | Playwright MCP browser testing. Captures console errors, failed network requests. Auto-fix mode. Loop-safe. | `/blitz:browse [full\|smoke\|page <path>\|fix\|--loop]` |
| **refactor** | Incremental refactoring with test snapshot before/after each step | `/blitz:refactor <file-or-dir> <goal>` |
| **test-gen** | Tests matching project conventions (Vitest/Jest auto-detect). AAA pattern, factory functions, edge cases. | `/blitz:test-gen <file-path>` |
| **fix-issue** | Fetches GitHub issue → researches root cause → implements fix with tests → updates issue | `/blitz:fix-issue <issue-number>` |
| **migrate** | Framework/library/tooling migrations. Researches breaking changes, atomic steps, verifies after each. | `/blitz:migrate <target>` |
| **bootstrap** | Greenfield project scaffold or feature/package scaffold into existing project | `/blitz:bootstrap <type> <name>` |
| **quick** | Small targeted edits without skill ceremony | `/blitz:quick <request>` |

### Documentation & Release

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **doc-gen** | API docs, component docs, architecture diagrams, changelogs from source | `/blitz:doc-gen [api\|components\|architecture\|changelog\|full]` |
| **release** | Semantic versioning, changelog, GitHub release | `/blitz:release [prepare\|verify\|publish\|rollback]` |

### Analysis & Meta

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **codebase-map** | 4-dimension analysis (Technology, Architecture, Quality, Concerns). Produces `CODEBASE-MAP.md` for brownfield onboarding. | `/blitz:codebase-map` |
| **compress** | Rewrites markdown/text files to terse form to reduce input tokens. Preserves code, URLs, tables, YAML/JSON verbatim. | `/blitz:compress <file>` |
| **retrospective** | Analyzes completed sessions, identifies patterns, generates self-improvement proposals with safety classification | `/blitz:retrospective` |
| **setup** | Detects conflicts between CLAUDE.md files and blitz skill behaviors. Validates permissions and stack assumptions. | `/blitz:setup` |
| **health** | Plugin health check — hooks, sessions, registry, structural integrity | `/blitz:health` |
| **conform** | Detects + fixes drift in an existing project's blitz runtime artifacts (`.cc-sessions/`, `sprints/`, `docs/roadmap/`, `docs/_research/`, `STATE.md`) against the current canonical schemas in `skills/_shared/`. Use after upgrading blitz when sprint-dev/review starts complaining about missing fields. Read-only by default; `--fix` applies migrations. `--scope plugin` available for plugin-fork structural drift. | `/blitz:conform [target-dir] [--fix\|--report-only] [--scope project\|plugin\|all]` |
| **todo** | Track development todos in `.cc-sessions/todos.jsonl` | `/blitz:todo [add\|list\|check\|resolve]` |

---

## Agents (6)

Agents are spawned by skills using `isolation: "worktree"` — each gets its own git branch that is auto-cleaned if no changes are made.

| Agent | Role | MCP Scope |
|-------|------|-----------|
| **backend-dev** | Cloud Functions v2 / Zod / Firestore implementation. Numbered comment flow, audit logging patterns. | Firestore, Firebase |
| **frontend-dev** | Vue 3 / Pinia components, stores, composables, routes. Adapts to Tailwind/Quasar/Vuetify. | Playwright |
| **test-writer** | Vitest/Jest tests. AAA pattern, factory functions, coverage awareness, regression tests. | Read-only |
| **reviewer** | Code quality and security review. OWASP top-10, pattern violations, correctness issues. | Read-only |
| **architect** | Read-only architecture analysis — coupling, cohesion, module boundaries, dependency graphs. | Read-only |
| **doc-writer** | API docs, component docs, ADRs, README sections, migration guides from source. | Read-only |

### Typed Agent Definitions

Drop typed agent YAML files into `.claude/agents/` to scope MCP server access per agent. Sprint-dev auto-detects these at spawn time:

```
.claude/agents/
├── blitz-backend-dev.md   # mcpServers: [firebase]
├── blitz-frontend-dev.md  # mcpServers: [playwright]
└── blitz-test-writer.md   # tools: read-only only
```

---

## Hooks (19 scripts, 8 events)

| Event | Matcher | Script | Behavior |
|-------|---------|--------|----------|
| `PreCompact` | `auto\|manual` | `pre-compact-snapshot.sh` | Writes sprint state snapshot to `.cc-sessions/compact-state.json` before context compaction — prevents state loss on long sprints |
| `PostCompact` | `auto\|manual` | `post-compact-log.sh` | Reads snapshot, appends restoration hint to activity feed so the next turn knows where to resume |
| `UserPromptExpansion` | `blitz:.*` | `blitz-prompt-expansion.sh` | Injects last 5 activity-feed events as `additionalContext` into every `blitz:*` invocation — instant session awareness without manual CLAUDE.md reads |
| `SessionStart` | — | `session-start.sh` | Reads activity feed, prints recent cross-session activity, logs `session_start` event |
| `TeammateIdle` | — | `teammate-idle.sh` | Quality gate for agent teams — can return feedback (exit 2) to keep agents working |
| `TaskCompleted` | — | `task-completed-validate.sh` | Validates task completion against Definition of Done before marking done |
| `PostToolUse` | `Write\|Edit` | `post-edit-activity-log.sh` | Appends `file_change` event to `.cc-sessions/activity-feed.jsonl` |
| `PostToolUse` | `Write\|Edit` | `post-edit-format.sh` | Auto-formats with Prettier or Biome (auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-lint.sh` | Auto-lints with ESLint or Biome (auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-test.sh` | Runs matching test file after source edits |
| `PostToolUse` | `Write\|Edit` | `analysis-paralysis-guard.sh` | Warns after 5+ consecutive reads without writes |
| `PostToolUse` | `Read\|Glob\|Grep` | `analysis-paralysis-guard.sh` | Same guard on read-heavy operations |
| `PostToolUse` | `Write\|Edit` | `skill-frontmatter-validate.sh` | Lints any modified `SKILL.md` against the canonical frontmatter contract (third-person description ≤1024 chars, body ≤500 lines, OUTPUT STYLE snippet present, required fields when invokable) |
| `PostToolUse` | `Read\|Glob\|Grep\|Bash` | `context-monitor.sh` | Tracks context window utilization, warns at ~60% and ~80% |
| `PreToolUse` | `Write\|Edit` | `pre-edit-guard.sh` | Blocks edits to protected files (.env, lock files, node_modules) |
| `PreToolUse` | `Write\|Edit` | `pre-edit-backup.sh` | Creates timestamped backup in /tmp/cc-backups/ before every edit |
| `PreToolUse` | `Bash` | `pre-commit-validate.sh` | On `git commit`: SKILL.md frontmatter lint + version-sync drift check + broken markdown link warn |
| `PreToolUse` | `Bash` | `reference-compression-validate.sh` | On `git commit`: validates compressed `references/main.md` matches `.original` sibling structure (code fences, URLs, headings, tables) |
| `PreToolUse` | `Bash` | `markdown-link-validate.sh` | On `git commit`: warn-only scan for broken relative `.md` links across `skills/` (skips fenced code, inline code, http URLs) |
| `PreToolUse` | `Bash` | `workflow-guard.sh` | Warns on out-of-order phase execution in phased skills |

---

## Carry-Forward Registry

The carry-forward registry (`.cc-sessions/carry-forward.jsonl`) is the backbone of the blitz cycle. It tracks quantified scope claims across sprints and prevents silent drops.

**How it works:**

1. `/blitz:research` emits a `scope:` YAML block when the research doc contains quantified claims (e.g., "migrate 45 components"):
   ```yaml
   ---
   scope:
     - id: cf-2026-04-25-modal-migration
       unit: components
       target: 45
       description: Migrate modal components to @mbk/ui Modal.vue
       acceptance:
         - grep_absent: 'class="modal-overlay"'
         - grep_present:
             pattern: 'from.*@mbk/ui.*Modal'
             min: 30
   ---
   ```

2. `/blitz:roadmap extend` (auto-invoked by `/blitz:sprint`) ingests the block as a registry entry with `status: active`, `coverage: 0.0`.

3. Sprint-plan treats every `status ∈ {active, partial}` entry as a mandatory planning input.

4. Sprint-dev advances `delivered.actual` and `coverage` as stories complete.

5. Sprint-review enforces 5 invariants — the loop cannot exit while entries remain active. Entries stuck for 3+ sprints are escalated with rollover banners.

6. When `coverage` reaches 1.0, the entry transitions to `status: complete`.

---

## Shared Protocols (`skills/_shared/`)

All skills share 14 protocol files that define cross-cutting behavior:

| Protocol | Purpose |
|----------|---------|
| `session-protocol.md` | Multi-session safety — file locks, conflict matrix, session registration, autonomy levels |
| `verbose-progress.md` | Output format and activity feed logging spec |
| `definition-of-done.md` | Banned anti-patterns (TODO/FIXME/placeholder/mock in production, etc.) |
| `checkpoint-protocol.md` | Sprint STATE.md format and resume flow |
| `deviation-protocol.md` | 4-tier escalation for unexpected implementation issues |
| `context-management.md` | Context window hygiene rules — when to summarize, when to offload to STATE.md |
| `carry-forward-registry.md` | Carry-forward registry — schema, **canonical Reader Algorithm**, writer contracts, rollover escalation |
| `story-frontmatter.md` | Canonical YAML schema for sprint stories — producer/consumer matrix, validation algorithm |
| `state-handoff.md` | Pipeline contracts — which artifacts each skill produces/requires (bootstrap → research → roadmap → sprint-* → ship) |
| `spawn-protocol.md` | Agent spawn rules — type selection, workload sizing, HEARTBEAT/PARTIAL, **Agent Output Contract** (success/failure/partial gates) |
| `terse-output.md` | Output style — canonical exemptions list, intensity precedence, OUTPUT STYLE snippet |
| `agent-prompt-boilerplate.md` / `scheduling.md` / `session-report-template.md` | Agent prompt preamble, loop-mode scheduling, session report format |

---

## Model Profiles

Three behavioral profiles control skill thoroughness. Set in `.claude-plugin/model-profiles.json`.

| Profile | Research Agents | Verification | Optional Phases | Use Case |
|---------|----------------|-------------|-----------------|----------|
| **quality** | Max | 2 passes | All run | Critical features, production releases |
| **balanced** | Standard | 1 pass | All run | Default — everyday development |
| **budget** | Min | 1 pass | Skip browser/E2E | Quick iterations, prototyping |

---

## Architecture

```
blitz/
├── .claude-plugin/
│   ├── plugin.json              # Manifest (name, version, author)
│   ├── marketplace.json         # Marketplace catalog
│   └── model-profiles.json      # quality / balanced / budget profiles
├── installer/
│   ├── bin/install.js           # npx blitz-cc entry point
│   ├── src/                     # Zero-dependency Node.js modules
│   └── install.sh               # Bash fallback (curl | bash)
├── scripts/
│   ├── detect-stack.sh          # Dynamic stack detection (injected into every skill)
│   ├── validate-plugin-structure.sh
│   ├── validate-skill-output.sh
│   ├── check-version-sync.sh    # plugin.json ↔ marketplace.json ↔ installer banner
│   ├── parse-scope-to-registry.py
│   ├── backfill-registry-parents.py
│   ├── add-terse-output-reference.py
│   └── maint/v1.9.0/            # Archived migration scripts from the v1.9.0 overhaul (idempotent re-runs)
├── skills/
│   ├── _shared/                 # 14 shared protocol files
│   ├── sprint/                  # Orchestrator — auto-chains roadmap extend
│   ├── sprint-plan/             # Carry-forward-aware sprint planning
│   ├── sprint-dev/              # Monitor-tool progress, worktree isolation
│   ├── sprint-review/           # 5 carry-forward invariants
│   ├── research/                # Parallel agents → scope: YAML frontmatter
│   ├── roadmap/                 # Research ingestion → epic-registry
│   ├── ui-audit/                # Cross-page consistency, ScheduleWakeup loop
│   ├── code-doctor/             # Framework-API correctness audit
│   ├── conform/                 # Brings legacy project artifacts into current spec (story v0.x→v1.9, etc.)
│   └── ... (28 more)
├── agents/
│   ├── backend-dev.md           # Firestore/VueFire/Cloud Functions
│   ├── frontend-dev.md          # Vue 3/Pinia/Quasar/Tailwind
│   ├── test-writer.md           # Vitest/Jest AAA
│   ├── reviewer.md              # OWASP + pattern review
│   ├── architect.md             # Read-only dependency analysis
│   └── doc-writer.md            # API docs, ADRs, changelogs
└── hooks/
    ├── hooks.json               # 8 event types wired
    └── scripts/                 # 19 hook scripts (see hooks/scripts/README.md for the full event-grouped index)
        ├── pre-compact-snapshot.sh     # PreCompact: sprint state → compact-state.json
        ├── post-compact-log.sh         # PostCompact: activity feed restoration hint
        ├── blitz-prompt-expansion.sh   # UserPromptExpansion: activity-feed context injection
        ├── session-start.sh            # SessionStart: activity feed summary + per-session counter reset
        ├── teammate-idle.sh            # TeammateIdle: agent team quality gate
        ├── task-completed-validate.sh  # TaskCompleted: DoD check
        ├── post-edit-activity-log.sh   # file_change → activity feed
        ├── post-edit-format.sh         # Prettier / Biome auto-format
        ├── post-edit-lint.sh           # ESLint / Biome auto-lint
        ├── post-edit-test.sh           # Run matching tests after edit
        ├── skill-frontmatter-validate.sh  # Lint canonical SKILL.md frontmatter on every edit
        ├── pre-edit-guard.sh           # Block .env / lock files
        ├── pre-edit-backup.sh          # /tmp/cc-backups/ before every edit
        ├── pre-commit-validate.sh      # Scan staged files; runs frontmatter + version-sync + link checks
        ├── analysis-paralysis-guard.sh # Warn on read-heavy without writes
        ├── context-monitor.sh          # Context utilization at 60% / 80%
        ├── reference-compression-validate.sh  # On commit: compressed-vs-original parity
        ├── markdown-link-validate.sh   # On commit: warn on broken relative .md links
        └── workflow-guard.sh           # Phase order enforcement
```

---

## Runtime Artifacts

Blitz generates runtime state in the project directory. These are **gitignored** — they are machine-local outputs of the plugin, not plugin source:

```
sprints/             # Sprint stories, manifests, STATE.md checkpoints
sprint-registry.json # Live sprint tracking
.cc-sessions/        # Session state, activity feed, carry-forward registry
docs/_research/      # Generated research documents
docs/roadmap/        # Generated roadmap, epic-registry, capability-index
docs/retrospective/  # Session retrospective proposals
```

### Conforming after upgrades

Existing projects that were bootstrapped on an older blitz version may carry artifact drift — old story-frontmatter schema (`epic` instead of `epic_id`), missing `registry_entries` field, STATE.md formats no longer mentioned in shared protocols, etc. Run **`/blitz:conform`** to detect drift; **`/blitz:conform --fix`** to apply mechanical migrations idempotently with per-file backups. Default scope is `project` (runtime artifacts); `--scope plugin` targets plugin forks. See `skills/conform/SKILL.md` and `skills/conform/references/main.md` for the full schema-detection rules and migration tables.

---

## Installer CLI

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

The installer is idempotent — safe to run multiple times. Merges settings without overwriting your existing configuration.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally: `claude --plugin-dir .` then `/reload-plugins` after edits
4. Validate structure: `./scripts/validate-plugin-structure.sh`
5. Add a CHANGELOG entry
6. Submit a pull request

## License

MIT
