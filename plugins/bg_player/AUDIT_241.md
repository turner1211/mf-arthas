# Audit 241: movement-driver ownership

The external report in `message.txt` was treated as diagnostic input and each
BG Player claim was checked against the current source. All three claims were
still reproducible in version 1.99.0.

- ArthasNav and authored direct steering now stop one another before movement
  ownership changes. This prevents held local keys from competing with a path.
- Combat approach no longer calls `look_at` every update while ArthasNav is
  steering. The stationary in-range combat hold still faces the target.
- Directional recovery falls back to the documented Project Sylvanas core
  strafe controls when the active ArthasNav object has no SimpleMovement
  adapter. Failed commands do not start a fake recovery timer.

Regression coverage verifies both directions of the driver handoff, preserves
stationary combat facing, and requires complete left/right start/stop fallback
controls.
