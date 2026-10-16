-- RestedXP .cast observes a spell event for the authored unit. A different
-- unit casting the same spell must never complete this step.
local M={}
function M.new()
 local counts={}
 local function key(unit,id,event) return tostring(unit)..":"..tostring(id)..":"..event end
 local self={}
 function self:event(event,args)
  if event~="UNIT_SPELLCAST_SUCCEEDED" and event~="UNIT_SPELLCAST_FAILED_QUIET" then return end
  if type(args)~="table" or type(args[1])~="string" then return end
  local id=tonumber(args[3]);if not id or id<=0 then return end
  local k=key(args[1],id,event);counts[k]=(counts[k] or 0)+1
 end
 function self:observed(step)
  step.cast_origin=step.cast_origin or {}
  local signals=step.completion_cast_signals
  if not signals then
   signals={};for _,id in ipairs(step.completion_spell_ids or {}) do signals[#signals+1]={unit="player",id=id} end
  end
  local matched=false
  for _,signal in ipairs(signals) do
   local events={"UNIT_SPELLCAST_SUCCEEDED"}
   if signal.allow_failure then events[2]="UNIT_SPELLCAST_FAILED_QUIET" end
   for _,event in ipairs(events) do
    local k=key(signal.unit or "player",signal.id,event)
    if step.cast_origin[k]==nil then step.cast_origin[k]=counts[k] or 0 end
    if (counts[k] or 0)>step.cast_origin[k] then matched=true end
   end
  end
  return matched
 end
 return self
end
return M
