local M={}
function M.goal(text)
 if type(text)~="string" then return nil end
 local id,count=text:match("^%s*(%d+)%s+(%d+)%s*$")
 if not id then id=text:match("^%s*(%d+)%s*$");count="1" end
 id,count=tonumber(id),tonumber(count)
 if not id or id<1 or not count or count<1 then return nil end
 return {item_id=id,count=count}
end
function M.count(slots,id)
 if type(slots)~="table" then return nil end
 local total=0
 for _,slot in pairs(slots) do
  local item=slot.item
  if item and item.get_item_id and item:get_item_id()==id then
   if type(slot.stack_count)~="number" or slot.stack_count<0 then return nil end
   total=total+slot.stack_count
  end
 end
 return total
end
return M
