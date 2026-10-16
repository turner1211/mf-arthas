local N={};N.__index=N
function N.new(get_nav,report,direct_start,direct_stop,skip_height_probe)
 return setmetatable({get_nav=get_nav,report=report,direct_start=direct_start,direct_stop=direct_stop,
  skip_height_probe=skip_height_probe,generation=0,direct_active=false,paused={},height_probe_disabled=false},N)
end
function N:stop()
 self.generation=self.generation+1
 if self.direct_active and self.direct_stop then pcall(self.direct_stop) end
 self.direct_active=false
 for reason,n in pairs(self.paused) do
  local found,resume=pcall(function() return n and n.resume end)
  if found and type(resume)=="function" then pcall(resume,n,reason) end
  self.paused[reason]=nil
 end
 local n=self.get_nav();if n then
  local found,stop=pcall(function() return n.stop end)
  if found and type(stop)=="function" then pcall(stop,n) end
 end
end
function N:pause(reason)
 reason=tostring(reason or "movement_hold")
 if self.paused[reason] then return true end
 local n=self.get_nav();if not n then return false end
 local found,pause=pcall(function() return n.pause end)
 if not found or type(pause)~="function" then return false end
 local ok,result=pcall(pause,n,reason)
 if ok and result~=false then self.paused[reason]=n;return true end
 return false
end
function N:resume(reason)
 reason=tostring(reason or "movement_hold")
 local n=self.paused[reason]
 if not n then return true end
 local found,resume=pcall(function() return n.resume end)
 if not found or type(resume)~="function" then return false end
 local ok,result=pcall(resume,n,reason)
 if ok and result~=false then self.paused[reason]=nil;return true end
 return false
end
function N:move(point,cb,direct,skip_height)
 self.generation=self.generation+1;local generation=self.generation
 local goal={x=point.x,y=point.y,z=point.z}
 local callback_done=false
 local function done(ok,err)
  if callback_done or generation~=self.generation or not cb then return end
  callback_done=true
  local called,callback_error=pcall(cb,ok,err)
  if not called and self.report then self.report("navigation_callback_error:"..tostring(callback_error),goal) end
 end
 -- Authored direct corridors use local input steering specifically so spawn
 -- rooms, ships and other off-mesh exits remain usable during a Sentinel
 -- outage. Try that adapter before requiring a navigation client.
 if direct and type(self.direct_start)=="function" then
  local ok,result=pcall(self.direct_start,goal)
  if ok and result~=false then self.direct_active=true;return end
  done(false,ok and "direct_movement_unavailable" or tostring(result));return
 end
 local n=self.get_nav()
 if not n then done(false,"navigation_unavailable");return end
 local function call(method,...)
  local found,fn=pcall(function() return n[method] end)
  if not found or type(fn)~="function" then return false,method.."_unavailable" end
  local ok,result=pcall(fn,n,...)
  return ok and result~=false,ok and result or tostring(result)
 end
 local function has(method)
  local ok,fn=pcall(function() return n[method] end)
  return ok and type(fn)=="function"
 end
 local function submit_move(method)
  local ok,err=call(method,goal,done)
  if not ok then done(false,method.."_error:"..tostring(err)) end
  return ok
 end
 -- Sentinel v0.23 exposes move_direct, but its implementation still submits
 -- the origin/destination to the remote navmesh and returns HTTP 422 in WSG
 -- flag rooms. Authored direct corridor legs must prefer local input steering.
 if direct and has("move_direct") then submit_move("move_direct");return end
 if not has("get_height") and not has("get_all_heights") then submit_move("move_to");return end
 local completed=false
 local function move_validated()
  if not has("validate_destination") then completed=true;submit_move("move_to");return end
  local dispatched,dispatch_error=call("validate_destination",goal,function(reachable,reason)
   if completed or generation~=self.generation or self.get_nav()~=n then return end
   if reachable~=true then
    completed=true
    if self.report then self.report("destination_validation_rejected",goal) end
    done(false,"destination_unreachable:"..tostring(reason or "unknown"));return
   end
   completed=true;submit_move("move_to")
  end)
  if not dispatched and not completed then completed=true;done(false,"validate_destination_error:"..tostring(dispatch_error)) end
 end
 local function projected(first,second)
  if completed or generation~=self.generation or self.get_nav()~=n then return end
  -- ArthasNav query callbacks use (ok, z); older compatible clients supplied
  -- z directly. Accept both contracts without mistaking `true` for a height.
  local height=first==true and type(second)=="number" and second or first
  -- Height projection may land on another bridge/floor. Preserve observed Z.
  -- Terrain rays can see the lake bed or terrain below a bridge, platform,
  -- ship deck or battleground structure. AmeisenNav 1.7.1 preserves the live
  -- destination in that case instead of snapping the request through the
  -- floor. Keep the same bounded guard before ArthasNav validation.
  if type(height)=="number" and height==height and height<goal.z-8 then
   if self.report then self.report("height_projection_platform_preserved",goal) end
   move_validated();return
  elseif type(height)=="number" and height==height and math.abs(height-goal.z)<=6 then
   goal.z=height
  elseif type(height)=="number" and height==height then
   completed=true
   if self.report then self.report("height_projection_conflict",goal) end
   done(false,"height_projection_conflict");return
  else
   if self.report then self.report("height_projection_rejected",goal) end
   -- Match the proven 1-90 navigation adapter: a missing optional height
   -- query must not prevent Sentinel from receiving an otherwise valid XYZ
   -- destination. Sentinel's own validation/move callback stays authoritative.
   move_validated();return
  end
  move_validated()
 end
 -- Unit positions already come from the live world object. Re-projecting a
 -- moving combat target's Z starts an extra asynchronous nav query on every
 -- refresh, and failed projections create visible request/log churn. Keep
 -- Sentinel destination validation, but trust the observed unit height.
 -- MF Navigation disables ground projection while swimming because the
 -- terrain API reports the lake or river bed. Preserve the live surface Z.
 local environmental_skip=false
 if type(self.skip_height_probe)=="function" then
  local ok,value=pcall(self.skip_height_probe)
  environmental_skip=ok and value==true
 end
 if skip_height or environmental_skip or self.height_probe_disabled then
  if environmental_skip and self.report then self.report("height_projection_skipped_swimming",goal) end
  move_validated();return
 end
 if has("get_all_heights") then
  local dispatched,dispatch_error=call("get_all_heights",goal,function(values)
   if completed or generation~=self.generation or self.get_nav()~=n then return end
   local best,best_delta
   for _,value in pairs(type(values)=="table" and values or {}) do
    local height=type(value)=="number" and value or type(value)=="table" and (value.z or value.height)
    if type(height)=="number" and height==height then
     local delta=math.abs(height-goal.z)
     if not best_delta or delta<best_delta then best,best_delta=height,delta end
    end
   end
   projected(best)
  end)
  if not dispatched and not completed then
   self.height_probe_disabled=true
   if self.report then self.report("height_projection_provider_disabled:"..tostring(dispatch_error),goal) end
   -- Height projection is optional. A provider packaging/configuration fault
   -- must not take movement down with it; preserve the live XYZ and submit the
   -- route through the provider's core move contract.
   move_validated()
  end
 else
  local dispatched,dispatch_error=call("get_height",goal,projected)
  if not dispatched and not completed then
   self.height_probe_disabled=true
   if self.report then self.report("height_projection_provider_disabled:"..tostring(dispatch_error),goal) end
   move_validated()
  end
 end
end
return N
