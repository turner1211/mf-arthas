# Sylvanas Mage 1.1.77 — offline release candidate

Arcane, Fire and Frost for the Project Sylvanas Midnight client. Each spec has independent profiles for World PvE, Delves, Dungeons, Mythic+, Raids, Arena, Battlegrounds and World PvP: 24 profiles total.

## Install and start

1. Extract the ZIP and place the entire `sylvanas_mage` folder in your Sylvanas Lua plugin directory, alongside your existing plugins. Keep all modules together; `header.lua` and `main.lua` are the entry points.
   This archive is the standalone Mage plugin. It does not include, require or control Sylvanas Universal UI. If `sylvanas_universal_ui` is also installed, it remains a separate plugin and must be disabled or removed separately when you do not want its window.
2. Reload the plugin loader on a Mage running the Midnight client. The client must provide the documented Sylvanas `core` API and `common/enums`.
3. Open the Mage menu. Global **Enable Mage** starts ON, as requested. Disable any other rotation controller for the same character before running Mage; use Pause when reviewing options.
4. The command window follows the detected spec. Selecting an activity to edit changes its settings, not the detected live activity. Use Pause to stop actions.
5. Every applicable feature starts enabled, including training dummy testing, automatic PvP kill windows and Arena healer Polymorph. Existing saved feature switches are enabled once by this update; subsequent OFF choices stay saved. Pause starts OFF. Manual PvP burst permission remains a temporary live override and clears on a spec/activity change.

## Included behavior

Separate Arcane, Fire and Frost decision modules, plus an independent executor allowlist that rejects abilities from other specs. Approved learned replacements are resolved explicitly. Specialization, player identity, assigned role and activity changes clear pending casts and combat history. Conflicting specialization information, unsupported clients and non-DPS assigned roles pause actions. Talent, aura, charge, cooldown and cost reads reject identifiers belonging to another spec. Shared Mage abilities and legitimate two-spec replacements have explicit permissions; they never broaden a spell into an unsupported spec.

Arcane supports charges, Clearcasting, Salvo, Prismatic Bolt, mana recovery and burst windows. Fire handles Heating Up conversion, Hot Streak, Combustion, Pyroclasm, Meteor and safe Flamestrike. Frost handles Freezing stacks, Fingers of Frost, Glacial Spike, Frozen Orb, Blizzard and Ray of Frost. Learned spells, movement, cooldowns, mana, range, line of sight, facing and cast confirmation gate execution.

PvP runs through three separate decision modules, one per spec. Arcane uses pressure-aware charge generation and instant spenders; Fire requires a confirmed target stun for delayed Meteor kill windows and a full live interrupt-safe window for Pyroclasm hardcasts, and avoids PvE Firestarter/proc delays; Frost prioritizes instant pressure, channels only with sufficient space or control, and preserves the final Ray charge of its two-charge build outside a confirmed kill commitment. Arena, BG and world PvP keep separate settings. PvE priority rules do not execute in these PvP modules.

Utility includes spec-specific barriers, shared emergency immunity, Counterspell, confirmed Spellsteal, curse removal and Intellect upkeep. Arcane Mirror Image defense requires its Refractive Images talent and separate enabled profile switch. Intellect maintenance also runs before combat, respecting the active profile toggle, pause and transition gates. Curse removal excludes known-expired aura rows and rechecks live curse evidence immediately before input. PvP adds pressure responses, DR-aware roots, Arcane Slow and optional arena healer Polymorph. Unknown DR or immunity information blocks optional control. Manual spell input yields control briefly. Retry backoff prevents repeated failed inputs.

Area damage checks protected units and unintended pulls; Frozen Orb checks its forward path. Manual targeting remains yours. The plugin does not choose Blink destinations or automate encounter movement.

Training dummy testing recognizes native unit flags, the client's dummy helpers, known capital-city and expansion-hub NPC entries, and strict training/target/tanking dummy name fallbacks. Named Dornogal practice targets are also recognized. Selecting a living, attackable dummy allows the correct Arcane, Fire, or Frost rotation to open without a manual first hit. PvP, delve, Mythic/dungeoneer and raid/boss dummy names select their matching profile; ordinary city NPCs retain the normal fresh-pull block. Nearby dummies permit practice AoE, while any ordinary idle enemy still blocks it. The global option starts ON and can be disabled under **DISPLAY / LOGS** or the native menu.

## Visuals and helper

The GUI uses three spec-specific painted PvP scenes embedded directly inside Lua: Medivh for Arcane, Kael'thas for Fire and Jaina for Frost. Each spec also has its own embedded nine-piece painted icon atlas: Arcane uses mana runes and temporal magic, Fire uses phoenix/meteor/combustion imagery, and Frost uses crystalline shields and ice weapons. These are independent symbols rather than recolors. Native vector art remains only as a fallback. No image or layer files are installed; the Mage folder contains only Lua and Markdown. Buttons and switches use the clean high-contrast class-GUI treatment without diagonal decoration crossing their labels.

