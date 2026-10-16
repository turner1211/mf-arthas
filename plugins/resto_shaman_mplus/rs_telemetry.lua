local M={}
local LOG_PATH="resto_shaman_mplus/session.log"
local DATA_FOLDER="resto_shaman_mplus"
local DATA_FILES={"resto_shaman_mplus/session_a.log","resto_shaman_mplus/session_b.log"}
local ENTITY="resto_shaman_mplus"
local VERSION="5.8.0"
local lines={}
local current_run_start=1
local journal_sequence=0
local journal_slot=1
local last_snapshot=-math.huge
local recent_events={}
local requested_at={}
local last_event_prune=-math.huge
local last_journal_write=-math.huge
local journal_dirty=false
local requested_info={}
local pending_outcomes={}
local terminal_casts={}
local HEAL_OUTCOME_IDS={[61295]="single",[77472]="single",[73685]="single",[1064]="primary_target"}
local cancelled_requests={}
local debug_lines={}
local run={active=false,mode=nil,started=0,requests=0,success=0,failed=0,interrupted=0,cancelled=0,external=0,
    spells={},failed_spells={},interrupted_spells={},cancelled_spells={},mana_start=nil,mana_min=nil,mana_end=nil,
    lowest_hp=100,lowest_current=100,critical_mana_seconds=0,last_sample=nil,samples=0,
    emergency_samples=0,low_mana_samples=0,highest_fall_rate=0,highest_predicted_loss=0}
local function clean(value)
    value=tostring(value or "-")
    return value:gsub("[|\r\n]"," ")
