-- Protected host API adapter. Sylvanas builds have exposed several manager
-- accessors as both object methods and strict static functions.
local M={}
function M.call(owner,method,...)
    local fn=owner and owner[method]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,owner,...);if ok then return value end
    ok,value=pcall(fn,...);if ok then return value end;return nil
end
-- Argument-taking host APIs are normally static. Preserve their argument order
-- first, then retry as an owner method only when the static call raises.
function M.static(owner,method,...)
    local ok,value=M.try_static(owner,method,...)
    if ok then return value end
    return nil
end
function M.try_static(owner,method,...)
    local fn=owner and owner[method]
    if type(fn)~="function" then return false,nil end
    local ok,value=pcall(fn,...);if ok then return true,value end
    ok,value=pcall(fn,owner,...);return ok,value
end
function M.manager(method,...) return M.call(core and core.object_manager,method,...) end
function M.manager_table(method,...)
    local value=M.manager(method,...)
    return type(value)=="table" and value or {}
end
return M
