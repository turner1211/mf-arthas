RESEARCH AND IMPLEMENTATION PROVENANCE — 2026-10-08

Primary sources inspected online and/or downloaded for verification:
https://docs.project-sylvanas.net/dev/
https://docs.project-sylvanas.net/dev/api/input/
https://docs.project-sylvanas.net/dev/api/events/
https://raw.githubusercontent.com/simulationcraft/simc/midnight/engine/class_modules/sc_hunter.cpp
https://raw.githubusercontent.com/simulationcraft/simc/midnight/engine/dbc/generated/trait_data.inc
https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_Hunter_Beast_Mastery.simc
https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_Hunter_Marksmanship.simc
https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_Hunter_Survival.simc

Local references read:
Installed Project Sylvanas scripts/.api/core.lua, game_object.lua, enums.lua,
pvp_helper.lua and pet_handler.lua.
Existing Warrior shared API/cast engine and DPS helper; installed Rogue
ar_boss_coach.lua / ar_s2_bosses.lua and Ret's ret_paladin_rotation.lua.
These informed cast confirmation/backoff, health prediction, independent profile
settings, English mechanic cards, timer-driven prompts and overlay behavior.
Ret and Rogue mechanics/data were adapted to Hunter wording and mode isolation;
their combat rotations are not imported or executed.

Changes driven by research:
* Modern BM uses Wild Thrash (1264359), not the old BM Multi-Shot rotation.
* Player Beast Cleave is 268877; pet Beast Cleave is 118455.
* Bestial Wrath's apex pet has a delayed hit and does not inherit old cleave;
  the next safe Wild Thrash refresh is prioritized after the confirmed Wrath.
* Survival uses Takedown (1250646), Boomstick (1261193), Raptor Strike (186270),
  Kill Command (259489), and Wildfire Bomb (259495).
* Twin Fangs changes Takedown's preferred Tip setup; Raptor Swipe (1262293)
  can turn an ordinary spender into area damage and must respect CC protection.
* MM uses separate Aimed, Precise and Trick Shots logic; moving Aimed requires
  positively observed Lock and Load. Rapid Fire channels are not clipped by this
  release, despite some simulation priorities requesting partial channels.
* Explicit spell replacement relationships reject unsupported/hotfixed overrides.
* Sylvanas casting requests are tracked until a confirming event; a request alone
  is not evidence of a successful cast. Emergency actions can supersede damage.

Source limitations:
SimulationCraft describes simulated PvE damage behavior, not arena strategy.
PvP logic here is a conservative authored adaptation using the actual Sylvanas
helper API. No claim is made that simulated priorities are optimal in PvP.
No unverified PvP timing was sourced from macros or private-server changelogs.
Downloaded source hashes are recorded in manifest.lua for reproducibility.

1.2.0 repair review (2026-10-08)
Compared Hunter window registration, texture layer, control layout and icon
caching with local ar_gui.lua/ar_icons.lua/ar_runtime.lua and native .api docs.
Checked the current upstream SimulationCraft Midnight default BM priorities:
https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/hunter_beast_mastery.simc
https://github.com/simulationcraft/simc/blob/midnight/engine/class_modules/sc_hunter.cpp
Black Arrow uses its own availability, while actual Kill Shot remains execute
gated. The practical PvP adaptation retains manual/automatic burst permission,
DR/CC and engaged-target checks; it is not a simulated or measured DPS claim.


1.4.0 gameplay audit, 2026-10-08:
Primary author rotation guides inspected (Slo, current 12.1 pages):
https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.26 urgent-stop arbitration — 2026-10-11

The shared utility controller now distinguishes prevention from routine stop
timing. A high-priority active channel or a cast with less than 0.4 seconds left
may be interrupted before an emergency defensive. All ordinary progress-based
interrupts remain after the defensive block. Native readiness, cast identity,
range, facing, line of sight, boss, CC, and DR safeguards remain unchanged.

## 1.4.25 BM pet-control recovery — 2026-10-11

Current BM PvP guidance identifies Bestial Wrath as an immediate pet
crowd-control break, restoring access to Kill Command and pet defensive utility.
The snapshot now records only a positively confirmed generic pet-control state.
BM consumes an already-authorized burst window to break that control; unknown
state, an unaffected pet, disabled cooldowns, or an unavailable spell holds.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.24 BM PvP Hunter's Mark timing — 2026-10-11

Current BM PvP guidance places Hunter's Mark after the normal offensive
priority when higher-value actions are unavailable and Focus is low. BM PvP now
follows that timing instead of spending its opening global on Mark at high
Focus. BM PvE retains opener upkeep, and MM and Survival keep their independent
spec branches.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle

## 1.4.22 active-channel response — 2026-10-11

Enemy channels differ from ordinary casts: their effect has already begun.
The interrupt controller now immediately stops channels classified at priority
two or higher, while low-priority channels and all ordinary casts retain the
user's configured progress threshold. Existing target, range, line-of-sight,
cooldown, cast-identity, boss, and DR safeguards still apply.

https://www.wowhead.com/guide/classes/hunter/beast-mastery/abilities-talents-pve-dps
https://www.wowhead.com/guide/classes/hunter/survival/abilities-talents-pve-dps

## 1.4.23 MM PvP burst sequencing — 2026-10-11

The current MM PvP burst priority places Volley first, protects an available
instant Aimed Shot, uses Rapid Fire, and then activates Trueshot. The PvP branch
now follows that order without changing the separate PvE priority. The audit
also retained BM's aggressive Bestial Wrath behavior because current BM PvP
guidance still recommends frequent use after its Barbed Shot setup.

https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.21 cross-mode root removal — 2026-10-11

Master's Call clears roots and snares in PvE as well as PvP, with useful niche
applications in dungeons and raids. The old PvP-only spell restriction was
removed. Automation still requires positive root detection plus normal pet,
known-spell, cooldown, range, line-of-sight, profile, and execution checks.

https://www.wowhead.com/guide/classes/hunter/beast-mastery/abilities-talents-pve-dps
https://www.wowhead.com/guide/classes/hunter/survival/abilities-talents-pve-dps
https://www.wowhead.com/guide/classes/hunter/survival/rotation-cooldowns-pve-dps
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.39 teammate-aware Arena defense — 2026-10-12

Current Hunter Arena guidance calls Roar of Sacrifice vital for either the
Hunter or a pressured teammate and recommends earlier personal mitigation while
the healer is crowd-controlled. Midnight Marksmanship no longer requires a pet
for Roar or Intimidation. The snapshot now counts confirmed attackers on party
members and identifies the friendly healer. Roar protects the lowest-health
partner at or below 70% under two-attacker pressure. Fittest is authorized at
80% or lower while the healer is confirmed controlled. BM and Survival retain
pet-health requirements; MM can use its native petless Roar.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-pets

## 1.4.38 DR-safe healer stun into Freezing Trap — 2026-10-12

