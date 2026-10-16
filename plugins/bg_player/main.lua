-- Stop the previously loaded generation before replacing its public API. Core
-- callbacks cannot be unregistered, so every callback below also checks this
-- generation token and becomes inert after the next script reload. This keeps
-- an accidental duplicate package from running two controllers at once.
local previous_instance=rawget(_G,"SylvanasBattlegroundBot")
if type(previous_instance)=="table" and type(previous_instance.stop)=="function" then
 pcall(previous_instance.stop)
end
local instance_generation=(tonumber(rawget(_G,"SylvanasBattlegroundGeneration")) or 0)+1
_G.SylvanasBattlegroundGeneration=instance_generation
local function instance_current()
 return rawget(_G,"SylvanasBattlegroundGeneration")==instance_generation
end
local plugin_load_started=core.time()
local plugin_load_clock,plugin_load_clock_source=core.time,"core.time"
if type(core.cpu_ticks)=="function" and type(core.cpu_ticks_per_second)=="function" then
 local ok,rate=pcall(core.cpu_ticks_per_second)
 if ok and type(rate)=="number" and rate>0 and rate<math.huge then
  plugin_load_clock=function() return core.cpu_ticks()/rate end;plugin_load_clock_source="core.cpu_ticks"
 end
elseif os and type(os.clock)=="function" then plugin_load_clock=os.clock;plugin_load_clock_source="os.clock" end
local plugin_load_clock_started=plugin_load_clock()
local Controller=require("bg_controller")
local ObstacleProbe=require("bg_obstacle_probe")
local ok_vec,Vec3=pcall(require,"common/geometry/vector_3")
local function vec3(x,y,z) return ok_vec and Vec3 and Vec3.new and Vec3.new(x,y,z) or {x=x,y=y,z=z} end
local Planner=require("bg_planner")
local Compat=require("bg_compat").new(core)
local Client=require("bg_client_profile").new(core)
local Gui=require("bg_gui")
local Theme=require("bg_theme")
local Health=require("bg_health").new()
local Reader=require("bg_reader").new()
local Build=require("header")
local Persistent=require("bg_persistent_log")
local persistent_log=Persistent.new(Build.version)
local Debug=require("bg_debug")
local debugger=Debug.new(persistent_log)
local Renderer=require("bg_render").new(debugger)
local Interaction=require("bg_interaction")
local Preparation=require("bg_preparation")
local Powerups=require("bg_powerups")
local Rules=require("bg_rules")
local Safety=require("bg_safety")
local Snapshot=require("bg_snapshot")
local Detect=require("bg_detect")
local Builtin=require("bg_builtin_objectives")
local PathRender=require("bg_path_render")
local Routes=require("bg_routes")
local Darkspear=require("bg_darkspear")
local ForeverRecovery=require("bg_forever_recovery")
local LevelPolicy=require("bg_level_policy")
local ForeverLevelRules=require("bg_forever_level_rules")
local ForeverMMaps=require("bg_forever_mmap_reference")
local MountSelection=require("bg_mount_selection")
local Navigation=require("bg_navigation")
local MountRecovery=require("bg_mount_recovery")
local MountVendor=require("bg_mount_vendor")
local Faction=require("bg_faction")
local CastHold=require("bg_cast_hold")
local MovementImpairment=require("bg_movement_impairment")
local Callouts=require("bg_callouts")
local RouteStore=require("bg_route_store")
local MatchMetrics=require("bg_match_metrics")
local Readiness=require("bg_readiness")
local LiveAcceptance=require("bg_live_acceptance")
local Prediction=require("bg_prediction")
local FlowPrediction=require("bg_flow_prediction")
local Performance=require("bg_performance")
local TargetForecast=require("bg_target_forecast")
local TrinityForever=require("bg_trinitycore_forever")
local NavFaction=require("bg_nav_faction")
local Object=require("bg_object")
local LocalLink=require("bg_local_link").new()
Compat.set_local_queue_reader(LocalLink.queues)
local tree=core.menu.tree_node()
local enabled=core.menu.checkbox(false,"sylvanas_bg_enabled_v1")
local QueueModes=require("bg_queue_modes")
local queue_mode=core.menu.combobox(1,"sylvanas_bg_queue_mode_v1")
local queues={core.menu.slider_int(0,2000,0,"sylvanas_bg_queue_v1"),
 core.menu.slider_int(0,2000,0,"sylvanas_bg_brawl_queue_v1"),
 core.menu.slider_int(0,2000,0,"sylvanas_bg_epic_queue_v1"),
 core.menu.slider_int(0,2000,0,"sylvanas_bg_blitz_queue_v1")}
local function selected_mode() Client:refresh_if_due(core.time(),30);return Client:queue_mode(QueueModes,queue_mode:get()) end
local function queue_labels() Client:refresh_if_due(core.time(),30);return Client:queue_labels(QueueModes) end
local function selected_queue() return queues[selected_mode().index] end
local function effective_queue_id()
 local configured=selected_queue():get()
 if configured~=0 then return configured end
 if not Compat.uses_local_queue_reader() then return 0 end
 return LocalLink.queues:catalog(selected_mode().key,core.time()) or 0
end
local role=core.menu.slider_int(0,14,8,"sylvanas_bg_role_v1")
local damage_style=core.menu.combobox(1,"sylvanas_bg_damage_style_v1")
local range=core.menu.slider_int(3,40,5,"sylvanas_bg_range_v1")
-- v2 deliberately resets the legacy default-on persisted value. Existing
-- installs otherwise keep constructing the expensive HUD after this update.
local show_hud=core.menu.checkbox(false,"sylvanas_bg_hud_enabled_v2")
-- The path overlay performs multiple 3D draw calls every rendered frame.
-- Keep it available for route debugging, but use a new default-off key so
-- existing installs do not carry the legacy always-on value into gameplay.
local show_path=core.menu.checkbox(false,"sylvanas_bg_path_overlay_v3")
local provider,context,objective_actions,reader_match,last_queue_link_state
local census_seen={};local census_count=0;local next_census=0;local last_profile,last_role,last_objective_source
local moving_census_entries={[60140]=true}
local route_seen={};local next_route_sample=0
local preparation=Preparation.new();local next_mount=0;local mount_settle;local mount_pending_until
local HEALTHSTONES={
 [5512]=true,[5511]=true,[5509]=true,[5510]=true,[9421]=true,
 [19004]=true,[19005]=true,[22103]=true,[22104]=true,[22105]=true,
 [224464]=true
}
local healthstone_scan_at=0;local healthstone_owned=false
local function has_healthstone(now)
 now=tonumber(now) or 0
 if now<healthstone_scan_at then return healthstone_owned end
 healthstone_scan_at=now+1;healthstone_owned=false
 local ok,helper=pcall(require,"common/utility/inventory_helper")
 if not ok or type(helper)~="table" or type(helper.get_character_bag_slots)~="function" then return false end
 local read,slots=pcall(function() return helper:get_character_bag_slots() end)
 if not read or type(slots)~="table" then return false end
 for _,slot in pairs(slots) do
  local item=type(slot)=="table" and slot.item or nil
  local count=type(slot)=="table" and tonumber(slot.stack_count) or nil
  if item and (count==nil or count>0) then
   local id_ok,id=pcall(function() return type(item.get_item_id)=="function" and item:get_item_id() end)
   if id_ok and HEALTHSTONES[tonumber(id)] then healthstone_owned=true;break end
   local name_ok,name=pcall(function() return type(item.get_name)=="function" and item:get_name() end)
   name=name_ok and type(name)=="string" and name:lower() or ""
   if name:find("healthstone",1,true) then healthstone_owned=true;break end
  end
 end
 return healthstone_owned
end
local last_mount_detail,last_mount_detail_at
local callouts=Callouts.new()
local faction=Faction.new()
local route_store=RouteStore.new();local match_metrics=MatchMetrics.new()
local readiness=Readiness.new(plugin_load_started,Client.route_scope)
local live_acceptance=LiveAcceptance.new()
local live_acceptance_load_at=plugin_load_started+10
local readiness_load_at=plugin_load_started+10
local prediction=Prediction.new()
local flow_prediction=FlowPrediction.new()
local performance=Performance.new()
local target_forecast=TargetForecast.new()
target_forecast.role_cache=require("bg_role_cache").new(2)
local critical_health_pursuit=false
local powerups=Powerups.new()
local seething_launch_active=false;local next_seething_jump=0;local seething_landing
local seething_ground_targeted=false;local seething_progress_position;local seething_progress_at=0
local cached_role,cached_role_guid
local log_rows={}
local window_key_down=false
local tick_objects
local function runtime_objects()
 if tick_objects then return tick_objects end
 local manager=core.object_manager or {};local ok,objects=pcall(function()
  if type(manager.get_all_objects)=="function" then return manager.get_all_objects() end
  if type(manager.get_visible_objects)=="function" then return manager.get_visible_objects() end
 end)
 tick_objects=ok and type(objects)=="table" and objects or {}
 return tick_objects
end
local function mount_detail(detail,now)
 if detail~=last_mount_detail or now-(last_mount_detail_at or 0)>=30 then
  last_mount_detail=detail;last_mount_detail_at=now
  debugger:add("mount",detail,now)
 end
end
local nav_health_next,nav_health_pending,nav_health_started=0,false,0
local nav_health_state="not_checked"
local sentinel_provider_kind="missing"
local ARTHAS_OWNER="sylvanas_battleground_bot"
local ARTHAS_CONTRACT={protocol=3,map_schema=1,api=1}
local arthas_enhancements,arthas_guarded_client,arthas_completed_client,arthas_lease_active,arthas_disabled_release_done
local arthas_contract_state="not_checked";local arthas_contract_blocked=false
local arthas_heartbeat_next=0
local arthas_engine_next=0;local arthas_engine_enabled;local arthas_engine_state="not_checked";local arthas_engine_error
local function complete_arthas_guard(client,enhancements)
 if type(client)~="table" then return nil end
 local move_ok,move=pcall(function() return client.move_to end)
 if not move_ok or type(move)~="function" then return client end
 local stop_ok,stop=pcall(function() return client.stop end)
 if stop_ok and type(stop)=="function" then return client end
 local facade={}
 setmetatable(facade,{__index=function(_,key)
  if key=="stop" then return function()
   local release=type(enhancements)=="table" and enhancements.release
   if type(release)~="function" then return false end
   local ok,result=pcall(release,ARTHAS_OWNER);return ok and result~=false
  end end
  local ok,value=pcall(function() return client[key] end)
  if not ok then return nil end
  if type(value)=="function" then return function(_,...)
   local found,current=pcall(function() return client[key] end)
   if not found or type(current)~="function" then return false end
   return current(client,...)
  end end
  return value
 end})
 return facade
end
local function guarded_arthas_client()
 local enhancements=rawget(_G,"ArthasNavEnhancements")
 if enhancements~=arthas_enhancements then
  arthas_enhancements=enhancements;arthas_guarded_client=nil;arthas_completed_client=nil;arthas_lease_active=false;arthas_disabled_release_done=false
  arthas_contract_state="not_checked";arthas_contract_blocked=false
 end
 if arthas_contract_blocked then return nil end
 if type(enhancements)=="table" and type(enhancements.get_client)=="function" and not arthas_guarded_client then
  if type(enhancements.check_compatibility)=="function" then
   local checked,compatible,reason=pcall(enhancements.check_compatibility,ARTHAS_OWNER,ARTHAS_CONTRACT)
   if not checked or compatible~=true then
    arthas_contract_state=checked and tostring(reason or "consumer_version_mismatch") or "contract_check_error"
    arthas_contract_blocked=true;return nil
   end
  end
  local ok,result=pcall(enhancements.get_client,ARTHAS_OWNER,ARTHAS_CONTRACT)
  if ok and type(result)=="table" then
   arthas_contract_state="compatible";arthas_guarded_client=result;arthas_completed_client=complete_arthas_guard(result,enhancements)
  else arthas_contract_state=ok and "client_unavailable" or "client_error" end
 end
 return arthas_completed_client or arthas_guarded_client
