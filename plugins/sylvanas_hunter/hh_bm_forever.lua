local F=require('hh_forever_common');local U=require('hh_util');local R={spec=253}
function R.decide(c,e)
 if c.spec~=253 then return end
 local distance=U.distance(c.player,c.target)
 if distance<8 then
  local a=F.melee_aspect(c,'switch to dodge aspect before the BM dead-zone trade');if a then return a end
  return c.pick('raptor_strike','BM dead-zone melee fallback')
 end
 local a=F.pvp_tracking(c,e);if a then return a end
 a=F.open(c,e);if a then return a end
 if F.level(c,40)and c.burst then a=c.pick('bestial_wrath','Forever BM offensive window');if a then return a end end
 if F.pet_first(c,e)then return end
 if F.rapid_fire(c)then a=c.pick('rapid_fire','sim-backed Forever BM attack-speed window below 95% mana');if a then return a end end
 a=F.burst_reset(c,{'bestial_wrath','rapid_fire'},'reset spent BM burst abilities for a durable target');if a then return a end
 if F.level(c,25)and c.settings.forever_hawk~=false and F.hawks(c,e)<2 and F.can_spend(c,'summon_hawk',20)then
  a=c.pick('summon_hawk','build or refresh the two-Hawk limit');if a then return a end
 end
 -- Current level-30 BM simulation uses Multi-Shot on cooldown even in single
 -- target, then Arcane Shot as filler. Aimed Shot is not worth its cast here.
 if F.level(c,18)and c.aoe_safe and(not c.pvp or c.enemy_count>=F.multi_threshold(c))then a=c.pick('multi_shot','sim-backed Forever BM weapon shot');if a then return a end end
 if F.level(c,6)and F.can_spend(c,'arcane_shot',35)then return c.pick('arcane_shot','spend mana without starving Hawk and Sting')end
end
return R
