-- Automatic fishing, corpse looting and skinning.
local Settings=require("guardian_settings")
local generation=_G.__guardian_runtime_generation
local Aura=require("guardian_aura")
local fish=require("common/utility/fish_helper")
local movement=require("common/utility/simple_movement")
local vec3=require("common/geometry/vector_3")
local M={}
local fish_at,last_cast,loot_at,corpse_at,skin_at=0,-math.huge,0,0,0
local looted,skin_queue,skin_block={},{},{}
local movement_owned=false
local pending_fish,skin_target=nil,nil
local function status(s) Settings.gathering_status=s end
local function player()
 local p=core.object_manager.get_local_player()
 return p and p:is_valid() and not p:is_dead() and p or nil
end
local function travel(p)
 for _,id in ipairs({783,1066,33943,40120,210053}) do if Aura.read(p,id) then return true end end
 return false
end
local function objects()
 local ok,v=pcall(core.object_manager.get_all_objects)
 return ok and type(v)=="table" and v or {}
end
local function pos(o)
 local ok,v=pcall(o.get_position,o)
 return ok and v or nil
end
local function dist(a,b)
 a,b=pos(a),pos(b); if not a or not b then return nil end
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function key(o)
 if o and o.get_guid then local ok,v=pcall(o.get_guid,o); if ok and v then return tostring(v) end end
 return tostring(o)
end
local function stop()
 if movement_owned then pcall(movement.clear_navigation,movement); movement_owned=false end
end
local function fishing()
 if not Settings.on("fishing") then return end
 local p=player(); if not p or p:is_in_combat() or travel(p) then return end
 local now=core.time(); if now<fish_at then return end
 if pending_fish then
  local ok,done=pcall(fish.loot_all,fish)
  if ok and done then pending_fish=nil; fish_at=now+1.5; status("Fishing: catch looted")
  elseif now-pending_fish>=5 then pending_fish=nil; fish_at=now+10; status("Fishing: loot incomplete; waiting")
  else fish_at=now+0.35; status("Fishing: waiting for catch loot") end
  return
 end
 local bobber
 for _,o in pairs(objects()) do local ok,v=pcall(fish.is_fish_bobber,fish,o); if ok and v then bobber=o; break end end
 if bobber then
  local ok,ready=pcall(fish.does_bobber_have_fish,fish,bobber)
  if ok and ready then
   local opened_ok,opened=pcall(fish.open_loot,fish,bobber)
   if opened_ok and opened then pending_fish=now; fish_at=now+0.35; status("Fishing: waiting for catch loot")
   else fish_at=now+0.35 end
  else fish_at=now+0.25 end
  return
 end
 if not p:is_casting_spell() and not p:is_channelling_spell() and now-last_cast>=2 then
  local ok,started=pcall(core.profession.open_profession,core.profession.FISHING)
  last_cast=now; fish_at=now+(ok and started and 1 or 2)
  status(ok and started and "Fishing: cast started" or "Fishing: waiting to cast")
 end
end
local function looting()
 if not Settings.on("looting") or Settings.on("fishing") then return end
 local p=player(); if not p or p:is_in_combat() or travel(p) or p:is_casting_spell() or p:is_channelling_spell() then return end
 local now=core.time(); if now<loot_at then return end
 local nearest,range=nil,35
 for _,o in pairs(objects()) do
  local ok,ready=pcall(function() return o:is_valid() and o:is_unit() and o:is_dead() and o:can_be_looted() and o:has_loot() end)
  local d=ok and ready and (looted[key(o)] or 0)<=now and dist(p,o) or nil
  if d and d<=range then nearest,range=o,d end
 end
 if not nearest then loot_at=now+0.5; return end
 local ok,started=pcall(core.input.loot_object,nearest,true); started=ok and started==true
 loot_at=now+(started and 1.5 or 1); corpse_at=loot_at
 if started then
  local k=key(nearest); looted[k]=now+8
  skin_queue[k]={object=nearest,ready=now+1.5,expires=now+20}
  status("Looting: corpse looted")
 end
end
local function has_loot(o)
 local ok,v=pcall(function() return o:can_be_looted() and o:has_loot() end); return ok and v
end
local function can_skin(o)
 return (o.can_be_skinned and o:can_be_skinned()) or (o.has_skin and o:has_skin())
