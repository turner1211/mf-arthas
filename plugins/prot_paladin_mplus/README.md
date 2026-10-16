# Protection Paladin Mythic+ 12.1

Version 6.13.67. Project Sylvanas plugin based on the installed Ret Paladin 12.1 conventions and current Method/Icy Veins Protection Paladin priorities.

### 6.13.67 major-city practice dummies

- Expands stable NPC-ID recognition across the shared classic capitals, Stormshield/Lunarfall, Legion class halls, Boralus/Dazar'alor, Oribos and covenant sanctums, Valdrakken, Dornogal, and Midnight Silvermoon.
- Adds Silvermoon 12.1 damage, cleave, normal-tank, dungeoneer-tank, raider, and PvP damage dummy families.
- Keeps localized clients reliable through NPC IDs and extends the English fallback to practice, combat, drill, tank, and sparring dummy names.
- Friendly healing targets still cannot start the damage rotation because training mode requires the selected unit to be attackable.
- Regression coverage exercises representative dummy IDs from every major capital generation while confirming encounter defensives, taunts, and utility remain suppressed during damage practice.

### 6.13.66 Customer GUI and hotkeys

- Reorganizes Paladin Vanguard into eleven focused pages: Dashboard, Rotation, Defense, Threat, M+ Route, Boss Guide, Support, Automation, Hotkeys, Tuning, and System.
- Every customer-facing feature row now has a distinct ON/OFF control plus an optional saved hotkey selector.
- Hotkeys use edge-triggered polling, reserve F1 for the main GUI and F7 for the boss helper, and automatically clear duplicate assignments.
- Adds a global hotkey switch, a safe starter layout, and one-click clearing without adding another window or another update callback.
- Enlarges and spaces the panel for cleaner navigation while preserving the left-side Icecrown tank artwork and two-window limit.

### 6.13.65 Frame-time optimization

- Reuses one host object snapshot across all combat targeting, interrupt, crowd-control, and proximity passes in each update instead of requesting the full object list up to six times.
- Prediction now shares one object snapshot between hostile-cast and nearby-pack analysis.
- Consolidates five gathering update callbacks into one ordered dispatcher, reducing protected callback overhead without changing loot or profession ownership.
- Batches crash-recovery persistence every five seconds while preserving immediate error and logout writes, avoiding full-snapshot disk writes every second.
- Replaces repeated front-of-array log trimming with one linear compaction pass and caps background world labels while always preserving the active pull.
- Adds a regression that fails if combat targeting performs more than one host enumeration per update.

### 6.13.64 Combat-safe aura maintenance

- Devotion Aura is now restored during out-of-combat preparation instead of competing with mitigation and emergency healing after combat begins.
- Adds a regression proving a missing aura cannot delay Lay on Hands at critical health.

### 6.13.63 Manual-input tank safety

- Manual spell input now pauses ordinary automated damage while leaving Shield of the Righteous, emergency defensives, interrupts, taunts, and emergency party support responsive.
- Removes the former 0.6-second tanking blind spot after a manual cast while preserving player control over ordinary rotation input.

### 6.13.62 Kindo'jan failure-aware boss guidance

- Detects Kindo'jan through the live NPC ID `266600` and tracks Disgraceful Display through aura `1303494`.
- Shows the player's live 0/3 failure count, escalating the warning when the next failed display is fatal.
- Adds a compact phase guide for puddles, Crushing Blow, the Juggernaut, and all four intermission tests.
- Does not invent countdowns: current LittleWigs 12.1.21 exposes the encounter and aura data but no boss timer bars.

### 6.13.61 Patch 12.1.5 Labyrinth support

- Treats the new Labyrinth of Kindo'jan as Delve-style content even if the host's Delve flag has not yet been updated for the new scenario.
- Uses the stable zone ID 16913 plus an instance-name fallback, preserving companion threat recovery, incoming-pressure prediction, emergency companion support, and Delve survival healing.
- Pauses M+ route guidance inside the Labyrinth and labels the mode correctly instead of reporting an unsupported dungeon.
- Adds regression coverage for both the English instance name and localized-client zone-ID path.

### 6.13.60 localized boss-guide coverage

- Added stable IDs for all eight boss-guide mechanics that previously depended on English cast names.
- Added a regression that requires every Season 2 boss-guide rule to retain at least one stable spell ID.
- Cross-checked the new IDs against current DBM dungeon modules, Keystone.Guru combat observations, and Wowhead spell records.

### 6.13.59 owned telemetry and strict specialization gate

- Cast telemetry now records only casts whose caster GUID matches the local Protection Paladin; nearby party and world casts no longer contaminate rotation metrics.
- A failed specialization-enum conversion now leaves the combat runtime inactive unless the raw specialization value independently proves Protection.
- Added regression coverage for same-session party casts and unavailable specialization conversion helpers.
- Structured host errors now preserve message, code, reason, status, and kind fields in persistent logs instead of an unreadable Lua table address.
- Incoming-damage prediction now recognizes healer and party targets through roster GUIDs when unit objects do not implement `is_party_member`, matching threat-recovery behavior.

### 6.13.58 partial-pull endgame accuracy

- Reverified all eight route data files against Mythic Dungeon Tools release 6.3.6.
- Endgame pack selection now subtracts confirmed deaths from each visible pull instead of valuing a partially defeated pack at its original full forces.
- The active-pull force display and projected overcount now use the same verified remaining-force calculation.

### 6.13.57 M+ route integrity audit

- Reverified all eight dungeon challenge IDs, required totals, and 219 route NPC force values against current Mythic Dungeon Tools source.
- Runtime validation now detects missing or conflicting pack metadata, challenge IDs, required/planned totals, mapping versions, and physical pull counts.
- Invalid route data stays visibly flagged in the route status instead of silently guiding from inconsistent tables.
- Temple of Sethraliss now includes the omitted two-Sand-crusted-Striker pack, bringing the route from 675 to 689 forces against a 687 requirement.

### 6.13.56 actionable live-run telemetry

- The independent Protection logger now records deduplicated `GUIDANCE_CHANGE` entries for boss instructions, danger state, and route decisions.
- Route transitions include pull, risk, off-route count, and the selected recovery target, allowing threat-line changes and accidental-pull behavior to be reconstructed after a run.
- State snapshots include the current recovery target and a guidance-change counter alongside mitigation, interrupt, defensive, healing, and threat metrics.
- Transition data uses the existing alternating persistent snapshots, so it survives crashes and can be exported after the next login.

### 6.13.55 adaptive guidance commitment

- A held danger escape is revalidated on every scan and is revoked immediately if a newly detected hazard blocks its corridor.
- Accidental-pull recovery commits briefly to the selected enemy, preventing equal-priority healer threats and casters from making the red line jump every scan.
- A materially higher-priority or unreachable target bypasses that commitment immediately, preserving fast recovery when the threat situation changes.
- The retained live Protection log was reviewed; its newest session was v6.13.43 and ended cleanly, so this release avoids unsupported rotation tuning until a current gameplay session is captured.

