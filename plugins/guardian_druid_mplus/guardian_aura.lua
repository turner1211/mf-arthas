-- Adapted from the supplied Tactix secret-aura template's positive-evidence
-- approach. Uses the installed PS API: manager durations are milliseconds.
local M = {}
local casts, targets = {}, {}
function M.guid(unit)
    if not unit then return nil end
    local ok, value = pcall(function() return unit:get_guid() end)
    if ok and value then return tostring(value) end
end
function M.confirm(data, player)
    if type(data) ~= "table" or not player then return end
    local caster, owner = M.guid(data.caster), M.guid(player)
    -- Unknown or other casters must never seed local-player confidence.
    if not caster or not owner or caster ~= owner then return end
    local id = tonumber(data.spell_id)
    if not id then return end
    casts[id] = core.time()
    local guid = M.guid(data.target)
    if guid then
        targets[id] = targets[id] or {}
        targets[id][guid] = core.time()
    end
    for spell, entries in pairs(targets) do
        for key, stamp in pairs(entries) do
            if core.time() - stamp > 60 then entries[key] = nil end
        end
        if next(entries) == nil then targets[spell] = nil end
    end
end
function M.since(id, unit)
    local stamp
    if unit then
        local guid = M.guid(unit)
        stamp = guid and targets[id] and targets[id][guid]
    else stamp = casts[id] end
    return stamp and core.time()>=stamp and (core.time()-stamp) or math.huge
end
local function remaining(data, manager)
    local value = manager and tonumber(data.remaining) or nil
    if value and value > 0 and value < 3600000 then return value / 1000 end
    local expiry = tonumber(data.expire_time)
    if expiry and expiry > 0 then
        local seconds = (expiry - core.game_time()) / 1000
        if seconds > 0 and seconds < 3600 then return seconds end
    end
    return nil -- zero/hidden/absurd values do not prove expiration
end
local function field(data,key)
    local ok,value=pcall(function() return data[key] end)
    if ok then return value end
end
local function number(data,key)
    local ok,value=pcall(function() return tonumber(data[key]) end)
    if ok then return value end
end
local function proven_expired(aura)
    local expiry=number(aura,"expire_time")
    return expiry and expiry>0 and expiry<=core.game_time() or false
end
local function aura_id(aura)
    return number(aura,"buff_id") or number(aura,"spell_id")
        or number(aura,"debuff_id") or number(aura,"id")
end
local function safe_remaining(data,manager)
    local ok,value=pcall(remaining,data,manager)
    return ok and value or nil
end
function M.read(unit, id, debuff, owner)
    if not unit then return false, nil end
    local ok, active, duration = pcall(function()
        local method = debuff and "get_debuff_data" or "get_buff_data"
        local data = unit[method](unit, { id })
        if data and data.is_active == true and (not owner or M.guid(data.caster) == M.guid(owner)) then
            return true, safe_remaining(data, true)
        end
        return false, nil
    end)
    if ok and active then return active, duration end
    for _, method in ipairs({ "get_auras", debuff and "get_debuffs" or "get_buffs" }) do
        local success, found, seconds = pcall(function()
            for _, aura in pairs(unit[method](unit) or {}) do
                if aura_id(aura) == id and not proven_expired(aura) and (not owner or M.guid(field(aura,"caster")) == M.guid(owner)) then
                    return true, safe_remaining(aura, false)
                end
            end
            return false, nil
        end)
        if success and found then return true, seconds end
    end
    return false, nil -- means unconfirmed, not proven absent
end
function M.stacks(unit, id, debuff, owner)
    if not unit then return nil end
    local ok, count = pcall(function()
        local method = debuff and "get_debuff_data" or "get_buff_data"
        local data = unit[method](unit, { id })
        if data and data.is_active == true and (not owner or M.guid(data.caster) == M.guid(owner)) then
            return number(data,"stacks") or number(data,"count")
        end
    end)
    if ok and count and count>0 then return count end
    for _, method in ipairs({ "get_auras", debuff and "get_debuffs" or "get_buffs" }) do
        local success, raw_count = pcall(function()
            for _, aura in pairs(unit[method](unit) or {}) do
                if aura_id(aura) == id and not proven_expired(aura) and (not owner or M.guid(field(aura,"caster")) == M.guid(owner)) then
                    return number(aura,"count") or number(aura,"stacks")
                end
            end
        end)
        if success and raw_count and raw_count>0 then return raw_count end
    end
    return nil -- hidden or absent; callers must not treat this as a confirmed zero
end
function M.reset() casts, targets = {}, {} end
function M.is_current(data)
    return data~=nil and field(data,"is_active")~=false and not proven_expired(data)
end
function M.id(data) return data and aura_id(data) or nil end
return M
