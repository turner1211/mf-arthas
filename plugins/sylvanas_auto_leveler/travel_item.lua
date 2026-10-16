local M={}
function M.tick(step,a)
 if step.travel_item_id~=50220 or step.travel_item_quest~=24678 or not a.on_quest or a.on_quest(24678)~=true then return false end
 if not a.map or a.map()~=179 or not a.count or not a.cooldown or type(a.use)~='function' then return false end
 local count,cooldown=a.count(50220),a.cooldown(50220)
 if type(count)~='number' or count<1 or type(cooldown)~='number' or cooldown>0 then return false end
 local now=a.time();if now<(step.travel_item_retry_at or 0) then return false end
 step.travel_item_retry_at=now+1
 local ok,result=pcall(a.use,50220);return ok and result==true
end
return M
