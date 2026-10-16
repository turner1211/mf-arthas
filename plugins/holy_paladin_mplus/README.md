# Holy Paladin Healing Profiles

Project Sylvanas / IZI plugin package, version 4.68.0. It retains the existing Holy Paladin talent checks, beacon support, aura selection, dispels, utility, fishing and looting, and provides separate healing profiles over a Paladin-art background.

Version 4.68.0 expands the Training Dummy profile across major cities and expansion hubs. It recognizes damage, PvP, tanking, healing, combat, practice, cleave, swarm, target, and challenge dummy families. Known NPC identities cover localized clients, while the Sylvanas unit helper remains the first detector for newly added dummies. Friendly healing dummies are included in Holy triage; hostile damage and tanking dummies run the normal talent-aware damage, Holy Power, cooldown, defensive, cast-outcome and logging paths. Select the desired dummy with Training Dummy Rotation enabled.

Version 4.67.0 reorganizes the customer panel into nine focused tabs: Home, Healing, PvE/Bosses, PvP/Control, Movement, Utility, Gathering, Hotkeys, and Display/Logs. Every switchable feature keeps a visible ON/OFF control and has an independent customer-assigned hotkey. The panel displays each assigned key beside its feature; press Insert and open Holy Paladin Healing to bind or change keys. Healing thresholds can now be adjusted directly from the Healing tab. The Hotkeys tab provides a scrollable overview of all 20 feature toggles and their current bindings.

Version 4.66.0 reduces runtime work by sharing one object-manager enumeration across each rotation pass and one across each visual pass. The snapshot ends after that pass and is also cleared on world transitions, so changing rosters and reconnects cannot retain stale object handles. Healing, PvP pressure, targeting, boss visuals, fishing and looting now use the shared enumerator. Validation confirms one enumeration for multiple consumers in a pass and a fresh enumeration on the next pass.

## Live folder naming

The deployed Project Sylvanas folder includes the current version: `holy_paladin_mplus_vX.Y.Z`. Each update renames the existing live folder to the new version instead of leaving an older copy that could load twice.

## Permanent deployment file rule

The source package and the live Project Sylvanas Holy Paladin folder may contain only `.lua` and `.md` files. Artwork, icons, encounter data, configuration, and other required resources must be embedded in Lua or documented in Markdown. Every deployment must recursively check the live folder and report zero unsupported files. A deployment is incomplete if any other extension is present.

Version 2.7.0 fixes Beacon of Faith's separate spell and target, caster ownership for Beacons and auras, native aura fields and millisecond durations, category-specific PvP diminishing returns, and Unstable Affliction dispel protection. Healing excludes allies confirmed behind line of sight or immune to healing. Emergency direct heals and spending at five Holy Power precede routine GCD setup. Group pressure and Light of Dawn use the current 40-yard healing radius. Lethal self saves bypass the routine defensive delay. Moving hard casts require a confirmed instant effect, and existing casts/channels are preserved. Emergency peeling remains available after healing attempts are unavailable. Idle or rejected auto-loot attempts no longer prevent Beacon, aura, or travel Steed upkeep. Closing the GUI while dragging releases mouse capture. Aura Mastery uses your selected aura, including when another Paladin's aura is also received. Quiet cast failures release the request latch; outcomes use cast GUIDs when provided. Logs distinguish matched plugin outcomes from manual/unmatched events and throttle repeated identical errors.

Version 2.8.0 adds measured cast outcomes and bounded per-mode threshold learning, important-cast Mythic+ forecasting, automatic Blessing of Freedom, lethal teammate CC recovery with Divine Shield, enemy trinket-aware CC scoring, dampening and mana adjustments, melee-versus-caster external selection, PvP talent handling for Cleanse the Weak, Spreading the Word, Searing Glare and Divine Plea, plus a short cooldown budget that prevents routine cooldown stacking. All talent actions remain conditional on positive talent or spellbook detection.

Version 2.9.0 adds six further systems: talent-aware Barrier of Faith for targeted pressure; full-health pre-damage setup with Barrier, Aura Mastery or Beacon of Virtue; health-loss velocity that catches sudden drops beyond the host forecast; short target hysteresis that prevents marginal heal-target flipping; a 0.75-second manual-input yield with a lethal-health override; and encounter-level outcome summaries. Safe Mythic+ damage now prioritizes Judgment for its Consecration interaction unless Holy Shock would waste a capped charge.

Version 3.1.0 extends PvP resource and round awareness. Arena and battleground drinking is preserved unless an ally reaches emergency health. Fresh PvP engagements clear learned trinket history so shuffle rounds do not inherit stale state. Weak crowd control can be chained near expiration, Blessing of Protection can rescue a physically pressured ally from a stun, Ultimate Sacrifice can be paired with Divine Shield when its full transfer threatens the Paladin, and dampening reads more host aura layouts. These additions retain the 3.0.0 pre-CC Sacrifice, defensive-overlap checks, damage-school classification, carrier priority, and Turn Evil pet peel logic.

Version 3.2.0 improves PvP prevention and objectives. Heavy burst now enters the external-save path at 75% health, allowing Blessing of Sacrifice to work at its intended preemptive threshold instead of waiting for crisis health. Spellwarding responds earlier to confirmed magical burst. When Denounce is selected, the plugin can spend available healing-safe Holy Power to suppress an active enemy burst's critical effects. Darkest before the Dawn stacks are consumed with Light of Dawn when multiple allies need the empowered heal. Battleground flag and orb carriers receive top Blessing of Freedom priority while slowed. Each new decision records a specific prevention, healing, or utility event in the durable log.

Version 3.3.0 improves arena coordination and escape behavior. Enemy target changes are tracked per attacker and create a short swap-protection window, allowing an early Sacrifice before the new target collapses. Enemy healer detection now uses healer specialization IDs when role data is missing. Hammer of Justice setup checks whether teammates are pressuring a separate kill target, so control lands on the healer during the team's go instead of requiring the team to attack the healer. Freedom detects roots when the host exposes them. World PvP can use Divine Steed as an emergency disengage while moving, outnumbered, and under 65% health. The durable log records enemy swaps and escape Steed decisions.

Version 3.3.1 ports the working Rogue GUI asset fix. The Paladin background is embedded in `holy_paladin_art.lua` and loaded directly into the top 2D layer using screen coordinates. Tabs and spell-related controls use native gold Paladin glyphs drawn by Lua. The plugin no longer ships or reads PNG files, and retains a native drawn fallback if texture loading is unavailable.

Version 3.4.0 adds talent-aware Divine Plea sequencing. When Divine Plea is selected, routine Aura Mastery is held during enemy pressure because the talent applies a 30-second healing penalty; the plugin instead triggers it below 22% mana only when the team is at least 90% healthy and no burst is active, while retaining a lethal-health override. New enemy swaps now count as immediate healing and Beacon of Virtue windows, and Barrier of Faith can pre-shield the swapped ally before health collapses. Denounce only spends Holy Power at the five-point cap, preserving Word of Glory or Eternal Flame resources for recovery. Each deliberate Divine Plea mana window and each suppressed unsafe Aura Mastery is recorded in the durable log.

