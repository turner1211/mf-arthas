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
local panel_w, panel_h = 1180, 780
local labels = { "PVE DAMAGE", "PVP / CONTROL", "ROTATION", "CONTROL", "SURVIVAL", "UTILITY", "GATHERING", "BOSS TOOLS", "HOTKEYS", "DISPLAY / LOGS", "CORE" }
local themes={
 {118,226,107,'POISON • PRECISION • PRESSURE'},{230,62,88,'SETUP • CONTROL • FINISH'},
 {100,220,116,'BLEEDS • ENERGY • EXECUTION'},{164,105,255,'SAP • BLIND • KIDNEY'},
 {245,177,66,'ANTICIPATE • TRADE • ESCAPE'},{77,180,235,'MOBILITY • TARGETING • STEALTH'},
 {54,205,170,'LOOT • FISH • SKIN'},{240,124,70,'MECHANICS • POSITION • SURVIVE'},
 {62,204,230,'BIND • TOGGLE • CUSTOMIZE'},{185,197,210,'RECORD • REVIEW • IMPROVE'},
 {215,70,91,'SYSTEM • SAFETY • PERFORMANCE'}}
local accent={118,226,107}

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
    rect(x1+2, y1+3, x2+2, y2+3, c(3, 7, 8, 185), 6)
    rect(x1, y1, x2, y2, active and c(accent[1],accent[2],accent[3],248) or
        (over and c(accent[1],accent[2],accent[3],150) or c(21, 27, 29, 224)), 5)
    outline(x1,y1,x2,y2,active and c(232,246,218,245) or c(accent[1],accent[2],accent[3],over and 230 or 105),5,active and 2 or 1)
    if active then rect(x1,y1+5,x1+5,y2-5,c(240,249,224,245),3) end
    local icon=Icons.for_label(label)
    local offset=10
    if icon and x2-x1>=130 then
        local icon_size=math.max(24,math.min(36,y2-y1-4))
        local icon_y=y1+math.floor((y2-y1-icon_size)/2)
        Icons.draw(icon,x1+4,icon_y,icon_size,win_x,win_y,window)
        outline(x1+3,icon_y-1,x1+5+icon_size,icon_y+icon_size+1,
            active and c(245,255,240) or c(accent[1],accent[2],accent[3],210),4,1)
        offset=icon_size+13
    end
    text(label, x1 + offset, y1 + 10, small_font(), active and c(12, 28, 16) or c(237, 245, 237))
    if clicked(x1, y1, x2, y2) then action() end
