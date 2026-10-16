SYLVANAS WARRIOR — ARMS / FURY / PROTECTION
Version 0.9.54 — Protection Colossus fallback and capital-city dummy support

This release lets Protection Warriors with Morale Killer answer verified nearby\r\nenemy burst against a party member with Demoralizing Shout. Ally pressure stays\r\nseparate from personal burst, so it cannot spend Shield Wall or cross into PvE.
It retains the two-window design: the F1 main interface and F7 compact boss guide.

WHAT THIS PLUGIN DOES
Warrior combat only. Separate Arms, Fury, and Protection modules cover World
PvE, Delves, Dungeons, Mythic+, Raids, Arena, Battlegrounds, and World PvP.
Every specialization/activity pair has independent settings: 24 profiles.

Protection Colossus builds use Demolish when it is learned and fall back to
Colossus Smash when Demolish is unavailable. In PvE, the signature attack runs
on cooldown after mitigation even when the generic burst window is being held;
the cooldown master switch still disables it. PvP retains its separate pooled
Colossal Might timing.

Training mode first uses Project Sylvanas' native dummy detector, then stable
capital-city NPC identities and common dummy/practice/combat-target names. This
covers modern and legacy major-city training areas without allowing players or
ordinary similarly named NPCs to enter the practice rotation.
Numeric settings use the same limits in both interfaces. The Arena trinket
window supports its complete 0–120 second range, while Protection's Shield
Block refresh remains constrained to 0–10 seconds.

Arms and Fury PvP profiles include an enabled-by-default PvP target/healer line
option. It works in Arena, battlegrounds, and World PvP. Protection and every
PvE profile remain excluded.

The F1 command window now uses a clean full-width layout with Core, Abilities,
Utility, Defense, Players, Dungeons, Visuals, and Diagnostics tabs. Its activity
sidebar can edit all eight modes from every tab. Every actionable ON/OFF option
has a separately saved hotkey and visible ON/OFF button. Numeric thresholds keep
their +/- value controls. F1 and F7 remain reserved for the main and boss-helper
windows. The window is created once and hidden or shown in place to avoid
frame-by-frame window recreation and flicker.

Both interfaces hide controls that cannot operate in the selected activity.
Arena peel, healer control, and trinket tracking appear only for Arena;
Mythic+ multi-stops and pack-size cooldown rules appear only for Mythic+;
automatic PvP burst appears only in PvP profiles; and Taunt recovery appears
only for Protection PvE profiles where automatic Taunt is permitted.
It does not add another class rotation, leveling, gathering, or BG navigation.
Your existing movement and activity plugins can continue handling those tasks.

CLIENT SUPPORT
Targets the Midnight client, using the API definitions supplied with your
wowxe loader and current SimulationCraft warrior priorities researched on
October 8, 2026. This is not a Classic/Forever/TBC/MoP rotation. Unsupported
clients, other classes, unknown specs, and conflicting identity readings stop
the plugin. The actual in-game character, talent loadout, equipment, and exact
live patch were not available for validation.
An unavailable player or specialization during login is treated as temporary:
the runtime registers once and waits for a readable Warrior. A definitively
known non-Warrior or unsupported client is still rejected by the loader header.
Exceptions from login-time version or local-player reads are also treated as
temporary and cannot abort header evaluation.

INSTALL
Place the sylvanas_warrior folder under your loader's scripts folder. Keep
header.lua, main.lua, and all ww_*.lua modules together. Reload the loader's
Lua scripts. The warrior menu loads only for a supported warrior character.
Requires the loader's existing Core and Common components. No other class
plugin is required, and no other class's settings are read or modified.

FIRST USE
1. Open the "Warrior: Arms / Fury / Protection" menu.
2. The plugin and every actionable feature begin enabled. Turn off only the
   features you do not want. Pause begins off because turning it on stops casts.
3. Hover the main toggles to read the current status and recommended action.
4. Review recommendations for your current specialization and activity.
5. Open ACTIVITY and press COPY SAVED LOG to place a paste-ready diagnostic
   report on the clipboard. COPY LOG PATHS identifies both persistent files.

