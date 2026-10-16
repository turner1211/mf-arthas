local Group=require("guardian_group")
local Objects=require("guardian_objects")
local M = {}
local next_scan, cached = 0, nil

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

local function party_victim(player, victim)
    return same(player, victim) or safe(victim, "is_party_member") == true
end

local function read_threat(enemy, player)
    -- The caller is the unit whose threat is measured; the argument is the mob.
    local data = safe(player, "get_threat_situation", enemy)
    if type(data) ~= "table" then return false, 0, 0 end
    return data.is_tanking == true, tonumber(data.status) or 0,
        tonumber(data.threat_percent) or 0
end

local function group_active()
    local challenge_id = core.world and safe(core.world, "get_active_challenge_map_id") or 0
    if tonumber(challenge_id) and tonumber(challenge_id) > 0 then return true end
    local members = safe(core.object_manager, "get_party_members")
    if type(members) == "table" and next(members) ~= nil then return true end
    local frames = safe(core.object_manager, "get_party_frames")
    return type(frames) == "table" and next(frames) ~= nil
end

local function evaluate(player, enemy, scan_range)
    local valid = safe(enemy, "is_valid") == true and safe(enemy, "is_dead") ~= true
        and safe(enemy, "is_unit") == true and safe(player, "can_attack", enemy) == true
        and safe(enemy, "is_in_combat") == true
    if not valid then return nil end
    -- Threat-list participation and target availability are separate checks.
    -- Only explicit client evidence excludes a candidate; missing APIs remain unknown.
    if safe(enemy,"is_pet")==true or safe(enemy,"is_visible")==false then return nil end
    if core.graphics and type(core.graphics.is_line_of_sight)=="function" then
        local ok,los=pcall(core.graphics.is_line_of_sight,player,enemy)
        if ok and los==false then return nil end
    end
    local range=distance(player,enemy)
    if range>scan_range then return nil end
    local victim=safe(enemy,"get_target")
    local attacking_party=party_victim(player,victim)
    local tanking,status,percent=read_threat(enemy,player)
    if not (attacking_party or status>0) or tanking or same(victim,player) then return nil end
    if attacking_party and not same(victim,player) and Group.role(victim)=="TANK" then return nil end
    return {object=enemy,victim=victim,range=range,status=status,
        threat_percent=percent,attacking_party=attacking_party}
end

local function healer_victim(victim)
    return victim~=nil and Group.role(victim)=="HEALER"
end
function M.select(player, current, scan_range, blocked)
    -- Never taunt while solo. Mythic+ counts as grouped even if the roster API
    -- is briefly unavailable during zoning.
    if not group_active() then cached=nil; return nil end
    local now = core.time()
    scan_range = math.max(10, math.min(60, tonumber(scan_range) or 40))
    if now < next_scan then
        cached=cached and evaluate(player,cached.object,scan_range) or nil
        if cached and blocked and blocked(cached.object) then cached=nil end
        return cached
    end
    next_scan = now + 0.20
    local best, best_score = nil, -math.huge
    for _, enemy in pairs(Objects.get()) do
        local candidate=evaluate(player,enemy,scan_range)
        if candidate and not (blocked and blocked(candidate.object)) then
                    local victim,range,status,percent=candidate.victim,candidate.range,
                        candidate.status,candidate.threat_percent
                    local score = 50
                    if healer_victim(victim) then score=score+35 end
                    if victim and safe(victim, "is_party_member") == true then score = score + 50 end
                    if status <= 1 then score = score + 20 end
                    score = score + math.max(0, 100-percent) * 0.1
                    score = score - range * 0.15
                    if same(enemy, current) then score = score + 5 end
                    -- Enemies hitting healers/DPS are the most urgent recovery targets.
                    if victim and not same(victim, player) then score=score+25 end
                    if score > best_score then
                        best_score = score
                        candidate.score=score
                        best=candidate
                    end
        end
    end
    cached = best
    return best
end

-- Status 2 means the tank is only insecurely holding the enemy. Focus damage
-- there before it becomes a taunt emergency, without wasting Growl early.
function M.select_at_risk(player,current,scan_range)
    if not group_active() then return nil end
    scan_range=math.max(10,math.min(60,tonumber(scan_range) or 40))
    local best,best_score=nil,-math.huge
    for _,enemy in pairs(Objects.get()) do
        local valid=safe(enemy,"is_valid")==true and safe(enemy,"is_dead")~=true
            and safe(enemy,"is_unit")==true and safe(player,"can_attack",enemy)==true
            and safe(enemy,"is_in_combat")==true and safe(enemy,"is_pet")~=true
        if valid then
            local range=distance(player,enemy)
            local tanking,status,percent=read_threat(enemy,player)
            if range<=scan_range and tanking and status==2 then
                local score=100-range+(same(enemy,current) and 8 or 0)+math.max(0,100-percent)*0.1
                if score>best_score then best,best_score={object=enemy,range=range,status=status,threat_percent=percent},score end
            end
        end
    end
    return best
end

function M.same(left, right) return same(left, right) end
function M.group_active() return group_active() end
function M.evaluate(player,enemy,range) return evaluate(player,enemy,range or 40) end
function M.reset() next_scan, cached = 0, nil end
return M
