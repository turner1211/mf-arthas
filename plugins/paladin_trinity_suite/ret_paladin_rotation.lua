-- Retribution Paladin PvE / Mythic+ rotation for the Lua API exposed in the supplied
-- scripts/.api/core.lua and game_object.lua files.
-- Register this file as a rotation in the client's script manager.
--
-- Priority reference: Method Midnight 12.1 (Aug 27, 2026) and Wowhead (Sep 8, 2026).
-- AoE priority switches at 2+ nearby enemies; M+ utility adds Rebuke interrupts.
-- This script uses the framework's input API to cast one eligible ability per
-- update tick. Test on a target dummy first; talent and client hotfix changes
-- can affect spell availability and priority.

-- Plugin header metadata lives in this rotation module so both loader entry
-- points use one source of truth.
local PALADIN_CLASS_ID = 2
local RET_SPECIALIZATION_ID = 3
local plugin = {
    name = "Ret Paladin 12.1",
    version = "1.62.0",
    author = "Local",
    load = true,
}
-- Project Sylvanas builds expose either the class-local specialization index
-- (3) or the global ChrSpecialization ID (70) through different API paths.
plugin.is_ret_spec = function(value)
    value = tonumber(value)
    return value == RET_SPECIALIZATION_ID or value == 70
end

local function write_status(filename, message)
    pcall(function()
        core.create_data_folder("ret_paladin_plugin")
        core.create_data_file("ret_paladin_plugin/" .. filename)
        core.write_data_file("ret_paladin_plugin/" .. filename, message)
    end)
end

local player_at_load = core.object_manager.get_local_player()
if player_at_load and player_at_load:is_valid() then
    local class_ok, class_id = pcall(function()
        return player_at_load:get_class()
    end)
    local spec_ok, spec_id = pcall(function()
        return player_at_load:get_specialization_id()
    end)
    if class_ok and spec_ok and class_id and class_id > 0
        and spec_id and spec_id > 0
        and (class_id ~= PALADIN_CLASS_ID or not plugin.is_ret_spec(spec_id)) then
        plugin.load = false
        write_status("header_status.md", "Plugin skipped: class=" .. tostring(class_id)
            .. ", specialization=" .. tostring(spec_id))
    else
        write_status("header_status.md", "Plugin accepted: specialization not available or is Retribution")
    end
else
    write_status("header_status.md", "Plugin accepted: no player available yet")
end

local function register_runtime()

local SPELL = {
    AVENGING_WRATH   = 31884,
    RADIANT_GLORY_WINGS = 454351,
    HOLY_LIGHT       = 82326,
    FLASH_OF_LIGHT   = 19750,
    DIVINE_PROTECTION = 498,
    LAY_ON_HANDS     = 633,
    DIVINE_SHIELD    = 642,
    SHIELD_OF_VENGEANCE = 184662,
    WORD_OF_GLORY    = 85673,
    EXECUTION_SENTENCE = 343527,
    EXPURGATION       = 383346,
    HAMMER_OF_LIGHT  = 427453,
    HAMMER_LIGHT_READY = 427441,
    LIGHT_DELIVERANCE = 433732,
    HERALD_DAWNLIGHT = 431377,
    TEMPLAR_LIGHTS_GUIDANCE = 427445,
    SACROSANCT_CRUSADE = 431730,
    SACROSANCT_BARRIER = 461867,
    RADIANT_GLORY    = 458359,
    WAKE_OF_ASHES    = 255937,
    DIVINE_TOLL      = 375576,
    BLADE_OF_JUSTICE = 184575,
    ART_OF_WAR       = 406086,
    RIGHTEOUS_CAUSE  = 402916,
    EMPYREAN_LEGACY  = 387178,
    SEAL_OF_THE_TEMPLAR = 1263252,
    HAMMER_OF_WRATH  = 24275,
    CRUSADER_STRIKE  = 35395,
    JUDGMENT         = 20271,
    FINAL_VERDICT    = 383328,
    TEMPLARS_VERDICT = 85256,
    DIVINE_STORM     = 53385,
    DIVINE_PURPOSE   = 223819,
    DIVINE_PURPOSE_ALT = 408458,
    DIVINE_ARBITER_STORM = 1306161,
    DIVINE_ARBITER_VERDICT = 1306162,
    DIVINE_ARBITER_HAMMER = 1310461,
    TEMPLAR_STRIKE   = 407480,
    TEMPLAR_SLASH    = 406647,
    REBUKE           = 96231,
    HAMMER_OF_JUSTICE = 853,
    BLINDING_LIGHT   = 115750,
    SEARING_GLARE    = 410126,
    BLESSING_OF_PROTECTION = 1022,
    BLESSING_OF_SPELLWARDING = 204018,
    BLESSING_OF_SACRIFICE = 6940,
    BLESSING_OF_FREEDOM = 1044,
    BLESSING_OF_SANCTUARY = 210256,
    CLEANSE_TOXINS   = 213644,
    CONSECRATION     = 205228,
    HALLOWED_GROUND  = 216868,
    FORBEARANCE      = 25771,
    DEVOTION_AURA    = 465,
    CONCENTRATION_AURA = 317920,
    CRUSADER_AURA    = 32223,
}

local MPLUS_PRIORITY_INTERRUPT_ABILITIES = {
    ["piercing hiss"] = true,
    ["mass envenom"] = true,
    ["light bolt volley"] = true,
    ["disorienting screech"] = true,
    ["healing breeze"] = true,
    ["frigid roar"] = true,
    ["arc lightning"] = true,
    ["shadowbolt volley"] = true,
    ["demoralizing shout"] = true,
}
local MPLUS_IMMEDIATE_INTERRUPT_ABILITIES = {
    ["mass envenom"] = true, ["healing breeze"] = true,
    ["shadowbolt volley"] = true, ["light bolt volley"] = true,
}

local function active_spell_name(unit)
    local spell_id
    if unit and unit.get_active_spell_id then
        local ok, value = pcall(unit.get_active_spell_id, unit); if ok then spell_id = value end
    end
    if (not spell_id or spell_id <= 0) and unit and unit.get_active_channel_spell_id then
        local ok, value = pcall(unit.get_active_channel_spell_id, unit); if ok then spell_id = value end
    end
    if not spell_id or spell_id <= 0 then return nil, nil end
    local ok, name = pcall(core.spell_book.get_spell_name, spell_id)
    return ok and type(name) == "string" and string.lower(name) or tostring(spell_id), spell_id
end

local function is_priority_mplus_interrupt(unit)
    if not unit then return false end
    local spell_id
    if unit.get_active_spell_id then
        local ok, value = pcall(unit.get_active_spell_id, unit); if ok then spell_id = value end
    end
    if (not spell_id or spell_id <= 0) and unit.get_active_channel_spell_id then
        local ok, value = pcall(unit.get_active_channel_spell_id, unit); if ok then spell_id = value end
    end
    if not spell_id or spell_id <= 0 then return false end
    local name_ok, spell_name = pcall(core.spell_book.get_spell_name, spell_id)
    if not name_ok or type(spell_name) ~= "string" then return false end
    return MPLUS_PRIORITY_INTERRUPT_ABILITIES[string.lower(spell_name)] == true
end
local HOLY_POWER = 9
local AOE_THRESHOLD = 2
local AOE_RANGE = 8
local DEFENSIVE_GAP_SECONDS = 4.0
local DEFAULT_THRESHOLDS = {
    lay_on_hands = 15,
    divine_shield = 20,
    divine_protection = 35,
    shield_of_vengeance = 35,
    word_of_glory = 30,
    holy_light = 40,
    ally_word_of_glory = 42,
    ally_blessing_of_protection = 18,
    ally_blessing_of_sacrifice = 60,
    ally_lay_on_hands = 12,
}
local SMART = {
    burst_min_ttd = 10, pack_end_ttd = 5, cooldown_hold_max = 5,
    interrupt_late_percent = 65, danger_interrupt_percent = 20,
    health_window = 2.5, predictive_margin = 8, scan_budget_ms = 3,
}

local function get_hero_tree()
    if core.spell_book.is_spell_known(SPELL.HERALD_DAWNLIGHT) then
        return "Herald of the Sun"
    end
    if core.spell_book.is_spell_known(SPELL.TEMPLAR_LIGHTS_GUIDANCE)
        or core.spell_book.is_spell_known(SPELL.HAMMER_LIGHT_READY) then
        return "Templar"
    end
    return "Unknown / shared priority"
end

-- Route groups are embedded from the published Winning Warcraft Midnight S2
-- guides, so the overlay auto-loads by dungeon name and needs no WoW addon.
local DUNGEON_ROUTE_GUIDES = {
    { name = "Altar of Fangs", aliases = {"Altar of Fangs"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/altar-of-fangs/", source_url = "https://keystone.guru/route/altar-of-fangs/E0NokVO/ww-aof-v1/4", pulls = {
        {270306, 261560, 261553, 261553, 261553, 261553, 261553, 261553, 261553, 261550, 261550, 261550, 261560, 261560},
        {261560, 261560, 261553, 261553, 261554, 261550, 261550, 261550, 261550, 261550},
        {270306, 261560, 261560, 261560, 261553, 261553, 261550, 261550, 261550},
        {270306, 261560, 261560, 261553, 261553, 261553, 261553, 261553, 261553, 261550, 261550, 261550, 261550},
        {270306, 261560, 261560, 261553, 261553, 261554, 261554, 261550, 261550, 261550},
        {259445},
        {261557, 261557, 261552, 261552, 261552, 262011},
        {261552, 261552, 261552, 261552, 261552, 261552, 262011, 261557, 261557},
        {261552, 261552, 261552, 259446, 261557, 261557, 262011, 262398, 262398, 270417, 270417},
        {271453, 271453, 261557, 261557},
        {271453, 271453, 271453, 261557, 261557},
        {261573},
        {271453, 271453, 263109, 263112, 263112, 263112, 263112, 263112, 263112},
        {261560, 261560, 261554, 271453, 271453, 271453, 271453},
        {270306, 270306, 271453, 271453, 263109},
        {259447, 268358},
    } },
    { name = "Murder Row", aliases = {"Murder Row"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/murder-row/", source_url = "https://keystone.guru/route/murder-row/rgaIdJp/ww-mr-v1/4", pulls = {
        {236085, 236085, 236085, 236085, 236073, 236073, 236084, 236084, 236071, 236082, 255604},
        {236085, 236085, 236085, 236085, 236085, 236085, 236073, 236073, 236073, 236073, 236084, 236084, 236071},
        {236085, 236073, 236073, 236073, 236073, 236084, 236091, 236091, 236091, 236091},
        {236085, 236085, 236085, 236085, 236085, 236084, 236084, 236902},
        {236073, 236073, 255050, 236091, 236091, 234660, 234648},
        {236893, 236893, 236893, 236893, 236893, 236893, 236897, 236897},
        {234649, 234852, 234852, 234852, 234852, 234852, 234860},
        {234849, 234849, 234849, 235465, 235267, 235267, 235267, 235268, 235268, 235261, 235261},
        {235257, 235257, 235257, 235257, 235257, 235257, 235257, 235257, 235265, 235267, 235267},
        {236082, 236082, 235465, 235261, 235261, 235268, 235268},
        {236905, 235257, 235257, 235257, 235257, 235257, 235257, 235257, 235257, 235261, 235261},
        {234647, 235520},
        {235267, 235267, 235322, 234849, 234849, 234849, 234849, 234849, 234849},
        {234849, 234849, 234849, 234849, 234849, 235268, 235261, 235261, 235267, 235267},
        {235465, 235261, 235261, 235261, 235265},
        {235268, 235268, 235261, 235261, 235322},
        {234763, 234799, 238414, 237626},
    } },
    { name = "Den of Nalorakk", aliases = {"Den of Nalorakk"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/den-of-nalorakk/", source_url = "https://keystone.guru/route/den-of-nalorakk/E7LgtTS/ww-don-v1/4", pulls = {
        {245855, 241813, 241813, 245567, 245752},
        {241814, 241816, 241813, 241813},
        {241816, 241816, 241816, 241809, 241809, 241808},
        {241813, 241813, 241813, 241813, 241814, 241814},
        {245855, 241808, 245567, 241809, 241809},
        {245855, 241816, 241816, 241816, 245567},
        {245855, 241814, 241813, 241808, 241809, 241809, 241809, 241809, 245567},
        {241812},
        {241814, 241814, 241813, 241816, 241816, 241813, 241808, 241809, 241809, 241809, 241809, 241808},
        {241808, 241808, 241874, 241874, 241874, 241874},
        {241911, 241872, 241872, 241876},
        {241874, 241874, 241874, 241876, 241876, 241872, 241872},
        {241874, 241874, 241911, 241869, 241876, 250478},
        {244100},
        {245143, 245143, 245143, 245146, 245139, 245139, 245148, 245145, 245190},
        {245143, 245143, 245139, 245139, 245145, 245145, 245145, 245190, 245190, 245190},
        {245146, 245146, 245139, 245148, 245148},
        {247301, 244889, 246404, 246409},
    } },
    { name = "The Blinding Vale", aliases = {"The Blinding Vale", "Blinding Vale"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/blinding-vale/", source_url = "https://keystone.guru/route/the-blinding-vale/PqAFTuO/ww-bv-v2/2", pulls = {
        {245345, 245345, 245410, 245410, 245410, 245339, 245339, 245346, 245336, 245410, 245410, 245410, 245410, 245410, 245345, 245410, 245410, 245410, 245410, 245410},
        {245345, 245345, 245410, 245410, 245339, 245339, 254850, 245336, 245410, 245410, 245410, 245345},
        {245410, 245410, 245410, 245410, 245410, 245339, 245339, 254850, 245336, 245336},
        {245345, 245410, 245410, 245410, 245346, 245336, 245410, 245410, 245410, 245410, 245345},
        {243028, 243029, 243030},
        {245345, 245339, 245339, 254850},
        {245410, 245410, 245410, 245410, 245410, 245346, 245484, 245473},
        {244887},
        {245484, 245473, 245527, 245527, 245527, 245527, 245527, 245460, 246871},
        {254850, 245473, 245473, 245473, 245460, 245460, 246871, 245527, 245527, 245527, 245527, 245527, 245527, 245527, 245527, 245527, 245527},
        {245345, 245345, 245410, 245410, 245410, 245410, 245410, 245410, 245410, 249756},
        {245912, 246367, 246371},
        {245339, 254850, 245513, 246871, 245484, 245484, 245484},
        {245339, 245339, 245336, 245336, 245346},
        {247676, 247755, 253571},
    } },
    { name = "Voidscar Arena", aliases = {"Voidscar Arena"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/voidscar-arena/", source_url = "https://keystone.guru/route/voidscar-arena/23XHW8T/ww-va-v1/4", pulls = {
        {243996, 243985, 243985, 238883, 243988, 241496, 241496, 252072},
        {267546},
        {243996, 243996, 243996, 243988, 243988, 243988, 243983, 243983, 243983, 243985, 243985, 243985},
        {243996, 243996, 243988, 243988, 243983, 243983, 243985, 243985, 244260, 249603, 249461, 249608, 244309, 249590},
        {238887, 254677},
        {243835, 245950, 241496, 243766},
        {241496, 252053, 238883, 245950},
        {239070, 239070, 239008},
        {243996, 243996, 243988, 243983, 243766, 243766, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 238883, 243835, 243835, 243835},
        {244708, 244708, 243835, 238883, 243766, 241496, 268184},
        {243996, 243996, 243983, 243983, 243835, 243835, 243835, 243835, 243766, 268184, 244708, 244708, 241496},
        {243988, 243988, 244708, 244708, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 252508, 268184},
        {239167, 255000, 255001},
    } },
    { name = "King's Rest", aliases = {"King's Rest", "Kings Rest"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/kings-rest/", source_url = "https://keystone.guru/route/kings-rest/x0FeBIJ/ww-kr-v1/2", pulls = {
        {133935, 133935, 133943, 133943, 133943, 133943, 133943, 133943, 133943, 133943, 134157, 134157, 134158},
        {134158, 134157, 134157, 133943, 133943, 133943, 133943, 133943, 134174, 134157, 134157},
        {135322},
        {137487, 137486, 137484, 137485, 137485, 137485, 137485, 134251, 137473, 134331, 137474, 137478},
        {134739},
        {137969, 137989, 137989, 137989, 137989, 137989, 137989, 137989, 137989, 137989, 270502, 270502},
        {137969, 137989, 137989, 137989, 137989, 137989, 137989, 137989, 137989, 270502, 270502},
        {134993, 136256},
        {135204, 135204, 135167, 135167, 135239, 137591, 135239},
        {135204, 135167, 135239, 135239, 135231, 135192, 135192, 135192, 135192, 137591},
        {135761, 135764, 135765, 269808, 269810, 269811},
        {138489, 138493},
        {136160, 136976, 136984},
    } },
    { name = "Ruby Life Pools", aliases = {"Ruby Life Pools"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/ruby-life-pools/", source_url = "https://keystone.guru/route/ruby-life-pools/BP8KnCV/ww-rlp-v1/3", pulls = {
        {188244, 187969, 187969, 187969, 187969, 188011, 188011, 188067},
        {188244, 188011, 188011, 188067, 188067, 188011, 187969},
        {187969, 188011, 188067, 187897, 187969, 188067},
        {188252},
        {190207, 190207, 190206, 190206, 190034},
        {190207, 190034, 190206, 197697},
        {190207, 190034, 190206, 190206, 190207},
        {190034, 190207, 190207, 190206, 190206},
        {189232},
        {197982, 197982, 197982, 197982, 197509, 197509, 197509, 197509, 197509, 197509, 198047},
        {197509, 197509, 197509, 197509, 197509, 190206, 198047, 197535, 197982, 197982, 197982, 197982, 197982, 190207},
        {190484, 190485},
    } },
    { name = "Temple of Sethraliss", aliases = {"Temple of Sethraliss"}, route_url = "https://winning-warcraft.com/routes/midnight-s2/temple-of-sethraliss/", source_url = "https://keystone.guru/route/temple-of-sethraliss/VBjuYmb/ww-tos-v1/3", pulls = {
        {134600, 134600, 134600, 134616, 134616, 134990, 134991, 134602, 134602, 134602},
        {134600, 134616, 134990, 134990, 134991, 134602, 134602},
        {262530, 262822},
        {134600, 134990, 134629, 135562, 135846, 264785, 134616, 134616, 134686, 139422},
        {134600, 134629, 135562, 135846, 264785},
        {135562, 135562, 135562, 135846, 135846, 134364, 139425, 139425, 264785, 134629},
        {134600, 134364, 135562, 135846, 135846, 264785, 139425, 134629},
        {134388, 133384, 263181, 134487, 263383},
        {139108, 265057, 136076},
        {134691, 134691, 134599, 134599, 136076},
        {136076, 134691, 134691, 134691, 134691, 134599, 134599},
        {263658, 139131, 135445},
        {139108, 139110},
        {135007, 240681, 269227, 269227},
        {135007, 269227, 269227, 240681},
        {135971, 135971, 135971, 135971, 135971, 135971, 135971, 135971, 136250, 268317, 268317, 268317, 268317},
        {133392, 268747, 268364},
    } },
}

local function normalize_route_name(value)
    return string.lower(value or ""):gsub("[^%w]", "")
end

local function read_core_string(getter)
    local ok, value = pcall(getter)
    if ok and type(value) == "string" then return value end
    return ""
end

local function get_current_route_guide(instance_name)
    local normalized = normalize_route_name(instance_name)
    if normalized == "" then return nil end
    for _, guide in ipairs(DUNGEON_ROUTE_GUIDES) do
        for _, alias in ipairs(guide.aliases) do
            local normalized_alias = normalize_route_name(alias)
            if normalized_alias ~= "" and string.find(normalized, normalized_alias, 1, true) then
                return guide
            end
        end
    end
    return nil
end

local function get_dungeon_status()
    local instance_type = string.lower(read_core_string(core.get_instance_type))
    local instance_name = read_core_string(core.get_instance_name)
    local difficulty = read_core_string(core.get_difficulty_name)
    local challenge_map_id = nil
    if core.world and core.world.get_active_challenge_map_id then
        local ok, map_id = pcall(core.world.get_active_challenge_map_id)
        if ok and type(map_id) == "number" and map_id > 0 then challenge_map_id = map_id end
    end

    local inside_dungeon = instance_type == "party" or challenge_map_id ~= nil
    if not inside_dungeon then
        return "Dungeon check: OUTSIDE a dungeon", nil, false, challenge_map_id, instance_name
    end

    local status = "Dungeon check: INSIDE a dungeon"
    if instance_name ~= "" then status = status .. " — " .. instance_name end
    if challenge_map_id then
        status = status .. " (Mythic+ active)"
    elseif difficulty ~= "" then
        status = status .. " (" .. difficulty .. ")"
    end
    return status, get_current_route_guide(instance_name), true, challenge_map_id, instance_name
end

local function has_spell(spell_id)
    local ok, known = pcall(core.spell_book.is_spell_known, spell_id)
    return ok and known == true
end

local function has_radiant_glory()
    return has_spell(SPELL.RADIANT_GLORY)
end

-- Framework menu: green Ret header, enable/disable checkbox, and heal slider.
local green = require("common/color").green()
local RetGui
local ret_gui_load_error
do
    local ok, loaded = pcall(require, "ret_paladin_gui")
    if ok then RetGui = loaded else ret_gui_load_error = tostring(loaded) end
    ok, loaded = pcall(require, "ret_paladin_boss_hud")
    if ok then plugin.boss_hud = loaded end
end
local gui = {
    root = core.menu.tree_node(),
    header = core.menu.header(),
    enabled = core.menu.checkbox(true, "ret_paladin_12_1_enabled"),
    fishing = core.menu.checkbox(false, "ret_paladin_12_1_auto_fishing"),
    skinning = core.menu.checkbox(false, "ret_paladin_12_1_auto_skinning"),
    looting = core.menu.checkbox(false, "ret_paladin_12_1_auto_looting"),
    auto_move = core.menu.checkbox(false, "ret_paladin_12_1_auto_move"),
    auto_move_hotkey = core.menu.keybind(0, false, "ret_paladin_12_1_auto_move_hotkey"),
    auto_aura = core.menu.checkbox(true, "ret_paladin_12_1_auto_aura"),
    -- Use a fresh setting key so the crash-safe, opt-in default isn't overridden
    -- by a saved enabled value from the earlier always-on build.
    auto_face = core.menu.checkbox(false, "ret_paladin_12_1_auto_face_safe"),
    target_line = core.menu.checkbox(false, "ret_paladin_12_1_target_line_safe"),
    healer_line = core.menu.checkbox(false, "ret_paladin_12_1_healer_line_safe"),
    pvp_lines = core.menu.checkbox(true, "ret_paladin_12_1_pvp_combat_lines"),
    diagnostic_log = core.menu.checkbox(true, "ret_paladin_12_1_diagnostic_log"),
    debug_overlay = core.menu.checkbox(false, "ret_paladin_12_1_debug_overlay"),
    route_map = core.menu.checkbox(false, "ret_paladin_12_1_route_map"),
    pve_danger_zones = core.menu.checkbox(true, "ret_paladin_12_1_pve_danger_zones"),
    pve_danger_lead = core.menu.slider_int(1, 6, 3, "ret_paladin_12_1_pve_danger_lead"),
    pve_danger_radius = core.menu.slider_int(2, 12, 5, "ret_paladin_12_1_pve_danger_radius"),
    s2_boss_guide = core.menu.checkbox(true, "ret_paladin_12_1_s2_boss_guide"),
    boss_helper_hud = core.menu.checkbox(true, "ret_paladin_12_1_boss_helper_hud"),
    burst = core.menu.checkbox(true, "ret_paladin_12_1_burst_enabled"),
    training_dummy_burst = core.menu.checkbox(true, "ret_paladin_12_1_training_dummy_burst"),
    interrupts = core.menu.checkbox(true, "ret_paladin_12_1_mplus_interrupts"),
    stun_backup = core.menu.checkbox(false, "ret_paladin_12_1_mplus_stun_backup"),
    smart_min_ttd = core.menu.slider_int(0, 30, SMART.burst_min_ttd, "ret_paladin_12_1_smart_min_ttd"),
    smart_hold_max = core.menu.slider_int(0, 10, SMART.cooldown_hold_max, "ret_paladin_12_1_smart_hold_max"),
    interrupt_late = core.menu.slider_int(20, 95, SMART.interrupt_late_percent, "ret_paladin_12_1_interrupt_late"),
    pve_prediction_window = core.menu.slider_int(0, 4, 2, "ret_paladin_12_1_pve_prediction_window"),
    target_swap_lock = core.menu.slider_int(1, 10, 3, "ret_paladin_12_1_target_swap_lock"),
    pvp_healer_interrupt = core.menu.slider_int(20, 80, 35, "ret_paladin_12_1_pvp_healer_interrupt"),
    pvp_dps_interrupt = core.menu.slider_int(30, 95, 70, "ret_paladin_12_1_pvp_dps_interrupt"),
    pvp_execute_lock = core.menu.slider_int(0, 60, 35, "ret_paladin_12_1_pvp_execute_lock"),
    pvp_outnumbered_hold = core.menu.slider_int(0, 100, 70, "ret_paladin_12_1_pvp_outnumbered_hold"),
    pvp_objective_priority = core.menu.checkbox(true, "ret_paladin_12_1_pvp_objective_priority"),
    pvp_sync_burst = core.menu.checkbox(true, "ret_paladin_12_1_pvp_sync_burst"),
    pvp_uptime_swap = core.menu.slider_int(8, 30, 18, "ret_paladin_12_1_pvp_uptime_swap"),
    pvp_healer_emergency = core.menu.slider_int(0, 80, 50, "ret_paladin_12_1_pvp_healer_emergency"),
    pvp_dampening_mitigation = core.menu.slider_int(0, 100, 30, "ret_paladin_12_1_pvp_dampening_mitigation"),
    pvp_manual_target_grace = core.menu.slider_int(0, 10, 4, "ret_paladin_12_1_pvp_manual_target_grace"),
    pvp_focus_fire = core.menu.checkbox(true, "ret_paladin_12_1_pvp_focus_fire"),
    pvp_safe_chase = core.menu.checkbox(true, "ret_paladin_12_1_pvp_safe_chase"),
    pvp_self_sanctuary = core.menu.checkbox(true, "ret_paladin_12_1_pvp_self_sanctuary"),
    pvp_priority_freedom = core.menu.checkbox(true, "ret_paladin_12_1_pvp_priority_freedom"),
    pvp_burst_sacrifice = core.menu.slider_int(0, 100, 75, "ret_paladin_12_1_pvp_burst_sacrifice"),
    pvp_safe_cleave = core.menu.checkbox(true, "ret_paladin_12_1_pvp_safe_cleave"),
    pvp_predictive_defense = core.menu.checkbox(true, "ret_paladin_12_1_pvp_predictive_defense"),
    pvp_prediction_window = core.menu.slider_int(1, 4, 2, "ret_paladin_12_1_pvp_prediction_window"),
    pvp_pre_sanctuary = core.menu.slider_int(0, 100, 70, "ret_paladin_12_1_pvp_pre_sanctuary"),
    pvp_burst_survival = core.menu.slider_int(0, 80, 40, "ret_paladin_12_1_pvp_burst_survival"),
    pvp_burst_min_power = core.menu.slider_int(0, 5, 3, "ret_paladin_12_1_pvp_burst_min_power"),
    pvp_kill_funnel = core.menu.slider_int(0, 80, 45, "ret_paladin_12_1_pvp_kill_funnel"),
    pvp_wings_target_lock = core.menu.checkbox(true, "ret_paladin_12_1_pvp_wings_target_lock"),
    pvp_wings_kill_swap = core.menu.slider_int(0, 50, 20, "ret_paladin_12_1_pvp_wings_kill_swap"),
    pvp_wings_kill_prediction = core.menu.slider_int(0, 4, 2, "ret_paladin_12_1_pvp_wings_kill_prediction"),
    pvp_execute_spend = core.menu.slider_int(0, 60, 35, "ret_paladin_12_1_pvp_execute_spend"),
    pvp_breakable_cc_pause = core.menu.checkbox(true, "ret_paladin_12_1_pvp_breakable_cc_pause"),
    pvp_predictive_targeting = core.menu.checkbox(true, "ret_paladin_12_1_pvp_predictive_targeting"),
    pvp_target_prediction = core.menu.slider_int(0, 4, 2, "ret_paladin_12_1_pvp_target_prediction"),
    pvp_resource_bank = core.menu.slider_int(0, 8, 3, "ret_paladin_12_1_pvp_resource_bank"),
    pvp_burst_max_range = core.menu.slider_int(5, 30, 12, "ret_paladin_12_1_pvp_burst_max_range"),
    pvp_burst_cc_min = core.menu.slider_int(0, 3000, 1200, "ret_paladin_12_1_pvp_burst_cc_min"),
    pvp_trinket_window = core.menu.slider_int(0, 120, 90, "ret_paladin_12_1_pvp_trinket_window"),
    pvp_burst_heal_hold = core.menu.slider_int(0, 50, 20, "ret_paladin_12_1_pvp_burst_heal_hold"),
    pvp_target_los_filter = core.menu.checkbox(true, "ret_paladin_12_1_pvp_target_los_filter"),
    pvp_predictive_execute_lock = core.menu.checkbox(true, "ret_paladin_12_1_pvp_predictive_execute_lock"),
    pvp_swap_confirm_ms = core.menu.slider_int(100, 1000, 400, "ret_paladin_12_1_pvp_swap_confirm_ms"),
    manual_yield_ms = core.menu.slider_int(0, 2000, 750, "ret_paladin_12_1_manual_yield_ms"),
    cast_failure_backoff = core.menu.checkbox(true, "ret_paladin_12_1_cast_failure_backoff"),
    pvp_forecast_samples = core.menu.slider_int(2, 6, 3, "ret_paladin_12_1_pvp_forecast_samples"),
    pvp_forecast_max_change = core.menu.slider_int(5, 40, 20, "ret_paladin_12_1_pvp_forecast_max_change"),
    pvp_offensive_stun_power = core.menu.slider_int(0, 5, 3, "ret_paladin_12_1_pvp_offensive_stun_power"),
    pvp_offensive_cc_delay = core.menu.slider_int(0, 10, 3, "ret_paladin_12_1_pvp_offensive_cc_delay"),
    pvp_emergency_peel_hp = core.menu.slider_int(0, 80, 40, "ret_paladin_12_1_pvp_emergency_peel_hp"),
    pvp_healer_lockout_window = core.menu.slider_int(1, 5, 3, "ret_paladin_12_1_pvp_healer_lockout_window"),
    pvp_swap_pressure_window = core.menu.slider_int(1, 5, 3, "ret_paladin_12_1_pvp_swap_pressure_window"),
    pvp_swap_sacrifice = core.menu.slider_int(0, 100, 85, "ret_paladin_12_1_pvp_swap_sacrifice"),
    arena_kick_commit_ms = core.menu.slider_int(150, 800, 450, "ret_paladin_12_1_arena_kick_commit_ms"),
    arena_offtarget_blind = core.menu.checkbox(true, "ret_paladin_12_1_arena_offtarget_blind"),
    arena_healer_cc_wall = core.menu.slider_int(0, 100, 70, "ret_paladin_12_1_arena_healer_cc_wall"),
    divine_protection = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.divine_protection, "ret_paladin_12_1_divine_protection_hp"),
    lay_on_hands = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.lay_on_hands, "ret_paladin_12_1_lay_on_hands_hp"),
    divine_shield = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.divine_shield, "ret_paladin_12_1_divine_shield_hp"),
    shield_of_vengeance = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.shield_of_vengeance, "ret_paladin_12_1_shield_of_vengeance_hp"),
    word_of_glory = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.word_of_glory, "ret_paladin_12_1_word_of_glory_hp"),
    holy_light = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.holy_light, "ret_paladin_12_1_holy_light_hp"),
    ally_word_of_glory = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.ally_word_of_glory, "ret_paladin_12_1_ally_word_of_glory_hp"),
    ally_blessing_of_protection = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.ally_blessing_of_protection, "ret_paladin_12_1_ally_bop_hp"),
    ally_blessing_of_sacrifice = core.menu.slider_int(0, 80, DEFAULT_THRESHOLDS.ally_blessing_of_sacrifice, "ret_paladin_12_1_ally_sac_hp"),
    ally_lay_on_hands = core.menu.slider_int(0, 40, DEFAULT_THRESHOLDS.ally_lay_on_hands, "ret_paladin_12_1_ally_loh_hp"),
}

local profile_settings = {
    mythic_plus = { title = "MYTHIC+ • CLEAVE & INTERRUPTS", rotation = true, burst = true,
        cc = false, swap_target = true, team_support = true, defensives = true, aoe_min = 2,
        strategy = "Dungeon cleave at 2+ enemies, Holy Power discipline, and priority-cast interrupts." },
    delve = { title = "DELVE • SOLO & COMPANION PRESSURE", rotation = true, burst = true,
        cc = false, swap_target = true, team_support = true, defensives = true, aoe_min = 2,
        strategy = "PvE priority with cleave, elite-aware cooldowns, personal survival, and companion support." },
    world_pve = { title = "WORLD PvE • QUESTING & RARES", rotation = true, burst = true,
        cc = false, swap_target = false, team_support = true, defensives = true, aoe_min = 2,
        strategy = "Safe questing pressure, late-cast interrupts, and cooldowns reserved for elites or large pulls." },
    arena = { title = "ARENA • FOCUSED KILL WINDOWS", rotation = true, burst = true,
        cc = true, swap_target = true, team_support = true, defensives = true, aoe_min = 99,
        strategy = "Single-target pressure, pressure-aware stun, target swaps, and threshold-based ally saves." },
    battleground = { title = "BATTLEGROUND • TEAM PRESSURE", rotation = true, burst = true,
        cc = true, swap_target = true, team_support = true, defensives = true, aoe_min = 99,
        strategy = "Stay on a vulnerable enemy player, support pressured allies, and avoid low-value cleave spenders." },
    world_pvp = { title = "WORLD PvP • LOCAL SKIRMISH", rotation = true, burst = true,
        cc = true, swap_target = true, team_support = true, defensives = true, aoe_min = 99,
        strategy = "Pressure nearby enemy players; peel attackers and protect visible party or friendly players." },
}

-- Customer-facing toggle registry. Every switch shown in the custom panel has
-- a persistent optional keybind. A key code of 0 leaves that shortcut unbound.
gui.toggle_controls = {
    toggle_plugin = gui.enabled, toggle_burst = gui.burst,
    toggle_interrupts = gui.interrupts, toggle_stun_backup = gui.stun_backup,
    toggle_auto_move = gui.auto_move, toggle_auto_face = gui.auto_face,
    toggle_target_line = gui.target_line, toggle_healer_line = gui.healer_line,
    toggle_pvp_lines = gui.pvp_lines, toggle_route_map = gui.route_map,
    toggle_pve_danger_zones = gui.pve_danger_zones,
    toggle_s2_boss_guide = gui.s2_boss_guide,
    toggle_boss_helper_hud = gui.boss_helper_hud,
    toggle_auto_aura = gui.auto_aura, toggle_fishing = gui.fishing,
    toggle_skinning = gui.skinning, toggle_looting = gui.looting,
    toggle_diagnostic_log = gui.diagnostic_log,
    toggle_debug_overlay = gui.debug_overlay,
    toggle_training_dummy_burst = gui.training_dummy_burst,
    toggle_arena_offtarget_blind = gui.arena_offtarget_blind,
    toggle_pvp_objective_priority = gui.pvp_objective_priority,
    toggle_pvp_sync_burst = gui.pvp_sync_burst,
    toggle_pvp_focus_fire = gui.pvp_focus_fire,
    toggle_pvp_safe_chase = gui.pvp_safe_chase,
    toggle_pvp_self_sanctuary = gui.pvp_self_sanctuary,
    toggle_pvp_priority_freedom = gui.pvp_priority_freedom,
    toggle_pvp_safe_cleave = gui.pvp_safe_cleave,
    toggle_pvp_predictive_defense = gui.pvp_predictive_defense,
    toggle_pvp_wings_target_lock = gui.pvp_wings_target_lock,
    toggle_pvp_breakable_cc_pause = gui.pvp_breakable_cc_pause,
    toggle_pvp_predictive_targeting = gui.pvp_predictive_targeting,
    toggle_pvp_target_los_filter = gui.pvp_target_los_filter,
    toggle_pvp_predictive_execute_lock = gui.pvp_predictive_execute_lock,
    toggle_cast_failure_backoff = gui.cast_failure_backoff,
}
gui.hotkeys, gui.hotkey_down, gui.hotkey_labels = {}, {}, {}
for action, _ in pairs(gui.toggle_controls) do
    gui.hotkeys[action] = action == "toggle_auto_move" and gui.auto_move_hotkey
        or core.menu.keybind(0, false, "ret_paladin_12_1_hotkey_" .. action)
    gui.hotkey_labels[action] = action:gsub("toggle_", ""):gsub("_", " ")
