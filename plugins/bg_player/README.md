SYLVANAS BATTLEGROUND COMMAND - v1.92.0 - October 15, 2026

Version 1.92.0 automatically detects the character level and selects a starter,
developing, established, veteran, or maximum-level battleground policy. Lower
levels stay closer to friendly groups, avoid unsupported assaults and uneven
optional fights, and disengage earlier while their spellbooks are incomplete.
The policy keeps urgent flag returns and verified defense authoritative. The
public `get_character_level_policy()` API exposes a role-aware rotation profile
and directive to class combat plugins; those plugins must still verify every
spell, talent, and cooldown against the live learned spellbook before casting.

Version 1.91.0 adds safe Darkspear Islands First Aid recovery. The live bag
scanner recognizes Silk, Mageweave, and Runecloth battleground bandages and
verified Mageweave item 272057. At 35% health or lower it prefers the strongest
bandage for an eight-second recovery; critical mana selects a ration instead.
Combat, a nearby enemy, flag possession, or restored health cancels the hold.

Version 1.90.0 makes Forever flag travel predictions carrier-aware. WSG and
Darkspear carriers now use their documented 85% speed cap for arrival estimates
instead of normal walking speed. Darkspear fallback snapshots expose the
verified 2,000-point win limit, allowing fresh live score feeds to drive the
existing all-in, close-race, and protect-lead strategy without inventing scores.
Snapshot validation rejects impossible carrier speed values.

Version 1.89.0 adds safe active-match recovery with Forever's Darkspear Islands
rations. The controller discovers Field, Iron, and Enriched rations from live
bag data, prefers the strongest available rank, and eats only on Darkspear while
out of combat with low health or mana and no enemy within 45 yards. It holds
movement during recovery and cancels for threats, combat, flag possession, or
recovered resources. Published First Aid spell ranks are cataloged for future
targeted-item support but are not dispatched without a verified item binding.

Version 1.88.0 adds live Darkspear Islands flag-carrier behavior from Forever's
published spell data. Aura 1284560 now identifies the player, friendly, and
enemy flag carriers. Player carriers cannot mount or abandon the objective;
friendly carriers receive role-aware escorts; enemy carriers override routine
base patrols. Without a live friendly-owned turn-in point, the carrier safely
regroups instead of guessing a base. The shared carrier scan now honors the
requested battleground detector for enemies as well as allies.

Version 1.87.0 hardens WoW Forever support from current published rules. Every
Forever build alias now stays inside the four-map WSG, AB, AV, and Darkspear
catalog in route selection and live validation. Darkspear fallback objectives
use a deterministic faction-aware patrol, cache converted landmarks per map and
match, and reset them between matches. The queue UI now describes the published
battlemaster or battleground-entrance flow without claiming an unverified
random, Brawl, Epic, or Darkspear queue ID.

Version 1.86.0 changes the dashboard identity from class/spec artwork to the
active battleground and mode. Warsong, Twin Peaks, Arathi, Gilneas, Eye of the
Storm, Deepwind, Kotmogu, Silvershard, Seething Shore, Deephaul, epic maps,
Blitz variants, training modes, and Forever's Darkspear profile receive their
own title, objective directive, colors, icon, and battlefield motif. Class and
specialization detection now affects gameplay role controls only.

Version 1.85.1 adds layered heraldic icon plaques, beveled buttons, active edge
glows, hover highlights, navigation chevrons, illustrated portrait corners, and
compact ON/OFF switch treatments. Every element inherits the detected class and
specialization palette.

Version 1.85.0 rebuilds the F2 interface as a class-themed PvP dashboard.
The window now uses a persistent specialization header, illustrated left command
rail, central workspace, and war banner. Its second page changes identity and
wording for healer, tank, melee damage, and ranged damage play. Non-damage roles
receive their own playbook instead of irrelevant melee/ranged controls.

Version 1.84.0 completes the SentinelCore reference audit. Stalled movement now
uses a bounded jump as its first recovery stage, then uses an optional three-ray
Project Sylvanas collision probe to choose the clear side before strafing. When
the trace API is absent or ambiguous, the existing alternating recovery remains
in control. ArthasNav still owns every path request and movement route.

Version 1.83.0 adds provider-neutral path-corridor supervision inspired by the
useful recovery concepts in SentinelCore. ArthasNav remains the only navigation
engine. Two confirmed lateral/vertical path departures now trigger a controlled
replan, severe wrong-floor departures trigger immediately, and reverse recovery
is suppressed near steep ramp samples so it cannot back the player off a ramp.

NAVIGATION POLICY
- ArthasNav is the only navmesh provider selected by this plugin.
- The controller uses ArthasNav's owner-guarded client, sends its lease
  heartbeat while enabled, and releases ownership when disabled.
- Authored local direct movement remains the fallback for verified short
  corridors and startup exits.
- Dense recorded field routes now constrain ArthasNav waypoint by waypoint.
  They no longer bypass obstacle-aware navigation merely because their
  coordinates came from a successful traversal.
- Emergency local fallback is limited to a 50-yard leg on the same terrain
  layer, including timeout and provider-error recovery paths.
- BG Player declares ArthasNav protocol 3, API 1, and map schema 1 when it
  acquires the guarded client. A proven contract mismatch blocks the raw-client
  escape path and is shown in diagnostics.
