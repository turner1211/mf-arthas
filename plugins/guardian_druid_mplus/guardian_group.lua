local M={}
local function call(unit,key,...)
    if not unit or type(unit[key])~="function" then return nil end
    local ok,value=pcall(unit[key],unit,...); if ok then return value end
end
local function role(value)
    if type(value)=="number" then return ({[0]="TANK",[1]="HEALER",[2]="DAMAGER"})[value] end
    if type(value)=="string" then
        value=value:upper()
        if value=="DPS" or value=="DAMAGE" then value="DAMAGER" end
        if value=="TANK" or value=="HEALER" or value=="DAMAGER" then return value end
    end
end
function M.roster(player)
    local result,seen={},{}
    local function add(value)
        local entry=type(value)=="table" and value.object and value or nil
        local unit=entry and entry.object or value
        if not unit then return end
        local key=tostring(call(unit,"get_guid") or unit)
        local item=seen[key]
        if not item then item={object=unit}; seen[key]=item; result[#result+1]=item end
        -- Merge metadata before consumers deduplicate units. Explicit offline
        -- evidence wins over an unannotated duplicate object.
        if entry and entry.is_online==false then item.is_online=false end
        item.role=role(call(unit,"get_group_role")) or role(entry and entry.role) or item.role
    end
    add(player)
    for _,key in ipairs({"get_party_members","get_party_frames"}) do
        local fn=core.object_manager and core.object_manager[key]
        if type(fn)=="function" then
            local ok,list=pcall(fn)
            if ok and type(list)=="table" then for _,value in pairs(list) do add(value) end end
        end
    end
    return result
end
function M.role(unit)
    local native=role(call(unit,"get_group_role")); if native then return native end
    local wanted=tostring(call(unit,"get_guid") or unit)
    for _,entry in ipairs(M.roster()) do
        if tostring(call(entry.object,"get_guid") or entry.object)==wanted then return entry.role end
    end
end
return M
