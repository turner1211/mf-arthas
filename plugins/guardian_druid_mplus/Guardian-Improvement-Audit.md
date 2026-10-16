# Guardian improvement audit — 6.32.0

## 8.11.0 — cross-spec callback and shared-scan audit

- Guardian route, boss, BigWigs, repair, and gathering callbacks now stop before
  doing work unless Guardian is the active specialization.
- Disabled route logic no longer wakes at frame rate, and enabled route scans
  always honor their bounded cadence.
- Balance, Feral, Restoration, and Forever context construction shares one
  short-lived object-manager snapshot across enemy and AoE-safety queries.
- Local TTD history is bounded and stale GUIDs are pruned.
- Header and bootstrap local-player reads retry transient native failures.
- Forever logout logging no longer depends on a still-valid player object.

Current rotation sources checked October 16, 2026:
https://www.method.gg/guides/guardian-druid/playstyle-and-rotation
https://foreverdb.net/class/Druid/pve
https://foreverdb.net/changelog

This update improves the shared party awareness used by predictive defense,
threat recovery, battle resurrection and support healing.

- Use the documented native numeric group role: 0 tank, 1 healer, 2 damage.
- Merge duplicate roster entries before reading role and online metadata.
- Detect unavailable healers and readable healer mana even when only party
  frames provide role information.
- Prioritize dead healers for Rebirth using the merged roster.
- Exclude explicitly offline allies from support healing and dispelling.
- Avoid automatically taking an enemy away from another assigned tank.
- Keep the logger release identifier synchronized with the runtime release.

Rotation reviewed against Method's current Midnight 12.1 Guardian guide:
https://www.method.gg/guides/guardian-druid/playstyle-and-rotation
The existing hero-tree rotation, mitigation reservation and Red Moon priorities
remain in place. No speculative ability IDs or forced form weaving were added.

Validation: 290 simulated behavior checks passed. All modules compile under
Lua 5.1, Lua 5.4 and LuaJIT, including a 32-local reserve check. These checks
do not establish flawless live gameplay.

Live verification still needed: healer death/disconnect recovery, two-tank
encounters, resurrection ordering, real cast/BigWigs timing, and danger-zone
placement on different floors. Record failures with the Guardian-owned logger
so further changes address reproducible behavior.

## 6.87.0 — completed-keystone snapshot retirement

- Clear the persisted route-progress snapshot only after the framework's
  authoritative `CHALLENGE_MODE_COMPLETED` event is verified for the active
  dungeon. This prevents a later restart inside a new key of the same dungeon
  from restoring the completed run's old pull position.
- Preserve saved progress throughout an active run, including reload and crash
  recovery. Completion events for another dungeon remain ignored.

Validation: 404 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom. Live dungeon testing remains required.

## 6.88.0 — current Season 2 must-stop coverage

- Add exact early-interrupt priority for Piercing Hiss, Mass Envenom, Healing
  Breeze, Winter's Shroud and Arc Lightning from current Method and Wowhead
  dungeon guidance.
- Add Evolve as an exact hard-stop priority. Skull Bash is used when the cast
  is interruptible; the existing Incapacitating Roar and faced Typhoon
  fallbacks can stop an eligible non-boss cast when the kick is unavailable.
- Keep unknown casts on the configured late-interrupt timing so the routine
  does not waste stops on unverified spell names.

Validation: 406 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom. Live dungeon testing remains required.

## 6.89.0 — manual input cooperation

- Pause normal automated requests for 0.6 seconds after a confirmed manual
  Guardian spell, matching the proven cooperation behavior in the Protection
  Paladin routine.
- Distinguish confirmed plugin requests from manual casts so normal automated
  rotation casts do not pause themselves.
- Keep the emergency mitigation failsafe active during the yield window, so a
  manual action cannot suppress a critical Barkskin, Survival Instincts or
  Frenzied Regeneration response.
- Add a persisted on/off setting for players who prefer uninterrupted
  automation.

Validation: 409 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom. Live dungeon testing remains required.

## 6.90.0 — expanded current Season 2 priority-control coverage

- Add exact early-interrupt priority for Fel Missiles, Seduction, Felstorm,
  Fel Rage and Chaos Bolt in Murder Row.
- Add Light Bolt Volley, Light Bolt, Warden's Wrath and Lightspore Shot in The
  Blinding Vale, plus Shadowbolt Volley and Mending Void in Voidscar Arena.
