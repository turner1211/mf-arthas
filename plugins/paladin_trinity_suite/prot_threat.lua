local M = {}
local Host = require("prot_host")
local Dungeon = require("prot_dungeon")
local next_scan, cached = 0, nil
local taunt_follow = { object=nil, expires=0, release_after=0 }

local function safe(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end

local function guid(object)
    local value = safe(object, "get_guid")
    return value and tostring(value) or nil
end

local function same(left, right)
    if left == right then return true end
    local a, b = guid(left), guid(right)
    return a and b and a == b or false
end

local function distance(left, right)
    local a, b = safe(left, "get_position"), safe(right, "get_position")
    if not a or not b then return math.huge end
    local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
    return math.sqrt(x*x + y*y + z*z)
end

local party_role

local function party_victim(player, victim)
    if same(player, victim) or safe(victim, "is_party_member") == true
        or party_role(victim)~=nil then return true end
    if victim and Dungeon.is_delve_like() then
        if safe(victim,"is_dead")~=true
            and safe(player,"can_attack",victim)==false then return true end
    end
    return false
end

party_role=function(unit)
    local wanted = guid(unit)
    if not wanted then return nil end
    local members = Host.manager("get_party_members")
    if type(members) ~= "table" then return nil end
    for _, member in pairs(members) do
        local object = member.object
        if (object and guid(object) == wanted) or tostring(member.guid or "") == wanted then
            return string.upper(tostring(member.role or ""))
        end
    end
end

local function read_threat(enemy, player)
    -- The caller is the unit whose threat is measured; the argument is the mob.
    local data = safe(player, "get_threat_situation", enemy)
    if type(data) ~= "table" then return false, 0, 0 end
    return data.is_tanking == true, tonumber(data.status) or 0,
        tonumber(data.threat_percent) or 0
end

function M.select(player, current, scan_range)
    local now = core.time()
    -- Taunt temporarily forces the target and raises us to the current leader's
    -- threat. Keep attacking it briefly so damage establishes lasting aggro.
    if taunt_follow.object and now < taunt_follow.expires
        and safe(taunt_follow.object, "is_valid") == true
        and safe(taunt_follow.object, "is_dead") ~= true then
        local tanking, status, percent = read_threat(taunt_follow.object, player)
        -- Hold long enough to establish damage threat, then release a target
        -- that the threat table confirms is stable so another loose enemy can
        -- be recovered before the original three-second window expires.
        if now < taunt_follow.release_after or not (tanking and status >= 3) then
            return { object=taunt_follow.object, victim=safe(taunt_follow.object, "get_target"),
                range=distance(player, taunt_follow.object), status=status,
                threat_percent=percent, score=200, recovery=true, tanking=tanking }
        end
        taunt_follow.object,taunt_follow.expires,taunt_follow.release_after=nil,0,0
        cached=nil;next_scan=0
    end
    if taunt_follow.object then
        taunt_follow.object,taunt_follow.expires,taunt_follow.release_after=nil,0,0
    end
    if now < next_scan then
        if cached and safe(cached.object, "is_valid") == true
            and safe(cached.object, "is_dead") ~= true then
            local victim = safe(cached.object, "get_target")
            local tanking,status,percent = read_threat(cached.object, player)
            if tanking and status==2 then
                cached.status,cached.threat_percent=status,percent
                cached.needs_taunt=false
                return cached
            elseif tanking or same(victim, player) then cached = nil else return cached end
        end
        return nil
    end
    next_scan = now + 0.20
    scan_range = math.max(10, math.min(60, tonumber(scan_range) or 40))
    local objects = Host.manager("get_all_objects")
    if type(objects) ~= "table" then cached=nil; return nil end
    local best, best_score = nil, -math.huge
    for _, enemy in pairs(objects) do
        local valid = safe(enemy, "is_valid") == true and safe(enemy, "is_dead") ~= true
            and safe(enemy, "is_unit") == true and safe(player, "can_attack", enemy) == true
        if valid then
            local range = distance(player, enemy)
            if range <= scan_range then
                local victim = safe(enemy, "get_target")
                local attacking_party = party_victim(player, victim)
                local tanking, status, percent = read_threat(enemy, player)
                -- Only manage the party's combat. Status > 0 proves the player is
                -- on this mob's threat table; a party victim proves party ownership.
                local party_engaged = attacking_party or status > 0
                local lost = party_engaged and not tanking and (attacking_party or status < 3)
                -- Status 2 means we still own the enemy but another unit is near
                -- the server's melee/ranged target-switch threshold.  Feed damage
                -- into that table before it becomes a taunt emergency.
                local insecure = party_engaged and tanking and status==2
                -- A mob already attacking us does not need a target switch even if
                -- the threat table takes a frame to report is_tanking=true.
                if (lost and not same(victim, player)) or insecure then
                    local score = insecure and 35 or 50
                    local victim_role=party_role(victim)
                    if victim and (safe(victim, "is_party_member") == true or victim_role~=nil) then
                        score = score + 50
                        if victim_role == "HEALER" then score = score + 35 end
                    end
                    if victim and Dungeon.is_delve_like()
                        and safe(player,"can_attack",victim)==false then score=score+40 end
                    if status <= 1 then score = score + 20 end
                    if safe(enemy, "is_casting_spell") == true
                        or safe(enemy, "is_channelling_spell") == true then
                        score = score + 30
                    end
                    score = score + math.max(0, 100-percent) * 0.1
                    score = score - range * 0.15
                    if same(enemy, current) then score = score + 5 end
                    if score > best_score then
                        best_score = score
                        best = { object=enemy, victim=victim, range=range,
                            status=status, threat_percent=percent, score=score,
                            needs_taunt=not insecure }
                    end
                end
            end
        end
    end
    cached = best
    return best
end

function M.same(left, right) return same(left, right) end
function M.is_party_victim(player,victim) return party_victim(player,victim) end
function M.mark_taunted(enemy, seconds)
    taunt_follow.object = enemy
    taunt_follow.expires = core.time() + math.max(1, tonumber(seconds) or 3)
    taunt_follow.release_after = core.time() + 0.75
    cached = nil
    next_scan = 0
end
function M.reset()
    next_scan, cached = 0, nil
    taunt_follow.object,taunt_follow.expires,taunt_follow.release_after=nil,0,0
end
return M
