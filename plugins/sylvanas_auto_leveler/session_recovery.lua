-- Periodic atomic last-known-state snapshot for crash/disconnect diagnosis.
local Snapshot=require("data_snapshot")
local M={};M.__index=M
function M.new(api,interval)
 return setmetatable({api=api,interval=interval or 10,next_write=0,error=nil,failures=0,next_report=0},M)
end
function M:due(now) return now>=self.next_write end
function M:write(now,text,force)
 if not force and now<self.next_write then return false,"throttled" end
 self.next_write=now+self.interval
 local ok,result=pcall(function()
  self.api.create_data_folder("sylvanas_auto_leveler")
  self.api.create_data_folder("sylvanas_auto_leveler/logs")
  return Snapshot.write(self.api,"sylvanas_auto_leveler/logs/recovery_state.txt",text)
 end)
 if ok and result~=false then self.error=nil;self.failures=0;self.next_report=0;return true end
 self.failures=self.failures+1
 self.next_write=now+math.min(self.interval,2^math.min(self.failures-1,4))
 self.error=tostring(ok and "snapshot_write_returned_false" or result);return false,self.error
end
function M:should_report(now)
 if now<self.next_report then return false end
 self.next_report=now+30;return true
end
return M