- Keep ordinary casts on the player's configured interrupt percentage while
  these guide-verified high-impact casts are stopped immediately.

Sources checked October 13, 2026:
https://www.wowhead.com/guide/midnight/murder-row-dungeon-overview-location-rewards
https://www.wowhead.com/guide/midnight/the-blinding-vale-dungeon-overview-location-rewards
https://www.wowhead.com/guide/midnight/voidscar-arena-dungeon-overview-location-rewards

## 6.91.0 — returning-dungeon control completion

- Add all four current guide-listed Ruby Life Pools interrupts: Ice Shield,
  Frigid Shard, Fiery Blast and Blaze Volley.
- Complete King's Rest priority coverage with Bind Soul, Unholy Mending,
  Poison Nova and Deathly Roar, and prioritize Soothe on Bestial Berserk.
- Complete Temple of Sethraliss coverage with Poison Spit, Essence Disruption
  and Flame Shock, while treating Cytotoxin and Poison Spit as urgent poison
  removals when Remove Corruption can help.
- Preserve the normal late-interrupt threshold for casts that current dungeon
  guidance does not identify as high priority.

Sources checked October 13, 2026:
https://www.wowhead.com/guide/midnight/ruby-life-pools-dungeon-overview-mythic-plus
https://www.wowhead.com/guide/midnight/kings-rest-dungeon-overview-mythic-plus
https://www.wowhead.com/guide/midnight/temple-of-sethraliss-dungeon-overview-mythic-plus

## 6.92.0 — Temple of Sethraliss route-force correction

- Add the omitted physical pack containing two Sand-crusted Strikers to both
  the combined pull plan and its pack-subdivision data.
- Correct the displayed planned total to 689 against the dungeon's required
  687 enemy forces. The earlier table claimed a complete total while omitting
  this pack, which could send the guide to the end short on forces.
- Add a regression that requires the exact two-Striker pack and corrected
  planned-force total.

Compared against the current validated Protection Paladin route data and its
MythicDungeonTools 6.3.6 integrity audit on October 13, 2026.

## 6.93.0 — party interrupt coordination

- Detect real interrupt casts from current party members and reserve their
  hostile target for 0.22 seconds.
- Retry automatically when the reservation expires and the hostile cast is
  still active, so a missed or ineffective party kick cannot suppress Skull
  Bash for the rest of the cast.
- Scope reservations by target GUID and clear them with combat runtime state.
  Interrupts from non-party players cannot affect Guardian decisions.

## 6.94.0 — overlapping mechanic-chain defense

- Count distinct recognized damaging BigWigs mechanics that land inside the
  configured forecast window rather than reducing the entire chain to one bar.
- Escalate predictive pressure for the second and third overlapping events
  while retaining the tank mechanic as the primary warning.
- Deduplicate repeated bars by spell identity so localized duplicates cannot
  manufacture a false defensive emergency. Unknown and movement mechanics
  remain excluded from defensive pressure.

## 6.95.0 — Patch 12.1.5 Labyrinth and Kindo'jan support

- Recognize the Labyrinth of Kindo'jan as Delve-style content through stable
  zone ID 16913 and an English instance-name fallback when the host's Delve
  flag has not yet been updated.
- Preserve companion threat, solo Delve pressure and survival behavior while
  pausing M+ route guidance with an explicit `Labyrinth mode` status.
- Detect Kindo'jan through NPC 266600 and show a role-aware phase guide.
- Read Disgraceful Display aura 1303494 and display the live 0/3 failure count,
  escalating the warning at two failures. No countdown is invented because
  current LittleWigs data exposes no reliable boss timer bars for the fight.

Sources checked October 13, 2026:
https://worldofwarcraft.blizzard.com/en-us/news/24304162/
Current installed Protection Paladin v6.13.62 Kindo'jan and Labyrinth audit.

## 6.96.0 — manual-input tank safety

- Manual spell input still pauses ordinary automated damage for 0.6 seconds,
  but it no longer creates a tanking blind spot.
- The bounded manual-safety path can maintain urgent Ironfur, interrupt a
  verified engaged caster, or Growl a confirmed party aggro loss.
- It cannot deal damage, move, face, change forms, dispel, resurrect, or heal
  party members, preserving direct player control during the yield window.
