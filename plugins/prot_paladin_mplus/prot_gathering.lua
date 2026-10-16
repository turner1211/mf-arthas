-- Fishing, looting and skinning behavior ported from the user's Ret Paladin 12.1.
local Settings = require("prot_settings")
local Aura = require("prot_aura")
local Host = require("prot_host")
local fish_helper = require("common/utility/fish_helper")
local simple_movement = require("common/utility/simple_movement")
local vec3 = require("common/geometry/vector_3")
local colors = require("common/color")
local M = {}
local HERB_LINE_COLOR = colors.green(255)
local MINING_LINE_COLOR = colors.yellow(255)
local NODE_DRAW_RANGE = 100
local MAX_NODE_LINES = 30
local node_draw_cache, next_node_draw_scan = {}, 0

local next_fishing_action, last_fishing_cast = 0, -math.huge
local next_looting_attempt, next_corpse_interaction = 0, 0
local recently_looted_corpses, pending_skinning_corpses = {}, {}
local next_skinning_attempt, next_skinning_target_attempt = 0, 0
local skinning_target_key, movement_owner = nil, nil
local skinning_busy = false
local next_gather_attempt, gather_target_key = 0, nil
local next_dismount_attempt = 0
local active_gather_key, active_gather_started = nil, 0
local gather_blacklist = {}
local harvested_nodes, skinned_corpses, caught_bobbers = {}, {}, {}
local pending_loot, loot_window_open = nil, false
local CORPSE_LOOT_RETRY_DELAY, CORPSE_SKIN_QUEUE_LIFETIME = 8, 20
local SKIN_INTERACT_DISTANCE = 3.5
local GATHER_ATTEMPT_TIMEOUT, GATHER_BLACKLIST_DURATION = 10, 60
local HARVEST_SUCCESS_COOLDOWN, LOOT_REQUEST_TIMEOUT = 60, 8

local function player_ready()
    local player=Host.manager("get_local_player")
    if not player or type(player.is_valid)~="function" then return nil end
    local valid_ok,valid=pcall(player.is_valid,player)
    if not valid_ok or valid~=true then return nil end
    if type(player.is_dead)=="function" then
        local dead_ok,dead=pcall(player.is_dead,player)
        if not dead_ok or dead==true then return nil end
    end
    return player
end
local function player_in_travel_form(player)
    for _, aura_id in ipairs({ 783, 1066, 33943, 40120, 210053 }) do
        if Aura.read(player, aura_id) then return true end
    end
    return false
end
local function objects()
    return Host.manager_table("get_all_objects")
end
local function position(object)
    local ok, value = pcall(object.get_position, object)
    if ok and value and type(value.x) == "number" and type(value.y) == "number"
        and type(value.z) == "number" then return value end
end
local function distance(left, right)
    local a, b = position(left), position(right)
    if not a or not b then return nil end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x * x + y * y + z * z)
end
local function get_corpse_key(object)
    if object and object.get_guid then
        local ok, guid = pcall(object.get_guid, object)
        if ok and guid then return tostring(guid) end
    end
    return tostring(object)
end
local function is_gather_blacklisted(object, now)
    local key = get_corpse_key(object)
    local expires = gather_blacklist[key]
    if not expires then return false, key end
    if expires <= now then
        gather_blacklist[key] = nil
        return false, key
    end
    return true, key
end
local function in_success_cooldown(cache, key, now)
    local expires = cache[key]
    if expires and expires > now then return true end
    cache[key] = nil
    return false
end
local function stop_owned_movement(owner)
    if movement_owner and (not owner or movement_owner == owner) then
        pcall(simple_movement.clear_navigation, simple_movement)
        movement_owner = nil
    end
end
local function status(message)
    Settings.gathering_status = message
end

local function loot_count()
    return math.max(0,tonumber(Host.static(core and core.game_ui,"get_loot_item_count")) or 0)
end
local function loot_work_busy()
    return pending_loot ~= nil or loot_window_open or loot_count() > 0
