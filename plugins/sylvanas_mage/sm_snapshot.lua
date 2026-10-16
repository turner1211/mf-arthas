local U,A,S,X,T,Dummy=require('sm_util'),require('sm_aura'),require('sm_spells'),require('sm_intel'),require('sm_timers'),require('sm_dummy')
local ok,Pvp=pcall(require,'common/utility/pvp_helper');if not ok then Pvp=nil end
local prediction_ok,Prediction=pcall(require,'common/modules/health_prediction');if not prediction_ok then Prediction=nil end
local N={Pvp=Pvp,scan_interval=0.3,scan_cache={time=-math.huge,rows={},known=false},health_pressure={}}
local MELEE_SPECS={[71]=true,[72]=true,[70]=true,[255]=true,[259]=true,[260]=true,[261]=true,[251]=true,[252]=true,[263]=true,[269]=true,[103]=true,[577]=true}
local BREAKABLE={6770,2094,1776,118,28271,28272,61305,61721,61780,126819,161354,161355,161372,51514,20066,8122,5782,3355,6358,33786,710,31661,105421}
local IMMUNE={642,45438,186265,33786,710}
local PRECOGNITION={377362,377360}
local function offensive_active(u)
 local f=Pvp and Pvp.has_offensive_cooldown_active
 if type(f)~='function'then return false end
 -- Project Sylvanas helpers have shipped as both colon-style module methods
 -- and plain functions. Accept a positive answer from either convention.
 if U.call(Pvp,'has_offensive_cooldown_active',u,500)==true then return true end
 return U.fn(f,u,500)==true
end
function N.precognition(u)
 local active,left
 for _,id in ipairs(PRECOGNITION)do
  local found,remaining=A.read(u,id)
  if found==true and(not active or remaining and(not left or remaining>left))then active,left=true,remaining end
 end
 return active==true,left
end
function N.protected(u)
 if A.any(u,BREAKABLE,true) or A.any(u,IMMUNE) or A.any(u,IMMUNE,true) then return true end
 local flags=Pvp and (Pvp.cc_flags or require('common/enums').cc_flags)
 local mask=0
 for _,key in ipairs({'INCAPACITATE','DISORIENT','FEAR','SAP','CYCLONE'})do mask=mask+(flags and flags[key] or 0)end
 return Pvp and (mask>0 and U.call(Pvp,'is_crowd_controlled',u,mask,0)==true
  or U.call(Pvp,'is_damage_immune',u,Pvp.damage_type_flags and Pvp.damage_type_flags.MAGICAL)==true) or false
end
function N.reduced(u)
 local magical=Pvp and Pvp.damage_type_flags and Pvp.damage_type_flags.MAGICAL
 local mult=Pvp and U.number(U.call(Pvp,'get_damage_reduction_mult',u,magical))
 if mult and mult>=0 and mult<=1 then return mult<=0.5 end
 local reduction=Pvp and U.number(U.call(Pvp,'get_damage_reduction_percentage',u,magical))
 if reduction and reduction>=0 and reduction<=1 then reduction=reduction*100 end
 return reduction and reduction>=50 or false
end
function N.engaged(p,u,mode,dummy_test)
 if dummy_test and U.enemy(p,u) and Dummy.is(u) then return true end
 -- Arena/BG opponents already fighting are valid cleave participants, including healers
 -- targeting their own allies. This never authorizes an idle player or a fresh PvE pull.
 if (mode=='arena' or mode=='battleground') and U.enemy(p,u)
  and (U.call(u,'is_player')==true or U.call(u,'is_pet')==true)
  and U.call(p,'is_in_combat')==true and U.call(u,'is_in_combat')==true then return true end
 local victim=U.call(u,'get_target')
 if U.same(victim,p) or U.call(victim,'is_party_member')==true or U.same(victim,U.call(p,'get_pet')) then return true end
 local threat=U.call(p,'get_threat_situation',u)
 if type(threat)=='table' and (threat.is_tanking==true or (U.number(threat.status) or 0)>0) then return true end
 -- Delve companions are friendly NPCs rather than party players.
 if mode=='delve' and U.valid(victim) and U.call(victim,'is_player')==false
  and U.call(p,'can_attack',victim)==false and U.call(u,'is_in_combat')==true then return true end
 -- Some live clients report `false` for an NPC target's combat flag even after
 -- the player has damaged it. A damaged current target while the player is in
 -- combat is direct engagement evidence and does not authorize a fresh pull.
 if U.same(U.call(p,'get_target'),u) and U.call(p,'is_in_combat')==true then
  local enemy_combat=U.call(u,'is_in_combat');local hp=U.hp(u)
  return enemy_combat==true or hp~=nil and hp<99.9
 end
 return false
