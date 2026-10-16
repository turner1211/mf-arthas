-- Route overlay ported from the user's Ret Paladin 12.1.
-- Uses conservative NPC-composition matching and a 250-yard live-object scan.
local Settings = require("prot_settings")
local DUNGEON_ROUTE_GUIDES = require("prot_route_data")
local ROUTE_PACKS = require("prot_route_packs")
local Intelligence = require("prot_intelligence")
local Host = require("prot_host")
local Dungeon = require("prot_dungeon")
local vec3 = require("common/geometry/vector_3")
local vec2 = require("common/geometry/vector_2")
local colors = require("common/color")
local green = colors.green(255)
local route_map_color = colors.yellow(255)
local world_route_color = type(colors.new)=="function" and colors.new(244,190,55,48) or colors.yellow(80)
local tank_anchor_color = type(colors.new)=="function" and colors.new(244,210,90,58) or colors.yellow(90)
local recovery_color = type(colors.new)=="function" and colors.new(255,92,74,76) or colors.yellow(110)
local function make_route_map_vec2(x, y) return vec2.new(x, y) end
local M = {}
local PACK_CLUSTER_RADIUS = 18
local PACK_CLUSTER_HEIGHT = 8
local MIN_MATCH_SCORE = 0.50
local MIN_MATCH_PRECISION = 0.50
local MIN_MATCH_RECALL = 0.34
local function normalize_route_name(value)
    return string.lower(value or ""):gsub("[^%w]", "")
end

local function read_core_string(getter)
    local ok, value = pcall(getter)
    if ok and type(value) == "string" then return value end
    return ""
end

local function get_current_route_guide(instance_name, challenge_map_id)
    if challenge_map_id then
        for _, guide in ipairs(DUNGEON_ROUTE_GUIDES) do
            if guide.challenge_id == challenge_map_id then return guide end
        end
    end
    local normalized = normalize_route_name(instance_name)
    if normalized == "" then return nil end
    for _, guide in ipairs(DUNGEON_ROUTE_GUIDES) do
        for _, alias in ipairs(guide.aliases) do
            local normalized_alias = normalize_route_name(alias)
            if normalized_alias ~= "" and string.find(normalized, normalized_alias, 1, true) then
                return guide
            end
        end
    end
    return nil
end

local function get_dungeon_status()
    local instance_type = string.lower(read_core_string(core.get_instance_type))
    local instance_name = read_core_string(core.get_instance_name)
    local difficulty = read_core_string(core.get_difficulty_name)
    local challenge_map_id = nil
    local map_id=tonumber(Host.static(core and core.world,"get_active_challenge_map_id"))
    if map_id and map_id>0 then challenge_map_id=map_id end

    local inside_dungeon = instance_type == "party" or challenge_map_id ~= nil
    if not inside_dungeon then
        return "Dungeon check: OUTSIDE a dungeon", nil, false, challenge_map_id, instance_name
    end

    local status = "Dungeon check: INSIDE a dungeon"
    if instance_name ~= "" then status = status .. " — " .. instance_name end
    if challenge_map_id then
        status = status .. " (Mythic+ active)"
    elseif difficulty ~= "" then
        status = status .. " (" .. difficulty .. ")"
    end
    return status, get_current_route_guide(instance_name, challenge_map_id), true, challenge_map_id, instance_name
end

local route_guide_state = {
    message = "Off",
    route_name = nil,
    pull_index = 0,
    pull_count = 0,
    completed_forces = 0,
    partial_forces = 0,
    planned_forces = 0,
    required_forces = 0,
    planned_enemies = 0,
    pull_forces = 0,
    failure_count = 0,
    suggestion = nil,
    risk = "Unknown",
    distance = nil,
    off_route_enemies = 0,
    data_warning = nil,
    key_level = 0,
    force_percent = 0,
    split_index = nil,
    split_count = nil,
    forces_remaining = 0,
    projected_overcap = 0,
    match_confidence = 0,
    decision = "WAIT",
    stale_pack = false,
    active_pull_engaged = false,
    off_route_forces = 0,
    endgame_optimized = false,
    endgame_plan_pulls = 0,
    endgame_plan_forces = 0,
    defensive_ready = nil,
    far_members = 0,
    dead_members = 0,
    offline_members = 0,
    healer_busy = false,
    injured_members = 0,
    critical_members = 0,
    healer_recovering = false,
    vertical_delta = 0,
    transition_required = false,
    location_pull = 0,
    location_confidence = 0,
    location_status = "Searching",
    tank_anchor = nil,
    targets = {},
    recovery_targets = {},
    pull_centers = {},
}

function M.choose_pull_decision(next_pack,forces_remaining,readiness,healer_wait,
    off_route,active_pull_engaged,transition_required,split_index,
    defensive_available,risk,stale_pack)
    if off_route>0 then return "RECOVER" end
    if not next_pack then return forces_remaining<=0 and "DONE" or "SEARCH" end
    if active_pull_engaged then return "FIGHT" end
    if not readiness.ready or healer_wait then return "WAIT" end
    if transition_required then return "TRANSITION" end
    if split_index then return "SPLIT" end
    if defensive_available==false and risk=="Severe" then return "WAIT" end
    if stale_pack then return "VERIFY" end
    return "READY"
end

-- A visible NPC's GUID remains assigned to its pull until the dungeon changes.
-- Composition alone cannot distinguish repeated packs or a partially dead pack.
local progress = { identity = nil, members = {}, completed = {}, required_seen = {},
    skipped_until = {}, manual_skipped = {}, failures = {}, off_route_members = {},
    healer_wait = false, location_cursor=1, location_candidate=0, location_since=0,
    committed_pull=0,commit_until=0,recovery_until=0,
    recovery_guid=nil,recovery_commit_until=0 }
local next_route_guide_refresh = 0
local smoothed_centers = {}
local visible_pull_index, visible_pull_since = 0, 0
local function validate_guide(guide, pack_info)
    if not guide or not guide.pulls or not guide.pull_forces or not guide.npc_forces then
        return "route data incomplete"
    end
    if not guide.challenge_id or guide.challenge_id <= 0 then return "challenge ID missing" end
    if not guide.required_forces or guide.required_forces <= 0 then return "required forces missing" end
    if not pack_info or not pack_info.pulls then return "physical pack data missing" end
    if pack_info.challenge_id ~= guide.challenge_id then return "pack challenge ID mismatch" end
    if pack_info.required_forces ~= guide.required_forces then return "pack required forces mismatch" end
    if type(pack_info.mapping_version) ~= "number" or pack_info.mapping_version <= 0 then
        return "pack mapping version missing"
    end
    if #guide.pulls ~= #guide.pull_forces then return "pull/force count mismatch" end
    if #pack_info.pulls ~= #guide.pulls then return "physical pack pull count mismatch" end
    local calculated = 0
    for index, pull in ipairs(guide.pulls) do
        local force = 0
        for _, npc_id in ipairs(pull) do
            if guide.npc_forces[npc_id] == nil then return "missing NPC " .. tostring(npc_id) end
            force = force + guide.npc_forces[npc_id]
        end
        if force ~= guide.pull_forces[index] then return "force mismatch at pull " .. tostring(index) end
        calculated = calculated + force
    end
    if calculated ~= guide.planned_forces then return "planned force mismatch" end
    if calculated < guide.required_forces then return "route does not meet required forces" end
    if pack_info.planned_forces ~= calculated then return "pack planned forces mismatch" end
    return nil
