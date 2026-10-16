-- Confirms native interaction requests from game events. The input API only
-- reports that a request was dispatched; it does not report the game result.
local M={}
local accepted={GOSSIP_SHOW=true,QUEST_GREETING=true,QUEST_DETAIL=true,QUEST_PROGRESS=true,
 QUEST_COMPLETE=true,MERCHANT_SHOW=true,TAXIMAP_OPENED=true,LOOT_OPENED=true,
 ITEM_TEXT_BEGIN=true,PLAYER_INTERACTION_MANAGER_FRAME_SHOW=true,QUEST_LOG_UPDATE=true,
 QUEST_ITEM_UPDATE=true}
function M.new(time)
 local self={time=time,sequence=0,receipts={}}
 function self:begin(key,timeout,evidence)
  self.sequence=self.sequence+1
  local token=self.sequence
  self.receipts[token]={key=key,started=self.time(),deadline=self.time()+(timeout or 1.25),state="pending",evidence=evidence}
  return token
 end
 function self:event(name,args)
  local state,error_id
  if accepted[name] then state="accepted"
  elseif name=="UI_ERROR_MESSAGE" then
   state="refused";error_id=tostring(args and (args[3] or args[2]) or "UI_ERROR_MESSAGE")
  end
  if not state then return end
  for _,row in pairs(self.receipts) do
   if row.state=="pending" then
    row.event=name;row.error_id=error_id
    if not row.evidence or state=="refused" then row.state=state end
   end
  end
 end
 function self:status(token,credit)
  local row=self.receipts[token]
  if not row then return "missing" end
  if row.evidence and type(credit)=="number" and type(row.evidence.credit)=="number" and credit>row.evidence.credit then
   row.state="accepted";row.event="objective_credit";row.error_id=nil
  end
  if row.state=="pending" and self.time()>=row.deadline then row.state="timeout" end
  return row.state,row.error_id,row.event
 end
 function self:finish(token) self.receipts[token]=nil end
 function self:reset() self.receipts={} end
 return self
end
return M
