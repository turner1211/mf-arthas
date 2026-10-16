-- Bounded live-position prediction for moving quest and combat targets.
-- This is deliberately owned by the leveler; it does not share BG state.
local M={}

local POLICIES={
    combat_pull={horizon=0.35,cap=8},
    vehicle={horizon=0.50,cap=8},
    item_action={horizon=0.25,cap=4},
    world_object={horizon=0.20,cap=3},
}

local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function length(x,y,z) return math.sqrt(x*x+y*y+z*z) end

function M.new()
    local self={samples={}}
    function self:forget(key) self.samples[key]=nil end
    function self:prune(now)
        for key,row in pairs(self.samples) do
            if now-row.time>5 then self.samples[key]=nil end
        end
    end
    function self:predict(key,position,now,purpose)
        if not key or not position then return position end
        local previous=self.samples[key]
        local current=copy(position)
        if not previous then
            self.samples[key]={position=current,time=now}
            return current
        end
        local dt=now-previous.time
        -- Keep a useful baseline when update callbacks arrive faster than a
        -- measurable movement interval.
        if dt<0.15 then return current end
        self.samples[key]={position=current,time=now}
        if dt>2.5 then return current end
        local dx,dy,dz=current.x-previous.position.x,current.y-previous.position.y,current.z-previous.position.z
        local speed=length(dx,dy,dz)/dt
        if speed<0.5 or speed>35 or math.abs(dz)>8 then return current end
        local policy=POLICIES[purpose] or POLICIES.combat_pull
        local horizon=math.min(policy.horizon,policy.cap/speed)
        local predicted={x=current.x+dx/dt*horizon,y=current.y+dy/dt*horizon,z=current.z+dz/dt*horizon}
        return predicted,{speed=speed,horizon=horizon,advance=speed*horizon}
    end
    return self
end

return M
