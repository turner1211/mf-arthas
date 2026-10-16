-- PvP panel with font-safe labels. Valeera art is the canvas; translucent controls
-- stay on the right so the character remains visible.
local M = {}
local Text=require('ar_text')
local Icons=require('ar_icons')
local color, vec2, enums, assets, window
local art_texture,art_attempted=nil,false
local function small_font() return enums and enums.window_enums.font_id.FONT_SMALL or 0 end
local page, win_x, win_y = 1, 45, 45
local pve_scroll, last_pve_scroll = 0, -math.huge
local dragging, mouse_was_down, reported = nil, false, false
local panel_w, panel_h = 1000, 760
local labels = { "PVE DAMAGE", "PVP / CONTROL", "ROTATION", "CONTROL", "SURVIVAL", "UTILITY", "GATHERING", "BOSS TOOLS", "HOTKEYS", "DISPLAY / LOGS", "CORE" }

local function initialize_window()
    if window then return true end
    local ok = pcall(function()
        color = color or require("common/color")
        vec2 = vec2 or require("common/geometry/vector_2")
        enums = enums or require("common/enums")
        window = core.menu.window("ar_valeera_100")
        window:set_initial_position(vec2.new(win_x, win_y))
        window:set_initial_size(vec2.new(panel_w, panel_h))
        if type(window.set_render_layer) == "function" then window:set_render_layer(1) end
        window:set_visibility(false)
    end)
    return ok and window ~= nil
end

local function c(r, g, b, a) return color.new(r, g, b, a or 255) end
local function rect(x1, y1, x2, y2, col, radius)
    window:render_rect_filled(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5)
end
local function outline(x1, y1, x2, y2, col, radius, thickness)
    window:render_rect(vec2.new(x1, y1), vec2.new(x2, y2), col, radius or 5, thickness or 1)
end
local function text(value, x, y, font, col)
    window:render_text(font, vec2.new(x, y), col, Text.clean(value))
