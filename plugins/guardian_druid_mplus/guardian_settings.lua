local M = {status="Ready", route_status="Ready", gathering_status="Ready", repair_status="Idle", bigwigs_status="Not loaded", cooldown_status="Ready", mode_status="World", log_status="Starting", actions={}}
local prefix = "guardian_druid_mplus_"
local ui = {root=core.menu.tree_node(),hotkeys=core.menu.tree_node()}
local checks = {
    {"themed_gui",false,"Open Emerald Dream window","Malfurion-themed Guardian controls; close from the window or this switch."},
    {"enabled",true,"Enable Guardian plugin","Master switch: combat, gathering and drawings."},
    {"low_lag",true,"Emergency combat performance","Use only the selected target and boss frames during combat; disables expensive off-target scans and world geometry."},
    {"combat",true,"Combat routine","Act only while already in combat."},
    {"manual_yield",true,"Yield to manual spells","Pause automated requests for 0.6 seconds after your own manual Guardian cast."},
    {"dummy_test",false,"Training dummy test mode","Run the full rotation only on a selected training dummy within 5 yards."},
    {"auto_bear",true,"Bear Form in combat","Return to Bear Form when combat begins."},
    {"cooldowns",true,"Offensive cooldowns","Use available Incarnation/Berserk, Lunar Beam and Red Moon."},
    {"defensives",true,"Automatic defensives","Ironfur, Frenzied Regeneration, Barkskin and Survival Instincts."},
    {"dream_heal",true,"Dream of Cenarius self-heal","Use Regrowth below the regeneration HP threshold only with a visible instant Bear Form proc."},
    {"dream_ally",true,"Dream of Cenarius party healing","Use an instant proc on a critically injured party member or before four stacks are wasted."},
    {"auto_mark",true,"Maintain Mark of the Wild","Apply Mark of the Wild while safely out of combat."},
    {"remove_corruption",true,"Party poison/curse dispel","Use Remove Corruption only on a confirmed Poison or Curse."},
    {"combat_rebirth",true,"Automatic combat Rebirth","Resurrect a dead party member when health and predicted danger make the cast safe."},
    {"prediction",true,"Predictive defense","Forecast incoming damage, targeted casts and pack pressure."},
    {"pre_regen",true,"Prepare regeneration before tank hits","Requires a verified BigWigs tank timer and Natural Resilience or Fount of Strength."},
    {"bigwigs_defensives",true,"BigWigs / LittleWigs defensives","Use emphasized addon timers to pre-cast a defensive."},
    {"spenders",true,"Offensive rage spenders","Preserve rage when Ironfur needs renewing."},
    {"interrupts",true,"Skull Bash interrupts","Interrupt the selected hostile target."},
    {"aoe_stop",true,"Emergency group stop","Use Incapacitating Roar or Typhoon when two nearby enemies cast together."},
    {"soothe",true,"Automatic Soothe","Remove a confirmed Enrage from an engaged enemy."},
    {"auto_face",true,"Automatic combat facing","Correct facing only when the client confirms the target is behind you."},
    {"threat_switch",true,"Threat target switching","Select the engaged enemy with the highest party-threat priority."},
    {"auto_taunt",true,"Threat check + auto Growl","Continuously taunt enemies attacking your party in groups and Mythic+. Does not pull neutral packs."},
    {"route_lock",false,"Lock current pull","Prevent automatic recovery to a later pull; Next and Previous still work."},
    {"route_map",true,"M+ auto dungeon","Automatically load the matching embedded route."},
    {"route_overview",true,"Route status panel","Show route source, pull and completed/planned/required forces."},
    {"draw_route_lines",true,"World route line","Point directly to the visible active pull. Green is verified; yellow is a partial match."},
    {"draw_next_pack",true,"Next pull aura rings","Highlight enemies assigned to the active pull."},
    {"draw_pull_labels",true,"Pull numbers","Label the active pack."},
    {"boss_guide",true,"Role-aware boss guide","Season 2 boss jobs, confirmed mechanics and BigWigs warnings."},
    {"boss_helper_gui",false,"Compact boss helper GUI","F7 shows it anytime. Boss detection opens it automatically; Hide suppresses only the current fight."},
    {"danger_zones",true,"Boss danger circles","Red inside a known circle; green outside that circle; blue for required soaks."},
    {"boss_lines",true,"Boss attack direction lines","Draw confirmed caster-to-target attack directions; these are not safe-path instructions."},
    {"looting",true,"Auto loot","Loot nearby corpses outside combat."},
    {"skinning",false,"Auto skin","Approach eligible corpses outside combat."},
    {"fishing",false,"Auto fish","Stand by water; fishing pauses other gathering."},
    {"auto_repair",true,"Auto repair","Repair damaged equipment when a repair merchant is open."},
    {"guild_repair",false,"Use guild repair funds","Use guild funds when permitted and available."},
    {"diagnostics",true,"Decision diagnostics","Show interrupt, target, utility and cooldown decisions."},
}
for _, row in ipairs(checks) do ui[row[1]]=core.menu.checkbox(row[2],prefix..row[1]) end
local sliders = {
    {"gui_scale",75,100,95,"Emerald Dream window scale %"},
    {"boss_warning_lead",1,10,5,"Boss warning lead time (seconds)"},
    {"danger_margin",0,3,1,"Danger circle safety buffer (yards)"},
    {"boss_overlay_x",0,2000,24,"Boss guide horizontal position"},
    {"boss_overlay_y",0,2000,390,"Boss guide vertical position"},
    {"regen_hp",10,95,60,"Frenzied Regeneration HP %"},
    {"barkskin_hp",10,95,75,"Barkskin HP %"},
    {"survival_hp",5,80,35,"Survival Instincts HP %"},
    {"ironfur_stacks",1,8,1,"Minimum Ironfur stacks"},
    {"rage_dump",60,100,80,"Offensive rage dump threshold"},
    {"threat_range",10,30,30,"Growl scan distance"},
    {"bigwigs_lead",1,5,2,"BigWigs defensive lead time (seconds)"},
    {"prediction_window",1,5,3,"Damage forecast window (seconds)"},
    {"prediction_regen",20,90,65,"Projected HP for Frenzied Regeneration"},
    {"prediction_survival",10,70,38,"Projected HP for Survival Instincts"},
    {"cooldown_min_enemies",1,10,3,"Enemies required for offensive cooldowns"},
    {"cooldown_ttd",5,60,15,"Minimum elite time-to-die for cooldowns"},
    {"interrupt_percent",30,90,65,"Ordinary cast interrupt percentage"},
    {"dream_ally_hp",10,90,45,"Dream Regrowth party HP %"},
    {"rebirth_min_hp",40,100,70,"Minimum HP % for combat Rebirth"},
}
for _,row in ipairs(sliders) do ui[row[1]]=core.menu.slider_int(row[2],row[3],row[4],prefix..row[1]) end
ui.hero=core.menu.combobox(1,prefix.."hero")
ui.previous=core.menu.button(prefix.."previous")
ui.next=core.menu.button(prefix.."next")
ui.reset=core.menu.button(prefix.."reset")
local hotkey_choices={{"F1",0x70},{"F2",0x71},{"F3",0x72},{"F4",0x73},{"F5",0x74},{"F6",0x75},{"F7",0x76},{"F8",0x77},{"F9",0x78},{"F10",0x79},{"F11",0x7A},{"F12",0x7B},{"NUM 0",0x60},{"NUM 1",0x61},{"NUM 2",0x62},{"NUM 3",0x63},{"NUM 4",0x64},{"NUM 5",0x65},{"NUM 6",0x66},{"NUM 7",0x67},{"NUM 8",0x68},{"NUM 9",0x69}}
local hotkey_labels={};for _,row in ipairs(hotkey_choices) do hotkey_labels[#hotkey_labels+1]=row[1] end
M.hotkeys={};M.hotkey_order={}
local function add_hotkey(key,label,kind,default_enabled,default_key)
    M.hotkeys[key]={label=label,kind=kind or "toggle",enabled=core.menu.checkbox(default_enabled==true,prefix.."hotkey_"..key.."_enabled"),key=core.menu.combobox(default_key or 1,prefix.."hotkey_"..key.."_key"),down=false}
    M.hotkey_order[#M.hotkey_order+1]=key
end
for _,row in ipairs(checks) do add_hotkey(row[1],row[3],"toggle",row[1]=="themed_gui",1) end
add_hotkey("previous","Previous dungeon pull","action");add_hotkey("next","Skip dungeon pull","action");add_hotkey("reset","Restart dungeon route","action")
function M.on(key) return ui[key] and ui[key]:get_state() or false end
function M.value(key) return ui[key] and ui[key]:get() or 0 end
function M.set(key,value)
    if not ui[key] then return end
    for _,row in ipairs(sliders) do if row[1]==key then value=math.max(row[2],math.min(row[3],math.floor(value))) end end
    if key=="hero" then value=math.max(1,math.min(3,value)) end
    ui[key]:set(value)
end
function M.describe(key)
    for _,row in ipairs(checks) do if row[1]==key then return {kind="check",label=row[3],note=row[4]} end end
    for _,row in ipairs(sliders) do if row[1]==key then return {kind="slider",label=row[5],note="Adjust with minus / plus"} end end
    return {kind="slider",label="Hero tree",note="Auto detect, Elune's Chosen, Druid of the Claw"}
end
function M.hotkey_enabled(key) local h=M.hotkeys[key];return h and h.enabled:get_state() or false end
function M.hotkey_name(key) local h=M.hotkeys[key];local i=h and tonumber(h.key:get()) or 1;return hotkey_choices[i] and hotkey_choices[i][1] or "F1" end
function M.set_hotkey_enabled(key,value) local h=M.hotkeys[key];if h then h.enabled:set(value==true) end end
function M.cycle_hotkey(key,delta)
    local h=M.hotkeys[key];if not h then return end
    local value=(tonumber(h.key:get()) or 1)+(delta or 1);if value<1 then value=#hotkey_choices elseif value>#hotkey_choices then value=1 end;h.key:set(value)
end
function M.poll_hotkeys()
    if not core.input or type(core.input.is_key_pressed)~="function" then return end
    for _,key in ipairs(M.hotkey_order) do
        local h=M.hotkeys[key]
        if h.enabled:get_state() then local i=tonumber(h.key:get()) or 1;local code=hotkey_choices[i] and hotkey_choices[i][2]
        local ok,down=pcall(core.input.is_key_pressed,code);down=ok and down==true
        if down and not h.down then
            if h.kind=="action" then if M.actions[key] then M.actions[key]() end
            elseif ui[key] and ui[key].get_state then ui[key]:set(not ui[key]:get_state()) end
        end
        h.down=down else h.down=false end
    end
end
function M.is_guardian()
    local ok,matched=pcall(function()
        local player=core.object_manager.get_local_player()
        return player and player:is_valid() and player:get_class()==11
            and core.spell_book.get_specialization_id()==3
    end)
    return ok and matched==true
end
function M.allowed()
    if not M.on("enabled") then return false end
    local instance=type(core.get_instance_type)=="function" and core.get_instance_type() or nil
    if type(instance)=="string" and instance:lower()=="arena" then return false end
    local p=core.object_manager.get_local_player()
    return p and p:is_valid() and not p:is_dead() and p:get_class()==11
        and core.spell_book.get_specialization_id()==3
end
function M.render()
    if not M.is_guardian() then return end
    ui.root:render("Guardian Druid Mythic+ 12.1",function()
        for _,row in ipairs(checks) do ui[row[1]]:render(row[3],row[4]) end
        ui.hero:render("Hero tree",{"Auto detect","Elune's Chosen","Druid of the Claw"})
        for _,row in ipairs(sliders) do ui[row[1]]:render(row[5]) end
        for _,name in ipairs({"previous","next","reset"}) do
            if ui[name]:render(name=="previous" and "Previous pull" or name=="next" and "Next / skip pull" or "Restart route") then
                if M.actions[name] then M.actions[name]() end
            end
        end
        ui.hotkeys:render("Hotkey customization",function()
            for _,key in ipairs(M.hotkey_order) do local h=M.hotkeys[key]
                h.enabled:render("Enable: "..h.label);h.key:render(h.label.." key",hotkey_labels)
            end
        end)
        core.menu.text("Combat: "..M.status)
        core.menu.text("PvE mode: "..M.mode_status)
        core.menu.text("Route: "..M.route_status)
        core.menu.text("Gathering: "..M.gathering_status)
        core.menu.text("Repair: "..M.repair_status)
        core.menu.text("BigWigs: "..M.bigwigs_status)
        core.menu.text("Boss guide: "..(M.boss_status or "Waiting for boss"))
        core.menu.text("Persistent log: "..M.log_status)
        if M.on("diagnostics") then
            local ok,combat=pcall(require,"guardian_combat")
            if ok then
                core.menu.text("Interrupt: "..combat.interrupt)
                core.menu.text("Target: "..combat.target_reason)
                core.menu.text("Utility: "..combat.utility)
                core.menu.text("Cooldowns: "..M.cooldown_status)
            end
        end
    end)
end
return M
