local S,P=require('sm_spells'),require('sm_pvp');local R={}
function R.decide(c,e)
 if c.spec~=62 or not c.pvp or not c.settings.damage or c.arcane_charges==nil or not c.mana_pct then return end
 local a;local charges=c.arcane_charges;local surge=c.buff(S.aura.surge)==true;local touch=c.debuff(S.aura.touch)==true
 local clearcasting=c.buff(S.aura.clearcasting)==true;local prismatic=c.buff(S.aura.prismatic)==true
 local salvo=c.stacks(S.aura.salvo);local cumulative=c.stacks(S.aura.cumulative)
 local hardcast_checked,hardcast_safe=false,false
 local function has_hardcast_space()
  if not hardcast_checked then hardcast_checked=true;hardcast_safe=P.channel_safe(c,2500)end
  return hardcast_safe
 end
 if c.settings.arcane_recovery and c.mana_pct<10 and not surge and not touch and c.cd('arcane_surge')>10 then
  a=c.pick('evocation','PvP recovery away from active pressure');if a then return a end
 end
 -- Both Missiles and Prismatic Bolt expose the Arcane school. Require enough
 -- verified space to complete them. The current tier bonus rewards finishing
 -- Clearcasting Missiles before Bolt, whose proc lasts long enough to wait.
 -- Presence of Mind is committed here specifically to rebuild the burst
 -- sequence after Barrage. Consume both instant Arcane Blasts before Orb,
 -- Pulse, Explosion or Clearcasting can spend the short damage window.
 if c.burst and (surge or touch) and c.buff(S.aura.presence)==true and charges<4 then
  a=c.pick('arcane_blast','PvP Presence instant Blast burst rebuild');if a then return a end
 end
 if c.burst and (surge or touch) and charges==4 and not prismatic then
  a=c.pick('arcane_barrage','four-charge PvP Barrage inside Surge or Touch');if a then return a end
 end
 if c.settings.arcane_prismatic and prismatic and cumulative>=6 and has_hardcast_space() then
  a=c.pick('prismatic_bolt','PvP Prismatic Bolt at six-plus Cumulative Power with full cast space');if a then return a end
 end
 if c.settings.arcane_missiles and clearcasting and has_hardcast_space() then
  a=c.pick('arcane_missiles',prismatic and'PvP Clearcasting amplifies pending Prismatic Bolt'or c.burst and'PvP Clearcasting before committed burst'or'PvP Clearcasting before charge spender');if a then return a end
 end
 if c.settings.arcane_prismatic and prismatic and has_hardcast_space() then
  a=c.pick('prismatic_bolt','PvP Prismatic Bolt with verified full cast space at Cumulative '..cumulative..' Salvo '..salvo);if a then return a end
 end
 if c.burst and not surge and charges==4 and c.known('arcane_surge')
  and c.cd('arcane_surge')<=0.05 and not c.moving and not c.busy then
  local cast_time=require('sm_util').number(require('sm_util').fn(core.spell_book.get_spell_cast_time,S.rows.arcane_surge.id))or 2.5
  if cast_time>0 and P.channel_safe(c,math.ceil((cast_time+0.15)*1000))then
   a=c.pick('arcane_surge','four-charge PvP Arcane kill window with full live cast space');if a then return a end
  end
 end
 if c.burst and not touch then
  if surge then
   a=c.pick('touch','PvP Touch after Arcane Surge');if a then return a end
  elseif c.cd('arcane_surge')>30 then
   local manual=e.burst_requested
   local target_stunned=not manual and P.control(c,c.target,'STUN',1200)
   if manual or target_stunned then
    a=c.pick('touch',manual and'manual PvP Touch coordination'or'PvP Touch mini-go: stunned kill target and controlled healer');if a then return a end
   end
  end
 end
 if c.burst and (surge or touch) and charges<1 and e.last_action=='arcane_barrage'
  and c.buff(S.aura.presence)~=true then
  a=c.pick('presence','PvP burst rebuild after Barrage');if a then return a end
 end
 if charges==4 then
  a=c.pick('arcane_barrage','four-charge PvP spender');if a then return a end
 end
 if c.settings.arcane_salvo and (c.buff(S.aura.soul)==true or charges==4 and c.stacks(S.aura.salvo)>=(c.talent('sunfury') and 25 or 20))then
  a=c.pick('arcane_barrage','PvP Salvo spender');if a then return a end
 end
 if charges<4 then
  a=c.pick('arcane_orb','safe PvP charge generation');if a then return a end
  a=c.pick('arcane_pulse','safe targeted PvP charge generation');if a then return a end
  if c.attackers>0 and c.distance and c.distance<=8 then a=c.pick('arcane_explosion','close-range PvP charges without a hardcast');if a then return a end end
 end
 if not surge and not touch and c.mana_pct<=c.settings.arcane_reserve and charges>0 then a=c.pick('arcane_barrage','PvP mana conservation');if a then return a end end
 if c.moving and charges>0 then a=c.pick('arcane_barrage','instant damage while repositioning');if a then return a end end
 if c.moving and c.buff(S.aura.presence)~=true then a=c.pick('presence','PvP instant Blast preparation');if a then return a end end
 if c.attackers>0 then return end
 -- Arcane Blast is replaced while Prismatic is active. Do not let the generic
 -- filler bypass the full-cast safety decision above.
 if prismatic then return end
 return c.pick('arcane_blast','PvP charge and Salvo builder')
end
return R