### 6.13.54 verified recovery and encounter isolation

- Threat recovery deprioritizes enemies that fail the host line-of-sight check, preventing a red recovery arrow from pointing through terrain when a reachable caster is available.
- Danger guidance explicitly reports `no verified clear path` and withholds its movement arrow rather than suggesting an unverified escape.
- Active and upcoming boss mechanics are both invalidated on dungeon-context changes, preventing stale instructions after teleports or instance transitions.
- Timer-only mechanics reacquire a current valid boss frame after a context reset so stack, interrupt, and priority guidance lines still render correctly.

### 6.13.53 path-safe escapes and recovery priority

- Danger guidance now checks intermediate points along each escape line, allowing the initial exit from the current hazard while rejecting a route that enters a second hazard.
- Accidental-pull recovery prioritizes enemies attacking the healer, then active casters, then distance, so the red recovery line points at the highest-risk loose target.
- Cached upcoming boss mechanics are bound to the detected dungeon context and are cleared immediately if the instance changes.
- All new host object calls are protected so incomplete or transient unit data cannot silence the router.

### 6.13.52 stable live guidance

- Danger-zone escape arrows now hold a verified safe direction briefly instead of rotating between equally safe samples every scan.
- Upcoming boss instructions survive short BigWigs, LittleWigs, ExBoss, or DBM timer dropouts and continue counting down from their last verified deadline.
- Accidental-pull recovery remains active through a brief clear scan, preventing the route line from flickering back while threat and object data settle.
- Normal route guidance resumes automatically once the recovery state remains clear.

### 6.13.51 mechanic-chain defense and accidental-pull recovery

- Defensive prediction now detects multiple damaging boss timers landing in the same forecast window and escalates coverage for the complete mechanic chain.
- Consecutive danger is exposed with its follow-up deadline so later defensive selection can distinguish one hit from a rapid combo.
- Accidental off-route pulls now take priority even when the planned pack is unloaded, replacing SEARCH with RECOVER immediately.
- World guidance suppresses the normal travel arrow during recovery, draws a red line to the nearest loose enemy, and marks every engaged off-route enemy for threat recovery.

### 6.13.50 predictive guidance and stable routing

- Boss mechanics that overlap now use action priority, so an imminent tank defensive or interrupt is not hidden by a lower-risk stack or spread timer.
- The boss helper prepares the next mechanic with its instruction and position before the urgent action window opens.
- Danger guidance evaluates all verified safe samples and chooses the escape direction with the best hazard clearance while limiting unnecessary travel.
- The M+ Auto Dungeon briefly commits to its selected visible pack, preventing patrol movement and nearby lookalike packs from making the route arrow flicker.

### 6.13.49 exactly two GUIs

- Removed the separate route overview screen panel and its controls.
- The only remaining windows are Paladin Vanguard (F1) and the compact Dungeon Boss Helper (F7).
- M+ route status remains inside Paladin Vanguard, while lightweight world-space lines, labels, and pull markers continue to guide the tank.

### 6.13.48 readable guide and unobstructed character

- Rebuilt the boss helper as a larger multi-line guide so immediate instructions, all three role steps, positioning, encounter context, and the upcoming mechanic are readable without truncation.
- Added an 18-second boss-timer preview while preserving the urgent action window for mechanics within 5.5 seconds.
- Removed every boss-guide and danger-zone circle centered on the player. Danger now uses an elevated status label and a green escape line, with at most six faint hazard samples away from the character.
- Reduced world-route, boss, hazard, and per-enemy marker opacity and size. The tank staging marker remains visible without layering a circle over the character when already close to the pull.

### 6.13.47 location-aware Protection pull planning

- The M+ Auto Dungeon now infers the current route segment from the nearest confidently identified live pack and advances only after a stable location match.
- Reloading or joining partway through a dungeon no longer blindly sends the tank toward the earliest visible pull. The route cursor avoids guiding backward and still honors manual Previous, Skip, and Reset controls.
- The next-pull overlay now draws a Protection tank staging marker before the pack, labels it `TANK PULL FROM HERE`, and separates the approach line from the final engage line.
- The Vanguard status card shows detected route location, planned pull, and live completed/required forces.

### 6.13.46 encounter guide and positioning

- Expanded the helper into a structured encounter guide with mechanic name, live countdown, immediate instruction, three role-specific steps, positioning guidance, and persistent between-mechanic preparation.
- Added mechanic-specific tank positioning for the Season 2 dungeon pool, including wall rotations, boss/add cleave placement, edge drops, shield returns, gateway staging, safe wind placement, star positioning, and frontal direction.
- World rings and arrows continue to show stack, pickup, priority, kite, movement, and facing directions without requiring an external overlay asset.
- Role fallback now recognizes every tank and healer specialization instead of treating an unknown role as a tank.

### 6.13.45 transparent boss auras

- Reduced red, green, and warning world-circle opacity so the player model and encounter floor effects remain visible during boss fights.
- Circle geometry, state colors, guide lines, and mechanic timing remain unchanged.

### 6.13.44 clean cross-class telemetry

- The retained logs showed that the universal boss helper caused the Protection Paladin logger to start on other classes and retain unrelated spell casts.
- Combat logging now starts lazily only after a Protection Paladin is detected. The universal boss helper still loads, auto-detects encounters, and remains available with F7 on every class.
- Non-Paladin logout and helper rendering events no longer alter the Protection Paladin session history or its crash-recovery marker.

### 6.13.43 universal automatic boss helper

- The compact boss helper loads on every class and specialization while the rotation and large Paladin Vanguard GUI remain Protection-only.
- F7 can show the helper at any time, and a separate setting automatically opens it when combat begins with a valid boss frame.
- HIDE or F7 suppresses the helper for the current encounter; a later boss encounter may auto-open it again.
- Helper visibility uses an ungated persistent setting, and its default position is kept inside smaller displays.

### 6.13.42 boss-helper F7 toggle

- The compact boss helper uses **F7** for show/hide and retains its visible **HIDE** button.

### 6.13.41 boss-helper hotkey correction

- The compact boss helper now uses **F6** for show/hide while retaining its visible **HIDE** button.

### 6.13.40 compact dungeon boss helper

- Adds a separate small boss-mechanic window that remains usable while Paladin Vanguard is hidden.
- Detects the live class, specialization, assigned role, dungeon mechanic and required role job every frame.
- Applies the detected class color and shows the active action, mechanic instruction and monitoring state without opening the full GUI.
- The helper has its own persistent on/off toggle under the boss-guide settings.
- A visible **HIDE** button closes the helper, and **F7** toggles it from anywhere without key-repeat flicker.

