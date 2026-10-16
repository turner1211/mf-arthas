RESEARCH AND PRIOR-BUILD REVIEW — October 8, 2026

PRIOR USER PLUGINS
The installed scripts and previous deliverable folders under Documents/Codex
were inventoried. Duplicate bundles and earlier backups were treated as earlier
versions of the same plugin family, rather than as independent integrations.
The following families supplied implementation lessons; their class rotations
were not bundled or required by the warrior plugin.

Retribution paladin: header/runtime class/spec guards, cooldown and target checks.
Holy paladin: one pending request, cast-outcome confirmation, secret-aura caution.
Protection paladin: role-safe Taunt, friendly victim verification, threat direction,
retry backoff, and damage follow-through after a confirmed Taunt.
Guardian druid: activity detection, maximum-health-safe pressure prediction,
physical-versus-magic survival, protected enemies, and native cast clocks.
Restoration shaman: separate PvP/PvE contexts, survival/resource priority, mode
configuration, NPC companion versus player handling, and supported Common helpers.
Assassination rogue: isolated profiles/identity, damage immunity and breakable CC,
PvP DR checks, ally-interrupt deferral, target health trends, and manual engagement.
Auto leveler: local-to-global specialization normalization and client awareness.
Auto skinner/gathering: bounded polling, retries, preserving ongoing actions, and
keeping movement/gathering decisions separate from the combat rotation.
Battleground bot and BG link probes: detected context, explicit capability gates,
independent rotation/navigation lifecycles, and cast/channel preservation.
Standalone combat logger: bounded capture, contextual rows, separating requests,
failures, and confirmations, and batching file writes.

LOCAL API SOURCE
wowxe/877cd2847fccb01a52d4ac407ba1/scripts/.api/core.lua
wowxe/877cd2847fccb01a52d4ac407ba1/scripts/.api/game_object.lua
wowxe/877cd2847fccb01a52d4ac407ba1/scripts/.api/menu.lua
Common enums, PvP helper, buff manager, health prediction, and auto-attack helpers.
The local October 7 API comments distinguish global spellbook spec IDs from
class-local game UI spec indices and specify role values and clock units.

PUBLIC PRIMARY SOURCES
Project Sylvanas developer setup and callbacks:
https://docs.project-sylvanas.net/dev/
https://docs.project-sylvanas.net/dev/api/core/
https://docs.project-sylvanas.net/dev/api/events/
https://docs.project-sylvanas.net/dev/api/spellbook/
https://docs.project-sylvanas.net/dev/api/input/
https://docs.project-sylvanas.net/examples/

SimulationCraft Midnight action priorities and warrior implementation:
https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/warrior_arms.simc
https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/warrior_fury.simc
https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/warrior_protection.simc
https://github.com/simulationcraft/simc/blob/midnight/engine/class_modules/sc_warrior.cpp
Research copies were read in work/. Warrior hero-tree branching, rage/Enrage
priorities, Thunder Blast, Colossal Might, Rend, Execute, and mitigation reserves
informed the implementation. This plugin is an independently written practical
adaptation, not a full SimulationCraft interpreter or a DPS-optimality proof.

Hekili's source spell/aura definitions were cross-checked for stable IDs:
https://github.com/Hekili/hekili/blob/master/TheWarWithin/WarriorArms.lua
https://github.com/Hekili/hekili/blob/master/TheWarWithin/WarriorFury.lua
https://github.com/Hekili/hekili/blob/master/TheWarWithin/WarriorProtection.lua
These files identify themselves as 11.2-era definitions. They were used for
identity cross-checks, not as current Midnight rotation authority. Native
spellbook overrides remain authoritative at runtime.

Blizzard client/patch context:
https://worldofwarcraft.blizzard.com/en-us/news/24264417
https://worldofwarcraft.blizzard.com/en-gb/news/24307306
https://worldofwarcraft.blizzard.com/en-us/news/24296142
https://worldofwarcraft.blizzard.com/en-gb/news/24304162/1215-content-update-notes
https://www.wowhead.com/guide/classes/warrior/arms/mythic-plus-dungeon-tips
https://www.wowhead.com/guide/classes/warrior/protection/mythic-plus-dungeon-tips
https://www.wowhead.com/spell=386071/disrupting-shout
https://www.wowhead.com/spell=208683/gladiators-medallion
https://orboro.net/pages/midnight-season-2-mythic-plus-interrupt-utility-cheat-sheet
https://www.method.gg/guides/protection-warrior/playstyle-and-rotation
The exact live character's patch could not be observed. Current/next-patch
mechanics and tuning remain a live-validation dependency.

The October 2026 official notes were used to recheck current Warrior PvP and
12.1.5 tuning context, including Intervene/Safeguard utility and current Arms,
Fury, and Protection adjustments. They informed thresholds and ability support;
runtime spellbook knowledge still decides whether an action is available.

The Season 2 dungeon sources specifically supported frequent Shockwave/Storm
Bolt stops, Protection's AoE interrupt, regular defensive use, Rallying Cry for
predictable damage, and Wrecking Throw for shield mechanics. The public trinket
data was used only after observing the enemy's actual cast; the plugin does not
invent unavailable enemy cooldown state.

The final mitigation audit used current Protection guidance that prioritizes
Shield Block uptime over damage spending and current SimulationCraft priorities
for Mountain Thane, Slayer, Colossus, and Protection rage management.

WHAT THE SOURCES DO NOT PROVE
PvE simulation priorities do not prove arena tactics, actual loader behavior,
every encounter's reflectability, or perfect survival. PvP controls here use
native cast targets, immunity/DR data, health pressure, and explicit burst intent.
No public source or offline assertion is represented as successful live testing.

VERSION 0.7.0 COMBAT AUDIT — OCTOBER 8, 2026
Current Patch 12.1 Arms guidance was rechecked against Wowhead's rotation guide:
Rend is refreshed with Cleave before a ready Colossus Smash window, cooldowns are
used liberally when the target-life and pull-size policy allows, and confirmed
Sudden Death stacks remain protected from overcapping.

Current Fury guidance was rechecked against Method and current PvP guides. The
rotation now converts an active Enraged Regeneration into Bloodthirst/Bloodbath
self-healing before ordinary damage fillers while preserving Enrage and Rampage.

Current Protection guidance was rechecked against Method, Icy Veins, Wowhead's
Season 2 dungeon guide, and the SimulationCraft Midnight branch. Shield Block
still outranks Ignore Pain for blockable damage, pack and magic pressure raise
the absorb threshold, Revenge keeps a Shield Block rage reserve, and a capped
Thunder Blast is spent before Avatar can reset or waste it.

Mythic+ stop coordination now remembers a recent Disrupting Shout and preserves
Shockwave instead of immediately chaining both area stops; Pummel and DR-safe
single-target control remain available for the surviving cast.

VERSION 0.7.1 EXECUTION AND STANCE AUDIT — OCTOBER 8, 2026
The final cast boundary now rejects ordinary damage actions after a target swap
and rechecks live engagement and crowd-control protection before every area cast.
This closes the gap between a correct decision and world state changing before
the native input request is sent.

Battle Shout upkeep now works before combat, matching current Arms pre-combat
guidance without opening the damage rotation early. Current Wowhead stance data
confirms Defensive Stance spell 386208 and Battle Stance spell 386164. Optional
per-profile stance management enters Defensive Stance only under measured health,
attacker, magic, or encounter-timer pressure and waits five seconds in PvE or
eight seconds in PvP before returning to Battle Stance. The delay prevents rapid
stance oscillation and each spec/mode retains its own switch.

ARENA COOLDOWN AUDIT
Current Gladiator's Medallion data lists a two-minute cooldown. The Arena burst
signal now uses a profile-specific 0–120 second post-trinket window, defaults to
120 seconds, consults the native PvP helper when it exposes trinket history, and
falls back to confirmed enemy spell events. Old 90-second hardcoding was removed.

VERSION 0.7.2 HERO-TREE PRIORITY AUDIT
Method's current Fury list places Recklessness and Avatar before the main damage
sequence, caps Sudden Death at two stacks, and spends capped Thunder Blast early.
The Fury branches now follow that ordering and no longer spend Odyn's Fury before
Recklessness or omit single-target Slayer Avatar.

