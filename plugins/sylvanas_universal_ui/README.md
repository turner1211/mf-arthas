SYLVANAS UNIVERSAL UI 1.6.0

INSTALL
Extract sylvanas_universal_ui into your Sylvanas Scripts directory.
Keep header.lua, main.lua and the ui_*.lua modules together in that folder.
Reload scripts with F6. Open the Sylvanas menu with INSERT and find Universal UI.
The UI loads for every class; you do not choose a class or spec manually.

DISPLAY
Automatic class/spec detection cross-checks the spellbook global spec ID, the
player object's global spec ID and the talent UI's 1-based spec index. It
refreshes every 0.1 seconds and on spec/talent events. Conflicting IDs or
unavailable identity clear the old display instead of showing a stale spec.
Unspecialized starter characters through level 20 receive a Starter profile.
All 13 Retail classes / 40 specializations have profiles, including Devourer.
Each spec/activity has saved scale and position. Three additional spell-ID
slots are available; the original first slot remains shared across activities.
Drag the native window to move it within the session. Menu position sliders
apply on change and provide the saved position for the next session.

Player/target health, absorbs, cast/channel progress, resource bars, learned
cooldown tiles, eight group members per page (up to five pages), and four
player buff labels. Party order follows party slot; loaded raid objects have
stable identity ordering. Low health is highlighted; offline and out-of-range
party members keep their place. Raid/BG rosters are labeled loaded members only.
Unknown values show --; unlearned preset abilities are omitted.
Cooldown AVAILABLE means cooldown/charges available, not range or cast validity.
Zero charges never become AVAILABLE just because the ordinary cooldown is zero.
Missing charge data shows UNKNOWN. Up to nine cooldown tiles are displayed.
Important learned abilities are discovered from the current spellbook, limited
to six preset/discovered slots before the three custom spell slots.
Buff display prioritizes stacks, then short remaining durations.
Enhancement has a Maelstrom Weapon stack display (unknown data stays unknown).
Arena shows up to five opponent frames; PvE instances show up to five bosses.

ACTIVITIES
Solo, grouped World PvE, Delves, dungeons, Mythic+, raids, arena,
battlegrounds and world PvP are detected automatically. Solo is used only
when the roster API confirms an empty group; unavailable roster data stays
grouped World PvE rather than guessing. Unknown activity data is labeled unavailable.
World PvP requires a hostile player target; War Mode alone is not inferred.
Mode changes select that spec/activity's saved layout. The frame grows to fit
additional cooldowns and encounters, then scales to fit the screen.
This plugin only displays information; it does not cast abilities.

CURRENT LIMITS
This is a standalone Sylvanas overlay, not a replacement for Blizzard frames,
action bars, minimap, chat or clickable healing frames. Those remain visible.
Ability presets are starter candidates and filtered by learned spells; custom
talent builds and future patches may need edits to ui_profiles.lua.
Devourer has Fury and an interrupt preset plus client-driven important-spell
discovery. If the client does not flag an ability as important, add its spell
ID using one of the custom slots. Discovery is cached for at most two seconds
and invalidated on spell, talent and world events.
Rune resource availability depends on the client API; no rune recharge timers.
Raid membership beyond loaded group objects is unavailable through the
documented APIs used here. The UI does not claim to show a complete raid roster.
Resources follow the specialization preset; temporary shapeshifts may require
different resource displays in a future revision.
Retail specialization order is the target. Classic/private-server orders and
abilities have not been validated.

VALIDATION
All 13 Lua files compile. Mocked runtime checks cover all 360 combinations of
40 specs and nine activities, three-way identity conflicts, loading screens,
offline/range party entries, charge availability, spell discovery, mode layout
separation, boss/arena panels, clock resets and 720p/ultrawide frame bounds.
These are simulations, not live-game integration or performance measurements.
1.1.1 adds panel-growth position checks, UTF-8-safe shortening of localized
names, invalid-charge rejection and an explicit unavailable-roster state.
Live Sylvanas / WoW validation is still required for every class/mode combination.

