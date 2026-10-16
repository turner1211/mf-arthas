-- Hardware movement input pauses automation; movement flags are deliberately
-- excluded because the navigation backend also sets those flags.
local M={}
function M.input(api)
 if api.typing and api.typing() then return false end
 if type(api.key)~="function" then return false end
 for _,key in ipairs({0x57,0x41,0x53,0x44,0x51,0x45,0x26,0x28,0x25,0x27,0x20}) do
  if api.key(key)==true then return true end
 end
 return api.key(0x01)==true and api.key(0x02)==true
end
function M.new()
 local self={active=false}
 function self:begin(now,p) self.active=true;self.last=now;self.position=p end
 function self:cancel() self.active=false;self.position=nil end
 function self:ready(now,p,input,blocked)
  if not self.active or not p then return false end
  local old=self.position
  if input or blocked or not old or math.sqrt((p.x-old.x)^2+(p.y-old.y)^2+(p.z-old.z)^2)>=0.5 then
   self.last=now;self.position={x=p.x,y=p.y,z=p.z};return false
  end
  return now-self.last>3
 end
 return self
end
return M
