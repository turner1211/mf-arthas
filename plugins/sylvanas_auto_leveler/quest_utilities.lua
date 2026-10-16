-- Protective quest items run alongside movement and objective interactions.
local M={}
function M.new()
 local self={next_attempt=0}
 function self:tick(now,api)
  if not api.active or api.busy or now<self.next_attempt then return end
  local id=191729
  local count=api.count(id)
  if not count or count<=0 then return end
  local remaining=api.cooldown(id)
  if type(remaining)=="number" and remaining>0 then
   self.next_attempt=now+math.min(remaining,1);return
  end
  -- Without authoritative cooldown data, check periodically; API acceptance
  -- never counts as quest completion and never stops the active navigation job.
  self.next_attempt=now+3
  local accepted=api.use(id)
  api.log("quest_utility_item_requested",{quest_id=66324,item_id=id,accepted=accepted})
 end
 return self
end
return M
