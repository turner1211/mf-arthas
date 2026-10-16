-- Per-context, per-start/goal recovery budget; no movement is issued here.
local M={}
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function M.new()
 local self={entries={}}
 function self:prepare(context,start,goal,now)
  for i=#self.entries,1,-1 do if self.entries[i].expires<=now then table.remove(self.entries,i) end end
  for _,e in ipairs(self.entries) do
   if e.context==context and distance(e.start,start)<12 and distance(e.goal,goal)<4 then
    if e.exhausted and now>=(e.retry_at or 0) then e.exhausted=nil;e.failures=0;e.detours=0;e.cause=nil end
    return e
   end
  end
  local e={context=context,start={x=start.x,y=start.y,z=start.z},goal={x=goal.x,y=goal.y,z=goal.z},failures=0,detours=0,expires=now+600}
  self.entries[#self.entries+1]=e;if #self.entries>32 then table.remove(self.entries,1) end;return e
 end
 function self:result(e,ok,reason,now)
  if ok then e.blocked_at=nil;e.failures=0;e.detours=0;e.exhausted=nil;e.cause=nil;return end
  local cause=require('travel_decisions').failure(reason)
  if cause=="terrain" or cause=="elevation" then e.blocked_at=now end
  if cause~='terrain' and cause~='elevation' and cause~='service' then return end
  e.cause=cause;e.failures=e.failures+1;e.expires=now+600

 end
 function self:ground_blocked(context,start,goal,now)
  for _,e in ipairs(self.entries) do
   if e.context==context and e.blocked_at and now-e.blocked_at<120
      and distance(e.start,start)<12 and distance(e.goal,goal)<4 then return true end
  end
  return false
 end
 function self:exhausted(e)
  return (e.cause=='terrain' or e.cause=='elevation') and e.detours>=2 and e.failures>=3
 end
 function self:detour(e)
  if (e.cause=='terrain' or e.cause=='elevation') and e.failures>0 and e.detours<2 then e.detours=e.detours+1;return true end
  return false
 end
 return self
end
return M