end
local function request_loot(kind, object, deadline)
    -- A pre-existing window belongs to the player or another action. Never
    -- adopt it merely because automated gathering is enabled.
    if loot_work_busy() then return nil end
    local now = core.time()
    pending_loot = {
        kind = kind, object = object, key = get_corpse_key(object),
        position = position(object), requested_at = now,
        expires_at = math.min(now + LOOT_REQUEST_TIMEOUT, deadline or math.huge),
        next_poll = now, accepted = false, success = false,
    }
    return pending_loot
end
local function accept_loot_request(request, accepted)
    if pending_loot ~= request then return end
    if accepted then request.accepted = true
    else pending_loot = nil end
end
local function request_in_range(request, player)
    local origin, destination = position(player), request.position
    if not origin or not destination then return false end
    local dx, dy, dz = origin.x-destination.x, origin.y-destination.y, origin.z-destination.z
    local range = request.kind == "Fishing" and 45 or 6
    return dx*dx + dy*dy + dz*dz <= range*range
end
local function request_enabled(request)
    if request.kind == "Fishing" then return Settings.on("fishing") end
    if request.kind == "Skinning" then return Settings.on("skinning") end
    return Settings.on(request.kind == "Herbing" and "herbing" or "mining")
end
local function confirm_loot_success(request, now, items_taken)
    if request.success then return end
    request.success = true
    if request.kind == "Fishing" then
        caught_bobbers[request.key] = now + 3
        next_fishing_action = now + 1.5
    elseif request.kind == "Skinning" then
        skinned_corpses[request.key] = now + HARVEST_SUCCESS_COOLDOWN
        pending_skinning_corpses[request.key] = nil
        next_skinning_attempt, next_corpse_interaction = now + 1.5, now + 1.5
    else
        -- Shared nodes can remain visible after our harvest. A success delay
        -- is separate from the user's 60-second failed-node blacklist.
        harvested_nodes[request.key] = now + HARVEST_SUCCESS_COOLDOWN
        gather_blacklist[request.key] = nil
        if active_gather_key == request.key then active_gather_key, active_gather_started = nil, 0 end
        gather_target_key, next_gather_attempt = nil, now + 1.5
        node_draw_cache, next_node_draw_scan = {}, 0
    end
    status(request.kind .. (items_taken and ": loot collected" or ": loot window completed"))
end
local function run_pending_loot()
    local request = pending_loot
    if not request then return end
    local now, player = core.time(), player_ready()
    if not request.accepted or not request_enabled(request) or not player
        or player:is_in_combat() or not request_in_range(request, player)
        or now >= request.expires_at then
        pending_loot = nil
        return
    end
    -- use_object/skin_object only confirm dispatch; the loot slots usually
    -- become available on a later frame, never the dispatch frame itself.
    if now <= request.requested_at or now < request.next_poll then return end
    request.next_poll = now + 0.2
    local count = loot_count()
    if count > 0 then
        request.saw_slots = true
        local ok, success, stats = pcall(fish_helper.loot_all, fish_helper)
        local taken = type(stats) == "table" and
            ((tonumber(stats.looted) or 0) > 0 or (tonumber(stats.gold) or 0) > 0)
        if ok and success == true and taken then confirm_loot_success(request, now, true) end
    elseif request.success or request.closed then
        -- An owned open/close pair also confirms completion when native
        -- auto-loot emptied the window before the next update could see slots.
        if request.closed and request.opened then confirm_loot_success(request, now, false) end
        pending_loot = nil
    end
end
local function on_loot_event(event_name)
    if event_name == "LOOT_OPENED" then
        loot_window_open = true
        local request, player = pending_loot, player_ready()
        -- A second opening is a different window. Finalize an already closed
        -- owned window, but leave this new window entirely to the player.
        if request and (request.opened or request.closed) then
            if request.opened and request.closed and request.accepted then
                confirm_loot_success(request, core.time(), false)
            end
            pending_loot = nil
            return
        end
        if request and player and core.time() < request.expires_at
            and request_in_range(request, player) then request.opened = true end
    elseif event_name == "LOOT_CLOSED" then
        loot_window_open = false
        if pending_loot and pending_loot.opened then pending_loot.closed = true end
    elseif event_name == "PLAYER_LEAVING_WORLD" then
        pending_loot, loot_window_open = nil, false
    elseif event_name == "MERCHANT_SHOW" or event_name == "GOSSIP_SHOW"
        or event_name == "MAIL_SHOW" or event_name == "BANKFRAME_OPENED" then
        pending_loot = nil
    end
