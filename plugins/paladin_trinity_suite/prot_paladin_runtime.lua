local Settings = require("prot_settings")
local Aura = require("prot_aura")
local Routes = require("prot_routes")
local Gathering = require("prot_gathering")
local Prediction = require("prot_prediction")
local Threat = require("prot_threat")
local Maintenance = require("prot_maintenance")
local Intelligence = require("prot_intelligence")
local Mechanics = require("prot_mechanics")
local Utility = require("prot_utility")
local Logger = require("prot_logger")
local Gui = require("prot_gui")
local Danger = require("prot_danger")
local BossHelperGui = require("prot_boss_helper_gui")
local Host = require("prot_host")
local enums = require("common/enums")

local S = {
    devotion_aura=465, avengers_shield=31935, judgment=275779,
    blessed_hammer=204019, hammer_righteous=53595,
    shield_righteous=53600, consecration=26573, word_glory=85673,
    shield_righteous_buff=132403, consecration_buff=188370, shining_light=327510,
    divine_purpose=408458, divine_purpose_legacy=223819,
    ardent_defender=31850, guardian_kings=86659, divine_shield=642,
    divine_protection=403876, lay_hands=633, forbearance=25771,
    sentinel=389539, avenging_wrath=31884, divine_toll=375576,
    hammer_light=427453, hammer_light_ready=427441,
    shake_heavens=431533, divine_guidance=433106,
    sacred_weapon=432472, sacred_weapon_buff=432502,
    holy_bulwark=432459, holy_armaments=1289890, holy_armaments_talent=1289728,
    blessed_assurance=433019,
    vanguard=1268810, valor=1269179, vanguard_final=1267215,
    blessed_word=1301732, final_stand=204077,
    rebuke=96231, hammer_justice=853, blinding_light=115750,
    hand_reckoning=62124,
    cleanse_toxins=213644, intercession=391054,
    blessing_freedom=1044,
    blessing_sacrifice=6940,
}
-- Keep mutable engine state and small helpers under one local. Sylvanas uses a
-- Lua runtime with a 200-local limit per function/chunk, so adding independent
-- top-level locals here can prevent the entire plugin from compiling silently.
local Runtime={attempts={},last_action=-math.huge,last_defensive=-math.huge,
    retry_until={},failure_streak={},pending_cast={},interrupt_failed_until={},
    target_retry_until={},target_failure_streak={},manual_yield_until=-math.huge,
    callback_error_until={}}
Runtime.dungeon=require("prot_dungeon")
-- Stable NPC IDs let training mode work on localized clients. This covers the
-- shared classic-capital set and the dedicated city sets introduced through
-- Draenor, Legion, Boralus/Dazar'alor, Oribos, Valdrakken, Dornogal and the
-- Midnight Silvermoon hub. Friendly healing dummies remain harmless because
-- dummy mode also requires player:can_attack(selected).
Runtime.training_dummy_ids={
    [1921]=true,[4952]=true,[5652]=true,[17059]=true,[17060]=true,[17578]=true,
    [18504]=true,[25225]=true,[25297]=true,[30527]=true,[31144]=true,[31146]=true,
    [32541]=true,[32542]=true,[32543]=true,[32545]=true,[32546]=true,[32547]=true,
    [32666]=true,[32667]=true,[33229]=true,[42328]=true,[44171]=true,[44389]=true,
    [44548]=true,[44614]=true,[44703]=true,[44794]=true,[44820]=true,[44848]=true,
    [44937]=true,[46647]=true,[48304]=true,[60197]=true,[64446]=true,[67127]=true,
    [70245]=true,[79414]=true,[87317]=true,[87318]=true,[87320]=true,[87322]=true,
    [87329]=true,[87760]=true,[87761]=true,[87762]=true,[88288]=true,[88314]=true,
    [88836]=true,[88837]=true,[88906]=true,[89078]=true,[92164]=true,[92165]=true,
    [92166]=true,[92168]=true,[92169]=true,[93828]=true,[97668]=true,[98581]=true,
    [107104]=true,[108420]=true,[109066]=true,[109096]=true,[111824]=true,
    [113858]=true,[113859]=true,[113860]=true,[113862]=true,[113863]=true,
    [113864]=true,[113871]=true,[113964]=true,[113966]=true,[114832]=true,
    [114840]=true,[126712]=true,[126781]=true,[127019]=true,[131983]=true,
    [131989]=true,[131990]=true,[131992]=true,[132976]=true,[134324]=true,
    [138048]=true,[143119]=true,[143509]=true,[144073]=true,[144077]=true,
    [144081]=true,[144085]=true,[144086]=true,[153285]=true,[153292]=true,
    [172452]=true,[173942]=true,[174565]=true,[174566]=true,[174567]=true,
    [174568]=true,[175449]=true,[175450]=true,[175451]=true,[189082]=true,
    [193394]=true,[193563]=true,[194643]=true,[194644]=true,[194648]=true,
    [194649]=true,[197833]=true,[197834]=true,[198594]=true,[199057]=true,
    [216458]=true,[219250]=true,[219251]=true,[222275]=true,[225976]=true,
    [225977]=true,[225979]=true,[225982]=true,[225983]=true,[225984]=true,
    [225985]=true,[235830]=true,[243166]=true,[243167]=true,[243205]=true,
    [243207]=true,[243208]=true,[243211]=true,[243212]=true,[243214]=true,
}
function Runtime.is_training_dummy(unit)
    if not Settings.on("training_dummy") or not unit then return false end
    if type(unit.get_npc_id)=="function" then
        local ok,id=pcall(unit.get_npc_id,unit)
        if ok and Runtime.training_dummy_ids[tonumber(id)] then return true end
    end
    if type(unit.get_name)~="function" then return false end
    local ok,name=pcall(unit.get_name,unit);if not ok then return false end
    name=string.lower(tostring(name or ""))
    return name:find("training dummy",1,true)~=nil
        or name:find("tanking dummy",1,true)~=nil
        or name:find("target dummy",1,true)~=nil
        or name:find("practice dummy",1,true)~=nil
        or name:find("combat dummy",1,true)~=nil
        or name:find("drill dummy",1,true)~=nil
        or name:find("tank dummy",1,true)~=nil
        or name:find("sparring dummy",1,true)~=nil
        or name=="reinforced target" or name=="reinforced golem"
        or name=="kelpfist" or name=="crystalmaw"
end
function Runtime.cast_key(id,target)
    return tostring(id)..":"..tostring(Aura.guid(target) or target or "none")
end
function Runtime.local_player()
    return Runtime.manager("get_local_player")
end
function Runtime.manager(method)
    local manager=core and core.object_manager
    local fn=manager and manager[method]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,manager)
    if ok then return value end
    ok,value=pcall(fn)
    return ok and value or nil
end
function Runtime.objects()
    if Runtime.object_snapshot_ready then
        return type(Runtime.object_snapshot)=="table" and Runtime.object_snapshot or {}
    end
    local value=Runtime.manager("get_all_objects")
    return type(value)=="table" and value or {}
end
function Runtime.boss_frames()
    local value=Runtime.manager("get_boss_frames")
    return type(value)=="table" and value or {}
