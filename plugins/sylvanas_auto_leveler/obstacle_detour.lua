-- Mesh-verified lateral/backtracking probes. Never use the server raycast.
local M={}
local GroundSafety=require('ground_safety')
local function d(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function valid(ok,points,info,goal,probe)
 if not ok or type(points)~="table" or #points<1 or #points>5000 or type(info)=="table" and info.partial then return nil end
 for _,p in ipairs(points) do
  for _,k in ipairs({"x","y","z"}) do if type(p[k])~="number" or p[k]~=p[k] or math.abs(p[k])>100000 then return nil end end
 end
 if d(points[#points],goal)>3 then return nil end
 if not GroundSafety.path_safe(points,probe) then return nil end
 return points[#points]
end
local function crosses(points,origin)
 for i=2,#points do
  local a,b=points[i-1],points[i];local dx,dy=b.x-a.x,b.y-a.y
  local den=dx*dx+dy*dy;local t=den>0 and ((origin.x-a.x)*dx+(origin.y-a.y)*dy)/den or 0
  t=math.max(0,math.min(1,t));local p={x=a.x+t*dx,y=a.y+t*dy,z=a.z+t*(b.z-a.z)}
  if d(p,origin)<3 then return true end
 end
 return false
end
function M.new(api)
 local self={epoch=0,memory={},attempts={}}
 local path="sylvanas_auto_leveler/routes/obstacle_memory.lua"
 if api.read then
  local ok,text=pcall(api.read,path)
  if ok and type(text)=="string" and #text<200000 then
   for key,x,y,z in text:gmatch("([^\n\t]+)\t([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)") do
    self.memory[key]={x=tonumber(x),y=tonumber(y),z=tonumber(z)}
   end
  end
 end
 local function key(origin,goal)
  return tostring(api.context())..":"..math.floor(origin.x/8)..":"..math.floor(origin.y/8)..":"..math.floor(origin.z/8)
    ..":"..math.floor(goal.x/20)..":"..math.floor(goal.y/20)..":"..math.floor(goal.z/8)
 end
 function self:known(origin,goal) return d(origin,goal)>12 and self.memory[key(origin,goal)]~=nil end
 function self:cancel() self.epoch=self.epoch+1;self.job=nil end
 function self:tick()
  local job=self.job
  if job and api.time()>job.deadline then job.sequence=job.sequence+1;job.next() end
 end
 function self:plan(origin,goal,callback)
  self:cancel();local epoch=self.epoch
  if d(origin,goal)<=12 then callback(nil,"detour_not_needed_for_close_approach");return end
  local dx,dy=goal.x-origin.x,goal.y-origin.y;local length=math.sqrt(dx*dx+dy*dy)
  if length<1 then callback(nil,"vertical_detour_unavailable");return end
  local ux,uy=dx/length,dy/length;local candidates={}
  local attempt_key=key(origin,goal)
  local batch=self.attempts[attempt_key] or 0
  self.attempts[attempt_key]=math.min(batch+1,3)
  local radii=({{8,16},{24,32},{40,48},{56,64}})[math.min(batch+1,4)]
  local remembered=self.memory[key(origin,goal)]
  if remembered then candidates[#candidates+1]=remembered end
  for _,radius in ipairs(radii) do
   for _,angle in ipairs({math.pi/2,-math.pi/2,math.pi*.75,-math.pi*.75,math.pi}) do
    candidates[#candidates+1]={x=origin.x+(ux*math.cos(angle)-uy*math.sin(angle))*radius,
      y=origin.y+(uy*math.cos(angle)+ux*math.sin(angle))*radius,z=origin.z}
   end
  end
  local job={index=0,sequence=0,deadline=api.time()+3};self.job=job
  local function finish(points,reason)
   if epoch~=self.epoch or self.job~=job then return end
   self.job=nil;callback(points,reason)
  end
  local function request(from,to,done)
   job.sequence=job.sequence+1;local sequence=job.sequence;job.deadline=api.time()+3
   local ran=pcall(api.find,from,to,function(ok,points,info)
    if epoch~=self.epoch or self.job~=job or sequence~=job.sequence then return end
    job.sequence=job.sequence+1;done(ok,points,info)
   end)
   if not ran and sequence==job.sequence then job.sequence=job.sequence+1;job.next() end
  end
  job.next=function()
   if epoch~=self.epoch or self.job~=job then return end
   job.index=job.index+1
   local candidate=candidates[job.index]
   if not candidate then finish(nil,"no_verified_detour");return end
   if api.floor then
    local ok,z=pcall(api.floor,candidate)
    if not ok or type(z)~='number' or z~=z or math.abs(z)==math.huge then job.next();return end
    candidate={x=candidate.x,y=candidate.y,z=z}
   end
   if api.log then api.log("obstacle_detour_probe",{index=job.index,x=candidate.x,y=candidate.y,z=candidate.z}) end
   request(origin,candidate,function(ok,first,info)
    local endpoint=valid(ok,first,info,candidate,api.floor)
    if not endpoint then job.next();return end
    request(endpoint,goal,function(found,second,detail)
     if not valid(found,second,detail,goal,api.floor) or crosses(second,origin) then job.next();return end
     local points={};for _,p in ipairs(first) do points[#points+1]=p end
     for _,p in ipairs(second) do if #points==0 or d(points[#points],p)>.1 then points[#points+1]=p end end
     -- Save only a connected detour, never a failed speculative direction.
     self.memory[key(origin,goal)]={x=endpoint.x,y=endpoint.y,z=endpoint.z}
     self.attempts[attempt_key]=nil
     if api.write then
      local rows={};for k,p in pairs(self.memory) do rows[#rows+1]=k.."\t"..string.format("%.6f,%.6f,%.6f",p.x,p.y,p.z) end
      table.sort(rows);while #rows>256 do table.remove(rows,1) end
      pcall(api.write,path,table.concat(rows,"\n"))
     end
     finish(points,"verified_detour")
    end)
   end)
  end
  job.next()
 end
 return self
end
return M
