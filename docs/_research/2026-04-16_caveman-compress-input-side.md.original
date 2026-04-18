---
scope:
  - id: cf-2026-04-16-compress-safe-references
    unit: files
    target: 12
    description: |
      Apply caveman-compress to the 12 SAFE reference.md files under skills/
      (browse, sprint-review, test-gen, ui-build, refactor, research,
      retrospective, release, dep-health, quality-metrics, migrate,
      codebase-map). Commit compressed files; commit .original.md backups
      alongside; add a validator hook that confirms no compressed file's
      preserved elements (code fences, URLs, file paths, table structure,
      section headings) changed.
    acceptance:
      - shell: "test $(find skills -name 'reference.md.original' | wc -l) -ge 12"
      - shell: "test -f hooks/scripts/reference-compression-validate.sh"
      - grep_absent: 'TODO.*caveman-compress'
  - id: cf-2026-04-16-reference-compression-validator
    unit: files
    target: 1
    description: |
      Add hooks/scripts/reference-compression-validate.sh that checks compressed
      reference.md files still contain all code fences, URLs, file paths, and
      headings from the .original.md backup (diff-based structural check).
    acceptance:
      - shell: "test -x hooks/scripts/reference-compression-validate.sh"
      - grep_present:
          pattern: 'reference-compression-validate'
          min: 1
---

# Research: caveman-compress for Input-Side reference.md Compression in Blitz

**Date:** 2026-04-16
**Topic:** Apply caveman-compress to blitz's 24 `reference.md` files to reduce input-token cost when skills load.
**Research type:** Feature Investigation
**Session:** cli-bc2827ec
**Follows from:** `docs/_research/2026-04-16_caveman-token-minimization.md` (Phase 2 workstream)

---

## Summary

caveman-compress is a Python 3.10+ CLI (`/caveman:compress <filepath>`) that uses Claude to rewrite natural-language markdown into terse form, claiming ~46% token reduction on prose-only files. Blitz has 24 reference.md files totaling 9,591 lines; after excluding code fences (~270 lines), tables (~1,290 lines), and exact-match agent-prompt content (~200 lines), ~7,831 lines of prose are eligible. Realistic savings: **~3,600 lines (~38% of total)** if applied broadly — but **4 reference.md files contain exact-match agent prompt templates** that agents execute verbatim, creating high corruption risk. Recommendation: **compress 12 SAFE files, leave the 4 UNSAFE and 3 RISKY files untouched, add a structural-diff validator**. Expected net savings: ~2,400 lines (~25% of the reference.md surface).

---

## Research Questions & Answers

| Question | Answer |
|---|---|
| How does caveman-compress work mechanically? | Single-file Python CLI. Reads file → sends to Claude → validates preserved elements → retries targeted fixes up to 2x → writes compressed output → saves `FILE.original.md` backup. No batch mode, no dry-run, no diff preview. |
| What does it preserve vs compress? | Preserves: fenced code blocks, inline code, URLs, file paths, commands, headings, tables (structure — cell text still compressed), dates, version numbers. Compresses: articles, fillers, pleasantries, hedging, verbose constructions. |
| What's the 46% savings claim based on? | 5-project sample: 898→481 avg tokens per memory file. Methodology weights prose-heavy files; not validated on mixed prose+code+tables. |
| What blitz files are candidates? | 24 reference.md files, 9,591 lines. 12 SAFE (pure prose), 3 RISKY (headings matched by agent prompts), 4 UNSAFE (exact-match agent prompt templates). |
| What are the realistic savings for blitz? | ~3,600 lines if all files compressed. ~2,400 lines (25%) if only SAFE files are compressed. Both far smaller than the 46% headline because blitz references are table-heavy (1,290/9,591 = 13% tables alone). |
| What are the risks? | (1) Agent prompt templates corrupted → sprint-dev/sprint-plan/code-sweep/completeness-gate agents misbehave. (2) Section-heading drift → orchestrator skills that reference "section X" fail lookup. (3) No existing validator checks reference.md content — compression damage is invisible until a skill runs. (4) Table cells still get compressed (tool only preserves *structure*); grep-executable patterns inside tables are at risk. |
| Is there a reversible workflow? | Yes — tool writes `.original.md` backup. Commit both. No existing repo pattern for source/generated pairs, but git-tracked backups suffice. |

---

## Findings

### Finding 1 — caveman-compress is single-file, no batch, no preview

Source: `caveman-compress/README.md` + `SKILL.md` fetched from upstream.

