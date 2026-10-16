# Damage audit - October 3, 2026

## WoW Forever level and priority audit - v1.2.8 (October 15, 2026)

The Forever engine now reads the character's live level and applies a branch-local learn-level guard before considering trained abilities. This prevents overlapping or stale spellbook IDs from selecting a spell before it should exist. The GUI and persistent STATE records expose the detected level, while the actual known-spell query remains authoritative for talent choices and purchased ranks. Poison unlocks are separated at levels 20, 24, 30 and 32; the level-30 talent tier and level-40 capstones remain isolated from lower-level priorities. A level-one Forever Rogue can now identify the client through the Classic Sinister Strike fingerprint before Mutilate is learned. If neither the version nor a branch-specific spell is readable during startup, detection retries instead of permanently locking the Retail fallback.

Assassination now keeps Venom and Slice and Dice ahead of a long-target PvE Rupture, then spends on Coup de Grace/Eviscerate. The Rupture branch is suppressed in PvP to preserve Blind, Gouge and Sap reset targets. Combat waits until at most half Energy before starting Adrenaline Rush, avoiding wasted doubled regeneration, and Combat/Subtlety value Ghostly Strike early when multiple attackers are connected. These rules come from Blizzard's current Forever Rogue deep dive, the current beta spell/talent comparison, and current leveling/rotation guidance: [Blizzard Rogue deep dive](https://news.blizzard.com/en-us/article/24310968/world-of-warcraft-forever-class-deep-dives-rogue-and-warlock), [Classic WoW Forever Rogue changes](https://classicwowforever.com/class-changes/rogue/), [Classic WoW Forever Rogue guide](https://classicwowforever.com/class-guides/rogue/), [Icy Veins Forever Assassination guide](https://www.icy-veins.com/wow-forever/assassination-rogue-melee-dps-pve-guide), and [wow.gg Forever Combat guide](https://wow.gg/guides/wow-forever-combat-rogue-beta).

## WoW Forever range, interrupt and survival audit - v1.2.7 (October 15, 2026)

Forever combat no longer tests melee reach with Midnight Mutilate spell 1329. It probes the actual selected Forever action, treating self-targeted cooldowns as immediately actionable. This prevents a valid Mutilate, Sinister Strike, Backstab, Eviscerate, or Forever cooldown from being diverted into an unusable Retail ranged fallback when the host correctly reports the Retail spell as unknown.

Interrupt decisions now resolve the highest learned Forever Kick rank for readiness, range, direct casts, Shadowstep control plans, and confirmed healer lockout memory. Combat aligns Blade Flurry with a safely isolated Kidney Shot window as well as bosses and two-target pulls. Predictive defense trades Evasion at 85% projected health when two or more melee attackers are already connected, following Forever's guidance to use it when the second enemy joins instead of waiting until nearly dead. Sources: [ForeverDB current Rogue guide](https://foreverdb.net/class/Rogue), [ForeverDB Rogue builds](https://foreverdb.net/class/Rogue/builds), [ForeverDB Rogue PvP guide](https://foreverdb.net/class/Rogue/pvp?spec=Subtlety), [ForeverDB Rogue PvE guide](https://foreverdb.net/class/Rogue/pve), and [ForeverDB level-30 guide](https://foreverdb.net/guide/leveling-rogue).

## WoW Forever poison isolation and short-target audit - v1.2.6 (October 15, 2026)

Forever poison preparation now resolves its own ranked coating families instead of reusing Midnight constants. It selects the highest learned rank, uses Deadly plus Instant for durable Assassination PvE, Instant plus Deadly for Combat/Subtlety PvE, prefers future Wound Poison in PvP when it is actually learned, and pairs Mind-numbing with caster or healer targets while retaining Crippling against other players. Dragon-Tempered Blades and other Retail-only poison behavior cannot enter this path. City poison upkeep also stays inside the Forever plan.