end
function Runtime.reachable(player,unit)
    if not core.graphics or type(core.graphics.is_line_of_sight)~="function" then return true end
    return Host.static(core and core.graphics,"is_line_of_sight",player,unit)~=false
end
function Runtime.report_callback_error(scope,err)
    local now=type(core.time)=="function" and select(2,pcall(core.time)) or 0
    now=tonumber(now) or 0
    if now<(Runtime.callback_error_until[scope] or -math.huge) then return end
    Runtime.callback_error_until[scope]=now+10
    if Settings.is_protection_paladin() then Logger.error(scope,err) end
end
function Runtime.reset_transient()
    Runtime.attempts={};Runtime.retry_until={};Runtime.failure_streak={};Runtime.pending_cast={}
    Runtime.interrupt_failed_until={};Runtime.target_retry_until={};Runtime.target_failure_streak={}
    Runtime.last_action=-math.huge;Runtime.last_defensive=-math.huge
    Runtime.manual_yield_until=-math.huge;Runtime.prepared_pull_key=nil;Runtime.last_face=nil
end
function Runtime.hammer_of_light_now(proc_active,proc_remaining,shake_active,shake_remaining)
    if not proc_active then return false end
    if not shake_active then return true end
    if not proc_remaining or proc_remaining<=4 then return true end
    return not shake_remaining or shake_remaining<=6
end
local function valid(unit)
    if not unit or type(unit.is_valid)~="function" then return false end
    local valid_ok,is_valid=pcall(unit.is_valid,unit)
    if not valid_ok or is_valid~=true then return false end
    if type(unit.is_dead)~="function" then return true end
    local dead_ok,is_dead=pcall(unit.is_dead,unit)
    return dead_ok and is_dead~=true
end
local function known(id)
    if not core.spell_book or type(core.spell_book.is_spell_known)~="function" then return false end
    return Host.static(core and core.spell_book,"is_spell_known",id)==true
end
local function resolve(id)
    if core.spell_book.get_override_spell_id then
        local value=Host.static(core and core.spell_book,"get_override_spell_id",id)
        if value and value>0 then return value end
    end
    return id
end
local function ready(id, target, player)
    local cast_id = resolve(id)
    if core.time()<(Runtime.retry_until[cast_id] or -math.huge) then return nil end
    if target and core.time()<(Runtime.target_retry_until[Runtime.cast_key(cast_id,target)]
        or -math.huge) then return nil end
    local confirmed_hammer = id == S.hammer_light
        and Aura.read(player, S.hammer_light_ready) == true
    if not known(id) and not known(cast_id) and not confirmed_hammer then return nil end
    if type(core.spell_book.is_usable_spell)~="function" then return nil end
    local usable=Host.static(core and core.spell_book,"is_usable_spell",cast_id)
    if usable~=true then return nil end
    local charge_ready = false
    if core.spell_book.get_spell_charge and core.spell_book.get_spell_charge_max then
        local current=Host.static(core and core.spell_book,"get_spell_charge",cast_id)
        local maximum=Host.static(core and core.spell_book,"get_spell_charge_max",cast_id)
        charge_ready = tonumber(maximum)
            and tonumber(maximum) > 1 and (tonumber(current) or 0) >= 1
    end
    if not charge_ready then
        if type(core.spell_book.get_spell_cooldown)~="function" then return nil end
        local cooldown=Host.static(core and core.spell_book,"get_spell_cooldown",cast_id)
        if (tonumber(cooldown) or math.huge)>0.15 then return nil end
    end
    if target and target ~= player and core.spell_book.is_spell_in_range
        then
        local in_range=Host.static(core and core.spell_book,"is_spell_in_range",cast_id,target,player)
        if in_range~=true then return nil end
    end
    return cast_id
end
local function cast(id, target, player)
    local cast_id = ready(id, target, player)
    if not cast_id or core.time() - (Runtime.attempts[cast_id] or -math.huge) < 0.65 then return false end
    Runtime.attempts[cast_id] = core.time()
    if Host.static(core and core.input,"cast_target_spell",cast_id,target) then
        Runtime.pending_cast[cast_id]={target=target,time=core.time()}
        Runtime.last_action = core.time()
        Settings.status = "Cast " .. tostring(cast_id)
        Logger.cast(cast_id,target,"accepted")
        return true
    end
    return false
end
local function cast_off_gcd(id, target, player)
    local cast_id = ready(id, target, player)
    if not cast_id or core.time() - (Runtime.attempts[cast_id] or -math.huge) < 0.65 then return false end
    Runtime.attempts[cast_id] = core.time()
    if Host.static(core and core.input,"cast_target_spell",cast_id,target) then
        Runtime.pending_cast[cast_id]={target=target,time=core.time()}
        Settings.status = "Cast mitigation " .. tostring(cast_id)
        Logger.cast(cast_id,target,"accepted_off_gcd")
        return true
    end
    return false
end
local function cast_defensive(id, player, emergency)
    if not emergency and core.time() - Runtime.last_defensive < 3.0 then return false end
    if cast(id, player, player) then
        Runtime.last_defensive = core.time()
        return true
    end
    return false
end
local function hp(unit)
    local maximum = unit:get_max_health()
    return maximum and maximum > 0 and unit:get_health() * 100 / maximum or 100
end
local function in_delve()
    return Runtime.dungeon.is_delve_like()
end
local function engaged_enemy(player, unit)
    if not valid(unit) then return false end
    if Runtime.is_training_dummy(unit) then return true end
    local victim = unit.get_target and unit:get_target() or nil
    if type(Threat.is_party_victim)=="function" then
        if Threat.is_party_victim(player,victim) then return true end
    else
        if Threat.same(victim,player) then return true end
        if victim and type(victim.is_party_member)=="function" then
            local ok,party=pcall(victim.is_party_member,victim)
            if ok and party==true then return true end
        end
        if in_delve() and valid(victim) then
            local ok,hostile=pcall(player.can_attack,player,victim)
            if ok and hostile==false then return true end
        end
    end
    if player.get_threat_situation then
        local ok, threat = pcall(player.get_threat_situation, player, unit)
        if ok and type(threat) == "table"
            and (threat.is_tanking == true or (tonumber(threat.status) or 0) > 0) then
            return true
        end
    end
    return false
end
local BREAKABLE_CONTROL={6770,2094,1776,118,51514,20066,8122,5782,3355,6358,33786}
local function breakable_control(unit)
    for _,id in ipairs(BREAKABLE_CONTROL) do
        if Aura.read(unit,id,true)==true then return true end
    end
    return false
end
local function control_immune(unit)
    for _,method in ipairs({"is_stun_immune","is_cc_immune","is_crowd_control_immune"}) do
        if unit and type(unit[method])=="function" then
            local ok,value=pcall(unit[method],unit)
            if ok and value==true then return true end
        end
    end
    return false
end
local function breakable_control_near(player,radius)
    local origin=player:get_position();if not origin then return false end
    for _,unit in pairs(Runtime.objects()) do
        local ok,blocked=pcall(function()
            if not valid(unit) or not unit:is_unit() or not player:can_attack(unit)
                or not breakable_control(unit) then return false end
            local point=unit:get_position();if not point then return false end
            local dx,dy,dz=point.x-origin.x,point.y-origin.y,point.z-origin.z
            return dx*dx+dy*dy+dz*dz<=(radius or 15)^2
        end)
        if ok and blocked then return true end
    end
    return false
