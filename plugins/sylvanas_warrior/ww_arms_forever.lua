local S=require('ww_spells');local R={spec=71}
local function since(engine,c,key)return c.now-(engine.target_history[key..':'..tostring(c.target_guid)]or-math.huge)end
local function due(engine,c,key,aura,refresh)
 local active,left=c.debuff(aura);return active==true and left and left<=refresh or active~=true and since(engine,c,key)>refresh
end
function R.decide(c,engine)
 if c.spec~=71 or not c.settings.damage then return end
 local a;local pvp=c.pvp==true
 if c.buff(S.aura.victorious)==true and c.hp and c.hp<c.settings.heal_hp then a=c.pick('victory_rush','Forever Arms consume Victorious healing');if a then return a end end
 if pvp and due(engine,c,'hamstring',S.aura.hamstring,4)then a=c.pick('hamstring','Forever Arms maintain PvP slow');if a then return a end end
 if c.target_hp and c.target_hp<=20 and((c.rage or 0)>=30 or pvp or c.ttd and c.ttd<=3)then a=c.pick('execute','Forever Arms execute window');if a then return a end end
 if due(engine,c,'rend',S.aura.rend,4)and(not c.ttd or c.ttd>9)then a=c.pick('rend','Forever Arms maintain Rend');if a then return a end end
 local aoe=c.aoe_safe and c.enemy_count>=2
 -- Sweeping Strikes must precede the reactive Overpower it will duplicate.
 if aoe and c.settings.cooldowns and c.burst and(c.rage or 0)>=30 and c.ready('overpower')then
  a=c.pick('sweeping_strikes','Forever Arms pair Sweeping Strikes with reactive Overpower');if a then return a end
 end
 -- Overpower is reactive and expires; never bury it below ordinary spenders.
 a=c.pick('overpower','Forever Arms consume reactive Overpower');if a then return a end
 if due(engine,c,'thunder_clap',S.aura.thunder_clap,3)and(c.attackers>0 or c.solo)then a=c.pick('thunder_clap','Forever Arms reduce enemy attack speed');if a then return a end end
 if pvp and c.physical and c.attackers>=2 and due(engine,c,'demoralizing_shout',S.aura.demoralizing_shout,4)then
  a=c.pick('demoralizing_shout','Forever Arms reduce multi-melee PvP pressure');if a then return a end
 end
 local _,_,stacks=c.debuff(S.aura.sunder);local wanted=5
 if(not stacks or stacks<wanted)and(not c.ttd or c.ttd>12)and(c.rage or 0)>=25 then a=c.pick('sunder_armor','Forever Arms build useful Sunder stacks');if a then return a end end
 a=c.pick('spearing_strike','Forever Arms talented weapon strike');if a then return a end
 a=c.pick('mortal_strike','Forever Arms primary strike when learned');if a then return a end
 if c.talent('improved_slam')and(c.rage or 0)>=30 then a=c.pick('slam','Forever Arms Improved Slam on cooldown');if a then return a end end
 if aoe and(c.rage or 0)>=35 then a=c.pick('cleave','Forever Arms safe queued cleave')or c.pick('whirlwind','Forever Arms safe area attack');if a then return a end end
 -- Slam is only safe as a post-swing filler when the host exposes swing data;
 -- without that signal, keep enough Rage for the priority list above.
 if c.just_swung==true and(c.rage or 0)>=45 then a=c.pick('slam','Forever Arms post-swing Slam');if a then return a end end
 if c.buff(S.aura.victorious)==true then a=c.pick('victory_rush','Forever Arms spend Victorious proc for damage');if a then return a end end
 local dump=(c.target_hp or 100)<=25 and 85 or 70
 if(c.rage or 0)>=dump then return c.pick('heroic_strike','Forever Arms excess-Rage queued attack')end
end
return R
