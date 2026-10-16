-- Confirmed three-stage sequence; never changes the selected kill target.
local S=require('ar_spells')
local M={}
local plan
local function guid(unit)
 if not unit or type(unit.get_guid)~='function' then return nil end
 local ok,value=pcall(unit.get_guid,unit);return ok and value~=nil and tostring(value) or nil
end
function M.reset() plan=nil end
function M.start(kill,focus,cc,n)
 if plan then return false end
 local kill_guid,focus_guid=guid(kill),guid(focus)
 if not kill_guid or not focus_guid then return false end
 plan={kill=kill,focus=focus,kill_guid=kill_guid,focus_guid=focus_guid,cc=cc,phase='out',expires=n+7}
 return true
end
function M.current(n,kill,safe)
 if plan and (n>=plan.expires or guid(kill)~=plan.kill_guid or not safe) then plan=nil end
 return plan
end
function M.confirm(id,target,success)
 if not plan then return end
 if not success then
  if plan.phase=='cc' then plan.phase='back' else plan=nil end
  return
 end
 local target_guid=guid(target)
 if plan.phase=='out' and id==S.STEP and target_guid==plan.focus_guid then plan.phase='cc'
 elseif plan.phase=='cc' and id==plan.cc and target_guid==plan.focus_guid then plan.phase='back'
 elseif plan.phase=='back' and id==S.STEP and target_guid==plan.kill_guid then plan=nil end
end
return M
