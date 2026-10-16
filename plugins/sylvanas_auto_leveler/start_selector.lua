-- Select only explicitly validated profiles. Guide level ranges alone are not enough.
local M={}
function M.select(profiles,character)
 local best,score=nil,-math.huge
 for id,p in pairs(profiles) do
  local level=character.level
  if p.validated==true and p.min_level and p.max_level and level>=p.min_level and level<=p.max_level
   and (not p.faction_id or p.faction_id==character.faction_id)
   and (not p.race_id or p.race_id==character.race_id)
   and (not p.class_id or p.class_id==character.class_id) then
   local s=p.min_level+(p.world_map_id==character.world_map_id and 0.5 or 0)
   if s>score or (s==score and tostring(id)<tostring(best)) then best=id;score=s end
  end
 end
 if best then return best end
 return nil,"validated_level_route_required"
end
return M
