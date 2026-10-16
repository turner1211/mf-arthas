local M={}
local ok,pvp=pcall(require,"common/utility/pvp_helper")
if not ok then pvp=nil end
local function read(fn,...)
    if type(fn)~="function" then return nil end
    local success,value=pcall(fn,...)
    if success then return value end
end
function M.get()
    local raw=read(core.get_instance_type)
    local kind=type(raw)=="string" and raw:lower() or ""
    local difficulty=read(core.get_difficulty_id)
    local mode,label="unknown","Unknown / loading"
    local is_pvp=false
    if kind=="arena" then mode,label,is_pvp="arena","Arena",true
    elseif kind=="pvp" or kind=="battleground" then mode,label,is_pvp="battleground","Battleground",true
    elseif core.delves and read(core.delves.is_in_delve)==true then mode,label="delve","Delve"
    elseif kind=="party" then
        local key=core.world and read(core.world.get_active_keystone_info)
        -- Never infer an active run from the keystone carried in the player's bag.
        local active=type(key)=="table" and type(key.level)=="number" and key.level>0
        if difficulty==8 or active then mode,label="mythic_plus","Mythic+ dungeon"
        else mode,label="dungeon","Dungeon" end
    elseif kind=="raid" then mode,label="raid","Raid"
    elseif kind=="scenario" then mode,label="scenario","Scenario"
    elseif pvp and read(pvp.is_pvp_scenario,pvp)==true then mode,label,is_pvp="pvp","PvP",true
    elseif kind=="none" then mode,label="world","Open world" end
    return {mode=mode,label=label,pvp=is_pvp,
        dungeon=mode=="dungeon" or mode=="mythic_plus",mythic_plus=mode=="mythic_plus"}
end
return M
