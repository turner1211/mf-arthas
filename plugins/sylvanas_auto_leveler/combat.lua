local Catalog=require("combat_catalog")
local Helper=require("common/utility/spell_helper")
local Targets=require("combat_targets")
local Specialization=require("specialization")
local RuntimeApi=require("leveler_runtime_api")
local M={}
local function invoke(fn,...)
 if type(fn)~="function" then return false end
 local ran,result=pcall(fn,...)
 return ran and result==true
end
local function dispatch(fn,...)
 if type(fn)~="function" then return false end
 local ran,result=pcall(fn,...)
 return ran and result~=false
end
local function read(fn,fallback,...)
 if type(fn)~="function" then return fallback end
 local ran,result=pcall(fn,...)
 if not ran then return fallback end
 return result
end
local function valid(o) return o and o:is_valid() and not o:is_dead() end
local function objects() return RuntimeApi.objects() end
local function hp(o) return o:get_health()/math.max(1,o:get_max_health())*100 end
local aura_cache,aura_cache_at={},-math.huge
local function aura(o,id,debuff)
 local now=core.time()
 if now~=aura_cache_at then aura_cache={};aura_cache_at=now end
 local row=aura_cache[o]
 if not row then row={};aura_cache[o]=row end
 local kind=debuff and "debuffs" or "buffs"
 if row[kind]==nil then row[kind]=(debuff and o:get_debuffs() or o:get_buffs()) or {} end
 for _,b in pairs(row[kind]) do if b.buff_id==id then return true end end
 return false
