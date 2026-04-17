---
id: S1-003
title: Blitz-native /blitz:compress skill (file-rewriter)
epic: caveman-concepts-absorbed
status: done
priority: P0
points: 3
depends_on: [S1-001, S1-002]
assigned_agent: backend-dev
files:
  - skills/compress/SKILL.md
  - .claude-plugin/skill-registry.json
verify:
  - "test -f skills/compress/SKILL.md"
  - "python3 -c \"import json; d=json.load(open('.claude-plugin/skill-registry.json')); assert any(s['name']=='compress' for s in d['skills'])\""
  - "grep -q 'output_style: exact' skills/compress/SKILL.md"
done: "Skill file exists, is registered in skill-registry.json under the meta category, declares preservation rules cross-referenced to terse-output.md, includes UNSAFE-marker refusal logic, and describes the .original-backup + validator-run workflow."
---

# S1-003 — Blitz-native /blitz:compress skill

## Description

Internalize caveman-compress as a blitz skill — no Python runtime, no external plugin. `/blitz:compress <file>` rewrites a markdown/text file into terse form per the Terse Output Protocol (S1-002), writes a `.original` backup before modifying, and runs the structural validator (S1-001) to catch drift. On validator failure the skill auto-restores from backup.

Replaces the previous S1-003 (which required running external caveman).

## Acceptance Criteria

1. `skills/compress/SKILL.md` exists with proper YAML frontmatter (`name: compress`, `model: sonnet`, `allowed-tools` list).
2. Skill is registered in `.claude-plugin/skill-registry.json` under `category: meta` with `modifies_code: true`.
3. Input rejection rules documented: code/config extensions refused; existing `.original` sibling skipped; size >500KB refused.
4. Phase 1 backup logic specified (Read + Write, byte-count verification).
5. Phase 2 preservation rules mechanically enumerated: code fences, URLs, file paths, headings, table rows, inline code, YAML/JSON blocks, grep patterns.
6. Phase 2 UNSAFE markers listed — skill refuses to touch files containing agent-prompt templates, "Grep Patterns by Check" heading, or `output_style: exact` frontmatter opt-out.
7. Phase 3 auto-restore on validator failure specified (`mv <file>.original <file>` returns to pre-compress state).
8. Phase 4 summary format defined — one line per target: complete / rejected / failed / skipped.
9. Operator responsibility for git-commit is called out (skill does NOT auto-commit).

## Implementation Notes

Skill is orchestrator-style: the model reads the target, applies rules, writes the result. Caveman-compress's Python implementation is replaced by Claude's own text-rewriting behavior — cheaper to maintain, zero dependencies.

Credit to upstream in the final section of SKILL.md (MIT attribution).

## Dependencies

- S1-001 (validator must exist for Phase 3 to work)
- S1-002 (terse-output.md is the preservation spec referenced from SKILL.md)
