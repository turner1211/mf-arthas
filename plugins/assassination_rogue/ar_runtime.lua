local Lib={
 Debugger=require('ar_debug'),S=require('ar_spells'),P=require('ar_profiles'),A=require('ar_aura'),
 T=require('ar_telemetry'),G=require('ar_gathering'),UI=require('ar_gui'),
 Prediction=require('ar_prediction'),BigWigs=require('ar_bigwigs'),StepCC=require('ar_step_cc'),
 KillWindows=require('ar_kill_windows'),Stealth=require('ar_stealth'),Engagement=require('ar_engagement'),
 Intel=require('ar_combat_intel'),Replay=require('ar_replay'),Performance=require('ar_performance'),
 PvP=require('ar_pvp_tactics'),TargetForecast=require('ar_target_forecast'),
 ThreatLearning=require('ar_threat_learning'),InterruptCoordination=require('ar_interrupt_coordination'),
 CastPriority=require('ar_cast_priority'),Decision=require('ar_decision_memory'),DangerZones=require('ar_danger_zones'),BossCoach=require('ar_boss_coach'),BossHUD=require('ar_boss_hud'),Hotkeys=require('ar_hotkeys'),Branch=require('ar_branch'),Forever=require('ar_forever')
}
local E=require("common/enums")
local Color=require('common/color')
local dummy_ok,UnitHelper=pcall(require,"common/utility/unit_helper")
local ok_pvp,H=pcall(require,"common/utility/pvp_helper");if not ok_pvp then H=nil end
local M={}
local opts={enabled=true,damage=true,defensives=true,interrupt=true,cc=true,poisons=true,
 stealth=true,offensive_vanish=false,auto_target=false,auto_face=false,
 fishing=false,looting=false,skinning=false,logging=true,predictive=true,bigwigs=true,danger_zones=true,boss_coach=true,dummy_test=true,auto_dummy_target=false,auto_kill=true,step_cc=true,world_visuals=true,spread_bleeds=true,combat_intel=true,replay_analysis=true,adaptive_performance=true}
local controls={}
for k,v in pairs(opts) do controls[k]=core.menu.checkbox(v,k=='dummy_test' and "ar_101_dummy_test" or "ar_100_"..k) end
local profile_controls={}
for key,p in pairs(Lib.P.settings) do
 profile_controls[key]={}
 for _,field in ipairs({"damage","opener","cooldowns","cc","defensives"}) do
  profile_controls[key][field]=core.menu.checkbox(p[field],"ar_100_"..key.."_"..field)
 end
end
Lib.Hotkeys.attach(controls,profile_controls,Lib.P.settings)
local root=core.menu.tree_node()
local window_open,editing_mode,mode,last,notice=true,nil,"pve","Waiting","Automatic profile detection"
local pending=nil
local State={cast_latency=0.25,target_failures={},next_request=0,next_update=0,next_skip=0,
 opening_target=nil,kill_kidney=nil,pvp_swap_lock_until=0,dot_history={},bleed_visibility={},cc_history={},key_down=false,
 duel_active=false,city_poison_at=0,
 manual_burst_until=0,envenom_expires=0,improved_refresh_target=nil,improved_refresh_until=0,chain_refresh_target=nil,talent_signature='',
 unit_frame=nil,ready_failure='',object_cache={},object_time=-math.huge,arena_specs={},arena_units={},arena_refresh=-math.huge,
 kidney_ready_since=nil,blind_ready_since=nil,
 blind_chain_target=nil,blind_chain_until=-math.huge,
 bleed_removal_seen={},bleed_recovery_until={},bleed_recovery_after={},
 arena_vanish_focus=nil,arena_vanish_until=-math.huge,arena_vanish_kill=nil,arena_vanish_kill_stage=nil,arena_vanish_kill_until=-math.huge,
 talent_cache=nil,talent_refresh=-math.huge,sap_log_time=-math.huge,triage_signature='',triage_time=-math.huge,
 last_update=-math.huge,next_settings=-math.huge,next_failure_cleanup=-math.huge,
 visual_check=-math.huge,visual_healer=nil,visual_possible=false}




local active=false
local opening={start=0,done=false,garrote=0,rupture=false,envenom=false}









for _,id in ipairs({Lib.S.DEADLY,Lib.S.WOUND,Lib.S.CRIPPLING,Lib.S.ATROPHIC,Lib.S.NUMBING,Lib.S.INSTANT,Lib.S.AMPLIFYING,
 8679,8687,8691,11341,11342,11343,2823,2837,11355,11356,11357,25347,3408,11201,5761,8694,11398,13219,13222,13223,13224}) do Lib.A.track(id,{cast_floor=1800}) end
for id,duration in pairs({[Lib.S.VIAL]=4,[Lib.S.FEINT]=6,[Lib.S.CLOAK]=5,[Lib.S.EVASION]=10,[Lib.S.STEALTH]=3,[Lib.S.VANISH]=3,[Lib.S.SPRINT]=8,[Lib.S.SLICE]=12}) do Lib.A.track(id,{cast_floor=duration}) end
-- Read-only native getters are memoized within one evaluation, never across ticks.

local cached_getters={is_valid=true,is_dead=true,is_player=true,is_in_combat=true,is_mounted=true,is_falling=true,is_flying=true,get_guid=true,get_name=true,get_health=true,get_max_health=true,get_class=true,get_group_role=true,get_specialization_id=true,get_level=true}
local function call(o,k,...)
 if not o then return nil end
 local row
 if State.unit_frame and cached_getters[k] and select("#",...)==0 then
  row=State.unit_frame[o];if not row then row={};State.unit_frame[o]=row end
  if row[k] then return row[k][1] end
 end
 local ok,fn=pcall(function() return o[k] end);if not ok or type(fn)~="function" then return nil end
 local good,v=pcall(fn,o,...);if good then if row then row[k]={v} end;return v end
end
local function read(fn,...)
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,...);if ok then return v end
end
local function now() return core.time() end
local function guid(u) return tostring(call(u,"get_guid") or u) end
local function alive(u) return call(u,"is_valid")==true and call(u,"is_dead")~=true end
local function hp(u)
 local a,b=call(u,"get_health"),call(u,"get_max_health")
 if type(a)=="number" and type(b)=="number" and b>0 then return math.max(0,math.min(100,a/b*100)) end
 return nil
end
local function mana_pct(u)
 local value,maximum=call(u,'get_power',0),call(u,'get_max_power',0)
 if type(value)=='number' and type(maximum)=='number' and maximum>0 then return math.max(0,math.min(100,value/maximum*100)) end
end
local function dist(p,u)
 local d=call(p,"distance_to",u);if type(d)=="number" then return d end
 local a,b=call(p,"get_position"),call(u,"get_position")
 if a and b then return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
 return math.huge
end
local function present(u,id) return Lib.A.present(u,id)==true end
local function enraged(u)
 local buffs=call(u,'get_buffs');if type(buffs)~='table' then return false end
 for _,a in pairs(buffs) do
  local flag=call(a,'is_enrage')
  local kind=call(a,'get_dispel_type') or read(function()return a.dispel_type or a.dispelType end)
  if flag==true or type(kind)=='string' and kind:lower()=='enrage' then return true end
 end
 return false
end
local function known(id) return read(core.spell_book.is_spell_known,id)==true end
local function cd(id) local d=read(core.spell_book.get_spell_cooldown,id);return type(d)=="number" and d or math.huge end

local function ready(id)
 State.ready_failure=""
 if not known(id) then State.ready_failure="spell "..id.." not known";return false end
 local charges=read(core.spell_book.get_spell_charge,id)
 if not (type(charges)=="number" and charges>0) and cd(id)>0.05 then State.ready_failure="spell "..id.." cooldown="..tostring(cd(id));return false end
 local usable=read(core.spell_book.is_usable_spell,id)==true
 if not usable then State.ready_failure="spell "..id.." not usable (resource / spell restriction)" end
 return usable
end
local function los(p,u) return read(core.graphics and core.graphics.is_line_of_sight,p,u)==true end
local function helper(method,u,...)
 local value=call(H,method,u,...)
 if value==nil then
  if method=='get_unit_dr' then value=call(u,'get_dr',...)
  elseif method=='is_disarmable' then value=call(u,'is_disarmable')
  elseif method=='has_burst_active' then value=call(u,'has_burst_active',...) end
 end
 if method=='get_unit_dr' then
  if type(value)~='number' or value<0 or value>1.01 then return nil end
  return math.min(1,value)
 end
 return value
end
local break_auras={6770,2094,1776,118,51514,20066,8122,5782,3355,6358,33786}
local immune_auras={642,45438,186265,33786,710}
local stun_auras={408,1833,853,30283,5211,119381}
local function any_aura(u,ids) for _,id in ipairs(ids) do if present(u,id) then return true end end;return false end
local function stunned(u) return call(u,'is_stunned',0)==true or any_aura(u,stun_auras) end
local function protected(u)
 return any_aura(u,immune_auras) or helper("is_damage_immune",u,nil,500)==true
end
local function breakable(u)
 local recent=State.cc_history[guid(u)]
 return any_aura(u,break_auras) or helper("is_crowd_controlled_weak",u,500)==true
    or (recent and recent.break_until and recent.break_until>now()) or false
end
local function stun_safe(p,u)
 if not los(p,u) or protected(u) or helper("is_cc_immune",u,nil,500)==true or breakable(u) or stunned(u) then return false end
 local h=State.cc_history[guid(u)]
 if h and (h.stun_dr_until or 0)>now() then return false end
 if call(u,"is_player")==true then
  local reduction=helper("get_unit_dr",u,E.cc_flags and E.cc_flags.STUN,0)
  -- Arena hosts can temporarily omit DR values. Confirmed local stuns still
  -- enforce the complete active-duration + reset lockout above; when the host
  -- returns a value, never cast into immune or quarter-duration stun DR.
  if type(reduction)=="number" and reduction<0.5 then return false end
 end
 return true
end

local function objects()
 if now()-State.object_time>=Lib.Performance.scan_interval() then
  local list=read(core.object_manager.get_all_objects);State.object_cache=type(list)=='table' and list or {};State.object_time=now()
 end
 return State.object_cache
end
local function dummy(u)
 if not alive(u) then return false end
 if dummy_ok and call(UnitHelper,'is_dummy',u)==true then return true end
 local name=call(u,'get_name')
 if type(name)~='string' or call(u,'is_player')==true then return false end
 name=name:lower()
 return name:find('training dummy',1,true)~=nil or name:find('target dummy',1,true)~=nil
  or name:find('combat dummy',1,true)~=nil or name:find('training bag',1,true)~=nil
end
local function enemy(p,u)
 if not alive(u) then return false end
 local attackable=call(p,"can_attack",u)
 if attackable~=nil then return attackable==true end
 return call(u,"is_enemy_with",p)==true
end
local healer_specs={[65]=true,[105]=true,[256]=true,[257]=true,[264]=true,[270]=true,[1468]=true}

