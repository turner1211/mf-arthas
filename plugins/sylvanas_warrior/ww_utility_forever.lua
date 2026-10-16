local S,U=require('ww_spells'),require('ww_util');local Q={}
local ok,Pvp=pcall(require,'common/utility/pvp_helper');if not ok then Pvp=nil end
function Q.prepare(c)
 if c.settings.stances then
  -- Battle Stance permits Charge and Rend for both leveling DPS specs. Fury
  -- only enters Berserker Stance for an explicit Berserker-only action. A
  -- Protection Warrior may pull from Defensive Stance only with Vanguard.
  local prot_vanguard=c.spec==73 and c.talent('vanguard')
  local key=prot_vanguard and'defensive_stance'or'battle_stance';local aura=S.aura[key]
  if c.buff(aura)~=true then local a=c.pick(key,'Forever safe pull stance');if a then return a end end
 end
 if c.buff(S.aura.battle_shout)~=true then local a=c.pick('battle_shout','maintain Forever Battle Shout');if a then return a end end
 -- Current 70374 data removed Bloodrage's forced-combat clause, so it can
 -- safely build Rage before Charge when health is not under pressure.
 if(c.rage or 0)<=60 and(not c.hp or c.hp>50)then local a=c.pick('bloodrage','build pre-pull Forever Rage');if a then return a end end
 if c.settings.charge and c.target_valid and c.distance and c.distance>=8 and c.distance<=25 then
  local a=c.pick('charge','Forever open with Charge before entering combat');if a then return a end
 end
