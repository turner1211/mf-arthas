-- Contract follows Sylvanas's Map Click to Nav example.
local M={}
local GroundSafety=require('ground_safety')
function M.new(native,fallback,api)
 local self={native=native,epoch=0}
 function self:diagnostic(event,job,reason)
  if not api.log then return end
  local state="unavailable"
  local method=native.get_full_state or native.get_state
  if method then local ok,value=pcall(method,native);if ok then state=tostring(value) end end
  api.log(event,{native_state=state,path_points=#self:get_current_path(),
   elapsed=job and api.time()-job.started or 0,reason=reason,shared_client=api.external_updates==true})
 end
 function self:is_server_available()
  local ok,ready=pcall(function() return native:is_server_available() end)
  return ok and ready==true
 end
 function self:get_current_path()
  if not native.get_current_path then return {} end
  local ok,path=pcall(function() return native:get_current_path() end)
  return ok and type(path)=='table' and path or {}
 end
 function self:get_path_index()
  if not native.get_path_index then return nil end
  local ok,value=pcall(function() return native:get_path_index() end)
  return ok and tonumber(value) or nil
 end
 function self:get_corridor_widths()
  if not native.get_corridor_widths then return nil end
  local ok,value=pcall(function() return native:get_corridor_widths() end)
  return ok and type(value)=="table" and value or nil
 end
 function self:get_progress()
  if not native.get_progress then return nil end
  local ok,value=pcall(function() return native:get_progress() end)
  return ok and type(value)=="table" and value or nil
 end
 function self:supports_height_query()
  return type(native.get_all_heights)=="function" or type(native.get_height)=="function"
 end
 function self:get_height(p,cb,options)
  local position={x=p.x,y=p.y,z=p.z}
  local settled=false
  local function finish(first,second)
   if settled then return end
   settled=true
   cb(first,second)
  end
  if type(native.get_all_heights)=="function" then
   local ok,err=pcall(function() native:get_all_heights(position,function(first,second)
    if settled then return end
    if first==false then finish(nil,"navigation_height_query_failed");return end
    local data=type(second)=="table" and second or first
    local values={}
    local function add(h)
     if type(h)=="number" and h==h and math.abs(h)<100000 then
      for _,old in ipairs(values) do if math.abs(old-h)<0.1 then return end end
      values[#values+1]=h
     end
    end
    if type(data)=="table" then
     local rows=data.heights or data.layers or data
     if type(rows)=="table" then
      for _,v in ipairs(rows) do
       if type(v)=="number" then add(v) elseif type(v)=="table" then add(v.height or v.z) end
      end
     end
     if #values==0 then add(data.height or data.z) end
    else add(data) end
    -- Select the layer closest to the authored/observed Z. Even a single
    -- response must remain plausibly close; accepting a distant lone floor
    -- can route onto a roof, bridge, cave, or different vertical phase.
    local chosen,delta
    for _,h in ipairs(values) do
     local candidate=math.abs(h-position.z)
     if not delta or candidate<delta then chosen,delta=h,candidate end
    end
    -- XY-only map coordinates carry no authored altitude. A single mesh
    -- layer is authoritative there; the player's distant Z is not a floor
    -- constraint. Multiple layers remain ambiguous and are rejected.
    if options and options.unknown_altitude and #values==1 then finish(values[1]);return end
    if chosen and delta<=6 then finish(chosen);return end
    finish(nil,#values>0 and "navigation_height_layer_mismatch" or "navigation_height_missing")
   end) end)
   if not ok then finish(nil,"navigation_height_dispatch_error:"..tostring(err)) end
   return
  end
  if native.get_height then
   local ok,err=pcall(function() native:get_height(position,function(first,second)
    -- Arthas Nav uses (ok, z); Sentinel variants use (z, reason).
    if settled then return end
    if first==false then finish(nil,"navigation_height_query_failed");return end
    local height=type(first)=="number" and first or type(second)=="number" and second or nil
    if height and height==height and math.abs(height)<100000 then finish(height);return end
    finish(nil,type(second)=="string" and second or "navigation_height_query_failed")
   end) end)
   if not ok then finish(nil,"navigation_height_dispatch_error:"..tostring(err)) end
   return
  end
  cb(nil,"navigation_height_api_missing")
 end
 -- Some shared Sentinel builds expose get_all_heights but never deliver its
 -- callback for an XY-only request.  Keep the ordinary single-layer API
 -- available as a bounded fallback.  Callers only use this after the layered
 -- request has remained unanswered, with a nearby observed Z seed.
 function self:get_height_near(p,cb)
  if type(native.get_height)~="function" then
   if api.height_query then api.height_query(p,cb) else cb(nil,"navigation_near_height_api_missing") end
   return
  end
  local position={x=p.x,y=p.y,z=p.z}
  local settled=false
  local fallback_started=false
  local function finish(first,second)
   if settled then return end
   settled=true
   cb(first,second)
  end
  local ok,err=pcall(function() native:get_height(position,function(first,second)
   if settled or fallback_started then return end
   local h
   -- Failure payloads can contain stale numeric data. Only successful
   -- replies may provide a floor; a fallback must measure its own result.
   if first~=false then
    h=first==true and type(second)=="number" and second or type(first)=="number" and first or type(second)=="number" and second
    if type(first)=="table" then h=first.height or first.z end
    if type(second)=="table" then h=second.height or second.z end
   end
   if type(h)=="number" and h==h and math.abs(h)<100000 then finish(h);return end
   if api.height_query then fallback_started=true;api.height_query(position,finish)
   else finish(nil,type(second)=="string" and second or "navigation_near_height_missing") end
  end) end)
  if not ok then finish(nil,"navigation_near_height_dispatch_error:"..tostring(err)) end
 end
 function self:stop()
  self.epoch=self.epoch+1;self.job=nil
  pcall(function() native:stop() end)
 end
 local corrected_floors={}
 function self:move_to(p,cb,direct)
  -- Keep arrival verification independent of a caller mutating its cached step.
  p={x=p.x,y=p.y,z=p.z,_unknown_altitude=p._unknown_altitude,_mesh_height=p._mesh_height}
  -- Bridges, caves and stacked interiors can share XY. A recovered floor
  -- belongs to the original altitude request, not every destination there.
  local floor_key=tostring(api.map and api.map() or "session")..":"..tostring(p.x)..":"..tostring(p.y)..":"..tostring(p.z)
  local cached=corrected_floors[floor_key]
  if not direct and cached and api.time()-cached.at<60 then p.z=cached.z;p._unknown_altitude=nil end
  self:stop()
  if not self:is_server_available() then cb(false,"navlib_server_unavailable");return end
  local epoch=self.epoch
  self.job={destination=p,callback=cb,started=api.time()}
  local dispatch
  -- The server accepts a measured floor only within six yards of its seed.
  -- Eight-yard intervals cover the vertical search without holes between probes.
  local floor_offsets={}
  for height=8,256,8 do floor_offsets[#floor_offsets+1]=height;floor_offsets[#floor_offsets+1]=-height end
  local floor_probe=0
  local original_z=p.z
  local function done(ok,reason,detail)
   if not ok and type(detail)=="table" and type(detail.code)=="string" then reason=detail.code end
   if epoch~=self.epoch or not self.job then return end
   if not ok and (reason=="no_path" or reason=="unreachable") and api.path_query and type(native.follow_path)=="function"
       and not self.job.bridge_active and (self.job.bridge_attempts or 0)<4 then
    self.job.bridge_active=true;self.job.bridge_attempts=(self.job.bridge_attempts or 0)+1
    local origin=api.position();local before=math.sqrt((origin.x-p.x)^2+(origin.y-p.y)^2)
    api.path_query(origin,p,function(points,partial)
     if epoch~=self.epoch or not self.job then return end
     if not points then done(false,type(partial)=="string" and partial or "no_path");return end
     local safe,why=GroundSafety.path_safe(points,api.floor_probe)
     if not safe then done(false,"navigation_unsafe_ground_edge:"..tostring(why));return end
     local endpoint=points[#points]
     if endpoint and (endpoint.x-p.x)^2+(endpoint.y-p.y)^2<=9 and math.abs(endpoint.z-p.z)>3 then
      done(false,"bridge_destination_layer_mismatch");return
     end
     GroundSafety.configure(native)
     if api.log then api.log("navigation_mesh_segment",{points=#points,partial=partial,attempt=self.job.bridge_attempts})end
     local ran=pcall(function()native:follow_path(points,function(success,why)
      if epoch~=self.epoch or not self.job then return end
      if not success then done(false,why or "bridge_follow_failed");return end
      local current=api.position();local after=math.sqrt((current.x-p.x)^2+(current.y-p.y)^2)
      if partial then
       if before-after<10 then done(false,"bridge_segment_no_progress");return end
       self.job.bridge_active=nil;dispatch()
      else done(true)end
     end)end)
     if not ran then done(false,"bridge_follow_dispatch_failed")end
    end)
    return
   end
   if not ok and (reason=="no_path" or reason=="unreachable" or reason=="no_verified_detour") and not p._mesh_height and not direct and (type(native.find_path)=="function" or type(native.get_height)=="function")
       and floor_probe<#floor_offsets then
    floor_probe=floor_probe+1
    local seed=original_z+floor_offsets[floor_probe]
    local function resolved(height)
     if epoch~=self.epoch or not self.job then return end
     if height and math.abs(height-seed)<=6 then
      -- Only a server-measured floor may replace the rejected collision Z.
      -- Native pathfinding still has to prove connectivity and actual arrival.
      p.z=height;p._unknown_altitude=nil;self.job.bridge_active=nil
      corrected_floors[floor_key]={z=height,at=api.time()}
      if api.log then api.log("navigation_destination_floor_remeasured",{reported=original_z,measured=height,probe=floor_probe}) end
      dispatch()
     else done(false,"no_path") end
    end
    if type(native.find_path)=="function" then
     local origin=api.position()
     local called=false
     local success=pcall(function() native:find_path(origin,{x=p.x,y=p.y,z=seed},function(found,points,info)
      if called then return end;called=true
      local endpoint=found and type(points)=="table" and points[#points]
      local valid=endpoint and type(endpoint.x)=="number" and type(endpoint.y)=="number" and type(endpoint.z)=="number"
      if valid then valid=(endpoint.x-p.x)^2+(endpoint.y-p.y)^2<=9 and math.abs(endpoint.z-seed)<=6
          and not (type(info)=='table' and info.partial) end
      resolved(valid and endpoint.z or nil)
     end,{allow_partial=false}) end)
     if not success and not called then called=true;resolved(nil) end
    else
     self:get_height_near({x=p.x,y=p.y,z=seed},resolved)
    end
    return
   end
   if not ok and reason=="cancelled" and api.log then
    local trace="traceback_unavailable"
    if debug and type(debug.traceback)=="function" then
     local traced,value=pcall(debug.traceback,"navigation cancellation",2)
     if traced then trace=value end
    end
    pcall(api.log,"navigation_cancel_source",{elapsed=api.time()-self.job.started,
     trace=trace,detail=type(detail)=="table" and tostring(detail.detail) or nil})
   end
   if ok then
    local current=api.position()
    local dx,dy,dz=current.x-p.x,current.y-p.y,current.z-p.z
    -- Sentinel resolves the walkable floor and can legitimately finish a few
    -- yards above or below an authored Z on ramps, stairs and uneven terrain.
    -- Requiring a three-dimensional three-yard sphere turned those successful
    -- arrivals into redispatches back toward the same coordinate. Keep planar
    -- interaction range strict while still rejecting a different floor.
    local planar=math.sqrt(dx*dx+dy*dy)
    if planar>2 and planar<=8 and math.abs(dz)<=2 and type(native.find_path)=="function" and not direct
        and (self.job.approach_attempts or 0)<2 then
     self.job.approach_attempts=(self.job.approach_attempts or 0)+1
     local attempt=self.job.approach_attempts
     -- Some native menus own a 6-yard arrival radius. A short, connected
     -- extension makes that radius land at the original endpoint. Verify
     -- actual arrival against the original endpoint, never the extension.
     local extension=6.5+(attempt-1)*2
     local beyond={x=p.x-dx/planar*extension,y=p.y-dy/planar*extension,z=p.z}
     self.job.approach_deadline=api.time()+8
     local approaches={beyond,
      {x=beyond.x-dy/planar*4,y=beyond.y+dx/planar*4,z=p.z},
      {x=beyond.x+dy/planar*4,y=beyond.y-dx/planar*4,z=p.z}}
     local probe
     probe=function(index)
      local settled=false
      local beyond=approaches[index]
      local ran=pcall(function() native:find_path(current,beyond,function(found,points,info)
      if settled or epoch~=self.epoch or not self.job then return end;settled=true
      local endpoint=found and type(points)=="table" and points[#points]
      local valid=endpoint and type(endpoint.x)=="number" and type(endpoint.y)=="number" and type(endpoint.z)=="number"
      local length=0;local last=current
      if valid then
       for _,v in ipairs(points) do
        if type(v.x)~="number" or type(v.y)~="number" or type(v.z)~="number" then valid=false;break end
        length=length+math.sqrt((v.x-last.x)^2+(v.y-last.y)^2+(v.z-last.z)^2);last=v
       end
       valid=valid and length<=25 and (endpoint.x-beyond.x)^2+(endpoint.y-beyond.y)^2<=2.25
        and math.abs(endpoint.z-p.z)<=2 and not (type(info)=="table" and info.partial)
      end
      if valid then
       if api.log then api.log("navigation_precise_approach",{distance=planar,attempt=attempt,required_range=2}) end
       self.job.approach_deadline=api.time()+8
       dispatch(endpoint)
      elseif index<#approaches then
       probe(index+1)
      else self.job=nil;cb(false,"navigation_precise_approach_unavailable") end
     end,{allow_partial=false}) end)
      if not ran and not settled then self.job=nil;cb(false,"navigation_precise_approach_dispatch_failed") end
     end
     probe(1)
     return
    end
    if dx*dx+dy*dy>4 or (not p._unknown_altitude and math.abs(dz)>8) then
     ok=false;reason="navlib_arrival_out_of_range"
     if api.log then api.log("navigation_arrival_rejected",{actual_x=current.x,actual_y=current.y,actual_z=current.z,
      expected_x=p.x,expected_y=p.y,expected_z=p.z,planar_distance=math.sqrt(dx*dx+dy*dy),height_difference=dz}) end
    end
   end
   self.job=nil
   cb(ok,reason)
  end
  self.job.done=done
  dispatch=function(approach_target)
   if epoch~=self.epoch or not self.job then return end
   if not direct and not self.ground_safety_configured then
    local configured,why=GroundSafety.configure(native)
    self.ground_safety_configured=configured
    if api.log then api.log('ground_terrain_scan',{enabled=configured,reason=why,cliff_drop=3,lookahead=20,waypoint_spacing=5}) end
   end
   local mover=direct and type(native.move_direct)=="function" and native.move_direct or native.move_to
   local ok,accepted,reason=pcall(mover,native,approach_target or p,done,{priority=10,is_valid=function() return epoch==self.epoch and self.job~=nil end})
   local err=accepted
   if not ok then self:stop();cb(false,"navlib_dispatch_error:"..tostring(err)) end
   if ok and accepted==false and self.job then done(false,"navlib_dispatch_rejected:"..tostring(reason or "unknown")) end
   if self.job then self:diagnostic("navigation_request_dispatched",self.job) end
  end
  local ok,err
  -- The installed Sentinel client owns its update/validation lifecycle.  A
  -- separate validate_destination request can occupy that single async
  -- channel and leave move_to undispatched forever.  The older, working
  -- integration sent the destination directly; Sentinel validates it as part
  -- of move_to and reports an ordinary failure through `done`.
  if not api.external_updates and type(native.validate_destination)=="function" then
   ok,err=pcall(function() native:validate_destination(p,function(reachable,reason)
    if epoch~=self.epoch or not self.job then return end
    if reachable~=true then done(false,"navlib_destination_unreachable:"..tostring(reason or "unknown"));return end
    dispatch()
   end) end)
  else ok,err=pcall(dispatch) end
  if not ok then self:stop();cb(false,"navlib_dispatch_error:"..tostring(err)) end
 end
 function self:move_direct(p,cb) return self:move_to(p,cb,true) end
 function self:is_planning()
  return self.job~=nil and #self:get_current_path()==0
 end
 function self:replan(reason)
  if not self.job or type(native.replan)~="function" then return false end
  local ok,result=pcall(function() return native:replan(reason) end)
  if not ok or result==false then return false end
  if self.job then self.job.started=api.time() end
  return true
 end
 function self:update()
  local job=self.job;if not job then return end
  if api.native_provider and api.native_provider()~=native then
   self:diagnostic("navigation_client_changed",job,"shared_singleton_replaced")
   self:stop();job.callback(false,"navlib_client_replaced");return
  end
  -- Reject an unsafe upcoming ground edge even if the provider accepted
  -- the rolling-window configuration. Inspect only the remaining path.
  local path=self:get_current_path();local index=self:get_path_index()
  if index and index>=1 and index<#path then
   local remaining={}
   for i=index,math.min(#path,index+4) do remaining[#remaining+1]=path[i] end
   local safe,why,sample=GroundSafety.path_safe(remaining,api.floor_probe)
   if not safe then
    self:diagnostic("navigation_unsafe_ground_edge",job,why or "unsafe_remaining_path")
    if api.log and sample then api.log("navigation_ground_sample_failed",{reason=why,x=sample.x,y=sample.y,z=sample.z,measured_z=sample.measured_z,previous_z=sample.previous_z,path_index=index}) end
    self:stop();job.callback(false,"navigation_unsafe_ground_edge");return
   end
  end
  -- Precision extensions compensate for the native arrival radius. Monitor
  -- the original goal while moving, rather than waiting for the extension's
  -- callback (which can drive through the goal and oscillate past it).
  if (job.approach_attempts or 0)>0 then
   local current=api.position();local goal=job.destination
   local dx,dy,dz=current.x-goal.x,current.y-goal.y,current.z-goal.z
   if dx*dx+dy*dy<=4 and math.abs(dz)<=2 then
    self:stop()
    if api.log then api.log("navigation_precise_arrived",{distance=math.sqrt(dx*dx+dy*dy)}) end
    job.callback(true,"arrived");return
   end
  end
  if job.approach_deadline and api.time()>job.approach_deadline then
   self:stop();job.callback(false,"navigation_precise_approach_timeout");return
  end
  -- Pump queued responses before deciding that planning timed out. A frame
  -- stall can otherwise discard a response that arrived during that frame.
  if native.update and not api.external_updates then
   local ok=pcall(function() native:update() end)
   if not ok then
    if self.job==job then self:stop();job.callback(false,"navlib_update_error") end
    return
   end
   if self.job~=job then return end
  end
  if api.time()-job.started>=(job.next_diagnostic or 5) then
   self:diagnostic("navigation_request_pending",job)
   job.next_diagnostic=(job.next_diagnostic or 5)+10
  end
  -- The shared client owns its update loop and network retry/backoff. Six
  -- seconds repeatedly cancelled those requests before they could finish.
  local planning_timeout=api.planning_timeout or (api.external_updates and 45 or 30)
  if type(native.get_current_path)=="function" and api.time()-job.started>planning_timeout and #self:get_current_path()==0 then
   self:diagnostic("navigation_request_timeout",job,"planning_without_path")
   self:stop();job.callback(false,"navlib_planning_timeout");return
  end
  if not self:is_server_available() or api.time()-job.started>240 then
   local reason=self:is_server_available() and "navlib_request_timeout" or "navlib_server_lost"
   self:stop();job.callback(false,reason);return
  end
  -- Shared Sentinel updates are owned by its library, as required by the
  -- published consumer contract. Standalone backends above are pumped here.
 end
 return self
end
return M