end

local function run_auto_fishing()
    if not Settings.on("fishing") then return end
    local player = player_ready()
    if not player or player:is_in_combat() or player_in_travel_form(player) then return end
    local now = core.time()
    if loot_work_busy() then return end
    if now < next_fishing_action then return end
    local bobber
    for _, object in pairs(objects()) do
        local ok, is_bobber = pcall(fish_helper.is_fish_bobber, fish_helper, object)
        if ok and is_bobber then bobber = object; break end
    end
    if bobber then
        if in_success_cooldown(caught_bobbers, get_corpse_key(bobber), now) then return end
        local ok, has_fish = pcall(fish_helper.does_bobber_have_fish, fish_helper, bobber)
        if ok and has_fish then
            local request = request_loot("Fishing", bobber)
            if not request then return end
            local accepted=Host.static(core and core.input,"use_object",bobber)
            accept_loot_request(request,accepted==true)
            next_fishing_action = now + 0.35
            status(accepted and "Fishing: waiting for catch loot" or "Fishing: catch interaction declined")
        else next_fishing_action = now + 0.25 end
        return
    end
    if player:is_casting_spell() or player:is_channelling_spell() then return end
    if now - last_fishing_cast >= 2 then
        local started=Host.static(core and core.profession,"open_profession",core.profession.FISHING)
        last_fishing_cast = now
        next_fishing_action = now + (started and 1 or 2)
        status(started and "Fishing: cast started" or "Fishing: waiting to cast")
    end
end

local function run_auto_looting()
    if not Settings.on("looting") or Settings.on("fishing") then return end
    if loot_work_busy() then return end
    local player = player_ready()
    if not player or player:is_in_combat() or player_in_travel_form(player)
        or player:is_casting_spell() or player:is_channelling_spell() then return end
    local now = core.time()
    if now < next_looting_attempt then return end
    local nearest, nearest_distance = nil, 35
    for _, object in pairs(objects()) do
        local ok, eligible = pcall(function()
            return object:is_valid() and object:is_unit() and object:is_dead()
                and object:can_be_looted() and object:has_loot()
        end)
        if ok and eligible and (recently_looted_corpses[get_corpse_key(object)] or 0) <= now then
            local range = distance(player, object)
            if range and range <= nearest_distance then nearest, nearest_distance = object, range end
        end
    end
    if not nearest then next_looting_attempt = now + 0.5; return end
    local started=Host.static(core and core.input,"loot_object",nearest,true)==true
    next_looting_attempt = now + (started and 1.5 or 1)
    next_corpse_interaction = next_looting_attempt
    if started then
        local key = get_corpse_key(nearest)
        recently_looted_corpses[key] = now + CORPSE_LOOT_RETRY_DELAY
        pending_skinning_corpses[key] = {
            object = nearest, ready_at = now + 1.5,
            expires_at = now + CORPSE_SKIN_QUEUE_LIFETIME,
            next_attempt_at = now + 1.5, attempts = 0,
        }
        status("Looting: corpse loot requested")
    end
end

local function corpse_has_loot_pending(object)
    local ok, pending = pcall(function() return object:can_be_looted() and object:has_loot() end)
    return ok and pending == true
