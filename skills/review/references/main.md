# Review — Reference Material

The `review` skill delegates all heavy lifting to `sprint-review` (see `skills/sprint-review/SKILL.md`). This file documents only the pieces the wrapper itself enforces — most notably the per-finding output shape reviewer agents must use regardless of entry point.

---

## Review Finding Format (mandatory terse line-level shape)

Reviewer agents MUST format every finding using the caveman-review shape absorbed in Sprint 3 / S3-003.

### Line-level format

- **Single file:** `L<line>: <severity-prefix> <problem>. <fix>.`
- **Multi-file:** `<file>:L<line>: <severity-prefix> <problem>. <fix>.`

### Severity prefixes

| Prefix | Severity | Meaning |
|---|---|---|
| `🔴 bug:` | Critical | Broken / incident-class / security-breach-class |
| `🟡 risk:` | Major | Fragile but works; likely-future-bug |
| `🔵 nit:` | Minor | Style / naming / small improvement |
| `❓ q:` | Info | Genuine question to author |

### LGTM rule

If a severity bucket has zero findings, write `LGTM` under that heading and stop. Do NOT pad with "nothing to report", "no issues found", or similar filler.

### Auto-clarity exemption

For security/CVE-class findings, architectural disagreements, or onboarding contexts, drop the terse one-liner and write a full prose explanation with references (OWASP rule IDs, RFCs, doc links). Resume terse format on the next finding.

### Drop from findings

"I noticed", "It seems like", "You might want to consider", per-comment praise, restating what the line already does, general hedging.

### Keep

Exact line numbers, identifiers in backticks, concrete fix, "why" only when non-obvious.

### Example

```markdown
### Critical
L42: 🔴 bug: `verifyToken` never checks `exp` claim. Add `if (payload.exp < Date.now()/1000) throw`.

### Major
src/api/user.ts:L88: 🟡 risk: missing `await` on `saveUser()` loses write on error path. Add `await`.

### Minor
LGTM

### Info
L30: ❓ q: why `Map` over `Record<string, X>` here? Hot path?
```

---

## Delegation

For all other templates, quality gates, auto-fix strategies, reviewer-specific checklists, and final-output formats, see `skills/sprint-review/reference.md`. The wrapper does not duplicate that content — it only enforces the finding-format contract above.
