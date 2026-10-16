# MasterArthasNav architecture study

Reviewed the downloaded folder and the fresh `turner1211/mf-arthas` checkout on 2026-10-16. The checkout is the editing/publishing source; the downloaded ZIP is unchanged.

## Repository

`plugins/` contains 16 navigation, combat, healing, battleground, leveling, diagnostic and shared-UI projects. `loaders/` contains their small stable host-facing entrypoints. `tools/loader_template/plugin_loader.lua` is the existing asynchronous HTTP implementation. It resolves a GitHub commit, downloads a manifest and changed project files, stages a build in `scripts_data/mf_arthas/<project>/`, and selects a complete build for the next plugin load. Existing code boots immediately while update checks run in the background. The loader uses the host's HTTP and data-file APIs, not sockets or a custom executable.

File-size checks protect installation and reuse; the manifest records SHA-256 digests, but the runtime loader does not recompute those hashes. Publishing now checks full source SHA-256 values. If GitHub's commit API is unavailable, the existing loader falls back to the branch name, so commit pinning is unavailable in that fallback. These are observed existing behaviors, not claims of cryptographic runtime verification.

## MasterArthasNav startup and ownership

`header.lua` supplies metadata and posts a boot message to the configured local companion. `main.lua` increments a generation number and guards the upstream callbacks so previous callbacks become inert after F6. It temporarily redirects the upstream hard-coded localhost URL to `anav/config.lua`'s `base_url`, loads the preserved upstream runtime, restores host functions, and adopts the new exported client.

`anav/export.lua` republishes the same bundle through `_G.AmeisenNav` and `_G.ArthasNav`; older tables registered by this library can be replaced, while foreign plugin-owned tables are left alone with a warning. `anav/bootstrap.lua` signals the tray companion with bounded periodic start/stop request files for BG Player, Auto Leveler, Bloodcrypt Delver and Master Farmer.

## Movement pipeline

Consumer → bootstrap/heartbeat → `ArthasNavEnhancements.get_client(owner, contract)` → compatibility/safety/readiness gate → bounded route queue → base path query → path validation/confidence/hazard checks → base path follower → independently verified arrival → consumer callback.

`enhancements.lua` coordinates one active owner, leases, priorities, preemption, moving objectives, avoidance zones, recorded routes, transport transitions and bounded recovery. It keeps request epochs/serials so stale responses cannot complete newer movement. Client replacement invalidates the old owner/proxies. Ordinary requests and recorded paths have deliberately different restart rules.

`routes.lua` bounds the queue, ages lower-priority requests, caps dispatch per update window, retires lost requests and rejects late callbacks. Path inspection validates finite coordinates and waypoint counts, checks unsafe drops and final-goal gaps, scores confidence, and subdivides segments while retaining original navmesh corners.

`reliability.lua` polls the local bridge's readiness endpoint with a bounded in-flight count and request/context generation. It verifies protocol 3, `engine_api=antcp1832`, map schema 1, engine availability and map/tile readiness. It also owns safety holds, failed-destination cooldowns, route scoring and support reports.

`contracts.lua` requires horizontal/vertical proximity and any requested instance/UI-map/objective evidence before success. `travel_policy.lua` chooses among travel candidates and requires positive transition evidence. `advanced.lua`, `flight_recorder.lua` and the replay helpers retain bounded measurements/history for loop detection, recovery verification and support diagnostics.

## Bridge and geometry

`config.lua` overrides only the companion base URL; other defaults come from the preserved upstream config. `height_fallback.lua` adapts the server's single-height `ok <z>` response when the older client reports an unexpected HTTP 200. `coords.lua`, `pathcheck.lua`, `horizon.lua`, avoidance, following, transport and profile modules supplement the underlying client. The companion/engine/installer binaries are separate; this repo does not contain their implementation.

Several upstream modules, including the runtime, client and base UI, are obfuscated. Their boundaries, dependencies and exposed behavior can be studied and probed with a mocked host, but a line-by-line claim about their hidden implementation would be unwarranted. The additive/plain modules are the primary maintenance points.

## GUI and integrations

Command Center v3 uses a native Sylvanas window with embedded tab art and translucent geometry. The tabs are Command, Combat, Route, Safety, Logs, Metrics and Setup. GUI actions are queued out of drawing and executed on update. Status refresh is throttled. `combat_hub.lua` uses numeric class/spec identities and converts spec indices where necessary, then adapts the relevant installed class module's persistent controls and supported hotkey API. Unsupported plugins/specs receive explicit messages; Holy/Ret delegation is not equivalent to a complete central toggle registry.

The repository's BG Player and Auto Leveler consume the exported navigation services. The class suites provide their own engines/settings and are surfaced through adapters; MasterArthasNav does not replace those combat engines. Shared localization now sits around presentation and verified identity lookups, with the existing loading and navigation contracts preserved.
