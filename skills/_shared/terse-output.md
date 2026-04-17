# Terse Output Protocol

Blitz's output-compression directive for skills and spawned agents. Inspired by the caveman-mode pattern (MIT, github.com/JuliusBrussee/caveman) and internalized here so blitz has no runtime dependency on external plugins.

**Purpose:** reduce model output tokens 20–40% without sacrificing technical accuracy. Applies to orchestrator-to-user prose, agent-to-orchestrator reports, findings summaries, decision rationale. Does NOT apply to structured artifacts, code, or exact-match payloads.

---

## Core rule

Speak technical-first, filler-free. Format preferred: `[subject] [verb] [reason]. [next action].`

**Drop:**
- Articles (a / an / the) where the meaning is unambiguous without them
- Fillers: *just, really, basically, actually, simply, quite, very*
- Pleasantries and preambles: *sure, certainly, I'd be happy to, let me*
- Hedging: *it seems, perhaps, maybe, arguably, somewhat*
- Trailing summaries of work already evident in the diff or tool output

**Keep:**
- Exact technical vocabulary and proper nouns
- Code (verbatim)
- File paths, URLs, commands, CLI flags
- Version numbers, dates, error codes
- Numbers, identifiers, grep patterns
- Headings and list structure

---

## Intensity levels

| Level | Description | When to use |
|---|---|---|
| `lite` | Drop fillers and pleasantries; keep full sentences | Default for user-facing orchestrator output |
| `full` | Fragments allowed; articles dropped; telegraphic | Agent-to-orchestrator reports; verification summaries |
| `ultra` | Maximum compression; symbol shorthand allowed | Internal checkpoint markers; bulk status lines |

Skills SHOULD declare an intended level in their SKILL.md frontmatter (`output_style: lite|full|ultra`). Default when unspecified: `lite`.

---

## Preservation boundary (non-negotiable)

Never compress:

1. Fenced code blocks (` ``` ... ``` `) and inline code (`` `...` ``)
2. YAML frontmatter and JSON bodies
3. File paths and URLs
4. Grep patterns, regex strings, exact-match phrases inside tables
5. Commit messages and PR descriptions (rendered verbatim elsewhere)
6. Scope blocks, registry entries, DoD checklists — every field must parse
7. Commands the user might copy-paste
8. Error messages and stack traces quoted for diagnosis

If compression would alter any of the above, write the original form. Correctness dominates brevity.

---

## Auto-pause conditions

Temporarily drop terse mode and write normally when:

- Reporting a security warning or credential risk
- Confirming an irreversible action (delete, force-push, drop-table)
- The user appears confused by prior terse output (explicit ask for clarification)
- Explaining a non-obvious root cause where compressed prose would lose the reasoning chain

Resume terse mode on the next response.

---

## Examples

| Verbose (before) | Terse (after) |
|---|---|
| "I'd be happy to take a look at that bug. Let me search the codebase and find where the issue might be." | "Investigating bug. Searching codebase." |
| "It seems like the problem is basically that the cache isn't being invalidated when the user updates their profile." | "Cache not invalidated on profile update." |
| "I've completed the refactor. Here's a summary of what I changed: I updated three files to use the new API, removed the deprecated helper, and added tests." | "Refactor done. Three files migrated to new API, deprecated helper removed, tests added." |
| "Sure! In order to fix this, we should probably just add a null check." | "Add null check." |

---

## Integration points in blitz

1. **Spawn protocol** — every Agent() prompt template should append: *"Output style: terse-technical per `/_shared/terse-output.md`. Preserve code, paths, commands, structured fields verbatim. No preamble, no trailing summary."* See `spawn-protocol.md`.

2. **SKILL.md Additional Resources** — skills that produce user-facing output should list this file alongside `context-management.md`.

3. **`/blitz:compress`** — the file-compression skill applies these same rules to rewrite markdown files at author time. This doc is the reference spec for that skill.

---

## Credit

The directive structure, intensity tiers, and preservation-rule framing are adapted from caveman-mode (JuliusBrussee/caveman, MIT). The integration surface (spawn-protocol injection, SKILL.md references, file-rewriter skill) is blitz-specific.
