local U,A,S,X,T=require('hh_util'),require('hh_aura'),require('hh_spells'),require('hh_intel'),require('hh_timers')
local ok,Pvp=pcall(require,'common/utility/pvp_helper');if not ok then Pvp=nil end
local helper_ok,UnitHelper=pcall(require,'common/utility/unit_helper');if not helper_ok then UnitHelper=nil end
local prediction_ok,Prediction=pcall(require,'common/modules/health_prediction');if not prediction_ok then Prediction=nil end
local N={Pvp=Pvp}
local BREAKABLE={6770,2094,1776,118,28271,28272,61305,61721,61780,126819,161354,161355,161372,51514,20066,8122,5782,3355,6358,33786,710,31661,105421,213691}
local IMMUNE={642,45438,186265,33786,710,1022,414658}
local SETUP_STUN={[19577]=true,[474421]=true}
local HARMLESS_FOR_TRAP={[257284]=true,[5116]=true,[195645]=true}
-- Compatibility fallbacks for old capital-city dummies. Current cores should
-- normally identify every dummy through unit:is_dummy() or unit_helper:is_dummy().
local DUMMY_NPCS={[30527]=true,[31144]=true,[31146]=true,[46647]=true,[114832]=true}
local NAMED_DUMMIES={kelpfist=true,crystalmaw=true}
local function control_remaining(unit)
 local longest
 for _,id in ipairs(BREAKABLE) do
  local active,left=A.read(unit,id,true)
  if active==true and left and left>0 then longest=math.max(longest or 0,left) end
 end
 for id in pairs(SETUP_STUN) do
  local active,left=A.read(unit,id,true)
  if active==true and left and left>0 then longest=math.max(longest or 0,left) end
 end
 return longest
end
function N.protected(u)
 if A.any(u,BREAKABLE,true) or A.any(u,IMMUNE) or A.any(u,IMMUNE,true) then return true end
 return Pvp and (U.call(Pvp,'is_crowd_controlled_weak',u,0)==true or U.call(Pvp,'is_damage_immune',u)==true) or false
end
local function trap_base(c,healer)
 if c.mode~='arena' or not (c.kill_intent or c.burst) or not healer or not U.same(healer,c.arena_healer)
  or U.same(healer,c.target) or not Pvp then return false end
 for _,ally in ipairs(c.party) do if U.same(U.call(ally.unit,'get_target'),healer) then return false end end
 if U.same(c.pet and U.call(c.pet,'get_target'),healer) then return false end
 return true
end
local function clean_for_trap(c,healer,allow_setup)
 local dots=U.call(healer,'get_debuffs');if type(dots)~='table' then return false,'debuffs_unknown' end
 for _,row in pairs(dots) do
  local id=U.number(row.buff_id)
  if not HARMLESS_FOR_TRAP[id]
   and not (allow_setup and SETUP_STUN[id] and U.same(row.caster,c.player)) then return false,'debuff_'..tostring(id or '?') end
 end
 return true
end
function N.trap_safe(c,healer)
 c.trap_block=nil
 if not trap_base(c,healer) then c.trap_block='base';return false end
 local setup_stunned=A.read(healer,19577,true,c.player)==true or A.read(healer,474421,true,c.player)==true
 if A.any(healer,BREAKABLE,true) or A.any(healer,IMMUNE) or A.any(healer,IMMUNE,true)
  or U.call(Pvp,'is_damage_immune',healer)==true
  or U.call(Pvp,'is_crowd_controlled_weak',healer,0)==true and not setup_stunned then c.trap_block='protected';return false end
 local flags=require('common/enums').cc_flags;local flag=flags and flags.INCAPACITATE
 local dr=flag and U.number(U.call(Pvp,'get_unit_dr',healer,flag,0.75))
 if not dr or dr<0.5 then c.trap_block='incap_dr';return false end
 if U.call(Pvp,'is_cc_immune',healer,flag,0,false)~=false then c.trap_block='incap_immune';return false end
 -- A confirmed setup stun fixes the healer in place even if the native movement
 -- flag retains pre-stun momentum for a frame. Unstunned direct traps still
 -- require a positively stationary target.
 if not setup_stunned and U.call(healer,'is_moving')~=false then c.trap_block='moving';return false end
 local clean,reason=clean_for_trap(c,healer,true);if not clean then c.trap_block=reason;return false end
 return true