end
local function toggle_row(label, value, x, y, x2, on_click, note, hotkey, on_hotkey)
    local over = hovered(x, y, x2, y + 50)
    rect(x+2, y+3, x2+2, y + 53, c(2,7,8,170), 6)
    rect(x, y, x2, y + 50, c(17, 27, 28, 239), 6)
    outline(x, y, x2, y + 50, over and c(accent[1],accent[2],accent[3],235) or c(65, 78, 76, 190), 6, over and 2 or 1)
    local icon=Icons.for_label(label);local offset=14
    if icon then
        rect(x+6,y+5,x+46,y+45,c(8,16,17,245),7)
        Icons.draw(icon,x+9,y+8,34,win_x,win_y,window)
        outline(x+6,y+5,x+46,y+45,c(accent[1],accent[2],accent[3],230),7,2);offset=56
    end
    text(Text.compact(label,36), x + offset, y + 7, small_font(), c(244, 237, 219))
    if note and note ~= "" then text(Text.compact(note,43), x + offset, y + 28, small_font(), c(186, 203, 189)) end
    local enabled = value == true
    local switch_x1,switch_x2=x2-292,x2-198
    rect(switch_x1,y+11,switch_x2,y+39,enabled and c(accent[1],accent[2],accent[3],225) or c(48,59,59,245),14)
    outline(switch_x1,y+11,switch_x2,y+39,c(accent[1],accent[2],accent[3],190),14,1)
    local knob_x=enabled and switch_x2-26 or switch_x1+4
    rect(knob_x,y+14,knob_x+22,y+36,enabled and c(235,250,220) or c(145,151,149),11)
    text(enabled and "ON" or "OFF",enabled and switch_x1+15 or switch_x1+38,y+17,small_font(),enabled and c(12,28,16) or c(224,232,227))
    local key_x1,key_x2=x2-188,x2-82
    local key_over=hovered(key_x1,y+9,key_x2,y+41)
    rect(key_x1,y+9,key_x2,y+41,key_over and c(accent[1],accent[2],accent[3],135) or c(25,35,36,245),6)
    outline(key_x1,y+9,key_x2,y+41,c(accent[1],accent[2],accent[3],190),6,1)
    text(Text.compact(hotkey or 'HK OFF',12),key_x1+10,y+18,small_font(),c(238,229,207))
    local left_x1,left_x2=x2-72,x2-40
    local right_x1,right_x2=x2-34,x2-2
    rect(left_x1,y+9,left_x2,y+41,c(24,34,35,245),6);outline(left_x1,y+9,left_x2,y+41,c(accent[1],accent[2],accent[3],175),6,1)
    rect(right_x1,y+9,right_x2,y+41,c(24,34,35,245),6);outline(right_x1,y+9,right_x2,y+41,c(accent[1],accent[2],accent[3],175),6,1)
    text("<",left_x1+11,y+17,small_font(),c(240,218,171));text(">",right_x1+11,y+17,small_font(),c(240,218,171))
    if clicked(key_x1,y+9,key_x2,y+41) or clicked(left_x1,y+9,left_x2,y+41) or clicked(right_x1,y+9,right_x2,y+41) then
        if on_hotkey then on_hotkey() end
    elseif clicked(x, y, x2, y + 50) then on_click() end
end

