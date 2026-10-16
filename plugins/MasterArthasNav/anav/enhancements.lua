-- Additive safety layer over the existing navigation client.
local M={zones={},history={},events={},proxies={},travels={},revision=0,overlay=false,config={stall_seconds=8,max_replans=3,lease_seconds=15,recovery_seconds=30}}
local R=require('anav/reliability')
local A=require('anav/advanced')
local P=require('anav/routes')
local C=require('anav/contracts')
local T=require('anav/travel_policy')
local F=require('anav/flight_recorder')
local RuntimeApi=require('anav/runtime_api')
M.compatibility={}
M.reliability=R
M.advanced=A
local base,client,active,epoch,next_tick,next_health,transition=nil,nil,nil,0,0,0,nil
local overlay_control
local local_lease
local reloading=false
function M.set_overlay(value)
    M.overlay=value==true
    if overlay_control then overlay_control:set(M.overlay) end
end
local function now() return core.time() end
local function point(p)
    if not p then return nil end
    local ok,x,y,z=pcall(function() return p.x,p.y,p.z end)
    if not ok then return nil end
    for _,v in ipairs({x,y,z}) do if type(v)~="number" or v~=v or math.abs(v)>100000 then return nil end end
    if x==nil or y==nil or z==nil then return nil end
    return {x=x,y=y,z=z}
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function context() return tostring(core.get_instance_id())..":"..tostring(core.get_map_id()) end
local function position()
    return point(RuntimeApi.position())
