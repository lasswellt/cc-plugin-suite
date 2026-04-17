# Subagent Type Selection

Authoritative guidance for blitz skills on choosing the right subagent type when spawning via the `Agent` tool or `TeamCreate`+`SendMessage`.

**Why this doc exists**: In April 2026, several blitz skills were observed spawning subagents that the SDK routed to the read-only `Explore` type for work that required writing findings to files. The agents completed, returned text, then silently failed the orchestrator's file-read step. All tokens were billed. This doc prevents that class of failure by making subagent type an explicit choice at every spawn site.

---

## Built-in Claude Code Subagent Types

Source: [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents). Verified 2026-04-16.

| Name | Purpose | Tools (CAN use) | Tools (CANNOT use) | Default Model |
|---|---|---|---|---|
| **Explore** | Fast, read-only codebase search | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Haiku |
| **Plan** | Plan-mode pre-flight research | Read, Grep, Glob, Bash (read subset) | Write, Edit, Agent, NotebookEdit | Inherits |
| **general-purpose** | Complex multi-step tasks requiring read + write | All tools (`*`) | None | Inherits |
| **statusline-setup** | Configure status line via `/statusline` | Read, Edit only | N/A | Sonnet |
| **claude-code-guide** | Answer Claude Code meta-questions | Read, Grep, Glob, WebFetch, WebSearch | Write, Edit, Agent | Haiku |

**Key quote on Explore**: "A fast, read-only agent optimized for searching and analyzing codebases... Claude delegates to Explore when it needs to search or understand a codebase without making changes."

**Key quote on general-purpose**: "Claude delegates to general-purpose when the task requires both exploration and modification, complex reasoning to interpret results, or multiple dependent steps."

`statusline-setup` and `claude-code-guide` are auto-invoked by the harness. Do not select them directly in skill spawns.

---

## Blitz Plugin Agents

Source: `agents/` directory. Verified 2026-04-16.

| Agent | Tools | Read-Only? | Default Model | Specialty |
|---|---|---|---|---|
| `blitz:architect` | Read, Glob, Grep, Bash | **YES (strictly)** | sonnet | Structural analysis, dependency graphs |
| `blitz:reviewer` | Read, **Write**, Bash, Glob, Grep | No (Write for findings only) | sonnet | Code quality/security review with written findings |
| `blitz:doc-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Documentation generation |
| `blitz:backend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Cloud Functions, Zod, Firestore |
| `blitz:frontend-dev` | Read, **Write**, Edit, Bash, Glob, Grep, WebSearch, ToolSearch | No | sonnet | Vue 3 / Pinia implementation |
| `blitz:test-writer` | Read, **Write**, Edit, Bash, Glob, Grep | No | sonnet | Unit / integration / E2E tests |

**Foot-gun**: `blitz:architect` is strictly read-only. If a spawn site expects `architect` to write findings files, the orchestrator must write them from the agent's text return — same failure mode as Explore. Do not use `blitz:architect` when writes are required.

**Plugin-agent caveat**: `permissionMode`, `hooks`, and `mcpServers` frontmatter are silently ignored for plugin agents. If you need those fields, copy the agent file out of the plugin directory into `~/.claude/agents/`.

---

## Decision Matrix

| Task type | Recommended subagent_type | Rationale |
|---|---|---|
| Read-only codebase search, findings returned as text | `Explore` | Fast Haiku, no write needed |
| **Research that MUST write findings to a file** | **`general-purpose`** | **Explore cannot Write. Never rely on heuristic defaults for write-required work.** |
| Focused grep/glob for a specific pattern | `Explore` | Fast, single-purpose |
| Web research + file writing | `general-purpose` | Has WebSearch + Write |
| Implementation (edit source files) | `blitz:backend-dev` / `blitz:frontend-dev` / `blitz:test-writer` | Role-specific conventions baked into the agent |
| Documentation writing | `blitz:doc-writer` | Designed for docs output |
| Code review with written findings | `blitz:reviewer` | Write for findings; cannot modify source |
| Architecture analysis with written report | `general-purpose` | `blitz:architect` is read-only — orchestrator must write report from agent's text return, OR spawn a `general-purpose` agent instead |
| Planning / strategy, no code changes | `Explore` or `Plan` (in plan mode) | Read-only; text summary to orchestrator |

**Rule of thumb**: if the agent needs to call `Write` or `Edit`, it MUST be `general-purpose` or a `blitz:<role>` agent with Write in its tool list. Anything else will silently fail.

---

## Model and Context Inheritance

Resolution order for subagent model (highest priority first):

1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
2. Per-invocation `model` parameter (Agent tool argument or SendMessage body)
3. Subagent definition's `model:` frontmatter
4. Main conversation's model (inheritance default)

**Default is `inherit`** — including `[1m]` flags. A Sonnet-declared subagent invoked from an Opus `[1m]` parent inherits `[1m]` too, then crashes at load if Sonnet 4.6 (1M requires `/extra-usage`).

**To force a specific model without `[1m]`**: set explicit `model: sonnet` or `model: opus` (no `[1m]`) in the subagent frontmatter, or set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` globally.

**Subagents cannot spawn subagents**: the harness prevents infinite nesting. Chain from the main conversation, not from within another subagent.

**Subagents do not inherit skills**: list any required skills explicitly in the subagent definition's `skills:` frontmatter field.

---

## Foot-Guns (from 2026-04-16 research)

1. **Explore picked for write-required work** — the exact bug that motivated this doc. Always specify `subagent_type` explicitly when writes are required.
2. **`blitz:architect` is read-only despite its name suggesting analytical output** — it cannot Write. Use `general-purpose` if the analysis must produce a file.
3. **Plugin-agent `permissionMode` is silently ignored** — use `.claude/agents/` (not plugin dirs) if you need that field.
4. **Haiku quality ceiling on Explore** — complex reasoning tasks may produce poor results. Use `general-purpose` with an explicit `model: sonnet` for nuanced analysis.
5. **`TeamCreate`+`SendMessage` does not accept `subagent_type`** — the SDK picks by heuristic. Either convert to the `Agent` tool (which takes `subagent_type` directly) or include an explicit "You are a general-purpose agent with Write access" instruction in the SendMessage body.
6. **Model inheritance propagates `[1m]`** — v1.1.3 crashed a Sonnet-declared skill invoked from a 1M parent. Declare explicit `model:` without `[1m]` to prevent this.

---

## How to Reference This Doc

Every blitz skill that spawns subagents should add to its Additional Resources block:

```markdown
- For subagent type selection, see [subagent-types.md](/_shared/subagent-types.md)
```

Reviewers (`/blitz:sprint-review`) must flag any new agent-spawn site that lacks an explicit `subagent_type` declaration as a BLOCKER.