- Crash recovery remains on the stricter defensive-only failsafe and cannot
  acquire or act on enemy targets.

Reference implementation audited:
the installed Protection Paladin v6.13.64 manual-input tank-safety path.

## 6.97.0 — current Druid of the Claw Ravage priority

- A live Ravage replacement above 60 Rage now precedes ordinary Thrash, as in
  the current Patch 12.1.5 Druid of the Claw standard priority.
- Initial multi-target contact still opens with Thrash for snap threat, Red
  Moon still gives Mangle priority, and missing Ironfur still reserves Rage.
- This also restores the timely Ursoc's Fury shield produced by the empowered
  offensive spender rather than delaying it behind a routine generator.

Source checked October 13, 2026:
https://www.method.gg/guides/guardian-druid/playstyle-and-rotation

## 7.0.0 — four-specialization Druid suite

- Expanded the class-only loader to Balance, Feral, Guardian and Restoration
  with exact specialization auto-detection.
- Added separate Balance, Feral and Restoration engines, themed windows,
  persisted settings namespaces, current/previous logs and crash debuggers.
- Added profiles for world PvE, dungeons, Mythic+, Delves, world PvP and
  battlegrounds on all four specs. Balance, Feral and Restoration also support
  arenas; Guardian is explicitly blocked there as requested.
- Added current 12.1.5 resource, DoT/HoT, cooldown, triage, interrupt, dispel,
  combat-resurrection and DR-aware PvP control priorities.
- Added engaged-target validation, crowd-control-safe area actions, spell
  readiness, GCD/cast protection, retry backoff and manual-input yielding.
- Guardian retains its independent tank runtime, M+ Auto Dungeon router and
  boss helper. Its logger no longer initializes under another Druid spec.

Full design, mode matrix and source list:
`Druid-Suite-README.md`

## 6.69.0 — route stability and runtime resilience

- Idle pack recognition must match across two route scans before changing the
  active pull. A nearby engaged pack still recovers the route immediately.
- Clear a pending route match when the evidence disappears, preventing one
  passing lookalike pack from moving the route guide.
- Refresh the shared object snapshot at the main combat cadence and reduce it
  to twice per second out of combat, cutting redundant world scans.
- Treat failures from the spell usability or cooldown APIs as unavailable
  spell data rather than allowing the rotation update to fail.

Validation: 362 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom. Live dungeon testing remains required.

## 6.70.0 — low-lag threat awareness and interrupt fallback

- Emergency low-lag mode now performs one bounded world-awareness pulse per
  second during combat. This restores detection of loose off-target enemies and
  casters while avoiding full object scans on every rotation tick.
- Deduplicate the shared object snapshot before threat, prediction and
  interrupt consumers inspect it.
- If Skull Bash is unavailable, a verified dangerous non-boss cast can use
  Incapacitating Roar or Typhoon even when the cast has no explicit unit target.
  Generic untargeted casts remain excluded from this fallback.

Validation: 365 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with the local-variable reserve enforced.

## 6.71.0 — healer-resource forecasting and scan compaction

- Low-lag awareness now retains only valid units within 45 yards after each
  one-second world pulse. Distant raw objects are not revalidated every combat
  tick, while the 40-yard utility and 30-yard threat ranges stay covered.
- Verified healer mana at or below 15 percent adds moderate forecast pressure
  while enemies are engaged. This is weaker than a dead or unavailable healer.
- Low healer mana raises the projected-health regeneration threshold by five
  points, allowing Frenzied Regeneration to begin before healer exhaustion
  becomes a crisis.

Validation: 368 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.72.0 — action-pipeline fault containment

- Spell range API faults are treated as unknown range rather than false range.
  An explicit false result still blocks the request normally.
- Cast-input API faults now enter the existing per-spell target backoff instead
  of escaping the rotation and contributing to a five-second recovery pause.
- Low-lag snapshots tolerate temporarily unreadable combat state and boss-frame
  APIs without discarding the prior valid world state or stopping combat logic.

Validation: 371 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.73.0 — crowd-control-safe threat recovery

- Threat selection now applies the same confirmed crowd-control and immunity
  filter used by damage targeting. Automatic Growl will not be spent on a
  controlled enemy.
- A controlled high-priority loose enemy no longer hides another loose enemy
  that is safe to taunt, target and stabilize.
