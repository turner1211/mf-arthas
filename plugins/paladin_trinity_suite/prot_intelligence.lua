local M = {}
local Host = require("prot_host")

local INTERRUPTS = {
    [96231]=true, [1766]=true, [6552]=true, [2139]=true, [57994]=true,
    [106839]=true, [116705]=true, [47528]=true, [183752]=true,
    [351338]=true, [147362]=true, [187707]=true, [15487]=true,
    [78675]=true, [31935]=true,
}
local learned, recent_interrupts = {}, {}
local current_context = "world"

local function local_player()
    return Host.manager("get_local_player")
end

local function guid(object)
    if not object or type(object.get_guid) ~= "function" then return nil end
    local ok, value = pcall(object.get_guid, object)
    return ok and value and tostring(value) or nil
end

local function party_guid_set()
    local result = {}
    local player = local_player()
    local player_guid = guid(player)
    if player_guid then result[player_guid] = true end
    do
        local members = Host.manager("get_party_members")
        if type(members) == "table" then
            for _, member in pairs(members) do
                local member_guid = guid(member.object)
                if member_guid then result[member_guid] = true end
            end
        end
    end
    return result
end

function M.set_context(value)
    current_context = tostring(value or "world")
end

function M.reset_transient()
    recent_interrupts = {}
end

function M.sync_context()
    local challenge=tonumber(Host.static(core and core.world,"get_active_challenge_map_id"))
    if challenge and challenge>0 then
        current_context="challenge:"..tostring(challenge)
        return current_context
    end
    for _,method_name in ipairs({"get_instance_id","get_map_id","get_map_id_raw"}) do
        local method=core[method_name]
        if type(method)=="function" then
            local ok,value=pcall(method)
            if ok and tonumber(value) and tonumber(value)>0 then
                current_context="map:"..tostring(math.floor(tonumber(value)))
                return current_context
            end
        end
    end
    local kind,name="world",""
    if type(core.get_instance_type)=="function" then
        local ok,value=pcall(core.get_instance_type);if ok then kind=tostring(value or kind) end
    end
    if type(core.get_instance_name)=="function" then
        local ok,value=pcall(core.get_instance_name);if ok then name=tostring(value or "") end
    end
    current_context=string.lower(kind..":"..name):gsub("[^%w:]","")
    if current_context==":" then current_context="world" end
    return current_context
end

function M.healer_mana()
    local members = Host.manager("get_party_members")
    if type(members) ~= "table" then return nil end
    for _, member in pairs(members) do
        if string.upper(tostring(member.role or "")) == "HEALER" and member.object then
            local object = member.object
            local power_ok, power = pcall(object.get_power, object, 0)
            local max_ok, maximum = false, nil
            if object.get_max_power then max_ok, maximum = pcall(object.get_max_power, object, 0) end
            if power_ok and max_ok and tonumber(maximum) and tonumber(maximum) > 0 then
                return math.max(0, math.min(100, tonumber(power) * 100 / tonumber(maximum)))
            end
        end
    end
    return nil
end

