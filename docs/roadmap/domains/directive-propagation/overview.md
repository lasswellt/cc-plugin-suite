**Output style:** terse-technical per `/_shared/terse-output.md`. Fragments OK.

# Domain — Directive Propagation

## Capabilities

- **CAP-001** — Extend terse-output reference across agents, SKILL.md gap, shared protocols (Phase 1)
- **CAP-003** — Inject runtime terse directive at write-sites and Agent() prompts (Phase 2)
- **CAP-007** — Upgrade WARNING → BLOCKER after coverage + one clean sprint (Phase 4)

## Mission

Close the 0%-runtime-reach gap identified in `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` Finding 1. 25/34 SKILL.md link terse-output.md passively; 0 re-assert at write-site; 0 of 7 UNSAFE reference.md inject the §7 canonical snippet. Progressive fix: passive refs (CAP-001) → active directives (CAP-003) → enforcement (CAP-007).

## Existing modules

- `skills/_shared/terse-output.md` — directive spec (95 lines)
- `skills/_shared/spawn-protocol.md:307-329` — §7 mandate + canonical snippet
- `agents/architect.md`, `agents/backend-dev.md`, `agents/doc-writer.md`, `agents/frontend-dev.md`, `agents/reviewer.md`, `agents/test-writer.md` (6 agent files, all missing terse-output ref today)

## No new modules needed

All work is additive edits to existing files. Zero greenfield.

## Acceptance pattern

Every edit in this domain is grep-verifiable — no human-interpretation acceptance criteria. See epic-registry.json stories for the exact grep patterns per story.

## Sequencing rationale

CAP-001 (passive refs) lands before CAP-003 (active directives) so that when CAP-003 inserts `per /_shared/terse-output.md` into a SKILL.md write-phase, the reader has the canonical directive already context-adjacent in Additional Resources. CAP-007 gates behind one clean sprint post-CAP-003 to avoid trapping an in-flight sprint into BLOCKER failure.
