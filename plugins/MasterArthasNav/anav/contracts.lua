-- Arrival contracts supplement proximity; missing evidence is never success.
local C={}
function C.arrived(p,goal,opts,read)
 opts=opts or {};read=read or {}
 if not p or not goal then return false,"arrival_position_unknown" end
 for _,key in ipairs({"x","y","z"}) do
  local a,b=p[key],goal[key]
  if type(a)~="number" or type(b)~="number" or a~=a or b~=b or math.abs(a)==math.huge or math.abs(b)==math.huge then return false,"arrival_position_unknown" end
 end
 local dx,dy,dz=p.x-goal.x,p.y-goal.y,p.z-goal.z
 local radius=opts.arrival_radius or 5;local height=opts.arrival_height or 3
 if dx*dx+dy*dy>radius*radius or math.abs(dz)>height then return false,"arrival_out_of_range" end
 for _,rule in ipairs({{"expected_ui_map","ui_map"},{"expected_instance","instance"}}) do
  if opts[rule[1]]~=nil then
   if type(read[rule[2]])~="function" then return false,"arrival_context_unknown" end
   local ok,value=pcall(read[rule[2]])
   if not ok or value~=opts[rule[1]] then return false,"arrival_context_mismatch" end
  end
 end
 if opts.arrival_valid then
  local ok,value=pcall(opts.arrival_valid)
  if not ok or value~=true then return false,"arrival_objective_unverified" end
 end
 return true
end
return C
