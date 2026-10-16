-- Lightweight three-ray obstacle probe used only to choose a recovery side.
-- Path generation and ordinary movement remain owned by ArthasNav.
local P={}
local function valid(p)
 return type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" and type(p.z)=="number"
end
local function rotate(x,y,a)
 local c,s=math.cos(a),math.sin(a);return x*c-y*s,x*s+y*c
end
function P.escape_side(trace,origin,goal,make_vector)
 if type(trace)~="function" or not valid(origin) or not valid(goal) then return nil end
 local dx,dy=goal.x-origin.x,goal.y-origin.y;local length=math.sqrt(dx*dx+dy*dy)
 if length<0.1 then return nil end
 dx,dy=dx/length,dy/length
 local raised={x=origin.x,y=origin.y,z=origin.z+1}
 local results={}
 for _,row in ipairs({{"left",math.rad(-20)},{"center",0},{"right",math.rad(20)}}) do
  local rx,ry=rotate(dx,dy,row[2]);local endpoint={x=raised.x+rx*8,y=raised.y+ry*8,z=raised.z}
  local a=type(make_vector)=="function" and make_vector(raised.x,raised.y,raised.z) or raised
  local b=type(make_vector)=="function" and make_vector(endpoint.x,endpoint.y,endpoint.z) or endpoint
  local ok,clear=pcall(trace,a,b,0x00000001)
  if not ok or type(clear)~="boolean" then return nil end
  results[row[1]]=clear
 end
 -- Sylvanas trace_line returns true for a clear segment. Choose a side only
 -- when the probe provides an unambiguous improvement over the center ray.
 if not results.center then
  if results.left and not results.right then return "left",results end
  if results.right and not results.left then return "right",results end
 end
 return nil,results
end
return P
