# Audit 243: provider boundary containment

The second follow-up audit injected failures into every remaining ArthasNav
property and discovery boundary used by active movement. Several reads were
still outside protected calls and could interrupt the full controller.

- Navigation provider discovery is now protected in stop, pause, direct-route
  handoff, ordinary movement, and asynchronous callback identity checks.
- Provider server-capability and health-check properties are read safely.
- Optional SimpleMovement lookup and replan dispatch are fully contained.
- Diagnostic reporting is best-effort and cannot break the movement it reports.

Regression tests inject throwing provider getters, methods, and diagnostic
callbacks and require an ordinary unavailable/failure result without a Lua
exception.
