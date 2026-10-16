## v1.61.45 Searing Glare pressure peel

- A talented Searing Glare now provides a fallback when two or more melee attackers commit burst into the Paladin.
- Blinding Light remains the first multi-attacker peel when it is available and DR-safe.
- Searing Glare is held against ordinary single-attacker pressure.

## v1.61.44 authoritative PvP burst resources

- Targets from 21% through 60% health now obey the configured PvP burst minimum Holy Power.
- A true 20% execute or confirmed hard stun still commits immediately as documented.
- The slider now controls every ordinary low-health burst instead of being bypassed at 60%.

## v1.61.43 Herald AoE charge protection

- Herald AoE now spends capped Hammer of Wrath charges before an Art of War Blade.
- Herald single target retains Art of War before capped Hammer charges.
- The split applies to PvE only and does not alter Arena priorities.

## v1.61.42 hero-specific PvE generators

- Templar PvE now uses ordinary Blade of Justice before Hammer of Wrath, matching the current single-target priority.
- Herald PvE retains Hammer of Wrath before ordinary Blade because its hero interactions favor Hammer.
- PvP generator ordering is unchanged.

## v1.61.41 Herald Wings Hammer priority

- In PvP Herald Wings, Hammer of Wrath now runs before the capped finisher because Walk Into Light also delivers Blade of Justice.
- This intentionally accepts Holy Power overcap for the combined Hammer, Blade and Judgment-maintenance value.
- Templar keeps its normal capped-spender priority.

## v1.61.40 resilient Arena opener

- Judgment and Blade opener stages advance only after the framework accepts the requested cast.
- Temporary range, readiness or client rejection no longer silently skips Greater Judgment or Holy Flames setup.
- Missing talents still skip cleanly so the opener cannot deadlock.

## v1.61.39 Herald Wings damage correction

- Herald no longer hardcasts Blade of Justice from either maintenance or filler logic while Wings is active in PvP.
- Hammer of Wrath, Judgment, finishers and safe fillers remain available during the window.
- The existing pre-Wings opener still applies Holy Flames before committing the burst package.

## v1.61.38 Arena resource-bank efficiency

- At three Holy Power, the pre-burst bank continues using a safe generator instead of idling the rotation.
- At four Holy Power, the bank still holds spenders and generators for the configured preparation window.
- Five Holy Power, execute pressure, active Execution Sentence and active burst continue to bypass the hold.

## v1.61.37 expiring Hammer protection

- A free Light's Deliverance Hammer of Light now checks its remaining aura time before waiting for Wings.
- The routine consumes the free Hammer when the proc would expire before Wings plus a safety margin.
- Proc alignment remains active when the aura duration is unknown or safely covers the cooldown.

## v1.61.36 Arena debuff-aware damage

- A build with Expurgation now applies Blade of Justice first on a fresh or newly swapped Arena target.
- Once Expurgation is active, Judgment returns to its ordinary higher sustained priority.
- Builds without the Expurgation talent retain Judgment-first sustained pressure.
- Capped Art of War/Righteous Cause and Hammer charges still override the maintenance branch.

## v1.61.35 Arena damage-priority correction

- Arena openers apply Judgment before Blade of Justice so Greater Judgment is established before the main damage package.
- The opener tracks its two stages across update ticks and resets cleanly after combat.
- Sustained Arena damage now prefers Judgment over an ordinary Blade of Justice, matching the current PvP priority.
- A capped two-stack Art of War or Righteous Cause proc still takes priority, and capped Hammer of Wrath charges remain protected.

## v1.61.34 Arena ranked-decision upgrade

- Arena Rebuke now honors both the configured cast-percentage threshold and a configurable final commit window, reducing early kicks into fake casts and Precognition.
- Interrupt scans include native arena targets even when they are absent from the ordinary object list.
- Blinding Light can create an off-target healer CC window when the kill target is vulnerable, Holy Power is prepared, disorient DR is ready, and the healer is close enough.
- When the friendly healer is controlled and enemies are actively pressuring the Paladin, Divine Protection can be traded early at a hard configurable projected-health threshold.
- The early wall skips a confirmed external damage-reduction effect to reduce defensive overlap.
- The Arena healer-blind feature is enabled by default and exposed in the custom GUI; all three controls are also available in the native framework menu.

## v1.61.26 specialization compatibility and role-aware guidance

- Every Ret identity gate accepts both Project Sylvanas specialization forms: class-local index `3` and global ChrSpecialization ID `70`.
- The normalization covers discovery, delayed startup, framework menu, main GUI, world overlays, and the combat update callback.
- Navigation safety remains per-frame, while repeated path-building requests are capped at 10 Hz to reduce movement jitter and runtime overhead.
- DPS-only mechanic anchors no longer draw destination arrows for tanks or healers on Xathuux, Atroxus, Golden Serpent, M'chimba, or Merektha.
- The two-window guarantee remains unchanged.
## v1.61.25 navigation geometry and control ownership

- Auto movement stops when the client positively reports blocked target line of sight instead of steering into geometry.
- Auto movement yields while rooted, stunned, feared, incapacitated, or charmed.
- Melee stopping distance accounts for up to 8 yards of target bounding radius, keeping navigation at a large boss's hitbox edge.
- Auto facing also pauses behind a confirmed line-of-sight block.
- The universal boss coach prefers the spell-book global specialization ID, then falls back to the player object, fixing solo role and spec labels across framework builds.
- The two-window guarantee remains unchanged.
## v1.61.24 mode isolation and guidance validation

- PvP outnumbered/healer chase holds now run only in Arena, Battleground, and World PvP; they cannot stop Mythic+, Delve, or World PvE movement.
- Auto facing yields while the player manually turns or strafes.
- Active targeted casts with verified movement names are tagged as movement hazards even when no BigWigs movement flag is available.
- The universal boss coach falls back to specialization role for solo tank and healer specs when no group role is exposed.
- Mechanic-object arrows reject positively line-of-sight-blocked anchors and same-named anchors farther than 60 yards.
- The two-window guarantee remains unchanged.
## v1.61.23 movement ownership and predictive boss alerts

- Auto movement yields immediately to WASD or arrow-key input, preventing navigation from fighting the player.
- Auto movement stops during a positively confirmed BigWigs movement hazard that is forecast to hit the player.
- PvE danger observations now retain their action type (`move`, `party`, `tank`, `targeted`, or `other_target`) for logging and movement decisions.
- The boss coach no longer promotes an ordinary elite target to a boss unless its name is in the supported encounter table or the client explicitly reports `is_boss`.
- Boss timers for roar, stomp, inferno, overload, tempest, and volley mechanics receive a blue `DEFENSIVE SOON` alert.
- Destination guidance changes to green `POSITION REACHED` within 2.75 yards of the live destination.
- The two-window guarantee remains unchanged.
## v1.61.22 two-window guarantee

- The Ret plugin creates exactly two custom windows: `ret_paladin_turalyon_200` for the main panel and `ret_paladin_boss_helper_hud_16120` for the compact boss coach.
- The main panel now registers through one render path. The generic render callback is used only when the dedicated window callback is unavailable, preventing duplicate main-window dispatch on clients that fire both callbacks.
- The boss coach keeps one window callback plus a separate world-overlay callback for its line and destination marker; the overlay callback creates no GUI window.
## v1.61.20 boss position and direction coach

