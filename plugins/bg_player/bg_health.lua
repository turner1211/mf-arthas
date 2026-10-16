-- Bounded runtime recovery; a successful frame alone does not clear repeated faults.
local H={};H.__index=H
function H.new() return setmetatable({failures=0,retries=0,locked=false,retry_at=0},H) end
function H:reset()
 self.failures=0;self.locked=false;self.retry_at=0;self.healthy_since=nil;self.last_error=nil
end
function H:ready(now) return not self.locked and now>=self.retry_at end
function H:fail(now,err)
 self.failures=self.failures+1;self.healthy_since=nil;self.last_error=tostring(err)
 if self.failures>=4 then self.locked=true;return "recovery_attention_required" end
 self.retries=self.retries+1;self.retry_at=now+2^self.failures
 return "recovering_runtime_error"
end
function H:success(now)
 if self.failures==0 then return end
 self.healthy_since=self.healthy_since or now
 if now-self.healthy_since>=30 then self.failures=0;self.last_error=nil;self.retry_at=0 end
end
function H:report(now)
 return {failures=self.failures,retries=self.retries,locked=self.locked,
  retry_in=math.max(0,self.retry_at-now),last_error=self.last_error}
end
return H
