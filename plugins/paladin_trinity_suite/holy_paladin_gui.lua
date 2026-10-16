-- Warm gold-and-ivory panel. The Paladin art is the canvas; translucent controls
-- stay on the right so the character remains visible.
local M = {}
local color, vec2, enums, window
local page, win_x, win_y = 1, 45, 45
local pve_scroll, last_pve_scroll = 0, -math.huge
local display_debug = true
local dragging, mouse_was_down = nil, false
local art_error_reported, render_error_reported = false, false
local art_texture, art_attempted = nil, false
local saved_x, saved_y
local panel_w, panel_h = 1180, 760
local labels = { "DASHBOARD", "PLAYER", "MYTHIC+", "DUNGEONS", "DELVES", "ARENA",
    "BATTLEGROUNDS", "WORLD PVP", "PRACTICE", "GATHERING", "COOLDOWNS", "SUPPORT",
    "HOTKEYS", "LOGS / DEBUG" }
local page_titles = { "HOLY PALADIN CONTROL", "PLAYER ASSISTANCE", "MYTHIC+ CUSTOMIZATION",
    "DUNGEON TOOLS", "DELVE HEALING", "ARENA CONTROL", "BATTLEGROUND SUPPORT",
    "WORLD PVP SURVIVAL", "PRACTICE DUMMIES", "GATHERING TOOLS", "COOLDOWN POLICY",
    "PALADIN SUPPORT", "CUSTOM HOTKEYS", "LOGS AND DEBUGGER" }
local page_subtitles = { "One clear view of the complete healing profile",
    "Beacons, auras, movement and targeting", "High-key healing, prevention and boss awareness",
    "Interrupts, mechanics and positioning", "Companion-aware solo healing and damage",
    "Pressure healing, crowd control and partner saves", "Large-team triage and objective support",
    "Self-sustain, friendly support and escape tools", "Test the live Holy rotation safely",
    "Out-of-combat convenience controls", "Throughput, saves and encounter timing",
    "Beacon, cleanse, aura and party assistance", "Every customer-assigned feature key",
    "Persistent run evidence and live decisions" }