### 6.13.39 F1 GUI toggle

- F1 now shows or hides Paladin Vanguard with edge-triggered input, so holding the key cannot rapidly reopen and close the panel.

### 6.13.38 training-dummy rotation mode

- Recognizes known city training, tanking, and target dummies by NPC ID, with an English-name fallback for newly added dummies.
- A selected dummy is treated as an explicitly safe target so the full damage rotation can run even though the dummy never attacks the player.
- Training mode suppresses taunts, interrupts, party utility, predictive defense, emergency heals, and major survival cooldowns so testing does not waste encounter tools or distort damage results.
- The standard menu and Paladin Vanguard Control tab include an independent **Training dummy mode** toggle. The status HUD reports **TRAINING** while active.

### 6.13.37 complete numeric tuning

- The eighth themed tab exposes every numeric tank control with persistent minus/value/plus rows.
- Threat range, forecast window, predicted Ardent/Guardian thresholds, Word of Glory, reactive defensives, Divine Shield, and Lay on Hands can now be tuned without leaving Paladin Vanguard.
- Values are clamped to the same safe ranges as the underlying Sylvanas sliders, including zero-to-disable emergency immunity and Lay on Hands.

### 6.13.36 complete themed controls

- The Paladin Vanguard panel now includes dedicated Support and Control tabs instead of leaving essential settings only in the basic Sylvanas tree menu.
- Support exposes aura, cleanse, Freedom, combat resurrection, party healing, Sacrifice, Delve healing, and emergency paid Word of Glory.
- Control exposes safe target acquisition, tank facing, manual-input yielding, direct interrupts, Hammer of Justice, Blinding Light, taunting, and threat switching.
- GUI regression now opens both tabs and verifies every new control is rendered.

### 6.13.35 official namespace dispatch

- All Sylvanas namespace APIs now use their documented static calling convention first, with an object-method retry only for host variants that require an owner.
- This includes specialization, challenge/keystone, Delve, inventory, loot-window, dismount, and mouse-capture calls.
- The release audit rejects any future method-first call on `core.input`, `core.graphics`, `core.world`, `core.delves`, `core.inventory`, `core.game_ui`, or `core.spell_book`.

### 6.13.34 facing host compatibility

- Automatic tank facing now invokes `look_at_3d` or `look_at` through the protected argument-preserving host adapter.
- Void-returning static functions and object methods are distinguished from failed calls, so successful facing is recorded even when the host returns no value.
- A combat regression reproduces the strict object-method convention and verifies that the destination argument is not shifted.

### 6.13.33 persistent, font-safe GUI

- The panel position is stored in unique Sylvanas menu-state controls and restored after reload.
- Releasing a header drag saves the new location, and the Logs page includes a reset-position action.
- Runtime, route, logger, and mechanic text is converted to a single-line font-safe form so Unicode punctuation or control characters cannot distort or break the custom window.

### 6.13.32 tank-command GUI

- The Vanguard page now shows live Holy Power, Shield of the Righteous duration, Consecration coverage, and predicted incoming-risk cards.
- Risk changes from stable/watch to high/severe/lethal using the same forecast that drives defensive choices, so the panel explains what the automation sees.
- Dragging clamps the panel to the detected screen bounds so the title bar remains recoverable at different resolutions.
- The implementation follows the installed Rogue/Shaman/Paladin window formula and Project Sylvanas custom-window and raw-texture APIs while retaining the Lua/Markdown-only runtime.

### 6.13.31 route-render host compatibility

- Routes now call every map-conversion, screen-size, 2D panel, and 3D world-marker API through the protected host adapter.
- Both strict static-function and object-method Sylvanas host conventions are regression-tested, preventing the route overlay from silently disappearing on API variants.
- The release audit now rejects direct route-render calls that bypass the adapter.

### 6.13.30 Rogue-formula GUI repair

- The Paladin panel now uses the Assassination Rogue GUI's window-position formula for backdrop and icon drawing, so artwork stays attached after moving the window.
- Header dragging now updates the real window position with mouse capture instead of the panel being forced back to `45,45` every frame.
- The five image tabs now use the Rogue four-column grid, placing the fifth tab at the left of row two instead of stranded at the far-right edge.
- Minimum sizing, texture placement, icon placement, and drag bounds now follow the stable Rogue panel implementation while retaining the Icecrown tank theme.

### 6.13.29 argument-safe host calls

- The shared host adapter now preserves static argument order and retries owner-required methods only after an actual static-call failure.
- Combat casts, spell readiness/name/charge queries, target changes, fishing, looting, skinning, gathering, dismounting, and repairs use the argument-safe boundary.
- Integration coverage proves strict static and strict owner-required argument providers return identical results without argument shifting.

### 6.13.28 namespace host compatibility

- Dungeon and keystone detection, Delve detection, repair capability/cost, and loot-window item counts now support both object-method and static host namespaces.
- Route object access now uses the shared host adapter directly instead of maintaining a second private compatibility implementation.
- Routing, prediction, threat, utility, gathering, repairs, and main combat no longer silently lose features when no-argument host functions require their namespace owner.

### 6.13.27 specialization host compatibility

- Main rotation, settings, GUI, and role guidance now resolve Protection specialization through the protected host adapter.
- A host exposing `get_specialization_id` as an owner-required object method can no longer pass the header and then silently disable the runtime.
- Integration coverage executes settings and rotation updates under both strict object-method and strict static spellbook conventions.

### 6.13.26 versioned loader evidence

- Every accepted, deferred, or rejected header class/spec decision now writes its exact plugin version to `header_status.txt`.
- Live acceptance can distinguish a current wrong-class skip from a stale loader status instead of inferring freshness from the file timestamp alone.
- The main audit now enforces versioned loader evidence, protected object-manager boundaries, and the exact 27-file release manifest so these reliability fixes cannot regress silently.

### 6.13.25 complete object-manager compatibility

- Main player lookup, predictive enemy scans, boss-frame guidance, and danger-overlay rendering now use the shared protected host adapter.
- Strict object-method hosts retain combat updates, incoming-damage prediction, boss detection, and world guidance instead of failing each feature independently.
- Integration coverage executes update and render callbacks with strict owner-required player, object, and boss-frame methods.
- `build_release.py` creates the package from an exact 27-file runtime manifest and verifies every archive entry, preventing tests and audit tooling from entering the live plugin package.

### 6.13.24 settings host compatibility

- The settings and GUI class gate now uses the shared protected host adapter. Hosts that expose `get_local_player` as an object method can no longer pass the header gate and then silently disable every rotation toggle and GUI surface.
- Integration coverage now exercises the strict object-method settings path in addition to header, threat, gathering, utility, intelligence, and logger host access.

### 6.13.23 header dependency recovery

