-- Count our engaged enemies, once per GUID, in the spell's actual impact area.
local M={}
local function same(a,b)
 return a and b and (a==b or a.get_guid and b.get_guid and a:get_guid()==b:get_guid())
end
local function valid(o) return o and o:is_valid() and not o:is_dead() end
function M.capture(player,target,objects)
 local result,seen={},{}
 local pet=player:get_pet()
 local function add(enemy,selected)
  if not valid(enemy) or enemy:is_player() or not player:can_attack(enemy) then return end
  if not selected then
   if not enemy.is_unit or not enemy:is_unit() or not enemy:is_in_combat() then return end
   local victim=enemy:get_target()
   if not same(victim,player) and not (valid(pet) and same(victim,pet)) then return end
  end
  local key=enemy.get_guid and tostring(enemy:get_guid()) or tostring(enemy)
  if not seen[key] then seen[key]=true;result[#result+1]=enemy end
 end
 if target then add(target,true) end
 for _,enemy in pairs(objects or {}) do add(enemy,false) end
 return result
end
function M.count(enemies,center,radius)
 if not center or type(center.x)~="number" or type(center.y)~="number" or type(center.z)~="number" then return 0 end
 local count=0
 for _,enemy in ipairs(enemies or {}) do
  if valid(enemy) then
   local p=enemy:get_position()
   if p and type(p.x)=="number" and type(p.y)=="number" and type(p.z)=="number"
    and (p.x-center.x)^2+(p.y-center.y)^2+(p.z-center.z)^2<=radius*radius then count=count+1 end
  end
 end
 return count
end
return M
