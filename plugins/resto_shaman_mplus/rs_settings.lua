local M = {status = "Ready", timer = "No timer", last = "None", link_status="Waiting for combat"}
local root = core.menu.tree_node()
local definitions = {
    {"enabled", "Enable routine", true},
    {"damage", "Damage during safe healing downtime", true},
    {"training_dummy", "City damage and healing dummy testing", true},
    {"dummy_damage", "Practice damage rotation on selected city dummies", true},
    {"dummy_healing", "Practice healing rotation on selected healing dummies", true},
    {"dummy_aoe", "Use Chain Lightning while testing on cleave dummies", false},
    {"damage_aoe", "Chain Lightning on engaged enemy packs", true},
    {"damage_hp", "Minimum party health for damage %", 95, 80, 100},
    {"damage_mana", "Reserve mana for healing %", 30, 0, 80},
    {"mana_management", "Context-aware mana management", true},
    {"mana_conserve", "Base mana conservation threshold %", 35, 20, 60},
    {"mana_critical", "Base critical mana threshold %", 15, 5, 30},
    {"cooldowns", "Automatic healing cooldowns", true},
    {"defensives", "Astral Shift", true},
    {"elemental", "Earth Elemental fallback (requires Primordial Bond)", true},
    {"link", "Automatic Spirit Link", true},
    {"link_hp", "Spirit Link group health % (3 clustered allies)", 55, 25, 80},
    {"bigwigs", "BigWigs integration", true},
    {"profiles", "Method dungeon damage profiles", true},
    {"prediction", "Incoming damage prediction", true},
    {"adaptive_velocity", "Observed health-loss prediction", true},
    {"anti_kick", "Hold non-emergency PvP hardcasts for confirmed kicks", true},
    {"dampening_logic", "Arena dampening-aware thresholds", true},
    {"overheal_cancel", "Cancel redundant Healing Wave casts", true},
    {"totemic_prediction", "Totemic predictive preparation", true},
    {"totemic_projection", "Reposition active healing totems with the group", true},
    {"dispels", "Automatic Purify Spirit", true},
    {"poison_cleansing", "Automatic Poison Cleansing Totem", true},
    {"resurrection", "Automatic out-of-combat Ancestral Spirit", true},
    {"interrupts", "Automatic Wind Shear on nearby enemy casts", true},
    {"pve_stun_interrupt", "Capacitor backup when PvE Wind Shear is unavailable", true},
    {"pvp_interrupt_at", "PvP Wind Shear cast progress %", 65, 20, 95},
    {"pvp_ground_cc_first", "Ground high-value CC before spending Wind Shear", true},
    {"pve_trinkets", "Use configured trinkets in PvE", true},
    {"pvp_trinkets", "Use configured trinkets in PvP", true},
    {"trinket_13_mode", "Upper trinket mode: 0 off, 1 heal, 2 defend, 3 friendly, 4 hostile, 5 ground, 6 PvP break", 1, 0, 6},
    {"trinket_14_mode", "Lower trinket mode: 0 off, 1 heal, 2 defend, 3 friendly, 4 hostile, 5 ground, 6 PvP break", 1, 0, 6},
    {"trinket_heal_hp", "Healing trinket health %", 70, 30, 95},
    {"trinket_defensive_hp", "Defensive trinket health %", 45, 15, 80},
    {"debug_log", "Detailed combat log for copy and paste", true},
    {"hotkeys", "Enable customer hotkeys", true},
    {"movement", "Spiritwalker's Grace while healing on the move", true},
    {"ghost_wolf", "Automatic Ghost Wolf during safe sustained movement", true},
    {"ghost_wolf_delay", "Ghost Wolf movement delay (seconds)", 2, 1, 4},
    {"avoidance", "Automatic M+ hazard escape (requires Sylvanas Evade)", true},
    {"danger_zones", "PvE danger-zone circles", true},
    {"danger_radius", "Danger-zone scan radius", 8, 4, 12},
    {"boss_guide", "Season 2 role-aware boss guide", true},
    {"boss_helper", "Compact auto-detected boss helper window", true},
    {"boss_arrows", "Boss positioning arrows and destination rings", true},
    {"boss_guide_lead", "Boss mechanic guide lead seconds", 6, 2, 10},
    {"arena_lines", "Arena partner lines (green visible / red line-of-sight lost)", true},
    {"preheal", "Pre-heal emphasized timers (no major cooldowns)", true},
    {"skinning", "Auto skinning (nearby corpses)", true},
    {"looting", "Auto loot (nearby corpses)", true},
    {"fishing", "Auto fishing (stand facing water)", false},
    {"fishing_recast", "Automatically recast after collecting a fish", true},
    {"gather_range", "Loot and skin interaction range", 3, 2, 5},
    {"emergency", "Emergency health %", 35, 10, 60},
    {"delve_emergency", "Delve emergency health %", 40, 10, 65},
    {"pvp_emergency", "PvP emergency health %", 45, 10, 70},
    {"pvp_burst", "PvP burst cooldown health %", 75, 40, 95},
    {"pvp_link", "PvP Spirit Link rescue health %", 40, 20, 60},
    {"pvp_damage", "Allow single-target damage during PvP downtime", false},
    {"pvp_damage_instant_only", "PvP damage: instant spells only", true},
    {"pvp_peel", "Automatic PvP peeling", true},
    {"pvp_cc", "Automatic safe-window Hex", true},
    {"pvp_counterstrike", "Counterstrike Totem against committed pressure", true},
    {"pvp_lasso", "Safe-window Lightning Lasso (advanced)", false},
    {"pvp_purge", "Safe-window Purge / Greater Purge", true},
    {"pve_purge", "Safe Mythic+ and delve enemy Purge", true},
    {"pvp_ancient_lore", "Counter enemy Ancient of Lore", true},
    {"pvp_peel_hp", "PvP peel when healer health is at or below %", 85, 50, 100},
    {"spot", "Urgent spot healing health %", 60, 35, 80},
    {"heal", "Direct healing health %", 90, 50, 99},
    {"group", "Group cooldown health % (3 allies)", 65, 30, 85},
    {"personal", "Astral Shift health %", 45, 15, 80},
    {"lead", "BigWigs lead seconds", 3, 1, 8},
    {"gui_scale", "GUI box size %", 115, 70, 132},
    {"font_scale", "Letters and numbers size %", 100, 85, 125},
}
local value_units={lead=" sec",boss_guide_lead=" sec",ghost_wolf_delay=" sec",gather_range=" yd",
    danger_radius=" yd",trinket_13_mode="",trinket_14_mode=""}
