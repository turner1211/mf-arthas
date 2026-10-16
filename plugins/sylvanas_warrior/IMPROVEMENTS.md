MYTHIC+ AND ARENA IMPROVEMENT CHECKLIST — COMPLETED

[done] Merge explicit arena frames into enemy discovery instead of relying only
on the general object list.
[done] Identify enemy healers from specialization IDs without sharing logic with
another class or specialization.
[done] Add arena ally-pressure detection and Intervene the focused low-health
party member during confirmed enemy pressure.
[done] Add Arms Ignore Pain under sustained health pressure. Fury and Protection
retain their own defensive branches.
[done] Rank hostile casts by effect and target. Healing, mass damage, control,
summons, and empowerment casts receive earlier interrupt timing.
[done] Protect the healer from targeted Mythic+ casts by raising their priority.
[done] Use Shockwave when at least two critical Mythic+ casts overlap in range,
subject to the existing engagement, crowd-control, and area-safety checks.
[done] Hold Mythic+ offensive cooldowns on small, dying trash pulls. Bosses,
larger pulls, and durable targets remain eligible.
[done] Add per-spec/per-mode controls for arena peeling, Mythic+ stop escalation,
minimum cooldown target count, and minimum target life.
[done] Make automatic Arena burst wait for a low target or a controlled enemy
healer. The manual burst toggle remains an explicit override.
[done] Preserve all 24 isolated Arms/Fury/Protection activity profiles and the
execution-time specialization/role/mode validation.
[done] Extend deterministic tests for arena-frame discovery, peel isolation,
and multi-caster Mythic+ stops.

SECOND-PASS HARDENING — COMPLETED

[done] Read live BigWigs and ExBoss countdowns through the loader API and use
only emphasized or clearly dangerous near-term bars.
[done] Pre-arm Protection Shield Block and major defensives for imminent timer
events, while keeping all timer automation out of PvP profiles.
[done] Use Rallying Cry before a predicted group hit when multiple allies are
already strained, instead of waiting until after lethal damage.
[done] Add Protection Disrupting Shout for overlapping critical casts, with
Shockwave as the safe fallback.
[done] Fix single-NPC Storm Bolt stops so they do not require player-only PvP
diminishing-return data.
[done] Add Wrecking Throw for substantial absorb shields when the talent is
actually learned, including shield-based Mythic+ mechanics.
[done] Track observed enemy PvP trinket use and treat a healer without a trinket
as an automatic Arena burst opportunity.
[done] Scan every engaged Arena opponent for active disarmable burst instead of
assuming the player's current target is the attacker.
[done] Fall back from Intervene to a DR-safe Storm Bolt when an enemy is bursting
into a focused low-health teammate.
[done] Add deterministic coverage for boss timers, PvP isolation, trinket memory,
off-target burst control, absorb breaking, Disrupting Shout, and NPC stun stops.

FINAL ROTATION AND ENCOUNTER AUDIT — COMPLETED

[done] Raise Protection's default Shield Block refresh window to support continuous
coverage while actively tanking and retain Ignore Pain's Shield Block rage reserve.
[done] Allow Demoralizing Shout on dangerous large pulls and predicted events,
without spending it on harmless single-target damage.
[done] Move Mountain Thane Odyn's Fury to the front of safe multi-target burst,
matching the current Midnight priority structure.
[done] Add DR-safe Storm Bolt control on the enemy healer during a confirmed Arena
kill window, without affecting battleground or PvE settings.
[done] Prevent Arms from repeatedly overwriting a healthy Ignore Pain absorb.
[done] Add exact priority names for verified Season 2 critical and high-priority
interrupts, while retaining generic and target-based fallbacks for hotfixes.
[done] Expose a read-only live validation snapshot with cast priorities, health,
rage, enemy count, Arena healer/trinket state, and encounter timers.