- Adds concise position plans for all 28 Midnight Season 2 dungeon bosses.
- Draws a yellow direction line and green destination ring when a matching live mechanic object is exposed, including freight, gateways, snowdrifts, singularities, spires, coffins, adds, and encounter soaks.
- Uses a live boss-relative outward direction for verified run-away and edge-placement mechanics.
- Keeps text-only guidance when the client exposes no trustworthy destination; no static safe coordinates are fabricated.
- Uses live boss casts and BigWigs timing to promote interrupt, movement, soak, and priority-target instructions.
- Remains available on F7 for every class/spec and automatically opens when a boss is detected.

Research reviewed October 10, 2026: current Wowhead Season 2 dungeon overviews, Icy Veins Season 2 dungeon guides, and Method dungeon strategy guides.
## v1.61.11 Sacrifice eligibility

Blessing of Sacrifice requires confirmed party membership or a matching group frame; nearby friendly players and self are excluded. Other support retains its spell-specific eligibility. Reference: https://www.wowhead.com/spell=6940/blessing-of-sacrifice .

## v1.61.10 initialization failure isolation

A failed initialization attempt cannot be repeated by the deferred callback or another main call. Saved startup error is preserved. Reload after correcting startup dependencies. 127 offline checks pass.

## v1.61.9 deferred startup

Saved live startup status showed no player class/spec available at load. Runtime now waits and checks once per second, registering only after Ret identity is confirmed. Repeated main calls after successful initialization are idempotent. Loader delegates identity checks to runtime. 126 offline checks pass. Live login confirmation remains pending.

## v1.61.8 danger cue uncertainty

Green means not targeted, not verified positional safety. Missing movement forecasts no longer generate green safety cues. 125 offline checks pass.

## v1.61.7 documented timer compatibility

Boss guide and danger scanner support BigWigs expire_time, verified against installed scripts/.api/core.lua. Remove an unintended global condition from danger timer scanning. 124 offline checks pass.

## v1.61.6 boss guidance accuracy

Preserve the actual active boss spell name over upcoming addon timers. Priority-add instructions no longer draw a misleading line to the boss. 123 offline checks pass. Runtime verification remains pending.

## v1.61.5 paired encounter detection

Detect Adderis, Aspix, Kyrakka and Erkhart Stormvein individually. Require a live cast/channel before an interrupt instruction. 122 offline checks pass.

Research: https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/paladin_retribution.simc . Its spender/proc conditions differ from the current Method guide; do not translate aura labels to numeric IDs without verifying spell data. Character-specific simulation comparison remains pending.

## v1.61.4 combat input control

Combat auto movement and facing honor the main pause toggle and manual-cast yield. Owned auto movement stops while paused. 120 offline tests pass; actual gameplay validation remains pending.

## v1.61.3 defensive recovery

Confirmed failed/interrupted plugin major defensive requests release their own overlap reservation, allowing an emergency alternative. Newer requests retain their reservation. 118 offline tests passed. Latest available live log remains v1.52.0 without combat casts; current gameplay validation is pending.

## v1.61.2 October 8 audit

Prevent capped Holy Power waste across all six modes; fix Logs button. 117 offline checks passed. Current Method rotation reviewed: https://www.method.gg/guides/retribution-paladin/playstyle-and-rotation . In-game performance remains unverified.

# Retribution Paladin 12.1 — Project Sylvanas

Version **1.61.1**. This package contains a Lua Retribution rotation and a green tabbed control panel drawn entirely at runtime.

## Season 2 role-aware boss coach — 1.61.0

- Covers all 28 bosses in the eight Midnight Season 2 Mythic+ dungeons.
- Detects the current dungeon, active boss, and the player's tank, healer, or damage role.
- Combines live boss casts with the nearest BigWigs/LittleWigs timer and displays a short role-specific instruction.
- Draws a yellow line and boss ring for interrupt or priority-target jobs, a green player ring for confirmed stack/soak jobs, and a red movement warning for dodge or cover mechanics.
- Falls back to an encounter-specific role card when no live mechanic is imminent.
- Logs boss, role, mechanic, action class, timing, and displayed instruction.

The coach never fabricates safe locations. Lines identify authoritative units; exact floor positions are drawn only when the runtime exposes them.

## PvE boss danger aura — 1.60.0

- Adds a default-on PvE danger-zone toggle for Mythic+, dungeons, Delves, and World PvE.
- Draws a red player ground aura when a confirmed active cast, party-wide BigWigs/LittleWigs timer, or incoming-damage forecast says the imminent mechanic can hit the player.
- Draws a green aura when a confirmed imminent boss or tank mechanic is aimed elsewhere or a movement warning has no predicted incoming hit.
- Removes the aura immediately when the active cast or relevant timer ends or leaves the configured warning window.
- Adds hard sliders for warning lead time and visual aura radius.
- Logs every danger-state transition and includes the current state in debugger exports.

BigWigs timers provide timing and labels. The Project Sylvanas health and cast APIs determine player impact; the visual radius is deliberately presented as a status aura rather than an invented encounter hitbox.

## Cross-plugin prediction improvements — 1.59.0

- Reconciles the native unit forecast with the shared health-prediction module and uses the stronger value without adding overlapping damage twice.
- Uses the shared combat-forecast module for target time to die when available, preserving measured health-trend fallback behavior.
- Gives active absorb shields partial credit only for ordinary Word of Glory or Eternal Flame decisions to reduce duplicate support healing.
- Keeps emergency saves tied to unadjusted predicted health.

## Predictive cast-target and healing context — 1.58.0

- Uses an enemy's active spell target as an early pressure signal before the cast lands, with the selected target as a safe fallback.
- Gives confirmed incoming healing partial credit for ordinary Word of Glory or Eternal Flame support decisions to reduce duplicate healing.
- Subtracts active healing absorbs from that queued-heal credit and raises the ally's danger score while an absorb is present.
- Keeps Lay on Hands, Blessing of Protection, and Blessing of Sacrifice tied to raw predicted health because queued heals can fail or be cancelled.
- Stores the new helpers on the existing runtime state table to preserve Lua compiler-local headroom.

## Lazy Ret-only GUI construction — 1.52.2

- Creates no GUI window when the standalone module is discovered on Rogue or another class.
- Constructs the window only after the Ret runtime supplies a positively eligible state.
- Keeps the previous class, specialization, menu, and overlay visibility gates.

## Cross-plugin GUI isolation — 1.52.1

- Starts the standalone GUI window hidden during Project Sylvanas discovery.
- Shows the custom window only after the runtime confirms a valid Retribution Paladin.
- Hides the custom window immediately after changing class or specialization.
- Applies the same Ret-only gate to the framework menu and target/healer overlays.

## Mythic+ prediction and Arena trinket windows — 1.52.0

- Adds a hard zero-to-four-second PvE prediction window for personal defensives and teammate saves in Mythic+, Delves, and World PvE.
- Uses cast end time to fire emergency Rebuke when an interruptible cast has 0.18 seconds or less remaining.
- Requires valid stun diminishing returns before Mythic+ Hammer of Justice backup.
- Wires the supported PvP helper spell feed so confirmed enemy trinket usage is tracked.
- Adds a hard Arena post-trinket pressure window; a recent confirmed trinket can open burst only after the configured Holy Power gate.
- Keeps the cast-time helper table-owned to preserve Lua compiler-local headroom.

## Engagement and support safety — 1.51.0

