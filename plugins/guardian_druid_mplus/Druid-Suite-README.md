# Arthas Druid Suite — Retail + Forever — v8.12.0

## Four-spec live-guide audit (8.12.0)

Retail Balance now opens cooldown sequences with Force of Nature and Fury of
Elune before Celestial Alignment or Incarnation, and long cooldowns wait for a
boss, elite, sustained measured target, large pack, PvP kill window, or training
dummy. This prevents world, delve, and dungeon targets near death from consuming
major burst.

Retail Feral removes the obsolete Midnight Thrash and Brutal Slash paths, treats
two targets as AoE, maintains pandemic-range Rake on secondary PvE targets, and
keeps Tiger's Fury and Feral Frenzy rolling independently of held long burst.
Restoration consumes Clearcasting with Regrowth and anchors PvE Lifebloom on the
tank when one is available. Forever Bear now uses Primal Bite before lower-value
maintenance and long-cooldown actions, preserving its verified threat priority.

## Cross-spec performance and lifecycle audit (8.11.0)

Guardian-only route, encounter, BigWigs, repair, and gathering callbacks now
stop at their callback boundary unless Guardian is the active specialization.
The route scanner also exits before its full object-manager pass while disabled
and obeys its scan interval unconditionally. This removes background Guardian
work while playing Balance, Feral, or Restoration.

The shared Retail/Forever context now reuses one 200-millisecond object snapshot
across enemy selection, PvP selection, and crowd-control safety checks. TTD
samples are pruned and capped, while object and TTD caches reset on world and
specialization transitions. Login header and bootstrap player reads tolerate
temporary native failures and retry instead of permanently stopping startup.
Forever logs now flush on logout even after the local player handle is invalid.

## Startup and Forever decision audit (8.10.0)

The suite now waits for both a valid local Druid and a conclusive client-family
result before loading a runtime. An empty login-time player handle can no longer
permanently suppress the plugin, and empty version telemetry is retried instead
of being cached as Retail. The bootstrap still loads exactly one client branch,
and all prior callbacks are invalidated before it waits.

Forever callbacks now revalidate the Druid class as well as the generation and
client family. Duration-aware Cat, Bear, and Balance choices use a GUID-scoped
smoothed health-loss estimate when the optional native time-to-die result is
missing. The estimate resets after healing, maximum-health changes, stale
samples, and world transitions.

## Attached audit fixes (8.9.0)

The Retail Guardian burst gate no longer depends entirely on the optional
native time-to-die call. A GUID-scoped, smoothed health-loss estimator supplies
a bounded fallback when the host returns no useful value, resets after healing,
maximum-health changes, stale samples, target changes, reloads, and world
transitions, and allows the existing short-target and long-target cooldown
rules to operate from observed combat data.

The skinning walker now processes its active movement state on every host
update while the more expensive corpse/object scan remains limited to roughly
seven times per second. A destination is submitted once per selected corpse,
and changing corpses first releases the old movement request. This prevents the
walker from stalling between throttled scans without restoring the earlier
high object-manager cost.

## Forever form, leveling, and mana audit (8.8.0)

Automatic profile selection now treats Primal Bite and Lacerate as Bear-only
signatures. A tank who leaves Bear Form between pulls therefore remains on the
Bear priority instead of being misclassified as Cat. Manual Cat and Bear choices
also fall back safely according to the character's level and actually learned
quest forms: Cat without its level-20 quest form uses learned Bear, and a Druid
without Bear uses the caster priority. Level changes are recorded in the
separate Forever log and refresh the learned-rank cache.

The level-20 Cat toolkit now spends capped combo points with Rip when Ferocious
Bite has not yet been learned, preventing repeated builders from wasting points.
Balance switches to efficient Wrath below 35% Mana. Restoration adds Regrowth
to a tank taking heavy sustained damage while preserving Rejuvenation for
Swiftmend preparation and retaining emergency healing above that maintenance.

