-- Controls only flight corridors checked by the navigation geometry adapter.
local M={}
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function invoke(fn,...)
 if type(fn)~="function" then return false,"api_unavailable" end
 local ran,result=pcall(fn,...)
 if not ran then return false,tostring(result) end
 return result~=false,result
end
function M.new(api,log)
 local self={next=0}
 local function emit(e,f) if log then log(e,f) end end
 local function recover(j,state,pos,now)
  invoke(api.forward_stop)
  j.recovery={state=state,anchor={x=pos.x,y=pos.y,z=pos.z},next=now+3,deadline=now+30,attempts=0}
  return state
 end
 function self:stop() invoke(api.forward_stop);invoke(api.ascend_stop);self.job=nil end
 function self:get_current_path() return self.job and self.job.path or {} end
 function self:get_path_index() return self.job and self.job.index or 1 end
 function self:start(goal)
  local p=api.player();local info=api.gliding()
  local reason=not (p:is_mounted() or p:is_flying() or info and info.is_gliding) and "not_mounted"
   or not api.flyable() and "area_not_flyable" or not info and "gliding_info_unavailable"
   or not info.can_glide and "can_glide_false"
  if reason then emit("skyriding_start_rejected",{reason=reason});return false,reason end
  local path,corridor_reason=api.corridor(p:get_position(),goal)
  if not path then if corridor_reason=="corridor_pending" then return false,corridor_reason end;emit("skyriding_corridor_unavailable");return false,"corridor_unavailable" end
  self.job={path=path,index=1,started=api.time(),map=api.map(),instance=api.instance(),takeoff_at=0,progress_at=api.time(),best=math.huge}
  emit("skyriding_started",{points=#path});return true
 end
 function self:land()
  local p=api.player();local landing=api.landing(p:get_position())
  if not landing then return false,"landing_unavailable" end
  self.job={path={landing},index=1,landing_only=true,started=api.time(),map=api.map(),instance=api.instance(),progress_at=api.time(),best=math.huge}
  emit("aerial_landing_requested");return true
 end
 function self:tick()
  local j=self.job;if not j then return end
  local p=api.player();local now=api.time();local info=api.gliding()
  if not p or not p:is_valid() then self:stop();return "skyriding_player_unavailable" end
  if p:is_dead() or p:is_ghost() or api.map()~=j.map or api.instance()~=j.instance then self:stop();return "skyriding_interrupted" end
  local pos=p:get_position();local point=j.path[j.index]
  if #j.path>1 and j.index==1 and not p:is_flying() and not (info and info.is_gliding) then
   if now-j.started>6 then self:stop();emit("skyriding_takeoff_failed");return "failed" end
   if now>=j.takeoff_at then
    local accepted,error=invoke(api.jump);invoke(api.ascend_stop);j.takeoff_at=now+0.5
    if not accepted then emit("skyriding_takeoff_input_rejected",{error=tostring(error)}) end
   end
   return "skyriding_takeoff"
  end
  -- A stationary glide flag can linger after touching down. The native
  -- flying flag, proximity to a measured landing, and zero glide speed must
  -- agree before allowing this landing-only recovery to resume ground travel.
  local stationary_landing=j.landing_only and not p:is_flying()
   and info and tonumber(info.forward_speed) and info.forward_speed<=1 and distance(pos,point)<=4
  if j.index==#j.path and not p:is_flying() and (stationary_landing or not (info and info.is_gliding)) and distance(pos,point)<=4 then
   invoke(api.forward_stop);invoke(api.ascend_stop)
   j.grounded_since=j.grounded_since or now
   if now-j.grounded_since<1 then return 'skyriding_confirming_landing' end
   self:stop();emit("skyriding_landed");return "complete"
  end
  j.grounded_since=nil
  -- Touchdown may occur away from the authored endpoint. Verify local ground
  -- before releasing flight ownership; never interpret a flag flicker as landing.
  if (j.index>1 or j.landing_only) and not p:is_flying()
     and (not info or not info.is_gliding or tonumber(info.forward_speed) and info.forward_speed<=1) then
   local floor=api.landing(pos)
   if floor and distance(pos,floor)<=2 then
    invoke(api.forward_stop);invoke(api.ascend_stop)
    j.offroute_grounded_since=j.offroute_grounded_since or now
    if now-j.offroute_grounded_since<1 then return "skyriding_confirming_ground_handoff" end
    self:stop();emit("skyriding_ground_handoff");return "failed"
   else j.offroute_grounded_since=nil end
  else j.offroute_grounded_since=nil end
  if j.recovery then
   local recovery=j.recovery
   if now>=recovery.deadline then
    self:stop();emit("skyriding_recovery_exhausted",{state=recovery.state,attempts=recovery.attempts})
    return "failed"
   end
   if distance(pos,recovery.anchor)>=3 then
    j.recovery=nil;j.best=math.huge;j.progress_at=now
    emit("skyriding_recovery_progress")
   else
    if now>=recovery.next then
     recovery.next=now+3;invoke(api.forward_stop)
     if recovery.attempts<3 then
      -- Retry only a newly measured, collision-checked local landing.
      -- Keep the same recovery state until movement actually resumes so
      -- the leveler's stalled-step watchdog can rebuild the quest route.
      local landing=api.landing(pos)
      if landing and api.clear(pos,landing) then
       local faced,face_error=invoke(api.face,landing)
       local started,start_error=faced and invoke(api.forward_start) or false,face_error
       if faced and started then
        recovery.attempts=recovery.attempts+1
        j.path={landing};j.index=1
        emit("skyriding_landing_retry",{attempt=recovery.attempts})
       else emit("skyriding_input_rejected",{phase="landing",error=tostring(faced and start_error or face_error)}) end
      end
     end
    end
    return recovery.state
   end
  end
  local remaining=distance(pos,point)
  if remaining<j.best-3 then j.best=remaining;j.progress_at=now end
  local passed=false
  if j.index>1 and j.index<#j.path then
   local previous=j.path[j.index-1];local dx,dy=point.x-previous.x,point.y-previous.y
   local length=dx*dx+dy*dy
   passed=length>0 and (pos.x-previous.x)*dx+(pos.y-previous.y)*dy>=length
  end
  local lookahead=math.min(45,math.max(12,(info and info.forward_speed or 0)*0.75))
  local horizontal=math.sqrt((pos.x-point.x)^2+(pos.y-point.y)^2)
  local climb_reached=j.index==1 and pos.z>=point.z-4 and horizontal<=lookahead
  local reached=climb_reached or j.index>1 and (remaining<=lookahead or passed)
  if j.index<#j.path and reached then
   j.index=j.index+1;j.best=math.huge;j.progress_at=now;point=j.path[j.index]
  end
  if now>=self.next then
   self.next=now+0.5
   if not api.clear(pos,point) then
    invoke(api.forward_stop);emit("skyriding_corridor_blocked")
    if j.index<#j.path and self:land() then return "skyriding_landing" end
    return recover(j,"skyriding_obstacle_wait",pos,now)
   end
   local faced,face_error=invoke(api.face,point)
   local started,start_error=faced and invoke(api.forward_start) or false,face_error
   if not faced or not started then
    emit("skyriding_input_rejected",{phase="cruise",error=tostring(faced and start_error or face_error)})
    return recover(j,"skyriding_input_wait",pos,now)
   end
   local final=j.path[#j.path]
   local final_distance=distance(pos,final)
   local braking_distance=math.max(30,(info and info.forward_speed or 0)*2)
   if (j.index==#j.path or final_distance<=braking_distance) and info and info.forward_speed>15 and now>=(j.brake_next or 0) then
    local brake=api.spell("Aerial Halt")
    if brake and api.known(brake) then
     local accepted,error=invoke(api.cast,brake,p);j.brake_next=now+(accepted and 15 or 2)
     emit("skyriding_brake_requested",{spell_id=brake,accepted=accepted,error=not accepted and tostring(error) or nil})
    end
   end
   -- Resolve current abilities and charges through the live spellbook.
   local ascent=api.spell("Skyward Ascent");local surge=api.spell("Surge Forward")
   -- Retail can replace the long-distance boost choice. Resolve every name
   -- through the live spellbook and only cast an ability the character knows.
   local whirling=api.spell("Whirling Surge");local lightning=api.spell("Lightning Rush")
   local safe_to_boost=j.index<#j.path and final_distance>math.max(100,(info and info.forward_speed or 0)*3)
   local id=point.z-pos.z>10 and ascent or safe_to_boost and info and info.forward_speed<25 and surge
   if (not id or not api.known(id) or api.charges(id)<=0) and safe_to_boost and info and info.forward_speed<25 then
    for _,candidate in ipairs({lightning,whirling}) do
     if candidate and api.known(candidate) and api.charges(candidate)>0 then id=candidate;break end
    end
   end
   if id and now>=(j.boost_next or 0) and api.charges(id)>0 and api.known(id) then
    local accepted,error=invoke(api.cast,id,p);j.boost_next=now+2
    emit("skyriding_boost",{spell_id=id,accepted=accepted,error=not accepted and tostring(error) or nil})
   end
   if now-j.progress_at>15 then
    invoke(api.forward_stop);emit("skyriding_no_progress")
    if j.index<#j.path and self:land() then return "skyriding_landing" end
    return recover(j,"skyriding_recovery_wait",pos,now)
   end
  end
  return j.index==#j.path and "skyriding_landing" or "skyriding_cruise"
 end
 return self
end
return M
