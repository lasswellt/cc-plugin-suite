---
scope:
  - id: cf-2026-04-16-caveman-skill-directives
    unit: files
    target: 33
    description: |
      Inject caveman-style terse-output directive into every blitz SKILL.md
      (orchestrator-level) and into every Agent() prompt template, so model
      outputs (summaries, findings, review reports) are compressed without
      altering the SKILL.md body content. Covers 33 SKILL.md files under
      skills/ plus a shared directive snippet in skills/_shared/.
    acceptance:
      - grep_present:
          pattern: 'caveman|terse-output-mode|<!-- terse -->'
          min: 33
      - shell: "test -f skills/_shared/terse-output.md"
      - grep_absent: 'TODO.*caveman'
---

# Research: Integrating Caveman for Token Minimization Across Blitz Skills

**Date:** 2026-04-16
**Topic:** Integrate [caveman](https://github.com/JuliusBrussee/caveman) into the blitz plugin library to minimize tokens across every skill.
**Research type:** Library Evaluation + Architecture Decision
**Session:** cli-d7433704

---

## Summary

Caveman is a **prompt-style directive** (Claude Code skill + rules + hooks, 35K★ repo) that instructs the model to produce terse, technical output — claimed 65% avg output-token reduction across benchmarks. It is *not* a compression library with a programmatic API; there is nothing to import or call. Integrating it into blitz means adopting its activation pattern inside blitz's own skill prompts and agent templates.

**Critical clarification for the user's premise:** caveman affects **output tokens only** (what the model writes). Blitz's actual dominant token cost — per the codebase-analyst survey — is **input tokens** (SKILL.md bodies ~10K lines, shared protocols ~1.9K lines, reference.md files ~9.6K lines, agent prompt templates injected into 72+ Agent() spawns per sprint). Caveman does not compress inputs.

**Recommendation:** Partial adoption — add a shared `terse-output.md` directive, reference it from every SKILL.md, and inject it into every Agent() prompt. Skip bundling the full caveman plugin as a dependency. Pair with a separate input-compression workstream (not caveman) for the larger ~60K-line context bloat.

---

## Research Questions & Answers

| Question | Answer |
|---|---|
| What is caveman technically? | A Claude Code plugin: activation rule (`rules/caveman-activate.md`), 4 sub-skills (caveman, caveman-commit, caveman-review, caveman-compress), status-line hooks (JS), install scripts. Runtime behavior = injected system directive. |
| Does it expose an API blitz can call? | No. No library, no preprocessor, no callable function. Mechanism is "mode activation" via slash command / natural language / system-prompt injection. |
| What does it actually compress? | Model output: drops articles, fillers, hedging, pleasantries. Keeps code, commits, PR text normal. Preserves technical vocabulary. |
| How much can blitz save? | Output-token savings only: ~65% of Agent summaries, verification reports, model-written findings. Input tokens unaffected. Rough sprint-scale estimate: 5–15K output tokens saved per sprint (Agent returns + synthesis), negligible input impact. |
| How should it be incorporated into every skill? | Option A (recommended): bundle a 10-line `terse-output.md` directive + reference it from each SKILL.md header and each Agent() prompt template. Do not install the caveman plugin as a dependency. |
| Any safety concerns? | Caveman's own rules auto-pause for security warnings, irreversible actions, and user confusion. Blitz must preserve exact pattern text (grep patterns, file paths, story IDs, decision tables) — terse mode must be output-only, not applied to data structures. |

---

## Findings

### Finding 1 — Caveman is a directive, not a library

Source: `rules/caveman-activate.md` (full content fetched). The core mechanism is a ~15-line system directive:

> Speech pattern: minimal, direct, technical-only.
> Drop: articles, filler words, pleasantries, hedging.
> Keep: fragments, short terms, exact technical vocabulary, code as-is.
> Format: [subject] [verb] [reason]. [next action].
> Auto-pause: security warnings, irreversible actions, confused users.
> Boundary: code, commits, PRs written normally.

Four intensity levels (lite / full / ultra / wenyan) scale how aggressively filler is removed. The hooks (`caveman-activate.js`, `caveman-mode-tracker.js`) maintain mode state across turns; they do not preprocess text.

### Finding 2 — Blitz token hotspot is INPUT context, not output

Per codebase-analyst (full report in session tmp):

| Surface | Approx lines | Token class | Caveman impact |
|---|---|---|---|
| 33 SKILL.md files | 10,298 | input | **None** |
| 24 reference.md files | 9,591 | input | **None** |
| 8 shared/_ protocols | 1,880 | input | **None** |
| Agent() prompt templates | ~150–300 lines × 72 spawns/sprint | input | **None** |
| Agent() return summaries | variable | output | ~65% reduction |
| Verification/test output passed to synthesis | variable | output (when model paraphrases) | partial |
| Orchestrator-to-user text | variable | output | ~65% reduction |

The research doc `docs/_research/` tradition, sprint-review narratives, and retrospective writeups are all output-side — those will compress. But the 20K+ lines of skill documentation loaded on every `/blitz:<skill>` invocation is input, and caveman does nothing for it.

### Finding 3 — A separate "caveman-compress" sub-skill exists for input files

Source: caveman repo has a `caveman-compress/` directory. README describes it: "Rewrites memory files (like `CLAUDE.md`) into caveman-speak, achieving approximately 46% input token savings across sessions."

This is the one part of the caveman ecosystem that does address input tokens, and it operates by **author-time rewriting** (compress the markdown file itself), not runtime compression. If adopted, this is a batch job to rewrite SKILL.md + reference.md + shared protocols into terse form once, checked into the repo. It does not require caveman to be installed at runtime.

### Finding 4 — Blitz already has context-hygiene patterns, partial overlap

`skills/_shared/context-management.md` exists. It prescribes write-to-file streaming for agents, checkpoint protocols, and spawn hygiene. Caveman is complementary (compresses the style of what's written), not a replacement. No conflict.

### Finding 5 — Caveman repo is mature and actively maintained

- 35,260★, updated today (2026-04-17)
- MIT license
- Multi-platform (Claude Code, Codex, Gemini, generic)
- Plugin marketplace distribution available via `claude plugin install caveman@caveman`

No maintenance risk for the directive content. The JS hooks would be an extra runtime dependency if bundled, so avoid bundling.

---

## Compatibility Analysis

| Dimension | Result |
|---|---|
| Plugin coexistence | Clean — caveman is a separate plugin; blitz can reference its style without importing its code. |
| License | MIT, compatible with blitz MIT. |
| Slash-command collision | None. Caveman uses `/caveman`, blitz uses `/blitz:*`. |
| Skill-lifecycle interaction | Caveman mode persists across turns. If user activates it, it will affect blitz skill output. No code change needed for that pathway — it already works. |
| Determinism | Caveman does not change semantics of structured outputs (JSON, YAML, code blocks). Safe for blitz's structured artifacts (capability-index.json, scope blocks, etc.). |
| Integration complexity | Low for directive injection. High if bundled as a dependency. |

---

## Recommendation

**Adopt the directive pattern; do not bundle the plugin.**

Three concrete changes:

1. **Add `skills/_shared/terse-output.md`** — 15–20 line distillation of caveman's activation rule, credited and linked to upstream. Include the 4 intensity levels and the "auto-pause for security / irreversible actions / confusion" guard. Boundary clause: "code, commit messages, PR bodies, file paths, grep patterns, YAML frontmatter, and structured JSON are NOT compressed."

2. **Reference it from every SKILL.md header** — one line near the top: `Output style: see /_shared/terse-output.md`. No body rewrite. 33 files touched.

3. **Inject it into every Agent() prompt template** — shared prefix in `skills/_shared/spawn-protocol.md` that all orchestrator skills already reference. Agents inherit terse output automatically when spawned via the shared protocol. Zero per-skill edits.

**Expected savings (conservative):** 20–40% reduction in model-generated output across a sprint cycle. Not 65% (benchmarks include pure-prose tasks; blitz output is mostly code + structured findings, which caveman explicitly preserves uncompressed).

**What NOT to do:**
- Do not add caveman as a runtime install dependency. Blitz users should not be forced to install another plugin.
- Do not apply terse mode to reference.md or SKILL.md bodies without a separate compression research pass — those are input, not output, and rewriting them risks damaging exact-match patterns used by hooks and validators.
- Do not apply terse mode to checkpoint files, audit logs, or structured data — reduction of prose there saves little and risks parser regressions.

---

## Implementation Sketch

### Step 1 — Create shared directive (new file)

```
skills/_shared/terse-output.md
```

Content: ~20 lines summarizing caveman's rule, with blitz-specific boundary carve-outs (preserve file paths, grep patterns, story IDs, scope blocks, JSON/YAML, code, commit messages, PR bodies). Credit upstream.

### Step 2 — Add reference line to each SKILL.md

For each of the 33 files under `skills/*/SKILL.md`, add near the top (after the frontmatter or first heading):

```markdown
> Output style: terse-technical. See [/_shared/terse-output.md](/_shared/terse-output.md).
```

Mechanical edit. Covered by the scope block in this doc's frontmatter.

### Step 3 — Inject into shared spawn-protocol.md

Edit `skills/_shared/spawn-protocol.md` to append to every Agent() prompt template:

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Preserve code, file paths, grep patterns, JSON/YAML verbatim. No pleasantries, no preamble, no trailing summaries. Report findings and return.
```

Orchestrator skills that already reference spawn-protocol.md inherit this for free.

### Step 4 — Validate

Run the existing plugin validator. Confirm no skill exceeds its former size (expect trivial growth: +1 line per SKILL.md, +5 lines in spawn-protocol.md).

### Step 5 — Measure

After v1.5.0 ships, run one sprint with terse mode and one without. Compare transcripts for output-token delta. Roll back or tune intensity if output becomes unparseable.

### Optional Phase 2 — Input compression (separate research)

If the user wants the 10K-line SKILL.md bloat addressed: spawn a dedicated research task for `caveman-compress` batch rewriting of reference.md files (not SKILL.md — those are read by validators and hooks with exact-match patterns and must stay stable). This is a distinct workstream, not in scope for this doc.

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Terse output breaks downstream parsers that grep specific phrases | Medium | Grep blitz for phrase-dependent parsing before rollout. Audit `hooks/` and `installer/`. |
| Agents omit required fields in terse mode (e.g., scope YAML blocks, DoD checklists) | Medium | Directive explicitly lists preserved structures. Validate with sprint-review on first run. |
| User doesn't want terse output for orchestrator → user messages | Low | Add `/blitz:verbose` toggle, or make terse mode opt-in via frontmatter flag. |
| Upstream caveman changes activation phrase / semantics | Low | Blitz owns its own copy of the directive; upstream changes don't propagate. |
| 65% reduction doesn't materialize | High | Stated above — blitz output is code-heavy, which caveman preserves. Expect 20–40%, not 65%. |
| Confusion with existing `code-sweep` / `simplify` skill semantics | Low | Terse-output is style-only; simplify/code-sweep touch code. No conceptual overlap. |

**Open question:** Should terse mode be default-on or opt-in via a `/blitz:terse` toggle? Default-on ships savings to all users automatically; opt-in is safer for the first release. **Suggest: default-on at `lite` intensity, with `/blitz:terse full|ultra` to escalate.**

---

## References

- Caveman repo: https://github.com/JuliusBrussee/caveman
- Caveman activation rule: https://github.com/JuliusBrussee/caveman/blob/main/rules/caveman-activate.md
- Caveman README (fetched 2026-04-16)
- Caveman plugin manifest structure (skills/, hooks/, rules/)
- Referenced paper: "Brevity Constraints Reverse Performance Hierarchies in Language Models" (2026) — cited in caveman README
- Blitz codebase-analyst findings: `.cc-sessions/cli-d7433704/tmp/research/codebase-analyst.md`
- Blitz shared protocols: `skills/_shared/spawn-protocol.md`, `skills/_shared/context-management.md`
- Blitz plugin manifest: `.claude-plugin/plugin.json` (v1.4.1)