end
local function reset_progress(identity)
    progress.identity, progress.members, progress.completed = identity, {}, {}
    progress.required_seen, progress.skipped_until, progress.manual_skipped = {}, {}, {}
    progress.failures,progress.off_route_members = {},{}
    progress.healer_wait=false;progress.location_cursor=1
    progress.location_candidate,progress.location_since=0,0
    progress.committed_pull,progress.commit_until=0,0
    progress.recovery_until=0
    progress.recovery_guid,progress.recovery_commit_until=nil,0
    smoothed_centers = {}
    visible_pull_index, visible_pull_since = 0, 0
end
local function object_guid(object)
    if not object or type(object.get_guid) ~= "function" then return nil end
    local ok, value = pcall(object.get_guid, object)
    if ok and value then return tostring(value) end
end
local function refresh_progress(guide)
    local all_dead, observed, dead_counts = {}, {}, {}
    for _, member in pairs(progress.members) do
        -- Invalid/unloaded handles are unknown, never evidence of death.
        local ok, valid, dead = pcall(function()
            return member.object:is_valid(), member.object:is_dead()
        end)
        if ok and valid then member.dead = dead == true end
        local pull = member.pull_index
        observed[pull] = true
        dead_counts[pull] = dead_counts[pull] or {}
        if member.dead then
            dead_counts[pull][member.npc_id] = (dead_counts[pull][member.npc_id] or 0) + 1
        end
        if all_dead[pull] == nil then all_dead[pull] = true end
        if not member.dead then all_dead[pull] = false end
    end
    for pull in pairs(observed) do
        local complete = all_dead[pull] == true
        local wanted = {}
        for _, npc_id in ipairs(guide.pulls[pull] or {}) do wanted[npc_id] = (wanted[npc_id] or 0) + 1 end
        for npc_id, amount in pairs(wanted) do
            if ((dead_counts[pull] or {})[npc_id] or 0) < amount then complete = false; break end
        end
        progress.completed[pull] = complete or nil
    end
end

local function clear_route_guide(message)
    route_guide_state.message = message
    route_guide_state.route_name = nil
    route_guide_state.pull_index = 0
    route_guide_state.pull_count = 0
    route_guide_state.completed_forces = 0
    route_guide_state.partial_forces = 0
    route_guide_state.planned_forces = 0
    route_guide_state.required_forces = 0
    route_guide_state.planned_enemies = 0
    route_guide_state.pull_forces = 0
    route_guide_state.failure_count = 0
    route_guide_state.suggestion = nil
    route_guide_state.risk = "Unknown"
    route_guide_state.distance = nil
    route_guide_state.off_route_enemies = 0
    route_guide_state.data_warning = nil
    route_guide_state.key_level = 0
    route_guide_state.force_percent = 0
    route_guide_state.split_index = nil
    route_guide_state.split_count = nil
    route_guide_state.forces_remaining = 0
    route_guide_state.projected_overcap = 0
    route_guide_state.match_confidence = 0
    route_guide_state.decision = "WAIT"
    route_guide_state.stale_pack = false
    route_guide_state.active_pull_engaged = false
    route_guide_state.off_route_forces = 0
    route_guide_state.endgame_optimized = false
    route_guide_state.endgame_plan_pulls = 0
    route_guide_state.endgame_plan_forces = 0
    route_guide_state.defensive_ready = nil
    route_guide_state.far_members = 0
    route_guide_state.dead_members = 0
    route_guide_state.offline_members = 0
    route_guide_state.healer_busy = false
    route_guide_state.injured_members = 0
    route_guide_state.critical_members = 0
    route_guide_state.healer_recovering = false
    route_guide_state.vertical_delta = 0
    route_guide_state.transition_required = false
    route_guide_state.targets = {}
    route_guide_state.recovery_targets = {}
    route_guide_state.pull_centers = {}
end

local function get_route_npc_set(guide)
    if guide.npc_set then return guide.npc_set end
    local npc_set = {}
    for _, pull in ipairs(guide.pulls) do
        for _, npc_id in ipairs(pull) do npc_set[npc_id] = true end
    end
    guide.npc_set = npc_set
    return npc_set
end

local function match_live_pack_to_route(cluster, guide, reserved, now)
    local live_counts, live_total = {}, #cluster.targets
    for _, target in ipairs(cluster.targets) do
        live_counts[target.npc_id] = (live_counts[target.npc_id] or 0) + 1
    end

    local best_pull, best_score = 0, 0
    for pull_index, pull in ipairs(guide.pulls) do
        local skipped = (progress.skipped_until[pull_index] or 0) > now
        if not progress.completed[pull_index] and not reserved[pull_index] and not skipped then
            local pack_info = ROUTE_PACKS[guide.name]
            local candidates = pack_info and pack_info.pulls[pull_index] or {pull}
            local score = 0
            for _, planned in ipairs(candidates) do
                local planned_counts, planned_total = {}, #planned
                for _, npc_id in ipairs(planned) do
                    planned_counts[npc_id] = (planned_counts[npc_id] or 0) + 1
                end
                local overlap = 0
                for npc_id, planned_count in pairs(planned_counts) do
                    overlap = overlap + math.min(planned_count, live_counts[npc_id] or 0)
                end
                local precision = live_total > 0 and overlap / live_total or 0
                local recall = planned_total > 0 and overlap / planned_total or 0
                local candidate_score = (precision + recall) > 0
                    and (2 * precision * recall) / (precision + recall) or 0
                if precision < MIN_MATCH_PRECISION or recall < MIN_MATCH_RECALL then candidate_score = 0 end
                score = math.max(score, candidate_score)
            end
            if score > best_score + 0.0001 then
                best_pull, best_score = pull_index, score
            end
        end
    end
    if best_score < MIN_MATCH_SCORE then return 0, best_score end
    return best_pull, best_score
end

local function compatible_with_assigned_pull(targets, pull)
    if #targets == 0 then return true end
    local available = {}
    for _, npc_id in ipairs(pull) do available[npc_id] = (available[npc_id] or 0) + 1 end
    local overlap = 0
    for _, target in ipairs(targets) do
        if (available[target.npc_id] or 0) > 0 then
            overlap = overlap + 1
            available[target.npc_id] = available[target.npc_id] - 1
        end
    end
    return overlap / #targets >= MIN_MATCH_PRECISION
end

local function first_pending_pull(guide)
    if not guide then return 0 end
    for index = 1, #guide.pulls do
        if not progress.completed[index] and not progress.manual_skipped[index] then return index end
    end
    return #guide.pulls + 1
end

