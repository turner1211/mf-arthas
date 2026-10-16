local M={status="Starting"}
local Identity=require('ar_identity')
local decision_signature=""
local decision_time=-math.huge
local path=Identity.session_file
local data_path=Identity.history_file
local enabled,lines,run_start,last_state=true,{},1,-math.huge
local head,count,total=1,0,0
local batch,batch_bytes,last_flush,last_persist={},0,-math.huge,-math.huge
local write_retry=0
local run={active=false,requests=0,success=0,failed=0}
local state_interval=1
local idle_signature,idle_state_time='',-math.huge
local persistent=''
-- Keep a compact crash-recovery tail. Rewriting a 1.5 MB data file every few
-- seconds caused visible OneDrive/I/O stalls even though the append-only log
-- already retains the complete session.
local persistent_limit=524288
local Text=require('ar_text')
local function clean(x) return Text.clean(x or '-'):gsub('|',' ') end
local function now() return core.time() end
local function replace_history(text)
 if type(core.delete_data_file)~='function' or type(core.create_data_file)~='function'
    or type(core.write_data_file)~='function' then return false,'replace API unavailable' end
 local size=type(core.get_data_file_size)=='function' and core.get_data_file_size(data_path) or 0
 if type(size)=='number' and size>0 and core.delete_data_file(data_path)~=true then return false,'history delete failed' end
 core.create_data_file(data_path)
 if core.write_data_file(data_path,text)==false then return false,'history write failed' end
 return true