local function value_unit(key)
    if value_units[key]~=nil then return value_units[key] end
    local d=nil
    for _,row in ipairs(definitions) do if row[1]==key then d=row;break end end
    return d and type(d[3])=="number" and "%" or ""
end
M.controls = {}
local runtime_values={}
for _, d in ipairs(definitions) do
    M.controls[d[1]] = type(d[3]) == "boolean"
        and core.menu.checkbox(d[3], "rsm1_" .. d[1])
        or core.menu.slider_int(d[4], d[5], d[3], "rsm1_" .. d[1])
end
local hotkey_controls={}
local bindable_keys={}
for _,d in ipairs(definitions) do
    if type(d[3])=="boolean" and d[1]~="hotkeys" then
        bindable_keys[#bindable_keys+1]=d[1]
        hotkey_controls[d[1]]=core.menu.slider_int(0,254,0,"rsm1_hotkey_"..d[1])
    end
end
M.party_bars = core.menu.text_input("rsm1_party_bars", true)
M.self_bars = core.menu.text_input("rsm1_self_bars", true)
-- Keep window placement in native menu controls so it survives reloads without
-- adding two technical sliders to the visible Shaman settings pages.
M.window_x = core.menu.slider_int(0, 7680, 45, "rsm1_window_x")
M.window_y = core.menu.slider_int(0, 4320, 45, "rsm1_window_y")
-- This plugin owns a standalone F1 window. Retained Sylvanas pages are not
-- registered, so the controls remain separate from the host configuration UI.
local modern=false
local paths={}
local by_key={}
for _,d in ipairs(definitions) do by_key[d[1]]=d end
local function modern_value(key)
    local path=paths[key]
    if path then return _G.menu:get(path,key) end
end
local function add(section,key,description)
    local d=by_key[key]
    paths[key]=section._rsm_path
    if type(d[3])=="boolean" then
        section:checkbox(key,d[2],d[3],{description=description})
    else
        section:slider(key,d[2],d[4],d[5],d[3],value_unit(key),
            {integer=true,description=description})
    end
end
local function section(page,path,title,column)
    local s=page:section(title,nil,{column=column})
    s._rsm_path=path
    return s
end
if modern then
    local menu=_G.menu
    menu:category({"Resto Shaman"},{icon="widgets"})
    local overview_path="Resto Shaman/Overview"
    local overview=menu:page({"Resto Shaman","Overview"},{icon="widgets"})
    overview:title("RESTORATION SHAMAN  •  WATER, EARTH & SPIRIT")
    local core_section=section(overview,overview_path,"Core", "left")
    add(core_section,"enabled","Master switch for every rotation feature.")
    add(core_section,"prediction","Include supported incoming-damage estimates in healing decisions.")
    add(core_section,"adaptive_velocity","Use recent health-loss speed when queued-damage data is incomplete.")
    add(core_section,"cooldowns","Allow Healing Tide, Ascendance and other major healing cooldowns.")
    local survival=section(overview,overview_path,"Survival", "right")
    add(survival,"defensives","Use Astral Shift for verified personal danger or low health.")
    add(survival,"elemental","Use Earth Elemental as a Primordial Bond emergency fallback.")
    add(survival,"link","Allow automatic Spirit Link when redistribution is useful.")
    add(survival,"link_hp","Clustered group threshold for Spirit Link.")

    local pve_path="Resto Shaman/PvE Healing"
    local pve=menu:page({"Resto Shaman","PvE Healing"},{icon="widgets"})
    pve:title("TIDAL HEALING  •  DUNGEONS, DELVES & OPEN WORLD")
    local triage=section(pve,pve_path,"Healing thresholds","left")
    for _,k in ipairs({"emergency","spot","heal","group","personal","delve_emergency","overheal_cancel"}) do add(triage,k) end
    local damage=section(pve,pve_path,"Safe damage","right")
    for _,k in ipairs({"damage","training_dummy","dummy_damage","dummy_healing","dummy_aoe","damage_aoe","damage_hp","damage_mana"}) do add(damage,k) end

    local pvp_path="Resto Shaman/PvP Healing"
    local pvp=menu:page({"Resto Shaman","PvP Healing"},{icon="widgets"})
    pvp:title("ANCESTRAL DEFENSE  •  ARENA, BATTLEGROUNDS & WORLD PvP")
    local saves=section(pvp,pvp_path,"Pressure response","left")
    for _,k in ipairs({"pvp_emergency","pvp_burst","pvp_link"}) do add(saves,k) end
    local pvp_options=section(pvp,pvp_path,"PvP options","right")
    add(pvp_options,"pvp_damage","Permit damage only after the PvP healing scheduler is satisfied.")
    add(pvp_options,"pvp_damage_instant_only","Use Flame Shock and instant Lava Burst; disable to allow checked hardcast damage windows.")
    add(pvp_options,"arena_lines","Green partner lines have line of sight; red lines are blocked.")
    add(pvp_options,"anti_kick","Hold only non-emergency hardcasts when enemy kick readiness is positively confirmed.")
    add(pvp_options,"dampening_logic","Raise arena healing thresholds at high reported dampening.")

    local cc_path="Resto Shaman/Crowd Control"
    local cc=menu:page({"Resto Shaman","Crowd Control"},{icon="widgets"})
    cc:title("STORM CONTROL  •  ROOT, KNOCK, CONTAIN & HEX")
    local peeling=section(cc,cc_path,"Peeling","left")
    add(peeling,"pvp_peel","Use learned roots, knockbacks, containment and movement talents against melee pressure.")
    add(peeling,"pvp_peel_hp","Begin defensive peeling at this healer health.")
    add(peeling,"pvp_counterstrike","Use Counterstrike Totem when at least two enemies commit to a teammate.")
    local control=section(cc,cc_path,"Hex control","right")
    add(control,"pvp_cc","Hex only during verified safe healing windows with DR and target checks.")
    add(control,"pvp_lasso","Optional: channel Lasso only at full team health with DR, target and kick checks.")
    add(control,"pvp_purge","Remove visible enemy Magic buffs only while the team and mana are safe.")
    add(control,"interrupts","Use Wind Shear on interruptible nearby enemy casts.")
    add(control,"pvp_ground_cc_first","Use Grounding first on recognized targeted CC and preserve Wind Shear for the follow-up cast.")
    add(control,"pvp_interrupt_at","Choose how far a PvP cast progresses before Wind Shear is requested.")
    control:label("Priority: enemy healer, then an off-target melee attacker.")
    control:label("Healing, defensives and emergency saves always run first.")

    local dispel_path="Resto Shaman/Cures & Dispels"
    local dispel=menu:page({"Resto Shaman","Cures & Dispels"},{icon="widgets"})
    dispel:title("PURIFYING WATER  •  CURSES, MAGIC & POISONS")
    local direct=section(dispel,dispel_path,"Direct cleansing","left")
    add(direct,"dispels","Use Purify Spirit on visible Magic and Curse effects after emergency healing.")
    add(direct,"pve_purge","Remove visible enemy Magic buffs during safe dungeon and delve healing downtime.")
    local poison=section(dispel,dispel_path,"Poison response","right")
    add(poison,"poison_cleansing","Use the talented totem for multiple poisons or an injured PvE target.")
    poison:label("PvP dispel-protection effects are avoided unless the target is critical.")

    local dungeon_path="Resto Shaman/Dungeons & Movement"
    local dungeon=menu:page({"Resto Shaman","Dungeons & Movement"},{icon="widgets"})
    dungeon:title("FLOW WITH THE PARTY  •  TIMERS, PREPARATION & SAFE MOVEMENT")
    local timers=section(dungeon,dungeon_path,"BigWigs prediction","left")
    for _,k in ipairs({"bigwigs","profiles","preheal","lead"}) do add(timers,k) end
    paths.party_bars=dungeon_path;paths.self_bars=dungeon_path
    timers:text_input("party_bars","Party damage bar labels","",{placeholder="Exact labels separated by ;"})
    timers:text_input("self_bars","Personal damage bar labels","",{placeholder="Exact labels separated by ;"})
    local motion=section(dungeon,dungeon_path,"Movement","right")
    add(motion,"pve_stun_interrupt","Time Capacitor Totem to stop a nearby PvE cast only while Wind Shear is unavailable.")
    add(motion,"movement","Use Spiritwalker's Grace when movement would otherwise block urgent healing.")
    add(motion,"avoidance","Use short, checked Sylvanas Evade escapes during Mythic+ combat.")
    add(motion,"danger_zones","Show red registered hazards and a green safe-position ring during timed mechanics.")
    add(motion,"danger_radius","Choose how far around the player the overlay samples registered hazards.")
    add(motion,"boss_guide","Show healer responsibilities and stack, spread, soak or movement prompts for supported Season 2 bosses.")
    add(motion,"boss_helper","Show the separate class/spec-themed boss helper. Press F7 at any time to show or hide it.")
    add(motion,"boss_arrows","Draw advisory green arrows and destination rings from visible units and registered safe geometry.")
    add(motion,"boss_guide_lead","Choose how early BigWigs mechanics replace the general boss plan.")

    local gather_path="Resto Shaman/Gathering"
    local gather=menu:page({"Resto Shaman","Gathering"},{icon="widgets"})
    gather:title("CALM WATERS  •  OPTIONAL OUT-OF-COMBAT HELPERS")
    local harvest=section(gather,gather_path,"Loot and professions","full")
    for _,k in ipairs({"looting","skinning","fishing"}) do add(harvest,k) end

    local status=menu:page({"Resto Shaman","Live Status"},{icon="widgets"})
    status:title(function()return "STATE  •  "..M.status end)
    status:title(function()return "CONTENT  •  "..(M.content or "Detecting").."    PROFILE  •  "..(M.profile or "Detecting") end)
    status:title(function()return "BUILD  •  "..require("rs_talents").hero().."    LAST REQUEST  •  "..M.last end)
    status:title(function()return "BIGWIGS  •  "..M.timer end)
    status:title(function()return "SPIRIT LINK  •  "..M.link_status end)
    status:title(function()return "MOVEMENT  •  "..(M.evade_status or "Waiting for M+ combat") end)
    status:title(function()return "DELVE COMPANION  •  "..(M.companion or "Not in a delve") end)
    status:title(function()return "DISPELS  •  "..(M.dispel_status or "Scanning") end)
end
function M.get(k)
    if runtime_values[k]~=nil then return runtime_values[k] end
    if modern and paths[k] then return modern_value(k) end
    local c = M.controls[k]
    local d=by_key[k]
    if d and type(d[3])=="number" then return c:get() end
    return c:get_state()
end
function M.text(k)
    if modern and paths[k] then return modern_value(k) or "" end
    local input=k=="party_bars" and M.party_bars or M.self_bars
    return input:get_text()
end
function M.render()
    if modern then return end
    root:render("Resto Shaman M+", function()
        for _, d in ipairs(definitions) do M.controls[d[1]]:render(d[2]) end
        M.party_bars:render("Party damage bar labels (; separated)", "Exact BigWigs text. Only these timers permit proactive healing cooldowns.")
        M.self_bars:render("Personal damage bar labels (; separated)", "Exact labels of mechanics that definitely hit you. Enables proactive Astral Shift.")
        core.menu.text("State: " .. M.status)
        core.menu.text("Detected content: " .. (M.content or "Detecting"))
        core.menu.text("Healing profile: " .. (M.profile or "Detecting"))
        core.menu.text("Delve companion: " .. (M.companion or "Not in a delve"))
        core.menu.text("BigWigs: " .. M.timer)
        core.menu.text("Last request: " .. M.last)
        core.menu.text("Build: " .. require("rs_talents").hero())
        core.menu.text("Spirit Link: " .. M.link_status)
        core.menu.text("Avoidance: " .. (M.evade_status or "Waiting for M+ combat"))
        core.menu.text("Danger zones: " .. (M.danger_status or "Waiting for PvE combat"))
    end)
end

local overlay_open=true
local overlay_group=1
local overlay_item=1
local keys_down={}
local overlay_notice="Select a setting to adjust it"
local overlay_offset_x,overlay_offset_y=0,0
local overlay_drag=nil
local overlay_slider=nil
local binding_key=nil
local binding_started=-math.huge
local hotkey_map={}
local hotkey_map_at=-math.huge
local function runtime_time() return type(core.time)=="function" and core.time() or 0 end
local groups={
    {"CORE",{"enabled","prediction","adaptive_velocity","cooldowns","defensives","elemental","resurrection","training_dummy"}},
    {"HEALING",{"emergency","delve_emergency","spot","heal","group","personal","overheal_cancel","link","link_hp"}},
    {"MANA & DAMAGE",{"mana_management","mana_conserve","mana_critical","damage","training_dummy","dummy_damage","dummy_healing","dummy_aoe","damage_aoe","damage_hp","damage_mana"}},
    {"TOTEMS",{"totemic_prediction","totemic_projection","poison_cleansing","pvp_counterstrike","preheal","pve_stun_interrupt"}},
    {"PVE & DUNGEONS",{"bigwigs","profiles","lead","dispels","pve_purge","boss_guide","boss_helper","boss_guide_lead"}},
    {"PVP HEALING",{"pvp_emergency","pvp_burst","pvp_link","dampening_logic","anti_kick","arena_lines","pvp_damage","pvp_damage_instant_only"}},
    {"PVP CONTROL",{"pvp_peel","pvp_peel_hp","pvp_cc","pvp_lasso","pvp_purge","interrupts","pvp_interrupt_at","pvp_ground_cc_first","pvp_ancient_lore"}},
    {"MOVEMENT",{"movement","ghost_wolf","ghost_wolf_delay","avoidance","danger_zones","danger_radius","boss_arrows"}},
    {"ITEMS & UTILITY",{"pve_trinkets","pvp_trinkets","trinket_13_mode","trinket_14_mode","trinket_heal_hp","trinket_defensive_hp"}},
    {"GATHERING",{"looting","skinning","fishing","fishing_recast","gather_range"}},
    {"HOTKEYS",bindable_keys},
    {"DISPLAY & LOGS",{"gui_scale","font_scale","debug_log"}},
}
local group_help={
    CORE="Master behavior, prediction, recovery and survival.",
    HEALING="Emergency, direct-heal, group-heal and Spirit Link thresholds.",
    ["MANA & DAMAGE"]="Choose conservation floors and safe damage limits.",
    TOTEMS="Predictive placement, projection, cleansing and control totems.",
    ["PVE & DUNGEONS"]="BigWigs, dispels, boss guidance and dungeon behavior.",
    ["PVP HEALING"]="Arena, battleground and world-PvP healing response.",
    ["PVP CONTROL"]="Peels, Hex, interrupts, Purge and enemy counters.",
    MOVEMENT="Ghost Wolf, casting movement, hazards and position guidance.",
    ["ITEMS & UTILITY"]="PvE and PvP trinket behavior and thresholds.",
    GATHERING="Optional out-of-combat loot, skinning and fishing helpers.",
    HOTKEYS="Click a feature, then press the key that should toggle it.",
    ["DISPLAY & LOGS"]="Window size, text size, recording and copy tools.",
}
local function overlay_bounds()
    local scale=(M.get("gui_scale") or 100)/100
    local w,h=920*scale,650*scale
    local x,y=35,70
    if core.graphics and type(core.graphics.get_screen_size)=="function" then
        local ok,screen=pcall(core.graphics.get_screen_size)
        if ok and screen and type(screen.x)=="number" and type(screen.y)=="number" then
            local center_x=math.floor((screen.x-w)/2)
            local center_y=math.floor((screen.y-h)/2)
            x=math.max(10,math.min(screen.x-w-10,center_x+overlay_offset_x))
            y=math.max(10,math.min(screen.y-h-10,center_y+overlay_offset_y))
            return x,y,w,h,center_x,center_y,scale
        end
    end
    return x,y,w,h,x,y,scale
end
local function inside(cursor,x1,y1,x2,y2)
    return cursor and cursor.x>=x1 and cursor.x<=x2 and cursor.y>=y1 and cursor.y<=y2
end
local key_labels={
    [0x08]="BACKSPACE",[0x09]="TAB",[0x0D]="ENTER",[0x14]="CAPS LOCK",[0x1B]="ESC / CLEAR",
    [0x20]="SPACE",[0x21]="PAGE UP",[0x22]="PAGE DOWN",[0x23]="END",[0x24]="HOME",
    [0x25]="LEFT",[0x26]="UP",[0x27]="RIGHT",[0x28]="DOWN",[0x2D]="INSERT",[0x2E]="DELETE",
}
local function reserved_hotkey(code)
    return code<8 or code==0x10 or code==0x11 or code==0x12 or code==0x70 or code==0x76
end
function M.hotkey_name(code)
    code=tonumber(code) or 0
    if code<=0 then return "UNBOUND" end
    if key_labels[code] then return key_labels[code] end
    if code>=0x30 and code<=0x39 or code>=0x41 and code<=0x5A then return string.char(code) end
    if code>=0x60 and code<=0x69 then return "NUM "..tostring(code-0x60) end
    if code>=0x71 and code<=0x7B then return "F"..tostring(code-0x6F) end
    return "KEY "..tostring(code)
end
function M.hotkey_keys() return bindable_keys end
function M.hotkey_code(key)
    local control=hotkey_controls[key]
    return control and tonumber(control:get()) or 0
end
function M.set_hotkey(key,code)
    local control=hotkey_controls[key]
    code=math.floor(tonumber(code) or 0)
    if not control or code<0 or code>254 or code>0 and reserved_hotkey(code) then return false end
    if code>0 then
        for _,other in ipairs(bindable_keys) do
            if other~=key and M.hotkey_code(other)==code then hotkey_controls[other]:set(0) end
        end
    end
    control:set(code);hotkey_map_at=-math.huge
    overlay_notice=(by_key[key] and by_key[key][2] or key).." hotkey: "..M.hotkey_name(code)
    return M.hotkey_code(key)==code
end
function M.clear_hotkeys()
    for _,key in ipairs(bindable_keys) do hotkey_controls[key]:set(0) end
    binding_key=nil;hotkey_map_at=-math.huge;overlay_notice="All customer hotkeys cleared"
    return true
end
function M.begin_hotkey_capture(key)
    if not hotkey_controls[key] then return false end
    binding_key=key;binding_started=runtime_time();overlay_notice="Press a key for "..by_key[key][2].." • Escape clears"
    return true
end
function M.hotkey_binding() return binding_key end
local function rebuild_hotkeys()
    hotkey_map={}
    for _,key in ipairs(bindable_keys) do
        local code=M.hotkey_code(key)
        if code>0 and not reserved_hotkey(code) and not hotkey_map[code] then hotkey_map[code]=key end
    end
    hotkey_map_at=runtime_time()
end
function M.poll_window()
    if not core.input or type(core.input.is_key_pressed)~="function" then return end
    local function sample(code)
        local ok,pressed=pcall(core.input.is_key_pressed,code)
        pressed=ok and pressed==true
        local hit=pressed and not keys_down[code]
        keys_down[code]=pressed
        return hit
    end
    local hit={[0x70]=sample(0x70)}
    if hit[0x70] then
        overlay_open=not overlay_open
        overlay_drag=nil;overlay_slider=nil
    end
    if binding_key then
        if runtime_time()-binding_started<0.20 then return end
        for code=8,254 do
            if not reserved_hotkey(code) and sample(code) then
                if code==0x1B then M.set_hotkey(binding_key,0) else M.set_hotkey(binding_key,code) end
                binding_key=nil
                return
            end
        end
        return
    end
    if not M.get("hotkeys") or type(core.is_textbox_focused)=="function" and core.is_textbox_focused()==true then return end
    if runtime_time()-hotkey_map_at>=2 then rebuild_hotkeys() end
    for code,key in pairs(hotkey_map) do
        if sample(code) then
            M.set_setting(key,not M.get(key))
            overlay_notice=M.hotkey_name(code).." toggled "..by_key[key][2].." "..(M.get(key) and "ON" or "OFF")
        end
    end
end
function M.is_window_open() return overlay_open end

local native_nodes={}
for i=1,#groups do native_nodes[i]=core.menu.tree_node() end
local log_path_input=core.menu.text_input("rsm_log_path_copy",false)
local log_recent_input=core.menu.text_input("rsm_log_recent_copy",false)
local copy_path_button=type(core.menu.button)=="function" and core.menu.button() or nil
local copy_recent_button=type(core.menu.button)=="function" and core.menu.button() or nil
function M.group_count() return #groups end
function M.group_title(index) return groups[index] and groups[index][1] or "SETTINGS" end
function M.group_help(index) return group_help[M.group_title(index)] or "Customize this feature group." end
function M.group_keys(index) return groups[index] and groups[index][2] or groups[1][2] end
function M.is_hotkey_group(index) return groups[index] and groups[index][1]=="HOTKEYS" or false end
function M.definition(key) return by_key[key] end
function M.set_setting(key,value)
    local control=M.controls[key]
    local d=by_key[key]
    if not control or not d or type(control.set)~="function" then return false end
    if type(d[3])=="boolean" then value=value==true
    else value=math.max(d[4],math.min(d[5],math.floor(tonumber(value) or d[3]))) end
    runtime_values[key]=value
    control:set(value)
    overlay_notice=d[2]..": "..(type(value)=="boolean" and (value and "ON" or "OFF") or M.value_label(key,value))
    return M.get(key)==value
end
function M.value_label(key,value) return tostring(value)..value_unit(key) end
function M.notice() return overlay_notice end
function M.set_notice(value) overlay_notice=tostring(value or "") end
function M.window_position()
    return M.window_x:get(),M.window_y:get()
end
function M.set_window_position(x,y)
    x=math.max(0,math.min(7680,math.floor(tonumber(x) or 45)))
    y=math.max(0,math.min(4320,math.floor(tonumber(y) or 45)))
    M.window_x:set(x);M.window_y:set(y)
    return x,y
end
function M.reset_display()
    M.set_setting("gui_scale",115)
    M.set_setting("font_scale",100)
    M.set_window_position(45,45)
    overlay_notice="Display size and position reset"
    return 45,45
end
function M.render_native_page(index,window)
    local group=groups[index] or groups[1]
    for _,key in ipairs(group[2]) do
        local d=by_key[key]
        M.controls[key]:render(d[2],"")
    end
    if index==5 then
        M.party_bars:render("Party damage bar labels (; separated)","Exact BigWigs labels")
        M.self_bars:render("Personal damage bar labels (; separated)","Exact BigWigs labels")
    elseif index==7 then
        local telemetry=require("rs_telemetry")
        if type(log_path_input.set_buffer)=="function" then log_path_input:set_buffer(telemetry.path()) end
        log_path_input:render("Session log file — select and copy","Saved continuously while Detailed combat log is enabled")
        if copy_path_button and copy_path_button:render("COPY LOG PATH","") then
            if type(log_path_input.copy_to_clipboard)=="function" then log_path_input:copy_to_clipboard()
            elseif window and type(window.copy_to_clipboard)=="function" then window:copy_to_clipboard(telemetry.path()) end
        end
        if type(log_recent_input.set_buffer)=="function" then log_recent_input:set_buffer(telemetry.saved_history()) end
        log_recent_input:render("Saved history — survives logout, reload and crashes","Copy this and paste it into Codex")
        if copy_recent_button and copy_recent_button:render("COPY RECENT LOGS","") then
            if type(log_recent_input.copy_to_clipboard)=="function" then log_recent_input:copy_to_clipboard()
            elseif window and type(window.copy_to_clipboard)=="function" then window:copy_to_clipboard(telemetry.saved_history()) end
        end
        core.menu.text("The full session remains in: "..telemetry.path())
    end
end
function M.render_native()
    core.menu.text("RESTORATION SHAMAN  •  TIDAL COMMAND  •  v4.5.1")
    core.menu.text("F1 closes or opens this window. Drag the title bar to move; drag the corner to resize.")
    core.menu.text("State: "..M.status.."  |  Content: "..(M.content or "Detecting").."  |  Build: "..require("rs_talents").hero())
    core.menu.text("Last: "..M.last.."  |  BigWigs: "..M.timer)
    if type(core.menu.separator)=="function" then core.menu.separator() end
    for i,g in ipairs(groups) do
        native_nodes[i]:render(g[1],function()
            for _,key in ipairs(g[2]) do
                local d=by_key[key]
                M.controls[key]:render(d[2], "")
            end
            if i==5 then
                M.party_bars:render("Party damage bar labels (; separated)", "Exact BigWigs labels")
                M.self_bars:render("Personal damage bar labels (; separated)", "Exact BigWigs labels")
            end
        end)
    end
    core.menu.text("Spirit Link: "..M.link_status)
    core.menu.text("Dispels: "..(M.dispel_status or "Scanning").."  |  Movement: "..(M.evade_status or "Waiting"))
end
function M.render_overlay()
    if not overlay_open then return end
    pcall(function()
        local color=require("common/color")
        local vec2=require("common/geometry/vector_2")
        if not core.graphics or type(core.graphics.text_2d)~="function"
            or type(core.graphics.rect_2d)~="function" then return end
        local teal=color.new(49,211,202,255)
        local deep=color.new(3,12,24,255)
        local shadow=color.new(0,0,0,255)
        local header_bg=color.new(7,35,57,232)
        local card_bg=color.new(8,25,38,224)
        local row_bg=color.new(11,34,47,238)
        local water=color.new(151,244,239,255)
        local white=color.new(244,250,250,255)
        local muted=color.new(166,194,201,255)
        local green=color.new(105,239,156,255)
        local red=color.new(255,128,112,255)
        local earth=color.new(202,166,88,255)
        local air=color.new(140,194,255,255)
        local spirit=color.new(187,143,255,255)
        local fire=color.new(255,143,73,255)
        local accents={{151,244,239},{202,166,88},{187,143,255},{140,194,255},{49,211,202},{255,143,73},{151,244,239}}
        local x,y,w,h,_,_,scale=overlay_bounds()
        local font_scale=(M.get("font_scale") or 100)/100
        if type(core.graphics.rect_2d_filled)=="function" then
            core.graphics.rect_2d_filled(vec2.new(x+8*scale,y+9*scale),w,h,shadow,12)
            core.graphics.rect_2d_filled(vec2.new(x,y),w,h,deep,12)
            core.graphics.rect_2d_filled(vec2.new(x+3*scale,y+3*scale),w-6*scale,65*scale,header_bg,10)
            core.graphics.rect_2d_filled(vec2.new(x+18*scale,y+120*scale),w-36*scale,48*scale,card_bg,7)
            core.graphics.rect_2d_filled(vec2.new(x+18*scale,y+218*scale),w-36*scale,344*scale,card_bg,8)
            core.graphics.rect_2d_filled(vec2.new(x+18*scale,y+568*scale),w-36*scale,68*scale,card_bg,7)
        elseif type(core.graphics.line_2d)=="function" then
            for py=y+5,y+h-5,10 do core.graphics.line_2d(vec2.new(x+5,py),vec2.new(x+w-5,py),deep,11) end
        end
        core.graphics.rect_2d(vec2.new(x,y),w,h,teal,3,10)
        local function text(value,px,py,size,c)
            core.graphics.text_2d(tostring(value),vec2.new(px,py),math.max(9,math.floor(size*font_scale)),c or white,false)
        end
        local function px(n)return x+n*scale end
        local function py(n)return y+n*scale end
        text("RESTORATION SHAMAN",px(24),py(18),21,water)
        text("TIDAL COMMAND  •  v4.5.1  •  DRAG THIS HEADER TO MOVE",px(24),py(48),12,teal)
        if type(core.graphics.rect_2d_filled)=="function" then
            for i,c in ipairs({water,earth,air,fire}) do
                core.graphics.rect_2d_filled(vec2.new(px(570+(i-1)*24),py(25)),14*scale,14*scale,c,7)
            end
                core.graphics.rect_2d_filled(vec2.new(x+w-62*scale,py(12)),44*scale,40*scale,color.new(74,27,35,255),7)
        end
        text("X",x+w-48*scale,py(20),15,red)
        text("CLICK TABS AND SWITCHES     CLICK OR DRAG SLIDER BARS",px(24),py(78),11,white)
        text("Mouse only: click tabs and switches  •  click/drag sliders  •  drag header  •  click X to close",px(24),py(99),10,muted)
        text("State: "..M.status,px(24),py(130),13,white)
        text("Content: "..(M.content or "Detecting"),px(470),py(130),13,white)
        text("Profile: "..(M.profile or "Detecting"),px(24),py(153),12,water)
        text("Build: "..require("rs_talents").hero(),px(470),py(153),12,water)
        local tab_x=px(18)
        local tab_width=(w-36*scale)/#groups
        local cursor=type(core.get_cursor_position)=="function" and core.get_cursor_position() or nil
        for i,g in ipairs(groups) do
            local label=(i==overlay_group and "> "..g[1] or g[1])
            local hover=inside(cursor,tab_x,py(177),tab_x+tab_width-5*scale,py(215))
            if (hover or i==overlay_group) and type(core.graphics.rect_2d_filled)=="function" then
                local alpha=i==overlay_group and 255 or 220
                local c=accents[i]
                core.graphics.rect_2d_filled(vec2.new(tab_x-3*scale,py(178)),tab_width-4*scale,28*scale,color.new(c[1],c[2],c[3],alpha),4)
            end
            text(label,tab_x,py(190),9,(i==overlay_group or hover) and white or muted)
            tab_x=tab_x+tab_width
        end
        local active=groups[overlay_group]
        text(active[1],px(24),py(225),16,teal)
        local items=active[2]
        for i,key in ipairs(items) do
            local d=by_key[key]
            local value=M.get(key)
            local value_text
            local value_color=white
            if type(d[3])=="boolean" then
                value_text=value and "ON" or "OFF"
                value_color=value and green or red
            else
                value_text=M.value_label(key,value)
                value_color=water
            end
            local selected=i==overlay_item
            local row_y=py(258+(i-1)*32)
            local hover=inside(cursor,px(20),row_y-5*scale,x+w-20*scale,row_y+22*scale)
            if type(core.graphics.rect_2d_filled)=="function" then
                local bg=hover and color.new(20,73,82,255) or row_bg
                core.graphics.rect_2d_filled(vec2.new(px(20),row_y-5*scale),w-40*scale,27*scale,bg,4)
            end
            if selected then core.graphics.rect_2d(vec2.new(px(20),row_y-5*scale),w-40*scale,27*scale,water,2,4) end
            text((selected and ">  " or "   ")..d[2],px(30),row_y,12,selected and water or white)
            text(value_text,x+w-105*scale,row_y,12,value_color)
            if type(d[3])~="boolean" and type(core.graphics.line_2d)=="function" then
                local start_x=x+w-280*scale
                local ratio=(value-d[4])/math.max(1,d[5]-d[4])
                core.graphics.line_2d(vec2.new(start_x,row_y+8*scale),vec2.new(start_x+170*scale,row_y+8*scale),muted,6*scale)
                core.graphics.line_2d(vec2.new(start_x,row_y+8*scale),vec2.new(start_x+170*scale*ratio,row_y+8*scale),teal,7*scale)
            end
        end
        if overlay_group==5 then
            text("BigWigs custom label text remains available in the standard Sylvanas menu.",px(28),py(562),10,muted)
        end
        text("SAVED: "..overlay_notice,px(24),py(575),11,green)
        text("LIVE  •  Last: "..M.last.."  |  BigWigs: "..M.timer,px(24),py(602),11,white)
        text("Spirit Link: "..M.link_status.."  |  Dispels: "..(M.dispel_status or "Scanning"),px(24),py(623),11,white)
    end)
end
return M