- Restricts automatic PvE swaps and off-target interrupts to enemies already engaged with the player or party; the manually selected target remains eligible.
- Restricts World PvP off-target swaps to opponents already attacking the player or a recognized ally; the manually selected opponent remains eligible.
- Makes the World PvE team-support switch functional for party healing, cleansing, Freedom, Sacrifice, Protection, and Lay on Hands.
- Includes a valid owned solo companion in Delve and World PvE support triage when the client exposes one through `get_pet`.
- Treats a confirmed tank like a melee teammate for Blessing of Protection and requires the lethal half-threshold before risking threat loss.
- Keeps all new helpers on `runtime_debug` to preserve compiler-local headroom.

## Lua local-limit guard — 1.50.1

- Moves all five named mode damage handlers from `register_runtime` locals into the existing `runtime_debug` state table.
- Restores five function-local slots of compiler headroom while keeping the same mode behavior.
- The regression harness compiles and initializes the complete runtime and asserts that every mode handler is table-owned.

## All-mode combat expansion — 1.50.0

- Adds a true World PvE mode and GUI tab instead of treating outdoor combat as Mythic+.
- World PvE uses normal two-target cleave but reserves major cooldowns for elites, bosses, or three-plus enemies.
- Mythic+, Delve, and World PvE can Rebuke late interruptible casts even when they are absent from the dangerous-cast name list.
- Battleground interrupts heavily prioritize casts aimed at a friendly objective carrier.
- Keeps World PvE automatic target swapping disabled so questing logic does not pull unrelated nearby enemies.

## Dedicated logger and debugger entity — 1.49.1

- Registers `_G.RetPaladinPluginDiagnostics` as the Ret Paladin diagnostics identity.
- Keeps the live log, crash journal, debugger export, and ownership marker under `ret_paladin_plugin` paths.
- Records that the entity is independent from `sylvanas_battleground_bot` and displays the entity name in the Logger / Debugger tab.

## All-mode action coordination — 1.49.0

- Adds one global unresolved-cast gate so different abilities cannot be submitted before the previous request resolves.
- Excludes zero-health teammates from healing and external-defensive targeting when the client has not yet marked them dead.
- Mythic+: ranks urgent priority interrupts ahead of ordinary casts, then uses cast progress and distance.
- Delve: reserves major burst for elites, bosses, or three-plus-enemy pulls instead of ordinary solo mobs.
- Arena: gains clean single-request sequencing and dead-unit support filtering without changing its single-target kill planner.
- Battleground: disables large-fight cleave while the outnumbered survival hold is active.
- World PvP: disables risky cleave during the same outnumbered survival state.

## Unlearned spell protection — 1.48.3

- Resolves Templar Strike and Templar Slash from the learned Crusader Strike replacement instead of requesting talent spell IDs directly.
- Captures `UI_ERROR_MESSAGE` reports containing “not learned” and blocks the correlated spell for five minutes.
- Writes `unlearned_spell_blocked` with the spell ID and client message to the structured logger.

## GUI discovery and initialization repair — 1.48.2

- Makes `header.lua` self-contained so Project Sylvanas can always discover and list the Ret plugin.
- Loads the artwork texture helper independently so an optional asset API failure cannot suppress the entire GUI.
- Reports window initialization failures to the structured logger instead of silently returning.
- Registers the panel on both supported render surfaces with same-frame duplicate protection.

## GUI startup repair — 1.48.1

- Removes the extra top-level Lua local introduced in 1.48.0 that exceeded Lua's 200-local function limit.
- Keeps the reachability checks in the existing runtime state table without changing their behavior.
- Restores rotation compilation, loader startup, GUI registration, logger startup, and debugger startup.

## Reachability and support safety — 1.48.0

- Filters Rebuke and Hammer of Justice targets through confirmed spell range and line of sight before selecting an off-target utility action.
- Applies predictive incoming-damage safety to Blessing of Sacrifice so it does not expose the Paladin when projected health is already unsafe.
- Detects melee teammates before Blessing of Protection and reserves the attack-suppressing immunity for a lethal rescue at half the configured threshold.
- Records projected Sacrifice safety and BoP role triage in the structured logger.

## Enemy target-swap protection — 1.46.0

- Remembers confirmed enemy target changes onto visible teammates for a configurable short pressure window.
- Raises predictive danger and support priority immediately instead of waiting for teammate health to collapse.
- Uses preemptive Blessing of Sacrifice on an eligible newly focused teammate at the configured hard HP limit while requiring the Paladin to remain above 55% HP.
- Counts multiple enemy swaps onto the same teammate as increasing danger and records attacker and swap counts.
- Respects existing external-defensive detection, same-target defensive spacing, range, line of sight and combat cleanup.

## Confirmed healer-lockout kill windows — 1.45.0

- Records a healer school lockout only after a plugin-owned Rebuke receives a confirmed success event.
- Treats that short lockout as a coordinated burst signal even when the host does not expose it as ordinary silence crowd control.
- Requires the normal Holy Power preparation, target protection, range, line-of-sight, incoming-heal and personal-survival gates before committing.
- Clears lockout memory between combats so Arena rounds and separate Battleground engagements cannot inherit stale state.
- Logs the interrupted healer, confirmed duration, remaining lockout and resulting burst-stage transition.

## Coordinated PvP stun planner — 1.44.0

- Separates defensive Hammer of Justice peels from offensive kill setup.
- Emergency peels remain immediate when an attacker is bursting a friendly victim or that victim crosses the configured HP threshold.
- Offensive target or healer stuns require configurable Holy Power, a short combat-opening delay, a valid unprotected kill target and usable burst range.
- Preserves stun diminishing-return checks, local request recovery, line-of-sight/range validation and breakable-control safety.
- Logs whether every committed stun was an emergency peel, healer setup or kill-target setup, and records why an offensive stun was held.

## Confidence-bounded PvP forecasting — 1.43.0

- Requires multiple recent health observations before health-loss forecasting can change target scoring or create a predicted Wings kill swap.
- Falls back to current health plus confirmed incoming healing while the forecast is still learning.
- Clamps projected damage loss to a configurable hard percentage so a noisy frame cannot manufacture an execute opportunity.
- Allows a genuinely low current-health target to qualify for a Wings kill swap even before prediction confidence is established.
- Resets sample confidence after a significant heal or when the rolling observation window restarts.

## Cross-plugin reliability upgrade — 1.42.0

- Ports the Holy Paladin manual-input yield: ordinary automation pauses briefly after a confirmed manual spell while 20% HP emergencies retain control.
- Ports the Rogue target-specific cast recovery: confirmed failures receive exponential retry delays instead of repeating every update.
- Keeps one unresolved request per spell until success, failure, interruption or a latency-aware timeout.
- Learns observed cast-result latency and bounds quiet-event timeout between 1.2 and 3 seconds.
- Clears a successful spell/target failure history immediately and clears all failure state when combat ends.
- Logs manual yield, retry delay, quiet timeout, observed latency and recovery reason.

## Reliable predictive target control — 1.41.0

- Excludes automatic target candidates only when line of sight is positively confirmed blocked.
- Uses projected net health for the current-target execute lock, including observed health loss and confirmed incoming healing.
- Verifies that an accepted automatic target request actually changed the game target; failed changes release their lock after a configurable timeout.
- Uses target hitbox radius when calculating reachability, anti-kite swaps, Wings kill swaps and distance scoring.
- Logs successful swap confirmation and failed confirmation recovery with requested and actual target identifiers.

