-- Use Arthas/Ameisen exclusively; never select Sentinel or standalone NavLib.
local M = {}
local RuntimeApi=require("leveler_runtime_api")
local repair_policy=require("navigation_repair").new()
local initialized
local mesh_client,provider_log,last_provider,mesh_provider,health_next
local detour_planner,detour_epoch,detour_active= nil,0,false
local function ameisen_native()
    local exported=rawget(_G,"ArthasNav") or rawget(_G,"AmeisenNav")
    if type(exported)~='table' then return nil end
    local improved=rawget(_G,"ArthasNavEnhancements")
    if improved then
        if type(improved.get_client)~='function' then return nil end
        local ok,client=pcall(improved.get_client,'auto_leveler')
        -- Wait for the ownership proxy; falling back here exposes our job to
        -- another plugin's Stop while Arthas initializes its shared client.
        return ok and client or nil
    end
    return exported.client
end
function M.owns_ground_windows() return ameisen_native()~=nil end
local direct_clear,direct_floor
local recovery_client,recovery_driver
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function ground_distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
end
local function direct_leg(here,goal)
    if not direct_clear or not direct_floor then return nil,"geometry_unavailable" end
    local dx,dy=goal.x-here.x,goal.y-here.y;local remaining=math.sqrt(dx*dx+dy*dy)
    if remaining<=3 and direct_clear(here,goal) then return {x=goal.x,y=goal.y,z=goal.z},"final" end
    local heading
    if dx==0 then heading=dy>=0 and math.pi/2 or -math.pi/2
    else heading=math.atan(dy/dx);if dx<0 then heading=heading+(dy>=0 and math.pi or -math.pi) end end
    local best,best_score
    -- Probe the local surface first. A wide vertical trace can hit a roof,
    -- tree or bridge above the player and used to reject every usable leg.
    -- Shorter probes and a full heading fan let us leave tight or sloped spots
    -- without committing the movement controller to a long direct run.
    for _,step in ipairs({math.min(12,remaining),math.min(8,remaining),math.min(4,remaining),math.min(2,remaining)}) do
        for _,offset in ipairs({0,.35,-.35,.7,-.7,1.05,-1.05,1.4,-1.4}) do
            local candidate={x=here.x+math.cos(heading+offset)*step,y=here.y+math.sin(heading+offset)*step,z=here.z}
            local grounded=direct_floor(candidate,false) or direct_floor(candidate,true)
            local climb=grounded and math.abs(grounded.z-here.z) or math.huge
            -- Never choose an escape point that increases planar distance to
            -- the route goal. Stateless backward probes can alternate on each
            -- dispatch and create the observed A-B-A running loop.
            local progress=grounded and (ground_distance(here,goal)-ground_distance(grounded,goal)) or -math.huge
            if grounded and progress>=math.max(.25,step*.02)
                and climb<=math.max(4.5,step*.75) and direct_clear(here,grounded) then
                local score=distance(grounded,goal)+math.abs(offset)*2+(12-step)*.15
                if not best_score or score<best_score then best,best_score=grounded,score end
            end
        end
        if best then break end
    end
    return best,best and "segment" or "no_clear_segment"
end
-- Keep ordinary ground navigation bounded as well as the emergency direct
-- driver. The movement controller retains the final goal and requests the
-- next measured leg only after the current one completes.
function M.next_ground_leg(here,goal)
    return direct_leg(here,goal)
