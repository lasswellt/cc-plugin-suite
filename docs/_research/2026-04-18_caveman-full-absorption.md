---
scope:
  - id: cf-2026-04-18-compress-safe-references-wave2
    unit: files
    target: 7
    description: |
      Compress the remaining 7 SAFE reference.md files that were uncompressed
      after S1-005: doc-gen, perf-profile, roadmap, completeness-gate,
      bootstrap, setup, fix-issue. Each must pass the structural validator
      and ship with a `.original` backup committed alongside.
    acceptance:
      - shell: "test -f skills/doc-gen/reference.md.original"
      - shell: "test -f skills/perf-profile/reference.md.original"
      - shell: "test -f skills/roadmap/reference.md.original"
      - shell: "test -f skills/completeness-gate/reference.md.original"
      - shell: "test -f skills/bootstrap/reference.md.original"
      - shell: "test -f skills/setup/reference.md.original"
      - shell: "test -f skills/fix-issue/reference.md.original"
      - shell: "bash hooks/scripts/reference-compression-validate.sh"
  - id: cf-2026-04-18-compress-research-docs
    unit: files
    target: 12
    description: |
      Compress 12 existing `docs/_research/*.md` files. Prose-dense, rarely
      loaded but loaded in full when referenced; largest unaddressed prose
      surface in the repo. Each must pass the structural validator.
    acceptance:
      - shell: "test $(find docs/_research -name '*.md.original' | wc -l) -ge 12"
      - shell: "bash hooks/scripts/reference-compression-validate.sh"
  - id: cf-2026-04-18-terse-directive-agents
    unit: files
    target: 6
    description: |
      Add the `/_shared/terse-output.md` Additional-Resources reference to
      each of the 6 agent definition files under `agents/` (architect,
      backend-dev, doc-writer, frontend-dev, reviewer, test-writer). Agents
      load these on every spawn; currently 0/6 carry the directive.
    acceptance:
      - grep_present:
          pattern: 'terse-output'
          min: 6
  - id: cf-2026-04-18-terse-directive-skill-gap
    unit: files
    target: 6
    description: |
      Add `/_shared/terse-output.md` reference to the 6 remaining substantive
      SKILL.md files currently lacking it: ask, sprint, ship, next, health,
      todo. (implement, review, quick remain exempt as genuinely thin
      orchestrators.)
    acceptance:
      - grep_present:
          pattern: '/_shared/terse-output.md'
          min: 31
  - id: cf-2026-04-18-terse-directive-shared-protocols
    unit: files
    target: 10
    description: |
      Add a "Related protocols" pointer to `/_shared/terse-output.md` from the
      10 remaining shared protocol files that govern output-bearing behavior:
      verbose-progress, session-protocol, checkpoint-protocol,
      context-management, deviation-protocol, definition-of-done, scheduling,
      carry-forward-registry, session-report-template, spawn-protocol (already
      references, verify). Ensures consistent directive discoverability.
    acceptance:
      - grep_present:
          pattern: 'terse-output'
          min: 11
  - id: cf-2026-04-18-agent-prompt-boilerplate
    unit: files
    target: 1
    description: |
      Extract reused agent-prompt boilerplate (HEARTBEAT spec, PARTIAL
      protocol, weight-class caps) into a single shared fragment at
      `skills/_shared/agent-prompt-boilerplate.md`, then refactor the 7 UNSAFE
      reference.md files (codebase-audit, codebase-map, code-sweep,
      integration-check, quality-metrics, sprint-dev, sprint-plan) to
      reference the shared fragment instead of reprinting verbatim.
      Targets 20-30% reduction on the ~12 K tokens/sprint spent on prompt
      templates.
    acceptance:
      - shell: "test -f skills/_shared/agent-prompt-boilerplate.md"
      - grep_present:
          pattern: 'agent-prompt-boilerplate'
          min: 7
  - id: cf-2026-04-18-output-intensity-profile
    unit: files
    target: 1
    description: |
      Add `output_intensity: lite|full|ultra` field to developer-profile.json
      schema and implement respect in at least one orchestrator skill (e.g.,
      sprint-dev) so agent-spawn directives interpolate the active intensity
      into the terse-output instruction. Default remains `lite`. Env-var
      override: `BLITZ_OUTPUT_INTENSITY`.
    acceptance:
      - grep_present:
          pattern: 'output_intensity'
          min: 2
      - shell: "grep -q 'BLITZ_OUTPUT_INTENSITY' skills/_shared/terse-output.md || grep -q 'BLITZ_OUTPUT_INTENSITY' skills/_shared/spawn-protocol.md"
  - id: cf-2026-04-18-task-type-gating
    unit: files
    target: 5
    description: |
      Mark 5 reasoning-heavy skills as terse-output-exempt (or set to `lite`
      intensity with explicit Auto-Clarity expansion) to avoid brevity-induced
      accuracy degradation per Hakim 2026 + Renze 2024 + Prompt-Compression-
      in-the-Wild. Targets: completeness-gate, codebase-audit, research,
      retrospective, bootstrap. Each SKILL.md frontmatter gains an
      `output_style_policy:` field or inline directive noting the exemption.
    acceptance:
      - grep_present:
          pattern: 'output_style_policy|reasoning-heavy|terse-exempt'
          min: 5
  - id: cf-2026-04-18-review-format-absorption
    unit: files
    target: 2
    description: |
      Adopt the caveman-review comment-format pattern (`L<line>: <severity>
      <problem>. <fix>.` with 🔴/🟡/🔵/❓ severity prefixes, LGTM-and-stop
      rule, auto-clarity for security/CVE findings) into `skills/review/` and
      `skills/sprint-review/`. Update both skills' reference.md (not SKILL.md
      — the reference sections are where the output-format spec lives).
    acceptance:
      - grep_present:
          pattern: 'L<line>|🔴 bug|🟡 risk|🔵 nit|LGTM'
          min: 4