end
local function clicked(x1, y1, x2, y2)
    return window:is_rect_clicked(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function hovered(x1, y1, x2, y2)
    return window:is_mouse_hovering_rect(vec2.new(x1, y1), vec2.new(x2, y2))
end
local function button(label, x1, y1, x2, y2, action, active)
    local over = hovered(x1, y1, x2, y2)
    rect(x1, y1, x2, y2, active and c(118, 226, 107, 248) or
        (over and c(117, 28, 41, 236) or c(49, 17, 25, 210)), 5)
    local icon=Icons.for_label(label)
    local offset=10
    if icon and x2-x1>=130 then
        local icon_size=math.max(24,math.min(36,y2-y1-4))
        local icon_y=y1+math.floor((y2-y1-icon_size)/2)
        Icons.draw(icon,x1+4,icon_y,icon_size,win_x,win_y,window)
        outline(x1+3,icon_y-1,x1+5+icon_size,icon_y+icon_size+1,
            active and c(226,255,218) or c(163,233,149,210),4,1)
        offset=icon_size+13
    end
    text(label, x1 + offset, y1 + 10, small_font(), active and c(12, 28, 16) or c(237, 245, 237))
    if clicked(x1, y1, x2, y2) then action() end
end
local function toggle_row(label, value, x, y, x2, on_click, note, hotkey, on_hotkey)
    local over = hovered(x, y, x2, y + 45)
    rect(x, y, x2, y + 45, c(25, 17, 25, 224), 5)
    outline(x, y, x2, y + 45, over and c(118, 226, 107, 235) or c(91, 49, 63, 190), 5, over and 2 or 1)
    local icon=Icons.for_label(label);local offset=14
    if icon then
        Icons.draw(icon,x+5,y+4,37,win_x,win_y,window)
        outline(x+4,y+3,x+43,y+42,c(163,233,149,210),4,1);offset=52
    end
    text(Text.compact(label,30), x + offset, y + 6, small_font(), c(237, 245, 237))
    if note and note ~= "" then text(Text.compact(note,35), x + offset, y + 26, small_font(), c(186, 203, 189)) end
    local enabled = value == true
    local key_x1,key_x2=x2-176,x2-84
    local key_over=hovered(key_x1,y+10,key_x2,y+35)
    rect(key_x1,y+10,key_x2,y+35,key_over and c(117,28,41,245) or c(43,31,45,245),6)
    outline(key_x1,y+10,key_x2,y+35,c(163,233,149,190),6,1)
    text(Text.compact(hotkey or 'UNBOUND',12),key_x1+8,y+15,small_font(),c(224,241,218))
    rect(x2 - 75, y + 10, x2 - 14, y + 35, enabled and c(118, 226, 107) or c(62, 44, 54), 6)
    text(enabled and "ON" or "OFF", x2 - 58, y + 15, small_font(),
        enabled and c(12, 28, 16) or c(237, 245, 237))
    if clicked(key_x1,y+10,key_x2,y+35) then if on_hotkey then on_hotkey() end
    elseif clicked(x, y, x2, y + 45) then on_click() end
end

local function compact(value, limit)
    value = Text.clean(value)
    if #value <= limit then return value end
    return value:sub(1, limit - 3) .. "..."
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
    if not state or state.eligible ~= true then
        if window then window:set_visibility(false) end
        return
    end
    if not initialize_window() then return end
    window:set_visibility(state.window_open ~= false)
    if state.window_open == false then return end
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
        local flags = we.window_resizing_flags or {}
        local visuals = we.window_cross_visuals or {}
        local font = we.font_id or {}
        if type(window.set_next_window_min_size) == "function" then
            window:set_next_window_min_size(vec2.new(panel_w, panel_h))
        end
        if type(window.force_window_size) == "function" then window:force_window_size(vec2.new(panel_w, panel_h)) end
        if type(window.force_next_begin_window_pos) == "function" then
            window:force_next_begin_window_pos(vec2.new(win_x, win_y))
        end
        window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0, false,
            c(15, 12, 20, 255), c(167, 40, 60, 255), visuals.NO_CROSS or 9, function()
            -- Native fallback only while the cached artwork is unavailable.
            if not art_texture then
            for band=0,19 do
                rect(band*50,0,(band+1)*50,panel_h,c(52-band*2,12,20,255),0)
            end
            outline(30,30,365,650,c(145,35,55),18,3)
            rect(110,85,280,260,c(105,22,39),45)
            rect(140,145,250,260,c(22,15,23),28)
            rect(155,173,181,180,c(107,238,85),2)
            rect(211,173,237,180,c(107,238,85),2)
            rect(97,264,293,600,c(42,22,32),30)
            for dagger=0,1 do
                local x=72+dagger*232
                rect(x,340,x+10,570,c(155,225,142),2)
                rect(x-12,560,x+22,571,c(144,45,57),2)
                rect(x,571,x+10,620,c(48,32,37),2)
            end
            text("VALEERA",110,630,font.FONT_BIG or 0,c(163,233,149))
            end

            -- Match the Shaman texture fix: screen coordinates and top 2D layer.
            if not art_attempted then
                art_attempted=true
                if core.graphics and type(core.graphics.load_texture)=='function' then
                    local loaded,texture=pcall(function()
                        return core.graphics.load_texture(require('ar_art'))
                    end)
                    if loaded then art_texture=texture end
                end
            end
            if art_texture and core.graphics and type(core.graphics.draw_texture)=='function' then
                local position=type(window.get_position)=='function' and window:get_position() or vec2.new(win_x,win_y)
                local drawn,draw_error=pcall(core.graphics.draw_texture,art_texture,vec2.new(position.x,position.y),panel_w,panel_h,c(255,255,255,255),true)
                if not drawn and not reported then
                    reported=true
                    if core.log then core.log('[Assassination GUI] Valeera texture: '..tostring(draw_error)) end
                end
            end

            -- Keep every label on a controlled contrast surface while leaving
            -- the Valeera portrait and the full-window artwork visible.
            rect(500, 10, 978, 91, c(15, 13, 21, 224), 8)
            outline(500, 10, 978, 91, c(118, 226, 107, 210), 8, 1)
            text("ASSASSINATION ROGUE", 520, 19, font.FONT_BIG or 0, c(236, 246, 232))
            text("VALEERA  |  PRESSURE • SETUP • SURVIVAL", 521, 49,
                small_font(), c(163, 233, 149))
            text("F1 OPEN/CLOSE  |  SWITCH + OPTIONAL HOTKEY  |  DRAG HEADER", 521, 73,
                small_font(), c(211, 221, 216))

            rect(398, 96, 978, 164, c(33, 15, 23, 222), 8)
            text("Mode: " .. tostring(state.mode_label or "Detecting"), 415, 105,
                small_font(), c(237, 245, 237))
            text("Build: " .. tostring(state.hero or "Unknown"), 415, 134,
                small_font(), c(163, 233, 149))
            text("Editing: " .. compact(state.profile_name or "Detecting", 27), 590, 105,
                small_font(), c(237, 245, 237))
            text("Last: " .. compact(state.last or "Waiting", 30), 590, 134,
                small_font(), c(197, 213, 205))
            button(state.plugin_enabled and "ON" or "PAUSED", 815, 109, 881, 151,
                function() action("toggle_plugin") end, state.plugin_enabled)
            button("AUTO", 888, 109, 969, 151,
                function() action("auto_mode") end, state.auto_mode)

            rect(18, 172, 982, 292, c(55, 15, 27, 115), 8)
            local gap, tabw = 8, 184
            for i, label in ipairs(labels) do
                local row = math.floor((i - 1) / 5)
                local col = (i - 1) % 5
                local x1 = 22 + col * (tabw + gap)
                button(label, x1, 178 + row * 36, x1 + tabw, 210 + row * 36,
                    function() page = i; pve_scroll = 0; action("notice", label .. " tab opened") end, page == i)
            end

            rect(398, 300, 978, 690, c(18, 15, 23, 222), 9)
            local shortcuts={{703,'Garrote',1},{1943,'Rupture',1},{32645,'Envenom',1},{6770,'Sap',2},{408,'Kidney Shot',2},{212182,'Smoke Bomb',2}}
            for i,entry in ipairs(shortcuts) do
                local ix=24+(i-1)*59
                rect(ix,662,ix+50,712,c(25,17,25,235),5)
                outline(ix,662,ix+50,712,hovered(ix,662,ix+50,712) and c(118,226,107) or c(150,50,70),5)
                Icons.draw(entry[1],ix+5,667,40,win_x,win_y,window)
                if hovered(ix,662,ix+50,712) then text(entry[2],24,722,small_font(),c(237,245,237)) end
                if clicked(ix,662,ix+50,712) then page=entry[3];pve_scroll=0;action('notice',entry[2]..' settings opened') end
            end
            text(labels[page], 416, 309, font.FONT_SEMI_BIG or 0, c(128, 234, 114))
            local function row(label, value, y, kind, note, hotkey, hotkey_id, key)
                toggle_row(label, value, 416, y, 960, function() action(kind,key) end, note,hotkey,
                    hotkey_id and function() action('hotkey_capture',hotkey_id) end or nil)
            end
            local function profile_button(label, key, x1, y)
                button((state.editing_mode == key and "ACTIVE: " or "USE: ") .. label,
                    x1, y, x1 + 170, y + 37, function() action("set_mode", key) end,
                    state.editing_mode == key)
            end
            local keys = page == 1 and {"pve", "mythic_plus", "delve"}
                or page == 2 and {"arena", "battleground", "world_pvp"} or nil
            if keys then
                for i, key in ipairs(keys) do
                    button(state.profiles[key].label,
                        416 + (i-1)*181, 339, 589 + (i-1)*181, 375,
                        function() action("set_mode", key) end, state.editing_mode == key)
                end
                local p = state.profiles[state.editing_mode or state.active_mode]
                text(p.label .. " SETTINGS (EDIT ONLY)", 416, 385, small_font(), c(163, 233, 149))
                local mode=state.editing_mode or state.active_mode
                row("Damage rotation", p.damage, 405, "profile_damage", "Separate logic for this activity",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_damage'],'profile_'..mode..'_damage')
                row("Stealth opener / first pressure", p.opener, 454, "profile_opener", "Confirmed casts advance the opener",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_opener'],'profile_'..mode..'_opener')
                row("Kill-window cooldowns", p.cooldowns, 503, "profile_cooldowns", "Bleed setup before major cooldowns",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_cooldowns'],'profile_'..mode..'_cooldowns')
                row("Control chains / peels", p.cc, 552, "profile_cc", "DR-aware setups and defensive peels",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_cc'],'profile_'..mode..'_cc')
                row("Survival / defensive trades", p.defensives, 601, "profile_defensives", "Predictive personal cooldown trades",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_defensives'],'profile_'..mode..'_defensives')
                text("AUTOMATIC BURST - NO REQUEST NEEDED",416,656,small_font(),c(163,233,149))
            elseif page == 10 then
                local T = require("ar_telemetry")
                row("Encounter recorder", state.log_enabled, 345, "toggle_log", "Casts, outcomes, resources and gathering",state.hotkey_labels and state.hotkey_labels.toggle_logging,'toggle_logging')
                button("COPY SAVED LOG",416,438,588,478,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(T.saved_log()) end
                end,false)
                button("COPY THIS RUN",598,435,772,478,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(T.current_run()) end
                end,false)
                button("CLEAR LOG",780,435,960,478,function() action("clear_log") end,false)
                text(compact(T.path(),57),416,490,small_font(),c(237, 245, 237))
                text("Recorder: " .. compact(T.status,48),416,520,small_font(),c(163, 233, 149))
                text("Session: " .. compact(T.run_status(),48),416,550,small_font(),c(237, 245, 237))
                text("Boss timer: " .. compact(state.timer_status or "Unavailable",46),416,580,small_font(),c(163,233,149))
                local D=require('ar_debug')
                button(D.enabled and "DEBUG ON" or "DEBUG OFF",416,606,580,644,function() action("debug_toggle") end,D.enabled)
                button("CAPTURE STATE",590,606,765,644,function() action("debug_snapshot") end,false)
                button("COPY DEBUG",775,606,960,644,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(D.last_snapshot or D.path()) end
                end,false)
                text("Debugger: "..compact(D.status,45),416,657,small_font(),c(163,233,149))
            else
                local rows = state.pages[page] or {}
                local max_scroll = math.max(0,#rows-5)
                pve_scroll = math.min(pve_scroll,max_scroll)
                button("UP",780,315,865,350,function() pve_scroll=math.max(0,pve_scroll-1) end,false)
                button("DOWN",875,315,960,350,function() pve_scroll=math.min(max_scroll,pve_scroll+1) end,false)
                text(string.format("ITEMS %d-%d OF %d", math.min(#rows, pve_scroll + 1),
                    math.min(#rows, pve_scroll + 5), #rows), 416, 327, small_font(), c(186, 203, 189))
                local wheel=hovered(398,355,978,682) and mouse_wheel_delta() or 0
                if wheel~=0 and core.time()-last_pve_scroll>0.08 then
                    pve_scroll=math.max(0,math.min(max_scroll,pve_scroll+(wheel<0 and 1 or -1)))
                    last_pve_scroll=core.time()
                end
                for i=1,5 do
                    local item=rows[pve_scroll+i]
                    if item then row(item.label,item.value,370+(i-1)*57,item.action,item.note,item.hotkey,item.hotkey_id,item.key) end
                end
                if page==9 then text(compact(state.hotkey_status or 'Click a key pill to bind',65),416,657,small_font(),c(163,233,149)) end
            end

            rect(398, 696, 978, 746, c(33, 15, 23, 232), 6)
            rect(20, 703, 118, 746, c(113, 215, 106, 225), 6)
            text("F1  HIDE", 34, 717, small_font(), c(14, 25, 18))
            text("STATUS: " .. compact(state.status or "Ready", 47), 415, 704,
                small_font(), c(237, 245, 237))
            text("NOTICE: " .. compact(state.notice or "Automatic activity detection", 47), 415, 726,
                small_font(), c(186, 203, 189))
            rect(884, 708, 968, 740, c(117, 225, 104, 248), 6)
            outline(884, 708, 968, 740, c(118, 226, 107, 255), 6, 2)
            text("v"..require('ar_version'), 900, 717, small_font(), c(14, 24, 18))
            outline(1, 1, 998, 758, c(167, 40, 60, 255), 10, 2)
        end)
    end)
    if not ok and not reported then
        reported = true
        if type(core.log_warning) == "function" then pcall(core.log_warning, "[Assassination GUI] " .. tostring(err)) end
    end
end
function M.hide()
    if window then window:set_visibility(false) end
end
return M