local page_rows = {
    [1] = { {"Entire plugin","plugin_enabled","toggle_plugin","Master control"},
        {"Healing rotation","global_healing","toggle_healing","Predictive Holy triage"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Wings and major throughput"},
        {"Defensives and saves","personals","toggle_personals","Personal and teammate protection"},
        {"Damage in safe windows","damage","toggle_damage","Activity-aware offensive globals"} },
    [2] = { {"Automatic Beacon","auto_beacon","toggle_beacon","Talent-aware Beacon placement"},
        {"Automatic aura","auto_aura","toggle_aura","Crusader, Devotion and Concentration"},
        {"Automatic dispel","auto_dispel","toggle_dispel","Magic and talented toxin removal"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Travel and pressure movement"},
        {"Automatic facing","auto_face","toggle_face","Face selected attack targets"},
        {"Automatic targeting","auto_target","toggle_target","Select nearby engaged enemies"} },
    [3] = { {"Healing rotation","global_healing","toggle_healing","Predictive five-player triage"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Damage-timeline cooldowns"},
        {"Defensives and saves","personals","toggle_personals","Prevent lethal damage"},
        {"Interrupts and stops","interrupt","toggle_interrupt","Rebuke with Hammer fallback"},
        {"Dispel and support","auto_dispel","toggle_dispel","Cleanse dangerous effects"},
        {"Danger zones","danger_zones","toggle_danger_zones","BigWigs-linked hazard guidance"} },
    [4] = { {"Dungeon boss helper","boss_guide","toggle_boss_guide","Role-aware mechanic instructions"},
        {"Danger-zone guidance","danger_zones","toggle_danger_zones","Safe position visualization"},
        {"Interrupts and stops","interrupt","toggle_interrupt","Dangerous cast control"},
        {"Automatic targeting","auto_target","toggle_target","Select engaged enemies"},
        {"Automatic facing","auto_face","toggle_face","Face without moving"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Movement mechanic support"} },
    [5] = { {"Healing rotation","global_healing","toggle_healing","Self and companion triage"},
        {"Damage rotation","damage","toggle_damage","Solo progress when stable"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Talent-aware recovery"},
        {"Automatic Beacon","auto_beacon","toggle_beacon","Selected Beacon behavior"},
        {"Automatic dispel","auto_dispel","toggle_dispel","Cleanse eligible effects"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Delve traversal support"} },
    [6] = { {"Healing rotation","global_healing","toggle_healing","Pressure and swap-aware triage"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Trade cooldowns into enemy goes"},
        {"Defensives and saves","personals","toggle_personals","Sacrifice, blessings and emergency saves"},
        {"Crowd control","auto_cc","toggle_cc","Setups, stops and emergency peels"},
        {"Priority dispels","auto_dispel","toggle_dispel","Remove dangerous control"},
        {"Partner lines","arena_lines","toggle_arena_lines","Range and line-of-sight status"} },
    [7] = { {"Healing rotation","global_healing","toggle_healing","Large-team projected triage"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Team-fight throughput"},
        {"Defensives and saves","personals","toggle_personals","Protect focused teammates"},
        {"Crowd control","auto_cc","toggle_cc","Peel pressure and stop casts"},
        {"Priority dispels","auto_dispel","toggle_dispel","Control and harmful effects"},
        {"Automatic targeting","auto_target","toggle_target","Find active enemy players"} },
    [8] = { {"Healing rotation","global_healing","toggle_healing","Self and friendly-player triage"},
        {"Defensives and saves","personals","toggle_personals","Survive focused pressure"},
        {"Crowd control","auto_cc","toggle_cc","Peels and kill support"},
        {"Automatic aura","auto_aura","toggle_aura","Mounted and combat aura logic"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Travel and escape support"},
        {"Automatic targeting","auto_target","toggle_target","Select confirmed hostiles"} },
    [9] = { {"Training dummy rotation","training_dummy","toggle_training_dummy","Major-city practice targets"},
        {"Healing rotation","global_healing","toggle_healing","Includes friendly healing dummies"},
        {"Damage rotation","damage","toggle_damage","Full offensive priority test"},
        {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Hero-build cooldown test"},
        {"Automatic targeting","auto_target","toggle_target","Target assistance"},
        {"Automatic facing","auto_face","toggle_face","Facing requirement test"} },
    [10] = { {"Automatic fishing","fishing","toggle_fishing","Fish and collect bites"},
        {"Automatic looting","looting","toggle_looting","Loot eligible nearby corpses"},
        {"Automatic aura","auto_aura","toggle_aura","Crusader Aura while mounted"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Sustained travel support"} },
    [11] = { {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns","Wings and throughput planning"},
        {"Defensives and saves","personals","toggle_personals","Personal and external survival"},
        {"Dungeon boss helper","boss_guide","toggle_boss_guide","Mechanic-aware cooldown timing"},
        {"Danger-zone guidance","danger_zones","toggle_danger_zones","Move before incoming mechanics"},
        {"Interrupts and stops","interrupt","toggle_interrupt","Protect healing windows"},
        {"Automatic Divine Steed","auto_steed","toggle_steed","Movement cooldown support"} },
    [12] = { {"Automatic Beacon","auto_beacon","toggle_beacon","Talent-aware Beacon placement"},
        {"Automatic dispel","auto_dispel","toggle_dispel","Remove eligible harmful effects"},
        {"Automatic aura","auto_aura","toggle_aura","Group and travel aura selection"},
        {"Crowd control","auto_cc","toggle_cc","Stops, peels and kill support"},
        {"Partner guidance lines","arena_lines","toggle_arena_lines","Range and line-of-sight help"},
        {"Automatic looting","looting","toggle_looting","Optional post-combat convenience"} },
}
local page_modes = { [3] = "mythic_plus", [5] = "delve", [6] = "arena",
    [7] = "battleground", [8] = "world_pvp", [9] = "training" }

-- Project Sylvanas fonts do not consistently contain typographic Unicode.
-- Keep every runtime/status string on the same font-safe path as the working
-- Rogue panel so bullets, arrows and smart punctuation cannot distort layout.
local function clean_text(value)
    local value_text = tostring(value == nil and "" or value)
    value_text = value_text:gsub("\226\128\162", " | ")
        :gsub("\226\134\146", " -> ")
        :gsub("\226\128\148", " - ")
        :gsub("\226\128\147", "-")
        :gsub("\226\128\153", "'")
        :gsub("\226\128\152", "'")
    return value_text:gsub("[\128-\255]+", "_"):gsub("[%c]", " ")
end

local function font_id(name)
    local fonts = enums and enums.window_enums and enums.window_enums.font_id
    return fonts and fonts[name] or 0
end
local function small_font() return font_id("FONT_SMALL") end
local function big_font() return font_id("FONT_BIG") end
local function semi_big_font() return font_id("FONT_SEMI_BIG") end
local function fit_text(value, limit)
    local value_text = clean_text(value)
    if #value_text <= limit then return value_text end
    return value_text:sub(1, math.max(0, limit - 3)) .. "..."
end

pcall(function()
    color = require("common/color")
    vec2 = require("common/geometry/vector_2")
    enums = require("common/enums")
    window = core.menu.window("hpm_silver_hand_200")
    if type(core.menu.slider_int) == "function" then
        saved_x = core.menu.slider_int(0, 7680, win_x, "hpm_gui_x_v1")
        saved_y = core.menu.slider_int(0, 4320, win_y, "hpm_gui_y_v1")
        win_x, win_y = saved_x:get(), saved_y:get()
    end
    window:set_initial_position(vec2.new(win_x, win_y))
    window:set_initial_size(vec2.new(panel_w, panel_h))
    if type(window.set_render_layer) == "function" then window:set_render_layer(1) end
    window:set_visibility(true)
end)

local function clamp_position(x, y)
    if core.graphics and type(core.graphics.get_screen_size) == "function" then
        local ok, screen = pcall(core.graphics.get_screen_size)
        if ok and screen and type(screen.x) == "number" and type(screen.y) == "number" then
            x = math.max(0, math.min(x, math.max(0, screen.x - panel_w)))
            y = math.max(0, math.min(y, math.max(0, screen.y - panel_h)))
        end
    end
    return math.max(0, x), math.max(0, y)
end

local function save_position()
    if saved_x and type(saved_x.set) == "function" then
        pcall(saved_x.set, saved_x, math.floor(win_x))
        pcall(saved_y.set, saved_y, math.floor(win_y))
    end
end

local function reset_position()
    win_x, win_y = clamp_position(45, 45)
    save_position()
end

local function c(r, g, b, a) return color.new(r, g, b, a or 255) end
local function rect(x1, y1, x2, y2, col, radius)
    window:render_rect_filled(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5)
end
local function outline(x1, y1, x2, y2, col, radius, thickness)
    window:render_rect(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5, thickness or 1)
end
local function text(value, x, y, font, col)
    window:render_text(font or small_font(), vec2.new(x, y), col, clean_text(value))
end
local function clicked(x1, y1, x2, y2)
    return window:is_rect_clicked(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function hovered(x1, y1, x2, y2)
    return window:is_mouse_hovering_rect(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function button(label, x1, y1, x2, y2, action, active)
    local over = hovered(x1, y1, x2, y2)
    rect(x1, y1, x2, y2, active and c(222, 185, 105, 248) or
        (over and c(135, 101, 54, 236) or c(67, 49, 31, 210)), 5)
    text(fit_text(label, math.max(8, math.floor((x2 - x1) / 7))), x1 + 10, y1 + 10, small_font(),
        active and c(38, 27, 15) or c(255, 247, 230))
    if clicked(x1, y1, x2, y2) then action() end
end
local function toggle_row(label, value, x, y, x2, on_click, note)
    rect(x, y, x2, y + 45, c(50, 38, 25, 224), 5)
    local tx = x + 14
    text(fit_text(label, 43), tx, y + 6, small_font(), c(255, 247, 230))
    if note and note ~= "" then
        text(fit_text(note, 49), tx, y + 26, small_font(), c(230, 213, 181))
    end
    local enabled = value == true
    rect(x2 - 75, y + 10, x2 - 14, y + 35, enabled and c(222, 185, 105) or c(92, 75, 55), 6)
    text(enabled and "ON" or "OFF", x2 - 58, y + 15, small_font(),
        enabled and c(38, 27, 15) or c(255, 247, 230))
    if clicked(x, y, x2, y + 45) then on_click() end
end

local function compact(value, limit)
    return fit_text(value, limit)
end

local function mouse_wheel_delta()
    local candidates = {
        core.input and core.input.get_mouse_wheel_delta,
        core.get_mouse_wheel_delta,
        core.graphics and core.graphics.get_mouse_wheel_delta,
    }
    for _, fn in pairs(candidates) do
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok and type(value) == "number" and value ~= 0 then return value end
        end
    end
    return 0
end

function M.render(state, action)
    if not window then return end
    -- Window callbacks can outlive the character that registered them. Require
    -- a positive Holy Paladin match here as the final ownership boundary.
    local owner = core.object_manager and core.object_manager.get_local_player
        and core.object_manager.get_local_player() or nil
    local owner_ok, owner_class = pcall(function()
        return owner and owner:is_valid() and owner:get_class()
    end)
    local enums_ok, owner_enums = pcall(require, "common/enums")
    local spec_ok, owner_spec = pcall(function()
        local raw = owner.get_specialization_id and owner:get_specialization_id()
            or core.spell_book.get_specialization_id()
        if raw == owner_enums.class_spec_id.spec_enum.HOLY_PALADIN then return raw end
        return owner_enums.class_spec_id.get_specialization_enum(owner_class, raw)
    end)
    local expected = enums_ok and owner_enums.class_spec_id and owner_enums.class_spec_id.spec_enum
        and owner_enums.class_spec_id.spec_enum.HOLY_PALADIN or nil
    if not (enums_ok and owner_ok and owner_enums.class_id
        and owner_class == owner_enums.class_id.PALADIN
        and spec_ok and expected and owner_spec == expected) then
        pcall(window.set_visibility, window, false)
        if dragging and core.graphics and type(core.graphics.set_mouse_capture_state) == "function" then
            pcall(core.graphics.set_mouse_capture_state, false)
        end
        dragging, mouse_was_down = nil, false
        return
    end
    pcall(window.set_visibility, window, state.window_open ~= false)
    if state.window_open == false then
        if dragging and core.graphics and type(core.graphics.set_mouse_capture_state) == "function" then
            pcall(core.graphics.set_mouse_capture_state, false)
        end
        dragging, mouse_was_down = nil, false
        return
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
            win_x, win_y = clamp_position(cursor.x - dragging.dx, cursor.y - dragging.dy)
            save_position()
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
        win_x, win_y = clamp_position(win_x, win_y)

        local we = enums.window_enums or enums
        local flags = we.window_resizing_flags or {}
        local visuals = we.window_cross_visuals or {}
        if type(window.set_next_window_min_size) == "function" then
            window:set_next_window_min_size(vec2.new(panel_w, panel_h))
        end
        if type(window.force_window_size) == "function" then window:force_window_size(vec2.new(panel_w, panel_h)) end
        if type(window.force_next_begin_window_pos) == "function" then
            window:force_next_begin_window_pos(vec2.new(win_x, win_y))
        end
        window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0, false,
            c(35, 24, 14, 255), c(204, 165, 89, 255), visuals.NO_CROSS or 9, function()
            if not art_attempted then
                art_attempted = true
                if core.graphics and type(core.graphics.load_texture) == "function" then
                    local loaded, texture = pcall(function()
                        return core.graphics.load_texture(require("holy_paladin_art"))
                    end)
                    if loaded then art_texture = texture end
                end
            end
            if art_texture and core.graphics and type(core.graphics.draw_texture) == "function" then
                local position = type(window.get_position) == "function"
                    and window:get_position() or vec2.new(win_x, win_y)
                local drawn, draw_error = pcall(core.graphics.draw_texture, art_texture,
                    vec2.new(position.x, position.y), panel_w, panel_h,
                    c(255, 255, 255, 255), true)
                if not drawn and not art_error_reported then
                    art_error_reported = true
                    if type(core.log) == "function" then
                        pcall(core.log, "[Holy Paladin GUI] embedded artwork: " .. tostring(draw_error))
                    end
                end
            else
                rect(0, 0, panel_w, panel_h, c(35, 24, 14, 255), 0)
                rect(0, 0, 390, panel_h, c(79, 51, 22, 255), 0)
                text("THE SILVER HAND", 70, 350, big_font(), c(255, 226, 130))
            end

            -- Reference-inspired customer layout: permanent navigation on the
            -- left, activity-specific controls on the right, and Holy styling.
            rect(0, 0, panel_w, panel_h, c(22, 15, 9, 82), 0)
            local accent = c(222, 185, 105)
            if page == 5 then accent = c(102, 202, 210)
            elseif page == 6 then accent = c(236, 104, 91)
            elseif page == 7 then accent = c(106, 164, 236)
            elseif page == 8 then accent = c(188, 119, 224)
            elseif page == 9 then accent = c(117, 206, 126)
            elseif page == 10 then accent = c(117, 193, 151)
            elseif page == 11 then accent = c(242, 201, 111)
            elseif page == 12 then accent = c(110, 210, 164)
            elseif page == 13 then accent = c(235, 171, 91)
            elseif page == 14 then accent = c(154, 184, 211) end

            -- Header and hand-built Holy crest keep the package Lua-only.
            rect(18, 12, 1162, 112, c(25, 18, 12, 238), 10)
            outline(18, 12, 1162, 112, c(222, 185, 105, 235), 10, 2)
            rect(34, 25, 103, 99, c(66, 45, 20, 245), 36)
            outline(34, 25, 103, 99, accent, 36, 3)
            rect(63, 38, 74, 86, c(255, 234, 172), 3)
            rect(47, 55, 91, 68, c(255, 234, 172), 3)
            text("THE SILVER HAND", 125, 24, big_font(), c(255, 236, 184))
            text("HOLY PALADIN HEALING SUITE  |  v4.70.0", 126, 58,
                small_font(), c(235, 202, 132))
            text("F1 PANEL  |  INSERT ASSIGN KEYS  |  DRAG HEADER", 126, 82,
                small_font(), c(235, 224, 203))
            button("-", 1080, 28, 1114, 62, function() action("notice", "Use F1 to hide the panel") end, false)
            button("X", 1120, 28, 1152, 62, function() action("toggle_window") end, false)
            button("MODE: " .. tostring(state.mode_label or "AUTO"), 850, 70, 1000, 103,
                function() action("auto_mode") end, state.auto_mode)
            button(state.plugin_enabled and "PROFILE ACTIVE" or "PROFILE PAUSED", 1007, 70, 1152, 103,
                function() action("toggle_plugin") end, state.plugin_enabled)

            -- Permanent left navigation mirrors the supplied customer layout.
            rect(18, 124, 252, 694, c(27, 20, 14, 226), 9)
            outline(18, 124, 252, 694, c(151, 111, 56, 220), 9, 1)
            for i, label in ipairs(labels) do
                local y1 = 132 + (i - 1) * 38
                local active = page == i
                local over = hovered(28, y1, 242, y1 + 34)
                if active then outline(27, y1 - 1, 243, y1 + 35, accent, 6, 2) end
                rect(28, y1, 242, y1 + 34, active and c(83, 58, 25, 242)
                    or (over and c(67, 48, 28, 239) or c(38, 29, 21, 229)), 5)
                rect(39, y1 + 8, 57, y1 + 26, active and accent or c(190, 153, 88), 4)
                text(label, 70, y1 + 10, small_font(), active and c(255, 242, 207) or c(235, 224, 203))
                if clicked(28, y1, 242, y1 + 34) then page, pve_scroll = i, 0 end
            end
            text("LIGHT  |  FAITH  |  DUTY", 47, 662, small_font(), c(205, 172, 112))

            -- Selected page owns the main canvas and accent color.
            rect(266, 124, 1162, 694, c(26, 19, 13, 236), 9)
            outline(266, 124, 1162, 694, c(151, 111, 56, 220), 9, 1)
            rect(282, 139, 1146, 200, c(42, 30, 18, 234), 7)
            rect(282, 139, 290, 200, accent, 4)
            text(page_titles[page], 310, 147, big_font(), c(255, 236, 184))
            text(page_subtitles[page], 311, 177, small_font(), c(222, 205, 176))
            local page_mode = page_modes[page]
            if page_mode then
                button(state.active_mode == page_mode and "ACTIVE PROFILE" or "USE PROFILE",
                    998, 150, 1130, 188, function() action("set_mode", page_mode) end,
                    state.active_mode == page_mode)
            end

            local function setting_row(item, y)
                local value = state[item[2]] == true
                local kind = item[3]
                local bind = state.hotkeys and state.hotkeys[kind] or "UNBOUND"
                rect(288, y, 1140, y + 50, c(42, 31, 21, 232), 6)
                outline(288, y, 1140, y + 50, c(87, 65, 39, 210), 6, 1)
                rect(301, y + 9, 333, y + 41, c(66, 47, 24, 238), 5)
                text(value and "+" or "-", 312, y + 16, small_font(), value and accent or c(154, 132, 101))
                text(fit_text(item[1], 38), 350, y + 6, small_font(), c(255, 244, 219))
                text(fit_text(item[4], 52), 350, y + 28, small_font(), c(211, 194, 164))
                button(value and "ON" or "OFF", 875, y + 8, 957, y + 42,
                    function() action(kind) end, value)
                button(tostring(bind), 970, y + 8, 1128, y + 42,
                    function() action("notice", "Press INSERT to assign " .. item[1]) end, bind ~= "UNBOUND")
            end

            local rows = page_rows[page]
            if rows then
                for i, item in ipairs(rows) do setting_row(item, 211 + (i - 1) * 57) end
                if page == 1 then
                    local function threshold_box(label, value, key, x)
                        rect(x, 507, x + 273, 600, c(42, 31, 21, 235), 7)
                        text(label .. "  " .. tostring(value) .. "%", x + 14, 519,
                            small_font(), c(255, 236, 184))
                        rect(x + 15, 552, x + 255, 565, c(79, 63, 43), 6)
                        rect(x + 15, 552, x + 15 + math.floor(240 * value / 100), 565, accent, 6)
                        button("-", x + 15, 572, x + 63, 595,
                            function() action("adjust_threshold", key, -1) end, false)
                        button("+", x + 207, 572, x + 255, 595,
                            function() action("adjust_threshold", key, 1) end, false)
                    end
                    threshold_box("DIRECT HEAL", state.heal_at or 82, "heal_at", 288)
                    threshold_box("GROUP HEAL", state.aoe_at or 70, "aoe_at", 575)
                    threshold_box("EMERGENCY", state.emergency or 15, "emergency", 862)
                end
            elseif page == 13 then
                local hotkey_rows = {
                    {"Entire plugin","plugin_enabled","toggle_plugin"},{"Healing rotation","global_healing","toggle_healing"},
                    {"Healing cooldowns","healing_cooldowns","toggle_healing_cooldowns"},{"Automatic Beacon","auto_beacon","toggle_beacon"},
                    {"Automatic dispel","auto_dispel","toggle_dispel"},{"Defensives and saves","personals","toggle_personals"},
                    {"Damage rotation","damage","toggle_damage"},{"Interrupts","interrupt","toggle_interrupt"},
                    {"PvP crowd control","auto_cc","toggle_cc"},{"Aura selection","auto_aura","toggle_aura"},
                    {"Divine Steed","auto_steed","toggle_steed"},{"Automatic facing","auto_face","toggle_face"},
                    {"Automatic targeting","auto_target","toggle_target"},{"Training dummy","training_dummy","toggle_training_dummy"},
                    {"Arena teammate lines","arena_lines","toggle_arena_lines"},{"Danger zones","danger_zones","toggle_danger_zones"},
                    {"Boss helper","boss_guide","toggle_boss_guide"},{"Automatic fishing","fishing","toggle_fishing"},
                    {"Automatic looting","looting","toggle_looting"},{"Encounter recorder","log_enabled","toggle_log"},
                }
                local maximum = math.max(0, #hotkey_rows - 6)
                pve_scroll = math.min(pve_scroll, maximum)
                local wheel = hovered(266, 200, 896, 470) and mouse_wheel_delta() or 0
                if wheel ~= 0 and core.time() - last_pve_scroll > 0.08 then
                    pve_scroll = math.max(0, math.min(maximum, pve_scroll + (wheel < 0 and 1 or -1)))
                    last_pve_scroll = core.time()
                end
                button("UP", 992, 207, 1056, 238, function() pve_scroll = math.max(0, pve_scroll - 1) end, false)
                button("DOWN", 1063, 207, 1138, 238, function() pve_scroll = math.min(maximum, pve_scroll + 1) end, false)
                for visible = 1, 6 do
                    local item = hotkey_rows[pve_scroll + visible]
                    if item then setting_row({item[1], item[2], item[3], "Independent customer toggle"},
                        246 + (visible - 1) * 57) end
                end
                text("Showing " .. tostring(pve_scroll + 1) .. "-" .. tostring(math.min(#hotkey_rows, pve_scroll + 6))
                    .. " of " .. tostring(#hotkey_rows) .. "  |  Assign keys in INSERT > Holy Paladin Healing",
                    290, 643, small_font(), c(222, 205, 176))
            elseif page == 14 then
                local T = require("holy_paladin_telemetry")
                setting_row({"Encounter recorder","log_enabled","toggle_log","Persistent Holy Paladin session evidence"}, 218)
                button("COPY LOG PATH", 288, 285, 486, 329, function()
                    if type(window.copy_to_clipboard) == "function" then window:copy_to_clipboard(T.path()) end
                end, false)
                button("COPY CURRENT RUN", 500, 285, 710, 329, function()
                    if type(window.copy_to_clipboard) == "function" then window:copy_to_clipboard(T.current_run()) end
                end, false)
                button("CLEAR LOG", 724, 285, 916, 329, function() action("clear_log") end, false)
                button("RESET DEBUGGER", 930, 285, 1138, 329, function() action("reset_debug") end, false)
                local d = state.debugger or {}
                rect(288, 346, 1140, 610, c(18, 14, 10, 235), 7)
                text("RUN: " .. (d.active and "ACTIVE" or "IDLE") .. "  |  MODE: " .. tostring(d.mode or "none")
                    .. "  |  REQUESTS: " .. tostring(d.requests or 0) .. "  |  SUCCESS: " .. tostring(d.success or 0),
                    306, 364, small_font(), d.active and c(105, 239, 156) or accent)
                text("LAST REQUEST: " .. compact(d.last_request or "none", 103), 306, 402, small_font(), c(255, 247, 230))
                text("LAST SKIP: " .. compact(d.last_skip or "none", 106), 306, 440, small_font(), c(222, 205, 176))
                text("LAST EVENT: " .. compact(d.last_event or "none", 104), 306, 478, small_font(), c(255, 247, 230))
                text("LAST ERROR: " .. compact(d.last_error or "none", 104), 306, 516, small_font(),
                    d.last_error ~= "none" and c(255, 128, 112) or c(105, 239, 156))
                text("FILE: " .. compact(T.path(), 108), 306, 554, small_font(), c(222, 205, 176))
            end

            rect(266, 704, 1162, 746, c(25, 18, 12, 236), 6)
            text("STATUS: " .. compact(state.status or "Ready", 20) .. "  |  " ..
                compact(state.notice or "Talents detected automatically", 59), 286, 718,
                small_font(), c(255, 247, 230))
            rect(1060, 710, 1148, 740, c(249, 239, 216, 248), 6)
            outline(1060, 710, 1148, 740, accent, 6, 2)
            text("v4.70.0", 1075, 718, small_font(), c(47, 29, 10))
            outline(1, 1, 1178, 758, c(204, 165, 89, 255), 10, 2)
        end)
    end)
    if not ok and not render_error_reported then
        render_error_reported = true
        if type(action) == "function" then pcall(action, "debug_error", tostring(err)) end
        if type(core.log_warning) == "function" then pcall(core.log_warning, "[Holy Paladin GUI] " .. tostring(err)) end
    end
end
function M.hide()
    if window then window:set_visibility(false) end
end
return M