Current Arena guidance for BM, Marksmanship, and Survival consistently uses
Intimidation into Freezing Trap on the enemy healer. The plugin now creates that
chain when the healer is moving, clean of damage effects, not targeted by the
pet or a teammate, and both stun and incapacitate DR are confirmed usable. Its
own confirmed Intimidation is the only debuff allowed to bridge into Trap;
unknown and foreign debuffs continue to block the ground cast.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.35 target-aware PvP action history — 2026-10-11

The second PvP state audit found that BM's recent pet-driving action check was
time-aware but not target-aware. A fast Arena, battleground, or world-PvP target
swap could therefore send Bestial Wrath before the pet committed to the new
enemy. Confirmed casts now retain their target GUID, and BM only trusts recent
Kill Command or Barbed Shot history when it belongs to the current target.

## 1.4.36 PvP target and healer lines — 2026-10-12

All three specs now draw a spec-colored world line to the current engaged PvP
target and a separate line to the nearest confirmed enemy healer. The healer
line is cyan with line of sight and red when line of sight is lost. Detection
uses arena specialization data first and guarded specialization/role data in
battlegrounds and world PvP. The feature is profile-isolated, defaults enabled,
and can be disabled with `Target and healer world lines` in each PvP profile.

## 1.4.37 Arena defensive and healer-support reactions — 2026-10-12

Current multi-Rank-1 Hunter guidance identifies Feign Death with Survival
Tactics as the primary short-cooldown defense, Roar of Sacrifice as vital during
enemy pressure, and Master's Call on a healer rooted in Solar Beam as an
immediate support play. The plugin now uses Feign Death for confirmed imminent
dangerous casts after interrupt handling, Roar under confirmed two-attacker
pressure with a healthy pet, and Master's Call for positively detected Arena
healer roots. Each reaction has its own enabled-by-default PvP profile switch.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle
Current SimulationCraft default action lists cross-checked:
https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/hunter_beast_mastery.simc
https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/hunter_marksmanship.simc
https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/hunter_survival.simc

BM: available Black Arrow precedes other PvP pressure; capped Kill Command is
protected before burst; PvP Kill Command cannot be held by PvE Apex tuning.
MM: independent PvP branch spends eligible Precise Shots and Lock and Load
before longer casts. Native execute, movement and splash safety still apply.
SV: prepare two Tip stacks before non-Twin-Fangs Takedown when possible;
consume visible Howl through Kill Command. PvP and Sentinel single-target
do not hold Boomstick/chakram solely on missing Tip aura visibility.
Runtime: snapshot copies object-manager rows before adding Arena frames;
charge/cooldown/known queries account for allowed replacement spells.
Healer immunity alone no longer authorizes an automatic Arena burst window.
Trap eligibility is shared by the planner and executor, rechecking DR,
immunity, stationary target, debuffs and allied/pet target pressure.

Validation remains offline. Native hidden aura data, positioning, latency,
talent interactions and actual DPS require live logs across all 24 profiles.
No claim of flawless gameplay or measured damage improvement is made.


1.4.1 runtime and PvE audit, 2026-10-08:
https://docs.project-sylvanas.net/dev/api/spellbook/
Current MM/Survival default action lists above cross-checked again.
Local API contract additionally confirms get_object_from_guid accepts raid1
through raid40, get_spell_cast_time answers seconds, and get_spell_haste
answers a percentage. Raid roster refresh is cached for one second and reset
on scope/roster changes. Raid tanks are included in Misdirection recipients;
enemy engagement and teammate interrupt deferral include verified raid allies.

Passive area protection now applies to attacks that spread damage rather than
every damage button. Arcane/Steady and Cobra remain eligible when their target
is safe but a spreading attack would break nearby CC. Dynamic cleave, Stomp
and Raptor Swipe receive the same area checks as explicit AoE, including the
pet position where relevant. These checks read protection and engagement again
at execution instead of relying solely on snapshot booleans.

PvE MM: Volley is attempted on safe single targets as well as packs. Dungeon
and Mythic+ Rapid Fire takes priority over ordinary Explosive Shot when ready,
unless Unstable Trigger is positively observed. Tactical Reload/Lock and Load
protection remains. Two-target Hydra Precise Shots spending uses Multi-Shot
outside dungeon routes; dungeon two-target spending remains Arcane Shot.
Eligible Kill Shot and Wailing Arrow proc damage are not tied to a major burst
request. Trick Shots refresh uses the available native Aimed cast time.
Survival Howl preparation does not overcap an already high Tip stack count.

Input rejects a selected-target change after a damage decision. Actual spell
confirmation records a canonical spell key instead of allowing alias iteration
order to alter history. Recommendations are cleared when the current tick
yields or waits. Version 1.4.17 removes the legacy status HUD so the plugin
creates only the main command GUI and compact boss helper.

Unverified API detail: charge recharge start-time units are not sufficiently
clear in the published/local contracts. Fractional charge prediction is not
invented; actual native charge counts and usability remain authoritative.


1.4.2 Survival and persistent diagnostics, 2026-10-08:
Current SimulationCraft Survival priority list cross-checked again.
Unknown Tip aura data is distinct from a positive native inactive result.
Confirmed Kill Command preparation can advance to native-eligible attacks
instead of repeating forever while the aura is hidden. Observed Twin Fangs
zero-stack Takedown and ordinary positive-stack setup remain distinct.
All eight activity profiles have regression checks for these paths.

Persistence contracts inspected in installed scripts/.api/core.lua and menu.lua:
create_data_file creates/truncates; write_data_file appends; read_dir lists
session files; get_data_file_size checks completed writes; the native window
copy_to_clipboard method supplies export. These informed a fresh numbered file
for each run and retained rotated files, not recreation of a shared session.log.
Each diagnostic event is appended immediately. Failed writes retain a bounded
queue with retry/status reporting. Old files are never automatically deleted.
Logs include active profile settings, decision/cast outcomes, current resource
and health data, five-second heartbeats, errors and available lifecycle events.
Clipboard reports read saved disk data and include up to the latest 64 KB.

Tests simulate storage failures, module reload, retained prior sessions,
rotation, clipboard size limits and all three GUI actions. A separate Python
process executes the actual Lua logger with real filesystem adapters, exits
abruptly via os._exit, and verifies that a new process can read/copy the prior
record without overwriting it. This does not claim native in-game storage or
clipboard verification, OS power-loss durability, or survival of records that
could not be written while the storage API was failing.


1.4.3 source and mode audit, 2026-10-08:
Current Survival/Beast Mastery default action lists rechecked online.
Survival Lethal Calibration single-target priority places an available Raptor
spender before a non-capped bomb after Boomstick, retaining ordinary Pack Leader
bomb priority. The exact near-full-recharge condition awaits confirmed charge
clock units; actual capped charges still protect against obvious charge waste.
Raptor eligibility uses the native Focus cost when available instead of a fixed
30-Focus threshold. Resource-cost variants prefer positively active required-buff
entries regardless of iteration order; inactive/unknown variants do not apply.

Local game_object API confirms get_owner(). Positive player ownership classifies
hostile pets/summons as PvP in the world and at execution. Player-owned units
cannot enter World PvE damage execution. A hostile pet with an unavailable owner
holds activity detection instead of guessing PvE. NPC-owned pets remain PvE.
An owner's death does not erase known player ownership. All three specs have
snapshot and executor regressions for these cases.

