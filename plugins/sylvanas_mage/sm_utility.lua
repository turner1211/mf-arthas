local U,A,S,N=require('sm_util'),require('sm_aura'),require('sm_spells'),require('sm_snapshot')
local Q={}
local barriers={[62]='prismatic_barrier',[63]='blazing_barrier',[64]='ice_barrier'}
function Q.cursed(u,game_now)
 local rows=U.call(u,'get_debuffs');if type(rows)~='table'then return false end
 for _,r in pairs(rows)do
  local ending=U.number(r.expire_time)
  local active=not ending or ending<=0 or not game_now or ending>game_now
  if active and (r.is_curse==true or r.dispel_type=='Curse' or r.dispel_type=='curse' or r.dispel_type==2 or r.type==2)then return true end
 end
 return false
end
function Q.maintenance(c,e)
 if c.settings.intellect and c.buff(S.aura.intellect)~=true and c.now-(e.history.intellect or -math.huge)>30 then return c.pick('intellect','maintain Arcane Intellect')end
 if c.mode=='arena'and not c.combat and c.settings.defensives and c.settings.invisibility_defense
  and c.now-(e.history.greater_invisibility or-math.huge)>150 then
  local a=c.pick('greater_invisibility','Arena pre-gate stealth for protected opening control');if a then return a end
 end
 -- Current Arcane Arena guidance chains Mass Invisibility after Greater
 -- Invisibility to protect the opening healer/off-target control. Keep this
 -- Arcane-only and require a recently confirmed Greater Invisibility so the
 -- shared Mage utility cannot leak the opener into Fire or Frost.
 if c.spec==62 and c.mode=='arena'and not c.combat and c.settings.defensives
  and c.settings.invisibility_defense and c.talent('improved_mass_invisibility')
  and c.now-(e.history.greater_invisibility or-math.huge)<=12
  and c.now-(e.history.mass_invisibility or-math.huge)>150 then
  return c.pick('mass_invisibility','Arcane protected opener after confirmed Greater Invisibility')
 end