Sources rechecked October 15: ForeverDB's live-extracted Druid PvE guide for
build 1.60.1.70374, its level-1-to-30 Druid guide and Druid build cards,
ClassicWoW.gg's Balance, Cat, Bear, and Restoration guides, and Wowhead's
Forever Feral ability catalog. Learned spells and confirmed character level
remain authoritative at runtime.

## Forever level and Bear-pressure audit (8.7.0)

The Forever runtime now requires a confirmed character level after its existing
database startup gate. It displays that level in the separate Forever GUI,
invalidates its highest-learned-rank cache on level-up and spellbook events,
and rebuilds the cache before the next decision. This keeps every profile on
the ranks the character has actually learned while avoiding repeated full
spellbook scans in combat.

Bear defense now scales its Barkskin and Frenzied Regeneration thresholds with
the number of active enemies and boss pressure instead of spending Barkskin at
full health merely because the target is a boss. Berserk requires a usable Rage
bank. Boss Lacerate still builds to five; ordinary durable targets stop at
three, short-lived enemies are skipped, and pack Swipe establishes broad threat
before ordinary stacking. Interrupts wait until the final 0.8 seconds when the
client exposes an end time, while unknown-timing casts retain the safe immediate
fallback.

Research was rechecked against ForeverDB's Druid PvE guide and level-30 Bear
build for client 1.60.1.70374, ClassicWoW.gg's October 8 Bear guide, and
Wowhead's current Forever Feral Combat spell list. Live learned-spell evidence
remains authoritative because beta levels and tuning can move between builds.

## Forever efficiency and lifetime audit (8.6.0)

Maul queue submissions now carry a 1.2-second retry guard so the engine cannot
repeatedly submit the same next-swing attack. A Restoration Druid with safe mana
can donate Innervate to another low-mana healer, while PvP profiles use Barkskin
earlier when an active melee attacker pushes health below the configured healing
threshold.

The runtime now consumes the target time-to-die signal when the client exposes
it. Cat uses Rip on long-lived low-health targets and Ferocious Bite on targets
unlikely to survive the bleed. Cat and Bear also hold Berserk on short-lived
multi-target packs while retaining immediate boss usage.

Research confirmed that Forever downranking can improve healing per mana, but
the optimal rank depends on live healing power, missing health, and talents.
Because those inputs are not all verified through the current runtime API, this
version keeps rank-aware maximum-throughput emergency healing instead of adding
an unsafe fixed downrank table.

## Forever mitigation, finishers, and preparation audit (8.5.0)

Bear now uses Barkskin as active mitigation throughout boss fights and heavy
pulls, enters Bear Form before a selected pull, and safely prepares Rage with
Enrage above 80% health. Cat can use the Forever Feral Charge leap to close an
8–25 yard gap and chooses Ferocious Bite instead of wasting a full Rip on an
enemy below 25% health.

At level 50 and above, grouped Druids prefer Gift of the Wild when three or more
members need the class buff, target the self-only group spell correctly, and
fall back to the appropriate Mark of the Wild rank when Gift or its reagent is
unavailable. Gift and Mark auras are recognized as equivalents.

The Forever context no longer performs its second complete world-object safety
scan during single-target combat. The crowd-control and neutral-target scan is
retained whenever area damage could actually be selected.

## Forever group utility and mobility audit (8.4.0)

Non-Restoration Druids now donate Innervate to a low-mana group healer when
the group is stable, using the customer's mode-specific Innervate threshold.
Bear uses Feral Charge to close a safe 8–25 yard gap in addition to stopping
casts. Cat preserves enough mana before using Shifting Power. Restoration can
root a melee attacker away from the healer in PvP, and all Roots logic respects
movement so cast requests do not stall the routine.

Cleanse selection now scores every affected ally instead of accepting object
manager order, prioritizing endangered tanks and healers. Numeric and textual
group-role values are normalized so tank HoTs, Thorns, cleanses, and healer
Innervate work across both party-member and party-frame providers.

## Forever runtime and current-client audit (8.3.0)

