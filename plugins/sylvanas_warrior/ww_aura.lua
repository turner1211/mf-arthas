local U=require('ww_util')
local A={}
function A.read(unit,id,debuff,owner)
 local data=U.call(unit,debuff and 'get_debuff_data' or 'get_buff_data',{id})
 if type(data)=='table' and data.is_active==true and (not owner or U.same(data.caster,owner)) then
  local remaining=U.number(data.remaining)
  return true,remaining and remaining>0 and remaining/1000 or nil,U.number(data.stacks) or U.number(data.count) or 1,data.points
 end
 local list=U.call(unit,debuff and 'get_debuffs' or 'get_buffs')
 if type(list)=='table' then
  for _,a in pairs(list) do
   if U.number(a.buff_id)==id and (not owner or U.same(a.caster,owner)) then
    local ending=U.number(a.expire_time);local now=U.number(U.fn(core.game_time))
    local left=ending and now and ending>now and (ending-now)/1000 or nil
    return true,left,U.number(a.count) or U.number(a.stacks) or 1,a.points
   end
  end
 end
 return nil,nil,nil -- no positive evidence; hidden data is not proof of absence
end
function A.any(unit,ids,debuff)
 for _,id in ipairs(ids) do if A.read(unit,id,debuff)==true then return true end end
 return false
end
return A
