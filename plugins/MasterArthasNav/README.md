# MasterArthasNav Lua library

Navigation library for Project Sylvanas plugins, installed to
`scripts\MasterArthasNav\` by `MasterArthasNav-Setup.exe`. It is the ArthasNav
client 2.0.4 (installer 1.0.14) with these changes:

- `header.lua`: plain header, plugin name `MasterArthasNav`. The boot line goes to
  `base_url` instead of a hard-coded port.
- `anav/config.lua`: holds `base_url` (default `http://127.0.0.1:47110`); the
  installer rewrites that one line from the chosen HTTP port. The upstream
  settings are unchanged in `anav/config_upstream.lua`.
- `anav/export.lua`: `_G.AmeisenNav` (primary) and `_G.ArthasNav` (same table)
  are published on every update tick. After F6 the tables from the previous
  load are replaced; a table another plugin put there is left alone.
- `main.lua`: hands the bundled client to the export, and sends the runtime's
  one load-time request for `127.0.0.1:47110` to `base_url`.
- `anav/bootstrap.lua`: `ArthasNavBootstrap.tick(id, enabled)` also accepts
  `bloodcrypt_delver` and `master_farmer`.
- `anav/height_fallback.lua`: `client:get_height` can read the server's
  `ok <z>` answer when the game has no height.
- `anav/enhancements.lua`: binds to the client this load exported.

Every other module is unchanged. API: `docs/API.md`. Contract tests:
`tests/lua` in the MasterArthasNav repository (`luajit tests/lua/run.lua`).