The Forever runtime now yields after a manual player cast, rejects cast-time
actions while moving, detects dead group members without discarding their unit
objects, and prevents Swipe or Hurricane from breaking crowd control or pulling
neutral enemies. Dangerous interruptible casts take priority over routine taunt
recovery.

Balance uses Starfire as its normal current-client filler and switches to Wrath
to build Eclipse only when the Eclipse talent is learned. It consumes Nature's
Grace with Starfire, maintains DoTs on a second target for two-to-four-target
combat, and reserves Hurricane for five safe targets. Restoration spends
Clearcasting on a large efficient heal and continues to prefer instant healing
while moving. Cure Poison remains available below level 26, with Abolish Poison
preferred automatically when learned.

## Forever deep audit (8.2.0)

The Forever side now follows current level-60 priorities more closely. Bear uses
Primal Bite before Lacerate maintenance, limits Frenzied Regeneration to the
20-Rage/low-health window, uses Barkskin proactively on bosses and heavy pulls,
and reserves Berserk for bosses or multi-target threat. Cat consumes Clearcasting
before restoring Energy with Shifting Power and begins that recovery at 60 Energy.
Balance refreshes its DoTs near expiry and spends Eclipse only when enough time
remains to finish Starfire. Restoration recognizes either Rejuvenation or Regrowth
for Swiftmend, favors Regrowth while taking damage, protects Tranquility with
Barkskin, and exposes Innervate, damage-mana, tank-HoT, and Wild Growth thresholds
in every mode profile.

PvP now maintains Nature's Grasp and Thorns during melee pressure. The spell
catalog also excludes client records for Nourish, Starsurge, Starfall, and Sunfire,
preventing unsupported Season of Discovery or Retail actions from entering the
Forever engine. Runtime, settings, GUI, state, and logs remain isolated from Retail.

## Forever combat audit (8.1.0)

- Bear now establishes Demoralizing Roar and Faerie Fire, uses Primal Bite on cooldown before Lacerate maintenance, keeps Lacerate at five stacks, uses Swipe for packs, spends excess Rage with Maul, and uses Enrage only above 80% health at low Rage.
- Bear uses the actual Forever Feral Charge talent (`1238122`) at 8–25 yards to stop casts, Bash in melee, Growl for one aggro loss, and Challenging Roar only when at least two enemies are loose.
- Cat uses Cower before pulling threat, supports Pounce and Ravage stealth openers, applies Faerie Fire and Rake, maintains Rip at five combo points, uses Shifting Power at low Energy, and spends Clearcasting on Shred when behind.
- Balance spends Clearcasting on Starfire because Forever Wrath does not consume the proc. It maintains Insect Swarm and Moonfire, follows Eclipse with Starfire, and channels Hurricane only while stationary against at least three safe engaged enemies.
- Restoration prioritizes critical healing over ordinary dispels, sequences Nature's Swiftness into Healing Touch, protects heavy Tranquility channels with Barkskin, uses Wild Growth for party damage, uses Innervate below 20% Mana, and deals damage only while the group is stable and Mana is at least 60%.
- Cleanse selection now distinguishes Curse from Poison. Every role can safely use Rebirth in combat and Revive out of combat. Out-of-combat preparation buffs missing group members with Mark of the Wild and maintains Thorns on the tank or solo Druid.
- Active forms are confirmed by their auras before falling back to host form identifiers, avoiding assumptions about a character's learned form order.

Version 8.0.1 prevents Forever startup from touching Retail specialization DB2 records and waits ten seconds after entering the world before querying learned spells. This avoids triggering the native `DB2.cpp ASSERT(IsLoaded())` failure while Blizzard's Forever databases are still initializing.

## WoW Forever and Retail separation

The package supports Retail/Midnight and WoW Forever from one folder. `druid_client.lua` selects exactly one boot path. A Forever session loads only `forever_*` modules; a Retail/Midnight session loads only the four existing Retail specialization runtimes. If version telemetry is temporarily missing, startup waits and retries rather than selecting the wrong client family.

