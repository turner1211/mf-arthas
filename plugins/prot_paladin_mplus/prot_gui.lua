-- Paladin Vanguard: an optional themed control surface. The standard menu
-- remains available so a texture or window API failure can never hide settings.
local M={}
local Host=require("prot_host")
local R={page=1,x=45,y=45,w=1000,h=820,visible=true,was_f1=false,reported=false,
    dragging=nil,mouse_was_down=false}
local Settings,Routes,Logger,color,vec2,enums,window
local saved_x,saved_y
local art_texture,art_attempted,icon_art=nil,false,nil
local icon_textures,icon_attempted={},{}
local pages={"DASHBOARD","ROTATION","DEFENSE","THREAT","M+ ROUTE","BOSS GUIDE",
    "SUPPORT","AUTOMATION","HOTKEYS","TUNING","SYSTEM"}
local icons={
    "vanguard","vanguard","tanking","tanking","dungeon","tanking",
    "vanguard","automation","automation","tanking","logs",
}

local ok,err=pcall(function()
    color=require("common/color")
    vec2=require("common/geometry/vector_2")
    enums=require("common/enums")
    window=core.menu.window("prot_paladin_vanguard_610")
    if type(core.menu.slider_int)=="function" then
        saved_x=core.menu.slider_int(0,7680,R.x,"prot_paladin_vanguard_x_v1")
        saved_y=core.menu.slider_int(0,4320,R.y,"prot_paladin_vanguard_y_v1")
        if saved_x and type(saved_x.get)=="function" then R.x=saved_x:get() or R.x end
        if saved_y and type(saved_y.get)=="function" then R.y=saved_y:get() or R.y end
    end
    window:set_initial_position(vec2.new(R.x,R.y))
    window:set_initial_size(vec2.new(R.w,R.h))
    if type(window.set_render_layer)=="function" then window:set_render_layer(1) end
    window:set_visibility(true)
    pcall(function() icon_art=require("prot_icon_art") end)
end)
if not ok then R.error=tostring(err);window=nil end

local function c(r,g,b,a) return color.new(r,g,b,a or 255) end
local function rect(x1,y1,x2,y2,col,r) window:render_rect_filled(vec2.new(x1,y1),vec2.new(x2,y2),col,r or 5) end
local function line(x1,y1,x2,y2,col,r,t) window:render_rect(vec2.new(x1,y1),vec2.new(x2,y2),col,r or 5,t or 1) end
local function clean_text(value)
    local s=tostring(value==nil and "" or value)
    s=s:gsub("\226\128\162"," | "):gsub("\226\134\146"," -> ")
        :gsub("\226\128\148"," - "):gsub("\226\128\147","-")
        :gsub("\226\128\153","'"):gsub("\226\128\152","'")
    return (s:gsub("[\128-\255]+","_"):gsub("[%c]"," "):gsub("%s+"," "))
end
local function text(v,x,y,font,col) window:render_text(font,vec2.new(x,y),col,clean_text(v)) end
local function hit(x1,y1,x2,y2) return window:is_rect_clicked(vec2.new(x1,y1),vec2.new(x2,y2)) end
local function hover(x1,y1,x2,y2) return window:is_mouse_hovering_rect(vec2.new(x1,y1),vec2.new(x2,y2)) end
local function short(v,n) v=clean_text(v);return #v<=n and v or v:sub(1,n-3).."..." end
local function clamp_position(x,y)
    local screen=Host.static(core and core.graphics,"get_screen_size")
    if screen and type(screen.x)=="number" and type(screen.y)=="number" then
        x=math.min(math.max(0,screen.x-R.w),math.max(0,x))
        y=math.min(math.max(0,screen.y-R.h),math.max(0,y))
    end
    return math.max(0,x),math.max(0,y)
end
local function save_position()
    if saved_x and type(saved_x.set)=="function" then pcall(saved_x.set,saved_x,math.floor(R.x)) end
    if saved_y and type(saved_y.set)=="function" then pcall(saved_y.set,saved_y,math.floor(R.y)) end
