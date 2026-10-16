-- Bounded alternatives around an unsafe exact landing anchor.
local M={}
function M.find(goal,measure,validate)
 local pending=false
 for _,radius in ipairs({6,12}) do
  for _,offset in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
   local center,status=measure({x=goal.x+offset[1]*radius,y=goal.y+offset[2]*radius,z=goal.z})
   pending=pending or status=='pending'
   if center and math.abs(center.z-goal.z)<=3 then
    local pad,reason=validate(center)
    if pad then return pad end
    pending=pending or reason=='corridor_pending'
   end
  end
 end
 return nil,pending and 'corridor_pending' or 'corridor_unavailable'
end
return M
