local U,A,S,N=require('ww_util'),require('ww_aura'),require('ww_spells'),require('ww_snapshot')
local Q={}
function Q.maintenance(c,engine)
 if c.buff(6673)~=true and c.now-(engine.history.battle_shout or -math.huge)>120 then
  return c.pick('battle_shout','maintain Battle Shout',c.player)
 end
end
local function stunned_allowed(c,u)
 local p=N.Pvp;local enums=require('common/enums');local flag=enums.cc_flags and enums.cc_flags.STUN
 if not p or not flag then return false end
 if U.call(p,'is_cc_immune',u,flag,0)~=false then return false end
 if U.call(u,'is_player')~=true then return true end
 local dr=U.number(U.call(p,'get_unit_dr',u,flag,0))
 return dr and dr>=0.5
end
local function feared_allowed(c,u)
 local p=N.Pvp;local enums=require('common/enums');local flags=enums.cc_flags or{}
 local flag=flags.DISORIENT or flags.FEAR
 if not p or not flag then return false end
 if U.call(p,'is_cc_immune',u,flag,0)~=false then return false end
 if U.call(u,'is_player')~=true then return true end
 local dr=U.number(U.call(p,'get_unit_dr',u,flag,0))
 return dr and dr>=0.5
end
local function hard_controlled(u)
 if N.controlled(u) then return true end
 local loss=U.call(u,'get_loss_of_control_info')
 if type(loss)~='table' then return false end
 local enums=require('common/enums');local flags=enums.loss_of_control_type or{}
 local rows=loss.valid~=nil and{loss}or loss
 for _,r in pairs(rows)do
  if type(r)=='table'and r.valid==true and r.type~=flags.ROOT and r.type~=flags.SNARE then return true end
 end
 return false
end
local function emergency(c,engine)
 if not c.settings.defensives or not c.hp then return nil end
 local low=math.min(c.hp,c.predicted_hp or c.hp)
 if c.mechanic_defensive and (not c.mechanic_remaining or c.mechanic_remaining<=1.2) then
  local major=c.spec==71 and 'die_by_sword' or c.spec==72 and 'enraged_regeneration' or 'shield_wall'
  local active=c.buff(S.aura.die_by_sword)==true or c.buff(S.aura.regeneration)==true or c.buff(S.aura.shield_wall)==true
  if not active then
   local a=c.pick(major,'pre-mitigate verified boss-guide defensive mechanic',c.player);if a then return a end
  end
 end
 if c.upcoming and c.upcoming.remaining<=0.8 and low<=(c.spec==73 and 85 or 65) then
  local major=c.spec==71 and 'die_by_sword' or c.spec==72 and 'enraged_regeneration' or 'shield_wall'
  local active=c.buff(S.aura.die_by_sword)==true or c.buff(S.aura.regeneration)==true or c.buff(S.aura.shield_wall)==true
  if not active then
   local a=c.pick(major,'pre-mitigate '..c.upcoming.source..' timer: '..c.upcoming.text,c.player);if a then return a end
  end
 end
 local loss=U.call(c.player,'get_loss_of_control_info')
 local enums=require('common/enums')
 if type(loss)=='table' then
  local flags=enums.loss_of_control_type or {}
  local rows=loss.valid~=nil and {loss} or loss
  for _,r in pairs(rows) do
   if type(r)=='table' and r.valid==true and (r.type==flags.FEAR or r.type==flags.FEAR_MECHANIC or r.type==flags.CHARM) then
    local a=c.pick('berserker_rage','confirmed fear or charm',c.player);if a then return a end
   end
  end
 end
 local pressure_bonus=(c.attackers or 0)>=3 and 10 or ((c.attackers or 0)>=2 and 5 or 0)
 local major_threshold=math.min(90,c.settings.low_hp+pressure_bonus)
 local healer_locked=false
 if c.mode=='arena'and(c.attackers or 0)>0 then
  local enums=require('common/enums')
  for _,ally in ipairs(c.party)do
   if (ally.role==enums.group_role.HEALER or ally.role=='HEALER')and hard_controlled(ally.unit)then
    healer_locked=true;break
   end
  end
 end
 if healer_locked and low<=90 then
  local major=c.spec==71 and'die_by_sword'or c.spec==72 and'enraged_regeneration'or'shield_wall'
  local active=c.buff(S.aura.die_by_sword)==true or c.buff(S.aura.regeneration)==true or c.buff(S.aura.shield_wall)==true
  if not active then
   local a=c.pick(major,'trade a major defensive while the Arena healer is crowd controlled',c.player);if a then return a end
  end
 end
 local burst_trade=c.pvp and(c.burst_attackers or 0)>0
  and low<=((c.burst_attackers or 0)>=2 and 95 or 82)
 if burst_trade then
  local major=c.spec==71 and 'die_by_sword' or c.spec==72 and 'enraged_regeneration' or 'shield_wall'
  local active=c.buff(S.aura.die_by_sword)==true or c.buff(S.aura.regeneration)==true or c.buff(S.aura.shield_wall)==true
  if not active then
   local a=c.pick(major,'trade a major defensive into verified enemy burst',c.player);if a then return a end
  end
 end
 if low<=major_threshold then
  local major=c.spec==71 and 'die_by_sword' or c.spec==72 and 'enraged_regeneration' or 'shield_wall'
  local active=c.buff(S.aura.die_by_sword)==true or c.buff(S.aura.regeneration)==true or c.buff(S.aura.shield_wall)==true
  if not active or low<=15 then
   local a=c.pick(major,'health trend and active pressure require major defense',c.player)
   if a then return a end
  end
  if c.spec==73 and low<=30 and c.buff(S.aura.last_stand)~=true then
   local a=c.pick('last_stand','critical tank survival fallback',c.player);if a then return a end
  end
 end
 if c.spec==71 and low<=55 and c.combat and c.now-(engine.history.ignore_pain or -math.huge)>2 then
  local pain,left,_,points=c.buff(S.aura.ignore_pain);local weak=pain~=true or left and left<=2
  local maximum=select(2,U.hp(c.player));local amount=type(points)=='table' and U.number(points[1])
  if amount and maximum and amount<maximum*0.08 then weak=true end
  if weak then local a=c.pick('ignore_pain','Arms pressure absorption',c.player);if a then return a end end
 end
 if c.hp<=c.settings.heal_hp and c.target_valid and c.target_engaged then
  local a=c.pick('impending_victory','restore health') or c.pick('victory_rush','usable victory healing')
  if a then return a end
 end
 local injured,strained=0,0
 for _,r in ipairs(c.party) do
  if r.hp and r.hp<=35 then injured=injured+1 end
  if r.hp and r.hp<=70 then strained=strained+1 end
 end
 local timed_group=c.upcoming and c.upcoming.remaining<=0.6 and strained>=2
 if injured>=2 or timed_group or c.hp<=20 and not c.solo then
  return c.pick('rallying_cry','group emergency health buffer',c.player)
 end
