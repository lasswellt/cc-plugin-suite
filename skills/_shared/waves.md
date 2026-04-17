# Wave Execution Protocol

Shared spec for wave-based execution in blitz orchestrator skills. Waves enable parallel execution within dependency-graph-ordered batches.

**Why this doc exists**: the concept was embedded inline in `sprint-dev` Phase 1.4 and partially mirrored in `verbose-progress.md`, `checkpoint-protocol.md`, and `context-management.md` with no single source of truth. Extracting it here eliminates drift and makes adoption by future skills clearer — while also being explicit about when *not* to use waves.

---

## Definition

A **wave** is a topological layer of a dependency DAG: the maximal set of work units whose declared prerequisites are satisfied by prior waves, enabling full parallelism within each wave.

The metaphor is explicit: a wave rolls forward after the preceding wave is fully complete.

---

## Gate: Do You Actually Have a DAG?

**Waves deliver value only when there is a directed dependency graph between units of work.** Before adopting this protocol, answer:

- Do your work units have declared `depends_on: [<id>...]` fields?
- Are any of those dependencies non-trivial (i.e., unit B actually cannot start until unit A finishes)?

**If no**: your work is a flat pool of independent units. Do NOT adopt waves. Run a simple parallel spawn with a polling completion check. Examples of flat pools in blitz: `codebase-audit` (10 independent pillars), `research` (2-4 independent investigators), `sprint-plan` (parallel researchers).

**If yes**: waves are appropriate. Continue reading.

Current adopters: `sprint-dev` (story DAG from `depends_on` fields).

Potential future adopters: `roadmap` Phase 7 (foundation epics before feature epics — weak case; optional).

---

## Dependency Resolution Algorithm

**Input**: a set of work units, each with optional `depends_on: [<id>...]` field.

**Algorithm** (Kahn's topological sort layered):

1. Compute in-degree for each unit from the `depends_on` edges.
2. **Wave 0**: all units with in-degree 0.
3. **Wave N**: all units whose dependencies are ALL in Waves 0..N-1 (in-degree becomes 0 after prior waves are removed).
4. Continue until all units are assigned to a wave.

**Invalid**: a cycle in the DAG causes some units to never reach in-degree 0. Hard-fail with a cycle report. Do not attempt partial execution.

**Critical path**: the longest dependency chain determines the minimum number of waves.

---

## Size Caps

**No built-in size cap.** The calling skill decides how many parallel agents are available per wave.

If a single wave exceeds available agent slots, sub-batch within the wave using a caller-specified priority ordering. `sprint-dev` uses: `schema/type > server > store > component > test`.

---

## Worker Pool Semantics

- **Within a wave**: all units may execute in parallel.
- **Between waves**: no unit in Wave N may start until all units in Wave N-1 are complete (or explicitly skipped with a documented reason that must appear in the final report).
- **Completion polling**: the orchestrator polls completion via the harness Task API (e.g., `TaskList`), not sleep-wait. Output-file existence checks (per `agent-workload-sizing.md`) confirm each unit actually wrote its deliverable.

---

## Progress Reporting Hooks

The wave protocol ties into the shared progress-reporting conventions:

**Wave start**: emit one status line per wave declaring size and unit ids starting.

**Unit completion**: update the in-memory tracker; check wave-complete condition.

**Wave completion**:
- Emit the Wave Progress block per [verbose-progress.md](verbose-progress.md) "Wave Progress Reporting" section.
- Write the wave checkpoint per [checkpoint-protocol.md](checkpoint-protocol.md) (STATE.md update).
- Trigger compact summary per [context-management.md](context-management.md) (wave boundary is one of the trigger points).
- Commit + push via `git commit -m "<type>(<skill>): wave N complete"` so progress survives loop restarts.

---

## Checkpoint Behavior

Wave boundaries are the natural pause points for orchestrator modes:

- **`autonomous`**: no user pause at wave boundaries; commit + push only.
- **`checkpoint`**: pause after wave completion; present results; await user confirmation before Wave N+1 begins.
- **`interactive`**: per-unit confirmation; waves are still computed but user control is at unit granularity.

STATE.md must include a Wave Progress table when a skill uses waves; the schema is defined in [checkpoint-protocol.md](checkpoint-protocol.md).

---

## Opting In

A skill adopts wave execution by:

1. Declaring a dependency graph on its units of work (e.g., stories with `depends_on:` fields).
2. Computing waves via the algorithm above in a "Phase X: Build Dependency Graph and Compute Waves" section.
3. Referencing this doc in its Additional Resources:
   ```markdown
   - For wave-based dependency ordering and execution protocol, see [waves.md](/_shared/waves.md)
   ```
4. Implementing the progress-reporting hooks above.
5. Adding a Wave Progress table to its STATE.md schema if it uses checkpointing.

No new frontmatter field is needed — adoption is expressed through skill behavior, not metadata.

---

## Risks and Non-Adoption

- **Cargo-cult adoption**: future skill authors may reach for waves as a "standard pattern" on flat-pool orchestrators. The Gate section above is the guard. Examples called out explicitly as non-adopters: `codebase-audit`, `research`, `sprint-plan`, `sprint-review`.
- **Explicit `depends_on` modeling cost**: if dependencies are soft/informational (e.g., "it would be nice if backend review saw the security review first"), the bookkeeping cost of declaring them may exceed the scheduling benefit. Leave such cases as flat pools.
- **Error recovery stays in calling skill**: this spec deliberately does not define wave-level rollback or skipped-unit semantics. Those belong to the calling skill's own error handling.

---

## Related

- [subagent-types.md](subagent-types.md) — which subagent type to spawn as a wave worker
- [agent-workload-sizing.md](agent-workload-sizing.md) — weight-class caps per worker
- [checkpoint-protocol.md](checkpoint-protocol.md) — STATE.md schema for resuming mid-sprint
- [verbose-progress.md](verbose-progress.md) — Wave Progress Reporting format
- [context-management.md](context-management.md) — wave boundary as compact-summary trigger
