#!/usr/bin/env python3
"""Rewrite descriptions for triggerability per Anthropic skill-creator guidance.

Principles applied:
- Third-person voice ("Plans sprints", not "I plan sprints")
- Front-loaded "Use when..." triggers with specific user phrases
- "Be slightly pushy" framing for skills with auto-fire scenarios
  (per Anthropic's "make sure to use this skill whenever the user mentions...")
- ≤1024 chars per description
- Quoted YAML strings (avoids YAML parsing edge cases on colons/quotes)
"""
import pathlib, re, sys

ROOT = pathlib.Path("/home/tom/development/blitz/skills")

# New descriptions keyed by skill name.
# Goal: every description starts with the action, names what it produces,
# then has explicit trigger phrases the user might type. For high-value
# auto-fire skills, include "even if not explicitly asked" framing.
DESCS = {
    # ─── Orchestrators (user-invocable; description shows in /help picker) ───
    "ask": "Routes a vague or underspecified request to the right blitz skill(s) by classifying intent and asking targeted clarifying questions. Use when the user describes work but doesn't pick a skill — e.g., 'I want to add a feature', 'help me clean this up', 'where do I start with X'. Especially valuable for new users who don't yet know the blitz skill catalog.",

    "next": "Reads current project, sprint, and carry-forward state and tells the user what action to take next (run sprint-plan, resume sprint-dev, ship, address a registry escalation, etc.). Use when the user asks 'what should I do next?', 'where are we?', 'is anything blocked?', or just '/blitz:next'. Always cite the specific blitz command to run.",

    "quick": "Makes a small ad-hoc change (typo, one-line fix, single-file tweak) without the full sprint ceremony. Use when the user describes a tiny scoped change like 'fix the typo in X', 'change Y to Z in file foo', 'rename this var', 'tweak this string'. Do NOT use for multi-file refactors, new features, or anything that needs tests — those go through sprint-dev or refactor.",

    "health": "Validates plugin structural integrity: hooks executable + valid hooks.json, no stale sessions or orphan locks, activity feed under threshold, every SKILL.md passes the canonical frontmatter lint. Use when the user reports a hook misfiring, a session collision warning, an unfamiliar lock file, or simply asks 'is the plugin healthy?'. Run after any /blitz:setup or hook config change.",

    "sprint": "Orchestrates the full sprint cycle (plan → implement → review). Use when the user says 'run a sprint', 'do a full sprint', or invokes --loop for autonomous reconciliation. The --loop mode is the canonical entry point for fully autonomous, multi-tick sprint progression.",

    "implement": "Runs the implementation phase of a sprint by routing to sprint-dev. Use when the user says 'implement sprint N', 'develop these stories', or 'resume sprint'. Skip planning and review — those are separate skills.",

    "review": "Runs the review phase of a sprint by routing to sprint-review. Use when the user says 'review sprint N', 'run quality gates', 'check the sprint', or asks to validate a completed sprint before shipping.",

    "ship": "Chains the full release workflow (sprint-review → completeness-gate → quality-metrics → release) with quality gates between each step. Use when the user says 'ship it', 'cut a release', 'release v1.X', or 'ready to ship'. Refuses to publish if any gate fails.",

    # ─── Sprint family (load-bearing; should fire on all sprint vocabulary) ───
    "sprint-plan": "Plans the next sprint from roadmap epics with research-backed stories. Reads the dependency graph, selects next unblocked epics, spawns research agents in parallel, generates per-story files with the canonical /_shared/story-frontmatter.md schema, and creates GitHub issues. Use when the user says 'plan sprint', 'generate stories', 'plan next sprint', 'sprint planning', or '--gaps' for gap-closure mode. Hard-fails at Phase 0.0 if roadmap-registry.json is missing.",

    "sprint-dev": "Implements planned sprints with coordinated agent teams. Spawns backend-dev, frontend-dev, and test-writer agents in isolated worktrees, distributes stories as tasks with dependency-ordered waves, and monitors progress via the Monitor tool. Use when the user says 'implement sprint', 'develop stories', 'start coding', 'work the sprint', or 'resume sprint' (with STATE.md). Hard-fails at Phase 0.0 if the sprint manifest or stories are missing.",

    "sprint-review": "Reviews sprint quality with automated gates (type-check, lint, tests, build) and parallel reviewer agents (security, backend, frontend, patterns). Auto-fixes safe categories (types, lint, imports). Enforces the carry-forward registry hard gate (Phase 3.6 Invariants 1-5). Use when the user says 'review sprint', 'check quality', 'run review', 'sprint quality gate', or 'audit sprint'.",

    # ─── Core dev skills ───
    "bootstrap": "Scaffolds new projects, features, or packages with project conventions auto-detected. Distinguishes greenfield (creates package.json, src/, docs/, empty roadmap stubs) from existing projects (adds to existing structure). Use when the user says 'bootstrap', 'scaffold', 'init a new project', 'set up a Vue/Nuxt/Firebase project', 'create a new package'. Required first step in the greenfield pipeline before /blitz:research and /blitz:roadmap.",

    "research": "Investigates libraries, APIs, cloud services, frameworks, and architecture patterns. Spawns parallel research agents (domain, library, codebase, optional infra), produces a structured docs/_research/<date>_<topic>.md with quantified scope: YAML frontmatter for /blitz:roadmap to ingest. Use when the user says 'research X', 'investigate', 'compare options', 'what's the best approach for', 'evaluate library Y', or just '/blitz:research <topic>'. Always run before sprint-plan when adopting new tech.",

    "roadmap": "Generates phased implementation roadmaps from research documents. Extracts capabilities and quantified scope: blocks, assesses codebase state, clusters features into epics, resolves dependencies, and writes roadmap-registry.json + epic-registry.json + carry-forward.jsonl 'created' lines. Use when the user says 'generate roadmap', 'plan phases', 'roadmap status', 'extend roadmap', or after /blitz:research produces a new doc. Required before /blitz:sprint-plan.",

    "fix-issue": "Resolves GitHub issues end-to-end: fetches issue context via gh CLI, researches root cause, implements fix with regression tests, and updates the issue with a closing comment. Use when the user says 'fix issue #N', 'resolve issue', 'work on issue', 'pick up issue', or pastes a GitHub issue URL. Independent of sprint-dev — for one-off bugs not in the sprint plan.",

    "refactor": "Performs safe, incremental refactoring with test verification after every step. Snapshots test results, refactors one piece at a time, and reverts if any test that was passing starts failing. Use when the user says 'refactor', 'extract', 'simplify', 'decompose', 'rename', 'restructure', or 'clean up'. NOT for behavior changes — those go through sprint-dev or fix-issue.",

    "test-gen": "Generates tests for target files matching the project's existing test conventions (Vitest/Jest, AAA/BDD style, factory patterns). Analyzes untested functions, edge cases, and error paths. Runs each generated test to verify it passes. Use when the user says 'add tests', 'generate tests for', 'test coverage', 'write tests', 'cover this file with tests'. Especially valuable after sprint-dev completes if test coverage gaps remain.",

    "ui-build": "Researches the codebase's design patterns (component library, layout system, design tokens, accessibility conventions) then generates production-grade Vue 3 UI that feels native to the project. Runs a 5-phase workflow (Discover → Analyze → Design → Implement → Refine). Use when the user says 'build a page', 'create UI', 'add a form', 'design component', 'build UI for X', 'add a screen for Y'.",

    "browse": "Automated browser testing, site crawling, and visual analysis via Playwright MCP. Navigates pages, clicks safe interactive elements, captures console errors, failed network requests, and screenshots. Classifies findings (Critical/Error/Warning) and optionally auto-fixes source issues. Loop-safe: one page per tick, builds navigational hierarchy, performs cross-page consistency analysis. Use when the user says 'test pages', 'smoke test', 'check console errors', 'browse test', 'crawl site', 'check design', 'visual audit', 'click through the app'.",

    "codebase-map": "Builds a CODEBASE-MAP.md for brownfield project onboarding by analyzing 4 dimensions: Technology (stack/deps/build), Architecture (modules/layers/data flow), Quality (test coverage, lint debt, complexity hotspots), and Concerns (security/perf/correctness risks). Use when the user says 'map the codebase', 'analyze this project', 'help me understand this code', 'I just inherited this repo', or starts working in an unfamiliar codebase. Should run automatically when no CODEBASE-MAP.md exists in a brownfield project.",

    "todo": "Tracks development ideas, follow-up items, and technical debt discovered mid-task. Modes: add, list, check, resolve. Stores in .cc-sessions/todos.jsonl with file:line context. Use when the user says 'todo: X', 'remember to X', 'add a todo', 'what's on my todo list', 'todos for this sprint', or when Claude itself surfaces a follow-up that shouldn't become a stale TODO comment in code.",

    # ─── Quality / audit ───
    "code-sweep": "Iterative code-quality improvement with /loop support. Discovers conventions from the codebase, defines standards, and progressively aligns code via 30 checks across 7 categories plus dynamic standards. Ratchet mechanism ensures quality only improves (never regresses). Use when the user says 'sweep', 'cleanup', 'improve code', 'code quality pass', 'find TODOs', 'remove dead code', 'enforce standards', or wants a continuous improvement loop running.",

    "code-doctor": "Framework-API correctness audit for Firestore, VueFire, Vue 3, and Pinia. Detects anti-patterns, misuse, dead exports, and duplication candidates. Read-only by default; --fix applies low-risk auto-fixes only (never mutates business logic). Use when the user says 'code-doctor', 'audit firestore', 'check api usage', 'find misuse', 'check vuefire', 'pinia anti-patterns', 'firestore best practices', or starts seeing framework-API warnings in logs.",

    "codebase-audit": "Comprehensive 5-pillar code-quality audit (Architecture, Performance, Security, Maintainability, Robustness). Spawns 10 parallel agents (2 per pillar) for thorough analysis. Produces findings formatted for /blitz:roadmap and /blitz:sprint-plan ingestion. Use when the user says 'audit codebase', 'full code review', 'comprehensive quality audit', 'health of this codebase', 'find tech debt', 'security audit', or before a major release.",

    "completeness-gate": "Scans code for placeholder patterns (TODO/FIXME/STUB/PLACEHOLDER), incomplete implementations (`return {}`, `throw new Error('Not implemented')`), and other production-readiness issues. Returns structured findings with file:line refs. Use when the user says 'check completeness', 'scan for placeholders', 'find unfinished code', 'production readiness', or as an automatic gate before /blitz:ship.",

    "quality-metrics": "Collects, stores, and visualizes code-quality metrics over time (test counts, lint debt, cyclomatic complexity, dependency health, type-error trends). Modes: collect, dashboard, trend, compare. Use when the user says 'quality metrics', 'metrics dashboard', 'show trends', 'compare sprints', 'quality over time', or as a post-sprint observability snapshot in /blitz:ship.",

    "ui-audit": "Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts a labeled value registry from rendered pages, asserts invariants across them (same field shows same value, same role shows same nav, no role leaks), flags placeholders / nulls / flapping values. Read-only. Loop-safe. Reads /blitz:browse crawl state if present. Use when the user says 'audit consistency', 'check cross-page data', 'ui-audit', 'data drift', 'invariants', 'role leak', 'placeholder text on screen', 'broken UI'.",

    "dep-health": "Audits npm dependencies for known vulnerabilities (npm audit), outdated versions, and license compliance. Modes: audit (read-only scan), upgrade (interactive bumps), report (CSV/JSON output). Use when the user says 'check deps', 'dep-health', 'audit dependencies', 'security vulnerabilities', 'outdated packages', 'license check', or as a recurring weekly sweep.",

    "perf-profile": "Profiles bundle size, runtime performance (Web Vitals), and Lighthouse scores for Vue/Nuxt apps. Identifies optimization opportunities (large deps, unused exports, render bottlenecks). Use when the user says 'profile perf', 'lighthouse', 'bundle size', 'performance', 'why is this slow', 'optimize Vue/Nuxt'.",

    "integration-check": "Validates cross-module wiring on the current code: export-to-import tracing (are new exports actually consumed?), route coverage (do new pages have navigation entries?), auth guard coverage, store-to-component wiring. Read-only analysis. Use when the user says 'integration check', 'check wiring', 'audit imports', 'unused exports', 'orphan routes', or invoked by /blitz:sprint-dev Phase 3.5.0 after implementation.",

    # ─── Docs / release ───
    "doc-gen": "Generates API docs, component docs, architecture diagrams (Mermaid), and CHANGELOG entries from source code and conventional commits. Modes: api, components, architecture, changelog, full. Use when the user says 'generate docs', 'doc-gen', 'API documentation', 'component docs', 'architecture diagram', 'auto-changelog', or when source code is ahead of docs/.",

    "release": "Manages semantic versioning, changelogs, and GitHub releases. Modes: prepare (compute version + draft CHANGELOG), verify (run all gates), publish (tag + push + npm publish if configured), rollback (revert + delete tag). Use when the user says 'release v1.X', 'cut a release', 'publish release', 'tag and ship', 'rollback release'. Composed by /blitz:ship as the final step.",

    "migrate": "Handles framework, library, and tooling migrations with incremental safety. Researches breaking changes, plans atomic migration steps, and verifies after each step (type-check + tests). Use when the user says 'migrate to', 'upgrade to Vue 3', 'Pinia from Vuex', 'Nuxt 2→3', 'replace X with Y', 'breaking change upgrade'. Refuses to proceed if any verification step fails.",

    # ─── Meta ───
    "compress": "Rewrites a markdown or plain-text file into terse form to reduce input tokens when the file is loaded. Preserves code, URLs, paths, commands, headings, tables, YAML, and JSON verbatim. Writes a .original backup before modifying the source. Use when the user says 'compress this file', 'shrink this doc', 'reduce tokens in <file>', 'make this terse', or when a research doc / SKILL.md gets too long.",

    "retrospective": "Analyzes completed sessions to identify improvement patterns. Reads activity-feed entries, session reports, and git diff to surface recurring friction. Generates proposals for plugin self-improvement classified by safety (auto-apply, propose-only, never-auto-apply). Use when the user says 'retrospective', 'what did we learn', 'session analysis', 'improve the plugin', 'find friction patterns'.",

    "setup": "Detects conflicts between the user's CLAUDE.md files and blitz skill behaviors. Reads global and project CLAUDE.md scopes, matches rules against a known-conflict catalog, and reports severity-graded findings with remediation suggestions. Validates tool permissions and stack assumptions. Use when the user installs blitz in a new project, after adding CLAUDE.md rules, or when sprint-dev/code-sweep/ui-audit behave unexpectedly. Should run automatically the first time blitz is invoked in a project.",
}


def main():
    files = sorted(ROOT.glob("*/SKILL.md"))
    too_long = []
    changed = 0
    for f in files:
        name = f.parent.name
        if name not in DESCS:
            print(f"  ! no rewrite for {name}", file=sys.stderr)
            continue
        new_desc = DESCS[name]
        if len(new_desc) > 1024:
            too_long.append((name, len(new_desc)))
            continue
        text = f.read_text()
        # Replace the description line in the frontmatter (handles quoted + unquoted).
        new_text, count = re.subn(
            r'^description:\s*"[^"]*"\s*$',
            f'description: "{new_desc}"',
            text, count=1, flags=re.M,
        )
        if count == 0:
            # try unquoted form
            new_text, count = re.subn(
                r'^description:[^\n]*$',
                f'description: "{new_desc}"',
                text, count=1, flags=re.M,
            )
        if count == 0:
            print(f"  ! could not match description in {name}", file=sys.stderr)
            continue
        if new_text != text:
            f.write_text(new_text)
            changed += 1
            print(f"  ✓ {name} ({len(new_desc)} chars)")
    print(f"\nUpdated {changed} descriptions.")
    if too_long:
        print(f"OVER 1024 cap: {too_long}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