---

# Research: Full Absorption of Caveman Concepts into Blitz

**Date:** 2026-04-18
**Topic:** Complete absorption of every reusable concept from https://github.com/JuliusBrussee/caveman into blitz, with zero runtime dependency, across inputs and outputs.
**Research type:** Feature Investigation + Architecture Decision
**Session:** cli-74cfb97c
**Supersedes / extends:** `docs/_research/2026-04-16_caveman-token-minimization.md` (output directive, done), `docs/_research/2026-04-16_caveman-compress-input-side.md` (reference.md compression, 10/12 done).

---

## Summary

Prior work absorbed two of caveman's surfaces: the output-style directive (`skills/_shared/terse-output.md`) and author-time `reference.md` compression (10 files under S1-005). This pass catalogs the remaining absorbable surfaces — agent-definition coverage, shared-protocol discoverability, review-format specialization, agent-prompt boilerplate dedup, intensity-mode persistence, task-type gating, and a further wave of file compression against `docs/_research/` and 7 remaining SAFE reference.md. **Crucially, web research surfaced strong counter-evidence against aggressive brevity**: the real effect is 15-25% cost reduction (not 75%), brevity actively degrades code-generation and weak-model math reasoning, and caveman itself has 8+ open issues around activation reliability and cross-session state conflicts.

**Recommendation:** Absorb the remaining safe patterns (review format, boilerplate dedup, compression wave, directive coverage). Gate terse-output by task type — ON for mechanical skills, OFF for reasoning-heavy. Do NOT adopt runtime/proxy compression, the wenyan mode, or multi-editor distribution. Persist intensity in `developer-profile.json` rather than building caveman's flag-file + JS-hook apparatus (blitz's per-session `.cc-sessions/` infra is already richer). Cite Hakim 2026 for design justification but calibrate public claims to the 15-25% measured band — avoid caveman's credibility-damaging 75% claim.

---

## Research Questions & Answers