end
local function reset_position() R.x,R.y=clamp_position(45,45);save_position() end
local function draw_icon(name,x,y,size)
    if not name or not icon_art or not core.graphics then return false end
    if not icon_textures[name] and not icon_attempted[name] then
        icon_attempted[name]=true
        icon_textures[name]=Host.static(core and core.graphics,"load_texture",icon_art[name])
    end
    if not icon_textures[name] or type(core.graphics.draw_texture)~="function" then return false end
    local position=type(window.get_position)=="function" and window:get_position() or vec2.new(R.x,R.y)
    local drawn=Host.static(core and core.graphics,"draw_texture",icon_textures[name],
        vec2.new(position.x+x,position.y+y),size,size,c(255,255,255),true)
    if drawn~=nil then line(x-1,y-1,x+size+1,y+size+1,c(226,188,93),4,1) end
    return drawn~=nil
end
local function button(label,x1,y1,x2,y2,active,fn,font,icon)
    local over=hover(x1,y1,x2,y2)
    rect(x1,y1,x2,y2,active and c(210,167,68,245) or over and c(52,82,112,245) or c(17,35,55,235),5)
    line(x1,y1,x2,y2,active and c(255,235,166) or c(103,137,170),5,1)
    local tx=x1+10
    if icon and draw_icon(icon,x1+5,y1+4,math.min(29,y2-y1-8)) then tx=x1+40 end
    text(label,tx,y1+9,font or 7,active and c(31,27,18) or c(238,244,250))
    if hit(x1,y1,x2,y2) and fn then fn() end
end
local function toggle(label,key,x,y,note,font)
    local value=Settings.on(key);local x2=964
    rect(x,y,x2,y+48,hover(x,y,x2,y+48) and c(25,51,76,238) or c(10,27,44,232),6)
    local category=(key=="route_map" or key=="route_overview" or key=="draw_route_lines" or key=="draw_next_pack" or key=="draw_pull_labels") and icons[3]
        or (key=="looting" or key=="skinning" or key=="fishing" or key=="herbing" or key=="mining" or key=="draw_herbs" or key=="draw_mining" or key=="auto_repair") and icons[4]
        or (key=="prediction" or key=="boss_timers" or key=="danger_zones" or key=="boss_guides" or key=="auto_taunt" or key=="threat_switch" or key=="interrupts" or key=="emergency_paid_wog" or key=="party_support") and icons[2] or icons[1]
    draw_icon(category,x+7,y+7,34)
    text(label,x+50,y+7,font or 7,c(248,241,215))
    text(short(note,42),x+50,y+27,font or 7,c(174,198,219))
    local key_x1=x2-176
    rect(key_x1,y+11,x2-80,y+37,c(21,44,65),6)
    line(key_x1,y+11,x2-80,y+37,c(88,121,150),6,1)
    text("KEY: "..Settings.hotkey_name(key),key_x1+8,y+16,font or 7,c(202,219,233))
    rect(x2-70,y+11,x2-13,y+37,value and c(221,177,72) or c(74,87,101),6)
    text(value and "ON" or "OFF",x2-54,y+16,font or 7,value and c(28,23,12) or c(235,239,242))
    if hit(key_x1,y+8,x2-76,y+40) then Settings.cycle_hotkey(key)
    elseif hit(x,y,x2,y+48) then Settings.toggle(key) end
end
local function action(label,x1,y1,x2,y2,fn,font) button(label,x1,y1,x2,y2,false,fn,font) end
local function status_card(label,value,x,y,value_color,font)
    rect(x,y,x+130,y+64,c(11,31,49,242),6);line(x,y,x+130,y+64,c(84,116,145),6,1)
    text(label,x+10,y+8,font or 7,c(158,186,208))
    text(value,x+10,y+31,font or 7,value_color or c(245,239,214))
end
local function number_control(label,key,x,y,minimum,maximum,step,font)
    local value=Settings.value(key);local x2=964
    rect(x,y,x2,y+40,c(10,27,44,232),6);line(x,y,x2,y+40,c(70,102,132),6,1)
    text(label,x+14,y+11,font or 7,c(238,241,220))
    action("-",x2-142,y+5,x2-102,y+35,function()
        Settings.set_value(key,math.max(minimum,value-step))
    end,font or 7)
    rect(x2-96,y+5,x2-48,y+35,c(20,43,63,245),5)
    text(tostring(value),x2-84,y+11,font or 7,c(226,188,93))
    action("+",x2-42,y+5,x2-2,y+35,function()
        Settings.set_value(key,math.min(maximum,value+step))
    end,font or 7)
