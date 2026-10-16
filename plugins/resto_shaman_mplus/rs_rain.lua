local A,S,U=require("rs_auras"),require("rs_spells"),require("rs_units")
local M={}

-- Healing Rain and Surging Totem have different live windows. Keep this in one
-- place so Downpour never treats an expired 18-second Healing Rain as active.
function M.window()
    local age=A.since(S.SURGING)
    if age<24 then
        local record=S.ground_record(S.SURGING)
        return {active=true,age=age,duration=24,closing=age>=16,kind="Surging Totem",
            position=record and core.time()-record.time<24 and record.position or nil}
    end
    age=A.since(S.RAIN)
    if age<18 then
        local record=S.ground_record(S.RAIN)
        return {active=true,age=age,duration=18,closing=age>=14,kind="Healing Rain",
            position=record and core.time()-record.time<18 and record.position or nil}
    end
    return {active=false,age=math.huge,duration=0,closing=false,kind="none"}
end

-- Downpour erupts at the active Rain, not around the caster. Only confirmed
-- ground placement is usable; a requested or unobservable tier-proc Rain must
-- never make distant injuries look covered.
function M.coverage(rows,window,threshold)
    window=window or M.window()
    if not window.active or not window.position then return {},0,0 end
    local covered,count,deficit={},0,0
    threshold=threshold or 98
    for _,row in ipairs(rows or {}) do
        local position=U.call(row.unit,"get_position")
        if position then
            local dx,dy,dz=position.x-window.position.x,position.y-window.position.y,position.z-window.position.z
            if math.sqrt(dx*dx+dy*dy+dz*dz)<=12 then
                covered[#covered+1]=row
                if row.hp<=threshold then count=count+1 end
                deficit=deficit+math.max(0,100-row.hp)
            end
        end
    end
    return covered,count,deficit
end

return M