function M.group_readiness()
    local result = { total=1, alive=1, online=1, nearby=1, far=0,
        dead=0, offline=0, injured=0, critical=0, healer_injured=false,
        healer_busy=false, ready=true }
    local members = Host.manager("get_party_members")
    if type(members) ~= "table" then return result end
    local player=local_player()
    local player_position
    if player and player.get_position then
        local position_ok,value=pcall(player.get_position,player)
        if position_ok then player_position=value end
    end
    for _, member in pairs(members) do
        result.total = result.total + 1
        if member.is_online ~= false then result.online = result.online + 1
        else result.offline = result.offline + 1 end
        local dead = member.object and member.object.is_dead
            and select(2, pcall(member.object.is_dead, member.object)) == true
        if member.is_online ~= false and not dead then result.alive = result.alive + 1
        elseif member.is_online ~= false and dead then result.dead = result.dead + 1 end
        if string.upper(tostring(member.role or ""))=="HEALER" and member.object
            and member.is_online~=false and not dead then
            local casting=member.object.is_casting_spell
                and select(2,pcall(member.object.is_casting_spell,member.object))==true
            local channeling=member.object.is_channelling_spell
                and select(2,pcall(member.object.is_channelling_spell,member.object))==true
            result.healer_busy=casting or channeling
        end
        if member.object and member.is_online~=false and not dead
            and type(member.object.get_health)=="function"
            and type(member.object.get_max_health)=="function" then
            local health_ok,health=pcall(member.object.get_health,member.object)
            local maximum_ok,maximum=pcall(member.object.get_max_health,member.object)
            if health_ok and maximum_ok and tonumber(maximum) and tonumber(maximum)>0 then
                local percent=(tonumber(health) or 0)*100/tonumber(maximum)
                if percent<70 then result.injured=result.injured+1 end
                if percent<45 then result.critical=result.critical+1 end
                if string.upper(tostring(member.role or ""))=="HEALER" and percent<70 then
                    result.healer_injured=true
                end
            end
        end
        local nearby=true
        if player_position and member.object and member.object.get_position then
            local position_ok,position=pcall(member.object.get_position,member.object)
            if position_ok and position and type(position.x)=="number" then
                local dx,dy,dz=position.x-player_position.x,position.y-player_position.y,
                    position.z-player_position.z
                nearby=dx*dx+dy*dy+dz*dz<=60*60
            end
        end
        if nearby then result.nearby=result.nearby+1 else result.far=result.far+1 end
    end
    result.ready = result.online == result.total and result.alive == result.total
        and result.nearby==result.total and not result.healer_busy
        and result.critical==0 and not result.healer_injured
    return result
end

function M.defensive_readiness()
    if not core.spell_book or type(core.spell_book.is_spell_known)~="function"
        or type(core.spell_book.get_spell_cooldown)~="function" then
        return {available=nil,short=false,major=false,known=0}
    end
    local function ready(id)
        local is_known=Host.static(core and core.spell_book,"is_spell_known",id)
        if is_known~=true then return false,false end
        if core.spell_book.get_spell_charge and core.spell_book.get_spell_charge_max then
            local charge=Host.static(core and core.spell_book,"get_spell_charge",id)
            local maximum=Host.static(core and core.spell_book,"get_spell_charge_max",id)
            if (tonumber(maximum) or 0)>0
                and (tonumber(charge) or 0)>0 then return true,true end
        end
        local cooldown=Host.static(core and core.spell_book,"get_spell_cooldown",id)
        return (tonumber(cooldown) or math.huge)<=0.15,true
    end
    local divine,known_divine=ready(403876)
    local ardent,known_ardent=ready(31850)
    local guardian,known_guardian=ready(86659)
    local sentinel,known_sentinel=ready(389539)
    local wings,known_wings=ready(31884)
    local short=divine or ardent
    local burst=sentinel or wings
    local known=(known_divine and 1 or 0)+(known_ardent and 1 or 0)
        +(known_guardian and 1 or 0)+(known_sentinel and 1 or 0)+(known_wings and 1 or 0)
    local available=nil
    if known>0 then available=short or guardian or burst end
    return {available=available,short=short,
        major=guardian,burst=burst,known=known}
end

function M.should_defer_interrupt(target)
    local key = guid(target)
    if not key then return false end
    local until_time = recent_interrupts[key]
    if not until_time then return false end
    if core.time() >= until_time then recent_interrupts[key] = nil; return false end
    return true
end

function M.learned_pressure(spell_id, maximum_health)
    local row = learned[current_context .. ":" .. tostring(tonumber(spell_id) or 0)]
    if not row or row.samples < 3 or not maximum_health or maximum_health <= 0 then return 0, 0 end
    return math.min(35, row.average * 100 / maximum_health), row.samples
end

