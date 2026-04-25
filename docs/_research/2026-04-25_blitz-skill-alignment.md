---
scope:
  - id: cf-2026-04-25-sprint-from-research-autochain
    unit: files
    target: 3
    description: |
      Wire research → roadmap → sprint into a single autonomous chain.
      Edit skills/sprint/SKILL.md (Pre-Flight 1b: detect uningested
      docs/_research/*.md and auto-invoke roadmap extend), skills/research/
      SKILL.md (Phase 4.2 follow-up table: add roadmap extend row), and
      skills/next/SKILL.md (Phase 0: read carry-forward.jsonl).
    acceptance:
      - grep_present:
          pattern: 'docs/_research.*-newer.*roadmap-registry'
          min: 1
      - grep_present:
          pattern: 'roadmap extend'
          min: 1
      - grep_present:
          pattern: 'carry-forward\.jsonl'
          min: 1
---

# Blitz Skill Suite — Cycle Alignment + April 2026 CC Feature Adoption

## 1. Summary

Blitz skill suite is end-to-end coherent **once a roadmap exists and the carry-forward registry is seeded**. Cycle `research → roadmap → sprint-plan → sprint-dev → sprint-review → release` is closed via four shared registries (`sprint-registry.json`, `roadmap-registry.json`, `epic-registry.json`, `carry-forward.jsonl`) plus the activity feed. Single blocking manual step: `research → roadmap extend`. `/sprint` Pre-Flight (sprint/SKILL.md:L202) does not detect uningested `docs/_research/*.md`, so a user with research in context who runs `/sprint` is told "No roadmap. Run `/blitz:roadmap` first." On the platform side, blitz already adopts `isolation: worktree`, TaskCreate/TaskList, TeammateIdle, TaskCompleted hooks. Major un-adopted April-2026 features: `Monitor` tool, `PreCompact`/`PostCompact` hooks, CronCreate-backed `/loop`, `UserPromptExpansion` hook for skill self-routing, forked subagents w/ per-agent mcpServers, `PushNotification` for sprint completion. Recommendation: 3-file edit to close the research→sprint loop now, then a follow-up sprint to adopt PreCompact + Monitor.

## 2. Research Questions

| Q | Answer |
|---|---|
| Are the 36 skills aligned through cycles? | Yes — registry-driven handoffs are coherent. One manual gap: `research → roadmap extend`. |
| Does `/sprint` auto-ingest research in context? | **No.** Pre-Flight checks roadmap-registry/epic-registry only. |
| Smallest fix to close that gap? | 3 file edits: sprint/SKILL.md Pre-Flight 1b, research/SKILL.md Phase 4.2 table, next/SKILL.md Phase 0. |
| Which April 2026 CC features are NOT yet used? | Monitor, PreCompact/PostCompact, CronCreate-backed `/loop`, UserPromptExpansion, forked subagents w/ agent-scoped mcpServers, PushNotification. |
| Which patterns are community converging on? | Activity-feed JSONL (blitz already does this), PreCompact→SessionStart state pair, plan-mode-as-gate (RIPER), TaskCreate/List native task tools (Simone). |
| Highest-leverage feature to adopt next? | PreCompact hook — long sprints lose state on auto-compact today. |

## 3. Findings

### 3.1 Cycle graph (codebase-analyst)

Skill cycle graph from `.claude-plugin/skill-registry.json` + actual content:

| Skill | Writes | Reads |
|---|---|---|
| `research` | `docs/_research/*.md` (+ `scope:` YAML) | — |
| `roadmap` (extend) | `roadmap-registry.json`, `epic-registry.json`, `capability-index.json`, `carry-forward.jsonl` | research docs |
| `sprint-plan` | `sprints/sprint-N/stories/*.md`, `sprint-registry.json`, `carry-forward.jsonl` (auto-waivers) | epic-registry, carry-forward, planning-inputs |
| `sprint-dev` | `STATE.md`, story status | stories, sprint-registry |
| `sprint-review` | `sprint-(N+1)-planning-inputs.json`, `carry-forward.jsonl` invariants | sprint-registry, STATE.md, carry-forward |
| `sprint` (orchestrator) | — | all of the above |
| `next` | — | sprint-registry, roadmap-registry, activity-feed |

The carry-forward registry is the load-bearing piece: 4 writers, 2 readers, append-only, latest-wins reduction, rollover_count escalation at ≥3.

### 3.2 Misalignments

1. **Research → roadmap is fully manual.** `sprint/SKILL.md:L202` Pre-Flight only checks for `roadmap-registry.json`/`epic-registry.json`. Loop Step 2 decision tree rows 1–8 has no row for "research docs exist but not ingested." Result: `/research` then `/sprint` fails with "No roadmap. Run `/blitz:roadmap` first." (codebase-analyst §3.1)
2. **`next/SKILL.md` lacks carry-forward awareness.** Phase 0 reads sprint-registry, STATE.md, activity-feed, git status, roadmap — but not `carry-forward.jsonl`. Diverged from `sprint` loop decision tree. Can output "nothing to do" while registry has active entries. (codebase-analyst §3.2)
3. **`research/SKILL.md` Phase 4.2 follow-up table omits `roadmap extend`.** Suggests `sprint-plan` directly for "architecture decision made," skipping roadmap ingestion. (codebase-analyst §3.1)
4. **`capability-index.json` is write-only.** Written by roadmap Phase 1.4, never read by sprint-plan (data flows through epic-registry instead). Not a functional gap, just dead-end storage. (codebase-analyst §3.3)
5. **Qualitative research docs produce no registry entry.** `scope:` block emitted only on quantified claims; qualitative docs use `<!-- no-registry -->` waiver and are not tracked. Sprint-review Invariant 1 catches missing scope at sprint-close, not research-time. (codebase-analyst §3.4)

### 3.3 April 2026 CC features (library-docs + web-researcher)

| Feature | Version | Description |
|---|---|---|
| **Monitor tool** | v2.1.98 (Apr 9) | Streams stdout of background script as session events; event-driven, zero token cost when silent. |
| **PreCompact / PostCompact hooks** | v2.1.105 | Fire before/after context compaction. Exit 2 from PreCompact to halt; receives `compaction_stats` in PostCompact. |
| **CronCreate / CronList / CronDelete** | v2.1.72+ | Schedule cron tasks within a session. Backs `/loop`. 7-day session-scope expiry. |
| **PushNotification tool** | v2.1.110 | Mobile push via Remote Control. |
| **Skill tool** | v2.1.108 | Model can invoke built-in slash commands via ToolSearch (`/init`, `/review`). |
| **UserPromptExpansion hook** | stable | Fires when slash command expands. Can rewrite/inject context. |
| **Forked subagents** | v2.1.117 | Subagents can spawn sub-subagents. |
| **Agent-scoped MCP servers** | v2.1.117 | Subagent YAML can declare its own `mcpServers` set — restricts permission surface. |
| **`paths:` skill frontmatter** | new | Glob-scoped auto-activation per file pattern. |
| **`when_to_use:` skill field** | new | Separate from description for invocation routing. |
| **`user-invocable: false`** | new | Hide skill from `/` menu; Claude-only. |
| **`memory:` field on subagents** | new | `user`/`project`/`local` persistent cross-session memory. |
| **Sandbox settings** | new | Filesystem + network isolation per session. |
| **`if:` conditional hook filters** | v2.1.85 | Hook-level guard. |
| **MCP Channels** | v2.1.81 (preview) | MCP servers push messages into sessions; CI can push test failures. |
| **Routines (cloud, no machine)** | new | 1-hour minimum, machine-independent scheduled agents. |

### 3.4 Community skill patterns

- **RIPER-5** (https://github.com/tony/claude-code-riper-5) — Research → Innovate → Plan → Execute → Review enforced phases, plan-mode-as-gate.
- **Simone** (https://github.com/Helmi/claude-simone) — Native TaskCreate/TaskList for cross-session project mgmt.
- **cc-tools** (https://github.com/Veraticus/cc-tools) — Go hooks + PreCompact session state pattern.
- **happy** (https://github.com/slopus/happy) — Background CC instances + PushNotification when human input needed.
- **viwo** (https://github.com/OverseedAI/viwo) — Docker + worktree per agent.

Convergent pattern: **JSONL activity feed at `.cc-sessions/activity-feed.jsonl`** — blitz already does this; community is ratifying it.

### 3.5 Blitz adoption status

| Feature | Adopted? | Where / Where to add |
|---|---|---|
| `isolation: worktree` | YES | sprint-dev |
| TaskCreate/TaskList/TaskUpdate | YES | sprint-dev |
| TeammateIdle hook | YES | — |
| TaskCompleted hook | YES | — |
| Monitor tool | NO | sprint-dev Phase 3 polling loop → event-driven |
| PreCompact / PostCompact | NO | hooks/hooks.json + sprint-dev/code-sweep state snapshot |
| CronCreate-backed `/loop` | NO | sprint --loop, ui-audit --loop |
| UserPromptExpansion | NO | next, ask, blitz:* prefix → inject activity-feed context |
| Forked subagents + agent mcpServers | NO | sprint-dev backend/frontend/test agents — each gets typed MCP set |
| PushNotification | NO | sprint-dev / ship completion |
| MCP Channels | NO (preview) | CI failure push |

## 4. Compatibility Analysis

- All proposed features require Claude Code ≥ v2.1.98 (Monitor) or ≥ v2.1.105 (PreCompact). Blitz registry already declares `compatibility: ">=2.1.71"` on multiple skills — bump to `">=2.1.117"` once forked subagents / agent mcpServers are adopted.
- `scope:` YAML contract (carry-forward registry) is internal — no CC version dependency.
- `Monitor`, `PreCompact`, `UserPromptExpansion` are non-breaking additions; existing skills work unchanged.
- Registry schema (`.cc-sessions/carry-forward.jsonl`, `epic-registry.json`) has stabilized in v1.6.0 and is the integration substrate; no migration needed.
- Three-file fix (Recommendation §5.1) is purely additive — no risk of breaking existing flows.

## 5. Recommendation

### 5.1 Immediate (this PR) — close research→sprint loop

Three file edits, no schema changes, fully backward compatible:

**A. `skills/sprint/SKILL.md`** — add Pre-Flight step 1b after line ~202:

```bash
# 1b. Uningested research check
UNINGESTED=$(find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null | head -5)
if [ -n "$UNINGESTED" ]; then
  echo "[sprint] Uningested research detected — invoking roadmap extend before sprint"
  # Dispatch to /blitz:roadmap extend, then re-read roadmap-registry.json before continuing
fi
```

Loop Step 2 decision tree: insert new row 0 above current rows: "Uningested research docs (newer than roadmap-registry.json) → invoke `roadmap extend`, exit cleanly so loop re-enters at row 1."

**B. `skills/research/SKILL.md`** — Phase 4.2 follow-up table: change first row from `sprint-plan` to `roadmap extend → "Ingest research into roadmap, seeds carry-forward registry"`. Add explicit note: "After research with `scope:` blocks, run `/blitz:roadmap extend` (or `/blitz:sprint`, which will auto-detect and chain)."

**C. `skills/next/SKILL.md`** — Phase 0: add carry-forward read mirroring `sprint/SKILL.md` Step 1. Decision logic: if `CF_ACTIVE > 0` and no in-progress sprint, recommend `/blitz:sprint` (not "nothing to do").

### 5.2 Next sprint — platform feature adoption

Priority order:

| # | Feature | Skill | Why |
|---|---|---|---|
| 1 | `PreCompact` + `SessionStart:resume` pair | hooks.json + sprint-dev | Long sprints lose state on auto-compact today — highest blitz failure mode |
| 2 | `Monitor` tool | sprint-dev Phase 3 | Replace polling with event-driven; cuts tokens, faster reaction |
| 3 | `UserPromptExpansion` hook | blitz:* prefix | Inject activity-feed context into every blitz invocation |
| 4 | Forked subagents + agent-scoped `mcpServers` | sprint-dev | Specialize MCP set per agent (backend=db, frontend=playwright, test=read-only) |
| 5 | `CronCreate`-backed `/loop` | sprint --loop, ui-audit --loop | Survive idle; document Routines for nightly CI |
| 6 | `PushNotification` | sprint-dev, ship | Notify on async completion |

## 6. Implementation Sketch

### Step 1 — Pre-Flight 1b in sprint/SKILL.md

Locate `## Pre-Flight Checks` section at L~200. Insert after step 1:

```markdown
### Step 1b: Uningested Research Detection

Before checking sprint state, scan for research docs newer than the roadmap registry:

\```bash
if [ -d docs/_research ]; then
  ROADMAP_MTIME=$(stat -c %Y roadmap-registry.json 2>/dev/null || echo 0)
  UNINGESTED=$(find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null)
  if [ -n "$UNINGESTED" ]; then
    echo "[sprint] Uningested research:"
    echo "$UNINGESTED" | sed 's/^/  /'
    echo "[sprint] Auto-invoking /blitz:roadmap extend"
    # Dispatch roadmap extend skill (in --loop mode: queue + exit; in normal mode: invoke and continue)
  fi
fi
\```

In --loop mode: emit decision row 0 ("ingest research") and exit so loop re-enters cleanly. In normal mode: invoke `/blitz:roadmap extend` synchronously, then proceed to Step 2 with refreshed registry.
```

Update loop Step 2 decision table (L~86): add row 0 "Uningested research → `roadmap extend`, exit clean."

### Step 2 — research/SKILL.md Phase 4.2 update

Replace the row in the follow-up table (L~345):

```markdown
| Research with `scope:` block written | `roadmap extend` | Ingest into capability-index + carry-forward registry. Required before sprint. |
| Architecture decision, ready to plan | `sprint` (auto-chains roadmap extend if needed) | Single command kicks off ingestion + planning + dev. |
```

### Step 3 — next/SKILL.md Phase 0 carry-forward read

Insert after existing observation block:

```bash
CF_ACTIVE=$(jq -s '
  group_by(.id) | map(max_by(.ts))
  | map(select(.status == "active" or .status == "partial"))
  | length
' .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "0")
```

Decision logic: if `CF_ACTIVE > 0` and `STATE.md` absent → recommend `/blitz:sprint`. If `CF_ESCALATED > 0` (rollover_count ≥ 3) → escalate per `_shared/carry-forward-registry.md`.

### Step 4 — registry bump

`.claude-plugin/skill-registry.json`: bump `version` to `1.4.0`, `updated` to `2026-04-25`, add note: "research→roadmap auto-chain; carry-forward in next/."

## 7. Risks

The research→sprint auto-chain has one important failure mode: a research doc with a malformed `scope:` block will cause `/blitz:roadmap extend` to hard-fail mid-chain when invoked from `/sprint`. Today the user invokes roadmap extend explicitly, sees the error, and fixes it. With auto-chaining, the error appears as a sprint-time failure — confusing because the user did not ask for a roadmap operation. **Mitigation:** before auto-invoking, validate scope blocks parse cleanly; if not, surface the validation error with the doc path and ask the user to confirm before chaining. Auto-chain should fail loud, not silent.

A second risk is the `find -newer roadmap-registry.json` heuristic. If the user manually edits an old research doc to fix a typo, the mtime updates and the doc looks "uningested" — but it has already been ingested, and re-ingestion will hard-fail on duplicate scope ids (per `roadmap` Phase 1.1.5). **Mitigation:** check whether the doc's `scope.id` values already exist in `carry-forward.jsonl` before treating it as uningested. If all ids are present, skip — even if mtime is newer.

Third risk: `next/SKILL.md` and `sprint/SKILL.md` decision trees diverge over time as one is edited and the other isn't. **Mitigation:** factor the carry-forward read into a shared `_shared/carry-forward-detect.md` snippet referenced by both skills, similar to how `verbose-progress.md` is referenced everywhere.

**Open questions:**

1. Should `/sprint` auto-chain `roadmap extend` *silently*, or always print "ingesting N research docs first"? Loud is safer; user wanted "automatic" so silent is implied. Recommend: print one summary line, do not gate on user confirm in --loop mode.
2. Should `research/SKILL.md` Phase 4.2 still suggest `/sprint` directly (auto-chain) or always recommend the explicit `/blitz:roadmap extend` first? Auto-chain reduces friction; explicit is more transparent. Recommend auto-chain with prominent log line.
3. Should the PreCompact hook (§5.2 priority 1) live in `hooks/hooks.json` (plugin-wide) or per-skill `hooks:` frontmatter (sprint-dev only)? Per-skill is narrower — only fires when sprint-dev is active. Recommend per-skill to start.

## 8. References

- `skills/sprint/SKILL.md:L86-L96` (loop Step 2 decision tree)
- `skills/sprint/SKILL.md:L202` (Pre-Flight step 1)
- `skills/research/SKILL.md:~L345` (Phase 4.2 follow-up table)
- `skills/research/SKILL.md:~L192` (Phase 3.1.1 scope block emission)
- `skills/roadmap/SKILL.md:L165` (Phase 1.4 capability-index write)
- `skills/sprint-plan/SKILL.md:L37` (Phase 0.1 glob — capability-index NOT included)
- `skills/sprint-review/SKILL.md:L393, L401` (Invariants 1 + 5)
- `skills/next/SKILL.md:L17-L73` (Phase 0 — no carry-forward read)
- `skills/_shared/carry-forward-registry.md` (registry contract)
- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Hooks reference: https://code.claude.com/docs/en/hooks
- Sub-agents reference: https://code.claude.com/docs/en/sub-agents
- Agent teams: https://code.claude.com/docs/en/agent-teams
- Scheduled tasks: https://code.claude.com/docs/en/scheduled-tasks
- Monitor tool guide: https://claudefa.st/blog/guide/mechanics/monitor
- Session memory guide: https://claudefa.st/blog/guide/mechanics/session-memory
- Awesome CC index: https://github.com/hesreallyhim/awesome-claude-code
- RIPER-5: https://github.com/tony/claude-code-riper-5
- Simone: https://github.com/Helmi/claude-simone
- cc-tools: https://github.com/Veraticus/cc-tools
- happy: https://github.com/slopus/happy
- viwo: https://github.com/OverseedAI/viwo