- Protects the earliest enum-module import so a transient shared dependency failure cannot silence plugin startup.
- Falls back to canonical Paladin class 2 and Protection specialization 66 while retaining the normal enum path when available.
- Integration validation now injects an enum-loader failure and confirms the header still loads safely.

### 6.13.22 startup class-gate compatibility

- The earliest header player and specialization lookups now support both host calling conventions.
- Object-method player lookup reliably rejects non-Paladins before their GUI and callbacks are loaded.
- Strict static lookup and unavailable-player startup remain supported and covered by integration checks.

### 6.13.21 shared host API recovery

- Adds one protected host adapter for object-method and strict static manager APIs.
- Applies it to gathering, threat, party utility, group intelligence, Delve companion scans, and logger player identity.
- Adds threat regressions proving both host calling conventions preserve healer aggro recovery.

### 6.13.20 route object-manager recovery

- Protects M+ Auto Dungeon player and object enumeration across zoning and reload frames.
- A transient local-player lookup now shows a waiting state while preserving route identity and pull progress.
- Route rendering skips an unavailable player frame without clearing valid navigation state.

### 6.13.19 combat enumeration recovery

- Protects combat object, boss-frame, and party-roster enumeration through the existing runtime state table.
- A transient object-manager failure now degrades optional pack scans to an empty result while current-target mitigation and damage continue.
- Adds a regression proving Judgment still executes when object enumeration throws.

### 6.13.18 boss-mod provider compatibility

- Supports addon adapters that expose BigWigs, LittleWigs, ExBoss, or DBM accessors as object methods.
- Retains a protected no-owner fallback for strict static host functions that reject extra arguments.
- Uses the same compatibility path in prediction, danger warnings, and boss guidance.

### 6.13.17 danger lifecycle and localized timer verification

- Clears the danger scanner throttle with encounter state so a newly started fight can warn on its first update.
- Adds independent regressions for localized LittleWigs timer IDs in both defensive prediction and world danger guidance.

### 6.13.16 spellbook fault recovery

- Boss guidance keeps the numeric cast identity when a transient spell-name lookup fails.
- Localized ID-based instructions and defensive prediction continue instead of losing the update frame.

### 6.13.15 current encounter reconciliation

- Adds stable IDs for current tank attacks and dangerous trash casts across all eight supported dungeons.
- Adds Tail Scythe, Envenom, and Heart Attack tank guidance found in the current LittleWigs encounter modules.
- Corrects current boss-mod names for Call of the Elements and Roaring Firebreath so text-only hosts still match them.

### 6.13.14 localized mechanic identity

- Matches supported boss casts and boss-mod timers by stable LittleWigs spell ID before using localized display text.
- Shares the same ID table across boss guidance, defensive prediction, and danger warnings so all three systems classify an event consistently.
- Keeps name matching as a fallback for host integrations that expose timer text without a spell ID.

### 6.13.13 auto-repair callback recovery

- Merchant events and auto-repair updates now have independent fault boundaries and visible maintenance status on host API failure.
- `MERCHANT_SHOW` reads the clock before mutating state, preventing a partial event from leaving repair automation stuck at an open merchant.
- World exit clears merchant state and repair timing for safe character and instance transitions.
- Regression coverage injects a merchant-event clock failure and verifies callback survival and state recovery.

### 6.13.12 guidance and telemetry callback isolation

- Danger prediction, boss guidance and logger snapshots now run inside a protected post-update boundary separate from combat rotation.
- Boss-frame enumeration fails closed during object-manager refreshes.
- Post-update subsystem errors are persisted through the independent logger with the existing per-scope rate limit.
- Integration coverage injects a danger-update failure and verifies that the callback survives and records the error.

### 6.13.11 unified party-engagement detection

- Main target selection and interrupt scanning now use the same party-roster-aware engagement decision as threat recovery.
- A roster-only victim can no longer be found by the taunt scanner and then discarded by automatic targeting or interrupt logic.
- The main runtime retains a compatibility fallback for minimal or older threat providers that do not expose the shared helper.

### 6.13.10 party-roster threat recovery

- Threat ownership now falls back to party-roster GUID matching when a party unit object does not expose `is_party_member()`.
- Enemies pulled by another party member can be recovered before the tank appears on their threat table.
- Healer-target priority also uses the roster fallback, preserving urgent taunt selection on limited host unit APIs.
- Regression coverage verifies recovery from a zero-threat enemy attacking an opaque healer unit.

### 6.13.9 localized boss and prediction detection

- Added one shared dungeon identity resolver for all eight Season 2 challenge IDs.
- Boss guidance and predictive mechanic classification now prefer stable challenge IDs, so localized instance names no longer disable either system.
- English instance-name matching remains available outside active keystones and as a compatibility fallback.
- Regression coverage verifies both boss guidance and defensive prediction with a deliberately unrecognized localized dungeon name.

### 6.13.8 boss-guide and defensive-prediction parity

- Added the missing predictive classifications for every Season 2 boss ability that the role-aware guide marks as a defensive event.
- Coverage now includes Chaos Barrage, Thorncaller Roar, Grievous Thrash, Thornspike, Serpentine Gust, Tail Thrash, Awakening Slam, Blade Combo, Stormslam, Serpentstorm, Consume Charge, Vile Charge and Tainted Strike.
- A cross-table regression now fails whenever a future boss-guide defensive instruction is absent from predictive defense.

### 6.13.7 always-current combat-log context

- Every incoming combat-log damage event now synchronizes its challenge/map/instance context before training the predictive model, including while the rotation toggle is off.
- Intelligence callbacks now use protected local-player acquisition so transient object-manager refreshes drop one sample safely instead of escaping the event callback.
- Regression coverage verifies callback containment and retains per-dungeon learning isolation under automatic context synchronization.

### 6.13.6 dungeon-aware learning and lifecycle reset

- The combat runtime now synchronizes the intelligence context with the active challenge ID, map or localized instance every update, activating the existing per-dungeon learned-damage model.
- World entry, world exit and player death clear stale cast retries, pending requests, aura history, threat targets, dispel state and party-interrupt holds.
- Learned damage remains preserved and isolated by dungeon context while transient encounter state resets safely.
- Current Method, Icy Veins and Wowhead 12.1 priorities were rechecked against both hero-tree rotations and defensive cadence.

### 6.13.5 render and settings resilience

- GUI, danger-overlay and standard-menu callbacks now contain rendering faults so visual API refreshes cannot interrupt combat logic.
- Contained visual errors are persisted with per-subsystem ten-second throttling to prevent log flooding.
- Character validation and menu widget reads now fail closed when host objects or controls are temporarily unavailable.
- Integration tests inject independent GUI and menu failures and verify that both remain callable and reach the plugin logger.

### 6.13.4 callback fault isolation

