-- Bounded escape from registered Evade hazards; not a dungeon route or soak solver.
local U,C,S=require("rs_units"),require("rs_settings"),require("rs_spells")
local M={}
local ev,movement,vec,flags
local active,started,next_scan=false,0,0
local destination
local last_error=-math.huge
local function api(obj,key,...)
    if not obj or type(obj[key])~="function" then return nil,"missing "..key end
    local ok,value=pcall(obj[key],obj,...)
    if not ok then return nil,key..": "..tostring(value) end
    return value,nil
end
local function fail(reason)
    M.stop(reason)
    return false
end
local function navigation_busy()
    local root=type(_G)=="table" and rawget(_G,"ArthasNav") or nil
    local client=type(root)=="table" and root.client or nil
    if type(client)~="table" or type(client.is_busy)~="function" then return false end
    local ok,busy=pcall(client.is_busy,client)
    return ok and busy==true
end
local function load_dependencies()
    if ev then return true end
    local ok,result=pcall(function()
        return {require("common/utility/evade_helper"),require("common/utility/simple_movement"),
            require("common/geometry/vector_3"),
            require("common/enums").collision_flags.Collision}
    end)
    if not ok or not result[1] or not result[2] or not result[3] or not result[4] then return false end
    -- Core 2.075 does not expose table.unpack.
    ev,movement,vec,flags=result[1],result[2],result[3],result[4]
    return true
end
function M.stop(reason)
    if active and movement then pcall(function()movement:stop()end) end
    active=false;destination=nil;C.evading=false
    C.evade_status=reason or "Idle"
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function terrain(p,z)
    local ok,h=pcall(core.get_height_for_position,vec.new(p.x,p.y,z+2))
    if not ok then return nil,"terrain height: "..tostring(h) end
    if type(h)~="number" or h~=h or math.abs(h-z)>1.5 then return nil end
    return vec.new(p.x,p.y,h)
end
local function route_ok(origin,target,objects,me)
    local length=distance(origin,target)
    local clear=false
    local previous=origin
    for i=1,math.ceil(length/0.75) do
        local t=math.min(1,i*0.75/length)
        local p=terrain(vec.new(origin.x+(target.x-origin.x)*t,origin.y+(target.y-origin.y)*t,origin.z),previous.z)
        if not p then return false end
        local trace_ok,clear_path=pcall(core.graphics.trace_line,vec.new(previous.x,previous.y,previous.z+0.8),vec.new(p.x,p.y,p.z+0.8),flags)
        if not trace_ok or clear_path~=true then return false end
        local safe=api(ev,"is_point_safe",p)
        if type(safe)~="boolean" or (clear and not safe) then return false end
        if safe then
            if api(ev,"is_point_safe_full",p,2)~=true then return false end
            clear=true
        end
        for _,u in pairs(objects) do
            if u~=me and U.valid(u) and U.call(u,"is_enemy_with",me)==true
                and U.call(u,"is_in_combat")~=true then
                local pos=U.call(u,"get_position")
                if pos and distance(p,pos)<12 then return false end
            end
        end
        previous=p
    end
    return clear and api(ev,"is_point_safe_full",target,2)==true
end
local function choose(me,origin,objects)
    local best,best_score
    for radius=2,8,2 do
        for n=0,15 do
            local angle=n*math.pi/8
            local p=terrain(vec.new(origin.x+radius*math.cos(angle),origin.y+radius*math.sin(angle),origin.z),origin.z)
            if p and api(ev,"is_point_safe_full",p,2)==true then
                local crowd,near_party=false,false
                for _,u in pairs(objects) do
                    if u~=me and U.valid(u) and U.call(u,"is_party_member")==true then
                        local pos=U.call(u,"get_position")
                        if pos then
                            local d=distance(p,pos)
                            crowd=crowd or d<3;near_party=near_party or d<35
                        end
                    end
                end
                if not crowd and near_party and route_ok(origin,p,objects,me) then
                    local party_distance=math.huge
                    for _,u in pairs(objects) do
                        if u~=me and U.valid(u) and U.call(u,"is_party_member")==true then
                            local pos=U.call(u,"get_position")
                            if pos then party_distance=math.min(party_distance,distance(p,pos)) end
                        end
                    end
                    -- Prefer the shortest safe exit, then the point that keeps healing range on the party.
                    local score=radius*10+math.min(party_distance,35)
                    if not best_score or score<best_score then best,best_score=p,score end
                end
            end
        end
    end
    return best
end
local function tick(me)
    if not C.get("avoidance") then M.stop("Off");return end
    -- Never initialize the host movement helper outside Mythic+. Loading the
    -- helper itself can retain shared movement state even if no destination is requested.
    if not require("rs_context").get().mythic_plus then M.stop("Movement disabled outside Mythic+");return end
    if not load_dependencies() then M.stop("Evade/movement API unavailable");return end
    if not U.valid(me)
        or U.call(me,"is_mounted") or U.call(me,"is_flying") or U.call(me,"is_in_combat")~=true then M.stop("Waiting for M+ combat");return end
    if core.character and core.character.is_swimming and core.character.is_swimming() then M.stop("Swimming; manual movement needed");return end
    if navigation_busy() then M.stop("MasterArthasNav owns movement");return end
    local origin=U.call(me,"get_position")
    if not origin then M.stop("Position unavailable");return end
    local safe,safe_err=api(ev,"is_point_safe",origin)
    if safe_err then error(safe_err) end
    if safe~=false then M.stop(safe==true and "No registered hazard here" or "Hazard data unavailable");return end
    local now=core.time()
    local objects=U.objects()
    if active then
        if now-started>2.5 or not route_ok(origin,destination,objects,me) then
            M.stop("Escape expired or path changed");next_scan=now+0.5;return
        end
        local processed,process_err=api(movement,"process")
        if process_err then error(process_err) end
        if processed==false then M.stop("Movement processor stopped");return end
        C.evading=true;return
    end
    local helper_moving,moving_err=api(movement,"is_moving")
    if moving_err then error(moving_err) end
    if U.call(me,"is_moving") or helper_moving then C.evade_status="Hazard; existing movement has priority";return end
    if now<next_scan then return end
    next_scan=now+0.3
    destination=choose(me,origin,objects)
    if not destination then C.evade_status="Hazard; no checked escape within 8 yards";return end
    local accepted,move_err=api(movement,"move_to_position",destination)
    if move_err then error(move_err) end
    if accepted~=true then destination=nil;C.evade_status="Movement request rejected";return end
    active=true;started=now;C.evading=true;C.evade_status="Escaping registered hazard"
    -- Survival movement may interrupt a heal as well as damage.
    if U.call(me,"is_casting_spell") or U.call(me,"is_channelling_spell") then
        S.cancel(me,"hazard escape movement")
    end
    local _,process_err=api(movement,"process")
    if process_err then error(process_err) end
end
function M.run(me)
    local ok,err=pcall(tick,me)
    if not ok then
        local short=tostring(err):gsub("^.-:%d+:%s*","")
        M.stop("Avoidance stopped: "..short)
        if core.time()-last_error>=10 then
            pcall(core.log_warning,"[Resto M+ movement] "..tostring(err))
            last_error=core.time()
        end
    end
end
return M
