local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=64 or not c.settings.damage then return end
 local a;local level=c.level and c.level>0 and c.level or 60;local fingers=c.stacks(S.aura.fingers);local winter=c.stacks(S.aura.winter_chill,true)
 if level<20 then
  if c.moving or c.execute then return c.pick('fire_blast',c.execute and'level-aware early Frost finisher'or'level-aware early Frost movement damage')end
  return c.pick('frostbolt','level-aware pre-Ice-Lance Frost kiting filler')
 end
 if c.settings.frost_freezing and (fingers>0 or c.target_frozen)then a=c.pick('ice_lance',c.target_frozen and'Ice Lance while Forever target is frozen'or'consume Forever Fingers of Frost');if a then return a end end
 if level>=26 and winter>=5 and c.aoe_safe then a=c.pick('cone_of_cold','consume five redesigned Winter\'s Chill stacks');if a then return a end end
 if c.settings.frost_blizzard and c.aoe_safe and c.enemy_count>=5 and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('blizzard','Forever five-target Blizzard');if a then return a end end
 if c.aoe_safe and c.enemy_count>=3 then a=c.pick('cone_of_cold','Forever close cone damage');if a then return a end end
 if c.enemy_count>=3 and (not c.aoe_safe or c.pvp and not require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_explosion','Forever instant area fallback when Blizzard cannot be safely channeled');if a then return a end end
 if c.moving or c.execute then return c.pick('fire_blast',c.execute and'Forever instant low-health finisher'or'Forever movement damage')end
 if c.known('frostfire_bolt')then a=c.pick('frostfire_bolt','Forever learned Frostfire hybrid filler');if a then return a end end
 return c.pick('frostbolt','Forever Frost filler and Fingers generation')
end
return R