Version 3.5.0 strengthens the PvP resource loop and swap preparation. Persistent Beacon of Light follows a freshly swapped-to teammate during the safe moment before urgent healing begins, while Beacon of Faith remains on its separate ally and Virtue builds retain their normal burst setup. When Holy Shock is unavailable, an ally is stable at 60% or higher, and no burst, multi-attacker pressure, or swap is active, Judgment can generate Holy Power without requiring the PvP damage switch. Damage-assisted healing refuses to target an enemy under meaningful crowd control. Beacon of Virtue is withheld below 15% mana during routine pressure but remains available at 55% ally health or below and during last-chance saves. New Beacon movement and Judgment resource decisions are written to the durable log.

Version 3.6.0 expands predictive protection. During a confirmed important targeted Mythic+ cast, Blessing of Sacrifice can be applied before impact when the host predicts at least 8% incoming health loss or the target is already projected below 72%, while requiring the Paladin to remain at 65% health or higher and respecting the external-cooldown budget. In PvP, Blessing of Protection can break a confirmed physical stun on the healer when a teammate is in lethal danger, preserving Divine Shield for later; this path is disabled when Spellwarding replaces the physical blessing. Battleground flag and orb carriers enter the external-save path earlier under focused pressure, and logs mark objective protection, stun recovery, and forecast Sacrifice decisions.

Version 3.7.0 adds movement and target intelligence. Optional automatic targeting ignores enemies under meaningful crowd control, prioritizes important interruptible casts, and then favors enemies actively pressuring teammates instead of selecting only the nearest unit. During Arena, Battleground, or World PvP combat, optional Divine Steed can reconnect to a teammate at 55% health or below who is within 60 yards but beyond healing range or blocked by line of sight, provided the Paladin is already moving. Existing emergency-healing and World PvP escape rules remain active, and logs identify priority target choices and partner-reconnect Steed usage.

Version 3.8.0 adapts proven systems from the installed Resto Shaman and Retribution Paladin plugins. A smoothed combat mana-burn sample projects mana 15 seconds ahead and enters conservation before the current bar reaches the critical threshold. Non-instant Flash of Light and Holy Light casts are held above emergency health when the PvP helper positively confirms an enemy interrupt is ready. Dispel selection now combines effect priority with the ally's observed health-loss velocity and native objective-carrier status. Important Mythic+ casts discovered by the existing forecast can be Rebuked directly at melee range without requiring the enemy to be the selected target. Native objective detection is used first for triage and Freedom, with aura-name detection retained as a fallback. STATE logs now include mana burn and the 15-second mana forecast.

Version 3.9.0 improves cast efficiency and interrupt recovery. An active Holy Light or non-instant Flash of Light is cancelled when its confirmed target reaches at least 98% current health and remains at least 95% after predicted incoming damage, preventing an expensive redundant heal after another source tops the ally. Forecasted mana now governs routine Flash of Light and Holy Light filler instead of current mana alone. When an important Mythic+ cast is within ten yards, interruptible, and reaches its final second, Hammer of Justice can act as a backup if Rebuke is unavailable or out of melee range. Cancellation and stun-backup decisions are written to the durable log. The existing protected update wrapper remains the runtime circuit breaker for frame errors.

Version 4.0.0 adds time-to-danger triage and aggregate group forecasting. Observed health-loss velocity now produces an estimated time to critical health: targets falling within 3.5 seconds receive strong triage priority, focused PvP allies below a 2.5-second window enter the save path, and a target below two seconds enters emergency direct healing even before a fixed health threshold is crossed. Group decisions now total projected health deficit and near-term predicted loss across all allies. Large aggregate pressure can open the healing branch, prepare Beacon of Virtue, trigger Mythic+ throughput cooldowns, and justify Devotion Aura Mastery even when no single fixed injured-count threshold captures the danger. STATE logs include total group deficit and predicted group loss for tuning from live runs.

Version 4.1.0 completes the predicted group-damage sequence after its setup global. Aggregate pressure now carries into the Beacon of Virtue and Divine Toll pairing, Lightsmith Holy Armaments, Holy Prism, and Holy Power spending. Light of Dawn can answer forecast group damage before the old injured-count threshold is reached, but only when at least two allies benefit; a single collapsing ally still receives Eternal Flame or Word of Glory. Forecast-driven Light of Dawn decisions record their group deficit, predicted loss, and injured count in the durable log.

Version 4.2.0 corrects time-to-danger triage so it measures the time until an ally reaches the active profile's emergency threshold instead of the time until zero health. Rapidly falling allies therefore gain emergency priority while there is still time to save them. Persistent Beacon placement is now context aware: Mythic+ and delve profiles anchor Beacon of Light on an available tank, while arena, battleground, and world PvP prioritize allies under observed enemy pressure. Beacon of Faith continues to select a separate ally, with ranged and lower-health candidates used as tie breakers.

Version 4.3.0 improves prediction recovery and adaptive-learning accuracy. A confirmed health increase immediately clears the ally's retained downward velocity, preventing an already recovered player from keeping stale emergency priority. Per-mode threshold learning now accepts only a completed direct heal that matches the plugin's pending spell request and observes the originally requested target. Light of Dawn and Divine Toll are excluded from single-target learning because their group effects cannot be measured correctly from one target's health change.

Version 4.4.0 makes large-roster triage and offensive targeting deterministic. Battleground and world-PvP rosters are fully ranked before the profile unit cap is applied, preserving the player, party members, objective carriers, nearby allies, and lower-health units instead of accepting arbitrary object-manager order. Auto-targeting now replaces hostile targets that are outside useful range, behind confirmed line of sight, or under meaningful PvP crowd control. The same crowd-control guard covers healing-conversion attacks and ordinary damage globals, preventing the rotation from breaking long control effects.

Version 4.5.0 stabilizes all automatic activity profiles. Positive arena, battleground, delve, and party signals still switch immediately, while a temporary open-world fallback must remain stable for 1.25 seconds before replacing the current instance profile. Confirmed mode changes clear health velocity, sticky triage, pending adaptive observations, enemy target history, and PvP swap windows so one mode cannot contaminate decisions in the next. Every transition is recorded in the durable log. Out of combat, protected automatic dispels now run before routine top-off casts so removable control and dangerous effects do not wait behind several healing globals.

Version 4.5.1 formalizes logger and debugger isolation. The recorder owns the `holy_paladin_mplus` entity, the `holy_paladin_mplus.debugger` debugger identity, private module-local state, and the dedicated `scripts_log/holy_paladin_mplus/session.log` path. Every record now includes `entity=holy_paladin_mplus`, session headers include the debugger identity, and the live debugger displays its owning entity. No battleground-player module, identifier, state table, menu key, or log path is referenced.

Version 4.6.0 adds shared cast-latch recovery for every activity profile. Instant spells now use a 0.9-second confirmation window instead of holding all decisions for 2.5 seconds when the host omits an event; genuine hard heals keep their longer startup window and active casts continue extending it. A pending request whose target becomes dead or invalid is released immediately when the player is not casting. Expired and invalid releases are written as `RECOVERY` records. Rejected requests and failed events share bounded exponential backoff, while a failure streak automatically resets after five quiet seconds so an old failure cannot penalize a later valid emergency cast.

Version 4.6.1 fixes the Lua startup compilation limit. Recent failure timing, mode-transition candidates, and hostile reachability helpers now live inside the existing runtime state table instead of consuming additional main-chunk locals. This removes several top-level locals, preserves the v4.6 behavior, and leaves headroom below Lua's 200-local function limit so the loader, GUI, isolated logger, and debugger can initialize normally.