end
local function is_boss(target)
    if target and target.is_boss then
        local ok, boss = pcall(target.is_boss, target)
        if ok and boss == true then return true end
    end
    local wanted = Aura.guid(target)
    if not wanted then return false end
    for _, boss in pairs(Runtime.boss_frames()) do
        if Aura.guid(boss) == wanted then return true end
    end
    return false
end
local function enemies_near(player, radius)
    local count, p = 0, player:get_position()
    if not p then return 0 end
    for _, unit in pairs(Runtime.objects()) do
        local ok, hostile = pcall(function()
            return valid(unit) and unit:is_unit() and player:can_attack(unit)
                and engaged_enemy(player, unit)
        end)
        if ok and hostile then
            local q = unit:get_position()
            if q and (p.x-q.x)^2 + (p.y-q.y)^2 + (p.z-q.z)^2 <= radius*radius then count=count+1 end
        end
    end
    return count
end
local function safe_combat_target(player,current)
    if valid(current) and player:can_attack(current) and engaged_enemy(player,current)
        and not breakable_control(current) and Runtime.reachable(player,current) then
        return current
    end
    local origin=player:get_position()
    if not origin then return nil end
    local best,best_score=nil,-math.huge
    for _,unit in pairs(Runtime.objects()) do
        local ok,score=pcall(function()
            if not valid(unit) or not unit:is_unit() or not player:can_attack(unit)
                or breakable_control(unit)
                or not engaged_enemy(player,unit) then return nil end
            if not Runtime.reachable(player,unit) then return nil end
            local point=unit:get_position();if not point then return nil end
            local dx,dy,dz=point.x-origin.x,point.y-origin.y,point.z-origin.z
            local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
            if distance>40 then return nil end
            local value=40-distance
            local victim=unit.get_target and unit:get_target() or nil
            if victim and victim.is_party_member then
                local party_ok,party=pcall(victim.is_party_member,victim)
                if party_ok and party then value=value+25 end
            end
            if victim then
                local members={}
                if core.object_manager.get_party_members then
                    local value=Runtime.manager("get_party_members")
                    if type(value)=="table" then members=value end
                end
                for _,member in pairs(members) do
                    if Threat.same(victim,member.object)
                        and string.upper(tostring(member.role or ""))=="HEALER" then
                        value=value+40;break
                    end
                end
            end
            if (unit.is_casting_spell and unit:is_casting_spell())
                or (unit.is_channelling_spell and unit:is_channelling_spell()) then value=value+15 end
            return value
        end)
        if ok and score and score>best_score then best,best_score=unit,score end
    end
    return best
end
local function interrupt_target(player, current)
    local function interrupt_key(unit)
        local id
        if unit then
            local channel=unit.is_channelling_spell and unit:is_channelling_spell()
            local method=channel and "get_active_channel_spell_id" or "get_active_spell_id"
            if type(unit[method])=="function" then
                local ok,value=pcall(unit[method],unit);if ok then id=tonumber(value) end
            end
        end
        return tostring(Aura.guid(unit) or unit)..":"..tostring(id or 0)
    end
    local function eligible(unit)
        if not valid(unit) then return false end
        local ok, result = pcall(function()
            return unit:is_unit() and player:can_attack(unit)
                and engaged_enemy(player, unit)
                and (unit:is_casting_spell() or unit:is_channelling_spell())
                and unit:is_active_spell_interruptable()
        end)
        if not ok or result ~= true then return false end
        if core.time()<(Runtime.interrupt_failed_until[interrupt_key(unit)] or -math.huge) then return false end
        if not Runtime.reachable(player,unit) then return false end
        return ready(S.rebuke, unit, player) ~= nil
            or ready(S.avengers_shield, unit, player) ~= nil
            or (not is_boss(unit) and Settings.on("stun_backup")
                and ready(S.hammer_justice, unit, player) ~= nil)
    end
    local origin = player:get_position()
    if not origin then return nil end
    local best, best_finish, best_priority = nil, math.huge, -math.huge
    local function in_interrupt_window(unit, priority, channeling, finish)
        if channeling then return true end
        local now_ms=core.game_time()
        if finish and finish>=now_ms and finish-now_ms<=350 then return true end
        if type(unit.get_active_spell_cast_start_time)~="function" or not finish then return true end
        local ok,started=pcall(unit.get_active_spell_cast_start_time,unit)
        started=ok and tonumber(started) or nil
        if not started or finish<=started or now_ms<started then return true end
        local progress=(now_ms-started)/(finish-started)
        return progress >= (priority>=20 and 0.25 or 0.55)
    end
    local function consider(unit)
        if not eligible(unit) then return end
        local point = unit:get_position()
        if not point then return end
        local distance_sq = (origin.x-point.x)^2 + (origin.y-point.y)^2
            + (origin.z-point.z)^2
        if distance_sq > 30*30 then return end
        local finish = tonumber(unit:get_active_spell_cast_end_time()) or math.huge
        local channeling = unit:is_channelling_spell()
        if channeling then
            finish = tonumber(unit:get_active_channel_cast_end_time()) or finish
        end
        local spell_id
        local id_method = channeling and "get_active_channel_spell_id" or "get_active_spell_id"
        if type(unit[id_method]) == "function" then
            local ok, value = pcall(unit[id_method], unit)
            if ok then spell_id = tonumber(value) end
        end
        local spell_name
        if spell_id and core.spell_book.get_spell_name then
            spell_name=Host.static(core and core.spell_book,"get_spell_name",spell_id)
        end
        local mechanic_score = select(1, Mechanics.classify(spell_name,spell_id)) or 0
        local maximum = player:get_max_health() or 0
        local learned = select(1, Intelligence.learned_pressure(spell_id, maximum)) or 0
        local priority = math.max(mechanic_score, learned)
        if not in_interrupt_window(unit,priority,channeling,finish) then return end
        if priority > best_priority or (priority == best_priority and finish < best_finish) then
            best, best_finish, best_priority = unit, finish, priority
        end
    end
    consider(current)
    for _, unit in pairs(Runtime.objects()) do
        if not Threat.same(unit, current) then consider(unit) end
    end
    return best
end
local function nearby_interruptible_casts(player, radius)
    local origin = player:get_position()
    if not origin then return 0 end
    local count = 0
    for _, unit in pairs(Runtime.objects()) do
        local ok, eligible = pcall(function()
            if not valid(unit) or not unit:is_unit() or not player:can_attack(unit)
                or not engaged_enemy(player, unit) or is_boss(unit)
                or not (unit:is_casting_spell() or unit:is_channelling_spell())
                or not unit:is_active_spell_interruptable() then return false end
            local point = unit:get_position()
            if not point then return false end
            if not unit:is_channelling_spell() and unit.get_active_spell_cast_end_time then
                local finish=tonumber(unit:get_active_spell_cast_end_time())
                if finish and finish-core.game_time()>350 then return false end
            end
            return (origin.x-point.x)^2 + (origin.y-point.y)^2
                + (origin.z-point.z)^2 <= radius*radius
        end)
        if ok and eligible then count = count + 1 end
    end
    return count
