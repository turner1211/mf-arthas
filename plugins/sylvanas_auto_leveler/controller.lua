-- Engine contract: adapters observe authoritative game state; dispatch is never completion.
-- Profile steps must contain authored world positions and explicit quest/target identities.
local M = {}
function M.new(adapter, profile)
    assert(type(profile) == "table" and type(profile.steps) == "table", "profile.steps required")
    local self = { adapter = adapter, profile = profile, index = 1, state = "disabled",
                   enabled = false, generation = 0, move = nil, deadline = nil, retries = 0 }
    function self:stop(reason)
        if self.adapter.log then self.adapter.log("stopped",{reason=reason or "disabled",step=self.index}) end
        self.enabled = false
        self.generation = self.generation + 1
        self.move = nil
        self.step_recovery_at=nil
        self.adapter.stop()
        if self.adapter.cancel_maintenance then self.adapter.cancel_maintenance() end
        self.state = reason or "disabled"
    end
    function self:recover_transient(reason)
        if not self.profile.persistent_navigation then return false end
        local prefixes={"taxi_","flight_master_","portal_","navigation_","nav_server_","map_conversion_","terrain_height_","mesh_height_"}
        local recoverable=false
        for _,prefix in ipairs(prefixes) do if tostring(reason):sub(1,#prefix)==prefix then recoverable=true;break end end
        if not recoverable then return false end
        self.transient_recoveries=(self.transient_recoveries or 0)+1
        local delay=math.min(60,3*2^math.min(4,self.transient_recoveries-1))
        self.adapter.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil
        self.objective_arrived=nil;self.travel_arrived=nil;self.step_recovery_at=self.adapter.time()+delay
        local step=self.profile.steps[self.index]
        if step then
            step.position=nil;step.height_query=nil;step.destination_pending=nil
            if self.adapter.recover_step then self.adapter.recover_step(step,self.transient_recoveries) end
        end
        self.state="recovering_transient:"..tostring(reason)
        if self.adapter.log then self.adapter.log("transient_failure_recovery",{step=self.index,reason=reason,
            attempt=self.transient_recoveries,delay=delay}) end
        return true
    end
    function self:start()
        if self.enabled then
            if self.adapter.log then self.adapter.log("start_ignored_already_running",{step=self.index}) end
            return false
        end
        if self.adapter.reset_movement_fault then self.adapter.reset_movement_fault() end
        local resumed=self.profile.steps[self.index]
        if resumed and self.adapter.resolve_position then
            resumed.position=nil;resumed.height_query=nil;resumed.destination_pending=nil
            resumed.coordinate_position=nil;resumed.coordinate_query=nil
        end
        self.loop_restart_at=nil;self.loop_restarts=0
        if self.adapter.log then self.adapter.log("started",{profile=self.profile.id or "unknown",step=self.index}) end
        self.enabled = true
        self.state = "running"
        self.deadline = nil
        self.step_recovery_at=nil
        self.retries = 0
        self.watch_index=self.index;self.watch_state=self.state;self.watch_at=self.adapter.time();self.watch_progress=nil;self.watch_progress_value=nil;self.self_repairs=0
    end
    function self:advance()
        local completed=self.profile.steps[self.index] or {}
        if self.adapter.note_step_progress then self.adapter.note_step_progress(completed) end
        if self.adapter.log then self.adapter.log("step_completed",{step=self.index,quest_id=completed.quest_id}) end
        self.adapter.stop()
        self.generation = self.generation + 1
        self.move = nil
        self.index = self.index + 1
        self.objective_arrived=nil
        self.travel_arrived=nil
        self.deadline = nil
        self.step_recovery_at=nil
        self.retries = 0
        self.recovery_attempts=0
        if self.death_counts then self.death_counts[self.index-1]=nil end
        self.watch_index=self.index;self.watch_state="running";self.watch_at=self.adapter.time();self.watch_progress=nil;self.watch_progress_value=nil;self.self_repairs=0
        if self.adapter.save then self.adapter.save(self.profile.id, self.index) end
    end
    function self:select_step(delta)
        local total=#self.profile.steps
        if total==0 then return false end
        local index=math.max(1,math.min(total,self.index+delta))
        local previous=self.index
        self.adapter.stop()
        if self.adapter.cancel_maintenance then self.adapter.cancel_maintenance() end
        self.generation=self.generation+1;self.index=index;self.move=nil;self.deadline=nil
        self.step_recovery_at=nil
        self.objective_arrived=nil;self.travel_arrived=nil;self.retry_at=nil;self.repair_retry_at=nil;self.retries=0
        self.recovery_attempts=0;self.catchup_attempts=0
        self.watch_index=index;self.watch_state=self.state;self.watch_at=self.adapter.time();self.watch_progress=nil;self.watch_progress_value=nil;self.self_repairs=0
        local step=self.profile.steps[index]
        step.position=nil;step.height_query=nil;step.coordinate_position=nil;step.coordinate_query=nil
        step.coordinate_index=1;step.coordinate_itinerary_complete=nil
        self.state=self.enabled and "running" or "step_selected"
        if self.adapter.save then self.adapter.save(self.profile.id,index) end
        if self.adapter.log then self.adapter.log("manual_step_selected",{previous=previous,step=index}) end
        return true
    end
    function self:navigate(position)
        if self.move == "pending" then self.state="navigating";return false end
        if self.move == "arrived" then return true end
        if self.adapter.time()<(self.repair_retry_at or 0) then return false end
        if self.move == "failed" then
            if self.adapter.time()<(self.retry_at or 0) then return false end
            self.retries = self.retries + 1
            local recoverable=self.last_navigation_cause=='terrain' or self.last_navigation_cause=='elevation' or self.last_navigation_cause=='service' or self.last_navigation_cause=='approach'
            if not recoverable and not self.profile.persistent_navigation and self.retries > (self.profile.max_retries or 3) then self:stop("navigation_failed"); return false end
            if self.adapter.log then self.adapter.log("navigation_retry",{step=self.index,attempt=self.retries,persistent=self.profile.persistent_navigation==true}) end
        end
        self.generation = self.generation + 1
        local generation = self.generation
        self.move = "pending"
        self.state = "navigating"
        if self.adapter.movement_owner then self.adapter.movement_owner('quest') end
        if self.adapter.log then self.adapter.log("navigation_requested",{step=self.index,x=position.x,y=position.y,z=position.z}) end
        self.adapter.move(position, function(ok, reason)
            if not self.enabled or generation ~= self.generation then return end
            if not ok and reason=="navigation_repair_replan" then
                self.repair_cycles=(self.repair_cycles or 0)+1
                -- Fresh planning requests are separate from terminal failures.
                self.move="failed";self.retry_at=self.adapter.time()+math.min(30,3*2^math.min(3,self.repair_cycles-1));self.repair_retry_at=self.retry_at;self.deadline=nil
                self.state="repairing_navigation"
                if self.adapter.log then self.adapter.log("navigation_repair_cycle",{step=self.index,reason=reason}) end
                return
            end
            self.move = ok and "arrived" or "failed"
            if self.adapter.destination_result then self.adapter.destination_result(position,ok,reason) end
            local cause=require('travel_decisions').failure(reason)
            if ok then self.last_navigation_cause=nil else self.last_navigation_cause=cause end
            if not ok and self.adapter.log then self.adapter.log("navigation_recovery_classified",{cause=cause,reason=reason,step=self.index}) end
            local current_step=self.profile.steps[self.index]
            if not ok and current_step and (cause=="terrain" or cause=="elevation") and self.retries%3==2 and self.adapter.recover_step then
                self.adapter.recover_step(current_step,self.retries+1)
            end
            local delay=self.profile.persistent_navigation and math.min(30,1.5*2^math.min(5,self.retries)) or math.min(5,1.5*(self.retries+1))
            if cause=="service" then delay=5 elseif cause=="interrupted" then delay=1 end
            if cause=='terrain' or cause=='elevation' or cause=='approach' then delay=0 end
            if ok then self.retry_at=nil else self.retry_at=self.adapter.time()+delay end
            if not ok and self.profile.persistent_navigation then
                local step=self.profile.steps[self.index]
                self.deadline=nil
                if step and step.destination_pending then
                    step.approach_attempt=(step.approach_attempt or 0)+1
                    step.position=nil;step.destination_pending=nil
                end
                if step and self.adapter.resolve_position and (reason=="area_changed" or reason=="navlib_arrival_out_of_range" or self.retries%3==2) then step.position=nil;step.height_query=nil end
            end
            if self.adapter.log then self.adapter.log("navigation_result",{step=self.index,success=ok,reason=reason}) end
            self.state = ok and "acting" or tostring(reason or "navigation_failed")
        end)
        return false
    end
    function self:tick()
        if not self.enabled then return end
        local a = self.adapter
        local now = a.time()
        -- Authoritative completed quests and guide completion must not be held
        -- behind repeated equipment/merchant maintenance or travel preparation.
        local current=self.profile.steps[self.index]
        if not current then self:stop("profile_finished");return end
        if current.quest_ids and a.bind_quest and not a.dead() then
            local id,reason=a.bind_quest(current)

        end
        if not a.dead() and current.completion_parent_quest_id and a.turned_in(current.completion_parent_quest_id) then
            if a.log then a.log("auxiliary_quest_section_completed",{step=self.index,quest_id=current.completion_parent_quest_id}) end
            self:advance();return
        end
        if not a.dead() and current.quest_id and a.turned_in(current.quest_id) then self:advance();return end
        if not a.dead() and current.action=='accept' and current.quest_id
            and a.on_quest(current.quest_id)==true and not current.gossip_option_ids and not current.gossip_option_indices then
            if a.log then a.log('quest_accept_already_satisfied',{step=self.index,quest_id=current.quest_id}) end
            self:advance();return
        end
        if not a.dead() and current.completion_quest_id
            and a.turned_in(current.completion_quest_id) then
            if a.log then a.log("spell_signal_quest_already_turned_in",{step=self.index,quest_id=current.completion_quest_id}) end
            self:advance();return
        end
        -- Authored RestedXP graveyard shortcuts deliberately die and resurrect
        -- at a Spirit Healer. They own death handling and must bypass ordinary
        -- combat rotations and corpse-return recovery for this step.
        if current.action=="deathskip" and (a.dead() or current.deathskip_started) then
            if not a.deathskip then self:stop("deathskip_handler_required");return end
            local state=a.deathskip(current)
            if state=="complete" then self:advance() else self.state=state or "deathskip" end
            return
        end
        if a.dead() then
            if a.movement_owner then a.movement_owner('death') end
            self.unready_since=nil
            if not self.death_episode then
                self.death_episode=true;self.death_counts=self.death_counts or {}
                self.death_counts[self.index]=(self.death_counts[self.index] or 0)+1
            end
            if a.recover_death then
                self.deadline=nil;self.move=nil;self.generation=self.generation+1
                local state=a.recover_death()
                if state and state:sub(1,8)=="blocked:" then self:stop(state:sub(9)) else self.state=state or "recovering_death" end
            else self:stop("death_handler_required") end
            return
        end
        if self.death_episode then
            self.death_episode=nil
            local count=self.death_counts and self.death_counts[self.index] or 1
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
            self.objective_arrived=nil;self.travel_arrived=nil
            if a.after_death then a.after_death(current,count) end
            self.state="post_death_recovery";self.watch_state=self.state;self.watch_at=now
            return
        end
        -- Taxi transport owns movement until arrival; never restart the departure walk
        -- because a ground watchdog, readiness check or quest recovery fires in flight.
        local transport_step=self.profile.steps[self.index]
        if a.transport_pending and a.transport_pending(transport_step) then
            local state=a.travel_action(transport_step)
            if state=="complete" then self:advance()
            elseif state and state:sub(1,8)=="blocked:" then
                local reason=state:sub(9);if not self:recover_transient(reason) then self:stop(reason) end
            else self.state=state or "taxi_travel_wait" end
            return
        end
        if not a.ready() then
            if not self.unready_since then
                self.unready_since=now;a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
                if a.cancel_maintenance then a.cancel_maintenance() end
            end
            local equipment=a.equipment_tick and not a.in_combat() and a.equipment_tick()
            if equipment then self.state=equipment;return end
            if now-self.unready_since>30 and not self.profile.persistent_navigation then self:stop("client_not_ready")
            else self.state="waiting_for_client" end
            return
        end
        if self.unready_since then
            -- A reconnect or phase change invalidates previously resolved
            -- destinations and arrival flags even when the quest step survives.
            if current.map_position or current.checkpoints then current.position=nil end
            current.height_query=nil;current.destination_pending=nil
            current.coordinate_position=nil;current.coordinate_query=nil
            self.objective_arrived=nil;self.travel_arrived=nil;self.retry_at=nil
            if a.log then a.log("client_ready_reconciled",{step=self.index,quest_id=current.quest_id}) end
        end
        self.unready_since=nil
        if a.level() >= (self.profile.target_level or 90) then self:stop("target_level_reached"); return end
        -- Whole-leveler watchdog. Navigation, combat, taxis, loading, death and
        -- maintenance have their own progress authorities. When an ordinary
        -- quest action sits in the same state with no pending route, rebuild
        -- that exact step instead of stopping or skipping it.
        if self.watch_index~=self.index or self.watch_state~=self.state then
            self.watch_index=self.index;self.watch_state=self.state;self.watch_at=now
        end
        -- Objective counters can advance while the controller remains in the
        -- same "acting" state. Treat that authoritative quest progress as
        -- activity so a long multi-kill or collection step is not needlessly
        -- reset by the whole-leveler watchdog.
        local progress,progress_value
        if a.progress_token then progress,progress_value=a.progress_token(current) end
        if progress~=nil then
            if self.watch_progress==nil then self.watch_progress=progress;self.watch_progress_value=progress_value
            elseif progress~=self.watch_progress then
                local previous_value=self.watch_progress_value
                local advanced=progress_value==nil or previous_value==nil or progress_value>previous_value
                self.watch_progress=progress;self.watch_progress_value=progress_value
                if advanced then
                    self.watch_at=now;self.self_repairs=0
                    local lease=current.timeout or 120
                    self.deadline=now+lease;self.recovery_attempts=0
                    if a.note_step_progress then a.note_step_progress(current) end
                    if a.log then a.log("quest_progress_observed",{step=self.index,quest_id=current.quest_id,value=progress_value}) end
                    if a.log then a.log("progress_lease_renewed",{step=self.index,quest_id=current.quest_id,seconds=lease,deadline=self.deadline}) end
                elseif a.log then
                    a.log("quest_progress_regressed",{step=self.index,quest_id=current.quest_id,previous=previous_value,current=progress_value})
                end
            end
        end
        local protected=(self.move=="pending" or self.move=="failed") or a.in_combat()
            or self.state=="waiting_for_client" or self.state=="taxi_travel_wait"
            or self.state=="releasing_spirit" or self.state=="walking_to_corpse"
            or self.state=="resurrecting_at_corpse" or self.state=="waiting_for_mount"
            or self.state=="mounting" or self.state=="stopping_before_mount"
            or self.state=="skyriding_takeoff" or self.state=="skyriding"
        -- A bounded floor scan is active work, not a stalled quest action.
        local height=current and current.height_query
        if self.state=="resolving_destination" and height and height.ground_probes
            and height.ground_probes<512 and now-height.started<180 then protected=true end
        local coordinated_due=a.quest_recovery_due and a.quest_recovery_due(current,progress,progress_value,protected)
        if not protected and (coordinated_due or coordinated_due==nil and now-(self.watch_at or now)>=75) then
            local step=self.profile.steps[self.index]
            self.self_repairs=(self.self_repairs or 0)+1
            a.stop();if a.cancel_maintenance then a.cancel_maintenance() end
            self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil;self.repair_retry_at=nil;self.retries=0
            self.objective_arrived=nil;self.travel_arrived=nil
            if step then
                step.position=nil;step.height_query=nil;step.search_state=nil;step.search_query=nil
                step.coordinate_position=nil;step.coordinate_query=nil
                step.dynamic_action_ready=nil
            end
            -- Rotate through every authored recovery point.  The old two-point
            -- alternation could retry forever without ever visiting checkpoint
            -- three or later on multi-area collection and interaction quests.
            local recovery_points=step and step.checkpoints and #step.checkpoints or 2
            local recovery_attempt=(self.self_repairs-1)%math.max(1,recovery_points)+1
            if a.recover_step and step then a.recover_step(step,recovery_attempt) end
            self.state="self_repairing_step";self.watch_state=self.state;self.watch_at=now
            if a.log then a.log("leveler_self_repair",{step=self.index,attempt=self.self_repairs,reason="state_stalled_75s"}) end
            return
        end
        if a.movement_tick then a.movement_tick() end
        local fault=a.movement_fault and a.movement_fault()
        if fault=="movement_loop_detected" or fault=="stuck_recovery_exhausted" then
            a.stop()
            if a.cancel_maintenance then a.cancel_maintenance() end
            if a.reset_movement_fault then a.reset_movement_fault() end
            self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil
            self.objective_arrived=nil;self.travel_arrived=nil
            self.loop_restarts=(self.loop_restarts or 0)+1
            local delay=math.min(15,2*self.loop_restarts)
            self.loop_restart_at=now+delay
            local step=self.profile.steps[self.index]
            if step then
                if a.resolve_position then step.position=nil;step.height_query=nil end
                step.search_state=nil;step.search_query=nil
            end
            self.state="restarting_after_movement_loop"
            if a.log then a.log("leveler_loop_restart",{step=self.index,attempt=self.loop_restarts,delay=delay}) end
            return
        elseif fault then self:stop(fault);return end
        if a.in_combat() and current.action~="deathskip" then
            if a.movement_owner then a.movement_owner('combat') end
            if not self.combat_interrupted then
                self.combat_interrupted=true
                if a.log then a.log("travel_interrupted_by_combat",{step=self.index}) end
            end
            if a.cancel_maintenance then a.cancel_maintenance() end
            if self.move then a.stop(); self.generation = self.generation + 1; self.move = nil end
            self.deadline = nil
            self.state = "combat_rotation"
            if a.combat_tick then a.combat_tick() end
            return
        end
        if not current.suppress_combat_preparation and a.combat_prepare and a.combat_prepare() then
            a.stop();self.move=nil;self.deadline=nil;self.generation=self.generation+1
            self.state="combat_preparation";return
        end
        if not current.defer_maintenance and a.maintenance then
            local service=a.maintenance()
            if service then
                self.generation=self.generation+1;self.move=nil;self.deadline=nil
                if service:sub(1,8)=="blocked:" then self:stop(service:sub(9))
                else self.state=service end
                return
            end
        end
        if self.state=="looting_open_window" then self.state="acting" end
        if self.combat_interrupted then
            self.combat_interrupted=nil
            if a.log then a.log("travel_resumed_after_combat_and_loot",{step=self.index}) end
        end
        if self.loop_restart_at then
            if now<self.loop_restart_at then self.state="restarting_after_movement_loop";return end
            self.loop_restart_at=nil;self.state="running"
        end
        if self.step_recovery_at and now<self.step_recovery_at then
            self.state="recovering_quest_step";return
        end
        self.step_recovery_at=nil
        local step = self.profile.steps[self.index]
        if not step then self:stop("profile_finished"); return end
        if step.action=='turnin' and step.quest_id and a.on_quest(step.quest_id)==true and a.objective_done then
            for candidate,objective in ipairs(self.profile.steps) do
                if objective.action=='objective' and objective.quest_id==step.quest_id
                    and a.objective_done(step.quest_id,objective.objective_index,objective.objective_indices)==false then
                    a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil
                    self.index=candidate;self.state='returning_to_unfinished_objective'
                    if a.save then a.save(self.profile.id,candidate) end
                    if a.log then a.log('premature_turnin_objective_selected',{quest_id=step.quest_id,step=candidate}) end
                    return
                end
            end
        end
        if step.toy_travel_id then
            if not a.toy_travel then self.state="toy_travel_adapter_required";return end
            local status=a.toy_travel(step)
            if status=="complete" then self:advance() else self.state=status or "toy_travel_wait" end
            return
        end
        if a.recall_eye then
            for _,op in ipairs(step.macro_operations or {}) do
                if op.kind=="recall_eye" and not a.recall_eye(step) then a.stop();self.state="recalling_eye_of_acherus";return end
            end
        end
        if step.custom_gates then
            local applicable,reason,skip_index=require("custom_route_compiler").gate(step,a)
            if applicable==nil then
                -- Unknown quest state must also cancel any previous movement.
                if self.move then a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil end
                self.state=reason or "waiting_for_custom_gate";return
            end
            if not applicable then
                if skip_index then
                    self.index=skip_index;self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.state="custom_gate_jump"
                else self:advance() end
                return
            end
        end
        if step.action=="route_transition" then
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
            if step.transition_index then
                self.index=step.transition_index;self.state="route_step_transition"
                if a.save then a.save(self.profile.id,self.index) end
                if a.log then a.log("route_step_transition",{step=self.index,label=step.transition_label}) end
            elseif step.transition_link then
                self.profile.next_links={step.transition_link}
                if a.log then a.log("speed_route_transition",{from=self.profile.id,to=step.transition_link}) end
                self:stop("profile_finished")
            else self:stop("route_transition_invalid") end
            return
        end
        if step.travel_item_id and a.travel_support then a.travel_support(step) end
        if a.step_skip and a.step_skip(step) then self:advance();return end
        if step and step.quest_ids and not step.quest_id and step.action~="accept" then
            self.state="waiting_for_quest_variant";return
        end
        if step.world_map_id and a.world_map_id and step.world_map_id~=a.world_map_id() then
            self:stop("map_transition_handler_required");return
        end
        if step.instance_id and a.instance_id and step.instance_id~=a.instance_id() then
            self:stop("instance_transition_handler_required");return
        end
        if not self.deadline then self.deadline = now + (step.timeout or 120) end
        if self.profile.persistent_navigation and (self.move=="failed" or self.move=="pending") then
            self.deadline=now+(step.timeout or 120)
        end
        if now > self.deadline then
            self.recovery_attempts=(self.recovery_attempts or 0)+1
            local persistent=self.profile.persistent_navigation==true
            if a.recover_step and (self.recovery_attempts<=2 or persistent) and a.recover_step(step,self.recovery_attempts) then
                local delay=persistent and math.min(60,5*math.ceil(self.recovery_attempts/2)) or 0
                self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.step_recovery_at=now+delay;self.state="recovering_quest_step"
                if a.log then a.log("quest_step_recovery_scheduled",{step=self.index,quest_id=step.quest_id,attempt=self.recovery_attempts,delay=delay,persistent=persistent}) end
                return
            end
            self:stop("step_timeout"); return
        end
        if step.quest_id and a.turned_in(step.quest_id) then self:advance(); return end
        if step.conditional_turnin and step.quest_id and not a.on_quest(step.quest_id) then
            if a.log then a.log("conditional_turnin_not_applicable",{step=self.index,quest_id=step.quest_id}) end
            self:advance();return
        end
        if step.item_goal and a.item_goal_done and a.item_goal_done(step.item_goal) then self:advance();return end
        if step.completion_spell_ids and a.cast_observed and a.cast_observed(step) then self:advance();return end
        if step.action == "accept" and step.quest_id and a.on_quest(step.quest_id)
            and not (step.gossip_option_ids and not step.gossip_sequence_complete) then self:advance(); return end
        if step.action == "objective" and a.objective_done(step.quest_id, step.objective_index, step.objective_indices) then self:advance(); return end
        if step.action=="spell_signal" and step.completion_quest_id and step.completion_objective_index and a.objective_done(
            step.completion_quest_id,step.completion_objective_index) then
            if a.log then a.log("spell_signal_already_complete",{step=self.index,quest_id=step.completion_quest_id,
                objective=step.completion_objective_index}) end
            self:advance();return
        end
        if step.action=="scenario_entry" then
            if not a.scenario_id then self:stop("scenario_reader_required");return end
            if a.scenario_id()==step.scenario_entry_id then self:advance()
            else self.state="waiting_for_scenario_entry:"..tostring(step.scenario_entry_id) end
            return
        end
        if step.action == "scenario" and a.scenario_done and a.scenario_done(step) then self:advance(); return end
        if step.action=="zone_wait" and a.ui_map_id and a.ui_map_id()==step.target_map_id then self:advance();return end
        if step.action=="unsupported" then self:stop(step.unsupported_reason or "unsupported_guide_step");return end
        if self.failed_quest_restart then
            local restart=self.failed_quest_restart
            if a.on_quest(restart.quest_id) then
                if a.time()>restart.deadline then self.failed_quest_restart=nil;self:stop("failed_quest_abandon_unconfirmed:"..restart.quest_id)
                else self.state="waiting_failed_quest_abandon" end
                return
            end
            local accept
            for i=restart.from,1,-1 do
                local candidate=self.profile.steps[i]
                local match=candidate.quest_id==restart.quest_id
                if not match then for _,qid in ipairs(candidate.quest_ids or {}) do if qid==restart.quest_id then match=true;break end end end
                if match and candidate.action=="accept" then accept=i;break end
            end
            self.failed_quest_restart=nil
            if not accept then self:stop("failed_quest_accept_step_missing:"..restart.quest_id);return end
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil
            self.objective_arrived=nil;self.travel_arrived=nil;self.index=accept;self.state="restarting_failed_quest"
            if a.log then a.log("failed_quest_rewind",{quest_id=restart.quest_id,to=accept,from=restart.from}) end
            return
        end
        if step.quest_id and (step.action=="objective" or step.action=="turnin") and a.quest_failed and a.quest_failed(step.quest_id) then
            if not a.restart_failed_quest or not a.restart_failed_quest(step.quest_id) then
                self:stop("failed_quest_restart_unavailable:"..step.quest_id);return
            end
            self.failed_quest_restart={quest_id=step.quest_id,from=self.index,deadline=a.time()+10}
            self.state="waiting_failed_quest_abandon";return
        end
        if step.action=="maintenance" then
            if not a.maintenance then self:stop("maintenance_handler_required");return end
            -- The maintenance adapter above has already satisfied its configured needs.
            if a.log then a.log("maintenance_checkpoint_completed",{step=self.index,restocking_supported=false}) end
            self:advance();return
        end
        -- An accepted quest proves its acceptance prerequisites were met.
        -- Stale authored prerequisite flags must not rewind its objectives.
        if a.step_gate and not (step.quest_id and a.on_quest(step.quest_id)) then
            local reason,missing=a.step_gate(step)
            if reason then
                local catchup
                for _,qid in ipairs(missing or {}) do
                    -- An already accepted prerequisite needs its unfinished objective
                    -- or turn-in, not another acceptance and another taxi journey.
                    if a.on_quest(qid) then
                        for i=1,#self.profile.steps do
                            local candidate=self.profile.steps[i]
                            if candidate.quest_id==qid and candidate.action=="objective"
                                and not a.objective_done(qid,candidate.objective_index,candidate.objective_indices) then catchup=i;break end
                            if candidate.quest_id==qid and candidate.action=="turnin" then catchup=i;break end
                        end
                    end
                    if catchup then break end
                    for i=1,#self.profile.steps do
                        local candidate=self.profile.steps[i]
                        if candidate.action=="accept" and candidate.quest_id==qid and not a.turned_in(qid) then catchup=i;break end
                    end
                    if catchup then break end
                end
                self.catchup_attempts=(self.catchup_attempts or 0)+1
                if catchup and self.catchup_attempts<=5 then
                    a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
                    if a.log then a.log("prerequisite_catchup",{from=self.index,to=catchup,reason=reason}) end
                    self.index=catchup;self.state="prerequisite_catchup";return
                end
                self:stop(reason);return
            end
        end
        -- Self-cast travel must never follow an inherited quest-area itinerary.
        if step.action=="hearth" then
            if a.cast_observed and a.cast_observed(step) then self:advance();return end
            if not a.use_hearth then self:stop("hearth_handler_required");return end
            a.use_hearth(step);self.state="using_hearthstone";return
        end
        local interaction_ready=a.interaction_local_ready and a.interaction_local_ready(step)
        if interaction_ready and self.move then
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
            if a.log then a.log("quest_interaction_route_handoff",{quest_id=step.quest_id,step=self.index}) end
        end
        if step.resolve_at_player and step.quest_action_mode=="self" and step.tags and tonumber(step.tags.U) and a.item_goal_count then
            local item=tonumber(step.tags.U);local count=a.item_goal_count({item_id=item})
            if count==0 then
                for i=1,self.index-1 do
                    local purchase=self.profile.steps[i]
                    if purchase.handler=="vendor_purchase" and purchase.item_goal and purchase.item_goal.item_id==item then
                        a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.index=i
                        self.state="recovering_missing_quest_item"
                        if a.log then a.log("quest_item_purchase_repaired",{quest_id=step.quest_id,item_id=item,step=i}) end
                        return
                    end
                end
                self.state="missing_quest_item";return
            end
        end
        if step.resolve_at_player and (step.quest_action_mode=="self" or step.vehicle_self_action) and step.action=="objective" then
            if self.objective_arrived~=self.index then a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil end
            self.objective_arrived=self.index
        end
        -- Some area/item objectives can already be performed at the current
        -- position. A live, verified target is stronger evidence than the
        -- guide's broad checkpoint and avoids routing away from a valid mob.
        if step.action=="objective" and self.objective_arrived~=self.index
            and a.objective_local_ready and a.objective_local_ready(step) then
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
            self.objective_arrived=self.index;self.state="objective_local_target_ready"
            if a.note_checkpoint_arrival then a.note_checkpoint_arrival(step) end
            if a.log then a.log("objective_checkpoint_bypassed",{step=self.index,quest_id=step.quest_id,reason="verified_nearby_target"}) end
        end
        if step.action=="spell_signal" and a.spell_signal_position then
            local live=a.spell_signal_position(step)
            if live then
                if not step.coordinate_itinerary_complete and a.log then a.log("spell_signal_live_target",{step=self.index,target=step.target_name}) end
                step.coordinate_itinerary_complete=true;step.position=live;step.destination_pending=nil
            end
        end
        -- RestedXP may provide several authored waypoints for one guide step.
        -- Treat them as an ordered coordinate route instead of sending the
        -- final quest anchor directly to the pathfinder.
        if step.coordinate_route and not step.coordinate_itinerary_complete
            and not interaction_ready and not (step.action=="objective" and self.objective_arrived==self.index) then
            step.coordinate_index=math.max(1,tonumber(step.coordinate_index) or 1)
            local route_point=step.coordinate_route[step.coordinate_index]
            if route_point then
                -- Keep the resolver state for this itinerary leg. Recreating
                -- this table every tick discards an asynchronous Sentinel
                -- height request and floods the server with the same query.
                local query=step.coordinate_query
                if not query or query.coordinate_index~=step.coordinate_index then
                    query={ui_map_id=route_point.ui_map_id,map_position={x=route_point.x,y=route_point.y},
                        source_index=step.source_index,coordinate_source=step.coordinate_source,
                        coordinate_index=step.coordinate_index}
                    step.coordinate_query=query
                end
                if not step.coordinate_position and a.resolve_position then
                    local position,reason=a.resolve_position(query)
                    if position then step.coordinate_position=position
                    elseif reason=="resolving_destination" then self.state=reason;return
                    else self:stop(reason or "coordinate_route_unresolved");return end
                end
                if not step.coordinate_position then self:stop("coordinate_world_position_required");return end
                if a.prepare_travel then
                    query.position=step.coordinate_position
                    local state=a.prepare_travel(query)
                    if state then self.generation=self.generation+1;self.move=nil;self.state=state;return end
                end
                if not self:navigate(step.coordinate_position) then return end
                if a.log then a.log("coordinate_route_point_reached",{step=self.index,quest_id=step.quest_id,
                    index=step.coordinate_index,count=#step.coordinate_route,map=route_point.ui_map_id,x=route_point.x,y=route_point.y}) end
                step.coordinate_index=step.coordinate_index+1;step.coordinate_position=nil;step.coordinate_query=nil
                self.generation=self.generation+1;self.move=nil;self.deadline=nil;self.retry_at=nil;self.repair_retry_at=nil;self.retries=0
                if step.coordinate_index>#step.coordinate_route then step.coordinate_itinerary_complete=true
                else self.state="advancing_coordinate_route";return end
            else step.coordinate_itinerary_complete=true end
        end
        if not step.position and a.resolve_position then
            local position,reason=a.resolve_position(step)
            if position then step.position=position;step.destination_pending=reason=="intermediate_destination"
            elseif reason=="resolving_destination" then self.state=reason;return
            else self:stop(reason or "destination_unresolved");return end
        end
        if not step.position then self:stop("world_position_required"); return end
        if (step.action=="accept" or step.action=="turnin") and a.quest_giver_position then
            local live,range=a.quest_giver_position(step)
            if live then
                local old=step.position
                local changed=(old.x-live.x)^2+(old.y-live.y)^2+(old.z-live.z)^2>4
                local close=range<=(step.interaction_range or 5)
                if changed or close and self.move=="pending" then
                    a.stop();self.generation=self.generation+1
                    step.position=live;step.destination_pending=nil
                    self.move=close and "arrived" or nil
                end
            end
        end
        if self.objective_arrived~=self.index and a.position
            and require('route_policy').objective_area_ready(step,a.position()) then
            a.stop();self.generation=self.generation+1;self.move=nil;self.deadline=nil
            self.objective_arrived=self.index;self.retry_at=nil;self.repair_retry_at=nil
            if a.log then a.log("objective_area_reached",{quest_id=step.quest_id,step=self.index,radius=8}) end
        end
        if self.travel_arrived==self.index and a.travel_action then
            local state=a.travel_action(step)
            if state=="complete" then self:advance()
            elseif state and state:sub(1,8)=="blocked:" then
                local reason=state:sub(9);if not self:recover_transient(reason) then self:stop(reason) end
            else self.state=state or "travel_action_wait" end
            return
        end
        if a.prepare_travel and not interaction_ready and not (step.action=="objective" and self.objective_arrived==self.index) then
            local state=a.prepare_travel(step)
            if state then
                self.generation=self.generation+1;self.move=nil;self.state=state
                if state=="landing_route_required" then self:stop(state) end
                return
            end
        end
        if not interaction_ready and not (step.action=="objective" and self.objective_arrived==self.index) then
            if not self:navigate(step.position) then return end
            if step.destination_pending then
                step.position=nil;step.height_query=nil;step.destination_pending=nil
                self.move=nil;self.deadline=nil;self.retries=0;self.retry_at=nil
                self.state="approaching_destination";return
            end
            if step.action=="objective" then self.objective_arrived=self.index end
            if (step.action=="objective" or step.action=="collect" or step.action=="scenario")
                and a.note_checkpoint_arrival then a.note_checkpoint_arrival(step) end
        end
        if step.macro_operations and not step.macro_operations_complete then
            if not a.macro_operation then self:stop("macro_operation_handler_required");return end
            if not a.macro_operation(step) then self.state="authored_macro_wait";return end
            step.macro_operations_complete=true
        end
        if step.action=="macro" then self:advance();return end
        if step.action=="countdown" then
            step.countdown_started_at=step.countdown_started_at or now
            if now-step.countdown_started_at>=step.countdown_seconds then self:advance()
            else self.state="countdown:"..tostring(math.ceil(step.countdown_seconds-(now-step.countdown_started_at))) end
            return
        end
        if step.action=="train" then
            if not a.train_spell then self:stop("trainer_handler_required");return end
            if a.train_spell(step) then self:advance() else self.state="training_spell:"..tostring(step.train_spell_id) end
            return
        end
        if step.action=="player_choice" then
            if not a.player_choice_complete then self:stop("player_choice_bridge_required");return end
            if a.player_choice_complete(step.player_choice_id) then self:advance()
            else self.state="waiting_for_player_choice:"..tostring(step.player_choice_id) end
            return
        end
        if step.action=="aura" then
            if not a.aura_matches then self:stop("aura_reader_required");return end
            local matches=a.aura_matches(step.aura_id,step.aura_min_remaining)
            if matches==step.aura_expected then self:advance() else self.state="waiting_for_aura:"..tostring(step.aura_id) end
            return
        end
        if step.action=="subzone_wait" then
            if not a.subzone_matches then self:stop("subzone_reader_required");return end
            local matches=a.subzone_matches(step.area_id)
            if matches==nil then self.state="waiting_for_subzone_data:"..tostring(step.area_id)
            elseif matches~=step.subzone_reverse then self:advance()
            else self.state="waiting_for_subzone:"..tostring(step.area_id) end
            return
        end
        if step.action=="emote" then
            if not a.perform_emote then self:stop("emote_handler_required");return end
            if a.perform_emote(step) then self:advance() else self.state="performing_emote:"..tostring(step.emote_token) end
            return
        end
        if step.action=="vehicle_state" then
            if not a.vehicle_state then self:stop("vehicle_state_handler_required");return end
            if a.vehicle_state(step) then self:advance() else self.state="entering_vehicle:"..tostring(step.vehicle_id) end
            return
        end
        if step.action=="vehicle_exit" then
            if not a.vehicle_exit then self:stop("vehicle_exit_handler_required");return end
            if a.vehicle_exit(step) then self:advance() else self.state="exiting_vehicle" end
            return
        end
        if step.action=="abandon_quest" then
            if not a.on_quest(step.quest_id) then self:advance();return end
            if not a.abandon_quest then self:stop("quest_abandon_handler_required");return end
            a.abandon_quest(step);self.state="waiting_for_quest_abandon:"..tostring(step.quest_id);return
        end
        if step.action=="reputation_wait" then
            if not a.reputation_condition then self:stop("reputation_reader_required");return end
            local reached=a.reputation_condition(step.faction_id,step.reputation_standing,step.reputation_value)
            if reached==step.reputation_expected then self:advance()
            elseif reached==nil then self.state="waiting_for_reputation_data:"..tostring(step.faction_id)
            else self.state="waiting_for_reputation:"..tostring(step.faction_id) end
            return
        end
        if step.action=="bind_home" then
            if not a.bind_home then self:stop("bind_home_handler_required");return end
            if a.bind_home(step) then self:advance() else self.state="binding_hearthstone" end
            return
        end
        if step.action=="collect_mount" then
            if not a.mount_collected or not a.collect_mount then self:stop("mount_collection_handler_required");return end
            if a.mount_collected(step.mount_id) then self:advance()
            else a.collect_mount(step);self.state="collecting_mount:"..tostring(step.mount_id) end
            return
        end
        if step.action=="deathskip" then
            if not a.deathskip then self:stop("deathskip_handler_required");return end
            step.deathskip_started=true
            local state=a.deathskip(step)
            if state=="complete" then self:advance() else self.state=state or "deathskip" end
            return
        end
        if step.action=="chromie_time" then
            if not a.chromie_time then self:stop("chromie_time_handler_required");return end
            if a.chromie_time(step) then self:advance() else self.state="selecting_chromie_time:"..tostring(step.chromie_time_option) end
            return
        end
        if step.action=="adventure_map_accept" then
            if a.on_quest(step.quest_id) or a.turned_in(step.quest_id) then self:advance();return end
            if not a.adventure_map_accept then self:stop("adventure_map_handler_required");return end
            a.adventure_map_accept(step);self.state="accepting_adventure_map_quest:"..tostring(step.quest_id);return
        end
        if step.action=="logout_roleplay_bypass" then
            if a.log then a.log("logout_roleplay_bypassed",{step=self.index,reason="preserve_unattended_session"}) end
            self:advance();return
        end
        if step.action=="achievement" then
            if not a.achievement_complete then self:stop("achievement_reader_required");return end
            local complete=a.achievement_complete(step.achievement_id,step.achievement_criterion)
            if complete then self:advance() else self.state="waiting_for_achievement:"..tostring(step.achievement_id) end
            return
        end
        if step.action == "travel" then
            if step.travel_mode=="taxi_discovery" or step.travel_mode=="taxi_flight"
                or step.travel_mode=="portal" or step.travel_mode=="scheduled_transport"
                or step.travel_mode=="use_item_after_arrival" or step.travel_mode=="use_item_until_buff" then
                self.travel_arrived=self.index;return
            end
            self:advance(); return
        end
        if step.action=="gossip" then
            if not a.gossip_sequence then self:stop("gossip_sequence_handler_required");return end
            if a.gossip_sequence(step) then self:advance() else self.state="authored_gossip_sequence" end
            return
        end
        if step.action=="spell" then
            if not a.authored_spell then self:stop("authored_spell_handler_required");return end
            if a.authored_spell(step) then self:advance() else self.state="authored_spell_wait" end
            return
        end
        if step.action=="spell_signal" then
            if not a.spell_signal then self:stop("spell_signal_handler_required");return end
            a.spell_signal(step);self.state="waiting_for_authored_cast";return
        end
        if step.action=="checkpoint" or step.action=="optional_interact" then
            if step.action=="optional_interact" and a.optional_interact then a.optional_interact(step) end
            self:advance();return
        end
        if step.action=="level_gate" then
            if not step.required_level or a.level()>=step.required_level then self:advance()
            else self.state="waiting_for_level:"..step.required_level end
            return
        end
        if step.action=="money_gate" then
            if not a.money then self:stop("money_reader_required");return end
            local amount=a.money();local reached=step.money_greater_than and amount>=step.money or amount<step.money
            if reached then self:advance() else self.state="waiting_for_money:"..tostring(step.money) end
            return
        end
        if step.action=="zone_wait" then
            if step.travel_mode=="portal" and a.travel_action then a.travel_action(step) end
            self.state="waiting_for_zone:"..tostring(step.target_map_id);return
        end
        if step.action == "accept" or step.action == "turnin" then
            if not (step.quest_id or step.quest_ids) or not (step.npc_id or step.target_name or step.auto_dialog or step.quest_giver_item or step.live_contact_observed) then self:stop("quest_identity_required"); return end
            if step.action=="accept" and step.quest_id and a.on_quest(step.quest_id) and step.gossip_option_ids then
                if not a.gossip_sequence then self:stop("gossip_sequence_handler_required");return end
                if a.gossip_sequence(step) then self:advance() else self.state="quest_gossip_sequence" end
                return
            end
            local result,position=a.quest_dialog(step)
            if result=="approach" and position then
                step.position=position;step.destination_pending=nil
                self.generation=self.generation+1;self.move=nil;self.state="approaching_quest_giver"
            end
        elseif step.action == "objective" or step.action=="collect" or step.action=="scenario" then
            if not step.handler or step.action=="objective" and not step.quest_id then self:stop("objective_handler_required"); return end
            local handler = a.handlers and a.handlers[step.handler]
            if not handler then self:stop("unsupported_handler:" .. step.handler); return end
            handler(step)
        else self:stop("unsupported_action:" .. tostring(step.action)) end
    end
    return self
end
return M

