local P={};P.__index=P
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function P.new() return setmetatable({},P) end
function P:reset() self.origin=nil;self.goal=nil;self.since=nil;self.moved=false end
function P:stalled(pos,goal,now,timeout,min_move)
 timeout=tonumber(timeout) or 7
 min_move=tonumber(min_move) or 1
 if not self.origin or distance(self.goal,goal)>4 or now<self.since or distance(self.origin,pos)>=min_move then
  self.moved=self.origin~=nil and distance(self.origin,pos)>=min_move
  self.origin=copy(pos);self.goal=copy(goal);self.since=now;return false
 end
 self.moved=false
 if now-self.since>=timeout then self.since=now;return true end
 return false
end
return P
