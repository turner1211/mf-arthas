local A={};A.__index=A
local function copy(p)return{x=p.x,y=p.y,z=p.z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)end
function A.new()return setmetatable({},A)end
function A:reset()self.goal=nil;self.best=nil;self.since=nil;self.position=nil end
function A:stalled(position,goal,now,timeout,min_gain)
 timeout=math.max(1,tonumber(timeout) or 10);min_gain=math.max(0.25,tonumber(min_gain) or 1)
 local remaining=distance(position,goal)
 if not self.goal or distance(self.goal,goal)>4 or not self.since or now<self.since then
  self.goal=copy(goal);self.best=remaining;self.since=now;self.position=copy(position);return false
 end
 if remaining<=self.best-min_gain then
  self.best=remaining;self.since=now;self.position=copy(position);return false
 end
 self.position=copy(position)
 if now-self.since>=timeout then self.since=now;self.best=remaining;return true end
 return false
end
return A