LIVE FOLLOW-UP
Observe-only testing should tune health thresholds, localized spell names, and
encounter-specific interrupt/reflect exceptions. Those depend on the actual
character, locale, loader build, and live combat data.

POSITIONAL BOSS GUIDE — COMPLETED IN 0.9.16

[done] Draw destination circles and true three-segment direction arrows.
[done] Compute stack, spread, kite, sidestep, close-range, and tank-facing anchors from live unit positions.
[done] Put Protection opposite the live party centroid for frontal-facing mechanics.
[done] Keep Arms/Fury DPS prompts and Protection tank prompts in separate guide modules.
[done] Leave object-specific mechanics text-only when a reliable live object position is unavailable.
[done] Deduplicate repeated context records discovered in the live saved log.
[done] Add deterministic geometry, arrow-rendering, metadata, and role-isolation tests.

AUTOMATIC PROTECTION ROUTE LOCATION — COMPLETED IN 0.9.17

[done] Match the tank's live area against every planned pull using NPC composition, distance, rarity, and route progress.
[done] Automatically advance to a clearly identified upcoming pack.
[done] Recover an earlier pull after a teleport, death return, reload mismatch, or sustained location mismatch.
[done] Prevent casual movement from incorrectly jumping backward through the route.
[done] Point the existing route line and destination marker to the automatically selected live pack.
[done] Persist the corrected pull per character and dungeon context.
[done] Keep automatic dungeon routing exclusive to Protection.

CLEAR-FLOOR OVERLAY AND LIVE-LOG PASS — COMPLETED IN 0.9.18

[done] Replace the large route aura and per-enemy rings with one small destination outline.
[done] Remove every mechanic circle and text layer centered over the player character.
[done] Reduce route and mechanic arrows to thin, low-opacity lines and compact arrowheads.
[done] Prevent generic boss markers from duplicating a positional mechanic arrow.
[done] Expand boss timer inputs and attach timer warnings to the live boss frame.
[done] Hold Charge for two seconds after a confirmed Charge to prevent immediate repeat failures.
[done] Respect the global cooldown before requesting Disrupting Shout.

ADAPTIVE COMBAT RECOVERY — COMPLETED IN 0.9.19

[done] Add a per-ability circuit breaker when the game rejects a cast that the
loader still reports ready, preventing retries from hopping between targets.
[done] Give movement, projectile, and interrupt actions longer exponential
recovery after repeated rejection; clear recovery immediately on success.
[done] Extend ally-interrupt deferral using measured latency to reduce duplicate
kicks without delaying an urgent fallback for too long.
[done] Spend Arms Execute and Fury Rampage resources when a PvE target has only
seconds to live.
[done] Move Protection Execute ahead of Revenge after its primary builders when
Shield Block is active or incoming damage does not require that rage reserve.
[done] Preserve all specialization, role, activity, target, and area-safety gates.

HERO-TREE AND PVP PRIORITY PASS — COMPLETED IN 0.9.20

[done] Keep Arms PvP Rend maintenance from delaying an active Warbreaker kill window.
[done] Consume Arms PvP Sudden Death before committing to Bladestorm.
[done] Complete Fury Slayer's Recklessness/Enrage Bladestorm before spending a
capped Sudden Death proc.
[done] Immediately Execute a one-health PvE priority target as Protection.
[done] Decay old ability-failure streaks after thirty seconds.
[done] Cap interrupt rejection recovery at four seconds so a stale loader error
cannot suppress the next emergency stop.

STRICT BURST ELIGIBILITY — COMPLETED IN 0.9.21

[done] Correct Lua operator grouping that allowed the burst state to become true
before target safety predicates were evaluated.
[done] Require a valid, engaged target within eight yards for every automatic or
manual offensive cooldown window.
[done] Hold burst into confirmed major damage reduction.
[done] Verify missing-target, unengaged-target, distant-target, and reduced-target
states independently.

DEFENSIVE ROTATION AND LOG SIGNAL — COMPLETED IN 0.9.22