end
local function event(code,detail)
    P.record(code,detail)
    M.events[#M.events+1]={time=now(),code=code,detail=tostring(detail or "")}
    if #M.events>80 then table.remove(M.events,1) end
end
local function complete(a,ok,why,detail)
    if a.done then return end
    detail=type(detail)=='table' and detail or nil
    if not ok and why~="cancelled" and why~="priority_preempted" then F.failure(now(),why);A.record_recovery(a,false) end
    if ok then A.record_recovery(a,true) end
    local owned=active==a
    a.done=true;if owned then active=nil end
    if a.pause_applied and client and client.resume then pcall(client.resume,client,'arthas_safety');a.pause_applied=false end
    if owned and not ok and base and base.stop then pcall(base.stop,client) end
    P.snapshot("request_complete",a,position(),why)
    R.record(a,ok,detail and detail.code or why,a.start_position,detail)
    event(why,a.owner)
    if type(a.cb)=="function" then pcall(a.cb,ok,why,detail or {code=why}) end
end
local function learn(p)
    if not p then return end
    local key=context();local found
    for _,h in ipairs(M.history) do if h.context==key and distance(h.center,p)<5 then found=h;break end end
    if not found then found={center=p,context=key,hits=0,radius=3};M.history[#M.history+1]=found end
    found.hits=found.hits+1;found.expires=now()+900
    found.radius=math.min(7,3+math.max(0,found.hits-2))
    if #M.history>64 then table.remove(M.history,1) end
    M.revision=M.revision+1
    if A.persistent then A.dirty=true end
end
function M.add_zone(id,center,radius,ttl)
    center=point(center)
    if type(id)~="string" or #id>80 or not center or type(radius)~="number" or radius~=radius or radius<=0 or radius>100 then return false,"bad_zone" end
    if type(ttl)~="number" or ttl~=ttl or ttl<=0 or ttl>3600 then return false,"bad_ttl" end
    local count=0;for _ in pairs(M.zones) do count=count+1 end
    if count>=64 and not M.zones[id] then return false,"zone_limit" end
    M.zones[id]={center=center,radius=radius,context=context(),expires=now()+ttl}
    M.revision=M.revision+1;return true
end
function M.remove_zone(id) M.zones[id]=nil;M.revision=M.revision+1 end
function M.reset_history() M.history={};R.reset();A.dirty=true;A.save_history(M.history,true);M.revision=M.revision+1;event("history_reset") end
local function zones()
    local out={};local t=now();local key=context()
    for id,z in pairs(M.zones) do
        if z.expires<=t then M.zones[id]=nil;M.revision=M.revision+1
        elseif z.context==key then out[#out+1]=z end
    end
    for i=#M.history,1,-1 do
        local h=M.history[i]
        if h.expires<=t then table.remove(M.history,i);M.revision=M.revision+1
        elseif h.context==key and h.hits>=2 then out[#out+1]=h end
    end
    return out
end
local function hit(a,b,z)
    local dx,dy=b.x-a.x,b.y-a.y;local length=dx*dx+dy*dy
    local t=length>0 and math.max(0,math.min(1,((z.center.x-a.x)*dx+(z.center.y-a.y)*dy)/length)) or 0
    local x,y,height=a.x+dx*t,a.y+dy*t,a.z+(b.z-a.z)*t
    return math.abs(height-z.center.z)<6 and (x-z.center.x)^2+(y-z.center.y)^2<(z.radius+1)^2
end
local function blocked(path,avoid)
    local escaping={}
    local first=point(path[1]);if not first then return true,nil end
    for _,z in ipairs(avoid) do if hit(first,first,z) then escaping[z]=true end end
    for i=2,#path do
        local a,b=point(path[i-1]),point(path[i]);if not a or not b then return true,nil end
        for _,z in ipairs(avoid) do
            -- Allow an initial segment to exit an area containing the player.
            -- Subdivision can leave several initial waypoints inside the zone.
            -- Permit the whole outward prefix, not only its first segment.
            local da=(a.x-z.center.x)^2+(a.y-z.center.y)^2
            local db=(b.x-z.center.x)^2+(b.y-z.center.y)^2
            local outward=(a.x-z.center.x)*(b.x-a.x)+(a.y-z.center.y)*(b.y-a.y)>=0
            local exiting=escaping[z] and outward and db>=da and (db>da or distance(a,b)<.001)
            if not exiting and hit(a,b,z) then return true,z end
            if not hit(b,b,z) then escaping[z]=nil end
        end
    end
    return false
end
M.path_blocked=blocked
local function valid_request(a) return active==a and not a.done and a.epoch==epoch and a.context==context() end
local function cancelled(a)
    if active==a and a.context~=context() then complete(a,false,"context_changed") end
end
local plan
local function finish(a,ok,why,detail)
    detail=type(detail)=='table' and detail or nil
    local code=detail and detail.code or why
    if code=="server_down" or code=="server_timeout" then
        a.serial=a.serial+1;a.phase="recovering";a.recover_until=now()+M.config.recovery_seconds
        -- Stop stale steering and invalidate the old walk callback before
        -- reconnecting. A late success from that walk must not complete recovery.
        pcall(base.stop,client);R.invalidate();event("server_recovery",code);return
    end
    if code=="max_stuck_exceeded" or code=="max_repath_exceeded" then learn(position()) end
    if ok then
        local updated,target_reason=A.target(a,point,true)
        if updated==false then complete(a,false,target_reason);return end
        if type(updated)=='table' then a.goal=updated;a.arrival_goal=nil;A.metrics.target_updates=A.metrics.target_updates+1;plan(a);return end
        local p=position();local goal=a.arrival_goal or a.goal
        local reached,arrival_reason=C.arrived(p,goal,a.opts,{ui_map=core.game_ui and core.game_ui.get_current_map_id,instance=core.get_instance_id})
        P.snapshot("arrival_check",a,p,arrival_reason or "verified")
        if not reached then
            a.arrival_retries=(a.arrival_retries or 0)+1;event("arrival_rejected",a.owner)
            if not a.recorded and a.arrival_retries<=2 then plan(a) else complete(a,false,"arrival_unverified") end
            return
        end
    end
    complete(a,ok,why,detail)
end
local function follow(a,path)
    if not valid_request(a) then cancelled(a);return end
    if not a.recorded then
        local adjusted,reason,confidence=P.inspect(path,a.goal,a.opts)
        a.confidence=confidence;event('route_confidence',confidence)
        if not adjusted then
            if reason=='low_route_confidence' and not a.confidence_retry then a.confidence_retry=true;event('confidence_replan');plan(a);return end
            complete(a,false,reason);return
        end
        path=adjusted
        local current=position()
        if not current then complete(a,false,'player_unavailable');return end
        if distance(current,path[1])>5 then
            event('route_start_moved','Replanning from observed player position')
            plan(a);return
        end
    end
    event('route_ready',string.format('%d waypoints; goal %.1f,%.1f,%.1f',#path,a.goal.x,a.goal.y,a.goal.z))
    local bad=blocked(path,zones())
    if bad then complete(a,false,"danger_no_safe_path");return end
    if a.opts.allow_partial then a.arrival_goal=point(path[#path]) end
    a.route_score=R.score(path,M.history)
    a.phase="walking";a.progress_at=now();a.last_position=position();a.path_index=0
    a.serial=(a.serial or 0)+1;local serial=a.serial
    local ran,result=pcall(base.follow_path,client,path,function(ok,why,detail)
        if not valid_request(a) or a.serial~=serial then return end
        finish(a,ok,why,detail)
    end)
    if (not ran or result==false) and valid_request(a) and a.serial==serial then complete(a,false,'navigation_start_failed') end
end
plan=function(a)
    if not valid_request(a) then cancelled(a);return end
    if a.recorded then complete(a,false,"recorded_route_restart_required");return end
    local start=position();if not start then complete(a,false,"player_unavailable");return end
    A.metrics.plans=A.metrics.plans+1
    a.serial=(a.serial or 0)+1;local serial=a.serial
    local function alive() return valid_request(a) and a.serial==serial end
    a.phase="planning";a.plan_until=now()+20
    base.find_path(client,start,a.goal,function(ok,path,info)
        info=type(info)=='table' and info or nil
        if not alive() then cancelled(a);return end
        if a.pending_goal then a.goal=a.pending_goal;a.pending_goal=nil;a.arrival_goal=nil;plan(a);return end
        if not ok or type(path)~="table" or #path<2 then
            local code=info and info.code or "no_path"
            if code=="server_down" or code=="server_timeout" or code=='query_timeout' or code=='query_queue_timeout' or code=='query_queue_full' then a.phase="recovering";a.recover_until=now()+M.config.recovery_seconds;R.invalidate();event("server_recovery",code)
            else complete(a,false,code,info) end
            return
        end
        local endpoint=point(path[#path])
        local origin=point(path[1])
        if not origin or distance(origin,start)>5 then complete(a,false,'route_start_disconnected');return end
        if not endpoint or (distance(endpoint,a.goal)>5 and not a.opts.allow_partial) then complete(a,false,"unreachable");return end
        if not a.opts.allow_partial and math.abs(endpoint.z-a.goal.z)>(a.opts.arrival_height or 3) then complete(a,false,"destination_floor_mismatch");return end
        local bad,z=blocked(path,zones())
        if not bad then follow(a,path);return end
        if not z then complete(a,false,"bad_path");return end
        local dx,dy=a.goal.x-start.x,a.goal.y-start.y;local len=math.sqrt(dx*dx+dy*dy)
        if len<.1 then complete(a,false,"danger_no_safe_path");return end
        local attempt,best,best_score,best_via=0,nil,math.huge,nil
        local function try_detour()
            if not alive() then cancelled(a);return end
            attempt=attempt+1
            if attempt>4 then
                if best then a.recovery_via=best_via;event("safe_detour_selected",string.format("score %.1f",best_score));follow(a,best)
                else complete(a,false,"danger_no_safe_path") end
                return
            end
            local side=attempt%2==1 and 1 or -1;local radius=z.radius+3+math.floor((attempt-1)/2)*4
            local via={x=z.center.x-dy/len*radius*side,y=z.center.y+dx/len*radius*side,z=z.center.z}
            base.find_path(client,start,via,function(ok1,p1)
                if not alive() then cancelled(a);return end
                if not ok1 or type(p1)~="table" or #p1<2 or blocked(p1,zones()) then try_detour();return end
                base.find_path(client,p1[#p1],a.goal,function(ok2,p2)
                    if not alive() then cancelled(a);return end
                    if not ok2 or type(p2)~="table" or #p2<2 then try_detour();return end
                    local endpoint2=point(p2[#p2])
                    if not endpoint2 or (distance(endpoint2,a.goal)>5 and not a.opts.allow_partial) then try_detour();return end
                    local joined={};for _,p in ipairs(p1) do joined[#joined+1]=p end
                    for i=2,#p2 do joined[#joined+1]=p2[i] end
                    if blocked(joined,zones()) then try_detour();return end
                    local score=math.max(0,R.score(joined,M.history)-A.recovery_bias(a.context,via))
                    if score<best_score then best,best_score,best_via=joined,score,via end
                    try_detour()
                end,a.opts)
            end,a.opts)
        end
        try_detour()
    end,a.opts)
end
local function launch(a)
    if not valid_request(a) then return false end
    a.start_position=a.start_position or position()
    if a.recorded and blocked(a.recorded,zones()) then complete(a,false,"danger_no_safe_path");return false end
    if a.method=="move_to" then plan(a);return true end
    a.phase="walking";a.progress_at=now();a.last_position=position()
    A.metrics.plans=A.metrics.plans+1
    a.serial=a.serial+1;local serial=a.serial
    local ran,result=pcall(base[a.method],client,a.recorded or a.goal,function(ok,why,detail)
        if valid_request(a) and a.serial==serial then
            if ok and a.opts.allow_partial and client.get_current_path then
                local path=client:get_current_path();a.arrival_goal=type(path)=='table' and point(path[#path]) or nil
            end
            finish(a,ok,why,detail)
        end
    end,a.opts)
    if (not ran or result==false) and valid_request(a) and a.serial==serial then complete(a,false,"navigation_start_failed") end
    return ran and result~=false
end
local function begin(owner,goal,cb,opts,method,recorded)
    if reloading or not client or not base then if type(cb)=='function' then pcall(cb,false,'client_reloaded',{code='client_reloaded'}) end;return false end
    if M.compatibility[owner]=='consumer_version_mismatch' then if cb then pcall(cb,false,'consumer_version_mismatch') end;return false end
    if local_lease and local_lease.expires>now() and local_lease.context==context() then
        if cb then pcall(cb,false,'navigation_owned',{code='navigation_owned',owner=local_lease.owner}) end;return false
    end
    goal=point(goal)
    if not goal then if cb then cb(false,"bad_request",{code="bad_request"}) end;return false end
    opts=opts or {}
    if type(opts)=='table' then local snapshot={};for k,v in pairs(opts) do snapshot[k]=v end;opts=snapshot end
    if type(opts)~='table' or not A.priority(opts) or (opts.obstacle_probe~=nil and type(opts.obstacle_probe)~='function') or (opts.recovery_handler~=nil and type(opts.recovery_handler)~='function') or (opts.is_valid~=nil and type(opts.is_valid)~='function') or (opts.arrival_valid~=nil and type(opts.arrival_valid)~='function') or (opts.destination_provider~=nil and type(opts.destination_provider)~='function') or (opts.expires_at~=nil and (type(opts.expires_at)~='number' or opts.expires_at~=opts.expires_at or opts.expires_at==math.huge)) then
        if cb then cb(false,'bad_request',{code='bad_request'}) end;return false
    end
    for _,rule in ipairs({{'max_drop',0,100},{'min_confidence',0,100},{'arrival_radius',0.25,20},{'arrival_height',0.25,10},{'expected_ui_map',0,99999},{'expected_instance',0,999999}}) do
        local v=opts[rule[1]]
        if v~=nil and (type(v)~='number' or v~=v or v<rule[2] or v>rule[3]) then if cb then cb(false,'bad_request',{code='bad_request'}) end;return false end
    end
    if transition then if cb then cb(false,"transport_busy",{code="transport_busy"}) end;return false end
    if active and active.owner~=owner then
        if opts.preempt==true and A.priority(opts)>(active.priority or 0) then
            local old=active;active=nil;epoch=epoch+1;pcall(base.stop,client);A.metrics.preemptions=A.metrics.preemptions+1;complete(old,false,'priority_preempted')
        else if cb then cb(false,"navigation_owned",{code="navigation_owned",owner=active.owner}) end;return false end
        -- A consumer callback may have submitted another request. Never overwrite it.
        if active then if cb then cb(false,'navigation_owned',{code='navigation_owned'}) end;return false end
    end
    local start=position()
    if active then
        local old=active;active=nil;epoch=epoch+1;pcall(base.stop,client);complete(old,false,"cancelled")
        if active or transition then if cb then cb(false,'navigation_owned',{code='navigation_owned'}) end;return false end
    end
    epoch=epoch+1
    local a={owner=owner,goal=goal,cb=cb,opts=opts or {},method=method,context=context(),epoch=epoch,serial=1,phase="preflight",progress_at=now(),last_position=start,start_position=start,replans=0,lease_until=now()+M.config.lease_seconds,ready_until=now()+45}
    active=a;event("navigation_started",owner)
    a.priority=A.priority(opts)
    a.recorded=recorded
    if recorded then
        local snapshot={}
        for i,p in ipairs(recorded) do local normalized=point(p);if not normalized then complete(a,false,'bad_path');return false end;snapshot[i]=normalized end
        a.recorded=snapshot
    end
    R.poll()
    if not R.safety_reason(a.opts) and R.ready() then return launch(a) end
    return true
end
function M.acquire_local(owner)
 if local_lease and (local_lease.expires<=now() or local_lease.context~=context()) then local_lease=nil end
 if type(owner)~='string' or #owner>80 or active or transition then return false end
 if local_lease and local_lease.expires>now() then return false end
 local_lease={owner=owner,context=context(),expires=now()+15};return true
end
function M.has_local(owner)
 return local_lease and local_lease.owner==owner and local_lease.context==context() and local_lease.expires>now() or false
end
function M.release_local(owner)
 if local_lease and local_lease.owner==owner then local_lease=nil;return true end
 return false
end
function M.heartbeat(owner)
 if local_lease and (local_lease.expires<=now() or local_lease.context~=context()) then local_lease=nil end
 if local_lease and local_lease.owner==owner and local_lease.context==context() then local_lease.expires=now()+15 end
    if active and active.owner==owner then active.lease_until=now()+M.config.lease_seconds end
end
function M.release(owner)
    M.release_local(owner)
    local journey=M.travels[owner]
    local a=active and active.owner==owner and active or nil
    local tr=transition and transition.owner==owner and transition or nil
    -- Detach the entire old journey before invoking any consumer callbacks.
    if journey then M.travels[owner]=nil;journey.done=true end
    if tr then transition=nil end
    if a then active=nil;epoch=epoch+1;pcall(base.stop,client);complete(a,false,'cancelled') end
    if tr and tr.cb then pcall(tr.cb,false,'cancelled') end
    if journey and journey.cb then pcall(journey.cb,false,'cancelled') end
    return a~=nil or tr~=nil or journey~=nil
end
function M.check_compatibility(owner,contract)
 if type(owner)~='string' or #owner>80 or type(contract)~='table' then return false,'bad_contract' end
 local count=0;for _ in pairs(M.compatibility) do count=count+1 end
 if count>=64 and not M.compatibility[owner] then return false,'contract_limit' end
 local ok=contract.protocol==R.protocol and contract.map_schema==1 and contract.api==1
 M.compatibility[owner]=ok and 'compatible' or 'consumer_version_mismatch'
 return ok,M.compatibility[owner]
end
function M.get_client(owner,contract)
    if contract and not M.check_compatibility(owner,contract) then return nil end
    if not client or type(owner)~="string" then return nil end
    if M.proxies[owner] then return M.proxies[owner] end
    local proxy={}
    setmetatable(proxy,{__index=function(_,key)
        if key=='travel_best' then return function(_,choices,cb,opts) return M.travel_best(owner,choices,cb,opts) end end
        if key=='travel_route' then return function(_,steps,cb,opts) return M.travel_route(owner,steps,cb,opts) end end
        if key=='track_target' then return function(_,provider,cb,opts)
            if type(provider)~='function' or (opts~=nil and type(opts)~='table') then if cb then cb(false,'bad_request',{code='bad_request'}) end;return false end
            local ok,goal=pcall(provider);if not ok or not point(goal) then if cb then cb(false,'target_lost',{code='target_lost'}) end;return false end
            local options={};for k,v in pairs(opts or {}) do options[k]=v end
            options.destination_provider=provider;options.expires_at=options.expires_at or now()+60
            M.heartbeat(owner);return begin(owner,goal,cb,options,'move_to')
        end end
        if key=='set_objective' then return function(_,token,valid) return A.set_objective(owner,token,valid) end end
        if key=='invalidate_destination' then return function()
            if active and active.owner==owner then local a=active;active=nil;epoch=epoch+1;pcall(base.stop,client);complete(a,false,'destination_stale');return true end
            return false
        end end
        if key=="move_to" or key=="move_direct" then return function(_,goal,cb,opts) M.heartbeat(owner);return begin(owner,goal,cb,opts,key) end end
        if key=="stop" then return function() return M.release(owner) end end
        if key=="follow_path" then return function(_,path,cb)
            if type(path)~="table" or #path<2 then if cb then cb(false,"bad_request",{code="bad_request"}) end;return false end
            if blocked(path,zones()) then if cb then cb(false,"danger_no_safe_path",{code="danger_no_safe_path"}) end;return false end
            local goal=point(path[#path]);if not goal then return false end
            return begin(owner,goal,cb,{horizon=false},"follow_path",path)
        end end
        if key=="pause" or key=="resume" or key=="replan" or key=="handoff" then return function(_,...)
            if (active and active.owner~=owner) or (transition and transition.owner~=owner) then return false end
            if not client or type(client[key])~='function' then return false end
            local result=client[key](client,...)
            if active and active.owner==owner and result~=false then
                if key=='pause' then active.manual_paused=true elseif key=='resume' then active.manual_paused=nil;active.native_wait_since=nil;active.progress_at=now() end
            end
            return result
        end end
        local value=client and client[key]
        if type(value)=="function" then return function(_,...)
            local current=client and client[key]
            if type(current)~='function' then return false end
            return current(client,...)
        end end
        return value
    end})
    M.proxies[owner]=proxy;return proxy
end
function M.begin_transition(owner,expected_context,timeout,cb,arrival_position,arrival_valid)
    if local_lease and local_lease.expires>now() and local_lease.context==context() then return false,"navigation_owned" end
    if transition or (active and active.owner~=owner) then return false,"navigation_owned" end
    if type(owner)~='string' or type(expected_context)~="string" or type(timeout)~="number" or timeout~=timeout or timeout<=0 or timeout>300 then return false,"bad_request" end
    if arrival_valid~=nil and type(arrival_valid)~="function" then return false,"bad_transition_evidence" end
    local arrival=point(arrival_position)
    if expected_context==context() and not arrival then return false,"transport_arrival_required" end
    M.release(owner)
    if active or transition then return false,'navigation_owned' end
    transition={owner=owner,expected=expected_context,arrival=arrival,arrival_valid=arrival_valid,expires=now()+timeout,cb=cb};event("transport_wait",expected_context);return true
end
function M.cancel_transition(owner)
    if transition and transition.owner==owner then local t=transition;transition=nil;if t.cb then pcall(t.cb,false,"cancelled") end;return true end
    return false
end
function M.travel_route(owner,steps,cb,opts)
    if type(owner)~='string' or type(steps)~='table' or #steps<1 or #steps>32 or M.travels[owner] or transition or active then return false,'navigation_owned' end
    local copy={}
    for i,s in ipairs(steps) do
        if type(s)~='table' or not point(s.approach) or type(s.expected_context)~='string' or not point(s.arrival) or type(s.timeout)~='number' or s.timeout~=s.timeout or s.timeout<1 or s.timeout>300 or (s.activate~=nil and type(s.activate)~='function') or (s.arrival_valid~=nil and type(s.arrival_valid)~='function') then return false,'bad_travel_step' end
        copy[i]={approach=point(s.approach),arrival=point(s.arrival),expected_context=s.expected_context,timeout=s.timeout,activate=s.activate,arrival_valid=s.arrival_valid}
    end
    local journey={steps=copy,index=0,cb=cb};M.travels[owner]=journey
    local function finish_travel(ok,reason)
        if journey.done then return end;journey.done=true;M.travels[owner]=nil;event('travel_finished',reason);if cb then pcall(cb,ok,reason) end
    end
    local advance
    advance=function()
        if journey.done then return end
        journey.index=journey.index+1;local step=copy[journey.index]
        if not step then finish_travel(true,'arrived');return end
        event('travel_approach',journey.index)
        begin(owner,step.approach,function(ok,reason)
            if journey.done then return end
            if not ok then finish_travel(false,reason);return end
            -- Register the arrival monitor before activating a door/portal/vehicle.
            M.travels[owner]=nil
            local accepted,why=M.begin_transition(owner,step.expected_context,step.timeout,function(arrived,result)
                if arrived then advance() else finish_travel(false,result) end
            end,step.arrival,step.arrival_valid)
            M.travels[owner]=journey
            if not accepted then finish_travel(false,why);return end
            if step.activate then
                local registered=transition
                local dispatched,result=pcall(step.activate)
                if journey.done then return end
                if not dispatched or result==false then
                    -- Remove only this activation's monitor before callbacks
                    -- can submit a replacement journey or transition.
                    if transition==registered then transition=nil end
                    finish_travel(false,'travel_activation_failed')
                end
            end
        end,opts,'move_to')
    end
    advance();return true
end
function M.status()
    return {owner=active and active.owner,phase=active and active.phase or "idle",context=context(),replans=active and active.replans or 0,history_count=#M.history,revision=M.revision,transport=transition and transition.expected,readiness=R.readiness.code,safety=active and active.safety,route_score=active and active.route_score,confidence=active and active.confidence,version=R.version,destination=active and active.goal,priority=active and active.priority or 0,provider="ArthasNav",recovery_reason=active and active.recovery_reason,movement_mode=transition and "transport" or active and active.method or "idle",persistent=A.persistent,performance=M.performance()}
end
function M.performance() local p=A.performance();p.bridge=R.readiness.performance or {};p.scheduler=P.metrics;p.queue_depth=#P.queue;return p end
function M.export_logs()
    return R.report(M.status(),M.events)..'\n\n'..P.export()..'\n\n'..F.export()..'\n\n'..A.outcome_report()..'\n\n'..M.compatibility_report()
end
function M.choose_travel(candidates) return T.choose(candidates) end
function M.travel_best(owner,candidates,cb,opts)
 local selected,cost=T.choose(candidates)
 if not selected then return false,cost end
 if type(selected.steps)~='table' then return false,'travel_steps_required' end
 event('travel_selected',tostring(selected.mode or 'unknown')..' estimated_seconds='..tostring(cost))
 return M.travel_route(owner,selected.steps,cb,opts)
end
function M.compatibility_report()
 local rows={'## Consumer compatibility contracts'}
 for owner,state in pairs(M.compatibility) do rows[#rows+1]=owner:gsub('[^%w_%-]','_')..': '..state end
 rows[#rows+1]='Bridge protocol, engine API and map schema are checked by readiness; undeclared consumers remain unknown.'
 return table.concat(rows,'\n')
end
function M.save_report() return R.save(M.export_logs()) end
function M.check_readiness() R.invalidate();R.poll() end
function M.set_safety_state(key,value) return R.set_safety_state(key,value) end
function M.set_persistent_history(value) return A.set_persistent(value,M.history) end
function M.set_objective(owner,token,valid) return A.set_objective(owner,token,valid) end
function M.tick()
    local t=now();if t<next_tick then return end;next_tick=t+.25
    if local_lease and (local_lease.expires<=t or local_lease.context~=context()) then local_lease=nil end
    F.sample(t,position(),M.status())
    for owner in pairs(M.travels) do M.heartbeat(owner) end
    -- MasterArthasNav: follow the table this load of the library exported;
    -- another plugin's _G.AmeisenNav or a stale one from before F6 is never used.
    local X=rawget(_G,"ArthasNavExport")
    local g=type(X)=="table" and type(X.current)=="function" and X.current() or rawget(_G,"AmeisenNav") or rawget(_G,"ArthasNav")
    if type(g)~='table' then g=nil end
    if client and (not g or g.client~=client) then
        reloading=true;epoch=epoch+1
        if active then local previous=active;active=nil;pcall(base.stop,client);complete(previous,false,"client_reloaded") end
        client=nil;base=nil;M.proxies={};event("client_reloaded")
        reloading=false;R.invalidate()
    end
    if not client and g and type(g.client)=="table" then
        client=g.client;base={};for _,name in ipairs({"move_to","move_direct","follow_path","find_path","stop"}) do base[name]=client[name] end
        if type(base.find_path)~="function" or type(base.follow_path)~="function" or type(base.stop)~='function' or type(base.move_to)~='function' then client=nil;base=nil;return end
        local find=base.find_path
        base.find_path=function(c,start,goal,cb,opts)
            local request=active;local serial=request and request.serial
            return P.submit(function(done)
                local stamp=A.query_started();local measured=false
                return find(c,start,goal,function(...)
                    if not measured then A.query_finished(stamp);measured=true end
                    done(...)
                end,opts)
            end,function() return request and valid_request(request) and request.serial==serial end,request and request.priority or 0,cb)
        end
        event("enhancements_ready")
    end
    if not client then return end
    P.pump()
    if not A.loaded then
        local restored=A.load_history()
        if restored then
            for _,h in ipairs(restored) do
                local duplicate=false
                for _,old in ipairs(M.history) do if old.context==h.context and distance(old.center,h.center)<5 then duplicate=true;break end end
                if not duplicate then M.history[#M.history+1]=h end
            end
            while #M.history>64 do table.remove(M.history,1) end
        end
    end
    zones()
    A.save_history(M.history)
    if transition then
        local p=position()
        local arrived=context()==transition.expected and (not transition.arrival or p and distance(p,transition.arrival)<3) and T.evidence(transition.arrival_valid)
        if arrived or t>=transition.expires then
            local tr=transition;transition=nil;local ok=arrived
            event(ok and "transport_arrived" or "transport_timeout",tr.expected)
            if tr.cb then pcall(tr.cb,ok,ok and "arrived" or "transport_timeout") end
        end
        return
    end
    local a=active;if not a then return end
    if a.context~=context() then a.epoch=-1;pcall(base.stop,client);complete(a,false,"context_changed");return end
    if t>=a.lease_until then a.epoch=-1;pcall(base.stop,client);complete(a,false,"owner_expired");return end
    local goal,target_reason=A.target(a,point)
    if goal==false then a.epoch=-1;pcall(base.stop,client);complete(a,false,target_reason);return end
    if type(goal)=='table' and a.phase=='planning' then
        a.pending_goal=goal
    elseif type(goal)=='table' then
        a.goal=goal;a.arrival_goal=nil;a.samples={};a.recovery=nil;a.best_distance=nil;A.metrics.target_updates=A.metrics.target_updates+1
        a.serial=a.serial+1;a.epoch=-1;pcall(base.stop,client);epoch=epoch+1;a.epoch=epoch
        a.needs_replan=true;a.phase='preflight';a.ready_until=t+45;event('moving_target_updated')
    end
    local safety=R.safety_reason(a.opts)
    if safety then
        if not a.safety then
            a.safety=safety;a.held_phase=a.phase;a.serial=a.serial+1
            if client.pause and a.held_phase~='preflight' then client:pause('arthas_safety');a.pause_applied=true
            elseif a.held_phase~='preflight' then pcall(base.stop,client);a.restart_after_hold=true end
            event('safety_hold',safety)
        end
        a.phase='safety_hold';a.progress_at=t;a.samples={};if a.recovery then a.recovery.until_time=t+12 end;return
    elseif a.safety then
        a.safety=nil;event('safety_released');R.invalidate()
        -- The route can have changed during a hold. Rebuild before resuming.
        if client.resume and a.pause_applied then client:resume('arthas_safety');a.pause_applied=false end
        a.serial=a.serial+1;a.epoch=-1;pcall(base.stop,client);epoch=epoch+1;a.epoch=epoch
        if a.recorded then complete(a,false,'recorded_route_restart_required');return end
        a.phase='preflight';a.ready_until=t+45;a.needs_replan=true
    end
    local p=position();if not p then return end
    if a.opts.allow_swimming==false and core.character and core.character.is_swimming then
        local ok,swimming=pcall(core.character.is_swimming)
        if ok and swimming then a.epoch=-1;pcall(base.stop,client);complete(a,false,'swimming_disallowed');return end
    end
    if a.phase=='preflight' then
        R.poll()
        if R.ready() then if a.needs_replan then plan(a) else launch(a) end
        elseif R.readiness.code=='map_not_loaded' or R.readiness.code=='map_tiles_missing' or R.readiness.code=='version_mismatch' or R.readiness.code=='bridge_upgrade_required' or R.readiness.code=='http_unavailable' or R.readiness.code=='map_context_mismatch' then complete(a,false,R.readiness.code)
        elseif t>=a.ready_until then complete(a,false,R.readiness.code=='checking' and 'readiness_timeout' or R.readiness.code) end
        return
    end
    if a.phase=="recovering" then
        if t>=a.recover_until then complete(a,false,"server_timeout");return end
        R.poll()
        if R.ready() then event("server_reconnected");plan(a) end
        return
    end
    if a.phase=="planning" then if a.recovery then a.recovery.until_time=t+12 end;if t>=a.plan_until then complete(a,false,"server_timeout") end;return end
    local state=client.get_full_state and tostring(client:get_full_state()) or ""
    if a.manual_paused then a.progress_at=t;a.samples={};return end
    local casting=RuntimeApi.casting()
    if casting then a.native_wait_since=nil;a.progress_at=t;a.last_position=p;a.samples={};if a.recovery then a.recovery.until_time=t+12 end;return end
    if state:find("paus") or state:find("recover") or state:find("planning") then
        a.native_wait_since=a.native_wait_since or t
        if t-a.native_wait_since<20 then a.progress_at=t;a.last_position=p;a.samples={};return end
        a.native_wait_since=nil;a.serial=a.serial+1;a.epoch=-1;pcall(base.stop,client);epoch=epoch+1;a.epoch=epoch
        event('native_state_stalled',state)
        if a.recorded then complete(a,false,'recorded_route_restart_required') else plan(a) end
        return
    end
    a.native_wait_since=nil
    if not a.performance_at or t>=a.performance_at then a.performance_at=t+10;R.poll() end
    local verified=A.verify_recovery(a,p)
    local loop=A.observe(a,p)
    if verified==true then event('recovery_verified') end
    local problem=verified==false and 'recovery_ineffective' or loop and 'route_loop'
    if problem then
        F.failure(t,problem);P.snapshot(problem,a,p);learn(p);a.replans=a.replans+1;event(problem,a.replans)
        if a.replans>M.config.max_replans then a.epoch=-1;pcall(base.stop,client);complete(a,false,problem);return end
        A.start_recovery(a,p,problem)
        if T.recover(a,p,problem,R.readiness.code) then a.progress_at=t;event("obstacle_recovery",a.recovery_reason);return end
        a.serial=a.serial+1;a.epoch=-1;pcall(base.stop,client);epoch=epoch+1;a.epoch=epoch;a.progress_at=t;a.best_distance=nil;plan(a);return
    end
    local index=client.get_path_index and client:get_path_index() or 0
    local path=client.get_current_path and client:get_current_path() or {}
    if not a.route_score and type(path)=='table' and #path>1 then a.route_score=R.score(path,M.history) end
    local waypoint=point(path[math.max(1,index)]) or a.goal
    if distance(p,waypoint)<2 then waypoint=point(path[math.max(1,index)+1]) or a.goal end
    local remaining=distance(p,waypoint)
    if index~=(a.path_index or 0) or not a.best_distance or remaining<a.best_distance-.8 then
        a.path_index=index;a.best_distance=remaining;a.last_position=p;a.progress_at=t;return
    end
    if t-a.progress_at>=M.config.stall_seconds then
        F.failure(t,"progress_stalled");P.snapshot("progress_stalled",a,p);learn(p);a.replans=a.replans+1;event("progress_stalled",a.replans)
        if a.replans>M.config.max_replans then a.epoch=-1;pcall(base.stop,client);complete(a,false,"progress_stalled");return end
        -- Invalidate callbacks from the interrupted walk before planning another route.
        A.start_recovery(a,p,'progress_stalled')
        if T.recover(a,p,'progress_stalled',R.readiness.code) then a.progress_at=t;event('obstacle_recovery',a.recovery_reason);return end
        a.serial=a.serial+1;a.epoch=-1;pcall(base.stop,client);epoch=epoch+1;a.epoch=epoch;a.progress_at=t;a.best_distance=nil;plan(a)
    end
end
function M.draw()
    if not M.overlay or not client or not core.graphics then return end
    local ok,Color=pcall(require,"common/color");if not ok then return end
    local col=Color.new(255,90,70,180)
    local p=position()
    if p and core.graphics.text_3d then
        local s=M.status();core.graphics.text_3d("ArthasNav: "..s.phase.." | "..tostring(s.owner or "none").." | "..s.provider.." | "..tostring(s.movement_mode).." | recovery "..tostring(s.recovery_reason or "none").." | replans "..s.replans..(s.destination and string.format(" | goal %.1f %.1f %.1f",s.destination.x,s.destination.y,s.destination.z) or ""),{x=p.x,y=p.y,z=p.z+3},14,col,true,0)
    end
    for _,z in ipairs(zones()) do
        for i=1,16 do
            local a,b=(i-1)*math.pi/8,i*math.pi/8
            core.graphics.line_3d({x=z.center.x+math.cos(a)*z.radius,y=z.center.y+math.sin(a)*z.radius,z=z.center.z+1},{x=z.center.x+math.cos(b)*z.radius,y=z.center.y+math.sin(b)*z.radius,z=z.center.z+1},col,2,1,false)
        end
    end
end
function M.setup()
    R.setup()
    local last_error=-100
    local overlay=core.menu and core.menu.checkbox and core.menu.checkbox(false,"arthas_nav_improvements_overlay")
    overlay_control=overlay
    core.register_on_update_callback(function()
        local ok,err=pcall(M.tick)
        if overlay then M.overlay=overlay:get_state() end
        if not ok and now()-last_error>10 then last_error=now();if core.log_error then core.log_error("ArthasNav enhancements: "..tostring(err)) end end
    end)
    core.register_on_render_callback(function() pcall(M.draw) end)
    if overlay and core.register_on_render_menu_callback then
        core.register_on_render_menu_callback(function() overlay:render("ArthasNav recovery overlay","Show navigation owner, recovery status and danger areas.") end)
    end
end
return M