end
local function mesh()
    local ameisen=ameisen_native()
    if mesh_client and ((ameisen and mesh_provider~="ameisen_nav") or (mesh_provider=="ameisen_nav" and mesh_client.native~=ameisen)) then
        mesh_client:stop();mesh_client=nil;last_provider=nil
    end
    if not mesh_client then
        local native,external
        local native_provider
        if ameisen then
            native=ameisen;external=true;mesh_provider="ameisen_nav"
            native_provider=ameisen_native
        end
        if native and type(native.move_to)=="function" and type(native.stop)=="function" and type(native.is_server_available)=="function" then
            mesh_client=require("navlib_adapter").new(native,nil,{time=core.time,
                external_updates=external,
                path_query=function(start,goal,cb) require("arthas_height_query").path(core,start,goal,cb) end,
                height_query=function(p,cb) require("arthas_height_query").query(core,p,cb) end,
                floor_probe=function(p) return M.measured_height and M.measured_height(p) end,
                map=function() return core.get_map_id and core.get_map_id() or "unknown" end,
                native_provider=external and native_provider or nil,
                -- A capability probe can create this adapter before initialize
                -- installs the logger. Resolve it at delivery time.
                log=function(event,fields) if provider_log then provider_log(event,fields) end end,
                position=function() local p=RuntimeApi.player();return p and p:is_valid() and p:get_position() or nil end})
        end
    end
    if mesh_client and not mesh_client:is_server_available() and mesh_client.native.health_check and core.time()>=(health_next or 0) then
        health_next=core.time()+10
        pcall(function() mesh_client.native:health_check(function(ok)
            if provider_log then provider_log("navigation_health_check",{provider=mesh_provider,success=ok==true}) end
        end) end)
    end
    return mesh_client
