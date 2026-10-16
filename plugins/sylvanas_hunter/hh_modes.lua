local U=require('hh_util')
local M={order={'world_pve','delve','dungeon','mythic_plus','raid','arena','battleground','world_pvp'}}
M.labels={world_pve='World PvE',delve='Delves',dungeon='Dungeons',mythic_plus='Mythic+',raid='Raids',arena='Arena',battleground='Battlegrounds',world_pvp='World PvP'}
M.pvp={arena=true,battleground=true,world_pvp=true}
function M.detect(p,t)
 local raw=U.fn(core.get_instance_type)
 if type(raw)~='string' or raw=='' then return nil,'instance_unavailable' end
 local k=raw:lower()
 if k=='arena' then return 'arena' end
 if k=='pvp' or k=='battleground' then return 'battleground' end
 local delve=core.delves and U.fn(core.delves.is_in_delve)
 if delve==true then return 'delve' end
 if k=='party' then
  local map=core.world and U.number(U.fn(core.world.get_active_challenge_map_id))
  if map and map>0 or U.fn(core.get_difficulty_id)==8 then return 'mythic_plus' end
  return 'dungeon'
 end
 if k=='raid' then return 'raid' end
 if k=='scenario' then return 'dungeon' end
 if k~='none' then return nil,'unknown_instance_'..k end
 -- War Mode by itself never changes NPC rotations into PvP rotations.
 if U.enemy(p,t) then
  if U.pvp_unit(t) then return 'world_pvp' end
  if U.call(t,'is_pet')==true and U.call(U.call(t,'get_owner'),'is_valid')~=true then return nil,'target_owner_unavailable' end
 end
 return 'world_pve'
end
return M
