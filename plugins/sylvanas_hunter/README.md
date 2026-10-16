SYLVANAS HUNTER 1.6.9 — MIDNIGHT + WOW FOREVER

PLUGIN FOLDER RULE: Every file inside this plugin folder and every subfolder
must end in `.lua` or `.md`. Release packaging fails if any other file type is
present. Images and icon atlases are embedded as Lua data; never place PNG,
JPEG, ZIP, Python, JSON, layered-art, or other file types in the plugin folder.

Built for Project Sylvanas's Midnight and WoW Forever client APIs. This is an offline-validated
release candidate; live testing is still required. It is not a claim of flawless
gameplay, maximum DPS, or verified behavior on every talent build.

Version 1.6.8 extends that policy around the verified level 26–30 rank-cost
jump. The rotation raises its mana reserve in that band, adjusts Serpent Sting's
target-life floor by level, and requires three targets before Multi-Shot while
mana pooling is active. Live learned spells and costs remain authoritative for
future cap increases. Status and snapshots expose the detected level band.
Version 1.6.9 strengthens level-aware Forever leveling and PvP survival. BM and
Marksmanship now enter Aspect of the Monkey before a forced melee trade from
level 4 onward. Survival uses Monkey before Aspect of the Beast unlocks and
returns to Monkey during dangerous PvP melee pressure. Solo PvE uses
Concussive Shot from level 8 while a target closes, gaining more ranged attacks
before the dead zone. Pet recovery, Mend Pet, Wing Clip, Frost Trap,
Disengage, Deterrence, Feign Death, and Readiness now have explicit character
level boundaries in addition to spell-book validation.


Version 1.6.7 extends the level-aware Forever policy. BM and Marksmanship can
maintain Track Hidden from level 24 against Rogue and Druid targets without
overriding Survival's Track Humanoids damage tracking. Scare Beast can safely
control a selected hostile pet from level 14, and its fear ranks are protected
from the damage rotation. Distracting Shot can peel a dungeon mob from a healer
from level 12 only while the Hunter is healthy and free of existing attackers.
Mana reserves now scale across the level 1–9, 10–17, 18–24, and 25+ toolkits,
and Serpent Sting is withheld from targets forecast to die before useful ticks.

Version 1.6.6 adds automatic character-level detection to every snapshot and
Forever status log. Forever priorities now unlock by the real trainer/talent
levels: Serpent Sting at 4, Hunter's Mark and Arcane Shot at 6, Hawk and pet
play from 10, Multi-Shot at 18, Aimed Shot at 20, Rapid Fire at 26, and the
level-30 Survival melee package. Marksmanship's level-40 Sniper Shot cannot
enter a level-30 rotation early. BM now follows the current simulator sequence
of Multi-Shot then Arcane Shot and no longer spends time casting Aimed Shot.
Rapid Fire is held for PvP burst, while PvE uses it after mana falls below 95%.
The Pet-first option now provides a bounded 1.25-second threat hand-off instead
of being a display-only setting; it can never stall the rotation indefinitely.

Version 1.6.5 keeps the hard-separated WoW Forever runtime and adds Survival-only PvP Track Humanoids automation for Improved Tracking, a dedicated saved toggle/hotkey, unknown-aura repetition protection, and the current explicit Mongoose Bite/Strider Kick/Raptor Strike priority. It retains level-cap sting fallback, simulator-backed BM Multi-Shot, target-life-aware Lacerate, all-spec Rapid Fire, spec-aware Readiness, Hawk tracking, closing-speed checks, melee-only Deterrence, and pressure-safe pet recovery. `core.get_game_version()` and `core.get_exact_game_version()` select Midnight or Forever before spell data, settings, logs, utility, or rotations load. Midnight retains its original focus modules and storage keys. Forever uses its own mana-based, rank-aware spell table; separate BM, Marksmanship, and Survival rotations; `hh_forever_` settings and hotkeys; and `sylvanas_hunter_forever/logs`. Midnight encounter data and modern abilities never enter Forever combat decisions.

