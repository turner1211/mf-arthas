-- Adaptive logic budget shared from the combat plugins' proven pattern.
local P={};P.__index=P
local default_clock=os and os.clock or function() return 0 end
function P.new(clock) return setmetatable({tier=0,slow=0,last_ms=0,average_ms=0,max_ms=0,spikes=0,samples=0,clock=clock or default_clock,last_journal=nil,
 match_active=false,match_samples=0,match_spikes=0,match_max_ms=0},P) end
function P:begin() return self.clock() end
function P:finish(started)
 local ms=math.max(0,(self.clock()-started)*1000);self.last_ms=ms;self.samples=self.samples+1
 self.average_ms=self.samples==1 and ms or self.average_ms+(ms-self.average_ms)*0.1
 self.max_ms=math.max(self.max_ms,ms)
 if ms>=8 then self.slow=self.slow+1;self.spikes=self.spikes+1 else self.slow=math.max(0,self.slow-0.1) end
 local previous=self.tier
 if self.slow>=5 then self.tier=2 elseif self.slow>=2 then self.tier=1 elseif self.slow<=0.5 then self.tier=0 end
 return ms,self.tier~=previous
end
function P:interval(combat)
 if combat then return self.tier==2 and 0.20 or self.tier==1 and 0.14 or 0.10 end
 return self.tier==2 and 0.12 or self.tier==1 and 0.08 or 0.05
end
function P:journal_due(now,active,interval)
 now=tonumber(now);interval=math.max(10,tonumber(interval) or 60)
 if active~=true or type(now)~="number" or now~=now or self.samples<1 then return false end
 if not self.last_journal or now<self.last_journal then self.last_journal=now;return false end
 if now-self.last_journal<interval then return false end
 self.last_journal=now;return true
end
function P:match_tick(active)
 if active==true then
  if not self.match_active then
   self.match_active=true;self.match_samples=0;self.match_spikes=0;self.match_max_ms=0
  end
  self.match_samples=self.match_samples+1
  self.match_max_ms=math.max(self.match_max_ms,self.last_ms or 0)
  if (self.last_ms or 0)>=8 then self.match_spikes=self.match_spikes+1 end
  return nil
 end
 if not self.match_active then return nil end
 local result={samples=self.match_samples,spikes=self.match_spikes,max_ms=self.match_max_ms,
  spike_rate=self.match_samples>0 and self.match_spikes/self.match_samples or 0}
 self.match_active=false;self.match_samples=0;self.match_spikes=0;self.match_max_ms=0
 return result
end
function P:report() return string.format("tier=%d / last %.2fms / avg %.2fms / max %.2fms / spikes %d / samples %d",
 self.tier,self.last_ms,self.average_ms,self.max_ms,self.spikes,self.samples) end
return P