- PS Core SimpleMovement is no longer presented as a navmesh provider. When
  ArthasNav is unavailable, only explicitly authorized short local corridors
  can move; arbitrary field travel fails closed.
- The dormant PS SimpleMovement/Kebab adapter and its per-frame worker are
  removed. ArthasNav has one unambiguous owner for ordinary battleground
  routing, with fewer module loads and less work during F6 reloads.
- The now-unreferenced Kebab bridge module is removed from the package, and a
  packaging regression prevents that alternate pathfinder hook from returning.
- Removed the final dead standalone/Sentinel bootstrap variables and provider
  identity branches. Runtime provider discovery and quarantine now describe
  only the ArthasNav engine the controller can actually select.
- The installed ArthasNav entry point now has an F6 generation guard around
  update, render, menu, window, and game-event callback registration. Earlier
  runtime generations become inert after reload, preventing the duplicate
  navigation work and log lines observed in the live session.
- Companion addon 0.6.2 publishes `C_PvP.GetBattlefieldFlagPosition` map hints
  on Retail and Forever. BG Player validates ownership, session, sequence,
  map, index, normalized coordinates, token, freshness, and conflicts, then
  displays the result in DEBUG. These hints are telemetry-only until they can
  be snapped to a verified route corridor and terrain layer.
- Flag publisher clock reads and BigWigs callback discovery are fault-isolated;
  missing or protected APIs now produce a visible bridge state instead of an
  uncaught addon error.
- The companion TOC explicitly includes Forever interface `16001` alongside
  Retail interfaces, preventing the shared bridge package from being rejected
  as out of date on Forever 1.60.1.
- Sentinel and NavLib are deliberately ignored even when installed.

Status: integration prototype; autonomous battleground gameplay is incomplete.
The bundled BigWigs companion v0.5.0 supplies fresh Midnight/Forever Random and
Epic queue catalog, slot status, and verified queue identity. Built-in objective
formation fallback and map-name detection run on Forever. Exact objectives and
authored routes remain guarded by the detected battleground profile.

FOREVER SUPPORT - v0.80.1
- Current Sylvanas identifies the Blizzard beta as Forever / wow_forever_beta_us.
  The compatibility layer accepts this exact client key and reports the live
  patch, build number, and interface version from core.get_game_build().
- Forever exposes only the live-verified Random Battleground queue in this
  plugin. Blizzard's current Forever material lists four battlegrounds and no
  Brawl or Random Epic mode, so both unsupported choices are hidden on Forever.
- Forever gameplay recognizes Warsong Gulch, Arathi Basin, Alterac Valley and
  Darkspear Islands. Darkspear uses its own hybrid base-and-central-flag rule
  identity and falls back to the live team formation until map-specific
  objectives or recorded routes are observed.
- The authenticated local queue reader now runs on standard Midnight and Forever
  clients. Private-server variants remain excluded because their contracts differ.
- Native Forever queue status, accept, match state, winner, team, generic join,
  and leave calls are used directly from the documented Sylvanas bindings.
- A future core.input.join_brawl binding is detected automatically. Current
  Sylvanas builds do not expose that action; set_version_adapter({join_brawl=fn})
  remains required for automatic brawl entry. join_battlefield is never misused
  with a brawl identifier.
- Battleground detection falls back from instance ID to UiMap ID to normalized
  instance name, which covers Forever clients whose numeric map identity differs.
- Built-in objective discovery uses live objects and friendly formation state;
  mounted navigation uses live world coordinates, Sentinel results, authored
  recovery corridors, automatic dismount, and bounded on-foot recovery without
  a Retail-only branch.

CURRENT AUDIT CHANGES
- Thirteen original full-window horror battleground illustrations are embedded
  in Lua and selected automatically by player class. Forty specialization themes
  then add their own title, crest, palette, controls and battlefield treatment.
- A full-window illustrated crypt battlefield is now embedded as Lua and drawn
  at full strength, matching the Bloodcrypt reference's visual quality. Each
  class/spec receives its own color grade, title, crests, banner and controls.
- The F2 window now has a dedicated, always-visible class/spec war-banner column
  with full-strength spec art, class heraldry, blood drips, skull ornamentation,
  PvP title, and class/spec name. Operational panels are more translucent so the
  themed battlefield artwork remains visible across every page.
- ArthasNav height projection is now treated as an optional capability. If its
  packaged height helper/configuration is unavailable, BG Player disables that
  probe for the session, preserves the live XYZ, and immediately submits the
  route through ArthasNav's core movement contract instead of stopping.
- The F2 command window now uses the installed Assassination Rogue GUI's proven
  large-canvas structure: dark battlefield foundation, outlined hover controls,
  image-backed buttons, strong header hierarchy, and procedural offline art.
- Automatic class/spec detection now selects one of 40 distinct horror-PvP
  identities. Every current spec, including Devourer, has its own crest icon,
  accent and blood palette, battlefield motif, and PvP title.
- All 13 class and 40 specialization crests are embedded in a Lua artwork atlas
  and appear in the full-canvas background, tabs, and image-backed controls.
  Project Sylvanas' shared icon helper supplies any future missing asset and
  caches it under scripts_data. The package remains Lua/Markdown-only.
