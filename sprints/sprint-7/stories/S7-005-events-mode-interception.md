---
id: S7-005
title: "Events mode routing + 3-layer interception (dataLayer + sendBeacon + network)"
epic: E-011
capability: CAP-015
status: done
priority: P0
points: 3
depends_on: []
assigned_agent: backend-dev
files:
  - skills/ui-audit/SKILL.md
  - skills/ui-audit/reference.md
verify:
  - "grep -q 'Phase EVENTS' skills/ui-audit/reference.md"
  - "grep -q 'window.dataLayer' skills/ui-audit/reference.md"
  - "grep -q 'navigator.sendBeacon' skills/ui-audit/reference.md"
  - "grep -q '__auditEventLog' skills/ui-audit/reference.md"
  - "grep -qE 'segment\\.io|posthog|amplitude|g/collect' skills/ui-audit/reference.md"
done: "SKILL.md events mode behavior documented; reference.md Phase EVENTS includes the 3 interception JS blocks + activation timing + network hostname filter list + drain procedure."
---

## Description

Wire `events` mode. Three-layer analytics interception installed immediately after `browser_navigate`: (a) `window.dataLayer.push` proxy for GA4/GTM, (b) `navigator.sendBeacon` wrap for GA4 hits, (c) network-level via `browser_network_requests` for Segment/PostHog/Amplitude. All 3 are non-destructive — they log events into `window.__auditEventLog` then pass through to the original transport.

## Acceptance Criteria

1. `SKILL.md` §0.1 `events` mode row updated: "intercept analytics events via dataLayer proxy + sendBeacon wrap + network filter; drain + persist to registry; evaluate event_invariants (see Phase EVENTS)."
2. `reference.md` gains `## Phase EVENTS — Analytics consistency` section with verbatim 3-layer JS from research doc §3.8:
   - Layer A: `window.dataLayer` push proxy (GA4/GTM)
   - Layer B: `navigator.sendBeacon` wrap
   - Layer C: Network-level via `browser_network_requests` — hostname filter list: `api.segment.io`, `app.posthog.com`, `api2.amplitude.com`, `/g/collect` (GA4)
3. Activation timing: inject Layers A+B immediately after `browser_navigate` returns, BEFORE any user interaction (R8 mitigation). If `window.dataLayer.length > 0` at inject time, emit `EVENTS_BEFORE_SPY` finding (severity LOW) with count.
4. Drain procedure: after each safe-click or at end-of-page, `browser_evaluate: window.__auditEventLog.splice(0)` returns captured events non-destructively (events already reached their transports).
5. Safety invariant: the wrappers always call `_original(...args)` last. Events reach production analytics unchanged. A comment in reference.md explicitly states this.

## Implementation Notes

- Research doc §3.8 has the JS verbatim — copy unchanged.
- R8 (analytics spy timing): `window.dataLayer.length > 0` check at inject time is the exact heuristic for missed pre-parse events.
- Network filter hostnames should be documented as extensible via `.ui-audit.json[analytics_hostnames]: ["..."]` for teams running private Segment/Snowplow/RudderStack collectors.

## Dependencies

None.
