local Catalog=require("bc_catalog")
local Plans=require("bc_story_plans")
local Rewards=require("bc_rewards")
local Learning=require("bc_learning")
local NemesisRuntime=require("bc_nemesis_runtime")
local RunMemory=require("bc_run_memory")
local LevelProfile=require("bc_level_profile")
local M={};M.__index=M
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1000000 end
local function family(name) return tostring(name or "objective"):lower():gsub("[^%w]","_"):sub(1,120) end
local function transient(reason)
 reason=tostring(reason or ""):lower()
 for _,word in ipairs({"owner","lease","busy","dismount","current cast","cancelled","priority_preempted","client_reloaded","transport_busy","server_timeout","server_down","query_timeout","query_queue_timeout","query_queue_full","map_not_loaded","map_tile_missing","map_tiles_missing","map_context_mismatch","readiness_timeout","http_unavailable","bridge_upgrade_required","version_mismatch","start_off_mesh","route_start_disconnected","player_unavailable","arrival_context_unknown","arrival_context_mismatch","navigation_start_failed","destination_stale","destination_expired","target_lost"}) do
  if reason:find(word,1,true) then return true end
 end
 return false
end
local function contact_name(name)
 name=tostring(name or ""):lower()
 return name:find("focus crystal",1,true) or name:find("ley line focuser",1,true) or name:find("focuser socket",1,true)
end
local OPTIONAL_OBJECTS={"campfire","refulgent copper","copper vein","ore deposit","mining deposit","herb","fishing","skinning","leave delve","the darkway","sturdy chest","explorers' league supplies","explorer's league supplies","delver's supplies","delvers' supplies","valeera sanguinar","corner piece","doodad_","bountiful coffer","delve trunk","gilded stash","nemesis supplies"}
local function optional_object(name)
 name=tostring(name or ""):lower()
 for _,word in ipairs(OPTIONAL_OBJECTS) do if name:find(word,1,true) then return true end end
 return false
end
local function remember(self,kind,guid)
 if self.options.objective_memory~=false then return RunMemory.mark(kind,guid) end
 return true
end
function M.new(api)
 return setmetatable({api=api,enabled=false,state="Stopped",index=0,runs=0,log={},options={repeat_run=true,max_runs=0,auto_exit=true,combat_hold=true,auto_level=true,auto_loot=true,spend_key=false,tier=8,key_reserve=1,max_pull=5,recover_death=true,learning=true,auto_mount=true,prefer_flying=true},epoch=0,blocked={},nemesis=NemesisRuntime.new()},M)
