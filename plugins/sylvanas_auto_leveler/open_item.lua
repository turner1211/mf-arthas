local M={}
function M.tick(operation,slots,now,use)
 if type(slots)~="table" or type(now)~="number" then return false end
 local count,selected=0,nil
 for _,slot in pairs(slots) do
  local item=slot.item
  if item and item.get_item_id and item:get_item_id()==operation.item_id then
   if type(slot.stack_count)~="number" or slot.stack_count<1 then return false end
   count=count+slot.stack_count
   if type(slot.bag_id)=="number" and type(slot.bag_slot)=="number" then selected=slot end
  end
 end
 -- A missing item before dispatch is not proof that the box was opened.
 if operation.open_initial_count and count<operation.open_initial_count then return true end
 if not selected or type(use)~="function" or now<(operation.open_retry_at or 0) then return false end
 operation.open_retry_at=now+2
 operation.open_initial_count=operation.open_initial_count or count
 -- Successful dispatch alone is not completion. Re-read bags on next tick.
 pcall(use,selected.bag_id,selected.bag_slot)
 return false
end
return M
