local C,X,U=require("rs_settings"),require("rs_context"),require("rs_units")
local M={}
local ok,pvp=pcall(require,"common/utility/pvp_helper")
if not ok then pvp=nil end
local burst_until=-math.huge
local burst_target=nil
local focus_guid=nil
local focus_seen=-math.huge
local swap_guid=nil
local swap_until=-math.huge
local defensives={[642]=true,[1022]=true,[45438]=true,[47585]=true,[22812]=true,[61336]=true,
    [115203]=true,[198589]=true,[31224]=true,[5277]=true,[186265]=true,[871]=true,
    [118038]=true,[48707]=true,[48792]=true,[108416]=true,[104773]=true}
function M.pvp_call(name,...)
    if not pvp or type(pvp[name])~="function" then return nil end
    local success,value=pcall(pvp[name],pvp,...)
    if success then return value end
end
function M.dampening()
    for _,name in ipairs({"get_dampening_percent","get_dampening"}) do
        local value=M.pvp_call(name)
        if type(value)=="number" and value>0 then
            if value>0 and value<=1 then value=value*100 end
            return math.max(0,math.min(100,value))
        end
    end
    -- The optional PvP helper is not populated consistently during arena
    -- preparation, reconnects, or immediately after a UI reload. Fall back to
    -- the player's live aura record so dampening-aware triage does not silently
    -- switch off for the rest of the round.
    local me=core.object_manager and core.object_manager.get_local_player
        and core.object_manager.get_local_player() or nil
    for _,source in ipairs({"get_auras","get_debuffs"}) do
    local list=U.call(me,source)
    if type(list)=="table" then
        for _,a in pairs(list) do
            local ok,name,value=pcall(function()
                local label=a.name or a.buff_name or a.debuff_name or ""
                local points=a.points
                local amount=a.value or a.amount or a.stacks or a.count or a.applications
                    or (type(points)=="table" and points[1])
                return string.lower(tostring(label)),tonumber(amount)
            end)
            if ok and name:find("dampening",1,true) and value then
                if value>0 and value<=1 then value=value*100 end
                return math.max(0,math.min(100,value))
            end
        end
    end
    end
    return 0
end
function M.defensive_active(unit)
    if M.pvp_call("has_defensive_active",unit,500)==true then return true end
    for _,source in ipairs({"get_buffs","get_auras"}) do
    local list=U.call(unit,source)
    if type(list)=="table" then
    for _,a in pairs(list) do
        local ok,id=pcall(function()return tonumber(a.buff_id or a.spell_id or a.id)end)
        if ok and id and defensives[id] then return true end
    end
    end
    end
    return false
end
function M.kick_threat(me)
    if not X.get().pvp then return false end
    for _,enemy in pairs(U.objects()) do
        if U.valid(enemy) and U.call(enemy,"is_player")==true and U.call(enemy,"is_enemy_with",me)==true
            and U.call(enemy,"is_in_combat")==true and U.distance(me,enemy)<=40 then
            if M.pvp_call("has_interrupt_available",enemy,500)==true
                or M.pvp_call("is_interrupt_ready",enemy,500)==true
                or M.pvp_call("can_interrupt",enemy,me,500)==true then return true end
        end
    end
    return false
end
function M.hardcast_risk(me)
    if M.kick_threat(me) then return true end
    if not X.get().pvp then return false end
    local committed=0
    for _,enemy in pairs(U.objects()) do
        if U.valid(enemy) and U.call(enemy,"is_player")==true and U.call(enemy,"is_enemy_with",me)==true
            and U.call(enemy,"is_in_combat")==true and U.guid(U.call(enemy,"get_target"))==U.guid(me)
            and U.distance(me,enemy)<=20 then
            committed=committed+1
            if M.pvp_call("is_melee",enemy)==true then return true end
        end
    end
    -- When class/kick metadata is missing, multiple enemies in melee range
    -- remain strong enough evidence to stop volunteering a long Nature cast.
    return committed>=2
end
function M.get()
    local x=X.get()
    local p={name="General healing",pvp=x.pvp,delve=x.mode=="delve",battleground=x.mode=="battleground",world_pvp=x.mode=="pvp",
        emergency=C.get("emergency"),heal=C.get("heal"),group_count=3,ground_count=3,ground_injured=2}
    if p.delve then
        p.name="Delve survival and companion";p.emergency=C.get("delve_emergency");p.ground_count=1;p.ground_injured=1;p.group_count=2
    elseif p.pvp then
        p.name=p.battleground and "Battleground team healing" or p.world_pvp and "World PvP survival healing" or "Arena / PvP pressure healing"
        p.emergency=C.get("pvp_emergency");p.burst_hp=C.get("pvp_burst");p.link_hp=C.get("pvp_link");p.heal=math.max(p.heal,95)
        p.group_count=p.battleground and 3 or 2;p.ground_count=2
        p.dampening=M.dampening()
        if C.get("dampening_logic") and not p.battleground and not p.world_pvp and p.dampening>=40 then
            p.heal=math.min(99,p.heal+2)
            p.burst_hp=math.min(95,p.burst_hp+5)
            p.emergency=math.min(75,p.emergency+5)
        end
    elseif x.dungeon then p.name=x.mythic_plus and "Mythic+ predictive healing" or "Dungeon healing" end
    return p
