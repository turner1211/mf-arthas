-- Authoring aid: website/map percentages are not XYZ navigation destinations.
local M={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function M.resolve_xy(api,map_id,x,y)
 if not finite(map_id) or map_id<1 or map_id%1~=0 then return nil,"ui_map_id_required" end
 if not finite(x) or not finite(y) or x<0 or y<0 or x>100 or y>100 then return nil,"invalid_percent_coordinates" end
 local ok,position,continent=pcall(api.convert,map_id,x/100,y/100)
 if not ok then return nil,"map_conversion_failed" end
 if not position or not finite(position.x) or not finite(position.y) then return nil,"map_conversion_unavailable" end
 local result={x=position.x,y=position.y,ui_map_id=map_id,playable=false,
  requires={"terrain_height_and_floor_validation","mesh_reachability_validation","phase_validation"}}
 if finite(continent) and continent>0 and continent%1==0 then
  result.world_map_id=continent
  if continent~=api.current_map() then result.requires[#result.requires+1]="cross_map_transport_required" end
 else result.requires[#result.requires+1]="world_map_identity_required" end
 return result
end
function M.runtime_resolve(map_id,x,y)
 local Vec=require("common/geometry/vector_2")
 return M.resolve_xy({current_map=core.get_map_id,convert=function(id,nx,ny)
  return core.game_ui.get_world_pos_from_map_pos(id,Vec.new(nx,ny)) end},map_id,x,y)
end
return M
