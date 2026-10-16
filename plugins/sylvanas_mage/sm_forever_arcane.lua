local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=62 or not c.settings.damage then return end
 local a;local level=c.level and c.level>0 and c.level or 60;local stacks=c.stacks(S.aura.arcane_charge);local _,stack_left=c.buff(S.aura.arcane_charge);local barrage=c.buff(S.aura.missile_barrage)==true
 local wrath=c.known('arcane_wrath');local stack_goal=c.burst and 4 or (c.mana_pct or 100)<25 and 1 or 2
 local aoe_budget=(c.mana_pct or 100)>=35 or(c.ttd or math.huge)<=6
 if c.burst then a=c.pick('arcane_power','Forever Arcane Power damage window');if a then return a end end
 -- Preserve Presence for Arcane Wrath once the burst stack window is ready.
 -- Before Wrath is learned, retain its normal instant Arcane Blast use.
 if c.burst and not c.moving and (not wrath or stacks>=stack_goal)then a=c.pick('presence',wrath and'prepare instant Arcane Wrath after completing the burst stack window'or'Forever instant Arcane Blast burst setup');if a then return a end end
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
 -- The persistent 15-second buff permits a mana-efficient two-stack cycle.
 -- Drop to one below 25% mana and climb to four only for a requested burst.
 if not c.moving and (stacks<stack_goal or stacks>=stack_goal and stack_left and stack_left<=2.2)then a=c.pick('arcane_blast',stacks<stack_goal and'build the adaptive Forever Arcane Blast window'or'refresh expiring Forever Arcane Blast window');if a then return a end end
 -- Arcane Wrath scales with maximum mana and can proc Missile Barrage. Cast it
 -- inside the completed Arcane Blast power window, but never expose a long
 -- PvP hardcast unless Presence of Mind or protected cast space is available.
 local presence=c.buff(S.aura.presence)==true
 if stacks>=stack_goal and not c.moving and (not c.pvp or presence or require('sm_pvp').channel_safe(c,3500))then
  a=c.pick('arcane_wrath','Forever Arcane Wrath inside the adaptive spell-power window');if a then return a end
 end
 if c.settings.arcane_missiles and stacks>=stack_goal and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_missiles','channel Arcane Missiles inside the adaptive damage window');if a then return a end end
 if not c.moving then if c.settings.arcane_missiles then a=c.pick('arcane_missiles','Forever Arcane Missiles filler');if a then return a end end;a=c.pick('frostbolt','efficient filler while preserving the Arcane Blast window');if a then return a end end
 return c.pick('fire_blast',c.execute and'Forever instant finisher'or'Forever movement damage')
end
return R
