local M={};M.__index=M
local function dist(a,b) if not a or not b then return math.huge end;return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function M.new() return setmetatable({active=nil,last_position=nil,last_time=nil,last_state=nil,last_plan=nil,pending_runtime_errors=0,pending_route_legs=0,pending_mounted_route_legs=0,pending_route_leg_ids={},pending_objective_attempts=0,pending_objective_key=nil},M) end
function M:note_runtime_error(in_bg)
 if in_bg~=true then return end
 if self.active then self.active.runtime_errors=(self.active.runtime_errors or 0)+1
 else self.pending_runtime_errors=(self.pending_runtime_errors or 0)+1 end
end
function M:note_route_leg(in_bg,leg,mounted)
 if in_bg~=true then return end
 local key=tostring(leg or "")
 if self.active then
  self.active.route_legs=(self.active.route_legs or 0)+1
  if mounted==true then self.active.mounted_route_legs=(self.active.mounted_route_legs or 0)+1 end
  if key~="" then self.active.route_leg_ids[key]=true end
 else
  self.pending_route_legs=(self.pending_route_legs or 0)+1
  if mounted==true then self.pending_mounted_route_legs=(self.pending_mounted_route_legs or 0)+1 end
  if key~="" then self.pending_route_leg_ids[key]=true end
 end
end
function M:note_objective_attempt(in_bg,key)
 if in_bg~=true then return end
 if self.active then self.active.objective_attempts=(self.active.objective_attempts or 0)+1;self.active.pending_objective_key=key
 else self.pending_objective_attempts=(self.pending_objective_attempts or 0)+1;self.pending_objective_key=key end