end
function Q.run(c,e)
 local a;local health=math.min(c.hp or 100,c.predicted_hp or 100)
 local current_health=c.hp or 100
 local predicted_loss=(c.hp or 100)-(c.predicted_hp or c.hp or 100)
 local incoming_control
 local healer_threat_cast
 if c.pvp then for _,cast in ipairs(c.casts or{})do
  if cast.critical and cast.interruptible and U.same(cast.target,c.player) and cast.left<=0.45 then incoming_control=cast;break end
  if c.mode=='arena'and cast.critical and c.party_healer and U.same(cast.target,c.party_healer)
   and cast.left<=0.65 then healer_threat_cast=cast end
 end end
 if c.buff(S.aura.ice_block)==true then return end
 local altering=c.buff(S.aura.alter_time)==true
 if not altering then e.temporal=nil end
 if c.settings.defensives then
  -- Cauterize has already preserved Fire from fatal damage when this debuff
  -- is visible.  Preserve Ice Block while the escape is succeeding, but use
  -- it before the six-second burn finishes if enemy pressure is continuing.
  local cauterize_danger=c.spec==63 and c.pvp and c.buff(S.aura.cauterize)==true
   and current_health<=math.max(32,(c.settings.turtle_hp or 18)+10)
   and ((c.attackers or 0)>0 or c.enemy_burst or predicted_loss>=8)
  local immunity_emergency=current_health<=c.settings.turtle_hp
   or current_health<=50 and health<=c.settings.turtle_hp and (not c.pvp or (c.attackers or 0)>0)
   or cauterize_danger
  if immunity_emergency and A.read(c.player,S.aura.hypothermia,true)~=true and c.buff(S.aura.ice_cold)~=true then
   a=c.pick('ice_block',cauterize_danger and'continued pressure during active Cauterize burn'or'emergency immunity');if not a then a=c.pick('ice_cold','learned emergency mitigation')end;if a then return a end
  end
  if c.spec==64 and c.settings.frost_cold_snap and current_health<=40 and health<=math.min(30,(c.settings.turtle_hp or 18)+7)
   and A.read(c.player,S.aura.hypothermia,true)~=true and c.known('ice_block') and c.cd('ice_block')>0.5 then
   a=c.pick('cold_snap','Frost emergency reset for unavailable Ice Block');if a then return a end
  end
  -- The second Alter Time activation is an emergency recall. Only take it
  -- after a large confirmed health loss from a healthy snapshot; this avoids
  -- undoing healer recovery or returning for ordinary sustained damage.
  local temporal=e.temporal
  if c.pvp and c.settings.temporal_defense and not c.talent('temporal_realign')and altering and temporal
   and temporal.epoch==e.epoch and temporal.scope==e.scope and temporal.hp
   and health<=math.max(25,(c.settings.turtle_hp or 18)+7) and temporal.hp-health>=25 then
   a=c.pick('alter_time','emergency Alter Time return after severe health loss');if a then return a end
  end
  local key=barriers[c.spec]
  -- Patch 12.1 Improved Barrier can provide a second charge.  Keep only a
  -- short anti-repeat guard in PvP so a broken first shield does not strand
  -- the second valid charge during sustained pressure.
  local barrier_guard=c.pvp and 1.5 or 8
  if (health<=c.settings.low_hp or c.pvp and c.attackers>0 or c.enemy_burst and health<=90 or c.upcoming and c.upcoming.remaining<=1.5) and c.buff(S.aura[key])~=true and c.now-(e.history[key] or -math.huge)>barrier_guard then
   a=c.pick(key,'current pressure or confirmed boss timer');if a then return a end
  end
  if c.pvp and c.settings.invisibility_defense
   and (c.enemy_burst and (current_health<=50 or c.magic and predicted_loss>=15 or incoming_control)
    or (c.attackers or 0)>0 and current_health<=50)
   and c.now-(e.history.greater_invisibility or-math.huge)>30 then
   a=c.pick('greater_invisibility',incoming_control and 'imminent critical PvP cast target denial' or 'critical PvP burst target denial');if a then return a end
  end
  if c.pvp and c.enemy_burst and (c.attackers or 0)>0 and not altering
   and current_health<=35 and health<=22
   and A.read(c.player,S.aura.hypothermia,true)~=true and c.buff(S.aura.ice_cold)~=true then
   local P=require('sm_pvp');local pressure=P.melee_pressure(c)
   local blink_ready=(c.charges('blink')or 0)>0 or c.cd('blink')<=0.05
   local escape=pressure and blink_ready and P.blink_destination(c,pressure)or nil
   if not escape then
    a=c.pick('ice_block','predicted lethal Arena burst with no validated mobility escape')
    if not a then a=c.pick('ice_cold','predicted lethal Arena burst mitigation')end
    if a then return a end
   end
  end
  if c.pvp and c.settings.temporal_defense and not c.talent('temporal_realign')and health>=70 and not c.moving
   and c.temporal_space~=false and (c.melee_attackers or 0)==0 and not c.peel_target
   and (c.enemy_burst or predicted_loss>=15 or incoming_control) and not altering
   and c.now-(e.history.alter_time or -math.huge)>45 then
   a=c.pick('alter_time',incoming_control and'preemptive ranged control setup return'or'preemptive ranged burst health and position return');if a then return a end
  end
  if c.spec==62 and c.settings.arcane_images and c.talent('refractive_images') and
   (health<=c.settings.heal_hp or c.upcoming and c.upcoming.remaining<=1.5)then
   a=c.pick('mirror_image','Arcane Refractive Images smooth incoming damage');if a then return a end
  end
 end
 if c.settings.interrupts then for _,cast in ipairs(c.casts)do
  if cast.interruptible and not cast.precognition and (not c.settings.priority_interrupts or (cast.priority or 0)>=2) and c.now>=(e.defer[U.guid(cast.unit) or '?'] or 0) and (cast.progress>=c.settings.interrupt_percent or cast.left<0.4)then
   local context=cast.source_healer and' enemy healer cast'or cast.protects_healer and' cast targeting allied healer'or''
   a=c.pick('counterspell','interrupt '..(cast.name or cast.id)..context,cast.unit);if a then a.cast_key=cast.key;return a end
  end end end
 if c.mode=='arena'and c.settings.defensives and c.settings.invisibility_defense
  and healer_threat_cast and c.talent('improved_mass_invisibility')
  and U.number(U.distance(c.player,c.party_healer))
  and U.distance(c.player,c.party_healer)<=40 then
  a=c.pick('mass_invisibility','deny imminent dangerous cast on allied healer after Counterspell unavailable')
  if a then return a end
 end
 -- A confirmed melee pursuer takes priority over dispels, setup, purges and
 -- damage. This prevents filler failures from consuming the peel window.
 a=require('sm_pvp').run(c,e);if a then return a end
 local control=require('sm_control')
 a=control.defensive(c,e);if a then return a end
 -- Proactive Arena control precedes dispels and purges so ordinary utility
 -- cannot starve healer/off-target Polymorph opportunities every global.
 a=control.run(c,e);if a then return a end
 if c.settings.remove_curse then
  local best,best_score,best_reason
  if Q.cursed(c.player,c.game_now)then best,best_score,best_reason=c.player,c.pvp and 200 or 300,'self'end
  local enums=require('common/enums');local healer=enums.group_role and enums.group_role.HEALER
  for _,r in ipairs(c.party)do if Q.cursed(r.unit,c.game_now)then
   local healing=r.role=='HEALER'or r.role==healer;local score=c.pvp and(healing and 300 or 100+(100-(r.hp or 100)))or 200
   if not best or score>best_score then best,best_score,best_reason=r.unit,score,healing and'healer'or'party member'end
  end end
  if best and c.now-(e.history.remove_curse or-math.huge)>1 then a=c.pick('remove_curse','confirmed curse triage: '..best_reason,best);if a then return a end end
 end
 local steal_mana=c.pvp and 45 or 20
 if c.settings.purge and c.target_valid and c.target_engaged and (c.mana_pct or 0)>=steal_mana
 then
  local purge=N.Pvp and U.call(N.Pvp,'is_purgeable',c.target,500)
  local window=c.buff(S.aura.combustion)==true or c.buff(S.aura.surge)==true or c.debuff(S.aura.touch)==true
  local priority=type(purge)=='table' and type(purge.table)=='table' and U.number(purge.table.priority) or 0
  local steal_gap=c.pvp and(priority>=3 and 1.5 or 8)or 3
  local valuable=not c.pvp or priority>=2
  if c.now-(e.history.spellsteal or-math.huge)>steal_gap and type(purge)=='table' and purge.is_purgeable==true
   and valuable and(not window or priority>=3)then
   a=c.pick('spellsteal','confirmed priority '..priority..' stealable magic buff');if a then return a end
  end
 end
 return Q.maintenance(c,e)
end
return Q
