---
id: S7-010
title: "Scripted login + storageState harvest/restore + R9 session-contamination sentinel"
epic: E-012
capability: CAP-016
status: done
priority: P0
points: 3
depends_on: [S7-009]
assigned_agent: backend-dev
files:
  - skills/ui-audit/reference.md
verify:
  - "grep -qE 'storageState|storage[ _-]state' skills/ui-audit/reference.md"
  - "grep -q '.auth/' skills/ui-audit/reference.md"
  - "grep -qE 'sentinel|R9' skills/ui-audit/reference.md"
done: "Phase ROLE documents the scripted login flow (browser_navigate to /login, fill creds from env, submit, wait for redirect), the storageState harvest (localStorage+sessionStorage+cookies via browser_evaluate, write to .auth/<role>.json), the restore path (replay login or state injection), and the R9 sentinel check (after role switch: navigate to /profile, assert displayed email == expected env var email)."
---

## Description

Per-role auth harness. Default path: scripted login per role transition (~5s overhead, reliable). Fast path: storageState injection (~100ms, brittle — documented as opt-in via `--fast-role-switch`). R9 mitigation: after EVERY role switch, sentinel-check that the skill is actually logged in as the expected role.

## Acceptance Criteria

1. Phase ROLE § Login documents scripted login:
   - `browser_navigate(baseUrl + "/login")`
   - Fill creds from env via `browser_evaluate` (selectors configurable in `.ui-audit.json[login_flow]`; defaults: `input[name=email]`, `input[name=password]`, `button[type=submit]`)
   - `browser_wait_for(text: "<dashboard-landmark>" or time: 5)` — landmark configurable as `.ui-audit.json[login_flow][success_landmark]`; default: URL does not contain `/login`
2. Phase ROLE § StorageState harvest:
   ```js
   // After successful login, browser_evaluate:
   ({
     localStorage:   Object.fromEntries(Object.entries(localStorage)),
     sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
     cookies:        document.cookie
   })
   ```
   Write result to `.auth/<role>.json`. `.gitignore` suggestion: `/.auth/`.
3. Phase ROLE § StorageState restore (opt-in `--fast-role-switch`):
   - Navigate to baseUrl
   - `browser_evaluate` to re-inject localStorage + sessionStorage
   - Cookie restoration via `document.cookie = k + "=" + v` for each pair (has eTLD + path limitations; document)
   - If injection fails, fall back to scripted login
4. R9 sentinel check (MANDATORY, both paths):
   - After login/restore, `browser_navigate(baseUrl + "/profile")`
   - `browser_evaluate`: extract displayed email via configurable selector (`.ui-audit.json[login_flow][profile_email_selector]`; default `[data-user-email], .user-email`)
   - Assert matches `AUDIT_<ROLE>_EMAIL` env var exactly
   - On mismatch: emit CRITICAL finding `ROLE_SWITCH_FAILED`, abort the role's audit, continue to next role
5. Between role transitions: clear `localStorage.clear()` + `sessionStorage.clear()` + `document.cookie = ""` BEFORE the next role's login, to prevent leaked state (also R9).

## Implementation Notes

- Cookie restoration is the brittle bit. The docs.claude.com Playwright MCP surface doesn't expose a cookie-injection primitive directly; `document.cookie = ...` only works for same-origin, non-HttpOnly cookies. For HttpOnly session cookies, scripted-login is the only reliable path. Document this.
- R9 sentinel is non-negotiable. Skipping it re-introduces the exact bug the research doc flagged.
- Anonymous role: no login, no sentinel. Just clear storage and continue.

## Dependencies

S7-009.