end
function M.new(log,motion)
 local self={next=0,failed={},pet_next=0,identity="",diagnostic=0,face_next=0,spell_names={},book_next=0,enemies=1,defense_until=0}
 local function emit(event,fields) if log then log(event,fields) end end
 function self:stop_chase()
  if self.chasing then self.chase_epoch=(self.chase_epoch or 0)+1;motion.stop();self.chasing=nil;self.chase_goal=nil end
 end
 function self:detect(p)
  local cid=p:get_class();local sid=Specialization.resolve(cid,read(core.spell_book.get_specialization_id,nil),
   core.game_ui and read(core.game_ui.get_specialization,nil) or nil)
  local c=Catalog.classes[cid];local s=Catalog.specs[sid]
  if s and s.class_id~=cid then s=nil end
  local identity=tostring(cid)..":"..tostring(sid)..":"..tostring(p:get_level())
  if identity~=self.identity then
   self.identity=identity
   self.failed={};self.book_next=0
   emit("combat_identity",{class_id=cid,spec_id=sid,class=c and c.name or "Unknown",spec=s and s.name or "Starter",level=p:get_level()})
  end
  return c,s
 end
 local function resolve(id)
  if type(id)=="number" then return id end
  if core.time()>=self.book_next then
   self.book_next=core.time()+1;self.spell_names={}
   for key,value in pairs(read(core.spell_book.get_spells,{}) or {}) do
    local spell_id=type(value)=="number" and value or type(key)=="number" and key
    local name=type(value)=="string" and value or spell_id and read(core.spell_book.get_spell_name,nil,spell_id)
    if spell_id and type(name)=="string" then self.spell_names[name]=spell_id end
   end
  end
  return self.spell_names[id]
 end
 function self:cast(row,p,target,kind)
  local id=resolve(row.id);local now=core.time()
  if not id or (Catalog.empowered[id] and not row.empower) or (self.failed[id] or 0)>now then return false end
  if read(core.spell_book.is_spell_known,false,id)~=true then return false end
  if row.hp and hp(p)>row.hp then return false end
  if row.combat_only and not p:is_in_combat() then return false end
  if row.target_hp_min and (not target or hp(target)<row.target_hp_min) then return false end
  if row.aoe then
   local count=self.enemies
   if self.engaged then
    local center=row.aoe_center=="player" and p or target
    count=Targets.count(self.engaged,center and center:get_position(),row.radius or 8)
   end
   if count<row.aoe then return false end
  end
  if row.execute and hp(target)>row.execute then return false end
  if row.combo and p:get_power(4)<row.combo then return false end
  if row.power_type and p:get_power(row.power_type)<(row.power_min or 0) then return false end
  if row.buff_id and not aura(p,row.buff_id) then return false end
  if row.buff and aura(row.self_target and p or target,id) or row.dot and aura(target,id,true) then return false end
  if id==6603 and read(core.spell_book.is_current_spell,false,id) then return false end
  local recipient=row.self_target and p or target
  local ground=row.ground or row.ground_self or read(core.spell_book.is_spell_position_cast,false,id)
  local ok
  if row.empower then
   if not Helper:is_spell_castable(id,p,recipient,false,false) then return false end
   if not self.izi and now>=(self.izi_retry or 0) then
    self.izi_retry=now+30;local loaded,sdk=pcall(require,"common/izi_sdk")
    if loaded and type(sdk)=="table" and type(sdk.spell)=="function" and type(sdk.cast_charge_spell)=="function" then self.izi=sdk end
   end
   if not self.izi then
    if now>=(self.empower_diagnostic or 0) then self.empower_diagnostic=now+30;emit("combat_empower_unavailable",{spell_id=id,reason="izi_charge_helper_not_loaded"}) end
    return false
   end
   local made,wrapper=pcall(self.izi.spell,id)
   ok=made and wrapper and invoke(self.izi.cast_charge_spell,wrapper,row.empower,recipient,"Leveling empower")
   if ok then self.empower={spell=wrapper,target=recipient,stage=row.empower,started=now} end
  elseif ground then
   local position=(row.ground_self and p or target):get_position()
   if not Helper.is_spell_castable_position or not core.input.cast_position_spell
    or not Helper:is_spell_castable_position(id,p,recipient,position,false,false,false) then return false end
   ok=invoke(core.input.cast_position_spell,id,position)
  else
   if not Helper:is_spell_castable(id,p,recipient,false,false) then return false end
   ok=invoke(core.input.cast_target_spell,id,recipient)
  end
  self.next=now+((kind=="form" or kind=="pet_summon" or kind=="pet_revive") and 3 or 0.25)
  if not ok then self.failed[id]=now+1 end
  emit(ok and "combat_cast" or "combat_cast_failed",{spell_id=id,kind=kind,identity=self.identity})
  return ok
 end
 function self:tick(requested,prepare)
  local p=RuntimeApi.player()
  if not valid(p) or p:is_ghost() then self:stop_chase();return false end
  if self.empower then
   local job=self.empower
   if not valid(job.target) or core.time()-job.started>8 then self.empower=nil
   elseif p:is_casting_spell() or p:is_channelling_spell() then
    self:stop_chase()
    if not invoke(self.izi and self.izi.cast_charge_spell,job.spell,job.stage,job.target,"Leveling empower") then
     self.empower=nil;emit("combat_cast_failed",{kind="empower_channel",identity=self.identity})
     return false
    end
    return true
   elseif core.time()-job.started<1 then return true
   else self.empower=nil end
  end
   if (not p:is_in_combat() and not requested and not prepare) or p:is_casting_spell() or p:is_channelling_spell() then self:stop_chase() end
  local c,s=self:detect(p)
  if not c or core.time()<self.next or p:is_casting_spell() or p:is_channelling_spell() then return false end
  local target=requested or p:get_target()
  if not valid(target) or target:is_player() or not p:can_attack(target) then target=nil end
  local object_snapshot
  local function combat_objects()
   if not object_snapshot then object_snapshot=motion and motion.objects and motion.objects() or objects() end
   return object_snapshot
  end
  if not requested and p:is_in_combat() then
   local pet=p:get_pet();local best=math.huge;local attacker
   local fallback,fallback_distance=nil,math.huge
   local function same(a,b)
    return a and b and (a==b or a.get_guid and b.get_guid and a:get_guid()==b:get_guid())
   end
   for _,enemy in pairs(combat_objects()) do
    if valid(enemy) and enemy.is_unit and enemy:is_unit() and not enemy:is_player()
        and p:can_attack(enemy) and enemy:is_in_combat() then
     local a,b=p:get_position(),enemy:get_position()
     local distance=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
     if distance<=40 and distance<fallback_distance then fallback=enemy;fallback_distance=distance end
     local victim=enemy:get_target()
     if same(victim,p) or valid(pet) and same(victim,pet) then
      if (distance<=40 or same(target,enemy) and distance<=60) and (same(target,enemy) or distance<best and not same(target,attacker)) then attacker=enemy;best=distance end
     end
    end
   end
   -- Retail can leave the player in combat after the last selected attacker
   -- dies or evades. The controller intentionally pauses quest movement while
   -- that flag is set, so acquire the nearest active hostile as a recovery
   -- target instead of standing indefinitely in combat_rotation.
   if not attacker and not target and fallback then
    attacker=fallback;best=fallback_distance
    emit("combat_orphan_target",{npc_id=fallback:get_npc_id(),distance=fallback_distance})
   end
   if attacker then
    if not same(target,attacker) then
      local selected=dispatch(core.input.set_target,attacker);self.face_next=0
      emit("combat_aggro_target",{npc_id=attacker:get_npc_id(),distance=best,accepted=selected})
    end
    target=attacker
   end
  end
  if prepare and not p:is_in_combat() then target=nil end
  self.engaged=Targets.capture(p,target,combat_objects())
  self.enemies=math.max(1,Targets.count(self.engaged,target and target:get_position(),8))
  local mode=self.enemies>=2 and "aoe" or "single_target"
  if mode~=self.mode then self.mode=mode;emit("combat_target_mode",{mode=mode,enemies=self.enemies,identity=self.identity}) end
  -- Survival casts must remain available even while approaching a distant enemy.
  for _,row in ipairs(c.heals) do
   local recipient=p;if row.enemy then recipient=target end
   if recipient and self:cast(row,p,recipient,"heal") then self:stop_chase();return true end
  end
  if p:is_in_combat() and hp(p)<=45 and core.time()>=self.defense_until then
   for _,row in ipairs(c.defense) do
    local recipient=p;if row.enemy then recipient=target end
    if recipient and self:cast(row,p,recipient,"defense") then
     -- Do not stack major defensives on adjacent updates while health has not
     -- had time to react to the first cooldown.
     self.defense_until=core.time()+4;self:stop_chase();return true
    end
   end
  end
  if target and target.is_active_spell_interruptable and target:is_active_spell_interruptable()
   and (target:is_casting_spell() or target.is_channelling_spell and target:is_channelling_spell()) then
   local interrupt_now=true
   if not (target.is_channelling_spell and target:is_channelling_spell())
       and target.get_active_spell_cast_start_time and target.get_active_spell_cast_end_time then
    local started=tonumber(target:get_active_spell_cast_start_time())
    local finish=tonumber(target:get_active_spell_cast_end_time())
    -- Cast timestamps use the game's millisecond clock; core.time() is the
    -- unrelated seconds elapsed since injection and only drives our throttles.
    local now=tonumber(core.game_time and core.game_time())
    if now and started and finish and finish>started and now>=started and now<finish then
     local progress=(now-started)/(finish-started)
     -- Let the enemy spend part of the cast, but never wait into the final
     -- reaction margin. This also avoids visibly frame-perfect kicks.
     interrupt_now=progress>=0.35 or finish-now<=350
    end
   end
   if interrupt_now then
    for _,row in ipairs(c.interrupts or {}) do if self:cast(row,p,target,"interrupt") then return true end end
   end
  end
  if not p:is_in_combat() then
   for _,row in ipairs(c.buffs or {}) do if self:cast(row,p,p,"buff") then return true end end
  end
  -- A quest-selected hostile is a valid movement request before the server has
  -- put the player in combat. This lets melee characters close the gap and
  -- ranged characters reach casting distance before their opening attack.
  if motion and (p:is_in_combat() or requested) and not prepare then
   if not target then self:stop_chase();self.chase_target=nil;self.chase_short_arrivals=nil;return false end
   local target_key=target.get_guid and target:get_guid() or target
   if self.chase_target~=target_key then
    self:stop_chase();self.chase_target=target_key;self.chase_short_arrivals=nil;self.chase_next=nil
   end
   local cid=p:get_class();local sid=Specialization.resolve(cid,read(core.spell_book.get_specialization_id,nil),
    core.game_ui and read(core.game_ui.get_specialization,nil) or nil)
   local ranged=cid==5 or cid==8 or cid==9 or cid==13 or cid==12 and sid==1480 or cid==3 and sid~=255
       or cid==7 and sid~=263 or cid==11 and sid~=103 and sid~=104
   local a,b=p:get_position(),target:get_position()
   local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z;local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
   local range=ranged and 25 or 3.5
   if distance>range and distance<=60 then
    if self.chasing and core.time()-(self.chase_started or core.time())>8 then self:stop_chase() end
    local old=self.chase_goal
    local changed=not old or (old.x-b.x)^2+(old.y-b.y)^2+(old.z-b.z)^2>16
    if not self.chasing and core.time()>=(self.chase_next or 0) then
     local stand_off=ranged and math.max(2,20-5*(self.chase_short_arrivals or 0)) or 2.5
     local scale=math.max(0,(distance-stand_off)/distance)
     local goal={x=a.x+dx*scale,y=a.y+dy*scale,z=b.z}
     self.chasing=true;self.chase_goal={x=b.x,y=b.y,z=b.z};self.chase_next=core.time()+2;self.chase_started=core.time()
     self.chase_epoch=(self.chase_epoch or 0)+1;local epoch=self.chase_epoch
     motion.move(goal,function(ok,reason)
      if epoch~=self.chase_epoch then return end
      if ok then self.chase_short_arrivals=(self.chase_short_arrivals or 0)+1 end
      self.chasing=nil;self.chase_next=core.time()+2
      if not ok then emit("combat_approach_failed",{reason=reason}) end
     end)
     emit("combat_approach",{range=range,distance=distance})
    end
    return false
   end
   self:stop_chase();self.chase_short_arrivals=nil
  end
  if target and core.time()>=self.face_next and (p:is_in_combat() or requested or not p.is_moving or not p:is_moving()) then
    local faced=dispatch(core.input.look_at,target:get_position());self.face_next=core.time()+0.75
    if not faced then emit("combat_face_rejected",{npc_id=target:get_npc_id()}) end
  end
  local pet=p:get_pet()
  local form_ids={[768]=1,[5487]=5,[24858]=31}
  local in_form=s and s.form and (aura(p,s.form) or read(core.spell_book.get_shapeshift_form_id,nil)==form_ids[s.form])
  if s and s.form and not in_form and self:cast({id=s.form},p,p,"form") then return true end
  if not (s and s.no_pet) and (c.pet or s and s.summons) then
   if not valid(pet) then
    if pet and pet:is_valid() and pet:is_dead() and c.revive then
     if self:cast({id=c.revive},p,p,"pet_revive") then return true end
    elseif not p:is_in_combat() then
     for _,id in ipairs(s and s.summons or c.summons or {}) do if self:cast({id=id},p,p,"pet_summon") then return true end end
    end
   else
    if c.pet_heal and hp(pet)<65 and self:cast({id=c.pet_heal},p,pet,"pet_heal") then return true end
    if target and core.time()>=self.pet_next then invoke(core.input.pet_attack,target);self.pet_next=core.time()+1 end
   end
  end
  if prepare or not target then return false end
  for _,row in ipairs(s and s.cooldowns or {}) do
   if self:cast(row,p,target,"cooldown") then return true end
  end
  for _,rows in ipairs({s and s.aoe or {},c.aoe or {}}) do
   for _,row in ipairs(rows) do if self:cast(row,p,target,"aoe") then return true end end
  end
  if core.spell_book.get_assisted_spell_id then
   local id=read(core.spell_book.get_assisted_spell_id,nil,target,false)
   if type(id)=="number" and id>0 and self:cast({id=id},p,target,"assisted") then return true end
  end
  for _,rows in ipairs({s and s.supplemental or {},s and s.attacks or {},c.attacks}) do
   for _,row in ipairs(rows) do if self:cast(row,p,target,"fallback") then return true end end
  end
  if self:cast({id=6603},p,target,"autoattack") then return true end
  if core.time()>=self.diagnostic then self.diagnostic=core.time()+5;emit("combat_wait",{reason="no_castable_spell",identity=self.identity}) end
  return false
 end
 return self
end
return M