Forever BM maintains Aspect of the Hawk, Hunter's Mark and Serpent Sting, keeps Summon Hawk active, uses Bestial Wrath in permitted windows, selects Multi-Shot for safe packs, and spends excess mana with Arcane Shot. Marksmanship adds Rapid Fire, Sniper Shot, Multi-Shot and Aimed Shot priorities with a mana reserve. Survival switches between ranged approach logic and its melee Strider Kick, Mongoose Bite, Counterattack, Lacerate and Raptor Strike priorities.

Version 1.4.64 expands city practice-dummy support for all three specs. Detection now uses the native unit flag, Project Sylvanas's maintained unit-helper database, known capital-city NPC IDs, and name fallbacks for raid, dungeon, PvP, cleave, tanking, damage, target, combat, training-bag, Kelpfist, and Crystalmaw variants. Dummy mode remains isolated to World PvE and can be disabled per profile.

Version 1.4.65 rebuilds the F1 customer window around a clear Hunter dashboard: a persistent left navigation rail, activity selection, wide option rows, explicit ON/OFF and hotkey controls, and compact threshold cards. Beast Mastery, Marksmanship, and Survival each use a distinct color system, title, character identity, embedded portrait, icon atlas, and spec-filtered option set. The redesign does not add another window; F1 remains the main GUI and F7 remains the boss helper.

Version 1.4.63 reorganizes the customer window into 12 focused tabs and adds persistent, conflict-safe hotkeys to every boolean feature. Each bind toggles only the currently active specialization and activity. New controls cover execute usage, dummy mode, manual-input yielding, urgent interrupts, CC interrupt fallback, predictive defensives, teammate Roar, emergency pet Exhilaration, automatic kiting, separate target/healer lines, boss world cues, boss auto-popup, and performance telemetry.

Version 1.4.62 removes the largest verified runtime hot paths. Snapshots now use Project Sylvanas's cached enemy helper, reuse spatial and aura reads, render PvP lines from snapshot data, cache repeated colors, batch routine log writes, force lifecycle/error saves, and record live tick/snapshot timing in every heartbeat.

Version 1.4.61 corrects the Blinding Vale Lightblossom Trinity helper. Meittik
no longer displays Ikuzz’s root-kiting instructions; Meittik, Lekshi, and Kezkitt
all receive the shared encounter card and current mechanic-specific cues.

Version 1.4.60 adds a one-second execution circuit after three different native
cast failures within 0.75 seconds. It bounds failure storms when the client
control flag is late or unavailable and logs control, busy, and GCD evidence.

Version 1.4.59 uses the native player-control state at the final execution gate.
Confirmed stuns, fears and incapacitation stop invalid request bursts even when
the raw spell usability API continues reporting individual abilities as usable.

Version 1.4.58 records the active spec's charge count, maximum, recharge start,
duration and computed fractional value in the persistent five-second diagnostic.
Fresh native logs can now validate charge timing without a debugger attached.

Version 1.4.57 adds fractional charge awareness for Barbed Shot, Kill Command,
Aimed Shot and Wildfire Bomb. Each spec can spend just before recharge waste
instead of waiting for the integer charge counter to reach its cap.

Version 1.4.56 measures successful local cast acknowledgements and uses a
bounded 1.2–3.0 second confirmation window. This prevents transient Arena
latency from creating false cast failures while preserving finite retry recovery.

INSTALL AND START
1. Place this entire sylvanas_hunter folder under the loader's scripts folder.
2. Reload scripts on a Hunter. The header rejects other classes and unsupported
   clients. BM, MM and Survival use automatic detection (IDs or spec indexes).
3. Open Hunter: BM / MM / Survival or the themed Hunter command window.
4. Enable Hunter to allow eligible combat actions to cast immediately.
5. Use F1 for the main GUI and F7 for the compact boss helper.
6. Each spec/activity has its own enable switch; there is no observe mode.
   Turn off the global Enable switch or turn on Pause to stop actions.

ACTIVITIES AND ISOLATION
24 independent settings profiles: three specs x World PvE, Delves, Dungeons,
Mythic+, Raids, Arena, Battlegrounds, and World PvP.
Instance and delve APIs choose the activity. A hostile player target chooses
World PvP outside instances; an NPC target keeps World PvE even in War Mode.
PvP cooldowns are held until the PvP Burst button is allowed, unless that profile
has automatic kill windows enabled. Automatic PvP burst defaults ON.