end
local function has_buff(unit, id) return Aura.read(unit, id) == true end
local function buff_stacks(unit, id) return Aura.stacks(unit, id) or 0 end
local function charges(id)
    local spell_id = resolve(id)
    if not core.spell_book.get_spell_charge then return 0, 0 end
    local current=Host.static(core and core.spell_book,"get_spell_charge",spell_id)
    local maximum=Host.static(core and core.spell_book,"get_spell_charge_max",spell_id)
    if type(current) ~= "number"
        or type(maximum) ~= "number" then return 0, 0 end
    return current, maximum
end
local function safe_bubble(player)
    if has_buff(player, S.forbearance) then return nil end
    local origin = player:get_position()
    if not origin then return nil end
    local final_stand=known(S.final_stand)
    local single,count=nil,0
    for _, unit in pairs(Runtime.objects()) do
        local ok, state = pcall(function()
            if not valid(unit) or not unit:is_unit() or not player:can_attack(unit)
                or not engaged_enemy(player, unit) then return nil end
            local victim = unit:get_target()
            local threat = player:get_threat_situation(unit)
            local tanking=Threat.same(victim,player)
                or (type(threat)=="table" and threat.is_tanking==true)
            if not tanking then return "unsafe" end
            local point = unit:get_position()
            if final_stand and (not point or (origin.x-point.x)^2 + (origin.y-point.y)^2
                + (origin.z-point.z)^2 > 15*15) then return "unsafe" end
            return "tanked"
        end)
        if not ok or state=="unsafe" then return nil end
        if state=="tanked" then count=count+1;single=unit end
    end
    if final_stand then return "final_stand" end
    local clock=core.time()
    if count==1 and Runtime.bubble_taunt_target==single
        and clock<(Runtime.bubble_taunt_until or 0) then return "taunted",single end
    if count==1 and ready(S.hand_reckoning,single,player)~=nil then return "needs_taunt",single end
    return nil
end
local function is_protection_paladin(player)
    -- Callbacks may fire before the object manager has a local player or while
    -- zoning/logging out. Missing player state means the plugin stays inactive.
    if not player or type(player.get_class)~="function" then return false end
    local ok_class, class_id = pcall(player.get_class, player)
    if not ok_class or not class_id then return false end
    local paladin_class=enums.class_id and enums.class_id.PALADIN or 2
    if class_id~=paladin_class then return false end
    local raw = Host.static(core and core.spell_book,"get_specialization_id")
    if not raw or raw <= 0 then return false end
    local spec_enum = enums.class_spec_id and enums.class_spec_id.spec_enum
    local expected = spec_enum and spec_enum.PROTECTION_PALADIN
    if expected and enums.class_spec_id.get_specialization_enum then
        local ok, converted = pcall(enums.class_spec_id.get_specialization_enum, class_id, raw)
        if ok and converted then raw=converted end
    end
    -- Some hosts expose the canonical specialization ID without the enum
    -- conversion helper; older wrappers may expose the class-local index.
    return raw==(expected or 66) or raw==66 or raw==2
end
local function prepare_next_pull(player)
    if not Settings.on("prepull") then return false end
    local state=Routes.get_state and Routes.get_state() or {}
    if state.decision~="READY" and state.decision~="SPLIT" then return false end
    local distance=tonumber(state.distance)
    if not distance or state.group_ready==false or state.healer_recovering
        or state.active_pull_engaged then return false end
    -- Blessed Hammer can bank Holy Power without touching a pack. Keep a
    -- twelve-yard buffer so its orbit cannot become an accidental pull.
    if distance>=12 and distance<=25 and (player:get_power(9) or 0)<3
        and known(S.blessed_hammer) and cast(S.blessed_hammer,player,player) then
        Settings.status="Pre-pull Holy Power";return true
    end
    -- Pre-arm only the inexpensive short cooldown, once per planned pull.
    -- Ardent Defender is deliberately excluded when it replaces DP.
    local key=tostring(state.route_name or "route")..":"..tostring(state.pull_index or 0)
    if distance<=10 and (state.risk=="Severe" or state.risk=="Boss")
        and known(S.divine_protection) and Runtime.prepared_pull_key~=key
        and not has_buff(player,S.divine_protection)
        and cast_defensive(S.divine_protection,player) then
        Runtime.prepared_pull_key=key;Settings.status="Pre-pull Divine Protection";return true
    end
    return false
end
local function face_target(player,target)
    if not Settings.on("auto_face") or not valid(target)
        or core.time()-(Runtime.last_face or -math.huge)<0.6
        or type(player.is_facing)~="function" then return false end
    local facing_ok,facing=pcall(player.is_facing,player,target)
    if not facing_ok or facing~=false then return false end
    local point=target.get_position and target:get_position() or nil
    if not point or not core.input then return false end
    local method_name=type(core.input.look_at_3d)=="function" and "look_at_3d"
        or type(core.input.look_at)=="function" and "look_at" or nil
    if not method_name then return false end
    local ok,result=Host.try_static(core and core.input,method_name,point)
    if ok and result~=false then Runtime.last_face=core.time();Settings.status="Facing engaged target";return true end
    return false