end
for mode, profile in pairs(profile_settings) do
    for _, field in ipairs({ "rotation", "burst", "cc", "swap_target", "team_support", "defensives" }) do
        local action = "profile:" .. mode .. ":" .. field
        gui.hotkeys[action] = core.menu.keybind(0, false,
            "ret_paladin_12_1_hotkey_" .. mode .. "_" .. field)
        gui.hotkey_labels[action] = mode:gsub("_", " ") .. " " .. field:gsub("_", " ")
    end
end
local function smart_setting(item, fallback)
    local ok, value = pcall(function() return item:get_state() end)
    return ok and type(value) == "number" and value or fallback
end
local current_mode, mode_override = "mythic_plus", nil
local manual_pause_until = -math.huge
local last_gui_notice = "Automatic profile selection"
local last_action = "Waiting"
local latest_runtime_error = "None"
local latest_runtime_error_time = "Never"
local runtime_debug = {
    player = "Unavailable", player_hp = "--", holy_power = "--", combat = false,
    target = "None", target_hp = "--", target_distance = "--",
    detected_mode = "mythic_plus", active_mode = "mythic_plus", hero = "Unknown",
    aura = "Unknown", ttd = "--", danger = "--", decision = "Waiting", pvp_state = "--",
    healer_emergency = false, healer_state = "none", dampening = 0,
    outnumbered = false, last_target_guid = nil, auto_target_guid = nil,
    manual_target_lock_until = -math.huge,
    last_world_flash = -math.huge, next_world_flash_retry = -math.huge,
    training_dummy_active = false,
    pvp_dr_fallback_seconds = 26,
}
runtime_debug.training_dummy_ids = {
    -- Classic capital cities and Acherus variants.
    [1921] = true, [18504] = true, [25225] = true, [25297] = true,
    [31144] = true, [31146] = true, [32541] = true, [32542] = true,
    [32545] = true, [32546] = true, [32666] = true, [32667] = true,
    [33229] = true, [42328] = true,
    -- Expansion capitals, faction hubs, garrisons and current-city variants.
    [44171] = true, [48304] = true, [60197] = true, [64446] = true,
    [67127] = true, [87317] = true, [87760] = true, [92164] = true,
    [108420] = true, [114832] = true, [131983] = true, [153285] = true,
    [194643] = true, [198594] = true, [225979] = true, [225980] = true,
}
runtime_debug.unlearned_spell_until = {}
runtime_debug.global_cast_pending = nil
runtime_debug.track_manual_target = function(player)
    local target = player and player.get_target and player:get_target() or nil
    local guid = target and target.get_guid and tostring(target:get_guid()) or "none"
    if runtime_debug.last_target_guid and guid ~= runtime_debug.last_target_guid then
        if guid == runtime_debug.auto_target_guid then
            runtime_debug.auto_target_guid = nil
        else
            runtime_debug.manual_target_lock_until = core.time()
                + smart_setting(gui.pvp_manual_target_grace, 4)
        end
    end
    runtime_debug.last_target_guid = guid
end
local combat_stats = { started = 0, actions = 0, damage = 0, defensive = 0,
    support = 0, interrupt = 0, swaps = 0, burst = 0, cc = 0, saves = 0,
    confirmed = 0, failed = 0, interrupted = 0 }

-- Rolling, event-driven diagnostics. The log records changed decisions and
-- accepted actions, rather than writing every high-frequency update scan.
local LOG = {
    entity = "ret_paladin_plugin",
    owner = "Ret Paladin 12.1",
    window_id = "ret_paladin_turalyon_200",
    log_path = "ret_paladin_plugin/session.md",
    path = "ret_paladin_plugin/diagnostic_log.md",
    backup_path = "ret_paladin_plugin/diagnostic_log_backup.md",
    previous_path = "ret_paladin_plugin/diagnostic_previous_session.md",
    debugger_path = "ret_paladin_plugin/debugger_export.md",
    entity_path = "ret_paladin_plugin/diagnostic_entity.md",
    buffer = {}, state = {}, pending = {}, last_flush = -math.huge, flush_failures = 0,
    lines = 0, status = "Starting",
}
local flush_diagnostic_log
LOG.header = table.concat({
    "Ret Paladin structured diagnostic log v" .. plugin.version,
    "Entity: " .. LOG.entity .. " | Owner: " .. LOG.owner .. " | Shared with battleground controller: false",
    "Fields: t=client seconds | level | category | event | key=value observations",
    "Categories: LOAD MODE GUI CAST ROTATION DEFENSIVE SUPPORT INTERRUPT TARGET AURA GATHER ROUTE OVERLAY SAFETY ERROR",
    "Look for: wrong mode/hero, threshold mismatch, defensive lockout, invalid/immune target,",
    "blocked/out-of-range healer, missed priority interrupt, failed target swap, gathering stalls,",
    "route detection mismatch, or a cast request that the framework declined.",
    "Repeated observations are logged only when their value changes.",
    "---",
}, "\n")

local function log_value(value)
    value = tostring(value == nil and "nil" or value)
    value = value:gsub("[\r\n|]", " ")
    if #value > 96 then value = value:sub(1, 93) .. "..." end
    return value
end