end
local function stance(c,engine)
 if not c.settings.stances then engine.stance_safe_since=nil;return nil end
 local defensive=c.buff(S.aura.defensive_stance)==true or engine.assumed_stance=='defensive_stance'
 local battle=c.buff(S.aura.battle_stance)==true or engine.assumed_stance=='battle_stance'
 local berserker=c.spec==72 and(c.buff(S.aura.berserker_stance)==true or engine.assumed_stance=='berserker_stance')
 -- Fury prefers Berserker Stance only when that talent is actually learned.
 -- A Battle Stance loadout must still establish and restore its available stance.
 local preferred_key=c.spec==72 and c.known('berserker_stance')and'berserker_stance'or'battle_stance'
 local preferred=preferred_key=='berserker_stance'and berserker or battle
 local low=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 local incoming=(c.attackers or 0)>=2 or c.magic and low<=75 or c.pvp and(c.burst_attackers or 0)>0
  or c.upcoming and c.upcoming.remaining<=2
 local threshold=(c.settings.low_hp or 40)+(c.pvp and 20 or c.spec==73 and 25 or 15)
 local danger=incoming or low<=math.min(90,threshold)
 if danger then
  engine.stance_safe_since=nil
  if not defensive then return c.pick('defensive_stance','enter Defensive Stance under confirmed pressure',c.player) end
  return nil
 end
 if defensive then
  if c.mode=='arena'and c.burst and not incoming and low>threshold then
   engine.stance_safe_since=nil
   return c.pick(preferred_key,'leave Defensive Stance for a verified damage window',c.player)
  end
  engine.stance_safe_since=engine.stance_safe_since or c.now
  local delay=c.pvp and 8 or 5
  if c.now-engine.stance_safe_since>=delay then
   return c.pick(preferred_key,'return to specialization damage stance after sustained safety',c.player)
  end
 elseif preferred then engine.stance_safe_since=nil
 else
  -- Establish the specialization's normal stance once. Observed cast tracking
  -- preserves this state when the client hides stance auras.
  return c.pick(preferred_key,'establish specialization damage stance',c.player)
 end