- Spell and game-event callbacks now contain subsystem exceptions and write them to the Protection Paladin logger instead of allowing silent callback loss.
- Gathering player acquisition and validity checks now fail closed during transient object-manager refreshes.
- Loot events use the same protected callback boundary as the rest of gathering automation, with recovery coverage that prevents a stale loot-window pause.

### 6.13.3 pre-runtime loader resilience

- Header loading now treats an unavailable or throwing object manager as a normal startup state instead of aborting before the GUI and logger can initialize.
- Header specialization detection now accepts canonical Protection ID 66 when enum helpers are missing or incomplete.
- Loader regression coverage exercises both transient object-manager failure and absent enum metadata before loading the full runtime.

### 6.13.2 class and specialization compatibility

- Protection detection now accepts the canonical specialization ID 66 when Sylvanas enum helpers are absent or still loading.
- Paladin detection now retains its numeric class fallback, so incomplete enum metadata cannot activate the runtime for another class.
- Integration coverage removes both enum tables and verifies the Protection and foreign-class paths without consuming another runtime local.

### 6.13.1 hot-path API resilience

- Unit validation, spell-known, usability, cooldown, and range queries now fail closed when the client API is temporarily unavailable instead of throwing through the update loop.
- Integration coverage injects a live spellbook exception and verifies that it cannot create another per-frame `API error` flood.

### 6.13.0 live-run evidence

- Persistent logs now measure distinct threat losses, confirmed interrupts, Shield of the Righteous gap time, prolonged combat stalls, and active boss-guide/danger instructions.
- Threat events are deduplicated so one loose enemy does not flood the recovered log every frame.
- Shield of the Righteous gap transitions are recorded explicitly, making mitigation failures visible after a crash or reload.
- Local-player lookup also tolerates temporary object-manager exceptions across update, render, menu, spell, and event callbacks.

### 6.12.1 startup player guard

- Update, render, spell, and event callbacks safely remain inactive while Sylvanas has not created the local-player object during startup, zoning, disconnect, or logout.
- Prevents the repeated `main.lua:387 attempt to index local 'player' (a nil value)` error captured in the live log.
- Local-player lookup is protected against temporary object-manager exceptions, and an unavailable specialization now fails closed instead of briefly activating on the wrong Paladin specialization.

Runtime packaging is Lua/Markdown-only. World guidance is drawn by Lua, GUI artwork is embedded inside Lua modules, and validation rejects external image or overlay assets and external image-path references.

### 6.12.0 role-aware Season 2 boss guide

- Covers the boss mechanics in all eight Midnight Season 2 Mythic+ dungeons with live cast and BigWigs/LittleWigs/DBM timer matching.
- Detects the assigned role from the player and falls back to Protection specialization, then labels every active instruction with that role.
- Shows tank-specific defensive, facing, positioning, pickup, interrupt, priority-target, spread, stack, soak, movement, and kite instructions.
- Draws colored world rings and mechanic-dependent lines. Confirmed ground danger remains driven by Evade geometry so the guide never invents a safe coordinate.
- The `Role-aware Season 2 boss guide` toggle controls the feature independently from danger-zone rendering.

### 6.11.0 PvE danger-zone auras

- Draws registered Sylvanas Evade hazards as red world-space circle auras and a green player ring when safely outside them.
- BigWigs, LittleWigs, ExBoss, and compatible DBM damaging/tank timers arm the overlay up to 4.5 seconds before impact.
- Works in PvE, M+, Delves, and dungeons; stopped/paused timers, combat end, death, and world changes clear the overlay.
- Uses confirmed Evade safety data for geometry and never invents a ground location from a boss-timer name.

### 6.10.0 cross-plugin reliability audit

- Ports the Rogue plugin's target-specific cast-failure isolation to tank taunts, interrupts, and hostile utility.
- A failed request against one unreachable or immune enemy no longer suppresses that spell against every other enemy.
- Self-cast failures retain spell-wide exponential backoff, preserving emergency-cooldown protection against repeated rejected requests.

### 6.9.0 absorb-aware prediction

- Incoming heals are reduced by active heal absorbs before they receive forecast credit, preventing false safety during healing-denial mechanics.
- Fully absorbed hostile spells now train learned damage through their documented SPELL_MISSED/ABSORB payload.
- Partial absorbs remain counted once through normal damage events, avoiding inflated predictions.

### 6.8.0 predictive cadence and role metadata

- Learns stable repeating non-melee damage intervals and forecasts the next hit without requiring a boss-mod timer.
- Rejects irregular cadence, stale intervals, melee swings, and predictions supported by fewer than three intervals.
- Uses explicit tank, tankbuster, or defensive metadata from compatible boss-mod bars across localized clients.

### 6.7.0 all-mode predictive learning

- Actual damage learned by spell ID can now drive an upcoming boss-mod timer even when its text is localized or absent from the seasonal mechanic table.
- Learned damage is isolated by challenge ID, map ID, or instance identity across M+, raids, Delves, scenarios, and open-world play.
- Adds compatible DBM timer-provider discovery alongside BigWigs/LittleWigs and ExBoss when the runtime exposes those providers.

### 6.6.0 TrinityCore threat audit

- Uses the client threat status to recognize enemies that are still tanked but insecure, then switches damage to reinforce them before aggro breaks.
- Loose enemies remain higher priority and receive taunt; insecurely tanked enemies receive damage without wasting Hand of Reckoning.
- Preserves the existing post-taunt damage hold, consistent with current server behavior that matches taunt threat to the highest available threat entry.

### 6.5.1 live-log isolation

- Combat snapshots, spell confirmations, retry state, and event telemetry now run only while the local character is a Protection Paladin.
- Logout and world-leave markers still flush the persistent logger cleanly after a character change.
- A regression case verifies that Rogue and other-class callbacks cannot contaminate this plugin's recovered logs.

### 6.5 public-source hardening

- Corrects combat facing only when the client confirms the engaged target is behind the tank.
- Ignores paused, stopped, and inactive BigWigs/LittleWigs bars during defensive prediction.
- Accepts alternate timer fields and deduplicates timers by spell identity and normalized label.
- Persists sampled Shield of the Righteous uptime, Holy Power, casts, interrupts, defensives, heals, failed casts, route decisions, match confidence, and off-route enemies for live-run tuning.

### 6.4 tank and route intelligence

- Safely banks Holy Power with Blessed Hammer while a ready pull remains 12–25 yards away.
- Pre-arms Divine Protection once for a nearby severe or boss pull without consuming Ardent Defender as a routine opener.
- Rotates Sentinel and short defensives, allowing overlap only for severe or lethal forecasts.
- Holds route guidance when the healer is below 70% health or any party member is below 45% health.
- Adds injured-party state to route risk and displays the exact reason the next pull is waiting.