local function diagnostic_event(level, category, event, fields)
    if gui.diagnostic_log:get_state() ~= true then return end
    local now_ok, now = pcall(core.time)
    now = now_ok and type(now) == "number" and now or 0
    local wall_clock = "unknown"
    pcall(function() wall_clock = os.date("%Y-%m-%d %H:%M:%S") end)
    local parts = { "[clock=" .. wall_clock .. "]", string.format("[t=%.2f]", now), "[" .. level .. "]",
        "[" .. category .. "]", "event=" .. log_value(event) }
    local keys = {}
    for key in pairs(fields or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. log_value(fields[key]) end
    LOG.buffer[#LOG.buffer + 1] = table.concat(parts, " | ")
    -- Ordinary accepted actions can happen several times per second. Rewriting
    -- both persistent journals for every action caused visible I/O spikes once
    -- the files grew. Batch those entries into the combat heartbeat; preserve
    -- immediate durability for failures, warnings, GUI requests and safety state.
    if flush_diagnostic_log and (level == "ERROR" or level == "WARN"
        or category == "GUI" or category == "SAFETY") then
        flush_diagnostic_log(true)
    end
end

local function diagnostic_transition(key, value, level, category, event, fields)
    local normalized = log_value(value)
    if LOG.state[key] == normalized then return end
    LOG.state[key] = normalized
    fields = fields or {}
    fields.state = normalized
    diagnostic_event(level, category, event, fields)
end

local function read_persistent_log(path)
    local ok, value = pcall(core.read_data_file, path)
    return ok and type(value) == "string" and value or ""
end

flush_diagnostic_log = function(force)
    if #LOG.buffer == 0 then return end
    local now_ok, now = pcall(core.time)
    now = now_ok and type(now) == "number" and now or 0
    if not force and now - LOG.last_flush < 1.0 then return end
    LOG.last_flush = now
    local ok = pcall(function()
        core.create_data_folder("ret_paladin_plugin")
        core.create_data_file(LOG.path)
        core.create_data_file(LOG.backup_path)
        local primary, backup = read_persistent_log(LOG.path), read_persistent_log(LOG.backup_path)
        local existing = #primary >= #backup and primary or backup
        if existing == "" then existing = LOG.header end
        local addition = table.concat(LOG.buffer, "\n")
        local combined = existing .. "\n" .. addition
        -- Keep the hot journal small enough that its redundant read/write pair
        -- cannot create a noticeable storage spike during combat. The prior
        -- session snapshot still preserves the older full session for export.
        if #combined > 300000 then
            combined = LOG.header .. "\n[older entries retained in previous-session snapshot; live log trimmed]\n"
                .. combined:sub(-250000)
        end
        core.write_data_file(LOG.path, combined)
        core.write_data_file(LOG.backup_path, combined)
        if type(core.write_log_file) == "function" then
            core.write_log_file(LOG.log_path, addition .. "\n")
        end
        LOG.lines = LOG.lines + #LOG.buffer
        LOG.buffer = {}
    end)
    if ok then
        LOG.flush_failures, LOG.status = 0, "Recording / " .. tostring(LOG.lines) .. " lines"
    else
        LOG.flush_failures = LOG.flush_failures + 1
        LOG.status = "Write failed; memory retained"
    end
end

-- Recover the longest intact copy and preserve a session snapshot before any
-- new events are appended. This survives ordinary logout/reload and gives a
-- second copy when a crash interrupts one file write.
pcall(function()
    core.create_data_folder("ret_paladin_plugin")
    core.create_data_file(LOG.path)
    core.create_data_file(LOG.backup_path)
    core.create_data_file(LOG.previous_path)
    core.create_data_file(LOG.entity_path)
    if type(core.create_log_folder) == "function" then core.create_log_folder("ret_paladin_plugin") end
    if type(core.create_log_file) == "function" then core.create_log_file(LOG.log_path) end
    local primary, backup = read_persistent_log(LOG.path), read_persistent_log(LOG.backup_path)
    local recovered = #primary >= #backup and primary or backup
    if recovered ~= "" then
        core.write_data_file(LOG.path, recovered)
        core.write_data_file(LOG.backup_path, recovered)
        core.write_data_file(LOG.previous_path, recovered)
    end
    core.write_data_file(LOG.entity_path, table.concat({
        "entity=" .. LOG.entity,
        "owner=" .. LOG.owner,
        "version=" .. plugin.version,
        "window_id=" .. LOG.window_id,
        "live_log=scripts_log/" .. LOG.log_path,
        "journal=scripts_data/" .. LOG.path,
        "debugger=scripts_data/" .. LOG.debugger_path,
        "independent_from=sylvanas_battleground_bot",
    }, "\n"))
end)
diagnostic_event("INFO", "LOAD", "runtime_registered", {
    plugin = plugin.name, version = plugin.version, session = "new_login_or_reload",
    entity = LOG.entity, owner = LOG.owner, shared_with_bg_controller = false,
})
flush_diagnostic_log(true)

-- A dedicated public identity lets support tools locate Ret diagnostics without
-- reading or mutating the battleground controller's global entity.
_G.RetPaladinPluginDiagnostics = {
    entity = LOG.entity,
    owner = LOG.owner,
    version = plugin.version,
    window_id = LOG.window_id,
    live_log_path = "scripts_log/" .. LOG.log_path,
    journal_path = "scripts_data/" .. LOG.path,
    debugger_path = "scripts_data/" .. LOG.debugger_path,
    independent_from = "sylvanas_battleground_bot",
}
local next_log_heartbeat = 0
core.register_on_update_callback(function()
    local now = core.time()
    if now >= next_log_heartbeat then
        -- Combat needs a tight heartbeat for post-fight diagnosis. Outside combat,
        -- a slower cadence preserves the useful journal history before it trims.
        local heartbeat_interval = runtime_debug.combat == true and 5 or 20
        next_log_heartbeat = now + heartbeat_interval
        diagnostic_event("INFO", "SESSION", "heartbeat", {
            mode = current_mode, action = last_action, player_hp = runtime_debug.player_hp,
            target = runtime_debug.target, target_hp = runtime_debug.target_hp,
            combat = runtime_debug.combat, buffered = #LOG.buffer,
            previous_flush_failures = LOG.flush_failures,
        })
        flush_diagnostic_log(true)
    end
end)

local pvp_helper
pcall(function() pvp_helper = require("common/utility/pvp_helper") end)
local enums = require("common/enums")

local function read_mode(getter)
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter)
    return ok and value or nil
end

local function detect_mode()
    local raw = read_mode(core.get_instance_type)
    local kind = type(raw) == "string" and string.lower(raw) or ""
    if kind == "arena" then return "arena" end
    if kind == "pvp" or kind == "battleground" then return "battleground" end
    if core.delves and read_mode(core.delves.is_in_delve) == true then return "delve" end
    if kind == "party" then return "mythic_plus" end
    if pvp_helper and type(pvp_helper.is_pvp_scenario) == "function" then
        local ok, active = pcall(pvp_helper.is_pvp_scenario, pvp_helper)
        if ok and active == true then return "world_pvp" end
    end
    return "world_pve"
end

local function effective_mode()
    local detected = detect_mode()
    current_mode = mode_override or detected
    if not profile_settings[current_mode] then current_mode = "mythic_plus" end
    return current_mode, detected
end

local function toggle_checkbox(check)
    check:set(check:get_state() ~= true)
end

local function handle_gui_action(action, mode, field)
    if action == "toggle_plugin" then
        toggle_checkbox(gui.enabled)
        last_gui_notice = gui.enabled:get_state() and "Combat routine enabled" or "Combat routine paused"
    elseif action == "auto_mode" then
        mode_override = nil
        last_gui_notice = "Automatic profile selection restored"
    elseif action == "set_mode" and profile_settings[mode] then
        mode_override = mode
        current_mode = mode
        last_gui_notice = "Manual profile: " .. mode
    elseif action == "notice" then
        last_gui_notice = tostring(mode or "Ready")
    elseif action == "clear_debug_error" then
        latest_runtime_error = "None"
        latest_runtime_error_time = "Never"
        last_gui_notice = "Debugger error cleared"
    elseif action == "save_debug_snapshot" then
        flush_diagnostic_log(true)
        local clock = "unknown"
        pcall(function() clock = os.date("%Y-%m-%d %H:%M:%S") end)
        local snapshot = table.concat({
            "RET PALADIN DEBUGGER EXPORT v" .. plugin.version,
            "Entity: " .. LOG.entity,
            "Owner: " .. LOG.owner,
            "Independent from battleground controller: true",
            "Saved: " .. clock,
            "Logger: " .. tostring(LOG.status),
            "Live log: scripts_log/" .. LOG.log_path,
            "Crash-safe journal: scripts_data/" .. LOG.path,
            "Player: " .. tostring(runtime_debug.player) .. " | HP " .. tostring(runtime_debug.player_hp)
                .. " | Holy Power " .. tostring(runtime_debug.holy_power),
            "Combat: " .. tostring(runtime_debug.combat) .. " | Mode " .. tostring(runtime_debug.active_mode)
                .. " | Detected " .. tostring(runtime_debug.detected_mode),
            "Hero: " .. tostring(runtime_debug.hero) .. " | Aura " .. tostring(runtime_debug.aura),
            "Target: " .. tostring(runtime_debug.target) .. " | HP " .. tostring(runtime_debug.target_hp)
                .. " | Distance " .. tostring(runtime_debug.target_distance),
            "TTD: " .. tostring(runtime_debug.ttd) .. " | Danger " .. tostring(runtime_debug.danger),
            "PvE danger aura: " .. tostring(runtime_debug.danger_zone_status or "Waiting"),
            "Season 2 boss guide: " .. tostring(runtime_debug.s2_boss_status or "Waiting"),
            "Decision: " .. tostring(runtime_debug.decision),
            "PvP: " .. tostring(runtime_debug.pvp_state),
            "Last action: " .. tostring(last_action),
            "Latest error: " .. tostring(latest_runtime_error) .. " at " .. tostring(latest_runtime_error_time),
            "", "===== PERSISTENT LOG =====", read_persistent_log(LOG.path),
        }, "\n")
        pcall(function()
            core.create_data_folder("ret_paladin_plugin")
            core.create_data_file(LOG.debugger_path)
            core.write_data_file(LOG.debugger_path, snapshot)
        end)
        last_gui_notice = "Saved scripts_data/ret_paladin_plugin/debugger_export.md"
        diagnostic_event("ACTION", "GUI", "debugger_export_saved", {
            path = "scripts_data/ret_paladin_plugin/debugger_export.md",
        })
    elseif action == "profile_toggle" and profile_settings[mode]
        and profile_settings[mode][field] ~= nil then
        if field == "burst" then
            local effective = profile_settings[mode].burst == true and gui.burst:get_state() == true
            profile_settings[mode].burst = not effective
            if profile_settings[mode].burst then gui.burst:set(true) end
        else
            profile_settings[mode][field] = not profile_settings[mode][field]
        end
        last_gui_notice = mode .. " " .. field .. (profile_settings[mode][field] and " enabled" or " paused")
    else
        local check = gui.toggle_controls[action]
        if check then
            toggle_checkbox(check)
            last_gui_notice = action:gsub("toggle_", "") .. (check:get_state() and " enabled" or " paused")
        end
    end
    diagnostic_event("INFO", "GUI", "setting_changed", {
        action = action, mode = mode or current_mode, field = field or "none", notice = last_gui_notice,
    })
end

gui.poll_customer_hotkeys = function()
    if not core.input or type(core.input.is_key_pressed) ~= "function" then return end
    for action, binding in pairs(gui.hotkeys) do
        local key = binding and binding.get_key_code and binding:get_key_code() or 0
        local down = false
        if key and key > 0 then
            local ok, pressed = pcall(core.input.is_key_pressed, key)
            down = ok and pressed == true
        end
        if down and not gui.hotkey_down[action] then
            local mode, field = action:match("^profile:([^:]+):([^:]+)$")
            if mode and field then handle_gui_action("profile_toggle", mode, field)
            else handle_gui_action(action) end
        end
        gui.hotkey_down[action] = down
    end
end

local function render_custom_gui()
    if not RetGui or type(RetGui.render) ~= "function" then return end
    local player = core.object_manager.get_local_player()
    local eligible = player and player.is_valid and player:is_valid()
        and player:get_class() == PALADIN_CLASS_ID
        and plugin.is_ret_spec(core.spell_book.get_specialization_id())
    if not eligible then
        if type(RetGui.hide) == "function" then pcall(RetGui.hide) end
        return
    end
    local mode, detected = effective_mode()
    local p = profile_settings[mode]
    local shown_profiles = {}
    for key, item in pairs(profile_settings) do
        shown_profiles[key] = {}
        for field, value in pairs(item) do shown_profiles[key][field] = value end
        shown_profiles[key].burst = item.burst == true and gui.burst:get_state() == true
    end
    local state = {
        eligible = true,
        active_mode = mode,
        detected_mode = detected,
        mode_label = (mode:gsub("_", " ")) .. (mode_override and " • MANUAL" or " • AUTO"),
        profile_name = p and p.title or "Retribution",
        hero = get_hero_tree(),
        status = gui.enabled:get_state() and "Active" or "Paused",
        notice = last_gui_notice,
        last = last_action,
        plugin_enabled = gui.enabled:get_state() == true,
        auto_mode = mode_override == nil,
        profiles = shown_profiles,
        auto_move = gui.auto_move:get_state() == true,
        auto_face = gui.auto_face:get_state() == true,
        target_line = gui.target_line:get_state() == true,
        healer_line = gui.healer_line:get_state() == true,
        pvp_lines = gui.pvp_lines:get_state() == true,
        diagnostic_log = gui.diagnostic_log:get_state() == true,
        debug_overlay = gui.debug_overlay:get_state() == true,
        debug = {
            entity = LOG.entity, owner = LOG.owner,
            player = runtime_debug.player, player_hp = runtime_debug.player_hp,
            holy_power = runtime_debug.holy_power, combat = runtime_debug.combat,
            target = runtime_debug.target, target_hp = runtime_debug.target_hp,
            target_distance = runtime_debug.target_distance,
            detected_mode = runtime_debug.detected_mode, active_mode = runtime_debug.active_mode,
            hero = runtime_debug.hero, last_action = last_action,
            aura = runtime_debug.aura,
            ttd = runtime_debug.ttd, danger = runtime_debug.danger, decision = runtime_debug.decision,
            danger_zone = runtime_debug.danger_zone_status,
            boss_guide = runtime_debug.s2_boss_status,
            pvp_state = runtime_debug.pvp_state,
            last_error = latest_runtime_error, error_time = latest_runtime_error_time,
            diagnostic_path = LOG.path, log_status = LOG.status,
            live_log_path = "scripts_log/" .. LOG.log_path,
        },
        version = plugin.version,
        route_map = gui.route_map:get_state() == true,
        pve_danger_zones = gui.pve_danger_zones:get_state() == true,
        s2_boss_guide = gui.s2_boss_guide:get_state() == true,
        boss_helper_hud = gui.boss_helper_hud:get_state() == true,
        auto_aura = gui.auto_aura:get_state() == true,
        fishing = gui.fishing:get_state() == true,
        skinning = gui.skinning:get_state() == true,
        looting = gui.looting:get_state() == true,
        training_dummy_burst = gui.training_dummy_burst:get_state() == true,
        arena_offtarget_blind = gui.arena_offtarget_blind:get_state() == true,
        burst = gui.burst:get_state() == true,
        interrupts = gui.interrupts:get_state() == true,
        stun_backup = gui.stun_backup:get_state() == true,
        pvp_objective_priority = gui.pvp_objective_priority:get_state() == true,
        pvp_sync_burst = gui.pvp_sync_burst:get_state() == true,
        pvp_focus_fire = gui.pvp_focus_fire:get_state() == true,
        pvp_safe_chase = gui.pvp_safe_chase:get_state() == true,
        pvp_self_sanctuary = gui.pvp_self_sanctuary:get_state() == true,
        pvp_priority_freedom = gui.pvp_priority_freedom:get_state() == true,
        pvp_safe_cleave = gui.pvp_safe_cleave:get_state() == true,
        pvp_predictive_defense = gui.pvp_predictive_defense:get_state() == true,
        pvp_wings_target_lock = gui.pvp_wings_target_lock:get_state() == true,
        pvp_breakable_cc_pause = gui.pvp_breakable_cc_pause:get_state() == true,
        pvp_predictive_targeting = gui.pvp_predictive_targeting:get_state() == true,
        pvp_target_los_filter = gui.pvp_target_los_filter:get_state() == true,
        pvp_predictive_execute_lock = gui.pvp_predictive_execute_lock:get_state() == true,
        cast_failure_backoff = gui.cast_failure_backoff:get_state() == true,
        hotkeys = gui.hotkeys,
        hotkey_labels = gui.hotkey_labels,
    }
    local rendered, err = RetGui.render(state, handle_gui_action)
    if rendered == false then error(err or "GUI render failed") end
end

local route_guide_state = {
    message = "Off",
    route_name = nil,
    pull_index = 0,
    pull_count = 0,
    targets = {},
    pull_centers = {},
}

core.register_on_render_menu_callback(function()
    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid()
        or player:get_class() ~= PALADIN_CLASS_ID
        or not plugin.is_ret_spec(core.spell_book.get_specialization_id()) then return end
    gui.root:render("Ret Paladin 12.1", function()
        gui.header:render("RETRIBUTION • 12.1 COMBAT PROFILES", green)
        core.menu.text("Hero tree: " .. get_hero_tree())
        local dungeon_status, route_guide, inside_dungeon = get_dungeon_status()
        core.menu.text(dungeon_status)
        if route_guide then
            core.menu.text("Built-in route: " .. route_guide.name .. " • auto-loaded")
        elseif inside_dungeon then
            core.menu.text("Built-in route: no matching dungeon")
        end
        gui.route_map:render("In-game M+ route guide", "Automatically detects supported dungeons and loads an embedded route. Draws route lines and highlights the next live pull. No WoW addon or MDT import is required.")
        gui.pve_danger_zones:render("PvE danger-zone aura", "Draw a red ground aura when confirmed cast, incoming-damage, or BigWigs/LittleWigs evidence says the next mechanic can hit you. Draw green when an imminent confirmed mechanic is aimed elsewhere. PvE modes only.")
        gui.pve_danger_lead:render("Danger-zone warning seconds", "Hard BigWigs and hostile-cast look-ahead window. The aura disappears when the cast or timer ends.")
        gui.pve_danger_radius:render("Danger-zone aura radius", "Visual ground-circle radius in yards. This is a status aura around your character, not a claim about the encounter spell's exact ground radius.")
        gui.s2_boss_guide:render("Season 2 boss encounter guide", "Detect all 28 Season 2 dungeon bosses, your group role, live casts and BigWigs/LittleWigs timers. Shows your current mechanic job and reliable boss/stack guidance overlays.")
        gui.boss_helper_hud:render("Small dungeon boss helper GUI", "Show a separate compact movable window in supported dungeons. It auto-detects class, specialization, role, boss mechanics and danger type.")
        core.menu.text("Route guide status: " .. route_guide_state.message)
        gui.enabled:render("Combat routine enabled", "Turn the Retribution combat routine on or off.")
        gui.fishing:render("Auto fishing", "Automatically start Fishing, watch your bobber, and loot the catch while you are out of combat.")
        gui.skinning:render("Auto skinning", "Target nearby harvestable corpses, move into range, and skin them while you are out of combat.")
        gui.looting:render("Auto looting", "Loot nearby dead creatures while you are out of combat only.")
        gui.auto_move:render("Auto move to selected target", "Move toward your selected attackable target during combat and stop at melee range.")
        gui.auto_move_hotkey:render("Auto move hotkey", "Bind a key to toggle Auto move to selected target. The checkbox also works.")
        gui.auto_aura:render("Automatic aura selection", "Use Crusader while mounted out of combat. In combat, use Concentration if another group Paladin is positively seen with Devotion; otherwise use Devotion. Outside combat, use Concentration when that group aura is detected; otherwise use Devotion.")
        gui.auto_face:render("Auto face selected target", "Opt in to face your selected attackable target during combat. Updates at 10 Hz and does not move the character.")
        gui.target_line:render("Yellow target line and ground ring", "Draw a yellow line to the selected hostile target and a small ring around its feet.")
        gui.healer_line:render("Healer line and line-of-sight", "Draw a line to your group healer. Green means clear line of sight and within 40 yards; red means blocked or too far.")
        gui.diagnostic_log:render("Structured diagnostic logging", "Records changed decisions and accepted actions to scripts_data/ret_paladin_plugin/diagnostic_log.md. Repeated scans are suppressed.")
        gui.debug_overlay:render("On-screen debugger", "Show live player, target, mode, action, toggle and runtime-error information in the custom GUI.")
        gui.burst:render("Burst cooldowns", "Align Avenging Wrath and Execution Sentence with Wake of Ashes, then use major generators without wasting Holy Power. Turn off to hold these cooldowns.")
        gui.training_dummy_burst:render("Training dummy burst testing", "Automatically recognize attackable city training dummies and run the complete single-target priority. When enabled, major cooldowns are tested on the dummy; when disabled, the normal rotation continues without major burst.")
        gui.interrupts:render("Mythic+ interrupts", "Use Rebuke only on casts marked important in the M+ ability guide.")
        gui.stun_backup:render("Hammer of Justice backup", "Use Hammer of Justice on a guide-priority cast when Rebuke is unavailable.")
        gui.smart_min_ttd:render("Minimum TTD for burst", "Hard planning rule: hold major burst below this observed target time-to-die. Zero disables the hold.")
        gui.smart_hold_max:render("Maximum cooldown hold seconds", "Hard maximum for an adaptive cooldown hold before the routine releases it.")
        gui.interrupt_late:render("Normal interrupt cast %", "Normal priority casts are interrupted at or after this progress. Urgent casts retain their early threshold.")
        gui.pve_prediction_window:render("PvE prediction window seconds", "Hard look-ahead window for Mythic+, Delve, and World PvE defensive thresholds. Zero uses current HP only.")
        gui.target_swap_lock:render("Target swap lock seconds", "Minimum time between accepted automatic target changes.")
        gui.pvp_healer_interrupt:render("PvP healer interrupt cast %", "Interrupt enemy healers at or after this cast progress.")
        gui.pvp_dps_interrupt:render("PvP DPS interrupt cast %", "Interrupt enemy damage dealers at or after this cast progress.")
        gui.pvp_execute_lock:render("PvP execute target lock HP %", "Keep a vulnerable current target at or below this HP unless it becomes protected or an objective carrier must be stopped. Zero disables.")
        gui.pvp_outnumbered_hold:render("Outnumbered burst hold HP %", "Hold offensive burst at or below this HP while visibly outnumbered. Zero disables.")
        gui.pvp_objective_priority:render("Battleground objective priority", "Prefer a positively identified flag or objective carrier.")
        gui.pvp_sync_burst:render("Synchronize teammate burst", "Allow a coordinated burst window when a nearby teammate has a confirmed offensive cooldown active.")
        gui.pvp_uptime_swap:render("PvP anti-kite swap distance", "Allow a temporary reachable-target swap when the current target is at least this far away and another valid enemy is in melee range.")
        gui.pvp_healer_emergency:render("Healer emergency HP %", "Enter peel mode when the group healer reaches this hard HP threshold or is crowd controlled. Zero disables the HP trigger.")
        gui.pvp_dampening_mitigation:render("Dampening mitigation priority %", "At or above this dampening level, prefer eligible mitigation saves before reduced healing. Zero disables.")
        gui.pvp_manual_target_grace:render("Manual target grace seconds", "Pause automatic target swapping for this many seconds after you personally select a different target. Zero disables.")
        gui.pvp_focus_fire:render("Team focus-fire targeting", "Add target value when nearby teammates are already attacking the same enemy.")
        gui.pvp_safe_chase:render("Outnumbered chase safety", "Stop automatic forward movement while the outnumbered survival state is active below its configured HP threshold.")
        gui.pvp_self_sanctuary:render("Self Sanctuary escape", "Use Blessing of Sanctuary on yourself when a supported hard-control effect is positively confirmed.")
        gui.pvp_priority_freedom:render("Priority PvP Freedom", "Free a rooted or slowed healer first, then a pressured teammate, before spending healing globals.")
        gui.pvp_burst_sacrifice:render("Burst Sacrifice HP %", "Hard HP limit for preemptive Blessing of Sacrifice on a healer under confirmed enemy burst. Zero disables.")
        gui.pvp_safe_cleave:render("Safe large-fight cleave", "Use multi-target finishers in Battleground and World PvP at 3+ enemies only when no nearby breakable crowd control is detected.")
        gui.pvp_predictive_defense:render("Predictive PvP defensives", "Use confirmed incoming damage and recent health loss to act before a configured defensive HP threshold is crossed.")
        gui.pvp_prediction_window:render("Prediction window seconds", "Hard forecast window used for Arena, Battleground and World PvP defensive thresholds.")
        gui.pvp_pre_sanctuary:render("Pre-Sanctuary healer HP %", "Use Sanctuary before confirmed enemy burst lands on the healer at or below this projected HP. Zero disables.")
        gui.pvp_burst_survival:render("PvP burst survival HP %", "Hold major offensive cooldowns at or below this projected self HP while continuing normal pressure. Zero disables.")
        gui.pvp_burst_min_power:render("PvP burst minimum Holy Power", "Prepare at least this much Holy Power before committing to coordinated burst. Hard control and execute opportunities bypass the preparation delay. Zero disables.")
        gui.pvp_kill_funnel:render("PvP kill funnel target HP %", "Use single-target damage instead of large-fight cleave at or below this target HP. Zero disables.")
        gui.pvp_wings_target_lock:render("Lock target during Wings", "Keep the current valid target while Avenging Wrath is active so automatic swaps do not split the damage window.")
        gui.pvp_wings_kill_swap:render("Wings kill-swap target HP %", "Override the Wings target lock for a valid nearby enemy at or below this HP when the current target is substantially healthier. Zero disables.")
        gui.pvp_wings_kill_prediction:render("Wings kill prediction seconds", "Project observed enemy health loss across this window when checking a Wings kill swap. Zero uses current HP only.")
        gui.pvp_execute_spend:render("PvP immediate spender HP %", "Spend at three Holy Power at or below this enemy HP instead of delaying a possible kill for ordinary generators. Zero disables.")
        gui.pvp_breakable_cc_pause:render("Pause damage on breakable CC", "Stop all rotation damage when the selected enemy is under confirmed breakable crowd control.")
        gui.pvp_predictive_targeting:render("Predictive PvP targeting", "Score enemy targets using observed health loss and confirmed incoming healing instead of a single health snapshot.")
        gui.pvp_target_prediction:render("Target prediction seconds", "Forecast enemy net HP across this hard window for target selection. Zero uses current HP.")
        gui.pvp_resource_bank:render("PvP resource-bank seconds", "Build safely at three, then hold four Holy Power for this long while waiting for a coordinated burst window. Five Holy Power and execute opportunities still spend. Zero disables.")
        gui.pvp_burst_max_range:render("PvP burst maximum range", "Start a new burst package only while the selected enemy is within this hard distance.")
        gui.pvp_burst_cc_min:render("Burst minimum CC remaining ms", "Require at least this much confirmed target or enemy-healer crowd control before treating it as a burst setup. Zero accepts any confirmed duration.")
        gui.pvp_trinket_window:render("Arena post-trinket pressure seconds", "Treat confirmed enemy PvP trinket use inside this hard window as a resource-gated kill signal. Zero disables.")
        gui.pvp_burst_heal_hold:render("Burst incoming-heal hold %", "Hold a new burst against a non-execute target receiving at least this much confirmed incoming healing. Zero disables.")
        gui.pvp_target_los_filter:render("Target line-of-sight filter", "Exclude an automatic PvP target candidate when line of sight is positively confirmed blocked.")
        gui.pvp_lines:render("PvP target and healer lines", "Draw a yellow line and ring to your selected enemy plus a healer line. The healer line is green when healable and red when line of sight is blocked, healing is immune, or the healer is too far away.")
        gui.pvp_predictive_execute_lock:render("Predictive execute target lock", "Keep the current target when its projected net HP is at or below the execute-lock threshold.")
        gui.pvp_swap_confirm_ms:render("Target-swap confirmation ms", "Release a failed automatic-swap lock if the selected target does not actually change within this hard timeout.")
        gui.manual_yield_ms:render("Manual-cast yield ms", "Pause ordinary automation for this long after a confirmed manual spell input. Emergency actions at 20% HP still run. Zero disables.")
        gui.cast_failure_backoff:render("Cast failure backoff", "Apply target-specific exponential retry delays after confirmed failures or quiet request timeouts.")
        gui.pvp_forecast_samples:render("PvP forecast minimum samples", "Require this many recent health observations before health-loss prediction can influence targeting or kill swaps.")
        gui.pvp_forecast_max_change:render("PvP forecast maximum damage %", "Clamp predicted health loss to this hard percentage so a noisy sample cannot manufacture a kill opportunity.")
        gui.pvp_offensive_stun_power:render("Offensive stun minimum Holy Power", "Require this much Holy Power before using Hammer of Justice for kill setup. Emergency peels bypass this limit. Zero disables the resource requirement.")
        gui.pvp_offensive_cc_delay:render("Offensive CC opening delay", "Wait this many combat seconds before spending offensive crowd control. Emergency peels bypass the delay.")
        gui.pvp_emergency_peel_hp:render("Emergency peel ally HP %", "Use available stun immediately when the attacker's friendly victim is at or below this hard HP limit or under confirmed burst. Zero disables the HP trigger.")
        gui.pvp_healer_lockout_window:render("Confirmed healer lockout seconds", "Treat a successful plugin-owned Rebuke on an enemy healer as a coordinated burst window for this hard duration.")
        gui.pvp_swap_pressure_window:render("Enemy-swap pressure seconds", "Remember a confirmed enemy target change onto a teammate for this hard duration.")
        gui.pvp_swap_sacrifice:render("Swap Sacrifice ally HP %", "Use preemptive Blessing of Sacrifice on a newly focused teammate at or below this hard HP limit. Zero disables.")
        gui.arena_kick_commit_ms:render("Arena interrupt commit window ms", "After the configured cast percentage, wait until this much cast time remains before Rebuke. This reduces early kicks into fake casts.")
        gui.arena_offtarget_blind:render("Arena off-target healer Blinding Light", "Use Blinding Light on a nearby enemy healer with ready disorient DR while the selected target is vulnerable and Holy Power is prepared.")
        gui.arena_healer_cc_wall:render("Arena healer-CC wall HP %", "Use Divine Protection early at or below this projected HP while your healer is controlled and enemies are pressuring you. Zero disables.")
        gui.divine_protection:render("Divine Protection trigger HP %", "Hard limit: use Divine Protection only at or below this HP percentage. Set to 0 to disable.")
        gui.lay_on_hands:render("Lay on Hands trigger HP %", "Hard trigger: attempt Lay on Hands only at or below this HP percentage. Set to 0 to disable.")
        gui.divine_shield:render("Divine Shield trigger HP %", "Hard trigger: attempt Divine Shield only at or below this HP percentage. Set to 0 to disable.")
        gui.shield_of_vengeance:render("Shield of Vengeance trigger HP %", "Hard trigger: attempt Shield of Vengeance only at or below this HP percentage. Set to 0 to disable.")
        gui.word_of_glory:render("Word of Glory trigger HP %", "Hard trigger: attempt Word of Glory only at or below this HP percentage. Set to 0 to disable.")
        gui.holy_light:render("Holy Light trigger HP %", "Hard trigger: attempt Holy Light only at or below this HP percentage. Set to 0 to disable.")
        core.menu.text("TEAM SUPPORT — all sliders are hard HP limits")
        gui.ally_word_of_glory:render("Ally Word of Glory HP %", "Hard limit: heal an eligible teammate only at or below this HP percentage.")
        gui.ally_blessing_of_protection:render("Ally immunity HP %", "Hard limit: use Protection for physical pressure or talented Spellwarding for confirmed magical pressure.")
        gui.ally_blessing_of_sacrifice:render("Ally Blessing of Sacrifice HP %", "Hard limit: use only on a teammate under active enemy pressure at or below this HP percentage.")
        gui.ally_lay_on_hands:render("Ally Lay on Hands HP %", "Hard limit: emergency heal only at or below this HP percentage. Set to 0 to disable.")
        core.menu.text("CUSTOM HOTKEYS — 0 means unbound")
        for action, binding in pairs(gui.hotkeys) do
            binding:render(gui.hotkey_labels[action] or action,
                "Pressing the assigned key toggles this option on or off. Profile shortcuts affect only the named mode feature.")
        end
    end)
end)

-- Render the custom panel on the same independent window layer used by the
-- stable Holy Paladin GUI. Keeping it outside the settings-tree callback lets
-- it remain visible during normal gameplay and while the framework menu is closed.
local ret_gui_error_reported = false
local last_gui_runtime_error, last_gui_runtime_error_at = nil, -math.huge
runtime_debug.render_boss_helper_hud = function()
    if not plugin.boss_hud or type(plugin.boss_hud.render) ~= "function" then return end
    if type(plugin.boss_hud.standalone) == "function" and plugin.boss_hud.standalone() then return end
    local player = core.object_manager.get_local_player()
    local eligible = player and safe_unit_call(player, "is_valid") == true
        and safe_unit_call(player, "get_class") == PALADIN_CLASS_ID
        and plugin.is_ret_spec(core.spell_book.get_specialization_id())
    if not eligible or gui.boss_helper_hud:get_state() ~= true then
        if type(plugin.boss_hud.hide) == "function" then pcall(plugin.boss_hud.hide) end
        return
    end
    local _, _, inside_dungeon = get_dungeon_status()
    local instance_name = "Dungeon"
    if type(core.get_instance_name) == "function" then
        local ok, value = pcall(core.get_instance_name)
        if ok and type(value) == "string" and value ~= "" then instance_name = value end
    end
    local role_id = tonumber(safe_unit_call(player, "get_group_role")) or 0
    local role = role_id == 2 and "TANK" or role_id == 1 and "HEALER" or "DPS"
    local guide = runtime_debug.current_boss_guide
    if inside_dungeon and type(runtime_debug.scan_s2_boss_guide) == "function" then
        guide = runtime_debug.scan_s2_boss_guide(player)
    end
    plugin.boss_hud.render({
        eligible = true, enabled = true, inside_dungeon = inside_dungeon == true,
        class_id = safe_unit_call(player, "get_class"),
        spec_id = core.spell_book.get_specialization_id(), role = role,
        instance = instance_name, guide = guide,
        status = runtime_debug.s2_boss_status or "Boss guide ready",
    })
end

local function render_ret_window()
    local render_now = core.time()
    if runtime_debug.last_gui_render_at == render_now then return end
    runtime_debug.last_gui_render_at = render_now
    local hud_ok, hud_err = pcall(runtime_debug.render_boss_helper_hud)
    if not hud_ok and type(core.log_warning) == "function" then
        pcall(core.log_warning, "[Ret Boss Helper HUD] " .. tostring(hud_err))
    end
    if not RetGui or type(RetGui.render) ~= "function" then
        if not ret_gui_error_reported and type(core.log_warning) == "function" then
            ret_gui_error_reported = true
            pcall(core.log_warning, "[Ret Paladin GUI] module unavailable: "
                .. tostring(ret_gui_load_error or "render function missing"))
        end
        return
    end
    local ok, err = pcall(render_custom_gui)
    if not ok then
        latest_runtime_error = "GUI: " .. tostring(err)
        local now = core.time()
        latest_runtime_error_time = string.format("%.2f", now)
        if latest_runtime_error ~= last_gui_runtime_error or now - last_gui_runtime_error_at >= 10 then
            last_gui_runtime_error, last_gui_runtime_error_at = latest_runtime_error, now
            diagnostic_event("ERROR", "ERROR", "gui_runtime_error", { message = latest_runtime_error })
            if type(core.log_warning) == "function" then
                pcall(core.log_warning, "[Ret Paladin GUI] " .. tostring(err))
            end
        end
    end
end
if type(core.register_on_render_window_callback) == "function" then
    core.register_on_render_window_callback(render_ret_window)
elseif type(core.register_on_render_callback) == "function" then
    -- Compatibility path for clients that expose the dedicated window callback
    -- only through the generic render callback. Never register both paths: some
    -- Project Sylvanas builds dispatch both and duplicate the main GUI render.
    core.register_on_render_callback(render_ret_window)
end

local fish_helper = require("common/utility/fish_helper")
local next_fishing_action = 0
local last_fishing_cast = -math.huge

local function run_auto_fishing()
    if not gui.fishing:get_state() then return end
    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid() or player:is_in_combat() then return end

    local now = core.time()
    if now < next_fishing_action then return end

    local bobber = nil
    local objects = core.object_manager.get_all_objects() or {}
    for _, object in pairs(objects) do
        if object and fish_helper:is_fish_bobber(object) then
            bobber = object
            break
        end
    end

    if bobber then
        if fish_helper:does_bobber_have_fish(bobber) then
            local opened = fish_helper:open_loot(bobber)
            if opened then
                fish_helper:loot_all()
                next_fishing_action = now + 1.5
            else
                next_fishing_action = now + 0.35
            end
        else
            next_fishing_action = now + 0.25
        end
        return
    end

    if runtime_debug.is_casting_or_channeling(player) then return end
    if now - last_fishing_cast >= 2.0 then
        local started = core.profession.open_profession(core.profession.FISHING)
        last_fishing_cast = now
        next_fishing_action = now + (started and 1.0 or 2.0)
    end
end

core.register_on_update_callback(run_auto_fishing)

local next_looting_attempt = 0
local next_corpse_interaction = 0
local recently_looted_corpses = {}
local pending_skinning_corpses = {}
local CORPSE_LOOT_RETRY_DELAY = 8.0
local CORPSE_SKIN_QUEUE_LIFETIME = 20.0
local function get_corpse_key(object)
    if object.get_guid then
        local ok, guid = pcall(object.get_guid, object)
        if ok and guid then return tostring(guid) end
    end
    return tostring(object)
end
local function run_auto_looting()
    if not gui.looting:get_state() or gui.fishing:get_state() then return end
    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid()
        or player:is_in_combat() or runtime_debug.is_casting_or_channeling(player) then return end

    local now = core.time()
    if now < next_looting_attempt then return end

    local nearest_corpse, nearest_distance = nil, 35
    local objects = core.object_manager.get_all_objects() or {}
    for _, object in pairs(objects) do
        if object and object.is_valid and object:is_valid()
            and object.is_unit and object:is_unit()
            and object:is_dead()
            and object.can_be_looted and object:can_be_looted()
            and object.has_loot and object:has_loot()
            and (recently_looted_corpses[get_corpse_key(object)] or 0) <= now then
            local distance = player:distance_to(object)
            if distance and distance <= nearest_distance then
                nearest_corpse, nearest_distance = object, distance
            end
        end
    end

    if nearest_corpse then
        local started = core.input.loot_object(nearest_corpse, true)
        next_looting_attempt = now + (started and 1.5 or 1.0)
        next_corpse_interaction = now + (started and 1.5 or 1.0)
        if started then
            local corpse_key = get_corpse_key(nearest_corpse)
            recently_looted_corpses[corpse_key] = now + CORPSE_LOOT_RETRY_DELAY
            pending_skinning_corpses[corpse_key] = {
                object = nearest_corpse,
                ready_at = now + 1.5,
                expires_at = now + CORPSE_SKIN_QUEUE_LIFETIME,
                next_attempt_at = now + 1.5,
                attempts = 0,
            }
        end
    else
        next_looting_attempt = now + 0.5
    end
end

core.register_on_update_callback(run_auto_looting)

local simple_movement = require("common/utility/simple_movement")
local vec3 = require("common/geometry/vector_3")
local movement_owner = nil
local function stop_owned_movement(owner)
    if movement_owner == owner then
        simple_movement:clear_navigation()
        movement_owner = nil
    end
end

local next_skinning_attempt = 0
local next_skinning_target_attempt = 0
local skinning_target_key = nil
local SKIN_INTERACT_DISTANCE = 3.5
runtime_debug.gather_log = { last = nil, file = nil, pending = nil, pending_since = -math.huge }
local function report_skinning_status(message)
    local now = core.time()
    local state = runtime_debug.gather_log
    if message ~= state.pending then
        state.pending, state.pending_since = message, now
    end
    if message ~= state.file then
        state.file = message
        pcall(function()
            core.create_data_folder("ret_paladin_plugin")
            core.create_data_file("ret_paladin_plugin/skinning_status.md")
            core.write_data_file("ret_paladin_plugin/skinning_status.md", message)
        end)
    end
    -- Object-manager corpse counts can oscillate every frame. Only journal a
    -- stable state, while the dedicated status file remains immediately current.
    if message ~= state.last and now - state.pending_since >= 2 then
        state.last = message
        diagnostic_event("INFO", "GATHER", "skinning_state", { detail = message })
    end
end

local function corpse_has_loot_pending(object)
    if not object or not object.can_be_looted or not object.has_loot then return false end
    local ok, pending = pcall(function()
        return object:can_be_looted() and object:has_loot()
    end)
    return ok and pending == true
end

local function run_auto_skinning()
    if not gui.skinning:get_state() then
        stop_owned_movement("skinning")
        report_skinning_status("Auto skinning is off")
        return
    end
    if gui.fishing:get_state() then
        stop_owned_movement("skinning")
        report_skinning_status("Paused while auto fishing is enabled")
        return
    end

    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid() then
        stop_owned_movement("skinning")
        report_skinning_status("Waiting for a valid player")
        return
    end
    if player:is_in_combat() then
        stop_owned_movement("skinning")
        report_skinning_status("Paused during combat")
        return
    end
    if runtime_debug.is_casting_or_channeling(player) then
        stop_owned_movement("skinning")
        report_skinning_status("Paused while the player is casting")
        return
    end

    local now = core.time()
    if gui.looting:get_state() and now < next_corpse_interaction then
        stop_owned_movement("skinning")
        report_skinning_status("Waiting for auto looting to finish")
        return
    end

    local nearest_corpse, nearest_distance = nil, 35
    local pending_skin_key, pending_skin_record = nil, nil
    local pending_count = 0
    for corpse_key, record in pairs(pending_skinning_corpses) do
        local object = record and record.object
        local valid_ok, is_valid = pcall(function()
            return object and object.is_valid and object:is_valid()
        end)
        if not record or now >= record.expires_at or not valid_ok or not is_valid then
            pending_skinning_corpses[corpse_key] = nil
        else
            pending_count = pending_count + 1
            if now >= record.ready_at and now >= record.next_attempt_at
                and not corpse_has_loot_pending(object) then
                local distance = player:distance_to(object)
                if distance and distance <= nearest_distance then
                    nearest_corpse, nearest_distance = object, distance
                    pending_skin_key, pending_skin_record = corpse_key, record
                end
            end
        end
    end

    local dead_units, skin_ready_units, loot_waiting_units = 0, 0, 0
    local objects = core.object_manager.get_all_objects() or {}
    for _, object in pairs(objects) do
        if object and object.is_valid and object:is_valid()
            and object.is_unit and object:is_unit()
            and object:is_dead() then
            dead_units = dead_units + 1
            local ok, can_skin, has_skin = pcall(function()
                local can = object.can_be_skinned and object:can_be_skinned() or false
                local has = object.has_skin and object:has_skin() or false
                return can == true, has == true
            end)
            if ok and (can_skin or has_skin) then
                skin_ready_units = skin_ready_units + 1
                if corpse_has_loot_pending(object) then
                    loot_waiting_units = loot_waiting_units + 1
                else
                    local distance = player:distance_to(object)
                    if distance and distance <= nearest_distance then
                        nearest_corpse, nearest_distance = object, distance
                        pending_skin_key, pending_skin_record = nil, nil
                    end
                end
            end
        end
    end

    if nearest_corpse then
        local corpse_key = pending_skin_key or get_corpse_key(nearest_corpse)
        local current_target = player:get_target()
        local target_key = current_target and get_corpse_key(current_target) or nil
        if target_key ~= corpse_key then
            if skinning_target_key ~= corpse_key or now >= next_skinning_target_attempt then
                skinning_target_key = corpse_key
                next_skinning_target_attempt = now + 0.5
                local target_ok, targeted = pcall(core.input.set_target, nearest_corpse)
                if target_ok and targeted then
                    report_skinning_status("Targeted corpse for skinning")
                    if nearest_distance <= SKIN_INTERACT_DISTANCE then return end
                else
                    report_skinning_status("Could not target corpse; trying direct skin request")
                end
            end
        else
            skinning_target_key = nil
        end

        if nearest_distance > SKIN_INTERACT_DISTANCE then
            local player_pos = player:get_position()
            local corpse_pos = nearest_corpse:get_position()
            if player_pos and corpse_pos then
                local destination = player_pos:get_extended(
                    corpse_pos,
                    nearest_distance - SKIN_INTERACT_DISTANCE
                )
                simple_movement:move_to_position(
                    vec3.new(destination.x, destination.y, destination.z)
                )
                simple_movement:process()
                movement_owner = "skinning"
                report_skinning_status("Moving to a harvestable corpse ("
                    .. tostring(math.floor(nearest_distance + 0.5)) .. " yd)")
            else
                report_skinning_status("Could not read player or corpse position")
            end
            return
        end

        stop_owned_movement("skinning")
        if now < next_skinning_attempt then return end
        local ok, started = pcall(core.input.skin_object, nearest_corpse)
        next_skinning_attempt = now + ((ok and started) and 1.5 or 2.0)
        if pending_skin_record then
            if ok and started then
                pending_skinning_corpses[pending_skin_key] = nil
            else
                pending_skin_record.attempts = pending_skin_record.attempts + 1
                pending_skin_record.next_attempt_at = now + 2.0
            end
        end
        if not ok then
            report_skinning_status("Skin request errored: " .. tostring(started))
        elseif started then
            report_skinning_status("Skin request accepted")
        else
            report_skinning_status("Skin request declined; retry "
                .. tostring(pending_skin_record and pending_skin_record.attempts or 1)
                .. " of queued corpse")
        end
    else
        stop_owned_movement("skinning")
        if gui.looting:get_state() and pending_count > 0 then
            report_skinning_status("Waiting on " .. tostring(pending_count)
                .. " looted corpse(s) to become skin-ready")
        elseif loot_waiting_units > 0 then
            report_skinning_status("Waiting to loot " .. tostring(loot_waiting_units) .. " skinnable corpse(s)")
        else
            report_skinning_status("No harvestable corpse within 35 yd; dead="
                .. tostring(dead_units) .. ", skin-ready=" .. tostring(skin_ready_units)
                .. ", queued=" .. tostring(pending_count))
        end
    end
end

core.register_on_update_callback(run_auto_skinning)

-- Follow the selected target during combat, stopping within melee range.
local MELEE_STOP_DISTANCE = 4.5
local function stop_auto_move()
    stop_owned_movement("auto_move")
end

local function run_auto_move()
    local move_key = gui.auto_move_hotkey:get_key_code()
    -- Any direct movement input belongs to the player. Yield immediately so
    -- automatic chase never fights WASD or the arrow keys.
    if core.input and type(core.input.is_key_pressed) == "function" then
        local manual_key_down = false
        for _, key_code in ipairs({ 0x57, 0x41, 0x53, 0x44, 0x26, 0x25, 0x28, 0x27 }) do
            if key_code ~= move_key then
                local key_ok, pressed = pcall(core.input.is_key_pressed, key_code)
                if key_ok and pressed == true then manual_key_down = true; break end
            end
        end
        if manual_key_down then
            stop_auto_move()
            diagnostic_transition("auto_move_manual_yield", "manual_input", "INFO",
                "SAFETY", "auto_move_held", { reason = "manual_movement_input" })
            return
        end
    end

    if not gui.enabled:get_state() or core.time() < manual_pause_until
        or not gui.auto_move:get_state() then
        stop_auto_move()
        return
    end

    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid()
        or not player:is_in_combat() then
        stop_auto_move()
        return
    end
    -- Do not chase through a movement mechanic. This consumes only positively
    -- observed cast/timer danger; unknown geometry never claims the player is safe.
    if type(runtime_debug.scan_pve_danger) == "function" then
        local zone = runtime_debug.scan_pve_danger(player)
        if zone and zone.active and zone.hit and zone.action == "move" then
            stop_auto_move()
            diagnostic_transition("auto_move_pve_hazard", tostring(zone.label), "INFO",
                "SAFETY", "auto_move_held", { reason = "confirmed_movement_hazard",
                    mechanic = zone.label, remaining = zone.remaining or "unknown" })
            return
        end
    end
    local chase_mode = runtime_debug.active_mode or current_mode
    local pvp_chase = chase_mode == "arena" or chase_mode == "battleground"
        or chase_mode == "world_pvp"
    if pvp_chase and gui.pvp_safe_chase:get_state() == true and runtime_debug.outnumbered
        and smart_setting(gui.pvp_outnumbered_hold, 70) > 0 then
        local hp_ok, hp = pcall(player.get_health, player)
        local max_ok, maximum = pcall(player.get_max_health, player)
        local hp_pct = hp_ok and max_ok and type(hp) == "number" and type(maximum) == "number"
            and maximum > 0 and hp / maximum * 100 or 100
        if hp_pct <= smart_setting(gui.pvp_outnumbered_hold, 70) then
            stop_auto_move()
            return
        end
    end
    if pvp_chase and gui.pvp_safe_chase:get_state() == true and (runtime_debug.healer_state == "dead"
        or runtime_debug.healer_state == "controlled"
        or runtime_debug.healer_state == "out_of_range"
        or runtime_debug.healer_state == "line_of_sight_blocked") then
        stop_auto_move()
        diagnostic_transition("pvp_chase_healer_gate", runtime_debug.healer_state,
            "INFO", "SAFETY", "auto_chase_held", { reason = "healer_unavailable" })
        return
    end

    local target = player:get_target()
    if not target or not target.is_valid or not target:is_valid()
        or target:is_dead() or not player:can_attack(target) then
        stop_auto_move()
        return
    end
    local protected = false
    if pvp_helper and type(pvp_helper.is_damage_immune) == "function" then
        local ok, value = pcall(pvp_helper.is_damage_immune, pvp_helper, target)
        protected = ok and value == true
    end
    if protected then
        stop_auto_move()
        return
    end
    -- A positive line-of-sight block means direct chase would steer into
    -- geometry. Leave navigation to the player until the target is visible.
    if core.graphics and type(core.graphics.is_line_of_sight) == "function" then
        local los_ok, has_los = pcall(core.graphics.is_line_of_sight, player, target)
        if los_ok and has_los == false then
            stop_auto_move()
            diagnostic_transition("auto_move_los", "blocked", "INFO", "SAFETY",
                "auto_move_held", { reason = "target_line_of_sight_blocked" })
            return
        end
    end
    -- Avoid repeatedly feeding movement into roots and hard control.
    for _, state_method in ipairs({ "is_rooted", "is_stunned", "is_feared",
        "is_incapacitated", "is_charmed" }) do
        local state_ok, state_fn = pcall(function() return player[state_method] end)
        if state_ok and type(state_fn) == "function" then
            local call_ok, active = pcall(state_fn, player)
            if call_ok and active == true then
                stop_auto_move()
                diagnostic_transition("auto_move_control", state_method, "INFO", "SAFETY",
                    "auto_move_held", { reason = state_method })
                return
            end
        end
    end
    -- Do not drag the player during a real cast/channel. Ranged actions can
    -- continue while approaching on subsequent updates.
    local casting, channeling = false, false
    if player.is_casting_spell then local ok, value = pcall(player.is_casting_spell, player); casting = ok and value == true end
    if player.is_channeling_spell then local ok, value = pcall(player.is_channeling_spell, player); channeling = ok and value == true end
    if casting or channeling then
        stop_auto_move()
        return
    end

    local player_pos = player:get_position()
    local target_pos = target:get_position()
    if not player_pos or not target_pos then
        stop_auto_move()
        return
    end

    local distance = player:distance_to(target)
    local target_radius = 0
    if target.get_bounding_radius then
        local radius_ok, radius = pcall(target.get_bounding_radius, target)
        if radius_ok and type(radius) == "number" then
            target_radius = math.max(0, math.min(8, radius))
        end
    end
    local stop_distance = MELEE_STOP_DISTANCE + target_radius
    if not distance or distance <= stop_distance then
        stop_auto_move()
        return
    end

    -- Safety and ownership checks above remain per-frame, while path requests
    -- are capped at 10 Hz to avoid rebuilding the same navigation path every tick.
    local move_now = core.time()
    if move_now < (runtime_debug.next_auto_move_at or 0) then return end
    runtime_debug.next_auto_move_at = move_now + 0.10

    -- Stop at the target hitbox edge instead of navigating to a large boss's center.
    local destination = player_pos:get_extended(target_pos, distance - stop_distance)
    simple_movement:move_to_position(vec3.new(destination.x, destination.y, destination.z))
    simple_movement:process()
    movement_owner = "auto_move"
end

core.register_on_update_callback(run_auto_move)

-- Face the selected attackable target while fighting. Use the framework's
-- documented look_at API, which changes facing without moving the character.
-- Throttle calls so the facing input is not repeated every update tick.
local next_auto_face_at = 0
local function run_auto_face()
    if not gui.enabled:get_state() or core.time() < manual_pause_until
        or not gui.auto_face:get_state()
        or not core.input or not core.input.look_at then return end

    -- Manual turn/strafe input owns facing until released.
    if type(core.input.is_key_pressed) == "function" then
        for _, key_code in ipairs({ 0x41, 0x44, 0x25, 0x27 }) do
            local key_ok, pressed = pcall(core.input.is_key_pressed, key_code)
            if key_ok and pressed == true then return end
        end
    end

    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid()
        or not player:is_in_combat() then return end

    local target = player:get_target()
    if not target or not target.is_valid or not target:is_valid()
        or target:is_dead() or not player:can_attack(target) then return end

    if core.graphics and type(core.graphics.is_line_of_sight) == "function" then
        local los_ok, has_los = pcall(core.graphics.is_line_of_sight, player, target)
        if los_ok and has_los == false then return end
    end

    local target_pos = target:get_position()
    if not target_pos then return end

    local clock_ok, now = pcall(core.time)
    if not clock_ok or type(now) ~= "number" or now < next_auto_face_at then return end
    next_auto_face_at = now + 0.10
    pcall(core.input.look_at, target_pos)
end

core.register_on_update_callback(run_auto_face)

local target_line_color = require("common/color").yellow(255)
local healer_line_good_color = require("common/color").new(78, 232, 132, 245)
local healer_line_blocked_color = require("common/color").new(248, 78, 74, 245)
local route_map_color = target_line_color
runtime_debug.danger_zone_red = require("common/color").new(255, 50, 45, 235)
runtime_debug.danger_zone_green = require("common/color").new(58, 232, 112, 220)
runtime_debug.boss_guide_color = require("common/color").new(255, 211, 72, 245)
local route_map_vec2 = nil
pcall(function()
    route_map_vec2 = require("common/geometry/vector_2")
end)

local function make_route_map_vec2(x, y)
    if route_map_vec2 and route_map_vec2.new then return route_map_vec2.new(x, y) end
    return { x = x, y = y }
end

local function clear_route_guide(message)
    diagnostic_transition("route_state", message, "INFO", "ROUTE", "route_state_changed", {
        detail = message,
    })
    route_guide_state.message = message
    route_guide_state.route_name = nil
    route_guide_state.pull_index = 0
    route_guide_state.pull_count = 0
    route_guide_state.targets = {}
    route_guide_state.pull_centers = {}
end

local function get_route_npc_set(guide)
    if guide.npc_set then return guide.npc_set end
    local npc_set = {}
    for _, pull in ipairs(guide.pulls) do
        for _, npc_id in ipairs(pull) do npc_set[npc_id] = true end
    end
    guide.npc_set = npc_set
    return npc_set
end

local function match_live_pack_to_route(cluster, guide)
    local live_counts, live_total = {}, #cluster.targets
    for _, target in ipairs(cluster.targets) do
        live_counts[target.npc_id] = (live_counts[target.npc_id] or 0) + 1
    end

    local best_pull, best_score = 0, 0
    for pull_index, pull in ipairs(guide.pulls) do
        local planned_counts, planned_total = {}, #pull
        for _, npc_id in ipairs(pull) do
            planned_counts[npc_id] = (planned_counts[npc_id] or 0) + 1
        end
        local overlap = 0
        for npc_id, planned_count in pairs(planned_counts) do
            overlap = overlap + math.min(planned_count, live_counts[npc_id] or 0)
        end
        local score = overlap > 0 and overlap / math.sqrt(planned_total * live_total) or 0
        if score > best_score + 0.0001 then
            best_pull, best_score = pull_index, score
        end
    end
    if best_score < 0.20 then return 0, best_score end
    return best_pull, best_score
end

local function add_live_target_to_cluster(target, clusters)
    local best_cluster, best_distance_squared = nil, 30 * 30
    for _, cluster in ipairs(clusters) do
        local dx, dy = target.position.x - cluster.center_x, target.position.y - cluster.center_y
        local dz = target.position.z - cluster.center_z
        local distance_squared = dx * dx + dy * dy
        if math.abs(dz) <= 12 and distance_squared < best_distance_squared then
            best_cluster, best_distance_squared = cluster, distance_squared
        end
    end
    if not best_cluster then
        table.insert(clusters, {
            targets = { target }, center_x = target.position.x,
            center_y = target.position.y, center_z = target.position.z,
        })
        return
    end

    table.insert(best_cluster.targets, target)
    local sum_x, sum_y, sum_z = 0, 0, 0
    for _, member in ipairs(best_cluster.targets) do
        sum_x = sum_x + member.position.x
        sum_y = sum_y + member.position.y
        sum_z = sum_z + member.position.z
    end
    local count = #best_cluster.targets
    best_cluster.center_x, best_cluster.center_y, best_cluster.center_z =
        sum_x / count, sum_y / count, sum_z / count
end

local next_route_guide_refresh = 0
local function update_route_guide()
    local now = core.time()
    if now < next_route_guide_refresh then return end
    next_route_guide_refresh = now + 0.35

    if not gui.route_map:get_state() then clear_route_guide("Off"); return end
    local _, route_guide, inside_dungeon, _, instance_name = get_dungeon_status()
    if not inside_dungeon then clear_route_guide("Enter a supported dungeon"); return end
    if not route_guide then
        clear_route_guide("No built-in route for " .. (instance_name ~= "" and instance_name or "unknown dungeon"))
        return
    end

    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid() then
        clear_route_guide("Waiting for the local player")
        return
    end

    local npc_set = get_route_npc_set(route_guide)
    local live_targets = {}
    local objects_ok, objects = pcall(core.object_manager.get_all_objects)
    if not objects_ok or type(objects) ~= "table" then objects = {} end
    for _, object in pairs(objects) do
        if object and object.is_valid and object.get_npc_id then
            local valid_ok, valid = pcall(object.is_valid, object)
            if valid_ok and valid then
                local npc_ok, npc_id = pcall(object.get_npc_id, object)
                if npc_ok and npc_set[npc_id] then
                    local dead_ok, dead = pcall(object.is_dead, object)
                    local distance_ok, distance = pcall(player.distance_to, player, object)
                    local hostile_ok, hostile = pcall(player.can_attack, player, object)
                    if (not dead_ok or not dead) and distance_ok and type(distance) == "number"
                        and distance <= 250 and (not hostile_ok or hostile) then
                        local position_ok, position = pcall(object.get_position, object)
                        if position_ok and position and type(position.x) == "number"
                            and type(position.y) == "number" and type(position.z) == "number" then
                            table.insert(live_targets, {
                                object = object, npc_id = npc_id,
                                position = position, distance = distance,
                            })
                        end
                    end
                end
            end
        end
    end
    table.sort(live_targets, function(left, right) return left.distance < right.distance end)

    local clusters = {}
    for _, target in ipairs(live_targets) do add_live_target_to_cluster(target, clusters) end
    local best_cluster_by_pull = {}
    for _, cluster in ipairs(clusters) do
        local pull_index, score = match_live_pack_to_route(cluster, route_guide)
        if pull_index > 0 then
            local distance = math.huge
            for _, target in ipairs(cluster.targets) do distance = math.min(distance, target.distance) end
            local existing = best_cluster_by_pull[pull_index]
            if not existing or distance < existing.distance then
                local sum_x, sum_y, sum_z = 0, 0, 0
                for _, target in ipairs(cluster.targets) do
                    sum_x = sum_x + target.position.x
                    sum_y = sum_y + target.position.y
                    sum_z = sum_z + target.position.z
                end
                local center = vec3.new(sum_x / #cluster.targets, sum_y / #cluster.targets, sum_z / #cluster.targets)
                local radius = 0
                for _, target in ipairs(cluster.targets) do
                    local dx, dy = target.position.x - center.x, target.position.y - center.y
                    radius = math.max(radius, math.sqrt(dx * dx + dy * dy))
                end
                best_cluster_by_pull[pull_index] = {
                    pull_index = pull_index, center = center,
                    radius = math.min(20, math.max(6, radius + 4)),
                    targets = cluster.targets, distance = distance, score = score,
                }
            end
        end
    end

    local pull_centers = {}
    for pull_index = 1, #route_guide.pulls do
        if best_cluster_by_pull[pull_index] then
            table.insert(pull_centers, best_cluster_by_pull[pull_index])
        end
    end
    local next_pack = pull_centers[1]
    route_guide_state.route_name = route_guide.name
    route_guide_state.pull_count = #route_guide.pulls
    route_guide_state.pull_index = next_pack and next_pack.pull_index or 0
    route_guide_state.targets = next_pack and next_pack.targets or {}
    route_guide_state.pull_centers = pull_centers
    if not next_pack then
        route_guide_state.message = route_guide.name .. " • route auto-loaded • looking for a matching pack"
    else
        route_guide_state.message = route_guide.name .. " • next pack "
            .. tostring(next_pack.pull_index) .. "/" .. tostring(#route_guide.pulls)
            .. " • " .. tostring(#next_pack.targets) .. " enemies"
    end
    diagnostic_transition("route_state", route_guide_state.message, "INFO", "ROUTE",
        "route_state_changed", {
            dungeon = route_guide.name, pull = route_guide_state.pull_index,
            pulls = route_guide_state.pull_count, targets = #route_guide_state.targets,
        })
end

core.register_on_update_callback(update_route_guide)

local function normalized_map_point(world_position)
    if not core.game_ui or not core.game_ui.world_pos_to_map_pos_normalized then return nil end
    local ok, point = pcall(core.game_ui.world_pos_to_map_pos_normalized, world_position)
    if not ok or not point or type(point.x) ~= "number" or type(point.y) ~= "number"
        or point.x < 0 or point.x > 1 or point.y < 0 or point.y > 1 then return nil end
    return point
end

local function draw_route_overview(player_pos)
    if not route_guide_state.route_name then return end
    local size_ok, screen_size = pcall(core.graphics.get_screen_size)
    if not size_ok or not screen_size or type(screen_size.x) ~= "number"
        or type(screen_size.y) ~= "number" or screen_size.x < 300 or screen_size.y < 250 then return end

    local panel_width, panel_height = 248, 286
    local panel_x, panel_y = screen_size.x - panel_width - 24, 90
    core.graphics.rect_2d(make_route_map_vec2(panel_x, panel_y), panel_width, panel_height, green, 2, 4)
    core.graphics.text_2d(route_guide_state.route_name,
        make_route_map_vec2(panel_x + 10, panel_y + 12), 13, green, false)
    core.graphics.text_2d(route_guide_state.message,
        make_route_map_vec2(panel_x + 10, panel_y + 32), 10, route_map_color, false)

    local points, player_point = {}, normalized_map_point(player_pos)
    if player_point then table.insert(points, { pull_index = 0, x = player_point.x, y = player_point.y, is_player = true }) end
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local point = normalized_map_point(pack.center)
        if point then table.insert(points, { pull_index = pack.pull_index, x = point.x, y = point.y }) end
    end
    if #route_guide_state.pull_centers == 0 then
        core.graphics.text_2d("Waiting for a live pack to load.",
            make_route_map_vec2(panel_x + 10, panel_y + 72), 10, green, false)
        return
    end

    local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge
    for _, point in ipairs(points) do
        min_x, max_x = math.min(min_x, point.x), math.max(max_x, point.x)
        min_y, max_y = math.min(min_y, point.y), math.max(max_y, point.y)
    end
    local content_x, content_y = panel_x + 16, panel_y + 60
    local content_width, content_height = panel_width - 32, panel_height - 78
    local span_x, span_y = math.max(0.0001, max_x - min_x), math.max(0.0001, max_y - min_y)
    local scale = math.min(content_width / span_x, content_height / span_y)
    local drawn_width, drawn_height = span_x * scale, span_y * scale
    local offset_x, offset_y = content_x + (content_width - drawn_width) / 2, content_y + (content_height - drawn_height) / 2
    local screen_points = {}
    for _, point in ipairs(points) do
        local screen_point = make_route_map_vec2(
            offset_x + (point.x - min_x) * scale, offset_y + (max_y - point.y) * scale)
        if point.is_player then core.graphics.circle_2d_filled(screen_point, 5, green)
        else screen_points[point.pull_index] = screen_point end
    end

    local previous_point = player_point and make_route_map_vec2(
        offset_x + (player_point.x - min_x) * scale, offset_y + (max_y - player_point.y) * scale) or nil
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local point = screen_points[pack.pull_index]
        if point then
            if previous_point then core.graphics.line_2d(previous_point, point, route_map_color, 2) end
            local active = pack.pull_index == route_guide_state.pull_index
            local color = active and route_map_color or green
            core.graphics.circle_2d_filled(point, active and 7 or 4, color)
            core.graphics.text_2d(tostring(pack.pull_index),
                make_route_map_vec2(point.x + 5, point.y - 5), 9, color, false)
            previous_point = point
        end
    end
end

local function draw_route_map_markers(player_pos)
    if not core.game_ui or not core.game_ui.is_map_open then return end
    local open_ok, map_open = pcall(core.game_ui.is_map_open)
    if not open_ok or not map_open then return end
    local current_map_ok, current_map_id = pcall(core.game_ui.get_current_map_id)
    local player_map_ok, player_map_id = pcall(core.get_map_id)
    if not current_map_ok or not player_map_ok or type(current_map_id) ~= "number"
        or type(player_map_id) ~= "number" or current_map_id <= 0 or current_map_id ~= player_map_id then return end

    local left_ok, map_top_left = pcall(core.game_ui.get_map_top_left)
    local right_ok, map_bottom_right = pcall(core.game_ui.get_map_bottom_right)
    if not left_ok or not right_ok or not map_top_left or not map_bottom_right
        or not map_top_left.x or not map_top_left.y or not map_bottom_right.x or not map_bottom_right.y then return end

    local function to_screen_point(position)
        local normalized = normalized_map_point(position)
        if not normalized then return nil end
        local ui_position = make_route_map_vec2(
            map_top_left.x + (map_bottom_right.x - map_top_left.x) * normalized.x,
            map_top_left.y + (map_bottom_right.y - map_top_left.y) * normalized.y)
        local ok, screen_position = pcall(core.game_ui.ui_pos_to_screen_pos, ui_position)
        if not ok or not screen_position or type(screen_position.x) ~= "number"
            or type(screen_position.y) ~= "number" then return nil end
        return screen_position
    end

    local player_point = to_screen_point(player_pos)
    if not player_point then return end
    local previous_point = player_point
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local point = to_screen_point(pack.center)
        if point then
            core.graphics.line_2d(previous_point, point, route_map_color, 3)
            local active = pack.pull_index == route_guide_state.pull_index
            local color = active and route_map_color or green
            core.graphics.circle_2d_filled(point, active and 8 or 5, color)
            core.graphics.text_2d("Pull " .. tostring(pack.pull_index),
                make_route_map_vec2(point.x + 8, point.y - 8), 11, color, false)
            previous_point = point
        end
    end
    for _, target in ipairs(route_guide_state.targets) do
        local point = to_screen_point(target.position)
        if point then core.graphics.circle_2d(point, 8, route_map_color, 2) end
    end
end

local function render_unit_call(unit, method_name, ...)
    if not unit then return nil end
    local member_ok, method = pcall(function() return unit[method_name] end)
    if not member_ok or type(method) ~= "function" then return nil end
    local call_ok, value = pcall(method, unit, ...)
    return call_ok and value or nil
end

local cached_healer, next_healer_scan = nil, -math.huge
local function find_render_healer(player)
    local now_ok, now = pcall(core.time)
    now = now_ok and type(now) == "number" and now or 0
    if now < next_healer_scan then
        if cached_healer and render_unit_call(cached_healer, "is_valid") == true
            and render_unit_call(cached_healer, "is_dead") ~= true then return cached_healer end
        return nil
    end
    next_healer_scan = now + 0.5

    local best, best_distance = nil, math.huge
    local seen = {}
    local function add(unit, known_group_member)
        if not unit or unit == player or render_unit_call(unit, "is_valid") ~= true
            or render_unit_call(unit, "is_dead") == true
            or render_unit_call(unit, "is_player") ~= true then return end
        local guid = render_unit_call(unit, "get_guid")
        local key = guid or tostring(unit)
        if seen[key] then return end
        seen[key] = true

        local hostile = render_unit_call(unit, "is_enemy_with", player) == true
        local friendly = known_group_member == true
            or render_unit_call(unit, "is_party_member") == true
            or render_unit_call(unit, "is_friend_with", player) == true
        if hostile or not friendly then return end

        local role = render_unit_call(unit, "get_group_role")
        if role == nil then role = render_unit_call(unit, "get_role") end
        local is_healer = role == 1 or render_unit_call(unit, "is_healer") == true
        if not is_healer then return end

        local distance_ok, distance = pcall(function() return player:distance_to(unit) end)
        if not distance_ok or type(distance) ~= "number" then distance = math.huge end
        if distance < best_distance then best, best_distance = unit, distance end
    end

    if core.object_manager.get_party_frames then
        local ok, frames = pcall(core.object_manager.get_party_frames)
        if ok and type(frames) == "table" then
            for _, unit in pairs(frames) do add(unit, true) end
        end
    end
    if core.object_manager.get_party_members then
        local ok, members = pcall(core.object_manager.get_party_members)
        if ok and type(members) == "table" then
            for _, member in pairs(members) do
                if type(member) == "table" then add(member.object, true)
                else add(member, true) end
            end
        end
    end
    if core.object_manager.get_all_objects then
        local ok, objects = pcall(core.object_manager.get_all_objects)
        if ok and type(objects) == "table" then
            for _, unit in pairs(objects) do add(unit, false) end
        end
    end
    cached_healer = best
    return best
end

runtime_debug.healer_line_reachable = false
core.register_on_render_callback(function()
    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid() then return end
    if player:get_class() ~= PALADIN_CLASS_ID
        or not plugin.is_ret_spec(core.spell_book.get_specialization_id()) then return end
    local player_pos = player:get_position()
    if not player_pos then return end
    local overlay_mode = runtime_debug.active_mode or current_mode
    local pvp_lines = gui.pvp_lines:get_state() == true
        and (overlay_mode == "arena" or overlay_mode == "battleground"
            or overlay_mode == "world_pvp")

    if gui.target_line:get_state() or pvp_lines then
        local target = render_unit_call(player, "get_target")
        if render_unit_call(target, "is_valid") == true
            and render_unit_call(target, "is_dead") ~= true
            and render_unit_call(player, "can_attack", target) == true then
            local target_pos = render_unit_call(target, "get_position")
            if target_pos then
                pcall(core.graphics.line_3d, player_pos, target_pos, target_line_color, 3, 0, false)
                pcall(core.graphics.circle_3d, target_pos, 1.25, target_line_color, 2, 2.5)
            end
        end
    end

    if gui.healer_line:get_state() or pvp_lines then
        local healer = find_render_healer(player)
        local healer_pos = render_unit_call(healer, "get_position")
        if healer and healer_pos then
            local los_ok, has_los = false, false
            if core.graphics and type(core.graphics.is_line_of_sight) == "function" then
                los_ok, has_los = pcall(core.graphics.is_line_of_sight, healer, player)
            end
            if not los_ok then
                local native_los = render_unit_call(healer, "has_line_of_sight", player)
                if native_los == nil then
                    native_los = render_unit_call(player, "has_line_of_sight", healer)
                end
                if type(native_los) == "boolean" then los_ok, has_los = true, native_los end
            end
            local distance_ok, distance = pcall(function() return player:distance_to(healer) end)
            local heal_immune = render_unit_call(player, "is_immune_to_heal") == true
            if pvp_helper and type(pvp_helper.is_immune_to_heal) == "function" then
                local immune_ok, immune = pcall(pvp_helper.is_immune_to_heal, pvp_helper, player, 0)
                heal_immune = heal_immune or (immune_ok and immune == true)
            end
            -- Use separate enter/exit distances so normal movement around the
            -- 40-yard boundary does not flicker the line and flood diagnostics.
            local range_limit = runtime_debug.healer_line_reachable and 41 or 39
            local can_heal = los_ok and has_los == true
                and distance_ok and type(distance) == "number" and distance <= range_limit
                and not heal_immune
            runtime_debug.healer_line_reachable = can_heal
            diagnostic_transition("healer_line_state", can_heal and "healable" or "blocked", "INFO",
                "OVERLAY", "healer_line_changed", {
                    healer = render_unit_call(healer, "get_name") or "unknown",
                    distance = distance_ok and type(distance) == "number" and string.format("%.1f", distance) or "unknown",
                    line_of_sight = los_ok and has_los == true, heal_immune = heal_immune,
                })
            local line_color = can_heal and healer_line_good_color or healer_line_blocked_color
            pcall(core.graphics.line_3d, player_pos, healer_pos, line_color, 4, 0, false)
        else
            runtime_debug.healer_line_reachable = false
            diagnostic_transition("healer_line_state", "no_healer", "INFO", "OVERLAY",
                "healer_line_changed", { reason = "no valid group healer exposed by client" })
        end
    end

    if gui.pve_danger_zones:get_state() and type(runtime_debug.scan_pve_danger) == "function" then
        local zone = runtime_debug.scan_pve_danger(player)
        if zone and zone.active then
            local zone_color = zone.hit and runtime_debug.danger_zone_red
                or runtime_debug.danger_zone_green
            pcall(core.graphics.circle_3d, player_pos,
                smart_setting(gui.pve_danger_radius, 5), zone_color, 5, 2.5)
            pcall(core.graphics.text_3d,
                (zone.hit and "DANGER: " or "NOT TARGETED: ") .. tostring(zone.label or "Incoming mechanic"),
                player_pos, 14, zone_color, true)
        end
    end

    if gui.s2_boss_guide:get_state() and type(runtime_debug.scan_s2_boss_guide) == "function" then
        local guide = runtime_debug.scan_s2_boss_guide(player)
        if guide then
            local guide_color = guide.kind == "move" and runtime_debug.danger_zone_red
                or guide.kind == "stack" and runtime_debug.danger_zone_green
                or runtime_debug.boss_guide_color
            pcall(core.graphics.text_3d, tostring(guide.instruction), player_pos,
                16, guide_color, true)
            if guide.kind == "interrupt" then
                local boss_pos = render_unit_call(guide.boss, "get_position")
                if boss_pos then
                    pcall(core.graphics.line_3d, player_pos, boss_pos, guide_color, 5, 0, false)
                    pcall(core.graphics.circle_3d, boss_pos, 2.0, guide_color, 4, 2.5)
                end
            elseif guide.kind == "stack" then
                pcall(core.graphics.circle_3d, player_pos, 4.0, guide_color, 5, 2.5)
            end
        end
    end

    if not gui.route_map:get_state() or not route_guide_state.route_name then return end
    pcall(draw_route_overview, player_pos)
    local previous_position = player_pos
    for _, pack in ipairs(route_guide_state.pull_centers) do
        local is_next = pack.pull_index == route_guide_state.pull_index
        pcall(core.graphics.line_3d, previous_position, pack.center, route_map_color, 3, 0, false)
        pcall(core.graphics.circle_3d, pack.center, is_next and pack.radius or 2.0,
            is_next and route_map_color or green, is_next and 3 or 1, 2.5)
        pcall(core.graphics.text_3d, "Pull " .. tostring(pack.pull_index), pack.center,
            is_next and 14 or 10, is_next and route_map_color or green, true)
        previous_position = pack.center
    end
    for _, target_info in ipairs(route_guide_state.targets) do
        pcall(core.graphics.circle_3d, target_info.position, 2.5, route_map_color, 3, 2.5)
    end
    if route_guide_state.pull_index > 0 then pcall(draw_route_map_markers, player_pos) end
end)

local function get_threshold(slider)
    return math.max(0, math.min(80, slider:get()))
end

local function below_threshold(slider, health_percent)
    local threshold = get_threshold(slider)
    return threshold > 0 and health_percent <= threshold
end

local has_buff, cast, safe_unit_call
local last_defensive_requests, last_major_defensive_by_target = {}, {}
local buff_manager = require("common/modules/buff_manager")
runtime_debug.health_prediction = select(2, pcall(require, "common/modules/health_prediction"))
runtime_debug.combat_forecast = select(2, pcall(require, "common/modules/combat_forecast"))

local function has_major_defensive_active(unit)
    return has_buff(unit, SPELL.DIVINE_SHIELD)
        or has_buff(unit, SPELL.SHIELD_OF_VENGEANCE)
        or has_buff(unit, SPELL.DIVINE_PROTECTION)
        or has_buff(unit, SPELL.SACROSANCT_BARRIER)
        or has_buff(unit, SPELL.BLESSING_OF_PROTECTION)
        or has_buff(unit, SPELL.BLESSING_OF_SPELLWARDING)
        or has_buff(unit, SPELL.BLESSING_OF_SACRIFICE)
end

local function is_major_defensive_spell(spell_id)
    return spell_id == SPELL.LAY_ON_HANDS
        or spell_id == SPELL.DIVINE_SHIELD
        or spell_id == SPELL.SHIELD_OF_VENGEANCE
        or spell_id == SPELL.DIVINE_PROTECTION
        or spell_id == SPELL.BLESSING_OF_PROTECTION
        or spell_id == SPELL.BLESSING_OF_SPELLWARDING
        or spell_id == SPELL.BLESSING_OF_SACRIFICE
end

local function cast_defensive(spell_id, player, target)
    target = target or player
    if spell_id == SPELL.BLESSING_OF_SACRIFICE then
        local grouped = safe_unit_call(target, "is_party_member") == true
        if not grouped and core.object_manager.get_party_frames then
            local ok, frames = pcall(core.object_manager.get_party_frames)
            if ok and type(frames) == "table" then
                local guid = safe_unit_call(target, "get_guid")
                for _, member in pairs(frames) do
                    if member == target or (guid and safe_unit_call(member, "get_guid") == guid) then
                        grouped = true
                        break
                    end
                end
            end
        end
        if target == player or not grouped then
            diagnostic_transition("sacrifice_group_gate", "not_grouped", "INFO", "SUPPORT",
                "sacrifice_target_ineligible", { target = safe_unit_call(target, "get_name") or "unknown" })
            return false
        end
    end
    local now = core.time()
    local target_key = safe_unit_call(target, "get_guid") or tostring(target)
    local request_key = target_key .. ":" .. tostring(spell_id)
    if now - (last_defensive_requests[request_key] or -math.huge) < 0.75 then return false end
    local major_elapsed = now - (last_major_defensive_by_target[target_key] or -math.huge)
    if is_major_defensive_spell(spell_id) and major_elapsed < DEFENSIVE_GAP_SECONDS then
        diagnostic_transition("defensive_block", "target_major_gap", "INFO", "DEFENSIVE", "blocked", {
            spell_id = spell_id, remaining = string.format("%.2f", DEFENSIVE_GAP_SECONDS - major_elapsed),
        })
        return false
    end
    if is_major_defensive_spell(spell_id) and target == player and has_major_defensive_active(player) then
        diagnostic_transition("defensive_block", "self_major_active", "INFO", "DEFENSIVE", "blocked",
            { spell_id = spell_id, reason = "major defensive already active" })
        return false
    end
    if is_major_defensive_spell(spell_id) and target ~= player and has_major_defensive_active(target) then
        diagnostic_transition("defensive_block", "ally_major_active", "INFO", "DEFENSIVE", "blocked",
            { spell_id = spell_id, reason = "ally already has major defensive" })
        return false
    end
    if has_buff(target, spell_id) then
        diagnostic_transition("defensive_block", "same_buff_active", "INFO", "DEFENSIVE", "blocked",
            { spell_id = spell_id, reason = "same effect already active" })
        return false
    end
    if cast(spell_id, target, player) then
        last_defensive_requests[request_key] = now
        if is_major_defensive_spell(spell_id) then last_major_defensive_by_target[target_key] = now end
        LOG.state.defensive_block = nil
        diagnostic_event("ACTION", target == player and "DEFENSIVE" or "SUPPORT", "defensive_cast", {
            spell_id = spell_id, target = safe_unit_call(target, "get_name") or "unknown",
        })
        return true
    end
    return false
end

local function aura_matches(aura, spell_id)
    if not aura then return false end
    for _, field in ipairs({ "buff_id", "spell_id", "debuff_id", "id" }) do
        local ok, matches = pcall(function() return tonumber(aura[field]) == spell_id end)
        if ok and matches then return true end
    end
    return false
end

local function find_raw_aura(unit, spell_id, methods)
    for _, method in ipairs(methods) do
        local ok, auras = pcall(function() return unit[method](unit) end)
        if ok and type(auras) == "table" then
            for _, aura in pairs(auras) do
                if aura_matches(aura, spell_id) then return aura end
            end
        end
    end
    return nil
end

has_buff = function(unit, spell_id)
    if not unit then return false end

    -- A positive manager result is useful; an inactive result is not proof that
    -- secret/protected aura data is absent, so continue to the raw aura list.
    if buff_manager then
        local ok, data = pcall(function()
            return buff_manager:get_aura_data(unit, { spell_id })
        end)
        if ok and data then
            local active_ok, is_active = pcall(function() return data.is_active end)
            if active_ok and is_active == true then return true end
        end
    end

    return find_raw_aura(unit, spell_id, { "get_auras", "get_buffs" }) ~= nil
end

local function has_debuff(unit, spell_id)
    if not unit then return false end
    if buff_manager then
        local ok, data = pcall(function()
            return buff_manager:get_debuff_data(unit, { spell_id })
        end)
        if ok and data then
            local active_ok, active = pcall(function() return data.is_active end)
            if active_ok and active == true then return true end
        end
    end
    return find_raw_aura(unit, spell_id, { "get_debuffs", "get_auras" }) ~= nil
end

local function has_any_buff(unit, spell_ids)
    for _, spell_id in ipairs(spell_ids) do
        if has_buff(unit, spell_id) then return true end
    end
    return false
end

local function get_buff_stacks(unit, spell_id)
    if not unit then return 0 end
    local aura = find_raw_aura(unit, spell_id, { "get_auras", "get_buffs" })
    if aura then
        local ok, count = pcall(function()
            local value = aura.count
            return type(value) == "number" and value >= 1 and value <= 100 and value or 1
        end)
        return ok and count or 1
    end
    return 0
end

runtime_debug.aura_remaining = function(unit, spell_id)
    local aura = find_raw_aura(unit, spell_id, { "get_auras", "get_buffs" })
    if not aura then return nil end
    local direct
    pcall(function()
        direct = tonumber(aura.remaining or aura.remaining_time or aura.time_left or aura.timeLeft)
    end)
    if direct and direct >= 0 then
        if direct > 100000 then direct = direct / 1000 end
        return direct
    end
    local expires
    pcall(function()
        expires = tonumber(aura.expiration_time or aura.expire_time or aura.expires_at or aura.expirationTime)
    end)
    if not expires or expires <= 0 then return nil end
    if expires > 100000 then expires = expires / 1000 end
    return math.max(0, expires - core.time())
end

local function wings_active(player)
    return has_any_buff(player, { SPELL.AVENGING_WRATH, SPELL.RADIANT_GLORY_WINGS })
end

local function cooldown_left(spell_id)
    local ok, seconds = pcall(core.spell_book.get_spell_cooldown, spell_id)
    if ok and type(seconds) == "number" then return math.max(0, seconds) end
    return math.huge
end

local function get_spell_charges(spell_id)
    if not core.spell_book.get_spell_charge then return 0, 0 end
    local current_ok, current = pcall(core.spell_book.get_spell_charge, spell_id)
    local max_ok, maximum = pcall(core.spell_book.get_spell_charge_max, spell_id)
    if not current_ok or not max_ok or type(current) ~= "number"
        or type(maximum) ~= "number" then
        return 0, 0
    end
    return current, maximum
end

-- Herald of the Sun replaces Word of Glory with Eternal Flame. Resolve the
-- live override so self-healing and teammate support work for both hero trees.
local function word_of_glory_spell()
    if core.spell_book.get_override_spell_id then
        local ok, override = pcall(core.spell_book.get_override_spell_id, SPELL.WORD_OF_GLORY)
        if ok and type(override) == "number" and override > 0
            and override ~= SPELL.WORD_OF_GLORY then return override end
    end
    return SPELL.WORD_OF_GLORY
end

local function spell_ready(spell_id, target, player, proc_spell)
    if core.time() < (runtime_debug.unlearned_spell_until[spell_id] or -math.huge) then return false end
    if not proc_spell and not core.spell_book.is_spell_known(spell_id) then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0.15 then return false end
    if target and core.spell_book.is_spell_in_range then
        if not core.spell_book.is_spell_in_range(spell_id, target, player) then
            return false
        end
    end
    return true
end

runtime_debug.spell_target_reachable = function(spell_id, target, player)
    if not target or safe_unit_call(target, "is_valid") ~= true
        or safe_unit_call(target, "is_dead") == true then return false end
    if core.spell_book.is_spell_in_range then
        local ok, in_range = pcall(core.spell_book.is_spell_in_range, spell_id, target, player)
        if ok and in_range == false then return false end
    end
    local los = safe_unit_call(player, "has_line_of_sight", target)
    if los == nil then los = safe_unit_call(target, "has_line_of_sight", player) end
    return los ~= false
end

local last_cast_requests = {}
local cast_failure_state = {}
local measured_cast_latency = 0.25
local function cast_failure_key(spell_id, target_guid)
    return tostring(spell_id) .. ":" .. tostring(target_guid or "none")
end
local function record_cast_failure(spell_id, target_guid, now, reason)
    if gui.cast_failure_backoff:get_state() ~= true then return end
    local key = cast_failure_key(spell_id, target_guid)
    local row = cast_failure_state[key] or { count = 0 }
    row.count = math.min(5, row.count + 1)
    row.last = now
    row.until_time = now + math.min(3, 0.25 * 2 ^ (row.count - 1))
    cast_failure_state[key] = row
    diagnostic_transition("cast_backoff_" .. key, tostring(row.count), "WARN", "CAST",
        "cast_failure_backoff", { spell_id = spell_id, target_guid = target_guid or "none",
            failures = row.count, retry_in = string.format("%.2f", row.until_time - now), reason = reason })
end
local function expire_stale_cast_requests(now)
    local timeout = math.max(1.2, math.min(3, measured_cast_latency * 4 + 0.8))
    for spell_id, request in pairs(LOG.pending) do
        if now - request.time >= timeout then
            LOG.pending[spell_id] = nil
            if runtime_debug.global_cast_pending == spell_id then
                runtime_debug.global_cast_pending = nil
            end
            record_cast_failure(spell_id, request.target_guid, now, "no_confirming_event")
            diagnostic_event("WARN", "CAST", "cast_request_timeout", {
                spell_id = spell_id, target = request.target, timeout = string.format("%.2f", timeout),
            })
        end
    end
end
cast = function(spell_id, target, player, proc_spell)
    local now = core.time()
    expire_stale_cast_requests(now)
    local urgent_request = spell_id == SPELL.REBUKE or is_major_defensive_spell(spell_id)
    if not urgent_request and runtime_debug.global_cast_pending
        and LOG.pending[runtime_debug.global_cast_pending] then
        return false
    end
    local request_key = tostring(spell_id) .. ":" .. tostring(safe_unit_call(target, "get_guid") or target)
    if now - (last_cast_requests[request_key] or -math.huge) < 0.12 then return false end
    local target_guid = safe_unit_call(target, "get_guid")
    local failure = cast_failure_state[cast_failure_key(spell_id, target_guid)]
    if failure and now < (failure.until_time or 0) then return false end
    local pending = LOG.pending[spell_id]
    local pending_timeout = math.max(1.2, math.min(3, measured_cast_latency * 4 + 0.8))
    if pending and now - pending.time < pending_timeout then return false end
    if not spell_ready(spell_id, target, player, proc_spell) then
        diagnostic_transition("cast_not_ready_" .. tostring(spell_id), "not_ready", "INFO", "CAST",
            "cast_not_ready", { spell_id = spell_id,
                target = safe_unit_call(target, "get_name") or "unknown", mode = current_mode })
        return false
    end
    last_cast_requests[request_key] = now
    local ok, accepted = pcall(core.input.cast_target_spell, spell_id, target)
    if ok and accepted == true then
        local spell_name = tostring(spell_id)
        if core.spell_book.get_spell_name then
            local name_ok, name = pcall(core.spell_book.get_spell_name, spell_id)
            if name_ok and type(name) == "string" then spell_name = name end
        end
        last_action = spell_name .. " → " .. tostring(safe_unit_call(target, "get_name") or "target")
        local category = "CAST"
        if spell_id == SPELL.REBUKE or spell_id == SPELL.HAMMER_OF_JUSTICE
            or spell_id == SPELL.BLINDING_LIGHT then category = "INTERRUPT"
        elseif spell_id == SPELL.DEVOTION_AURA or spell_id == SPELL.CONCENTRATION_AURA
            or spell_id == SPELL.CRUSADER_AURA then category = "AURA"
        elseif spell_id == SPELL.LAY_ON_HANDS or spell_id == SPELL.DIVINE_SHIELD
            or spell_id == SPELL.SHIELD_OF_VENGEANCE or spell_id == SPELL.DIVINE_PROTECTION
            or spell_id == SPELL.WORD_OF_GLORY or spell_id == word_of_glory_spell()
            or spell_id == SPELL.HOLY_LIGHT
            or spell_id == SPELL.BLESSING_OF_PROTECTION or spell_id == SPELL.BLESSING_OF_SACRIFICE
            or spell_id == SPELL.BLESSING_OF_FREEDOM or spell_id == SPELL.BLESSING_OF_SANCTUARY
            or spell_id == SPELL.CLEANSE_TOXINS then
            category = target == player and "DEFENSIVE" or "SUPPORT"
        end
        local hp, max_hp = safe_unit_call(player, "get_health"), safe_unit_call(player, "get_max_health")
        local player_hp = type(hp) == "number" and type(max_hp) == "number" and max_hp > 0
            and math.floor(hp * 1000 / max_hp + 0.5) / 10 or "unknown"
        diagnostic_event("ACTION", category, "cast_accepted", {
            spell = spell_name, spell_id = spell_id, target = safe_unit_call(target, "get_name") or "unknown",
            mode = current_mode, hero = get_hero_tree(), player_hp = player_hp,
            holy_power = safe_unit_call(player, "get_power", HOLY_POWER) or "unknown",
        })
        LOG.pending[spell_id] = { time = now, target = safe_unit_call(target, "get_name") or "unknown",
            target_guid = target_guid, target_role = safe_unit_call(target, "get_group_role"),
            spell = spell_name, category = category }
        runtime_debug.global_cast_pending = spell_id
        combat_stats.actions = combat_stats.actions + 1
        if category == "DEFENSIVE" then combat_stats.defensive = combat_stats.defensive + 1
        elseif category == "SUPPORT" then combat_stats.support = combat_stats.support + 1
        elseif category == "INTERRUPT" then combat_stats.interrupt = combat_stats.interrupt + 1
        else combat_stats.damage = combat_stats.damage + 1 end
        if spell_id == SPELL.AVENGING_WRATH or spell_id == SPELL.EXECUTION_SENTENCE
            or spell_id == SPELL.WAKE_OF_ASHES or spell_id == SPELL.DIVINE_TOLL then
            combat_stats.burst = combat_stats.burst + 1
        end
        if spell_id == SPELL.HAMMER_OF_JUSTICE or spell_id == SPELL.BLINDING_LIGHT then
            combat_stats.cc = combat_stats.cc + 1
        end
        if category == "DEFENSIVE" or category == "SUPPORT" then combat_stats.saves = combat_stats.saves + 1 end
        LOG.state["cast_declined_" .. tostring(spell_id)] = nil
        LOG.state["cast_not_ready_" .. tostring(spell_id)] = nil
        return true
    end
    diagnostic_transition("cast_declined_" .. tostring(spell_id), "declined", "WARN", "CAST",
        "cast_request_declined", { spell_id = spell_id, target = safe_unit_call(target, "get_name") or "unknown" })
    if gui.cast_failure_backoff:get_state() == true then
        local key = cast_failure_key(spell_id, target_guid)
        local row = cast_failure_state[key] or { count = 0 }
        row.until_time = now + 0.20
        cast_failure_state[key] = row
    end
    return false
end

runtime_debug.run_world_pve_flash = function(player)
    local raw = read_mode(core.get_instance_type)
    local kind = type(raw) == "string" and string.lower(raw) or ""
    local world = raw == nil or kind == "" or kind == "none" or kind == "world"
        or kind == "open_world" or kind == "outdoor"
    if not world then return false end
    if core.delves and read_mode(core.delves.is_in_delve) == true then return false end
    if pvp_helper and type(pvp_helper.is_pvp_scenario) == "function" then
        local ok, active = pcall(pvp_helper.is_pvp_scenario, pvp_helper)
        if ok and active == true then return false end
    end
    if safe_unit_call(player, "is_dead") == true or safe_unit_call(player, "is_ghost") == true
        or safe_unit_call(player, "is_mounted") == true or safe_unit_call(player, "is_in_vehicle") == true then
        return false
    end
    local now = core.time()
    if now - runtime_debug.last_world_flash < 60 or now < runtime_debug.next_world_flash_retry then
        return false
    end
    if cast(SPELL.FLASH_OF_LIGHT, player, player) then
        runtime_debug.last_world_flash = now
        runtime_debug.next_world_flash_retry = now + 60
        diagnostic_event("ACTION", "SUPPORT", "world_pve_flash_of_light", {
            interval = 60, context = kind ~= "" and kind or "world",
        })
        return true
    end
    runtime_debug.next_world_flash_retry = now + 2
    return false
end

-- Auto-select aura using positive aura observations and confirmed cast events.
-- Unknown/hidden aura data is not treated as proof that an aura is absent.
local AURA_CAST_RETRY_SECONDS = 8
local AURA_CONFIRMED_FLOOR_SECONDS = 30
local last_confirmed_aura = nil
local last_confirmed_aura_at = -math.huge
local last_aura_attempt = -math.huge
local group_aura_scan_time = -math.huge
local group_paladin_has_devotion_cache = false

safe_unit_call = function(unit, method_name, ...)
    if not unit then return nil end
    local method_ok, method = pcall(function() return unit[method_name] end)
    if not method_ok or type(method) ~= "function" then return nil end
    local call_ok, value = pcall(method, unit, ...)
    if call_ok then return value end
    return nil
end

-- Keep cast and channel detection in runtime state so expanding interrupt
-- coverage does not consume another local in the already-large runtime scope.
runtime_debug.is_casting_or_channeling = function(unit)
    return safe_unit_call(unit, "is_casting_spell") == true
        or safe_unit_call(unit, "is_channelling_spell") == true
        or safe_unit_call(unit, "is_channeling_spell") == true
end

runtime_debug.active_cast_progress = function(unit)
    local progress = safe_unit_call(unit, "get_active_spell_cast_percentage")
        or safe_unit_call(unit, "get_active_channel_cast_percentage")
        or safe_unit_call(unit, "get_channel_percentage")
        or safe_unit_call(unit, "get_cast_percentage")
    progress = type(progress) == "number" and progress or 100
    if progress >= 0 and progress <= 1 then progress = progress * 100 end
    return math.max(0, math.min(100, progress))
end

runtime_debug.is_interruptible_cast = function(unit)
    return runtime_debug.is_casting_or_channeling(unit)
        and (safe_unit_call(unit, "is_active_spell_interruptable") == true
            or safe_unit_call(unit, "is_active_channel_interruptable") == true
            or safe_unit_call(unit, "is_active_channel_interruptible") == true)
end

runtime_debug.is_objective_carrier = function(unit)
    return safe_unit_call(unit, "is_objective_carrier") == true
        or safe_unit_call(unit, "is_flag_carrier") == true
        or safe_unit_call(unit, "has_battleground_flag") == true
end

runtime_debug.read_dampening = function(player)
    local function normalized(value)
        value = tonumber(value)
        if not value then return nil end
        if value > 0 and value <= 1 then value = value * 100 end
        return math.max(0, math.min(100, value))
    end
    for _, method in ipairs({ "get_arena_dampening", "get_dampening_percent", "get_dampening" }) do
        if type(core[method]) == "function" then
            local ok, value = pcall(core[method])
            value = ok and normalized(value) or nil
            if value ~= nil then return value end
        end
        if pvp_helper and type(pvp_helper[method]) == "function" then
            local ok, value = pcall(pvp_helper[method], pvp_helper)
            value = ok and normalized(value) or nil
            if value ~= nil then return value end
        end
    end
    local auras = safe_unit_call(player, "get_auras") or safe_unit_call(player, "get_debuffs")
    if type(auras) == "table" then
        for _, aura in pairs(auras) do
            local ok, name, amount = pcall(function()
                local points = aura.points
                return string.lower(tostring(aura.name or aura.buff_name or aura.debuff_name or "")),
                    aura.value or aura.amount or aura.stacks or aura.count or aura.applications
                        or (type(points) == "table" and points[1])
            end)
            if ok and name:find("dampening", 1, true) then
                amount = normalized(amount)
                if amount ~= nil then return amount end
            end
        end
    end
    return 0
end

runtime_debug.is_training_dummy = function(unit)
    if not unit or safe_unit_call(unit, "is_valid") ~= true then return false end
    if safe_unit_call(unit, "is_training_dummy") == true then return true end
    local npc_id = tonumber(safe_unit_call(unit, "get_npc_id")
        or safe_unit_call(unit, "get_entry_id") or safe_unit_call(unit, "get_id"))
    if npc_id and runtime_debug.training_dummy_ids[npc_id] then return true end
    local name = string.lower(tostring(safe_unit_call(unit, "get_name") or ""))
    return name:find("training dummy", 1, true) ~= nil
        or name:find("practice dummy", 1, true) ~= nil
        or name:find("training bag", 1, true) ~= nil
        or name:find("target dummy", 1, true) ~= nil
        or name:find("combat dummy", 1, true) ~= nil
        or name:find("tanking dummy", 1, true) ~= nil
        or name:find("damage dummy", 1, true) ~= nil
        or name:find("melee target", 1, true) ~= nil
end

local function other_group_paladin_has_devotion(player, now)
    if now - group_aura_scan_time < 1 then return group_paladin_has_devotion_cache end
    group_aura_scan_time = now

    local player_guid = safe_unit_call(player, "get_guid")
    local found = false
    local function check_member(unit)
        if not unit or unit == player or safe_unit_call(unit, "is_valid") ~= true then return false end
        local guid = safe_unit_call(unit, "get_guid")
        if player_guid and guid and guid == player_guid then return false end
        local distance = safe_unit_call(player, "distance_to", unit)
        if type(distance) ~= "number" or distance > 40 then return false end
        return safe_unit_call(unit, "get_class") == PALADIN_CLASS_ID
            and has_buff(unit, SPELL.DEVOTION_AURA)
    end

    if core.object_manager.get_party_frames then
        local frames_ok, frames = pcall(core.object_manager.get_party_frames)
        if frames_ok and type(frames) == "table" then
            for _, unit in pairs(frames) do
                if check_member(unit) then found = true; break end
            end
        end
    end

    -- Fallback for clients that expose group units only through the object list.
    if not found then
        local objects_ok, objects = pcall(core.object_manager.get_all_objects)
        if objects_ok and type(objects) == "table" then
            for _, unit in pairs(objects) do
                if safe_unit_call(unit, "is_party_member") == true and check_member(unit) then
                    found = true
                    break
                end
            end
        end
    end

    group_paladin_has_devotion_cache = found
    return found
end

local function record_confirmed_aura_cast(data)
    if type(data) ~= "table" then return end
    local caster_ok, caster = pcall(function() return data.caster end)
    local player_ok, player = pcall(core.object_manager.get_local_player)
    if not caster_ok or not player_ok or not caster or not player then return end
    local caster_guid = safe_unit_call(caster, "get_guid")
    local player_guid = safe_unit_call(player, "get_guid")
    if caster ~= player and (not caster_guid or not player_guid or caster_guid ~= player_guid) then return end
    local spell_id_ok, spell_id = pcall(function() return tonumber(data.spell_id) end)
    if not spell_id_ok or (spell_id ~= SPELL.DEVOTION_AURA
        and spell_id ~= SPELL.CONCENTRATION_AURA and spell_id ~= SPELL.CRUSADER_AURA) then
        return
    end
    local now_ok, now = pcall(core.time)
    if now_ok and type(now) == "number" then
        last_confirmed_aura = spell_id
        last_confirmed_aura_at = now
    end
end

if core.register_on_spell_cast_callback then
    core.register_on_spell_cast_callback(function(data)
        record_confirmed_aura_cast(data)
        if pvp_helper and type(pvp_helper.on_spell) == "function" then
            pcall(pvp_helper.on_spell, pvp_helper, data)
        end
    end)
end

local function update_auto_aura(player)
    if not gui.auto_aura:get_state() then return false end
    local now_ok, now = pcall(core.time)
    if not now_ok or type(now) ~= "number" then return false end

    local in_combat = safe_unit_call(player, "is_in_combat") == true
    local mounted = safe_unit_call(player, "is_mounted") == true
    local paladin_devotion = other_group_paladin_has_devotion(player, now)
    local desired_aura
    if in_combat and paladin_devotion and has_spell(SPELL.CONCENTRATION_AURA) then
        desired_aura = SPELL.CONCENTRATION_AURA
    elseif in_combat then
        desired_aura = SPELL.DEVOTION_AURA
    elseif mounted and has_spell(SPELL.CRUSADER_AURA) then
        desired_aura = SPELL.CRUSADER_AURA
    elseif paladin_devotion and has_spell(SPELL.CONCENTRATION_AURA) then
        desired_aura = SPELL.CONCENTRATION_AURA
    else
        desired_aura = SPELL.DEVOTION_AURA
    end

    local aura_name = tostring(desired_aura)
    if core.spell_book.get_spell_name then
        local name_ok, name = pcall(core.spell_book.get_spell_name, desired_aura)
        if name_ok and type(name) == "string" then aura_name = name end
    end
    runtime_debug.aura = aura_name .. (paladin_devotion and " (group Devotion in 40 yd)" or "")
    diagnostic_transition("aura_plan", tostring(desired_aura) .. ":" .. tostring(paladin_devotion),
        "INFO", "AURA", "aura_plan_changed", {
            desired = aura_name, mounted = mounted, combat = in_combat,
            group_devotion_in_range = paladin_devotion,
        })

    if not has_spell(desired_aura) then return false end
    if has_buff(player, desired_aura) then
        last_confirmed_aura = desired_aura
        last_confirmed_aura_at = now
        return false
    end
    if last_confirmed_aura == desired_aura
        and now - last_confirmed_aura_at < AURA_CONFIRMED_FLOOR_SECONDS then
        return false
    end
    if now - last_aura_attempt < AURA_CAST_RETRY_SECONDS then return false end

    -- This timestamp throttles attempts only. Presence is recorded only from
    -- a positive aura read or the confirmed spell-cast callback above.
    last_aura_attempt = now
    return cast(desired_aura, player, player)
end

local function nearby_enemy_count(player, current_target, range, engaged_only)
    local count = 0
    local current_target_seen = false
    local check_range = range or AOE_RANGE
    local target_guid = ""
    if current_target and current_target.get_guid then
        local guid_ok, guid = pcall(current_target.get_guid, current_target)
        if guid_ok and type(guid) == "string" then target_guid = guid end
    end
    local objects = core.object_manager.get_all_objects() or {}
    for _, unit in pairs(objects) do
        if unit and unit.is_valid and unit:is_valid()
            and unit.is_unit and unit:is_unit()
            and not unit:is_dead()
            and player:can_attack(unit)
            and player:distance_to(unit) <= check_range
            and (not engaged_only or not runtime_debug.is_engaged_pve_enemy
                or runtime_debug.is_engaged_pve_enemy(player, unit, current_target)) then
            count = count + 1
            if unit == current_target then
                current_target_seen = true
            elseif target_guid ~= "" and unit.get_guid then
                local guid_ok, guid = pcall(unit.get_guid, unit)
                if guid_ok and guid == target_guid then current_target_seen = true end
            end
        end
    end
    -- Object lists can omit the selected target in some clients.
    if current_target and not current_target_seen
        and current_target.is_valid and current_target:is_valid()
        and not current_target:is_dead() and player:can_attack(current_target)
        and player:distance_to(current_target) <= check_range then
        count = count + 1
    end
    return count
end

local pvp_cleave_safe
local function cast_finisher(target, player, aoe, holy_power, divine_purpose, pvp_mode)
    if holy_power < 3 and not divine_purpose then return false end
    local arbiter_for_storm = has_buff(player, SPELL.DIVINE_ARBITER_STORM)
    local arbiter_for_verdict = has_buff(player, SPELL.DIVINE_ARBITER_VERDICT)
    local spender = aoe and SPELL.DIVINE_STORM or SPELL.FINAL_VERDICT
    -- Arbiter empowers an opposite spender; Divine Purpose supplies the free
    -- cast. Consume an existing empowerment before requesting another proc.
    -- Empyrean Legacy's Verdict also triggers a stronger Divine Storm on AoE.
    local empyrean_legacy = has_buff(player, SPELL.EMPYREAN_LEGACY)
    if pvp_mode and (empyrean_legacy or arbiter_for_verdict or has_buff(player, SPELL.DIVINE_ARBITER_HAMMER))
        and not pvp_cleave_safe(player, target, 8, false) then return false end
    if empyrean_legacy or (aoe and arbiter_for_verdict) then
        spender = SPELL.FINAL_VERDICT
    elseif not pvp_mode and not aoe and arbiter_for_storm
        and not has_spell(SPELL.SEAL_OF_THE_TEMPLAR) then
        spender = SPELL.DIVINE_STORM
    end
    if cast(spender, target, player) then return true end
    if spender == SPELL.FINAL_VERDICT
        and cast(SPELL.TEMPLARS_VERDICT, target, player) then return true end

    return false
end

local function is_valid_unit(unit)
    return safe_unit_call(unit, "is_valid") == true
        and safe_unit_call(unit, "is_dead") ~= true
end

local function unit_health_percent(unit)
    local hp, maximum = safe_unit_call(unit, "get_health"), safe_unit_call(unit, "get_max_health")
    if type(hp) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return nil end
    return math.max(0, math.min(100, hp / maximum * 100))
end

local function unit_distance(player, unit)
    local value = safe_unit_call(player, "distance_to", unit)
    return type(value) == "number" and value or math.huge
end

local function unit_guid(unit)
    local value = safe_unit_call(unit, "get_guid")
    return value and tostring(value) or nil
end

-- Short rolling health histories make decisions from observed damage without
-- inventing protected aura durations or encounter timers.
local health_history = {}
local last_history_cleanup = -math.huge
local function cleanup_adaptive_history(force)
    local now = core.time()
    if not force and now - last_history_cleanup < 10 then return end
    last_history_cleanup = now
    for guid, row in pairs(health_history) do
        if force or now - (row.last_t or 0) > 20 then health_history[guid] = nil end
    end
end
local function health_trend(unit)
    local guid, hp = unit_guid(unit), unit_health_percent(unit)
    if not guid or not hp then return 0, math.huge end
    local now = core.time()
    local row = health_history[guid] or { first_t = now, first_hp = hp, last_t = now, last_hp = hp, samples = 0 }
    if now - row.first_t > SMART.health_window or hp > row.last_hp + 8 then
        row.first_t, row.first_hp, row.samples = now, hp, 0
    end
    if now - (row.last_t or -math.huge) >= 0.10 or (row.samples or 0) == 0 then
        row.samples = math.min(100, (row.samples or 0) + 1)
    end
    row.last_t, row.last_hp = now, hp
    health_history[guid] = row
    cleanup_adaptive_history(false)
    local elapsed = now - row.first_t
    local loss_per_second = elapsed > 0.35 and math.max(0, (row.first_hp - hp) / elapsed) or 0
    local ttd = loss_per_second > 0.1 and hp / loss_per_second or math.huge
    local confident = (row.samples or 0) >= smart_setting(gui.pvp_forecast_samples, 3)
        and elapsed >= 0.35 and now - row.last_t <= 1.0
    return loss_per_second, ttd, confident, row.samples or 0
end

local function observed_ttd(unit)
    if runtime_debug.combat_forecast
        and type(runtime_debug.combat_forecast.get_forecast_single) == "function" then
        local ok, value = pcall(runtime_debug.combat_forecast.get_forecast_single,
            runtime_debug.combat_forecast, unit, true)
        if ok and type(value) == "number" and value > 0 and value < 3600 then return value end
    end
    local _, ttd = health_trend(unit)
    return ttd
end

local function projected_enemy_health(unit, seconds)
    local hp = unit_health_percent(unit) or 100
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return hp, 0, 0 end
    local loss_rate, _, confident, samples = health_trend(unit)
    local maximum = safe_unit_call(unit, "get_max_health")
    local healing = safe_unit_call(unit, "get_incoming_heals", seconds)
    local healing_pct = type(healing) == "number" and type(maximum) == "number" and maximum > 0
        and math.max(0, healing / maximum * 100) or 0
    local predicted_loss = confident and math.min(loss_rate * seconds,
        smart_setting(gui.pvp_forecast_max_change, 20)) or 0
    return math.max(0, math.min(100, hp - predicted_loss + healing_pct)),
        loss_rate, healing_pct, confident, samples
end

local function incoming_danger(unit, pressure, deadline)
    local hp = unit_health_percent(unit) or 100
    local loss = health_trend(unit)
    deadline = math.max(0, tonumber(deadline) or 2.0)
    local module_incoming, unit_incoming
    if runtime_debug.health_prediction
        and type(runtime_debug.health_prediction.get_incoming_damage) == "function" then
        local ok, value = pcall(runtime_debug.health_prediction.get_incoming_damage,
            runtime_debug.health_prediction, unit, deadline)
        if ok and type(value) == "number" then module_incoming = math.max(0, value) end
    end
    local native_value = safe_unit_call(unit, "get_incoming_damage", deadline)
    if type(native_value) == "number" then unit_incoming = math.max(0, native_value) end
    -- The providers can observe different damage streams. Follow the mature
    -- Rogue predictor and use the stronger forecast without adding overlapping
    -- estimates together.
    local incoming = math.max(module_incoming or 0, unit_incoming or 0)
    -- Existing absorbs are reliable but can be consumed by other damage before
    -- the forecasted event. Match the mature Rogue and Holy predictors by
    -- crediting at most 75% of forecast damage instead of treating the shield
    -- as guaranteed or ignoring it entirely.
    local shield = math.max(0, tonumber(safe_unit_call(unit, "get_total_shield")) or 0)
    local shield_credit = math.min(shield, incoming * 0.75)
    incoming = math.max(0, incoming - shield_credit)
    local max_hp = safe_unit_call(unit, "get_max_health")
    local incoming_pct = type(incoming) == "number" and type(max_hp) == "number" and max_hp > 0
        and incoming / max_hp * 100 or 0
    local guid = unit_guid(unit)
    local focus = guid and pressure and pressure[guid] or nil
    local score = (100 - hp) + loss * 3 + incoming_pct
        + (focus and focus.count or 0) * 8 + (focus and focus.burst and 18 or 0)
        + (focus and focus.swap and math.min(20, 10 + (focus.swap_count or 1) * 5) or 0)
    return score, loss, incoming_pct
end

runtime_debug.predicted_health_percent = function(unit, current_hp, window, loss, incoming_pct)
    window = math.max(0, tonumber(window) or 0)
    if window > 0 then
        local future_hp = safe_unit_call(unit, "get_health_percentage_inc", window)
        if type(future_hp) == "number" and future_hp >= 0 and future_hp <= 100 then
            return future_hp, "izi_future_hp"
        end
    end
    return math.max(0, (tonumber(current_hp) or 100)
        - math.max(tonumber(incoming_pct) or 0, (tonumber(loss) or 0) * window)), "fallback"
end

-- Treat queued healing as a confidence-weighted signal for ordinary support
-- heals.  Major saves remain keyed to raw/predicted health because queued
-- heals can be cancelled, interrupted, or fully consumed by a heal absorb.
runtime_debug.healing_context = function(unit)
    local maximum = safe_unit_call(unit, "get_max_health")
    if type(maximum) ~= "number" or maximum <= 0 then return 0, 0, 0, 0 end
    local incoming = tonumber(safe_unit_call(unit, "get_incoming_heals")) or 0
    local absorbed = tonumber(safe_unit_call(unit, "get_total_heal_absorbs"))
        or tonumber(safe_unit_call(unit, "get_total_heal_absorb"))
        or tonumber(safe_unit_call(unit, "get_heal_absorb")) or 0
    local shield = tonumber(safe_unit_call(unit, "get_total_shield")) or 0
    local incoming_pct = math.max(0, incoming) / maximum * 100
    local absorb_pct = math.max(0, absorbed) / maximum * 100
    return incoming_pct, absorb_pct, math.max(0, incoming_pct - absorb_pct),
        math.max(0, shield) / maximum * 100
end

local function decision_trace(event, fields)
    runtime_debug.decision = event
    diagnostic_transition("decision_trace", event .. ":" .. tostring(fields and fields.reason or ""),
        "DEBUG", "ROTATION", event, fields or {})
end

local function is_boss_or_elite(unit)
    return safe_unit_call(unit, "is_boss") == true
        or (tonumber(safe_unit_call(unit, "get_classification")) or 0) >= 1
end

local function is_pvp_mode(mode)
    return mode == "arena" or mode == "battleground" or mode == "world_pvp"
end

local function is_enemy_player(player, unit)
    if not is_valid_unit(unit) or safe_unit_call(unit, "is_player") ~= true then return false end
    return safe_unit_call(player, "can_attack", unit) == true
        or safe_unit_call(unit, "is_enemy_with", player) == true
end

local function is_hostile_unit(player, unit)
    if not is_valid_unit(unit) then return false end
    return safe_unit_call(player, "can_attack", unit) == true
        or safe_unit_call(unit, "is_enemy_with", player) == true
end

local object_cache, object_cache_at = {}, -math.huge
local function object_list()
    local now = core.time()
    if now - object_cache_at < 0.10 then return object_cache end
    local ok, objects = pcall(core.object_manager.get_all_objects)
    object_cache = ok and type(objects) == "table" and objects or {}
    object_cache_at = now
    return object_cache
end

-- These helper queries work even when IZI's optional object extensions have
-- not been installed by another plugin.
local function confirmed_cc(unit, native_method, flag_name, min_ms)
    if native_method and safe_unit_call(unit, native_method, min_ms or 100) == true then return true end
    local flags = pvp_helper and pvp_helper.cc_flags
    local flag = flags and flags[flag_name] or (enums.cc_flags and enums.cc_flags[flag_name])
    if flag and type(pvp_helper.is_crowd_controlled) == "function" then
        local ok, active = pcall(pvp_helper.is_crowd_controlled, pvp_helper, unit, flag, min_ms or 100)
        return ok and active == true
    end
    return false
end

local function breakable_cc(unit)
    if not unit then return false end
    if pvp_helper and type(pvp_helper.is_crowd_controlled_weak) == "function" then
        local ok, active = pcall(pvp_helper.is_crowd_controlled_weak, pvp_helper, unit, 100)
        if ok and active == true then return true end
    end
    return false
end

local function movement_impaired(unit)
    if confirmed_cc(unit, "is_rooted", "ROOT", 100)
        or safe_unit_call(unit, "is_slowed") == true then return true end
    if pvp_helper and type(pvp_helper.is_slow) == "function" then
        local ok, active = pcall(pvp_helper.is_slow, pvp_helper, unit, 0, 100)
        return ok and active == true
    end
    return false
end

runtime_debug.is_confirmed_snare_only = function(unit)
    return safe_unit_call(unit, "is_slowed") == true
        and not confirmed_cc(unit, "is_rooted", "ROOT", 100)
end

runtime_debug.try_hallowed_ground = function(player, candidates, mode)
    if not is_pvp_mode(mode) or not has_spell(SPELL.HALLOWED_GROUND)
        or not has_spell(SPELL.CONSECRATION)
        or (tonumber(safe_unit_call(player, "get_power", HOLY_POWER)) or 0) >= 5
        or not pvp_cleave_safe(player, safe_unit_call(player, "get_target"), 8, true) then return false end
    local beneficiary = nil
    local selected = safe_unit_call(player, "get_target")
    if runtime_debug.is_confirmed_snare_only(player) and is_enemy_player(player, selected)
        and unit_distance(player, selected) <= 12 then beneficiary = player end
    if not beneficiary then
        for _, candidate in ipairs(candidates or {}) do
            local ally = candidate.unit
            local healer = safe_unit_call(ally, "get_group_role") == 1
            if unit_distance(player, ally) <= 8 and runtime_debug.is_confirmed_snare_only(ally)
                and (candidate.objective_carrier or candidate.pressured or healer) then
                beneficiary = ally
                break
            end
        end
    end
    if beneficiary and cast(SPELL.CONSECRATION, player, player) then
        diagnostic_event("ACTION", "SUPPORT", "hallowed_ground_snare_clear", {
            target = safe_unit_call(beneficiary, "get_name") or "unknown",
            self = beneficiary == player, mode = mode,
        })
        return true
    end
    return false
end

local target_is_protected

local function collect_allies(player, mode)
    local result, seen = {}, {}
    local function add(unit, known_party)
        if not is_valid_unit(unit) then return end
        local guid = unit_guid(unit) or tostring(unit)
        if seen[guid] then return end
        local friendly = unit == player or known_party
            or safe_unit_call(unit, "is_party_member") == true
        if not friendly and is_pvp_mode(mode) then
            friendly = safe_unit_call(unit, "is_player") == true
                and safe_unit_call(unit, "is_friend_with", player) == true
                and safe_unit_call(unit, "is_enemy_with", player) ~= true
        end
        if friendly then
            seen[guid] = true
            result[#result + 1] = unit
        end
    end
    add(player, true)
    -- Some solo scenarios expose their combat companion through the ordinary
    -- owner/pet relationship. Include it when valid; normal Ret characters
    -- without such a companion simply return nil here.
    if mode == "delve" or mode == "world_pve" then
        add(safe_unit_call(player, "get_pet"), true)
    end
    if core.object_manager.get_party_frames then
        local ok, frames = pcall(core.object_manager.get_party_frames)
        if ok and type(frames) == "table" then
            for _, unit in pairs(frames) do add(unit, true) end
        end
    end
    if core.object_manager.get_party_members then
        local ok, members = pcall(core.object_manager.get_party_members)
        if ok and type(members) == "table" then
            for _, member in pairs(members) do
                if type(member) == "table" then add(member.object, true) end
            end
        end
    end
    if is_pvp_mode(mode) then
        for _, unit in pairs(object_list()) do add(unit, false) end
    end
    return result
end

-- Off-target automation must only consider enemies already participating in
-- the current fight. The selected target remains eligible because selecting it
-- is an explicit player decision.
runtime_debug.is_engaged_pve_enemy = function(player, enemy, selected)
    if enemy == selected then return true end
    if safe_unit_call(enemy, "is_in_combat") ~= true then return false end
    local victim = safe_unit_call(enemy, "get_target")
    if victim == player or safe_unit_call(victim, "is_party_member") == true then return true end
    local threat = safe_unit_call(player, "get_threat_situation", enemy)
    return type(threat) == "table" and (threat.is_tanking == true
        or (tonumber(threat.status) or 0) > 0 or (tonumber(threat.threat_percent) or 0) > 0)
end

runtime_debug.enemy_target_memory, runtime_debug.ally_swap_windows = {}, {}
local function build_pressure_map(player, allies, mode)
    local by_guid, pressure = {}, {}
    for _, ally in ipairs(allies or {}) do
        local guid = unit_guid(ally)
        if guid then by_guid[guid] = ally; pressure[guid] = { count = 0, burst = false,
            swap = false, swap_count = 0, unit = ally } end
    end
    local now = core.time()
    for _, enemy in pairs(object_list()) do
        local relevant_enemy = is_pvp_mode(mode) and is_enemy_player(player, enemy)
            or (not is_pvp_mode(mode) and is_hostile_unit(player, enemy))
        if relevant_enemy then
            -- The active spell target is the earliest reliable signal of who
            -- will take the next cast. Fall back to the enemy's selected target
            -- for melee pressure and clients that do not expose cast targets.
            local cast_victim = safe_unit_call(enemy, "get_active_spell_target")
            local victim = is_valid_unit(cast_victim) and cast_victim
                or safe_unit_call(enemy, "get_target")
            local guid, state = unit_guid(victim), nil
            if guid then state = pressure[guid] end
            local enemy_guid = unit_guid(enemy)
            if enemy_guid then
                local previous = runtime_debug.enemy_target_memory[enemy_guid]
                if previous and guid and previous ~= guid and state then
                    local row = runtime_debug.ally_swap_windows[guid]
                    if not row or row.until_time <= now then row = { count = 0 } end
                    row.count = row.count + 1
                    row.until_time = now + smart_setting(gui.pvp_swap_pressure_window, 3)
                    runtime_debug.ally_swap_windows[guid] = row
                    diagnostic_event("INFO", "SUPPORT", "enemy_target_swap", {
                        enemy = safe_unit_call(enemy, "get_name") or "unknown",
                        target = safe_unit_call(victim, "get_name") or "unknown", count = row.count,
                    })
                end
                runtime_debug.enemy_target_memory[enemy_guid] = guid
            end
            if state then
                state.count = state.count + 1
                state.cast_targeted = state.cast_targeted or is_valid_unit(cast_victim)
                if pvp_helper and type(pvp_helper.is_melee) == "function" then
                    local melee_ok, melee = pcall(pvp_helper.is_melee, pvp_helper, enemy)
                    state.melee = state.melee or (melee_ok and melee == true)
                    state.caster = state.caster or (melee_ok and melee == false)
                end
                if pvp_helper and type(pvp_helper.has_burst_active) == "function" then
                    local ok, active = pcall(pvp_helper.has_burst_active, pvp_helper, enemy, 500)
                    state.burst = state.burst or (ok and active == true)
                end
                if not state.burst then
                    state.burst = safe_unit_call(enemy, "has_burst_active", 500) == true
                end
            end
        end
    end
    for guid, row in pairs(runtime_debug.ally_swap_windows) do
        if row.until_time <= now then
            runtime_debug.ally_swap_windows[guid] = nil
        elseif pressure[guid] then
            pressure[guid].swap = true
            pressure[guid].swap_count = row.count or 1
        end
    end
    return pressure
end
runtime_debug.build_pressure = build_pressure_map

runtime_debug.scan_pve_danger = function(player)
    local mode = runtime_debug.active_mode or current_mode
    if mode ~= "mythic_plus" and mode ~= "delve" and mode ~= "world_pve" then
        runtime_debug.danger_zone_status = "Off outside PvE"
        return nil
    end
    if not player or safe_unit_call(player, "is_in_combat") ~= true then
        runtime_debug.danger_zone_status = "Waiting for PvE combat"
        return nil
    end
    local lead = smart_setting(gui.pve_danger_lead, 3)
    local candidate, player_guid = nil, unit_guid(player)
    local function remember(hit, label, remaining, source, action)
        local row = { active = true, hit = hit == true, label = label,
            remaining = remaining, source = source, action = action or "damage" }
        if not candidate or row.hit and not candidate.hit
            or row.hit == candidate.hit and (row.remaining or math.huge)
                < (candidate.remaining or math.huge) then candidate = row end
    end
    for _, enemy in pairs(object_list()) do
        local channeling = safe_unit_call(enemy, "is_channelling_spell") == true
            or safe_unit_call(enemy, "is_channeling_spell") == true
        if is_hostile_unit(player, enemy)
            and (safe_unit_call(enemy, "is_casting_spell") == true or channeling)
            and runtime_debug.is_engaged_pve_enemy(player, enemy,
                safe_unit_call(player, "get_target")) then
            local remaining = runtime_debug.cast_remaining and runtime_debug.cast_remaining(enemy) or nil
            if remaining == nil or remaining <= lead then
                local victim = safe_unit_call(enemy, "get_active_spell_target")
                local aimed_at_player = player_guid and unit_guid(victim) == player_guid
                local spell_id = channeling and safe_unit_call(enemy, "get_active_channel_spell_id")
                    or safe_unit_call(enemy, "get_active_spell_id")
                local spell_name = spell_id and core.spell_book.get_spell_name
                    and select(2, pcall(core.spell_book.get_spell_name, spell_id)) or nil
                if aimed_at_player then
                    local spell_text = string.lower(tostring(spell_name or ""))
                    local movement_cast = spell_text:find("dash", 1, true)
                        or spell_text:find("gaze", 1, true)
                        or spell_text:find("bomb", 1, true)
                        or spell_text:find("breath", 1, true)
                        or spell_text:find("wave", 1, true)
                        or spell_text:find("boulder", 1, true)
                        or spell_text:find("death rattle", 1, true)
                        or spell_text:find("fel nova", 1, true)
                    remember(true, spell_name or "Targeted boss cast", remaining,
                        "active_cast", movement_cast and "move" or "targeted")
                elseif is_valid_unit(victim) and is_boss_or_elite(enemy) then
                    remember(false, spell_name or "Boss cast aimed elsewhere", remaining, "active_cast", "other_target")
                end
            end
        end
    end
    local addon = core.addons and core.addons.bigwigs or nil
    if addon and type(addon.is_loaded) == "function" and type(addon.get_bars) == "function" then
        local loaded_ok, loaded = pcall(addon.is_loaded)
        local bars_ok, bars = pcall(addon.get_bars)
        if loaded_ok and loaded and bars_ok and type(bars) == "table" then
            for _, bar in pairs(bars) do
                local remaining = tonumber(bar.remaining or bar.time_left or bar.timeLeft)
                if not remaining and tonumber(bar.expire_time or bar.ends_at or bar.end_time) then
                    remaining = tonumber(bar.expire_time or bar.ends_at or bar.end_time) - core.time()
                end
                if remaining and remaining >= 0 and remaining <= lead then
                    local text = string.lower(tostring(bar.text or ""))
                    local warning = string.lower(tostring(bar.warning_type or bar.warningType
                        or bar.role or bar.action or ""))
                    local party = warning == "aoe" or warning == "party" or warning == "damage"
                        or text:find("stomp", 1, true) or text:find("nova", 1, true)
                        or text:find("roar", 1, true) or text:find("eruption", 1, true)
                        or text:find("pulse", 1, true) or text:find("storm", 1, true)
                        or text:find("inferno", 1, true) or text:find("volley", 1, true)
                    local tank = warning == "tank" or warning == "tankbuster"
                        or text:find("tank", 1, true) or text:find("buster", 1, true)
                    local movement = warning == "move" or warning == "dodge"
                        or text:find("dodge", 1, true) or text:find("move", 1, true)
                        or text:find("ground", 1, true) or text:find("swirl", 1, true)
                    if party then
                        remember(true, bar.text or "Party-wide mechanic", remaining, "bigwigs", "party")
                    elseif tank then
                        remember(false, bar.text or "Tank mechanic", remaining, "bigwigs", "tank")
                    elseif movement then
                        local current_hp = unit_health_percent(player) or 100
                        local future_hp = safe_unit_call(player, "get_health_percentage_inc", remaining)
                        local incoming = safe_unit_call(player, "get_incoming_damage", remaining)
                        local will_hit = type(future_hp) == "number" and future_hp < current_hp - 0.5
                            or type(incoming) == "number" and incoming > 0
                        -- Missing forecasts are unknown, never evidence of safety.
                        if will_hit then
                            remember(true, bar.text or "Movement mechanic", remaining, "bigwigs", "move")
                        end
                    end
                end
            end
        end
    end
    runtime_debug.danger_zone_status = candidate
        and ((candidate.hit and "DANGER " or "NOT TARGETED ") .. tostring(candidate.label)
            .. " / " .. tostring(candidate.source)) or "No imminent confirmed mechanic"
    diagnostic_transition("pve_danger_zone", runtime_debug.danger_zone_status,
        "INFO", "OVERLAY", "pve_danger_zone_changed", {
            mode = mode, state = runtime_debug.danger_zone_status,
            remaining = candidate and candidate.remaining or "none",
        })
    return candidate
end

-- Midnight Season 2 role cards. These deliberately describe jobs and never
-- invent world coordinates that the client or boss addon does not expose.
runtime_debug.s2_boss_guides = {
    ravi={d="altaroffangs",tank="Keep Rav'i in melee; aim her away and manage Hydrastrike/Fresh Meat.",healer="Prepare for Carrion Burst and Triple Shot; keep the group clear of Regurgitate.",dps="Break the Ssscavenging/Feeding Frenzy shield; soak Messy Eater and dodge Regurgitate."},
    thewrithingcoil={d="altaroffangs",tank="Face the Coil away; defensive Tail Scythe and break the Death Rattle tether.",healer="Prepare for Synchronized Venom and Death Rattle; break your tether quickly.",dps="Kick Toxic Atrophy, break Death Rattle tethers, then cleave the Uncoiled Writhes."},
    zuljan={d="altaroffangs",tank="Defensive Chop Down; help intercept Ritual of the Fang and clear Ritual Venom.",healer="Cover Ritual of the Fang and weapon hits; clear Ritual Venom safely.",dps="Intercept Ritual of the Fang, dodge Axegrinder/Boneslicer, and clear Ritual Venom."},
    kystiamanaheart={d="murderrow",tank="Control Kystia and Nibbles; face Fel Spray away and stop Mirror Images.",healer="Prepare for Destabilized; dispel Corroding Spittle and stabilize Nibbles pressure.",dps="Focus Nibbles to 20%, stop Mirror Images, dodge Fel Nova and Fel Spray."},
    zaenbladesorrow={d="murderrow",tank="Manage Envenom and take cover at 100 energy for Murder in a Row.",healer="Take cover for Murder in a Row; avoid Same-Day Delivery and Fire Bomb.",dps="Take cover at 100 energy; avoid Same-Day Delivery and Fire Bomb."},
    xathuuxtheannihilator={d="murderrow",tank="Place Burning Steps safely and defensive Legion Strike.",healer="Cover Legion Strike healing reduction and Fel Lightning until the axe dies.",dps="Destroy Axe Toss immediately; avoid expanding Burning Steps pools."},
    lithielcinderfury={d="murderrow",tank="Control the Furious Vilefiend and keep Chaos Bolt interrupted.",healer="Use the Demonic Gateway through Malefic Wave; prepare for Vilefiend damage.",dps="Kick Chaos Bolt, kill Wild Imps, and use the gateway through Malefic Wave."},
    thehoardmonger={d="denofnalorakk",tank="Face slams away and control Resourceful Measures positioning.",healer="Prepare for Bellow damage; cleanse Toxic Spores and recover frontal mistakes.",dps="Soak Rotten Mushrooms before Putrid Burst and dodge Earthshatter/Bonespike Slam."},
    sentinelofwinter={d="denofnalorakk",tank="Hold position through Frozen Tempest and avoid Raging Squalls.",healer="Cover Frozen Tempest and Rimeshatter; dispel Glacial Torment.",dps="Kill Shivercores, avoid Squalls, and use Snowdrifts against Frozen Tempest."},
    nalorakk={d="denofnalorakk",tank="Protect Zul'jarra for Onslaught and intercept Echoes during Fury.",healer="Cover Onslaught, Echo interceptors and Forceful Roar recovery.",dps="Intercept Echoes before Zul'jarra during Fury, then recover after Forceful Roar."},
    lightblossomtrinity={d="theblindingvale",tank="Place Fertile Loam safely, avoid Dash, then soak Lightblossom Beam.",healer="Cover Thornblade/Bedrock Surge and heal Beam soakers.",dps="Kick Light Bolt and soak Lightblossom Beam; avoid Lightsower Dash."},
    ikuzzthelighthunter={d="theblindingvale",tank="Control Ikuzz, free rooted allies and protect the Gaze target.",healer="Cover Thorncaller Roar and Incise; help free Bloodthorn Roots.",dps="Free roots, survive Stomp, and kite Bloodthirsty Gaze over roots."},
    lightwardenruia={d="theblindingvale",tank="Control Ruia and avoid Pulverizing Strikes cones and Lightfall.",healer="Prepare for rapid mechanics below 40%; cover targeted Lightfall damage.",dps="Dodge Pulverizing Strikes and Lightfall; save movement for Spirits of the Vale."},
    ziekket={d="theblindingvale",tank="Control Lashers and defensive Thornspike.",healer="Cover Oozing Xylem and players taking Lightbloom Essence.",dps="Aim Concentrated Lightbeam through dormant Lashers, collect safe Essence, kill adds."},
    tazrah={d="voidscararena",tank="Defensive Void Blast and keep clear of Umbral Rupture puddles.",healer="Cover Dark Bloom and Nether Dash; keep players out of shade lines.",dps="Spread at the edge for Nether Dash, dodge Dark Bloom orbs, rotate from puddles."},
    atroxus={d="voidscararena",tank="Face Noxious Breath away; kite Toxic Creeper and defensive Hulking Claw.",healer="Cover Poison Splash/Roar and the Creeper target.",dps="Dodge Breath and poison pools; focus the Toxic Creeper after Monstrous Roar."},
    charonus={d="voidscararena",tank="Keep clear of Singularity and help position Gravitic Orbs.",healer="Cover Condensed Mass and Orb carriers.",dps="Place Gravitic Orbs inside Unstable Singularity to collapse them."},
    thegoldenserpent={d="kingsrest",tank="Face Tail Thrash away and stop Animated Gold reaching the boss.",healer="Cover Spit Gold and Serpentine Gust; keep puddle targets healthy.",dps="Stack Spit Gold puddles and kill/CC Animated Gold before Luster reaches the boss."},
    mchimbatheembalmer={d="kingsrest",tank="Control Finished Mummies and help free Entomb targets.",healer="Keep Drain Fluids targets above 90%; heal Entomb and Burn Corruption.",dps="Break Entomb coffins, kill Finished Mummies, and avoid Burning Ground."},
    thecounciloftribes={d="kingsrest",tank="Defensive Backhand and stack for Barrel Through.",healer="Cover Barrel Through, Poison Nova and Severing Axe.",dps="Stack Barrel Through, kill elemental totems, and handle returning councilors."},
    dazarthefirstking={d="kingsrest",tank="Defensive Blade Combo/Savage Maul and face mounted Dazar safely.",healer="Cover Gilded Destruction, Impaling Spear bleeds and mounted tank damage.",dps="Dodge spears/frontals, stop Deathly Roar, and burn the shared-health mount phase."},
    melidrussachillworn={d="rubylifepools",tank="Pick up whelps and defensive Cold Claws; keep Frigid Shard interrupted.",healer="Cover Chillstorm/Hailburst and Frost Overload; monitor Cold Claws.",dps="Bait Hailburst together, drop Chillstorm out, kill whelps and break Ice Bulwark."},
    kokiablazehoof={d="rubylifepools",tank="Defensive Searing Blows, pick up Firestorms and stop Blaze Volley.",healer="Cover Inferno, Molten Boulder and Ritual targets.",dps="Kill Blazebound Firestorms, kick Blaze Volley and dodge Molten Boulder."},
    kyrakkaanderkhartstormvein={d="rubylifepools",tank="Defensive Stormslam and preserve space from Flaming Embers.",healer="Cover Inferno Spit and Winds of Change; reposition for Cloudburst.",dps="Avoid Embers, adjust for Winds of Change, and interrupt Cloudburst."},
    adderisandaspix={d="templeofsethraliss",tank="Attack the unshielded boss, defensive Overload, then stack after Gale Force.",healer="Cover Tempest Winds and Thunder and Lightning; manage Gale Force pushback.",dps="Hit the unshielded boss, spread for Gale Force, then collapse for Thunder and Lightning."},
    merektha={d="templeofsethraliss",tank="Defensive Lightning Bite, pick up snakes and keep Storm Serpents away.",healer="Cover Serpentstorm/Burrowquake and Knot of Snakes.",dps="Kill snakes, interrupt Poison Spit, break Knot of Snakes and avoid Lingering Storm."},
    galvazzt={d="templeofsethraliss",tank="Block Spire energy but rotate before Galvanized stacks become unsafe.",healer="Help block Spires and heal Galvanized players.",dps="Stand between boss and Lightning Spires; rotate blockers and avoid knockbacks."},
    avatarofsethraliss={d="templeofsethraliss",tank="Pick up Guardians and defensive Tainted Strike while adds are controlled.",healer="Heal the Avatar to full; account for Defiling Taint and Tormentor fixates.",dps="Kill Essence Defilers first, then Tormentors; deliver Corrupted Lifeforce."},
}

runtime_debug.s2_boss_aliases = {
    adderis = "adderisandaspix", aspix = "adderisandaspix",
    kyrakka = "kyrakkaanderkhartstormvein", erkhartstormvein = "kyrakkaanderkhartstormvein",
}

runtime_debug.scan_s2_boss_guide = function(player)
    local mode = runtime_debug.active_mode or current_mode
    if mode ~= "mythic_plus" and mode ~= "delve" and mode ~= "world_pve" then
        runtime_debug.current_boss_guide = nil
        return nil
    end
    local function normalized(value)
        return string.lower(tostring(value or "")):gsub("[^%w]", "")
    end
    local instance_name = type(core.get_instance_name) == "function"
        and select(2, pcall(core.get_instance_name)) or ""
    local instance_key = normalized(instance_name)
    local boss, guide
    local selected = safe_unit_call(player, "get_target")
    local selected_key = normalized(safe_unit_call(selected, "get_name"))
    selected_key = runtime_debug.s2_boss_aliases[selected_key] or selected_key
    if runtime_debug.s2_boss_guides[selected_key]
        and safe_unit_call(selected, "is_dead") ~= true then
        boss, guide = selected, runtime_debug.s2_boss_guides[selected_key]
    end
    if not boss then
        for _, unit in pairs(object_list()) do
            local key = normalized(safe_unit_call(unit, "get_name"))
            key = runtime_debug.s2_boss_aliases[key] or key
            local row = runtime_debug.s2_boss_guides[key]
            if row and safe_unit_call(unit, "is_dead") ~= true
                and safe_unit_call(unit, "is_in_combat") == true then boss, guide = unit, row; break end
        end
    end
    if not boss or not guide then
        runtime_debug.s2_boss_status = "No supported Season 2 boss detected"
        runtime_debug.current_boss_guide = nil
        return nil
    end
    if instance_key ~= "" and not instance_key:find(guide.d, 1, true)
        and not guide.d:find(instance_key, 1, true) then
        runtime_debug.s2_boss_status = "Boss name found outside expected Season 2 dungeon"
        runtime_debug.current_boss_guide = nil
        return nil
    end
    local role_id = tonumber(safe_unit_call(player, "get_group_role")) or 0
    local role = role_id == 2 and "tank" or role_id == 1 and "healer" or "dps"
    local mechanic, remaining
    if safe_unit_call(boss, "is_casting_spell") == true
        or safe_unit_call(boss, "is_channelling_spell") == true
        or safe_unit_call(boss, "is_channeling_spell") == true then
        local channeling = safe_unit_call(boss, "is_channelling_spell") == true
            or safe_unit_call(boss, "is_channeling_spell") == true
        local spell_id = channeling and safe_unit_call(boss, "get_active_channel_spell_id")
            or safe_unit_call(boss, "get_active_spell_id")
        mechanic = spell_id and core.spell_book.get_spell_name
            and select(2, pcall(core.spell_book.get_spell_name, spell_id)) or nil
        remaining = runtime_debug.cast_remaining and runtime_debug.cast_remaining(boss) or nil
    end
    local addon = core.addons and core.addons.bigwigs or nil
    if not mechanic and addon and type(addon.is_loaded) == "function" and type(addon.get_bars) == "function" then
        local loaded_ok, loaded = pcall(addon.is_loaded)
        local bars_ok, bars = pcall(addon.get_bars)
        if loaded_ok and loaded and bars_ok and type(bars) == "table" then
            for _, bar in pairs(bars) do
                local left = tonumber(bar.remaining or bar.time_left or bar.timeLeft)
                if not left and tonumber(bar.expire_time or bar.ends_at or bar.end_time) then
                    left = tonumber(bar.expire_time or bar.ends_at or bar.end_time) - core.time()
                end
                if left and left >= 0 and left <= smart_setting(gui.pve_danger_lead, 3) + 3
                    and (not remaining or left < remaining) then
                    mechanic, remaining = bar.text or "Upcoming boss mechanic", left
                end
            end
        end
    end
    local lower = string.lower(tostring(mechanic or ""))
    local kind, instruction = "guide", guide[role]
    local interruptible = (safe_unit_call(boss, "is_casting_spell") == true
        or safe_unit_call(boss, "is_channelling_spell") == true
        or safe_unit_call(boss, "is_channeling_spell") == true)
        and runtime_debug.is_interruptible_cast(boss)
    if interruptible and role == "dps" then
        kind, instruction = "interrupt", "INTERRUPT " .. tostring(mechanic or "boss cast")
    elseif lower:find("soak", 1, true) or lower:find("thunder and lightning", 1, true)
        or lower:find("barrel through", 1, true) or lower:find("lightblossom beam", 1, true) then
        kind, instruction = "stack", "STACK / SOAK: " .. tostring(mechanic)
    elseif lower:find("add", 1, true) or lower:find("whelp", 1, true)
        or lower:find("axe toss", 1, true) or lower:find("lucre", 1, true)
        or lower:find("hatch", 1, true) or lower:find("mirror image", 1, true) then
        kind, instruction = "focus", "SWAP TO PRIORITY TARGET: " .. tostring(mechanic)
    elseif lower:find("gaze", 1, true) or lower:find("dash", 1, true)
        or lower:find("wave", 1, true) or lower:find("breath", 1, true)
        or lower:find("slam", 1, true) or lower:find("boulder", 1, true)
        or lower:find("eruption", 1, true) or lower:find("bomb", 1, true)
        or lower:find("murder in a row", 1, true) then
        kind, instruction = "move", "MOVE / DODGE: " .. tostring(mechanic)
    elseif mechanic and mechanic ~= "" then
        instruction = string.upper(role) .. ": " .. tostring(mechanic) .. " — " .. guide[role]
    end
    runtime_debug.s2_boss_status = tostring(safe_unit_call(boss, "get_name") or "Boss")
        .. " / " .. role .. " / " .. tostring(instruction)
    diagnostic_transition("s2_boss_guide", runtime_debug.s2_boss_status,
        "INFO", "ENCOUNTER", "boss_instruction_changed", {
            dungeon = instance_name, boss = safe_unit_call(boss, "get_name") or "unknown",
            role = role, mechanic = mechanic or "overview", kind = kind,
            remaining = remaining or "none", instruction = instruction,
        })
    runtime_debug.current_boss_guide = { boss = boss, role = role, mechanic = mechanic,
        remaining = remaining, kind = kind, instruction = instruction }
    return runtime_debug.current_boss_guide
end

local function pressure_for(unit, pressure)
    local guid = unit_guid(unit)
    return guid and pressure and pressure[guid] or nil
end

local last_target_swap = -math.huge
local pending_target_swap = nil
local function maybe_swap_pvp_target(player, mode, profile, pressure)
    if not profile.swap_target or not is_pvp_mode(mode)
        or not core.input or type(core.input.set_target) ~= "function" then return false end
    local now = core.time()
    if pending_target_swap then
        local actual_guid = unit_guid(safe_unit_call(player, "get_target"))
        if actual_guid == pending_target_swap.guid then
            diagnostic_transition("pvp_target_swap_confirmed", actual_guid,
                "DEBUG", "TARGET", "target_swap_confirmed", { target = pending_target_swap.name })
            pending_target_swap = nil
        elseif (now - pending_target_swap.requested_at) * 1000
            >= smart_setting(gui.pvp_swap_confirm_ms, 400) then
            diagnostic_event("WARN", "TARGET", "target_swap_not_confirmed", {
                requested = pending_target_swap.name, requested_guid = pending_target_swap.guid,
                actual_guid = actual_guid or "none",
            })
            pending_target_swap = nil
            last_target_swap = -math.huge
        else
            return false
        end
    end
    if now < runtime_debug.manual_target_lock_until then return false end
    if now - last_target_swap < smart_setting(gui.target_swap_lock, 3) then return false end
    if safe_unit_call(player, "is_casting_spell") == true
        or safe_unit_call(player, "is_channeling_spell") == true then return false end
    local allies = collect_allies(player, mode)
    local best, best_score = nil, math.huge
    local wings_kill, wings_kill_hp = nil, math.huge
    local wings_kill_limit = smart_setting(gui.pvp_wings_kill_swap, 20)
    local wings_prediction = smart_setting(gui.pvp_wings_kill_prediction, 2)
    local candidates, seen = {}, {}
    local function add(candidate)
        local guid = unit_guid(candidate)
        if is_enemy_player(player, candidate) and not seen[guid or tostring(candidate)] then
            seen[guid or tostring(candidate)] = true
            candidates[#candidates + 1] = candidate
        end
    end
    add(safe_unit_call(player, "get_target"))
    for _, candidate in pairs(object_list()) do add(candidate) end
    if mode == "arena" and core.object_manager.get_arena_target then
        for index = 1, 5 do
            local ok, candidate = pcall(core.object_manager.get_arena_target, index)
            if ok then add(candidate) end
        end
    end
    for _, enemy in ipairs(candidates) do
        local distance = unit_distance(player, enemy)
        local bound = tonumber(safe_unit_call(enemy, "get_bounding_radius")) or 0
        local effective_distance = math.max(0, distance - math.max(0, math.min(20, bound)))
        local line_of_sight = safe_unit_call(player, "has_line_of_sight", enemy)
        if line_of_sight == nil then line_of_sight = safe_unit_call(enemy, "has_line_of_sight", player) end
        local target_visible = gui.pvp_target_los_filter:get_state() ~= true or line_of_sight ~= false
        local world_engaged = mode ~= "world_pvp" or enemy == safe_unit_call(player, "get_target")
            or (safe_unit_call(enemy, "is_in_combat") == true
                and pressure_for(safe_unit_call(enemy, "get_target"), pressure) ~= nil)
        if effective_distance <= 45 and target_visible and world_engaged
            and not target_is_protected(enemy) and not breakable_cc(enemy) then
            local hp = unit_health_percent(enemy) or 100
            local prediction_window = smart_setting(gui.pvp_target_prediction, 2)
            local projected_hp, _, incoming_heal, forecast_confident, forecast_samples =
                projected_enemy_health(enemy, prediction_window)
            local scoring_hp = gui.pvp_predictive_targeting:get_state() == true
                and (forecast_confident and projected_hp or math.min(100, hp + incoming_heal)) or hp
            local enemy_pressure = pressure_for(enemy, pressure)
            local attack_value = 0
            for _, ally in ipairs(allies) do
                local incoming = pressure_for(ally, pressure)
                if incoming and incoming.count > 0
                    and unit_guid(safe_unit_call(enemy, "get_target")) == unit_guid(ally) then
                    attack_value = math.min(32, 18 + incoming.count * 5 + (incoming.burst and 8 or 0))
                    if safe_unit_call(ally, "get_group_role") == 1 then attack_value = attack_value + 14 end
                    break
                end
            end
            local healer = safe_unit_call(enemy, "get_group_role") == 1 and 6 or 0
            local focus_fire = 0
            if gui.pvp_focus_fire:get_state() == true then
                for _, ally in ipairs(allies) do
                    if ally ~= player and unit_guid(safe_unit_call(ally, "get_target")) == unit_guid(enemy) then
                        focus_fire = focus_fire + 1
                    end
                end
            end
            local objective = runtime_debug.is_objective_carrier(enemy)
            local dangerous_cast = runtime_debug.is_casting_or_channeling(enemy)
                and (is_priority_mplus_interrupt(enemy) or is_pvp_mode(mode))
            local post_trinket = false
            if mode == "arena" and pvp_helper
                and type(pvp_helper.trinket_used_within) == "function" then
                local ok, used = pcall(pvp_helper.trinket_used_within, pvp_helper, enemy,
                    smart_setting(gui.pvp_trinket_window, 8))
                post_trinket = ok and used == true
            end
            local score = scoring_hp + effective_distance * 0.22 - attack_value - healer - (dangerous_cast and 18 or 0)
                - (mode == "battleground" and gui.pvp_objective_priority:get_state() == true and objective and 40 or 0)
                - math.min(24, focus_fire * 8)
                - (post_trinket and 20 or 0)
                + math.min(20, incoming_heal * 0.5)
            if enemy_pressure and enemy_pressure.burst then score = score - 3 end
            if score < best_score then best, best_score = enemy, score end
            local projected_hp, _, _, kill_confident = projected_enemy_health(enemy, wings_prediction)
            if wings_kill_limit > 0 and wings_active(player) and effective_distance <= 8
                and (kill_confident or hp <= wings_kill_limit)
                and projected_hp <= wings_kill_limit and projected_hp < wings_kill_hp then
                wings_kill, wings_kill_hp = enemy, projected_hp
            end
        end
    end
    if not best then return false end
    local current = safe_unit_call(player, "get_target")
    local wings_kill_override = false
    if current == best then return false end
    if is_enemy_player(player, current) and not target_is_protected(current) and not breakable_cc(current) then
        if has_debuff(current, SPELL.EXECUTION_SENTENCE) then
            diagnostic_transition("pvp_sentence_target_lock", unit_guid(current) or tostring(current),
                "INFO", "TARGET", "execution_sentence_target_lock", {
                    target = safe_unit_call(current, "get_name") or "unknown", mode = mode,
                })
            return false
        end
        if gui.pvp_wings_target_lock:get_state() == true and wings_active(player)
            and unit_distance(player, current) <= 12 then
            local current_hp = unit_health_percent(current) or 100
            local kill_swap = wings_kill and wings_kill ~= current
                and current_hp > wings_kill_limit and current_hp - wings_kill_hp >= 20
            if kill_swap then
                best, best_score = wings_kill, wings_kill_hp
                wings_kill_override = true
                decision_trace("pvp_wings_kill_swap", { reason = "nearby_execute_opportunity",
                    current_hp = string.format("%.1f", current_hp),
                    target_hp = string.format("%.1f", unit_health_percent(wings_kill) or wings_kill_hp),
                    projected_hp = string.format("%.1f", wings_kill_hp),
                    target = safe_unit_call(wings_kill, "get_name") or "unknown" })
            else
                diagnostic_transition("pvp_wings_target_lock", unit_guid(current) or tostring(current),
                    "INFO", "TARGET", "wings_target_lock", {
                        target = safe_unit_call(current, "get_name") or "unknown", mode = mode,
                    })
                return false
            end
        end
        local current_hp = unit_health_percent(current) or 100
        local current_effective_hp = current_hp
        if gui.pvp_predictive_execute_lock:get_state() == true then
            current_effective_hp = projected_enemy_health(current,
                smart_setting(gui.pvp_target_prediction, 2))
        end
        -- Finish a vulnerable kill target unless the replacement is carrying an
        -- objective or the current target gained protection.
        local best_objective = runtime_debug.is_objective_carrier(best)
        local execute_lock = smart_setting(gui.pvp_execute_lock, 35)
        if execute_lock > 0 and current_effective_hp <= execute_lock
            and not (mode == "battleground" and gui.pvp_objective_priority:get_state() == true and best_objective) then return false end
        local current_distance = unit_distance(player, current)
        local current_bound = tonumber(safe_unit_call(current, "get_bounding_radius")) or 0
        local current_effective_distance = math.max(0,
            current_distance - math.max(0, math.min(20, current_bound)))
        local current_pressure = pressure_for(current, pressure)
        local current_attack = current_pressure and math.min(32, current_pressure.count * 8
            + (current_pressure.burst and 8 or 0)) or 0
        local current_score = current_effective_hp + current_effective_distance * 0.22 - current_attack
        local uptime_swap = current_effective_distance >= smart_setting(gui.pvp_uptime_swap, 18)
            and unit_distance(player, best) <= 8
        if not wings_kill_override and not uptime_swap and best_score > current_score - 12 then return false end
    end
    local ok, accepted = pcall(core.input.set_target, best)
    if ok and accepted == true then
        last_target_swap = now
        runtime_debug.auto_target_guid = unit_guid(best)
        local best_guid = unit_guid(best)
        pending_target_swap = best_guid and { guid = best_guid, requested_at = now,
            name = safe_unit_call(best, "get_name") or "enemy" } or nil
        combat_stats.swaps = combat_stats.swaps + 1
        last_action = "Target swap → " .. tostring(safe_unit_call(best, "get_name") or "enemy")
        diagnostic_event("ACTION", "TARGET", "target_swap", {
            target = safe_unit_call(best, "get_name") or "unknown", score = best_score,
            target_hp = unit_health_percent(best) or "unknown", mode = mode,
            wings_kill_swap = wings_kill_override,
        })
        return true
    end
    return false
end

target_is_protected = function(target)
    if not target then return false end
    -- Native immunity signals remain authoritative when the optional PvP
    -- helper is absent or still initializing.
    if safe_unit_call(target, "is_immune") == true
        or safe_unit_call(target, "is_damage_immune") == true
        or safe_unit_call(target, "is_invulnerable") == true then return true end
    if not pvp_helper then return false end
    if type(pvp_helper.is_damage_immune) == "function" then
        local ok, immune = pcall(pvp_helper.is_damage_immune, pvp_helper, target)
        if ok and immune == true then return true end
    end
    if type(pvp_helper.has_damage_reduction) == "function" then
        local ok, heavy = pcall(pvp_helper.has_damage_reduction, pvp_helper, target, 50)
        if ok and heavy == true then return true end
    end
    return false
end

local function maybe_swap_pve_target(player, mode, profile)
    if not profile.swap_target or (mode ~= "mythic_plus" and mode ~= "delve")
        or not core.input or type(core.input.set_target) ~= "function" then return false end
    local now = core.time()
    if now < runtime_debug.manual_target_lock_until then return false end
    if now - last_target_swap < smart_setting(gui.target_swap_lock, 3) then return false end
    if safe_unit_call(player, "is_casting_spell") == true
        or safe_unit_call(player, "is_channeling_spell") == true then return false end
    local current = safe_unit_call(player, "get_target")
    local current_valid = is_hostile_unit(player, current) and not target_is_protected(current)
        and not breakable_cc(current) and unit_distance(player, current) <= 45
    local best, best_score, best_priority = nil, math.huge, false
    for _, enemy in pairs(object_list()) do
        if runtime_debug.is_engaged_pve_enemy(player, enemy, current)
            and is_hostile_unit(player, enemy) and unit_distance(player, enemy) <= 45
            and not target_is_protected(enemy) and not breakable_cc(enemy) then
            local hp, distance = unit_health_percent(enemy) or 100, unit_distance(player, enemy)
            local priority = runtime_debug.is_casting_or_channeling(enemy)
                and is_priority_mplus_interrupt(enemy)
            local score = hp + distance * 0.25 - (priority and 55 or 0)
                - (is_boss_or_elite(enemy) and 6 or 0) - (enemy == current and 12 or 0)
            if score < best_score then best, best_score, best_priority = enemy, score, priority end
        end
    end
    if not best or best == current then return false end
    local current_hp = current_valid and (unit_health_percent(current) or 100) or 100
    if current_valid and not best_priority and not ((unit_health_percent(best) or 100) <= 20 and current_hp >= 45) then
        return false
    end
    local ok, accepted = pcall(core.input.set_target, best)
    if ok and accepted == true then
        last_target_swap = now
        runtime_debug.auto_target_guid = unit_guid(best)
        combat_stats.swaps = combat_stats.swaps + 1
        diagnostic_event("ACTION", "TARGET", "pve_priority_target_swap", {
            target = safe_unit_call(best, "get_name") or "unknown", score = string.format("%.1f", best_score),
            priority_cast = best_priority, mode = mode,
        })
        return true
    end
    return false
end

local function has_cc_immunity(target)
    local immune = safe_unit_call(target, "is_cc_immune", nil, 100)
    if immune == true then return true end
    if pvp_helper and type(pvp_helper.is_cc_immune) == "function" then
        local ok, helper_immune = pcall(pvp_helper.is_cc_immune, pvp_helper, target, nil, 100)
        if ok and helper_immune == true then return true end
    end
    return false
end

-- Midnight 12.1 PvP stun DR resets after 20 seconds and reaches immunity after
-- two applications. Keep a conservative local request lockout when the engine
-- cannot provide a reliable DR value.
local pvp_stun_requests = {}
local pvp_disorient_requests = {}
local pvp_healer_lockouts = {}
local function stun_dr_ready(target)
    local guid = unit_guid(target) or tostring(target)
    local requested_at = pvp_stun_requests[guid]
    if requested_at and core.time() - requested_at < runtime_debug.pvp_dr_fallback_seconds then return false end
    local dr = safe_unit_call(target, "get_dr", "stun", 0)
    if type(dr) ~= "number" and pvp_helper and pvp_helper.cc_flags
        and type(pvp_helper.get_unit_dr) == "function" then
        local ok, value = pcall(pvp_helper.get_unit_dr, pvp_helper, target, pvp_helper.cc_flags.STUN, 0)
        if ok then dr = value end
    end
    if type(dr) == "number" then
        -- Do not spend Hammer of Justice when the engine reports partial or
        -- uninitialized DR. Full DR is the only confirmed ready state.
        return dr >= 0.99 and dr <= 1.01
    end
    return not confirmed_cc(target, "is_stunned", "STUN", 100)
end

local function disorient_dr_ready(target)
    local guid = unit_guid(target) or tostring(target)
    if pvp_disorient_requests[guid]
        and core.time() - pvp_disorient_requests[guid] < runtime_debug.pvp_dr_fallback_seconds then return false end
    local flags = pvp_helper and pvp_helper.cc_flags
    if flags and flags.DISORIENT and type(pvp_helper.get_unit_dr) == "function" then
        local ok, value = pcall(pvp_helper.get_unit_dr, pvp_helper, target, flags.DISORIENT, 0)
        if ok and type(value) == "number" then return value >= 0.99 and value <= 1.01 end
    end
    return not confirmed_cc(target, nil, "DISORIENT", 100)
end

local function choose_cc_target(player, selected, mode, pressure, allies)
    local best, best_score = nil, 0
    local candidates, seen = {}, {}
    local function add(unit)
        local guid = unit_guid(unit)
        if is_enemy_player(player, unit) and not seen[guid or tostring(unit)] then
            seen[guid or tostring(unit)] = true
            candidates[#candidates + 1] = unit
        end
    end
    add(selected)
    for _, enemy in pairs(object_list()) do add(enemy) end
    if mode == "arena" and core.object_manager.get_arena_target then
        for index = 1, 5 do
            local ok, enemy = pcall(core.object_manager.get_arena_target, index)
            if ok then add(enemy) end
        end
    end
    for _, enemy in ipairs(candidates) do
        if unit_distance(player, enemy) <= 10
            and runtime_debug.spell_target_reachable(SPELL.HAMMER_OF_JUSTICE, enemy, player)
            and not has_cc_immunity(enemy)
            and not confirmed_cc(enemy, "is_cc", "ANY_BUT_ROOT", 250) and stun_dr_ready(enemy) then
            local score, role = 0, safe_unit_call(enemy, "get_group_role")
            if role == 1 then score = score + 18 end
            local enemy_target_guid = unit_guid(safe_unit_call(enemy, "get_target"))
            for _, ally in ipairs(allies or {}) do
                local focus = pressure_for(ally, pressure)
                if focus and focus.count > 0 and enemy_target_guid == unit_guid(ally) then
                    score = score + 8
                    if safe_unit_call(ally, "get_group_role") == 1 then score = score + 12 end
                    if focus.burst then score = score + 10 end
                    break
                end
            end
            local cast = runtime_debug.is_casting_or_channeling(enemy)
                and runtime_debug.is_interruptible_cast(enemy)
            if cast then score = score + 8 end
            local hp = unit_health_percent(enemy)
            if hp and hp <= 40 then score = score + 5 end
            if enemy == selected then score = score + 3 end
            if score > best_score then best, best_score = enemy, score end
        end
    end
    return best, best_score
end

local function choose_pvp_interrupt_target(player, selected, mode)
    local best, best_score = nil, -math.huge
    local seen = {}
    local function consider(enemy)
        local guid = unit_guid(enemy) or tostring(enemy)
        if seen[guid] or not is_enemy_player(player, enemy) or breakable_cc(enemy)
            or not runtime_debug.spell_target_reachable(SPELL.REBUKE, enemy, player)
            or not runtime_debug.is_casting_or_channeling(enemy)
            or not runtime_debug.is_interruptible_cast(enemy) then return end
        seen[guid] = true
        local progress = runtime_debug.active_cast_progress(enemy)
        local healer = safe_unit_call(enemy, "get_group_role") == 1
        local victim = safe_unit_call(enemy, "get_target")
        local victim_hp = unit_health_percent(victim) or 100
        local objective_victim = mode == "battleground" and victim
            and runtime_debug.is_objective_carrier(victim)
        local threshold = healer and smart_setting(gui.pvp_healer_interrupt, 35)
            or smart_setting(gui.pvp_dps_interrupt, 70)
        if victim_hp <= 35 then threshold = math.max(20, threshold - 20) end
        local remaining = runtime_debug.cast_remaining and runtime_debug.cast_remaining(enemy) or nil
        local commit_window = mode == "arena"
            and smart_setting(gui.arena_kick_commit_ms, 450) / 1000 or math.huge
        if progress < threshold or (remaining and remaining > commit_window) then return end
        local score = progress + (healer and 45 or 0) + (victim_hp <= 50 and 25 or 0)
            + (objective_victim and 60 or 0)
            + (remaining and remaining <= 0.18 and 500 or 0)
            + (enemy == selected and 5 or 0)
        if score > best_score then best, best_score = enemy, score end
    end
    consider(selected)
    for _, enemy in pairs(object_list()) do consider(enemy) end
    if mode == "arena" and core.object_manager.get_arena_target then
        for index = 1, 5 do
            local ok, enemy = pcall(core.object_manager.get_arena_target, index)
            if ok then consider(enemy) end
        end
    end
    return best, best_score
end

local function run_pvp_utility(player, target, mode, profile, pressure, allies)
    if not is_pvp_mode(mode) or not profile.cc then return false end
    local interrupt_target, interrupt_score = choose_pvp_interrupt_target(player, target, mode)
    if interrupt_target and cast(SPELL.REBUKE, interrupt_target, player) then
        diagnostic_event("ACTION", "INTERRUPT", "pvp_interrupt_selected", {
            target = safe_unit_call(interrupt_target, "get_name") or "unknown",
            off_target = interrupt_target ~= target, score = string.format("%.1f", interrupt_score), mode = mode,
        })
        return true
    end
    if mode == "arena" and gui.arena_offtarget_blind:get_state() == true
        and has_spell(SPELL.BLINDING_LIGHT) and not target_is_protected(target)
        and not breakable_cc(target) and (unit_health_percent(target) or 100) <= 70
        and (tonumber(safe_unit_call(player, "get_power", HOLY_POWER)) or 0) >= 3 then
        local healer_ready, seen_healers = false, {}
        local function consider_healer(enemy)
            local guid = unit_guid(enemy) or tostring(enemy)
            if seen_healers[guid] then return end
            seen_healers[guid] = true
            if enemy ~= target and is_enemy_player(player, enemy)
                and safe_unit_call(enemy, "get_group_role") == 1
                and unit_distance(player, enemy) <= 10 and not has_cc_immunity(enemy)
                and not confirmed_cc(enemy, "is_cc", "ANY_BUT_ROOT", 250)
                and disorient_dr_ready(enemy) then
                healer_ready = true
            end
        end
        for _, enemy in pairs(object_list()) do consider_healer(enemy) end
        if core.object_manager.get_arena_target then
            for index = 1, 5 do
                local ok, enemy = pcall(core.object_manager.get_arena_target, index)
                if ok then consider_healer(enemy) end
            end
        end
        if healer_ready and cast(SPELL.BLINDING_LIGHT, player, player) then
            for _, enemy in pairs(object_list()) do
                if is_enemy_player(player, enemy) and unit_distance(player, enemy) <= 10 then
                    pvp_disorient_requests[unit_guid(enemy) or tostring(enemy)] = core.time()
                end
            end
            diagnostic_event("ACTION", "INTERRUPT", "arena_offtarget_healer_blind", {
                target = safe_unit_call(target, "get_name") or "unknown",
                target_hp = string.format("%.1f", unit_health_percent(target) or 100),
                holy_power = tonumber(safe_unit_call(player, "get_power", HOLY_POWER)) or 0,
            })
            return true
        end
    end
    local self_pressure = pressure_for(player, pressure)
    if self_pressure and self_pressure.count >= 2 and self_pressure.melee
        and pvp_cleave_safe(player, target, 10, true)
        and disorient_dr_ready(target)
        and cast(SPELL.BLINDING_LIGHT, player, player) then
        for _, enemy in pairs(object_list()) do
            if is_enemy_player(player, enemy) and unit_distance(player, enemy) <= 10 then
                pvp_disorient_requests[unit_guid(enemy) or tostring(enemy)] = core.time()
            end
        end
        diagnostic_event("ACTION", "INTERRUPT", "multi_attacker_peel", {
            attackers = self_pressure.count, burst = self_pressure.burst == true, mode = mode,
        })
        return true
    end
    if self_pressure and self_pressure.count >= 2 and self_pressure.melee
        and self_pressure.burst == true and has_spell(SPELL.SEARING_GLARE)
        and cast(SPELL.SEARING_GLARE, player, player) then
        diagnostic_event("ACTION", "INTERRUPT", "multi_attacker_searing_glare", {
            attackers = self_pressure.count, burst = true, mode = mode,
        })
        return true
    end
    local cc_target, score = choose_cc_target(player, target, mode, pressure, allies)
    local stun_intent = nil
    if score >= 8 and cc_target then
        local victim = safe_unit_call(cc_target, "get_target")
        local victim_hp = unit_health_percent(victim) or 100
        local victim_pressure = pressure_for(victim, pressure)
        local peel_limit = smart_setting(gui.pvp_emergency_peel_hp, 40)
        local emergency_peel = victim and (victim == player
            or safe_unit_call(victim, "is_party_member") == true)
            and ((peel_limit > 0 and victim_hp <= peel_limit)
                or (victim_pressure and victim_pressure.burst == true))
        if emergency_peel then
            stun_intent = "emergency_peel"
        else
            local role = safe_unit_call(cc_target, "get_group_role")
            local offensive_target = cc_target == target or role == 1
            local minimum_power = smart_setting(gui.pvp_offensive_stun_power, 3)
            local holy_power = tonumber(safe_unit_call(player, "get_power", HOLY_POWER)) or 0
            local resource_ready = minimum_power <= 0 or holy_power >= minimum_power
            local opening_delay = smart_setting(gui.pvp_offensive_cc_delay, 3)
            local elapsed = math.max(0, core.time() - (combat_stats.started or core.time()))
            local target_ready = is_enemy_player(player, target) and not target_is_protected(target)
                and not breakable_cc(target)
                and unit_distance(player, target) <= smart_setting(gui.pvp_burst_max_range, 12)
            if offensive_target and resource_ready and elapsed >= opening_delay and target_ready then
                stun_intent = role == 1 and "healer_kill_setup" or "kill_target_setup"
            else
                decision_trace("pvp_stun_hold", { reason = not offensive_target and "no_offensive_target"
                    or not resource_ready and "insufficient_holy_power"
                    or elapsed < opening_delay and "opening_delay"
                    or "kill_target_not_ready", holy_power = holy_power,
                    required = minimum_power, elapsed = string.format("%.1f", elapsed) })
            end
        end
    end
    if stun_intent and cast(SPELL.HAMMER_OF_JUSTICE, cc_target, player) then
        pvp_stun_requests[unit_guid(cc_target) or tostring(cc_target)] = core.time()
        diagnostic_event("ACTION", "INTERRUPT", "pvp_stun_committed", {
            target = safe_unit_call(cc_target, "get_name") or "unknown",
            dr_lockout_seconds = runtime_debug.pvp_dr_fallback_seconds,
            score = score, mode = mode, intent = stun_intent,
        })
        return true
    end
    return false
end

local function is_heal_immune(unit)
    if safe_unit_call(unit, "is_immune_to_heal") == true then return true end
    if pvp_helper and type(pvp_helper.is_immune_to_heal) == "function" then
        local ok, immune = pcall(pvp_helper.is_immune_to_heal, pvp_helper, unit, 100)
        if ok and immune == true then return true end
    end
    return false
end

local function has_cleanseable_debuff(unit)
    local best_severity = 0
    for _, method in ipairs({ "get_debuffs", "get_auras" }) do
        local ok, debuffs = pcall(function() return unit[method](unit) end)
        if ok and type(debuffs) == "table" then
            for _, aura in pairs(debuffs) do
                local kind
                pcall(function()
                    kind = aura.type or aura.dispel_type or aura.dispelType or aura.dispel_name or aura.dispelName
                end)
                local avoid, urgent = false, false
                pcall(function()
                    avoid = aura.do_not_dispel == true or aura.dispel_punishes == true
                    urgent = aura.is_deadly == true or aura.priority == "high" or (tonumber(aura.stacks or aura.count) or 0) >= 3
                end)
                if avoid then kind = nil end
                if type(kind) == "string" then
                    kind = string.lower(kind)
                    if kind == "poison" or kind == "disease" then best_severity = math.max(best_severity, urgent and 2 or 1) end
                elseif type(kind) == "number" and enums.buff_type then
                    if kind == enums.buff_type.POISON or kind == enums.buff_type.DISEASE then
                        best_severity = math.max(best_severity, urgent and 2 or 1)
                    end
                end
            end
        end
    end
    return best_severity > 0, best_severity
end

local function run_personal_defensives(player, profile, pressure)
    if not profile.defensives then return false end
    local health = unit_health_percent(player)
    if not health then return false end
    local window = 0
    if is_pvp_mode(runtime_debug.active_mode) and gui.pvp_predictive_defense:get_state() == true then
        window = smart_setting(gui.pvp_prediction_window, 2)
    elseif not is_pvp_mode(runtime_debug.active_mode) then
        window = smart_setting(gui.pve_prediction_window, 2)
    end
    local danger, loss, incoming = incoming_danger(player, pressure, window)
    local predicted_health, prediction_source = runtime_debug.predicted_health_percent(
        player, health, window, loss, incoming)
    local defensive_health = math.min(health, predicted_health)
    runtime_debug.danger = string.format("%.0f", danger)
    local lowest = math.max(get_threshold(gui.lay_on_hands), get_threshold(gui.divine_shield),
        get_threshold(gui.shield_of_vengeance), get_threshold(gui.divine_protection),
        get_threshold(gui.word_of_glory), get_threshold(gui.holy_light))
    diagnostic_transition("self_defensive_band", defensive_health <= lowest and "inside_thresholds" or "healthy",
        "INFO", "DEFENSIVE", "health_band_changed", {
            hp = string.format("%.1f", health), loh = get_threshold(gui.lay_on_hands),
            bubble = get_threshold(gui.divine_shield), protection = get_threshold(gui.divine_protection),
            vengeance = get_threshold(gui.shield_of_vengeance), wog = get_threshold(gui.word_of_glory),
            holy_light = get_threshold(gui.holy_light), danger = string.format("%.1f", danger),
            health_loss_per_second = string.format("%.1f", loss), incoming_pct = string.format("%.1f", incoming),
            predicted_hp = string.format("%.1f", predicted_health), prediction_source = prediction_source,
        })
    if below_threshold(gui.lay_on_hands, defensive_health) and not is_heal_immune(player)
        and not has_debuff(player, SPELL.FORBEARANCE)
        and cast_defensive(SPELL.LAY_ON_HANDS, player) then return true end
    -- Native usability handles Light's Revocation, which permits Divine Shield
    -- during Forbearance when talented. LoH and BoP retain explicit guards.
    local carrying_objective = runtime_debug.active_mode == "battleground"
        and runtime_debug.is_objective_carrier(player)
    if below_threshold(gui.divine_shield, defensive_health) and not carrying_objective
        and cast_defensive(SPELL.DIVINE_SHIELD, player) then return true end
    if carrying_objective and below_threshold(gui.divine_shield, defensive_health) then
        diagnostic_transition("objective_immunity_hold", "holding", "INFO", "DEFENSIVE",
            "divine_shield_held_for_objective", { hp = string.format("%.1f", health) })
    end
    local healer_cc_wall = smart_setting(gui.arena_healer_cc_wall, 70)
    local self_pressure = pressure_for(player, pressure)
    local external_active = false
    if pvp_helper and type(pvp_helper.has_damage_reduction) == "function" then
        local ok, active = pcall(pvp_helper.has_damage_reduction, pvp_helper, player, 35)
        external_active = ok and active == true
    end
    if runtime_debug.active_mode == "arena" and healer_cc_wall > 0
        and runtime_debug.healer_state == "controlled" and defensive_health <= healer_cc_wall
        and self_pressure and (self_pressure.count > 0 or self_pressure.burst)
        and not external_active and cast_defensive(SPELL.DIVINE_PROTECTION, player) then
        diagnostic_event("ACTION", "DEFENSIVE", "arena_healer_cc_early_wall", {
            hp = string.format("%.1f", health), predicted_hp = string.format("%.1f", predicted_health),
            attackers = self_pressure.count or 0, burst = self_pressure.burst == true,
        })
        return true
    end
    if below_threshold(gui.shield_of_vengeance, defensive_health)
        and cast_defensive(SPELL.SHIELD_OF_VENGEANCE, player) then return true end
    if below_threshold(gui.divine_protection, defensive_health)
        and cast_defensive(SPELL.DIVINE_PROTECTION, player) then return true end
    if below_threshold(gui.word_of_glory, defensive_health)
        and cast_defensive(word_of_glory_spell(), player) then return true end
    if below_threshold(gui.holy_light, defensive_health)
        and cast_defensive(SPELL.HOLY_LIGHT, player) then return true end
    return false
end

local function run_team_support(player, mode, profile, allies, pressure)
    if not profile.team_support or not (is_pvp_mode(mode) or mode == "mythic_plus"
        or mode == "delve" or mode == "world_pve") then return false end
    if is_pvp_mode(mode) and gui.pvp_self_sanctuary:get_state() == true
        and has_spell(SPELL.BLESSING_OF_SANCTUARY) then
        local self_controlled = confirmed_cc(player, "is_stunned", "STUN", 100)
            or confirmed_cc(player, "is_silenced", "SILENCE", 100)
            or confirmed_cc(player, "is_feared", "FEAR", 100)
            or confirmed_cc(player, "is_horrified", "HORROR", 100)
        if self_controlled and cast(SPELL.BLESSING_OF_SANCTUARY, player, player) then
            diagnostic_event("ACTION", "SUPPORT", "self_sanctuary_escape", { mode = mode })
            return true
        end
    end
    if is_pvp_mode(mode) then
        local cleanseable, severity = has_cleanseable_debuff(player)
        if cleanseable and severity >= 2 and cast(SPELL.CLEANSE_TOXINS, player, player) then
            diagnostic_event("ACTION", "SUPPORT", "urgent_self_cleanse", {
                severity = severity, mode = mode,
            })
            return true
        end
    end
    local candidates = {}
    for _, ally in ipairs(allies or {}) do
        if ally ~= player and is_valid_unit(ally) and unit_distance(player, ally) <= 40 then
            local hp = unit_health_percent(ally)
            local los = safe_unit_call(player, "has_line_of_sight", ally)
            if los == nil then los = safe_unit_call(ally, "has_line_of_sight", player) end
            if hp and hp > 0 and los ~= false then
                local focus = pressure_for(ally, pressure)
                local prediction_window = 0
                if is_pvp_mode(mode) and gui.pvp_predictive_defense:get_state() == true then
                    prediction_window = smart_setting(gui.pvp_prediction_window, 2)
                elseif not is_pvp_mode(mode) then
                    prediction_window = smart_setting(gui.pve_prediction_window, 2)
                end
                local danger, loss, incoming_pct = incoming_danger(ally, pressure, prediction_window)
                local predicted_hp, prediction_source = runtime_debug.predicted_health_percent(
                    ally, hp, prediction_window, loss, incoming_pct)
                local queued_heal_pct, heal_absorb_pct, net_queued_heal_pct, shield_pct =
                    runtime_debug.healing_context(ally)
                danger = danger + math.min(20, heal_absorb_pct * 0.5)
                local objective_carrier = runtime_debug.is_objective_carrier(ally)
                if mode == "battleground" and objective_carrier then danger = danger + 30 end
                local external = false
                if pvp_helper and type(pvp_helper.has_damage_reduction) == "function" then
                    local ok, active = pcall(pvp_helper.has_damage_reduction, pvp_helper, ally, 35)
                    external = ok and active == true
                end
                candidates[#candidates + 1] = {
                    unit = ally, hp = hp, predicted_hp = predicted_hp,
                    prediction_source = prediction_source,
                    effective_hp = math.min(hp, predicted_hp), focus = focus,
                    -- Give cancellable incoming heals partial credit only for
                    -- the ordinary WoG/Eternal Flame decision.
                    minor_heal_hp = math.min(100,
                        math.min(hp, predicted_hp) + net_queued_heal_pct * 0.5
                            + shield_pct * 0.5),
                    queued_heal_pct = queued_heal_pct, heal_absorb_pct = heal_absorb_pct,
                    shield_pct = shield_pct,
                    danger = danger, external_defensive = external, objective_carrier = objective_carrier,
                    physical_relevant = safe_unit_call(ally,
                        "is_physical_damage_taken_relevant") == true,
                    pressured = objective_carrier or (focus and (focus.count > 0 or focus.swap))
                        or incoming_pct > 0,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.danger == b.danger then return a.hp < b.hp end
        return a.danger > b.danger
    end)
    local lowest = candidates[1]
    diagnostic_transition("support_lowest_ally",
        lowest and ((safe_unit_call(lowest.unit, "get_name") or "unknown") .. ":" .. math.floor(lowest.hp)) or "none",
        "INFO", "SUPPORT", "lowest_eligible_ally_changed", {
            ally = lowest and (safe_unit_call(lowest.unit, "get_name") or "unknown") or "none",
            hp = lowest and string.format("%.1f", lowest.hp) or "none",
            predicted_hp = lowest and string.format("%.1f", lowest.predicted_hp) or "none",
            prediction_source = lowest and lowest.prediction_source or "none",
            queued_heal_pct = lowest and string.format("%.1f", lowest.queued_heal_pct) or "none",
            heal_absorb_pct = lowest and string.format("%.1f", lowest.heal_absorb_pct) or "none",
            shield_pct = lowest and string.format("%.1f", lowest.shield_pct) or "none",
            pressured = lowest and lowest.pressured or false, danger = lowest and string.format("%.1f", lowest.danger) or "none",
            candidates = #candidates,
        })
    -- Sanctuary is PvP-only utility: remove a confirmed stun, silence, fear,
    -- or horror before spending healing globals into a controlled teammate.
    if is_pvp_mode(mode) and has_spell(SPELL.BLESSING_OF_SANCTUARY) then
        for pass = 1, 2 do
            for _, candidate in ipairs(candidates) do
                local ally = candidate.unit
                local healer = safe_unit_call(ally, "get_group_role") == 1
                local hard_cc = confirmed_cc(ally, "is_stunned", "STUN", 100)
                    or confirmed_cc(ally, "is_silenced", "SILENCE", 100)
                    or confirmed_cc(ally, "is_feared", "FEAR", 100)
                    or confirmed_cc(ally, "is_horrified", "HORROR", 100)
                if (pass == 1 and healer or pass == 2 and not healer)
                    and hard_cc and cast(SPELL.BLESSING_OF_SANCTUARY, ally, player) then return true end
            end
        end
    end
    local pre_sanctuary_hp = smart_setting(gui.pvp_pre_sanctuary, 70)
    if is_pvp_mode(mode) and pre_sanctuary_hp > 0 and has_spell(SPELL.BLESSING_OF_SANCTUARY) then
        for _, candidate in ipairs(candidates) do
            local ally, focus = candidate.unit, candidate.focus
            if safe_unit_call(ally, "get_group_role") == 1 and candidate.effective_hp <= pre_sanctuary_hp
                and focus and focus.burst and not has_buff(ally, SPELL.BLESSING_OF_SANCTUARY)
                and cast(SPELL.BLESSING_OF_SANCTUARY, ally, player) then
                diagnostic_event("ACTION", "SUPPORT", "preemptive_healer_sanctuary", {
                    target = safe_unit_call(ally, "get_name") or "unknown",
                    hp = string.format("%.1f", candidate.hp),
                    predicted_hp = string.format("%.1f", candidate.predicted_hp), mode = mode,
                })
                return true
            end
        end
    end
    if runtime_debug.try_hallowed_ground(player, candidates, mode) then return true end
    if is_pvp_mode(mode) and gui.pvp_priority_freedom:get_state() == true then
        for pass = 1, 3 do
            for _, candidate in ipairs(candidates) do
                local ally = candidate.unit
                local healer = safe_unit_call(ally, "get_group_role") == 1
                local chosen = pass == 1 and candidate.objective_carrier
                    or pass == 2 and healer and not candidate.objective_carrier
                    or pass == 3 and not healer and not candidate.objective_carrier
                if chosen and (healer or candidate.pressured)
                    and movement_impaired(ally) and not has_buff(ally, SPELL.BLESSING_OF_FREEDOM)
                    and cast(SPELL.BLESSING_OF_FREEDOM, ally, player) then
                    diagnostic_event("ACTION", "SUPPORT", "priority_freedom", {
                        target = safe_unit_call(ally, "get_name") or "unknown", healer = healer, mode = mode,
                    })
                    return true
                end
            end
        end
    end
    if is_pvp_mode(mode) then
        for pass = 1, 3 do
            for _, candidate in ipairs(candidates) do
                local ally = candidate.unit
                local healer = safe_unit_call(ally, "get_group_role") == 1
                local cleanseable, severity = has_cleanseable_debuff(ally)
                local chosen = pass == 1 and candidate.objective_carrier
                    or pass == 2 and healer and not candidate.objective_carrier
                    or pass == 3 and not healer and not candidate.objective_carrier
                if chosen and cleanseable and severity >= 2
                    and cast(SPELL.CLEANSE_TOXINS, ally, player) then
                    diagnostic_event("ACTION", "SUPPORT", "urgent_pvp_cleanse", {
                        target = safe_unit_call(ally, "get_name") or "unknown",
                        severity = severity, objective_carrier = candidate.objective_carrier, mode = mode,
                    })
                    return true
                end
            end
        end
    end
    local self_hp = unit_health_percent(player) or 100
    local self_window = 0
    if is_pvp_mode(mode) and gui.pvp_predictive_defense:get_state() == true then
        self_window = smart_setting(gui.pvp_prediction_window, 2)
    elseif mode == "mythic_plus" or mode == "delve" or mode == "world_pve" then
        self_window = smart_setting(gui.pve_prediction_window, 2)
    end
    local _, self_loss, self_incoming = incoming_danger(player, pressure, self_window)
    local predicted_self_hp = runtime_debug.predicted_health_percent(
        player, self_hp, self_window, self_loss, self_incoming)
    local swap_sacrifice_hp = smart_setting(gui.pvp_swap_sacrifice, 85)
    if is_pvp_mode(mode) and swap_sacrifice_hp > 0 and predicted_self_hp > 55 then
        for _, candidate in ipairs(candidates) do
            local focus = candidate.focus
            if focus and focus.swap and candidate.effective_hp <= swap_sacrifice_hp
                and not candidate.external_defensive
                and cast_defensive(SPELL.BLESSING_OF_SACRIFICE, player, candidate.unit) then
                diagnostic_event("ACTION", "SUPPORT", "target_swap_sacrifice", {
                    target = safe_unit_call(candidate.unit, "get_name") or "unknown",
                    hp = string.format("%.1f", candidate.hp), predicted_hp = string.format("%.1f", candidate.predicted_hp),
                    attackers = focus.count or 0, swaps = focus.swap_count or 1, mode = mode,
                    predicted_self_hp = string.format("%.1f", predicted_self_hp),
                })
                return true
            end
        end
    end
    local burst_sacrifice_hp = smart_setting(gui.pvp_burst_sacrifice, 75)
    if is_pvp_mode(mode) and burst_sacrifice_hp > 0 and predicted_self_hp > 50 then
        for _, candidate in ipairs(candidates) do
            local ally, focus = candidate.unit, candidate.focus
            if safe_unit_call(ally, "get_group_role") == 1 and candidate.effective_hp <= burst_sacrifice_hp
                and focus and focus.burst and not candidate.external_defensive
                and cast_defensive(SPELL.BLESSING_OF_SACRIFICE, player, ally) then
                diagnostic_event("ACTION", "SUPPORT", "preemptive_burst_sacrifice", {
                    target = safe_unit_call(ally, "get_name") or "unknown",
                    hp = string.format("%.1f", candidate.hp), limit = burst_sacrifice_hp, mode = mode,
                    predicted_self_hp = string.format("%.1f", predicted_self_hp),
                })
                return true
            end
        end
    end
    local dampening = runtime_debug.read_dampening(player)
    local high_dampening = mode == "arena" and smart_setting(gui.pvp_dampening_mitigation, 30) > 0
        and dampening >= smart_setting(gui.pvp_dampening_mitigation, 30)
    for _, candidate in ipairs(candidates) do
        local ally = candidate.unit
        if not high_dampening and not is_heal_immune(ally)
            and below_threshold(gui.ally_lay_on_hands, candidate.effective_hp)
            and not has_debuff(ally, SPELL.FORBEARANCE)
            and cast_defensive(SPELL.LAY_ON_HANDS, player, ally) then return true end
    end
    for _, candidate in ipairs(candidates) do
        local ally = candidate.unit
        local ally_melee = false
        if pvp_helper and type(pvp_helper.is_melee) == "function" then
            local ok, melee = pcall(pvp_helper.is_melee, pvp_helper, ally)
            ally_melee = ok and melee == true
        end
        local ally_tank = safe_unit_call(ally, "get_group_role") == 2
        -- BoP suppresses physical attacks. A confirmed melee teammate receives
        -- it only as a lethal rescue at half the configured hard threshold.
        local bop_limit = get_threshold(gui.ally_blessing_of_protection)
        local role_safe = (not ally_melee and not ally_tank)
            or candidate.effective_hp <= math.max(1, bop_limit * 0.5)
        -- Spellwarding replaces BoP for confirmed magical pressure when the
        -- PvP talent is learned. Require a caster actively casting at this
        -- ally or using burst so an unknown damage school cannot consume it.
        if is_pvp_mode(mode) and has_spell(SPELL.BLESSING_OF_SPELLWARDING)
            and not candidate.objective_carrier and not candidate.external_defensive
            and candidate.pressured and candidate.focus and candidate.focus.caster
            and (candidate.focus.cast_targeted or candidate.focus.burst)
            and bop_limit > 0 and candidate.effective_hp <= bop_limit
            and not has_debuff(ally, SPELL.FORBEARANCE)
            and cast_defensive(SPELL.BLESSING_OF_SPELLWARDING, player, ally) then
            diagnostic_event("ACTION", "SUPPORT", "spellwarding_magic_triage", {
                target = safe_unit_call(ally, "get_name") or "unknown",
                hp = string.format("%.1f", candidate.effective_hp), limit = bop_limit,
                cast_targeted = candidate.focus.cast_targeted == true,
                burst = candidate.focus.burst == true,
            })
            return true
        end
        if not candidate.objective_carrier and not candidate.external_defensive and role_safe
            and candidate.pressured
            and ((candidate.focus and candidate.focus.melee) or candidate.physical_relevant)
            and bop_limit > 0 and candidate.effective_hp <= bop_limit
            and not has_debuff(ally, SPELL.FORBEARANCE)
            and cast_defensive(SPELL.BLESSING_OF_PROTECTION, player, ally) then
            diagnostic_event("ACTION", "SUPPORT", "bop_role_triage", {
                target = safe_unit_call(ally, "get_name") or "unknown",
                melee = ally_melee, tank = ally_tank,
                predicted_physical = candidate.physical_relevant,
                hp = string.format("%.1f", candidate.effective_hp), limit = bop_limit,
            })
            return true
        end
    end
    for _, candidate in ipairs(candidates) do
        local ally = candidate.unit
        if predicted_self_hp > 35 and candidate.pressured and not candidate.external_defensive
            and below_threshold(gui.ally_blessing_of_sacrifice, candidate.effective_hp)
            and cast_defensive(SPELL.BLESSING_OF_SACRIFICE, player, ally) then
            diagnostic_event("ACTION", "SUPPORT", "predictive_sacrifice", {
                target = safe_unit_call(ally, "get_name") or "unknown",
                predicted_self_hp = string.format("%.1f", predicted_self_hp), mode = mode,
            })
            return true
        end
    end
    if high_dampening then
        for _, candidate in ipairs(candidates) do
            local ally = candidate.unit
            if not is_heal_immune(ally) and below_threshold(gui.ally_lay_on_hands, candidate.effective_hp)
                and not has_debuff(ally, SPELL.FORBEARANCE)
                and cast_defensive(SPELL.LAY_ON_HANDS, player, ally) then return true end
        end
    end
    for _, candidate in ipairs(candidates) do
        local ally = candidate.unit
        if below_threshold(gui.ally_word_of_glory, candidate.minor_heal_hp) and not is_heal_immune(ally)
            and cast_defensive(word_of_glory_spell(), player, ally) then return true end
    end
    for _, candidate in ipairs(candidates) do
        local ally = candidate.unit
        if has_cleanseable_debuff(ally) and cast(SPELL.CLEANSE_TOXINS, ally, player) then return true end
        if movement_impaired(ally) and not has_buff(ally, SPELL.BLESSING_OF_FREEDOM)
            and cast(SPELL.BLESSING_OF_FREEDOM, ally, player) then return true end
    end
    if has_cleanseable_debuff(player) and cast(SPELL.CLEANSE_TOXINS, player, player) then return true end
    if movement_impaired(player) and not has_buff(player, SPELL.BLESSING_OF_FREEDOM)
        and cast(SPELL.BLESSING_OF_FREEDOM, player, player) then return true end
    return false
end

local pvp_burst_stage = {}
local function burst_target_is_ready(target, mode, player)
    if not is_pvp_mode(mode) then return true end
    local guid = unit_guid(target) or tostring(target)
    local survival_limit = smart_setting(gui.pvp_burst_survival, 40)
    if survival_limit > 0 then
        local player_hp = unit_health_percent(player) or 100
        local prediction_window = 0
        if gui.pvp_predictive_defense:get_state() == true then
            prediction_window = smart_setting(gui.pvp_prediction_window, 2)
        end
        local _, loss, incoming = incoming_danger(player, nil, prediction_window)
        local predicted_hp = runtime_debug.predicted_health_percent(
            player, player_hp, prediction_window, loss, incoming)
        if predicted_hp <= survival_limit then
            pvp_burst_stage[guid] = "hold_personal_survival"
            decision_trace("pvp_burst_hold", { reason = "projected_self_danger",
                player_hp = string.format("%.1f", player_hp),
                predicted_hp = string.format("%.1f", predicted_hp), limit = survival_limit })
            return false
        end
    end
    if target_is_protected(target) then
        pvp_burst_stage[guid] = "cancelled_protected"
        decision_trace("pvp_burst_cancel", { reason = "target_defensive", target = safe_unit_call(target, "get_name") })
        return false
    end
    if has_debuff(target, SPELL.EXECUTION_SENTENCE) then
        pvp_burst_stage[guid] = "commit_sentence_active"
        return true
    end
    local hp = unit_health_percent(target)
    if wings_active(player) then
        pvp_burst_stage[guid] = "commit_wings_active"
        return true
    end
    if hp ~= nil and hp <= 20 then
        pvp_burst_stage[guid] = "commit_execute"
        return true
    end
    local burst_range = smart_setting(gui.pvp_burst_max_range, 12)
    local distance = unit_distance(player, target)
    if distance > burst_range then
        pvp_burst_stage[guid] = "hold_range"
        decision_trace("pvp_burst_hold", { reason = "target_out_of_burst_range",
            distance = string.format("%.1f", distance), limit = burst_range })
        return false
    end
    local line_of_sight = safe_unit_call(player, "has_line_of_sight", target)
    if line_of_sight == nil then line_of_sight = safe_unit_call(target, "has_line_of_sight", player) end
    if line_of_sight == false then
        pvp_burst_stage[guid] = "hold_line_of_sight"
        decision_trace("pvp_burst_hold", { reason = "target_line_of_sight_blocked" })
        return false
    end
    local heal_hold = smart_setting(gui.pvp_burst_heal_hold, 20)
    if heal_hold > 0 then
        local _, _, incoming_heal = projected_enemy_health(target,
            smart_setting(gui.pvp_target_prediction, 2))
        if incoming_heal >= heal_hold and (hp or 100) > smart_setting(gui.pvp_execute_spend, 35) then
            pvp_burst_stage[guid] = "hold_incoming_healing"
            decision_trace("pvp_burst_hold", { reason = "large_incoming_heal",
                incoming_heal = string.format("%.1f", incoming_heal), limit = heal_hold })
            return false
        end
    end
    local minimum_power = smart_setting(gui.pvp_burst_min_power, 3)
    local current_power = tonumber(safe_unit_call(player, "get_power", HOLY_POWER)) or 0
    local resources_ready = minimum_power <= 0 or current_power >= minimum_power
        or has_buff(player, SPELL.DIVINE_PURPOSE) or has_buff(player, SPELL.DIVINE_PURPOSE_ALT)
        or has_buff(player, SPELL.LIGHT_DELIVERANCE)
    local minimum_cc = smart_setting(gui.pvp_burst_cc_min, 1200)
    local controlled = confirmed_cc(target, "is_stunned", "STUN", minimum_cc)
    if controlled then
        pvp_burst_stage[guid] = "commit_controlled"
        return true
    end
    if hp ~= nil and hp <= 60 then
        if not resources_ready then
            pvp_burst_stage[guid] = "prepare_holy_power"
            decision_trace("pvp_burst_prepare", { reason = "low_target_resource_gate",
                target_hp = string.format("%.1f", hp), holy_power = current_power, required = minimum_power })
            return false
        end
        pvp_burst_stage[guid] = "commit_low_target"
        return true
    end
    local trinket_window = smart_setting(gui.pvp_trinket_window, 90)
    if mode == "arena" and trinket_window > 0 and pvp_helper
        and type(pvp_helper.trinket_used_within) == "function" then
        local ok, used = pcall(pvp_helper.trinket_used_within, pvp_helper, target, trinket_window)
        if ok and used == true then
            if not resources_ready then
                pvp_burst_stage[guid] = "prepare_holy_power"
                decision_trace("pvp_burst_prepare", { reason = "post_trinket_resource_gate",
                    holy_power = current_power, required = minimum_power })
                return false
            end
            pvp_burst_stage[guid] = "commit_post_trinket"
            decision_trace("pvp_burst_sync", { reason = "enemy_trinket_on_cooldown",
                target = safe_unit_call(target, "get_name") or "unknown", window = trinket_window })
            return true
        end
    end
    for _, enemy in pairs(object_list()) do
        if enemy ~= target and is_enemy_player(player, enemy) and unit_distance(player, enemy) <= 45
            and safe_unit_call(enemy, "get_group_role") == 1 then
            local healer_guid = unit_guid(enemy)
            if healer_guid and (pvp_healer_lockouts[healer_guid] or -math.huge) > core.time() then
                if not resources_ready then
                    pvp_burst_stage[guid] = "prepare_holy_power"
                    decision_trace("pvp_burst_prepare", { reason = "healer_lockout_resource_gate",
                        holy_power = current_power, required = minimum_power })
                    return false
                end
                pvp_burst_stage[guid] = "commit_healer_lockout"
                decision_trace("pvp_burst_sync", { reason = "confirmed_healer_rebuke_lockout",
                    healer = safe_unit_call(enemy, "get_name") or "unknown",
                    remaining = string.format("%.1f", pvp_healer_lockouts[healer_guid] - core.time()) })
                return true
            end
            for _, flag in ipairs({ "STUN", "SILENCE", "FEAR", "HORROR", "INCAPACITATE", "DISORIENT", "SAP", "CYCLONE", "BANISH" }) do
                if confirmed_cc(enemy, nil, flag, minimum_cc) then
                    if not resources_ready then
                        pvp_burst_stage[guid] = "prepare_holy_power"
                        decision_trace("pvp_burst_prepare", { reason = "healer_control_resource_gate",
                            holy_power = current_power, required = minimum_power })
                        return false
                    end
                    pvp_burst_stage[guid] = "commit_healer_controlled"
                    return true
                end
            end
        end
    end
    if gui.pvp_sync_burst:get_state() == true and pvp_helper
        and type(pvp_helper.has_burst_active) == "function" and (hp or 100) <= 85 then
        for _, ally in ipairs(collect_allies(player, mode)) do
            if ally ~= player and unit_distance(player, ally) <= 45 then
                local ok, active = pcall(pvp_helper.has_burst_active, pvp_helper, ally, 500)
                if ok and active == true then
                    if not resources_ready then
                        pvp_burst_stage[guid] = "prepare_holy_power"
                        decision_trace("pvp_burst_prepare", { reason = "teammate_burst_resource_gate",
                            holy_power = current_power, required = minimum_power })
                        return false
                    end
                    pvp_burst_stage[guid] = "commit_teammate_burst"
                    decision_trace("pvp_burst_sync", { reason = "teammate_offensive_active",
                        ally = safe_unit_call(ally, "get_name") or "unknown" })
                    return true
                end
            end
        end
    end
    pvp_burst_stage[guid] = "build_resources"
    decision_trace("pvp_burst_build", { reason = "waiting_for_control_or_execute", target_hp = hp or "unknown" })
    return false
end

pvp_cleave_safe = function(player, target, radius, from_player)
    local center = from_player and player or target
    -- Execution Sentence includes the target's bounding radius. Apply that
    -- conservative margin to target-centered splash checks when it is known.
    if not from_player then
        local bound = safe_unit_call(target, "get_bounding_radius")
        if type(bound) == "number" and bound >= 0 and bound <= 20 then radius = radius + bound end
    end
    for _, enemy in pairs(object_list()) do
        if is_enemy_player(player, enemy) and breakable_cc(enemy)
            and unit_distance(center, enemy) <= radius then return false end
    end
    return true
end

local was_in_combat, opener_pending = false, false
local burst_hold_started = {}
local pvp_resource_bank_started = {}
runtime_debug.cast_sacrosanct_wake = function(target, player, hero_tree, holy_power, pvp_mode)
    local limit = get_threshold(gui.shield_of_vengeance)
    if hero_tree ~= "Templar" or not has_spell(SPELL.SACROSANCT_CRUSADE)
        or limit <= 0 or (unit_health_percent(player) or 100) > limit
        or holy_power > 2 or has_major_defensive_active(player)
        or (pvp_mode and not pvp_cleave_safe(player, target, 12, true)) then return false end
    local player_key = unit_guid(player) or tostring(player)
    if core.time() - (last_major_defensive_by_target[player_key] or -math.huge)
        < DEFENSIVE_GAP_SECONDS then return false end
    if cast(SPELL.WAKE_OF_ASHES, target, player) then
        last_major_defensive_by_target[player_key] = core.time()
        diagnostic_event("ACTION", "DEFENSIVE", "sacrosanct_wake_barrier", {
            hp = string.format("%.1f", unit_health_percent(player) or 100),
            limit = limit, holy_power = holy_power,
        })
        return true
    end
    return false
end
local function run_damage_priority(target, player, aoe, burst_window, mode)
    local pvp_mode = is_pvp_mode(mode)
    local training_dummy = runtime_debug.is_training_dummy(target)
    local sentence_active = pvp_mode and has_debuff(target, SPELL.EXECUTION_SENTENCE)
    if sentence_active then aoe = false end
    local ttd = observed_ttd(target)
    runtime_debug.ttd = ttd == math.huge and "learning" or string.format("%.1fs", ttd)
    local target_key = unit_guid(target) or tostring(target)
    local minimum_ttd = smart_setting(gui.smart_min_ttd, SMART.burst_min_ttd)
    local maximum_hold = smart_setting(gui.smart_hold_max, SMART.cooldown_hold_max)
    if pvp_mode and gui.pvp_breakable_cc_pause:get_state() == true and breakable_cc(target) then
        decision_trace("stop_damage_breakable_cc", { reason = "selected_target_breakable_control",
            target = safe_unit_call(target, "get_name") or "unknown" })
        return false
    end
    local low_value_window = minimum_ttd > 0 and not pvp_mode and not training_dummy
        and not is_boss_or_elite(target) and ttd < minimum_ttd
    if burst_window and low_value_window then
        burst_hold_started[target_key] = burst_hold_started[target_key] or core.time()
        if core.time() - burst_hold_started[target_key] < maximum_hold then
            burst_window = false
            decision_trace("hold_burst_short_ttd", { reason = "target_dying", ttd = string.format("%.1f", ttd) })
        end
    else
        burst_hold_started[target_key] = nil
    end
    if target_is_protected(target) or safe_unit_call(target, "is_immune") == true then
        decision_trace("stop_damage_protected_target", { reason = "immunity_or_major_reduction" })
        return false
    end
    if opener_pending then
        if pvp_mode then
            runtime_debug.pvp_opener_stage = runtime_debug.pvp_opener_stage or "judgment"
            if runtime_debug.pvp_opener_stage == "judgment" then
                if not has_spell(SPELL.JUDGMENT) then
                    runtime_debug.pvp_opener_stage = "blade"
                elseif cast(SPELL.JUDGMENT, target, player) then
                    runtime_debug.pvp_opener_stage = "blade"
                    return true
                end
            end
            if runtime_debug.pvp_opener_stage == "blade" then
                if not has_spell(SPELL.BLADE_OF_JUSTICE) then
                    opener_pending = false
                    runtime_debug.pvp_opener_stage = "complete"
                elseif cast(SPELL.BLADE_OF_JUSTICE, target, player) then
                    opener_pending = false
                    runtime_debug.pvp_opener_stage = "complete"
                    return true
                end
            end
        elseif not has_spell(SPELL.BLADE_OF_JUSTICE) then
            opener_pending = false
        elseif cast(SPELL.BLADE_OF_JUSTICE, target, player) then
            opener_pending = false
            return true
        end
    end
    local holy_power = player:get_power(HOLY_POWER)
    local hero_tree = get_hero_tree()
    local radiant_glory = has_radiant_glory()
    local divine_purpose = has_any_buff(player, { SPELL.DIVINE_PURPOSE, SPELL.DIVINE_PURPOSE_ALT })

    -- Sacrosanct Crusade turns Wake into a 10% maximum-health barrier. Permit
    -- this Templar-only survival use while offensive burst is held, but keep
    -- the configured defensive threshold and shared anti-overlap gap strict.
    if not burst_window and runtime_debug.cast_sacrosanct_wake(
        target, player, hero_tree, holy_power, pvp_mode) then return true end

    if burst_window then
        local wings_up = wings_active(player)
        local sentence_cd = cooldown_left(SPELL.EXECUTION_SENTENCE)
        local hold_wings = not radiant_glory and has_spell(SPELL.EXECUTION_SENTENCE)
            and maximum_hold > 0 and sentence_cd > 0.15 and sentence_cd <= maximum_hold
        if not radiant_glory and not wings_up
            and not hold_wings
            and cast(SPELL.AVENGING_WRATH, player, player) then return true end
        if hold_wings then decision_trace("hold_wings_for_sentence", {
            reason = "cooldown_alignment", sentence_cd = string.format("%.2f", sentence_cd) }) end
        wings_up = wings_active(player)
        -- Radiant Glory applies Wings from Wake, so Execution Sentence must be
        -- placed before Wake even though the Wings aura is not active yet.
        if has_spell(SPELL.EXECUTION_SENTENCE) and (wings_up or radiant_glory)
            and (not pvp_mode or pvp_cleave_safe(player, target, 10, false))
            and cast(SPELL.EXECUTION_SENTENCE, target, player) then return true end
    end

    -- Both paid and free Hammer share the readiness aura. Arbiter empowers
    -- Hammer damage without unlocking it or changing its Holy Power cost.
    local free_hammer = has_buff(player, SPELL.LIGHT_DELIVERANCE)
    local hammer_light_ready = has_buff(player, SPELL.HAMMER_LIGHT_READY) or free_hammer
    local post_wake_hammer = hammer_light_ready and not free_hammer
    local hold_free_hammer = false
    if free_hammer and not post_wake_hammer then
        local wings_up = wings_active(player)
        local sentence_active = has_debuff(target, SPELL.EXECUTION_SENTENCE)
        local wings_cooldown = cooldown_left(SPELL.AVENGING_WRATH)
        local target_hp = unit_health_percent(target) or 100
        local proc_remaining = runtime_debug.aura_remaining(player, SPELL.LIGHT_DELIVERANCE)
        -- Briefly align a free Light's Deliverance Hammer with an imminent
        -- major window. Post-Wake Hammer remains immediate, and execute targets
        -- are never delayed.
        hold_free_hammer = burst_window and not wings_up and not sentence_active and target_hp > 20
            and wings_cooldown > 0.15 and wings_cooldown <= 3.0
            and (not proc_remaining or proc_remaining > wings_cooldown + 0.75)
    end
    diagnostic_transition("templar_hammer_hold", tostring(hold_free_hammer),
        "DEBUG", "ROTATION", hold_free_hammer and "hold_free_hammer" or "hammer_available", {
            post_wake = post_wake_hammer, free_proc = free_hammer,
            proc_remaining = proc_remaining and string.format("%.2f", proc_remaining) or "unknown",
        })
    if hero_tree == "Templar" and not hold_free_hammer
        and (not pvp_mode or pvp_cleave_safe(player, target, 8, false)) then
        local hammer_of_light = core.spell_book.get_override_spell_id(SPELL.WAKE_OF_ASHES)
        local live_hammer_override = type(hammer_of_light) == "number" and hammer_of_light > 0
            and hammer_of_light ~= SPELL.WAKE_OF_ASHES
        if hammer_light_ready or live_hammer_override then
            if not live_hammer_override then hammer_of_light = SPELL.HAMMER_OF_LIGHT end
            if cast(hammer_of_light, target, player, hammer_light_ready) then return true end
        end
    end

    -- Walk Into Light makes Hammer of Wrath the Herald builder during Wings
    -- and also fires Blade of Justice. In Arena the combined damage and
    -- Judgment maintenance are worth the deliberate Holy Power overcap.
    if pvp_mode and hero_tree == "Herald of the Sun" and wings_active(player)
        and cast(SPELL.HAMMER_OF_WRATH, target, player) then return true end

    if holy_power >= 5 and cast_finisher(target, player, aoe, holy_power, divine_purpose, pvp_mode) then return true end

    -- Wake and Toll belong to the selected burst package in every mode. This
    -- keeps the PvP burst toggle authoritative and prevents cooldown dumping
    -- before a stun/execute window.
    local use_generating_cooldowns = burst_window
    if use_generating_cooldowns then
        local sentence_cooldown = cooldown_left(SPELL.EXECUTION_SENTENCE)
        local wings_up = wings_active(player)
        local hold_wake_for_sentence = not pvp_mode and not radiant_glory and wings_up
            and has_spell(SPELL.EXECUTION_SENTENCE)
            and sentence_cooldown > 0.15 and sentence_cooldown <= 4.5
        if holy_power <= 2 and not hold_wake_for_sentence
            and (not pvp_mode or pvp_cleave_safe(player, target, 12, true))
            and cast(SPELL.WAKE_OF_ASHES, target, player) then return true end
        -- Current priority uses Toll immediately after the capped spender and
        -- Wake. Accept some unavoidable multi-target generation overflow so
        -- the cooldown is not held indefinitely in packs.
        if holy_power <= 2
            and (not pvp_mode or pvp_cleave_safe(player, target, 30, true))
            and cast(SPELL.DIVINE_TOLL, target, player) then return true end
    end

    local target_hp = unit_health_percent(target) or 100
    if pvp_mode and target_hp <= 20 and holy_power <= 4
        and cast(SPELL.HAMMER_OF_WRATH, target, player) then return true end
    local execute_spend = smart_setting(gui.pvp_execute_spend, 35)
    if pvp_mode and execute_spend > 0 and target_hp <= execute_spend and holy_power >= 3
        and cast_finisher(target, player, false, holy_power, divine_purpose, true) then return true end
    if sentence_active and holy_power >= 3
        and cast_finisher(target, player, false, holy_power, divine_purpose, true) then return true end

    local bank_limit = smart_setting(gui.pvp_resource_bank, 3)
    local burst_stage = pvp_burst_stage[target_key]
    local wants_bank = pvp_mode and not burst_window and gui.burst:get_state() == true
        and bank_limit > 0 and holy_power >= 3 and holy_power < 5
        and (burst_stage == "build_resources" or burst_stage == "prepare_holy_power")
    if wants_bank then
        pvp_resource_bank_started[target_key] = pvp_resource_bank_started[target_key] or core.time()
        local banked_for = core.time() - pvp_resource_bank_started[target_key]
        if banked_for < bank_limit then
            local bank_reason = holy_power >= 4 and "waiting_for_kill_window" or "building_safe_holy_power"
            decision_trace("pvp_resource_bank", { reason = bank_reason,
                holy_power = holy_power, elapsed = string.format("%.1f", banked_for), limit = bank_limit })
            if holy_power >= 4 then return false end
        end
    else
        pvp_resource_bank_started[target_key] = nil
    end

    local art_of_war_stacks = get_buff_stacks(player, SPELL.ART_OF_WAR)
    local righteous_cause_stacks = get_buff_stacks(player, SPELL.RIGHTEOUS_CAUSE)
    local hammer_charges, hammer_max_charges = get_spell_charges(SPELL.HAMMER_OF_WRATH)
    if not pvp_mode and aoe and hero_tree == "Herald of the Sun"
        and hammer_max_charges >= 2 and hammer_charges >= hammer_max_charges
        and holy_power <= 4 and cast(SPELL.HAMMER_OF_WRATH, target, player) then return true end
    if (art_of_war_stacks >= 2 or righteous_cause_stacks >= 2) and holy_power <= 4
        and (hero_tree ~= "Herald of the Sun" or not wings_active(player))
        and cast(SPELL.BLADE_OF_JUSTICE, target, player) then return true end
    if hammer_max_charges >= 2 and hammer_charges >= hammer_max_charges
        and holy_power <= 4 and cast(SPELL.HAMMER_OF_WRATH, target, player) then return true end
    if (divine_purpose or holy_power >= 4)
        and cast_finisher(target, player, aoe, holy_power, divine_purpose, pvp_mode) then return true end
    -- Templar's current PvE priority places an ordinary Blade ahead of
    -- Judgment/Hammer. Herald keeps Hammer first because its hero interactions
    -- make Hammer the stronger generator.
    if not pvp_mode and hero_tree == "Templar" and holy_power <= 3
        and cast(SPELL.BLADE_OF_JUSTICE, target, player) then return true end
    -- A failed spender must not turn into a generator at the resource cap.
    if holy_power <= 4 and cast(SPELL.HAMMER_OF_WRATH, target, player) then return true end
    local needs_expurgation = pvp_mode and has_spell(SPELL.EXPURGATION)
        and not has_debuff(target, SPELL.EXPURGATION)
    if needs_expurgation and holy_power <= 3
        and (hero_tree ~= "Herald of the Sun" or not wings_active(player))
        and cast(SPELL.BLADE_OF_JUSTICE, target, player) then return true end
    if pvp_mode and holy_power <= 3 and cast(SPELL.JUDGMENT, target, player) then return true end
    if holy_power <= 3 and (not pvp_mode or hero_tree ~= "Herald of the Sun" or not wings_active(player))
        and cast(SPELL.BLADE_OF_JUSTICE, target, player) then return true end
    if not pvp_mode and holy_power <= 3 and cast(SPELL.JUDGMENT, target, player) then return true end
    -- At three Holy Power, try the primary generators first, then spend before
    -- falling through to Templar/Crusader filler strikes.
    if holy_power >= 3
        and cast_finisher(target, player, aoe, holy_power, divine_purpose, pvp_mode) then return true end
    if holy_power <= 3 then
        -- Templar Strike is an override of Crusader Strike. Resolve from the
        -- base spell so an untalented character never receives a direct request
        -- for the unlearned talent spell or its second-step Slash replacement.
        local filler = core.spell_book.get_override_spell_id(SPELL.CRUSADER_STRIKE)
        if filler and filler > 0 and cast(filler, target, player) then return true end
    end
    if holy_power <= 3 and cast(SPELL.CRUSADER_STRIKE, target, player) then return true end
    return false
end

runtime_debug.run_mythic_plus_damage = function(target, player, profile)
    -- Count only the selected target and enemies positively participating in
    -- this pull. Nearby neutral packs must not force an accidental AoE spender.
    local enemies = nearby_enemy_count(player, target, nil, true)
    return run_damage_priority(target, player, enemies >= profile.aoe_min,
        gui.burst:get_state() == true and profile.burst == true, "mythic_plus")
end

runtime_debug.run_delve_damage = function(target, player, profile)
    local enemies = nearby_enemy_count(player, target)
    local elite = safe_unit_call(target, "is_boss") == true
        or (tonumber(safe_unit_call(target, "get_classification")) or 0) >= 1
    local burn = profile.burst == true and gui.burst:get_state() == true
        and (elite or enemies >= 3)
    return run_damage_priority(target, player, enemies >= profile.aoe_min, burn, "delve")
end

runtime_debug.run_arena_damage = function(target, player, profile)
    return run_damage_priority(target, player, false,
        not runtime_debug.healer_emergency and profile.burst == true and gui.burst:get_state() == true
            and burst_target_is_ready(target, "arena", player), "arena")
end

runtime_debug.run_battleground_damage = function(target, player, profile)
    local hold_hp = smart_setting(gui.pvp_outnumbered_hold, 70)
    local survival_hold = hold_hp > 0 and runtime_debug.outnumbered and (unit_health_percent(player) or 100) <= hold_hp
    local safe_aoe = gui.pvp_safe_cleave:get_state() == true and nearby_enemy_count(player, target) >= 3
        and pvp_cleave_safe(player, target, 8, false)
    if survival_hold then safe_aoe = false end
    local funnel_hp = smart_setting(gui.pvp_kill_funnel, 45)
    if funnel_hp > 0 and (unit_health_percent(target) or 100) <= funnel_hp then safe_aoe = false end
    return run_damage_priority(target, player, safe_aoe,
        not survival_hold and not runtime_debug.healer_emergency and profile.burst == true and gui.burst:get_state() == true
            and burst_target_is_ready(target, "battleground", player), "battleground")
end

runtime_debug.run_world_pvp_damage = function(target, player, profile)
    local hold_hp = smart_setting(gui.pvp_outnumbered_hold, 70)
    local survival_hold = hold_hp > 0 and runtime_debug.outnumbered and (unit_health_percent(player) or 100) <= hold_hp
    local safe_aoe = gui.pvp_safe_cleave:get_state() == true and nearby_enemy_count(player, target) >= 3
        and pvp_cleave_safe(player, target, 8, false)
    if survival_hold then safe_aoe = false end
    local funnel_hp = smart_setting(gui.pvp_kill_funnel, 45)
    if funnel_hp > 0 and (unit_health_percent(target) or 100) <= funnel_hp then safe_aoe = false end
    return run_damage_priority(target, player, safe_aoe,
        not survival_hold and not runtime_debug.healer_emergency and profile.burst == true and gui.burst:get_state() == true
            and burst_target_is_ready(target, "world_pvp", player), "world_pvp")
end

runtime_debug.damage_rotations = {
    mythic_plus = runtime_debug.run_mythic_plus_damage,
    delve = runtime_debug.run_delve_damage,
    arena = runtime_debug.run_arena_damage,
    battleground = runtime_debug.run_battleground_damage,
    world_pvp = runtime_debug.run_world_pvp_damage,
    world_pve = function(target, player, profile)
        local enemies = nearby_enemy_count(player, target)
        local training_dummy = runtime_debug.is_training_dummy(target)
        local burn = profile.burst == true and gui.burst:get_state() == true
            and ((training_dummy and gui.training_dummy_burst:get_state() == true)
                or is_boss_or_elite(target) or enemies >= 3)
        return run_damage_priority(target, player,
            not training_dummy and enemies >= profile.aoe_min, burn, "world_pve")
    end,
}

runtime_debug.cast_remaining = function(unit)
    local ending = safe_unit_call(unit, "get_active_spell_cast_end_time")
        or safe_unit_call(unit, "get_active_channel_cast_end_time")
    ending = tonumber(ending)
    if not ending or ending <= 0 then return nil end
    if ending > 100000 then ending = ending / 1000 end
    return math.max(0, ending - core.time())
end

local function find_priority_mplus_interrupt(player, selected)
    local best, best_score = nil, -math.huge
    local function consider(unit)
        if not runtime_debug.is_engaged_pve_enemy(player, unit, selected)
            or not is_valid_unit(unit) or safe_unit_call(player, "can_attack", unit) ~= true
            or not runtime_debug.spell_target_reachable(SPELL.REBUKE, unit, player)
            or not runtime_debug.is_casting_or_channeling(unit)
            or not runtime_debug.is_interruptible_cast(unit)
            or not is_priority_mplus_interrupt(unit) then return end
        local spell_name = active_spell_name(unit)
        local progress = runtime_debug.active_cast_progress(unit)
        local threshold = MPLUS_IMMEDIATE_INTERRUPT_ABILITIES[spell_name]
            and SMART.danger_interrupt_percent or smart_setting(gui.interrupt_late, SMART.interrupt_late_percent)
        local remaining = runtime_debug.cast_remaining(unit)
        if progress < threshold and (not remaining or remaining > 0.18) then
            decision_trace("hold_interrupt", { reason = "late_interrupt_timing", cast = spell_name,
                progress = string.format("%.0f", progress), threshold = threshold })
            return
        end
        local distance = unit_distance(player, unit)
        local urgent = MPLUS_IMMEDIATE_INTERRUPT_ABILITIES[spell_name] == true
        local score = (urgent and 1000 or 0) + progress * 2 - distance
            + (remaining and remaining <= 0.18 and 500 or 0)
        if unit == selected then score = score + 5 end
        if score > best_score then best, best_score = unit, score end
    end
    consider(selected)
    for _, unit in pairs(object_list()) do consider(unit) end
    return best
end

-- General PvE kick fallback. Mythic+ dangerous-name rules run first; this
-- catches other late interruptible casts and gives Delves/open world their
-- own selected-target interrupt behavior without spending Hammer of Justice.
runtime_debug.find_pve_interrupt = function(player, selected)
    local best, best_progress = nil, -math.huge
    local seen = {}
    local function consider(unit)
        local guid = unit_guid(unit) or tostring(unit)
        if seen[guid] or not runtime_debug.is_engaged_pve_enemy(player, unit, selected)
            or not is_valid_unit(unit)
            or safe_unit_call(player, "can_attack", unit) ~= true
            or not runtime_debug.spell_target_reachable(SPELL.REBUKE, unit, player)
            or not runtime_debug.is_casting_or_channeling(unit)
            or not runtime_debug.is_interruptible_cast(unit) then return end
        seen[guid] = true
        local progress = runtime_debug.active_cast_progress(unit)
        local remaining = runtime_debug.cast_remaining(unit)
        if progress < smart_setting(gui.interrupt_late, SMART.interrupt_late_percent)
            and (not remaining or remaining > 0.18) then return end
        local score = progress + (unit == selected and 8 or 0) - unit_distance(player, unit) * 0.1
            + (remaining and remaining <= 0.18 and 500 or 0)
        if score > best_progress then best, best_progress = unit, score end
    end
    consider(selected)
    for _, unit in pairs(object_list()) do consider(unit) end
    return best, best_progress
end

local function reset_combat_adaptive_state()
    if not was_in_combat then return end
    local resolved_casts = combat_stats.confirmed + combat_stats.failed + combat_stats.interrupted
    local failure_rate = resolved_casts > 0 and combat_stats.failed / resolved_casts or 0
    diagnostic_event("INFO", "ROTATION", "combat_summary", {
        duration = string.format("%.1f", math.max(0, core.time() - combat_stats.started)),
        actions = combat_stats.actions, damage = combat_stats.damage,
        defensive = combat_stats.defensive, support = combat_stats.support,
        interrupts = combat_stats.interrupt, swaps = combat_stats.swaps,
        burst_actions = combat_stats.burst, crowd_control = combat_stats.cc, saves = combat_stats.saves,
        confirmed = combat_stats.confirmed, failed = combat_stats.failed,
        interrupted_casts = combat_stats.interrupted,
        cast_failure_rate = string.format("%.0f%%", failure_rate * 100),
    })
    if resolved_casts >= 3 and failure_rate >= 0.25 then
        diagnostic_event("WARN", "SAFETY", "high_cast_failure_rate", {
            attempts = resolved_casts, confirmed = combat_stats.confirmed,
            failed = combat_stats.failed, interrupted = combat_stats.interrupted,
            failure_rate = string.format("%.0f%%", failure_rate * 100),
            recommendation = "inspect CAST backoff and target/range state",
        })
    end
    combat_stats = { started = 0, actions = 0, damage = 0, defensive = 0,
        support = 0, interrupt = 0, swaps = 0, burst = 0, cc = 0, saves = 0,
        confirmed = 0, failed = 0, interrupted = 0 }
    cleanup_adaptive_history(true)
    burst_hold_started = {}
    pvp_burst_stage = {}
    pvp_resource_bank_started = {}
    pending_target_swap = nil
    cast_failure_state = {}
    pvp_stun_requests = {}
    pvp_disorient_requests = {}
    pvp_healer_lockouts = {}
    runtime_debug.enemy_target_memory, runtime_debug.ally_swap_windows = {}, {}
    runtime_debug.pvp_opener_stage = nil
    runtime_debug.manual_target_lock_until = -math.huge
    runtime_debug.auto_target_guid = nil
    runtime_debug.last_target_guid = nil
    runtime_debug.outnumbered = false
    runtime_debug.ttd, runtime_debug.danger, runtime_debug.decision = "--", "--", "Waiting"
    decision_trace("combat_state_reset", { reason = "left_combat" })
end

runtime_debug.run_rotation = function()
    if RetGui and type(RetGui.poll_hotkey) == "function" then pcall(RetGui.poll_hotkey) end
    if type(gui.poll_customer_hotkeys) == "function" then pcall(gui.poll_customer_hotkeys) end
    if not gui.enabled:get_state() then return end
    local player = core.object_manager.get_local_player()
    if not player or not player.is_valid or not player:is_valid() then return end
    if player:get_class() ~= PALADIN_CLASS_ID
        or not plugin.is_ret_spec(core.spell_book.get_specialization_id()) then return end
    local mode, detected = effective_mode()
    local profile = profile_settings[mode]
    runtime_debug.player = tostring(safe_unit_call(player, "get_name") or "Player")
    runtime_debug.player_hp = string.format("%.1f%%", unit_health_percent(player) or 0)
    runtime_debug.holy_power = tostring(safe_unit_call(player, "get_power", HOLY_POWER) or 0)
    runtime_debug.combat = player:is_in_combat() == true
    runtime_debug.detected_mode = detected
    runtime_debug.active_mode = mode
    runtime_debug.hero = get_hero_tree()
    diagnostic_transition("active_mode", mode .. ":" .. detected .. ":" .. get_hero_tree(),
        "INFO", "MODE", "profile_selected", {
            active = mode, detected = detected, override = mode_override or "none",
            hero = get_hero_tree(), profile = profile and profile.title or "missing",
        })
    if update_auto_aura(player) then return end
    if safe_unit_call(player, "is_dead") == true
        or safe_unit_call(player, "is_ghost") == true
        or safe_unit_call(player, "is_in_vehicle") == true then return end
    if player:is_in_combat() and safe_unit_call(player, "is_mounted") == true then return end
    if runtime_debug.run_world_pve_flash(player) then return end
    if (gui.fishing:get_state() or gui.skinning:get_state() or gui.looting:get_state())
        and not player:is_in_combat() then
        reset_combat_adaptive_state()
        was_in_combat, opener_pending = false, false
        return
    end
    local selected_before_combat = safe_unit_call(player, "get_target")
    local selected_training_dummy = runtime_debug.is_training_dummy(selected_before_combat)
        and safe_unit_call(player, "can_attack", selected_before_combat) == true
    if not player:is_in_combat() and not selected_training_dummy then
        reset_combat_adaptive_state()
        was_in_combat, opener_pending = false, false
        return
    end
    if not was_in_combat then
        was_in_combat, opener_pending = true, true
        runtime_debug.pvp_opener_stage = nil
        combat_stats = { started = core.time(), actions = 0, damage = 0, defensive = 0,
            support = 0, interrupt = 0, swaps = 0, burst = 0, cc = 0, saves = 0,
            confirmed = 0, failed = 0, interrupted = 0 }
    end

    local allies = collect_allies(player, mode)
    local pressure = build_pressure_map(player, allies, mode)
    if core.time() < manual_pause_until then
        local emergency = (unit_health_percent(player) or 100) <= 20
        if not emergency then
            for _, ally in ipairs(allies) do
                if (unit_health_percent(ally) or 100) <= 20 then emergency = true; break end
            end
        end
        if not emergency then
            runtime_debug.decision = "Yielding to manual cast"
            return
        end
    end
    local visible_enemies = 0
    if is_pvp_mode(mode) then
        for _, enemy in pairs(object_list()) do
            if is_enemy_player(player, enemy) and unit_distance(player, enemy) <= 45 then
                visible_enemies = visible_enemies + 1
            end
        end
    end
    runtime_debug.outnumbered = is_pvp_mode(mode) and visible_enemies > math.max(1, #allies)
    if is_pvp_mode(mode) then
        runtime_debug.track_manual_target(player)
        diagnostic_transition("manual_target_grace", core.time() < runtime_debug.manual_target_lock_until,
            "INFO", "TARGET", "manual_target_grace_state", {
                remaining = string.format("%.1f", math.max(0, runtime_debug.manual_target_lock_until - core.time())),
            })
    end
    local healer_state, healer_hp = "none", 100
    for _, ally in ipairs(allies) do
        if ally ~= player and safe_unit_call(ally, "get_group_role") == 1 then
            healer_hp = unit_health_percent(ally) or 100
            local controlled = confirmed_cc(ally, "is_stunned", "STUN", 250)
                or confirmed_cc(ally, "is_silenced", "SILENCE", 250)
                or confirmed_cc(ally, "is_feared", "FEAR", 250)
            local far = unit_distance(player, ally) > 40
            local dead = safe_unit_call(ally, "is_dead") == true
            local los = safe_unit_call(player, "has_line_of_sight", ally)
            if los == nil then los = safe_unit_call(ally, "has_line_of_sight", player) end
            local blocked = los == false
            healer_state = dead and "dead" or (controlled and "controlled"
                or (far and "out_of_range" or (blocked and "line_of_sight_blocked" or "available")))
            if dead or controlled or far or blocked then
                local guid = unit_guid(player)
                if guid and pressure[guid] then pressure[guid].burst = true end
            end
            break
        end
    end
    runtime_debug.dampening = runtime_debug.read_dampening(player)
    runtime_debug.healer_state = healer_state
    local healer_limit = smart_setting(gui.pvp_healer_emergency, 50)
    runtime_debug.healer_emergency = is_pvp_mode(mode) and (healer_state == "controlled"
        or healer_state == "dead" or (healer_limit > 0 and healer_hp <= healer_limit))
    diagnostic_transition("healer_state", healer_state, "INFO", "SUPPORT", "healer_state_changed", {
        state = healer_state,
    })
    runtime_debug.pvp_state = is_pvp_mode(mode)
        and ("enemies=" .. tostring(visible_enemies) .. " allies=" .. tostring(#allies)
            .. " healer=" .. healer_state .. " damp=" .. tostring(runtime_debug.dampening)
            .. (runtime_debug.healer_emergency and " PEEL" or "")
            .. (runtime_debug.outnumbered and " OUTNUMBERED" or "")) or "PvE"
    health_trend(player)
    for _, ally in ipairs(allies) do health_trend(ally) end
    -- PvP rescue utility gets the first global so an ordinary personal wall
    -- cannot delay LoH, BoP, Sacrifice, Sanctuary, Freedom, or an urgent cleanse.
    if is_pvp_mode(mode) then
        local self_hp = unit_health_percent(player) or 100
        local prediction_window = 0
        if gui.pvp_predictive_defense:get_state() == true then
            prediction_window = smart_setting(gui.pvp_prediction_window, 2)
        end
        local _, self_loss, self_incoming = incoming_danger(player, pressure, prediction_window)
        local predicted_self = runtime_debug.predicted_health_percent(
            player, self_hp, prediction_window, self_loss, self_incoming)
        local self_critical = predicted_self <= math.max(get_threshold(gui.lay_on_hands),
            get_threshold(gui.divine_shield))
        diagnostic_transition("pvp_defensive_triage", self_critical and "self_first" or "team_first",
            "INFO", "DEFENSIVE", "pvp_defensive_triage", {
                self_hp = string.format("%.1f", self_hp),
                predicted_self = string.format("%.1f", predicted_self),
            })
        if self_critical and run_personal_defensives(player, profile, pressure) then return end
        if run_team_support(player, mode, profile, allies, pressure) then return end
        if not self_critical and run_personal_defensives(player, profile, pressure) then return end
    else
        if run_personal_defensives(player, profile, pressure) then return end
        if run_team_support(player, mode, profile, allies, pressure) then return end
    end
    if profile.swap_target then
        if is_pvp_mode(mode) then maybe_swap_pvp_target(player, mode, profile, pressure)
        else maybe_swap_pve_target(player, mode, profile) end
    end

    local target = safe_unit_call(player, "get_target")

    if mode == "mythic_plus" then
        local interrupt_target = find_priority_mplus_interrupt(player, target)
        if interrupt_target then
            if gui.interrupts:get_state()
                and cast(SPELL.REBUKE, interrupt_target, player) then return end
            if gui.stun_backup:get_state() and not has_cc_immunity(interrupt_target)
                and stun_dr_ready(interrupt_target)
                and cast(SPELL.HAMMER_OF_JUSTICE, interrupt_target, player) then return end
            local cast_id = safe_unit_call(interrupt_target, "get_active_spell_id")
                or safe_unit_call(interrupt_target, "get_active_channel_spell_id") or 0
            local cast_name = tostring(cast_id)
            if core.spell_book.get_spell_name then
                local name_ok, name = pcall(core.spell_book.get_spell_name, cast_id)
                if name_ok and type(name) == "string" then cast_name = name end
            end
            diagnostic_transition("missed_interrupt_" .. tostring(cast_id), "active", "WARN", "INTERRUPT",
                "priority_cast_not_stopped", {
                    cast = cast_name, cast_id = cast_id,
                    target = safe_unit_call(interrupt_target, "get_name") or "unknown",
                    selected_target = interrupt_target == target,
                    rebuke_enabled = gui.interrupts:get_state(), stun_backup = gui.stun_backup:get_state(),
                })
        end
    end

    if not is_pvp_mode(mode) and gui.interrupts:get_state() then
        local interrupt_target, interrupt_score = runtime_debug.find_pve_interrupt(player, target)
        if interrupt_target and cast(SPELL.REBUKE, interrupt_target, player) then
            diagnostic_event("ACTION", "INTERRUPT", "pve_interrupt_selected", {
                target = safe_unit_call(interrupt_target, "get_name") or "unknown",
                off_target = interrupt_target ~= target, score = string.format("%.1f", interrupt_score), mode = mode,
            })
            return
        end
    end

    runtime_debug.training_dummy_active = false
    if not is_valid_unit(target) or safe_unit_call(player, "can_attack", target) ~= true then
        runtime_debug.target, runtime_debug.target_hp, runtime_debug.target_distance = "None", "--", "--"
        return
    end
    runtime_debug.target = tostring(safe_unit_call(target, "get_name") or "Unknown")
    runtime_debug.training_dummy_active = runtime_debug.is_training_dummy(target)
    if runtime_debug.training_dummy_active then
        runtime_debug.target = runtime_debug.target .. " [DUMMY TEST]"
        runtime_debug.pvp_state = "Training dummy: single target | burst="
            .. tostring(gui.training_dummy_burst:get_state() == true)
        diagnostic_transition("training_dummy_test", "active", "INFO", "ROTATION",
            "training_dummy_detected", { target = runtime_debug.target,
                burst = gui.training_dummy_burst:get_state() == true })
    end
    runtime_debug.target_hp = string.format("%.1f%%", unit_health_percent(target) or 0)
    runtime_debug.target_distance = string.format("%.1f yd", unit_distance(player, target))
    if is_pvp_mode(mode) then
        local stage = pvp_burst_stage[unit_guid(target) or tostring(target)] or "evaluate"
        runtime_debug.pvp_state = runtime_debug.pvp_state .. " stage=" .. stage
            .. " stunDR=" .. (stun_dr_ready(target) and "ready" or "hold")
            .. " disorientDR=" .. (disorient_dr_ready(target) and "ready" or "hold")
    end
    if is_pvp_mode(mode) and not is_enemy_player(player, target) then return end
    if is_pvp_mode(mode) and breakable_cc(target) then return end
    if is_pvp_mode(mode) and run_pvp_utility(player, target, mode, profile, pressure, allies) then return end

    if not profile.rotation then return end
    local rotation = runtime_debug.damage_rotations[mode]
    if rotation then rotation(target, player, profile) end
end

runtime_debug.last_rotation_error, runtime_debug.last_rotation_error_report = nil, -math.huge
runtime_debug.rotation_error_streak, runtime_debug.rotation_circuit_until = 0, -math.huge
runtime_debug.next_rotation_tick = -math.huge
core.register_on_update_callback(function()
    local now = core.time()
    if now < runtime_debug.rotation_circuit_until then return end
    -- Framework update callbacks may run once per rendered frame. A bounded
    -- 30 Hz combat loop prevents high-refresh clients from multiplying object,
    -- aura and prediction work without adding meaningful cast responsiveness.
    if now < runtime_debug.next_rotation_tick then return end
    runtime_debug.next_rotation_tick = now + 0.033
    local tick_started = now
    local ok, err = pcall(runtime_debug.run_rotation)
    local tick_finished = core.time()
    local tick_ms = math.max(0, (tick_finished - tick_started) * 1000)
    runtime_debug.rotation_tick_ms = tick_ms
    local budget_ms = tonumber(performance_profile.scan_budget_ms) or 3
    local load_state = tick_ms > budget_ms * 2 and "heavy"
        or (tick_ms > budget_ms and "elevated" or "normal")
    if load_state ~= "normal" then
        -- One slower interval gives the client room to render and lets Lua's
        -- incremental collector progress instead of piling work onto the next frame.
        runtime_debug.next_rotation_tick = math.max(runtime_debug.next_rotation_tick,
            tick_finished + (load_state == "heavy" and 0.075 or 0.050))
    end
    diagnostic_transition("rotation_load", load_state, "INFO", "ROTATION",
        "performance_budget_state", {
            elapsed_ms = string.format("%.2f", tick_ms), budget_ms = budget_ms,
            next_interval_ms = load_state == "heavy" and 75 or (load_state == "elevated" and 50 or 33),
        })
    if ok then runtime_debug.rotation_error_streak = 0; return end
    runtime_debug.rotation_error_streak = runtime_debug.rotation_error_streak + 1
    if runtime_debug.rotation_error_streak >= 3 then
        runtime_debug.rotation_circuit_until = now + 5
        runtime_debug.rotation_error_streak = 0
        diagnostic_event("WARN", "SAFETY", "rotation_circuit_open", {
            reason = "three_consecutive_errors", resume_in = 5,
        })
    end
    latest_runtime_error = tostring(err)
    latest_runtime_error_time = string.format("%.2f", now)
    local error_key = latest_runtime_error .. ":" .. tostring(runtime_debug.active_mode)
    if error_key == runtime_debug.last_rotation_error
        and now - runtime_debug.last_rotation_error_report < 10 then return end
    runtime_debug.last_rotation_error, runtime_debug.last_rotation_error_report = error_key, now
    diagnostic_event("ERROR", "ERROR", "rotation_runtime_error", {
        message = latest_runtime_error, mode = runtime_debug.active_mode,
        action = last_action, target = runtime_debug.target,
    })
    flush_diagnostic_log(true)
    if type(core.log_warning) == "function" then
        pcall(core.log_warning, "[Ret Paladin Debugger] " .. latest_runtime_error)
    end
end)

if type(core.register_on_game_event_callback) == "function" then
    core.register_on_game_event_callback(function(event, args)
        if event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
            diagnostic_event("INFO", "SESSION", "session_flush", { event = event })
            flush_diagnostic_log(true)
            return
        end
        if event == "UI_ERROR_MESSAGE" and type(args) == "table" then
            local message = tostring(args[2] or args[1] or "")
            local lowered = string.lower(message)
            if lowered:find("not learned", 1, true) or lowered:find("haven't learned", 1, true)
                or lowered:find("have not learned", 1, true) then
                local newest_id, newest_request, newest_time = nil, nil, -math.huge
                for pending_id, pending_request in pairs(LOG.pending) do
                    if pending_request.time > newest_time then
                        newest_id, newest_request, newest_time = pending_id, pending_request, pending_request.time
                    end
                end
                if newest_id and core.time() - newest_time <= 1 then
                    runtime_debug.unlearned_spell_until[newest_id] = core.time() + 300
                    LOG.pending[newest_id] = nil
                    if runtime_debug.global_cast_pending == newest_id then
                        runtime_debug.global_cast_pending = nil
                    end
                    diagnostic_event("ERROR", "CAST", "unlearned_spell_blocked", {
                        spell_id = newest_id, spell = newest_request.spell,
                        message = message, blocked_seconds = 300,
                    })
                    flush_diagnostic_log(true)
                end
            end
            return
        end
        if event ~= "UNIT_SPELLCAST_SUCCEEDED" and event ~= "UNIT_SPELLCAST_FAILED"
            and event ~= "UNIT_SPELLCAST_INTERRUPTED" then return end
        if type(args) ~= "table" or args[1] ~= "player" then return end
        local spell_id = args[3] or args[4]
        local request = spell_id and LOG.pending[spell_id] or nil
        local owned = request and core.time() - request.time <= 4
        if owned then
            LOG.pending[spell_id] = nil
            if runtime_debug.global_cast_pending == spell_id then
                runtime_debug.global_cast_pending = nil
            end
        end
        -- The manual-cast callback already records the yield. Do not mix other
        -- addons, item procs, or player casts into plugin reliability metrics.
        if not owned then return end
        if owned then
            local observed = math.max(0, core.time() - request.time)
            measured_cast_latency = measured_cast_latency * 0.8 + observed * 0.2
            local failure_key = cast_failure_key(spell_id, request.target_guid)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                cast_failure_state[failure_key] = nil
            else
                record_cast_failure(spell_id, request.target_guid, core.time(), event)
            end
        end
        if owned and event == "UNIT_SPELLCAST_SUCCEEDED" and spell_id == SPELL.REBUKE
            and request.target_role == 1 and request.target_guid then
            local duration = smart_setting(gui.pvp_healer_lockout_window, 3)
            pvp_healer_lockouts[tostring(request.target_guid)] = core.time() + duration
            diagnostic_event("ACTION", "INTERRUPT", "confirmed_healer_lockout", {
                target = request.target, target_guid = request.target_guid, duration = duration,
            })
        end
        if owned and event ~= "UNIT_SPELLCAST_SUCCEEDED" then
            -- Release only this failed reservation. A newer accepted defensive
            -- for the same unit must keep its own overlap protection.
            if is_major_defensive_spell(spell_id) and request.target_guid then
                local target_key = tostring(request.target_guid)
                local request_key = target_key .. ":" .. tostring(spell_id)
                if last_defensive_requests[request_key] == request.time then
                    last_defensive_requests[request_key] = nil
                end
                if last_major_defensive_by_target[target_key] == request.time then
                    last_major_defensive_by_target[target_key] = nil
                end
            end
            if spell_id == SPELL.HAMMER_OF_JUSTICE and request.target_guid then
                pvp_stun_requests[request.target_guid] = nil
            elseif spell_id == SPELL.BLINDING_LIGHT then
                pvp_disorient_requests = {}
            end
        end
        if owned and was_in_combat then
            if event == "UNIT_SPELLCAST_SUCCEEDED" then combat_stats.confirmed = combat_stats.confirmed + 1
            elseif event == "UNIT_SPELLCAST_FAILED" then combat_stats.failed = combat_stats.failed + 1
            else combat_stats.interrupted = combat_stats.interrupted + 1 end
        end
        diagnostic_event(event == "UNIT_SPELLCAST_SUCCEEDED" and "ACTION" or "WARN", "CAST",
            "cast_result", {
                result = event, spell_id = spell_id or "unknown",
                spell = request and request.spell or "unknown",
                target = request and request.target or "unknown",
                origin = "plugin_request",
                latency = string.format("%.2f", core.time() - request.time),
                mode = current_mode,
            })
    end)
end

if type(core.register_on_legit_spell_cast_callback) == "function" then
    core.register_on_legit_spell_cast_callback(function(data)
        local yield_ms = smart_setting(gui.manual_yield_ms, 750)
        if yield_ms <= 0 then return end
        local spell_id = type(data) == "table" and tonumber(data.spell_id) or tonumber(data)
        manual_pause_until = core.time() + yield_ms / 1000
        diagnostic_event("INFO", "MANUAL", "manual_cast_yield", {
            spell_id = spell_id or "unknown", yield_ms = yield_ms,
        })
    end)
end

end -- register_runtime

local function main()
    if plugin.runtime_initialized or plugin.runtime_initialization_attempted then return end
    write_status("load_status.md", "main.lua entered")
    -- The discovery header is intentionally lightweight and may be loaded before
    -- the player object is ready. Re-check here before registering the GUI or any
    -- callbacks so this plugin cannot appear for another class or specialization.
    local player = core.object_manager.get_local_player()
    local class_ok, class_id = pcall(function()
        return player and player:is_valid() and player:get_class() or nil
    end)
    local spec_ok, spec_id = pcall(function()
        return player and player:is_valid() and player:get_specialization_id() or nil
    end)
    local identity_pending = class_ok and spec_ok
        and (class_id == nil or tonumber(class_id) == nil or tonumber(class_id) <= 0
            or class_id == PALADIN_CLASS_ID
                and (spec_id == nil or tonumber(spec_id) == nil or tonumber(spec_id) <= 0))
    if identity_pending then
        write_status("load_status.md", "Waiting for player class and specialization")
        if not plugin.startup_wait_registered then
            plugin.startup_wait_registered = true
            plugin.next_startup_check = 0
            core.register_on_update_callback(function()
                if plugin.runtime_initialized or plugin.runtime_initialization_attempted
                    or core.time() < plugin.next_startup_check then return end
                plugin.next_startup_check = core.time() + 1
                main()
            end)
        end
        return
    end
    if not class_ok or not spec_ok
        or class_id ~= PALADIN_CLASS_ID or not plugin.is_ret_spec(spec_id) then
        plugin.load = false
        write_status("load_status.md", "Plugin skipped before runtime registration: class="
            .. tostring(class_id) .. ", specialization=" .. tostring(spec_id))
        return
    end
    plugin.load = true
    plugin.runtime_initialization_attempted = true
    local ok, err = pcall(register_runtime)
    if not ok then
        write_status("load_status.md", "Rotation initialization failed: " .. tostring(err))
        error(err)
    end
    plugin.runtime_initialized = true
    write_status("load_status.md", "Rotation module loaded")
end

return {
    header = plugin,
    main = main,
}
