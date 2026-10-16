-- Ret Paladin panel built on the stable Holy Paladin GUI structure.
-- The only layout change is the Resto Shaman-style two-row tab grid.
local M = {}
local color, vec2, enums, window
local art_texture, art_attempted_at = nil, -math.huge
local page, win_x, win_y = 1, 45, 45
local page_follows_auto = true
local settings_scroll = 0
local dragging, mouse_was_down, reported = nil, false, false
local f1_was_down, visible = false, true
local initialization_error = nil
local panel_w, panel_h = 1000, 760
local labels = { "MYTHIC+", "DELVE", "WORLD PvE", "ARENA", "BATTLEGROUND", "WORLD PvP",
    "COMBAT", "DEFENSE", "SUPPORT", "MOVEMENT", "VISUALS", "GATHERING", "HOTKEYS", "LOGS" }
local modes = { "mythic_plus", "delve", "world_pve", "arena", "battleground", "world_pvp" }
local ICON = {
    wings = "WG", verdict = "JV", shield = "DS", hammer = "HJ",
    heal = "HL", freedom = "BF", movement = "CS", route = "RT",
    gather = "SK", hotkey = "HK", logs = "DB",
}
local NAV_ICON = { "M+", "DV", "WP", "AR", "BG", "PK", "JV", "DS",
    "HL", "CS", "EY", "SK", "HK", "DB" }
local TAB_THEME = {
    { 92, 225, 133 }, { 230, 170, 74 }, { 132, 218, 110 },
    { 244, 91, 82 }, { 92, 164, 238 }, { 186, 104, 232 },
    { 239, 197, 98 }, { 91, 190, 234 }, { 88, 224, 145 },
    { 245, 189, 72 }, { 181, 119, 241 }, { 65, 208, 177 },
    { 241, 144, 65 }, { 96, 220, 133 },
}

-- Do not create any window during standalone script discovery. Some Project
-- Sylvanas builds surface every created window even after set_visibility(false).
-- Creation happens only after the Ret runtime supplies an eligible state.
local function initialize_window()
    if window then return true end
    local initialized, init_error = pcall(function()
        color = require("common/color")
        vec2 = require("common/geometry/vector_2")
        enums = require("common/enums")
        window = core.menu.window("ret_paladin_turalyon_200")
        window:set_initial_position(vec2.new(win_x, win_y))
        window:set_initial_size(vec2.new(panel_w, panel_h))
        if type(window.set_render_layer) == "function" then window:set_render_layer(1) end
        window:set_visibility(false)
    end)
    if not initialized then
        initialization_error = tostring(init_error)
        window = nil
        return false
    end
    return true
end

local function c(r, g, b, a) return color.new(r, g, b, a or 255) end
local function rect(x1, y1, x2, y2, col, radius)
    window:render_rect_filled(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5)
end
local function outline(x1, y1, x2, y2, col, radius, thickness)
    window:render_rect(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5, thickness or 1)
end
local function clean(value)
    local value_text = tostring(value or "")
    value_text = value_text:gsub("\226\128\162", " | ")
        :gsub("\226\128\148", " - "):gsub("\226\128\147", "-")
        :gsub("\226\128\153", "'"):gsub("\226\128\152", "'")
        :gsub("[%c]", " ")
    return value_text
end
local function text(value, x, y, font, col)
    window:render_text(type(font) == "number" and font or 0,
        vec2.new(x, y), col, clean(value))
