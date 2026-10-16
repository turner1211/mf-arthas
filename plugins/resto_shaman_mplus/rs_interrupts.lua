local U,S,C=require("rs_units"),require("rs_spells"),require("rs_settings")
local M={}
local last_shear={unit=nil,guid=nil,time=-math.huge,confirmed=false}
local VOID_TOXIN=1294983
local SOUL_EXTINCTION=1294981
local PVP_CAST_PRIORITY={
    [51514]=220,  -- Hex
    [305483]=220, -- Lightning Lasso
    [118]=180,    -- Polymorph
    [33786]=180,  -- Cyclone
    [20066]=180,  -- Repentance
    [5782]=180,   -- Fear
    [605]=180,    -- Mind Control
    [360806]=180, -- Sleep Walk
    [77472]=100,  -- Healing Wave
    [188196]=-40, -- Lightning Bolt
    [188443]=-40, -- Chain Lightning
    [51505]=-40,  -- Lava Burst
}
local PVP_NAME_PRIORITY={
    ["hex"]=220,["lightning lasso"]=220,["polymorph"]=180,["cyclone"]=180,
    ["repentance"]=180,["fear"]=180,["mind control"]=180,["sleep walk"]=180,
    ["healing wave"]=100,["lightning bolt"]=-40,["chain lightning"]=-40,["lava burst"]=-40,
}
local function pvp_cast_priority(id,name)
    local value=PVP_CAST_PRIORITY[id]
    if value then return value end
    for fragment,weight in pairs(PVP_NAME_PRIORITY) do
        if name:find(fragment,1,true) then return weight end
    end
    return 0
end

local function normalized_time(value)
    value=tonumber(value)
    if not value then return nil end
    if value>100000 then value=value/1000 end
    return value
end

local function cast_progress(unit)
    local channel=U.call(unit,"is_channelling_spell")==true
    local prefix=channel and "get_active_channel_" or "get_active_spell_cast_"
    local started=normalized_time(U.call(unit,prefix.."start_time"))
    local finishes=normalized_time(U.call(unit,prefix.."end_time"))
    if not started or not finishes or finishes<=started then return 100,nil end
    local now=core.time()
    local progress=math.max(0,math.min(100,((now-started)/(finishes-started))*100))
    return progress,finishes-now
end

local function active_spell(unit)
    local id=tonumber(U.call(unit,"get_active_spell_id"))
    local name=U.call(unit,"get_active_spell_name")
    if type(name)~="string" and id and core.spell_book and type(core.spell_book.get_spell_name)=="function" then
        local ok,value=pcall(core.spell_book.get_spell_name,id)
        if ok then name=value end
    end
    return id,type(name)=="string" and name:lower() or ""
end

local function aztarec_priority(unit)
    if require("rs_context").get().mode~="delve" then return 0,false end
    local id,name=active_spell(unit)
    if id==VOID_TOXIN or name:find("void toxin",1,true) then return 0,true end
    if id==SOUL_EXTINCTION or name:find("soul extinction",1,true) then return 1000,false end
    return 0,false
end

