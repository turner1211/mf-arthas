local U,A,S,X,T=require('ww_util'),require('ww_aura'),require('ww_spells'),require('ww_intel'),require('ww_timers')
local ok,Pvp=pcall(require,'common/utility/pvp_helper');if not ok then Pvp=nil end
local dummy_ok,UnitHelper=pcall(require,'common/utility/unit_helper');if not dummy_ok then UnitHelper=nil end
local prediction_ok,Prediction=pcall(require,'common/modules/health_prediction');if not prediction_ok then Prediction=nil end
local N={Pvp=Pvp}
local object_cache,object_cache_at,object_cache_player,object_cache_known={},-math.huge,nil,false
local BREAKABLE={6770,2094,1776,118,28271,28272,61305,61721,61780,126819,161354,161355,161372,51514,20066,8122,5782,3355,6358,33786,710,31661,105421}
local IMMUNE={642,45438,186265,33786,710,1022,414658}
-- Stable legacy capital-city dummy entries supplement Project Sylvanas'
-- native UnitHelper detector. Modern hubs are normally covered by UnitHelper
-- and the name fallback, so this list does not need a city or map allowlist.
local DUMMY_IDS={
 [1921]=true,[4952]=true,[18504]=true,[25225]=true,[25297]=true,
 [30527]=true,[31144]=true,[31146]=true,[32541]=true,[32542]=true,
 [32545]=true,[32546]=true,[32667]=true,[33229]=true,[42328]=true,
 [44171]=true,[48304]=true,[60197]=true,[64446]=true,[92164]=true
}
function N.protected(u)
 if A.any(u,BREAKABLE,true) or A.any(u,IMMUNE) or A.any(u,IMMUNE,true) then return true end
 return Pvp and (U.call(Pvp,'is_crowd_controlled_weak',u,0)==true or U.call(Pvp,'is_damage_immune',u)==true) or false
end
function N.controlled(u)
 return A.any(u,BREAKABLE,true)or Pvp and U.call(Pvp,'is_crowd_controlled_weak',u,0)==true or false
end
function N.immune(u)
 return A.any(u,IMMUNE)or A.any(u,IMMUNE,true)or Pvp and U.call(Pvp,'is_damage_immune',u)==true or false
end
function N.dummy(u)
 if not U.valid(u) or U.call(u,'is_player')==true then return false end
 if UnitHelper and U.call(UnitHelper,'is_dummy',u)==true then return true end
 local id=U.number(U.call(u,'get_npc_id'))or U.number(U.call(u,'get_entry_id'))
 if not id then
  local guid=U.guid(u)
  -- Retail creature GUID: Creature-0-server-instance-zone-id-spawn.
  id=guid and U.number(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))or nil
 end
 if id and DUMMY_IDS[id]then return true end
 local name=U.call(u,'get_name')
 if type(name)~='string'then return false end
 name=name:lower()
 return name:find('dummy',1,true)~=nil
  or name:find('practice target',1,true)~=nil
  or name:find('combat target',1,true)~=nil
end
function N.engaged(p,u,mode,allow_dummy)
 if allow_dummy and mode=='world_pve'and N.dummy(u)and U.enemy(p,u)then return true end
 local victim=U.call(u,'get_target')
 if U.same(victim,p) or U.call(victim,'is_party_member')==true then return true end
 local threat=U.call(p,'get_threat_situation',u)
 if type(threat)=='table' and (threat.is_tanking==true or (U.number(threat.status) or 0)>0) then return true end
 -- Delve companions are friendly NPCs rather than party players.
 if mode=='delve' and U.valid(victim) and U.call(victim,'is_player')==false
  and U.call(p,'can_attack',victim)==false and U.call(u,'is_in_combat')==true then return true end
 return U.same(U.call(p,'get_target'),u) and U.call(p,'is_auto_attacking')==true
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
 return {unit=u,id=id,start=start,ending=ending,left=left,
  progress=math.max(0,math.min(100,(game_now-start)/(ending-start)*100)),channel=channel,
  interruptible=U.call(u,'is_active_spell_interruptable')==true,target=U.call(u,'get_active_spell_target'),
  school=U.number(U.fn(core.spell_book.get_spell_school,id)),key=(U.guid(u) or '')..':'..id..':'..start}
