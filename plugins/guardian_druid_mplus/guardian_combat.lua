local Group=require("guardian_group")
local Aura=require("guardian_aura")
local Threat=require("guardian_threat")
local enums=require("common/enums")
local Settings=require("guardian_settings")
local Mode=require("guardian_mode")
local DungeonPriorities=require("guardian_dungeon_priorities")
local Objects=require("guardian_objects")
local M={status="Ready",interrupt="Watching casts",utility="Ready",target_reason="Current target"}
M.priority_interrupts={}
for spell in pairs(DungeonPriorities.interrupt) do M.priority_interrupts[spell]=true end
for _,profile in ipairs(require("guardian_encounter_data").bosses or {}) do
    for spell,mechanic in pairs(profile.mechanics or {}) do
        if mechanic.kind=="interrupt" then M.priority_interrupts[spell]=true end
    end
end
local failed_until={}
local next_failure_cleanup=0
local last_face=-math.huge
local locked_target,lock_until=nil,-math.huge
local recent_party_interrupts={}
local PARTY_INTERRUPTS={
    [96231]=true,[1766]=true,[6552]=true,[2139]=true,[57994]=true,
    [106839]=true,[116705]=true,[47528]=true,[183752]=true,
    [351338]=true,[147362]=true,[187707]=true,[15487]=true,
    [78675]=true,[31935]=true,
}

local function call(o,k,...)
    if not o or type(o[k])~="function" then return nil end
    local ok,v=pcall(o[k],o,...); if ok then return v end
end
local function guid(o) return Aura.guid(o) or tostring(o) end
local function valid(o) return call(o,"is_valid")==true and call(o,"is_dead")~=true end
local function same(a,b) return Threat.same(a,b) end
local function distance(a,b)
    local x,y=call(a,"get_position"),call(b,"get_position")
    if not x or not y then return math.huge end
    return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2)
end
local function reachable(player,unit,range)
    if distance(player,unit)>(range or 40) then return false end
    if core.graphics and type(core.graphics.is_line_of_sight)=="function" then
        local ok,los=pcall(core.graphics.is_line_of_sight,player,unit)
        if ok and los==false then return false end
    end
    return true
end
-- Adapted from the installed Rogue's positive-aura protection checks.
local BREAKABLE={6770,2094,1776,118,51514,20066,8122,5782,3355,6358,33786}
local IMMUNE={642,45438,186265,33786,710}
local function has_any(unit,ids)
    for _,id in ipairs(ids) do if Aura.read(unit,id) or Aura.read(unit,id,true) then return true end end
    return false
end
function M.damage_blocked(unit)
    return has_any(unit,BREAKABLE) or has_any(unit,IMMUNE) or call(unit,"is_damage_immune")==true
end
function M.control_nearby(player,radius)
    for _,unit in pairs(Objects.get()) do
        if valid(unit) and call(player,"can_attack",unit)==true and distance(player,unit)<=(radius or 10)
            and has_any(unit,BREAKABLE) then return true end
    end
    return false
end
local function engaged(player,u)
    if not valid(u) or call(u,"is_unit")~=true or call(player,"can_attack",u)~=true then return false end
    local victim=call(u,"get_target")
    if same(victim,player) or call(victim,"is_party_member")==true then return true end
    local threat=call(player,"get_threat_situation",u)
    if type(threat)=="table" and (threat.is_tanking==true or (tonumber(threat.status) or 0)>0) then return true end
    -- Combat state alone can belong to another group. A selected, already
    -- engaged target remains an explicit player choice; scans need evidence.
    if call(u,"is_in_combat")~=true then return false end
    if same(call(player,"get_target"),u) then return true end
    return Mode.is_delve() and victim~=nil and call(victim,"is_dead")~=true
        and call(player,"can_attack",victim)==false or false
end
local function boss(u)
    if call(u,"is_boss")==true then return true end
    local wanted=Aura.guid(u)
    local frames={}
    if core.object_manager.get_boss_frames then
        local ok,value=pcall(core.object_manager.get_boss_frames)
        if ok and type(value)=="table" then frames=value end
    end
    for _,frame in pairs(frames) do if wanted and Aura.guid(frame)==wanted then return true end end
    return false
end
local function cast_remaining(u)
    local channel=call(u,"is_channelling_spell")==true
    local finish=tonumber(call(u,channel and "get_active_channel_cast_end_time" or "get_active_spell_cast_end_time"))
    if not finish or finish<=0 then return math.huge end
    -- Native cast deadlines and game_time share the millisecond clock.
    -- Numeric magnitude must never select a different time base.
    local now=core.game_time and core.game_time() or core.time()*1000
    return math.max(0,(finish-now)/1000)
