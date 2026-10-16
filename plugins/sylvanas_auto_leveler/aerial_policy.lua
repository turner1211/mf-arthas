-- Remembers repeated aerial failures per destination and temporarily falls
-- back to Sentinel ground movement instead of retrying the same flight loop.
local M={}
local function key(goal,map)
 if not goal then return "none" end
 return table.concat({tostring(map or 0),math.floor((goal.x or 0)/20),math.floor((goal.y or 0)/20),math.floor((goal.z or 0)/8)},":")
end
function M.new(api,log)
 local self={failures=0,retry_at=0,suppressed_until=0,entries={}}
 local function select(goal)
  local value=key(goal,api.map and api.map())
  if value~=self.key then
   if self.key then self.entries[self.key]={failures=self.failures,retry_at=self.retry_at,suppressed_until=self.suppressed_until} end
   local row=self.entries[value] or {failures=0,retry_at=0,suppressed_until=0}
   self.key=value;self.failures=row.failures;self.retry_at=row.retry_at;self.suppressed_until=row.suppressed_until
   local count=0;for _ in pairs(self.entries) do count=count+1 end
   if count>32 then for old in pairs(self.entries) do if old~=value then self.entries[old]=nil;break end end end
  end
 end
 function self:can_attempt(goal)
  select(goal);local now=api.time()
  return now>=self.retry_at and now>=self.suppressed_until
 end
 function self:failed(goal,reason)
  select(goal);local now=api.time();self.failures=self.failures+1;self.retry_at=now+30
  if self.failures>=3 then
   self.suppressed_until=now+300
   if log then log("aerial_ground_fallback",{reason=reason,failures=self.failures,cooldown=300,destination=self.key}) end
  elseif log then log("aerial_retry_deferred",{reason=reason,failures=self.failures,cooldown=30,destination=self.key}) end
 end
 function self:landed(goal,pos)
  select(goal)
  local previous=self.last_landing
  if not previous or previous.key~=self.key or (previous.x-pos.x)^2+(previous.y-pos.y)^2>=2500 then
   self.last_landing={key=self.key,x=pos.x,y=pos.y}
   self.failures=0;self.retry_at=api.time()+3;self.suppressed_until=0
   if log then log("aerial_recovery_landed",{retry_seconds=3,destination=self.key}) end
  end
 end
 function self:succeeded(goal)
  select(goal);self.failures=0;self.retry_at=0;self.suppressed_until=0
 end
 function self:status(goal)
  select(goal);return {failures=self.failures,retry_at=self.retry_at,suppressed_until=self.suppressed_until,key=self.key}
 end
 return self
end
return M
