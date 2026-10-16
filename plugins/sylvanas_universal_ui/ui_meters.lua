local U=require('ui_util')
local M={}
local function source(session)
 if type(session)~='table' or type(session.sources)~='table' then return end
 for _,row in pairs(session.sources)do
  if row.is_local_player==true then
   local total=U.num(row.total_amount);local rate=U.num(row.per_second)
   local duration=U.num(session.duration)
   if not rate and total and duration and duration>0 then rate=total/duration end
   return total and math.max(0,total),rate and math.max(0,rate)
  end
 end
end
function M.read(overall)
 local api=core.damage_meter
 local result={label=overall and 'OVERALL' or 'CURRENT FIGHT',status='Meter unavailable'}
 if not api or U.fn(api.is_available)~=true then return result end
 local kind=overall and 0 or 1
 local damage=U.fn(api.get_session_from_type,kind,0)
 local healing=U.fn(api.get_session_from_type,kind,2)
 result.damage,result.dps=source(damage)
 result.healing,result.hps=source(healing)
 result.status=(result.damage or result.healing) and 'Your performance' or 'No personal combat data'
 return result
end
function M.format(value)
 if not value then return '--' end
 return string.format('%.0f',value)
end
function M.reset()
 local api=core.damage_meter
 if not api or type(api.reset_all)~='function' then return false end
 return pcall(api.reset_all)
end
return M