- Invocation: `/caveman:compress <single-filepath>`
- No `--dry-run`, no `--diff`, no batch mode documented
- 500KB file-size limit (blitz's largest reference.md is browse at 1,330 lines ≈ 45KB — fine)
- Up to 2 validation-retry cycles; if final fails, source untouched and error reported
- `SECURITY.md` confines writes to the given path and prohibits network calls beyond Anthropic API

**Operational implication:** A blitz wrapper script is required to iterate over multiple files and to implement dry-run/diff review before commit. Estimate ~30 lines of bash.

### Finding 2 — Blitz has 24 reference.md files; most are table-heavy

Source: codebase-analyst report (full report at session tmp).

Top five by size: browse (1,330), code-sweep (912), roadmap (661), sprint-dev (582), doc-gen (539). Only 7,831 of 9,591 lines are actually prose — the rest is code fences (270), tables (1,290), or agent-prompt templates (200). Prose is what caveman-compress actually reduces.

### Finding 3 — Four reference.md files contain exact-match agent prompt templates

Source: codebase-analyst grep of orchestrator SKILL.md files for "reference.md" references and prompt-template spawns.

| File | Exact-match content | Consumer |
|---|---|---|
| code-sweep/reference.md | Tier agent prompt template (lines 11–70) + grep patterns (table rows) | Tier agents execute grep patterns verbatim |
| completeness-gate/reference.md | 13 grep patterns in table | Agents run patterns byte-for-byte |
| sprint-dev/reference.md | 12-item dev-agent prompt checklist | Agents verify all 12 items present |
| sprint-plan/reference.md | Epic-agent prompt template | Filled-in template sent to agents |

Compressing these files would rewrite agent-facing text. caveman-compress's preservation rules protect code fences and table structure but **will still rewrite prose inside table cells** — which is exactly where the grep patterns and prompt fragments live in completeness-gate and code-sweep. This is the single biggest correctness risk in this adoption.

### Finding 4 — No existing validator catches reference.md damage

Source: codebase-analyst scan of `hooks/scripts/*.sh` and `installer/validate.sh`.

Existing pre-commit and post-edit hooks check SKILL.md existence and line counts. No hook parses reference.md content. This is a blind spot: if compression corrupts an agent prompt template, the failure surfaces only when a user runs that skill — potentially weeks later, across an interim release.

### Finding 5 — Three additional files have RISKY section-heading references

Source: codebase-analyst.

- `codebase-audit/reference.md` — "Dimension Agent Prompt Template" heading matched by orchestrator lookup
- `integration-check/reference.md` — "Check Agent Prompt Template" heading matched
- `code-sweep/reference.md` (also UNSAFE; double-flagged) — "Grep Patterns by Check" and "Tier {{TIER}}" headings

caveman-compress preserves heading *text*, per its documented rules. So headings themselves are safe — but if the orchestrator looks up prose *under* a heading, compressed prose may no longer match downstream expectations. Lower risk than UNSAFE, but still audit-worthy.

### Finding 6 — Backup convention is `.original.md`; fits git-tracked source pattern

Source: caveman-compress SKILL.md.

The tool already writes `FILE.original.md` alongside the compressed file. Simplest reversible pattern for blitz: commit both; the `.original.md` is the canonical source for future edits, the compressed file is the runtime artifact. A lightweight rebuild script re-runs compression when `.original.md` changes.

---

## Compatibility Analysis

| Dimension | Result |
|---|---|
| Python runtime | Blitz is a pure-prompt plugin; no Python runtime today. Adding caveman-compress as an author-time *build* tool (not runtime dep) avoids imposing Python on end users. |
| License | caveman is MIT, blitz is MIT. Compatible. |
| File size | Largest reference.md (browse, 1,330 lines ≈ 45KB) is well under the 500KB tool limit. |
| Caveman runtime install | **Not required for end users.** Compression is author-time; end users only see the compressed output that ships in the blitz plugin. |
| Skill-loading impact | Skills load reference.md via Read on demand. Compressed files parse identically — no loader change needed. |
| Hooks / validators | None exist for reference.md content. Must add one before compressing, or compression damage is undetectable. |

---

## Recommendation

**Phased, audited rollout — compress the 12 SAFE files, add a validator, defer the 7 RISKY/UNSAFE files.**

Three priorities, in order:

1. **Write a structural-diff validator FIRST.** `hooks/scripts/reference-compression-validate.sh` diffs a compressed `reference.md` against its `.original.md` backup and fails if any of: code fences removed, URLs changed, file paths rewritten, table row counts differ, heading list differs. This is the prerequisite — without it, we have no mechanism to catch compression damage.

2. **Compress the 12 SAFE files.** browse, sprint-review, test-gen, ui-build, refactor, research, retrospective, release, dep-health, quality-metrics, migrate, codebase-map. Validate each. Commit both compressed and `.original.md`.

3. **Leave UNSAFE and RISKY files uncompressed.** code-sweep, completeness-gate, sprint-dev, sprint-plan (UNSAFE — contain executable agent content). codebase-audit, integration-check (RISKY — section-heading lookups). doc-gen, roadmap, bootstrap, setup, fix-issue (keep uncompressed pending per-file audit — these have substantial table/schema content where compression return is marginal).

**Projected net savings:** ~2,400 lines (25% reduction of reference.md surface), not the 46% headline. If this is insufficient, an alternate path is to rewrite reference.md files to be terse *by hand* during normal authorship — cheaper than maintaining a compression pipeline.

---

## Implementation Sketch

### Step 1 — Validator (new file, ~40 lines)

`hooks/scripts/reference-compression-validate.sh`:

```bash
#!/usr/bin/env bash
# For each reference.md + reference.md.original pair, verify structural preservation.
set -euo pipefail
FAILED=0
for orig in $(find skills -name 'reference.md.original'); do
  compressed="${orig%.original}"
  # Code fences count
  of=$(grep -c '^```' "$orig")
  cf=$(grep -c '^```' "$compressed")
  [[ "$of" == "$cf" ]] || { echo "FAIL $compressed: code fence count $cf != $of"; FAILED=1; }
  # URLs preserved
  diff <(grep -oE 'https?://[^ )]+' "$orig" | sort -u) \
       <(grep -oE 'https?://[^ )]+' "$compressed" | sort -u) \
       || { echo "FAIL $compressed: URL set drift"; FAILED=1; }
  # Heading list preserved
  diff <(grep -E '^#+ ' "$orig") <(grep -E '^#+ ' "$compressed") \
       || { echo "FAIL $compressed: heading drift"; FAILED=1; }
  # Table row count preserved
  ot=$(grep -c '^|' "$orig"); ct=$(grep -c '^|' "$compressed")
  [[ "$ot" == "$ct" ]] || { echo "FAIL $compressed: table rows $ct != $ot"; FAILED=1; }
done
exit $FAILED
```

Wire into `hooks/hooks.json` as pre-commit.

### Step 2 — Batch wrapper (new file, ~30 lines)

`scripts/compress-references.sh`:

```bash
#!/usr/bin/env bash
# Compress the SAFE-list reference.md files via caveman-compress.
SAFE=(browse sprint-review test-gen ui-build refactor research retrospective release dep-health quality-metrics migrate codebase-map)
for skill in "${SAFE[@]}"; do
  target="skills/${skill}/reference.md"
  [[ -f "$target" ]] || { echo "skip $skill (no reference.md)"; continue; }
  [[ -f "${target}.original" ]] && { echo "skip $skill (already compressed)"; continue; }
  /caveman:compress "$target" || { echo "FAIL $skill"; continue; }
done
bash hooks/scripts/reference-compression-validate.sh
```

### Step 3 — Commit both files per skill

`skills/<skill>/reference.md` = compressed (runtime).
`skills/<skill>/reference.md.original` = source (author edits here).

### Step 4 — Update contributor docs

Add note to `CLAUDE.md` or `CONTRIBUTING` (if exists): "Edit `reference.md.original`; run `scripts/compress-references.sh`; commit both."

### Step 5 — Measure

Compare token counts before/after via the `.cc-sessions/context-char-count` file (blitz already tracks this). Confirm ~2,400 line reduction translates to meaningful sprint-level token savings before scaling.

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Compressed prose inside tables breaks grep patterns (completeness-gate, code-sweep) | HIGH if applied broadly; mitigated to low by excluding those 2 files | Exclude from SAFE list (done in recommendation) |
| Agent prompt templates corrupted | HIGH if applied broadly; mitigated to low by excluding 4 UNSAFE files | Exclude sprint-dev, sprint-plan from compression |
| Section-heading lookups drift | Low — caveman-compress preserves heading text | Validator compares heading lists |
| Python 3.10+ becomes a contributor dependency | Medium | Wrapper script prints clear install instructions; CI can use a Docker image |
| caveman-compress's Claude calls cost tokens | Low — author-time, amortized | Budget check per run; batch wrapper prints token estimate |
| Source-of-truth confusion between `reference.md` and `.original.md` | Medium | Pre-commit hook rejects edits to compressed file when `.original.md` is older |
| 25% savings too small to justify the pipeline | Medium-high | If net savings fall below 2,000 lines after first batch, abandon and rewrite prose terse-by-hand instead |

**Open questions:**
- Should `.original.md` be git-tracked, or generated at build time from a pre-commit hook? Tracking both doubles the repo size for reference files. (Suggest: track both; reference.md files are small in absolute terms.)
- Does end-user skill loading read compressed or original? Skills always Read `reference.md` — the compressed file. `.original.md` is author-only.
- Is there value in compressing SKILL.md too? No — SKILL.md has hook-matched line-count limits and is already closer to minimum viable prose. Risk > reward.

---

## References

- caveman repo: https://github.com/JuliusBrussee/caveman
- caveman-compress SKILL: https://github.com/JuliusBrussee/caveman/blob/main/caveman-compress/SKILL.md
- caveman-compress README: https://github.com/JuliusBrussee/caveman/blob/main/caveman-compress/README.md
- caveman-compress SECURITY: https://github.com/JuliusBrussee/caveman/blob/main/caveman-compress/SECURITY.md
- Prior research: `docs/_research/2026-04-16_caveman-token-minimization.md`
- Blitz codebase-analyst report: `.cc-sessions/cli-bc2827ec/tmp/research/codebase-analyst.md`
- Blitz reference inventory: 24 files, 9,591 lines, tabulated in codebase-analyst report
- Blitz hook infrastructure: `hooks/hooks.json`, `hooks/scripts/*.sh`
