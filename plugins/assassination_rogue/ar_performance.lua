-- Adaptive runtime budget. Slow samples temporarily reduce expensive scan rates.
local M={tier=0,slow=0,total=0,last_ms=0,peak_ms=0}
-- Project Sylvanas does not guarantee the Lua os library. core.game_time is
-- the host's millisecond monotonic clock and therefore measures real stalls;
-- core.time remains a safe seconds-based fallback on older cores.
local function clock_ms()
 if core and type(core.game_time)=='function' then
  local ok,v=pcall(core.game_time);if ok and type(v)=='number' then return v end
 end
 if core and type(core.time)=='function' then
  local ok,v=pcall(core.time);if ok and type(v)=='number' then return v*1000 end
 end
 return 0
end
function M.begin() return clock_ms() end
function M.finish(start)
 local old=M.tier;local ms=math.max(0,clock_ms()-start);M.last_ms=ms;M.peak_ms=math.max(M.peak_ms*0.98,ms);M.total=M.total+1
 if ms>=8 then M.slow=math.min(20,M.slow+1) else M.slow=math.max(0,M.slow-0.2) end
 if M.slow>=5 then M.tier=2 elseif M.slow>=2 then M.tier=1 elseif M.slow<=0.5 then M.tier=0 end
 return ms,old~=M.tier
end
function M.update_interval() return M.tier==2 and 0.14 or M.tier==1 and 0.10 or 0.08 end
function M.scan_interval() return M.tier==2 and 1.0 or M.tier==1 and 0.75 or 0.5 end
function M.visual_interval() return M.tier==2 and 0.25 or M.tier==1 and 0.16 or 0.1 end
function M.log_interval() return M.tier==2 and 3 or M.tier==1 and 2 or 1.5 end
function M.status() return string.format('tier=%d last=%.2fms peak=%.2fms slow=%.1f',M.tier,M.last_ms,M.peak_ms,M.slow) end
return M
