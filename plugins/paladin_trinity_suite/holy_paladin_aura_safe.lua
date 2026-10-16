-- Tactix 12.1 Aura Compatibility Template
--
-- Purpose:
--   Provide one safe aura access layer for Project Sylvanas / IZI scripts after
--   Midnight 12.1 aura secrecy/protection changes.
--
-- Proven design principles carried forward from Tactix:
--   1) Never trust get_buffs()/get_debuffs() as the only aura source.
--   2) Prefer POSITIVE confirmation; a negative/empty result is not proof of absence.
--   3) Scan get_auras() as a fallback because secret/protected auras may still appear there.
--   4) Treat zero/absurd duration fields as UNKNOWN rather than "expired".
--   5) Use only CONFIRMED spell-cast callbacks to seed anti-spam floors/latches.
--   6) Single-target fallback state is keyed by target GUID.
--
-- This file intentionally contains no class rotation decisions.

local izi = require("common/izi_sdk")
local M = {}

local tracked = {}
local last_confirmed_cast = {}
local guid_latches = {}

local function now()
    if type(izi.now) == "function" then
        local ok, value = pcall(izi.now)
        if ok and type(value) == "number" then return value end
    end
    if core and type(core.time) == "function" then
        local ok, value = pcall(core.time)
        if ok and type(value) == "number" then return value end
    end
    return 0
end

local function safe_member(object, key)
    if not object then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function unit_guid(unit)
    if not unit then return nil end
    for _, method in ipairs({"get_guid", "guid"}) do
        local fn = safe_member(unit, method)
        if type(fn) == "function" then
            local ok, value = pcall(fn, unit)
            if ok and value ~= nil then return tostring(value) end
        end
    end
    local value = safe_member(unit, "guid")
    if value ~= nil and type(value) ~= "function" then return tostring(value) end
    return nil
end

local function aura_spell_id(aura)
    if type(aura) ~= "table" then return nil end
    return tonumber(aura.spell_id)
        or tonumber(aura.buff_id)
        or tonumber(aura.debuff_id)
        or tonumber(aura.id)
end

local function scan_list(list, spell_id)
    if type(list) ~= "table" then return false, nil end
    spell_id = tonumber(spell_id)
    for _, aura in pairs(list) do
        if aura_spell_id(aura) == spell_id then
            return true, aura
        end
    end
    return false, nil
end

local function call_list(unit, method)
    local fn = safe_member(unit, method)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, unit)
    if ok and type(value) == "table" then return value end
    return nil
end

-- Optional positive buff-manager lookup.
-- get_buff_data/get_debuff_data are methods proven in prior Tactix 12.1 work.
-- We only accept explicit positive state here; manager failure/false falls through.
local function manager_positive(unit, spell_id)
    if not unit then return false, nil end

    -- IZI's resolved aura cache is the documented first-party path. Accept
    -- only positive results; unknown secret-aura data continues through the
    -- compatibility fallbacks below.
    local aura_getter = safe_member(unit, "get_aura_data")
    if type(aura_getter) == "function" then
        local ok, data = pcall(aura_getter, unit, { spell_id })
        if ok and type(data) == "table"
            and (safe_member(data, "is_active") == true
                or safe_member(data, "active") == true) then
            return true, data
        end
    end
    local aura_up = safe_member(unit, "aura_up") or safe_member(unit, "has_aura")
    if type(aura_up) == "function" then
        local ok, active = pcall(aura_up, unit, spell_id)
        if ok and active == true then return true, nil end
    end

    -- Native PS objects publish these methods directly on the unit.
    for _, method in ipairs({"get_buff_data", "get_debuff_data"}) do
        local fn = safe_member(unit, method)
        if type(fn) == "function" then
            local ok, data = pcall(fn, unit, { spell_id })
            if ok and type(data) == "table" and safe_member(data, "is_active") == true then
                return true, data
            end
        end
    end

    local manager = nil
    local getter = safe_member(unit, "get_buff_manager")
    if type(getter) == "function" then
        local ok, value = pcall(getter, unit)
        if ok then manager = value end
    end
    if not manager then manager = safe_member(unit, "buff_manager") end
    if not manager then return false, nil end

    for _, method in ipairs({"get_buff_data", "get_debuff_data"}) do
        local fn = safe_member(manager, method)
        if type(fn) == "function" then
            local ok, data = pcall(fn, manager, spell_id)
            if ok and type(data) == "table" then
                if data.is_active == true or data.active == true then
                    return true, data
                end
                -- Do NOT interpret explicit false as proof that a protected aura is absent.
            end
        end
    end

    return false, nil
