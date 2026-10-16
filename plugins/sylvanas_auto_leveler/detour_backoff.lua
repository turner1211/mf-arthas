-- Bound repeated scans to the same map, start cell and destination layer.
local M={}
function M.new()
 local rows={}
 local function key(map,start,goal)
  return table.concat({map,math.floor(start.x/8),math.floor(start.y/8),math.floor(start.z/8),math.floor(goal.x/8),math.floor(goal.y/8),math.floor(goal.z/8)},":")
 end
 return {
  blocked=function(map,start,goal,now)local r=rows[key(map,start,goal)];return r~=nil and now<r end,
  failed=function(map,start,goal,now)
   local count=0;for k,v in pairs(rows)do if v<=now then rows[k]=nil else count=count+1 end end
   if count>=256 then rows={} end
   rows[key(map,start,goal)]=now+30
  end,
  clear=function(map,start,goal)rows[key(map,start,goal)]=nil end
 }
end
return M