local function refresh_arena()
 if now()-State.arena_refresh<0.5 then return end
 State.arena_refresh=now();State.arena_specs={};State.arena_units={}
 local kind=read(core.get_instance_type)
 if kind~='arena' then return end
 for i=1,5 do
  local arena_core=core.addons and core.addons.arena_core
  local frame=arena_core and read(arena_core.get_frame_info,i)
  local token=type(frame)=='table' and frame.unit or 'arena'..i
  local u=read(core.object_manager.get_arena_target,i) or read(core.object_manager.get_object_from_guid,token)
  if alive(u) then
   State.arena_units[#State.arena_units+1]=u
   local spec=read(core.object_manager.get_arena_opponent_spec,i)
   if type(spec)~='number' or spec<=0 then spec=type(frame)=='table' and frame.spec_id or arena_core and read(arena_core.get_spec_id,i) end
   if type(spec)=='number' and spec>0 then State.arena_specs[guid(u)]=spec end
  end
 end
end
local function healer(u)
 local spec=State.arena_specs[guid(u)] or call(u,'get_specialization_id')
 if type(spec)=='number' and spec>0 then return healer_specs[spec]==true end
 local r=call(u,"get_group_role") or call(u,"get_role")
 return healer_specs[State.arena_specs[guid(u)]]==true or healer_specs[call(u,'get_specialization_id')]==true or r==1 or (type(r)=="string" and r:lower():find("heal",1,true)~=nil)
end
local tank_specs={[66]=true,[73]=true,[104]=true,[268]=true,[250]=true,[581]=true}
local function tank(u)
 local spec=call(u,'get_specialization_id')
 if type(spec)=='number' and tank_specs[spec] then return true end
 local role=call(u,'get_group_role') or call(u,'get_role')
 return role==0 or role==3 or type(role)=='string' and role:lower()=='tank'
end
local function control_candidate(u,kill)
 if not u or kill and guid(u)==guid(kill) then return false end
 if not kill or not healer(kill) then return healer(u) end
 local focus=read(core.input.get_focus) or call(core.object_manager.get_local_player(),'get_focus_target')
 if not focus or guid(focus)~=guid(u) then return false end
 if call(u,'is_player')~=true or healer(u) then return false end
 local role=call(u,'get_group_role') or call(u,'get_role')
 local spec=State.arena_specs[guid(u)] or call(u,'get_specialization_id')
 return role==2 or type(role)=='string' and (role:lower()=='dps' or role:lower()=='damage' or role:lower()=='damager')
  or type(spec)=='number' and spec>0 and not tank_specs[spec]
end
local function dummy_profile(target)
 local name=call(target,'get_name')
 name=type(name)=='string' and name:lower() or ''
 if name:find('pvp',1,true) or name:find('competitor',1,true) then return 'arena' end
 if name:find('delve',1,true) then return 'delve' end
 if name:find('dungeoneer',1,true) or name:find('cleave',1,true) or name:find('dungeon',1,true) then return 'mythic_plus' end
 return 'pve'
end
local function detect(p,target)
 local kind=read(core.get_instance_type);kind=type(kind)=="string" and kind:lower() or ""
 local difficulty=read(core.get_difficulty_id)
 local keystone=read(core.world and core.world.get_active_keystone_info)
 if kind=="arena" then return "arena" end
 if kind=="pvp" or kind=="battleground" then return "battleground" end
 if read(core.delves and core.delves.is_in_delve)==true then return "delve" end
 if kind=="party" and (difficulty==8 or type(keystone)=="table" and (tonumber(keystone.level) or 0)>0) then return "mythic_plus" end
 if kind=="raid" or kind=="party" then return "pve" end
 if opts.dummy_test and dummy(target) then return dummy_profile(target) end
 if enemy(p,target) and call(target,"is_player")==true then return "world_pvp" end
 return "pve"
end

local function active_talents()
 if now()-State.talent_refresh>=0.5 then State.talent_cache=read(core.game_ui and core.game_ui.get_active_talents);State.talent_refresh=now() end
 return State.talent_cache
end
local function talent(id,name)
 local ts=active_talents()
 if type(ts)=="table" and next(ts) then
  for _,t in pairs(ts) do
   if type(t)=="table" and (tonumber(t.rank) or 1)>0 and
     (tonumber(t.spell_id)==id or type(t.name)=="string" and t.name:lower()==name:lower()) then return true end
  end
  return (id==Lib.S.HEMOTOXIN or id==Lib.S.SYSTEM_SHOCK or id==Lib.S.PREEMPTIVE) and known(id)
 end
 return id>0 and known(id)
end
local function refresh(u,id,threshold)
 local remaining,source=Lib.A.remaining(u,id)
 local unit_key=guid(u);local visibility=State.bleed_visibility[unit_key]
 if type(remaining)=="number" then
  if id==Lib.S.GARROTE or id==Lib.S.RUPTURE then
   visibility=visibility or {};State.bleed_visibility[unit_key]=visibility
   visibility[id]=visibility[id] or {};visibility[id].seen=true;visibility[id].missing_since=nil
  end
  return remaining<=threshold
 end
 local h=State.dot_history[unit_key];local expires=h and h[id]
 if expires then
  local row=visibility and visibility[id]
  if (id==Lib.S.GARROTE or id==Lib.S.RUPTURE) and row and row.seen and now()>=(row.grace_until or 0)
     and expires-now()>math.max(3,threshold+1) and source=='not_visible' and not present(u,id) then
   -- A single missing aura query is not evidence. Require a readable native
   -- debuff snapshot and sustained absence after this bleed was positively
   -- visible before invalidating the confirmed local timer.
   local debuffs=call(u,'get_debuffs')
   if type(debuffs)=='table' then
    row.missing_since=row.missing_since or now()
    if now()-row.missing_since>=0.35 then
     h[id]=nil;row.seen=false;row.missing_since=nil;row.grace_until=now()+1.2
     Lib.T.note('BLEED_REMOVED',{'target='..tostring(call(u,'get_name') or unit_key),'spell='..tostring(id),'action=immediate reapply'})
     return true
    end
   else row.missing_since=nil end
  elseif row then row.missing_since=nil end
  return expires-now()<=threshold
 end
 -- Unknown never means absent. One initial application / conservative timed refresh.
 if present(u,id) then return false end
 return true
end
local off_gcd={[Lib.S.STEP]=true,[Lib.S.KICK]=true,[Lib.S.CLOAK]=true,[Lib.S.EVASION]=true,[Lib.S.VANISH]=true,[Lib.S.TEA]=true,[Lib.S.SPRINT]=true,[Lib.S.MARK_FOR_DEATH]=true}
for _,id in ipairs(require('ar_forever_spells').KICK) do off_gcd[id]=true end
local self_spells={[Lib.S.FAN]=true,[Lib.S.TEMPEST]=true,[Lib.S.VIAL]=true,[Lib.S.FEINT]=true,
 [Lib.S.CLOAK]=true,[Lib.S.EVASION]=true,[Lib.S.VANISH]=true,[Lib.S.STEALTH]=true,[Lib.S.TEA]=true,
 [Lib.S.DEADLY]=true,[Lib.S.WOUND]=true,[Lib.S.CRIPPLING]=true,[Lib.S.ATROPHIC]=true,[Lib.S.NUMBING]=true}
self_spells[Lib.S.SPRINT]=true;self_spells[Lib.S.SMOKE]=true;self_spells[Lib.S.INSTANT]=true;self_spells[Lib.S.AMPLIFYING]=true;self_spells[Lib.S.SLICE]=true
-- Higher Forever ranks have distinct cast IDs. Preserve the self-target and
-- off-GCD semantics that the shared Retail IDs receive.
for _,family in ipairs({'EVASION','VANISH','SPRINT'}) do
 for _,id in ipairs(require('ar_forever_spells')[family]) do off_gcd[id]=true;self_spells[id]=true end
end
local function skip(s)
 notice=s
 if now()>State.next_skip then Lib.T.note("SKIP",{s});State.next_skip=now()+2 end
end
local function failure_key(id,target) return tostring(id)..':'..guid(target) end
local function record_target_failure(id,target)
 local k=failure_key(id,target);local row=State.target_failures[k] or {count=0}
 row.count=math.min(5,row.count+1)
 local hold=math.min(2,0.25*2^(row.count-1))
 if row.count>=3 then hold=math.max(hold,math.min(6,row.count)) end
 row.until_time=now()+hold
 row.last=now();State.target_failures[k]=row
 if row.count==3 then Lib.T.note('CAST_CIRCUIT',{'spell='..id,'target='..guid(target),'hold='..string.format('%.1f',row.until_time-now())}) end
end
local function attempt(a,c)
 if not a then return false end
 if a.wait then c.current_action="Pooling / waiting";c.next_reason=a.why;skip(a.why);return false end
 if pending or now()<State.next_request or not ready(a.id) then return false end
 local target=self_spells[a.id] and c.player or a.target
 if not alive(target) then return false end
 local target_failure=State.target_failures[failure_key(a.id,target)]
 if target_failure and (target_failure.until_time or 0)>now() then skip('Cast held after repeated target-specific failures');return false end
 if guid(target)~=guid(c.player) then
  if a.friendly then
   if enemy(c.player,target) then skip("Friendly cast blocked: target is hostile");return false end
  else
   if not enemy(c.player,target) then skip("Cast blocked: target not attackable");return false end
   if protected(target) or breakable(target) then skip("Cast blocked: damage immunity or breakable control");return false end
  end
  if not los(c.player,target) then skip("Cast blocked: line of sight not confirmed");return false end
 end
 local gcd=cd(61304)
 if gcd==math.huge then gcd=call(c.player,"gcd_remains") end
 if not off_gcd[a.id] and (type(gcd)~="number" or gcd>0.05) then skip("Waiting for global cooldown");return false end
 local in_range=read(core.spell_book.is_spell_in_range,a.id,target,c.player)
 if guid(target)~=guid(c.player) and in_range~=true then skip("Spell range not confirmed");return false end
 local ok,accepted=pcall(core.input.cast_target_spell,a.id,target)
 accepted=ok and accepted==true;State.next_request=now()+math.max(0.12,math.min(0.3,State.cast_latency*0.5))
 Lib.T.request(a.id,call(target,"get_name") or guid(target),accepted,a.why,c)
 if accepted then
  pending={id=a.id,target=target,time=now(),expires=now()+math.max(1.2,math.min(3,State.cast_latency*4+0.8)),cp=c.cp,why=a.why,kill_target=c.target,target_name=call(target,"get_name") or guid(target)}
  if a.id==Lib.S.TEMPEST and c.aoe_safe then
   pending.spread_targets={}
   pending.spread_garrote=type(c.garrote_remaining)=='number' and c.garrote_remaining>0 and c.garrote_remaining or nil
   pending.spread_rupture=type(c.rupture_remaining)=='number' and c.rupture_remaining>0 and c.rupture_remaining or nil
   for _,u in ipairs(c.enemies or {}) do
    if enemy(c.player,u) and dist(c.player,u)<=10 and call(u,'is_in_combat')==true
       and not protected(u) and not breakable(u) then pending.spread_targets[#pending.spread_targets+1]=guid(u) end
   end
  end
  c.current_action=read(core.spell_book.get_spell_name,a.id) or tostring(a.id)
  last=(read(core.spell_book.get_spell_name,a.id) or tostring(a.id)).." / "..a.why
 else record_target_failure(a.id,target) end
 return accepted
end
local function action(id,target,why,friendly) return {id=id,target=target,why=why,friendly=friendly==true} end
local function confirm(id,success,observed_target)
 if id==115191 and pending and pending.id==Lib.S.STEALTH then id=Lib.S.STEALTH end
 if not pending or pending.id~=id then return end
 if not self_spells[id] and observed_target and pending.target and guid(observed_target)~=guid(pending.target) then
  Lib.T.note('CONFIRM_MISMATCH',{'spell='..tostring(id),'expected='..guid(pending.target),'observed='..guid(observed_target)})
  return
 end
 local req=pending;pending=nil;Lib.T.event(id,success,req)
 Lib.Replay.cast(id,success,req)
 local observed=math.max(0,now()-req.time);State.cast_latency=State.cast_latency*0.8+observed*0.2
 Lib.StepCC.confirm(id,req.target,success)
 if not success then
  record_target_failure(id,req.target)
  return
 end
 State.target_failures[failure_key(id,req.target)]=nil
 if id==Lib.S.VANISH and (req.why=='Vanish before Deathmark for Improved Garrote' or req.why=='PvP safe offensive Vanish before Deathmark') then
  State.improved_refresh_target=guid(req.kill_target);State.improved_refresh_until=now()+6
 elseif id==Lib.S.VANISH and req.why=='Mythic+ chain pull: recover Improved Garrote window' then
  State.improved_refresh_target=guid(req.kill_target);State.chain_refresh_target=guid(req.kill_target);State.improved_refresh_until=now()+6
 end
 local k=guid(req.target);State.dot_history[k]=State.dot_history[k] or {}
 if id==Lib.S.TEMPEST and req.spread_targets then
  for _,spread_key in ipairs(req.spread_targets) do
   State.dot_history[spread_key]=State.dot_history[spread_key] or {}
   State.bleed_visibility[spread_key]=State.bleed_visibility[spread_key] or {}
   if req.spread_garrote then
    State.dot_history[spread_key][Lib.S.GARROTE]=now()+req.spread_garrote
    State.bleed_visibility[spread_key][Lib.S.GARROTE]={seen=false,grace_until=now()+1.2}
   end
   if req.spread_rupture then
    State.dot_history[spread_key][Lib.S.RUPTURE]=now()+req.spread_rupture
    State.bleed_visibility[spread_key][Lib.S.RUPTURE]={seen=false,grace_until=now()+1.2}
   end
  end
  Lib.T.note('BLEED_SPREAD',{'targets='..tostring(#req.spread_targets),'garrote_s='..tostring(req.spread_garrote),'rupture_s='..tostring(req.spread_rupture)})
 end
 if id==Lib.S.GARROTE then
  State.dot_history[k][id]=now()+18;if k==State.opening_target then opening.garrote=opening.garrote+1 end
  State.bleed_visibility[k]=State.bleed_visibility[k] or {};State.bleed_visibility[k][id]={seen=false,grace_until=now()+1.2}
  if k==State.improved_refresh_target then State.improved_refresh_target=nil end
  if k==State.chain_refresh_target then State.chain_refresh_target=nil end
  if k==State.arena_vanish_focus and now()<State.arena_vanish_until then
   State.cc_history[k]=State.cc_history[k] or {};State.cc_history[k].lockout_until=now()+3
   State.arena_vanish_focus=nil;State.arena_vanish_until=-math.huge
   Lib.T.note('HEALER_LOCKOUT',{'target='..tostring(req.target_name),'duration=3.0','source=offensive Vanish Garrote'})
  end
  if k==State.arena_vanish_kill and now()<State.arena_vanish_kill_until then
   if State.arena_vanish_kill_stage=='garrote1' then
    State.arena_vanish_kill_stage='cheap'
   elseif State.arena_vanish_kill_stage=='garrote2' then
    State.arena_vanish_kill=nil;State.arena_vanish_kill_stage=nil;State.arena_vanish_kill_until=-math.huge
    Lib.T.note('OFFENSIVE_VANISH',{'target='..tostring(req.target_name),'chain=Garrote to Cheap Shot to Garrote','window=Deathmark/Kingsbane'})
   end
  end
 end
 if id==Lib.S.RUPTURE then
  State.dot_history[k][id]=now()+4+4*req.cp;State.bleed_visibility[k]=State.bleed_visibility[k] or {}
  State.bleed_visibility[k][id]={seen=false,grace_until=now()+1.2};if k==State.opening_target then opening.rupture=true end
 end
 if id==Lib.S.ENVENOM then if k==State.opening_target then opening.envenom=true;opening.done=true end;State.envenom_expires=now()+1+req.cp end
 if id==Lib.S.KIDNEY or Lib.Forever.is_spell('KIDNEY',id) then State.kidney_ready_since=nil end
 if id==Lib.S.BLIND or Lib.Forever.is_spell('BLIND',id) then
  State.blind_ready_since=nil
  if healer(req.target) then State.blind_chain_target=k;State.blind_chain_until=now()+8 end
 end
 if id==Lib.S.SAP and k==State.blind_chain_target then
  State.blind_chain_target=nil;State.blind_chain_until=-math.huge
  Lib.T.note('CC_CHAIN',{'target='..tostring(req.target_name),'chain=Blind to Sap','result=confirmed'})
 end
 if id==Lib.S.DEATHMARK then State.dot_history[k][id]=now()+16 end
 if id==Lib.S.KINGSBANE then State.dot_history[k][id]=now()+14 end
 if id==Lib.S.CHEAP or id==Lib.S.KIDNEY or Lib.Forever.is_spell('KIDNEY',id) then
  local duration=(id==Lib.S.KIDNEY or Lib.Forever.is_spell('KIDNEY',id)) and math.min(6,1+(req.cp or 0)) or 4
  State.cc_history[k]=State.cc_history[k] or {}
  State.cc_history[k].stun_active_until=now()+duration
  State.cc_history[k].stun_dr_until=now()+duration+20
  if id==Lib.S.CHEAP and k==State.arena_vanish_kill and State.arena_vanish_kill_stage=='cheap'
     and now()<State.arena_vanish_kill_until then State.arena_vanish_kill_stage='garrote2' end
 end
 if (id==Lib.S.KICK or Lib.Forever.is_spell('KICK',id)) and healer(req.target) then
  State.cc_history[k]=State.cc_history[k] or {};State.cc_history[k].lockout_until=now()+3
  Lib.T.note('HEALER_LOCKOUT',{'target='..tostring(req.target_name),'duration=3.0','source=confirmed Kick'})
 end
 if (id==Lib.S.KIDNEY or Lib.Forever.is_spell('KIDNEY',id)) and req.cp>=5 and req.why=='kill opener: full Kidney before Smoke Bomb' then State.kill_kidney={target=k,expires=now()+5} end
 if id==Lib.S.SMOKE then State.kill_kidney=nil end
 if id==Lib.S.BLIND or id==Lib.S.SAP or id==Lib.S.GOUGE or Lib.Forever.is_spell('BLIND',id) or Lib.Forever.is_spell('SAP',id) or Lib.Forever.is_spell('GOUGE',id) then
  local duration=(id==Lib.S.GOUGE or Lib.Forever.is_spell('GOUGE',id)) and 4 or 8
  State.cc_history[k]=State.cc_history[k] or {};State.cc_history[k].break_until=now()+duration
 end
 Lib.A.on_spell_cast({spell_id=id,target=req.target})
end
local function defense(c)
 if not opts.defensives or not c.profile.defensives then return end
 local r=c.prediction or {projected=c.self_hp,current=c.self_hp,danger=false,reason="reactive health"}
 if c.enemy_burst and not r.physical and not r.magic then
  r.physical=c.matchup_school=='physical';r.magic=c.matchup_school=='magic'
 end
 local player_stunned=stunned(c.player)
 local evasion_effective=present(c.player,Lib.S.EVASION) and not player_stunned
 local hpv=math.min(c.self_hp,r.projected)
 local cast_defense_needed=(r.unstoppable_casts or 0)>0 or (r.stoppable_casts or 0)>(r.reachable_stops or 0)
 -- Remembered enemy burst lowers every major defensive threshold without
 -- guessing damage school; the normal school-specific selection still applies.
 if c.enemy_burst then hpv=hpv-10 end
 if c.friendly_healer_present and not c.friendly_healer_available then hpv=hpv-8 end
 if c.friendly_healer_mana and c.friendly_healer_mana<=20 then hpv=hpv-8
 elseif c.friendly_healer_mana and c.friendly_healer_mana<=35 then hpv=hpv-4 end
 if c.player_flag_carrier then hpv=hpv-10 end
 local why=" / "..r.reason
 if c.game_branch=='forever' and not player_stunned and c.attackers>=2 and (c.melee_pressure or r.physical)
    and hpv<=85 and not evasion_effective then
  if attempt(action(c.evasion_id,c.player,'Forever: early Evasion against multiple melee attackers'..why),c) then return true end
 end
 if c.game_branch~='forever' and c.pvp and r.stun and (talent(Lib.S.PREEMPTIVE,'Preemptive Maneuver') or talent(Lib.S.ELUSIVENESS,'Elusiveness')) and not present(c.player,Lib.S.FEINT) then
  if attempt(action(Lib.S.FEINT,c.player,'preemptive Feint: observed stun cast'..why),c) then return true end
 end
 if c.pvp and r.control and r.magic and (r.impact_in or math.huge)<=0.55
    and (r.reachable_stops or 0)==0 and not present(c.player,Lib.S.CLOAK) then
  if attempt(action(Lib.S.CLOAK,c.player,'preemptive Cloak: targeted hard CC cannot be kicked'..why),c) then return true end
 end
 -- Smoke is centered on the Rogue. Use it to cover a nearby healer only when
 -- a ranged cast aimed at that healer is about to land and Kick cannot reach.
 if c.pvp and c.self_hp<=35 and c.friendly_healer_smoke_cover and c.friendly_healer_cast_threat
    and c.friendly_healer_cast_imminent and c.friendly_healer_cast_outside_bomb
    and not c.friendly_healer_cast_kick_reachable and not c.player_flag_carrier then
  if attempt(action(Lib.S.SMOKE,c.player,'defensive Smoke Bomb: cover nearby healer from imminent ranged control'),c) then return true end
 end
 local timer=r.timer
 local timer_personal=timer and (not timer.targeted or r.casts>0)
 -- An active major protects only its own damage type. At low projected health,
 -- a verified opposite-school cast may require the other major as well.
 if hpv<=35 then
  if r.magic and evasion_effective and not present(c.player,Lib.S.CLOAK) then
   if attempt(action(Lib.S.CLOAK,c.player,'magic threat bypasses active Evasion'..why),c) then return true end
  end
  if not player_stunned and r.physical and present(c.player,Lib.S.CLOAK) and not evasion_effective then
   if attempt(action(c.evasion_id,c.player,'physical threat bypasses active Cloak'..why),c) then return true end
  end
 end
 -- At immediate lethal danger, trade the relevant major before routine Feint.
 if hpv<=25 and not present(c.player,Lib.S.CLOAK) and not evasion_effective then
  if r.magic and attempt(action(Lib.S.CLOAK,c.player,"emergency predicted magic hit"..why),c) then return true end
  if not player_stunned and (r.physical or c.melee_pressure) and attempt(action(c.evasion_id,c.player,"emergency predicted melee hit"..why),c) then return true end
  if c.pvp and c.friendly_healer_present and not c.friendly_healer_available and c.attackers>=2
     and c.smoke_range and not c.damage_reduced and attempt(action(Lib.S.SMOKE,c.player,"defensive Smoke Bomb: healer unavailable under lethal focus"..why),c) then return true end
  if c.pvp and not c.player_flag_carrier and c.attackers>0 and attempt(action(c.vanish_id,c.player,"emergency predicted kill pressure"..why),c) then return true end
 end
if c.world_escape and not c.player_flag_carrier and c.attackers>=3 and not c.stealth and not present(c.player,Lib.S.CLOAK) and not evasion_effective then
   if attempt(action(c.vanish_id,c.player,'World PvP disengage: outnumbered with falling health'..why),c) then return true end
 end
 -- Trade one defensive at a time. Lib.A configured imminent AoE gets Feint even
 -- without Elusiveness; unknown targeted casts use Feint only with that talent.
 if c.game_branch~='forever' and not present(c.player,Lib.S.CLOAK) and not evasion_effective and not present(c.player,Lib.S.FEINT)
    and (c.boss_defensive_soon or (timer and timer.kind=="aoe") or (timer and timer.kind=="unknown" and talent(Lib.S.ELUSIVENESS,"Elusiveness")) or
      (r.danger and talent(Lib.S.ELUSIVENESS,"Elusiveness") and (hpv<=85 or cast_defense_needed or r.focus_burst and c.attackers>0 and (r.current-r.projected)>=8))) then
  if attempt(action(Lib.S.FEINT,c.player,"predictive damage reduction"..why),c) then return true end
 end
 local imminent_heavy=r.impact_in and r.impact_in<=0.9 and ((r.learned_pressure or 0)>=12 or r.projected<=55)
 if imminent_heavy then
  if r.magic and not present(c.player,Lib.S.CLOAK) and attempt(action(Lib.S.CLOAK,c.player,'learned magic impact inside one second'..why),c) then return true end
  if r.physical and not player_stunned and not evasion_effective and attempt(action(c.evasion_id,c.player,'learned physical impact inside one second'..why),c) then return true end
 end
 if hpv<=50 and not present(c.player,Lib.S.VIAL) then
  if c.self_hp<=80 and attempt(action(Lib.S.VIAL,c.player,"personal heal"..why),c) then return true end
 end
 if (r.magic and hpv<=65 or timer_personal and timer.kind=="magic") and not evasion_effective and not present(c.player,Lib.S.CLOAK) then
  if attempt(action(Lib.S.CLOAK,c.player,"predictive magic defense"..why),c) then return true end
 end
 if not player_stunned and (c.melee_pressure and hpv<=60 or r.physical and hpv<=65 or timer_personal and timer.kind=="physical") and not present(c.player,Lib.S.CLOAK) and not evasion_effective then
  if attempt(action(c.evasion_id,c.player,"predictive physical defense"..why),c) then return true end
 end
 if c.game_branch~='forever' and hpv<=70 and c.attackers>0 and talent(Lib.S.ELUSIVENESS,"Elusiveness") and not present(c.player,Lib.S.FEINT)
    and not present(c.player,Lib.S.CLOAK) and not evasion_effective then
  if attempt(action(Lib.S.FEINT,c.player,"Elusiveness under focus"),c) then return true end
 end
 if hpv<=20 and c.self_hp<=35 and c.attackers>0 and c.pvp and not c.stealth and not c.player_flag_carrier
    and (not present(c.player,Lib.S.CLOAK) and not evasion_effective or (r.loss or 0)>0) then
  return attempt(action(c.vanish_id,c.player,"predictive emergency disengage"..why),c)
 end
end
local function full_stun(p,u)
 local reduction=helper('get_unit_dr',u,E.cc_flags and E.cc_flags.STUN,0)
 -- Missing native DR is permitted only while the local confirmed-cast lockout
 -- is clear. This keeps Arena control functional on hosts that report nil DR.
 return stun_safe(p,u) and (reduction==nil or reduction>=1)
end
local harmless_debuffs={[3409]=true,[8680]=true,[5760]=true,[381637]=true,
 [408]=true,[1833]=true,[853]=true,[30283]=true,[5211]=true,[119381]=true,[1330]=true}
local function clean_for_breakable(u)
 if present(u,Lib.S.GARROTE) or present(u,Lib.S.RUPTURE) or present(u,Lib.S.DEATHMARK) or present(u,Lib.S.KINGSBANE) then return false end
 -- CC duration reduction is not a DoT classifier. Check foreign debuffs too.
 local debuffs=call(u,'get_debuffs')
 if type(debuffs)~='table' then return false end
 for _,a in pairs(debuffs) do
  local id=read(function()return a.spell_id or a.buff_id or a.debuff_id or a.id end)
  if not harmless_debuffs[id] then return false end
 end
 return true
end

local function evaluate_sap(c)
 local sap_id=c.sap_id
 c.sap_candidate=nil;c.sap_target='none'
  if not c.pvp or c.training then c.sap_status='not a live PvP profile';return end
 if not opts.cc or not c.profile.cc or not c.profile.opener then c.sap_status='CC or opener disabled';return end
 if call(c.player,'is_mounted')~=false or call(c.player,'is_flying')==true or call(c.player,'is_falling')==true then
  c.sap_status='mounted / unsafe movement';return end
  if not c.stealth then c.sap_status='Stealth required';return end
 local best,range=nil,math.huge
 local nearest,nearest_range=nil,math.huge
 for _,u in ipairs(c.enemies) do
  if control_candidate(u,c.target) and enemy(c.player,u) then
   local distance=dist(c.player,u)
   if distance<nearest_range then nearest,nearest_range=u,distance end
   -- Some arena hosts expose no combat boolean during the preparation phase.
   -- Sap remains intrinsically combat-restricted, so treat only nil/false as a
   -- pre-combat candidate and let the spell usability check reject stale data.
   if call(u,'is_in_combat')~=true and los(c.player,u) and not protected(u) and not breakable(u)
      and helper('is_cc_immune',u,nil,500)~=true
      and read(core.spell_book.is_spell_in_range,sap_id,u,c.player)==true and clean_for_breakable(u) then
    local reduction=helper('get_unit_dr',u,E.cc_flags and E.cc_flags.INCAPACITATE,0)
    local local_cc=State.cc_history[guid(u)]
    local raw_reduction=call(u,'get_dr',E.cc_flags and E.cc_flags.INCAPACITATE,0)
    local invalid_sentinel=type(raw_reduction)=='number' and (raw_reduction<0 or raw_reduction>1.01)
    local fresh_opening=reduction==nil and not invalid_sentinel and not local_cc and call(c.player,'is_in_combat')~=true
    if (type(reduction)=='number' and reduction>=0.5 or fresh_opening) and distance<range then best,range=u,distance end
   end
  end
 end
 local candidate=best or nearest
 if not candidate then c.sap_status=healer(c.target) and 'healer selected for kill: eligible DPS focus required' or 'no confirmed enemy healer detected';return end
 c.sap_target=call(candidate,'get_name') or guid(candidate)
 if best then
  if ready(sap_id) then c.sap_candidate=best;c.sap_status='eligible: automatic healer / focus Sap'
  else c.sap_status=State.ready_failure end
 elseif call(candidate,'is_in_combat')==true then c.sap_status='candidate in combat'
 elseif protected(candidate) or helper('is_cc_immune',candidate,nil,500)==true then c.sap_status='candidate immune'
 elseif breakable(candidate) then c.sap_status='candidate already controlled'
 elseif not los(c.player,candidate) then c.sap_status='candidate outside line of sight'
 elseif read(core.spell_book.is_spell_in_range,sap_id,candidate,c.player)~=true then c.sap_status='candidate outside Sap range'
 elseif not clean_for_breakable(candidate) then c.sap_status='candidate has DoTs or debuff safety unavailable'
 else c.sap_status='incapacitate DR unavailable / too diminished' end
end
local function sap_healer(c)
 if c.sap_candidate then return attempt(action(c.sap_id,c.sap_candidate,'automatic in-range off-target Sap before opener'),c) end
 if c.pvp and not c.training and now()-State.sap_log_time>=2 then
  State.sap_log_time=now()
  Lib.T.note('SAP_BLOCKED',{'target='..c.sap_target,'reason='..c.sap_status,'stealth='..tostring(c.stealth),
   'enemies='..#c.enemies,'kill_target='..tostring(c.target_name),'kill_is_healer='..tostring(healer(c.target))})
 end
end
local function control_remaining(u)
 local best=0
 local local_cc=State.cc_history[guid(u)]
 if local_cc and (local_cc.stun_active_until or 0)>now() then best=math.max(best,local_cc.stun_active_until-now()) end
 if local_cc and (local_cc.lockout_until or 0)>now() then best=math.max(best,local_cc.lockout_until-now()) end
 if local_cc and (local_cc.break_until or 0)>now() then best=math.max(best,local_cc.break_until-now()) end
 local observed=false
 for _,id in ipairs({11297,2070,6770,2094,11286,8629,1777,1776,8643,408,1833,853,30283,5211,119381,1330}) do
  if present(u,id) then
   observed=true
   local remaining=Lib.A.remaining(u,id)
   if type(remaining)~='number' then return math.huge end
   best=math.max(best,remaining)
  end
 end
 if call(u,'is_stunned',700)==true and not observed then best=math.max(best,1) end
 return best
end
local function control_chain_clear(u)
 return control_remaining(u)<=0.7
end

local function control(c)
 local mobile=c.pvp and not c.training and c.self_hp>45 and call(c.player,'is_mounted')==false
   and call(c.player,'is_falling')~=true and call(c.player,'is_flying')~=true
 local plan=Lib.StepCC.current(now(),c.target,mobile and opts.step_cc and opts.cc and c.profile.cc)
 if plan then
  local destination=plan.phase=='back' and plan.kill or plan.focus
  if not enemy(c.player,destination) or protected(destination) or not los(c.player,destination) then
   -- If Step-out already succeeded, abort the CC cast into a newly invalid
   -- focus but preserve the return Step instead of stranding beside the healer.
   if plan.phase=='cc' then Lib.StepCC.confirm(plan.cc,plan.focus,false);return true end
   Lib.StepCC.reset()
 elseif not Lib.PvP.tether_safe(c,destination,{dist=dist,los=los,cc=function(u)return helper('is_crowd_controlled',u,nil,0)==true end}) then Lib.StepCC.reset()
  elseif plan.phase=='cc' and (plan.cc==Lib.S.KICK or Lib.Forever.is_spell('KICK',plan.cc)) then
   if call(plan.focus,'is_casting_spell')~=true and call(plan.focus,'is_channelling_spell')~=true then
    Lib.StepCC.confirm(plan.cc,plan.focus,false)
   elseif attempt(action(plan.cc,plan.focus,'Step Kick: confirmed arrival, stop healer cast'),c) then return true end
  elseif plan.phase=='cc' and control_chain_clear(plan.focus) then
   if Lib.Forever.is_spell('KIDNEY',plan.cc) and not full_stun(c.player,plan.focus) then Lib.StepCC.confirm(plan.cc,plan.focus,false)
   elseif attempt(action(plan.cc,plan.focus,'Step setup: confirmed arrival, healer control'),c) then return true end
  elseif plan.phase=='cc' then
   -- Another player landed control during our travel. Do not overwrite it or
   -- wait beside the healer; advance directly to the return-Step phase.
   Lib.StepCC.confirm(plan.cc,plan.focus,false);return true
  elseif plan.phase=='back' and dist(c.player,plan.kill)<=5 then Lib.StepCC.reset()
  elseif attempt(action(Lib.S.STEP,destination,plan.phase=='out' and 'Step to healer control' or 'Step back to kill target'),c) then return true end
  if Lib.StepCC.current(now(),c.target,true) then return true end
 end
 local casters={}
 for _,u in ipairs(c.enemies) do
  if opts.interrupt and not protected(u) and not breakable(u) and los(c.player,u)
     and (call(u,"is_casting_spell")==true or call(u,"is_channelling_spell")==true) then
   local protect_healer=Lib.PvP.cast_targets_friendly_healer(u,c,{cast_target=function(v)return call(v,'get_active_spell_target') end,
    same=function(a,b)return guid(a)==guid(b) end})
   local channel=call(u,'is_channelling_spell')==true
   local spell_id=channel and call(u,'get_active_channel_spell_id') or call(u,'get_active_spell_id')
   local finish=channel and call(u,'get_active_channel_cast_end_time') or call(u,'get_active_spell_cast_end_time')
   local remaining=type(finish)=='number' and math.max(0,finish-now()) or nil
   local learned,samples=Lib.ThreatLearning.pressure(c.mode,spell_id,call(c.player,'get_max_health'))
   local cast_target=call(u,'get_active_spell_target')
   local targets_self=cast_target and guid(cast_target)==guid(c.player)
   local targets_ally=alive(cast_target) and guid(cast_target)~=guid(c.player) and call(cast_target,'is_enemy_with',c.player)==false
   local deferred,left=Lib.InterruptCoordination.defer(u,now(),guid)
   if deferred then c.interrupt_wait='ally interrupt observed / wait '..string.format('%.2fs',left)
   else casters[#casters+1]={unit=u,protect_healer=protect_healer,score=Lib.PvP.interrupt_score(u,{healer=healer,
    protect=function()return protect_healer end,current=function(v)return guid(v)==guid(c.target) end,dist=function(v)return dist(c.player,v) end,
    self_target=function()return targets_self end,ally_target=function()return targets_ally end,channel=function()return channel end,
    danger=function()return learned end,priority=function(v)return Lib.CastPriority.score(spell_id)+Lib.BossCoach.interrupt_bonus(c,v,guid) end,
    remaining=function()return remaining end}),spell_id=spell_id,learned=learned,samples=samples,
    targets_self=targets_self,targets_ally=targets_ally,remaining=remaining} end
  end
 end
 table.sort(casters,function(a,b)return a.score>b.score end)
 local top=casters[1]
 if top then
  c.dangerous_cast_score=top.score;c.dangerous_cast_spell=top.spell_id;c.dangerous_cast_learned=top.learned;c.dangerous_cast_samples=top.samples
  local signature=table.concat({tostring(guid(top.unit)),tostring(top.spell_id),string.format('%.1f',top.score)},':')
  if signature~=State.triage_signature or now()-State.triage_time>=1 then
   State.triage_signature=signature;State.triage_time=now();Lib.T.note('CAST_TRIAGE',{'mode='..c.mode,'target='..tostring(call(top.unit,'get_name')),
    'spell='..tostring(top.spell_id),'score='..string.format('%.1f',top.score),'learned='..string.format('%.1f',top.learned or 0),
    'samples='..tostring(top.samples),'self_target='..tostring(top.targets_self),'ally_target='..tostring(top.targets_ally),'remaining='..tostring(top.remaining)})
  end
 end
 if top and not c.pvp and opts.cc and c.profile.cc and c.aoe_safe
    and talent(Lib.S.AIRBORNE_IRRITANT,'Airborne Irritant') and ready(c.blind_id) then
  local clustered=0
  for _,row in ipairs(casters) do
   if call(row.unit,'is_boss')~=true and dist(top.unit,row.unit)<=10 then clustered=clustered+1 end
  end
  if clustered>=2 and attempt(action(c.blind_id,top.unit,'Airborne Irritant: stop clustered casts'),c) then return true end
 end
 for _,row in ipairs(casters) do
   local u=row.unit
   local interrupt_now,remaining,timing=Lib.PvP.interrupt_timing(u,now(),c.pvp,{
    channel=function(v)return call(v,'is_channelling_spell')==true end,
    finish=function(v)return call(v,'get_active_spell_cast_end_time') end,
    healer=healer,urgent=row.protect_healer or Lib.CastPriority.score(row.spell_id)>=80
     or Lib.BossCoach.interrupt_bonus(c,u,guid)>0 or c.self_hp<=40 or c.friendly_healer_present and not c.friendly_healer_available,
    buffer=State.cast_latency})
   if not interrupt_now then
    c.interrupt_wait=(call(u,'get_name') or guid(u))..' / '..timing
   else
   local interruptible=call(u,"is_active_spell_interruptable")
   local known_name=Lib.CastPriority.name(row.spell_id)
   local reason=row.protect_healer and "protect friendly healer: interrupt targeted cast"
    or Lib.BossCoach.interrupt_bonus(c,u,guid)>0 and "boss mechanic: stop priority add cast"
    or known_name and ("Season 2 priority cast: "..known_name)
    or row.targets_self and row.learned>=10 and "learned dangerous cast targeting player"
    or row.targets_ally and row.learned>=10 and "learned dangerous cast targeting ally"
    or healer(u) and "interrupt healer cast / channel" or "interrupt verified cast / channel"
   local kick_range=read(core.spell_book.is_spell_in_range,c.kick_id,u,c.player)==true
   local step_charges=read(core.spell_book.get_spell_charge,Lib.S.STEP)
   local priority_step=row.protect_healer or Lib.CastPriority.score(row.spell_id)>=80
    or row.targets_self and (row.learned or 0)>=10
   if interruptible==true and c.pvp and (healer(u) or priority_step) and not kick_range and opts.step_cc and mobile
      and type(step_charges)=='number' and step_charges>=2 and ready(Lib.S.STEP)
      and guid(u)~=guid(c.target) and dist(c.player,u)<=25
      and Lib.PvP.tether_safe(c,u,{dist=dist,los=los,cc=function(v)return helper('is_crowd_controlled',v,nil,0)==true end})
      and Lib.StepCC.start(c.target,u,c.kick_id,now()) then
    if attempt(action(Lib.S.STEP,u,healer(u) and 'Step to healer Kick: reserve return charge'
       or 'Step to priority Kick: reserve return charge'),c) then return true end
    Lib.StepCC.reset()
   end
   if interruptible==true and attempt(action(c.kick_id,u,reason),c) then return true end
   local stop_safe=interruptible==true or interruptible==false and call(u,'is_boss')~=true
    and helper('is_cc_immune',u,E.cc_flags and E.cc_flags.STUN,0)==false
   if stop_safe and not c.pvp and opts.cc and c.profile.cc and call(u,'is_boss')~=true
      and helper('is_cc_immune',u,E.cc_flags and E.cc_flags.INCAPACITATE,0)~=true and clean_for_breakable(u) then
    local incap=helper('get_unit_dr',u,E.cc_flags and E.cc_flags.INCAPACITATE,0)
    if (type(incap)~='number' or incap>=0.5) and attempt(action(c.gouge_id,u,'PvE cast stop: Kick unavailable; preserve combo points'),c) then return true end
   end
   if stop_safe and opts.cc and c.profile.cc and c.cp>=5 and stun_safe(c.player,u) then
    if attempt(action(c.kidney_id,u,"cast stop: Kick unavailable"),c) then return true end
   end
   if stop_safe and not c.pvp and opts.cc and c.profile.cc and not breakable(u) then
    if attempt(action(c.blind_id,u,"PvE cast stop: Kick, Gouge and Kidney unavailable"),c) then return true end
   end
   end
 end
 if opts.cc and c.profile.cc and c.self_peel_urgent and enemy(c.player,c.self_peel_target) and los(c.player,c.self_peel_target)
    and not protected(c.self_peel_target) and not breakable(c.self_peel_target) then
  local u=c.self_peel_target
  if c.self_peel_disarmable and attempt(action(Lib.S.DISMANTLE,u,'emergency self peel: disarm attacker'),c) then return true end
  if c.cp>=5 and full_stun(c.player,u) and attempt(action(c.kidney_id,u,'emergency self peel: full Kidney attacker'),c) then return true end
  if clean_for_breakable(u) then
   local incap=helper('get_unit_dr',u,E.cc_flags and E.cc_flags.INCAPACITATE,0)
   if type(incap)=='number' and incap>=0.5 and attempt(action(c.gouge_id,u,'emergency self peel: Gouge attacker'),c) then return true end
   local disorient=helper('get_unit_dr',u,E.cc_flags and E.cc_flags.DISORIENT,0)
   if c.self_hp<=30 and type(disorient)=='number' and disorient>=0.5
      and attempt(action(c.blind_id,u,'emergency self peel: Blind attacker'),c) then return true end
  end
 end
 if not opts.cc or not c.profile.cc then c.cc_status='CC disabled';return end
 -- Preserve offensive healer CC while the selected kill target has confirmed
 -- mitigation. Emergency self/ally peel branches above remain available.
 local pressure=not c.damage_reduced and c.bleeds_ready and (c.target_hp<=60 or c.envenom_active or c.kill_intent or c.kill_window or c.deathmark or c.burst_requested)
 local step_focus=c.control_focus
 local cross_control=c.target_stunned==true
 c.cross_control_ready=cross_control
 -- A healer who sits a trinketless Blind can leave combat before it expires.
 -- Reserve a safe Vanish, then Sap only after Blind ends and Sap is legal.
 if State.blind_chain_target and now()>State.blind_chain_until+2 then
  State.blind_chain_target=nil;State.blind_chain_until=-math.huge
 end
 if c.mode=='arena' and step_focus and guid(step_focus)==State.blind_chain_target and c.healer_trinket_down
    and enemy(c.player,step_focus) and healer(step_focus) and call(step_focus,'is_in_combat')==false
    and los(c.player,step_focus) and not protected(step_focus) and clean_for_breakable(step_focus) then
  local sap_dr=helper('get_unit_dr',step_focus,E.cc_flags and E.cc_flags.INCAPACITATE,0)
  if now()>=State.blind_chain_until and c.stealth and type(sap_dr)=='number' and sap_dr>=0.5
     and read(core.spell_book.is_spell_in_range,c.sap_id,step_focus,c.player)==true then
   if attempt(action(c.sap_id,step_focus,'trinketless healer chain: Sap after Blind'),c) then return true end
  elseif now()>=State.blind_chain_until-1 and not c.stealth and c.self_hp>=70 and (c.attackers or 0)<=1
     and (c.defensive_reserves or 0)>=2 and ready(c.vanish_id) then
   if attempt(action(c.vanish_id,c.player,'trinketless healer chain: Vanish before Sap'),c) then return true end
  end
 end
 if mobile and pressure and cross_control and c.cp>=5 and c.energy>=25
    and enemy(c.player,step_focus) and control_candidate(step_focus,c.target) and full_stun(c.player,step_focus)
    and control_chain_clear(step_focus)
    and not c.bomb_opener and dist(c.player,step_focus)<=5 and read(core.spell_book.is_spell_in_range,c.kidney_id,step_focus,c.player)==true then
  if attempt(action(c.kidney_id,step_focus,'automatic full Kidney: in-range off-target kill setup'),c) then return true end
 end
 local charges=read(core.spell_book.get_spell_charge,Lib.S.STEP)
 if opts.step_cc and mobile and not c.bomb_opener and pressure and cross_control and c.cp>=5 and c.energy>=45
    and type(charges)=='number' and charges>=2 and ready(Lib.S.STEP) and ready(c.kidney_id)
    and enemy(c.player,step_focus) and control_candidate(step_focus,c.target)
    and control_chain_clear(step_focus)
    and dist(c.player,step_focus)>5 and dist(c.player,step_focus)<=25
    and dist(step_focus,c.target)<=25 and full_stun(c.player,step_focus)
    and Lib.PvP.tether_safe(c,step_focus,{dist=dist,los=los,cc=function(u)return helper('is_crowd_controlled',u,nil,0)==true end})
    and Lib.PvP.tether_safe(c,c.target,{dist=dist,los=los,cc=function(u)return helper('is_crowd_controlled',u,nil,0)==true end}) then
  Lib.StepCC.start(c.target,step_focus,c.kidney_id,now())
  if attempt(action(Lib.S.STEP,step_focus,'Step to healer: reserve return charge'),c) then return true end
  Lib.StepCC.reset()
 end

 -- Sap/Blind/Gouge require a valid off-target control candidate, no visible DoTs,
 -- a readable debuff list, line of sight and usable DR data.
 local focus=c.control_focus
 c.cc_status=focus and ('control target='..tostring(call(focus,'get_name'))..'; evaluate range / DR / setup') or 'No eligible off-target control candidate'
 -- Once the healer is securely controlled and the poison package is already
 -- running, Vanish may extend the kill target's pressure with Improved
 -- Garrote. Keep the trade narrow: the target must be Kidney-stunned, the
 -- Rogue must have another major defensive, and the go must be unmitigated.
 if now()>=State.arena_vanish_kill_until then State.arena_vanish_kill=nil;State.arena_vanish_kill_stage=nil end
 local reserved_kill_chain=guid(c.target)==State.arena_vanish_kill and now()<State.arena_vanish_kill_until
 local kill_chain_safe=reserved_kill_chain and c.stealth and enemy(c.player,c.target) and not protected(c.target)
    and not breakable(c.target) and los(c.player,c.target) and dist(c.player,c.target)<=5
 if kill_chain_safe and (State.arena_vanish_kill_stage=='garrote1' or State.arena_vanish_kill_stage=='garrote2')
    and read(core.spell_book.is_spell_in_range,Lib.S.GARROTE,c.target,c.player)==true then
  local reason=State.arena_vanish_kill_stage=='garrote1' and 'Arena poison go: first Improved Garrote'
    or 'Arena poison go: second Improved Garrote after Cheap Shot'
  if attempt(action(Lib.S.GARROTE,c.target,reason),c) then return true end
 end
 if kill_chain_safe and State.arena_vanish_kill_stage=='cheap' then
  local stun_dr=helper('get_unit_dr',c.target,E.cc_flags and E.cc_flags.STUN,0)
  if type(stun_dr)=='number' and stun_dr>=0.25
     and read(core.spell_book.is_spell_in_range,Lib.S.CHEAP,c.target,c.player)==true then
   if attempt(action(Lib.S.CHEAP,c.target,'Arena poison go: Cheap Shot between Improved Garrotes'),c) then return true end
  end
 end
 if c.mode=='arena' and not c.stealth and c.improved_talent and c.kill_window and c.target_stunned
    and c.healer_cc_secure and c.bleeds_ready and c.envenom_active
    and (c.kingsbane_active or c.deathmark and not known(Lib.S.KINGSBANE))
    and not c.damage_reduced and not c.target_defensive and not c.healer_external
    and c.energy>=45 and c.self_hp>=80 and (c.attackers or 0)<=1 and (c.defensive_reserves or 0)>=2
    and enemy(c.player,c.target) and not protected(c.target) and not breakable(c.target)
    and los(c.player,c.target) and dist(c.player,c.target)<=5
    and read(core.spell_book.is_spell_in_range,Lib.S.GARROTE,c.target,c.player)==true and ready(c.vanish_id) then
  State.arena_vanish_kill=guid(c.target);State.arena_vanish_kill_stage='garrote1';State.arena_vanish_kill_until=now()+6
  if attempt(action(c.vanish_id,c.player,'Arena poison go: Vanish for Improved Garrote'),c) then return true end
  State.arena_vanish_kill=nil;State.arena_vanish_kill_stage=nil;State.arena_vanish_kill_until=-math.huge
 end
 -- Convert a safe offensive Vanish into a guaranteed healer Garrote silence
 -- during a real poison go. Preserve Vanish whenever survival, positioning,
 -- or the next major-control global is uncertain.
 local poison_go=c.deathmark or c.kingsbane_active or ready(Lib.S.DEATHMARK) or ready(Lib.S.KINGSBANE)
 if c.mode=='arena' and not c.stealth and c.kill_window and c.target_stunned and c.bleeds_ready and poison_go
    and not c.healer_cc_secure and c.self_hp>=75 and (c.attackers or 0)<=1 and (c.defensive_reserves or 0)>=2
    and enemy(c.player,focus) and healer(focus) and control_candidate(focus,c.target)
    and control_chain_clear(focus) and not protected(focus) and not breakable(focus)
    and los(c.player,focus) and dist(c.player,focus)<=5 and not present(focus,Lib.S.GARROTE)
    and read(core.spell_book.is_spell_in_range,Lib.S.GARROTE,focus,c.player)==true and ready(c.vanish_id) then
  State.arena_vanish_focus=guid(focus);State.arena_vanish_until=now()+4
  if attempt(action(c.vanish_id,c.player,'Arena offensive Vanish: reserve healer Garrote silence'),c) then return true end
  State.arena_vanish_focus=nil;State.arena_vanish_until=-math.huge
 end
 -- Current Assassination PvP uses Subterfuge Garrote as an off-target silence.
 -- Prefer it when a healer is casting or stun DR is unavailable, but only
 -- during established pressure and never into immunity or existing control.
 local reserved_garrote=guid(focus)==State.arena_vanish_focus and now()<State.arena_vanish_until
 if c.game_branch~='forever' and c.stealth and pressure and enemy(c.player,focus) and control_candidate(focus,c.target)
    and healer(focus) and control_chain_clear(focus) and not protected(focus) and not breakable(focus)
    and los(c.player,focus) and not present(focus,Lib.S.GARROTE)
    and (reserved_garrote or call(focus,'is_casting_spell')==true or call(focus,'is_channelling_spell')==true
      or helper('get_unit_dr',focus,E.cc_flags and E.cc_flags.STUN,0)==nil) then
  if attempt(action(Lib.S.GARROTE,focus,reserved_garrote and 'Arena offensive Vanish: healer Garrote silence' or 'stealth off-target Garrote silence during pressure'),c) then return true end
 end
 if c.stealth and enemy(c.player,focus) and control_candidate(focus,c.target) and full_stun(c.player,focus) and control_chain_clear(focus) then
  if attempt(action(Lib.S.CHEAP,focus,'stealth off-target Cheap Shot setup'),c) then return true end
 end
 if enemy(c.player,focus) and control_candidate(focus,c.target) and los(c.player,focus) and not protected(focus) and helper("is_cc_immune",focus,nil,500)~=true and not breakable(focus) then
  local debuffs=call(focus,"get_debuffs");local reduction=helper("get_unit_dr",focus,E.cc_flags and E.cc_flags.INCAPACITATE,0)
  if clean_for_breakable(focus) and control_chain_clear(focus) then
   local blind_dr=helper('get_unit_dr',focus,E.cc_flags and E.cc_flags.DISORIENT,0)
   if c.stealth and call(focus,"is_in_combat")==false then
    if type(reduction)=='number' and reduction>=0.5 and attempt(action(c.sap_id,focus,"focus healer opener"),c) then return true end
   elseif c.target_stunned or c.bleeds_ready and pressure or c.self_hp<=50 or c.attackers>=2 then
    -- Blind is strongest after observed trinket usage; otherwise prefer Gouge.
    if c.healer_trinket_down and type(blind_dr)=='number' and blind_dr>=0.5 then
     if attempt(action(c.blind_id,focus,"kill window: healer trinket observed"),c) then return true end
    end
    if type(reduction)=='number' and reduction>=0.5 and attempt(action(c.gouge_id,focus,"kill window: focus healer control"),c) then return true end
    if (pressure or c.target_stunned or c.self_hp<=50 or c.attackers>=2 or (c.blind_ready_age or 0)>=35 and c.bleeds_ready)
       and type(blind_dr)=='number' and blind_dr>=0.5
       and attempt(action(c.blind_id,focus,(c.blind_ready_age or 0)>=35 and "CC cadence: off-target Blind has remained ready" or "automatic kill window: off-target Blind"),c) then return true end
   end
  end
 end
 local disarm=Lib.P.offensive_disarm(c)
 if disarm and attempt(disarm,c) then return true end
 if c.peel_urgent and enemy(c.player,c.peel_target) and c.cp>=5 and full_stun(c.player,c.peel_target) then
  if attempt(action(c.kidney_id,c.peel_target,'emergency peel: attacker threatening critical ally'),c) then return true end
 end
 -- Otherwise reserve Dismantle for a melee attacker threatening an injured ally.
 if c.pvp then for _,u in ipairs(c.enemies) do
  local victim=call(u,"get_target");local vh=hp(victim)
  if alive(victim) and call(victim,"is_enemy_with",c.player)==false and vh and vh<=40
     and helper("is_disarmable",u)==true and dist(u,victim)<=5 and not protected(u) and not breakable(u) and los(c.player,u) then
   if attempt(action(Lib.S.DISMANTLE,u,"peel close attacker from injured ally"),c) then return true end
  end
 end end
end
local function make_context(p,target,profile,list)
 local cp=call(p,"get_power",E.power_type and E.power_type.COMBOPOINTS or 4)
 local energy=call(p,"get_power",E.power_type and E.power_type.ENERGY or 3)
 if type(cp)~="number" or type(energy)~="number" then return nil end
 local max=call(p,"get_max_power",E.power_type and E.power_type.COMBOPOINTS or 4)
 local pvp=mode=="arena" or mode=="battleground" or mode=="world_pvp"
 local c={player=p,target=target,profile=profile,mode=mode,pvp=pvp,cp=cp,cp_max=type(max)=="number" and max or 5,
  level=tonumber(call(p,'get_level')) or tonumber(read(core.get_player_level)),
  energy=energy,self_hp=hp(p) or 100,target_hp=hp(target) or 100,nearby=0,attackers=0,player_attackers=0,pet_attackers=0,ally_threats=0,interrupt_opportunities=0,enemies={},aoe_safe=true,
   spread_needed=false,ready=ready,known=known,cd=cd,refresh=refresh,
   remaining=function(u,id)return Lib.A.remaining(u,id) or 0 end,
   stacks=function(u,id)return Lib.A.stacks(u,id) or 0 end,
  stun_safe=function(u) return stun_safe(p,u) end,opener=profile.opener,
  full_stun_safe=function(u) return full_stun(p,u) end,
  cooldowns=profile.cooldowns,cc_enabled=opts.cc and profile.cc,offensive_vanish=opts.offensive_vanish and mode~="delve",
  elapsed=now()-opening.start,open_done=opening.done,open_garrote=opening.garrote>0,
  open_garrote_count=opening.garrote,open_rupture=opening.rupture,open_envenom=opening.envenom,
  stealth=present(p,Lib.S.STEALTH) or present(p,115191) or present(p,11327) or present(p,Lib.S.VANISH) or present(p,Lib.S.SUBTERFUGE),
  darkest=present(p,Lib.S.DARKEST_NIGHT),improved=present(p,Lib.S.IMPROVED_GARROTE),
  blindside=present(p,121153),kingsbane_gain=talent(Lib.S.IMPLACABLE_FINAL,"Implacable Kingsbane") and 6 or 1,
  improved_talent=talent(Lib.S.IMPROVED_GARROTE,"Improved Garrote"),
  boss=call(target,"is_boss")==true,ttd=call(target,"get_time_to_die"),target_class=call(target,'get_class'),target_healer=healer(target),
  target_race=call(target,'get_race') or call(target,'get_race_id'),
  target_stunned=stunned(target) or State.cc_history[guid(target)] and (State.cc_history[guid(target)].stun_active_until or 0)>now(),healer_cc=false,ally_burst=false,ally_burst_target=nil,self_peel_target=nil,friendly_healers={},friendly_tank=nil,friendly_healer_smoke_cover=false,burst_requested=now()<State.manual_burst_until,
  target_key=alive(target) and guid(target) or nil,healer_present=false,
  target_debuffs_readable=type(call(target,'get_debuffs'))=='table',
  blind_chain_target=State.blind_chain_target,blind_chain_remaining=math.max(0,State.blind_chain_until-now()),
  trinket_recent=helper("trinket_used_within",target,60)==true,smoke_range=dist(p,target)<=5,
  kidney_cd=cd(Lib.S.KIDNEY),
  damage_reduced=helper("has_damage_reduction",target,50,nil,500)==true,
  last=last,pending=pending and pending.id or "none"}
 local keystone=mode=='mythic_plus' and read(core.world and core.world.get_active_keystone_info) or nil
 c.keystone_level=type(keystone)=='table' and tonumber(keystone.level) or nil
 if type(keystone)=='table' and type(keystone.affix_ids)=='table' then
  for _,affix_id in ipairs(keystone.affix_ids) do
   if tonumber(affix_id)==10 then c.fortified=true elseif tonumber(affix_id)==9 then c.tyrannical=true end
  end
 end
 if game_branch=='forever' then c.lethal_poison,c.utility_poison=Lib.Forever.poison_plan(c)
 elseif c.pvp then c.utility_poison=Lib.S.CRIPPLING
 elseif c.mode=='mythic_plus' and c.fortified then c.utility_poison=known(Lib.S.NUMBING) and Lib.S.NUMBING or Lib.S.ATROPHIC
 else c.utility_poison=known(Lib.S.ATROPHIC) and Lib.S.ATROPHIC or Lib.S.NUMBING end
 c.hero=talent(Lib.S.MARK,"Deathstalker's Mark") and "Deathstalker" or talent(Lib.S.HAND_OF_FATE,"Hand of Fate") and "Fatebound" or "Unknown"
 c.dampening_active=c.pvp and present(p,Lib.S.DAMPENING) or false
 c.dampening_stacks=c.dampening_active and Lib.A.stacks(p,Lib.S.DAMPENING) or nil
 c.high_dampening=type(c.dampening_stacks)=='number' and c.dampening_stacks>=30
 c.target_marked=present(target,Lib.S.MARK);c.mark_elsewhere=nil
 c.player_flag_carrier=call(p,'is_flag_carrier')==true or call(p,'has_flag')==true
 c.gouge_id=game_branch=='forever' and (Lib.Forever.spell(c,'GOUGE') or 0) or Lib.S.GOUGE
 c.kidney_id=game_branch=='forever' and (Lib.Forever.spell(c,'KIDNEY') or 0) or Lib.S.KIDNEY
 c.blind_id=game_branch=='forever' and (Lib.Forever.spell(c,'BLIND') or 0) or Lib.S.BLIND
 c.sprint_id=game_branch=='forever' and (Lib.Forever.spell(c,'SPRINT') or 0) or Lib.S.SPRINT
 c.vanish_id=game_branch=='forever' and (Lib.Forever.spell(c,'VANISH') or 0) or Lib.S.VANISH
 c.evasion_id=game_branch=='forever' and (Lib.Forever.spell(c,'EVASION') or 0) or Lib.S.EVASION
 c.defensive_reserves=(known(Lib.S.CLOAK) and cd(Lib.S.CLOAK)<=0.05 and 1 or 0)
  +(c.evasion_id and cd(c.evasion_id)<=0.05 and 1 or 0)
  +(not c.player_flag_carrier and c.vanish_id and cd(c.vanish_id)<=0.05 and 1 or 0)
 c.defensive_dry=c.pvp and c.defensive_reserves==0
 c.kick_id=game_branch=='forever' and (Lib.Forever.spell(c,'KICK') or 0) or Lib.S.KICK
 c.kick_ready=opts.interrupt and c.kick_id~=nil and cd(c.kick_id)<=0.05
 c.kidney_cd=cd(c.kidney_id)
 c.bleeds_ready=not refresh(target,Lib.S.GARROTE,0) and not refresh(target,Lib.S.RUPTURE,0)
 c.bomb_opener=pvp and profile.cooldowns and opts.cc and profile.cc and not c.damage_reduced and c.self_hp>45
  and known(Lib.S.SMOKE) and cd(Lib.S.SMOKE)<=0 and (known(Lib.S.DEATHMARK) and cd(Lib.S.DEATHMARK)<=2 or known(Lib.S.KINGSBANE) and cd(Lib.S.KINGSBANE)<=2)
 c.kill_kidney_confirmed=State.kill_kidney~=nil and State.kill_kidney.target==guid(target) and now()<State.kill_kidney.expires
 c.unshakeable_drive=talent(Lib.S.UNSHAKEABLE_DRIVE,'Unshakeable Drive')
 c.unshakeable_stacks=c.unshakeable_drive and Lib.A.stacks(p,Lib.S.UNSHAKEABLE_DRIVE_BUFF) or nil
 c.shiv_pressure=c.pvp and present(p,Lib.S.CRIPPLING) and call(target,'is_moving')==true and not present(target,3409)
 c.kingsbane_active=present(target,Lib.S.KINGSBANE) or (State.dot_history[guid(target)] and (State.dot_history[guid(target)][Lib.S.KINGSBANE] or 0)>now()) or false
 c.offensive_garrote_pending=State.improved_refresh_target==guid(target) and now()<State.improved_refresh_until
 c.offensive_garrote_due=c.offensive_garrote_pending
 -- Keep the original field for telemetry and backward-compatible diagnostics.
 c.offensive_garrote=c.offensive_garrote_pending
 c.hemotoxin=talent(Lib.S.HEMOTOXIN,'Hemotoxin');c.system_shock=talent(Lib.S.SYSTEM_SHOCK,'System Shock')
 c.deathmark=present(target,Lib.S.DEATHMARK) or (State.dot_history[guid(target)] and (State.dot_history[guid(target)][Lib.S.DEATHMARK] or 0)>now()) or false
 for _,u in pairs(list) do
  if enemy(p,u) then
   local d=dist(p,u)
   if guid(u)~=guid(target) and present(u,Lib.S.MARK) then c.mark_elsewhere=u end
   if d<=40 and (not pvp or call(u,"is_player")==true) then c.enemies[#c.enemies+1]=u end
   Lib.TargetForecast.observe(guid(u),now(),hp(u))
   if d<=10 then
    local practice=opts.dummy_test and dummy(target) and dummy(u)
    if breakable(u) or protected(u) or (call(u,"is_in_combat")~=true and not practice) then c.aoe_safe=false end
    if (call(u,"is_in_combat")==true or practice) and (not pvp or call(u,"is_player")==true or practice) then
     c.nearby=c.nearby+1
     if refresh(u,Lib.S.GARROTE,0) or refresh(u,Lib.S.RUPTURE,0) then c.spread_needed=true end
    end
   end
   local victim=call(u,"get_target")
   if victim and guid(victim)==guid(p) then
    local player_threat=not pvp or call(u,'is_player')==true
    if not pvp then c.attackers=c.attackers+1
    elseif player_threat then c.player_attackers=c.player_attackers+1
    else c.pet_attackers=c.pet_attackers+1 end
    if player_threat then
     if d<=5 and (not pvp or helper("is_melee",u)==true or call(u,'is_auto_attacking')==true) then c.melee_pressure=true end
     if helper("has_burst_active",u,500)==true then c.focus_burst=true end
     if call(u,"is_casting_spell")==true then c.magic_pressure=true end
     local peel_score=(helper('is_disarmable',u)==true and 30 or 0)+(helper('has_burst_active',u,500)==true and 40 or 0)-d
     if d<=15 and not protected(u) and not breakable(u) and (not c.self_peel_score or peel_score>c.self_peel_score) then
      c.self_peel_target=u;c.self_peel_score=peel_score;c.self_peel_disarmable=helper('is_disarmable',u)==true
     end
    end
   elseif alive(victim) and call(victim,'is_enemy_with',p)==false and call(u,'is_in_combat')==true then
    c.ally_threats=c.ally_threats+1
    if not c.peel_target or hp(victim) and hp(victim)<(c.peel_ally_hp or 101) then
     c.peel_target=u;c.peel_ally_hp=hp(victim) or 100;c.peel_target_class=call(u,'get_class')
    end
   end
   if healer(u) and dist(p,u)<=40 then
    c.healer_present=true
    local enemy_mana=mana_pct(u)
    if enemy_mana then c.enemy_healer_mana=math.min(c.enemy_healer_mana or 100,enemy_mana) end
    local cc_left=control_remaining(u)
    local local_cc=State.cc_history[guid(u)]
    if cc_left>0 then
     c.healer_cc=true
     c.healer_cc_remaining=math.max(c.healer_cc_remaining or 0,cc_left)
     if local_cc and (local_cc.lockout_until or 0)>now() then c.healer_cc_reason='confirmed Kick lockout' end
    end
   end
   if opts.interrupt and not protected(u) and not breakable(u)
      and (call(u,'is_casting_spell')==true or call(u,'is_channelling_spell')==true)
      and call(u,'is_active_spell_interruptable')==true and los(p,u) then
    local kick_actionable=c.kick_ready and read(core.spell_book.is_spell_in_range,c.kick_id,u,p)==true
    local kidney_actionable=opts.cc and profile.cc and c.cp>=5 and c.kidney_id~=0 and cd(c.kidney_id)<=0.05
     and read(core.spell_book.is_spell_in_range,c.kidney_id,u,p)==true and stun_safe(p,u)
    local blind_actionable=not c.pvp and opts.cc and profile.cc and c.blind_id~=0 and cd(c.blind_id)<=0.05
     and read(core.spell_book.is_spell_in_range,c.blind_id,u,p)==true
    if kick_actionable or kidney_actionable or blind_actionable then c.interrupt_opportunities=c.interrupt_opportunities+1 end
   end
  elseif alive(u) and guid(u)~=guid(p) and call(u,'is_player')==true then
   if not c.pvp and not c.friendly_tank and tank(u) and dist(p,u)<=40 and los(p,u) then c.friendly_tank=u end
   if c.pvp and not healer(u) and helper('has_burst_active',u,500)==true and dist(p,u)<=40 and los(p,u) then
    c.ally_burst=true;c.ally_burst_target=c.ally_burst_target or u
   end
   if healer(u) then
    c.friendly_healer_present=true
    c.friendly_healers[#c.friendly_healers+1]=u
    if dist(p,u)<=7.5 and los(p,u) then c.friendly_healer_smoke_cover=true end
    local available=dist(p,u)<=40 and los(u,p) and helper('is_immune_to_heal',p,0)~=true
     and helper('is_crowd_controlled',u,nil,0)~=true
    if available then c.friendly_healer_available=true end
    local percent=mana_pct(u)
    if percent then
     c.friendly_healer_mana=math.min(c.friendly_healer_mana or 100,percent)
    end
   end
  end
 end
 if pvp then c.attackers=c.player_attackers+math.min(1,c.pet_attackers) end
 local target_victim=call(target,'get_target')
 c.target_tanked=c.friendly_tank~=nil and target_victim~=nil and guid(target_victim)==guid(c.friendly_tank)
 c.healer_cc_secure=c.healer_cc and (c.healer_cc_remaining or math.huge)>=2.5
 c.healer_cc_expiring=c.healer_cc and not c.healer_cc_secure
 Lib.TargetForecast.prune(now())
 for _,u in ipairs(c.enemies) do
  if (call(u,'is_casting_spell')==true or call(u,'is_channelling_spell')==true)
     and Lib.PvP.cast_targets_friendly_healer(u,c,{cast_target=function(v)return call(v,'get_active_spell_target') end,
      same=function(a,b)return guid(a)==guid(b) end}) then
   c.friendly_healer_cast_threat=true
   local channel=call(u,'is_channelling_spell')==true
   local finish=channel and call(u,'get_active_channel_cast_end_time') or call(u,'get_active_spell_cast_end_time')
   local kick_reachable=c.kick_ready and call(u,'is_active_spell_interruptable')==true and los(p,u)
    and read(core.spell_book.is_spell_in_range,c.kick_id,u,p)==true
   c.friendly_healer_cast_imminent=channel or type(finish)=='number' and finish>now() and finish-now()<=0.8
   c.friendly_healer_cast_outside_bomb=dist(p,u)>8
   c.friendly_healer_cast_kick_reachable=kick_reachable
   if c.friendly_healer_cast_imminent then break end
  end
 end
 local target_forecast=Lib.TargetForecast.get(guid(target))
 c.target_loss_rate=target_forecast.rate;c.target_forecast_samples=target_forecast.samples or 0
 c.target_recovering=target_forecast.recovering==true
 c.target_casting=call(target,'is_casting_spell')==true or call(target,'is_channelling_spell')==true
 c.combat_forecast=Lib.TargetForecast.host(target,c.pvp)
 c.ttd_source=type(c.ttd)=='number' and c.ttd>0 and 'unit' or target_forecast.confident and 'health trend'
  or type(c.combat_forecast)=='number' and 'combat forecast' or 'unavailable'
 if type(c.ttd)~='number' or c.ttd<=0 then
  if target_forecast.confident then c.ttd=target_forecast.ttd
  elseif type(c.combat_forecast)=='number' then c.ttd=c.combat_forecast end
 end
 c.target_collapse=c.pvp and ((target_forecast.confident and target_forecast.ttd and target_forecast.ttd<=6)
  or (c.ttd_source=='combat forecast' and c.target_hp<=35 and c.combat_forecast<=5)) or false
 local max_energy=call(p,'get_max_power',E.power_type and E.power_type.ENERGY or 3)
 c.energy_pct=type(max_energy)=='number' and max_energy>0 and c.energy/max_energy*100 or nil
 c.envenom_remaining=Lib.A.remaining(p,Lib.S.ENVENOM) or math.max(0,State.envenom_expires-now())
 c.envenom_active=c.envenom_remaining>0
 local selected=active_talents()
 local snapshot={}
 if type(selected)=='table' then for _,t in pairs(selected) do
  if type(t)=='table' and (tonumber(t.rank) or 0)>0 then snapshot[#snapshot+1]=tostring(t.name)..':'..tostring(t.spell_id)..':'..tostring(t.rank) end
 end end
 table.sort(snapshot);local signature=table.concat(snapshot,',')
 if signature~=State.talent_signature then State.talent_signature=signature;Lib.T.note('TALENTS',{signature}) end
 if type(c.ttd)~="number" or c.ttd<=0 then c.ttd=nil end
 c.raw_nearby=c.nearby
 c.nearby=Lib.Decision.pack_count(now(),c.nearby,call(p,'is_in_combat')==true)
 local focus=read(core.input.get_focus) or call(p,"get_focus_target")
 if not (enemy(p,focus) and control_candidate(focus,target)) then
  focus=nil;local best_score=-math.huge
  for _,u in ipairs(c.enemies) do
   local distance=dist(p,u)
   if control_candidate(u,target) and distance<=30 and los(p,u) and not protected(u)
      and helper('is_cc_immune',u,nil,500)~=true then
    local score=Lib.PvP.control_score(u,now(),{dist=function(v)return dist(p,v) end,healer=healer,mana=mana_pct,
     casting=function(v)return call(v,'is_casting_spell')==true or call(v,'is_channelling_spell')==true end,
     controlled=function(v)return breakable(v) or any_aura(v,stun_auras) end,
     dr=function(v,flag)return helper('get_unit_dr',v,flag,0) end,
     incap_flag=E.cc_flags and E.cc_flags.INCAPACITATE,disorient_flag=E.cc_flags and E.cc_flags.DISORIENT,
     memory=Lib.Intel.memory_for,guid=guid})
    local victim=call(u,'get_target')
    if alive(victim) and not enemy(p,victim) then score=score+30 end
    if score>best_score then focus=u;best_score=score end
   end
  end
 end
 c.control_focus=focus
 if pvp then
  for _,u in ipairs(c.enemies) do
   if dist(p,u)<=10 and guid(u)~=guid(target) and (healer(u) or focus and guid(u)==guid(focus)) then c.aoe_safe=false end
  end
 end
 c.cc_status=not c.cc_enabled and 'disabled' or not focus and 'no eligible off-target in range / line of sight'
  or 'target='..tostring(call(focus,'get_name'))..' stun_dr='..tostring(helper('get_unit_dr',focus,E.cc_flags and E.cc_flags.STUN,0))
    ..' sap_dr='..tostring(helper('get_unit_dr',focus,E.cc_flags and E.cc_flags.INCAPACITATE,0))
    ..' blind_dr='..tostring(helper('get_unit_dr',focus,E.cc_flags and E.cc_flags.DISORIENT,0))
    ..' clean='..tostring(clean_for_breakable(focus))..' los='..tostring(los(p,focus))
 c.focus_healer=enemy(p,focus) and guid(focus)~=guid(target) and healer(focus) and dist(p,focus)<=25 and los(p,focus)
 c.cc_opportunity=enemy(p,focus) and los(p,focus) and dist(p,focus)<=25 and not protected(focus) and not breakable(focus)
 local in_city,city_reason=Lib.Stealth.city(p)
 c.in_city,c.city_reason=in_city,city_reason
 c.duel_active=State.duel_active or call(p,'is_in_duel')==true or call(p,'is_dueling')==true
 return c
end
local function prepare_multidot(c)
 c.spread_enabled=opts.spread_bleeds
 c.spread_status='hold: establish primary bleeds / preserve kill window';c.spread_candidates=0
 if not opts.spread_bleeds then c.spread_status='disabled';return end
 if not c.bleeds_ready or not enemy(c.player,c.target) or c.self_hp<=50 or c.target_hp<=45
    or c.kill_intent or c.kill_window or c.deathmark or c.stealth or c.darkest
    or refresh(c.target,Lib.S.GARROTE,6) or refresh(c.target,Lib.S.RUPTURE,8) then return end
 local eligible={}
 for _,u in ipairs(c.enemies) do
  local ttd=call(u,'get_time_to_die')
  if guid(u)~=guid(c.target) and (not c.control_focus or guid(u)~=guid(c.control_focus))
     and call(u,'is_in_combat')==true and not breakable(u) and not protected(u)
     and (not c.pvp or call(u,'is_player')==true and not healer(u))
     and dist(c.player,u)<=5 and los(c.player,u)
     and (type(ttd)~='number' or ttd<=0 or ttd>=12) then
   local life=type(ttd)=='number' and ttd>0 and math.min(30,ttd) or 18
   local score=life-dist(c.player,u)
   if refresh(u,Lib.S.GARROTE,0) then score=score+8 end
   if refresh(u,Lib.S.RUPTURE,0) then score=score+5 end
   eligible[#eligible+1]={unit=u,score=score}
  end
 end
 table.sort(eligible,function(a,b)return a.score>b.score end)
 local limit=c.pvp and 2 or 4
 for index=1,math.min(limit,#eligible) do
  local u=eligible[index].unit;c.spread_candidates=c.spread_candidates+1
  if not c.multidot_garrote and refresh(u,Lib.S.GARROTE,5.4)
     and read(core.spell_book.is_spell_in_range,Lib.S.GARROTE,u,c.player)==true then c.multidot_garrote=u end
  if not c.multidot_rupture and refresh(u,Lib.S.RUPTURE,0.3*(4+4*c.cp))
     and read(core.spell_book.is_spell_in_range,Lib.S.RUPTURE,u,c.player)==true then c.multidot_rupture=u end
 end
 c.spread_status=c.spread_candidates>0 and 'safe secondary bleeds eligible; primary burst has priority' or 'no safe secondary enemy in melee'
end
local function reset_open()
 Lib.KillWindows.reset();Lib.StepCC.reset()
 opening={start=now(),done=false,garrote=0,rupture=false,envenom=false}
end
local function reset_match_state(reason)
 Lib.Intel.reset();Lib.TargetForecast.reset();Lib.InterruptCoordination.reset()
 for k in pairs(State.cc_history) do State.cc_history[k]=nil end
 for k in pairs(State.dot_history) do State.dot_history[k]=nil end
 for k in pairs(State.bleed_visibility) do State.bleed_visibility[k]=nil end
 State.kill_kidney=nil;State.pvp_swap_lock_until=0
 State.arena_vanish_focus=nil;State.arena_vanish_until=-math.huge
 State.arena_vanish_kill=nil;State.arena_vanish_kill_stage=nil;State.arena_vanish_kill_until=-math.huge
 Lib.T.note('MATCH_STATE_RESET',{'mode='..mode,'reason='..tostring(reason),'opponent_memory=cleared','local_dr=cleared'})
end
-- Keep the hot update closure below Lua 5.1/LuaJIT limits. Stable helpers are
-- passed in one table; module references and mutable combat state each occupy
-- one shared upvalue so encrypted output retains substantial local headroom.
local update_helpers={
 now=now,read=read,call=call,alive=alive,hp=hp,mana_pct=mana_pct,guid=guid,dist=dist,los=los,
 enemy=enemy,dummy=dummy,breakable=breakable,protected=protected,present=present,
 known=known,cd=cd,ready=ready,talent=talent,helper=helper,stunned=stunned,
 objects=objects,refresh_arena=refresh_arena,detect=detect,skip=skip,attempt=attempt,action=action,
 make_context=make_context,prepare_multidot=prepare_multidot,evaluate_sap=evaluate_sap,
 sap_healer=sap_healer,defense=defense,control=control,reset_open=reset_open,
 record_target_failure=record_target_failure,
 opts=opts,controls=controls,profile_controls=profile_controls,target_failures=State.target_failures,
 cc_history=State.cc_history,A=Lib.A,T=Lib.T,P=Lib.P,S=Lib.S,E=E,M=M,G=Lib.G,
 Prediction=Lib.Prediction,Engagement=Lib.Engagement,StepCC=Lib.StepCC,KillWindows=Lib.KillWindows,
 Intel=Lib.Intel,PvP=Lib.PvP,Performance=Lib.Performance,BigWigs=Lib.BigWigs,Replay=Lib.Replay,Stealth=Lib.Stealth,TargetForecast=Lib.TargetForecast
}
local function update(H)
 local now,read,call,alive,hp,mana_pct,guid,dist,los=H.now,H.read,H.call,H.alive,H.hp,H.mana_pct,H.guid,H.dist,H.los
 local enemy,dummy,breakable,protected,present=H.enemy,H.dummy,H.breakable,H.protected,H.present
 local known,cd,ready,talent,helper,stunned=H.known,H.cd,H.ready,H.talent,H.helper,H.stunned
 local objects,refresh_arena,detect,skip,attempt,action=H.objects,H.refresh_arena,H.detect,H.skip,H.attempt,H.action
 local make_context,prepare_multidot,evaluate_sap,sap_healer=H.make_context,H.prepare_multidot,H.evaluate_sap,H.sap_healer
 local defense,control,reset_open,record_target_failure=H.defense,H.control,H.reset_open,H.record_target_failure
 local opts,controls,profile_controls=H.opts,H.controls,H.profile_controls
 if now()>=State.next_failure_cleanup then
  State.next_failure_cleanup=now()+5
  for k,v in pairs(State.target_failures) do if now()-(v.last or 0)>60 then State.target_failures[k]=nil end end
 end
 Lib.A.begin_frame()
 if now()>=State.next_settings then
  State.next_settings=now()+0.25
  for k,v in pairs(controls) do opts[k]=v:get_state()==true end
  for key,fields in pairs(profile_controls) do for field,control in pairs(fields) do Lib.P.settings[key][field]=control:get_state()==true end end
 end
 Lib.T.set_enabled(opts.logging)
 local hotkey_notice=Lib.Hotkeys.poll(now())
 if hotkey_notice then notice=hotkey_notice;State.next_settings=-math.huge;Lib.T.note('HOTKEY',{hotkey_notice}) end
 if core.input and core.input.is_key_pressed then
  local down=read(core.input.is_key_pressed,0x70)==true
  if down and not State.key_down then window_open=not window_open end;State.key_down=down
 end
 local p=core.object_manager.get_local_player();if not alive(p) or (hp(p) or 0)<=0.1
    or call(p,'is_ghost')==true or call(p,'is_released')==true then Lib.G.stop();return end
 if call(p,"get_class")~=(E.class_id and E.class_id.ROGUE or 4) then return end
  local raw_spec=read(core.spell_book.get_specialization_id)
  local spec=read(E.class_spec_id and E.class_spec_id.get_specialization_enum,call(p,"get_class"),raw_spec) or raw_spec
  local game_branch,spec_key,branch_evidence=Lib.Branch.detect(raw_spec,spec)
  if game_branch~='forever' and not (spec==259 or spec==260 or spec==261 or raw_spec==1 or raw_spec==2 or raw_spec==3) then skip("Rogue damage specialization required");return end
 local target=call(p,"get_target")
 -- Optional city practice assistant. Project Sylvanas' locale-independent
 -- unit_helper classification covers capital-city and expansion-hub dummies;
 -- names are used only to select the matching practice profile.
 if opts.dummy_test and opts.auto_dummy_target and not enemy(p,target)
    and call(p,'is_in_combat')~=true and call(p,'is_mounted')==false and call(p,'is_moving')==false then
  local in_city=Lib.Stealth.city(p)
  if in_city then
   local best,range=nil,30
   local candidates=objects()
   for i=1,#candidates do local u=candidates[i]
    if dummy(u) and enemy(p,u) then
     local name=tostring(call(u,'get_name') or ''):lower()
     local healing=name:find('healing',1,true)~=nil or name:find('healer',1,true)~=nil
     local d=dist(p,u)
     if not healing and d<range and los(p,u) then best,range=u,d end
    end
   end
   if best and read(core.input.set_target,best)==true then
    target=call(p,'get_target') or best
    Lib.T.note('DUMMY_TARGET',{'name='..tostring(call(best,'get_name')),'distance='..string.format('%.1f',range),'profile='..dummy_profile(best),'source=unit_helper'})
   end
  end
 end
 local next_mode=detect(p,target)
 if next_mode~=mode then mode=next_mode;reset_open() end
 local training=opts.dummy_test and dummy(target) and enemy(p,target) and dist(p,target)<=5 and call(p,"is_mounted")==false
 local combat=call(p,"is_in_combat")==true or training
 if combat and not active then
  reset_open();Lib.Prediction.reset();Lib.TargetForecast.reset()
  State.kill_kidney=nil;last="Waiting for first confirmed cast"
  Lib.T.note('COMBAT_START',{'mode='..mode,'opponent_memory=preserved','local_dr=preserved'})
 end
 active=combat
 if pending and now()>=pending.expires then
  Lib.StepCC.confirm(pending.id,pending.target,false);record_target_failure(pending.id,pending.target);Lib.T.note("TIMEOUT",{"spell="..pending.id,"target="..guid(pending.target),"latency="..string.format("%.2f",now()-pending.time),"expected="..string.format('%.2f',State.cast_latency),"reason=no confirming event"});pending=nil
 end
 local list=objects()
 refresh_arena()
 local merged,seen={},{}
 for _,u in pairs(list) do if not seen[guid(u)] then merged[#merged+1]=u;seen[guid(u)]=true end end
 for _,u in ipairs(State.arena_units) do if not seen[guid(u)] then merged[#merged+1]=u;seen[guid(u)]=true end end
 list=merged
 local hover=read(core.object_manager.get_mouse_over_object)
 local armed=Lib.Engagement.update(enemy(p,target) and guid(target) or nil,read(core.input.is_key_pressed,0x02)==true,
  alive(hover) and guid(hover) or nil,call(p,'is_in_combat')==true,call(p,'is_auto_attacking')==true,now())
 if mode=='pve' or mode=='mythic_plus' or mode=='delve' or mode=='battleground' then armed=enemy(p,target) end
 -- Retaliation is an authorized continuation after a dead/missing PvE target.
 if opts.enabled and opts.damage and Lib.P.settings[mode].damage and (mode=='pve' or mode=='mythic_plus' or mode=='delve')
    and combat and not training and call(p,'is_mounted')==false then
  local function attacker(u)
   local victim=call(u,'get_target')
   return enemy(p,u) and call(u,'is_player')==false and call(u,'is_in_combat')==true
    and alive(victim) and (guid(victim)==guid(p) or call(victim,'is_enemy_with',p)==false)
    and dist(p,u)<=25 and los(p,u)
    and not breakable(u) and not protected(u)
  end
  local target_life=enemy(p,target) and call(target,'get_time_to_die') or nil
  local handoff=not enemy(p,target) or protected(target) or type(target_life)=='number' and target_life>0 and target_life<1.5
  if handoff then
   local best,best_score=nil,-math.huge
   for _,u in pairs(list) do if attacker(u) then
    local d=dist(p,u);local score=50-d
    if guid(call(u,'get_target'))==guid(p) then score=score+25 end
    if healer(call(u,'get_target')) then score=score+30 end
    score=score+(100-(hp(u) or 100))*0.3
    if call(u,'is_casting_spell')==true or call(u,'is_channelling_spell')==true then score=score+60 end
    if call(u,'is_boss')==true then score=score+30 end
    local life=call(u,'get_time_to_die');if type(life)=='number' and life>12 then score=score+15 end
    if mode=='delve' then
     local victim=call(u,'get_target')
     if alive(victim) and call(victim,'is_enemy_with',p)==false then score=score+35 end
    end
    if score>best_score then best,best_score=u,score end
   end end
   if best and guid(best)~=guid(target) and read(core.input.set_target,best)==true then
    local selected=call(p,'get_target')
    if selected and guid(selected)==guid(best) then
      if pending and guid(pending.target)~=guid(p) and not alive(pending.target) then
      Lib.T.note('CANCEL',{'spell='..pending.id,'reason=previous target died'});pending=nil
     end
     Lib.T.note('TARGET_SWAP',{'from='..guid(target),'to='..guid(best),'reason='..(protected(target) and 'current target protected' or 'PvE target dead or expiring')})
     target=best;reset_open()
    end
   end
  end
  if attacker(target) and not armed then Lib.Engagement.transfer(guid(target),now());armed=true end
 end
 if armed and combat and (mode=='arena' or mode=='battleground' or mode=='world_pvp') and not pending
    and (now()>=State.pvp_swap_lock_until or not enemy(p,target) or protected(target) or breakable(target) or dist(p,target)>25 or not los(p,target))
    and not Lib.StepCC.current(now(),target,true)
    and not (M.context and (M.context.kill_window or M.context.kingsbane_active or M.context.deathmark)
      and enemy(p,target) and not protected(target) and not breakable(target) and dist(p,target)<=25 and los(p,target))
    and Lib.Engagement.can_swap(now()) then
  local score_helpers={player=p,enemy=function(u)return enemy(p,u) end,hp=hp,mana=mana_pct,healer=healer,dist=dist,los=los,
   breakable=breakable,protected=protected,guid=guid,memory=Lib.Intel.memory_for,forecast=Lib.TargetForecast.get,
   stun_blocked=function(u)local row=State.cc_history[guid(u)];return row and (row.stun_dr_until or 0)>now() end}
  local current_score=Lib.PvP.score_target(target,now(),score_helpers)
  local best,best_score=nil,current_score
  for _,u in pairs(list) do
    if guid(u)~=guid(target) and call(u,'is_in_combat')==true then
    local score=Lib.PvP.score_target(u,now(),score_helpers)
    if score>-math.huge and score>=best_score+25 then best,best_score=u,score end
   end
  end
  if best and Lib.PvP.swap_ready(target,best,now(),score_helpers) and read(core.input.set_target,best)==true then
    Lib.T.note('TARGET_SWAP',{'from='..guid(target),'to='..guid(best),'reason=scored PvP kill/objective opportunity','old_score='..string.format('%.1f',current_score),'new_score='..string.format('%.1f',best_score)})
   target=best;Lib.Engagement.transfer(guid(best),now())
   State.pvp_swap_lock_until=now()+4
  elseif not best then Lib.PvP.swap_ready(nil,nil,now(),score_helpers) end
 end
 if armed and opts.auto_target and combat and not enemy(p,target) then
  local best,range=nil,8
  for _,u in pairs(list) do if enemy(p,u) and call(u,"is_in_combat")==true and not breakable(u) and not protected(u)
     and dist(p,u)<range and los(p,u) then best,range=u,dist(p,u) end end
  if best then read(core.input.set_target,best);target=best end
 end
  local c=make_context(p,target,Lib.P.settings[mode],list);if not c then skip("Resource data unavailable");return end
  c.spec_id=spec;c.spec_key=spec_key;c.game_branch=game_branch;c.branch_evidence=branch_evidence
  c.sap_id=game_branch=='forever' and (Lib.Forever.spell(c,'SAP') or 0) or Lib.S.SAP
  c.spec_name=spec_key=='outlaw' and 'Outlaw' or spec_key=='combat' and 'Combat' or spec_key=='subtlety' and 'Subtlety' or 'Assassination'
  if game_branch=='forever' then c.hero='Forever '..c.spec_name..' tree' end
 c.healer_tether_safe,c.healer_tether_reason=Lib.PvP.tether_safe(c,target,{dist=dist,los=los,cc=function(u)return helper('is_crowd_controlled',u,nil,0)==true end})
 if enemy(p,target) and State.opening_target~=guid(target) then
  State.opening_target=guid(target)
  if c.pvp and combat then
   opening.start=now();opening.done=true;opening.garrote=0;opening.rupture=false;opening.envenom=false
   c.elapsed=0;c.open_done=true;c.open_garrote=false;c.open_garrote_count=0;c.open_rupture=false;c.open_envenom=false
   Lib.T.note('OPENER_CONTINUE',{'target='..tostring(call(target,'get_name')),'reason=in-combat PvP swap uses maintenance priority even during Subterfuge'})
  else
   reset_open();c.elapsed=0;c.open_done=false;c.open_garrote=false;c.open_garrote_count=0;c.open_rupture=false;c.open_envenom=false
   Lib.T.note('OPENER_RESET',{'target='..tostring(call(target,'get_name')),'reason=pre-combat or stealth target change'})
  end
 end
 c.training=training
 if opts.combat_intel then
  Lib.Intel.evaluate(c,now(),{dist=dist,los=los,guid=guid,healer=healer})
  if c.bleeds_removed_at and State.bleed_removal_seen[c.target_key]~=c.bleeds_removed_at then
   State.bleed_removal_seen[c.target_key]=c.bleeds_removed_at
   State.bleed_recovery_after[c.target_key]=c.bleeds_reapply_after or now()
   State.bleed_recovery_until[c.target_key]=math.max(now()+3,State.bleed_recovery_after[c.target_key]+3)
   State.dot_history[c.target_key]={};State.bleed_visibility[c.target_key]={}
   c.deathmark=false;c.kingsbane_active=false
   Lib.T.note('BLEED_REMOVED',{'target='..tostring(c.target_name),'spell='..tostring(c.bleeds_removed_spell),'source=observed targeted cleanse'})
  end
  if (State.bleed_recovery_until[c.target_key] or 0)>now() then
   local recovered=State.dot_history[c.target_key] or {}
   local can_reapply=now()>=(State.bleed_recovery_after[c.target_key] or 0)
   c.force_missing_garrote=can_reapply and not recovered[Lib.S.GARROTE]
   c.force_missing_rupture=can_reapply and not recovered[Lib.S.RUPTURE]
   c.bleeds_ready=false
  end
  if c.enemy_burst then c.focus_burst=true end
 else c.intel_status='disabled';c.position_score=0;c.enemy_vulnerable=false end
 c.poison_uptime_commit=c.pvp and c.kingsbane_active and not c.damage_reduced and not c.enemy_defensive and not c.enemy_external
 c.cooldown_target_lock=c.pvp and (c.kingsbane_active or c.deathmark) and not c.damage_reduced and not c.enemy_defensive and not c.enemy_external
  if c.pvp then Lib.PvP.evaluate(c) else c.pvp_status='not PvP' end
 c.kill=Lib.KillWindows.evaluate(c,now(),opts.auto_kill and (training or opts.cc and c.profile.cc))
 c.kill_intent=c.kill.intent;c.kill_window=c.kill.active
 local arena_cooldown_gap=mode=='arena' and cd(c.kidney_id)>8 and cd(Lib.S.KINGSBANE)>8 and cd(Lib.S.DEATHMARK)>8
 c.arena_reset=mode=='arena' and not training and not c.kill_window and not c.kill_intent and not c.target_collapse
  and (c.enemy_burst or c.enemy_defensive or c.enemy_external or c.damage_reduced or c.defensive_dry
   or c.friendly_healer_present and not c.friendly_healer_available or arena_cooldown_gap) or false
 c.arena_reset_reason=not c.arena_reset and 'pressure phase'
  or c.enemy_burst and 'enemy burst active'
  or c.enemy_external and 'enemy healer external active'
  or (c.enemy_defensive or c.damage_reduced) and 'enemy defensive active'
  or c.friendly_healer_present and not c.friendly_healer_available and 'friendly healer unavailable'
  or c.defensive_dry and 'personal defensives unavailable'
  or 'Kidney and poison cooldowns are between go windows'
 if c.arena_reset then c.mobility_plan='reset: preserve Shadowstep and Sprint; maintain ranged poison pressure' end
 c.disarmable=helper('is_disarmable',target)==true
 c.disarm_matchup=call(target,'get_class')==6 or call(target,'get_specialization_id')==71
 local dm_ready=ready(Lib.S.DEATHMARK);local dm_reason=dm_ready and 'ready' or State.ready_failure
 local kb_ready=ready(Lib.S.KINGSBANE);local kb_reason=kb_ready and 'ready' or State.ready_failure
 c.burst_status=string.format('DM_known=%s DM_cd=%.1f DM_ready=%s DM_reason=%s KB_known=%s KB_cd=%.1f KB_ready=%s KB_reason=%s KB_gain=%d',
 tostring(known(Lib.S.DEATHMARK)),cd(Lib.S.DEATHMARK),tostring(dm_ready),dm_reason,
 tostring(known(Lib.S.KINGSBANE)),cd(Lib.S.KINGSBANE),tostring(kb_ready),kb_reason,c.kingsbane_gain)
 c.burst_hold=not c.cooldowns and 'cooldowns disabled' or not c.bleeds_ready and 'establish Garrote and Rupture'
  or c.damage_reduced and 'enemy damage reduction' or not dm_ready and not kb_ready and 'major cooldowns unavailable (see spell reasons)'
  or c.pvp and c.defensive_dry and c.attackers>=2 and c.self_hp<=60 and 'survival hold: no major defensive reserves under focus'
  or mode=='arena' and c.healer_cc_expiring and not c.kill_window and 'wait: healer control is expiring before a new go'
  or c.pvp and not training and not c.kill_window and mode=='arena' and 'await observed healer control or target setup'
  or not c.envenom_active and not (c.pvp and (c.kill_window or c.target_stunned and c.healer_cc)) and 'prime Envenom poison window'
  or known(Lib.S.KINGSBANE) and cd(Lib.S.KINGSBANE)>2 and dm_ready and 'align Deathmark with Kingsbane'
  or c.cp>c.cp_max-c.kingsbane_gain and kb_ready and 'spend points before Kingsbane gain' or 'eligible; follow profile priority'
 local target_dots=State.dot_history[guid(target)]
 c.garrote_remaining=Lib.A.remaining(target,Lib.S.GARROTE) or target_dots and target_dots[Lib.S.GARROTE] and math.max(0,target_dots[Lib.S.GARROTE]-now())
 c.rupture_remaining=Lib.A.remaining(target,Lib.S.RUPTURE) or target_dots and target_dots[Lib.S.RUPTURE] and math.max(0,target_dots[Lib.S.RUPTURE]-now())
 c.melee_range=read(core.spell_book.is_spell_in_range,Lib.S.MUTILATE,target,p)==true

 c.target_name=call(target,"get_name") or "none"
 c.mark_elsewhere_name=c.mark_elsewhere and (call(c.mark_elsewhere,'get_name') or guid(c.mark_elsewhere)) or 'none'
 c.attackable=enemy(p,target);c.target_dummy=dummy(target)
 c.target_is_self=target~=nil and guid(target)==guid(p)
 c.damage_enabled=opts.damage and c.profile.damage;c.combat=combat
 c.engagement_armed=armed
 c.auto_attacking=call(p,'is_auto_attacking')==true
 local cc_reasons={}
 for _,id in ipairs({11297,2070,6770,2094,11286,8629,1777,1776,8643,408,1833}) do
  local usable=ready(id)
  cc_reasons[#cc_reasons+1]=tostring(id)..'='..(usable and 'ready' or tostring(State.ready_failure))
 end
 c.cc_readiness=table.concat(cc_reasons,'; ')
 if c.pvp and c.kidney_id~=0 and cd(c.kidney_id)<=0 then State.kidney_ready_since=State.kidney_ready_since or now() else State.kidney_ready_since=nil end
 if c.pvp and c.blind_id~=0 and cd(c.blind_id)<=0 then State.blind_ready_since=State.blind_ready_since or now() else State.blind_ready_since=nil end
 c.kidney_ready_age=State.kidney_ready_since and math.max(0,now()-State.kidney_ready_since) or 0
 c.blind_ready_age=State.blind_ready_since and math.max(0,now()-State.blind_ready_since) or 0
 c.defense_status_stun=stunned(p)
 c.evasion_effective=present(p,Lib.S.EVASION) and not c.defense_status_stun
 c.defense_enabled=opts.defensives and c.profile.defensives
 c.defense_status=string.format('Vial_cd=%.1f Cloak_cd=%.1f Evasion_cd=%.1f Vanish_cd=%.1f melee=%s',
  cd(Lib.S.VIAL),cd(Lib.S.CLOAK),cd(c.evasion_id),cd(c.vanish_id),tostring(c.melee_pressure))
 if training then c.boss=true;c.ttd=nil;notice="DUMMY TEST: "..Lib.P.settings[mode].label end
 c.prediction=opts.predictive and Lib.Prediction.evaluate(c,opts.bigwigs and not training) or nil
 Lib.DangerZones.update(c,opts.danger_zones and opts.bigwigs and not training)
 c.danger_zone_status=Lib.DangerZones.status
 Lib.BossCoach.update(c,opts.boss_coach and not training)
 Lib.BossCoach.plan(c)
 c.boss_coach_status=Lib.BossCoach.status
 if c.boss_cooldown_hold then c.burst_hold='hold major cooldowns: '..c.boss_plan_status end
  local learned_summary=Lib.ThreatLearning.summary(mode)
  c.learned_spell_count=learned_summary.spells;c.learned_sample_count=learned_summary.samples
 local discovered=Lib.BigWigs.take_discovery()
 if discovered then Lib.T.note('BIGWIGS_DISCOVERY',{'instance='..tostring(discovered.instance),'key='..tostring(discovered.key),'text='..tostring(discovered.text),'action=add an exact reviewed rule to ar_encounters.lua'}) end
 c.performance_status=Lib.Performance.status()
 c.cast_health=string.format('latency=%.2f pending_timeout=%.2f',State.cast_latency,math.max(1.2,math.min(3,State.cast_latency*4+0.8)))
 Lib.T.set_state_interval(opts.adaptive_performance and Lib.Performance.log_interval() or 1)
 prepare_multidot(c)
 c.enrage_target=nil
 if not c.pvp and ready(Lib.S.SHIV) then
  if enemy(p,target) and enraged(target) and read(core.spell_book.is_spell_in_range,Lib.S.SHIV,target,p)==true then c.enrage_target=target
  else for _,u in ipairs(c.enemies) do
   if enemy(p,u) and enraged(u) and not protected(u) and los(p,u)
      and read(core.spell_book.is_spell_in_range,Lib.S.SHIV,u,p)==true then c.enrage_target=u;break end
  end end
 end
 c.enrage_target_name=c.enrage_target and (call(c.enrage_target,'get_name') or guid(c.enrage_target)) or 'none'
 local next_action=Lib.P.decide(mode,c)
 c.next_spell=next_action and next_action.id and (read(core.spell_book.get_spell_name,next_action.id) or tostring(next_action.id)) or 'Pool energy / wait'
 c.next_reason=next_action and next_action.why or 'No eligible damage spell'
 if not c.attackable then
  c.next_spell='Select an enemy or dummy'
  c.next_reason=c.target_is_self and 'Host reports your character as the selected target' or 'No attackable target'
  c.current_action='Blocked: '..c.next_reason
  c.burst_hold='No attackable target; burst evaluation unavailable'
 elseif not armed then c.next_spell='Right-click target to start';c.next_reason='Arena and World PvP require engagement confirmation';c.current_action=c.next_spell
 elseif not combat and c.pvp and mode~='battleground' then c.next_spell='Waiting for combat';c.next_reason='Arena and World PvP wait for confirmed engagement';c.current_action=c.next_spell end
 evaluate_sap(c)
 c.replay_status=opts.replay_analysis and Lib.Replay.update(c,combat,now(),Lib.T.note) or 'disabled'
 M.context=c;Lib.T.state(c,combat);Lib.T.decision(c)
 c.next_id=c.attackable and armed and (combat or not c.pvp or mode=='battleground') and next_action and next_action.id or nil
 if not opts.enabled then Lib.G.stop();skip("Plugin paused");return end
 if call(p,"is_mounted")==true then Lib.G.stop();return end
 if combat then Lib.G.stop() end
 if combat and defense(c) then return end
 if pending then return end
 if call(p,"is_casting_spell")==true or call(p,"is_channelling_spell")==true then return end
 if not c.pvp and c.boss_movement_urgent and call(p,'is_moving')==true
    and not present(p,c.sprint_id) and call(p,'is_falling')~=true and call(p,'is_flying')~=true then
  if attempt(action(c.sprint_id,p,'boss mechanic: assist confirmed player repositioning'),c) then return end
 end
  if training and opts.stealth and not c.stealth and call(p,'is_in_combat')~=true then
   if Lib.Stealth.safe(p,false,false) then
    if attempt(action(Lib.S.STEALTH,p,'city dummy: prepare full stealth opener'),c) then return end
   else skip('Dummy opener Stealth blocked by movement or player state') end
   return
  end
 if sap_healer(c) then return end
 if not combat then
  Lib.G.update(p,opts,Lib.T,list)
  if opts.fishing then return end
  if opts.poisons then
   local lethal=c.game_branch=='forever' and c.lethal_poison
    or c.pvp and known(Lib.S.WOUND) and Lib.S.WOUND or known(Lib.S.DEADLY) and Lib.S.DEADLY or Lib.S.INSTANT
   local utility=c.utility_poison
   if lethal and not present(p,lethal) and attempt(action(lethal,p,c.game_branch=='forever' and "prepare Forever lethal poison" or "prepare lethal poison"),c) then return end
   if c.game_branch~='forever' and talent(Lib.S.DRAGON_BLADES,'Dragon-Tempered Blades') and known(Lib.S.AMPLIFYING) and not present(p,Lib.S.AMPLIFYING) and attempt(action(Lib.S.AMPLIFYING,p,'prepare additional lethal poison'),c) then return end
   if utility and utility~=lethal and not present(p,utility) and attempt(action(utility,p,c.game_branch=='forever' and "prepare Forever utility poison" or "prepare utility poison"),c) then return end
   if c.in_city and call(p,'is_moving')==false and now()>=State.city_poison_at then
    local random_poison=c.game_branch=='forever' and (c.utility_poison or c.lethal_poison) or Lib.Stealth.random_poison(known)
    State.city_poison_at=now()+60
    if random_poison and attempt(action(random_poison,p,"city idle random poison"),c) then return end
   end
  end
  if opts.stealth and not c.stealth and not c.player_flag_carrier then
   -- Selecting World PvP while idle in a capital is not an active PvP
   -- engagement.  Only a duel or a hostile player already in combat may lift
   -- the city Stealth block; Arena/Battleground instances are not cities.
   local city_pvp_active=c.pvp and (c.duel_active or enemy(p,target) and call(target,'is_player')==true and call(target,'is_in_combat')==true)
   local city_block=c.in_city and not city_pvp_active
   local safe,reason
   if city_block then safe,reason=false,"city idle; waiting for duel or PvP"
   else safe,reason=Lib.Stealth.safe(p,Lib.G.busy(),pending~=nil) end
   if safe then
    if attempt(action(Lib.S.STEALTH,p,"safe out-of-combat Stealth"),c) then return end
    else skip("Stealth blocked: "..tostring(reason or "host safety state unavailable")) end
  end
 end
 if armed and not training and enemy(p,target) and (combat or call(target,"is_in_combat")==true) and control(c) then return end
 if not armed then
  skip(not c.attackable and c.next_reason or c.pvp and 'Waiting for right-click on selected target' or 'Waiting for eligible combat target');return
 end
 if not opts.damage or not c.profile.damage then skip("Damage disabled globally or for this profile");return end
 if not enemy(p,target) then skip("Selected target is not confirmed attackable");return end
 if c.enrage_target and attempt(action(Lib.S.SHIV,c.enrage_target,'utility: remove confirmed Enrage'),c) then return end
 if not c.pvp and (mode=='mythic_plus' or mode=='pve') and combat and c.target_tanked and c.friendly_tank
    and attempt(action(Lib.S.TRICKS,c.friendly_tank,'group utility: Tricks on confirmed active tank',true),c) then return end
 if c.pvp and talent(Lib.S.THICK_AS_THIEVES,'Thick as Thieves') and c.ally_burst_target
    and (c.kill_window or c.kill_intent or c.target_stunned and c.healer_cc)
    and attempt(action(Lib.S.TRICKS,c.ally_burst_target,'Thick as Thieves: amplify teammate kill burst',true),c) then return end
  if c.pvp and call(target,"is_player")~=true and not training then skip("PvP profile requires player target; enable dummy testing for practice");return end
 if c.pvp and mode~='battleground' and not combat and call(target,"is_in_combat")~=true then skip("Waiting for confirmed PvP engagement");return end
 if breakable(target) or protected(target) then skip("Target is controlled / immune");return end
 if opts.auto_face then read(core.input.look_at,call(target,"get_position")) end
 c.melee_probe_id=c.game_branch=='forever' and next_action and next_action.id or Lib.S.MUTILATE
 c.melee_probe_ok=c.game_branch=='forever' and next_action and guid(next_action.target)==guid(p)
  or c.melee_probe_id and read(core.spell_book.is_spell_in_range,c.melee_probe_id,target,p)==true
 if c.melee_probe_ok~=true then
  -- Finisher/control range can exceed Mutilate range for selected talents.
  if next_action and (next_action.id==Lib.S.ENVENOM or next_action.id==Lib.S.RUPTURE or Lib.Forever.is_spell('KIDNEY',next_action.id))
     and read(core.spell_book.is_spell_in_range,next_action.id,target,p)==true
     and attempt(next_action,c) then return end
  local step_charges=read(core.spell_book.get_spell_charge,Lib.S.STEP)
  local pursuit_step=not c.arena_reset and type(step_charges)=='number' and (step_charges>=2 or step_charges>=1 and (c.kill_window or c.poison_uptime_commit) and c.self_hp>=65)
  if c.pvp and c.enemy_mobility_down and not c.kill_window and not c.poison_uptime_commit and step_charges==1 then pursuit_step=false end
  if c.pvp and pursuit_step and c.healer_tether_safe
     and c.self_hp>45 and dist(p,target)<=25 and los(p,target) and not breakable(target) and not protected(target)
     and call(p,'is_falling')~=true and call(p,'is_flying')~=true then
   if attempt(action(Lib.S.STEP,target,step_charges>=2 and 'pursuit: close melee gap using spare Step charge'
      or c.poison_uptime_commit and 'pursuit: preserve active Kingsbane melee uptime'
      or 'pursuit: commit final Step to confirmed kill window'),c) then return end
  end
  if call(p,'is_moving')==true and dist(p,target)>8 and dist(p,target)<=30 and los(p,target)
     and (not c.pvp or c.self_hp>45 and c.healer_tether_safe and not c.arena_reset)
     and call(p,'is_falling')~=true and call(p,'is_flying')~=true
     and not present(p,c.sprint_id) and attempt(action(c.sprint_id,p,'combat pursuit: moving outside melee'),c) then return end
  if c.cp>=math.min(5,c.cp_max) or c.self_hp<=50 and c.energy<45 then
   skip('Ranged: preserve combo points / energy for finisher and defense');return
  end
  -- Poisoned Knife is low damage. In PvP, use it to apply a missing slow or
  -- bleed off imminent Energy overcap; otherwise pool for melee re-entry.
  if c.pvp and present(target,3409) and (c.energy_pct or 0)<80 then
   skip('Ranged: Crippling active; pool Energy for melee re-entry');return
  end
  attempt(action(Lib.S.KNIFE,target,c.arena_reset and 'Arena reset: Crippling pressure while preserving mobility' or 'ranged poison pressure on engaged target'),c);return
 end
 if not talent(Lib.S.CUT_TO_CHASE,'Cut to the Chase') and c.cp>=2 and (not c.pvp or c.bleeds_ready) and not present(p,Lib.S.SLICE) then
  if attempt(action(Lib.S.SLICE,p,'maintain Slice and Dice without automatic talent'),c) then return end
 end
 attempt(next_action,c)
end

local function safe_update()
 local n=now()
 if n<State.next_update then return end
 State.next_update=n+(opts.adaptive_performance and Lib.Performance.update_interval() or 0.08)
 State.last_update=n
 local perf_start=Lib.Performance.begin()
 State.unit_frame={}
 local ok,err=xpcall(function()return update(update_helpers)end,function(e)return Lib.Debugger.error(e,M.context)end);if not ok then skip("Runtime error; see debug.md");Lib.T.note("ERROR",{tostring(err)}) end
 Lib.A.end_frame();State.unit_frame=nil
 if opts.adaptive_performance then
  local ms,changed=Lib.Performance.finish(perf_start)
  if changed or ms>=12 then Lib.T.note('PERF_SPIKE',{'update_ms='..string.format('%.2f',ms),'status='..Lib.Performance.status()}) end
 end
end
local function toggle(k)
 if controls[k] then controls[k]:set(not controls[k]:get_state()) end
end
local function gui_action(kind,key)
 if kind=="set_mode" and Lib.P.settings[key] then editing_mode=key;notice="Editing settings: "..Lib.P.settings[key].label
 elseif kind=="auto_mode" then editing_mode=nil;notice="Rotation follows detected activity"
 elseif kind=="toggle_plugin" then toggle("enabled")
 elseif kind=="toggle_log" then toggle("logging")
 elseif kind=="debug_toggle" then Lib.Debugger.enabled=not Lib.Debugger.enabled
 elseif kind=="debug_snapshot" then Lib.Debugger.snapshot(M.context,"GUI capture")
 elseif kind=="clear_log" then Lib.T.clear()
 elseif kind=="hotkey_capture" then Lib.Hotkeys.begin_capture(key);notice=Lib.Hotkeys.status
 elseif kind=="hotkey_toggle" then notice=Lib.Hotkeys.toggle(key) or notice;State.next_settings=-math.huge
 elseif kind=="burst" then State.manual_burst_until=now()+10;notice="Burst requested for 10 seconds"
 elseif kind:sub(1,8)=="profile_" then local k=kind:sub(9);local selected=editing_mode or mode;Lib.P.settings[selected][k]=not Lib.P.settings[selected][k];profile_controls[selected][k]:set(Lib.P.settings[selected][k])
 elseif kind:sub(1,7)=="toggle_" then toggle(kind:sub(8))
 elseif kind=="notice" then notice=key end
 Lib.T.note("CONTROL",{kind,key})
end
local function gui_state()
 local function row(label,k,note) local id="toggle_"..k;return {label=label,value=controls[k]:get_state(),action=id,note=note,hotkey=Lib.Hotkeys.label(id),hotkey_id=id} end
 local hotkey_labels={}
 for _,entry in ipairs(Lib.Hotkeys.rows()) do hotkey_labels[entry.id]=Lib.Hotkeys.label(entry.id) end
 local function hotkey_rows()
  local rows={}
  for _,entry in ipairs(Lib.Hotkeys.rows()) do
   local value=false
   if entry.kind=='option' then value=controls[entry.field]:get_state()==true
   else value=profile_controls[entry.mode][entry.field]:get_state()==true end
   rows[#rows+1]={label=entry.label,value=value,action='hotkey_toggle',key=entry.id,
    note='Click the key pill to bind; switch remains independently usable',hotkey=Lib.Hotkeys.label(entry.id),hotkey_id=entry.id}
  end
  return rows
 end
 local c=M.context or {}
 return {eligible=true,window_open=window_open,plugin_enabled=opts.enabled,auto_mode=true,active_mode=mode,editing_mode=editing_mode or mode,
   mode_label=Lib.P.settings[mode].label,profile_name=Lib.P.settings[editing_mode or mode].label,hero=c.hero or "Unknown",last=last,
   spec_name=c.spec_name or 'Assassination',game_branch=c.game_branch or 'retail',level=c.level,
  notice=notice,status=pending and "Cast pending" or Lib.G.status,log_enabled=opts.logging,profiles=Lib.P.settings,
  hotkey_status=Lib.Hotkeys.status,hotkey_labels=hotkey_labels,
  prediction=c.prediction,attackers=c.attackers,timer_status=Lib.BigWigs.status,
  pages={
   [3]={row("Damage rotation","damage","Master damage engine for every activity"),row("Prepare poisons","poisons","Activity-aware lethal and utility poison selection"),
    row("Safe automatic Stealth","stealth","Stationary, unmounted and city-aware"),row("Offensive Vanish","offensive_vanish","Guarded burst re-entry"),
    row("Automatic kill windows","auto_kill","Align setup, stun and major cooldowns"),row("Spread bleeds","spread_bleeds","Safe secondary pressure without breaking control"),
    row("Training dummy testing","dummy_test","Full opener and cooldown practice"),row("Nearby city dummy target","auto_dummy_target","While stationary, acquire a damage dummy within 30 yd")},
   [4]={row("Interrupt casts","interrupt","Kick and control fallback"),row("Control and peels","cc","DR-aware off-target setup and defensive peel"),
    row("Shadowstep control return","step_cc","Step to control target and safely return"),row("Automatic targeting","auto_target","Acquire nearby engaged targets"),
    row("Automatic facing","auto_face","Face the selected hostile target"),row("Combat intelligence","combat_intel","Opponent cooldown, position and control memory")},
   [5]={row("Automatic defensives","defensives","Vial, Cloak, Evasion, Feint and escape"),row("Predictive defense","predictive","Forecast incoming damage, casts and focus fire"),
    row("Combat intelligence","combat_intel","Matchup-aware defensive planning"),row("Adaptive performance","adaptive_performance","Protect frame time during heavy fights"),
    row("Combat replay grading","replay_analysis","Review late defensive trades")},
   [6]={row("Automatic targeting","auto_target","Stay engaged after target deaths"),row("Automatic facing","auto_face","Correct facing before cast attempts"),
    row("Safe automatic Stealth","stealth","Movement and city safety checks"),row("Shadowstep control return","step_cc","Mobility reserved for control chains"),
    row("World combat visuals","world_visuals","Target and healer connection lines")},
   [7]={row("Automatic fishing","fishing","Fishing takes priority over corpses"),row("Automatic looting","looting","Acquire and approach lootable corpses"),
    row("Automatic skinning","skinning","Target, approach and skin after looting"),row("Safe automatic Stealth","stealth","Break Stealth only when gathering requires it"),
    row("Adaptive performance","adaptive_performance","Reduce object scans under load")},
   [8]={row("BigWigs support","bigwigs","Exact reviewed encounter timers"),row("Boss danger auras","danger_zones","Red danger and green safe zones"),
    row("Season 2 boss coach","boss_coach","Role-aware mechanics and positioning"),row("World combat visuals","world_visuals","Lines, circles and encounter guidance"),
    row("Predictive defense","predictive","Pre-defend confirmed incoming mechanics")},
   [9]=hotkey_rows(),
   [11]={row("Plugin enabled","enabled","Master customer switch"),row("Encounter recorder","logging","Persistent session diagnostics"),
    row("Combat replay grading","replay_analysis","End-of-fight improvement report"),row("Adaptive performance","adaptive_performance","Automatic lag protection"),
    row("Training dummy testing","dummy_test","Practice safely in every major city"),row("Nearby city dummy target","auto_dummy_target","Optional stationary damage-dummy acquisition")}
  }}
end
core.register_on_update_callback(safe_update)
core.register_on_render_menu_callback(function()
 root:render("Assassination Rogue",function()
  core.menu.text("VALEERA / "..Lib.P.settings[mode].label.." / v"..require('ar_version'))
  for _,k in ipairs({"enabled","damage","defensives","interrupt","cc","poisons","stealth","offensive_vanish","auto_target","auto_face","fishing","looting","skinning","logging","predictive","bigwigs","danger_zones","boss_coach","dummy_test","auto_dummy_target","auto_kill","step_cc","world_visuals","spread_bleeds","combat_intel","replay_analysis","adaptive_performance"}) do
   controls[k]:render(k:gsub("_"," "),"Assassination Rogue setting")
   local bind=Lib.Hotkeys.binding('toggle_'..k);if bind then bind:render('Hotkey: '..k:gsub('_',' '),'Optional key to toggle this switch') end
  end
  for _,entry in ipairs(Lib.Hotkeys.rows(function(row)return row.kind=='profile' end)) do
   entry.bind:render('Hotkey: '..entry.label,'Optional key to toggle this activity setting')
  end
  core.menu.text("F1: panel | "..last)
 end)
end)
local render=core.register_on_render_window_callback or core.register_on_render_callback


if render then render(function()
  if controls.world_visuals:get_state() then
   local p=core.object_manager.get_local_player()
   if alive(p) then
    local pos=call(p,'get_position');local target=call(p,'get_target')
    if pos then
     read(core.graphics.circle_3d,pos,1.5,Color.new(170,80,240,220),2,1)
     if enemy(p,target) then read(core.graphics.line_3d,pos,call(target,'get_position'),Color.new(255,70,70,230),2,1,false) end
     if now()-State.visual_check>=Lib.Performance.visual_interval() then
      State.visual_check=now();local party=read(core.object_manager.get_party_members)
      local best,range=nil,math.huge
      if type(party)=='table' then for _,member in pairs(party) do
       local u=type(member)=='table' and member.object or member
       if alive(u) and guid(u)~=guid(p) and not enemy(p,u) and healer(u) and dist(p,u)<range then best,range=u,dist(p,u) end
      end end
      -- Solo Shuffle can expose direct units rather than party wrapper objects.
      -- Recover the friendly player healer from the existing arena object cache.
      if not best and mode=='arena' then for _,u in pairs(objects()) do
       if alive(u) and guid(u)~=guid(p) and call(u,'is_player')==true
          and call(u,'is_enemy_with',p)==false and healer(u) and dist(p,u)<range then
        best,range=u,dist(p,u)
       end
      end end
      State.visual_healer=best;State.visual_possible=best and range<=40 and los(best,p) and helper('is_immune_to_heal',p,0)~=true
       and helper('is_crowd_controlled',best,nil,0)~=true
     end
     if alive(State.visual_healer) then
      read(core.graphics.line_3d,pos,call(State.visual_healer,'get_position'),State.visual_possible and Color.new(60,230,110,230) or Color.new(255,160,40,230),2,1,false)
     end
    end
   end
  end
  Lib.DangerZones.render(controls.danger_zones:get_state() and controls.world_visuals:get_state(),core.graphics,Color)
  Lib.BossCoach.render(controls.boss_coach:get_state() and controls.world_visuals:get_state(),core.graphics,Color)
  Lib.BossHUD.render({enabled=controls.boss_coach:get_state(),
   active=Lib.BossCoach.active,status=Lib.BossCoach.status,instance=read(core.get_instance_name)})
  Lib.UI.render(gui_state(),gui_action)
  local c=M.context or {}
 end) end
if core.register_on_spell_cast_callback then core.register_on_spell_cast_callback(function(data)
 helper("on_spell",data)
 local p=core.object_manager.get_local_player()
 Lib.InterruptCoordination.observe(data,now(),{player=p,guid=guid,same=function(a,b)return guid(a)==guid(b) end,enemy=function(u)return enemy(p,u) end})
 Lib.Intel.observe_spell(data,now(),guid,function(u)return enemy(p,u) end)
 if type(data)=="table" and data.caster and guid(data.caster)==guid(p) then
  local spell_id=tonumber(data.spell_id)
  if spell_id==8613 then Lib.G.confirm_skin(true,Lib.T) end
  confirm(spell_id,true,data.target)
 end
end) end
if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event,args)
 local event_player=core.object_manager.get_local_player()
 Lib.ThreatLearning.on_event(event,args,event_player,guid,mode,now())
  if event=='PLAYER_LOGOUT' or event=='PLAYER_LEAVING_WORLD' then Lib.ThreatLearning.flush(true,now()) end
 if event=='ARENA_PREP_OPPONENT_SPECIALIZATIONS' or event=='PVP_MATCH_ACTIVE' then reset_match_state(event) end
 if event=='DUEL_REQUESTED' or event=='DUEL_INBOUNDS' then
  if not State.duel_active then reset_match_state(event) end
  State.duel_active=true
 end
 if event=='DUEL_FINISHED' or event=='DUEL_CANCELLED' or event=='PVP_MATCH_COMPLETE' then
  State.duel_active=false;reset_match_state(event)
 end
 if event=='UI_ERROR_MESSAGE' and args then
  local host_error=args[2] or args[1]
  if pending then
   pending.host_error=tostring(host_error)
   Lib.T.note('CAST_ERROR',{'spell='..tostring(pending.id),'target='..tostring(pending.target_name),'host_error='..tostring(host_error)})
  else Lib.T.note('UI_ERROR',{'host_error='..tostring(host_error)}) end
  Lib.G.skin_error(host_error,Lib.T)
 end
 if args and args[1]=="player" then
  local id=tonumber(args[3]) or tonumber(args[4])
  if event=="UNIT_SPELLCAST_SUCCEEDED" or event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED" then
   Lib.T.note("EVENT",{event,"spell="..tostring(id)})
  end
  if event=="UNIT_SPELLCAST_SUCCEEDED" then if id==8613 then Lib.G.confirm_skin(true,Lib.T) end;confirm(id,true)
  elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED" then if id==8613 then Lib.G.confirm_skin(false,Lib.T) end;confirm(id,false) end
 end
end) end
M.main=function() return true end
M.update=safe_update;M.options=opts;M.gui_action=gui_action;M.confirm=confirm;M.dummy_profile=dummy_profile
return M