The built-in **Paladin Vanguard** window is a story-themed Protection Paladin control panel with an Icecrown Citadel raid backdrop and illustrated tank/PvE image buttons. The background and icons are embedded in Lua like the Rogue and Shaman panels, so no loose image files are required. It opens by default, can be toggled from the standard Sylvanas menu, and can be shown or hidden with **F1**. Its pages control the rotation, tank logic, M+ Auto Dungeon overlay, gathering and repairs, support, targeting, tuning, and persistent logs. The standard menu remains available if the custom window or artwork API is unavailable.

Features:

- Protection Paladin combat priority, defensives, interrupts, stun backup, taunt, and Devotion Aura.
- Pack-wide interrupt scanning uses Rebuke in melee or Avenger's Shield at range, considers only reachable casters, works when the selected enemy dies, skips boss stuns, and can use Blinding Light when two or more engaged nearby enemies cast together. Nearby unpulled enemies do not affect combat priorities.
- Interrupt selection now weighs known mechanic danger and learned damage before cast completion time, so a critical tank buster outranks a slightly earlier harmless cast.
- Routine casts are interrupted after 55% progress or in their final 350 ms, preserving control for dangerous casts. Critical and learned-danger casts become eligible at 25%, while channels remain immediate.
- Blinding Light waits until nearby casts are imminent, avoiding waste on early casts that the party can still handle normally.
- Interrupt selection chooses the engaged, reachable cast that finishes first instead of automatically favoring the selected target, and rejects confirmed line-of-sight failures.
- Divine Toll and Templar Hammer of Light support, talent-aware Sentinel/Avenging Wrath, Shining Light healing, and separate single-target/AoE priorities.
- Method-based hero-tree priorities: Templar maintains Shake the Heavens; Lightsmith consumes Divine Guidance and manages Sacred Weapon.
- Damage priority manages Judgment charges and its Hammer of Wrath transformation, consumes free Divine Purpose spenders and Shining Light procs for either hero tree, uses Holy Power-safe Divine Toll, consumes Blessed Assurance, and supports Midnight Holy Armaments.
- Lightsmith now separates Sacred Weapon and Holy Bulwark priorities, pre-arms Bulwark before wings, and immediately consumes Glory of the Vanguard with Avenger's Shield.
- Shield of the Righteous applies off-GCD before early returns from healing, taunt, interrupts, or generators. Successful spends update the local Holy Power budget before Divine Toll; Templar reserves a ready Hammer of Light when armor is secure.
- Templar uses Shake the Heavens pandemic timing: Hammer of Light waits while Shake has more than six seconds and the proc has more than four seconds, spends capped Holy Power safely on Shield of the Righteous, then refreshes Shake before either buff or proc expires.
- Valor is consumed through Shield of the Righteous, and the final Glory of the Vanguard talent elevates empowered Avenger's Shields during wings while making Holy Power room first.
- Blessed Word allows free Shining Light healing to build an absorb at full health when procs are capped or a heavy mechanic is imminent.
- Predictive defense takes the stronger of native incoming damage and sampled health-loss momentum, credits current absorbs, excludes friendly healers, recognizes long hostile channels, and resets health history on player/max-health changes or between pulls.
- The available short defensive handles predicted pressure with stricter thresholds for Ardent Defender, Lay on Hands provides configurable emergency recovery, and Shield of the Righteous uses the correct self-cast path so active mitigation fires reliably.
- An independently toggleable emergency paid Word of Glory converts Holy Power into a critical self-heal in any PvE mode only when Shield of the Righteous has at least five seconds remaining and Lay on Hands, Guardian, and Ardent Defender are unavailable.
- Strong Sentinel stacks suppress unnecessary Ardent Defender overlap across predictive and reactive branches. Lethal forecasts or critical health permit Guardian escalation even with Ardent active or during normal defensive spacing.
- Known damaging BigWigs/LittleWigs mechanic bars feed the predictor. Unknown phase, movement, or add-spawn timers do not trigger defensive pressure merely because they are emphasized.
- ExBoss/EXWIND timer bars are merged with BigWigs/LittleWigs and matching bars are deduplicated before defensive pressure is calculated.
- Dungeon-scoped combat-log learning builds a bounded moving damage estimate for hostile spells. A spell begins influencing predictive defense after three observed hits, and learned values never leak between dungeons.
- Route pull size and healer mana feed defensive preparation. Large planned pulls with a low-mana healer trigger earlier short mitigation while offensive cooldowns continue shortening dangerous pulls.
- Party interrupt casts briefly reserve their actual target, preventing same-target Rebuke overlap while automatically retrying after 0.22 seconds if the hostile cast continues.
- An interrupt already inside its action window now resolves before unrelated taunt and target-switch recovery, preventing a fixed-deadline cast from being lost while another enemy is loose.
- Accepted spell requests are tracked until a success or failure outcome. Game-rejected spells receive a bounded exponential retry delay, interrupted player casts receive a three-second lock, and successful casts immediately clear their penalty.
- A failed Rebuke, Avenger's Shield interrupt, or Hammer of Justice quarantines that exact caster/spell pair for 1.5 seconds, allowing the scanner to choose another caster or control method instead of repeatedly failing on the same target.
- Method's Midnight Season 2 dungeon mechanics are classified per dungeon. Live hostile casts and BigWigs/LittleWigs bars recognize tank busters, armor/damage amplifiers, bleeds, and dangerous party hits so the plugin spends stronger defensives on the correct events.
- Ardent Defender is selected when it replaces Divine Protection, charged Guardian casts work during recharge, and free Shining Light healing is consumed before its two-stack cap. Blessed Hammer follows normal generation priority rather than repeatedly displacing damage buttons during pressure.
- Automatic Divine Shield requires Final Stand, no Forbearance, and every enemy currently tanked within the talent's 15-yard taunt coverage. Its HP threshold remains configurable and defaults off.
- Independent green herb-node and yellow mining-node line overlays cover named gatherable nodes within 100 yards, including Midnight 12.1 and The War Within base nodes and their modified variants.
- A node that remains ungathered after 10 seconds of attempts is hidden and skipped for 60 seconds so gathering can continue to another node.
- Gathering and skinning keep separate movement ownership, so disabled skinning cannot cancel node navigation. The node deadline stays with the active target and resets for deliberate combat/fishing pauses.
- Gathering, skinning, and fishing wait for loot slots on later frames. An owned loot request is correlated with a fresh window and bounded time/range; confirmed successful harvests receive a separate cooldown so lingering shared nodes are not treated as failed nodes. Pre-existing loot windows are left to the player.
- Automatic repairs trigger at repair-capable merchants, including a merchant already open when the plugin reloads, using guild repair funds first and personal gold as a fallback.
- Party-wide threat control scans engaged enemies, taunts confirmed aggro losses, and switches targets for damage-based threat recovery when taunt is unavailable.
- Threat recovery prioritizes loose enemies actively casting or channeling at the party, reducing the chance that an urgent caster completes its hit before ordinary damage restores aggro.
- Safe combat-target selection keeps a valid target only when combat or threat evidence confirms it is engaged. Dead, invalid, or unengaged selections are replaced with an engaged enemy, prioritizing healer/party attackers, active casters, and then proximity.
- When no engaged enemy exists, offensive rotation is withheld even if an unrelated hostile is selected, preventing the automation from starting an unintended pull. Delve companion attackers remain eligible.
- Safe target selection rejects confirmed line-of-sight failures. If the graphics API cannot determine visibility, the target remains eligible rather than being discarded on uncertain evidence.
- A confirmed player spell that does not match the plugin's pending-request ledger creates a 0.6-second manual-input yield window. Plugin-originated confirmations clear their request normally without pausing the rotation.
- Positive aura evidence protects nearby Sap, Blind, Gouge, Polymorph, Hex, Repentance, Fear, Freezing Trap, Seduction, Cyclone, and similar breakable control. Controlled enemies are excluded from automatic target selection.
- Optional Consecration, Blessed Hammer, Hammer of the Righteous, Divine Toll, Avenger's Shield, and Blinding Light are held while they could break nearby control. Shield of the Righteous remains available for tank survival, and normal AoE resumes as soon as control ends.
- Hammer of Justice backup is withheld only when the client positively reports stun or crowd-control immunity; unknown immunity state does not discard a usable emergency stop.
- Native Delve detection enables companion-aware combat. Enemies attacking a friendly Delve companion are included in threat recovery and incoming-pack prediction, while unrelated friendly NPCs outside Delves remain excluded.
- Delves show a dedicated companion-aware status and pause M+ Auto Dungeon instead of reporting a missing dungeon route.
- Cleanse Toxins tracks confirmed Poison and Disease aura events, prioritizes the player and healer, ignores dead allies, and remains independently toggleable.
- Safe Intercession prioritizes a dead healer, then other party members, only while the tank is healthy, Shield of the Righteous is secure, Holy Power is available, and the damage forecast is stable.
- A free Shining Light Word of Glory can rescue the most critically injured party member when the tank is healthy and no severe mechanic is forecast; equally injured healers receive priority.
- Blessing of Sacrifice can rescue a critically injured party member or attacked Delve companion only while the tank is at least 80% health, projected to remain above 75%, more than eight seconds from death, under 15% immediate incoming damage, and has at least six seconds of Shield of the Righteous.
- Blessing of Freedom automatically clears confirmed roots and slows from the tank first, then the healer and party.
- In Delves, secure Shield of the Righteous coverage permits a paid emergency Word of Glory below 35% health, and a free Shining Light heal can rescue a companion being attacked.
- Crash-safe persistent logging records one-second combat/route snapshots, accepted and confirmed casts, spell failures, deaths, world transitions, encounters, logout markers, and caught runtime errors.
- Logs use alternating `scripts_data/prot_paladin_mplus/log_snapshot_a.txt` and `log_snapshot_b.txt` snapshots. The previous valid copy remains available if a crash interrupts the newest write.
- The logger is an independent `project_sylvanas.protection_paladin_mplus.logger` entity with its own module, runtime state, menu action, namespace marker, data folder, and log folder. It does not import or share BG Player's debugger or persistent logger.
- Mutable rotation fields and reachability checks are consolidated under one runtime-state entity to avoid Sylvanas Lua's 200-local compiler ceiling. The audit rejects builds above 100 top-level declarations or 120 names in the main update function, preserving substantial startup headroom.
- Critical events and logout flush immediately; routine activity flushes within one second. History is bounded to roughly 900 KB so logging cannot grow without limit.
- On the next load, a recovered session without a logout or world-leave marker is explicitly labelled `RECOVERED_UNCLEAN_SESSION` for faster crash diagnosis.
- **Export recovered logs** writes the restored cross-session history to `scripts_log/prot_paladin_mplus/recovered.log`, ready to open, select, copy, and paste after logging back in. Normal activity also streams to `scripts_log/prot_paladin_mplus/session.log`.
- A successfully taunted enemy remains the recovery target for three seconds, ensuring the rotation adds damage threat before the temporary taunt control expires.
- Taunt recovery now has a 0.75-second minimum damage hold. Once the threat table confirms stable tanking, it releases the target early and immediately scans for another loose enemy instead of waiting the full three seconds.
- Cached threat targets are revalidated before reuse, and loose enemies attacking the healer receive higher recovery priority.
- M+ Auto Dungeon provides addon-free dungeon detection and embedded pull definitions. The existing saved router setting is preserved across this rename.
- On-screen route panel, a direct world line to the next identified pull, pull labels, and aura rings around the next pack.
- Route matching uses precision/recall checks and tight 18-yard horizontal/8-yard vertical clustering so one shared NPC no longer maps an unrelated large pull and adjacent floors or packs are less likely to merge.
- Stable challenge-map IDs identify all eight routes on localized clients, with English-name aliases retained as a non-keystone fallback.
- The route panel shows completed planned forces, total planned forces, and MDT's required forces. Partial packs show loaded versus planned enemies and cannot complete until enough of the planned pack was observed.
- Confirmed deaths inside an unfinished pack now add partial enemy forces immediately. The pack still cannot complete from a partial load, while live forces and least-overcount routing no longer lag behind individual kills.
- Route deviation quarantines earlier unassigned pulls for 45 seconds, preventing an intentionally skipped lookalike pack from being immediately reused.
- Unknown enemies beside a known pack must still match that pull's NPC composition before they inherit its pull identity.
- Keystone.Guru sub-pack signatures distinguish individual physical packs inside combined route pulls, matching the stronger Guardian Druid route selector.
- Previous Pull, Next/Skip Pull, and Reset Route controls allow corrections without immediately reusing GUIDs from a manually skipped pack.
- Player deaths are recorded against the active route pull. Repeated combined-pack failures remain visible on the route panel with a safer split-pull suggestion based on the embedded physical sub-packs.
- The route panel now reports pull distance, Normal/Moderate/High/Severe/Boss risk, group readiness, healer mana, and engaged off-route enemies. Failed pulls raise the next preparation level so short mitigation is available earlier.
- Each visible pull now receives an NPC-composition confidence score. A partial match that remains below 70% for ten seconds is marked stale with a floor/position verification warning instead of silently presenting it as a complete pack.
- Stale low-confidence pulls retain a visible VERIFY marker but suppress their direct navigation line until the match becomes trustworthy again.
- A next pull more than 12 yards above or below the player enters TRANSITION guidance. The panel and world marker show UP or DOWN with the vertical distance, while the misleading direct line through floors is suppressed until the player reaches the correct level.
- The route panel gives a direct READY, WAIT, SPLIT, RECOVER, VERIFY, or DONE decision from group readiness, healer mana, route deviation, pack confidence, and forces progress.
- An engaged planned pack changes the route decision to FIGHT, preventing the panel from suggesting READY or WAIT after the pull has already begun.
- Split-pull combat detection watches the entire assigned pull, including physical sub-packs that are not currently highlighted, so any accidental or intentional engagement switches guidance to FIGHT.
- Group readiness now includes known party positions. A living online member more than 60 yards away changes the next-pull decision to WAIT and appears on the route panel.
- M+ Auto Dungeon reports exact dead and offline member counts alongside distance readiness, making WAIT decisions immediately actionable.
- A living healer who is still casting or channeling between pulls holds the route at WAIT and appears as `healer casting`; active combat still reports FIGHT.
- Healer mana uses a recovery latch: dropping below 20% holds WAIT until mana reaches 30%, preventing rapid READY/WAIT oscillation around the pull threshold.
- The router checks known Divine Protection, Ardent Defender, and Guardian cooldowns, including charges. A complete defensive drought raises pull risk and can automatically split a combined pull.
- Sentinel or Avenging Wrath readiness counts as defensive pull coverage. A severe pull with no short defensive, Guardian, or wings coverage remains at WAIT when it cannot be split safely.
- When required forces remain but no trustworthy planned pack is visible, the router reports SEARCH instead of implying that the route is finished or merely waiting on the group.
- Severe pulls, healer mana below 25%, and large packs at +15 or above automatically narrow guidance to the nearest verified physical sub-pack when route data provides one; the combined pull returns when risk falls.
- Active keystone level scales pre-pull risk, force progress is shown as a percentage, and the panel reports remaining forces or the next pull's projected over-count.
- Once required enemy forces are complete, active route guidance stops instead of directing the group into unnecessary planned trash.
- Engaged enemies that cannot be assigned to a planned pull are tracked by GUID. Confirmed deaths credit their verified NPC force values, while enemies later assigned to a route pull are removed from the off-route ledger to prevent double counting.
- At 80% required forces or higher, the router compares visible pending pulls and guides the smallest pull that can finish enemy forces with the least overcount.
- Endgame routing evaluates combinations of up to twelve visible pending packs. It can choose an exact multi-pack finish instead of forcing a larger single-pack overcount, and shows the planned pull count and force total.
- After a failed combined pull, both the highlighted enemies and the guidance line narrow to the closest matching physical sub-pack.
- Moving patrol centers are smoothed between scans, preventing the guidance line and aura from jumping as patrol members change formation.
- Route data validates itself at runtime, and the audit verifies all eight challenge IDs, NPC force values, totals, and physical sub-pack signatures before packaging.
- Every embedded route NPC ID and enemy-force value was verified against MythicDungeonTools commit `95266d2d674b5a4c3350c7738caa75ccc7c72d9f` from October 5, 2026.
- Independent toggles for route guidance, route lines, next-pack highlighting, labels, auto loot, auto skinning, auto fishing, auto herbalism, and auto mining.
- Built-in routes: Altar of Fangs, Murder Row, Den of Nalorakk, The Blinding Vale, Voidscar Arena, King's Rest, Ruby Life Pools, and Temple of Sethraliss.

