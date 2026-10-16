-- Core callbacks cannot be unregistered. Stop the previous generation and
-- make every old callback inert before installing this one. Without this,
-- repeated script reloads can run duplicate controllers and movement owners.
local previous_instance=rawget(_G,"SylvanasAutoLeveler")
if type(previous_instance)=="table" and type(previous_instance.stop)=="function" then
 pcall(previous_instance.stop)
end
local instance_generation=(tonumber(rawget(_G,"SylvanasAutoLevelerGeneration")) or 0)+1
_G.SylvanasAutoLevelerGeneration=instance_generation
local function instance_current()
 return rawget(_G,"SylvanasAutoLevelerGeneration")==instance_generation
end
local ArthasBootstrap=require("arthas_bootstrap")
local Controller = require("controller")
local Runtime = require("runtime")
Runtime.api=require("leveler_runtime_api")
local profiles = require("profiles")
local RouteAuthor = require("route_author")
local Guidance = require("guidance")
local Overlay=require("path_overlay")
local Selector=require("start_selector")
local Logger=require("logger")
local Settings=require("settings")
local Gui=require("gui")
local Build=require("header")
local Coordinates=require("coordinates")
local Compiler=require("route_compiler")
local Navigation=require("navigation")
local RestedXPProfile=require("restedxp_profile")
local CustomCompiler=require("custom_route_compiler")
local CustomCatalog=require("custom_route_catalog")
local SpeedSelector=require("speed_route_selector")
local Debugger=require("debugger")
local Snapshot=require("data_snapshot")
local Client=require("client_compat")
assert(Logger.entity_id=="sylvanas_auto_leveler" and Debugger.entity_id==Logger.entity_id,"leveler_telemetry_identity_mismatch")
Settings.load();Overlay.enabled=Settings.values.show_path
local logger=Logger.new(Logger.runtime_api())
local function log(event,fields) logger:record(event,fields) end
local function report_error(message) if type(core.log_error)=="function" then pcall(core.log_error,message) end end
log("session_loaded",{version=Build.version,entity_id=Logger.entity_id,game_version=Client.version(),exact_game_version=Client.exact_version()})
local QuestData=require("quest_data")
local rxp_state=QuestData.status(core.addons and core.addons.rested_xp)
local questie_state=QuestData.status(core.addons and core.addons.questie)
log("runtime_capabilities",{arthas_nav_loaded=type(rawget(_G,"ArthasNav") or rawget(_G,"Amei".."senNav"))=="table",sentinel_loaded=_G.SentinelNavClient~=nil,
    navlib_loaded=_G.NavLib~=nil,
    quest_panel_api=core.quests and type(core.quests.get_open_quest_info)=="function" or false,
    restedxp_api=core.addons and core.addons.rested_xp~=nil or false,
    restedxp_loaded=rxp_state.loaded,restedxp_has_step=rxp_state.active,
    questie_loaded=questie_state.loaded,questie_ready=questie_state.ready,
    blizzard_objectives_api=core.quests and type(core.quests.get_quest_objectives)=="function" or false,
    questie_api=core.addons and core.addons.questie~=nil or false})
logger:flush(true)
local recorder = RouteAuthor.new(RouteAuthor.runtime_api())
local taught_profile
local taught_flush_at=0
local PathLearning=require("path_learning")
local ManualControl=require("manual_control")
local manual_control=ManualControl.new()
local manual_owner
local active, adapter
local chain_visited={}
local runtime_recovery=require("runtime_recovery").new({max=3,window=60,stable=120})
local runtime_restart_at
local navigation_failures=0
local session_recovery=require("session_recovery").new({
    create_data_folder=core.create_data_folder,create_data_file=core.create_data_file,
    read_data_file=core.read_data_file,delete_data_file=core.delete_data_file,write_data_file=core.write_data_file},10)
local function debug_snapshot()
    local p=Runtime.api.player()
    return Debugger.capture({active=active,player=p and p:is_valid() and p or nil,area=adapter and adapter.area,
        navigation=Navigation,version=Build.version,captured_at=core.time(),map=core.get_map_id,instance=core.get_instance_id,
        arthas_nav_loaded=type(rawget(_G,"ArthasNav") or rawget(_G,"Amei".."senNav"))=="table",sentinel_loaded=_G.SentinelNavClient~=nil,navlib_loaded=_G.NavLib~=nil,log_error=logger:failure()})
