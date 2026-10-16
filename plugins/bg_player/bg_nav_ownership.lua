-- Detect when another consumer replaces the shared Sentinel destination while
-- the battleground controller still owns an active movement request.
local O={};O.__index=O
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function point(value)
 local ok,x,y,z=pcall(function() return value and value.x,value and value.y,value and value.z end)
 if ok and finite(x) and finite(y) and finite(z) then return {x=x,y=y,z=z} end
end
function O.new(limit) return setmetatable({limit=tonumber(limit) or 3,claims=0,count=0},O) end
function O:reset(clear_budget) self.signature=nil;self.count=0;if clear_budget then self.claims=0 end end
function O:observe(expected,actual,state)
 local wanted,live=point(expected),point(actual)
 if tostring(state or "")~="navigating" or not wanted or not live then self:reset(false);return false end
 local signature=string.format("%.1f:%.1f:%.1f",wanted.x,wanted.y,wanted.z)
 if signature~=self.signature then self.signature=signature;self.count=0 end
 local horizontal=math.sqrt((wanted.x-live.x)^2+(wanted.y-live.y)^2)
 local vertical=math.abs(wanted.z-live.z)
 if horizontal<=8 and vertical<=12 then self.count=0;return false end
 self.count=self.count+1
 if self.count>=2 and self.claims<self.limit then
  self.count=0;self.claims=self.claims+1
  return true,{horizontal=horizontal,vertical=vertical,attempt=self.claims}
 end
 return false
end
return O
