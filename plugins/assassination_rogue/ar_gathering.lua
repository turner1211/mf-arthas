-- Gathering uses the same host APIs as the existing Holy/Guardian plugins.
local M={status="Idle"}
local fish_ok,fish=pcall(require,"common/utility/fish_helper")
local move_ok,movement=pcall(require,"common/utility/simple_movement")
local vec_ok,vec3=pcall(require,"common/geometry/vector_3")
local movement_owned=false
local busy_until=0
local next_action,last_fish=0,-math.huge
local blocked={}
local looted={}
local probed={}
local skin_pending,skin_tries=nil,{}
local last_diagnostic=-math.huge
local function call(o,k,...)
 if not o or type(o[k])~="function" then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function note(T,s) M.status=s;T.note("GATHERING",{s}) end
local function distance(a,b)
 local d=call(a,"distance_to",b);if type(d)=="number" then return d end
 local x,y=call(a,"get_position"),call(b,"get_position")
 if x and y then return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2) end
end
function M.stop()
 if movement_owned then call(movement,"clear_navigation");movement_owned=false end
end
function M.busy() return skin_pending~=nil or movement_owned or core.time()<busy_until end
function M.confirm_skin(success,T)
 if not skin_pending then return end
 local req=skin_pending;skin_pending=nil
 if success then blocked[req.key..':skin']=core.time()+120
 elseif (skin_tries[req.key] or 0)<3 then probed[req.key]=nil;blocked[req.key..':skin']=core.time()+1 end
 note(T,(success and 'Skinning confirmed / ' or 'Skinning failed / ')..req.name)
end
function M.skin_error(message,T)
 if skin_pending then T.note('SKINNING_ERROR',{'target='..skin_pending.name,'message='..tostring(message)}) end