The decision function and cast executor both enforce spec allowlists. Allowed
spell replacements are explicit, including Kill Shot -> Black Arrow and Raptor
Strike -> Eagle/Swipe. Unknown replacements stop that action. Spec, player,
activity and assigned role changes invalidate pending decisions and histories.
Assigned tank/healer roles stop casting. Settings use unique profile keys and
never import Ret, Rogue, Warrior or healer rotation state.

ROTATION AND UTILITY
BM: Wild Thrash / Beast Cleave setup and post-Bestial Wrath refresh with brief
aura visibility grace, Barbed charge protection and burst preparation, Pack
Leader summon pressure, learned Dire Beast, Cobra Fang / Killer Cobra procs,
Dark Ranger Black Arrow above execute range, and cost-aware Focus reservation.
Arena/BG opponents already in combat count as engaged cleave participants;
protected targets and idle opponents remain excluded. Per-ability splash checks
still protect nearby crowd control. These changes have no measured live DPS gain.
MM: Precise Shots, Trick Shots setup, Trueshot, safe explosive/Volley/chakram
damage, Aimed charge protection, Rapid Fire, execute and focus recovery.
Survival: Tip of the Spear, Twin Fangs Takedown setup, empowered Boomstick/bombs,
Sentinel chakram, Raptor Strike and ranged Eagle assistance.
All actions require a learned, usable, ready spell with range/LoS checks where
applicable. Existing target engagement is required; the plugin does not select
fresh pulls, move the player, navigate battlegrounds, or queue content.

Defensives use current/predicted health and optional BigWigs/ExBoss timers.
Interrupts use live cast progress, recheck cast identity, and briefly yield after
a teammate's kick. Stun stops require known PvP DR/immunity information.
Pet care includes Mend, Call Pet 1, and safe PvE revive attempts. Pet recovery
defaults ON for MM at user request; switch it OFF for a petless setup. No pet is selected
from the stable or abandoned. Misdirection uses a party tank or a living solo pet.
Purges require a confirmed purgeable buff. Master's Call reacts to confirmed roots.
Arena Trap assistance only attempts stationary healer setups with known DR,
explicit immunity clearance, no visible debuffs, and no allied target/pet pressure.
Moving healer trap prediction is left to manual play.
Harpoon defaults ON for Survival. Disengage, Feign Death, racials, consumables and automated
teammate sacrifice are left to manual play; geometry/talent evidence is insufficient
to automate those actions reliably in this release.

GUI / OVERLAYS / BOSS GUIDE
The reference-style command panel features Rexxar and Misha for BM, Alleria
Windrunner for MM, and Huln Highmountain for Survival. Each spec has approved
custom character artwork, colors, Hunter emblems and buttons. Portraits are
embedded BMP data in Lua; each spec uses its own cached 3x3 PvP BMP
icon atlas. BM uses bronze/leather fangs, MM uses silver elven arrowwork,
and Survival uses hammered-steel rivets and embers. The same spec-owned set
appears on tabs, settings rows and the ability dock. Native emblems are a fallback if texture drawing is unavailable. There are NO PNG, JPEG,
PSD, layered artwork files or external texture dependencies in this package.
Activity tabs edit only the selected settings profile; the header separately
shows the live detected activity. Portrait textures load once per spec and the
three separate ability atlases each load once when their spec is shown. Both windows use the dedicated window callback,
independent of whether the loader settings menu is open.

Tabs: Damage, Control/PvP, Defense, Pet/Utility, the detected spec rotation,
Display/Logs, and DPS Guide. Every applicable profile setting in the native menu
appears in the themed GUI. Harpoon is Survival-only; healer Trap assistance is
Arena-only; Misdirection and boss timers are PvE-only. Numeric settings have
plus/minus buttons and a clickable track. OFF values remain boolean false.
Spec-specific rotation controls are stored only in the matching spec profiles.
The header exposes PvP burst permission and distinguishes automatic windows.
Existing saved burst settings are preserved; no defaults are silently enabled.
Hunter_GUI_Preview.html beside the package displays actual native drawing traces
captured through an offline API mock. It is a static preview, not a live web GUI.