- The 3D route overlay now defaults off under a fresh saved setting. It remains
  available from Options for diagnosis, but ordinary gameplay no longer pays
  for dozens of world-space draw calls on every rendered frame.
- Queue/addon polling, readiness accounting, journal flush checks, ArthasNav
  ownership maintenance and export discovery now share a 4 Hz supervisor.
  Queue freshness remains at its existing 250 ms contract, while redundant
  frame-rate-scaled protected calls are removed.
- Mount requests now remain in a confirmation state for the full cast window.
  Navigation stays stopped until live `is_mounted()` confirms success; an
  interrupted or rejected request retries after one second instead of silently
  waiting through the ten-second success cooldown.
- Navigation now holds while the player is stunned, rooted, feared, or
  charmed. These expected crowd-control stops no longer become false stuck
  detections or trigger route recovery; planning resumes after control returns.
- MF Navigation's environment profiles were compared against ArthasNav. BG
  Player now preserves live water-surface height while swimming instead of
  projecting a destination to the lake or river bed.
- Mounted travel widens straight, level waypoint acceptance by a bounded 35%.
  Corners, reversals, ramps and layer transitions retain their existing tight
  three-dimensional checks, preventing speed compensation from skipping them.
- Forever now passes the detected Horde or Alliance team directly into
  ArthasNav once per team change. This covers Forever sessions where race and
  faction IDs temporarily report zero without adding per-frame work.
- The supplied legacy mmap collection was audited rather than copied blindly.
  Its classic coverage is older or smaller on several maps and it has no map
  2524 data, so Darkspear keeps the safer landmark/live-coordinate fallback.
- WSG flag-room exits now use short local steering because live v0.78.0 logs
  prove Sentinel repeatedly rejected the indoor Horde waypoint as off-mesh.
  Field travel remains on Sentinel. Both faction exits use the same policy.
- Darkspear's five published normalized map landmarks are converted to current
  client world coordinates at runtime, checked against instance 2997, measured
  for terrain height and linked through a conservative objective graph. This
  adds real strategic movement without inventing ownership or interaction state.
- Authored route selection now has an explicit client boundary. Warsong Gulch,
  Arathi Basin and Alterac Valley are deliberately shared by Retail/Midnight
  and Forever; Darkspear is Forever-only; every other current graph is blocked
  on Forever. Unknown identity during login retains existing behavior until the
  automatic detector resolves, avoiding a startup movement regression.
- Client identity is now detected automatically from Sylvanas at runtime. The
  plugin reads the game family, exact product key, patch, build and interface,
  retries transient unknown values during login, and refreshes build data every
  30 seconds. Queue choices, diagnostics and route policy use this one result.
- Learned routes and failure history are partitioned by exact client product
  key. Forever, Midnight, Classic and private variants cannot inherit each
  other's successful corridors, blacklists or recovery detours.
- Forever continues to expose only its verified Random Battleground automation.
  The plugin does not guess Brawl or Random Epic support from dormant client
  records. Darkspear remains a distinct hybrid objective profile with verified
  instance/UI map IDs and safe formation fallback until live world-coordinate
  routes and objective objects are observed.
- Learned route keys now include battleground profile and faction, preventing a
  similarly named objective on another map from inheriting unrelated history.
- Temporary class/spec read failures retain the last positively detected role
  for the same character; a changed character GUID clears the cache.
- The callout reader retains simultaneous locations and chooses the largest,
  freshest active threat. Clearing one location reveals the next active call.
- Queue join and accept attempts now record slot, mode, queue ID, and role flags.
- Match summaries now include observed outcome and whether decisions used live,
  fallback, mixed, or no objective data.
- Multiple live Seething Azerite objects receive position-qualified IDs.
- Seething Shore now detects loaded Azerite objects as live objectives for tank
  and damage roles. Healers continue supporting the friendly formation. Its
  airship exit and live-observed direct ground graph avoid Sentinel requests
  while airborne and on ground sections rejected by the server navmesh.
- Learned route successes, failures, and successful detours persist under
  scripts_data/sylvanas_battleground_bot/routes and are restored after reloads.
- Every completed battleground emits one compact match_summary containing map,
  role, duration, deaths, navigation failures, recoveries, stationary time, and
  controller state changes.
- Falling pauses ground path requests on every map. Healers hold movement during
  active casts/channels and resume the objective after the cast ends.
- Every structured diagnostic event is appended immediately to
  scripts_log/sylvanas_battleground_bot/session.log. A bounded reloadable copy
  is checkpointed every two seconds under scripts_data, so Copy Debug Report
  includes recovered history after a disconnect, script reload, or game crash.
- Healer group anchors now use six-second/30-yard hysteresis. The controller
  finishes a meaningful support leg before accepting a materially different
  formation position, preventing rapid teammate changes from producing the
  Deepwind Market/Quarry zigzags seen in the live v0.35.0 journal.
- DPS can respond to urgent team-chat objective callouts in battleground and
  instance chat. The reader understands common location names and abbreviations,
  requires words such as inc, incoming, help, or defend, records attacker counts,
  expires calls quickly, and cancels them on clear, safe, nvm, or nevermind.
- Healers now use a live backline formation point about 18 yards behind the
  friendly objective group relative to visible enemies. This keeps normal heal
  range while reducing center-of-pack exposure and follows a friendly flag
  carrier without sending the healer flag hunting.
