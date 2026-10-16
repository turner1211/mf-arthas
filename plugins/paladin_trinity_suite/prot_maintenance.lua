local Settings = require("prot_settings")
local Host = require("prot_host")
local M = {}

local merchant_open = false
local next_repair_check = 0
local next_merchant_probe = 0
local repair_stage = 0

local function repair_cost()
    return tonumber(Host.static(core and core.inventory,"get_total_repair_cost")) or 0
end

local function can_repair()
    return Host.static(core and core.inventory,"can_merchant_repair")==true
end

local function on_event(event_name)
    if event_name == "MERCHANT_SHOW" then
        local opened_at = core.time()
        merchant_open = true
        repair_stage = 0
        next_repair_check = opened_at + 0.15
    elseif event_name == "MERCHANT_CLOSED" or event_name == "PLAYER_LEAVING_WORLD" then
        merchant_open = false
        repair_stage = 0
        next_repair_check = 0
    end
end

local function update()
    if not Settings.on("auto_repair") then return end
    local now = core.time()
    -- Reloading the plugin while a repair merchant is already open does not
    -- replay MERCHANT_SHOW. A positive repair-capability read recovers that case.
    if not merchant_open then
        if now < next_merchant_probe then return end
        next_merchant_probe = now + 0.5
        if not can_repair() then return end
        merchant_open, repair_stage, next_repair_check = true, 0, now + 0.15
    end
    if now < next_repair_check then return end
    if not can_repair() then merchant_open=false; repair_stage=0; return end

    local cost = repair_cost()
    if cost <= 0 then
        Settings.maintenance_status = repair_stage > 0 and "Items repaired" or "No repairs needed"
        next_repair_check = math.huge
        return
    end

    if repair_stage == 0 then
        -- Try the guild allowance first. The next pass checks the remaining
        -- repair cost and falls back to personal gold if guild repair failed.
        Host.static(core and core.input,"repair_all_items",true)
        repair_stage = 1
        next_repair_check = core.time() + 0.6
        Settings.maintenance_status = "Repairing with guild funds"
        return
    end

    if repair_stage == 1 then
        Host.static(core and core.input,"repair_all_items",false)
        repair_stage = 2
        next_repair_check = core.time() + 0.75
        Settings.maintenance_status = string.format("Using personal gold • %.2fg", cost / 10000)
        return
    end

    Settings.maintenance_status = string.format("Repair incomplete • %.2fg remaining", cost / 10000)
    next_repair_check = math.huge
end

local function safe(callback,label)
    return function(...)
        local ok,err=pcall(callback,...)
        if not ok then Settings.maintenance_status=label..": runtime API unavailable • "..tostring(err) end
    end
end

M.on_event=safe(on_event,"Repair event")
M.update=safe(update,"Auto repair")
core.register_on_game_event_callback(M.on_event)
core.register_on_update_callback(M.update)
return M