end
function N.arena_setup(c)
 local healer_is_kill=c.arena_healer and U.same(c.arena_healer,c.target)or false
 local required_control
 if c.arena_healer and not healer_is_kill then required_control=c.healer_controlled
 else required_control=c.setup_controlled end
 if required_control then return true,c.arena_healer and not healer_is_kill and'healer'or'off_target'end
 if c.healer_trinket_down and c.target_hp and c.target_hp<=25 then return true,'execute'end
 return false,'none'
end
function N.cast(u,game_now)
 local channel=U.call(u,'is_channelling_spell')==true
 if not channel and U.call(u,'is_casting_spell')~=true then return nil end
 local id=U.number(U.call(u,channel and 'get_active_channel_spell_id' or 'get_active_spell_id'))
 local ending=U.number(U.call(u,channel and 'get_active_channel_cast_end_time' or 'get_active_spell_cast_end_time'))
 local start=U.number(U.call(u,channel and 'get_active_channel_cast_start_time' or 'get_active_spell_cast_start_time'))
 if not id or id<=0 or not ending or not start or ending<=start or not game_now then return nil end
 local left=(ending-game_now)/1000
 if left<=0 then return nil end
 return {unit=u,id=id,name=U.fn(core.spell_book.get_spell_name,id),start=start,ending=ending,left=left,
  progress=math.max(0,math.min(100,(game_now-start)/(ending-start)*100)),channel=channel,
  interruptible=U.call(u,'is_active_spell_interruptable')==true,target=U.call(u,'get_active_spell_target'),
  school=U.number(U.fn(core.spell_book.get_spell_school,id)),key=(U.guid(u) or '')..':'..id..':'..start}
