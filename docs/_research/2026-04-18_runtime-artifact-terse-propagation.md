---
scope:
  - id: cf-2026-04-18-write-phase-directive-inserts
    unit: files
    target: 8
    description: |
      Insert a 3-5 line inline terse-output directive into the Generate/Write
      phase of 8 SKILL.md files that produce prose artifacts but currently
      only link the protocol passively. Targets: research, sprint-plan,
      sprint-review, retrospective, roadmap, release, fix-issue, todo. Each
      insert names the intensity (lite/full) and the compressible vs
      preserve-verbatim subsurfaces.
    acceptance:
      - grep_present:
          pattern: '\*\*Output style:\*\* terse-technical'
          min: 8
  - id: cf-2026-04-18-unsafe-ref-agent-prompt-injection
    unit: files
    target: 7
    description: |
      Inject the spawn-protocol §7 canonical OUTPUT STYLE snippet (5 lines)
      into every agent-prompt template in the 7 UNSAFE reference.md files:
      codebase-audit, codebase-map, code-sweep, integration-check,
      quality-metrics, sprint-dev, sprint-plan. Manual edit required (files
      are UNSAFE for /blitz:compress). Place after the WRITE-AS-YOU-GO clause.
    acceptance:
      - grep_present:
          pattern: 'OUTPUT STYLE: terse-technical per /_shared/terse-output.md'
          min: 7
  - id: cf-2026-04-18-lite-exemption-markers
    unit: files
    target: 9
    description: |
      Add explicit LITE-intensity exemption markers to 9 skills whose outputs
      contain sections where compression harms accuracy (security findings,
      root-cause chains, breaking-change explanations, never-auto-apply
      rationales). Targets: completeness-gate, codebase-audit, research,
      retrospective, sprint-review, release, migrate, fix-issue, bootstrap.
      Marker names the specific section(s) that stay LITE while the rest of
      the doc runs full intensity.
    acceptance:
      - grep_present:
          pattern: 'Terse exemptions|LITE intensity|lite-only'
          min: 9
  - id: cf-2026-04-18-spawn-protocol-warning-upgrade
    unit: files
    target: 2
    description: |
      After the 7 UNSAFE reference.md have the §7 snippet injected, upgrade
      spawn-protocol.md:328 from WARNING → BLOCKER and update sprint-review
      Phase 3.6 Invariant list to fail the sprint on missing snippet.
    acceptance:
      - grep_absent: 'WARNING \(not BLOCKER\)'
      - grep_present:
          pattern: 'Invariant.*OUTPUT STYLE|BLOCKER.*terse-output'
          min: 1
  - id: cf-2026-04-18-activity-feed-message-rule
    unit: files
    target: 1
    description: |
      Add a soft length rule to verbose-progress.md: activity-feed `message`
      field SHOULD be ≤200 chars; overflow moves to `detail`. Sprint-review
      Phase 3.6 adds a grep-based warning for messages >300 chars as Invariant
      reinforcement (not a BLOCKER, to avoid false positives on legitimate
      session-end summaries).
    acceptance:
      - grep_present:
          pattern: 'message.*200 char|message.*length'
          min: 1
---

# Research: Runtime-Artifact Terse-Output Propagation in Blitz Skills

**Date:** 2026-04-18
**Topic:** Runtime-produced artifacts (research docs, sprint plans, reviews, retrospectives, roadmap docs, close comments) and whether the terse-output directive actually reaches them at generation time.
**Research type:** Architecture Decision
**Session:** cli-22d341d9
**Complements:** `docs/_research/2026-04-18_caveman-full-absorption.md` (concept absorption — focused on which caveman concepts to adopt). This pass asks the narrower follow-on: once absorbed, do the concepts actually propagate to skills' generated output?

---

## Summary