- Route recovery remembers cleanly completed legs and successful obstacle detours
  for later matches in the same Sylvanas session. A leg that stalls three times
  is avoided for one hour, and its successful side approach is preferred on the
  next traversal instead of retracing the failed line.
- Silvershard Mines now discovers live mine-cart creatures by entry 60140 and
  routes to their current world positions. It no longer represents a friendly
  player as an escort_cart objective. If no real cart is loaded, movement pauses
  with silvershard_cart_data_unavailable instead of following a fake cart.
- DEBUG now labels the objective source as live_objective_reader or
  team_formation_fallback so each live map run immediately shows whether it has
  a dedicated reader or still needs map-specific objective integration.
- The overnight diagnostic journal retains up to 5,000 events. On fallback maps
  it samples visible non-player objects every ten seconds, recording deduplicated
  entry IDs, object type, name and world position on a ten-yard grid. COPY WAR
  LOG exports the unified debug journal for later map-reader work. State changes
  are included once instead of being repeated in a second appended section.
- Every live queue slot whose status is confirm is accepted immediately without
  invitation type, queue-mode, queue-ID or ownership verification.
- Active class and specialization now determine tank, healer or damage role
  automatically. The detected role supplies queue role flags and objective score
  adjustments. Healers favor group support, escorts and contested defense;
  tanks favor flag/orb carrying and guarding owned objectives; damage specs favor
  captures, recaptures, interception and active fights. On formation fallback
  maps, healers follow the friendly player nearest the visible team cluster.
  Unknown specializations retain the configured queue-role fallback.
- Healer movement does not claim enemy targets, leaving friendly target ownership
  to the external healing plugin. Active casts and channels hold movement, then
  the controller reacquires the current objective when casting finishes.
- A queue started by this controller is now retained as owned queue continuity.
  When the local bridge temporarily loses invitation type metadata at the
  queued-to-confirm transition, the same sole observed slot can still be
  accepted. First-seen, ambiguous, arena and concurrently observed invitations
  remain untrusted.
- World-space destination and Sentinel route markers are lifted 3.5 yards above
  their ground positions so the lines and circles remain visible above players.
- Stable routes are checked for real position progress. Two stalled windows ask
  Sentinel to replan; a third alternates a short right/left strafe, stops the
  strafe after 0.8 seconds, and reacquires the objective route. Any real movement
  resets the sequence. Sentinel retains its own obstacle probing, avoidance,
  jumping and backtracking recovery underneath this controller-level fallback.
- When Sentinel exposes its detailed state, the outer stall watchdog runs only
  during following_path. Awaiting a server path, cast deferral, Sentinel's own
  recovery and an active repath are allowed to finish without competing replans.
- Supported battleground profiles are detected from instance ID, UI map ID, or
  localized English instance name. Maps without a dedicated objective reader use
  live friendly-player formation movement so they leave spawn and stay with the
  team. Formation movement is a fallback and does not claim live node ownership,
  flag-carrier, vehicle, gate, cart, or resource state.
- Automatically detects supported battleground profiles from live instance and
  UI map IDs. Instance 998 / map 417 selects Temple of Kotmogu.
- Temple of Kotmogu has a built-in objective reader using researched orb world
  positions and object IDs. It moves to a live loaded orb, interacts at arrival,
  detects the four carrier auras, and routes carriers toward the scoring center.
- Sentinel destinations dispatch directly through move_to. Sentinel v0.0.8
  performs off-mesh snapping internally; failures return through the existing
  retry/replan path without a separate validation wait.
- Older Sentinel builds receive a navmesh-height query before move_to, avoiding
  HTTP 422 errors caused by objective models sitting above the walkable floor.
  Ordinary combat/healing casts no longer cancel the route; Sentinel defers and
  resumes movement itself. Confirmed capture interactions still hold position.
- New queue requests use verified queue data. A fresh live confirm slot is
  accepted immediately without objective, navigation, catalog-name, or
  invitation-metadata gates. Objective movement remains paused
  until fresh objective data and Sentinel Navigation are available.
- Stopping or invalidating a plan clears only a target still matching the GUID
  selected by this controller. A target replaced by the user or another plugin
  is retained. The existing transition into objective carrying clears targeting.
- Objective interactions revalidate the object and its type: units use native
  interact_with_object, world objects use use_object. An unavailable type/API
  or refused request does not trigger a second, different interaction.
- Menu and command-window failures recover separately after two seconds;
  failed display-data reads use fallbacks and appear in DEBUG. These UI failures
  do not disable gameplay or consume the controller's runtime retry allowance.
- Hybrid flag delivery rejects a named tower that is destroyed or explicitly
  unreachable, as well as enemy-owned, inactive or contested towers. It uses a
  verified safe_position or pauses. A locked but valid owned tower remains valid.
- Capability reports follow the selected queue mode. Brawl needs join_brawl;
  a generic join_battlefield binding is not a replacement for it.
- The local probe uses literal SBGLOCAL3~GUID~SEQ~RANDOM~EPIC labels, records
  callback/readability/cleanup diagnostics, and removes a captured bar only while
  its public CandyBar ownership tag still matches. The native reader also accepts
  legacy SBGLOCAL2 pipe packets and reports readable-label/candidate counts.
See AUDIT_4.md and BRIDGE_FINDINGS.md for evidence and remaining limitations.

