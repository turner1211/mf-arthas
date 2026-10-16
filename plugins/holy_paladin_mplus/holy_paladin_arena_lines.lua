-- Draw arena partner lines; green is healable, amber is out of range, red is blocked.
local M = {}
local color = require("common/color")
local ok_pvp, pvp_helper = pcall(require, "common/utility/pvp_helper")
if not ok_pvp then pvp_helper = nil end
local HEALABLE = color.new(95, 232, 145, 235)
local OUT_OF_RANGE = color.new(246, 192, 77, 235)
local BLOCKED = color.new(246, 91, 81, 245)

local function call(unit, method, ...)
    if not unit then return nil end
    local ok, fn = pcall(function() return unit[method] end)
    if not ok or type(fn) ~= "function" then return nil end
    local call_ok, value = pcall(fn, unit, ...)
    if call_ok then return value end
    return nil
end

local function heal_immune(unit)
    if pvp_helper and type(pvp_helper.is_immune_to_heal) == "function" then
        local ok, immune = pcall(pvp_helper.is_immune_to_heal, pvp_helper, unit, 0)
        if ok and immune == true then return true end
    end
    return call(unit, "is_immune_to_heal") == true
end

local function distance(a, b)
    local pa, pb = call(a, "get_position"), call(b, "get_position")
    if not pa or not pb then return math.huge end
    local ok, d = pcall(function()
        local x, y, z = pa.x - pb.x, pa.y - pb.y, pa.z - pb.z
        return math.sqrt(x * x + y * y + z * z)
    end)
    return ok and d or math.huge
end

local function in_heal_range(spell_id, unit, player)
    local d = distance(player, unit)
    if d > 40 then return false end
    if core.spell_book and type(core.spell_book.is_spell_in_range) == "function" then
        local ok, in_range = pcall(core.spell_book.is_spell_in_range, spell_id, unit, player)
        if ok and in_range == false then return false end
    end
    return true
end

function M.draw(player, allies, enabled, is_arena, heal_spell)
    if not enabled or not is_arena or not player or not core.graphics
        or type(core.graphics.line_3d) ~= "function" then return end
    local from = call(player, "get_position")
    if not from then return end
    for _, unit in ipairs(allies or {}) do
        if unit ~= player and call(unit, "is_valid") == true and call(unit, "is_dead") ~= true
            and call(unit, "is_player") == true and call(unit, "is_party_member") == true
            and call(unit, "is_enemy_with", player) ~= true then
            local to = call(unit, "get_position")
            if to then
                local los_ok, has_los = pcall(core.graphics.is_line_of_sight, player, unit)
                local line_color
                if heal_immune(unit) or not los_ok or has_los ~= true then
                    line_color = BLOCKED
                elseif not in_heal_range(heal_spell, unit, player) then
                    line_color = OUT_OF_RANGE
                else
                    line_color = HEALABLE
                end
                pcall(core.graphics.line_3d, from, to, line_color, 4, 0, false)
            end
        end
    end
end

return M