end
local function unwrap(row) return type(row)=='table' and row.object or row end
local function object_rows(player,now)
 -- Object enumeration is one of the loader's most expensive calls. Unit
 -- objects remain live, so cache only the container and continue reading all
 -- combat/cast/health fields on every decision tick.
 if object_cache_player~=player or now<object_cache_at or now-object_cache_at>=.25 then
  local point=U.call(player,'get_position')
  local rows=UnitHelper and point and U.call(UnitHelper,'get_enemy_list_around',point,45,true,false)or nil
  -- Current Project Sylvanas builds provide a cached, filtered unit helper.
  -- Keep raw enumeration for older builds and unusual helper failures.
  if type(rows)~='table'then rows=U.fn(core.object_manager.get_all_objects)end
  object_cache_known=type(rows)=='table'
  object_cache=object_cache_known and rows or{}
  object_cache_at=now;object_cache_player=player
 end
 return object_cache,object_cache_known
end
function N.invalidate_object_cache()
 object_cache={};object_cache_at=-math.huge;object_cache_player=nil;object_cache_known=false
end
function N.build(player,identity,mode,settings,engine)
 local now=U.number(U.fn(core.time)) or 0
 local c={player=player,identity=identity,spec=identity.id,mode=mode,pvp=require('ww_modes').pvp[mode]==true,
  settings=settings,now=now,game_now=U.number(U.fn(core.game_time)),enemies={},nearby={},casts={},
  enemy_count=1,attackers=0,burst_attackers=0,team_burst_attackers=0,physical=false,magic=false,aoe_safe=true,aoe_known=false,party={},
  target=U.call(player,'get_target'),hp=U.hp(player)}
 c.training=engine.dummy_allowed~=false and mode=='world_pve'and N.dummy(c.target)and U.enemy(player,c.target)
 local enums=require('common/enums')
 c.rage=U.number(U.call(player,'get_power',enums.power_type.RAGE))
 c.rage_max=U.number(U.call(player,'get_max_power',enums.power_type.RAGE))
 if c.rage and c.rage_max then c.deficit=math.max(0,c.rage_max-c.rage) end
 c.combat=U.call(player,'is_in_combat')==true
 if mode=='arena'then
  if c.combat and not engine.arena_was_in_combat then engine.arena_started_at=nil end
  if not c.combat then engine.arena_started_at=nil end
  engine.arena_was_in_combat=c.combat
 end
 local loss=U.call(player,'get_loss_of_control_info')
 if type(loss)=='table' then
  local rows=loss.valid~=nil and {loss} or loss
  for _,row in pairs(rows) do
   if type(row)=='table' and row.valid==true then
    local flags=enums.loss_of_control_type or{}
    if row.type==flags.ROOT then c.rooted=true end
    if row.type==flags.SNARE then c.slowed=true end
    if row.type==flags.FEAR or row.type==flags.FEAR_MECHANIC or row.type==flags.CHARM then c.feared=true end
   end
  end
 end
 c.rooted=c.rooted==true;c.slowed=c.slowed==true;c.feared=c.feared==true
 c.busy=U.call(player,'is_casting_spell')==true or U.call(player,'is_channelling_spell')==true
 local channel_id=U.number(U.call(player,'get_active_channel_spell_id'))
 c.defense_during_channel=channel_id==436358 or channel_id==227847 or channel_id==446035
  or A.any(player,{227847,446035})
 local rows,known=object_rows(player,now)
 c.aoe_known=known
 local arena_specs={}
 if mode=='arena' then
  -- Arena frames may not be present in the general object list. Copy the
  -- cached container before adding them so the cache itself never grows.
  local combined={};for _,row in pairs(rows)do combined[#combined+1]=row end;rows=combined
  local frames=U.fn(core.object_manager.get_arena_frames)
  if type(frames)=='table' then
   for i,row in pairs(frames) do
    local u=unwrap(row);rows[#rows+1]=u
    local key=U.guid(u);if key then arena_specs[key]=X.arena_spec(U.number(i) or i,u) end
   end
  else
   for i=1,3 do
    local u=U.fn(core.object_manager.get_arena_target,i)
    if U.valid(u) then rows[#rows+1]=u;arena_specs[U.guid(u)]=X.arena_spec(i,u) end
   end
  end
 end
 local seen={}
 for _,row in pairs(type(rows)=='table' and rows or {}) do
  local u=unwrap(row);local key=U.guid(u)
  if key and not seen[key] and U.enemy(player,u) and U.distance(player,u)<=45 then
   seen[key]=true
   local engaged=N.engaged(player,u,mode,c.training)
   local protected=N.protected(u)
   local d=U.distance(player,u)
   local r={unit=u,guid=key,distance=d,engaged=engaged,protected=protected,hp=U.hp(u),
    spec=arena_specs[key]or(c.pvp and U.number(U.call(u,'get_specialization_id')))}
   r.healer=X.healer_spec(r.spec)
   if r.healer then c.enemy_healer=u;if mode=='arena'then c.arena_healer=u end end
   c.enemies[#c.enemies+1]=r
   if d<=12 then
    c.nearby[#c.nearby+1]=r
    if protected or not engaged then c.aoe_safe=false end
   end
   local victim=U.call(u,'get_target')
   r.burst=Pvp and U.call(Pvp,'has_burst_active',u,300)==true or false
   if engaged and not protected and r.burst and U.same(victim,player) then c.burst_attackers=c.burst_attackers+1 end
   -- Morale Killer turns Demoralizing Shout into team mitigation. Keep this
   -- distinct from personal burst so ally pressure never spends Shield Wall.
   if engaged and not protected and r.burst and d<=10
    and not U.same(victim,player) and U.call(victim,'is_party_member')==true then
    c.team_burst_attackers=c.team_burst_attackers+1
   end
   if engaged and U.same(victim,player) then
    c.attackers=c.attackers+1
    if d<=8 and U.call(u,'is_casting_spell')~=true then c.physical=true end
   end
   if engaged and not protected then
    local cast=N.cast(u,c.game_now)
    if cast then
     c.casts[#c.casts+1]=cast
     if U.same(cast.target,player) and cast.left<=2 then
      if cast.school==1 then c.physical=true elseif cast.school and cast.school>1 then c.magic=true end
      if cast.school and cast.school>1 then c.reflect=cast end
     end
    end
   end
  end
 end
 local n=0
 if identity.id==73 and not c.pvp and not identity.role_conflict and engine.taunt_follow then
  local follow=engine.taunt_follow
  if now>=follow.expires then engine.taunt_follow=nil
  else
   for _,r in ipairs(c.enemies) do
    if r.guid==follow.guid and r.engaged and not r.protected then
     local threat=U.call(player,'get_threat_situation',r.unit)
     local stable=type(threat)=='table' and threat.is_tanking==true and (U.number(threat.status) or 0)>=3
     if stable and now>=follow.minimum then engine.taunt_follow=nil
     else c.target=r.unit;c.recovery_target=true end
     break
    end
   end
  end
 end
 for _,r in ipairs(c.nearby) do if r.distance<=8 and r.engaged and not r.protected then n=n+1 end end
 c.enemy_count=math.max(1,n)
 c.aoe_safe=c.aoe_safe and c.aoe_known and settings.aoe
 for _,row in pairs(U.fn(core.object_manager.get_party_members) or {}) do
  local u=unwrap(row)
  if U.valid(u) and not U.same(u,player) then
   c.party[#c.party+1]={unit=u,hp=U.hp(u),role=type(row)=='table' and row.role or U.call(u,'get_group_role')}
  end
 end
 for _,cast in ipairs(c.casts) do X.classify_cast(cast,player,c.party) end
 table.sort(c.casts,function(a,b)
  if (a.priority or 0)~=(b.priority or 0) then return (a.priority or 0)>(b.priority or 0) end
  return a.left<b.left
 end)
 c.solo=#c.party==0
 local timed_mode=mode=='delve'or mode=='dungeon'or mode=='mythic_plus'or mode=='raid'
 if settings.timer_defensives and timed_mode then c.upcoming=T.next() end
 c.target_valid=U.enemy(player,c.target) and not N.protected(c.target)
 if c.target_valid then
  c.target_hp=U.hp(c.target);c.target_guid=U.guid(c.target)
  c.distance=U.distance(player,c.target)
  c.target_engaged=N.engaged(player,c.target,mode,c.training)
  local is_player=U.call(c.target,'is_player')==true
  if mode=='world_pvp' and not is_player or mode=='world_pve' and is_player then c.target_valid=false end
  c.reduced=Pvp and U.call(Pvp,'has_damage_reduction',c.target,50)==true or false
 end
 c.buff=function(id) return A.read(player,id) end
 c.debuff=function(id) return A.read(c.target,id,true,player) end
 c.known=function(key)
  local row=S.rows[key]
  return row and S.allowed(key,c.spec) and U.fn(core.spell_book.is_spell_known,engine:resolve(row))==true or false
 end
 c.talent=function(key)
  local ids=S.talent[key];if type(ids)=='number'then ids={ids}end
  for _,id in ipairs(ids or{})do if U.fn(core.spell_book.is_spell_known,id)==true then return true end end
  return false
 end
 c.charges=function(key)
  local row=S.rows[key];if not row or not S.allowed(key,c.spec)then return nil,nil end
  local id=engine:resolve(row)
  return U.number(U.fn(core.spell_book.get_spell_charge,id)),U.number(U.fn(core.spell_book.get_spell_charge_max,id))
 end
 c.cooldown=function(key)
  local row=S.rows[key];if not row or not S.allowed(key,c.spec)then return nil end
  return U.number(U.fn(core.spell_book.get_spell_cooldown,engine:resolve(row)))
 end
 c.ready=function(key,target) return engine:ready(c,key,target) end
 c.pick=function(key,why,target)
  if not c.ready(key,target) then return nil end
  local row=S.rows[key]
  return {key=key,why=why,target=target,default_target=target==nil and row and(row.kind=='enemy'or row.kind=='ground'),
   target_guid=U.guid(target or c.target),scope=engine.scope,epoch=engine.epoch}
 end
 c.execute=c.target_hp and c.target_hp<=20 or c.buff(S.aura.sudden_death)==true
 local massacre=c.spec==72 and 'fury_massacre' or c.spec==71 and 'arms_massacre' or 'prot_massacre'
 if c.talent(massacre) and c.target_hp and c.target_hp<=35 then c.execute=true end
 c.enrage,c.enrage_left=c.buff(S.aura.enrage)
 c.smash,c.smash_left=c.debuff(S.aura.smash)
 c.avatar=c.buff(S.aura.avatar);c.recklessness=c.buff(S.aura.recklessness)
 c.colossal,c.colossal_left,c.colossal_stacks=c.buff(S.aura.colossal_might)
 c.thunder,c.thunder_left,c.thunder_stacks=c.buff(S.aura.thunder_blast)
 c.phalanx,c.phalanx_left,c.phalanx_stacks=c.buff(S.aura.phalanx)
 c.whirlwind,c.whirlwind_left,c.whirlwind_stacks=c.buff(S.aura.whirlwind)
 c.sudden,c.sudden_left,c.sudden_stacks=c.buff(S.aura.sudden_death)
 c.precision,c.precision_left,c.precision_stacks=c.buff(S.aura.precision)
 c.predicted_hp=engine:predict(c)
 local incoming=U.number(U.call(player,'get_incoming_damage',1.5))
 if not incoming and Prediction then incoming=U.number(U.call(Prediction,'get_incoming_damage',player,1.5)) end
 local maximum=select(2,U.hp(player))
 if incoming and incoming>0 and maximum and c.hp then
  c.predicted_hp=math.min(c.predicted_hp or c.hp,math.max(0,c.hp-incoming/maximum*100))
 end
 if mode=='arena'then
  if not engine.arena_started_at and c.combat and c.target_valid and c.target_engaged
   and c.distance and c.distance<=8 then engine.arena_started_at=c.now end
  c.arena_opener=engine.arena_started_at~=nil and c.now-engine.arena_started_at<=8
 end
 local automatic=settings.automatic_burst
 if mode=='arena' and automatic then
  local healer_key=c.arena_healer and U.guid(c.arena_healer)
  local trinket=healer_key and engine.pvp_trinket and engine.pvp_trinket[healer_key]
  local window=settings.pvp_trinket_window or 120
  local native=c.arena_healer and Pvp and U.call(Pvp,'trinket_used_within',c.arena_healer,window)==true
  c.healer_trinket_down=native or trinket and c.now-trinket<window or false
  automatic=c.arena_opener or(c.target_hp and c.target_hp<=70)or(c.arena_healer and N.controlled(c.arena_healer))or c.healer_trinket_down
  -- Do not mistake immunity for crowd control. An explicit manual request may
  -- still override this hold, but automatic cooldowns wait for immunity to end.
  if c.arena_healer and N.immune(c.arena_healer)then automatic=false end
 end
 local pvp_allowed=not c.pvp or engine.pvp_burst_allowed~=false
 -- Keep every safety predicate inside the same conjunction. Lua evaluates
 -- `and` before `or`; placing `or false` before these checks previously made
 -- the remaining target gates unreachable and reported burst with no target.
 c.burst=(settings.cooldowns==true and pvp_allowed
  and(not c.pvp or automatic==true or engine.burst_requested==true)
  and not c.reduced and c.target_valid and c.target_engaged
  and c.distance and c.distance<=8)or false
 local ttd=engine:target_life(c)
 local min_ttd=settings.cooldown_min_ttd or 5
 if ttd and ttd<min_ttd then c.burst=false end
 if mode=='mythic_plus' and c.enemy_count<(settings.cooldown_min_enemies or 3)
  and U.call(c.target,'is_boss')~=true and (not ttd or ttd<min_ttd*2) then c.burst=false end
 c.ttd=ttd
 return c
end
return N
