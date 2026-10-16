local Routes=require("bc_routes")
local Rewards=require("bc_rewards")
local M={};M.__index=M
function M.new(api)
 return setmetatable({api=api,enabled=false,state="Stopped",index=1,epoch=0,log={},runs=0,options={repeat_run=false,max_runs=1,auto_exit=false,combat_hold=true,auto_loot=true,spend_key=false,tier=8},events={}},M)
end
function M:note(s) self.state=s;self.log[#self.log+1]=s;if #self.log>60 then table.remove(self.log,1) end end
function M:stop(reason)
 self.enabled=false;self.pending_route=nil;self.epoch=self.epoch+1;self.moving=false;self.arrived=false;if self.reward_job then self.reward_job:stop();self.reward_job=nil end;self.api.stop();self:note(reason or "Stopped")
end
function M:switch(route)
 local ok,why=Routes.validate(route);if not ok then return false,why end
 if not self.enabled or not self.api.snapshot().inside then return self:start(route) end
 self.pending_route=route;self:note("Delve change queued: finish this run, then travel to "..route.name);return true
end
function M:start(route)
 local ok,why=Routes.validate(route);if not ok then self:note(why);return false,why end
 if self.api.reset_bridge then self.api.reset_bridge() end
 self:stop();self.route=route;self.index=1;self.runs=0;self.started=self.api.now();self.events={};self.enter_attempts=0;self.exit_attempts=0;self.enter_at=nil;self.exit_at=nil;self.entry_deadline=nil;self.was_inside=nil;self.hold_started=nil;self.step_started=nil;self.completed=false;self.enabled=true;self:note("Starting expedition");return true
end
function M:event(name,args)
 if not self.enabled then return end
 self.events[name]=(self.events[name] or 0)+1
 if self.reward_job then self.reward_job:event(name,args) end
end
function M:move(p)
 if self.arrived then return true end
 if self.moving then return false end
 local epoch=self.epoch;self.moving=true
 local accepted=self.api.move(p,function(ok,reason)
  if self.epoch~=epoch or not self.enabled then return end
  self.moving=false
  if ok then self.arrived=true else self:stop("Navigation failed: "..tostring(reason)) end
 end)
 if accepted==false and self.enabled then self:stop("Navigation request refused") end
 return self.arrived
end
function M:advance()
 self.epoch=self.epoch+1;self.api.stop();self.index=self.index+1;self.arrived=false;self.moving=false;self.step_started=nil;self.interaction_at=nil;self.target_seen=nil;self.kill_guid=nil;self.interaction_guid=nil
end
function M:tick()
 if not self.enabled then return end
 local a=self.api;local now=a.now();local snap=a.snapshot()
 if not snap.ready then self:stop("Character unavailable");return end
 if snap.dead then self:stop("Death: resume after resurrection");return end
 if snap.combat and self.options.combat_hold then
  if self.reward_job and self.reward_job.moving then self.reward_job:stop() end
  if self.moving then self.epoch=self.epoch+1;a.stop();self.moving=false;self.arrived=false end
  self.hold_started=self.hold_started or now;self.state="Combat plugin active";return
 end
 if self.hold_started then
  local dt=now-self.hold_started;self.started=self.started+dt;if self.step_started then self.step_started=self.step_started+dt end
  if self.reward_job then local j=self.reward_job;if j.started then j.started=j.started+dt end;if j.sent then j.sent=j.sent+dt end;if j.quiet_since then j.quiet_since=j.quiet_since+dt end end
  self.hold_started=nil
 end
 if now-self.started>3600 then self:stop("Run timeout");return end
 local r=self.route
 if self.completed then
  if snap.inside then
   if self.options.auto_loot and a.rewards then
    self.reward_job=self.reward_job or Rewards.new(a,self.options.spend_key)
    local result,why=self.reward_job:tick();self.state=self.reward_job.state
    if result==false then self:stop(why);return end
    if result~=true then return end
   end
   if not self.options.auto_exit then self.state="Complete: collect rewards, then exit";return end
   if now>=(self.exit_at or 0) then
    if self.exit_attempts>=3 then self:stop("Exit timeout");return end
    local ok,why=a.exit();if ok==false then self:stop(why or "Exit refused");return end;self.exit_at=now+10;self.exit_attempts=self.exit_attempts+1
   end
   return
  end
  self.runs=self.runs+1
  if self.pending_route then local next_route=self.pending_route;self.pending_route=nil;self:start(next_route);return end
  if self.options.repeat_run and (self.options.max_runs==0 or self.runs<self.options.max_runs) then
   if a.reset_bridge then a.reset_bridge() end
   self.index=1;self.arrived=false;self.completed=false;self.was_inside=nil;self.enter_at=nil;self.exit_at=nil;self.entry_deadline=nil;self.enter_attempts=0;self.exit_attempts=0;self.step_started=nil;self.started=now;self.events={};self.reward_job=nil;self:note("Next run")
  else self:stop("Expedition finished") end
  return
 end
 if not snap.inside then
  if self.was_inside then self:stop("Unexpected instance exit");return end
  if snap.map~=r.entrance_map then self:stop("Travel to the route entrance map first");return end
  self.state="Travelling to entrance"
  if self:move(r.entrance) then
   self.state="Entering delve"
   if a.prepare_entry then
    self.entry_deadline=self.entry_deadline or now+60
    local ready,why=a.prepare_entry(r.instance,self.options.tier)
    if ready==false then self:stop(why);return end
    if ready~=true then self.state="Tier bridge: "..tostring(why);if now>=self.entry_deadline then self:stop("Tier bridge timeout: load the WoW bridge Lua") end;return end
   end
   if now>=(self.enter_at or 0) then
    if self.enter_attempts>=3 then self:stop("Entry timeout: check entrance and tier selection");return end
    local ok,why=a.enter();if ok==false then self:stop(why or "Entry refused");return end;self.enter_at=now+10;self.enter_attempts=self.enter_attempts+1
   end
  end
  return
 end
 if not self.was_inside then self.was_inside=true;self.arrived=false;self.moving=false;self.epoch=self.epoch+1;a.stop() end
 if snap.map~=r.map then self:stop("Instance map does not match route");return end
 if r.instance and snap.instance~=r.instance then self:stop("Instance identity does not match route");return end
 if r.scenario_id and a.scenario then
  local live=a.scenario()
  if not live then self.state="Waiting for exact scenario snapshot";return end
  if live.scenario_id~=r.scenario_id then self:stop("Story scenario does not match route");return end
 end
 if snap.complete then self.completed=true;self.epoch=self.epoch+1;a.stop();self.moving=false;self:note("Delve complete");return end
 local s=r.steps[self.index]
 if not s then self.state="Awaiting native delve completion";return end
 if not self.step_started then self.step_started=now;self.event_origin=s.event and (self.events[s.event] or 0) or 0 end
 if now-self.step_started>(s.timeout or 120) then self:stop("Step timeout: "..self.index);return end
 self.state=string.format("Step %d/%d: %s",self.index,#r.steps,s.kind)
 if s.kind=="wait" then
  if (self.events[s.event] or 0)>self.event_origin then self:advance() end;return
 end
 if s.kind=="interact" and self.interaction_at then
  local confirmed=s.confirm=="unusable" and a.usable and a.usable(self.interaction_guid)==false
  if s.confirm=="criterion" and a.criterion then local c=a.criterion(s.stage_id,s.criterion_id);confirmed=c and c.complete==true and not c.failed or false end
  if s.event and (self.events[s.event] or 0)>self.event_origin then confirmed=true end
  if confirmed then self:advance();return end
 end
 if s.kind=="kill" and self.kill_guid and a.dead(self.kill_guid) then self:advance();return end
 if not self:move(s.position) then return end
 if s.kind=="move" then self:advance();return end
 local object,distance,live_position=a.object(s.object_id,s.position,s.kind=="kill")
 if not object then self.state="Waiting for recorded object "..s.object_id;return end
 if distance>4 then
  if live_position then self.arrived=false;self:move(live_position);self.state="Approaching recorded object" else self.state="Recorded object outside interaction range" end
  return
 end
 if s.kind=="kill" then self.kill_guid=a.guid(object);local ok,why=a.target(object);if ok==false then self:stop(why);return end;self.state="Target handed to combat plugin";return end
 if not self.interaction_at or now-self.interaction_at>=4 then
  if not self.interaction_at then self.event_origin=s.event and (self.events[s.event] or 0) or 0 end
  local ok,why=a.interact(object);if not ok then self:stop(why);return end
  self.interaction_at=now;self.interaction_guid=a.guid(object)
 end
end
return M