The Rogue/Ret-derived DPS encounter-card system covers the inherited 28 Season 2
dungeon bosses. All three Hunter specs use it in all PvE modes. Known live casts
and boss timers select the immediate prompt; unknown bosses receive generic DPS
coaching. The compact boss helper includes the mechanic card. World markers
show pressure/priority indicators, without inventing stack/soak destination points.
Raid and delve bosses beyond the inherited dungeon list use generic guidance;
they do not have a complete authored encounter database. English spell/boss names
are needed for named cards; generic cast handling continues on other locales.

COORDINATION / LOGS
Optional read-only hook: SylvanasHunterStatus() returns spec, mode, status,
version, enable and pause state. Optional SylvanasHunterCombatHold(context) can request
a combat hold from a companion plugin. No unrelated plugin is edited.
Persistent logs are ON by default. Routine records are drained in batches no more than 0.25 seconds apart, which avoids many tiny disk writes. Lifecycle events, API errors, and SAVE NOW force a synchronous flush. A file-size check runs before records leave memory.
Files are under the loader's scripts_data/sylvanas_hunter/logs/ directory,
named session_00000001.log, session_00000002.log, and so on. Reloading never
recreates an old file. Files rotate near 1 MB; old files are retained.
The log includes version, spec, activity, profile settings, current health,
Focus, pet/target health, cast requests/confirmations/failures, state changes,
five-second snapshots, API errors and available lifecycle events.

To send a report: F1 -> DISPLAY / LOGS -> COPY CURRENT, then paste into chat.
After restarting following a crash/disconnect, use COPY PREVIOUS to recover
the preceding session. SAVE NOW retries queued records after a storage error.
Clipboard export includes the last 64 KB; complete files remain on disk and
can also be opened in a text editor and copied. No log files are auto-deleted.
If logging is switched OFF, new diagnostic records are not written.
Successful native writes survive plugin reloads and process termination.
A sudden system/power failure can still lose OS-buffered final writes; the
plugin cannot force a filesystem sync or write after its process has crashed.
Storage failures are shown in the GUI and queued in memory for retry; queued
records cannot survive termination while the storage API itself is failing.

VALIDATION AND LIMITS
See TEST_REPORT.md and tests/scenarios.lua. Regression tests cover all profiles,
foreign actions and overrides, role/spec/mode changes, casting confirmation,
urgent preemption, range/LoS/GCD/charges, pet state, CC protection, both GUIs and
boss guide behavior. They use a simulated API, not a running WoW character.
Live cast event payloads, latency, aura visibility, pet pathing, ground placement,
native font metrics and competitive DPS remain live-test requirements. Priority
lists are practical adaptations of current primary sources, not a full simulator
translation of every hero talent, apex interaction, set bonus or encounter.

LIVE TEST ORDER
Enable on a dummy for each spec, including moving MM and forced-range Survival.
Use short single-target and safe cleave sessions. Test spec swaps,
pause/re-enable, pet death/recovery, protected neighbors, kicks and failed casts.
Check a delve, dungeon and raid before arena/BG tests; verify PvP burst holds,
healer Trap conditions and assigned-role changes. Capture diagnostic logs for any
unexpected wait or cast. Live performance tuning must follow those observations.

1.4.7 readability update: larger labels and notes, opaque contrast panels,
simplified headers, restrained spec metalwork, and accent markers for selected
tabs. Compact switches retain their high-contrast ON/OFF treatment.

1.4.7 controls: press F1 to show/hide the main command panel. A held key
toggles only once and hiding the GUI does not change combat enable/pause.
Version 1.4.17 removes the old DPS status HUD. The plugin creates exactly two
windows: the large F1 command GUI and the compact F7 boss helper.

Version 1.4.18 adds confirmed-missing Hunter's Mark upkeep for all three specs,
prevents three-point Nature's Ally BM from repeating Kill Command without a
filler, removes the invalid Black Arrow Precise Shots assumption, permits
Midnight Steady Shot while moving, and prioritizes emergency Turtle before
Exhilaration below the configured Turtle threshold.