end
function M.update(p,opts,T,cached_objects)
 if call(p,"is_in_combat")==true or call(p,"is_mounted")==true then M.stop();M.status="Paused for combat / mount";return end
 if skin_pending then
  if core.time()<skin_pending.expires then M.status='Skinning: waiting for cast confirmation';return end
  M.confirm_skin(false,T)
 end
 if not opts.fishing and not opts.looting and not opts.skinning then
  M.stop();busy_until=0;M.status='Gathering disabled';return
 end
 if core.time()<next_action then return end
 local now=core.time();next_action=now+0.25
 for k,t in pairs(blocked) do if t<now then blocked[k]=nil end end
 for k,t in pairs(looted) do if now-t>120 then looted[k]=nil;probed[k]=nil end end
 local list=cached_objects
 if type(list)~='table' then
  local ok;ok,list=pcall(core.object_manager.get_all_objects)
  if not ok or type(list)~='table' then return end
 end
 if opts.fishing then
  busy_until=now+1
  M.stop()
  if not fish_ok then M.status="Fishing helper unavailable";return end
  local bobber
  for _,o in pairs(list) do if call(fish,"is_fish_bobber",o)==true then bobber=o;break end end
  if bobber then
   if call(fish,"does_bobber_have_fish",bobber)==true and call(fish,"open_loot",bobber)==true then
    call(fish,"loot_all");next_action=now+1.5;note(T,"Fishing catch requested")
   end
   return
  end
  if call(p,"is_casting_spell")==true or call(p,"is_channelling_spell")==true or call(p,"is_moving")==true then return end
  if now-last_fish>=2 then
   last_fish=now
   local started=core.profession and core.profession.open_profession and core.profession.open_profession(core.profession.FISHING)
   next_action=now+2;note(T,started and "Fishing cast accepted" or "Fishing waiting for profession")
  end
  return
 end
 if call(p,"is_casting_spell")==true or call(p,"is_channelling_spell")==true then M.stop();return end
 local nearest,range,kind=nil,35,nil
 local corpses,skins,unlooted=0,0,0
 for _,o in pairs(list) do
  if call(o,"is_valid")==true and call(o,"is_unit")==true and call(o,"is_dead")==true then
   local key=tostring(call(o,"get_guid") or o)
   local loot=call(o,"has_loot");local can_loot=call(o,'can_be_looted')==true
   local skin=call(o,"can_be_skinned")==true or call(o,"has_skin")==true
   local creature_type=call(o,'get_creature_type')
   local skin_species=creature_type==1 or creature_type==2
   local fallback=opts.skinning and skin_species and looted[key]~=nil and now-looted[key]>=1.5 and not probed[key]
   corpses=corpses+1;if skin then skins=skins+1 end;if loot==true then unlooted=unlooted+1 end
   local loot_complete=loot==false or looted[key] and now-looted[key]>=1.5 and not can_loot
   local action=(opts.looting or opts.skinning and (skin or skin_species)) and loot==true and can_loot and "loot"
      or opts.skinning and loot_complete and (skin or fallback) and "skin" or nil
   local d=distance(p,o)
   -- Skin at interaction range; loot_object has the reference host's approach flag.
   if action and type(d)=="number" and d<=range
      and not blocked[key..':'..action] then nearest,range,kind=o,d,action end
  end
 end
 if not nearest then
  M.stop();M.status=opts.skinning and "Skinning: waiting for eligible corpse within 35 yd" or "Gathering idle"
  if opts.skinning and now-last_diagnostic>=5 then
   last_diagnostic=now;T.note('SKINNING_CHECK',{'enabled=true','corpses='..corpses,'skin_flags='..skins,'loot_remaining='..unlooted})
  end
  return
 end
 if kind=="skin" and range>2 then
  if move_ok and vec_ok then
   local a,b=call(p,"get_position"),call(nearest,"get_position")
   if a and b then
    local scale=(range-1.5)/range
    call(movement,"move_to_position",vec3.new(a.x+(b.x-a.x)*scale,a.y+(b.y-a.y)*scale,a.z+(b.z-a.z)*scale))
    call(movement,"process");movement_owned=true;M.status="Skinning: approaching corpse";return
   end
  end
  M.status="Skinning: move within 2 yd (navigation unavailable)";return
 end
 M.stop()
 local key=tostring(call(nearest,"get_guid") or nearest)
 if kind=='skin' then
  if call(p,'is_moving')==true then busy_until=now+2;M.status='Skinning: waiting to stop moving';return end
  local selected=call(p,'get_target')
  if tostring(call(selected,'get_guid') or selected)~=key then
   if type(core.input.set_target)~='function' then M.status='Skinning: targeting API unavailable';return end
   local target_ok,target_result=pcall(core.input.set_target,nearest)
   busy_until=now+3
   if not target_ok or target_result~=true then next_action=now+1;note(T,'Skinning: corpse targeting rejected');return end
   selected=call(p,'get_target')
   if tostring(call(selected,'get_guid') or selected)~=key then next_action=now+0.25;M.status='Skinning: waiting for corpse target confirmation';return end
  end
  local buffs=call(p,'get_buffs') or call(p,'get_auras')
  if type(buffs)=='table' then for _,buff in pairs(buffs) do
   local valid,id=pcall(function()return buff.spell_id or buff.id end)
   if valid and (id==1784 or id==115191) then
    if type(core.input.cancel_buff)~='function' then M.status='Skinning: cancel Stealth manually (host API unavailable)';busy_until=now+2;return end
    local cancel_ok,cancel_result=pcall(core.input.cancel_buff,buff)
    local cancelled=cancel_ok and cancel_result~=false
    busy_until=now+3;next_action=now+0.5
    note(T,cancelled and 'Skinning: cancel Stealth requested; waiting for aura removal' or 'Skinning: Stealth cancellation failed')
    return
   end
  end end
 end
 local fn=kind=="loot" and core.input.loot_object or core.input.skin_object
 if type(fn)~="function" then M.status=kind.." API unavailable";return end
 local accepted
 if kind=="loot" then accepted=fn(nearest,true) else accepted=fn(nearest) end
 local skin_spell_known=false
 local skin_method='native interaction'
 if kind=='skin' then
  local spellbook=core.spell_book
  if spellbook and type(spellbook.is_spell_known)=='function' then
   local valid,value=pcall(spellbook.is_spell_known,8613);skin_spell_known=valid and value==true
  end
  if accepted~=true and skin_spell_known and type(core.input.cast_target_spell)=='function' then
   local usable_ok,usable=pcall(spellbook.is_usable_spell,8613)
   if usable_ok and usable==true then
    local cast_ok,cast_result=pcall(core.input.cast_target_spell,8613,nearest)
    accepted=cast_ok and cast_result==true;skin_method='targeted Skinning spell 8613'
   end
  end
 end
 if kind=='skin' then
  skin_tries[key]=(skin_tries[key] or 0)+1
  if accepted==true then
   probed[key]=true
   skin_pending={key=key,name=tostring(call(nearest,'get_name') or key),expires=now+5}
  elseif skin_tries[key]>=3 then probed[key]=true
  else probed[key]=nil end
  T.note('SKINNING_REQUEST',{'target='..tostring(call(nearest,'get_name') or key),
   'skin_flag='..tostring(call(nearest,'can_be_skinned')),'has_skin='..tostring(call(nearest,'has_skin')),
   'creature_type='..tostring(call(nearest,'get_creature_type')),'skin_spell_known='..tostring(skin_spell_known),
   'method='..skin_method,'accepted='..tostring(accepted)})
 end
 blocked[key..':'..kind]=now+(accepted==true and 5 or 2)
 if kind=='loot' and accepted==true then looted[key]=now end
 next_action=now+1.5;busy_until=now+(accepted==true and 3 or 1)
 note(T,kind.." "..(accepted==true and "request accepted" or "request rejected").." / "..tostring(call(nearest,"get_name") or key))
end
return M
