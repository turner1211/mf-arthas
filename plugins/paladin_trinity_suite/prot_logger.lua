local ENTITY_ID="project_sylvanas.protection_paladin_mplus.logger"
local NAMESPACE="prot_paladin_mplus"
local M={status="Starting",entity_id=ENTITY_ID,namespace=NAMESPACE,
    path="scripts_log/"..NAMESPACE.."/session.log",
    export_path="scripts_log/"..NAMESPACE.."/recovered.log"}
local Host=require("prot_host")
local DATA_A=NAMESPACE.."/log_snapshot_a.txt"
local DATA_B=NAMESPACE.."/log_snapshot_b.txt"
local OWNER_PATH=NAMESPACE.."/logger_identity.txt"
local LOG_PATH=NAMESPACE.."/session.log"
local EXPORT_PATH=NAMESPACE.."/recovered.log"
-- Persist often enough for crash recovery without rewriting an eventually
-- 900 KB snapshot every second during combat. Urgent errors and logout still
-- force an immediate write.
local MAX_BYTES,FLUSH_INTERVAL=900000,5.0
local lines,bytes,sequence,active_slot={},0,0,"a"
local pending,last_flush,last_snapshot={},-math.huge,-math.huge
local initialized=false
local metrics={casts=0,sotr=0,interrupts=0,defensives=0,heals=0,failures=0,
    combat_samples=0,sotr_samples=0,sotr_gap_seconds=0,interrupt_success=0,
    threat_losses=0,stalled_samples=0}
local DEFENSIVES={[403876]=true,[31850]=true,[86659]=true,[642]=true,[633]=true}
local last_cast_time,last_threat_key,last_threat_time=-math.huge,nil,-math.huge
local sotr_gap_active=false
local last_guidance={}

local function now()
    local ok,value=pcall(core.time); return ok and tonumber(value) or 0
end
local function wall_time()
    if type(core.get_local_time)=="function" then
        local ok,t=pcall(core.get_local_time)
        if ok and type(t)=="table" then return string.format("%04d-%02d-%02d %02d:%02d:%02d",
            t.year or 0,t.month or 0,t.day or 0,t.hour or 0,t.minute or 0,t.second or 0) end
    end
    return string.format("game-time-%.2f",now())
