-- Holy Paladin activity recorder. Structured lines are written to scripts_log.
local M = {}
-- This module owns its complete state and filesystem namespace. Keep these
-- identifiers independent from battleground-player and every other plugin.
local ENTITY_ID = "holy_paladin_mplus"
local DEBUGGER_ID = "holy_paladin_mplus.debugger"
local LOG_PATH = ENTITY_ID .. "/session.log"
local lines, run_start, last_snapshot, recent_events, recent_skips = {}, 1, -math.huge, {}, {}
local pending_writes, dropped_writes = {}, 0
local is_enabled = true
local runtime_key, runtime_time = nil, -math.huge
local last_error_key, last_error_time, repeated_errors = nil, -math.huge, 0
local last_event_cleanup = -math.huge
local debug_state = { last_request = "none", last_skip = "none", last_event = "none",
    last_error = "none", last_state = "none" }
local run = { active = false, mode = nil, started = 0, requests = 0,
    success = 0, failed = 0, interrupted = 0, unmatched_events = 0, spells = {},
    outcomes = 0, stabilized = 0, outcome_delta = 0, decision = nil }
M.status = "Starting"

local function clean(value)
    return tostring(value == nil and "-" or value):gsub("[|\r\n]", " ")
end
local function now()
    local ok, value = pcall(core.time)
    return ok and type(value) == "number" and value or 0
end
local function wall_time()
    if type(core.get_local_time) == "function" then
        local ok, t = pcall(core.get_local_time)
        if ok and type(t) == "table" then
            return string.format("%04d-%02d-%02d %02d:%02d:%02d",
                t.year or 0, t.month or 0, t.day or 0,
                t.hour or 0, t.minute or 0, t.second or 0)
        end
    end
    return "game-time-" .. string.format("%.2f", now())
end
local function unit_name(unit)
    if not unit then return "-" end
    local ok, value = pcall(function() return unit:get_name() end)
    if ok and value then return clean(value) end
    local ok_guid, guid = pcall(function() return unit:get_guid() end)
    return ok_guid and clean(guid) or "unknown"
