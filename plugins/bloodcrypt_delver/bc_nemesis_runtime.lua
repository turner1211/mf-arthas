local Data=require("bc_nemesis")
local M={};M.__index=M
function M.new() return setmetatable({memory=Data.new_memory(),attempt=0,phase="Idle",seen={}},M) end
function M:reset() self.attempt=self.memory:reset();self.phase="Idle";self.seen={};return self.attempt end
function M:update(instance,health,combat,hard)
 local e=Data.encounters[instance];if not e then self.phase="Not Nemesis";return self.phase end
 if not combat then if self.phase~="Idle" then self:reset() end;return self.phase end
 if self.phase=="Idle" then self:reset();self.phase="Engaged" end
 if type(health)=="number" then
  for i,threshold in ipairs(e.thresholds) do if health<=threshold and not self.seen[i] then
   self.seen[i]=true
   if instance==3079 then self.memory:begin(i,hard);self.phase="Observe safe quadrants: intermission "..i
   else self.phase="Nullaeus intermission "..i..": live Evade geometry required" end
  end end
 end
 return self.phase
end
function M:observe(index,covered)
 local q,why=Data.safe_quadrant(covered);if not q then return false,why end
 return self.memory:observe(self.attempt,index,q)
end
function M:replay(index,anchors)
 local q,why=self.memory:replay(self.attempt,index);if not q then return nil,why end
 return anchors and anchors[q] or nil,"Arena anchors unavailable"
end
return M