end
local function clean(value)
    if type(value)=="table" then
        local fields={}
        for _,key in ipairs({"message","error","reason","code","status","kind"}) do
            local item=value[key]
            if type(item)=="string" or type(item)=="number" or type(item)=="boolean" then
                fields[#fields+1]=key.."="..tostring(item)
            end
        end
        if #fields==0 then
            for key,item in pairs(value) do
                if type(item)=="string" or type(item)=="number" or type(item)=="boolean" then
                    fields[#fields+1]=tostring(key).."="..tostring(item)
                    if #fields>=6 then break end
                end
            end
        end
        value=#fields>0 and table.concat(fields,",") or "table_error_no_scalar_fields"
    end
    return tostring(value or "-"):gsub("[\r\n|]"," ")
end
local function parse_snapshot(raw)
    if type(raw)~="string" then return nil end
    local seq=tonumber(raw:match("^%[PPMLOG_SNAPSHOT%] seq=(%d+)\n"))
    if not seq then return nil end
    local body=raw:gsub("^[^\n]*\n","",1)
    return seq,body
end
local function load_snapshot()
    if type(core.read_data_file)~="function" then return end
    local ok_a,a=pcall(core.read_data_file,DATA_A);local sa,ba=ok_a and parse_snapshot(a) or nil,nil
    if sa then _,ba=parse_snapshot(a) end
    local ok_b,b=pcall(core.read_data_file,DATA_B);local sb,bb=ok_b and parse_snapshot(b) or nil,nil
    if sb then _,bb=parse_snapshot(b) end
    local body
    if sa and (not sb or sa>=sb) then sequence,active_slot,body=sa,"a",ba
    elseif sb then sequence,active_slot,body=sb,"b",bb end
    for line in tostring(body or ""):gmatch("[^\n]+") do
        lines[#lines+1]=line;bytes=bytes+#line+1
    end
end
local function trim()
    if bytes<=MAX_BYTES or #lines<=1 then return end
    local target,start=MAX_BYTES*0.90,1
    while bytes>target and start<#lines do
        bytes=bytes-#lines[start]-1;start=start+1
    end
    local compact={}
    for index=start,#lines do compact[#compact+1]=lines[index] end
    lines=compact
end
local function snapshot_text(next_sequence)
    return "[PPMLOG_SNAPSHOT] seq="..tostring(next_sequence).."\n"..table.concat(lines,"\n").."\n"
end
function M.flush(force)
    if not initialized or (#pending==0 and not force) then return true end
    if not force and now()-last_flush<FLUSH_INTERVAL then return true end
    local next_sequence=sequence+1
    local next_slot=active_slot=="a" and "b" or "a"
    local path=next_slot=="a" and DATA_A or DATA_B
    local ok,err=pcall(function()
        assert(type(core.create_data_file)=="function" and type(core.write_data_file)=="function",
            "persistent data writer unavailable")
        core.create_data_file(path)
        assert(core.write_data_file(path,snapshot_text(next_sequence))~=false,"snapshot write failed")
        if #pending>0 and type(core.write_log_file)=="function" then
            core.write_log_file(LOG_PATH,table.concat(pending,"\n").."\n")
        end
    end)
    if ok then
        sequence,active_slot,pending,last_flush=next_sequence,next_slot,{},now()
        M.status="Saved • "..tostring(#lines).." lines • seq "..tostring(sequence)
    else M.status="Save failed • retained in memory • "..clean(err) end
    return ok
end
function M.activate()
    if initialized then return true end
    local ok,err=pcall(function()
        if type(core.create_data_folder)=="function" then core.create_data_folder(NAMESPACE) end
        if type(core.create_log_folder)=="function" then core.create_log_folder(NAMESPACE) end
        if type(core.create_data_file)=="function" and type(core.write_data_file)=="function" then
            core.create_data_file(OWNER_PATH)
            core.write_data_file(OWNER_PATH,"entity="..ENTITY_ID.."\nnamespace="..NAMESPACE.."\n")
        end
        load_snapshot()
        if type(core.create_log_file)=="function" then core.create_log_file(LOG_PATH) end
    end)
    if not ok then M.status="Start failed • "..clean(err);return false end
    initialized=true
    local previous_last=lines[#lines] or ""
    M.previous_unclean=sequence>0 and not previous_last:find("PLAYER_LOGOUT",1,true)
        and not previous_last:find("PLAYER_LEAVING_WORLD",1,true)
    M.note("LOGGER_START",{"version=6.14.0","entity="..ENTITY_ID,
        "recovered_lines="..tostring(#lines),"snapshot_sequence="..tostring(sequence),
        "path="..M.path},true)
    if M.previous_unclean then
        M.note("RECOVERED_UNCLEAN_SESSION",{"reason=no_graceful_shutdown_marker"},true)
    end
    return true
end
function M.note(kind,fields,urgent)
    if not initialized and not M.activate() then return false end
    local row={"[PPMLOG]",clean(kind),"clock="..wall_time(),"t="..string.format("%.2f",now())}
    for _,field in ipairs(fields or {}) do row[#row+1]=clean(field) end
    local line=table.concat(row," | ")
    lines[#lines+1]=line;bytes=bytes+#line+1;pending[#pending+1]=line;trim()
    if urgent then M.flush(true) end
end
function M.export()
    M.flush(true)
    local ok,err=pcall(function()
        assert(type(core.create_log_file)=="function" and type(core.write_log_file)=="function",
            "log export API unavailable")
        if type(core.delete_log_file)=="function" then core.delete_log_file(EXPORT_PATH) end
        core.create_log_file(EXPORT_PATH)
        core.write_log_file(EXPORT_PATH,table.concat(lines,"\n").."\n")
    end)
    M.status=ok and ("Export ready • "..M.export_path) or ("Export failed • "..clean(err))
    return ok
end
function M.on_event(event,args)
    if event=="PLAYER_LOGOUT" or event=="PLAYER_LEAVING_WORLD" then
        M.note(event,{"status=graceful_shutdown"},true)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_DEAD" or event=="PLAYER_ALIVE"
        or event=="ENCOUNTER_START" or event=="ENCOUNTER_END" then
        M.note(event,{"arg1="..clean(args and args[1])},event=="PLAYER_DEAD")
    elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET"
        or event=="UNIT_SPELLCAST_INTERRUPTED" then
        if args and args[1]=="player" then M.note("SPELL_EVENT",{"event="..event,
            "cast="..clean(args[2]),"spell_id="..clean(args[3] or args[4])},true)
            metrics.failures=metrics.failures+1 end
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" and type(args)=="table"
        and tostring(args[2] or "")=="SPELL_INTERRUPT" then
        local player=Host.manager("get_local_player")
        local player_guid
        if player and type(player.get_guid)=="function" then
            local ok,value=pcall(player.get_guid,player);if ok then player_guid=tostring(value) end
        end
        if player_guid and tostring(args[4] or "")==player_guid then
            metrics.interrupt_success=metrics.interrupt_success+1
            M.note("INTERRUPT_CONFIRMED",{"spell_id="..clean(args[12]),
                "interrupted_spell_id="..clean(args[15]),"target="..clean(args[8])})
        end
    end
end
function M.cast(spell_id,target,status)
    local guid="-"
    if target and target.get_guid then local ok,value=pcall(target.get_guid,target);if ok then guid=clean(value) end end
    if tostring(status):find("accepted",1,true) then
        last_cast_time=now()
        metrics.casts=metrics.casts+1
        spell_id=tonumber(spell_id)
        if spell_id==53600 then metrics.sotr=metrics.sotr+1 end
        if spell_id==96231 or spell_id==31935 or spell_id==853 or spell_id==115750 then
            metrics.interrupts=metrics.interrupts+1
        end
        if DEFENSIVES[spell_id] then metrics.defensives=metrics.defensives+1 end
        if spell_id==85673 then metrics.heals=metrics.heals+1 end
    end
    M.note("CAST",{"spell_id="..clean(spell_id),"target="..guid,"status="..clean(status)})
end
function M.threat_loss(entry)
    if not entry or not entry.object then return end
    local key=tostring(entry.object)
    if type(entry.object.get_guid)=="function" then
        local ok,value=pcall(entry.object.get_guid,entry.object);if ok and value then key=tostring(value) end
    end
    if key==last_threat_key and now()-last_threat_time<2 then return end
    last_threat_key,last_threat_time=key,now();metrics.threat_losses=metrics.threat_losses+1
    M.note("THREAT_LOSS",{"target="..clean(key),"percent="..clean(entry.threat_percent),
        "status="..clean(entry.status),"needs_taunt="..tostring(entry.needs_taunt~=false)})
end
local function guidance_change(system,value,fields)
    value=clean(value)
    if last_guidance[system]==value then return end
    local previous=last_guidance[system] or "-";last_guidance[system]=value
    metrics.guidance_changes=(metrics.guidance_changes or 0)+1
    local row={"system="..system,"from="..previous,"to="..value}
    for _,field in ipairs(fields or {}) do row[#row+1]=field end
    M.note("GUIDANCE_CHANGE",row)
end
function M.snapshot(player,settings,route)
    if now()-last_snapshot<1 then M.flush(false);return end
    local sample_delta=last_snapshot>-math.huge and math.max(0,math.min(2,now()-last_snapshot)) or 0
    last_snapshot=now()
    local hp,max_hp,combat,holy_power,sotr=0,0,false,0,false
    if player then pcall(function() hp=player:get_health();max_hp=player:get_max_health();combat=player:is_in_combat() end) end
    if player then
        pcall(function() holy_power=player:get_power(9) or 0 end)
        pcall(function()
            local aura=player:get_buff_data({132403})
            sotr=type(aura)=="table" and aura.is_active~=false
        end)
    end
    if combat then
        metrics.combat_samples=metrics.combat_samples+1
        if sotr then metrics.sotr_samples=metrics.sotr_samples+1 end
        if not sotr then
            metrics.sotr_gap_seconds=metrics.sotr_gap_seconds+sample_delta
            if not sotr_gap_active then M.note("SOTR_GAP_START",{"holy_power="..clean(holy_power)});sotr_gap_active=true end
        elseif sotr_gap_active then M.note("SOTR_GAP_END",{"gap_total="..string.format("%.1f",metrics.sotr_gap_seconds)});sotr_gap_active=false end
        if now()-last_cast_time>2 then metrics.stalled_samples=metrics.stalled_samples+1 end
    elseif sotr_gap_active then
        M.note("SOTR_GAP_END",{"reason=combat_end","gap_total="..string.format("%.1f",metrics.sotr_gap_seconds)});sotr_gap_active=false
    end
    local percent=max_hp>0 and hp*100/max_hp or 0
    local uptime=metrics.combat_samples>0 and metrics.sotr_samples*100/metrics.combat_samples or 0
    local recovery=route and route.recovery_targets and route.recovery_targets[1]
    local recovery_guid=recovery and recovery.guid or "-"
    guidance_change("boss",settings and settings.boss_guide_status,
        {"combat="..tostring(combat)})
    guidance_change("danger",settings and settings.danger_status,
        {"combat="..tostring(combat)})
    guidance_change("route",(route and route.route_name or "-")..":"
        ..clean(route and route.pull_index)..":"..clean(route and route.decision),
        {"risk="..clean(route and route.risk),"recovery_target="..clean(recovery_guid),
        "off_route="..clean(route and route.off_route_enemies)})
    M.note("STATE",{"combat="..tostring(combat),"hp="..string.format("%.1f",percent),
        "holy_power="..clean(holy_power),"sotr="..tostring(sotr),
        "sotr_sampled_uptime="..string.format("%.1f",uptime),
        "casts="..metrics.casts,"sotr_casts="..metrics.sotr,
        "interrupts="..metrics.interrupts,"defensives="..metrics.defensives,
        "interrupt_success="..metrics.interrupt_success,
        "threat_losses="..metrics.threat_losses,
        "guidance_changes="..clean(metrics.guidance_changes or 0),
        "sotr_gap_seconds="..string.format("%.1f",metrics.sotr_gap_seconds),
        "stalled_samples="..metrics.stalled_samples,
        "heals="..metrics.heals,"failures="..metrics.failures,
        "status="..clean(settings and settings.status),"route="..clean(route and route.route_name),
        "boss_guide="..clean(settings and settings.boss_guide_status),
        "danger_zone="..clean(settings and settings.danger_status),
        "pull="..clean(route and route.pull_index),"risk="..clean(route and route.risk),
        "decision="..clean(route and route.decision),"match="..clean(route and route.match_confidence),
        "off_route="..clean(route and route.off_route_enemies),
        "recovery_target="..clean(recovery_guid),
        "forces="..clean(route and route.completed_forces).."/"..clean(route and route.required_forces)})
    M.flush(false)
end
function M.error(scope,err) M.note("ERROR",{"scope="..clean(scope),"message="..clean(err)},true) end
function M.recent(count)
    local out={};for i=math.max(1,#lines-(count or 200)+1),#lines do out[#out+1]=lines[i] end
    return table.concat(out,"\n")
end
function M.metrics() local copy={};for key,value in pairs(metrics) do copy[key]=value end;return copy end
return M
