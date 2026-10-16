-- Resolve alternative quest IDs from observed quest state or an actual offer.
local M={}
function M.parse(value)
 if type(value)~="string" or not value:find("^",1,true) or value:find("[^%d%^]") then return end
 local ids={};for token in (value.."^"):gmatch("(.-)%^") do
  local id=tonumber(token);if not id or id<=0 then return end;ids[#ids+1]=id
 end
 return #ids>1 and ids or nil
end
function M.contains(step,id)
 if step.quest_id then return step.quest_id==id end
 for _,candidate in ipairs(step.quest_ids or {}) do if candidate==id then return true end end
 return false
end
function M.observe(step,on_quest,completed)
 if step.quest_id then return step.quest_id end
 local active
 for _,id in ipairs(step.quest_ids or {}) do
  if on_quest and on_quest(id) then
   if active then return nil,"ambiguous_active_quest_variants" end
   active=id
  end
 end
 if active then return active end
 for _,id in ipairs(step.quest_ids or {}) do if completed and completed(id) then return id end end
 return nil,"quest_variant_not_observed"
end
return M
