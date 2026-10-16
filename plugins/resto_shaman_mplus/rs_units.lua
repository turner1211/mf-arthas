local M = {}
local prediction=require("common/modules/health_prediction")
local history={}
local last_history_prune=-math.huge
local sticky_guid=nil
local sticky_until=-math.huge
local object_snapshot=nil
local snapshot_active=false
function M.begin_object_snapshot()
    snapshot_active=true
    object_snapshot=nil
end
function M.end_object_snapshot()
    snapshot_active=false
    object_snapshot=nil
end
function M.objects()
    if not snapshot_active then return core.object_manager.get_all_objects() or {} end
    if object_snapshot==nil then object_snapshot=core.object_manager.get_all_objects() or {} end
    return object_snapshot
end
function M.call(o, key, ...)
    if not o then return nil end
    local ok, f = pcall(function() return o[key] end)
    if not ok or type(f) ~= "function" then return nil end
    local success, value = pcall(f, o, ...)
    if success then return value end
end
-- Sylvanas exposes cast timestamps on the game-time clock (milliseconds).
-- core.time() is a different, session-relative seconds clock, so mixing them
-- makes late interrupts and predictive totems drift or fire immediately.
function M.cast_timing(u)
    local channel=M.call(u,"is_channelling_spell")==true
    local prefix=channel and "get_active_channel_cast_" or "get_active_spell_cast_"
    local started=tonumber(M.call(u,prefix.."start_time"))
    local finish=tonumber(M.call(u,prefix.."end_time"))
    if not finish then return nil,nil,channel end
    local game_now
    if type(core.game_time)=="function" then
        local ok,value=pcall(core.game_time)
        if ok then game_now=tonumber(value) end
    end
    if game_now then
        if not started or finish<=started then return nil,(finish-game_now)/1000,channel end
        local progress=math.max(0,math.min(100,100*(game_now-started)/(finish-started)))
        return progress,(finish-game_now)/1000,channel
    end
    -- Test/older-host fallback: accept seconds, or normalize millisecond values.
    if finish>100000 then finish=finish/1000;if started then started=started/1000 end end
    local now=core.time()
    if not started or finish<=started then return nil,finish-now,channel end
    return math.max(0,math.min(100,100*(now-started)/(finish-started))),finish-now,channel
end
function M.active_spell_id(u)
    local channel=M.call(u,"is_channelling_spell")==true
    return tonumber(M.call(u,channel and "get_active_channel_spell_id" or "get_active_spell_id"))
end
local function cast_remaining(u)
    local _,remaining=M.cast_timing(u)
    return remaining
end
function M.valid(u)
    return u and M.call(u, "is_valid") == true and M.call(u, "is_dead") == false
        and M.call(u, "is_ghost") ~= true and M.call(u, "is_feign_death") ~= true
end
function M.guid(u) return M.call(u, "get_guid") end
function M.distance(a, b)
    local x, y = M.call(a, "get_position"), M.call(b, "get_position")
    if not x or not y then return math.huge end
    local ok, d = pcall(function() return math.sqrt((x.x-y.x)^2+(x.y-y.y)^2+(x.z-y.z)^2) end)
    return ok and d or math.huge
end
function M.health(u)
    local hp, maximum = M.call(u, "get_health"), M.call(u, "get_max_health")
    if type(hp) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return nil end
    return math.max(0, math.min(100, 100 * hp / maximum))
end
function M.shield_percent(u)
    local shield=M.call(u,"get_total_shield")
    local maximum=M.call(u,"get_max_health")
    if type(shield)~="number" or type(maximum)~="number" or maximum<=0 then return 0 end
    return math.max(0,math.min(100,100*shield/maximum))
end
function M.heal_absorb_percent(u)
    local amount
    for _,method in ipairs({"get_total_heal_absorb","get_total_heal_absorbs","get_heal_absorb"}) do
        amount=M.call(u,method)
        if type(amount)=="number" then break end
    end
    local maximum=M.call(u,"get_max_health")
    if type(amount)~="number" or type(maximum)~="number" or maximum<=0 then return 0 end
    return math.max(0,math.min(100,100*amount/maximum))
