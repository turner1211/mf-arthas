local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=64 or not c.settings.damage then return end
 local a;local level=c.level and c.level>0 and c.level or 60;local fingers=c.stacks(S.aura.fingers);local winter=c.stacks(S.aura.winter_chill,true)
 local aoe_budget=(c.mana_pct or 100)>=35 or(c.ttd or math.huge)<=6
 if level<20 and not c.known('ice_lance')then
  if c.moving or c.execute then return c.pick('fire_blast',c.execute and'level-aware early Frost finisher'or'level-aware early Frost movement damage')end
  a=c.pick('frostbolt','level-aware pre-Ice-Lance Frost kiting filler');if a then return a end
  return c.pick('fireball','level one to three filler before Frostbolt is trained')
 end
 if c.settings.frost_freezing and (fingers>0 or c.target_frozen)then a=c.pick('ice_lance',c.target_frozen and'Ice Lance while Forever target is frozen'or'consume Forever Fingers of Frost');if a then return a end end
 if winter>=5 and c.aoe_safe and aoe_budget then a=c.pick('cone_of_cold','consume five redesigned Winter\'s Chill stacks when learned');if a then return a end end
 if winter==4 and not c.moving then a=c.pick('frost_blast','quickly build the fifth Winter\'s Chill stack for Cone of Cold');if a then return a end end
 if c.settings.frost_blizzard and c.aoe_safe and aoe_budget and c.enemy_count>=5 and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('blizzard','Forever five-target Blizzard with escape mana reserved');if a then return a end end
 if c.aoe_safe and aoe_budget and c.enemy_count>=3 then a=c.pick('cone_of_cold','Forever close cone damage with escape mana reserved');if a then return a end end
 if aoe_budget and c.enemy_count>=3 and (not c.aoe_safe or c.pvp and not require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_explosion','Forever instant area fallback when Blizzard cannot be safely channeled');if a then return a end end
 if c.moving or c.execute then return c.pick('fire_blast',c.execute and'Forever instant low-health finisher'or'Forever movement damage')end
 if c.pvp and c.target_slowed==false then a=c.pick('frost_blast','apply the fast nine-second PvP slow before a longer Frost cast');if a then return a end end
 if not c.pvp then a=c.pick('fire_blast','Forever Frost PvE Fire Blast cooldown damage');if a then return a end end
 if c.known('frostfire_bolt')then a=c.pick('frostfire_bolt','Forever learned Frostfire hybrid filler');if a then return a end end
 return c.pick('frostbolt','Forever Frost filler and Fingers generation')
end
return R