## PvP burst-quality gate — 1.40.0

- Starts a new cooldown package only when the target is within the configured hard burst range and line of sight is not positively blocked.
- Requires configurable remaining crowd-control time before using target or enemy-healer control as a burst signal.
- Holds a new burst against a non-execute target receiving a configured amount of confirmed incoming healing.
- Genuine execute targets, an active Execution Sentence and an already-active Wings package bypass setup holds so committed damage is not abandoned.
- Logs every range, line-of-sight, incoming-heal and insufficient-control hold as an explicit burst stage.

## Predictive targeting and resource banking — 1.39.0

- Banks three or four Holy Power for a short configurable period while waiting for control or a coordinated burst window.
- Never banks at five Holy Power and never delays an eligible execute spender or active Execution Sentence window.
- Scores PvP targets from projected net health using observed health loss and positively reported incoming healing.
- Uses the same net-health forecast for conditional Wings kill swaps, avoiding targets that are already receiving enough healing to escape execute range.
- Bounds the resource hold with a hard timer so the rotation resumes ordinary pressure if no kill window appears.
- Clears all banking state when combat ends.

## PvP damage planner upgrade — 1.38.0

- Keeps the selected burst package committed while Wings is active, allowing Execution Sentence, Wake and Divine Toll to complete instead of returning to ordinary pressure logic.
- Stops all damage on a selected enemy under positively confirmed breakable crowd control.
- Projects observed enemy health loss for configurable Wings kill-swap decisions instead of relying only on current HP.
- Uses an immediate single-target spender at three Holy Power inside the configured execute threshold.
- Retains immunity checks, Execution Sentence locking, defensive survival holds and crowd-control-safe splash checks.
- Adds hard controls for kill prediction, immediate execute spending and breakable-CC damage pausing.

## Conditional Wings kill swap — 1.37.0

- Keeps the current reachable target locked during Wings under normal conditions.
- Overrides that lock when another valid enemy within eight yards reaches the configured kill-swap HP and is at least twenty percentage points lower than the current target.
- Preserves the Execution Sentence target lock, immunity filtering, breakable-CC safety, manual-target grace, swap cooldown and Battleground objective scoring.
- Logs the current HP, replacement HP, selected enemy and kill-swap reason.
- Adds a hard **Wings kill-swap target HP** slider; zero disables the override.

## PvP damage and kill-window upgrade — 1.36.0

- Prepares a configurable minimum amount of Holy Power before committing cooldowns to healer-control or teammate-burst windows; hard target control and execute opportunities remain immediate.
- Keeps the burst package active after Execution Sentence lands and spends at three Holy Power during its damage window.
- Funnels single-target finishers into an Execution Sentence target instead of switching to cleave.
- Prioritizes Hammer of Wrath in execute range when it can build Holy Power without overcapping.
- Locks a reachable current target while Wings is active so automatic target selection cannot split the cooldown window.
- Converts Battleground and World PvP cleave into single-target pressure at the configurable kill-funnel HP threshold.
- Adds hard framework controls for burst preparation, kill funneling, and the Wings target lock.

## PvP survival triage and healer protection — 1.35.0

- Gives critical self survival priority over teammate saves when projected HP crosses the configured immunity or Lay on Hands limit.
- Preemptively uses Blessing of Sanctuary on a healer under confirmed enemy burst at the new hard HP threshold.
- Cleanses urgent poison and disease effects from the player before spending support globals elsewhere.
- Holds major offensive cooldowns below the new projected self-health threshold while continuing normal pressure.
- Stops automatic target chasing when the healer is dead, controlled, out of range, or behind confirmed line-of-sight obstruction.
- Adds direct framework sliders for healer pre-Sanctuary and burst survival; zero disables each behavior.
- The offline replay suite contains 78 passing checks.

## Predictive PvP defensive engine — 1.34.0

- Forecasts player and teammate HP from confirmed incoming damage and recent health loss over a configurable one-to-four-second window.
- Applies every existing defensive slider as a hard limit against the lower of current or projected HP.
- In PvP, evaluates critical teammate rescue before ordinary personal defensives so Lay on Hands, Protection, Sacrifice, Sanctuary, Freedom, and urgent cleanses are not delayed.
- Adds Lay on Hands to the major-defensive spacing system so it cannot overlap another major save on the same target.
- Logs current HP, projected HP, incoming damage, health-loss rate, chosen spell, and any reason a defensive was blocked.
- The offline replay suite contains 73 passing checks.

## PvP burst stability and objective safety — 1.33.0

- Locks the current PvP target while Execution Sentence is active so automatic swapping cannot waste its final burst.
- Prevents automatic Divine Shield while carrying a Battleground objective and prevents Blessing of Protection on an objective carrier.
- Gives a slowed or rooted objective carrier Freedom before the normal healer-first support order.
- Cleanses urgent three-stack poison or disease effects from objective carriers and healers before ordinary emergency healing.
- Lowers the interrupt timing threshold when an enemy cast is aimed at a teammate at 35% HP or lower.
- Adds structured reasons for every target lock, immunity hold, objective Freedom, and urgent cleanse.
- The offline replay suite contains 69 passing checks.

## PvP control, rescue, and large-fight upgrade — 1.32.0

- Uses Blessing of Sanctuary on the player when supported hard control is positively confirmed.
- Prioritizes Blessing of Freedom for a rooted or slowed healer, then pressured teammates, before ordinary healing globals.
- Adds a hard preemptive Blessing of Sacrifice threshold for healers under confirmed enemy burst.
- Prevents Lay on Hands from being spent into positively confirmed healing immunity.
- Clears local stun or disorient request locks when the corresponding cast fails or is interrupted.
- Enables Divine Storm in Battleground and World PvP fights at three or more enemies only when the breakable-CC safety scan passes.
- Adds framework controls for each new behavior and structured diagnostic events explaining every activation.
- The offline replay suite contains 63 passing checks.

## Resto Shaman and Rogue style logger — 1.31.0

- Writes a standard live log to `scripts_log/ret_paladin_plugin/session.md` while retaining the mirrored crash-safe data journal.
- Correlates accepted plugin cast requests with confirmed success, failure and interruption game events.
- Records cast ownership, result latency, target, mode, and per-combat confirmation totals.
- Flushes the journal during logout and world transitions and exposes live recording status in the LOGS tab.
- The SAVE COPY export includes both exact log paths and the logger status.
- The offline replay suite contains 57 passing checks.

## Logs and copy-ready debugger — 1.30.0

- Adds a dedicated **LOGS** tab containing the persistent logger, live debugger, error controls and export button.
- Press **SAVE COPY** to combine the current debugger state and persistent runtime log into `scripts_data/ret_paladin_plugin/debugger_export.md`.
- Open that text file, copy all contents, and paste them into Codex for diagnosis.
- The always-visible **LOGS / DEBUG** footer button opens the same tab directly.
- The offline replay suite contains 56 passing checks.

## World PvE Flash of Light — 1.29.0

- Casts Flash of Light on the player when entering an eligible open-world PvE context, then enforces a strict 60-second interval between accepted casts.
- Failed or unavailable cast requests retry after two seconds without consuming the interval.
- Never runs in parties, dungeons, raids, Delves, Arena, Battlegrounds or detected World PvP scenarios.
- Pauses while dead, ghosted, mounted or inside a vehicle.
- Records every accepted timed cast in the persistent diagnostic log.
- The offline replay suite contains 55 passing checks.

