SYLVANAS WARRIOR 1.7.0 — OFFLINE VALIDATION
Date: October 15, 2026
Runtime: lupa 2.8, Lua 5.4, bundled Python 3.12

PASS: 41 runtime Lua files compile under Lua 5.4.
PASS: 7,792 behavioral assertions.
Coverage: 24 spec/activity profiles, 62 registered spells,
400 deterministic randomized combat contexts.

Checks include:
- Warrior-only class/client guards and local/global specialization normalization.
- Conflicting or unavailable identity readings and unknown instance states.
- Automatic World PvE/Delve/Dungeon/Mythic+/Raid/Arena/BG/World PvP detection.
- Independent settings and persistent toggle hotkeys across all 24 profiles.
- Foreign-spec rotation, spell, and resolved-override rejection.
- PvP burst holds and disabled-plugin input suppression.
- Validity, engagement, line of sight, facing, usability, cooldown, GCD, charges.
- Area damage protection for breakable CC, idle mobs, and target-centered radii.
- Cleave-buff protection, including hidden aura state after confirmed casts.
- Pending request tracking, rejection backoff, timeout, and success confirmation.
- Identity changes immediately before execution and stale-generation rejection.
- Ally interrupt deferral, changed-cast cancellation, uninterruptible/DR/immune cases.
- Protection-only PvE Taunt, other-tank avoidance, and assigned-role mismatch.
- Confirmed Taunt damage follow-through and stable-threat release.
- Protection mitigation priority, rage reservation, and free Revenge.
- Secret/unknown aura handling, owner validation, and millisecond conversion.
- Fury empowered override checks and Arms Execute/Sudden Death decisions.
- Maximum-health-safe pressure prediction and known-channel defense handling.
- Actual main callbacks: disabled menu, observation, manual hold, mount, class switch.
- Arena-frame healer discovery and arena-only focused-ally Intervene peeling.
- Critical Mythic+ cast ranking and safe multi-caster Shockwave escalation.
- Pull-value cooldown holds for small, short-lived Mythic+ packs.
- BigWigs/ExBoss danger timers, Protection pre-mitigation, and PvP exclusion.
- Disrupting Shout escalation and single-NPC Storm Bolt without player DR data.
- Wrecking Throw absorb thresholds and learned-spell gating.
- Arena trinket memory, off-target Disarm, and focused-ally stun fallback.
- Season 2 exact cast classification and generic localization-safe fallbacks.
- Mountain Thane AoE opener and Arena healer-control isolation.
- Protection Shield Block refresh policy and Arms absorb overwrite prevention.
- Final target-swap and newly-applied crowd-control execution revalidation.
- Delayed automatic stance recovery and pre-combat Battle Shout upkeep.
- Two-minute configurable Arena trinket tracking with native-helper fallback.
- Arms Colossus setup/Demolish windows and Fury 12.1 hero-tree priorities.
- Protection Shield Charge gating and expiring free-Revenge consumption.
- Immediate diagnostic writes, bounded persistent copy, and clean-exit marker.
- Protection and DPS boss-helper routing in detected dungeon modes.
- Saved GUI hold/decision transitions and externally initiated player casts.
- Persistent Protection route recovery and partial-pack despawn accounting.
- Shared numeric bounds across the standard panel, themed GUI, and API setters.
- Activity-specific option visibility across every spec/mode GUI combination.
- Complete help text for every visible profile and global GUI option.
- Rendered guidance, explicit state labels, numeric units, and one-window reuse.
- Full route/pack/boss-card structure and exact pull composition for 8 dungeons.
- Direction geometry, arrowhead rendering, destination markers, positional metadata, and role isolation.
- Saved-log context deduplication based on the live 1.8 MB session log audit.
- Protection-only automatic route location, forward detection, teleport recovery, and backward-jump protection.
- Compact overlay geometry, thin arrow rendering, low-opacity markers, and unobstructed player position.
- Damage-rotation disable enforcement for Arms, Fury, and Protection.
- Midnight 12.1 Arms burst setup ordering around capped Sudden Death.
- Targeted enemy-burst defensive trades across all three specializations.
- Arena healer-first and DR-safe kill-target Storm Bolt control.
- Locale-independent Season 2 critical and priority interrupt IDs.
- Read-only boss-helper refresh while paused and immediate cross-role clearing.
- Native GUI clipboard export, recovery path header, and bounded newest-log tail.
- Arms Rend/proc ordering and distinct Protection Colossus/Thane priorities.
- Off-tank Shield Block charge-cap spending without wasting a lone charge.
- Final target-swap cancellation for target-centered ground cooldowns.
- Cast success/failure confirmation through loader event fields 3 and 4.
- Enabled defaults for every actionable option, with Pause left inactive.
- All seven standard Project Sylvanas global controls in the custom GUI.
- Explicit raid and PvP Taunt rejection under enabled defaults.
- Current Season 2 Mountain Thane AoE opener and single-target builder order.
- Cross-target adaptive ability backoff and immediate success recovery.
- Terminal Arms/Fury resource spending and mitigation-safe Protection Execute.
- Strict burst rejection for missing, invalid, unengaged, distant, or reduced targets.
- Protection defensive-layer rotation with exceptional-pressure override.
- Adaptive idle diagnostic cadence with immediate state-change capture.
- Pummel, Spell Reflection, and Storm Bolt fallback ordering for targeted magic.
- Urgent interrupt arbitration against personal emergency defensives.
- Protection Colossus Demolish activation at three confirmed Might stacks.
- Fury Berserker Stance setup, hidden-aura tracking, and safe restoration.
- Fury Battle Stance fallback when Berserker Stance is not learned.
- Arms Executioner's Precision player ownership and false-target rejection.
- Precombat specialization stance setup before Battle Shout maintenance.
- Encounter-timer runtime isolation across all eight activity modes.
- Warrior-only DPS boss-guide language with recursive foreign-class rejection.
- Character- and dungeon-isolated route persistence with reconnect recovery.
- DPS boss live-cast recognition and multi-timer mechanic selection.
- Bounded boss-prompt persistence through transient provider gaps.
- PvP burst permission separated from explicit manual burst intent.
- Controlled-healer, immune-healer, vulnerable-target, and disabled-gate Arena cases.
- Executed custom-GUI rendering, F1 edge debounce, visibility, and window reuse.
- Indeterminate-login startup recovery and definite class/client rejection.
- Exception-safe header behavior for throwing login-time API reads.
- Arms PvP Avatar-first Colossus setup without the PvE Ravager opener.
- Fury Thane/Slayer PvP opener isolation and active-Avatar duplicate suppression.
- Arena healer-control fallthrough to DR-safe Shockwave on the kill target.
- Arms guarded Intervene sequencing and Fury Arena Charge conservation.
- Targeted spell pressure is controlled instead of wasting Intervene, while
  non-disarmable attack pressure remains eligible for the peel.
- Fury Charge conservation is consistent across Arena, battleground, and World PvP.
- Arms and Fury PvP target/healer line rendering with specialization colors.
- Enemy-healer discovery in Arena, battlegrounds, and World PvP.
- Green visible-healer line, red obstructed-healer line, profile switch, and
  Protection/PvE isolation.

This is mocked behavioral testing, not a live-game result or DPS/survival benchmark.
The real loader, current character/talents/equipment, live encounters, latency,
restricted aura data, and PvP strategy still require live validation.
SYLVANAS WARRIOR 1.0.0 — DUAL-RUNTIME VALIDATION

- All 41 runtime Lua files compile under Lua 5.4.
- Existing Midnight suite: 7,788 assertions across 24 spec/mode profiles.
- Fresh Forever runtime verifies exact client dispatch, ranked spell resolution,
  Arms/Fury/Protection decisions, and strict spec allowlists.
- Static catalog audit rejects selected Midnight hero-talent abilities from the
  Forever registry and Forever-only actions from the Midnight registry.
- Runtime gates prevent Midnight route and boss datasets from executing on
  Forever. Settings, hotkeys, and logs use distinct client-family namespaces.
- No live gameplay was performed. Forever remains a beta and requires live
  confirmation as its builds and API behavior change.

