local M={active=false,inside=false,status="Idle",points={},hold_until=0,next_scan=0,
    escape_position=nil,escape_hold_until=0,escape_blocked=false}
local Mechanics=require("prot_mechanics")
local color=require("common/color")
local vec3=require("common/geometry/vector_3")
local guides=require("prot_boss_guides")
local Host=require("prot_host")
local evade
-- World-space boss rings must remain readable without covering the player or
-- floor mechanics. Alpha is deliberately low; geometry and color carry the
-- warning while the character model stays visible through the aura.
local red=color.new(245,48,48,38)
local green=color.new(55,225,105,30)

local function call(object,method,...)
    if not object or type(object[method])~="function" then return nil end
    local ok,value=pcall(object[method],object,...);if ok then return value end
end
local function provider_call(provider,method)
    local fn=provider and provider[method];if type(fn)~="function" then return false,nil end
    local ok,value=pcall(fn,provider);if ok then return true,value end
    return pcall(fn)
end
local function load_evade()
    if evade then return evade end
    local ok,value=pcall(require,"common/utility/evade_helper")
    if ok then evade=value end
    return evade
end
local function remaining(bar)
    if bar.paused==true or bar.is_paused==true or bar.stopped==true or bar.active==false then return nil end
    local value=tonumber(bar.remaining or bar.time_left or bar.timeLeft)
    if not value and tonumber(bar.ends_at or bar.end_time) then
        value=tonumber(bar.ends_at or bar.end_time)-core.time()
    end
    return value
end
local function warning_window()
    if not core.addons then return false,nil,nil end
    local best_name,best_time
    for _,name in ipairs({"bigwigs","exboss","dbm","deadlybossmods"}) do
        local provider=core.addons[name]
        if provider and type(provider.is_loaded)=="function" and type(provider.get_bars)=="function" then
            local loaded_ok,loaded=provider_call(provider,"is_loaded")
            local bars_ok,bars=provider_call(provider,"get_bars")
            if loaded_ok and loaded and bars_ok and type(bars)=="table" then
                for _,bar in pairs(bars) do
                    local time=remaining(bar)
                    local spell_id=tonumber(bar.spell_id or bar.spellId or bar.id)
                    local score=Mechanics.classify(bar.text,spell_id)
                    local kind=string.lower(tostring(bar.warning_type or bar.warningType or bar.role or bar.action or ""))
                    local dangerous=score>0 or bar.is_tank==true or bar.is_defensive==true
                        or kind=="tank" or kind=="defensive" or kind=="tankbuster"
                    if dangerous and time and time>=0 and time<=4.5
                        and (not best_time or time<best_time) then
                        best_name,best_time=tostring(bar.text or "Incoming danger"),time
                    end
                end
            end
        end
    end
    return best_time~=nil,best_name,best_time
end
local function safe(point)
    local helper=load_evade()
    local value=call(helper,"is_point_safe",point)
    if type(value)=="boolean" then return value end
    return nil
end
function M.reset(reason)
    M.active,M.inside,M.points,M.hold_until,M.next_scan=false,false,{},0,0
    M.escape_position,M.escape_hold_until=nil,0
    M.escape_blocked=false
    M.status=reason or "Idle"
