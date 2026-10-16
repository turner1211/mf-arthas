local M={}
local armed,right_down,last_target,was_combat,last_swap=nil,false,nil,false,-math.huge
local click_target,click_until,was_auto=nil,-math.huge,false
function M.update(target,right,hover,combat,auto,time)
 time=time or 0
 if was_combat and not combat then armed=nil end
 if target~=last_target then armed=nil end
 if right and not right_down then click_target=hover;click_until=time+0.8 end
 if target~=nil and time<=click_until and click_target==target then armed=target;click_target=nil end
 -- A confirmed auto-attack transition also covers clicks missed between updates.
 -- Merely selecting another target while auto-attack stays on does not authorize it.
 if target~=nil and auto==true and not was_auto then armed=target end
 was_auto=auto==true
 right_down=right;last_target=target;was_combat=combat
 return target~=nil and armed==target
end
function M.transfer(target,time)
 armed=target;last_target=target;last_swap=time
end
function M.can_swap(time) return armed~=nil and time-last_swap>=5 end
return M
