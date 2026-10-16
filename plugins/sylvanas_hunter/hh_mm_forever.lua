local F=require('hh_forever_common');local U=require('hh_util');local R={spec=254}
function R.decide(c,e)
 if c.spec~=254 then return end
 local distance=U.distance(c.player,c.target)
 if distance<8 then
  local a=F.melee_aspect(c,'switch to dodge aspect before the MM dead-zone trade');if a then return a end
  return c.pick('raptor_strike','MM dead-zone melee fallback')
 end
 local a=F.pvp_tracking(c,e);if a then return a end
 a=F.open(c,e);if a then return a end
 if F.level(c,25)then a=F.aspect(c,'trueshot_aura',require('hh_spells').aura.trueshot,'maintain party ranged attack power');if a then return a end end
 if F.pet_first(c,e)then return end
 if F.rapid_fire(c)then a=c.pick('rapid_fire','Forever MM attack-speed window');if a then return a end end
 -- Sniper Shot is a four-second setup cast and can lose damage in ordinary PvE.
 -- Reserve it for deliberate burst/opening windows with room to complete it.
 if F.level(c,40)and c.settings.forever_sniper~=false and c.burst and c.attackers==0 and distance>=20
  and (not c.ranged_cast_safe or c.ranged_cast_safe(c.cast_time('sniper_shot')))
  and (not c.ttd or c.ttd>=8) and F.can_spend(c,'sniper_shot',20)then
  a=c.pick('sniper_shot','stationary long-range burst setup');if a then return a end
 end
 -- Aimed Shot and Multi-Shot share a cooldown in Forever. Spend that cooldown
 -- on Multi-Shot only when three or more safe targets make it worthwhile.
 if F.level(c,18)and c.aoe_safe and c.enemy_count>=F.multi_threshold(c)then a=c.pick('multi_shot','shared-cooldown multi-target choice');if a then return a end end
 if F.level(c,20)and(not c.ranged_cast_safe or c.ranged_cast_safe(c.cast_time('aimed_shot')))then a=c.pick('aimed_shot','safe shared-cooldown single-target choice');if a then return a end end
 a=F.burst_reset(c,{'rapid_fire'},'reset Forever Hunter cooldowns for a committed MM burst');if a then return a end
 if F.level(c,6)and F.can_spend(c,'arcane_shot',30)then return c.pick('arcane_shot','spend excess mana')end
end
return R