function M.run(me,pvp)
    if not C.get("interrupts") then
        C.interrupt_status="Disabled"
        return false
    end
    local shear_ready=S.ready(S.WIND_SHEAR)
    local stun_ready=not pvp and C.get("pve_stun_interrupt") and S.ready(S.CAPACITOR)
    local candidates={}
    local selected=U.call(me,"get_target")
    if U.valid(selected) and U.call(me,"can_attack",selected)==true then candidates[#candidates+1]=selected end
    for _,u in pairs(U.objects()) do
        local hostile=U.call(u,"is_enemy_with",me)==true or U.call(me,"can_attack",u)==true
        local correct_type=not pvp or U.call(u,"is_player")==true
        if U.valid(u) and hostile and correct_type and U.distance(me,u)<=30 and u~=selected then
            candidates[#candidates+1]=u
        end
    end
    local target,target_progress,target_score,target_spell_id,target_spell_name
    local stun_target,stun_remaining,stun_score
    local threshold=pvp and (C.get("pvp_interrupt_at") or 65) or 0
    local waiting_progress
    local holding_for_extinction=false
    for _,u in ipairs(candidates) do
        local casting=U.call(u,"is_casting_spell")==true or U.call(u,"is_channelling_spell")==true
        if casting and U.call(u,"is_active_spell_interruptable")==true then
            local progress,remaining=cast_progress(u)
            local priority,reserve=aztarec_priority(u)
            local active_window=not remaining or remaining>0
            if reserve then
                holding_for_extinction=true
            elseif active_window and shear_ready and (progress>=threshold or (remaining and remaining<=0.18)) then
                local spell_id,spell_name=active_spell(u)
                local score=progress+priority+(pvp and pvp_cast_priority(spell_id,spell_name) or 0)
                local victim=U.call(u,"get_target")
                if U.valid(victim) and U.call(victim,"is_enemy_with",me)~=true then
                    local hp=U.projected(victim)
                    if hp then score=score+(100-hp) end
                end
                if pvp and U.call(u,"get_group_role")==1 then score=score+20 end
                if not target_score or score>target_score then
                    target,target_progress,target_score=u,progress,score
                    target_spell_id,target_spell_name=spell_id,spell_name
                end
            elseif active_window and shear_ready and (not waiting_progress or progress>waiting_progress) then waiting_progress=progress end
            if not reserve and stun_ready and not shear_ready and remaining and remaining>=1.7 and remaining<=2.6
                and U.distance(me,u)<=8 then
                local score=100-math.abs(2.05-remaining)*20
                local victim=U.call(u,"get_target")
                if U.valid(victim) and U.call(victim,"is_enemy_with",me)~=true then
                    score=score+(100-(U.projected(victim) or 100))
                end
                if not stun_score or score>stun_score then
                    stun_target,stun_remaining,stun_score=u,remaining,score
                end
            end
        end
    end
    if not target then
        if stun_target and S.cast(S.CAPACITOR,stun_target,me,true) then
            C.interrupt_status=string.format("Capacitor backup placed; cast ends in %.1fs",stun_remaining)
            return true
        end
        C.interrupt_status=waiting_progress
            and string.format("Waiting: cast %.0f%% / Wind Shear at %d%%",waiting_progress,threshold)
            or (holding_for_extinction and "Holding Wind Shear: dispel Void Toxin; reserve for Soul Extinction")
            or (shear_ready and "Watching enemy casts" or "Wind Shear unavailable; watching Capacitor window")
        return false
    end
    if S.cast(S.WIND_SHEAR,target,me,false,false,true) then
        last_shear={unit=target,guid=U.guid(target),time=core.time(),confirmed=false}
        local cast_label=target_spell_name~="" and target_spell_name or tostring(target_spell_id or "unknown cast")
        C.interrupt_status=string.format("Wind Shear requested on %s (%s) at %.0f%%",
            cast_label,tostring(target_spell_id or "unknown"),target_progress or 100)
        return true
    end
    C.interrupt_status="Interrupt detected; waiting for range or accepted input"
    return false
end

function M.recent_target(seconds)
    if last_shear.confirmed and core.time()-last_shear.time<=(seconds or 4) and U.valid(last_shear.unit)
        and U.guid(last_shear.unit)==last_shear.guid then return last_shear.unit end
end

function M.event(event,args)
    if type(args)~="table" or args[1]~="player" then return end
    local id=tonumber(args[3] or args[4] or args[#args])
    if id~=S.WIND_SHEAR or core.time()-last_shear.time>3 then return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        last_shear.confirmed=true;last_shear.time=core.time()
    elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET"
        or event=="UNIT_SPELLCAST_INTERRUPTED" then
        last_shear.confirmed=false
    end
end

return M