Wowhead's current Arms Colossus list builds Colossal Might with Mortal Strike,
places Ravager before the armor-break window, and uses Demolish during Colossus
Smash. Those conditions are now explicit and remain separate from Slayer logic.

Protection now moves Shield Charge ahead of ground cooldowns, spends expiring
free Revenge procs, and no longer lets the optional gap-closing Charge switch
disable the core Shield Charge rotation ability.

VERSION 0.7.4 LIVE-GUIDE AND DIAGNOSTIC AUDIT
Method's Fury 12.1 guide, updated August 11, 2026, confirms the existing core
ordering: Recklessness/Avatar, Rampage for missing Enrage or high Rage, capped
Sudden Death, then empowered strikes. It also recommends following Enraged
Regeneration with Bloodthirst healing, which the Fury branch already enforces.
https://www.method.gg/guides/fury-warrior/playstyle-and-rotation



VERSION 0.9.51 ARMS PVE WRECKING THROW DAMAGE FILLER
- Icy Veins' current Patch 12.1 Arms guide describes Wrecking Throw as a competent ranged filler with unusually strong damage, in addition to its much larger value against absorb shields.
- Arms now requests Wrecking Throw only after its normal PvE attacks cannot be used. Confirmed absorb shields still trigger the earlier utility path.
- Routine filler use is excluded from Arena, battlegrounds, and World PvP and is guarded by the Arms specialization decision layer.

SOURCE REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities



VERSION 0.9.52 LOW-LAG RUNTIME HOT PATHS
- Project Sylvanas warns that get_all_objects returns every game object and is computationally expensive when processed frequently. Its documentation recommends the cached, filtered unit_helper methods for relevant enemy lists.
- The Warrior snapshot now prefers unit_helper:get_enemy_list_around and refreshes its list container at 250 ms. Live fields on the returned unit objects are still evaluated every 100 ms, preserving combat and interrupt responsiveness.
- Older cores retain a guarded get_all_objects fallback, also cached for 250 ms. This matches the caching strategy used by the mature local Rogue and Guardian plugins.
- The logger previously concatenated each new row onto a growing string and deleted/recreated the entire recovery data file every second. Lua strings are immutable, so that pattern repeatedly copies the accumulated text and creates garbage-collection pressure.
- Diagnostic rows now accumulate in a table and are materialized at 15-second recovery checkpoints. Immediate append-only session.log writes and forced exit/disconnect checkpoints preserve crash diagnostics.

SOURCES REVIEWED
https://docs.project-sylvanas.net/dev/api/object-manager/
https://docs.project-sylvanas.net/dev/api/core/
https://www.lua.org/notes/ltn009.html
Local assassination_rogue_v1.1.91/ar_performance.lua and ar_runtime.lua
Local guardian_druid_mplus_v7.4.0/guardian_objects.lua and guardian_runtime.lua

Method's Protection 12.1 guide emphasizes defensive management and the spec's
weakness against damage-over-time and unblockable damage. The existing split
continues to reserve Shield Block for physical/timed pressure while allowing
Ignore Pain and major defensives to answer magic and mechanic pressure.
https://www.method.gg/guides/protection-warrior

The current Arms PvP guide identifies Sharpen Blade as mandatory but states it
is no longer directly controlled. It also supports the existing Slayer burst
ordering and Colossus Demolish setup behavior, so no invalid active Sharpen
Blade cast was added to the registry.
https://www.icy-veins.com/wow/arms-warrior-pvp-talents-and-builds

The diagnostic audit found that GUI hold reasons and manually initiated player
casts were visible live but absent from the saved copy. Version 0.7.4 persists
status transitions and every recognized player cast, making post-crash reports
useful for both missed-action and unexpected-action investigations.

VERSION 0.7.8 HERO-TREE PRIORITY FOLLOW-UP
Method's Protection 12.1 rotation separates the hero trees after Shield Slam:
Colossus prioritizes Revenge ahead of Thunder Clap, while Mountain Thane keeps
Thunder Blast and Thunder Clap ahead of Execute and Revenge. The implementation
now follows that split while retaining the mitigation rage reserve.
https://www.method.gg/guides/protection-warrior/playstyle-and-rotation

Current Arms 12.1 priorities maintain Rend before the Colossus setup and consume
capped Sudden Death before repeatedly building Colossal Might. This prevents the
setup loop from starving an expiring maintenance debuff or capped proc.
https://www.method.gg/guides/arms-warrior/playstyle-and-rotation

VERSION 0.7.9 SHIELD BLOCK CHARGE AUDIT
Current Protection guidance prioritizes Shield Block when missing or about to
cap charges and notes its Shield Slam damage bonus even while not actively
tanking. The snapshot now exposes native charge counts, allowing an off-tank in
active combat to spend only a fully capped Shield Block charge. One remaining
charge is preserved for the next blockable hit or tank swap.
https://www.method.gg/guides/protection-warrior/playstyle-and-rotation

VERSION 0.8.3 MIDNIGHT SEASON 2 PROFILE FOLLOW-UP
The current SimulationCraft MID2 profiles were re-read from the maintained
midnight branch. Mountain Thane Fury now opens multi-target combat with Odyn's
Fury before Recklessness and Avatar, while its single-target list keeps ordinary
Execute below Bloodbath, Crushing Blow, Thunder Blast, Rampage, and Bloodthirst.
Protection Colossus now commits Demolish at three confirmed Colossal Might stacks.
These changes are runtime spellbook-gated and retain PvP burst and area-safety
controls.
https://github.com/simulationcraft/simc/blob/midnight/profiles/MID2/MID2_Warrior_Fury.simc
https://github.com/simulationcraft/simc/blob/midnight/profiles/MID2/MID2_Warrior_Protection.simc

VERSION 0.8.4 STANCE AUDIT
The current Fury MID2 profile explicitly selects Berserker Stance before combat,
while Arms and Protection select Battle Stance. Berserker Stance spell and aura
ID 386196 were cross-checked against current spell data. Automatic stance
recovery now restores Fury to Berserker Stance after a defensive window and
retains confirmed state when the client hides the stance aura.
https://github.com/simulationcraft/simc/blob/midnight/profiles/MID2/MID2_Warrior_Fury.simc
https://www.wowhead.com/spell=386196/berserker-stance

VERSION 0.8.5 AURA OWNERSHIP AND TALENT FALLBACK AUDIT
Berserker Stance is a selectable talent, so Fury now falls back to learned
Battle Stance when Berserker Stance is unavailable. The Arms MID2 priority uses
buff.executioners_precision, confirming that Executioner's Precision belongs to
the warrior rather than the target. Snapshot ownership and two-stack consumption
tests now enforce that distinction.
https://github.com/simulationcraft/simc/blob/midnight/profiles/MID2/MID2_Warrior_Arms.simc

VERSION 0.8.6 PRECOMBAT AND ACTIVITY-BOUNDARY AUDIT
The MID2 profiles apply their specialization stance during precombat. The main
loop now invokes a safe preparation path outside combat so stance selection is
completed before Battle Shout maintenance. Boss-mod timer consumption now uses
the same explicit delve/dungeon/Mythic+/raid boundary shown by the GUI, removing
the possibility of stale encounter bars influencing World PvE or PvP.

VERSION 0.8.7 DUNGEON SUBSYSTEM AUDIT
The Arms/Fury encounter cards inherited several Rogue-specific words from their
reference implementation. Feint and Vanish prompts were replaced with Warrior
defensive and Pummel instructions, and recursive validation now rejects known
foreign-class ability names. Route persistence now keys progress by character
GUID as well as dungeon context, preventing two Protection Warriors from sharing
an active pull while preserving reconnect recovery for the original character.

VERSION 0.8.8 BOSS-HELPER LIFECYCLE AUDIT
The DPS helper previously inspected only the first returned addon timer and
cleared its active mechanic on every update. It now ranks recognized mechanics
from the live boss cast and all supported timer providers, ignores unrelated
bars, and preserves a verified prompt for a short bounded interval through
transient provider gaps. Encounter-end, death, activity, and role gates still
clear the state immediately.

