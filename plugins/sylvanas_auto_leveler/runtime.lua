-- Retail-only adapter. Uses quest identity checks before accepting/rewarding a panel.
local nav = require("navigation")
local vec3 = require("common/geometry/vector_3")
local Services=require("services")
local MovementWatch=require("movement_watch")
local GuideSupport=require("guide_support")
local Gear=require("gear")
local QuestTargets=require("quest_targets")
local TrinityForeverOk,TrinityForever=pcall(require,"trinitycore_forever")
if not TrinityForeverOk then TrinityForever={} end
local QuestSearch=require("quest_search")
local QuestInventory=require("quest_inventory")
local QuestDialogue=require("quest_dialogue")
local QuestObjectives=require("quest_objectives")
local QuestData=require("quest_data")
local QuestConditions=require("quest_conditions")
local Talents=require("talents")
local Sky=require("skyriding")
local Variants=require("quest_variants")
local Specialization=require("specialization")
local SafeInteraction=require("safe_interaction")
local InteractionTracker=require("interaction_tracker")
local QuestRouteMemory=require("quest_route_memory")
local QuestieSupport=require("questie_support")
local Snapshot=require("data_snapshot")
local TargetPrediction=require("target_prediction")
local RuntimeApi=require("leveler_runtime_api")
local M = {}
function M.new(profile,log)
    nav.initialize(log)
    local panel, next_input = nil, 0
    local greeting_open=false
    local a = { handlers = {} }
    a.log=log
    local function emit(event,fields) if log then log(event,fields) end end
    local read_failure_next={}
    local function safe_read(event,fn,fallback,...)
        if type(fn)~="function" then return fallback end
        local ran,result=pcall(fn,...)
        if ran then return result end
        local now=core.time()
        if now>=(read_failure_next[event] or 0) then
            read_failure_next[event]=now+5;emit(event.."_read_failed",{error=tostring(result)})
        end
        return fallback
    end
    local function quest_state(id) return safe_read("quest_accepted",core.quests.is_on_quest,nil,id) end
    local function quest_accepted(id) return quest_state(id)==true end
    local function quest_completed(id) return safe_read("quest_completed",core.quests.is_quest_flagged_completed,false,id)==true end
    local function safe_input(event,fn,...)
        if type(fn)~="function" then emit(event.."_rejected",{error="input_unavailable"});return false end
        local ran,result=pcall(fn,...)
        if not ran or result==false then
            emit(event.."_rejected",{error=not ran and tostring(result) or nil})
            return false
        end
        return true
    end
    local services,loot_pending,loot_generation
    local route_memory=QuestRouteMemory.new({
        time=core.time,
        read=core.read_data_file,
        write=function(path,text)
            if type(core.create_data_folder)~="function" or type(core.create_data_file)~="function" or type(core.write_data_file)~="function" then return false end
            core.create_data_folder("sylvanas_auto_leveler")
            return Snapshot.write(core,path,text)
        end,
    },profile and profile.id)
    local seen_vendors={}
    -- Deduplicate terrain requests across short-lived resolver tables. Some
    -- itinerary/search callers build a query wrapper, and a delayed Sentinel
    -- response must remain attached to the coordinate rather than the Lua
    -- table's lifetime.
    local destination_height_queries={}
    local pull_moving,pull_epoch,pull_next=nil,0,0
    local target_prediction=TargetPrediction.new()
    local prediction_log_at={}
    local attack_next=0
    local function player() return RuntimeApi.player() end
    a.position=function() local p=player();return p and p:is_valid() and p:get_position() or nil end
    -- The raw object manager is expensive and many objective helpers can run
    -- in the same update. Reuse one snapshot for 500 ms, matching Sylvanas'
    -- documented scan-cooldown guidance instead of rebuilding it per helper.
    local object_cache,object_cache_at,object_cache_context={},-math.huge,nil
    local function objects()
        local now=core.time()
        local context=tostring(safe_read("object_cache_map",core.get_map_id,0))..":"..
            tostring(safe_read("object_cache_instance",core.get_instance_id,0))
        if context==object_cache_context and now-object_cache_at<0.5 then return object_cache end
        local current=RuntimeApi.objects()
        if type(current)=="table" then object_cache=current end
        object_cache_at=now;object_cache_context=context
        return object_cache
    end
    local flight
    local combat
    local taxi_job,world_transport_job
    local learned_quest_givers={}
    local pending_quest_giver
    local interaction_tracker=InteractionTracker.new(core.time)
    local questie=core.addons and core.addons.questie
    local bridge={loaded=false,scenario={criteria={}},merchant={items={}},achievements={},choices={},area_names={},area_pois={},cooldowns={},mounts={},chromie_time={},adventure_map={},skyriding_unlocked=nil,darkmoon_faire=nil,home_bound_epoch=0,extra_action={spell_id=0,available=false},
        player={taxi=false,in_vehicle=false,can_exit_vehicle=false,vehicle_guid="",speed=0,epoch=0},
        quest_map={points={},objectives={},waypoints={},available={},taxi_nodes={}},vehicle_actions={slots={}},failed_quests={},quest_contacts={},
        forever_guide={available=false},guide_actions={},capabilities={forever_guide=false,shortest_path=false,questie=false}}
    local objective_sources={}
    local function live_objectives(id)
        local rows,source=QuestData.objectives(core.quests,core.addons and core.addons.rested_xp,bridge.quest_map,id,core.time())
        if rows and objective_sources[id]~=source then
            objective_sources[id]=source;emit("quest_data_source",{quest_id=id,source=source})
        end
        return rows
    end
    local bridge_scenario_completion_epoch=0
    local function bridge_fields(message)
        local rows={};for value in (tostring(message or "").."|"):gmatch("(.-)|") do rows[#rows+1]=value end
        return rows
    end
    local function bridge_event(args)
        if not args or args[1]~="SALBRIDGE" then return end
        local f=bridge_fields(args[2]);local kind=f[1]
        bridge.loaded=true
        if kind=="H" then
            bridge.capabilities={forever_guide=f[3]=="1",shortest_path=f[4]=="1",questie=f[5]=="1"}
            emit("companion_bridge_ready",{version=f[2],forever_guide=bridge.capabilities.forever_guide,
                shortest_path=bridge.capabilities.shortest_path,questie=bridge.capabilities.questie})
        elseif kind=="G" then
            bridge.forever_guide={available=f[2]=="1",guide_id=f[3],step_index=tonumber(f[4]),type=f[5],
                quest_id=tonumber(f[6]),objective=tonumber(f[7]),npc_id=tonumber(f[8]),npc_name=f[9],
                target_name=f[10],item_id=tonumber(f[11]),ui_map_id=tonumber(f[12]),
                x=tonumber(f[13]),y=tonumber(f[14])}
        elseif kind=="S" then
            local generation=tonumber(f[2]) or 0
            local stage_id=tonumber(f[5])
            local scenario_id=tonumber(f[6])
            bridge.scenario={generation=generation,complete=f[3]=="1",count=tonumber(f[4]) or 0,
                stage_id=stage_id,scenario_id=scenario_id,
                title=scenario_id and f[7] or stage_id and f[6] or f[5],criteria={}}
        elseif kind=="C" and bridge.scenario.generation==tonumber(f[2]) then
            bridge.scenario.criteria[tonumber(f[3]) or 0]={complete=f[4]=="1",quantity=tonumber(f[5]) or 0,
                total=tonumber(f[6]) or 0,description=f[7]}
        elseif kind=="D" then bridge_scenario_completion_epoch=bridge_scenario_completion_epoch+1
        elseif kind=="M" then
            bridge.merchant={generation=tonumber(f[2]) or 0,count=tonumber(f[3]) or 0,items={}}
        elseif kind=="I" and bridge.merchant.generation==tonumber(f[2]) then
            local row={slot=tonumber(f[3]),item_id=tonumber(f[4]),name=f[5]}
            bridge.merchant.items[#bridge.merchant.items+1]=row
        elseif kind=="E" then
            bridge.extra_action={spell_id=tonumber(f[2]) or 0,available=f[3]=="1"}
        elseif kind=="L" then
            local id=tonumber(f[2]);if id then bridge.area_names[id]=f[3] end
        elseif kind=="K" then
            local id=tonumber(f[2]);if id then bridge.choices[id]=true end
        elseif kind=="Y" then
            local id,criterion=tonumber(f[2]),tonumber(f[3]) or 0
            if id then bridge.achievements[tostring(id)..":"..criterion]=f[4]=="1" end
        elseif kind=="B" then bridge.home_bound_epoch=(bridge.home_bound_epoch or 0)+1
        elseif kind=="Z" then
            local map,id=tonumber(f[2]),tonumber(f[3]);if map and id then bridge.area_pois[tostring(map)..":"..tostring(id)]=f[4]=="1" end
        elseif kind=="R" then
            local id=tonumber(f[2]);if id then bridge.cooldowns[id]=tonumber(f[3]) end
        elseif kind=="DMF" then bridge.darkmoon_faire=f[2]=="1"
        elseif kind=="CAP" then
            bridge.skyriding_unlocked=f[2]=="1";local id=tonumber(f[3]);if id then bridge.mounts[id]=f[4]=="1" end
        elseif kind=="CT" then local id=tonumber(f[2]);if id then bridge.chromie_time[id]=true end
        elseif kind=="AM" then local id=tonumber(f[2]);if id then bridge.adventure_map[id]=true end
        elseif kind=="GA" then
            local name=tostring(f[2] or "")
            if name~="" then bridge.guide_actions[name]=core.time();emit("companion_guide_action_observed",{name=name}) end
        elseif kind=="P" then
            bridge.player={taxi=f[2]=="1",in_vehicle=f[3]=="1",can_exit_vehicle=f[4]=="1",
                vehicle_guid=f[5] or "",speed=tonumber(f[6]) or 0,epoch=(bridge.player.epoch or 0)+1}
        elseif kind=="Q" then
            bridge.quest_map={generation=tonumber(f[2]) or 0,map_id=tonumber(f[3]),count=tonumber(f[4]) or 0,at=core.time(),points={},objectives={},waypoints={},available={},taxi_nodes={}}
        elseif kind=="W" and bridge.quest_map.generation==tonumber(f[2]) then
            bridge.quest_map.points[tonumber(f[3]) or 0]={x=(tonumber(f[4]) or 0)*100,y=(tonumber(f[5]) or 0)*100}
        elseif kind=="J" and bridge.quest_map.generation==tonumber(f[2]) then
            local id=tonumber(f[3])
            if id and id>0 then bridge.quest_map.waypoints[id]={ui_map_id=tonumber(f[4]),
                x=(tonumber(f[5]) or 0)*100,y=(tonumber(f[6]) or 0)*100,text=f[7] or ""} end
        elseif kind=="U" and bridge.quest_map.generation==tonumber(f[2]) then
            local id=tonumber(f[3])
            if id and id>0 then bridge.quest_map.available[id]={ui_map_id=tonumber(f[4]),
                x=(tonumber(f[5]) or 0)*100,y=(tonumber(f[6]) or 0)*100,name=f[7] or "",quest_start=f[8]=="1"} end
        elseif kind=="T" and bridge.quest_map.generation==tonumber(f[2]) then
            bridge.quest_map.taxi_nodes[#bridge.quest_map.taxi_nodes+1]={node_id=tonumber(f[3]),ui_map_id=tonumber(f[4]),
                x=(tonumber(f[5]) or 0)*100,y=(tonumber(f[6]) or 0)*100,name=f[7] or "",undiscovered=f[8]=="1",faction=tonumber(f[9]) or 0}
        elseif kind=="O" and bridge.quest_map.generation==tonumber(f[2]) then
            local quest_id,index=tonumber(f[3]),tonumber(f[4])
            if quest_id and index then
                bridge.quest_map.objectives[quest_id]=bridge.quest_map.objectives[quest_id] or {}
                bridge.quest_map.objectives[quest_id][index]={type=f[5],finished=f[6]=="1",fulfilled=tonumber(f[7]) or 0,
                    required=tonumber(f[8]) or 0,text=f[9] or ""}
            end
        elseif kind=="V" then
            bridge.vehicle_actions={generation=tonumber(f[2]) or 0,count=tonumber(f[3]) or 0,slots={}}
        elseif kind=="X" and bridge.vehicle_actions.generation==tonumber(f[2]) then
            bridge.vehicle_actions.slots[tonumber(f[3]) or 0]={type=f[4],id=tonumber(f[5]),usable=f[6]=="1"}
        elseif kind=="F" then
            local id=tonumber(f[2]);if id and id>0 then bridge.failed_quests[id]=true;emit("quest_failed_client_event",{quest_id=id}) end
        elseif kind=="A" then
            local id=tonumber(f[2]);if id and id>0 then bridge.failed_quests[id]=nil end
        elseif kind=="N" then
            local action,id=f[2],tonumber(f[3]);local npc_id=tonumber(f[4])
            if id and id>0 and (action=="accept" or action=="turnin") then
                local contact={npc_id=npc_id and npc_id>0 and npc_id or nil,name=f[5],x=tonumber(f[6]),y=tonumber(f[7]),
                    z=tonumber(f[8]),instance=tonumber(f[9])}
                bridge.quest_contacts[action..":"..id]=contact
                if contact.npc_id then learned_quest_givers[action..":"..id]=contact.npc_id end
                emit("quest_contact_observed",{action=action,quest_id=id,npc_id=contact.npc_id,name=contact.name})
            end
        end
    end
    local function combat_tick(target,prepare)
        if not profile or profile.built_in_combat~=true then return false end
        if not combat then combat=require("combat").new(log,{move=nav.move_combat,stop=nav.stop,objects=objects}) end
        return combat:tick(target,prepare)
    end
    a.combat_tick=function() return combat_tick() end
    a.combat_prepare=function() return combat_tick(nil,true) end
    local function distance(p, q)
        local x,y,z = p.x-q.x,p.y-q.y,p.z-q.z
        return math.sqrt(x*x+y*y+z*z)
    end
    local function target(id,alive)
        local nearest, best = nil, math.huge
        local p = player()
        for _, obj in pairs(objects()) do
            if obj:is_valid() and obj:get_npc_id() == id and (not alive or not obj:is_dead()) then
                local d = distance(p:get_position(), obj:get_position())
                if d < best then nearest, best = obj, d end
            end
        end
        return nearest, best
    end
    -- TrinityCore UnitDefines.h: quest giver 0x2; vendor classes
    -- 0x80,0x100,0x200,0x400,0x800; repair 0x1000; flight 0x2000.
    local function npc_flag(flags,value) return math.floor((flags or 0)/value)%2==1 end
    local function vendor_flag(flags)
        return npc_flag(flags,128) or npc_flag(flags,256) or npc_flag(flags,512)
            or npc_flag(flags,1024) or npc_flag(flags,2048)
    end
    local function named_target(step,alive)
        if step.action=="accept" or step.action=="turnin" or step.allow_dead_target or step.tags and step.tags.NC then alive=false end
        local learned=step.quest_id and learned_quest_givers[tostring(step.action)..":"..tostring(step.quest_id)]
        if learned then
            local obj,d=target(learned,alive)
            if obj then return obj,d end
        end
        if step.target_ids then
            local nearest,best=nil,math.huge
            for _,id in ipairs(step.target_ids) do
                local candidate,d=target(id,alive)
                if candidate and d<best then nearest,best=candidate,d end
            end
            if nearest then return nearest,best end
        end
        if step.npc_id then return target(step.npc_id,alive) end
        local nearest,best=nil,math.huge;local p=player()
        if not step.target_name and step.quest_id and (step.action=="accept" or step.action=="turnin") then
            local ids=QuestieSupport.quest_giver_ids(questie,step.quest_id,step.action)
            local obj,d=QuestieSupport.nearest_matching(objects(),ids,
                function(candidate) return p:can_attack(candidate) end,
                function(candidate) return distance(p:get_position(),candidate:get_position()) end,80)
            if obj then return obj,d end
        end
        if not step.target_name and (step.action=="accept" or step.action=="turnin") then
            -- Some imported guides provide a destination but omit the contact
            -- identity. At the destination, the NPC quest-giver flag is safer
            -- than guessing from every neutral unit. Quest-panel validation
            -- still rejects a contact that does not expose the required quest.
            for _,candidate in pairs(objects()) do
                if candidate:is_valid() and candidate.get_npc_flags and candidate.get_position
                    and not candidate:is_dead() and not p:can_attack(candidate)
                    and npc_flag(candidate:get_npc_flags(),2) then
                    local d=distance(p:get_position(),candidate:get_position())
                    if d<=12 and d<best then nearest,best=candidate,d end
                end
            end
            if nearest then
                if core.time()>=(step.giver_fallback_log_at or 0) then
                    step.giver_fallback_log_at=core.time()+5
                    emit("quest_giver_flag_fallback",{action=step.action,quest_id=step.quest_id,
                        npc_id=nearest:get_npc_id(),distance=best})
                end
                return nearest,best
            end
        end
        if not step.target_name and not step.target_names then return nil,best end
        local names={}
        for _,name in ipairs(step.target_names or {}) do names[name:lower()]=true end
        if step.target_name then names[step.target_name:lower()]=true end
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj.get_name and names[obj:get_name():lower()]
                and (not alive or not obj:is_dead()) then
                local d=distance(p:get_position(),obj:get_position())
                if d<best then nearest,best=obj,d end
            end
        end
        if not nearest and step.tags and step.tags.CHAT then
            local prefix=step.target_name:lower().." "
            local match
            for _,obj in pairs(objects()) do
                if obj:is_valid() and not obj:is_dead() and obj.get_name and obj:get_npc_id()>0
                    and obj:get_name():lower():sub(1,#prefix)==prefix and not p:can_attack(obj) then
                    local d=distance(p:get_position(),obj:get_position())
                    if d<=60 then
                        if match then return nil,math.huge end
                        match=obj;best=d
                    end
                end
            end
            nearest=match
        end
        return nearest,best
    end
    a.bind_quest=function(step)
        if not step.quest_ids or step.quest_id then return step.quest_id end
        local id,reason=Variants.observe(step,quest_state,quest_completed)
        if id then step.quest_id=id;emit("quest_variant_resolved",{quest_id=id,expression=step.tags and step.tags.QID,source="observed_quest_state"}) end
        return id,reason
    end
    a.step_skip=function(step)
        if step.action=="accept" and step.quest_id and not quest_accepted(step.quest_id) then
            local dependency=QuestieSupport.dependency_state(questie,step.quest_id,
                quest_state,quest_completed)
            if dependency and dependency.skip then
                emit("predictive_quest_skip",{quest_id=step.quest_id,reason=dependency.reason,
                    related=table.concat(dependency.related or {},";")})
                return true
            end
        end
        if step.lead_condition and (not step.quest_id or quest_state(step.quest_id)==false) then
            local superseded=QuestConditions.evaluate(step.lead_condition,quest_completed)
            if superseded==true then
                emit("breadcrumb_superseded",{quest_id=step.quest_id,lead=step.lead_condition,source_index=step.source_index})
                return true
            end
        end
        if step.exploration_only and (not profile or profile.skip_exploration~=false) then
            emit("speed_detour_skipped",{source_index=step.source_index,title=step.title,reason="exploration_only"})
            return true
        end
        if step.active_condition then
            local active=QuestConditions.evaluate(step.active_condition,quest_state)
            if active==false then return true end
        end
        if (step.action=="objective" or step.action=="turnin") and (step.conditional_turnin or step.optional_area_objective or step.tags and step.tags.O) then
            return step.quest_id and not quest_accepted(step.quest_id)
                and not quest_completed(step.quest_id)
        end
        return false
    end
    a.step_gate=function(step)
        if step.active_condition then
            local active,reason=QuestConditions.evaluate(step.active_condition,quest_state)
            if active==nil then return reason..":"..step.active_condition end
        end
        if (step.action=="turnin" or step.action=="objective") and not step.conditional_turnin and not (step.tags and step.tags.O)
            and step.quest_id and not quest_accepted(step.quest_id)
            and not quest_completed(step.quest_id) then
            return "quest_not_accepted:"..step.quest_id,{step.quest_id}
        end
        if step.action=="accept" and step.quest_id and not quest_accepted(step.quest_id) then
            local dependency=QuestieSupport.dependency_state(questie,step.quest_id,
                quest_state,quest_completed)
            if dependency and dependency.missing and #dependency.missing>0 then
                emit("predictive_prerequisite_missing",{quest_id=step.quest_id,reason=dependency.reason,
                    missing=table.concat(dependency.missing,";")})
                return dependency.reason..":"..step.quest_id,dependency.missing
            end
            local doable=QuestieSupport.quest_doable(questie,step.quest_id)
            if doable==false and not step.questie_unavailable_logged then
                step.questie_unavailable_logged=true
                emit("questie_acceptance_advisory",{quest_id=step.quest_id,doable=false})
            end
        end
        if step.action~="accept" or not step.pre or step.quest_id and quest_accepted(step.quest_id) then return end
        local passed,reason,missing=QuestConditions.evaluate(step.pre,quest_completed)
        if passed==nil then return reason..":"..step.pre end
        if not passed then return "missing_prerequisite:"..step.pre,missing end
    end
    a.recover_step=function(step,attempt)
        a.stop();pull_epoch=pull_epoch+1;pull_moving=nil;panel=nil
        interaction_tracker:reset()
        safe_input("recover_close_quest",core.quests.close_quest)
        safe_input("recover_close_gossip",core.quests.close_gossip)
        step.position=nil;step.height_query=nil;step.search_state=nil;step.search_query=nil
        step.target_scan=nil;step.target_memory=nil;step.dynamic_action_ready=nil
        step.live_target=nil;step.pending_world_interaction=nil;step.pending_item_action=nil
        step.interaction_retry_at=nil;step.item_retry_at=nil
        step.interaction_range=require('route_policy').arrival(step.action,step.interaction_range,
            step.tags and tonumber(step.tags.U) and 'item' or step.action=='collect' and 'object' or nil)
        if step.recovery_checkpoint and step.recovery_checkpoint_arrived then
            route_memory:record(step,step.recovery_checkpoint,false)
            local learned=route_memory:summary(step,step.recovery_checkpoint)
            emit("quest_checkpoint_learned",{quest_id=step.quest_id,checkpoint=step.recovery_checkpoint,outcome="stalled",successes=learned.successes,failures=learned.failures})
        elseif step.recovery_checkpoint then
            emit("quest_checkpoint_unreached",{quest_id=step.quest_id,checkpoint=step.recovery_checkpoint,outcome="navigation_or_resolution_failure"})
        end
        local checkpoint
        local choice_reason,choice_score
        if step.checkpoints and #step.checkpoints>0 then
            checkpoint,choice_reason,choice_score=route_memory:choose(step,attempt)
            step.map_position=step.checkpoints[checkpoint]
            step.recovery_checkpoint=checkpoint
            step.recovery_checkpoint_arrived=nil
        end
        local chosen=checkpoint and route_memory:summary(step,checkpoint) or {}
        emit("quest_step_recovery",{quest_id=step.quest_id,source_index=step.source_index,attempt=attempt,
            checkpoint=checkpoint,choice_reason=choice_reason,choice_score=choice_score,
            checkpoint_successes=chosen.successes,checkpoint_failures=chosen.failures})
        return true
    end
    a.note_step_progress=function(step)
        if not step or not step.recovery_checkpoint then return end
        local checkpoint=step.recovery_checkpoint
        route_memory:record(step,checkpoint,true)
        local learned=route_memory:summary(step,checkpoint)
        emit("quest_checkpoint_learned",{quest_id=step.quest_id,checkpoint=checkpoint,outcome="progress",successes=learned.successes,failures=learned.failures})
        step.recovery_checkpoint=nil
        step.recovery_checkpoint_arrived=nil
    end
    a.note_checkpoint_arrival=function(step)
        if not step or not step.recovery_checkpoint or step.recovery_checkpoint_arrived then return end
        step.recovery_checkpoint_arrived=true
        emit("quest_checkpoint_arrived",{quest_id=step.quest_id,checkpoint=step.recovery_checkpoint})
    end
    a.quest_route_status=function(step)
        if not step or not step.checkpoints or #step.checkpoints==0 then return nil end
        local checkpoint=step.recovery_checkpoint or route_memory:choose(step,1)
        local learned=route_memory:summary(step,checkpoint)
        return {checkpoint=checkpoint,successes=learned.successes,failures=learned.failures}
    end
    local function enrich_from_forever_guide(step)
        if not profile or profile.game_version~="Forever" then return false end
        local live=bridge.forever_guide
        if not live or not live.available or not live.quest_id or live.quest_id<=0 then return false end
        if not step.quest_id or step.quest_id~=live.quest_id then return false end
        local changed=false
        if (not step.ui_map_id or step.ui_map_id<=0) and live.ui_map_id and live.ui_map_id>0 then step.ui_map_id=live.ui_map_id;changed=true end
        if not step.map_position and live.x and live.y and live.x>0 and live.y>0 then
            step.map_position={x=live.x,y=live.y};changed=true
        end
        if (not step.npc_id or step.npc_id<=0) and live.npc_id and live.npc_id>0 then step.npc_id=live.npc_id;changed=true end
        if (not step.target_name or step.target_name=="") then
            local name=live.target_name~="" and live.target_name or live.npc_name
            if name and name~="" then step.target_name=name;changed=true end
        end
        if live.objective and live.objective>0 and not step.objective_index then step.objective_index=live.objective;changed=true end
        if live.item_id and live.item_id>0 then
            step.item_goal=step.item_goal or {}
            if not step.item_goal.item_id then step.item_goal.item_id=live.item_id;changed=true end
        end
        if changed and not step.forever_guide_enriched then
            step.forever_guide_enriched=true
            emit("forever_guide_step_enriched",{guide=live.guide_id,guide_step=live.step_index,quest_id=live.quest_id,
                source_index=step.source_index,map=step.ui_map_id,npc_id=step.npc_id,item_id=live.item_id})
        end
        return changed
    end
    a.resolve_position=function(step)
        enrich_from_forever_guide(step)
        if GuideSupport.zygor(step,core.addons and core.addons.zygor) then
            emit("guide_identity_fallback",{quest_id=step.quest_id,source="zygor_live",npc_id=step.npc_id,map=step.ui_map_id})
        end
        if step.resolve_at_player or step.quest_giver_item or step.item_goal and step.quest_action_mode=="self" and not step.map_position then
            local v=player():get_position();return {x=v.x,y=v.y,z=v.z}
        end
        local obj=named_target(step,true)
        if obj then local v=obj:get_position();return {x=v.x,y=v.y,z=v.z} end
        if GuideSupport.enrich(step,core.addons and core.addons.rested_xp) then
            emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="restedxp_live",map=step.ui_map_id})
        end
        if not step.map_position and step.quest_id and (step.action=="accept" or step.action=="turnin") then
            local giver=QuestieSupport.quest_giver_point(questie,step.quest_id,step.action,
                type(core.get_map_id)=="function" and core.get_map_id() or step.ui_map_id)
            if giver then
                step.ui_map_id=giver.ui_map_id;step.map_position=giver.map_position
                if giver.kind=="npc" then step.npc_id=giver.entity_id end
                emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="questie_giver_spawn",map=step.ui_map_id,
                    entity_id=giver.entity_id,kind=giver.kind})
            end
        end
        local contact=step.quest_id and bridge.quest_contacts[tostring(step.action)..":"..tostring(step.quest_id)]
        if contact and contact.x and contact.y and contact.z and (contact.x~=0 or contact.y~=0) then
            emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="companion_quest_contact",npc_id=contact.npc_id})
            return {x=contact.x,y=contact.y,z=contact.z}
        end
        if profile and profile.edition=="Vanilla" and step.quest_id
            and (step.action=="accept" or step.action=="turnin") then
            local record=TrinityForever[step.quest_id]
            local candidates=record and record[step.action]
            local current_instance=type(core.get_instance_id)=="function" and core.get_instance_id() or nil
            local here=player():get_position();local best,best_distance,best_entity=nil,math.huge,nil
            for _,entity in ipairs(candidates or {}) do
                -- The object manager exposes both creature and game-object
                -- entries through get_npc_id(), so this identity is useful for
                -- quest dialog and clickable-object targets alike.
                if not step.npc_id then step.npc_id=entity.entity_id end
                for _,spawn in ipairs(entity.spawns or {}) do
                    if current_instance==nil or spawn.instance_id==current_instance then
                        local d=distance(here,spawn)
                        if d<best_distance then best,best_distance,best_entity=spawn,d,entity.entity_id end
                    end
                end
            end
            if best then
                emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="trinitycore_map_spawn",
                    entity_id=best_entity,instance=current_instance,distance=best_distance})
                return {x=best.x,y=best.y,z=best.z}
            end
        end
        if not step.map_position and step.action=="accept" and step.quest_id and bridge.quest_map.available[step.quest_id] then
            local offer=bridge.quest_map.available[step.quest_id]
            if offer.ui_map_id and offer.x>0 and offer.y>0 then
                step.map_position={x=offer.x,y=offer.y};step.ui_map_id=offer.ui_map_id
                emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="blizzard_available_quest_line",
                    map=step.ui_map_id,quest=offer.name})
            end
        end
        if not step.map_position and step.quest_id and bridge.quest_map.waypoints[step.quest_id] then
            local waypoint=bridge.quest_map.waypoints[step.quest_id]
            if waypoint.ui_map_id and waypoint.x>0 and waypoint.y>0 then
                step.map_position={x=waypoint.x,y=waypoint.y};step.ui_map_id=waypoint.ui_map_id
                emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="blizzard_next_waypoint",
                    map=step.ui_map_id,waypoint=waypoint.text})
            end
        end
        if not step.map_position and step.quest_id and bridge.quest_map.points[step.quest_id] then
            step.map_position=bridge.quest_map.points[step.quest_id]
            step.ui_map_id=bridge.quest_map.map_id
            emit("guide_coordinate_fallback",{quest_id=step.quest_id,source="blizzard_quest_map",map=step.ui_map_id})
        end
        if not step.map_position and step.action=="travel"
            and (step.travel_mode=="taxi_flight" or step.travel_mode=="taxi_discovery") then
            local Vec2=require("common/geometry/vector_2")
            local current=player():get_position();local best,best_distance=nil,math.huge
            for _,node in ipairs(bridge.quest_map.taxi_nodes or {}) do
                if node.ui_map_id and node.x>0 and node.y>0
                    and (step.travel_mode=="taxi_discovery" or not node.undiscovered) then
                    local ok,xy=pcall(core.game_ui.get_world_pos_from_map_pos,node.ui_map_id,
                        Vec2.new(node.x/100,node.y/100))
                    if ok and xy and type(xy.x)=="number" and type(xy.y)=="number" then
                        local d=math.sqrt((current.x-xy.x)^2+(current.y-xy.y)^2)
                        if d<best_distance then best,best_distance=node,d end
                    end
                end
            end
            if best and best_distance<=3000 then
                step.map_position={x=best.x,y=best.y};step.ui_map_id=best.ui_map_id
                emit("guide_coordinate_fallback",{source="blizzard_nearest_taxi_node",node_id=best.node_id,
                    node=best.name,map=best.ui_map_id,distance=best_distance,undiscovered=best.undiscovered})
            end
        end
        if not step.map_position or not step.ui_map_id then return nil,"guide_coordinates_missing:"..tostring(step.source_index) end
        local Vec2=require("common/geometry/vector_2")
        local ok,xy,continent=pcall(core.game_ui.get_world_pos_from_map_pos,step.ui_map_id,
            Vec2.new(step.map_position.x/100,step.map_position.y/100))
        if not ok or not xy or type(xy.x)~="number" or type(xy.y)~="number" then return nil,"map_conversion_unavailable" end
        local instance=core.get_instance_id and core.get_instance_id()
        if type(continent)=="number" and continent>0 and type(instance)=="number" and continent~=instance then
            emit("destination_wrong_continent",{quest_id=step.quest_id,target_instance=continent,current_instance=instance,ui_map_id=step.ui_map_id})
            return nil,"cross_continent_transport_required"
        end
        local p=player():get_position()
        if math.sqrt((p.x-xy.x)^2+(p.y-xy.y)^2)>30000 then return nil,"cross_continent_transport_required" end
        local query=vec3.new(xy.x,xy.y,p.z)
        local client=nav.client and nav.client()
        local can_query_height=client and type(client.get_height)=="function"
            and (not client.supports_height_query or client:supports_height_query())
        local success,z=pcall(core.get_height_for_position,query)
        local echoed_altitude=success and type(z)=="number" and math.abs(z-p.z)<.01
            and distance(p,{x=xy.x,y=xy.y,z=p.z})>20
        if success and type(z)=="number" and z==z and math.abs(z)<100000 and z~=0 and not echoed_altitude then
            -- Arthas height checks are asynchronous. Do not accept a reported
            -- collision height merely because its callback has not arrived yet.
            if not (can_query_height and nav.provider_name and nav.provider_name()=="arthas_nav") then
                return {x=xy.x,y=xy.y,z=z}
            end
            if not step.reported_height_deferred then
                step.reported_height_deferred=true
                emit("destination_reported_height_deferred",{quest_id=step.quest_id,reported=z,reason="awaiting_measured_layer"})
            end
        end
        -- Unknown height must be supplied by the mesh, never guessed from current altitude.
        if nav.measured_height then
            local terrain=nav.measured_height(query)
            if terrain then emit("destination_height_measured",{quest_id=step.quest_id,x=xy.x,y=xy.y,z=terrain});return {x=xy.x,y=xy.y,z=terrain} end
        end
        if nav.approach_destination then
            local approach=nav.approach_destination(p,query,step.approach_attempt)
            if approach then
                emit("destination_approach",{quest_id=step.quest_id,source_index=step.source_index,x=approach.x,y=approach.y,z=approach.z})
                return approach,"intermediate_destination"
            end
        end
        -- Legacy clients without a height endpoint must resolve the seed
        -- during pathfinding. Clients exposing height queries resolve the
        -- destination first, including asynchronous responses.
        if nav.provider_name and nav.provider_name()=="arthas_nav" and not can_query_height then
            emit("destination_height_seeded",{quest_id=step.quest_id,source_index=step.source_index,x=xy.x,y=xy.y,z=p.z})
            return {x=xy.x,y=xy.y,z=p.z,_unknown_altitude=true}
        end
        local client=nav.client()
        if not client or type(client.get_height)~="function" then return nil,"terrain_height_unavailable" end
        local height_key=tostring(step.ui_map_id)..":"..tostring(xy.x)..":"..tostring(xy.y)
        if step.height_query and step.height_query.x~=nil and (step.height_query.x~=xy.x or step.height_query.y~=xy.y) then
            if step.height_query.retry_at and core.time()<step.height_query.retry_at then return nil,"resolving_destination" end
            step.height_query=nil
        end
        if not step.height_query then
            step.height_query=destination_height_queries[height_key]
        end
        if not step.height_query then
            step.height_query={started=core.time(),x=xy.x,y=xy.y,key=height_key,seed_z=p.z}
            local request=step.height_query
            destination_height_queries[height_key]=request
            client:get_height(query,function(first,second)
                local h=type(first)=="number" and first or type(second)=="number" and second
                if type(first)=="table" then h=first.height or first.z end
                if type(second)=="table" then h=second.height or second.z end
                if type(h)=="number" and h==h and math.abs(h)<100000 then request.height=h end
                request.complete=true
                if not request.height and not request.failure_logged then
                    request.failure_logged=true
                    emit("destination_height_failed",{reason=type(second)=="string" and second or "mesh_returned_no_height",x=xy.x,y=xy.y})
                end
            end,{unknown_altitude=true})
        end
        local request=step.height_query
        -- The shared Sentinel client can advertise get_all_heights while
        -- leaving that optional request pending forever.  After a short
        -- grace period, query its proven single-layer endpoint using the
        -- player's observed altitude as the layer seed.  Sentinel still
        -- supplies the measured destination height; we never invent Z.
        if not request.height and not request.near_started
            and (request.complete or core.time()-request.started>=2) and type(client.get_height_near)=="function" then
            request.near_started=true
            client:get_height_near(query,function(first,second)
                local h=type(first)=="number" and first or type(second)=="number" and second
                if type(first)=="table" then h=first.height or first.z end
                if type(second)=="table" then h=second.height or second.z end
                if type(h)=="number" and h==h and math.abs(h)<100000 then
                    request.height=h;request.complete=true
                    emit("destination_height_near_fallback",{quest_id=step.quest_id,x=xy.x,y=xy.y,z=h})
                elseif second then
                    emit("destination_height_near_failed",{reason=tostring(second),x=xy.x,y=xy.y})
                end
            end)
        end
        -- A player in flight is not a usable ground-layer seed. Search
        -- measured mesh layers at bounded intervals rather than retrying
        -- the same airborne Z. Never accept an unmeasured probe altitude.
        local ground_scan=nav.provider_name and nav.provider_name()=="arthas_nav"
            and type(client.get_height_near)=="function"
        if ground_scan and not request.height and request.near_started then
            if request.probe_pending and core.time()-request.probe_started>=2 then
                request.probe_pending=nil
            end
            local probes=request.ground_probes or 0
            if not request.probe_pending and probes<512 and core.time()>=(request.next_probe or 0) then
                probes=probes+1;request.ground_probes=probes
                local offset=math.ceil(probes/2)*8*(probes%2==1 and -1 or 1)
                local seed=request.seed_z+offset
                request.probe_pending=probes;request.probe_started=core.time();request.next_probe=core.time()+.25
                local serial=probes
                client:get_height_near(vec3.new(xy.x,xy.y,seed),function(h)
                    if request.probe_pending~=serial then return end
                    request.probe_pending=nil
                    if type(h)=="number" and h==h and math.abs(h)<100000 and math.abs(h-seed)<=6 then
                        request.height=h;request.complete=true
                        emit("destination_ground_layer_resolved",{quest_id=step.quest_id,x=xy.x,y=xy.y,z=h,probe=serial})
                    end
                end)
            end
        end
        if request.height then
            if destination_height_queries[height_key]==request then destination_height_queries[height_key]=nil end
            return {x=xy.x,y=xy.y,z=request.height,_mesh_height=true}
        end
        local height_terminal=(request.complete and (request.near_started or type(client.get_height_near)~="function"))
        if ground_scan and not request.height and (request.ground_probes or 0)<512
            and core.time()-request.started<180 then return nil,"resolving_destination" end
        if height_terminal or core.time()-request.started>15 then
            if profile and profile.persistent_navigation then
                if not request.retry_at then
                    step.height_failures=(step.height_failures or 0)+1
                    request.retry_at=core.time()+math.min(60,5*2^math.min(4,step.height_failures-1))
                    if step.height_failures>=2 and #(step.checkpoints or {})>1 then
                        step.height_checkpoint=(step.height_checkpoint or 1)%#step.checkpoints+1
                        step.map_position=step.checkpoints[step.height_checkpoint]
                        emit("destination_checkpoint_changed",{quest_id=step.quest_id,index=step.height_checkpoint})
                    end
                    emit("destination_height_retry",{quest_id=step.quest_id,source_index=step.source_index,x=xy.x,y=xy.y})
                elseif core.time()>=request.retry_at then
                    if destination_height_queries[height_key]==request then destination_height_queries[height_key]=nil end
                    step.height_query=nil
                end
                return nil,"resolving_destination"
            end
            if destination_height_queries[height_key]==request then destination_height_queries[height_key]=nil end
            return nil,"mesh_height_unavailable"
        end
        return nil,"resolving_destination"
    end
    a.time = core.time
    a.readiness_reason=function()
        if not nav.client() then
            for part,providers in ipairs(nav.diagnostic_rows()) do
                emit("navigation_provider_diagnostic",{part=part,providers=providers})
            end
            for part,providers in ipairs(nav.diagnostic_rows("farmer")) do
                emit("master_farmer_provider_diagnostic",{part=part,providers=providers})
            end
            return "arthas_not_loaded"
        end
        if not nav.available() then return "navigation_server_unavailable" end
        if type(core.quests.get_open_quest_info)~="function" then return "quest_panel_api_unavailable" end
    end
    local health_next=0
    a.ready = function()
        local p = player()
        local client=nav.client and nav.client()
        if client and not nav.available() and type(client.health_check)=="function" and core.time()>=health_next then
            health_next=core.time()+5;client:health_check(function(ok) emit("navigation_health_check",{success=ok}) end)
        end
        return p and p:is_valid() and nav.available()
            and type(core.quests.get_open_quest_info) == "function"
    end
    a.level = function() local p=player();return p and p:is_valid() and p:get_level() or 0 end
    a.dead = function() local p=player();return p and p:is_valid() and (p:is_dead() or p:is_ghost()) or false end
    a.in_combat = function() local p=player();return p and p:is_valid() and p:is_in_combat() or false end
    a.world_map_id=core.get_map_id
    a.subzone_name=function()
        if type(core.get_subzone_name)=="function" then return core.get_subzone_name() end
    end
    a.subzone_matches=function(area_id)
        local expected=bridge.area_names[tonumber(area_id)]
        local current=type(core.get_subzone_name)=="function" and core.get_subzone_name() or nil
        if not expected or not current or current=="" then return nil end
        return current:lower()==expected:lower()
    end
    a.instance_id=core.get_instance_id
    local last_player_position={x=0,y=0,z=0}
    local movement=MovementWatch.new({time=core.time,map=core.get_map_id,instance=core.get_instance_id,log=log,
        position=function() local p=player();if p and p:is_valid() then last_player_position=p:get_position() end;return last_player_position end,
        paused=function() local p=player();return not p or not p:is_valid() or p:is_in_combat() or p:is_casting_spell() or nav.is_planning and nav.is_planning() end,
        mounted=function() local p=player();return p and p:is_valid() and p:is_mounted() or false end,
        flying=function() local p=player();return p and p:is_valid() and p:is_flying() or false end,
        dismount=core.input.dismount,stop=nav.stop,replan=nav.replan,detour=nav.detour,strafe=nav.strafe,native_state=nav.state,
        path=function() local c=nav.client and nav.client();return c and c:get_current_path() or nil end,
        path_index=function() local c=nav.client and nav.client();return c and c.get_path_index and c:get_path_index() or nil end,
        corridor_widths=function() local c=nav.client and nav.client();return c and c.get_corridor_widths and c:get_corridor_widths() or nil end,
        lock_corridor=function() return not nav.owns_ground_windows() end,
        move_leg=function(position,callback) nav.move_direct(vec3.new(position.x,position.y,position.z),callback) end,
        move=function(position,callback) nav.move(vec3.new(position.x,position.y,position.z),callback) end,
        move_direct=function(position,callback) nav.move_direct(vec3.new(position.x,position.y,position.z),callback) end})
    a.stop=function()
        pull_epoch=pull_epoch+1;pull_moving=nil
        if world_transport_job and world_transport_job.approaching then
            world_transport_job.approaching=nil
            world_transport_job.approach_epoch=(world_transport_job.approach_epoch or 0)+1
            world_transport_job.next=core.time()+3
        end
        if flight and flight.job then flight:stop() end
        a.taught_epoch=(a.taught_epoch or 0)+1
        movement:stop()
    end
    a.move=function(position,callback)
        local Learning=require("path_learning")
        local id=profile and profile.id or "unknown"
        local c={world_map_id=safe_read("world_map",core.get_map_id,0),instance_id=safe_read("instance",core.get_instance_id,0),
            ui_map_id=safe_read("ui_map",core.game_ui.get_current_map_id,0)}
        local route=Learning.match(Learning.load(Learning.runtime_api(),id),c,player():get_position(),position)
        if not route then return movement:move(position,callback) end
        a.taught_epoch=(a.taught_epoch or 0)+1;local epoch=a.taught_epoch
        emit("taught_path_reused",{profile=id,points=#route})
        local index=0
        local function advance(ok,why)
            if epoch~=a.taught_epoch then return end
            if ok==false then if callback then callback(false,why) end;return end
            index=index+1
            if index>#route then if callback then callback(true,"arrived") end;return end
            movement:move(vec3.new(route[index].x,route[index].y,route[index].z),advance)
        end
        advance(true)
    end
    a.move_direct=function(position,callback) movement:move(position,callback,true) end
    a.movement_tick=function() movement:tick() end
    a.ground_path=function()
        local sequence=movement.active and movement.active.sequence
        if sequence then return sequence.points,sequence.index end
    end
    a.movement_fault=function() return movement.fault end
    a.reset_movement_fault=function() movement.fault=nil end
    local death_job,death_count,death_next=nil,0,0
    a.recover_death=function()
        local p=player();local now=core.time()
        if not death_job then
            death_count=death_count+1
            if death_count>3 and not (profile and profile.persistent_navigation) then return "blocked:repeated_deaths" end
            a.stop();death_job={since=now};emit("death_recovery_started",{attempt=death_count})
        end
        if now-death_job.since>180 and not (profile and profile.persistent_navigation) then a.stop();return "blocked:corpse_recovery_timeout" end
        if not p:is_ghost() then
            if now>=death_next then
                death_next=now+2
                local ran,result=pcall(core.input.release_spirit)
                if not ran or result==false then
                    emit("death_release_rejected",{error=not ran and tostring(result) or nil})
                else
                    emit("death_release_requested")
                end
            end
            return "releasing_spirit"
        end
        local corpse=safe_read("corpse_position",core.game_ui.get_corpse_position,nil)
        if not corpse or type(corpse.x)~="number" or type(corpse.y)~="number" or type(corpse.z)~="number"
            or corpse.x==0 and corpse.y==0 and corpse.z==0 then
            return "waiting_for_corpse_position"
        end
        if distance(p:get_position(),corpse)<=25 then
            a.stop()
            if (tonumber(safe_read("corpse_resurrect_delay",core.game_ui.get_resurrect_corpse_delay,1)) or 1)<=0 and now>=death_next then
                death_next=now+2
                local ran,result=pcall(core.input.resurrect_corpse)
                if not ran or result==false then
                    emit("corpse_resurrect_rejected",{error=not ran and tostring(result) or nil})
                else
                    emit("corpse_resurrect_requested")
                end
            end
            return "resurrecting_at_corpse"
        end
        if not death_job.moving and now>=(death_job.retry_at or 0) then
            death_job.failed=nil
            death_job.moving=true;local job=death_job
            emit("corpse_navigation_requested",{attempt=(job.retries or 0)+1,x=corpse.x,y=corpse.y,z=corpse.z})
            a.move(corpse,function(ok,reason)
                if death_job==job then
                    job.moving=nil
                    if not ok then
                        job.failed=true;job.retries=(job.retries or 0)+1;job.retry_at=core.time()+math.min(15,2*job.retries)
                        emit("corpse_navigation_retry",{reason=reason,attempt=job.retries,delay=math.min(15,2*job.retries)})
                    end
                end
            end)
        end
        movement:tick()
        if death_job.failed then
            if profile and profile.persistent_navigation then return "retrying_corpse_route" end
            return "blocked:corpse_unreachable"
        end
        return "walking_to_corpse"
    end
    a.after_death=function(step,count)
        if not step then return end
        step.position=nil;step.height_query=nil;step.search_state=nil;step.search_query=nil
        step.dynamic_action_ready=nil;step.target_scan=nil
        local points=step.checkpoints or {}
        if #points>1 then
            local index=(math.max(1,count)-1)%#points+1
            step.map_position=points[index]
            emit("death_hotspot_rotated",{quest_id=step.quest_id,attempt=count,checkpoint=index,count=#points})
        else emit("death_step_rebuilt",{quest_id=step.quest_id,attempt=count}) end
    end
    a.area=function()
        local p=player()
        return {world_map_id=safe_read("world_map",core.get_map_id,0),instance_id=safe_read("instance",core.get_instance_id,0),
            name=safe_read("map_name",core.get_map_name,"Unknown"),ui_map_id=safe_read("ui_map",core.game_ui.get_current_map_id,0),
            outdoors=safe_read("player_outdoors",function() return p:is_outdoors() end,false),
            flying=safe_read("player_flying",function() return p:is_flying() end,false),
            mounted=safe_read("player_mounted",function() return p:is_mounted() end,false)}
    end
    local talent_manager=Talents.new({player=player,time=core.time,ui=core.game_ui,spec=function()
        local p=player();return Specialization.resolve(p and p:get_class(),safe_read("spellbook_specialization",core.spell_book.get_specialization_id,nil),
            safe_read("ui_specialization",core.game_ui.get_specialization,nil))
    end},log,profile)
    local sky_names,sky_refresh={},0
    local function sky_spell(name)
        if core.time()>=sky_refresh then
            sky_refresh=core.time()+10;sky_names={}
            for key,value in pairs(core.spell_book.get_spells and core.spell_book.get_spells() or {}) do
                local id=type(value)=="number" and value or type(key)=="number" and key
                if id then local n=type(value)=="string" and value or core.spell_book.get_spell_name(id);if n then sky_names[n]=id end end
            end
        end
        return sky_names[name]
    end
    local forever=profile and profile.game_version=="Forever"
    if not forever and core.spell_book and core.spell_book.get_gliding_info and core.spell_book.get_spell_charge and core.spell_book.get_spell_name
        and core.spell_book.is_spell_known and nav.flight_corridor and nav.flight_clear and nav.flight_landing
        and core.world and core.world.is_advanced_flyable_area and core.input.jump and core.input.ascend_stop
        and core.input.move_forward_start and core.input.move_forward_stop and core.input.look_at and core.input.cast_target_spell then
        flight=Sky.new({player=player,time=core.time,map=core.get_map_id,instance=core.get_instance_id,
            gliding=core.spell_book.get_gliding_info,flyable=core.world.is_advanced_flyable_area,
            steady_flyable=function() return core.world.is_flyable_area and core.world.is_flyable_area()==true end,
            steady_mount=function()
                if not core.spell_book.get_mount_count or not core.spell_book.get_mount_info then return false end
                for i=1,core.spell_book.get_mount_count() do
                    local m=core.spell_book.get_mount_info(i)
                    if m and m.is_active then return m.mount_type==248 or m.mount_type==402 or m.mount_type==424 end
                end
                return false
            end,
            corridor=nav.flight_corridor,clear=nav.flight_clear,landing=nav.flight_landing,
            forward_start=core.input.move_forward_start,forward_stop=core.input.move_forward_stop,
            jump=core.input.jump,ascend_stop=core.input.ascend_stop,spell=sky_spell,
            known=core.spell_book.is_spell_known,charges=core.spell_book.get_spell_charge,
            cast=core.input.cast_target_spell,face=function(point) return core.input.look_at(vec3.new(point.x,point.y,point.z)) end},log)
    end
    a.aerial_path=function()
        if not flight or not flight.job then return nil end
        return flight:get_current_path(),flight:get_path_index()
    end
    local aerial_policy=require("aerial_policy").new({time=core.time,map=core.get_map_id},log)
    local flight_goal
    local travel_mode
    local function report_mode(mode)
        if mode~=travel_mode then travel_mode=mode;emit("travel_mode",{mode=mode}) end
    end
    local mount_next,mount_pending,mount_settle=0,nil,nil
    local mount_attempts,mount_failed=0,{}
    local landing_probe_next,landing_probe_log=0,0
    local sky_decision_next=0
    local TravelDecision=require("travel_decisions")
    local mode_observer=TravelDecision.observer()
    local mode_floor_next,mode_floor=0,nil
    local soar=require('soar_travel').new({time=core.time,
        airborne=function() local p=player();local g=core.spell_book.get_gliding_info and core.spell_book.get_gliding_info();return p:is_flying() or g and g.is_gliding end,
        known=function(id) return core.spell_book.is_spell_known and core.spell_book.is_spell_known(id)==true end,
        usable=function(id) return core.spell_book.is_usable_spell and core.spell_book.is_usable_spell(id)==true end,
        moving=function() local p=player();return p.is_moving and p:is_moving() end,
        casting=function() local p=player();return p:is_casting_spell() or p:is_channelling_spell() end,
        corridor=function(goal) return nav.flight_corridor and nav.flight_corridor(player():get_position(),goal) end,
        stop=function() a.stop() end,cast=function(id) return core.input.cast_target_spell(id,player()) end,
        log=function(event) emit(event,{spell_id=369536}) end})
    a.prepare_travel=function(step)
        local p=player()
        local now=core.time()
        if step.no_mount then mount_pending=nil;mount_settle=nil end
        if flight and flight.job then
            local current_glide=core.spell_book.get_gliding_info()
            report_mode(current_glide and current_glide.is_gliding and "skyriding" or p:is_flying() and "steady_flying" or p:is_mounted() and "ground_mounted" or "walking")
            local local_landing=flight.job.landing_only
            local state=flight:tick()
            if state=="complete" then
                if local_landing then aerial_policy:landed(flight_goal,p:get_position())
                else aerial_policy:succeeded(flight_goal) end
                flight_goal=nil;return "aerial_route_finished"
            end
            if state=="failed" then aerial_policy:failed(flight_goal,"flight_controller_failed");flight_goal=nil;return "aerial_route_finished" end
            return state
        end
        if mount_pending then
            if p:is_mounted() then mount_pending=nil;mount_attempts=0;mount_failed={};emit("mount_confirmed")
            elseif p:is_in_combat() then mount_pending=nil;mount_next=now+15
            elseif now<mount_pending.deadline then return "waiting_for_mount"
            else
                mount_failed[mount_pending.index]=true;mount_pending=nil
                emit("mount_attempt_timeout",{attempt=mount_attempts})
                if mount_attempts>=3 then mount_next=now+30;mount_attempts=0;mount_failed={}
                else mount_next=0 end
            end
        end
        if mount_settle then
            if p:is_in_combat() or not p:is_outdoors() or core.character.is_swimming() or p:is_mounted() then mount_settle=nil
            elseif now<mount_settle.ready or p.is_moving and p:is_moving() then
                a.stop()
                if now-mount_settle.started>5 then
                    emit("mount_stop_timeout");mount_settle=nil;mount_next=now+10;return
                end
                return "stopping_before_mount"
            elseif p:is_casting_spell() or p:is_channelling_spell() then return "mount_casting"
            else
                local job=mount_settle;mount_settle=nil;mount_attempts=mount_attempts+1
                emit("mount_requested",{index=job.index,spell_id=job.info.spell_id,mount_type=job.info.mount_type,attempt=mount_attempts})
                local ran,result=pcall(core.input.mount,job.index)
                if not ran or result==false then
                    mount_failed[job.index]=true
                    emit("mount_request_rejected",{index=job.index,attempt=mount_attempts,reason=ran and "client_refused" or tostring(result)})
                    if mount_attempts>=3 then mount_next=now+30;mount_attempts=0;mount_failed={}
                    else mount_next=now+1 end
                    return "mount_failed"
                end
                mount_pending={index=job.index,deadline=now+8};mount_next=now+10
                return "mounting"
            end
        end
        local glide=core.spell_book and core.spell_book.get_gliding_info and core.spell_book.get_gliding_info()
        local measured
        if glide and glide.is_gliding and not p:is_flying() and nav and nav.measured_height then
            if now>=mode_floor_next then mode_floor_next=now+.25;mode_floor=nav.measured_height(p:get_position()) end
            measured=mode_floor
        end
        local mode,stable=mode_observer:update(TravelDecision.mode(p,glide,measured),now)
        report_mode(mode)
        if not stable then movement:stop();return "travel_mode_confirming" end
        local remaining=distance(p:get_position(),step.position)
        local ground_blocked=nav and nav.ground_blocked and nav.ground_blocked(step.position)
        local soar_preferred=require('soar_travel').preferred(remaining,
            core.spell_book and core.spell_book.is_spell_known and core.spell_book.is_spell_known(369536),ground_blocked)
        local sky_allowed=flight and not forever and not step.no_skyriding and (soar_preferred or ground_blocked and remaining>8 or require('route_policy').prefer_flight(remaining,
                p.get_movement_speed_max and p:get_movement_speed_max(),p.get_flight_speed_max and p:get_flight_speed_max(),not p:is_flying()))
            and p:is_outdoors() and not p:is_in_combat() and not core.character.is_swimming()
            and (not profile or profile.auto_skyriding~=false) and (core.world.is_advanced_flyable_area() or core.world.is_flyable_area and core.world.is_flyable_area())
            and aerial_policy:can_attempt(step.position)
        if mode=="skyriding" or mode=="steady_flying" then
            soar:prepare(step.position,false)
            if a.movement_owner then a.movement_owner('flight') end
            -- An unavailable collision probe is a recoverable observation,
            -- not a reason to disable the quest controller. Retry at a bounded
            -- rate and re-evaluate airborne state on every update.
            movement:stop()
            if now>=landing_probe_next then
                landing_probe_next=now+3
                if sky_allowed then
                    local started,start_reason=flight:start(step.position)
                    if started then flight_goal=step.position;return 'skyriding_cruise' end
                    if start_reason=='corridor_pending' then return 'flight_geometry_pending' end
                    aerial_policy:failed(step.position,start_reason or 'start_rejected')
                end
                if flight and flight:land() then flight_goal=step.position;return "skyriding_landing" end
                if now>=landing_probe_log then
                    landing_probe_log=now+10
                    emit("aerial_landing_probe_wait",{quest_id=step.quest_id,retry_seconds=3})
                end
            end
            return "landing_probe_wait"
        end
        landing_probe_next=0
        if now>=sky_decision_next then
            sky_decision_next=now+10
            local reason=sky_allowed and "eligible" or not flight and "flight_api_unavailable"
                or forever and "forever_flight_disabled" or step.no_skyriding and "step_requires_ground"
                or profile and profile.auto_skyriding==false and "disabled_in_profile"
                or p:is_in_combat() and "combat" or not p:is_outdoors() and "indoors"
                or core.character.is_swimming() and "swimming"
                or not (core.world.is_advanced_flyable_area() or core.world.is_flyable_area and core.world.is_flyable_area()) and "area_not_flyable"
                or not aerial_policy:can_attempt(step.position) and "corridor_retry_cooldown"
                or "short_trip_cost"
            emit("skyriding_travel_decision",{distance=remaining,eligible=sky_allowed==true,reason=reason,
                mounted=p:is_mounted(),can_glide=glide and glide.can_glide,
                soar_known=core.spell_book and core.spell_book.is_spell_known and core.spell_book.is_spell_known(369536),
                soar_preferred=soar_preferred,ground_blocked=ground_blocked})
        end
        if sky_allowed and nav and nav.flight_corridor then
            local corridor,reason=nav.flight_corridor(p:get_position(),step.position)
            if not corridor and reason=='corridor_pending' then return 'flight_geometry_pending' end
        end
        -- Prefer innate Soar over an existing ground mount only with a verified corridor.
        if sky_allowed and soar_preferred and p:is_mounted() and soar:can_prepare_after_dismount()
            and nav.flight_corridor and nav.flight_corridor(p:get_position(),step.position) then
            a.stop()
            if now>=mount_next then
                local ran,result=pcall(core.input.dismount)
                mount_next=now+3
                emit("soar_dismount_requested",{accepted=ran and result~=false})
            end
            return "dismounting_for_soar"
        end
        local soar_state=soar:prepare(step.position,sky_allowed and not p:is_mounted())
        if soar_state and soar_state~='ready' then return soar_state end
        -- Keep short NPC and quest-object approaches on foot. Mounting here
        -- expands the collision envelope at doors, fences and tight slopes.
        local far=remaining>70
        local needs_foot=step.no_mount or remaining<=8 or not p:is_outdoors() or core.character.is_swimming()
        if p:is_mounted() and needs_foot then
            a.stop();if core.time()>=mount_next then
                emit("dismount_requested")
                local ran,result=pcall(core.input.dismount)
                if not ran or result==false then emit("dismount_request_rejected",{reason=ran and "client_refused" or tostring(result)}) end
                mount_next=core.time()+3
            end
            return "dismounting"
        end
        if p:is_mounted() and sky_allowed and not needs_foot and not p:is_in_combat() and flight and not step.no_skyriding
            and aerial_policy:can_attempt(step.position) and (not profile or profile.auto_skyriding~=false) then
            -- A rejected corridor must leave the active Sentinel ground job intact.
            -- Claim flight only after a checked corridor exists; failed probes
            -- must not cancel a still-valid ground route.
            local started,start_reason=flight:start(step.position)
            if started then
                if a.movement_owner then a.movement_owner('flight') end
                flight_goal=step.position;movement:stop();return "skyriding_takeoff"
            end
            if start_reason=='corridor_pending' then return 'flight_geometry_pending' end
                    aerial_policy:failed(step.position,start_reason or 'start_rejected')
        end
        if not far or p:is_mounted() or needs_foot or p:is_in_combat() then return end
        if profile and profile.auto_mount==false then return end
        if movement.recovery_until and core.time()<movement.recovery_until then return end
        if p:is_casting_spell() then return "mount_casting" end
        if core.time()<mount_next then return end
        local count=core.spell_book.get_mount_count()
        local selected,selected_info,best_score
        -- Retail grants Skyriding from level 10 after the account unlock. The
        -- live can_glide check remains the final authority at takeoff.
        local prefer_sky=flight and not step.no_skyriding and p:get_level()>=10 and (not profile or profile.auto_skyriding~=false)
            and core.world.is_advanced_flyable_area()
        for i=1,count do
            local m=core.spell_book.get_mount_info(i)
            if m and m.is_usable and require("mount_selection").allowed(m,forever) and not mount_failed[i] then
                local score=require("mount_selection").score(m,prefer_sky)
                if not selected or score>best_score then selected,selected_info,best_score=i,m,score end
            end
        end
        if not selected and mount_attempts>0 and mount_attempts<3 then
            mount_failed={}
            for i=1,count do local m=core.spell_book.get_mount_info(i);if m and m.is_usable and require("mount_selection").allowed(m,forever) then selected,selected_info=i,m;break end end
        end
        if selected then
            a.stop();mount_settle={index=selected,info=selected_info,started=now,ready=now+0.5}
            emit("mount_stopping",{index=selected,distance=remaining});return "stopping_before_mount"
        end
        mount_next=now+10;emit("mount_unavailable",{count=count,distance=remaining})
    end
    a.turned_in=quest_completed
    a.on_quest=quest_accepted
    a.money=function() return safe_read("gold",core.inventory and core.inventory.get_gold,0) or 0 end
    local function quest_log_count() return math.max(0,tonumber(safe_read("quest_log_count",core.quests.get_num_quest_log_entries,0)) or 0) end
    local function quest_log_title(index) return safe_read("quest_log_title",core.quests.get_quest_log_title,nil,index) end
    local function quest_objective_count(index) return math.max(0,tonumber(safe_read("quest_objective_count",core.quests.get_num_quest_leader_boards,0,index)) or 0) end
    local function quest_objective(index,quest_index) return safe_read("quest_objective",core.quests.get_quest_log_leader_board,nil,index,quest_index) end
    a.level_progress=function()
        local level=a.level and a.level() or 0
        if not core.character or type(core.character.get_xp)~="function" or type(core.character.get_xp_max)~="function" then return nil end
        local ok_xp,xp=pcall(core.character.get_xp);local ok_max,xp_max=pcall(core.character.get_xp_max)
        if not ok_xp or not ok_max or not xp_max or xp_max<=0 then return level>0 and level or nil end
        return level+(tonumber(xp) or 0)/xp_max
    end
    a.quest_failed=function(id)
        if not id then return false end
        if bridge.failed_quests[id] then return true end
        for i=1,quest_log_count() do
            local q=quest_log_title(i)
            if q and q.quest_id==id then return tonumber(q.is_complete)==-1 end
        end
        return false
    end
    a.restart_failed_quest=function(id)
        if not a.quest_failed(id) or type(core.quests.abandon_quest_by_id)~="function" then return false end
        local ok,result=pcall(core.quests.abandon_quest_by_id,id)
        local sent=ok and result==true
        local failure
        if not ok then failure=tostring(result) end
        emit("failed_quest_abandon_requested",{quest_id=id,accepted=sent,error=failure})
        return sent
    end
    local inventory_next,inventory_counts=0,{}
    a.item_goal_count=function(goal)
        if core.time()>=inventory_next then
            inventory_next=core.time()+1;inventory_counts={}
            local ok,helper=pcall(require,"common/utility/inventory_helper")
            if ok and helper and helper.get_character_bag_slots then
                local read,slots=pcall(function() return helper:get_character_bag_slots() end)
                if read then inventory_counts.slots=slots end
            end
        end
        return QuestInventory.count(inventory_counts.slots,goal.item_id)
    end
    a.item_goal_done=function(goal)
        local count=a.item_goal_count(goal)
        if count==nil then return nil end
        local flags=tonumber(goal.flags) or 0
        local function has(mask) return math.floor(flags/mask)%2==1 end
        local quest_id=tonumber(goal.quest_id)
        if quest_id then
            if not has(16) and a.turned_in(quest_id) then return true end
            if tonumber(goal.objective_mask)==0 and a.on_quest(quest_id) then return true end
            if live_objectives then
                local ok,rows=pcall(live_objectives,quest_id)
                if ok and type(rows)=="table" then
                    local selected,fulfilled,finished=0,0,true
                    local mask=tonumber(goal.objective_mask) or 0
                    for index,objective in ipairs(rows) do
                        if mask>0 and math.floor(mask/(2^(index-1)))%2==1 then
                            selected=selected+1
                            fulfilled=fulfilled+(tonumber(objective.fulfilled) or 0)
                            if not objective.finished then finished=false end
                        end
                    end
                    if has(4) and selected>0 and finished then return true end
                    if has(2) and selected>0 then
                        local required=math.max(0,(tonumber(goal.count) or 1)-fulfilled*(tonumber(goal.multiplier) or 1))
                        return count>=required
                    end
                end
            end
        end
        local wanted=tonumber(goal.count) or 1
        local operator=tonumber(goal.operator) or 0
        if operator<0 then return goal.inclusive and count<=wanted or count<wanted end
        if operator>0 then return goal.inclusive and count>=wanted or count>wanted end
        return count==wanted
    end
    local scenario_event_epoch=0
    a.progress_token=function(step)
        if not step then return nil end
        local parts={};local value=0;local valued=false
        local function relevant(j)
            if step.objective_indices then for _,id in ipairs(step.objective_indices) do if tonumber(id)==j then return true end end;return false end
            return not step.objective_index or tonumber(step.objective_index)==j
        end
        if step.item_goal and step.item_goal.item_id then
            local count=a.item_goal_count(step.item_goal)
            if count~=nil then parts[#parts+1]="item:"..tostring(count);value=value+count;valued=true end
        end
        local direct_objectives=false
        if step.quest_id and live_objectives then
            local ok,rows=pcall(live_objectives,step.quest_id)
            if ok and type(rows)=="table" and #rows>0 then
                direct_objectives=true
                for j,objective in ipairs(rows) do
                    if relevant(j) then
                    local fulfilled=tonumber(objective.fulfilled) or 0
                    local required=tonumber(objective.required) or 0
                    parts[#parts+1]=table.concat({j,objective.finished and 1 or 0,fulfilled,required,
                        tostring(objective.type or ""),tostring(objective.text or "")},":")
                    value=value+fulfilled+(objective.finished and required==0 and 1 or 0);valued=true
                    end
                end
            end
        end
        if not direct_objectives and step.quest_id and core.quests.get_num_quest_log_entries
            and core.quests.get_quest_log_title and core.quests.get_num_quest_leader_boards
            and core.quests.get_quest_log_leader_board then
            local ok=pcall(function()
                for i=1,quest_log_count() do
                    local q=quest_log_title(i)
                    if q and q.quest_id==step.quest_id then
                        for j=1,quest_objective_count(i) do
                            local objective=quest_objective(j,i)
                            if objective and relevant(j) then
                                local description=tostring(objective.description or "")
                                parts[#parts+1]=table.concat({j,objective.is_completed and 1 or 0,
                                    description},":")
                                local have=description:match("(%d+)%s*/%s*%d+")
                                if have then value=value+tonumber(have);valued=true
                                elseif objective.is_completed then value=value+1;valued=true end
                            end
                        end
                        break
                    end
                end
            end)
            if not ok then return #parts>0 and table.concat(parts,"|") or nil end
        end
        if step.action=="scenario" then
            parts[#parts+1]="scenario:"..tostring(scenario_event_epoch)..":"..tostring(bridge_scenario_completion_epoch)
            value=value+scenario_event_epoch+bridge_scenario_completion_epoch;valued=true
        end
        return #parts>0 and table.concat(parts,"|") or nil,valued and value or nil
    end
    a.objective_done = function(id, index, indices)
        -- Current Retail cores expose the game's authoritative whole-quest
        -- completion state. This covers hidden, scripted, progress-bar, and
        -- zero-leaderboard objectives that the legacy row reader cannot see.
        if core.quests.is_quest_complete then
            local ok,complete=pcall(core.quests.is_quest_complete,id)
            if ok and complete==true then return true end
        end
        if live_objectives then
            local ok,rows=pcall(live_objectives,id)
            if ok and type(rows)=="table" and #rows>0 then
                return QuestObjectives.done(indices or (index and {index}),#rows,function(j)
                    local objective=rows[j]
                    if not objective then return nil end
                    return {description=objective.text,is_completed=objective.finished==true,
                        fulfilled=objective.fulfilled,required=objective.required,objective_type=objective.type}
                end)
            end
        end
        for i=1,quest_log_count() do
            local q = quest_log_title(i)
            if q and q.quest_id == id then
                local count = quest_objective_count(i)
                return QuestObjectives.done(indices or (index and {index}),count,function(j)
                    return quest_objective(j,i)
                end)
            end
        end
        return false
    end
    local function normalized_words(value)
        local words={}
        for word in tostring(value or ""):lower():gmatch("[%a%d]+") do
            if #word>2 and word~="the" and word~="and" and word~="with" then words[word]=true end
        end
        return words
    end
    local function text_match(left,right)
        local a_words,b_words=normalized_words(left),normalized_words(right);local common,total=0,0
        for word in pairs(a_words) do total=total+1;if b_words[word] then common=common+1 end end
        return total>0 and common>=math.min(2,total)
    end
    local scenario_completion_epoch=0
    local cast_signals=require("cast_signals").new()
    a.scenario_done=function(step)
        local wanted=step.scenario_text or step.title
        local live=bridge.scenario
        step.bridge_scenario_origin_completion=step.bridge_scenario_origin_completion or bridge_scenario_completion_epoch
        if bridge_scenario_completion_epoch>step.bridge_scenario_origin_completion then
            emit("scenario_completed",{source="companion_bridge",title=wanted});return true
        end
        if step.scenario_stage_id and live.stage_id==step.scenario_stage_id then
            local criterion=live.criteria and live.criteria[step.scenario_criterion_index or 1]
            if criterion then
                step.scenario_signal_seen=true
                local required=step.scenario_required or criterion.total or 1
                if criterion.complete or (criterion.quantity or 0)>=required then
                    emit("scenario_completed",{source="companion_exact_criteria",stage_id=live.stage_id,
                        criterion=step.scenario_criterion_index,quantity=criterion.quantity,required=required});return true
                end
            end
        end
        for _,criterion in pairs(live.criteria or {}) do
            if text_match(wanted,criterion.description) then
                step.scenario_signal_seen=true
                if criterion.complete then emit("scenario_completed",{source="companion_criteria",title=wanted});return true end
            end
        end
        step.scenario_origin_event=step.scenario_origin_event or scenario_event_epoch
        step.scenario_origin_completion=step.scenario_origin_completion or scenario_completion_epoch
        if scenario_completion_epoch>step.scenario_origin_completion then
            emit("scenario_completed",{source="game_event",title=wanted});return true
        end
        if scenario_event_epoch>step.scenario_origin_event then step.scenario_signal_seen=true end
        step.scenario_origin_map=step.scenario_origin_map or core.get_map_id()
        step.scenario_origin_instance=step.scenario_origin_instance or core.get_instance_id()
        if step.scenario_signal_seen and (core.get_map_id()~=step.scenario_origin_map or core.get_instance_id()~=step.scenario_origin_instance) then
            emit("scenario_completed",{source="verified_world_transition",title=wanted});return true
        end
        local rx=core.addons and core.addons.rested_xp
        if rx and rx.is_loaded and rx.is_loaded() and rx.has_current_step and rx.has_current_step() then
            local rows={rx.get_current_step()};for _,row in ipairs(rx.get_current_stickies() or {}) do rows[#rows+1]=row end
            for _,row in ipairs(rows) do
                for _,goal in ipairs(row.goals or {}) do
                    if text_match(wanted,goal.text) then
                        step.scenario_signal_seen=true
                        if goal.is_complete then emit("scenario_completed",{source="restedxp",title=wanted});return true end
                    end
                end
            end
        end
        local z=core.addons and core.addons.zygor
        if z and z.is_loaded and z.is_loaded() and z.has_current_step and z.has_current_step() then
            local rows={z.get_current_step()};for _,row in ipairs(z.get_current_stickies() or {}) do rows[#rows+1]=row end
            for _,row in ipairs(rows) do
                for _,goal in ipairs(row.goals or {}) do
                    local label=goal.target or goal.npc or ""
                    if text_match(wanted,label) then
                        step.scenario_signal_seen=true
                        if goal.is_complete then emit("scenario_completed",{source="zygor",title=wanted});return true end
                    end
                end
            end
        end
        for i=1,quest_log_count() do
            local count=quest_objective_count(i)
            for j=1,count do
                local objective=quest_objective(j,i)
                if objective and text_match(wanted,objective.description) then
                    step.scenario_signal_seen=true
                    if objective.is_completed then emit("scenario_completed",{source="hidden_quest",title=wanted});return true end
                end
            end
        end
        if core.time()>=(step.scenario_log_at or 0) then
            step.scenario_log_at=core.time()+5
            emit("scenario_completion_wait",{title=wanted,restedxp=rx and rx.is_loaded and rx.is_loaded() or false,
                zygor=z and z.is_loaded and z.is_loaded() or false,matching_signal_seen=step.scenario_signal_seen==true})
        end
        return false
    end
    a.scenario_id=function() return bridge.scenario and bridge.scenario.scenario_id end
    a.achievement_complete=function(id,criterion)
        return bridge.achievements[tostring(id)..":"..tostring(criterion or 0)]
    end
    a.player_choice_complete=function(id) return bridge.choices[tonumber(id)]==true end
    a.aura_matches=function(id,min_remaining)
        for _,list in ipairs({player():get_buffs() or {},player():get_debuffs() or {}}) do
            for _,aura in pairs(list) do
                local aura_id=tonumber(aura.buff_id or aura.spell_id or aura.id)
                if aura_id==tonumber(id) then
                    local expires=tonumber(aura.expiration_time or aura.expire_time or aura.end_time)
                    if not min_remaining or min_remaining<=0 or not expires or expires-core.time()>min_remaining then return true end
                end
            end
        end
        return false
    end
    a.quest_count=function(ids,ignore_turned_in)
        local count=0
        for _,id in ipairs(ids or {}) do
            if quest_accepted(id) or (not ignore_turned_in and quest_completed(id)) then count=count+1 end
        end
        return count
    end
    a.spell_known=function(id) return core.spell_book.is_spell_known(id)==true end
    a.train_spell=function(step)
        if core.spell_book.is_spell_known(step.train_spell_id) then return true end
        if core.time()<(step.train_retry_at or 0) then return false end
        step.train_retry_at=core.time()+2
        local wanted=core.spell_book.get_spell_name(step.train_spell_id)
        local trainer_count=math.max(0,tonumber(safe_read("trainer_service_count",core.quests.get_num_trainer_services,0)) or 0)
        for index=1,trainer_count do
            local info=safe_read("trainer_service_info",core.quests.get_trainer_service_info,nil,index)
            if info and wanted and info.spell_name==wanted then
                local ran,result=pcall(core.quests.buy_trainer_service,index)
                local accepted=ran and result~=false
                emit("trainer_service_requested",{spell_id=step.train_spell_id,index=index,accepted=accepted,
                    error=not ran and tostring(result) or nil});return false
            end
        end
        local obj,d=named_target(step,true)
        if obj and d<=4 then SafeInteraction.dispatch(core.input,obj,"interact") end
        return false
    end
    a.cast_observed=function(step)
        return cast_signals:observed(step)
    end
    local world_state_epoch=0
    a.transport_pending=function(step)
        return taxi_job and taxi_job.step==step and taxi_job.requested==true
            or world_transport_job and world_transport_job.step==step and world_transport_job.requested==true
    end
    a.event = function(event,args)
        interaction_tracker:event(event,args)
        if event=="CHAT_MSG_ADDON" then bridge_event(args) end
        if event=="CONFIRM_XP_LOSS" and core.input.accept_xp_loss then
            local ran,result=pcall(core.input.accept_xp_loss)
            emit("deathskip_spirit_healer_confirmed",{accepted=ran and result~=false,error=not ran and tostring(result) or nil})
        end
        if event=="QUEST_ACCEPT_CONFIRM" and core.quests.confirm_accept_quest then
            local quest_id=args and tonumber(args[3])
            local ran,result=pcall(core.quests.confirm_accept_quest)
            emit("escort_quest_accept_confirmed",{quest_id=quest_id,title=args and args[2],starter=args and args[1],
                accepted=ran and result~=false,error=not ran and tostring(result) or nil})
        elseif event=="LOOT_BIND_CONFIRM" and core.input.confirm_loot_slot then
            local client_slot=args and tonumber(args[1])
            if client_slot and client_slot>=1 then
                local ran,result=pcall(core.input.confirm_loot_slot,client_slot-1)
                emit("quest_loot_bind_confirmed",{client_slot=client_slot,loot_slot=client_slot-1,
                    accepted=ran and result~=false,error=not ran and tostring(result) or nil})
            end
        elseif event=="CONFIRM_BINDER" and core.input.confirm_binder then
            local ran,result=pcall(core.input.confirm_binder)
            emit("hearth_bind_confirmed",{binder=args and args[1],accepted=ran and result~=false,
                error=not ran and tostring(result) or nil})
        elseif (event=="AUTOEQUIP_BIND_CONFIRM" or event=="EQUIP_BIND_CONFIRM") and core.input.equip_pending_item then
            local pending
            if core.game_ui.get_pending_equip_slot then
                local read,value=pcall(core.game_ui.get_pending_equip_slot);if read then pending=value end
            end
            local slot=tonumber(pending) or args and tonumber(args[1])
            if slot then
                local ran,result=pcall(core.input.equip_pending_item,slot)
                emit("equip_bind_confirmed",{slot=slot,event=event,accepted=ran and result~=false,
                    error=not ran and tostring(result) or nil})
            end
        end
        -- Quest progress and world entry can swap the character into a new
        -- phase while map coordinates remain unchanged. Objective handlers
        -- use this epoch to discard object GUIDs and searches from that phase.
        if event=="QUEST_LOG_UPDATE" or event=="QUEST_LOG_CRITERIA_UPDATE"
            or event=="QUEST_WATCH_UPDATE" or event=="QUEST_ITEM_UPDATE"
            or event=="TASK_PROGRESS_UPDATE" or event=="PLAYER_ENTERING_WORLD"
            or event=="ZONE_CHANGED_NEW_AREA" then
            world_state_epoch=world_state_epoch+1
            if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then object_cache_at=-math.huge end
        end
        if event=="SCENARIO_UPDATE" or event=="SCENARIO_CRITERIA_UPDATE"
            or event=="SCENARIO_BONUS_OBJECTIVE_COMPLETE" then scenario_event_epoch=scenario_event_epoch+1 end
        if event=="SCENARIO_COMPLETED" then
            scenario_event_epoch=scenario_event_epoch+1;scenario_completion_epoch=scenario_completion_epoch+1
        end
        cast_signals:event(event,args)
        if taxi_job and taxi_job.requested then
            -- Control events are also raised by stuns and scripted sequences.
            -- They cannot prove that this taxi left or reached its destination.
            if event=="PLAYER_CONTROL_LOST" then taxi_job.control_lost=true end
            if event=="PLAYER_CONTROL_GAINED" and taxi_job.control_lost then taxi_job.control_returned=true end
        end
        if event=="QUEST_GREETING" then greeting_open=true
        elseif event=="QUEST_DETAIL" or event=="QUEST_PROGRESS" or event=="QUEST_COMPLETE" or event=="QUEST_FINISHED" or event=="GOSSIP_CLOSED" or event=="GOSSIP_SHOW" then greeting_open=false end
        if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then panel=event
        elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" or event == "GOSSIP_SHOW" then panel=nil end
    end
    a.travel_action=function(step)
        if step.travel_mode=="cast_spell_after_arrival" then
            if not step.travel_spell_id then return "blocked:travel_spell_id_missing" end
            if core.time()<(step.travel_item_retry_at or 0) then return "travel_spell_wait" end
            step.travel_item_retry_at=core.time()+5;a.stop()
            local ran,result=pcall(core.input.cast_target_spell,step.travel_spell_id,player())
            local accepted=ran and result==true
            emit("travel_spell_requested",{spell_id=step.travel_spell_id,accepted=accepted,error=not ran and tostring(result) or nil})
            return accepted and "complete" or "travel_spell_retry"
        elseif step.travel_mode=="use_item_after_arrival" or step.travel_mode=="use_item_until_buff" then
            if not step.travel_item_id then return "blocked:travel_item_id_missing" end
            if step.travel_mode=="use_item_until_buff" then
                for _,aura in pairs(player():get_buffs() or {}) do
                    for _,required in ipairs(step.required_buffs or {}) do
                        if aura.buff_id==required then
                            emit("travel_item_buff_observed",{quest_id=step.quest_id,buff_id=required})
                            return "complete"
                        end
                    end
                end
            end
            if core.time()<(step.travel_item_retry_at or 0) then return "travel_item_wait" end
            step.travel_item_retry_at=core.time()+3
            a.stop()
            local ran,result=pcall(core.input.use_item,step.travel_item_id)
            local accepted=ran and result==true
            emit("travel_item_requested",{quest_id=step.quest_id,item_id=step.travel_item_id,accepted=accepted,error=not ran and tostring(result) or nil})
            if accepted and step.travel_mode=="use_item_after_arrival" then return "complete" end
            if accepted then return "travel_item_buff_wait" end
            return "travel_item_retry"
        end
        if step.travel_mode=="portal" or step.travel_mode=="scheduled_transport" then
            local now=core.time();local p=player();local pos=p:get_position()
            if not world_transport_job or world_transport_job.step~=step then
                world_transport_job={step=step,origin={x=pos.x,y=pos.y,z=pos.z},origin_map=core.get_map_id(),next=0}
            end
            local job=world_transport_job
            -- WoW exposes no transport timetable. Confirm boarding from either
            -- an explicit vehicle/taxi state or repeated world displacement
            -- while the companion addon reports that the player is standing
            -- still. This avoids mistaking a missed boat for a 90-second trip.
            local bridge_player=bridge.player or {}
            if step.travel_mode=="scheduled_transport" then
                local explicit=bridge_player.taxi or bridge_player.in_vehicle or bridge_player.can_exit_vehicle
                    or bridge_player.vehicle_guid and bridge_player.vehicle_guid~=""
                if explicit and not job.boarded then
                    job.boarded=true;job.requested=true;job.boarded_at=now;job.deadline=now+180
                    emit("scheduled_transport_boarded",{evidence="client_state",taxi=bridge_player.taxi,
                        vehicle=bridge_player.in_vehicle,guid=bridge_player.vehicle_guid})
                end
                if bridge_player.epoch~=(job.observed_bridge_epoch or -1) then
                    job.observed_bridge_epoch=bridge_player.epoch
                    if job.motion_point then
                        local moved=distance(pos,job.motion_point)
                        if (bridge_player.speed or 0)<0.25 and moved>=2 then
                            job.carried_samples=(job.carried_samples or 0)+1
                        else
                            job.carried_samples=0
                        end
                    end
                    job.motion_point={x=pos.x,y=pos.y,z=pos.z}
                    if not job.boarded and (job.carried_samples or 0)>=2 then
                        job.boarded=true;job.requested=true;job.boarded_at=now;job.deadline=now+180
                        emit("scheduled_transport_boarded",{evidence="carried_motion",samples=job.carried_samples})
                    end
                end
            end
            local changed=core.get_map_id()~=job.origin_map or distance(pos,job.origin)>250
            if step.expected_map_id then changed=core.get_map_id()==step.expected_map_id end
            if changed then
                emit("world_transport_arrived",{mode=step.travel_mode,map=core.get_map_id()})
                world_transport_job=nil;return "complete"
            end
            if job.approaching then return step.travel_mode.."_approaching_object" end
            if job.requested then
                if job.boarded and now<=(job.deadline or math.huge) then return step.travel_mode.."_aboard" end
                if now>(job.deadline or math.huge) then
                    job.requested=false;job.next=now+3;job.attempt=(job.attempt or 1)+1
                    local expired_boarding=job.boarded==true
                    job.boarded=nil;job.boarded_at=nil;job.carried_samples=0;job.motion_point={x=pos.x,y=pos.y,z=pos.z}
                    emit("world_transport_retry",{mode=step.travel_mode,attempt=job.attempt,
                        reason=expired_boarding and "boarding_expired_without_arrival" or "transition_timeout"})
                else return step.travel_mode.."_transition_wait" end
            end
            if now<job.next then return step.travel_mode.."_interaction_wait" end
            job.next=now+2
            local best,best_distance=nil,math.huge
            if step.travel_mode=="portal" or step.travel_mode=="scheduled_transport" then
                local wanted=(step.target_name or ""):lower()
                for _,obj in pairs(objects()) do
                    if obj:is_valid() and obj.get_position and obj.get_name then
                        local d=distance(pos,obj:get_position());local name=(obj:get_name() or ""):lower()
                        local matches=wanted~="" and name~="" and (name==wanted or name:find(wanted,1,true) or wanted:find(name,1,true))
                        local radius=step.travel_mode=="scheduled_transport" and 20 or 12
                        if d<=radius and not p:can_attack(obj) and matches and d<best_distance then
                            best,best_distance=obj,d
                        end
                    end
                end
            end
            if best then
                if best_distance>(step.interaction_range or 4) then
                    local goal=best:get_position()
                    a.stop()
                    job.approaching=true;job.approach_epoch=(job.approach_epoch or 0)+1
                    local epoch=job.approach_epoch
                    a.move({x=goal.x,y=goal.y,z=goal.z},function(ok,reason)
                        if world_transport_job~=job or epoch~=job.approach_epoch then return end
                        job.approaching=nil;job.next=core.time()+(ok and 0 or 3)
                        emit("world_transport_approach_result",{mode=step.travel_mode,success=ok,reason=reason})
                    end)
                    return step.travel_mode.."_approaching_object"
                end
                a.stop()
                local accepted,interaction_reason=SafeInteraction.dispatch(core.input,best)
                if not accepted then
                    job.next=now+3
                    emit("world_transport_interaction_retry",{mode=step.travel_mode,target=best:get_name(),reason=interaction_reason})
                    return step.travel_mode.."_interaction_retry"
                end
                job.requested=true;job.deadline=now+(step.travel_mode=="portal" and 20 or 90)
                emit("world_transport_interact",{mode=step.travel_mode,target=best:get_name(),accepted=accepted})
                return step.travel_mode.."_transition_wait"
            end
            if step.travel_mode=="scheduled_transport" then
                -- A transport not being visible is not proof that the character
                -- boarded it. Keep polling the dock instead of latching into a
                -- false 90-second transition wait. A real map/displacement
                -- transition is still recognized above, including manual or
                -- platform-triggered boarding.
                emit("scheduled_transport_dock_wait",{target=step.target_name})
                return "scheduled_transport_wait"
            end
            if profile and profile.persistent_navigation then
                emit("world_transport_object_wait",{mode=step.travel_mode,target=step.target_name})
                return "portal_object_wait"
            end
            return "blocked:portal_object_not_found"
        end
        if not core.taxi or not core.taxi.num_nodes then
            if profile and profile.persistent_navigation then return "taxi_api_wait" end
            return "blocked:taxi_api_unavailable"
        end
        if not taxi_job or taxi_job.step~=step then taxi_job={step=step,started=core.time(),next=0} end
        if taxi_job.requested then
            local p=player();local pos=p:get_position()
            if taxi_job.origin and distance(pos,taxi_job.origin)>50 then taxi_job.departed=true end
            -- take_node has no success result on this core. A closed map alone
            -- is not departure either; recover a rejected/no-op request while
            -- the character is still stationary at the departure flight master.
            local idle=p.is_moving and not p:is_moving() and p.is_flying and not p:is_flying()
            local control_free=not taxi_job.control_lost or taxi_job.control_returned
            if not taxi_job.departed and control_free and taxi_job.origin
                and distance(pos,taxi_job.origin)<=15
                and (idle or (safe_read("taxi_nodes",core.taxi.num_nodes,0) or 0)>0)
                and core.time()-(taxi_job.requested_at or core.time())>=15 then
                taxi_job.requested=false;taxi_job.control_lost=nil;taxi_job.control_returned=nil
                taxi_job.next=core.time()+3
                emit("taxi_departure_retry",{destination=step.taxi_destination,reason="departure_not_observed"})
                return "taxi_departure_retry"
            end
            -- This core's event pump does not guarantee PLAYER_CONTROL_GAINED.
            -- Require displacement followed by a stable, measured landing beside
            -- a flight master before completing through polling.
            local at_landing=false
            if taxi_job.departed and p.is_moving and not p:is_moving() and not p:is_flying()
                and (not step.taxi_destination_map_id or core.get_map_id()==step.taxi_destination_map_id) then
                local height=nav.measured_height and nav.measured_height(pos)
                if height and math.abs(height-pos.z)<=4 then
                    for _,obj in pairs(objects()) do
                        if obj:is_valid() and obj.get_npc_flags and math.floor(obj:get_npc_flags()/8192)%2==1
                            and distance(pos,obj:get_position())<=12 then at_landing=true;break end
                    end
                end
            end
            if at_landing then
                taxi_job.landing_since=taxi_job.landing_since or core.time()
                if core.time()-taxi_job.landing_since>=2 then
                    emit("taxi_arrived",{destination=step.taxi_destination,source="measured_landing"})
                    taxi_job=nil;return "complete"
                end
            else taxi_job.landing_since=nil end
            if core.time()>(taxi_job.arrival_deadline or math.huge) then
                if profile and profile.persistent_navigation then
                    emit("taxi_arrival_recovery",{destination=step.taxi_destination,reason="arrival_unconfirmed"})
                    taxi_job={step=step,started=core.time(),next=core.time()+10}
                    if core.taxi.close then safe_input("taxi_close",core.taxi.close) end
                    return "taxi_route_recovery"
                end
                return "blocked:taxi_arrival_unconfirmed"
            end
            return "taxi_travel_wait"
        end
        if core.time()<taxi_job.next then return "opening_taxi_map" end
        local count=safe_read("taxi_nodes",core.taxi.num_nodes,0) or 0
        if count>0 then
            if step.travel_mode=="taxi_discovery" then safe_input("taxi_close",core.taxi.close);taxi_job=nil;return "complete" end
            local names={}
            for i=1,count do names[i]=safe_read("taxi_node_name",core.taxi.node_name,"",i) or "" end
            local selected,match_reason=require("taxi_match").find(step.taxi_destination,names)
            if selected then
                    local i=selected;local name=names[i]
                    local kind=safe_read("taxi_node_type",core.taxi.node_type,nil,i)
                    if kind=="CURRENT" then safe_input("taxi_close",core.taxi.close);taxi_job=nil;return "complete" end
                    if kind~="REACHABLE" then
                        if profile and profile.persistent_navigation then
                            emit("taxi_network_refresh",{destination=name,reason="destination_not_reachable"})
                            if core.taxi.close then safe_input("taxi_close",core.taxi.close) end
                            taxi_job.next=core.time()+15
                            return "taxi_network_refresh"
                        end
                        return "blocked:taxi_destination_not_reachable:"..name
                    end
                    local accepted=safe_input("taxi_departure",core.taxi.take_node,i)
                    if not accepted then
                        taxi_job.next=core.time()+3
                        emit("taxi_departure_retry",{destination=name,reason="request_rejected"})
                        return "taxi_departure_retry"
                    end
                    local origin=player():get_position()
                    taxi_job.requested=true;taxi_job.origin={x=origin.x,y=origin.y,z=origin.z};taxi_job.requested_at=core.time();taxi_job.arrival_deadline=core.time()+900
                    emit("taxi_requested",{destination=name});return "taxi_departure_wait"
            end
            emit("taxi_destination_unresolved",{destination=step.taxi_destination,reason=match_reason,available=table.concat(names,"; ")})
            if profile and profile.persistent_navigation then
                if core.taxi.close then safe_input("taxi_close",core.taxi.close) end
                taxi_job.next=core.time()+15
                return "taxi_network_refresh"
            end
            return "blocked:taxi_destination_name_unmatched:"..step.taxi_destination
        end
        taxi_job.next=core.time()+2
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj.get_npc_flags and math.floor(obj:get_npc_flags()/8192)%2==1
                and distance(player():get_position(),obj:get_position())<=8 then
                local accepted=SafeInteraction.dispatch(core.input,obj,"interact")
                if accepted then return "opening_taxi_map" end
            end
        end
        if profile and profile.persistent_navigation then return "flight_master_search_wait" end
        return "blocked:flight_master_not_found_at_guide_point"
    end
    a.optional_interact=function(step)
        local p=player();local wanted=(step.target_name or ""):lower();local best,best_distance=nil,math.huge
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj.get_name and obj.get_position and not p:can_attack(obj) then
                local name=(obj:get_name() or ""):lower();local d=distance(p:get_position(),obj:get_position())
                if name==wanted and d<=5 and d<best_distance then best,best_distance=obj,d end
            end
        end
        if best then
            local accepted,reason=SafeInteraction.dispatch(core.input,best)
            emit("optional_interact_requested",{target=step.target_name,accepted=accepted,reason=reason})
        else emit("optional_interact_skipped",{target=step.target_name,reason="exact_object_not_observed"}) end
    end
    a.quest_giver_position=function(step)
        local obj,d=named_target(step,true)
        step.live_contact_observed=obj~=nil and d<=12
        if obj and d<=60 then local p=obj:get_position();return {x=p.x,y=p.y,z=p.z},d end
    end
    a.quest_dialog = function(step)
        local now = core.time()
        if now < next_input then return end
        next_input = now + 0.8
        local function quest_request(kind,fn,...)
            if type(fn)~="function" then
                emit("quest_request_failed",{quest_id=step.quest_id,kind=kind,reason="api_unavailable"});return false
            end
            local ran,result=pcall(fn,...)
            if not ran or result==false then
                emit("quest_request_failed",{quest_id=step.quest_id,kind=kind,
                    reason=ran and "client_refused" or tostring(result)});return false
            end
            return true
        end
        if greeting_open then
            local read=step.action=="accept" and core.quests.get_available_title or core.quests.get_active_title
            local choose=step.action=="accept" and core.quests.select_available_quest or core.quests.select_active_quest
            local wanted=tostring(step.title or ""):lower():match("^%s*(.-)%s*$")
            if type(read)=="function" and type(choose)=="function" and wanted~="" then
                for index=1,32 do
                    local ok,title=pcall(read,index)
                    if not ok or type(title)~="string" or title=="" then break end
                    if title:lower():match("^%s*(.-)%s*$")==wanted then
                        if quest_request("greeting_select",choose,index) then
                            greeting_open=false;step.quest_dialog_submission={stage="GREETING",at=now}
                            emit("quest_greeting_selected",{quest_id=step.quest_id,index=index,title=title,action=step.action})
                        end
                        return
                    end
                end
            end
        end
        local q = safe_read("open_quest_info",core.quests.get_open_quest_info,nil)
        -- After one of several quests is handed in, Retail can leave the old
        -- reward panel visible for a moment. Never click through that stale
        -- panel for the next guide step; close it, then reopen the NPC and
        -- select the exact remaining quest from gossip.
        if q and panel and not Variants.contains(step,q.quest_id) then
            emit("stale_quest_panel_closed",{expected_quest_id=step.quest_id,open_quest_id=q.quest_id,action=step.action})
            safe_input("stale_close_quest",core.quests.close_quest)
            safe_input("stale_close_gossip",core.quests.close_gossip)
            panel=nil
            return
        end
        if q and Variants.contains(step,q.quest_id) then
            if pending_quest_giver and pending_quest_giver.step==step then
                local key=tostring(step.action)..":"..tostring(q.quest_id)
                learned_quest_givers[key]=pending_quest_giver.npc_id
                emit("quest_giver_identity_learned",{action=step.action,quest_id=q.quest_id,npc_id=pending_quest_giver.npc_id})
                pending_quest_giver=nil
            end
            if not step.quest_id then step.quest_id=q.quest_id;emit("quest_variant_resolved",{quest_id=step.quest_id,source="matching_panel"}) end
            if not panel then
                emit("quest_panel_reopen",{quest_id=step.quest_id,reason="panel_stage_unknown"})
                safe_input("panel_close_quest",core.quests.close_quest)
                safe_input("panel_close_gossip",core.quests.close_gossip)
                return
            end
            local submission=step.quest_dialog_submission
            if submission and submission.stage==panel and now-submission.at<3 then return end
            if panel == "QUEST_DETAIL" and step.action == "accept" then
                emit("quest_accept_requested",{quest_id=step.quest_id})
                if quest_request("accept",core.quests.accept_quest) then step.quest_dialog_submission={stage=panel,at=now} end
            elseif panel == "QUEST_PROGRESS" and step.action == "turnin" then
                if not a.objective_done(step.quest_id) then
                    emit("quest_turnin_not_ready",{quest_id=step.quest_id});return
                end
                emit("quest_complete_requested",{quest_id=step.quest_id})
                if quest_request("complete",core.quests.complete_quest) then step.quest_dialog_submission={stage=panel,at=now} end
            elseif panel == "QUEST_COMPLETE" and step.action == "turnin" then
                -- QUEST_PROGRESS advances with complete_quest; QUEST_COMPLETE
                -- submits with get_quest_reward, including index 0 for no choices.
                local choice=step.reward_choice
                local choice_count
                if core.quests.get_num_quest_choices then
                    local ok,value=pcall(core.quests.get_num_quest_choices)
                    if ok and type(value)=="number" then choice_count=math.max(0,math.floor(value)) end
                end
                if choice_count==0 then
                    emit("quest_turnin_no_choice_requested",{quest_id=step.quest_id})
                    if quest_request("reward_no_choice",core.quests.get_quest_reward,0) then step.quest_dialog_submission={stage=panel,at=now} end
                    return
                end
                if choice~=nil and choice_count and (choice<1 or choice>choice_count) then
                    emit("quest_reward_wait",{quest_id=step.quest_id,reason="authored_reward_choice_out_of_range",
                        choice=choice,choice_count=choice_count});return
                end
                -- An unspecified choice always means automatic selection. This
                -- also protects imported routes that predate auto_reward.
                if choice==nil then
                    local choices,worn={},{}
                    local limit=choice_count or 10
                    for i=1,limit do
                        local link=safe_read("quest_reward_item_link",core.quests.get_quest_item_link,nil,"choice",i)
                        if not link or link=="" then
                            if choice_count then
                                emit("quest_reward_wait",{quest_id=step.quest_id,reason="reward_item_link_pending",choice=i,
                                    choice_count=choice_count});return
                            end
                            break
                        end
                        choices[#choices+1]={index=i,info=safe_read("quest_reward_item_info",core.quests.get_item_info,nil,link),
                            stats=safe_read("quest_reward_item_stats",core.inventory.get_item_stats,nil,link)}
                    end
                    for slot=1,19 do
                        local link=safe_read("reward_equipped_item_link",core.inventory.get_inventory_item_link,nil,slot)
                        if link and link~="" then worn[slot]={info=safe_read("reward_equipped_item_info",core.quests.get_item_info,nil,link),
                            stats=safe_read("reward_equipped_item_stats",core.inventory.get_inventory_item_stats,nil,slot)} end
                    end
                    local class_names={[1]="WARRIOR",[2]="PALADIN",[3]="HUNTER",[4]="ROGUE",[5]="PRIEST",[6]="DEATHKNIGHT",[7]="SHAMAN",[8]="MAGE",[9]="WARLOCK",[10]="MONK",[11]="DRUID",[12]="DEMONHUNTER",[13]="EVOKER"}
                    local reason
                    choice,reason=Gear.reward_choice(choices,worn,{class=class_names[player():get_class()],
                        spec=safe_read("reward_specialization",core.game_ui.get_specialization,nil),
                        level=player():get_level()})
                    if reason then emit("quest_reward_wait",{quest_id=step.quest_id,reason=reason});return end
                end
                if choice and choice>0 then
                    emit("quest_reward_requested",{quest_id=step.quest_id,choice=choice})
                    if quest_request("reward",core.quests.get_quest_reward,choice) then step.quest_dialog_submission={stage=panel,at=now} end
                end
            end
            return
        end
        local getter = step.action == "accept" and core.quests.get_gossip_available_quests or core.quests.get_gossip_active_quests
        local selector = step.action == "accept" and core.quests.select_gossip_available_quest or core.quests.select_gossip_active_quest
        local read,entries=pcall(getter)
        if not read or type(entries)~="table" then
            emit("quest_gossip_read_failed",{quest_id=step.quest_id,action=step.action,reason=read and "invalid_result" or tostring(entries)})
            entries={}
        end
        for _, entry in ipairs(entries) do
            if Variants.contains(step,entry.quest_id) then
                if not step.quest_id then step.quest_id=entry.quest_id;emit("quest_variant_resolved",{quest_id=step.quest_id,source="matching_gossip_offer"}) end
                emit("quest_gossip_selected",{quest_id=entry.quest_id})
                if quest_request("gossip_select",selector,entry.quest_id) then step.quest_dialog_submission={stage="GOSSIP",at=now} end
                return
            end
        end
        -- Authored gossip can unlock the offer (e.g. Chromie), so process it
        -- while waiting for acceptance, not only after accepting the quest.
        if step.action=="accept" and step.gossip_option_ids and core.quests.get_gossip_options then
            local options=safe_read("quest_accept_gossip",core.quests.get_gossip_options,{}) or {}
            local choice=QuestDialogue.choose(step,options)
            if choice then
                if now>=(step.accept_gossip_retry_at or 0) then
                    step.accept_gossip_retry_at=now+2
                    local accepted=quest_request("accept_gossip",core.quests.select_gossip_option,choice)
                    emit("quest_accept_gossip_selected",{quest_id=step.quest_id,option_id=choice,accepted=accepted})
                end
                return
            end
        end
        if step.quest_giver_item then
            local item=step.tags and tonumber(step.tags.U)
            if item then
                local ran,result=pcall(core.input.use_item,item)
                emit("quest_start_item_requested",{quest_id=step.quest_id,item_id=item,
                    accepted=ran and result==true,error=not ran and tostring(result) or nil})
            end
            return
        end
        local obj,d = named_target(step,true)
        if not obj and step.auto_dialog and step.position then
            local candidates={}
            step.quest_giver_anchor=step.quest_giver_anchor or step.position
            if distance(step.position,step.quest_giver_anchor)>12 then step.quest_giver_anchor=step.position end
            for _,candidate in pairs(objects()) do
                if candidate:is_valid() and not candidate:is_dead() and candidate.is_quest_unit
                    and candidate:is_quest_unit() and player().can_attack and not player():can_attack(candidate) then
                    local near=distance(player():get_position(),candidate:get_position())
                    local authored=distance(step.quest_giver_anchor,candidate:get_position())
                    if near<=12 and authored<=12 then candidates[#candidates+1]={object=candidate,range=near,key=tostring(candidate:get_guid())} end
                end
            end
            table.sort(candidates,function(x,y) if x.range==y.range then return x.key<y.key end;return x.range<y.range end)
            if #candidates>0 and now>=(step.quest_giver_retry_at or 0) then
                local index=((step.quest_giver_attempt or 0)%#candidates)+1
                step.quest_giver_attempt=(step.quest_giver_attempt or 0)+1;step.quest_giver_retry_at=now+3
                obj=candidates[index].object;d=candidates[index].range
                pending_quest_giver={step=step,npc_id=obj:get_npc_id()}
                safe_input("dialog_close_quest",core.quests.close_quest)
                safe_input("dialog_close_gossip",core.quests.close_gossip)
                emit("quest_giver_candidate",{quest_id=step.quest_id,npc_id=obj:get_npc_id(),attempt=step.quest_giver_attempt,quest_identity_confirmed=false})
            end
        end
        if obj and d > (step.interaction_range or 5) then
            local pos=obj:get_position()
            emit("quest_npc_approach",{quest_id=step.quest_id,distance=d,npc_id=obj:get_npc_id()})
            return "approach",{x=pos.x,y=pos.y,z=pos.z}
        end
        if not obj then pending_quest_giver=nil end
        if not obj and now>=(step.npc_missing_log_at or 0) then
            step.npc_missing_log_at=now+5
            emit("quest_npc_not_found",{quest_id=step.quest_id,target=step.target_name,npc_id=step.npc_id})
        end
        if obj and d <= (step.interaction_range or 5) then
            if step.live_contact_observed and not step.npc_id and not step.target_name then
                pending_quest_giver={step=step,npc_id=obj:get_npc_id()}
            end
            if obj.is_unit and not obj:is_unit() and core.input.use_object then
                emit("quest_giver_object_use",{quest_id=step.quest_id,target=step.target_name})
                SafeInteraction.dispatch(core.input,obj,"use")
            else
                if now<(step.quest_contact_retry_at or 0) then return end
                step.quest_contact_attempts=(step.quest_contact_attempts or 0)+1
                step.quest_contact_retry_at=now+math.min(15,2+step.quest_contact_attempts)
                local accepted,reason=SafeInteraction.dispatch(core.input,obj,"interact")
                emit("quest_npc_interact",{npc_id=obj:get_npc_id(),target=obj.get_name and obj:get_name() or step.target_name,quest_id=step.quest_id,accepted=accepted,reason=reason,attempt=step.quest_contact_attempts})
                if step.quest_contact_attempts%3==0 then
                    local offers={};for _,entry in ipairs(entries) do offers[#offers+1]=tostring(entry.quest_id) end
                    emit("quest_offer_unavailable",{quest_id=step.quest_id,target=obj.get_name and obj:get_name() or step.target_name,offered=table.concat(offers,","),chromie_time_option=step.chromie_time_option})
                end
            end
        end
    end
    a.authored_spell=function(step)
        if core.time()<(step.spell_retry_at or 0) then return false end
        local target_object=player()
        if step.target_name or step.npc_id then
            local obj,d=named_target(step,true)
            if not obj then return false end
            if d>4 then return false end
            target_object=obj
        end
        for _,spell_id in ipairs(step.spell_ids or step.active_spell_ids or {}) do
            if core.spell_book.is_spell_known(spell_id) and core.spell_book.is_usable_spell(spell_id) then
                step.spell_retry_at=core.time()+2;a.stop()
                local ran,result=pcall(core.input.cast_target_spell,spell_id,target_object)
                local accepted=ran and result==true
                emit("authored_spell_requested",{spell_id=spell_id,target=step.target_name,accepted=accepted,
                    error=not ran and tostring(result) or nil})
                return accepted
            end
        end
        return false
    end
    a.perform_emote=function(step)
        if step.emote_done then return true end
        if step.emote_token=="SIT" then
            local started=safe_input("authored_emote_descend_start",core.input.descend_start)
            local stopped=safe_input("authored_emote_descend_stop",core.input.descend_stop)
            if started and stopped then step.emote_done=true;emit("authored_emote",{token=step.emote_token,npc_id=step.npc_id});return true end
        end
        return false
    end
    a.vehicle_state=function(step)
        if bridge.player and (bridge.player.in_vehicle or bridge.player.can_exit_vehicle) then return true end
        if core.time()<(step.vehicle_retry_at or 0) then return false end
        local obj,d=named_target(step,true)
        if obj and d<=4 then
            step.vehicle_retry_at=core.time()+2
            local accepted,reason=SafeInteraction.dispatch(core.input,obj,"interact")
            emit("authored_vehicle_interact",{vehicle_id=step.vehicle_id,accepted=accepted,reason=reason})
        end
        return false
    end
    a.vehicle_exit=function(step)
        if not (bridge.player and (bridge.player.in_vehicle or bridge.player.can_exit_vehicle)) then return true end
        if core.time()<(step.vehicle_exit_retry_at or 0) then return false end
        step.vehicle_exit_retry_at=core.time()+2
        local accepted=safe_input("authored_vehicle_exit",core.input.dismount)
        emit("authored_vehicle_exit_requested",{accepted=accepted})
        return false
    end
    a.abandon_quest=function(step)
        if not a.on_quest(step.quest_id) then return true end
        if core.time()<(step.abandon_retry_at or 0) then return false end
        step.abandon_retry_at=core.time()+3
        local accepted=safe_input("authored_quest_abandon",core.quests.abandon_quest_by_id,step.quest_id)
        emit("authored_quest_abandon_requested",{quest_id=step.quest_id,accepted=accepted})
        return false
    end
    a.reputation_condition=function(faction_id,standing,value)
        if not core.reputation or type(core.reputation.get_faction_info_by_id)~="function" then return nil end
        local info=safe_read("reputation",core.reputation.get_faction_info_by_id,nil,faction_id)
        if not info then return nil end
        local current=tonumber(info.standing_id);local bottom=tonumber(info.bar_min);local top=tonumber(info.bar_max);local earned=tonumber(info.bar_value)
        if not current or not bottom or not top or not earned then return nil end
        value=tonumber(value) or 0
        if value<0 then return current>=standing or current==standing-1 and earned>=top+value end
        if value>=1 then return current>standing or current==standing and earned>=bottom+value end
        local relative=earned<0 and (top-bottom)+earned or earned-bottom
        return current>standing or current==standing and relative>=(top-bottom)*value
    end
    a.area_poi_exists=function(map_id,ids)
        local known=false
        for _,id in ipairs(ids or {}) do
            local value=bridge.area_pois[tostring(map_id)..":"..tostring(id)]
            if value==true then return true elseif value~=nil then known=true end
        end
        return known and false or nil
    end
    a.cooldown_remaining=function(cooldown_type,id)
        if cooldown_type~="item" then return nil end
        local p=player()
        if p and p:is_valid() and type(p.get_item_cooldown)=='function' then
            local ok,value=pcall(p.get_item_cooldown,p,tonumber(id))
            if ok and type(value)=='number' and value==value and value>=0 then return value end
        end
        return bridge.cooldowns[tonumber(id)]
    end
    a.darkmoon_faire_active=function() return bridge.darkmoon_faire end
    a.skyriding_unlocked=function() return bridge.skyriding_unlocked end
    a.mount_collected=function(id) return bridge.mounts[tonumber(id)] end
    a.collect_mount=function(step)
        if a.mount_collected(step.mount_id) then return true end
        if not step.mount_item_id or core.time()<(step.mount_collect_retry_at or 0) then return false end
        step.mount_collect_retry_at=core.time()+3
        local accepted=safe_input("mount_collection_item",core.input.use_item,step.mount_item_id)
        emit("mount_collection_item_requested",{mount_id=step.mount_id,item_id=step.mount_item_id,accepted=accepted})
        return false
    end
    a.deathskip=function(step)
        local p=player();local now=core.time()
        if not p or not p:is_valid() then return "deathskip_waiting_for_player" end
        if p:is_dead() or p:is_ghost() then
            step.deathskip_was_dead=true;a.stop()
            if not p:is_ghost() then
                if now>=(step.deathskip_retry_at or 0) then
                    step.deathskip_retry_at=now+2
                    local ran,result=pcall(core.input.release_spirit)
                    if not ran or result==false then
                        emit("deathskip_release_rejected",{error=not ran and tostring(result) or nil})
                    else
                        emit("deathskip_release_requested")
                    end
                end
                return "deathskip_releasing_spirit"
            end
            local best,best_distance
            for _,obj in pairs(objects()) do
                if obj:is_valid() and obj.is_unit and obj:is_unit() and obj.get_name then
                    local name=tostring(obj:get_name() or ""):lower()
                    if name:find("spirit healer",1,true) then
                        local d=distance(p:get_position(),obj:get_position())
                        if not best_distance or d<best_distance then best,best_distance=obj,d end
                    end
                end
            end
            if best and best_distance<=5 and now>=(step.deathskip_retry_at or 0) then
                step.deathskip_retry_at=now+2;SafeInteraction.dispatch(core.input,best,"interact")
                return "deathskip_spirit_healer_interaction"
            elseif best and not step.deathskip_moving then
                step.deathskip_moving=true
                a.move(best:get_position(),function() step.deathskip_moving=nil end)
            end
            return "deathskip_finding_spirit_healer"
        end
        if step.deathskip_was_dead then
            emit("deathskip_completed",{source_index=step.source_index});return "complete"
        end
        local best,best_distance
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj.is_unit and obj:is_unit() and p:can_attack(obj) and not obj:is_dead() then
                local d=distance(p:get_position(),obj:get_position())
                if d<=80 and (not best_distance or d<best_distance) then best,best_distance=obj,d end
            end
        end
        if not best then return "deathskip_waiting_for_hostile" end
        if best_distance>4 then
            if not step.deathskip_moving then
                step.deathskip_moving=true
                a.move(best:get_position(),function() step.deathskip_moving=nil end)
            end
            return "deathskip_approaching_hostile"
        end
        a.stop()
        local targeted=safe_input("deathskip_target",core.input.set_target,best)
        local interacted=safe_input("deathskip_interact",core.input.interact_with_object,best)
        safe_input("deathskip_stop_attack",core.input.stop_attack)
        local descended=safe_input("deathskip_descend_start",core.input.descend_start)
        safe_input("deathskip_descend_stop",core.input.descend_stop)
        emit("deathskip_hostile_pulled",{npc_id=best:get_npc_id(),distance=best_distance,
            accepted=targeted and interacted and descended})
        return "deathskip_waiting_for_death"
    end
    a.chromie_time=function(step)
        if bridge.chromie_time[step.chromie_time_option] then return true end
        if core.time()<(step.chromie_retry_at or 0) then return false end
        step.chromie_retry_at=core.time()+2
        local obj,d=named_target(step,true)
        if obj and d<=4 then SafeInteraction.dispatch(core.input,obj,"interact") end
        return false
    end
    a.adventure_map_accept=function(step)
        if a.on_quest(step.quest_id) or bridge.adventure_map[step.quest_id] then return true end
        if core.time()<(step.adventure_map_retry_at or 0) then return false end
        step.adventure_map_retry_at=core.time()+2
        local p=player();local best,best_distance
        for _,obj in pairs(objects()) do
            if obj:is_valid() and (not obj.is_unit or not obj:is_unit()) then
                local d=distance(p:get_position(),obj:get_position())
                if d<=8 and (not best_distance or d<best_distance) then best,best_distance=obj,d end
            end
        end
        if best then SafeInteraction.dispatch(core.input,best,"use") end
        return false
    end
    local function runtime_request(kind,fn,...)
        if type(fn)~="function" then emit("runtime_request_failed",{kind=kind,reason="api_unavailable"});return false end
        local ran,result=pcall(fn,...)
        if not ran or result==false then
            emit("runtime_request_failed",{kind=kind,reason=ran and "client_refused" or tostring(result)})
            return false
        end
        return true,result
    end
    a.bind_home=function(step)
        step.home_bound_epoch=step.home_bound_epoch or bridge.home_bound_epoch
        if bridge.home_bound_epoch>step.home_bound_epoch then return true end
        if safe_read("hearth_gossip_shown",core.quests.is_gossip_frame_shown,false) then
            if core.time()<(step.bind_retry_at or 0) then return false end
            for _,option in ipairs(safe_read("hearth_bind_gossip",core.quests.get_gossip_options,{}) or {}) do
                local kind=tostring(option.gossip_type or ""):lower();local name=tostring(option.name or ""):lower()
                if kind=="binder" or name:find("home",1,true) or name:find("hearthstone",1,true) then
                    step.bind_retry_at=core.time()+2
                    local accepted=runtime_request("hearth_bind_gossip",core.quests.select_gossip_option,option.gossip_option_id)
                    emit("hearth_bind_gossip_selected",{option_id=option.gossip_option_id,name=option.name,accepted=accepted})
                    return false
                end
            end
        end
        local obj,d=named_target(step,true)
        if obj and d<=4 and core.time()>=(step.bind_retry_at or 0) then
            step.bind_retry_at=core.time()+2;SafeInteraction.dispatch(core.input,obj,"interact")
        end
        return false
    end
    a.use_hearth=function(step)
        -- Capture the current cast counters before dispatch so completion is
        -- authoritative even when this is the first tick for the step.
        a.cast_observed(step)
        if core.time()<(step.hearth_retry_at or 0) then return false end
        step.hearth_retry_at=core.time()+5;a.stop()
        local accepted
        if core.spell_book.is_spell_known(556) then
            local dispatched,result=runtime_request("astral_recall",core.input.cast_target_spell,556,player())
            accepted=dispatched and result==true
        end
        if not accepted then local dispatched,result=runtime_request("hearthstone",core.input.use_item,6948);accepted=dispatched and result==true end
        if not accepted then local dispatched,result=runtime_request("garrison_hearthstone",core.input.use_item,184871);accepted=dispatched and result==true end
        emit("hearth_requested",{accepted=accepted==true,astral_recall=core.spell_book.is_spell_known(556)==true})
        return false
    end
    a.macro_operation=function(step)
        if core.time()<(step.macro_retry_at or 0) then return false end
        local operations=step.macro_operations or {};local index=step.macro_operation_index or 1
        local operation=operations[index];if not operation then return true end
        local accepted=false
        if operation.kind=="cancel_aura" then
            local found
            for _,aura in pairs(player():get_buffs() or {}) do
                local id=tonumber(aura.buff_id or aura.spell_id or aura.id);local name=aura.name or aura.spell_name
                if (operation.aura_id and id==operation.aura_id) or (operation.aura_name and name==operation.aura_name) then found=aura;break end
            end
            accepted=not found or runtime_request("macro_cancel_aura",core.input.cancel_buff,found)
        elseif operation.kind=="sit" then
            accepted=runtime_request("macro_descend_start",core.input.descend_start)
                and runtime_request("macro_descend_stop",core.input.descend_stop)
        elseif operation.kind=="leave_party" then accepted=runtime_request("macro_leave_party",core.input.leave_party)
        elseif operation.kind=="cast_spell" then
            local dispatched,result=runtime_request("macro_cast_spell",core.input.cast_target_spell,operation.spell_id,player());accepted=dispatched and result==true
        elseif operation.kind=="use_item" then
            local dispatched,result=runtime_request("macro_use_item",core.input.use_item,operation.item_id);accepted=dispatched and result==true
        elseif operation.kind=="exit_vehicle" then
            local dispatched,result=runtime_request("macro_exit_vehicle",core.input.dismount);accepted=dispatched and result==true
        elseif operation.kind=="random_mount" then
            local mount=a.preferred_mount and a.preferred_mount("ground") or 1
            local dispatched,result=runtime_request("macro_mount",core.input.mount,mount or 1);accepted=dispatched and result==true
        elseif operation.kind=="companion_guide_action" then
            -- The companion addon owns Blizzard UI APIs that are unavailable
            -- to the Project Sylvanas runtime. Advance only after its GA
            -- acknowledgement proves the authored action was attempted.
            operation.guide_action_after=operation.guide_action_after or core.time()
            local observed=bridge.guide_actions[operation.name]
            accepted=observed and observed>=operation.guide_action_after or false
        end
        emit("authored_macro_operation",{kind=operation.kind,accepted=accepted,spell_id=operation.spell_id,item_id=operation.item_id})
        if accepted then step.macro_operation_index=index+1;step.macro_retry_at=core.time()+0.5 end
        return (step.macro_operation_index or index)>#operations
    end
    a.spell_signal_position=function(step)
        local obj,d=named_target(step,true)
        if obj and d<=60 then return obj:get_position() end
    end
    a.spell_signal=function(step)
        if a.cast_observed(step) then return true end
        if core.time()<(step.spell_retry_at or 0) then return false end
        local obj,d=named_target(step,true)
        if obj and d<=4 then
            step.spell_retry_at=core.time()+2
            local accepted,reason=SafeInteraction.dispatch(core.input,obj,obj.is_unit and not obj:is_unit() and "use" or "interact")
            emit("spell_signal_interaction",{target=step.target_name,accepted=accepted,reason=reason})
        end
        return false
    end
    a.gossip_sequence=function(step)
        if step.gossip_sequence_complete then return true end
        local shown=safe_read("authored_gossip_shown",core.quests.is_gossip_frame_shown,false)
        if shown then
            if step.require_empty_quest_gossip then
                local available=safe_read("gossip_available_quests",core.quests.get_gossip_available_quests,{}) or {}
                local active=safe_read("gossip_active_quests",core.quests.get_gossip_active_quests,{}) or {}
                if #available>0 or #active>0 then
                    emit("authored_gossip_wait",{reason="quest_dialogue_present"});return false
                end
            end
            local options=safe_read("authored_gossip",core.quests.get_gossip_options,{}) or {}
            local choice,reason=QuestDialogue.choose(step,options)
            if choice then
                if core.time()<(step.gossip_retry_at or 0) then return false end
                step.gossip_retry_at=core.time()+1
                local accepted=runtime_request("authored_gossip",core.quests.select_gossip_option,choice)
                if accepted then
                    step.gossip_selection_seen=true
                    if step.gossip_option_indices then step.gossip_index_cursor=(step.gossip_index_cursor or 1)+1 end
                end
                emit("authored_gossip_selected",{quest_id=step.quest_id,option_id=choice,accepted=accepted})
                return false
            end
            if step.gossip_selection_seen and reason=="authored_gossip_option_not_present" then
                step.gossip_sequence_complete=true
                emit("authored_gossip_complete",{quest_id=step.quest_id});return true
            end
            emit("authored_gossip_wait",{quest_id=step.quest_id,reason=reason});return false
        end
        if step.gossip_selection_seen then
            step.gossip_sequence_complete=true
            emit("authored_gossip_complete",{quest_id=step.quest_id,reason="frame_closed"});return true
        end
        local obj,d=named_target(step,true)
        if obj and d<=4 and core.time()>=(step.gossip_retry_at or 0) then
            step.gossip_retry_at=core.time()+2
            SafeInteraction.dispatch(core.input,obj,"interact")
        end
        return false
    end
    local rescue_quests={[28806]=true,[28808]=true,[28809]=true,[28810]=true,[28811]=true,[28812]=true,[28813]=true,[29082]=true,[63447]=true}
    local rescue_attempts={}
    local object_attempts={}
    local object_nav_failures={}
    local object_cleanup_at=0
    local object_pending_until=0
    local objective_scope
    local function is_westfall_homeless(candidate,p)
        if not candidate or not candidate:is_valid() or not candidate.get_name or p:can_attack(candidate) then return false end
        local id=candidate:get_npc_id();local name=candidate:get_name():lower()
        return id==42384 or id==42383 or id==42386
            or name=="homeless stormwind citizen" or name=="west plains drifter" or name=="transient"
    end
    a.interaction_local_ready=function(step)
        if step.action~="accept" and step.action~="turnin" then return false end
        -- A matching open quest panel owns dialogue even if the NPC moves a
        -- little outside arrival range. Do not restart a route through it.
        if panel and core.quests.get_open_quest_info then
            local ok,q=pcall(core.quests.get_open_quest_info)
            if ok and q and Variants.contains(step,q.quest_id) then return true end
        end
        if not step.npc_id and not step.target_name then return false end
        local p=player();if not p or not p:is_valid() or p:is_mounted() or p:is_flying() then return false end
        local obj,d=named_target(step,true)
        return obj~=nil and d<=require('route_policy').arrival(step.action,step.interaction_range)
            and not p:can_attack(obj)
    end
    a.objective_local_ready=function(step)
        -- A live unfinished objective target owns its approach. Do not force
        -- a return to a stale collection checkpoint before pursuing it.
        if step.quest_id and step.objective_mode~="explore" and live_objectives then
            local ok,rows=pcall(live_objectives,step.quest_id)
            local descriptions={}
            if ok and type(rows)=="table" then
                local unfinished={}
                for index,row in ipairs(rows) do
                    if not row.finished and QuestObjectives.includes(step.objective_indices or (step.objective_index and {step.objective_index}),index) then
                        descriptions[#descriptions+1]=tostring(row.text or row.description or "");unfinished[#unfinished+1]=index
                    end
                end
                step.live_objective_indices=unfinished
            end
            local p=player()
            if p and not p:is_mounted() and not p:is_flying() then
                for _,obj in pairs(objects()) do
                    if QuestTargets.available(obj) and obj.get_name then
                        local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
                        local here,there=p:get_position(),obj:get_position()
                        if (object_attempts[key] or 0)<=core.time() and distance(here,there)<=60 and math.abs(here.z-there.z)<=8
                            and QuestTargets.matches(step,obj:get_name(),obj:get_npc_id(),p:can_attack(obj),descriptions) then
                            return true
                        end
                    end
                end
            end
        end
        if step.quest_id~=26271 then
            if step.tags and step.tags.NC and (step.target_name or step.npc_id) and not tonumber(step.tags.U) then
                local obj,d=named_target(step,true);local p=player()
                if obj and p and not p:is_mounted() and not p:is_flying() and not p:can_attack(obj) then
                    local range=obj.is_unit and not obj:is_unit() and 2.25 or 4
                    if d<=range then return true end
                end
            end
            if not step.extra_action_spell_id or not (step.target_name or step.npc_id or step.target_names) then return false end
            local obj,d=named_target(step,true)
            local p=player()
            if not obj or not p or p:can_attack(obj) or d>(step.item_action_range or 30) then return false end
            local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
            if (object_attempts[key] or 0)>core.time() then return false end
            step.dynamic_action_ready=true
            return true
        end
        local p=player();if not p or not p:is_valid() then return false end
        local best
        for _,candidate in pairs(objects()) do
            if is_westfall_homeless(candidate,p) then
                local key=candidate.get_guid and tostring(candidate:get_guid()) or tostring(candidate)
                if (object_attempts[key] or 0)<=core.time() then
                    local range=distance(p:get_position(),candidate:get_position())
                    if range<=25 and (not best or range<best) then best=range end
                end
            end
        end
        if not best then return false end
        step.dynamic_action_ready=true
        if core.time()>=(step.local_ready_log_at or 0) then
            step.local_ready_log_at=core.time()+10
            emit("westfall_stew_local_target_ready",{quest_id=step.quest_id,distance=best})
        end
        return true
    end
    local function move_to_quest_target(step,obj,purpose)
        local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
        local npc_id=obj:get_npc_id();local target_name=obj:get_name();local current=obj:get_position()
        local destination,prediction=target_prediction:predict(key,current,core.time(),purpose)
        if prediction and core.time()>=(prediction_log_at[key] or 0) then
            prediction_log_at[key]=core.time()+5
            emit("quest_target_position_predicted",{quest_id=step.quest_id,npc_id=npc_id,target=target_name,
                purpose=purpose,speed=prediction.speed,horizon=prediction.horizon,advance=prediction.advance})
        end
        pull_epoch=pull_epoch+1;local epoch=pull_epoch
        pull_moving={kind="quest_target",key=key,object=obj,destination={x=destination.x,y=destination.y,z=destination.z},started=core.time(),purpose=purpose}
        local current_distance=distance(player():get_position(),destination)
        -- A visible nearby feeding target does not need a remote mesh route.
        -- Sentinel's direct follower avoids the server request that has been
        -- stalling on these short, moving-unit destinations. Keep ordinary
        -- quest routes on the established navmesh path.
        local mover=step.quest_id==26271 and current_distance<=40 and a.move_direct or a.move
        if mover==a.move_direct then
            emit("quest_target_direct_navigation",{quest_id=step.quest_id,npc_id=npc_id,target=target_name,
                purpose=purpose,distance=current_distance})
        end
        mover(destination,function(ok,reason)
            if epoch~=pull_epoch then return end
            pull_moving=nil
            if ok and purpose=="world_object" then
                local valid,obj_valid=pcall(function() return obj:is_valid() end)
                local range=(obj.is_unit and not obj:is_unit()) and 2.25 or 4
                if step.force_close_interaction==key then range=.75 end
                if not valid or not obj_valid or not QuestTargets.interaction_reached(player():get_position(),obj:get_position(),range) then
                    ok=false;reason="quest_target_outside_interaction_range_after_arrival"
                end
            end
            if ok then object_nav_failures[key]=nil;return end
            local failures=(object_nav_failures[key] or 0)+1;object_nav_failures[key]=failures
            local cooldown=math.min(120,15*2^(math.min(4,failures)-1))
            object_attempts[key]=core.time()+cooldown
            emit("quest_target_navigation_failed",{quest_id=step.quest_id,npc_id=npc_id,
                target=target_name,purpose=purpose,reason=reason,failures=failures,cooldown=cooldown})
        end)
    end
    local function refresh_quest_target_route(step,obj,purpose)
        if type(pull_moving)~="table" or pull_moving.kind~="quest_target" then return pull_moving~=nil end
        local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
        if pull_moving.key~=key then
            local old_valid=false
            if pull_moving.object then
                local ok,valid=pcall(function() return pull_moving.object:is_valid() and not pull_moving.object:is_dead() end)
                old_valid=ok and valid==true
            end
            if not old_valid and core.time()-pull_moving.started>=1 then
                local old_key=pull_moving.key
                nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil
                emit("quest_target_route_replaced",{quest_id=step.quest_id,previous=old_key,current=key,purpose=purpose})
                move_to_quest_target(step,obj,purpose)
            end
            return true
        end
        local position=obj:get_position()
        if core.time()-pull_moving.started>=2 and distance(position,pull_moving.destination)>=8 then
            local moved=distance(position,pull_moving.destination)
            nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil
            emit("quest_target_route_refreshed",{quest_id=step.quest_id,target=obj:get_name(),purpose=purpose,distance_moved=moved})
            move_to_quest_target(step,obj,purpose)
        end
        return true
    end
    a.handlers.guide_objective=function(step)
        if step.vehicle_self_action then
            if not a.objective_done(step.quest_id,1) then return end
            if core.time()>=next_input then
                next_input=core.time()+3
                require("quest_actions").vehicle(step,player(),log,bridge.vehicle_actions.slots)
            end
            return
        end
        if step.action~="collect" and step.action~="scenario" and not quest_accepted(step.quest_id) then return end
        -- Scripted waits follow their actor without clicking or searching for kills.
        if step.scripted_wait then
            local actor,d=named_target({target_name=step.follow_actor},true)
            if actor and d>(step.scripted_follow_range or 6) then
                if not refresh_quest_target_route(step,actor,"scripted_follow") then
                    move_to_quest_target(step,actor,"scripted_follow")
                end
            else
                if pull_moving then nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil end
                a.stop()
            end
            if core.time()>=(step.scripted_wait_log_at or 0) then
                step.scripted_wait_log_at=core.time()+10
                emit("quest_scripted_wait",{quest_id=step.quest_id,actor=step.follow_actor,actor_found=actor~=nil,distance=d})
            end
            return
        end
        -- Target fatigue belongs to one authored objective. The same NPC or
        -- object can legitimately be needed by consecutive quest steps; do
        -- not carry an interaction cooldown or pending receipt into the next
        -- step and suppress its valid target.
        if objective_scope~=step then
            objective_scope=step
            object_attempts={};object_nav_failures={};rescue_attempts={}
            object_pending_until=0;interaction_tracker:reset()
        end
        if core.time()<object_pending_until or player():is_casting_spell() or player():is_channelling_spell() then return end
        if core.time()>=object_cleanup_at then
            object_cleanup_at=core.time()+60
            for key,expires in pairs(object_attempts) do
                if expires<=core.time() then object_attempts[key]=nil;object_nav_failures[key]=nil end
            end
        end
        if step.world_state_epoch~=world_state_epoch then
            step.world_state_epoch=world_state_epoch;step.search_state=nil;step.search_query=nil
            -- Quest 26271 applies a two-minute "fed" state to each citizen.
            -- Preserve those target cooldowns across QUEST_LOG_UPDATE so the
            -- new objective count does not make us immediately reuse one.
            if step.quest_id~=26271 then object_attempts={};object_nav_failures={} end
            if step.quest_id==26271 and pull_moving then
                -- Quest credit can arrive after the stew cast while an area
                -- search has already started. Cancel that stale route and scan
                -- the current population again before leaving the valid group.
                a.stop()
                emit("westfall_stew_route_refreshed",{quest_id=step.quest_id,reason="quest_progress"})
            end
            object_pending_until=0
            emit("quest_world_state_refreshed",{quest_id=step.quest_id,epoch=world_state_epoch})
        end
        GuideSupport.zygor(step,core.addons and core.addons.zygor)
        -- Feeding the Hungry has a dedicated multi-citizen area loop below.
        -- Do not let the generic self-use shortcut repeatedly cast at one spot.
        if step.quest_id~=26271 and step.quest_action_mode=="self" and step.tags and tonumber(step.tags.U) then
            if core.time()>=next_input and not player():is_casting_spell() and not player():is_channelling_spell() then
                next_input=core.time()+3;a.stop()
                require("quest_actions").dispatch(step,player(),log)
            end
            return
        end
        local descriptions={}
        step.live_objective_indices=nil
        local objective_types={}
        local function remember_objective_type(value)
            local kind=tostring(value or ""):lower():gsub("[^%w]","")
            if kind~="" then objective_types[kind]=true end
        end
        -- Prefer the current client's structured objective rows. Besides more
        -- accurate text, their type predicts whether the next action is combat,
        -- object interaction, item acquisition, dialogue, or an event/area
        -- trigger. This prevents a noncombat step from falling through to an
        -- unrelated hostile merely because another tracked quest shares it.
        if step.quest_id and live_objectives then
            local ok,rows=pcall(live_objectives,step.quest_id)
            if ok and type(rows)=="table" and #rows>0 then
                step.live_objective_indices={}
                for j,o in ipairs(rows) do
                    if not o.finished and QuestObjectives.includes(step.objective_indices or (step.objective_index and {step.objective_index}),j) then
                        step.live_objective_indices[#step.live_objective_indices+1]=j
                        local text=tostring(o.text or o.description or ""):lower()
                        if text~="" then descriptions[#descriptions+1]=text end
                        remember_objective_type(o.type or o.objective_type)
                    end
                end
            end
        end
        for i=1,quest_log_count() do
            local q=quest_log_title(i)
            if q and q.quest_id==step.quest_id then
                for j=1,quest_objective_count(i) do
                    local o=quest_objective(j,i)
                    if o and not o.is_completed and QuestObjectives.includes(step.objective_indices or (step.objective_index and {step.objective_index}),j) then
                        descriptions[#descriptions+1]=(o.description or ""):lower()
                        remember_objective_type(o.type or o.objective_type)
                    end
                end
            end
        end
        if bridge.quest_map.at and core.time()-bridge.quest_map.at<=10 and bridge.quest_map.objectives and bridge.quest_map.objectives[step.quest_id] then
            local need_bridge_text=#descriptions==0
            for j,o in pairs(bridge.quest_map.objectives[step.quest_id]) do
                if not o.finished and QuestObjectives.includes(step.objective_indices or (step.objective_index and {step.objective_index}),j) then
                    if need_bridge_text then descriptions[#descriptions+1]=(o.text or ""):lower() end
                    remember_objective_type(o.type)
                end
            end
        end
        QuestTargets.configure(step,descriptions)
        local predicted_mode=step.tags and step.tags.NC and "interact" or objective_types.monster and "combat"
            or objective_types.object and "interact"
            or objective_types.item and "item_source"
            or (objective_types.talkto or objective_types.talk) and "dialogue"
            or objective_types.event and "event"
            or objective_types.areatrigger and "event"
            or objective_types.criteria and "event"
            or objective_types.progressbar and "event"
        if predicted_mode and step.predicted_objective_mode~=predicted_mode then
            step.predicted_objective_mode=predicted_mode
            emit("quest_action_predicted",{quest_id=step.quest_id,mode=predicted_mode,
                objective_types=table.concat((function() local out={} for kind in pairs(objective_types) do out[#out+1]=kind end table.sort(out);return out end)(),";")})
        end
        QuestTargets.frontier(step,descriptions)
        QuestTargets.westfall_stew(step,descriptions)
        local objective_signature=table.concat(descriptions,";")
        -- An open authored conversation owns the objective until its choice is resolved.
        if step.tags and step.tags.CHAT and safe_read("quest_dialogue_shown",core.quests.is_gossip_frame_shown,false) then
            if core.time()<next_input then return end
            next_input=core.time()+3
            local read,options=pcall(core.quests.get_gossip_options)
            if not read or type(options)~="table" then
                local failure=not read and tostring(options) or ("invalid_gossip_options_result:"..type(options))
                options={}
                emit("quest_dialogue_read_failed",{quest_id=step.quest_id,objective_index=step.objective_index,error=failure})
            end
            local choice,reason=QuestDialogue.choose(step,options)
            if choice then
                local ran,result=pcall(core.quests.select_gossip_option,choice)
                emit("quest_dialogue_selected",{quest_id=step.quest_id,option_id=choice,accepted=ran and result~=false})
            else
                local names={}
                for i,option in ipairs(options) do
                    if i>8 then break end
                    names[#names+1]=tostring(option.gossip_option_id or option.gossipOptionID or "?")..":"..tostring(option.name or ""):gsub("[\r\n]"," "):sub(1,160)
                end
                emit("quest_dialogue_wait",{quest_id=step.quest_id,objective_index=step.objective_index,reason=reason,options=table.concat(names,";")})
            end
            return
        end
        if step.pending_world_interaction then
            local pending=step.pending_world_interaction
            local _,credit=a.progress_token(step)
            local state,error_id,event=interaction_tracker:status(pending.token,credit)
            if state=="pending" then return end
            interaction_tracker:finish(pending.token);step.pending_world_interaction=nil
            local accepted=state=="accepted"
            local cooldown,attempts=QuestSearch.target_attempt(step,pending.key,objective_signature,core.time(),accepted)
            object_attempts[pending.key]=core.time()+(accepted and math.max(10,cooldown) or math.max(1,cooldown))
            emit("quest_world_object_result",{quest_id=step.quest_id,target=pending.name,state=state,
                event=event,error_id=error_id,cooldown=object_attempts[pending.key]-core.time()})
            if not accepted and error_id and (error_id:find("TOO_FAR",1,true) or error_id:find("OUT_OF_RANGE",1,true)) then
                object_attempts[pending.key]=nil;step.force_close_interaction=pending.key
            elseif attempts>=2 then
                emit("quest_target_deferred_no_progress",{quest_id=step.quest_id,target=pending.name,attempts=attempts,cooldown=cooldown})
            end
        end
        local scan_radius=QuestSearch.radius(step,objective_signature,core.time())
        local obj,d=named_target(step,true)
        if type(pull_moving)=="table" and pull_moving.kind=="quest_target" and pull_moving.object then
            local reserved=pull_moving.object
            local valid,eligible=pcall(function() return reserved:is_valid() and (step.tags and step.tags.NC or QuestTargets.available(reserved)) end)
            if valid and eligible then obj=reserved;d=distance(player():get_position(),reserved:get_position()) end
        end
        if obj then
            local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
            if (object_attempts[key] or 0)>core.time() or not QuestSearch.target_available(step,key,objective_signature,core.time()) then obj=nil end
        end
        if step.objective_mode=="explore" or step.quest_id==52 then obj=nil end
        if not obj and step.objective_mode~="explore" then
            local best=math.huge
            for _,candidate in pairs(objects()) do
                local rescue=rescue_quests[step.quest_id]
                if candidate:is_valid() and (rescue or step.tags and step.tags.NC or QuestTargets.available(candidate)
                    or not player():can_attack(candidate) and QuestTargets.matches(step,candidate:get_name(),candidate:get_npc_id(),false,descriptions)) and candidate.get_name
                    and (object_attempts[candidate.get_guid and tostring(candidate:get_guid()) or tostring(candidate)] or 0)<=core.time()
                    and QuestSearch.target_available(step,candidate.get_guid and tostring(candidate:get_guid()) or tostring(candidate),objective_signature,core.time()) then
                    local name=candidate:get_name():lower();local matches=false
                    if step.npc_id and candidate:get_npc_id()==step.npc_id then matches=true end
                    if step.target_name and name==step.target_name:lower() then matches=true end
                    if step.target_family and name:find(step.target_family,1,true) then matches=true end
                    for _,description in ipairs(descriptions) do
                        if name~="" and description:find(name,1,true) then matches=true end
                    end
                    local mapped=QuestTargets.matches(step,name,candidate:get_npc_id(),player():can_attack(candidate),descriptions)
                    if step.strict_objective_targets or step.quest_id==66106 then matches=mapped
                    elseif mapped then matches=true elseif step.quest_id==52 then matches=false end
                    if rescue then
                        matches=(name=="injured stormwind infantry" or name=="injured stormwind soldier")
                            and not player():can_attack(candidate)
                            and (rescue_attempts[tostring(candidate:get_guid())] or 0)<=core.time()
                    end
                    if matches then local n=distance(player():get_position(),candidate:get_position())
                        if n<best and n<=scan_radius then obj,d,best=candidate,n,n end
                    end
                end
            end
        end
        if not obj and step.objective_mode~="explore" and step.quest_id and step.quest_id~=66106 then
            local ids=QuestieSupport.quest_target_ids(questie,step.quest_id,descriptions)
            local fallback,range=QuestieSupport.nearest_matching(objects(),ids,
                function(candidate) return player():can_attack(candidate) end,
                function(candidate) return distance(player():get_position(),candidate:get_position()) end,scan_radius)
            if fallback then
                obj,d=fallback,range
                if step.questie_exact_target_source~=fallback:get_npc_id() then
                    step.questie_exact_target_source=fallback:get_npc_id()
                    emit("quest_target_resolved",{quest_id=step.quest_id,npc_id=fallback:get_npc_id(),source="questie_quest_objectives"})
                end
            end
        end
        if not obj and step.objective_mode~="explore" and step.quest_id and step.quest_id~=66106 and not step.npc_id
            and not step.target_name and not (step.tags and (step.tags.NC or step.tags.U or step.tags.EAB)) then
            -- An unambiguous hostile is appropriate only for combat or item
            -- acquisition. Structured object/talk/event rows must wait for the
            -- matching object, dialogue target, checkpoint, or client event.
            if not predicted_mode or predicted_mode=="combat" or predicted_mode=="item_source" then
                local fallback,range,source=QuestieSupport.unambiguous_hostile(questie,
                    objects(),function(candidate) return player():can_attack(candidate) end,
                    function(candidate) return distance(player():get_position(),candidate:get_position()) end,scan_radius)
                if fallback then
                    obj,d=fallback,range
                    if step.questie_target_source~=fallback:get_npc_id() then
                        step.questie_target_source=fallback:get_npc_id()
                        emit("quest_target_resolved",{quest_id=step.quest_id,npc_id=fallback:get_npc_id(),source=source})
                    end
                end
            end
        end
        if not obj and step.action=="scenario" and step.scenario_kill_any then
            local best=math.huge
            for _,candidate in pairs(objects()) do
                if candidate:is_valid() and not candidate:is_dead() and player():can_attack(candidate) then
                    local range=distance(player():get_position(),candidate:get_position())
                    if range<best and range<=60 then obj,d,best=candidate,range,range end
                end
            end
        end
        local self_item_action=step.tags and tonumber(step.tags.U) and step.quest_action_mode=="self"
        if step.quest_id==26271 and obj then
            -- The stew is placed at the player. Stand beside the selected
            -- citizen before placing it; the former eight-yard threshold could
            -- be accepted by the input API while missing the quest NPC.
            local range=math.min(step.item_action_range or 4,4)
            if d>range then
                if not refresh_quest_target_route(step,obj,"item_action") then move_to_quest_target(step,obj,"item_action") end
            elseif core.time()>=next_input and not player():is_casting_spell() then
                next_input=core.time()+6.2;nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil
                local accepted=require("quest_actions").dispatch(step,player(),log)
                if accepted then
                    local marked=0;local origin=player():get_position()
                    -- A single pot feeds every eligible citizen in its small
                    -- area. Exclude that entire group until the two-minute fed
                    -- aura expires, then move toward a different citizen.
                    for _,candidate in pairs(objects()) do
                        if is_westfall_homeless(candidate,player()) and distance(origin,candidate:get_position())<=4 then
                            local key=candidate.get_guid and tostring(candidate:get_guid()) or tostring(candidate)
                            object_attempts[key]=core.time()+125;marked=marked+1
                        end
                    end
                    step.dynamic_action_ready=nil
                    emit("westfall_stew_placed",{quest_id=step.quest_id,item_id=tonumber(step.tags.U),citizens_deferred=marked})
                end
            end
            return
        end
        local self_action_ready=self_item_action and (step.dynamic_action_ready
            or step.quest_id~=26271 and (obj or #(step.checkpoints or {})==0))
        if step.quest_id~=26271 and (step.dynamic_extra_action or self_action_ready) and (obj or step.dynamic_action_ready or #(step.checkpoints or {})==0) and core.time()>=next_input and not player():is_casting_spell() then
            next_input=core.time()+3
            local action_target=obj or player()
            local bridge_spell=bridge.extra_action.available and bridge.extra_action.spell_id or nil
            if require("quest_actions").dispatch(step,action_target,log,bridge_spell) then
                emit("quest_extra_action_requested",{quest_id=step.quest_id,action_id=169,target=obj and obj:get_name() or "player"})
            end
        end
        if not obj then
            local point,index=QuestSearch.next(step,core.time())
            if point and not pull_moving then
                local query=step.search_query
                if not query or query.search_index~=index then
                    query={map_position=point,ui_map_id=step.ui_map_id,checkpoints={},search_index=index};step.search_query=query
                end
                local position,reason=a.resolve_position(query)
                if position then
                    step.search_state.pending=true
                    pull_epoch=pull_epoch+1;local epoch=pull_epoch;pull_moving=true
                    emit("quest_search_waypoint",{quest_id=step.quest_id,index=index,count=#step.checkpoints,mode=QuestSearch.mode(step)})
                    a.move(position,function(ok)
                        if epoch~=pull_epoch then return end
                        pull_moving=nil;step.search_query=nil
                        if ok and (step.dynamic_extra_action or self_item_action) then step.dynamic_action_ready=true end
                        QuestSearch.finish(step,index,ok,core.time())
                    end)
                elseif reason~="resolving_destination" then
                    emit("quest_search_destination_failed",{quest_id=step.quest_id,index=index,reason=reason})
                    step.search_query=nil;QuestSearch.finish(step,index,false,core.time())
                end
            elseif step.search_state and step.search_state.pending and not pull_moving then
                -- An interrupted route must be eligible for another request.
                step.search_state.pending=nil
            end
            if core.time()>=(step.rescue_diagnostic_next or 0) then
                step.rescue_diagnostic_next=core.time()+5
                local nearby={}
                for _,candidate in pairs(objects()) do
                    if candidate:is_valid() and candidate.get_name and #nearby<5 then
                        local range=distance(player():get_position(),candidate:get_position())
                        if range<=60 then nearby[#nearby+1]=candidate:get_name()..":"..tostring(candidate:get_npc_id()) end
                    end
                end
                emit(step.objective_mode=="explore" and "quest_exploration_wait" or "quest_target_wait",{quest_id=step.quest_id,reason=step.objective_mode=="explore" and "following_authored_checkpoints" or "no_matching_available_target",radius=scan_radius,
                    objective=table.concat(descriptions,";"),nearby=table.concat(nearby,";"),item_id=step.tags and step.tags.U,
                    extra_action_required=step.tags and step.tags.EAB==true})
            end
            return
        end
        if step.search_state and step.search_state.pending then
            nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil;step.search_state.pending=nil;step.search_query=nil
            step.search_state.next_at=core.time()+10
        end
        if step.emote_token then
            if d>8 then
                if not refresh_quest_target_route(step,obj,"emote") then move_to_quest_target(step,obj,"emote") end
            elseif core.time()>=(step.emote_retry_at or 0) then
                step.emote_retry_at=core.time()+2;nav.stop()
                local ran,result=pcall(core.input.set_target,obj)
                emit("quest_emote_targeted",{quest_id=step.quest_id,token=step.emote_token,npc_id=obj:get_npc_id(),
                    accepted=ran and result~=false,error=not ran and tostring(result) or nil})
            end
            return
        end
        if step.vehicle_action_slots then
            local range=30
            if d>range then
                if not refresh_quest_target_route(step,obj,"vehicle") then move_to_quest_target(step,obj,"vehicle") end
            elseif d<=range and core.time()>=next_input and not player():is_casting_spell() then
                next_input=core.time()+1;nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil
                local ran,result=pcall(core.input.look_at,obj:get_position())
                if not ran or result==false then emit("quest_vehicle_face_rejected",{quest_id=step.quest_id,error=not ran and tostring(result) or nil}) end
                require("quest_actions").vehicle(step,obj,log,bridge.vehicle_actions.slots)
            end
            return
        elseif step.extra_action_spell_id or step.tags and tonumber(step.tags.U) then
            local range=step.item_action_range or (step.quest_id==26391 and 8 or 30)
            if d>range then
                if not refresh_quest_target_route(step,obj,"item_action") then move_to_quest_target(step,obj,"item_action") end
            elseif d<=range and core.time()>=next_input and not player():is_casting_spell() then
                next_input=core.time()+3;nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil
                local ran,result=pcall(core.input.look_at,obj:get_position())
                if not ran or result==false then emit("quest_item_face_rejected",{quest_id=step.quest_id,error=not ran and tostring(result) or nil}) end
                emit("quest_item_requested",{quest_id=step.quest_id,item_id=step.tags and tonumber(step.tags.U),mode=step.quest_id==26391 and "facing" or "target"})
                local accepted=require("quest_actions").dispatch(step,obj,log)
                if accepted then
                    local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
                    local cooldown,attempts=QuestSearch.target_attempt(step,key,objective_signature,core.time(),true)
                    object_attempts[key]=core.time()+math.max(step.quest_id==26271 and 125 or 4,cooldown)
                    if attempts>=2 then emit("quest_target_deferred_no_progress",{quest_id=step.quest_id,target=obj:get_name(),attempts=attempts,cooldown=cooldown}) end
                end
            end
            -- Spell/item actions own this target. Do not also run the ordinary
            -- click branch, which redispatches movement and interrupts casts.
            return
        elseif not (step.tags and step.tags.NC) and player():can_attack(obj) then
            local selected={};for k,v in pairs(step) do selected[k]=v end
            selected.npc_id=obj:get_npc_id();selected.live_target=obj;a.handlers.kill_target(selected)
            -- Combat owns this hostile; never also approach it as a clickable object.
            return
        elseif player():can_attack(obj) then return
        end
        -- World quest objects often need the player much closer than NPC
        -- interaction range.  Drive to the live object's position until we
        -- are inside a reliable use range, then stop before clicking it.
        local current_key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
        local object_use_range=(obj.is_unit and not obj:is_unit()) and 2.25 or 4
        if step.force_close_interaction==current_key then object_use_range=0.75 end
        if step.quest_id==26230 and not player():can_attack(obj) then object_use_range=1.75 end
        if d>object_use_range then
            if not refresh_quest_target_route(step,obj,"world_object") then move_to_quest_target(step,obj,"world_object") end
        elseif d<=object_use_range and core.time()>=next_input then
            if step.tags and step.tags.CHAT and safe_read("quest_dialogue_shown",core.quests.is_gossip_frame_shown,false) then
                next_input=core.time()+3
                local read,options=pcall(core.quests.get_gossip_options)
                if not read or type(options)~="table" then
                    local failure=not read and tostring(options) or ("invalid_gossip_options_result:"..type(options))
                    options={}
                    emit("quest_dialogue_read_failed",{quest_id=step.quest_id,objective_index=step.objective_index,error=failure})
                end
                local choice,reason=QuestDialogue.choose(step,options)
                if choice then
                    local ran,result=pcall(core.quests.select_gossip_option,choice)
                    local accepted=ran and result~=false
                    emit("quest_dialogue_selected",{quest_id=step.quest_id,option_id=choice,accepted=accepted,error=not ran and tostring(result) or nil})
                    if accepted and step.quest_id==26209 then
                        local key=obj.get_guid and tostring(obj:get_guid()) or tostring(obj)
                        object_attempts[key]=core.time()+120
                    end
                else
                    local names={};for _,option in ipairs(options or {}) do names[#names+1]=option.name end
                    emit("quest_dialogue_wait",{quest_id=step.quest_id,reason=reason,options=table.concat(names,";")})
                end
                return
            end
            next_input=core.time()+1;emit("quest_object_interact",{quest_id=step.quest_id,npc_id=obj:get_npc_id()})
            if rescue_quests[step.quest_id] then rescue_attempts[tostring(obj:get_guid())]=core.time()+10 end
            if obj.is_unit and not obj:is_unit() and core.input.use_object then
                a.stop()
                local accepted,interaction_reason=SafeInteraction.dispatch(core.input,obj,"use")
                local key=current_key
                if accepted then
                    step.force_close_interaction=nil
                    step.pending_world_interaction={token=interaction_tracker:begin(key,3,{quest_id=step.quest_id,credit=select(2,a.progress_token(step)),target=key,range=d,item_id=step.item_id}),key=key,name=obj:get_name()}
                    object_pending_until=core.time()+1.25
                else
                    local cooldown,attempts=QuestSearch.target_attempt(step,key,objective_signature,core.time(),false)
                    object_attempts[key]=core.time()+math.max(3,cooldown)
                    if attempts>=2 then emit("quest_target_deferred_no_progress",{quest_id=step.quest_id,target=obj:get_name(),attempts=attempts,cooldown=cooldown}) end
                end
                emit("quest_world_object_use",{quest_id=step.quest_id,object_id=obj:get_npc_id(),accepted=accepted,reason=interaction_reason})
            else
                local accepted,interaction_reason=SafeInteraction.dispatch(core.input,obj,"interact")
                local key=current_key
                if accepted then
                    step.pending_world_interaction={token=interaction_tracker:begin(key,3,{quest_id=step.quest_id,credit=select(2,a.progress_token(step)),target=key,range=d,item_id=step.item_id}),key=key,name=obj:get_name(),kind="unit"}
                    object_pending_until=core.time()+1.25
                else
                    local cooldown,attempts=QuestSearch.target_attempt(step,key,objective_signature,core.time(),false)
                    object_attempts[key]=core.time()+math.max(3,cooldown)
                    if attempts>=2 then emit("quest_target_deferred_no_progress",{quest_id=step.quest_id,target=obj:get_name(),attempts=attempts,cooldown=cooldown}) end
                end
                emit("quest_unit_interact",{quest_id=step.quest_id,npc_id=obj:get_npc_id(),accepted=accepted,reason=interaction_reason})
            end
        end
    end
    a.handlers.kill_target = function(step)
        if not step.npc_id then return end
        local obj=step.live_target
        if obj and (not obj:is_valid() or obj:is_dead()) then obj=nil end
        local d=obj and distance(player():get_position(),obj:get_position())
        if not obj then obj,d=target(step.npc_id,true) end
        if obj and player():can_attack(obj) and d <= (step.search_radius or 40) then
            local target_ran,target_result=pcall(core.input.set_target,obj)
            if not target_ran or target_result==false then
                emit("combat_target_rejected",{quest_id=step.quest_id,npc_id=step.npc_id,
                    error=not target_ran and tostring(target_result) or nil})
            end
            if d<=4 and core.time()>=attack_next then
                local ok,helper=pcall(require,"common/utility/auto_attack_helper")
                if ok and helper and helper.start_attack then
                    local ran,accepted=pcall(helper.start_attack,helper,obj,6603)
                    accepted=ran and accepted~=false
                    emit("quest_auto_attack_requested",{quest_id=step.quest_id,npc_id=step.npc_id,accepted=accepted})
                    attack_next=core.time()+1
                end
            end
            if profile and profile.built_in_combat and d<=40 then
                if combat_tick(obj) then nav.stop();pull_epoch=pull_epoch+1;pull_moving=nil;return end
                if combat and combat.chasing then return end
            end
            local spell=step.pull_spell_id or (profile and profile.pull_spell_id) or 6603
            local range=step.pull_range or 4
            if d>range then
                if not refresh_quest_target_route(step,obj,"combat_pull") then move_to_quest_target(step,obj,"combat_pull") end
            elseif d<=range and core.time()>=pull_next and core.spell_book.is_spell_known(spell) then
                nav.stop();pull_next=core.time()+3
                local face_ran,face_result=pcall(core.input.look_at,obj:get_position())
                if not face_ran or face_result==false then
                    emit("combat_face_rejected",{npc_id=step.npc_id,error=not face_ran and tostring(face_result) or nil})
                end
                -- One pull request enters combat; existing rotations own combat thereafter.
                local cast_ran,cast_result=pcall(core.input.cast_target_spell,spell,obj)
                emit("combat_pull_requested",{npc_id=step.npc_id,spell_id=spell,
                    accepted=cast_ran and cast_result~=false,error=not cast_ran and tostring(cast_result) or nil})
            end
        end
    end
    a.handlers.use_world_object = function(step)
        if core.time() < next_input or not step.npc_id then return end
        local obj,d = target(step.npc_id)
        if obj and d <= (step.interaction_range or 4) then
            next_input = core.time()+0.8
            local accepted,reason=SafeInteraction.dispatch(core.input,obj,"use")
            emit("world_object_use",{npc_id=step.npc_id,accepted=accepted,reason=reason})
        end
    end
    local classes={[1]="WARRIOR",[2]="PALADIN",[3]="HUNTER",[4]="ROGUE",[5]="PRIEST",
        [6]="DEATHKNIGHT",[7]="SHAMAN",[8]="MAGE",[9]="WARLOCK",[10]="MONK",[11]="DRUID",
        [12]="DEMONHUNTER",[13]="EVOKER"}
    local function inventory()
        local items,worn={},{}
        local free=0
        for bag=0,4 do
            local size=safe_read("bag_slots",core.inventory.get_num_bag_slots,0,bag+1) or 0
            for wow_slot=1,size do
                -- get_num_bag_slots uses shifted 1..5 IDs, while every item
                -- operation uses the inventory-helper container pair 0..4
                -- and the core's container slot is WoW's slot plus one.
                local slot=wow_slot+1
                local link=safe_read("bag_item_link",core.inventory.get_container_item_link,nil,bag,slot)
                if link and link~="" then
                    local id=tonumber(link:match("item:(%d+)"))
                    items[#items+1]={id=id,bag=bag,slot=slot,link=link,
                        info=safe_read("item_info",core.quests.get_item_info,nil,link),
                        stats=safe_read("bag_item_stats",core.inventory.get_container_item_stats,nil,bag,slot)}
                else free=free+1 end
            end
        end
        local durability=1
        for slot=1,19 do
            local link=safe_read("equipped_item_link",core.inventory.get_inventory_item_link,nil,slot)
            if link and link~="" then worn[slot]={link=link,
                info=safe_read("item_info",core.quests.get_item_info,nil,link),
                stats=safe_read("equipped_item_stats",core.inventory.get_inventory_item_stats,nil,slot)} end
            local d=safe_read("item_durability",core.inventory.get_item_durability,nil,slot)
            if d and (d.max or 0)>0 then durability=math.min(durability,(d.current or 0)/d.max) end
        end
        return {items=items,worn=worn,free_slots=free,durability=durability,
            money=safe_read("gold",core.inventory.get_gold,0) or 0,
            character={class=classes[player():get_class()],
                spec=safe_read("equipment_specialization",core.game_ui.get_specialization,nil),level=player():get_level()}}
    end
    local merchant=false
    local previous_event=a.event
    a.event=function(event,args)
        previous_event(event,args)
        if talent_manager and talent_manager.event then talent_manager:event(event) end
        if event=="MERCHANT_SHOW" then merchant=true elseif event=="MERCHANT_CLOSED" then merchant=false end
    end
    a.handlers.vendor_purchase=function(step)
        if (not step.item_goal.item_id or step.vendor_slot==nil) and bridge.merchant.count and bridge.merchant.count>0 then
            local wanted=tostring(step.item_goal.name or step.target_name or ""):lower()
            for _,row in ipairs(bridge.merchant.items or {}) do
                local match=step.item_goal.item_id and row.item_id==step.item_goal.item_id
                    or wanted~="" and tostring(row.name or ""):lower()==wanted
                if match then
                    step.vendor_slot=row.slot
                    if row.item_id and row.item_id>0 then step.item_goal.item_id=row.item_id end
                    emit("quest_vendor_slot_resolved",{source="companion_bridge",item_id=step.item_goal.item_id,live_slot=row.slot})
                    break
                end
            end
        end
        local count=a.item_goal_count(step.item_goal)
        if count and count>=step.item_goal.count then
            if merchant and core.input.close_merchant then safe_input("quest_vendor_close",core.input.close_merchant) end
            return
        end
        if player():is_in_combat() or core.time()<(step.purchase_retry_at or 0) then return end
        if merchant then
            step.purchase_retry_at=core.time()+2
            local remaining=math.max(1,step.item_goal.count-(count or 0))
            local slot=step.vendor_slot
            -- Retail vendor slots can shift with character state. Current cores
            -- expose a live C_MerchantFrame catalog; resolve it before requiring a
            -- static slot and match by normalized name when an item ID is absent.
            if core.game_ui.get_vendor_item_count and core.game_ui.get_vendor_item_info then
                local live_count=safe_read("vendor_item_count",core.game_ui.get_vendor_item_count,0)
                if type(live_count)=="number" and live_count>0 then
                    local wanted_name=tostring(step.item_goal.name or ""):lower():gsub("^%s+",""):gsub("%s+$","")
                    local live_slot
                    for i=1,live_count do
                        local info=safe_read("vendor_item_info",core.game_ui.get_vendor_item_info,nil,i)
                        local id=info and tonumber(info.item_id)
                        local name=info and tostring(info.item_name or ""):lower():gsub("^%s+",""):gsub("%s+$","") or ""
                        if info and ((step.item_goal.item_id and id==step.item_goal.item_id)
                            or (not step.item_goal.item_id and wanted_name~="" and name==wanted_name)) then
                            live_slot=tonumber(info.vendor_item_index) or i
                            if id and id>0 then step.item_goal.item_id=id end
                            break
                        end
                    end
                    if live_slot then slot=live_slot end
                end
            end
            if not slot then
                emit("quest_vendor_catalog_wait",{item_id=step.item_goal.item_id,item_name=step.item_goal.name,bridge=bridge.loaded})
                return
            end
            if slot~=step.vendor_slot then emit("quest_vendor_slot_resolved",{item_id=step.item_goal.item_id,static_slot=step.vendor_slot,live_slot=slot}) end
            local accepted=safe_input("quest_vendor_purchase",core.input.buy_item,slot,remaining)
            emit("quest_vendor_purchase_requested",{item_id=step.item_goal.item_id,slot=slot,
                quantity=remaining,vendor=step.target_name,accepted=accepted})
            return
        end
        if safe_read("vendor_gossip_shown",core.quests.is_gossip_frame_shown,false) then
            for _,option in ipairs(safe_read("quest_vendor_gossip",core.quests.get_gossip_options,{}) or {}) do
                if tostring(option.gossip_type):lower()=="vendor" then
                    step.purchase_retry_at=core.time()+1
                    emit("quest_vendor_gossip_selected",{vendor=step.target_name,option_id=option.gossip_option_id})
                    safe_input("quest_vendor_gossip",core.quests.select_gossip_option,option.gossip_option_id);return
                end
            end
        end
        local obj,d=named_target(step,true)
        if not obj and step.map_position then
            local p=player();local best,best_distance=nil,math.huge
            for _,candidate in pairs(objects()) do
                if candidate:is_valid() and candidate.get_npc_flags and not candidate:is_dead() and not p:can_attack(candidate) then
                    local flags=candidate:get_npc_flags() or 0;local distance_to_player=distance(p:get_position(),candidate:get_position())
                    local distance_to_anchor=distance(step.map_position,candidate:get_position())
                    if vendor_flag(flags) and distance_to_player<=15 and distance_to_anchor<=15 and distance_to_player<best_distance then
                        obj,d,best_distance=candidate,distance_to_player,distance_to_player
                    end
                end
            end
        end
        if not obj then
            if core.time()>=(step.purchase_log_at or 0) then
                step.purchase_log_at=core.time()+5
                emit("quest_vendor_wait",{vendor=step.target_name,npc_id=step.npc_id})
            end
            return
        end
        if d>4 and not pull_moving then
            pull_epoch=pull_epoch+1;local epoch=pull_epoch;pull_moving=true
            a.move(obj:get_position(),function() if epoch==pull_epoch then pull_moving=nil end end)
        elseif d<=4 then
            step.purchase_retry_at=core.time()+1
            a.stop();emit("quest_vendor_interact",{vendor=step.target_name,npc_id=obj:get_npc_id()})
            safe_input("quest_vendor_interact",core.input.interact_with_object,obj)
        end
    end
    local function bit(flags,value) return npc_flag(flags,value) end
    local function choose_vendor(repair,excluded)
        local p=player();local context=core.get_map_id();local instance=core.get_instance_id()
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj.get_npc_flags and not obj:is_dead() and not p:is_enemy_with(obj) then
                local flags=obj:get_npc_flags()
                if vendor_flag(flags) or bit(flags,4096) then
                    local v=obj:get_position();local id=obj:get_npc_id()
                    local cache_key=table.concat({tostring(instance),tostring(context),tostring(id)},":")
                    seen_vendors[cache_key]={key=cache_key,npc_id=id,repair=bit(flags,4096),world_map_id=context,instance_id=instance,
                        position={x=v.x,y=v.y,z=v.z}}
                end
            end
        end
        local best,dist=nil,math.huge
        for _,vendor in pairs(seen_vendors) do
            if vendor.instance_id==instance and vendor.world_map_id==context and (not repair or vendor.repair)
                and not (excluded and excluded[vendor.key or tostring(vendor.npc_id)]) then
                local d=distance(p:get_position(),vendor.position)
                if d<dist then vendor.distance=d;best,dist=vendor,d end
            end
        end
        for _,vendor in ipairs(profile and profile.vendors or {}) do
            local key=vendor.npc_id and tostring(vendor.npc_id) or table.concat({tostring(vendor.position.x or ""),tostring(vendor.position.y or ""),tostring(vendor.position.z or "")},":")
            if vendor.instance_id==instance and (not vendor.world_map_id or vendor.world_map_id==context)
                and (not repair or vendor.repair)
                and not (excluded and excluded[key]) then
                local d=distance(p:get_position(),vendor.position)
                if d<dist then vendor.key=key;vendor.distance=d;best,dist=vendor,d end
            end
        end
        return best
    end
    local function service_input(name,fn,...)
        if type(fn)~="function" then emit(name.."_rejected",{error="input_unavailable"});return false end
        local ran,result=pcall(fn,...)
        if not ran or result==false then
            emit(name.."_rejected",{error=not ran and tostring(result) or nil})
            return false
        end
        return true
    end
    local function service_read(name,fn,fallback,...)
        if type(fn)~="function" then emit(name.."_unavailable");return fallback end
        local ran,result=pcall(fn,...)
        if not ran then emit(name.."_read_failed",{error=tostring(result)});return fallback end
        return result
    end
    local service_api={log=emit,time=core.time,inventory=inventory,choose_vendor=choose_vendor,stop=a.stop,
        move=function(p,cb) if a.movement_owner then a.movement_owner('vendor') end;a.stop();a.move(p,cb) end,
        merchant_open=function() return merchant end,
        interact_vendor=function(vendor)
            local options=service_read("vendor_gossip",core.quests.get_gossip_options,{}) or {}
            if type(options)~="table" then emit("vendor_gossip_read_failed",{error="invalid_gossip_options_result:"..type(options)});options={} end
            for _,option in ipairs(options) do
                if tostring(option.gossip_type):lower()=="vendor" then
                    return service_input("vendor_gossip",core.quests.select_gossip_option,option.gossip_option_id)
                end
            end
            local obj,d=target(vendor.npc_id)
            if obj and d<=4 then return service_input("vendor_interact",core.input.interact_with_object,obj) end
            return false
        end,
        can_repair=function() return service_read("repair_capability",core.inventory.can_merchant_repair,false) end,
        repair_cost=function() return service_read("repair_cost",core.inventory.get_total_repair_cost,math.huge) end,
        repair=function()
            emit("repair_requested")
            local accepted=service_input("repair",core.input.repair_all_items,false)
            emit("repair_result",{accepted=accepted});return accepted
        end,
        bag_link=function(bag,slot) return service_read("bag_link",core.inventory.get_container_item_link,nil,bag,slot) end,
        sell=function(bag,slot)
            emit("sale_requested",{bag=bag,slot=slot,item=service_read("bag_link",core.inventory.get_container_item_link,nil,bag,slot)})
            local accepted=service_input("sale",core.input.use_container_item,bag,slot)
            emit("sale_dispatched",{bag=bag,slot=slot,accepted=accepted});return accepted
        end,
        close_merchant=function() return service_input("merchant_close",core.input.close_merchant) end,
        equipped_link=function(slot) return service_read("equipped_link",core.inventory.get_inventory_item_link,nil,slot) end,
        pending_equip_slot=function() return service_read("pending_equip_slot",core.game_ui.get_pending_equip_slot,nil) end,
        confirm_equip=function(slot) return service_input("equip_confirm",core.input.equip_pending_item,slot) end,
        clear_equip=function(slot)
            if service_read("pending_equip_slot",core.game_ui.get_pending_equip_slot,nil)==slot then service_input("equip_cancel",core.input.cancel_pending_equip,slot) end
            if service_read("cursor_item",core.game_ui.has_cursor_item,false) and core.input.clear_cursor then service_input("cursor_clear",core.input.clear_cursor) end
        end,
        equip=function(bag,slot,dest)
            emit("equip_requested",{bag=bag,slot=slot,destination=dest});a.stop()
            local accepted=service_input("equip",core.input.equip_container_item,bag,slot,dest)
            emit("equip_result",{accepted=accepted});return accepted
        end,
    }
    services=Services.new(service_api,profile and profile.service_policy)
    a.equipment_tick=function()
        local p=player()
        if not p or not p:is_valid() or p:is_dead() or p:is_ghost() or p:is_in_combat()
            or p:is_casting_spell() or p:is_channelling_spell() then return nil end
        if safe_read("loot_item_count",core.game_ui.get_loot_item_count,0)>0 then return nil end
        return services:tick(true)
    end

    loot_generation=0
    local vendor_scan_next=0
    local loot_next=0
    local loot_cooldowns={}
    local background_item_attempted={}
    local background_item_next=0
    local background_spell_attempted={}
    local function loot_key(obj) return obj.get_guid and tostring(obj:get_guid()) or tostring(obj) end
    local loot_deadline=0
    a.cancel_maintenance=function()
        if world_transport_job and world_transport_job.approaching then a.stop() end
        if pull_moving then pull_epoch=pull_epoch+1;pull_moving=nil;nav.stop() end
        if services.state~="idle" then services:cancel() end
        if loot_pending then loot_generation=loot_generation+1;loot_pending=nil;nav.stop() end
    end
    local quest_utilities=require("quest_utilities").new()
    a.maintenance=function()
        -- Utility items must not replace the world-object objective or cancel its route.
        quest_utilities:tick(core.time(),{
            active=quest_accepted(66324),
            busy=player():is_casting_spell() or player():is_channelling_spell(),
            count=function(id) return a.item_goal_count({item_id=id}) end,
            cooldown=function(id) return a.cooldown_remaining("item",id) end,
            use=function(id) return safe_input("quest_utility_item",core.input.use_item,id) end,
            log=emit,
        })
        talent_manager:tick()
        if core.game_ui.get_loot_item_count and core.input.loot_item then
            local count=safe_read("loot_item_count",core.game_ui.get_loot_item_count,0)
            local slot,item
            if type(count)=="number" and count>0 then
                for index=0,count-1 do
                    local id=safe_read("loot_item_id",core.game_ui.get_loot_item_id,nil,index)
                    local gold=safe_read("loot_is_gold",core.game_ui.get_loot_is_gold,false,index)
                    if (type(id)=="number" and id>0) or gold then slot,item=index,id or "gold";break end
                end
            end
            if slot~=nil then
                local signature=tostring(count)..":"..slot..":"..tostring(item)
                if signature~=a.loot_signature then a.loot_signature=signature;a.loot_progress_at=core.time();a.loot_ignored=nil end
                if core.time()-(a.loot_progress_at or core.time())>=8 and not a.loot_ignored then
                    a.loot_ignored=true;emit("loot_window_stalled",{slot=slot,slots=count})
                    if core.input.close_loot then
                        local ran,result=pcall(core.input.close_loot)
                        if not ran or result==false then emit("loot_window_close_rejected",{error=not ran and tostring(result) or nil}) end
                    end
                end
                if not a.loot_ignored then
                    a.stop()
                    if core.time()>=(a.loot_slot_next or 0) then
                        a.loot_slot_next=core.time()+0.2
                        local ran,result=pcall(core.input.loot_item,slot)
                        if not ran or result==false then
                            a.loot_slot_next=core.time()+1
                            emit("loot_window_slot_rejected",{slot=slot,slots=count,error=not ran and tostring(result) or nil})
                        else
                            emit("loot_window_slot_requested",{slot=slot,slots=count})
                        end
                    end
                    return "looting_open_window"
                end
            else a.loot_signature=nil;a.loot_ignored=nil end
        end
        -- Hidden RestedXP #completewith item rows are persistent bag actions,
        -- not quest objectives.  Try at most one item per maintenance pass and
        -- once per runtime session.  This prevents repeated use of buff items
        -- while still consuming explicitly authored tokens and utility items.
        local auto_items=profile and profile.service_policy and profile.service_policy.auto_use_items or {}
        if #auto_items>0 and core.time()>=background_item_next and not player():is_in_combat()
            and not player():is_casting_spell() and not player():is_channelling_spell() then
            for _,item_id in ipairs(auto_items) do
                if not background_item_attempted[item_id] then
                    local count=a.item_goal_count({item_id=item_id})
                    if count and count>0 then
                        background_item_attempted[item_id]=true;background_item_next=core.time()+2
                        a.stop()
                        local accepted=safe_input("background_item_use",core.input.use_item,item_id)
                        emit("background_item_use_requested",{item_id=item_id,count=count,accepted=accepted})
                        return "using_background_item"
                    end
                end
            end
        end
        local auto_spells=profile and profile.service_policy and profile.service_policy.auto_use_spells or {}
        if #auto_spells>0 and core.time()>=background_item_next and not player():is_in_combat()
            and not player():is_casting_spell() and not player():is_channelling_spell() then
            for _,spell_id in ipairs(auto_spells) do
                if not background_spell_attempted[spell_id] and core.spell_book.is_spell_known(spell_id)
                    and core.spell_book.is_usable_spell(spell_id) then
                    background_spell_attempted[spell_id]=true;background_item_next=core.time()+2;a.stop()
                    local accepted=safe_input("background_spell",core.input.cast_target_spell,spell_id,player())
                    emit("background_spell_requested",{spell_id=spell_id,accepted=accepted})
                    return "using_background_spell"
                end
            end
        end
        if core.time()>=vendor_scan_next then vendor_scan_next=core.time()+4;choose_vendor(false) end
        if death_job then death_job=nil;emit("death_recovery_finished") end
        local state=services:tick()
        if state then
            if pull_moving then pull_epoch=pull_epoch+1;pull_moving=nil end
            if loot_pending then loot_generation=loot_generation+1;loot_pending=nil end
            return state
        end
        local now=core.time()
        if loot_pending then
            if now>loot_deadline or not loot_pending:is_valid() or not loot_pending:can_be_looted() then
                loot_cooldowns[loot_key(loot_pending)]=now+30
                loot_pending=nil;nav.stop();loot_next=now+1;return "loot_finished"
            end
            local d=distance(player():get_position(),loot_pending:get_position())
            if d<=4 and now>=loot_next then
                local corpse=loot_pending
                nav.stop();loot_next=now+1
                local ran,result=pcall(core.input.loot_object,corpse,true)
                if not ran or result==false then
                    emit("loot_rejected",{npc_id=corpse:get_npc_id(),error=not ran and tostring(result) or nil})
                else
                    emit("loot_requested",{npc_id=corpse:get_npc_id()})
                end
            end
            return "looting"
        end
        if now<loot_next then return nil end
        loot_next=now+1
        local nearest,best=nil,30
        for _,obj in pairs(objects()) do
            if obj:is_valid() and obj:is_dead() and obj:can_be_looted() and (loot_cooldowns[loot_key(obj)] or 0)<=now then
                local d=distance(player():get_position(),obj:get_position())
                if d<best then nearest,best=obj,d end
            end
        end
        if nearest then
            pull_epoch=pull_epoch+1;pull_moving=nil
            loot_pending=nearest;loot_deadline=now+25;loot_generation=loot_generation+1
            local epoch=loot_generation
            if a.movement_owner then a.movement_owner('loot') end
            a.stop()
            a.move(nearest:get_position(),function(ok)
                if epoch==loot_generation and not ok then loot_pending=nil;loot_next=core.time()+10 end
            end)
            return "loot_travel"
        end
    end
    local Policy=require('route_policy')
    local owner=Policy.owner({stop=function(previous,next_owner)
        -- A verified incoming flight job exists before ownership is claimed.
        -- Cancel outgoing movement without deleting that newly prepared job.
        local incoming=next_owner=='flight' and flight and flight.job
        a.stop()
        if incoming then flight.job=incoming end
    end,log=log})
    a.movement_owner=function(name) return owner:claim(name) end
    local DataAPI=require('path_learning').runtime_api()
    local phase_proxy,phase_proxy_at
    local function quest_phase_context()
        local now=core.time()
        if phase_proxy and now<(phase_proxy_at or 0) then return phase_proxy end
        local ids,seen={},{}
        for _,step in ipairs(profile and profile.steps or {}) do
            if step.quest_id and not seen[step.quest_id] then ids[#ids+1]=step.quest_id;seen[step.quest_id]=true end
        end
        table.sort(ids);local hash=0
        for _,id in ipairs(ids) do
            local accepted=a.on_quest and a.on_quest(id)==true
            local completed=a.turned_in and a.turned_in(id)==true
            hash=(hash*31+id*3+(completed and 2 or accepted and 1 or 0))%2147483647
        end
        phase_proxy=tostring(hash);phase_proxy_at=now+5;return phase_proxy
    end
    local function learning_context()
        return table.concat({tostring(profile and profile.id or 'unknown'),tostring(profile and profile.game_version or 'unknown'),
            tostring(core.get_map_id and core.get_map_id() or 0),tostring(core.get_instance_id and core.get_instance_id() or 0)},':')
    end
    local Failures=require('destination_failures').new({read=DataAPI.read,write=DataAPI.write,
        time=function() return os and os.time and os.time() or core.time() end,context=function() return learning_context()..':quest_phase:'..quest_phase_context() end})
    a.destination_result=function() end -- Results are recorded once by the shared movement adapter below.
    local original_move=a.move
    a.move=function(p,callback)
        -- Capture the request context; a later map/quest transition must not poison its new layer.
        p.failure_context=learning_context()..':quest_phase:'..quest_phase_context()
        local original_callback=callback
        local generation=owner.generation
        callback=function(ok,reason)
            if generation~=owner.generation then return end
            if ok then Failures:clear(p) elseif TravelDecision.failure(reason)~="service" and TravelDecision.failure(reason)~="interrupted" then Failures:record(p,reason) end
            if original_callback then original_callback(ok,reason) end
        end
        if Failures:blocked(p) and nav.detour and not player():is_flying() then
            local handled=nav.detour(p,function(ok,why)
                if generation~=owner.generation then return end
                if not ok and (why=="detour_not_needed_for_close_approach" or why=="no_verified_detour") then
                    emit('remembered_destination_normal_approach',{x=p.x,y=p.y,z=p.z})
                    return original_move(p,callback)
                end
                if callback then callback(ok,why) end
            end)
            if handled then emit('remembered_destination_replanned',{x=p.x,y=p.y,z=p.z});return end
        end
        return original_move(p,callback)
    end
    local Learner=require('manual_action_learning').new({read=DataAPI.read,write=DataAPI.write,context=learning_context,log=log})
    local manual_step,manual_contact,manual_cast
    local function observed_state(step)
        local _,progress=a.progress_token(step)
        return {accepted=a.on_quest and a.on_quest(step.quest_id)==true,
            turned_in=a.turned_in and a.turned_in(step.quest_id)==true,progress=progress}
    end
    a.manual_action_begin=function(step)
        owner:claim('manual');manual_step=step;manual_contact=nil;manual_cast=nil
        if step and step.quest_id then Learner:begin(step,observed_state(step)) end
    end
    a.manual_action_tick=function()
        if not manual_step or not manual_step.quest_id then return end
        local obj=RuntimeApi.mouseover()
        if not obj or not obj:is_valid() then obj=named_target(manual_step,true) end
        local contact
        if obj and distance(player():get_position(),obj:get_position())<=6 then
            local p=obj:get_position();contact={id=obj:get_npc_id(),x=p.x,y=p.y,z=p.z};manual_contact={at=core.time(),value=contact}
        elseif manual_contact and core.time()-manual_contact.at<10 then contact=manual_contact.value
        else local p=player():get_position();contact={id=0,x=p.x,y=p.y,z=p.z} end
        contact.spell_id=0;contact.item_id=0
        if manual_cast and core.time()-manual_cast.at<10 then contact.spell_id=manual_cast.spell_id;contact.item_id=manual_cast.item_id end
        local saved=Learner:observe(observed_state(manual_step),contact)
        if saved then manual_cast=nil end
        return saved
    end
    a.manual_action_end=function() manual_step=nil;manual_cast=nil;manual_contact=nil;Learner:finish() end
    local before_learning_event=a.event
    a.event=function(event,args)
        before_learning_event(event,args)
        if not manual_step or event~='UNIT_SPELLCAST_SUCCEEDED' or not args or args[1]~='player' or player():is_in_combat() then return end
        local id=tonumber(args[#args]);if not id or not require("manual_action_learning").quest_spell(id) then return end
        local items={};local matches=0;local item_id
        if core.quests.get_item_spell and core.inventory and core.inventory.get_num_bag_slots and core.inventory.get_container_item_link then
            for bag=0,4 do
                local size=safe_read('manual_bag_size',core.inventory.get_num_bag_slots,0,bag+1)
                for slot=2,math.min(100,size+1) do
                    local link=safe_read('manual_item_link',core.inventory.get_container_item_link,nil,bag,slot)
                    local item=link and tonumber(link:match('item:(%d+)'))
                    if item and not items[item] then
                        items[item]=true;local spell=safe_read('manual_item_spell',core.quests.get_item_spell,nil,item)
                        if spell and spell.spell_id==id then matches=matches+1;item_id=item end
                    end
                end
            end
        end
        if matches==1 then manual_cast={at=core.time(),spell_id=0,item_id=item_id}
        elseif matches==0 and core.spell_book.is_spell_known(id) then manual_cast={at=core.time(),spell_id=id,item_id=0} end
    end
    local progress_before_learning=a.note_step_progress
    a.note_step_progress=function(step)
        step.manual_spell_attempts=0;step.manual_spell_deferred=nil
        if step.learned_action_applied then Learner:succeeded(step) end
        return progress_before_learning(step)
    end
    local QuestRecovery=require("quest_recovery").new({read=DataAPI.read,write=DataAPI.write,
        context=function()
            local p=player()
            return learning_context()..":"..tostring(p and p.get_guid and p:get_guid() or p and p.get_name and p:get_name() or "unknown_character")
        end,time=function() return os and os.time and os.time() or core.time() end,
        log=function(event,data) emit(event,data) end})
    a.quest_recovery_due=function(step,token,value,protected)
        return QuestRecovery:observe(step,token,value,protected)
    end
    local recover_before_learning=a.recover_step
    a.recover_step=function(step,attempt)
        local stage,sequence_attempt=QuestRecovery:attempt(step)
        if not stage then return false end
        local retired=false
        if stage=="discard_learned_action" then
            step.manual_spell_attempts=3
            if step.learned_action_applied then
                for i=1,3 do if Learner:failed(step) then retired=true;break end end
            end
        end
        if stage=="refresh_targets" then step.live_target=nil;step.target_scan=nil;step.target_memory=nil end
        if step.learned_action_applied and (retired or Learner:failed(step)) then
            local original=step.learned_action_original or {}
            step.npc_id=original.npc_id;step.quest_action_mode=original.mode
            if step.tags then step.tags.U=original.item end
            step.manual_contact_learned=nil;step.learned_action_applied=nil
            emit("learned_action_retired",{quest_id=step.quest_id,reason="repeated_no_progress"})
        end
        return recover_before_learning(step,sequence_attempt or attempt)
    end
    local original_resolve=a.resolve_position
    a.resolve_position=function(step)
        step.interaction_range=step.interaction_range or Policy.arrival(step.action,nil,
            step.tags and tonumber(step.tags.U) and 'item' or step.action=='collect' and 'object' or nil)
        local learned=Learner:lookup(step)
        if learned then
            if not step.learned_action_applied then
                step.learned_action_original={npc_id=step.npc_id,mode=step.quest_action_mode,item=step.tags and step.tags.U}
                step.learned_action_applied=true
            end
            if step.action=='objective' and learned.item_id and learned.item_id>0 then
                step.tags=step.tags or {};step.tags.U=learned.item_id;step.quest_action_mode=learned.id>0 and 'target' or 'self'
                step.item_action_range=step.item_action_range or Policy.arrival('objective',nil,'item')
            end
            if learned.id>0 and (not step.npc_id or step.npc_id==learned.id) then
                step.npc_id=learned.id;step.manual_contact_learned=true
                local obj=named_target(step,true)
                if obj then local p=obj:get_position();return {x=p.x,y=p.y,z=p.z} end
                return {x=learned.x,y=learned.y,z=learned.z}
            elseif learned.id==0 and step.action=='objective' then
                -- Learned position supplements discovery; it never invents a click/item action.
                return {x=learned.x,y=learned.y,z=learned.z}
            end
        end
        return original_resolve(step)
    end
    local original_objective=a.handlers.guide_objective
    a.handlers.guide_objective=function(step)
        if step.vehicle_self_action then
            if not a.objective_done(step.quest_id,1) then return end
            if core.time()>=next_input then
                next_input=core.time()+3
                require("quest_actions").vehicle(step,player(),log,bridge.vehicle_actions.slots)
            end
            return
        end
        local learned=Learner:lookup(step)
        if learned and learned.spell_id and learned.spell_id>0 and core.spell_book.is_spell_known(learned.spell_id)
            and core.spell_book.is_usable_spell(learned.spell_id) and not a.objective_done(step.quest_id,step.objective_index,step.objective_indices)
            and not player():is_in_combat() and (step.manual_spell_attempts or 0)<3 then
            local obj=learned.id>0 and named_target(step,true) or player()
            if obj and distance(player():get_position(),obj:get_position())<=3 then
                if core.time()>=(step.manual_spell_next or 0) and not player():is_casting_spell() then
                    step.manual_spell_next=core.time()+3
                    step.manual_spell_attempts=(step.manual_spell_attempts or 0)+1
                    local ok,result=pcall(core.input.cast_target_spell,learned.spell_id,obj)
                    emit('learned_quest_spell_requested',{quest_id=step.quest_id,spell_id=learned.spell_id,accepted=ok and result~=false})
                end
                return
            end
        end
        if (step.manual_spell_attempts or 0)>=3 and not step.manual_spell_deferred then
            step.manual_spell_deferred=true
            emit("learned_quest_spell_deferred",{quest_id=step.quest_id,reason="no_quest_credit_after_three_attempts"})
        end
        return original_objective(step)
    end
    return a
end
return M

