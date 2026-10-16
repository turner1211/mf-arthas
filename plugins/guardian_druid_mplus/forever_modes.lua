local M={order={"world_pve","dungeon","raid","battleground","world_pvp"},pvp={battleground=true,world_pvp=true}}
M.labels={world_pve="World PvE",dungeon="Dungeon",raid="Raid",battleground="Battleground",world_pvp="World PvP"}
function M.detect(player,target)
 local ok,kind=pcall(core.get_instance_type);kind=ok and type(kind)=="string" and kind:lower() or "none"
 if kind=="pvp" or kind=="battleground" then return "battleground" end
 if kind=="party" or kind=="scenario" then return "dungeon" end
 if kind=="raid" then return "raid" end
 local hostile=false;if target and type(target.is_player)=="function" then local a,b=pcall(target.is_player,target);hostile=a and b==true end
 return hostile and "world_pvp" or "world_pve"
end
return M