end
local function debug_text()
    return Debugger.text(debug_snapshot(),logger.rows,40)
end
-- Developer interface. Profile selection and production UI remain to be implemented.
_G.SylvanasAutoLeveler = {
    entity_id = Logger.entity_id,
    guides = Guidance.list,
    guide_plan = Guidance.plan,
    checkpoint_xy = Coordinates.runtime_resolve,
    next_guides = Guidance.next_guides,
    area = function() return adapter and adapter.area() or nil end,
    show_path = function(enabled) Overlay.enabled=enabled==true;Settings.set("show_path",enabled) end,
    show_window = function(enabled) Gui.open=enabled==true end,
    log_text = function() return logger:text() end,
    save_log = function() logger:flush(true);local failure=logger:failure();return failure==nil,failure end,
    debug_snapshot = debug_snapshot,
    debug_text = debug_text,
    auto_start = function()
        if active and active.enabled then
            log("auto_start_already_running",{step=active.index,state=active.state})
            return true,"already_running"
        end
        local p=Runtime.api.player()
        if not p or not p:is_valid() then log("start_rejected",{reason="character_not_ready"});logger:flush(true);return false,"character_not_ready" end
        local character=Compiler.character(p)
        log("auto_start_character",{level=character.level,race=character.race,class=character.class,
            faction=character.faction,map=character.ui_map_id})
        local rx=core.addons and core.addons.rested_xp
        -- Prefer the live RestedXP guide. If the addon is loaded without a
        -- current step, immediately continue from the compiled coordinate
        -- catalog instead of leaving Auto Start permanently unavailable.
        if RestedXPProfile.available(rx) then
            local rxprofile,rxreason=RestedXPProfile.build(rx)
            if rxprofile then
                log("guide_source_selected",{source="sylvanas_restedxp_route",step=rxprofile.rxp_step_num})
                return _G.SylvanasAutoLeveler.start_profile(rxprofile)
            end
            local fields={reason=rxreason}
            if rx.get_current_step then
                local ok,current=pcall(rx.get_current_step)
                if ok and current then fields.rxp_step=current.num;fields.rxp_active=current.active;fields.rxp_complete=current.is_complete end
            end
            log("restedxp_live_fallback",fields)
        else
            local loaded=rx and type(rx.is_loaded)=="function" and rx.is_loaded() or false
            local has_step=rx and type(rx.has_current_step)=="function" and rx.has_current_step() or false
            log("restedxp_live_fallback",{reason="active_guide_unavailable",restedxp_loaded=loaded,restedxp_has_step=has_step})
        end
        local id,reason=Compiler.select(profiles,character)
        local speed_id,speed_reason=SpeedSelector.select(CustomCatalog,character)
        if speed_id then
            log("guide_source_selected",{source="restedxp_speed_catalog",profile=speed_id})
            return _G.SylvanasAutoLeveler.start(speed_id)
        end
        log("restedxp_speed_fallback",{reason=speed_reason})
        local guid=p.get_guid and p:get_guid()
        if guid then
            local Progress=require("progress")
            local saved,last=Progress.read({read=core.read_data_file},guid)
            local preferred,best_resume_score
            for candidate,row in pairs(saved) do
                local metadata=profiles[candidate]
                if metadata then
                    local compiled=Compiler.load(metadata,character)
                    if compiled then
                        local checkpoint=Progress.new({read=core.read_data_file},guid,compiled):load()
                        local resume_score,reject=Compiler.saved_resume_score(metadata,compiled,checkpoint,character,
                            candidate==last,profiles[id])
                        if resume_score and (not best_resume_score or resume_score>best_resume_score) then
                            preferred,best_resume_score=candidate,resume_score
                        elseif reject and candidate==last then
                            log("auto_start_saved_guide_ignored",{profile=candidate,reason=reject,checkpoint=checkpoint})
                        end
                    end
                end
            end
            if preferred then id=preferred;log("auto_start_saved_guide",{profile=id}) end
        end
        if not id then log("start_rejected",{reason=reason,level=p:get_level(),race_id=p:get_race_id(),class_id=p:get_class(),map=core.get_map_id()});logger:flush(true);return false,reason end
        return _G.SylvanasAutoLeveler.start(id)
    end,
    record_start = function(name)
        if active then active:stop("route_authoring") end
        return recorder:start(name)
    end,
    teach_path = function()
        if not active then return false,"start_a_profile_first" end
        taught_profile=active.profile.id;taught_flush_at=core.time()+5;runtime_restart_at=nil
        active:stop("teaching_manual_path")
        return recorder:start("manual_teaching")
    end,
    save_taught_path = function()
        if not taught_profile then return false,"teach_path_first" end
        -- Include the final position even when less than the normal sample spacing.
        local p,c=recorder.api.sample()
        if not p or not c or c.world_map_id~=recorder.context.world_map_id
            or c.instance_id~=recorder.context.instance_id or c.ui_map_id~=recorder.context.ui_map_id
            or recorder.status~="recording" then return false,"route_context_changed_restart_teaching" end
        recorder.nodes[#recorder.nodes+1]=p;recorder.recording=false
        local ok,why=PathLearning.store(PathLearning.runtime_api(),taught_profile,recorder.context,recorder.nodes)
        recorder.status=ok and "taught_path_saved" or why
        log("manual_path_saved",{profile=taught_profile,points=#recorder.nodes,success=ok})
        taught_profile=nil;return ok,why
    end,
    record_save = function() return recorder:save() end,
    record_status = function() return recorder.status end,
    start_profile = function(profile,continuation)
        local profile_id=profile.id
        if not continuation then chain_visited={} end
        chain_visited[profile_id]=true
        runtime_restart_at=nil;runtime_recovery:reset()
        if active then active:stop() end
        local configured={};for k,v in pairs(profile) do configured[k]=v end
        configured.service_policy={};for k,v in pairs(profile.service_policy or {}) do configured.service_policy[k]=v end
        for _,key in ipairs({"auto_equip","auto_repair","auto_sell"}) do configured.service_policy[key]=Settings.values[key] end
        configured.auto_mount=Settings.values.auto_mount;configured.auto_talents=Settings.values.auto_talents
        configured.auto_skyriding=Settings.values.auto_skyriding and Client.supports_skyriding();configured.built_in_combat=Settings.values.built_in_combat
        configured.game_version=Client.version();configured.exact_game_version=Client.exact_version()
        configured.persistent_navigation=true
        adapter=Runtime.new(configured,log);active=Controller.new(adapter,configured)
        active.index=require("quest_resume").select(configured.steps,1,adapter)
        log("quest_progress_reconciled",{profile=profile_id,saved_step=1,selected_step=active.index,source="custom_coordinates"})
        active:start();return true
    end,
    start = function(profile_id,continuation)
        runtime_restart_at=nil;runtime_recovery:reset()
        if recorder.recording then log("start_rejected",{reason="recording_active"});logger:flush(true);report_error("Auto Leveler: save the recorded route before playback"); return false end
        if CustomCatalog[profile_id] then
            local p=Runtime.api.player()
            if not p or not p:is_valid() then return false,"character_not_ready" end
            local source=require(CustomCatalog[profile_id].module)
            local custom,blockers=CustomCompiler.compile(source,Compiler.character(p))
            if not custom then
                local first=blockers[1] or {}
                log("custom_route_preflight_blocked",{profile=profile_id,count=#blockers,
                    source_step=first.step,line=first.line,reason=first.reason})
                logger:flush(true)
                return false,tostring(first.reason).." (source step "..tostring(first.step or "guide")..")"
            end
            log("custom_route_compiled",{profile=profile_id,steps=#custom.steps,source="standalone_coordinates"})
            return _G.SylvanasAutoLeveler.start_profile(custom,continuation)
        end
        if profile_id=="RestedXP:live" then
            local rxprofile,reason=RestedXPProfile.build(core.addons and core.addons.rested_xp)
            if not rxprofile then return false,reason end
            return _G.SylvanasAutoLeveler.start_profile(rxprofile,continuation)
        end
        local profile = profiles[profile_id]
        if not profile then log("start_rejected",{reason="validated_profile_missing",profile=profile_id});logger:flush(true);report_error("Auto Leveler: validated profile missing: " .. tostring(profile_id)); return false end
        if profile.compiled then
            local p=Runtime.api.player()
            if not p or not p:is_valid() then return false,"character_not_ready" end
            local converted,reason=Compiler.load(profile,Compiler.character(p))
            if not converted then log("start_rejected",{profile=profile_id,reason=reason});logger:flush(true);return false,reason end
            profile=converted
            if #profile.steps==0 then log("start_rejected",{reason="guide_has_no_steps_for_character",profile=profile_id});logger:flush(true);return false,"guide_has_no_steps_for_character" end
            log("route_compiled",{profile=profile_id,steps=#profile.steps,live_validated=false})
        end
        if active then active:stop() end
        local configured={};for k,v in pairs(profile) do configured[k]=v end
        configured.service_policy={};for k,v in pairs(profile.service_policy or {}) do configured.service_policy[k]=v end
        for _,key in ipairs({"auto_equip","auto_repair","auto_sell"}) do configured.service_policy[key]=Settings.values[key] end
        configured.auto_mount=Settings.values.auto_mount
        configured.auto_talents=Settings.values.auto_talents
        configured.auto_skyriding=Settings.values.auto_skyriding and Client.supports_skyriding()
        configured.built_in_combat=Settings.values.built_in_combat
        configured.game_version=Client.version();configured.exact_game_version=Client.exact_version()
        configured.persistent_navigation=true
        adapter = Runtime.new(configured,log)
        local checkpoint_player=Runtime.api.player()
        local checkpoint_guid=checkpoint_player and checkpoint_player.get_guid and checkpoint_player:get_guid()
        local checkpoint
        if checkpoint_guid then
            checkpoint=require("progress").new({read=core.read_data_file,write=function(path,text)
                core.create_data_folder("sylvanas_auto_leveler")
                return Snapshot.write(core,path,text)
            end},checkpoint_guid,configured)
            adapter.save=function(id,index)
                if not checkpoint:save(id,index) then log("checkpoint_write_failed",{profile=id,step=index}) end
            end
        end
        local unavailable=adapter.readiness_reason()
        if unavailable and unavailable~="navigation_server_unavailable" then log("start_rejected",{reason=unavailable,profile=profile_id});logger:flush(true);return false,unavailable end
        active = Controller.new(adapter,configured)
        if checkpoint then active.index=checkpoint:load();log("checkpoint_resumed",{profile=profile_id,step=active.index}) end
        local saved_index=active.index
        active.index=require("quest_resume").select(configured.steps,active.index,adapter,
            checkpoint_player and Compiler.character(checkpoint_player) or nil)
        log("quest_progress_reconciled",{profile=profile_id,saved_step=saved_index,selected_step=active.index})
        if not continuation then chain_visited={} end
        chain_visited[profile_id]=true
        active:start()
        return true
    end,
    stop = function() manual_control:cancel();manual_owner=nil;taught_profile=nil;recorder.recording=false;runtime_restart_at=nil;runtime_recovery:reset();if active then active:stop() end;logger:flush(true) end,
    status = function() return active and active.state or "ready_to_select_guide" end,
}
core.register_on_game_event_callback(function(event,args)
    if not instance_current() then return end
    if event:match("^QUEST_") or event:match("^SCENARIO_") or event=="PLAYER_CONTROL_LOST" or event=="PLAYER_CONTROL_GAINED" or event=="MERCHANT_SHOW" or event=="MERCHANT_CLOSED" or event=="PLAYER_DEAD" or event=="PLAYER_ENTERING_WORLD" then log("game_event",{event=event}) end
    if adapter then
        local ok,err=pcall(adapter.event,event,args)
        if not ok then log("game_event_dispatch_error",{event=event,error=err});logger:flush(true);report_error("Auto Leveler event: "..tostring(err)) end
    end
    if event=="PLAYER_LOGOUT" or event=="PLAYER_LEAVING_WORLD" then
        local snapshot=debug_snapshot();log("session_ending",{event=event,state=snapshot.state,step=snapshot.step,quest_id=snapshot.quest_id})
        session_recovery:write(core.time(),Debugger.text(snapshot,logger.rows,40),true);logger:flush(true)
    end
end)
local last_state,last_step,last_map,last_record
local NavigationService=require("navigation_service")
core.register_on_update_callback(function()
    if not instance_current() then return end
    ArthasBootstrap.tick("auto_leveler", active ~= nil and active.enabled == true)
    NavigationService.tick(active and active.enabled,core.time(),rawget(_G,"ArthasNavBootstrap"),log)
    local manual_input,manual_source=ManualControl.input({key=core.input and core.input.is_key_pressed,typing=core.is_textbox_focused})
    local local_player=Runtime.api.player()
    local manual_position=local_player and local_player:is_valid() and local_player:get_position() or nil
    if manual_control.active and manual_owner~=active then
        manual_control:cancel();manual_owner=nil;taught_profile=nil;recorder.recording=false
    end
    if manual_input and active and active.enabled and not recorder.recording then
        if adapter and adapter.manual_action_begin then adapter.manual_action_begin(active.profile.steps[active.index]) end
        local ok,why=_G.SylvanasAutoLeveler.teach_path()
        if ok then
            manual_owner=active;manual_control:begin(core.time(),manual_position)
            Gui.notice="Manual control: recording your path. Resume automatically after 3 seconds still."
            log("manual_takeover_started",{profile=active.profile.id,step=active.index,input_source=manual_source or "explicit"})
        else
            log("manual_takeover_record_failed",{reason=why});active:stop("manual_control")
            manual_owner=active;manual_control:begin(core.time(),manual_position)
        end
    end
    local manual_ready=manual_control:ready(core.time(),manual_position,manual_input,
        (core.is_textbox_focused and core.is_textbox_focused()) or not local_player or not local_player:is_valid()
        )
    if manual_control.active and adapter and adapter.manual_action_tick then adapter.manual_action_tick() end
    if manual_ready and adapter and adapter.manual_action_end then adapter.manual_action_end() end
    if manual_ready and manual_control.active and not recorder.recording and not taught_profile then
        manual_control:cancel();manual_owner=nil
        if active then active:start();log("manual_control_auto_resumed",{step=active.index,recorded=false}) end
    end
    if active and not active.enabled and runtime_restart_at and core.time()>=runtime_restart_at then
        runtime_restart_at=nil;active:start();log("runtime_restart",{step=active.index})
    end
    local navigation_failed=false
    if active and active.enabled then
        local ok,err=pcall(Navigation.tick)
        if not ok then
            navigation_failed=true;navigation_failures=navigation_failures+1
            local delay=math.min(60,2^math.min(5,navigation_failures-1))
            active:stop("navigation_runtime_error");active.state="navigation_runtime_error_restarting";runtime_restart_at=core.time()+delay
            log("navigation_runtime_error",{error=err,attempt=navigation_failures,restart_in=delay});logger:flush(true)
            report_error("Auto Leveler navigation: "..tostring(err))
        else navigation_failures=0 end
    end
    if recorder.recording then
        local ok,err=pcall(function() recorder:tick() end)
        if not ok then recorder.recording=false; recorder.status="recording_error";log("recording_error",{error=err});logger:flush(true);report_error(tostring(err)) end
        if ok and manual_control.active and taught_profile and not recorder.recording then
            -- A zone boundary or teleport splits the recorded path instead of
            -- leaving the character permanently paused or joining disconnected points.
            if #recorder.nodes>=2 then
                local saved,why=PathLearning.store(PathLearning.runtime_api(),taught_profile,recorder.context,recorder.nodes)
                log("manual_path_segment_saved",{success=saved,reason=why,status=recorder.status})
            end
            local restarted=recorder:start("manual_teaching")
            if not restarted and manual_ready then
                manual_control:cancel();manual_owner=nil;taught_profile=nil
                if active then active:start() end
                log("manual_takeover_resumed_without_recording",{step=active and active.index})
            end
        end
        if ok and taught_profile and recorder.recording then
            local learned,problem=pcall(function()
                if manual_control.active and manual_ready or not manual_control.active and recorder:autosave_ready() then
                    local saved,why
                    if manual_control.active and #recorder.nodes<2 then
                        recorder.recording=false;taught_profile=nil;saved=true
                        log("manual_takeover_no_path",{reason="no_recordable_movement"})
                    else saved,why=_G.SylvanasAutoLeveler.save_taught_path() end
                    manual_control:cancel();manual_owner=nil
                    if saved then
                        Gui.notice="Path saved automatically. Leveling resumed."
                        if active then
                            active.index=require("quest_resume").select(active.profile.steps,active.index,adapter)
                            active:start()
                        end
                        log("manual_path_auto_resumed",{step=active and active.index})
                    else log("manual_path_auto_save_failed",{reason=why});Gui.notice=tostring(why) end
                elseif #recorder.nodes>=2 and core.time()>=taught_flush_at then
                    taught_flush_at=core.time()+5
                    local saved,why=PathLearning.store(PathLearning.runtime_api(),taught_profile,recorder.context,recorder.nodes)
                    if not saved then log("manual_path_checkpoint_save_failed",{reason=why}) end
                end
            end)
            if not learned then log("manual_path_auto_save_error",{error=tostring(problem)});Gui.notice="Path save failed; see logs." end
        end
    end
    if active and not navigation_failed then
        local ok,err = pcall(function() active:tick() end)
        if not ok then
            active:stop("runtime_error")
            local delay,attempt=runtime_recovery:failure(core.time())
            log("runtime_error",{error=err,attempt=attempt,restart_in=delay})
            logger:flush(true);report_error("Auto Leveler: " .. tostring(err))
            if delay then active.state="runtime_error_restarting";runtime_restart_at=core.time()+delay
            else log("runtime_error_circuit_open",{step=active.index,failures=attempt}) end
        else runtime_recovery:success(core.time()) end
        if active.enabled and core.time()>=(active.next_heartbeat or 0) then
            active.next_heartbeat=core.time()+10
            local snapshot=debug_snapshot()
            log("heartbeat",{state=snapshot.state,step=snapshot.step,quest_id=snapshot.quest_id,map=snapshot.map,
                x=snapshot.x,y=snapshot.y,z=snapshot.z,move=snapshot.move,navigation_available=snapshot.navigation_available,
                navigation_planning=snapshot.navigation_planning,target_id=snapshot.target_id})
            local saved,reason=session_recovery:write(core.time(),Debugger.text(snapshot,logger.rows,40),false)
            if not saved and reason~="throttled" and session_recovery:should_report(core.time()) then log("recovery_snapshot_failed",{reason=reason,attempts=session_recovery.failures}) end
        end
        if active.state=="profile_finished" and active.profile.source=="custom_coordinates" and not active.chain_attempted then
            active.chain_attempted=true
            local p=Runtime.api.player()
            if p and p:is_valid() then
                local candidates,reason=CustomCompiler.next_candidates(active.profile,CustomCatalog,Compiler.character(p))
                local started=false;local failure=reason
                for _,id in ipairs(candidates or {}) do
                    if not chain_visited[id] then
                        local ok,why=_G.SylvanasAutoLeveler.start(id,true)
                        if ok then log("custom_route_transition",{to=id});started=true;break end
                        if why and not why:find("guide_character_mismatch",1,true) then failure=why;break end
                    else failure="custom_route_transition_cycle:"..id end
                end
                if not started and p:get_level()<90 then
                    local character=Compiler.character(p)
                    local rxprofile,rxreason=RestedXPProfile.build(core.addons and core.addons.rested_xp)
                    if rxprofile and rxprofile.rxp_signature~=active.profile.rxp_signature then
                        log("custom_route_transition_fallback",{source="restedxp_live",reason=failure or "authored_next_missing"})
                        _G.SylvanasAutoLeveler.start_profile(rxprofile,true);started=true
                    end
                    if not started then
                        local speed_id,speed_reason=SpeedSelector.select(CustomCatalog,character,chain_visited)
                        if speed_id then
                            local ok,why=_G.SylvanasAutoLeveler.start(speed_id,true)
                            if ok then log("custom_route_transition_fallback",{source="restedxp_speed_catalog",to=speed_id});started=true
                            else failure=why end
                        else failure=failure or speed_reason end
                    end
                    if not started then
                        local compiled_id,compiled_reason=Compiler.select(profiles,character)
                        if compiled_id and not chain_visited[compiled_id] then
                            local ok,why=_G.SylvanasAutoLeveler.start(compiled_id,true)
                            if ok then log("custom_route_transition_fallback",{source="compiled_retail",to=compiled_id});started=true
                            else failure=why end
                        else failure=failure or compiled_reason or "custom_next_route_unavailable" end
                    end
                    if not started then log("custom_route_chain_gap",{profile=active.profile.id,reason=failure});logger:flush(true) end
                end
            end
        elseif active.state=="profile_finished" and active.profile.source=="restedxp_live"
            and core.time()>=(active.next_rxp_poll or 0) then
            active.next_rxp_poll=core.time()+1
            local next_profile,reason=RestedXPProfile.build(core.addons and core.addons.rested_xp)
            if next_profile and next_profile.rxp_signature~=active.profile.rxp_signature then
                log("restedxp_step_transition",{from=active.profile.rxp_step_num,to=next_profile.rxp_step_num})
                _G.SylvanasAutoLeveler.start_profile(next_profile,true)
            elseif not next_profile and active.last_rxp_wait~=reason then
                active.last_rxp_wait=reason
                log("restedxp_step_wait",{reason=reason})
            end
        elseif active.state=="profile_finished" and active.profile.compiled and not active.chain_attempted then
            active.chain_attempted=true
            local p=Runtime.api.player()
            if p and p:is_valid() then
                local next_id,reason=Compiler.next_profile(profiles,active.profile,Compiler.character(p),chain_visited)
                if next_id then
                    log("guide_transition",{from=active.profile.id,to=next_id})
                    local started,failure=_G.SylvanasAutoLeveler.start(next_id,true)
                    if not started then log("guide_transition_blocked",{reason=failure}) end
                else log("guide_transition_blocked",{reason=reason}) end
            end
        end
        if last_state~=active.state or last_step~=active.index then
            local step=active.profile.steps[active.index] or {}
            log("state",{state=active.state,step=active.index,quest_id=step.quest_id,action=step.action,npc_id=step.npc_id})
            last_state=active.state;last_step=active.index
            if not active.enabled then logger:flush(true) end
        end
    end
    if last_record~=recorder.status then last_record=recorder.status;log("recorder_state",{state=last_record}) end
    local p=Runtime.api.player()
    if p and p:is_valid() then
        local map=tostring(core.get_map_id())..":"..tostring(core.get_instance_id())
        if map~=last_map then last_map=map;local pos=p:get_position();log("area",{map=core.get_map_id(),instance=core.get_instance_id(),level=p:get_level(),x=pos.x,y=pos.y,z=pos.z}) end
    end
    -- Keep the independently owned debugger snapshot fresh while stopped,
    -- recording, disconnected or waiting, as well as during active questing.
    if (not active or not active.enabled) and session_recovery:due(core.time()) then
        local saved,reason=session_recovery:write(core.time(),debug_text(),false)
        if not saved and reason~="throttled" and session_recovery:should_report(core.time()) then log("recovery_snapshot_failed",{reason=reason,attempts=session_recovery.failures}) end
    end
    logger:flush(false)
end)
core.log("Sylvanas Auto Leveler loaded. RestedXP live routing with compiled coordinate-route recovery is ready.")
local overlay_retry_at=0
core.register_on_render_callback(function()
    if not instance_current() then return end
    if core.time()<overlay_retry_at then return end
    local p=Runtime.api.player()
    local state=active and tostring(active.state or "") or ""
    local aerial=(p and p:is_valid() and p:is_flying()) or state:find("skyriding",1,true)~=nil
    local aerial_points,aerial_index
    if aerial and active and active.adapter and active.adapter.aerial_path then
        aerial_points,aerial_index=active.adapter.aerial_path()
    elseif not aerial and active and active.adapter and active.adapter.ground_path then
        aerial_points,aerial_index=active.adapter.ground_path()
    end
    local ok,err=pcall(Overlay.draw,active and active.enabled,aerial,aerial_points,aerial_index)
    if not ok then overlay_retry_at=core.time()+2;log("overlay_error",{error=err,retry_in=2});logger:flush(true);report_error("Path overlay: "..tostring(err)) end
end)
local gui_profiles={}
gui_profiles[#gui_profiles+1]={id="RestedXP:live",label="Sylvanas Leveling Route (RestedXP)"}
for id,route in pairs(CustomCatalog) do
    gui_profiles[#gui_profiles+1]={id=id,label="Custom coordinates: "..route.name.." [preflight]"}
end
table.sort(gui_profiles,function(a,b) return tostring(a.id)<tostring(b.id) end)
local function gui_action(action,key,value)
    if action=="setting" then
        local ok,err=Settings.set(key,value)
        Overlay.enabled=Settings.values.show_path
        log("setting_changed",{key=key,value=value,saved=ok,error=err})
        Gui.notice=ok and "Option saved." or "Option changed; file could not be saved."
    elseif action=="save_log" then
        local ok,err=_G.SylvanasAutoLeveler.save_log()
        Gui.notice=ok and "Log saved to scripts_data/sylvanas_auto_leveler/logs/latest.txt" or tostring(err)
    elseif action=="save_debug" then
        local snapshot=debug_snapshot();local text=Debugger.text(snapshot,logger.rows,40)
        core.create_data_folder("sylvanas_auto_leveler");core.create_data_folder("sylvanas_auto_leveler/logs")
        local safe,result=pcall(Snapshot.write,core,"sylvanas_auto_leveler/logs/debug_snapshot.txt",text)
        local ok=safe and result~=false
        log("debug_snapshot_saved",{step=snapshot.step,quest_id=snapshot.quest_id,state=snapshot.state,success=ok})
        logger:flush(true);Gui.notice=ok and "Debug snapshot saved to logs/debug_snapshot.txt" or "Debug snapshot could not be saved."
    elseif action=="teach_path" or action=="save_taught_path" then
        local ok,why=_G.SylvanasAutoLeveler[action]()
        Gui.notice=ok and (action=="teach_path" and "Leveler paused. Move manually; stop for 5 seconds to save and resume." or "Path saved. Resume to reuse it near the same destination.") or tostring(why)
    elseif action=="auto_start" then
        local ok,reason=_G.SylvanasAutoLeveler.auto_start()
        Gui.notice=ok and "Leveling started." or "Unable to start: "..tostring(reason)
    elseif action=="start" then
        local ok,reason=_G.SylvanasAutoLeveler.start(key)
        Gui.notice=ok and "Leveling started." or "Unable to start: "..tostring(reason or "see logs")
    elseif action=="previous_step" or action=="next_step" then
        if active then active:select_step(action=="previous_step" and -1 or 1);Gui.notice="Selected step "..active.index
        else Gui.notice="Start a profile before selecting a step." end
    elseif action=="resume" then
        if active then active:start();Gui.notice="Resumed selected step."
        else Gui.notice="Start a profile first." end
    elseif action=="stop" then _G.SylvanasAutoLeveler.stop();Gui.notice="Stopped. Log saved." end
end
local gui_retry_at=0
local gui_debug,gui_debug_at=nil,-math.huge
core.register_on_render_window_callback(function()
    if not instance_current() then return end
    if core.time()<gui_retry_at then return end
    local ok,err=pcall(function()
        local p=Runtime.api.player()
        local step=active and active.profile.steps[active.index] or {}
        local now=core.time()
        if not gui_debug or now-gui_debug_at>=0.25 then gui_debug=debug_snapshot();gui_debug_at=now end
        local debug=gui_debug
        Gui.render({status=_G.SylvanasAutoLeveler.status(),level=p and p:is_valid() and p:get_level() or nil,game_version=Client.version(),
            area=p and p:is_valid() and core.get_map_name() or "Character unavailable",
            index=active and active.index,total=active and #active.profile.steps,
            step_title=step.title or step.action,action=step.action,quest_id=step.quest_id,
            profiles=gui_profiles,settings=Settings.values,log_text=function() return logger:text() end,
            log_rows=logger.rows,log_error=logger:failure(),debug=debug,debug_text=debug_text},gui_action)
    end)
    if not ok then gui_retry_at=core.time()+2;log("gui_error",{error=err,retry_in=2});logger:flush(true);report_error("Leveling window: "..tostring(err)) end
end)
