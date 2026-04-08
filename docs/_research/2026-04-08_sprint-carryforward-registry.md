# Sprint Carry-Forward Registry — Preventing Silent Scope Drops in blitz --loop

**Date**: 2026-04-08
**Research Type**: Architecture Decision (blitz plugin self-improvement)
**Triggering incident**: Modal standardization (CAP-133) — research promised 130 files; 84 shipped; 46 silently dropped across sprint-197 → sprint-198; roadmap marked "107/107 complete"
**Baselines**:
- `docs/_research/2026-04-02_modal-consistency.md` (130-file scope claim)
- `docs/_research/2026-04-08_modal-standardization-finish-state.md` (forensic audit of the drop)
- blitz skills: `research`, `roadmap`, `sprint-plan`, `sprint-dev`, `sprint-review`, `sprint` (with `--loop`)

---

## Summary

The blitz sprint --loop silently dropped 46 files of promised CAP-133 scope because **no persistent registry links research-doc scope claims to delivered artifacts**, and **auto-waiver in `full` autonomy writes carry-forward state into a single sprint manifest that the next sprint's planner never reads**. The drop is not caused by any one bug — it's the expected behavior of the current state machine, which has no coverage gate, no rollup, no stalled-item query, and no parent-scope audit.

The industry answer is unambiguous: **(1)** an append-only JSONL registry with structured scope metrics (target vs delivered), **(2)** a KEP-style status enum that makes `partial` and `dropped` first-class, **(3)** a sprint-close invariant that refuses to mark an epic done while a child registry entry is `active` or `partial`, and **(4)** a loop exit guard that checks registry coverage before declaring "nothing to do." Implementation is one new file (`.cc-sessions/carry-forward.jsonl`), four SKILL.md patches, and one pre-sprint-close invariant check — roughly the size of the `activity-feed.jsonl` feature already in the repo.

---

## Research Questions — Answers

| # | Question | Answer |
|---|---|---|
| 1 | Where exactly does blitz --loop lose track of carried-forward work? | At the **epic-registry level**. `sprint-plan/SKILL.md:320` auto-waives unmet ACs into `manifest.carry_forward`, but the epic's `status` field in `epic-registry.json` is never updated with coverage % or a carry-forward count. Sprint-198 planner queries epic-registry, sees `status: done`, and never re-selects CAP-133's epic. |
| 2 | How does research → capability → epic → story link work today? | One-way: `capability-index.json` stores `source_document: "<research-doc-path>"` at capability level (`roadmap/SKILL.md:159`). Epic schema has **no** `source_research_doc` field. Story schema has **no** back-link either. There is no "expected scope" field anywhere — scope claims are extracted as narrative prose, not as a structured `{unit, target}` metric. |
| 3 | Agile best practices for spillover/DoD coverage? | Scrum.org: *stop saying "carryover"* — dissolve unfinished PBIs and force re-planning. Mountain Goat: rollover count as a metric; `>=2` triggers escalation. Atlassian: burn-**up** charts for epics so scope growth is visible. Shape Up: no auto-continuation — unfinished work must be re-shaped into a new pitch. |
| 4 | How do Linear/Jira/GH Projects/Shortcut/ADO model carry-forward? | **Linear** cycles auto-roll unfinished issues with an audit trail and health enum. **Jira** refuses to close a sprint if a child subtask is outside the rightmost column. **GitHub** ships sub-issues + dependencies (blocked-by/blocking) GA Aug 2025. **Shortcut** archives abandoned stories with explicit revival flag. **ADO** rolls up numeric metrics (not just counts) through Epic → Feature → Story → Task. |
| 5 | What registry structure prevents bulk-story collapse? | 8 load-bearing fields: `id`, `source` (doc+anchor), `parent` (capability/epic), `scope` (`{unit,target}`), `delivered` (`{unit,actual,last_sprint}`), `status` (KEP enum), `last_touched` (`{sprint,date}`), and `drop_reason`+`revival_candidate` (required when dropped). Append-only JSONL, latest-wins semantics — matches the existing `activity-feed.jsonl` convention. |
| 6 | What guardrails block a sprint from closing with partial parent scope? | Four invariants, all enforceable by a single `sprint-review` check: (a) quantified scope claims in research must have a registry entry; (b) `status==active` entries must be touched this sprint or explicitly deferred; (c) roadmap "N/N complete" must cross-check registry coverage; (d) `coverage < 1.0 AND status==active` auto-carries into next sprint's planning inputs (Linear semantics). |