LIVE STATUS AND VALIDATION
Controller v0.25.2 was live-verified joining the Random Battleground queue with
configured ID 0 resolved from the live catalog. The command window reported
Waiting in queue and WoW confirmed the queue join. Matching invitation acceptance
uses the same verified live identity and is enabled; an invitation had not yet
arrived during this check.

Controller v0.25.1 and companion v0.4.1 were checked live on Retail. WoW emitted
an advancing SBGQ1 packet with zero current slots; Sylvanas received 52 updates,
resolved Random queue ID 32 and moved to objective_provider_required. Client APIs
and Navigation reported Ready, with no runtime, reader or render errors.

Retail UI and diagnostic commands have been checked. The earlier v0.23.1/v0.3.0
test reported native loaded=true, bars=1, receipts=0 and a visible blank 24-hour
bar. With v0.24.0/v0.3.1, /reload created the literal tilde-delimited label;
WoW reported bar_confirmed with one matched callback, readable/equal label and
shown=true. Sylvanas reported local_data_received and zero runtime errors.
The test bar disappeared after 30 seconds; /sbgstatus confirmed active=false and
cleanup=owned_bar_stopped. This verifies receipt and owned cleanup on this Retail
setup; actual queueing and objective gameplay remain unverified.
All 22 Python/Lua regression test files passed for the current source. Mock tests
do not establish combat, resurrection or compatibility across clients. No full
battleground gameplay loop is verified.

USE AND GUI
This plugin is self-contained and does not require Master Farmer, the Sylvanas
leveler, or any other gameplay plugin. It imports only its own `bg_*` modules
and Project Sylvanas' built-in `common/*` API helpers. ArthasNav and the selected
combat plugin are the only intended runtime companions.

Enable ArthasNav and your combat plugin. Open the command window with F2, from
the HUD's OPEN button or the native plugin menu. Battle, Options, War Log and
DEBUG pages provide Start/Stop, queue mode, role/range controls and copied reports.
QUEUE FOR selects Random Battleground, Brawl or Epic Battleground, with a separate
actual client-specific queue ID for each. On Retail Random/Epic, 0 automatically
uses the fresh live catalog ID. Changing the selector does
not cancel an existing queue. Unmatched or ambiguous invitations are ignored.
Use a single movement controller; another plugin taking movement or targets
requires an explicit integration arrangement.

The GUI reads the class/spec on rendering, including while stopped, and changes
colors and original embedded heraldic JPG badges. Known classes/specs have
themes; unknown specs fall back to the class, loading to neutral. No runtime
image download or official WoW spell-icon art is required. Retail display was
checked; every class/spec and client has not been checked live.

LIFECYCLE AND CLIENT ADAPTER CONTRACT
SylvanasBattlegroundBot.get_capabilities() reports version, exact_version,
ready, missing[] and operation booleans for the selected mode. ready covers the
lifecycle interface only; gameplay additionally requires provider and navigation.
set_version_adapter(table) replaces the supplied override set; nil restores
native paths. Operations must normalize actual working client results:
queue_status(index) -> "none", "queued", "confirm", "active", or nil unknown;
queue_info(index) -> {kind="battleground"/"arena"/"wargame", queue_id=actual_id,
 queue_mode="random"/"brawl"/"epic", observed_at=core.time() of observation,
 suspended=boolean, is_battleground=verified_War_Game_type_if_applicable};
accept(index, true); join(queue_id, role_flags); join_brawl(); leave();
match_state() -> 2 preparation, 3 active, 5 complete, nil unavailable;
winner() -> nil undecided, 0 Horde, 1 Alliance, 2 tie.

The native queue-status string does not provide queue_info. Metadata must be
fresh and identify the actual invitation. Do not copy the configured menu ID
into unobserved metadata. Retail Random/Epic joins use catalog bgID, not bgIndex;
Brawl uses its separate join operation. Catalog IDs are not invitation proof.

Documentation-based native lifecycle support:
- Midnight/Forever: queue, accept, match phase, winner and leave paths.
- Tbc/Mop: queue, accept and winner paths; match phase needs an adapter.
- Era/Vanilla, Titan, private and unknown/new clients: additional lifecycle
  adapters required. Function presence does not prove a non-stub binding works.
All clients still need queue_info. Native support is not an all-version test.
Queue catalog, roles, objective observations, map layout and navigation meshes
must match the actual client. The dropdown is not a current queue-roster source.

OBJECTIVE PROVIDER CONTRACT
set_objective_provider(function(player, match_id) ... end) registers a reader.
Return a new snapshot from actual game observations. Required baseline:
valid=true; match_id matches the supplied argument; observed_at uses core.time(),
is nonfuture and at most two seconds old; team=0 Horde or 1 Alliance; live
player_position={x,y,z}; and a supported kind or correct rule_profile/mode.
World positions must include verified height; normalized map coordinates are
not world coordinates. The team is the current PvP team, including Mercenary
assignment. Refresh timestamps only when data is actually observed again.

Rule profiles in bg_rules.lua describe decision policies, not live observations,
queue IDs, fixed coordinates or guarantees that a map is available now. They
cover flag, base, hybrid, orb, cart, resource, crystal, frontline and siege
families, with explicit legacy, Blitz and supported Training variants. A provider
must choose the actual layout and mode. All Brawls are not implemented.