25/34 SKILL.md link `/_shared/terse-output.md` passively in Additional Resources. **Zero skills re-assert the directive inside the Generate/Write phase where output is produced.** Zero of the 7 UNSAFE reference.md agent-prompt files inject the spawn-protocol §7 OUTPUT STYLE snippet, despite §7 stating it MUST be injected. Sprint-review's missing-snippet WARNING (spawn-protocol.md:328) would fire universally. The research skill is the self-evidence: today's 439-line `docs/_research/2026-04-18_caveman-full-absorption.md` has ~65-95 compressible prose lines (15-22%), caused by `skills/research/SKILL.md:256-266` mandating "3-5 sentence summary" with no inline terse directive at synthesis. Fix is two concrete edits per skill: (a) 5-line directive at write-site, (b) inject §7 snippet into agent prompts. Add LITE-intensity exemption markers for 9 safety/reasoning-sensitive sections to prevent accuracy loss per Renze 2024 / Prompt-Compression-in-the-Wild evidence already cataloged in prior doc. Realistic monthly saving: ~1 K lines. Not revolutionary; correctness-driven.

---

## Research Questions & Answers

| Question | Answer |
|---|---|
| Do blitz skills' runtime outputs follow terse-output? | No. Link-only propagation. Templates re-introduce verbose defaults ("3-5 sentence…", "2-4 sentences on what and why…"). |
| Which skills produce prose-heavy artifacts? | 14: research, sprint-plan (story bodies), sprint-review, retrospective, roadmap, codebase-audit, codebase-map, perf-profile, dep-health, doc-gen, migrate, fix-issue (issue comment), release (notes body), integration-check. |
| Which skills are already adequate? | commit subjects (all 30 recent: conventional-commits, avg 57 chars), CHANGELOG structure, completeness-gate JSON findings, quality-metrics dashboard tables. |
| Is spawn-protocol §7 effective? | No. Defines snippet and mandate (line 309); 0/7 UNSAFE reference.md inline it; enforcement is WARNING (line 328), not BLOCKER, and nothing fails today. |
| What's the realistic savings ceiling? | ~1 K lines/month at current cadence (2 sprints + 4 research docs + quarterly audit). Consistent with Hakim/Pillitteri 15-25% band documented in prior doc's Finding 3. |
| Are there sections where terse HARMS the output? | Yes. 9 skills have sections needing LITE intensity: security findings, root-cause chains, breaking-change entries, never-auto-apply rationale. Per Renze 2024 (math degradation) + Prompt-Compression-in-the-Wild (code-gen harm). |

---

## Findings

### Finding 1 — Propagation is passive; reach is 0%

Source: template-audit §1 (full matrix across 34 skills).

| Propagation point | Coverage |
|---|---|
| SKILL.md Additional Resources link to `/_shared/terse-output.md` | 25/34 |
| SKILL.md Generate/Write phase re-asserts the directive | **0/34** |
| Agent() spawn prompts inline §7 snippet | **0/7 UNSAFE reference.md** |

The link at the top is context the model *can* read. Templates at the bottom tell the model how to format output. Those two surfaces don't talk. When the model generates the final artifact, it follows the template ("3-5 sentences") and forgets the link. Result: verbose default.

### Finding 2 — 14 prose-heavy artifacts leak

Source: artifact-inventory §1.

| Skill | Artifact | Prose density | Fix class |
|---|---|---|---|
| research | `docs/_research/YYYY-MM-DD_<slug>.md` | HIGH | Stylistic + structural |
| sprint-plan | `stories/S*-XXX.md` Description + Impl Notes; `summary.md` | MIXED | Stylistic |
| sprint-review | `review-report.md` ExecSummary + Findings + Recs | HIGH | Stylistic + review-format absorption |
| retrospective | `proposals.md` | HIGH | Stylistic |
| roadmap | `gap-analysis.md` narrative, phase docs | MIXED | Stylistic + structural |
| fix-issue | GitHub issue close comment body | HIGH | Stylistic |
| codebase-audit | 10 pillar findings files | HIGH | Stylistic (UNSAFE ref.md edit) |
| codebase-map | 4 dimension files | HIGH | Stylistic (UNSAFE ref.md edit) |
| perf-profile | `docs/perf/<mode>-<ts>.md` | HIGH | Stylistic |
| dep-health | `docs/dep-health-report.md` | HIGH | Stylistic |
| doc-gen | `docs/generated/api.md|components.md|architecture.md` | HIGH | Structural (prose-by-definition) |
| migrate | migration plan + progress doc | HIGH | Stylistic |
| release | `release-notes.md` body | MIXED | Stylistic |
| integration-check | `docs/integration-check-report.md` | MIXED | Stylistic |

