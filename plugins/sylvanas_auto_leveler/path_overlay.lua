local Nav=require("navigation")
local Color=require("common/color")
local M={enabled=true}
local line=Color.new(50,210,255,210)
local halo=Color.new(50,210,255,50)
local next_color=Color.new(255,210,60,220)
local flight_line=Color.new(170,110,255,220)
local flight_halo=Color.new(170,110,255,55)
local function raised(p,aerial) return {x=p.x,y=p.y,z=p.z+(aerial and 400 or 3)} end
local function valid(p)
 if not p then return false end
 for _,key in ipairs({"x","y","z"}) do
  local v=p[key];if type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return false end
 end
 return true
end
local function arrow(a,b,col)
 local dx,dy=b.x-a.x,b.y-a.y;local length=math.sqrt(dx*dx+dy*dy)
 if length<2 then return end
 local size=math.min(1.8,length*.2);local ux,uy=dx/length,dy/length
 local tip={x=a.x+dx*.65,y=a.y+dy*.65,z=a.z+(b.z-a.z)*.65}
 for _,side in ipairs({-1,1}) do
  core.graphics.line_3d({x=tip.x-ux*size-uy*size*.55*side,y=tip.y-uy*size+ux*size*.55*side,z=tip.z},tip,col,2,1,false)
 end
end
function M.draw(active,aerial,aerial_points,aerial_index)
 if not M.enabled or not active then return end
 local client=Nav.client()
 local points,index
 if type(aerial_points)=="table" and #aerial_points>0 then
  points,index=aerial_points,aerial_index or 1
 else
  if not client or type(client.get_current_path)~="function" then return end
  points=client:get_current_path();if not points then return end
  index=type(client.get_path_index)=="function" and client:get_path_index() or 1
 end
 if type(points)~="table" then return end
 index=tonumber(index) or 1
 if index~=index or index==math.huge or index==-math.huge then index=1 end
 index=math.max(1,math.floor(index))
 -- World-space circles and arrowheads are expensive render primitives. Keep
 -- the useful near corridor visible while bounding work on very long paths.
 local last=math.min(#points,index+49)
 local sparse=#points-index>49
 for i=index,last do
  local p=points[i]
  if valid(p) then
   local display=raised(p,aerial)
   local route_color=aerial and flight_line or line
   if not sparse or i==index or (i-index)%5==0 then
    core.graphics.circle_3d_filled(display,aerial and 1.5 or 0.6,aerial and flight_halo or halo)
   end
   core.graphics.circle_3d(display,aerial and 1.5 or 0.6,i==index and next_color or route_color,2,1)
   if i<last and valid(points[i+1]) then
    local next_point=raised(points[i+1],aerial)
    core.graphics.line_3d(display,next_point,route_color,2,1,false)
    if (i-index)%4==0 then arrow(display,next_point,route_color) end
   end
  end
 end
end
return M