end
local function cast_progress(u)
    local channel=call(u,"is_channelling_spell")==true
    local start=tonumber(call(u,channel and "get_active_channel_cast_start_time" or "get_active_spell_cast_start_time"))
    local finish=tonumber(call(u,channel and "get_active_channel_cast_end_time" or "get_active_spell_cast_end_time"))
    if not start or not finish or finish<=start then return nil end
    local now=core.game_time and core.game_time() or core.time()*1000
    return math.max(0,math.min(100,(now-start)/(finish-start)*100))
end
local function active_spell(u)
    local channel=call(u,"is_channelling_spell")==true
    return tonumber(call(u,channel and "get_active_channel_spell_id" or "get_active_spell_id")) or 0
end

function M.select_interrupt(player,current,range,late_percent)
    if core.time()>=next_failure_cleanup then
        next_failure_cleanup=core.time()+5
        for key,deadline in pairs(failed_until) do if deadline<=core.time() then failed_until[key]=nil end end
    end
    local best,best_score,best_remaining=nil,-math.huge,math.huge
    local function consider(u)
        if not engaged(player,u) or distance(player,u)>(range or 13) then return end
        if call(u,"is_casting_spell")~=true and call(u,"is_channelling_spell")~=true then return end
        if call(u,"is_active_spell_interruptable")~=true then return end
        local key=guid(u)..":"..tostring(active_spell(u))
        if (failed_until[key] or 0)>core.time() then return end
        local held=recent_party_interrupts[guid(u)]
        if held then
            if held>core.time() then return end
            recent_party_interrupts[guid(u)]=nil
        end
        if core.graphics and type(core.graphics.is_line_of_sight)=="function" then
            local ok,los=pcall(core.graphics.is_line_of_sight,player,u); if ok and los==false then return end
        end
        local remaining=cast_remaining(u)
        local victim=call(u,"get_active_spell_target")
        local dangerous=same(victim,player) or call(victim,"is_party_member")==true
            or call(u,"is_channelling_spell")==true or M.priority_interrupts[active_spell(u)]==true
        local progress=cast_progress(u)
        local threshold=dangerous and 20 or (tonumber(late_percent) or 65)
        if progress and progress<threshold or not progress and remaining>(dangerous and 1.8 or 1.5) then return end
        local score=math.max(0,40-math.min(40,remaining*12))
        if same(victim,player) then score=score+45
        elseif call(victim,"is_party_member")==true then score=score+35 end
        if same(u,current) then score=score+8 end
        if call(u,"is_channelling_spell")==true then score=score+12 end
        if M.priority_interrupts[active_spell(u)] then score=score+30 end
        if score>best_score or score==best_score and remaining<best_remaining then
            best,best_score,best_remaining=u,score,remaining
        end
    end
    consider(current)
    for _,u in pairs(Objects.get()) do if not same(u,current) then consider(u) end end
    if best then M.interrupt=string.format("Interrupting %s in %.1fs",call(best,"get_name") or "enemy",best_remaining) end
    return best
end

function M.on_spell_cast(data,player)
    if type(data)~="table" or not PARTY_INTERRUPTS[tonumber(data.spell_id)] then return end
    if same(data.caster,player) then return end
    local caster_guid=guid(data.caster)
    if not caster_guid then return end
    local party=false
    for _,entry in ipairs(Group.roster(player)) do
        if guid(entry.object)==caster_guid then party=true; break end
    end
    local target_guid=guid(data.target)
    if party and target_guid then recent_party_interrupts[target_guid]=core.time()+0.22 end
end

function M.mark_interrupt_failed(unit)
    if not unit then return end
    failed_until[guid(unit)..":"..tostring(active_spell(unit))]=core.time()+1.5
    M.interrupt="Interrupt failed; temporarily skipped"
end

function M.interruptible_count(player,range)
    local count,seen,nearest,nearest_range=0,{},nil,math.huge
    for _,u in pairs(Objects.get()) do
        local identity=guid(u)
        local unit_range=distance(player,u)
        if not seen[identity] and engaged(player,u) and not boss(u) and unit_range<=range
            and (call(u,"is_casting_spell")==true or call(u,"is_channelling_spell")==true)
            and call(u,"is_active_spell_interruptable")==true then
            seen[identity]=true; count=count+1
            if unit_range<nearest_range then nearest,nearest_range=u,unit_range end
        end
    end
    return count,nearest