[done] Hold routine Protection Demoralizing Shout while Shield Wall or Last Stand
is already active.
[done] Permit Demoralizing Shout overlap for an imminent timer, critical health,
or four-or-more-attacker emergency.
[done] Keep one-second combat snapshots and immediate state-change snapshots.
[done] Slow identical out-of-combat snapshots to ten seconds so useful combat
evidence remains longer in the bounded crash-safe log.

MAGIC-CAST RESPONSE ORDER — COMPLETED IN 0.9.23

[done] Let Pummel handle an interruptible targeted magic cast before consuming
Spell Reflection.
[done] Use latency-aware Spell Reflection as the fallback when Pummel cannot be used.
[done] Preserve Storm Bolt when Reflection can cover the cast.
[done] Retain Storm Bolt as the final stop when both Pummel and Reflection are unavailable.
[done] Never overwrite an already-active Spell Reflection aura.

URGENT INTERRUPT ARBITRATION — COMPLETED IN 0.9.24

[done] Give critical and player-targeted casts an early interrupt pass.
[done] Run emergency health and defensive logic immediately after that pass.
[done] Keep ordinary off-target casts on the configured progress timing after
survival decisions.
[done] Verify an urgent kick wins over Die by the Sword while an ordinary cast
yields to critical personal survival.

DEEP PVP LOGIC AUDIT — COMPLETED IN 0.9.25

[done] Keep the Arms Colossus PvE Ravager opener out of PvP and preserve the
Avatar into Warbreaker kill-window setup.
[done] Keep Mountain Thane's PvE Odyn's Fury opener out of PvP.
[done] Give Fury Slayer its PvP Recklessness, Avatar, then Bladestorm setup and
prevent duplicate Avatar requests while its aura is already active.
[done] Let unavailable healer Storm Bolt control fall through to a DR-safe
Shockwave on the kill target.
[done] Prepare Die by the Sword before Arms redirects verified melee burst with
Intervene at vulnerable health.
[done] Preserve Fury Charge inside fifteen yards in Arena while retaining the
normal Arms mobility threshold.
[done] Verify every change in the complete deterministic offline suite.

PVP PEEL AND MOBILITY AUDIT — COMPLETED IN 0.9.26

[done] Detect an active spell or channel explicitly targeting an Arena ally
before committing Intervene.
[done] Prefer DR-safe Storm Bolt against that spell burst and hold Intervene
when it cannot redirect the incoming damage.
[done] Pair Die by the Sword with Intervene only for positively identified
physical weapon pressure.
[done] Avoid treating every non-disarmable opponent as a caster; ordinary attack
pressure from those opponents remains eligible for Intervene.
[done] Extend Fury's fifteen-yard Charge conservation from Arena to battleground
and World PvP without changing Arms or Protection mobility.
[done] Audit the available Warrior runtime log and preserve the existing adaptive
cast-rejection recovery for older battleground failure bursts.

ARMS AND FURY PVP TARGET LINES — COMPLETED IN 0.9.27

[done] Draw a crimson Arms or orange Fury line to the current PvP target.
[done] Draw a separate enemy-healer line using live specialization data.
[done] Show the healer line in green with line of sight and red without it.
[done] Support Arena frames plus battleground and World PvP unit discovery.
[done] Add the enabled-by-default PvP line option to the standard panel and
custom GUI for every Arms and Fury PvP profile.
[done] Keep the overlay out of Protection and every PvE activity.
[done] Use code-rendered geometry only, preserving the Lua/Markdown-only folder.

ARENA COMPETITIVE LOGIC PASS — COMPLETED IN 0.9.28