end
local function unwrap(row) return type(row)=='table' and row.object or row end
function N.build(player,identity,mode,settings,engine)
 local now=U.number(U.fn(core.time)) or 0
 local c={player=player,identity=identity,spec=identity.id,mode=mode,pvp=require('sm_modes').pvp[mode]==true,
  settings=settings,now=now,game_now=U.number(U.fn(core.game_time)),enemies={},nearby={},casts={},
  enemy_count=1,attackers=0,melee_attackers=0,peel_target=nil,physical=false,magic=false,aoe_safe=true,aoe_known=false,party={},
  target=U.call(player,'get_target'),hp=U.hp(player)}
 c.level=U.number(U.call(player,'get_level'))or U.number(identity.level)or 0
 c.level_known=c.level>0
 c.level_band=not c.level_known and'unknown'or c.level>=60 and'endgame'or c.level>=58 and'58-59'or c.level>=56 and'56-57'or c.level>=48 and'48-55'or c.level>=40 and'40-47'or c.level>=38 and'38-39'or c.level>=34 and'34-37'or c.level>=30 and'30-33'or c.level>=28 and'28-29'or c.level>=26 and'26-27'or c.level>=24 and'24-25'or c.level>=22 and'22-23'or c.level>=20 and'20-21'or c.level>=18 and'18-19'or c.level>=16 and'16-17'or c.level>=14 and'14-15'or c.level>=12 and'12-13'or c.level>=10 and'10-11'or c.level>=8 and'8-9'or c.level>=6 and'6-7'or c.level>=4 and'4-5'or'1-3'
 c.precognition,c.precognition_left=N.precognition(player)
 local player_key=U.guid(player)or tostring(player)
 local pressure=N.health_pressure
 local prior=pressure.key==player_key and pressure.hp or nil
 local prior_time=pressure.key==player_key and pressure.time or nil
 local incoming=U.number(U.call(player,'get_incoming_damage',1.5))
 if not incoming and Prediction then incoming=U.number(U.call(Prediction,'get_incoming_damage',player,1.5)) end
 local dropped=prior and prior_time and now>=prior_time and now-prior_time<=1.5 and c.hp and prior-c.hp>=0.25
 if dropped or incoming and incoming>0 then pressure.until_time=now+2.25 end
 pressure.key,pressure.hp,pressure.time=player_key,c.hp,now
 c.recent_damage=now<(pressure.until_time or -math.huge)
 c.pressure_source=dropped and 'health_loss'or incoming and incoming>0 and 'incoming_damage'or c.recent_damage and 'recent_damage'or 'none'
 c.incoming_damage=incoming
 local enums=require('common/enums')
 c.mana=U.number(U.call(player,'get_power',enums.power_type.MANA))
 c.mana_max=U.number(U.call(player,'get_max_power',enums.power_type.MANA))
 if c.mana and c.mana_max then c.deficit=math.max(0,c.mana_max-c.mana) end
 c.training=settings.dummy_test==true and U.enemy(player,c.target) and Dummy.is(c.target)
 c.combat=U.call(player,'is_in_combat')==true or c.training or c.pvp and c.recent_damage
 c.busy=U.call(player,'is_casting_spell')==true or U.call(player,'is_channelling_spell')==true
 c.pet=U.call(player,'get_pet')
 c.moving=U.call(player,'is_moving')~=false
 c.mana_pct=c.mana and c.mana_max and c.mana_max>0 and c.mana/c.mana_max*100 or nil
 c.arcane_charges=U.number(U.call(player,'get_power',enums.power_type.ARCANECHARGES))
 c.player_cast=N.cast(player,c.game_now)
 local cache=N.scan_cache
 if now<(cache.time or -math.huge)or now-(cache.time or -math.huge)>=N.scan_interval then
  local original=U.fn(core.object_manager.get_all_objects);cache.time=now;cache.rows={};cache.known=type(original)=='table'
  for _,row in pairs(type(original)=='table'and original or{})do
   local u=unwrap(row)
   if U.enemy(player,u)and U.distance(player,u)<=80 then cache.rows[#cache.rows+1]=u end
  end
 end
 local rows={};for _,u in ipairs(cache.rows)do rows[#rows+1]=u end
 if U.valid(c.target)then rows[#rows+1]=c.target end
 c.aoe_known=cache.known
 local arena_specs={}
 if mode=='arena' then
  -- Arena frames are the authoritative hostile-player roster. The global
  -- object list also includes pets, guardians, mirrors and transient objects.
  rows={}
  local frames=U.fn(core.object_manager.get_arena_frames)
  if type(frames)=='table' then
   rows=type(rows)=='table' and rows or {}
   for i,row in pairs(frames) do
    local u=unwrap(row);rows[#rows+1]=u
    local key=U.guid(u);if key then arena_specs[key]=X.arena_spec(U.number(i) or i,u) end
   end
  else
   rows=type(rows)=='table' and rows or {}
   for i=1,3 do
    local u=U.fn(core.object_manager.get_arena_target,i)
    if U.valid(u) then rows[#rows+1]=u;arena_specs[U.guid(u)]=X.arena_spec(i,u) end
   end
  end
 end
 local seen={}
 for _,row in pairs(type(rows)=='table' and rows or {}) do
  local u=unwrap(row);local key=U.guid(u)
  if key and not seen[key] and U.enemy(player,u) and U.distance(player,u)<=80 then
   seen[key]=true
   local d=U.distance(player,u)
   local live_player=U.call(u,'is_player')==true
   local victim=U.call(u,'get_target')
   local pressure_engaged=c.pvp and c.recent_damage and live_player and d<=15 and not U.valid(victim)
   local engaged=N.engaged(player,u,mode,settings.dummy_test)or pressure_engaged
   local protected=N.protected(u)
   local enemy_spec=arena_specs[key]or U.number(U.call(u,'get_specialization_id'))
   local r={unit=u,guid=key,distance=d,engaged=engaged,protected=protected,hp=U.hp(u),spec=enemy_spec}
   r.healer=X.healer_spec(r.spec)
   if r.healer then c.arena_healer=u end
   c.enemies[#c.enemies+1]=r
   if U.distance(c.target,u)<=22 then
    c.nearby[#c.nearby+1]=r
    if U.distance(c.target,u)<=12 and (protected or not engaged) then c.aoe_safe=false end
   end
   r.victim=victim
   local focused=U.same(victim,player)or pressure_engaged
   r.pressuring=focused
   local helper_melee=Pvp and U.call(Pvp,'is_melee',u)==true
   local melee=MELEE_SPECS[enemy_spec]==true or helper_melee or not enemy_spec and d<=6 and U.call(u,'is_casting_spell')~=true
   r.melee=melee
   r.burst=offensive_active(u)
   if engaged and focused then
    c.attackers=c.attackers+1
    if d<=8 and U.call(u,'is_casting_spell')~=true then c.physical=true end
    if melee and d<=15 then
     c.melee_attackers=c.melee_attackers+1;r.peel_score=(r.burst and 30 or 0)+(15-d)
     if not c.peel_target or r.peel_score>(c.peel_target.peel_score or 0)then c.peel_target=r end
    end
   end
   if engaged and not protected then
    local cast=N.cast(u,c.game_now)
    if cast then
     cast.source_healer=r.healer==true
     cast.precognition=N.precognition(u)
     c.casts[#c.casts+1]=cast
     if U.same(cast.target,player) and cast.left<=2 then
      if cast.school==1 then c.physical=true elseif cast.school and cast.school>1 then c.magic=true end
      -- WoW spell-school masks: Fire=4 and Frost=16. Composite schools retain
      -- those bits, allowing wards to react without another object scan.
      if cast.school and math.floor(cast.school/4)%2==1 then c.fire_magic=true end
      if cast.school and math.floor(cast.school/16)%2==1 then c.frost_magic=true end
      if cast.school and cast.school>1 then c.reflect=cast end
     end
    end
   end
  end
 end
 local n=0
 for _,r in ipairs(c.nearby) do if U.distance(c.target,r.unit)<=10 and r.engaged and not r.protected then n=n+1 end end
 c.enemy_count=math.max(1,n)
 c.aoe_clear=c.aoe_safe and c.aoe_known
 c.aoe_safe=c.aoe_clear and settings.aoe
 for _,row in pairs(U.fn(core.object_manager.get_party_members) or {}) do
  local u=unwrap(row)
  if U.valid(u) and not U.same(u,player) then
   local role=type(row)=='table' and row.role or U.call(u,'get_group_role')
   c.party[#c.party+1]={unit=u,hp=U.hp(u),role=role}
   local healer_enum=enums.group_role and enums.group_role.HEALER
   if role=='HEALER'or role==healer_enum or tostring(role):upper():find('HEAL',1,true)then c.party_healer=u end
  end
 end
 if c.pvp then
  for _,r in ipairs(c.enemies)do if r.engaged and r.melee and not r.protected then
   for _,ally in ipairs(c.party)do
    if U.same(r.victim,ally.unit)and ((ally.hp or 100)<=65 or r.burst and (ally.hp or 100)<=85) and U.distance(r.unit,ally.unit)<=10 then
     local role=tostring(ally.role or''):upper();local score=(100-(ally.hp or 100))+(role:find('HEAL',1,true)and 25 or 0)+(r.burst and 30 or 0)
     if not c.ally_peel_target or score>(c.ally_peel_score or 0)then
      c.ally_peel_target=r;c.ally_peel_ally=ally.unit;c.ally_peel_hp=ally.hp;c.ally_peel_score=score
     end
    end
   end
  end end
  for _,r in ipairs(c.enemies)do if r.engaged and not r.protected and not r.healer and not U.same(r.unit,c.target)then
   for _,ally in ipairs(c.party)do
    if U.same(r.victim,ally.unit)and ((ally.hp or 100)<=45 or r.burst and (ally.hp or 100)<=65) then
     local role=tostring(ally.role or''):upper();local score=(100-(ally.hp or 100))+(role:find('HEAL',1,true)and 25 or 0)+(r.burst and 30 or 0)
     if not c.defensive_poly_target or score>(c.defensive_poly_score or 0)then
      c.defensive_poly_target=r;c.defensive_poly_ally=ally.unit;c.defensive_poly_hp=ally.hp;c.defensive_poly_score=score
     end
    end
   end
  end end
 end
 for _,cast in ipairs(c.casts) do X.classify_cast(cast,player,c.party,c.pvp,c.hp) end
 table.sort(c.casts,function(a,b)
  if (a.priority or 0)~=(b.priority or 0) then return (a.priority or 0)>(b.priority or 0) end
  return a.left<b.left
 end)
 c.solo=#c.party==0
 if settings.timer_defensives and not c.pvp then c.upcoming=T.next() end
 c.target_valid=U.enemy(player,c.target) and not N.protected(c.target)
 if c.target_valid then
  c.target_hp=U.hp(c.target);c.target_guid=U.guid(c.target)
  c.distance=U.distance(player,c.target)
  c.target_engaged=N.engaged(player,c.target,mode,settings.dummy_test)
  local is_player=U.call(c.target,'is_player')==true
  if (mode=='arena' or mode=='battleground') and not c.training and not is_player and U.call(c.target,'is_pet')~=true then c.target_valid=false end
  if mode=='world_pvp' and not is_player or mode=='world_pve' and is_player then c.target_valid=false end
  c.reduced=N.reduced(c.target)
 end
 c.buff=function(id) if S.aura_allowed(id,c.spec)then return A.read(player,id)end end
 c.stacks=function(id,debuff)if not S.aura_allowed(id,c.spec)then return 0 end;local active,_,n=A.read(debuff and c.target or player,id,debuff,debuff and player or nil);return active==true and (n or 1) or 0 end
 c.debuff=function(id) if S.aura_allowed(id,c.spec)then return A.read(c.target,id,true,player)end end
 c.row_debuff=function(key)
  local row=S.rows[key];if not row or not S.allowed(key,c.spec)then return false end
  local best=false
  for _,id in ipairs(row.ranks or{row.id})do local active,left=A.read(c.target,id,true,player);if active==true and(left==nil or best==false or left>best)then best=left or math.huge end end
  return best
 end
 c.target_frozen=c.target_valid and S.freeze_auras and A.any(c.target,S.freeze_auras,true)or false
 c.known=function(key)
  local row=S.rows[key]
  return row and S.allowed(key,c.spec) and engine:learned(row,row.id,c.spec) or false
 end
 c.enemy_interrupt_ready=function(u)
  local record=engine.enemy_interrupts and engine.enemy_interrupts[U.guid(u)or'?']
  if record and record.ready and record.ready>c.now then return false,record.ready-c.now,record.spell end
  return nil
 end
 c.talent=function(key) return S.talent_allowed(key,c.spec) and S.talent[key] and U.fn(core.spell_book.is_spell_known,S.talent[key])==true or false end
 c.ready=function(key,target) return engine:ready(c,key,target) end
 c.pick=function(key,why,target)
  if not c.ready(key,target) then return nil end
  return {key=key,why=why,target=target,scope=engine.scope,epoch=engine.epoch}
 end
 c.execute=c.target_hp and c.target_hp<=30 or false
 c.charges=function(k)local r=S.rows[k];return r and S.allowed(k,c.spec) and U.number(U.fn(core.spell_book.get_spell_charge,engine:resolve(r))) or 0 end
 c.cd=function(k)local r=S.rows[k];return r and S.allowed(k,c.spec) and U.number(U.fn(core.spell_book.get_spell_cooldown,engine:resolve(r))) or math.huge end
 c.fractional=function(k)
  local r=S.rows[k];if not r or not S.allowed(k,c.spec)then return 0 end
  local id=engine:resolve(r);local current=U.number(U.fn(core.spell_book.get_spell_charge,id)) or 0
  local maximum=U.number(U.fn(core.spell_book.get_spell_charge_max,id))
  if not maximum or maximum<=0 or current>=maximum then return current end
  local started=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_start_time,id))
  local duration=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_duration,id))
  if not started or started<=0 or not duration or duration<=0 then return current end
  -- Duration is documented in seconds. Older surfaces have exposed the start in ms.
  if started>c.now*10 then started=started/1000 end
  local progress=math.max(0,math.min(0.999,(c.now-started)/duration))
  return math.min(maximum,current+progress)
 end
 c.cost=function(k)
  local r=S.rows[k];if not r or not S.allowed(k,c.spec)then return end;local costs=r and U.fn(core.spell_book.get_spell_costs,engine:resolve(r))
  for _,cost in pairs(type(costs)=='table' and costs or {})do
   if cost.cost_type==enums.power_type.MANA and (not cost.required_buff_id or cost.required_buff_id==0 or c.buff(cost.required_buff_id)==true)then
    return U.number(cost.cost) or U.number(cost.min_cost)
   end
  end
 end
 c.predicted_hp=engine:predict(c)
 local incoming=c.incoming_damage
 local maximum=select(2,U.hp(player))
 if incoming and incoming>0 and maximum and c.hp then
  c.predicted_hp=math.min(c.predicted_hp or c.hp,math.max(0,c.hp-incoming/maximum*100))
 end
 c.enemy_burst=false
 c.temporal_space=true
 for _,r in ipairs(c.enemies)do
  if r.engaged and r.pressuring and (r.distance or math.huge)<20 then c.temporal_space=false end
  if r.engaged and (r.pressuring or U.same(U.call(r.unit,'get_target'),player)) and r.burst then c.enemy_burst=true end
 end
 local automatic=settings.automatic_burst
 if mode=='arena' and automatic then
  local healer_key=c.arena_healer and U.guid(c.arena_healer)
  local trinket=healer_key and engine.pvp_trinket and engine.pvp_trinket[healer_key]
  c.healer_trinket_remaining=trinket and math.max(0,120-(c.now-trinket))or 0
  c.healer_trinket_down=c.healer_trinket_remaining>0
  local flags=Pvp and (Pvp.cc_flags or enums.cc_flags)
  local mask=0
  for _,key in ipairs({'INCAPACITATE','DISORIENT','FEAR','SAP','CYCLONE','STUN','SILENCE'})do mask=mask+(flags and flags[key] or 0)end
  -- Automatic cooldowns need enough confirmed setup time to begin the
  -- spec's actual damage sequence. Fire can commit with instant Combustion
  -- and Hot Streak; Arcane and Frost need a longer protected cast/channel.
  local setup_ms=c.spec==63 and 1200 or 2500
  c.setup_window_ms=setup_ms
  local healer_is_kill=c.arena_healer and U.same(c.arena_healer,c.target)or false
  c.healer_controlled=c.arena_healer and not healer_is_kill and mask>0
   and U.call(Pvp,'is_crowd_controlled',c.arena_healer,mask,setup_ms)==true or false
  c.setup_controlled=false
  -- When a known healer is off-target, arena_setup can only use that healer's
  -- control state. Scan other opponents only when an off-target setup is the
  -- actual fallback (healer is the kill target or no healer was identified).
  if not c.arena_healer or healer_is_kill then
   for _,r in ipairs(c.enemies)do if not U.same(r.unit,c.target)and mask>0
    and U.call(Pvp,'is_crowd_controlled',r.unit,mask,setup_ms)==true then c.setup_controlled=true;break end end
  end
  -- Arena cooldowns follow a real CC setup. A tracked healer trinket creates
  -- opportunity but does not by itself justify spending every major cooldown.
   automatic,c.setup_source=N.arena_setup(c)
 end
 c.burst=settings.cooldowns and (not c.pvp or automatic or engine.burst_requested)
  and not c.reduced and c.target_valid and c.target_engaged and c.distance and c.distance<=45
 local ttd=engine:target_life(c)
 local min_ttd=settings.cooldown_min_ttd or 5
 if ttd and ttd<min_ttd then c.burst=false end
 if mode=='mythic_plus' and c.enemy_count<(settings.cooldown_min_enemies or 3)
  and U.call(c.target,'is_boss')~=true and (not ttd or ttd<min_ttd*2) then c.burst=false end
 c.ttd=ttd
 if c.peel_target and Pvp then
  local flags=Pvp.cc_flags or enums.cc_flags
  local category=c.spec==63 and flags and flags.DISORIENT or flags and flags.ROOT
  c.peel_dr=category and U.number(U.call(Pvp,'get_unit_dr',c.peel_target.unit,category,0))or nil
  c.peel_immune=category and U.call(Pvp,'is_cc_immune',c.peel_target.unit,category,100)or nil
  c.peel_controlled=category and U.call(Pvp,'is_crowd_controlled',c.peel_target.unit,category,500)or nil
  c.peel_stage=c.spec==62 and (c.peel_target.distance<=8 and 'arcane_control_then_blink'or'slow_and_range')
   or c.spec==63 and (c.peel_target.distance<=8 and 'fire_disorient_then_blink'or'close_gap_monitor')
   or c.spec==64 and (c.peel_target.distance<=8 and 'frost_roots_then_blink'or'root_and_range')
 end
 if c.ally_peel_target then
  c.ally_peel_stage=c.spec==62 and 'arcane_slow_ally_attacker'
   or c.spec==63 and (c.ally_peel_target.distance<=12 and 'fire_disorient_ally_attacker'or'fire_reposition_for_peel')
   or c.spec==64 and 'frost_root_ally_attacker'
 end
 return c
end
return N
