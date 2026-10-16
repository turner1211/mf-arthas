local BigWigs=require("guardian_bigwigs")
local Mode=require("guardian_mode")
local HealthPrediction=require("common/modules/health_prediction")
local Objects=require("guardian_objects")
local M={}
local state={time=nil,health_fraction=nil,loss_rate=0}

local function safe(object,method,...)
    if not object or type(object[method])~="function" then return nil end
    local ok,value=pcall(object[method],object,...)
    if ok then return value end
end
local function guid(object)
    local value=safe(object,"get_guid")
    return value and tostring(value) or nil
end
local function same(left,right)
    if left==right then return true end
    local a,b=guid(left),guid(right)
    return a and b and a==b or false
end
local function health_velocity(now,health,maximum)
    local fraction=health/maximum
    if not state.time or now<state.time or now-state.time>2 or state.maximum~=maximum then
        state.time,state.health_fraction,state.loss_rate,state.maximum=now,fraction,0,maximum
        return 0
    end
    local elapsed=now-state.time
    if elapsed>=0.25 then
        -- Protection Paladin's minimum sample interval avoids render-frame spikes.
        -- Preserve Guardian's percentage comparison for max-health transitions.
        local raw=math.max(0,(state.health_fraction-fraction)*maximum/elapsed)
        local weight=1-math.exp(-elapsed/0.75)
        state.loss_rate=state.loss_rate*(1-weight)+raw*weight
        state.time,state.health_fraction=now,fraction
    end
    return state.loss_rate
end
local function casts(player,window)
    local pressure,count,physical,magic=0,0,false,false
    local seen,spell_pressure={},{}
    for _,unit in pairs(Objects.get()) do
        local identity=guid(unit) or tostring(unit)
        if not seen[identity] and safe(unit,"is_valid")==true and safe(unit,"is_dead")~=true
            and safe(unit,"is_unit")==true and safe(player,"can_attack",unit)==true
            and (safe(unit,"is_casting_spell")==true or safe(unit,"is_channelling_spell")==true)
            and same(safe(unit,"get_active_spell_target"),player) then
            local channel=safe(unit,"is_channelling_spell")==true
            local finish=tonumber(safe(unit,channel and "get_active_channel_cast_end_time" or "get_active_spell_cast_end_time"))
            -- Cast timestamps share the client's millisecond clock, not the
            -- injection clock used for request throttles.
            local remaining=finish and finish>0 and (finish-core.game_time())/1000 or nil
            if not remaining or remaining>=0 and (channel or remaining<=window) then
                seen[identity]=true
                count=count+1
                local urgency=safe(unit,"is_active_spell_interruptable")==true and 6 or 12
                pressure=pressure+urgency
                local school=tonumber(safe(unit,"get_active_spell_school"))
                local spell=tonumber(safe(unit,channel and "get_active_channel_spell_id" or "get_active_spell_id"))
                if spell and spell>0 then spell_pressure[spell]=(spell_pressure[spell] or 0)+urgency end
                if not school and spell and core.spell_book.get_spell_school then
                    local ok,value=pcall(core.spell_book.get_spell_school,spell); if ok then school=tonumber(value) end
                end
                if school==1 then physical=true elseif school and school>1 then magic=true end
            end
        end
    end
    return math.min(30,pressure),count,physical,magic,spell_pressure
end
local function party_engaged(player,unit)
    local victim=safe(unit,"get_target")
    if same(victim,player) or safe(victim,"is_party_member")==true then return true end
    local threat=safe(player,"get_threat_situation",unit)
    if type(threat)=="table" and (threat.is_tanking==true or (tonumber(threat.status) or 0)>0) then return true end
    if Mode.is_delve() and victim and safe(victim,"is_dead")~=true and safe(player,"can_attack",victim)==false then return true end
    return false