No runtime Hunter logs were present at the inspected live log location during
this audit. Tests do not establish native gameplay, DPS or competitive quality.
BM native zero-cost Cobra is allowed while Focus is reserved; a free attack cannot spend the reserved resource. All eight activities have this regression check.


1.4.4 native combat diagnostics, 2026-10-08:
Native v1.4.3 BM World PvE logs now contain successful requested/confirmed
Barbed Shot, Kill Command, Cobra Shot and Mend Pet pairs, without recorded
failures or API errors. This establishes these observed cast paths only.
No Bestial Wrath request was present despite a permitted burst window. The log
did not contain enough native readiness data to attribute the missing cooldown.
Main-cooldown probes now record known/usable/CD/GCD/ready and separate enemy,
pet and self range results every five seconds during valid-target combat.
Probes do not send input and ignore foreign-spec cooldowns. Probe errors are
contained and logged. No targeting or range safety rule is changed speculatively.
Full all-spec/activity, DPS, UI/clipboard and competitive validation remain open.

1.4.5, native v1.4.4 BM World PvE evidence:
Bestial Wrath ID19574 known=true usable=true cd=0 gcd=0 ready=false;
range_enemy=false range_pet=false range_self=false, with valid pet/LoS/facing.
A spell-specific range exemption preserves the enemy-target dispatch and all
remaining engagement, protected-target, pet-cleave, identity and burst guards.
Other spells retain strict native range checks. Requires live cast confirmation.
Primary platform docs explicitly allow range skipping for self-buff spells:
https://docs.project-sylvanas.net/dev/api/spellbook/helper/
SimulationCraft midnight bestial_wrath_t models player and pet buffs separately
from pet damage. Full DPS/all-profile/live GUI validation remains incomplete.

1.4.7 MM PvP review, 2026-10-08:
Rechecked Slo's current 12.1 BM/MM/SV PvP rotation pages. MM burst opener includes
Volley and Dark Ranger Wailing Arrow. Add native-eligible safe Volley during
authorized burst, including single target, and Wailing proc fallback to all
three PvP profiles. Preserve user toggles, native AoE CC/pull guards and spec
allowlists. PvE priorities unchanged. No numerical DPS improvement is proven.
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle
1.4.8 BM PvP audit, 2026-10-08:
The current 12.1 opener calls for two Barbed Shots before Bestial Wrath. The
previous branch stopped after one confirmed preparation shot. PvP now completes
the second shot only during an authorized, ready Wrath window, within three
seconds of the confirmed first cast, and only with a remaining charge. If no
charge remains, Wrath proceeds. PvE behavior is unchanged.
https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.9 training-dummy support — 2026-10-08

Project Sylvanas exposes `unit_helper:is_dummy(unit)` for native training-dummy
classification. The world-PvE snapshot uses that API rather than names or a
hard-coded NPC list. It bypasses only the engagement/combat-start requirement;
all spec, role, range, facing, line-of-sight, protected-target, spell-known,
cooldown and area-safety checks remain active.

https://docs.project-sylvanas.net/dev/libraries/mini-libs/unit-helper/

## 1.4.16 boss positioning coach — 2026-10-10

The Season 2 encounter cards were checked against current Icy Veins dungeon
guides and the Wowhead dungeon overview. The helper now keeps tank placement
and Hunter positioning separate. Examples include Taz'Rah wall rotation,
Charonus center-of-stars placement, Nalorakk corner/shield handling, Rav'i
corpse separation, and boss/add cleave placement. World arrows are generated
only from detected player and boss positions. Arena landmarks such as stars,
snow cover, freight, and gateways use text and ring cues because the API does
not expose a verified landmark destination in this plugin.

https://www.icy-veins.com/wow/altar-of-fangs-dungeon-guide
https://www.icy-veins.com/wow/voidscar-arena-dungeon-guide
https://www.icy-veins.com/wow/blinding-vale-dungeon-guide
https://www.icy-veins.com/wow/den-of-nalorakk-dungeon-guide
https://www.icy-veins.com/wow/murder-row-dungeon-guide
https://www.icy-veins.com/wow/kings-rest-dungeon-guide
https://www.icy-veins.com/wow/dungeons-guide
https://www.wowhead.com/guide/midnight/altar-of-fangs-dungeon-overview-location-rewards

## 1.4.18 rotation audit — 2026-10-11

Current 12.1 guides identify four reliable corrections: all specs open with
Hunter's Mark when it is absent; three-point Nature's Ally BM places a filler
between Kill Commands; MM Precise Shots is spent by Arcane Shot or Multi-Shot
rather than Black Arrow; and Midnight Steady Shot can be cast while moving.
The implementation acts on Hunter's Mark only when aura absence is positively
observed, so incomplete aura data cannot cause repeated casts. Emergency
defensive ordering also places Turtle before Exhilaration below its threshold.

https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-spec-builds-talents
https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities
https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-guide
https://www.wowhead.com/guide/classes/hunter/survival/rotation-cooldowns-pve-dps
https://www.wowhead.com/guide/classes/hunter/marksmanship/overview-pve-dps

## 1.4.19 resource and cooldown alignment — 2026-10-11

Current BM guidance banks a single Nature's Ally Kill Command when Bestial
Wrath is within three seconds, except when charges would cap or Howl is ready.
Current Survival guidance prohibits Kill Command above one Tip stack and asks
for two Tip stacks before a non-Twin Fangs Takedown. These conditions now use
live charge, cooldown, talent, buff, and stack observations.

https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-rotation-cooldowns-abilities
https://www.icy-veins.com/wow/survival-hunter-pve-dps-rotation-cooldowns-abilities

## 1.4.20 BM Wrath sequence and PvP mark timing — 2026-10-11

The Pack Leader AoE sequence now survives the Wild Thrash confirmation between
Bestial Wrath and its first Kill Command, allowing the Stampede trigger to stay
ordered. Cleave is not refreshed immediately before a ready Wrath, because the
post-Wrath Apex pet requires the new refresh. Dark Ranger can use Black Arrow to
establish missing cleave before Wrath. PvP Hunter's Mark follows the current MM
guidance and waits for high Focus.

https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-rotation-cooldowns-abilities
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle

## 1.4.27 Survival range recovery — 2026-10-11

Current PvE guidance describes Aspect of the Eagle as the tool for maintaining
Raptor Strike uptime while handling ranged raid and dungeon mechanics. Current
PvP guidance identifies Harpoon as the catch and gap-closing tool. The shared
Survival utility branch now orders Eagle first in PvE and Harpoon first in PvP;
each retains its profile toggle and native readiness checks.

https://www.wowhead.com/guide/classes/hunter/survival/abilities-talents-pve-dps
https://www.icy-veins.com/wow/survival-hunter-pvp-guide

## 1.4.28 Exhilaration global-cooldown correction — 2026-10-11

