local F=require('hh_forever_common');local S=require('hh_spells');local U=require('hh_util');local R={spec=255}
function R.decide(c,e)
 if c.spec~=255 then return end
 local distance=U.distance(c.player,c.target);local melee=distance<=5.5;local a
 a=F.pvp_tracking(c,e);if a then return a end
 if melee and c.settings.forever_melee~=false then
  local defensive_monkey=c.pvp and c.hp and c.hp<=c.settings.low_hp and F.has(c.player,S.aura.monkey)
  if not defensive_monkey then a=F.aspect(c,'aspect_beast',S.aura.beast,'maintain melee Aspect of the Beast');if a then return a end end
  a=F.mark_and_sting(c,e);if a then return a end
  if c.burst then a=c.pick('rapid_fire','accelerate the Survival melee burst window');if a then return a end end
  a=F.burst_reset(c,{'rapid_fire'},'reset spent Survival burst abilities for a durable target');if a then return a end
  a=c.pick('mongoose_bite','use reactive Mongoose Bite');if a then return a end
  a=c.pick('counterattack','use reactive Counterattack');if a then return a end
  local lacerated=false;for _,id in ipairs(S.aura.lacerate or{})do if c.debuff(id)==true then lacerated=true;break end end
  if c.settings.forever_lacerate~=false and not lacerated and F.durable(c,14,50)then a=c.pick('lacerate','apply the 21-second bleed only to a durable target');if a then return a end end
  a=c.pick('strider_kick','highest-priority cooldown strike with movement-speed window');if a then return a end
  a=c.pick('raptor_strike','Forever Survival weapon strike');if a then return a end
  if c.settings.forever_traps~=false and (not c.target_hp or c.target_hp>35) and F.can_spend(c,'immolation_trap',25)then
   a=c.pick('immolation_trap','place the separate Fire trap for durable melee pressure');if a then return a end
  end
  if c.settings.forever_traps~=false and c.aoe_safe and c.enemy_count>=F.multi_threshold(c)then a=c.pick('explosive_trap','in-combat Survival area damage');if a then return a end end
  return nil
 end
 a=F.open(c,e);if a then return a end
 if c.burst then a=c.pick('rapid_fire','accelerate ranged attacks while closing');if a then return a end end
 a=F.burst_reset(c,{'rapid_fire'},'reset spent Survival ranged burst for a durable target');if a then return a end
 if c.aoe_safe and c.enemy_count>=F.multi_threshold(c)then a=c.pick('multi_shot','ranged cleave while closing');if a then return a end end
 if not c.ranged_cast_safe or c.ranged_cast_safe(c.cast_time('aimed_shot'))then a=c.pick('aimed_shot','safe ranged damage while melee is unavailable');if a then return a end end
 if F.can_spend(c,'arcane_shot',35)then return c.pick('arcane_shot','spend mana while closing')end
end
return R