end
function Q.run(c,engine)
 local low=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 if c.feared then
  local a=c.pick('berserker_rage','break Forever fear or incapacitate')
  if not a and c.spec==72 and c.settings.cooldowns then a=c.pick('death_wish','Forever Fury emergency fear immunity')end
  if a then return a end
 end
 if c.settings.interrupts then
  for _,cast in ipairs(c.casts or{})do
   local threshold=c.settings.interrupt_percent or 55
   if cast.interruptible and(cast.channel or cast.progress>=threshold or cast.left<=.5)then
    local a=c.pick('pummel','interrupt Forever cast',cast.unit)or c.pick('shield_bash','interrupt Forever cast',cast.unit)
    if a then a.cast_key=cast.key;return a end
   end
  end
 end
 local root_break=c.talent('improved_berserker_rage')and(c.rooted and(c.distance or 99)>5
  or c.slowed and(c.distance or 0)>8)
 if root_break and c.settings.cc then
  if c.settings.stances and c.buff(S.aura.berserker_stance)~=true then
   local a=c.pick('berserker_stance','Forever stance for Improved Berserker Rage movement break');if a then return a end
  end
  local a=c.pick('berserker_rage','Forever remove movement impairment');if a then return a end
 end
 if c.settings.defensives then
  if low<=20 then local a=c.pick('shield_wall','Forever lethal-pressure Shield Wall');if a then return a end end
  if c.spec==73 and low<=40 then local a=c.pick('last_stand','Forever early Last Stand health buffer');if a then return a end end
  local retaliation_safe=c.spec~=73 and c.attackers>=3 and low>55
   or c.spec==73 and c.attackers>=4 and low>75 and not c.magic
  if retaliation_safe and c.physical and c.known('retaliation')then
   if c.settings.stances and c.buff(S.aura.battle_stance)~=true then local a=c.pick('battle_stance','Forever stance for Retaliation');if a then return a end end
   local a=c.pick('retaliation','Forever multi-attacker Retaliation');if a then return a end
  end
 end
 -- Gore Drinker makes Berserker Rage a small recovery primer. Keep the fear
 -- break available in PvP and do not spend it when health is already critical.
 if not c.pvp and c.spec==72 and c.talent('gore_drinker') and not c.feared
  and low>30 and low<=60 and(c.rage or 0)<=70 then
  local a=c.pick('berserker_rage','Forever Gore Drinker recovery primer');if a then return a end
 end
 local disarm_pressure=c.pvp and c.physical and Pvp and Pvp.is_disarmable and Pvp:is_disarmable(c.target)==true
 if c.settings.stances and c.spec==72 and not disarm_pressure and not(c.pvp and c.distance and c.distance>8)then
  local level=c.level or 60
  local rend=c.debuff(S.aura.rend);local recent=engine.target_history['rend:'..tostring(c.target_guid)]or-math.huge
  -- Level-30 Fury intentionally omits Rend, so its stance controller must not
  -- hold Battle Stance waiting for an action the rotation will never request.
  -- Before Berserker Stance is learned, Battle Stance remains the safe home.
  if level>30 and rend~=true and c.now-recent>12 then
   if c.buff(S.aura.battle_stance)~=true then local a=c.pick('battle_stance','Forever Fury stance for Rend');if a then return a end end
  elseif level>=30 and c.buff(S.aura.berserker_stance)~=true then
   local a=c.pick('berserker_stance','Forever Fury level-appropriate damage stance');if a then return a end
  elseif level<30 and c.buff(S.aura.battle_stance)~=true then
   local a=c.pick('battle_stance','Forever Fury pre-Berserker damage stance');if a then return a end
  end
 end
 if c.settings.stances and c.spec==71 and not c.pvp and c.buff(S.aura.battle_stance)~=true then
  -- Spearing Strike explicitly requires Battle Stance in current Forever.
  local a=c.pick('battle_stance','Forever Arms restore Spearing Strike stance');if a then return a end
 end
 if c.spec==73 and not c.pvp and c.settings.taunt and not c.identity.role_conflict then
  for _,enemy in ipairs(c.enemies or{})do
   local victim=U.call(enemy.unit,'get_target')
   if enemy.engaged and U.valid(victim)and not U.same(victim,c.player)and U.call(victim,'is_party_member')==true then
    local a=c.pick('taunt','Forever recover loose dungeon enemy',enemy.unit);if a then return a end
    -- Mocking Blow is the six-second backup when Taunt is cooling down. Check
    -- its native cooldown before leaving Defensive Stance so a failed backup
    -- cannot make the tank bounce between stances every update.
    local cd=c.cooldown and c.cooldown('mocking_blow')
    if c.known('mocking_blow')and cd and cd<=.05 then
     if c.settings.stances and c.buff(S.aura.battle_stance)~=true then
      a=c.pick('battle_stance','Forever stance for backup Mocking Blow');if a then return a end
     end
     a=c.pick('mocking_blow','Forever backup threat fixate while Taunt cools',enemy.unit);if a then return a end
    end
   end
  end
 end
 if c.settings.stances and c.spec==73 and not c.pvp then
  local finishing=c.solo and c.target_hp and c.target_hp<=20 and(c.rage or 0)>=35
   and(c.hp or 0)>60 and(c.attackers or 0)<=1
  local preferred=finishing and'battle_stance'or'defensive_stance'
  if c.buff(S.aura[preferred])~=true then
   local why=finishing and'Forever safe solo stance for Execute'or'Forever restore Protection tank stance'
   local a=c.pick(preferred,why);if a then return a end
  end
 end
 if c.settings.cc and c.casts and #c.casts>0 then
  local cast=c.casts[1];if cast.interruptible~=true and(cast.left or 9)<=2 then
   local a=c.pick('concussion_blow','Forever stop dangerous uninterruptible cast',cast.unit)
   if not a and(c.pvp or c.mode=='world_pve')then a=c.pick('intimidating_shout','Forever emergency solo or PvP cast stop')end
   if a then return a end
  end
 end
 if c.spec==73 and c.settings.cc and c.physical and(c.attackers or 0)>=1
  and math.min(c.hp or 100,c.predicted_hp or c.hp or 100)<=55 then
  local a=c.pick('concussion_blow','Forever Protection stun a hard hitter under pressure');if a then return a end
 end
 if c.pvp and c.spec==72 and c.enemy_count>=2 and c.aoe_safe
  and c.now-(engine.history.piercing_howl or-math.huge)>=5 then
  local a=c.pick('piercing_howl','Forever Fury slow nearby PvP group');if a then return a end
 end
 if c.pvp and c.settings.cc and disarm_pressure then
  if c.buff(S.aura.defensive_stance)~=true then local a=c.pick('defensive_stance','Forever stance for Disarm');if a then return a end end
  local a=c.pick('disarm','Forever disarm physical PvP pressure');if a then return a end
 end
 -- Protection must briefly enter Battle Stance for Hamstring, then return to
 -- Defensive Stance as soon as the slow has been applied.
 if c.pvp and c.spec==73 and c.settings.cc and c.distance and c.distance<=5 then
  local slowed=c.debuff(S.aura.hamstring);local recent=engine.target_history['hamstring:'..tostring(c.target_guid)]or-math.huge
  if slowed~=true and c.now-recent>4 then
   if c.settings.stances and c.buff(S.aura.battle_stance)~=true then local a=c.pick('battle_stance','Forever Protection stance for Hamstring');if a then return a end end
   local a=c.pick('hamstring','Forever Protection maintain PvP slow');if a then return a end
  elseif c.settings.stances and c.buff(S.aura.defensive_stance)~=true then
   local a=c.pick('defensive_stance','Forever Protection restore tank stance after Hamstring');if a then return a end
  end
 end
 if c.pvp and c.distance and c.distance>8 then
  if c.buff(S.aura.berserker_stance)~=true then local a=c.pick('berserker_stance','Forever stance for Intercept');if a then return a end end
  local a=c.pick('intercept','Forever close PvP gap in Berserker Stance');if a then return a end
 end
 -- Temporary control stances must not leak into the normal spec rotation.
 if c.settings.stances and c.pvp and c.distance and c.distance<=8 then
  local preferred=c.spec==72 and'berserker_stance'or c.spec==73 and'defensive_stance'or'battle_stance'
  local aura=S.aura[preferred]
  if c.buff(aura)~=true then local a=c.pick(preferred,'Forever restore spec stance after PvP utility');if a then return a end end
 end
 if not c.pvp and c.spec~=73 and c.settings.cc and c.target_hp and c.target_hp<=20
  and(c.mode=='world_pve'or c.mode=='delve'or c.mode=='dungeon')and c.distance and c.distance<=5 then
  local slowed=c.debuff(S.aura.hamstring);local recent=engine.target_history['hamstring:'..tostring(c.target_guid)]or-math.huge
  if slowed~=true and c.now-recent>4 then local a=c.pick('hamstring','Forever slow a low-health runner');if a then return a end end
 end
 if c.buff(S.aura.battle_shout)~=true then local a=c.pick('battle_shout','refresh Forever Battle Shout during combat');if a then return a end end
 local low=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 local bloodrage_floor=c.spec==73 and 35 or 50
 if(c.rage or 0)<=45 and low>bloodrage_floor then
  local a=c.pick('bloodrage','restore Forever combat Rage at safe health');if a then return a end
 end
 if not c.pvp and c.spec==72 and(c.rage or 0)<=20 and c.talent('improved_berserker_rage')then
  return c.pick('berserker_rage','Forever Fury convert Improved Berserker Rage into Rage')
 end
end
return Q
