# Session Report Template

Standard format for session reports. Generated automatically at session cleanup.

Reports are written to `.cc-sessions/reports/<SESSION_ID>.md`.

---

## Template

```markdown
# Session Report: <SESSION_ID>

| Field | Value |
|---|---|
| Skill | <skill-name> |
| Started | <ISO-8601> |
| Ended | <ISO-8601> |
| Duration | <elapsed in HH:MM:SS> |
| Status | completed / failed / partial |

## Summary

<1-3 sentence description of what was accomplished>

## Actions Taken

1. <action description> — <timestamp>
2. <action description> — <timestamp>
3. <action description> — <timestamp>

## Files Changed

| File | Action |
|---|---|
| path/to/file1.ts | created |
| path/to/file2.vue | modified |
| path/to/file3.ts | deleted |

## Verification Results

| Check | Result | Detail |
|---|---|---|
| Type-check | PASS / FAIL | <error count if fail> |
| Tests | PASS / FAIL | <passed>/<total> |
| Lint | PASS / FAIL | <error count if fail> |
| Build | PASS / FAIL | — |
| Completeness | <score>/100 | <grade> |

## Agents Spawned

| Agent | Stories | Completed | Blocked |
|---|---|---|---|
| backend-dev | 5 | 4 | 1 |
| frontend-dev | 3 | 3 | 0 |

(Omit this section if no agents were spawned)

## Key Decisions

- **DECISION:** <what> — Reason: <why>
- **DECISION:** <what> — Reason: <why>

## Deviations

- **DEVIATION:** <what was added/changed> — Reason: <why>

(Omit this section if no deviations occurred)

## Issues Encountered

- <issue description> — Resolution: <how resolved>
- <issue description> — Resolution: <escalated to user>

(Omit this section if no issues)

## Metrics

| Metric | Value |
|---|---|
| Stories completed | <N>/<total> |
| Waves completed | <N>/<total> |
| Fix iterations | <N> |
| Circuit breakers tripped | <N> |
| Deviations | <N> |
| Escalations | <N> |

(Include only metrics relevant to the skill that ran)
```

---

## Generation Rules

1. **Auto-populate from activity feed** — Read the session's entries from `activity-feed.jsonl` to fill Actions Taken, Decisions, and Issues sections.
2. **Auto-populate files from git** — Run `git diff --name-status <start-commit>..HEAD` to fill Files Changed.
3. **Auto-populate verification** — Use the last verification results from the session.
4. **Keep it factual** — No opinions, no suggestions for future work. Just what happened.
5. **Max 100 lines** — Be concise. Link to artifacts (STATE.md, review reports) rather than duplicating content.

---

## Storage

```
.cc-sessions/
├── reports/
│   ├── sprint-dev-a3f7c1b2.md
│   ├── fix-issue-b4e8f2a1.md
│   └── research-c5f9a3d2.md
```

Reports are preserved indefinitely. They serve as input for the `retrospective` skill's pattern analysis.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