end
function Q.prepare(c,engine)
 local a=stance(c,engine);if a then return a end
 return Q.maintenance(c,engine)
end
function Q.interrupt(c,engine,urgent_only)
 if not c.settings.interrupts then return nil end
 table.sort(c.casts,function(a,b)
  if (a.priority or 0)~=(b.priority or 0) then return (a.priority or 0)>(b.priority or 0) end
  local a_self=U.same(a.target,c.player);local b_self=U.same(b.target,c.player)
  if a_self~=b_self then return a_self end
  return a.left<b.left
 end)
 local latency=(U.number(U.fn(core.get_ping)) or 100)/1000
 local urgent=math.max(0.15,math.min(0.6,latency+0.12))
 if c.mode=='mythic_plus' and c.settings.mplus_stops and c.settings.cc and c.aoe_safe then
  local simultaneous=0
  for _,cast in ipairs(c.casts) do
   if cast.critical and cast.left>latency+0.15 and U.distance(c.player,cast.unit)<=10 then simultaneous=simultaneous+1 end
  end
  if simultaneous>=2 then
   if c.spec==73 and c.settings.taunt and not c.identity.role_conflict then
    local a=c.pick('disrupting_shout','interrupt multiple critical Mythic+ casts',c.player);if a then return a end
   end
   if c.now-(engine.history.disrupting_shout or -math.huge)>4 then
    local a=c.pick('shockwave','stop multiple critical Mythic+ casts',c.player);if a then return a end
   end
  end
 end
 for _,cast in ipairs(c.casts) do
  local urgent_cast=cast.critical or U.same(cast.target,c.player)
  if not urgent_only or urgent_cast then
  local defer=engine.defer[U.guid(cast.unit) or '?'] or 0
  local threshold=cast.critical and math.min(25,c.settings.interrupt_percent) or c.settings.interrupt_percent
  if c.now>=defer and (cast.channel or cast.progress>=threshold or cast.left<=urgent) then
   if cast.interruptible then
    local a=c.pick('pummel','interrupt '..cast.id,cast.unit)
    if a then a.cast_key=cast.key;return a end
   end
   local reflect_first=c.reflect and c.reflect.key==cast.key
    and c.ready('spell_reflection',c.player)
   if c.settings.cc and not reflect_first and cast.left>latency+0.15 and stunned_allowed(c,cast.unit) then
    local a=c.pick('storm_bolt','stun eligible cast '..cast.id,cast.unit)
    if a then a.cast_key=cast.key;return a end
   end
  end
  end
 end
end
function Q.reflect(c)
 if not c.settings.defensives or not c.reflect or c.buff(S.aura.reflection)==true then return nil end
 local latency=(U.number(U.fn(core.get_ping))or 100)/1000
 local window=math.max(0.35,math.min(0.9,latency+0.45))
 if c.reflect.left<=window and c.reflect.left>=0.05 then
  return c.pick('spell_reflection','fallback for incoming targeted magic cast',c.player)
 end
end
function Q.arena_root_break(c)
 if c.mode~='arena' or c.spec~=71 and c.spec~=72 or c.rooted~=true
  or not c.settings.damage or not c.settings.cooldowns
  or not c.target_valid or not c.target_engaged or not c.distance or c.distance<=8 or c.distance>25
  or c.reduced then return nil end
 local a=c.pick('avatar','break confirmed Arena root to restore melee uptime',c.player)
 if a then return a end
 local key=c.spec==71 and 'arms_bladestorm' or c.spec==72 and 'fury_bladestorm' or nil
 if key then return c.pick(key,'break confirmed Arena root to restore melee uptime',c.player) end