Per-policy fields include current objective positions/IDs, owner/state,
active/destroyed/reachable/capturable/locked, threat/defender counts and actual
interactable objects. flags/orbs/crystals may expose pickup_allowed and current
carriers. Carrying requires verified carry_destination or safe_position;
hybrid carry_destination_node_id revalidates its tower. CTF delivery requires
own_flag_home=true; orb_scoring_position and carrier_in_danger are observations.
capture_in_progress holds movement and interaction during actual capture.
Cart control_radius is measured in world units; friendly_count/enemy_count
exclude the local player. Resources use live active/depleted/mineable/ready_at.
Snapshot arrays, booleans, counts and detached positions are validated.

Siege objectives need verified prerequisites, attackability and, for round maps,
round_role/round_id. Required vehicle or gate actions need handlers registered by
set_objective_actions({vehicle=fn, siege_gate=fn}). No vehicle/siege executor is
bundled. Missing handlers pause with objective_action_adapter_required.

COMBAT, DEATH AND RECOVERY
Rotations remain in your own combat plugins; no class/spec rotations are added.
get_context() publishes the plan, team, carrying state, match_id, original
observed_at and published_at, plus advisory avoid_mount, avoid_stealth,
avoid_objective_dropping_abilities and hold_combat. Combat plugins must explicitly
honor that context and objective movement ownership; this controller does not
patch their spells or targets. Normal targeting uses observed attackable enemy
players near the objective and line of sight. Special NPC objectives and verified
Training opponents are explicit exceptions, not incidental NPC selection.

In battlegrounds, the controller releases a dead player and holds while ghosted
for Spirit Guide resurrection. Once alive, active phase plus fresh valid objective
data resumes planning and movement. Actual return from the graveyard remains
untested; unavailable data/navigation produces a diagnostic pause. Open-world
corpse recovery uses an observed corpse position/delay, navigation and reclaim;
unsupported instances pause. No universal resurrection timer or AFK motion is used.
Match completion needs observed phase/winner; leave/requeue never uses a guessed
match duration. New queues observe the actual Deserter aura, not a fixed penalty.

Navigation has retry backoff and stalled-route monitoring. Provider failures use
2/4/8-second retries then 30-second probes while death/completion remain available.
Controller/action errors use bounded 2/4/8-second retries and a fault lock after
four repeated failures or failed cleanup; START resets that lock. Valid observations
resume provider execution. This is bounded recovery, not automatic code rewriting.

DEBUG AND OPTIONAL LOCAL PROBE
DEBUG and COPY DEBUG REPORT include state, phase/queues, destination, position,
data age, missing APIs, provider/runtime/UI recovery, local-reader counts/errors
and at most 100 recent diagnostic events. show_debugger(), get_debug_snapshot(),
get_debug_report() and clear_debugger() expose diagnostics without code execution.
get_bridge_status() reports the diagnostic link. The probe is not a provider.
See ../BG_LINK_PROBE_README.md for /sbgbar, /sbgstatus and the two-sided test.

INSTALLATION AND NEXT REQUIREMENTS
Copy this directory as `bg player` into the Sylvanas scripts folder.
The user authorized updates in this chat to the existing destination:
C:\Users\tturn\OneDrive\Desktop\wowxe\877cd2847fccb01a52d4ac407ba1\scripts\bg player
Keep rollback copies outside the scripts tree under
`scripts_data\sylvanas_battleground_bot\backups`. A backup containing an enabled
`header.lua` inside `scripts` can be discovered as another plugin, producing
duplicate controllers, duplicate log writes, movement conflicts, and reload lag.
No recurring background updater is created. Reload scripts after an update; the WoW
companion is separate and requires its own addon reload.

Remaining: extend the proven local transport or supply a supported native binding
for fresh actual invitation metadata and objective observations; provide unsupported
client lifecycle and needed vehicle actions; validate the complete live loop and
combat-plugin cooperation per client. Do not label this prototype 100% automated.
API contracts: https://docs.project-sylvanas.net/dev/
Research, access limits and source links: AUDIT_4.md and BRIDGE_FINDINGS.md.

BUILD 0.44.0 AUTOMATION
- Objective travel under 45 yards stays on foot.
- Mounted path failures dismount automatically, take one bounded on-foot step,
  release movement input, and retry normal navigation.
- Remounting requires both 45 seconds and 25 yards of clearance from the failure.
- Missing on-foot navmesh escalates to a quiet 30-second probe circuit.
- Grizzly Hills Packmaster remains the preferred mount.
- Full details and validation: AUDIT_15.md.

BUILD 0.45.0 PATHING AUDIT
- Off-route spawns enter through the nearest verified graph node.
- Warsong healer and formation movement can use the verified flag corridor.
- Timeouts and severe failures are tracked per route leg.
- Repeated bad legs receive a temporary detour; successful arrival clears it.
- Bundled route graphs pass coordinate, link, and connectivity validation.
- Full findings and validation: AUDIT_16.md.

BUILD 0.45.1 HEALER MOVEMENT
- Channels and meaningful hard casts pause movement; nearly finished cast edges do not.
- A lost mount cannot be recast for 20 seconds, reducing mount/cast/path churn.
- Full findings and validation: AUDIT_17.md.