VERSION 0.8.9 ARENA BURST-SIGNAL AUDIT
The enabled global PvP option had been copied into the engine's manual-request
field, which could force Arena cooldowns without a kill-window signal. It now
acts strictly as permission. Automatic Arena burst requires a vulnerable target,
controlled healer, or confirmed trinket window. Crowd control and damage
immunity are evaluated separately so an immune healer cannot create a false
automatic opportunity.

VERSION 0.9.0 GUI API AND LIFECYCLE AUDIT
The GUI window, visibility, sizing, forced-position, cursor, key, and render
callback calls were checked against the installed Project Sylvanas API files and
the established Rogue, Paladin, Shaman, and Hunter window patterns. The test
harness now supplies the same API surface and executes the custom GUI, proving
F1 edge debounce and single-window reuse rather than allowing initialization to
fall through its protected compatibility path.

VERSION 0.9.1 LOADER STARTUP AUDIT
The loader header and main module previously required a fully readable local
player and specialization during file evaluation. Login-time API gaps could
therefore skip initialization for the session. Indeterminate identity now loads
the guarded runtime and waits in its update callback, while definite non-Warrior
and unsupported-client states remain rejected before combat logic can activate.

VERSION 0.9.2 HEADER EXCEPTION AUDIT
Version and local-player APIs can be temporarily callable yet still throw while
the client is loading. Header reads now use protected calls and classify those
exceptions as indeterminate startup state. Confirmed incompatible class/client
values still prevent loading, while temporary failures cannot abort discovery.

VERSION 0.9.3 GUI CLARITY AND ROUTE-CONTENT AUDIT
Official Project Sylvanas UI and graphics documentation confirms that persistent
windows should be predeclared and rendered only from registered callbacks. The
Warrior interface continues to reuse one window and cached embedded textures.
Every profile and global control now carries concise explanatory text in the
custom GUI, numerical values show units, and active/inactive state is conveyed
with text, shape, border, and color. Contrast choices were reviewed against the
W3C WCAG 2.1 guidance for text (4.5:1 normal, 3:1 large) and WCAG 2.2 guidance
for component state indicators (3:1). The dungeon data tests now validate all
eight routes, pack metadata, tank/DPS boss coverage, and exact pull multisets.

GUI SOURCES REVIEWED
https://docs.project-sylvanas.net/dev/api/graphics/
https://docs.project-sylvanas.net/dev/api/ui/
https://docs.project-sylvanas.net/dev/guides/custom-ui/
https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum
https://github.com/w3c-wcag/wcag22/blob/main/understanding/non-text-contrast.html
https://news.blizzard.com/en-gb/article/23783586/enhance-your-gameplay-more-accessibility-updates-available

VERSION 0.9.4 CONTROL AND ROTATION AUDIT
An option-to-execution trace found that Arms and Fury could still return damage
decisions after their profile Damage rotation switch was disabled. The engine
would reject those decisions, but the loop could repeatedly report an unusable
action instead of idling cleanly. Both rotations now stop at their entry point,
matching Protection and the option's stated behavior. Current Midnight 12.1
Arms guidance also places burst setup and Bladestorm or Demolish ahead of a
capped Sudden Death Execute. The priority now follows that order while retaining
the capped-stack Execute immediately after all available setup actions.

ROTATION SOURCE REVIEWED
https://www.wowhead.com/guide/classes/warrior/arms/rotation-cooldowns-pve-dps
https://www.wowhead.com/guide/classes/warrior/fury/rotation-cooldowns-pve-dps
https://www.wowhead.com/guide/classes/warrior/protection/rotation-cooldowns-pve-tank
https://www.wowhead.com/guide/classes/warrior/protection/midnight-season-2

VERSION 0.9.5 ARENA PRESSURE AND CONTROL AUDIT
Current Midnight 12.1 PvP guidance emphasizes trading a major defensive into
verified enemy offensive cooldowns and using Storm Bolt to establish a burst
window. Snapshots now count only engaged, unprotected burst enemies currently
targeting the Warrior. Arms, Fury, and Protection answer that signal with their
own spec-valid major defensive at a bounded health threshold. Burst aimed at an
ally, an immune enemy, an expired burst signal, or an already-active defensive
cannot spend the personal cooldown. Arena control still prefers an eligible
off-target healer, then uses a DR-safe Storm Bolt on the kill target when no
healer control is available.

PVP SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/fury-warrior-pvp-rotation-and-playstyle

VERSION 0.9.6 MYTHIC+ INTERRUPT IDENTITY AUDIT
The dangerous-cast classifier previously relied primarily on English spell
names. Verified spell IDs from the installed Guardian priority table and
LittleWigs-derived encounter data now classify critical and high-priority
Season 2 casts even when the loader returns a localized or unavailable name.
Name matching remains as a fallback for hotfixed IDs. High-priority casts do
not automatically escalate to a multi-caster Shockwave, while verified
critical casts retain emergency-stop eligibility.

ENCOUNTER SOURCE REVIEWED
https://github.com/BigWigsMods/LittleWigs
https://github.com/BigWigsMods/LittleWigs/releases

VERSION 0.9.7 ENCOUNTER-HELPER LIFECYCLE AUDIT
The DPS helper previously refreshed after global and profile action gates. A
paused Arms or Fury profile could therefore retain an older prompt through a
specialization or activity transition. Snapshot construction and role-specific
guide refresh now occur before those casting exits. The operation is read-only:
pause and profile-disable controls still prevent every input request, while
boss guidance stays current. A paused change to Protection immediately clears
the DPS helper, preserving strict tank-versus-damage-role isolation.

VERSION 0.9.8 LIVE-TEST DIAGNOSTIC HANDOFF AUDIT
The crash-safe logger already retained up to one MiB on disk, but the Warrior
GUI exposed only its path. The Activity page now provides native Copy Saved Log
and Copy Log Paths controls using the same Project Sylvanas clipboard API as
the installed Rogue, Shaman, Guardian, and Hunter interfaces. Clipboard output
is capped to the newest 64 KiB, identifies itself and its recovery file, and
leaves the complete one-MiB history on disk. Executable GUI tests click through
the Activity tab and prove that the rendered button reaches the native window
clipboard with a freshly emitted marker.

VERSION 0.9.9 GUI LIFECYCLE AND READABILITY AUDIT
- Compared the Warrior window lifecycle with the installed Rogue and Ret Paladin panels.
- Delayed native window creation until a supported Warrior is active, preventing discovery-time ghost windows.
- Added three-second retry windows for embedded backgrounds and spec icons so transient texture failures recover.
- Added captured header dragging, mouse-wheel option scrolling, context-following profile selection, and stronger hover outlines.
- Confirmed Master of Warfare aura 1269391 and Heroic Strike 1269383 against current Midnight spell data.
- Applied high-contrast text, state, and focus treatment informed by WCAG 2.2 guidance.


VERSION 0.9.11 TRAINING DUMMY AUDIT
- Reused the installed Rogue plugin's native unit_helper.is_dummy-first detection pattern with a guarded non-player name fallback.
- Limited practice mode to a selected, attackable World PvE dummy and an explicit enabled-by-default global option.
- Allowed safe precombat rotation startup for Arms, Fury, and Protection without changing real-target engagement rules.
- Nearby confirmed dummies can participate in cleave testing; any nearby non-dummy or protected target still blocks unsafe area actions.
- Added full-spec snapshot, opt-out, spoof rejection, runtime dispatch, diagnostics, and GUI-option validation.


VERSION 0.9.12 COMPACT BOSS HELPER GUI AUDIT
- Added an independent, lazy-created boss-helper native window rather than embedding the helper in the primary settings panel.
- Auto-detects Arms, Fury, or Protection and renders distinct spec colors, emblems, and DPS/Tank labels.
- Reads only the matching existing DPS or Protection boss-helper state, preserving role and specialization isolation.
- Limited visibility to Dungeon and Mythic+ and tied it to the existing Boss Guide master switch.
- Added tests for all three themes, role labels, dungeon-only visibility, and the master switch.


