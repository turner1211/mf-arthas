local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=63 or not c.settings.damage then return end
 local a;local level=c.level or 60;local hot=c.stacks(S.aura.hot_streak);local _,hot_left=c.buff(S.aura.hot_streak)
 local vulnerability=c.stacks(S.aura.fire_vulnerability,true)
 local short_pyro=hot>=3 or hot>=2 and (c.execute or hot_left and hot_left<=4 or c.pvp and not c.moving and require('sm_pvp').channel_safe(c,2000))
 -- October 15: every Fire Blast supplies one Heating Up charge (two on a
 -- critical). At two stacks, complete the quarter-cast Pyro setup first.
 if c.settings.fire_hot_streak and hot==2 then
  a=c.pick('fire_blast','complete three-stack Forever Heating Up before Pyroblast');if a then return a end
 end
 if c.settings.fire_hot_streak and short_pyro then
  a=c.pick('pyroblast',hot>=3 and'consume three-stack Forever Heating Up quarter-cast Pyroblast'or'consume two-stack Forever Heating Up before expiration or in protected PvP space');if a then return a end
 end
 if c.burst then a=c.pick('combustion','Forever Combustion damage window');if a then return a end end
 if level<10 then
  if not c.moving then a=c.pick('fireball','level-aware early Fire filler');if a then return a end end
  return c.pick('fire_blast','level-aware early Fire movement damage')
 end
 if c.talent('improved_scorch')and vulnerability<5 and not c.moving then a=c.pick('scorch','build five Forever Improved Scorch vulnerability stacks');if a then return a end end
 if c.aoe_safe and c.enemy_count>=(c.settings.fire_flamestrike or 3)then a=c.pick('blast_wave','Forever close area burst');if a then return a end;a=c.pick('flamestrike','Forever area damage');if a then return a end end
 if c.aoe_safe and c.enemy_count>=(c.settings.fire_flamestrike or 3)then a=c.pick('arcane_explosion','Forever instant area fallback after Fire area actions');if a then return a end end
 if c.execute then a=c.pick('fire_blast','Forever instant low-health finisher');if a then return a end end
 if c.moving then a=c.pick('fire_blast','Forever movement damage');if a then return a end;return c.pick('scorch','Forever mobile filler')end
 if c.known('frostfire_bolt')then a=c.pick('frostfire_bolt','Forever dual-school filler for learned hybrid build');if a then return a end end
 if not c.pvp then
  a=c.pick('fire_blast','Forever PvE Fire Blast cooldown damage');if a then return a end
  local burn=c.row_debuff and c.row_debuff('fireball')or false
  if burn==false or burn~=math.huge and burn<1.5 then a=c.pick('fireball','apply or refresh Forever Fireball burn');if a then return a end end
  if c.talent('improved_scorch')then a=c.pick('scorch','Forever improved Scorch sustained filler');if a then return a end end
 end
 a=c.pick('fireball','Forever Fire filler');if a then return a end
 -- A learned Frost spell keeps dealing damage when the Fire school is locked.
 return c.pick('frostbolt','Forever alternate-school filler while Fire is unavailable')
end
return R