Current Midnight ability documentation identifies Exhilaration as a global-
cooldown heal. Its spell metadata now reflects that native behavior, preventing
requests during an active GCD and avoiding unnecessary failed-cast backoff.
Turtle retains its distinct off-global emergency behavior.

https://www.wowhead.com/guide/classes/hunter/survival/abilities-talents-pve-dps

## 1.4.29 critical pet recovery — 2026-10-11

Current Hunter ability documentation confirms Exhilaration heals both the
Hunter and active pet. The shared utility controller now uses it at or below
20% pet health when defensive and pet-healing permissions are both enabled.
This supplements Mend Pet only in the critical instant-recovery window.

https://www.wowhead.com/guide/classes/hunter/survival/abilities-talents-pve-dps

## 1.4.30 proactive PvP mitigation — 2026-10-11

Current PvP guidance recommends Survival of the Fittest during heavy incoming
pressure so the Hunter can remain aggressive. The snapshot already confirms
which engaged enemies actively target the player. Two or more such attackers,
combined with health at or below 80%, now authorize proactive mitigation. A
single attacker retains the profile's normal health threshold.

https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.31 live debugger/logger correction — 2026-10-11

The current loader debugger reported class 13, so the Hunter plugin correctly
skipped runtime registration and could not produce a new Hunter session. The
latest Hunter combat log exposed the actionable fault: city combat repeatedly
recorded near-zero target health with `training_dummy=false`. Dummy detection
now checks the unit flag, Project Sylvanas helper, and guarded English dummy-name
fallbacks. Heartbeats include target name and classification source so the next
live session can distinguish API, helper, and fallback detection.

## 1.4.32 representative city-dummy decisions — 2026-10-11

The live combat log showed the city target repeatedly reporting effectively zero
health. Dummy detection is now reliable, so the decision layer can preserve the
raw diagnostic value while excluding it from execute and target-life gates. This
keeps normal opener, sustain, and cooldown paths testable. Deathblow remains the
only proc-based exception and still permits Kill Shot on a dummy.

## 1.4.33 BM pet-commit opener — 2026-10-11

Current Wowhead BM guidance warns that opening directly with Bestial Wrath can
miss its pet hit and Bloodshed when the pet has not begun attacking. It also
recommends planning Kill Command charges for the cooldown window. BM now confirms
the pet target or a recent pet-driving attack, preferring Kill Command and then
Barbed Shot for one setup GCD before Wrath. The setup cannot deadlock Wrath when
both attacks are unavailable, and confirmed pet-CC breaking remains immediate.

https://www.wowhead.com/guide/classes/hunter/beast-mastery/rotation-cooldowns-pve-dps

## 1.4.34 deep PvP audit — 2026-10-11

Current Icy Veins guidance for all Hunter PvP specs emphasizes healer crowd
control before major offensive commitments, movement control through Master's
Call, and preserving or recovering the active pet. Automatic Arena burst now
requires healer control, the recorded healer-trinket window, or an emergency
finish at 35% target health. Master's Call recognizes a positively confirmed
40% PvP slow as well as roots. Revive Pet is allowed during PvP only with at
least 80% Hunter health and zero enemies confirmed to be targeting the Hunter.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle


## 1.4.40 Arena setup and CC-window timing — 2026-10-12

Current BM, Marksmanship, and Survival Arena guidance builds kill attempts by
stunning the enemy healer into Freezing Trap, then committing damage while that
control is active. The previous state model required an existing burst window
to begin the setup that creates the window. Arena now has a separate, guarded
kill-intent state: it can start a clean, DR-safe Intimidation-to-Trap chain while
major cooldowns remain held. Automatic cooldowns unlock only after confirmed
healer control with at least the configured time remaining, a tracked healer
trinket window, or an enemy at finishing health. Unknown CC duration preserves
the confirmed-control behavior instead of guessing. Both thresholds appear only
in each spec's Arena control page, default enabled with one second of minimum CC
and a 90-second tracked trinket window. Diagnostics record setup intent, healer
control, and known remaining time for live review.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.41 Arena planner setup-gate completion — 2026-10-12

The post-install control-path audit found a second legacy burst check in the
utility planner. Although trap eligibility accepted the new kill-intent state,
the planner could still return before consulting it. The planner now uses the
same setup-intent contract as the safety layer. An end-to-end regression proves
that a healthy target and uncontrolled healer can produce Intimidation on a
clean, DR-safe healer without authorizing major damage cooldowns early.

## 1.4.42 Survival sustained Arena Takedown — 2026-10-12

The current 12.1 Survival Arena guide places Takedown second in the sustained
damage priority, after Kill Command only when Tip of the Spear is absent or a
Pack Leader Howl is available. Takedown was incorrectly tagged as burst-only,
which made the native readiness check reject it between coordinated kill
windows. The spell is now eligible outside burst, and the Survival PvP branch
uses it before Boomstick and Wildfire Bomb with a positively prepared Tip state.
Non-Twin-Fangs uses at least one observed stack; Twin Fangs retains its observed
zero-stack condition. PvE and both ranged Hunter specs keep their separate logic.

https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.43 BM Arena pre-control damage ramp — 2026-10-12

The current 12.1 BM Arena opener orders Black Arrow, two Barbed Shots, and
Bestial Wrath before Intimidation into Freezing Trap. The shared utility layer
could previously begin healer control as soon as kill intent existed, before
BM completed that ramp. BM now treats Arena kill intent as permission for its
pre-control damage setup. The trap planner yields only while Black Arrow or an
immediately ready Barbed/Wrath step can actually execute, then resumes control
as soon as Wrath is spent or unavailable. This behavior is BM-only; MM and
Survival keep independent openers. The normal healer-CC gate still controls
subsequent major damage commitment outside this sourced BM setup.

https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.44 Survival pre-control Bomb sequencing — 2026-10-12

The current 12.1 Survival Arena opener builds Tip of the Spear, spends one
Wildfire Bomb, then controls the healer before Takedown, Bomb, and Boomstick.
Survival kill intent now holds the trap planner for a positively confirmed
zero-stack Kill Command or one immediately usable, Tip-empowered pre-control
Bomb. A six-second confirmed-cast guard prevents repeating that priming Bomb.
Hidden Tip data never delays control. After the priming cast, the existing
DR-safe healer chain resumes and sustained Takedown remains available.

https://www.icy-veins.com/wow/survival-hunter-pvp-rotation-and-playstyle

## 1.4.45 live Arena trap handoff repair — 2026-10-13

The native v1.4.44 BM Arena log contained 2,294 Arena records, including five
Intimidation requests and no Freezing Trap request. Confirmed Intimidations
were followed by eligible-action waits while the healer control window expired.
The trap safety path required the native movement flag to be positively false
even after the plugin's own confirmed setup stun. Native movement can retain
pre-stun momentum briefly. A confirmed player-cast Intimidation now supplies
the stationary proof for its immediate Trap handoff. Direct unstunned traps
still require a positively stationary healer. Immunity, incapacitate DR,
foreign control, debuff, allied-target, pet-target, range, line-of-sight, and
area-safety checks remain active. Heartbeats now record the exact trap-block
category so the next live session can distinguish DR, immunity, movement,
debuff, and base-target failures.