end
local function skinning()
 if not Settings.on("skinning") then stop(); skin_target=nil; return end
 if Settings.on("fishing") then stop(); skin_target=nil; return end
 local p=player(); if not p or p:is_in_combat() or travel(p) then stop(); return end
 if p:is_casting_spell() or p:is_channelling_spell() then stop(); return end
 local now=core.time(); if now<corpse_at then stop(); return end
 local nearest,range=nil,35
 for k,r in pairs(skin_queue) do
  local ok,valid=pcall(r.object.is_valid,r.object)
  if now>=r.expires or not ok or not valid then skin_queue[k]=nil
  elseif now>=r.ready and (skin_block[k] or 0)<=now and not has_loot(r.object) then
   local ready_ok,ready=pcall(can_skin,r.object); local d=ready_ok and ready and dist(p,r.object) or nil
   if d and d<=range then nearest,range=r.object,d end
  end
 end
 for _,o in pairs(objects()) do
  local ok,ready=pcall(function() return o:is_valid() and o:is_unit() and o:is_dead() and can_skin(o) and not has_loot(o) end)
  local d=ok and ready and (skin_block[key(o)] or 0)<=now and dist(p,o) or nil
  if d and d<=range then nearest,range=o,d end
 end
 -- Keep one corpse selected while moving or requesting its skinning cast.
 if skin_target and (skin_block[skin_target.key] or 0)<=now then
  local o=skin_target.object
  local ok,ready=pcall(function() return o:is_valid() and o:is_dead() and can_skin(o) and not has_loot(o) end)
  local d=ok and ready and dist(p,o) or nil
  if d and d<=35 then nearest,range=o,d else skin_target=nil end
 end
 if not nearest then stop(); status("Skinning: no harvestable corpse within 35 yd"); return end
 local k=key(nearest)
 if not skin_target or skin_target.key~=k then
  stop()
  local point=pos(p)
  skin_target={key=k,object=nearest,progress_at=now,position=point and {x=point.x,y=point.y,z=point.z},gather_at=nil}
  pcall(core.input.set_target,nearest)
 end
 local point=pos(p); local previous=skin_target.position
 if point and previous and (point.x-previous.x)^2+(point.y-previous.y)^2+(point.z-previous.z)^2>=0.25 then
  skin_target.position,skin_target.progress_at={x=point.x,y=point.y,z=point.z},now
 end
 if range>3.5 and now-skin_target.progress_at>=20
  or skin_target.gather_at and now-skin_target.gather_at>=10 then
  skin_block[k]=now+60; skin_queue[k]=nil; skin_target=nil
  stop(); status("Skinning: unreachable or failed corpse skipped for 60 seconds"); return
 end
 if range>3.5 then
  local a,b=pos(p),pos(nearest); local scale=(range-3.5)/range
  if not movement_owned then
   local ok,accepted=pcall(movement.move_to_position,movement,vec3.new(a.x+(b.x-a.x)*scale,a.y+(b.y-a.y)*scale,a.z+(b.z-a.z)*scale))
   movement_owned=ok and accepted~=false
  end
  status("Skinning: moving to corpse"); return
 end
 stop(); skin_target.gather_at=skin_target.gather_at or now; if now<skin_at then return end
 local ok,started=pcall(core.input.skin_object,nearest); started=ok and started==true
 skin_at=now+(started and 1.5 or 2); if started then skin_queue[key(nearest)]=nil end
 status(started and "Skinning: request accepted" or "Skinning: retrying corpse")
end
local function safe(fn,label) return function() local ok,e=pcall(fn); if not ok then stop(); status(label..": "..tostring(e)) end end end
M.fishing=safe(fishing,"Fishing"); M.looting=safe(looting,"Looting"); M.skinning=safe(skinning,"Skinning")
local next_tick=0
function M.update()
 if not Settings.allowed() then stop(); skin_target=nil; pending_fish=nil; status("Off"); return end
 local p=player(); if not p or p:is_in_combat() then stop(); skin_target=nil; pending_fish=nil; status("Paused during combat"); return end
 -- The simple_movement walker is stateful and must be advanced every host
 -- update. Keep object discovery throttled below, but never throttle an active
 -- skinning walk or re-submit its destination on every scan.
 if movement_owned then pcall(movement.process,movement) end
 if core.time()<next_tick then return end; next_tick=core.time()+0.15
 if Settings.on("fishing") then stop(); M.fishing(); return end
 pending_fish=nil
 M.looting(); if core.time()<corpse_at then stop(); return end; M.skinning()
 local now=core.time(); for k,v in pairs(looted) do if v<now then looted[k]=nil end end
 for k,v in pairs(skin_block) do if v<now then skin_block[k]=nil end end
end
function M.reset()
 stop(); pending_fish,skin_target=nil,nil
 looted,skin_queue,skin_block={},{},{}
 fish_at,last_cast,loot_at,corpse_at,skin_at,next_tick=0,-math.huge,0,0,0,0
end
local registered=safe(M.update,"Gathering")
core.register_on_update_callback(function() if _G.__guardian_runtime_generation==generation and Settings.is_guardian() then registered() end end)
return M