All three Forever trees now spend three or four combo points on Eviscerate when a target is about to die rather than losing target-bound points. Full five-point finishers remain the normal priority. This follows the current level-30 guidance to finish early only when the mob will die before another builder. Sources: [ForeverDB level-30 Rogue guide](https://foreverdb.net/guide/leveling-rogue), [ForeverDB Rogue builds](https://foreverdb.net/class/Rogue/builds), [ForeverDB Instant Poison](https://foreverdb.net/spell/8679), [ForeverDB Deadly Poison](https://foreverdb.net/spell/2823), [ForeverDB Crippling Poison](https://foreverdb.net/spell/3408), [ForeverDB Mind-numbing Poison](https://foreverdb.net/spell/5761), and [WoW Honor Forever Rogue PvP guide](https://wowhonor.com/guides/classes/rogue/).

## WoW Forever stun-window audit - v1.2.5 (October 15, 2026)

The Forever PvP engine now preserves the combo points earned by Cheap Shot and Initiative until Kidney Shot can be chained, including Subtlety's documented three-point Kidney opener. While Cheap Shot is active, it pools instead of spending those points on Slice and Dice, Rupture, or an early Eviscerate. During the resulting stun window, maintenance Slice and Dice and long-target Rupture yield to direct damage, and Assassination only commits Cold Blood when the kill target is confirmed stunned.

This closes a sequence-level damage loss that individual spell-priority checks could not catch: the former profile recognized both Cheap Shot and Kidney Shot but allowed the damage profile between them to consume the shared combo-point resource. Sources: [ForeverDB Rogue builds](https://foreverdb.net/class/Rogue/builds), [ForeverDB Cheap Shot](https://foreverdb.net/spell/1833), [ForeverDB Kidney Shot rank 1](https://foreverdb.net/spell/408), [ForeverDB Kidney Shot rank 2](https://foreverdb.net/spell/8643), [ForeverDB Cold Blood](https://foreverdb.net/spell/14177), and [ForeverDB Improved Kidney Shot](https://foreverdb.net/spell/14174).

## WoW Forever proc, opener and group-support audit - v1.2.4 (October 15, 2026)

All three Forever trees now fall back to Garrote when Stealth is active but Ambush is unusable because of position or weapon requirements. Subtlety consumes an Ambush that the host explicitly marks usable outside Stealth, covering Cutthroat's ten-second proc without guessing its hidden aura. Ghostly Strike is no longer starved by an always-ready Hemorrhage builder and is prioritized for its 180% dagger hit and seven-second dodge bonus, especially against multiple attackers.

Subtlety only spends Rupture when Hemorrhage is learned, its fifteen-second target amplifier is positively visible, and the target is forecast to survive the full sixteen-second bleed. Otherwise it uses Eviscerate, matching the weaker Forever Rupture base damage. Hemorrhage is established before the next eligible long-target Rupture without wasting capped combo points.

On a long grouped boss, five combo points can support the physical group with Forever's strengthened Expose Armor only after a readable debuff snapshot proves that neither Expose Armor nor Sunder Armor is active. It never applies this support finisher in PvP, solo pulls, short-lived targets, or when aura visibility is unavailable. Sources: [ForeverDB current Rogue builds](https://foreverdb.net/class/Rogue/builds), [ForeverDB Ghostly Strike](https://foreverdb.net/spell/14278), [ForeverDB Rupture](https://foreverdb.net/spell/1943), [ForeverDB Backstab and Cutthroat interactions](https://foreverdb.net/spell/53), [Forever Rogue changes](https://foreverdb.net/class/Rogue/changes), and the [official deep-dive mirror](https://foreverdb.net/news/post/forums-us-30378087).

## WoW Forever client-data audit - v1.2.3 (October 15, 2026)

ForeverDB's build 1.60.1.70374 simulation changed several priorities. Slice and Dice is now established with one or two combo points on targets expected to live instead of waiting until five. Combat can use Blade Flurry as a single-target boss cooldown as well as safe two-target cleave; the cleave gate still rejects nearby Sap or Gouge targets. Assassination now distinguishes the learned Deadly Poison coating from its target aura ranks. Five stacks strengthen Coup de Grace, but the simulator still spends Eviscerate whenever it is ready, so the engine no longer idles at capped combo points waiting for a random poison application.

Classic utility semantics are now branch-safe. Forever Feint is used as a threat reduction after pulling a PvE target and is excluded from Retail predictive-damage-reduction rules. Preparation can recover both Vanish and Evasion after they are committed under lethal Arena, Battleground, World PvP, or Delve pressure. Retail's Garrote-silence behavior is explicitly disabled on Forever. Automatic PvP poison selection checks that Wound Poison is learned before choosing it, allowing the current level-30 client to fall back to Deadly or Instant Poison instead of repeatedly requesting an above-cap spell. Automatic healer control resolves the highest learned Sap rank, including rank 2 at level 28, rather than always using the shorter rank 1.

Sources: [ForeverDB Rogue guide and current simulator priorities](https://foreverdb.net/class/Rogue), [ForeverDB Rogue builds](https://foreverdb.net/class/Rogue/builds), [WoW Honor Forever PvP guide](https://wowhonor.com/guides/classes/rogue/), and [WoW Forever Rogue class guide](https://wowforever.gg/en/classes/rogue/).

## WoW Forever verified priority audit - v1.2.2 (October 15, 2026)

The Forever branch now uses the live database ID 1310703 for Venom and removes Eviscerate rank 2 from the Expose Armor family. Assassination maintains Slice and Dice and Venom on durable targets, waits for five positively observed Deadly Poison stacks before Coup de Grace, uses Cold Blood directly before that finisher, and still executes targets that will die before a full poison setup. PvP supports the documented Cheap Shot, Mutilate, four-point Kidney setup without weakening five-point stuns elsewhere.

Combat now reacts to Riposte after a parry, maintains Slice and Dice only when the target will live, gates Blade Flurry behind a safe second target so it does not break Sap or Gouge, and places Adrenaline Rush inside durable pressure. Subtlety targets the enemy with Premeditation, uses it before Cheap Shot in PvP, prioritizes Hemorrhage to amplify Serrated Blades Rupture, and skips long-duration finishers on dying targets. The engine retains only Blade Flurry as its supported cleave because the Forever Rogue has no general-purpose AoE damage rotation.

Client-family detection is cached after its first guarded result. This removes repeated version and spell-book fingerprint calls from combat updates and reduces exposure to unstable native database probes while preserving a hard dispatch boundary between Forever and Retail. Sources: [ForeverDB Rogue guide](https://foreverdb.net/class/Rogue), [ForeverDB Rogue builds](https://foreverdb.net/class/Rogue/builds), [ForeverDB PvP guide](https://foreverdb.net/class/Rogue/pvp?spec=Subtlety), [WoW Forever Venom](https://wow-forever.gg/db/spells/1310703-venom/), [ForeverDB Riposte](https://foreverdb.net/spell/14251), [ForeverDB Blade Flurry](https://foreverdb.net/spell/13877), [ForeverDB Cold Blood](https://foreverdb.net/spell/14177), [ForeverDB Hemorrhage](https://foreverdb.net/spell/16511), and [WoW Forever Rogue guide](https://wow-forever.gg/guides/classes/rogue/).

## Retail three-spec and WoW Forever isolation - v1.2.1 (October 15, 2026)

The single Rogue plugin folder now contains independent Retail/Midnight engines for Assassination, Outlaw and Subtlety plus an isolated WoW Forever engine for Assassination, Combat and Subtlety. The dispatcher detects the client branch before choosing a specialization, and the Forever engine imports only `ar_forever_spells.lua`; it cannot read Retail spell IDs or Retail priority modules. Retail similarly continues through its own three spec engines.

WoW Forever detection uses guarded client/build probes for the 1.60 branch and a new-Mutilate spell fingerprint when build metadata is unavailable. Its tree detector examines active talent names and deep-tree spell fingerprints. Forever priorities were based on beta build 1.60.1.70374 data: Mutilate and poison-linked Eviscerate for Assassination, Blade Flurry/Adrenaline Rush sustained pressure for Combat, and Hemorrhage/Rupture plus stealth openers for Subtlety. Each tree has separate PvE, dungeon/Mythic-equivalent, delve/solo, Arena, Battleground and World PvP entry points.

## Framed icon controls - v1.1.96 (October 14, 2026)

The customer interface now uses layered image-button frames, illuminated selected navigation, framed Rogue ability artwork, sliding on/off controls, dedicated hotkey displays, and bordered previous/next controls. This brings the settings rows closer to the supplied premium-suite reference while retaining the embedded-Lua asset requirement and the unique accent theme for every Rogue section.

## Themed customer interface - v1.1.95 (October 14, 2026)

The main window now uses a Valeera-themed Rogue suite shell with a permanent vertical navigation rail, a wide settings workspace, mode and profile status controls, and a compact persistent footer. Every section has its own visual identity: poison-green PvE, crimson PvP, bleed-green Rotation, violet Control, amber Survival, blue Utility, teal Gathering, orange Boss Tools, cyan Hotkeys, silver Display/Logs, and red Core safety.

The redesign preserves the Rogue-specific options, six activity profiles, embedded spell icons, editable hotkeys, saved logs, debugger controls, and Lua-embedded artwork. Interactive regions were resized and aligned with the larger layout so switches, scrolling rows, hotkey pills, shortcuts, and log actions share consistent click targets.

## Major-city practice dummies - v1.1.94 (October 14, 2026)

Practice mode now relies first on Project Sylvanas' locale-independent `unit_helper:is_dummy()` classification, covering capital-city and expansion-hub dummies without maintaining a fragile English NPC-name list. Selected damage dummies continue to run the complete opener, sustained rotation, cooldown and defensive test paths. Dungeoneer/Cleave dummies select Mythic+ logic, PvP/Competitor dummies select Arena logic, Delve-labeled dummies select Delve logic, and general/Raider dummies select PvE logic.

An optional **Nearby city dummy target** switch and hotkey can acquire the closest visible damage dummy within 30 yards while the Rogue is stationary, unmounted and out of combat. Healing dummies are excluded. The feature only runs in a host-confirmed city/rest area, records a `DUMMY_TARGET` diagnostic, and preserves the existing safety rules outside practice sessions.

## Customer GUI and hotkey expansion - v1.1.93 (October 14, 2026)

The Valeera interface now uses eleven focused tabs: PvE Damage, PvP/Control, Rotation, Control, Survival, Utility, Gathering, Boss Tools, Hotkeys, Display/Logs, and Core. Every global option and all five settings for each of the six activity profiles retain an independent on/off switch and receive a persistent optional Project Sylvanas keybind. Clicking a key pill starts capture; Escape clears it. Unbound entries are removed from the runtime polling list, assigned keys toggle only once per press, and key processing pauses while a text box is focused.

The native Project Sylvanas settings tree also renders each keybind so customers can configure the same bindings through the host menu. This follows the documented rule that menu objects must be constructed once outside render callbacks and uses the supported `get_key_code`/`set_key_code` persistence API.

## Lag and frame-time audit - v1.1.92 (October 14, 2026)

The adaptive profiler used `os.clock`, but the live Project Sylvanas host does not expose that Lua library. Every sample therefore read `0.00 ms`, so the adaptive tier never activated. It now measures real callback duration with the documented millisecond `core.game_time()` clock and falls back to `core.time()` on older hosts. Measured slow callbacks progressively reduce rotation polling from 12.5 to 10 or 7.1 evaluations per second, full object scans from 2 to 1.3 or 1 per second, visual queries, and state logging. Normal tier retains the existing 80 ms combat cadence.

The persistent logger previously rewrote as much as 1.5 MB every three seconds. The full append-only session log remains intact, while the crash-recovery snapshot is now a 512 KiB rolling tail rewritten at most every ten seconds and force-written on logout/world-leave. Menu checkbox reads are cached for 250 ms and stale cast-failure cleanup runs every five seconds. These changes follow Project Sylvanas' guidance to keep game logic out of render callbacks, cache comprehensive object scans, use 500 ms object-cache refreshes, validate live pointers, and prefer numeric loops on arrays.

## Target-isolated cast recovery - v1.1.91 (October 13, 2026)

The failure system previously combined a spell-and-target circuit breaker with a second global spell retry. A failed Garrote, Mutilate, Rupture, Envenom, or Shadowstep on one unit could therefore make the same spell appear unavailable against every other unit for up to two seconds, delaying valid swaps, interrupts, returns, and bleed spread. Recovery is now keyed only by spell plus target. The first two failures receive short 0.25/0.5-second holds; three or more failures open the existing multi-second circuit. A confirmed cast clears only its own target key, and stale entries still expire after 60 seconds.

## Host cast-error attribution - v1.1.90 (October 13, 2026)

The retained v1.1.77 log contains 91 failed Mutilates, 78 failed Garrotes, 31 failed Shadowsteps, 28 failed Envenoms, and 28 failed Ruptures. Those rows preserved the plugin's intended reason but discarded the host's `UI_ERROR_MESSAGE`, making facing, range, resource races, invalid targets, and other rejection causes indistinguishable. Pending casts now capture the exact host message in a `CAST_ERROR` event and repeat it as `host_error` on the final `FAILED` row. Unassociated UI errors remain visible as `UI_ERROR`, and the existing target-specific circuit breaker still limits retries.

## Crimson Tempest copied-bleed memory - v1.1.89 (October 13, 2026)

Crimson Tempest is self-cast, so the ordinary confirmation path previously associated it only with the Rogue and could not remember the Garrote and Rupture it copied to nearby enemies. If those secondary debuffs were protected or temporarily unreadable, `spread_needed` remained true and the profile could request another Tempest. A confirmed Tempest now snapshots the already validated safe combat enemies within ten yards and carries forward only positively known primary bleed durations. Unknown durations remain unknown, controlled or protected units are excluded, and a `BLEED_SPREAD` row reports what was remembered.

This follows the current [Method 12.1.5 rotation](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation), which uses Crimson Tempest to spread bleeds to all targets in AoE, and the current [Icy Veins 12.1 overview](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide), which describes Crimson Tempest as the AoE bleed-spread builder.

## City World PvP Stealth engagement guard - v1.1.88 (October 13, 2026)

The automatic Stealth city exception now requires an active duel or a selected hostile player already confirmed in combat. Merely auto-detecting or selecting World PvP while idle in a capital no longer bypasses the city block. The audit also found that the old `city_block and false or safe_check()` expression could never preserve a false result under Lua's `and`/`or` semantics, so even a correctly detected city fell through to Stealth. The gate now uses an explicit branch. Training dummies retain their explicit practice exception, and actual Arena/Battleground instances remain unaffected. A runtime regression reproduces an idle, noncombat World PvP target inside a detected city and proves no Stealth request occurs.

## Patch 12.1.5 PvE Shiv correction - v1.1.87 (October 13, 2026)

The PvE, Mythic+, and Delve damage profiles no longer use Shiv as a routine Toxic Stiletto builder. The single-target Darkest Night path also uses Mutilate instead of spending a utility global on Shiv; Fan of Knives remains eligible when it can build through real cleave. Confirmed Enrage removal still has priority in supported PvE content, and PvP retains Shiv for poison/Hemotoxin pressure.

This follows the current [Method 12.1.5 rotation](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation), which lists Mutilate/Ambush as single-target builders and Fan of Knives for multiple targets, and the current [Icy Veins 12.1 overview](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide/), which describes Shiv as utility-only rather than part of the damage rotation. [Wowhead's current rotation analysis](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) likewise finds routine Shiv usage to be a damage loss outside narrow talent-specific simulation conditions.

## October 11, 2026 Adaptation and racial CC-break memory - v1.1.68

- Opponent memory now distinguishes manual Gladiator's Medallion (336126/legacy 42292), Human Will to Survive (59752), and Adaptation proc variants (336135/336145). Adaptation receives its documented fixed 60-second cooldown; Will to Survive records the 90-second shared break lockout; Medallion remains role-aware at 90 seconds for healers and 120 seconds for damage dealers.
- Kill-target scoring, healer-control scoring, Blind chaining, Smoke Bomb value, and telemetry consume the same break record and identify its kind. This avoids treating Adaptation as a normal two-minute Medallion or missing its automatic break entirely.
- Sources: https://warcraft.wiki.gg/wiki/Adaptation, https://warcraft.wiki.gg/wiki/PvP_medallion, https://www.wowhead.com/spell=336145/adaptation, https://warcraft.wiki.gg/wiki/Every_Man_For_Himself

## October 11, 2026 role-aware PvP trinket timing - v1.1.67

- The fixed 90-second opponent trinket assumption is replaced with role-aware timing: 90 seconds for healer specializations and 120 seconds for damage dealers. Target scoring, healer-control scoring, Smoke Bomb value, kill targeting, and Blind chaining now consume the same memory.
- The old direct Blind check only remembered a healer trinket for 60 seconds; it now uses the complete healer window. STATE telemetry exposes both kill-target and control-healer trinket time remaining.
- Sources: https://warcraft.wiki.gg/wiki/PvP_trinket, https://warcraft.wiki.gg/wiki/Patch_10.2.0, https://warcraft.wiki.gg/wiki/PvP_medallion

## October 11, 2026 complete immunity/racial bleed recovery - v1.1.66

- The event-driven bleed recovery system now covers Stoneform (20594), Fireblood (265221), Divine Shield (642), Ice Block (45438), and targeted Blessing of Protection (1022), in addition to Cauterizing Flame and Mending Bandage.
- Every confirmed removal immediately invalidates stale Garrote, Rupture, Deathmark, and Kingsbane state. Reapplication begins immediately after Stoneform/Fireblood, but waits through the verified 8-second Divine Shield and 10-second Ice Block/Blessing of Protection immunity windows.
- Sources: https://warcraft.wiki.gg/wiki/Stoneform, https://warcraft.wiki.gg/wiki/Bleed, https://warcraft.wiki.gg/wiki/Divine_Shield, https://warcraft.wiki.gg/wiki/Ice_Block, https://warcraft.wiki.gg/wiki/Blessing_of_Protection

## October 11, 2026 targeted bleed-cleanse recovery - v1.1.65

- Enemy Cauterizing Flame (374251) and Mending Bandage (212640) casts are now attributed to their actual recipient. The event invalidates local Garrote, Rupture, Deathmark, and Kingsbane assumptions even when hostile aura visibility remains stale or protected.
- A three-second recovery state rebuilds missing Garrote and Rupture from confirmed plugin casts before allowing the normal burst engine to regard bleeds as established again. Telemetry records the cleanse spell and each forced recovery requirement.
- Sources: https://warcraft.wiki.gg/wiki/Cauterizing_Flame, https://warcraft.wiki.gg/wiki/Bleed, https://www.wowhead.com/spell=374251/cauterizing-flame, https://www.icy-veins.com/wow/survival-hunter-pvp-talents-and-builds

## October 11, 2026 Arena healer-save memory - v1.1.64

- The opponent-memory engine now records which enemy healer spent a major external and exposes a conservative 30-second “save recently spent” opportunity. It does not claim the healer is out of saves because Pain Suppression, Time Dilation, Blessing talents, and other modifiers can supply charges or cooldown reductions.
- A recently spent save adds modest next-go pressure; it never replaces the required energy, combo points, bleeds, target setup, or control. An external still active on the kill target now blocks kill-window creation as well as Deathmark/Kingsbane execution.
- Sources: https://warcraft.wiki.gg/wiki/Pain_Suppression, https://warcraft.wiki.gg/wiki/Ironbark, https://warcraft.wiki.gg/wiki/Life_Cocoon, https://warcraft.wiki.gg/wiki/Time_Dilation, https://warcraft.wiki.gg/wiki/Just_in_Time, https://warcraft.wiki.gg/wiki/Patch_12.0.5

## October 11, 2026 Arena external-aware swapping - v1.1.63

- Targeted external memory now also recognizes Guardian Spirit (47788, 10 seconds), Time Dilation (357170, 8 seconds), and Blessing of Protection (1022, 10 seconds). Ray of Hope was deliberately excluded because it was removed in Patch 12.0.0.
- Automatic PvP targeting applies the same penalty to an observed external that it already applied to a personal defensive. A second enemy still must beat the current target by 25 score points and remain the candidate for 0.65 seconds, preventing a healer save from causing an immediate or unstable swap.
- Arena reset state explicitly reports an enemy healer external. Major cooldowns remain held while sustained pressure, control, and a qualified target swap remain available.
- Sources: https://warcraft.wiki.gg/wiki/Guardian_Spirit, https://warcraft.wiki.gg/wiki/Time_Dilation, https://warcraft.wiki.gg/wiki/Blessing_of_Protection, https://warcraft.wiki.gg/wiki/Ray_of_Hope_(priest_PvP_talent), https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/

## October 11, 2026 Arena external-save awareness - v1.1.62

- Enemy casts of Pain Suppression (33206, 8 seconds), Ironbark (102342, 12 seconds), Blessing of Sacrifice (6940, 12 seconds), and Life Cocoon (116849, 12 seconds) are now remembered on the actual hostile recipient supplied by the cast callback.
- Arena burst resources, Deathmark, and Kingsbane wait through a confirmed external on the kill target while ordinary bleed pressure continues. Externals cast on another enemy do not suppress the selected target's go. Target scoring and STATE telemetry expose the active save and remaining duration.
- Sources: https://warcraft.wiki.gg/wiki/Pain_Suppression, https://warcraft.wiki.gg/wiki/Ironbark, https://warcraft.wiki.gg/wiki/Blessing_of_Sacrifice, https://warcraft.wiki.gg/wiki/Life_Cocoon, https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle

## October 8, 2026 Shadowstep Kick control chain

- Current Season 2 PvP guidance identifies Shadowstep plus Kick as the Rogue's ranged healer interrupt. Version 1.1.25 requires two confirmed Step charges, a live interruptible healer cast within 25 yards, line of sight and healer-tether safety, then returns to the unchanged kill target after the confirmed Kick: https://www.icy-veins.com/wow/assassination-rogue-pvp-guide, https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle

## October 8, 2026 Unshakeable Drive Mythic+ builder

- Current 12.1 Mythic+ guidance uses Fan of Knives in single target with the dungeon build until Unshakeable Drive reaches three visible stacks, then Mutilate consumes the empowerment. Version 1.1.24 follows that priority only with positively observed stack data and preserves the AoE crowd-control safety gate: https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps, https://www.wowhead.com/spell=1248775/unshakeable-drive

## October 8, 2026 Airborne Irritant cast-stop support

- Current 12.1 Rogue guidance identifies Airborne Irritant (200733) as a strong Mythic+ talent because Blind can interrupt multiple nearby enemies. Version 1.1.20 prefers it over single-target Kick only for two or more clustered, stoppable, non-boss casts and retains the plugin's existing AoE safety gate: https://www.wowhead.com/guide/classes/rogue/assassination/abilities-talents-pve-dps, https://www.wowhead.com/spell=200733/airborne-irritant

## October 8, 2026 Thick as Thieves burst coordination

- Current 12.1 PvP guidance calls Thick as Thieves a strong offensive option that turns Tricks of the Trade into a teammate damage buff for securing kills. Version 1.1.19 requires the selected PvP talent, a host-confirmed non-healer teammate burst aura, range, line of sight and an active kill window before casting: https://www.icy-veins.com/wow/assassination-rogue-pvp-talents-and-builds, https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/talents/, https://www.wowhead.com/spell=221622/thick-as-thieves

## October 8, 2026 guarded Tricks of the Trade support

- The current Season 2 Mythic+ guide lists Tricks of the Trade as the default utility choice but warns that it does not protect the Rogue's first hit from Stealth and has limited value once threat is secure. Version 1.1.18 casts spell 57934 only after a hostile target is observed attacking a confirmed friendly tank in grouped PvE or Mythic+: https://www.wowhead.com/guide/classes/rogue/assassination/mythic-plus-dungeon-tips, https://www.wowhead.com/spell=57934/tricks-of-the-trade

## October 8, 2026 Season 2 predictive-defense expansion

- The current Season 2 Mythic+ guide explicitly recommends Feint for Ravenous Stomp, Thorncaller Roar, Ravenous Bellow, Insidious Aura, Steel Barrage, Frost Overload, Molten Blood and Inferno. Version 1.1.17 maps both the exact English timer labels and verified spell IDs into the BigWigs/ExBoss AoE prediction table so Feint can be used before impact: https://www.wowhead.com/guide/classes/rogue/assassination/mythic-plus-dungeon-tips
- Verified spell records used for the new rules include Ravenous Stomp 1307915, Thorncaller Roar 1236709, Ravenous Bellow 1234681, Insidious Aura 1234855, Steel Barrage 372047, Frost Overload 373680, Molten Blood 392569 and Inferno 373692.

## October 8, 2026 Improved Garrote cooldown-order correction

- Current 12.1 single-target guidance places Vanish and its empowered Garrote immediately before Deathmark, followed by Kingsbane. Version 1.1.16 corrects the previous Deathmark-first order and makes a confirmed offensive Vanish reserve the next eligible global for Garrote: https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps, https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities

## October 11, 2026 Arena live damage correction - v1.1.55

- A v1.1.54 Arena run ended with replay grade 72: 22 samples, 18 casts, four failures, six Rupture-down samples, two combo-cap samples, one CC opportunity with no CC cast, and two burst-ready samples. The live sequence showed a failed opener Rupture followed by repeated `waiting for opener Rupture`, plus an adaptive target swap while Subterfuge was active that still logged `OPENER_RESET`.
- All in-combat PvP swaps now use maintenance/finisher priorities even during Subterfuge. If opener Rupture is rejected at capped points, it spends Envenom rather than idling and resumes bleed setup on the next eligible cycle. Garrote retains its short failure backoff to avoid rejected-request spam.
- Deathmark had already been spent in the observed run and Kingsbane entered cooldown later, so the verified loss was opener retry downtime rather than a missing major-cooldown implementation.

## October 11, 2026 Arena damage-log correction - v1.1.54

- The retained Arena sequence repeatedly reset to `opener: Garrote` and `opener: Rupture` after in-combat target changes, replacing normal finishers and kill pressure with fresh opener setup. Mid-combat PvP swaps now use maintenance priorities unless Stealth/Subterfuge is genuinely active.
- The same sequence reported 11 attackers in Arena. Hostile pets and minions were each counted as a full attacker, which repeatedly triggered Feint, emergency peels and survival burst holds. Enemy players now count individually, all pets aggregate to one secondary pressure source, and automatic Kidney/Dismantle peel selection ignores pets. Incoming-health prediction still reacts to their real damage.
- The available history still identifies itself as v1.1.34, so these are code corrections from its telemetry rather than measured v1.1.54 damage results.

## October 11, 2026 Arena setup synchronization - v1.1.53

- New Arena Kidney and major-cooldown setups require at least 2.5 seconds of observed healer control remaining. This avoids opening a fresh six-second kill sequence during the final fraction of Sap, Blind, Gouge or a confirmed healer lockout.
- Once a kill window has started, it continues through its existing target-specific duration. Low-health emergency pressure and explicit burst requests retain their previous exceptions. Telemetry now records secure versus expiring healer control so live logs can validate the threshold.

## October 11, 2026 PvP state-machine audit - v1.1.52

- Confirmed local stun timing now bridges a transient missing native stun aura, so a successful full Kidney can still authorize its guarded Smoke Bomb follow-up.
- Shadowstep control plans now advance to their return phase when a teammate lands control during travel or the off-target becomes invalid after the outgoing Step. This prevents a seven-second action stall beside the healer while preserving the unchanged kill target.
- The retained live history still ends at v1.1.34. It cannot validate v1.1.51 timing until Project Sylvanas is reloaded and a new Arena/Battleground session is recorded.

## October 11, 2026 PvP control audit - v1.1.51

- The current 12.1 Icy Veins PvP guide identifies Sap, Blind, Cheap Shot, Garrote and Dismantle as the core control kit, and specifically recommends using offensive Vanish/Subterfuge globals to silence enemies with Garrote when survival permits. The runtime now uses a guarded off-target Garrote silence during established pressure when the healer is casting or stun DR is unavailable. It still requires Stealth/Subterfuge, line of sight, no immunity, no existing breakable control and no existing Garrote.
- Project Sylvanas may return no explicit enemy combat or DR value during arena preparation. A fresh, never-locally-controlled target can now qualify for the automatic opener Sap when both sides are out of combat and every other Sap safety gate passes. After any locally observed control, readable incap DR is required again. Sap's native combat restriction remains the final stale-state safeguard.
- The audit retained full Kidney, Blind/Gouge chaining, Shadowstep-out/control/Shadowstep-back, target-swap hysteresis, healer tether checks, defensive prediction, Smoke Bomb, Dismantle and Battleground auto-engagement. No live v1.1.50 match was present in the retained session log, so match effectiveness remains a live-testing question rather than a claimed result.

Source: https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle (updated August 10, 2026 for Midnight Season 2).

## October 8, 2026 PvP defensive-memory update

- Current live spell records confirm Anti-Magic Shell (48707, 5 seconds), Blur (198589, 10 seconds), Touch of Karma (122470, 10 seconds), and Fortifying Brew (115203, 15 seconds). Version 1.1.11 records these observed casts as active defensive windows so automatic Deathmark/Kingsbane decisions do not commit into known mitigation or absorbs: https://www.wowhead.com/spell=48707/anti-magic-shell, https://www.wowhead.com/spell=198589/blur, https://www.wowhead.com/spell=122470/touch-of-karma, https://www.wowhead.com/spell=115203/fortifying-brew

## October 8, 2026 Deathstalker target-transfer update

- Patch 12.0.5 added Mark for Death (1293340), a 25-Energy, 10-yard, 20-second off-global ability that moves an existing Deathstalker's Mark. Current rotation guidance calls it out for priority adds and target switches. Version 1.1.13 uses it only with observed off-target mark evidence and a durable committed destination: https://www.wowhead.com/spell=1293340/mark-for-death, https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities

## October 8, 2026 Shiv correction

- Current 12.1 guidance states that Shiv no longer grants bonus damage and serves as utility/Soothe. Toxic Stiletto (1267182) only reduces its Energy cost and cooldown and increases its range. Version 1.1.14 removes the old PvE combo-point filler use while preserving Enrage removal and PvP poison utility: https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide, https://www.wowhead.com/spell=1267182/toxic-stiletto

- The dedicated current 12.1 priority adds the missing efficiency context: Deathstalker with Toxic Stiletto uses Shiv on cooldown in single target because its reduced cost makes it the most efficient combo-point generator, but stops doing so when adds make Fan of Knives more efficient. Version 1.1.15 implements that narrower rule in PvE, Mythic+ and Delve: https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps

## October 8, 2026 audit

- Wowhead's current 12.1 priority confirms the implemented main-target Garrote/Rupture maintenance, Crimson Tempest bleed spreading below the finisher threshold, Fan of Knives at two or more targets, Envenom priming, and Deathmark into Kingsbane alignment. Version 1.0.91 extends Thistle Tea preparation to every mode while preserving Envenom priming before PvE cooldowns: https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps
- Icy Veins confirms that Mythic+ damage is built around even multi-target bleed setup followed by focused finishers. The existing safe spread and multidot priorities remain consistent: https://www.icy-veins.com/wow/assassination-rogue-pve-dps-mythic-plus-tips
- ArenaCoach's October 8 live data identifies long-unused Kidney Shot and Blind as common lost-momentum errors. Version 1.0.91 measures each spell's uninterrupted ready time and uses conservative readiness-age fallbacks while retaining DR, immunity, DoT, range, line-of-sight and cooldown-alignment gates: https://arenacoach.gg/guides/assassination-rogue-pvp-guide-midnight-season-2
- Method's current guide describes Assassination as a resource-planning specialization and confirms Crimson Tempest's builder/spreader role. The audit therefore favors energy preparation and avoids adding a conflicting fixed sequence: https://www.method.gg/guides/assassination-rogue



The supplied Arena dummy excerpt shows successful builders, bleeds and finishers but no major cooldown requests. A newer live session confirms Deathmark at 25235.48 and Kingsbane at 25236.43; subsequent entries show their cooldowns. This proves the updated PvE dummy path can cast them, not a measured DPS increase or real Arena performance.



## Sources rechecked



| Source | Use |

|---|---|

| [Method rotation](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) | Opener, bleeds, cooldown pairing and hero finishers. |

| [Method talents](https://www.method.gg/guides/assassination-rogue/talents) | Crosschecked Apex and hero differences. |

| [Wowhead rotation](https://www.wowhead.com/ptr/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) | Resource efficiency and differing Shiv recommendations. The retrieved page is marked PTR. |

| [Wowhead builds](https://www.wowhead.com/guide/classes/rogue/assassination/talent-builds-pve-dps) | Dungeon and Delve builds; solo survival changes cooldown policy. |

| [Icy Veins PvE](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities) | Envenom timing, point-based bleed refresh and resource recovery. |

| [Icy Veins PvP](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) | Healer control, stuns and burst opportunities. |

| [Icy Veins Battlegrounds](https://www.icy-veins.com/wow/assassination-rogue-battleground-blitz-pvp-guide) | Spread pressure and disruption; objective navigation is outside this plugin. |

| [Skill Capped talents](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/talents/) | Hemotoxin, Preemptive Maneuver and control roles; its build section warns updates remain underway. |

| [ArenaCoach Season 2](https://arenacoach.gg/guides/assassination-rogue-pvp-guide-midnight-season-2) | Mistake categories and defensive context. Conflicting patch labels prevent using its numbers as a rotation specification. |

| [SimulationCraft Midnight APL](https://github.com/simulationcraft/simc/blob/midnight/engine/class_modules/apl/rogue/assassination.simc) | Crosschecked cooldown preparation and resource timing; branch assumptions are not unconditional PvP rules. |

| [Dalaran Gaming video](https://www.youtube.com/watch?v=lFJw787T2Do) | Located the current guide and rotation chapter; reviewed accessible metadata, not a full video transcript. |

| [Recent Reddit burst discussion](https://www.reddit.com/r/worldofpvp/comments/1wec9sf/burst_damage_for_assn_rogue/) | Identified questions to crosscheck; anecdotes are not validation. |



## Corrections



Tea follows actual maximum Energy. PvE Envenom can pool while its buff remains, with spending exceptions for overflow, burst and short fights. Deathmark considers Kingsbane alignment and poison preparation. Kingsbane's large point gain checks the exact final Apex spell rather than every Implacable rank. [Spell record](https://www.wowhead.com/spell=1265387/implacable).



Rupture refresh timing follows the points spent. The Darkest Night exception was corrected in v1.0.44 below. Fatebound PvE no longer uses unconditional Shiv filler. Melee uses the host's attack-range result. Observed healer control can open a go after Kidney on that healer; training does not need a simulated CC window. Logs expose readiness blockers and selected talents.



## Limits



This is a broad recheck, not every website. Sources disagree or retain old/PTR sections. Controlled dummy comparisons with unchanged talents/gear are needed to measure DPS. Real PvP and protected aura/DR data remain unverified. Situational utilities such as Shroud, Distract, Tricks, lockpicking, Pick Pocket, racials, items and Death from Above still lack automatic policies; complete all-skill automation is not claimed.





## October 3, 2026 PvP recheck — v1.0.34



The submitted v1.0.26 run contains zero cast requests: damage engagement never armed and melee range was false. It cannot measure rotation output or defensive effectiveness. These are code corrections inferred from current guidance, not a measured DPS gain.



[Icy Veins, NoTrickz, 12.1](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): verified healer control and target-stun sequencing, Rupture-first sustained maintenance, Mutilate preference, Implacable Kingsbane following Kidney, and preemptive Feint. Applied: confirmed PvP CC windows bypass mandatory pre-Envenom; low-point Kingsbane can refill points; avoid early bleed refresh during a go; prioritize expiring Rupture; ordinary stealth uses Mutilate; retain Blindside; remove generic PvP Shiv filler. Darkest Night's one-point Fan fallback now requires AoE safety. Elusiveness alone can pre-Feint a verified incoming stun. Existing healer/control-target protection remains stricter than general cleave recommendations to preserve CC.



[Method, Whispyr, 12.1](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation): crosschecked 5-point finishers, 7-point Darkest Night and cooldown alignment. [Wowhead rotation](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps): Deathstalker Shiv filler requires Toxic Stiletto. [Toxic Stiletto spell record](https://www.wowhead.com/spell=1267182/toxic-stiletto): confirmed ID 1267182; native talent selection controls eligibility.



[Skill Capped](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/) supports sustained bleed pressure and recurring Kidney setups. [ArenaCoach Season 2](https://arenacoach.gg/guides/assassination-rogue-pvp-guide-midnight-season-2) was reviewed for matchup context; conflicting patch labels and aggregated figures are not spell-priority rules. Reddit discussions were searched as leads only; old expansion advice was excluded.



YouTube research: [Dalaran Gaming 12.1](https://www.youtube.com/watch?v=lFJw787T2Do&t=385s), published August 15, includes a rotation chapter at 6:25. [Shindigg Midnight guide](https://www.youtube.com/watch?v=v5YsyRXp_aM), published March 15, lists opener, pooling and hero-talent chapters. [Javier Season 2](https://www.youtube.com/watch?v=aAR5XOEqq8c), published August 15, describes a Raid/M+ guide. Accessible descriptions and chapter metadata were reviewed; full transcripts/video playback were unavailable. No unverified video claim was translated into a PvP rule.



## 1.0.35: F��� build comparison

The Pvplog profile lists Fatebound, Iron Wire, Internal Bleeding, Elusiveness and two ranks of Implacable. It provides ladder snapshots rather than cast timelines. Observed Garrote silence (1330) now counts as healer control only with more than 1.5 seconds remaining; Blind/Gouge chain checks preserve it until its final 0.7 seconds. Existing Elusiveness and exact Kingsbane-gain checks remain. No build or cast sequence is inferred from ladder rating.

Sources: https://pvplog.com/retail/eu/ravencrest/F%C3%AD%C3%B1%C3%B1 and https://www.wowhead.com/spell=1330/garrote-silence

Pikaboo channel search surfaced https://www.youtube.com/watch?v=PXpFq_HiQvA (Season 2 Assassination build); transcript export returned unavailable. No spoken advice from that video is claimed or applied.



## October 5, 2026 audit - v1.0.44

The current live session.md contains only a v1.0.38 startup entry. It cannot establish a damage gain or a CC failure. These changes correct priorities and state accounting; actual match performance remains to be measured.

- [Wowhead live 12.1 rotation](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps): outside the opener, preserve Darkest Night points for empowered Envenom even when Rupture is missing. The opener exception remains.
- [Icy Veins PvP rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): offensive Dismantle against Death Knights and Arms Warriors denies weapon-dependent survival. Added only during a confirmed kill window with established bleeds and a disarmable target, retaining range and cast eligibility checks.
- Initial object enumeration now deduplicates GUIDs, preventing duplicate units from inflating nearby-target and attacker counts.

Crosschecks: [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) for cooldown alignment and finishers; [Skill Capped](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/) for bleed pressure and repeated control setups. [Dalaran Gaming Season 2 starter guide](https://www.youtube.com/watch?v=vn9QRw-zkoo): reviewed the available auto-generated Assassination transcript segment, reinforcing Crimson Tempest spreading from established bleeds, preemptive Feint and situational Dismantle. Those spreading and defensive policies already exist; transcription errors and gear advice were not translated into spell rules. [Reddit Season 2 discussion](https://www.reddit.com/r/worldofpvp/comments/1vra0ne/rogue_in_season_2/) supplied resource-pressure and bleed/control leads, not authoritative mechanics. Google searches supplied discovery leads. Existing source coverage was revisited selectively, not every page or video.

All 367 behavior assertions pass, including Darkest Night with absent Rupture and offensive Dismantle eligibility guards. All six activity profiles retain their separate decisions, predictive defenses, PvP-only engagement arming and healer/focus CC protection.

## Follow-up audit - v1.0.45

Reviewed the six damage profiles, runtime defense/control order, Step-CC confirmation sequence, gathering/Stealth guards and the current live log. The log still contains only a v1.0.38 startup entry; match effectiveness cannot be assessed.

Two PvE timing corrections: refresh Envenom within its final two seconds rather than waiting until one second; require more than two seconds of a readable Envenom buff before Deathmark. Kingsbane and confirmed PvP windows retain their existing eligibility. This follows [Wowhead's Envenom-chain guidance](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) and [SimulationCraft's Deathmark priming condition](https://github.com/simulationcraft/simc/blob/midnight/engine/class_modules/apl/rogue/assassination.simc). SimulationCraft is a PvE reference, not a PvP specification; it also differs from Wowhead on missing Rupture during Darkest Night, so that existing guide-based policy was retained.

Rechecked Method, Icy Veins and the public Skill Capped guide. Fresh YouTube and Reddit searches supplied leads, including a Season 1 LudiDeo video; older advice was not applied as Season 2 mechanics. The previously available Season 2 Dalaran transcript remains the verified video crosscheck. No claim to watching all videos or reviewing every site is made. Five new assertions cover expiring/healthy Envenom buffs and preserving immediate confirmed PvP burst. Total: 372 passing behavior assertions.

## Full audit follow-up - v1.0.47 (October 5, 2026)

Latest live log reviewed: logger v1.0.45, 61 idle PvE state samples, no combat runs or cast requests. All were outside combat with no attackable target; 41 selected the player and 20 had no target. This is not a DPS/CC/defensive comparison and indicates the host had not loaded the newer release.

Implemented corrections:
- Confirmed offensive PvE Vanish reserves one Improved Garrote refresh on its original kill target for six seconds. Capped points are spent first. Only a successful Vanish confirmation starts the latch; a successful Garrote consumes it. [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) support Vanish followed by Improved Garrote.
- Native aura expire_time is recognized, and direct cached get_buff_data/get_debuff_data queries use their documented millisecond duration. Positive native stun state supplements the older aura list. [Buff API](https://docs.project-sylvanas.net/dev/api/buffs/), [IZI object extensions](https://docs.project-sylvanas.net/dev/libraries/izi/izi-object-extensions/).
- Breakable CC checks now inspect foreign debuffs rather than treating CC duration reduction as a DoT classifier. Native buff_id/debuff_id fields and known harmless slows/control are handled. [PvP helper](https://docs.project-sylvanas.net/dev/libraries/mini-libs/pvp-helper/).
- Interrupt logic includes channels. Non-interruptible casts/channels can receive a Kidney stop only with confirmed CC eligibility, sufficient points and a non-boss target. Unknown interruptibility does not authorize this fallback. Channel forecasting uses the channel end/spell getters documented in the installed host API.
- Legacy helper calls retain priority, with native DR, disarm and burst fallbacks when unavailable. DR values above 1.01 are rejected as untracked. Sprint respects its zero GCD, while mobility safety gates remain.
- Fixed Display/Logs overlapping Utility and the missing next-spell HUD glyph. Valeera stays embedded in Lua; hidden fallback artwork is skipped once its texture is cached. Gathering skips disabled-feature scans and reuses the runtime object list when enabled.

Research coverage includes current Method, Wowhead, Icy Veins, public Skill Capped content, Google discovery, the actual auto-generated [Dalaran Season 2 video transcript](https://www.youtube.com/watch?v=vn9QRw-zkoo), and [current Reddit discussion](https://www.reddit.com/r/worldofpvp/comments/1vra0ne/rogue_in_season_2/). Video spreading/Feint/Hemotoxin advice mostly matches existing logic. Reddit opinions and Google AI summaries were not used as spell specifications. Defensive Smoke Bomb and Thick as Thieves remain research leads requiring ally-position/burst policy. Talent-aware fallback timers need a separate verified duration audit; actual native timers are now preferred. The global pending-cast latch remains conservative; bypassing it for emergency off-GCD spells requires a separate confirmation-tracking design.

Validation: 22 Lua files parse; 400 behavior assertions pass, including channel interrupts across all six modes, native aura timing, safe Sap DR fallback, foreign-debuff CC safety, offensive Vanish confirmation, GUI/HUD placement and avoiding duplicate gathering scans. These tests do not establish measured DPS or live frame-time gains.

## Full audit follow-up - v1.0.48 (October 6, 2026)

Current 12.1 sources were rechecked through Google discovery, Wowhead, Icy Veins, Method, Skill Capped, YouTube and Reddit. [Wowhead's cooldown detail](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) says to use the full six-second Improved Garrote window and refresh Garrote near its end; the old latch cast Garrote immediately after confirmed Vanish. The latch now waits until 1.5 seconds remain, while still casting early if Garrote is absent or expiring. [Icy Veins](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities) independently lists the second empowered Garrote and Deathmark/Kingsbane sequence.

[Skill Capped's current Season 2 guide](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/) continues to emphasize bleed pressure, Kidney and control. Current and recent Reddit discussions consistently supplied the Sap-healer-then-pressure lead; after the plugin confirms healer control, Arena, Battleground and World PvP now open Garrote on the kill target rather than redundantly using Cheap Shot first. Cheap Shot remains the fallback when off-target healer control is absent. Reddit and video material were treated as leads and only translated into rules that agree with current mechanics sources and existing safety checks.

The current Icy Veins Deathstalker priority still lists Shiv on cooldown, while Wowhead describes build-dependent gains and losses. The existing Toxic Stiletto gate and special six-to-seven Darkest Night builder were retained rather than applying an unconditional Shiv change. Public YouTube searches did not expose a newer verifiable Season 2 transcript than the Dalaran transcript already documented in v1.0.47; no inaccessible spoken claim was inferred.

## Arena late-game follow-up - v1.1.69 (October 12, 2026)

The runtime now reads the real Dampening aura (110310) and its exposed stack count. It does not infer stacks from elapsed match time because bracket start/ramp rules can change and secret aura data can be unavailable. At 30 or more positively observed stacks, a damaged target becomes a higher-value pressure target and a confirmed full stun can open a wider kill window. Unknown stacks preserve the normal thresholds. [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Dampening) documents that each stack reduces healing and absorption by one percent.

Smoke Bomb now waits while an observed target defensive or healer external is active, including both the planned Kidney/Bomb sequence and the opportunistic post-trinket branch. This preserves the three-minute cooldown for a clean isolation window. [Icy Veins](https://www.icy-veins.com/wow/assassination-rogue-pvp-guide) recommends full Kidney Shot plus Smoke Bomb when the target cannot trinket; [Wowhead](https://www.wowhead.com/spell=212182/smoke-bomb) confirms the current five-second, eight-yard targeting denial. Dampening state, stacks and the high-Dampening decision flag are written to session telemetry for live validation.

## Arena healer-cover follow-up - v1.1.70 (October 12, 2026)

Current [Icy Veins PvP talent guidance](https://www.icy-veins.com/wow/assassination-rogue-pvp-talents-and-builds) identifies a second high-value Smoke Bomb use: blocking incoming crowd control on an exposed healer when that control could lose the game. The runtime already identifies enemy casts aimed at friendly healers. It now uses defensive Smoke only when the Rogue is at 35% health or lower, the healer is within the self-centered bomb radius, the caster is outside that radius, the cast is imminent, and Kick cannot reach it. The flag-carrier safeguard remains in force. Every eligibility input is included in session telemetry so live logs can reveal missed or wasteful triggers.

[Skill Capped's current Season 2 talent guide](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/talents/) continues to prioritize Preemptive Maneuver, Smoke Bomb and Hemotoxin. The existing pre-stun Feint, offensive Kidney/Bomb and Shiv healing-pressure rules already cover those recommendations, so this release avoids duplicating them.

## Arena stacked-pressure follow-up - v1.1.71 (October 12, 2026)

The current [Icy Veins 12.1 Arena rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) includes Crimson Tempest after establishing Garrote and Rupture so those bleeds spread to nearby enemies. The plugin already had a guarded PvP spread routine, but Arena never called it. Arena now uses that routine after securing the primary target's bleeds. It remains disabled during kill intent or an active kill window, requires at least two nearby combat enemies, and requires the AoE safety scan to confirm that no breakable control will be hit. This increases stacked-team pressure without sacrificing the current Kidney, healer-control or poison burst sequence.

## Arena Blind-chain follow-up - v1.1.72 (October 12, 2026)

The current [Icy Veins 12.1 Arena playstyle](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) recommends converting a healer's spent trinket into Blind followed by Sap or Kidney for extended control. Confirmed Blind on a healer now arms a short target-specific chain. When that healer actually leaves combat, has no visible damaging debuffs, retains usable Sap DR and remains in line/range, the plugin may reserve Vanish and Sap after Blind expires. The Vanish trade requires at least 70% health, no more than one attacker, and two defensive reserves so it cannot casually sacrifice the Rogue's only escape. [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Sap) confirms that Sap requires Stealth and an out-of-combat target; its [DR reference](https://warcraft.wiki.gg/wiki/Diminishing_returns) supports retaining the existing readable-DR gate. Chain target and remaining time are logged for live review.

## Arena cross-control correction - v1.1.73 (October 12, 2026)

[Icy Veins' current Arena playstyle](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) recommends Kidney Shot on the healer when a teammate supplies the stun on the kill target. The previous automatic in-range and Shadowstep healer-Kidney branches could fire from damage pressure alone. They now require a positively observed stun on the selected kill target. Without that cross-control, Kidney remains available for the kill target. The existing two-charge Shadowstep return, healer tether, full stun DR and safety requirements remain unchanged. The cross-control decision is logged for live review.

## Arena damage-cadence follow-up - v1.1.74 (October 12, 2026)

The current [Icy Veins 12.1 PvP rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) describes repeated damage setups on every Kidney Shot, even when Deathmark and Kingsbane are unavailable. The Arena profile previously allowed Envenom to consume five points immediately before Kidney came off cooldown, delaying that next setup while rebuilding. It now pools five or more points during the final 2.5 seconds of Kidney's cooldown when the kill target has established bleeds and a full stun remains legal. It does not pool into an observed defensive/external, while the target is already stunned, or when the target is at 25% health or lower. This protects repeated-go cadence without withholding execution damage. Kidney cooldown and the wait reason are logged for live timing review.

The burst sequence remains full bleeds, target control, Deathmark, Kingsbane and Envenom, matching the current PvP guide. Existing Thistle Tea preparation and maximum-point Darkest Night handling cover the energy and empowered-finisher requirements described by [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps).

## Arena Kingsbane-uptime follow-up - v1.1.75 (October 12, 2026)

Current [Icy Veins 12.1 rotation guidance](https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities) describes full melee and Envenom uptime during Kingsbane as critical because every poison application increases the active effect. During an unmitigated PvP Kingsbane, the pursuit system may now commit the final Shadowstep charge after the short kill-window flag expires. This still requires at least 65% health, a safe healer tether, line of sight, a target within Step range, no Arena reset, and no observed target defensive or healer external. Normal pressure continues reserving the final charge.

The rotation also uses an available Thistle Tea when active Kingsbane falls below 60% energy, sustaining poison applications and five-point Envenoms before energy starvation. It refuses that resource spend through an observed target defensive or healer external. Kingsbane uptime commitment and its exact mobility/resource reasons are logged for live measurement. The retained live log contains no Arena run newer than v1.1.54, so these current decisions require a fresh match after script reload before their real uptime gain can be measured.

## Arena cooldown-target commitment - v1.1.76 (October 12, 2026)

Both [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) describe Deathmark and Kingsbane as a target-specific aligned damage package. Adaptive PvP scoring previously became free to select another target when the short kill-window latch expired, even while either debuff remained active. It now retains the current target through active Deathmark or Kingsbane when that target remains attackable, unprotected, free of breakable control, within 25 yards and in line of sight. Immunity, fragile control, lost range/line or another invalid target state still permits recovery instead of forcing a dead target lock. The commitment flag is recorded in telemetry.

## Arena offensive-Vanish follow-up - v1.1.77 (October 12, 2026)

The current [Icy Veins 12.1 Arena rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle) includes an aggressive Vanish into Improved Garrote extension after Deathmark and Kingsbane are committed. Arena may now reserve Vanish for an Improved Garrote on the kill target, but only while that target is Kidney-stunned, the healer has at least 2.5 seconds of confirmed control remaining, both primary bleeds are established, and Deathmark or Kingsbane is already active. It refuses the trade through observed mitigation, healer externals, fragile crowd control, unsafe positioning, low energy, personal danger, or when Vanish is the Rogue's only remaining major defensive.

This keeps the added damage inside a real coordinated kill window. It does not automatically spend Cheap Shot into the existing Kidney because doing so could waste stun diminishing returns. Successful execution is recorded as `OFFENSIVE_VANISH` so retained Arena logs can measure whether the extra Garrote converted into pressure without causing avoidable deaths. [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) independently support aligning Vanish-enabled Improved Garrote with the Deathmark/Kingsbane package.

## Arena poison-package correction - v1.1.78 (October 13, 2026)

The retained v1.1.77 Arena log showed Deathmark committed to Amethon while `target_stunned=false`; the kill window had been armed only by a 2.8-second healer Kick lockout. Kingsbane was ready but never cast during the captured v1.1.77 matches. Arena now requires positively observed control on the kill target before the major poison package becomes eligible. The profile continues building points while the healer is controlled, applies Kidney through its earlier setup priority, and only then proceeds with Deathmark, Kingsbane and Envenom.

This directly follows the current [Icy Veins Season 2 PvP sequence](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): off-target healer control, five-point Kidney on the kill target, Deathmark, Kingsbane and Envenom. Current [Method guidance](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead guidance](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) also place Kingsbane immediately after Deathmark. Training-dummy manual burst remains exempt so the complete package can still be tested without an Arena stun target.

## Arena Subterfuge damage chain - v1.1.79 (October 13, 2026)

The guarded kill-target offensive Vanish now continues through the complete aggressive Subterfuge extension documented by the current [Icy Veins Season 2 PvP rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): Improved Garrote, Cheap Shot, then a second Improved Garrote. The chain is target-specific and confirmation-driven. Each successful cast advances one stage; failed casts retry only inside a six-second reservation, and the sequence cancels when the target becomes protected, enters fragile control, leaves melee or line of sight, or the Stealth/Subterfuge state disappears.

Cheap Shot requires positively readable stun diminishing returns of at least 25%, preventing the chain from blindly spending a global into stun immunity. This extension inherits v1.1.77's strict entry requirements: active Deathmark or Kingsbane, a Kidney-stunned kill target, secure healer control, established bleeds, high personal health, low incoming focus and another major defensive beyond Vanish. [Method's current 12.1.5 guide](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) continue to support using Vanish as an Improved Garrote enabler aligned with Deathmark.

## Arena opener-point preservation - v1.1.80 (October 13, 2026)

The shared opener previously required a preliminary Envenom after Garrote and Rupture before allowing the Arena profile to evaluate Kidney. When healer control became secure during that opener, this could consume the five prepared points and delay the coordinated stun and poison package. Arena now exits the shared opener once both primary bleeds are established. Its normal priority can then spend those points on Kidney immediately when healer control is secure; if no setup exists, sustained pressure can still use Envenom through the later spender priority.

This matches the current [Icy Veins Season 2 Arena sequence](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle), which establishes Garrote and Rupture, controls the healer, builds five points, uses Kidney on the kill target, then commits Deathmark, Kingsbane and Envenom. [Skill Capped's Season 2 overview](https://www.skill-capped.com/wowarticles/guides/assassination-rogue-pvp-guide/) likewise emphasizes maintained bleeds and Kidney cadence as the specialization's core win condition.

## Arena ranged-resource correction - v1.1.81 (October 13, 2026)

The retained v1.1.77 sessions contained 129 Poisoned Knife requests, including 45 failed casts, making it the largest source of failed damage requests. The ranged branch previously attempted Knife whenever Mutilate was out of range unless points were already capped or health and Energy were both low. It now uses Poisoned Knife in PvP only when Crippling Poison is missing from the target or Energy has reached at least 80%. When the slow is already active below that threshold, it pools Energy for melee re-entry.

This follows the current [Icy Veins PvP resource guidance](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle), which describes Poisoned Knife as very low damage and recommends it while rooted or slowed only to prevent Energy overcap or when a ranged enemy needs to be slowed. The change preserves the existing combo-point cap, defensive-resource, line-of-sight and confirmed-range gates while reducing low-value requests and leaving more Energy for Mutilate, Shiv and Envenom after reconnecting.

## Arena offensive-Vanish ordering - v1.1.82 (October 13, 2026)

The control engine executes before the damage profile. The initial offensive-Vanish gate accepted either active Deathmark or active Kingsbane, which meant a confirmed Deathmark could start the multi-global Subterfuge chain before Kingsbane, and an active Kingsbane could start it before the Implacable-funded Envenom. The gate now requires a confirmed Envenom buff and active Kingsbane whenever Kingsbane is known. A build without Kingsbane may still extend an active Deathmark after Envenom.

This preserves the documented **Deathmark → Kingsbane → Envenom** core before spending globals on Vanish, Improved Garrote and Cheap Shot. The order is explicit in the current [Icy Veins Season 2 burst rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle), while current [Method](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) and [Wowhead](https://www.wowhead.com/guide/classes/rogue/assassination/rotation-cooldowns-pve-dps) guidance both require Kingsbane immediately after Deathmark and emphasize Envenom uptime during Kingsbane.

## Arena priority-caster reach - v1.1.83 (October 13, 2026)

Several retained v1.1.77 Arena grades recorded three to ten actionable interrupt opportunities but zero or one successful stop. The interrupt engine already triaged casts and delayed Kick to an adaptive late threshold, but its two-charge Shadowstep Kick and return sequence was restricted to enemy healers. It now permits the same sequence for a non-healer only when the cast targets the friendly healer, has a Season 2 priority score of at least 80, or targets the Rogue with at least 10% learned pressure. It still requires two Step charges, a different selected kill target, 25-yard reach, line of sight and a safe healer tether.

This retains a return charge and does not spend mobility on ordinary damage casts. The change supports the current [Icy Veins PvP role guidance](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle), which identifies disruption and cast denial as one of Assassination's two primary Arena jobs, while preserving the guide's emphasis on staying connected to the kill target for damage.

## Delve Vanish isolation - v1.1.84 (October 13, 2026)

The Delve profile explicitly reserves offensive Vanish for solo survival, but the shared non-PvP burst helper did not exclude Delve and could still spend Vanish before Deathmark. Delve is now excluded from that shared offensive-Vanish branch. It continues using Deathmark, Kingsbane, Tea, bleeds and Envenom normally while retaining Vanish for an emergency combat reset or threat break.

This follows the current [Icy Veins PvP playstyle discussion of Vanish](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle), which identifies it primarily as a defensive escape unless conditions justify an offensive trade, and avoids importing the current [Method Mythic+ recommendation](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) to spend Vanish for Improved Garrote into solo Delve survival logic.

## Battleground and World PvP offensive Vanish - v1.1.85 (October 13, 2026)

The shared burst helper previously excluded every PvP mode, while the specialized offensive-Vanish chain existed only in Arena. Battleground and World PvP therefore could not convert a safe confirmed burst window into Improved Garrote pressure. Those modes may now use Vanish before Deathmark when the existing mode-specific go is active, health is at least 80%, no more than one attacker is present, and at least two major defensive reserves are ready. Flag carriers are always excluded. Arena continues using its stricter healer-control chain, and Delve continues reserving Vanish for solo survival.

Successful Vanish confirmation reserves the next Garrote for the same kill target, using the existing six-second confirmation latch. This implements the current [Icy Veins Vanish guidance](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): Vanish is primarily defensive, but a spare charge can be used offensively for Improved Garrote when it is not required for survival. Current [Method guidance](https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation) also identifies Improved Garrote aligned with Deathmark as Vanish's damage purpose.

## Arena three-point opener Rupture - v1.1.86 (October 13, 2026)

The shared opener previously required five combo points before its first Rupture in every mode. Arena now accepts three points for that initial application, producing a 16-second bleed and releasing the state machine to its second Improved Garrote, control and damage priorities without another builder global. PvE, Mythic+ and Delve retain the five-point opener requirement.

This matches both current opener variants in the [Icy Veins Season 2 PvP rotation](https://www.icy-veins.com/wow/assassination-rogue-pvp-rotation-and-playstyle): the silence-first opener explicitly uses a three-point Rupture, while the stun-first sequence applies Rupture immediately after Cheap Shot and Garrote rather than delaying for a full finisher. The shorter Arena setup reduces the reaction window before coordinated control without changing sustained Rupture refreshes, which still require five points.
