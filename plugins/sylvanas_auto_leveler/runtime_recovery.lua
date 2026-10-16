-- Bounded same-step restart policy for unexpected runtime exceptions.
local M={};M.__index=M
function M.new(options)
 local o=options or {}
 return setmetatable({max=o.max or 3,window=o.window or 60,stable=o.stable or 120,failures={}},M)
end
function M:reset() self.failures={};self.last_failure=nil end
function M:failure(now)
 local kept={}
 for _,stamp in ipairs(self.failures) do if now-stamp<=self.window then kept[#kept+1]=stamp end end
 kept[#kept+1]=now;self.failures=kept;self.last_failure=now
 if #kept>self.max then return nil,#kept end
 return math.min(15,2^(#kept-1)),#kept
end
function M:success(now)
 if self.last_failure and now-self.last_failure>=self.stable then self:reset();return true end
 return false
end
return M