## 1.4.46 live Arena burst-permission correction — 2026-10-13

The v1.4.44 BM Arena log showed burst=true for nearly the whole active match,
including records with no confirmed healer control. The enabled-by-default
`Allow PvP burst` control was incorrectly treated as a permanent manual burst
override, bypassing the enabled automatic kill-window setting. It now acts as
the documented master permission. With automatic timing enabled, Arena major
cooldowns require confirmed useful healer CC, the tracked healer-trinket window,
or finishing target health. Turning the master permission off holds both setup
and cooldowns. Disabling automatic timing while permission remains on retains
the explicit always-on behavior. This correction applies through the shared
PvP state contract while each spec keeps its independent damage priority.

## 1.4.47 post-Trap Chimaeral Sting chain — 2026-10-13

Current 12.1 Hunter Arena guidance recommends Chimaeral Sting after Freezing
Trap ends when team disorient follow-up is unavailable. The plugin did not know
the PvP talent. All three specs now expose an enabled-by-default Arena-only
`Chimaeral Sting after healer Trap` option. The action requires the spell to be
natively known, a confirmed plugin Trap on the same healer, an elapsed Trap
window, no positively active Trap aura, and no Sting already confirmed for that
chain. Hidden aura data waits seven seconds rather than guessing that Trap has
ended. The follow-up expires after twelve seconds. It cannot enter PvE profiles
or another spec's damage branch.

https://www.icy-veins.com/wow/marksmanship-hunter-pvp-rotation-and-playstyle
https://www.icy-veins.com/wow/marksmanship-hunter-pvp-talents-and-builds
https://www.wowhead.com/spell=356719/chimaeral-sting

## 1.4.48 Arena Scatter Shot safety — 2026-10-13

Current Midnight 12.1 sources identify Scatter Shot (213691) as an all-Hunter PvP talent: a 20-yard, 3-second breakable incapacitate that removes damage-over-time effects and stops auto-attacks. Current DR references place Scatter Shot with Freezing Trap in the incapacitate category. The plugin therefore does not use Scatter to start its healer Trap chain. It reserves Scatter for urgent, critical casts from a clean off-target when incapacitate DR and immunity are positively safe, the target is neither the kill target nor Arena healer, and no teammate or pet is targeting it. Scatter's aura is included in the global breakable-control guard so all three damage rotations hold spreading damage around it.

Sources reviewed:
- https://www.wowhead.com/ptr/spell=213691/scatter-shot
- https://warcraft.wiki.gg/wiki/Scatter_Shot
- https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-talents-and-builds
- https://www.icy-veins.com/wow/survival-hunter-pvp-talents-and-builds
- https://www.icy-veins.com/wow/marksmanship-hunter-pvp-guide
- https://worldofwarcraft.blizzard.com/en-us/news/24244455

## 1.4.49 BM Midnight Season 2 Cobra Fang thresholds — 2026-10-13

The current 12.1 BM rotation guide documents a hero-tree-specific single-target tier-set breakpoint: spend Cobra Fang before Barbed Shot at three stacks for Pack Leader and four stacks for Dark Ranger. Its AoE priority spends Cobra Shot whenever Cobra Fang and Beast Cleave are both active. The BM planner now represents all three branches explicitly and tests the two single-target thresholds independently.

Source reviewed:
- https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-rotation-cooldowns-abilities

## 1.4.50 MM Sentinel Trueshot sequencing — 2026-10-13

The current 12.1 MM single-target priority places Aimed Shot ahead of Rapid Fire during Trueshot when Precise Shots is absent, and schedules Moonlight Chakram at roughly five seconds remaining on Trueshot. The planner now reads the Trueshot aura and remaining duration, holds Chakram during the early window, spends it at five seconds or less, and preserves normal outside-window use. Unknown active-aura duration holds Chakram rather than guessing early.

Source reviewed:
- https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities

## 1.4.51 Survival sustained Takedown — 2026-10-13

Current 12.1 Survival guidance and the bundled SimulationCraft profiles both place Takedown in the ordinary single-target and cleave priority, including an unconditional late fallback. The prior planner used it continuously in PvP but still required a burst flag for most PvE paths. The planner now prepares an imminent non-Twin Takedown with Kill Command below two Tip stacks, spends it with a valid Tip/Twin state in every activity, and retains a normal native-availability fallback. This closes a sustained PvE cooldown-usage gap without mixing activity profiles.

Sources reviewed:
- https://www.icy-veins.com/wow/survival-hunter-pve-dps-rotation-cooldowns-abilities
- bundled work/hunter_Survival.simc actions.plst, actions.plcleave, actions.sentst and actions.sentcleave

## 1.4.52 MM Dark Ranger Precise Shots — 2026-10-13

The 12.1 Dark Ranger single-target and AoE priorities, plus the bundled SimulationCraft `drst`/`draoe` lists, place Black Arrow at the top when Precise Shots is active. The shared MM planner previously delayed it behind several Sentinel-shaped priorities. A hero-tree-gated branch now spends Precise Shots with Black Arrow before Explosive Shot, Volley, Rapid Fire and Wailing Arrow. A separate regression proves Sentinel cannot enter this branch.

Sources reviewed:
- https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities
- bundled work/hunter_Marksmanship.simc actions.drst and actions.draoe

## 1.4.53 BM Dark Ranger PvP Barbed setup — 2026-10-13

The current 12.1 BM PvP opener uses Black Arrow, two Barbed Shots, and then Bestial Wrath before the healer-control chain. A PvE-only Dark Ranger talent condition could suppress the first Barbed setup when the pet had already reached the kill target. PvP now bypasses that PvE condition in Arena, battlegrounds, and world PvP; the confirmed/recent first-shot guard still controls the second shot and the no-charge fallback still releases Bestial Wrath.

Source reviewed:
- https://www.icy-veins.com/wow/beast-mastery-hunter-pvp-rotation-and-playstyle

## 1.4.54 Arena Trap harmless-debuff classification — 2026-10-13

Project Sylvanas exposes aura rows but no verified generic periodic-damage classifier. The trap planner previously rejected every healer debuff except the Hunter's own setup stun, which meant harmless Hunter's Mark, Concussive Shot, or Wing Clip could suppress a valid control window. The safety gate now has a deliberately small allowlist for those three known non-damaging effects. Unknown debuffs remain blocked, as do breakable control, immunity, damage immunity, hostile targeting, movement without setup stun, and unsafe DR.

Platform pattern reviewed:
- installed Project Sylvanas `ar_runtime.lua` clean-for-breakable implementation

## 1.4.55 Midnight combined-aura compatibility — 2026-10-13

The Hunter aura reader now follows the positive-evidence rules proven by the installed 12.1 compatibility layer. It checks the native manager first, then `get_auras`, the relevant legacy buff/debuff list, and `get_all_buffs`; accepts `spell_id`, `buff_id`, `debuff_id`, or `id`; and reads common remaining-duration and stack fields. A positive combined-list row overrides a stale manager false. Missing or protected data with no positive row remains unknown rather than becoming false. This improves proc, defensive, crowd-control and hero-tree visibility across all profiles without speculative casts.