The DPS overlay includes the active spec/activity, action guidance, priority target lines, pressure markers, inherited Rogue/Ret encounter cards adapted for Mage, and timer/cast prompts. Inherited encounter cards are labeled as reference material and require validation against your live season. A sourced Nymrissa Wavecaller Heroic/Mythic card is included; other unknown raids, delves and world bosses receive generic coaching. Mechanic-name matches are restricted to the detected boss, and live cast names can select the matching prompt. Activity-specific gameplay coaching also covers PvP burst holds, target protection, Reflection, pressure, mitigation, mana and dangerous casts. English encounter names are used. Available BigWigs/ExBoss data can inform defensive preparation. This is not a complete authored encounter guide for every activity.

## Validation and live test checklist

39 Lua files compile; 4,029 offline behavioral assertions pass. `tests/scenarios.lua` is a self-contained mock suite for Lua 5.4, run from this folder so local modules resolve. See `TEST_REPORT.md`. These checks verify isolation and behavior; they do not measure live DPS or establish flawless gameplay.

See `RELEASE_AUDIT.md` for the requirement-by-requirement evidence and the live-client validation checklist.

Begin on a training dummy with each spec, including movement, proc consumption and burst. Confirm spell/aura IDs and learned replacement behavior for your exact build. Check barriers, interrupt timing, curse removal and Spellsteal in controlled encounters. Then test each activity and spec transitions, checking that burst permissions clear and profiles remain separate. Test arena DR, enemy immunity and healer protection with optional control enabled. Confirm ground casts, Orb paths, addon timers and overlay positioning in the real client.

Hero talent coverage is selective. Racials, equipment items, Alter Time, Blink placement, mass crowd control and every possible talent build are not automated. Passive hero-talent splash and hidden client data require live verification. The client API, tuning and talent behavior may change after the research snapshot.

## Persistent diagnostics and copying logs

Detailed combat logging starts ON. Open **DISPLAY / LOGS**, then press **COPY CURRENT LOG** to copy recent diagnostics, or **COPY PREVIOUS LOG** after a reload/reconnect to copy the last complete saved recovery checkpoint. Paste that text into this chat. Native Mage-menu copy buttons provide the same actions when the client's text-input clipboard API is available.

Each load creates a unique `scripts_log/sylvanas_mage/session_<number>.log` through the loader's API. Existing sessions are never recreated or deleted. Combat records use lightweight immediate session appends. Verified alternating recovery checkpoints are batched every five seconds to avoid blocking gameplay; errors, death, logout, world leave, disconnect and manual export force them immediately. Snapshots record health, mana, movement, pressure, burst permission and current-spec proc state.

Two alternating recovery files in `scripts_data/sylvanas_mage/` retain the latest 500 records. Each complete checkpoint is read back and verified; an interrupted newest write falls back to the other complete checkpoint. Session discovery can recover if the latest-session pointer is missing. Copying the previous checkpoint works without a clean logout event. The regular session log provides the longer record when the loader appends log messages; open that text file to copy a longer history. No archives are automatically deleted.

The logger page shows whether the checkpoint was verified, only a log write was accepted, or disk saving failed. Disk failure keeps recent records in memory and retries. Turning detailed logging OFF keeps essential errors and lifecycle records. The logger does not record chat messages or authentication tokens. A crash during the final OS/loader write or a total storage failure can still lose the newest record; real-client crash/reconnect testing remains necessary.

 `SylvanasMageStatus()` exposes current status. An optional `SylvanasMageCombatHold(context)` companion hook can request a hold.

Failed recovery checkpoints retry even after the native session stream accepted the records, without duplicating that stream.

The plugin now loads for a confirmed Midnight Mage even when spec data is temporarily missing or conflicting. Combat waits for a consistent spec and recovers automatically. Death, logout, world leave and disconnect immediately clear pending combat state, displayed advice and burst permission. Specialization/talent/equipment changes also clear the displayed scope before fresh detection.

Final readiness checks re-read player validity, mount state, casting/channeling and combat eligibility. Major burst rechecks target protection and magical mitigation. PvP gameplay tips use separate spec-specific advice instead of PvE proc-holding rules.

Callback failures include their source (update, game event, spell confirmation, menu, HUD or boss overlay) in diagnostics. Combat callback errors set Pause and clear burst permission; after reviewing the error, use Pause to resume. Rendering errors are contained and logged without stopping healthy combat; repeated identical errors are suppressed until a successful callback. The startup record names the complete prior-session checkpoint after recovery.

