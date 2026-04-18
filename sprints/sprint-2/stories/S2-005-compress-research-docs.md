---
id: S2-005
title: Compress 12 docs/_research/*.md files
epic: E-002
capability: CAP-002
registry_id: cf-2026-04-18-compress-research-docs
status: done
github_issue: 5
priority: medium
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - docs/_research/2026-03-25_claude-code-recent-improvements.md
  - docs/_research/2026-03-25_sprint-loop-compatibility.md
  - docs/_research/2026-03-26_code-sweep-improvements.md
  - docs/_research/2026-03-26_code-sweep.md
  - docs/_research/2026-03-26_loop-tactics-standards.md
  - docs/_research/2026-04-08_sprint-carryforward-registry.md
  - docs/_research/2026-04-16_agent-reliability.md
  - docs/_research/2026-04-16_caveman-compress-input-side.md
  - docs/_research/2026-04-16_caveman-token-minimization.md
  - docs/_research/2026-04-16_plugin-agent-strategy.md
  - docs/_research/2026-04-16_subagent-type-selection.md
  - docs/_research/2026-04-18_caveman-full-absorption.md
verify:
  - "test $(find docs/_research -name '*.md.original' | wc -l) -ge 12"
  - "bash hooks/scripts/reference-compression-validate.sh"
done: 12 research docs have .original backups; structural validator passes.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

12 `docs/_research/*.md` files are prose-dense and currently uncompressed. Per `docs/_research/2026-04-18_caveman-full-absorption.md` recommendation §Phase 2 step 2, run `/blitz:compress` on each. Expected aggregate saving: 25-40 KB input per load (10-15% per file — higher than reference.md wave-1 ratio due to higher prose density in research docs).

Excludes the today-written `2026-04-18_runtime-artifact-terse-propagation.md` — it was authored already at `full` intensity per Finding 3 of that doc; compressing further risks auto-pause-boundary violations on its own LITE-marker proposals.

## Acceptance Criteria

1. 12 `.original` backups exist under `docs/_research/`.
2. `find docs/_research -name '*.md.original' | wc -l` ≥ 12.
3. `bash hooks/scripts/reference-compression-validate.sh` exits 0.
4. No research doc's `scope:` YAML frontmatter is altered — the validator's heading + URL + code-fence checks catch this, but worth manual spot-check on the 2 April-18 docs since their `scope:` blocks are load-bearing for the roadmap.

## Implementation Notes

Batch invocation:

```bash
/blitz:compress docs/_research/2026-03-25_claude-code-recent-improvements.md docs/_research/2026-03-25_sprint-loop-compatibility.md docs/_research/2026-03-26_code-sweep-improvements.md docs/_research/2026-03-26_code-sweep.md docs/_research/2026-03-26_loop-tactics-standards.md docs/_research/2026-04-08_sprint-carryforward-registry.md docs/_research/2026-04-16_agent-reliability.md docs/_research/2026-04-16_caveman-compress-input-side.md docs/_research/2026-04-16_caveman-token-minimization.md docs/_research/2026-04-16_plugin-agent-strategy.md docs/_research/2026-04-16_subagent-type-selection.md docs/_research/2026-04-18_caveman-full-absorption.md
```

## Dependencies

None. Parallel to S2-004 and all E-001 stories.