## PvP player-control upgrade — 1.28.0

- Detects a manual target change and pauses automatic swaps for the configured grace period.
- Adds optional team focus-fire scoring when nearby teammates are attacking the same enemy.
- Stops automatic forward chase while visibly outnumbered and below the configured survival threshold.
- Shows stun and disorient DR readiness for the current PvP target in the debugger.
- Clears target locks, burst stages and local stun/disorient request histories when combat ends.
- Adds enforced settings for manual-target grace, team focus fire and outnumbered chase safety.
- The offline replay suite contains 53 passing checks.

## PvP resilience and uptime — 1.27.0

- Adds configurable anti-kite swaps from a distant target to a valid enemy already in melee range.
- Enters healer emergency peel mode when the healer is controlled, dead or below the configured hard HP threshold; offensive burst pauses while support and pressure continue.
- Gives friendly Battleground objective carriers additional rescue priority.
- Reads Arena dampening when available and prioritizes eligible mitigation before reduced Lay on Hands healing at the configured threshold.
- Adds enemy-burst value to peel target selection.
- Combat summaries now include burst actions, crowd control and defensive/support saves.
- The offline replay suite contains 51 passing checks.

## Crash-persistent logging — 1.26.0

- Keeps logs across logout, reload and the next login instead of starting over.
- Writes actions, errors, warnings, GUI changes and safety events immediately.
- Writes a complete state heartbeat every five seconds so a hard crash loses at most the last few seconds of routine state.
- Mirrors every durable write to `diagnostic_log_backup.md` and restores the longer intact copy at startup.
- Saves `diagnostic_previous_session.md` before appending the new login/reload session.
- Adds wall-clock timestamps and explicit session-start markers.
- Retains up to roughly 750 KB in the live rolling log and preserves a previous-session snapshot before trimming.
- The offline replay suite contains 48 passing checks.

After logging back in, copy the files from `scripts_data/ret_paladin_plugin/`. Start with `diagnostic_log.md`; use `diagnostic_log_backup.md` if the first file was interrupted, or `diagnostic_previous_session.md` to see the snapshot taken before the current session began.

## Advanced PvP coordination — 1.25.0

- Selects the best visible interrupt target without requiring a target swap, prioritizing healer casts and casts aimed at endangered teammates.
- Synchronizes a burst window with a nearby teammate's confirmed offensive cooldown when the kill target is at 85% HP or lower.
- Adds enforced settings for healer interrupt timing, DPS interrupt timing, execute-target lock HP, outnumbered burst-hold HP, objective priority and teammate burst synchronization.
- Adds extra peel value when enemy burst is focused into a teammate or healer.
- Extends the PvP debugger state with the active burst stage.
- The offline replay suite contains 45 passing checks.

## PvP decision engine — 1.24.0

- Keeps vulnerable kill targets through short swap opportunities while still abandoning immunity and major protection.
- Gives Battleground objective carriers strong target priority when the framework identifies them.
- Scores enemies attacking the friendly healer as urgent peel targets.
- Delays ordinary PvP interrupts to resist early fake casts while interrupting healer casts earlier.
- Tracks Blinding Light's disorient diminishing returns separately from Hammer of Justice stun DR.
- Holds offensive burst below 70% HP when visibly outnumbered in Battleground or World PvP and continues defensive/support actions.
- Shows visible enemy count, ally count, healer state and OUTNUMBERED status in the live debugger.
- The offline replay suite contains 43 passing checks.

## Control and input-safety upgrade — 1.23.0

- Adds hard framework sliders for minimum burst TTD, maximum cooldown hold, normal interrupt timing and automatic target-swap lockout.
- Suppresses identical spell/target requests for 120 ms to reduce duplicate native input without delaying normal gameplay.
- Suspends combat decisions while dead, ghosted, mounted in combat or inside a vehicle.
- Prevents automatic target changes during casts and channels.
- Excludes teammates behind a positively confirmed line-of-sight block and respects external damage reduction before adding Blessing of Protection or Sacrifice.
- Uses Blinding Light as a multi-attacker PvP peel only when it will not break nearby protected crowd control.
- Writes a compact action, defensive, support, interrupt and target-swap summary when combat ends.
- The offline replay suite contains 40 passing checks.

## Long-session and targeting upgrade — 1.22.0

- Normalizes interrupt cast progress from either 0–1 or 0–100 framework formats.
- Adds healer death and line-of-sight states to defensive planning.
- Caches object scans at 10 Hz and removes stale health histories, burst stages and encounter state between combats.
- Adds stable Mythic+ and Delve priority targeting for dangerous casts and clear execute opportunities, with a 2.5-second swap lockout and current-target preference.
- Expands regression coverage to 37 passing checks.

## Adaptive combat engine — 1.21.0

- Learns target time to die from rolling health history and carries cooldowns through nearly finished trash, with a five-second maximum hold.
- Aligns Avenging Wrath with an imminent Execution Sentence while preserving Radiant Glory sequencing.
- Stops damage and automatic movement into confirmed protection and treats bosses and elites as durable cooldown targets.
- Scores targets, allies and defensive danger using casts, health trend, incoming damage, pressure, role, range, immunity and crowd control.
- Uses late normal interrupts, early urgent interrupts, PvP diminishing returns and explicit PvP burst stages.
- Shows TTD, danger and the current decision in the debugger, and recovers after repeated runtime errors with a bounded circuit breaker.
- Keeps every defensive and support HP slider as an absolute eligibility limit. The replay suite contains 35 passing checks.

## October 6 rotation audit — 1.20.0

- At three Holy Power, ordinary Hammer of Wrath, Blade of Justice and Judgment now generate before the fallback spender. Four and five Holy Power still spend first.
- Divine Toll can fire at two or fewer Holy Power in packs, accepting unavoidable overflow so its burst cooldown is not delayed indefinitely.
- Templar keeps the current single-target Divine Arbiter Divine Storm swap, including with Seal of the Templar.

These changes follow Method's October 6, 2026 Retribution priority and remain consistent with the current SimulationCraft action list.

## Full audit — October 5, 2026 / 1.19.0

- Corrected Art of War's current aura ID and added Righteous Cause. Capped Blade procs now take priority at four Holy Power, including when Divine Purpose is active.
- Recognizes Radiant Glory's separate Avenging Wrath aura.
- Corrected the earlier Divine Arbiter assumption: it empowers a spender; Divine Purpose supplies a free cast. Existing empowerment is consumed before requesting another proc.
- Empyrean Legacy chooses Verdict in AoE. Seal of the Templar prevents the deliberate single-target Storm swap.
- Separates free Light's Deliverance from paid Hammer readiness and consumes regular spenders at three Holy Power before ordinary generators and fillers.
- Aura readers accept documented `buff_id` rows and continue to raw auras after an empty normal list. Cleanse supports numeric poison/disease types and self cleansing.
- Aura cast tracking only records the local player's confirmed casts.
- Sanctuary prioritizes controlled healers; Freedom also works on the player. CC and stun DR queries use documented helper fallbacks when optional object extensions are absent.
- Enemy healer CC can open a burst window on a healthy kill target. Swaps skip protected or breakable-CC enemies and only record accepted target changes.
- Execution Sentence, Wake, Toll, Hammer, Legacy and consuming Arbiter spenders check for nearby breakable CC in PvP.
- Major defensive spacing is per recipient. Emergency direct healing can follow a mitigation cast; major effects still cannot stack on the same recipient. Divine Shield uses native usability to support Light's Revocation.
- Skinning waits for loot to clear, including queued corpses. Repeated runtime errors are throttled, GUI failures reach the debugger, and covered controls cannot receive clicks through the debugger.
- Removed one redundant full enemy scan and corrected the download archive's installation layout.

