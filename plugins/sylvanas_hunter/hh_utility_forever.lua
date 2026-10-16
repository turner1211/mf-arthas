local U,A,S=require('hh_util'),require('hh_aura'),require('hh_spells');local Q={}
function Q.run(c,e)
 local a
 local melee_emergency=c.physical or(c.distance and c.distance<=5.5 and c.attackers>0)
 if c.settings.defensives and c.hp<=c.settings.turtle_hp and melee_emergency then a=c.pick('deterrence','Forever emergency melee avoidance');if a then return a end end
 if c.settings.defensives and c.settings.forever_readiness~=false and c.hp<=c.settings.turtle_hp and melee_emergency
  and c.known('deterrence')and c.cd('deterrence')>10 then a=c.pick('readiness','reset Deterrence for a lethal melee emergency');if a then return a end end
 if c.settings.defensives and c.hp<=c.settings.low_hp and c.attackers>0 then
  a=c.pick('feign_death','drop lethal pressure or PvE threat');if a then return a end
 end
 if not c.pvp and c.settings.defensives and c.attackers>0 and U.valid(c.pet)then
  a=c.pick('disengage','reduce threat after pulling from the pet');if a then return a end
 end
 if c.settings.pet_heal and c.pet_hp and c.pet_hp<=c.settings.pet_hp and(c.attackers==0 or c.pet_hp<=25)then
  local mend=false;for _,id in ipairs(S.aura.mend or{})do if A.read(c.pet,id)==true then mend=true;break end end
  if not mend then a=c.pick('mend_pet','heal active Forever pet');if a then return a end end
 end
 local lone_wolf=c.spec==254 and c.settings.forever_lone_wolf==true
 if c.settings.pet_recovery and not lone_wolf then
  if c.pet==nil then a=c.pick('call_pet','call missing Forever pet')
  elseif U.call(c.pet,'is_dead')==true and c.attackers==0 and c.hp>=80 then a=c.pick('revive_pet','revive Forever pet after pressure ends')end
  if a then return a end
 end
 if c.spec==253 and c.settings.interrupts then
  for _,cast in ipairs(c.casts or{})do if cast.interruptible and cast.left<=1.2 then
   a=c.pick('intimidation','pet stun to stop a dangerous cast',cast.unit);if a then return a end
  end end
 end
 if c.pvp and c.settings.auto_kite then
  local distance=U.distance(c.player,c.target)
  if distance<=5.5 and(c.spec~=255 or c.hp<=c.settings.low_hp)then
   local monkey=false;for _,id in ipairs(S.aura.monkey or{})do if A.read(c.player,id)==true then monkey=true;break end end
   if not monkey then a=c.pick('aspect_monkey','switch to dodge aspect while trapped in the dead zone');if a then return a end end
  end
  if c.spec==254 and distance<=15 and c.attackers>0 and c.settings.cc
   and c.debuff(S.aura.serpent)~=true and not U.same(c.pet and U.call(c.pet,'get_target'),c.target)then
   a=c.pick('forever_scatter','disorient an undotted melee attacker to escape the dead zone');if a then return a end
  end
  if distance<=8 and c.attackers>0 and c.aoe_safe and c.settings.forever_traps~=false then a=c.pick('frost_trap','slow the melee approach at the Hunter position');if a then return a end end
  if distance<=5.5 then a=c.pick('wing_clip','melee slow before creating distance')
  elseif distance<=20 and c.debuff(S.aura.concussive)~=true then a=c.pick('concussive_shot','maintain ranged slow on approaching target')end
  if a then return a end
 end
end
return Q