Version 4.7.0 adds emergency hard-cast redirection to every mode without adding a top-level local. A plugin-started Holy Light or Flash of Light is cancelled when its target dies, becomes unreachable, or is safely recovered. It is also redirected when another healable ally falls to the active profile's emergency threshold while the original target remains at least 18 percentage points above that floor. The separation guard prevents oscillation between two critical allies. Every cancellation records its reason, old target, and emergency replacement data in the isolated Holy Paladin log.

Version 4.8.0 applies the October 2026 Mythic+ and arena audit. In Mythic+, a target at 45% or lower with at most two Holy Power can unlock the selected hero tree's burst package even when group-injury counts are low: Lightsmith uses Holy Bulwark or Sacred Weapon, while Herald uses Divine Toll. This closes the severe single-target gap while retaining Beacon of Virtue sequencing for group damage. In arena, Divine Protection can trade at 82% during a confirmed multi-attacker or burst go, or when time-to-danger falls below 3.5 seconds. Blessing of Sacrifice gains the same time-to-danger expansion up to 80% on a pressured teammate. Existing defensive-overlap, self-safety, Forbearance, cooldown-budget, and emergency guards still apply. These changes follow Method's current 12.1 build-and-spend and Divine Toll guidance plus ArenaCoach's live defensive-mistake data and current Lightsmith/Herald representation.

Version 4.8.1 hardens GUI ownership. The loader now defaults to disabled and initializes only after positively identifying the active character as a Holy Paladin. The menu callback checks the current character every frame, and the artwork window has its own final class/spec check that immediately hides a window left registered after a character or specialization switch.

Version 4.9.0 updates hero-tree and maintenance priorities from the October 2026 audit. Lightsmith Holy Bulwark no longer depends on low Holy Power and can protect a newly focused or swapped arena teammate before Wings is committed. During a safe Mythic+ damage window, Lightsmith spends an available Bulwark or Sacred Weapon charge so Holy Armaments continue recharging; Herald uses Divine Toll below three Holy Power, and Holy Prism is used rather than held indefinitely. These maintenance actions run only after the healing path finds no urgent action. New telemetry actions identify each proactive armament, Toll, and Prism decision for log review.

Version 4.9.1 hardens the plugin against current Sylvanas and Midnight runtime differences. Spell requests resolve the active override button before checking knowledge, usability, charges, cooldown, range, and casting. Lightsmith now uses the single alternating Armaments button through whichever choice-node base spell is selected instead of assuming Holy Bulwark and Sacred Weapon are independent buttons. Specialization checks prefer the documented player specialization ID and retain the spellbook/enum fallback. Aura detection now checks IZI's resolved `get_aura_data`, `aura_up`, and `has_aura` extensions before the native manager and raw-list compatibility layers. Entering or leaving the world clears stale object handles, cast GUIDs, health history, and PvP target state while preserving settings and the append-only session log.

Version 4.9.2 closes the final callback ownership leak found in the persistent log. Manual casts from a Rogue or any other class can no longer pause the Holy Paladin rotation or write `MANUAL` entries. Logout lifecycle events are also ignored unless the active character is positively identified as Holy Paladin. Menu, artwork, arena lines, spell events, game events, update actions, and manual-cast events now all enforce the same live class/spec boundary.

Version 4.10.0 incorporates mechanics verified against TrinityCore's retail 12.1 branch. Offensive Holy Shock now respects an explicit `is_facing` failure before issuing the cast, preventing repeated server rejection when the enemy is behind the Paladin. During group healing, Holy Prism still prefers a hostile primary target for nearby ally healing, then falls back to the selected friendly healing target when no safe hostile target exists. This mirrors the server script's friendly/hostile Prism branches and its five-target secondary selection.

Version 4.11.0 adds predictive pressure acceleration across every healing profile. Triage now combines the host's incoming-damage estimate with a bounded short-term projection from observed health-loss speed and acceleration, while PvP keeps its conservative twelve-point forecast cap. Arena, battleground, world-PvP, and delve pressure tracks newly converging attackers plus sustained focus age, moving a focused ally forward before a fixed health threshold is crossed. Important hostile-cast forecasting and pre-impact Barrier, Sacrifice, Aura Mastery, Virtue, Rebuke, and stun preparation now also operate in delve and world PvP. STATE records include drop acceleration, focus ramp, and focus age for live tuning.

Version 4.12.0 adds learned encounter timing and predictive resource readiness. In Mythic+, delve, and world PvP, the plugin records important casts separately for each enemy and spell, smooths valid four-to-forty-five-second intervals, and requires three observations before producing a narrow pre-cast warning. Invalid sources, combat endings, mode changes, missed timings, and world transitions age out or reset the pattern. Forecasts preserve the prior target when one was observable and report whether the warning came from an active cast or a learned interval with its confidence. Across all profiles, accelerating group damage, near-term predicted loss, enemy burst, concentrated attackers, or an active forecast creates predictive risk. During that risk, optional Divine Toll and Holy Prism maintenance plus offensive Holy Power spending are held so healing resources remain ready. STATE records the risk flag and number of accelerating allies.

Version 4.13.0 integrates additional documented IZI prediction signals. Each ally's bounded trend and raw incoming-damage forecast now consult the runtime's combined `get_health_percentage_inc` estimate as a second opinion, retaining the existing twelve-point PvP and thirty-point PvE safety caps. PvP Blessing selection supplements attacker classification with IZI's native physical and magical damage-relevance checks, improving Protection versus Spellwarding choices when an enemy is channeling or its role is unavailable. Mythic+, delve, and world-PvP scans count enemies committed to each friendly target; three or more attackers on an ally projected at 85% or lower reserve healing resources without forcing a heal on a healthy target. STATE logs the exposed target and attacker count for tuning.

Version 4.14.0 ports two proven prediction systems from the installed Resto Shaman plugin. Health projection now credits confirmed shields against no more than seventy-five percent of queued damage, subtracts healing absorbs from incoming heals, and treats the uncovered absorb as bounded effective-health debt. This prevents both needless healing into real absorbs and underhealing targets whose health bar conceals a large healing absorb. Mana planning now calculates time until twenty-percent mana from the smoothed burn rate and uses mode-specific twenty-five-to-forty-five-second planning horizons. When critical mana lies inside that horizon, routine healing thresholds become slightly more conservative while emergency, burst, targeted-cast, and objective saves remain available. STATE records time-to-critical mana and the conservation state.

Version 4.14.1 fixes the Lua compiler's sixty-upvalue limit in the frame update function. All update helpers are routed through the existing runtime state table, reducing dozens of captured outer locals to one table reference without changing rotation behavior. This also creates durable headroom for future logic additions while retaining the separate two-hundred-local main-chunk fix.

Version 4.15.0 adds the optional PvE danger-zone aura for Mythic+, normal and heroic dungeons, delves, scenarios, and raid boss combat. BigWigs bars provide the appearance and expiry window for known impact-style mechanics, using the documented remaining time and current Season 2 encounter labels. Sylvanas Evade provides the spatial result: a translucent double ring centered on the player turns red when the current position is registered unsafe and green when a relevant mechanic is imminent but the position is safe. An unsafe registered ground effect displays even without a matching timer, and the overlay disappears when combat, the timer, and the hazard end. Arena and battleground content are excluded. The PvE Healing tab and standard menu include an independent toggle and live status.

Version 4.16.0 introduced the boss guide profiles for eight Season 2 dungeons. Version 4.17.0 hardened optional drawing dependencies and timer reads and removed misleading guidance to the tank for independent soaks. Green reference lines now appear only for known melee-stack mechanics. Instructions and colors are advisory and do not confirm a safe destination.