end
function M:tick(now,in_bg,profile,role,state,position,outcome,objective_source,plan_kind,faction,moving_expected,damage_style)
 -- Winner data can appear on the same update that the instance type changes.
 -- Preserve it before the out-of-battleground branch finalizes the record.
 if self.active and (outcome==0 or outcome==1 or outcome==2) then self.active.outcome=outcome end
 if in_bg and not self.active then
  self.last_plan=nil
  self.active={started=now,profile=profile or "unknown",role=role or "unknown",damage_style=damage_style or "unknown",faction=faction,deaths=0,path_failures=0,recoveries=0,runtime_errors=self.pending_runtime_errors or 0,objective_failures=0,objective_attempts=self.pending_objective_attempts or 0,objective_confirmations=0,pending_objective_key=self.pending_objective_key,route_legs=self.pending_route_legs or 0,mounted_route_legs=self.pending_mounted_route_legs or 0,route_leg_ids=self.pending_route_leg_ids or {},stationary=0,
   travel_stall=0,max_travel_stall=0,max_displacement=0,state_changes=0,engagements=0,combat_approaches=0,combat_holds=0,combat_reacquires=0,objective_changes=0}
  self.pending_runtime_errors=0;self.pending_route_legs=0;self.pending_mounted_route_legs=0;self.pending_route_leg_ids={};self.pending_objective_attempts=0;self.pending_objective_key=nil
 elseif not in_bg and self.active then
  local a=self.active;self.active=nil;self.last_position=nil;self.last_time=nil;self.last_state=nil;self.last_plan=nil
  local duration=math.max(0,now-a.started)
  local objective_data=a.live_seen and (a.fallback_seen and "mixed" or "live") or (a.fallback_seen and "formation_fallback" or "none")
  local unique_route_legs=0;for _ in pairs(a.route_leg_ids or {}) do unique_route_legs=unique_route_legs+1 end
  local summary=string.format("profile=%s role=%s damage_style=%s outcome=%s duration=%.1fs deaths=%d path_failures=%d recoveries=%d runtime_errors=%d objective_failures=%d objective_attempts=%d objective_confirmations=%d route_legs=%d mounted_route_legs=%d unique_route_legs=%d max_displacement=%.1f stationary=%.1fs max_travel_stall=%.1fs state_changes=%d engagements=%d combat_approaches=%d combat_holds=%d combat_reacquires=%d objective_changes=%d objective_data=%s",
   a.profile,a.role,tostring(a.damage_style or "unknown"),tostring(a.outcome or "unknown"),duration,a.deaths,a.path_failures,a.recoveries,a.runtime_errors or 0,a.objective_failures or 0,a.objective_attempts or 0,a.objective_confirmations or 0,a.route_legs or 0,a.mounted_route_legs or 0,unique_route_legs,a.max_displacement or 0,a.stationary,a.max_travel_stall or 0,a.state_changes,
   a.engagements,a.combat_approaches or 0,a.combat_holds or 0,a.combat_reacquires or 0,a.objective_changes,
   objective_data)
  return summary,{profile=a.profile,role=a.role,damage_style=a.damage_style,faction=a.faction,outcome=a.outcome,duration=duration,deaths=a.deaths,
   path_failures=a.path_failures,recoveries=a.recoveries,runtime_errors=a.runtime_errors or 0,objective_failures=a.objective_failures or 0,objective_attempts=a.objective_attempts or 0,objective_confirmations=a.objective_confirmations or 0,route_legs=a.route_legs or 0,mounted_route_legs=a.mounted_route_legs or 0,unique_route_legs=unique_route_legs,max_displacement=a.max_displacement or 0,stationary=a.stationary,max_travel_stall=a.max_travel_stall or 0,state_changes=a.state_changes,
   engagements=a.engagements,combat_approaches=a.combat_approaches or 0,combat_holds=a.combat_holds or 0,combat_reacquires=a.combat_reacquires or 0,objective_changes=a.objective_changes,objective_data=objective_data}
 end
 local a=self.active;if not a then return end
 if position then
  if not a.start_position then a.start_position={x=position.x,y=position.y,z=position.z} end
  a.max_displacement=math.max(a.max_displacement or 0,dist(position,a.start_position))
 end
 -- Instance/map and faction APIs can be temporarily unavailable during the
 -- loading transition. Adopt the first valid identity, but never rewrite a
 -- match after it has converged.
 if (a.profile=="unknown" or a.profile=="none" or a.profile=="") and type(profile)=="string" and profile~="" and profile~="none" and profile~="unknown" then a.profile=profile end
 if (a.role=="unknown" or a.role=="") and type(role)=="string" and role~="" and role~="unknown" then a.role=role end
 if (a.damage_style=="unknown" or a.damage_style=="") and (damage_style=="melee" or damage_style=="ranged") then a.damage_style=damage_style end
 if a.faction~=0 and a.faction~=1 and (faction==0 or faction==1) then a.faction=faction end
 if a.pending_objective_key and plan_kind and plan_kind~=a.pending_objective_key then a.objective_confirmations=(a.objective_confirmations or 0)+1;a.pending_objective_key=nil end
 if plan_kind and plan_kind~=self.last_plan then a.objective_changes=a.objective_changes+1;self.last_plan=plan_kind end
 if outcome==0 or outcome==1 or outcome==2 then a.outcome=outcome end
 if objective_source=="live_objective_reader" then a.live_seen=true
 elseif objective_source=="team_formation_fallback" or objective_source=="static_objective_fallback" then a.fallback_seen=true end
 if state~=self.last_state then
  a.state_changes=a.state_changes+1
  if state=="waiting_resurrection" then a.deaths=a.deaths+1 end
  if tostring(state):find("combat_",1,true) and not tostring(self.last_state or ""):find("combat_",1,true) then a.engagements=a.engagements+1 end
  if state=="combat_approaching" then a.combat_approaches=(a.combat_approaches or 0)+1 end
  if state=="combat_holding" then a.combat_holds=(a.combat_holds or 0)+1 end
  if state=="combat_reacquiring" then a.combat_reacquires=(a.combat_reacquires or 0)+1 end
  local state_text=tostring(state)
  if state_text:find("navigation_path_timeout",1,true) or state_text:find("navigation_failed",1,true) or
   state_text:find("navigation_mesh_probe_wait",1,true) or state_text:find("navigation_unavailable",1,true) or
   state_text:find("navigation_local_graph_fallback",1,true) or state_text:find("navigation_waypoint_fallback",1,true) then
   a.path_failures=a.path_failures+1
  end
  if state_text:find("objective_interaction_retry",1,true) or state_text:find("objective_action_adapter_required",1,true) or
   state_text:find("objective_action_failed",1,true) then a.objective_failures=a.objective_failures+1;a.pending_objective_key=nil end
  if tostring(state):find("replanning",1,true) or tostring(state):find("rebound",1,true) then a.recoveries=a.recoveries+1 end
  self.last_state=state
 end
 if self.last_time and now>=self.last_time and now-self.last_time<=2 then
  local delta=now-self.last_time;local still=dist(position,self.last_position)<1
  if still then a.stationary=a.stationary+delta end
  if moving_expected==true and still then
   a.travel_stall=(a.travel_stall or 0)+delta;a.max_travel_stall=math.max(a.max_travel_stall or 0,a.travel_stall)
  else a.travel_stall=0 end
 end
 self.last_time=now;self.last_position=position and {x=position.x,y=position.y,z=position.z} or nil
end
function M:report()
 local a=self.active
 if not a then return "No active match" end
 return string.format("engagements=%d / holds=%d / reacquires=%d / objectives=%d / failures=%d / recoveries=%d / stationary=%.1fs / travel stall=%.1fs",
  a.engagements,a.combat_holds or 0,a.combat_reacquires or 0,a.objective_changes,a.path_failures,a.recoveries,a.stationary,a.max_travel_stall or 0)
end
return M
