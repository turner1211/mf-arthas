local F=require('hh_forever_common');local U=require('hh_util');local R={spec=253}
function R.decide(c,e)
 if c.spec~=253 then return end
 local distance=U.distance(c.player,c.target)
 if distance<8 then return c.pick('raptor_strike','BM dead-zone melee fallback')end
 local a=F.open(c,e);if a then return a end
 if c.burst then a=c.pick('bestial_wrath','Forever BM offensive window');if a then return a end end
 if c.burst then a=c.pick('rapid_fire','accelerate BM ranged and pet pressure window');if a then return a end end
 a=F.burst_reset(c,{'bestial_wrath','rapid_fire'},'reset spent BM burst abilities for a durable target');if a then return a end
 if c.settings.forever_hawk~=false and F.hawks(c,e)<2 and F.can_spend(c,'summon_hawk',20)then
  a=c.pick('summon_hawk','build or refresh the two-Hawk limit');if a then return a end
 end
 -- Current level-30 BM simulation uses Multi-Shot on cooldown even in single
 -- target. Its weapon hit beats Aimed Shot for BM and still respects AoE safety.
 if c.aoe_safe and(not c.pvp or c.enemy_count>=F.multi_threshold(c))then a=c.pick('multi_shot','sim-backed Forever BM weapon shot');if a then return a end end
 if not c.ranged_cast_safe or c.ranged_cast_safe(c.cast_time('aimed_shot'))then a=c.pick('aimed_shot','safe Forever BM weapon-damage cast');if a then return a end end
 if F.can_spend(c,'arcane_shot',35)then return c.pick('arcane_shot','spend mana without starving Hawk and Sting')end
end
return R
