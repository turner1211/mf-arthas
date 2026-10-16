local S,U=require('hh_spells'),require('hh_util');local R={spec=253}
local function enabled(c,key)return c.settings[key]~=false end
function R.decide(c,e)
 if c.spec~=253 then return nil end
 local a;local gcd=c.gcd_duration or 1.5
 if c.debuff(S.aura.hunter_mark)==false and not c.pvp then
  a=c.pick('hunters_mark','apply missing Hunter’s Mark');if a then return a end
 end
 local dark=c.talent('black_arrow') or c.known('black_arrow')
 local multi=c.aoe_safe and c.enemy_count>=2 and enabled(c,'bm_cleave')
 local wrath_cd=c.cd('bestial_wrath')
 local cleave,left=c.buff(S.aura.beast_cleave)
 if cleave~=true then cleave,left=c.pet_buff(S.aura.pet_cleave)end
 -- Brief aura visibility gaps must not spend every GCD reapplying Wild Thrash.
 local recent=c.now-(e.history.wild_thrash or -math.huge)
 if cleave~=true and recent<6.5 then cleave,left=true,8-recent end
 local wrath_time=e.history.bestial_wrath or -math.huge
 local wrath_window=c.now-wrath_time<4
 local after_wrath=wrath_window and (e.history.wild_thrash or -math.huge)<wrath_time
 local hold_for_wrath=multi and cleave==true and c.burst and wrath_cd<=gcd and not wrath_window
 if multi and dark and cleave~=true and c.burst and wrath_cd<=gcd and enabled(c,'bm_dark_ranger')then
  a=c.pick('black_arrow','activate Dark Ranger cleave before Bestial Wrath');if a then return a end
 end
 if multi and not hold_for_wrath and (cleave~=true or after_wrath or left and left<gcd*0.25)then
  a=c.pick('wild_thrash','maintain pet cleave and cover the Apex pet after Wrath');if a then return a end
 end
 local barbed=math.max(c.charges('barbed_shot'),c.fractional and c.fractional('barbed_shot') or 0)
 local kc=math.max(c.charges('bm_kill_command'),c.fractional and c.fractional('bm_kill_command') or 0)
 local offensive=c.burst or c.mode=='arena' and c.kill_intent
 -- PvP pressure has its own priority; PvE Apex/proc tuning must not delay it.
 if c.pvp then
  if offensive and c.pet_controlled then
   a=c.pick('bestial_wrath','break confirmed pet crowd control and restore pet pressure');if a then return a end
  end
  if dark and enabled(c,'bm_dark_ranger') then a=c.pick('black_arrow','PvP Dark Ranger pressure');if a then return a end end
  if kc>=1.8 then a=c.pick('bm_kill_command','PvP Kill Command nearing charge cap');if a then return a end end
 end
 if barbed>=1.8 then a=c.pick('barbed_shot','protect Barbed Shot nearing charge cap before burst');if a then return a end end
 local prep=offensive and c.known('bestial_wrath') and wrath_cd<=gcd and e.last_action~='barbed_shot' and enabled(c,'bm_barbed_setup')
 -- Current PvP setup ramps two Barbed Shots into Bestial Wrath. Limit the
 -- second shot to a confirmed, recent first shot and a remaining charge.
 if c.pvp and offensive and enabled(c,'bm_barbed_setup') and wrath_cd<=gcd
  and e.last_action=='barbed_shot' and c.now-(e.history.barbed_shot or -math.huge)<3 and barbed>=1 then
  a=c.pick('barbed_shot','complete the two-Barbed PvP Bestial Wrath setup');if a then return a end
 end
 if prep and (c.pvp or not dark or c.talent('bloody_frenzy') and c.talent('snakeskin_quiver') and c.talent('jagged_wounds'))then
  a=c.pick('barbed_shot','prepare Barbed damage before Bestial Wrath');if a then return a end
 end
 -- Bestial Wrath's opening pet hit can be lost before the pet commits. Confirm
 -- the pet target or a recent pet-driving attack, then use one setup GCD when
 -- possible. If neither setup spell is usable, Wrath remains available below.
 local pet_target=U.call(c.pet,'get_target')
 local pet_committed=U.same(pet_target,c.target)
  or c.now-(e.history.bm_kill_command or -math.huge)<3 and e.history_target.bm_kill_command==c.target_guid
  or c.now-(e.history.barbed_shot or -math.huge)<3 and e.history_target.barbed_shot==c.target_guid
 if offensive and c.known('bestial_wrath') and wrath_cd<=gcd and not c.pet_controlled and not pet_committed then
  a=c.pick('bm_kill_command','commit the pet before Bestial Wrath');if a then return a end
  a=c.pick('barbed_shot','send the pet before Bestial Wrath');if a then return a end
 end
 if offensive and (not multi or not c.talent('beast_cleave') or cleave==true)then
  a=c.pick('bestial_wrath','BM PvP kill window or PvE offensive window');if a then return a end
 end
 local stampede_due=not c.pvp and c.talent('pack_leader') and wrath_window
  and (e.history.bm_kill_command or -math.huge)<wrath_time and (not multi or cleave==true)
 if stampede_due then a=c.pick('bm_kill_command','launch the first post-Wrath Pack Leader Stampede');if a then return a end end
 local withering,withering_left=c.buff(S.aura.withering)
 if dark and enabled(c,'bm_dark_ranger') and withering==true then
  a=c.pick('black_arrow','Withering Fire damage, including targets above execute range');if a then return a end
 end
 local howl=c.buff(S.aura.howl_wyvern)==true or c.buff(S.aura.howl_boar)==true or c.buff(S.aura.howl_bear)==true
 local ally=c.buff(S.aura.natures_ally)
 local apex=c.talent('natures_ally_3')
 local repeated_apex=not c.pvp and apex and e.last_action=='bm_kill_command'
  and c.now-(e.history.bm_kill_command or -math.huge)<3
 local bank_ally=not c.pvp and ally==true and kc<2 and wrath_cd<=3
 if not repeated_apex and (kc>=1.8 or howl or not bank_ally and (c.pvp or ally==true or not apex)) then
  a=c.pick('bm_kill_command','pet damage, charge protection and Pack Leader summon');if a then return a end
 end
 if dark and enabled(c,'bm_dark_ranger') and (withering==true and withering_left and withering_left<3.5 or c.ttd and c.ttd<3.5)then
  a=c.pick('wailing_arrow','finish Wailing Arrow before the damage window expires');if a then return a end
 end
 local fang,_,fang_stacks=c.buff(S.aura.cobra_fang)
 -- The 12.1 four-piece threshold differs by hero tree on one target: Pack
 -- Leader spends at 3, Dark Ranger at 4. In AoE any active Fang is consumed
 -- while Beast Cleave is active because Cobra transfers into the cleave.
 local fang_threshold=dark and 4 or 3
 local cobra_proc=fang==true and (multi or (fang_stacks or 0)>=fang_threshold)
 local killer=c.talent('killer_cobra') and c.buff(S.aura.bestial)==true and barbed<1.4
 if cobra_proc or killer then
  a=c.pick('cobra_shot',cobra_proc and 'spend empowered Cobra Fang' or 'reset Kill Command through Killer Cobra');if a then return a end
 end
 if c.execute and not dark then a=c.pick('kill_shot','PvP or PvE execute pressure');if a then return a end end
 if dark and enabled(c,'bm_dark_ranger') then a=c.pick('black_arrow','Dark Ranger primary arrow damage');if a then return a end end
 if multi and left and left<gcd then a=c.pick('wild_thrash','refresh cleave before the next damage GCD');if a then return a end end
 if enabled(c,'bm_dire_beast')then a=c.pick('dire_beast','available summoned-beast damage');if a then return a end end
 if c.talent('serpentine_strikes') or not c.focus or c.focus<75 or barbed>=2 then
  a=c.pick('barbed_shot','Barbed pressure and charge cycling');if a then return a end
 end
 if dark and enabled(c,'bm_dark_ranger')then a=c.pick('wailing_arrow','available Dark Ranger damage');if a then return a end end
 -- Hidden Apex data uses a usable Kill Command fallback rather than stopping damage.
 if not repeated_apex and not bank_ally then a=c.pick('bm_kill_command','pet pressure when no higher priority proc is visible');if a then return a end end
 local cobra_cost=c.cost and c.cost('cobra_shot') or 35
 local kc_cost=c.cost and c.cost('bm_kill_command') or 30
 local reserve=enabled(c,'bm_focus_pool') and c.cd('bm_kill_command')<=gcd and kc_cost or 0
 if cobra_cost==0 or not c.focus or c.focus>=cobra_cost+reserve or c.deficit and c.deficit<10 then
  a=c.pick('cobra_shot','spend Focus while reserving the next Kill Command');if a then return a end
 end
 if c.pvp and c.debuff(S.aura.hunter_mark)==false and c.focus and c.focus<=cobra_cost then
  a=c.pick('hunters_mark','apply missing Hunter’s Mark during low-Focus PvP downtime');if a then return a end
 end
 return c.pick('barbed_shot','available Barbed fallback while Focus is reserved')
end
return R