Version 1.4.19 banks BM's last Nature's Ally Kill Command when Bestial Wrath
is within three seconds, while still spending capped charges and honoring a
ready Howl summon. Survival no longer uses Kill Command above one Tip stack and
requires two Tip stacks for non-Twin Fangs Takedown whenever aura data is known.

Version 1.4.20 tracks the confirmed Bestial Wrath sequence across the required
Wild Thrash refresh, then launches Pack Leader's first post-Wrath Kill Command
for Stampede. It holds an unnecessary pre-Wrath cleave refresh, lets Dark Ranger
Black Arrow establish missing cleave, and delays PvP Hunter's Mark until high
Focus so it does not displace immediate pressure.

Version 1.4.21 permits Master's Call in every activity. It casts only when the
crowd-control helper positively confirms the Hunter is rooted and a valid pet
can execute the ability. Unknown root state, missing pets, unsupported pet
families, cooldowns, range, and line of sight continue to hold the action.

Version 1.4.22 immediately stops high-priority enemy channels because their
damage or control is already active. Low-priority channels and ordinary casts
continue to use the configured interrupt-progress threshold.

Version 1.4.23 corrects the MM PvP burst sequence. After Volley, it protects an
active instant Aimed Shot, uses Rapid Fire, and then enters Trueshot for the
following precision sequence. PvE keeps its separate cooldown ordering.

Version 1.4.24 moves BM PvP Hunter's Mark into low-Focus downtime. Missing Mark
no longer consumes the opening global ahead of Black Arrow, capped charges,
Barbed Shot preparation, Bestial Wrath, or the normal damage priority.

Version 1.4.25 detects positively confirmed pet crowd control in PvP. During an
authorized burst window, BM uses Bestial Wrath immediately to free the pet and
restore Kill Command and pet pressure. Unknown or absent control never triggers it.

Version 1.4.26 lets only last-moment casts and high-priority active channels
preempt emergency defensives. A successful stop prevents the incoming effect;
routine percentage-based interrupts remain behind Turtle and emergency healing.

Version 1.4.27 makes Survival range recovery activity-aware. PvE uses Aspect of
the Eagle before Harpoon to preserve damage without blindly entering mechanics;
PvP retains Harpoon first for immediate target pressure and gap closing.

Version 1.4.28 corrects Exhilaration's native timing. The heal now waits for the
global cooldown instead of issuing a doomed request and entering retry backoff;
Turtle remains an off-global emergency action.

Version 1.4.29 uses Exhilaration to save an active pet at 20% health or lower.
The branch requires both defensive and pet-healing permissions and retains the
spell's native cooldown, global-cooldown, and active-pet checks.

Version 1.4.30 adds proactive PvP pressure mitigation. Two or more engaged
enemies actively targeting the Hunter can trigger Survival of the Fittest at
80% health or lower; one attacker still follows the normal configured threshold.

Version 1.4.31 fixes the live logger's missed city-dummy classification. It uses
the unit flag, Project Sylvanas helper, and a guarded training/target/combat-dummy
name fallback. Heartbeats now record target name and classification source.

1.4.7: At user request all applicable feature toggles and master casting/burst default ON. Boolean persistence keys migrated once to v2; later OFF choices persist. Pause stays OFF. System tab exposes all global P.S controls; MORE OPTIONS reveals additional profile rows. Numeric thresholds are preserved. Spec/activity availability restrictions and learned-spell checks still apply.
1.4.8: BM PvP completes the current two-Barbed Shot setup before an authorized
Bestial Wrath when the first Barbed cast was confirmed recently and another
charge is available. It never holds Wrath when that charge is absent. PvE
behavior is unchanged. Live arena/BG/world-PvP confirmation is required.

## Training dummies

Version 1.4.9 recognizes city training dummies through Project Sylvanas's
native unit helper. A selected world-PvE dummy is treated as engaged, so the
rotation can begin before normal threat or combat starts. This exception never
applies to players, PvP profiles, or ordinary idle NPCs. Dummy sessions are
marked in diagnostic heartbeats. Select the desired single-target or grouped
dummy and leave Safe Area Damage enabled when testing cleave.