end

local function raw_positive(unit, spell_id)
    -- 12.1 preferred raw fallback.
    local found, aura = scan_list(call_list(unit, "get_auras"), spell_id)
    if found then return true, aura, "get_auras" end

    -- Legacy wrappers remain useful when they DO return positive data.
    found, aura = scan_list(call_list(unit, "get_buffs"), spell_id)
    if found then return true, aura, "get_buffs" end

    found, aura = scan_list(call_list(unit, "get_debuffs"), spell_id)
    if found then return true, aura, "get_debuffs" end

    local all = call_list(unit, "get_all_buffs")
    found, aura = scan_list(all, spell_id)
    if found then return true, aura, "get_all_buffs" end

    return false, nil, nil
end

local function sane_remaining(aura)
    if type(aura) ~= "table" then return nil end

    -- Native buff-manager remaining/expiry values use the engine millisecond
    -- clock. Legacy wrappers below use explicit second-based field names.
    if safe_member(aura, "is_active") == true then
        local ms = tonumber(safe_member(aura, "remaining"))
        if ms and ms > 0 and ms < 3600000 then return ms / 1000 end
    end
    local expiry_ms = tonumber(safe_member(aura, "expire_time"))
    if expiry_ms and expiry_ms > 0 and core and type(core.game_time) == "function" then
        local ok, clock_ms = pcall(core.game_time)
        local ms = ok and type(clock_ms) == "number" and expiry_ms - clock_ms or nil
        if ms and ms > 0 and ms < 3600000 then return ms / 1000 end
    end

    for _, key in ipairs({"remaining", "time_remaining", "remaining_time"}) do
        local value = tonumber(aura[key])
        if value and value > 0 and value < 3600 then return value end
    end

    for _, key in ipairs({"expiration_time", "expires_at", "expiration"}) do
        local expires = tonumber(aura[key])
        if expires and expires > 0 then
            local remaining = expires - now()
            if remaining > 0 and remaining < 3600 then return remaining end
        end
    end

    -- Zero, negative, missing, or absurd secret/protected values are UNKNOWN.
    return nil
end

-- Register an aura/spell that should receive confirmed-cast fallback handling.
-- opts:
--   cast_floor = seconds after a confirmed cast during which presence may be
--                considered true even if aura APIs hide it (good for self/group buffs).
--   guid_latch = seconds for a confirmed target-specific anti-spam latch.
function M.track(spell_id, opts)
    spell_id = tonumber(spell_id)
    if not spell_id then return end
    opts = type(opts) == "table" and opts or {}
    tracked[spell_id] = {
        cast_floor = math.max(0, tonumber(opts.cast_floor) or 0),
        guid_latch = math.max(0, tonumber(opts.guid_latch) or 0),
    }
end

function M.untrack(spell_id)
    tracked[tonumber(spell_id) or -1] = nil
end

function M.since_last_confirmed_cast(spell_id)
    local stamp = last_confirmed_cast[tonumber(spell_id) or -1]
    if not stamp then return math.huge end
    return math.max(0, now() - stamp)
end

local function set_guid_latch(spell_id, guid, seconds)
    if not guid or not seconds or seconds <= 0 then return end
    spell_id = tonumber(spell_id)
    guid_latches[spell_id] = guid_latches[spell_id] or {}
    guid_latches[spell_id][guid] = now() + seconds
