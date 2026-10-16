local U,A,S,C=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings")
local M={cap_setup=nil,cap_pending=nil,cap_followup=nil,cap_retry_after=-math.huge,pending_projection=nil}
local function position_distance(a,b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function coverage(rows,position,radius)
    local n=0
    for _,r in ipairs(rows) do
        local p=U.call(r.unit,"get_position")
        if p and position_distance(p,position)<=radius then n=n+1 end
    end
    return n
end
local function protected_totem_active()
    local surging=S.ground_record(S.SURGING)
    return (surging and core.time()-surging.time<22)
        or A.since(S.STREAM)<8 or A.since(S.resolve(S.STREAM))<8
        or A.since(S.TIDE)<10 or A.since(S.LINK)<6
        or A.since(S.EARTHGRAB)<8 or A.since(S.EARTHBIND)<8 or A.since(S.STATIC)<6
        or A.since(S.POISON_CLEANSING)<6 or A.since(S.COUNTERSTRIKE)<8
        or A.since(S.GROUNDING)<3 or A.since(S.TREMOR)<6
end
-- Capacitor takes two seconds to arm. Drop it safely at the healer, then move
-- only that confirmed totem onto the selected enemy late in the arming window.
-- The sequence is abandoned whenever another active totem would be displaced.
function M.capacitor_control(me,target)
    if not target or not S.known(S.CAPACITOR) or not S.known(S.PROJECTION) then return false end
    local now=core.time()
    if M.cap_setup and (now-M.cap_setup.started>3 or not U.valid(M.cap_setup.target)) then M.cap_setup=nil end
    if M.cap_setup then
        local placed=S.ground_record(S.CAPACITOR)
        -- Own the control window while input confirmation and the arming delay
        -- are pending. Returning false here would let rs_pvp fall through to a
        -- normal Hex and break the intended Capacitor -> Projection -> Hex chain.
        if not placed or placed.time<M.cap_setup.started then return true end
        local age=now-placed.time
        if age<0.8 then return true end
        if age>1.8 or protected_totem_active() then M.cap_setup=nil;return false end
        local destination=U.call(M.cap_setup.target,"get_position")
        if not destination or U.distance(me,M.cap_setup.target)>30 or not U.visible(me,M.cap_setup.target) then
            M.cap_setup=nil;return false
        end
        if S.cast_position(S.PROJECTION,destination,me,true) then
            M.cap_pending={target=M.cap_setup.target,requested=now,expires=now+2.5}
            M.pending_projection={kind="Capacitor",requested=now}
            M.cap_setup=nil
            C.projection_status="Projected arming Capacitor onto the enemy healer"
            C.status="PvP control: Capacitor projection"
            return true
        end
        return true
    end
    if now<M.cap_retry_after or protected_totem_active()
        or not S.ready(S.CAPACITOR) or not S.ready(S.PROJECTION)
        or U.distance(me,target)>30 or not U.visible(me,target) then return false end
    if S.cast(S.CAPACITOR,me,me,true) then
        M.cap_setup={target=target,started=now}
        C.projection_status="Capacitor armed; preparing late projection"
        C.status="PvP control: preparing Capacitor projection"
        return true
    end
    return false
end
function M.capacitor_followup()
    local state=M.cap_followup
    if not state or core.time()>state.expires or not U.valid(state.target) then M.cap_followup=nil;return nil end
    return state.target
end
function M.capacitor_pending()
    local state=M.cap_pending
    if state and core.time()<=state.expires and U.valid(state.target) then return true end
    M.cap_pending=nil
    return false
end
function M.consume_capacitor_followup() M.cap_followup=nil end
function M.cancel_capacitor_setup(reason)
    if not M.cap_setup then return false end
    M.cap_setup=nil
    M.cap_retry_after=core.time()+3
    C.projection_status=reason or "Capacitor setup cancelled"
    return true
end
function M.reset()
    M.cap_setup=nil;M.cap_pending=nil;M.cap_followup=nil;M.cap_retry_after=-math.huge;M.pending_projection=nil
end
function M.event(event,args)
    if type(args)~="table" or args[1]~="player" then return end
    local id=tonumber(args[3] or args[4])
    if id~=S.PROJECTION and S.resolve(id or 0)~=S.PROJECTION then return end
    local pending=M.cap_pending
    local projection=M.pending_projection
    if event=="UNIT_SPELLCAST_SUCCEEDED" and pending
        and core.time()<=pending.expires and U.valid(pending.target) then
        M.cap_followup={target=pending.target,expires=core.time()+3}
        M.cap_pending=nil
        M.pending_projection=nil
        C.projection_status="Confirmed Capacitor Projection; Hex follow-up armed"
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" and projection
        and core.time()-projection.requested<4 then
        C.projection_status=projection.kind=="Surging"
            and string.format("Confirmed Surging Projection: coverage %d -> %d",projection.old or 0,projection.new or 0)
            or ("Confirmed "..projection.kind.." Projection")
        M.pending_projection=nil
    elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET"
        or event=="UNIT_SPELLCAST_INTERRUPTED" then
        M.cap_pending=nil
        M.pending_projection=nil
        M.cap_retry_after=core.time()+3
        C.projection_status="Capacitor Projection failed; control chain released"
    end
end
function M.control_peel(me,profile,pressure,enemy)
    if not C.get("totemic_projection") or not profile.pvp or not enemy
        or pressure.target~=me or (pressure.self_attackers or 0)<2
        or not S.known(S.PROJECTION) or not S.ready(S.PROJECTION) then return false end
    local static=S.ground_record(S.STATIC)
    if not static or core.time()-static.time>=6 then return false end
    -- Projection moves every active totem. Preserve healing and lifesaving
    -- fields instead of dragging them away merely to improve a peel.
    local surging=S.ground_record(S.SURGING)
    if surging and core.time()-surging.time<22 or A.since(S.STREAM)<8
        or A.since(S.resolve(S.STREAM))<8 or A.since(S.TIDE)<10 or A.since(S.LINK)<6
        or A.since(S.CAPACITOR)<3 or A.since(S.EARTHGRAB)<8 or A.since(S.EARTHBIND)<8
        or A.since(S.POISON_CLEANSING)<6 or A.since(S.COUNTERSTRIKE)<8
        or A.since(S.GROUNDING)<3 or A.since(S.TREMOR)<6 then return false end
    local origin,target=U.call(me,"get_position"),U.call(enemy,"get_position")
    if not origin or not target then return false end
    local dx,dy=target.x-origin.x,target.y-origin.y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.1 then return false end
    local destination={x=origin.x+dx/length*12,y=origin.y+dy/length*12,z=origin.z}
    if S.cast_position(S.PROJECTION,destination,me,true) then
        M.pending_projection={kind="Static Field",requested=core.time()}
        C.projection_status="Projected Static Field away from the healer"
        C.status="PvP peel: projecting trapped attackers"
        return true
    end
    return false
end
function M.run(me,rows,profile,pressure)
    if not C.get("totemic_projection") then C.projection_status="Disabled";return false end
    if not S.known(S.PROJECTION) then C.projection_status="Totemic Projection talent not selected";return false end
    if not S.ready(S.PROJECTION) then C.projection_status="Totemic Projection on cooldown";return false end
    -- Projection moves every active totem. Do not drag short-range lifesaving,
    -- cleansing, or control totems away while their placement still matters.
    if A.since(S.LINK)<6 or A.since(S.CAPACITOR)<3 or A.since(S.EARTHGRAB)<8 or A.since(S.EARTHBIND)<8
        or A.since(S.STATIC)<6 or A.since(S.POISON_CLEANSING)<6
        or A.since(S.COUNTERSTRIKE)<8 or A.since(S.GROUNDING)<3 or A.since(S.TREMOR)<6 then
        C.projection_status="Held to preserve an active rescue, control, or cleansing totem";return false
    end
    local surging=S.ground_record(S.SURGING)
    if not surging or core.time()-surging.time>=22 then C.projection_status="Waiting for active Surging Totem";return false end
    local center,count
    if profile.pvp and not profile.battleground and pressure.target then
        center=pressure.target;count=1
    else center,count=U.cluster(rows,98,10) end
    if not center or count<(profile.delve and 1 or profile.pvp and 1 or 2) then
        C.projection_status="Waiting for a useful healing destination";return false
    end
    if profile.pvp and not pressure.burst and U.count(rows,90,center,10)<1 then
        C.projection_status="Arena target stable; preserving Projection";return false
    end
    local destination=U.call(center,"get_position")
    if not destination then C.projection_status="Destination position unavailable";return false end
    if position_distance(surging.position,destination)<9 then C.projection_status="Surging Totem already covers destination";return false end
    local old_coverage=coverage(rows,surging.position,10)
    local new_coverage=coverage(rows,destination,10)
    local arena_focus=profile.pvp and not profile.battleground and pressure.target~=nil
    if new_coverage<=old_coverage and not pressure.burst and not arena_focus then
        C.projection_status="Held: new position would not improve totem coverage";return false
    end
    if S.cast(S.PROJECTION,center,me,true,false,true) then
        M.pending_projection={kind="Surging",requested=core.time(),old=old_coverage,new=new_coverage}
        C.totemic_status="Projected active healing totems onto the moved group"
        C.projection_status=string.format("Requested Surging Projection: coverage %d -> %d",old_coverage,new_coverage)
        return true
    end
    C.projection_status="Projection ready; waiting for accepted input"
    return false
end
return M
