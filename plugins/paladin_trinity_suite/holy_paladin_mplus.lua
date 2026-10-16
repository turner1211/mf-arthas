-- Holy Paladin Mythic+ rotation for Project Sylvanas / IZI.
-- One pending spell request at a time, confirmed through cast outcome events.
-- Aura decisions follow
-- the local 12.1 secret-aura compatibility template: only positive aura data
-- is treated as confirmation; unknown/hidden data is never interpreted as absent.
local Aura = require("holy_paladin_aura_safe")
local Telemetry = require("holy_paladin_telemetry")
local PaladinGui = require("holy_paladin_gui")
local ArenaLines = require("holy_paladin_arena_lines")
local DangerZones = require("holy_paladin_danger_zones")
local BossGuide = require("holy_paladin_s2_boss_guide")
local enums = require("common/enums")
local fish_helper = require("common/utility/fish_helper")
local gold = require("common/color").new(219, 181, 93, 255)
local ok_pvp, pvp_helper = pcall(require, "common/utility/pvp_helper")
if not ok_pvp then pvp_helper = nil end

local SPELL = {
    HOLY_SHOCK = 20473,
    WORD_OF_GLORY = 85673,
    DIVINE_PURPOSE = 223819,
    SHIELD_OF_THE_RIGHTEOUS = 53600,
    FLASH_OF_LIGHT = 19750,
    HOLY_LIGHT = 82326,
    LIGHT_OF_DAWN = 85222,
    ETERNAL_FLAME = 156322,
    DIVINE_TOLL = 375576,
    HOLY_ARMAMENTS = 1289728,
    HOLY_BULWARK = 432459,
    SACRED_WEAPON = 432472,
    HOLY_PRISM = 114165,
    BEACON_OF_VIRTUE = 200025,
    BEACON_OF_LIGHT = 53563,
    BEACON_OF_FAITH = 156910,
    BEACON_OF_THE_SAVIOR = 1244893,
    DAWNLIGHT = 431377,
    DEVOTION_AURA = 465,
    CONCENTRATION_AURA = 317920,
    CRUSADER_AURA = 32223,
    AVENGING_WRATH = 31884,
    AVENGING_CRUSADER = 216331,
    AURA_MASTERY = 31821,
    BLESSING_OF_SACRIFICE = 6940,
    BLESSING_OF_PROTECTION = 1022,
    BLESSING_OF_SPELLWARDING = 204018,
    DIVINE_PROTECTION = 498,
    FORBEARANCE = 25771,
    LAY_ON_HANDS = 633,
    DIVINE_SHIELD = 642,
    REBUKE = 96231,
    HAMMER_OF_JUSTICE = 853,
    BLINDING_LIGHT = 115750,
    CLEANSE = 4987,
    IMPROVED_CLEANSE = 393024,
    MOMENT_OF_COMPASSION = 387786,
    JUDGMENT = 20271,
    HAMMER_OF_WRATH = 24275,
    CRUSADER_STRIKE = 35395,
    INFUSION_OF_LIGHT = 54149,
    HAND_OF_DIVINITY = 414273,
    DIVINE_STEED = 221885,
    DIVINE_STEED_LEGACY = 190784,
    BLESSING_OF_FREEDOM = 1044,
    SEARING_GLARE = 410126,
    DIVINE_PLEA = 415244,
    SPREADING_THE_WORD = 199456,
    CLEANSE_THE_WEAK = 199330,
    BARRIER_OF_FAITH = 148039,
    BARRIER_OF_FAITH_ABSORB = 388536,
    TURN_EVIL = 10326,
    ULTIMATE_SACRIFICE = 199452,
    DENOUNCE = 2812,
    DARKEST_BEFORE_DAWN = 210378,
}
-- These buttons do not consume the spell GCD on the current ruleset. The
-- ordinary rotation still observes the host GCD spell (61304) before every
-- GCD action; Lay on Hands, Divine Protection, Sacrifice and Wings can be queued
-- independently when cast events have cleared the single-request latch.
local OFF_GCD = {
    [SPELL.AVENGING_WRATH] = true,
    [SPELL.AVENGING_CRUSADER] = true,
    [SPELL.BLESSING_OF_SACRIFICE] = true,
    [SPELL.DIVINE_PROTECTION] = true,
    [SPELL.LAY_ON_HANDS] = true,
}
Aura.track(SPELL.AVENGING_WRATH, { cast_floor = 20 })
Aura.track(SPELL.AVENGING_CRUSADER, { cast_floor = 15 })
local HOLY_POWER = enums.power_type and enums.power_type.HOLYPOWER or 9
local MANA = enums.power_type and enums.power_type.MANA or 0
local PALADIN = enums.class_id and enums.class_id.PALADIN or 2
local HOLY_SPEC = enums.class_spec_id and enums.class_spec_id.spec_enum
    and enums.class_spec_id.spec_enum.HOLY_PALADIN

local gui = {
    root = core.menu.tree_node(),
    header = core.menu.header(),
    enabled = core.menu.checkbox(true, "hpmplus_enabled_v1"),
    healing = core.menu.checkbox(true, "hpmplus_healing_v1"),
    healing_cooldowns = core.menu.checkbox(true, "hpmplus_healing_cooldowns_v1"),
    auto_beacon = core.menu.checkbox(true, "hpmplus_auto_beacon_v1"),
    auto_dispel = core.menu.checkbox(true, "hpmplus_auto_dispel_v1"),
    damage = core.menu.checkbox(true, "hpmplus_damage_v1"),
    fishing = core.menu.checkbox(false, "hpmplus_auto_fishing_v1"),
    looting = core.menu.checkbox(false, "hpmplus_auto_looting_v1"),
    auto_aura = core.menu.checkbox(true, "hpmplus_auto_aura_v1"),
    auto_face = core.menu.checkbox(false, "hpmplus_auto_face_v1"),
    auto_target = core.menu.checkbox(false, "hpmplus_auto_target_v1"),
    training_dummy = core.menu.checkbox(true, "hpmplus_training_dummy_v1"),
    auto_steed = core.menu.checkbox(true, "hpmplus_auto_steed_v1"),
    arena_lines = core.menu.checkbox(true, "hpmplus_arena_lines_v1"),
    danger_zones = core.menu.checkbox(true, "hpmplus_danger_zones_v1"),
    boss_guide = core.menu.checkbox(true, "hpmplus_s2_boss_guide_v1"),
    auto_cc = core.menu.checkbox(true, "hpmplus_auto_cc_v1"),
    debug_log = core.menu.checkbox(true, "hpmplus_debug_log_v2"),
    interrupt = core.menu.checkbox(true, "hpmplus_interrupt_v1"),
    personals = core.menu.checkbox(true, "hpmplus_personals_v1"),
    emergency = core.menu.slider_int(5, 35, 15, "hpmplus_emergency_hp_v1"),
    heal_at = core.menu.slider_int(40, 95, 82, "hpmplus_heal_hp_v1"),
    aoe_at = core.menu.slider_int(40, 90, 70, "hpmplus_aoe_hp_v1"),
    enabled_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_enabled_key_v1") or core.menu.checkbox(false, "hpmplus_enabled_key_v1")),
    healing_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_healing_key_v1") or core.menu.checkbox(false, "hpmplus_healing_key_v1")),
    healing_cooldowns_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_healing_cooldowns_key_v1") or core.menu.checkbox(false, "hpmplus_healing_cooldowns_key_v1")),
    auto_beacon_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_beacon_key_v1") or core.menu.checkbox(false, "hpmplus_auto_beacon_key_v1")),
    auto_dispel_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_dispel_key_v1") or core.menu.checkbox(false, "hpmplus_auto_dispel_key_v1")),
    damage_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_damage_key_v1") or core.menu.checkbox(false, "hpmplus_damage_key_v1")),
    fishing_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_fishing_key_v1") or core.menu.checkbox(false, "hpmplus_fishing_key_v1")),
    looting_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_looting_key_v1") or core.menu.checkbox(false, "hpmplus_looting_key_v1")),
    auto_aura_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_aura_key_v1") or core.menu.checkbox(false, "hpmplus_auto_aura_key_v1")),
    auto_face_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_face_key_v1") or core.menu.checkbox(false, "hpmplus_auto_face_key_v1")),
    auto_target_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_target_key_v1") or core.menu.checkbox(false, "hpmplus_auto_target_key_v1")),
    training_dummy_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_training_dummy_key_v1") or core.menu.checkbox(false, "hpmplus_training_dummy_key_v1")),
    auto_steed_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_steed_key_v1") or core.menu.checkbox(false, "hpmplus_auto_steed_key_v1")),
    arena_lines_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_arena_lines_key_v1") or core.menu.checkbox(false, "hpmplus_arena_lines_key_v1")),
    danger_zones_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_danger_zones_key_v1") or core.menu.checkbox(false, "hpmplus_danger_zones_key_v1")),
    boss_guide_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_boss_guide_key_v1") or core.menu.checkbox(false, "hpmplus_boss_guide_key_v1")),
    auto_cc_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_auto_cc_key_v1") or core.menu.checkbox(false, "hpmplus_auto_cc_key_v1")),
    debug_log_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_debug_log_key_v1") or core.menu.checkbox(false, "hpmplus_debug_log_key_v1")),
    interrupt_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_interrupt_key_v1") or core.menu.checkbox(false, "hpmplus_interrupt_key_v1")),
    personals_key = (type(core.menu.keybind) == "function" and core.menu.keybind(0, false, "hpmplus_personals_key_v1") or core.menu.checkbox(false, "hpmplus_personals_key_v1")),
}

local profiles = {
    mythic_plus = { title = "MYTHIC+ • PREDICTIVE PARTY TRIAGE", healing = true, cooldowns = true,
        damage = true, emergency = 15, heal_at = 82, aoe_at = 70, units = 5, group_count = 2,
        strategy = "Rank the 5-player party by near-term damage forecast; Beacon setup, efficient Holy Power spending, and cooldowns follow group pressure.",
        detail = "Uses a short incoming-damage estimate plus current health. Holy Power spenders and Light of Dawn depend on the selected talents and number of nearby injured allies." },
    delve = { title = "DELVE • PLAYER & COMPANION SURVIVAL", healing = true, cooldowns = true,
        damage = true, emergency = 20, heal_at = 80, aoe_at = 70, units = 3, group_count = 1,
        strategy = "Include the known delve companion when detected; favor the companion under attack and keep emergency healing centered on the player group.",
        detail = "Adds Brann or Valeera when exposed by the client object list. NPC detection and damage forecasts depend on runtime visibility." },
    arena = { title = "ARENA • FOCUSED PRESSURE & SAVES", healing = true, cooldowns = true,
        damage = true, emergency = 24, heal_at = 78, aoe_at = 78, units = 3, group_count = 2,
        strategy = "Increase triage priority for allies targeted by enemy players; burst signals and multiple attackers can unlock healing cooldowns sooner.",
        detail = "Guarded arena damage follows the Damage rotation switch, preserves healing resources and stops under pressure. Enemy and partner data depend on runtime visibility." },
    battleground = { title = "BATTLEGROUND • TEAM & CLUSTER HEALING", healing = true, cooldowns = true,
        damage = false, emergency = 25, heal_at = 82, aoe_at = 74, units = 40, group_count = 3,
        strategy = "Scan visible friendly player units; prioritize pressured targets and use group healing when several teammates are clustered nearby.",
        detail = "Damage defaults off. Friendly-player and range information come from the host object API; far or hidden teammates may not be selectable." },
    world_pvp = { title = "WORLD PvP • SELF & FRIENDLY PRESSURE", healing = true, cooldowns = true,
        damage = false, emergency = 27, heal_at = 80, aoe_at = 74, units = 8, group_count = 2,
        strategy = "Keep target triage on the party and positively identified nearby allies; focus urgency rises when an enemy player is targeting them.",
        detail = "Damage defaults off. The profile limits allied selection to known party members and visible friendly players to avoid healing hostile units." },
    training = { title = "TRAINING DUMMY • ROTATION TEST", healing = true, cooldowns = true,
        damage = true, emergency = 15, heal_at = 82, aoe_at = 70, units = 5, group_count = 2,
        strategy = "Run the live talent-aware Holy rotation against a selected city training dummy while continuing to heal injured group members.",
        detail = "Select a training dummy. The profile exercises damage, Holy Power, hero talent and healing paths through the normal cast and logging pipeline." },
}
local current_mode, mode_override = "mythic_plus", nil
local last_action, gui_notice, window_open = "Waiting", "Automatic profile selection", true
local key_down = {}
local pending_cast, next_spell_request_at = nil, 0
local spell_retry_after, spell_failure_streak = {}, {}
local pvp_combat_started_at = -math.huge
local pending_outcomes, adaptive_by_mode = {}, {}
local cooldown_budget = { major = -math.huge, external = -math.huge, immunity = -math.huge,
    spell_failure_time = {}, mode_candidate = nil, mode_candidate_since = -math.huge,
    object_cache = {}, object_cache_valid = false, object_cache_ok = false,
    object_snapshot_active = false }
-- Object enumeration crosses the host boundary and was previously repeated by
-- healing, PvP, targeting, utility and render paths in the same frame. Keep a
-- per-pass snapshot so those consumers share one enumeration while unit handles
-- still expose their current health, casts and positions. Release every handle
-- when the update/render pass ends so roster changes are visible immediately.
cooldown_budget.begin_object_snapshot = function()
    cooldown_budget.object_cache, cooldown_budget.object_cache_valid = {}, false
    cooldown_budget.object_cache_ok = false
    cooldown_budget.object_snapshot_active = true
end
cooldown_budget.end_object_snapshot = function()
    cooldown_budget.object_cache, cooldown_budget.object_cache_valid = {}, false
    cooldown_budget.object_cache_ok = false
    cooldown_budget.object_snapshot_active = false
end
cooldown_budget.objects = function()
    if cooldown_budget.object_snapshot_active == true
        and cooldown_budget.object_cache_valid == true then
        return cooldown_budget.object_cache, cooldown_budget.object_cache_ok
    end
    if not core.object_manager or type(core.object_manager.get_all_objects) ~= "function" then
        return {}, false
    end
    local ok, objects = pcall(core.object_manager.get_all_objects)
    if not ok or type(objects) ~= "table" then objects = {} end
    if cooldown_budget.object_snapshot_active == true then
        cooldown_budget.object_cache, cooldown_budget.object_cache_valid = objects, true
        cooldown_budget.object_cache_ok = ok == true
    end
    return objects, ok == true
end
cooldown_budget.emergency_threshold = function()
    local fallback = profiles[current_mode] and profiles[current_mode].emergency or 25
    if current_mode ~= "mythic_plus" then return fallback end
    local ok, value = pcall(gui.emergency.get, gui.emergency)
    if not ok or type(value) ~= "number" or value ~= value then return fallback end
    return math.max(5, math.min(35, value))
end
cooldown_budget.resolve_spell = function(spell_id)
    if core.spell_book and type(core.spell_book.get_override_spell_id) == "function" then
        local ok, override = pcall(core.spell_book.get_override_spell_id, spell_id)
        if ok and type(override) == "number" and override > 0 then return override end
    end
    return spell_id
end
cooldown_budget.healing_spender_ready = function(player, power)
    return (type(power) == "number" and power >= 3) or Aura.present(player, SPELL.DIVINE_PURPOSE)
end
local manual_pause_until = -math.huge
local health_history, last_triage = {}, { guid = nil, unit = nil, time = -math.huge }

local function spell_known(spell_id)
    if not core.spell_book.is_spell_known then return false end
    local ok, known = pcall(core.spell_book.is_spell_known, spell_id)
    if ok and known == true then return true end
    ok, known = pcall(core.spell_book.is_spell_known, cooldown_budget.resolve_spell(spell_id))
    return ok and known == true
end

local talent_cache, talent_cache_time = nil, -math.huge
local function active_talent_snapshot()
    local now = core.time()
    -- The host clock can restart after reloads or reconnects. A negative age
    -- is stale rather than fresh; otherwise the previous build could remain
    -- cached until the new session clock catches the old timestamp.
    if talent_cache and now >= talent_cache_time
        and now - talent_cache_time < 1 then return talent_cache end
    local ok, entries = false, nil
    if core.game_ui and core.game_ui.get_active_talents then
        ok, entries = pcall(core.game_ui.get_active_talents)
    end
    local snapshot = { available = ok and type(entries) == "table" and #entries > 0,
        spells = {}, names = {} }
    if snapshot.available then
        for _, talent in pairs(entries) do
            if type(talent) == "table" and (tonumber(talent.rank) or 1) > 0 then
                local spell_id = tonumber(talent.spell_id)
                if spell_id then snapshot.spells[spell_id] = true end
                if type(talent.name) == "string" then
                    snapshot.names[string.lower(talent.name)] = true
                end
            end
        end
    end
    talent_cache, talent_cache_time = snapshot, now
    return snapshot
end

local function talent_selected(spell_id, talent_name)
    local snapshot = active_talent_snapshot()
    if snapshot.available then
        return snapshot.spells[spell_id] == true
            or (talent_name and snapshot.names[string.lower(talent_name)] == true)
    end
    -- Older clients or a not-yet-loaded talent panel may not expose the active
    -- node list. In that case spellbook knowledge is the safe compatibility fallback.
    return spell_known(spell_id)
end
cooldown_budget.armament_spell = function()
    if talent_selected(SPELL.HOLY_PRISM, "Holy Prism") then return SPELL.HOLY_PRISM end
    return SPELL.DIVINE_TOLL
end

local function hero_build()
    if talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments") then return "Lightsmith" end
    if talent_selected(SPELL.DAWNLIGHT, "Dawnlight") then return "Herald of the Sun" end
    return "Unknown / talent data unavailable"
end

local function beacon_build()
    local savior = talent_selected(SPELL.BEACON_OF_THE_SAVIOR, "Beacon of the Savior")
    local base = nil
    if talent_selected(SPELL.BEACON_OF_VIRTUE, "Beacon of Virtue") then base = "Beacon of Virtue"
    elseif talent_selected(SPELL.BEACON_OF_FAITH, "Beacon of Faith") then
        base = "Beacon of Faith (two persistent targets)"
    elseif spell_known(SPELL.BEACON_OF_LIGHT) then base = "Beacon of Light" end
    if savior and base then return "Beacon of the Savior + " .. base end
    if savior then return "Beacon of the Savior (automatic)" end
    if base then return base end
    return "No active Beacon talent detected"
end

local function safe_call(object, method, ...)
    if not object then return nil end
    local ok, fn = pcall(function() return object[method] end)
    if not ok or type(fn) ~= "function" then return nil end
    local call_ok, value = pcall(fn, object, ...)
    if call_ok then return value end
    return nil
end

cooldown_budget.is_training_dummy = function(unit)
    if not unit or safe_call(unit, "is_dead") == true or safe_call(unit, "is_player") == true then return false end
    if cooldown_budget.dummy_helper_checked ~= true then
        cooldown_budget.dummy_helper_checked = true
        local ok, helper = pcall(require, "common/utility/unit_helper")
        if ok then cooldown_budget.dummy_helper = helper end
    end
    if cooldown_budget.dummy_helper
        and safe_call(cooldown_budget.dummy_helper, "is_dummy", unit) == true then return true end
    -- Stable IDs cover localized clients and long-lived capital-city variants.
    -- Name families below cover newer expansion dummies before the host helper
    -- or this table has been updated.
    cooldown_budget.dummy_npc_ids = cooldown_budget.dummy_npc_ids or {
        [30527] = true, [31144] = true, [44820] = true, [46647] = true,
        [87322] = true, [88288] = true, [88314] = true, [107557] = true,
        [108420] = true, [114832] = true, [131992] = true, [131997] = true,
        [131998] = true, [144077] = true, [144081] = true, [173877] = true,
        [199057] = true,
    }
    local npc_id = tonumber(safe_call(unit, "get_npc_id") or safe_call(unit, "get_entry_id"))
    if npc_id and cooldown_budget.dummy_npc_ids[npc_id] then return true end
    local name = safe_call(unit, "get_name")
    name = type(name) == "string" and string.lower(name) or ""
    return (string.find(name, "training dummy", 1, true) ~= nil
        or string.find(name, "target dummy", 1, true) ~= nil
        or string.find(name, "tanking dummy", 1, true) ~= nil
        or string.find(name, "healing dummy", 1, true) ~= nil
        or string.find(name, "combat dummy", 1, true) ~= nil
        or string.find(name, "practice dummy", 1, true) ~= nil
        or string.find(name, "cleave dummy", 1, true) ~= nil
        or string.find(name, "swarm dummy", 1, true) ~= nil
        or string.find(name, "challenge dummy", 1, true) ~= nil)
end