- A temporary nil object-manager result preserves the last valid shared combat
  snapshot instead of creating a false empty battlefield for one update.

Validation: 374 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.74.0 — directional stop control and host compatibility

- Group-stop scans now return the nearest confirmed caster as the directional
  reference for Typhoon.
- Incapacitating Roar remains the first group-stop choice. If it is unavailable,
  the routine corrects confirmed bad facing before requesting Typhoon.
- Truthy non-boolean cast acceptance remains compatible with host API variants.
- Damage-target selection tolerates a temporary boss-frame API failure.

Validation: 377 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with at least 31 local slots of headroom.

## 6.75.0 — verified directional stop execution

- Facing requests now distinguish an explicit client rejection from a
  successful or legacy no-result request.
- Typhoon is withheld when a confirmed rear caster cannot be faced because the
  turn request failed or automatic facing is disabled.
- Incapacitating Roar remains available because it does not depend on facing.

Validation: 379 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.76.0 — protected descent and cast-time defense

- Injured airborne combat can request Barkskin before descending. Barkskin is
  form-safe; Bear Form and all offensive actions still wait for touchdown.
- A verified BigWigs/LittleWigs tank hit within 1.2 seconds can request Barkskin
  while the player is casting or channeling, without interrupting that cast.
- Survival Instincts remains restricted to confirmed Bear Form in the casting
  path, preventing an unsafe form change.

Validation: 381 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.77.0 — descent throttling and single-target burst discipline

- Airborne Barkskin uses the shared defensive request throttle, preventing
  repeated requests during descent when an aura callback is delayed or lost.
- An ordinary lone enemy with unknown lifetime no longer consumes a major
  offensive cooldown without route or pressure evidence when the configured
  minimum pack size is higher.
- Bosses, elites, large packs, dangerous route pulls, long-lived targets and
  severe predicted pressure continue to release burst immediately.

Validation: 384 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.78.0 — healer-confidence damage forecasting

- Incoming heals still clear confirmed heal absorbs before receiving credit.
- A healthy available healer can offset at most 50 percent of forecast damage,
  preserving the established conservative behavior.
- Verified low healer mana reduces the credit cap to 30 percent. A confirmed
  dead or unavailable healer reduces it to 15 percent, retaining limited
  allowance for real off-healing without trusting stale optimistic values.
- The forecast exposes both usable and actually credited incoming healing for
  diagnostics and future log analysis.

Validation: 386 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.79.0 — restored route-force accuracy

- Rebuild completed enemy forces from the persisted completed-pull set as soon
  as a saved dungeon route is restored.
- Reconnecting no longer shows zero completed forces until the next pack dies.
- Skipped pulls remain excluded from completed forces after restoration, so the
  planned and required percentage cannot be inflated by manual route recovery.

Validation: 387 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with 32-local headroom.

## 6.80.0 — pull-specific wipe adaptation

- A confidently identified active pull with recorded prior wipes receives
  Barkskin during the first three seconds of its next engagement.
- The same pull raises the Ironfur target by one stack, capped at eight.
- Both adaptations require the combat target GUID to belong to the matched
  pull, so failures cannot make unrelated enemies consume defensives.

Validation: 389 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with the 32-local reserve check enforced.

## 6.33.0 � prediction and utility follow-up

- Exact known encounter spell IDs override name-based timer guesses. Known
  movement, spread, interrupt, phase and soak timers no longer masquerade as
  tank busters. Unknown spell schools remain unknown.
- Supported encounter tank and party damage timers work with localized labels.
- Confirmed protected threat targets no longer starve safe damage selection.
- Soothe skips confirmed blocked line-of-sight targets and considers others.
- Soothe and Remove Corruption reject explicitly expired/inactive raw auras;
  hidden duration alone does not discard confirmed presence.

Sources checked: current Method Guardian rotation and LittleWigs Nalorakk and
Lightblossom Trinity modules. Existing encounter data supplies spell identities.
https://github.com/BigWigsMods/LittleWigs/tree/master/Midnight

Validation: 300 simulated behavior checks, plus compilation and local-variable
headroom checks. Live gameplay validation remains outstanding.

## 6.34.0 � combat recovery and interrupt priorities

- Keep a safe damage target through the main rotation, including after Growl,
  when a loose enemy has confirmed breakable crowd control or immunity.
