# Retrospective — Reference Material

Pattern taxonomy, proposal templates, safety classification rules, and metrics templates used by the retrospective skill.

---

## Pattern Taxonomy

Categories of patterns to identify during retrospective analysis.

### Failure Patterns

| Pattern | Detection Method | Example | Severity |
|---------|-----------------|---------|----------|
| **Crash** | Session JSON with `status: failed` | Skill hit an unrecoverable error and aborted | High |
| **Timeout** | Session duration > 2x average for skill | Agent waited too long for a response or lock | Medium |
| **Incorrect Output** | Revert commits after skill completion | Sprint-dev produced code that was immediately reverted | High |
| **Regression** | Fixup commits within 2 commits of feature | Test failures introduced by implementation | High |
| **Repeated Failure** | Same skill fails 3+ times in analysis period | Systemic issue with skill design or project state | Critical |
| **Silent Failure** | Session completed but review found critical issues | Skill passed verification but produced low-quality output | High |
| **Partial Completion** | Session completed with skipped steps noted | Migration or refactoring that only partially succeeded | Medium |

### Efficiency Patterns

| Pattern | Detection Method | Example | Severity |
|---------|-----------------|---------|----------|
| **Lock Contention** | `conflict_detected` entries in operations log | Two sprint-dev sessions fighting for same lock | Medium |
| **Redundant Research** | Same WebSearch queries across sessions | Multiple sessions researching the same library | Low |
| **Excessive Iterations** | Session turn count > 2x skill average | Too many verification-fix loops | Medium |
| **Rework** | Same file modified in 3+ consecutive sessions | Code written, reviewed, fixed, reviewed again | High |
| **Unnecessary Spawning** | Agent spawned but produced no findings | Audit agent for backend when project has no backend | Low |
| **Tool Unavailability** | Fallback paths triggered frequently | WebSearch unavailable, research degraded | Medium |

### Quality Patterns

| Pattern | Detection Method | Example | Severity |
|---------|-----------------|---------|----------|
| **Recurring Violations** | Same lint/type error across reviews | `any` type used repeatedly in new code | Medium |
| **Declining Metrics** | Quality scores trending down over time | Test coverage dropping with each sprint | High |
| **Incomplete Implementation** | TODO/FIXME in committed code | Placeholder code that passed review | High |
| **Weak Tests** | Tests that never fail (always pass regardless of changes) | `expect(true).toBe(true)` style assertions | Medium |
| **Missing Error Handling** | Review findings for unhandled error paths | Async operations without try/catch | Medium |
| **Style Drift** | Inconsistent patterns in new code vs existing | New components use different structure than established ones | Low |

### Coverage Patterns

| Pattern | Detection Method | Example | Severity |
|---------|-----------------|---------|----------|
| **Untested Modules** | Source directories with no test files | `src/utils/` has 20 files, 0 tests | High |
| **Unused Skills** | Skills never appearing in session history | `perf-profile` skill never invoked | Low |
| **Unaudited Areas** | Source directories never appearing in audit findings | Backend code never audited because no backend agents spawned | Medium |
| **Missing Skill Coverage** | User requests that don't map to any skill | User asks for "database schema migration" but no skill handles it | Medium |

---

## Developer Profile Schema

The developer profile (`.cc-sessions/developer-profile.json`) is generated/updated by the retrospective skill's Phase 2.5. Other skills read it at session registration (step 6b) to adapt behavior.

```json
{
  "updated": "<ISO-8601>",
  "sessions_analyzed": 15,
  "confidence": "high",
  "preferences": {
    "verbosity": "standard",
    "autonomy": "high",
    "commit_style": "atomic",
    "pr_size": "medium",
    "review_tolerance": "standard",
    "framework_focus": "vue-nuxt",
    "common_skills": ["fix-issue", "sprint-dev", "refactor"],
    "peak_hours": "09:00-17:00"
  },
  "patterns": {
    "avg_session_duration_minutes": 45,
    "most_common_first_action": "fix-issue",
    "typical_sprint_size": 12,
    "auto_fix_acceptance_rate": 0.85
  }
}
```

### Derivation Rules

| Dimension | Signal | Value |
|---|---|---|
| verbosity | User said "just do it" or skipped plans often | concise |
| verbosity | Default (no strong signal) | standard |
| verbosity | User asked "explain", "why", "show me" | detailed |
| autonomy | <30% of sessions had user mid-session input | high |
| autonomy | 30-70% had user input | medium |
| autonomy | >70% had user input | low |
| commit_style | Git log shows one commit per story | atomic |
| commit_style | Git log shows grouped commits per phase | batched |
| commit_style | User explicitly commits after skill completes | manual |
| review_tolerance | User fixed all findings including low-severity | strict |
| review_tolerance | User fixed critical+high, ignored low | standard |
| review_tolerance | User dismissed most findings | lenient |

### Profile Consumers

| Skill | How It Uses the Profile |
|---|---|
| **ask** | Skips clarification for high-autonomy users; prefers common_skills for ambiguous requests |
| **sprint-dev** | Adjusts commit granularity based on commit_style |
| **sprint-review** | Adjusts finding threshold based on review_tolerance |
| **All skills** | Adjusts output verbosity based on verbosity preference |

---

## Proposal Template

Full template for documenting a retrospective proposal.