## Installed folder naming

Every live Project Sylvanas release is installed under a versioned folder named
`sylvanas_hunter_v<version>`, for example `sylvanas_hunter_v1.4.9`. An update
replaces the previous versioned Hunter folder so only one Hunter copy can load.

Version 1.4.10 polls F1 from both normal update ticks and window frames. Pressing
F1 toggles the themed GUI while visible or hidden; holding the key toggles once.
It does not change combat enable, profile enable, burst, or pause state.

Version 1.4.11 adds a dedicated 440x142 dungeon boss-helper card. It appears
only for a detected PvE boss while the DPS boss helper is enabled, automatically
uses the active BM/MM/Survival colors and icon atlas, and shows the boss, action,
timer, wrapped guidance and detected activity. It hides in PvP and between bosses.

Version 1.4.13 keeps the Hide button on the separate boss-helper card and assigns
F7 as its show/hide toggle. Edge detection prevents repeated toggles while F7 is
held. F7 can restore the helper after its Hide button is used and does not alter
the main F1 GUI, boss-guide setting, combat state, or rotation settings.

Version 1.4.14 keeps the separate helper visible in PvE between encounters with
a `BOSS HELPER READY` card, so its position and F7/Hide controls can be verified
before a pull. A detected boss replaces the waiting card automatically. Native
boss-window render failures are now written to the persistent diagnostic log.

Version 1.4.16 allows the separate helper to remain visible in any detected
Hunter mode when opened with F7. Hide/F7 can dismiss it between encounters, and
the next newly detected PvE boss automatically reopens it with live guidance.
The active card separates tank placement from the Hunter's safe position.
Source-backed move-in, move-out, flank, edge, and cover cues render as world
arrows or rings. Relative arrows use live player and boss positions; landmark
mechanics stay as text/ring cues until a real landmark is detectable.

Version 1.4.32 makes city-dummy testing representative when the game reports a
dummy at nearly zero health. The raw health remains in the persistent log, but
dummy snapshots no longer enter permanent execute range or fail cooldown gates
because of synthetic time-to-die. A real Deathblow proc still enables Kill Shot.

Version 1.4.33 improves BM's Bestial Wrath opener. When the pet is not confirmed
on the current target, the rotation first uses an available Kill Command or
Barbed Shot to commit it. A recent setup attack immediately unlocks Wrath, and
the rotation never holds Wrath when neither setup action can be used.

Version 1.4.34 tightens all-spec PvP decisions. Automatic Arena burst now waits
for confirmed healer control or a recorded healer-trinket window, except for a
target already at 35% health or lower. Master's Call also removes positively
confirmed heavy PvP slows. Dead pets can be revived in PvP only while health is
at least 80% and no engaged enemy is confirmed to be targeting the Hunter.

Version 1.4.35 makes confirmed action history target-aware. BM no longer treats
a recent Kill Command or Barbed Shot against the previous enemy as proof that
the pet has committed to a newly selected target. It recommits the pet before
Bestial Wrath when possible, while retaining the existing no-stall fallback.

Version 1.4.36 adds an enabled-by-default PvP world-line overlay for every spec.
The current hostile target uses the active spec color. The nearest confirmed
enemy healer uses cyan while visible and red when line of sight is lost. Arena
uses opponent specialization data; battleground and world PvP use exposed spec
or healer-role data. The overlay is a render layer and does not add a third GUI.

Version 1.4.37 adds three enabled-by-default Arena reactions for every spec.
Feign Death answers a confirmed imminent, dangerous cast after an available
interrupt has been considered. Roar of Sacrifice answers two-attacker pressure
at 70% health or lower only while the pet remains above 40%. Master's Call can
free a positively confirmed rooted Arena healer as well as the Hunter.

Version 1.4.38 adds the missing healer stun-to-Trap Arena chain. A moving clean
healer in an authorized kill window is stunned only when both stun and
incapacitate DR are usable and neither category is immune. The next confirmed
snapshot recognizes the Hunter's own Intimidation as a safe bridge into
Freezing Trap while still rejecting DoTs, foreign debuffs, immunity, pet
pressure, teammate pressure, and exhausted DR.