end

function M.guid_latch_active(unit, spell_id)
    local guid = unit_guid(unit)
    spell_id = tonumber(spell_id)
    if not guid or not spell_id then return false end
    local expiry = guid_latches[spell_id] and guid_latches[spell_id][guid]
    if not expiry then return false end
    if expiry <= now() then
        guid_latches[spell_id][guid] = nil
        return false
    end
    return true
end

-- Call this ONLY from PS's confirmed spell-cast callback.
-- Current Tactix runtime uses core.register_on_spell_cast_callback(function(data) ... end)
-- where data is a table containing data.spell_id and, when available, data.target.
function M.on_spell_cast(data)
    if type(data) ~= "table" then return end
    local spell_id = tonumber(data.spell_id)
    local config = spell_id and tracked[spell_id] or nil
    if not config then return end

    last_confirmed_cast[spell_id] = now()

    if config.guid_latch > 0 then
        local guid = unit_guid(data.target)
        if guid then set_guid_latch(spell_id, guid, config.guid_latch) end
    end
end

-- Positive/compatibility presence query.
-- Returns: active:boolean, source:string, aura:table|nil
function M.present(unit, spell_id, opts)
    spell_id = tonumber(spell_id)
    if not unit or not spell_id then return false, "invalid", nil end
    opts = type(opts) == "table" and opts or {}

    local active, aura = manager_positive(unit, spell_id)
    if active then return true, "buff_manager", aura end

    local source
    active, aura, source = raw_positive(unit, spell_id)
    if active then return true, source, aura end

    local config = tracked[spell_id] or {}
    local cast_floor = tonumber(opts.cast_floor)
    if cast_floor == nil then cast_floor = tonumber(config.cast_floor) or 0 end
    if cast_floor > 0 and M.since_last_confirmed_cast(spell_id) < cast_floor then
        return true, "confirmed_cast_floor", nil
    end

    local use_latch = opts.use_guid_latch
    if use_latch == nil then use_latch = (tonumber(config.guid_latch) or 0) > 0 end
    if use_latch and M.guid_latch_active(unit, spell_id) then
        return true, "confirmed_guid_latch", nil
    end

    return false, "not_confirmed", nil
end

-- Presence attributed to a specific caster. A propagated aura on another
-- Paladin is not proof that they are the one supplying it.
function M.present_from(unit, spell_id, caster)
    local owner = unit_guid(caster)
    if not owner or not unit then return false end
    local function owned(aura)
        return type(aura) == "table" and aura_spell_id(aura) == tonumber(spell_id)
            and unit_guid(safe_member(aura, "caster")) == owner
    end
    for _, method in ipairs({"get_buff_data", "get_debuff_data"}) do
        local fn = safe_member(unit, method)
        if type(fn) == "function" then
            local ok, data = pcall(fn, unit, { spell_id })
            if ok and safe_member(data, "is_active") == true and owned(data) then return true end
        end
    end
    for _, method in ipairs({"get_auras", "get_buffs", "get_debuffs", "get_all_buffs"}) do
        for _, aura in pairs(call_list(unit, method) or {}) do
            if owned(aura) then return true end
        end
    end
    return false
end

-- Remaining duration is deliberately separate from presence.
-- A protected aura can be PRESENT while its exact duration is UNKNOWN.
function M.remaining(unit, spell_id)
    if not unit or not spell_id then return nil, "invalid" end

    local active, aura = manager_positive(unit, spell_id)
    if active then
        local value = sane_remaining(aura)
        if value then return value, "buff_manager" end
    end

    local found, raw_aura, source = raw_positive(unit, spell_id)
    if found then
        local value = sane_remaining(raw_aura)
        if value then return value, source end
        return nil, source .. "_secret_or_unknown_duration"
    end

    return nil, "not_visible"
end

function M.clear()
    tracked = {}
    last_confirmed_cast = {}
    guid_latches = {}
end

return M
