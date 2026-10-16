local M={};M.__index=M
local function call(default,fn,...)
 if type(fn)~="function" then return default end
 local ok,value=pcall(fn,...);if ok then return value end
 return default
end
local function damaged(inventory)
 if type(inventory)~="table" or type(inventory.get_item_durability)~="function" then return false end
 for slot=1,19 do
  local row=call(nil,inventory.get_item_durability,slot)
  if type(row)=="table" then
   local current,max=tonumber(row.current),tonumber(row.max)
   if current and max and max>0 and current<max then return true end
  end
 end
 return false
end
local function distance(a,b)
 if not a or not b then return math.huge end
 local dx,dy,dz=(a.x or 0)-(b.x or 0),(a.y or 0)-(b.y or 0),(a.z or 0)-(b.z or 0)
 return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function repair_vendor(player,objects)
 local origin=call(nil,player and player.get_position,player);local best,best_distance
 if not origin then return nil end
 for _,object in pairs(objects or {}) do
  local valid=call(false,object and object.is_valid,object)
  local dead=call(false,object and object.is_dead,object)
  local enemy=call(false,player and player.is_enemy_with,player,object)
  local flags=tonumber(call(0,object and object.get_npc_flags,object)) or 0
  if valid and not dead and not enemy and math.floor(flags/4096)%2==1 then
   local d=distance(origin,call(nil,object.get_position,object))
   if d<=8 and (not best_distance or d<best_distance) then best,best_distance=object,d end
  end
 end
 return best
end
function M.new(api)
 return setmetatable({api=api,next_action=0,waiting_until=0,done=false,attempts=0},M)
end
function M:reset() self.next_action=0;self.waiting_until=0;self.done=false;self.attempts=0 end
function M:tick(player,now)
 local a=self.api
 if self.done or not player or call(true,player.is_in_combat,player) or call(false,player.is_dead,player)
  or call(false,player.is_ghost,player) or call(false,player.is_casting_spell,player)
  or call(false,player.is_channelling_spell,player) then return false end
 if not damaged(a.inventory) then
  self.done=true
  if call(false,a.can_repair) and a.close_merchant then pcall(a.close_merchant) end
  return false
 end
 if call(false,a.can_repair) then
  local cost=tonumber(call(0,a.repair_cost)) or 0
  if cost<=0 then self.done=true;if a.close_merchant then pcall(a.close_merchant) end;return false end
  if now<self.next_action then return true,"mount_vendor_repair_wait" end
  local ok,result=pcall(a.repair,false)
  self.next_action=now+1;self.waiting_until=now+3
  if ok and result~=false then return true,"repairing_from_packmaster" end
  self.attempts=self.attempts+1
  if self.attempts>=2 then self.done=true end
  return false
 end
 if now<self.waiting_until then return true,"opening_packmaster_vendor" end
 if now<self.next_action or not call(false,player.is_mounted,player) then return false end
 if self.attempts>=3 then self.done=true;return false end
 local vendor=repair_vendor(player,call({},a.objects))
 if not vendor then return false end
 if a.stop then a.stop() end
 local ok,result=pcall(a.interact,vendor)
 self.attempts=self.attempts+1;self.next_action=now+2;self.waiting_until=now+1.5
 if not ok or result==false then
  if self.attempts>=3 then self.done=true end
  return false
 end
 return true,"opening_packmaster_vendor"
end
return M
