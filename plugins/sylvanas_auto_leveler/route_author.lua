-- Local route authoring and strict plain XYZ route import.
-- This format is owned by this plugin; Master Farmer compatibility must be observed first.
local M = {}
local RuntimeApi=require("leveler_runtime_api")
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function name_ok(s) return type(s)=="string" and s:match("^[A-Za-z0-9_-]+$") and #s<=64 end
function M.parse_xyz(text)
    if type(text)~="string" or #text>2000000 then return nil,"invalid_route_size" end
    local nodes={}
    for raw_line in (text.."\n"):gmatch("([^\n]*)\n") do
        local line=raw_line:gsub("\r$","")
        if line:match("%S") then
            local x,y,z=line:match("^%s*([^,]+),([^,]+),([^,]+)%s*$")
            x,y,z=tonumber(x),tonumber(y),tonumber(z)
            if not finite(x) or not finite(y) or not finite(z) then return nil,"invalid_xyz_row" end
            nodes[#nodes+1]={x=x,y=y,z=z}
            if #nodes>20000 then return nil,"too_many_waypoints" end
        end
    end
    if #nodes<2 then return nil,"at_least_two_waypoints_required" end
    return nodes
end
function M.new(api)
    local self={api=api,recording=false,nodes={},context=nil,status="idle",next_sample=0}
    function self:start(name)
        if not name_ok(name) then return false,"invalid_route_name" end
        local position,context=self.api.sample()
        if not position or not context then return false,"player_not_ready" end
        self.name=name; self.context=context; self.nodes={position}; self.recording=true
        self.status="recording"; self.next_sample=0;self.last_motion_at=self.api.time();self.motion_position=position
        return true
    end
    function self:tick()
        if not self.recording or self.api.time()<self.next_sample then return end
        self.next_sample=self.api.time()+0.25
        local p,c=self.api.sample()
        if not p or not c then self.recording=false; self.status="player_not_ready"; return end
        if c.world_map_id~=self.context.world_map_id or c.instance_id~=self.context.instance_id
            or c.ui_map_id~=self.context.ui_map_id then
            self.recording=false; self.status="map_changed_split_route"; return
        end
        local observed=self.motion_position or p
        if math.sqrt((p.x-observed.x)^2+(p.y-observed.y)^2+(p.z-observed.z)^2)>=0.5 then
            self.last_motion_at=self.api.time();self.motion_position=p
        end
        local last=self.nodes[#self.nodes]
        local d=math.sqrt((p.x-last.x)^2+(p.y-last.y)^2+(p.z-last.z)^2)
        if d>100 then self.recording=false; self.status="position_jump_split_route"; return end
        if d>=3 then self.nodes[#self.nodes+1]=p end
        if #self.nodes>=20000 then self.recording=false; self.status="route_limit_reached" end
    end
    function self:autosave_ready()
        return self.recording and #self.nodes>=2 and self.api.time()-(self.last_motion_at or self.api.time())>=5
    end
    function self:save()
        self.recording=false
        if #self.nodes<2 then self.status="at_least_two_waypoints_required"; return false end
        local rows={}
        for _,p in ipairs(self.nodes) do rows[#rows+1]=string.format("%.6f,%.6f,%.6f",p.x,p.y,p.z) end
        self.api.write(self.name,table.concat(rows,"\n").."\n",self.context)
        self.status="saved_unvalidated"
        return true
    end
    return self
end
function M.runtime_api()
    return {
        time=core.time,
        sample=function()
            local p=RuntimeApi.player()
            if not p or not p:is_valid() or p:is_dead() or p:is_ghost() then return nil end
            local v=p:get_position()
            if not finite(v.x) or not finite(v.y) or not finite(v.z) then return nil end
            return {x=v.x,y=v.y,z=v.z},{world_map_id=core.get_map_id(),
                instance_id=core.get_instance_id(),ui_map_id=core.game_ui.get_current_map_id()}
        end,
        write=function(name,xyz,c)
            core.create_data_folder("sylvanas_auto_leveler")
            core.create_data_folder("sylvanas_auto_leveler/routes")
            local path="sylvanas_auto_leveler/routes/"..name
            core.create_data_file(path..".route")
            core.write_data_file(path..".route",xyz)
            core.create_data_file(path..".context")
            core.write_data_file(path..".context",string.format("world_map_id=%d\ninstance_id=%d\nui_map_id=%d\nvalidated=false\n",c.world_map_id,c.instance_id,c.ui_map_id))
        end,
    }
end
return M
