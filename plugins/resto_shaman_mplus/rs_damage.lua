local U,A,S,C=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings")
local M={}
local last_cancel=-math.huge
function M.is_training_dummy(me,target)
    if not C.get("training_dummy") or not C.get("dummy_damage") then return false end
    target=target or U.call(me,"get_target")
    return require("rs_dummies").is_damage(U,me,target)
end
function M.cancel_for_healing(me,rows,heal_at,pressure)
    local danger=rows[1] and rows[1].hp<heal_at
    danger=danger or (pressure and (pressure.burst or pressure.self_burst or pressure.swap))
    if U.call(me,"is_casting_spell")~=true then return false end
    local active=U.call(me,"get_active_spell_id")
    local damage=false
    for _,id in ipairs({S.LAVA,S.BOLT,S.LIGHTNING}) do
        if active==id or active==S.resolve(id) then damage=true;break end
    end
    if not damage then return false end
    local unsafe_target=false
    if pressure then
        local target_guid=A.request_target(active)
        if target_guid then
            local P=require("rs_profiles")
            for _,enemy in pairs(U.objects())do
                if U.guid(enemy)==target_guid and (not U.valid(enemy)
                    or P.pvp_call("is_crowd_controlled_weak",enemy,0)==true
                    or P.pvp_call("is_damage_immune",enemy,0)==true) then unsafe_target=true;break end
            end
        end
    end
    if not danger and not unsafe_target then return false end
    -- Yield this update after cancellation; wait for native cast state to clear
    -- before the normal healing scheduler sends its next spell.
    if core.time()-last_cancel>=0.25 then
        last_cancel=core.time()
        S.cancel(me,unsafe_target and "damage target became controlled, dead or immune" or "damage cast yielded to healing")
        C.status=unsafe_target and "Stopping damage: target controlled, dead or immune" or "Stopping damage cast to heal"
    end
    return true
end
-- Called only after the healing scheduler explicitly determines no healing is needed.
function M.run(me,plan)
    local dummy=M.is_training_dummy(me)
    if C.evading or not C.get("damage")
        or (U.call(me,"is_in_combat")~=true and not dummy) then return false end
    local profile=require("rs_profiles").get()
    if profile.pvp and not C.get("pvp_damage") then return false end
    if profile.battleground and #U.group(me)<2 then
        C.status="Battleground roster incomplete; damage held"
        return false
    end
    if plan.prepare or plan.party or plan.personal or plan.soon then return false end
    -- Reserve instant-heal cooldowns and throughput windows for healing.
    if A.present(me,S.NATURE) or A.present(me,S.ANCESTRAL) or A.present(me,S.ASCEND) then return false end
    local mana,maxmana=U.call(me,"get_power",0),U.call(me,"get_max_power",0)
    local Mana=require("rs_mana")
    local reserve=Mana.damage_floor(me,profile)
    if profile.pvp and Mana.plan(me,profile).saving then C.status="PvP damage held: preserving mana";return false end
    if type(mana)~="number" or type(maxmana)~="number" or maxmana<=0
        or 100*mana/maxmana<reserve then return false end
    local all=U.objects()
    local function healthy(u)
        local hp=U.projected(u)
        return hp~=nil and hp>=math.max(C.get("damage_hp"),C.get("heal"))
    end
    if not healthy(me) then return false end
    for _,u in pairs(all) do
        if U.valid(u) and U.call(u,"is_player")==true and U.call(u,"is_party_member")==true
            and not healthy(u) then return false end
    end
    local target=U.call(me,"get_target")
    if not U.valid(target) or U.call(target,"is_enemy_with",me)~=true
        or (U.call(target,"is_in_combat")~=true and not dummy) or U.distance(me,target)>40
        or not U.visible(me,target) then return false end
    if profile.delve then
        for _,r in ipairs(U.group(me)) do if not healthy(r.unit) then return false end end
    end
    if profile.pvp then
        local P=require("rs_profiles")
        if P.pvp_call("is_crowd_controlled_weak",target,0)~=false or P.pvp_call("is_damage_immune",target,0)~=false then return false end
        local pressure=P.pressure(me,U.group(me))
        if pressure.burst or pressure.swap then return false end
    end
    local flame,remaining=A.own_debuff(target,S.FLAME,me)
    local instant=A.present(me,S.LAVA_SURGE)
    -- Spend the instant proc before paying for a nonessential early DoT refresh.
    if profile.pvp and flame and instant and S.cast(S.LAVA,target,me) then C.status="PvP damage: instant Lava Burst";return true end
    if not flame or (remaining and remaining<=4.5) then
        if S.cast(S.FLAME,target,me) then C.status="Damage: Flame Shock";return true end
    end
    -- Do not spend mana maintaining Surging Totem during damage downtime.
    -- The healing scheduler places it only when group deficit or predicted loss justifies the cost.
    if profile.pvp and C.get("pvp_damage_instant_only") then return false end
    if profile.pvp and require("rs_profiles").hardcast_risk(me) then
        C.status="PvP damage held: hardcast interrupt risk";return false
    end
    if S.cast(S.LAVA,target,me,false,not instant) then C.status="Damage: Lava Burst";return true end
    local count,unsafe=1,false
    local seen={[tostring(U.guid(target))]=true}
    for _,u in pairs(all) do
        if U.valid(u) and U.call(u,"is_enemy_with",me)==true and U.distance(target,u)<=12.5 then
            if U.call(u,"is_in_combat")~=true and not M.is_training_dummy(me,u) then unsafe=true end
            local guid=U.guid(u)
            if guid and not seen[tostring(guid)] then seen[tostring(guid)]=true;count=count+1 end
        end
    end
    local dummy_aoe=dummy and C.get("dummy_aoe")
    if not profile.pvp and C.get("damage_aoe") and (count>=3 or dummy_aoe) and not unsafe and S.cast(S.LIGHTNING,target,me,false,true) then
        C.status="Damage: Chain Lightning";return true
    end
    if S.cast(S.BOLT,target,me,false,true) then C.status="Damage: Lightning Bolt";return true end
    return false
end
return M
