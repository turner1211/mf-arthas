HUNTER REQUIREMENT AUDIT — 2026-10-15, v1.6.0

This audits the full requested scope. Offline evidence is explicitly separated
from native/live evidence; passing mocks does not prove flawless gameplay.

1. BM, MM, Survival: three independent rotation modules and executor allowlists.
   Evidence: hh_bm/mm/sv.lua, hh_spells.lua, tests/scenarios.lua.
   Offline coverage present; actual damage/hero-tree interactions unverified.
2. Eight activities x three specs: hh_modes.lua and unique settings profile keys.
   Evidence: routing, foreign-action, setting isolation and late-transition tests.
   Offline covered; all 24 native activity/spec runs still need evidence.
3. Auto spec/role detection: hh_identity.lua; repeated input-boundary checks.
   Offline ID/index/conflict tests pass. Native spec changes remain unverified.
4. No cross-spec/mode actions: decision and executor guards; owner-aware World
   PvP routing prevents player pets from using World PvE profiles.
   Offline covered. Missing owner data deliberately holds detection.
5. Observe mode removed: no observe control; enabled actions cast directly.
   Evidence: entrypoint and direct-input tests. Global enable defaults ON at user request in v1.4.7.
6. Three custom themed GUIs/icons/buttons: separate cached BMP modules and
   distinct BM/MM/SV controls. GUI schema covers every applicable profile option.
   Offline native drawing traces/UVs verified. Live visual fidelity/flicker
   resolution requires an actual client rendering session.
7. Exactly two GUIs: the large F1 command window and compact F7 boss helper.
   The former DPS status HUD and its module were removed. Window-count tests pass.
8. No PNG/JPEG/layer files: packaging rejects prohibited formats; portraits and
   icons are BMP bytes embedded in Lua. Preview images outside package are WebP.
   Evidence: package validation and file manifest.
9. Rogue/Ret DPS helper: adapted encounter cards, live-cast/timer prompts and
   overlay for all three specs in every PvE activity. Generic guidance covers
   unknown bosses. Raid/delve authored cards are not a complete database.
10. Internet research: RESEARCH.md records current primary author guides,
    SimulationCraft source lists, platform contracts and concrete adaptations.
11. Persistent/copyable logging: bounded batch records with forced lifecycle/error saves, fresh numbered
    sessions, retained rotation, retries and native clipboard controls.
    Mock behavior plus real-filesystem abrupt-exit/restart test verified.
    Native in-game writes/clipboard and final OS buffering remain unverified.
12. Verified installation: release manifest hashes are compared with every
    installed file after copying. Other plugins are not modified.

REMAINING EVIDENCE REQUIRED
* Native cast requests, actual confirmation payloads, range/LoS, pet pathing,
  moving/channel interactions and errors for all 24 profiles.
* Both available hero trees/talent combinations per spec, including native
  required-aura visibility and charge-recharge timestamp units.
* PvP DR/immunity/trap behavior under latency and real target/owner transitions.
* Comparable damage samples and cast breakdowns for single targets, packs,
  arena/BGs/world PvP; offline priority tests are not DPS benchmarks.
* Native rendering of both GUIs, F1/F7, copy controls and crash recovery.

The overall near-flawless gameplay objective is not proven complete. The logger
now provides the evidence needed to continue the native validation and fixes.

Version 1.4.56 replaces the fixed cast-confirmation deadline with a bounded,
smoothed deadline learned from successful local acknowledgements. Offline tests
cover ordinary, delayed, capped, expired and confirmed requests. Native Arena
latency and callback timing still require fresh logs.


Native evidence update: v1.4.3 BM World PvE successfully requested and confirmed
Barbed Shot, Kill Command, Cobra Shot and Mend Pet in the inspected session.
Saved native logs verify file append. These observations replace the earlier
idle-only checkpoint for this one profile; the rest of the scope remains open.
Missing Bestial Wrath requires the added native readiness probes and new logs.

1.4.7, native v1.4.4 BM World PvE evidence:
Bestial Wrath ID19574 known=true usable=true cd=0 gcd=0 ready=false;
range_enemy=false range_pet=false range_self=false, with valid pet/LoS/facing.
A spell-specific range exemption preserves the enemy-target dispatch and all
remaining engagement, protected-target, pet-cleave, identity and burst guards.
Other spells retain strict native range checks. Requires live cast confirmation.
Primary platform docs explicitly allow range skipping for self-buff spells:
https://docs.project-sylvanas.net/dev/api/spellbook/helper/
SimulationCraft midnight bestial_wrath_t models player and pet buffs separately
from pet damage. Full DPS/all-profile/live GUI validation remains incomplete.
1.4.8 adds source-informed BM PvP two-Barbed burst preparation with charge,
confirmation-age, spec, activity and burst guards. Offline branch checks do not
prove damage gain or native arena/BG/world-PvP behavior.

1.4.9 adds native city training-dummy classification for all three specs. Tests
cover no-threat/no-combat startup and prove an ordinary idle NPC remains held.
Actual city dummy behavior and cast confirmations still require live testing.

Live installation convention: the scripts folder includes the release version
in `sylvanas_hunter_v<version>`, and prior Hunter release folders are removed
after the replacement is verified to prevent duplicate loading.


Version 1.4.57 adds spec-isolated fractional-charge protection. The snapshot
handles documented seconds and legacy millisecond start timestamps and safely
falls back to integer charges when timing is missing. Offline cases prove BM,
MM and Survival spend their own charge abilities before imminent cap waste.
Native recharge timestamps and resulting DPS still need fresh client logs.

Version 1.4.58 adds persistent native charge diagnostics for the detected spec.
This closes the prior observability gap, but actual BM/MM/Survival samples are
still required before native timestamp compatibility or DPS benefit is proven.