| Question | Answer |
|---|---|
| What concepts from caveman has blitz NOT absorbed yet? | Nine: (1) per-turn reinforcement hook; (2) review-format specialization; (3) commit-format specialization (low value); (4) remaining SAFE-file compression wave; (5) agent-definition directive coverage; (6) shared-protocol directive coverage; (7) agent-prompt boilerplate dedup; (8) persisted intensity mode; (9) task-type gating. Catalog detail in Finding 1. |
| Does the brevity-constraints paper support blitz's direction? | Partially. Hakim 2026 shows brevity helps on 7.7% of benchmark problems (+26 pp on that subset) — not a universal win. Renze 2024 shows brevity HURTS GPT-3.5 on math (-27.69 pp). Prompt Compression in the Wild shows code-gen degrades even under slight compression. Terse-output is a subset intervention, not a global one. |
| What are caveman's actually measured savings, independent of its marketing? | Pillitteri (independent review): 4-10% real session savings, 15-25% on full API costs. 75% marketing claim is prose-subset-only. Don't overclaim. |
| Which caveman failure modes does blitz structurally avoid? | Concurrent-session flag-file conflicts (caveman #184): blitz's per-session `.cc-sessions/${SESSION_ID}/` avoids this by design. Windows+git-bash hook failures: blitz hooks are bash-only, no JS. Global-state leaks on `~/.claude/`: blitz state is repo-scoped. |
| What's the remaining leverage in absolute tokens? | ~25-40 KB from docs/_research/ compression (12 files). ~4-9 KB from 7 remaining SAFE reference.md. ~20-30% on ~12 K tokens/sprint from agent-prompt boilerplate dedup (~2.5-3.5 K tokens saved per sprint). Indirect savings from directive coverage on 6 agent files + 6 SKILL.md + 10 shared protocols (high-frequency, hard to quantify). |
| What should be gated off from terse-output entirely? | Reasoning-heavy skills: completeness-gate, codebase-audit, research, retrospective, bootstrap. Evidence: Renze 2024 (math degradation), Prompt Compression in the Wild (code-gen harm), Pillitteri ("turn OFF for architecture/learning/debugging unknowns"). |

---

## Findings

### Finding 1 — Full catalog of caveman surfaces and absorption status

Source: library-docs agent deep-dive of the caveman repo at commit 84cc3c14.

| Caveman surface | What it is | Blitz status | Absorb? |
|---|---|---|---|
| `rules/caveman-activate.md` short form | 15-line activation directive | Absorbed as `skills/_shared/terse-output.md` | **DONE** |
| Intensity levels (lite/full/ultra) | Three escalating compression tiers | Absorbed in `terse-output.md` | **DONE** |
| `caveman-compress` author-time Python tool | File compressor with validator retry | Absorbed as `skills/compress/` + `hooks/scripts/reference-compression-validate.sh` | **DONE** (partial — 10/17 SAFE files compressed) |
| `/caveman-help` one-shot reference card | Compressed skill index | Not needed — blitz already has `/blitz:next` and `/blitz:health` | **SKIP** |
| Wenyan mode (文言文) | Classical Chinese compression | Novelty; low ROI for engineering audience | **SKIP** |
| `hooks/caveman-activate.js` (SessionStart) | Writes flag, injects directive | Blitz's `session-start.sh` could emit intensity line but current value is marginal | **MAYBE** (§Rec-9) |
| `hooks/caveman-mode-tracker.js` (UserPromptSubmit, per-turn) | Re-anchors directive every turn despite competing plugin noise | No blitz equivalent; requires JS or Python hook; blitz hooks are all bash today | **MAYBE** (§Rec-9) |
| Dynamic SKILL.md filtering | Runtime-strip non-active intensity rows before inject | Interesting but requires runtime hook; skip for now | **SKIP** |
| Statusline badge | ANSI orange `[CAVEMAN:MODE]` | Blitz has no statusline; optional future addition | **SKIP** |
| Flag-file + whitelist + symlink-safe + 0600 atomic write | Security-hardened state file pattern | Blitz state files (`.cc-sessions/*.json`) don't currently follow this pattern; worth adopting | **YES** (§Rec-10) |
| `CAVEMAN_DEFAULT_MODE=off` env override | User escape hatch | Blitz should add `BLITZ_OUTPUT_INTENSITY` | **YES** (§Rec-4) |
| Auto-Clarity rule (drop terse for security/irreversible/confused-user/multi-step) | Model-side self-override | Absorbed in `terse-output.md` §Auto-pause | **DONE** — verify full list present |
| `caveman-commit` SKILL | Commit-message format rules | Blitz commits already ≤61 avg chars; dedicated skill has ~400 token lifetime savings | **SKIP** |
| `caveman-review` SKILL | `L<line>: <severity> <problem>. <fix>.` with 🔴/🟡/🔵/❓ | Blitz sprint-review output format would benefit | **YES** (§Rec-5) |
| Three-arm eval methodology (baseline / terse-control / skill) | Honest benchmarking | Blitz should import this pattern for any future quality/perf claims | **YES** (§Rec-7) |
| Multi-editor distribution (Cursor/Windsurf/Cline/Codex/Gemini/Copilot) | CI-synced rule files | Out of scope — blitz is Claude-Code-specific | **SKIP** |
| Honest marketing / three-arm-eval against self-inflation | Philosophy | Good import for blitz docs | **YES** (§Rec-8) |
| Hakim 2026 arxiv paper citation | Justifies brevity as accuracy intervention | Cite in terse-output.md with caveats from Renze 2024 | **YES** (§Rec-1) |

### Finding 2 — The brevity literature is split; absorption must respect task type

Sources: web-researcher.

- **Hakim 2026** (arXiv:2604.00025): 31 models, 1,485 problems. Brevity helps on **7.7% of problems** (+26 pp). Reverses hierarchy on math/science (large models gain 7.7-15.9 pp when terse). Does NOT claim universal improvement.
- **Renze & Guven 2024** (arXiv:2401.05618): GPT-3.5 + concise CoT on math = **-27.69% accuracy**. GPT-4 unaffected. Brevity is **model-capability-dependent**.
- **Prompt Compression in the Wild** (arXiv:2604.02985): code generation "degrades even under slight compression". Few-shot classification drops 52%. Overhead often dominates savings on modern serving stacks (vLLM, commercial APIs).
- **Anthropic's own guidance** (`effective-context-engineering-for-ai-agents`): supports "smallest possible set of high-signal tokens" AND explicitly cautions against "overly aggressive compaction causing information loss".
- **Pillitteri independent review of caveman**: keep ON for refactor/mechanical/background agents; turn OFF for learning frameworks, architectural decisions, debugging unknowns, shared outputs. Formal proofs + complex math degrade under full/ultra.

**Actionable conclusion**: Gate terse-output by task type. Five blitz skills should be exempt or at `lite`-only: `completeness-gate`, `codebase-audit`, `research`, `retrospective`, `bootstrap`. Mechanical skills (`sprint-dev`, `code-sweep`, `test-gen`, `refactor`, `ui-build`, `migrate`) can default to `full`. `/blitz:compress` itself stays at `full` as the canonical reference.

### Finding 3 — Caveman's measured savings are 15-25%, not 75%

Source: web-researcher, Pillitteri.

Caveman's headline "cuts ~75% of tokens" is **output-token, prose-only**. Once thinking tokens, input context, and system prompt are counted:

| Measurement | Savings |
|---|---|
| Marketing claim | 75% |
| Actual prose-only output reduction | 61-68% |
| Full session (input + thinking + output) | 4-10% |
| Full API cost (with Sonnet + prompt caching) | 15-25% (Pillitteri) |
| Combined with Sonnet + caching | up to 50% (edge case) |

**Implication for blitz**: if we ship metrics, calibrate to the 15-25% band. Don't repeat caveman's credibility error. The current sprint-1 result of -3.26% aggregate on reference.md compression is consistent with this band — it's table/code-dense, so the prose share is lower than caveman's test corpus.

### Finding 4 — Agent-definition and shared-protocol coverage gap

Source: codebase-analyst.

| Surface | Total files | Terse-directive coverage |
|---|---|---|
| `agents/*.md` | 6 | 0/6 |
| `skills/_shared/*.md` | 11 | 1/11 (spawn-protocol.md) |
| `skills/*/SKILL.md` | 34 | 25/34 (6 substantively missing) |

Agent definition files are loaded every time `Agent(subagent_type: blitz:…)` spawns — high frequency. Currently **none** carry the terse directive. Fixing this is the highest-leverage directive-injection work.

Shared protocols govern output-bearing behavior (`verbose-progress.md`, `session-report-template.md`, `definition-of-done.md`) but don't cross-reference `terse-output.md`. Adding a "Related protocols" footer is low-effort, improves discoverability.

### Finding 5 — UNSAFE reference.md boilerplate is duplicated; dedup is feasible

Source: codebase-analyst.

Seven reference.md files contain exact-match agent prompt templates totaling ~3,118 lines. They cannot be author-time compressed (the prompts must match verbatim). But they **redundantly** reprint the same boilerplate: HEARTBEAT specification, PARTIAL protocol, weight-class cap tables, session-registration instructions. A shared fragment at `skills/_shared/agent-prompt-boilerplate.md`, imported (via `<!-- import: ... -->` marker or explicit Read instruction) by each template, would save an estimated 20-30% per template.

Per sprint-dev run: ~610 lines of prompt-template input × ~80 chars/line ÷ ~4 chars/token ≈ 12 K tokens of prompt-template input. Dedup savings: ~2.5-3.5 K tokens per sprint, repeated across every spawn wave.

### Finding 6 — Blitz structurally avoids caveman's worst bugs

Source: web-researcher (caveman issues list) + codebase-analyst (blitz session infra).

| Caveman failure mode | Blitz status |
|---|---|
| Global `~/.claude/.caveman-active` flag → concurrent-session conflicts (#184) | Blitz state is per-session under `.cc-sessions/${SESSION_ID}/`. No conflict surface. |
| Windows + git-bash JS hook failures (#199) | Blitz hooks are bash scripts; no JS runtime dependency. |
| `safeWriteFlag` refuses symlinked `~/.claude` (#207) | Blitz state is inside the repo, not `~/.claude`. |
| Activation persistence drops mid-session | Blitz doesn't require cross-turn persistence for terse-output; directive is referenced from SKILL.md and injected into every Agent() prompt. |
| Cursor/Copilot/Cowork cross-client breakage | Blitz is Claude-Code-only; no multi-agent port surface. |

These are structural advantages worth documenting as differentiators — they come "for free" from blitz's existing design and shouldn't be eroded by future absorption work.

### Finding 7 — Commit and PR compression is not worth shipping

Source: codebase-analyst git audit.

Blitz commit history: 74 commits, avg subject 60.8 chars, already using conventional-commits with scope. A `/blitz:commit-style` skill would save ~400 tokens over the repo's lifetime and risks stripping body context that retrospectives and sprint-reviews rely on. **Skip.**

Blitz has 0 GitHub PRs (direct push to main). No absorption surface exists. If the workflow changes to include PRs, a `/blitz:pr-describe` skill becomes interesting — but that is new-feature territory, not caveman absorption.

### Finding 8 — Blitz has richer mode-state infra than caveman; no new hooks needed

Source: codebase-analyst.

Blitz already tracks:

- `.claude-plugin/model-profiles.json` — active profile (quality/balanced/budget)
- `.cc-sessions/developer-profile.json` — per-user preferences
- `.cc-sessions/${SESSION_ID}.json` — session state
- `.cc-sessions/activity-feed.jsonl` — cross-session log
- `.cc-sessions/${SESSION_ID}-workflow.json` — workflow guard input

Adding `output_intensity: lite|full|ultra` to `developer-profile.json` (with optional `BLITZ_OUTPUT_INTENSITY` env override) is sufficient for per-user + per-session preference. **No new hook required.** Contrast with caveman's ~200 lines of JS hook code + flag file + statusline; blitz gets equivalent behavior by extending existing infra.

---

## Compatibility Analysis

| Dimension | Result |
|---|---|
| Plugin coexistence | Clean — blitz never runs caveman at runtime; even if a user installs both, per-turn directives compose (with some attention-split overhead, same as any two-plugin install). |
| License | MIT ↔ MIT. Compatible. All concepts re-implemented, no caveman code imported. |
| Existing blitz infra | Extended, not replaced. `terse-output.md` exists; this pass fills directive-coverage gaps. `developer-profile.json` gains one field. No migrations required. |
| Structural validator | Already in place (`hooks/scripts/reference-compression-validate.sh`). Handles all wave-2 compression targets. |
| Hook count | Unchanged. No new hooks. Existing sprint-review WARNING on missing terse-snippet remains the enforcement layer. |
| Commit conventions | Unchanged. Commit-compression skill skipped (Finding 7). |
| Per-session safety | Improved. Adopting caveman's whitelist/symlink-safe pattern for any new state files is a defensive upgrade; blitz doesn't currently violate this but should document the pattern for future writers. |
| Upstream caveman drift | N/A. Blitz owns its own copy of every absorbed concept; caveman's releases cannot break blitz. |

---

## Recommendation

**Absorb the remaining safe patterns in a phased rollout, preserving blitz's structural advantages (per-session state, no JS hooks, no multi-editor fan-out). Gate terse-output by task type. Calibrate public messaging to measured 15-25%, not 75%.**

### Priority matrix

| Item | Leverage | Effort | Risk | Priority |
|---|---|---|---|---|
| Compress 7 SAFE reference.md (wave 2) | +4-9 KB input per run | LOW | LOW (validator exists) | **HIGH** |
| Compress 12 docs/_research/*.md | +25-40 KB input per load | LOW | LOW | **HIGH** |
| Terse-directive on 6 agent files | High frequency, indirect | LOW | LOW | **HIGH** |
| Agent-prompt boilerplate dedup | ~2.5-3.5 K tokens/sprint | MED | MED (cross-file refactor) | **HIGH** |
| Terse-directive on 6 remaining SKILL.md | Indirect | LOW | LOW | MED |
| Terse-directive on 10 shared protocols | Indirect, discoverability | LOW | LOW | MED |
| Adopt caveman-review output format | Review clarity | LOW | LOW | MED |
| Persist `output_intensity` in dev profile | Enables gating + user override | LOW | LOW | MED |
| Task-type gating on 5 reasoning-heavy skills | Prevents accuracy degradation | MED | LOW | **HIGH** |
| Cite Hakim 2026 + Renze 2024 in terse-output.md | Design justification | LOW | LOW | LOW |
| Three-arm eval methodology doc | Honest future benchmarks | LOW | LOW | LOW |
| Per-turn reinforcement hook | Style anchoring | HIGH | MED (requires hook script) | SKIP FIRST PASS |
| Dynamic SKILL.md filtering | Runtime filter | HIGH | HIGH | SKIP |
| Statusline badge | UX | LOW | LOW | SKIP |
| `/blitz:commit-style` skill | ~400 tokens ever | LOW | MED | **SKIP** |
| Wenyan mode | Novelty | LOW | LOW | **SKIP** |
| Multi-editor distribution | Out of scope | HIGH | HIGH | **SKIP** |

### Design principles (durable)

1. **Terse-output is a subset intervention, not a global optimization.** Evidence: Hakim 2026 (7.7% of problems), Renze 2024 (weaker-model math degradation), Prompt-Compression-in-the-Wild (code-gen harm). Apply selectively.
2. **Claim 15-25%, not 75%.** Calibrate public docs and metric dashboards to measured outcomes. Audit sprint-review output for inflated claims.
3. **Author-time > runtime.** Compression that ships in the repo is reviewer-gated and deterministic; runtime/proxy compression (LLMLingua-class) adds overhead and can silently degrade code generation.
4. **Existing infra > new hooks.** Extend `developer-profile.json` and sprint-review WARNINGs before building caveman's flag-file + JS-hook apparatus.
5. **Preservation boundary is non-negotiable.** The UNSAFE list (7 reference.md files + code + JSON schemas + grep-pattern tables) must never receive author-time compression.

---

## Implementation Sketch

Phased, each phase shippable independently.

### Phase 1 — Directive coverage (low-risk, mechanical)

1. Add `/_shared/terse-output.md` reference to 6 agent files (`agents/architect.md`, `agents/backend-dev.md`, `agents/doc-writer.md`, `agents/frontend-dev.md`, `agents/reviewer.md`, `agents/test-writer.md`). Pattern: a single line near the top — "Output style: terse-technical per `/_shared/terse-output.md`."
2. Add the same reference to the 6 SKILL.md gap (`ask`, `sprint`, `ship`, `next`, `health`, `todo`). Leave `implement`, `review`, `quick` exempt (genuinely thin aliases).
3. Add "Related protocols: see `/_shared/terse-output.md`" footer to the 10 shared protocols currently lacking it.
4. Validate: `grep -l 'terse-output' agents/*.md skills/*/SKILL.md skills/_shared/*.md | wc -l` ≥ 31 + 6 + 10 = ≥ 47.

### Phase 2 — Compression wave 2 (author-time, validator-gated)

1. Invoke `/blitz:compress` on each of the 7 SAFE uncompressed reference.md files: doc-gen, perf-profile, roadmap, completeness-gate, bootstrap, setup, fix-issue. Expect 2-8% per file based on S1-005 range.
2. Invoke `/blitz:compress` on each of 12 `docs/_research/*.md` files. Expect 10-15% per file (higher prose density).
3. For each compressed file, commit both compressed + `.original`. Validator runs at commit time.
4. Measure total byte delta; expect ~25-50 KB aggregate reduction.

### Phase 3 — Agent-prompt boilerplate dedup

1. Read the 7 UNSAFE reference.md files (codebase-audit, codebase-map, code-sweep, integration-check, quality-metrics, sprint-dev, sprint-plan). Identify duplicated boilerplate sections: HEARTBEAT spec, PARTIAL protocol, weight-class caps, session-registration template.
2. Extract the shared sections to `skills/_shared/agent-prompt-boilerplate.md` — a new file containing the verbatim text each template was reprinting.
3. Replace the duplicated sections in each of the 7 reference.md files with a single-line import marker: `<!-- import: /_shared/agent-prompt-boilerplate.md -->`. The orchestrator skill that reads the reference.md must be updated to resolve the import at spawn time (Read the referenced file, splice the content into the Agent() prompt verbatim, then emit the combined prompt).
4. Verify: each Agent() spawn still receives byte-identical prompt text as before (the import resolution is mechanical, no rewriting).
5. Expected savings: 20-30% per template × ~12 K tokens/sprint input = ~2.5-3.5 K tokens saved per sprint-dev run.

### Phase 4 — Persisted intensity + task-type gating

1. Extend `developer-profile.json` schema to include `output_intensity: lite|full|ultra` (default `lite`). Respect env-var override `BLITZ_OUTPUT_INTENSITY`.
2. Update `skills/_shared/spawn-protocol.md` §7 to interpolate the active intensity into the Agent() prompt terse-snippet: `OUTPUT STYLE: terse-technical at <intensity> level per /_shared/terse-output.md. …`.
3. Mark 5 reasoning-heavy skills with an `output_style_policy:` frontmatter field set to `lite` or `reasoning-heavy` (override default). Targets: `completeness-gate`, `codebase-audit`, `research`, `retrospective`, `bootstrap`.
4. Update `terse-output.md` §Auto-pause to include the "reasoning-heavy skill active" case with a cite of Hakim 2026 and Renze 2024.

### Phase 5 — Review-format absorption

1. Read `skills/caveman-review/SKILL.md` verbatim for the severity-prefix + `L<line>:` format.
2. Rewrite `skills/review/reference.md` and `skills/sprint-review/reference.md` output-format sections to use the same pattern: `L<line>: <severity> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes, `LGTM` for clean code, auto-clarity for security/CVE findings (full prose, not terse).
3. Validate via sprint-review run on a real sprint — compare reviewer output readability before/after.

### Phase 6 — Evidence trail

1. Update `skills/_shared/terse-output.md` to cite:
   - Hakim 2026 (arXiv:2604.00025) — supporting evidence for brevity as accuracy intervention on the inverse-scaling subset.
   - Renze & Guven 2024 (arXiv:2401.05618) — counter-evidence on weaker-model math degradation.
   - Anthropic's `effective-context-engineering-for-ai-agents` — official guidance on "smallest set of high-signal tokens" paired with warning on "overly aggressive compaction".
2. Add a "Known limits" section listing the task-type exemption rationale.

### Phase 7 (optional) — Per-turn reinforcement hook

**Defer unless Phase 1-6 prove insufficient.** If user reports the terse directive "drifts" mid-conversation (caveman's known #184-class issue), consider a bash UserPromptSubmit hook that re-emits the terse-snippet. Blitz already has a hooks.json surface; the cost is one more hook script. But evidence from sprint-1 suggests the SKILL.md + agent-prompt injection is already persistent (no drift observed). Only revisit if measurement shows the need.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Compression damages a research doc during wave 2 | LOW | LOW | Structural validator runs on every pair; `/blitz:compress` auto-restores on validator failure |
| Agent-prompt boilerplate dedup breaks prompt parsing in an orchestrator | MED | HIGH | Implement import resolution mechanically (byte-identical splice); add a test that dumps the resolved prompt and diffs against pre-refactor capture |
| Task-type gating mis-classifies a skill | LOW | LOW | Conservative default (lite) for flagged skills; operator can escalate to full per invocation |
| `output_intensity` env var collides with a CI or user's environment | LOW | LOW | Prefix with `BLITZ_` (unique); document in README |
| Review-format absorption changes sprint-review output and breaks downstream parsing | MED | MED | Run sprint-review on a completed sprint before shipping; diff output against prior run; gate rollout behind a feature-flag field in developer-profile.json |
| Users expect caveman's 75% savings and get 15-25% | HIGH | LOW | Document honestly in release notes; link to this research doc's Finding 3 |
| Reasoning-heavy exemption leaves too much verbose output | MED | LOW | Allow per-invocation intensity escalation via CLI flag `/blitz:research --intensity=lite` |
| Wave-2 compression time exceeds operator patience (19 files) | LOW | LOW | `/blitz:compress` accepts multiple files; run in a loop or parallelize via `/loop` |
| Deduping boilerplate is reversed by future edits | LOW | LOW | Add a pre-commit hook that detects boilerplate reprints in UNSAFE reference.md |

**Open questions:**

- Should the per-turn reinforcement hook be built proactively, or only if drift is observed? **Recommended: wait for evidence.**
- Should the commit-style skill be shipped as an opt-in toggle for users who push high commit volumes, even if blitz's own cadence doesn't benefit? **No — leave it as a user's own concern; don't ship a ~400-token-lifetime feature.**
- Does the statusline pattern have any value for blitz's sprint-phase indication? **Defer; UX-only, no token impact.**
- Should Phase 5 (review-format) escalate to also modify `skills/review/SKILL.md` body, not just reference.md? **Reference.md only first; escalate if reviewer output still looks verbose.**

---

## References

**Caveman repo + artifacts:**
- https://github.com/JuliusBrussee/caveman (main)
- https://github.com/JuliusBrussee/caveman/blob/main/rules/caveman-activate.md
- https://github.com/JuliusBrussee/caveman/blob/main/skills/caveman/SKILL.md
- https://github.com/JuliusBrussee/caveman/blob/main/skills/caveman-commit/SKILL.md
- https://github.com/JuliusBrussee/caveman/blob/main/skills/caveman-review/SKILL.md
- https://github.com/JuliusBrussee/caveman/tree/main/caveman-compress
- https://github.com/JuliusBrussee/caveman/tree/main/hooks
- https://github.com/JuliusBrussee/caveman/tree/main/evals
- https://github.com/JuliusBrussee/caveman/issues (failure-mode catalog)

**Brevity-and-reasoning literature:**
- Hakim, MD Azizul. "Brevity Constraints Reverse Performance Hierarchies in Language Models." arXiv:2604.00025 (2026). https://arxiv.org/abs/2604.00025
- Renze & Guven. "The Benefits of a Concise Chain of Thought on Problem-Solving in LLMs." arXiv:2401.05618 (2024). https://arxiv.org/html/2401.05618v3
- "Prompt Compression in the Wild." arXiv:2604.02985 (2026). https://arxiv.org/html/2604.02985
- "To CoT or not to CoT?" arXiv:2409.12183 (2024). https://arxiv.org/html/2409.12183v1
- Jiang et al. "LLMLingua." EMNLP 2023. https://arxiv.org/abs/2310.05736

**Anthropic official:**
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://code.claude.com/docs/en/best-practices

**Community / independent reviews:**
- Pillitteri. "Claude Code Caveman Mode." https://pasqualepillitteri.it/en/news/846/claude-code-caveman-mode-token-saving
- anthropics/claude-code#33464 (native-compression feature request, Open). https://github.com/anthropics/claude-code/issues/33464
- drona23/claude-token-efficient. https://github.com/drona23/claude-token-efficient
- sliday/tamp (proxy-layer input+output compression). https://github.com/sliday/tamp
- thedotmack/claude-mem (session-memory compression). https://github.com/thedotmack/claude-mem

**Prior blitz research (this pass extends/supersedes):**
- `docs/_research/2026-04-16_caveman-token-minimization.md` — output-directive absorption (done)
- `docs/_research/2026-04-16_caveman-compress-input-side.md` — reference.md compression (10/17 done)
- `skills/_shared/terse-output.md` — current directive
- `skills/compress/SKILL.md` — current compressor
- `hooks/scripts/reference-compression-validate.sh` — current validator
- `sprints/sprint-1/STATE.md` — sprint-1 outcomes
- Session artifacts: `.cc-sessions/cli-74cfb97c/tmp/research/{library-docs,web-researcher,codebase-analyst}.md`
