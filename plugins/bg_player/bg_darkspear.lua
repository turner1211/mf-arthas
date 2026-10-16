-- Forever-only Darkspear landmarks. Public coordinates are normalized UI-map
-- positions; convert them with the running client and measure terrain before use.
local M={}
local MAP_ID=2524
local INSTANCE_ID=2997
local rules={team_size=15,capture_points=4,score_to_win=2000,central_flag=true,
 flag_requires_owned_base=true,min_level=30,max_level=60}
local points={
 shipwreck_cove={x=.415,y=.434},abandoned_tower={x=.616,y=.452},
 center_flag={x=.511,y=.524},camp={x=.421,y=.624},ruins={x=.613,y=.621}
}
local links={
 shipwreck_cove={"abandoned_tower","center_flag","camp"},
 abandoned_tower={"shipwreck_cove","center_flag","ruins"},
 center_flag={"shipwreck_cove","abandoned_tower","camp","ruins"},
 camp={"shipwreck_cove","center_flag","ruins"},
 ruins={"abandoned_tower","center_flag","camp"}
}
local cache
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function M.landmarks(core,reference_z)
 if cache then return cache end
 local ui=core and core.game_ui
 if type(ui)~="table" or type(ui.get_world_pos_from_map_pos)~="function" or
  type(core.get_height_for_position)~="function" then return nil,"map_conversion_unavailable" end
 local ok2,Vec2=pcall(require,"common/geometry/vector_2")
 local ok3,Vec3=pcall(require,"common/geometry/vector_3")
 if not ok2 or not Vec2 or type(Vec2.new)~="function" or not ok3 or not Vec3 or type(Vec3.new)~="function" then
  return nil,"geometry_unavailable"
 end
 local resolved={}
 for id,map in pairs(points) do
  local ok,xy,continent=pcall(ui.get_world_pos_from_map_pos,MAP_ID,Vec2.new(map.x,map.y))
  if not ok or not xy or not finite(xy.x) or not finite(xy.y) then return nil,"map_conversion_failed:"..id end
  if finite(continent) and continent>0 and continent~=INSTANCE_ID then return nil,"map_continent_mismatch" end
  local seed=finite(reference_z) and reference_z or 0
  local height_ok,z=pcall(core.get_height_for_position,Vec3.new(xy.x,xy.y,seed),{probe_up=250})
  if not height_ok or not finite(z) then return nil,"terrain_height_unavailable:"..id end
  resolved[id]={x=xy.x,y=xy.y,z=z,id=id,map_x=map.x,map_y=map.y}
 end
 cache=resolved
 return cache
end
function M.reset() cache=nil end
function M.route(core,start,goal)
 if not start or not goal then return nil end
 local nodes=M.landmarks(core,start.z);if not nodes then return nil end
 local function nearest(p)
  local id,best
  for key,node in pairs(nodes) do local d=distance(p,node);if not best or d<best then id,best=key,d end end
  return id,best
 end
 local source,sd=nearest(start);local target,td=nearest(goal)
 if not source or not target or sd>180 or td>45 then return nil end
 local path
 if source==target then path={target}
 else
  local adjacent=false;for _,id in ipairs(links[source] or {}) do if id==target then adjacent=true;break end end
  path=adjacent and {source,target} or {source,"center_flag",target}
 end
 local out={source="forever_runtime_map_2524",coordinate_source="normalized_map_runtime_conversion",
  waypoint_radius=7,lock_id="darkspear_landmark_"..source.."_"..target,direct=false,
  avoid_mount=false,allow_direct_fallback=false}
 for _,id in ipairs(path) do local n=nodes[id];out[#out+1]={x=n.x,y=n.y,z=n.z} end
 return out
end
M.map_id=MAP_ID;M.instance_id=INSTANCE_ID;M.points=points
M.rules=rules
return M