Settings.actions = Settings.actions or {}
Settings.actions.next_route_pull = function()
    local _, guide = get_dungeon_status()
    local index = route_guide_state.pull_index > 0 and route_guide_state.pull_index or first_pending_pull(guide)
    if guide and index >= 1 and index <= #guide.pulls then
        progress.manual_skipped[index] = true
        progress.location_cursor=math.max(progress.location_cursor or 1,index+1)
        for guid, member in pairs(progress.members) do
            if member.pull_index == index then progress.members[guid] = nil end
        end
        next_route_guide_refresh = 0
    end
end
Settings.actions.previous_route_pull = function()
    local latest = 0
    for index in pairs(progress.manual_skipped) do latest = math.max(latest, index) end
    if latest > 0 then
        progress.manual_skipped[latest] = nil
        progress.location_cursor=math.min(progress.location_cursor or latest,latest)
        next_route_guide_refresh = 0
    end
end
Settings.actions.reset_route = function()
    reset_progress(progress.identity)
    next_route_guide_refresh = 0
end

local function add_live_target_to_cluster(target, clusters)
    local best_cluster, best_distance_squared = nil, PACK_CLUSTER_RADIUS * PACK_CLUSTER_RADIUS
    for _, cluster in ipairs(clusters) do
        local dx, dy = target.position.x - cluster.center_x, target.position.y - cluster.center_y
        local dz = target.position.z - cluster.center_z
        local distance_squared = dx * dx + dy * dy
        if math.abs(dz) <= PACK_CLUSTER_HEIGHT and distance_squared < best_distance_squared then
            best_cluster, best_distance_squared = cluster, distance_squared
        end
    end
    if not best_cluster then
        table.insert(clusters, {
            targets = { target }, center_x = target.position.x,
            center_y = target.position.y, center_z = target.position.z,
        })
        return
    end

    table.insert(best_cluster.targets, target)
    local sum_x, sum_y, sum_z = 0, 0, 0
    for _, member in ipairs(best_cluster.targets) do
        sum_x = sum_x + member.position.x
        sum_y = sum_y + member.position.y
        sum_z = sum_z + member.position.z
    end
    local count = #best_cluster.targets
    best_cluster.center_x, best_cluster.center_y, best_cluster.center_z =
        sum_x / count, sum_y / count, sum_z / count
end