Forever has its own settings prefix, window identity, logger directory, runtime state, spell tables, mode detector and rotation engine. Its profile selector offers Auto, Balance, Feral Cat, Feral Bear and Restoration. Auto selection checks active form and group role first, then learned Forever signature talents. Manual selection supports hybrid builds.

Every Forever action resolves the highest learned spell rank at cast time. Unlearned talent abilities are skipped, allowing leveling characters and arbitrary talent builds to continue through the remaining priority list. Forever covers world PvE, dungeons, raids, battlegrounds and world PvP. It does not inherit Retail Mythic+, Delve, hero-talent, Retail spell, route or boss-helper logic.

Forever support targets the 1.60.x client line and its three Druid trees. Feral Cat and Bear are separate runtime roles within Feral Combat. Learned-rank gating protects the routine from missing talents and changing beta builds.

One Project Sylvanas package now supports every Druid specialization while
keeping each specialization's mutable state separate.

PvP profiles share burst, immunity, damage-reduction, crowd-control and diminishing-return awareness. Balance, Feral and Restoration support arena, battleground and world PvP; Guardian remains deliberately limited to battleground and world PvP. Profiles pre-defend enemy burst, peel melee pressure, avoid damage immunities, reserve major damage cooldowns for kill windows and use Cyclone only when control is eligible. Control logic also respects Precognition, Ancient of Lore, expiring crowd control and damage teammates already attacking the proposed Cyclone target.

Version 7.4 separates the damage-safe roster from the complete arena roster so controlled opponents remain visible for DR chains without becoming damage targets. It identifies the actual bursting attacker for defensive Cyclone, distinguishes team pressure from pressure on the Druid, preserves Bear Form while trained, predicts targeted healer control, coordinates Bash/Cyclone and Root/Solar Beam setups, denies stalled low-target healing with Cyclone, and applies safe sustained Moonfire and bleed pressure outside kill windows. Restoration maintains HoTs on the focused teammate and orders Ironbark, Overgrowth, Swiftmend, Soul of the Forest and Nature's Swiftness around incoming pressure.

Version 7.5 adds line-of-sight-aware targeting and healer availability, safe PvP
dispel scoring that refuses Unstable Affliction backlash, urgent crowd-control
dispels, Guardian flag-carrier defense, and a current Ancient of Lore healing
window. Restoration now protects the focus first, uses Nature's Swiftness to
enter Ancient, selects Mass Blooming for spread pressure, and repeats Blossom
Burst for focused pressure. Friendly-healer control has a local aura fallback
when the optional PvP helper is unavailable.

Version 7.6 adds arena-frame specialization recovery so hidden enemy roles still
identify the opposing healer, detects control casts aimed at the friendly
healer, prioritizes their caster for a defensive stop, and scales defensive
urgency with friendly-healer mana. Raw party units and wrapper records now use
one safe discovery path. Feral maintains talented Lunar Inspiration Moonfire,
and Balance follows the current Incarnation, Force of Nature, Fury of Elune
burst order. Each non-Guardian arena profile now saves a match summary with
duration, minimum health, accepted actions, kill-window transitions,
healer-control threats, and healer-unavailable time.

Version 7.6.1 spends Balance Astral Power at the current 40-point PvP
Starsurge threshold, immediately consumes free Touch the Cosmos spenders, and
routes Restoration's Soul of the Forest directly into Wild Growth without an
unneeded Nature's Swiftness global between them.

Version 7.7 corrects Feral's rated burst sequence so Incarnation and bleed
setup precede Tiger's Fury at the five-combo-point Rip window. Shared PvP
logic now separates setup windows from commit windows, allowing healer control
to create a go without circularly requiring one first. Confirmed healer CC
promotes pressure into a commit window, and every damage spec follows a safe
target selected by a teammate whose burst cooldowns are active.

