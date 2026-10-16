local U,A,S,N=require('hh_util'),require('hh_aura'),require('hh_spells'),require('hh_snapshot');local Q={}
local HARMLESS_BREAKABLE={[5116]=true,[14268]=true,[14267]=true,[2974]=true}
local function clean_breakable(unit)
 local debuffs=U.call(unit,'get_debuffs');if type(debuffs)~='table'then return false end
 for _,row in pairs(debuffs)do if not HARMLESS_BREAKABLE[U.number(row.buff_id)]then return false end end
 return true
end
function Q.run(c,e)
 local a;local level=U.number(c.level)or 1
 -- Scare Beast is learned at 14. Use it only on the selected hostile pet and
 -- only before our own damage lands; the fear is breakable and short ranged.
 if c.pvp and level>=14 and c.settings.cc and U.call(c.target,'is_pet')==true
  and not N.protected(c.target)and clean_breakable(c.target)and e.history_target.serpent_sting~=c.target_guid then
  a=c.pick('scare_beast','fear the selected enemy beast pet before applying damage');if a then return a end
 end
 -- Distracting Shot is learned at 12. Peel a mob from the healer only while
 -- healthy and not already tanking another attacker, giving the tank time to recover it.
 if not c.pvp and level>=12 and c.settings.cc and c.hp>=70 and c.attackers==0 and U.valid(c.target)then
  local victim=U.call(c.target,'get_target')
  for _,member in ipairs(c.party or{})do
   if U.same(victim,member.unit)and tostring(member.role):upper()=='HEALER'then
    a=c.pick('distracting_shot','pull a mob off the healer for tank recovery');if a then return a end
   end
  end
 end
 local melee_emergency=c.physical or(c.distance and c.distance<=5.5 and c.attackers>0)
 if level>=20 and c.settings.defensives and c.hp<=c.settings.turtle_hp and melee_emergency then a=c.pick('deterrence','Forever emergency melee avoidance');if a then return a end end
 if level>=30 and c.settings.defensives and c.settings.forever_readiness~=false and c.hp<=c.settings.turtle_hp and melee_emergency
  and c.known('deterrence')and c.cd('deterrence')>10 then a=c.pick('readiness','reset Deterrence for a lethal melee emergency');if a then return a end end
 if level>=30 and c.settings.defensives and c.hp<=c.settings.low_hp and c.attackers>0 then
  a=c.pick('feign_death','drop lethal pressure or PvE threat');if a then return a end
 end
 if level>=20 and not c.pvp and c.settings.defensives and c.attackers>0 and U.valid(c.pet)then
  a=c.pick('disengage','reduce threat after pulling from the pet');if a then return a end
 end
 if level>=12 and c.settings.pet_heal and c.pet_hp and c.pet_hp<=c.settings.pet_hp and(c.attackers==0 or c.pet_hp<=25)then
  local mend=false;for _,id in ipairs(S.aura.mend or{})do if A.read(c.pet,id)==true then mend=true;break end end
  if not mend then a=c.pick('mend_pet','heal active Forever pet');if a then return a end end
 end
 local lone_wolf=c.spec==254 and c.settings.forever_lone_wolf==true
 if level>=10 and c.settings.pet_recovery and not lone_wolf then
  if c.pet==nil then a=c.pick('call_pet','call missing Forever pet')
  elseif U.call(c.pet,'is_dead')==true and c.attackers==0 and c.hp>=80 then a=c.pick('revive_pet','revive Forever pet after pressure ends')end
  if a then return a end
 end
 if c.spec==253 and c.settings.interrupts then
  for _,cast in ipairs(c.casts or{})do if cast.interruptible and cast.left<=1.2 then
   a=c.pick('intimidation','pet stun to stop a dangerous cast',cast.unit);if a then return a end
  end end
 end
 if c.settings.auto_kite and c.target_valid~=false and c.target_engaged~=false then
  local distance=c.distance or U.distance(c.player,c.target)
  -- In solo PvE, slow a mob while it closes so leveling Hunters gain extra
  -- ranged attacks before the dead zone. Party play leaves movement to the tank.
  if not c.pvp and level>=8 and c.solo and distance>8 and distance<=25
   and c.debuff(S.aura.concussive)~=true then
   a=c.pick('concussive_shot','slow a solo leveling target before it reaches the dead zone');if a then return a end
  end
  if not c.pvp then return end
  if distance<=5.5 and level>=4 and(c.spec~=255 or c.hp<=c.settings.low_hp)then
   local monkey=false;for _,id in ipairs(S.aura.monkey or{})do if A.read(c.player,id)==true then monkey=true;break end end
   if not monkey then a=c.pick('aspect_monkey','switch to dodge aspect while trapped in the dead zone');if a then return a end end
  end
  if c.spec==254 and distance<=15 and c.attackers>0 and c.settings.cc
   and c.debuff(S.aura.serpent)~=true and not U.same(c.pet and U.call(c.pet,'get_target'),c.target)then
   a=c.pick('forever_scatter','disorient an undotted melee attacker to escape the dead zone');if a then return a end
  end
  if level>=28 and distance<=8 and c.attackers>0 and c.aoe_safe and c.settings.forever_traps~=false then a=c.pick('frost_trap','slow the melee approach at the Hunter position');if a then return a end end
  if level>=12 and distance<=5.5 then a=c.pick('wing_clip','melee slow before creating distance')
  elseif level>=8 and distance<=20 and c.debuff(S.aura.concussive)~=true then a=c.pick('concussive_shot','maintain ranged slow on approaching target')end
  if a then return a end
 end
end
return Q
