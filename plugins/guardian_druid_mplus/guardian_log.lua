local M={}
local LOG_PATH="guardian_druid_mplus/session.log"
local DATA_PATH="guardian_druid_mplus/logs/session_history.txt"
local MARKER_PATH="guardian_druid_mplus/logs/session_marker.txt"
local MAX_BYTES=600000
local VERSION=require("guardian_version")
local rows,previous,dirty,next_flush,last_values={},"",false,0,{}
local append_error=nil
local error_times={}
local last_context={}
local death_recorded=false
local next_critical_snapshot=0
local next_heartbeat=0
local combat={active=false,started=0,min_hp=100}
M.log_path="scripts_log/"..LOG_PATH
M.copy_path="scripts_data/"..DATA_PATH
M.error=nil
local function clean(value,limit)
    local text=tostring(value==nil and "nil" or value):gsub("[|\r\n]"," ")
    return text:sub(1,limit or 256)
end
local function now()
    local ok,value=pcall(core.time); return ok and tonumber(value) or 0
end
local function fields_text(fields)
    local keys,out={},{}
    for key in pairs(fields or {}) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do out[#out+1]=clean(key,40).."="..clean(fields[key],180) end
    return table.concat(out," | ")
end
local function retained_text()
    local current=table.concat(rows,"\n")
    local combined=current=="" and previous or (previous~="" and (previous.."\n"..current) or current)
    if #combined>MAX_BYTES then combined="[older log entries trimmed]\n"..combined:sub(-(MAX_BYTES-32)) end
    return combined
end
function M.record(level,category,event,fields)
    local line=string.format("[t=%.2f] | [%s] | [%s] | event=%s",now(),clean(level,12),clean(category,24),clean(event,80))
    local extra=fields_text(fields); if extra~="" then line=line.." | "..extra end
    rows[#rows+1]=line; if #rows>1500 then table.remove(rows,1) end; dirty=true
    if type(core.write_log_file)=="function" then
        local ok,err=pcall(core.write_log_file,LOG_PATH,line.."\n")
        append_error=(not ok or err==false) and clean(ok and "append write failed" or err,300) or nil
        if append_error then M.error=append_error end
    end
    return line
end
function M.runtime_error(category,message)
    local key=clean(category,24)..":"..clean(message,300)
    if now()<(error_times[key] or -math.huge)+5 then return false end
    error_times[key]=now()
    M.record("ERROR",category,"runtime",{message=message})
    M.flush(true)
    return true
end
function M.transition(key,value,level,category,event,fields)
    local normalized=clean(value,220)
    local detail=normalized
    -- Keep countdown animation in the UI without writing a new disk entry
    -- every tenth of a second for an unchanged mechanic or decision.
    if key=="bigwigs" or key=="status" then normalized=normalized:gsub(" in %d+%.?%d*s$","") end
    if last_values[key]==normalized then return false end
    last_values[key]=normalized; fields=fields or {}; fields.state=normalized
    if detail~=normalized then fields.detail=detail end
    M.record(level or "INFO",category or "STATE",event or "changed",fields); return true
end
function M.flush(force)
    if not dirty then return true end
    local t=now(); if not force and t<next_flush then return true end; next_flush=t+1
    local ok,err=pcall(function()
        assert(type(core.write_data_file)=="function","data writer unavailable")
        if type(core.create_data_folder)=="function" then
            core.create_data_folder("guardian_druid_mplus"); core.create_data_folder("guardian_druid_mplus/logs")
        end
        if type(core.create_data_file)=="function" then core.create_data_file(DATA_PATH) end
        assert(core.write_data_file(DATA_PATH,retained_text())~=false,"snapshot write failed")
    end)
    if ok then previous=retained_text(); rows={}; dirty=false; M.error=append_error else M.error=clean(err,300) end
    return ok
end
function M.text() return retained_text() end
function M.suspend()
    if combat.active then
        M.record("INFO","COMBAT","summary",{duration=string.format("%.1f",math.max(0,now()-combat.started)),
            min_hp=combat.min_hp,outcome="Guardian inactive"})
        combat={active=false,started=0,min_hp=100}
        M.transition("combat","inactive","INFO","COMBAT","state")
    end
    M.flush(true)
end
function M.initialize()
    local unclean=false
    pcall(function()
        if type(core.create_log_folder)=="function" then core.create_log_folder("guardian_druid_mplus") end
        if type(core.create_log_file)=="function" then core.create_log_file(LOG_PATH) end
        if type(core.read_data_file)=="function" then
            local old=core.read_data_file(DATA_PATH)
            if type(old)=="string" and old~="" then previous=old:sub(-MAX_BYTES) end
            local marker=tostring(core.read_data_file(MARKER_PATH) or "")
            -- Some hosts append data-file writes. Read the final marker so an
            -- accumulated "activeactive" file still reports a prior crash.
            local last=marker:match("(active)%s*$") or marker:match("(clean)%s*$")
            unclean=last=="active"
        end
    end)
    M.record(unclean and "WARN" or "INFO","SESSION",unclean and "previous_session_unclean" or "start",{version=VERSION,recovered_bytes=#previous})
    pcall(function() if type(core.create_data_file)=="function" then core.create_data_file(MARKER_PATH) end; core.write_data_file(MARKER_PATH,"\nactive") end)
    M.flush(true)
end
local function call(object,method,...)
    if not object or type(object[method])~="function" then return nil end
    local ok,value=pcall(object[method],object,...); if ok then return value end
end
local function player_context(player,settings)
    local health,maximum=tonumber(call(player,"get_health")) or 0,tonumber(call(player,"get_max_health")) or 0
    local point=call(player,"get_position") or {}
    local target=call(player,"get_target")
    return {hp=maximum>0 and math.floor(health*100/maximum+0.5) or 0,map=type(core.get_map_id)=="function" and core.get_map_id() or 0,
        x=string.format("%.1f",tonumber(point.x) or 0),y=string.format("%.1f",tonumber(point.y) or 0),z=string.format("%.1f",tonumber(point.z) or 0),
        target=call(target,"get_name") or call(target,"get_npc_id") or "none",mode=settings.mode_status,route=settings.route_status,status=settings.status}
end
function M.observe(settings,player)
    local in_combat=player and call(player,"is_dead")~=true and call(player,"is_in_combat")==true or false
    local context=player_context(player,settings)
    last_context=context
    local dead=call(player,"is_dead")==true
    if player and call(player,"is_valid")==true and not dead then death_recorded=false end
    if dead and not death_recorded then M.on_event("PLAYER_DEAD",{}) end
    if in_combat and not combat.active then
        combat={active=true,started=now(),min_hp=context.hp}; M.record("INFO","COMBAT","start",context)
    elseif in_combat then combat.min_hp=math.min(combat.min_hp,context.hp)
    elseif combat.active then
        context.duration=string.format("%.1f",math.max(0,now()-combat.started)); context.min_hp=combat.min_hp
        M.record("INFO","COMBAT","summary",context); combat={active=false,started=0,min_hp=100}
    end
    M.transition("combat",in_combat and "active" or "inactive","INFO","COMBAT","state")
    M.transition("mode",settings.mode_status,"INFO","PVE","mode")
    M.transition("status",settings.status,"INFO","ROTATION","decision")
    M.transition("route",settings.route_status,"INFO","ROUTE","status")
    M.transition("utility",settings.gathering_status,"INFO","UTILITY","status")
    M.transition("repair",settings.repair_status,"INFO","REPAIR","status")
    M.transition("bigwigs",settings.bigwigs_status,"INFO","BIGWIGS","status")
    M.transition("cooldown",settings.cooldown_status,"INFO","COOLDOWN","decision")
    if now()>=next_heartbeat then next_heartbeat=now()+30; M.record("INFO","SESSION","heartbeat",context) end
    if in_combat and context.hp<=35 and now()>=next_critical_snapshot then
        next_critical_snapshot=now()+5
        M.record("WARN","SURVIVAL","critical_snapshot",context)
        M.flush(true)
    end
    M.flush(false)
    settings.log_status=M.error and ("Write problem: "..M.error) or ("Saved: "..M.copy_path)
end
function M.on_event(event,args)
    local important={PLAYER_LOGOUT=true,PLAYER_LEAVING_WORLD=true,PLAYER_DEAD=true,PLAYER_ENTERING_WORLD=true}
    if important[event] then
        if event=="PLAYER_DEAD" then
            if death_recorded then return end
            death_recorded=true
        end
        M.record("INFO","GAME",event,{args=type(args)=="table" and #args or 0})
        if (event=="PLAYER_DEAD" or event=="PLAYER_LOGOUT") and combat.active then
            local summary={duration=string.format("%.1f",math.max(0,now()-combat.started)),min_hp=event=="PLAYER_DEAD" and 0 or combat.min_hp,outcome=event}
            M.record("INFO","COMBAT","summary",summary)
            combat={active=false,started=0,min_hp=100}
        end
        if event=="PLAYER_DEAD" then
            local report="Guardian Druid last death report\n"..fields_text(last_context).."\n--- Recent session history ---\n"..retained_text():sub(-30000)
            local ok,err=pcall(function()
                local path="guardian_druid_mplus/logs/last_death.txt"
                if core.create_data_file then core.create_data_file(path) end
                assert(core.write_data_file(path,report)~=false,"death report write failed")
            end)
            if not ok then M.runtime_error("DEATH_REPORT",err) end
        end
        pcall(function() core.write_data_file(MARKER_PATH,event=="PLAYER_LOGOUT" and "\nclean" or "\nactive") end)
        M.flush(true)
    end
end
return M