end
function N.trap_setup_safe(c,healer)
 if not trap_base(c,healer) or N.protected(healer) or not clean_for_trap(c,healer,false) then return false end
 local flags=require('common/enums').cc_flags
 local incap,stun=flags and flags.INCAPACITATE,flags and flags.STUN
 local incap_dr=incap and U.number(U.call(Pvp,'get_unit_dr',healer,incap,0.75))
 local stun_dr=stun and U.number(U.call(Pvp,'get_unit_dr',healer,stun,0.75))
 return incap_dr and incap_dr>=0.5 and stun_dr and stun_dr>=0.5
  and U.call(Pvp,'is_cc_immune',healer,incap,0,false)==false
  and U.call(Pvp,'is_cc_immune',healer,stun,0,false)==false
end
function N.scatter_safe(c,u)
 if c.mode~='arena' or not c.settings.arena_scatter or not c.settings.cc or not Pvp
  or not U.valid(u) or U.same(u,c.target) or U.same(u,c.arena_healer) or N.protected(u) then return false end
 -- Scatter breaks on damage. Reserve it for an off-target nobody on our team or
 -- pet is attacking, and never spend the incapacitate DR of the healer Trap.
 for _,ally in ipairs(c.party or {}) do if U.same(U.call(ally.unit,'get_target'),u) then return false end end
 if U.same(c.pet and U.call(c.pet,'get_target'),u) then return false end
 local flags=require('common/enums').cc_flags;local incap=flags and flags.INCAPACITATE
 local dr=incap and U.number(U.call(Pvp,'get_unit_dr',u,incap,0.75))
 return dr and dr>=0.5 and U.call(Pvp,'is_cc_immune',u,incap,0,false)==false
end
function N.ally(c,u)
 for _,row in ipairs(c.party or {}) do if U.same(row.unit,u) then return true end end
 return false