VERSION 0.9.13 BOSS HELPER VISIBILITY AUDIT
- Added a dedicated HIDE control inside the compact boss-helper window.
- Added an independent edge-triggered F7 show/hide hotkey that continues polling while the helper is hidden.
- Confirmed held-key debounce, repeated hide/show cycles, and independence from the main F1 GUI.


VERSION 0.9.15 BOSS HUD VISIBILITY RECOVERY
- Live diagnostics showed the client was still running v0.9.11 and then rejected a non-Warrior character, so v0.9.14 had not been loaded in that session.
- Replaced the fixed 1040px X position with screen-aware placement and per-frame screen clamping.
- Added a visible monitoring preview in every supported Warrior activity so placement and F7 can be verified before entering a dungeon.
- Wrapped the boss HUD renderer with persistent boss_hud_error diagnostics instead of allowing silent callback failure.
- Extended the window mock to validate two independent native windows without conflating F1 and F7 visibility.

VERSION 0.9.16 POSITIONAL BOSS COACH AND LOG AUDIT
- Cross-checked all eight Midnight Season 2 dungeons against current Wowhead and Icy Veins encounter guidance.
- Added role-aware world overlays with a destination circle, direction line, arrowhead, and movement label for deterministic stack, spread, kite, sidestep, and tank-facing mechanics.
- Tank facing anchors use the live party centroid so Protection is guided opposite the group; DPS movement remains isolated to Arms and Fury.
- Kept mechanics needing a specific shield, corpse, singularity, mushroom, root, or puddle as text guidance unless the loader exposes that object's reliable live position.
- Corrected current positioning prompts for Nalorakk, Taz'Rah, Atroxus, Charonus, Ikuzz, Ziekket, Kystia, Xathuux, and Altar of Fangs encounters.
- Live-log review found context records repeating every update. Context is now change-deduplicated, preserving useful cast failures, encounter events, and snapshots in the crash-safe log.

ENCOUNTER SOURCES REVIEWED
https://www.wowhead.com/guide/midnight/mythic-plus-season-overview
https://www.wowhead.com/guide/midnight/den-of-nalorakk-dungeon-overview-location-rewards
https://www.wowhead.com/guide/midnight/altar-of-fangs-dungeon-overview-location-rewards
https://www.wowhead.com/guide/midnight/murder-row-dungeon-overview-location-rewards
https://www.icy-veins.com/wow/altar-of-fangs-dungeon-guide
https://www.icy-veins.com/wow/murder-row-dungeon-guide/
https://www.icy-veins.com/wow/den-of-nalorakk-dungeon-guide/
https://www.icy-veins.com/wow/blinding-vale-dungeon-guide
https://www.icy-veins.com/wow/voidscar-arena-dungeon-guide

VERSION 0.9.17 AUTOMATIC PROTECTION ROUTE LOCATION
- Scores every pull in the detected dungeon against live NPC IDs, required multiplicities, distance, route rarity, and current progress.
- Automatically selects a clearly better visible pull and immediately redirects the route line and destination circle to that pack.
- Allows forward progression during normal movement while requiring a teleport-sized movement or sustained mismatch before moving backward.
- Persists auto-corrected progress per character and dungeon so reloads resume at the detected location.
- Keeps all location matching and route drawing restricted to Protection in Dungeon and Mythic+ modes.

VERSION 0.9.18 CLEAR-FLOOR BOSS AND ROUTE OVERLAYS
- Removed the 8-yard route ring, per-enemy route rings, player-centered mechanic rings, duplicate boss circles, and world text over the character.
- Reduced world line width, marker radius, marker thickness, label size, and alpha while keeping destination direction readable.
- The compact boss HUD now owns mechanic instructions; the world layer shows only one low-opacity arrow or target line.
- Expanded Protection timer discovery to BigWigs, ExBoss, DBM, and Deadly Boss Mods compatible providers and pre-warns supported mechanics up to eight seconds out.
- Associates boss-mod timers with the live boss frame so positional arrows have a current world anchor.
- Live v0.9.17 diagnostics contained no runtime or HUD errors. Added a two-second successful-Charge lock and moved Disrupting Shout behind the global-cooldown gate based on repeated cast failures.

VERSION 0.9.19 ADAPTIVE CAST RECOVERY AND PRIORITY PASS
- Rechecked Patch 12.1 Arms, Fury, and Protection priority guidance. Arms keeps armor-break windows frequent, Fury maintains Enrage and avoids wasting Rage, and Protection preserves effective Shield Block coverage before optional Rage spending.
- The live 4.5 MB Warrior log showed repeated game-client rejection after the loader reported Charge, Wrecking Throw, Pummel, Shield Slam, and Disrupting Shout usable. Added per-ability exponential recovery across targets while retaining the existing target-specific retry gate.
- Extended observed ally-kick deferral using live ping so the plugin waits through the network acknowledgement window before attempting a duplicate stop.
- Added terminal target-life spending for Arms and Fury and allowed Protection Execute ahead of Revenge only after primary builders and with mitigation covered.

ROTATION SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities
https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities

VERSION 0.9.28 ARENA CONTROL AND IMMUNITY PASS
- Current Arms Arena guidance orders Hamstring, kill-target control, Avatar,
  Warbreaker, Champion's Spear, and Mortal Strike. The rotation now prevents
  early Mortal Strike upkeep from interrupting the active setup sequence.
- Healer Storm Bolt is reserved for the documented Storm Bolt-healer into
  Shockwave-kill-target sequence. Without ready Shockwave, the stun remains on
  the kill target.
- Intimidating Shout now participates only when its control category is DR-safe
  and its area cannot disturb protected targets.
- Defensive Stance can answer positively identified enemy burst preemptively.
- Wrecking Throw and Shattering Throw now use their distinct live spell IDs;
  Shattering Throw is limited to confirmed damage immunity.

ARENA SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/arms-warrior-pvp-talents-and-builds
https://www.icy-veins.com/wow/fury-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/fury-warrior-pvp-talents-and-builds
https://www.wowhead.com/spell=64382/shattering-throw
https://www.wowhead.com/spell=384110/wrecking-throw

VERSION 0.9.29 ARENA OPENER AND DEFENSIVE TRADING
- Current Arms, Fury, and Protection Arena guidance recommends avoiding Charge
  when possible, applying the opening control chain, and using cooldowns early
  to establish momentum. The new opener is tied to Arena combat transitions.
- Arms guidance recommends a major defensive into enemy cooldowns or a healer
  crowd-control chain. The defensive layer now recognizes both conditions.
- Fury guidance explicitly supports combining Enraged Regeneration with an
  Intervene that may redirect lethal weapon damage.
- Disarm now precedes Intervene when reliable helper data confirms weapon burst,
  preventing damage rather than needlessly moving it onto the Warrior.

ADDITIONAL ARENA SOURCES REVIEWED
https://www.icy-veins.com/wow/protection-warrior-pvp-rotation-and-playstyle

VERSION 0.9.30 ARENA MAXIMUM-DAMAGE PRIORITIES
- Arms Colossus now uses Demolish immediately inside the verified armor-break
  window, while confirmed Heroic Strike procs precede Mortal Strike as listed in
  the current Arena burst sequence.
- Fury Mountain Thane now follows the distinct Avatar, Recklessness, Spear,
  Rampage, Stormblast, Execute, and builder hierarchy. Slayer retains its own
  Recklessness, Avatar, and Bladestorm branch.
- Protection Arena damage now promotes Execute and Stormblast before its
  ordinary Shield Slam and Thunder Clap sequence.
- PvE priority lists remain separate from these Arena-specific branches.

VERSION 0.9.31 ARENA DAMAGE-STANCE UPTIME
- Current Arms and Fury guidance warns against remaining in Defensive Stance
  longer than incoming pressure requires because its penalty reduces damage.
- Minor magic at full health is no longer enough on its own to enter the stance;
  verified burst, multiple attackers, low health, and timers remain authoritative.
- A safe verified kill window restores the specialization's damage stance
  immediately instead of losing up to eight seconds of pressure.
- Arms' Arena filler threshold now follows the documented Slam usage above
  50 Rage when no stronger action is available.

