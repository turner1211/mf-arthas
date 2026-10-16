# Restoration Shaman GUI assets

The GUI intentionally uses Lua-drawn marks so Project Sylvanas does not need
PNG or JPEG files. The tab marks are `E` Earth, `W` Water, `S` Spirit Link,
`C` Cleanse, `G` Ghost Wolf, `U` Utility, and `L` Lightning/control. They are
drawn by `rs_gui_probe.lua` and remain clickable, scalable, and readable.

The panel background is the opaque navy-and-teal canvas rendered by the same
Lua file. This keeps the window portable and prevents missing texture errors.

There is no image loader or external artwork dependency. Thrall, his staff,
the elemental totems, panels, boss instructions, danger circles, and all text
are rendered from Lua through Project Sylvanas drawing functions.
## 4.5.1 city training-dummy support

The shared dummy classifier recognizes selected damage, cleave, tanking, and healing practice targets across capital cities by NPC identity, name, and role title. The Mana & Damage tab provides separate switches and customer hotkeys for damage practice, healing practice, and optional cleave testing. Practice behavior remains disabled for ordinary NPCs and never overrides live healing priority.

## 5.4.0 multi-client Shaman suite

The same embedded Lua artwork is shared by Restoration, Elemental, and Enhancement. The live header identifies Retail/Midnight or WoW Forever and the detected specialization/tree. The package remains self-contained with no PNG, JPEG, or overlay files.

The F1 window now uses a persistent left navigation rail for Dashboard, Player, Open World, Dungeons, Mythic+, Raid, Delves, Arena, Battlegrounds, World PvP, Hotkeys, and Display/Logs. Each page has its own elemental accent, relevant live controls, a master mode switch where applicable, and row-level hotkey assignment. Twelve high-detail fantasy navigation icons are embedded in `rs_nav_art.lua`; no external image file is required at runtime.


## 5.4.0 WoW Forever decision pass

Forever controls now expose rank-aware healing, five-second-rule recovery, Shock reservation, support totems, and healer safe-window damage. The isolated Forever engine also tracks elemental totem slots so reactive Tremor, Grounding, cleansing, and survival choices are not overwritten by routine group buffs.

## 5.4.0 Forever predictive controls

The Dashboard exposes Forever projected triage, redundant-heal cancellation, pre-pull totem calls, and post-combat resurrection. These controls remain within the existing two-window Shaman GUI and do not add another panel.

## 5.4.0 Forever damage controls

The existing Dashboard now includes crowd-control-safe area damage, low-mana damage downranking, an Enhancement mana-floor slider, and meaningful-fight Rage timing. No new GUI window was added.
