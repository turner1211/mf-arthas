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

## Command Center v3

### Shared languages (2.1.3)

The command center and all other compatible projects in this repository now use
the shared language layer. Select **Interface language** in a plugin menu or on
the Setup tab. German, Italian, both Chinese scripts, all WoW client language
families and Japanese have bundled core labels; additional language packs are
supported with English fallback. See [coverage and limitations](../../docs/LOCALIZATION.md).
The installed `plugin_loader.lua`, `header.lua` and `main.lua` loader entrypoints
remain unchanged across updates. Reload plugins to activate downloaded changes.

The redesigned command center opens from the MasterArthasNav menu and provides seven translucent, artwork-backed tabs: Command, Combat, Route, Safety, Logs, Metrics, and Setup.

The Combat tab checks the local character continuously. It converts the host specialization index to the full specialization ID when needed, selects the installed Warrior, Paladin, Hunter, Rogue, Shaman, Mage, or Druid suite, and rebuilds its controls after a class or specialization change. Every displayed switch reads and writes the matched plugin's persistent control. Supported hotkeys show their current binding and can be changed from the Combat page or the native MasterArthasNav menu. Classes without an installed suite receive an explicit unsupported message.