VERSION 0.9.32 ARENA FIRST-CONTACT BURST TIMING
- Current Arena guidance defines the opener around applying control and damage
  to the target, rather than the moment the combat flag first appears.
- The automatic opening window now starts on first verified melee contact, so
  approach time does not consume the intended pressure window.

VERSION 0.9.33 HERO-TREE ARENA SEQUENCING
- Current Fury guidance places Rampage before Slayer Bladestorm in the opener,
  but places Bladestorm before Rampage in the later coordinated burst list.
  The runtime now distinguishes those two windows.
- Current Arms Colossus guidance orders Avatar, Warbreaker, control, and
  Demolish. Colossus alone now delays the shared control layer until its first
  two setup actions are established.

VERSION 0.9.34 MANUAL OPENER CONTEXT AND LIVE DIAGNOSTICS
- First-contact state is now independent from the automatic cooldown option, so
  manual openers retain the documented opener order.
- The October 13 runtime-log audit found no Arena combat samples. Snapshots now
  record target distance and opener state so the next Arena session can support
  evidence-based uptime and sequencing changes.

VERSION 0.9.25 DEEP PVP LOGIC AUDIT
- Current Arms PvP guidance continues to emphasize uptime, Hamstring, Avatar
  into Warbreaker pressure, deliberate control, and Intervene as a major peel.
- Current Fury PvP guidance separates its Recklessness/Avatar burst setup from
  PvE hero-tree openers and uses Bladestorm in the Slayer kill sequence.
- PvE-only Ravager and Odyn's Fury opener branches are now explicitly excluded
  from PvP, and Arena control falls through when healer Storm Bolt is unavailable.

PVP AUDIT SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/fury-warrior-pvp-rotation-and-playstyle

VERSION 0.9.26 PVP PEEL AND MOBILITY AUDIT
- Current Arms guidance states that Intervene redirects melee and ranged
  attacks but does not cover spells. The peel now uses direct cast-target data
  to distinguish those cases and controls a confirmed spell attacker instead.
- Die by the Sword is prepared only when the native PvP helper positively
  identifies physical, disarmable burst; uncertain or non-disarmable attack
  pressure can still receive a normal Intervene.
- Fury keeps Charge available inside fifteen yards in every PvP mode, matching
  the current emphasis on conserving mobility rather than spending Charge by
  default at short range.

VERSION 0.9.21 STRICT BURST ELIGIBILITY
- A live-log invariant audit found repeated `target=none burst=true` snapshots.
- Lua's `and` precedence had left target validity, engagement, range, and damage-reduction checks after an `or false`, making those checks unreachable.
- The complete burst expression is now one parenthesized conjunction. Automatic and explicit PvP burst requests both retain target safety, and all cooldown-tagged spells inherit the corrected state.

VERSION 0.9.22 DEFENSIVE ROTATION AND LOG SIGNAL
- Current Protection guidance emphasizes rotating defensive tools instead of stacking all of them. Routine Demoralizing Shout now waits for Shield Wall or Last Stand to finish, while imminent mechanics, critical health, or four attackers can still justify overlap.
- The 4.5 MB live log contained 5,745 snapshots, including 1,909 idle snapshots. Identical idle snapshots now use a ten-second cadence; combat remains one second and any state change writes immediately.

VERSION 0.9.23 COORDINATED MAGIC-CAST RESPONSE
- Protection Mythic+ guidance identifies Pummel as the main interrupt and Spell Reflection as both magic mitigation and a reflection tool. The previous ordering spent Reflection before testing Pummel.
- Targeted magic now follows Pummel, Reflection, then Storm Bolt availability. This preserves cooldowns, avoids redundant control, and still covers uninterruptible casts.

VERSION 0.9.24 URGENT INTERRUPT ARBITRATION
- The action pipeline previously ran every emergency action before checking hostile casts. At low health, a heal or defensive could therefore delay a critical Pummel.
- Critical and player-targeted casts now receive an early interrupt pass. Emergency survival follows immediately, then ordinary casts retain the user's configured progress threshold.
https://www.icy-veins.com/wow/protection-warrior-pve-tank-rotation-cooldowns-abilities

VERSION 0.9.20 HERO-TREE AND PVP PRIORITY PASS
- Arms PvP now completes Warbreaker setup before overdue Rend upkeep and consumes confirmed Sudden Death before Bladestorm, matching the current kill-window ordering.
- Fury Slayer now preserves the documented Rampage-to-Bladestorm burst sequence before spending capped Sudden Death; Mountain Thane remains on its separate priority.
- Protection immediately Executes one-health priority targets while retaining its normal Shield Block and Rage reserve everywhere else.
- Ability failure streaks decay after thirty seconds, and Pummel/Disrupting Shout recovery is capped at four seconds so old client rejection cannot block a later emergency interrupt.

ADDITIONAL SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/protection-warrior-pve-tank-mythic-plus-tips
https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities


VERSION 0.9.35 ARENA ROOT-UPTIME RESPONSE
- Current Patch 12.1 Arms and Fury PvP guidance treats uptime as the primary Arena requirement and explicitly identifies Avatar and Bladestorm as anti-root tools that may be more valuable than holding them for burst.
- The implementation reacts only to a confirmed ROOT state when the engaged target is outside melee range. SNARE is deliberately excluded, and the normal offensive path remains unchanged when uptime is already available.
- Arms and Fury retain separate Bladestorm registrations. Protection receives neither the helper action nor the burst-gate exception.
- Blizzard's October 1 tuning increased Mountain Thane Lightning Strike and Ground Current only outside PvP, so no Arena priority was changed for that tuning.

SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/fury-warrior-pvp-rotation-and-playstyle
https://worldofwarcraft.blizzard.com/en-us/news/24296142/hotfixes-august-25-2026


VERSION 0.9.36 PROTECTION PHALANX APEX CADENCE
- Patch 12.1 Protection guidance added Phalanx to the AoE priority: Thunder Clap primes the next Shield Slam with extra frontal damage, so Thunder Clap should be used when the Phalanx buff is absent.
- The plugin already registered the Phalanx aura but never read it. The snapshot now exposes the confirmed buff, and the Protection multi-target priority performs the documented Thunder Clap-to-Shield Slam weave.
- Single-target Shield Slam remains immediate, and the talent and action path are isolated to specialization 73.

SOURCES REVIEWED
https://www.icy-veins.com/wow/protection-warrior-pve-tank-rotation-cooldowns-abilities
https://www.icy-veins.com/wow/protection-warrior-pve-tank-spell-summary
https://www.icy-veins.com/wow/protection-warrior-pve-tank-mythic-plus-tips


VERSION 0.9.37 ARMS PVP RAGE-DUMP ORDER
- Patch 12.1 Arms PvP sustained-damage guidance places Slam above Overpower when Rage is above fifty after Mortal Strike and higher-priority actions.
- The plugin had the correct threshold but evaluated it only after Overpower. The PvP branch now spends Slam at the documented position, while the PvE priority is unchanged.
- The October 13 log audit found only older v0.9.26 and v0.9.33 sessions, with no current Arena combat. Live conclusions remain deferred until a v0.9.37 session is recorded.

SOURCE REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle


VERSION 0.9.38 FURY MOUNTAIN THANE PVE PRIORITY
- Current Patch 12.1 Mountain Thane guidance prioritizes capped Sudden Death and Thunder Blast procs, Bloodbath, Execute, and Rampage before an ordinary Crushing Blow.
- The previous PvE branch placed Crushing Blow before both Execute and the Recklessness Rampage condition, and placed ordinary Execute below Bloodthirst. The branch now follows the documented order after its existing capped-proc checks.
- The Arena Mountain Thane list and Slayer list are separate code paths and remain unchanged.

SOURCES REVIEWED
https://www.method.gg/guides/fury-warrior/playstyle-and-rotation
https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities
https://www.wowhead.com/guide/classes/warrior/fury/rotation-cooldowns-pve-dps