local function read_core(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    return ok and value or nil
end

local function gcd_remaining(player)
    -- Match the host helper used by the Resto Shaman package. Fall back to the
    -- player wrapper for builds that do not publish spell 61304 cooldown data.
    local remaining = read_core(core.spell_book and core.spell_book.get_spell_cooldown, 61304)
    if type(remaining) == "number" then return math.max(0, remaining) end
    remaining = safe_call(player, "gcd_remains")
    return type(remaining) == "number" and math.max(0, remaining) or nil
end

local function detect_mode()
    if gui.training_dummy:get_state() == true then
        local player = core.object_manager and core.object_manager.get_local_player
            and core.object_manager.get_local_player() or nil
        if cooldown_budget.is_training_dummy(safe_call(player, "get_target")) then return "training" end
    end
    local raw = read_core(core.get_instance_type)
    local kind = type(raw) == "string" and string.lower(raw) or ""
    if kind == "arena" then return "arena" end
    if kind == "pvp" or kind == "battleground" then return "battleground" end
    if core.delves and read_core(core.delves.is_in_delve) == true then return "delve" end
    if kind == "party" then
        local difficulty = read_core(core.get_difficulty_id)
        local active = core.world and read_core(core.world.get_active_keystone_info)
        if difficulty == 8 or (type(active) == "table" and type(active.level) == "number" and active.level > 0) then
            return "mythic_plus"
        end
        return "mythic_plus"
    end
    if pvp_helper and type(pvp_helper.is_pvp_scenario) == "function" then
        local ok, is_pvp = pcall(pvp_helper.is_pvp_scenario, pvp_helper)
        if ok and is_pvp == true then return "world_pvp" end
    end
    return "world_pvp"
end

local function effective_mode()
    local detected = detect_mode()
    local next_mode = mode_override or detected
    if not profiles[next_mode] then next_mode = "mythic_plus" end

    -- Instance APIs can briefly fall back to open-world data during loading.
    -- Strong arena, battleground, delve, and party signals apply immediately;
    -- a fallback to world PvP must remain stable before replacing them.
    if not mode_override and next_mode == "world_pvp" and current_mode ~= "world_pvp" then
        if cooldown_budget.mode_candidate ~= next_mode then
            cooldown_budget.mode_candidate = next_mode
            cooldown_budget.mode_candidate_since = core.time()
            return current_mode, detected
        end
        if core.time() - cooldown_budget.mode_candidate_since < 1.25 then
            return current_mode, detected
        end
    else
        cooldown_budget.mode_candidate = nil
        cooldown_budget.mode_candidate_since = -math.huge
    end

    if next_mode ~= current_mode then
        local previous = current_mode
        current_mode = next_mode
        health_history = {}
        last_triage = { guid = nil, unit = nil, time = -math.huge }
        pending_outcomes = {}
        cooldown_budget.enemy_targets = {}
        cooldown_budget.swap_windows = {}
        cooldown_budget.pressure_focus = {}
        cooldown_budget.cast_patterns = {}
        cooldown_budget.pvp_active = false
        Telemetry.note("MODE", { "from=" .. tostring(previous),
            "to=" .. tostring(current_mode), "detected=" .. tostring(detected) })
    end
    return current_mode, detected
end

local function render_menu()
    gui.root:render("Holy Paladin Healing", function()
        gui.header:render("HOLY • SILVER HAND", gold)
        core.menu.text("Activity profile: " .. current_mode)
        core.menu.text("Hero build: " .. hero_build())
        core.menu.text("Beacon build: " .. beacon_build())
        gui.enabled:render("Plugin enabled", "Enable or pause all automatic actions.")
        gui.healing:render("Party healing", "Prioritize the lowest projected health over the next 2 seconds, subtracting already incoming heals and falling back to current health when prediction is unavailable.")
        gui.auto_beacon:render("Auto beacons", "Detect your Beacon talent. Maintain persistent beacons during PvP setup/safe windows and use Beacon of Virtue on pressured PvP targets or group damage when selected.")
        gui.auto_dispel:render("Auto dispel", "Use Holy's Cleanse on visible Magic effects, plus Poison and Disease when Improved Cleanse is talented. PvP crowd control is prioritized and Unstable Affliction blocks automatic cleansing.")
        gui.healing_cooldowns:render("Healing cooldowns", "Detect the active Lightsmith/Herald talents. Start Avenging Wrath or Avenging Crusader off the GCD on meaningful burst, then use the matching build cooldowns when healing is needed.")
        gui.fishing:render("Auto fishing", "Out of combat only: start Fishing, watch for a bite, and loot the catch.")
        gui.looting:render("Auto loot", "Out of combat only: loot nearby eligible creature corpses. Pauses while auto fishing is enabled.")
        gui.training_dummy:render("Training dummy rotation", "Select a city training dummy to run the live Holy healing and damage rotation for testing.")
        gui.auto_aura:render("Auto select aura", "Use Crusader Aura while mounted out of combat. Use Devotion Aura in combat unless another Paladin already supplies it; then use Concentration Aura so group auras do not overlap.")
        gui.auto_face:render("Auto face target", "Face your selected attackable target during combat. This does not move your character.")
        gui.auto_target:render("Auto select target", "During combat, select the nearest valid attackable enemy within 35 yards when you have no valid target.")
        gui.auto_steed:render("Auto Divine Steed", "Use Steed during sustained out-of-combat travel, or while moving under verified PvP pressure. Avoids casting during urgent ally healing.")
        gui.arena_lines:render("Arena teammate lines", "Draw a line to each party member: green means in range and line of sight, amber means out of range, red means blocked or immune to healing.")
        gui.danger_zones:render("PvE danger-zone aura", "BigWigs supplies timing. Red: registered hazard; green: no registered hazard; amber: safety unknown. Unregistered mechanics may still hit you.")
        gui.boss_guide:render("Season 2 boss guide", "Role-aware BigWigs instructions and world overlays for every current Season 2 dungeon boss.")
        gui.auto_cc:render("Automatic PvP crowd control", "After the opening 5 seconds, set up Hammer of Justice on the enemy healer or peel an attacker during a confirmed go. Blinding Light needs a pressured enemy cluster, line of sight, and usable crowd-control diminishing returns.")
        gui.damage:render("Damage rotation", "Use Holy Shock, Judgment, and Crusader Strike on your selected enemy during combat.")
        gui.interrupt:render("Mythic+ interrupts", "Use Rebuke on the selected enemy's interruptible cast; Hammer of Justice is a backup.")
        gui.personals:render("Automatic defensives and PvP saves", "Use Divine Protection before Divine Shield under focused pressure. In PvP, trade Sacrifice, matching BoP/Spellwarding clues, or Lay on Hands to save a pressured teammate. Checks current and predicted health.")
        gui.emergency:render("Emergency HP %", "Self-defensive trigger. Set the value to the HP threshold you want.")
        gui.heal_at:render("Direct heal threshold %", "Heal when the lowest party member's projected health over the next 2 seconds reaches this percentage.")
        gui.aoe_at:render("Group heal threshold %", "Use Light of Dawn when multiple nearby party members' projected health reaches this percentage.")
        gui.debug_log:render("Session log recorder", "Record activity boundaries, cast requests, spell events, roster health and current hero build to scripts_log/holy_paladin_mplus/session.log.")
        core.menu.text("CUSTOM HOTKEYS - click a key field, then press the customer's preferred key")
        gui.enabled_key:render("Toggle entire plugin")
        gui.healing_key:render("Toggle healing rotation")
        gui.healing_cooldowns_key:render("Toggle healing cooldowns")
        gui.auto_beacon_key:render("Toggle automatic Beacons")
        gui.auto_dispel_key:render("Toggle automatic dispels")
        gui.personals_key:render("Toggle defensives and teammate saves")
        gui.damage_key:render("Toggle damage rotation")
        gui.interrupt_key:render("Toggle interrupts")
        gui.auto_cc_key:render("Toggle PvP crowd control")
        gui.auto_aura_key:render("Toggle aura selection")
        gui.auto_steed_key:render("Toggle Divine Steed")
        gui.auto_face_key:render("Toggle automatic facing")
        gui.auto_target_key:render("Toggle automatic targeting")
        gui.training_dummy_key:render("Toggle training dummy mode")
        gui.arena_lines_key:render("Toggle arena teammate lines")
        gui.danger_zones_key:render("Toggle danger zones")
        gui.boss_guide_key:render("Toggle boss helper")
        gui.fishing_key:render("Toggle automatic fishing")
        gui.looting_key:render("Toggle automatic looting")
        gui.debug_log_key:render("Toggle encounter recorder")
        core.menu.text("Paladin artwork panel: F1. Current action: " .. last_action)
    end)
end

local function health_percent(unit)
    local hp, max_hp = safe_call(unit, "get_health"), safe_call(unit, "get_max_health")
    if type(hp) ~= "number" or type(max_hp) ~= "number" or max_hp <= 0 then return nil end
    return math.max(0, math.min(100, hp / max_hp * 100))
end

local function distance(player, unit)
    local d = safe_call(player, "distance_to", unit)
    return type(d) == "number" and d or math.huge
end

local function valid(unit)
    return unit and safe_call(unit, "is_valid") == true and safe_call(unit, "is_dead") ~= true
end

local function in_range(spell_id, target, player)
    if core.spell_book.is_spell_in_range then
        local ok, result = pcall(core.spell_book.is_spell_in_range, spell_id, target, player)
        if ok and result == false then return false end
    end
    return true
end

local function can_heal(player, unit, spell_id)
    if not valid(unit) or distance(player, unit) > 40
        or not in_range(spell_id or SPELL.HOLY_SHOCK, unit, player) then return false end
    if safe_call(unit, "is_immune_to_heal") == true then return false end
    if pvp_helper and type(pvp_helper.is_immune_to_heal) == "function" then
        local ok, immune = pcall(pvp_helper.is_immune_to_heal, pvp_helper, unit, 0)
        if ok and immune == true then return false end
    end
    if unit ~= player and core.graphics and type(core.graphics.is_line_of_sight) == "function" then
        local ok, visible = pcall(core.graphics.is_line_of_sight, player, unit)
        if ok and visible == false then return false end
    end
    return true
end

cooldown_budget.record_spell_failure = function(spell_id, base_delay)
    if not spell_id then return end
    local now = core.time()
    local failure_time = cooldown_budget.spell_failure_time
    local recent = now - (failure_time[spell_id] or -math.huge) <= 5
    local streak = recent and math.min(5, (spell_failure_streak[spell_id] or 0) + 1) or 1
    spell_failure_streak[spell_id] = streak
    failure_time[spell_id] = now
    spell_retry_after[spell_id] = now + math.min(1.6, (base_delay or 0.25) * (2 ^ (streak - 1)))
end

local function cast(spell_id, target, player, proc_spell, skip_gcd)
    local function skipped(reason, detail)
        Telemetry.skip(spell_id, target, reason, detail)
        return false
    end
    if not spell_id then return skipped("missing_spell_id") end
    cooldown_budget.requested_spell_id = spell_id
    spell_id = cooldown_budget.resolve_spell(spell_id)
    if not target or not valid(target) then return skipped("invalid_target") end
    local now = core.time()
    -- Leave ongoing manual or automated hard casts/channels intact. A pending
    -- request may outlive its original timeout while the game is still casting.
    if not OFF_GCD[spell_id] and (safe_call(player, "is_casting_spell") == true
        or safe_call(player, "is_channelling_spell") == true
        or safe_call(player, "is_channeling_spell") == true) then
        if pending_cast then pending_cast.expires = math.max(pending_cast.expires, now + 0.5) end
        return skipped("player_casting")
    end
    if pending_cast then
        local player_busy = safe_call(player, "is_casting_spell") == true
            or safe_call(player, "is_channelling_spell") == true
            or safe_call(player, "is_channeling_spell") == true
        if not valid(pending_cast.target) and not player_busy then
            Telemetry.note("RECOVERY", { "action=release_invalid_pending_target",
                "spell_id=" .. tostring(pending_cast.spell_id),
                "age=" .. string.format("%.2f", now - pending_cast.requested_at) })
            cooldown_budget.record_spell_failure(pending_cast.spell_id, 0.18)
            pending_cast = nil
        end
    end
    if pending_cast then
        if now < pending_cast.expires then
            return skipped("cast_pending", "pending_spell=" .. tostring(pending_cast.spell_id))
        end
        -- Missing host cast events must not leave the rotation frozen, but do
        -- apply a short retry pause before attempting the same spell again.
        Telemetry.note("RECOVERY", { "action=release_expired_pending_cast",
            "spell_id=" .. tostring(pending_cast.spell_id),
            "age=" .. string.format("%.2f", now - pending_cast.requested_at) })
        cooldown_budget.record_spell_failure(pending_cast.spell_id, 0.25)
        pending_cast = nil
    end
    if now < next_spell_request_at then return skipped("request_throttle") end
    if now < (spell_retry_after[spell_id] or 0) then return skipped("retry_backoff") end
    if not proc_spell and not spell_known(spell_id) then return skipped("spell_not_known") end
    if core.spell_book.is_usable_spell then
        local usable_ok, usable = pcall(core.spell_book.is_usable_spell, spell_id)
        if not usable_ok then return skipped("usable_check_failed") end
        if usable ~= true then return skipped("spell_not_usable") end
    end
    local hard_heal = spell_id == SPELL.FLASH_OF_LIGHT or spell_id == SPELL.HOLY_LIGHT
    local instant_heal = false
    if hard_heal then
        local cast_time = read_core(core.spell_book.get_spell_cast_time, spell_id)
        instant_heal = type(cast_time) == "number" and cast_time == 0
            or (spell_id == SPELL.FLASH_OF_LIGHT and Aura.present(player, SPELL.INFUSION_OF_LIGHT))
            or (spell_id == SPELL.HOLY_LIGHT and Aura.present(player, SPELL.HAND_OF_DIVINITY))
        if safe_call(player, "is_moving") == true and not instant_heal then
            return skipped("player_moving", "hard_cast_requires_stationary_player")
        end
    end
    local pvp_cast = current_mode == "arena" or current_mode == "battleground"
        or current_mode == "world_pvp"
    if hard_heal and not instant_heal and pvp_cast
        and (health_percent(target) or 100) > cooldown_budget.emergency_threshold()
        and pvp_helper then
        local kick_threat = false
        local objects = cooldown_budget.objects()
        if type(objects) == "table" then
            for _, enemy in pairs(objects) do
                if valid(enemy) and safe_call(enemy, "is_player") == true
                    and safe_call(enemy, "is_enemy_with", player) == true
                    and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 40 then
                    for _, method in ipairs({ "has_interrupt_available", "is_interrupt_ready", "can_interrupt" }) do
                        if type(pvp_helper[method]) == "function" then
                            local call_ok, ready
                            if method == "can_interrupt" then
                                call_ok, ready = pcall(pvp_helper[method], pvp_helper, enemy, player, 500)
                            else
                                call_ok, ready = pcall(pvp_helper[method], pvp_helper, enemy, 500)
                            end
                            if call_ok and ready == true then kick_threat = true; break end
                        end
                    end
                end
                if kick_threat then break end
            end
        end
        if kick_threat then return skipped("pvp_kick_threat", "hold_non_emergency_hard_cast") end
    end
    if not skip_gcd and not OFF_GCD[spell_id] then
        local remaining = gcd_remaining(player)
        if type(remaining) == "number" and remaining > 0.05 then
            return skipped("gcd_active", string.format("%.2f", remaining))
        end
    end
    local has_charge = false
    if core.spell_book.get_spell_charge then
        local charge_ok, charges = pcall(core.spell_book.get_spell_charge, spell_id)
        has_charge = charge_ok and type(charges) == "number" and charges > 0
        if charge_ok and type(charges) == "number" and charges <= 0
            and type(core.spell_book.get_spell_charge_max) == "function" then
            local max_ok, maximum = pcall(core.spell_book.get_spell_charge_max, spell_id)
            if max_ok and type(maximum) == "number" and maximum > 0 then
                return skipped("no_charges", "charge_pool_empty")
            end
        end
    end
    if not has_charge and core.spell_book.get_spell_cooldown then
        local ok, cd = pcall(core.spell_book.get_spell_cooldown, spell_id)
        if ok and type(cd) == "number" and cd > 0.15 then
            return skipped("cooldown", string.format("%.2f", cd))
        end
    end
    if not in_range(spell_id, target, player) then return skipped("out_of_range") end
    -- TrinityCore's 12.1 spell script confirms offensive Holy Shock has a
    -- server-side facing requirement. Treat an explicit host-facing failure
    -- as unavailable so the same rejected request does not stall the tick.
    if spell_id == SPELL.HOLY_SHOCK and safe_call(player, "can_attack", target) == true then
        local facing = safe_call(player, "is_facing", target)
        if facing == false then return skipped("target_not_in_front") end
    end
    -- Accepted means queued by the host, not confirmed by the game. A pending
    -- latch below waits for the spellcast outcome before another request.
    next_spell_request_at = now + 0.16
    local ok, accepted = pcall(core.input.cast_target_spell, spell_id, target)
    local result = ok and accepted == true
    Telemetry.cast(spell_id, target, "spell", result)
    if result then
        local confirmation_window = hard_heal and not instant_heal and 2.5 or 0.9
        pending_cast = { spell_id = spell_id, target = target,
            target_guid = safe_call(target, "get_guid") or tostring(target),
            health_before = health_percent(target), requested_at = now,
            expires = now + confirmation_window }
        local spell_name = tostring(spell_id)
        if core.spell_book.get_spell_name then
            local name_ok, name = pcall(core.spell_book.get_spell_name, spell_id)
            if name_ok and name then spell_name = name end
        end
        last_action = spell_name .. " → " .. tostring(safe_call(target, "get_name") or "target")
    else
        cooldown_budget.record_spell_failure(spell_id, 0.18)
    end
    return result
end

local function group_units(player)
    local result, seen = {}, {}
    local unit_limit = profiles[current_mode] and profiles[current_mode].units or 5
    local function add(unit)
        if not valid(unit) then return end
        local guid = safe_call(unit, "get_guid") or tostring(unit)
        if seen[guid] then return end
        local friendly = unit == player or safe_call(unit, "is_party_member") == true
        if not friendly and (current_mode == "battleground" or current_mode == "world_pvp") then
            friendly = safe_call(unit, "is_player") == true
                and safe_call(unit, "is_friend_with", player) == true
                and safe_call(unit, "is_enemy_with", player) ~= true
        end
        if not friendly and current_mode == "delve" then
            local name = safe_call(unit, "get_name")
            local npc_id = safe_call(unit, "get_npc_id") or safe_call(unit, "get_entry_id")
            name = type(name) == "string" and string.lower(name) or ""
            friendly = safe_call(unit, "is_player") ~= true
                and safe_call(unit, "is_enemy_with", player) ~= true
                and safe_call(player, "can_attack", unit) ~= true
                and (npc_id == 210759 or npc_id == 242381
                    or name == "brann bronzebeard" or name == "valeera sanguinar")
        end
        if not friendly and current_mode == "training"
            and cooldown_budget.is_training_dummy(unit)
            and safe_call(player, "can_attack", unit) ~= true then
            friendly = true
        end
        if friendly then
            seen[guid] = true
            result[#result + 1] = unit
        end
    end
    add(player)
    local objects = cooldown_budget.objects()
    if type(objects) == "table" then
        for _, unit in pairs(objects) do add(unit) end
    end
    -- Object-manager order is not a healing priority. Rank the full visible
    -- roster before applying each profile's unit cap so party members, nearby
    -- units, objective carriers, and injured allies cannot be discarded just
    -- because unrelated friendly objects were enumerated first.
    table.sort(result, function(a, b)
        if a == b then return false end
        if a == player then return true end
        if b == player then return false end
        local a_party = safe_call(a, "is_party_member") == true
        local b_party = safe_call(b, "is_party_member") == true
        if a_party ~= b_party then return a_party end
        local a_objective = safe_call(a, "is_objective_carrier") == true
        local b_objective = safe_call(b, "is_objective_carrier") == true
        if a_objective ~= b_objective then return a_objective end
        local a_range, b_range = distance(player, a) <= 40, distance(player, b) <= 40
        if a_range ~= b_range then return a_range end
        local a_hp, b_hp = health_percent(a) or 101, health_percent(b) or 101
        if a_hp ~= b_hp then return a_hp < b_hp end
        local a_distance, b_distance = distance(player, a), distance(player, b)
        if a_distance ~= b_distance then return a_distance < b_distance end
        return tostring(safe_call(a, "get_guid") or a)
            < tostring(safe_call(b, "get_guid") or b)
    end)
    while #result > unit_limit do table.remove(result) end
    return result
end

local DAMAGE_PREDICTION_WINDOW = 2.0

local function predicted_health_percent(unit)
    local current = health_percent(unit)
    if not current then return nil, nil end
    local guid = safe_call(unit, "get_guid") or tostring(unit)
    local history = health_history[guid]
    local velocity = history and (history.velocity or 0) or 0
    local acceleration = history and (history.acceleration or 0) or 0
    local danger_floor = cooldown_budget.emergency_threshold()
    -- Measure time until emergency healing is required, rather than time until
    -- zero health. This gives the rotation enough lead time to react to a
    -- rapidly falling ally before that ally is already in lethal range.
    local time_to_danger = velocity > 0.1
        and math.max(0, current - danger_floor) / velocity or math.huge
    -- Health-loss acceleration catches a pull, swap, or damage wave before a
    -- fixed health threshold is crossed. Keep the extrapolation short and
    -- bounded because movement, absorbs, and delayed heals can change it fast.
    local trend_loss = math.min(25, velocity * 1.25 + acceleration * 0.35)
    if current_mode == "arena" or current_mode == "battleground" or current_mode == "world_pvp" then
        trend_loss = math.min(12, trend_loss)
    end
    local trend_projected = math.max(0, current - trend_loss)
    local hp, max_hp = safe_call(unit, "get_health"), safe_call(unit, "get_max_health")
    local incoming = safe_call(unit, "get_incoming_damage", DAMAGE_PREDICTION_WINDOW)
    if type(incoming) ~= "number" or type(hp) ~= "number"
        or type(max_hp) ~= "number" or max_hp <= 0 then
        return trend_projected, current, trend_loss, time_to_danger
    end
    incoming = math.max(0, incoming)
    local incoming_heals = safe_call(unit, "get_incoming_heals")
    if type(incoming_heals) ~= "number" then incoming_heals = 0 end
    local shield = safe_call(unit, "get_total_shield")
    if type(shield) ~= "number" then shield = 0 end
    local heal_absorb = nil
    for _, method in ipairs({ "get_total_heal_absorb", "get_total_heal_absorbs", "get_heal_absorb" }) do
        heal_absorb = safe_call(unit, method)
        if type(heal_absorb) == "number" then break end
    end
    if type(heal_absorb) ~= "number" then heal_absorb = 0 end
    -- The runtime's damage forecast is heuristic and incoming heals have no
    -- deadline here. Credit confirmed absorbs against at most 75% of the hit,
    -- then discount at most half the remainder with usable queued healing.
    -- Uncovered heal absorbs are effective-health debt, capped at 25% health.
    local shield_credit = math.min(math.max(0, shield), incoming * 0.75)
    local after_shield = math.max(0, incoming - shield_credit)
    local usable_healing = math.max(0, incoming_heals - heal_absorb)
    local covered_healing = math.min(usable_healing, after_shield * 0.5)
    local absorb_debt = math.min(max_hp * 0.25, math.max(0, heal_absorb - incoming_heals))
    local net_incoming = math.max(0, after_shield - covered_healing) + absorb_debt
    local incoming_percent = net_incoming / max_hp * 100
    local projected = math.min(trend_projected,
        math.max(0, math.min(100, (hp - net_incoming) / max_hp * 100)))
    -- IZI also exposes a combined future-health estimate. Use it as a bounded
    -- second opinion so one heuristic cannot create an unbounded emergency.
    local native_ok, native_future, native_damage, native_current, native_incoming = pcall(function()
        return unit:get_health_percentage_inc(1.5)
    end)
    if native_ok and type(native_future) == "number" then
        local native_cap = (current_mode == "arena" or current_mode == "battleground"
            or current_mode == "world_pvp") and 12 or 30
        projected = math.min(projected, math.max(current - native_cap,
            math.max(0, math.min(100, native_future))))
        if type(native_incoming) == "number" then
            incoming_percent = math.max(incoming_percent, math.max(0, native_incoming))
        end
    end
    -- PvP forecasts in the attached run jumped from 62% to 97% projected HP
    -- in one second while current HP stayed at 97%. Treat them as an urgency
    -- nudge, not a precise prediction: at most 12 percentage points of damage
    -- may move PvP triage below the observed health value.
    if current_mode == "arena" or current_mode == "battleground" or current_mode == "world_pvp" then
        projected = math.max(projected, current - 12)
    end
    return projected, current, math.max(incoming_percent, trend_loss), time_to_danger
end

cooldown_budget.observe_arena_health = function(player, units, pressure)
    if current_mode ~= "arena" then cooldown_budget.arena_health = {}; return end
    local rows = cooldown_budget.arena_health or {}
    cooldown_budget.arena_health = rows
    local active = safe_call(player, "is_in_combat") == true
    for _, unit in ipairs(units or {}) do
        if safe_call(unit, "is_in_combat") == true then active = true end
    end
    for guid, row in pairs(rows) do
        if not row.dead and safe_call(row.unit, "is_valid") == true
            and safe_call(row.unit, "is_dead") == true then
            row.dead = true
            Telemetry.note("ARENA_DEATH", { "target=" .. tostring(row.name),
                "last_hp=" .. tostring(row.hp), "seconds_since_seen=" .. tostring(core.time() - row.seen) })
        end
        if core.time() - row.seen > 10 then rows[guid] = nil end
    end
    if not active then cooldown_budget.arena_health = {}; return end
    for _, unit in ipairs(units or {}) do
        local hp = health_percent(unit)
        local guid = safe_call(unit, "get_guid") or tostring(unit)
        if hp and valid(unit) then
            local old = rows[guid]
            local critical = hp <= 35
            local was_critical = old and old.critical or false
            local focus = pressure and pressure.targets and pressure.targets[guid]
            local name = safe_call(unit, "get_name") or "ally"
            if critical and not was_critical then
                Telemetry.note("ARENA_EMERGENCY", { "target=" .. tostring(name), "hp=" .. tostring(hp),
                    "attackers=" .. tostring(focus and focus.count or 0),
                    "burst_sources=" .. tostring(focus and focus.burst_sources or 0),
                    "holy_power=" .. tostring(safe_call(player, "get_power", HOLY_POWER) or "unknown"),
                    "holy_shock_cd=" .. tostring(read_core(core.spell_book.get_spell_cooldown, SPELL.HOLY_SHOCK) or "unknown"),
                    "observed=true" })
            elseif was_critical and hp >= 60 then
                Telemetry.note("ARENA_RECOVERY", { "target=" .. tostring(name), "hp=" .. tostring(hp),
                    "observed=true", "cause=unattributed" })
            end
            rows[guid] = { unit = unit, name = name, hp = hp, seen = core.time(),
                critical = critical or (was_critical and hp < 60), dead = false }
        end
    end
end

local function pvp_pressure(player, units)
    local result = { attackers = 0, burst = false, targets = {}, target = nil, target_attackers = 0 }
    if current_mode ~= "arena" and current_mode ~= "battleground"
        and current_mode ~= "world_pvp" and current_mode ~= "delve" then
        cooldown_budget.pvp_active = false
        return result
    end
    local by_guid = {}
    local previous_enemy_targets = cooldown_budget.enemy_targets or {}
    local current_enemy_targets = {}
    local swap_windows = cooldown_budget.swap_windows or {}
    local continuing_engagement = cooldown_budget.pvp_active == true
    for _, unit in ipairs(units) do by_guid[safe_call(unit, "get_guid") or tostring(unit)] = unit end
    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return result end
    for _, enemy in pairs(objects) do
        if valid(enemy) and (current_mode == "delve" or safe_call(enemy, "is_player") == true)
            and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 60 then
            local target = safe_call(enemy, "get_target")
            local target_source = "selected"
            if current_mode == "arena" and (safe_call(enemy, "is_casting_spell") == true
                or safe_call(enemy, "is_channelling_spell") == true
                or safe_call(enemy, "is_channeling_spell") == true) then
                local cast_target = safe_call(enemy, "get_active_spell_target")
                local cast_guid = safe_call(cast_target, "get_guid")
                if cast_guid and by_guid[cast_guid] then
                    target, target_source = by_guid[cast_guid], "active_cast"
                end
            end
            local target_guid = safe_call(target, "get_guid")
            local friend = target_guid and by_guid[target_guid]
            if friend then
                local key = target_guid
                local enemy_guid = safe_call(enemy, "get_guid") or tostring(enemy)
                current_enemy_targets[enemy_guid] = target_guid
                local burst = false
                if pvp_helper and type(pvp_helper.has_burst_active) == "function" then
                    local burst_ok, active = pcall(pvp_helper.has_burst_active, pvp_helper, enemy, 500)
                    burst = burst_ok and active == true
                end
                local state = result.targets[key] or { count = 0, burst = false, unit = friend,
                    nearby_attackers = 0, melee_attackers = 0, physical_attackers = 0, magic_attackers = 0,
                    interruptible_casts = 0, enemies = {}, swap = false, ramp = false, focus_age = 0,
                    burst_sources = 0, cast_target_sources = 0 }
                if continuing_engagement and previous_enemy_targets[enemy_guid]
                    and previous_enemy_targets[enemy_guid] ~= target_guid then
                    swap_windows[target_guid] = core.time() + 2.5
                    result.swap = true
                    result.swap_target = friend
                end
                state.swap = (swap_windows[target_guid] or -math.huge) > core.time()
                state.count = state.count + 1
                state.burst = state.burst or burst
                if burst then state.burst_sources = state.burst_sources + 1 end
                if target_source == "active_cast" then state.cast_target_sources = state.cast_target_sources + 1 end
                state.enemies[#state.enemies + 1] = enemy
                if distance(enemy, friend) <= 8 then
                    state.nearby_attackers = state.nearby_attackers + 1
                end
                local melee = false
                if pvp_helper and type(pvp_helper.is_melee) == "function" then
                    local melee_ok, value = pcall(pvp_helper.is_melee, pvp_helper, enemy)
                    melee = melee_ok and value == true
                end
                local channel = safe_call(enemy, "is_channelling_spell") == true
                    or safe_call(enemy, "is_channeling_spell") == true
                local active_spell = tonumber(channel and (safe_call(enemy, "get_active_channel_spell_id")
                    or safe_call(enemy, "get_active_channel_id")) or safe_call(enemy, "get_active_spell_id"))
                local school = active_spell and read_core(core.spell_book.get_spell_school, active_spell)
                local schools = enums.spell_schools_flags
                local physical_cast = false
                if school and schools and schools.Physical then
                    if type(schools.contains) == "function" then
                        local school_ok, value = pcall(schools.contains, school, schools.Physical)
                        physical_cast = school_ok and value == true
                    else
                        physical_cast = school == schools.Physical
                    end
                end
                if melee and distance(enemy, friend) <= 10 then
                    state.melee_attackers = state.melee_attackers + 1
                    state.physical_attackers = state.physical_attackers + 1
                elseif physical_cast then
                    state.physical_attackers = state.physical_attackers + 1
                elseif safe_call(enemy, "is_casting_spell") == true or channel then
                    state.magic_attackers = state.magic_attackers + 1
                end
                if (safe_call(enemy, "is_casting_spell") == true or channel)
                    and safe_call(enemy, "is_active_spell_interruptable") == true then
                    state.interruptible_casts = state.interruptible_casts + 1
                end
                result.targets[key] = state
                result.attackers = result.attackers + 1
                result.burst = result.burst or burst
                if state.count > result.target_attackers then
                    result.target, result.target_attackers = friend, state.count
                end
            end
        end
    end
    local now = core.time()
    cooldown_budget.pressure_focus = cooldown_budget.pressure_focus or {}
    for guid, state in pairs(result.targets) do
        local old = cooldown_budget.pressure_focus[guid]
        local continuous = old and now - (old.seen or 0) <= 0.8
        state.focus_age = continuous and math.max(0, now - (old.started or now)) or 0
        state.ramp = not continuous or state.count > (old.count or 0)
        cooldown_budget.pressure_focus[guid] = {
            started = continuous and old.started or now, seen = now, count = state.count }
    end
    for guid, state in pairs(cooldown_budget.pressure_focus) do
        if now - (state.seen or 0) > 1.5 then cooldown_budget.pressure_focus[guid] = nil end
    end
    -- Trinket observations belong to one PvP engagement. Shuffle rounds and
    -- fresh arena/BG fights must not inherit an opponent's previous state.
    local pvp_mode = current_mode == "arena" or current_mode == "battleground"
        or current_mode == "world_pvp"
    local active = pvp_mode and (safe_call(player, "is_in_combat") == true or result.attackers > 0)
    if active and cooldown_budget.pvp_active ~= true then
        if pvp_helper and type(pvp_helper.clear_all_trinket_history) == "function" then
            pcall(pvp_helper.clear_all_trinket_history, pvp_helper)
        end
        Telemetry.note("PVP_RESET", { "action=new_engagement", "mode=" .. current_mode })
    end
    if result.swap then
        Telemetry.note("PRESSURE", { "action=enemy_target_swap",
            "target=" .. tostring(safe_call(result.swap_target, "get_name") or "ally"),
            "attackers=" .. tostring(result.target_attackers) })
    end
    cooldown_budget.enemy_targets = active and current_enemy_targets or {}
    cooldown_budget.swap_windows = active and swap_windows or {}
    cooldown_budget.pvp_active = active
    return result
end

cooldown_budget.enemy_has_breakable_control = function(enemy)
    local pvp_mode = current_mode == "arena" or current_mode == "battleground"
        or current_mode == "world_pvp"
    if not pvp_mode or not pvp_helper
        or type(pvp_helper.is_crowd_controlled) ~= "function" then return false end
    local ok, controlled, _, remaining = pcall(pvp_helper.is_crowd_controlled,
        pvp_helper, enemy, nil, 500)
    return ok and controlled == true and (tonumber(remaining) or 501) > 500
end

cooldown_budget.safe_to_damage = function(player, enemy)
    return valid(enemy) and safe_call(player, "can_attack", enemy) == true
        and not cooldown_budget.enemy_has_breakable_control(enemy)
end
cooldown_budget.arena_enemy_safe = function(player, enemy)
    if not valid(enemy) or safe_call(player, "can_attack", enemy) ~= true then return false end
    local control_safe = not cooldown_budget.enemy_has_breakable_control(enemy)
    if pvp_helper and type(pvp_helper.is_crowd_controlled_weak) == "function" then
        local ok, weak = pcall(pvp_helper.is_crowd_controlled_weak, pvp_helper, enemy, 500)
        if ok and type(weak) == "boolean" then control_safe = not weak end
    end
    if not control_safe or Aura.present(enemy, SPELL.DIVINE_SHIELD) or Aura.present(enemy, 45438) then return false end
    local flags = pvp_helper and pvp_helper.damage_type_flags or {}
    if flags.ANY and type(pvp_helper.is_damage_immune) == "function" then
        local ok, immune = pcall(pvp_helper.is_damage_immune, pvp_helper, enemy, flags.ANY, 500)
        if ok and immune == true then return false end
    end
    if not core.graphics or type(core.graphics.is_line_of_sight) ~= "function" then return false end
    local ok, visible = pcall(core.graphics.is_line_of_sight, player, enemy)
    return ok and visible == true
end

cooldown_budget.prism_friendly_safe = function(player, ally)
    if current_mode ~= "arena" and current_mode ~= "battleground"
        and current_mode ~= "world_pvp" then return true end
    local objects, objects_ok = cooldown_budget.objects()
    if objects_ok ~= true or type(objects) ~= "table" then return false end
    for _, enemy in pairs(objects) do
        if valid(enemy) and safe_call(player, "can_attack", enemy) == true
            and cooldown_budget.enemy_has_breakable_control(enemy) then
            local separation = distance(ally, enemy)
            if separation <= 30 or separation == math.huge then
                Telemetry.skip(SPELL.HOLY_PRISM, ally, "prism_cc_splash", "radius=30")
                return false
            end
        end
    end
    return true
end

cooldown_budget.prism_enemy_coverage = function(player, enemy, units, threshold, required)
    if not cooldown_budget.safe_to_damage(player, enemy) then return false end
    local covered = 0
    local needed = math.max(1, math.min(2, tonumber(required) or 2))
    for _, ally in ipairs(units or {}) do
        local hp = health_percent(ally)
        if hp and hp <= (tonumber(threshold) or 92)
            and can_heal(player, ally, SPELL.HOLY_PRISM)
            and distance(enemy, ally) <= 30 then
            covered = covered + 1
            if covered >= needed then return true end
        end
    end
    return false
end

local function healing_conversion_enemy(player, focus_state, max_distance)
    local reach = tonumber(max_distance) or 30
    local function eligible(enemy)
        if distance(player, enemy) > reach then return false end
        if current_mode == "arena" then return cooldown_budget.arena_enemy_safe(player, enemy) end
        return cooldown_budget.safe_to_damage(player, enemy)
    end
    local target = safe_call(player, "get_target")
    if eligible(target) then return target end
    for _, enemy in ipairs(focus_state and focus_state.enemies or {}) do
        if eligible(enemy) then return enemy end
    end
    -- PvP generators may use pets or totems when no player target is
    -- available. Pressure attribution intentionally tracks players, so make a
    -- final object scan and choose the nearest fully validated hostile unit.
    if current_mode == "arena" or current_mode == "battleground"
        or current_mode == "world_pvp" then
        local objects = cooldown_budget.objects()
        if type(objects) == "table" then
            local best, best_distance = nil, math.huge
            for _, enemy in pairs(objects) do
                local enemy_distance = distance(player, enemy)
                local generator_kind = current_mode == "arena"
                    or safe_call(enemy, "is_player") == true
                    or safe_call(enemy, "is_pet") == true
                    or safe_call(enemy, "is_totem") == true
                    or safe_call(enemy, "is_in_combat") == true
                if generator_kind and safe_call(enemy, "is_enemy_with", player) == true
                    and enemy_distance < best_distance and eligible(enemy) then
                    best, best_distance = enemy, enemy_distance
                end
            end
            if best then return best end
        end
    end
    return nil
end

local function select_injured(player, units, pressure)
    local best, best_hp, best_current_hp, best_score = nil, 101, 101, math.huge
    local previous_score, previous_hp, previous_tier = nil, nil, nil
    local emergency = cooldown_budget.emergency_threshold()
    local best_tier = 3
    for _, unit in ipairs(units or group_units(player)) do
        local hp, current, _, time_to_danger = predicted_health_percent(unit)
        if hp and can_heal(player, unit, SPELL.HOLY_SHOCK) then
            local score = hp
            -- Actual emergencies outrank forecast emergencies, which outrank
            -- routine pressure. Bonuses and stickiness apply within a tier.
            local tier = current and current <= emergency and 0 or (hp <= emergency and 1 or 2)
            local guid = safe_call(unit, "get_guid") or tostring(unit)
            local focus = pressure and pressure.targets and pressure.targets[guid]
            if focus then
                score = score - math.min(22, focus.count * 5 + (focus.burst and 8 or 0)
                    + (focus.swap and 10 or 0))
                if focus.ramp then score = score - 7 end
                if (focus.focus_age or 0) >= 1.5 then score = score - 4 end
            end
            local history = health_history[guid]
            if history then
                local velocity = history.velocity or 0
                score = score - math.min(12, velocity * 0.4)
                if time_to_danger <= 2.0 then score = score - 30
                elseif time_to_danger <= 3.5 then score = score - 18 end
            end
            if current_mode == "battleground" then
                local native_objective = safe_call(unit, "is_objective_carrier") == true
                if native_objective then score = score - 14 end
                local buffs = safe_call(unit, "get_buffs") or safe_call(unit, "get_auras")
                if type(buffs) == "table" then
                    for _, aura in pairs(buffs) do
                        local name = nil
                        if type(aura) == "table" then
                            local name_ok, value = pcall(function()
                                return aura.buff_name or aura.name or aura.spell_name
                            end)
                            if name_ok then name = value end
                        end
                        name = type(name) == "string" and string.lower(name) or ""
                        if name == "alliance flag" or name == "horde flag"
                            or name == "netherstorm flag" or name == "orb of power"
                            or name:find("flag carrier", 1, true) then
                            if not native_objective then score = score - 14 end
                            break
                        end
                    end
                end
            end
            if unit == player and (current_mode == "arena" or current_mode == "world_pvp") then
                score = score - 2
            end
            if tier < best_tier or (tier == best_tier and (score < best_score
                or (score == best_score and current and current < (best_current_hp or 101)))) then
                best, best_hp, best_current_hp, best_score = unit, hp, current, score
                best_tier = tier
            end
            if guid == last_triage.guid then previous_score, previous_hp, previous_tier = score, hp, tier end
        end
    end
    if last_triage.unit and core.time() - last_triage.time < 0.60
        and previous_tier == best_tier and previous_score and previous_score <= best_score + 6
        and can_heal(player, last_triage.unit, SPELL.HOLY_SHOCK) then
        return last_triage.unit, previous_hp
    end
    local best_guid = best and (safe_call(best, "get_guid") or tostring(best)) or nil
    if best_guid ~= last_triage.guid then
        last_triage = { guid = best_guid, unit = best, time = core.time() }
    end
    return best, best_hp
end

local function update_health_velocity(units)
    local now = core.time()
    local seen = {}
    for _, unit in ipairs(units or {}) do
        local guid = safe_call(unit, "get_guid") or tostring(unit)
        local hp = health_percent(unit)
        seen[guid] = true
        if hp then
            local old = health_history[guid]
            if old and (now < old.time or now - old.time > 3) then
                -- Loading, a long stalled frame, or a clock reset invalidates
                -- short-window velocity. Start a fresh sample on recovery.
                health_history[guid] = { hp = hp, time = now, velocity = 0, acceleration = 0 }
            elseif old and now - old.time >= 0.20 then
                local dt = math.max(0.20, now - old.time)
                local falling = math.max(0, (old.hp - hp) / dt)
                -- A confirmed health gain means the previous downward trend no
                -- longer describes this ally. Clear it immediately so a large
                -- heal cannot leave stale emergency priority behind.
                local recovered = hp >= old.hp + 1
                local retained = recovered and 0
                    or math.max(0, (old.velocity or 0) - dt * 4)
                local raw_acceleration = math.max(0, (falling - (old.velocity or 0)) / dt)
                local retained_acceleration = recovered and 0
                    or math.max(0, (old.acceleration or 0) - dt * 12)
                health_history[guid] = { hp = hp, time = now,
                    velocity = math.max(falling, retained),
                    acceleration = math.min(30, math.max(raw_acceleration, retained_acceleration)) }
            elseif not old then
                health_history[guid] = { hp = hp, time = now, velocity = 0, acceleration = 0 }
            end
        end
    end
    for guid, row in pairs(health_history) do
        if not seen[guid] and now - row.time > 10 then health_history[guid] = nil end
    end
end

local function select_beaconed_injured(player, units)
    local best, best_hp = nil, 101
    for _, unit in ipairs(units) do
        local hp = predicted_health_percent(unit)
        local beaconed = Aura.present(unit, SPELL.BEACON_OF_LIGHT)
            or Aura.present(unit, SPELL.BEACON_OF_FAITH)
            or Aura.present(unit, SPELL.BEACON_OF_VIRTUE)
            or Aura.present(unit, SPELL.BEACON_OF_THE_SAVIOR)
        if beaconed and hp and hp <= 90 and hp < best_hp
            and can_heal(player, unit, SPELL.FLASH_OF_LIGHT) then
            best, best_hp = unit, hp
        end
    end
    return best, best_hp
end

local function injured_count(player, units, threshold, radius)
    local count = 0
    for _, unit in ipairs(units) do
        local hp = predicted_health_percent(unit)
        if hp and hp <= threshold and distance(player, unit) <= (radius or 40)
            and can_heal(player, unit, SPELL.HOLY_SHOCK) then count = count + 1 end
    end
    return count
end

local function safe_field(object, field)
    local ok, value = pcall(function() return object[field] end)
    return ok and value or nil
end

local function is_pvp_mode()
    return current_mode == "arena" or current_mode == "battleground" or current_mode == "world_pvp"
end

local PVP_DISPEL_PRIORITY = {
    [853] = 100,   -- Hammer of Justice
    [118] = 95,    -- Polymorph
    [28272] = 95, [28271] = 95, [61305] = 95, [61721] = 95,
    [8122] = 95,   -- Psychic Scream
    [5782] = 95,   -- Fear
    [3355] = 95,   -- Freezing Trap
    [20066] = 95,  -- Repentance
    [6789] = 90,   -- Mortal Coil
    [31661] = 95,  -- Dragon's Breath
    [360806] = 95, -- Sleep Walk
    [6358] = 95,   -- Seduction
}
local BREAKABLE_CC_CAST = {
    [118] = true, [28272] = true, [28271] = true, [61305] = true, -- Polymorph variants
    [5782] = true, [130616] = true, [20066] = true, [51514] = true, -- Fear, Repentance, Hex
    [605] = true, [6358] = true, [360806] = true, -- Mind Control, Seduction, Sleep Walk
}
local UNSTABLE_AFFLICTION = { [30108] = true, [316099] = true, [342938] = true }

local function aura_id(aura)
    return tonumber(safe_field(aura, "buff_id") or safe_field(aura, "debuff_id")
        or safe_field(aura, "spell_id") or safe_field(aura, "spellId") or safe_field(aura, "id"))
end

local function visible_debuffs(unit)
    local result, seen = {}, {}
    local function add(aura)
        if type(aura) ~= "table" then return end
        local id = aura_id(aura)
        if id and seen[id] then return end
        if id then seen[id] = true end
        result[#result + 1] = aura
    end
    local debuffs = safe_call(unit, "get_debuffs")
    if type(debuffs) == "table" then for _, aura in pairs(debuffs) do add(aura) end end
    local all = safe_call(unit, "get_auras")
    if type(all) == "table" then
        for _, aura in pairs(all) do
            local id = aura_id(aura)
            local data = id and safe_call(unit, "get_debuff_data", { id })
            if safe_field(aura, "is_harmful") == true or safe_field(aura, "is_debuff") == true
                or (type(data) == "table" and safe_field(data, "is_active") == true) then add(aura) end
        end
    end
    return result
end

local function has_visible_debuff(unit, spell_id)
    for _, debuff in pairs(visible_debuffs(unit)) do
        if aura_id(debuff) == spell_id then return true end
    end
    return false
end

local function has_poison_or_disease(unit)
    for _, debuff in pairs(visible_debuffs(unit)) do
        local kind = safe_field(debuff, "dispel_name") or safe_field(debuff, "dispelName")
            or safe_field(debuff, "dispel_type") or safe_field(debuff, "dispelType")
            or safe_field(debuff, "buff_type") or safe_field(debuff, "type")
        if type(kind) == "string" then
            kind = string.lower(kind)
            if kind == "poison" or kind == "disease" then return true end
        elseif enums.buff_type and (kind == enums.buff_type.POISON or kind == enums.buff_type.DISEASE) then
            return true
        end
    end
    return false
end

local function dispel_priority(unit)
    if is_pvp_mode() then
        for id in pairs(UNSTABLE_AFFLICTION) do
            if Aura.present(unit, id) then
                Telemetry.skip(SPELL.CLEANSE, unit, "dispel_backlash", "aura_id=" .. tostring(id))
                return 0
            end
        end
    end
    local debuffs = visible_debuffs(unit)
    local magic = enums.buff_type and enums.buff_type.MAGIC
    local poison = enums.buff_type and enums.buff_type.POISON
    local disease = enums.buff_type and enums.buff_type.DISEASE
    local improved = talent_selected(SPELL.IMPROVED_CLEANSE, "Improved Cleanse")
    local best, protected = 0, false
    for _, debuff in pairs(debuffs) do
        local spell_id = aura_id(debuff)
        local name = safe_field(debuff, "buff_name") or safe_field(debuff, "name") or safe_field(debuff, "spell_name")
            or safe_field(debuff, "spellName")
        local normalized_name = type(name) == "string" and string.lower(name) or ""
        if UNSTABLE_AFFLICTION[spell_id] or normalized_name:find("unstable affliction", 1, true) then
            protected = true
        end
        local kind = safe_field(debuff, "dispel_name") or safe_field(debuff, "dispelName")
            or safe_field(debuff, "dispel_type") or safe_field(debuff, "dispelType")
            or safe_field(debuff, "buff_type") or safe_field(debuff, "type")
        local eligible = kind ~= nil and ((magic ~= nil and kind == magic)
            or (improved and ((poison ~= nil and kind == poison)
                or (disease ~= nil and kind == disease))))
        if type(kind) == "string" then
            local normalized = string.lower(kind)
            eligible = normalized == "magic"
                or (improved and (normalized == "poison" or normalized == "disease"))
        end
        if eligible then
            local priority = 10
            if is_pvp_mode() then
                priority = PVP_DISPEL_PRIORITY[spell_id] or priority
                if normalized_name:find("polymorph", 1, true)
                    or normalized_name:find("hammer of justice", 1, true)
                    or normalized_name == "fear"
                    or normalized_name:find("psychic scream", 1, true)
                    or normalized_name:find("freezing trap", 1, true)
                    or normalized_name:find("repentance", 1, true)
                    or normalized_name == "dragon's breath"
                    or normalized_name == "sleep walk"
                    or normalized_name == "seduction" then
                    priority = math.max(priority, 95)
                end
            end
            best = math.max(best, priority)
        end
    end
    -- Cleanse removes all eligible effects at once. Never automate it while
    -- Unstable Affliction is present because its dispel backlash damages and
    -- silences the healer.
    if protected and is_pvp_mode() then return 0 end
    return best
end

local function run_auto_dispel(player, minimum_priority)
    if gui.auto_dispel:get_state() ~= true or not spell_known(SPELL.CLEANSE) then
        return false
    end
    local target, target_hp, target_priority = nil, 101, 0
    for _, unit in ipairs(group_units(player)) do
        local priority = can_heal(player, unit, SPELL.CLEANSE) and dispel_priority(unit) or 0
        if priority > 0 and priority >= (minimum_priority or 0) then
            local hp = health_percent(unit) or 100
            local guid = safe_call(unit, "get_guid") or tostring(unit)
            local velocity = health_history[guid] and health_history[guid].velocity or 0
            local objective = current_mode == "battleground"
                and safe_call(unit, "is_objective_carrier") == true
            local score = priority + math.min(30, velocity * 2) + (objective and 15 or 0)
            if score > target_priority or (score == target_priority and hp < target_hp) then
                target, target_hp, target_priority = unit, hp, score
            end
        end
    end
    if target and cast(SPELL.CLEANSE, target, player) then
        Telemetry.note("DISPEL", { "target=" .. tostring(safe_call(target, "get_name") or "ally"),
            "priority=" .. tostring(target_priority) })
        return true
    end
    return false
end

local mana_sample = { percent = nil, time = -math.huge, burn = 0 }
local function mana_percent(player)
    local current = safe_call(player, "get_power", MANA)
    local maximum = safe_call(player, "get_max_power", MANA)
    if type(current) == "number" and type(maximum) == "number" and maximum > 0 then
        local percent = current / maximum * 100
        local now = core.time()
        local combat = safe_call(player, "is_in_combat") == true
        local elapsed = now - (mana_sample.time or -math.huge)
        local burn = mana_sample.burn or 0
        if combat and mana_sample.percent and elapsed >= 0.25 and elapsed <= 5 then
            local instant = math.max(0, (mana_sample.percent - percent) / elapsed)
            burn = burn * 0.75 + instant * 0.25
        elseif not combat then
            burn = 0
        end
        if elapsed >= 0.25 or not mana_sample.percent then
            mana_sample = { percent = percent, time = now, burn = burn }
        end
        cooldown_budget.mana_burn = burn
        cooldown_budget.mana_forecast = math.max(0, percent - burn * 15)
        cooldown_budget.mana_time_to_critical = burn > 0.05
            and math.max(0, (percent - 20) / burn) or math.huge
        cooldown_budget.mana_planning_horizon = (current_mode == "mythic_plus"
            or current_mode == "arena") and 45 or current_mode == "battleground" and 35
            or current_mode == "delve" and 30 or 25
        cooldown_budget.mana_conserve = percent <= 30
            or cooldown_budget.mana_time_to_critical <= cooldown_budget.mana_planning_horizon
        return percent
    end
    return 100
end

local function is_drinking(player)
    for _, method in ipairs({ "get_buffs", "get_all_buffs" }) do
        local buffs = safe_call(player, method)
        if type(buffs) == "table" then
            for _, aura in pairs(buffs) do
                local name = safe_field(aura, "buff_name") or safe_field(aura, "name")
                    or safe_field(aura, "spell_name")
                name = type(name) == "string" and string.lower(name) or ""
                if string.find(name, "drink", 1, true)
                    or string.find(name, "refreshment", 1, true)
                    or string.find(name, "food and drink", 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

cooldown_budget.preserve_drink = function(player, units)
    if safe_call(player, "is_in_combat") == true or not is_drinking(player) then return false end
    local lowest = 100
    for _, unit in ipairs(units or {}) do
        local projected, current = predicted_health_percent(unit)
        -- Unknown health or an ally already fighting requires normal decisions.
        if not projected or not current or safe_call(unit, "is_in_combat") == true then return false end
        lowest = math.min(lowest, projected, current)
    end
    if lowest <= 35 then return false end
    local now = core.time()
    if now - (cooldown_budget.last_drink_log or -math.huge) >= 5 then
        cooldown_budget.last_drink_log = now
        Telemetry.note("RESOURCE", { "action=preserve_drink", "mode=" .. current_mode,
            "lowest_hp=" .. string.format("%.1f", lowest) })
    end
    return true
end

local function run_out_of_combat_topoff(player)
    local profile = profiles[current_mode]
    if gui.healing:get_state() ~= true or not profile or not profile.healing then return false end
    local target, target_hp = nil, 100
    for _, unit in ipairs(group_units(player)) do
        local hp = health_percent(unit)
        if hp and hp < target_hp and can_heal(player, unit, SPELL.HOLY_LIGHT) then
            target, target_hp = unit, hp
        end
    end
    -- Ignore only tiny rounding differences; continue healing until everyone
    -- is effectively full, scanning the group again after every cast.
    if not target or target_hp >= 99.5 then return false end

    if cooldown_budget.preserve_drink(player, group_units(player)) then return true end

    local holy_power = safe_call(player, "get_power", HOLY_POWER) or 0
    local spender = talent_selected(SPELL.ETERNAL_FLAME, "Eternal Flame")
        and SPELL.ETERNAL_FLAME or SPELL.WORD_OF_GLORY
    if (target_hp <= 65 or (target_hp <= 90 and Aura.present(player, SPELL.DIVINE_PURPOSE)))
        and cooldown_budget.healing_spender_ready(player, holy_power)
        and cast(spender, target, player) then return true end
    if target_hp <= 90 and cast(SPELL.HOLY_SHOCK, target, player) then return true end
    if Aura.present(player, SPELL.INFUSION_OF_LIGHT)
        and cast(SPELL.FLASH_OF_LIGHT, target, player) then return true end
    if target_hp <= 55 and mana_percent(player) > 5
        and cast(SPELL.FLASH_OF_LIGHT, target, player) then return true end
    if cooldown_budget.healing_spender_ready(player, holy_power) and cast(spender, target, player) then return true end
    if mana_percent(player) > 5 and cast(SPELL.HOLY_LIGHT, target, player) then return true end
    return false
end

local function is_holy_paladin(player)
    if safe_call(player, "get_class") ~= PALADIN then return false end
    if not HOLY_SPEC then return false end
    local raw_ok, raw = pcall(function()
        return safe_call(player, "get_specialization_id")
            or core.spell_book.get_specialization_id()
    end)
    if not raw_ok then return false end
    if raw == HOLY_SPEC then return true end
    local ok, value = pcall(enums.class_spec_id.get_specialization_enum, PALADIN, raw)
    return ok and value == HOLY_SPEC
end

local last_defensive = -math.huge
local last_beacon_virtue_confirmed = -math.huge
local next_fishing_action = 0
local last_fishing_cast = -math.huge
local next_looting_attempt = 0
local looting_busy_until = 0
local recently_looted = {}
local last_aura_attempt, last_aura_cast_request, last_aura_spell = -math.huge, -math.huge, nil
local next_auto_face_at = 0
local next_auto_target_at = 0
local beacon_confirmed = {}
local own_aura_confirmed = { spell_id = nil, time = -math.huge }
local moving_since_steed, last_steed_success = nil, -math.huge
local last_confirmation = { key = nil, time = -math.huge }

local HEALING_SPELL = {
    [SPELL.HOLY_SHOCK] = true, [SPELL.WORD_OF_GLORY] = true,
    [SPELL.FLASH_OF_LIGHT] = true, [SPELL.HOLY_LIGHT] = true,
    [SPELL.ETERNAL_FLAME] = true, [SPELL.LAY_ON_HANDS] = true,
}
local MAJOR_COOLDOWN = {
    [SPELL.AVENGING_WRATH] = true, [SPELL.AVENGING_CRUSADER] = true,
    [SPELL.AURA_MASTERY] = true, [SPELL.DIVINE_TOLL] = true,
    [SPELL.HOLY_BULWARK] = true, [SPELL.SACRED_WEAPON] = true,
}
local EXTERNAL_COOLDOWN = {
    [SPELL.BLESSING_OF_SACRIFICE] = true, [SPELL.BLESSING_OF_PROTECTION] = true,
    [SPELL.BLESSING_OF_SPELLWARDING] = true, [SPELL.LAY_ON_HANDS] = true,
}

local function adaptive_offset(mode)
    local row = adaptive_by_mode[mode]
    return row and row.samples >= 6 and row.offset or 0
end

local function observe_outcomes()
    local now = core.time()
    for i = #pending_outcomes, 1, -1 do
        local row = pending_outcomes[i]
        if now >= row.observe_at then
            local after = health_percent(row.target)
            if after and row.before then
                local delta = after - row.before
                local stable = after >= row.before - 2 or after >= 75
                local learned = adaptive_by_mode[row.mode] or { samples = 0, offset = 0 }
                learned.samples = learned.samples + 1
                if not stable or after < 35 then
                    learned.offset = math.min(5, learned.offset + 0.5)
                elseif row.before >= 82 and after >= 98 then
                    learned.offset = math.max(-3, learned.offset - 0.2)
                end
                adaptive_by_mode[row.mode] = learned
                Telemetry.outcome({ spell_id = row.spell_id, target = row.target,
                    before = row.before, after = after, delta = delta,
                    elapsed = now - row.started, stabilized = stable,
                    mode = row.mode, adaptive = learned.offset })
            end
            table.remove(pending_outcomes, i)
        end
    end
end


local function budget_ready(kind, emergency)
    if emergency then return true end
    local window = kind == "major" and 4.0 or 3.0
    return core.time() - (cooldown_budget[kind] or -math.huge) >= window
end

local function confirm_player_spell(spell_id, target)
    local player = core.object_manager.get_local_player()
    if not player then return end
    local confirmation_key = tostring(spell_id) .. ":" ..
        tostring(target and (safe_call(target, "get_guid") or target) or "-")
    if last_confirmation.key == confirmation_key
        and core.time() - last_confirmation.time < 0.10 then return end
    last_confirmation = { key = confirmation_key, time = core.time() }
    Aura.on_spell_cast({ spell_id = spell_id, caster = player, target = target })
    if spell_id == SPELL.DEVOTION_AURA or spell_id == SPELL.CONCENTRATION_AURA
        or spell_id == SPELL.CRUSADER_AURA then
        own_aura_confirmed = { spell_id = spell_id, time = core.time() }
    end
    if spell_id == SPELL.BEACON_OF_VIRTUE then last_beacon_virtue_confirmed = core.time() end
    if target and (spell_id == SPELL.BEACON_OF_LIGHT or spell_id == SPELL.BEACON_OF_FAITH) then
        beacon_confirmed[spell_id] = { guid = safe_call(target, "get_guid") or tostring(target), time = core.time() }
    end
    if MAJOR_COOLDOWN[spell_id] then
        cooldown_budget.major = core.time()
        Telemetry.note("COOLDOWN", { "group=major", "spell_id=" .. tostring(spell_id) })
    elseif EXTERNAL_COOLDOWN[spell_id] then
        cooldown_budget.external = core.time()
        Telemetry.note("COOLDOWN", { "group=external", "spell_id=" .. tostring(spell_id) })
    elseif spell_id == SPELL.DIVINE_SHIELD then
        cooldown_budget.immunity = core.time()
        Telemetry.note("COOLDOWN", { "group=immunity", "spell_id=" .. tostring(spell_id) })
    end
    if HEALING_SPELL[spell_id] and pending_cast
        and pending_cast.spell_id == spell_id
        and pending_cast.health_before and valid(pending_cast.target) then
        -- Learn only from the exact direct-heal request that completed. Group
        -- spells and unrelated/manual confirmations cannot tune thresholds
        -- using the wrong unit's health change.
        pending_outcomes[#pending_outcomes + 1] = { spell_id = spell_id, target = pending_cast.target,
            before = pending_cast.health_before, started = pending_cast.requested_at or core.time(),
            observe_at = core.time() + 0.85, mode = current_mode }
    end
end

local function own_aura_active(player, spell_id)
    -- Another Paladin's group aura can also appear on this player. Only our
    -- selected aura determines what our Aura Mastery empowers.
    for _, aura_spell in ipairs({ SPELL.DEVOTION_AURA, SPELL.CONCENTRATION_AURA, SPELL.CRUSADER_AURA }) do
        if Aura.present_from(player, aura_spell, player) then
            own_aura_confirmed = { spell_id = aura_spell, time = core.time() }
            return aura_spell == spell_id
        end
    end
    return own_aura_confirmed.spell_id == spell_id
        and core.time() - own_aura_confirmed.time < 600
end

local function is_tank_role(unit)
    local role = safe_call(unit, "get_group_role") or safe_call(unit, "get_role")
    if type(role) == "number" and enums.group_role then return role == enums.group_role.TANK end
    return type(role) == "string" and string.find(string.lower(role), "tank", 1, true) ~= nil
end

local function is_ranged_role(unit)
    local role = safe_call(unit, "get_group_role") or safe_call(unit, "get_role")
    return type(role) == "string" and string.find(string.lower(role), "ranged", 1, true) ~= nil
end

local function run_auto_persistent_beacons(player, pressure)
    if gui.auto_beacon:get_state() ~= true
        or talent_selected(SPELL.BEACON_OF_VIRTUE, "Beacon of Virtue")
        or not spell_known(SPELL.BEACON_OF_LIGHT) then return false end

    local faith = talent_selected(SPELL.BEACON_OF_FAITH, "Beacon of Faith")
    local candidates = {}
    for _, unit in ipairs(group_units(player)) do
        if unit ~= player and can_heal(player, unit, SPELL.BEACON_OF_LIGHT) then
            local max_health = safe_call(unit, "get_max_health")
            if type(max_health) ~= "number" then max_health = 0 end
            candidates[#candidates + 1] = {
                unit = unit,
                ranged = is_ranged_role(unit),
                tank = is_tank_role(unit),
                max_health = max_health,
                guid = safe_call(unit, "get_guid") or tostring(unit),
                pressure = 0,
            }
            local candidate = candidates[#candidates]
            local focus = pressure and pressure.targets and pressure.targets[candidate.guid]
            if focus then
                candidate.pressure = (focus.count or 0) * 25
                    + (focus.burst and 40 or 0) + (focus.swap and 50 or 0)
            end
        end
    end
    table.sort(candidates, function(a, b)
        if is_pvp_mode() and a.pressure ~= b.pressure then return a.pressure > b.pressure end
        if current_mode == "mythic_plus" or current_mode == "delve" then
            if a.tank ~= b.tank then return a.tank end
            if a.ranged ~= b.ranged then return a.ranged end
        else
            if a.ranged ~= b.ranged then return a.ranged end
            if a.tank ~= b.tank then return not a.tank end
        end
        -- When role metadata is unavailable, lower max health is a useful
        -- proxy for a squishier ranged ally; avoid defaulting every Beacon to tank.
        return a.max_health < b.max_health
    end)

    -- Move Beacon during the short safe window after an enemy swap, or once
    -- the opening kill target has remained focused long enough to be more than
    -- a transient target selection. Faith stays on its separate ally; Virtue
    -- builds use their temporary multi-target window instead of this path.
    if is_pvp_mode() and pressure and pressure.targets then
        local pressure_candidate, pressure_score = nil, -math.huge
        for _, candidate in ipairs(candidates) do
            local focus = pressure.targets[candidate.guid]
            local confirmed_faith = beacon_confirmed[SPELL.BEACON_OF_FAITH]
            local own_faith = faith and (Aura.present_from(candidate.unit, SPELL.BEACON_OF_FAITH, player)
                or (confirmed_faith and confirmed_faith.guid == candidate.guid
                    and core.time() - confirmed_faith.time < 600))
            -- A swap onto our Faith target is already covered. Moving Light
            -- there would collapse two distinct Beacon assignments into one.
            local confirmed_focus = focus and (focus.swap == true
                or focus.burst == true or (focus.count or 0) >= 2
                or (focus.focus_age or 0) >= 1.0)
            if confirmed_focus and not own_faith then
                local hp = health_percent(candidate.unit) or 100
                local score = (focus.count or 0) * 25 + (focus.burst and 40 or 0) - hp * 0.1
                if score > pressure_score then
                    pressure_candidate, pressure_score = candidate, score
                end
            end
        end
        if pressure_candidate
            and not Aura.present_from(pressure_candidate.unit, SPELL.BEACON_OF_LIGHT, player)
            and cast(SPELL.BEACON_OF_LIGHT, pressure_candidate.unit, player) then
            Telemetry.note("PREVENTION", { "action=beacon_follow_enemy_pressure",
                "target=" .. tostring(safe_call(pressure_candidate.unit, "get_name") or "ally") })
            return true
        end
    end

    local now = core.time()
    local slots = { SPELL.BEACON_OF_LIGHT }
    if faith then slots[#slots + 1] = SPELL.BEACON_OF_FAITH end
    local assigned = {}
    for _, spell_id in ipairs(slots) do
        for _, candidate in ipairs(candidates) do
            local own = Aura.present_from(candidate.unit, spell_id, player)
            local confirmed = beacon_confirmed[spell_id]
            if own or (confirmed and confirmed.guid == candidate.guid and now - confirmed.time < 600) then
                assigned[spell_id] = candidate.guid
                if own then beacon_confirmed[spell_id] = { guid = candidate.guid, time = now } end
                break
            end
        end
    end
    for _, spell_id in ipairs(slots) do
        if not assigned[spell_id] then
            for _, candidate in ipairs(candidates) do
                local taken = false
                for _, guid in pairs(assigned) do if guid == candidate.guid then taken = true end end
                if not taken and cast(spell_id, candidate.unit, player) then return true end
            end
        end
    end
    return false
end

local function run_auto_target(player, pressure)
    if gui.auto_target:get_state() ~= true or not core.input or not core.input.set_target
        or safe_call(player, "is_in_combat") ~= true then return end
    local current = safe_call(player, "get_target")
    local current_visible = true
    if valid(current) and core.graphics and type(core.graphics.is_line_of_sight) == "function" then
        local los_ok, visible = pcall(core.graphics.is_line_of_sight, player, current)
        if los_ok and visible == false then current_visible = false end
    end
    if cooldown_budget.safe_to_damage(player, current) and distance(player, current) <= 40
        and current_visible then return end
    local now = core.time()
    if now < next_auto_target_at then return end
    next_auto_target_at = now + 0.15
    local best, best_score = nil, -math.huge
    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return end
    for _, object in pairs(objects) do
        if valid(object) and safe_call(object, "is_unit") == true
            and safe_call(player, "can_attack", object) == true then
            local d = distance(player, object)
            local victim = safe_call(object, "get_target")
            local victim_guid = victim and (safe_call(victim, "get_guid") or tostring(victim))
            local focus = victim_guid and pressure and pressure.targets
                and pressure.targets[victim_guid]
            local engaged = safe_call(object, "is_in_combat") == true or focus ~= nil
            local visible = true
            if core.graphics and type(core.graphics.is_line_of_sight) == "function" then
                local los_ok, line_of_sight = pcall(core.graphics.is_line_of_sight, player, object)
                if los_ok and line_of_sight == false then visible = false end
            end
            if engaged and visible and d <= 40
                and not cooldown_budget.enemy_has_breakable_control(object) then
                local score = 40 - d
                if safe_call(object, "is_casting_spell") == true
                    and safe_call(object, "is_active_spell_interruptable") == true then
                    score = score + 45
                    local spell_id = tonumber(safe_call(object, "get_active_spell_id"))
                    if spell_id and read_core(core.spell_book.is_important_spell, spell_id) == true then
                        score = score + 80
                    end
                end
                if focus then
                    score = score + focus.count * 20 + (focus.burst and 35 or 0)
                end
                if score > best_score then best, best_score = object, score end
            end
        end
    end
    if best then
        local call_ok, accepted = pcall(core.input.set_target, best)
        if not call_ok or accepted == false then return false end
        next_auto_target_at = now + 0.5
        Telemetry.note("UTILITY", { "action=auto_target_priority",
            "target=" .. tostring(safe_call(best, "get_name") or "enemy"),
            "score=" .. string.format("%.1f", best_score) })
        return true
    end
    return false
end

local function run_auto_face(player)
    if gui.auto_face:get_state() ~= true or not core.input or not core.input.look_at
        or safe_call(player, "is_in_combat") ~= true then return end
    local target = safe_call(player, "get_target")
    if not valid(target) or safe_call(player, "can_attack", target) ~= true then return end
    local target_position = safe_call(target, "get_position")
    if not target_position then return end
    local now = core.time()
    if now < next_auto_face_at then return end
    next_auto_face_at = now + 0.10
    pcall(core.input.look_at, target_position)
end

local function another_paladin_has_devotion(player)
    local player_guid = safe_call(player, "get_guid")
    for _, unit in ipairs(group_units(player)) do
        local guid = safe_call(unit, "get_guid")
        local is_self = unit == player or (player_guid and guid == player_guid)
        if not is_self and safe_call(unit, "get_class") == PALADIN
            and Aura.present_from(unit, SPELL.DEVOTION_AURA, unit) then
            return true
        end
    end
    return false
end

local function run_auto_aura(player, combat)
    if gui.auto_aura:get_state() ~= true then return false end
    local mounted = safe_call(player, "is_mounted") == true
    local desired = SPELL.DEVOTION_AURA
    if combat then
        desired = spell_known(SPELL.CONCENTRATION_AURA)
            and another_paladin_has_devotion(player) and SPELL.CONCENTRATION_AURA
            or SPELL.DEVOTION_AURA
    elseif mounted and spell_known(SPELL.CRUSADER_AURA) then
        desired = SPELL.CRUSADER_AURA
    elseif spell_known(SPELL.CONCENTRATION_AURA)
        and another_paladin_has_devotion(player) then
        desired = SPELL.CONCENTRATION_AURA
    end
    if own_aura_active(player, desired) then
        return false
    end
    local now = core.time()
    if last_aura_spell == desired then
        if now - last_aura_cast_request < 8 then return false end
        if now - last_aura_attempt < 1.5 then return false end
    end
    last_aura_spell = desired
    last_aura_attempt = now
    if cast(desired, player, player) then
        last_aura_cast_request = now
        return true
    end
    return false
end

local function pvp_healing_urgent(player, units, pressure, profile)
    if not is_pvp_mode() or not profile then return false end
    local target, hp = select_injured(player, units, pressure)
    if not target or not hp then return false end
    local threshold = profile.heal_at + 5
    local guid = safe_call(target, "get_guid") or tostring(target)
    local focus = pressure and pressure.targets and pressure.targets[guid]
    if focus and focus.burst then threshold = profile.heal_at + 12 end
    if focus and focus.count >= 2 then threshold = math.max(threshold, profile.heal_at + 10) end
    if focus and focus.swap then threshold = math.max(threshold, profile.heal_at + 8) end
    return hp <= threshold
end

local function dampening_percent(player)
    local auras = safe_call(player, "get_auras")
    if type(auras) ~= "table" then return 0 end
    local dampening = 0
    cooldown_budget.darkest_stacks = 0
    for _, aura in pairs(auras) do
        local name = safe_field(aura, "name") or safe_field(aura, "buff_name")
            or safe_field(aura, "debuff_name")
        local lower_name = type(name) == "string" and string.lower(name) or ""
        if aura_id(aura) == SPELL.DARKEST_BEFORE_DAWN
            or lower_name == "darkest before the dawn" then
            cooldown_budget.darkest_stacks = tonumber(safe_field(aura, "stacks")
                or safe_field(aura, "count") or safe_field(aura, "applications")) or 1
        elseif string.find(lower_name, "dampening", 1, true) then
            local points = safe_field(aura, "points")
            local point = type(points) == "table" and tonumber(points[1]) or nil
            local value = tonumber(safe_field(aura, "value") or safe_field(aura, "amount")
                or safe_field(aura, "stacks") or safe_field(aura, "count")
                or safe_field(aura, "applications")) or point
            dampening = math.max(0, math.min(100, value or 0))
        end
    end
    return dampening
end

local function dungeon_forecast(player, units)
    local result = { active = false, seconds = 99, group = false, target = nil,
        spell_id = nil, source = nil, learned = false, confidence = 0,
        exposed_target = nil, exposed_attackers = 0 }
    if current_mode ~= "mythic_plus" and current_mode ~= "delve"
        and current_mode ~= "world_pvp" then return result end
    local friendly = {}
    for _, unit in ipairs(units or {}) do
        friendly[safe_call(unit, "get_guid") or tostring(unit)] = unit
    end
    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return result end
    local now = core.time()
    local threat_counts = {}
    cooldown_budget.cast_patterns = cooldown_budget.cast_patterns or {}
    for _, enemy in pairs(objects) do
        if valid(enemy) and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 60 then
            local committed = safe_call(enemy, "get_target")
            local committed_guid = committed and (safe_call(committed, "get_guid") or tostring(committed))
            if committed_guid and friendly[committed_guid] then
                threat_counts[committed_guid] = (threat_counts[committed_guid] or 0) + 1
            end
        end
        if valid(enemy) and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 60
            and (safe_call(enemy, "is_casting_spell") == true
                or safe_call(enemy, "is_channelling_spell") == true
                or safe_call(enemy, "is_channeling_spell") == true) then
            local channel = safe_call(enemy, "is_channelling_spell") == true
                or safe_call(enemy, "is_channeling_spell") == true
            local spell_id = tonumber(channel and (safe_call(enemy, "get_active_channel_spell_id")
                or safe_call(enemy, "get_active_channel_id")) or safe_call(enemy, "get_active_spell_id"))
            local important = spell_id and read_core(core.spell_book.is_important_spell, spell_id) == true
            if important then
                local cast_target = safe_call(enemy, "get_active_spell_target")
                local target = cast_target and friendly[safe_call(cast_target, "get_guid") or tostring(cast_target)]
                local source_guid = safe_call(enemy, "get_guid") or tostring(enemy)
                local pattern_key = tostring(source_guid) .. ":" .. tostring(spell_id)
                local pattern = cooldown_budget.cast_patterns[pattern_key]
                    or { samples = 0, interval = 0, last_start = nil, last_seen = -math.huge }
                if now - (pattern.last_seen or -math.huge) > 0.8 then
                    if pattern.last_start then
                        local interval = now - pattern.last_start
                        if interval >= 4 and interval <= 45 then
                            -- A phase change or delayed recast is not a dependable
                            -- periodic timer. Require new consistent observations.
                            if pattern.samples > 0 and math.abs(interval - pattern.interval)
                                > math.max(2, pattern.interval * 0.25) then
                                pattern.samples, pattern.interval = 0, 0
                            end
                            pattern.interval = pattern.samples > 0
                                and pattern.interval * 0.65 + interval * 0.35 or interval
                            pattern.samples = math.min(5, pattern.samples + 1)
                        else
                            pattern.samples, pattern.interval = 0, 0
                        end
                    end
                    pattern.last_start = now
                end
                pattern.last_seen, pattern.source, pattern.spell_id = now, enemy, spell_id
                pattern.target_guid = target and (safe_call(target, "get_guid") or tostring(target)) or nil
                cooldown_budget.cast_patterns[pattern_key] = pattern
                local finish = tonumber(channel and (safe_call(enemy, "get_active_channel_cast_end_time")
                    or safe_call(enemy, "get_active_channel_end_time")) or safe_call(enemy, "get_active_spell_cast_end_time"))
                local seconds = 1.5
                if finish then
                    -- Accept a plausible future timestamp, including milliseconds
                    -- early in a session; never interpret stale data as impact now.
                    local milliseconds, raw = finish / 1000 - now, finish - now
                    if milliseconds >= 0 and milliseconds <= 60 then seconds = milliseconds
                    elseif raw >= 0 and raw <= 60 then seconds = raw end
                end
                if seconds < result.seconds then
                    result = { active = true, seconds = seconds, group = target == nil,
                        target = target, spell_id = spell_id, source = enemy,
                        learned = false, confidence = 1 }
                end
            end
        end
    end
    -- After observing three casts from the same enemy, use the smoothed interval
    -- as a short pre-cast warning. The narrow window and missed-timer expiry keep
    -- phase changes, interrupts, and dead enemies from becoming stale forecasts.
    if not result.active then
        for key, pattern in pairs(cooldown_budget.cast_patterns) do
            local age = now - (pattern.last_seen or now)
            if not valid(pattern.source) or safe_call(pattern.source, "is_in_combat") ~= true
                or age > 50 then
                cooldown_budget.cast_patterns[key] = nil
            elseif (pattern.samples or 0) >= 2 and (pattern.interval or 0) >= 4 then
                local seconds = pattern.last_start + pattern.interval - now
                if seconds >= 0.2 and seconds <= 2.5 and seconds < result.seconds then
                    local target = pattern.target_guid and friendly[pattern.target_guid] or nil
                    result = { active = true, seconds = seconds, group = target == nil,
                        target = target, spell_id = pattern.spell_id, source = pattern.source,
                        learned = true, confidence = math.min(1, pattern.samples / 4) }
                elseif seconds < -1.5 then
                    pattern.samples = math.max(0, pattern.samples - 1)
                    pattern.last_start = now
                end
            end
        end
    end
    for guid, count in pairs(threat_counts) do
        if count > (result.exposed_attackers or 0) then
            result.exposed_target, result.exposed_attackers = friendly[guid], count
        end
    end
    return result
end

local function run_pre_damage_setup(player, units, forecast)
    if current_mode ~= "mythic_plus" and current_mode ~= "delve"
        and current_mode ~= "world_pvp" then return false end
    if not forecast.active or forecast.seconds > 1.8
        or gui.healing_cooldowns:get_state() ~= true
        or not profiles[current_mode] or profiles[current_mode].cooldowns ~= true then return false end
    local target = forecast.target
    if not target then
        for _, unit in ipairs(units) do
            if is_tank_role(unit) and can_heal(player, unit, SPELL.HOLY_SHOCK) then target = unit; break end
        end
    end
    target = target or player
    if not is_pvp_mode() and gui.interrupt:get_state() == true and forecast.source
        and safe_call(forecast.source, "is_active_spell_interruptable") == true
        and distance(player, forecast.source) <= 10 then
        if distance(player, forecast.source) <= 8
            and cast(SPELL.REBUKE, forecast.source, player, false, true) then
            Telemetry.note("PREVENTION", { "action=forecast_rebuke",
                "spell_id=" .. tostring(forecast.spell_id),
                "impact=" .. string.format("%.2f", forecast.seconds) })
            return true
        end
        if forecast.seconds <= 1.0
            and cast(SPELL.HAMMER_OF_JUSTICE, forecast.source, player) then
            Telemetry.note("PREVENTION", { "action=forecast_stun_backup",
                "spell_id=" .. tostring(forecast.spell_id),
                "impact=" .. string.format("%.2f", forecast.seconds) })
            return true
        end
    end
    -- Preparation must not consume the GCD needed to recover an ally who is
    -- already critical. A confirmed interrupt above can prevent the hit itself.
    for _, unit in ipairs(units or {}) do
        local projected, current, _, time_to_danger = predicted_health_percent(unit)
        if current and can_heal(player, unit, SPELL.HOLY_SHOCK)
            and (current <= math.max(24, cooldown_budget.emergency_threshold())
                or (projected and projected <= cooldown_budget.emergency_threshold())
                or time_to_danger <= 2.0) then return false end
    end
    if forecast.target and talent_selected(SPELL.BARRIER_OF_FAITH, "Barrier of Faith")
        and not Aura.present(target, SPELL.BARRIER_OF_FAITH_ABSORB)
        and cast(SPELL.BARRIER_OF_FAITH, target, player) then
        Telemetry.note("FORECAST", { "action=barrier_of_faith", "spell_id=" .. tostring(forecast.spell_id),
            "impact=" .. string.format("%.2f", forecast.seconds) })
        return true
    end
    if forecast.target and target ~= player
        and gui.personals:get_state() == true
        and can_heal(player, target, SPELL.BLESSING_OF_SACRIFICE)
        and not Aura.present(target, SPELL.BLESSING_OF_SACRIFICE)
        and (health_percent(player) or 100) >= 65 then
        local projected, current, incoming = predicted_health_percent(target)
        local self_projected, _, _, self_time_to_danger = predicted_health_percent(player)
        if ((incoming or 0) >= 8 or (projected or current or 100) <= 72)
            and (not self_projected or self_projected > 48)
            and self_time_to_danger > 2.5
            and budget_ready("external", false)
            and cast(SPELL.BLESSING_OF_SACRIFICE, target, player) then
            Telemetry.note("FORECAST", { "action=preemptive_sacrifice",
                "spell_id=" .. tostring(forecast.spell_id),
                "impact=" .. string.format("%.2f", forecast.seconds),
                "incoming_pct=" .. string.format("%.1f", incoming or 0) })
            return true
        end
    end
    if forecast.group and own_aura_active(player, SPELL.DEVOTION_AURA)
        and budget_ready("major", false)
        and cast(SPELL.AURA_MASTERY, player, player) then
        Telemetry.note("FORECAST", { "action=aura_mastery", "spell_id=" .. tostring(forecast.spell_id),
            "impact=" .. string.format("%.2f", forecast.seconds) })
        return true
    end
    if forecast.group and gui.auto_beacon:get_state() == true
        and talent_selected(SPELL.BEACON_OF_VIRTUE, "Beacon of Virtue")
        and core.time() - last_beacon_virtue_confirmed >= 7.5
        and cast(SPELL.BEACON_OF_VIRTUE, target, player) then
        Telemetry.note("FORECAST", { "action=beacon_of_virtue", "spell_id=" .. tostring(forecast.spell_id),
            "impact=" .. string.format("%.2f", forecast.seconds) })
        return true
    end
    return false
end

local function run_pvp_cc_recovery(player, units, pressure, profile)
    if gui.personals:get_state() ~= true
        or not is_pvp_mode() or not pvp_helper or type(pvp_helper.is_crowd_controlled) ~= "function"
        or Aura.present(player, SPELL.FORBEARANCE) then return false end
    local ok, controlled, _, remaining = pcall(pvp_helper.is_crowd_controlled, pvp_helper, player, nil, 700)
    if not ok or controlled ~= true or (tonumber(remaining) or 0) < 700 then return false end
    local target, projected = select_injured(player, units, pressure)
    if not target or target == player then return false end
    local current = health_percent(target) or projected or 100
    local guid = safe_call(target, "get_guid") or tostring(target)
    local focus = pressure.targets and pressure.targets[guid]
    local lethal = current <= 24 or (projected and projected <= 18)
        or (focus and focus.burst and current <= 42)
    local flags = pvp_helper.cc_flags or {}
    local player_guid = safe_call(player, "get_guid") or tostring(player)
    local self_focus = pressure.targets and pressure.targets[player_guid]
    local physical_pressure = self_focus and ((self_focus.physical_attackers or 0) >= 1
        or (self_focus.melee_attackers or 0) >= 1)
    local stunned = false
    if flags.STUN then
        local stun_ok, value = pcall(pvp_helper.is_crowd_controlled,
            pvp_helper, player, flags.STUN, 700)
        stunned = stun_ok and value == true
    end
    -- Break a confirmed physical stun with Protection before spending the
    -- full immunity. Spellwarding replaces this physical interaction.
    if lethal and stunned and physical_pressure
        and not talent_selected(SPELL.BLESSING_OF_SPELLWARDING, "Blessing of Spellwarding")
        and budget_ready("external", true)
        and cast(SPELL.BLESSING_OF_PROTECTION, player, player) then
        Telemetry.note("RECOVERY", { "action=bop_break_physical_stun",
            "ally=" .. tostring(safe_call(target, "get_name") or "ally"),
            "ally_hp=" .. string.format("%.1f", current) })
        return true
    end
    if lethal and budget_ready("immunity", true) and cast(SPELL.DIVINE_SHIELD, player, player) then
        Telemetry.note("RECOVERY", { "action=divine_shield_break_cc",
            "ally=" .. tostring(safe_call(target, "get_name") or "ally"),
            "ally_hp=" .. string.format("%.1f", current) })
        return true
    end
    return false
end

local function run_auto_freedom(player, units, pressure, profile)
    if not is_pvp_mode() or not spell_known(SPELL.BLESSING_OF_FREEDOM)
        or pvp_healing_urgent(player, units, pressure, profile)
        or not pvp_helper or type(pvp_helper.is_slow) ~= "function" then return false end
    local best, score, slowed = nil, -math.huge, 0
    for _, unit in ipairs(units) do
        local ok, value = pcall(pvp_helper.is_slow, pvp_helper, unit, 0.70, 700)
        local rooted = false
        if type(pvp_helper.is_rooted) == "function" then
            local root_ok, root_value = pcall(pvp_helper.is_rooted, pvp_helper, unit, 700)
            rooted = root_ok and root_value == true
        end
        if ((ok and value == true) or rooted)
            and not Aura.present(unit, SPELL.BLESSING_OF_FREEDOM)
            and can_heal(player, unit, SPELL.BLESSING_OF_FREEDOM) then
            slowed = slowed + 1
            local guid = safe_call(unit, "get_guid") or tostring(unit)
            local focus = pressure.targets and pressure.targets[guid]
            local unit_score = (unit == player and 10 or 0) + (focus and focus.count * 25 or 0)
                + (focus and focus.burst and 30 or 0) + (safe_call(unit, "is_moving") == true and 15 or 0)
                + (rooted and 25 or 0)
            if current_mode == "battleground" then
                local native_objective = safe_call(unit, "is_objective_carrier") == true
                if native_objective then
                    unit_score = unit_score + 60
                end
                local buffs = safe_call(unit, "get_buffs") or safe_call(unit, "get_auras")
                for _, aura in pairs(type(buffs) == "table" and buffs or {}) do
                    local name = safe_field(aura, "buff_name") or safe_field(aura, "name")
                        or safe_field(aura, "spell_name")
                    name = type(name) == "string" and string.lower(name) or ""
                    if name == "alliance flag" or name == "horde flag"
                        or name == "netherstorm flag" or name == "orb of power"
                        or string.find(name, "flag carrier", 1, true) then
                        if not native_objective then unit_score = unit_score + 60 end
                        break
                    end
                end
            end
            if unit_score > score then best, score = unit, unit_score end
        end
    end
    if best and (score >= 15 or (slowed >= 2
        and talent_selected(SPELL.SPREADING_THE_WORD, "Spreading the Word")))
        and cast(SPELL.BLESSING_OF_FREEDOM, best, player) then
        Telemetry.note("UTILITY", { "action=blessing_of_freedom", "slowed_allies=" .. slowed,
            "target=" .. tostring(safe_call(best, "get_name") or "ally") })
        return true
    end
    return false
end

local function pvp_defensive_active(unit, damage_type)
    if not pvp_helper then return false end
    if type(pvp_helper.is_damage_immune) == "function" then
        local ok, immune = pcall(pvp_helper.is_damage_immune, pvp_helper, unit, damage_type, 700)
        if ok and immune == true then return true end
    end
    if type(pvp_helper.has_damage_reduction) == "function" then
        local ok, reduced = pcall(pvp_helper.has_damage_reduction, pvp_helper, unit, 30, damage_type, 700)
        if ok and reduced == true then return true end
    end
    return false
end

cooldown_budget.run_pvp_self_aura_mastery = function(player, current, focus, profile, recent_defensive)
    if not is_pvp_mode() or not profile or profile.cooldowns ~= true
        or gui.healing_cooldowns:get_state() ~= true or not focus
        or not own_aura_active(player, SPELL.DEVOTION_AURA) then return false end
    local damage_window = (focus.burst == true and current <= 62)
        or ((focus.count or 0) >= 2 and current <= 48)
    if not damage_window then return false end
    local lethal = current <= 25
    if not lethal and core.time() - (recent_defensive or -math.huge) <= 3 then return false end
    if talent_selected(SPELL.DIVINE_PLEA, "Divine Plea") and not lethal then
        Telemetry.skip(SPELL.AURA_MASTERY, player, "divine_plea_healing_penalty",
            "reserve_self_aura_mastery_for_lethal_pressure")
        return false
    end
    local flags = pvp_helper and pvp_helper.damage_type_flags or {}
    if not lethal and pvp_defensive_active(player, flags.ANY) then return false end
    if budget_ready("major", lethal) and cast(SPELL.AURA_MASTERY, player, player) then
        Telemetry.note("PREVENTION", { "action=self_burst_aura_mastery",
            "self_hp=" .. string.format("%.1f", current),
            "attackers=" .. tostring(focus.count or 0),
            "burst=" .. tostring(focus.burst == true) })
        return true
    end
    return false
end

cooldown_budget.enemy_interrupt_ready = function(player, friend)
    if not pvp_helper then return false end
    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return false end
    for _, enemy in pairs(objects) do
        if valid(enemy) and safe_call(enemy, "is_player") == true
            and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true
            and distance(enemy, friend or player) <= 40 then
            for _, method in ipairs({ "has_interrupt_available", "is_interrupt_ready", "can_interrupt" }) do
                if type(pvp_helper[method]) == "function" then
                    local call_ok, ready
                    if method == "can_interrupt" then
                        call_ok, ready = pcall(pvp_helper[method], pvp_helper, enemy, friend or player, 500)
                    else
                        call_ok, ready = pcall(pvp_helper[method], pvp_helper, enemy, 500)
                    end
                    if call_ok and ready == true then return true end
                end
            end
        end
    end
    return false
end

local function run_pvp_sacrifice_cc_break(player, units, pressure)
    if not is_pvp_mode() or not spell_known(SPELL.BLESSING_OF_SACRIFICE)
        or (health_percent(player) or 100) <= 55
        or Aura.present(player, SPELL.DIVINE_SHIELD) then return false end
    for _, unit in ipairs(units or {}) do
        local projected, current = predicted_health_percent(unit)
        if can_heal(player, unit, SPELL.HOLY_SHOCK)
            and ((current and current <= 35)
                or (projected and projected <= cooldown_budget.emergency_threshold())) then
            Telemetry.skip(SPELL.BLESSING_OF_SACRIFICE, unit, "cc_prevention_yields_to_healing")
            return false
        end
    end
    local self_projected, _, _, self_ttd = predicted_health_percent(player)
    if (self_projected and self_projected <= 48) or self_ttd <= 2.5 then return false end
    local player_guid = safe_call(player, "get_guid")
    local incoming_cc, caster = nil, nil
    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return false end
    for _, enemy in pairs(objects) do
        if valid(enemy) and safe_call(enemy, "is_player") == true
            and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_casting_spell") == true then
            local spell_id = tonumber(safe_call(enemy, "get_active_spell_id"))
            local target = safe_call(enemy, "get_active_spell_target")
            if BREAKABLE_CC_CAST[spell_id]
                and target and safe_call(target, "get_guid") == player_guid then
                incoming_cc, caster = spell_id, enemy
                break
            end
        end
    end
    if not incoming_cc then return false end
    local best, best_score = nil, -math.huge
    for _, unit in ipairs(units) do
        if unit ~= player and not Aura.present(unit, SPELL.BLESSING_OF_SACRIFICE)
            and not Aura.present(unit, SPELL.DIVINE_SHIELD)
            and not Aura.present(unit, SPELL.BLESSING_OF_PROTECTION)
            and not Aura.present(unit, SPELL.BLESSING_OF_SPELLWARDING) then
            local hp = health_percent(unit) or 100
            local guid = safe_call(unit, "get_guid") or tostring(unit)
            local focus = pressure.targets and pressure.targets[guid]
            if hp > 25 and focus and focus.count >= 1
                and can_heal(player, unit, SPELL.BLESSING_OF_SACRIFICE) then
                local score = focus.count * 25 + (focus.burst and 35 or 0) - hp * 0.1
                if score > best_score then best, best_score = unit, score end
            end
        end
    end
    if best and budget_ready("external", false)
        and cast(SPELL.BLESSING_OF_SACRIFICE, best, player) then
        Telemetry.note("PREVENTION", { "action=sacrifice_cc_break",
            "incoming_cc=" .. tostring(incoming_cc),
            "caster=" .. tostring(safe_call(caster, "get_name") or "enemy"),
            "ally=" .. tostring(safe_call(best, "get_name") or "ally") })
        return true
    end
    return false
end

local function run_pvp_teammate_saves(player, units, pressure, profile)
    if not is_pvp_mode() or not profile or gui.personals:get_state() ~= true then return false end
    if run_pvp_sacrifice_cc_break(player, units, pressure) then return true end

    -- Ultimate Sacrifice transfers the full hit as a DoT. If our own Sacrifice
    -- is already protecting the kill target and the transfer is threatening us,
    -- Divine Shield converts that dangerous trade into a reliable team save.
    local self_hp = health_percent(player) or 100
    if talent_selected(SPELL.ULTIMATE_SACRIFICE, "Ultimate Sacrifice")
        and self_hp <= 72 and not Aura.present(player, SPELL.FORBEARANCE)
        and not Aura.present(player, SPELL.DIVINE_SHIELD) then
        for _, ally in ipairs(units or {}) do
            if ally ~= player and Aura.present_from(ally, SPELL.BLESSING_OF_SACRIFICE, player) then
                local ally_hp = health_percent(ally) or 100
                local ally_guid = safe_call(ally, "get_guid") or tostring(ally)
                local ally_focus = pressure and pressure.targets and pressure.targets[ally_guid]
                if ally_hp <= 55 and ally_focus and (ally_focus.burst or ally_focus.count >= 2)
                    and budget_ready("immunity", self_hp <= 35)
                    and cast(SPELL.DIVINE_SHIELD, player, player) then
                    Telemetry.note("DEFENSIVE", { "action=ultimate_sacrifice_bubble",
                        "ally=" .. tostring(safe_call(ally, "get_name") or "ally"),
                        "self_hp=" .. string.format("%.1f", self_hp) })
                    return true
                end
            end
        end
    end
    local target, projected = select_injured(player, units, pressure)
    if not target or target == player then return false end
    local current = health_percent(target) or projected
    if not current then return false end
    local guid = safe_call(target, "get_guid") or tostring(target)
    local focus = pressure and pressure.targets and pressure.targets[guid]
    local focused = focus and focus.count >= 1
    local heavy_pressure = focus and (focus.burst or focus.count >= 2)
    heavy_pressure = heavy_pressure or (focus and focus.swap == true)
    local objective_carrier = current_mode == "battleground"
        and safe_call(target, "is_objective_carrier") == true
    if current_mode == "battleground" then
        local buffs = safe_call(target, "get_buffs") or safe_call(target, "get_auras")
        for _, aura in pairs(type(buffs) == "table" and buffs or {}) do
            local name = safe_field(aura, "buff_name") or safe_field(aura, "name")
                or safe_field(aura, "spell_name")
            name = type(name) == "string" and string.lower(name) or ""
            if name == "alliance flag" or name == "horde flag"
                or name == "netherstorm flag" or name == "orb of power"
                or string.find(name, "flag carrier", 1, true) then
                objective_carrier = true
                break
            end
        end
    end
    heavy_pressure = heavy_pressure or (objective_carrier and focused and current <= 70)
    local cc_flags = pvp_helper and pvp_helper.cc_flags or {}
    local physical_stun = false
    local native_physical = safe_call(target, "is_physical_damage_taken_relevant") == true
    local native_magical = safe_call(target, "is_magical_damage_taken_relevant") == true
    if pvp_helper and type(pvp_helper.is_crowd_controlled) == "function" and cc_flags.STUN then
        local stun_ok, stunned = pcall(pvp_helper.is_crowd_controlled,
            pvp_helper, target, cc_flags.STUN, 700)
        physical_stun = stun_ok and stunned == true and focus
            and (native_physical or (focus.physical_attackers or 0) >= 1
                or (focus.melee_attackers or 0) >= 1)
    end
    local _, _, _, time_to_danger = predicted_health_percent(target)
    local urgent = current <= 18
        or (current_mode == "arena" and focus and (focus.burst_sources or 0) >= 2 and current <= 80)
        or (focused and current <= 36)
        or (focus and focus.burst and current <= 60)
        or (heavy_pressure and current <= 75)
        or (objective_carrier and focused and current <= 65)
        or (physical_stun and current <= 60)
        or (focused and time_to_danger <= 2.5 and current <= 75)
    if not urgent then return false end

    local protected = Aura.present(target, SPELL.BLESSING_OF_PROTECTION)
        or Aura.present(target, SPELL.BLESSING_OF_SPELLWARDING)
        or Aura.present(target, SPELL.DIVINE_SHIELD)
    local forbearance = Aura.present(target, SPELL.FORBEARANCE)
    local damage_flags = pvp_helper and pvp_helper.damage_type_flags or {}
    local any_defensive = pvp_defensive_active(target, damage_flags.ANY)
    local physical_defensive = pvp_defensive_active(target, damage_flags.PHYSICAL)
    local magical_defensive = pvp_defensive_active(target, damage_flags.MAGICAL)
    if any_defensive and current > 25 then
        Telemetry.skip(SPELL.BLESSING_OF_SACRIFICE, target, "defensive_overlap",
            "existing_damage_reduction_or_immunity")
    end
    if current <= 12 and not forbearance
        and cast(SPELL.LAY_ON_HANDS, target, player) then
        return true
    end

    self_hp = health_percent(player) or 100
    local self_guid = safe_call(player, "get_guid") or tostring(player)
    local self_focus = pressure and pressure.targets and pressure.targets[self_guid]
    local self_projected, _, _, self_ttd = predicted_health_percent(player)
    local self_unsafe = self_hp <= 48 or (self_focus and (self_focus.burst or self_focus.count >= 2)
        and self_hp <= 72)
        or (self_projected and self_projected <= 40) or self_ttd <= 2.5

    -- Sacrifice is the first external trade against confirmed burst or a
    -- multi-attacker go. Avoid transferring damage to a Paladin already under
    -- heavy pressure, and never renew a positively confirmed existing Sac.
    local sacrifice_threshold = (current_mode == "arena" and focus and (focus.burst_sources or 0) >= 2) and 80
        or (focus and focus.swap) and 80
        or (time_to_danger <= 3.5 and 80 or 70)
    if focused and heavy_pressure and current <= sacrifice_threshold and not self_unsafe
        and budget_ready("external", current <= 25)
        and (not any_defensive or current <= 25)
        and not protected
        and not Aura.present(target, SPELL.BLESSING_OF_SACRIFICE)
        and cast(SPELL.BLESSING_OF_SACRIFICE, target, player) then
        Telemetry.note("PREVENTION", { "action=preemptive_sacrifice",
            "target=" .. tostring(safe_call(target, "get_name") or "ally"),
            "target_hp=" .. string.format("%.1f", current),
            "attackers=" .. tostring(focus and focus.count or 0),
            "burst_sources=" .. tostring(focus and focus.burst_sources or 0),
            "cast_target_sources=" .. tostring(focus and focus.cast_target_sources or 0),
            "burst=" .. tostring(focus and focus.burst == true),
            "objective_carrier=" .. tostring(objective_carrier) })
        return true
    end

    -- Blessings of Protection and Spellwarding are only used when their
    -- combat clues match: close attackers for BoP, or a confirmed interruptible
    -- hostile cast plus burst for the selected Spellwarding talent.
    if (current <= 30 or (physical_stun and current <= 60)) and focus
        and (native_physical or (focus.physical_attackers or 0) >= 1
        or (focus.melee_attackers or 0) >= 1)
        and budget_ready("external", current <= 18)
        and (not physical_defensive or current <= 18)
        and not protected and not forbearance
        and not Aura.present(target, SPELL.BLESSING_OF_SACRIFICE)
        and cast(SPELL.BLESSING_OF_PROTECTION, target, player) then
        if physical_stun then
            Telemetry.note("RECOVERY", { "action=bop_physical_stun",
                "target=" .. tostring(safe_call(target, "get_name") or "ally") })
        end
        return true
    end
    if current <= 60 and focus and focus.burst
        and (native_magical or (focus.magic_attackers or 0) >= 1)
        and budget_ready("external", current <= 22)
        and (not magical_defensive or current <= 22)
        and talent_selected(SPELL.BLESSING_OF_SPELLWARDING, "Blessing of Spellwarding")
        and not protected and not forbearance
        and not Aura.present(target, SPELL.BLESSING_OF_SACRIFICE)
        and cast(SPELL.BLESSING_OF_SPELLWARDING, target, player) then
        Telemetry.note("PREVENTION", { "action=spellwarding_magic_burst",
            "target=" .. tostring(safe_call(target, "get_name") or "ally"),
            "target_hp=" .. string.format("%.1f", current) })
        return true
    end

    local devotion_active = own_aura_active(player, SPELL.DEVOTION_AURA)
    local concentration_active = own_aura_active(player, SPELL.CONCENTRATION_AURA)
    local mastery_for_damage = devotion_active and ((focus and focus.burst and current <= 62)
        or (focus and focus.count >= 2 and current <= 48))
    local friendly_casting = safe_call(target, "is_casting_spell") == true
        or safe_call(target, "is_channelling_spell") == true
        or safe_call(target, "is_channeling_spell") == true
    local mastery_for_casts = concentration_active and friendly_casting and current <= 62
        and cooldown_budget.enemy_interrupt_ready(player, target)
    local divine_plea_selected = talent_selected(SPELL.DIVINE_PLEA, "Divine Plea")
    -- Divine Plea is triggered by Aura Mastery and reduces healing for 30 seconds.
    -- Keep routine Mastery out of an active enemy go when that PvP talent is
    -- selected. Lethal health can still justify the immediate aura effect.
    if divine_plea_selected and (mastery_for_damage or mastery_for_casts) and current > 25 then
        Telemetry.skip(SPELL.AURA_MASTERY, target, "divine_plea_healing_penalty",
            "reserve_aura_mastery_for_safe_mana_window")
    end
    if gui.healing_cooldowns:get_state() == true and profile.cooldowns
        and (mastery_for_damage or mastery_for_casts)
        and (not divine_plea_selected or current <= 25)
        and budget_ready("major", current <= 25)
        and (not any_defensive or current <= 25)
        and not protected
        and not Aura.present(target, SPELL.BLESSING_OF_SACRIFICE)
        and cast(SPELL.AURA_MASTERY, player, player) then
        return true
    end
    return false
end

local function run_pvp_maintenance(player, units, pressure, profile)
    if not is_pvp_mode() then return false end
    if pvp_healing_urgent(player, units, pressure, profile) then return false end
    -- Combat aura comes first in safe windows; persistent beacons are talent-aware.
    if run_auto_aura(player, true) then return true end
    if run_auto_persistent_beacons(player, pressure) then return true end
    -- Divine Plea is passive: Aura Mastery starts its mana return and its
    -- healing penalty. Use that trade only in a deliberately safe, low-mana
    -- window so the penalty does not overlap the next visible enemy go.
    if profile and profile.cooldowns and gui.healing_cooldowns:get_state() == true
        and talent_selected(SPELL.DIVINE_PLEA, "Divine Plea")
        and mana_percent(player) <= 22
        and not Aura.present(player, SPELL.DIVINE_PLEA)
        and not (pressure and pressure.burst)
        and (not pressure or (pressure.attackers or 0) <= 1) then
        local safe_target, safe_projected = select_injured(player, units, pressure)
        local safe_current = safe_target and (health_percent(safe_target) or 100) or 100
        local safe_floor = math.min(safe_current, safe_projected or safe_current)
        if safe_floor >= 90 and budget_ready("major", false)
            and cast(SPELL.AURA_MASTERY, player, player) then
            Telemetry.note("RESOURCE", { "action=divine_plea_mana_window",
                "mana=" .. string.format("%.1f", mana_percent(player)),
                "lowest_hp=" .. string.format("%.1f", safe_floor) })
            return true
        end
    end
    return false
end

local function steed_spell_id()
    if spell_known(SPELL.DIVINE_STEED) then return SPELL.DIVINE_STEED end
    if spell_known(SPELL.DIVINE_STEED_LEGACY) then return SPELL.DIVINE_STEED_LEGACY end
    return SPELL.DIVINE_STEED
end

local function is_swimming(player)
    local value = safe_call(player, "is_swimming")
    if value ~= nil then return value == true end
    if core.character and type(core.character.is_swimming) == "function" then
        local ok, swimming = pcall(core.character.is_swimming)
        return ok and swimming == true
    end
    return false
end

local function run_auto_steed(player, combat, units, pressure, profile)
    if gui.auto_steed:get_state() ~= true then moving_since_steed = nil; return false end
    local now = core.time()
    if safe_call(player, "is_mounted") == true or safe_call(player, "is_flying") == true
        or is_swimming(player) or safe_call(player, "is_in_vehicle") == true then
        moving_since_steed = nil
        return false
    end
    if safe_call(player, "is_moving") ~= true or safe_call(player, "is_casting_spell") == true
        or safe_call(player, "is_channelling_spell") == true
        or safe_call(player, "is_channeling_spell") == true then
        moving_since_steed = nil
        return false
    end
    moving_since_steed = moving_since_steed or now
    if now - moving_since_steed < (combat and 0.45 or 1.35) or now - last_steed_success < 4 then
        return false
    end
    local reconnect_name = nil
    if combat then
        if not is_pvp_mode() then return false end
        if current_mode == "arena" then
            for _, ally in ipairs(units or {}) do
                local projected, current = predicted_health_percent(ally)
                if can_heal(player, ally, SPELL.HOLY_SHOCK)
                    and ((current and current <= 35)
                        or (projected and projected <= cooldown_budget.emergency_threshold())) then
                    Telemetry.skip(steed_spell_id(), ally, "arena_steed_yields_to_emergency_heal")
                    return false
                end
            end
        end
        local guid = safe_call(player, "get_guid") or tostring(player)
        local focus = pressure.targets and pressure.targets[guid]
        local reconnect_target = nil
        for _, ally in ipairs(units or {}) do
            if ally ~= player and (health_percent(ally) or 100) <= 55
                and distance(player, ally) <= 60 then
                local out_of_range = distance(player, ally) > 40
                local blocked = false
                if core.graphics and type(core.graphics.is_line_of_sight) == "function" then
                    local los_ok, visible = pcall(core.graphics.is_line_of_sight, player, ally)
                    blocked = not los_ok or visible ~= true
                end
                if out_of_range or blocked then reconnect_target = ally; break end
            end
        end
        if (not focus or focus.count < 1) and not reconnect_target then return false end
        local world_escape = current_mode == "world_pvp" and focus and focus.count >= 2
            and (health_percent(player) or 100) <= 65
        if pvp_healing_urgent(player, units, pressure, profile)
            and not world_escape and not reconnect_target then return false end
        if reconnect_target then
            reconnect_name = safe_call(reconnect_target, "get_name") or "ally"
        end
    else
        if current_mode == "arena" or current_mode == "battleground"
            or gui.fishing:get_state() == true
            or (gui.looting:get_state() == true and now < looting_busy_until) then return false end
    end
    local spell = steed_spell_id()
    if Aura.present(player, spell) then return false end
    if cast(spell, player, player) then
        last_steed_success = now
        moving_since_steed = nil
        local steed_action = reconnect_name and "partner_reconnect_steed"
            or (current_mode == "world_pvp" and "world_pvp_escape_steed" or "divine_steed")
        Telemetry.note("UTILITY", { "action=" .. steed_action,
            "mode=" .. current_mode,
            "target=" .. tostring(reconnect_name or "none") })
        return true
    end
    return false
end

local function enemy_cc_immune(enemy, category)
    if safe_call(enemy, "is_immune_to_cc") == true then return true end
    if pvp_helper then
        for _, method in ipairs({ "is_cc_immune", "is_crowd_controlled_weak" }) do
            if type(pvp_helper[method]) == "function" then
                local ok, immune, _, remaining
                if method == "is_crowd_controlled_weak" then
                    ok, immune, _, remaining = pcall(pvp_helper[method], pvp_helper, enemy, 500)
                elseif method == "is_cc_immune" then
                    ok, immune = pcall(pvp_helper[method], pvp_helper, enemy, category, 500)
                else
                    ok, immune = pcall(pvp_helper[method], pvp_helper, enemy)
                end
                -- Allow the next control to be queued at the end of a weak CC,
                -- while continuing to block wasteful overlap earlier in it.
                if ok and immune == true and (method ~= "is_crowd_controlled_weak"
                    or type(remaining) ~= "number" or remaining > 350) then return true end
            end
        end
        if category and type(pvp_helper.get_unit_dr) == "function" then
            local ok, dr = pcall(pvp_helper.get_unit_dr, pvp_helper, enemy, category, 0)
            if ok and type(dr) == "number" and dr < 0.5 then return true end
        end
    end
    return false
end

local function enemy_healer(enemy)
    local healer_specs = { [65] = true, [105] = true, [256] = true, [257] = true,
        [264] = true, [270] = true, [1468] = true }
    local spec = tonumber(safe_call(enemy, "get_specialization_id"))
    if spec and healer_specs[spec] then return true end
    local role = safe_call(enemy, "get_group_role") or safe_call(enemy, "get_role")
    if type(role) == "number" then return enums.group_role and role == enums.group_role.HEALER end
    return type(role) == "string" and string.find(string.lower(role), "heal", 1, true) ~= nil
end

cooldown_budget.arena_partner_window = function(friend, target)
    if current_mode ~= "arena" then return true end
    if not valid(friend) or not valid(target) then return false end
    if pvp_helper and type(pvp_helper.is_crowd_controlled) == "function" then
        local ok, controlled = pcall(pvp_helper.is_crowd_controlled, pvp_helper, friend, nil, 500)
        if ok and controlled == true then
            Telemetry.skip(SPELL.HAMMER_OF_JUSTICE, target, "arena_partner_controlled")
            return false
        end
    end
    if Aura.present(target, SPELL.DIVINE_SHIELD) or Aura.present(target, 45438) then
        Telemetry.skip(SPELL.HAMMER_OF_JUSTICE, target, "arena_kill_target_immune")
        return false
    end
    local flags = pvp_helper and pvp_helper.damage_type_flags or {}
    if flags.ANY and type(pvp_helper.is_damage_immune) == "function" then
        local ok, immune = pcall(pvp_helper.is_damage_immune, pvp_helper, target, flags.ANY, 500)
        if ok and immune == true then
            Telemetry.skip(SPELL.HAMMER_OF_JUSTICE, target, "arena_kill_target_immune")
            return false
        end
    end
    return true
end

local function friendly_kill_pressure(units, healer)
    local healer_guid = safe_call(healer, "get_guid")
    for _, friend in ipairs(units or {}) do
        local target = safe_call(friend, "get_target")
        if (current_mode ~= "arena" or (friend ~= core.object_manager.get_local_player()
            and safe_call(friend, "is_in_combat") == true))
            and valid(target) and safe_call(target, "is_player") == true
            and cooldown_budget.arena_partner_window(friend, target)
            and safe_call(target, "is_enemy_with", friend) == true
            and safe_call(target, "get_guid") ~= healer_guid
            and not cooldown_budget.enemy_has_breakable_control(target)
            and (health_percent(target) or 100) <= 80 then return true end
    end
    return false
end

local function can_control_enemy(player, enemy)
    if not core.graphics or type(core.graphics.is_line_of_sight) ~= "function" then return false end
    local ok, visible = pcall(core.graphics.is_line_of_sight, player, enemy)
    return ok and visible == true
end

cooldown_budget.pressure_victim = function(enemy, pressure)
    if current_mode == "arena" then
        local guid = safe_call(enemy, "get_guid") or tostring(enemy)
        local target_guid = cooldown_budget.enemy_targets and cooldown_budget.enemy_targets[guid]
        local state = target_guid and pressure and pressure.targets and pressure.targets[target_guid]
        if state and valid(state.unit) then return state.unit end
    end
    return safe_call(enemy, "get_target")
end

local function run_auto_pvp_cc(player, units, pressure, profile)
    if gui.auto_cc:get_state() ~= true or not is_pvp_mode()
        or safe_call(player, "is_in_combat") ~= true then return false end
    local heal_urgent = pvp_healing_urgent(player, units, pressure, profile)
    -- Hold offensive setup in the opener; an emergency peel may still save
    -- a teammate before the opening exchange has stabilized.
    local opening = core.time() - pvp_combat_started_at < 5

    local objects = cooldown_budget.objects()
    if type(objects) ~= "table" then return false end

    -- Denounce is a defensive Holy Power spend when selected: suppress an
    -- enemy burst window before crits force expensive recovery. It never
    -- replaces an urgent heal and is withheld at low mana.
    if not opening and talent_selected(SPELL.DENOUNCE, "Denounce") and not heal_urgent
        and mana_percent(player) >= 35 and (safe_call(player, "get_power", HOLY_POWER) or 0) >= 5 then
        for _, enemy in pairs(objects) do
            if valid(enemy) and safe_call(enemy, "is_player") == true
                and safe_call(enemy, "is_enemy_with", player) == true
                and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 30
                and not has_visible_debuff(enemy, SPELL.DENOUNCE)
                and not cooldown_budget.enemy_has_breakable_control(enemy)
                and can_control_enemy(player, enemy) then
                local victim = cooldown_budget.pressure_victim(enemy, pressure)
                local victim_guid = victim and (safe_call(victim, "get_guid") or tostring(victim))
                local focus = victim_guid and pressure.targets and pressure.targets[victim_guid]
                local victim_hp = victim and health_percent(victim) or 100
                local bursting = focus and focus.burst
                if not bursting and pvp_helper and type(pvp_helper.has_burst_active) == "function" then
                    local burst_ok, active = pcall(pvp_helper.has_burst_active, pvp_helper, enemy, 500)
                    bursting = burst_ok and active == true
                end
                if bursting and victim_hp >= 68 and cast(SPELL.DENOUNCE, enemy, player) then
                    Telemetry.note("PREVENTION", { "action=denounce_anti_crit",
                        "enemy=" .. tostring(safe_call(enemy, "get_name") or "enemy"),
                        "victim_hp=" .. string.format("%.1f", victim_hp) })
                    return true
                end
            end
        end
    end
    local best, best_score, best_reason = nil, -math.huge, nil
    local flags = (pvp_helper and pvp_helper.cc_flags) or enums.cc_flags or {}
    for _, enemy in pairs(objects) do
        if valid(enemy) and safe_call(enemy, "is_player") == true
            and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 20
            and not enemy_cc_immune(enemy, flags.STUN) and can_control_enemy(player, enemy) then
            local target = cooldown_budget.pressure_victim(enemy, pressure)
            local target_guid = safe_call(target, "get_guid")
            local target_pressure = target_guid and pressure.targets and pressure.targets[target_guid]
            local casting = safe_call(enemy, "is_casting_spell") == true
                or safe_call(enemy, "is_channelling_spell") == true
                or safe_call(enemy, "is_channeling_spell") == true
            local interruptible = safe_call(enemy, "is_active_spell_interruptable") == true
            local healer = enemy_healer(enemy)
            local teammate_setup = healer and friendly_kill_pressure(units, enemy)
            local target_hp = target and health_percent(target)
            local peel = target_pressure and target_hp and (
                (target_pressure.burst and target_hp <= 60)
                or (target_pressure.count >= 2 and target_hp <= 42)
                or (target_pressure.count >= 1 and target_hp <= 25))
            local emergency_peel = peel and (target_hp <= 38
                or (target_pressure.burst and target_hp <= 52))
            local peel_interrupt = target_pressure and casting and interruptible
                and target_hp and target_hp <= 55
            local setup = healer and teammate_setup and not heal_urgent
            if setup and current_mode == "arena" then
                local full_dr = false
                if flags.STUN and pvp_helper and type(pvp_helper.get_unit_dr) == "function" then
                    local dr_ok, dr = pcall(pvp_helper.get_unit_dr, pvp_helper, enemy, flags.STUN, 0)
                    full_dr = dr_ok and type(dr) == "number" and dr >= 1
                end
                if not full_dr then
                    setup = false
                    Telemetry.skip(SPELL.HAMMER_OF_JUSTICE, enemy, "arena_setup_requires_full_stun_dr")
                end
            end
            local interrupt_save = casting and interruptible and target_pressure
                and target_hp and target_hp <= 42
            if (not opening or emergency_peel or interrupt_save)
                and (setup or peel or (casting and interruptible and not heal_urgent)
                or (heal_urgent and (emergency_peel or peel_interrupt or interrupt_save))) then
                local trinket_down = false
                if pvp_helper and type(pvp_helper.trinket_used_within) == "function" then
                    local trinket_ok, used = pcall(pvp_helper.trinket_used_within, pvp_helper, enemy, 90)
                    trinket_down = trinket_ok and used == true
                end
                local score = (emergency_peel and 180 or 0)
                    + (peel and 120 or 0) + (setup and 80 or 0)
                    + (peel_interrupt and 75 or 0)
                    + (casting and interruptible and 35 or 0)
                    + (trinket_down and 30 or 0)
                    - distance(player, enemy)
                if score > best_score then
                    best, best_score = enemy, score
                    best_reason = emergency_peel and "emergency_peel"
                        or peel and "pressure_peel" or setup and "healer_setup"
                        or "cast_control"
                end
            end
        end
    end
    if best and cast(SPELL.HAMMER_OF_JUSTICE, best, player) then
        Telemetry.note("CONTROL", { "spell=Hammer_of_Justice", "target=" ..
            tostring(safe_call(best, "get_name") or "enemy"), "mode=" .. current_mode,
            "reason=" .. tostring(best_reason), "score=" .. string.format("%.1f", best_score) })
        return true
    end
    if opening then return false end

    local glare = talent_selected(SPELL.SEARING_GLARE, "Searing Glare")
    local area_control = glare or talent_selected(SPELL.BLINDING_LIGHT, "Blinding Light")
    local close, pressured_close, protected_control = 0, 0, false
    for _, enemy in pairs(objects) do
        -- Area spells also hit enemies excluded from the eligible-target count.
        -- Preserve a teammate's control instead of overwriting their setup.
        if valid(enemy) and safe_call(enemy, "is_enemy_with", player) == true
            and distance(player, enemy) <= 10
            and cooldown_budget.enemy_has_breakable_control(enemy) then protected_control = true end
        if valid(enemy) and safe_call(enemy, "is_player") == true
            and safe_call(enemy, "is_enemy_with", player) == true
            and safe_call(enemy, "is_in_combat") == true and distance(player, enemy) <= 10
            and not enemy_cc_immune(enemy, flags.BLINDING_LIGHT or flags.DISORIENT)
            and can_control_enemy(player, enemy) then
            close = close + 1
            local target = cooldown_budget.pressure_victim(enemy, pressure)
            local guid = safe_call(target, "get_guid")
            local focus = guid and pressure.targets and pressure.targets[guid]
            local target_hp = target and health_percent(target)
            local peel = focus and target_hp and ((focus.burst and target_hp <= 60)
                or (focus.count >= 2 and target_hp <= 42)
                or (focus.count >= 1 and target_hp <= 25))
            if peel or (not heal_urgent and focus) then pressured_close = pressured_close + 1 end
        end
    end
    local control_spell = glare and SPELL.SEARING_GLARE or SPELL.BLINDING_LIGHT
    if area_control and close >= 2 and pressured_close >= 1 and protected_control then
        Telemetry.skip(control_spell, player, "area_control_overlap", "nearby_enemy_already_controlled")
    end
    if area_control and close >= 2 and pressured_close >= 1 and not protected_control
        and cast(control_spell, player, player) then
        Telemetry.note("CONTROL", { "spell=" .. (glare and "Searing_Glare" or "Blinding_Light"),
            "nearby_enemies=" .. close, "mode=" .. current_mode })
        return true
    end
    if spell_known(SPELL.TURN_EVIL) and mana_percent(player) > 30
        and safe_call(player, "is_moving") ~= true then
        local creature = enums.creature_type or {}
        for _, pet in pairs(objects) do
            local pet_type = valid(pet) and safe_call(pet, "get_creature_type") or nil
            local eligible = pet_type ~= nil and (
                (creature.UNDEAD ~= nil and pet_type == creature.UNDEAD)
                or (creature.DEMON ~= nil and pet_type == creature.DEMON)
                or (creature.ABERRATION ~= nil and pet_type == creature.ABERRATION))
            if eligible and safe_call(pet, "is_pet") == true
                and safe_call(pet, "is_enemy_with", player) == true
                and distance(player, pet) <= 30
                and not enemy_cc_immune(pet, flags.FEAR)
                and can_control_enemy(player, pet) then
                local victim = safe_call(pet, "get_target")
                local victim_guid = victim and (safe_call(victim, "get_guid") or tostring(victim))
                local focus = victim_guid and pressure.targets and pressure.targets[victim_guid]
                local victim_hp = victim and health_percent(victim) or 100
                if focus and (not heal_urgent or victim_hp <= 45)
                    and victim_hp <= 65 and cast(SPELL.TURN_EVIL, pet, player) then
                    Telemetry.note("CONTROL", { "spell=Turn_Evil",
                        "target=" .. tostring(safe_call(pet, "get_name") or "pet"),
                        "victim=" .. tostring(safe_call(victim, "get_name") or "ally") })
                    return true
                end
            end
        end
    end
    return false
end

cooldown_budget.run_arena_damage = function(player, units, pressure, profile)
    if current_mode ~= "arena" or gui.damage:get_state() ~= true
        or type(units) ~= "table" or #units == 0
        or safe_call(player, "is_in_combat") ~= true or cooldown_budget.predictive_risk
        or pvp_healing_urgent(player, units, pressure, profile) then return false end
    local power = safe_call(player, "get_power", HOLY_POWER)
    if type(power) ~= "number" or mana_percent(player) < 25 then return false end
    for _, ally in ipairs(units or {}) do
        local projected, current, _, ttd = predicted_health_percent(ally)
        local guid = safe_call(ally, "get_guid") or tostring(ally)
        local focus = pressure and pressure.targets and pressure.targets[guid]
        if not current or not projected or math.min(current, projected) < 90 or ttd <= 4
            or (focus and (focus.burst or focus.count >= 2)) then return false end
    end
    local function eligible(enemy, friend)
        return cooldown_budget.arena_enemy_safe(player, enemy)
            and distance(player, enemy) <= 30 and can_control_enemy(player, enemy)
            and cooldown_budget.arena_partner_window(friend or player, enemy)
    end
    local target, source = nil, "selected"
    for _, ally in ipairs(units or {}) do
        if ally ~= player and valid(ally) and safe_call(ally, "is_in_combat") == true then
            local enemy = safe_call(ally, "get_target")
            if eligible(enemy, ally) then target, source = enemy, "partner_assist"; break end
        end
    end
    target = target or safe_call(player, "get_target")
    if not eligible(target, player) then return false end
    local function request(spell)
        if not cast(spell, target, player) then return false end
        Telemetry.note("ARENA_DAMAGE", { "spell_id=" .. tostring(spell),
            "target=" .. tostring(safe_call(target, "get_name") or "enemy"),
            "source=" .. source, "holy_power=" .. tostring(power) })
        return true
    end
    local crusader = Aura.present(player, SPELL.AVENGING_CRUSADER)
    if (crusader or Aura.present(player, SPELL.AVENGING_WRATH))
        and request(SPELL.HAMMER_OF_WRATH) then return true end
    local charges = read_core(core.spell_book.get_spell_charge, SPELL.HOLY_SHOCK)
    if power < 5 and type(charges) == "number" and charges >= 2 and mana_percent(player) >= 35
        and request(SPELL.HOLY_SHOCK) then return true end
    if request(SPELL.JUDGMENT) then return true end
    if power < 5 and crusader and distance(player, target) <= 5
        and request(SPELL.CRUSADER_STRIKE) then return true end
    return false
end

local function run_auto_fishing(player)
    if gui.fishing:get_state() ~= true or safe_call(player, "is_in_combat") == true then return false end
    local now = core.time()
    if now < next_fishing_action then return true end

    local bobber = nil
    local objects = cooldown_budget.objects()
    if type(objects) == "table" then
        for _, object in pairs(objects) do
            if object and fish_helper:is_fish_bobber(object) then
                bobber = object
                break
            end
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
        return true
    end

    if safe_call(player, "is_casting_spell") == true then return true end
    if now - last_fishing_cast >= 2.0 then
        local started = core.profession.open_profession(core.profession.FISHING)
        last_fishing_cast = now
        next_fishing_action = now + (started and 1.0 or 2.0)
    end
    return true
end

local function run_auto_looting(player)
    if gui.looting:get_state() ~= true or gui.fishing:get_state() == true
        or safe_call(player, "is_in_combat") == true
        or safe_call(player, "is_casting_spell") == true then return false end
    local now = core.time()
    if now < next_looting_attempt then return now < looting_busy_until end

    local nearest, nearest_distance = nil, 35
    local objects = cooldown_budget.objects()
    if type(objects) == "table" then
        for _, object in pairs(objects) do
            -- `valid()` intentionally rejects dead units, so corpse checks must
            -- validate the object directly before testing its dead/loot state.
            if safe_call(object, "is_valid") == true and safe_call(object, "is_unit") == true
                and safe_call(object, "is_dead") == true
                and safe_call(object, "can_be_looted") == true
                and safe_call(object, "has_loot") == true then
                local key = safe_call(object, "get_guid") or tostring(object)
                if (recently_looted[key] or 0) <= now then
                    local d = distance(player, object)
                    if d <= nearest_distance then nearest, nearest_distance = object, d end
                end
            end
        end
    end

    if nearest then
        local call_ok, started = pcall(core.input.loot_object, nearest, true)
        started = call_ok and started == true
        next_looting_attempt = now + (started and 1.5 or 1.0)
        looting_busy_until = started and next_looting_attempt or 0
        if started then
            local key = safe_call(nearest, "get_guid") or tostring(nearest)
            recently_looted[key] = now + 8.0
        end
        return started
    else
        next_looting_attempt = now + 0.5
    end
    return false
end

local function gui_state()
    local p = profiles[current_mode]
    local labels_by_mode = { mythic_plus = "Mythic+", delve = "Delve", arena = "Arena",
        battleground = "Battleground", world_pvp = "World PvP", training = "Training Dummy" }
    local shown = {}
    for key, item in pairs(profiles) do shown[key] = item end
    shown.mythic_plus = {}
    for k, v in pairs(profiles.mythic_plus) do shown.mythic_plus[k] = v end
    shown.mythic_plus.heal_at, shown.mythic_plus.aoe_at = gui.heal_at:get(), gui.aoe_at:get()
    local hotkeys = {}
    for _, entry in ipairs(cooldown_budget.hotkey_bindings or {}) do
        local ok, code = pcall(entry.bind.get_key_code, entry.bind)
        hotkeys[entry.action] = cooldown_budget.key_label(ok and code or 0)
    end
    return { mode_label = labels_by_mode[current_mode], active_mode = current_mode,
        profile_name = p and p.title, hero = hero_build(), status = gui.enabled:get_state() and "Active" or "Paused",
        last = last_action, notice = gui_notice, auto_mode = mode_override == nil,
        plugin_enabled = gui.enabled:get_state() == true, log_enabled = gui.debug_log:get_state() == true,
        global_healing = gui.healing:get_state() == true,
        healing_cooldowns = gui.healing_cooldowns:get_state() == true,
        damage = gui.damage:get_state() == true,
        personals = gui.personals:get_state() == true,
        interrupt = gui.interrupt:get_state() == true,
        auto_face = gui.auto_face:get_state() == true,
        auto_steed = gui.auto_steed:get_state() == true,
        arena_lines = gui.arena_lines:get_state() == true,
        danger_zones = gui.danger_zones:get_state() == true,
        danger_status = DangerZones.status,
        boss_guide = gui.boss_guide:get_state() == true,
        boss_guide_status = BossGuide.status,
        auto_cc = gui.auto_cc:get_state() == true,
        auto_beacon = gui.auto_beacon:get_state() == true,
        auto_aura = gui.auto_aura:get_state() == true,
        auto_dispel = gui.auto_dispel:get_state() == true,
        fishing = gui.fishing:get_state() == true,
        looting = gui.looting:get_state() == true,
        auto_target = gui.auto_target:get_state() == true,
        training_dummy = gui.training_dummy:get_state() == true,
        emergency = gui.emergency:get(), heal_at = gui.heal_at:get(), aoe_at = gui.aoe_at:get(),
        hotkeys = hotkeys,
        log_status = Telemetry.status, run_status = Telemetry.run_status and Telemetry.run_status() or "Run recorder ready",
        debugger = Telemetry.debug_snapshot and Telemetry.debug_snapshot() or {},
        window_open = window_open, profiles = shown }
end

local function gui_action(kind, key, setting)
    if kind == "auto_mode" then
        mode_override, gui_notice = nil, "Automatic profile selection restored"
    elseif kind == "set_mode" and profiles[key] then
        mode_override, gui_notice = key, "Manual profile: " .. key
    elseif kind == "toggle_plugin" then
        gui.enabled:set(gui.enabled:get_state() ~= true)
        gui_notice = gui.enabled:get_state() and "Plugin enabled" or "Plugin paused"
    elseif kind == "toggle_window" then
        window_open = not window_open
        gui_notice = window_open and "Control panel opened" or "Control panel hidden; press F1 to reopen"
    elseif kind == "toggle_healing" then
        gui.healing:set(gui.healing:get_state() ~= true)
        gui_notice = gui.healing:get_state() and "Global healing enabled" or "Global healing paused"
    elseif kind == "toggle_healing_cooldowns" then
        gui.healing_cooldowns:set(gui.healing_cooldowns:get_state() ~= true)
        gui_notice = gui.healing_cooldowns:get_state() and "Healing cooldowns enabled" or "Healing cooldowns paused"
    elseif kind == "toggle_damage" then
        gui.damage:set(gui.damage:get_state() ~= true)
        gui_notice = gui.damage:get_state() and "Damage rotation enabled" or "Damage rotation paused"
    elseif kind == "toggle_personals" then
        gui.personals:set(gui.personals:get_state() ~= true)
        gui_notice = gui.personals:get_state() and "Defensives enabled" or "Defensives paused"
    elseif kind == "toggle_interrupt" then
        gui.interrupt:set(gui.interrupt:get_state() ~= true)
        gui_notice = gui.interrupt:get_state() and "Interrupts enabled" or "Interrupts paused"
    elseif kind == "toggle_face" then
        gui.auto_face:set(gui.auto_face:get_state() ~= true)
        gui_notice = gui.auto_face:get_state() and "Automatic facing enabled" or "Automatic facing paused"
    elseif kind == "toggle_steed" then
        gui.auto_steed:set(gui.auto_steed:get_state() ~= true)
        gui_notice = gui.auto_steed:get_state() and "Automatic Divine Steed enabled" or "Automatic Divine Steed paused"
    elseif kind == "toggle_beacon" then
        gui.auto_beacon:set(gui.auto_beacon:get_state() ~= true)
        gui_notice = gui.auto_beacon:get_state() and "Automatic Beacon enabled" or "Automatic Beacon paused"
    elseif kind == "toggle_aura" then
        gui.auto_aura:set(gui.auto_aura:get_state() ~= true)
        gui_notice = gui.auto_aura:get_state() and "Automatic aura enabled" or "Automatic aura paused"
    elseif kind == "toggle_dispel" then
        gui.auto_dispel:set(gui.auto_dispel:get_state() ~= true)
        gui_notice = gui.auto_dispel:get_state() and "Automatic dispels enabled" or "Automatic dispels paused"
    elseif kind == "toggle_fishing" then
        gui.fishing:set(gui.fishing:get_state() ~= true)
        gui_notice = gui.fishing:get_state() and "Automatic fishing enabled" or "Automatic fishing paused"
    elseif kind == "toggle_looting" then
        gui.looting:set(gui.looting:get_state() ~= true)
        gui_notice = gui.looting:get_state() and "Automatic looting enabled" or "Automatic looting paused"
    elseif kind == "toggle_target" then
        gui.auto_target:set(gui.auto_target:get_state() ~= true)
        gui_notice = gui.auto_target:get_state() and "Automatic target selection enabled" or "Automatic target selection paused"
    elseif kind == "toggle_training_dummy" then
        gui.training_dummy:set(gui.training_dummy:get_state() ~= true)
        gui_notice = gui.training_dummy:get_state() and "Training dummy detection enabled" or "Training dummy detection paused"
    elseif kind == "toggle_arena_lines" then
        gui.arena_lines:set(gui.arena_lines:get_state() ~= true)
        gui_notice = gui.arena_lines:get_state() and "Arena partner lines enabled" or "Arena partner lines hidden"
    elseif kind == "toggle_danger_zones" then
        gui.danger_zones:set(gui.danger_zones:get_state() ~= true)
        gui_notice = gui.danger_zones:get_state() and "PvE danger-zone aura enabled" or "PvE danger-zone aura hidden"
    elseif kind == "toggle_boss_guide" then
        gui.boss_guide:set(gui.boss_guide:get_state() ~= true)
        gui_notice = gui.boss_guide:get_state() and "Season 2 boss guide enabled" or "Season 2 boss guide hidden"
    elseif kind == "toggle_cc" then
        gui.auto_cc:set(gui.auto_cc:get_state() ~= true)
        gui_notice = gui.auto_cc:get_state() and "Automatic PvP crowd control enabled" or "Automatic PvP crowd control paused"
    elseif kind == "profile_toggle" and profiles[key] and profiles[key][setting] ~= nil then
        profiles[key][setting] = not profiles[key][setting]
        gui_notice = key .. " " .. setting .. (profiles[key][setting] and " enabled" or " disabled")
    elseif kind == "adjust_threshold" and gui[key] and type(setting) == "number" then
        local minimum, maximum = 5, 95
        if key == "heal_at" then minimum, maximum = 40, 95
        elseif key == "aoe_at" then minimum, maximum = 40, 90
        elseif key ~= "emergency" then return end
        local current = tonumber(gui[key]:get()) or minimum
        gui[key]:set(math.max(minimum, math.min(maximum, current + setting)))
        gui_notice = key .. " set to " .. tostring(gui[key]:get()) .. "%"
    elseif kind == "toggle_log" then
        gui.debug_log:set(gui.debug_log:get_state() ~= true)
        Telemetry.set_enabled(gui.debug_log:get_state() == true)
        gui_notice = gui.debug_log:get_state() and "Session recording enabled" or "Session recording paused"
    elseif kind == "clear_log" then
        gui_notice = Telemetry.clear() and "Log cleared; recording continues" or "Could not clear log file"
    elseif kind == "reset_debug" then
        if Telemetry.reset_debug then Telemetry.reset_debug() end
        gui_notice = "Debugger state reset"
    elseif kind == "debug_error" then
        Telemetry.error("gui", key)
        gui_notice = "GUI error captured by debugger"
    elseif kind == "notice" then
        gui_notice = tostring(key)
    end
end

cooldown_budget.hotkey_bindings = {
    { id = "plugin", bind = gui.enabled_key, action = "toggle_plugin" },
    { id = "healing", bind = gui.healing_key, action = "toggle_healing" },
    { id = "cooldowns", bind = gui.healing_cooldowns_key, action = "toggle_healing_cooldowns" },
    { id = "beacon", bind = gui.auto_beacon_key, action = "toggle_beacon" },
    { id = "dispel", bind = gui.auto_dispel_key, action = "toggle_dispel" },
    { id = "personals", bind = gui.personals_key, action = "toggle_personals" },
    { id = "damage", bind = gui.damage_key, action = "toggle_damage" },
    { id = "interrupt", bind = gui.interrupt_key, action = "toggle_interrupt" },
    { id = "cc", bind = gui.auto_cc_key, action = "toggle_cc" },
    { id = "aura", bind = gui.auto_aura_key, action = "toggle_aura" },
    { id = "steed", bind = gui.auto_steed_key, action = "toggle_steed" },
    { id = "face", bind = gui.auto_face_key, action = "toggle_face" },
    { id = "target", bind = gui.auto_target_key, action = "toggle_target" },
    { id = "training", bind = gui.training_dummy_key, action = "toggle_training_dummy" },
    { id = "lines", bind = gui.arena_lines_key, action = "toggle_arena_lines" },
    { id = "danger", bind = gui.danger_zones_key, action = "toggle_danger_zones" },
    { id = "boss", bind = gui.boss_guide_key, action = "toggle_boss_guide" },
    { id = "fishing", bind = gui.fishing_key, action = "toggle_fishing" },
    { id = "looting", bind = gui.looting_key, action = "toggle_looting" },
    { id = "log", bind = gui.debug_log_key, action = "toggle_log" },
}
cooldown_budget.hotkey_down = {}
cooldown_budget.next_hotkey_poll = -math.huge
cooldown_budget.key_label = function(code)
    code = tonumber(code) or 0
    if code <= 0 or code == 7 or code == 999 then return "UNBOUND" end
    if code >= 0x70 and code <= 0x7B then return "F" .. tostring(code - 0x6F) end
    if code >= 0x30 and code <= 0x39 then return string.char(code) end
    if code >= 0x41 and code <= 0x5A then return string.char(code) end
    local names = { [0x20] = "SPACE", [0x09] = "TAB", [0x10] = "SHIFT",
        [0x11] = "CTRL", [0x12] = "ALT", [0x2D] = "INSERT", [0x2E] = "DELETE",
        [0x24] = "HOME", [0x23] = "END", [0x21] = "PAGE UP", [0x22] = "PAGE DOWN" }
    return names[code] or ("KEY " .. tostring(code))
end
cooldown_budget.poll_feature_hotkeys = function()
    if not core.input or type(core.input.is_key_pressed) ~= "function" then return end
    local now = core.time()
    if now >= 0 and now < (cooldown_budget.next_hotkey_poll or -math.huge) then return end
    cooldown_budget.next_hotkey_poll = now + 0.02
    for _, entry in ipairs(cooldown_budget.hotkey_bindings) do
        local ok, code = pcall(entry.bind.get_key_code, entry.bind)
        code = ok and tonumber(code) or 0
        local down = false
        if code and code > 0 and code ~= 7 and code ~= 999 then
            local pressed_ok, pressed = pcall(core.input.is_key_pressed, code)
            down = pressed_ok and pressed == true
        end
        if down and cooldown_budget.hotkey_down[entry.id] ~= true then
            gui_action(entry.action)
            gui_notice = cooldown_budget.key_label(code) .. " - " .. tostring(gui_notice)
        end
        cooldown_budget.hotkey_down[entry.id] = down
    end
end

local function poll_gui_key()
    if not core.input or type(core.input.is_key_pressed) ~= "function" then return end
    local ok, down = pcall(core.input.is_key_pressed, 0x70)
    down = ok and down == true
    if down and not key_down[0x70] then window_open = not window_open end
    key_down[0x70] = down
    cooldown_budget.poll_feature_hotkeys()
end

local function telemetry_rows(units)
    local rows = {}
    for _, unit in ipairs(units) do
        local hp, current, incoming = predicted_health_percent(unit)
        local guid = safe_call(unit, "get_guid") or tostring(unit)
        rows[#rows + 1] = { unit = unit, hp = hp or 0,
            current = current or hp or 0, incoming = incoming or 0,
            velocity = health_history[guid] and health_history[guid].velocity or 0,
            acceleration = health_history[guid] and health_history[guid].acceleration or 0 }
    end
    return rows
end

-- Lua limits a function to 60 captured outer locals. Keep the frame update's
-- helper surface behind one runtime table so adding prediction systems cannot
-- silently push the plugin over that compiler limit again.
cooldown_budget.runtime = {
    Aura = Aura, beacon_build = beacon_build, budget_ready = budget_ready,
    adaptive_offset = adaptive_offset, can_heal = can_heal, gcd_remaining = gcd_remaining,
    cast = cast, dampening_percent = dampening_percent, dungeon_forecast = dungeon_forecast,
    effective_mode = effective_mode, group_units = group_units, hero_build = hero_build,
    injured_count = injured_count, is_pvp_mode = is_pvp_mode,
    is_training_dummy = cooldown_budget.is_training_dummy, mana_percent = mana_percent,
    observe_outcomes = observe_outcomes, own_aura_active = own_aura_active,
    poll_gui_key = poll_gui_key, predicted_health_percent = predicted_health_percent,
    pvp_pressure = pvp_pressure, safe_call = safe_call, select_injured = select_injured,
    has_poison_or_disease = has_poison_or_disease,
    healing_conversion_enemy = healing_conversion_enemy, health_percent = health_percent,
    is_holy_paladin = is_holy_paladin, pvp_healing_urgent = pvp_healing_urgent,
    read_core = read_core, select_beaconed_injured = select_beaconed_injured,
    spell_known = spell_known, valid = valid,
    talent_selected = talent_selected, telemetry_rows = telemetry_rows,
    update_health_velocity = update_health_velocity,
    run_auto_aura = run_auto_aura, run_auto_dispel = run_auto_dispel,
    run_auto_face = run_auto_face, run_auto_fishing = run_auto_fishing,
    run_auto_freedom = run_auto_freedom, run_auto_looting = run_auto_looting,
    run_auto_persistent_beacons = run_auto_persistent_beacons,
    run_auto_pvp_cc = run_auto_pvp_cc, run_auto_steed = run_auto_steed,
    run_auto_target = run_auto_target, run_out_of_combat_topoff = run_out_of_combat_topoff,
    run_pre_damage_setup = run_pre_damage_setup,
    run_pvp_cc_recovery = run_pvp_cc_recovery,
    run_pvp_maintenance = run_pvp_maintenance,
    run_pvp_teammate_saves = run_pvp_teammate_saves
}

local function update()
    cooldown_budget.runtime.poll_gui_key()
    cooldown_budget.runtime.observe_outcomes()
    local player = core.object_manager.get_local_player()
    if not cooldown_budget.runtime.valid(player) or not cooldown_budget.runtime.is_holy_paladin(player) then return end
    local mode = cooldown_budget.runtime.effective_mode()
    local profile = profiles[mode]
    local combat = cooldown_budget.runtime.safe_call(player, "is_in_combat") == true or mode == "training"
    local units = cooldown_budget.runtime.group_units(player)
    cooldown_budget.runtime.update_health_velocity(units)
    local pressure = cooldown_budget.runtime.pvp_pressure(player, units)
    local forecast = cooldown_budget.runtime.dungeon_forecast(player, units)
    local dampening = cooldown_budget.runtime.is_pvp_mode() and cooldown_budget.runtime.dampening_percent(player) or 0
    if cooldown_budget.runtime.is_pvp_mode() and (combat or pressure.attackers > 0) then
        if pvp_combat_started_at == -math.huge then pvp_combat_started_at = core.time() end
    else
        pvp_combat_started_at = -math.huge
    end
    Telemetry.set_enabled(gui.debug_log:get_state() == true)
    cooldown_budget.observe_arena_health(player, units, pressure)
    local self_projected, self_current, self_incoming = cooldown_budget.runtime.predicted_health_percent(player)
    local selected = cooldown_budget.runtime.safe_call(player, "get_target")
    local group_deficit, predicted_group_loss, accelerating_allies = 0, 0, 0
    for _, unit in ipairs(units) do
        local projected, current = cooldown_budget.runtime.predicted_health_percent(unit)
        if projected and current then
            group_deficit = group_deficit + math.max(0, 100 - projected)
            predicted_group_loss = predicted_group_loss + math.max(0, current - projected)
        end
        local history = health_history[cooldown_budget.runtime.safe_call(unit, "get_guid") or tostring(unit)]
        if history and ((history.acceleration or 0) >= 3 or (history.velocity or 0) >= 4) then
            accelerating_allies = accelerating_allies + 1
        end
    end
    cooldown_budget.predictive_risk = forecast.active or predicted_group_loss >= 12
        or accelerating_allies >= 2 or pressure.burst == true or pressure.target_attackers >= 2
        or ((forecast.exposed_attackers or 0) >= 3 and forecast.exposed_target
            and (cooldown_budget.runtime.predicted_health_percent(forecast.exposed_target) or 100) <= 85)
    local context = {
        beacon = cooldown_budget.runtime.beacon_build(), self_projected = self_projected,
        self_current = self_current, self_incoming = self_incoming,
        holy_power = cooldown_budget.runtime.safe_call(player, "get_power", HOLY_POWER) or 0,
        gcd = cooldown_budget.runtime.gcd_remaining(player) or "unknown",
        armament_button = cooldown_budget.runtime.talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments")
            and (tostring(cooldown_budget.armament_spell()) .. ">"
                .. tostring(cooldown_budget.resolve_spell(cooldown_budget.armament_spell())))
            or "inactive",
        armament_charges = cooldown_budget.runtime.talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments")
            and (cooldown_budget.runtime.read_core(core.spell_book.get_spell_charge,
                cooldown_budget.resolve_spell(cooldown_budget.armament_spell())) or "unknown")
            or "inactive",
        selected = selected and cooldown_budget.runtime.safe_call(selected, "get_name") or "none",
        selected_hp = selected and cooldown_budget.runtime.health_percent(selected) or "unknown",
        adaptive_offset = string.format("%.1f", cooldown_budget.runtime.adaptive_offset(mode)),
        mana_burn = string.format("%.2f", cooldown_budget.mana_burn or 0),
        mana_forecast = string.format("%.1f", cooldown_budget.mana_forecast or cooldown_budget.runtime.mana_percent(player)),
        mana_time_to_critical = (cooldown_budget.mana_time_to_critical or math.huge) < math.huge
            and string.format("%.1f", cooldown_budget.mana_time_to_critical) or "stable",
        mana_conserve = cooldown_budget.mana_conserve and "yes" or "no",
        group_deficit = string.format("%.1f", group_deficit),
        predicted_group_loss = string.format("%.1f", predicted_group_loss),
        predictive_risk = cooldown_budget.predictive_risk and "yes" or "no",
        emergency_threshold = cooldown_budget.emergency_threshold(),
        accelerating_allies = accelerating_allies,
        exposed_target = forecast.exposed_target
            and (cooldown_budget.runtime.safe_call(forecast.exposed_target, "get_name") or "ally") or "none",
        exposed_attackers = forecast.exposed_attackers or 0,
        dampening = string.format("%.0f", dampening),
        forecast = forecast.active and (tostring(forecast.spell_id) .. ":" ..
            string.format("%.1fs", forecast.seconds) .. (forecast.group and ":group" or ":target")
            .. (forecast.learned and (":learned@" .. string.format("%.2f", forecast.confidence or 0))
                or ":active")) or "none",
        cooldown_budget = string.format("major:%.1f external:%.1f",
            core.time() - cooldown_budget.major, core.time() - cooldown_budget.external),
        manual_yield = math.max(0, manual_pause_until - core.time()),
        switches = table.concat({
            "plugin:" .. (gui.enabled:get_state() and "on" or "off"),
            "heal:" .. (gui.healing:get_state() and "on" or "off"),
            "cooldowns:" .. (gui.healing_cooldowns:get_state() and "on" or "off"),
            "defensives:" .. (gui.personals:get_state() and "on" or "off"),
            "cc:" .. (gui.auto_cc:get_state() and "on" or "off") }, ",")
    }
    Telemetry.snapshot(player, cooldown_budget.runtime.telemetry_rows(units), mode, profile.title,
        cooldown_budget.runtime.hero_build(), pressure, last_action, context)
    if gui.enabled:get_state() ~= true then return end
    if core.time() < manual_pause_until then
        local emergency_now = false
        for _, unit in ipairs(units) do
            if (cooldown_budget.runtime.health_percent(unit) or 100) <= 20 then emergency_now = true; break end
        end
        if not emergency_now then return end
    end

    if combat then
        cooldown_budget.runtime.run_auto_target(player, pressure)
        cooldown_budget.runtime.run_auto_face(player)
    end
    if not combat then
        -- Guard every automated action, even when no top-off is needed.
        if cooldown_budget.preserve_drink(player, units) then return end
        if cooldown_budget.runtime.run_auto_dispel(player) then return end
        if cooldown_budget.runtime.run_out_of_combat_topoff(player) then return end
        if cooldown_budget.runtime.run_auto_fishing(player) then return end
        if cooldown_budget.runtime.run_auto_looting(player) then return end
        if cooldown_budget.runtime.run_auto_persistent_beacons(player) then return end
        if cooldown_budget.runtime.run_auto_aura(player, false) then return end
        if cooldown_budget.runtime.run_auto_steed(player, false, units, pressure, profile) then return end
        return
    end

    local self_hp, self_current_hp, self_incoming_pct, self_time_to_danger = cooldown_budget.runtime.predicted_health_percent(player)
    local emergency = cooldown_budget.emergency_threshold()
    local self_guid = cooldown_budget.runtime.safe_call(player, "get_guid") or tostring(player)
    local self_focus = pressure.targets and pressure.targets[self_guid]
    local focused_burst = self_focus and self_focus.burst == true
    if cooldown_budget.runtime.run_pvp_cc_recovery(player, units, pressure, profile) then return end
    if gui.personals:get_state() and self_hp and self_current_hp then
        local self_forbearance = cooldown_budget.runtime.Aura.present(player, SPELL.FORBEARANCE)
        local lethal_forecast = self_incoming_pct >= 20 and self_hp <= math.min(10, emergency)
        local emergency_forecast = self_incoming_pct >= 10 and self_hp <= emergency
        local pvp_save = (focused_burst or (self_focus and self_focus.count >= 2))
            and self_hp <= math.min(75, emergency + 30)
        if not self_forbearance and (self_current_hp <= math.min(10, emergency) or lethal_forecast)
            and cooldown_budget.runtime.cast(SPELL.LAY_ON_HANDS, player, player) then
            last_defensive = core.time(); return
        end
        local self_under_go = self_focus and (self_focus.burst or self_focus.count >= 2)
        local arena_proactive_personal = mode == "arena" and self_under_go
            and (self_current_hp <= 82 or self_time_to_danger <= 3.5)
        if cooldown_budget.runtime.is_pvp_mode() and self_under_go
            and (self_current_hp <= 70 or arena_proactive_personal)
            and self_current_hp > emergency and core.time() - last_defensive > 3
            and cooldown_budget.runtime.cast(SPELL.DIVINE_PROTECTION, player, player) then
            if arena_proactive_personal then
                Telemetry.note("PREVENTION", { "action=arena_proactive_divine_protection",
                    "self_hp=" .. string.format("%.1f", self_current_hp),
                    "time_to_danger=" .. (self_time_to_danger < math.huge
                        and string.format("%.2f", self_time_to_danger) or "unknown") })
            end
            last_defensive = core.time(); return
        end
        local pve_predictive_defensive = not cooldown_budget.runtime.is_pvp_mode()
            and self_incoming_pct >= 12 and self_hp <= 65 and self_current_hp <= 82
            and self_current_hp > emergency and not emergency_forecast
        if pve_predictive_defensive and core.time() - last_defensive > 3
            and cooldown_budget.runtime.cast(SPELL.DIVINE_PROTECTION, player, player) then
            last_defensive = core.time(); return
        end
        if not self_forbearance and (self_current_hp <= emergency or emergency_forecast
            or (pvp_save and core.time() - last_defensive > 3))
            and cooldown_budget.runtime.cast(SPELL.DIVINE_SHIELD, player, player) then
            last_defensive = core.time(); return
        end
    end

    if cooldown_budget.run_pvp_self_aura_mastery(
        player, self_current_hp or 100, self_focus, profile, last_defensive) then return end

    if cooldown_budget.runtime.run_pvp_teammate_saves(player, units, pressure, profile) then return end

    local dispel_worst, dispel_projected = cooldown_budget.runtime.select_injured(player, units, pressure)
    local urgent_direct_heal = dispel_worst and ((cooldown_budget.runtime.health_percent(dispel_worst) or 100) <= 35
        or (cooldown_budget.runtime.is_pvp_mode() and (dispel_projected or 100) <= 48))
    if cooldown_budget.runtime.run_auto_dispel(player, urgent_direct_heal and 90 or 0) then return end
    if cooldown_budget.runtime.run_auto_freedom(player, units, pressure, profile) then return end
    if cooldown_budget.runtime.run_pvp_maintenance(player, units, pressure, profile) then return end
    if cooldown_budget.runtime.run_auto_steed(player, true, units, pressure, profile) then return end
    if cooldown_budget.runtime.run_pre_damage_setup(player, units, forecast) then return end

    if gui.healing:get_state() and profile.healing then
        local heal_at = (mode == "mythic_plus" and gui.heal_at:get() or profile.heal_at)
            + cooldown_budget.runtime.adaptive_offset(mode)
        local aoe_at = (mode == "mythic_plus" and gui.aoe_at:get() or profile.aoe_at)
            + cooldown_budget.runtime.adaptive_offset(mode) * 0.5
        local mana_now = cooldown_budget.runtime.mana_percent(player)
        local mana_guard = math.min(mana_now, cooldown_budget.mana_forecast or mana_now)
        if mana_guard < 20 then heal_at, aoe_at = heal_at - 4, aoe_at - 3 end
        if cooldown_budget.mana_conserve and mana_guard >= 20 then
            heal_at, aoe_at = heal_at - 2, aoe_at - 1
        end
        if cooldown_budget.runtime.is_pvp_mode() and mana_guard < 25
            and cooldown_budget.runtime.talent_selected(SPELL.DIVINE_PLEA, "Divine Plea") then
            -- Divine Plea changes the build's mana return and carries a healing
            -- tradeoff. Conserve expensive casts sooner while it is selected.
            heal_at, aoe_at = heal_at - 2, aoe_at - 2
        end
        if dampening >= 30 then heal_at = heal_at + 2 end
        local group_need = profile.group_count
        local target, hp = cooldown_budget.runtime.select_injured(player, units, pressure)
        if forecast.active and forecast.target and cooldown_budget.runtime.can_heal(player, forecast.target, SPELL.HOLY_SHOCK) then
            local forecast_hp = cooldown_budget.runtime.predicted_health_percent(forecast.target)
            if forecast_hp and (not hp or forecast_hp <= hp + 8) then
                target, hp = forecast.target, forecast_hp
            end
        end
        local hurt = cooldown_budget.runtime.injured_count(player, units, aoe_at)
        local mild_hurt = cooldown_budget.runtime.injured_count(player, units, math.min(92, math.max(85, aoe_at + 12)))
        local focused_target_state = target and pressure.targets
            and pressure.targets[cooldown_budget.runtime.safe_call(target, "get_guid") or tostring(target)]
        local pressure_save = focused_target_state
            and (focused_target_state.burst or focused_target_state.count >= 2
                or focused_target_state.swap == true or focused_target_state.ramp == true
                or (focused_target_state.focus_age or 0) >= 1.5)
        local damage_soon = forecast.active and forecast.seconds <= 2.2
        local aggregate_group_pressure = group_deficit >= 90 or predicted_group_loss >= 20
        -- Aggregate forecasting may be driven by one collapsing ally. Only
        -- choose a cone heal when at least two allies can benefit; otherwise
        -- keep the forecast response on the selected direct-heal target.
        local forecast_group_spend = aggregate_group_pressure and mild_hurt >= 2
        if (target and hp and (hp <= heal_at or pressure_save
            or (damage_soon and hp <= math.min(95, heal_at + 8))))
            or hurt >= group_need or aggregate_group_pressure
            or (damage_soon and forecast.group and mild_hurt >= 1) then
            if not target then target, hp = player, self_hp or 100 end
            local current_target_hp = cooldown_budget.runtime.health_percent(target) or hp or 100
            local holy_power = cooldown_budget.runtime.safe_call(player, "get_power", HOLY_POWER) or 0
            local spender = cooldown_budget.runtime.talent_selected(SPELL.ETERNAL_FLAME, "Eternal Flame")
                and SPELL.ETERNAL_FLAME or SPELL.WORD_OF_GLORY

            local pvp_burst_save = cooldown_budget.runtime.is_pvp_mode() and focused_target_state
                and focused_target_state.burst and current_target_hp <= profile.heal_at + 5
            local pvp_multi_save = cooldown_budget.runtime.is_pvp_mode() and focused_target_state
                and focused_target_state.count >= 2 and current_target_hp <= profile.heal_at - 5
            local pvp_last_chance = cooldown_budget.runtime.is_pvp_mode() and focused_target_state
                and focused_target_state.count >= 1 and current_target_hp <= 32
            local pvp_dampening_save = cooldown_budget.runtime.is_pvp_mode() and dampening >= 35
                and focused_target_state and focused_target_state.count >= 1
                and current_target_hp <= 58
            local mplus_cooldown_window = hurt >= group_need
                and hp <= math.max(68, heal_at - 5)
            if mode == "mythic_plus"
                and (group_deficit >= 110 or predicted_group_loss >= 25) then
                mplus_cooldown_window = true
            end
            if damage_soon and forecast.group and mild_hurt >= group_need then
                mplus_cooldown_window = true
            end
            local pvp_beacon_window = cooldown_budget.runtime.is_pvp_mode() and pressure_save
                and (hp <= heal_at + 10 or hurt > 0)
            local mplus_single_rescue = mode == "mythic_plus"
                and current_target_hp <= 45 and holy_power <= 2
            local virtue_toll_combo = cooldown_budget.runtime.is_pvp_mode()
                or mode ~= "mythic_plus"
                or hurt >= group_need + 1 or current_target_hp <= 55
                or aggregate_group_pressure
            -- Direct emergency healing and spending at cap precede temporary
            -- beacon setup or generators in every activity profile.
            local critical_heal = current_target_hp <= math.max(24, emergency)
                or (cooldown_budget.runtime.is_pvp_mode() and focused_target_state
                    and (focused_target_state.burst or focused_target_state.count >= 2)
                    and current_target_hp <= 48)
            local _, _, _, target_ttd = cooldown_budget.runtime.predicted_health_percent(target)
            critical_heal = critical_heal or target_ttd <= 2.0
            if critical_heal then
                -- Wings does not trigger the GCD. Start the selected throughput
                -- window before the emergency heal so repeated critical globals
                -- cannot keep the cooldown unreachable in any activity mode.
                if gui.healing_cooldowns:get_state() and profile.cooldowns
                    and (current_target_hp <= emergency or target_ttd <= 1.5
                        or pvp_burst_save or pvp_multi_save or pvp_last_chance
                        or mplus_cooldown_window)
                    and cooldown_budget.runtime.budget_ready("major", current_target_hp <= 25)
                    and cooldown_budget.runtime.cast(
                        cooldown_budget.runtime.talent_selected(SPELL.AVENGING_CRUSADER, "Avenging Crusader")
                            and SPELL.AVENGING_CRUSADER or SPELL.AVENGING_WRATH,
                        player, player) then
                    Telemetry.note("COOLDOWN", { "action=emergency_wings",
                        "mode=" .. tostring(mode),
                        "target_hp=" .. string.format("%.1f", current_target_hp),
                        "time_to_danger=" .. (target_ttd < math.huge
                            and string.format("%.2f", target_ttd) or "unknown") })
                    return
                end
                if cooldown_budget.healing_spender_ready(player, holy_power)
                    and cooldown_budget.runtime.cast(spender, target, player) then return end
                if cooldown_budget.runtime.cast(SPELL.HOLY_SHOCK, target, player) then return end
                if cooldown_budget.runtime.Aura.present(player, SPELL.INFUSION_OF_LIGHT)
                    and cooldown_budget.runtime.cast(SPELL.FLASH_OF_LIGHT, target, player) then return end
                if current_target_hp <= 22 and cooldown_budget.runtime.mana_percent(player) > 5
                    and cooldown_budget.runtime.cast(SPELL.FLASH_OF_LIGHT, target, player) then return end
            end
            if current_target_hp <= 90 and cooldown_budget.runtime.Aura.present(player, SPELL.DIVINE_PURPOSE)
                and cooldown_budget.runtime.cast(spender, target, player) then
                Telemetry.note("RESOURCE", { "action=divine_purpose_heal", "mode=" .. tostring(mode),
                    "holy_power=" .. tostring(holy_power), "target_hp=" .. tostring(current_target_hp) })
                return
            end
            if holy_power >= 5 then
                if (mild_hurt >= group_need or forecast_group_spend) and hp >= 80
                    and cooldown_budget.runtime.cast(SPELL.LIGHT_OF_DAWN, player, player) then
                    if forecast_group_spend then
                        Telemetry.note("HEAL", { "action=forecast_light_of_dawn",
                            "group_deficit=" .. tostring(math.floor(group_deficit + 0.5)),
                            "predicted_group_loss=" .. tostring(math.floor(predicted_group_loss + 0.5)),
                            "injured=" .. tostring(mild_hurt) })
                    end
                    return
                end
                if cooldown_budget.runtime.cast(spender, target, player) then return end
            end
            if cooldown_budget.runtime.talent_selected(SPELL.BARRIER_OF_FAITH, "Barrier of Faith")
                and not cooldown_budget.runtime.Aura.present(target, SPELL.BARRIER_OF_FAITH_ABSORB)
                and ((focused_target_state and focused_target_state.swap == true
                        and current_target_hp <= 85)
                    or (focused_target_state and focused_target_state.burst and current_target_hp <= 72)
                    or (damage_soon and forecast.target == target))
                and cooldown_budget.runtime.cast(SPELL.BARRIER_OF_FAITH, target, player) then return end
            if gui.healing_cooldowns:get_state() and profile.cooldowns then
                -- Armaments are charge-based prevention and do not require
                -- Holy Power. Put Bulwark on a newly focused arena target
                -- before committing a longer throughput cooldown, preventing
                -- Lightsmith from sitting capped while damage ramps.
                if cooldown_budget.runtime.is_pvp_mode() and pressure_save and current_target_hp <= 88
                    and cooldown_budget.runtime.talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments")
                    and cooldown_budget.runtime.budget_ready("major", current_target_hp <= 35)
                    and cooldown_budget.runtime.cast(cooldown_budget.armament_spell(), target, player) then
                    Telemetry.note("PREVENTION", { "action=pvp_proactive_holy_bulwark",
                        "target=" .. tostring(cooldown_budget.runtime.safe_call(target, "get_name") or "ally"),
                        "target_hp=" .. string.format("%.1f", current_target_hp),
                        "swap=" .. tostring(focused_target_state.swap == true) })
                    return
                end
                if mode == "mythic_plus" and mplus_cooldown_window
                    and cooldown_budget.runtime.own_aura_active(player, SPELL.DEVOTION_AURA)
                    and (hurt >= group_need + 1 or current_target_hp <= 55
                        or predicted_group_loss >= 30)
                    and cooldown_budget.runtime.budget_ready("major", current_target_hp <= 25)
                    and cooldown_budget.runtime.cast(SPELL.AURA_MASTERY, player, player) then return end
                if (pvp_burst_save or pvp_multi_save or pvp_last_chance
                    or pvp_dampening_save or mplus_cooldown_window)
                    and cooldown_budget.runtime.budget_ready("major", pvp_last_chance or current_target_hp <= 25) then
                    local wings = cooldown_budget.runtime.talent_selected(SPELL.AVENGING_CRUSADER, "Avenging Crusader")
                        and SPELL.AVENGING_CRUSADER or SPELL.AVENGING_WRATH
                    -- Wings is off-GCD, so start throughput before spending a
                    -- healing global. The cast path still observes its normal
                    -- request/event latch and cooldown readiness.
                    if cooldown_budget.runtime.cast(wings, player, player) then return end
                end
                -- Establish Virtue before Divine Toll so Toll's Holy Shocks
                -- land inside the temporary beacon transfer window.
                if gui.auto_beacon:get_state() == true
                    and (mild_hurt >= group_need or pvp_beacon_window or aggregate_group_pressure)
                    and virtue_toll_combo
                    and (mana_guard >= 15 or current_target_hp <= 55 or pvp_last_chance)
                    and cooldown_budget.runtime.talent_selected(SPELL.BEACON_OF_VIRTUE, "Beacon of Virtue")
                    and core.time() - last_beacon_virtue_confirmed >= 7.5
                    and not cooldown_budget.runtime.Aura.present(target, SPELL.BEACON_OF_VIRTUE)
                    and cooldown_budget.runtime.cast(SPELL.BEACON_OF_VIRTUE, target, player) then return end
                if (mild_hurt >= group_need or aggregate_group_pressure or mplus_single_rescue
                        or pressure_save or pvp_last_chance)
                    and cooldown_budget.runtime.budget_ready("major", pvp_last_chance or current_target_hp <= 25) then
                    local lightsmith = cooldown_budget.runtime.talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments")
                    if lightsmith then
                        if cooldown_budget.runtime.cast(cooldown_budget.armament_spell(), target, player) then
                            if mplus_single_rescue then
                                Telemetry.note("PREVENTION", { "action=mplus_lightsmith_armament_rescue",
                                    "target_hp=" .. string.format("%.1f", current_target_hp) })
                            end
                            return
                        end
                    elseif holy_power <= 2
                        and cooldown_budget.runtime.talent_selected(SPELL.DIVINE_TOLL, "Divine Toll")
                        and (virtue_toll_combo
                            or not cooldown_budget.runtime.Aura.present(target, SPELL.BEACON_OF_VIRTUE))
                        and cooldown_budget.runtime.cast(SPELL.DIVINE_TOLL, target, player) then
                        if mplus_single_rescue then
                            Telemetry.note("PREVENTION", { "action=mplus_divine_toll_single_rescue",
                                "target_hp=" .. string.format("%.1f", current_target_hp) })
                        end
                        return
                    end
                end
            end

            if gui.auto_beacon:get_state() == true
                and (mild_hurt >= group_need or pvp_beacon_window or aggregate_group_pressure)
                and (mana_guard >= 15 or current_target_hp <= 55 or pvp_last_chance)
                and cooldown_budget.runtime.talent_selected(SPELL.BEACON_OF_VIRTUE, "Beacon of Virtue")
                and core.time() - last_beacon_virtue_confirmed >= 7.5
                and not cooldown_budget.runtime.Aura.present(target, SPELL.BEACON_OF_VIRTUE)
                and cooldown_budget.runtime.cast(SPELL.BEACON_OF_VIRTUE, target, player) then return end

            if (mild_hurt >= group_need or aggregate_group_pressure) and holy_power <= 2
                and cooldown_budget.runtime.talent_selected(SPELL.HOLY_PRISM, "Holy Prism") then
                local enemy = cooldown_budget.runtime.safe_call(player, "get_target")
                if cooldown_budget.prism_enemy_coverage(player, enemy, units,
                        math.min(92, math.max(85, aoe_at + 12)), group_need)
                    and cooldown_budget.runtime.cast(SPELL.HOLY_PRISM, enemy, player) then return end
                -- Holy Prism accepts either disposition: a hostile primary
                -- heals nearby allies, while a friendly primary supplies the
                -- direct healing path and damages nearby enemies. Preserve the
                -- group-heal global when no safe hostile target is available.
                if cooldown_budget.prism_friendly_safe(player, target)
                    and cooldown_budget.runtime.cast(SPELL.HOLY_PRISM, target, player) then return end
            end

            local has_infusion = cooldown_budget.runtime.Aura.present(player, SPELL.INFUSION_OF_LIGHT)
            if cooldown_budget.runtime.is_pvp_mode() and cooldown_budget.runtime.talent_selected(SPELL.CLEANSE_THE_WEAK, "Cleanse the Weak")
                and cooldown_budget.runtime.has_poison_or_disease(target) and hp <= 85 and cooldown_budget.runtime.mana_percent(player) > 12 then
                if cooldown_budget.runtime.cast(SPELL.FLASH_OF_LIGHT, target, player) then return end
                if cooldown_budget.runtime.cast(SPELL.HOLY_LIGHT, target, player) then return end
            end
            if has_infusion and hp <= 92 and cooldown_budget.runtime.mana_percent(player) > 15 then
                local infusion_target = target
                if hp > 45 and cooldown_budget.runtime.talent_selected(SPELL.MOMENT_OF_COMPASSION, "Moment of Compassion") then
                    local beacon_target, beacon_hp = cooldown_budget.runtime.select_beaconed_injured(player, units)
                    if beacon_target and beacon_hp <= hp + 10 then infusion_target = beacon_target end
                end
                if cooldown_budget.runtime.cast(SPELL.FLASH_OF_LIGHT, infusion_target, player) then return end
            end
            if cooldown_budget.runtime.cast(SPELL.HOLY_SHOCK, target, player) then return end

            if cooldown_budget.healing_spender_ready(player, holy_power) and (hp <= math.max(72, heal_at - 8)
                    or hurt >= group_need or aggregate_group_pressure) then
                local dawn_stacks = cooldown_budget.runtime.talent_selected(SPELL.DARKEST_BEFORE_DAWN, "Darkest before the Dawn")
                    and (cooldown_budget.darkest_stacks or 0) or 0
                if cooldown_budget.runtime.is_pvp_mode() and dawn_stacks >= 4 and mild_hurt >= 2
                    and cooldown_budget.runtime.cast(SPELL.LIGHT_OF_DAWN, player, player) then
                    Telemetry.note("HEAL", { "action=empowered_light_of_dawn",
                        "stacks=" .. tostring(dawn_stacks), "injured=" .. tostring(mild_hurt) })
                    return
                end
                if (mild_hurt >= group_need or forecast_group_spend) and hp >= 80
                    and cooldown_budget.runtime.cast(SPELL.LIGHT_OF_DAWN, player, player) then
                    if forecast_group_spend then
                        Telemetry.note("HEAL", { "action=forecast_light_of_dawn",
                            "group_deficit=" .. tostring(math.floor(group_deficit + 0.5)),
                            "predicted_group_loss=" .. tostring(math.floor(predicted_group_loss + 0.5)),
                            "injured=" .. tostring(mild_hurt) })
                    end
                    return
                end
                if cooldown_budget.runtime.cast(spender, target, player) then return end
            end
            -- Judgment belongs to the PvP healing resource loop. If Holy
            -- Shock is unavailable and the ally is stable enough for one
            -- generator global, build Holy Power without enabling damage mode.
            if holy_power < 3 and current_target_hp >= 60 and hp >= 60
                and not critical_heal and not pressure_save and not damage_soon
                and not aggregate_group_pressure and not has_infusion and mana_now > 10 then
                local generator_enemy = cooldown_budget.runtime.healing_conversion_enemy(player, focused_target_state, 30)
                if generator_enemy and cooldown_budget.runtime.cast(SPELL.JUDGMENT, generator_enemy, player) then
                    Telemetry.note("RESOURCE", { "action=healing_judgment_generator", "mode=" .. tostring(mode),
                        "holy_power=" .. tostring(holy_power),
                        "ally_hp=" .. string.format("%.1f", current_target_hp) })
                    return
                end
            end
            if hp <= 42 and mana_guard > 15
                and cooldown_budget.runtime.cast(SPELL.FLASH_OF_LIGHT, target, player) then return end

            -- Avenging Crusader turns melee/damage globals into healing. Use
            -- those generators only during its confirmed window, only while
            -- nearby allies need healing, and only below Holy Power cap.
            if mild_hurt >= group_need and holy_power < 4 then
                local active_crusader = cooldown_budget.runtime.Aura.present(player, SPELL.AVENGING_CRUSADER)
                local active_wrath = cooldown_budget.runtime.Aura.present(player, SPELL.AVENGING_WRATH)
                local enemy = cooldown_budget.runtime.healing_conversion_enemy(player, focused_target_state, 30)
                if enemy then
                    if (active_crusader or active_wrath)
                        and cooldown_budget.runtime.spell_known(SPELL.HAMMER_OF_WRATH)
                        and cooldown_budget.runtime.cast(SPELL.HAMMER_OF_WRATH, enemy, player) then return end
                    if active_crusader and distance(player, enemy) <= 5
                        and cooldown_budget.runtime.cast(SPELL.CRUSADER_STRIKE, enemy, player) then return end
                    if (active_crusader or active_wrath)
                        and cooldown_budget.runtime.cast(SPELL.JUDGMENT, enemy, player) then return end
                end
                if active_crusader then
                    local melee_enemy = cooldown_budget.runtime.healing_conversion_enemy(player, focused_target_state, 5)
                    if melee_enemy and melee_enemy ~= enemy
                        and cooldown_budget.runtime.cast(SPELL.CRUSADER_STRIKE, melee_enemy, player) then return end
                end
            end

            local mana = mana_guard
            if hp <= 47 and holy_power == 0 and not has_infusion
                and (mana > 20 or (hp <= 25 and mana > 5))
                and cooldown_budget.runtime.cast(SPELL.HOLY_LIGHT, target, player) then return end

            -- When healing is unavailable, the guarded emergency peel can
            -- still stop a confirmed attacker. Urgent healing above wins;
            -- run_auto_pvp_cc suppresses routine setups while healing is due.
            if cooldown_budget.runtime.run_auto_pvp_cc(player, units, pressure, profile) then return end

            local enemy = cooldown_budget.runtime.safe_call(player, "get_target")
            if mode ~= "arena" and profile.damage and gui.damage:get_state() and holy_power < 5
                and cooldown_budget.safe_to_damage(player, enemy)
                and cooldown_budget.runtime.cast(SPELL.JUDGMENT, enemy, player) then return end
            -- A failed or unavailable healing spell must not send the same
            -- tick into offensive Holy Power spending or maintenance.
            return
        end
    end

    if cooldown_budget.runtime.run_auto_pvp_cc(player, units, pressure, profile) then return end
    if not cooldown_budget.runtime.pvp_healing_urgent(player, units, pressure, profile) then
        if cooldown_budget.runtime.run_auto_persistent_beacons(player) then return end
        if cooldown_budget.runtime.run_auto_aura(player, true) then return end
    end

    if current_mode == "arena" then
        cooldown_budget.run_arena_damage(player, units, pressure, profile)
        return
    end
    -- Current Mythic+ priorities favor using hero charges frequently. This
    -- path runs only after the healing block declined to act, so it cannot
    -- replace an urgent heal. Keep Lightsmith recharging with Bulwark first,
    -- then Sacred Weapon, even when the party is presently stable.
    if (current_mode == "mythic_plus" or current_mode == "training")
        and gui.healing_cooldowns:get_state() == true then
        cooldown_budget.maintenance_target = cooldown_budget.runtime.select_injured(player, units, pressure)
        if cooldown_budget.runtime.talent_selected(SPELL.HOLY_ARMAMENTS, "Holy Armaments") then
            if cooldown_budget.runtime.valid(cooldown_budget.maintenance_target)
                and cooldown_budget.runtime.cast(cooldown_budget.armament_spell(),
                    cooldown_budget.maintenance_target, player) then
                Telemetry.note("PREVENTION", { "action=mplus_armament_maintenance",
                    "armament=alternating_button",
                    "target=" .. tostring(cooldown_budget.runtime.safe_call(cooldown_budget.maintenance_target,
                        "get_name") or "ally") })
                return
            end
        end
        cooldown_budget.maintenance_target = nil
    end

    local target = cooldown_budget.runtime.safe_call(player, "get_target")
    if not cooldown_budget.safe_to_damage(player, target) then return end
    -- Herald and common M+ talent cooldowns are used during a safe damage
    -- global instead of being held indefinitely for a large healing event.
    -- Divine Toll remains below three Holy Power to avoid wasting generation.
    if (current_mode == "mythic_plus" or current_mode == "training")
        and gui.healing_cooldowns:get_state() == true then
        cooldown_budget.idle_holy_power = cooldown_budget.runtime.safe_call(player, "get_power", HOLY_POWER) or 0
        if not cooldown_budget.predictive_risk and cooldown_budget.idle_holy_power <= 2
            and cooldown_budget.runtime.talent_selected(SPELL.DIVINE_TOLL, "Divine Toll")
            and cooldown_budget.runtime.cast(SPELL.DIVINE_TOLL, target, player) then
            Telemetry.note("RESOURCE", { "action=mplus_divine_toll_maintenance",
                "holy_power=" .. tostring(cooldown_budget.idle_holy_power) })
            return
        end
        if not cooldown_budget.predictive_risk and cooldown_budget.idle_holy_power <= 2
            and cooldown_budget.runtime.talent_selected(SPELL.HOLY_PRISM, "Holy Prism")
            and cooldown_budget.runtime.cast(SPELL.HOLY_PRISM, target, player) then
            Telemetry.note("RESOURCE", { "action=mplus_holy_prism_maintenance",
                "holy_power=" .. tostring(cooldown_budget.idle_holy_power) })
            return
        end
    end
        -- Rebuke is not available to Holy Paladin in the current PvP ruleset;
        -- PvP uses the guarded Hammer of Justice control path above instead.
        if not cooldown_budget.runtime.is_pvp_mode() and gui.interrupt:get_state()
            and cooldown_budget.runtime.safe_call(target, "is_casting_spell") == true
        and cooldown_budget.runtime.safe_call(target, "is_active_spell_interruptable") == true then
        if cooldown_budget.runtime.cast(SPELL.REBUKE, target, player, false, true) then return end
        if cooldown_budget.runtime.cast(SPELL.HAMMER_OF_JUSTICE, target, player) then return end
    end
    if gui.damage:get_state() and profile.damage then
        if cooldown_budget.predictive_risk then return end
        local holy_power = cooldown_budget.runtime.safe_call(player, "get_power", HOLY_POWER) or 0
        -- Spend only at cap during idle PvE, keeping more Holy Power ready
        -- between damage casts. Training keeps its damage loop.
        if holy_power >= (current_mode == "training" and 4 or 5)
            and cooldown_budget.runtime.cast(SPELL.SHIELD_OF_THE_RIGHTEOUS, target, player) then return end
        local shock_charges = cooldown_budget.runtime.read_core(core.spell_book.get_spell_charge, SPELL.HOLY_SHOCK) or 0
        if shock_charges >= 2 and cooldown_budget.runtime.cast(SPELL.HOLY_SHOCK, target, player) then return end
        -- Current Mythic+ guidance values Judgment on cooldown for its
        -- Consecration interaction. Avoid wasting capped Holy Shock charges.
        if cooldown_budget.runtime.cast(SPELL.JUDGMENT, target, player) then return end
        if cooldown_budget.runtime.cast(SPELL.HOLY_SHOCK, target, player) then return end
        if cooldown_budget.runtime.cast(SPELL.CRUSADER_STRIKE, target, player) then return end
    end
end

core.register_on_spell_cast_callback(function(data)
    if type(data) ~= "table" then return end
    local player = core.object_manager.get_local_player()
    if not valid(player) or not is_holy_paladin(player) then return end
    if pvp_helper and type(pvp_helper.on_spell) == "function" then pcall(pvp_helper.on_spell, pvp_helper, data) end
    local caster_guid, player_guid = safe_call(data.caster, "get_guid"), safe_call(player, "get_guid")
    if caster_guid and player_guid and caster_guid == player_guid then
        confirm_player_spell(tonumber(data.spell_id), data.target)
    end
end)
local function current_holy_player()
    local player = core.object_manager.get_local_player()
    return valid(player) and is_holy_paladin(player) and player or nil
end
if type(core.register_on_legit_spell_cast_callback) == "function" then
    core.register_on_legit_spell_cast_callback(function(data)
        if not current_holy_player() then return end
        local spell_id = type(data) == "table" and tonumber(data.spell_id)
            or tonumber(data)
        manual_pause_until = core.time() + 0.75
        Telemetry.note("MANUAL", { "spell_id=" .. tostring(spell_id or "unknown"),
            "yield_seconds=0.75" })
    end)
end
core.register_on_render_menu_callback(function()
    if current_holy_player() then render_menu() end
end)
local last_overheal_cancel = -math.huge
local function cancel_redundant_hardcast(player)
    if not pending_cast or not core.input or type(core.input.cancel_spells) ~= "function"
        or safe_call(player, "is_casting_spell") ~= true then return false end
    if pending_cast.spell_id ~= SPELL.HOLY_LIGHT
        and pending_cast.spell_id ~= SPELL.FLASH_OF_LIGHT then return false end
    local target = pending_cast.target
    if core.time() - last_overheal_cancel < 0.30 then return false end
    local function cancel_for(reason, details)
        local ok, accepted = pcall(core.input.cancel_spells)
        if not ok or accepted == false then return false end
        last_overheal_cancel = core.time()
        pending_cast.expires = math.min(pending_cast.expires, core.time() + 0.18)
        Telemetry.note("HEAL", { "action=cancel_hardcast", "reason=" .. reason,
            "spell_id=" .. tostring(pending_cast.spell_id),
            "target=" .. tostring(safe_call(target, "get_name") or "ally"),
            details or "details=none" })
        return true
    end
    if not valid(target) then return cancel_for("target_invalid") end
    if not can_heal(player, target, pending_cast.spell_id) then
        return cancel_for("target_unreachable")
    end
    local projected, current = predicted_health_percent(target)
    if not projected or not current then return false end
    if current >= 98 and projected >= 95 then
        return cancel_for("target_recovered", "current=" .. string.format("%.1f", current)
            .. ",projected=" .. string.format("%.1f", projected))
    end

    -- Redirect a long heal only for a clear emergency upgrade. The current
    -- target must be comfortably above the mode's emergency floor, preventing
    -- oscillation between two simultaneously critical allies.
    local emergency_floor = cooldown_budget.emergency_threshold()
    local emergency_target, emergency_hp = nil, 101
    for _, unit in ipairs(group_units(player)) do
        local hp = predicted_health_percent(unit)
        if unit ~= target and hp and hp < emergency_hp
            and can_heal(player, unit, pending_cast.spell_id) then
            emergency_target, emergency_hp = unit, hp
        end
    end
    if emergency_target and emergency_hp <= emergency_floor
        and projected >= emergency_floor + 18 then
        return cancel_for("redirect_emergency",
            "new_target=" .. tostring(safe_call(emergency_target, "get_name") or "ally")
            .. ",new_projected=" .. string.format("%.1f", emergency_hp)
            .. ",old_projected=" .. string.format("%.1f", projected))
    end
    return false
end
local function render_window()
    if not current_holy_player() then
        pcall(PaladinGui.render, { window_open = false }, gui_action)
        return
    end
    local ok, err = pcall(PaladinGui.render, gui_state(), gui_action)
    if not ok and type(core.log_warning) == "function" then
        pcall(core.log_warning, "[Holy Paladin GUI] " .. tostring(err))
    end
end
if type(core.register_on_render_window_callback) == "function" then
    core.register_on_render_window_callback(render_window)
elseif type(core.register_on_render_callback) == "function" then
    core.register_on_render_callback(render_window)
end
if type(core.register_on_render_callback) == "function" then
    core.register_on_render_callback(function()
        local player = current_holy_player()
        if not player then pcall(BossGuide.draw, nil, {}, false); return end
        cooldown_budget.begin_object_snapshot()
        local ok, allies = pcall(group_units, player)
        if ok then
            local lines_ok, lines_error = pcall(ArenaLines.draw, player, allies, gui.arena_lines:get_state() == true,
                current_mode == "arena", SPELL.HOLY_SHOCK)
            if not lines_ok then pcall(Telemetry.error, "arena_lines", lines_error) end
            local guide_ok, guide_error = pcall(BossGuide.draw, player, allies, gui.boss_guide:get_state() == true)
            if not guide_ok then pcall(Telemetry.error, "boss_guide", guide_error) end
        else
            pcall(Telemetry.error, "visual_roster", allies)
        end
        local danger_ok, danger_error = pcall(DangerZones.draw, player, gui.danger_zones:get_state() == true)
        if not danger_ok then pcall(Telemetry.error, "danger_zones", danger_error) end
        cooldown_budget.end_object_snapshot()
    end)
end
local last_update_error = -math.huge
local function safe_update()
    local identity_ok, player = pcall(current_holy_player)
    if not identity_ok then pcall(Telemetry.error, "player_identity", player); return end
    local diagnostic_player = player or read_core(core.object_manager.get_local_player)
    pcall(Telemetry.set_enabled, safe_call(gui.debug_log, "get_state") == true)
    pcall(Telemetry.runtime_status, player and "holy_ready" or "waiting_holy", {
        "plugin_enabled=" .. tostring(safe_call(gui.enabled, "get_state") == true),
        "class=" .. tostring(safe_call(diagnostic_player, "get_class") or "unknown"),
        "spec=" .. tostring(safe_call(diagnostic_player, "get_specialization_id") or "unknown"),
        "dead=" .. tostring(safe_call(diagnostic_player, "is_dead")),
        "mode=" .. tostring(current_mode),
        "combat=" .. tostring(player and safe_call(player, "is_in_combat") == true or false) })
    if player then
        local cancel_ok, cancelled = pcall(cancel_redundant_hardcast, player)
        if not cancel_ok then pcall(Telemetry.error, "cancel_hardcast", cancelled)
        elseif cancelled then return end
    end
    cooldown_budget.begin_object_snapshot()
    local ok, err = pcall(update)
    cooldown_budget.end_object_snapshot()
    if not ok then
        pcall(Telemetry.error, "update", err)
        if core.time() - last_update_error >= 10 and type(core.log_warning) == "function" then
            pcall(core.log_warning, "[Holy Paladin] " .. tostring(err))
            last_update_error = core.time()
        end
    end
end
if type(core.register_on_game_event_callback) == "function" then
    core.register_on_game_event_callback(function(event, args)
        if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_ENTERING_WORLD" then
            -- Loading screens, disconnect recovery, and character changes can
            -- invalidate object handles and cast GUIDs. Keep learned settings
            -- and logs, but discard only transient combat state.
            pending_cast, next_spell_request_at = nil, 0
            pending_outcomes, health_history = {}, {}
            spell_retry_after, spell_failure_streak = {}, {}
            cooldown_budget.spell_failure_time = {}
            cooldown_budget.end_object_snapshot()
            cooldown_budget.hotkey_down, cooldown_budget.next_hotkey_poll = {}, -math.huge
            cooldown_budget.predictive_risk = false
            cooldown_budget.arena_health = {}
            cooldown_budget.mana_burn, cooldown_budget.mana_forecast = nil, nil
            cooldown_budget.mana_time_to_critical, cooldown_budget.mana_conserve = nil, false
            mana_sample = { percent = nil, time = -math.huge, burn = 0 }
            manual_pause_until = 0
            last_triage = { guid = nil, unit = nil, time = -math.huge }
            cooldown_budget.enemy_targets, cooldown_budget.swap_windows = {}, {}
            cooldown_budget.pressure_focus = {}
            cooldown_budget.cast_patterns = {}
            cooldown_budget.pvp_active = false
            pvp_combat_started_at = -math.huge
            talent_cache, talent_cache_time = nil, -math.huge
            cooldown_budget.mode_candidate, cooldown_budget.mode_candidate_since = nil, -math.huge
        end
        -- Logout can invalidate the player handle before this callback runs.
        -- Close the Holy logger first; this module was loaded only after a
        -- positive Holy identity check, so lifecycle output remains isolated.
        if event == "PLAYER_LOGOUT" then pcall(Telemetry.lifecycle, event) end
        -- The plugin can remain resident after a character/spec swap. Do not
        -- pollute the Holy Paladin log or state with another class's casts.
        if not current_holy_player() then return end
        local spell_id = type(args) == "table" and (tonumber(args[3]) or tonumber(args[4])) or nil
        local matched = type(args) == "table" and args[1] == "player" and pending_cast
            and spell_id == pending_cast.spell_id
            and (not pending_cast.cast_guid or args[2] == pending_cast.cast_guid)
        local ok, err = pcall(Telemetry.event, event, args, matched == true)
        if not ok then pcall(Telemetry.error, "event", err) end
        if type(args) == "table" and args[1] == "player" then
            if event == "UNIT_SPELLCAST_SENT" and pending_cast then
                local sent_id = tonumber(args[4])
                if sent_id == pending_cast.spell_id then pending_cast.cast_guid = args[3] end
            elseif event == "UNIT_SPELLCAST_START" and matched then
                pending_cast.cast_guid = args[2]
                pending_cast.expires = math.max(pending_cast.expires, core.time() + 6)
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                confirm_player_spell(spell_id, matched and pending_cast.target or nil)
            end
            if matched and (event == "UNIT_SPELLCAST_SUCCEEDED"
                or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
                or event == "UNIT_SPELLCAST_INTERRUPTED") then
                pending_cast = nil
                if event == "UNIT_SPELLCAST_SUCCEEDED" then
                    spell_failure_streak[spell_id] = 0
                    cooldown_budget.spell_failure_time[spell_id] = nil
                    spell_retry_after[spell_id] = nil
                    next_spell_request_at = math.max(next_spell_request_at, core.time() + 0.35)
                elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
                    cooldown_budget.record_spell_failure(spell_id, 0.25)
                else
                    spell_retry_after[spell_id] = core.time() + 0.45
                end
            end
        end
    end)
end
core.register_on_update_callback(safe_update)

return { main = function() return true end, update = safe_update,
    mode = effective_mode, profiles = profiles, telemetry = Telemetry }
