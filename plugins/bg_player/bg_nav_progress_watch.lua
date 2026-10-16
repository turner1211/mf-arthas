-- Detect a live Sentinel route which stays on the same waypoint even when
-- small position changes prevent the ordinary distance watchdog from firing.
local W={};W.__index=W
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function number(v) v=tonumber(v);return finite(v) and v or nil end
local function ignored(state)
 state=tostring(state or ""):lower()
 return state:find("awaiting_path",1,true) or state:find("planning",1,true) or
  state:find("recover",1,true) or state:find("avoid",1,true) or
  state=="idle" or state=="arrived" or state=="failed"
end
function W.new(timeout,max_replans)
 return setmetatable({timeout=tonumber(timeout) or 6,max_replans=tonumber(max_replans) or 2},W)
end
function W:reset(clear_budget)
 self.token=nil;self.goal=nil;self.since=nil;self.fired=nil
 if clear_budget then self.replans=0 end
end
function W:observe(progress,state,goal,now)
 now=number(now)
 if not now or ignored(state) or type(progress)~="table" or type(goal)~="table" then
  self:reset(false);return false
 end
 local index=number(progress.current_index)
 local remaining=number(progress.waypoints_remaining)
 local total=number(progress.total_waypoints)
 local percent=number(progress.percent)
 local gx,gy,gz=number(goal.x),number(goal.y),number(goal.z)
 if not index or not remaining or not total or total<1 or index<0 or remaining<0 or
  not gx or not gy or not gz then self:reset(false);return false end
 percent=percent and math.max(0,math.min(1,percent)) or 0
 local goal_key=string.format("%.1f:%.1f:%.1f",gx,gy,gz)
 -- Quantize percentage so harmless floating-point noise cannot mask a stall.
 local token=string.format("%d:%d:%d:%d",math.floor(index+.5),math.floor(remaining+.5),
  math.floor(total+.5),math.floor(percent*100+.5))
 if self.goal~=goal_key or self.token~=token or not self.since or now<self.since then
  self.goal=goal_key;self.token=token;self.since=now;self.fired=false;return false
 end
 if not self.fired and now-self.since>=self.timeout and (self.replans or 0)<self.max_replans then
  self.fired=true;self.replans=(self.replans or 0)+1
  return true,{index=index,remaining=remaining,total=total,percent=percent,attempt=self.replans}
 end
 return false
end
return W