end

function M.select_emergency_stop(player,current,range)
    local best,best_remaining=nil,math.huge
    local function consider(unit)
        if boss(unit) or not engaged(player,unit) or distance(player,unit)>(range or 10) then return end
        if call(unit,"is_casting_spell")~=true and call(unit,"is_channelling_spell")~=true then return end
        local victim=call(unit,"get_active_spell_target")
        local assigned=same(victim,player) or call(victim,"is_party_member")==true
        local priority=M.priority_interrupts[active_spell(unit)]==true
        -- Verified dangerous casts may be untargeted area mechanics. If the
        -- normal kick is unavailable, allow a safe non-boss crowd-control stop.
        if not assigned and not priority then return end
        local remaining=cast_remaining(unit)
        local progress=cast_progress(unit)
        local urgent=priority or call(unit,"is_channelling_spell")==true or remaining<=1.0 or progress and progress>=70
        if urgent and remaining<best_remaining then best,best_remaining=unit,remaining end
    end
    consider(current)
    for _,unit in pairs(Objects.get()) do if not same(unit,current) then consider(unit) end end
    return best,best_remaining
end

local function aura_field(a,...)
    for i=1,select("#",...) do local k=select(i,...); local ok,v=pcall(function() return a[k] end); if ok and v~=nil then return v end end
end
local function enrage_info(unit)
    for _,method in ipairs({"get_buffs","get_auras","get_all_buffs"}) do
        local list=call(unit,method)
        for _,a in pairs(type(list)=="table" and list or {}) do
            local kind=aura_field(a,"dispel_type","dispelType","type","dispel_name","dispelName")
            if Aura.is_current(a) then
                local enrage=type(kind)=="string" and kind:lower()=="enrage"
                    or enums and enums.buff_type and kind==enums.buff_type.ENRAGE
                if enrage then return true,DungeonPriorities.soothe[Aura.id(a)]==true end
            end
        end
    end
    return false,false
end
function M.enraged(unit) return enrage_info(unit) end
function M.select_enrage(player,current,range)
    local best,best_score=nil,-math.huge
    local seen={}
    local function consider(unit)
        local identity=guid(unit)
        if not identity or seen[identity] then return end
        seen[identity]=true
        if engaged(player,unit) and reachable(player,unit,range or 40) then
            local enraged,priority=enrage_info(unit)
            if enraged then
                local score=(priority and 100 or 0)+(same(unit,current) and 10 or 0)
                local victim=call(unit,"get_target")
                if victim and Group.role(victim)=="HEALER" then score=score+20 end
                if score>best_score then best,best_score=unit,score end
            end
        end
    end
    consider(current)
    for _,unit in pairs(Objects.get()) do
        consider(unit)
    end
    return best
end

function M.face_if_needed(player,target)
    if not valid(target) or core.time()-last_face<0.6 then return false end
    local facing=call(player,"is_facing",target)
    if facing~=false then return false end
    local point=call(target,"get_position"); if not point then return false end
    local ok,accepted=pcall(core.input.look_at_3d,point)
    if ok and accepted~=false then last_face=core.time(); M.utility="Facing combat target"; return true end
    return false
end
function M.ensure_facing(player,target,allow_turn)
    local facing=call(player,"is_facing",target)
    if facing~=false then return true end
    return allow_turn==true and M.face_if_needed(player,target) or false
end