The route overlay uses NPC compositions and live enemies loaded by the client. It automatically loads the matching dungeon guide, remembers assignments by enemy GUID, separates repeated pack compositions, preserves assignments after partial kills, and resets on dungeon/challenge changes. Unloaded enemies are not assumed dead. This is inferred pull guidance: the embedded data does not contain exact MDT clone coordinates or collision-safe navigation waypoints. The line therefore points only to the next identified pull rather than pretending to be a walkable path. It does not require a WoW route addon.

Reload or rescan local scripts in Project Sylvanas, select **Protection Paladin Mythic+**, and enable the individual herb/mining automation and drawing toggles. Gathering approaches nodes from up to 60 yards, supports mounted gathering unlocks, and dismounts automatically when the client rejects mounted gathering. Gathering features only run outside combat.

Audit references checked on October 8, 2026:

- [Method rotation and defensive use](https://www.method.gg/guides/protection-paladin/playstyle-and-rotation)
- [Icy Veins rotation](https://www.icy-veins.com/wow/protection-paladin-pve-tank-rotation-cooldowns-abilities)
- [Valor](https://www.wowhead.com/spell=1269179/valor), [final Vanguard talent](https://www.wowhead.com/spell=1267215/glory-of-the-vanguard), [Blessed Word](https://www.wowhead.com/spell=1301732/blessed-word), and [Final Stand](https://www.wowhead.com/spell=204077/final-stand)
- [Tactyks video](https://www.youtube.com/watch?v=C0HuvxhvNnA) and [YoDaTV video](https://www.youtube.com/watch?v=15eTmWfKrLc): accessible descriptions and chapters were checked; no video playback validation was performed.
- [Reddit tank discussion](https://www.reddit.com/r/wow/comments/1wi4rj2/struggling_to_push_keys_as_a_pug_tankprot_paladin/) supplied leads for comparison with current guides.
- [Skill Capped 12.1 notes](https://www.skill-capped.com/wowarticles/general/patch-12-1-notes/) focus on PvP. No current Protection PvE rotation guide was found there.
- [Blizzard's Season 2 announcement](https://worldofwarcraft.blizzard.com/en-gb/news/24294369/the-shadows-deepen-midnight-season-2-begins-19-august) confirms the embedded eight-dungeon pool.
- [LittleWigs encounter modules](https://github.com/BigWigsMods/LittleWigs) provide the current boss and trash spell identities used by localized mechanic matching.
- [Updated PUG route field report](https://www.reddit.com/r/WOWMythicPlus/comments/1vvp84d/updated_mythic_routes_for_midnight_season_2_aimed/) favors sensible pull sizes and live-tested routing; its discussion also documents optional skips and riskier opening pulls. The plugin keeps its conservative built-in sequence until an exact, machine-verifiable MDT export is available.

Validation: all 41 Lua files compile; fifteen mocked regression suites cover combat, prediction, route progression and data integrity, danger geometry, role-aware boss instructions, gathering/loot, repairs, combat-log learning, healer mana, interrupt coordination, cleanse lifecycle, combat resurrection, healer support, Delve companion threat, persistent crash recovery, alternating-snapshot corruption fallback, synchronous logout, copy-ready export, and full module/callback loading. The boss guide includes 114 mechanic rules across all eight Season 2 dungeons, and every rule has stable spell-ID coverage for localized clients. Friendly damage is excluded from learning and extreme samples are capped. Router regression also verifies keystone risk scaling, split-pack line targeting, and stopping at required forces. Live in-game behavior and damage output still need an actual dungeon or Delve run. Learned damage is intentionally session-local so a patch or gear change cannot preserve stale danger values. Loot-source GUIDs are not exposed by the local API, so automated loot ownership is correlated rather than source-proven.
