-- Read optional Sentinel diagnostics without allowing a telemetry failure to
-- interrupt movement or enter the controller-wide runtime recovery circuit.
local T={};T.__index=T
function T.new(log,time)
 return setmetatable({log=log,time=time,last={}},T)
end
function T:read(client,method)
 if client==nil then return nil end
 local found,reader=pcall(function() return client[method] end)
 if not found or type(reader)~="function" then return nil end
 local ok,value=pcall(reader,client)
 if ok then return value end
 local clock_ok,clock=pcall(function() return type(self.time)=="function" and self.time() or 0 end)
 local now=clock_ok and tonumber(clock) or 0
 now=now and now==now and now or 0
 if not self.last[method] or now<self.last[method] or now-self.last[method]>=30 then
  self.last[method]=now
  if type(self.log)=="function" then self.log("sentinel_telemetry_error:"..method..":"..tostring(value)) end
 end
 return nil
end
return T