Version 4.18.0 protects delve companion targeting against hostile or player name matches and makes PvP Sacrifice respect measured healer health collapse. The current regression runner is `work/audit_4170_regression.py`; 43 simulated scenarios pass. The improvement tracker records remaining live-client and combat-log validation.

The prior 2.7.1 protections remain: spell callbacks and game events from another class or specialization cannot enter Holy Paladin state or logs after a character swap. Safe-window Shield of the Righteous waits for at least four Holy Power, preserving a healing reserve.

The artwork panel now follows the Resto Shaman task-based organization: PvE Healing, PvP / Control, Utility, Gathering, Display / Logs, and Core. Dungeon and movement controls are full setting rows inside PvE Healing. Five rows are shown at once; use the mouse wheel over the panel or its UP/DOWN buttons to reach the remaining rows. Core occupies the far-right position below Utility. Both tab rows leave the far-left column empty so the Paladin remains visible. The Paladin color scheme and full-window artwork remain, with higher-contrast title, control, status, and version surfaces. The title and instructions sit in the dark upper-right. The running version is shown in a boxed badge at the bottom-right.

The GUI includes a custom Holy Paladin icon set on every task tab and its corresponding setting rows. The icons share an ivory, gold, royal-blue, and warm-dark ability-art treatment: healing hand, hammer and shield, beacon lantern, fishing hook and loot bag, sacred log book, and winged core crest.

Display / Logs includes a live debugger showing current run status, cast request/success/failure/interruption counts, the latest state, accepted or rejected request, throttled skip reason, game spell event, and runtime error. RESET DEBUGGER clears only the live diagnostic display; it does not erase the session log.

Warcraft Wiki mechanics are applied conservatively across the profiles. Beacon of the Savior is identified as an automatic Beacon and is reported alongside the selected traditional Beacon. Flash of Light and Holy Light naturally support its automatic movement through normal triage. Forbearance blocks self Lay on Hands and Divine Shield attempts. Devotion Aura is not duplicated when another Paladin already provides it, and Aura Mastery only treats Devotion as a damage save or Concentration as cast protection. Mythic+ can use Devotion Aura Mastery for severe group damage. During Avenging Crusader, both Crusader Strike and Judgment are available as healing-conversion attacks.

Session STATE entries report only the most recent accepted cast request from the current combat run. A new run begins with `Waiting for first accepted cast`, preventing a previous encounter's last action from appearing as a new decision. Snapshot timing is reset at each run start so the first combat state is captured immediately.

### What the diagnostic log records

- `RUN_START` and `RUN_END`: mode, version, duration, request count, matched successful/failed/interrupted spell events, manual/unmatched event count, successful spell IDs, measured outcomes, stabilization rate, and average health change.
- `STATE`: detected profile, hero and Beacon builds; player current/projected health and incoming damage; worst ally current/projected health, incoming damage and health-drop rate; enemy focus count, burst flag, nearby attackers, physical and magical pressure, hostile interruptible casts; mana, Holy Power, GCD, adaptive threshold offset, dampening, important dungeon-cast forecast, cooldown budget, manual-input yield, selected target and health; automation switches; current-run accepted decision; full roster health.
- `REQUEST` / `REJECT`: the spell and target submitted to the host and whether the host accepted it.
- `SKIP`: throttled explanations such as active GCD, ongoing cast/channel, moving hard cast, cooldown, range, unknown/unusable spell, pending cast, retry backoff, invalid target, request throttle, or unsafe dispel backlash.
- `EVENT`: player success, failure (including quiet failure), or interruption, with `origin=plugin_request` or `origin=manual_or_unmatched`.
- `OUTCOME`: spell, target, health before and after the observation window, health delta, elapsed time, stabilization result, mode and learned threshold offset.
- `DISPEL`, `CONTROL`, `PREVENTION`, `RECOVERY`, `COOLDOWN`, `FORECAST`, `MANUAL`, `UTILITY`, and `ERROR`: dispel target/priority, CC use, pre-CC Sacrifice, emergency CC recovery, confirmed cooldown group, pre-damage action, manual yield, movement utility, and runtime errors. Identical errors are limited to one entry per five seconds with a repetition count.

### What to inspect in a shared log

1. **Triage:** Did `worst_current`, `worst_projected`, and `worst_incoming_pct` identify the ally who actually needed healing?
2. **Pressure:** Did `focused_by`, `focus_burst`, `nearby_attackers`, and `hostile_casts` justify an emergency heal, external defensive, or peel?
3. **Resources:** Were `mana`, `holy_power`, and `gcd` compatible with the intended spell?
4. **Build:** Did `hero` and `beacon` match the selected talents?
5. **Decision:** Does `decision` show the intended spell and target from this run?
6. **Execution:** Does an accepted `REQUEST` receive a matching successful `EVENT` with `origin=plugin_request`; if not, is there a failure, interruption, or `SKIP` reason? Manual/unmatched events do not count as plugin successes.
7. **Outcome:** Did health stabilize after the cast, and were long cooldowns reserved for pressure that justified them?

## Files

- `header.lua` and `main.lua` — loader metadata and entry point.
- `holy_paladin_mplus.lua` — mode detection, profile-specific triage, shared talent-aware rotation and optional utilities.
- `holy_paladin_aura_safe.lua` — positive-only aura access compatible with the supplied Tactix secret-aura template.
- `holy_paladin_gui.lua` — standalone draggable interface with Mythic+, Delve, Arena, Battleground, World PvP and Logs pages. The character artwork stays visible behind warm gold-and-ivory controls. Press F1 to show or hide it.
- `holy_paladin_telemetry.lua` — structured activity logger and copy/clear controls.
- `holy_paladin_art.lua` — embedded Paladin artwork bytes used without external image files.

## Healing profiles

- **Mythic+** ranks the five-player group with the host's short incoming-damage estimate, promotes immediate danger, spends Holy Power before overcapping, and uses group healing/cooldowns when the predicted group state justifies them.
- **Delve** includes the player, party and recognized Brann/Valeera companions when the object API exposes them. It gives special urgency to a companion under attack.
- **Arena** prioritizes allies being targeted by enemy players and uses available burst/attacker clues to trade cooldowns, emergency heals, and peels. Damage is off by default; attacks are used as healing only during an active Avenging Crusader/Wrath conversion window when injured allies need it.
- **Battleground** includes positively identified friendly players and favors clustered group healing. Damage is off by default.
- **World PvP** heals the party and positively identified nearby friendly players, with additional urgency when enemies target them. Damage is off by default.

PvP safe windows maintain selected persistent Beacons and Devotion Aura; Beacon of Virtue is used against pressured targets or group damage. Optional Divine Steed uses sustained out-of-combat travel, or movement under confirmed player pressure in PvP, and yields to urgent ally healing. PvP crowd control is optional: Hammer of Justice prioritizes a teammate's selected healer when safe, and switches to peel priority when a focused ally is in kill danger or an attacker has a confirmed interruptible cast. Talented Blinding Light requires multiple nearby enemies and pressure on an ally. CC waits through the opening five seconds, requires line of sight, avoids known CC immunity and heavy diminishing returns, and yields to healing except for a confirmed emergency peel. Rebuke is disabled in PvP, where the current ruleset removes the Holy Paladin interrupt. Arena partner lines are green when the ally is within healing range and line of sight, amber when out of range, and red when line of sight is blocked or healing immunity is detected.

