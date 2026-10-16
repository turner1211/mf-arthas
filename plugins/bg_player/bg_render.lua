-- UI failures recover independently of gameplay and never change the controller's enabled state.
local Debug=require("bg_debug")
local R={};R.__index=R
function R.new(debugger)
 return setmetatable({debugger=debugger,kinds={},read_failures=0,read_log_at={}},R)
end
local function record(self,kind,message,now)
 if self.debugger then pcall(self.debugger.add,self.debugger,kind,message,now) end
end
function R:read(name,now,fn,fallback)
 local ok,value=pcall(fn)
 if ok then return value end
 self.read_failures=self.read_failures+1
 self.last_read_error=(name..": "..Debug.trace(value)):sub(1,4096)
 if now>=(self.read_log_at[name] or 0) then
  self.read_log_at[name]=now+2;record(self,"render_read_error",self.last_read_error,now)
 end
 return fallback
end
function R:run(kind,now,fn)
 local state=self.kinds[kind]
 if not state then state={failures=0,retry_at=0};self.kinds[kind]=state end
 if now<state.retry_at then return false,"render_cooling_down" end
 local ok,err=xpcall(fn,Debug.trace)
 if not ok then
  state.failures=state.failures+1;state.retry_at=now+2;state.last_error=tostring(err):sub(1,4096)
  record(self,"render_error",kind..": "..state.last_error,now)
  return false,state.last_error
 end
 state.retry_at=0
 return true
end
function R:report(now)
 local report={read_failures=self.read_failures,last_read_error=self.last_read_error}
 for _,kind in ipairs({"menu","window"}) do
  local state=self.kinds[kind] or {failures=0,retry_at=0}
  report[kind]={failures=state.failures,retry_in=math.max(0,state.retry_at-now),last_error=state.last_error}
 end
 return report
end
return R