end
function N.dummy(u)
 if not U.valid(u) or U.call(u,'is_player')==true then return false,'invalid' end
 if U.call(u,'is_dummy')==true then return true,'unit' end
 if UnitHelper and U.call(UnitHelper,'is_dummy',u)==true then return true,'helper' end
 local npc=U.number(U.call(u,'get_npc_id'))or U.number(U.call(u,'npc_id'))
 if not npc then
  local guid=U.guid(u);npc=guid and U.number(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
 end
 if npc and DUMMY_NPCS[npc]then return true,'npc_'..npc end
 local name=tostring(U.call(u,'get_name') or ''):lower()
 if name:find('training dummy',1,true) or name:find('target dummy',1,true)
  or name:find('combat dummy',1,true) or name:find('damage dummy',1,true)
  or name:find('tanking dummy',1,true) or name:find('healing dummy',1,true)
  or name:find('training bag',1,true) or NAMED_DUMMIES[name] then return true,'name' end
 return false,'none'
end
function N.engaged(p,u,mode,party)
 -- City dummies intentionally have no normal threat/target relationship.
 if mode=='world_pve' and N.dummy(u) then return true end
 -- Arena/BG opponents already fighting are valid cleave participants, including healers
 -- targeting their own allies. This never authorizes an idle player or a fresh PvE pull.
 if (mode=='arena' or mode=='battleground') and U.enemy(p,u)
  and (U.pvp_unit(u) or U.call(u,'is_pet')==true)
  and U.call(p,'is_in_combat')==true and U.call(u,'is_in_combat')==true then return true end
 local victim=U.call(u,'get_target')
 if U.same(victim,p) or U.call(victim,'is_party_member')==true or U.same(victim,U.call(p,'get_pet')) then return true end
 for _,row in ipairs(party or {}) do if U.same(victim,row.unit) then return true end end
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
function N.build(player,identity,mode,settings,engine)
 local now=U.number(U.fn(core.time)) or 0
 local c={player=player,identity=identity,spec=identity.id,mode=mode,pvp=require('hh_modes').pvp[mode]==true,
  settings=settings,now=now,game_now=U.number(U.fn(core.game_time)),enemies={},nearby={},casts={},
  enemy_count=1,attackers=0,physical=false,magic=false,aoe_safe=true,aoe_known=false,party={},
  target=U.call(player,'get_target'),hp=U.hp(player)}
 c.level=U.number(U.call(player,'get_level'))or U.number(U.call(player,'level'))or 1
 c.player_position=U.call(player,'get_position')
 c.target_position=U.call(c.target,'get_position')
 local aura_cache={}
 local function cached_aura(bucket,unit,id,debuff,owner)
  local key=tostring(id)..':'..tostring(debuff==true)..':'..tostring(owner and U.guid(owner) or '')
  bucket=aura_cache[bucket] or {};aura_cache[bucket]=bucket
  local row=bucket[key]
  if not row then row={A.read(unit,id,debuff,owner)};row.n=4;bucket[key]=row end
  return row[1],row[2],row[3],row[4]
 end
 local enums=require('common/enums')
 local runtime=require('hh_runtime')
 local power=runtime.family=='forever' and (enums.power_type.MANA or 0) or enums.power_type.FOCUS
 c.focus=U.number(U.call(player,'get_power',power))
 local haste=U.number(U.call(player,'get_spell_haste'))
 c.gcd_duration=haste and haste>=0 and math.max(0.75,1.5/(1+haste/100)) or 1.5
 c.focus_max=U.number(U.call(player,'get_max_power',power))
 if c.focus and c.focus_max then c.deficit=math.max(0,c.focus_max-c.focus);c.resource_pct=c.focus_max>0 and c.focus/c.focus_max*100 or 0 end
 c.combat=U.call(player,'is_in_combat')==true
 c.player_in_control=U.fn(core.spell_book.is_player_in_control)
 c.busy=U.call(player,'is_casting_spell')==true or U.call(player,'is_channelling_spell')==true
 c.pet=U.call(player,'get_pet');c.pet_hp=U.hp(c.pet)
 c.pet_on_target=U.valid(c.pet)and U.same(U.call(c.pet,'get_target'),c.target)or false
 c.pet_controlled=c.pvp and U.valid(c.pet) and Pvp and U.call(Pvp,'is_crowd_controlled',c.pet)==true or false
 c.pet_buff=function(id) return cached_aura('pet',c.pet,id) end
 local group_seen,party_by_guid={},{}
 local function add_member(u,role)
  local key=U.guid(u)
  if key and not group_seen[key] and U.valid(u) and not U.same(u,player) and U.call(player,'can_attack',u)==false then
   local member={unit=u,hp=U.hp(u),role=role or U.call(u,'get_group_role'),attackers=0}
   group_seen[key]=true;party_by_guid[key]=member;c.party[#c.party+1]=member
  end
 end
 for _,row in pairs(U.fn(core.object_manager.get_party_members) or {}) do
  add_member(unwrap(row),type(row)=='table' and row.role or nil)
 end
 if mode=='arena' and Pvp then
  local healer_role=enums.group_role and enums.group_role.HEALER
  for _,row in ipairs(c.party) do if row.role=='HEALER' or row.role==healer_role then
   c.friendly_healer=row.unit
   c.friendly_healer_controlled=U.call(Pvp,'is_crowd_controlled',row.unit)==true
   break
  end end
 end
 if mode=='raid' then
  if not engine.raid_roster or now-(engine.raid_roster_time or -math.huge)>=1 then
   engine.raid_roster={};engine.raid_roster_time=now
   for index=1,40 do
    local u=U.fn(core.object_manager.get_object_from_guid,'raid'..index)
    if U.valid(u) then engine.raid_roster[#engine.raid_roster+1]=u end
   end
  end
  for _,u in ipairs(engine.raid_roster) do add_member(u) end
 end
 -- Project Sylvanas recommends the cached unit helper instead of walking every
 -- game object. Fall back only on cores where that optimized API is absent.
 local source_rows=c.player_position and UnitHelper
  and U.call(UnitHelper,'get_enemy_list_around',c.player_position,80,true,true)
 if type(source_rows)~='table' then source_rows=U.fn(core.object_manager.get_all_objects) end
 c.aoe_known=type(source_rows)=='table'
 -- Arena frames belong to this snapshot, never to the shared object-manager list.
 local rows={}
 for _,row in pairs(type(source_rows)=='table' and source_rows or {}) do rows[#rows+1]=row end
 local arena_specs={}
 if mode=='arena' then
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
  local position=U.call(u,'get_position')
  local d=U.point_distance(c.player_position,position)
  if key and not seen[key] and U.enemy(player,u) and d<=80 then
   seen[key]=true
   local engaged=N.engaged(player,u,mode,c.party)
   local protected=N.protected(u)
   local detected_spec=arena_specs[key] or (c.pvp and U.number(U.call(u,'get_specialization_id')))
   local role=c.pvp and U.call(u,'get_group_role')
   local healer_role=enums.group_role and enums.group_role.HEALER
   local r={unit=u,guid=key,distance=d,position=position,engaged=engaged,protected=protected,hp=U.hp(u),spec=detected_spec}
   r.healer=X.healer_spec(r.spec) or role=='HEALER' or healer_role and role==healer_role
   if r.healer and (not c.pvp_healer_distance or d<c.pvp_healer_distance) then
    c.pvp_healer=u;c.pvp_healer_distance=d;c.pvp_healer_position=position
   end
   c.enemies[#c.enemies+1]=r
   local target_distance=U.point_distance(c.target_position,position)
   if target_distance<=22 then
    c.nearby[#c.nearby+1]=r
    if target_distance<=12 and (protected or not engaged) then c.aoe_safe=false end
   end
   local victim=U.call(u,'get_target')
   local pressured_ally=party_by_guid[U.guid(victim)]
   if engaged and pressured_ally then pressured_ally.attackers=pressured_ally.attackers+1 end
   if engaged and U.same(victim,player) then
    c.attackers=c.attackers+1
    if d<=8 and U.call(u,'is_casting_spell')~=true then c.physical=true end
   end
   if engaged and not protected then
    local cast=N.cast(u,c.game_now)
    if cast then
     c.casts[#c.casts+1]=cast
     if U.same(cast.target,player) and cast.left<=2 then
      if not c.incoming or cast.left<c.incoming.left then c.incoming=cast end
      if cast.school==1 then c.physical=true elseif cast.school and cast.school>1 then c.magic=true end
      if cast.school and cast.school>1 then c.reflect=cast end
     end
    end
   end
  end
 end
 if mode=='arena' then c.arena_healer=c.pvp_healer end
 local n=0
 for _,r in ipairs(c.nearby) do if U.point_distance(c.target_position,r.position)<=10 and r.engaged and not r.protected then n=n+1 end end
 c.enemy_count=math.max(1,n)
 c.aoe_safe=c.aoe_safe and c.aoe_known and settings.aoe
 for _,cast in ipairs(c.casts) do X.classify_cast(cast,player,c.party) end
 table.sort(c.casts,function(a,b)
  if (a.priority or 0)~=(b.priority or 0) then return (a.priority or 0)>(b.priority or 0) end
  return a.left<b.left
 end)
 c.solo=#c.party==0
 if settings.timer_defensives and not c.pvp then c.upcoming=T.next() end
 c.target_valid=U.enemy(player,c.target) and not N.protected(c.target)
 if c.target_valid then
  c.target_hp=U.hp(c.target);c.target_guid=U.guid(c.target);c.target_name=U.call(c.target,'get_name')
  c.distance=U.point_distance(c.player_position,c.target_position)
  local motion=engine.forever_target_motion
  if runtime.family=='forever'and c.target_guid and c.distance<math.huge then
   if motion and motion.guid==c.target_guid then
    local dt=c.now-motion.time
    if dt>=0.1 and dt<=2 then c.closing_speed=math.max(0,(motion.distance-c.distance)/dt) end
   end
   engine.forever_target_motion={guid=c.target_guid,distance=c.distance,time=c.now}
   c.ranged_cast_safe=function(seconds)
    local projected=c.distance-(c.closing_speed or 0)*(tonumber(seconds)or 0)
    return c.attackers==0 and projected>=8.5
   end
  end
  if runtime.family=='forever'then
   local mana=enums.power_type.MANA or 0
   local target_mana=U.number(U.call(c.target,'get_power',mana))
   local target_mana_max=U.number(U.call(c.target,'get_max_power',mana))
   if target_mana and target_mana_max and target_mana_max>0 then c.target_mana_pct=target_mana/target_mana_max*100 end
  end
  c.target_engaged=N.engaged(player,c.target,mode,c.party)
  local dummy,dummy_source=N.dummy(c.target)
  c.training_dummy=mode=='world_pve' and dummy or false;c.dummy_source=dummy_source
  local player_controlled=U.pvp_unit(c.target)
  if (mode=='arena' or mode=='battleground') and not player_controlled and U.call(c.target,'is_pet')~=true then c.target_valid=false end
  if mode=='world_pvp' and not player_controlled or mode=='world_pve' and player_controlled then c.target_valid=false end
  c.reduced=Pvp and U.call(Pvp,'has_damage_reduction',c.target,50)==true or false
 end
 if c.pvp_healer then c.pvp_healer_los=U.los(player,c.pvp_healer) end
 c.buff=function(id) return cached_aura('player',player,id) end
 c.debuff=function(id) return cached_aura('target',c.target,id,true,player) end
 c.known=function(key)
  local row=S.rows[key]
  local id=row and engine:resolve(row)
  return row and S.allowed(key,c.spec) and S.id_allowed(id,c.spec)
   and (U.fn(core.spell_book.is_spell_known,id)==true or U.fn(core.spell_book.is_spell_known,row.id)==true) or false
 end
 c.talent=function(key) return S.talent[key] and U.fn(core.spell_book.is_spell_known,S.talent[key])==true or false end
 c.ready=function(key,target) return engine:ready(c,key,target) end
 c.pick=function(key,why,target)
  if not c.ready(key,target) then return nil end
  return {key=key,why=why,target=target,scope=engine.scope,epoch=engine.epoch}
 end
 -- City dummies can report effectively zero health indefinitely. Preserve the
 -- raw value for diagnostics, but do not let it force execute-only priorities.
 -- A real Deathblow proc still authorizes Kill Shot during dummy testing.
 c.execute=settings.execute~=false and ((not c.training_dummy and c.target_hp and c.target_hp<=20) or (S.aura.deathblow and c.buff(S.aura.deathblow)==true))
 c.charges=function(k)local r=S.rows[k];return r and U.number(U.fn(core.spell_book.get_spell_charge,engine:resolve(r))) or 0 end
 c.fractional=function(k)
  local r=S.rows[k];if not r or not S.allowed(k,c.spec) then return 0 end
  local id=engine:resolve(r);local current=U.number(U.fn(core.spell_book.get_spell_charge,id)) or 0
  local maximum=U.number(U.fn(core.spell_book.get_spell_charge_max,id))
  if not maximum or maximum<=0 or current>=maximum then return current end
  local started=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_start_time,id))
  local duration=U.number(U.fn(core.spell_book.get_spell_charge_cooldown_duration,id))
  if not started or started<=0 or not duration or duration<=0 then return current end
  -- Charge duration is seconds. Some native versions expose the start timestamp
  -- in milliseconds, while newer surfaces align it with core.time seconds.
  if started>c.now*10 then started=started/1000 end
  local progress=math.max(0,math.min(0.999,(c.now-started)/duration))
  return math.min(maximum,current+progress)
 end
 c.cd=function(k)local r=S.rows[k];return r and U.number(U.fn(core.spell_book.get_spell_cooldown,engine:resolve(r))) or math.huge end
 c.cast_time=function(k)
  local r=S.rows[k];local duration=r and U.number(U.fn(core.spell_book.get_spell_cast_time,engine:resolve(r)))
  return duration and duration>=0 and duration or r and r.casttime or 0
 end
 c.cost=function(k)
  local r=S.rows[k];local costs=r and U.fn(core.spell_book.get_spell_costs,engine:resolve(r))
  local base,modified
  for _,cost in pairs(type(costs)=='table' and costs or {})do
   local resource=require('hh_runtime').family=='forever'and(enums.power_type.MANA or 0)or enums.power_type.FOCUS
   if cost.cost_type==resource then
    local amount=U.number(cost.cost) or U.number(cost.min_cost)
    if amount and amount>=0 then
     if not cost.required_buff_id or cost.required_buff_id==0 then base=base and math.min(base,amount) or amount
     elseif c.buff(cost.required_buff_id)==true then modified=modified and math.min(modified,amount) or amount end
    end
   end
  end
  return modified~=nil and modified or base
 end
 c.predicted_hp=engine:predict(c)
 local incoming=U.number(U.call(player,'get_incoming_damage',1.5))
 if not incoming and Prediction then incoming=U.number(U.call(Prediction,'get_incoming_damage',player,1.5)) end
 local maximum=select(2,U.hp(player))
 if incoming and incoming>0 and maximum and c.hp then
  c.predicted_hp=math.min(c.predicted_hp or c.hp,math.max(0,c.hp-incoming/maximum*100))
 end
 local automatic=settings.automatic_burst
 local burst_allowed=engine.burst_requested~=false
 local burst_eligible=settings.cooldowns and not c.reduced and c.target_valid and c.target_engaged
  and c.distance and c.distance<=45
 c.kill_intent=mode=='arena' and burst_eligible and burst_allowed or false
 if mode=='arena' and automatic then
  local healer_key=c.arena_healer and U.guid(c.arena_healer)
  local trinket=healer_key and engine.pvp_trinket and engine.pvp_trinket[healer_key]
  c.healer_trinket_down=trinket and c.now-trinket<(settings.arena_trinket_window or 90) or false
  local healer_controlled=c.arena_healer and not A.any(c.arena_healer,IMMUNE)
   and (A.any(c.arena_healer,BREAKABLE,true) or U.call(Pvp,'is_crowd_controlled',c.arena_healer)==true)
  c.healer_controlled=healer_controlled and true or false
  c.healer_cc_remaining=healer_controlled and control_remaining(c.arena_healer) or nil
  local cc_ready=healer_controlled and (not c.healer_cc_remaining
   or c.healer_cc_remaining>=(settings.arena_cc_min or 1))
  -- Preserve major cooldowns for a real healer-control/trinket window. Very low
  -- target health remains a valid emergency finish even when control is absent.
  automatic=(c.target_hp and c.target_hp<=35) or cc_ready or c.healer_trinket_down
 end
 local authorized=not c.pvp
 if c.pvp then authorized=burst_allowed and (settings.automatic_burst~=true or automatic==true) end
 c.burst=burst_eligible and authorized
 -- Dummy health and time-to-die are synthetic, so cooldown testing must not be
 -- suppressed by the minimum-life gate.
 local ttd=not c.training_dummy and engine:target_life(c) or nil
 local min_ttd=settings.cooldown_min_ttd or 5
 if ttd and ttd<min_ttd then c.burst=false end
 if mode=='mythic_plus' and c.enemy_count<(settings.cooldown_min_enemies or 3)
  and U.call(c.target,'is_boss')~=true and (not ttd or ttd<min_ttd*2) then c.burst=false end
 c.ttd=ttd
 return c
end
return N