Platform reference reviewed:
- installed Project Sylvanas `ar_aura.lua` Midnight compatibility layer

## 1.4.56 adaptive cast acknowledgement — 2026-10-13

Project Sylvanas documents `register_on_spell_cast_callback` as the structured
callback for successful casts and its confirmed sequence helper advances only
after that server acknowledgement. Its current game-event documentation also
identifies `UNIT_SPELLCAST_SUCCEEDED`, rather than `STOP`, as the completion
signal. The engine therefore continues matching exact spell IDs and target GUIDs,
but now measures successful acknowledgement delay and smooths it into a bounded
1.2–3.0 second pending deadline. A six-second busy-cast ceiling remains for live
hard casts and channels. This reduces false retry backoff during latency spikes
without permitting an unbounded stall.

Sources:
- https://docs.project-sylvanas.net/dev/api/core/
- https://docs.project-sylvanas.net/dev/api/events/
- https://docs.project-sylvanas.net/dev/api/spell-sequence-helper/

## 1.4.57 fractional charge protection — 2026-10-13

Current Project Sylvanas spellbook documentation confirms that
`get_spell_charge` is integer-only, the charge recharge duration is seconds,
and a separate recharge start timestamp is available. Current Midnight
SimulationCraft Hunter action lists use fractional charges and full recharge
time to avoid charge waste. The snapshot now derives a bounded fractional value,
normalizes legacy millisecond start timestamps, and falls back to the integer
count whenever timing data is absent. BM uses it for Barbed Shot and Kill
Command, MM for Aimed Shot, and Survival for Wildfire Bomb; no charge rule can
cross into a foreign spec.

Sources:
- https://docs.project-sylvanas.net/dev/api/spellbook/
- https://github.com/simulationcraft/simc/tree/midnight/ActionPriorityLists/default/hunter

## 1.4.58 native charge evidence — 2026-10-13

The five-second persistent diagnostic now records the raw charge count, maximum,
recharge start, recharge duration and computed fractional value for Barbed Shot,
Aimed Shot or Wildfire Bomb according to the detected spec. This does not change
combat priority. It makes native timestamp compatibility and charge-cap decisions
visible in retained logs after a crash or disconnect.

## 1.4.59 native player-control execution gate — 2026-10-13

The retained BM Arena log contains tight clusters where unrelated damage,
utility and defensive abilities all receive `UNIT_SPELLCAST_FAILED`. Project
Sylvanas documents `spell_book.is_player_in_control()` specifically for detecting
stun, fear and incapacitation. Version 1.4.59 snapshots that value for diagnostics
and rechecks it inside `ready()` immediately before every input. Only a confirmed
`false` blocks execution; missing API data remains fail-open. This addresses the
observed multi-spell failure burst without guessing crowd-control auras.

Source:
- https://docs.project-sylvanas.net/dev/api/spellbook/

## 1.4.60 bounded multi-action failure circuit — 2026-10-13

The enhanced retained-log analysis identified 13 Arena clusters containing at
least three different failed actions within 0.75 seconds. Version 1.4.60 records
failure-time native control, busy and GCD state and opens a one-second execution
circuit after three distinct failures in that window. The circuit clears itself,
and resets on every spec, activity, role or player scope transition. Per-spell
exponential retry remains in place. This protects the Arena decision cadence
when the native control flag is delayed without permanently pausing combat.

## 1.4.61 Lightblossom Trinity boss-helper correction — 2026-10-13

The current October 12 Blinding Vale guide and encounter-journal sources identify Meittik, Lekshi and Kezkitt as the three targetable members of Lightblossom Trinity. The prior Meittik card incorrectly used Ikuzz’s Bloodthirsty Gaze/root-kiting instructions, while Lekshi and Kezkitt fell back to generic guidance. All three now share the correct beam-soak, loam-avoidance and stacked-cleave card. Current Bedrock Slam, Fertile Loam, Lightsower Dash, Lightbloom Overgrowth, Thornblade and Light Bolt cues were added.

Sources:
- https://www.icy-veins.com/wow/blinding-vale-dungeon-guide
- https://warcraft.wiki.gg/wiki/Lightblossom_Trinity
- https://www.wowhead.com/npc%3D243028/meittik/heroic-encounter-journal

## 1.4.62 runtime performance audit — 2026-10-14

Project Sylvanas documents `get_all_objects()` as a comprehensive and computationally expensive query and recommends `common/utility/unit_helper` for cached, filtered unit retrieval. The combat snapshot now requests enemies within 80 yards from `unit_helper:get_enemy_list_around()` and keeps the full object-manager walk only as a compatibility fallback. A regression test proves supported runtimes never invoke the full scan.

The update path now reads each unit position once per snapshot and reuses it for distance, AoE, target, and PvP overlay decisions. Repeated player, pet, and target aura requests are cached for the lifetime of one 100 ms snapshot. The per-frame PvP overlay consumes that snapshot instead of re-reading validity, position, and line of sight every rendered frame. Static render colors are cached rather than recreated every frame.

Routine diagnostic records are grouped into at most one native write per 250 ms unless the queue reaches 8 KB. Logout, world transitions, death, combat transitions, API errors, and the GUI SAVE NOW action force a synchronous flush. This preserves useful crash/disconnect recovery while removing per-record disk writes from the combat decision path. Five-second heartbeat records now include moving-average and session-maximum tick and snapshot durations for live hitch diagnosis.

Sources:
- https://docs.project-sylvanas.net/dev/api/object-manager/
- https://docs.project-sylvanas.net/dev/api/core/
- https://docs.project-sylvanas.net/dev/api/ui/
- https://warcraft.wiki.gg/wiki/OnUpdate

## 1.4.63 customer controls and hotkeys — 2026-10-14

The main customer window now uses twelve stable pages: Core, Damage, Burst, Control, Defense, Pet, Mobility, PvP, Spec, Boss Guide, Display/Logs, and Hotkeys. The functional pages keep specialization and activity controls isolated. Every boolean feature exposes its saved ON/OFF control and a bind button; the Hotkeys page provides a consolidated list for the active profile.

One persistent native `core.menu.keybind` is created per feature outside render callbacks. The chosen key toggles that feature only in the currently active specialization/activity profile. Held-key edge detection prevents repeated toggles, F1 and F7 remain reserved for the two existing windows, Escape clears a bind, and assigning an occupied key clears the older assignment. This follows the current Project Sylvanas requirement that menu objects be constructed once rather than recreated while rendering.

New customer controls are connected to runtime behavior rather than being display-only: execute priorities, training-dummy activation, manual-cast yielding, immediate channel stops, CC interrupt fallback, predictive health, teammate Roar, critical-pet Exhilaration, PvP kiting, target/healer world lines, boss world cues, boss auto-popup, and performance telemetry can each be disabled independently.