- Deduplicate pack units and interruptible casters by GUID so duplicate object
  references cannot fake AoE threat or trigger unnecessary group stops.
- Give supported known interrupt mechanics earlier interrupt eligibility and
  extra selection priority; native interruptibility and reachability still apply.
- Do not infer physical damage from an unknown-school tank timer when deciding
  whether to add an extra Ironfur stack. Existing minimum armor remains intact.
- Respect the BigWigs defensive toggle in the battle-resurrection safety check.

Current sources reviewed:
https://www.method.gg/guides/guardian-druid/playstyle-and-rotation
https://www.method.gg/guides/guardian-druid/talents
https://github.com/BigWigsMods/LittleWigs/blob/master/BfA/KingsRest/Council.lua

Validation: 307 simulated behavior checks plus Lua compilation and 32-local
headroom checks. Further audit remains active; flawless live behavior is not
claimed.

## 6.35.0 � engagement and persistent history

- Automatic combat scans require evidence of party involvement instead of
  accepting any nearby enemy already fighting. Explicit selected combat targets
  and friendly-NPC combat in delves retain their supported behavior.
- Timer countdown animation no longer writes a new persistent log entry every
  fraction of a second for the same mechanic. New mechanics, cancellation and
  actual decision changes remain recorded; the first entry preserves timing.

Validation: 314 simulated behavior checks, including unrelated fights,
positive threat, explicit targeting and timer-history transitions.

## 6.36.0 � route matching and recovery integrity

- Deduplicate native object references by GUID before NPC composition matching.
- Reject fractional/out-of-range saved pull numbers instead of accidentally
  advancing through nonexistent pulls.
- Validate completed/skipped pull tokens and wipe counters before restoration.
- Keep confirmed-death completion and unloaded-object safeguards intact.

Validation: 317 simulated behavior checks, including duplicate route objects
and malformed progress files, plus multi-runtime Lua compilation with local
headroom. Routing remains guidance, not automatic movement or pulling.

## 6.37.0 � live damage-school prediction

Known boss damage timers can use confirmed native spell-book school data for
physical/magic preparation and talented pre-hit regeneration. Missing, failed
or invalid school readings stay unknown. Non-damage mechanics remain excluded.
Repair requests returning false are reported as declined, not accepted.

Source: https://www.method.gg/guides/guardian-druid/playstyle-and-rotation
Validation: 321 simulated checks and multi-runtime compilation/headroom checks.

## 6.38.0 � Guardian logger lifecycle

Switching away from Guardian closes and saves its active combat summary. Death
events from another class/spec cannot overwrite the Guardian death report.
Saved log text and displayed retained text now agree without extra trailing
blank lines. Validation: 323 simulated behavior checks and compiler safeguards.

Live evidence audit: available installed history ends on 2026-10-07 and records
v6.23.1, not the current release. It cannot prove current rotation, defense,
route or encounter behavior. Updated Guardian PvE runs remain required.

## 6.39.0 — Season 2 trash priorities

- Added exact current LittleWigs 12.1 failed-interrupt cast identities wherever
  its Season 2 metadata provides positive evidence.
- Dangerous verified trash casts become eligible for an early Skull Bash while
  ordinary casts retain the configurable late-interrupt timing.
- Remove Corruption prioritizes exact dangerous poison/curse consequences,
  then the most injured eligible ally, instead of depending on roster order.
- Native interruptibility, party engagement, range and line of sight remain
  mandatory; the priority table cannot make an invalid cast actionable.

Source: https://github.com/BigWigsMods/LittleWigs
Validation: 328 simulated behavior checks plus Lua 5.1, Lua 5.4 and LuaJIT
compilation with the 32-local headroom check.

## 6.40.0 — Soothe target priority

- Soothe evaluates every reachable engaged enrage instead of returning the
  first object-manager entry.
- The exact King's Rest Ancestral Fury enrage receives top priority from the
  current LittleWigs source; enemies attacking the healer receive secondary
  priority, followed by the current target.
- Duplicate objects and explicitly inactive/expired auras are ignored.

Validation: 332 simulated behavior checks and the compiler/headroom suite.

## 6.81.0 — defensive fault recovery