end
function M.projected(u)
    local current=M.health(u)
    if not current or not require("rs_settings").get("prediction") then return current end
    local ok,damage=pcall(function() return prediction:get_incoming_damage(u,2) end)
    local maximum=M.call(u,"get_max_health")
    if not ok or type(damage)~="number" or damage<0 or not maximum or maximum<=0 then return current end
    local heals=M.call(u,"get_incoming_heals") or 0
    local damage_pct=100*damage/maximum
    -- A confirmed shield is real effective health, but cap its prediction
    -- credit so stale shield data can never erase an entire queued hit.
    local absorb_credit=math.min(M.shield_percent(u),damage_pct*0.75)
    local net_damage_pct=math.max(0,damage_pct-absorb_credit)
    local heal_pct=math.max(0,100*heals/maximum)
    local heal_absorb_pct=M.heal_absorb_percent(u)
    -- Incoming-heal APIs can include slow, cancelled, or duplicated casts. Credit
    -- at most half of queued damage so they reduce duplicate healing without
    -- concealing a dangerous hit from the triage engine.
    local usable_heal_pct=math.max(0,heal_pct-heal_absorb_pct)
    local credited_heal_pct=math.min(usable_heal_pct,net_damage_pct*0.5)
    local remaining_heal_absorb=math.max(0,heal_absorb_pct-heal_pct)
    local critical=math.max(require("rs_settings").get("emergency") or 35,
        require("rs_settings").get("delve_emergency") or 40,
        require("rs_settings").get("pvp_emergency") or 45)
    -- Never trust incoming heals to hide an already critical target. Above that
    -- line, count confirmed incoming healing so this routine does not duplicate it.
    local projected
    if current<=critical then projected=math.max(0,current-net_damage_pct)
    else projected=math.max(0,math.min(100,current-net_damage_pct+credited_heal_pct)) end
    -- Healing absorbs are future effective-health debt. Account for the part
    -- not already covered by queued direct healing, capped so an uncertain or
    -- stale host value cannot consume the entire triage score.
    projected=math.max(0,projected-math.min(25,remaining_heal_absorb))
    -- Supplement the host's queued-damage estimate with observed health velocity.
    -- This catches periodic damage and fast PvP swaps that are not yet queued.
    local h=history[M.guid(u)]
    if require("rs_settings").get("adaptive_velocity") and h and h.rate and h.rate>=3 and core.time()-h.time<=2 then
        local acceleration_penalty=math.min(10,math.max(0,h.acceleration or 0)*0.35)
        projected=math.min(projected,math.max(0,current-math.min(25,h.rate)-acceleration_penalty))
    end
    return projected
end
function M.visible(me, u)
    if me == u then return true end
    local ok, los = pcall(core.graphics.is_line_of_sight, me, u)
    return ok and los == true
end
function M.is_healing_dummy(me,u)
    if not require("rs_settings").get("training_dummy") or not M.valid(u)
        or not require("rs_settings").get("dummy_healing")
        or M.call(me,"get_target")~=u then return false end
    return require("rs_dummies").is_healing(M,me,u)