Sources:
- https://docs.project-sylvanas.net/dev/api/ui/
- https://docs.project-sylvanas.net/dev/api/input/
- https://docs.project-sylvanas.net/modules/control-panel/

## 1.4.64 major-city practice-dummy coverage — 2026-10-14

The shared snapshot now recognizes major-city practice targets for Beast Mastery, Marksmanship, and Survival through the current native `unit:is_dummy()` result, Project Sylvanas `unit_helper:is_dummy()` database, legacy capital-city NPC IDs, and conservative name fallbacks. Covered names include Training Dummy, Raider/Dungeoneer/PvP/Cleave variants, Target Dummy, Combat Dummy, Damage Dummy, Tanking Dummy, Healing Dummy, Training Bag, Kelpfist, and Crystalmaw. The NPC fallback covers IDs 30527, 31144, 31146, 46647, and 114832 when localized names prevent text matching.

The logic bypasses the normal threat/manual-attack requirement only for a positively identified dummy. It stays limited to World PvE, retains spec isolation, honors the per-profile Training Dummy toggle, suppresses synthetic execute/TTD behavior from dummy health, and still allows a genuine Deathblow proc. Friendly healing dummies are recognized but remain ineligible damage targets because the existing enemy check is unchanged.

Sources:
- https://docs.project-sylvanas.net/dev/libraries/mini-libs/unit-helper/
- https://docs.project-sylvanas.net/dev/libraries/izi/izi-object-extensions/
- https://warcraft.wiki.gg/wiki/Training_Dummy
- https://warcraft.wiki.gg/wiki/Contender%27s_Gate
- https://www.wowhead.com/npc=46647/training-dummy
- https://www.wowhead.com/npc=114832/pvp-training-dummy

## 1.4.65 premium Hunter navigation redesign — 2026-10-14

The main window now follows the attached reference's information hierarchy: a strong title bar, persistent left navigation, activity context inside the content card, wide option rows, explicit toggle and bind controls, and paired threshold cards. No reference artwork or brand assets were copied. The plugin continues to use its own embedded Hunter portraits and icon atlases, with BM green and bronze pack styling, Marksmanship blue and silver Windrunner styling, and Survival orange and iron spear styling. Every page continues to filter controls through the detected specialization and selected activity.

## 1.5.0 WoW Forever runtime and rotations — 2026-10-15

Project Sylvanas documents `core.get_game_version()` returning `Forever` and `core.get_exact_game_version()` returning `wow_forever_beta_us`. Those values now select a separate runtime before combat modules initialize. Current Forever build data identifies the 1.60.1 beta family, Classic-style mana, ranked shots, ranged dead zone, in-combat traps, Summon Hawk for BM, Sniper Shot for Marksmanship, and Strider Kick/Lacerating melee gameplay for Survival. Distinct modules and persistence namespaces prevent cross-client updates from changing the other client's priorities.

Sources:
- https://docs.project-sylvanas.net/dev/api/core/
- https://www.icy-veins.com/wow-forever/beast-mastery-hunter-ranged-dps-pve-guide
- https://www.icy-veins.com/wow-forever/marksmanship-hunter-ranged-dps-pve-guide
- https://www.icy-veins.com/wow-forever/survival-hunter-melee-dps-pve-guide
- https://theforeverera.com/en/guides/classes/hunter/
- https://foreverdb.net/spell/1317257
- https://questing.wiki/wow-forever/spells/

## 1.6.0 WoW Forever deep rotation and PvP audit — 2026-10-15

Sources checked against the current beta:
- Icy Veins Hunter overview and BM/MM/Survival guides (updated October 5, 2026).
- ForeverDB Hunter abilities, builds, PvP guide, and extracted spell pages for Summon Hawk, Sniper Shot, Strider Kick, Aspect of the Beast, Intimidation, Scatter Shot, Mongoose Bite, and Lacerate.

Implemented findings:
- BM tracks confirmed Summon Hawk casts as an 18-second two-Hawk population and reserves mana before refreshing. Arcane Shot no longer competes blindly with Hawk's shared cooldown.
- MM treats Aimed Shot and Multi-Shot as a shared-cooldown choice, uses Multi-Shot at three safe targets, maintains Trueshot Aura, and reserves the four-second Sniper Shot for stationary long-range burst with enough target life.
- Survival swaps to Aspect of the Beast in melee, maintains the verified Lacerate debuff, uses reactive Mongoose Bite/Counterattack before fillers, uses Strider Kick for damage and its speed window, and swaps back to ranged behavior outside melee.
- All specs preserve a configurable mana reserve and avoid Serpent Sting on targets already near death.
- BM/MM use Raptor Strike in the eight-yard ranged dead zone. PvP logic adds Aspect of the Monkey, Wing Clip, Frost Trap, safe undotted MM Scatter Shot, and BM Intimidation cast stops.
- MM Lone Wolf mode no longer automatically recalls or revives a pet.
- Forever-only spell corrections include Lacerate 24118, Mongoose Bite rank 2 14269, Aspect of the Beast ranks, Scatter Shot 19503, Wing Clip ranks, and Aspect of the Monkey 13163.

## 1.6.1 WoW Forever mechanics pass — 2026-10-15

ForeverDB build 1.60.1.70338 data confirmed that Scorpid Sting is now a single-rank 2% attack-hit reduction, Viper Sting has a 15-second cooldown, and Fire and Frost traps occupy separate one-trap categories. Immolation Trap is usable in combat with a 30-second cooldown. Current Hunter ability data also confirms the level progression through the current level-30 cap and later abilities used for forward-compatible rows.

Implemented adaptive sting selection, target mana sampling, separate Fire/Frost trap decisions, configurable Forever sting/trap options, and a post-Feign action hold. Auto Shot automation remains intentionally excluded until the native API can distinguish starting ranged auto-fire from toggling it off.

## 1.6.2 WoW Forever cast and cooldown pass — 2026-10-15

ForeverDB build 1.60.1.70374 confirms that Readiness now resets every other Hunter ability, while Mend Pet occupies five seconds of focused healing. The current PvP guide confirms the eight-yard ranged dead zone, melee-only value of Deterrence, Aspect of the Monkey synergy under melee pressure, separate Fire/Frost trap limits, and the need to preserve mana through long kites.

Implemented target-aware 18-second Hawk accounting so a target swap cannot inherit another target's two-Hawk cap; projected-distance checks now suppress Aimed Shot and Sniper Shot when an opponent is closing into the dead zone before the cast completes. MM can use Readiness during a durable committed burst after Rapid Fire is spent, while all specs can reset Deterrence only during lethal melee pressure. Deterrence no longer fires into spell or ranged pressure, Mend Pet avoids ordinary pressured channels, and Survival preserves its defensive Monkey aspect until the low-health melee condition clears.

Sources:
- https://foreverdb.net/class/Hunter
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/class/Hunter/pvp
- https://foreverdb.net/spell/23989

## 1.6.4 WoW Forever level-cap and simulator pass — 2026-10-15

