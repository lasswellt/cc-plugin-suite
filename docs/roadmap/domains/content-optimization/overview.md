**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Domain — Content Optimization

## Capabilities

- **CAP-002** — Wave-2 author-time compression: 7 SAFE reference.md + 12 research docs (Phase 1)
- **CAP-006** — Extract agent-prompt boilerplate to shared fragment; refactor 7 UNSAFE reference.md to import (Phase 3)

## Mission

Reduce input-token cost of blitz skill loading and agent spawning via two distinct mechanisms:

1. **Author-time compression** (CAP-002) — existing `/blitz:compress` skill runs over the SAFE input files left after sprint-1's S1-005 wave. Expected aggregate saving: 25-40 KB.
2. **Boilerplate dedup** (CAP-006) — ~20-30% reduction on the ~12 K tokens/sprint spent on Agent() prompt templates. Works by extracting HEARTBEAT spec + PARTIAL protocol + weight-class caps + session-registration template into a single shared fragment imported at runtime.

## Existing modules

- `skills/compress/SKILL.md` — runtime compressor handles all CAP-002 work; no new code required
- `hooks/scripts/reference-compression-validate.sh` — structural validator fires at commit time
- `sprints/sprint-1/STATE.md` — S1-005 precedent for UNSAFE rule

## New modules

- `skills/_shared/agent-prompt-boilerplate.md` — single-source fragment imported by the 7 UNSAFE reference.md. Content derived in CAP-006 Story E006-S01 by extracting redundant sections from codebase-audit, codebase-map, code-sweep, integration-check, quality-metrics, sprint-dev, sprint-plan reference.md files.

## Sequencing rationale

CAP-002 is purely parallel, no deps. CAP-006 depends on CAP-003 (OUTPUT STYLE snippet injected into the UNSAFE files before dedup so the dedup extracts stable content). Phase 3 ordering: CAP-005 work runs in parallel with CAP-006; each has its own parallel workstream in `phase-plan.json`.

## Parity requirement

CAP-006 must not change agent behavior. Story E006-S03 validates this by dumping the resolved prompt for one test Agent() spawn pre- and post-refactor and diffing byte-for-byte.