[done] Keep Storm Bolt on the kill target unless Shockwave is learned and ready
to continue control after a healer Storm Bolt.
[done] Add DR-safe Intimidating Shout as close-range offensive control and an
emergency ally peel when the preferred stun is unavailable.
[done] Enter Defensive Stance for verified enemy burst even before health falls.
[done] Complete Arms Avatar and Warbreaker setup before Mortal Strike pressure.
[done] Correct Wrecking Throw to spell 384110 and register Shattering Throw as
spell 64382 for confirmed immunity removal.
[done] Allow Shattering Throw through confirmed immunity while preserving the
ordinary crowd-control protection gate.
[done] Verify the pass with the complete deterministic offline suite.

ARENA OPENER AND DEFENSIVE TRADING — COMPLETED IN 0.9.29

[done] Open each Arena combat round with an eight-second automatic control and
cooldown opportunity while preserving every immunity, range, and safety gate.
[done] Reset opener state on the next combat round without leaking it across
specification or activity changes.
[done] Preserve Charge inside fifteen yards for both Arms and Fury in Arena.
[done] Rank verified disarmable burst by danger to the Warrior and vulnerable
allies, then use Disarm before redirecting that damage with Intervene.
[done] Let Fury activate Enraged Regeneration before a dangerous Intervene.
[done] Trade the specialization's major personal defensive under active Arena
pressure when the friendly healer is confirmed hard controlled.
[done] Distinguish hard control from roots and snares before spending a major.

ARENA MAXIMUM-DAMAGE PRIORITY PASS — COMPLETED IN 0.9.30

[done] Convert Arms Colossus Smash with Demolish before returning to Mortal
Strike during the Arena kill window.
[done] Consume a confirmed Arms Heroic Strike proc before Mortal Strike inside
the burst sequence.
[done] Open Fury Mountain Thane Arena burst with Avatar before Recklessness
without changing its separate PvE cooldown order.
[done] Include Champion's Spear in the Fury Arena burst sequence.
[done] Prioritize Mountain Thane Rampage, Stormblast, and Execute ahead of its
ordinary Raging Blow and Bloodthirst builders in PvP.
[done] Move Protection Arena Execute and Stormblast ahead of PvE-oriented burst
actions and its ordinary Shield Slam priority.
[done] Verify every changed branch and specialization boundary offline.

ARENA DAMAGE-STANCE UPTIME — COMPLETED IN 0.9.31

[done] Stop treating every minor targeted magic cast at full health as enough
reason to sacrifice damage in Defensive Stance.
[done] Preserve Defensive Stance for verified burst, multiple attackers, low
health, and imminent dangerous mechanics.
[done] Return immediately to Battle or Berserker Stance during a verified Arena
kill window when confirmed pressure is absent.
[done] Keep the normal safety delay outside that verified Arena condition.
[done] Let Arms spend Slam above 50 Rage in Arena when every stronger action is
unavailable, matching the current sustained-damage threshold.

ARENA FIRST-CONTACT BURST TIMING — COMPLETED IN 0.9.32

[done] Start the automatic opener only after an engaged target becomes hittable
inside eight yards.
[done] Preserve the opener while crossing the Arena instead of expiring it from
the initial combat-state transition.
[done] Keep the eight-second duration, round reset, immunity gate, damage
reduction gate, and manual burst override unchanged.

HERO-TREE ARENA SEQUENCING — COMPLETED IN 0.9.33

[done] Mark the live first-contact window separately from later automatic or
manual kill windows.
[done] Let Fury Slayer's opener establish available Rampage before Bladestorm.
[done] Keep later Fury Slayer burst on its Bladestorm-before-Rampage sequence.
[done] Let Arms Colossus establish Avatar and Warbreaker before Arena control.
[done] Apply the Colossus control after armor break and immediately before the
existing Demolish conversion.
[done] Preserve normal control-first behavior for Arms Slayer, Fury, and
Protection.

MANUAL OPENER CONTEXT AND ARENA DIAGNOSTICS — COMPLETED IN 0.9.34

