local M={}
function M.tick(step,api)
 local state=api.state() or {}
 if state.in_vehicle or state.can_exit_vehicle then
  if not step.vehicle_id then
   -- Never credit a different vehicle merely because the player is seated.
   local name=api.vehicle_name and api.vehicle_name(state.vehicle_guid)
   if type(name)~="string" then return false end
   name=name:lower()
   if type(step.target_name)=="string" and name==step.target_name:lower() then return true end
   for _,target in ipairs(step.target_names or {}) do
    if type(target)=="string" and name==target:lower() then return true end
   end
   return false
  end
  local id=tonumber(tostring(state.vehicle_guid or ''):match('^[^-]+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
  return id==step.vehicle_id
 end
 if not step.vehicle_item_id then return nil end
 if step.vehicle_item_map and api.map()~=step.vehicle_item_map then return false end
 if api.time()<(step.vehicle_retry_at or 0) then return false end
 local count=api.count(step.vehicle_item_id)
 if not count or count<1 then return false end
 local remaining=api.cooldown(step.vehicle_item_id)
 if remaining and remaining>0 then return false end
 step.vehicle_retry_at=api.time()+5
 api.use(step.vehicle_item_id)
 -- A dispatched item request is not proof of being inside the vehicle.
 return false
end
return M
