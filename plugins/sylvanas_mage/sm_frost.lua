local S=require('sm_spells');local R={}
function R.decide(c,e)
 if c.spec~=64 or not c.settings.damage then return end
 if c.pvp then return require('sm_frost_pvp').decide(c,e)end
 local a;local ff=c.talent('frostfire');local fingers=c.stacks(S.aura.fingers);local ice=c.stacks(S.aura.icicles)
 local freezing=c.stacks(S.aura.freezing,true);local thermal=c.buff(S.aura.thermal_void)==true
 if c.settings.frost_ray and c.charges('ray')>=2 then a=c.pick('ray','prevent Ray charge overflow');if a then return a end end
 if ff and c.settings.frost_spike and c.buff(S.aura.glacial_spike)==true then a=c.pick('glacial_spike','current Glacial Spike proc');if a then return a end end
 if not ff and c.aoe_safe and (not c.pvp or c.burst)then a=c.pick('comet_storm','Spellslinger Comet priority');if a then return a end end
 if c.buff(S.aura.brain)==true and not thermal then a=c.pick('flurry','spend Brain Freeze before another proc');if a then return a end end
 if fingers>=2 then a=c.pick('ice_lance','avoid Fingers of Frost overflow');if a then return a end end
 if ff and c.aoe_safe and (not c.pvp or c.burst) and (c.enemy_count<=2 or e.previous_action=='glacial_spike')then
  a=c.pick('comet_storm','Frostfire Comet after Icicle spending');if a then return a end
 end
 if ff and not c.talent('hand_final') and c.settings.frost_ray and (not c.pvp or c.burst and c.attackers==0)then
  a=c.pick('ray','Frostfire Ray before Orb without final Apex');if a then return a end
 end
 if c.settings.frost_orb and (not c.pvp or c.burst)then a=c.pick('frozen_orb','safe Orb path');if a then return a end end
 if not ff and c.settings.frost_spike and c.buff(S.aura.glacial_spike)==true then a=c.pick('glacial_spike','Spellslinger Spike after Orb');if a then return a end end
 local rain=c.buff(S.aura.freezing_rain)==true
 local blizzard_n=(ff and 8 or 7)-(c.talent('freezing_winds') and (ff and 3 or 2) or 0)-(c.talent('freezing_rain') and 2 or 0)
 if c.settings.frost_blizzard and c.aoe_safe and not c.pvp and (ff and (c.enemy_count>=blizzard_n or rain and c.enemy_count>=3)
  or not ff and rain and c.enemy_count>=(5-(c.talent('freezing_winds') and 2 or 0)))then
  a=c.pick('blizzard','safe area damage above hero threshold');if a then return a end
 end
 if c.settings.frost_freezing and (freezing>=(ff and 12 or 6) or fingers>0 and (not ff or thermal or c.moving))then
  a=c.pick('ice_lance','spend Freezing or eligible Fingers proc');if a then return a end
 end
 if ff and c.buff(S.aura.frostfire_empowerment)==true and c.enemy_count>=3 then a=c.pick('frostfire_bolt','spend empowerment before channel');if a then return a end end
 local cone_targets=ff and 5 or 4
 if c.talent('cone_of_frost') and c.charges('ray')>=1 and c.enemy_count>=cone_targets
  and (not ff or c.buff(S.aura.frostfire_empowerment)~=true)then
  if c.settings.frost_ice_nova then a=c.pick('ice_nova','Cone of Frost multi-target Ice Nova');if a then return a end end
  if c.settings.frost_cone then a=c.pick('cone_of_cold','Cone of Frost directional multi-target damage');if a then return a end end
 end
 if c.settings.frost_ray and (not c.pvp or c.burst and c.attackers==0) and (ff and (c.enemy_count<=2 or c.buff(S.aura.frostfire_empowerment)~=true) or not ff and (ice<=3 or c.enemy_count>=3) or c.charges('ray')>=2)then
  a=c.pick('ray','complete Ray channel without clipping');if a then return a end
 end
 a=c.pick('flurry','available Flurry charge');if a then return a end
 if not ff and c.settings.frost_blizzard and c.aoe_safe and c.enemy_count>=blizzard_n then
  a=c.pick('blizzard','Spellslinger hardcast area filler');if a then return a end
 end
 if c.settings.frost_spike and ice>=5 then a=c.pick('glacial_spike','consume full Icicles');if a then return a end end
 if ff then a=c.pick('frostfire_bolt','Frostfire filler');if a then return a end end
 a=c.pick('frostbolt','build Icicles and Freezing');if a then return a end
 if c.moving then
  if c.settings.frost_blizzard and rain then a=c.pick('blizzard','instant Freezing Rain movement fallback');if a then return a end end
  if c.talent('cone_of_frost')then
   if c.settings.frost_ice_nova then a=c.pick('ice_nova','Ice Nova movement fallback');if a then return a end end
   if c.settings.frost_cone then a=c.pick('cone_of_cold','directional Cone movement fallback');if a then return a end end
  end
  return c.pick('ice_lance','instant movement filler')
 end
end
return R