The supplied Arena run had 1,366 accepted spell requests in 117.7 seconds, with 1,229 failures and 71 successful casts. Most repeats were Eternal Flame (642 requests), Holy Shock (506), and Flash of Light (205). The rotation now permits one pending cast request, waits for a matching success/failure/interruption event, applies escalating per-spell retry delays after failures, and times out safely if the host omits an event. PvP damage forecasts are capped at a 12 percentage-point adjustment because the log's projected health swung from 62% to 97% while observed health remained 97%. Beacon/aura upkeep, Steed, and CC yield while an ally is at or near the profile's healing threshold; automatic CC also waits five seconds into combat.

PvP now has distinct emergency layers. The player uses Divine Protection at moderate confirmed focus pressure, then retains Divine Shield and Lay on Hands for the configured emergency thresholds. If the healer is crowd controlled while a teammate is in lethal danger, Divine Shield can break the control and restore healing access. For allies, Lay on Hands is reserved for critical health, Blessing of Sacrifice is traded against burst or multi-attacker pressure only when the Paladin is safe, Blessing of Protection follows confirmed melee pressure, and talented Spellwarding follows caster pressure plus burst. Aura Mastery follows burst pressure. Automatic Freedom uses native slow detection and gains group value from Spreading the Word. Cleanse the Weak can turn Flash of Light or Holy Light into a Poison/Disease removal. Searing Glare replaces the clustered blind path when selected. Enemy trinket history increases safe setup value while existing DR checks prevent waste.

Global cooldown handling reads the host's generic GCD spell cooldown (61304), falling back to the player GCD method when unavailable. Avenging Wrath, Avenging Crusader, Blessing of Sacrifice, Divine Protection, and Lay on Hands are treated as off-GCD. Rebuke has an explicit interrupt exception. Other spells, including Divine Shield and Aura Mastery, wait for the GCD. The one-request/cast-event latch remains in place to prevent duplicate requests. Flash of Light while moving requires confirmed Infusion of Light or a reported zero cast time; Holy Light requires confirmed Hand of Divinity or a reported zero cast time. Divine Favor alone does not make Holy Light instant. When Avenging Crusader or Avenging Wrath is confirmed active, the plugin can use Crusader Strike or Hammer of Wrath as healing-conversion attacks while allies are injured and Holy Power is below cap.

The **AUTO** control returns to context detection. Selecting **USE THIS PROFILE** forces that profile until AUTO is selected again. Each mode has separate healing, cooldown and damage switches. Shared controls remain in the plugin's normal settings menu.

## Talent handling

Active talent data is read from `core.game_ui.get_active_talents()` and used to distinguish Lightsmith from Herald of the Sun and to respect selected Beacon, Holy Prism, Eternal Flame, Moment of Compassion and cooldown talents. Beacon of Faith maintains Beacon of Light (53563) and Beacon of Faith (156910) on distinct allies, using your confirmed applications. A queued request alone never establishes Beacon coverage. The Lightsmith Holy Bulwark/Sacred Weapon replacements and Herald Divine Toll branch remain separate. Infusion is redirected toward an injured Beacon target only with Moment of Compassion selected. If the runtime has not exposed the active talent list, the plugin falls back to spellbook knowledge and displays the build as unavailable if neither source is conclusive.

## Session log recorder

The recorder writes continuously to `scripts_log/holy_paladin_mplus/session.log`. Version 3.1.1 preserves this file across plugin reloads, crashes, disconnects, and logouts instead of recreating it when the plugin starts. Each login/reload adds a `SESSION_RESUME` separator; a normal logout adds `SESSION_END`, while the absence of that marker identifies an interrupted or crashed session. Previously written lines remain available after logging back in. The Logs page copies the file path or current encounter to the clipboard and only deletes history when the user explicitly presses Clear Log. Logging is enabled by default and can be paused from the panel or standard settings menu.

## Healing logic references