Version 1.4.39 adds teammate-aware Arena defense. Roar of Sacrifice can protect
the lowest-health partner under confirmed two-attacker pressure, while keeping
the existing self-protection and pet-health safeguards. Marksmanship correctly
uses its modern petless Roar; BM and Survival still require a living pet. The
snapshot tracks pressure on party members, and Fittest activates earlier when
the Hunter is damaged while the friendly Arena healer is confirmed controlled.


Version 1.4.40 separates Arena healer setup from major cooldown commitment. A
clean, DR-safe stun-to-trap sequence can begin before a burst window exists,
while automatic cooldowns wait for useful remaining healer CC, a tracked
trinket window, or finishing health. Arena-only sliders control the minimum CC
remaining and healer trinket window for every spec. Logs expose these states.

Version 1.4.41 completes the Arena setup-intent path in the utility planner and
adds an end-to-end regression for initiating healer control before burst.

Version 1.4.42 restores Takedown to Survival's sustained Arena priority when a
valid Tip of the Spear state is prepared, instead of restricting it to burst.

Version 1.4.43 aligns the BM Arena opener with its sourced pre-trap ramp:
Black Arrow and available Barbed/Wrath preparation can execute before the
healer control chain, without making the shared MM or Survival planner wait.

Version 1.4.44 adds Survival's sourced pre-control Arena sequence: positively
confirmed Tip preparation can place one Wildfire Bomb before the healer trap,
with a cast-history guard preventing repeated setup Bombs.

Version 1.4.45 repairs a live-observed Intimidation-to-Trap handoff failure.
Our confirmed setup stun now overrides a stale native movement flag, and Arena
heartbeats record the exact remaining Trap safety block for follow-up analysis.

Version 1.4.46 fixes the live-observed always-on Arena burst state. The global
burst switch is now a true master permission; the enabled automatic profile
setting controls actual CC, trinket, and finishing-health cooldown windows.

Version 1.4.47 adds known-talent Chimaeral Sting after a confirmed healer Trap
Version 1.4.48 adds DR-safe emergency Scatter Shot for critical off-target Arena casts. It never spends the healer's Freezing Trap DR, refuses teammates' or pet targets, and protects the breakable Scatter aura from rotation damage.
Version 1.4.49 corrects the Midnight Season 2 BM Cobra Fang spender threshold: three stacks for Pack Leader, four for Dark Ranger on one target, while safe Beast Cleave AoE continues to consume any active stack.
Version 1.4.50 corrects MM Sentinel cooldown timing: Aimed Shot precedes Rapid Fire during Trueshot when no Precise Shots spender is pending, and Moonlight Chakram is held until the final five seconds of Trueshot.
Version 1.4.51 makes Survival Takedown part of sustained PvE as well as PvP. Imminent non-Twin casts first prepare Tip with Kill Command, prepared Takedown no longer waits for a burst flag, and the native-eligible fallback remains available throughout combat.
Version 1.4.52 adds the Dark Ranger-specific MM Precise Shots branch: an available Black Arrow consumes the proc before Explosive Shot, Volley, Rapid Fire or Wailing Arrow, while Sentinel remains on its independent priority.
Version 1.4.53 separates BM's sourced PvP opener from its PvE Dark Ranger talent gate. Arena, battleground and world-PvP Dark Ranger now begin the two-Barbed Bestial Wrath setup even when the pet is already committed.
Version 1.4.54 makes Arena Trap cleanliness precise without guessing: Hunter's Mark, Concussive Shot and Wing Clip are explicitly recognized as non-damaging, while every unknown debuff and known damage/control hazard still blocks Freezing Trap.
Version 1.4.55 hardens Midnight aura visibility. Positive `get_auras` or `get_all_buffs` evidence, alternate native spell-ID fields, duration fields and stack fields are recognized before a stale manager inactive result; fully missing data remains unknown.
ends. The Arena-only option is enabled by default and includes active-Trap,
same-healer, timing, duplicate-cast, and hidden-aura safeguards.