end
local combat_movement=false
function M.initialize(log)
    provider_log=log
    if initialized then return mesh() end
    if not core.graphics or type(core.graphics.native_intersect)~="function"
        or type(core.graphics.trace_line)~="function" then
        -- Sentinel is the required movement provider and does not depend on
        -- the local collision API. Keep full-destination routing available
        -- when the client build cannot expose optional short-leg geometry.
        initialized=true
        if log then
            log("navigation_geometry_unavailable",{fallback="external_full_route"})
            log("navigation_backend",{provider=ameisen_native() and "arthas_nav" or "arthas_required",arthas_nav_connected=ameisen_native()~=nil})
        end
        return mesh()
    end
    local vec=require("common/geometry/vector_3")
    local enums=require("common/enums")
    local driver=require("common/utility/simple_movement")
    local flags=enums.collision_flags
    if not flags or not driver then return nil end
    local mask=flags.DoodadCollision+flags.WmoCollision+flags.Terrain
    local function position() local p=RuntimeApi.player();return p and p:is_valid() and p:get_position() or nil end
    local function floor(p,wide)
        local above=wide and 40 or 2;local below=wide and 40 or 3
        local start=vec.new(p.x,p.y,p.z+above);local finish=vec.new(p.x,p.y,p.z-below)
        local hit,point=core.graphics.native_intersect(finish,start,above+below,mask)
        if type(hit)=="table" then point=hit[2];hit=hit[1] end
        if hit~=true or not point or type(point.z)~="number" or point.z~=point.z then return nil end
        return {x=p.x,y=p.y,z=point.z}
    end
    local function clear(a,b)
        local dx,dy=b.x-a.x,b.y-a.y;local length=math.sqrt(dx*dx+dy*dy)
        local p=RuntimeApi.player()
        local mounted=p and p:is_valid() and p:is_mounted()
        local width=mounted and 1 or 0.45
        local ox,oy=0,0;if length>0 then ox,oy=-dy/length*width,dx/length*width end
        for _,side in ipairs({-1,0,1}) do
            for _,height in ipairs(mounted and {0.3,1.5,3} or {0.3,1.5}) do
                if core.graphics.trace_line(vec.new(a.x+ox*side,a.y+oy*side,a.z+height),
                    vec.new(b.x+ox*side,b.y+oy*side,b.z+height),mask)~=true then return false end
            end
        end
        return true
    end
    direct_clear=clear;direct_floor=floor
    M.measured_height=function(p) local terrain=floor(p) or floor(p,true);return terrain and terrain.z end
    M.flight_clear=function(a,b)
        local dx,dy=b.x-a.x,b.y-a.y
        local span=math.sqrt(dx*dx+dy*dy)
        local ox,oy=1,0
        if span>0 then ox,oy=-dy/span,dx/span end
        for _,side in ipairs({-2,0,2}) do
            for _,height in ipairs({0,2}) do
                if core.graphics.trace_line(vec.new(a.x+ox*side,a.y+oy*side,a.z+height),vec.new(b.x+ox*side,b.y+oy*side,b.z+height),mask)~=true then return false end
            end
        end
        return true
    end
    local function flight_floor(p)
        local measured=floor(p) or floor(p,true)
        if measured then return measured end
        local h,status=require("arthas_height_query").sample(core,p)
        if h then return {x=p.x,y=p.y,z=h} end
        return nil,status
    end
    local function landing_pad(center)
        local highest=center.z;local missing=false;local pending=false
        for _,offset in ipairs({{-2,0},{2,0},{0,-2},{0,2},{-2,-2},{-2,2},{2,-2},{2,2}}) do
            local sample,status=flight_floor({x=center.x+offset[1],y=center.y+offset[2],z=center.z})
            if not sample or math.abs(sample.z-center.z)>3 then missing=true;pending=pending or status=="pending"
            else highest=math.max(highest,sample.z) end
        end
        if missing then return nil,pending and "corridor_pending" or "corridor_unavailable" end
        return {x=center.x,y=center.y,z=highest+1}
    end
    M.flight_landing=function(p)
        local bottom=vec.new(p.x,p.y,p.z-500);local top=vec.new(p.x,p.y,p.z+2)
        local hit,point=core.graphics.native_intersect(bottom,top,502,mask)
        if type(hit)=="table" then point=hit[2];hit=hit[1] end
        if hit~=true or not point or type(point.z)~="number" then return nil end
        local landing=landing_pad({x=p.x,y=p.y,z=point.z})
        if not landing then return nil end
        if not M.flight_clear(p,landing) then return nil end
        return landing
    end
    local rejected_corridors={}
    local verified_log_at={}
    M.flight_corridor=function(start,goal)
        local now=core.time and core.time() or 0
        local cache_key=table.concat({math.floor(start.x/3),math.floor(start.y/3),math.floor(start.z/3),math.floor(goal.x/3),math.floor(goal.y/3),math.floor(goal.z/3)},":")
        local cached=rejected_corridors[cache_key]
        if cached and now<cached.until_time then return nil,cached.reason end
        local function reject(reason,fields)
            local pending=reason=="corridor_pending"
            rejected_corridors[cache_key]={until_time=now+(pending and .25 or 3),reason=reason}
            local count=0;for _ in pairs(rejected_corridors)do count=count+1 end
            if count>128 then for key,row in pairs(rejected_corridors)do if row.until_time<=now then rejected_corridors[key]=nil end end end
            if not pending and provider_log then provider_log("flight_corridor_rejected",fields) end
            return nil,reason
        end
        local player=RuntimeApi.player()
        local airborne=player and player:is_valid() and player:is_flying()
        local current=floor(start) or floor(start,true)
        -- Measure departure terrain without requiring a descent corridor.
        if not current then
            local hit,point=core.graphics.native_intersect(vec.new(start.x,start.y,start.z-500),vec.new(start.x,start.y,start.z+2),502,mask)
            if type(hit)=="table" then point=hit[2];hit=hit[1] end
            if hit==true and point and type(point.z)=="number" then current={x=start.x,y=start.y,z=point.z} end
        end
        if airborne then current={x=start.x,y=start.y,z=start.z} end
        local destination,destination_status=flight_floor(goal)
        if not current or not destination or math.abs(destination.z-goal.z)>4 then
            return reject(not destination and destination_status=="pending" and "corridor_pending" or "corridor_unavailable",{reason=not current and "departure_floor_missing" or not destination and "destination_floor_missing" or "destination_layer_mismatch",goal_z=goal.z,measured_z=destination and destination.z})
        end
        local dx,dy=goal.x-start.x,goal.y-start.y;local span=math.sqrt(dx*dx+dy*dy)
        local landing,landing_reason=landing_pad({x=goal.x,y=goal.y,z=destination.z})
        if not landing and landing_reason~="corridor_pending" then
            landing,landing_reason=require('landing_search').find(destination,flight_floor,landing_pad)
            if landing and provider_log then provider_log("flight_landing_alternative",{goal_x=goal.x,goal_y=goal.y,x=landing.x,y=landing.y,z=landing.z}) end
        end
        if not landing then
            return reject(landing_reason,{reason="landing_footprint_unavailable"})
        end
        if span<=8 or span>12800 then return nil end
        -- Player coordinates are at ground contact. Clearance rays offset to
        -- either side can hit the slope under the feet before takeoff begins.
        -- Check the center launch rise, then inspect the airborne corridor.
        local launch={x=start.x,y=start.y,z=airborne and start.z or math.max(start.z,current.z)+2.5}
        if not airborne and core.graphics.trace_line(vec.new(start.x,start.y,start.z+.3),vec.new(launch.x,launch.y,launch.z),mask)~=true then
            if provider_log then provider_log("flight_corridor_rejected",{reason="launch_clearance_blocked",distance=span}) end
            return nil
        end
        local rejected={takeoff=0,cruise=0,landing=0}
        -- Try higher measured corridors when the lowest one intersects trees/buildings.
        -- Segment long trips so obstacle checks cover each leg and progress is observable.
        for _,clearance in ipairs(span<75 and {12,30,60,100} or {30,60,100,150,250,400}) do
            local altitude=math.max(start.z,destination.z)+clearance
            local takeoff={x=start.x,y=start.y,z=altitude}
            -- Prefer the direct corridor. If a building/tree blocks it, try
            -- collision-checked doglegs on both sides before climbing higher.
            for _,offset in ipairs({0,40,-40,80,-80}) do
                local path={takeoff};local previous=takeoff
                local valid=M.flight_clear(launch,takeoff)
                if not valid then rejected.takeoff=rejected.takeoff+1 end
                local legs=math.max(offset==0 and 1 or 2,math.ceil(span/200))
                local ox,oy=-dy/span,dx/span
                for i=1,legs do
                    local ratio=i/legs
                    local lateral=offset*math.sin(math.pi*ratio)
                    local point={x=start.x+dx*ratio+ox*lateral,y=start.y+dy*ratio+oy*lateral,z=altitude}
                    if valid and not M.flight_clear(previous,point) then valid=false;rejected.cruise=rejected.cruise+1 end
                    path[#path+1]=point;previous=point
                end
                if valid then
                    if M.flight_clear(previous,landing) then
                        path[#path+1]=landing
                        if provider_log and now>=(verified_log_at[cache_key] or 0) then
                            verified_log_at[cache_key]=now+10
                            local count=0;for _ in pairs(verified_log_at)do count=count+1 end
                            if count>128 then for key,until_time in pairs(verified_log_at)do if until_time<=now then verified_log_at[key]=nil end end end
                            provider_log("flight_corridor_verified",{distance=span,clearance=clearance,points=#path})
                        end
                        return path
                    end
                    rejected.landing=rejected.landing+1
                end
            end
        end
        return reject("corridor_unavailable",{reason="collision_probes_blocked",distance=span,takeoff=rejected.takeoff,cruise=rejected.cruise,landing=rejected.landing})
    end
    if driver.set_use_look_at then driver:set_use_look_at(true) end
    driver:set_smoothing_enabled(false);driver:set_final_threshold(0.8)
    if driver.set_flying_enabled then driver:set_flying_enabled(false) end
    recovery_driver=driver
    -- Sentinel remains the primary world router. This bounded graph is used
    -- only when Sentinel cannot produce a path; every two-yard edge is checked
    -- against the live floor and collision geometry before movement begins.
    recovery_client=require("ground_mesh").new({
        position=position,floor=floor,destination_floor=function(p) return floor(p) or floor(p,true) end,
        clear=clear,map=core.get_map_id,instance=core.get_instance_id,time=core.time,log=log,
        approach_clear=function(a,b)
            return core.graphics.trace_line(vec.new(a.x,a.y,a.z+1.5),vec.new(b.x,b.y,b.z+1.5),mask)==true
        end,
        stop=function() if driver.clear_navigation then driver:clear_navigation() end end,
        walk=function(p)
            local current=position();local terrain=floor(current)
            local offset=terrain and math.max(-2,math.min(2,current.z-terrain.z)) or 0
            if driver.move_to_position then return driver:move_to_position(vec.new(p.x,p.y,p.z+offset)) end
        end,
        process=function() if driver.process then driver:process() end end,
        paused=function()
            local p=RuntimeApi.player()
            return not p or not p:is_valid() or p:is_in_combat() and not combat_movement
                or p:is_casting_spell() or p:is_channelling_spell()
        end})
    initialized=true
    if log then log("navigation_backend",{provider=ameisen_native() and "arthas_nav" or "arthas_required",arthas_nav_connected=ameisen_native()~=nil}) end
    return mesh()

end
function M.tick()
    if detour_planner then detour_planner:tick() end
    if mesh_client and mesh_client.job then mesh_client:update()
    end
    if recovery_client and recovery_client.job and recovery_client.update then recovery_client:update() end
    mesh()
end
function M.is_planning()
    if recovery_client and recovery_client.job and recovery_client.job.phase=="planning" then return true end
    if mesh_client and mesh_client.job then return mesh_client:is_planning() end
    return false
end
function M.provider_info(filter)
    local found={}
    for name,value in pairs(_G) do
        local lower=type(name)=="string" and name:lower() or ""
        local farmer=lower:find("farmer",1,true) or lower:find("mf_",1,true) or lower:find("master",1,true)
        local navigation=lower:find("lion",1,true) or lower:find("sentinel",1,true) or lower:find("navlib",1,true) or lower:find("ameisen",1,true)
        if (filter=="farmer" and farmer) or (filter~="farmer" and navigation) then
            local fields={}
            if type(value)=="table" then
                for key,entry in pairs(value) do
                    if type(key)=="string" and (type(entry)=="function" or type(entry)=="table") then fields[#fields+1]=key..":"..type(entry) end
                    if type(key)=="string" and type(entry)=="table" and (key=="navmesh" or key=="remote") then
                        local methods={}
                        for method,fn in pairs(entry) do
                            if type(method)=="string" and type(fn)=="function" then methods[#methods+1]=method end
                        end
                        table.sort(methods);fields[#fields+1]=key.."{"..table.concat(methods,",").."}"
                    end
                end
                table.sort(fields)
            end
            found[#found+1]=name.."["..table.concat(fields,",").."]"
        end
    end
    table.sort(found);return table.concat(found,";")
end
function M.diagnostic_rows(filter)
    local info=M.provider_info(filter)
    if info=="" then return {"no_public_global_export_detected"} end
    local rows={}
    -- Keep each value below the logger's 500-character field limit.
    for offset=1,#info,400 do rows[#rows+1]=info:sub(offset,offset+399) end
    return rows
end
function M.client()
    if mesh_client and mesh_client.job then return mesh_client end
    local candidate=mesh()
    local selected=candidate
    local provider=selected==mesh_client and mesh_client and mesh_provider or "arthas_not_loaded"
    if provider~=last_provider then
        last_provider=provider
        if provider_log then provider_log("navigation_backend",{provider=provider=="ameisen_nav" and "arthas_nav" or provider,ameisen_loaded=ameisen_native()~=nil,navlib_loaded=_G.NavLib~=nil,sentinel_loaded=_G.SentinelNavClient~=nil,mesh_server_available=mesh_client and mesh_client:is_server_available() or false,arthas_nav_connected=provider=="ameisen_nav" and mesh_client and mesh_client:is_server_available() or false}) end
    end
    return selected
end
function M.provider_name()
    mesh()
    return mesh_provider=="ameisen_nav" and "arthas_nav" or mesh_provider
end
function M.available()
    local client = M.client()
    return client and client:is_server_available()
end
function M.ground_blocked(goal)
 local player=RuntimeApi.player()
 if not player or not player:is_valid() then return false end
 return repair_policy:ground_blocked(tostring(core.get_instance_id())..":"..tostring(core.get_map_id()),player:get_position(),goal,core.time())
end
function M.move(position, callback, skip_avoidance, repair_bypass)
    local repair_entry
    if not repair_bypass then
        local player=RuntimeApi.player()
        if not player or not player:is_valid() then callback(false,"player_unavailable");return end
        local context=tostring(core.get_instance_id())..":"..tostring(core.get_map_id())
        repair_entry=repair_policy:prepare(context,player:get_position(),position,core.time())
        if repair_entry.exhausted and core.time()<(repair_entry.retry_at or 0) then
            callback(false,"navigation_repair_replan");return
        end
        local original=callback;local consumed=false
        callback=function(ok,reason)
            if consumed then return end;consumed=true
            repair_policy:result(repair_entry,ok,reason,core.time())
            if not ok and repair_entry.cause=="service" then
                local guard=rawget(_G,"ArthasNavEnhancements")
                if guard and guard.check_readiness then guard.check_readiness() end
                local bootstrap=rawget(_G,"ArthasNavBootstrap")
                if bootstrap and bootstrap.tick then bootstrap.tick("auto_leveler",true) end
            end
            if provider_log then provider_log("navigation_self_repair_result",{success=ok,reason=reason,failures=repair_entry.failures,detours=repair_entry.detours}) end
            local cause=require('travel_decisions').failure(reason)
            if not ok and (cause=="terrain" or cause=="elevation") then
                if repair_policy:exhausted(repair_entry) then
                    repair_entry.exhausted=true
                    repair_entry.cycles=(repair_entry.cycles or 0)+1
                    repair_entry.retry_at=core.time()+math.min(60,5*2^math.min(3,repair_entry.cycles-1))
                    M.stop();original(false,"navigation_repair_replan");return
                end
                -- Continue the same request immediately through verified alternatives.
                M.move(position,original);return
            end
            original(ok,reason)
        end
    end
    local in_combat_movement=combat_movement
    M.stop()
    combat_movement=in_combat_movement
    local client = M.client()
    if not client then callback(false, "arthas_not_loaded"); return end
    if not client:is_server_available() then callback(false, "nav_server_unavailable"); return end
    if repair_entry and not skip_avoidance and repair_policy:detour(repair_entry) then
        if provider_log then provider_log("navigation_self_repair_detour",{attempt=repair_entry.detours,cause=repair_entry.cause}) end
        if M.detour(position,function(ok,reason)
            if not ok and reason=="detour_not_needed_for_close_approach" then
                M.move(position,callback,true,true);return
            end
            callback(ok,reason)
        end,true) then return end
        callback(false,"no_verified_detour");return
    end
    if not skip_avoidance and M.known_detour and M.known_detour(position) then
        local handled=M.detour(position,function(ok,reason)
            if not ok and (reason=="no_verified_detour" or reason=="detour_not_needed_for_close_approach") then
                if provider_log then provider_log("navigation_detour_mesh_fallback",{reason=reason}) end
                return M.move(position,callback,true,true)
            end
            callback(ok,reason)
        end)
        if handled then return end
    end
    client:move_to(position,function(ok,reason)
        if M.allow_local_recovery==true and not ok and recovery_client and (reason=="navlib_planning_timeout"
            or tostring(reason):find("unreachable",1,true) or tostring(reason):find("start",1,true)) then
            if provider_log then provider_log("navigation_recovery_started",{provider="verified_ground_graph",reason=reason}) end
            recovery_client:move_to({x=position.x,y=position.y,z=position.z},function(recovered,recovery_reason)
                if provider_log then provider_log("navigation_recovery_result",{provider="verified_ground_graph",success=recovered,reason=recovery_reason}) end
                callback(recovered,recovery_reason)
            end)
            return
        end
        callback(ok,reason)
    end)
end
function M.move_direct(position,callback)
    local in_combat_movement=combat_movement
    M.stop()
    combat_movement=in_combat_movement
    local client=M.client()
    if not client then callback(false,"arthas_not_loaded");return end
    if not client:is_server_available() then callback(false,"nav_server_unavailable");return end
    -- Sentinel owns close-range movement too. Manual look/forward driving here
    -- competed with the mesh client and caused abrupt turns and A-B movement.
    -- The caller may still submit a short terrain-checked leg, but the same
    -- navigation provider executes it and reports completion.
    client:move_direct(position,callback)
end
function M.stop()
    detour_epoch=detour_epoch+1;detour_active=false
    if detour_planner then detour_planner:cancel() end
    combat_movement=false
    if mesh_client then mesh_client:stop() end
    if recovery_client and recovery_client.stop then recovery_client:stop() end
end
function M.move_combat(position,callback)
    combat_movement=true
    M.move(position,callback)
end
function M.replan(reason)
    local client=M.client()
    if not client or type(client.replan)~="function" then return false end
    local ok,result=pcall(function() return client:replan(reason) end)
    return ok and result~=false
end
function M.strafe(direction)
    local client=M.client()
    local movement=client and client.native and client.native.movement
    if not movement or type(movement.strafe)~="function" then return false end
    local ok,result=pcall(function() return movement:strafe(direction) end)
    return ok and result~=false
end
local function planner()
    if detour_planner then return detour_planner end
    detour_planner=require("obstacle_detour").new({time=core.time,
        floor=function(point) return M.measured_height(point) end,
        context=function() return tostring(core.get_instance_id and core.get_instance_id() or 0)..":"..tostring(core.get_map_id and core.get_map_id() or 0) end,
        read=core.read_data_file,
        write=function(path,text)
            core.create_data_folder("sylvanas_auto_leveler/routes");core.create_data_file(path);return core.write_data_file(path,text)
        end,
        log=function(event,fields) if provider_log then provider_log(event,fields) end end,
        find=function(from,to,cb)
            local native=ameisen_native()
            if not native or type(native.find_path)~="function" then cb(false);return end
            native:find_path(from,to,cb,{allow_partial=false})
        end})
    return detour_planner
end
function M.known_detour(goal)
    local native=ameisen_native()
    if not native or type(native.find_path)~="function" or type(native.follow_path)~="function" then return false end
    local p=RuntimeApi.player()
    return p and p:is_valid() and planner():known(p:get_position(),goal) or false
end
local detour_backoff
function M.detour(goal,callback,force_repair)
    local native=ameisen_native()
    if not native or type(native.find_path)~="function" or type(native.follow_path)~="function" then return false end
    detour_backoff=detour_backoff or require("detour_backoff").new()
    local player=RuntimeApi.player()
    if not player or not player:is_valid() then return false end
    local p=player:get_position()
    local map=core.get_instance_id and core.get_instance_id() or 0
    if not force_repair and detour_backoff.blocked(map,p,goal,core.time()) then return false end
    M.stop();local epoch=detour_epoch;detour_active=true
    planner():plan({x=p.x,y=p.y,z=p.z},{x=goal.x,y=goal.y,z=goal.z},function(points,reason)
        if epoch~=detour_epoch then return end
        if not points then detour_backoff.failed(map,p,goal,core.time());detour_active=false;callback(false,reason);return end
        detour_backoff.clear(map,p,goal)
        if provider_log then provider_log("obstacle_detour_verified",{points=#points,reason=reason}) end
        local ran=pcall(function() native:follow_path(points,function(ok,why)
            if epoch~=detour_epoch then return end
            detour_active=false
            if ok then M.move(goal,callback,true,true) else callback(false,why or "obstacle_detour_failed") end
        end) end)
        if not ran then detour_active=false;callback(false,"obstacle_detour_dispatch_failed") end
    end)
    return true
end
function M.state()
    if detour_active then return "navigating.verified_detour" end
    if recovery_client and recovery_client.job then return "navigating.verified_ground_recovery" end
    local client=M.client()
    if not client or not client.native then return nil end
    local native=client.native
    local reader=type(native.get_full_state)=="function" and native.get_full_state or native.get_state
    if type(reader)~="function" then return nil end
    local ok,value=pcall(function() return reader(native) end)
    return ok and value or nil
end
return M


