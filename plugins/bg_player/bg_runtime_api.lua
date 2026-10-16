local M={}
local los_cache=setmetatable({}, {__mode="k"})
local function manager_call(method,...)
 local manager=core and core.object_manager
 if not manager or type(manager[method])~="function" then return nil end
 local fn=manager[method];local ok,value=pcall(fn,...);if ok then return value end
 ok,value=pcall(fn,manager,...);return ok and value or nil
end
function M.player() return manager_call("get_local_player") end
function M.objects()
 local rows=manager_call("get_all_objects")
 if type(rows)~="table" then rows=manager_call("get_visible_objects") end
 return type(rows)=="table" and rows or {}
end
function M.los(from,to)
 if not from or not to or not core or not core.graphics or type(core.graphics.is_line_of_sight)~="function" then return nil end
 local ok,now=pcall(core.game_time);now=ok and tonumber(now) or nil
 if not now then ok,now=pcall(core.time);now=(ok and tonumber(now) or 0)*1000 end
 local targets=los_cache[from]
 if not targets then targets=setmetatable({}, {__mode="k"});los_cache[from]=targets end
 local hit=targets[to];if hit and now-hit.at<=60 then return hit.value end
 local ran,value=pcall(core.graphics.is_line_of_sight,from,to);if not ran then return nil end
 value=value==true;targets[to]={at=now,value=value};return value
end
function M.clear_los_cache() los_cache=setmetatable({}, {__mode="k"}) end
return M