The global Pause toggle immediately holds all warrior actions. Manual spell
input briefly takes priority. Charge and Champion's Leap movement begin enabled.
PvP major offensive cooldowns still require the burst window and exact activity
conditions even though their controls begin enabled.
Arena burst behavior never changes World PvE or dungeon settings.

The custom GUI Activity page includes every global Project Sylvanas warrior
control: Plugin Enabled, Pause All Actions, Show Custom GUI, Allow PvP Burst,
Record Diagnostics, Route Overlay, and Boss Guide. Its Rotation, Defense, and
Utility pages expose every valid option for the selected specialization and
activity. Invalid class, specialization, and activity controls remain hidden
and are also rejected by runtime guards. Version-2 setting keys intentionally
apply these new enabled defaults instead of inheriting earlier disabled values.
The offline harness now creates and renders the actual custom window. It verifies
F1 close/reopen edges, held-key debounce, visibility changes, and reuse of one
native window instance so repeated frames cannot recreate or flicker the GUI.

Protection dungeon route progress is stored in
scripts_data/sylvanas_warrior/route_progress.txt. A reconnect to the same
dungeon restores the active pull. Reset Route clears the saved position.
Completed pack members remain credited if their world objects despawn before
the last enemy in that pull dies.
The saved key includes the character GUID and dungeon context, so a second
Protection Warrior cannot inherit the first character's active pull.

AUTOMATIC SPEC, ROLE, AND ACTIVITY DETECTION
"Auto roll" is implemented as role detection. Both global specialization IDs
(71/72/73) and legacy class-local indices (1/2/3) are validated. Arms and Fury
remain damage specs; Protection remains the tank spec. A group-assigned role
is displayed separately and cannot choose a different specialization's logic.
A role mismatch disables automatic Taunt. It does not disable self-defense.
PvP instance identity takes precedence. Delves use the loader's delve API.
An enemy player target selects World PvP outdoors; an NPC target selects World
PvE. War Mode alone does not turn NPC combat into a PvP rotation. Loading or
unknown instance data holds combat rather than guessing an activity.

STATE ISOLATION AND CAST HANDLING
The engine resets queued requests, retry state, health trends, threat recovery,
and cast history when character/spec/activity/assigned-role changes. Native
talent, equipment, group, and combat-end events also reset combat state. Each
action carries the exact context and generation that produced it. Immediately
before input, the engine checks character, specialization, assigned role, and
activity again. A registered spell allowlist rejects foreign-spec abilities,
even if the spellbook incorrectly marks them known.

Target-centered ground cooldowns retain the target identity that produced their
decision. If the selected target changes before input, Ravager, Champion's Spear,
and Champion's Leap are cancelled instead of landing at a stale position.

Accepted input requests are logged separately from observed/succeeded casts.
Only one request is pending at a time. Failed inputs and missing confirmations
use bounded backoff. Charges, overrides, usability, cooldowns, global cooldown,
range, facing, line of sight, target validity, and engagement are checked.
Health and cast timestamps use the appropriate seconds/milliseconds clock.
Both supported UNIT_SPELLCAST payload layouts are accepted, so success and
failure events can identify the spell from field 3 or field 4 without causing
a false confirmation timeout.

COMBAT BEHAVIOR
Arms: Mortal Strike pressure, Execute/Sudden Death, Rend, Overpower, safe cleave,
armor-break windows, and Colossus/Slayer priorities when supported by the actual
spellbook and positively observed procs.
Fury: Enrage/Rampage priorities, safe cleave setup, confirmed empowered attacks,
Recklessness windows, Slayer and Mountain Thane branches, Thunder Blast procs.
Protection: physical Shield Block priority, Ignore Pain with a rage reserve,
major survival cooldowns, Shield Slam generation, free/excess-rage Revenge,
safe Thane/Colossus attacks, and PvE threat recovery with damage follow-through.