- The existing five-second rotation recovery pause now retains a minimal health-based defensive safeguard.
- Critical Bear Form health can use Survival Instincts, moderate danger health can use Barkskin, and low Bear Form health can use Frenzied Regeneration.
- The safeguard cannot attack, retarget, move, or change forms. Defensive requests retain the normal aura, cooldown, and request-throttle checks.

## 6.82.0 — predictive defense during fault recovery

- The minimal recovery safeguard now preserves verified BigWigs/LittleWigs
  tank-hit timing during the existing five-second rotation pause.
- An imminent verified tank hit can pre-cast Barkskin while health is high and
  can escalate to Survival Instincts at lower Bear Form health.
- Unknown timer text cannot spend a defensive, and recovery still cannot
  attack, retarget, move, or change forms.

## 6.83.0 — route-state integrity audit

- Position recovery now excludes both completed and manually skipped pulls, so
  reconnecting beside an old pack cannot undo a player correction.
- Restored progress removes conflicting completed/skipped markers and advances
  past any outcome already resolved in the saved snapshot.
- Next at route completion cannot create an out-of-range skipped entry, and
  later-pull recovery no longer labels an already completed pull as skipped.
- The embedded roster still matches Blizzard's current eight-dungeon Midnight
  Season 2 pool: Altar of Fangs, Murder Row, Den of Nalorakk, The Blinding
  Vale, Voidscar Arena, King's Rest, Ruby Life Pools, and Temple of Sethraliss.

Current roster sources checked:
https://worldofwarcraft.blizzard.com/en-us/news/24280285/
https://worldofwarcraft.blizzard.com/en-gb/news/24294369

## 6.84.0 — live-log route recovery

- A partially killed pull can no longer pin the router for the rest of a
  dungeon when its final bound object unloads.
- Recovery requires three independent facts: at least one confirmed death in
  the bound pull, no bound enemy still live, and a later saved pull actively
  fighting the party within the existing 35-yard recovery range.
- The unresolved pull is marked skipped rather than completed, so its missing
  enemy awards no estimated forces. A fully unconfirmed unloaded pack remains
  locked and cannot auto-advance.
- October 13 patch 12.1.5 keeps the same eight-dungeon pool. Current tuning is
  numerical/ability tuning and does not invalidate embedded NPC compositions.

Sources checked:
https://worldofwarcraft.blizzard.com/en-us/news/24307306/
https://www.wowhead.com/news/mythic-dungeon-tuning-with-weekly-reset-altar-of-fangs-nerfed-383388

## 6.85.0 — Elune Moonfire maintenance correction

- Elune's Chosen now restores a genuinely missing or expiring Moonfire before
  ordinary generators, matching the current 12.1.5 maintenance priority and
  restoring Scintillating Moonlight's defensive value promptly.
- Ordinary Elune Moonfire filler still remains behind Mangle as required by
  the current guide. Pack-entry Thrash still leads DoT maintenance for snap
  threat when multiple enemies first engage.

Source checked October 13, 2026:
https://www.method.gg/guides/guardian-druid/playstyle-and-rotation

## 6.86.0 — keystone lifecycle correction

- Project Sylvanas documents no active challenge as `nil`. The router now
  normalizes that state and reliably detects the following challenge start.
- Entering a new key resets old progress even when the same dungeon and
  challenge ID were run previously, preventing stale skipped pulls or route
  position from carrying into a fresh run.
- Loading the plugin while already inside an active key remains distinct and
  can still restore that run's saved progress.

API source checked:
scripts/.api/core.lua — core.world.get_active_challenge_map_id

# 8.10.0 — startup boundary and Forever TTD audit

- Startup now waits for a valid local Druid and conclusive client telemetry.
  Empty login-time handles and version strings are retried instead of silently
  disabling the suite or caching the wrong client family.
- The Forever runtime revalidates class, client, and generation at every
  callback boundary, preserving client isolation after reloads.
- Forever duration-aware cooldown and finisher rules now have a local,
  GUID-scoped health-loss estimator when native time-to-die is unavailable.
- The October 16 Forever build 1.60.1.70425 changes several Druid spell effects,
  including Bear Form, Dire Bear Form, Faerie Fire, and Moonkin Aura. The audit
  found no verified spell-ID or unlock change that justified speculative
  rotation-table edits.

Sources checked October 16, 2026:
https://foreverdb.net/changelog/1.60.1.70425
https://foreverdb.net/class/Druid
https://www.method.gg/guides/guardian-druid