local function compact(value, limit)
    value = Text.clean(value)
    return require("mf_i18n").clip(require("mf_i18n").text(value), limit)
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
        local theme=themes[page] or themes[1]
        accent={theme[1],theme[2],theme[3]}
        local mouse_down, cursor = false, nil
        if type(core.get_cursor_position) == "function" then cursor = core.get_cursor_position() end
        if core.input and type(core.input.is_key_pressed) == "function" then
            local mok, pressed = pcall(core.input.is_key_pressed, 0x01)
            mouse_down = mok and pressed == true
        end
        if cursor and mouse_down and not mouse_was_down and cursor.x >= win_x
            and cursor.x <= win_x + panel_w and cursor.y >= win_y and cursor.y <= win_y + 112 then
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
            -- Header and status bar: Rogue-class identity remains constant while
            -- the accent and motto communicate the selected activity page.
            rect(18, 10, 1158, 112, c(10, 18, 19, 238), 10)
            outline(18, 10, 1158, 112, c(accent[1],accent[2],accent[3],220), 10, 2)
            rect(35,24,112,99,c(21,29,29,245),38)
            outline(35,24,112,99,c(accent[1],accent[2],accent[3],240),38,3)
            Icons.draw(32645,48,36,50,win_x,win_y,window)
            text("SHADOWS OF VALEERA", 130, 20, font.FONT_BIG or 0, c(241, 230, 206))
            text(string.upper(state.spec_name or "ROGUE").." ROGUE SUITE  •  v"..require('ar_version'), 132, 54,
                small_font(), c(accent[1],accent[2],accent[3]))
            text(theme[4],132,79,small_font(),c(206,218,211))
            button("MODE: "..compact(state.mode_label or "DETECT",16), 740, 31, 925, 75,
                function() action("auto_mode") end, true)
            button(state.plugin_enabled and "PROFILE ACTIVE" or "PROFILE PAUSED", 938, 31, 1138, 75,
                function() action("toggle_plugin") end, state.plugin_enabled)
            text("CLIENT: "..string.upper(state.game_branch or 'retail').."   •   LEVEL: "..tostring(state.level or '?').."   •   BUILD: "..compact(state.hero or 'Unknown',20).."   •   EDITING: "..compact(state.profile_name or 'Auto',14),740,84,small_font(),c(222,231,224))

            -- Permanent navigation rail modeled after the customer reference.
            rect(18, 122, 270, 708, c(9, 18, 19, 235), 9)
            outline(18,122,270,708,c(75,88,82,220),9,1)
            local gap, tabw = 5, 230
            for i, label in ipairs(labels) do
                local y1=132+(i-1)*49
                button(label, 29, y1, 29+tabw, y1+43,
                    function() page = i; pve_scroll = 0; action("notice", label .. " tab opened") end, page == i)
            end

            rect(282, 122, 1158, 708, c(9, 20, 20, 234), 9)
            outline(282,122,1158,708,c(accent[1],accent[2],accent[3],150),9,1)
            local shortcuts={{703,'Garrote',1},{1943,'Rupture',1},{32645,'Envenom',1},{6770,'Sap',2},{408,'Kidney Shot',2},{212182,'Smoke Bomb',2}}
            for i,entry in ipairs(shortcuts) do
                local ix=31+(i-1)*38
                rect(ix,676,ix+33,709,c(18,27,27,245),5)
                outline(ix,676,ix+33,709,hovered(ix,676,ix+33,709) and c(accent[1],accent[2],accent[3]) or c(91,105,98),5)
                Icons.draw(entry[1],ix+3,679,27,win_x,win_y,window)
                if hovered(ix,676,ix+33,709) then text(entry[2],31,715,small_font(),c(237,245,237)) end
                if clicked(ix,676,ix+33,709) then page=entry[3];pve_scroll=0;action('notice',entry[2]..' settings opened') end
            end
            text(labels[page].." CUSTOMIZATION", 312, 145, font.FONT_SEMI_BIG or 0, c(accent[1],accent[2],accent[3]))
            text(theme[4],312,174,small_font(),c(180,197,188))
            local function row(label, value, y, kind, note, hotkey, hotkey_id, key)
                toggle_row(label, value, 312, y, 1128, function() action(kind,key) end, note,hotkey,
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
                        312 + (i-1)*267, 198, 562 + (i-1)*267, 238,
                        function() action("set_mode", key) end, state.editing_mode == key)
                end
                local p = state.profiles[state.editing_mode or state.active_mode]
                text(p.label .. " SETTINGS", 312, 252, small_font(), c(accent[1],accent[2],accent[3]))
                local mode=state.editing_mode or state.active_mode
                row("Damage rotation", p.damage, 270, "profile_damage", "Separate logic for this activity",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_damage'],'profile_'..mode..'_damage')
                row("Stealth opener / first pressure", p.opener, 329, "profile_opener", "Confirmed casts advance the opener",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_opener'],'profile_'..mode..'_opener')
                row("Kill-window cooldowns", p.cooldowns, 388, "profile_cooldowns", "Bleed setup before major cooldowns",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_cooldowns'],'profile_'..mode..'_cooldowns')
                row("Control chains / peels", p.cc, 447, "profile_cc", "DR-aware setups and defensive peels",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_cc'],'profile_'..mode..'_cc')
                row("Survival / defensive trades", p.defensives, 506, "profile_defensives", "Predictive personal cooldown trades",state.hotkey_labels and state.hotkey_labels['profile_'..mode..'_defensives'],'profile_'..mode..'_defensives')
                text("AUTOMATIC BURST • ACTIVITY DETECTION • SAFE CONFIRMATION",312,578,small_font(),c(accent[1],accent[2],accent[3]))
            elseif page == 10 then
                local T = require("ar_telemetry")
                row("Encounter recorder", state.log_enabled, 215, "toggle_log", "Casts, outcomes, resources and gathering",state.hotkey_labels and state.hotkey_labels.toggle_logging,'toggle_logging')
                button("COPY SAVED LOG",312,290,555,334,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(T.saved_log()) end
                end,false)
                button("COPY THIS RUN",565,290,810,334,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(T.current_run()) end
                end,false)
                button("CLEAR LOG",820,290,1128,334,function() action("clear_log") end,false)
                rect(312,350,1128,490,c(15,27,28,238),7)
                outline(312,350,1128,490,c(accent[1],accent[2],accent[3],125),7,1)
                text("LOG FILE  "..compact(T.path(),80),330,370,small_font(),c(237, 245, 237))
                text("RECORDER  " .. compact(T.status,74),330,403,small_font(),c(accent[1],accent[2],accent[3]))
                text("SESSION   " .. compact(T.run_status(),74),330,436,small_font(),c(237, 245, 237))
                text("BOSS TIMER  " .. compact(state.timer_status or "Unavailable",70),330,469,small_font(),c(accent[1],accent[2],accent[3]))
                local D=require('ar_debug')
                button(D.enabled and "DEBUG ON" or "DEBUG OFF",312,515,555,559,function() action("debug_toggle") end,D.enabled)
                button("CAPTURE STATE",565,515,810,559,function() action("debug_snapshot") end,false)
                button("COPY DEBUG",820,515,1128,559,function()
                    if window.copy_to_clipboard then window:copy_to_clipboard(D.last_snapshot or D.path()) end
                end,false)
                text("DEBUGGER  "..compact(D.status,88),312,580,small_font(),c(accent[1],accent[2],accent[3]))
            else
                local rows = state.pages[page] or {}
                local max_scroll = math.max(0,#rows-5)
                pve_scroll = math.min(pve_scroll,max_scroll)
                button("PREVIOUS",916,195,1017,232,function() pve_scroll=math.max(0,pve_scroll-1) end,false)
                button("NEXT",1027,195,1128,232,function() pve_scroll=math.min(max_scroll,pve_scroll+1) end,false)
                text(string.format("ITEMS %d-%d OF %d", math.min(#rows, pve_scroll + 1),
                    math.min(#rows, pve_scroll + 5), #rows), 312, 207, small_font(), c(186, 203, 189))
                local wheel=hovered(300,240,1140,650) and mouse_wheel_delta() or 0
                if wheel~=0 and core.time()-last_pve_scroll>0.08 then
                    pve_scroll=math.max(0,math.min(max_scroll,pve_scroll+(wheel<0 and 1 or -1)))
                    last_pve_scroll=core.time()
                end
                for i=1,5 do
                    local item=rows[pve_scroll+i]
                    if item then row(item.label,item.value,246+(i-1)*68,item.action,item.note,item.hotkey,item.hotkey_id,item.key) end
                end
                if page==9 then text(compact(state.hotkey_status or 'Click a key pill to bind',88),312,602,small_font(),c(accent[1],accent[2],accent[3])) end
            end

            rect(18, 719, 1158, 765, c(8, 17, 18, 244), 7)
            outline(18,719,1158,765,c(accent[1],accent[2],accent[3],145),7,1)
            rect(29, 726, 137, 758, c(accent[1],accent[2],accent[3],235), 6)
            text("F1  HIDE", 48, 735, small_font(), c(14, 25, 18))
            text("STATUS: " .. compact(state.status or "Ready", 66), 300, 727,
                small_font(), c(237, 245, 237))
            text("NOTICE: " .. compact(state.notice or "Automatic activity detection", 66), 300, 746,
                small_font(), c(186, 203, 189))
            rect(1030, 726, 1144, 758, c(accent[1],accent[2],accent[3],248), 6)
            outline(1030, 726, 1144, 758, c(accent[1],accent[2],accent[3],255), 6, 2)
            text("v"..require('ar_version'), 1050, 735, small_font(), c(14, 24, 18))
            outline(1, 1, 1178, 778, c(accent[1],accent[2],accent[3],255), 10, 2)
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
