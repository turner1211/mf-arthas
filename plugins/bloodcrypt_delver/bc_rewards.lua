-- Completion is not permission to leave before loot has settled.
local M={};M.__index=M
local function transient(reason)
 reason=tostring(reason or ""):lower()
 return reason:find("owner",1,true) or reason:find("lease",1,true) or reason:find("busy",1,true) or reason:find("dismount",1,true) or reason:find("current cast",1,true)
end
function M.new(api,allow_key,options)
 options=type(options)=="table" and options or {}
 local budget=type(allow_key)=="number" and math.max(0,math.floor(allow_key)) or allow_key and 1 or 0
 return setmetatable({api=api,key_budget=budget,done={},epoch=0,state="Scanning rewards",timeout=math.max(60,math.min(900,tonumber(options.timeout) or 180)),settle=math.max(5,math.min(30,tonumber(options.settle) or 8))},M)
end
function M:stop() self.epoch=self.epoch+1;self.api.stop();self.moving=false end
function M:event(event,args)
 if not self.sent then return end
 if event=="LOOT_OPENED" then self.opened=true
 elseif event=="LOOT_CLOSED" and self.opened then self.closed=true
 elseif event=="LOOT_BIND_CONFIRM" and self.opened and args and tonumber(args[1]) then self.api.confirm_loot(tonumber(args[1])-1) end
end
function M:tick()
 local a=self.api;local now=a.now()
 if not self.started then self.started=now end
 if now-self.started>self.timeout then return false,"Reward collection timeout" end
 if self.current then
  if self.error then return false,self.error end
  if not self.arrived then
   if not self.moving and now>=(self.retry_at or 0) then
    self.moving=true;local epoch=self.epoch;local r=a.move(self.current.position,function(ok,why)
     if self.epoch~=epoch then return end;self.moving=false;self.arrived=ok;if not ok and transient(why) then self.retry_at=a.now()+2;self.state="Reward navigation paused: "..tostring(why) else self.error=not ok and "Reward path: "..tostring(why) or nil end
    end)
    if r==false and not self.error and not self.retry_at then self.move_refusals=(self.move_refusals or 0)+1;if self.move_refusals>=5 then self.error="Reward navigation repeatedly refused" else self.retry_at=now+2;self.moving=false;self.state="Reward navigation retry "..self.move_refusals.."/5" end end
   end
   return nil
  end
  if not self.sent then
   if now<(self.retry_at or 0) then return nil end
   local ok,why=a.interact_guid(self.current.guid);if not ok then if transient(why) then self.retry_at=now+1;self.state="Reward interaction paused: "..tostring(why);return nil end;return false,why end
   if self.current.requires_key then self.key_budget=math.max(0,self.key_budget-1) end
   self.sent=now;self.state="Opening "..self.current.name;return nil
  end
  local count=a.loot_count()
  if count>0 then
   if now>=(self.next_loot or 0) then local ok,why=a.loot_slot(0);if not ok then return false,why end;self.next_loot=now+0.5 end
   return nil
  end
  -- A closed loot window after our dispatch is evidence; a lost object alone is not.
  if self.opened and self.closed and count==0 then
   self.done[self.current.guid]=true;self.confirmed=(self.confirmed or 0)+1;self.current=nil;self.sent=nil;self.opened=nil;self.closed=nil;self.arrived=nil;self.retry_at=nil;self.move_refusals=nil;self.quiet_since=nil;a.stop();return nil
  end
  if now-self.sent>15 then return false,"No confirmed reward loot for "..self.current.name end
  return nil
 end
 for _,r in ipairs(a.rewards(self.key_budget>0)) do if not self.done[r.guid] and (not r.requires_key or self.key_budget>0) then self.current=r;self.quiet_since=nil;return nil end end
 self.quiet_since=self.quiet_since or now
 if now-self.quiet_since>=self.settle and (self.confirmed or 0)>0 then self.state="Reward scan settled";return true end
 if (self.confirmed or 0)==0 then self.state="Waiting for identifiable reward chests" end
 return nil
end
return M
