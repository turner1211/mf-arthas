-- EOTS-style immutable corridor ownership; terrain comes from Sentinel.
local Progress=require("route_progress")
local M={};M.__index=M
local function valid(p)
 if not p then return false end
 for _,k in ipairs({"x","y","z"}) do local n=p[k];if type(n)~="number" or n~=n or math.abs(n)==math.huge then return false end end
 return true
end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function M.new(path,index,origin,goal)
 if type(path)~="table" or #path<2 or not valid(origin) or not valid(goal) then return nil end
 if not valid(path[#path]) or distance(path[#path],goal)>5 then return nil end
 index=tonumber(index) or 1
 if index~=index or math.abs(index)==math.huge then return nil end
 index=math.max(1,math.floor(index))
 local points={};local previous
 for i=index,#path do
  local p=path[i];if not valid(p) then return nil end
  -- Split only server-produced straight edges, never the unverified entry leg.
  if previous then
   local count=math.ceil(distance(previous,p)/12)
   if count>1000 then return nil end
   for j=1,count do local t=j/count;points[#points+1]={x=previous.x+(p.x-previous.x)*t,y=previous.y+(p.y-previous.y)*t,z=previous.z+(p.z-previous.z)*t} end
  else points[#points+1]=copy(p) end
  previous=copy(p)
  if #points>5000 then return nil end
 end
 if #points==0 then return nil end
 return setmetatable({points=points,index=1,origin=copy(origin)},M)
end
function M:next(position)
 while self.index<=#self.points do
  local radius=Progress.adaptive_radius(self.points,self.index,self.origin,2)
  -- Quest routing uses stricter floors than public BG landmark coordinates.
  local reached=math.abs(position.z-self.points[self.index].z)<=3 and
   Progress.reached(position,self.points[self.index],self.origin,radius)
  if not reached then return self.points[self.index] end
  self.origin=copy(self.points[self.index]);self.index=self.index+1
 end
 return nil
end
return M
