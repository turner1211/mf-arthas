local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=62 or not c.settings.damage then return end
 local a;local level=c.level and c.level>0 and c.level or 60;local stacks=c.stacks(S.aura.arcane_charge);local _,stack_left=c.buff(S.aura.arcane_charge);local barrage=c.buff(S.aura.missile_barrage)==true
 local aoe_budget=(c.mana_pct or 100)>=35 or(c.ttd or math.huge)<=6
 if c.burst then a=c.pick('arcane_power','Forever Arcane Power damage window');if a then return a end end
 if c.burst and not c.moving then a=c.pick('presence','Forever instant cast burst setup');if a then return a end end
 if c.aoe_safe and c.enemy_count>=3 and aoe_budget then a=c.pick('arcane_explosion','Forever three-target Arcane area damage with escape mana reserved');if a then return a end end
 if c.settings.arcane_missiles and barrage and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_missiles','consume Forever Missile Barrage in protected channel space');if a then return a end end
 if level<20 and not c.known('arcane_blast')then
  local free=c.buff(S.aura.clearcasting)==true
  local finish=(c.ttd or math.huge)<=8 and (c.mana_pct or 0)>=55
  if c.settings.arcane_missiles and not c.moving and (free or finish)and (not c.pvp or require('sm_pvp').channel_safe(c,3000))then a=c.pick('arcane_missiles',free and'level-aware free early Arcane Missiles'or'level-aware early Arcane Missiles kill sequence');if a then return a end end
  if not c.moving then a=c.pick('frostbolt','level-aware early Mage filler');if a then return a end;a=c.pick('fireball','level one to three filler before Frostbolt is trained');if a then return a end end
  return c.pick('fire_blast','level-aware early Mage movement damage')
 end
 if c.buff(S.aura.clearcasting)==true and not c.moving then a=c.pick('arcane_blast','use free Arcane Blast to build or refresh the Forever power window');if a then return a end end
 if c.mana_pct and c.mana_pct<(c.settings.arcane_reserve or 40)and not c.moving then a=c.pick('frostbolt','preserve mana instead of extending the costly Arcane Blast ramp');if a then return a end end
 -- October 15: Arcane Blast now grants a four-stack, 15-second spell-damage
 -- window which is not consumed by another damage spell. Build all four
 -- stacks, refresh only near expiry, and use Missiles inside the window.
 if not c.moving and (stacks<4 or stacks>=4 and stack_left and stack_left<=2.2)then a=c.pick('arcane_blast',stacks<4 and'build the four-stack Forever Arcane Blast window'or'refresh expiring Forever Arcane Blast window');if a then return a end end
 if c.settings.arcane_missiles and stacks>=4 and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_missiles','channel Arcane Missiles inside the four-stack damage window');if a then return a end end
 if not c.moving then if c.settings.arcane_missiles then a=c.pick('arcane_missiles','Forever Arcane Missiles filler');if a then return a end end;a=c.pick('frostbolt','efficient filler while preserving the Arcane Blast window');if a then return a end end
 return c.pick('fire_blast',c.execute and'Forever instant finisher'or'Forever movement damage')
end
return R
