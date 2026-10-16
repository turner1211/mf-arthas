local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=63 or not c.settings.damage then return end
 if c.pvp then return require('sm_fire_pvp').decide(c,e)end
 local a;local hot=c.buff(S.aura.hot_streak)==true;local combustion=c.buff(S.aura.combustion)==true
 local free=c.buff(S.aura.hyperthermia)==true
 local ff=c.talent('frostfire');local pyro=c.buff(S.aura.pyroclasm)==true
 local _,combustion_left=c.buff(S.aura.combustion)
 local flames=c.aoe_safe and not c.pvp and c.talent('fuel') and c.enemy_count>=math.max(3,c.settings.fire_flamestrike)
 local pyro_flames=flames
 local firestarter=c.talent('firestarter') and c.target_hp and c.target_hp>90
 local cast=c.player_cast
 local hardcast=cast and not cast.channel and cast.left and cast.left>0.1
 local combustion_cd=c.cd('combustion');local blast_charges=c.charges('fire_blast');local blast_max=c.max_charges('fire_blast')
 local bank_fire_blast=c.known('combustion') and combustion_cd>0.05 and combustion_cd<=12
  and blast_max>0 and blast_charges<blast_max
 local pyro_hardcast=hardcast and cast.id==S.rows.pyroblast.id and pyro
 local filler_hardcast=hardcast and (cast.id==S.rows.fireball.id or cast.id==S.rows.frostfire_bolt.id
  or pyro_hardcast or cast.id==S.rows.flamestrike.id or cast.id==S.rows.flamestrike_target.id)
 if firestarter and not combustion then flames=false end
 local hold_hot=ff and hot and not free and not combustion and c.burst and not firestarter
  and c.known('combustion') and c.cd('combustion')>0 and c.cd('combustion')<5 and not pyro and not c.moving
  and (not c.ttd or c.ttd>8)
 if c.settings.fire_hot_streak and (hot or free) and not hold_hot then
  if flames then a=c.pick('flamestrike','instant Hot Streak area spender');if a then return a end end
  a=c.pick('pyroblast','spend Hot Streak before generating another');if a then return a end
 end
 -- The current Fire APL protects a nearly full Fire Blast bank in Firestarter.
 -- Existing Hot Streak is deliberately handled first so this cannot waste a conversion.
 if c.settings.fire_blast and firestarter and not hot and c.fractional('fire_blast')>=2.9
  and c.now-(e.history.fire_blast or -math.huge)>0.45 then
  a=c.pick('fire_blast','prevent Firestarter Fire Blast charge overcap');if a then return a end
 end
 local blast_spacing=c.now-(e.history.fire_blast or -math.huge)>0.45
 if c.settings.fire_blast and not hot and pyro_hardcast and blast_spacing and not bank_fire_blast then
  a=c.pick('fire_blast','build Hot Streak during confirmed Pyroclasm hardcast');if a then return a end
 end
 if c.settings.fire_blast and not hot and c.execute and hardcast and cast.id==S.rows.scorch.id
  and c.buff(S.aura.heating)~=true and c.buff(S.aura.heat_shimmer)~=true and blast_spacing then
  a=c.pick('fire_blast','pair Fire Blast with execute Scorch critical');if a then return a end
 end
 local heating_window=combustion or free or filler_hardcast and not c.execute
  or firestarter and c.cd('combustion')<=0.05
 if c.settings.fire_blast and not hot and c.buff(S.aura.heating)==true and heating_window and blast_spacing and not bank_fire_blast then
  a=c.pick('fire_blast','convert Heating Up in a confirmed Fire Blast window');if a then return a end
 end
 local precast=cast and not cast.channel and (cast.id==S.rows.fireball.id or cast.id==S.rows.frostfire_bolt.id
  or cast.id==S.rows.pyroblast.id or cast.id==S.rows.scorch.id or cast.id==S.rows.flamestrike.id or cast.id==S.rows.flamestrike_target.id)
 local combustion_start=precast and cast.left<=0.25
 if c.burst and not combustion and combustion_start and (not firestarter or c.ttd and c.ttd<20)then
  a=c.pick('combustion','permitted Fire burst after spending proc');if a then return a end
 end
 if c.settings.fire_meteor and (not c.pvp or c.burst) then
  local _,left=c.buff(S.aura.combustion)
  local burnout=ff and c.talent('burnout')
  local meteor_window=combustion and left and left>2 and (not burnout or left<8)
   or not combustion and (ff and c.cd('combustion')>5 or c.talent('blast_zone') or not c.known('combustion'))
  if meteor_window then a=c.pick('meteor','safe impact during damage window');if a then return a end end
 end
 if c.settings.fire_pyroclasm and c.buff(S.aura.pyroclasm)==true and not c.moving then
  local _,left=c.buff(S.aura.combustion)
  local haste=require('sm_util').number(require('sm_util').call(c.player,'get_spell_haste'))
  local cast_time=require('sm_util').number(require('sm_util').fn(core.spell_book.get_spell_cast_time,S.rows.pyroblast.id))
   or haste and 4.5/(1+math.max(0,haste)/100) or nil
  local _,pyro_left=c.buff(S.aura.pyroclasm)
  local expires=pyro_left and cast_time and pyro_left<math.max(c.cd('combustion'),cast_time+0.3)
  local spend=not ff or c.stacks(S.aura.pyroclasm)>=2 or c.cd('combustion')>12 or expires
  if pyro_flames then
   local flame_time=require('sm_util').number(require('sm_util').fn(core.spell_book.get_spell_cast_time,e:resolve(S.rows.flamestrike)))
   if not combustion and spend or combustion and left and flame_time and flame_time>0 and flame_time+0.15<left then
    a=c.pick('flamestrike','Pyroclasm area cast within its own cast window');if a then return a end
   end
  end
  if combustion and left and cast_time and cast_time>0 and cast_time+0.15<left or not combustion and spend then
   a=c.pick('pyroblast','consume Pyroclasm before it expires');if a then return a end
  end
 end
 if c.buff(S.aura.heat_shimmer)==true or c.execute and c.talent('scald') or combustion and not ff or c.moving then a=c.pick('scorch','execute or movement filler');if a then return a end end
 if c.talent('frostfire')then a=c.pick('frostfire_bolt','Frostfire hero filler');if a then return a end end
 return c.pick('fireball','build Heating Up')
end
return R