end
function Q.arena_peel(c,engine)
 if c.mode~='arena' or not c.settings.arena_peel or not c.settings.defensives then return nil end
 local p=N.Pvp;local best,score,attacker
 for _,ally in ipairs(c.party) do
  local pressure=0
  local focused
  for _,enemy in ipairs(c.enemies) do
   if U.same(U.call(enemy.unit,'get_target'),ally.unit) then
    pressure=pressure+1
    if p and U.call(p,'has_burst_active',enemy.unit,300)==true then pressure=pressure+2;focused=enemy.unit end
   end
  end
  local value=pressure*30+(ally.hp and 100-ally.hp or 0)
  if pressure>0 and ally.hp and ally.hp<=65 and (not score or value>score) then best,score,attacker=ally,value,focused end
 end
 -- Intervene redirects attacks, not spells. Direct cast-target evidence is
 -- stronger than class heuristics: a non-disarmable attacker may still deal
 -- physical attacks, while an active spell aimed at the ally cannot be covered.
 local spell_burst=attacker and (U.call(attacker,'is_casting_spell')==true
   or U.call(attacker,'is_channelling_spell')==true)
  and U.same(U.call(attacker,'get_active_spell_target'),best.unit)
 local redirectable=not spell_burst
 local physical=attacker and p and U.call(p,'is_disarmable',attacker)==true
 if best and redirectable and c.now-(engine.history.intervene or -math.huge)>3 then
  if physical and(c.spec==71 or c.spec==72)and c.hp and c.hp<=75 then
   local key=c.spec==71 and'die_by_sword'or'enraged_regeneration'
   local aura=c.spec==71 and S.aura.die_by_sword or S.aura.regeneration
   local guard=c.buff(aura)~=true and c.pick(key,'prepare to Intervene a teammate under verified melee burst',c.player)
   if guard then return guard end
  end
  local a=c.pick('intervene','peel focused arena ally at '..math.floor(best.hp)..'% health',best.unit);if a then return a end
 end
 if best and attacker and c.settings.cc and stunned_allowed(c,attacker) then
  local stop=c.pick('storm_bolt','stop burst on focused arena ally',attacker);if stop then return stop end
 end
 if best and best.hp<=45 and attacker and c.settings.cc and c.aoe_safe
  and U.distance(c.player,attacker)<=8 and feared_allowed(c,attacker) then
  return c.pick('intimidating_shout','emergency fear peel for critical arena ally',c.player)
 end
end
function Q.arena_control(c)
 if c.mode~='arena' or not c.settings.arena_control or not c.settings.cc or not c.burst then return nil end
 -- Arena Colossus sets Avatar and Warbreaker before stunning into Demolish.
 -- Other hero trees retain the normal control-first sequence.
 if c.spec==71 and c.known('demolish')and(c.avatar~=true or c.smash~=true)then return nil end
 if c.arena_healer and not U.same(c.arena_healer,c.target) and not N.protected(c.arena_healer)
  and c.known('shockwave') and c.ready('shockwave',c.player) and stunned_allowed(c,c.arena_healer) then
  local control=c.pick('storm_bolt','control enemy healer during Arena kill window',c.arena_healer)
  if control then return control end
 end
 if c.target_valid and stunned_allowed(c,c.target) then
  local a=c.pick('storm_bolt','lock the kill target during Arena burst',c.target);if a then return a end
  if c.distance and c.distance<=8 and c.aoe_safe then
   local wave=c.pick('shockwave','follow healer control with DR-safe kill-target stun',c.player);if wave then return wave end
  end
 end
 if c.arena_healer and not U.same(c.arena_healer,c.target) and not N.protected(c.arena_healer)
  and c.distance and c.distance<=8 and U.distance(c.player,c.arena_healer)<=8
  and c.aoe_safe and feared_allowed(c,c.arena_healer) then
  return c.pick('intimidating_shout','start a DR-safe healer fear during arena pressure',c.player)
 end
end
function Q.taunt(c)
 if c.spec~=73 or c.pvp or c.mode=='raid' or c.identity.role_conflict or not c.settings.taunt then return nil end
 local enums=require('common/enums')
 for _,r in ipairs(c.enemies) do
  local victim=U.call(r.unit,'get_target')
  local role=U.call(victim,'get_group_role')
  local friendly=U.call(victim,'is_party_member')==true or c.mode=='delve' and U.valid(victim)
   and U.call(victim,'is_player')==false and U.call(c.player,'can_attack',victim)==false
  local threat=U.call(c.player,'get_threat_situation',r.unit)
  if r.engaged and not r.protected and U.call(r.unit,'is_player')==false and friendly and not U.same(victim,c.player)
   and role~=enums.group_role.TANK and role~='TANK' and type(threat)=='table' and threat.is_tanking==false then
   local a=c.pick('taunt','recover enemy attacking a non-tank ally',r.unit);if a then return a end
  end
 end
