local Planner=require("bg_planner")
local Queue=require("bg_queue")
local Recovery=require("bg_recovery")
local Progress=require("bg_progress")
local Snapshot=require("bg_snapshot")
local FormationAnchor=require("bg_formation_anchor")
local RouteProgress=require("bg_route_progress")
local Advancement=require("bg_advancement")
local Object=require("bg_object")
local PathPreflight=require("bg_path_preflight")
local NavProgressWatch=require("bg_nav_progress_watch")
local NavOwnership=require("bg_nav_ownership")
local PathCorridor=require("bg_path_corridor")
local MMapError=require("bg_mmap_error")
local C={};C.__index=C
local Predictive=require("bg_predictive_logic")
local function native_bool(object,method)
 if not object then return false,false end
 local ok,value=pcall(function()
  local fn=object[method];if type(fn)~="function" then error("native_method_unavailable") end
  return fn(object)
 end)
 return ok,value==true
end
local function native_position(object)
 if not object then return nil end
 local ok,value=pcall(function()
  local fn=object.get_position;if type(fn)~="function" then return nil end
  return fn(object)
 end)
 return ok and Snapshot.position(value) or nil
end
local function route_scope(settings)
 local ok,value=pcall(function() return type(settings.route_scope)=="function" and settings.route_scope() end)
 value=ok and tostring(value or "shared") or "shared"
 return value:gsub("[^%w_:%.%-]","_"):sub(1,80)
end
function C.new(api,settings)
 return setmetatable({api=api,progress=Progress.new(),advancement=Advancement.new(),nav_progress=NavProgressWatch.new(6,2),nav_ownership=NavOwnership.new(3),path_corridor=PathCorridor.new(2),recovery=Recovery.new(api),predictive=Predictive.new(),settings=settings,state="disabled",next_action=0,next_target=0,epoch=0,confirmable_slots={},blocked_legs={},leg_points={},reroutes={},route_memory=settings.route_memory or {},direct_route_fallback={},death_hotspots={}},C)
end
-- Failed corridors are remembered by position so the route graph can steer
-- around them (soft penalty, never a hard block) instead of retrying the same leg.
function C:note_leg(leg,point,profile)
 if type(leg)~="string" or type(point)~="table" or type(point.x)~="number" or type(point.y)~="number" then return end
 local count=0;for _ in pairs(self.leg_points) do count=count+1 end
 if count>=240 then
  -- Bound memory: forget legs whose blacklist already lapsed and that carry no failures.
  for key in pairs(self.leg_points) do
   local row=self.route_memory[key]
   if not self.blocked_legs[key] and not (row and (row.failures or 0)>0) then self.leg_points[key]=nil end
  end
 end
 self.leg_points[leg]={x=point.x,y=point.y,z=point.z,profile=tostring(profile or "")}