Version 7.8 makes Balance and Feral dispels pressure-aware: urgent control is
still cleared immediately, while ordinary poison and curse cleanup yields to
team danger and active kill windows. Both damage specs now Innervate an
available healer at low mana outside a setup or commit window. Balance also
uses Hibernate defensively against a verified Feral or Guardian in animal
form, provided no damage teammate is attacking that control target.

Version 7.8.1 keeps friendly-healer crowd control strictly defensive instead
of allowing it to create an offensive setup signal. Rated-match summaries now
record accepted, confirmed, unconfirmed and declined automated casts plus
manual interventions, making client rejection and player-override rates
measurable without adding per-frame file writes.

Version 7.9 adds stable-period Restoration pre-HoT coverage across the PvP
party before downtime damage or offensive control. Restoration also uses
Hibernate against an eligible, uncontested animal-form attacker after urgent
healing is stable, while emergency recovery always retains priority.

Version 7.10 adds PvP gate preparation for every arena-enabled spec. Balance
and Feral enter Prowl after Mark of the Wild. Restoration applies Rejuvenation
and talented Germination to the likely focus before entering Prowl. All three
profiles yield while stealthed so automated maintenance cannot reveal the
Druid before the opener.

Version 7.10.1 corrects Restoration's PvP Soul of the Forest follow-up to an
empowered Rejuvenation on the pressured ally. The proc is evaluated before
the stable-party pre-HoT sweep so an unrelated maintenance cast cannot consume
it. PvE spread healing retains its Soul of the Forest Wild Growth path.

Version 7.11 removes the retired active Overgrowth spell from Restoration's
12.1 model; current Overgrowth is the passive Nature's Swiftness enhancement.
An active Nature's Swiftness now flows directly into emergency Regrowth unless
it is preparing the documented Ancient of Lore sequence. Both predictive and
fallback Ironbark paths respect an ally's existing strong damage reduction,
with a critical-health override retained.

Version 7.11.1 lets a confirmed Balance PvP kill window activate Incarnation
or Celestial Alignment, Force of Nature, Fury of Elune and Convoke before
spending globals on missing Moonfire or Sunfire. Setup windows still prepare
the target with DoTs before the team commits.

Version 7.12 replaces the sparse Balance, Feral and Restoration windows with
customer-facing Dashboard, Player, World, Dungeon, Mythic+, Raid, Delve,
Arena, Battleground, World PvP and Hotkeys pages. Every behavior switch has an
independent persistent binding-enable switch and selectable F-key or numeric
keypad binding. Guardian receives matching Player and Hotkeys pages, including
bindings for route navigation. Bindings trigger once per press, remain isolated
by specialization and skip input polling while disabled.

Version 7.12.1 extends selected-target training mode to all four specs. Dummy
recognition uses the framework classifier first, stable NPC IDs for localized
clients, and damage, tanking, healing and practice-dummy name fallbacks.
Balance and Restoration support caster-range practice, Feral and Guardian
require melee range, and Restoration can treat a selected friendly healing
dummy as the injured practice target. Ordinary neutral NPCs remain excluded.

## Mode coverage

| Specialization | World PvE | Dungeons / M+ | Delves | World PvP | Battlegrounds | Arena |
|---|---:|---:|---:|---:|---:|---:|
| Balance | Yes | Yes | Yes | Yes | Yes | Yes |
| Feral | Yes | Yes | Yes | Yes | Yes | Yes |
| Guardian | Yes | Yes | Yes | Yes | Yes | No |
| Restoration | Yes | Yes | Yes | Yes | Yes | Yes |

Guardian is deliberately disabled in arenas. The other three specs receive
arena detection, opponent-frame discovery and DR-aware healer control.

## Isolation

- The loader accepts Druid only and auto-detects specialization IDs 1–4.
- Balance, Feral and Restoration have separate runtime engines, retry ledgers,
  manual-input holds, settings namespaces, themed windows and persistent logs.
- Guardian keeps its mature tank runtime, route engine and boss helper. Its
  logger initializes only while Guardian is active.