The beta remains capped at level 30, while Viper Sting starts at 36. Adaptive selection now falls through to Serpent Sting when Viper is not learned. BM follows the level-30 simulator's safe single-target Multi-Shot priority. Survival restricts its 21-second Lacerate to durable targets.

## 1.6.5 WoW Forever Improved Tracking and priority pass — 2026-10-15

Improved Tracking raises Survival damage against the currently tracked creature type by up to 5%. Enemy players are Humanoids, and the current Survival PvP guide explicitly requires Track Humanoids. Survival now maintains it in PvP through its own saved option and hotkey. The option is absent for BM and Marksmanship and inactive in PvE. Hosts exposing tracking as an aura are checked directly; an unknown aura result uses confirmed cast history to avoid repeated requests.

The current level-30 card orders reactive Mongoose Bite first, Strider Kick second, and Raptor Strike third. Survival now follows that explicit cooldown priority after durable Lacerate setup.

Sources:
- https://foreverdb.net/class/Hunter
- https://foreverdb.net/class/Hunter/pvp
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/spell/19883
- https://foreverdb.net/spell/24293
- https://foreverdb.net/sim/hunter/survival

## 1.6.4 WoW Forever level-cap and simulator pass — 2026-10-15

The current beta remains capped at level 30, while Viper Sting starts at 36. Adaptive sting selection now falls through to Serpent Sting when the preferred Viper rank is not learned instead of leaving mana-using targets without a sting. An already active Viper or Scorpid Sting is preserved because only one Hunter sting can occupy the target. Live incoming-physical classification also allows Scorpid Sting against a melee build whose base class alone does not identify its damage type.

ForeverDB's level-30 BM simulation places Multi-Shot ahead of Arcane Shot and reports it as 6.8% of total damage. BM now attempts Multi-Shot on a safe single PvE target rather than substituting Aimed Shot; PvP retains its conservative multi-target gate. Survival now applies its 21-second Lacerate only when the target is forecast to live at least 14 seconds, then prioritizes Raptor Strike ahead of Strider Kick and optional trap damage. This matches the current Survival guide and the simulator's damage shares: Raptor Strike 39.1%, Strider Kick 17.9%, and Mongoose Bite 3.3%.

Sources:
- https://foreverdb.net/class/Hunter
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/sim/hunter/survival
- https://foreverdb.net/spell/3034
- https://foreverdb.net/spell/3043
- https://foreverdb.net/spell/24118
- https://foreverdb.net/spell/1317257
- https://foreverdb.net/spell/136

## 1.6.3 WoW Forever baseline-cooldown and cleave pass — 2026-10-15

The build 1.60.1.70374 Hunter ability table confirms that Rapid Fire is a baseline level-26 Hunter ability rather than a Marksmanship-only spell. Its current tooltip accelerates both ranged and melee attacks, so BM and Survival now use it in durable burst windows as well. Readiness can subsequently reset spent Rapid Fire for every spec; BM also considers spent Bestial Wrath. The reset remains gated by a 15-second target-life forecast to avoid consuming a five-minute cooldown on a dying target.

Current Forever PvE guidance recommends Multi-Shot on packs of two or three and confirms its shared six-second cooldown with Aimed Shot. Every Forever rotation now selects safe Multi-Shot from two targets in PvE. PvP retains a three-target threshold to conserve mana and reduce incidental pressure near control targets. Pet revival is now requested only after attackers are gone and the Hunter is healthy enough to complete the ten-second cast.

Sources:
- https://foreverdb.net/class/Hunter/pve
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/class/Hunter/macros
- https://foreverdb.net/guide/leveling-hunter
- https://foreverdb.net/spell/23989
# 1.6.6 WoW Forever level-aware rotation pass — 2026-10-15

The Forever client currently caps characters at level 30, but its data also
contains future ranks and level-40 talents. The runtime now reads the local
character level directly and applies explicit unlock gates in addition to the
spellbook checks. This prevents future abilities, especially Sniper Shot, from
entering a lower-level priority when client data is partially available.

Current level-30 BM simulation attributes 11.3% of damage to Multi-Shot and
7.6% to Arcane Shot, uses Rapid Fire once per 60-second fight, and does not use
Aimed Shot. The BM priority now follows that model. The current class guide
states that Rapid Fire is used once mana falls below 95%; PvE follows that
threshold, while PvP continues to hold the five-minute cooldown for a kill
window. The build guide also recommends sending the pet after the tank has
threat. The existing Pet-first option now creates a bounded 1.25-second handoff
when a live pet has not reached the target, then releases automatically.

Sources:
- https://foreverdb.net/class/Hunter
- https://foreverdb.net/class/Hunter/abilities
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/class/Hunter/pve
- https://foreverdb.net/class/Hunter/pvp
- https://foreverdb.net/sim/hunter/beast-mastery
- https://foreverdb.net/sim/hunter/survival
- https://foreverdb.net/spell/3045
# 1.6.7 WoW Forever tracking, control, and leveling pass — 2026-10-15

Forever teaches Distracting Shot at level 12, Scare Beast at 14, and Track
Hidden at 24. The new priorities enforce those boundaries directly. BM and MM
activate Track Hidden only against Rogue or Druid players; Survival preserves
Track Humanoids because Improved Tracking raises its damage against players.
Scare Beast targets only the selected hostile pet before this Hunter has put a
Serpent Sting on it, and all three fear ranks are classified as breakable CC so
the damage engine will stop. Distracting Shot is limited to PvE mobs targeting
a healer while the Hunter is at least 70% health and has no current attacker.

The leveling and PvE guides also emphasize that mana pressure changes as new
ranks unlock, and that Serpent Sting should be skipped on trash that cannot
live through most of its 15-second duration. Mana floors now scale by actual
character level, and a measured time-to-die below nine seconds suppresses a new
Serpent Sting application.

Sources:
- https://foreverdb.net/guide/leveling-hunter
- https://foreverdb.net/class/Hunter/pve
- https://foreverdb.net/class/Hunter/pvp
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/spell/1513
- https://foreverdb.net/spell/19885
- https://foreverdb.net/sim/hunter/marksmanship

# 1.6.8 WoW Forever early-level control pass — 2026-10-15

The current leveling guide teaches Aspect of the Monkey at level 4 for enemies
that reach the Hunter, then Concussive Shot at level 8 so approaching targets
take longer to enter melee. The PvP guide uses the same transition: slow the
enemy while it closes, switch to Monkey once melee connects, and apply Wing
Clip before creating distance. The rotation now follows those boundaries for
all three specs. Survival keeps its level-30 Aspect of the Beast damage stance,
but switches back to Monkey during dangerous PvP melee pressure.

Utility unlocks now use explicit character-level checks as well as the native
spellbook. This prevents transient or incomplete spellbook data from requesting
pet recovery, traps, movement tools, or defensive cooldowns before their
documented training or talent level.

Sources:
- https://foreverdb.net/guide/leveling-hunter
- https://foreverdb.net/class/Hunter/pvp
- https://foreverdb.net/class/Hunter/builds
- https://foreverdb.net/class/Hunter/pve
- https://foreverdb.net/spell/13163
- https://foreverdb.net/spell/5116