end
local function debug_push(kind,message)
    debug_lines[#debug_lines+1]=string.format("[RSMDBG] t=%.2f | %s | %s",core.time(),clean(kind),clean(message))
    if #debug_lines>120 then table.remove(debug_lines,1) end
end
local function decode_journal(text)
    if type(text)~="string" or text=="" then return nil end
    local sequence,count,bytes,payload=text:match("^RSMCACHE|(%d+)|(%d+)|(%d+)\n(.*)$")
    sequence,count,bytes=tonumber(sequence),tonumber(count),tonumber(bytes)
    if not sequence or not count or not bytes or #payload~=bytes then return nil end
    local restored={}
    for line in payload:gmatch("[^\n]+") do restored[#restored+1]=line:gsub("\r$","") end
    if #restored~=count then return nil end
    return {sequence=sequence,lines=restored}
end
local function persist_journal()
    if type(core.write_data_file)~="function" then return false end
    journal_sequence=journal_sequence+1
    journal_slot=journal_slot==1 and 2 or 1
    local payload=table.concat(lines,"\n")
    if #payload>0 then payload=payload.."\n" end
    local snapshot=string.format("RSMCACHE|%d|%d|%d\n%s",journal_sequence,#lines,#payload,payload)
    local ok=pcall(core.write_data_file,DATA_FILES[journal_slot],snapshot)
    if ok then last_journal_write=core.time();journal_dirty=false end
    return ok
end
local function restore_journal()
    if type(core.read_data_file)~="function" then return end
    local best,best_slot
    for index,path in ipairs(DATA_FILES) do
        local ok,text=pcall(core.read_data_file,path)
        local decoded=ok and decode_journal(text) or nil
        if decoded and (not best or decoded.sequence>best.sequence) then best,best_slot=decoded,index end
    end
    if best then
        lines=best.lines;journal_sequence=best.sequence;journal_slot=best_slot
        current_run_start=1
        -- After a crash there is no RUN_END marker. Keep the whole recovered
        -- history copyable instead of pretending the interrupted run completed.
        for i=#lines,1,-1 do
            if lines[i]:find("| RUN_START |",1,true) then current_run_start=i;break end
            if lines[i]:find("| RUN_END |",1,true) then current_run_start=i+1;break end
        end
    end
end

local function enabled()
    local ok,C=pcall(require,"rs_settings")
    return ok and C.get("debug_log")==true
end
local function wall_time()
    if type(core.get_local_time)=="function" then
        local ok,t=pcall(core.get_local_time)
        if ok and type(t)=="table" then
            return string.format("%04d-%02d-%02d %02d:%02d:%02d",
                t.year or 0,t.month or 0,t.day or 0,t.hour or 0,t.minute or 0,t.second or 0)
        end
    end
    return "game-time-"..string.format("%.2f",core.time())
end
local function unit_name(unit)
    if not unit then return "-" end
    local ok,value=pcall(function()return unit:get_name()end)
    if ok and value then return clean(value) end
    local ok2,guid=pcall(function()return unit:get_guid()end)
    return ok2 and clean(guid) or "unknown"
end
local function unit_guid(unit)
    local ok,U=pcall(require,"rs_units")
    if ok and type(U.guid)=="function" then return U.guid(unit) end
    local success,value=pcall(function()return unit and unit:get_guid()end)
    return success and value or nil
end
local function append_raw(line,console,durable)
    lines[#lines+1]=line
    if #lines>5000 then
        table.remove(lines,1)
        current_run_start=math.max(1,current_run_start-1)
    end
    journal_dirty=true
    -- Rewriting a multi-thousand-line crash journal on every one-second STATE
    -- sample creates avoidable disk and frame pressure. Checkpoint at most every
    -- two seconds, while run boundaries and errors remain immediately durable.
    if durable or core.time()-last_journal_write>=2 then persist_journal() end
    if console~=false then pcall(core.log,line) end
    local ok,err=pcall(function()
        assert(type(core.write_log_file)=="function","core.write_log_file unavailable")
        core.write_log_file(LOG_PATH,line.."\n")
    end)
    local C=require("rs_settings")
    C.log_status=ok and ("Recording • "..#lines.." lines") or ("Write failed: "..clean(err))
    return ok
end
local function emit(kind,fields,force)
    if not force and not enabled() then return false end
    local out={"[RSMLOG]",kind,"clock="..wall_time(),"t="..string.format("%.2f",core.time())}
    for _,v in ipairs(fields or {}) do out[#out+1]=clean(v) end
    local durable=kind=="RUN_START" or kind=="RUN_END" or kind=="REPLAY_GRADE"
        or kind=="ERROR" or kind=="LOG_CLEARED"
    return append_raw(table.concat(out," | "),nil,durable)
end
local function reset_run(mode)
    run={active=true,mode=mode,started=core.time(),requests=0,success=0,failed=0,interrupted=0,cancelled=0,external=0,
        spells={},failed_spells={},interrupted_spells={},cancelled_spells={},mana_start=nil,mana_min=nil,mana_end=nil,
        lowest_hp=100,lowest_current=100,critical_mana_seconds=0,last_sample=nil,samples=0,
        emergency_samples=0,low_mana_samples=0,highest_fall_rate=0,highest_predicted_loss=0}
    current_run_start=#lines+1
    emit("RUN_START",{"mode="..clean(mode),"version="..VERSION})
end
local function finish_run(reason)
    if not run.active then return end
    local counts={}
    for id,count in pairs(run.spells) do counts[#counts+1]=tostring(id)..":"..count end
    table.sort(counts)
    local function named_counts(source)
        local out={}
        for id,count in pairs(source or {}) do
            if count>0 then
                local name=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or id
                out[#out+1]=clean(name)..":"..count
            end
        end
        table.sort(out);return #out>0 and table.concat(out,",") or "none"
    end
    emit("RUN_END",{"mode="..clean(run.mode),"reason="..clean(reason),
        "duration="..string.format("%.1f",core.time()-run.started),"requests="..run.requests,
        "success="..run.success,"failed="..run.failed,"interrupted="..run.interrupted,"cancelled="..run.cancelled,
        "external_events="..run.external,
        "mana="..string.format("%s/%s/%s",run.mana_start and string.format("%.1f",run.mana_start) or "?",
            run.mana_min and string.format("%.1f",run.mana_min) or "?",run.mana_end and string.format("%.1f",run.mana_end) or "?"),
        "critical_mana_seconds="..string.format("%.1f",run.critical_mana_seconds),
        "lowest_projected_hp="..string.format("%.1f",run.lowest_hp),
        "lowest_current_hp="..string.format("%.1f",run.lowest_current),
        "failed_spells="..named_counts(run.failed_spells),"interrupted_spells="..named_counts(run.interrupted_spells),
        "cancelled_spells="..named_counts(run.cancelled_spells),
        "successful_spells="..named_counts(run.spells),
        "successful_spell_ids="..(#counts>0 and table.concat(counts,",") or "none")})
    local major_casts=(run.spells[98008] or 0)+(run.spells[108280] or 0)+(run.spells[114052] or 0)
    local execution_failures=run.failed+run.interrupted
    local grade=100-math.min(20,execution_failures*5)
    grade=grade-math.min(20,math.floor(run.critical_mana_seconds/3)*2)
    if run.lowest_hp<=15 and major_casts==0 then grade=grade-15 end
    grade=math.max(0,grade)
    local advice="execution stable; review spell mix and cooldown spacing"
    if execution_failures>=3 then advice="review failed or interrupted cast windows"
    elseif run.critical_mana_seconds>=10 then advice="mana pressure sustained; review Chain Heal and preparation casts"
    elseif run.lowest_hp<=15 and major_casts==0 then advice="major healing cooldown may have been held through lethal pressure"
    elseif run.highest_fall_rate>=20 then advice="fast damage detected; review predictive emergency timing" end
    emit("REPLAY_GRADE",{"mode="..clean(run.mode),"grade="..grade,"samples="..run.samples,
        "major_casts="..major_casts,"emergency_samples="..run.emergency_samples,
        "low_mana_samples="..run.low_mana_samples,
        "max_fall_rate="..string.format("%.1f",run.highest_fall_rate),
        "max_predicted_loss="..string.format("%.1f",run.highest_predicted_loss),
        "advice="..advice})
    run.active=false
end

pcall(function()
    if type(core.create_data_folder)=="function" then core.create_data_folder(DATA_FOLDER) end
    restore_journal()
    if type(core.create_data_file)=="function" then
        for _,path in ipairs(DATA_FILES) do
            local existing=type(core.read_data_file)=="function" and core.read_data_file(path) or nil
            if not existing or existing=="" then core.create_data_file(path) end
        end
    end
    if type(core.create_log_folder)=="function" then core.create_log_folder("resto_shaman_mplus") end
    if type(core.create_log_file)=="function" then core.create_log_file(LOG_PATH) end
end)
emit("LOGGER_START",{"version="..VERSION,"entity="..ENTITY,"standalone=true",
    "enabled="..tostring(enabled()),"path=scripts_log/"..LOG_PATH},true)

function M.path() return "scripts_log/"..LOG_PATH end
function M.identity()
    return {entity=ENTITY,standalone=true,log_path="scripts_log/"..LOG_PATH,
        data_folder="scripts_data/"..DATA_FOLDER,debug_prefix="[RSMDBG]"}
end
function M.recent(count)
    local first=math.max(1,#lines-(count or 120)+1)
    local out={}
    for i=first,#lines do out[#out+1]=lines[i] end
    return table.concat(out,"\n")
end
function M.current_run()
    local out={}
    for i=math.max(1,current_run_start),#lines do out[#out+1]=lines[i] end
    return table.concat(out,"\n")
end
function M.saved_history(count)
    local first=math.max(1,#lines-(count or 5000)+1)
    local out={}
    for i=first,#lines do out[#out+1]=lines[i] end
    return table.concat(out,"\n")
end
function M.clear()
    lines={}
    current_run_start=1
    last_snapshot=-math.huge
    requested_info={};pending_outcomes={};cancelled_requests={};terminal_casts={};journal_dirty=false;last_journal_write=-math.huge
    run={active=false,mode=nil,started=0,requests=0,success=0,failed=0,interrupted=0,cancelled=0,external=0,spells={},failed_spells={},interrupted_spells={},cancelled_spells={}}
    local ok,err=pcall(function()
        if type(core.delete_log_file)=="function" then core.delete_log_file(LOG_PATH) end
        assert(type(core.create_log_file)=="function","core.create_log_file unavailable")
        core.create_log_file(LOG_PATH)
        if type(core.delete_data_file)=="function" then
            for _,path in ipairs(DATA_FILES) do core.delete_data_file(path) end
        end
        if type(core.create_data_file)=="function" then
            for _,path in ipairs(DATA_FILES) do core.create_data_file(path) end
        end
        journal_sequence=0;journal_slot=1
    end)
    if not ok then
        require("rs_settings").log_status="Clear failed: "..clean(err)
        return false
    end
    emit("LOG_CLEARED",{"version="..VERSION,"recording_continues=true"},true)
    return true
end
function M.debug_text(count)
    local first=math.max(1,#debug_lines-(count or 80)+1);local out={}
    for i=first,#debug_lines do out[#out+1]=debug_lines[i] end
    return table.concat(out,"\n")
end
function M.clear_debug()
    debug_lines={};debug_push("INFO","debug buffer cleared");return true
end
function M.debug(kind,message)
    debug_push(kind or "INFO",message or "")
    return true
end
function M.cast(id,target,cast_type)
    if run.active then run.requests=run.requests+1 end
    requested_at[id]=core.time()
    local spell=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or id
    local U=require("rs_units")
    local me=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player() or nil
    local target_hp=U.projected(target)
    local mana_module=require("rs_mana")
    local mana=me and type(mana_module.percent)=="function" and mana_module.percent(me) or nil
    requested_info[id]={guid=unit_guid(target),target=unit_name(target),hp=target_hp,
        mana=mana,time=core.time(),spell=spell}
    local mode=require("rs_context").get().mode
    emit("REQUEST",{"spell="..clean(spell),"id="..id,"type="..cast_type,"target="..unit_name(target),
        "target_hp="..(target_hp and string.format("%.1f",target_hp) or "unknown"),
        "mana="..(mana and string.format("%.1f",mana) or "unknown"),"mode="..clean(mode),
        "decision="..clean(require("rs_settings").status)})
    debug_push("REQUEST",clean(spell).." -> "..unit_name(target))
end
function M.cancel_request(id,reason)
    id=tonumber(id)
    if not id then return false end
    cancelled_requests[id]={time=core.time(),reason=reason or "rotation cancellation"}
    local spell=core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or id
    emit("CANCEL_REQUEST",{"spell="..clean(spell),"id="..id,"reason="..clean(reason)})
    debug_push("CANCEL_REQUEST",clean(spell).." | "..clean(reason))
    return true
end
function M.item(id,target,cast_type)
    if run.active then run.requests=run.requests+1 end
    emit("ITEM",{"id="..id,"type="..cast_type,"target="..unit_name(target)})
    debug_push("ITEM",tostring(id).." -> "..unit_name(target))
end
function M.mode_transition(previous,current)
    emit("MODE_CHANGE",{"from="..clean(previous),"to="..clean(current),
        "predictive_state_reset=true"},true)
    debug_push("MODE_CHANGE",clean(previous).." -> "..clean(current))
end
function M.snapshot(me,rows,profile,b,pressure)
    if not enabled() then return end
    local U=require("rs_units")
    local S=require("rs_spells")
    local A=require("rs_auras")
    local function spell_state(id)
        local ok_known,known=pcall(S.known,id)
        local ok_ready,ready=pcall(S.ready,id)
        return ok_known and known==true,ok_ready and ready==true
    end
    local function aura_state(id)
        local ok,value=pcall(A.present,me,id)
        return ok and value==true
    end
    local combat=U.call(me,"is_in_combat")==true
    for _,r in ipairs(rows or {}) do combat=combat or U.call(r.unit,"is_in_combat")==true end
    local mode=require("rs_context").get().mode
    if combat and (not run.active or run.mode~=mode) then
        if run.active then finish_run("content_changed") end
        reset_run(mode)
    elseif not combat then
        if run.active then finish_run("combat_ended") end
        return
    end
    if core.time()-last_snapshot<1 then return end
    last_snapshot=core.time()
    for i=#pending_outcomes,1,-1 do
        local outcome=pending_outcomes[i]
        if core.time()-outcome.time>=0.8 then
            local after=nil
            for _,row in ipairs(rows or {}) do
                if unit_guid(row.unit)==outcome.guid then after=row.current or row.hp;break end
            end
            local gain=after and outcome.hp and after-outcome.hp or nil
            local probable=outcome.scope=="single"
                and tostring(outcome.hp and outcome.hp>=98 and (not gain or gain<=2)) or "unknown"
            emit("HEAL_OUTCOME",{"spell="..clean(outcome.spell),"id="..clean(outcome.id),
                "target="..clean(outcome.target),
                "scope="..clean(outcome.scope),
                "hp_before="..(outcome.hp and string.format("%.1f",outcome.hp) or "unknown"),
                "hp_after="..(after and string.format("%.1f",after) or "unknown"),
                "observed_gain="..(gain and string.format("%.1f",gain) or "unknown"),
                "probable_overheal="..probable})
            table.remove(pending_outcomes,i)
        end
    end
    if core.time()-last_event_prune>=30 then
        for key,stamp in pairs(recent_events) do
            if core.time()-stamp>15 then recent_events[key]=nil end
        end
        for id,stamp in pairs(requested_at) do
            if core.time()-stamp>15 then requested_at[id]=nil;requested_info[id]=nil end
        end
        last_event_prune=core.time()
    end
    local worst=rows and rows[1]
    local mana=require("rs_mana").plan(me,profile)
    if run.active and mana.percent then
        run.mana_start=run.mana_start or mana.percent
        run.mana_min=math.min(run.mana_min or mana.percent,mana.percent)
        run.mana_end=mana.percent
        local now=core.time()
        if run.last_sample and mana.critical_state then
            run.critical_mana_seconds=run.critical_mana_seconds+math.min(2,now-run.last_sample)
        end
        run.last_sample=now
        run.low_mana_samples=run.low_mana_samples+(mana.critical_state and 1 or 0)
    end
    if run.active and worst then
        run.lowest_hp=math.min(run.lowest_hp,worst.hp or 100)
        run.lowest_current=math.min(run.lowest_current,worst.current or worst.hp or 100)
        run.samples=run.samples+1
        run.highest_fall_rate=math.max(run.highest_fall_rate,worst.velocity or 0)
        run.highest_predicted_loss=math.max(run.highest_predicted_loss,
            math.max(0,(worst.current or worst.hp or 100)-(worst.hp or 100)))
        local emergency=profile and (profile.effective_emergency or profile.emergency) or 35
        if (worst.hp or 100)<=emergency then run.emergency_samples=run.emergency_samples+1 end
    end
    local roster={}
    for _,r in ipairs(rows or {}) do
        roster[#roster+1]=unit_name(r.unit)..":"..string.format("%.0f",r.hp).."/"..string.format("%.0f",r.current or r.hp)
    end
    local C=require("rs_settings")
    local link_known,link_ready=spell_state(S.LINK)
    local tide_known,tide_ready=spell_state(S.TIDE)
    local asc_known,asc_ready=spell_state(S.ASCEND)
    local shift_known,shift_ready=spell_state(S.SHIFT)
    local burrow_known,burrow_ready=spell_state(S.BURROW)
    local grounding_known,grounding_ready=spell_state(S.GROUNDING)
    local nature_known,nature_ready=spell_state(S.NATURE)
    local ancestral_known,ancestral_ready=spell_state(S.ANCESTRAL)
    local control=U.call(me,"get_loss_of_control_info")
    local control_state="none"
    if type(control)=="table" and control.valid~=false then
        control_state=clean(control.type or control.control_type or control.name or control.spell_id or "active")
    end
    local rain_state="unavailable"
    local ok_rain,Rain=pcall(require,"rs_rain")
    if ok_rain and Rain and type(Rain.window)=="function" and type(Rain.coverage)=="function" then
        local window=Rain.window()
        local _,injured,deficit=Rain.coverage(rows,window,98)
        rain_state=string.format("%s,age:%.1f,position:%s,injured:%d,deficit:%.1f",
            clean(window.kind),window.age==math.huge and -1 or window.age,
            tostring(window.position~=nil),injured,deficit)
    end
    emit("STATE",{"mode="..clean(mode),"profile="..clean(profile and profile.name),
        "worst="..unit_name(worst and worst.unit),"hp="..string.format("%.1f",worst and worst.hp or 0),
        "self="..string.format("%.1f",U.projected(me) or 0),
        "mana="..(mana.percent and string.format("%.1f",mana.percent) or "unknown"),"mana_state="..mana.state,
        "mana_forecast="..(mana.forecast and string.format("%.1f",mana.forecast) or "unknown"),
        "mana_time_to_critical="..(mana.time_to_critical and mana.time_to_critical<10000
            and string.format("%.1f",mana.time_to_critical) or "stable"),
        "mana_planning_horizon="..tostring(mana.planning_horizon or "unknown"),
        "fall_rate="..string.format("%.1f",worst and worst.velocity or 0),
        "fall_acceleration="..string.format("%.1f",worst and worst.acceleration or 0),
        "worst_absorb="..string.format("%.1f",worst and worst.absorb or 0),
        "worst_heal_absorb="..string.format("%.1f",worst and worst.heal_absorb or 0),
        "worst_attackers="..tostring(worst and worst.attackers or 0),
        "targeted_casts="..tostring(worst and worst.targeted_casts or 0),
        "cast_bias="..string.format("%.1f",worst and worst.cast_bias or 0),
        "cast_impact="..(worst and worst.cast_remaining and string.format("%.2f",worst.cast_remaining) or "none"),
        "tidal_waves="..tostring(A.stacks(me,S.TIDAL_WAVES)),
        "heal_at="..clean(C.heal_threshold),
        "emergency_at="..clean(profile and (profile.effective_emergency or profile.emergency)),
        "imminent_emergency="..tostring(profile and profile.imminent_emergency==true),
        "time_to_emergency="..(profile and profile.time_to_emergency and profile.time_to_emergency<1000 and string.format("%.2f",profile.time_to_emergency) or "none"),
        "burst="..tostring(pressure and pressure.burst==true),"swap="..tostring(pressure and pressure.swap==true),
        "attackers="..tostring(pressure and pressure.attackers or 0),
        "target_attackers="..tostring(pressure and pressure.target_attackers or 0),
        "self_attackers="..tostring(pressure and pressure.self_attackers or 0),
        "target_defensive="..tostring(pressure and pressure.target_defensive==true),
        "response_horizon="..string.format("%.1f",U.call(me,"is_moving")==true and 1.2 or 2.2),
        "dampening="..string.format("%.1f",profile and profile.dampening or 0),
        "kick_threat="..tostring(require("rs_profiles").kick_threat(me)==true),
        "pressure="..clean(pressure and pressure.reason),
        "control="..control_state,
        "party_timer="..tostring(b and b.party==true),"soon="..tostring(b and b.soon==true),
        "roster="..table.concat(roster,","),"decision="..clean(C.status),
        "link="..clean(C.link_status),"totemic="..clean(C.totemic_status),"rain="..rain_state,
        "dispel="..clean(C.dispel_status),"pvp="..clean(C.pvp_status),
        "purge="..clean(C.purge_status),
        "interrupt="..clean(C.interrupt_status),
        "cc_rotation="..string.format("tremor_age:%.1f,ground_age:%.1f,shear_age:%.1f",
            A.since(S.TREMOR),A.since(S.GROUNDING),A.since(S.WIND_SHEAR)),
        "major="..string.format("link:%s/%s,tide:%s/%s,asc:%s/%s",tostring(link_known),tostring(link_ready),tostring(tide_known),tostring(tide_ready),tostring(asc_known),tostring(asc_ready)),
        "survival="..string.format("shift:%s/%s/%s,burrow:%s/%s,ground:%s/%s,ns:%s/%s/%s,as:%s/%s/%s",
            tostring(shift_known),tostring(shift_ready),tostring(aura_state(S.SHIFT)),
            tostring(burrow_known),tostring(burrow_ready),tostring(grounding_known),tostring(grounding_ready),
            tostring(nature_known),tostring(nature_ready),tostring(aura_state(S.NATURE)),
            tostring(ancestral_known),tostring(ancestral_ready),tostring(aura_state(S.ANCESTRAL))),
        "projection="..clean(C.projection_status),"movement="..clean(C.evade_status)})
    debug_push("STATE",clean(mode).." | hp="..string.format("%.0f",worst and worst.hp or 0).." | mana="..tostring(mana.percent or "?").." | "..clean(C.status))
end
function M.event(event,args)
    if event~="UNIT_SPELLCAST_SUCCEEDED" and event~="UNIT_SPELLCAST_FAILED" and event~="UNIT_SPELLCAST_FAILED_QUIET"
        and event~="UNIT_SPELLCAST_INTERRUPTED" then return end
    if type(args)~="table" or args[1]~="player" then return end
    local id=args[3] or args[4]
    local cast_guid=clean(args[2])
    local event_key=event..":"..cast_guid..":"..clean(id)
    local now=core.time()
    for guid,result in pairs(terminal_casts) do
        if now-(result.time or 0)>10 then terminal_casts[guid]=nil end
    end
    if now-(recent_events[event_key] or -math.huge)<0.25 then return end
    recent_events[event_key]=now
    local previous=cast_guid~="-" and terminal_casts[cast_guid] or nil
    if previous and now-previous.time<=2 then
        -- The client can report FAILED_QUIET immediately before INTERRUPTED for
        -- one cast. Reconcile that sequence instead of charging one plugin cast
        -- with a failure and then inventing a second external interruption.
        if previous.event=="UNIT_SPELLCAST_FAILED_QUIET" and event=="UNIT_SPELLCAST_INTERRUPTED"
            and previous.owned and not previous.cancelled then
            if run.active then
                run.failed=math.max(0,run.failed-1);run.interrupted=run.interrupted+1
                if previous.id then
                    run.failed_spells[previous.id]=math.max(0,(run.failed_spells[previous.id] or 0)-1)
                    run.interrupted_spells[previous.id]=(run.interrupted_spells[previous.id] or 0)+1
                end
            end
            previous.event=event;previous.time=now
            emit("EVENT_RECONCILED",{"cast="..cast_guid,"spell_id="..clean(previous.id),
                "from=UNIT_SPELLCAST_FAILED_QUIET","to=UNIT_SPELLCAST_INTERRUPTED","origin=plugin_request"})
            debug_push("EVENT_RECONCILED",clean(previous.id).." | failed quiet -> interrupted")
        else
            emit("EVENT_DUPLICATE",{"event="..event,"cast="..cast_guid,"spell_id="..clean(id),
                "original_event="..clean(previous.event),"origin="..(previous.owned and "plugin_request" or "external_or_manual")})
        end
        return
    end
    local owned=id~=nil and now-(requested_at[id] or -math.huge)<4
    local info=id and requested_info[id] or nil
    if id then requested_at[id]=nil end
    local cancellation=id and cancelled_requests[id] or nil
    if cancellation and now-cancellation.time>2 then cancellation=nil;cancelled_requests[id]=nil end
    if run.active and owned then
        if event=="UNIT_SPELLCAST_SUCCEEDED" then
            run.success=run.success+1
            if id then run.spells[id]=(run.spells[id] or 0)+1 end
            if info and info.guid and HEAL_OUTCOME_IDS[id] then
                pending_outcomes[#pending_outcomes+1]={id=id,guid=info.guid,target=info.target,
                    hp=info.hp,mana=info.mana,time=now,spell=info.spell,scope=HEAL_OUTCOME_IDS[id]}
                if #pending_outcomes>20 then table.remove(pending_outcomes,1) end
            end
        elseif cancellation then
            run.cancelled=run.cancelled+1
            if id then run.cancelled_spells[id]=(run.cancelled_spells[id] or 0)+1 end
        elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET" then
            run.failed=run.failed+1
            if id then run.failed_spells[id]=(run.failed_spells[id] or 0)+1 end
        else
            run.interrupted=run.interrupted+1
            if id then run.interrupted_spells[id]=(run.interrupted_spells[id] or 0)+1 end
        end
    elseif run.active then run.external=run.external+1 end
    if cast_guid~="-" then
        terminal_casts[cast_guid]={event=event,id=id,owned=owned,cancelled=cancellation~=nil,time=now}
    end
    if id then requested_info[id]=nil;cancelled_requests[id]=nil end
    local spell=id and core.spell_book.get_spell_name and core.spell_book.get_spell_name(id) or id
    local origin=owned and "plugin_request" or "external_or_manual"
    local outcome=cancellation and "plugin_cancel" or (event=="UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "native")
    emit("EVENT",{"event="..event,"cast="..clean(args[2]),"spell="..clean(spell),"spell_id="..clean(id),
        "origin="..origin,"outcome="..outcome,"cancel_reason="..clean(cancellation and cancellation.reason)})
    debug_push(event,clean(spell).." ("..clean(id)..") | "..origin)
end
function M.error(scope,err) debug_push("ERROR",clean(scope).." | "..clean(err));emit("ERROR",{"scope="..clean(scope),"message="..clean(err)},true) end
return M