end
local function maintain_arthas_lease(active,now)
 local enhancements=rawget(_G,"ArthasNavEnhancements")
 if type(enhancements)~="table" then arthas_lease_active=false;return end
 now=tonumber(now) or 0
 if active and now>=arthas_heartbeat_next and type(enhancements.heartbeat)=="function" then
  local ok,result=pcall(enhancements.heartbeat,ARTHAS_OWNER)
  arthas_lease_active=ok and result~=false
  arthas_heartbeat_next=now+(arthas_lease_active and 5 or 1)
  if arthas_lease_active then arthas_disabled_release_done=false end
 elseif not active and not arthas_disabled_release_done and type(enhancements.release)=="function" then
  local ok,result=pcall(enhancements.release,ARTHAS_OWNER)
  arthas_lease_active=false;arthas_disabled_release_done=ok and result~=false;arthas_heartbeat_next=0
 end
end
local function maintain_arthas_engine(active,now)
 now=tonumber(now) or 0;active=active==true
 if arthas_engine_enabled==active and now<arthas_engine_next then return end
 arthas_engine_enabled=active;arthas_engine_next=now+5
 local bootstrap=rawget(_G,"ArthasNavBootstrap")
 if type(bootstrap)~="table" or type(bootstrap.tick)~="function" then
  arthas_engine_state="bootstrap_missing";arthas_engine_error="ArthasNavBootstrap.tick unavailable";arthas_engine_next=now+2;return
 end
 local ok,result=pcall(bootstrap.tick,"bg_player",active)
 if ok and result~=false then
  arthas_engine_state=active and "start_requested" or "stop_requested";arthas_engine_error=nil
 else
  arthas_engine_state="request_failed";arthas_engine_error=tostring(ok and "rejected" or result);arthas_engine_next=now+1
 end
end
local navigation_quarantine={}
local function navigation_identity(name)
 name=tostring(name or "unknown")
 if name:find("ArthasNav",1,true) then return "arthas_navmesh" end
 return name
end
local function navigation_allowed(name)
 local until_at=tonumber(navigation_quarantine[navigation_identity(name)]) or 0
 return not core.time or core.time()>=until_at