Version 1.4.59 responds to retained BM Arena evidence showing clustered native
failures across unrelated spells. The executor now blocks every request during a
confirmed native loss of player control and logs that state in heartbeats. This
is offline verified; a new Arena log must prove the failure clusters disappear.

Version 1.4.60 adds a bounded multi-action failure circuit based on 13 measured
clusters in the retained BM Arena session. Tests prove activation, automatic
one-second recovery and transition reset. New native logs must compare failure
cluster counts and confirmation rates against the old-session baseline.

Version 1.4.64 corrects the stale Meittik card, adds native Lekshi/Kezkitt detection, and tests authored Trinity guidance in Mythic+. Live boss-frame names, timer text, and window rendering remain unverified in the client.



Version 1.4.64 replaces full object scans with the documented cached enemy helper, reuses snapshot positions and aura results, removes repeated PvP render queries and color construction, batches routine storage writes, and adds live timing telemetry. Offline checks validate API fallback and optimized-path selection; only live client profiling can confirm hardware-specific frame pacing.


Version 1.4.64 expands the main customer GUI to twelve category tabs, adds saved ON/OFF controls and conflict-safe hotkeys for every boolean feature, and wires new customization controls into combat, overlay, boss-helper, dummy, and logging behavior. The two-window limit remains intact.


Version 1.4.64 adds layered major-city dummy detection across BM, Marksmanship, and Survival, verifies named and localized-ID fallbacks, keeps real idle NPCs blocked, and preserves World-PvE/spec isolation.

Version 1.4.65 redesigns the existing F1 window without adding a third GUI. Offline native-render checks cover all twelve pages for all three specs, verify activity and spec filtering, and keep foreign-spec controls absent. BM, Marksmanship, and Survival retain separate embedded artwork, icon atlases, titles, colors, and page content.

Version 1.5.0 adds deterministic Midnight/Forever runtime dispatch. Separate spell modules, rotation modules, resource handling, settings namespaces, hotkeys and log roots prevent cross-client state and logic bleed. Dedicated offline Forever tests verify the exact client key, new spell table, all three rotation dispatches, and foreign-spec rejection. Live Forever beta testing is still required to confirm current server-side spell behavior and timing.


Version 1.5.1 removes every player, specialization, spell-book, and game-UI query from header.lua. WoW Forever identity detection waits eight seconds after a valid local player appears, preventing DB2 access during native client startup.


Version 1.6.0 adds the researched Forever Hawk-cap model, mana reserves, shared-shot cooldown choices, aspect switching, dead-zone fallbacks, spec-specific control, corrected Forever spell ranks, and expanded isolation tests.


Version 1.6.1 adds adaptive Scorpid/Viper/Serpent selection, target-mana sampling, separate Forever Fire/Frost trap logic, post-Feign hold timing, and customer toggles/hotkeys for the new Forever systems.

Version 1.6.2 adds target-bound Hawk lifetime tracking, closing-speed protection for long ranged casts, offensive and emergency Readiness planning, melee-scoped Deterrence, pressure-aware Mend Pet timing, and stable Survival Monkey/Beast aspect transitions. All changes remain inside the Forever dispatcher and Forever settings namespace.

Version 1.6.3 corrects Rapid Fire to a baseline all-spec Forever ability, adds BM and Survival burst usage, adds durable-target Readiness reuse, changes safe PvE cleave to the researched two-target threshold while retaining three targets in PvP, and prevents unsafe Revive Pet recommendations during pressure.

Version 1.6.4 adds learned-spell fallback from unavailable Viper Sting to Serpent Sting, broadens Scorpid selection from observed physical pressure, adopts the level-30 BM simulator's single-target Multi-Shot priority, and moves Survival's durable-target Lacerate and high-share Raptor Strike ahead of lower-value trap and Strider fillers.

Version 1.6.5 adds Survival-only Track Humanoids upkeep for the Improved Tracking PvP damage bonus, a spec/mode-filtered default-on GUI option and hotkey, guarded unknown-aura handling, and the current explicit Mongoose Bite/Strider Kick/Raptor Strike priority.

Version 1.6.6 adds native character-level detection and explicit Forever unlock boundaries, corrects BM to the current Multi-Shot/Arcane simulator priority, reserves Rapid Fire by context, and makes Pet-first engagement safety functional with a bounded hand-off.

Version 1.6.7 adds level-gated Track Hidden, Scare Beast pet control, guarded healer-peel Distracting Shot, level-scaled mana floors, short-target Sting suppression, and breakable-fear protection without changing Midnight modules.

Version 1.6.9 adds early-level Monkey aspect transitions, level-8 solo Concussive Shot approach control, and explicit unlock checks for defensive, pet, trap, and kiting utility. Offline tests cover both sides of each new level boundary; live Forever testing remains necessary to tune timing against server latency and current NPC behavior.

Version 1.6.10 guards the remaining direct native reads in the portrait and icon texture paths and consolidates the live scripts installation to a single Hunter release folder. This removes a confirmed duplicate-load risk and prevents transient time or window-position failures from aborting a GUI frame.

Version 1.6.11 corrects mixed-unit aura expiration math. Millisecond and seconds-based native timestamps are both covered offline, preventing a five-second aura from being misread as 0.005 seconds on seconds-based hosts.

Version 1.6.12 adds the Patch 12.1.5 Sentinel/Twin Fangs Boomstick opener and
updates Forever Survival's melee ordering from build 1.60.1.70425 simulator
data. Both changes remain isolated by client, specialization and activity.
Critical lifecycle/checkpoint/fatal log records now force a disk flush; ordinary high-frequency telemetry remains batched for performance.