```markdown
### Proposal <ID>: <Title>

- **Classification**: safe | review | never-auto-apply
- **Pattern observed**: <Description of the pattern from session data>
- **Evidence**:
  - Sessions: <list of session IDs or count>
  - Occurrences: <how many times the pattern appeared>
  - Time period: <date range>
- **Proposed change**:
  - File: <absolute path to file>
  - Type: add | edit | delete
  - Description: <what specifically to change>
  - Before: <current content (if edit)>
  - After: <proposed content>
- **Expected impact**:
  - Metric improved: <which metric or behavior>
  - Estimated improvement: <quantified if possible>
- **Classification rationale**: <why this classification level>
- **Risk assessment**:
  - If applied correctly: <expected outcome>
  - If applied incorrectly: <worst case>
  - Reversibility: <easy | moderate | hard>
- **Status**: proposed | applied | reverted | deferred
```

---

## Safety Classification Rules

Detailed rules for classifying proposals. When in doubt, classify at the MORE restrictive level.

### Safe — Auto-Applicable

A proposal is "safe" if ALL of the following are true:

1. **Additive only**: The change adds content without removing or modifying existing content.
2. **Reference material only**: The change is in a `reference.md` file, a template, or a non-executable section.
3. **No behavioral impact**: The change does not alter how any skill executes its phases.
4. **No safety rule interaction**: The change does not touch, reference, or affect any safety rule.
5. **Easily reversible**: The change can be reverted with a single `git checkout -- <file>`.

**Examples of safe proposals:**
- Adding a new codemod entry to `skills/migrate/reference.md`
- Adding a new pattern to a checklist in `skills/codebase-audit/reference.md`
- Fixing a typo in a skill description
- Adding a new routing row to `skills/ask/SKILL.md`
- Adding a new entry to the pattern taxonomy in this file
- Updating version compatibility tables

### Review — Needs User Confirmation

A proposal requires "review" if ANY of the following are true:

1. **Modifies execution flow**: Changes a skill's phase structure, step ordering, or conditional logic.
2. **Changes verification behavior**: Alters what is checked, when it is checked, or how results are interpreted.
3. **Modifies agent instructions**: Changes the prompts, scopes, or capabilities given to spawned agents.
4. **Adds new safety rules**: Even adding safety rules needs review to ensure they don't conflict.
5. **Changes model assignments**: Switching a skill from opus to sonnet or vice versa.
6. **Modifies shared protocols**: Changes to session protocol, lock behavior, or conflict matrix.
7. **Removes content**: Deletes any section, step, or instruction from a skill file.

**Examples of review proposals:**
- Adding a new pre-flight check to a skill's Phase 0
- Changing the file cap for an audit agent
- Restructuring a skill's phase numbering
- Adding a new agent to a multi-agent skill
- Changing the timeout for lock acquisition

### Never Auto-Apply

A proposal is "never-auto-apply" if ANY of the following are true:

1. **Removes or weakens a safety rule**: Any change that makes a safety rule less restrictive.
2. **Reduces verification gates**: Removing a type-check, test run, build step, or validation.
3. **Changes the session protocol**: The session protocol is shared infrastructure; changes cascade.
4. **Modifies the conflict matrix**: Incorrectly classifying a conflict could cause data corruption.
5. **Changes lock behavior**: Lock timing, stale detection, or retry logic changes.
6. **Removes a skill entirely**: Skills should not be auto-deleted.
7. **Changes the Definition of Done**: The quality bar should not be lowered automatically.

**Examples of never-auto-apply proposals:**
- "Remove the 3-consecutive-failure abort rule — it's too conservative"
- "Skip type-check verification to speed up sprint-dev"
- "Change lock timeout from 60s to 5s"
- "Allow sprint-dev and sprint-review to run concurrently on the same sprint"

---

## Before/After Metrics Template

Use this template to track improvement after applying retrospective proposals.

```markdown
## Improvement Metrics — YYYY-MM-DD

### Measurement Period
- Before: <start-date> to <proposal-date> (N sessions)
- After: <proposal-date> to <measurement-date> (N sessions)

### Failure Rate
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Failed sessions (%) | X% | X% | -X% |
| Revert commits | N | N | -N |
| Fixup commits | N | N | -N |
| Critical review findings | N | N | -N |

### Efficiency
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Avg session duration (min) | X | X | -X |
| Lock conflicts | N | N | -N |
| Avg turns per session | X | X | -X |
| Rework incidents | N | N | -N |

### Quality
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Avg completeness score | X/100 | X/100 | +X |
| Test coverage (%) | X% | X% | +X% |
| Lint errors per session | X | X | -X |
| Type errors per session | X | X | -X |

### Coverage
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Skills used (unique) | N/M | N/M | +N |
| Tested directories (%) | X% | X% | +X% |
| Audited areas (%) | X% | X% | +X% |

### Applied Proposals Summary
| Proposal | Status | Measured Impact |
|----------|--------|-----------------|
| S1: <title> | Applied | <measured outcome> |
| S2: <title> | Applied | <measured outcome> |
| R1: <title> | Deferred | N/A |
```

---

## Session Data Schema

Expected format of session JSON files for parsing.

```json
{
  "session_id": "skill-name-a3f7c1b2",
  "skill": "skill-name",
  "started": "2026-03-18T10:00:00Z",
  "ended": "2026-03-18T10:45:00Z",
  "pid": "12345",
  "status": "completed",
  "working_on": "Brief description of what was done",
  "locks_held": [],
  "tmp_dir": ".cc-sessions/skill-name-a3f7c1b2/tmp/",
  "steps_completed": 5,
  "steps_total": 5,
  "errors": []
}
```

Fields used by retrospective analysis:
- `skill`: For grouping sessions by skill type
- `started` / `ended`: For duration calculation and timeline
- `status`: For failure rate calculation
- `working_on`: For understanding what was attempted
- `errors`: For failure pattern identification (if populated)