VERSION 0.9.39 ARMS SLAYER PRE-BLADESTORM EXECUTE
- Current Patch 12.1 Slayer guidance places an available Sudden Death Execute immediately before Bladestorm after the major cooldown setup. Consuming Sudden Death advances Slayer interactions and avoids carrying a capped proc through the channel.
- The plugin used an older Bladestorm-before-capped-Execute order. It now establishes Avatar/armor break, consumes the available proc, and then channels Bladestorm.
- Colossus continues to build Colossal Might and use Demolish during its armor-break window.

SOURCES REVIEWED
https://www.method.gg/guides/arms-warrior/playstyle-and-rotation
https://www.wowhead.com/guide/classes/warrior/arms/rotation-cooldowns-pve-dps
https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities


VERSION 0.9.40 PATCH 12.1.5 PROTECTION COLOSSUS RAGE COSTS
- Blizzard's October 13 Patch 12.1.5 notes add a Practiced Strikes effect that reduces Protection Colossus Revenge and Execute costs by ten Rage, explicitly to improve access to both abilities and threat management.
- The plugin now lowers only the corresponding PvE safety thresholds by ten while retaining its active-mitigation reserve.
- Mountain Thane does not receive the discount. Protection PvP keeps its existing deliberate Rage pooling behavior.

SOURCE REVIEWED
https://worldofwarcraft.blizzard.com/en-us/news/24304162/


VERSION 0.9.41 PATCH 12.1.5 PROTECTION OPPRESSOR
- Blizzard's October 6 PvP hotfix increased Warrior Oppressor's Focused Assault cap to six stacks, duration to ten seconds, reduced its cooldown to fifteen seconds, and increased its range to fifteen yards.
- Oppressor replaces Taunt, but the plugin correctly blocks its PvE Taunt path in PvP. A separate Protection-only PvP registration and decision path now applies it during a verified kill window or confirmed teammate focus.
- It is preserved outside those windows and cannot load for Arms, Fury, or PvE.

SOURCES REVIEWED
https://worldofwarcraft.blizzard.com/en-us/news/24296142/hotfixes-august-31-2026
https://www.wowhead.com/spell=205800/oppressor
https://www.icy-veins.com/wow/protection-warrior-pvp-talents-and-builds



VERSION 0.9.42 PROTECTION MORALE KILLER TEAM PEEL
- Current Patch 12.1 guidance identifies Morale Killer as a mandatory Protection PvP talent. Spell 199023 reduces Demoralizing Shout's cooldown and makes affected enemies deal reduced damage to every target.
- The plugin previously reacted with Demoralizing Shout only to pressure on the Warrior. It now recognizes verified burst aimed at a nearby party member and uses the talented shout as a team peel.
- The ally signal is deliberately separate from personal burst, range-limited, and PvP/talent gated.

SOURCES REVIEWED
https://www.wowhead.com/spell=199023/morale-killer
https://warcraft.wiki.gg/wiki/Morale_Killer
https://www.icy-veins.com/wow/protection-warrior-pvp-talents-and-builds



VERSION 0.9.43 ARMS PVP HEROIC STRIKE PROC PRIORITY
- Current Patch 12.1 Arms PvP guidance places Heroic Strike when it procs ahead of Mortal Strike in both sustained and burst priority lists.
- The plugin already handled that ordering inside burst, but its timed sustained Mortal Strike gate could take the global first. A confirmed Master of Warfare replacement now bypasses that gate and is consumed after bleed upkeep.
- The change is confined to Arms PvP; the existing PvE proc branch remains unchanged.

SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.wowhead.com/spell=1269391/master-of-warfare
https://www.wowhead.com/spell=1269394/master-of-warfare



VERSION 0.9.44 ARMS/FURY ARENA OPENER SLOW ORDERING
- Current Patch 12.1 Arms and Fury PvP guides both identify maintaining Hamstring as critical for melee uptime and list it before Storm Bolt in the Arena opener.
- The utility pipeline previously attempted offensive Arena control before slow maintenance. It now reuses a dedicated slow decision immediately before offensive control for Arms and Fury.
- Defensive reactions and teammate peeling still take priority. Protection and other modes retain their established ordering.

SOURCES REVIEWED
https://www.icy-veins.com/wow/arms-warrior-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/fury-warrior-pvp-rotation-and-playstyle



VERSION 0.9.45 PROTECTION COLOSSUS PVE DEMOLISH PRIORITY
- Current Protection PvE priority lists place Demolish on cooldown and before Shield Charge. Blizzard's Midnight tuning moved damage from Colossal Might into Demolish's baseline specifically so the ability remains satisfying at low or no stacks.
- The plugin previously required three Colossal Might stacks, which could leave a ready core cooldown unused and reverse the documented Demolish/Shield Charge ordering.
- PvE now uses ready Demolish inside an eligible cooldown window after its amplifiers. Protection PvP retains its separate three-stack pooling behavior.

SOURCES REVIEWED
https://www.method.gg/guides/protection-warrior/playstyle-and-rotation
https://www.icy-veins.com/wow/protection-warrior-pve-tank-rotation-cooldowns-abilities
https://www.wowhead.com/guide/classes/warrior/protection/rotation-cooldowns-pve-tank
https://www.icy-veins.com/wow/news/hybrid-healer-buffs-class-tuning-midnight-development-notes-january-21st/



VERSION 0.9.46 ARMS SLAYER CAPPED SUDDEN DEATH PRIORITY
- Current Patch 12.1.5 Slayer general priority places Execute with two Sudden Death stacks ahead of Heroic Strike, while a single Sudden Death proc follows Heroic Strike and Mortal Strike.
- The plugin previously evaluated Heroic Strike before the generic capped-proc guard. Slayer PvE now consumes the capped proc first to avoid wasting a newly generated stack.
- Colossus and PvP retain their Heroic Strike-first priorities, matching their separate lists.

SOURCES REVIEWED
https://www.method.gg/guides/arms-warrior/playstyle-and-rotation
https://www.wowhead.com/guide/classes/warrior/arms/rotation-cooldowns-pve-dps
https://www.icy-veins.com/wow/arms-warrior-pve-dps-rotation-cooldowns-abilities



VERSION 0.9.47 FURY MOUNTAIN THANE BLOODBATH/THUNDER BLAST ORDERING
- Current Mountain Thane single-target priorities place a capped two-charge Thunder Blast before Bloodbath, but a normal one-charge Thunder Blast during Avatar after Bloodbath.
- The plugin treated any Avatar-active Thunder Blast as the capped case. It now reserves the early position for two charges, AoE, or a nearly expired proc, then uses Bloodbath before the one-charge Avatar extension.
- The PvP Mountain Thane branch remains unchanged and continues to prioritize Stormblast after Rampage.

SOURCES REVIEWED
https://www.method.gg/guides/fury-warrior/playstyle-and-rotation
https://www.wowhead.com/guide/classes/warrior/fury/rotation-cooldowns-pve-dps
https://www.icy-veins.com/wow/fury-warrior-pve-dps-rotation-cooldowns-abilities



VERSION 0.9.48 SHIELD-BREAK STALE COOLDOWN PROTECTION
- The retained live log shows Wrecking Throw confirmed twice only 0.44 seconds apart and requested again shortly afterward, despite its 45-second base cooldown. This demonstrates stale loader cooldown data after a successful projectile cast.
- Wrecking Throw and Shattering Throw now use confirmed history as a twenty-second fallback lockout. Native cooldown readiness still governs normally.
- Twenty seconds remains below the 22.5-second Wrecking Throw cooldown produced by the Demolition PvP talent, so valid reduced-cooldown casts are not delayed.

SOURCES REVIEWED
Local scripts_log/sylvanas_warrior/session.log
https://www.wowhead.com/spell=384110/wrecking-throw
https://warcraft.wiki.gg/wiki/Demolition



VERSION 0.9.49 BOUNDED COMBAT DIAGNOSTIC SNAPSHOTS
- The retained runtime log had grown to 4.6 MB. Inspection showed exact health, predicted-health, and Rage changes altered the snapshot signature every 0.1-second update and bypassed the intended one-second combat interval.
- Combat and training snapshots now obey the one-second cadence regardless of ordinary telemetry changes. Separate event/status records remain immediate, preserving the evidence needed for live debugging.
- Idle snapshots retain their ten-second unchanged cadence and still record meaningful context changes immediately.

