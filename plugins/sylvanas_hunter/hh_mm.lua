local S=require('hh_spells');local R={spec=254}
function R.decide(c,e)
 if c.spec~=254 then return nil end
 local a;local multi=c.aoe_safe and c.enemy_count>=3
 if c.debuff(S.aura.hunter_mark)==false and (not c.pvp or c.focus and c.focus>=70) then
  a=c.pick('hunters_mark','apply missing Hunter’s Mark');if a then return a end
 end
 local precise=c.buff(S.aura.precise)==true;local trick,left=c.buff(S.aura.trick)
 local trueshot,trueshot_left=c.buff(S.aura.trueshot)
 local dark=c.talent('black_arrow')
 if c.pvp then
  -- Instant empowered pressure comes before long casts in player combat.
  a=c.pick('black_arrow','PvP Dark Ranger arrow pressure');if a then return a end
  if precise and c.settings.mm_precise~=false then
   a=c.pick('kill_shot','PvP empowered execute shot');if a then return a end
   a=c.pick('arcane_shot','PvP consume Precise Shots before rebuilding');if a then return a end
  end
  if c.burst and c.settings.mm_volley~=false then a=c.pick('volley','PvP safe Volley burst setup');if a then return a end end
  if c.buff(S.aura.lock)==true then a=c.pick('aimed_shot','protect instant Lock and Load before the PvP burst sequence');if a then return a end end
  a=c.pick('rapid_fire','PvP mobile Rapid Fire pressure');if a then return a end
  if c.burst then a=c.pick('trueshot','PvP authorized Trueshot after the opening Rapid Fire');if a then return a end end
  if c.settings.mm_explosive~=false then a=c.pick('explosive_shot','PvP safe explosive pressure');if a then return a end end
  a=c.pick('aimed_shot','PvP precision pressure when able to cast');if a then return a end
  a=c.pick('wailing_arrow','PvP available Dark Ranger proc pressure');if a then return a end
  a=c.pick('kill_shot','PvP execute pressure');if a then return a end
  if c.settings.mm_chakram~=false and c.talent('sentinel') then a=c.pick('moonlight_chakram','PvP Sentinel pressure');if a then return a end end
  if c.settings.mm_volley~=false and multi then a=c.pick('volley','PvP safe grouped pressure');if a then return a end end
  if c.focus and c.focus>=80 then a=c.pick('arcane_shot','PvP focus overflow');if a then return a end end
  return c.pick('steady_shot','PvP focus recovery')
 end
 -- Dark Ranger's Precise Shots spender is Black Arrow and belongs ahead of
 -- Explosive Shot/Volley. Sentinel never enters this hero-tree-only branch.
 if precise and dark then a=c.pick('black_arrow','Dark Ranger Precise Shots spender');if a then return a end end
 local dungeon=c.mode=='dungeon' or c.mode=='mythic_plus'
 local explosive_first=not dungeon or not c.ready('rapid_fire') or c.buff(S.aura.unstable)==true
 if c.settings.mm_explosive~=false and explosive_first and (not c.talent('tactical_reload') or c.buff(S.aura.lock)~=true) then
  a=c.pick('explosive_shot','safe explosive damage');if a then return a end
 end
 if c.settings.mm_volley~=false then a=c.pick('volley','safe Volley damage and Trick Shots setup');if a then return a end end
 if multi then
  local aimed_time=c.cast_time and c.cast_time('aimed_shot') or 3
  if c.settings.mm_trick~=false and (trick~=true or left and left<aimed_time+0.1) then a=c.pick('multishot','establish Trick Shots before Aimed/Rapid');if a then return a end end
 end
 if c.burst then a=c.pick('trueshot','MM burst window');if a then return a end end
 -- During Trueshot, spend an Aimed charge before Rapid Fire when there is no
 -- Precise Shots global waiting. Sentinel Chakram is timed into the final five
 -- seconds rather than spent at the start of the cooldown window.
 if trueshot==true and not precise then a=c.pick('aimed_shot','Trueshot Aimed Shot before Rapid Fire');if a then return a end end
 if c.settings.mm_chakram~=false and c.talent('sentinel')
  and (trueshot~=true or trueshot_left and trueshot_left<=5) then
  a=c.pick('moonlight_chakram','land Sentinel Chakram near the end of Trueshot');if a then return a end
 end
 local aimed_fractional=math.max(c.charges('aimed_shot'),c.fractional and c.fractional('aimed_shot') or 0)
 if aimed_fractional>=1.8 then a=c.pick('aimed_shot','avoid imminent Aimed charge waste');if a then return a end end
 a=c.pick('rapid_fire','Rapid Fire damage and focus generation');if a then return a end
 a=c.pick('wailing_arrow','available Dark Ranger proc damage');if a then return a end
 if precise and c.settings.mm_precise~=false then
  a=c.pick('kill_shot','consume Precise Shots with eligible execute damage');if a then return a end
  local cleave_spender=multi or c.aoe_safe and c.enemy_count>=2 and c.talent('hydra') and not dungeon
  a=cleave_spender and c.pick('multishot','consume Precise Shots into safe cleave') or c.pick('arcane_shot','consume Precise Shots');if a then return a end
 end
 a=c.pick('aimed_shot','MM primary precision strike');if a then return a end
 a=c.pick('black_arrow','Dark Ranger arrow damage');if a then return a end
 if c.execute then a=c.pick('kill_shot','execute pressure');if a then return a end end
 if c.focus and c.focus>=80 then a=c.pick('arcane_shot','avoid focus overcap');if a then return a end end
 return c.pick('steady_shot','focus recovery; movement waits for an eligible instant')
end
return R
