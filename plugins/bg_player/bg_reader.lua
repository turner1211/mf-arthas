-- Isolated circuit breaker for read-only objective observations.
local R={};R.__index=R
function R.new() return setmetatable({failures=0,retries=0,retry_at=0,state="closed"},R) end
function R:reset()
 self.failures=0;self.retry_at=0;self.state="closed";self.last_error=nil;self.healthy_since=nil
end
function R:read(fn,now)
 if now<self.retry_at then return nil,"objective_provider_cooling_down" end
 local probe=self.state=="open"
 if probe then self.state="half_open" end
 local ok,data,reason=pcall(fn)
 if not ok or type(data)~="table" then
  self.failures=self.failures+1;self.retries=self.retries+1;self.healthy_since=nil
  self.last_error=tostring(ok and (reason or "invalid_snapshot") or data)
  local delay=self.failures>=4 and 30 or 2^self.failures
  self.retry_at=now+delay;self.state=self.failures>=4 and "open" or "backoff"
  return nil,"objective_provider_cooling_down"
 end
 self.state="closed";self.retry_at=0
 self.healthy_since=self.healthy_since or now
 if probe or now-self.healthy_since>=30 then self.failures=0;self.last_error=nil end
 return data
end
function R:report(now)
 return {state=self.state,failures=self.failures,retries=self.retries,
  retry_in=math.max(0,self.retry_at-now),last_error=self.last_error}
end
return R