end
function M:note(s)
 if self.state==s then return end
 self.state=s;self.log[#self.log+1]=s;if #self.log>60 then table.remove(self.log,1) end
 if self.logger then self.logger.record(self.api.now(),"state",{state=s,delve=self.selected or 0,variant=self.variant or 0,runs=self.runs or 0}) end
end
function M:clear_motion() self.epoch=self.epoch+1;self.moving=false;self.arrived=false;self.goal=nil;self.goal_block_key=nil;self.move_started=nil;self.api.stop() end
function M:observe_managed_motion(now,snap,nav)
 local percent=tonumber(nav and nav.percent) or 0;local index=tonumber(nav and nav.index) or 0
 local marker=tostring(index)..":"..string.format("%.2f",percent);local progressed=marker~=self.nav_progress_marker
 local pos=snap and snap.position
 if pos and self.last_motion_position then
  local dx,dy,dz=pos.x-self.last_motion_position.x,pos.y-self.last_motion_position.y,pos.z-self.last_motion_position.z
  if math.sqrt(dx*dx+dy*dy+dz*dz)>.55 then progressed=true end
 end
 if progressed then
  self.nav_progress_marker=marker;self.last_motion_at=now;self.nav_transient_failures=0
  if pos then self.last_motion_position={x=pos.x,y=pos.y,z=pos.z} end
  return true
 end
 if pos and not self.last_motion_position then self.last_motion_position={x=pos.x,y=pos.y,z=pos.z};self.last_motion_at=now;return true end
 local state=tostring(nav and nav.state or ""):lower();local recovering=state:find("recover",1,true) or state:find("repath",1,true)
 local timeout=recovering and 20 or 12
 if now-(self.last_motion_at or now)<=timeout then return true end
 local key=self.goal_block_key or self.goal and (tostring(self.goal.x)..":"..tostring(self.goal.y))
 local goal=self.goal;self:clear_motion();self.stuck_retries=(self.stuck_retries or 0)+1
 local delay=math.min(8,2^(self.stuck_retries-1));self.nav_retry_at=now+delay
 if key then self.blocked[key]=now+math.min(45,15+self.stuck_retries*5) end
 if self.logger then self.logger.record(now,"managed_nav_stall",{state=state,index=index,percent=percent,seconds=timeout,retry=self.stuck_retries,backoff=delay,x=goal and goal.x or 0,y=goal and goal.y or 0,z=goal and goal.z or 0}) end
 if self.stuck_retries>3 then self:stop("Managed navigation recovery exhausted; inspect live debugger") else self:note("Managed route stalled; rescanning after recovery "..self.stuck_retries) end
 return false
end
function M:stop(reason)
 self.enabled=false;self.pending_id=nil;self:clear_motion();if self.reward_job then self.reward_job:stop();self.reward_job=nil end;self:note(reason or "Stopped")
end
function M:start(id,variant,resume)
 if not Catalog[id] then return false,"Invalid delve" end
 self:stop();self.selected=id;self.variant=variant or 1;self.runs=0;self.started=self.api.now();self.progress_at=self.started;self.enabled=true;self.completed=false;self.was_inside=false;self.enter_attempts=0;self.enter_at=nil;self.entry_deadline=nil;self.entry_arrived_at=nil;self.exit_attempts=0;self.exit_at=nil;self.nav_retry_at=nil;self.resolve_pending=false;self.signature=nil;self.interaction=nil;self.local_interaction=nil;self.local_prepare=nil;self.combat_move_guid=nil;self.combat_target_guid=nil;self.combat_last_position=nil;self.combat_seen_at=nil;self.combat_repath_at=nil;self.blocked={};self.failed_ids={};self.completed_guids={};self.family_refusals={};self.quarantined_families={};self.candidate_log_at={};self.index=0;self.stuck_retries=0;self.death_since=nil;self.loading_since=nil;self.nemesis:reset()
 self.nav_retry_at=nil;self.nav_transient_failures=0;self.nav_progress_marker=nil
 self.entry_interaction_complete=false
 local instance=Catalog[id].instance
 local done,quarantined,families
 if resume and self.options.objective_memory~=false then done,quarantined,families=RunMemory.load(instance) else done,quarantined,families=RunMemory.reset(instance) end
 for guid in pairs(done) do self.completed_guids[guid]=true;self.blocked[guid]=math.huge;if guid:match("^Creature%-") then self.entry_interaction_complete=true end end
 for guid in pairs(quarantined) do self.blocked[guid]=math.huge end
 for name in pairs(families) do self.quarantined_families[name]=true end
 self:note((resume and "Resuming " or "Travelling to ")..Catalog[id].name);return true
end
function M:switch(id)
 if not Catalog[id] then return false,"Invalid delve" end
 if not self.enabled then return self:start(id,1) end
 if self.api.snapshot().inside then self.pending_id=id;self:note("Next delve queued: "..Catalog[id].name);return true end
 return self:start(id,1)
end
function M:event(name,args) if self.enabled and self.reward_job then self.reward_job:event(name,args) end end
function M:move(p,label,block_key,frontier_distance,request)
 if self.moving then return false end
 if self.api.now()<(self.nav_retry_at or 0) then self.state="Navigation ownership cooldown";return false end
 if self.options.hazard_avoidance~=false and self.api.goal_safe then local safe,why=self.api.goal_safe(p);if safe==false then if block_key then self.blocked[block_key]=self.api.now()+20 end;self:note(why or "Unsafe navigation destination");if self.logger then self.logger.record(self.api.now(),"move_rejected_hazard",{label=label or "Navigating",x=p.x,y=p.y,z=p.z,reason=why or "unsafe"}) end;return false end end
 local snap=self.api.snapshot();local dist
 if snap.position then local dx,dy,dz=p.x-snap.position.x,p.y-snap.position.y,p.z-snap.position.z;dist=math.sqrt(dx*dx+dy*dy+dz*dz) end
 local level=self.level_profile
 if self.options.auto_mount and (not level or level.mount) and not snap.dead and dist and dist>35 and self.api.prepare_mount then
  local ready,status=self.api.prepare_mount(dist,self.options.prefer_flying and (not level or level.flying))
  if ready~=true then self.state=status or "Preparing mount";return ready~=false end
 end
 local epoch=self.epoch;self.moving=true;self.goal=p;self.goal_block_key=block_key;self.move_started=self.api.now();self.last_motion_position=nil;self.last_motion_at=self.move_started;self:note(label or "Navigating")
 local callback_transient=false
 local accepted=self.api.move(p,function(ok,reason)
  if epoch~=self.epoch or not self.enabled then return end
  self.moving=false;if self.logger then self.logger.record(self.api.now(),"move_result",{ok=ok==true,reason=reason or "",x=p.x,y=p.y,z=p.z}) end
  if ok then self.arrived=true;self.stuck_retries=0;self.nav_transient_failures=0;if frontier_distance then self.frontier_distance=math.max(self.frontier_distance or 0,frontier_distance) end
  else callback_transient=transient(reason);if callback_transient then self.nav_transient_failures=(self.nav_transient_failures or 0)+1;local delay=math.min(16,2^self.nav_transient_failures);self.nav_retry_at=self.api.now()+delay;self:note("Navigation paused: "..tostring(reason).." / retry in "..delay.."s") else self.nav_transient_failures=0;self.blocked[tostring(p.x)..":"..tostring(p.y)]=self.api.now()+30;if block_key then self.blocked[block_key]=self.api.now()+45 end;self:note("Path unavailable: "..tostring(reason)) end end
 end,request)
 if accepted==false then self.moving=false;if not callback_transient then if block_key then self.blocked[block_key]=self.api.now()+45 end;self:note("Navigation request refused") end end
 if self.logger then self.logger.record(self.api.now(),"move_request",{accepted=accepted~=false,label=label or "Navigating",x=p.x,y=p.y,z=p.z}) end
 return accepted~=false
end
function M:resolve(ui,x,y,label)
 if self.resolve_pending or self.moving then return end;self.resolve_pending=true
 local epoch=self.epoch
 self.api.resolve_map_point(ui,x,y,function(ok,p,why)
  if epoch~=self.epoch or not self.enabled then return end
  self.resolve_pending=false
  if not ok then self:note(tostring(p));return end
  local key=tostring(p.x)..":"..tostring(p.y);if (self.blocked[key] or 0)>self.api.now() then return end
  self.arrived=false;self:move(p,label)
 end)
end
function M:reset_run(now)
 self:clear_motion();self.completed=false;self.was_inside=false;self.started=now;self.progress_at=now;self.enter_attempts=0;self.enter_at=nil;self.entry_deadline=nil;self.entry_arrived_at=nil;self.exit_attempts=0;self.exit_at=nil;self.signature=nil;self.interaction=nil;self.local_interaction=nil;self.local_prepare=nil;self.combat_move_guid=nil;self.combat_target_guid=nil;self.combat_last_position=nil;self.combat_seen_at=nil;self.combat_repath_at=nil;self.reward_job=nil;self.blocked={};self.failed_ids={};self.completed_guids={};self.family_refusals={};self.quarantined_families={};self.index=0;self.stuck_retries=0;self.death_since=nil;self.loading_since=nil;self.nemesis:reset()
 self.nav_retry_at=nil;self.nav_transient_failures=0;self.nav_progress_marker=nil
 self.entry_interaction_complete=false
 if self.api.reset_bridge then self.api.reset_bridge() end
 RunMemory.reset(Catalog[self.selected] and Catalog[self.selected].instance or 0)
end
function M:tick()
 if not self.enabled then return end
 local a=self.api;local now=a.now();local snap=a.snapshot();local delve=Catalog[self.selected]
 local character=a.character and a.character() or {};local profile=LevelProfile.get(character,self.options)
 if self.options.auto_level==false then profile.max_pull=self.options.max_pull or 5;profile.approach_range=4.5;profile.mount=true;profile.flying=true end
 self.level_profile=profile
 _G.BloodcryptCombatContext={level=profile.level,bracket=profile.name,role=profile.role,spec_id=profile.spec_id,rotation=profile.rotation,approach_range=profile.approach_range,max_pull=profile.max_pull,delve=self.selected,story=self.variant,state=self.state,updated_at=now}
 local detected,label
 if self.options.auto_story~=false and a.detect_story then detected,label=a.detect_story(delve) end
 if detected and detected~=self.variant then self.variant=detected;self:note("Detected story: "..tostring(label)) end
 if not snap.ready then self.loading_since=self.loading_since or now;if now-self.loading_since>90 then self:stop("Character/loading timeout") else self.state="Loading: preserving verified run state" end;return else self.loading_since=nil end
 if snap.dead then
  local first_death=not self.death_since;self.death_since=self.death_since or now;if first_death and self.moving then self:clear_motion() end
  if not self.options.recover_death or now-self.death_since>180 then self:stop("Death recovery timeout")
  elseif a.recover_death then local ok,why,corpse=a.recover_death(snap);if ok==false and not transient(why) then self:stop(why or "Death recovery unavailable") else if corpse and not self.moving then self:move(corpse,"Death recovery: returning to corpse","corpse") end;self.state=why or "Waiting for resurrection" end
  else self.state="Waiting for resurrection" end;return
 elseif self.death_since then if self.moving then self:clear_motion() end;self.death_since=nil;self.combat_move_guid=nil;self.combat_target_guid=nil;self.combat_last_position=nil;self.combat_seen_at=nil;self.combat_orphan_since=now;self.progress_at=now;self:note("Resurrected: rescanning current objective") end
 if snap.vehicle then if self.moving then self:clear_motion() end;self.state="Vehicle active: waiting for supported objective controls";return end
 local threat=self.options.combat_hold and a.combat_target and a.combat_target(60) or nil
 local escape,status
 if self.options.hazard_avoidance~=false and snap.combat and a.hazard_escape then escape,status=a.hazard_escape() end
 if snap.combat and not threat and not escape then self.combat_orphan_since=self.combat_orphan_since or now else self.combat_orphan_since=nil;self.combat_orphan_logged=nil end
 local stale_combat=snap.combat and not threat and not escape and now-(self.combat_orphan_since or now)>=5
 if (threat or escape or snap.combat and not stale_combat) and self.options.combat_hold then
  if threat then
  self.progress_at=now
   if self.combat_target_guid~=threat.guid and self.logger then self.logger.record(now,"combat_acquire",{guid=threat.guid,name=threat.name or "",distance=threat.distance,source=threat.source or ""}) end
   self.combat_seen_at=now
   if self.options.auto_face~=false and a.face_target and now>=(self.combat_face_at or 0) then local faced,why=a.face_target(threat.object);self.combat_face_at=now+.15;if faced==false and self.logger then self.logger.record(now,"combat_face_refused",{guid=threat.guid,reason=why or "refused"}) end end
  end
  status=status or "Combat plugin active"
  if escape and not self.moving then self:move(escape,status);return end
  if threat and not escape then
   if self.moving and self.combat_move_guid~=threat.guid then self:clear_motion() end
   if a.target and self.combat_target_guid~=threat.guid then local targeted,why=a.target(threat.object);if targeted then self.combat_target_guid=threat.guid elseif self.logger then self.logger.record(now,"combat_target_refused",{guid=threat.guid,reason=why or "refused"}) end end
    if self.options.combat_approach~=false and threat.distance>profile.approach_range then
    if not self.moving then self.combat_move_guid=threat.guid;self.combat_last_position={x=threat.position.x,y=threat.position.y,z=threat.position.z};self.arrived=false;self:move(threat.position,"Combat approach: "..threat.name,threat.guid,nil,{track_guid=threat.guid}) end
    return
   end
   if self.moving and self.combat_move_guid then self:clear_motion() end
   self.combat_move_guid=threat.guid;status="In combat range: external combat plugin active"
  elseif not escape and self.moving then self:clear_motion() end
  local combat_plan=Plans.get(self.selected,self.variant)
  local encounter=delve.nemesis and self.nemesis:update(snap.instance,a.boss_health and combat_plan and a.boss_health(combat_plan.boss),true,self.options.tier>=11)
  self.state=encounter and encounter~="Idle" and encounter or status or "Combat plugin active";return
 end
 if stale_combat and not self.combat_orphan_logged then self.combat_orphan_logged=true;if self.logger then self.logger.record(now,"stale_combat_ignored",{seconds=now-(self.combat_orphan_since or now)}) end;self:note("No hostile found after combat grace: resuming route") end
 if (self.combat_move_guid or self.combat_target_guid) and now-(self.combat_seen_at or now)<1.5 then self.state="Confirming combat ended before route resume";return end
 if self.combat_move_guid or self.combat_target_guid then
  if self.logger then self.logger.record(now,"combat_resume",{guid=self.combat_target_guid or self.combat_move_guid or ""}) end
  self.combat_move_guid=nil;self.combat_target_guid=nil;self.combat_last_position=nil;self.combat_repath_at=nil;self.combat_face_at=nil;self.arrived=false;self:note("Combat ended: resuming delve route")
 end
 if now-self.started>5400 then self:stop("Run timeout");return end
 if self.completed then
  if snap.inside then
   if self.options.auto_loot and a.rewards then
    local budget=0;if self.options.spend_key and a.can_spend_key then local allowed,count=a.can_spend_key(self.options.key_reserve or 1);if allowed then budget=math.max(0,(tonumber(count) or 0)-(tonumber(self.options.key_reserve) or 1)) end end
    self.reward_job=self.reward_job or Rewards.new(a,budget,self.selected==15 and {timeout=600,settle=15} or nil);local result,why=self.reward_job:tick();self.state=self.reward_job.state;if result==false then self:stop(why);return elseif result~=true then return end
   end
   if self.options.auto_exit then if now>=(self.exit_at or 0) then if (self.exit_attempts or 0)>=8 then self:stop("Exit transition timeout; inspect live debugger");return end;local ok,why=a.exit();if ok==false then if transient(why) then self.exit_at=now+2;self.state="Exit paused: "..tostring(why);return end;self:stop(why or "Exit refused");return end;self.exit_attempts=(self.exit_attempts or 0)+1;self.exit_at=now+10;self.state="Exit requested: waiting for world transition ("..self.exit_attempts.."/8)" end else self.state="Complete: waiting for Stop" end
   return
  end
  self.runs=self.runs+1
  if self.pending_id then local id=self.pending_id;self.pending_id=nil;self:start(id,1);return end
  if self.options.repeat_run and (self.options.max_runs==0 or self.runs<self.options.max_runs) then self:reset_run(now);self:note("Repeating "..delve.name) else self:stop("Expedition finished") end
  return
 end
 if not snap.inside then
  if self.was_inside then self:stop("Unexpected instance exit");return end
  if not self.goal and not self.resolve_pending then local e=delve.entrance;self:resolve(e.map,e.x,e.y,"Travelling to "..delve.name.." entrance");return end
  if self.arrived then
   if snap.position and self.goal then local dx,dy,dz=snap.position.x-self.goal.x,snap.position.y-self.goal.y,snap.position.z-self.goal.z;if math.sqrt(dx*dx+dy*dy+dz*dz)>15 then self.goal=nil;self.arrived=false;self:note("Entrance snap was too far away: resolving another floor");return end end
   self.state="Opening delve entrance"
   self.entry_deadline=self.entry_deadline or now+75
   self.entry_arrived_at=self.entry_arrived_at or now
   local ready,why=a.prepare_entry(delve.instance,self.options.tier)
   if ready==false then if transient(why) and now<self.entry_deadline then self.state="Entry paused: "..tostring(why);return end;self:stop(why);return elseif ready~=true then self.state="Entry: "..tostring(why);if now>=self.entry_deadline then self:stop("Entry bridge timeout") end;return end
   if now>=(self.enter_at or 0) then if self.enter_attempts>=6 then self:stop("Entry timeout: entrance trigger did not accept the run");return end;local ok,err=a.enter();if ok==false then if transient(err) then self.enter_at=now+2;self.state="Entry paused: "..tostring(err);return end;self:stop(err or "Entry refused");return end;self.enter_attempts=self.enter_attempts+1;self.enter_at=now+7;self.state="Entry requested: waiting for instance transition" end
  end
  return
 end
 if not self.was_inside then self.was_inside=true;self:clear_motion();self.signature=nil;self.run_origin=snap.position;self.frontier_distance=0;self:note("Detecting active story") end
 if snap.instance~=delve.instance then self:stop("Entered instance does not match selected delve");return end
 local delve_state=a.delve_state and a.delve_state()
 if delve_state and delve_state.active and delve_state.tier>0 and self.options.tier>0 and delve_state.tier~=self.options.tier then self:stop("Active delve tier "..delve_state.tier.." does not match requested tier "..self.options.tier);return end
 if snap.complete then self.completed=true;self.exit_attempts=0;self.exit_at=nil;self:clear_motion();self:note("Delve complete");return end
 local live=a.scenario()
 if live and self.local_interaction then
  local pending=self.local_interaction;self.local_interaction=nil;self.local_prepare=nil;self.failed_ids[pending.id]=nil;self.completed_guids[pending.guid]=true;self.blocked[pending.guid]=math.huge
  if pending.friendly then self.entry_interaction_complete=true end
  remember(self,"completed",pending.guid);self.progress_at=now;self.stuck_retries=0;self:note("Scenario started after interaction: "..pending.name)
 end
 if not live then
  if self.moving then return end
  if self.local_prepare then
   local pending=self.local_prepare
   if now<pending.ready_at then self.state="Settling and facing: "..pending.name;return end
   local usable=a.usable(pending.guid)
   if (usable==nil or usable==false) and not pending.friendly then self.failed_ids[pending.id]=(self.failed_ids[pending.id] or 0)+1;self.blocked[pending.guid]=now+15;self.local_prepare=nil;self.state="Objective changed before acquisition: "..pending.name;return end
   local object=a.object_by_guid and a.object_by_guid(pending.guid) or pending.object
   local ok,why=a.interact(object)
   if self.logger then self.logger.record(now,"interaction_attempt",{name=pending.name,id=pending.id,guid=pending.guid,attempt=pending.attempt,ok=ok==true,reason=ok and "" or why or "",method=ok and why or ""}) end
   if ok then self.local_interaction={guid=pending.guid,id=pending.id,name=pending.name,at=now,friendly=pending.friendly,attempt=pending.attempt,object=pending.object};self.local_prepare=nil;self.blocked[pending.guid]=now+10;self.state="Local scan: using "..pending.name.." via "..tostring(why);return end
   if transient(why) then pending.ready_at=now+1;self.state="Interaction paused: "..tostring(why);return end
   if pending.attempt<2 then pending.attempt=pending.attempt+1;pending.ready_at=now+1.25;if a.face_guid then a.face_guid(pending.guid) end;self.state="Refacing before final acquisition attempt: "..pending.name;return end
   self.failed_ids[pending.id]=(self.failed_ids[pending.id] or 0)+1;self.blocked[pending.guid]=math.huge;remember(self,"quarantined",pending.guid);local f=family(pending.name);self.family_refusals[f]=(self.family_refusals[f] or 0)+1;if self.family_refusals[f]>=2 then self.quarantined_families[f]=true;remember(self,"family",f) end;self.local_prepare=nil
   if contact_name(pending.name) and pending.object then local valid,q=pcall(function() if not pending.object:is_valid() then return nil end;return pending.object:get_position() end);if valid and q and finite(q.x) and finite(q.y) and finite(q.z) then if self.logger then self.logger.record(now,"contact_fallback",{guid=pending.guid,id=pending.id,name=pending.name,x=q.x,y=q.y,z=q.z}) end;self:move({x=q.x,y=q.y,z=q.z},"Crossing contact objective: "..pending.name);return end end
   if self.logger then self.logger.record(now,"run_quarantine",{guid=pending.guid,id=pending.id,name=pending.name,family=f,family_refusals=self.family_refusals[f],reason="two interaction refusals"}) end;self.state=self.quarantined_families[f] and "Inactive objective family quarantined: "..pending.name or "Inactive object quarantined for this run: "..pending.name;return
  end
  if self.local_interaction then
   local pending=self.local_interaction;local usable=a.usable(pending.guid)
   local refused=a.interaction_refused and a.interaction_refused(pending.at)
   if refused then
    self.local_interaction=nil
    if pending.attempt<2 then pending.attempt=pending.attempt+1;pending.ready_at=now+1.25;self.local_prepare=pending;if a.face_guid then a.face_guid(pending.guid) end;self.state="Interaction refused; refacing: "..pending.name;return end
    self.failed_ids[pending.id]=(self.failed_ids[pending.id] or 0)+1;self.blocked[pending.guid]=now+15;self.state="Interaction refused: "..tostring(refused);return
   end
   local ui_confirmed=a.interaction_confirmed and a.interaction_confirmed(pending.at)
   if ui_confirmed or not pending.friendly and (usable==nil or usable==false) then self.local_interaction=nil;self.failed_ids[pending.id]=nil;self.completed_guids[pending.guid]=true;self.blocked[pending.guid]=math.huge;if pending.friendly then self.entry_interaction_complete=true end;remember(self,"completed",pending.guid);self.progress_at=now;self.stuck_retries=0;self:note("Confirmed local objective: "..pending.name);return end
   if now-pending.at<10 then self.state="Confirming local objective: "..pending.name;return end
   self.failed_ids[pending.id]=(self.failed_ids[pending.id] or 0)+1;self.blocked[pending.guid]=math.huge;remember(self,"quarantined",pending.guid);local f=family(pending.name);self.family_refusals[f]=(self.family_refusals[f] or 0)+1;if self.family_refusals[f]>=2 then self.quarantined_families[f]=true;remember(self,"family",f) end;self.local_interaction=nil;if self.logger then self.logger.record(now,"run_quarantine",{guid=pending.guid,id=pending.id,name=pending.name,family=f,family_refusals=self.family_refusals[f],reason="no completion evidence"}) end
  end
  local plan=Plans.get(self.selected,self.variant);local strict=plan and plan.requires_live_evidence==true
  local nearby=a.nearby_objectives(strict and 18 or 70)
  local reject={}
  if self.selected==15 then for _,name in ipairs({"ancient chest","mislaid treasure","hexmask","loa-sealed","loa sealed","keeper of the key","spiritual conduit"}) do reject[#reject+1]=name end end
  local favor={"interface","conduit","lever","switch","portal","door","gate","barrier","crystal","shrine","cage","prisoner","cocoon","egg","web","chest","cache","coffer","key","totem","barrel","bomb","explosive","mushroom","fungus","idol","rune","console","mechanism"}
  local filtered={}
  for _,row in ipairs(nearby) do
   local name=(row.name or ""):lower();local denied=self.completed_guids[row.guid]==true or self.quarantined_families[family(name)]==true or optional_object(name);for _,word in ipairs(reject) do if name:find(word,1,true) then denied=true;break end end
   if name:find("door",1,true) and row.distance>25 then denied=true end
   if (row.vertical or 0)>12 and not name:find("portal",1,true) and not name:find("teleport",1,true) and not name:find("elevator",1,true) then denied=true end
   local strong=false;for _,word in ipairs(favor) do if name:find(word,1,true) then strong=true;break end end
   if strict and row.distance>15 then denied=true end
   if strict and row.usable and not strong and not row.friendly_interactable then denied=true end
   if not denied then
    local failures=self.failed_ids[row.id] or 0;local score=(row.usable and 100 or 80)-row.distance-(row.enemy and (row.pack or 1)*2 or 0)-failures*90;if name:find("doodad_",1,true) then score=score-60 end
    if strong then score=score+80 end
    row.local_score=score;filtered[#filtered+1]=row
   end
  end
  table.sort(filtered,function(x,y) if x.local_score==y.local_score then return tostring(x.guid)<tostring(y.guid) end;return x.local_score>y.local_score end)
  for _,row in ipairs(filtered) do
    if (self.blocked[row.guid] or 0)<=now and not (row.enemy and (row.pack or 1)>profile.max_pull) then
    local logged_at=self.candidate_log_at and self.candidate_log_at[row.guid] or -100
    if self.logger and now-logged_at>=5 then self.candidate_log_at[row.guid]=now;self.logger.record(now,"local_candidate",{name=row.name or "",id=row.id or 0,guid=row.guid or "",distance=row.distance,usable=row.usable==true,enemy=row.enemy==true,pack=row.pack or 0,score=row.local_score}) end
    local use_range=row.usable and 2.5 or 4
    if row.distance>use_range then self.arrived=false;self:move(row.position,"Local scan: approaching "..(row.name or "objective"),row.guid,nil,{valid_guid=row.guid,expires_in=45});return end
    if row.usable then local name=row.name or "objective";local faced,why=true,"Facing object";if a.face_guid then faced,why=a.face_guid(row.guid) end;if faced==false then self.blocked[row.guid]=now+10;self.state=tostring(why);return end;self.local_prepare={guid=row.guid,id=row.id,name=name,object=row.object,attempt=1,ready_at=now+.45,friendly=row.friendly_interactable==true};if self.logger then self.logger.record(now,"interaction_prepare",{name=name,id=row.id or 0,guid=row.guid or "",delay=.45,friendly=row.friendly_interactable==true}) end;self.state="Settling and facing: "..name;return end
    if row.enemy then local ok,why=a.target(row.object);self.blocked[row.guid]=now+(ok and 3 or 10);self.state=ok and "Local scan: target handed to combat plugin" or tostring(why);return end
   end
  end
  if not strict and self.run_origin and self.entry_interaction_complete then
   local anchor,anchor_distance
   for _,row in ipairs(nearby) do
    if row.position and not row.enemy and not row.friendly_interactable then
     local dx=row.position.x-self.run_origin.x;local dy=row.position.y-self.run_origin.y;local dz=row.position.z-self.run_origin.z
     local d=math.sqrt(dx*dx+dy*dy+dz*dz)
     if d>8 and (not anchor_distance or d>anchor_distance) then anchor=row;anchor_distance=d end
    end
   end
   if anchor and anchor_distance>(self.frontier_distance or 0)+4 then
    local dx=anchor.position.x-self.run_origin.x;local dy=anchor.position.y-self.run_origin.y;local scale=(anchor_distance+18)/anchor_distance
    local frontier={x=self.run_origin.x+dx*scale,y=self.run_origin.y+dy*scale,z=anchor.position.z}
    if self.logger then self.logger.record(now,"frontier_advance",{landmark=anchor.name or "",landmark_distance=anchor_distance,x=frontier.x,y=frontier.y,z=frontier.z}) end
    self.arrived=false;self:move(frontier,"Advancing beyond cleared entrance","frontier:"..family(anchor.name),anchor_distance);return
   end
  end
  if now-(self.progress_at or now)>240 then self:stop("Fallback watchdog: no objective evidence for 4 minutes; inspect live debugger");return end
  self.state=strict and "Guarded story label: waiting for nearby live objective evidence" or self.entry_interaction_complete and "No new forward landmark: scanning for objective" or "Bridge unavailable: scanning nearby objectives";return
 end
 local sig=a.progress_signature();if sig and sig~=self.signature then
  if self.interaction then self.completed_guids[self.interaction.guid]=true;remember(self,"completed",self.interaction.guid);if self.options.learning then Learning.record(self.interaction.learn_key,true);Learning.flush() end end
  self.signature=sig;self.interaction=nil;local permanent={};for key,until_at in pairs(self.blocked) do if until_at==math.huge then permanent[key]=until_at end end;self.blocked=permanent;self.index=self.index+1;self.progress_at=now;self.stuck_retries=0;if self.moving then self:clear_motion() end
 end
 if not self.moving and now-(self.progress_at or now)>240 then self:stop("Progress watchdog: no objective change for 4 minutes; inspect live debugger");return end
 if self.interaction then
  if sig~=self.interaction.signature then self.interaction=nil;return end
  local usable=a.usable(self.interaction.guid)
  if usable==false then self.completed_guids[self.interaction.guid]=true;self.blocked[self.interaction.guid]=math.huge;remember(self,"completed",self.interaction.guid);self.interaction=nil;self.progress_at=now;self:note("Confirmed objective became inactive");return end
  local current=a.snapshot();if current.map~=self.interaction.map or current.instance~=self.interaction.instance then self.completed_guids[self.interaction.guid]=true;self.blocked[self.interaction.guid]=math.huge;remember(self,"completed",self.interaction.guid);self.interaction=nil;self.progress_at=now;self:note("Confirmed portal/floor transition");return end
  if now-self.interaction.at>12 then local guid=self.interaction.guid;if self.options.learning then Learning.record(self.interaction.learn_key,false);Learning.flush() end;self.blocked[guid]=math.huge;remember(self,"quarantined",guid);if self.logger then self.logger.record(now,"run_quarantine",{guid=guid,reason="accepted interaction produced no completion evidence"}) end;self.interaction=nil;self:note("Unconfirmed objective quarantined for this run");return end
  return
 end
 if self.moving then
  local nav=a.nav_progress and a.nav_progress()
  if nav and nav.managed then
   self:observe_managed_motion(now,snap,nav)
   if self.logger and now>=(self.nav_progress_log_at or 0) then self.nav_progress_log_at=now+5;self.logger.record(now,"nav_progress",{state=nav.state or "",phase=nav.phase or "",percent=nav.percent or 0,index=nav.index or 0,remaining=nav.remaining or 0,replans=nav.replans or 0,recovery=nav.recovery_reason or "",readiness=nav.readiness or "",confidence=nav.confidence or 0,route_score=nav.route_score or 0}) end
   return
  end
  if snap.position then
   local p=self.last_motion_position;if p then local dx,dy,dz=snap.position.x-p.x,snap.position.y-p.y,snap.position.z-p.z;if math.sqrt(dx*dx+dy*dy+dz*dz)>.6 then self.last_motion_position=snap.position;self.last_motion_at=now elseif now-(self.last_motion_at or now)>8 then
    local key=self.goal_block_key or self.goal and (tostring(self.goal.x)..":"..tostring(self.goal.y));self:clear_motion();if key then self.blocked[key]=now+45 end;self.stuck_retries=self.stuck_retries+1
    if self.stuck_retries>3 then self:stop("Stuck recovery exhausted; inspect live debugger") else self:note("Stuck recovery "..self.stuck_retries..": rescanning alternate objective") end
   end else self.last_motion_position=snap.position;self.last_motion_at=now end
  end
  return
 end
 local objects=a.nearby_objectives(70)
 local objective=(live.title or ""):lower();for _,c in pairs(live.criteria or {}) do objective=objective.." "..tostring(c.description or ""):lower() end
 local tokens={};for w in objective:gmatch("[%a]+") do if #w>=4 then tokens[w]=true end end
 local candidates={}
 for _,row in ipairs(objects) do
  local score=(row.usable and 120 or 0)-row.distance;local lname=(row.name or ""):lower();for w in pairs(tokens) do if lname:find(w,1,true) then score=score+35 end end
  local learn=Learning.key(snap.instance,self.variant,live.step_id,row.usable and "use" or "kill",row.id);score=score+(self.options.learning and Learning.score(learn) or 0);row.score=score;row.learn_key=learn
  if not optional_object(lname) then candidates[#candidates+1]=row elseif self.logger and now>=(self.optional_log_at or 0) then self.optional_log_at=now+10;self.logger.record(now,"optional_object_skipped",{name=row.name or "",id=row.id or 0,guid=row.guid or "",step=live.step_id or 0}) end
 end
 table.sort(candidates,function(x,y) if x.score==y.score then return tostring(x.guid)<tostring(y.guid) end;return x.score>y.score end)
 for _,row in ipairs(candidates) do
  if (self.blocked[row.guid] or 0)<=now then
    local oversized=row.enemy and (row.pack or 1)>profile.max_pull
   if oversized then self.blocked[row.guid]=now+20
   else
    if row.distance>4 then self.arrived=false;self:move(row.position,"Approaching "..(row.name or "objective"),row.guid,nil,{valid_guid=row.guid,expires_in=45});return end
    if row.usable then local ok,why=a.interact(row.object);if ok then self.interaction={guid=row.guid,signature=sig,at=now,map=snap.map,instance=snap.instance,learn_key=row.learn_key};self.state="Using "..(row.name or "objective") else if transient(why) then self.blocked[row.guid]=now+1;self.state="Interaction paused: "..tostring(why) else if self.options.learning then Learning.record(row.learn_key,false) end;self.blocked[row.guid]=now+20;self.state=tostring(why) end end;return end
    if row.enemy then local ok,why=a.target(row.object);if ok then self.state="Target handed to combat plugin" else self.blocked[row.guid]=now+(transient(why) and 1 or 10);self.state=tostring(why) end;return end
   end
  end
 end
 local pins=a.objective_pins()
 for _,pin in ipairs(pins) do local key=pin.ui_map..":"..pin.x..":"..pin.y;if (self.blocked[key] or 0)<=now then self.blocked[key]=now+20;self:resolve(pin.ui_map,pin.x,pin.y,"Moving to objective: "..tostring(pin.description));return end end
 local plan=Plans.get(self.selected,self.variant);self.state="Needs live objective evidence: "..tostring(plan and plan.handlers[1] or live.title)
end
return M
