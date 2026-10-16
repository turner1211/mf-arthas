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
local panel_w, panel_h = 1000, 760
local labels = { "HOME", "HEALING", "PVE / BOSSES", "PVP / CONTROL", "MOVEMENT",
    "UTILITY", "GATHERING", "HOTKEYS", "DISPLAY / LOGS" }

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
    return value_text:gsub("[%c]", " ")
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
    return require('mf_i18n').clip(require('mf_i18n').text(value_text),limit)
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

            -- Keep every label on a controlled contrast surface while leaving
            -- the Paladin portrait and the full-window artwork visible.
            rect(500, 10, 978, 91, c(24, 19, 14, 224), 8)
            outline(500, 10, 978, 91, c(222, 185, 105, 210), 8, 1)
            text("HOLY PALADIN", 520, 19, big_font(), c(255, 241, 207))
            text("THE SILVER HAND  |  HEALING PROFILES", 521, 49,
                small_font(), c(235, 202, 132))
            text("F1 PANEL  |  INSERT SET KEYS  |  CLICK SWITCHES  |  DRAG HEADER", 521, 73,
                small_font(), c(245, 237, 222))

            rect(398, 96, 978, 164, c(43, 32, 21, 222), 8)
            text("Mode: " .. tostring(state.mode_label or "Detecting"), 415, 105,
                small_font(), c(255, 247, 230))
            text("Build: " .. tostring(state.hero or "Unknown"), 415, 134,
                small_font(), c(235, 202, 132))
            text("Profile: " .. compact(state.profile_name or "Detecting", 27), 590, 105,
                small_font(), c(255, 247, 230))
            text("Last: " .. compact(state.last or "Waiting", 30), 590, 134,
                small_font(), c(235, 224, 203))
            button(state.plugin_enabled and "ON" or "PAUSED", 815, 109, 881, 151,
                function() action("toggle_plugin") end, state.plugin_enabled)
            button(state.auto_mode and "AUTO" or "MANUAL", 888, 109, 969, 151,
                function() action("auto_mode") end, state.auto_mode)

            rect(398, 172, 978, 280, c(48, 34, 20, 190), 8)
            local gap, tabw = 7, 184
            for i, label in ipairs(labels) do
                local row = math.floor((i - 1) / 3)
                local col = (i - 1) % 3
                local x1 = 408 + col * (tabw + gap)
                button(label, x1, 177 + row * 34, x1 + tabw, 207 + row * 34,
                    function()
                        page = i
                        pve_scroll = 0
                        action("notice", label .. " tab opened")
                    end,
                    page == i)
            end

            rect(398, 288, 978, 690, c(34, 26, 18, 230), 9)
            text(labels[page], 416, 300, semi_big_font(), c(240, 204, 131))
            local function row(label, value, y, kind, note)
                local bind = state.hotkeys and state.hotkeys[kind]
                local detail = tostring(note or "")
                if bind then detail = detail .. "  |  KEY: " .. tostring(bind) end
                toggle_row(label, value, 416, y, 960, function() action(kind) end, detail)
            end
            local function threshold_row(label, value, key, y, note)
                rect(416, y, 960, y + 45, c(50, 38, 25, 224), 5)
                text(label, 430, y + 6, small_font(), c(255, 247, 230))
                text(note, 430, y + 26, small_font(), c(230, 213, 181))
                button("-", 790, y + 8, 830, y + 37,
                    function() action("adjust_threshold", key, -1) end, false)
                rect(838, y + 8, 900, y + 37, c(222, 185, 105), 5)
                text(tostring(value) .. "%", 850, y + 15, small_font(), c(38, 27, 15))
                button("+", 908, y + 8, 948, y + 37,
                    function() action("adjust_threshold", key, 1) end, false)
            end
            local function profile_button(label, key, x1, y)
                button((state.active_mode == key and "ACTIVE: " or "USE: ") .. label,
                    x1, y, x1 + 170, y + 37, function() action("set_mode", key) end,
                    state.active_mode == key)
            end
            if page == 1 then
                row("Entire plugin", state.plugin_enabled, 330, "toggle_plugin", "Master pause without losing settings")
                row("Healing rotation", state.global_healing, 380, "toggle_healing", "Automatic healing decisions")
                row("Healing cooldowns", state.healing_cooldowns, 430, "toggle_healing_cooldowns", "Wings and major throughput")
                row("Defensives and saves", state.personals, 480, "toggle_personals", "Personal and teammate protection")
                row("Damage in safe windows", state.damage, 530, "toggle_damage", "Activity-aware offensive globals")
                button(state.auto_mode and "PROFILE: AUTOMATIC" or "RESTORE AUTOMATIC PROFILE",
                    416, 590, 690, 630, function() action("auto_mode") end, state.auto_mode)
                text("Current profile: " .. compact(state.profile_name or "Detecting", 41), 416, 646,
                    small_font(), c(235, 224, 203))
            elseif page == 2 then
                row("Healing rotation", state.global_healing, 330, "toggle_healing", "Main Holy healing engine")
                row("Automatic Beacon", state.auto_beacon, 380, "toggle_beacon", "Detects the selected Beacon talent")
                row("Automatic dispel", state.auto_dispel, 430, "toggle_dispel", "Magic, Poison, Disease and PvP control")
                threshold_row("Direct heal threshold", state.heal_at or 82, "heal_at", 480,
                    "Start routine healing at projected health")
                threshold_row("Group heal threshold", state.aoe_at or 70, "aoe_at", 530,
                    "Light of Dawn and group pressure threshold")
                threshold_row("Emergency threshold", state.emergency or 15, "emergency", 580,
                    "Emergency triage and self-save threshold")
            elseif page == 3 then
                text("PVE PROFILE", 416, 330, small_font(), c(235, 202, 132))
                profile_button("MYTHIC+", "mythic_plus", 416, 352)
                profile_button("DELVE", "delve", 596, 352)
                row("Mythic+ interrupts", state.interrupt, 405, "toggle_interrupt", "Rebuke with Hammer fallback")
                row("Danger-zone guidance", state.danger_zones, 455, "toggle_danger_zones", state.danger_status or "BigWigs timing")
                row("Dungeon boss helper", state.boss_guide, 505, "toggle_boss_guide", state.boss_guide_status or "Role-aware mechanics")
                row("Training dummy rotation", state.training_dummy, 555, "toggle_training_dummy", "Test the complete rotation in cities")
                row("Damage in safe windows", state.damage, 605, "toggle_damage", "Holy Power generation when healing is stable")
            elseif page == 4 then
                text("PVP PROFILE", 416, 330, small_font(), c(235, 202, 132))
                profile_button("ARENA", "arena", 416, 352)
                profile_button("BATTLEGROUND", "battleground", 596, 352)
                profile_button("WORLD PVP", "world_pvp", 776, 352)
                row("Automatic crowd control", state.auto_cc, 405, "toggle_cc", "Setups, interrupts and emergency peels")
                row("Arena teammate lines", state.arena_lines, 455, "toggle_arena_lines", "Range and line of sight")
                row("Defensives and teammate saves", state.personals, 505, "toggle_personals", "Sacrifice, blessings and emergency saves")
                row("Automatic dispel", state.auto_dispel, 555, "toggle_dispel", "Prioritizes removable crowd control")
                row("Automatic target selection", state.auto_target, 605, "toggle_target", "Find a valid nearby enemy")
            elseif page == 5 then
                row("Automatic Divine Steed", state.auto_steed, 330, "toggle_steed", "Travel and verified PvP pressure")
                row("Automatic facing", state.auto_face, 380, "toggle_face", "Face the selected attack target")
                row("Automatic target selection", state.auto_target, 430, "toggle_target", "Choose a nearby engaged enemy")
                row("Automatic aura selection", state.auto_aura, 480, "toggle_aura", "Crusader, Devotion and Concentration")
                row("Dungeon boss helper", state.boss_guide, 530, "toggle_boss_guide", "Movement directions during supported mechanics")
                text("Movement features never replace manual positioning or direct movement input.", 416, 600,
                    small_font(), c(235, 224, 203))
            elseif page == 6 then
                row("Automatic Beacon", state.auto_beacon, 330, "toggle_beacon", "Talent-aware Beacon maintenance")
                row("Automatic aura", state.auto_aura, 380, "toggle_aura", "Group-aware aura selection")
                row("Automatic dispel", state.auto_dispel, 430, "toggle_dispel", "Cleanse eligible allies")
                row("Mythic+ interrupts", state.interrupt, 480, "toggle_interrupt", "Interrupt dangerous casts")
                row("Automatic facing", state.auto_face, 530, "toggle_face", "Face without moving")
                row("Training dummy rotation", state.training_dummy, 580, "toggle_training_dummy", "Safe city rotation testing")
            elseif page == 7 then
                row("Automatic fishing", state.fishing, 330, "toggle_fishing", "Fish while out of combat")
                row("Automatic looting", state.looting, 380, "toggle_looting", "Loot eligible nearby corpses")
                row("Automatic aura", state.auto_aura, 430, "toggle_aura", "Use Crusader Aura while mounted")
                row("Automatic Divine Steed", state.auto_steed, 480, "toggle_steed", "Faster sustained travel")
                text("Fishing pauses corpse looting while active. Combat pauses both gathering tools.", 416, 550,
                    small_font(), c(235, 224, 203))
            elseif page == 8 then
                local hotkey_rows = {
                    { "Entire plugin", state.plugin_enabled, "toggle_plugin" },
                    { "Healing rotation", state.global_healing, "toggle_healing" },
                    { "Healing cooldowns", state.healing_cooldowns, "toggle_healing_cooldowns" },
                    { "Automatic Beacon", state.auto_beacon, "toggle_beacon" },
                    { "Automatic dispel", state.auto_dispel, "toggle_dispel" },
                    { "Defensives and saves", state.personals, "toggle_personals" },
                    { "Damage rotation", state.damage, "toggle_damage" },
                    { "Interrupts", state.interrupt, "toggle_interrupt" },
                    { "PvP crowd control", state.auto_cc, "toggle_cc" },
                    { "Aura selection", state.auto_aura, "toggle_aura" },
                    { "Divine Steed", state.auto_steed, "toggle_steed" },
                    { "Automatic facing", state.auto_face, "toggle_face" },
                    { "Automatic targeting", state.auto_target, "toggle_target" },
                    { "Training dummy", state.training_dummy, "toggle_training_dummy" },
                    { "Arena teammate lines", state.arena_lines, "toggle_arena_lines" },
                    { "Danger zones", state.danger_zones, "toggle_danger_zones" },
                    { "Boss helper", state.boss_guide, "toggle_boss_guide" },
                    { "Automatic fishing", state.fishing, "toggle_fishing" },
                    { "Automatic looting", state.looting, "toggle_looting" },
                    { "Encounter recorder", state.log_enabled, "toggle_log" },
                }
                text("BIND KEYS IN INSERT > HOLY PALADIN HEALING", 416, 326,
                    small_font(), c(235, 202, 132))
                button("UP", 790, 316, 870, 350, function() pve_scroll = math.max(0, pve_scroll - 1) end, false)
                button("DOWN", 880, 316, 960, 350,
                    function() pve_scroll = math.min(math.max(0, #hotkey_rows - 5), pve_scroll + 1) end, false)
                local wheel = hovered(398, 350, 978, 680) and mouse_wheel_delta() or 0
                if wheel ~= 0 and core.time() - last_pve_scroll > 0.08 then
                    pve_scroll = math.max(0, math.min(math.max(0, #hotkey_rows - 5),
                        pve_scroll + (wheel < 0 and 1 or -1)))
                    last_pve_scroll = core.time()
                end
                for visible = 1, 5 do
                    local item = hotkey_rows[pve_scroll + visible]
                    if item then row(item[1], item[2], 360 + (visible - 1) * 50, item[3], "Customer assigned hotkey") end
                end
                text("Showing " .. tostring(pve_scroll + 1) .. "-" ..
                    tostring(math.min(#hotkey_rows, pve_scroll + 5)) .. " of " .. tostring(#hotkey_rows),
                    416, 624, small_font(), c(235, 224, 203))
            elseif page == 9 then
                local T = require("holy_paladin_telemetry")
                row("Encounter recorder", state.log_enabled, 330, "toggle_log", "Persistent Holy Paladin session log")
                button("COPY LOG PATH", 416, 390, 586, 432,
                    function()
                        if type(window.copy_to_clipboard) == "function" then
                            window:copy_to_clipboard(T.path()); action("notice", "Log path copied")
                        end
                    end, false)
                button("COPY CURRENT RUN", 596, 390, 776, 432,
                    function()
                        if type(window.copy_to_clipboard) == "function" then
                            window:copy_to_clipboard(T.current_run()); action("notice", "Current run copied")
                        end
                    end, false)
                button("CLEAR LOG", 786, 390, 960, 432, function() action("clear_log") end, false)
                button("RESET DEBUGGER", 416, 445, 586, 487, function() action("reset_debug") end, false)
                button("RESET WINDOW", 596, 445, 776, 487,
                    function() reset_position(); action("notice", "Window position reset") end, false)
                local d = state.debugger or {}
                rect(416, 502, 960, 650, c(28, 22, 16, 232), 7)
                text("RUN: " .. (d.active and "ACTIVE" or "IDLE") .. "  |  MODE: " ..
                    tostring(d.mode or "none") .. "  |  REQUESTS: " .. tostring(d.requests or 0),
                    430, 516, small_font(), d.active and c(105, 239, 156) or c(235, 202, 132))
                text("LAST: " .. compact(d.last_request or state.last or "none", 68), 430, 548,
                    small_font(), c(255, 247, 230))
                text("SKIP: " .. compact(d.last_skip or "none", 68), 430, 580,
                    small_font(), c(235, 224, 203))
                text("ERROR: " .. compact(d.last_error or "none", 67), 430, 612,
                    small_font(), d.last_error ~= "none" and c(255, 128, 112) or c(105, 239, 156))
            end
            rect(398, 702, 978, 746, c(43, 32, 21, 218), 6)
            rect(20, 703, 118, 746, c(242, 231, 207, 225), 6)
            text("F1  HIDE", 34, 717, small_font(), c(67, 43, 17))
            text("STATUS: " .. compact(state.status or "Ready", 20) .. "  |  " ..
                compact(state.notice or "Talents detected automatically", 25), 415, 717,
                small_font(), c(255, 247, 230))
            rect(884, 708, 968, 740, c(249, 239, 216, 248), 6)
            outline(884, 708, 968, 740, c(222, 185, 105, 255), 6, 2)
            text("v4.68.0", 900, 717, small_font(), c(47, 29, 10))
            outline(1, 1, 998, 758, c(204, 165, 89, 255), 10, 2)
        end)
    end)
    if not ok and not render_error_reported then
        render_error_reported = true
        if type(action) == "function" then pcall(action, "debug_error", tostring(err)) end
        if type(core.log_warning) == "function" then pcall(core.log_warning, "[Holy Paladin GUI] " .. tostring(err)) end
    end
end
return M