[done] Track first melee contact even when automatic burst is disabled.
[done] Give an explicit manual burst request the correct opener rotation during
the live first-contact window.
[done] Keep automatic burst disabled when the user turns it off.
[done] Add target distance and first-contact state to persistent snapshots for
live Arena uptime and sequence analysis.
[done] Audit the available runtime log; no Arena combat was present, so no
opponent-specific assumptions were introduced from World PvE idle data.

ARENA ROOT-UPTIME RESPONSE — COMPLETED IN 0.9.35

[done] Detect confirmed player roots separately from slows and other loss-of-control states.
[done] Let Arms and Fury use Avatar, then their own Bladestorm, when a confirmed Arena root removes melee uptime.
[done] Preserve offensive cooldowns for roots inside melee range, targets beyond twenty-five yards, and verified damage-reduction windows.
[done] Keep the exception out of Protection, World PvP, PvE, and cross-specialization spell tables.
[done] Record rooted state in the crash-safe diagnostic snapshots for live Arena review.
[done] Verify root, snare, range, mode, and specialization boundaries offline.


PROTECTION PHALANX APEX CADENCE — COMPLETED IN 0.9.36

[done] Detect the learned Phalanx Apex talent and its confirmed player buff.
[done] Prime Protection multi-target Shield Slam with Thunder Clap when Phalanx is absent.
[done] Consume an active Phalanx with Shield Slam instead of repeating Thunder Clap.
[done] Preserve the normal immediate Shield Slam priority on a single target.
[done] Prove Phalanx cannot enter Arms or Fury rotation logic.


ARMS PVP RAGE-DUMP ORDER — COMPLETED IN 0.9.37

[done] Move Slam above an ordinary Overpower when Arms has more than fifty Rage in PvP.
[done] Keep Mortal Strike, burst setup, Heroic Strike, Execute, and capped proc handling ahead of the Slam dump.
[done] Preserve Overpower at exactly fifty Rage and below.
[done] Keep the change isolated from Arms PvE, Fury, and Protection.
[done] Audit the available runtime log; it still contains no current-version combat session, so no unsupported live assumptions were added.


FURY MOUNTAIN THANE PVE PRIORITY — COMPLETED IN 0.9.38

[done] Move available Execute ahead of ordinary Crushing Blow and Bloodthirst after capped proc handling.
[done] Spend Rampage during Recklessness before ordinary Crushing Blow.
[done] Preserve high-priority Thunder Blast and Bloodbath conditions.
[done] Keep Slayer and all Fury PvP sequencing on their separate branches.
[done] Verify Raid, Mythic+, and Arena boundaries offline.


ARMS SLAYER PRE-BLADESTORM EXECUTE — COMPLETED IN 0.9.39

[done] Consume an available Sudden Death Execute immediately before Slayer Bladestorm.
[done] Keep Avatar and armor-break setup ahead of the Execute/Bladestorm pair.
[done] Fall through to Bladestorm when Execute is unavailable.
[done] Preserve capped Sudden Death fallback when burst actions are unavailable.
[done] Leave Colossus Demolish sequencing unchanged and spec-isolated.


PATCH 12.1.5 PROTECTION COLOSSUS RAGE COSTS — COMPLETED IN 0.9.40

[done] Apply the new ten-Rage Practiced Strikes efficiency to Colossus Revenge thresholds in PvE.
[done] Apply the same verified cost reduction to Colossus Execute thresholds in PvE.
[done] Preserve the existing Shield Block reserve instead of treating the discount as free spending.
[done] Keep Mountain Thane thresholds and Protection PvP pooling unchanged.
[done] Verify Colossus, Mountain Thane, Raid, and Arena boundaries offline.


PATCH 12.1.5 PROTECTION OPPRESSOR — COMPLETED IN 0.9.41

[done] Register Oppressor as a distinct Protection-only PvP action instead of passing it through the PvE Taunt gate.
[done] Apply Focused Assault during a verified Protection kill window.
[done] Detect a teammate attacking the same battleground or Arena target as an independent focus signal.
[done] Preserve Oppressor when neither burst nor team focus is confirmed.
[done] Keep Oppressor out of Arms, Fury, and every PvE mode.



