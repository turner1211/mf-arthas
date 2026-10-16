-- Narrow, protected access to loader-managed object-manager reads.
-- Keep this adapter owned by the Auto Leveler so other plugins cannot share
-- its runtime state or silently change its failure behavior.
local M={}

local function manager()
    return core and core.object_manager
end

local function call(name,fallback,...)
    local owner=manager()
    local fn=owner and owner[name]
    if type(fn)~="function" then return fallback end
    local ok,value=pcall(fn,...)
    if ok then return value end
    -- Some loader builds expose object-manager functions as methods.
    ok,value=pcall(fn,owner,...)
    return ok and value or fallback
end

function M.player()
    local value=call("get_local_player",nil)
    return value
end

function M.objects()
    local value=call("get_all_objects",{})
    return type(value)=="table" and value or {}
end

function M.mouseover()
    return call("get_mouse_over_object",nil)
end

return M