end
local function pack(player)
    local origin=safe(player,"get_position")
    if not origin then return 0,0 end
    local count,encounter_pressure=0,0
    local seen={}
    local encounter_add_distance=nil
    for _,unit in pairs(Objects.get()) do
        local identity=guid(unit) or tostring(unit)
        if not seen[identity] and safe(unit,"is_valid")==true and safe(unit,"is_dead")~=true
            and safe(player,"can_attack",unit)==true and safe(unit,"is_in_combat")==true
            and party_engaged(player,unit) then
            seen[identity]=true
            local point=safe(unit,"get_position")
            if point then
                local dx,dy,dz=point.x-origin.x,point.y-origin.y,point.z-origin.z
                local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
                if distance<=15 then count=count+1 end
                if tonumber(safe(unit,"get_npc_id"))==257846 then
                    encounter_add_distance=math.min(encounter_add_distance or math.huge,distance)
                    if distance<=10 then encounter_pressure=45
                    elseif distance<=20 then encounter_pressure=30 end
                end
            end
        end
    end
    return math.min(18,count*1.5)+encounter_pressure,count,encounter_add_distance
end

function M.evaluate(player,window,use_timers,timer_lead)
    window=math.max(1,math.min(5,tonumber(window) or 3))
    local health=tonumber(safe(player,"get_health")) or 0
    local maximum=tonumber(safe(player,"get_max_health")) or 0
    if maximum<=0 then return nil end
    local incoming=safe(player,"get_incoming_damage",window)
    if incoming==nil then incoming=safe(HealthPrediction,"get_incoming_damage",player,window) end
    incoming=math.max(0,tonumber(incoming) or 0)
    local heals=math.max(0,tonumber(safe(player,"get_incoming_heals")) or 0)
    local heal_absorb=math.max(0,tonumber(safe(player,"get_total_heal_absorbs")) or 0)
    local healer_low=Mode.healer_mana~=nil and Mode.healer_mana<=15
    -- Healing must clear a confirmed heal absorb before it can recover health.
    local usable_heals=math.max(0,heals-heal_absorb)
    -- Incoming-heal APIs can retain optimistic or stale values during healer
    -- loss. Preserve some confirmed off-healing without trusting it equally.
    local heal_cap=Mode.healer_unavailable and 0.15 or healer_low and 0.30 or 0.50
    local credited_heals=math.min(usable_heals,incoming*heal_cap)
    local net=math.max(0,incoming-credited_heals)
    local loss=health_velocity(core.time(),health,maximum)
    local trend=loss*math.min(window,1.5)
    local cast_pressure,targeted,physical,magic,spell_pressure=casts(player,window)
    local pack_pressure,enemies,encounter_add_distance=pack(player)
    local timer=use_timers and BigWigs.scan(timer_lead or window) or nil
    local timer_pressure=timer and ((timer.severity==2 and 36 or 24)
        +math.min(24,math.max(0,(tonumber(timer.overlap_count) or 1)-1)*12)) or 0
    -- Adapt Protection Paladin's complementary-evidence rule only when the
    -- live spell ID matches the timer key. Different mechanics remain additive.
    local duplicate_pressure=timer and spell_pressure and spell_pressure[tonumber(timer.key)] or 0
    local mechanic_pressure=cast_pressure+timer_pressure-math.min(cast_pressure,timer_pressure,duplicate_pressure)
    local group_pressure=((Mode.dead or 0)>0 and 10 or 0)+(Mode.healer_unavailable and enemies>0 and 12 or 0)
        +(healer_low and enemies>0 and not Mode.healer_unavailable and 6 or 0)
    local solo_delve_pressure=Mode.is_delve() and Mode.solo and 8 or 0
    local incoming_pct=net/maximum*100
    local trend_pct=trend/maximum*100
    -- The framework estimate already includes recent damage. Treat the health
    -- trend as an alternative estimate, rather than counting the same hit twice.
    local damage_pct=math.max(incoming_pct,trend_pct)
    local current=health/maximum*100
    return {current_pct=current,projected_pct=math.max(0,current-damage_pct),
        danger=damage_pct+mechanic_pressure+pack_pressure+group_pressure+solo_delve_pressure,
        time_to_die=loss>0 and health/loss or math.huge,targeted_casts=targeted,
        enemy_count=enemies,timer=timer,encounter_add_distance=encounter_add_distance,
        timer_kind=timer and timer.kind or nil,
        heal_absorb=heal_absorb,usable_incoming_heals=usable_heals,credited_incoming_heals=credited_heals,healer_unavailable=Mode.healer_unavailable,healer_low=healer_low,party_dead=Mode.dead or 0,solo_delve=Mode.is_delve() and Mode.solo,
        physical=physical or timer and timer.school=="physical" or false,
        magic=magic or timer and timer.school=="magic" or false}
end
function M.reset() state={time=nil,health_fraction=nil,loss_rate=0} end
return M
