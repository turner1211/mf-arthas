local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=62 or not c.settings.damage then return end
 if c.pvp then return require('sm_arcane_pvp').decide(c,e)end
 local a;local salvo=c.stacks(S.aura.salvo);local charges=c.arcane_charges
 if charges==nil or not c.mana_pct then return end
 local surge,surge_left=c.buff(S.aura.surge);surge=surge==true;local touch=c.debuff(S.aura.touch)==true
 local sun=c.talent('sunfury');local aoe=c.aoe_safe and c.enemy_count>=(sun and 5 or 2)
 if c.ttd and c.ttd<3 and charges==4 then a=c.pick('arcane_barrage','finish a dying enemy');if a then return a end end
 if c.settings.arcane_recovery and c.mana_pct<10 and not surge and not touch and c.cd('arcane_surge')>10 and (not c.pvp or c.attackers==0)then
  a=c.pick('evocation','recover depleted mana outside damage windows');if a then return a end
 end
 if c.burst and not surge and c.talent('splintering') and charges<4 and not e.history.arcane_orb then
  a=c.pick('arcane_orb','Spellslinger opening charges before Surge');if a then return a end
 end
 if c.burst and not surge and (c.stacks(S.aura.lustrous)==0 or c.stacks(S.aura.lustrous)>=2) then a=c.pick('arcane_surge','permitted Arcane burst');if a then return a end end
 local since=c.now-(e.history.arcane_surge or -math.huge)
 if c.burst and not touch and (surge or c.cd('arcane_surge')>30)
  and (e.last_action=='prismatic_bolt' or e.last_action=='arcane_barrage' or surge and (surge_left and surge_left<12 or not surge_left and since>1.5))then
  a=c.pick('touch','align Touch after spender or Surge');if a then return a end
 end
 if charges<1 and e.last_action=='arcane_barrage' and c.buff(S.aura.prismatic)~=true
  and c.buff(S.aura.clearcasting)~=true and c.buff(S.aura.presence)~=true
  and not c.ready('arcane_orb') and not c.ready('arcane_pulse')
  and (not c.known('touch') or c.cd('touch')>0.05)then
  a=c.pick('presence','instant charge recovery after Barrage');if a then return a end
 end
 if not sun and c.settings.arcane_prismatic and c.buff(S.aura.prismatic)==true
  and (salvo>13 or aoe and c.stacks(S.aura.clearcasting)<3)then
  a=c.pick('prismatic_bolt',salvo>13 and 'Spellslinger Prismatic priority at high Salvo'
   or 'Spellslinger multi-target Prismatic before Clearcasting cap');if a then return a end
 end
 -- Sunfury has a different front of list: low-Salvo Clearcasting is spent first.
 if sun and c.settings.arcane_missiles and c.buff(S.aura.clearcasting)==true and salvo<12 then
  a=c.pick('arcane_missiles','Sunfury spends low-Salvo Clearcasting before Barrage');if a then return a end
 end
 -- The active eight-stack aura is positive proof of the tier-dependent Prismatic condition.
 if sun and c.settings.arcane_prismatic and c.buff(S.aura.prismatic)==true
  and c.stacks(S.aura.cumulative)>=8 and c.buff(S.aura.soul)~=true then
  a=c.pick('prismatic_bolt','Sunfury consumes capped Cumulative Power before Barrage');if a then return a end
 end
 if c.settings.arcane_salvo and (c.buff(S.aura.soul)==true or charges==4 and (salvo>=(sun and 25 or (20-(c.talent('orb_barrage') and 1 or 0))) or sun and salvo>=12 and (c.buff(S.aura.clearcasting)==true or aoe and (c.charges('arcane_orb')>=1 or c.charges('arcane_pulse')>=1))))then
  a=c.pick('arcane_barrage','spend Arcane Salvo with matching hero build');if a then return a end
 end
 if c.settings.arcane_missiles and c.buff(S.aura.clearcasting)==true and (salvo<(sun and 12 or 15) or c.stacks(S.aura.clearcasting)>=3)then
  a=c.pick('arcane_missiles','spend Clearcasting without clipping channel');if a then return a end
 end
 if c.settings.arcane_prismatic and c.buff(S.aura.prismatic)==true then a=c.pick('prismatic_bolt','consume current Prismatic Bolt replacement');if a then return a end end
 if charges<(aoe and not sun and 4 or 3) or not sun and c.talent('orb_mastery') and c.charges('arcane_orb')>=2 then a=c.pick('arcane_orb','rebuild charges through a clear path');if a then return a end end
 if not sun and charges<3 and not surge or sun and (charges<1 or c.aoe_safe and c.enemy_count>=4) then a=c.pick('arcane_pulse','rebuild charges with safe Arcane Pulse');if a then return a end end
 if not surge and not touch and c.mana_pct<=c.settings.arcane_reserve and charges>=3 then a=c.pick('arcane_barrage','conserve mana outside burst');if a then return a end end
 if c.moving and charges>0 then a=c.pick('arcane_barrage','instant movement damage');if a then return a end end
 if c.moving and c.buff(S.aura.presence)~=true then a=c.pick('presence','instant Arcane Blast while moving');if a then return a end end
 if c.pvp and c.target_hp and c.target_hp<=25 and charges==4 then a=c.pick('arcane_barrage','PvP execute pressure');if a then return a end end
 if c.ttd and c.ttd<3 and charges==4 then a=c.pick('arcane_barrage','finish a dying enemy');if a then return a end end
 return c.pick('arcane_blast','build charges and Salvo')
end
return R