end
function M.group(me)
    local rows, seen = {}, {}
    local context=require("rs_context").get()
    local now=core.time()
    -- Object GUIDs change constantly across dungeons, battlegrounds, pets and
    -- reconnects. Bound the prediction cache so an all-day session cannot
    -- retain every unit it has ever seen.
    if now-last_history_prune>=30 then
        for guid,sample in pairs(history) do
            if now-(sample.time or 0)>15 then history[guid]=nil end
        end
        last_history_prune=now
    end
    local companion_seen=false
    local function add(u)
        if not M.valid(u) then return end
        local player=M.call(u,"is_player")==true
        local friend_flag=M.call(u,"is_friend_with",me)
        local enemy_flag=M.call(u,"is_enemy_with",me)
        local attackable=M.call(me,"can_attack",u)
        local friendly=enemy_flag~=true and (friend_flag==true
            or (context.mode=="battleground" and attackable~=true))
        local name=M.call(u,"get_name")
        local npc=M.call(u,"get_npc_id")
        local companion_name=type(name)=="string" and name:lower() or ""
        local known_companion=npc==210759 or npc==242381
            or companion_name:find("valeera",1,true)~=nil
            or companion_name:find("brann",1,true)~=nil
        local companion=context.mode=="delve" and not player and enemy_flag~=true
            and M.call(u,"is_unit")==true and known_companion
        local bg=context.mode=="battleground" and player and friendly
        local healing_dummy=M.is_healing_dummy(me,u)
        if u~=me and not companion and not bg and not healing_dummy
            and M.call(u,"is_party_member")~=true then return end
        if not player and not companion and not healing_dummy then return end
        if M.call(u,"is_enemy_with",me)==true then return end
        if M.distance(me,u)>40 or not M.visible(me,u) then return end
        if context.pvp and require("rs_profiles").pvp_call("is_immune_to_heal",u,0)==true then return end
        local id=M.guid(u)
        local current=M.health(u)
        local prior=id and history[id]
        local now=core.time()
        local rate,acceleration=prior and prior.rate or 0,prior and prior.acceleration or 0
        local dt=prior and now-prior.time or nil
        if prior and current and dt and dt>=0.20 and dt<=3 then
            local falling=math.max(0,(prior.hp-current)/dt)
            local recovered=current>=prior.hp+1
            local retained=recovered and 0 or math.max(0,(prior.rate or 0)-dt*4)
            local raw_acceleration=math.max(0,(falling-(prior.rate or 0))/dt)
            local retained_acceleration=recovered and 0
                or math.max(0,(prior.acceleration or 0)-dt*12)
            rate=math.max(falling,retained)
            acceleration=math.min(30,math.max(raw_acceleration,retained_acceleration))
            history[id]={hp=current,time=now,rate=rate,acceleration=acceleration}
        elseif id and current and (not prior or dt and dt>3) then
            rate,acceleration=0,0
            history[id]={hp=current,time=now,rate=0,acceleration=0}
        end
        local hp=M.projected(u)
        if not id or seen[id] or not hp then return end
        seen[id] = true
        local role=M.call(u,"get_group_role")
        local objective=M.call(u,"is_flag_carrier")==true or M.call(u,"is_objective_carrier")==true
        rows[#rows+1] = {unit=u,hp=hp,current=current,absorb=M.shield_percent(u),
            heal_absorb=M.heal_absorb_percent(u),tank=role==0,healer=role==1,
            companion=companion,healing_dummy=healing_dummy,
            velocity=rate,acceleration=acceleration,objective=objective}
        companion_seen=companion_seen or companion
    end
    add(me)
    add(M.call(me,"get_target"))
    -- Project Sylvanas may allocate a fresh manager result for each request.
    -- One triage pass uses one coherent snapshot for both friendly discovery
    -- and hostile-target prediction, avoiding a duplicate full-world query.
    local objects=M.objects()
    for _, u in pairs(objects) do add(u) end
    local by_guid={}
    for _,row in ipairs(rows) do
        row.attackers=0;row.targeted_casts=0;row.cast_remaining=nil;by_guid[M.guid(row.unit)]=row
    end
    -- Active enemy targeting is a short-horizon predictor available even when
    -- offensive-buff metadata is missing. It only breaks close health ties;
    -- a meaningfully lower-health ally remains first.
    for _,enemy in pairs(objects) do
        if M.valid(enemy) and M.call(enemy,"is_enemy_with",me)==true
            and M.call(enemy,"is_in_combat")==true then
            local target=M.call(enemy,"get_target")
            local row=by_guid[M.guid(target)]
            if row then
                row.attackers=row.attackers+1
                if M.call(enemy,"is_casting_spell")==true or M.call(enemy,"is_channelling_spell")==true then
                    local active_target=M.call(enemy,"get_active_spell_target") or target
                    local remaining=cast_remaining(enemy)
                    if M.guid(active_target)==M.guid(row.unit) and (not remaining or remaining>=0 and remaining<=3) then
                        row.targeted_casts=row.targeted_casts+1
                        if remaining then row.cast_remaining=math.min(row.cast_remaining or math.huge,remaining) end
                    end
                end
            end
        end
    end
    -- Convert only verified, near-impact enemy casts into a small triage bias.
    -- This moves preparation ahead of the health loss without pretending that
    -- an unknown cast has a known damage amount. The live health predictor
    -- remains the dominant signal and the bias is capped at 12 percentage points.
    for _,row in ipairs(rows) do
        local cast_bias=0
        if (row.targeted_casts or 0)>0 and (not row.cast_remaining or row.cast_remaining<=2) then
            cast_bias=math.min(12,4+(row.targeted_casts-1)*3+(row.attackers or 0))
        end
        row.cast_bias=cast_bias
        row.hp=math.max(0,row.hp-cast_bias)
    end
    table.sort(rows,function(a,b)
        if math.abs(a.hp-b.hp)>3 then return a.hp<b.hp end
        local ap=(a.targeted_casts or 0)*4+(a.attackers or 0)*3+(a.objective and 2 or 0)+(a.healer and 1 or 0)
        local bp=(b.targeted_casts or 0)*4+(b.attackers or 0)*3+(b.objective and 2 or 0)+(b.healer and 1 or 0)
        if ap~=bp then return ap>bp end
        return a.hp<b.hp
    end)
    -- Avoid switching direct-heal targets every frame when two allies have
    -- nearly identical health. Meaningfully lower health always wins.
    if #rows>1 and sticky_guid and core.time()<sticky_until then
        for i=2,#rows do
            if M.guid(rows[i].unit)==sticky_guid and rows[i].hp<=rows[1].hp+3
                and (rows[i].attackers or 0)>=(rows[1].attackers or 0)
                and (rows[i].targeted_casts or 0)>=(rows[1].targeted_casts or 0) then
                local sticky=table.remove(rows,i);table.insert(rows,1,sticky);break
            end
        end
    end
    if rows[1] and rows[1].hp<95 then sticky_guid=M.guid(rows[1].unit);sticky_until=core.time()+1.5 end
    if context.mode=="battleground" then
        require("rs_settings").bg_roster="Reachable battleground allies: "..math.max(0,#rows-1)
    else require("rs_settings").bg_roster="Not in a battleground" end
    require("rs_settings").companion=context.mode=="delve" and (companion_seen and "Reachable companion included" or "No recognized reachable companion") or "Not in a delve"
    return rows
end
function M.reset_history() history={};sticky_guid=nil;sticky_until=-math.huge end
function M.count(rows, hp, center, radius)
    local n = 0
    for _, r in ipairs(rows) do
        if r.hp <= hp and (not center or M.distance(center, r.unit) <= radius) then n=n+1 end
    end
    return n
end
function M.cluster(rows, hp, radius, required)
    local best, count = nil, 0
    for _, r in ipairs(rows) do
        if not required or M.distance(r.unit, required) <= radius then
            local n = M.count(rows, hp, r.unit, radius)
            if n > count then best, count = r.unit, n end
        end
    end
    return best, count
end
return M