---

## Findings (Organized by Theme)

### Theme 1 — The Drop Mechanism Is a State-Machine Hole, Not a Bug

The exact sequence of silent drop in the CAP-133 case, traced to file:line ([codebase-analyst.md](#references), full table in § "Exact Sequence"):

1. **sprint-plan S197**: Phase 4.1 AC-coverage gate runs. 46 of 130 files are uncovered. Autonomy is `full` (loop mode), so `sprint-plan/SKILL.md:320` auto-waives them into `manifest.carry_forward` and logs a `decision` event to the activity feed. **No epic-registry update.**
2. **sprint-dev S197**: Agent implements S197-004 on 84 files. Build passes. Story marked `done`. **No re-check of AC coverage.**
3. **sprint-review S197**: Type-check / lint / test gates pass. Report tables the story as `done`. **No AC-coverage audit, no cross-check against the originating research doc, no epic-registry mutation.**
4. **sprint-plan S198**: Phase 0 step 6 reads "incomplete stories" (`status: incomplete|in-progress`) — S197-004 is `done`, so not selected. Line 80 selects epics with `status: in-progress` — E001 is still `planned` (or `done`), so not selected. **Carry-forward list in the S197 manifest is never read.**
5. **sprint --loop** `SKILL.md:67` decision tree queries epic-registry, sees all epics `done|blocked`, prints "Nothing to do", and idles cleanly.

**Four independent locations where the chain could have broken the drop but didn't:**

| Gate | Current behavior | What it should do |
|---|---|---|
| Waiver decision | Auto-approve + log to activity feed | Auto-approve + write `status:partial` to registry with coverage % |
| Sprint review close | Ignore manifest.carry_forward | Refuse close if any child registry entry is `active`/`partial` without explicit defer |
| Next-sprint plan input | Query incomplete stories + in-progress epics | Also query registry for `status ∈ {active, partial}` and inject as mandatory planning inputs |
| Loop idle detection | Epics all `done|blocked`? → exit | Epics all `done|blocked` **AND registry has zero `active|partial`**? → exit |

### Theme 2 — Zombie Scrum Is the Named Anti-Pattern

The incident is a textbook instance of three overlapping anti-patterns from the literature:

- **Zombie Scrum** (Scrum.org) — *"items from the sprint backlog get carried over to the next sprint without question."* Ceremonies look healthy; empiricism is dead.
- **Ticket decay** (Philipp Flenker) — the longer a ticket sits, the more its context decays; the fix is short-TTL tickets that either execute or die.
- **Zombie work** (Atlassian Rovo, 2025) — *"any issue that looks active but is functionally blocked, quietly aging out of sprints."* Atlassian ships a dedicated detector because the pattern is ubiquitous.

All three prescriptions converge on the same mechanism: **explicit re-surfacing**. A registry/ledger of delayed items that must be reviewed each cycle, with items aging past N sprints triggering hard escalation.

### Theme 3 — "Migrate 130 Files via Glob" Is a Spike Dressed as a Story

The S197-004 story violated every well-known decomposition rule:

- **SPIDR** (Mountain Goat / Mike Cohn): for a 130-file migration, the **Data** axis is the right split — by route, feature area, or author. S197-004 was a horizontal "all layers, all files" story that delivers value only at the end, which is why it rolled over twice.
- **Batch-size control** (Allen Holub, Planview): small batches have exponentially better flow metrics. A 5-point story touching 130 files is outside any sane WIP policy. *"When the team can't articulate AC beyond 'it compiles', that's a spike, not a story."*
- **Shape Up "hammer scope, don't cut"** (Basecamp): if a project doesn't ship in its appetite, it does not automatically continue. It goes back to the shaper for a fresh pitch. No silent carry.

**Implication for blitz sprint-plan**: a linter-style rule that flags stories with `files.length > N` or descriptions matching "all X" / "via pattern" / "across the codebase" should force an interactive split (or a mandatory `spidr_split` field justifying the large scope) before accepting the story.

### Theme 4 — The Registry Pattern Is Well-Precedented

Every mature tool we surveyed has **the same two missing elements** that blitz lacks:

1. **A numeric rollup metric** (not just count-of-children). Azure DevOps, Linear milestones, and Jira burn-up charts all track `delivered/target` as a ratio. A binary "done/not done" on 130 files hides the 45% state.
2. **A partial/dropped status that is not implicit.** KEP's `implementable | implemented | deferred | rejected | withdrawn | replaced`, PEP's `Deferred | Superseded | Withdrawn`, and Shortcut's "archived with revival path" all make abandonment loud, not silent.

The Kubernetes KEP pattern is the closest fit for blitz: a **machine-readable sibling file** (`kep.yaml`) alongside the human-readable proposal prose. blitz should adopt the same: research docs stay prose, and a companion JSONL entry carries the structured metadata.

### Theme 5 — Capability-Level DoD Must Be Executable

The strongest single insight from the web research: **capability-level DoD should be an executable grep/AST check, not a checklist item**. For CAP-133, the DoD should have been:

```
grep -r 'from.*shared/ConfirmDialog' apps/web/src/ | wc -l   # must be 0
grep -r 'class="modal-overlay"'       apps/web/src/ | wc -l   # must be 0
grep -r 'import AdminModal'           apps/web/src/ | wc -l   # must be 0
grep -r 'from.*@mbk/ui.*Modal'        apps/web/src/ | wc -l   # must be > 30
```

This is **verifiable in milliseconds and cannot be marked done dishonestly**. blitz's `completeness-gate` skill already exists but checks overall code health; it needs to accept per-capability DoD rules as inputs from the registry.

---

## Compatibility Analysis — Fit With Current blitz Architecture

| blitz primitive | Current role | What changes |
|---|---|---|
| `.cc-sessions/activity-feed.jsonl` | Append-only event log | Unchanged. Registry entries reference it for event history. |
| `capability-index.json` (roadmap) | Capability → source doc link | Extend with `source_scope: {unit, target}` for quantified claims. |
| `epic-registry.json` (roadmap) | Epic status + coverage | **Add** `source_research_doc`, `ac_count`, `ac_met`, `coverage`, `carry_forward_count` fields. |
| `sprints/sprint-N/manifest.json` | Sprint metadata + carry_forward array | **Add** `waived_ac_count`, `reason_waivers`. Emit a registry write when waivers are logged. |
| `.cc-sessions/carry-forward.jsonl` | **NEW** | Append-only JSONL registry, latest-wins by `id`. Mirrors activity-feed conventions. |
| `completeness-gate` skill | Overall code health scan | **Extend** to consume per-capability DoD rules from registry entries. |
| `skills/sprint-plan/SKILL.md:64-66` | "Check incomplete stories" | **Extend** to query registry for `status ∈ {active, partial}`. |
| `skills/sprint-review/SKILL.md` | Sprint close | **Add** a "registry invariants" phase: fail close if any child entry is active/partial without explicit defer. |
| `skills/sprint/SKILL.md:67` | Loop idle detection | **Add** registry query to decision tree — idle only if registry has no active/partial entries. |
| `skills/research/SKILL.md` Phase 3 | Prose research doc | **Add** optional `## Scope` block with structured `scope:` YAML frontmatter the roadmap can parse. |
| `skills/roadmap/SKILL.md` extend mode | Adds epics from research docs | **Add** registry write for every quantified scope claim found in the source doc. |

**No new tools.** No new services. No schema migration. Every change is additive to existing JSON files and SKILL.md flows.

**Dependency on filesystem conventions**: the blitz plugin already relies on `.cc-sessions/` for cross-session state. The registry lives there naturally.

**Back-compat**: old sprints without registry entries are unaffected. The sprint-review invariant only fails if a registry entry exists and is stale — greenfield behavior is a no-op.

---

## Recommendation

**Ship a three-part fix**, ordered by leverage:

### Part A — Registry (highest leverage, smallest change)

Add `.cc-sessions/carry-forward.jsonl` as an append-only JSONL registry, and teach `skills/research`, `skills/roadmap` extend, and `skills/sprint-plan` auto-waiver to write to it. This alone makes silent drops visible.

### Part B — Invariants at sprint close

Add one phase to `skills/sprint-review/SKILL.md` that enforces four invariants against the registry:

1. Every quantified scope claim in a research doc touched this sprint has a registry entry.
2. Every `status==active` entry was touched this sprint OR explicitly transitioned to `deferred`/`dropped`.
3. Roadmap `N/N complete` must cross-check registry coverage; mismatch fails the gate.
4. Any entry with `coverage < 1.0 AND status==active` automatically injects into the next sprint's planning inputs (Linear semantics).

### Part C — Loop guard

One-line change to `skills/sprint/SKILL.md:67` decision tree: idle exit requires **both** "all epics done|blocked" **and** "registry has zero active|partial entries."

### Comparison matrix (rejected alternatives)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| Fix sprint-plan carry-forward logic only | Small diff | Leaves epic-registry blind; no coverage rollup; bulk stories still collapse | **Rejected** — treats symptom not cause |
| Full rewrite using Linear/Jira integration | Mature tooling | External dependency; blitz is file-based by design | **Rejected** — violates design constraint |
| Add fields to epic-registry only (no new file) | No new file | Not append-only; loses audit trail; can't reference from activity-feed | **Rejected** — append-only is the insight |
| **JSONL registry + invariants + loop guard** | Append-only, auditable, file-based, uses existing conventions | Requires coordinated changes across 5 skills | **Selected** — matches blitz design patterns |
| Shape Up-style "no carry, always re-pitch" | Cleanest semantics | Too aggressive a UX change for current users | **Partially adopted** — status enum includes `dropped` with explicit revival path, but soft auto-carry is retained |

---

## Implementation Sketch

### Step 1 — Create the registry schema

New file: `.cc-sessions/carry-forward.jsonl`. Append-only. One JSON object per line. Updates are new lines with the same `id`; **latest wins** on `id`. Example:

```jsonl
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-02T10:00:00Z","event":"created","source":{"doc":"docs/_research/2026-04-02_modal-consistency.md","anchor":"§Scope"},"parent":{"capability":"CAP-133","epic":"EPIC-105"},"scope":{"unit":"files","target":130,"description":"Migrate modal components to @mbk/ui Modal.vue"},"delivered":{"unit":"files","actual":0,"last_sprint":null},"coverage":0.0,"status":"active","last_touched":{"sprint":"sprint-197","date":"2026-04-03"},"children":[],"blocker":null,"drop_reason":null,"revival_candidate":false,"notes":""}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-03T18:30:00Z","event":"progress","delivered":{"unit":"files","actual":84,"last_sprint":"sprint-197"},"coverage":0.646,"status":"partial","last_touched":{"sprint":"sprint-197","date":"2026-04-03"},"children":["S197-004"]}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-04T09:15:00Z","event":"auto_waived","waived_count":46,"reason":"autonomy=full auto-waiver at sprint-plan Phase 4.1"}
```

Canonical status enum (borrowed from KEP + PEP): `provisional | active | partial | complete | deferred | dropped | replaced`.

### Step 2 — Teach `skills/research` to emit structured scope

In `skills/research/SKILL.md` Phase 3, when a finding includes a quantified target (regex: `\d+\s+(files|components|modals|tests|routes|...)`), emit a YAML frontmatter block:

```yaml
---
scope:
  - id: cf-2026-04-02-modal-consistency
    unit: files
    target: 130
    description: Migrate modal components to @mbk/ui Modal.vue
    acceptance:
      - grep_absent: "class=\"modal-overlay\""
      - grep_absent: "from.*shared/ConfirmDialog"
      - grep_min: { pattern: "from.*@mbk/ui.*Modal", min: 30 }
---
```

`skills/roadmap` extend mode parses this block and writes a new registry line on first ingestion.

### Step 3 — Extend epic-registry + sprint manifest schemas

`skills/roadmap/reference.md`:

```json
// epic schema additions
"source_research_doc": "docs/_research/2026-04-02_modal-consistency.md",
"registry_entries": ["cf-2026-04-02-modal-consistency"],
"acceptance_criteria_count": 130,
"acceptance_criteria_met": 84,
"acceptance_criteria_waived": 46,
"coverage": 0.646,
"carry_forward_count": 46
```

`skills/sprint-plan/reference.md` manifest schema additions:

```json
"waived_ac_count": 46,
"reason_waivers": "autonomy=full",
"registry_entries_touched": ["cf-2026-04-02-modal-consistency"]
```

### Step 4 — Patch `skills/sprint-plan/SKILL.md:64-80` (context loading)

```
6. Check for incomplete stories AND registry carry-forward.
   a. Find stories from prior sprints with status: incomplete | in-progress.
   b. Read .cc-sessions/carry-forward.jsonl. For each entry where
      status ∈ {active, partial} AND coverage < 1.0, select its parent
      epic for re-planning EVEN IF all child stories are marked done.
      These entries are mandatory planning inputs — the next sprint MUST
      either include work toward them or explicitly transition them to
      deferred with a written reason.
```

And at Phase 4.1 (line 320) — replace silent auto-waiver with a mandatory registry write:

```
If autonomy is high or full, auto-waive uncovered ACs:
  - Append to manifest.carry_forward (existing behavior).
  - Log the waiver as a decision event to activity-feed (existing).
  - NEW: Append an event to .cc-sessions/carry-forward.jsonl with
    event: "auto_waived", waived_count: N, reason: "autonomy=<mode>".
  - NEW: Update the parent registry entry's status to "partial" if it
    was "active", or leave "partial" otherwise.
```

### Step 5 — Add `sprint-review` invariants phase

New phase at the end of `skills/sprint-review/SKILL.md` (before status transition):

```
Phase N — Registry Invariants (HARD GATE)

1. Load .cc-sessions/carry-forward.jsonl. Reduce to latest-wins by id.
2. For each entry with status ∈ {active, partial}:
   a. Was it touched this sprint (last_touched.sprint == current sprint)?
      If no — fail gate. Require explicit transition to deferred/dropped
      with a reason, or an explanation of why it's still active untouched.
3. For every epic selected in this sprint's manifest, cross-check:
   coverage from registry >= coverage claimed in epic-registry?
   If no — fail gate and print the delta.
4. If roadmap claims "N/N epics complete", verify no registry entry has
   status ∈ {active, partial} — if any exist, fail gate.
5. Any coverage < 1.0 AND status == active entry auto-injects into the
   next sprint's planning inputs via a pointer in
   sprints/sprint-(N+1)-planning-inputs.json.
```

### Step 6 — Patch `skills/sprint/SKILL.md:67` loop guard

```
7. No active sprint + all epics done|blocked
   + .cc-sessions/carry-forward.jsonl has zero entries with
     status ∈ {active, partial}
   → Nothing to do. Print status and exit.

   Otherwise: plan a gap-closure sprint targeting the outstanding
   registry entries.
```

### Step 7 — Bulk-story guard in sprint-plan (Part of Part A safety net)

In `skills/sprint-plan/SKILL.md` Phase 3 story generation, after drafting each story:

```
Check:
  - If story.files.length > 8 OR story description matches
    /all \w+|across the codebase|via (pattern|glob)|every \w+/i,
    print a SPIDR-split warning and require either:
    a. Manual approval to proceed with a large-scope story, OR
    b. Automatic split along the SPIDR Data axis (by route,
       feature folder, or file path prefix).
  - In loop mode (autonomy=full), option (a) is disallowed. The story
    MUST be split or downgraded to a spike.
```

### Step 8 — Backfill existing incident (one-time)

Write an initial registry line for CAP-133 reflecting current state:

```jsonl
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-08T00:00:00Z","event":"backfilled","source":{"doc":"docs/_research/2026-04-02_modal-consistency.md"},"parent":{"capability":"CAP-133","epic":"EPIC-105"},"scope":{"unit":"files","target":130},"delivered":{"unit":"files","actual":84,"last_sprint":"sprint-197"},"coverage":0.646,"status":"partial","last_touched":{"sprint":"sprint-197","date":"2026-04-03"},"notes":"Backfilled during registry rollout; see 2026-04-08_modal-standardization-finish-state.md for finish plan"}
```

Running a loop tick after this backfill should automatically surface CAP-133 as a mandatory planning input for the next sprint — proving the fix works by closing the original incident.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| False positives — registry entries that legitimately exist without sprint touches (e.g., deferred research) | Medium | Low | Status enum includes `deferred`; entries with `deferred` don't trigger invariants. Require `drop_reason` on dropped status. |
| Registry drift from reality (entry says partial but code is fully migrated) | Medium | Medium | `completeness-gate` runs the executable DoD checks (grep/AST) and auto-reconciles registry coverage. `sprint-review` calls the gate before closing. |
| Pre-existing sprints have no registry entries — backfill burden | High | Low | One-time backfill script. Scan `docs/_research/` for quantified claims, match against roadmap epics, write initial entries. Existing sprints without entries are unaffected. |
| Auto-inject into planning inputs creates planning loops | Low | Medium | Rollover counter (inspired by Atlassian spillover pattern) — any entry with `rollover_count >= 3` escalates to mandatory human review instead of auto-inject. Prevents infinite bounce. |
| JSONL grows unbounded | Low | Low | Append-only but latest-wins semantics via `jq` reducer mean effective size is O(unique ids). Ship a compaction step in `skills/retrospective`. |
| User workflow disruption — sprint-review gate fails unexpectedly on legacy drift | Medium | Low | Feature-flag the invariants phase behind `blitz.strict_registry: true` in settings. Default off for one release cycle; default on once backfill is validated. |
| Research skill scope extraction is lossy (misses quantified claims) | Medium | Medium | Scope block is opt-in YAML, not auto-parsed prose. Authors explicitly declare the block; roadmap extend refuses to ingest research docs with quantified language but no scope block (hard-fail at extend time). |
| Bulk-story guard creates friction for legitimate large changes | Low | Low | Guard is advisory in non-loop modes; hard gate only in `autonomy=full`. Human operators can override with a single flag. |

### Open questions

- **Who owns revival prioritization for dropped entries?** WSJF vs RICE vs age-sorted? — defer to a follow-up research spike; for now, dropped entries surface in the next `retrospective` run for human triage.
- **Should the registry live in the blitz plugin source, or in the consumer project's `.cc-sessions/`?** The activity feed lives in the consumer project, so the registry should too. Keeping them co-located is the low-surprise choice.
- **Does `skills/research` today emit anything structured that we can piggyback on?** Answer from codebase-analyst: no — research docs are prose-only today. Teaching research to emit the scope YAML block is the first prerequisite change.

---

## References

### Blitz skill files cited (file:line)
- `skills/sprint/SKILL.md:55-67` — loop decision tree, idle-exit logic
- `skills/sprint-plan/SKILL.md:64-66, 80, 241-262, 298-320` — context loading, epic selection, story generation, AC-coverage gate, auto-waiver
- `skills/sprint-dev/SKILL.md` — no AC recheck
- `skills/sprint-review/SKILL.md:38-40` — story status categorization
- `skills/roadmap/SKILL.md:159, 214-246, Phase 7-8` — capability-index writes, codebase assessment coverage, epic-registry mutations
- `skills/roadmap/reference.md:12, 77, 309-341, 452-462, 545+` — capability schema, coverage field, epic schema gap, tracker, epic-registry
- `skills/research/SKILL.md` Phase 3 — prose-only research doc output

### Agile & process research
- Scrum.org — ["Why We Need to Stop Talking About 'Carryover'"](https://www.scrum.org/) and ["Zombie Scrum — Symptoms, Causes and Treatment"](https://www.scrum.org/)
- Mountain Goat Software — ["Spillover in Agile: 3 Ways to Break an Unfinished Work Habit"](https://www.mountaingoatsoftware.com/) and ["SPIDR: Five Simple but Powerful Ways to Split User Stories"](https://www.mountaingoatsoftware.com/)
- Atlassian Community — ["Zombie Work Detector"](https://community.atlassian.com/) (2025) and ["How to track how many times a story has been spilled over"](https://community.atlassian.com/)
- Philipp Flenker — ["Ticket Decay: How Short-Term Tickets Foster Long-Term Stability"](https://philippflenker.com/)
- Basecamp Shape Up — Chapters 3 & 14 (["Set Boundaries"](https://basecamp.com/shapeup), ["Decide When to Stop"](https://basecamp.com/shapeup))
- less.works — ["Dealing with Spill-over Items"](https://less.works/) (2024)
- Allen Holub & Planview — ["Measuring Batch Size, WIP, and Throughput"](https://www.planview.com/)
- Pragmatic Engineer & incident.io — postmortem action-item follow-through studies (2024)
- dan luu — [`danluu/post-mortems`](https://github.com/danluu/post-mortems)

### Tooling references
- [Linear docs — Cycles](https://linear.app/docs/cycles), [Initiatives](https://linear.app/docs/initiatives), [Project Milestones](https://linear.app/docs/project-milestones)
- [Atlassian — Complete a Jira sprint](https://support.atlassian.com/jira-software-cloud/docs/complete-a-sprint/)
- [GitHub Blog — Issue Dependencies GA (Aug 2025)](https://github.blog/changelog/2025-08-21-dependencies-on-issues/), [Sub-issues docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies)
- [Shortcut — Archiving FAQ](https://help.shortcut.com/hc/en-us/articles/360018662831-Archiving-in-Shortcut-FAQ) and [Hierarchy](https://help.shortcut.com/hc/en-us/articles/360044698631)
- [Azure DevOps — Display rollup columns](https://learn.microsoft.com/en-us/azure/devops/boards/backlogs/display-rollup), [Feature Progress Power BI](https://learn.microsoft.com/en-us/azure/devops/report/powerbi/sample-boards-featureprogress)
- [Atlassian — Burn-up charts](https://www.atlassian.com/agile/project-management/burn-up-chart)
- [Aha! Discovery](https://www.aha.io/discovery/overview), [FitGap traceability chain writeup](https://us.fitgap.com/stack-guides/build-a-requirements-traceability-chain-from-customer-insight-to-shipped-outcomes)

### Proposal-to-implementation ledgers (precedent for the JSONL format)
- [Kubernetes Enhancement Proposals (KEP) — kep.yaml template](https://github.com/kubernetes/enhancements/blob/master/keps/NNNN-kep-template/README.md)
- [Python PEP header format](https://peps.python.org/pep-0001/)
- [Rust RFC process and known weaknesses](https://internals.rust-lang.org/t/improve-format-of-rust-rfc-like-python-pep/20180)

### RTM tradition
- [TestRail — Requirements Traceability Matrix guide](https://www.testrail.com/blog/requirements-traceability-matrix/)
- [Ketryx — RTM in Agile best practices](https://www.ketryx.com/) (2024)
- [Jama Software — RTM how-to](https://www.jamasoftware.com/requirements-management-guide/requirements-traceability/how-to-create-and-use-a-requirements-traceability-matrix-rtm/)

### Supporting blitz-internal research docs
- `docs/_research/2026-04-02_modal-consistency.md` — original 130-file scope claim
- `docs/_research/2026-04-08_modal-standardization-finish-state.md` — forensic audit of the drop incident
- `docs/_research/2026-03-25_sprint-loop-compatibility.md` — prior loop-compat research informing the sprint --loop design
