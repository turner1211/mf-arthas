# Audit 244: supplied TBC API dump

`api_dump_stub.lua` is a generated Sylvanas API declaration for the
Tbc / wow_tbc_us client. It is reference data, not executable plugin code.

The dump confirms BG Player's native bindings for battlefield status,
acceptance, joining, leaving, winner detection, interaction, mounting, movement,
strafe recovery, object discovery, inventory, rendering, and map conversion.

Two compatibility gaps were found and fixed:

- `core.game_ui.get_active_match_state` is present on this TBC runtime, so TBC
  now uses it directly rather than requiring a supplemental phase adapter.
- TBC does not expose Brawl, Epic-selector, or Blitz join bindings. Its mode
  selector now presents one generic TBC battleground choice.

The dump does not expose queue-slot metadata equivalent to `queue_info`. BG
Player continues to require a verified metadata adapter before it can claim or
accept a TBC queue. The dump itself is not installed with the plugin.
