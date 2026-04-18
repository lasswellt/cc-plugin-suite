---
id: S3-002
title: Inject spawn-protocol §7 OUTPUT STYLE snippet into 7 UNSAFE reference.md
epic: E-003
capability: CAP-003
registry_id: cf-2026-04-18-unsafe-ref-agent-prompt-injection
status: planned
github_issue: 7
priority: high
points: 2
depends_on: []
assigned_agent: doc-writer
files:
  - skills/codebase-audit/reference.md
  - skills/codebase-map/reference.md
  - skills/code-sweep/reference.md
  - skills/integration-check/reference.md
  - skills/quality-metrics/reference.md
  - skills/sprint-dev/reference.md
  - skills/sprint-plan/reference.md
verify:
  - "test $(grep -l 'OUTPUT STYLE: terse-technical per /_shared/terse-output.md' skills/*/reference.md | wc -l) -ge 7"
done: 7 UNSAFE reference.md files contain the verbatim spawn-protocol §7 OUTPUT STYLE snippet.
---

**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

## Description

Per `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` §A.2, `skills/_shared/spawn-protocol.md:309` mandates every Agent() prompt include the canonical OUTPUT STYLE snippet, yet 0/7 UNSAFE reference.md files containing agent-prompt templates inject it. Sprint-review's `WARNING (not BLOCKER)` on line 328 would fire for every spawn today. This story is the prerequisite for CAP-007 (upgrade to BLOCKER) in Sprint 5.

## Acceptance Criteria

1. Each of the 7 listed UNSAFE reference.md files contains the verbatim 5-line OUTPUT STYLE snippet (from `spawn-protocol.md:313-319`).
2. `grep -l 'OUTPUT STYLE: terse-technical per /_shared/terse-output.md' skills/*/reference.md | wc -l` returns ≥7.
3. Snippet placed after the shared preamble's WRITE-AS-YOU-GO clause (or nearest equivalent) in each agent-prompt template.
4. Manual edit required — files are UNSAFE for `/blitz:compress`. Edit each file by hand or via `Edit` tool; do not batch-rewrite.

## Implementation Notes

Canonical snippet (verbatim from `skills/_shared/spawn-protocol.md:313-319`):

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

Target insertion lines (from research doc §3 agent-prompt audit):

| File | Prompts | Insert location |
|---|---|---|
| skills/sprint-dev/reference.md | 4 (line 12, 76, 141, 205) | Top of each role prompt |
| skills/sprint-plan/reference.md | 4 (line 304, 333, 365, 398); shared preamble at 286-299 | After WRITE-AS-YOU-GO |
| skills/codebase-audit/reference.md | 1 templated pillar (line 12) | Top of pillar prompt |
| skills/codebase-map/reference.md | 4 dimension agents | Top of each dimension prompt |
| skills/code-sweep/reference.md | tier agents | Top of tier prompt |
| skills/integration-check/reference.md | 3 domain agents | Top of each domain prompt |
| skills/quality-metrics/reference.md | collector agents | Top of collector prompt |

## Dependencies

None. Parallel to S3-001 and S3-003.