Reviewed again on October 6, 2026. The healing priorities follow [Method's 12.1 rotation](https://www.method.gg/guides/holy-paladin/playstyle-and-rotation), the [Wowhead healing guide](https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer), and [Icy Veins Mythic+ guidance](https://www.icy-veins.com/wow/holy-paladin-pve-healing-mythic-plus-tips): spend healing power at cap, favor focused healing when an ally is in danger, consume Infusion efficiently, preserve mana on expensive Holy Light, and reserve damage spending until four or five Holy Power. Moment of Compassion is checked before Beacon redirection. Current [Blizzard class notes](https://news.blizzard.com/en-us/article/24244455/midnight-pre-expansion-content-update-notes) and live spell data confirm [Light of Dawn's 40-yard radius](https://www.wowhead.com/spell=85222/light-of-dawn), [instant Infusion Flash](https://www.wowhead.com/spell=54149/infusion-of-light), [Hand of Divinity](https://www.wowhead.com/spell=414273/hand-of-divinity), and [Lay on Hands' zero GCD](https://www.wowhead.com/spell=633/lay-on-hands).

PvP timing and defensive trades were reviewed against [Icy Veins](https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle), [Skill Capped's 12.1 changes](https://www.skill-capped.com/wowarticles/guides/holy-paladin-pvp-guide/midnight-changes/), [ArenaCoach's live top-player builds](https://arenacoach.gg/builds/holy-paladin/shuffle), and Warcraft Wiki's [Spellwarding history](https://warcraft.wiki.gg/wiki/Blessing_of_Spellwarding) and [Unstable Affliction mechanics](https://warcraft.wiki.gg/wiki/Unstable_Affliction). ArenaCoach currently shows 39 Lightsmith and 11 Herald players in its top-50 Shuffle sample; Murlok currently shows the inverse tendency in its top-50 Mythic+ sample, with 42 Lightsmith and 8 Herald players. These small, mode-specific popularity samples do not override the player's actual talents or justify fixed cooldown timing, so both hero paths remain supported.

Google-indexed leads included Khanoozie's [12.1 Mythic+ beginner guide](https://www.youtube.com/watch?v=jM_QPNsyD1E) and AutomaticJak's [Season 2 Holy Paladin guide](https://www.youtube.com/watch?v=w4MTlSOTaLM). Search metadata exposed their chapters and scope, but the video pages/transcripts were unavailable, so no video-only mechanic was implemented. Recent Reddit discussions about [weak PvP sustained healing](https://www.reddit.com/r/worldofpvp/comments/1wjvgy1/holy_paladin_am_i_missing_something/) and [Lightsmith tuning](https://www.reddit.com/r/worldofpvp/comments/1wlw4hh/holy_paladin_lightsmith_received_zero_pvp_tuning/) reinforce conservative cooldown usage but remain anecdotal. Maxroll remained blocked by robots.txt; no rule relies on inaccessible content.

## October 6 audit verification

The actual Lua modules were loaded in LuaJIT/Lua 5.1 with a simulated Project Sylvanas host. All seven Lua files compile. The final suites pass 50 rotation/utility/GUI scenarios and 30 native-API/telemetry scenarios. New PvP cases verify pre-CC Sacrifice, defensive overlap suppression, physical cast classification, Battleground objective-carrier priority, and Turn Evil pet peeling. Existing cases continue to verify dungeon forecasting, Barrier pre-shielding, manual-input yielding with emergency override, health-loss velocity, target hysteresis, safe-damage Judgment priority, encounter outcome summaries, Freedom target choice, lethal teammate CC recovery, measured healing outcomes, cross-class log isolation, and the Holy Power damage reserve. These are behavior regressions, with some overlapping coverage, rather than performance benchmarks.

Coverage includes both hero replacements, Beacon Faith and failure recovery, aura ownership, unsafe dispels, healing visibility/immunity, current group range, emergency ordering, GCD handling, moving/ongoing casts, quiet failures, stale cast GUIDs, DR categories, plugin versus manual log outcomes, error throttling, loot lifecycle, travel Steed, emergency peeling, and GUI mouse release. Fishing, loot, target/facing, arena lines, and GUI signatures were also checked against the installed native API documentation.

The current regression harnesses are retained in the workspace's `work/audit_271` directory. The previous audit and v2.6.1 backup remain in `work/audit_270`. The October 6 live log contained a v2.7.0 startup and a Shaman Earth Shield event, but no Holy Paladin combat run for measuring healing results. In-game execution, rendered GUI readability, healing throughput, and key/rating capability remain unverified by this audit.

## Limits

Version 4.22.0 aligns emergency recovery and forecast setup with the defensive/activity switches, excludes forecast Rebuke in PvP, and prevents transient log-write failures from recreating existing history. A confirmed missing file may be created; unknown storage state is reported as a write failure. The current simulated suites pass 60 behavior cases and 30 API cases. The file creation policy requires `core.read_log_dir` for recovery when initial appending fails.

Version 4.20.0 fixes false-valued visual API responses and adds explicit amber unknown-safety warnings. Red indicates a registered hazard; green means both Evade checks returned true, not that every possible boss mechanic is safe. Paused/stopped timers are excluded, and visual failures are reported to the debugger. All 55 current simulated checks pass.

Version 4.19.0 adds an explicit empty-charge guard, prevents Turn Evil from selecting unknown creature types, and preserves existing crowd control before Denounce. The current simulated regression suite passes 49 scenarios. The latest inspected live log does not contain a current-version Holy Paladin combat run, so actual throughput and defensive timing remain unverified.

The host describes incoming-damage forecasts as heuristic. The plugin caps how much un-timed incoming healing can offset those estimates and uses current health when prediction is unavailable. Enemy focus, companion identity, line of sight, dispel eligibility and aura presence depend on what the client API exposes. The panel's manual profile selector is provided for ambiguous contexts. In-game behavior and the new GUI texture still require a runtime check in the supplied Project Sylvanas installation.
Version 4.22.0 additionally guards forecast Sacrifice against declining healer health and ineligible recipients. Current coverage: 62 behavior scenarios and 30 API checks; live performance remains unconfirmed.
Version 4.23.0 makes forecast preparation yield to already critical allies or measured time to danger of two seconds or less. Confirmed PvE interruption remains available to prevent the hit. Current simulated coverage: 65 behavior scenarios and 30 API checks.
Version 4.24.0 queues failed log appends and retries in order, with up to 50 writes per emission and 5,000 pending lines. Queue overflow is reported in logger status/debug data; unwritten memory cannot survive a crash. Failed Clear preserves in-memory records. Boolean false stays explicit in logs. Coverage: 69 behavior cases and 30 API checks.
Version 4.25.0 protects confirmed PvP crowd control from hostile Holy Prism and its friendly-target 30-yard damage splash. A failed enemy roster read holds the friendly Prism path; other healing remains available. Hidden or unavailable CC data remains a runtime limitation. Current coverage: 72 behavior cases and 30 API checks.

Version 4.26.0 verifies that an enemy Holy Prism anchor covers the injured group before spending its healing global. Group use requires up to two injured, healable allies within the spell's documented 30-yard secondary radius; otherwise the rotation falls back to the direct friendly heal. Current coverage: 75 behavior cases and 30 API checks.

Version 4.27.0 starts the selected Avenging Wrath or Avenging Crusader throughput window before an emergency healing global when the ally is at the mode's emergency threshold, near measured danger, under PvP burst, or inside the Mythic+ cooldown window. The setting and profile cooldown switches remain authoritative. Current coverage: 80 behavior cases and 30 API checks.

Version 4.28.0 restores the supplied Holy Paladin GUI layout. Tabs and setting rows use clean text without added glyph boxes, keeping the Paladin artwork visible and preserving the empty far-left tab column. All displayed runtime text is converted to host-font-safe characters, long labels and footer messages are clipped to their panels, font selection uses the host enum with a safe fallback, and changing tabs resets scroll position.

Version 4.29.0 keeps the GUI recoverable and readable across screen sizes. Dragging is clamped to the visible screen, its position persists across reloads, and Display / Logs includes a Reset Window control. Artwork failures and renderer failures are reported independently so a background problem cannot silence later GUI diagnostics.

Version 4.29.1 moves Reset Window into the unused Display / Logs header slot so it never overlaps debugger or log controls.

Version 4.30.0 adds automatic training dummy testing. With Training dummy rotation enabled, selecting a city training or target dummy activates a dedicated profile that uses the normal talent-aware healing, Holy Power, damage, hero build, cast-outcome and logging paths. Injured allies retain healing priority. Dummy detection uses the host unit helper with a conservative non-player name fallback, and selecting an ordinary enemy never activates the training profile.

Version 4.31.0 adds a separate compact movable dungeon boss helper GUI. It automatically verifies Paladin and Holy specialization, detects healer role, appears only inside a supported Season 2 dungeon, and shows the next recognized BigWigs timer or boss cast, countdown, mechanic category and short role instruction in the Holy gold-and-ivory theme. Its header has a Hide button. The existing world circles and stack/spread lines remain active.

Version 4.31.1 assigns F7 as the boss helper show/hide toggle. The header Hide button remains available, and F7 reopens the helper after it has been hidden.

Version 4.32.0 makes the standalone boss helper available whenever it is enabled on a verified Holy Paladin. F7 can show or hide it anywhere, while detection of a valid live boss frame automatically opens it at the start of each boss engagement. Hiding it during that encounter is respected until the next boss. Outside a supported dungeon it displays a clear waiting status instead of silently hiding. Its initial position is calculated from the current screen size so the panel cannot start beyond the right or bottom edge. A new window identity also recovers from a stale saved off-screen position.

Version 4.33.0 expands the Season 2 boss helper with guide-reviewed positioning instructions for all eight current dungeons. The small GUI now gives a concise position cue beneath each mechanic. Move and spread mechanics scan sixteen nearby candidate points and draw a green line and destination circle only when the host hazard helper positively confirms the point is safe. Stack mechanics retain real-player anchor lines, interrupts point to the live casting boss, and soak mechanics remain textual when the client does not expose the actual soak object.

Version 4.35.0 enforces exactly two visible plugin windows: the main Holy Paladin GUI and one small boss helper. The boss helper now uses one stable window identity, and the briefly used retired identity is forced hidden to clean up duplicate windows left by an in-session Refresh.

## PvP audit — 4.39.0

Reviewed arena, battleground and world-PvP decision paths: emergency healing, Holy Power spending, hero builds, GCD/charges, defensive overlap and Forbearance, dispel backlash, Beacon ownership, aura maintenance, Freedom, Steed, crowd control and diminishing returns.

Confirmed fixes:
- Emergency Hammer of Justice peels can occur during the first five seconds; offensive setup still waits. Available emergency healing retains priority.
- Channeling enemies participate in control selection and pressure-school assessment using native channel spell IDs.
- Area control is withheld when a nearby enemy has confirmed existing control; the skipped decision is logged.
- Freedom excludes unreachable or healing-immune allies before ranking.
- Beacon of Light does not move onto your existing Beacon of Faith during a pressure swap; another Paladin's Faith does not block your assignment.

Offline validation: 110 behavioral scenarios plus native API compatibility checks; all 10 Lua files compile under LuaJIT. These checks simulate the host and do not establish live PvP performance. The available session.log last records version 4.30.0 on October 10, 2026, and contains no current-version arena combat runs. Actual hidden aura, DR, cast-event, and charge behavior still requires current live logs.

References reviewed:
- https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle (Patch 12.1)
- https://www.icy-veins.com/wow/holy-paladin-pvp-talents-and-builds
- https://arenacoach.gg/guides/holy-paladin-pvp-guide-midnight-season-1 (older season; used for decision-review context)
- https://murlok.io/paladin/holy/ (Season 2 build context)

## Second PvP audit — 4.40.0

- Sacrifice used to prevent incoming breakable CC yields when a reachable ally is at or below 35% current HP or projected emergency HP. Ordinary teammate-save Sacrifice remains available.
- Incoming-CC prevention does not spend Sacrifice while the healer has Divine Shield, or on allies with known Shield, Protection or Spellwarding.
- Dragon's Breath (31661), Sleep Walk (360806) and Seduction (6358) receive high control-dispel priority, including English-name fallback. Priority never bypasses runtime dispel eligibility or Unstable Affliction protection.
- 116 simulated behavioral scenarios passed, including six new anti-CC/dispel checks. Native API compatibility and all 10 Lua files compiled successfully.
- Existing checks cover healing-first ordering, Forbearance-related saves, defensive overlap, DR categories, GCDs/charges, independent logging, aura ownership and distinct Beacons. These are offline checks, not live match certification. The latest available log remains version 4.30.0; fresh arena/BG/world-PvP runs are still needed for runtime confirmation.

Guidance: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle
Dispel/setup context: https://arenacoach.gg/guides/holy-paladin-pvp-guide-midnight-season-1
Seduction spell data: https://www.wowhead.com/spell=6358/seduction

## Arena coordination improvements — 4.41.0

- Offensive healer-stun setups require confirmed full stun DR in arena. Missing or reduced DR blocks the setup branch; emergency peels and cast-control branches retain their own safeguards.
- Arena kill pressure must come from a teammate in combat, not the Paladin's selected target. Controlled kill targets cannot trigger a setup.
- Arena Divine Steed reconnect logic yields to reachable allies at or below 35% current health or projected emergency health. Reconnecting remains possible when emergency allies are unreachable.
- Hammer of Justice decisions log emergency_peel, pressure_peel, healer_setup or cast_control and candidate score.
- 122 offline behavioral scenarios passed, including six new arena scenarios. Current-version live match confirmation remains outstanding. No ranking or flawless-performance guarantee is implied.

Research: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle and https://arenacoach.gg/mistakes

## Arena partner availability — 4.42.0

Offensive healer-stun setup no longer counts dead/invalid partners, partners with confirmed active crowd control, or kill targets with confirmed full damage immunity. Divine Shield and Ice Block provide visible-aura fallbacks; native ANY damage-immunity checks are used when available. Missing helper data does not imply immunity. Existing full-stun-DR and emergency healing/peel logic is preserved. Skip reasons are recorded for controlled partners and immune targets.

127 offline behavioral scenarios passed, including five partner-window checks; native API checks and all 10 Lua compilations passed. Live arena logs are still required to evaluate timing, opponent adaptations and actual runtime data.

Research: https://arenacoach.gg/mistakes and https://www.icy-veins.com/wow/holy-paladin-pvp-guide

## Arena caster swaps and burst trades — 4.43.0

Confirmed active cast targets take priority over selected enemy targets when attributing arena pressure. Unknown cast recipients retain the selected-target fallback. CC peels use that same committed recipient. Arena Sacrifice can trade at up to 80% HP when at least two enemies have confirmed burst active, with healer safety and defensive-overlap checks retained. Prevention records include burst_sources and cast_target_sources. 132 offline scenarios passed; live timing remains unverified.

Research: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle and https://arenacoach.gg/guides/top-10-arena-mistakes-holding-you-back

## Arena review records — 4.44.0

The independent Holy logger records ARENA_EMERGENCY when observed HP enters 35% or below, ARENA_RECOVERY when that ally reaches 60% or above, and ARENA_DEATH only when a retained valid object explicitly reports death. Emergency records include attacker count, confirmed burst-source count, Holy Power and reported Holy Shock cooldown. Recovery cause is unattributed: other players may supply healing. Hysteresis prevents repeated critical-health records on every update. Missing/invalid objects never imply death; state resets between engagements and loading screens.

134 simulated behavioral scenarios passed. These records support future live-log tuning; they do not certify ranking, flawless play, or event coverage when the host hides object state.

## Log-evidence diagnostics — 4.45.0

The inspected session.log contains a 4.44.0 SESSION_RESUME on October 12, 2026, but no subsequent combat runs, cast requests, or state snapshots. No combat thresholds were tuned from this insufficient evidence. New RUNTIME_STATUS records identify ready/waiting-Holy state, class/spec/death observations, plugin/recording switches, mode and combat status. State transitions are recorded even while detailed recording is paused; paused/inactive states do not emit periodic heartbeats. Enabled Holy callbacks emit a heartbeat at most once per minute. Identity lookup errors now reach the Holy error logger.

136 offline behavioral scenarios passed, including idle and paused diagnostics; native API and Lua compilation checks passed. These changes diagnose missing recording; they do not establish whether combat was played in the inspected session.

## Arena rotation and damage — 4.46.0

The arena profile now permits the existing Damage rotation switch to enable a separate guarded damage path. It runs after healing/control/maintenance paths, never through the generic PvE damage spender.

- Requires known roster health, everyone at least 90% current/projected HP, no near-term emergency trend, no confirmed burst/multiple-attacker pressure, at least 25% mana and fewer than five Holy Power. These are conservative implementation thresholds, not source-prescribed values.
- Prefers a valid teammate's target without changing the player's selected target; uses selected enemy as fallback.
- Uses Hammer of Wrath during confirmed wings, then Judgment (with native override handling), then offensive Holy Shock only with two charges and at least 35% mana. Crusader Strike is restricted to confirmed Avenging Crusader and existing five-yard reach.
- Does not spend Holy Power on offensive Shield of the Righteous or use major healing cooldowns for this damage path.
- Requires confirmed line of sight and excludes known immunities. Native weak-CC checks allow damage into stuns while protecting breakable control; missing/invalid category information keeps the conservative generic fallback.
- ARENA_DAMAGE records target, nominal spell ID, assist/selected source and Holy Power.

147 simulated behavioral scenarios passed. Native API checks and all 10 Lua compilations passed. Current-version arena damage performance and thresholds still need live match logs; ranking outcomes cannot be established offline.

Research: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle ; https://murlok.io/paladin/holy/

## Shared arena targets and startup recovery — 4.47.0

Arena damage and healing-resource generators now share target validation: confirmed line of sight, immunity rejection, and weak-control discrimination with conservative fallback. A selected immune/blocked enemy no longer prevents selecting a usable enemy from the pressured ally's known attackers.

Startup now defers while character/class/spec data is unavailable and rechecks once per second until Holy is positively identified. Rogue, Protection and Retribution do not initialize the Holy module or its GUI. Startup errors are warned once and are not automatically retried, preventing duplicate callbacks after partial failure. Refresh remains required after fixing a genuine initialization error.

Validation: 150 simulated behavior scenarios, six isolated loader scenarios, native API checks and all 10 Lua compilations. In-game delayed loading and live arena behavior remain to be confirmed. Research: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle ; https://arenacoach.gg/mistakes ; https://www.method.gg/guides/holy-paladin/playstyle-and-rotation

## Confirmed free healing spenders — 4.48.0

A positively observed Divine Purpose proc (223819) now allows Word of Glory/Eternal Flame below three Holy Power. Critical-heal and out-of-combat top-off paths respect this eligibility. The ordinary recovery path prioritizes the free direct heal at up to 90% observed HP before generating more resources or setting up temporary cooldowns. No proc is inferred from a talent selection or a Divine Toll request. Native spell usability, GCD, range and pending-cast checks remain authoritative.

158 simulated behavioral scenarios passed, including eight free-spender checks across modes and both hero-build spenders. Native API checks and all 10 Lua compilations passed. Current live proc visibility and actual match performance remain unverified.

References: https://www.wowhead.com/spell=223819/divine-purpose ; https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Reach-aware arena healing generators — 4.49.0

Healing-resource damage now selects an enemy within the requested spell reach. An out-of-range selected enemy no longer prevents Judgment or another supported generator from using a reachable pressure target. During Avenging Crusader, ranged generators keep their 30-yard target while Crusader Strike performs a separate five-yard search, avoiding a failed melee request when another nearby enemy is available.

## Reload-safe talent and mode detection — 4.50.0

Talent snapshots now treat a backward host-clock jump as stale and are explicitly cleared on world leave/enter events. Hero, Beacon, PvP-talent and spell-choice decisions therefore re-read the active build after a reload or reconnect instead of retaining the previous session's cached selection. Pending mode stabilization is also cleared so an old arena or instance candidate cannot be held by a pre-reload timestamp.

## Invalid-handle logout durability — 4.51.0

The logout lifecycle reaches the Holy logger before the runtime checks whether the local player object is still valid. A normal logout therefore closes an active run and appends `SESSION_END` even when the client invalidates the character handle before dispatching `PLAYER_LOGOUT`. Combat records continue to append immediately during play, which is the persistence mechanism available for unexpected process crashes.

## Logout backlog recovery — 4.52.0

Combat-time disk recovery remains bounded to protect frame time, while logout now makes a final attempt to drain the complete queued-write backlog after recording `RUN_END` and `SESSION_END`. Confirmed writes are removed in order. If storage remains unavailable, the first failed line and everything after it stay queued rather than being reported as saved.

## Avenging Crusader Hammer of Wrath generator — 4.53.0

The pressure-healing branch now requests Hammer of Wrath during a positively confirmed Avenging Crusader window as well as ordinary Avenging Wrath. This matches the existing guarded arena-damage behavior and the current PvP rotation, which uses Hammer of Wrath and Crusader Strike repeatedly during Avenging Crusader to deal damage and generate Holy Power for Word of Glory or Eternal Flame.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Exact two-window registration — 4.65.0

The retired hidden boss-helper window identity has been removed. The package now registers exactly two windows: the main Holy Paladin panel and the active boss helper. Automated validation enumerates literal window registrations and fails if another identity is added.

## Opening kill-target Beacon tracking — 4.64.0

Persistent PvP Beacon of Light now follows the first sustained kill target after one second of confirmed enemy focus, even when no prior enemy target exists to produce a swap event. Multi-attacker pressure and confirmed burst may move it immediately. Brief target selections are ignored, and Beacon of Faith remains assigned to a distinct teammate.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Arena Holy Shock charge protection — 4.63.0

When the team is safe and Holy Shock reaches two charges, the arena damage window now spends a hostile Holy Shock before Judgment so recharge time is not lost. Judgment remains the preferred safe global with one or fewer Holy Shock charges, and no generator is used at five Holy Power except the already permitted Judgment or Hammer of Wrath pressure path.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Holy Prism resource protection — 4.61.0

Routine Mythic+ and training Holy Prism use now requires two or fewer Holy Power, matching the full-bar generation rule already applied to Divine Toll and emergency healing branches. This prevents a safe damage global from discarding generated Holy Power; urgent healing remains free to use Prism when its healing value matters more than resource efficiency.

References: https://www.method.gg/guides/holy-paladin/playstyle-and-rotation and https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer

## Arena capped-resource Judgment — 4.62.0

The safe arena damage window no longer shuts down at five Holy Power. It may still use Hammer of Wrath or Judgment for damage and Greater Judgment prevention while preserving the full resource pool for Word of Glory or Eternal Flame. Holy Shock and Crusader Strike remain blocked at the cap so their Holy Power generation is not wasted.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## PvP pet and totem generator fallback — 4.54.0

When neither the selected enemy nor an attacker attributed to the healing target is usable, the PvP healing-resource loop now searches visible hostile objects and chooses the nearest safe target within the requested spell reach. This enables the current recommendation to generate Holy Power with Judgment or Crusader Strike on an enemy pet or totem. The fallback retains arena immunity, positive line-of-sight, range, and breakable-control checks.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Safe world-PvP generator discovery — 4.55.0

Automatic generator discovery now requires a positively hostile object. Arena retains full hostile-object coverage for pets and totems. Battleground and world-PvP discovery additionally requires a player, pet, totem, or unit already in combat, preventing the healing-resource loop from starting an unrelated neutral or world-mob pull. A manually selected enemy remains under the player's control and keeps the existing validation path.

## Confirmed hard-cast cancellation — 4.56.0

Redundant Holy Light and Flash of Light cancellation now treats an explicit `false` return from the host as a rejected request. A rejected cancellation no longer shortens the pending-cast latch, starts the cancellation throttle, records a successful cancel, or skips the healing update. Hosts whose cancellation call succeeds without returning a value remain supported.

## Confirmed automatic targeting — 4.57.0

Automatic target selection now records and returns success only when the host call completes without an explicit rejection. A thrown or `false` response no longer produces an `auto_target_priority` success record. Rejected requests use a short retry interval, while accepted and void-return host APIs retain the normal half-second target-selection throttle.

## Engaged and reachable automatic targets — 4.58.0

Automatic target selection now requires the candidate to be in combat or positively tied to a pressured ally. Confirmed blocked line of sight also excludes a candidate. This prevents automatic targeting from selecting an unrelated attackable unit, starting an extra pull, or repeatedly swapping to an enemy the Paladin cannot currently reach with spells.

## Self-focused PvP Aura Mastery — 4.59.0

Devotion Aura Mastery can now answer confirmed burst or multi-attacker pressure when the Holy Paladin is the focused target. The path waits at least three seconds after a recent personal defensive at nonlethal health, respects positively detected damage-reduction overlap, and holds Aura Mastery when Divine Plea's healing penalty is selected unless the Paladin is at lethal health. This closes the previous self-target gap while retaining the existing teammate Aura Mastery logic.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle

## Confirmed Concentration Aura Mastery — 4.60.0

Concentration Aura Mastery no longer triggers merely because an enemy is casting an interruptible offensive spell. It now requires the pressured friendly target to be actively casting or channeling and a hostile player within interrupt range to have a positively confirmed interrupt available. Devotion Aura Mastery retains its separate burst-damage path.

Reference: https://www.icy-veins.com/wow/holy-paladin-pvp-rotation-and-playstyle
