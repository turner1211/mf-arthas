local S=require('ww_spells');local R={spec=73}
local function since(engine,c,key)return c.now-(engine.target_history[key..':'..tostring(c.target_guid)]or-math.huge)end
local function due(engine,c,key,aura,refresh)local active,left=c.debuff(aura);return active==true and left and left<=refresh or active~=true and since(engine,c,key)>refresh end
function R.mitigation(c)
 if c.spec~=73 or not c.settings.defensives then return end
 local low=math.min(c.hp or 100,c.predicted_hp or c.hp or 100)
 if low<=20 then return c.pick('shield_wall','Forever Protection lethal-pressure Shield Wall')or c.pick('last_stand','Forever Protection emergency Last Stand')end
 if low<=40 then return c.pick('last_stand','Forever Protection early Last Stand health buffer')end
 local block,left=c.buff(S.aura.shield_block)
 if c.physical and c.attackers>0 and(block~=true or left and left<=1.5)then return c.pick('shield_block','Forever Protection maintain two-block physical mitigation')end
end
function R.decide(c,engine)
 if c.spec~=73 or not c.settings.damage then return end
 local a
 if c.buff(S.aura.victorious)==true and c.hp and c.hp<c.settings.heal_hp then a=c.pick('victory_rush','Forever Protection consume Victorious healing');if a then return a end end
 -- Revenge is cheap, enhanced in Forever, and expires after the avoidance proc.
 a=c.pick('revenge','Forever Protection consume Revenge proc');if a then return a end
 local aoe=c.aoe_safe and c.enemy_count>=2
 if aoe and due(engine,c,'thunder_clap',S.aura.thunder_clap,3)then a=c.pick('thunder_clap','Forever Protection establish pack threat and attack-speed slow');if a then return a end end
 a=c.pick('shield_slam','Forever Protection high-threat Shield Slam when learned');if a then return a end
 if not aoe and c.attackers>0 and due(engine,c,'thunder_clap',S.aura.thunder_clap,3)then
  a=c.pick('thunder_clap','Forever Protection maintain single-target attack-speed slow');if a then return a end
 end
 if c.attackers>0 and due(engine,c,'demoralizing_shout',S.aura.demoralizing_shout,4)then a=c.pick('demoralizing_shout','Forever Protection reduce pack damage');if a then return a end end
 local _,_,stacks=c.debuff(S.aura.sunder)
 local wanted=(c.mode=='dungeon'or c.mode=='raid')and((c.level or 60)<30 and 3 or 5)or 2
 if(not stacks or stacks<wanted)and since(engine,c,'sunder_armor')>2 then a=c.pick('sunder_armor','Forever Protection build target threat and armor reduction');if a then return a end end
 if(stacks or 0)>=wanted and due(engine,c,'rend',S.aura.rend,4)and(not c.ttd or c.ttd>9)then
  a=c.pick('rend','Forever Protection add Rend after primary threat is secure');if a then return a end
 end
 if c.target_hp and c.target_hp<=20 and(c.rage or 0)>=35 and c.solo then a=c.pick('execute','Forever Protection solo execute');if a then return a end end
 if aoe and c.recovery_target then a=c.pick('challenging_shout','Forever Protection emergency pack recovery');if a then return a end end
 if c.buff(S.aura.victorious)==true then a=c.pick('victory_rush','Forever Protection spend Victorious proc for damage');if a then return a end end
 local discount=c.talent('focused_rage')and 3 or 0
 if aoe and(c.rage or 0)>=75-discount then a=c.pick('cleave','Forever Protection excess-Rage queued pack threat');if a then return a end end
 if(c.rage or 0)>=75-discount then return c.pick('heroic_strike','Forever Protection excess-Rage queued threat')end
end
return R