PROTECTION MORALE KILLER TEAM PEEL — COMPLETED IN 0.9.42

[done] Track verified nearby enemy burst aimed at a party member separately from personal pressure.
[done] Use Demoralizing Shout as team mitigation only when Morale Killer is learned.
[done] Allow the team peel while Shield Wall is active because the two defenses cover different targets.
[done] Require the burst enemy to be within Demoralizing Shout range and preserve area-safety checks.
[done] Keep the response out of PvE, Arms, Fury, and personal major-defensive logic.



ARMS PVP HEROIC STRIKE PROC PRIORITY — COMPLETED IN 0.9.43

[done] Consume a confirmed Master of Warfare Heroic Strike replacement before the routine sustained PvP Mortal Strike gate.
[done] Preserve Rend upkeep ahead of the proc and keep documented burst setup unchanged.
[done] Return to Mortal Strike pressure immediately when the proc is absent.
[done] Preserve the established Arms PvE proc priority and all Fury/Protection branches.



ARMS/FURY ARENA OPENER SLOW ORDERING — COMPLETED IN 0.9.44

[done] Establish a confirmed missing Hamstring before offensive Storm Bolt or Shockwave in Arms and Fury Arena openers.
[done] Keep interrupts, emergency survival, root breaks, Disarm, and defensive ally peeling ahead of slow upkeep.
[done] Continue directly into offensive control once the kill target is already slowed.
[done] Preserve Protection, battleground, World PvP, and PvE decision ordering.



PROTECTION COLOSSUS PVE DEMOLISH PRIORITY — COMPLETED IN 0.9.45

[done] Use Demolish on cooldown during eligible Protection Colossus PvE cooldown windows instead of requiring three stacks.
[done] Place Demolish before Shield Charge inside the amplified cooldown sequence.
[done] Continue honoring active mitigation, movement/channel safety, cooldown settings, and area safety.
[done] Preserve the separate three-stack Demolish rule in Protection PvP.
[done] Verify low-stack PvE use, cooldown fallback, disabled-cooldown behavior, and PvP isolation.



ARMS SLAYER CAPPED SUDDEN DEATH PRIORITY — COMPLETED IN 0.9.46

[done] Spend two stacked Sudden Death procs before Heroic Strike in Arms Slayer PvE.
[done] Preserve Heroic Strike priority when only one Sudden Death stack is held.
[done] Preserve Colossus Heroic Strike-first ordering.
[done] Prevent the Slayer PvE rule from crossing into Arena, battlegrounds, or World PvP.



FURY MOUNTAIN THANE BLOODBATH/THUNDER BLAST ORDERING — COMPLETED IN 0.9.47

[done] Place Bloodbath before a single Thunder Blast charge during Avatar in single-target PvE.
[done] Use that Thunder Blast immediately after Bloodbath to extend Avatar.
[done] Preserve early Thunder Blast at two stacks, near proc expiration, and in AoE.
[done] Preserve Mountain Thane PvP's separate Stormblast-first branch.



SHIELD-BREAK STALE COOLDOWN PROTECTION — COMPLETED IN 0.9.48

[done] Use confirmed cast history to suppress repeated Wrecking Throw requests when native cooldown data remains stale.
[done] Apply the same protection to Shattering Throw immunity removal.
[done] Keep the fallback below Demolition's reduced 22.5-second cooldown.
[done] Preserve ordinary native readiness, shield thresholds, immunity checks, and mode/spec isolation.



BOUNDED COMBAT DIAGNOSTIC SNAPSHOTS — COMPLETED IN 0.9.49

[done] Enforce the intended one-second snapshot cadence during combat and training-dummy sessions.
[done] Prevent exact health, prediction, and Rage changes from generating ten snapshots per second.
[done] Keep cast events, failures, confirmations, game events, and status transitions immediate.
[done] Preserve immediate idle context changes, crash recovery, and the copyable 64 KB diagnostic report.