end
local function poll_hotkey()
    if not core.input or type(core.input.is_key_pressed)~="function" then return end
    local down=Host.static(core and core.input,"is_key_pressed",0x70)==true
    if down and not R.was_f1 then R.visible=not R.visible;Settings.set("custom_gui",R.visible) end
    R.was_f1=down
    Settings.poll_hotkeys()
end

function M.configure(settings,routes,logger) Settings,Routes,Logger=settings,routes,logger end
function M.render()
    if not Settings then return end
    if not Settings.is_protection_paladin() then
        if window then window:set_visibility(false) end
        return true
    end
    poll_hotkey()
    R.visible=Settings.on("custom_gui")
    if not window then return false,R.error end
    window:set_visibility(R.visible)
    if not R.visible then return true end
    local success,failure=pcall(function()
        local mouse_down,cursor=false,nil
        if type(core.get_cursor_position)=="function" then
            local cursor_ok,value=pcall(core.get_cursor_position);if cursor_ok then cursor=value end
        end
        if core.input and type(core.input.is_key_pressed)=="function" then
            mouse_down=Host.static(core.input,"is_key_pressed",0x01)==true
        end
        if cursor and mouse_down and not R.mouse_was_down and cursor.x>=R.x
            and cursor.x<=R.x+R.w and cursor.y>=R.y and cursor.y<=R.y+72 then
            R.dragging={dx=cursor.x-R.x,dy=cursor.y-R.y}
            Host.static(core and core.graphics,"capture_next_mouse_input")
        end
        if R.dragging and mouse_down and cursor then
            R.x,R.y=clamp_position(cursor.x-R.dragging.dx,cursor.y-R.dragging.dy)
            Host.static(core and core.graphics,"set_mouse_capture_state",true)
        elseif R.dragging and not mouse_down then
            R.dragging=nil;save_position();Host.static(core and core.graphics,"set_mouse_capture_state",false)
        end
        R.mouse_was_down=mouse_down
        local we=enums.window_enums or enums;local flags=we.window_resizing_flags or {};local visuals=we.window_cross_visuals or {};local font=we.font_id or {}
        if type(window.set_next_window_min_size)=="function" then window:set_next_window_min_size(vec2.new(R.w,R.h)) end
        if type(window.force_window_size)=="function" then window:force_window_size(vec2.new(R.w,R.h)) end
        if type(window.force_next_begin_window_pos)=="function" then window:force_next_begin_window_pos(vec2.new(R.x,R.y)) end
        window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,c(5,14,25),c(216,177,83),visuals.NO_CROSS or 9,function()
            if not art_attempted then
                art_attempted=true
                if core.graphics and type(core.graphics.load_texture)=="function" then
                    art_texture=Host.static(core and core.graphics,"load_texture",require("prot_art"))
                end
            end
            if art_texture and core.graphics and type(core.graphics.draw_texture)=="function" then
                local position=type(window.get_position)=="function" and window:get_position() or vec2.new(R.x,R.y)
                Host.static(core and core.graphics,"draw_texture",art_texture,
                    vec2.new(position.x,position.y),R.w,R.h,c(255,255,255),true)
            end
            rect(392,8,986,92,c(5,18,31,226),8);line(392,8,986,92,c(224,184,86),8,2)
            text("PALADIN VANGUARD",414,20,font.FONT_BIG or 8,c(255,240,190))
            text("PROTECTION • MYTHIC+ • PvE STORY COMMAND",415,51,font.FONT_SMALL or 7,c(224,193,116))
            text("F1 SHOW / HIDE  |  CLICK KEY TO ASSIGN  |  v6.13.67",415,72,font.FONT_SMALL or 7,c(213,226,237))
            rect(392,100,986,151,c(5,18,31,226),7)
            text("Combat: "..short(Settings.status,28),407,112,font.FONT_SMALL or 7,c(242,246,250))
            text("Route: "..short(Settings.route_status,33),650,112,font.FONT_SMALL or 7,c(196,216,233))
            button(Settings.on("enabled") and "ROTATION ON" or "ROTATION OFF",847,108,974,142,Settings.on("enabled"),function() Settings.toggle("enabled") end,font.FONT_SMALL or 7)
            -- Two-row image-tab strip mirrors the other class panels while
            -- reserving the full left side for the Icecrown raid artwork.
            local gap,tabw=9,233
            for i,label in ipairs(pages) do
                local row=math.floor((i-1)/4);local col=(i-1)%4
                local x1=22+col*(tabw+gap);local y1=154+row*38
                button(label,x1,y1,x1+tabw,y1+35,R.page==i,function() R.page=i end,font.FONT_SMALL or 7,icons[i])
            end
            rect(392,274,986,773,c(4,16,29,234),9);line(392,274,986,773,c(91,126,160),9,1)
            if R.page==1 then
                text("COMMAND DASHBOARD",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local route=Routes and Routes.get_state and Routes.get_state() or {}
                local hud=Settings.telemetry or {}
                status_card("HOLY POWER",tostring(hud.holy_power or 0).." / 5",412,322,
                    (hud.holy_power or 0)>=3 and c(229,190,88) or c(196,216,233),font.FONT_SMALL or 7)
                status_card("SOTR ARMOR",hud.sotr_active and string.format("%.1fs",hud.sotr_remaining or 0) or "DOWN",550,322,
                    hud.sotr_active and c(126,224,151) or c(244,105,105),font.FONT_SMALL or 7)
                status_card("CONSECRATION",hud.consecration and "ACTIVE" or "OUT",688,322,
                    hud.consecration and c(126,224,151) or c(244,174,90),font.FONT_SMALL or 7)
                local risk=tostring(hud.risk or "IDLE")
                status_card("INCOMING RISK",risk,826,322,
                    (risk=="LETHAL" or risk=="SEVERE") and c(255,92,92)
                        or risk=="HIGH" and c(255,165,76) or c(126,224,151),font.FONT_SMALL or 7)
                rect(412,400,964,466,c(14,34,52,240),6)
                text("ACTIVE ROUTE",428,411,font.FONT_SMALL or 7,c(226,188,93))
                text(short(route.route_name or Settings.route_status,58),428,438,font.FONT_SMALL or 7,c(241,246,250))
                text("Pull "..tostring(route.pull_index or "-").." | Forces "..tostring(route.completed_forces or "--").."/"..tostring(route.required_forces or "--"),760,438,font.FONT_SMALL or 7,c(190,213,233))
                toggle("Master rotation","enabled",412,480,"Start or pause automated combat decisions.",font.FONT_SMALL or 7)
                toggle("Predict incoming damage","prediction",412,534,"Pre-cast defensives from damage and timers.",font.FONT_SMALL or 7)
                toggle("Maintain party threat","auto_taunt",412,588,"Recover enemies attacking party members.",font.FONT_SMALL or 7)
                toggle("M+ Auto Dungeon","route_map",412,642,"Detect dungeon and load its pull plan.",font.FONT_SMALL or 7)
                toggle("Role-aware boss guide","boss_guides",412,696,"Show your mechanic job and positioning.",font.FONT_SMALL or 7)
            elseif R.page==2 then
                text("ROTATION & PLAYSTYLE",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Master rotation","enabled","Start or pause all combat decisions."},{"Use major cooldowns","cooldowns","Use offensive and defensive cooldowns."},{"Prepare next pull","prepull","Build resources and pre-arm safe mitigation."},{"Training dummy mode","training_dummy","Run damage logic safely on city dummies."},{"Yield to manual spells","manual_input_yield","Briefly give your manual cast priority."},{"Safe target selection","auto_combat_target","Select only enemies engaged with the group."},{"Automatic tank facing","auto_face","Face an engaged target when required."},{"Devotion Aura","auto_aura","Restore Devotion Aura safely out of combat."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
            elseif R.page==3 then
                text("DEFENSE & SURVIVAL",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Predictive defense","prediction","Forecast casts, timers, trends and absorbs."},{"Boss-addon timers","boss_timers","Use BigWigs, LittleWigs, ExBoss and DBM."},{"Danger-zone auras","danger_zones","Show confirmed hazards and safe position."},{"Emergency paid Word of Glory","emergency_paid_wog","Heal at critical health behind secure armor."},{"Delve survival healing","delve_survival","Use protected emergency healing in Delves."},{"Use major cooldowns","cooldowns","Permit encounter and defensive cooldowns."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
                text("Health thresholds and forecast timing are under TUNING.",420,666,font.FONT_SMALL or 7,c(184,207,227))
            elseif R.page==4 then
                text("THREAT & CONTROL",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Maintain party threat","auto_taunt","Taunt loose enemies threatening the party."},{"Threat target switching","threat_switch","Swap when damage must recover threat."},{"Direct interrupts","interrupts","Use Rebuke and Avenger's Shield."},{"Hammer of Justice backup","stun_backup","Stun eligible casts when needed."},{"Blinding Light area stop","aoe_stop","Stop overlapping nearby casts."},{"Safe combat target selection","auto_combat_target","Acquire only engaged enemies."},{"Automatic tank facing","auto_face","Correct facing for an engaged target."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
            elseif R.page==5 then
                text("M+ AUTO DUNGEON",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                toggle("Auto dungeon guide","route_map",412,314,"Detect dungeon and follow embedded pack plan.",font.FONT_SMALL or 7)
                toggle("Route overview","route_overview",412,369,"Show the compact route overview when available.",font.FONT_SMALL or 7)
                toggle("Draw next-pull line","draw_route_lines",412,424,"Guide toward the next verified pack.",font.FONT_SMALL or 7)
                toggle("Highlight next pack","draw_next_pack",412,479,"Draw a light aura around the active pull.",font.FONT_SMALL or 7)
                toggle("Pull labels","draw_pull_labels",412,534,"Label nearby planned packs in the world.",font.FONT_SMALL or 7)
                action("PREVIOUS",412,606,570,646,Settings.actions.previous_route_pull,font.FONT_SMALL or 7)
                action("SKIP / NEXT",581,606,755,646,Settings.actions.next_route_pull,font.FONT_SMALL or 7)
                action("RESET ROUTE",766,606,964,646,Settings.actions.reset_route,font.FONT_SMALL or 7)
                text(short(Settings.route_status,75),414,676,font.FONT_SMALL or 7,c(190,213,233))
            elseif R.page==6 then
                text("BOSS GUIDE & OVERLAYS",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Role-aware boss guide","boss_guides","Show tank jobs, positions and priorities."},{"Boss-addon timers","boss_timers","Time instructions and defensive forecasts."},{"Danger-zone auras","danger_zones","Show hazards with lighter world circles."},{"Compact boss helper","boss_helper_gui","Keep the small mechanic helper available."},{"Auto-show boss helper","boss_helper_auto","Open helper automatically on boss combat."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
                rect(412,606,964,674,c(12,31,49,242),7)
                text("LIVE GUIDE",430,618,font.FONT_SMALL or 7,c(226,188,93))
                text(short(Settings.boss_guide_status,72),430,646,font.FONT_SMALL or 7,c(240,245,250))
                text("F7 remains the dedicated compact-helper shortcut.",420,699,font.FONT_SMALL or 7,c(184,207,227))
            elseif R.page==7 then
                text("PALADIN SUPPORT",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Devotion Aura","auto_aura","Keep the party's armor aura active."},{"Cleanse Toxins","auto_cleanse","Remove confirmed Poison and Disease."},{"Blessing of Freedom","auto_freedom","Clear confirmed roots and slows."},{"Safe combat resurrection","auto_battle_rez","Resurrect an ally only while secure."},{"Emergency party support","party_support","Use free Word of Glory on a critical ally."},{"Blessing of Sacrifice","auto_sacrifice","Protect an ally while your defense is secure."},{"Delve survival healing","delve_survival","Protect yourself in Delve emergencies."},{"Emergency paid Word of Glory","emergency_paid_wog","Spend Holy Power only to survive."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
            elseif R.page==8 then
                text("AUTOMATION & GATHERING",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Auto loot","looting","Loot nearby corpses after combat."},{"Auto skin","skinning","Skin eligible corpses after looting."},{"Auto fishing","fishing","Cast, detect bites and collect catches."},{"Auto herbalism","herbing","Move to visible herbs and gather."},{"Auto mining","mining","Move to visible ore and gather."},{"Herb guide lines","draw_herbs","Draw green guidance to herbs."},{"Mining guide lines","draw_mining","Draw gold guidance to ore."},{"Auto repair","auto_repair","Repair at capable merchants."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],412,314+(i-1)*55,v[3],font.FONT_SMALL or 7) end
            elseif R.page==9 then
                text("CUSTOM HOTKEYS",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                toggle("Enable customer hotkeys","hotkeys_enabled",412,314,"Master switch for optional feature shortcuts.",font.FONT_SMALL or 7)
                rect(412,380,964,508,c(12,31,49,242),7)
                text("HOW TO ASSIGN",430,394,font.FONT_SMALL or 7,c(226,188,93))
                text("1. Open any feature tab.",430,424,font.FONT_SMALL or 7,c(240,245,250))
                text("2. Click its KEY button to cycle available keys.",430,450,font.FONT_SMALL or 7,c(240,245,250))
                text("3. The same key can belong to only one feature.",430,476,font.FONT_SMALL or 7,c(240,245,250))
                action("APPLY STARTER KEYS",412,536,676,578,Settings.apply_hotkey_preset,font.FONT_SMALL or 7)
                action("CLEAR ALL KEYS",690,536,964,578,Settings.clear_hotkeys,font.FONT_SMALL or 7)
                text("Reserved: F1 main GUI | F7 boss helper",420,608,font.FONT_SMALL or 7,c(184,207,227))
                text("Bindings save with the other plugin settings.",420,636,font.FONT_SMALL or 7,c(184,207,227))
            elseif R.page==10 then
                text("TANK TUNING",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                local rows={{"Threat scan range","threat_range",10,60,5},{"Prediction window (seconds)","prediction_window",1,4,1},{"Predicted Ardent HP %","prediction_ardent",10,90,5},{"Predicted Guardian HP %","prediction_guardian",5,75,5},{"Urgent Word of Glory HP %","word_of_glory_hp",10,95,5},{"Reactive Ardent HP %","ardent_hp",10,90,5},{"Reactive Guardian HP %","guardian_hp",10,80,5},{"Divine Shield HP % (0 disables)","bubble_hp",0,50,5},{"Lay on Hands HP % (0 disables)","lay_on_hands_hp",0,50,5}}
                for i,v in ipairs(rows) do number_control(v[1],v[2],412,314+(i-1)*47,v[3],v[4],v[5],font.FONT_SMALL or 7) end
            else
                text("SYSTEM & RECOVERY",412,288,font.FONT_SEMI_BIG or 1,c(226,188,93))
                toggle("Show Paladin Vanguard","custom_gui",412,314,"F1 always restores or hides this window.",font.FONT_SMALL or 7)
                toggle("Auto repair","auto_repair",412,369,"Repair at capable merchants automatically.",font.FONT_SMALL or 7)
                rect(412,438,964,562,c(12,31,49,242),7)
                text("PERSISTENT LOGGER",430,452,font.FONT_SMALL or 7,c(226,188,93))
                text(short(Settings.logging_status,65),430,480,font.FONT_SMALL or 7,c(240,245,250))
                text("Recovery: scripts_log/prot_paladin_mplus/recovered.log",430,518,font.FONT_SMALL or 7,c(184,207,227))
                action("EXPORT RECOVERED LOGS",412,590,650,632,Settings.actions.export_logs,font.FONT_SMALL or 7)
                action("RESET WINDOW POSITION",664,590,964,632,reset_position,font.FONT_SMALL or 7)
                text("Independent from BG Player; saved across reloads and crashes.",420,666,font.FONT_SMALL or 7,c(184,207,227))
            end
            rect(392,717,986,748,c(6,20,34,238),6);text("ICECROWN RAID: Hold the line • Protect the party • Lead the next pull",412,725,font.FONT_SMALL or 7,c(238,224,180))
            line(1,1,998,818,c(224,184,86),10,2)
        end)
    end)
    if not success and not R.reported then R.reported=true;if type(core.log_warning)=="function" then pcall(core.log_warning,"[Paladin Vanguard GUI] "..tostring(failure)) end end
    return success,failure
end
return M

