---
id: S1-002
title: Blitz-native terse-output directive and spawn-protocol integration
epic: caveman-concepts-absorbed
status: done
priority: P0
points: 2
depends_on: []
assigned_agent: backend-dev
files:
  - skills/_shared/terse-output.md
  - skills/_shared/spawn-protocol.md
verify:
  - "test -f skills/_shared/terse-output.md"
  - "grep -q 'Terse Output Protocol' skills/_shared/spawn-protocol.md"
  - "grep -q 'OUTPUT STYLE: terse-technical' skills/_shared/spawn-protocol.md"
done: "Directive file exists; spawn-protocol.md has a Section 7 that mandates injecting the terse snippet into every Agent() prompt template, with preservation boundary, auto-pause rules, and credit to upstream caveman."
---

# S1-002 — Blitz-native terse-output directive

## Description

Absorb the caveman-mode prompt pattern into blitz as a first-class, tool-agnostic directive. The directive lives at `skills/_shared/terse-output.md` and is injected into every Agent() prompt template via a new Section 7 in `skills/_shared/spawn-protocol.md`. No external plugin dependency — blitz owns the rule text.

This story replaces the previous S1-002 (wrapper around external `caveman-compress`) following the operator's clarification that caveman's *concepts* should be internalized, not that caveman should be installed.

## Acceptance Criteria

1. `skills/_shared/terse-output.md` exists and documents:
   - Core rule (drop/keep lists)
   - Three intensity levels: `lite`, `full`, `ultra`
   - Preservation boundary (8 non-negotiable categories)
   - Auto-pause conditions
   - Before/after examples
   - Credit to upstream caveman
2. `skills/_shared/spawn-protocol.md` has a new Section 7 titled "Output Style (Terse Output Protocol)" that mandates the snippet for every Agent() spawn.
3. The mandatory snippet in Section 7 is explicit about preserving code, paths, patterns, and structured fields.
4. "How to Reference This Doc" block updated to include "output style" in the capability list.
5. Sprint-review WARNING hook wired (textual in the new section) — absence of the snippet in an Agent prompt flagged as non-BLOCKER.

## Implementation Notes

Directive is intentionally standalone (not buried inside spawn-protocol.md) because it's also referenced by `/blitz:compress` (S1-003) as the canonical preservation spec.

Expected savings per research doc: 20–40% output-token reduction across spawned agents, with zero impact on structured artifacts.

## Dependencies

None.