end
local function clicked(x1, y1, x2, y2)
    return window:is_rect_clicked(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function hovered(x1, y1, x2, y2)
    return window:is_mouse_hovering_rect(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function compact(value, limit)
    value = clean(value)
    return require('mf_i18n').clip(require('mf_i18n').text(value),limit)
end
local function icon_tile(icon, x1, y1, x2, y2, accent, active)
    local edge = accent or c(214, 177, 93, 245)
    rect(x1, y1, x2, y2, active and c(48, 38, 15, 252) or c(5, 24, 14, 250), 5)
    outline(x1, y1, x2, y2, edge, 5, active and 2 or 1)
    rect(x1 + 4, y1 + 4, x2 - 4, y1 + 7, edge, 2)
    rect(x1 + 5, y2 - 7, x2 - 5, y2 - 4, c(126, 90, 31, 220), 2)
    text(icon or "PA", x1 + 8, y1 + 10, 0,
        active and c(255, 239, 184) or c(232, 218, 168))
end
local function button(label, x1, y1, x2, y2, on_click, active, font, accent)
    local over = hovered(x1, y1, x2, y2)
    local active_color = accent or c(214, 177, 93, 250)
    rect(x1, y1, x2, y2, active and active_color
        or (over and c(49, 126, 75, 240) or c(19, 54, 34, 224)), 5)
    text(label, x1 + 10, y1 + 10, font or 0,
        active and c(30, 22, 10) or c(244, 255, 247))
    if active or over then
        outline(x1, y1, x2, y2, active and active_color
            or c(122, 239, 157, 245), 5, active and 2 or 1)
    end
    if clicked(x1, y1, x2, y2) then on_click() end
end
local function image_button(label, icon, x1, y1, x2, y2, on_click, active, font)
    local over = hovered(x1, y1, x2, y2)
    rect(x1, y1, x2, y2, active and c(214, 177, 93, 250)
        or (over and c(49, 126, 75, 240) or c(19, 54, 34, 224)), 5)
    icon_tile(icon, x1 + 5, y1 + 4, x1 + 39, y2 - 4,
        active and c(255, 231, 154) or c(96, 220, 133), active)
    text(label, x1 + 47, y1 + 10, font or 0,
        active and c(30, 22, 10) or c(244, 255, 247))
    if active or over then
        outline(x1, y1, x2, y2, active and c(255, 231, 154, 255)
            or c(122, 239, 157, 245), 5, active and 2 or 1)
    end
    if clicked(x1, y1, x2, y2) then on_click() end
end
local function hotkey_label(binding)
    local code=binding and binding.get_key_code and binding:get_key_code() or 0
    return code and code>0 and ("KEY "..tostring(code)) or "UNBOUND"
end
local function toggle_row(label, value, x, y, x2, on_click, note, font, icon, binding)
    local over = hovered(x, y, x2, y + 45)
    rect(x, y, x2, y + 45, over and c(25, 72, 43, 238) or c(12, 39, 24, 230), 5)
    icon_tile(icon, x + 6, y + 5, x + 42, y + 40,
        value == true and c(255, 221, 125) or c(75, 157, 99), value == true)
    local text_x = x + 52
    text(compact(label, 31), text_x, y + 6, font or 0, c(249, 255, 250))
    if note and note ~= "" then text(compact(note, 36), text_x, y + 26, font or 0, c(198, 229, 206)) end
    local enabled = value == true
    rect(x2 - 166, y + 10, x2 - 82, y + 35, c(8, 29, 18, 244), 5)
    outline(x2 - 166, y + 10, x2 - 82, y + 35, c(92, 158, 111, 220), 5, 1)
    text(hotkey_label(binding), x2 - 157, y + 15, font or 0, c(230, 218, 168))
    rect(x2 - 75, y + 10, x2 - 14, y + 35,
        enabled and c(96, 220, 133) or c(73, 88, 77), 6)
    text(enabled and "ON" or "OFF", x2 - 58, y + 15, font or 0,
        enabled and c(9, 34, 18) or c(247, 250, 248))
    if over then outline(x, y, x2, y + 45, c(122, 239, 157, 245), 5, 1) end
    if clicked(x, y, x2, y + 45) then on_click() end
end

local function mouse_wheel_delta()
    local candidates = {
        core.input and core.input.get_mouse_wheel_delta,
        core.get_mouse_wheel_delta,
        core.graphics and core.graphics.get_mouse_wheel_delta,
    }
    for _, getter in ipairs(candidates) do
        if type(getter) == "function" then
            local ok, value = pcall(getter)
            if ok and type(value) == "number" and value ~= 0 then return value end
        end
    end
    return 0
end

function M.poll_hotkey()
    if not core.input or type(core.input.is_key_pressed) ~= "function" then return end
    local ok, down = pcall(core.input.is_key_pressed, 0x70)
    down = ok and down == true
    if down and not f1_was_down then visible = not visible end
    f1_was_down = down
end

function M.hide()
    if window then window:set_visibility(false) end
end

function M.render(state, action)
    local eligible = state and state.eligible == true
    if not eligible then
        if window then window:set_visibility(false) end
        return
    end
    if not initialize_window() then return false, "GUI window initialization failed: "
        .. tostring(initialization_error or "core.menu.window unavailable") end
    window:set_visibility(visible and eligible)
    if not visible or not eligible then return end
    if state.auto_mode and page_follows_auto then
        for index, key in ipairs(modes) do
            if key == state.active_mode then page = index; break end
        end
    end
    local ok, err = pcall(function()
        local mouse_down, cursor = false, nil
        if type(core.get_cursor_position) == "function" then cursor = core.get_cursor_position() end
        if core.input and type(core.input.is_key_pressed) == "function" then
            local mok, pressed = pcall(core.input.is_key_pressed, 0x01)
            mouse_down = mok and pressed == true
        end
        if cursor and mouse_down and not mouse_was_down and cursor.x >= win_x
            and cursor.x <= win_x + panel_w and cursor.y >= win_y and cursor.y <= win_y + 72 then
            dragging = { dx = cursor.x - win_x, dy = cursor.y - win_y }
            if core.graphics and type(core.graphics.capture_next_mouse_input) == "function" then
                pcall(core.graphics.capture_next_mouse_input)
            end
        end
        if dragging and mouse_down and cursor then
            win_x, win_y = math.max(0, cursor.x - dragging.dx), math.max(0, cursor.y - dragging.dy)
            if core.graphics and type(core.graphics.set_mouse_capture_state) == "function" then
                pcall(core.graphics.set_mouse_capture_state, true)
            end
        elseif dragging and not mouse_down then
            dragging = nil
            if core.graphics and type(core.graphics.set_mouse_capture_state) == "function" then
                pcall(core.graphics.set_mouse_capture_state, false)
            end
        end
        mouse_was_down = mouse_down

        local we = enums.window_enums or enums
        local flags, visuals = we.window_resizing_flags or {}, we.window_cross_visuals or {}
        local font = we.font_id or {}
        if type(window.set_next_window_min_size) == "function" then
            window:set_next_window_min_size(vec2.new(panel_w, panel_h))
        end
        if type(window.force_window_size) == "function" then window:force_window_size(vec2.new(panel_w, panel_h)) end
        if type(window.force_next_begin_window_pos) == "function" then
            window:force_next_begin_window_pos(vec2.new(win_x, win_y))
        end
        window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0, false,
            c(7, 18, 11, 255), c(83, 211, 122, 255), visuals.NO_CROSS or 9, function()
            local now = type(core.time) == "function" and core.time() or 0
            if not art_texture and now - art_attempted_at >= 3 then
                art_attempted_at = now
                if core.graphics and type(core.graphics.load_texture) == "function" then
                    local loaded, texture = pcall(function()
                        return core.graphics.load_texture(require("ret_paladin_art"))
                    end)
                    if loaded then art_texture = texture end
                end
            end
            if art_texture and core.graphics and type(core.graphics.draw_texture) == "function" then
                local position = type(window.get_position) == "function"
                    and window:get_position() or vec2.new(win_x, win_y)
                pcall(core.graphics.draw_texture, art_texture,
                    vec2.new(position.x, position.y), panel_w, panel_h,
                    c(255, 255, 255, 255), true)
            else
                -- Native fallback while the embedded texture is queued/unavailable.
                rect(1, 1, 998, 758, c(5, 16, 10, 255), 10)
                rect(12, 10, 382, 746, c(9, 31, 18, 248), 9)
                outline(12, 10, 382, 746, c(49, 126, 75, 230), 9, 2)
                text("TURALYON", 38, 34, font.FONT_BIG or 0, c(246, 234, 198))
                text("RETRIBUTION", 38, 66, font.FONT_SEMI_BIG or 0, c(214, 177, 93))
            end

            -- These surfaces and measurements follow the stable Holy Paladin panel.
            rect(500, 10, 978, 91, c(7, 25, 15, 232), 8)
            outline(500, 10, 978, 91, c(214, 177, 93, 225), 8, 1)
            text("RETRIBUTION PALADIN", 520, 19, font.FONT_BIG or 0, c(246, 234, 198))
            text("TURALYON  |  MIDNIGHT 12.1 COMBAT PROFILES", 521, 49,
                font.FONT_SMALL or 7, c(221, 192, 125))
            text("F1 OPEN/CLOSE  |  CLICK TABS AND SWITCHES  |  DRAG HEADER", 521, 73,
                font.FONT_SMALL or 7, c(235, 248, 239))

            rect(398, 96, 978, 164, c(7, 27, 16, 226), 8)
            text("Mode: " .. tostring(state.mode_label or "Detecting"), 415, 105,
                font.FONT_SMALL or 7, c(246, 255, 248))
            text("Build: " .. tostring(state.hero or "Unknown"), 415, 134,
                font.FONT_SMALL or 7, c(222, 193, 127))
            text("Profile: " .. compact(state.profile_name or "Detecting", 27), 590, 105,
                font.FONT_SMALL or 7, c(246, 255, 248))
            text("Last: " .. compact(state.last or "Waiting", 30), 590, 134,
                font.FONT_SMALL or 7, c(208, 230, 214))
            button(state.plugin_enabled and "ON" or "PAUSED", 815, 109, 881, 151,
                function() action("toggle_plugin") end, state.plugin_enabled, font.FONT_SMALL or 7)
            button(state.auto_mode and "AUTO" or "MANUAL", 888, 109, 969, 151,
                function() page_follows_auto = true; action("auto_mode") end,
                state.auto_mode, font.FONT_SMALL or 7)

            -- Permanent suite-style navigation rail with a theme per page.
            rect(18, 172, 382, 690, c(5, 20, 13, 235), 8)
            outline(18, 172, 382, 690, c(214, 177, 93, 210), 8, 1)
            text("PALADIN CONTROL CENTER", 38, 184, font.FONT_SMALL or 7, c(246, 234, 198))
            local tabw = 340
            for i, label in ipairs(labels) do
                local x1, y1 = 30, 208 + (i - 1) * 33
                local theme = TAB_THEME[i] or TAB_THEME[14]
                local selected = page == i
                local accent = c(theme[1], theme[2], theme[3], 245)
                rect(x1, y1, x1 + tabw, y1 + 29, selected and c(theme[1], theme[2], theme[3], 88)
                    or c(11, 37, 23, 225), 5)
                icon_tile(NAV_ICON[i], x1 + 5, y1 + 3, x1 + 34, y1 + 26, accent, selected)
                text(label, x1 + 45, y1 + 8, font.FONT_SMALL or 0,
                    selected and c(255, 241, 192) or c(238, 246, 240))
                if selected or hovered(x1, y1, x1 + tabw, y1 + 29) then
                    outline(x1, y1, x1 + tabw, y1 + 29, accent, 5, selected and 2 or 1)
                end
                if clicked(x1, y1, x1 + tabw, y1 + 29) then
                    page = i
                    settings_scroll = 0
                    page_follows_auto = false
                    action("notice", label .. " tab opened")
                end
            end

            local page_theme = TAB_THEME[page] or TAB_THEME[14]
            local page_accent = c(page_theme[1], page_theme[2], page_theme[3], 245)
            rect(398, 172, 978, 690, c(7, 25, 15, 240), 9)
            outline(398, 172, 978, 690, page_accent, 9, 2)
            rect(410, 182, 966, 222, c(9, 36, 22, 245), 6)
            text(labels[page] .. " CUSTOMIZATION", 426, 192,
                font.FONT_SEMI_BIG or 0, page_accent)
            if page <= 6 then
                local key = modes[page]
                local profile = state.profiles and state.profiles[key] or {}
                text(tostring(profile.title or labels[page]), 416, 234,
                    font.FONT_SEMI_BIG or 0, c(222, 193, 127))
                text(compact(profile.strategy or "Retribution combat profile.", 82), 416, 263,
                    font.FONT_SMALL or 7, c(238, 250, 241))
                image_button(state.active_mode == key and "PROFILE ACTIVE" or "USE THIS PROFILE",
                    ICON.wings,
                    416, 288, 600, 324, function() action("set_mode", key) end,
                    state.active_mode == key, font.FONT_SMALL or 7)
                local rows = {
                    { "Damage rotation", profile.rotation, "rotation", "Mode-specific damage priority", ICON.verdict },
                    { "Burst cooldowns", profile.burst, "burst", "Major offensive cooldowns", ICON.wings },
                    { "Crowd control", profile.cc, "cc", "Interrupts, stuns and pressure control", ICON.hammer },
                    { "Smart target swap", profile.swap_target, "swap_target", "Swap for clear pressure or kill value", ICON.verdict },
                    { "Team support", profile.team_support, "team_support", "Heals, cleanses and protective blessings", ICON.heal },
                    { "Profile defensives", profile.defensives, "defensives", "Uses configured hard HP limits", ICON.shield },
                }
                for i, item in ipairs(rows) do
                    local field = item[3]
                    toggle_row(item[1], item[2], 416, 340 + (i - 1) * 55, 960,
                        function() action("profile_toggle", key, field) end,
                        item[4], font.FONT_SMALL or 7, item[5],
                        state.hotkeys and state.hotkeys["profile:"..key..":"..field])
                end
            elseif page <= 13 then
                local group_names = { "COMBAT CONTROL", "DEFENSIVE CONTROL", "TEAM SUPPORT",
                    "MOVEMENT", "VISUALS & GUIDES", "GATHERING", "HOTKEY STATUS" }
                local grouped = {
                    {
                        { "Combat routine", state.plugin_enabled, "toggle_plugin", "Master rotation switch", ICON.wings },
                        { "Burst cooldowns", state.burst, "toggle_burst", "Major offensive cooldowns", ICON.wings },
                        { "Interrupts", state.interrupts, "toggle_interrupts", "Mode-aware interrupt logic", ICON.hammer },
                        { "Stun backup", state.stun_backup, "toggle_stun_backup", "Hammer of Justice fallback", ICON.hammer },
                        { "Dummy burst testing", state.training_dummy_burst, "toggle_training_dummy_burst", "Full cooldown tests on training dummies", ICON.wings },
                        { "Automatic aura", state.auto_aura, "toggle_auto_aura", "Crusader, Devotion or Concentration", ICON.wings },
                    },
                    {
                        { "Predictive PvP defense", state.pvp_predictive_defense, "toggle_pvp_predictive_defense", "Act on forecast damage", ICON.shield },
                        { "Wings target lock", state.pvp_wings_target_lock, "toggle_pvp_wings_target_lock", "Keep pressure target during Wings", ICON.shield },
                        { "Breakable CC pause", state.pvp_breakable_cc_pause, "toggle_pvp_breakable_cc_pause", "Avoid breaking teammate control", ICON.shield },
                        { "Predictive execute lock", state.pvp_predictive_execute_lock, "toggle_pvp_predictive_execute_lock", "Reserve execute pressure", ICON.shield },
                        { "Cast failure backoff", state.cast_failure_backoff, "toggle_cast_failure_backoff", "Avoid repeated rejected casts", ICON.shield },
                        { "PvE danger prediction", state.pve_danger_zones, "toggle_pve_danger_zones", "Incoming mechanic warning", ICON.shield },
                    },
                    {
                        { "Objective support", state.pvp_objective_priority, "toggle_pvp_objective_priority", "Protect friendly objective carriers", ICON.shield },
                        { "Coordinated burst", state.pvp_sync_burst, "toggle_pvp_sync_burst", "Sync pressure with teammates", ICON.wings },
                        { "Focus-fire detection", state.pvp_focus_fire, "toggle_pvp_focus_fire", "Follow team pressure", ICON.verdict },
                        { "Self Sanctuary", state.pvp_self_sanctuary, "toggle_pvp_self_sanctuary", "Break eligible control", ICON.shield },
                        { "Priority Freedom", state.pvp_priority_freedom, "toggle_pvp_priority_freedom", "Free rooted priority allies", ICON.freedom },
                        { "Arena healer blind", state.arena_offtarget_blind, "toggle_arena_offtarget_blind", "Off-target healer kill setup", ICON.wings },
                    },
                    {
                        { "Auto movement", state.auto_move, "toggle_auto_move", "Move toward selected target", ICON.movement },
                        { "Auto facing", state.auto_face, "toggle_auto_face", "Face selected target in combat", ICON.movement },
                        { "Safe PvP chase", state.pvp_safe_chase, "toggle_pvp_safe_chase", "Stop unsafe healer LOS chase", ICON.shield },
                        { "Target LOS filter", state.pvp_target_los_filter, "toggle_pvp_target_los_filter", "Skip unreachable swap targets", ICON.verdict },
                        { "Predictive targeting", state.pvp_predictive_targeting, "toggle_pvp_predictive_targeting", "Forecast kill opportunities", ICON.verdict },
                        { "Safe PvP cleave", state.pvp_safe_cleave, "toggle_pvp_safe_cleave", "Protect breakable control", ICON.verdict },
                    },
                    {
                        { "Target line + ring", state.target_line, "toggle_target_line", "Selected target marker", ICON.verdict },
                        { "Healer LOS line", state.healer_line, "toggle_healer_line", "Green clear; red blocked", ICON.shield },
                        { "PvP combat lines", state.pvp_lines, "toggle_pvp_lines", "Automatic PvP target and healer lines", ICON.shield },
                        { "M+ route overlay", state.route_map, "toggle_route_map", "Route and next-pull markers", ICON.route },
                        { "Season 2 boss guide", state.s2_boss_guide, "toggle_s2_boss_guide", "Role-aware mechanic guide", ICON.wings },
                        { "Small boss helper", state.boss_helper_hud, "toggle_boss_helper_hud", "Independent compact boss window", ICON.wings },
                    },
                    {
                        { "Auto fishing", state.fishing, "toggle_fishing", "Out-of-combat fishing", ICON.gather },
                        { "Auto skinning", state.skinning, "toggle_skinning", "Loot first, then skin", ICON.gather },
                        { "Auto looting", state.looting, "toggle_looting", "Out of combat only", ICON.gather },
                        { "Route assistance", state.route_map, "toggle_route_map", "Dungeon travel guidance", ICON.route },
                        { "Automatic aura", state.auto_aura, "toggle_auto_aura", "Mounted and combat aura rules", ICON.wings },
                        { "Combat routine", state.plugin_enabled, "toggle_plugin", "Pause combat while gathering", ICON.wings },
                    },
                    {},
                }
                local group_index = page - 6
                local items = grouped[group_index]
                if group_index == 7 then
                    for action_name, binding in pairs(state.hotkeys or {}) do
                        local code = binding and binding.get_key_code and binding:get_key_code() or 0
                        items[#items + 1] = { tostring((state.hotkey_labels or {})[action_name] or action_name),
                            code > 0, action_name, code > 0 and ("Bound to key code " .. tostring(code))
                                or "Unbound - assign in framework menu", ICON.hotkey, true }
                    end
                    table.sort(items, function(a, b) return a[1] < b[1] end)
                end
                text(group_names[group_index], 416, 234, font.FONT_SEMI_BIG or 0, page_accent)
                text(group_index == 7 and "Review shortcuts here; assign keys in the framework menu."
                    or "Every switch supports an optional customer hotkey.", 416, 263,
                    font.FONT_SMALL or 7, c(238, 250, 241))
                local max_scroll = math.max(0, #items - 6)
                settings_scroll = math.min(settings_scroll, max_scroll)
                button("UP", 780, 232, 865, 270,
                    function() settings_scroll = math.max(0, settings_scroll - 1) end,
                    false, font.FONT_SMALL or 7)
                button("DOWN", 875, 232, 960, 270,
                    function() settings_scroll = math.min(max_scroll, settings_scroll + 1) end,
                    false, font.FONT_SMALL or 7)
                local wheel = hovered(398, 276, 978, 690) and mouse_wheel_delta() or 0
                if wheel ~= 0 then
                    settings_scroll = math.max(0, math.min(max_scroll,
                        settings_scroll + (wheel < 0 and 1 or -1)))
                end
                text("OPTIONS " .. tostring(math.min(#items, settings_scroll + 1)) .. "-" ..
                    tostring(math.min(#items, settings_scroll + 6)) .. " OF " .. tostring(#items),
                    416, 288, font.FONT_SMALL or 7, page_accent)
                for visible_index = 1, 6 do
                    local item = items[settings_scroll + visible_index]
                    if item then
                        local action_name = item[3]
                        toggle_row(item[1], item[2], 416, 316 + (visible_index - 1) * 59, 960,
                            function() if not item[6] then action(action_name) end end,
                            item[4], font.FONT_SMALL or 7, item[5],
                            state.hotkeys and state.hotkeys[action_name])
                    end
                end
            else
                local dbg = state.debug or {}
                rect(398, 172, 978, 690, c(3, 13, 8, 248), 9)
                outline(398, 172, 978, 690, page_accent, 9, 2)
                text("RET PALADIN LIVE DEBUGGER", 416, 190,
                    font.FONT_SEMI_BIG or 0, c(246, 234, 198))
                text("v" .. tostring(state.version or "1.62.0") .. "  |  " ..
                    compact(dbg.log_status or "Logger starting", 30),
                    416, 219, font.FONT_SMALL or 0, c(198, 229, 206))
                button(state.diagnostic_log and "LOGGER ON" or "LOGGER OFF", 650, 184, 758, 222,
                    function() action("toggle_diagnostic_log") end, state.diagnostic_log, font.FONT_SMALL or 7)
                button(state.debug_overlay and "DEBUG ON" or "DEBUG OFF", 764, 184, 866, 222,
                    function() action("toggle_debug_overlay") end, state.debug_overlay, font.FONT_SMALL or 7)
                button("SAVE COPY", 872, 184, 970, 222,
                    function() action("save_debug_snapshot") end, false, font.FONT_SMALL or 7)

                rect(402, 238, 970, 352, c(10, 36, 22, 245), 6)
                text("PLAYER", 418, 248, font.FONT_SMALL or 7, c(222, 193, 127))
                text(tostring(dbg.player or "Unavailable") .. "  |  HP " ..
                    tostring(dbg.player_hp or "--") .. "  |  Holy Power " ..
                    tostring(dbg.holy_power or "--") .. "  |  Combat " ..
                    tostring(dbg.combat == true), 418, 272, font.FONT_SMALL or 7, c(246, 255, 248))
                text("TARGET", 418, 300, font.FONT_SMALL or 7, c(222, 193, 127))
                text(tostring(dbg.target or "None") .. "  |  HP " ..
                    tostring(dbg.target_hp or "--") .. "  |  " ..
                    tostring(dbg.target_distance or "--"), 418, 324,
                    font.FONT_SMALL or 7, c(246, 255, 248))

                rect(402, 364, 970, 478, c(10, 36, 22, 245), 6)
                text("MODE  detected=" .. tostring(dbg.detected_mode or "unknown") ..
                    "  active=" .. tostring(dbg.active_mode or "unknown") ..
                    "  hero=" .. tostring(dbg.hero or "unknown"), 418, 377,
                    font.FONT_SMALL or 7, c(246, 255, 248))
                text("TARGET PLAN  TTD=" .. tostring(dbg.ttd or "--") .. "  danger=" ..
                    tostring(dbg.danger or "--") .. "  " .. compact(dbg.decision or "Waiting", 40), 418, 403,
                    font.FONT_SMALL or 7, c(198, 229, 206))
                text("PvP  " .. compact(dbg.pvp_state or "--", 68), 418, 429,
                    font.FONT_SMALL or 7, c(222, 193, 127))
                text("LIVE  " .. compact(dbg.live_log_path or "scripts_log/ret_paladin_plugin/session.md", 66), 418, 455,
                    font.FONT_SMALL or 7, c(198, 229, 206))
                text("ENTITY  " .. compact(dbg.entity or "ret_paladin_plugin", 58), 690, 455,
                    font.FONT_SMALL or 7, c(222, 193, 127))

                local error_active = dbg.last_error and dbg.last_error ~= "None"
                rect(402, 490, 970, 670, error_active and c(83, 24, 20, 245) or c(12, 55, 30, 245), 6)
                text("LATEST ERROR  t=" .. tostring(dbg.error_time or "Never"), 418, 505,
                    font.FONT_SMALL or 7, error_active and c(255, 188, 174) or c(132, 240, 164))
                text(compact(dbg.last_error or "None", 82), 418, 539,
                    font.FONT_SMALL or 7, c(250, 250, 245))
                text(error_active and "Captured safely; routine continues on the next update."
                    or "No captured runtime error.", 418, 575,
                    font.FONT_SMALL or 7, c(208, 230, 214))
                button("CLEAR ERROR", 830, 636, 958, 670,
                    function() action("clear_debug_error") end, false, font.FONT_SMALL or 7)
            end

            rect(398, 702, 978, 746, c(7, 27, 16, 226), 6)
            rect(20, 703, 118, 746, c(239, 232, 209, 235), 6)
            text("F1  HIDE", 34, 717, font.FONT_SMALL or 7, c(45, 34, 14))
            image_button("LOGS / DEBUG", ICON.logs, 124, 703, 280, 746,
                function() page = 14; page_follows_auto = false; action("notice", "LOGS tab opened") end,
                page == 14, font.FONT_SMALL or 7)
            text("STATUS: " .. tostring(state.status or "Ready") .. "  |  " ..
                compact(state.notice or "Profiles are activity-specific", 31), 415, 717,
                font.FONT_SMALL or 7, c(246, 255, 248))
            rect(884, 708, 968, 740, c(247, 239, 216, 250), 6)
            outline(884, 708, 968, 740, c(214, 177, 93, 255), 6, 2)
            text("v" .. tostring(state.version or "1.62.0"), 898, 717,
                font.FONT_SMALL or 7, c(40, 29, 10))
            outline(1, 1, 998, 758, c(83, 211, 122, 255), 10, 2)
        end)
    end)
    if not ok then
        if not reported then
            reported = true
            if type(core.log_warning) == "function" then
                pcall(core.log_warning, "[Ret Paladin GUI] " .. tostring(err))
            end
        end
        return false, err
    end
    reported = false
    return true
end

return M