FURY PVE WRECKING THROW DAMAGE FILLER — COMPLETED IN 0.9.50

[done] Add Wrecking Throw after rotational attacks for Slayer PvE.
[done] Add Wrecking Throw after rotational attacks for Mountain Thane PvE.
[done] Preserve the higher-priority absorb-removal utility path.
[done] Prevent this damage filler from crossing into PvP, Arms, or Protection.



ARMS PVE WRECKING THROW DAMAGE FILLER — COMPLETED IN 0.9.51

[done] Add Wrecking Throw after all ordinary Arms PvE rotational actions.
[done] Preserve higher-priority absorb removal before the specialization rotation.
[done] Prevent routine Wrecking Throw damage use in Arena, battlegrounds, and World PvP.
[done] Verify that the Arms/Fury damage-only fallbacks cannot cross into Protection.



LOW-LAG RUNTIME HOT PATHS — COMPLETED IN 0.9.52

[done] Prefer Project Sylvanas' optimized unit-helper enemy list over raw world-object enumeration.
[done] Cache the enumeration container for 250 ms while keeping unit health, casts, targets, and other combat fields live at the 100 ms decision rate.
[done] Retain a raw-object compatibility fallback for loader builds without the optimized helper.
[done] Buffer recovery-log text and checkpoint it every 15 seconds instead of recreating a growing data file every second.
[done] Keep append-only session records immediate and force recovery checkpoints on logout or world departure.
[done] Verify object-cache cadence, logger cadence, crash persistence, mode isolation, and all existing behavior offline.



ALL-MODE GUI AND HOTKEY CONTROLS — COMPLETED IN 0.9.53

[done] Replace the artwork-heavy panel with a clean, readable full-width layout.
[done] Add Core, Abilities, Utility, Defense, Players, Dungeons, Visuals, and Diagnostics tabs.
[done] Keep all eight activity profiles available from every tab.
[done] Give every actionable global and profile ON/OFF option an independent persistent hotkey.
[done] Synchronize GUI clicks, Project Sylvanas menu checkboxes, and hotkey toggle state in both directions.
[done] Preserve class, specialization, role, and activity visibility rules so invalid options cannot cross profiles.
[done] Reserve F1 and F7 for the two Warrior windows and reject those keys during option assignment.
[done] Keep numeric thresholds as bounded value controls and retain the two-window, no-flicker lifecycle.



PROTECTION COLOSSUS AND CITY-DUMMY SUPPORT — COMPLETED IN 0.9.54

[done] Use Demolish as Protection's preferred Colossus signature attack.
[done] Fall back to Colossus Smash when the current Protection build does not know Demolish.
[done] Run the Protection PvE signature attack on cooldown after mitigation even when generic burst is held.
[done] Preserve the user cooldown switch and the separate PvP Colossal Might pooling rule.
[done] Keep the fallback out of Fury and retain explicit spell allowlisting.
[done] Extend training detection through the native helper, stable capital-city NPC identities, and safe dummy/practice/combat-target names.
[done] Reject player-name spoofing and ordinary NPC names.



THREE-SPEC WARRIOR SUITE INTERFACE — COMPLETED IN 0.9.55

[done] Rework the main window around an ornate framed suite layout with a large specialization header.
[done] Give Arms a crimson blade theme, Fury a fire-and-axes theme, and Protection a blue steel shield theme.
[done] Add distinct crest geometry, titles, header etching, accent colors, and activity-profile language for all three specs.
[done] Retain the eight purpose tabs and all eight editable activity modes.
[done] Add glowing switch-style ON/OFF controls and hotkey boxes with previous/next selectors.
[done] Preserve direct press-a-key assignment and reserve F1/F7 for the two Warrior windows.
[done] Verify spec themes and retain all specialization/activity visibility gates.