DIAGNOSTICS
Enable Status diagnostics to log distinct errors to the Sylvanas console.
The SylvanasUniversalUIStatus() function returns the active spec/activity,
current error, last historical error, update count and panel counts for debug
tools or another plugin. It does not contain character names or GUIDs.

REFERENCES
https://docs.project-sylvanas.net/dev/
https://docs.project-sylvanas.net/dev/api/ui/
https://docs.project-sylvanas.net/dev/api/game-object/
https://docs.project-sylvanas.net/dev/api/spellbook/
https://www.curseforge.com/wow/addons/luckyoneui
https://github.com/Mapkov2/MidnightCooldownManager


LIVE LOG (1.1.2)
With diagnostics enabled, local samples and UI errors are written immediately to scripts_log/universal_ui_live.log. Samples include class/spec, mode, combat state and panel counts; no character names or GUIDs. First live check passed for Beast Mastery Hunter in World PvE.


1.2.0: Compact PvP panel with embedded artwork/icons following the Rogue GUI. Header Hide and separate draggable Show/Hide switch. Personal damage, DPS, healing and HPS update at 10 Hz from the native damage-meter API. Current/Overall button selects the session. Reset Meters clears ALL native combat sessions, including the Blizzard meter. Missing personal data displays --. Rates use the game's reported per-second value, or session duration when unavailable.


1.3.0: Original custom bloodstained arena artwork and skull/weapon icons replace the Rogue assets. Brighter labels, exact white meter values, larger minimum text, image-backed buttons and reduced empty spacing. Source PNGs are in assets; runtime textures are embedded in Lua and require no downloads.


1.4.0: Existing class/spec cooldown tiles include remaining seconds and charges. Adds optional GCD countdown/READY/unknown display. PvP-only awareness panel shows player/target CC, target stun/root/fear/incapacitate DR multiplier and reset time, enemy burst state, observed target cooldowns and elapsed time since detected target trinket use. Optional SDK/helper failures display unknown; never assume an unobserved enemy cooldown is ready. Enemy tracked spells use current class presets and the native cooldown tracker; coverage is not every enemy ability. Trinket observation does not claim a fixed cooldown. GCD and PvP tracking are independently configurable.
Research inspiration: https://www.curseforge.com/wow/addons/gladiusex and https://www.curseforge.com/wow/addons/omnibar . These establish useful tracker features, not compatibility of those addons with 12.1. Implementation uses installed Sylvanas API annotations.


1.5.0: Four readable tabs: Overview, Cooldowns, PvP, Meters. Auto selects PvP for Arena/BG/World PvP and Overview for World PvE/Delves/Dungeon/Mythic+/Raid. Manual tab choices use saved native settings separately per spec/activity; AUTO clears that override. GCD stays in the footer. Adds active keystone level, dungeon/raid difficulty, delve completion, current combat duration, player/target shields and incoming heals/heal absorbs, personal match kills/deaths/honor, and upcoming BigWigs events when that addon is already loaded. Timers use actual exposed bars; no fabricated boss schedule. Raid/BG group views still show only confirmed loaded members. Native options control visibility and size.
Reference inspiration: https://www.curseforge.com/wow/addons/bigwigs and https://www.curseforge.com/wow/addons/plater-nameplates/description .


1.6.0: Adds an explicit Solo activity with its own saved layout and keeps grouped World PvE separate. Delves are recognized even while the instance-type API is briefly unavailable. Class/spec detection now cross-checks two global-ID sources plus the talent UI index, accepts a valid player-object fallback when the spellbook is late, and rejects mismatches without retaining the previous character. Starter profiles cover confirmed unspecialized characters through level 20. Mythic+ context includes the active key level and affix count when exposed, with the active challenge map as a truthful fallback. Release metadata, tests and documentation now use the same version.

1.6.1: Protects all Universal UI object-manager reads behind a UI-owned adapter. Full object scans used for loaded raid and battleground members are cached for 500 milliseconds, following the Project Sylvanas guidance to avoid comprehensive scans every frame. Loading transitions invalidate the cache. Per-specialization windows, saved layouts, activity settings, and profiles remain separate; the UI does not import or overwrite settings from class/spec plugins.