end
local function append(line, console)
    lines[#lines + 1] = line
    if #lines > 5000 then
        table.remove(lines, 1)
        run_start = math.max(1, run_start - 1)
    end
    if console and type(core.log) == "function" then pcall(core.log, line) end
    pending_writes[#pending_writes + 1] = line
    if #pending_writes > 5000 then
        table.remove(pending_writes, 1)
        dropped_writes = dropped_writes + 1
    end
    local function write_line(value)
        assert(type(core.write_log_file) == "function", "core.write_log_file unavailable")
        local result = core.write_log_file(LOG_PATH, value .. "\n")
        assert(result ~= false, "core.write_log_file rejected write")
    end
    local ok, err = pcall(write_line, pending_writes[1])
    -- A failed append may mean a locked disk/file, not a missing file.
    -- Only create after a successful directory listing proves it absent.
    if not ok and type(core.create_log_file) == "function"
        and type(core.read_log_dir) == "function" then
        local listed, entries = pcall(core.read_log_dir, ENTITY_ID)
        if listed and type(entries) == "table" then
            local exists = false
            for _, entry in pairs(entries) do
                if entry == "session.log" or entry == LOG_PATH then exists = true; break end
            end
            if not exists then
                pcall(core.create_log_file, LOG_PATH)
                ok, err = pcall(write_line, pending_writes[1])
            end
        end
    end
    -- Bound recovery work per emission so a storage outage cannot cause an
    -- unbounded flush on a combat tick. Remove only confirmed writes.
    if ok then
        table.remove(pending_writes, 1)
        for _ = 2, 50 do
            if #pending_writes == 0 then break end
            ok, err = pcall(write_line, pending_writes[1])
            if not ok then break end
            table.remove(pending_writes, 1)
        end
    end
    M.status = ok and ("Recording / " .. #lines .. " lines / queued=" .. #pending_writes)
        or ("Write failed / queued=" .. #pending_writes .. " / " .. clean(err))
    if dropped_writes > 0 then M.status = M.status .. " / dropped=" .. dropped_writes end
    return ok
end
local function emit(kind, fields, force)
    if not force and not is_enabled then return false end
    local out = { "[HPMLOG]", kind, "entity=" .. ENTITY_ID,
        "clock=" .. wall_time(), "t=" .. string.format("%.2f", now()) }
    for _, field in ipairs(fields or {}) do out[#out + 1] = clean(field) end
    return append(table.concat(out, " | "), true)
end
local function reset_run(mode)
    run = { active = true, mode = mode, started = now(), requests = 0,
        success = 0, failed = 0, interrupted = 0, unmatched_events = 0, spells = {},
        outcomes = 0, stabilized = 0, outcome_delta = 0, decision = nil }
    run_start = #lines + 1
    last_snapshot = -math.huge
    debug_state.last_state = "run started: " .. clean(mode)
    emit("RUN_START", { "mode=" .. clean(mode), "version=4.70.0" })
end
local function finish_run(reason)
    if not run.active then return end
    local counts = {}
    for id, count in pairs(run.spells) do counts[#counts + 1] = tostring(id) .. ":" .. count end
    table.sort(counts)
    emit("RUN_END", { "mode=" .. clean(run.mode), "reason=" .. clean(reason),
        "duration=" .. string.format("%.1f", now() - run.started),
        "requests=" .. run.requests, "success=" .. run.success,
        "failed=" .. run.failed, "interrupted=" .. run.interrupted,
        "unmatched_events=" .. run.unmatched_events,
        "outcomes=" .. run.outcomes,
        "stabilized=" .. run.stabilized,
        "stabilization_rate=" .. (run.outcomes > 0
            and string.format("%.1f", run.stabilized / run.outcomes * 100) or "unknown"),
        "average_hp_delta=" .. (run.outcomes > 0
            and string.format("%.1f", run.outcome_delta / run.outcomes) or "unknown"),
        "successful_spell_ids=" .. (#counts > 0 and table.concat(counts, ",") or "none") })
    run.active = false
end

pcall(function()
    if type(core.create_log_folder) == "function" then core.create_log_folder(ENTITY_ID) end
end)
emit("SESSION_RESUME", { "version=4.70.0", "debugger=" .. DEBUGGER_ID,
    "enabled=true", "durable=true",
    "previous_session_may_be_incomplete=true", "path=scripts_log/" .. LOG_PATH }, true)

function M.set_enabled(value)
    is_enabled = value == true
    M.status = is_enabled and "Recording enabled" or "Recording paused"
end
function M.runtime_status(status, fields)
    local key = clean(status) .. ":" .. tostring(is_enabled) .. ":" .. table.concat(fields or {}, ":")
    local changed = key ~= runtime_key
    if not changed and (not is_enabled or status ~= "holy_ready" or now() - runtime_time < 60) then return end
    runtime_key, runtime_time = key, now()
    local out = { "status=" .. clean(status), "recording=" .. tostring(is_enabled),
        "reason=" .. (changed and "state_changed" or "heartbeat") }
    for _, value in ipairs(fields or {}) do out[#out + 1] = value end
    -- Minimal runtime/lifecycle evidence remains available when detailed
    -- combat recording is paused. Paused state does not emit heartbeats.
    emit("RUNTIME_STATUS", out, true)
end
function M.run_status()
    if not run.active then return "Waiting for combat" end
    return string.format("%s | %.0fs | %d casts", clean(run.mode), now() - run.started, run.success)
end
function M.note(kind, fields)
    emit(kind, fields)
end
function M.outcome(row)
    row = row or {}
    local spell = row.spell_id
    if spell and core.spell_book and type(core.spell_book.get_spell_name) == "function" then
        local ok, name = pcall(core.spell_book.get_spell_name, spell)
        if ok and name then spell = name end
    end
    if run.active then
        run.outcomes = run.outcomes + 1
        run.outcome_delta = run.outcome_delta + (row.delta or 0)
        if row.stabilized == true then run.stabilized = run.stabilized + 1 end
    end
    emit("OUTCOME", { "spell=" .. clean(spell), "spell_id=" .. clean(row.spell_id),
        "target=" .. unit_name(row.target),
        "hp_before=" .. string.format("%.1f", row.before or 0),
        "hp_after=" .. string.format("%.1f", row.after or 0),
        "hp_delta=" .. string.format("%.1f", row.delta or 0),
        "elapsed=" .. string.format("%.2f", row.elapsed or 0),
        "stabilized=" .. tostring(row.stabilized == true),
        "mode=" .. clean(row.mode),
        "adaptive_offset=" .. string.format("%.1f", row.adaptive or 0) })
end
function M.path() return "scripts_log/" .. LOG_PATH end
function M.identity()
    return { entity = ENTITY_ID, debugger = DEBUGGER_ID, path = "scripts_log/" .. LOG_PATH }
end
function M.flush(limit)
    local maximum = math.max(0, math.min(5000, tonumber(limit) or 5000))
    local written, last_error = 0, nil
    while #pending_writes > 0 and written < maximum do
        local ok, err = pcall(function()
            assert(type(core.write_log_file) == "function", "core.write_log_file unavailable")
            local result = core.write_log_file(LOG_PATH, pending_writes[1] .. "\n")
            assert(result ~= false, "core.write_log_file rejected write")
        end)
        if not ok then last_error = err; break end
        table.remove(pending_writes, 1)
        written = written + 1
    end
    if #pending_writes == 0 then
        M.status = "Recording / " .. #lines .. " lines / queued=0"
    elseif last_error then
        M.status = "Write failed / queued=" .. #pending_writes .. " / " .. clean(last_error)
    end
    if dropped_writes > 0 then M.status = M.status .. " / dropped=" .. dropped_writes end
    return #pending_writes == 0, written
end
function M.lifecycle(event)
    if event ~= "PLAYER_LOGOUT" then return end
    finish_run("logout")
    emit("SESSION_END", { "reason=player_logout", "durable=true" }, true)
    -- Combat emissions keep retry work bounded. Logout is outside the combat
    -- loop, so use the remaining time to drain every recoverable queued line.
    -- A continuing write failure leaves the queue intact rather than deleting
    -- records that were never confirmed on disk.
    M.flush(5000)
end
function M.recent(count)
    local out = {}
    for i = math.max(1, #lines - (count or 120) + 1), #lines do out[#out + 1] = lines[i] end
    return table.concat(out, "\n")
end
function M.current_run()
    local out = {}
    for i = math.max(1, run_start), #lines do out[#out + 1] = lines[i] end
    return table.concat(out, "\n")
end
function M.clear()
    local ok, err = pcall(function()
        if type(core.delete_log_file) == "function" then core.delete_log_file(LOG_PATH) end
        assert(type(core.create_log_file) == "function", "core.create_log_file unavailable")
        core.create_log_file(LOG_PATH)
    end)
    if not ok then M.status = "Clear failed / " .. clean(err); return false end
    lines, run_start, last_snapshot = {}, 1, -math.huge
    pending_writes, dropped_writes = {}, 0
    emit("LOG_CLEARED", { "recording_continues=true" }, true)
    return true
end
function M.reset_debug()
    debug_state = { last_request = "none", last_skip = "none", last_event = "none",
        last_error = "none", last_state = run.active and ("active: " .. clean(run.mode)) or "idle" }
    recent_skips = {}
end
function M.debug_snapshot()
    return { entity = ENTITY_ID, debugger = DEBUGGER_ID,
        log_path = "scripts_log/" .. LOG_PATH,
        active = run.active, mode = run.mode or "none", requests = run.requests,
        success = run.success, failed = run.failed, interrupted = run.interrupted,
        unmatched_events = run.unmatched_events,
        queued_writes = #pending_writes, dropped_writes = dropped_writes,
        last_request = debug_state.last_request, last_skip = debug_state.last_skip,
        last_event = debug_state.last_event, last_error = debug_state.last_error,
        last_state = debug_state.last_state }
end
function M.cast(id, target, cast_type, accepted)
    if run.active then run.requests = run.requests + 1 end
    local spell = id
    if core.spell_book and type(core.spell_book.get_spell_name) == "function" then
        local ok, name = pcall(core.spell_book.get_spell_name, id)
        if ok and name then spell = name end
    end
    if run.active and accepted == true then
        run.decision = clean(spell) .. " -> " .. unit_name(target)
    end
    debug_state.last_request = clean(spell) .. " -> " .. unit_name(target) ..
        " | " .. (accepted == true and "accepted" or "rejected")
    emit(accepted and "REQUEST" or "REJECT", {
        "spell=" .. clean(spell), "id=" .. clean(id), "type=" .. clean(cast_type),
        "target=" .. unit_name(target), "accepted=" .. tostring(accepted == true) })
end
function M.skip(id, target, reason, detail)
    if not run.active or not is_enabled then return end
    local key = clean(id) .. ":" .. clean(reason) .. ":" .. unit_name(target)
    if now() - (recent_skips[key] or -math.huge) < 1.5 then return end
    recent_skips[key] = now()
    debug_state.last_skip = clean(id) .. " -> " .. unit_name(target) ..
        " | " .. clean(reason) .. (detail and (" | " .. clean(detail)) or "")
    emit("SKIP", { "spell_id=" .. clean(id), "target=" .. unit_name(target),
        "reason=" .. clean(reason), "detail=" .. clean(detail) })
end
function M.snapshot(player, rows, mode, profile, hero, pressure, decision, context)
    if not is_enabled then return end
    local combat = false
    local function in_combat(unit)
        if not unit then return false end
        local ok, value = pcall(function() return unit:is_in_combat() end)
        return ok and value == true
    end
    combat = in_combat(player)
    for _, row in ipairs(rows or {}) do combat = combat or in_combat(row.unit) end
    if combat and (not run.active or run.mode ~= mode) then
        if run.active then finish_run("content_changed") end
        reset_run(mode)
    elseif not combat then
        if run.active then finish_run("combat_ended") end
        return
    end
    if now() - last_snapshot < 1 then return end
    last_snapshot = now()
    local roster, worst = {}, nil
    for _, row in ipairs(rows or {}) do
        roster[#roster + 1] = unit_name(row.unit) .. ":" ..
            string.format("%.0f/%.0f", row.hp or 0, row.current or row.hp or 0)
        if not worst or (row.hp or 101) < (worst.hp or 101) then worst = row end
    end
    local mana, max_mana = nil, nil
    pcall(function()
        mana = player:get_power(0)
        max_mana = player:get_max_power(0)
    end)
    local mana_pct = type(mana) == "number" and type(max_mana) == "number" and max_mana > 0
        and string.format("%.1f", mana / max_mana * 100) or "unknown"
    context = context or {}
    debug_state.last_state = clean(mode) .. " | " .. unit_name(worst and worst.unit) ..
        " " .. string.format("%.0f/%.0f", worst and worst.current or 0, worst and worst.hp or 0)
    local worst_focus = nil
    if worst and worst.unit and pressure and pressure.targets then
        local ok_guid, guid = pcall(function() return worst.unit:get_guid() end)
        if ok_guid and guid then worst_focus = pressure.targets[guid] end
    end
    emit("STATE", { "mode=" .. clean(mode), "profile=" .. clean(profile), "hero=" .. clean(hero),
        "beacon=" .. clean(context.beacon),
        "self_hp=" .. string.format("%.1f", context.self_current or 0),
        "self_projected=" .. string.format("%.1f", context.self_projected or 0),
        "self_incoming_pct=" .. string.format("%.1f", context.self_incoming or 0),
        "worst=" .. unit_name(worst and worst.unit),
        "worst_current=" .. string.format("%.1f", worst and worst.current or 0),
        "worst_projected=" .. string.format("%.1f", worst and worst.hp or 0),
        "worst_incoming_pct=" .. string.format("%.1f", worst and worst.incoming or 0),
        "worst_drop_rate=" .. string.format("%.1f", worst and worst.velocity or 0),
        "worst_drop_acceleration=" .. string.format("%.1f", worst and worst.acceleration or 0),
        "focused_by=" .. clean(worst_focus and worst_focus.count or 0),
        "focus_burst=" .. tostring(worst_focus and worst_focus.burst == true),
        "focus_ramp=" .. tostring(worst_focus and worst_focus.ramp == true),
        "focus_age=" .. string.format("%.1f", worst_focus and worst_focus.focus_age or 0),
        "nearby_attackers=" .. clean(worst_focus and worst_focus.nearby_attackers or 0),
        "physical_pressure=" .. clean(worst_focus and worst_focus.physical_attackers or 0),
        "magical_pressure=" .. clean(worst_focus and worst_focus.magic_attackers or 0),
        "hostile_casts=" .. clean(worst_focus and worst_focus.interruptible_casts or 0),
        "mana=" .. mana_pct, "mana_burn=" .. clean(context.mana_burn),
        "mana_15s_forecast=" .. clean(context.mana_forecast),
        "mana_time_to_critical=" .. clean(context.mana_time_to_critical),
        "mana_conserve=" .. clean(context.mana_conserve),
        "group_deficit=" .. clean(context.group_deficit),
        "predicted_group_loss=" .. clean(context.predicted_group_loss),
        "predictive_risk=" .. clean(context.predictive_risk),
        "accelerating_allies=" .. clean(context.accelerating_allies),
        "exposed_target=" .. clean(context.exposed_target),
        "exposed_attackers=" .. clean(context.exposed_attackers),
        "holy_power=" .. clean(context.holy_power),
        "gcd=" .. clean(context.gcd),
        "armament_button=" .. clean(context.armament_button),
        "armament_charges=" .. clean(context.armament_charges),
        "adaptive_offset=" .. clean(context.adaptive_offset),
        "dampening=" .. clean(context.dampening),
        "forecast=" .. clean(context.forecast),
        "cooldown_budget=" .. clean(context.cooldown_budget),
        "manual_yield=" .. string.format("%.2f", context.manual_yield or 0),
        "selected=" .. clean(context.selected), "selected_hp=" .. clean(context.selected_hp),
        "attackers=" .. clean(pressure and pressure.attackers or 0),
        "burst=" .. tostring(pressure and pressure.burst == true),
        "switches=" .. clean(context.switches),
        "decision=" .. clean(run.decision or "Waiting for first accepted cast"),
        "roster=" .. table.concat(roster, ",") })
end
function M.event(event, args, matched_request)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" and event ~= "UNIT_SPELLCAST_FAILED"
        and event ~= "UNIT_SPELLCAST_FAILED_QUIET" and event ~= "UNIT_SPELLCAST_INTERRUPTED" then return end
    if type(args) ~= "table" or args[1] ~= "player" then return end
    local id = tonumber(args[3]) or tonumber(args[4])
    if now() - last_event_cleanup >= 5 then
        for key, time in pairs(recent_events) do
            if now() - time > 10 then recent_events[key] = nil end
        end
        last_event_cleanup = now()
    end
    local key = event .. ":" .. clean(args[2]) .. ":" .. clean(id)
    if now() - (recent_events[key] or -math.huge) < 0.25 then return end
    recent_events[key] = now()
    if run.active and matched_request == true then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            run.success = run.success + 1
            if id then run.spells[id] = (run.spells[id] or 0) + 1 end
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then run.failed = run.failed + 1
        else run.interrupted = run.interrupted + 1 end
    elseif run.active then
        run.unmatched_events = run.unmatched_events + 1
    end
    local spell = id
    if id and core.spell_book and type(core.spell_book.get_spell_name) == "function" then
        local ok, name = pcall(core.spell_book.get_spell_name, id)
        if ok and name then spell = name end
    end
    emit("EVENT", { "event=" .. event, "cast=" .. clean(args[2]),
        "spell=" .. clean(spell), "spell_id=" .. clean(id),
        "origin=" .. (matched_request == true and "plugin_request" or "manual_or_unmatched") })
    debug_state.last_event = clean(event) .. " | " .. clean(spell) .. " | id=" .. clean(id)
end
function M.error(scope, err)
    debug_state.last_error = clean(scope) .. " | " .. clean(err)
    local key = clean(scope) .. ":" .. clean(err)
    if key == last_error_key and now() - last_error_time < 5 then
        repeated_errors = repeated_errors + 1
        return
    end
    emit("ERROR", { "scope=" .. clean(scope), "message=" .. clean(err),
        "repeated_since_last=" .. tostring(key == last_error_key and repeated_errors or 0) }, true)
    last_error_key, last_error_time, repeated_errors = key, now(), 0
end
return M
