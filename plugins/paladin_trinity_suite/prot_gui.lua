-- Paladin Vanguard: an optional themed control surface. The standard menu
-- remains available so a texture or window API failure can never hide settings.
local M={}
local Host=require("prot_host")
local R={page=1,x=45,y=45,w=1180,h=760,visible=true,was_f1=false,reported=false,
    dragging=nil,mouse_was_down=false}
local Settings,Routes,Logger,color,vec2,enums,window
local saved_x,saved_y
local art_texture,art_attempted,icon_art=nil,false,nil
local icon_textures,icon_attempted={},{}
local pages={"DASHBOARD","PLAYER","ROTATION","DEFENSE","DUNGEONS","MYTHIC+",
    "RAID","DELVES","AUTOMATION","HOTKEYS","TUNING","SUPPORT","ACCESS","SYSTEM"}
local icons={
    "dashboard","player","rotation","defense","dungeons","mythic",
    "raid","delves","automation","hotkeys","tuning","player","hotkeys","system",
}
local themes={
    {226,188,93,"COMMAND DASHBOARD","Live Protection Paladin readiness"},
    {102,174,236,"PLAYER","Targeting, movement and manual control"},
    {242,196,88,"ROTATION","Damage priorities and cooldown policy"},
    {230,104,82,"DEFENSE","Prediction, mitigation and recovery"},
    {105,190,225,"DUNGEONS","Boss guidance and party control"},
    {172,125,235,"MYTHIC+","Route planning, pulls and enemy forces"},
    {222,87,94,"RAID","Boss timers, mechanics and group support"},
    {226,153,73,"DELVES","Companion-aware solo survival"},
    {102,194,133,"AUTOMATION","Gathering, loot and maintenance"},
    {92,196,220,"HOTKEYS","Saved customer shortcuts"},
    {232,205,132,"TUNING","Tank thresholds and response windows"},
    {105,216,163,"SUPPORT","Blessings, cleanses and party assistance"},
    {112,190,226,"ACCESSIBILITY","Windows, input ownership and visual guidance"},
    {151,171,190,"SYSTEM","Window, logging and recovery"},
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
    local theme=themes[R.page] or themes[1];local accent=c(theme[1],theme[2],theme[3],245)
    rect(x1,y1,x2,y2,active and accent or over and c(52,82,112,245) or c(12,29,46,238),5)
    line(x1,y1,x2,y2,active and c(255,239,188) or c(88,119,146),5,1)
    local tx=x1+10
    if icon and draw_icon(icon,x1+5,y1+4,math.min(29,y2-y1-8)) then tx=x1+40 end
    text(label,tx,y1+9,font or 7,active and c(31,27,18) or c(238,244,250))
    if hit(x1,y1,x2,y2) and fn then fn() end
end
local function nav_button(label,icon,index,y,font)
    local x1,x2,y2=24,250,y+35
    local active=R.page==index
    local over=hover(x1,y,x2,y2)
    local theme=themes[index] or themes[1]
    local accent=c(theme[1],theme[2],theme[3],245)
    rect(x1,y,x2,y2,active and c(21,45,62,250) or over and c(27,53,72,245) or c(10,28,43,238),6)
    line(x1,y,x2,y2,active and accent or c(73,105,130,210),6,active and 2 or 1)
    if active then rect(x1,y+4,x1+5,y2-4,accent,2) end
    draw_icon(icon,x1+10,y+4,27)
    text(label,x1+48,y+9,font or 7,active and c(255,235,172) or c(230,238,245))
    if active then text(">",x2-21,y+8,font or 7,accent) end
    if hit(x1,y,x2,y2) then R.page=index end
end
local function toggle(label,key,x,y,note,font)
    local value=Settings.on(key);local x2=1145;local theme=themes[R.page] or themes[1]
    rect(x,y,x2,y+48,hover(x,y,x2,y+48) and c(25,51,76,238) or c(10,27,44,232),6)
    local category=(key=="route_map" or key=="route_overview" or key=="draw_route_lines" or key=="draw_next_pack" or key=="draw_pull_labels") and "mythic"
        or (key=="looting" or key=="skinning" or key=="fishing" or key=="herbing" or key=="mining" or key=="draw_herbs" or key=="draw_mining" or key=="auto_repair") and "automation"
        or (key=="prediction" or key=="boss_timers" or key=="danger_zones" or key=="boss_guides" or key=="auto_taunt" or key=="threat_switch" or key=="interrupts" or key=="emergency_paid_wog" or key=="party_support") and "defense" or "rotation"
    draw_icon(category,x+7,y+7,34)
    text(label,x+50,y+7,font or 7,c(248,241,215))
    text(short(note,58),x+50,y+27,font or 7,c(174,198,219))
    local key_x1=x2-176
    rect(key_x1,y+11,x2-80,y+37,c(21,44,65),6)
    line(key_x1,y+11,x2-80,y+37,c(88,121,150),6,1)
    text("KEY: "..Settings.hotkey_name(key),key_x1+8,y+16,font or 7,c(202,219,233))
    rect(x2-70,y+11,x2-13,y+37,value and c(theme[1],theme[2],theme[3]) or c(74,87,101),6)
    text(value and "ON" or "OFF",x2-54,y+16,font or 7,value and c(28,23,12) or c(235,239,242))
    if hit(key_x1,y+8,x2-76,y+40) then Settings.cycle_hotkey(key)
    elseif hit(x,y,x2,y+48) then Settings.toggle(key) end
end
local function action(label,x1,y1,x2,y2,fn,font) button(label,x1,y1,x2,y2,false,fn,font) end
local function status_card(label,value,x,y,value_color,font,width)
    width=width or 130
    rect(x,y,x+width,y+64,c(11,31,49,242),6);line(x,y,x+width,y+64,c(84,116,145),6,1)
    text(label,x+10,y+8,font or 7,c(158,186,208))
    text(value,x+10,y+31,font or 7,value_color or c(245,239,214))
end
local function number_control(label,key,x,y,minimum,maximum,step,font)
    local value=Settings.value(key);local x2=1145
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
function M.hide()
    R.visible=false
    if window then window:set_visibility(false) end
end
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
            local theme=themes[R.page] or themes[1]
            local accent=c(theme[1],theme[2],theme[3])
            -- Wide command header and left navigation follow the customer-facing
            -- suite layout while retaining the Paladin's Icecrown artwork.
            rect(274,8,1167,101,c(4,16,28,238),9);line(274,8,1167,101,c(224,184,86),9,2)
            text("PALADIN VANGUARD",302,20,font.FONT_BIG or 8,c(255,240,190))
            text("PROTECTION PALADIN SUITE  |  v6.14.0",303,53,font.FONT_SMALL or 7,c(224,193,116))
            text("F1 WINDOW  |  F7 BOSS HELPER  |  CLICK A KEY BOX TO ASSIGN",303,76,font.FONT_SMALL or 7,c(202,219,233))
            rect(902,24,1148,62,c(13,35,48,244),8);line(902,24,1148,62,accent,8,1)
            text(Settings.on("enabled") and "PROFILE ACTIVE" or "PROFILE PAUSED",930,35,font.FONT_SMALL or 7,
                Settings.on("enabled") and c(147,235,151) or c(241,139,117))
            button(Settings.on("enabled") and "ROTATION ON" or "ROTATION OFF",902,66,1148,94,
                Settings.on("enabled"),function() Settings.toggle("enabled") end,font.FONT_SMALL or 7)

            rect(14,110,260,712,c(3,15,25,242),9);line(14,110,260,712,c(91,126,160),9,1)
            for i,label in ipairs(pages) do
                local y=120+(i-1)*40
                nav_button(label,icons[i],i,y,font.FONT_SMALL or 7)
            end
            text("LIGHT GUIDES",78,691,font.FONT_SMALL or 7,c(224,193,116))

            rect(274,110,1167,712,c(3,15,26,240),9);line(274,110,1167,712,accent,9,2)
            text(theme[4],300,128,font.FONT_SEMI_BIG or 1,accent)
            text(theme[5],300,157,font.FONT_SMALL or 7,c(187,207,224))
            line(296,178,1145,178,c(theme[1],theme[2],theme[3],150),3,1)
            if R.page==1 then
                local route=Routes and Routes.get_state and Routes.get_state() or {}
                local hud=Settings.telemetry or {}
                status_card("HOLY POWER",tostring(hud.holy_power or 0).." / 5",300,194,
                    (hud.holy_power or 0)>=3 and c(229,190,88) or c(196,216,233),font.FONT_SMALL or 7,198)
                status_card("SOTR ARMOR",hud.sotr_active and string.format("%.1fs",hud.sotr_remaining or 0) or "DOWN",510,194,
                    hud.sotr_active and c(126,224,151) or c(244,105,105),font.FONT_SMALL or 7,198)
                status_card("CONSECRATION",hud.consecration and "ACTIVE" or "OUT",720,194,
                    hud.consecration and c(126,224,151) or c(244,174,90),font.FONT_SMALL or 7,198)
                local risk=tostring(hud.risk or "IDLE")
                status_card("INCOMING RISK",risk,930,194,
                    (risk=="LETHAL" or risk=="SEVERE") and c(255,92,92)
                        or risk=="HIGH" and c(255,165,76) or c(126,224,151),font.FONT_SMALL or 7,215)
                rect(300,270,1145,330,c(12,31,49,242),7)
                text("ACTIVE ROUTE",318,281,font.FONT_SMALL or 7,accent)
                text("Combat: "..short(Settings.status,38),690,281,font.FONT_SMALL or 7,c(202,219,233))
                text(short(route.route_name or Settings.route_status,75),318,307,font.FONT_SMALL or 7,c(241,246,250))
                text("Pull "..tostring(route.pull_index or "-").." | Forces "..tostring(route.completed_forces or "--").."/"..tostring(route.required_forces or "--"),930,307,font.FONT_SMALL or 7,c(190,213,233))
                toggle("Master rotation","enabled",300,346,"Start or pause automated combat decisions.",font.FONT_SMALL or 7)
                toggle("Predict incoming damage","prediction",300,401,"Pre-cast defensives from damage and boss timers.",font.FONT_SMALL or 7)
                toggle("Maintain party threat","auto_taunt",300,456,"Recover enemies attacking party members.",font.FONT_SMALL or 7)
                toggle("M+ Auto Dungeon","route_map",300,511,"Detect the dungeon and load its pull plan.",font.FONT_SMALL or 7)
                toggle("Role-aware boss guide","boss_guides",300,566,"Show your mechanic job, position and movement.",font.FONT_SMALL or 7)
            elseif R.page==2 then
                local rows={{"Safe target selection","auto_combat_target","Acquire only enemies engaged with your group."},{"Automatic tank facing","auto_face","Face an engaged target only when required."},{"Yield to manual spells","manual_input_yield","Briefly give your own input priority."},{"Training dummy mode","training_dummy","Practice in every major city without encounter utility."},{"Devotion Aura","auto_aura","Restore the Protection party aura safely."},{"Blessing of Freedom","auto_freedom","Clear confirmed movement impairments."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==3 then
                local rows={{"Master rotation","enabled","Start or pause all combat decisions."},{"Use major cooldowns","cooldowns","Use wings, Divine Toll and hero cooldowns."},{"Prepare next pull","prepull","Build resources and pre-arm safe mitigation."},{"Training dummy mode","training_dummy","Run the damage rotation on recognized dummies."},{"Yield to manual spells","manual_input_yield","Pause offense briefly after your manual cast."},{"Safe combat targeting","auto_combat_target","Replace dead or unengaged selections safely."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==4 then
                local rows={{"Predictive defense","prediction","Forecast casts, timers, health trends and absorbs."},{"Boss-addon timers","boss_timers","Read BigWigs, LittleWigs, ExBoss and DBM."},{"Danger-zone auras","danger_zones","Show confirmed hazards and a safe position."},{"Use major cooldowns","cooldowns","Permit automatic survival cooldowns."},{"Emergency paid Word of Glory","emergency_paid_wog","Heal critically behind secure armor."},{"Blessing of Sacrifice","auto_sacrifice","Protect an ally only while your tank state is safe."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
                text("Fine tune every health threshold on the TUNING page.",310,558,font.FONT_SMALL or 7,c(184,207,227))
            elseif R.page==5 then
                local rows={{"Role-aware boss guide","boss_guides","Show mechanic-specific tank positioning and actions."},{"Compact boss helper","boss_helper_gui","Keep the small encounter window available."},{"Auto-show boss helper","boss_helper_auto","Open the helper when a boss fight begins."},{"Boss-addon timers","boss_timers","Time defensives and upcoming instructions."},{"Danger-zone auras","danger_zones","Draw light encounter hazard guidance."},{"Direct interrupts","interrupts","Use ranked Rebuke and Avenger's Shield control."},{"Area stops","aoe_stop","Stop overlapping dangerous casts."},{"Safe combat resurrection","auto_battle_rez","Recover an ally only while mitigation is secure."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==6 then
                toggle("M+ Auto Dungeon","route_map",300,194,"Auto-detect the dungeon and embedded route.",font.FONT_SMALL or 7)
                toggle("Route overview","route_overview",300,249,"Show the compact route overview when available.",font.FONT_SMALL or 7)
                toggle("Draw next-pull line","draw_route_lines",300,304,"Guide toward the next verified pull anchor.",font.FONT_SMALL or 7)
                toggle("Highlight next pack","draw_next_pack",300,359,"Draw a transparent aura around the active pack.",font.FONT_SMALL or 7)
                toggle("Pull labels","draw_pull_labels",300,414,"Label nearby planned packs without screen clutter.",font.FONT_SMALL or 7)
                toggle("Maintain party threat","auto_taunt",300,469,"Recover every loose enemy threatening the party.",font.FONT_SMALL or 7)
                action("PREVIOUS",300,542,500,584,Settings.actions.previous_route_pull,font.FONT_SMALL or 7)
                action("SKIP / NEXT",510,542,750,584,Settings.actions.next_route_pull,font.FONT_SMALL or 7)
                action("RESET ROUTE",760,542,1000,584,Settings.actions.reset_route,font.FONT_SMALL or 7)
                text(short(Settings.route_status,100),304,616,font.FONT_SMALL or 7,c(190,213,233))
            elseif R.page==7 then
                local rows={{"Predictive defense","prediction","Forecast raid damage and tank events."},{"Boss-addon timers","boss_timers","Read active boss timers without double counting."},{"Role-aware boss guide","boss_guides","Show current tank job and positioning."},{"Danger-zone auras","danger_zones","Mark confirmed boss danger and safe movement."},{"Emergency party support","party_support","Use free healing when your own forecast is safe."},{"Blessing of Sacrifice","auto_sacrifice","Protect a critical ally behind secure mitigation."},{"Safe combat resurrection","auto_battle_rez","Resurrect when the tank state allows it."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==8 then
                local rows={{"Delve survival healing","delve_survival","Use emergency healing behind secure armor."},{"Maintain companion threat","auto_taunt","Recover enemies attacking your Delve companion."},{"Emergency party support","party_support","Support the companion while your forecast is safe."},{"Predictive defense","prediction","Forecast incoming Delve damage."},{"Danger-zone auras","danger_zones","Show confirmed boss hazards."},{"Role-aware boss guide","boss_guides","Display Delve boss jobs and movement."},{"Automatic tank facing","auto_face","Correct facing against an engaged enemy."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==9 then
                local rows={{"Auto loot","looting","Loot nearby corpses after combat."},{"Auto skin","skinning","Skin eligible corpses after looting."},{"Auto fishing","fishing","Cast, detect bites and collect catches."},{"Auto herbalism","herbing","Move to visible herb nodes and gather."},{"Auto mining","mining","Move to visible ore nodes and gather."},{"Herb guide lines","draw_herbs","Draw green guidance to herbs."},{"Mining guide lines","draw_mining","Draw gold guidance to ore."},{"Auto repair","auto_repair","Repair at capable merchants."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==10 then
                toggle("Enable customer hotkeys","hotkeys_enabled",300,194,"Master switch for all optional feature shortcuts.",font.FONT_SMALL or 7)
                rect(300,258,1145,390,c(12,31,49,242),7);line(300,258,1145,390,accent,7,1)
                text("ASSIGNMENT",320,274,font.FONT_SMALL or 7,accent)
                text("Open a feature page and click its KEY box to cycle available shortcuts.",320,307,font.FONT_SMALL or 7,c(240,245,250))
                text("Each key belongs to one feature; assigning it automatically clears the old owner.",320,335,font.FONT_SMALL or 7,c(240,245,250))
                text("F1 is reserved for this window. F7 is reserved for the compact boss helper.",320,363,font.FONT_SMALL or 7,c(184,207,227))
                action("APPLY STARTER KEYS",300,420,650,466,Settings.apply_hotkey_preset,font.FONT_SMALL or 7)
                action("CLEAR ALL KEYS",670,420,1020,466,Settings.clear_hotkeys,font.FONT_SMALL or 7)
                text("Only assigned keys are polled, preserving frame-time performance.",310,500,font.FONT_SMALL or 7,c(184,207,227))
            elseif R.page==11 then
                local rows={{"Threat scan range","threat_range",10,60,5},{"Prediction window (seconds)","prediction_window",1,4,1},{"Predicted Ardent HP %","prediction_ardent",10,90,5},{"Predicted Guardian HP %","prediction_guardian",5,75,5},{"Urgent Word of Glory HP %","word_of_glory_hp",10,95,5},{"Reactive Ardent HP %","ardent_hp",10,90,5},{"Reactive Guardian HP %","guardian_hp",10,80,5},{"Divine Shield HP % (0 disables)","bubble_hp",0,50,5},{"Lay on Hands HP % (0 disables)","lay_on_hands_hp",0,50,5}}
                for i,v in ipairs(rows) do number_control(v[1],v[2],300,194+(i-1)*49,v[3],v[4],v[5],font.FONT_SMALL or 7) end
            elseif R.page==12 then
                local rows={{"Emergency party healing","party_support","Use free healing when your tank forecast is secure."},{"Blessing of Sacrifice","auto_sacrifice","Protect critical allies without risking the tank."},{"Blessing of Freedom","auto_freedom","Clear confirmed movement impairments."},{"Automatic cleanse","auto_cleanse","Remove eligible poison and disease effects."},{"Safe combat resurrection","auto_battle_rez","Recover an ally only behind stable mitigation."},{"Devotion Aura","auto_aura","Maintain the Protection party aura safely."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            elseif R.page==13 then
                local rows={{"Show Paladin Vanguard","custom_gui","F1 restores or hides the main window."},{"Enable customer hotkeys","hotkeys_enabled","Master control for optional feature shortcuts."},{"Yield to manual spells","manual_input_yield","Give customer input priority after a manual cast."},{"Automatic tank facing","auto_face","Correct facing only against an engaged target."},{"Danger-zone guidance","danger_zones","Use transparent encounter movement cues."},{"Compact boss helper","boss_helper_gui","F7 restores or hides the encounter helper."}}
                for i,v in ipairs(rows) do toggle(v[1],v[2],300,194+(i-1)*58,v[3],font.FONT_SMALL or 7) end
            else
                toggle("Show Paladin Vanguard","custom_gui",300,194,"F1 always restores or hides this window.",font.FONT_SMALL or 7)
                toggle("Enable customer hotkeys","hotkeys_enabled",300,249,"Enable saved feature shortcuts.",font.FONT_SMALL or 7)
                toggle("Auto repair","auto_repair",300,304,"Repair at capable merchants automatically.",font.FONT_SMALL or 7)
                rect(300,378,1145,494,c(12,31,49,242),7);line(300,378,1145,494,accent,7,1)
                text("PERSISTENT LOGGER",320,392,font.FONT_SMALL or 7,accent)
                text(short(Settings.logging_status,90),320,423,font.FONT_SMALL or 7,c(240,245,250))
                text("Recovery: scripts_log/prot_paladin_mplus/recovered.log",320,457,font.FONT_SMALL or 7,c(184,207,227))
                action("EXPORT RECOVERED LOGS",300,526,650,570,Settings.actions.export_logs,font.FONT_SMALL or 7)
                action("RESET WINDOW POSITION",670,526,1020,570,reset_position,font.FONT_SMALL or 7)
                text("Independent logger; saved across reloads, logout and crashes.",310,606,font.FONT_SMALL or 7,c(184,207,227))
            end
            rect(274,719,1167,750,c(5,18,31,242),6)
            text("LIGHT BEFORE US  |  SHIELD BESIDE US  |  NO ALLY LEFT BEHIND",466,728,font.FONT_SMALL or 7,c(238,224,180))
            line(1,1,1178,758,c(224,184,86),10,2)
        end)
    end)
    if not success and not R.reported then R.reported=true;if type(core.log_warning)=="function" then pcall(core.log_warning,"[Paladin Vanguard GUI] "..tostring(failure)) end end
    return success,failure
end
return M