end
local navigation_discovery="not_scanned";local navigation_discovery_attempts=0;local navigation_discovery_next=0
local function probe_navigation_exports(now)
 if navigation_discovery_attempts>=5 or now<navigation_discovery_next then return end
 navigation_discovery_attempts=navigation_discovery_attempts+1;navigation_discovery_next=now+4
 local function methods(value,names)
  if type(value)~="table" then return "missing" end
  local available={}
  for _,name in ipairs(names) do if type(value[name])=="function" then available[#available+1]=name end end
  return "loaded["..(#available>0 and table.concat(available,",") or "no expected methods").."]"
 end
 local arthas=rawget(_G,"ArthasNav");local enhancements=rawget(_G,"ArthasNavEnhancements")
 local arthas_methods=methods(arthas,{"move_to","stop","get_state","get_current_path"})
 if type(arthas)=="table" and type(arthas.client)=="table" then
  arthas_methods="loaded[client:"..methods(arthas.client,{"move_to","stop","get_state","get_current_path"}):gsub("^loaded%[",""):gsub("%]$","").."]"
 end
 local result=table.concat({
  "ArthasNav="..arthas_methods,
  "enhancements="..methods(enhancements,{"get_client","heartbeat","release","path_blocked"})
 },";")
 if result~=navigation_discovery then navigation_discovery=result;debugger:add("navigation_exports",result,now) end
 if type(enhancements)=="table" and type(enhancements.get_client)=="function" then navigation_discovery_attempts=5 end
end
local function nav_client_available(client)
 if type(client)~="table" then return false end
 local move_ok,move_method=pcall(function() return client.move_to end)
 if not move_ok or type(move_method)~="function" then return false end
 local server_ok,server_method=pcall(function() return client.is_server_available end)
 if not server_ok then return false end
 if type(server_method)~="function" then return true end
 local ok,available=pcall(server_method,client)
 return ok and available==true
end
local function nav()
 local arthas=rawget(_G,"ArthasNav")
 local guarded=guarded_arthas_client()
 if nav_client_available(guarded) and navigation_allowed("ArthasNav local navmesh") then
  sentinel_provider_kind="ArthasNav guarded local navmesh";return guarded
 end
 if not arthas_contract_blocked and type(arthas)=="table" and nav_client_available(arthas.client) and navigation_allowed("ArthasNav local navmesh") then
  sentinel_provider_kind="ArthasNav compatibility client";return arthas.client
 end
 sentinel_provider_kind=type(arthas)=="table" and "ArthasNav/unavailable" or "ArthasNav missing"
 return nil
end
local nav_faction=NavFaction.new(Client,nav,function(kind,detail,now) debugger:add(kind,detail,now) end)
local nav_telemetry=require("bg_nav_telemetry").new(function(message) debugger:add("navigation",message,core.time()) end,function() return core.time() end)
local function navigation_ready()
 local n=nav();if not n then nav_health_state="client_missing";return false end
 local method_ok,server_method=pcall(function() return n.is_server_available end)
 if method_ok and type(server_method)~="function" then
  -- Local navmesh providers do not necessarily have a remote server. They
  -- are usable when they expose the common movement contract; discovery and
  -- readiness must agree on that contract.
  local move_ok,move_method=pcall(function() return n.move_to end)
  if move_ok and type(move_method)=="function" then
   nav_health_pending=false;nav_health_state="local_ready"
   readiness:observe("sentinel",true)
   return true
  end
 end
 local ok,available=pcall(function() return server_method(n) end)
 if ok and available==true then
  nav_health_pending=false
  nav_health_state="ready"
  readiness:observe("sentinel",true)
  return true
 end
 local now=core.time()
 if nav_health_pending and now-nav_health_started>=10 then
  nav_health_pending=false;nav_health_state="probe_timeout";nav_health_next=now
  debugger:add("navigation","health_check_timeout",now)
 end
 local health_method_ok,health_method=pcall(function() return n.health_check end)
 if not nav_health_pending and now>=nav_health_next and health_method_ok and type(health_method)=="function" then
  nav_health_pending=true;nav_health_started=now;nav_health_next=now+5;nav_health_state="probing"
  local dispatched=pcall(function() health_method(n,function(result)
   nav_health_pending=false
   nav_health_state=result==true and "reconnected" or "probe_failed"
   if result==true then debugger:add("navigation","health_check_reconnected",core.time()) end
  end) end)
  if not dispatched then nav_health_pending=false;nav_health_state="probe_dispatch_failed" end
 elseif not health_method_ok or type(health_method)~="function" then nav_health_state="health_check_missing"
 end
 return false
end
local plugin_init_ms
local next_supervisor_tick=0
local function detected_role(player)
 local role_name=Theme.detect(player).role
 local guid_ok,guid=pcall(function() return player and type(player.get_guid)=="function" and player:get_guid() end)
 guid=guid_ok and guid or nil
 if guid and cached_role_guid and guid~=cached_role_guid then cached_role=nil end
 if guid then cached_role_guid=guid end
 if role_name~="unknown" then cached_role=role_name elseif cached_role then role_name=cached_role end
 if role_name=="unknown" then role_name=role:get()==2 and "tank" or role:get()==4 and "healer" or "damage" end
 return role_name,role_name=="tank" and 2 or role_name=="healer" and 4 or role_name=="damage" and 8 or role:get()
end
local function detected_damage_style(player)
 local choice=tonumber(damage_style:get()) or 1
 if choice==2 then return "melee","manual" end
 if choice==3 then return "ranged","manual" end
 local detected=Theme.detect(player).damage_style
 return (detected=="melee" or detected=="ranged") and detected or "unknown","automatic"
end
local function detected_level_policy(player,role_name,style)
 role_name=role_name or detected_role(player)
 style=style or detected_damage_style(player)
 return LevelPolicy.detect(player,Client:is_forever(),role_name,style)
end
local function detected_profile()
 Client:refresh_if_due(core.time(),30)
 return Detect.resolve(core.get_instance_id(),core.get_map_id(),core.get_instance_name and core.get_instance_name(),Client.family)
end
local navigation=Navigation.new(nav,function(event,goal) debugger:add(event,"destination_z="..tostring(goal.z),core.time()) end,
 function(goal)
  local input=core.input or {}
  if type(input.look_at)~="function" or type(input.move_forward_start)~="function" then return false end
  input.look_at(vec3(goal.x,goal.y,goal.z));input.move_forward_start();return true
 end,
 function()
  local input=core.input or {};if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
 end,
 function()
  local player=core.object_manager.get_local_player()
  return player and type(player.is_swimming)=="function" and player:is_swimming()==true
 end)
local mount_recovery=MountRecovery.new(function() navigation:stop() end,core.input and core.input.dismount)
local crowd_control_paused=false
local mount_vendor=MountVendor.new({
 inventory=core.inventory or {},
 objects=runtime_objects,
 can_repair=core.inventory and core.inventory.can_merchant_repair,
 repair_cost=core.inventory and core.inventory.get_total_repair_cost,
 repair=core.input and core.input.repair_all_items,
 close_merchant=core.input and core.input.close_merchant,
 interact=core.input and core.input.interact_with_object,
 stop=function() navigation:stop() end
})
local api={
 match_reset=function()
  if crowd_control_paused then navigation:resume("bg_crowd_control");crowd_control_paused=false end
  Reader:reset();reader_match=nil;context=nil
  prediction:reset()
  flow_prediction:reset()
  target_forecast:reset()
  target_forecast.role_cache:reset()
  critical_health_pursuit=false
  if callouts and type(callouts.reset)=="function" then callouts:reset() end
  if faction and type(faction.reset)=="function" then faction:reset() end
  Darkspear.reset()
  census_seen={};census_count=0;next_census=0
  route_seen={};next_route_sample=0
  if seething_launch_active and core.input and type(core.input.move_forward_stop)=="function" then core.input.move_forward_stop() end
  seething_launch_active=false;next_seething_jump=0;seething_landing=nil;seething_ground_targeted=false;seething_progress_position=nil;seething_progress_at=0
  mount_settle=nil;mount_pending_until=nil;last_mount_detail=nil;last_mount_detail_at=nil
  if mount_vendor then mount_vendor:reset() end
  Powerups.reset(powerups,nil)
 end,
 time=core.time,player=core.object_manager.get_local_player,
 instance_type=core.get_instance_type,
 corpse_position=core.game_ui.get_corpse_position,
 corpse_delay=core.game_ui.get_resurrect_corpse_delay,
 reclaim=core.input.resurrect_corpse,
 in_battleground=function() return core.get_instance_type()=="pvp" end,
 match_id=function() return tostring(core.get_instance_id())..":"..tostring(core.get_map_id()) end,
 queue_ready=function() return Compat.queue_ready(selected_mode().key) end,
 queue_allowed=function(player)
  local allowed,reason=Safety.queue_allowed(player)
  if not allowed then return false,reason end
  if Client:is_forever() then
   local level=LevelPolicy.read(player)
   -- Login/loading transitions can briefly hide the level API. Preserve the
   -- established live queue path until a valid level is observable.
   if level then
    local eligible,level_reason=ForeverLevelRules.queue_eligible(effective_queue_id(),level)
    if not eligible then return false,level_reason end
   end
  end
  -- The bundled local reader only certifies the current Random/Epic catalog.
  if Compat.uses_local_queue_reader() then
   local id,can_queue=LocalLink.queues:catalog(selected_mode().key,core.time())
   if not id then return false,"live_queue_catalog_required" end
   if not can_queue then return false,"queue_not_eligible" end
   if effective_queue_id()~=id then return false,"queue_catalog_mismatch" end
  end
  return true
 end,
 accept_allowed=function(player) return Safety.queue_allowed(player) end,
 queue_status=Compat.queue_status,
 queue_info=Compat.queue_info,
 queue_count=Compat.queue_count,
 match_state=Compat.match_state,
 match_complete=function(phase)
  -- TrinityCore uses WAIT_LEAVE=4. Retail/Sylvanas integrations have also
  -- exposed 5, so Forever accepts either only after the controller observed 3.
  return Client:is_forever() and (phase==4 or phase==5) or phase==5
 end,
 observe_team=function(player,phase)
  local p
  pcall(function() if player and type(player.get_position)=="function" then p=Snapshot.position(player:get_position()) end end)
  local raw=core.game_ui.get_battlefield_arena_faction and core.game_ui.get_battlefield_arena_faction()
  return faction and faction:observe(detected_profile(),p,raw,phase) or raw
 end,
 winner=Compat.winner,
 accept=function(i)
  debugger:add("queue_accept_attempt",string.format("slot=%s mode=%s queue_id=%s",tostring(i),selected_mode().key,tostring(effective_queue_id())),core.time())
  return Compat.accept(i,true)
 end,
 join=function(id,flags)
  debugger:add("queue_join_attempt",string.format("mode=%s queue_id=%s role_flags=%s",selected_mode().key,tostring(id),tostring(flags)),core.time())
  if selected_mode().key=="brawl" then Compat.join_brawl()
  elseif selected_mode().key=="blitz" then Compat.join_blitz()
  else Compat.join(id,flags) end
 end,leave=function()
  debugger:add("leave_attempt",string.format("instance=%s map=%s",tostring(core.get_instance_id()),tostring(core.get_map_id())),core.time())
  return Compat.leave()
 end,
 release=core.input.release_spirit,target=core.input.set_target,clear_target=core.input.clear_target,
 current_target=function(player) return player and player:get_target() end,
 interact=function(object)
  local player=core.object_manager.get_local_player()
  if player and type(player.is_mounted)=="function" and player:is_mounted() then
   if core.input and type(core.input.dismount)=="function" then core.input.dismount() end
   return false,"objective_dismounting"
  end
  return Interaction.dispatch(core,object)
 end,face=core.input.look_at,
 prepare=function(player,match,now)
  local p=Snapshot.position(player:get_position());if not p then return nil end
  return Preparation.choose(preparation,runtime_objects(),p,match,now,{healthstone=has_healthstone(now)})
 end,
 prepare_use=function(row,now)
  local player=core.object_manager.get_local_player()
  if player and type(player.is_mounted)=="function" and player:is_mounted() then
   if core.input and type(core.input.dismount)=="function" then core.input.dismount() end
   return false,"preparation_dismounting"
  end
  local ok,reason=Interaction.dispatch(core,row.object)
  if ok then Preparation.used(preparation,row,now);readiness:observe("preparation",true) end
  return ok,reason
 end,
 powerup=function(player,snapshot,now)
  return Powerups.choose(powerups,runtime_objects(),player,snapshot.player_position,snapshot.match_id,now,
   snapshot.player_role,snapshot.travel_distance)
 end,
 forever_recovery=function(player,snapshot,now)
  if not Client:is_forever() then return nil end
  return ForeverRecovery.choose(snapshot)
 end,
 use_forever_recovery=function(row,now)
  local input=core.input or {}
  if type(input.use_item)~="function" or type(row)~="table" or not tonumber(row.item_id) then return false end
  local ok,accepted=pcall(input.use_item,row.item_id)
  if ok and accepted==true then
   debugger:add("forever_recovery",tostring(row.kind or "item")..":"..tostring(row.item_id),now);return true
  end
  return false
 end,
 prepare_skip=function(row,now)
  Preparation.used(preparation,row,now)
 end,
 mount_service=function(player,now)
  local handled,state=mount_vendor:tick(player,now)
  if state then mount_detail(state,now) end
  if state=="repairing_from_packmaster" then readiness:observe("repair",true) end
  return handled,state
 end,
 recover_mounted=function(position,reason,now)
  local player=core.object_manager.get_local_player()
  if not player then return false end
  local recovered=mount_recovery:recover(player,position,now)
  if recovered then mount_settle=nil;mount_detail("dismount_recovery:"..tostring(reason),now) end
  return recovered
 end,
 ensure_on_foot=function(player,reason,now)
  if type(player.is_mounted)~="function" or not player:is_mounted() then return false end
  local input=core.input or {}
  if type(input.dismount)~="function" then return false end
  navigation:stop()
  local ok,result=pcall(input.dismount)
  if not ok or result==false then return false end
  mount_settle=nil;next_mount=math.max(next_mount or 0,now+3)
  if tostring(reason):find("narrow_corridor",1,true) then
   mount_recovery:note_forced_on_foot(Snapshot.position(player:get_position()),now,30,15)
  end
  mount_detail("route_dismount:"..tostring(reason),now)
  return true
 end,
 try_mount=function(player,now,distance)
  local position=Snapshot.position(player:get_position())
  if type(player.is_mounted)~="function" then mount_detail("skipped:is_mounted_api_unavailable",now);return false end
  if player:is_mounted() then
   mount_settle=nil;mount_pending_until=nil;mount_recovery:note_mounted(now);mount_detail("mounted",now);return false
  end
  -- core.input.mount is a fire-and-forget request and returns nil.  Keep
  -- navigation stopped while the game completes the mount cast; resuming the
  -- route on the next update interrupts the cast and then hides the failure
  -- behind the normal mount cooldown.
  if mount_pending_until then
   navigation:stop()
   if now<mount_pending_until then mount_detail("awaiting_mount_confirmation",now);return true end
   mount_pending_until=nil;next_mount=now+1
   mount_detail("failed:mount_not_confirmed",now);return false
  end
  local allowed,mount_reason=mount_recovery:mount_allowed(position,now,distance)
  if not allowed then mount_settle=nil;mount_detail("skipped:"..mount_reason,now);return false end
  if type(player.is_in_combat)~="function" then mount_settle=nil;mount_detail("skipped:combat_api_unavailable",now);return false end
  if player:is_in_combat() then mount_settle=nil;mount_detail("skipped:in_combat",now);return false end
  if type(player.is_outdoors)=="function" and not player:is_outdoors() then mount_settle=nil;mount_detail("skipped:indoors",now);return false end
  local book,input=core.spell_book or {},core.input or {}
  if type(book.get_mount_count)~="function" or type(book.get_mount_info)~="function" or type(input.mount)~="function" then
   mount_detail("skipped:mount_api_unavailable",now);return false
  end
  if mount_settle then
   local moving=type(player.is_moving)=="function" and player:is_moving()
   navigation:stop()
   if now<mount_settle.ready or moving then
    if now-mount_settle.started<=3 then mount_detail("settling_before_mount",now);return true end
    mount_settle=nil;next_mount=now+3;mount_detail("failed:movement_did_not_settle",now);return false
   end
   local job=mount_settle;mount_settle=nil
   local ok,result=pcall(input.mount,job.index)
   if ok and result~=false then
    mount_pending_until=now+2.75;next_mount=now+10
    mount_detail("dispatched:index="..tostring(job.index),now);return true
   end
   next_mount=now+1
   mount_detail("failed:dispatch:index="..tostring(job.index),now);return false
  end
  if now<next_mount then mount_detail("cooldown",now);return false end
  local index,reason=MountSelection.select(book)
  if index then
   navigation:stop()
   mount_settle={index=index,started=now,ready=now+0.5}
   mount_detail("selected:Grizzly Hills Packmaster:index="..tostring(index),now);return true
  end
  next_mount=now+30;mount_detail("skipped:"..tostring(reason),now);return false
 end,
 log=function(state)
  local row=string.format("[%0.1f] %s",core.time(),state)
  log_rows[#log_rows+1]=row;if #log_rows>5000 then table.remove(log_rows,1) end
  debugger:add("state",state,core.time())
  core.log("[Battleground] "..state)
 end,
 route_memory_event=function(kind,leg,data)
  local detail=string.format("leg=%s successes=%d failures=%d",tostring(leg),tonumber(data and data.successes) or 0,tonumber(data and data.failures) or 0)
  debugger:add(kind,detail,core.time())
  if (kind=="route_leg_proven" or kind=="route_leg_passed") and match_metrics and type(match_metrics.note_route_leg)=="function" then
   local active=false;local mounted=false;pcall(function() active=api.in_battleground()==true;local player=api.player();mounted=player and type(player.is_mounted)=="function" and player:is_mounted()==true end)
   match_metrics:note_route_leg(active,leg,mounted)
   if active then
    if mounted then readiness:observe("mounted_navigation",true) end
   end
  end
  if kind=="objective_interaction_dispatched" and match_metrics and type(match_metrics.note_objective_attempt)=="function" then
   local active=false;pcall(function() active=api.in_battleground()==true end);match_metrics:note_objective_attempt(active,leg)
  end
  route_store:event(kind,leg,data)
 end,
 objective_provider_ready=function()
  local profile=detected_profile()
  return type(provider)=="function" or Builtin.supports(profile)
 end,
 player_role=function(player) return detected_role(player) end,
 player_damage_style=function(player) return detected_damage_style(player) end,
 player_level_policy=function(player,role_name,style) return detected_level_policy(player,role_name,style) end,
 transport_transition=function(player,snapshot,now)
  local position=Snapshot.position(player and player:get_position())
  local seething=snapshot and snapshot.rule_profile=="seething"
  if not seething or not position then
   if seething_launch_active then
    local input=core.input or {}
    if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
    seething_launch_active=false;next_seething_jump=0;seething_landing=nil;seething_ground_targeted=false;seething_progress_position=nil;seething_progress_at=0
   end
   return false
  end
  -- Seething Shore starts on faction airships above Sentinel's ground mesh.
  -- Walk and jump toward the observed landing edge, then let Sentinel resume
  -- only after the character has descended to ground altitude.
  local input=core.input or {};local n=nav()
  if not seething_launch_active then
   if position.z<80 then return false end
   navigation:stop();seething_launch_active=true
   seething_landing=position.x>1400 and {x=1441.1,y=2700.2,z=9.8} or {x=1243.2,y=2721.5,z=11.9}
   seething_progress_position={x=position.x,y=position.y,z=position.z};seething_progress_at=now
  end
  if position.z<80 and not seething_ground_targeted then
   local entries={{x=1243.2,y=2721.5,z=11.9},{x=1441.1,y=2700.2,z=9.8},{x=1343.7,y=2919.9,z=33.1}}
   local best,best_distance
   for _,entry in ipairs(entries) do
    local d=(position.x-entry.x)^2+(position.y-entry.y)^2
    if not best_distance or d<best_distance then best,best_distance=entry,d end
   end
   seething_landing=best;seething_ground_targeted=true
   seething_progress_position={x=position.x,y=position.y,z=position.z};seething_progress_at=now
  end
  local landing=seething_landing
  local falling_ok,falling=pcall(function() return type(player.is_falling)=="function" and player:is_falling() end)
  local planar=math.sqrt((position.x-landing.x)^2+(position.y-landing.y)^2)
  -- Do not hand an arbitrary beach landing to Sentinel. The launch remains in
  -- local steering until the player reaches a known ground-mesh entry point.
  if position.z<55 and falling_ok and not falling and planar<=14 then
   if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
   seething_launch_active=false;next_seething_jump=0;seething_landing=nil;seething_ground_targeted=false;seething_progress_position=nil;seething_progress_at=0
   return false
  end
  if type(input.look_at)=="function" then input.look_at(vec3(landing.x,landing.y,landing.z)) end
  if type(input.move_forward_start)=="function" then input.move_forward_start() end
  if position.z<80 then
   local moved=seething_progress_position and math.sqrt((position.x-seething_progress_position.x)^2+(position.y-seething_progress_position.y)^2) or 0
   if moved>=2 then
    seething_progress_position={x=position.x,y=position.y,z=position.z};seething_progress_at=now
   elseif now-(seething_progress_at or now)>=4 then
    if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
    if type(input.jump)=="function" then input.jump() end
    if type(input.move_forward_start)=="function" then input.move_forward_start() end
    seething_progress_at=now
    return true,"seething_landing_recovery"
   end
  end
  if position.z>=80 and (not falling_ok or not falling) and now>=next_seething_jump and type(input.jump)=="function" then
   input.jump();next_seething_jump=now+0.75
  end
  if position.z<80 then return true,"seething_reaching_landing" end
  return true,(falling_ok and falling) and "seething_descending" or "seething_leaving_airship"
 end,
 movement_hold=function(player,snapshot)
  local impairment=MovementImpairment.reason(player)
  if impairment then
   if crowd_control_paused or navigation:pause("bg_crowd_control") then
    crowd_control_paused=true
    return true,"crowd_controlled_"..impairment,true
   end
   navigation:stop();return true,"crowd_controlled_"..impairment
  end
  if crowd_control_paused then navigation:resume("bg_crowd_control");crowd_control_paused=false end
  local falling_ok,falling=pcall(function() return type(player.is_falling)=="function" and player:is_falling() end)
  if falling_ok and falling then navigation:stop();return true,"waiting_for_stable_ground" end
  if snapshot and snapshot.player_role=="healer" then
   local reason=CastHold.reason(player,type(core.game_time)=="function" and core.game_time() or nil)
   if reason then navigation:stop();return true,"healer_"..reason.."_hold" end
  end
  return false
 end,
 navigation_ready=navigation_ready,
 navigation_provider=function() return sentinel_provider_kind end,
 quarantine_navigation_provider=function(name,until_at)
  name=tostring(name or "unknown")
  local value=tonumber(until_at) and until_at>0 and until_at or nil
  navigation_quarantine[navigation_identity(name)]=value
 end,
 navigation_state=function() return nav_telemetry:read(nav(),"get_state") end,
 navigation_full_state=function() return nav_telemetry:read(nav(),"get_full_state") end,
 navigation_path=function() return nav_telemetry:read(nav(),"get_current_path") end,
 navigation_path_index=function() return nav_telemetry:read(nav(),"get_path_index") end,
 navigation_corridor_widths=function() return nav_telemetry:read(nav(),"get_corridor_widths") end,
 navigation_progress=function() return nav_telemetry:read(nav(),"get_progress") end,
 navigation_destination=function() return nav_telemetry:read(nav(),"get_destination") end,
 replan=function(reason)
  local n=nav();if not n then return false end
  local found,method=pcall(function() return n.replan end)
  if not found or type(method)~="function" then return false end
  local ok,result=pcall(method,n,reason);return ok and result~=false
 end,
 escape_direction=function(direction)
  local n=nav();local read,movement=pcall(function() return n and n.movement end)
  movement=read and movement or nil
  -- A directional recovery is a manual driver. Stop the current path before
  -- starting it so provider steering cannot cancel or fight the strafe.
  if direction~=nil then navigation:stop() end
  if movement and type(movement.strafe)=="function" then
   local ok,result=pcall(movement.strafe,movement,direction)
   if ok and result~=false then return true end
  end
  -- ArthasNav builds do not all expose SimpleMovement on the navigator. Use
  -- the stable core input strafe controls as the bounded recovery fallback.
  local input=core.input or {}
  if type(input.strafe_left_stop)=="function" then pcall(input.strafe_left_stop) end
  if type(input.strafe_right_stop)=="function" then pcall(input.strafe_right_stop) end
  if direction==nil then return true end
  local start=direction=="left" and input.strafe_left_start or
   direction=="right" and input.strafe_right_start or nil
  if type(start)~="function" then return false end
  local ok,result=pcall(start)
  return ok and result~=false
 end,
 obstacle_escape_side=function(position,goal)
  local graphics=core.graphics
  if type(graphics)~="table" or type(graphics.trace_line)~="function" then return nil end
  local side=ObstacleProbe.escape_side(function(a,b,flags) return graphics.trace_line(a,b,flags) end,
   position,goal,vec3)
  return side
 end,
 recovery_jump=function()
  local input=core.input or {}
  if type(input.jump)~="function" then return false end
  local ok=pcall(input.jump);return ok
 end,
 reverse_rebound=function(point)
  local input=core.input or {}
  if not point then
   if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
   return true
  end
  if type(input.look_at)~="function" or type(input.move_forward_start)~="function" then return false end
  navigation:stop()
  input.look_at(vec3(point.x,point.y,point.z));input.move_forward_start();return true
 end,
 recovery_step=function(point)
  local input=core.input or {}
  if not point then
   if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
   return true
  end
  if type(input.look_at)~="function" or type(input.move_forward_start)~="function" then return false end
  navigation:stop();input.look_at(vec3(point.x,point.y,point.z));input.move_forward_start();return true
 end,
 stop=function()
  navigation:stop()
  if seething_launch_active then
   local input=core.input or {};if type(input.move_forward_stop)=="function" then input.move_forward_stop() end
   seething_launch_active=false;next_seething_jump=0;seething_landing=nil;seething_ground_targeted=false;seething_progress_position=nil;seething_progress_at=0
  end
 end,
 move=function(p,cb) navigation:move(p,cb,false) end,
 move_combat=function(p,cb) navigation:move(p,cb,false,true) end,
 move_direct=function(p,cb) navigation:move(p,cb,true) end,
 publish=function(plan,snapshot)
  local now=core.time();context=Safety.context(plan,snapshot,now);nav_faction:sync(snapshot,now)
 end,
 route_for=function(snapshot,plan,force_graph,avoid)
  local opening=Routes.opening_recovery(snapshot.rule_profile,snapshot.player_position,Client.family)
  if opening then return opening end
  local recovery=Routes.elevation_recovery(snapshot.rule_profile,snapshot.player_position,Client.family)
  if recovery then return recovery end
  if snapshot.rule_profile=="darkspear_islands" and Client:is_forever() then
   local route=Darkspear.route(core,snapshot.player_position,plan.position)
   if route then return route end
  end
  return Routes.route(snapshot.rule_profile,snapshot.player_position,plan.position,force_graph,snapshot.player_role,snapshot.damage_style,Client.family,avoid)
 end,
 travel_distance=function(snapshot,point)
  return Routes.travel_distance(snapshot.rule_profile,snapshot.player_position,point,Client.family)
 end,
 objective_action_ready=function(name) return objective_actions and type(objective_actions[name])=="function" end,
 objective_action=function(plan,snapshot)
  local name=tostring(plan.required_action or "unknown")
  local ok,result=xpcall(function() return objective_actions[plan.required_action](plan,snapshot) end,Debug.trace)
  if not ok then
   readiness.objective_action_errors=readiness.objective_action_errors or {}
   local last=tonumber(readiness.objective_action_errors[name]) or -math.huge
   local now=core.time()
   if now<last or now-last>=30 then
    readiness.objective_action_errors[name]=now
    debugger:add("objective_action_error",name..":"..tostring(result),now)
   end
   return false,"objective_action_error:"..name
  end
  if result==true then
   readiness:observe(name,true)
   local active=false;pcall(function() active=api.in_battleground()==true end);match_metrics:note_objective_attempt(active,tostring(plan.kind)..":"..tostring(plan.id or ""))
   debugger:add("objective_action_confirmed",name,core.time())
  end
  return result
 end,
 snapshot=function(player,match)
  local profile=detected_profile()
  if not provider and not Builtin.supports(profile) then return nil,"objective_provider_required" end
  if reader_match~=match then Reader:reset();reader_match=match end
  local function read_snapshot()
  local ok,s=xpcall(function()
   if provider then return provider(player,match) end
   local p
   pcall(function() if player and type(player.get_position)=="function" then p=Snapshot.position(player:get_position()) end end)
   local raw=core.game_ui.get_battlefield_arena_faction and core.game_ui.get_battlefield_arena_faction()
   local detected_team=faction and faction:observe(profile,p,raw,Compat.match_state()) or raw
   return Builtin.snapshot(core,profile,player,match,core.time(),nil,detected_team,runtime_objects())
  end,Debug.trace)
  if not ok then return nil,"objective_provider_error:"..tostring(s) end
  if type(s)~="table" then return nil,"objective_provider_invalid" end
  if provider and s.objective_source==nil then
   s.objective_source=s.formation_fallback and "team_formation_fallback" or "live_objective_reader"
  end
  local actual_team=faction and faction:team() or nil
  if actual_team~=0 and actual_team~=1 then actual_team=core.game_ui.get_battlefield_arena_faction and core.game_ui.get_battlefield_arena_faction() end
  local team_ok,team_reason=Safety.validate_team(s,actual_team)
  if not team_ok then return nil,team_reason end
  local normalized,validation_error=Snapshot.normalize(s)
  if not normalized then return nil,validation_error end
  s=normalized
  -- Health is read locally after provider normalization so an external
  -- objective feed cannot spoof survivability policy. Missing bindings simply
  -- leave the planner's existing behavior unchanged.
  local health_ok,health,max_health=pcall(function()
   if not player or type(player.get_health)~="function" or type(player.get_max_health)~="function" then return nil,nil end
   return player:get_health(),player:get_max_health()
  end)
  if health_ok and type(health)=="number" and type(max_health)=="number" and
   max_health>0 and health>=0 and health<=max_health then s.player_health_ratio=health/max_health end
  local mana_ok,mana,max_mana=pcall(function()
   if not player or type(player.get_power)~="function" or type(player.get_max_power)~="function" then return nil,nil end
   return player:get_power(0),player:get_max_power(0)
  end)
  if mana_ok and type(mana)=="number" and type(max_mana)=="number" and
   max_mana>0 and mana>=0 and mana<=max_mana then s.player_mana_ratio=mana/max_mana end
  s=prediction:update(s,core.time())
  s=flow_prediction:update(s)
  if s.valid~=true or s.match_id~=match or type(s.observed_at)~="number" or
   s.observed_at~=s.observed_at or s.observed_at>core.time() or core.time()-s.observed_at>2 then
   return nil,"objective_snapshot_not_fresh"
  end
  return Rules.resolve(s)
  end
  local snapshot,reason=Reader:read(read_snapshot,core.time())
  if not snapshot then return nil,reason end
  return callouts and callouts:apply(snapshot,profile,core.time()) or snapshot
 end,
 select_target=function(player,plan,snapshot)
  local best,score
  local player_position=Snapshot.position(player:get_position())
  if not player_position then return nil end
  -- One clock sample owns the whole scan. Native clock calls inside the enemy
  -- loop used to scale with target count and could give the role/TTD caches
  -- slightly different ages within one decision.
  local combat_now=core.time()
  local player_health_ratio
  local player_health_ok,player_health,player_max_health=pcall(function()
   if type(player.get_health)~="function" or type(player.get_max_health)~="function" then return nil,nil end
   return player:get_health(),player:get_max_health()
  end)
  if player_health_ok and type(player_health)=="number" and type(player_max_health)=="number" and
   player_max_health>0 and player_health>=0 and player_health<=player_max_health then
   player_health_ratio=player_health/player_max_health
  end
  if player_health_ratio then
   if player_health_ratio<=0.25 then critical_health_pursuit=true
   elseif player_health_ratio>=0.40 then critical_health_pursuit=false end
  else critical_health_pursuit=false end
  local visible
  if type(runtime_objects)=="function" then visible=runtime_objects()
  else
   local manager=core.object_manager or {}
   visible=type(manager.get_visible_objects)=="function" and manager.get_visible_objects() or {}
  end
  local current_target
  pcall(function() if type(player.get_target)=="function" then current_target=player:get_target() end end)
  local combat_observations={}
  local function observe_combatant(object,allow_unit)
   if not object then return nil end
   local row=combat_observations[object]
   if not row then
    row={object=object,valid=false};combat_observations[object]=row
    local ok=pcall(function()
     row.valid=object:is_valid() and true or false
     if not row.valid then return end
     row.player=object:is_player() and true or false
     row.dead=object:is_dead() and true or false
     row.ghost=object:is_ghost() and true or false
     row.attackable=player:can_attack(object) and true or false
     if type(object.get_guid)=="function" then
      local value=object:get_guid()
      if (type(value)=="string" or type(value)=="number") and tostring(value)~="" then row.guid=tostring(value) end
     end
     if row.player and not row.dead and not row.ghost then row.position=Snapshot.position(object:get_position()) end
    end)
    if not ok then row.valid=false end
   end
   if allow_unit and row.valid and not row.player and not row.unit_checked then
    row.unit_checked=true
    local ok,is_unit=pcall(function() return object:is_unit() end);row.unit=ok and is_unit==true
    if row.unit then
     local position_ok,value=pcall(function() return object:get_position() end)
     row.position=position_ok and Snapshot.position(value) or nil
    end
   end
   return row
  end
  -- Detect a real nearby skirmish rather than treating every visible enemy as
  -- a reason to abandon the objective. A friendly player must be close and
  -- actively targeting that enemy; this lets DPS/tanks help fights beside a
  -- base such as Farm without chasing unrelated players across the map.
  local assisted_targets={};local assisted_by_guid={};local nearby_friendlies={};local nearby_friendly_guids={}
  local friendly_carrier,friendly_carrier_guid
  local protected_carrier_position=snapshot.friendly_flag_carrier_position or snapshot.friendly_orb_carrier_position
  local enemy_target_by_guid={};local enemy_target_fallback={}
  local function observed_enemy_target(enemy)
   local observation=observe_combatant(enemy);local guid=observation and observation.guid
   if guid then
    local cached=enemy_target_by_guid[guid]
    if cached then return cached.value end
    local ok,value=pcall(function() return type(enemy.get_target)=="function" and enemy:get_target() or nil end)
    enemy_target_by_guid[guid]={value=ok and value or nil};return ok and value or nil
   end
   for _,entry in ipairs(enemy_target_fallback) do
    if Object.same(entry.enemy,enemy) then return entry.value end
   end
   local ok,value=pcall(function() return type(enemy.get_target)=="function" and enemy:get_target() or nil end)
   enemy_target_fallback[#enemy_target_fallback+1]={enemy=enemy,value=ok and value or nil}
   return ok and value or nil
  end
  local function add_assist(enemy,bonus)
   local observation=observe_combatant(enemy);local guid=observation and observation.guid
   if guid then assisted_by_guid[guid]=(assisted_by_guid[guid] or 0)+bonus;return end
   for _,entry in ipairs(assisted_targets) do
    if Object.same(entry.enemy,enemy) then entry.bonus=entry.bonus+bonus;return end
   end
   assisted_targets[#assisted_targets+1]={enemy=enemy,bonus=bonus}
  end
  for _,friendly in pairs(visible) do
   local observation=observe_combatant(friendly)
   pcall(function()
    if observation and observation.valid and observation.player and not observation.dead and
     not observation.ghost and not observation.attackable then
     local friendly_position=observation.position
     if friendly_position and Planner.distance(player_position,friendly_position)<=45 then
      nearby_friendlies[#nearby_friendlies+1]=friendly
      local friendly_guid=observation.guid
      if friendly_guid then nearby_friendly_guids[friendly_guid]=true end
      if protected_carrier_position and Planner.distance(friendly_position,protected_carrier_position)<=4 then
       friendly_carrier,friendly_carrier_guid=friendly,friendly_guid
      end
     end
     if friendly_position and Planner.distance(player_position,friendly_position)<=45 and type(friendly.get_target)=="function" then
      local enemy=friendly:get_target()
      if enemy and enemy:is_valid() and enemy:is_player() and not enemy:is_dead() and
       not enemy:is_ghost() and player:can_attack(enemy) then
       local enemy_position=Snapshot.position(enemy:get_position())
       if enemy_position and Planner.distance(player_position,enemy_position)<=55 and
        Planner.distance(friendly_position,enemy_position)<=45 then
        add_assist(enemy,250)
       end
      end
     end
    end
   end)
  end
  -- Casters and kiting players may have no target selected. Recognize the
  -- reverse relationship when an enemy is targeting a nearby teammate.
  for _,enemy in pairs(visible) do
   local observation=observe_combatant(enemy)
   pcall(function()
    if observation and observation.valid and observation.player and not observation.dead and not observation.ghost and
     observation.attackable and type(enemy.get_target)=="function" then
     local victim=observed_enemy_target(enemy)
     local enemy_position=observation.position
     if victim and enemy_position and Planner.distance(player_position,enemy_position)<=55 then
      local victim_guid=Object.guid(victim)
      if victim_guid and nearby_friendly_guids[victim_guid] then add_assist(enemy,350)
      elseif not victim_guid then
       -- Native objects without a stable GUID retain the safe identity fallback.
       for _,friendly in ipairs(nearby_friendlies) do
        if Object.same(victim,friendly) then add_assist(enemy,350);break end
       end
      end
     end
    end
   end)
  end
  local function teammate_is_fighting(o)
   local observation=observe_combatant(o);local guid=observation and observation.guid
   if guid then return assisted_by_guid[guid] end
   for _,entry in ipairs(assisted_targets) do if Object.same(o,entry.enemy) then return entry.bonus end end
   return nil
  end
  local function consider(o,priority,allow_npc)
   if not o then return end
   local ok,weight=pcall(function()
    local observation=observe_combatant(o,allow_npc)
    if not observation or not observation.valid or not (observation.player or allow_npc and observation.unit) or
     observation.dead or observation.ghost or not observation.attackable then return nil end
    local position=observation.position
    if not position then return nil end
    local dist=Planner.distance(player_position,position)
    local assist_bonus=observation.player and teammate_is_fighting(o)
    local team_fight=type(assist_bonus)=="number"
    local objective_pursuit=Object.same(o,plan.target)
    local current_pursuit=Object.same(o,current_target)
    -- Immediate threats can be fought even just outside an objective circle;
    -- a nearby teammate's active target may be assisted slightly farther out.
    -- Other enemies remain leashed to the active objective.
    if dist>(team_fight and 55 or 45) or
     (not team_fight and dist>15 and Planner.distance(plan.position,position)>(plan.engagement_radius or 35)) then return nil end
    -- Teammate assistance must not pull a defender away from the objective it
    -- is anchoring. Immediate self-defense stays available inside 15 yards,
    -- and a verified objective-owned target (carrier/assault target) bypasses
    -- the tether. Ranged roles inherit their wider engagement radius.
    local anchor_tether=math.max(25,(plan.engagement_radius or 35)+15)
    if plan.combat_anchor and not objective_pursuit and dist>15 and
     Planner.distance(plan.position,position)>anchor_tether then return nil end
    -- At critical health, keep fighting the current target and answer immediate
    -- threats, but do not begin a new distant chase. Verified objective-owned
    -- targets remain actionable so carriers and emergency assaults are not lost.
    if critical_health_pursuit and dist>15 and
     not objective_pursuit and not current_pursuit then return nil end
    local los_ok,has_los=pcall(core.graphics.is_line_of_sight,player,o)
    has_los=los_ok and has_los==true
    local pursuit=team_fight or objective_pursuit
    local eye_profile=snapshot.rule_profile=="eye_standard" or snapshot.rule_profile=="eye_blitz" or snapshot.rule_profile=="eye_blitz_legacy"
    -- A verified priority/assisted target may briefly disappear behind a
    -- pillar. Sentinel can route around it on meshed maps; raw EOTS steering
    -- cannot, and cross-layer or distant targets remain rejected.
    if not has_los and (not pursuit or eye_profile or dist>35 or math.abs(position.z-player_position.z)>8) then return nil end
    local target_weight=priority-dist+(assist_bonus or 0)
    if not has_los then target_weight=target_weight-100 end
    if observation.player then
     local enemy_role=target_forecast.role_cache:get(observation.guid,combat_now,function()
      return Theme.resolve(o:get_class(),o:get_specialization_id()).role
     end)
     -- Role tiers deliberately dominate distance and objective preference.
     -- Within a tier, keep the current target to let the rotation finish it.
     local role_priority={healer=3000,damage=2000,unknown=1500,tank=1000}
     target_weight=target_weight+(role_priority[enemy_role] or role_priority.unknown)
     if current_pursuit then target_weight=target_weight+200 end
     local observed_target=observed_enemy_target(o)
     if observed_target and Object.same(observed_target,player) then target_weight=target_weight+300 end
     local health_ok,health,max_health=pcall(function()
      if type(o.get_health)~="function" or type(o.get_max_health)~="function" then return nil,nil end
      return o:get_health(),o:get_max_health()
     end)
     if health_ok and type(health)=="number" and type(max_health)=="number" and max_health>0 and
      health>=0 and health<=max_health then
      target_weight=target_weight+(1-health/max_health)*150
      local hp=health/max_health*100;local guid=observation.guid
      target_forecast:observe(guid,combat_now,hp)
      local forecast=target_forecast:get(guid,combat_now)
      -- Finish a confirmed collapsing target without overcoming the healer,
      -- damage, and tank role tiers that define the battleground policy.
      if forecast.confident and forecast.ttd and forecast.ttd<=8 then
       target_weight=target_weight+math.min(180,(8-forecast.ttd)*30)
      end
     end
     if observed_target then
      local friendly_ok,is_friendly=pcall(function()
       return observed_target:is_valid() and observed_target:is_player() and not player:can_attack(observed_target)
      end)
      if friendly_ok and is_friendly and Theme.detect(observed_target).role=="healer" then
       -- Tanks peel attackers off friendly healers before chasing an ordinary
       -- kill target. DPS keeps the established enemy-healer-first order.
       -- Urgent objective targets still carry the separate 5000-point policy
       -- bonus and therefore remain authoritative for every role.
       target_weight=target_weight+(snapshot.player_role=="tank" and 1200 or 100)
      end
      local victim_guid=Object.guid(observed_target)
      local attacking_carrier=friendly_carrier and
       (friendly_carrier_guid and victim_guid==friendly_carrier_guid or
        not friendly_carrier_guid and Object.same(observed_target,friendly_carrier))
      if attacking_carrier then
       -- Bodyguard tanks peel directly from a verified friendly flag or orb carrier.
       -- DPS receives only a modest focus-fire hint and therefore retains its
       -- enemy-healer kill order. Objective-owned targets still score higher.
       target_weight=target_weight+(snapshot.player_role=="tank" and 1400 or 150)
      end
     end
    end
    return target_weight
   end)
   if ok and weight and (not score or weight>score) then best,score=o,weight end
  end
  -- A live objective target (especially an enemy flag carrier) must survive
  -- the generic healer-first ranking. Ordinary fights still use the role
  -- order below, while urgent objective defense/interception owns targeting.
  local objective_target=plan.kind=="intercept" or plan.kind=="defend" or plan.kind=="recapture"
  consider(plan.target,objective_target and 5000 or 100,plan.allow_npc)
  if Rules.npc_opponents(snapshot) then
   for _,enemy in ipairs(snapshot.enemies or {}) do
    if enemy.is_battleground_opponent==true and enemy.attackable==true and enemy.dead~=true then
     consider(enemy.target,40,true)
    end
   end
  end
  for _,o in pairs(visible) do
   consider(o,20,false)
  end
  target_forecast:prune(combat_now)
  return best
 end
}
local controller=Controller.new(api,{
 enabled=function() return enabled:get_state() end,
 queue_mode=function() return selected_mode().key end,
 queue_id=effective_queue_id,
 role_flags=function() local _,flags=detected_role(api.player());return flags end,
 combat_range=function() return range:get() end,route_memory=route_store.memory,
 route_scope=function() Client:refresh_if_due(core.time(),30);return Client.route_scope end
})
local event_error_next=0
if type(core.register_on_game_event_callback)=="function" then
 core.register_on_game_event_callback(function(event,args)
  if not instance_current() then return end
  local event_now=core.time()
  local event_ok,event_err=xpcall(function()
  -- PLAYER_LEAVING_WORLD fires during battleground and reload transitions.
  -- A forced data-file rewrite there stalls the game thread at the worst time.
  if event=="PLAYER_LOGOUT" then
   if persistent_log then persistent_log:flush(core.time(),true) end
   if readiness and readiness.loaded then readiness:flush() end
  end
  -- World-transition events can arrive after the native player object has
  -- already gone stale. Keep that boundary out of the event dispatcher.
  local player,active
  local player_ok=pcall(function()
   player=api.player()
   active=player~=nil and player:is_valid()==true and api.in_battleground()==true
  end)
  if not player_ok or not active then return end
  local profile=detected_profile();local role_name=detected_role(player)
  local row=callouts:ingest(event,args,profile,role_name,core.time())
  if row then
   local detail=row.cleared and ("objective="..tostring(row.id)) or
    string.format("objective=%s enemies=%s sender=%s",tostring(row.id),tostring(row.enemy_count or "unknown"),tostring(row.sender or "unknown"))
   debugger:add(row.cleared and "callout_cleared" or "callout_received",detail,core.time())
  end
  end,Debug.trace)
  if not event_ok and event_now>=event_error_next then
   event_error_next=event_now+5
   debugger:add("event_callback_error",event_err,event_now)
  end
 end)
end
local function safe_method(object,methods)
 for _,method in ipairs(methods) do
  local ok,value=pcall(function() return type(object[method])=="function" and object[method](object) end)
  if ok and value~=nil and value~=false then return value end
 end
end
local function collect_object_census(now)
 if now<next_census or not api.in_battleground() or not context or context.objective_source~="team_formation_fallback" then return end
 next_census=now+10
 local profile=detected_profile() or "unknown"
 local objects=runtime_objects()
 local inspected=0
 for _,object in pairs(type(objects)=="table" and objects or {}) do
  inspected=inspected+1;if inspected>250 then break end
  local ok,valid,is_player,p=pcall(function()
   return object:is_valid(),object:is_player(),Snapshot.position(object:get_position())
  end)
  if ok and valid and not is_player and p then
   local entry=tonumber(safe_method(object,{"get_npc_id","get_entry_id","get_entry"})) or 0
   local is_unit=safe_method(object,{"is_unit"})==true
   local gx,gy,gz=math.floor(p.x/10),math.floor(p.y/10),math.floor(p.z/10)
   local key=entry>0 and table.concat({profile,entry,is_unit and "unit" or "object",
    moving_census_entries[entry] and gx or "",moving_census_entries[entry] and gy or "",moving_census_entries[entry] and gz or ""},":") or nil
   if key and not census_seen[key] and census_count<500 then
    census_seen[key]=true;census_count=census_count+1
    local name=tostring(safe_method(object,{"get_name"}) or "-"):gsub("[%c]"," "):sub(1,80)
    debugger:add("object_census",string.format("profile=%s entry=%d type=%s name=%s position=%.1f,%.1f,%.1f",
     profile,entry,is_unit and "unit" or "object",name,p.x,p.y,p.z),now)
   elseif census_count>=500 and not census_seen.__limit then
    census_seen.__limit=true;debugger:add("object_census","unique-object limit reached",now)
   end
  end
 end
end
local function collect_route_sample(now)
 if now<next_route_sample or not api.in_battleground() or not controller.plan then return end
 next_route_sample=now+3
 local player=api.player();local ok,p=pcall(function() return player and Snapshot.position(player:get_position()) end)
 if not ok or not p then return end
 local profile=detected_profile() or "unknown";local plan=controller.plan;local destination=controller.destination or plan.position
 local gx,gy,gz=math.floor(p.x/10),math.floor(p.y/10),math.floor(p.z/10)
 local nav=tostring(api.navigation_full_state() or api.navigation_state() or "unknown")
 local key=table.concat({profile,tostring(plan.kind),gx,gy,gz,nav},":")
 if route_seen[key] then return end;route_seen[key]=true
 local source=type(plan.route)=="table" and tostring(plan.route.source or "route") or "arthasnav"
 local dp=Snapshot.position(destination);local destination_text=dp and string.format("%.1f,%.1f,%.1f",dp.x,dp.y,dp.z) or "None"
 debugger:add("route_sample",string.format("profile=%s role=%s objective=%s source=%s steering=%s leg=%s/%s nav=%s position=%.1f,%.1f,%.1f destination=%s",
  profile,tostring(context and context.player_role or "unknown"),tostring(plan.kind),source,
  type(plan.route)=="table" and plan.route.direct==true and "local" or "arthasnav",
  tostring(controller.route_index or 0),tostring(type(plan.route)=="table" and #plan.route or 0),nav,p.x,p.y,p.z,destination_text),now)
end
local function inspect(fn)
 local ok,value=pcall(fn);if ok then return value end;return "Unavailable"
end
local function render_time()
 local ok,value=pcall(core.time)
 if ok and type(value)=="number" and value==value and math.abs(value)<math.huge then return value end
 return 0
end
local function render_capabilities(now)
 return Renderer:read("client APIs",now,function() return Compat.capabilities(selected_mode().key) end,
  {version="Unavailable",exact_version="Unavailable",missing={"client_state_unavailable"},ready=false})
end
local function display_queue_id(now)
 return Renderer:read("queue catalog",now,effective_queue_id,0)
end
local function position_label(value)
 local p=Snapshot.position(value)
 return p and string.format("%.1f, %.1f, %.1f",p.x,p.y,p.z) or "None"
end
local function readiness_report(now)
 local base=readiness:report(now);local maps=live_acceptance:report(Client.route_scope,Client.family)
 base.base_passed=base.passed;base.base_total=base.total;base.map_passed=maps.passed;base.map_total=maps.total
 base.passed=base.passed+maps.passed;base.total=base.total+maps.total
 base.live=math.floor(base.passed/base.total*100+0.5);base.maps=maps
 return base
end
local role_guidelines={
 healer="follow the injured friendly cluster or flag carrier; hold at healing range; avoid solo objectives",
 tank="lead durable objective work; carry flags or orbs; defend threatened and unguarded positions",
 damage="respond to calls; intercept carriers; capture objectives; pressure enemy healers"
}
local function debug_rows()
 local now=render_time();local recovery=Health:report(now);local reader=Reader:report(now);local rendering=Renderer:report(now)
 local player=inspect(api.player);local cap=render_capabilities(now)
 local detected,detected_flags=detected_role(player)
 local detected_style,style_source=detected_damage_style(player)
 local level_policy=detected_level_policy(player,detected,detected_style)
 local profile=inspect(detected_profile);if type(profile)~="string" then profile=nil end
 local active_callout=profile and callouts:active(profile,detected,now)
 local last=controller.observations or {};local queues=last.queues or {}
 local next_waypoint=controller.locked_route and controller.locked_route[controller.route_index or 0]
 local player_position=inspect(function() return player:get_position() end)
 local waypoint_distance=Snapshot.position(player_position) and Snapshot.position(next_waypoint) and Planner.distance(Snapshot.position(player_position),Snapshot.position(next_waypoint)) or nil
 local route_source=controller.plan and type(controller.plan.route)=="table" and tostring(controller.plan.route.source or "custom") or "ArthasNav generated"
 local route_steering=controller.plan and type(controller.plan.route)=="table" and controller.plan.route.direct==true and "local direct" or "ArthasNav"
 local certificate=readiness_report(now)
 local active_nav=nav()
 local acceptance=certificate.maps
 local missing_preview={}
 for i=1,math.min(4,#(acceptance.missing or {})) do missing_preview[#missing_preview+1]=acceptance.missing[i] end
 if #(acceptance.missing or {})>#missing_preview then missing_preview[#missing_preview+1]="+"..tostring(#acceptance.missing-#missing_preview).." more" end
 local rows={
  {"Controller",controller.state},{"Enabled",tostring(enabled:get_state())},
  {"Match / phase",tostring(controller.match or "None").." / "..tostring(last.phase or "Unknown")},
  {"Queues observed",(function() local out={};for i=1,last.queue_count or 3 do out[i]=tostring(queues[i] or "Unknown") end;return #out>0 and table.concat(out," / ") or "None" end)()},
  {"Navigation",inspect(api.navigation_full_state) or inspect(api.navigation_state)},
  {"Navigation provider",sentinel_provider_kind.." / client="..tostring(active_nav~=nil).." / arthas="..tostring(type(rawget(_G,"ArthasNav"))=="table").." / guarded="..tostring(type(rawget(_G,"ArthasNavEnhancements"))=="table")},
  {"Arthas engine",arthas_engine_state..(arthas_engine_error and (" / "..arthas_engine_error) or "")},
  {"Arthas contract",arthas_contract_state.." / protocol 3 / API 1 / map schema 1"},
  {"Navigation exports",navigation_discovery},
  {"Navigation policy","ArthasNav -> verified short local fallback; Sentinel disabled"},
  {"Navigation recovery",nav_health_state..(nav_health_pending and " / pending" or "")},
  {"Destination",position_label(controller.destination or controller.recovery.destination)},
  {"Player position",position_label(player_position)},
  {"Objective / data age",tostring(controller.plan and controller.plan.kind or "None").." / "..(context and context.observed_at and string.format("%.1fs",now-context.observed_at) or "Unknown")},
  {"Objective source",context and context.objective_source or "None"},
  {"Route / waypoint",tostring(controller.route_key or "None").." / "..tostring(controller.route_index or 0).." of "..tostring(controller.locked_route and #controller.locked_route or 0)},
  {"Route source / steering",route_source.." / "..route_steering},
  {"Next waypoint distance",waypoint_distance and string.format("%.1f yards",waypoint_distance) or "None"},
  {"Match activity",match_metrics:report()},
  {"Readiness certificate",string.format("software %d%% / live %d%% (%d/%d)",certificate.software,certificate.live,certificate.passed,certificate.total)},
  {"Battleground validation",string.format("%s maps %d/%d / partial %d",acceptance.family,acceptance.passed,acceptance.total,acceptance.partial)},
  {"Validation still needed",#missing_preview>0 and table.concat(missing_preview,"; ") or "None"},
  {"Validation storage",acceptance.loaded and (acceptance.error and ("error: "..acceptance.error) or (acceptance.dirty and "pending save" or "ready")) or "waiting outside battleground"},
  {"Live proof",string.format("ArthasNav=%s Horde=%s Alliance=%s objectives=%s preparation=%s mounted=%s vehicle=%s siege=%s repair=%s clean=%d overnight=%s",
   tostring(certificate.sentinel),tostring(certificate.horde),tostring(certificate.alliance),tostring(certificate.live_objectives),
   tostring(certificate.preparation),tostring(certificate.mounted_navigation),tostring(certificate.vehicle),tostring(certificate.siege),tostring(certificate.repair),certificate.consecutive_clean,tostring(certificate.overnight))},
  {"Player callout",active_callout and (tostring(active_callout.id).." from "..tostring(active_callout.sender or "unknown")) or "None"},
  {"Detected role / policy",tostring(detected).." / "..tostring(role_guidelines[detected] or "general objective support")},
  {"Character level policy",tostring(level_policy.level or "Unknown").." / "..tostring(level_policy.band).." / "..tostring(level_policy.rotation_profile)},
  {"Rotation directive",tostring(level_policy.rotation_directive or "Live spellbook checks required")},
  {"Battleground faction",(function() local f=faction:report();return (f.team==0 and "Horde" or f.team==1 and "Alliance" or "Unknown").." / "..f.source..(f.conflict and " / API conflict corrected" or "") end)()},
  {"Damage style",tostring(detected_style).." / "..tostring(style_source)},
  {"Runtime recovery",recovery.failures.." errors / retry in "..string.format("%.1fs",recovery.retry_in)},
  {"Objective reader",reader.state.." / retry in "..string.format("%.1fs",reader.retry_in)},
  {"APIs / local link",(type(cap)=="table" and (#cap.missing>0 and table.concat(cap.missing,", ") or "Ready") or "Unknown").." / "..LocalLink.state},
  {"Client build",tostring(cap.game_patch or "Unknown").." / "..tostring(cap.game_build or 0).." / interface "..tostring(cap.interface or 0)},
  {"Client policy / route scope",Client.family.." / "..Client.route_scope},
  {"TrinityCore catalog","random="..tostring(TrinityForever.battlemaster.random).." / modern="..
   tostring(TrinityForever.battlemaster.random_modern).." / epic="..tostring(TrinityForever.battlemaster.random_epic)..
   " / live catalog remains authoritative"},
  {"Forever readiness",Client:is_forever() and "4 BG catalog; battlemaster/entrance queue; deterministic Darkspear fallback; Brawl/Epic unavailable" or "Not running Forever"},
  {"Forever mmap reference",Client:is_forever() and ForeverMMaps.report(detected_profile()) or "Not running Forever"},
  {"Vehicle / siege handlers",(objective_actions and type(objective_actions.vehicle)=="function" and "vehicle ready" or "vehicle unavailable").." / "..
   (objective_actions and type(objective_actions.siege_gate)=="function" and "siege ready" or "siege unavailable")},
  {"Plugin initialization",plugin_init_ms and string.format("%.1fms",plugin_init_ms) or "measuring"},
  {"Runtime performance",performance:report()},
  {"Last provider error",reader.last_error or "None"},
  {"Last runtime error",debugger.last_error or recovery.last_error or "None"},
  {"Build",Build.version},
  {"Local reader detail","loaded="..tostring(LocalLink.is_loaded).." / bars="..tostring(LocalLink.bars_observed)..
   " / readable="..tostring(LocalLink.labels_readable).." / candidates="..tostring(LocalLink.candidate_packets).." / receipts="..tostring(LocalLink.receipts)..
   " / last receipt="..(LocalLink.received_at and string.format("%.1fs ago",now-LocalLink.received_at) or "None")},
  {"Last local reader error",LocalLink.last_error or "None"}
 }
 for _,kind in ipairs({"menu","window"}) do
  local state=rendering[kind]
  rows[#rows+1]={kind=="menu" and "Menu rendering" or "Window rendering",
   state.failures.." errors / retry in "..string.format("%.1fs",state.retry_in)}
  rows[#rows+1]={kind=="menu" and "Last menu error" or "Last window error",state.last_error or "None"}
 end
 rows[#rows+1]={"Last display-data error",rendering.last_read_error or "None"}
 local queue_link=LocalLink.queues:report(now)
 rows[#rows+1]={"Queue data link",queue_link.state.." / updates="..queue_link.receipts.." / slots="..tostring(queue_link.count or "Unknown")}
 local flag_link=LocalLink.flags:report(now)
 rows[#rows+1]={"Flag map link",flag_link.state.." / map="..tostring(flag_link.map_id or "-").." / flags="..tostring(flag_link.count or 0)..
  (flag_link.received_at and " / age="..string.format("%.1fs",math.max(0,now-flag_link.received_at)) or "")}
 rows[#rows+1]={"Resolved queue ID",tostring(display_queue_id(now)).." / configured="..tostring(selected_queue():get())}
 return rows
end
-- Optional integration surface: external plugins keep their own rotations enabled.
_G.SylvanasBattlegroundBot={
 set_version_adapter=function(adapter)
  controller:reset_match();context=nil;Compat.set_adapter(adapter)
 end,
 get_capabilities=function() return Compat.capabilities(selected_mode().key) end,
 get_character_level_policy=function()
  local player=api.player();local role_name=detected_role(player);local style=detected_damage_style(player)
  local policy=detected_level_policy(player,role_name,style)
  local copy={};for key,value in pairs(policy) do copy[key]=value end
  return copy
 end,
 get_forever_readiness=function()
  return {detected=Client:is_forever(),queue_modes={configured_battleground=true,random_matchmaking=false,brawl=false,epic=false},
   profiles={"warsong","arathi","alterac","darkspear_islands"},darkspear_rules=Darkspear.rules,
   darkspear_navigation="landmark_fallback_no_native_mmap_2524",live_validation_required=true,route_scope=Client.route_scope,build=Build.version}
 end,
 get_forever_reference=function() return TrinityForever end,
 get_forever_mmap_reference=function(profile)
  if profile then return ForeverMMaps.coverage(profile) end
  local profiles={};for name in pairs(ForeverMMaps.profiles) do profiles[name]=ForeverMMaps.coverage(name) end
  return {target_build=ForeverMMaps.target_build,verified=false,status=ForeverMMaps.status,
   map_headers=ForeverMMaps.map_headers,tile_files=ForeverMMaps.tile_files,profiles=profiles}
 end,
 set_objective_actions=function(actions)
  assert(actions==nil or type(actions)=="table","Expected objective action table")
  if actions then for key,fn in pairs(actions) do
   assert((key=="vehicle" or key=="siege_gate") and type(fn)=="function","Invalid objective action")
  end end
  controller:reset_match();context=nil;objective_actions=actions
 end,
 show_window=function(value) Gui.open=value~=false end,
 set_objective_provider=function(fn)
  assert(fn==nil or type(fn)=="function","Expected snapshot provider function")
  controller:reset_match();context=nil;provider=fn;Reader:reset()
 end,
 get_context=function() return context end,
 get_status=function() return controller.state end,
 get_bridge_status=function() return LocalLink:report(core.time()) end,
 get_readiness=function() return readiness_report(core.time()) end,
 get_live_acceptance=function() return live_acceptance:report(Client.route_scope,Client.family) end,
 get_debug_snapshot=function() return {rows=debug_rows(),events=debugger:events_copy()} end,
 get_debug_report=function() return debugger:export(debug_rows()) end,
 clear_debugger=function() debugger:clear() end,
 show_debugger=function() Gui.open=true;Gui.page=4 end,
 get_recovery_status=function() local r=Health:report(core.time());r.objectives=Reader:report(core.time());return r end,
 reset_recovery=function() Health:reset();Reader:reset() end,
 stop=function() enabled:set(false);controller:reset_match();context=nil;debugger:add("control","stopped",core.time()) end,
 start=function() Health:reset();Reader:reset();enabled:set(true);debugger:add("control","started",core.time()) end
}
core.register_on_update_callback(function()
 if not instance_current() then return end
 local now=core.time()
 local logic_due=now>=(controller.next_logic_tick or 0)
 local logic_started=logic_due and performance:begin() or nil
 -- Keep the heavy custom window cold during F6 reloads, but always provide a
 -- discoverable, allocation-free way to bring it back. F2 is VK_F2 (0x71).
 local key_pressed=false
 if core.input and type(core.input.is_key_pressed)=="function" then
  local key_ok,key_state=pcall(core.input.is_key_pressed,0x71);key_pressed=key_ok and key_state==true
 end
 if key_pressed and not window_key_down then Gui.open=not Gui.open end
 window_key_down=key_pressed
 -- Queue/addon polling has a 250 ms contract and Arthas ownership heartbeats
 -- are five seconds apart. Running this supervisory work once per render frame
 -- only adds protected calls and allocations, especially at high frame rates.
 if now>=(next_supervisor_tick or 0) then
  next_supervisor_tick=now+0.25
  maintain_arthas_engine(enabled:get_state(),now)
  maintain_arthas_lease(enabled:get_state(),now)
  if type(probe_navigation_exports)=="function" then probe_navigation_exports(now) end
  if readiness and type(readiness.tick)=="function" then readiness:tick(now,enabled:get_state()) end
  if persistent_log then persistent_log:flush(now,false) end
  local link_state=LocalLink.state
  local link_ok,link_err=pcall(function() LocalLink:poll(core,now) end)
  if not link_ok then LocalLink.state="reader_error";LocalLink.last_error=Debug.trace(link_err);LocalLink.queues:invalidate("queue_reader_error") end
  if LocalLink.state~=link_state then debugger:add("local_link",LocalLink.state,now) end
  if live_acceptance and not live_acceptance.loaded and now>=live_acceptance_load_at then
   local bg_ok,in_bg=pcall(api.in_battleground)
   if bg_ok and not in_bg then
    if not live_acceptance:load() then
     live_acceptance_load_at=now+30
     debugger:add("live_acceptance_storage","load_failed:"..tostring(live_acceptance.error),now)
    elseif live_acceptance.dirty and not live_acceptance:flush() then
     debugger:add("live_acceptance_storage","save_failed:"..tostring(live_acceptance.error),now)
    end
   else live_acceptance_load_at=now+10 end
  end
  if readiness and not readiness.loaded and now>=readiness_load_at then
   local bg_ok,in_bg=pcall(api.in_battleground)
   if bg_ok and not in_bg then
    if not readiness:load(now) then readiness_load_at=now+30;debugger:add("readiness_storage","load_failed:"..tostring(readiness.error),now)
    elseif readiness.dirty and not readiness:flush() then debugger:add("readiness_storage","save_failed:"..tostring(readiness.error),now) end
   else readiness_load_at=now+10 end
  elseif readiness and readiness.loaded and readiness.dirty and now>=readiness_load_at then
   local bg_ok,in_bg=pcall(api.in_battleground)
   if bg_ok and not in_bg then
    if not readiness:flush() then debugger:add("readiness_storage","save_failed:"..tostring(readiness.error),now) end
    readiness_load_at=now+10
   end
  end
  local queue_link_state=LocalLink.queues:report(now).state
  if queue_link_state~=last_queue_link_state then debugger:add("queue_link",queue_link_state,now);last_queue_link_state=queue_link_state end
 end
 if Health.locked or enabled:get_state() and not Health:ready(now) then
  controller:status(Health.locked and "recovery_attention_required" or "recovering_runtime_error");return
 end
 -- Object discovery and target scoring are the expensive part of this
 -- controller. Once combat is active, 10 Hz is sufficient for movement while
 -- the separate combat rotation continues at its own cadence. Travel keeps
 -- 20 Hz responsiveness for doors, route corners and interactions.
 if not logic_due then return end
 tick_objects=nil
 local combat_state=controller.state=="combat_approaching" or controller.state=="combat_holding" or
  controller.state=="combat_reacquiring" or controller.state=="fight"
 controller.next_logic_tick=now+performance:interval(combat_state)
 local ok,err=xpcall(function() controller:tick() end,Debug.trace)
 local _,performance_tier_changed=performance:finish(logic_started)
 if performance_tier_changed then debugger:add("performance",performance:report(),now) end
 -- Instance APIs can become temporarily unavailable between
 -- PLAYER_LEAVING_WORLD and PLAYER_ENTERING_WORLD.  This read happens after
 -- the protected controller tick, so protect it independently as well.
 local performance_active=false
 pcall(function()
  performance_active=type(api)=="table" and type(api.in_battleground)=="function" and api.in_battleground()==true
 end)
 local completed_performance=performance:match_tick(performance_active)
 if performance:journal_due(now,performance_active,60) then debugger:add("performance_sample",performance:report(),now) end
 if not ok then
  local fault_in_bg=false
  pcall(function() fault_in_bg=type(api)=="table" and type(api.in_battleground)=="function" and api.in_battleground()==true end)
  if match_metrics and type(match_metrics.note_runtime_error)=="function" then match_metrics:note_runtime_error(fault_in_bg) end
  debugger:add("error",err,now)
  context=nil
  local cleaned,cleanup_error=pcall(function() controller:stop_motion();controller.recovery:reset(true) end)
  local state=Health:fail(now,err)
  if not cleaned then Health.locked=true;Health.last_error=tostring(err).."; cleanup: "..tostring(cleanup_error);state="recovery_attention_required" end
  if Health.locked then enabled:set(false) end
  controller:status(state)
  core.log("[Battleground recovery] "..tostring(err))
 else
  Health:success(now)
  if controller.state=="disabled" or not controller.plan then context=nil end
  local journal_ok,journal_err=pcall(function()
   local profile=detected_profile() or "none";local role_name=detected_role(api.player())
   local metric_player=api.player();local metric_position
   if metric_player then local got,value=pcall(function() return metric_player:get_position() end);metric_position=got and Snapshot.position(value) or nil end
   local winner_ok,winner=pcall(api.winner)
   local observed_faction=faction:report().team
   local metric_style=detected_damage_style(metric_player)
   local summary,evidence=match_metrics:tick(now,api.in_battleground(),profile,role_name,controller.state,metric_position,
    winner_ok and winner or nil,context and context.objective_source or nil,controller.plan and
     (tostring(controller.plan.kind)..":"..tostring(controller.plan.id or "")) or nil,observed_faction,controller.destination~=nil,metric_style)
   if summary then debugger:add("match_summary",summary,now) end
   if summary then
    if completed_performance and evidence then
     evidence.performance_samples=completed_performance.samples
     evidence.performance_spikes=completed_performance.spikes
     evidence.performance_max_ms=completed_performance.max_ms
     evidence.performance_spike_rate=completed_performance.spike_rate
     debugger:add("match_performance",string.format("samples=%d spikes=%d rate=%.4f max=%.2fms",
      completed_performance.samples,completed_performance.spikes,completed_performance.spike_rate,completed_performance.max_ms),now)
    end
    local clean=evidence and (evidence.outcome==0 or evidence.outcome==1 or evidence.outcome==2) and evidence.path_failures==0
    local accepted,reason=clean,"strict_validator_unavailable"
    if live_acceptance then
     accepted,reason=live_acceptance:observe(Client.route_scope,Client.family,evidence,clean==true)
     debugger:add("live_acceptance",accepted and ("accepted:"..tostring(evidence.profile)) or ("rejected:"..tostring(reason)),now)
     if accepted and not live_acceptance:flush() then debugger:add("live_acceptance_storage","save_failed:"..tostring(live_acceptance.error),now) end
    end
    readiness:observe("match",accepted==true)
   end
   if profile~=last_profile then debugger:add("profile",profile,now);last_profile=profile end
   if role_name~=last_role then debugger:add("role",role_name,now);last_role=role_name end
   local source=context and context.objective_source or "none"
   if source=="live_objective_reader" then readiness:observe("live_objectives",true) end
   if observed_faction==0 or observed_faction==1 then readiness:observe("faction",observed_faction) end
   if source~=last_objective_source then debugger:add("objective_source",source,now);last_objective_source=source end
   collect_object_census(now)
   collect_route_sample(now)
  end)
  if not journal_ok then debugger:add("journal_error",Debug.trace(journal_err),now) end
 end
end)
if type(core.register_on_render_callback)=="function" then
 core.register_on_render_callback(function()
  if not instance_current() then return end
  if show_path:get_state() then
   local state=controller.state
   local combat=state=="combat_approaching" or state=="combat_holding" or state=="combat_reacquiring" or state=="fight"
   pcall(PathRender.draw,core,controller,nav(),combat,performance.tier)
  end
 end)
end
-- The F2 command window owns all settings. Registering the same controls in the
-- Core menu creates a second native layout whose construction-order cache can
-- survive hot reloads and fail in ensure_loose_section/place_value. Keeping one
-- UI surface also removes duplicate sidebar entries and reload-time menu work.
plugin_init_ms=math.max(0,(plugin_load_clock()-plugin_load_clock_started)*1000)
debugger:add("plugin_init",string.format("version=%s main=%.1fms clock=%s",Build.version,plugin_init_ms,plugin_load_clock_source),core.time())
debugger:add("control",enabled:get_state() and "restored_enabled" or "restored_disabled",core.time())
local function report()
 local now=render_time();local cap=render_capabilities(now);local rendering=Renderer:report(now)
 return "Sylvanas Battleground Controller v"..Build.version.."\nStatus: "..controller.state..
  "\nClient: "..cap.version.." / "..cap.exact_version.."\nClient build: "..tostring(cap.game_patch or "unknown").." / "..tostring(cap.game_build or 0).." / interface "..tostring(cap.interface or 0).."\nMissing APIs: "..table.concat(cap.missing,", ")..
  "\nRecovery failures: "..Health.failures.." / retries: "..Health.retries.." / locked: "..tostring(Health.locked).."\nLast error: "..tostring(Health.last_error or "none")..
  "\nObjective reader: "..Reader.state.." / failures: "..Reader.failures.." / retry in: "..string.format("%.1f",Reader:report(core.time()).retry_in).."\nReader error: "..tostring(Reader.last_error or "none")..
  "\nQueue for: "..selected_mode().label.." / ID: "..display_queue_id(now).." / configured: "..selected_queue():get()..
  "\nObjectives: "..tostring(Renderer:read("objectives",now,api.objective_provider_ready,false)).."\nArthas engine: "..arthas_engine_state..(arthas_engine_error and (" / "..arthas_engine_error) or "").."\nArthasNav provider: "..sentinel_provider_kind.." / client: "..tostring(nav()~=nil).." / state: "..nav_health_state.."\nNavigation: "..tostring(Renderer:read("navigation",now,api.navigation_ready,false))..
  "\nMenu display error: "..tostring(rendering.menu.last_error or "none")..
  "\nWindow display error: "..tostring(rendering.window.last_error or "none")..
  "\nDisplay-data error: "..tostring(rendering.last_read_error or "none")
end
core.register_on_render_window_callback(function()
 if not instance_current() then return end
 -- Avoid native window creation and the full display-data scan on the normal
 -- gameplay path. This keeps F6 reloads responsive; explicit API calls can
 -- still open the command window or debugger when they are needed.
 if not Gui.open and not show_hud:get_state() then return end
 local now=render_time()
 Renderer:run("window",now,function()
 local player=Renderer:read("player",now,core.object_manager.get_local_player,false)
 local theme=Renderer:read("class and specialization",now,function() return Theme.detect(player) end,Theme.resolve(nil,nil))
 local detected_name,detected_flags=detected_role(player)
 local detected_style,style_source=detected_damage_style(player)
 local level_policy=detected_level_policy(player,detected_name,detected_style)
 local route_total=controller.plan and type(controller.plan.route)=="table" and #controller.plan.route or 0
 local player_position=Renderer:read("player position",now,function() return player and Snapshot.position(player:get_position()) end,nil)
 local destination=Snapshot.position(controller.destination)
 local route_distance=player_position and destination and Planner.distance(player_position,destination) or nil
 local s={debug_rows=debug_rows,debug_report=function() return debugger:export(debug_rows()) end,recovery=Health:report(now),theme=theme,status=controller.state,enabled=enabled:get_state(),show_hud=show_hud:get_state(),show_path=show_path:get_state(),
  queue_mode=selected_mode().index,queue_label=selected_mode().label,queue_options=queue_labels(),
  queue_id=selected_queue():get(),resolved_queue_id=display_queue_id(now),role_flags=detected_flags,role_policy=role_guidelines[detected_name],damage_style=detected_style,damage_style_source=style_source,damage_style_choice=damage_style:get(),combat_range=range:get(),level_policy=level_policy,capabilities=render_capabilities(now),
  context=context,provider_ready=Renderer:read("objectives",now,api.objective_provider_ready,false),navigation_ready=Renderer:read("navigation",now,api.navigation_ready,false),
  sentinel_provider=type(rawget(_G,"ArthasNavEnhancements"))=="table" or type(rawget(_G,"ArthasNav"))=="table",sentinel_client=nav()~=nil,sentinel_provider_kind=sentinel_provider_kind,sentinel_state=nav_health_state,
  readiness=readiness_report(now),route_index=controller.route_index or 0,route_total=route_total,route_distance=route_distance,
  area=Renderer:read("area",now,core.get_instance_name,"Loading"),profile=Renderer:read("battleground profile",now,detected_profile,nil),version=Build.version,log_rows=log_rows,
  log_text=function() return debugger:export(debug_rows()) end,report=report}
 if s.area=="" then s.area="Outside battleground" end
 s.role_label=({[2]="Tank",[4]="Healer",[8]="Damage"})[s.role_flags] or "Custom roles"
 Gui.render(s,function(action,value)
  if action=="start" then _G.SylvanasBattlegroundBot.start()
  elseif action=="stop" then _G.SylvanasBattlegroundBot.stop()
  elseif action=="clear_debugger" then debugger:clear()
  elseif action=="queue_mode" then queue_mode:set(Client:queue_mode(QueueModes,value).index)
  elseif action=="queue" then selected_queue():set(value)
  elseif action=="range" then range:set(value)
  elseif action=="role" then role:set(value)
  elseif action=="damage_style" then damage_style:set(value)
  elseif action=="hud" then show_hud:set(value)
  elseif action=="path" then show_path:set(value) end
 end)
 end)
end)
