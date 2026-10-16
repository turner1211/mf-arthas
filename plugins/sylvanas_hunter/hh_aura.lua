local U=require('hh_util')
local A={}
local function id_of(a)
 return type(a)=='table' and (U.number(a.spell_id) or U.number(a.buff_id)
  or U.number(a.debuff_id) or U.number(a.id)) or nil
end
local function owner_ok(a,owner)return not owner or U.same(a and a.caster,owner)end
local function raw_left(a)
 if type(a)~='table'then return nil end
 for _,key in ipairs({'remaining','time_remaining','remaining_time'})do
  local value=U.number(a[key]);if value and value>0 and value<3600 then return value end
 end
 local ending=U.number(a.expire_time) or U.number(a.expiration_time)
  or U.number(a.expires_at) or U.number(a.expiration)
 local now=U.number(U.fn(core.game_time))
 if ending and now and ending>now then
  local left=(ending-now)/1000;if left>0 and left<3600 then return left end
 end
end
local function result(a,left)
 return true,left,U.number(a and a.stacks) or U.number(a and a.count)
  or U.number(a and a.applications) or 1,a and a.points
end
function A.read(unit,id,debuff,owner)
 local data=U.call(unit,debuff and 'get_debuff_data' or 'get_buff_data',{id})
 if type(data)=='table' and (data.is_active==true or data.active==true) and owner_ok(data,owner) then
  local remaining=U.number(data.remaining) or U.number(data.time_remaining) or U.number(data.remaining_time)
  return result(data,remaining and remaining>0 and remaining/1000 or nil)
 end
 -- Midnight can hide an aura from the legacy buff/debuff list while preserving
 -- positive evidence in the combined list. Positive evidence wins over a stale
 -- manager false; absence from every list remains unknown.
 for _,method in ipairs({'get_auras',debuff and 'get_debuffs' or 'get_buffs','get_all_buffs'})do
  local list=U.call(unit,method)
  if type(list)=='table'then for _,a in pairs(list)do
   if id_of(a)==id and owner_ok(a,owner) then return result(a,raw_left(a)) end
  end end
 end
 if type(data)=='table' and (data.is_active==false or data.active==false) then return false,nil,0 end
 return nil,nil,nil -- no positive evidence; hidden data is not proof of absence
end
function A.any(unit,ids,debuff)
 for _,id in ipairs(ids)do if A.read(unit,id,debuff)==true then return true end end
 return false
end
return A