BUILD 0.46.0 HEALING GROUP SELECTION
- Healers follow the densest 55-yard friendly cluster instead of the whole-team midpoint.
- Injured groups win equal-size ties; compactness and travel distance break later ties.
- The selected group retains the existing 12-second and 45-yard stability rules.
- Full findings and validation: AUDIT_18.md.

BUILD 0.47.0 ROUTE QUALITY
- Graph routes minimize physical travel distance instead of waypoint count.
- Healers approach within 25 yards of the selected formation anchor.
- Large group rotations switch after 12 seconds; gradual movement refreshes after 30 seconds.
- Shifts of 12 yards or less do not rebuild the route.
- Full findings and validation: AUDIT_19.md.

BUILD 0.47.1 DEEPWIND PATHING
- Nearby same-level healing groups use a local Sentinel path instead of backtracking through quarry.
- Cross-map group rotations continue to use the Deepwind strategic graph.
- Failed local paths force graph routing for 60 seconds before local routing is retried.
- Full findings and validation: AUDIT_20.md.


BUILD 0.43.0 - COMPLETED IMPROVEMENTS

[x] Objective commitment: the currently valid scored objective gains a small
    12-point preference. Urgent defenses, recaptures and flag returns outrank
    routine objectives. Invalidated objectives immediately lose their preference.
[x] Deterministic tie selection: kind, ID and position resolve equal scores,
    avoiding changes caused solely by provider enumeration order.
[x] Healer corridor routing: distant live support requests the authored map
    graph. Close support avoids unnecessary graph requests. Generic formation
    support keeps its existing 35-yard hold range; live support uses 12 yards.
[x] Route input validation: routes must be contiguous, bounded to 512 points,
    and contain finite world positions and correctly typed metadata. Coordinates
    are copied. Positive finite waypoint radii are clamped to 2-18 yards.
    Invalid routes stop movement and publish a diagnostic state.
[x] Navigation callback lifecycle: completed legs, changed objective keys and
    changed formation anchors stop old movement and invalidate old callbacks.
    Late errors from a previous leg cannot clear a newly dispatched destination.

Validation: all Lua files compile under the test Lua runtime. Sixteen regression
suites passed, including new commitment, emergency priority, deterministic tie,
route validation, waypoint arrival and stale callback scenarios. These are
mocked checks. Real battleground behavior still requires a script reload and
live verification with the user's combat plugin and Sentinel client.

BUILD 0.43.1 - MOUNTED PATHING

- Mount choice is Grizzly Hills Packmaster, selected by the documented live
  mount_name field. If absent or unusable, the journal records that reason;
  another mount is not silently substituted.
- Stop, mount settling, casting holds and new movement requests invalidate
  delayed height and navigation callbacks. A late height response cannot restart
  movement after stopping or replace a newer route.
- Height projection is accepted only within three yards of the observed goal Z,
  preventing a query from replacing a bridge/floor destination with another level.
- Arrived outside the real controller arrival range triggers cancellation and
  replanning; three repeated early arrivals to the same goal use ten-second
  retry backoff. It does not mark the objective reached or steer through obstacles.

Evidence: supplied Silvershard report shows arrived about 90 yards from the goal.
The report does not establish Sentinel's internal cause. These changes address
observable arrival mismatch and callback lifecycle faults in our adapter.

Validation: existing sixteen regression suites plus the new mounted navigation
suite pass. Includes callback cancellation, other-floor projection, preferred
mount selection, premature arrival and bounded retries. Live mounted pathing
requires reload and a fresh match report.

BUILD 0.43.2 - STUCK APPROACH RECOVERY

Healer support now uses the observed teammate position. Removed the synthetic
18-yard XY backline offset that retained the teammate Z without terrain proof.
Outstanding destinations in idle/failed navigation now participate in the
seven-second position-progress watchdog and normal replan/escape recovery.
After three premature arrivals, a supported reverse adapter performs a four-yard
backward command for 0.8 seconds, releases input and replans. Without that adapter,
the existing ten-second retry backoff applies. No direct obstacle bypass added.

Seventeen mocked regression suites passed, including added idle-stall and bounded
reverse recovery checks. Live Silvershard movement remains to be verified.
Grizzly Hills Packmaster remains selected.

BUILD 0.43.3 - MISSING NAVMESH CIRCUIT BREAKER

The supplied 0.43.2 Warsong report and server log show repeated HTTP 422
Position not on navmesh with no authored fallback route. Without such a route,
two full path timeouts or a reported severe path failure now stop rapid retries.
Probe once every 30 seconds; moving more than eight yards from the failing
position permits an immediate new attempt. Changing the healer goal cannot
bypass the circuit. Removed the timeout replan call before fallback selection,
which could restart the cancelled server request.

Seventeen mocked regression suites pass, including circuit opening, suppressed
requests and position-based reset. Packmaster selection remains unchanged.
This contains request storms; it does not provide missing server mesh coverage
or verify an off-mesh recovery route. Live pathing remains unresolved where
Sentinel cannot route from the current position.

BUILD 0.43.4 - MOUNT-AWARE PATH RECOVERY

Mounted path failures now attempt the documented core.input.dismount operation,
stop pending navigation, clear failed path state, and retry after one second.
Triggers: eight-second path timeout, two premature arrivals, position stall,
severe callback error, or an existing blocked-mesh state. On-foot failures keep
their existing bounded recovery and probe policy.

