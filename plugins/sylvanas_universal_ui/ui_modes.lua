local U=require('ui_util')
local M={order={'solo','world_pve','delve','dungeon','mythic_plus','raid','arena','battleground','world_pvp'}}
M.labels={solo='Solo',world_pve='World PvE Group',delve='Delves',dungeon='Dungeon',mythic_plus='Mythic+',raid='Raid',arena='Arena',battleground='Battleground',world_pvp='World PvP',unknown='Activity unavailable'}
function M.detect(me,target,members)
 if core.delves and U.fn(core.delves.is_in_delve)==true then return 'delve' end
 local raw=U.fn(core.get_instance_type)
 if type(raw)~='string' then return 'unknown' end
 local kind=raw:lower()
 if kind=='arena' then return 'arena' end
 if kind=='pvp' or kind=='battleground' then return 'battleground' end
 if kind=='raid' then return 'raid' end
 if kind=='party' then
  local map=core.world and U.num(U.fn(core.world.get_active_challenge_map_id))
  if map and map>0 or U.num(U.fn(core.get_difficulty_id))==8 then return 'mythic_plus' end
  return 'dungeon'
 end
 if kind=='scenario' then return 'dungeon' end
 if kind=='none' then
  if U.call(target,'is_player')==true and U.call(me,'can_attack',target)==true then return 'world_pvp' end
  if type(members)~='table' then return 'world_pve' end
  return next(members) and 'world_pve' or 'solo'
 end
 return 'unknown'
end
return M
