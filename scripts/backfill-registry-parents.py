#!/usr/bin/env python3
"""Phase 7 backfill — append 'correction' events to carry-forward.jsonl setting parent.capability and parent.epic."""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Derived from docs/roadmap/epic-registry.json — registry_id → (capability_id, epic_id).
PARENT_MAP = {
    "cf-2026-04-18-terse-directive-agents": ("CAP-001", "E-001"),
    "cf-2026-04-18-terse-directive-skill-gap": ("CAP-001", "E-001"),
    "cf-2026-04-18-terse-directive-shared-protocols": ("CAP-001", "E-001"),
    "cf-2026-04-18-compress-safe-references-wave2": ("CAP-002", "E-002"),
    "cf-2026-04-18-compress-research-docs": ("CAP-002", "E-002"),
    "cf-2026-04-18-write-phase-directive-inserts": ("CAP-003", "E-003"),
    "cf-2026-04-18-unsafe-ref-agent-prompt-injection": ("CAP-003", "E-003"),
    "cf-2026-04-18-review-format-absorption": ("CAP-004", "E-004"),
    "cf-2026-04-18-output-intensity-profile": ("CAP-005", "E-005"),
    "cf-2026-04-18-lite-exemption-markers": ("CAP-005", "E-005"),
    "cf-2026-04-18-task-type-gating": ("CAP-005", "E-005"),
    "cf-2026-04-18-activity-feed-message-rule": ("CAP-005", "E-005"),
    "cf-2026-04-18-agent-prompt-boilerplate": ("CAP-006", "E-006"),
    "cf-2026-04-18-spawn-protocol-warning-upgrade": ("CAP-007", "E-007"),
}


def main():
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    path = Path(".cc-sessions/carry-forward.jsonl")
    lines = []
    for registry_id, (cap, epic) in PARENT_MAP.items():
        line = {
            "id": registry_id,
            "ts": ts,
            "event": "correction",
            "parent": {"capability": cap, "epic": epic},
            "notes": "Parent backfilled by roadmap Phase 7 after epic generation",
        }
        lines.append(json.dumps(line))
    with open(path, "a") as f:
        f.write("\n".join(lines) + "\n")
    print(f"appended {len(lines)} correction events")


if __name__ == "__main__":
    main()
