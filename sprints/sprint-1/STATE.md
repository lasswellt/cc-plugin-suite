# Sprint 1 — STATE

**Last updated:** 2026-04-16
**Status:** in-progress — 4/5 stories done
**Pivot note:** caveman concepts absorbed natively, zero external dependency.

## Completed (4/5)

| Story | Title | Files touched |
|---|---|---|
| S1-001 | Reference-compression validator | `hooks/scripts/reference-compression-validate.sh`, `hooks/hooks.json` |
| S1-002 | Terse-output directive | `skills/_shared/terse-output.md`, `skills/_shared/spawn-protocol.md` (§7) |
| S1-003 | `/blitz:compress` skill | `skills/compress/SKILL.md`, `.claude-plugin/skill-registry.json` |
| S1-004 | terse-output.md referenced from 25 SKILL.md | 25 SKILL.md files (19 via script, 2 edge-case manual, 3 substantive new-block); 9 exempt |

## Planned (1/5)

| Story | Title | Blocker |
|---|---|---|
| S1-005 | Apply `/blitz:compress` to 12 SAFE reference.md files | Requires fresh Claude session where `/blitz:compress` is in the loaded skill registry. Not invokable from the current session (skill was added mid-session). |

## S1-004 exempt files (9, documented)

Thin orchestrators / routers: `ask`, `sprint`, `implement`, `review`, `ship` — they dispatch to other skills that carry the reference.
Utility / read-only: `next`, `health`, `quick`, `todo` — minimal narrative output, some with explicit verbose-progress exemption.

## Verification run

- `bash hooks/scripts/reference-compression-validate.sh` → exit 0 (0 pairs, expected — S1-005 not yet run)
- `python3 -c "import json; json.load(open('hooks/hooks.json'))"` → OK
- `python3 -c "import json; d=json.load(open('.claude-plugin/skill-registry.json')); print(len(d['skills']))"` → 34
- `grep -l 'terse-output.md' skills/*/SKILL.md | wc -l` → 25
- `python3 scripts/add-terse-output-reference.py --check` → exit 0 (idempotent, nothing to add)
- `grep -q 'Terse Output Protocol' skills/_shared/spawn-protocol.md` → match

## Next steps for operator

**Option A — fresh session (recommended for S1-005):**
Open a new Claude session in this repo so the plugin loader picks up `skills/compress/SKILL.md`. Then run:
```
/blitz:compress skills/browse/reference.md
/blitz:compress skills/sprint-review/reference.md
/blitz:compress skills/test-gen/reference.md
/blitz:compress skills/ui-build/reference.md
/blitz:compress skills/refactor/reference.md
/blitz:compress skills/research/reference.md
/blitz:compress skills/retrospective/reference.md
/blitz:compress skills/release/reference.md
/blitz:compress skills/dep-health/reference.md
/blitz:compress skills/quality-metrics/reference.md
/blitz:compress skills/migrate/reference.md
/blitz:compress skills/codebase-map/reference.md
```
Confirm each produced `reference.md.original`, then `bash hooks/scripts/reference-compression-validate.sh` → exit 0. Spot-check 2 files. Commit.

**Option B — defer S1-005 and commit what's done.**
Sprint 1 closes at 4/5; S1-005 rolls to Sprint 2.

## Rollback notes

- Deleted: `scripts/compress-references.sh` (wrong direction — external caveman dependency)
- Deleted: obsolete story files `S1-002-compress-references-wrapper.md`, `S1-003-compress-safe-reference-files.md`
- Nothing committed yet — full pivot is in the working tree only.