EVIDENCE REVIEWED
Local scripts_log/sylvanas_warrior/session.log



VERSION 0.9.50 FURY PVE WRECKING THROW DAMAGE FILLER
- Method's current Patch 12.1 Fury priority lists place Wrecking Throw after the normal rotational attacks for both Slayer and Mountain Thane.
- The plugin previously reserved Wrecking Throw entirely for large absorb shields, leaving an avoidable empty PvE global when every ordinary Fury attack was unavailable.
- Fury now uses Wrecking Throw as its last PvE damage filler. Arena, battleground, and World PvP continue to reserve it for confirmed absorb removal, and the new rule cannot enter Arms or Protection.

SOURCE REVIEWED
https://www.method.gg/guides/fury-warrior/playstyle-and-rotation

VERSION 0.9.53 ALL-MODE GUI AND HOTKEY AUDIT

- Reorganized all user-facing settings into eight readable tabs based on purpose.
- Added a dedicated Players tab for PvP burst, trinket, peel, healer-control, and target-line behavior.
- Added native persistent keybind objects for every boolean profile and global option across all 24 specialization/activity profiles.
- Kept numeric thresholds on bounded value controls because they are values rather than toggle states.
- Retained existing specialization and activity visibility gates, including Protection-only route/tank settings and PvP-only player controls.
- Reserved F1 and F7 for the main and boss-helper windows to prevent hotkey collisions.

VERSION 0.9.54 PROTECTION COLOSSUS AND TRAINING-DUMMY AUDIT

- Current Protection 12.1.5 guidance identifies Demolish as the Colossus signature attack and places it ahead of Shield Charge and Shield Slam.
- Protection now prefers Demolish and uses Colossus Smash when Demolish is unavailable in the learned build.
- The PvE signature action can run after mitigation while the generic burst detector holds other cooldowns; the cooldown option remains authoritative.
- Project Sylvanas' native dummy helper remains the first detector. Stable legacy city IDs and conservative name fallbacks cover capital-city practice targets when the helper is unavailable.
- References: https://www.method.gg/guides/protection-warrior/playstyle-and-rotation and https://warcraft.wiki.gg/wiki/Training_Dummy

VERSION 0.9.55 THREE-SPEC WARRIOR SUITE INTERFACE

- Reworked the Lua-rendered panel around the supplied framed-suite reference while retaining the established Warrior controls and two-window lifecycle.
- Arms, Fury, and Protection now have separate crest geometry, palettes, etched header motifs, titles, and activity-profile labels.
- Toggle rows use switch-style states, persistent hotkey boxes, and previous/next key selectors. Direct key capture remains available by clicking the key box.
- Spec and activity filtering remains authoritative, so presentation changes cannot expose or execute foreign controls.

VERSION 1.0.0 — WOW FOREVER DUAL-RUNTIME RESEARCH

Research date: 2026-10-15. WoW Forever is treated as its own game family, not
as a Midnight talent profile. The current public data reports client 1.60.1 and
a level-30 beta cap. Forever retains ranked Warrior spells and stance/rage
constraints, while its talent trees substantially change Classic Era talents.

Implementation consequences:
- Client family is read from core.get_game_version() and must be exactly
  "Forever" or "Midnight". Unknown families stop execution.
- Forever and Midnight have separate spell catalogs, rotations, utility modules,
  saved setting identifiers, hotkeys, and crash-recovery log directories.
- Forever chooses the highest learned rank from each spell's rank list.
- Arms prioritizes Rend upkeep, Mortal Strike, reactive Overpower, safe cleave,
  and excess-Rage dumps. Fury uses Death Wish/Recklessness windows, Bloodthirst
  when learned, safe Whirlwind/Cleave, and conservative queued attacks.
- Protection prioritizes Shield Block, Revenge, Shield Slam, pack Thunder Clap,
  Demoralizing Shout, and Sunder Armor threat.
- Unlearned talent actions fail closed. Passive talents require no cast entry.
- Midnight dungeon route and boss datasets are runtime-gated off in Forever.

Sources consulted:
- Icy Veins WoW Forever Arms, Fury, and Protection Warrior guides.
- ForeverDB Warrior builds and rotation data.
- AHledger Warrior class changes, extracted from the Forever client tables.
- WoW Forever Talents build dataset.

The beta may change spell data between builds. Offline validation proves module
and registry isolation; it cannot replace in-client testing of range, equipment,
stance, rage, and server-side usability responses.

VERSION 1.5.0 — FOREVER MOVEMENT AND THREAT AUDIT

- Blizzard's October 15 fix makes Improved Berserker Rage reliably remove
  movement impairments. The snapshot now distinguishes snares from roots. A
  Warrior with the talent enters Berserker Stance and breaks a root beyond melee
  range or a slow preventing gap closure, then returns to the spec's stance.
- Fury may use talented Berserker Rage as a ten-Rage generator only outside PvP,
  at very low Rage, and only after safe Bloodrage is unavailable. PvP preserves
  it for Fear and movement control.
- Protection now maintains Thunder Clap's attack-speed reduction against one
  active attacker as well as packs. On packs, Thunder Clap precedes Shield Slam;
  on one target, the high-threat Shield Slam retains priority when learned.
- Current Arms guidance and Sunder's corrected threat/AP scaling support all five
  armor-reduction stacks on durable targets. Arms and Fury now finish five stacks
  when the target lifetime justifies it instead of stopping at two while solo.
- Sources: Blizzard WoW Forever Development Notes updated October 15; Wowhead
  Improved Berserker Rage spell data; ForeverDB Warrior PvE/PvP and build data,
  checked October 15, 2026.

VERSION 1.4.0 — OCTOBER 15 FOREVER BUILD AUDIT

- Blizzard's October 15 build makes Battle Shout raid-wide, removes spell
  pushback from Slam, fixes Overpower activation against much lower-level
  enemies, fixes Improved Berserker Rage's movement-impair removal, and fixes
  Fury Lingering Rage blocking out-of-combat health regeneration. The existing
  spell catalog remains compatible with these server-side fixes.
- Protection now uses Cleave on safe multi-target pulls with excess Rage, as the
  current level-30 tank priority specifies. Heroic Strike remains the single-
  target alternative and both continue to use guarded next-swing queue logic.
- A loose dungeon enemy first receives Taunt. If Taunt is cooling down, the
  plugin checks Mocking Blow's native cooldown before entering Battle Stance,
  applies its six-second fixate, then restores Defensive Stance. This avoids a
  failed-ability stance loop.
- Victory Rush is first reserved for healing below the configured threshold. If
  health is already safe, Arms, Fury, and Protection now consume the Victorious
  proc for its free damage before it expires.
- Bloodrage now respects current and predicted health: DPS holds it below 50%,
  while Protection's Improved Bloodrage path uses a 35% floor. Emergency actions
  retain priority and no health is spent merely to fill Rage during danger.
- Sources: Blizzard WoW Forever Beta Development Notes updated October 15;
  ForeverDB Warrior PvE, abilities, builds, and macros; Wowhead Forever Arms,
  Fury, and Protection level-30 guides, checked October 15, 2026.

VERSION 1.3.0 — FOREVER REACTIVE COMBAT AND RAGE AUDIT

- Current build 1.60.1.70374 guidance explicitly pairs Sweeping Strikes with an
  available Overpower. Arms now activates the cleave before consuming the proc.
- Battle Shout lasts three minutes but can expire during long encounters; combat
  utility now refreshes it after urgent interrupts, defensives, and control.
- Hamstring now catches low-health PvE runners for Arms and Fury. PvP Arms gains
  Demoralizing Shout against multiple melee attackers, while Fury gains Thunder
  Clap against melee groups, matching the current control guidance.
- Death Wish's Forever drawback is 5% increased damage taken. Automatic use now
  requires a safe current and predicted health level, while Fear can still invoke
  its immunity as an emergency Fury fallback.
- Protection may use Retaliation on a large physical pull only at high predicted
  health and without incoming magic pressure, then returns to Defensive Stance.
  Concussion Blow can also stop a hard hitter when health is under pressure.
