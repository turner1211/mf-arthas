-- Explicit, selected-target-only training support for city practice dummies.
local M={}
local helper_ok,UnitHelper=pcall(require,"common/utility/unit_helper")
-- Stable IDs are a fallback for localized clients whose names do not contain
-- the English word "dummy". Framework dummy classification remains primary.
local known={
    [32667]=true,[31146]=true,[87318]=true,[87322]=true,[87329]=true,
    [113647]=true,[113673]=true,[174565]=true,[175452]=true,
    [225978]=true,[243167]=true,[243212]=true,[248169]=true}
local healing={[243212]=true}
local function call(o,key,...)
    if not o or type(o[key])~="function" then return nil end
    local ok,value=pcall(o[key],o,...); if ok then return value end
end
local function distance(a,b)
    local x,y=call(a,"get_position"),call(b,"get_position")
    if not x or not y then return math.huge end
    return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2)
end
function M.is_dummy(unit)
    if call(unit,"is_valid")~=true or call(unit,"is_dead")==true or call(unit,"is_player")==true then return false end
    if call(unit,"is_dummy")==true then return true end
    if helper_ok and UnitHelper and call(UnitHelper,"is_dummy",unit)==true then return true end
    local id=tonumber(call(unit,"get_npc_id") or call(unit,"get_entry_id"))
    if id and known[id] then return true end
    local name=call(unit,"get_name");local title=call(unit,"get_sub_name") or call(unit,"get_title")
    local text=(tostring(name or "").." "..tostring(title or "")):lower()
    return text:find("training dummy",1,true)~=nil or text:find("tanking dummy",1,true)~=nil
        or text:find("healing dummy",1,true)~=nil or text:find("practice dummy",1,true)~=nil
end
function M.is_healing(unit)
    if not M.is_dummy(unit) then return false end
    local id=tonumber(call(unit,"get_npc_id") or call(unit,"get_entry_id"));if id and healing[id] then return true end
    local text=(tostring(call(unit,"get_name") or "").." "..tostring(call(unit,"get_sub_name") or call(unit,"get_title") or "")):lower()
    return text:find("healing",1,true)~=nil
end
function M.selected(player,target,max_range,allow_healing)
    return M.is_dummy(target) and call(player,"get_target")==target
        and (call(player,"can_attack",target)==true or allow_healing and M.is_healing(target))
        and distance(player,target)<=(max_range or 5)
end
return M