- Generation tokens retire callbacks from older hot-loaded copies.
- Every menu and window checks class and exact specialization before rendering.

Separate log locations:

- `druid_suite/balance/current.log`
- `druid_suite/feral/current.log`
- `guardian_druid_mplus/session.log`
- `druid_suite/restoration/current.log`

Each new spec also owns `previous.log` and `last_error.log` in its directory.

## Rotation models

Balance maintains Moonfire and Sunfire, avoids Astral Power capping, chooses
Starsurge or Starfall from safe target count, respects Eclipse, coordinates
Force of Nature/Celestial Alignment/Incarnation/Convoke/Fury of Elune, and
provides Solar Beam, defensive, dispel and DR-aware PvP control logic.

Feral maintains Rake, Rip and Thrash inside pandemic windows, coordinates
Tiger's Fury, Berserk/Incarnation, Feral Frenzy and Convoke, spends five combo
points on Rip/Primal Wrath/Ferocious Bite, uses safe AoE builders, supports
Maim kill windows and Predatory Swiftness recovery, and supplies Skull Bash,
defensive, dispel and DR-aware PvP control logic.

Restoration maintains Lifebloom on self, applies proactive Rejuvenation,
triages with Swiftmend/Regrowth/Nature's Swiftness/Ironbark, uses Wild Growth
and major healing cooldowns from injured-group count, manages Innervate from
readable mana, dispels supported debuffs, performs safe combat resurrection,
and deals caster-form damage only while the group is stable.

All three new engines reject unrelated neutral targets, suppress unsafe area
actions around neutral or crowd-controlled enemies, respect casts and the
global cooldown, and pause briefly after confirmed manual player input.

## Research sources

- https://www.method.gg/guides/guardian-druid/playstyle-and-rotation
- https://www.method.gg/guides/balance-druid/playstyle-and-rotation
- https://www.method.gg/guides/feral-druid/playstyle-and-rotation
- https://www.method.gg/guides/restoration-druid/playstyle-and-rotation
- https://www.icy-veins.com/wow/balance-druid-pve-dps-rotation-cooldowns-abilities
- https://www.icy-veins.com/wow/feral-druid-pve-dps-rotation-cooldowns-abilities
- https://www.icy-veins.com/wow/restoration-druid-pve-healing-rotation-cooldowns-abilities
- https://www.icy-veins.com/wow/balance-druid-pvp-guide
- https://www.icy-veins.com/wow/feral-druid-pvp-rotation-and-playstyle
- https://www.icy-veins.com/wow/restoration-druid-pvp-guide
- https://www.icy-veins.com/wow/balance-druid-pvp-rotation-and-playstyle
- https://www.icy-veins.com/wow/feral-druid-pvp-rotation-and-playstyle
- https://www.icy-veins.com/wow/restoration-druid-pvp-rotation-and-playstyle
- https://www.icy-veins.com/wow/balance-druid-battleground-blitz-pvp-guide
- https://www.icy-veins.com/wow/feral-druid-battleground-blitz-pvp-guide
- https://www.wowhead.com/spell=155675/germination
- https://www.wowhead.com/spell=1219045/unstable-affliction
- https://www.wowhead.com/spell=473909/ancient-of-lore
- https://www.wowhead.com/spell=473919/blossom-burst
- https://www.wowhead.com/spell=474149/mass-blooming
- https://www.wowhead.com/spell=450360/touch-the-cosmos
- https://murlok.io/druid/feral/3v3
- https://murlok.io/druid/restoration/
- https://drustvar.com/
- https://warcraft.wiki.gg/wiki/Training_dummy
- https://www.wowhead.com/npc=243167/dungeoneers-training-dummy
- https://www.wowhead.com/npc=243212/pvp-training-dummy

## Validation

Version 8.6.0 passes the complete simulated behavior suite and compiles on Lua 5.1,
Lua 5.4 and LuaJIT with 32 additional local variables reserved in every chunk
and named function. This is simulation and compiler validation; live combat
logs remain the authority for future timing and client-data adjustments.
