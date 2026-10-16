local Group=require("guardian_group")
local M={kind="world",label="World",map_id=0,group_size=1,alive=1,dead=0,solo=true}
local DELVES={ [2933]=true,[2952]=true,[2953]=true,[2961]=true,[2962]=true,[2963]=true,[2964]=true,[2965]=true,[2966]=true,[2979]=true,[3003]=true,[3038]=true,[3077]=true,[3079]=true }
local LABYRINTH_ZONE_ID=16913
local function call(object,method,...)
    if not object or type(object[method])~="function" then return nil end
    local ok,value=pcall(object[method],object,...); if ok then return value end
end
local function global(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...); if ok then return value end
end
local function unwrap(value) return type(value)=="table" and value.object or value end
local function normalized(value) return tostring(value or ""):lower():gsub("[^%w]","") end
function M.is_labyrinth()
    for _,value in pairs({global(core.get_instance_id),global(core.get_map_id),core.world and global(core.world.get_current_map_id)}) do
        if tonumber(value)==LABYRINTH_ZONE_ID then return true end
    end
    return normalized(global(core.get_instance_name)):find("labyrinthofkindojan",1,true)~=nil
end
function M.update(player)
    local challenge=core.world and global(core.world.get_active_challenge_map_id) or 0
    local map=global(core.get_map_id) or (core.world and global(core.world.get_current_map_id)) or 0
    local instance=global(core.get_instance_type) or "none"
    local kind,label="world","World"
    if tonumber(challenge) and tonumber(challenge)>0 then kind,label="mythic_plus","Mythic+"
    elseif M.is_labyrinth() then kind,label="delve","Labyrinth"
    elseif (core.delves and global(core.delves.is_in_delve)==true) or DELVES[tonumber(map) or 0] then kind,label="delve","Delve"
    elseif instance=="party" then kind,label="dungeon","Dungeon"
    elseif instance=="raid" then kind,label="raid","Raid" end
    local alive,dead=0,0
    local healer_count,healer_ready,healer_mana=0,0,nil
    local roster=Group.roster(player)
    for _,entry in ipairs(roster) do
        local unit=entry.object
        local available=entry.is_online~=false and call(unit,"is_valid")==true
        if entry.role=="HEALER" then
            healer_count=healer_count+1
            if available and call(unit,"is_dead")~=true then
                healer_ready=healer_ready+1
                local power,maximum=tonumber(call(unit,"get_power",0)),tonumber(call(unit,"get_max_power",0))
                if power and maximum and maximum>0 then healer_mana=math.max(healer_mana or 0,math.max(0,math.min(100,power/maximum*100))) end
            end
        end
        if call(unit,"is_dead")==true then dead=dead+1 elseif available then alive=alive+1 end
    end
    M.healer_unavailable=healer_count>0 and healer_ready==0
    M.healer_mana=healer_mana
    M.kind,M.label,M.map_id=kind,label,tonumber(map) or 0
    M.alive,M.dead,M.group_size,M.solo=alive,dead,#roster,#roster<=1
    return M
end
function M.is_delve() return M.kind=="delve" end
function M.is_group_pve() return M.kind=="mythic_plus" or M.kind=="dungeon" or M.kind=="raid" end
return M
