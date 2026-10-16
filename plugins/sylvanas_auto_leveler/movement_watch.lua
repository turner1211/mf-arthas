-- Replanning uses the mesh server; never invent unverified XYZ detours.
local M={}
local Sequence
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function invoke(fn,...)
 if type(fn)~="function" then return false,"api_unavailable" end
 local ran,result=pcall(fn,...)
 if not ran then return false,tostring(result) end
 return result~=false,result
end
function M.new(api)
 local self={active=nil,epoch=0}
 function self:stop()
  if self.escape_until and api.strafe then api.strafe(nil) end
  self.escape_until=nil;self.awaiting_since=nil
  self.epoch=self.epoch+1;self.active=nil;api.stop()
 end
 local function distance(a,b)
  return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
 end
 local function mounted_clearance_failure(reason)
  local s=tostring(reason or ""):lower()
  return s:find("path",1,true) or s:find("route",1,true)
   or s:find("unreachable",1,true) or s:find("start_edge",1,true)
   or s:find("floor",1,true) or s:find("clearance",1,true)
   or s:find("arrival_out_of_range",1,true)
 end
 local function begin_dismount(job,reason,source)
  local now=api.time()
  -- Revoke the route callback that led here; late Sentinel completion must not
  -- clear the job while the client is changing movement mode.
  self.epoch=self.epoch+1
  job.mount_retry=true
  job.waiting_dismount={started=now,deadline=now+5,next_retry=now+1,reason=reason,source=source}
  job.anchor=copy(api.position());job.since=now;job.loop=nil
  invoke(api.stop)
  local accepted,error=invoke(api.dismount)
  self.recovery_until=now+60
  if api.log then api.log("mounted_route_dismount_requested",{reason=reason,source=source,accepted=accepted,
   error=not accepted and tostring(error) or nil}) end
 end
 function self:dispatch()
  local job=self.active;self.epoch=self.epoch+1;local epoch=self.epoch
  local destination=job.goal
  job.dispatch_position=copy(api.position())
  job.leg=nil;job.leg_mode=nil
  if job.sequence then
   job.advancement=job.advancement or require("route_advancement").new()
   local leg=job.sequence:next(api.position())
   if leg then destination=leg;job.leg=copy(leg);job.leg_mode="locked_corridor" end
  elseif not job.direct and api.next_leg then
   local ran,leg,mode=pcall(api.next_leg,api.position(),job.goal)
   if not ran then mode="short_leg_query_error:"..tostring(leg);leg=nil end
   if leg then destination=leg;job.leg=copy(leg);job.leg_mode=mode
   else
    -- A mounted collision envelope can reject a perfectly walkable doorway,
    -- slope, bridge edge, or NPC approach. Change locomotion mode before
    -- submitting the same blocked request to Sentinel.
    if not job.mount_retry and api.mounted() and not api.flying() then
     begin_dismount(job,mode or "mounted_short_leg_unavailable","short_leg_preflight")
     return
    end
    -- Local terrain sampling can fail at stairs, layered floors, or phased
    -- geometry. Preserve the destination and let Sentinel solve that section
    -- instead of failing the entire route.
    job.leg_mode="sentinel_fallback:"..tostring(mode)
    if api.log then api.log("navigation_route_mesh_fallback",{reason=mode}) end
   end
  end
  if api.log and distance(destination,job.goal)>3 then
   api.log("navigation_route_leg",{remaining=distance(api.position(),job.goal),leg_distance=distance(api.position(),destination),mode=job.leg_mode})
  end
  -- A measured short leg is already terrain- and clearance-checked. Dispatch
  -- it through the immediate close-range driver so every 12-yard leg does not
  -- wait for a remote full-route planning timeout.
  local mover=job.direct and api.move_direct or (job.leg and api.move_leg) or api.move
  local function completed(ok,reason)
   if self.active~=job or epoch~=self.epoch then return end
   local previous_index=job.sequence and job.sequence.index
   if ok and job.sequence and job.sequence:next(api.position()) then
    if job.sequence.index==previous_index then
     self.active=nil;api.stop();job.callback(false,"route_leg_arrival_unconfirmed");return
    end
    job.anchor=copy(api.position());job.since=api.time();self:dispatch();return
   end
   if ok and job.sequence and distance(api.position(),job.goal)>3 then
    self.active=nil;api.stop();job.callback(false,"route_final_arrival_unconfirmed");return
   end
   if not ok and not job.mount_retry and api.mounted() and not api.flying() and mounted_clearance_failure(reason) then
    begin_dismount(job,reason,"route_failure");return
   end
   if ok and job.leg and distance(api.position(),job.goal)>3 then
    if distance(api.position(),job.dispatch_position)<0.5 then
     self.active=nil;api.stop();job.callback(false,"short_leg_completed_without_movement");return
    end
    -- Keep the route-wide loop detector alive across successful short legs.
    job.anchor=copy(api.position());job.since=api.time()
    self:dispatch();return
   end
   local failure=tostring(reason or ""):lower()
   if not ok and api.detour and not api.flying() and distance(api.position(),job.goal)>12
       and (job.failed_detours or 0)<2 and (failure:find("stuck",1,true) or failure:find("blocked",1,true)
        or failure:find("no_path",1,true) or failure:find("unreachable",1,true) or failure:find("repath",1,true)) then
    job.failed_detours=(job.failed_detours or 0)+1
    self.epoch=self.epoch+1;local recovery_epoch=self.epoch;api.stop()
    job.detour_pending=true;job.detour_deadline=api.time()+math.min(300,60+distance(api.position(),job.goal)/4)
    local accepted=api.detour(job.goal,function(recovered,why)
     if self.active~=job or self.epoch~=recovery_epoch then return end
     job.detour_pending=nil;self.active=nil;job.callback(recovered,why)
    end)
    if accepted then return end
    job.detour_pending=nil
   end
   self.active=nil;job.callback(ok,reason)
  end
  local ran,error=pcall(mover,destination,completed)
  if not ran and self.active==job and epoch==self.epoch then
   self.active=nil;invoke(api.stop)
   if api.log then api.log("navigation_dispatch_failed",{error=tostring(error),mode=job.leg_mode}) end
   job.callback(false,"navigation_dispatch_error:"..tostring(error))
  end
 end
 function self:move(goal,callback,direct)
  self:stop()
  self.fault=nil
  self.active={goal=goal,callback=callback,direct=direct==true,anchor=copy(api.position()),since=api.time(),attempts=0,map=api.map(),instance=api.instance and api.instance()}
  self:dispatch()
 end
 function self:tick()
  local job=self.active;if not job then return end
  if api.map()~=job.map then
   if api.instance and api.instance()==job.instance and distance(api.position(),job.anchor)<=25 then
    job.map=api.map();job.anchor=copy(api.position());job.since=api.time()
   else self:stop();job.callback(false,"area_changed");return end
  end
  local now=api.time();local pos=api.position()
  if job.detour_pending then
   if now>(job.detour_deadline or now+1) then
    self.epoch=self.epoch+1;api.stop();job.detour_pending=nil
    job.anchor=copy(pos);job.since=now
    if api.log then api.log("obstacle_detour_timeout",{attempt=job.attempts}) end
    self:dispatch()
   end
   return
  end
  local lock_corridor=api.lock_corridor
  if type(lock_corridor)=="function" then lock_corridor=lock_corridor() end
  if lock_corridor and not job.direct and not job.sequence and not api.flying() then
   Sequence=Sequence or require("route_sequence")
   local path=api.path and api.path()
   local sequence=Sequence.new(path,api.path_index and api.path_index() or 1,pos,job.goal)
   if sequence then
    job.sequence=sequence;self.epoch=self.epoch+1;api.stop()
    if api.log then api.log("route_corridor_locked",{points=#sequence.points,model="eots_sequence"}) end
    self:dispatch();return
   end
  end
  if job.waiting_dismount then
   local wait=job.waiting_dismount
   if not api.mounted() then
    job.waiting_dismount=nil;job.anchor=copy(pos);job.since=now;job.loop=nil
    if api.log then api.log("mounted_route_dismount_confirmed",{elapsed=now-wait.started,source=wait.source}) end
    self.epoch=self.epoch+1;api.stop();self:dispatch();return
   end
   if now>=wait.deadline then
    self.fault="dismount_timeout";self.epoch=self.epoch+1;self.active=nil;api.stop()
    if api.log then api.log("mounted_route_dismount_timeout",{elapsed=now-wait.started,source=wait.source}) end
    job.callback(false,self.fault);return
   end
   if now>=wait.next_retry then
    wait.next_retry=now+1
    local accepted,error=invoke(api.dismount)
    if api.log then api.log("mounted_route_dismount_retry",{elapsed=now-wait.started,source=wait.source,
     accepted=accepted,error=not accepted and tostring(error) or nil}) end
   end
   return
  end
  local native_state=api.native_state and api.native_state()
  -- Sentinel can remain in awaiting_path while the ordinary movement watchdog
  -- is paused for planning. Give the server a bounded window, then rebuild the
  -- same request instead of waiting forever.
  if type(native_state)=="string" and native_state:find("awaiting_path",1,true) then
   self.awaiting_since=self.awaiting_since or now
   if now-self.awaiting_since>=8 then
    job.path_timeouts=(job.path_timeouts or 0)+1;self.awaiting_since=now
    if api.log then api.log("navigation_path_timeout",{attempt=job.path_timeouts,state=native_state}) end
    if job.path_timeouts>3 then
     self.fault="stuck_recovery_exhausted";self.epoch=self.epoch+1;self.active=nil;api.stop();job.callback(false,self.fault);return
    end
    if api.replan and api.replan("leveler_awaiting_path_timeout") then return end
    self.epoch=self.epoch+1;api.stop();self:dispatch();return
   end
   return
  end
  self.awaiting_since=nil
  -- Inspect Sentinel's active corridor before waiting for physical symptoms.
  -- A narrow upcoming corridor predicts mount collision; an A-B-A segment
  -- predicts the same trackback pattern Detour removes when merging paths.
  local path=api.path and api.path() or nil
  local index=api.path_index and api.path_index() or 1
  if type(path)=="table" and #path>0 then
   index=math.max(1,math.floor(tonumber(index) or 1))
   local signature_parts={tostring(#path),tostring(index)}
   for i=index,math.min(#path,index+8) do
    local point=path[i]
    if type(point)=="table" then
     signature_parts[#signature_parts+1]=table.concat({
      math.floor((tonumber(point.x) or 0)*2+.5),
      math.floor((tonumber(point.y) or 0)*2+.5),
      math.floor((tonumber(point.z) or 0)*2+.5)},",")
    end
   end
   local signature=table.concat(signature_parts,":")
   if signature~=job.path_signature then
    job.path_signature=signature
    local widths=api.corridor_widths and api.corridor_widths() or nil
    if api.mounted() and not api.flying() and type(widths)=="table" then
     local narrow
     for i=index,math.min(#widths,index+4) do
      local width=tonumber(widths[i])
      if width and width>0 and width<1.8 then narrow=width;break end
     end
     if narrow then begin_dismount(job,"predicted_narrow_corridor:"..tostring(narrow),"corridor_preflight");return end
    end
    local function close(a,b)
     return type(a)=="table" and type(b)=="table" and tonumber(a.x) and tonumber(b.x)
      and distance(a,b)<=0.75
    end
    for i=index+1,math.min(#path-1,index+8) do
     if close(path[i-1],path[i+1]) then
      job.trackback_replans=(job.trackback_replans or 0)+1
      if api.log then api.log("navigation_trackback_predicted",{index=i,attempt=job.trackback_replans}) end
      if job.trackback_replans<=2 and api.replan and api.replan("leveler_path_trackback") then
       job.anchor=copy(pos);job.since=now;return
      end
      break
     end
    end
   end
  end
  if self.escape_until then
   if now<self.escape_until then return end
   if api.strafe then api.strafe(nil) end
   self.escape_until=nil;job.anchor=copy(pos);job.since=now
   if api.log then api.log("navigation_directional_escape_complete",{direction=job.escape_direction}) end
   if api.replan and api.replan("leveler_directional_escape_complete") then return end
   self.epoch=self.epoch+1;api.stop();self:dispatch();return
  end
  if api.paused() then
   job.anchor=copy(pos);job.since=now;job.loop=nil
   if job.advancement then job.advancement:reset() end
   return
  end
  if job.sequence and job.leg and job.advancement:stalled(pos,job.leg,now,12,1) then
   job.attempts=job.attempts+1
   if api.log then api.log("route_leg_no_forward_progress",{index=job.sequence.index,attempt=job.attempts}) end
   job.sequence=nil;job.advancement=nil
   self.epoch=self.epoch+1;api.stop();job.anchor=copy(pos);job.since=now
   if job.attempts>3 then self.active=nil;job.callback(false,"route_corridor_recovery_exhausted");return end
   self:dispatch();return
  end
  local loop=job.loop
  if not loop then
   loop={origin=copy(pos),last=copy(pos),since=now,length=0,initial=distance(pos,job.goal),best=distance(pos,job.goal)};job.loop=loop
  else
   loop.length=loop.length+distance(pos,loop.last);loop.last=copy(pos)
   loop.best=math.min(loop.best,distance(pos,job.goal))
   if now-loop.since>=10 then
    if loop.length>=12 and distance(pos,loop.origin)<=4 and loop.initial-loop.best<2 then
     self.fault="movement_loop_detected"
     if api.log then api.log(self.fault,{distance_walked=loop.length,progress=loop.initial-loop.best,elapsed=now-loop.since}) end
     self:stop();job.callback(false,self.fault);return
    end
    job.loop=nil
   end
  end
  if distance(pos,job.goal)<=3 then return end
  if distance(pos,job.anchor)>=2 then job.anchor=copy(pos);job.since=now;return end
  if now-job.since<8 then return end
  if type(native_state)=="string" and (native_state:find("recover",1,true) or native_state:find("avoid",1,true)) then
   job.anchor=copy(pos);job.since=now
   if api.log and native_state~=job.last_native_recovery then
    job.last_native_recovery=native_state;api.log("sentinel_recovery_in_progress",{state=native_state})
   end
   return
  end
  job.attempts=job.attempts+1
  if api.log then api.log("movement_stalled",{attempt=job.attempts,x=pos.x,y=pos.y,z=pos.z,mounted=api.mounted(),flying=api.flying()}) end
  if job.attempts>3 then self.fault="stuck_recovery_exhausted";self.epoch=self.epoch+1;self.active=nil;api.stop();job.callback(false,self.fault);return end
  -- A ground mount can be wider/taller than Sentinel's successful mesh agent.
  -- Confirm the client has dismounted before asking for the on-foot route.
  if api.mounted() and not api.flying() then
   begin_dismount(job,"movement_stalled","stall");return
  end
  if api.detour and not api.flying() and not job.detour_pending then
   self.epoch=self.epoch+1;local epoch=self.epoch;api.stop()
   job.detour_pending=true;job.detour_deadline=now+math.min(300,60+distance(pos,job.goal)/4);job.anchor=copy(pos);job.since=now
   local accepted=api.detour(job.goal,function(ok,reason)
    if self.active~=job or self.epoch~=epoch then return end
    job.detour_pending=nil
    if ok then self.active=nil;job.callback(true,reason);return end
    job.anchor=copy(api.position());job.since=api.time()
    if api.log then api.log("obstacle_detour_failed",{reason=reason,attempt=job.attempts}) end
    self:dispatch()
   end)
   if accepted then return end
   job.detour_pending=nil
  end
  -- Reuse the battleground controller's bounded side-step recovery. Alternating
  -- sides avoids repeating the same collision angle; Sentinel owns the route
  -- again immediately after the short escape.
  if job.attempts>=2 and api.strafe then
   job.escape_side=-(job.escape_side or -1)
   job.escape_direction=job.escape_side>0 and "right" or "left"
   if api.strafe(job.escape_direction)~=false then
    self.escape_until=now+0.8
    if api.log then api.log("navigation_directional_escape",{direction=job.escape_direction,attempt=job.attempts}) end
    return
   end
  end
  self.recovery_until=now+60
  job.anchor=copy(pos);job.since=now
  if job.sequence then
   job.sequence=nil;job.advancement=nil
   self.epoch=self.epoch+1;api.stop();self:dispatch();return
  end
  -- Use Sentinel's own replan to retain its active obstacle/recovery context.
  if api.replan and api.replan("leveler_movement_stalled") then return end
  self.epoch=self.epoch+1;api.stop();self:dispatch()
 end
 return self
end
return M
