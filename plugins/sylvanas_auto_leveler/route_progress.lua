local R={}
local function distance(a,b)
 local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z
 return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function clamp_radius(radius)
 return math.max(2,math.min(18,tonumber(radius) or 18))
end
-- Straight roads can use the profile's normal tolerance. Corners and ramps
-- need a tighter proof so a large radius cannot skip the turn or change floor.
function R.adaptive_radius(route,index,origin,radius)
 radius=clamp_radius(radius)
 if type(route)~="table" or type(index)~="number" then return radius end
 local waypoint=route[index]
 if type(waypoint)~="table" then return radius end
 local before=origin or route[index-1]
 local after=route[index+1]
 local steep=false
 if before then steep=math.abs(waypoint.z-before.z)>5 end
 if after then steep=steep or math.abs(after.z-waypoint.z)>5 end
 if steep then return math.min(radius,4) end
 if before and after then
  local ax,ay=waypoint.x-before.x,waypoint.y-before.y
  local bx,by=after.x-waypoint.x,after.y-waypoint.y
  local al,bl=math.sqrt(ax*ax+ay*ay),math.sqrt(bx*bx+by*by)
  if al>0.1 and bl>0.1 then
   local cosine=(ax*bx+ay*by)/(al*bl)
   if cosine<0 then return math.min(radius,3) end
   if cosine<0.71 then return math.min(radius,4) end
  end
 end
 return radius
end
function R.reached(position,waypoint,origin,radius)
 radius=clamp_radius(radius)
 local horizontal=math.sqrt((position.x-waypoint.x)^2+(position.y-waypoint.y)^2)
 if distance(position,waypoint)<=radius then return true,"arrived" end
 -- Some public battleground landmarks use object/deck height instead of the
 -- walkable floor. Exact X/Y arrival with a small Z discrepancy proves the
 -- corridor was reached; larger differences still protect bridges and tunnels.
 if horizontal<=math.min(2,radius) and math.abs(position.z-waypoint.z)<=8 then
  return true,"floor_adjusted"
 end
 if not origin then return false end
 local dx,dy=waypoint.x-origin.x,waypoint.y-origin.y
 local length2=dx*dx+dy*dy
 if length2<16 then return false end
 local px,py=position.x-origin.x,position.y-origin.y
 local projection=(px*dx+py*dy)/length2
 if projection<1 or projection>1+math.max(30,radius*2)/math.sqrt(length2) then return false end
 local nearest_x,nearest_y=origin.x+projection*dx,origin.y+projection*dy
 local lateral=math.sqrt((position.x-nearest_x)^2+(position.y-nearest_y)^2)
 if lateral>radius then return false end
 -- Crossing a waypoint on another bridge, floor or ramp does not prove that
 -- the authored corridor was traversed.
 if math.abs(position.z-waypoint.z)>math.max(6,radius) then return false end
 return true,"passed"
end
function R.resume_index(position,route,radius)
 if type(route)~="table" or #route==0 then return 1 end
 radius=clamp_radius(radius)
 local best_index,best_distance
 for index,waypoint in ipairs(route) do
  if type(waypoint)=="table" and math.abs(position.z-waypoint.z)<=math.max(12,radius*2) then
   local d=distance(position,waypoint)
   if not best_distance or d<best_distance then best_index,best_distance=index,d end
  end
 end
 -- Only resume from a landmark that is credibly local. A distant nearest point
 -- may be across a wall, tunnel roof or unrelated section of a folded map.
 if not best_index or best_distance>math.max(80,radius*5) then return 1 end
 if best_distance<=radius then return math.min(#route+1,best_index+1) end
 return best_index
end
return R
