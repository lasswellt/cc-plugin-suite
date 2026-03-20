---
name: health
description: "Plugin health check — verifies hooks, sessions, registry, and structural integrity"
argument-hint: "(no arguments — runs all checks)"
model: sonnet
disable-model-invocation: true
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

# Plugin Health Check

Verify the structural integrity and operational health of the blitz plugin. Reports issues that could affect skill execution, session management, or hook automation.

**No session protocol required.** This skill is lightweight and read-only.

---

## Phase 0: STRUCTURAL CHECKS

Run the plugin structure validator:
```bash
./scripts/validate-plugin-structure.sh 2>&1
```

Report the result. If validation fails, list each failure with its location.

---

## Phase 1: HOOK CHECKS

### 1.1 Hook Scripts Exist and Are Executable

For each hook in `hooks/hooks.json`, verify:
- The referenced script file exists
- The script is executable (`-x` permission)
- The script has a valid shebang line

```bash
# List all hook scripts from hooks.json and check each
for script in $(grep -oP '"command":\s*"[^"]*scripts/([^"]+)"' hooks/hooks.json | grep -oP '[^/]+\.sh$'); do
  ls -la hooks/scripts/${script} 2>/dev/null || echo "MISSING: ${script}"
done
```

### 1.2 hooks.json Is Valid

```bash
python3 -c "import json; json.load(open('hooks/hooks.json')); print('hooks.json: valid')" 2>&1
```

---

## Phase 2: SESSION CHECKS

### 2.1 Stale Sessions

Check `.cc-sessions/*.json` for sessions that are still marked `active` but appear stale:

```bash
find .cc-sessions -maxdepth 1 -name "*.json" -exec grep -l '"status": "active"' {} \; 2>/dev/null
```

For each active session:
- Check if the PID is still running
- Check if the session is older than 4 hours

Report stale sessions and suggest cleanup.

### 2.2 Stale Locks

Check for `.lock` files that may be orphaned:

```bash
find . -name "*.lock" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null
```

For each lock file, check if the owning session is still active. Report orphaned locks.

### 2.3 Activity Feed Size

```bash
wc -l .cc-sessions/activity-feed.jsonl 2>/dev/null || echo "No activity feed"
```

If over 500 lines, suggest truncation. If over 1000 lines, flag as a warning.

### 2.4 Session Reports Directory

```bash
ls .cc-sessions/reports/ 2>/dev/null | wc -l
```

Report the number of session reports available.

---

## Phase 3: REGISTRY CHECKS

### 3.1 Skill Registry Matches Disk

Compare skill entries in `.claude-plugin/skill-registry.json` with actual skill directories:

```bash
# Skills in registry
python3 -c "
import json
registry = json.load(open('.claude-plugin/skill-registry.json'))
registered = set(s['name'] for s in registry['skills'])
print('Registered:', sorted(registered))
"

# Skills on disk (directories under skills/ with SKILL.md, excluding _shared)
ls -d skills/*/SKILL.md 2>/dev/null | sed 's|skills/||;s|/SKILL.md||' | sort
```

Report any mismatches:
- Skills on disk but not in registry
- Skills in registry but not on disk

### 3.2 Agent Files Exist

Verify all agent files referenced by skills exist in `agents/`:

```bash
ls agents/*.md 2>/dev/null
```

### 3.3 Shared Protocols Exist

Verify all shared protocol files exist:

```bash
ls skills/_shared/*.md 2>/dev/null
```

Check that the expected protocols are present: session-protocol.md, verbose-progress.md, definition-of-done.md, checkpoint-protocol.md, deviation-protocol.md, context-management.md, session-report-template.md.

---

## Phase 4: STACK DETECTION CHECK

```bash
./scripts/detect-stack.sh 2>&1
```

Verify the stack detection script runs successfully and produces output.

---

## Phase 5: REPORT

Print a health summary:

```
Plugin Health Check
===================
Structural validation: PASS/FAIL (N/M checks)
Hook scripts:          PASS/FAIL (N/M executable)
hooks.json:            PASS/FAIL
Sessions:              N active, N stale, N completed
Stale locks:           N found
Activity feed:         N lines (OK/WARN)
Session reports:       N available
Skill registry:        PASS/FAIL (N skills registered, N on disk)
Agent files:           PASS/FAIL (N/M found)
Shared protocols:      PASS/FAIL (N/M found)
Stack detection:       PASS/FAIL

Overall: HEALTHY / NEEDS ATTENTION / UNHEALTHY
```

If any checks fail, list recommended actions:

```
Recommended Actions:
  1. [STALE SESSION] Clean up session <X> — PID not running, 6h old
  2. [ORPHANED LOCK] Delete sprint-registry.json.lock — owning session completed
  3. [MISSING SKILL] Skill "foo" on disk but not in registry — add to skill-registry.json
```