Shared utility includes Pummel, DR/immunity-aware Storm Bolt, Spell Reflection
for imminent targeted magic casts, fear/charm recovery, victory healing,
Rallying Cry, and PvP slows/disarm when supported by reliable helper data.
Healing/resource pressure uses health trends and optional native incoming-damage
prediction. Area attacks check nearby idle enemies and breakable crowd control,
including the radius around a ground/cleave target. Cleave buffs also gate
otherwise single-target attacks. Unknown aura data does not invent a proc.
Automatic Taunt is explicitly blocked in raids; no tank-swap strategy is assumed.

MYTHIC+ AND ARENA INTELLIGENCE
Mythic+ casts are ranked from their observed spell name and target. Heals, mass
damage, control, summons, and empowerment casts are stopped earlier. Two nearby
critical casts can trigger a safe Shockwave stop. Major damage cooldowns wait on
small, dying trash pulls and remain available for bosses, durable enemies, and
larger packs. These thresholds are independent for each warrior specialization.
When BigWigs or ExBoss is available, imminent emphasized or dangerous countdowns
can pre-arm mitigation. Protection uses Disrupting Shout before Shockwave for
overlapping critical casts. Wrecking Throw handles substantial absorb shields
when learned. Predictable group hits can trigger Rallying Cry when allies are
already strained.
Automatic stance management establishes Battle Stance for Arms and Protection
and prefers Berserker Stance for Fury when learned. Fury falls back to Battle
Stance when its current talent loadout does not know Berserker Stance. All three can enter Defensive Stance under
confirmed pressure. After sustained safety, Fury returns to Berserker Stance;
the other specs return to Battle Stance. Confirmed hidden stance state prevents
repeated requests when the client does not expose the aura.
Executioner's Precision is read only from the warrior's own buff state; target
debuff data cannot create a false two-stack Mortal Strike decision.
Outside combat, preparation establishes the learned specialization stance before
refreshing Battle Shout. Encounter-timer defensives consume BigWigs or ExBoss
bars only in delves, dungeons, Mythic+, and raids; World PvE and all PvP modes
ignore stale or unrelated timer bars.
The current Season 2 interrupt table adds exact English-client priorities for
verified critical casts, backed by generic cast-name and cast-target scoring.

Arena discovery explicitly includes arena frames and identifies healer specs.
Intervene can peel a focused low-health ally during confirmed enemy pressure.
Automatic burst waits for either a vulnerable target, a controlled healer, or
an observed enemy-healer trinket window. The global Allow PvP Burst switch is a
permission gate and does not itself force a kill window. Arms can use Ignore Pain under real
pressure. Fury and Protection do not inherit the Arms rotation or its priorities.
Observed enemy trinkets are remembered for the active Arena context. A healer
without a trinket can open an automatic burst window. Disarm and peel selection
scan engaged opponents instead of assuming the current target is the threat.
During a confirmed kill window, Storm Bolt can control a DR-eligible enemy healer.
An immune healer is distinct from a controlled healer and closes automatic burst
until the immunity ends; explicit internal manual requests remain deliberate overrides.
See IMPROVEMENTS.md for the completed checklist.

The Arms/Fury boss coach considers the live boss cast and every available
BigWigs, ExBoss, DBM, or DeadlyBossMods timer, then selects the nearest recognized
mechanic. Unrelated first bars cannot hide a later matching timer. A short
verified-mechanic hold bridges transient cast/bar disappearance without leaving
a stale prompt active after its bounded expiry.

COEXISTENCE
The plugin does not replace foreign callbacks, menus, globals, or spell queues.
It does not turn other plugins on or off. Do not enable a second warrior combat
rotation at the same time: independent plugins cannot guarantee mutual exclusion
without cooperating. Your class-guarded paladin/druid/shaman/rogue plugins retain
their own guards. The existing navigation plugins retain their own decisions.

Read-only diagnostics are exposed through _G.SylvanasWarrior.status() and
_G.SylvanasWarrior.diagnostics(). An optional companion hook named
_G.SylvanasWarriorCombatHold(context) can return true to hold this rotation.
Its context contains the current warrior spec ID, activity, and derived role.
There is no existing-provider assumption; the hook does nothing unless supplied.
_G.SylvanasWarrior.snapshot() returns a read-only compact combat snapshot for
live validation, including prioritized casts and encounter or Arena state.