Spellsteal requires current confirmed purge data at final readiness. Counterspell rechecks both the active cast identity and interruptibility immediately before input.

The custom GUI exposes every native profile option for the automatically detected spec across eight activities. The spec selector is intentionally absent: the window cannot display or edit another spec. Choose only the activity profile to edit. MENU INFORMATION mirrors the Project Sylvanas global controls and every value in the detected spec/activity profile through Rogue-style paged rows. The footer shows the live status and provides its complete text as a tooltip. DISPLAY / LOGS includes the command-window switch, DPS overlay, detailed logging and current/previous log copy buttons.

Each spec has a separate lore-character PvP scene and matching controls. Arcane uses Medivh in a corrupted blood-ritual arena, Fire uses Kael'thas in a scorched phoenix battlefield, and Frost uses Jaina in a frozen crimson kill zone. Buttons and icons retain separate Arcane cuts, Fire claws and Frost fractures. The painted bytes live inside spec-only Lua modules; no image files are installed.

The custom window follows the stable interaction patterns from the local Rogue and Warrior plugins: F1 hides or reopens it once per key press, the header can be dragged while remaining inside the detected screen, the wheel pages long option lists, and rows highlight on hover. These controls affect the window only; F1 never changes combat enable or Pause.

The custom window remains available while spec or activity detection is missing during login/reconnect. It opens MENU INFORMATION with the actual waiting status; saved-log copy and options remain accessible. The previous theme is decorative only and never fills in a missing combat identity.

PvP Arcane now uses stationary Presence of Mind after Barrage inside a permitted active Surge/Touch window. PvP Evocation and Frost Ray recheck actual enemy positions and targeting before input; missing distance information blocks those channels. Recovery requires a longer control lookahead than Ray. These are pressure heuristics, not a prediction of every enemy interrupt. The native menu also remains accessible while detection waits, so a hidden custom window can be restored.

PvE Arcane Evocation can now end at 95% recovered mana. This applies only to an accepted, confirmed plugin request whose active channel start matches the request and subsequent observations. Manual spell input clears pending confirmation and channel ownership. Spec/activity/role changes, disabled recovery and unexpected channels revoke management. The API returns no success value, so diagnostics record a cancellation request; live channel completion is not inferred. PvP Evocation, Missiles and Ray are not shortened by this rule. Verify the optimization on a dummy, including manual recasts and confirmation timing.

Arena healer control can prepare an automatic kill window before burst is unlocked. This requires automatic windows, damage, cooldowns and arena control enabled, a learned own-spec offensive cooldown within five seconds, no current focus pressure, and health above the barrier threshold. It does not itself grant burst permission: the snapshot still waits for observed healer CC or another permitted kill condition. Clean-aura, DR, immunity, spacing and ally/pet-target checks repeat at readiness. BGs, world PvP and PvE never use this healer setup. Validate team coordination, healer identification and DR in live Arena.

Midnight defensive correction: baseline Mirror Image and Greater Invisibility are not treated as general damage reduction. Arcane Refractive Images enables Mirror Image damage smoothing, with its own ON-by-default defense switch and health threshold in each Arcane activity profile. These controls are not created for Fire or Frost. Talent disappearance is checked again before input. Environmental/raid damage and confirmed incoming boss pressure can trigger Arcane smoothing without an enemy directly targeting you. No automatic Greater Invisibility escape or generic Mirror Image threat diversion is added.

Fire PvE now protects a nearly full Fire Blast bank in a Firestarter window. It spends an existing Hot Streak first, then uses the documented charge start and duration data to estimate fractional recharge progress. Missing or invalid recharge metadata falls back to whole charges. This rule is absent from Fire PvP and every Arcane/Frost path.

Frostfire Frost PvE can end a plugin-owned Ray after at least one second in a multi-target situation when the final Hand of Frost talent is absent. With Crystalline Refraction it also requires two current Fingers of Frost stacks. The request must have been accepted and confirmed, and the exact channel start must still match immediately before cancellation. PvP, Spellslinger, manual channels and the Comet Storm replacement are excluded. The one-second timing is a conservative approximation of the upstream tick/GCD condition and requires live validation.

Frost PvE now includes Ice Nova and directional Cone of Cold under two separate ON-by-default Frost profile switches. Both require Cone of Frost, an available Ray charge and safe area data. Frostfire uses them at five targets after spending Frostfire Empowerment; Spellslinger uses them at four. Ice Nova is checked before Cone, and both precede the later Ray decision. Cone additionally requires the current target within 12 yards and verified live facing. These controls and priorities do not exist in Arcane, Fire or PvP profiles.
