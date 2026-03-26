# Scheduling Reference

Skills can be run on a recurring schedule using Claude Code's built-in scheduling features.

## Methods

### /loop (Session-Scoped)

Runs a skill at a fixed interval within the current session. Tasks expire when the session closes or after 3 days.

```
/loop 2h /blitz:dep-health audit
/loop 1d /blitz:quality-metrics collect
/loop 30m /blitz:sprint --loop
```

### /schedule (Remote Triggers)

Creates persistent scheduled tasks that survive session closure. Uses CronCreate under the hood.

```
/schedule daily /blitz:dep-health audit
/schedule weekly /blitz:quality-metrics collect
```

## Recommended Schedules

| Skill | Interval | Mode | Rationale |
|-------|----------|------|-----------|
| `dep-health` | Weekly | `audit` | Catch vulnerabilities and outdated packages |
| `quality-metrics` | Daily | `collect` | Track quality trends over time |
| `completeness-gate` | After each sprint | default | Catch placeholders before they age |
| `retrospective` | After each sprint | default | Auto-analyze completed sessions |
| `sprint` | 15-30m | `--loop` | Continuous sprint execution |
| `health` | Daily | default | Plugin integrity check |

## Loop-Compatible Skills

Skills that support `/loop` must be **idempotent** — safe to call repeatedly with the same result. The following skills are loop-compatible:

| Skill | Loop-Safe | Notes |
|-------|-----------|-------|
| `sprint --loop` | Yes | Reconciliation layer detects state, runs one phase per tick |
| `dep-health audit` | Yes | Read-only audit, no state changes |
| `quality-metrics collect` | Yes | Writes to date-stamped files, no conflicts |
| `health` | Yes | Read-only check |
| `completeness-gate` | Yes | Read-only scan |
| `next` | Yes | Read-only advisor |

Skills that modify code (sprint-dev, refactor, fix-issue, etc.) should NOT be used with `/loop` directly — use `/blitz:sprint --loop` to orchestrate them safely.