end
function Q.shield_break(c,engine)
 if not U.enemy(c.player,c.target) or not N.engaged(c.player,c.target,c.mode,c.training) then return nil end
 if N.immune(c.target) then
  -- Live logs showed stale native cooldown data immediately after confirmed
  -- throws. Twenty seconds remains below Demolition's reduced cooldown while
  -- preventing the same successful projectile from being requested repeatedly.
  if engine and c.now-(engine.history.shattering_throw or -math.huge)<20 then return nil end
  return c.pick('shattering_throw','remove confirmed enemy immunity',c.target)
 end
 if N.protected(c.target) then return nil end
 local absorb=U.number(U.call(c.target,'get_total_shield'))
 local _,maximum=U.hp(c.target)
 if absorb and absorb>0 and maximum and absorb>=maximum*0.10 then
  if engine and c.now-(engine.history.wrecking_throw or -math.huge)<20 then return nil end
  return c.pick('wrecking_throw','break a substantial absorb shield',c.target)
 end
end
function Q.oppressor(c)
 if c.spec~=73 or not c.pvp or not c.settings.damage
  or not c.target_valid or not c.target_engaged then return nil end
 local focused=false
 for _,ally in ipairs(c.party) do
  if U.same(U.call(ally.unit,'get_target'),c.target) then focused=true;break end
 end
 if not c.burst and not focused then return nil end
 return c.pick('oppressor',focused and 'amplify confirmed team focus with Focused Assault'
  or 'apply Focused Assault during Protection kill window',c.target)
end
function Q.disarm(c,engine)
 if not c.pvp or not c.settings.cc then return nil end
 local p=N.Pvp
 if p and c.now-(engine.history.disarm or -math.huge)>8 then
  local best,best_score
  for _,enemy in ipairs(c.enemies) do
   if enemy.engaged and not enemy.protected and U.call(p,'has_burst_active',enemy.unit,300)==true
    and U.call(p,'is_disarmable',enemy.unit)==true then
    local victim=U.call(enemy.unit,'get_target');local score=100-(enemy.distance or 45)
    if U.same(victim,c.player)then score=score+200 end
    for _,ally in ipairs(c.party)do
     if U.same(victim,ally.unit)then score=score+150+(100-(ally.hp or 100));break end
    end
    if not best_score or score>best_score then best,best_score=enemy.unit,score end
   end
  end
  if best then return c.pick('disarm','stop the highest-risk verified weapon burst',best)end
 end
end
function Q.slow(c,engine)
 if not c.pvp or not c.target_valid or not c.target_engaged or not c.settings.cc then return nil end
 local p=N.Pvp
 if p and U.call(p,'is_slow',c.target,30,1500)==false
  and U.call(p,'is_slow_immune',c.target)==false and c.now-(engine.history.hamstring or -math.huge)>6 then
  return c.pick('hamstring','maintain pressure with a confirmed missing slow')
 end
end
function Q.pvp(c,engine)
 if not c.pvp or not c.target_valid or not c.target_engaged then return nil end
 local disarm=Q.disarm(c,engine);if disarm then return disarm end
 return Q.slow(c,engine)
end
function Q.run(c,engine)
 local a=Q.interrupt(c,engine,true);if a then return a end
 a=emergency(c,engine);if a then return a end
 a=Q.interrupt(c,engine);if a then return a end
 a=Q.reflect(c);if a then return a end
 a=Q.arena_root_break(c);if a then return a end
 a=stance(c,engine);if a then return a end
 if c.mode=='arena'then a=Q.disarm(c,engine);if a then return a end end
 a=Q.arena_peel(c,engine);if a then return a end
 -- Current Arms/Fury Arena openers establish Hamstring before offensive
 -- control. Defensive peels retain priority, but an unslowed kill target can
 -- no longer spend the Storm Bolt global first and escape the setup afterward.
 if c.mode=='arena'and(c.spec==71 or c.spec==72)then
  a=Q.slow(c,engine);if a then return a end
 end
 a=Q.arena_control(c);if a then return a end
 a=Q.taunt(c);if a then return a end
 a=Q.shield_break(c,engine);if a then return a end
 a=Q.oppressor(c);if a then return a end
 a=Q.pvp(c,engine);if a then return a end
 local charge_min=c.mode=='arena'and 15 or c.pvp and c.spec==72 and 15 or 9
 if c.settings.charge and c.distance and c.distance>=charge_min and c.distance<=25 and c.target_engaged
  and c.now-(engine.history.charge or -math.huge)>=2 then
  a=c.pick('charge','close distance to engaged target');if a then return a end
 end
 return Q.maintenance(c,engine)
end
return Q