The source details, limits and offline verification are recorded in [AUDIT.md](AUDIT.md). In-game performance has not been measured for this update.

## Second full rotation audit — 1.18.0

- The earlier free Divine Arbiter assumption was incorrect and is corrected in 1.19.0.
- Templar uses the immediate post-Wake Hammer of Light without delay.
- The free Hammer alignment rule was corrected in 1.19.0 because free and paid Hammer share a readiness aura.
- The combat opener state now has the correct Lua scope and retains its Blade of Justice step when the first request fails because of range or temporary availability.

This pass rechecked current Method, Wowhead, Icy Veins, Skill Capped, Warcraft Wiki, YouTube, and Reddit material. Community posts and videos were used to locate mechanics that were then cross-checked against current written references before changing the Lua logic.

## Full rotation audit — 1.17.0

- Radiant Glory now places Execution Sentence before Wake of Ashes, allowing Wake to activate Avenging Wrath inside the sentence window.
- Wake of Ashes and Divine Toll now obey the Burst switch in every mode. Arena, Battleground, and World PvP no longer dump those cooldowns outside the selected burst window.
- The earlier three Holy Power Art of War limit was superseded in 1.19.0 by the current capped-proc priority at four Holy Power.
- Herald keeps Hammer of Wrath priority during Avenging Wrath while Templar can consume urgent two-stack Art of War procs.
- Aura stack detection accepts the framework's `buff_id`, `spell_id`, and `id` representations.
- Mythic+ scans nearby enemies for approved priority casts and can Rebuke the caster without changing the selected target.
- Added current Voidscar Arena priority casts `Shadowbolt Volley` and `Demoralizing Shout`.

The audit compared Method, Wowhead, Icy Veins, Skill Capped, Warcraft Wiki, current YouTube guides, and current Reddit discussions. Community sources were treated as leads and applied only when they agreed with current 12.1 guide mechanics or exposed a verifiable code defect.

Version 1.16.1 limits duplicate Devotion Aura detection to another group Paladin within the aura's 40-yard coverage. The live debugger now shows the selected aura plan, and aura-plan changes are recorded in structured diagnostics.

Version 1.16.0 resolves Herald of the Sun's Eternal Flame replacement whenever the rotation requests Word of Glory. It also separates direct emergency healing from major defensive buff stacking: Word of Glory/Eternal Flame and Lay on Hands can heal through an active mitigation buff, while Divine Shield, Divine Protection, Shield of Vengeance, and Blessing of Protection remain mutually protected from automatic overlap.

## Live debugger

Use the **DEBUG** image button in the lower-left area of the custom GUI or enable **On-screen debugger** in Settings. It shows live player HP, Holy Power, combat state, selected target HP and range, detected and active profiles, hero tree, last accepted action, and the latest safely captured runtime error. **CLEAR ERROR** resets the displayed error. Full event details remain in `scripts_data/ret_paladin_plugin/diagnostic_log.md`.

## Warcraft Wiki mechanics applied

- Midnight 12.1 PvP stun diminishing returns use a conservative 20-second per-target lockout when the engine cannot confirm readiness.
- Blessing of Sanctuary can remove confirmed stun, silence, fear, or horror effects from teammates in PvP modes when talented.
- Blessing of Protection remains limited to teammates under confirmed melee pressure because it protects against physical damage.
- Blessing of Sacrifice is held when the Ret Paladin is at 35% HP or lower to avoid unsafe transferred damage.
- Forbearance checks prevent invalid Lay on Hands and Blessing of Protection overlap. Divine Shield uses native usability so Light's Revocation can work.
- Cleanse Toxins remains restricted to confirmed poison and disease effects.
- Herald of the Sun continues to prioritize Hammer of Wrath during Avenging Wrath, matching the current talent interaction.

Mechanics reference: `https://warcraft.wiki.gg/wiki/Paladin_abilities`, `https://warcraft.wiki.gg/wiki/Diminishing_returns`, `https://warcraft.wiki.gg/wiki/Blessing`, `https://warcraft.wiki.gg/wiki/Forbearance`, and `https://warcraft.wiki.gg/wiki/Wake_of_Ashes`.

The GUI uses Lua-drawn Retribution themed badges for damage, burst, control, support, defensives, profile selection, tabs, and global settings. No image asset is required.

The custom panel now renders on Project Sylvanas's independent window layer, so it remains visible during gameplay when the framework settings menu is closed. GUI load and render failures are reported with a `[Ret Paladin GUI]` warning.

## Install

Extract the package into the Project Sylvanas loader folder and allow the `scripts` and `scripts_data` folders to merge. The package keeps the loader entry point, rotation module, GUI module, and artwork at their expected paths.

## Control panel

- Press **F1** to hide or show the panel. Drag its header to move it.
- Use **ROUTINE ON/OFF** to pause or resume combat actions. **AUTO/MANUAL** selects automatic activity profiles or lets you choose one of the five profiles.
- The **MYTHIC+**, **DELVE**, **ARENA**, **BATTLEGROUND**, and **WORLD PvP** pages each have their own damage, burst, crowd-control, target-swap, team-support, and defensive switches.
- **SETTINGS** has switches for movement, facing, target and healer overlays, dungeon routes, auras, fishing, skinning, and out-of-combat looting.
- The current version is shown in a high-contrast badge at the bottom right.

## Target and healer overlays

Turn on **Target line + ground ring** to draw the yellow line to your selected hostile target and a small yellow ring at its position.

Turn on **Healer line** to draw a line from you to the nearest recognized group healer. Green means line of sight is clear, the healer is within 40 yards, and the player is not marked heal-immune. Red means line of sight is blocked, the healer is out of range, or healing is prevented. The indicator cannot see the healer's current cooldowns or cast state.

Both overlay switches are off by default. The healer line uses the framework's healer-role and line-of-sight data; if the client does not expose a group healer, no healer line is drawn.

## Diagnostic log

Structured logging is enabled by default and can be switched off on the GUI **Settings** page or in the framework menu. The rolling file is:

`scripts_data/ret_paladin_plugin/diagnostic_log.md`

Each line contains the client time, severity, category, event, and the observations used for that decision. The log is capped and trims older entries automatically. Routine scans are not repeated unless their result changes.

The logger records:

- **LOAD / ERROR:** plugin version, initialization, and runtime failures. Identical recurring runtime errors are reported at most once per ten seconds.
- **MODE:** detected activity, active profile, manual override, hero tree, and profile title.
- **GUI:** the exact switch or profile field changed.
- **CAST:** accepted spell requests and framework-declined requests, including spell, target, mode, hero tree, player HP, and Holy Power.
- **DEFENSIVE:** current HP versus every configured hard threshold, the recipient's major defensive lockout time, and existing effects that prevented stacking.
- **SUPPORT:** the lowest eligible teammate, HP, pressure state, candidate count, and accepted protection or healing action.
- **INTERRUPT:** accepted Rebuke or Hammer of Justice actions and priority casts that were still active after both options were checked.
- **TARGET:** automatic target swaps with selected target, score, HP, and mode.
- **AURA:** accepted Crusader, Devotion, or Concentration Aura changes.
- **GATHER:** skinning state changes, including loot waits, movement, targeting, accepted requests, and declined requests.
- **ROUTE:** dungeon detection, loaded route, next pull, pull count, and visible target count.
- **OVERLAY:** healer identity, distance, line of sight, heal immunity, and the resulting green/red/no-healer state.

