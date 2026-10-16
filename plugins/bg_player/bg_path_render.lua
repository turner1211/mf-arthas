local M={height=0.18,max_route_points=16,max_nav_points=48}
local ok_color,Color=pcall(require,"common/color")
local ok_vec,Vec3=pcall(require,"common/geometry/vector_3")
local function lift(p,extra)
 if not p then return nil end
 local ok,x,y,z=pcall(function() return p.x,p.y,p.z end)
 if not ok or type(x)~="number" or type(y)~="number" or type(z)~="number" then return nil end
 local raised=z+M.height+(tonumber(extra) or 0)
 if ok_vec and Vec3 and Vec3.new then return Vec3.new(x,y,raised) end
 return {x=x,y=y,z=raised}
end
local function vec(x,y,z)
 if ok_vec and Vec3 and Vec3.new then return Vec3.new(x,y,z) end
 return {x=x,y=y,z=z}
end
local function color(r,g,b,a)
 return ok_color and Color and Color.new and Color.new(r,g,b,a)
end
local palette
local function colors()
 if palette then return palette end
 if not color(1,1,1,1) then return nil end
 palette={cyan=color(30,190,255,220),white=color(255,255,255,150),gold=color(255,190,40,230),green=color(70,255,120,220),
  up=color(255,145,35,235),down=color(180,90,255,235),label=color(235,245,255,235)}
 return palette
end
function M.draw(core,controller,nav,combat,performance_tier)
 local paints=colors()
 if not core or not controller or not core.graphics or not paints then return end
 local player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
 if not player or not controller.destination then return end
 local ok,player_position=pcall(function() return player:is_valid() and player:get_position() end)
 if not ok or not player_position then return end
 local cyan,white,gold,green=paints.cyan,paints.white,paints.gold,paints.green
 local up,down,label=paints.up,paints.down,paints.label
 local tier=math.max(0,math.min(2,tonumber(performance_tier) or 0))
 local route_budget=combat and (tier>=2 and 4 or 8) or (tier>=2 and 8 or M.max_route_points)
 local nav_budget=combat and (tier>=2 and 12 or 20) or (tier>=2 and 24 or M.max_nav_points)
 local path=nav and nav.get_current_path and nav:get_current_path()
 local start=lift(player_position)
 local display_destination=type(path)=="table" and #path>0 and path[#path] or controller.destination
 local goal=lift(display_destination)
 local direct=controller.plan and type(controller.plan.route)=="table" and controller.plan.route.direct==true
 -- A straight chord between distant ground points cuts through terrain and
 -- falsely looks underground. Draw it only when local direct steering really
 -- follows that line; Sentinel paths are rendered from their actual points.
 if direct and start and goal and core.graphics.line_3d then core.graphics.line_3d(start,goal,cyan,4) end
 if goal and core.graphics.circle_3d then core.graphics.circle_3d(goal,2.2,gold,5) end
 -- Draw the plugin's authored route independently of Sentinel's internal path.
 -- The route coordinates remain unchanged; lift is render-only and keeps the
 -- guide just above the ground at the player's feet.
 local route=controller.locked_route
 local route_index=math.max(1,tonumber(controller.route_index) or 1)
 if type(route)=="table" and route_index<=#route then
  local previous=direct and start or nil
  local route_last=math.min(#route,route_index+route_budget-1)
  for i=route_index,route_last do
   local point=lift(route[i])
   if direct and previous and point and core.graphics.line_3d then core.graphics.line_3d(previous,point,green,4) end
   if point and core.graphics.circle_3d then core.graphics.circle_3d(point,i==route_index and 1.1 or 0.7,green,3) end
   if point and core.graphics.text_3d and (i==route_index or (i-route_index)%4==0) then
    core.graphics.text_3d("WP "..tostring(i).."/"..tostring(#route),lift(route[i],1.0),13,label,true)
   end
   -- A flat line cannot show whether the next point belongs to a bridge,
   -- ramp or lower floor. Draw a vertical shaft at the next waypoint and label
   -- the height delta relative to the player.
   if i==route_index and type(route[i].z)=="number" and type(player_position.z)=="number" then
    local dz=route[i].z-player_position.z
    if math.abs(dz)>=3 and core.graphics.line_3d then
     local base=vec(route[i].x,route[i].y,math.min(route[i].z,player_position.z)+M.height)
     local top=vec(route[i].x,route[i].y,math.max(route[i].z,player_position.z)+M.height)
     local elevation_color=dz>0 and up or down
     core.graphics.line_3d(base,top,elevation_color,5)
     if core.graphics.text_3d then
      core.graphics.text_3d((dz>0 and "UP +" or "DOWN ")..string.format("%.0f yd",dz),lift(route[i],2.0),15,elevation_color,true)
     end
    end
   end
   -- Add a ground-plane arrowhead for the next segment. It is visual only and
   -- uses the same points as movement, so it cannot create a routing shortcut.
   if direct and previous and point and core.graphics.triangle_3d_filled then
    local dx,dy=point.x-previous.x,point.y-previous.y;local length=math.sqrt(dx*dx+dy*dy)
    if length>2 then
     local ux,uy=dx/length,dy/length;local px,py=-uy,ux
     local mx,my=(previous.x+point.x)*0.5,(previous.y+point.y)*0.5;local mz=(previous.z+point.z)*0.5+0.03
     core.graphics.triangle_3d_filled(vec(mx+ux*2.4,my+uy*2.4,mz),vec(mx-ux*1.4+px*1.4,my-uy*1.4+py*1.4,mz),vec(mx-ux*1.4-px*1.4,my-uy*1.4-py*1.4,mz),green)
    end
   end
   if point then previous=point end
  end
 end
 if type(path)~="table" then return end
 local path_last=math.min(#path,nav_budget)
 for i=1,path_last do
  local point=lift(path[i])
  if point and core.graphics.circle_3d and (i==1 or i==#path or i%8==0) then core.graphics.circle_3d(point,0.65,cyan,3) end
  if i<path_last and point and core.graphics.line_3d then
   local next_point=lift(path[i+1]);if next_point then core.graphics.line_3d(point,next_point,white,3) end
  end
 end
end
return M