LOGS AND VALIDATION
Warrior diagnostics: scripts_log/sylvanas_warrior/session.log.
Crash-safe copy: scripts_data/sylvanas_warrior/session_copy.txt.
The logger appends important events and one-second combat snapshots immediately.
It also saves every visible hold/decision transition and player cast observed by
the loader, including manually initiated casts, so missing-action reports retain
the reason shown in the GUI at the time.
The data copy is rewritten with a bounded history, so it remains easy to copy
and paste after a crash or disconnect. An active session marker lets the next
load record that the prior session ended unexpectedly. Keep Record Diagnostics
enabled in the GUI when gathering a report.
Each decision/request/result includes its specialization, activity, and role.
In-memory diagnostics, persistent history, and write queues are bounded.
See TEST_REPORT.md for the exact offline result and RESEARCH.md for sources.
Tests use Python with lupa (Lua 5.4): python tools/run_warrior_tests.py.

REMAINING LIVE VALIDATION
This release is not proven flawless. Confirm loader module resolution, menu
rendering, actual talent/spell overrides, hidden aura behavior, cast callbacks,
latency, facing/range checks, and survival/rotation behavior on your character.
Exercise spec switches and all intended activities on a safe target before competitive use.
PvP strategy, encounter-specific tank swaps/reflectability, movement paths,
trinket optimization, and raid-wide coordination need their own live evidence.

0.5.0 DUNGEON AND GUI ADDITIONS
- Protection route overlay uses the Guardian/Protection route datasets and supports automatic pull progression plus manual previous, next, and reset controls.
- Protection boss guidance is role-isolated and reacts to supported boss casts and boss-mod timers.
- Arms and Fury use a separate melee-DPS boss coach derived from the Rogue and Retribution guidance patterns.
- Its displayed instructions are rewritten for Warrior utility and defensives;
  inherited Feint, Vanish, and other foreign-class ability prompts are rejected.
- The GUI automatically switches among Arms, Fury, and Protection settings without sharing rotation controls between specs or activities.
- Each spec has a custom procedural theme: Arms blade/crimson steel, Fury twin weapons/embers, and Protection shield/fortress.
- All artwork, buttons, route lines, and boss indicators are rendered from Lua geometry. The plugin contains no PNG, JPG, or JPEG assets.

TRAINING DUMMY TESTING
Training dummy testing is enabled by default. Target an attackable city training dummy while unmounted and the active Arms, Fury, or Protection World PvE profile can begin before combat. Native dummy detection is preferred, with a non-player Training Dummy name fallback. Nearby confirmed dummies may count for cleave testing; nearby non-dummy or protected targets continue to block unsafe area attacks. Disable TRAINING DUMMIES in Activity controls to require normal combat engagement.


COMPACT DUNGEON BOSS HELPER
A separate 430x164 draggable boss-helper window appears automatically in Dungeon and Mythic+ while Boss Guide is enabled. It follows the detected specialization: crimson Arms DPS, orange Fury DPS, or blue Protection Tank. The window shows the current mechanic action, role-specific prompt, live countdown when available, and monitoring state. It stays hidden in PvP, raids, delves, and outdoor content and does not depend on the large F1 settings window being open.


BOSS HELPER VISIBILITY
The compact dungeon boss helper has its own HIDE button. Press F7 at any time to show or hide that window; one key press changes state once, so holding F7 does not flicker. This does not change the visibility of the main F1 settings GUI.


BOSS HELPER VISIBILITY RECOVERY
The compact helper now renders a monitoring preview whenever a supported Warrior specialization is detected and Boss Guide is enabled, including outside a dungeon. Dungeon and Mythic+ mechanics remain the only source of live dungeon guidance. Its initial position is calculated from the current screen size and clamped fully on-screen. If window rendering fails, the diagnostic log records boss_hud_error. Project Sylvanas must reload scripts or restart after replacing a versioned plugin folder.

