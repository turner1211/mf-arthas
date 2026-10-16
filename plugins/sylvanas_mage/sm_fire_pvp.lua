local S,P=require('sm_spells'),require('sm_pvp');local R={}
function R.decide(c,e)
 if c.spec~=63 or not c.pvp or not c.settings.damage then return end
 local a;local hot=c.buff(S.aura.hot_streak)==true;local combustion=c.buff(S.aura.combustion)==true
 -- Meteor lands three seconds after the input. Query its stun window lazily
 -- so ordinary Fire damage ticks do not call the PvP control helper.
 local stun_checked,stunned=false,false
 local function meteor_stunned()
  if not stun_checked then stun_checked=true;stunned=P.control(c,c.target,'STUN',3200)end
  return stunned
 end
 local combustion_cd=c.cd('combustion');local blast_charges=c.fractional('fire_blast')
 if c.burst and not combustion and hot then
  if c.settings.fire_meteor and c.known('meteor') and meteor_stunned() and c.now-(e.history.meteor or -math.huge)>10 then a=c.pick('meteor','stunned PvP Meteor before Combustion');if a then return a end end
  local cast=c.player_cast
  local precast=cast and not cast.channel and (cast.id==133 or cast.id==431044 or cast.id==11366 or cast.id==2948)
  if not c.busy or precast and cast.left<=0.25 then a=c.pick('combustion','permitted PvP Combustion without Firestarter delay');if a then return a end end
 end
 -- During Combustion, preload Fire Blast while Hot Streak is still active.
 -- The following instant Pyro then consumes Hot Streak while the guaranteed
 -- Fire Blast crit carries the chain forward. The history guard prevents
 -- aura latency from spending a second charge before Pyro is observed.
 if combustion and hot and c.settings.fire_blast and c.now-(e.history.fire_blast or -math.huge)>0.45 then
  a=c.pick('fire_blast','Combustion Fire Blast preload before instant Pyroblast');if a then return a end
 end
 if c.settings.fire_hot_streak and (hot or c.buff(S.aura.hyperthermia)==true)then
  a=c.pick('pyroblast','immediate PvP Hot Streak pressure');if a then return a end
 end
 if c.settings.fire_blast and not hot and c.buff(S.aura.heating)==true and c.now-(e.history.fire_blast or -math.huge)>0.45 then
  local bank=not combustion and c.known('combustion') and combustion_cd<=12 and not c.burst
  if not bank or blast_charges>=2.85 then
   a=c.pick('fire_blast',bank and'prevent Fire Blast overcap while banking for Combustion'or'confirmed PvP Heating Up conversion');if a then return a end
  end
 end
 if c.burst and c.settings.fire_meteor and c.known('meteor') and meteor_stunned() then
  local _,left=c.buff(S.aura.combustion)
  if not combustion or left and left>2 then a=c.pick('meteor','stunned PvP impact window');if a then return a end end
 end
 if c.talent('frostfire') and c.buff(S.aura.frostfire_empowerment)==true then a=c.pick('frostfire_bolt','instant PvP Frostfire pressure');if a then return a end end
 if c.settings.fire_pyroclasm and c.buff(S.aura.pyroclasm)==true and not c.moving then
  local _,left=c.buff(S.aura.combustion)
  local cast_time=require('sm_util').number(require('sm_util').fn(core.spell_book.get_spell_cast_time,S.rows.pyroblast.id))
  local cast_safe=cast_time and cast_time>0 and P.channel_safe(c,math.ceil((cast_time+0.15)*1000))
  -- During Combustion, do not spend this hardcast while two or more Fire
  -- Blast charges are already available; preserving recharge value is worth
  -- more than forcing the proc into the active window.
  local charge_safe=not combustion or blast_charges<2
  if cast_safe and charge_safe and(not combustion or left and cast_time+0.15<left)then
   a=c.pick('pyroblast','Pyroclasm hardcast with verified full cast space');if a then return a end
  end
 end
 if c.moving or c.attackers>0 or c.buff(S.aura.heat_shimmer)==true or c.execute and c.talent('scald') or combustion and not c.talent('frostfire')then
  a=c.pick('scorch','PvP movement or guaranteed-crit filler');if a then return a end
 end
 if c.attackers>0 then return end
 if c.talent('frostfire')then a=c.pick('frostfire_bolt','PvP Frostfire filler');if a then return a end end
 return c.pick('fireball','PvP Heating Up builder')
end
return R