local function select_physical_subpack(targets, subpacks)
    if not subpacks or #subpacks < 2 then return nil end
    local best, best_index, best_recall, best_distance = nil, nil, 0, math.huge
    for index, planned in ipairs(subpacks) do
        local need, selected = {}, {}
        for _, npc in ipairs(planned) do need[npc] = (need[npc] or 0) + 1 end
        local ordered = {}
        for _, target in ipairs(targets) do ordered[#ordered+1] = target end
        table.sort(ordered, function(a,b)
            return (a.distance or math.huge) < (b.distance or math.huge)
        end)
        for _, target in ipairs(ordered) do
            if (need[target.npc_id] or 0) > 0 then
                selected[#selected+1] = target
                need[target.npc_id] = need[target.npc_id] - 1
            end
        end
        local recall = #planned > 0 and #selected / #planned or 0
        local distance = selected[1] and (selected[1].distance or math.huge) or math.huge
        if recall > best_recall or (recall == best_recall and distance < best_distance) then
            best, best_index, best_recall, best_distance = selected, index, recall, distance
        end
    end
    if best_recall < 0.50 then return nil end
    return best, best_index, #subpacks
end

local function pack_confidence(targets, planned)
    if not targets or not planned or #targets==0 or #planned==0 then return 0 end
    local live,wanted={},{}
    for _,target in ipairs(targets) do live[target.npc_id]=(live[target.npc_id] or 0)+1 end
    for _,npc in ipairs(planned) do wanted[npc]=(wanted[npc] or 0)+1 end
    local overlap=0
    for npc,count in pairs(wanted) do overlap=overlap+math.min(count,live[npc] or 0) end
    local precision=overlap/#targets
    local recall=overlap/#planned
    return (precision+recall)>0 and (2*precision*recall)/(precision+recall) or 0
end

local function remaining_pull_forces(guide, pull_index)
    local remaining=(guide.pull_forces or {})[pull_index] or 0
    for _,member in pairs(progress.members) do
        if member.pull_index==pull_index and member.dead then
            remaining=remaining-((guide.npc_forces or {})[member.npc_id] or 0)
        end
    end
    return math.max(0,remaining)
end

-- Search the visible pending pulls for the smallest force overcount. The
-- candidate count is capped so this remains cheap even if a client exposes an
-- unusually large part of a dungeon at once.
local function choose_endgame_plan(packs, remaining, guide)
    local candidates={}
    for index,pack in ipairs(packs or {}) do
        if index>12 then break end
        candidates[#candidates+1]={pack=pack,
            force=type(pack.remaining_force)=="number" and pack.remaining_force
                or ((guide.pull_forces or {})[pack.pull_index] or 0)}
    end
    local states={{total=0,packs={}}}
    for _,candidate in ipairs(candidates) do
        local additions={}
        for _,state in ipairs(states) do
            local selected={}
            for i,value in ipairs(state.packs) do selected[i]=value end
            selected[#selected+1]=candidate.pack
            additions[#additions+1]={total=state.total+candidate.force,packs=selected}
        end
        for _,state in ipairs(additions) do states[#states+1]=state end
    end
    local best=nil
    for _,state in ipairs(states) do
        if #state.packs>0 and state.total>=remaining then
            local over=state.total-remaining
            local best_over=best and best.total-remaining or math.huge
            if not best or over<best_over
                or (over==best_over and #state.packs<#best.packs) then best=state end
        end
    end
    return best and best.packs or nil,best and best.total or 0
end

local function update_route_guide()
    local now = core.time()
    if now < next_route_guide_refresh then return end
    next_route_guide_refresh = now + 0.35

    local _, route_guide, inside_dungeon, challenge_id, instance_name = get_dungeon_status()
    local instance_id = read_core_string(function() return tostring(core.get_instance_id()) end)
    local identity = inside_dungeon and ("instance:" .. instance_id .. ":"
        .. (challenge_id and ("challenge:" .. tostring(challenge_id))
            or normalize_route_name(instance_name))) or nil
    if identity ~= progress.identity then reset_progress(identity) end
    if not Settings.on("route_map") then clear_route_guide("Off"); return end
    if Dungeon.is_delve_like() then
            local mode=Dungeon.is_labyrinth() and "Labyrinth mode" or "Delve mode"
            clear_route_guide(mode.." • companion-aware combat • M+ route paused")
            return
    end
    if not inside_dungeon then clear_route_guide("Enter a supported dungeon"); return end
    if not route_guide then
        clear_route_guide("No built-in route for " .. (instance_name ~= "" and instance_name or "unknown dungeon"))
        return
    end

    local player = Host.manager("get_local_player")
    if not player or not player.is_valid or not player:is_valid() then
        clear_route_guide("Waiting for the local player")
        return
    end

    local npc_set = get_route_npc_set(route_guide)
    local live_targets = {}
    local objects = Host.manager("get_all_objects")
    if type(objects) ~= "table" then objects = {} end
    for _, object in pairs(objects) do
        if object and object.is_valid and object.get_npc_id then
            local valid_ok, valid = pcall(object.is_valid, object)
            if valid_ok and valid then
                local key = object_guid(object)
                if key and progress.members[key] then progress.members[key].object = object end
                local npc_ok, npc_id = pcall(object.get_npc_id, object)
                if npc_ok and npc_set[npc_id] then
                    local dead_ok, dead = pcall(object.is_dead, object)
                    local distance_ok, distance = pcall(function()
                        local a, b = player:get_position(), object:get_position()
                        return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
                    end)
                    local hostile_ok, hostile = pcall(player.can_attack, player, object)
                    if (dead_ok and not dead) and distance_ok and type(distance) == "number"
                        and distance <= 250 and (hostile_ok and hostile) then
                        local position_ok, position = pcall(object.get_position, object)
                        if position_ok and position and type(position.x) == "number"
                            and type(position.y) == "number" and type(position.z) == "number" then
                            table.insert(live_targets, {
                                object = object, npc_id = npc_id,
                                position = position, distance = distance, guid = key,
                            })
                        end
                    end
                end
            end
        end
    end
    refresh_progress(route_guide)
    table.sort(live_targets, function(left, right) return left.distance < right.distance end)

    local clusters = {}
    for _, target in ipairs(live_targets) do add_live_target_to_cluster(target, clusters) end
    local best_cluster_by_pull, buckets, reserved = {}, {}, {}
    for pull_index in pairs(progress.manual_skipped) do reserved[pull_index] = true end
    for pull_index, until_time in pairs(progress.skipped_until) do
        if until_time > now then reserved[pull_index] = true else progress.skipped_until[pull_index] = nil end
    end
    -- Reserve even unloaded living assignments so another identical pack
    -- cannot steal their pull number when the player moves out of scan range.
    for _, member in pairs(progress.members) do reserved[member.pull_index] = true end
    local function assign_target(target, pull_index)
        if target.guid then
            progress.off_route_members[target.guid]=nil
            progress.members[target.guid] = {
                object = target.object, pull_index = pull_index, npc_id = target.npc_id, dead = false,
            }
        end
        progress.completed[pull_index] = nil
        reserved[pull_index] = true
        buckets[pull_index] = buckets[pull_index] or {}
        table.insert(buckets[pull_index], target)
    end
    -- Existing GUID assignments win before any new composition matching.
    for _, target in ipairs(live_targets) do
        local member = target.guid and progress.members[target.guid]
        if member then assign_target(target, member.pull_index) end
    end
    for _, cluster in ipairs(clusters) do
        local unknown, known_pull, mixed = {}, nil, false
        for _, target in ipairs(cluster.targets) do
            local member = target.guid and progress.members[target.guid]
            if member then
                if known_pull and known_pull ~= member.pull_index then mixed = true end
                known_pull = known_pull or member.pull_index
            else table.insert(unknown, target) end
        end
        local pull_index = 0
        if #unknown > 0 then
            if known_pull and not mixed and compatible_with_assigned_pull(unknown, route_guide.pulls[known_pull]) then
                pull_index = known_pull
            else pull_index = match_live_pack_to_route({targets = unknown}, route_guide, reserved, now) end
        end
        if pull_index > 0 then
            local nearest = math.huge
            for _, target in ipairs(unknown) do nearest = math.min(nearest, target.distance or math.huge) end
            if nearest <= 35 then
                for earlier = 1, pull_index - 1 do
                    if not progress.completed[earlier] and not reserved[earlier] then
                        progress.skipped_until[earlier] = now + 45
                        reserved[earlier] = true
                    end
                end
            end
            for _, target in ipairs(unknown) do assign_target(target, pull_index) end
        end
    end
    for pull_index, targets in pairs(buckets) do
        local distance = math.huge
        for _, target in ipairs(targets) do distance = math.min(distance, target.distance) end
        local sum_x, sum_y, sum_z = 0, 0, 0
        for _, target in ipairs(targets) do
            sum_x = sum_x + target.position.x
            sum_y = sum_y + target.position.y
            sum_z = sum_z + target.position.z
        end
        local raw_x, raw_y, raw_z = sum_x / #targets, sum_y / #targets, sum_z / #targets
        local old = smoothed_centers[pull_index]
        if old then
            local dx, dy, dz = raw_x-old.x, raw_y-old.y, raw_z-old.z
            if dx*dx + dy*dy + dz*dz <= 20*20 then
                raw_x, raw_y, raw_z = old.x*0.65+raw_x*0.35,
                    old.y*0.65+raw_y*0.35, old.z*0.65+raw_z*0.35
            end
        end
        local center = vec3.new(raw_x, raw_y, raw_z)
        smoothed_centers[pull_index] = center
        local radius = 0
        for _, target in ipairs(targets) do
            local dx, dy = target.position.x - center.x, target.position.y - center.y
            radius = math.max(radius, math.sqrt(dx * dx + dy * dy))
        end
        best_cluster_by_pull[pull_index] = {
            pull_index = pull_index, center = center,
            radius = math.min(20, math.max(6, radius + 4)),
            targets = targets, distance = distance,
            remaining_force = remaining_pull_forces(route_guide,pull_index),
        }
    end

    local pull_centers = {}
    for pull_index = 1, #route_guide.pulls do
        if best_cluster_by_pull[pull_index] then
            table.insert(pull_centers, best_cluster_by_pull[pull_index])
        end
    end
    -- Infer the player's route segment from the nearest confidently identified
    -- live pack. A short confirmation prevents patrols and briefly loaded packs
    -- from jumping the route cursor. The cursor only advances automatically;
    -- manual Previous/Reset remain the explicit ways to go back.
    local location_pack,location_score=nil,0
    for _,pack in ipairs(pull_centers) do
        local score=pack_confidence(pack.targets,route_guide.pulls[pack.pull_index])
        if pack.distance<=55 and score>=0.70 and (not location_pack or pack.distance<location_pack.distance) then
            location_pack,location_score=pack,score
        end
    end
    if location_pack and location_pack.pull_index>=progress.location_cursor then
        if progress.location_candidate~=location_pack.pull_index then
            progress.location_candidate,progress.location_since=location_pack.pull_index,now
        elseif now-progress.location_since>=0.7 or location_pack.pull_index<=progress.location_cursor+1 then
            progress.location_cursor=location_pack.pull_index
        end
    else progress.location_candidate,progress.location_since=0,now end
    local next_pack
    for _,pack in ipairs(pull_centers) do
        if pack.pull_index>=progress.location_cursor and not progress.completed[pack.pull_index]
            and not progress.manual_skipped[pack.pull_index] then next_pack=pack;break end
    end
    if not next_pack and progress.location_cursor<=1 then next_pack=pull_centers[1] end
    -- Keep a verified pull selected briefly while patrols move or objects stream
    -- in and out. Release immediately when completed or manually skipped.
    if progress.committed_pull>0 and now<progress.commit_until
        and not progress.completed[progress.committed_pull]
        and not progress.manual_skipped[progress.committed_pull]
        and (not next_pack or next_pack.pull_index>=progress.committed_pull) then
        for _,pack in ipairs(pull_centers) do
            if pack.pull_index==progress.committed_pull then next_pack=pack;break end
        end
    end
    if next_pack then
        if progress.committed_pull~=next_pack.pull_index then
            progress.committed_pull=next_pack.pull_index
            progress.commit_until=now+3
        end
    elseif now>=progress.commit_until then progress.committed_pull=0 end
    route_guide_state.route_name = route_guide.name
    route_guide_state.pull_count = #route_guide.pulls
    local completed_forces, partial_forces = 0, 0
    for pull_index, done in pairs(progress.completed) do
        if done then completed_forces = completed_forces + (route_guide.pull_forces[pull_index] or 0) end
    end
    -- Credit confirmed deaths inside an unfinished pack without allowing that
    -- partial observation to mark the pack complete. This keeps the live forces
    -- display and endgame choice aligned with what has actually died.
    for _,member in pairs(progress.members) do
        if member.dead and not progress.completed[member.pull_index] then
            partial_forces=partial_forces+(route_guide.npc_forces[member.npc_id] or 0)
        end
    end
    completed_forces=completed_forces+partial_forces
    route_guide_state.partial_forces=partial_forces
    local off_route_forces=0
    for guid,member in pairs(progress.off_route_members) do
        if progress.members[guid] then progress.off_route_members[guid]=nil
        else
            local ok,valid,dead=pcall(function()
                return member.object:is_valid(),member.object:is_dead()
            end)
            if ok and valid and dead then member.credited=true end
            if member.credited then off_route_forces=off_route_forces
                +(route_guide.npc_forces[member.npc_id] or 0) end
        end
    end
    completed_forces=completed_forces+off_route_forces
    route_guide_state.off_route_forces=off_route_forces
    route_guide_state.endgame_optimized=false
    local required=route_guide.required_forces or 0
    route_guide_state.endgame_plan_pulls=0
    route_guide_state.endgame_plan_forces=0
    if next_pack and required>0 and completed_forces/required>=0.80 then
        local remaining=math.max(0,required-completed_forces)
        local plan,total=choose_endgame_plan(pull_centers,remaining,route_guide)
        if plan and plan[1] then
            next_pack=plan[1]
            route_guide_state.endgame_optimized=true
            route_guide_state.endgame_plan_pulls=#plan
            route_guide_state.endgame_plan_forces=total
        end
    end
    if (route_guide.required_forces or 0) > 0
        and completed_forces >= route_guide.required_forces then next_pack = nil end
    route_guide_state.completed_forces = completed_forces
    route_guide_state.planned_forces = route_guide.planned_forces or 0
    route_guide_state.required_forces = route_guide.required_forces or 0
    route_guide_state.force_percent = route_guide_state.required_forces > 0
        and math.min(100, completed_forces * 100 / route_guide_state.required_forces) or 0
    route_guide_state.forces_remaining = math.max(0, route_guide_state.required_forces-completed_forces)
    route_guide_state.pull_index = next_pack and next_pack.pull_index or 0
    route_guide_state.location_pull=progress.location_cursor or 1
    route_guide_state.location_confidence=location_score
    route_guide_state.location_status=location_pack and
        ("Near pull "..tostring(location_pack.pull_index)) or "Searching visible packs"
    local active_index = route_guide_state.pull_index
    route_guide_state.planned_enemies = active_index > 0 and #(route_guide.pulls[active_index] or {}) or 0
    route_guide_state.pull_forces = active_index > 0 and remaining_pull_forces(route_guide,active_index) or 0
    route_guide_state.projected_overcap = active_index > 0 and math.max(0,
        completed_forces + route_guide_state.pull_forces - route_guide_state.required_forces) or 0
    route_guide_state.failure_count = active_index > 0 and (progress.failures[active_index] or 0) or 0
    route_guide_state.match_confidence = next_pack and pack_confidence(next_pack.targets,
        route_guide.pulls[active_index]) or 0
    if active_index>0 then
        if visible_pull_index~=active_index then
            visible_pull_index,visible_pull_since=active_index,now
        end
    else visible_pull_index,visible_pull_since=0,now end
    route_guide_state.stale_pack=active_index>0 and route_guide_state.match_confidence<0.70
        and now-visible_pull_since>=10
    local pack_info = ROUTE_PACKS[route_guide.name]
    local subpacks = pack_info and pack_info.pulls[active_index]
    route_guide_state.suggestion = route_guide_state.failure_count > 0 and subpacks and #subpacks > 1
        and ("After " .. tostring(route_guide_state.failure_count) .. " failure"
            .. (route_guide_state.failure_count == 1 and "" or "s") .. ": split into "
            .. tostring(#subpacks) .. " packs") or nil
    route_guide_state.targets = next_pack and next_pack.targets or {}
    route_guide_state.split_index, route_guide_state.split_count = nil, nil
    if route_guide_state.failure_count > 0 and next_pack then
        local subset, split_index, split_count = select_physical_subpack(next_pack.targets, subpacks)
        if subset then
            route_guide_state.targets = subset
            route_guide_state.split_index, route_guide_state.split_count = split_index, split_count
            local x,y,z=0,0,0
            for _,target in ipairs(subset) do x=x+target.position.x;y=y+target.position.y;z=z+target.position.z end
            if #subset>0 then next_pack.center=vec3.new(x/#subset,y/#subset,z/#subset) end
        end
    end
    route_guide_state.pull_centers = pull_centers
    Intelligence.set_context(tostring(challenge_id or route_guide.name))
    local healer_mana = Intelligence.healer_mana()
    route_guide_state.healer_mana = healer_mana
    if healer_mana and healer_mana<20 then progress.healer_wait=true
    elseif not healer_mana or healer_mana>=30 then progress.healer_wait=false end
    route_guide_state.healer_recovering=progress.healer_wait
    local key_level = 0
    local info=Host.static(core and core.world,"get_active_keystone_info")
    if type(info)=="table" then key_level=tonumber(info.level) or 0 end
    route_guide_state.key_level = key_level
    local readiness = Intelligence.group_readiness()
    route_guide_state.group_ready = readiness.ready
    route_guide_state.far_members = readiness.far or 0
    route_guide_state.dead_members = readiness.dead or 0
    route_guide_state.offline_members = readiness.offline or 0
    route_guide_state.healer_busy = readiness.healer_busy==true
    route_guide_state.injured_members = readiness.injured or 0
    route_guide_state.critical_members = readiness.critical or 0
    local defensive=Intelligence.defensive_readiness and Intelligence.defensive_readiness()
        or {available=nil}
    route_guide_state.defensive_ready=defensive.available
    local player_position = player:get_position()
    if next_pack and player_position then
        local dx,dy,dz = next_pack.center.x-player_position.x,
            next_pack.center.y-player_position.y,next_pack.center.z-player_position.z
        route_guide_state.distance = math.sqrt(dx*dx+dy*dy+dz*dz)
        route_guide_state.vertical_delta=dz
        route_guide_state.transition_required=math.abs(dz)>12
        local horizontal=math.sqrt(dx*dx+dy*dy)
        local stand_off=math.min(math.max((next_pack.radius or 6)+2,7),12)
        if horizontal>stand_off+0.5 then
            local scale=(horizontal-stand_off)/horizontal
            route_guide_state.tank_anchor=vec3.new(player_position.x+dx*scale,
                player_position.y+dy*scale,player_position.z+dz*scale)
        else route_guide_state.tank_anchor=nil end
    else
        route_guide_state.distance = nil
        route_guide_state.vertical_delta=0
        route_guide_state.transition_required=false
        route_guide_state.tank_anchor=nil
    end
    local assigned = {}
    for _, target_info in ipairs(live_targets) do if target_info.guid and progress.members[target_info.guid] then assigned[target_info.guid]=true end end
    local off_route,recovery_targets = 0,{}
    for _, target_info in ipairs(live_targets) do
        if target_info.guid and not assigned[target_info.guid] then
            local victim_ok, victim = pcall(target_info.object.get_target, target_info.object)
            local threat_ok, threat = pcall(player.get_threat_situation, player, target_info.object)
            if (victim_ok and victim) or (threat_ok and type(threat)=="table"
                and ((tonumber(threat.status) or 0)>0 or threat.is_tanking==true)) then
                off_route=off_route+1
                local role=nil
                if victim then
                    local role_ok,role_value=pcall(function()
                        if type(victim.get_role)=="function" then return victim:get_role() end
                        if type(victim.get_assigned_role)=="function" then return victim:get_assigned_role() end
                    end)
                    if role_ok then role=role_value end
                end
                local cast_ok,casting=pcall(function()
                    return (type(target_info.object.is_casting_spell)=="function"
                        and target_info.object:is_casting_spell()) or
                        (type(target_info.object.is_channelling_spell)=="function"
                        and target_info.object:is_channelling_spell())
                end)
                casting=cast_ok and casting==true
                local reachable=true
                if core.graphics and type(core.graphics.is_line_of_sight)=="function" then
                    reachable=Host.static(core.graphics,"is_line_of_sight",player,target_info.object)~=false
                end
                target_info.reachable=reachable
                target_info.recovery_priority=(string.upper(tostring(role or ""))=="HEALER" and 100 or 0)
                    +(casting and 35 or 0)-(target_info.distance or 0)*0.1-(reachable and 0 or 1000)
                recovery_targets[#recovery_targets+1]=target_info
            end
        end
    end
    route_guide_state.off_route_enemies = off_route
    if off_route>0 then
        progress.recovery_until=now+0.8
        table.sort(recovery_targets,function(a,b)
            if a.recovery_priority~=b.recovery_priority then return a.recovery_priority>b.recovery_priority end
            return (a.distance or math.huge)<(b.distance or math.huge)
        end)
        local committed_index=nil
        for index,target in ipairs(recovery_targets) do
            if target.guid==progress.recovery_guid then committed_index=index;break end
        end
        local top,committed=recovery_targets[1],committed_index and recovery_targets[committed_index]
        if committed and now<progress.recovery_commit_until and committed.reachable
            and top.recovery_priority<=committed.recovery_priority+40 then
            table.remove(recovery_targets,committed_index);table.insert(recovery_targets,1,committed)
        elseif top then
            progress.recovery_guid=top.guid;progress.recovery_commit_until=now+0.75
        end
        route_guide_state.recovery_targets=recovery_targets
    elseif now>=progress.recovery_until then
        route_guide_state.recovery_targets={}
        progress.recovery_guid,progress.recovery_commit_until=nil,0
    end
    local recovery_active=off_route>0 or now<progress.recovery_until
    for _,target_info in ipairs(live_targets) do
        if target_info.guid and not assigned[target_info.guid] then
            local victim_ok,victim=pcall(target_info.object.get_target,target_info.object)
            local threat_ok,threat=pcall(player.get_threat_situation,player,target_info.object)
            if (victim_ok and victim) or (threat_ok and type(threat)=="table"
                and ((tonumber(threat.status) or 0)>0 or threat.is_tanking==true)) then
                progress.off_route_members[target_info.guid]={object=target_info.object,
                    npc_id=target_info.npc_id,credited=false}
            end
        end
    end
    local boss_pull = false
    for _, target_info in ipairs(route_guide_state.targets) do
        if target_info.object.is_boss then
            local ok, boss = pcall(target_info.object.is_boss, target_info.object)
            if ok and boss then boss_pull=true; break end
        end
    end
    local active_pull_engaged=false
    -- Split guidance narrows drawing targets, but combat detection must still
    -- cover every enemy assigned to the complete planned pull.
    local engagement_targets=next_pack and next_pack.targets or route_guide_state.targets
    for _,target_info in ipairs(engagement_targets) do
        local object=target_info.object
        local victim_ok,victim=pcall(object.get_target,object)
        local party_victim=victim==player
        if victim_ok and victim and victim~=player and type(victim.is_party_member)=="function" then
            local party_ok,is_party=pcall(victim.is_party_member,victim)
            party_victim=party_ok and is_party==true
        end
        local threat_ok,threat=pcall(player.get_threat_situation,player,object)
        if party_victim or (threat_ok and type(threat)=="table"
            and ((tonumber(threat.status) or 0)>0 or threat.is_tanking==true)) then
            active_pull_engaged=true;break
        end
    end
    route_guide_state.active_pull_engaged=active_pull_engaged
    local risk_score = (route_guide_state.planned_enemies >= 8 and 2 or route_guide_state.planned_enemies >= 5 and 1 or 0)
        + (route_guide_state.pull_forces >= 50 and 2 or route_guide_state.pull_forces >= 30 and 1 or 0)
        + (healer_mana and healer_mana < 30 and 2 or 0)
        + (route_guide_state.failure_count > 0 and 2 or 0)
        + (not readiness.ready and 3 or 0) + ((readiness.critical or 0)>0 and 2 or 0)
        + (readiness.healer_injured and 2 or 0) + (recovery_active and 1 or 0)
        + (defensive.available==false and 2 or 0)
        + (key_level >= 15 and 2 or key_level >= 10 and 1 or 0)
    route_guide_state.risk = boss_pull and "Boss" or risk_score >= 5 and "Severe"
        or risk_score >= 3 and "High" or risk_score >= 1 and "Moderate" or "Normal"
    local adaptive_split = next_pack and not route_guide_state.split_index
        and subpacks and #subpacks>1 and (route_guide_state.risk=="Severe"
            or (healer_mana and healer_mana<25)
            or defensive.available==false
            or (key_level>=15 and route_guide_state.planned_enemies>=5))
    if adaptive_split then
        local subset,split_index,split_count=select_physical_subpack(next_pack.targets,subpacks)
        if subset then
            route_guide_state.targets=subset
            route_guide_state.split_index,route_guide_state.split_count=split_index,split_count
            local x,y,z=0,0,0
            for _,target in ipairs(subset) do x=x+target.position.x;y=y+target.position.y;z=z+target.position.z end
            if #subset>0 then next_pack.center=vec3.new(x/#subset,y/#subset,z/#subset) end
            route_guide_state.distance=subset[1] and subset[1].distance or route_guide_state.distance
            route_guide_state.suggestion="Risk-based split: guide physical pack "
                ..tostring(split_index).."/"..tostring(split_count)
        end
    end
    route_guide_state.decision=M.choose_pull_decision(next_pack,
        route_guide_state.forces_remaining,readiness,progress.healer_wait,recovery_active and 1 or 0,
        active_pull_engaged,route_guide_state.transition_required,
        route_guide_state.split_index,defensive.available,route_guide_state.risk,
        route_guide_state.stale_pack)
    route_guide_state.data_warning = validate_guide(route_guide, pack_info)
    if not next_pack then
        route_guide_state.message = route_guide.name .. " • route loaded • forces "
            .. tostring(completed_forces) .. "/" .. tostring(route_guide.planned_forces or 0)
            .. " (need " .. tostring(route_guide.required_forces or 0) .. ")"
    else
        local expected = #route_guide.pulls[next_pack.pull_index]
        route_guide_state.message = "Next visible pack "
            .. tostring(next_pack.pull_index) .. "/" .. tostring(#route_guide.pulls)
            .. " • loaded " .. tostring(#next_pack.targets) .. "/" .. tostring(expected)
            .. " • forces " .. tostring(completed_forces) .. "/"
            .. tostring(route_guide.planned_forces or 0) .. " (need "
            .. tostring(route_guide.required_forces or 0) .. ")"
        route_guide_state.message = route_guide_state.message
            .. string.format(" • %.1f%% • match %.0f%% • %s", route_guide_state.force_percent,
                route_guide_state.match_confidence*100,route_guide_state.decision)
        if off_route_forces>0 then route_guide_state.message=route_guide_state.message
            .. " • off-route forces +"..tostring(off_route_forces) end
        if partial_forces>0 then route_guide_state.message=route_guide_state.message
            .. " • partial forces +"..tostring(partial_forces) end
        if route_guide_state.endgame_optimized then route_guide_state.message=route_guide_state.message
            .. " • least-overcount plan "..tostring(route_guide_state.endgame_plan_pulls)
            .. " pull(s)/"..tostring(route_guide_state.endgame_plan_forces).." forces" end
        if key_level > 0 then route_guide_state.message = route_guide_state.message
            .. " • +" .. tostring(key_level) end
        if route_guide_state.projected_overcap > 0 then
            route_guide_state.message = route_guide_state.message .. " • overcount +"
                .. tostring(route_guide_state.projected_overcap)
        else
            route_guide_state.message = route_guide_state.message .. " • need "
                .. tostring(route_guide_state.forces_remaining)
        end
        if healer_mana then route_guide_state.message = route_guide_state.message
            .. string.format(" • healer %.0f%%", healer_mana) end
        if progress.healer_wait then route_guide_state.message=route_guide_state.message
            .. " • healer recovering to 30%" end
        route_guide_state.message = route_guide_state.message .. " • " .. route_guide_state.risk
        if route_guide_state.distance then route_guide_state.message = route_guide_state.message
            .. string.format(" • %.0f yd", route_guide_state.distance) end
        route_guide_state.message=route_guide_state.message.." • location "
            ..tostring(route_guide_state.location_pull).."/"..tostring(route_guide_state.pull_count)
        if route_guide_state.transition_required then
            route_guide_state.message=route_guide_state.message..string.format(" • %s %.0f yd",
                route_guide_state.vertical_delta>0 and "UP" or "DOWN",
                math.abs(route_guide_state.vertical_delta))
        end
        if not readiness.ready then route_guide_state.message = route_guide_state.message .. " • group not ready" end
        if (readiness.dead or 0)>0 then route_guide_state.message=route_guide_state.message
            .. " • "..tostring(readiness.dead).." dead" end
        if (readiness.offline or 0)>0 then route_guide_state.message=route_guide_state.message
            .. " • "..tostring(readiness.offline).." offline" end
        if (readiness.far or 0)>0 then route_guide_state.message=route_guide_state.message
            .. " • "..tostring(readiness.far).." member(s) >60 yd" end
        if readiness.healer_busy then route_guide_state.message=route_guide_state.message
            .. " • healer casting" end
        if readiness.healer_injured then route_guide_state.message=route_guide_state.message
            .. " • healer injured" end
        if (readiness.critical or 0)>0 then route_guide_state.message=route_guide_state.message
            .. " • "..tostring(readiness.critical).." critical member(s)" end
        if defensive.available==false then route_guide_state.message=route_guide_state.message
            .. " • defensives unavailable" end
        if route_guide_state.stale_pack then route_guide_state.message=route_guide_state.message
            .. " • partial pack stale; verify floor/position" end
        if off_route > 0 then route_guide_state.message = route_guide_state.message
            .. " • " .. tostring(off_route) .. " off-route engaged" end
        if off_route==0 and recovery_active then route_guide_state.message=route_guide_state.message
            .. " • confirming threat recovery" end
        if route_guide_state.data_warning then route_guide_state.message = route_guide_state.message
            .. " • DATA: " .. route_guide_state.data_warning end
        if route_guide_state.suggestion then route_guide_state.message = route_guide_state.message
            .. " • " .. route_guide_state.suggestion end
        if route_guide_state.split_index then route_guide_state.message = route_guide_state.message
            .. " • guiding split " .. tostring(route_guide_state.split_index) .. "/"
            .. tostring(route_guide_state.split_count) end
    end
end

function M.get_state() return route_guide_state end
function M.choose_endgame_plan(packs,remaining,guide)
    return choose_endgame_plan(packs,remaining,guide)
end

function M.record_failure()
    local index = route_guide_state.pull_index
    if index and index > 0 then
        progress.failures[index] = (progress.failures[index] or 0) + 1
        next_route_guide_refresh = 0
    end
end

local function normalized_map_point(world_position)
    if not core.game_ui or not core.game_ui.world_pos_to_map_pos_normalized then return nil end
    local point = Host.static(core and core.game_ui,"world_pos_to_map_pos_normalized",world_position)
    if not point or type(point.x) ~= "number" or type(point.y) ~= "number"
        or point.x < 0 or point.x > 1 or point.y < 0 or point.y > 1 then return nil end
    return point
end

local function draw_route_overview(player_pos)
    if not route_guide_state.route_name then return end
    local screen_size = Host.static(core and core.graphics,"get_screen_size")
    if not screen_size or type(screen_size.x) ~= "number"
        or type(screen_size.y) ~= "number" or screen_size.x < 300 or screen_size.y < 250 then return end

    local panel_width, panel_height = 248, 286
    local panel_x, panel_y = screen_size.x - panel_width - 24, 90
    Host.static(core and core.graphics,"rect_2d",make_route_map_vec2(panel_x, panel_y), panel_width, panel_height, green, 2, 4)
    Host.static(core and core.graphics,"text_2d",route_guide_state.route_name,
        make_route_map_vec2(panel_x + 10, panel_y + 12), 13, green, false)
    Host.static(core and core.graphics,"text_2d",route_guide_state.message,
        make_route_map_vec2(panel_x + 10, panel_y + 32), 10, route_map_color, false)

    local points, player_point = {}, normalized_map_point(player_pos)
    if player_point then table.insert(points, { pull_index = 0, x = player_point.x, y = player_point.y, is_player = true }) end
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local point = normalized_map_point(pack.center)
        if point then table.insert(points, { pull_index = pack.pull_index, x = point.x, y = point.y }) end
    end
    if #route_guide_state.pull_centers == 0 then
        Host.static(core and core.graphics,"text_2d","Waiting for a live pack to load.",
            make_route_map_vec2(panel_x + 10, panel_y + 72), 10, green, false)
        return
    end

    if #points == 0 then
        Host.static(core and core.graphics,"text_2d","World markers active; map unavailable.",
            make_route_map_vec2(panel_x + 10, panel_y + 72), 10, green, false)
        return
    end
    local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge
    for _, point in ipairs(points) do
        min_x, max_x = math.min(min_x, point.x), math.max(max_x, point.x)
        min_y, max_y = math.min(min_y, point.y), math.max(max_y, point.y)
    end
    local content_x, content_y = panel_x + 16, panel_y + 60
    local content_width, content_height = panel_width - 32, panel_height - 78
    local span_x, span_y = math.max(0.0001, max_x - min_x), math.max(0.0001, max_y - min_y)
    local scale = math.min(content_width / span_x, content_height / span_y)
    local drawn_width, drawn_height = span_x * scale, span_y * scale
    local offset_x, offset_y = content_x + (content_width - drawn_width) / 2, content_y + (content_height - drawn_height) / 2
    local screen_points = {}
    for _, point in ipairs(points) do
        local screen_point = make_route_map_vec2(
            offset_x + (point.x - min_x) * scale, offset_y + (max_y - point.y) * scale)
        if point.is_player then Host.static(core and core.graphics,"circle_2d_filled",screen_point, 5, green)
        else screen_points[point.pull_index] = screen_point end
    end

    local player_screen_point = player_point and make_route_map_vec2(
        offset_x + (player_point.x - min_x) * scale, offset_y + (max_y - player_point.y) * scale) or nil
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local point = screen_points[pack.pull_index]
        if point then
            local active = pack.pull_index == route_guide_state.pull_index
            if active and player_screen_point then
                Host.static(core and core.graphics,"line_2d",player_screen_point, point, route_map_color, 2)
            end
            local color = active and route_map_color or green
            Host.static(core and core.graphics,"circle_2d_filled",point,active and 7 or 4,color)
            Host.static(core and core.graphics,"text_2d",tostring(pack.pull_index),
                make_route_map_vec2(point.x + 5, point.y - 5), 9, color, false)
        end
    end
end


local function render()
    -- A render-time toggle check hides markers immediately, even between ticks.
    if not Settings.on("route_map") or not route_guide_state.route_name then return end
    local _, guide, inside = get_dungeon_status()
    if not inside or not guide or guide.name ~= route_guide_state.route_name then return end
    local player = Host.manager("get_local_player")
    if not player or not player:is_valid() then return end
    local player_pos = player:get_position()
    if not player_pos then return end
    if route_guide_state.decision=="RECOVER" and route_guide_state.recovery_targets[1] then
        local recovery=route_guide_state.recovery_targets[1]
        Host.static(core and core.graphics,"line_3d",player_pos,recovery.position,recovery_color,3,0,false)
        Host.static(core and core.graphics,"text_3d","RECOVER THREAT",recovery.position,15,recovery_color,true)
        for _,target in ipairs(route_guide_state.recovery_targets) do
            Host.static(core and core.graphics,"circle_3d",target.position,1.6,recovery_color,2,0.08)
        end
    end
    -- Route status lives inside Vanguard. Rendering another 2D route panel
    -- would create an unwanted third GUI, so this callback draws only world guidance.
    local background_labels=0
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local is_next = pack.pull_index == route_guide_state.pull_index
        if Settings.on("draw_route_lines") and is_next and route_guide_state.decision~="RECOVER" and not route_guide_state.stale_pack
            and not route_guide_state.transition_required then
            -- NPC composition reveals the next pull, not a collision-safe navigation path.
            -- Drawing only to that pull avoids a misleading line through walls or later packs.
            local anchor=route_guide_state.tank_anchor or pack.center
            Host.static(core and core.graphics,"line_3d",player_pos,anchor,world_route_color,2,0,false)
            Host.static(core and core.graphics,"line_3d",anchor,pack.center,tank_anchor_color,2,0,false)
            Host.static(core and core.graphics,"circle_3d",anchor,1.8,tank_anchor_color,24,0.12)
            if type(core.graphics.text_3d)=="function" then
                Host.static(core and core.graphics,"text_3d","TANK PULL FROM HERE",anchor,14,tank_anchor_color,true)
            end
        end
        if Settings.on("draw_next_pack") and is_next then
            Host.static(core and core.graphics,"circle_3d",pack.center,pack.radius,world_route_color,2,0.08)
        end
        if Settings.on("draw_pull_labels") and (is_next or background_labels<6) then
            if not is_next then background_labels=background_labels+1 end
            local prefix=is_next and route_guide_state.transition_required
                and (route_guide_state.vertical_delta>0 and "UP " or "DOWN ")
                or is_next and route_guide_state.stale_pack and "VERIFY " or "Pull "
            Host.static(core and core.graphics,"text_3d",prefix..tostring(pack.pull_index),pack.center,
                is_next and 14 or 10, is_next and route_map_color or green, true)
        end
    end
    if Settings.on("draw_next_pack") then for _, target in ipairs(route_guide_state.targets) do
        -- Re-check cached members: no rings left around dead/despawned mobs.
        local ok, alive = pcall(function()
            return target.object:is_valid() and not target.object:is_dead()
        end)
        if ok and alive then
            local pos_ok, pos = pcall(target.object.get_position, target.object)
            if pos_ok and pos then Host.static(core and core.graphics,"circle_3d",pos,1.35,world_route_color,2,0.06) end
        end
    end end
end
local function safe_update()
    local ok = pcall(update_route_guide)
    if not ok then clear_route_guide("Route API unavailable") end
    Settings.route_status = route_guide_state.message
end
local function safe_render()
    local ok = pcall(render)
    if not ok then Settings.route_status = "Route drawing API unavailable" end
end
core.register_on_update_callback(safe_update)
core.register_on_render_callback(safe_render)
M.update, M.render, M.state, M.progress = safe_update, safe_render, route_guide_state, progress
return M
