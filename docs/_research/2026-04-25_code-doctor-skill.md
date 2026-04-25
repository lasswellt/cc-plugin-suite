---
scope:
  - id: cf-2026-04-25-code-doctor-skill
    unit: files
    target: 4
    description: |
      New skill `blitz:code-doctor`: scaffold SKILL.md, reference.md, registry
      entry, and marketplace entry. Focus is framework-API misuse detection
      (Firestore/VueFire/Pinia/Vue), with bridges to code-sweep for the
      generic dead-code/duplication checks already covered there.
    acceptance:
      - shell: "test -f skills/code-doctor/SKILL.md"
      - shell: "test -f skills/code-doctor/reference.md"
      - grep_present:
          pattern: '"code-doctor"'
          min: 1
      - grep_present:
          pattern: 'code-doctor'
          min: 1
---

# Research: `blitz:code-doctor` — Framework-Aware Code Quality Skill

## 1. Summary

User wants a skill that finds (a) dead code, (b) duplication → shared extraction candidates, (c) inefficiencies, (d) **framework-API incorrectness** (Firestore, VueFire). Categories (a)–(c) are already substantially covered by `blitz:code-sweep` (30 checks, 7 categories, ratchet, auto-fix) and `blitz:codebase-audit` (5-pillar audit, 10 parallel agents). Category (d) — *framework-specific anti-pattern detection with concrete grep/AST rules and auto-fix recipes* — is the genuine gap. Recommend a focused new sibling skill `blitz:code-doctor` that owns framework-API correctness, and explicitly delegates (a)–(c) to `code-sweep` via a chained workflow rather than re-implementing them.

## 2. Research Questions

| # | Question | Answer |
|---|---|---|
| Q1 | Does an existing skill cover dead code? | Yes. `code-sweep` category includes "find TODOs, dead code, optimize". Reference has detection patterns. |
| Q2 | Does an existing skill cover duplication / DRY extraction? | Partial. `codebase-audit` reference.md:163,177 lists duplication as a checklist item but no detection patterns or auto-fix; `code-sweep` covers it as a standard. |
| Q3 | Does any skill cover Firestore/VueFire API misuse? | **No.** Zero matches for `firestore` or `vuefire` across `skills/`. This is the real gap. |
| Q4 | Should this be a new skill or an extension to `code-sweep`? | New sibling skill. `code-sweep` is generic+ratcheting; framework rules churn fast and benefit from isolated reference.md + targeted agent prompts. |
| Q5 | What's the minimum viable check set? | ~25 rules: 10 Firestore, 5 VueFire, 5 Vue 3, 5 Pinia. See §4. |
| Q6 | Auto-fix or detect-only? | Both modes. Detect-only by default (`--scan`), opt-in `--fix` for low-risk transforms (e.g., `onUnmounted` cleanup wiring, missing `await`). |

## 3. Findings

### 3.1 Overlap matrix with existing skills

| Concern | code-sweep | codebase-audit | refactor | simplify | **gap** |
|---|---|---|---|---|---|
| Dead code | ✅ rules+auto-fix | ✅ checklist | — | — | none |
| Duplication → extraction | ✅ standards | ✅ checklist (no patterns) | ✅ executes after detection | ✅ post-hoc on diffs | weak detection patterns |
| Inefficiencies (perf hotspots) | partial | ✅ Performance pillar | — | — | runtime profiling lives in `perf-profile` |
| **Framework API misuse** | ❌ | ❌ | ❌ | ❌ | **THIS** |

### 3.2 Firestore/VueFire anti-patterns to detect

High-confidence patterns drawn from common Firebase consulting findings:

| # | Anti-pattern | Detection | Severity |
|---|---|---|---|
| F1 | `getDocs` inside a loop instead of `where(... 'in' ...)` batch | grep `for.*await getDocs` within 5 lines | major |
| F2 | Listener registered without `onUnmounted`/cleanup → memory leak | AST: `onSnapshot(` in `<script setup>` w/o `onUnmounted` in same file | critical |
| F3 | `serverTimestamp()` written client-side then read in same op (returns null) | grep `serverTimestamp\(\)` and same doc read same tx | major |
| F4 | Missing composite index hint — queries with multiple `where`+`orderBy` | grep multi-`where` + `orderBy` calls | minor |
| F5 | `.docs.map(d => d.data())` losing `id` | grep that exact pattern | major |
| F6 | Reading entire collection (`getDocs(collection(...))`) without `limit()` | AST: `getDocs(collection(` not followed by `.limit(` or `query(` | major |
| F7 | Writing inside a transaction read phase | `runTransaction` with `tx.set` before `tx.get` | critical |
| F8 | `updateDoc` with non-existent doc (no merge) | flag if not preceded by existence check | minor |
| F9 | Per-component duplicate listeners on same doc | cross-file: same `doc(...,id)` in >1 component | major |
| F10 | Security rules read in client code | grep `firestore.rules` import in src | minor |
| V1 | `useDocument`/`useCollection` in non-setup context | AST: composable call outside `<script setup>` or `setup()` | critical |
| V2 | VueFire ref dereferenced without `.value` in template | grep `{{\s*\w+Ref\s+\.}}` heuristic | major |
| V3 | `useFirestore()` called repeatedly per component | count occurrences per file > 1 | minor |
| V4 | Reactive query built outside `computed` (won't update) | `query(.*\$\{.*\}.*)` outside computed | major |
| V5 | `useCollection` on unbounded collection (no `query` wrapper) | grep `useCollection(collection(` | major |

Vue/Pinia bonus (carryover from common review findings):
- `ref()` for object that should be `reactive()` — followed by `.value.x = ...` mutations.
- Pinia store mutations outside actions.
- `watch(() => store.x)` where `storeToRefs` would be cleaner.
- Unkeyed `v-for` with index as key when list reorders.
- `v-if` + `v-for` on same element.

### 3.3 Detection mechanism

Three tiers, in priority order:

1. **Grep rules** (90% of patterns): fast, false-positive prone, runs in <1s on typical repo. Stored in `reference.md` as `id|pattern|severity|fix-hint` rows.
2. **AST rules** (for context-sensitive checks like F2/V1): use `tsc --noEmit` + a small TS-Compiler-API helper script committed to `skills/code-doctor/scripts/ast-check.ts`. Spawn via Bash.
3. **LLM judge agent** (for fuzzy cases): single sonnet agent scoped to a flagged file, asked "is this a real F2 violation given surrounding cleanup logic?" Reduces false positives on high-severity rules only.

### 3.4 Architecture pattern (matches existing skills)

```
skills/code-doctor/
  SKILL.md            # opus orchestrator, effort:low
  reference.md        # rule table, fix recipes (loaded on-demand)
  scripts/
    ast-check.ts      # AST checks compiled+run via npx tsx
    rules-firestore.json
    rules-vuefire.json
```

Workflow phases (mirrors `code-sweep`):

1. **Discover** — detect Firebase/VueFire dependency in `package.json`. Skip rules whose deps are absent.
2. **Scan** — run grep rules → AST rules → optional LLM-judge on critical findings.
3. **Report** — write `docs/_audits/YYYY-MM-DD_code-doctor.md` with file:line refs, severity, fix recipe.
4. **Fix** (opt-in) — apply auto-fix recipes for low-risk rules (F5, F8, V3); leave critical/major to user.
5. **Ratchet** — append findings count per rule to `.cc-sessions/code-doctor-ledger.jsonl` so subsequent runs only worsen if new violations appear.

## 4. Compatibility Analysis

- **Stack fit:** Repo is plugin-suite, but `code-doctor` targets *consumer* projects. Detection runs against the user's working dir, which is normal for blitz skills.
- **Dependency check:** Conditionally loads Firestore/VueFire rule sets based on `package.json` scan. Falls back to Vue/Pinia rules only if Firestore absent.
- **Existing skills it composes with:**
  - Runs *before* `refactor` (which executes the duplication extraction).
  - Runs *after* `code-sweep --scan-only` to avoid double-reporting dead code.
  - `ship` workflow: insert as quality-gate step, severity:critical findings block ship.
- **No conflict** with `codebase-audit` — that skill is breadth-first 5-pillar; this is depth-first framework-correctness.

## 5. Recommendation

Build `blitz:code-doctor` as a new sibling skill, scoped to **framework-API correctness only**.

Rationale:

1. **Avoid duplication with `code-sweep`.** Dead-code and inefficiency rules already exist there with a ratchet. Re-implementing reverses the suite's own DRY principle.
2. **Framework rules churn.** Firestore SDK v9→v10, VueFire 2→3, Pinia API changes mean an isolated rule set is easier to update than threading them into `code-sweep`'s 30-check structure.
3. **Sharper UX.** `/blitz:code-doctor` surfaces "your Firestore code has 3 critical issues" — much more legible than burying it inside a generic sweep report.
4. **Existing `simplify` skill already handles "review changed code for reuse".** That covers the duplication ask on the changed-code surface; the larger codebase-wide DRY scan stays in `code-sweep`/`codebase-audit`.

## 6. Implementation Sketch

1. **Scaffold** `skills/code-doctor/SKILL.md` with frontmatter:
   ```yaml
   ---
   name: code-doctor
   description: "Framework-API correctness audit. Detects Firestore/VueFire/Vue/Pinia anti-patterns. Read-only by default; --fix applies low-risk auto-fixes. Use when user says 'audit firestore', 'check api usage', 'code-doctor'."
   allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
   model: opus
   effort: low
   compatibility: ">=2.1.71"
   argument-hint: "[scope] [--scan|--fix|--fix-all] [--rules firestore,vuefire,vue,pinia]"
   ---
   ```
2. **Author `reference.md`** with the rule table from §3.2 plus fix recipes (one per rule).
3. **Add scripts/ast-check.ts** (~150 LOC) using `ts-morph` for F2 / V1 (the two rules that materially need AST).
4. **Wire into `.claude-plugin/skill-registry.json`** and `marketplace.json`.
5. **Activity-feed compliance** — log `skill_start`, `task_complete` per CLAUDE.md.
6. **Loop integration** — support `--loop` so `/loop /blitz:code-doctor` keeps fixing until clean, mirroring `code-sweep`.
7. **Tests** — fixture project under `tests/fixtures/code-doctor/` with one violation per rule; assert detector flags each.

Estimated build: ~1 sprint (1 story for scaffold+grep rules, 1 for AST checks, 1 for auto-fix recipes, 1 for fixtures+tests).

## 7. Risks

- **Risk: rule false-positive rate.** Grep-only rules over-flag. *Mitigation:* mark grep rules `severity:minor` until validated on a real repo; promote to major after 0 FPs across 3 sample repos. The LLM-judge tier (§3.3) is the planned escape hatch for high-severity grep rules.
- **Risk: overlap creep with `code-sweep`.** Future contributors may add generic checks to `code-doctor`. *Mitigation:* add a CONTRIBUTING note in `reference.md` header: "framework-API only; generic quality checks belong in code-sweep."
- **Risk: SDK version drift.** Firestore v9→v10 already shipped; v11 likely. *Mitigation:* version each rule (`since: "firestore@9"`), skip rules whose `since` exceeds detected version.
- **Open question:** Should `blitz:ship` block on critical findings from `code-doctor`? Recommend yes, behind a `--strict` flag, opt-in per project via `.cc-sessions/config.json`.
- **Open question:** Build a Postgres/Prisma rule pack now or defer? Defer — current ask is Firestore/VueFire.

## 8. References

- Existing skills: `skills/code-sweep/reference.md` (dead code patterns), `skills/codebase-audit/reference.md` (duplication checklist), `skills/simplify/`, `skills/refactor/SKILL.md`.
- Firestore best practices: https://firebase.google.com/docs/firestore/best-practices
- VueFire docs: https://vuefire.vuejs.org/
- Internal protocol: `skills/_shared/spawn-protocol.md`, `skills/_shared/carry-forward-registry.md`.