end
local function update()
    Runtime.object_snapshot_ready=false;Runtime.object_snapshot=nil
    if not Settings.on("enabled") then Prediction.reset(); Settings.status="Off"
        Settings.telemetry={mode="OFF",health=100,holy_power=0,sotr_active=false,
            sotr_remaining=0,consecration=false,risk="OFF",projected_pct=100};return end
    local player = Runtime.local_player()
    if not valid(player) then Settings.status="Waiting for player"; return end
    if not is_protection_paladin(player) then
        Settings.status="Requires Protection Paladin"; return
    end
    Intelligence.sync_context()
    if player:is_casting_spell() or player:is_channelling_spell() then return end
    -- Manual input pauses ordinary damage, but tank-critical armor, defensives,
    -- interrupts, taunts and emergency support must remain responsive.
    local manual_yielding=Settings.on("manual_input_yield")
        and core.time()<Runtime.manual_yield_until
    if not player:is_in_combat() and Settings.on("auto_aura")
        and known(S.devotion_aura) and not has_buff(player, S.devotion_aura) then
        if cast(S.devotion_aura, player, player) then return end
    end
    local selected=player:get_target()
    local dummy_mode=valid(selected) and player:can_attack(selected)
        and Runtime.is_training_dummy(selected)
    if not player:is_in_combat() and not dummy_mode then
        Prediction.reset();Threat.reset()
        Settings.telemetry={mode="READY",health=hp(player),holy_power=player:get_power(9) or 0,
            sotr_active=false,sotr_remaining=0,consecration=has_buff(player,S.consecration_buff),
            risk="READY",projected_pct=hp(player)}
        if prepare_next_pull(player) then return end
        Settings.status="Ready";return
    end
    -- One immutable host snapshot serves every targeting, interrupt, crowd
    -- control and proximity pass in this combat update. Host enumeration is
    -- substantially more expensive than iterating the returned Lua table.
    Runtime.object_snapshot=Runtime.manager("get_all_objects")
    Runtime.object_snapshot_ready=true
    -- Apply off-GCD armor before any healing, taunt, interrupt or generator can
    -- return. This pass also works after the selected enemy dies.
    local holy_power = player:get_power(9) or 0
    local divine_purpose = has_buff(player, S.divine_purpose)
        or has_buff(player, S.divine_purpose_legacy)
    local sotr_active, sotr_remaining = Aura.read(player, S.shield_righteous_buff)
    local current = selected
    if Settings.on("auto_combat_target") then
        local safe=safe_combat_target(player,current)
        if safe and not Threat.same(safe,current) and core.input.set_target then
            Host.static(core and core.input,"set_target",safe);Settings.status="Selected engaged enemy"
        end
        current=safe
    end
    face_target(player,current)
    local hammer_ready,hammer_proc_remaining = Aura.read(player, S.hammer_light_ready)
    local shake_active,shake_remaining=Aura.read(player,S.shake_heavens)
    local hammer_now=Runtime.hammer_of_light_now(hammer_ready,hammer_proc_remaining,
        shake_active,shake_remaining)
    local armor_urgent = not sotr_active or (sotr_remaining and sotr_remaining < 1.5)
    local reserve_hammer = hammer_ready and valid(current) and player:can_attack(current)
        and ready(S.hammer_light, current, player) ~= nil and (hammer_now or armor_urgent)
    local vanguard_shield = has_buff(player, S.vanguard)
        or (known(S.vanguard_final)
            and (has_buff(player, S.avenging_wrath) or has_buff(player, S.sentinel)))
    local make_shield_room = vanguard_shield and valid(current) and player:can_attack(current)
        and ready(S.avengers_shield, current, player) ~= nil
        and not hammer_ready
    local should_sotr = divine_purpose or has_buff(player, S.valor)
        or make_shield_room or holy_power >= 5 or not sotr_active
        or not sotr_remaining or sotr_remaining < 9.0
    if (holy_power >= 3 or divine_purpose) and should_sotr
        and (not reserve_hammer or armor_urgent or divine_purpose)
        and cast_off_gcd(S.shield_righteous, player, player) then
        -- The client may not have refreshed its resource snapshot in this frame.
        -- Budget the confirmed spend locally before considering Divine Toll.
        holy_power = math.max(0, holy_power - (divine_purpose and 0 or 3))
    end
    if core.time()-Runtime.last_action < 0.15 then return end
    local health = hp(player)
    local forecast = not dummy_mode and Settings.on("prediction")
        and Prediction.evaluate(player, Settings.value("prediction_window"),
            Settings.on("boss_timers")) or nil
    local route_state = Routes.get_state and Routes.get_state() or {}
    local planned_large_pull = (route_state.planned_enemies or 0) >= 8
        or (route_state.pull_forces or 0) >= 50
        or (route_state.failure_count or 0) > 0
    local healer_low = route_state.healer_mana and route_state.healer_mana < 30
    if not Settings.on("prediction") then Prediction.reset() end
    local guardian_active = has_buff(player, S.guardian_kings)
    local ardent_active = has_buff(player, S.ardent_defender)
    local bubble_active = has_buff(player, S.divine_shield)
    local major_active = guardian_active or ardent_active or bubble_active
    local lethal = health <= 20
        or (forecast and (forecast.projected_pct <= 20 or forecast.time_to_die <= 1.25))
    local sentinel_strong = buff_stacks(player, S.sentinel) >= 8
    local sentinel_active = has_buff(player,S.sentinel)
    Settings.telemetry={mode=dummy_mode and "TRAINING" or "COMBAT",health=health,holy_power=holy_power,
        sotr_active=sotr_active==true,sotr_remaining=sotr_remaining or 0,
        consecration=has_buff(player,S.consecration_buff),
        risk=lethal and "LETHAL" or forecast and forecast.danger>=30 and "SEVERE"
            or forecast and forecast.danger>=16 and "HIGH" or forecast and forecast.danger>=8 and "WATCH" or "STABLE",
        projected_pct=forecast and forecast.projected_pct or health,
        incoming_pct=forecast and forecast.incoming_pct or 0,
        mechanic=forecast and (forecast.mechanic_name or forecast.timer_name) or nil}
    local allow_moderate = not sentinel_strong or health <= 45
        or (forecast and (forecast.mechanic_score >= 30 or forecast.incoming_pct >= 25
            or forecast.projected_pct <= 45))
    -- Lay on Hands is the emergency recovery layer. It was previously absent
    -- from the defensive table entirely; Forbearance prevents invalid attempts.
    if not dummy_mode and health <= Settings.value("lay_on_hands_hp")
        and Settings.value("lay_on_hands_hp") > 0
        and not has_buff(player, S.forbearance)
        and cast(S.lay_hands, player, player) then
        Runtime.last_defensive = core.time()
        Settings.status = "Emergency Lay on Hands"
        return
    end
    if not dummy_mode and forecast and not bubble_active and not guardian_active and (not ardent_active or lethal) then
        local severe = forecast.projected_pct <= Settings.value("prediction_guardian")
            or forecast.incoming_pct >= 40 or forecast.time_to_die <= 1.25
            or (forecast.mechanic_score >= 30 and forecast.current_pct <= 55)
            or ((forecast.mechanic_chain or 0)>=2 and forecast.current_pct<=70)
        local elevated = forecast.projected_pct <= Settings.value("prediction_ardent")
            and (forecast.incoming_pct >= 8 or forecast.trend_pct >= 8
                or forecast.targeted_casts > 0 or forecast.enemy_count >= 4
                or forecast.timer_emphasized)
        elevated = elevated or forecast.mechanic_score >= 20
            or (forecast.mechanic_chain or 0)>=2
        if severe and cast_defensive(S.guardian_kings, player, lethal) then
            Settings.status = forecast.mechanic_name and
                string.format("%s%s • Guardian", forecast.mechanic_name,
                    forecast.timer_remaining and string.format(" in %.1fs", forecast.timer_remaining) or "")
                or forecast.timer_name and
                string.format("%s in %.1fs • Guardian", forecast.timer_name, forecast.timer_remaining or 0)
                or string.format("Predicted %.0f%% HP • Guardian", forecast.projected_pct)
            return
        end
        -- In Midnight, Ardent Defender replaces Divine Protection when
        -- selected. Choose the short defensive that actually exists.
        local short_defensive = known(S.divine_protection)
            and S.divine_protection or S.ardent_defender
        local short_active = has_buff(player, S.divine_protection)
            or has_buff(player, S.ardent_defender)
        local divine_needed
        if short_defensive == S.ardent_defender then
            -- Ardent is a 90-second death-save cooldown, so do not spend it on
            -- every routine targeted cast as we would the cheaper Divine Protection.
            divine_needed = not short_active and (forecast.incoming_pct >= 12
                or forecast.trend_pct >= 10 or forecast.danger >= 24
                or forecast.mechanic_score >= 20
                or forecast.projected_pct <= Settings.value("prediction_ardent"))
            divine_needed = divine_needed and allow_moderate
        else
            divine_needed = not short_active and (forecast.incoming_pct >= 8
                or forecast.trend_pct >= 6 or forecast.targeted_casts > 0
                or forecast.danger >= 16 or forecast.mechanic_score >= 12)
        end
        divine_needed = divine_needed or (((planned_large_pull and healer_low)
            or route_state.risk == "Severe") and forecast.enemy_count >= 4)
        -- Rotate coverage instead of stacking the short cooldown on Sentinel.
        -- Severe/lethal busters can still escalate through existing coverage.
        divine_needed=divine_needed and (not sentinel_active or severe or lethal
            or forecast.mechanic_score>=30 or forecast.projected_pct<=35)
        if divine_needed and cast_defensive(short_defensive, player) then
            Settings.status = forecast.mechanic_name
                and (forecast.mechanic_name .. (short_defensive == S.ardent_defender
                    and " • Ardent Defender" or " • Divine Protection"))
                or string.format("Predicted pressure %.0f • %s", forecast.danger,
                    short_defensive == S.ardent_defender and "Ardent Defender"
                        or "Divine Protection")
            return
        end
        if elevated and allow_moderate and not short_active
            and cast_defensive(S.ardent_defender, player) then
            Settings.status = forecast.mechanic_name and
                string.format("%s%s • Ardent", forecast.mechanic_name,
                    forecast.timer_remaining and string.format(" in %.1fs", forecast.timer_remaining) or "")
                or forecast.timer_name and
                string.format("%s in %.1fs • Ardent", forecast.timer_name, forecast.timer_remaining or 0)
                or string.format("Predicted %.0f%% HP • Ardent", forecast.projected_pct)
            return
        end
    end
    if not dummy_mode and health <= Settings.value("bubble_hp") and Settings.value("bubble_hp") > 0
        and not bubble_active and (not major_active or lethal) then
        local bubble_mode,bubble_target=safe_bubble(player)
        if bubble_mode=="needs_taunt" and cast(S.hand_reckoning,bubble_target,player) then
            Runtime.bubble_taunt_target=bubble_target
            Runtime.bubble_taunt_until=core.time()+2.5
            Settings.status="Taunt secured • Divine Shield next"
            return
        end
        if bubble_mode and bubble_mode~="needs_taunt"
            and cast_defensive(S.divine_shield,player,lethal) then
            Runtime.bubble_taunt_target=nil;Runtime.bubble_taunt_until=nil;return
        end
    end
    if not dummy_mode and health <= Settings.value("guardian_hp") and not has_buff(player, S.guardian_kings)
        and not bubble_active and (not ardent_active or lethal)
        and cast_defensive(S.guardian_kings, player, lethal) then return end
    if not dummy_mode and health <= Settings.value("ardent_hp") and not has_buff(player, S.ardent_defender)
        and not major_active and allow_moderate and cast_defensive(S.ardent_defender, player) then return end
    -- Preserve Holy Power for Shield of the Righteous. Icy Veins places Word of
    -- Glory here only when Shining Light makes it free.
    if not dummy_mode and health <= Settings.value("word_of_glory_hp") and has_buff(player, S.shining_light)
        and cast(S.word_glory, player, player) then return end
    local forecast_safe = not forecast or ((forecast.projected_pct or 100) >= 60
        and (forecast.time_to_die or math.huge) > 4 and (forecast.mechanic_score or 0) < 20)
    if not dummy_mode and Settings.on("auto_battle_rez") and health >= 70 and forecast_safe
        and holy_power >= 3 and sotr_active and (sotr_remaining or 0) >= 4 then
        local ally = Utility.dead_ally()
        if ally and cast(S.intercession, ally, player) then
            Settings.status="Intercession • party recovery"; return
        end
    end
    if not dummy_mode and Settings.on("auto_cleanse") then
        local ally,role=Utility.cleanse_target(player)
        if ally and cast(S.cleanse_toxins, ally, player) then
            Settings.status="Cleanse Toxins • "..tostring(role or "party"); return
        end
    end
    if not dummy_mode and Settings.on("auto_freedom") then
        local ally,role=Utility.freedom_target(player)
        if ally and cast(S.blessing_freedom,ally,player) then
            Settings.status="Blessing of Freedom • "..tostring(role or "party");return
        end
    end
    local critical_ally=Utility.critical_ally(25)
        or Utility.critical_delve_companion(player,30)
    if not dummy_mode and Settings.on("party_support") and health >= 75 and forecast_safe
        and has_buff(player,S.shining_light) then
        if critical_ally and cast(S.word_glory,critical_ally,player) then
            Settings.status="Free Word of Glory • ally"; return
        end
    end
    local sacrifice_safe=health>=80 and forecast_safe and sotr_active
        and (sotr_remaining or 0)>=6 and (not forecast
            or ((forecast.projected_pct or 100)>=75
                and (forecast.time_to_die or math.huge)>8
                and (forecast.incoming_pct or 0)<15))
    if not dummy_mode and Settings.on("auto_sacrifice") and sacrifice_safe and critical_ally
        and cast(S.blessing_sacrifice,critical_ally,player) then
        Settings.status="Blessing of Sacrifice • ally rescue";return
    end
    if not dummy_mode and Settings.on("delve_survival") and in_delve() and health<=35
        and holy_power>=3 and sotr_active and (sotr_remaining or 0)>=5
        and cast(S.word_glory,player,player) then
        Settings.status="Delve emergency Word of Glory";return
    end
    -- Convert Holy Power into survival when emergency cooldowns cannot answer
    -- critical health, but only behind stable Shield of the Righteous coverage.
    if not dummy_mode and Settings.on("emergency_paid_wog") and health<=30 and holy_power>=3
        and not has_buff(player,S.shining_light)
        and sotr_active and (sotr_remaining or 0)>=5
        and ready(S.lay_hands,player,player)==nil
        and ready(S.guardian_kings,player,player)==nil
        and ready(S.ardent_defender,player,player)==nil
        and cast(S.word_glory,player,player) then
        Settings.status="Emergency paid Word of Glory";return
    end
    local target=current
    if not Settings.on("auto_combat_target") then target=player:get_target() end
    -- An in-window cast has a fixed deadline. Handle it before changing targets
    -- for threat recovery; the loose enemy remains eligible on the next frame.
    local caster = not dummy_mode and Settings.on("interrupts") and interrupt_target(player, target) or nil
    if caster and not Intelligence.should_defer_interrupt(caster) then
        if cast(S.rebuke, caster, player) then return end
        if cast(S.avengers_shield, caster, player) then return end
        if Settings.on("stun_backup") and not is_boss(caster) and not control_immune(caster)
            and cast(S.hammer_justice, caster, player) then return end
    end
    if not dummy_mode and Settings.on("auto_taunt") then
        local loose = Threat.select(player, target, Settings.value("threat_range"))
        if loose and loose.object then
            Logger.threat_loss(loose)
            if Settings.on("threat_switch") and not Threat.same(target, loose.object)
                and core.input.set_target then
                Host.static(core and core.input,"set_target",loose.object)
                target = loose.object
                Settings.status = loose.needs_taunt==false
                    and string.format("Securing threat • %.0f%%", loose.threat_percent)
                    or string.format("Threat recovery • %.0f%%", loose.threat_percent)
            end
            if loose.needs_taunt~=false and cast(S.hand_reckoning, loose.object, player) then
                Threat.mark_taunted(loose.object, 3.0)
                Settings.status = "Taunted loose enemy"
                return
            end
            -- Keep damaging this enemy until its threat table confirms we are tanking.
            target = loose.object
        end
    end
    -- Blinding Light remains available when all direct interrupts are spent.
    if Settings.on("interrupts") and Settings.on("aoe_stop")
        and nearby_interruptible_casts(player, 10) >= 2
        and not breakable_control_near(player,15)
        and cast(S.blinding_light, player, player) then return end
    if manual_yielding then Settings.status="Yielding offense to manual input";return end
    if not valid(target) or not player:can_attack(target) then Settings.status="Select a hostile target"; return end
    local count = enemies_near(player, 10)
    local preserve_control=breakable_control_near(player,30)
    local templar = known(S.hammer_light) or known(S.hammer_light_ready) or hammer_ready
    local lightsmith = known(S.holy_armaments_talent) or known(S.holy_armaments)
        or known(S.sacred_weapon)

    -- Shining Light caps at two stacks. Spend a free self-heal before another
    -- Shield of the Righteous would waste progress, provided healing is useful.
    local shining_stacks = buff_stacks(player, S.shining_light)
    if shining_stacks >= 2 and (health < 95 or known(S.blessed_word))
        and cast(S.word_glory, player, player) then return end
    -- Free Blessed Word overhealing becomes an absorb. Pre-arm it for a known
    -- heavy mechanic without spending Holy Power needed for armor.
    if known(S.blessed_word) and shining_stacks >= 1 and forecast
        and (forecast.mechanic_score >= 20 or forecast.incoming_pct >= 25)
        and cast(S.word_glory, player, player) then return end
    local armament_id, armament_resolved, armament_charges, armament_max
    if lightsmith then
        armament_resolved = resolve(S.holy_armaments)
        armament_id = (known(S.holy_armaments) or known(armament_resolved))
            and S.holy_armaments or S.sacred_weapon
        armament_charges, armament_max = charges(armament_id)
    end
    if Settings.on("cooldowns") then
        local major = known(S.sentinel) and S.sentinel or S.avenging_wrath
        local wings = has_buff(player, S.avenging_wrath) or has_buff(player, S.sentinel)
        -- Method recommends entering a Lightsmith wings window with Holy
        -- Bulwark already active to maximize Reflection of Radiance procs.
        local capped_bulwark = lightsmith and not wings
            and armament_resolved == S.holy_bulwark
            and armament_max >= 2 and armament_charges >= armament_max
        if capped_bulwark and ready(major, player, player)
            and cast(armament_id, player, player) then return end
        -- Method recommends maximizing casts throughout an encounter rather than
        -- holding wings only for bosses or large packs.
        -- Route size informs defensive preparation above. Offensive cooldowns
        -- stay active on every pull because faster kills also reduce tank damage.
        if count > 0 and cast(major, player, player) then return end
    end
    -- Hammer of Light is the first Templar rotational priority; consume the proc
    -- before normal mitigation and generators so its 20-second window is not lost.
    if templar and hammer_now
        and cast(S.hammer_light, target, player) then return end
    -- A failed/out-of-range Hammer of Light must not suppress normal armor.
    if reserve_hammer and (holy_power >= 3 or divine_purpose) and should_sotr
        and cast_off_gcd(S.shield_righteous, player, player) then
        holy_power = math.max(0, holy_power - (divine_purpose and 0 or 3))
    end
    -- Lightsmith spends five Divine Guidance stacks through Consecration.
    if not preserve_control and lightsmith and buff_stacks(player, S.divine_guidance) >= 5
        and cast(S.consecration, player, player) then return end
    -- Divine Toll can generate up to 5 Holy Power. Only fire it after making
    -- room so the burst cast also feeds additional Shield of the Righteous uses.
    if not preserve_control and Settings.on("cooldowns") and count > 0 and holy_power <= 2
        and cast(S.divine_toll, target, player) then return end

    -- In Midnight, Hammer of Wrath is Judgment's wings-only transformation.
    -- The override resolver in cast() handles that form, so manage Judgment's
    -- charges directly and never let the two-charge generator cap.
    local judgment_charges, judgment_max = charges(S.judgment)
    if judgment_max >= 2 and judgment_charges >= judgment_max
        and cast(S.judgment, target, player) then return end

    local vanguard = vanguard_shield
    local hammer_of_wrath = resolve(S.judgment) ~= S.judgment
    -- Both hero trees elevate an Apex-powered shield. Lightsmith also elevates
    -- Avenger's Shield naturally at two or more targets.
    if not preserve_control and ((lightsmith and count >= 2) or vanguard)
        and cast(S.avengers_shield, target, player) then return end

    if lightsmith then
        -- During wings Judgment resolves to Hammer of Wrath and belongs ahead
        -- of Sacred Weapon. Normal Judgment remains below Blessed Assurance.
        if hammer_of_wrath and cast(S.judgment, target, player) then return end

        -- Sacred Weapon is the damage half of rotating Holy Armaments. Refresh
        -- it when absent or below 20 seconds without consuming Bulwark early.
        local sacred_active, sacred_remaining = Aura.read(player, S.sacred_weapon_buff)
        local sacred_button = armament_resolved == S.sacred_weapon
            or armament_id == S.sacred_weapon
        local refresh_sacred = sacred_button and armament_charges >= 1
            and (not sacred_active or not sacred_remaining or sacred_remaining < 20)
        if Settings.on("cooldowns") and refresh_sacred
            and cast(armament_id, player, player) then return end

        if has_buff(player, S.blessed_assurance) then
            if not preserve_control and known(S.blessed_hammer) and cast(S.blessed_hammer, player, player) then return end
            if not preserve_control and cast(S.hammer_righteous, target, player) then return end
        end
        if cast(S.judgment, target, player) then return end

        local wings = has_buff(player, S.avenging_wrath) or has_buff(player, S.sentinel)
        local capped_bulwark = armament_resolved == S.holy_bulwark
            and armament_max >= 2 and armament_charges >= armament_max and not wings
        if Settings.on("cooldowns") and capped_bulwark
            and cast(armament_id, player, player) then return end
        if not preserve_control and cast(S.avengers_shield, target, player) then return end
    else
        -- Templar: Judgment/Hammer of Wrath precedes Shake maintenance.
        if cast(S.judgment, target, player) then return end
    end
    if not preserve_control and templar and has_buff(player, S.shake_heavens) and known(S.blessed_hammer)
        and cast(S.blessed_hammer, player, player) then return end
    if not preserve_control and templar and cast(S.avengers_shield, target, player) then return end
    -- With Hammerfall, a free Word of Glory has offensive value. Method places
    -- it here while Shake the Heavens is active; self-casting also refunds mana.
    if templar and has_buff(player, S.shining_light) and has_buff(player, S.shake_heavens)
        and cast(S.word_glory, player, player) then return end
    if not preserve_control and known(S.blessed_hammer) and cast(S.blessed_hammer, player, player) then return end
    if not preserve_control and cast(S.hammer_righteous, target, player) then return end
    if not preserve_control and not templar and cast(S.avengers_shield, target, player) then return end
    -- Current 12.1 priorities spend a free Shining Light heal after the direct
    -- generators. This also lets Lightsmith consume a useful one-stack proc
    -- instead of waiting for two stacks or emergency health.
    if has_buff(player, S.shining_light) and health < 95
        and cast(S.word_glory, player, player) then return end
    -- Unempowered Consecration is a filler in 12.1, behind the direct attacks.
    if not preserve_control and count > 0 and not has_buff(player, S.consecration_buff) then
        cast(S.consecration, player, player)
    end
