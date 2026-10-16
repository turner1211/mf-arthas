-- One object-manager snapshot shared by every combat subsystem.
local M={}
local Settings=require("guardian_settings")
local snapshot,next_refresh,world_snapshot,next_world={},0,{},0
local function filtered(value,player,radius)
    local result,seen={},{}
    local origin=player and player.get_position and player:get_position()
    local limit=(radius or 80)^2
    for _,unit in pairs(type(value)=="table" and value or {}) do
        local valid,near=pcall(function()
            if not unit:is_valid() or not unit:is_unit() or unit:is_dead() then return false end
            if not origin then return true end
            local p=unit:get_position(); if not p then return false end
            local dx,dy,dz=p.x-origin.x,p.y-origin.y,p.z-origin.z
            return dx*dx+dy*dy+dz*dz<=limit
        end)
        if valid and near and not seen[unit] then seen[unit]=true; result[#result+1]=unit end
    end
    return result
end
function M.get()
    local now=core.time()
    if now>=next_refresh then
        local value,ok={},true
        local player=core.object_manager.get_local_player()
        if Settings.on("low_lag") then
            local combat_ok,combat=false,false
            if player and player.is_in_combat then combat_ok,combat=pcall(player.is_in_combat,player) end
            combat=combat_ok and combat==true
            -- Keep emergency low-lag mode aware of off-target threats without
            -- returning to a full object-manager scan on every combat tick.
            if combat and now>=next_world then
                local scanned,list=pcall(core.object_manager.get_all_objects)
                if scanned and type(list)=="table" then world_snapshot=filtered(list,player,45) end
                next_world=now+1.0
            elseif not combat then
                world_snapshot={}; next_world=0
            end
            for _,unit in pairs(world_snapshot) do value[#value+1]=unit end
            value[#value+1]=player and player.get_target and player:get_target() or nil
            if core.object_manager.get_boss_frames then
                local frames_ok,frames=pcall(core.object_manager.get_boss_frames)
                if frames_ok then for _,unit in pairs(type(frames)=="table" and frames or {}) do value[#value+1]=unit end end
            end
        else
            ok,value=pcall(core.object_manager.get_all_objects)
            ok=ok and type(value)=="table"
        end
        snapshot=ok and filtered(value,player,Settings.on("low_lag") and 45 or 80) or snapshot
        -- Match the main loop cadence. Out of combat there is no reason to
        -- rebuild the world snapshot five times per second.
        local combat_ok,combat=false,false
        if player and player.is_in_combat then combat_ok,combat=pcall(player.is_in_combat,player) end
        next_refresh=now+(combat_ok and combat==true and 0.25 or 0.50)
    end
    return snapshot
end
function M.reset() snapshot={}; next_refresh=0; world_snapshot={}; next_world=0 end
return M
