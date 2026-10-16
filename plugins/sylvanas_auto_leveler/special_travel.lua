-- Authored DK recall and Arcantina travel; dispatch never proves arrival.
local M={}
local function fresh(now,state)
 return state and type(state.at)=="number" and now>=state.at and now-state.at<=5
end
function M.recall(step,a)
 local now=a.time();local state=a.state()
 if not fresh(now,state) then return false end
 if not state.in_vehicle and not state.can_exit_vehicle then return true end
 local bar=a.actions()
 if not fresh(now,bar) then return false end
 local available=false
 for _,slot in pairs(bar.slots or {}) do
  if slot.type=="spell" and slot.id==52694 and slot.usable==true then available=true end
 end
 if not available or now<(step.eye_retry_at or 0) then return false end
 step.eye_retry_at=now+5
 pcall(a.cast,52694)
 return false
end
function M.toy(step,a)
 if step.toy_travel_id~=253629 or step.target_map_id~=2393 then return "toy_travel_context_invalid" end
 local map=a.map();if not map then return "waiting_for_toy_map" end
 if map==2393 then return "complete" end
 local now=a.time()
 if step.toy_origin_map and map~=step.toy_origin_map then
  -- A second use would return to the origin. Take the named exit instead.
  a.portal();return "waiting_for_arcantina_exit"
 end
 if type(a.owned)~="function" or type(a.use)~="function" then return "toy_api_unavailable" end
 if a.owned(253629)~=true then return "arcantina_key_not_owned" end
 if a.usable(253629)~=true then return "waiting_for_arcantina_key" end
 if now<(step.toy_retry_at or 0) then return "waiting_for_arcantina_teleport" end
 step.toy_origin_map=map;step.toy_retry_at=now+5
 local ok,result=pcall(a.use,253629)
 return ok and result~=false and "waiting_for_arcantina_teleport" or "arcantina_toy_dispatch_failed"
end
return M