end
local function run_auto_skinning()
    skinning_busy = false
    if not Settings.on("skinning") then stop_owned_movement("skinning"); return end
    if Settings.on("fishing") then stop_owned_movement("skinning"); status("Skinning paused for fishing"); return end
    local player = player_ready()
    if not player then stop_owned_movement("skinning"); status("Skinning: waiting for player"); return end
    if player:is_in_combat() or player_in_travel_form(player) then
        stop_owned_movement("skinning"); status("Skinning paused during combat or Travel Form"); return
    end
    if player:is_casting_spell() or player:is_channelling_spell() then stop_owned_movement("skinning"); return end
    local now = core.time()
    if loot_work_busy() then stop_owned_movement("skinning"); return end
    if Settings.on("looting") and now < next_corpse_interaction then stop_owned_movement("skinning"); return end

    local nearest, nearest_distance, queued_key, queued_record = nil, 35, nil, nil
    for key, record in pairs(pending_skinning_corpses) do
        local ok, valid = pcall(function() return record.object:is_valid() end)
        if now >= record.expires_at or not ok or not valid then pending_skinning_corpses[key] = nil
        elseif not in_success_cooldown(skinned_corpses, key, now)
            and now >= record.ready_at and now >= record.next_attempt_at then
            local range = distance(player, record.object)
            if range and range <= nearest_distance then
                nearest, nearest_distance, queued_key, queued_record = record.object, range, key, record
            end
        end
    end
    for _, object in pairs(objects()) do
        local ok, ready = pcall(function()
            return object:is_valid() and object:is_unit() and object:is_dead()
                and ((object.can_be_skinned and object:can_be_skinned())
                    or (object.has_skin and object:has_skin()))
        end)
        if ok and ready and not corpse_has_loot_pending(object)
            and not in_success_cooldown(skinned_corpses, get_corpse_key(object), now) then
            local range = distance(player, object)
            if range and range <= nearest_distance then
                nearest, nearest_distance, queued_key, queued_record = object, range, nil, nil
            end
        end
    end
    if not nearest then stop_owned_movement("skinning"); status("Skinning: no harvestable corpse within 35 yd"); return end
    skinning_busy = true

    local key = queued_key or get_corpse_key(nearest)
    local target = player:get_target()
    if get_corpse_key(target) ~= key and (skinning_target_key ~= key or now >= next_skinning_target_attempt) then
        skinning_target_key, next_skinning_target_attempt = key, now + 0.5
        Host.static(core and core.input,"set_target",nearest)
    end
    if nearest_distance > SKIN_INTERACT_DISTANCE then
        local a, b = position(player), position(nearest)
        if a and b then
            local remaining = nearest_distance - SKIN_INTERACT_DISTANCE
            local scale = remaining / nearest_distance
            local destination = vec3.new(a.x + (b.x-a.x)*scale, a.y + (b.y-a.y)*scale, a.z + (b.z-a.z)*scale)
            pcall(simple_movement.move_to_position, simple_movement, destination)
            pcall(simple_movement.process, simple_movement)
            movement_owner = "skinning"
            status("Skinning: moving to corpse")
        end
        return
    end
    stop_owned_movement("skinning")
    if now < next_skinning_attempt then return end
    local request = request_loot("Skinning", nearest)
    if not request then return end
    local started=Host.static(core and core.input,"skin_object",nearest)==true
    accept_loot_request(request, started)
    next_skinning_attempt = now + (started and 1.5 or 2)
    if queued_record then
        if not started then queued_record.attempts = queued_record.attempts + 1 end
        queued_record.next_attempt_at = now + 2
    end
    status(started and "Skinning: request accepted" or "Skinning: retrying corpse")
end

local HERB_WORDS = {
    "herb", "bloom", "flower", "lotus", "root", "frond", "lichen",
    "grass", "weed", "vine", "mycobloom", "blossom", "petal", "thorn",
    -- Midnight 12.1 base nodes. Modifiers such as Lush, Wild, Primal,
    -- Lightfused, Voidbound, Cursed and Envenomated preserve these names.
    "tranquility bloom", "argentleaf", "azeroot", "mana lily", "sanguithorn",
    -- The War Within base nodes.
    "arathor's spear", "blessing blossom", "luredrop", "orbinid",
}
local MINING_WORDS = {
    "ore", "deposit", "seam", "lode", "vein", "outcrop", "mining node",
    -- Midnight 12.1 nodes do not contain generic words such as ore/deposit.
    "refulgent copper", "brilliant silver", "umbral tin",
    -- The War Within base nodes.
    "bismuth", "ironclaw", "aqirite",
}
local function name_matches(object, words)
    if not object.get_name then return false end
    local ok, name = pcall(object.get_name, object)
    if not ok or type(name) ~= "string" then return false end
    name = string.lower(name)
    for _, word in ipairs(words) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end