After recovery, automount is suppressed until BOTH 45 seconds have elapsed and
the player has moved at least 25 yards from the failing position. Preferred mount
remains Grizzly Hills Packmaster. Missing/failed dismount bindings preserve the
normal recovery path rather than claiming a successful dispatch.

Validation: seventeen mocked regression suites pass, covering mounted timeout,
route cleanup, on-foot behavior, and remount time/distance guards. The supplied
logs also show Sentinel's internal retries after controller cancellation; those
bundled-library retries are not repaired by changing this plugin. Dismounting is
a mount-specific fallback, not proof of navigation coverage or graveyard escape.
Reload scripts and verify mounted-to-foot recovery live.
0.81.0 adds cross-mode match-flow prediction from live capture deadlines. It estimates arrival time conservatively, promotes reachable urgent defense/capture work, and does not invent timers when the client/provider has none.

0.81.1 adds bounded live score-velocity prediction. When consecutive trusted score samples show a clear race, the planner shifts toward recovery pressure or protecting a lead. Score resets, large jumps, stale samples, and missing values produce no prediction.

0.82.0 imports two proven patterns from the installed plugin family: adaptive update pacing to reduce combat/reload pressure, and multi-sample target health forecasting to finish confirmed collapsing enemies without changing healer-first role priority.

The command window remains lazy to avoid F6 reload stalls: press F2 to show or hide it. The Project Sylvanas menu label also displays the shortcut.

0.83.0 adds predictive Sentinel corridor preflight across all battlegrounds. It detects a real A-B-A trackback before physical sticking, requests at most two Sentinel replans per match, records the event, and ignores duplicate path points. Enemies actively targeting the player also receive a bounded bonus within their existing healer/DPS/tank tier.

0.84.0 reads Sentinel's live corridor-width API and dismounts before a verified narrow section instead of waiting for the mount to collide. It retains on-foot mode for 30 seconds and until 15 yards of progress, preventing an immediate remount loop at the same doorway.

0.85.0 adds a Sentinel waypoint-progress watchdog across every battleground. If the live route remains on the same waypoint for six seconds, even while collision jitter changes the player position, it records the failure and requests a bounded replan. Planning, recovery, avoidance, arrival, and direct authored routes are excluded; the match-wide budget is two proactive replans.

0.86.0 isolates all optional Sentinel route telemetry reads from active gameplay. A transient failure in state, path, waypoint, corridor-width, or progress inspection now skips prediction for that tick, logs a rate-limited diagnostic, and leaves navigation running instead of entering the controller-wide runtime recovery pause.

0.87.0 reduces crowded-fight targeting cost across every battleground. Nearby teammate GUIDs are indexed once, so checking whether enemies are attacking the group is linear instead of comparing every enemy against every teammate. Native objects without stable GUIDs retain the protected identity fallback, and existing healer/DPS/tank priority is unchanged.

0.88.0 adds a bounded two-second opponent-role cache. Crowded combat no longer repeats native class and specialization reads for every visible enemy on every 0.10-second decision tick. Target roles refresh quickly, cache failures resolve safely to unknown, and stale GUIDs are pruned without changing healer/DPS/tank priority.

0.89.0 fault-isolates Sentinel movement commands as well as telemetry. Exceptions from stop, height projection, destination validation, direct movement, normal movement, or completion callbacks now return a precise failure through the existing bounded recovery flow instead of escaping the navigation adapter and interrupting the controller.

0.90.0 detects shared-Sentinel destination displacement. While the battleground controller owns a generated route, two consecutive destination mismatches stop the foreign path and redispatch the verified battleground goal. Height projection tolerance is preserved, authored direct routes are excluded, every event is journaled, and reclamation is capped at three attempts per match to prevent plugin contention loops.

0.91.0 expands adaptive-performance evidence without adding gameplay scans. The runtime now tracks exponentially weighted average time, session maximum, slow-tick count, and sample count, and journals only pacing-tier changes. This makes intermittent combat or routing stalls visible while preserving the existing automatic 10–20 Hz load reduction.

0.92.0 improves combat handoff around pillars and corners. A nearby verified plan target or enemy actively fighting the local group can remain selected through a brief line-of-sight break, allowing Sentinel to route into combat instead of resuming unrelated objective travel. Pursuit is limited to 35 yards and the same vertical layer, carries a scoring penalty, and remains disabled on EOTS profiles where only raw local steering is available.

0.93.0 adds capture-interaction confirmation. After an objective click is accepted, the controller holds position, keeps facing the object, and waits 2.5 seconds for live capture/objective state instead of issuing a second click that could interrupt the first cast. Explicitly refused clicks retain fast retries and the existing three-failure cooldown; accepted and refused attempts are journaled.

0.94.0 bounds optional battleground power-up pursuit. A useful nearby speed, restoration, or berserking pickup may divert movement for at most eight seconds; if geometry prevents collection, it is suppressed for 30 seconds and objective play resumes. Reaching pickup radius retains the existing 60-second deduplication, and changing matches clears all pursuit state.

0.95.0 fault-isolates optional vehicle and siege objective adapters. An adapter exception now returns an ordinary failed action, keeps the controller alive, and writes a rate-limited traceback tagged with the action name. Confirmed successful actions retain readiness evidence and normal one-second action cadence.

