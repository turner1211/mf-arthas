local M = { status = "Starting", route_status = "Idle", gathering_status = "Idle",
    maintenance_status = "Idle", logging_status = "Starting", danger_status="Idle", boss_guide_status="Idle", actions = {} }
M.telemetry={mode="STARTING",health=100,holy_power=0,sotr_active=false,
    sotr_remaining=0,consecration=false,risk="IDLE",projected_pct=100}
local color = require("common/color")
local enums = require("common/enums")
local Host = require("prot_host")
-- Optional customer hotkeys. Index zero means unbound. F1 is reserved for the
-- main window and F7 for the compact boss helper, so neither is assignable.
local hotkey_catalog={
    {"NONE",0},{"F2",0x71},{"F3",0x72},{"F4",0x73},{"F5",0x74},{"F6",0x75},
    {"F8",0x77},{"F9",0x78},{"F10",0x79},{"F11",0x7A},{"F12",0x7B},
    {"NUM 0",0x60},{"NUM 1",0x61},{"NUM 2",0x62},{"NUM 3",0x63},{"NUM 4",0x64},
    {"NUM 5",0x65},{"NUM 6",0x66},{"NUM 7",0x67},{"NUM 8",0x68},{"NUM 9",0x69},
    {"INSERT",0x2D},{"DELETE",0x2E},{"HOME",0x24},{"END",0x23},{"PAGE UP",0x21},{"PAGE DOWN",0x22},
}
local hotkey_targets={
    "enabled","cooldowns","interrupts","stun_backup","aoe_stop","auto_taunt","threat_switch",
    "auto_combat_target","auto_face","training_dummy","manual_input_yield","prepull","auto_aura",
    "auto_cleanse","auto_battle_rez","party_support","auto_sacrifice","auto_freedom","delve_survival",
    "emergency_paid_wog","prediction","boss_timers","danger_zones","boss_guides",
    "boss_helper_auto","route_map","route_overview","draw_route_lines","draw_next_pack","draw_pull_labels",
    "fishing","looting","skinning","herbing","mining","draw_herbs","draw_mining","auto_repair",
}
local ui = {
    root = core.menu.tree_node(),
    custom_gui = core.menu.checkbox(true, "prot_paladin_mplus_custom_gui"),
    hotkeys_enabled = core.menu.checkbox(true, "prot_paladin_mplus_hotkeys_enabled"),
    enabled = core.menu.checkbox(true, "prot_paladin_mplus_enabled"),
    cooldowns = core.menu.checkbox(true, "prot_paladin_mplus_cooldowns"),
    interrupts = core.menu.checkbox(true, "prot_paladin_mplus_interrupts"),
    stun_backup = core.menu.checkbox(true, "prot_paladin_mplus_stun_backup"),
    aoe_stop = core.menu.checkbox(true, "prot_paladin_mplus_aoe_stop"),
    auto_taunt = core.menu.checkbox(true, "prot_paladin_mplus_auto_taunt"),
    threat_switch = core.menu.checkbox(true, "prot_paladin_mplus_threat_switch"),
    auto_combat_target = core.menu.checkbox(true, "prot_paladin_mplus_auto_combat_target"),
    auto_face = core.menu.checkbox(true, "prot_paladin_mplus_auto_face"),
    training_dummy = core.menu.checkbox(true, "prot_paladin_mplus_training_dummy"),
    manual_input_yield = core.menu.checkbox(true, "prot_paladin_mplus_manual_input_yield"),
    threat_range = core.menu.slider_int(10, 60, 40, "prot_paladin_mplus_threat_range"),
    auto_aura = core.menu.checkbox(true, "prot_paladin_mplus_auto_aura"),
    auto_cleanse = core.menu.checkbox(true, "prot_paladin_mplus_auto_cleanse"),
    auto_battle_rez = core.menu.checkbox(true, "prot_paladin_mplus_auto_battle_rez"),
    party_support = core.menu.checkbox(true, "prot_paladin_mplus_party_support"),
    auto_sacrifice = core.menu.checkbox(true, "prot_paladin_mplus_auto_sacrifice"),
    auto_freedom = core.menu.checkbox(true, "prot_paladin_mplus_auto_freedom"),
    delve_survival = core.menu.checkbox(true, "prot_paladin_mplus_delve_survival"),
    emergency_paid_wog = core.menu.checkbox(true, "prot_paladin_mplus_emergency_paid_wog"),
    prediction = core.menu.checkbox(true, "prot_paladin_mplus_prediction"),
    prepull = core.menu.checkbox(true, "prot_paladin_mplus_prepull"),
    boss_timers = core.menu.checkbox(true, "prot_paladin_mplus_boss_timers"),
    danger_zones = core.menu.checkbox(true, "prot_paladin_mplus_danger_zones"),
    boss_guides = core.menu.checkbox(true, "prot_paladin_mplus_boss_guides"),
    boss_helper_gui = core.menu.checkbox(true, "prot_paladin_mplus_boss_helper_gui"),
    boss_helper_auto = core.menu.checkbox(true, "prot_paladin_mplus_boss_helper_auto"),
    prediction_window = core.menu.slider_int(1, 4, 2, "prot_paladin_mplus_prediction_window"),
    prediction_ardent = core.menu.slider_int(10, 90, 70, "prot_paladin_mplus_prediction_ardent"),
    prediction_guardian = core.menu.slider_int(5, 75, 45, "prot_paladin_mplus_prediction_guardian"),
    route_map = core.menu.checkbox(true, "prot_paladin_mplus_route_map"),
    route_overview = core.menu.checkbox(false, "prot_paladin_mplus_route_overview"),
    draw_route_lines = core.menu.checkbox(true, "prot_paladin_mplus_route_lines"),
    draw_next_pack = core.menu.checkbox(true, "prot_paladin_mplus_next_pack"),
    draw_pull_labels = core.menu.checkbox(true, "prot_paladin_mplus_pull_labels"),
    previous_route = core.menu.button("prot_paladin_mplus_previous_route"),
    next_route = core.menu.button("prot_paladin_mplus_next_route"),
    reset_route = core.menu.button("prot_paladin_mplus_reset_route"),
    export_logs = core.menu.button("prot_paladin_mplus_export_logs"),
    fishing = core.menu.checkbox(false, "prot_paladin_mplus_fishing"),
    looting = core.menu.checkbox(true, "prot_paladin_mplus_looting"),
    skinning = core.menu.checkbox(false, "prot_paladin_mplus_skinning"),
    herbing = core.menu.checkbox(false, "prot_paladin_mplus_herbing"),
    mining = core.menu.checkbox(false, "prot_paladin_mplus_mining"),
    draw_herbs = core.menu.checkbox(true, "prot_paladin_mplus_draw_herbs"),
    draw_mining = core.menu.checkbox(true, "prot_paladin_mplus_draw_mining"),
    auto_repair = core.menu.checkbox(true, "prot_paladin_mplus_auto_repair"),
    word_of_glory_hp = core.menu.slider_int(10, 95, 55, "prot_paladin_mplus_wog_hp"),
    ardent_hp = core.menu.slider_int(10, 90, 55, "prot_paladin_mplus_ardent_hp_v2"),
    guardian_hp = core.menu.slider_int(10, 80, 35, "prot_paladin_mplus_guardian_hp_v2"),
    bubble_hp = core.menu.slider_int(0, 50, 0, "prot_paladin_mplus_bubble_hp_v2"),
    lay_on_hands_hp = core.menu.slider_int(0, 50, 20, "prot_paladin_mplus_lay_on_hands_hp"),
}
for _,key in ipairs(hotkey_targets) do
    ui["hotkey_"..key]=core.menu.slider_int(0,#hotkey_catalog-1,0,"prot_paladin_mplus_hotkey_"..key)
end
local aliases = {
    custom_gui="custom_gui",
    hotkeys_enabled="hotkeys_enabled",
    enabled="enabled", cooldowns="cooldowns", interrupts="interrupts", prediction="prediction", prepull="prepull",
    aoe_stop="aoe_stop",
    boss_timers="boss_timers",
    danger_zones="danger_zones",
    boss_guides="boss_guides",
    boss_helper_gui="boss_helper_gui",
    boss_helper_auto="boss_helper_auto",
    auto_taunt="auto_taunt", threat_switch="threat_switch", auto_combat_target="auto_combat_target", auto_face="auto_face",
    training_dummy="training_dummy",
    manual_input_yield="manual_input_yield",
    auto_cleanse="auto_cleanse", auto_battle_rez="auto_battle_rez", party_support="party_support",
    auto_sacrifice="auto_sacrifice",
    auto_freedom="auto_freedom", delve_survival="delve_survival",
    emergency_paid_wog="emergency_paid_wog",
    route_map="route_map", route_overview="route_overview",
    draw_route_lines="draw_route_lines", draw_next_pack="draw_next_pack",
    draw_pull_labels="draw_pull_labels", fishing="fishing", looting="looting",
    skinning="skinning", herbing="herbing", mining="mining",
    draw_herbs="draw_herbs", draw_mining="draw_mining", auto_repair="auto_repair",
}
function M.is_protection_paladin()
    local player=Host.manager("get_local_player")
    if not player or type(player.is_valid)~="function" or type(player.get_class)~="function" then return false end
    local valid_ok,valid=pcall(player.is_valid,player)
    if not valid_ok or valid~=true then return false end
    local class_ok,class_id=pcall(player.get_class,player)
    if not class_ok or class_id~=(enums.class_id and enums.class_id.PALADIN or 2) then return false end
    local raw=Host.static(core and core.spell_book,"get_specialization_id")
    if not raw or raw==0 then return false end
    local expected=enums.class_spec_id and enums.class_spec_id.spec_enum
        and enums.class_spec_id.spec_enum.PROTECTION_PALADIN or 66
    if enums.class_spec_id and type(enums.class_spec_id.get_specialization_enum)=="function" then
        local converted_ok,converted=pcall(enums.class_spec_id.get_specialization_enum,class_id,raw)
        if converted_ok and converted then raw=converted end
    end
    return raw==expected or raw==66
end
function M.on(key)
    if not M.is_protection_paladin() then return false end
    local widget = ui[aliases[key] or key]
    if not widget or type(widget.get_state)~="function" then return false end
    local ok,value=pcall(widget.get_state,widget)
    return ok and value==true
end
function M.global_on(key)
    local widget=ui[aliases[key] or key]
    if not widget or type(widget.get_state)~="function" then return false end
    local ok,value=pcall(widget.get_state,widget)
    return ok and value==true
end
function M.global_toggle(key)
    local widget=ui[aliases[key] or key]
    if not widget or type(widget.get_state)~="function" or type(widget.set)~="function" then return false end
    local ok,current=pcall(widget.get_state,widget);if not ok then return false end
    return pcall(widget.set,widget,current~=true)
end
function M.global_set(key,value)
    local widget=ui[aliases[key] or key]
    return widget and type(widget.set)=="function" and pcall(widget.set,widget,value) or false
end
function M.value(key)
    local widget = ui[key]
    if not widget or type(widget.get)~="function" then return 0 end
    local ok,value=pcall(widget.get,widget)
    return ok and tonumber(value) or 0
end
function M.set(key, value)
    local widget = ui[aliases[key] or key]
    if not widget or type(widget.set) ~= "function" then return false end
    local ok = pcall(widget.set, widget, value)
    return ok
end
function M.set_value(key,value)
    local widget=ui[key]
    if not widget or type(widget.set)~="function" then return false end
    local ok=pcall(widget.set,widget,tonumber(value) or 0)
    return ok
end
function M.toggle(key) return M.set(key, not M.on(key)) end
local hotkey_down,active_hotkeys={},nil
local function refresh_hotkeys()
    active_hotkeys={}
    for _,key in ipairs(hotkey_targets) do
        local index=M.value("hotkey_"..key);local entry=hotkey_catalog[index+1]
        if index>0 and entry then active_hotkeys[key]=entry[2] end
    end
end
function M.hotkey_name(key)
    if key=="custom_gui" then return "F1" end
    if key=="boss_helper_gui" then return "F7" end
    if key=="hotkeys_enabled" then return "MASTER" end
    local index=M.value("hotkey_"..key)
    return hotkey_catalog[index+1] and hotkey_catalog[index+1][1] or "NONE"
end
function M.set_hotkey(key,index)
    index=math.max(0,math.min(#hotkey_catalog-1,math.floor(tonumber(index) or 0)))
    if index>0 then
        -- A key belongs to one feature. Assigning it here removes any older
        -- assignment and prevents one press from changing several systems.
        for _,other in ipairs(hotkey_targets) do
            if other~=key and M.value("hotkey_"..other)==index then M.set_value("hotkey_"..other,0) end
        end
    end
    local changed=M.set_value("hotkey_"..key,index);refresh_hotkeys();return changed
end
function M.cycle_hotkey(key)
    if key=="custom_gui" or key=="boss_helper_gui" or key=="hotkeys_enabled" then return false end
    return M.set_hotkey(key,(M.value("hotkey_"..key)+1)%#hotkey_catalog)
end
function M.clear_hotkeys()
    for _,key in ipairs(hotkey_targets) do M.set_value("hotkey_"..key,0) end;refresh_hotkeys()
end
function M.apply_hotkey_preset()
    local preset={enabled=1,cooldowns=2,prediction=3,auto_taunt=4,route_map=5,
        danger_zones=6,boss_guides=7,interrupts=8,looting=9,auto_repair=10}
    M.clear_hotkeys();for key,index in pairs(preset) do M.set_hotkey(key,index) end
end
function M.poll_hotkeys()
    if not M.is_protection_paladin() or not M.global_on("hotkeys_enabled")
        or not core.input or type(core.input.is_key_pressed)~="function" then return end
    if not active_hotkeys then refresh_hotkeys() end
    for key,key_code in pairs(active_hotkeys) do
        local down=Host.static(core.input,"is_key_pressed",key_code)==true
        if down and not hotkey_down[key] then M.global_toggle(key) end
        hotkey_down[key]=down
    end
end
function M.render()
    if not M.is_protection_paladin() then return end
    ui.root:render("Protection Paladin Mythic+ 12.1", function()
        core.menu.text("PROTECTION PALADIN • MYTHIC+")
        ui.custom_gui:render("Show Paladin Vanguard panel", "Open the themed PvE tank control panel. Press F1 to show or hide it in game.")
        ui.hotkeys_enabled:render("Enable customer hotkeys", "Allow optional saved feature hotkeys configured in Paladin Vanguard. F1 and F7 remain reserved.")
        ui.enabled:render("Enable rotation", "Master combat toggle.")
        ui.cooldowns:render("Use major cooldowns", "Use Sentinel/Avenging Wrath, Divine Toll, and hero-tree cooldowns.")
        ui.interrupts:render("Auto interrupt", "Scan engaged casters for usable Rebuke or Avenger's Shield interrupts, including when your selected target dies.")
        ui.stun_backup:render("Hammer of Justice backup", "Stun interruptible casts when Rebuke is unavailable.")
        ui.aoe_stop:render("Blinding Light area stop", "Stop overlapping nearby casts after direct interrupts are unavailable.")
        ui.auto_taunt:render("Maintain party threat", "Scan engaged enemies and taunt mobs you are not tanking.")
        ui.threat_switch:render("Switch targets for threat", "Target a loose enemy when taunt is unavailable so the rotation can recover aggro.")
        ui.auto_combat_target:render("Safe combat target selection", "Replace dead, invalid, or unengaged targets with an enemy already fighting you, your party, or a Delve companion.")
        ui.auto_face:render("Automatic tank facing", "Correct facing only when the client confirms your selected engaged target is behind you.")
        ui.training_dummy:render("Training dummy mode", "Recognize city training dummies as safe combat targets, run the damage rotation, and suppress encounter-only utility and emergency cooldowns.")
        ui.manual_input_yield:render("Yield to manual spells", "Pause automated requests for 0.6 seconds after a confirmed player cast that did not originate from the plugin.")
        ui.prepull:render("Prepare the next pull", "Build Holy Power safely before a ready pack and pre-arm Divine Protection once for a severe nearby pull.")
        ui.threat_range:render("Threat scan range", "Scan this many yards for enemies already fighting your party.")
        ui.auto_aura:render("Auto Devotion Aura", "Keep Devotion Aura active when available.")
        ui.auto_cleanse:render("Auto Cleanse Toxins", "Remove confirmed Poison and Disease effects from yourself, then the healer and party.")
        ui.auto_battle_rez:render("Safe healer combat resurrection", "Use Intercession on a dead healer or party member only while your own health and active mitigation are secure.")
        ui.party_support:render("Emergency party support", "Spend a free Shining Light Word of Glory on a critically injured party member or attacked Delve companion while your own forecast is safe.")
        ui.auto_sacrifice:render("Safe Blessing of Sacrifice", "Protect a critically injured ally only while your own health, forecast, and Shield of the Righteous coverage are secure.")
        ui.auto_freedom:render("Auto Blessing of Freedom", "Clear confirmed roots and slows from yourself, then the healer and party.")
        ui.delve_survival:render("Delve survival healing", "Use a paid Word of Glory at critical health in a Delve only when Shield of the Righteous is secure.")
        ui.emergency_paid_wog:render("Emergency paid Word of Glory", "Spend Holy Power on a critical self-heal when armor is secure and emergency cooldowns are unavailable.")
        core.menu.text("M+ Auto Dungeon • " .. tostring(M.route_status))
        ui.route_map:render("M+ Auto Dungeon", "Auto-detect the dungeon and infer its embedded pull guide from visible enemies.")
        ui.draw_route_lines:render("Draw next-pull line", "Draw a direct guidance line to the next identified pull.")
        ui.draw_next_pack:render("Highlight next pull", "Draw an aura ring around the next pack and its enemies.")
        ui.draw_pull_labels:render("Draw pull labels", "Label visible pull packs in the world.")
        if ui.previous_route:render("Previous route pull") and M.actions.previous_route_pull then M.actions.previous_route_pull() end
        if ui.next_route:render("Next / skip route pull") and M.actions.next_route_pull then M.actions.next_route_pull() end
        if ui.reset_route:render("Reset route progress") and M.actions.reset_route then M.actions.reset_route() end
        core.menu.text("Persistent logs • " .. tostring(M.logging_status))
        core.menu.text("Copy-ready path • scripts_log/prot_paladin_mplus/recovered.log")
        if ui.export_logs:render("Export recovered logs") and M.actions.export_logs then M.actions.export_logs() end
        core.menu.text("Automation • " .. tostring(M.gathering_status))
        ui.looting:render("Auto loot", "Loot nearby corpses out of combat.")
        ui.skinning:render("Auto skin", "Move to and skin eligible corpses out of combat.")
        ui.fishing:render("Auto fishing", "Cast, detect bites, and loot catches.")
        ui.herbing:render("Auto herbalism", "Move to and gather nearby visible herb nodes.")
        ui.mining:render("Auto mining", "Move to and gather nearby visible ore nodes.")
        ui.draw_herbs:render("Draw lines to herbs", "Draw green lines and rings to recognized herb nodes within 100 yards.")
        ui.draw_mining:render("Draw lines to mining nodes", "Draw yellow lines and rings to recognized ore nodes within 100 yards.")
        ui.auto_repair:render("Auto repair", "Repair at repair-capable merchants, trying guild funds before personal gold.")
        core.menu.text("Maintenance • " .. tostring(M.maintenance_status))
        core.menu.text("Defensives")
        ui.prediction:render("Predict incoming damage", "Evaluate incoming damage, sustained health loss, hostile casts/channels, and known dungeon mechanics.")
        ui.boss_timers:render("Use boss-addon timers", "Merge BigWigs, LittleWigs, and ExBoss/EXWIND bars into defensive prediction without double-counting matching mechanics.")
        ui.danger_zones:render("Boss danger-zone auras", "During PvE combat, draw confirmed unsafe Evade positions red and show a green player ring after you move clear. Boss-addon timers control the warning window.")
        core.menu.text("Danger zones • "..tostring(M.danger_status))
        ui.boss_guides:render("Role-aware Season 2 boss guide", "Detect your assigned role and show mechanic-specific tank jobs, world rings, guidance lines, interrupts, defensives, movement, positioning, adds, and priority targets for every Season 2 dungeon boss.")
        ui.boss_helper_gui:render("Compact dungeon boss helper", "Show a small class-, specialization-, and role-themed boss mechanic window. Press F7 to show or hide it.")
        ui.boss_helper_auto:render("Auto-show helper for boss fights", "Open the compact helper automatically when combat begins with a detected boss frame.")
        core.menu.text("Boss guide • "..tostring(M.boss_guide_status))
        ui.prediction_window:render("Prediction window", "Seconds of incoming damage to evaluate.")
        ui.prediction_ardent:render("Predicted Ardent HP %", "Pre-cast Ardent Defender when projected health reaches this value.")
        ui.prediction_guardian:render("Predicted Guardian HP %", "Pre-cast Guardian of Ancient Kings for severe projected damage.")
        ui.word_of_glory_hp:render("Urgent Word of Glory HP %", "Prioritize a free Shining Light heal below this health. Additional free heals and Blessed Word absorbs follow the rotation.")
        ui.ardent_hp:render("Ardent Defender HP %", "Use at or below this health.")
        ui.guardian_hp:render("Guardian of Ancient Kings HP %", "Use at or below this health.")
        ui.bubble_hp:render("Divine Shield HP %", "Emergency immunity; requires Final Stand and all enemies you are tanking within its 15-yard taunt range. Set to 0 to disable.")
        ui.lay_on_hands_hp:render("Lay on Hands HP %", "Emergency self-heal at or below this health; set to 0 to disable.")
        core.menu.text("Status • " .. tostring(M.status))
    end)
end
return M