### Finding 3 — Research skill is the self-evidence

Source: artifact-inventory §2.1 + §6 (meta-audit of today's doc).

Today's `docs/_research/2026-04-18_caveman-full-absorption.md` is 439 lines. Prose-to-structure ratio ≈ 0.51. Identified 8 verbose passages (artifact-inventory §2.1) each compressible 30-68% without boundary violation. Net: ~65-95 lines droppable (15-22%).

Root cause: `skills/research/SKILL.md:256-266`. Template specifies 8 mandatory sections and "3-5 sentence executive summary" — a prose-inviting floor. No inline terse directive at Phase 3.1 synthesis. The Additional-Resources link at SKILL.md:17 is not loaded into the synthesis prompt.

Representative passage (`:140-142`, 44 words):
> Prior work absorbed two of caveman's surfaces: the output-style directive (…) and author-time `reference.md` compression (10 files under S1-005). This pass catalogs the remaining absorbable surfaces — agent-definition coverage, shared-protocol discoverability, review-format specialization, agent-prompt boilerplate dedup, intensity-mode persistence, task-type gating, and a further wave of file compression against `docs/_research/` and 7 remaining SAFE reference.md.

Terse (28 words, -36%):
> Prior passes absorbed directive + 10 reference.md. This pass catalogs 9 remaining surfaces: agent-definition coverage, protocol discoverability, review-format, boilerplate dedup, intensity persistence, task-type gating, wave-2 compression.

### Finding 4 — spawn-protocol §7 is documented but inert

Source: template-audit §4.

`skills/_shared/spawn-protocol.md:309` mandates: *"Every agent spawn MUST inject the terse-output directive into the prompt"*. Canonical snippet at :313-319 (5 lines, verbatim). Enforcement at :328: WARNING (not BLOCKER).

None of the 7 UNSAFE reference.md files with agent prompts inject the snippet. Sprint-review's missing-snippet WARNING would fire for every agent spawn today, but nothing fails. The contract exists; nothing enforces it.

### Finding 5 — Review-format absorption is highest single-edit leverage

Source: artifact-inventory §5.2 + template-audit §5.4 + prior doc's `cf-2026-04-18-review-format-absorption`.

`skills/sprint-review/SKILL.md:406-413` template names sections but specifies no per-finding format. Adopting caveman-review's `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes is a single edit that touches the most-re-read artifact per sprint cycle. Carry-forward already registers this work; this research confirms the leverage rank.

### Finding 6 — 9 skills need LITE-intensity exemption markers

Source: template-audit §8.

Renze 2024 + Prompt-Compression-in-the-Wild show brevity degrades reasoning on weaker-model math and code-gen. Applied to blitz:

| Skill | Section requiring LITE |
|---|---|
| completeness-gate | `severity:critical + category:security` `message` field |
| codebase-audit | security-pillar risk narrative |
| research | §7 Risks + Open Questions (reasoning chain) |
| retrospective | Never-Auto-Apply classification rationale |
| sprint-review | critical/major finding explanations |
| release | breaking-change entries |
| migrate | breaking-change step explanations |
| fix-issue | Root Cause field |
| bootstrap | destructive-op confirmations (harness-level) |

These are per-section exemptions, not whole-skill. The rest of the doc runs full intensity; only the named section drops to LITE (full sentences, preserve reasoning chain).

### Finding 7 — Commit subjects and CHANGELOG already comply

Source: artifact-inventory §8.

30 most recent commits: 30/30 conventional-commits, avg subject 57 chars, 0 with trailing filler. Template literals in sprint-dev / sprint-plan / sprint-review / fix-issue / release / retrospective all produce terse subjects. No change needed.

### Finding 8 — Activity-feed `message` field occasionally leaks

Source: artifact-inventory §2.6.

Sampled `.cc-sessions/activity-feed.jsonl` (541 lines). Most `message` strings ≤80 chars. At least one >500-char offender observed (`2026-04-18T13:19:29`, web-researcher task_complete). JSONL envelope is preservation-boundary; `message` value is compression target. Soft rule: ≤200 chars, overflow to `detail`. No hook enforcement needed — sprint-review Phase 3.6 grep warning covers it.

### Finding 9 — Preservation-boundary discipline is solid but must be codified

Source: artifact-inventory §9.

Section headings enumerated below are grep'd as lookup keys by downstream skills. Their text must never compress:

- `## Summary`, `## Fix Applied`, `## Phase Summary`, `## Next Actions`, `## Blockers`, `### Registry Invariants`, `### Critical`, `### Major`, `### Minor`, `### Info`, `### Added`, `### Fixed`, `### Changed`, `### Breaking Changes`, `**Root Cause**`, `**Fix**`, `**Verification**`

Add these to `/blitz:compress`'s UNSAFE catalog (sprint-1 rule 2.3 markers) so future terse rewrites can't accidentally drop them.

### Finding 10 — Two gap classes: stylistic vs structural

Source: template-audit §7.

**Stylistic (fixable by directive insert):** ~8 SKILL.md write-phases + 7 UNSAFE reference.md. Savings: 10-20% per artifact.

**Structural (needs template rewrite):**

| Skill | Structural issue |
|---|---|
| research | 8-section mandate + subsection headers; downstream (roadmap) parses section names |
| roadmap | 5-artifact-per-run sprawl (phase-plan + gap-analysis + research-cache + domain-index + epic-registry) |
| doc-gen | Output IS prose by definition (API docs, architecture narratives) |
| codebase-audit | 10 pillars × multi-section |
| codebase-map | 4 dimensions × narrative |

Structural rewrites yield 30-50% but risk downstream parsers. Defer to separate roadmap item; do not bundle with this absorption.

---

## Compatibility Analysis

| Dimension | Result |
|---|---|
| Existing infra | Extended, not replaced. spawn-protocol §7 snippet exists; just needs injection. terse-output.md already defines intensities. |
| Prior sprint-1 work | Complements. Sprint-1 compressed reference.md files (input-side); this pass fixes output-side propagation at write-time. |
| Carry-forward registry | 5 new scope entries in this doc's frontmatter. No conflicts with 9 entries from prior doc (`cf-2026-04-18-*`). |
| Validators | No new validator required. sprint-review Phase 3.6 grep extensions cover enforcement once snippets land. |
| Hook layer | No new hooks. spawn-protocol WARNING → BLOCKER upgrade happens post-rollout. |
| Structural gaps | Out of scope here. Separate roadmap item for research/roadmap/doc-gen structural rewrites. |

---

## Recommendation

**Two-phase rollout. Phase A: directive injection across 15 write-sites. Phase B: enforcement upgrade + LITE markers + preservation-boundary codification.**

### Priority matrix

| Item | Target count | Effort | Leverage | Order |
|---|---|---|---|---|
| Inject §7 snippet into 7 UNSAFE reference.md agent prompts | 7 | LOW (manual edit) | HIGH (every agent spawn) | 1 |
| 5-line directive insert at 8 SKILL.md write-phases | 8 | LOW | HIGH (14 prose-artifact classes) | 2 |
| Absorb caveman-review `L<line>:` format in sprint-review | 1 | LOW | HIGH (most-re-read artifact) | 3 |
| Add LITE-intensity exemption markers to 9 safety/reasoning sections | 9 | LOW | MED (accuracy protection) | 4 |
| Add preservation-boundary header list to `/blitz:compress` UNSAFE catalog | 1 | LOW | LOW (prevents future foot-gun) | 5 |
| Add activity-feed `message` length rule to verbose-progress.md | 1 | LOW | LOW | 6 |
| Upgrade spawn-protocol §7 WARNING → BLOCKER | 1 | LOW | MED (enforcement) | 7 (after 1+2 land) |
| Structural template rewrites (research, roadmap, doc-gen) | N/A | HIGH | HIGH | SEPARATE roadmap item |

### Design principles

1. **Runtime propagation needs runtime instruction.** Additional-Resources links are reference material; Claude follows templates. Directive must live at the write-site.
2. **Intensity is per-section, not per-skill.** LITE for security/root-cause/breaking-change; FULL for mechanical narrative; lite for user-facing summary. Skills declare which section is which.
3. **Enforcement after coverage.** Upgrade WARNING → BLOCKER only after the snippet lands in all 7 UNSAFE files; otherwise sprint-review blocks every sprint.
4. **Structural rewrites are a separate concern.** Directive injection closes 10-20%. 30-50% savings on research/roadmap/doc-gen requires rewriting their mandated-section templates and is a separate roadmap epic.

---

## Implementation Sketch

### Phase A — directive injection (8 + 7 + 9 edits)

**A.1 — 8 SKILL.md write-phase directive inserts.** Each is a 3-5 line block at the skill's Generate/Write phase. Exact locations from template-audit §5:

| Skill | Insert at | Directive text |
|---|---|---|
| research | `skills/research/SKILL.md:256` (before "Use the template") | See §5.1 of template-audit |
| sprint-plan | `skills/sprint-plan/SKILL.md:318` (before story body list) | See §5.2 |
| sprint-review | `skills/sprint-review/SKILL.md:406` (before "Write the review report") | See §5.4 |
| retrospective | `skills/retrospective/SKILL.md:258` (before proposals template) | See §5.6 |
| roadmap | `skills/roadmap/SKILL.md:301` (before gap-analysis write) | See §5.7 |
| release | `skills/release/SKILL.md:215` (before release-notes HEREDOC) | See §5.8 |
| fix-issue | `skills/fix-issue/SKILL.md:317` (before comment template) + rewrite `:321-332` fields, drop `:333` filler line | See §5.9 |
| todo | `skills/todo/SKILL.md` (add Additional-Resources link first) | Standard block |

Canonical 5-line block (template-audit §6):

```markdown
**Output style:** terse-technical per `/_shared/terse-output.md`. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, paths, commands, grep patterns, YAML/JSON, tables, error codes, dates, versions. No preamble, no trailing summary. Fragments OK. Intensity: `lite` (user-facing) or `full` (agent-internal). Auto-pause for security/irreversible/root-cause sections.
```

**A.2 — 7 UNSAFE reference.md §7 snippet injections.** Manual (UNSAFE for `/blitz:compress`). Place after the shared preamble's WRITE-AS-YOU-GO clause in each:

- `skills/codebase-audit/reference.md` (10-pillar prompts)
- `skills/codebase-map/reference.md` (4 dimension prompts)
- `skills/code-sweep/reference.md` (tier prompts)
- `skills/integration-check/reference.md` (3 domain prompts)
- `skills/quality-metrics/reference.md` (collector prompts)
- `skills/sprint-dev/reference.md:12,76,141,205` (4 role prompts)
- `skills/sprint-plan/reference.md:304,333,365,398` (4 researcher prompts)

Snippet (verbatim from spawn-protocol.md:313-319):

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

**A.3 — Caveman-review format in sprint-review.** Rewrite `skills/sprint-review/SKILL.md` Findings section (and `reference.md` reviewer templates) to mandate: `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓. `LGTM` for clean code. Auto-clarity (LITE) for security/CVE findings. This closes `cf-2026-04-18-review-format-absorption`.

### Phase B — LITE markers + enforcement + hygiene

**B.1 — LITE-intensity exemption markers on 9 skills.** Each gets a 2-line marker naming the section(s) that stay LITE:

```markdown
**Terse exemptions (LITE intensity):** <section name>. Full sentences + reasoning chain required. Resume terse on next section.
```

Target sections per Finding 6 table.

**B.2 — Preservation-boundary header codification.** Append to `skills/compress/SKILL.md` §2.3 UNSAFE markers list: the 17 grep-target headers from Finding 9. `/blitz:compress` refuses files whose compressed form would alter these headings.

**B.3 — Activity-feed message rule.** Add to `skills/_shared/verbose-progress.md`: *"`message` field SHOULD be ≤200 chars. Overflow belongs in `detail`."* Sprint-review Phase 3.6 adds a non-BLOCKER grep check for >300-char offenders.

**B.4 — spawn-protocol WARNING → BLOCKER.** After A.2 lands and sprint-1+ sprints ship clean, edit `skills/_shared/spawn-protocol.md:328`: change "WARNING (not BLOCKER)" to "BLOCKER — sprint-review fails the sprint if an Agent() prompt template omits the OUTPUT STYLE snippet." Add Invariant 5 to sprint-review Phase 3.6.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Directive insert makes Claude too terse on reasoning artifacts | MED | MED | LITE markers on 9 named sections; Finding 6 table is exhaustive |
| Sprint-review BLOCKER upgrade fires during transition, blocks sprints | HIGH if misordered | HIGH | Strict ordering: A.2 fully lands before B.4; CI-style pre-check before the upgrade commit |
| Header-preservation list in `/blitz:compress` is incomplete | LOW | MED | Headers enumerated in Finding 9 from a live grep; add audit step during `/blitz:compress` that surfaces new grep-target candidates |
| Review-format change breaks downstream sprint-review parsing | MED | MED | Diff review-report output against prior sprint; gate behind `developer-profile.json` flag for one cycle |
| LITE markers confuse model — which section applies? | LOW | LOW | Markers name the section heading verbatim ("§7 Risks", "Root Cause field"); unambiguous |
| Activity-feed rule breaks long legitimate summaries | LOW | LOW | Soft rule only, non-BLOCKER, message 300-char threshold (not 200) for grep warning |
| Terse docs lose context for future readers (incl. human operators) | MED | LOW | Intensity=lite default for user-facing output; research doc §Risks stays LITE; no reasoning chain compressed |

**Open questions:**

- Should the directive text be a `<!-- terse-output -->` include marker rather than inline prose, so it updates in one place? **Defer — inline is discoverable by reviewers; single source of truth already exists in `/_shared/terse-output.md`.**
- Structural rewrites (research 8-section, roadmap 5-artifact) — should they be in the same roadmap epic as directive injection or a later one? **Later. Directive injection is mechanical and shippable; structural rewrites require downstream parser audit.**
- Does `/blitz:compress` need a "verify-no-header-drift" post-step extended to cover Finding 9 headers? **Yes — already implicit in the existing structural validator; codify in `hooks/scripts/reference-compression-validate.sh` as an additional heading-match check.**

---

## References

**Session artifacts:**
- `.cc-sessions/cli-22d341d9/tmp/research/artifact-inventory.md` (536 lines)
- `.cc-sessions/cli-22d341d9/tmp/research/template-audit.md` (338 lines)

**Prior blitz research (complements, not supersedes):**
- `docs/_research/2026-04-18_caveman-full-absorption.md` — concept absorption catalog; this doc is its runtime-propagation follow-on
- `docs/_research/2026-04-16_caveman-token-minimization.md` — original output-directive introduction
- `docs/_research/2026-04-16_caveman-compress-input-side.md` — input-side compression work

**Blitz canonical protocols:**
- `skills/_shared/terse-output.md:1-95` — the directive and intensity tiers
- `skills/_shared/spawn-protocol.md:307-329` — §7 Agent-spawn snippet and WARNING clause
- `skills/_shared/verbose-progress.md` — activity-feed contract

**Template sources audited (path:line refs):**
- `skills/research/SKILL.md:244-266` — 8-section doc template
- `skills/sprint-plan/SKILL.md:308-324` — story body format
- `skills/sprint-review/SKILL.md:404-413` — review report template
- `skills/retrospective/SKILL.md:256-307` — proposals template
- `skills/roadmap/SKILL.md:301-305` — gap-analysis format
- `skills/release/SKILL.md:179-219` — CHANGELOG + release notes
- `skills/fix-issue/SKILL.md:317-334` — issue close comment
- `skills/completeness-gate/SKILL.md:94-104` — finding JSON schema
- `skills/sprint-dev/reference.md:12,76,141,205` — 4 role prompts (silent on style)
- `skills/sprint-plan/reference.md:286-299,304,333,365,398` — preamble + 4 researcher prompts
- `sprints/sprint-1/STATE.md` — sprint-1 rule 2.3 UNSAFE marker precedent

**Brevity literature (per prior doc, cited for LITE markers):**
- Hakim 2026, arXiv:2604.00025 — brevity helps 7.7% of problems
- Renze & Guven 2024, arXiv:2401.05618 — brevity harms weak-model math (-27.69%)
- "Prompt Compression in the Wild," arXiv:2604.02985 — code-gen degrades under compression
- Anthropic, "Effective Context Engineering" — cautions against over-aggressive compaction
