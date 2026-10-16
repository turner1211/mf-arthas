# Audit 242: navigation state transitions

The full movement lifecycle was checked after the external movement-driver
fix. Two additional ownership gaps were reproducible from the current source.

- Crowd control could pause ArthasNav while an authored direct corridor kept
  its local forward key held. The hold now releases direct movement and
  invalidates its callbacks. Clearing the hold cannot resume the provider path
  that direct steering previously replaced. A dedicated hold marker makes
  repeated pause calls idempotent without touching that stale provider.
- ArthasNav SimpleMovement strafing could begin before its current path was
  stopped. Every non-null directional recovery now stops the path first,
  including both SimpleMovement and core-input fallback execution.

Regression coverage verifies release, callback invalidation, absence of stale
provider resume, and stop-before-strafe ordering.