end
function M.pressure(me,rows)
    local result={burst=false,self_burst=false,swap=false,target=nil,attackers=0,target_attackers=0,self_attackers=0,
        target_defensive=false,reason="No enemy pressure"}
    if not X.get().pvp then
        burst_until=-math.huge;burst_target=nil;focus_guid=nil;focus_seen=-math.huge
        swap_guid=nil;swap_until=-math.huge
        return result
    end
    local scores,raw_attackers={},{ }
    for _,enemy in pairs(U.objects()) do
        if U.valid(enemy) and U.call(enemy,"is_player")==true and U.call(enemy,"is_enemy_with",me)==true
            and U.call(enemy,"is_in_combat")==true and U.distance(me,enemy)<=60 then
            local target=U.call(enemy,"get_target")
            local guid=U.guid(target)
            for _,r in ipairs(rows) do
                if guid and guid==U.guid(r.unit) then
                    local burst=M.pvp_call("has_burst_active",enemy,500)==true
                    scores[guid]=(scores[guid] or 0)+1+(burst and 2 or 0)
                    raw_attackers[guid]=(raw_attackers[guid] or 0)+1
                    result.attackers=result.attackers+1
                    if r.unit==me then result.self_attackers=result.self_attackers+1 end
                    result.burst=result.burst or burst
                    result.self_burst=result.self_burst or (burst and r.unit==me)
                end
            end
        end
    end
    local high=0
    for _,r in ipairs(rows) do
        local score=(scores[U.guid(r.unit)] or 0)+(r.objective and 2 or 0)
        if score>high then
            high=score;result.target=r.unit;result.target_attackers=raw_attackers[U.guid(r.unit)] or 0
        end
    end
    -- Some hosts do not expose enemy offensive-buff data. Two enemies committed
    -- to a target whose projected health is already falling is still a verified
    -- arena go and must unlock proactive healing cooldowns.
    if result.target then
        for _,r in ipairs(rows) do
            if r.unit==result.target then
                local predicted_loss=math.max(0,(r.current or r.hp)-r.hp)
                local focused=(result.target_attackers>=2 and (r.hp<=C.get("pvp_burst") or predicted_loss>=8
                        or (r.targeted_casts or 0)>=1))
                    or (result.target_attackers>=1 and (r.velocity or 0)>=10)
                if focused and not result.burst then
                    result.burst=true
                    result.self_burst=r.unit==me
                    result.reason=string.format("Fallback arena go: %d attackers, %d casts, %.0f%% projected",
                        result.target_attackers,r.targeted_casts or 0,r.hp)
                elseif result.burst then result.reason="Enemy offensive cooldown detected"
                else result.reason=string.format("Focused pressure: %d attackers",result.target_attackers) end
                break
            end
        end
        result.target_defensive=M.defensive_active(result.target)
    end
    local now=core.time()
    local current_guid=U.guid(result.target)
    -- A real target switch is visible before health loss. Remember the prior
    -- focused ally, but do not call initial target acquisition a swap. This
    -- short window prepares maintenance and suppresses damage; major healing
    -- cooldowns still require burst or actual injury.
    if current_guid and result.target_attackers>=1 then
        if focus_guid and current_guid~=focus_guid and result.target_attackers>=1
            and now-focus_seen<=4 then
            swap_guid=current_guid;swap_until=now+2
        end
        focus_guid=current_guid;focus_seen=now
    elseif now-focus_seen>4 then focus_guid=nil end
    if current_guid and current_guid==swap_guid and now<swap_until then
        result.swap=true
        if not result.burst then result.reason="Enemy target swap detected" end
    elseif now>=swap_until then swap_guid=nil end
    if result.burst then
        burst_until=now+2.5;burst_target=U.guid(result.target)
    elseif result.target and now<burst_until and U.guid(result.target)==burst_target then
        result.burst=true
        result.self_burst=result.target==me
        result.reason="Enemy burst persistence window"
    elseif now>=burst_until then burst_target=nil end
    return result
end
function M.reset_pressure()
    burst_until=-math.huge;burst_target=nil;focus_guid=nil;focus_seen=-math.huge
    swap_guid=nil;swap_until=-math.huge
end
function M.shield_target(me,rows,p,pressure)
    if p.delve then
        local players=0
        for _,r in ipairs(rows) do if not r.companion then players=players+1 end end
        if players==1 then
            for _,r in ipairs(rows) do
                if r.companion then
                    local companion_guid=U.guid(r.unit)
                    for _,enemy in pairs(U.objects()) do
                        if U.valid(enemy) and U.call(enemy,"is_enemy_with",me)==true
                            and U.guid(U.call(enemy,"get_target"))==companion_guid then return r.unit end
                    end
                end
            end
            return me
        end
    end
    if p.pvp then return pressure.target or (rows[1] and rows[1].unit) end
    for _,r in ipairs(rows) do if r.tank and not r.companion then return r.unit end end
end
function M.delve_companion_tanking(me,rows)
    for _,r in ipairs(rows) do
        if r.companion then
            local guid=U.guid(r.unit)
            for _,enemy in pairs(U.objects()) do
                if U.valid(enemy) and U.call(enemy,"is_enemy_with",me)==true
                    and U.guid(U.call(enemy,"get_target"))==guid then return r.unit end
            end
        end
    end
end
return M
