local M = {}
local Host = require("prot_host")
local Dungeon = require("prot_dungeon")
local dispellable = {}
local labyrinth_failures = 0

local function token_bucket(token)
    token=tostring(token or "")
    if token=="" then return nil end
    dispellable[token]=dispellable[token] or {}
    return dispellable[token]
end

function M.on_event(event,args)
    if event~="UNIT_AURA" or type(args)~="table" then return end
    local action,token=tostring(args[1] or ""),tostring(args[2] or "")
    if action=="full" then
        dispellable[token]={}
        if token=="player" then labyrinth_failures=0 end
        return
    end
    local bucket=token_bucket(token); if not bucket then return end
    local instance=tostring(args[3] or "")
    local spell_id=tonumber(args[4])
    if action=="removed" then
        bucket[instance]=nil
        if token=="player" and spell_id==1303494 then labyrinth_failures=0 end
        return
    end
    if action~="added" and action~="updated" then return end
    if token=="player" and spell_id==1303494 then
        labyrinth_failures=math.max(1,math.floor(tonumber(args[6]) or 1))
    end
    local harmful=args[11]==true
    local kind=string.lower(tostring(args[12] or ""))
    if harmful and (kind=="poison" or kind=="disease") then
        bucket[instance]={spell_id=tonumber(args[4]),name=tostring(args[5] or kind),kind=kind}
    else bucket[instance]=nil end
end

function M.labyrinth_failure_stacks() return labyrinth_failures end

local function afflicted(token)
    local bucket=dispellable[tostring(token or "")]
    return bucket and next(bucket)~=nil
end

function M.cleanse_target(player)
    if afflicted("player") then return player,"self" end
    local members=Host.manager("get_party_members")
    if type(members)~="table" then return nil end
    table.sort(members,function(a,b)
        return (string.upper(tostring(a.role or ""))=="HEALER" and 0 or 1)
            < (string.upper(tostring(b.role or ""))=="HEALER" and 0 or 1)
    end)
    for _,member in ipairs(members) do
        local object=member.object
        local dead=false
        if object and object.is_dead then
            local dead_ok,value=pcall(object.is_dead,object); dead=dead_ok and value==true
        end
        if object and not dead and afflicted(member.unit_token) then return object,member.role end
    end
end

function M.dead_ally()
    local members=Host.manager("get_party_members")
    if type(members)~="table" then return nil end
    local best,best_score
    for _,member in pairs(members) do
        local object=member.object
        local dead_ok,dead=false,false
        if object and object.is_dead then dead_ok,dead=pcall(object.is_dead,object) end
        if dead_ok and dead and member.is_online~=false then
            local role=string.upper(tostring(member.role or ""))
            local score=role=="HEALER" and 3 or role=="TANK" and 2 or 1
            if not best_score or score>best_score then best,best_score=object,score end
        end
    end
    return best
end

function M.critical_healer(threshold)
    local members=Host.manager("get_party_members")
    if type(members)~="table" then return nil end
    for _,member in pairs(members) do
        if string.upper(tostring(member.role or ""))=="HEALER" and member.object then
            local object=member.object
            local ok_values,health,maximum=pcall(function()
                return object:get_health(),object:get_max_health()
            end)
            if ok_values and maximum and maximum>0 and health*100/maximum<=(threshold or 25)
                and (not object.is_dead or not object:is_dead()) then return object end
        end
    end
end

function M.critical_ally(threshold)
    local members=Host.manager("get_party_members")
    if type(members)~="table" then return nil end
    local best,best_percent,best_role=nil,math.huge,math.huge
    for _,member in pairs(members) do
        local object=member.object
        local values_ok,health,maximum=pcall(function()
            return object:get_health(),object:get_max_health()
        end)
        local dead=false
        if object and object.is_dead then
            local dead_ok,value=pcall(object.is_dead,object);dead=dead_ok and value==true
        end
        if object and not dead and member.is_online~=false and values_ok
            and maximum and maximum>0 then
            local percent=health*100/maximum
            local role=string.upper(tostring(member.role or ""))=="HEALER" and 0 or 1
            if percent<=(threshold or 25)
                and (percent<best_percent or (percent==best_percent and role<best_role)) then
                best,best_percent,best_role=object,percent,role
            end
        end
    end
    return best,best_percent
end

local function movement_impaired(unit)
    if not unit then return false end
    for _,method in ipairs({"is_rooted","is_slowed"}) do
        if type(unit[method])=="function" then
            local ok,value=pcall(unit[method],unit,100)
            if ok and value==true then return true end
        end
    end
    return false
end
function M.freedom_target(player)
    if movement_impaired(player) then return player,"self" end
    local members=Host.manager("get_party_members")
    if type(members)~="table" then return nil end
    table.sort(members,function(a,b)
        return (string.upper(tostring(a.role or ""))=="HEALER" and 0 or 1)
            < (string.upper(tostring(b.role or ""))=="HEALER" and 0 or 1)
    end)
    for _,member in ipairs(members) do
        if movement_impaired(member.object) then return member.object,member.role end
    end
end
function M.critical_delve_companion(player,threshold)
    if not Dungeon.is_delve_like() then return nil end
    local objects=Host.manager("get_all_objects")
    if type(objects)~="table" then return nil end
    for _,enemy in pairs(objects) do
        local hostile_ok,hostile=pcall(player.can_attack,player,enemy)
        if hostile_ok and hostile and enemy.get_target then
            local target_ok,target=pcall(enemy.get_target,enemy)
            if target_ok and target and target~=player then
                local friendly_ok,friendly=pcall(player.can_attack,player,target)
                local values_ok,health,maximum=pcall(function()
                    return target:get_health(),target:get_max_health()
                end)
                if friendly_ok and friendly==false and values_ok and maximum and maximum>0
                    and health*100/maximum<=(threshold or 30) then return target end
            end
        end
    end
end

function M.reset() dispellable={};labyrinth_failures=0 end
return M
