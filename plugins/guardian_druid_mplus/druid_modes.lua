local M={}
M.order={"world_pve","delve","dungeon","mythic_plus","raid","arena","battleground","world_pvp"}
M.labels={world_pve="World PvE",delve="Delves",dungeon="Dungeon",mythic_plus="Mythic+",raid="Raid",
    arena="Arena",battleground="Battleground",world_pvp="World PvP"}
M.pvp={arena=true,battleground=true,world_pvp=true}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...); if ok then return value end
end
function M.detect(player,target)
    local raw=call(core.get_instance_type)
    if type(raw)~="string" then return nil,"Instance type unavailable" end
    raw=raw:lower()
    if raw=="arena" then return "arena" end
    if raw=="pvp" or raw=="battleground" then return "battleground" end
    if core.delves and call(core.delves.is_in_delve)==true then return "delve" end
    if raw=="party" then
        local challenge=core.world and tonumber(call(core.world.get_active_challenge_map_id))
        if challenge and challenge>0 or tonumber(call(core.get_difficulty_id))==8 then return "mythic_plus" end
        return "dungeon"
    end
    if raw=="raid" then return "raid" end
    if raw=="scenario" then return "dungeon" end
    if raw~="none" and raw~="" then return nil,"Unsupported instance: "..raw end
    local hostile_player=false
    if target and type(target.is_player)=="function" then
        local ok,value=pcall(target.is_player,target); hostile_player=ok and value==true
    end
    if hostile_player and player and type(player.can_attack)=="function" then
        local ok,value=pcall(player.can_attack,player,target); hostile_player=ok and value==true
    end
    return hostile_player and "world_pvp" or "world_pve"
end
function M.allowed(spec,mode)
    if spec==3 and mode=="arena" then return false end
    return mode~=nil
end
return M