local function node_kind(object)
    local is_herb = name_matches(object, HERB_WORDS)
    local is_mine = name_matches(object, MINING_WORDS)
    if not is_herb and not is_mine then return nil end
    local ok, eligible = pcall(function()
        if not object:is_valid() then return false end
        if object.is_unit and object:is_unit() then return false end
        if object.is_visible and not object:is_visible() then return false end
        -- is_glow() is a visual effect state, not a gathering-node test. Many
        -- harvestable nodes return false here, so it must not gate detection.
        -- Name + validity + non-unit type is the stable cross-build filter.
        return true
    end)
    if not ok or not eligible then return nil end
    return is_herb and "Herbing" or "Mining"
end
local function gather_kind(object)
    local kind = node_kind(object)
    if kind == "Herbing" and Settings.on("herbing") then return kind end
    if kind == "Mining" and Settings.on("mining") then return kind end
    return nil
end

local function draw_gathering_nodes()
    if not Settings.on("draw_herbs") and not Settings.on("draw_mining") then return end
    local player = player_ready()
    if not player then return end
    local player_position = position(player)
    if not player_position then return end
    local now = core.time()
    if now >= next_node_draw_scan then
        next_node_draw_scan = now + 0.5
        local candidates = {}
        for _, object in pairs(objects()) do
            local kind = node_kind(object)
            local blocked = is_gather_blacklisted(object, now)
                or in_success_cooldown(harvested_nodes, get_corpse_key(object), now)
            if not blocked and ((kind == "Herbing" and Settings.on("draw_herbs"))
                or (kind == "Mining" and Settings.on("draw_mining"))) then
                local range = distance(player, object)
                local node_position = position(object)
                if range and range <= NODE_DRAW_RANGE and node_position then
                    candidates[#candidates + 1] = {
                        kind = kind, range = range, position = node_position,
                    }
                end
            end
        end
        table.sort(candidates, function(left, right) return left.range < right.range end)
        node_draw_cache = candidates
    end
    for index = 1, math.min(MAX_NODE_LINES, #node_draw_cache) do
        local node = node_draw_cache[index]
        local line_color = node.kind == "Herbing" and HERB_LINE_COLOR or MINING_LINE_COLOR
        Host.static(core and core.graphics,"line_3d",player_position,node.position,line_color,3)
        Host.static(core and core.graphics,"circle_3d",node.position,1.5,line_color,3,2.5)
    end
end
local function run_auto_gathering()
    if not Settings.on("herbing") and not Settings.on("mining") then
        active_gather_key, active_gather_started = nil, 0
        stop_owned_movement("gathering"); return
    end
    if Settings.on("fishing") then
        active_gather_key, active_gather_started = nil, 0
        stop_owned_movement("gathering"); return
    end
    local player = player_ready()
    if not player or player:is_in_combat() or player_in_travel_form(player) then
        active_gather_key, active_gather_started = nil, 0
        stop_owned_movement("gathering"); return
    end
    if player:is_casting_spell() or player:is_channelling_spell() then return end
    local now = core.time()
    if loot_work_busy() then stop_owned_movement("gathering"); return end
    -- Corpse work owns this frame. Do not replace its destination or issue a
    -- second interaction while loot/skin requests are still being processed.
    if skinning_busy or (Settings.on("looting") and now < next_corpse_interaction) then
        active_gather_key, active_gather_started = nil, 0
        stop_owned_movement("gathering"); return
    end
    local nearest, nearest_distance, kind = nil, 60, nil
    local active_node, active_distance, active_kind
    for _, object in pairs(objects()) do
        local candidate_kind = gather_kind(object)
        local blocked = is_gather_blacklisted(object, now)
            or in_success_cooldown(harvested_nodes, get_corpse_key(object), now)
        if candidate_kind and not blocked then
            local range = distance(player, object)
            if range and range < nearest_distance then
                nearest, nearest_distance, kind = object, range, candidate_kind
            end
            if range and range < 60 and get_corpse_key(object) == active_gather_key then
                active_node, active_distance, active_kind = object, range, candidate_kind
            end
        end
    end
    -- Keep the attempt deadline attached to one node. Re-selecting whichever
    -- node is nearest every frame allowed failed targets to evade the timeout.
    if active_node then nearest, nearest_distance, kind = active_node, active_distance, active_kind end
    if not nearest then
        stop_owned_movement("gathering")
        active_gather_key, active_gather_started = nil, 0
        status("Gathering: no enabled node within 60 yd")
        return
    end
    local key = get_corpse_key(nearest)
    if active_gather_key ~= key then
        active_gather_key, active_gather_started = key, now
    elseif now - active_gather_started >= GATHER_ATTEMPT_TIMEOUT then
        gather_blacklist[key] = now + GATHER_BLACKLIST_DURATION
        active_gather_key, active_gather_started = nil, 0
        gather_target_key, next_gather_attempt = nil, 0
        stop_owned_movement("gathering")
        node_draw_cache, next_node_draw_scan = {}, 0
        status(kind .. ": node failed for 10 sec; blacklisted for 60 sec")
        return
    end
    if nearest_distance > SKIN_INTERACT_DISTANCE then
        local a, b = position(player), position(nearest)
        if a and b then
            local remaining = nearest_distance - SKIN_INTERACT_DISTANCE
            local scale = remaining / nearest_distance
            pcall(simple_movement.move_to_position, simple_movement,
                vec3.new(a.x + (b.x-a.x)*scale, a.y + (b.y-a.y)*scale, a.z + (b.z-a.z)*scale))
            pcall(simple_movement.process, simple_movement)
            movement_owner = "gathering"
            status(kind .. ": moving to node")
        end
        return
    end
    stop_owned_movement("gathering")
    if now < next_gather_attempt and gather_target_key == key then return end
    if player:is_mounted() and now >= next_dismount_attempt then
        -- Players with the profession unlock can gather while mounted. Try the
        -- node once first; if the client rejects it, dismount and retry shortly.
        local request = request_loot(kind, nearest, active_gather_started + GATHER_ATTEMPT_TIMEOUT)
        if not request then return end
        local mounted_used=Host.static(core and core.input,"use_object",nearest)
        accept_loot_request(request,mounted_used==true)
        if mounted_used then
            gather_target_key, next_gather_attempt = key, now + 2
            status(kind .. ": gathering node while mounted")
            return
        end
        Host.static(core and core.input,"dismount")
        next_dismount_attempt = now + 1
        gather_target_key, next_gather_attempt = key, now + 0.6
        status(kind .. ": dismounting to gather")
        return
    end
    gather_target_key, next_gather_attempt = key, now + 2
    local request = request_loot(kind, nearest, active_gather_started + GATHER_ATTEMPT_TIMEOUT)
    if not request then return end
    local used=Host.static(core and core.input,"use_object",nearest)
    accept_loot_request(request,used==true)
    if used then
        status(kind .. ": gathering node")
    else
        status(kind .. ": interaction retry scheduled")
    end
end

local function safe(callback, label)
    return function(...)
        local ok = pcall(callback,...)
        if not ok then status(label .. ": runtime API unavailable") end
    end
end
M.fishing, M.looting, M.skinning = safe(run_auto_fishing, "Fishing"),
    safe(run_auto_looting, "Looting"), safe(run_auto_skinning, "Skinning")
M.gathering = safe(run_auto_gathering, "Gathering")
M.pending_loot = safe(run_pending_loot, "Loot completion")
M.on_event = safe(on_loot_event, "Loot event")
if type(core.register_on_game_event_callback) == "function" then
    core.register_on_game_event_callback(M.on_event)
end
-- A single dispatcher avoids five protected host callbacks every frame while
-- preserving the established ownership order between loot and professions.
M.update=function()
    M.pending_loot();M.fishing();M.looting();M.skinning();M.gathering()
end
core.register_on_update_callback(M.update)
core.register_on_render_callback(function()
    pcall(draw_gathering_nodes)
end)
return M