- Next-swing queues remain latched for slow weapons until their observed combat
  event, with a five-second recovery if the client never reports the event. This
  prevents a repeated Heroic Strike/Cleave input from disturbing the queue.
- Sources: ForeverDB Warrior PvE, PvP, leveling and spell records; Wowhead Forever
  level-30 Arms/Fury guides and Protection abilities, checked October 15, 2026.

VERSION 1.2.0 — FOREVER COMBAT FLOW AND SAFETY AUDIT

- Rechecked current ForeverDB and Wowhead Forever Warrior references for build
  1.60.1.70374. Protection now separates Last Stand's health buffer from lethal
  Shield Wall timing, maintains Defensive Stance outside a deliberately safe
  solo Execute, and adds Rend only after primary Sunder threat is established.
- Fury now applies Sunder Armor to targets above 70% health when their estimated
  lifetime justifies the Rage cost, while keeping Overpower and Bloodthirst first.
- PvP utility now restores each spec's correct stance after Disarm, Intercept,
  Hamstring, or Retaliation. Protection can stance-dance for Hamstring without
  leaving tank rotation logic in Battle Stance.
- Intimidating Shout is held in dungeons and raids so an automated cast stop
  cannot scatter enemies into another pull. Concussion Blow remains available.
- Heroic Strike and Cleave are modeled as queued next-swing attacks. An accepted
  queue no longer blocks the decision engine waiting for a delayed weapon-hit
  confirmation, and a short queue throttle prevents rapid duplicate inputs.
- Sources: ForeverDB Warrior PvE/PvP and spell records; Wowhead Forever Arms,
  Fury, and Protection level-30 guides and Protection ability reference; Blizzard
  WoW Forever beta development notes through October 8, 2026.

VERSION 1.1.0 — FOREVER BUILD 1.60.1.70374 DEEP AUDIT

The 15 October ForeverDB dataset supersedes the earlier 70338 research. The
current beta remains capped at level 30, so Mortal Strike (40), Bloodthirst
(40), Shield Slam (40), Whirlwind (36), and Pummel (38) are retained for future
levels but can never execute until the game confirms that they are learned.

Implemented findings:
- Charge uses ranks 100, 6178, and 11578. Build 70374 removed Bloodrage's
  forced-combat clause, so healthy Warriors may safely generate Rage first.
- Spearing Strike spell 1310222 is supported only for Arms when learned.
- Overpower is a baseline Warrior reaction on Forever and remains usability-
  gated by its dodge proc instead of being incorrectly restricted to Arms.
- Rend, Hamstring, Thunder Clap, Demoralizing Shout, and Sunder Armor use
  target-specific confirmation history to prevent hidden-aura recast loops.
- Arms consumes Overpower before normal spenders, pools for Sweeping Strikes,
  limits Sunder investment by activity and target lifetime, and only attempts
  Slam when a confirmed post-swing signal is available.
- Fury uses Death Wish at a valid pooled burst window, maintains Rend, consumes
  Overpower, uses safe cleave, and preserves Rage instead of blindly queuing
  Heroic Strike. Bloodthirst and Whirlwind activate naturally at later levels.
- Protection refreshes Shield Block near expiry, consumes enhanced Revenge,
  builds five Sunder stacks in group PvE and two while solo, maintains pack
  attack-speed and attack-power reductions, and separates Last Stand from the
  longer Shield Wall emergency.
- PvP maintains Hamstring, disarms only confirmed weapon users, uses Piercing
  and single-target slows through spec-safe entries, breaks Fear with Berserker
  Rage, and permits Intercept only in its required stance.
- Forever's allowlist now rejects every unknown resolved spell ID.

Primary current sources: ForeverDB Warrior PvE and PvP guides and client spell
pages, Wowhead's level-30 Arms guide, Icy Veins' Arms/Fury/Protection guides,
and the AHledger client-table comparison. Offline checks cover priority and
isolation behavior; equipment and native usability still require live testing.



VERSION 1.6.0 — LEVEL-AWARE FOREVER ROTATION AUDIT

- The live player level is sampled into every combat snapshot. Four level
  bands tune low-level Rage dumps and Sunder stack goals without pretending an
  untrained spell exists; the spellbook remains the final availability gate.
- Current build data says Whirlwind always strikes with both weapons and
  Raging Blows reduces Whirlwind and Cleave cost by 3 Rage. Fury now uses
  Whirlwind as a post-Bloodthirst single-target filler and lowers safe area
  thresholds when Raging Blows is learned.
- Gore Drinker triggers from Berserker Rage and Bloodthirst. PvE Fury can prime
  its three healing swings under moderate pressure while PvP preserves
  Berserker Rage for control removal.
- Death Wish now increases incoming damage by 5%; automatic use requires a
  stable health position. Recklessness remains independently available because
  the three major Warrior cooldowns no longer share a cooldown.
- Vanguard is explicitly detected before Protection attempts to Charge from
  Defensive Stance. Builds without Vanguard enter Battle Stance for the pull.
- Focused Rage discounts Protection's excess-Rage queued attacks, and Shield
  Block is reserved for detected physical pressure.
- Sources checked October 15, 2026: Blizzard's Warrior class deep dive,
  Wowhead's current Forever Warrior beta build updates and Arms overview, and
  WoW Forever Builds & Tools data for build 1.60.1.70374.

VERSION 1.7.0 — LEVEL-30 PRIORITY AND TRAINER-GATE AUDIT

- Added explicit minimum levels for baseline and trainer abilities, including
  Execute at 24, Whirlwind at 36, and Pummel at 38. Talent abilities remain
  governed by the live spellbook so Forever Legacy bonus points can unlock
  them earlier than a normal tree path.
- Level-30 Fury no longer spends a global maintaining Rend. It prioritizes the
  documented Overpower, durable-target Sunder, and queued swing flow, and holds
  PvE Execute until 70 Rage so resources can carry into the next pull. PvP
  Execute remains immediate.
- Protection now establishes safe multi-target threat with Thunder Clap before
  routine Shield Block, while lethal Shield Wall and Last Stand checks retain
  priority. Shield Block remains limited to physical pressure.
- Level detection now tries both get_level and get_character_level before using
  its conservative fallback.
- Sources checked October 15, 2026: Blizzard's WoW Forever beta development
  notes (including the October 15 update), Wowhead's current level-30 Arms,
  Fury, and Protection guides, and WoW Forever build 1.60.1.70374 data.

VERSION 1.7.1 — GUI INPUT SYNCHRONIZATION AUDIT

- Replaced the sparse mouse-wheel fallback table with a dense receiver-aware
  probe. A missing core.input wheel function can no longer prevent the root or
  graphics wheel API from being checked.
- Replaced one-way hotkey-to-checkbox copying with change-aware two-way
  synchronization. Native Project Sylvanas menu clicks, custom GUI clicks, and
  keybind edges now converge on the same persistent state without reverting.
- Added regression checks for root wheel fallback, native checkbox persistence,
  paired hotkey updates, and subsequent hotkey control.

VERSION 1.8.0 — BUILD 70425 STANCE AND LIVE-LOG AUDIT

- The October 16 beta client is build 1.60.1.70425. Blizzard's latest notes do
  not add a new Warrior rotation change; they retain the current level-30 cap
  and confirm Demoralizing Shout threat, Last Stand, Battle Shout, Slam, and
  Overpower fixes from the preceding builds.
- Fixed a cross-layer Fury disagreement: the level-30 damage priority correctly
  omitted Rend, but the utility controller could still hold Battle Stance while
  waiting to apply it. Level-30 Fury now restores Berserker Stance, pre-30 Fury
  uses Battle Stance, and post-30 Fury only enters Battle Stance for due Rend.
- Arms now explicitly restores Battle Stance in Forever PvE because Blizzard
  documents that Spearing Strike requires it.
- The new beta has a known action-bar stance-swap defect. This plugin selects
  abilities through the spellbook API and does not depend on action-bar pages.
- Existing live logs were from obsolete 0.9.x builds and contained no current
  combat evidence, so no unsupported tuning conclusions were drawn from them.
- Sources checked October 16, 2026: Blizzard's official WoW Forever beta
  development notes and maintenance confirmation for client build 70425.