end
core.register_on_spell_cast_callback(function(data)
    local callback_ok,callback_error=pcall(function()
    local local_player=Runtime.local_player()
    -- The Sylvanas loader can keep a module resident after a class change.  Do
    -- not let another character feed this plugin's aura, retry, or log state.
    if not is_protection_paladin(local_player) then return end
    Aura.confirm(data, local_player)
    Intelligence.on_spell_cast(data)
    if type(data)=="table" then
        local id=tonumber(data.spell_id)
        if id then
            local plugin_request=Runtime.pending_cast[id] and core.time()-(Runtime.pending_cast[id].time or 0)<=3
            if Aura.guid(data.caster)==Aura.guid(local_player) and not plugin_request then
                Runtime.manual_yield_until=core.time()+0.6
            end
            Runtime.failure_streak[id]=0;Runtime.retry_until[id]=nil;Runtime.pending_cast[id]=nil
        end
    end
    if type(data)=="table" and Aura.guid(data.caster)==Aura.guid(local_player) then
        Logger.cast(data.spell_id,data.target,"confirmed_callback")
    end
    end)
    if not callback_ok then Logger.error("spell_callback",callback_error) end
end)
if type(core.register_on_game_event_callback) == "function" then
    core.register_on_game_event_callback(function(event, args)
        local callback_ok,callback_error=pcall(function()
        if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEAVING_WORLD"
            or event=="PLAYER_DEAD" then
            Runtime.reset_transient();Aura.reset();Prediction.reset();Threat.reset()
            Intelligence.reset_transient();Utility.reset()
        end
        if not is_protection_paladin(Runtime.local_player()) then return end
        Intelligence.on_event(event, args)
        Utility.on_event(event, args)
        Logger.on_event(event,args)
        Danger.on_event(event,args)
        if type(args)=="table" and args[1]=="player" then
            local id=tonumber(args[3]) or tonumber(args[4]) or tonumber(args[#args])
            if id and (event=="UNIT_SPELLCAST_FAILED"
                or event=="UNIT_SPELLCAST_FAILED_QUIET") then
                local pending=Runtime.pending_cast[id]
                local player=Runtime.local_player()
                local target_key=pending and pending.target and Runtime.cast_key(id,pending.target)
                local self_target=pending and Aura.guid(pending.target)==Aura.guid(player)
                if target_key and not self_target then
                    Runtime.target_failure_streak[target_key]=math.min(4,
                        (Runtime.target_failure_streak[target_key] or 0)+1)
                    Runtime.target_retry_until[target_key]=core.time()+math.min(2,
                        0.4*Runtime.target_failure_streak[target_key])
                else
                    Runtime.failure_streak[id]=math.min(4,(Runtime.failure_streak[id] or 0)+1)
                    Runtime.retry_until[id]=core.time()+math.min(2,0.4*Runtime.failure_streak[id])
                end
                if (id==S.rebuke or id==S.avengers_shield or id==S.hammer_justice)
                    and pending and pending.target then
                    local unit=pending.target
                    local spell_id
                    local channel=unit.is_channelling_spell and unit:is_channelling_spell()
                    local method=channel and "get_active_channel_spell_id" or "get_active_spell_id"
                    if type(unit[method])=="function" then
                        local ok,value=pcall(unit[method],unit);if ok then spell_id=tonumber(value) end
                    end
                    Runtime.interrupt_failed_until[tostring(Aura.guid(unit) or unit)..":"
                        ..tostring(spell_id or 0)]=core.time()+1.5
                end
                Runtime.pending_cast[id]=nil
            elseif id and event=="UNIT_SPELLCAST_INTERRUPTED" then
                Runtime.retry_until[id]=core.time()+3
                Runtime.pending_cast[id]=nil
            elseif id and event=="UNIT_SPELLCAST_SUCCEEDED" then
                local pending=Runtime.pending_cast[id]
                if pending and pending.target then
                    local key=Runtime.cast_key(id,pending.target)
                    Runtime.target_failure_streak[key]=nil;Runtime.target_retry_until[key]=nil
                end
                Runtime.failure_streak[id]=0;Runtime.retry_until[id]=nil;Runtime.pending_cast[id]=nil
            end
        end
        if event == "PLAYER_DEAD" then Routes.record_failure() end
        end)
        if not callback_ok then Logger.error("game_event",callback_error) end
    end)
end
core.register_on_update_callback(function()
    local ok, err = pcall(update)
    if not ok then
        Settings.status = "API error: " .. tostring(err)
        if Settings.is_protection_paladin() then Logger.error("update",err) end
    end
    local post_ok,post_error=pcall(function()
        local local_player=Runtime.local_player()
        BossHelperGui.update(local_player)
        if is_protection_paladin(local_player) then
            Logger.activate()
            if Settings.on("danger_zones") or Settings.on("boss_guides") then
                Danger.update(local_player,Settings.on("boss_guides"))
            else Danger.reset("Off") end
            Settings.danger_status=Danger.status
            Settings.boss_guide_status=Danger.guide_status()
            Logger.snapshot(local_player,Settings,
                Routes.get_state and Routes.get_state() or Routes.state)
            Settings.logging_status=Logger.status
        end
    end)
    if not post_ok then Runtime.report_callback_error("post_update",post_error) end
end)
Settings.actions=Settings.actions or {}
Settings.actions.export_logs=function()
    Logger.export();Settings.logging_status=Logger.status
end
Gui.configure(Settings,Routes,Logger)
BossHelperGui.configure(Settings)
if type(core.register_on_render_callback)=="function" then core.register_on_render_callback(function()
    local ok,err=pcall(Danger.render);if not ok then Runtime.report_callback_error("danger_render",err) end
end) end
if type(core.register_on_render_window_callback)=="function" then
    core.register_on_render_window_callback(function()
        local ok,err=pcall(Gui.render);if not ok then Runtime.report_callback_error("gui_render",err) end
        local boss_ok,boss_err=pcall(BossHelperGui.render);if not boss_ok then Runtime.report_callback_error("boss_helper_render",boss_err) end
    end)
elseif type(core.register_on_render_callback)=="function" then
    core.register_on_render_callback(function()
        local ok,err=pcall(Gui.render);if not ok then Runtime.report_callback_error("gui_render",err) end
        local boss_ok,boss_err=pcall(BossHelperGui.render);if not boss_ok then Runtime.report_callback_error("boss_helper_render",boss_err) end
    end)
end
core.register_on_render_menu_callback(function()
    local ok,err=pcall(Settings.render);if not ok then Runtime.report_callback_error("settings_render",err) end
end)
return { settings=Settings, aura=Aura, routes=Routes, gathering=Gathering,
    prediction=Prediction, threat=Threat, maintenance=Maintenance,
    intelligence=Intelligence, utility=Utility, logger=Logger, gui=Gui, danger=Danger,
    boss_helper_gui=BossHelperGui, runtime=Runtime, update=update }
