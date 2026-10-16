-- Defer initialization until Holy is positively identified. No Holy module or
-- GUI is loaded on other classes/specs or while character data is unavailable.
local attempted, next_probe = false, -math.huge
local function is_holy_ready()
    local player = core.object_manager and core.object_manager.get_local_player
        and core.object_manager.get_local_player()
    if not player or not player:is_valid() then return false end
    local enums = require("common/enums")
    local class = player:get_class()
    if not enums.class_id or class ~= enums.class_id.PALADIN then return false end
    local specs = enums.class_spec_id
    local expected = specs and specs.spec_enum and specs.spec_enum.HOLY_PALADIN
    if not expected then return false end
    local raw = player.get_specialization_id and player:get_specialization_id()
        or (core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id())
    if raw == expected then return true end
    return specs.get_specialization_enum and specs.get_specialization_enum(class, raw) == expected
end
local function bootstrap()
    if attempted then return end
    local time_ok, now = pcall(core.time)
    now = time_ok and type(now) == "number" and now or 0
    if now < next_probe - 1 then next_probe = now end
    if now < next_probe then return end
    next_probe = now + 1
    local ok, ready = pcall(is_holy_ready)
    if not ok or ready ~= true then return end
    -- Do not repeat a partially failed module's callback registration.
    attempted = true
    local loaded, err = pcall(function() require("holy_paladin_mplus").main() end)
    if not loaded and type(core.log_warning) == "function" then
        pcall(core.log_warning, "[Holy Paladin] Startup failed; Refresh after fixing: " .. tostring(err))
    end
end
bootstrap()
if not attempted and type(core.register_on_update_callback) == "function" then
    core.register_on_update_callback(bootstrap)
end