end
function M.update(player,boss_guides_enabled)
    guides.update(player,boss_guides_enabled)
    if not player or call(player,"is_valid")~=true or call(player,"is_dead")==true
        or call(player,"is_in_combat")~=true then M.reset("Waiting for PvE combat");return end
    local now=core.time();if now<M.next_scan then return end;M.next_scan=now+0.12
    local origin=call(player,"get_position");if not origin then M.reset("Position unavailable");return end
    local warned,name,time=warning_window()
    if warned then M.hold_until=math.max(M.hold_until,now+math.max(1,time+1)) end
    local points,unsafe={},false
    local center_safe=safe(origin)
    if center_safe~=nil then points[#points+1]={position=origin,safe=center_safe,player=true};unsafe=not center_safe end
    for _,radius in ipairs({2.5,5,7.5}) do
        for index=0,7 do
            local angle=index*math.pi/4
            local point=vec3.new(origin.x+math.cos(angle)*radius,origin.y+math.sin(angle)*radius,origin.z)
            local point_safe=safe(point)
            if point_safe~=nil then
                points[#points+1]={position=point,safe=point_safe}
                if not point_safe then unsafe=true end
            end
        end
    end
    M.points,M.inside=points,center_safe==false
    local previous_escape=M.escape_position
    M.escape_position=nil;M.escape_blocked=false
    if M.inside then
        local function clear_corridor(destination)
            local seen_safe=false
            for _,fraction in ipairs({0.25,0.5,0.75}) do
                local probe=vec3.new(origin.x+(destination.x-origin.x)*fraction,
                    origin.y+(destination.y-origin.y)*fraction,
                    origin.z+(destination.z-origin.z)*fraction)
                local probe_safe=safe(probe)
                if probe_safe==true then seen_safe=true
                elseif probe_safe==false and seen_safe then return false end
            end
            return true
        end
        if previous_escape and now<M.escape_hold_until and safe(previous_escape)==true
            and clear_corridor(previous_escape) then
            M.escape_position=previous_escape
        end
        -- Prefer a safe sample with the most clearance from every confirmed
        -- unsafe sample. Distance is a smaller cost so a slightly longer move
        -- wins when it avoids threading between two hazards.
        local best_score=-math.huge
        if not M.escape_position then for _,candidate in ipairs(points) do if candidate.player~=true and candidate.safe==true then
            -- A safe endpoint is insufficient when the straight route crosses a
            -- second hazard. Allow the initial exit from the current danger,
            -- then reject any path that becomes unsafe again after reaching safety.
            local path_valid=clear_corridor(candidate.position)
            local nearest_unsafe=math.huge
            for _,hazard in ipairs(points) do if hazard.safe==false then
                local dx=candidate.position.x-hazard.position.x
                local dy=candidate.position.y-hazard.position.y
                nearest_unsafe=math.min(nearest_unsafe,math.sqrt(dx*dx+dy*dy))
            end end
            local dx,dy=candidate.position.x-origin.x,candidate.position.y-origin.y
            local travel=math.sqrt(dx*dx+dy*dy)
            local score=(nearest_unsafe<math.huge and nearest_unsafe or 12)*2-travel*0.35
            if path_valid and score>best_score then best_score=score;M.escape_position=candidate.position end
        end end end
        if M.escape_position~=previous_escape then M.escape_hold_until=now+0.65 end
        M.escape_blocked=M.escape_position==nil
    end
    M.active=unsafe or warned or now<M.hold_until
    if M.inside then M.status=M.escape_blocked and "DANGER • no verified clear path" or "DANGER • move out"
    elseif M.active then M.status=(name and ("Safe • "..name.." in "..string.format("%.1fs",time)) or "Safe • nearby hazard")
    else M.status="No confirmed danger zone" end
end
function M.render()
    local player=Host.manager("get_local_player")
    guides.render(player)
    if not M.active or not core.graphics or type(core.graphics.circle_3d)~="function" then return end
    local hazard_rings=0
    for _,point in ipairs(M.points) do
        if point.player then
            if type(core.graphics.text_3d)=="function" then
                local label=vec3.new(point.position.x,point.position.y,point.position.z+2.8)
                Host.static(core and core.graphics,"text_3d",M.inside and "DANGER • FOLLOW LINE" or "SAFE",label,14,
                    M.inside and red or green,true)
            end
        elseif point.safe==false and hazard_rings<6 then
            hazard_rings=hazard_rings+1
            Host.static(core and core.graphics,"circle_3d",point.position,1.0,red,16,0.06)
        end
    end
    if M.inside and M.escape_position and type(core.graphics.line_3d)=="function" then
        local origin=call(player,"get_position")
        if origin then Host.static(core and core.graphics,"line_3d",origin,M.escape_position,green,3,0,false) end
    end
end
function M.on_event(event)
    guides.on_event(event)
    if event=="ENCOUNTER_END" or event=="PLAYER_DEAD" or event=="PLAYER_LEAVING_WORLD" then
        M.reset("Encounter ended")
    end
end
function M.guide_status() return guides.status end
return M