function M.select_damage_target(player,current,range)
    local loose=Threat.select(player,current,range or 30,M.damage_blocked)
    if loose and valid(loose.object) and not M.damage_blocked(loose.object) then M.target_reason="Threat recovery"; return loose.object,loose end
    if core.time()<lock_until and valid(locked_target) and engaged(player,locked_target) and reachable(player,locked_target,40) and not M.damage_blocked(locked_target) then
        M.target_reason="Stable priority target"; return locked_target,nil
    end
    local current_ok=engaged(player,current) and reachable(player,current,40) and not M.damage_blocked(current)
    local best,best_score=current_ok and current or nil,current_ok and 10 or -math.huge
    local candidates={}
    for _,u in pairs(Objects.get()) do candidates[#candidates+1]=u end
    if core.object_manager.get_boss_frames then
        local ok,frames=pcall(core.object_manager.get_boss_frames)
        if ok and type(frames)=="table" then for _,u in pairs(frames) do candidates[#candidates+1]=u end end
    end
    for _,u in pairs(candidates) do
        if engaged(player,u) and reachable(player,u,40) and not M.damage_blocked(u) then
            local score=same(u,current) and 10 or 0
            local victim=call(u,"get_target")
            local threat=call(player,"get_threat_situation",u)
            if call(victim,"is_party_member")==true and not same(victim,player)
                and not (type(threat)=="table" and threat.is_tanking==true) then score=score+50 end
            if call(u,"is_casting_spell")==true or call(u,"is_channelling_spell")==true then score=score+20 end
            if boss(u) then score=score+(Mode.is_delve() and 35 or 18) end
            local classification=tonumber(call(u,"get_classification")) or 0
            if Mode.is_delve() and classification>=1 then score=score+12 end
            local route=Settings.route_context
            if route and route.guids and route.guids[guid(u)] then score=score+15 end
            score=score-math.min(15,distance(player,u)*0.2)
            if score>best_score then best,best_score=u,score end
        end
    end
    M.target_reason=best and (same(best,current) and "Current target" or "Priority engaged enemy") or "No target"
    if best and not same(best,current) then locked_target,lock_until=best,core.time()+1.25 end
    return best,loose
end

function M.select_rebirth(player,max_range)
    local best,best_score=nil,-math.huge
    local seen={}
    local function consider(value)
        local entry=type(value)=="table" and value.object and value or nil
        if entry and entry.is_online==false then return end
        local unit=entry and entry.object or value
        if not unit or call(unit,"is_valid")~=true or call(unit,"is_dead")~=true then return end
        local key=guid(unit); if seen[key] then return end; seen[key]=true
        if not reachable(player,unit,max_range or 40) then return end
        local role=tostring(entry and entry.role or Group.role(unit) or ""):lower()
        local score=role:find("heal",1,true) and 30 or role:find("tank",1,true) and 20 or 10
        if call(unit,"is_party_member")==true then score=score+5 end
        if score>best_score then best,best_score=unit,score end
    end
    for _,entry in ipairs(Group.roster()) do consider(entry) end
    return best
end

local function party_units(player)
    local result={}
    for _,entry in ipairs(Group.roster(player)) do
        if entry.is_online~=false and valid(entry.object) then result[#result+1]=entry.object end
    end
    return result
end
local function aura_kind(a)
    local kind=aura_field(a,"dispel_type","dispelType","type","dispel_name","dispelName")
    return type(kind)=="string" and kind:lower() or kind
end
function M.select_dispel(player)
    local best,best_score=nil,-math.huge
    for _,unit in ipairs(party_units(player)) do
        if reachable(player,unit,40) then
        for _,method in ipairs({"get_debuffs","get_auras"}) do
            local list=call(unit,method)
            for _,a in pairs(type(list)=="table" and list or {}) do
                local kind=aura_kind(a)
                if Aura.is_current(a) and (kind=="poison" or kind=="curse"
                    or enums.buff_type and (kind==enums.buff_type.POISON or kind==enums.buff_type.CURSE)) then
                    local health,maximum=tonumber(call(unit,"get_health")),tonumber(call(unit,"get_max_health"))
                    local pct=health and maximum and maximum>0 and health/maximum*100 or 100
                    local score=(DungeonPriorities.dispel[Aura.id(a)] and 100 or 0)+(100-pct)
                    if same(unit,player) then score=score+2 end
                    if score>best_score then best,best_score=unit,score end
                end
            end
        end
        end
    end
    return best
end
function M.lowest_ally(player,max_range)
    local best,best_pct=nil,101
    for _,unit in ipairs(party_units(player)) do
        local health,maximum=tonumber(call(unit,"get_health")),tonumber(call(unit,"get_max_health"))
        local pct=health and maximum and maximum>0 and health/maximum*100 or nil
        if pct and pct<best_pct and reachable(player,unit,max_range or 40) then best,best_pct=unit,pct end
    end
    return best,best_pct
end

function M.engaged(player,unit) return engaged(player,unit) end
function M.is_boss(unit) return boss(unit) end
function M.spell_school(unit)
    local value=tonumber(call(unit,"get_active_spell_school"))
    if not value and core.spell_book.get_spell_school then
        local ok,v=pcall(core.spell_book.get_spell_school,active_spell(unit)); if ok then value=tonumber(v) end
    end
    if value==1 then return "physical" elseif value and value>1 then return "magic" end
    return "unknown"
end
function M.reset() Objects.reset(); failed_until={}; recent_party_interrupts={}; next_failure_cleanup=0; last_face=-math.huge; locked_target,lock_until=nil,-math.huge; M.status="Ready"; M.interrupt="Watching casts"; M.utility="Ready"; M.target_reason="Current target" end
return M