When reporting a problem, reproduce it once and share the section beginning with the latest `MODE` entry through the error or unexpected action. This keeps the report focused while retaining the conditions that led to the decision.

## Dungeon route guide

The rotation includes built-in pull groups for the eight dungeons in the [Winning Warcraft Midnight S2 route hub](https://winning-warcraft.com/routes/midnight-s2/). Route data is embedded in the Lua file and selected from the current instance name. The guide draws yellow route lines, circles around the next live pull, and map markers when the dungeon map is open. It only marks enemies the game client has loaded and does not move the character.

## Source material

The damage priorities were reviewed against [Method](https://www.method.gg/guides/retribution-paladin/playstyle-and-rotation), [Icy Veins PvE](https://www.icy-veins.com/wow/retribution-paladin-pve-dps-rotation-cooldowns-abilities), [SimulationCraft's current Ret priority](https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/paladin_retribution.simc), and Wowhead spell data. Support and PvP checks used [Skill Capped](https://www.skill-capped.com/wowarticles/guides/retribution-paladin-pvp-guide/), [Icy Veins PvP](https://www.icy-veins.com/wow/retribution-paladin-pvp-rotation-and-playstyle), and the [official Sylvanas helper API](https://docs.project-sylvanas.net/dev/libraries/mini-libs/pvp-helper/). See AUDIT.md for YouTube/Reddit leads and access limitations. The GUI artwork is generated cinematic art.
# v1.47 logger-driven reliability update

- Debounces rapidly changing skinning scanner states while keeping `skinning_status.md` current.
- Uses 5-second combat and 20-second out-of-combat heartbeats to preserve more useful history.
- Excludes unrelated manual, item, and external spell results from plugin cast reliability metrics.
- Adds healer-line range hysteresis at the 40-yard boundary.
- Adds per-combat cast failure rate and a warning when plugin failures reach 25% with enough samples.

# v1.53 Mythic+ and Arena update

- Counts only positively engaged enemies when deciding Mythic+ AoE, reducing accidental cleave into nearby unpulled packs.
- Keeps Final Verdict for single-target Seal of the Templar builds instead of actively consuming Divine Arbiter with Divine Storm.
- Adds a bounded Arena target preference for enemies whose PvP trinket was observed within the configured trinket window.
- Preserves Execution Sentence, Wings, execute, crowd-control, immunity, line-of-sight and manual-target protections.

# v1.54 predictive Sacrifice safety

- Uses projected Paladin health for the general Blessing of Sacrifice decision in every PvE and PvP mode.
- Holds Sacrifice when incoming damage would push the Paladin to or below the existing 35% self-safety floor.
- Logs accepted decisions as `predictive_sacrifice` with the projected self-health and active mode.

# v1.55 official health prediction

- Uses Project Sylvanas's pre-impact Health Prediction module for every PvE and PvP profile.
- Keeps native incoming-damage methods and measured health trends as fallback when the module has no observation.
- Feeds one consistent prediction signal into personal defensives, teammate saves, support triage and PvP survival holds.

# v1.56 direct future-health prediction

- Uses IZI's future-health percentage directly with each mode's configured prediction window.
- Records the prediction source in defensive and teammate-triage diagnostics.
- Rejects invalid framework results and retains the incoming-damage plus health-trend fallback.

# v1.57 damage-type and burst prediction

- Uses predicted physical-damage relevance to select Blessing of Protection even when an attacker lacks a melee classification.
- Uses native enemy burst observations when the optional PvP helper cannot provide them.
- Keeps role safety, Forbearance, objective-carrier, existing-defensive and lethal-rescue checks authoritative.

# v1.61.1 Lua-only interface

- Removed every PNG and texture dependency from the runtime GUI.
- The panel, buttons, icons, boss instructions, lines, rings, and danger cues are drawn directly by Lua.
- The distributable contains only Lua and Markdown files.

## v1.61.12 Rogue GUI parity repair

Ported the Rogue panel's font-safe text handling and simple control layout into Ret. Removed nested letter badges that compressed labels, normalized missing font enums to the host's default font, sanitized unsupported characters, and filled the empty left canvas with readable live status cards. The Ret activity tabs and Lua-only package remain intact.

## v1.61.13 reference GUI restoration

Restored the approved Turalyon full-window canvas and reference layout. The artwork is embedded inside `ret_paladin_art.lua`, loaded through `core.graphics.load_texture`, and requires no PNG or external overlay file. Controls remain readable on translucent green surfaces.

## v1.61.14 GUI usability audit

Improved the Turalyon interface after comparing the local Holy Paladin, Resto Shaman, and Rogue panels and reviewing WoW accessibility guidance. Interactive controls now have high-contrast hover and active outlines, profile rows include spell-role badges plus text state labels, Settings supports mouse-wheel navigation, and embedded artwork loading retries safely if the graphics service is not ready on the first frame.

## v1.61.15 Lua and Markdown-only storage

Converted every Ret Paladin status, diagnostic, debugger, and session output to Markdown. The live loader folder, data folder, and distributable now use only `.lua` and `.md` files; the Turalyon artwork remains encoded inside `ret_paladin_art.lua`.

## v1.61.16 city training-dummy testing

Attackable training dummies are detected through the framework flag, known city dummy NPC IDs, and common dummy names. Dummy testing uses the World PvE single-target priority, ignores short time-to-die cooldown suppression, prevents nearby dummies from forcing the AoE priority, and exposes a **Dummy burst testing** switch for complete cooldown tests. The debugger marks the target with `[DUMMY TEST]` and records whether burst testing is enabled.

## Versioned Project Sylvanas folder

Every live update is installed in `scripts/ret_paladin_plugin_v<VERSION>/`, where the suffix exactly matches the runtime and header version. The previous Ret Paladin plugin folder is removed after hash verification to prevent duplicate discovery. Root compatibility modules retain their stable filenames.

## v1.61.17 small dungeon boss helper GUI

Added a separate compact and movable boss-helper window. It appears only in detected dungeon content when enabled, reads class, specialization and group role from the current player, and uses class-colored framing. The alert border and heading change for interrupts, movement, stack/soak and priority-target mechanics. The window reuses the existing Season 2 boss guide, active boss casts and BigWigs/LittleWigs timing data. Use its **HIDE [F7]** button or press **F7** to hide it; press **F7** again to restore it.

### v1.61.18 boss-helper hotkey

The independent boss-helper visibility hotkey is F7. Its button now reads **HIDE [F7]**.

### v1.61.19 universal boss-helper startup

The small helper now starts independently of the Ret combat runtime and detects the active character's class, specialization and group role. The main Ret GUI remains restricted to Retribution Paladins. The helper can be shown at any time with F7 and displays an **Enter a dungeon** ready state outside instances. A newly detected boss fight automatically presents the helper even if it was hidden between pulls. Inside a dungeon it detects the active boss, casts and available BigWigs/LittleWigs timers.

### v1.61.27 startup and encounter coverage

- Treats temporary class or specialization value `0` as startup data that is still loading and retries once per second.
- Detects boss encounters in dungeons, Mythic+, Delves, raids and the open world.
- Keeps manual F7 preview available while requiring active combat before the boss helper automatically opens.
- Preserves the two-window layout: one main Ret panel and one compact boss helper.

### v1.61.28 boss encounter awareness

- Detects interruptible casts from nearby hostile adds during a boss encounter, even when the add is not selected.
- Points the boss-helper navigation line at the urgent caster and identifies both the spell and caster.
- Rejects friendly or distant boss-class objects so open-world detection cannot latch onto an unrelated encounter.
- Preserves the existing two-window layout and Retribution-only combat runtime.

### v1.61.29 channel-aware actions

- Treats interruptible channels as active casts in Mythic+, Delve, world PvE and PvP interrupt selection.
- Reads channel progress and channel spell IDs when the framework exposes them.
- Includes dangerous channels in priority target scoring and the off-target boss-add coach.
- Prevents fishing, looting and skinning interactions from firing during a player channel.
- Stores the shared channel helpers on runtime state to preserve the Lua function-local budget.

### v1.61.30 channel API compatibility

- Resolves dangerous ability names through either active-cast or active-channel spell IDs.
- Accepts the framework's spell and channel interruptibility method variants.
- Applies the same fallback to Mythic+, general PvE, PvP, priority targeting and the boss coach.
- Records the correct channel spell ID when a priority stop cannot be completed.

### v1.61.31 PvP deep audit

- Uses channel progress for PvP fake-cast timing instead of defaulting a channel to complete.
- Rejects targets with native immunity or invulnerability signals even when the optional PvP helper is unavailable.
- Extends the conservative local DR fallback through Hammer of Justice duration plus the Patch 12.1 20-second reset window.
- Adds focused regression coverage for channel timing, native immunity and fallback DR timing.

### v1.61.32 PvP state compatibility audit

- Reads dampening from core APIs, the PvP helper, or the player's live Dampening aura.
- Normalizes both fractional and percentage dampening values before defensive triage.
- Recognizes `is_flag_carrier`, `is_objective_carrier`, and `has_battleground_flag` through one objective helper.
- Applies unified carrier detection to targeting, interrupts, support priority, Freedom and immunity holds.

### v1.61.33 PvP combat lines

- Adds a dedicated PvP combat-lines switch enabled by default.
- Draws a yellow line and ground ring to the selected hostile target in Arena, Battleground and World PvP.
- Draws a line to the detected group healer: green when within healing range and visible, red when blocked, too far away or unable to heal the player.
- Uses graphics line-of-sight first and unit line-of-sight methods as a compatibility fallback.

# Ret Paladin 12.1 v1.61.46

## v1.61.46 defensive substitution

- Recognizes the **Blessing of Spellwarding** PvP talent.
- Uses Spellwarding only when a confirmed caster is actively casting at, or bursting into, a pressured teammate below the configured ally immunity threshold.
- Keeps Blessing of Protection for physical pressure.
- Treats Spellwarding as a major defensive, so the four second per-target defensive lock prevents overlap with Protection, Sacrifice, Lay on Hands, and other major saves.
- Never requests Spellwarding when the talent is not learned.

# Ret Paladin 12.1 v1.61.47

## v1.61.47 Templar survival conversion

- Recognizes the **Sacrosanct Crusade** Templar hero talent.
- When offensive burst is being held, Wake of Ashes may be used at or below the strict Shield of Vengeance health threshold to gain its 10% maximum-health barrier.
- Requires 0–2 Holy Power so the survival cast also avoids wasting Wake's three Holy Power generation.
- Respects PvP crowd-control safety and the existing four-second major defensive anti-overlap lock.
- Leaves the ordinary offensive Wake of Ashes priority unchanged.

# Ret Paladin 12.1 v1.61.48

## v1.61.48 Hallowed Ground support

- Recognizes the Hallowed Ground PvP talent and uses Consecration to clear confirmed snares from the Paladin or a nearby pressured, objective-carrying, or healer teammate.
- Keeps Blessing of Freedom available for roots and other movement control.
- Refuses the Consecration when it would overcap Holy Power or damage an enemy under breakable crowd control.
- Casts Consecration at the Paladin because Hallowed Ground affects allies standing within its area.

# Ret Paladin 12.1 v1.61.49

## v1.61.49 healing-state compatibility

- Uses the native Project Sylvanas `is_immune_to_heal` unit signal in addition to the optional PvP helper.
- Prevents Lay on Hands and Word of Glory from being requested into confirmed healing immunity in every mode.
- Supports `get_total_heal_absorbs`, `get_total_heal_absorb`, and `get_heal_absorb`, matching the mature Holy Paladin and Restoration Shaman compatibility pattern.
- The healer line also turns red when the player is natively healing immune.

# Ret Paladin 12.1 v1.61.50

## v1.61.50 shield-aware prediction

- Predictive personal and teammate survival logic now credits existing absorb shields against forecast incoming damage.
- Shield credit is capped at 75% of forecast damage, matching the installed Rogue and Holy Paladin predictors.
- Current-health thresholds remain strict, and a partial shield cannot hide a genuinely dangerous forecast.
- This reduces unnecessary defensive stacking over a shield already protecting the same damage window.

# Ret Paladin 12.1 v1.61.51

## v1.61.51 Templar override validation

- Hammer of Light is requested only when its readiness aura is active or Wake of Ashes currently resolves to the Hammer override.
- Three Holy Power alone no longer causes premature Hammer probes before Wake has transformed the button.
- This removes avoidable not-ready and spell-not-learned noise while preserving paid and free Hammer casts.

# Ret Paladin 12.1 v1.61.52

## Frame-time and logging optimization

- Caps the full combat decision loop at 30 Hz instead of running it once per rendered frame.
- Adds adaptive 50/75 ms backoff when a decision pass exceeds the existing 3 ms scan budget.
- Batches ordinary accepted-action diagnostics into the five-second combat heartbeat.
- Keeps errors, warnings, GUI actions, and safety events immediately durable.
- Reduces the live redundant journal working set to 300 KB while retaining the previous-session snapshot.

# Ret Paladin 12.1 v1.61.53

## Customer GUI and hotkey update

- Expands the main panel from eight tabs to fourteen task-focused tabs.
- Adds dedicated Combat, Defense, Support, Movement, Visuals, Gathering, Hotkeys, and Logs pages.
- Keeps six mode pages with independent Rotation, Burst, CC, Swap, Support, and Defensive switches.
- Adds a persistent optional framework keybind for every global switch and every mode switch.
- Every assigned shortcut toggles its option on or off on the key-down edge, preventing repeat toggles while held.
- The Hotkeys page shows bound/unbound status and directs customers to the framework controls for binding.

# Ret Paladin 12.1 v1.61.54

## Major-city practice dummy support

- Adds legacy and modern dummy IDs used across faction capitals, expansion capitals, class hubs, and garrisons.
- Recognizes Training Dummy, Practice Dummy, Target Dummy, Combat Dummy, Tanking Dummy, Damage Dummy, Training Bag, and Melee Target names.
- Honors the framework's native `is_training_dummy` signal first.
- Allows a selected attackable dummy to start the test rotation before the client exposes an in-combat flag.
- Keeps full cooldown testing controlled by the existing Dummy Burst Testing toggle.

