local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=62 or not c.settings.damage then return end
 local a;local stacks=c.stacks(S.aura.arcane_charge);local _,stack_left=c.buff(S.aura.arcane_charge);local barrage=c.buff(S.aura.missile_barrage)==true
 if c.burst then a=c.pick('arcane_power','Forever Arcane Power damage window');if a then return a end end
 if c.burst and not c.moving then a=c.pick('presence','Forever instant cast burst setup');if a then return a end end
 if c.aoe_safe and c.enemy_count>=3 then a=c.pick('arcane_explosion','Forever three-target Arcane area damage');if a then return a end end
 if c.settings.arcane_missiles and barrage and (not c.pvp or require('sm_pvp').channel_safe(c,2500))then a=c.pick('arcane_missiles','consume Forever Missile Barrage in protected channel space');if a then return a end end
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
