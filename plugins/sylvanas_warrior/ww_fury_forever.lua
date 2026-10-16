local S=require('ww_spells');local R={spec=72}
local function since(engine,c,key)return c.now-(engine.target_history[key..':'..tostring(c.target_guid)]or-math.huge)end
local function due(engine,c,key,aura,refresh)local active,left=c.debuff(aura);return active==true and left and left<=refresh or active~=true and since(engine,c,key)>refresh end
function R.decide(c,engine)
 if c.spec~=72 or not c.settings.damage then return end
 local a;local pvp=c.pvp==true
 if c.buff(S.aura.victorious)==true and c.hp and c.hp<c.settings.heal_hp then a=c.pick('victory_rush','Forever Fury consume Victorious healing');if a then return a end end
 if pvp and due(engine,c,'hamstring',S.aura.hamstring,4)then a=c.pick('hamstring','Forever Fury maintain PvP slow');if a then return a end end
 local low=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 if c.settings.cooldowns and c.burst and(c.rage or 0)>=35 and low>45 then a=c.pick('death_wish','Forever Fury Death Wish window')or c.pick('recklessness','Forever Fury Recklessness window');if a then return a end end
 if c.target_hp and c.target_hp<=20 and((c.rage or 0)>=35 or pvp or c.ttd and c.ttd<=3)then a=c.pick('execute','Forever Fury execute without wasting pooled Rage');if a then return a end end
 if due(engine,c,'rend',S.aura.rend,4)and(not c.ttd or c.ttd>9)then a=c.pick('rend','Forever Fury maintain Rend');if a then return a end end
 a=c.pick('overpower','Forever Fury consume reactive Overpower');if a then return a end
 a=c.pick('bloodthirst','Forever Fury primary strike when learned');if a then return a end
 if pvp and c.physical and c.enemy_count>=2 and due(engine,c,'thunder_clap',S.aura.thunder_clap,3)then
  a=c.pick('thunder_clap','Forever Fury slow multiple melee attackers');if a then return a end
 end
 -- Current level-30 guidance values Sunder while a healthy target will live
 -- long enough to repay its Rage cost. Keep it below reactive/core attacks.
 local _,_,stacks=c.debuff(S.aura.sunder);local wanted=5
 if(c.target_hp or 0)>70 and(not c.ttd or c.ttd>15)and(not stacks or stacks<wanted)
  and(c.rage or 0)>=25 and since(engine,c,'sunder_armor')>2 then
  a=c.pick('sunder_armor','Forever Fury armor reduction on a durable target');if a then return a end
 end
 if c.talent('improved_slam')and(c.rage or 0)>=30 then a=c.pick('slam','Forever Fury Improved Slam on cooldown');if a then return a end end
 local aoe=c.aoe_safe and c.enemy_count>=2
 if aoe and(c.rage or 0)>=35 then a=c.pick('whirlwind','Forever Fury safe area strike')or c.pick('cleave','Forever Fury safe queued cleave');if a then return a end end
 if due(engine,c,'demoralizing_shout',S.aura.demoralizing_shout,4)and c.attackers>0 then a=c.pick('demoralizing_shout','Forever Fury reduce incoming melee damage');if a then return a end end
 if c.just_swung==true and(c.rage or 0)>=50 then a=c.pick('slam','Forever Fury post-swing Slam');if a then return a end end
 if c.buff(S.aura.victorious)==true then a=c.pick('victory_rush','Forever Fury spend Victorious proc for damage');if a then return a end end
 local dump=(c.target_hp or 100)<=25 and 85 or 70
 if(c.rage or 0)>=dump then return c.pick('heroic_strike','Forever Fury excess-Rage queued attack')end
end
return R
