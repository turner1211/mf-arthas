-- Keep the existing local recovery helper informed while waiting for service.
local M={last_error=-100,last_tick=-100,enabled=nil}
function M.tick(enabled,now,bootstrap,log)
 if type(bootstrap)~="table" or type(bootstrap.tick)~="function" then return false end
 local requested=enabled==true
 -- The installed helper currently refreshes/release-checks on every call.
 -- Bound the compatibility bridge to one hertz and always pass transitions.
 if M.enabled==requested and now-M.last_tick<1 then return true end
 M.enabled=requested;M.last_tick=now
 local ok,result=pcall(bootstrap.tick,"auto_leveler",requested)
 if (not ok or result==false) and now-M.last_error>=30 then
  M.last_error=now
  if log then log("navigation_startup_signal_failed",{reason=ok and "writer_refused" or tostring(result)}) end
 end
 return ok and result~=false
end
return M