function M.recurring_pressure(maximum_health, window)
    if not maximum_health or maximum_health<=0 then return 0,nil,nil end
    local now,best,best_id,best_in=core.time(),0,nil,nil
    for key,row in pairs(learned) do
        local spell_id=tonumber(key:match(":(%d+)$"))
        if key:sub(1,#current_context+1)==current_context..":" and spell_id~=6603
            and (row.interval_samples or 0)>=3 and (row.interval or 0)>=0.3 then
            local jitter=(row.interval_deviation or 0)/row.interval
            local remaining=(row.last_seen or 0)+row.interval-now
            local tolerance=math.max(0.25,(row.interval_deviation or 0)*2)
            if jitter<=0.25 and remaining>=-tolerance
                and remaining<=math.max(1,tonumber(window) or 2) then
                local pressure=math.min(35,(row.average or 0)*100/maximum_health)
                if pressure>best then best,best_id,best_in=pressure,spell_id,math.max(0,remaining) end
            end
        end
    end
    return best,best_id,best_in
end

function M.summary()
    local spells, samples = 0, 0
    for _, row in pairs(learned) do spells, samples = spells + 1, samples + row.samples end
    return { spells=spells, samples=samples, healer_mana=M.healer_mana() }
end

function M.on_spell_cast(data)
    if type(data) ~= "table" or not INTERRUPTS[tonumber(data.spell_id)] then return end
    local player = local_player()
    if guid(data.caster) == guid(player) then return end
    local parties = party_guid_set()
    if parties[guid(data.caster)] then
        local target_guid = guid(data.target)
        if target_guid then recent_interrupts[target_guid] = core.time() + 0.22 end
    end
end

function M.on_event(event, args)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or type(args) ~= "table" then return end
    M.sync_context()
    local subevent = tostring(args[2] or "")
    local player = local_player()
    if tostring(args[8] or "") ~= tostring(guid(player) or "") then return end
    local spell_id, amount
    if subevent == "SWING_DAMAGE" then spell_id, amount = 6603, tonumber(args[12])
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE"
        or subevent == "RANGE_DAMAGE" or subevent == "DAMAGE_SHIELD" then
        spell_id, amount = tonumber(args[12]), tonumber(args[15])
    elseif subevent=="SPELL_MISSED" and tostring(args[15])=="ABSORB" then
        -- A fully absorbed spell has no SPELL_DAMAGE row. Learn the prevented
        -- amount here; partial absorbs remain represented by their damage row
        -- and are deliberately not added again.
        spell_id,amount=tonumber(args[12]),tonumber(args[17])
    end
    if not spell_id or not amount or amount <= 0 then return end
    -- Ignore friendly fire/self-damage and cap outliers so one overkill or
    -- logging anomaly cannot poison the estimate for the rest of the run.
    if party_guid_set()[tostring(args[4] or "")] then return end
    local maximum = player and player.get_max_health
        and select(2, pcall(player.get_max_health, player)) or nil
    if tonumber(maximum) and tonumber(maximum) > 0 then
        amount = math.min(amount, tonumber(maximum) * 1.5)
    end
    local key = current_context .. ":" .. tostring(spell_id)
    local row = learned[key] or { samples=0, average=amount, peak=amount }
    local event_time=core.time()
    if row.last_seen then
        local interval=event_time-row.last_seen
        if interval>=0.3 and interval<=30 then
            if row.interval then
                local difference=math.abs(interval-row.interval)
                row.interval_deviation=(row.interval_deviation or difference)*0.7+difference*0.3
                row.interval=row.interval*0.7+interval*0.3
            else
                row.interval,row.interval_deviation=interval,0
            end
            row.interval_samples=math.min(50,(row.interval_samples or 0)+1)
        end
    end
    row.samples = math.min(200, row.samples + 1)
    row.average = row.average * 0.75 + amount * 0.25
    row.peak = math.max(row.peak or 0, amount)
    row.last_seen = event_time
    learned[key] = row
end

return M
