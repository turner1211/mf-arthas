local M = {}
local Mechanics = require("prot_mechanics")
local Intelligence = require("prot_intelligence")
local Host = require("prot_host")
local Threat = require("prot_threat")
local Dungeon = require("prot_dungeon")
local state = { time = nil, health = nil, maximum = nil, owner = nil, loss_rate = 0 }

local function safe(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end

local function provider_call(provider,method)
    local fn=provider and provider[method]
    if type(fn)~="function" then return false,nil end
    local ok,value=pcall(fn,provider)
    if ok then return true,value end
    return pcall(fn)
end

local function guid(object)
    local value = safe(object, "get_guid")
    return value and tostring(value) or nil
end

local function same_unit(left, right)
    if left == right then return true end
    local a, b = guid(left), guid(right)
    return a and b and a == b or false
end

local function engaged_with_party(player, unit)
    local victim = safe(unit, "get_target")
    if Threat.is_party_victim(player,victim) then
        return true
    end
    if victim and Dungeon.is_delve_like() then
        if safe(victim,"is_dead")~=true
            and safe(player,"can_attack",victim)==false then return true end
    end
    local threat = safe(player, "get_threat_situation", unit)
    return type(threat) == "table"
        and (threat.is_tanking == true or (tonumber(threat.status) or 0) > 0)
end

local function update_health_velocity(player, now, health, maximum)
    local owner = guid(player)
    -- Health snapshots arrive between frames. Do not divide one update's loss
    -- by a tiny render interval, or interpret Sentinel's max-health change as
    -- damage. Sample over at least a quarter-second and reset on owner changes.
    if owner ~= state.owner or maximum ~= state.maximum
        or not state.time or now < state.time or now - state.time > 2.0 then
        state.time, state.health, state.maximum, state.owner = now, health, maximum, owner
        state.loss_rate = 0
        return 0
    end
    if now - state.time >= 0.25 then
        local elapsed = now - state.time
        local raw_loss_per_second = math.max(0, (state.health - health) / elapsed)
        local weight = 1 - math.exp(-elapsed / 0.75)
        state.loss_rate = state.loss_rate * (1-weight) + raw_loss_per_second * weight
        state.time, state.health = now, health
    end
    return state.loss_rate
end

local function hostile_cast_pressure(player, window, maximum, objects)
    local pressure, casts, mechanic_score, mechanic_name, mechanic_level = 0, 0, 0, nil, nil
    local learned_pressure, learned_samples = 0, 0
    -- Native cast timestamps are milliseconds on the game clock. Comparing
    -- them with core.time() seconds silently excluded every normal hostile cast.
    local now_ms = core.game_time()
    objects = objects or Host.manager("get_all_objects")
    if type(objects) ~= "table" then return 0, 0, 0, nil, nil end
    for _, unit in pairs(objects) do
        local valid = safe(unit, "is_valid") == true and safe(unit, "is_dead") ~= true
        local channeling = safe(unit, "is_channelling_spell") == true
        if valid and safe(unit, "is_unit") == true and safe(player, "can_attack", unit) == true
            and (safe(unit, "is_casting_spell") == true or channeling) then
            local target = safe(unit, "get_active_spell_target")
            if engaged_with_party(player, unit) then
                local finish = tonumber(safe(unit, "get_active_spell_cast_end_time"))
                if channeling then
                    finish = tonumber(safe(unit, "get_active_channel_cast_end_time")) or finish
                end
                -- A channel can deal its next tick long before its end time.
                local lands_soon = channeling or not finish or finish <= 0
                    or (finish >= now_ms and finish - now_ms <= window * 1000)
                if lands_soon then
                    local spell_id = tonumber(safe(unit, channeling
                        and "get_active_channel_spell_id" or "get_active_spell_id"))
                    local spell_name = nil
                    if spell_id and core.spell_book.get_spell_name then
                        spell_name=Host.static(core and core.spell_book,"get_spell_name",spell_id)
                    end
                    local score, level, matched = Mechanics.classify(spell_name,spell_id)
                    local learned, samples = Intelligence.learned_pressure(spell_id, maximum)
                    -- Generic casts matter only when aimed at the tank. Known
                    -- dungeon mechanics can be party-wide or untargeted, so
                    -- include them for any enemy already engaged with the group.
                    if same_unit(target, player) or score > 0 then
                        casts = casts + (same_unit(target, player) and 1 or 0)
                        pressure = pressure + math.max(score,
                            safe(unit, "is_active_spell_interruptable") == true and 6 or 12)
                        if learned > learned_pressure then
                            learned_pressure, learned_samples = learned, samples
                        end
                        if score > mechanic_score then
                            mechanic_score, mechanic_name, mechanic_level = score,
                                matched or spell_name, level
                        end
                    end
                end
            end
        end
    end
    return math.min(45, math.max(pressure, learned_pressure)), casts,
        mechanic_score, mechanic_name, mechanic_level, learned_pressure, learned_samples
end

local function nearby_pressure(player, objects)
    local origin = safe(player, "get_position")
    if not origin then return 0, 0 end
    local count, pressure = 0, 0
    objects = objects or Host.manager("get_all_objects")
    if type(objects) ~= "table" then return 0, 0 end
    for _, unit in pairs(objects) do
        local valid = safe(unit, "is_valid") == true and safe(unit, "is_dead") ~= true
        local hostile = valid and safe(player, "can_attack", unit) == true
        if hostile then
            local point = safe(unit, "get_position")
            if point then
                local dx, dy, dz = point.x-origin.x, point.y-origin.y, point.z-origin.z
                if dx*dx + dy*dy + dz*dz <= 15*15 then
                    local victim = safe(unit, "get_target")
                    local attacking_player = same_unit(victim, player)
                    local attacking_party = Threat.is_party_victim(player,victim)
                    local threat = safe(player, "get_threat_situation", unit)
                    local on_threat_table = type(threat) == "table"
                        and (threat.is_tanking == true or (tonumber(threat.status) or 0) > 0)
                    -- Ignore nearby hostiles that are not part of our pull. Mobs
                    -- currently attacking us contribute the most melee pressure.
                    if attacking_player or attacking_party or on_threat_table then
                        count = count + 1
                        pressure = pressure + (attacking_player and 2.25 or 0.9)
                    end
                end
            end
        end
    end
    return math.min(18, pressure), count
end

local function boss_timer_pressure(window, enabled, maximum)
    if not enabled or not core.addons then
        return 0, nil, nil, false, 0, nil, 0, nil
    end
    local bars, any_loaded, seen = {}, false, {}
    local function remaining_of(bar)
        if bar.paused==true or bar.is_paused==true or bar.stopped==true
            or bar.active==false then return nil end
        local remaining=tonumber(bar.remaining or bar.time_left or bar.timeLeft)
        if not remaining and tonumber(bar.ends_at or bar.end_time) then
            remaining=tonumber(bar.ends_at or bar.end_time)-core.time()
        end
        return remaining
    end
    for _, provider_name in ipairs({ "bigwigs", "exboss", "dbm", "deadlybossmods" }) do
        local provider = core.addons[provider_name]
        if provider and type(provider.is_loaded) == "function"
            and type(provider.get_bars) == "function" then
            local loaded_ok, loaded = provider_call(provider,"is_loaded")
            if loaded_ok and loaded then
                any_loaded = true
                local bars_ok, provider_bars = provider_call(provider,"get_bars")
                if bars_ok and type(provider_bars) == "table" then
                    for index, bar in pairs(provider_bars) do
                        local key = tostring(bar.spell_id or bar.spellId or "")..":"
                            ..string.lower(tostring(bar.text or "")):gsub("^%s+", ""):gsub("%s+$", "")
                        -- Empty labels are unrelated timers, not duplicates.
                        if key == "" then key = provider_name .. ":" .. tostring(index) end
                        local existing = seen[key]
                        if not existing then
                            bars[#bars + 1], seen[key] = bar, bar
                        elseif (remaining_of(bar) or math.huge)
                            < (remaining_of(existing) or math.huge) then
                            for index, saved in ipairs(bars) do
                                if saved == existing then bars[index] = bar; break end
                            end
                            seen[key] = bar
                        end
                    end
                end
            end
        end
    end
    if not any_loaded then return 0, nil, nil, false, 0, nil, 0, nil end
    local pressure, next_name, next_remaining, emphasized = 0, nil, nil, false
    local mechanic_score, mechanic_level, mechanic_name, mechanic_remaining = 0, nil, nil, nil
    local mechanic_chain,first_damage_remaining,followup_remaining=0,nil,nil
    for _, bar in pairs(bars) do
        local remaining = remaining_of(bar)
        if remaining and remaining >= 0 and remaining <= window + 0.75 then
            local important = bar.is_emphasized == true
            local spell_id=tonumber(bar.spell_id or bar.spellId or bar.id)
            local score, level, matched = Mechanics.classify(bar.text,spell_id)
            local warning_type=string.lower(tostring(bar.warning_type or bar.warningType
                or bar.role or bar.action or ""))
            if score==0 and (bar.is_tank==true or bar.is_defensive==true
                or warning_type=="tank" or warning_type=="defensive"
                or warning_type=="tankbuster") then
                score,level,matched=20,"bossmod",bar.text or "Tank mechanic"
            end
            local learned,samples=Intelligence.learned_pressure(spell_id,maximum)
            if learned>score then
                score,level,matched=learned,"learned",
                    bar.text or ("Spell "..tostring(spell_id))
            end
            -- Emphasis can mark movement, adds or a phase transition. Only a
            -- classified damaging mechanic is evidence for defensive pressure.
            if score > 0 then
                pressure = pressure + score;mechanic_chain=mechanic_chain+1
                if not first_damage_remaining or remaining<first_damage_remaining then
                    followup_remaining,first_damage_remaining=first_damage_remaining,remaining
                elseif not followup_remaining or remaining<followup_remaining then followup_remaining=remaining end
            end
            if score > mechanic_score then
                mechanic_score, mechanic_level, mechanic_name = score, level,
                    matched or tostring(bar.text or "Upcoming mechanic")
                mechanic_remaining = remaining
            end
            if not next_remaining or remaining < next_remaining then
                next_remaining = remaining
                next_name = tostring(bar.text or "Upcoming mechanic")
            end
            emphasized = emphasized or (important and score > 0)
        end
    end
    if mechanic_name then next_name, next_remaining = mechanic_name, mechanic_remaining end
    return math.min(45, pressure), next_name, next_remaining, emphasized,
        mechanic_score, mechanic_level, mechanic_name, mechanic_chain, followup_remaining
end

function M.evaluate(player, window, use_boss_timers)
    Intelligence.sync_context()
    window = math.max(1, math.min(4, tonumber(window) or 2))
    local health = tonumber(safe(player, "get_health")) or 0
    local maximum = tonumber(safe(player, "get_max_health")) or 0
    if maximum <= 0 then return nil end
    local now = core.time()
    local current_pct = math.max(0, math.min(100, health / maximum * 100))
    local incoming = tonumber(safe(player, "get_incoming_damage", window)) or 0
    local heals = tonumber(safe(player, "get_incoming_heals")) or 0
    local absorbs = tonumber(safe(player, "get_total_shield")) or 0
    local heal_absorbs = tonumber(safe(player, "get_total_heal_absorbs"))
        or tonumber(safe(player, "get_total_heal_absorb")) or 0
    incoming = math.max(0, incoming)
    heals = math.max(0,heals-heal_absorbs)
    local loss_rate = update_health_velocity(player, now, health, maximum)
    local trend_damage = loss_rate * math.min(window, 1.5)
    -- Native prediction and recent loss describe overlapping damage streams.
    -- Use the larger estimate instead of adding them, then credit absorbs and
    -- at most half the forecast in incoming heals (which have no deadline).
    local expected_damage = math.max(incoming, trend_damage)
    local absorbed = math.min(math.max(0, absorbs), expected_damage)
    local credited_heals = math.min(math.max(0, heals), expected_damage * 0.5)
    local net_expected = math.max(0, expected_damage - absorbed - credited_heals)
    local net_incoming = math.max(0, incoming - math.max(0, absorbs)
        - math.min(math.max(0, heals), incoming * 0.5))
    local net_trend = math.max(0, trend_damage - math.max(0, absorbs)
        - math.min(math.max(0, heals), trend_damage * 0.5))
    local objects=Host.manager("get_all_objects")
    if type(objects)~="table" then objects={} end
    local cast_pressure, targeted_casts, cast_mechanic_score,
        cast_mechanic_name, cast_mechanic_level, learned_pressure, learned_samples =
        hostile_cast_pressure(player, window, maximum, objects)
    local pack_pressure, enemy_count = nearby_pressure(player, objects)
    -- LittleWigs arrives through BigWigs; ExBoss/EXWIND is merged separately.
    local timer_pressure, timer_name, timer_remaining, timer_emphasized,
        timer_mechanic_score, timer_mechanic_level, timer_mechanic_name,
        mechanic_chain,followup_remaining =
        boss_timer_pressure(window, use_boss_timers, maximum)
    local recurring_pressure,recurring_spell,recurring_remaining=
        Intelligence.recurring_pressure(maximum,window)
    local mechanic_score, mechanic_name, mechanic_level = cast_mechanic_score,
        cast_mechanic_name, cast_mechanic_level
    if timer_mechanic_score > mechanic_score then
        mechanic_score, mechanic_name, mechanic_level = timer_mechanic_score,
            timer_mechanic_name or timer_name, timer_mechanic_level
    end
    local incoming_pct = net_incoming / maximum * 100
    local trend_pct = net_trend / maximum * 100
    local projected_pct = math.max(0, current_pct - net_expected / maximum * 100)
    -- Live casts and boss bars can announce the same attack. Their urgency is
    -- complementary evidence, so use the strongest signal once.
    local danger = math.max(incoming_pct, trend_pct)
        + math.max(cast_pressure, timer_pressure, recurring_pressure)
        + pack_pressure
    local ttd = loss_rate > 0 and (health + math.max(0, absorbs)) / loss_rate or math.huge
    return {
        current_pct = current_pct,
        projected_pct = projected_pct,
        incoming_pct = incoming_pct,
        absorb_pct = absorbed / maximum * 100,
        heal_absorb_pct = math.max(0,heal_absorbs) / maximum * 100,
        trend_pct = trend_pct,
        danger = danger,
        time_to_die = ttd,
        targeted_casts = targeted_casts,
        enemy_count = enemy_count,
        timer_pressure = timer_pressure,
        timer_name = timer_name,
        timer_remaining = timer_remaining,
        timer_emphasized = timer_emphasized,
        mechanic_score = mechanic_score,
        mechanic_name = mechanic_name,
        mechanic_level = mechanic_level,
        learned_pressure = learned_pressure,
        learned_samples = learned_samples,
        recurring_pressure = recurring_pressure,
        recurring_spell = recurring_spell,
        recurring_remaining = recurring_remaining,
        mechanic_chain = mechanic_chain or 0,
        followup_remaining = followup_remaining,
    }
end

function M.reset()
    state.time, state.health, state.maximum, state.owner, state.loss_rate = nil, nil, nil, nil, 0
end

return M