end
function C:avoid_list(profile,now)
 local out={};profile=tostring(profile or "")
 for leg,row in pairs(self.blocked_legs) do
  local point=self.leg_points[leg]
  if point and point.profile==profile and (not row.expires or now<row.expires) then
   out[#out+1]={x=point.x,y=point.y,z=point.z,radius=6,penalty=600}
  end
 end
 for leg,memory in pairs(self.route_memory) do
  local point=self.leg_points[leg]
  local failures=type(memory)=="table" and tonumber(memory.failures) or 0
  if point and point.profile==profile and failures>0 and not self.blocked_legs[leg] then
   local trust=math.max(0,math.floor(tonumber(memory.opening_successes) or 0))
   out[#out+1]={x=point.x,y=point.y,z=point.z,radius=6,penalty=math.min(480,120*failures/(1+trust))}
  end
 end
 for _,hotspot in ipairs(self.death_hotspots or {}) do
  if hotspot.profile==profile and hotspot.count>=2 and now<(hotspot.expires or 0) then
   out[#out+1]={x=hotspot.x,y=hotspot.y,z=hotspot.z,radius=10,penalty=math.min(600,180*hotspot.count)}
  end
 end
 if #out>40 then for i=#out,41,-1 do out[i]=nil end end
 return out
end
-- Drop the frozen role corridor so the next tick re-plans around a leg that was
-- just blacklisted. Authored spawn/flag-room corridors are never re-planned.
function C:request_reroute(plan)
 local lock=type(plan)=="table" and type(plan.route)=="table" and plan.route.lock_id
 if type(lock)~="string" or not lock:find("^role_corridor_") or not self.route_key then return false end
 local count=self.reroutes[self.route_key] or 0
 if count>=4 then return false end
 self.reroutes[self.route_key]=count+1
 self.route_key=nil;self.locked_route=nil
 return true
end
function C:status(state)
 if self.state~=state then self.state=state;self.api.log(state) end
end
local function target_guid(target)
 return Object.guid(target)
end
function C:clear_owned_target(player)
 local owned=self.owned_target_guid
 if not owned then return end
 local ok,current=pcall(function()
  player=player or self.api.player()
  if self.api.current_target then return self.api.current_target(player) end
  return player and player.get_target and player:get_target()
 end)
 if not ok then return end
 local current_guid=target_guid(current)
 if current and not current_guid then return end
 -- A user or another plugin may have replaced the target since our last dispatch.
 if current_guid==owned and self.api.clear_target then self.api.clear_target() end
 self.owned_target_guid=nil
end
function C:gameplay_ready()
 local a=self.api
 if type(a.objective_provider_ready)~="function" or not a.objective_provider_ready() then
  return false,"objective_provider_required"
 end
 if type(a.navigation_ready)~="function" or not a.navigation_ready() then
  return false,"navigation_unavailable"
 end
 return true
end
function C:stop_motion(preserve_plan)
 self.progress:reset()
 self.advancement:reset()
 self.path_corridor:reset()
 if self.mounted_escape and self.api.recovery_step then self.api.recovery_step(nil) end
 if self.escape_until and self.api.escape_direction then self.api.escape_direction(nil) end
 if self.reverse_until and self.api.reverse_rebound then self.api.reverse_rebound(nil) end
 self.escape_until=nil
 self.reverse_until=nil
 self.mounted_escape=nil
 self.epoch=self.epoch+1
 local active=self.destination~=nil
 if not active and self.api.navigation_full_state then
  local ok,state=pcall(self.api.navigation_full_state)
  active=ok and type(state)=="string" and state~="idle" and state~="arrived" and state~="failed"
 end
 if active then self.api.stop() end
 self.destination=nil
 if not preserve_plan then self.plan=nil;self:clear_owned_target() end
end
function C:reset_match()
 if self.api.match_reset then self.api.match_reset() end
 self:stop_motion();self.recovery:reset();self.match=nil;self.carrier_seen=nil;self.next_target=0;self.navigation_retry_at=0;self.confirmable_slots={};self.owned_queue=nil;self.stall_count=0;self.escape_side=1
 self.navigation_unavailable_since=nil
 self.awaiting_path_since=nil;self.route_key=nil;self.route_index=nil;self.route_leg_origin=nil;self.locked_route=nil;self.path_timeout_count=0;self.path_timeout_leg=nil;self.direct_route_fallback={};self.reverse_until=nil;self.learned_passed={};self.formation_goal=nil;self.formation_goal_at=nil
 self.path_preflight_signature=nil;self.path_preflight_attempts=0
 self.nav_progress:reset(true)
 self.nav_ownership:reset(true)
 self.path_corridor:reset()
 self.reroutes={}
 self.preparation_key=nil;self.preparation_started_at=nil;self.preparation_hold_until=nil;self.forever_recovery_until=nil;self.forever_recovery_kind=nil;self.forever_recovery_retry_at=0;self.premature_arrivals=0;self.premature_goal=nil;self.path_blocked_position=nil;self.path_probe_at=nil;self.force_graph_until=nil
 self.combat_hold_target=nil;self.combat_hold_guid=nil;self.combat_holding=nil;self.combat_reacquire_until=nil;self.last_combat_position=nil
 self.activity_position=nil;self.activity_goal=nil;self.activity_at=nil;self.activity_recoveries=0
 self.interaction_key=nil;self.interaction_failures=0;self.interaction_retry_at=0
 self.interaction_pending_until=nil
 self.match_entered_at=nil;self.match_finished=false;self.last_match_phase=nil;self.active_phase_at=nil;self.active_guard_until=nil
 self.awaiting_respawn=nil;self.respawn_reintegrate_until=nil
 self.death_hotspots={};self.death_noted=nil;self.match_deaths=0;self.last_death_at=nil;self.current_profile=nil;self.spawn_key=nil;self.objective_history={}
end
function C:recover_mounted(pos,goal,now,reason)
 if not self.api.recover_mounted or not self.api.recover_mounted(pos,reason,now) then return false end
 self:stop_motion(true)
 self.path_blocked_position=nil;self.path_probe_at=nil;self.path_timeout_count=0
 self.awaiting_path_since=nil;self.premature_arrivals=0;self.premature_goal=nil
 self.mounted_escape={goal={x=goal.x,y=goal.y,z=goal.z},start_at=now+0.35,stop_at=now+1.15,started=false}
 self.navigation_retry_at=now+1.25;self.next_move=0
 self:status("mounted_path_recovery_on_foot");return true
end
function C:tick()
 local a=self.api;local now=a.time()
 if not self.settings.enabled() then self:reset_match();self:status("disabled");return end
 local player=a.player()
 local valid_ok,valid=native_bool(player,"is_valid")
 if not valid_ok or not valid then self:reset_match();self:status("loading");return end
 local in_bg=a.in_battleground()
 if not in_bg then
  local _,dead=native_bool(player,"is_dead");local _,ghost=native_bool(player,"is_ghost")
  if dead or ghost then
   if self.match then self:reset_match() end
   self:stop_motion()
   if not a.instance_type or a.instance_type()~="none" then
    self.recovery:reset();self:status("death_recovery_instance_unsupported");return
   end
   self:status(self.recovery:tick(player,now));return
  end
  self.recovery:reset()
  if self.match then
   local completed=self.match_finished==true
   self:reset_match()
   self.post_match_until=math.max(tonumber(self.post_match_until) or 0,now+(completed and 30 or 60))
   self.next_action=self.post_match_until
  end
  if a.queue_ready then
   local ready,reason=a.queue_ready()
   if not ready then self:status(reason or "version_adapter_required");return end
  end
  self.observations={observed_at=now,queues={}}
  -- Native bindings have no slot-count reader; a live adapter can supply the actual limit.
  local queue_count=3
  if a.queue_count~=nil then
   local ok,count=pcall(a.queue_count)
   if not ok or type(count)~="number" or count~=count or count%1~=0 or count<0 or count>16 then
    self:status("queue_status_unavailable");return
   end
   queue_count=count
  end
  self.observations.queue_count=queue_count
  local queued,unknown=false,false
  local ignored_invitation
  local infos={};local nonempty=0
  for i=1,queue_count do
   local status_ok,status=pcall(a.queue_status,i)
   if not status_ok then status=nil end
   self.observations.queues[i]=status
   if a.queue_info then
    local info_ok,info=pcall(a.queue_info,i)
    if info_ok then infos[i]=info end
   end
   if status and status~="none" then nonempty=nonempty+1 end
  end
  -- Deserter can arrive several seconds after an unexpected server removal.
  -- Never accept or create another queue during this observation window.
  if now<(tonumber(self.post_match_until) or 0) then
   if a.queue_allowed then
    local allowed,reason=a.queue_allowed(player)
    if not allowed and reason=="deserter_active" then self:status(reason);return end
   end
   self:status("post_match_safety_wait");return
  end
  for i=1,queue_count do
   local status=self.observations.queues[i]
   if status~="none" and status~="queued" and status~="active" and status~="confirm" then unknown=true end
   if status=="confirm" then
    local verified,invitation_reason=Queue.invitation(infos[i],now,self.settings.queue_id(),
     self.settings.queue_mode and self.settings.queue_mode())
    local owned=self.owned_queue
    local owned_continuity=self.confirmable_slots[i]==true or owned and nonempty==1 and
     now>=owned.joined_at and now-owned.joined_at<=7200 and owned.id==self.settings.queue_id() and
     (not self.settings.queue_mode or owned.mode==self.settings.queue_mode())
    if verified or owned_continuity then
     if a.accept_allowed then
      local allowed,reason=a.accept_allowed(player)
      if not allowed then self:status(reason or "invitation_blocked");return end
     end
     self:status("accepting")
     if now>=(self.next_accept or 0) then self.next_accept=now+3;a.accept(i) end
     return
    end
    ignored_invitation=invitation_reason or "invitation_identity_unverified"
   elseif status=="queued" or status=="active" then
    queued=true
    local verified=Queue.invitation(infos[i],now,self.settings.queue_id(),self.settings.queue_mode and self.settings.queue_mode())==true
    local owned=self.owned_queue
    local continuous_owned=owned and nonempty==1 and now>=owned.joined_at and now-owned.joined_at<=7200 and
     owned.id==self.settings.queue_id() and (not self.settings.queue_mode or owned.mode==self.settings.queue_mode())
    self.confirmable_slots[i]=verified or continuous_owned or self.confirmable_slots[i]==true
   elseif status=="none" then self.confirmable_slots[i]=nil end
  end
  if queued then self:status("queued");return end
  if unknown then self:status("queue_status_unavailable");return end
  if ignored_invitation then self:status(ignored_invitation);return end
  if a.queue_allowed then
   local allowed,reason=a.queue_allowed(player)
   if not allowed then self:status(reason or "queue_blocked");return end
  end
  local id=self.settings.queue_id()
  if not id or id<=0 then self:status("queue_id_required");return end
  self:status("queueing")
  if now>=self.next_action then
   self.next_action=now+15
   self.owned_queue={id=id,mode=self.settings.queue_mode and self.settings.queue_mode(),joined_at=now}
   a.join(id,self.settings.role_flags())
  end
  return
 end
 self.recovery:reset()
 local match=a.match_id()
 if self.match~=match then self:reset_match();self.match=match;self.next_action=now;self.match_entered_at=now end
 local phase=a.match_state()
 local previous_phase=self.last_match_phase
 -- Keep durable proof that this exact match was engaged. Retail normally moves
 -- Engaged (3) -> PostRound (4) -> Complete (5), so checking only the
 -- immediately previous phase loses the proof needed for a safe automatic exit.
 if phase==3 and self.active_phase_at==nil then self.active_phase_at=now end
 if phase==3 and previous_phase~=nil and previous_phase~=3 then self.active_guard_until=now+3 end
 self.last_match_phase=phase
 if a.observe_team then a.observe_team(player,phase) end
 self.observations={observed_at=now,phase=phase}
 local winner=a.winner()
 local verified_winner=winner==0 or winner==1 or winner==2
 -- Some clients briefly report the completed phase while a newly accepted
 -- battleground is still preparing. Never turn that transient reading into a
 -- leave request unless this controller observed the match become active.
 local complete_phase=phase==5
 if type(a.match_complete)=="function" then complete_phase=a.match_complete(phase)==true end
 local verified_complete=complete_phase and (self.active_phase_at~=nil or self.match_finished==true)
 if verified_complete or verified_winner then
  self.match_finished=true;self:stop_motion();self:status("finished")
  if now>=self.next_action then self.next_action=now+5;a.leave() end
  return
 end
 if complete_phase then self:stop_motion();self:status("verifying_match_completion");return end
 local _,dead=native_bool(player,"is_dead");local _,ghost=native_bool(player,"is_ghost")
 if dead or ghost then
  if not self.death_noted then
   self.death_noted=true;self.match_deaths=(self.match_deaths or 0)+1;self.last_death_at=now
   local death_position_ok,death_position_raw=pcall(function() return player:get_position() end)
   local death_position=death_position_ok and Snapshot.position(death_position_raw) or nil
   if death_position and self.current_profile then
    local found
    for _,row in ipairs(self.death_hotspots) do
     if row.profile==self.current_profile and Planner.distance(row,death_position)<=12 then found=row;break end
    end
    if not found then found={x=death_position.x,y=death_position.y,z=death_position.z,profile=self.current_profile,count=0};self.death_hotspots[#self.death_hotspots+1]=found end
    found.count=found.count+1;found.expires=now+240
   end
  end
  self.awaiting_respawn=true
  self:stop_motion();self.route_key=nil;self.route_index=nil;self.locked_route=nil;self:status("waiting_resurrection")
  if not ghost and now>=self.next_action then self.next_action=now+5;a.release() end
  return
 end
 if self.awaiting_respawn then
  self.awaiting_respawn=nil;self.death_noted=nil;self.respawn_reintegrate_until=now+12
 end
 if phase==3 and self.active_guard_until and now<self.active_guard_until then
  self:stop_motion();self:status("confirming_match_entry");return
 end
 if phase~=3 then
  if phase==2 and now<(self.preparation_hold_until or 0) then
   self:stop_motion();self:status("preparation_interaction_hold");return
  end
  if phase==2 and a.mount_service then
   local handled,service_state=a.mount_service(player,now)
   if handled then self:stop_motion(true);self:status(service_state or "mount_vendor_service");return end
  end
  if phase==2 and a.prepare then
   local prep=a.prepare(player,match,now)
   if prep then
    local pos=native_position(player)
    local goal=Snapshot.position(prep.position)
    if pos and goal and Planner.distance(pos,goal)>5 then
     if self.preparation_key~=prep.key then
      self.preparation_key=prep.key;self.preparation_started_at=now
     elseif now-(self.preparation_started_at or now)>=6 then
      self:stop_motion(true);self.destination=nil
      if a.prepare_skip then a.prepare_skip(prep,now) end
      self.preparation_key=nil;self.preparation_started_at=nil
      self:status("preparation_unreachable:"..tostring(prep.kind));return
     end
     if not self.destination or Planner.distance(self.destination,goal)>2 then
      self:stop_motion(true);self.destination=goal;self.epoch=self.epoch+1
      local epoch=self.epoch
      local mover=type(a.move_direct)=="function" and a.move_direct or a.move
      mover(goal,function(ok,err)
       if epoch~=self.epoch then return end
       if not ok then self.destination=nil;self:status("preparation_navigation_failed:"..tostring(err)) end
      end)
     end
     self:status("preparing_"..tostring(prep.kind));return
    elseif prep.object and not player:is_casting_spell() and not player:is_channelling_spell() then
     self:stop_motion(true)
     if now>=self.next_action then
      self.next_action=now+2
      local accepted=a.prepare_use(prep,now)
      if accepted then
       self.preparation_hold_until=now+2.5
       self.preparation_key=nil;self.preparation_started_at=nil
      end
     end
     self:status("using_"..tostring(prep.kind));return
    end
   end
  self.preparation_key=nil;self.preparation_started_at=nil
  end
  if phase==2 and a.try_mount and not player:is_casting_spell() and
   not player:is_channelling_spell() then
   local mounting=a.try_mount(player,now)
   if mounting then self:status("mounting");return end
  end
  self:stop_motion();self:status(phase==nil and "match_state_unavailable" or "waiting_start");return
 end
 local snapshot,reason=a.snapshot(player,match)
 if not snapshot or not snapshot.valid or snapshot.match_id~=match or
  type(snapshot.observed_at)~="number" or snapshot.observed_at~=snapshot.observed_at or snapshot.observed_at>now or now-snapshot.observed_at>2 then
  self:stop_motion();self:status(reason or "objective_state_unavailable");return
 end
 if a.player_role then snapshot.player_role=a.player_role(player) end
 if a.player_damage_style then snapshot.damage_style=a.player_damage_style(player) end
 if a.player_level_policy then
  local policy=a.player_level_policy(player,snapshot.player_role,snapshot.damage_style)
  if type(policy)=="table" then snapshot.player_level=policy.level;snapshot.level_policy=policy end
 end
 self.current_profile=snapshot.rule_profile
 local recovered=type(self.last_death_at)=="number" and math.floor(math.max(0,now-self.last_death_at)/120) or 0
 snapshot.aggression_modifier=-math.min(30,math.max(0,(self.match_deaths or 0)-recovered)*8)
 if not self.spawn_key and snapshot.player_position then
  self.spawn_key=tostring(math.floor(snapshot.player_position.x/75)).."_"..tostring(math.floor(snapshot.player_position.y/75))
 end
 snapshot.post_resurrection=type(self.respawn_reintegrate_until)=="number" and now<self.respawn_reintegrate_until
 snapshot.objective_history=self.objective_history
 if self.forever_recovery_until and now<self.forever_recovery_until then
  local threatened=false
  for _,enemy in ipairs(snapshot.enemies or {}) do
   local p=Snapshot.position(enemy.position or enemy)
   if enemy.dead~=true and enemy.reachable~=false and p and Planner.distance(snapshot.player_position,p)<=45 then threatened=true;break end
  end
  local _,in_combat=native_bool(player,"is_in_combat")
  local recovered=(tonumber(snapshot.player_health_ratio) or 0)>=.90 and
   (snapshot.player_mana_ratio==nil or snapshot.player_mana_ratio>=.85)
  if not threatened and not in_combat and not recovered and not snapshot.carrying then
   self:stop_motion(true);self:status("forever_"..tostring(self.forever_recovery_kind or "ration").."_recovering");return
  end
  self.forever_recovery_until=nil;self.forever_recovery_kind=nil;self.forever_recovery_retry_at=now+10
 end
 if a.forever_recovery and a.use_forever_recovery and now>=(self.forever_recovery_retry_at or 0) then
  local recovery=a.forever_recovery(player,snapshot,now)
  if recovery then
   self:stop_motion(true)
   if a.use_forever_recovery(recovery,now) then
    self.forever_recovery_kind=recovery.kind or "ration"
    self.forever_recovery_until=now+(tonumber(recovery.hold_seconds) or 20);self.forever_recovery_retry_at=now+60
    self:status("using_forever_"..self.forever_recovery_kind);return
   end
   self.forever_recovery_retry_at=now+30
  end
 end
 local avoid_points=self:avoid_list(snapshot.rule_profile,now)
 -- Objective scoring uses authored-graph travel distance on folded maps.
 if a.travel_distance then snapshot.travel_distance=function(point) return a.travel_distance(snapshot,point) end end
 local plan,why=Planner.choose(snapshot,self.plan)
 if not plan then self:stop_motion();self:status(why);return end
 local plan_key=Predictive.objective_key(plan.kind,plan.id,plan.position)
 local last_history=self.objective_history[#self.objective_history]
 if not last_history or last_history.key~=plan_key then
  self.objective_history[#self.objective_history+1]={key=plan_key,at=now}
  while #self.objective_history>12 or self.objective_history[1] and now-(self.objective_history[1].at or 0)>20 do table.remove(self.objective_history,1) end
 end
 if plan.carrier_threat_reroute then
  for _,enemy in ipairs(snapshot.enemies or {}) do
   local p=Snapshot.position(enemy.position or enemy)
   if enemy.dead~=true and enemy.reachable~=false and p and #avoid_points<40 then
    avoid_points[#avoid_points+1]={x=p.x,y=p.y,z=p.z,radius=12,penalty=420}
   end
  end
 end
  if a.powerup and not snapshot.carrying then
  local buff=a.powerup(player,snapshot,now)
   local decisive={return_flag=true,intercept=true,defend=true,recapture=true,hold_capture=true,
    take_flag=true,take_orb=true,take_crystal=true,mine_resource=true}
   local urgent=decisive[plan.kind]==true or type(plan.capture_remaining)=="number" and plan.capture_remaining<=15
   -- Opportunistic buffs must not pull the player off a decisive objective.
   -- Restoration is still preferred over other buffs during routine movement;
   -- its health threshold is enforced by bg_powerups before this gate.
   if buff and buff.position and not urgent then
   plan={kind="collect_powerup",id=buff.kind..":"..buff.key,position=buff.position,arrival_radius=3,
    combat_anchor=true,engagement_radius=20}
  end
 end
 -- A freshly resurrected player may be within the regroup arrival radius
 -- while still standing on a graveyard ledge or inside a spawn enclosure.
 -- Always ask the route provider during this bounded window so its authored
 -- opening recovery owns movement before combat targeting can take over.
 if not plan.route and a.route_for and (snapshot.post_resurrection or
  Planner.distance(snapshot.player_position,plan.position)>(plan.arrival_radius or 3)) then
  plan.route=a.route_for(snapshot,plan,self.force_graph_until and now<self.force_graph_until,avoid_points)
 end
 if plan.route then
  local checked,route_error=Snapshot.route(plan.route)
  if not checked then self:stop_motion();self:status(route_error);return end
  plan.route=checked
 end
 self.plan=plan;a.publish(plan,snapshot)
 local was_carrying=self.carrier_seen;self.carrier_seen=snapshot.carrying==true
 if self.carrier_seen and not was_carrying and a.clear_target then
  a.clear_target();self.owned_target_guid=nil
 end
 if snapshot.capture_in_progress then
  self:stop_motion(true);self:status("casting_or_capturing");return
 end
 -- Friendly formations move every frame. Commit to one support anchor long
 -- enough to finish a useful path, then rotate only after a material shift.
 if snapshot.player_role=="healer" and plan.kind=="escort" and plan.id=="friendly_group" then
  local candidate=Snapshot.position(plan.position)
  local goal,goal_at,changed=FormationAnchor.update(self.formation_goal,self.formation_goal_at,candidate,now)
  if changed then
   self.formation_goal=goal;self.formation_goal_at=goal_at
    local locked_route=type(self.plan)=="table" and type(self.plan.route)=="table" and self.plan.route.lock_id
    self:stop_motion(true)
    -- A moving healer anchor may interrupt the current request, but it must not
    -- rewind a mandatory spawn/flag-room corridor to its first waypoint.
    if not locked_route then self.route_key=nil;self.route_index=nil end
  end
  if self.formation_goal then
   plan.position={x=self.formation_goal.x,y=self.formation_goal.y,z=self.formation_goal.z}
   plan.id="friendly_group_"..tostring(math.floor(self.formation_goal.x/50)).."_"..tostring(math.floor(self.formation_goal.y/50))
   plan.route=nil
  end
 else self.formation_goal=nil;self.formation_goal_at=nil end
 if not plan.route and a.route_for and (snapshot.post_resurrection or
  Planner.distance(snapshot.player_position,plan.position)>(plan.arrival_radius or 3)) then
  plan.route=a.route_for(snapshot,plan,self.force_graph_until and now<self.force_graph_until,avoid_points)
 end
 if plan.route then
  local checked,route_error=Snapshot.route(plan.route)
  if not checked then self:stop_motion();self:status(route_error);return end
  plan.route=checked
 end
 -- Specialized vehicle/siege actions are the final handoff, not a substitute
 -- for travel. Approach the verified live objective normally and invoke its
 -- adapter only after entering the same bounded arrival radius used by other
 -- interactions. Otherwise a distant gate or vehicle freezes the controller.
 if plan.required_action and Planner.distance(snapshot.player_position,plan.position)<=math.max(2,plan.arrival_radius or 5) then
  if player:is_casting_spell() or player:is_channelling_spell() then
   self:status("casting_or_capturing");return
  end
  self:stop_motion(true)
  if not a.objective_action_ready or not a.objective_action_ready(plan.required_action) then
   self:status("objective_action_adapter_required:"..plan.required_action);return
  end
  self:status(plan.kind)
  if now>=self.next_action then
   self.next_action=now+1
   local accepted=a.objective_action(plan,snapshot)
   if accepted==false then self:status("objective_action_failed:"..plan.required_action) end
  end
  return
 end
 if a.transport_transition then
  local transitioning,transition_state=a.transport_transition(player,snapshot,now)
  if transitioning then
   self.destination=nil;self.awaiting_path_since=nil;self.progress:reset()
   self:status(transition_state or "transport_transition");return
  end
 end
 if a.movement_hold then
  local held,hold_state,preserve_navigation=a.movement_hold(player,snapshot,now)
  if held then
   if not preserve_navigation then
    self.destination=nil;self.awaiting_path_since=nil;self.progress:reset()
   end
   self:status(hold_state or "movement_hold");return
  end
 end
 local profile_key=tostring(snapshot.rule_profile or "unknown")
 local route_lock=type(plan.route)=="table" and plan.route.lock_id
 local fallback_scope=route_scope(self.settings)..":"..profile_key..":"..tostring(snapshot.team or "unknown")..":"..
  tostring(route_lock or (tostring(plan.kind)..":"..tostring(plan.id or "")))
 local route_fallback_until=tonumber(self.direct_route_fallback[fallback_scope]) or 0
 if route_fallback_until>0 and now>=route_fallback_until then self.direct_route_fallback[fallback_scope]=nil;route_fallback_until=0 end
 local fallback_direct=type(plan.route)=="table" and #plan.route>0 and
  type(a.move_direct)=="function" and
  now<route_fallback_until
 local direct_route=type(plan.route)=="table" and #plan.route>0 and
  (plan.route.direct==true or fallback_direct) and type(a.move_direct)=="function"
 -- Attack only threats near the objective; rotations remain external.
 local pos=native_position(player)
 if not pos then self:stop_motion();self:status("live_player_position_unavailable");return end
 if self.path_blocked_position then
  local blocked_goal=Snapshot.position(plan.position)
  if blocked_goal and self:recover_mounted(pos,blocked_goal,now,"mesh_blocked") then return end
  if Planner.distance(pos,self.path_blocked_position)>8 then
   self.path_blocked_position=nil;self.path_probe_at=nil;self.path_timeout_count=0;self.navigation_retry_at=0
  elseif now<(self.path_probe_at or 0) then
   self:status("navigation_mesh_probe_wait");return
  else self.path_blocked_position=nil;self.path_probe_at=nil end
 end
 -- Enclosed spawn/flag-room and elevation-recovery corridors must own the
 -- character until clear ground. Skip the expensive combat scan entirely;
 -- selecting and then discarding a target still paid the crowded-fight cost
 -- and could delay the precise opening route.
 local escape_priority=type(plan.route)=="table" and #plan.route>0 and
  (plan.route.escape_priority==true or Predictive.layer_gate(pos,plan.route,1))
 local target=not escape_priority and not snapshot.carrying and snapshot.player_role~="healer" and a.select_target(player,plan,snapshot) or nil
 local target_position
 if target then
  local ok,value=pcall(function() return target:get_position() end)
  target_position=ok and Snapshot.position(value) or nil
  if not target_position then target=nil end
 end
 -- A nearby verified combat target remains actionable during a Sentinel outage.
 -- Use local steering only for that short-lived target position; objective and
 -- long-distance travel still require Sentinel or an authored direct corridor.
 local offmesh_profile=profile_key=="eye_standard" or profile_key=="eye_blitz" or profile_key=="eye_blitz_legacy"
 local nav_ready=a.navigation_ready()
 local combat_direct=target and type(a.move_direct)=="function" and (offmesh_profile or not nav_ready)
 -- Spawn rooms, flag rooms, ships and narrow opening ramps must be cleared
 -- before combat movement can own the destination. A visible enemy beyond an
 -- off-mesh wall otherwise replaces the authored exit with an impossible
 -- Sentinel request and leaves the character standing in the room.
 if escape_priority then target=nil;target_position=nil;combat_direct=false end
 -- Raw steering cannot discover a ramp between stacked floors. EOTS has no
 -- usable Sentinel mesh, and any battleground can temporarily enter the same
 -- mode during an outage. Ignore a target on another layer and resume the
 -- authored objective corridor instead of walking into the wall beneath it.
 if combat_direct and math.abs(target_position.z-pos.z)>8 then
  target=nil;target_position=nil;combat_direct=false
 end
 if combat_direct then direct_route=true end
 -- With no Sentinel client there can be no remote failure callback to trigger
 -- the normal circuit breaker. Verified custom and live-traversed routes opt
 -- into local fallback, so steer their current waypoint immediately.
 local emergency_first=type(plan.route)=="table" and Snapshot.position(plan.route[1]) or nil
 local emergency_leg_safe=emergency_first and Planner.distance(pos,emergency_first)<=50 and
  math.abs(emergency_first.z-pos.z)<=8
 if not nav_ready and not direct_route and type(plan.route)=="table" and #plan.route>0 and
  plan.route.allow_direct_fallback==true and emergency_leg_safe and type(a.move_direct)=="function" then
  self.direct_route_fallback[fallback_scope]=now+120
  direct_route=true
  self.navigation_unavailable_since=nil
  if a.route_memory_event and not self.nav_missing_fallback_noted then
   self.nav_missing_fallback_noted=true
   a.route_memory_event("navigation_client_missing_local_fallback",fallback_scope,
    {source=plan.route.source,quality=plan.route.route_quality})
  end
 end
 if not nav_ready and not direct_route then
  self.navigation_unavailable_since=self.navigation_unavailable_since or now
  if now-self.navigation_unavailable_since<3 then self:status("navigation_reconnecting");return end
  self:stop_motion(true);self:status("navigation_unavailable");return
 end
 self.navigation_unavailable_since=nil
 if target then
  self.last_combat_position={x=target_position.x,y=target_position.y,z=target_position.z}
  self.combat_reacquire_until=now+1.25
 elseif self.combat_reacquire_until and now<self.combat_reacquire_until then
  -- Brief LoS/object-list gaps must not restart mounting or objective travel.
  self:stop_motion(true)
  if self.last_combat_position and a.face then a.face(self.last_combat_position) end
  self:status("combat_reacquiring");return
 end
 if target and now>=self.next_target then
  local guid=target_guid(target)
  self.next_target=now+1;a.target(target)
  self.owned_target_guid=guid
 elseif not target then
   local defeated=false
   if self.combat_hold_target then pcall(function() defeated=self.combat_hold_target:is_dead()==true end) end
   if defeated then self.match_deaths=math.max(0,(self.match_deaths or 0)-1) end
   self.combat_hold_target=nil;self.combat_hold_guid=nil;self.combat_holding=nil
  self.combat_reacquire_until=nil;self.last_combat_position=nil
  self:clear_owned_target(player)
 end
  -- Native game-object equality can throw after an object despawns. Compare a
  -- copied GUID instead so stale combat objects cannot crash any battleground.
  local hold_guid=target_guid(target)
  if hold_guid~=self.combat_hold_guid then
  -- Cancel callbacks and paths aimed at the previous objective or enemy before
  -- steering toward the new target. This also removes the former 0.75-second
  -- pause when combat begins or priority switches to a healer.
  if self.destination then self:stop_motion(true) end
   self.combat_hold_target=target;self.combat_hold_guid=hold_guid;self.combat_holding=false;self.next_move=0;self.progress:reset()
 end
 -- Combat is allowed to interrupt a retry delay left by objective navigation.
 -- Otherwise a failed path can leave a valid nearby enemy unanswered for seconds.
 if target then self.navigation_retry_at=0 end
 if not target and not self.path_blocked_position and not self.mounted_escape and now<(self.navigation_retry_at or 0) then
  self:status("navigation_retry_wait");return
 end
 local goal=Snapshot.position(plan.position)
 -- A verified enemy inside the objective engagement area temporarily owns
 -- movement. Continuing an objective corridor while the rotation is trying to
 -- attack causes running past targets, repeated turning and target loss.
 if target then goal=target_position end
 if not goal then self:stop_motion();self:status("movement_destination_invalid");return end
 if target and a.face then a.face(target_position) end
 if self.mounted_escape then
  local escape=self.mounted_escape
  if now<escape.start_at then self:status("mounted_recovery_dismounting");return end
  if not escape.started then
   if not a.recovery_step or a.recovery_step(escape.goal)==false then
    self.mounted_escape=nil;self.navigation_retry_at=now+3
    self:status("mounted_recovery_step_unavailable");return
   end
   escape.started=true
  end
  if now<escape.stop_at then self:status("mounted_recovery_stepping_clear");return end
  a.recovery_step(nil);self.mounted_escape=nil
  self.navigation_retry_at=now+0.25;self:status("mounted_recovery_replanning");return
 end
 -- Use the mount for long field approaches, including distant combat targets.
 -- Keep authored rooms, ramps and short approaches on foot, then dismount early
 -- enough for the combat plugin to begin its normal ranged/melee approach.
 local warsong_room=snapshot.rule_profile=="warsong" and pos.x>=900 and pos.x<1075 and
  pos.y>=1350 and pos.y<=1495 and pos.z>=323
 local target_travel_distance=target and Planner.distance(pos,goal) or nil
 local combat_dismount_range=snapshot.damage_style=="ranged" and 48 or 24
 local warsong_field=snapshot.rule_profile=="warsong" and pos.x>=1080 and pos.x<=1495 and pos.z<325 and
  goal.x>=1080 and goal.x<=1495 and goal.z<325
 local route_avoids_mount=type(plan.route)=="table" and plan.route.avoid_mount==true and not warsong_field
 if target and target_travel_distance<=combat_dismount_range and
  type(player.is_mounted)=="function" and player:is_mounted() and a.ensure_on_foot then
  self:stop_motion(true)
  if a.ensure_on_foot(player,"combat_target",now) then
   self.navigation_retry_at=now+0.2;self:status("combat_dismounting");return
  end
 end
 if not target and plan.object and Planner.distance(pos,plan.position)<=12 and
  type(player.is_mounted)=="function" and player:is_mounted() and a.ensure_on_foot then
  self:stop_motion(true)
  if a.ensure_on_foot(player,"objective_interaction",now) then
   self.navigation_retry_at=now+0.2;self:status("objective_dismounting");return
  end
 end
 if route_avoids_mount and
  type(player.is_mounted)=="function" and player:is_mounted() and a.ensure_on_foot then
  self:stop_motion(true)
  if a.ensure_on_foot(player,plan.route.source or "authored_corridor",now) then
   self.navigation_retry_at=now+0.2;self:status("route_dismounting");return
  end
 end
 if fallback_direct and type(player.is_mounted)=="function" and player:is_mounted() and a.ensure_on_foot then
  self:stop_motion(true)
  if a.ensure_on_foot(player,"bounded_offmesh_corridor",now) then
   self.navigation_retry_at=now+0.2;self:status("route_dismounting");return
  end
 end
 local long_combat_approach=target and target_travel_distance>=60
 if a.try_mount and (not target or long_combat_approach) and not snapshot.carrying and not warsong_room and
  not fallback_direct and
  not route_avoids_mount and
  not player:is_casting_spell() and not player:is_channelling_spell() then
  local mounting=a.try_mount(player,now,Planner.distance(pos,goal))
  if mounting then self:status("mounting");return end
 end
  local scope=route_scope(self.settings)
 local route_identity=tostring(route_lock or (tostring(plan.kind)..":"..tostring(plan.id)))
 local route_key=self.predictive:route_key(scope,snapshot.rule_profile,snapshot.team,self.spawn_key,route_identity)
 if self.route_key~=route_key then
  if self.route_key then self:stop_motion(true) end
  local resume_radius=type(plan.route)=="table" and plan.route.waypoint_radius or 18
  local resume_index=type(plan.route)=="table" and type(plan.route.lock_id)=="string" and
   RouteProgress.resume_index(pos,plan.route,resume_radius) or 1
  self.route_key=route_key;self.route_index=resume_index
  local prior=type(plan.route)=="table" and resume_index>1 and plan.route[resume_index-1] or nil
  self.route_leg_origin=prior and {x=prior.x,y=prior.y,z=prior.z} or {x=pos.x,y=pos.y,z=pos.z}
  self.locked_route=plan.route
 elseif self.locked_route then
  -- Route generation uses the current player position. Replacing the array on
  -- every tick while retaining route_index changes the meaning of that index
  -- and can send every battleground route back toward its spawn. Freeze the
  -- authored sequence until this objective changes or the route completes.
  local switch,new_length,old_length=Predictive.shadow_switch(pos,self.locked_route,self.route_index,plan.route)
  if switch then
   self:stop_motion(true);self.locked_route=plan.route;self.route_index=1;self.route_leg_origin={x=pos.x,y=pos.y,z=pos.z}
   self.predictive:event("shadow_route_selected",{old=old_length,new=new_length,key=route_key},now)
  else plan.route=self.locked_route end
 end
 local function leg_id(point,index)
  return route_key..":"..tostring(index or self.route_index or 0)..":"..
   tostring(math.floor(point.x+0.5))..":"..tostring(math.floor(point.y+0.5))
 end
 if not target and type(plan.route)=="table" and #plan.route>0 then
  self.route_index=math.max(1,math.min(self.route_index or 1,#plan.route+1))
  -- Corridor and elevation waypoints require actual three-dimensional arrival.
  -- Passing their X coordinate alone does not prove the corner was traversed.
  local waypoint_radius=tonumber(plan.route.waypoint_radius) or 18
  waypoint_radius=math.max(2,math.min(18,waypoint_radius))
  while self.route_index<=#plan.route do
   local waypoint=plan.route[self.route_index]
   local mounted=type(player.is_mounted)=="function" and player:is_mounted()==true
   local leg_radius=RouteProgress.adaptive_radius(plan.route,self.route_index,self.route_leg_origin,waypoint_radius,mounted)
   local reached,proof=RouteProgress.reached(pos,waypoint,self.route_leg_origin,leg_radius)
   if not reached then break end
   local completed=leg_id(waypoint,self.route_index)
   local memory=self.route_memory[completed] or {successes=0,failures=0}
   memory.successes=(memory.successes or 0)+1;memory.failures=math.max(0,(memory.failures or 0)-1);memory.last_success=now
   if self.match_entered_at and now-self.match_entered_at<=90 then memory.opening_successes=(memory.opening_successes or 0)+1 end
   self.route_memory[completed]=memory;self.blocked_legs[completed]=nil;self.predictive:route_result(completed,true)
   if a.route_memory_event then a.route_memory_event(proof=="passed" and "route_leg_passed" or "route_leg_proven",completed,memory) end
   self:stop_motion(true);self.route_leg_origin={x=waypoint.x,y=waypoint.y,z=waypoint.z};self.route_index=self.route_index+1
  end
  if self.route_index>#plan.route then self.locked_route=nil;self.route_leg_origin=nil end
  if self.route_index<=#plan.route then goal=Snapshot.position(plan.route[self.route_index]) or goal end
 end
 local current_leg=leg_id(goal)
 local timeout_leg=route_key..":"..tostring(self.route_index or 0)
 if self.path_timeout_leg~=timeout_leg then
  self.path_timeout_leg=timeout_leg;self.path_timeout_count=0;self.awaiting_path_since=nil
 end
 local blocked=self.blocked_legs[current_leg]
 if blocked and now>=blocked.expires then self.blocked_legs[current_leg]=nil;blocked=nil end
 local learned=self.route_memory[current_leg]
 -- Reject a persistent detour learned on another terrain layer. Matching X/Y
 -- does not make a point above or below the player safely reusable.
 local learned_local=learned and learned.detour and Planner.distance(pos,learned.detour)<=40 and
  math.abs(pos.z-learned.detour.z)<=3
 local detour_leg=false
 -- Sentinel routes use Sentinel's own replan and obstacle context, matching
 -- the 1-90 movement watcher. Synthetic side coordinates are reserved for a
 -- verified local/direct corridor where no navmesh route exists.
 if direct_route and learned_local and not self.learned_passed[current_leg] then
  if Planner.distance(pos,learned.detour)<=3 then
   self.learned_passed[current_leg]=true;self:stop_motion(true)
  else
   goal={x=learned.detour.x,y=learned.detour.y,z=learned.detour.z};detour_leg=true
  end
 elseif direct_route and blocked and not blocked.detour_complete then
  if not blocked.detour then
   local dx,dy=goal.x-pos.x,goal.y-pos.y;local length=math.sqrt(dx*dx+dy*dy)
   if length>0.1 then
    local side=blocked.side or 1
    blocked.detour={x=pos.x+dx/length*6-dy/length*10*side,
     y=pos.y+dy/length*6+dx/length*10*side,z=pos.z}
   end
  end
  if blocked.detour and Planner.distance(pos,blocked.detour)<=3 then
   blocked.detour_complete=true;self.learned_passed[current_leg]=true
   local memory=self.route_memory[current_leg] or {successes=0}
   memory.detour={x=blocked.detour.x,y=blocked.detour.y,z=blocked.detour.z}
   memory.successes=memory.successes+1;memory.last_success=now
   self.route_memory[current_leg]=memory
   if a.route_memory_event then a.route_memory_event("route_detour_learned",current_leg,memory) end
   self.destination=nil;self.progress:reset()
  elseif blocked.detour then goal=blocked.detour;detour_leg=true end
 end
 -- Intermediate graph points are corridor controls and must be reached closely.
 -- The wider healer formation radius applies only to the final destination.
 local on_route_leg=not target and type(plan.route)=="table" and self.route_index and self.route_index<=#plan.route
 local mounted=type(player.is_mounted)=="function" and player:is_mounted()==true
 local route_leg_radius=on_route_leg and RouteProgress.adaptive_radius(plan.route,self.route_index,self.route_leg_origin,
  tonumber(plan.route.waypoint_radius) or 18,mounted) or nil
 local combat_range=tonumber(self.settings.combat_range()) or 5
 local ranged_combat=target and snapshot.player_role=="damage" and snapshot.damage_style=="ranged"
 if ranged_combat then
  combat_range=math.max(combat_range,25)
 elseif target then
  -- A manually enlarged generic range must not make melee/tanks stop outside
  -- actual attack reach. Their movement closes to a dependable four yards.
  combat_range=math.min(combat_range,4)
 end
 combat_range=math.max(3,math.min(35,combat_range))
 if target and self.combat_holding then
  -- Use a real release buffer after reaching attack range. Sub-yard jitter in
  -- target positions was toggling approach/hold many times per second.
  combat_range=math.min(40,combat_range+(ranged_combat and 4 or 2.5))
 end
 local range=detour_leg and 3 or on_route_leg and route_leg_radius or
  (target and combat_range or
   math.max(plan.arrival_radius or 3,plan.object and (plan.interaction_radius or 5) or 0))
 local goal_distance=Planner.distance(pos,goal)
 local activity_nav_state=a.navigation_full_state and a.navigation_full_state()
 local activity_waiting=type(activity_nav_state)=="string" and activity_nav_state:find("awaiting_path",1,true)~=nil
 if not target and goal_distance>range and not activity_waiting then
  local activity_reset=not self.activity_position or not self.activity_goal or
   Planner.distance(self.activity_position,pos)>=1 or Planner.distance(self.activity_goal,goal)>8 or
   not self.activity_at or now<self.activity_at
  if activity_reset then
   self.activity_position={x=pos.x,y=pos.y,z=pos.z};self.activity_goal={x=goal.x,y=goal.y,z=goal.z}
   self.activity_at=now;self.activity_recoveries=0
  elseif now-self.activity_at>=15 then
   self.activity_at=now;self.activity_recoveries=(self.activity_recoveries or 0)+1
   self:stop_motion(true);self.destination=nil;self.next_move=0;self.progress:reset()
   if self.activity_recoveries>=2 and a.escape_direction then
    local direction=(self.escape_side or 1)>0 and "right" or "left"
    self.escape_side=-(self.escape_side or 1);a.escape_direction(direction);self.escape_until=now+0.6
    self:status("navigation_activity_escape_"..direction);return
   end
   if a.replan then a.replan("battleground_activity_watchdog") end
   self:status("navigation_activity_recovery");return
  end
 else
  self.activity_position=nil;self.activity_goal=nil;self.activity_at=nil;self.activity_recoveries=0
 end
 if goal_distance>range then
  if self.reverse_until then
   if now<self.reverse_until then self:status("navigation_reverse_rebound");return end
   if a.reverse_rebound then a.reverse_rebound(nil) end
   self.reverse_until=nil;self.destination=nil;self.progress:reset();self.stall_count=0
   if a.replan then a.replan("battleground_reverse_rebound_complete") end
   self.navigation_retry_at=now+(direct_route and 0.1 or 0.25)
   self:status("navigation_replanning");return
  end
  if self.escape_until then
   if now<self.escape_until then self:status("navigation_directional_escape");return end
   if a.escape_direction then a.escape_direction(nil) end
   self.escape_until=nil;self.destination=nil;self.progress:reset()
   if a.replan then a.replan("battleground_directional_escape_complete") end
   self.navigation_retry_at=now+(direct_route and 0.1 or 0.25)
   self:status("navigation_replanning");return
  end
  local nav_state=a.navigation_state and a.navigation_state()
  local nav_full_state=a.navigation_full_state and a.navigation_full_state()
  if self.destination and not direct_route and type(a.navigation_destination)=="function" then
   local displaced,detail=self.nav_ownership:observe(self.destination,a.navigation_destination(),nav_state)
   if displaced then
    if a.route_memory_event then a.route_memory_event("navigation_destination_displaced",current_leg,detail) end
    self:stop_motion(true);self.navigation_retry_at=now+0.1;self.next_move=0
    self:status("navigation_destination_reclaiming");return
   end
  else self.nav_ownership:reset(false) end
  if self.destination and not direct_route and type(a.navigation_progress)=="function" then
   local stalled,detail=self.nav_progress:observe(a.navigation_progress(),nav_full_state or nav_state,goal,now)
   if stalled then
    if a.replan then a.replan("battleground_waypoint_progress_stalled") end
    self.destination=nil;self.navigation_retry_at=now+0.25;self.progress:reset();self.advancement:reset()
    if a.route_memory_event then a.route_memory_event("navigation_waypoint_progress_stalled",current_leg,detail) end
    self:status("navigation_progress_replanning");return
   end
  else self.nav_progress:reset(false) end
  if self.destination and not direct_route and type(a.navigation_path)=="function" then
   local path=a.navigation_path();local index=type(a.navigation_path_index)=="function" and a.navigation_path_index() or 1
   local widths=type(a.navigation_corridor_widths)=="function" and a.navigation_corridor_widths() or nil
   local deviated,deviation=self.path_corridor:observe(pos,path,index,widths)
   if deviated then
    if a.route_memory_event then a.route_memory_event("navigation_corridor_deviation",current_leg,deviation) end
    self:stop_motion(true);self.destination=nil;self.navigation_retry_at=now+0.7
    self.progress:reset();self.advancement:reset()
    if a.replan then a.replan("battleground_corridor_deviation") end
    self:status("navigation_corridor_replanning");return
   end
   local narrow=PathPreflight.narrow(widths,index,4,1.8)
   if narrow and type(player.is_mounted)=="function" and player:is_mounted() and a.ensure_on_foot and
    a.ensure_on_foot(player,"predicted_narrow_corridor:"..tostring(narrow.width),now) then
    self.destination=nil;self.navigation_retry_at=now+0.25;self.progress:reset();self.advancement:reset()
    if a.route_memory_event then a.route_memory_event("mounted_narrow_corridor_predicted",current_leg,narrow) end
    self:status("mounted_narrow_corridor_dismounting");return
   end
   local vertical=PathPreflight.vertical_hazard(path,index,4)
   if vertical and vertical.signature~=self.path_preflight_signature then
    self.path_preflight_signature=vertical.signature
    self.path_preflight_attempts=(self.path_preflight_attempts or 0)+1
    if a.route_memory_event then a.route_memory_event("navigation_vertical_hazard_predicted",current_leg,
     {index=vertical.index,horizontal=vertical.horizontal,vertical=vertical.vertical,attempt=self.path_preflight_attempts}) end
    if a.replan and a.replan("battleground_vertical_hazard") then
     self.destination=nil;self.navigation_retry_at=now+0.2;self.progress:reset();self.advancement:reset()
     self:status("navigation_vertical_hazard_replanning");return
    end
   end
   local loop=PathPreflight.inspect(path,index)
   if loop and loop.signature~=self.path_preflight_signature then
    self.path_preflight_signature=loop.signature
    self.path_preflight_attempts=(self.path_preflight_attempts or 0)+1
    if a.route_memory_event then a.route_memory_event("navigation_trackback_predicted",current_leg,
     {index=loop.index,excursion=loop.excursion,attempt=self.path_preflight_attempts}) end
    if self.path_preflight_attempts<=2 and a.replan and a.replan("battleground_path_trackback") then
     self:status("navigation_trackback_replanning");return
    end
   elseif not loop then
    self.path_preflight_signature=nil
   end
  end
  if self.destination and (nav_state=="arrived" or nav_full_state=="arrived") then
   local same=self.premature_goal and Planner.distance(self.premature_goal,goal)<=4
   self.premature_arrivals=same and (self.premature_arrivals or 0)+1 or 1
   self.premature_goal={x=goal.x,y=goal.y,z=goal.z}
   if self.premature_arrivals>=2 and self:recover_mounted(pos,goal,now,"premature_arrival") then return end
   self:stop_motion(true)
   local ramp_near=PathCorridor.ramp_near(pos,
    type(a.navigation_path)=="function" and a.navigation_path() or nil,
    type(a.navigation_path_index)=="function" and a.navigation_path_index() or 1)
   if self.premature_arrivals>=3 and not ramp_near and a.reverse_rebound then
    local dx,dy=goal.x-pos.x,goal.y-pos.y;local length=math.sqrt(dx*dx+dy*dy)
    if length>0.1 and a.reverse_rebound({x=pos.x-dx/length*4,y=pos.y-dy/length*4,z=pos.z})~=false then
     self.reverse_until=now+0.8;self.navigation_retry_at=now
     self.premature_arrivals=0
     self:status("navigation_arrival_reverse_recovery");return
    end
   end
   local cooldown=self.premature_arrivals>=3 and 10 or 0.5
   self.navigation_retry_at=now+cooldown
   if a.replan then a.replan("battleground_arrived_outside_range") end
   if a.route_memory_event then a.route_memory_event("navigation_premature_arrival",current_leg,
    {distance=Planner.distance(pos,goal),attempts=self.premature_arrivals}) end
   self:status(self.premature_arrivals>=3 and "navigation_arrival_retry_backoff" or "navigation_arrival_replanning");return
  end
  if type(nav_full_state)=="string" and nav_full_state:find("awaiting_path",1,true) then
   self.awaiting_path_since=self.awaiting_path_since or now
   if now-self.awaiting_path_since>=8 then
    if self:recover_mounted(pos,goal,now,"path_timeout") then return end
    self:stop_motion(true);self.destination=nil;self.navigation_retry_at=now+0.5

    self.awaiting_path_since=nil
    self.path_timeout_count=(self.path_timeout_count or 0)+1
    if not plan.route and snapshot.formation_fallback==true and type(a.route_for)=="function" then
     self.force_graph_until=now+60;self.navigation_retry_at=now+0.25
     self:status("navigation_local_graph_fallback");return
    end
    if type(plan.route)=="table" and #plan.route>0 and goal_distance<=50 and
     math.abs(goal.z-pos.z)<=8 and
     plan.route.allow_direct_fallback==true and
     type(a.move_direct)=="function" then
     -- Sentinel v0.23 returns HTTP 422 on battlegrounds without a server
     -- navmesh. Fall back only to the current authored graph leg, never to a
     -- continuously changing raw teammate chase.
     self.direct_route_fallback[fallback_scope]=math.max(self.direct_route_fallback[fallback_scope] or 0,
      now+(self.path_timeout_count>=2 and 120 or 20))
     -- Scope the circuit breaker to this authored corridor. A failure at one
     -- doorway must not switch every route in the battleground to raw steering.
     if self.path_timeout_count>=2 then
      if a.route_memory_event then
       a.route_memory_event("navigation_corridor_direct_fallback",fallback_scope,
        {timeouts=self.path_timeout_count})
      end
     end
     self.navigation_retry_at=now+0.25
     self:status("navigation_waypoint_fallback");return
    end
    if self.path_timeout_count>=2 then
     self.path_blocked_position={x=pos.x,y=pos.y,z=pos.z};self.path_probe_at=now+30
     self.navigation_retry_at=0
     self:status("navigation_mesh_probe_wait");return
    end
    self:status("navigation_path_timeout");return
   end
  else
   self.awaiting_path_since=nil
   -- A brief following_path state can be emitted before Sentinel reports
   -- HTTP 422. Preserve the timeout history for this match; completed legs
   -- and match reset remain the reliable recovery boundaries.
  end
  local watchdog_active=type(nav_full_state)~="string" or nav_full_state=="navigating" or nav_full_state=="idle" or nav_full_state=="failed" or
   nav_full_state:find("following_path",1,true)~=nil
  -- Authored graph legs use local steering and can recover immediately.  The
  -- remote navigator keeps the longer grace period because it may pause while
  -- accepting a path.  A half-yard movement threshold catches doorway and
  -- terrain collisions without treating ordinary forward motion as a stall.
  local direct_stall_timeout=1.25
  local stalled=watchdog_active and self.progress:stalled(pos,goal,now,
   target and 1.5 or direct_route and direct_stall_timeout or 7,
   target and 0.5 or direct_route and 0.5 or 1) or false
  local position_stalled=stalled
  local no_forward_progress=not target and watchdog_active and self.advancement:stalled(pos,goal,now,
   direct_route and 2.5 or 10,direct_route and 0.75 or 2) or false
  local forward_only=no_forward_progress and not position_stalled
  if no_forward_progress then stalled=true end
  if not watchdog_active then self.progress:reset();self.advancement:reset() end
  if self.progress.moved then self.stall_count=0 end
  if stalled and self.destination and a.replan then
   -- The precise movement watchdog is already recovering this stall. Restart
   -- the broad activity timer so it cannot fire over the next recovery stage.
   self.activity_position={x=pos.x,y=pos.y,z=pos.z};self.activity_goal={x=goal.x,y=goal.y,z=goal.z};self.activity_at=now
   if target then
    self:stop_motion(true)
    if a.escape_direction then
     local direction=(self.escape_side or 1)>0 and "right" or "left"
     self.escape_side=-(self.escape_side or 1);a.escape_direction(direction);self.escape_until=now+0.45
     self.navigation_retry_at=now;self:status("combat_path_escape_"..direction);return
    end
    self.navigation_retry_at=now+0.2;self:status("combat_path_replanning");return
   end
   if self:recover_mounted(pos,goal,now,forward_only and "no_forward_progress" or "position_stalled") then return end
   self.stall_count=(self.stall_count or 0)+1
   -- Small doodads and lips are often cleared more safely by one jump than by
   -- replacing the route. Keep this as the first bounded recovery stage.
   if self.stall_count==1 and a.recovery_jump and a.recovery_jump() then
    if a.replan then a.replan("battleground_jump_recovery") end
    self.navigation_retry_at=now+0.8;self:status("navigation_jump_recovery");return
   end
   local reverse_threshold=direct_route and 2 or 3
   local escape_threshold=direct_route and 1 or 2
   local recovery_ramp=PathCorridor.ramp_near(pos,
    type(a.navigation_path)=="function" and a.navigation_path() or nil,
    type(a.navigation_path_index)=="function" and a.navigation_path_index() or 1)
   if self.stall_count>=reverse_threshold and not recovery_ramp and a.reverse_rebound then
    local dx,dy=goal.x-pos.x,goal.y-pos.y
    local length=math.sqrt(dx*dx+dy*dy)
    if length>0.1 then
     local behind={x=pos.x-dx/length*6,y=pos.y-dy/length*6,z=pos.z}
     if a.reverse_rebound(behind)~=false then
      local previous=self.blocked_legs[current_leg]
      self.blocked_legs[current_leg]={expires=now+3600,side=self.escape_side or 1,failures=(previous and previous.failures or 0)+1}
      self.route_memory[current_leg]=nil
      self:note_leg(current_leg,goal,profile_key)
      self:request_reroute(plan)
      if a.route_memory_event then a.route_memory_event("route_leg_blacklisted",current_leg,self.blocked_legs[current_leg]) end
      self.reverse_until=now+1.1;self:status("navigation_reverse_rebound");return
     end
    end
   end
   if self.stall_count>=escape_threshold then
    if a.escape_direction then
     local probed=type(a.obstacle_escape_side)=="function" and a.obstacle_escape_side(pos,goal) or nil
     local direction=probed or ((self.escape_side or 1)>0 and "right" or "left")
     self.escape_side=-(self.escape_side or 1)
     local duration=direct_route and 0.55 or 0.9
     a.escape_direction(direction);self.escape_until=now+duration
     self:status("navigation_rebound_"..direction);return
    end
    if direct_route then
     a.replan("battleground_direct_stall");self:status("navigation_replanning");return
    end
    self:stop_motion(true);self.navigation_retry_at=now+1
    self:status("navigation_recovering");return
   end
   a.replan(forward_only and "battleground_no_forward_progress" or "battleground_no_position_progress")
   self:status(forward_only and "navigation_wrong_way_recovery" or "navigation_replanning");return
  end
  -- Moving objectives and formation anchors can shift every update. Keep the
  -- current path for a short window instead of cancelling and rebuilding it
  -- for every few yards of target movement.
  local move_due=now>=(self.next_move or 0)
  local full_state=tostring(nav_full_state or ""):lower()
  local nav_active=nav_state=="navigating" or full_state:find("navigating",1,true)~=nil or
   full_state:find("following_path",1,true)~=nil or full_state:find("awaiting_path",1,true)~=nil
  -- Detour corridors are most stable when a client does not replace an active
  -- request for every small target adjustment. Preserve the live combat path
  -- until the predicted target has moved meaningfully, while local/direct
  -- steering retains its fast facing updates.
  local remote_combat=target and not combat_direct and not direct_route
  local refresh_distance=remote_combat and (ranged_combat and 12 or 8) or 4
  if not self.destination or move_due and (Planner.distance(self.destination,goal)>refresh_distance or not nav_active) then
   if player:is_casting_spell() or player:is_channelling_spell() then
    self:status(plan.kind);return
   end
   self.epoch=self.epoch+1;local epoch=self.epoch
   self.destination={x=goal.x,y=goal.y,z=goal.z};self.next_move=now+(remote_combat and (ranged_combat and 2.5 or 2) or target and 1.25 or direct_route and 0.6 or 5)
   local mover=(direct_route or combat_direct) and a.move_direct or target and a.move_combat or a.move
   mover=mover or a.move
   local provider_name=type(a.navigation_provider)=="function" and a.navigation_provider() or (direct_route and "direct" or "active")
   local dispatched_at=now
   mover(self.destination,function(ok,err)
    if epoch~=self.epoch then return end
    local provider_health=self.predictive:provider_result(provider_name,ok==true,math.max(0,a.time()-dispatched_at),a.time())
    if type(a.quarantine_navigation_provider)=="function" then
     a.quarantine_navigation_provider(provider_name,ok==true and 0 or provider_health.cooldown or 0)
    end
    if not ok then
     self.destination=nil;self.navigation_retry_at=a.time()+3
     local message=tostring(err or "unknown")
     local mmap_error=MMapError.classify(message)
     local severe=mmap_error.severe
     local rerouted_now=false
     if severe then
      local memory=self.route_memory[current_leg] or {successes=0,failures=0}
      memory.failures=(memory.failures or 0)+1;self.route_memory[current_leg]=memory
      self.predictive:route_result(current_leg,false)
      self:note_leg(current_leg,goal,profile_key)
      if memory.failures>=2 then
       self.blocked_legs[current_leg]={expires=a.time()+300,side=self.escape_side or 1,failures=memory.failures}
       rerouted_now=self:request_reroute(plan)
      end
      if a.route_memory_event then
       memory.recovery_stage=Predictive.recovery_stage(memory.failures-1)
       a.route_memory_event("route_leg_failed",current_leg,memory)
      end
     end
     if severe and not plan.route and snapshot.formation_fallback==true then
      self.force_graph_until=a.time()+60;self.navigation_retry_at=a.time()+0.25
      self:status("navigation_local_graph_fallback");return
     end
     local bounded_authored=plan.route and plan.route.allow_direct_fallback==true and
      on_route_leg and goal_distance<=50 and math.abs(goal.z-pos.z)<=8
     local bounded_offmesh=message:find("height_projection_unavailable",1,true) and
      on_route_leg and goal_distance<=50 and math.abs(goal.z-pos.z)<=8
     -- A missing/incompatible map or tile will not improve after a retry. Use
     -- the same short, authored, height-bounded escape corridor immediately;
     -- never apply this to a long or steep unscripted destination.
     local bounded_missing_mesh=(mmap_error.category=="coverage" or mmap_error.category=="format") and
      on_route_leg and goal_distance<=50 and math.abs(goal.z-pos.z)<=8
     if severe and type(plan.route)=="table" and #plan.route>0 and
      (bounded_authored or bounded_offmesh or bounded_missing_mesh) and
      type(a.move_direct)=="function" then
      self.path_timeout_count=(self.path_timeout_count or 0)+1
      self.direct_route_fallback[fallback_scope]=a.time()+120
      if a.route_memory_event then
       a.route_memory_event("navigation_corridor_direct_fallback",fallback_scope,
        {timeouts=self.path_timeout_count,error=message,error_category=mmap_error.category})
      end
      -- The remote service has already proved that this battleground endpoint
      -- has no usable height projection. Retry the same short authored leg by
      -- local steering on the next tick instead of idling for three seconds.
      self.navigation_retry_at=a.time()+0.15
     end
     if severe and self:recover_mounted(pos,goal,a.time(),"path_failure:"..message) then return end
     if severe and rerouted_now then
      -- The corridor was just replaced by one that avoids this leg; try it right
      -- away instead of idling in the 30-second mesh probe wait.
      self:stop_motion(true);self.navigation_retry_at=a.time()+0.5
      self:status("navigation_rerouting_around_failed_leg");return
     end
     if severe and not (tonumber(self.direct_route_fallback[fallback_scope]) and a.time()<self.direct_route_fallback[fallback_scope]) then
      self:stop_motion(true)
      self.path_blocked_position={x=pos.x,y=pos.y,z=pos.z};self.path_probe_at=a.time()+30
      self.navigation_retry_at=0
      self:status("navigation_mesh_probe_wait");return
     end
     self:status("navigation_failed:"..message)
    end
   end)
   if (self.navigation_retry_at or 0)>now then return end
  end
  self:status(detour_leg and "navigation_blacklist_detour" or target and "combat_approaching" or plan.kind)
 else
  self.premature_arrivals=0;self.premature_goal=nil
  if target then self.combat_holding=true end
  self:stop_motion(true)
  if target and a.face then a.face(target_position) end
  local interaction_key=plan.object and (tostring(plan.kind)..":"..tostring(plan.id or "")) or nil
  if interaction_key~=self.interaction_key then
   self.interaction_key=interaction_key;self.interaction_failures=0;self.interaction_retry_at=0;self.interaction_pending_until=nil
  end
  if plan.object and not target and now<(self.interaction_pending_until or 0) then
   if a.face then a.face(goal) end
   self:status("objective_interaction_confirming");return
  end
  if plan.object and not target and now<(self.interaction_retry_at or 0) then
   self:status("objective_interaction_retry");return
  end
  self:status(target and "combat_holding" or plan.object and "using_objective" or plan.kind)
  if plan.object and not target and now>=self.next_action then
   if a.face then a.face(goal) end
   local accepted,interaction_error=a.interact(plan.object)
   if accepted then
    self.interaction_failures=0;self.interaction_retry_at=0;self.interaction_pending_until=now+2.5;self.next_action=self.interaction_pending_until
    if a.route_memory_event then a.route_memory_event("objective_interaction_dispatched",interaction_key,{confirm_until=self.interaction_pending_until}) end
   else
    if a.route_memory_event then a.route_memory_event("objective_interaction_refused",interaction_key,{reason=tostring(interaction_error or "unknown")}) end
    self.interaction_failures=(self.interaction_failures or 0)+1
    if self.interaction_failures>=3 then
     self.interaction_retry_at=now+4;self.next_action=self.interaction_retry_at
     self:status("objective_interaction_retry")
    else self.next_action=now+0.5 end
   end
   -- Dispatch is not proof of capture. Re-read the snapshot next tick.
  end
 end
end
return C
