local S=require('hh_spells');local R={spec=255}
function R.decide(c,e)
 if c.spec~=255 then return nil end
 local a;local tip,_,stacks=c.buff(S.aura.tip)
 if c.debuff(S.aura.hunter_mark)==false and (not c.pvp or c.focus and c.focus>=70) then
  a=c.pick('hunters_mark','apply missing Hunter’s Mark');if a then return a end
 end
 local visible=tip==true and stacks~=nil or tip==false and stacks==0
 local low=not visible or stacks<2
 local prepared=e.last_action=='sv_kill_command' and c.now-(e.history.sv_kill_command or -math.huge)<3
 local twin=c.talent('twin_fangs')
 local howl=c.buff(S.aura.howl_wyvern)==true or c.buff(S.aura.howl_boar)==true or c.buff(S.aura.howl_bear)==true
 local arena_prep=c.mode=='arena' and c.kill_intent and not c.burst
 local bomb_recent=c.now-(e.history.wildfire_bomb or -math.huge)<6
 if arena_prep and tip==true and (stacks or 0)>=1 and not bomb_recent and c.settings.sv_bombs~=false then
  a=c.pick('wildfire_bomb','prime Survival damage before the healer control chain');if a then return a end
 end
 if c.settings.sv_tip~=false and (visible or not prepared)
  and (howl and low or not twin and c.cd('takedown')<=(c.gcd_duration or 1.5) and low) then
  a=c.pick('sv_kill_command','prepare Pack Leader summon or Takedown Tip stacks');if a then return a end
 end
 if visible and (not twin and stacks>=1 or twin and stacks==0) then
  a=c.pick('takedown','Takedown with the correct Twin Fangs setup');if a then return a end
 end
 -- Unknown aura data is not a zero-stack observation. A confirmed preparation
 -- may proceed through native usability rather than issuing Kill Command forever.
 if not visible and prepared then
  a=c.pick('takedown','available Takedown after confirmed preparation with hidden Tip data');if a then return a end
 end
 if (not visible and not prepared or visible and stacks==0) and c.settings.sv_tip~=false then a=c.pick('sv_kill_command','build Tip of the Spear before empowered attacks');if a then return a end end
 local bomb_fractional=math.max(c.charges('wildfire_bomb'),c.fractional and c.fractional('wildfire_bomb') or 0)
 if c.settings.sv_bombs~=false and bomb_fractional>=1.8 then a=c.pick('wildfire_bomb','avoid imminent Wildfire charge waste');if a then return a end end
 -- Sentinel single-target and PvP must not park major attacks on hidden Tip data.
 local direct_pressure=c.pvp or c.talent('sentinel') and c.enemy_count<3
 local calibrated_single=not c.pvp and not c.talent('sentinel') and c.enemy_count<3 and c.talent('lethal_calibration')
 if tip==true or direct_pressure or prepared then
  if not c.pvp and not c.talent('sentinel') and c.enemy_count<3 and c.settings.sv_bombs~=false and not c.talent('lethal_calibration') then
   a=c.pick('wildfire_bomb','Pack Leader single-target empowered bomb priority');if a then return a end
  end
  if c.settings.sv_boomstick~=false then a=c.pick('boomstick','Tip-empowered Boomstick');if a then return a end end
  if c.settings.sv_chakram~=false and c.talent('sentinel') then a=c.pick('moonlight_chakram','Tip-empowered Sentinel chakram');if a then return a end end
  if c.settings.sv_bombs~=false and not calibrated_single then a=c.pick('wildfire_bomb','Tip-empowered safe bomb');if a then return a end end
 end
 local strike_cost=c.cost and c.cost('raptor_strike') or 30
 if c.focus and c.focus>=strike_cost then
  a=c.pick('raptor_strike','Survival melee spender with runtime Eagle override');if a then return a end
 end
 if calibrated_single and (tip==true or prepared) and c.settings.sv_bombs~=false then
  a=c.pick('wildfire_bomb','Lethal Calibration empowered bomb after available melee spender');if a then return a end
 end
 if not visible or stacks<2 then a=c.pick('sv_kill_command','focus and Tip generation without wasting Tip stacks');if a then return a end end
 if c.settings.sv_bombs~=false then a=c.pick('wildfire_bomb','safe ranged Survival fallback');if a then return a end end
 return c.pick('takedown','native-eligible sustained Takedown fallback after damage priorities')
end
return R