end
function M.flush(force)
 if #batch==0 or now()<write_retry or not force and now()-last_flush<0.5 then return end
 last_flush=now()
 local text=table.concat(batch);batch={};batch_bytes=0
 local ok,err=pcall(function()
  assert(core.write_log_file,'log writer unavailable');core.write_log_file(path,text)
  if type(core.write_data_file)=='function' then
   persistent=persistent..text
   if #persistent>persistent_limit then
    persistent=persistent:sub(#persistent-persistent_limit+1)
    local first=persistent:find('\n',1,true);if first then persistent=persistent:sub(first+1) end
   end
   if force or now()-last_persist>=10 then
    local saved,reason=replace_history(persistent)
    if saved then last_persist=now() else M.status='Recording; persistent snapshot unavailable / '..clean(reason) end
   end
  end
 end)
 M.status=ok and 'Recording / '..count..' lines' or 'File unavailable; memory retained / '..clean(err)
 if not ok then write_retry=now()+5 end
end
function M.note(kind,fields)
 if not enabled then return end
 local s={"[ARLOG]",kind,"t="..string.format("%.2f",now())}
 for _,v in ipairs(fields or {}) do s[#s+1]=clean(v) end
 local line=table.concat(s," | ")
 total=total+1
 if count<5000 then lines[(head+count-1)%5000+1]=line;count=count+1
 else lines[head]=line;head=head%5000+1 end
 if batch_bytes+#line<131072 then batch[#batch+1]=line..'\n';batch_bytes=batch_bytes+#line+1 end
end
pcall(function()
 core.create_log_folder(Identity.log_folder)
 local exists=false;local entries=type(core.read_log_dir)=='function' and core.read_log_dir(Identity.log_folder) or nil
 if type(entries)=='table' then for _,name in pairs(entries) do if name=='session.md' then exists=true end end end
 if not exists then core.create_log_file(path) end
 if type(core.create_data_folder)=='function' then core.create_data_folder(Identity.log_folder) end
 local size=type(core.get_data_file_size)=='function' and core.get_data_file_size(data_path) or 0
 if type(size)=='number' and size>persistent_limit*2 then
  persistent='[ARLOG] | HISTORY_RESET | reason=oversize snapshot | previous_bytes='..tostring(size)..'\n'
  replace_history(persistent)
 elseif type(size)=='number' and size>0 and type(core.read_data_file)=='function' then persistent=core.read_data_file(data_path) or ''
 elseif type(core.create_data_file)=='function' then core.create_data_file(data_path) end
end)
for line in persistent:gmatch('[^\r\n]+') do
 total=total+1
 if count<5000 then lines[(head+count-1)%5000+1]=line;count=count+1 else lines[head]=line;head=head%5000+1 end
end
run_start=total+1
function M.set_enabled(v)
 v=v==true
 if enabled~=v then if not v then M.flush(true) end;enabled=v;M.status=enabled and 'Recording' or 'Paused' end
 M.flush(false)
end
function M.path() return "scripts_log/"..path end
function M.saved_path() return "scripts_data/"..data_path end
function M.saved_log() return persistent end
function M.set_state_interval(v) if type(v)=='number' then state_interval=math.max(1,math.min(5,v)) end end
function M.current_run()
 local out={};local oldest=total-count+1
 if run_start<oldest then out[#out+1]='[ARLOG] | COPY_TRUNCATED | older rows='..(oldest-run_start) end
 for seq=math.max(run_start,oldest),total do out[#out+1]=lines[(head+seq-oldest-1)%5000+1] end
 return table.concat(out,"\n")
end
function M.run_status() return run.active and string.format("%s | %.0fs | %d confirmed",run.mode,now()-run.start,run.success) or "Waiting for combat" end
local function finish(reason)
 if not run.active then return end
 M.note("RUN_END",{"mode="..run.mode,"reason="..reason,"duration="..(now()-run.start),"requests="..run.requests,"success="..run.success,"failed="..run.failed})
 M.note('RUN_DIAGNOSIS',{'samples='..tostring(run.samples or 0),
  'no_target='..tostring(run.no_target or 0),'unarmed='..tostring(run.unarmed or 0),
  'outside_melee='..tostring(run.outside_melee or 0),'sap_block='..tostring(run.sap_block),
  'lowest_hp='..tostring(run.lowest_hp),'highest_incoming='..tostring(run.highest_incoming or 0),
  'interpretation='..(run.requests==0 and (run.no_target or 0)==(run.samples or 0) and 'no attackable target observed; damage/CC performance cannot be evaluated' or 'review requests, failures and state samples')})
 run.active=false
 M.flush(true)
end
function M.state(c,combat)
 if run.active and (not combat or run.mode~=c.mode) then finish(not combat and "combat ended" or "profile changed") end
 if combat and not run.active then
  run={active=true,mode=c.mode,start=now(),requests=0,success=0,failed=0};run_start=total+1;last_state=-math.huge
  M.note("RUN_START",{"mode="..c.mode,"version="..require('ar_version')})
 end
 local idle_key=table.concat({tostring(c.mode),tostring(c.target_name),tostring(c.attackable),tostring(c.in_city),tostring(c.next_spell),tostring(c.next_reason)},':')
 if not combat and idle_key==idle_signature and now()-idle_state_time<30 then return end
 if combat and now()-last_state<state_interval then return end
 last_state=now();idle_signature=idle_key;idle_state_time=now()
 if run.active then
  run.samples=(run.samples or 0)+1
  if not c.attackable then run.no_target=(run.no_target or 0)+1
  elseif not c.engagement_armed then run.unarmed=(run.unarmed or 0)+1
  elseif not c.melee_range then run.outside_melee=(run.outside_melee or 0)+1 end
  run.sap_block=c.sap_status
  run.lowest_hp=math.min(run.lowest_hp or 100,c.self_hp or 100)
  run.highest_incoming=math.max(run.highest_incoming or 0,c.prediction and c.prediction.incoming or 0)
 end
 M.note("STATE",{"mode="..c.mode,"hero="..c.hero,"hp="..c.self_hp,"target_hp="..c.target_hp,
  "energy="..c.energy,"energy_pct="..string.format("%.1f",c.energy_pct or -1),"cp="..c.cp,"nearby="..c.nearby,"nearby_raw="..tostring(c.raw_nearby),"aoe_safe="..tostring(c.aoe_safe),
  "opener="..tostring(c.open_done),"decision="..tostring(c.last),"pending="..tostring(c.pending),
  "training_dummy="..tostring(c.training==true),"target="..tostring(c.target_name),
  "attackable="..tostring(c.attackable),"is_dummy="..tostring(c.target_dummy),"target_is_self="..tostring(c.target_is_self),
  "damage_enabled="..tostring(c.damage_enabled),"combat="..tostring(c.combat),"engagement_armed="..tostring(c.engagement_armed),"auto_attacking="..tostring(c.auto_attacking),
  "spread_status="..tostring(c.spread_status),"spread_candidates="..tostring(c.spread_candidates),
  "stealth="..tostring(c.stealth),"in_city="..tostring(c.in_city),"city_reason="..tostring(c.city_reason),"duel_active="..tostring(c.duel_active),"sap_target="..tostring(c.sap_target),"sap_status="..tostring(c.sap_status),
  "enemies="..tostring(c.enemies and #c.enemies or 0),"kill_window="..tostring(c.kill_window),"kill_intent="..tostring(c.kill_intent),"cc_status="..tostring(c.cc_status),
  "next_spell="..tostring(c.next_spell),"next_reason="..tostring(c.next_reason),"melee_range="..tostring(c.melee_range),
  "garrote_s="..tostring(c.garrote_remaining or 'unknown'),"rupture_s="..tostring(c.rupture_remaining or 'unknown'),
  "envenom_s="..string.format('%.1f',c.envenom_remaining or 0),"healer_cc="..tostring(c.healer_cc),"healer_cc_remaining="..tostring(c.healer_cc_remaining),"healer_cc_secure="..tostring(c.healer_cc_secure),"healer_cc_expiring="..tostring(c.healer_cc_expiring),"healer_cc_reason="..tostring(c.healer_cc_reason),
  "target_stunned="..tostring(c.target_stunned),"burst_hold="..tostring(c.burst_hold),
  "target_ttd="..tostring(c.ttd),"ttd_source="..tostring(c.ttd_source),"target_loss_rate="..tostring(c.target_loss_rate),"target_recovering="..tostring(c.target_recovering),"target_casting="..tostring(c.target_casting),"target_collapse="..tostring(c.target_collapse),
  "target_marked="..tostring(c.target_marked),"mark_elsewhere="..tostring(c.mark_elsewhere_name),"unshakeable_stacks="..tostring(c.unshakeable_stacks),"poison_uptime_commit="..tostring(c.poison_uptime_commit),"cooldown_target_lock="..tostring(c.cooldown_target_lock),
  "kill_reason="..tostring(c.kill and c.kill.reason),"burst_status="..tostring(c.burst_status),
  "intel="..tostring(c.intel_status),"cc_chain_next="..tostring(c.cc_chain_next),"cross_control_ready="..tostring(c.cross_control_ready),"matchup_defense="..tostring(c.matchup_defense),
  "blind_chain_target="..tostring(c.blind_chain_target),"blind_chain_s="..tostring(c.blind_chain_remaining),
  "target_race="..tostring(c.target_race),"bleed_cleanse_available="..tostring(c.bleed_cleanse_available),"bleed_cleanse_remaining="..tostring(c.bleed_cleanse_remaining),
  "bleeds_removed_spell="..tostring(c.bleeds_removed_spell),"force_garrote="..tostring(c.force_missing_garrote),"force_rupture="..tostring(c.force_missing_rupture),
  "enemy_external="..tostring(c.enemy_external),"enemy_external_spell="..tostring(c.enemy_external_spell),"enemy_external_s="..tostring(c.enemy_external_remaining),
  "enemy_trinket_down="..tostring(c.enemy_trinket_down),"enemy_trinket_s="..tostring(c.enemy_trinket_remaining),"enemy_trinket_kind="..tostring(c.enemy_trinket_kind),"healer_trinket_down="..tostring(c.healer_trinket_down),"healer_trinket_s="..tostring(c.healer_trinket_remaining),"healer_trinket_kind="..tostring(c.healer_trinket_kind),
  "healer_external_spent="..tostring(c.healer_external_spent_recent),"healer_external_spell="..tostring(c.healer_external_spent_spell),"healer_external_age="..tostring(c.healer_external_spent_age),
  "arena_reset="..tostring(c.arena_reset),"arena_reset_reason="..tostring(c.arena_reset_reason),
  "pvp_tactics="..tostring(c.pvp_status),"bomb_value="..tostring(c.bomb_value),"ally_burst="..tostring(c.ally_burst),"player_flag_carrier="..tostring(c.player_flag_carrier),
  "self_peel="..tostring(c.self_peel_plan),"self_peel_urgent="..tostring(c.self_peel_urgent),"player_attackers="..tostring(c.player_attackers),"pet_attackers="..tostring(c.pet_attackers),"effective_attackers="..tostring(c.attackers),
  "ally_threats="..tostring(c.ally_threats),"friendly_healer="..tostring(c.friendly_healer_available),"friendly_healer_mana="..tostring(c.friendly_healer_mana),
  "enemy_healer_mana="..tostring(c.enemy_healer_mana),"enemy_healer_exhausted="..tostring(c.enemy_healer_exhausted),
  "dampening_active="..tostring(c.dampening_active),"dampening_stacks="..tostring(c.dampening_stacks),"high_dampening="..tostring(c.high_dampening),
  "healer_tether_safe="..tostring(c.healer_tether_safe),"healer_tether_reason="..tostring(c.healer_tether_reason),
  "friendly_healer_cast_threat="..tostring(c.friendly_healer_cast_threat),"healer_smoke_cover="..tostring(c.friendly_healer_smoke_cover),"healer_cast_imminent="..tostring(c.friendly_healer_cast_imminent),"healer_cast_outside_bomb="..tostring(c.friendly_healer_cast_outside_bomb),"healer_cast_kick_reachable="..tostring(c.friendly_healer_cast_kick_reachable),
  "defensive_reserves="..tostring(c.defensive_reserves),"defensive_dry="..tostring(c.defensive_dry),
  "interrupt_opportunities="..tostring(c.interrupt_opportunities),"cast_health="..tostring(c.cast_health),
  "interrupt_wait="..tostring(c.interrupt_wait),
  "replay="..tostring(c.replay_status),"performance="..tostring(c.performance_status),
  "cc_readiness="..tostring(c.cc_readiness),"player_stunned="..tostring(c.defense_status_stun),"evasion_effective="..tostring(c.evasion_effective),"defense_enabled="..tostring(c.defense_enabled),"defense_status="..tostring(c.defense_status),
  "learned_pressure="..tostring(c.prediction and c.prediction.learned_pressure or 0),"learned_samples="..tostring(c.prediction and c.prediction.learned_samples or 0),"learned_untargeted_casts="..tostring(c.prediction and c.prediction.untargeted_casts or 0),
  "learned_spells="..tostring(c.learned_spell_count or 0),"learned_total_samples="..tostring(c.learned_sample_count or 0),
  "danger_zone="..tostring(c.danger_zone_status),
  "kidney_ready_age="..string.format('%.1f',c.kidney_ready_age or 0),
  "kidney_cd="..string.format('%.1f',c.kidney_cd or -1),
  "blind_ready_age="..string.format('%.1f',c.blind_ready_age or 0),
  "enrage_target="..tostring(c.enrage_target_name or 'none'),
  "keystone="..tostring(c.keystone_level or 'none'),"fortified="..tostring(c.fortified==true),"tyrannical="..tostring(c.tyrannical==true),
  "utility_poison="..tostring(c.utility_poison or 'pending out of combat'),
  "boss_coach="..tostring(c.boss_coach_status),
  "boss_plan="..tostring(c.boss_plan_status),"boss_move="..tostring(c.boss_movement_soon),"boss_defense="..tostring(c.boss_defensive_soon),"boss_cd_hold="..tostring(c.boss_cooldown_hold),"boss_priority_add="..tostring(c.boss_priority_add),"boss_priority_name="..tostring(c.boss_priority_name),
  "forecast="..tostring(c.prediction and c.prediction.reason or "disabled")})
end
function M.decision(c)
 local signature=table.concat({c.mode,tostring(c.target_name),tostring(c.next_spell),tostring(c.next_reason),tostring(c.burst_hold)},':')
 if signature==decision_signature or now()-decision_time<0.3 then return end
 decision_signature=signature;decision_time=now()
 M.note('DECISION',{'mode='..c.mode,'target='..tostring(c.target_name),'next='..tostring(c.next_spell),'reason='..tostring(c.next_reason),'burst_hold='..tostring(c.burst_hold)})
end
function M.request(id,target,accepted,why,c)
 if run.active then run.requests=run.requests+1 end
 M.note(accepted and "REQUEST" or "REJECT",{"spell="..id,"target="..clean(target),"reason="..clean(why),"mode="..tostring(c and c.mode),"energy="..tostring(c and c.energy),"cp="..tostring(c and c.cp),"forecast="..tostring(c and c.prediction and c.prediction.reason)})
end
function M.event(id,success,req)
 if run.active then local k=success and "success" or "failed";run[k]=run[k]+1 end
 M.note(success and "SUCCESS" or "FAILED",{"spell="..id,"target="..tostring(req and req.target_name),"latency="..string.format("%.2f",req and now()-req.time or 0),"reason="..tostring(req and req.why),"host_error="..clean(req and req.host_error or 'none')})
end
function M.clear()
 local ok=pcall(function()
  assert(core.delete_log_file);core.delete_log_file(path);core.create_log_file(path)
  persistent='';replace_history('')
 end)
 if not ok then M.status="Clear failed; log retained";return false end
 lines={};head,count,total=1,0,0;batch={};batch_bytes=0;write_retry=0;last_persist=-math.huge;run_start=1;last_state=-math.huge;idle_signature='';idle_state_time=-math.huge;decision_signature='';decision_time=-math.huge;run.requests=0;run.success=0;run.failed=0;run.start=now();M.note("LOG_CLEARED");return true
end
M.note("LOGGER_START",{"entity="..Identity.logger,"owner="..Identity.entity,"version="..require('ar_version'),"session="..tostring(type(core.get_server_time)=='function' and core.get_server_time() or 'unknown'),"recovered_lines="..tostring(total)})
M.flush(true)
M.owner=Identity.entity
M.entity=Identity.logger
return M
