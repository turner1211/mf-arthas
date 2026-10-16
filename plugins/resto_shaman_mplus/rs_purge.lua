local U,S,C,P,Mana=require("rs_units"),require("rs_spells"),require("rs_settings"),require("rs_profiles"),require("rs_mana")
local M={}
local last_pvp_purge=-math.huge
local priority_buffs={[17]=80,[1022]=100,[1044]=70}
local enums_ok,enums=pcall(require,"common/enums")
if not enums_ok then enums=nil end
local function field(a,key)
    local ok,value=pcall(function()return a[key]end)
    return ok and value or nil
end
local function magic_buff(unit)
    local buffs=U.call(unit,"get_buffs") or U.call(unit,"get_auras")
    if type(buffs)~="table" then return 0 end
    local count,priority=0,0
    for _,a in pairs(buffs) do
        local kind=field(a,"dispel_name") or field(a,"dispelName") or field(a,"dispel_type") or field(a,"type")
        local bt=enums and enums.buff_type
        local magic=(type(kind)=="string" and string.lower(kind)=="magic") or (bt and bt.MAGIC~=nil and kind==bt.MAGIC)
        if magic then
            count=count+1
            local id=tonumber(field(a,"spell_id") or field(a,"buff_id") or field(a,"id"))
            priority=math.max(priority,priority_buffs[id] or 0)
        end
    end
    return count,priority
end
local function mind_controlled(unit)
    local control=U.call(unit,"get_loss_of_control_info")
    if type(control)=="table" and control.valid~=false then
        local label=string.lower(tostring(control.type or control.control_type or control.name or ""))
        if label:find("mind",1,true) or label:find("charm",1,true) then return true end
    end
    local auras=U.call(unit,"get_debuffs") or U.call(unit,"get_auras")
    if type(auras)=="table" then
        for _,a in pairs(auras) do
            local id=tonumber(field(a,"spell_id") or field(a,"buff_id") or field(a,"id"))
            local name=string.lower(tostring(field(a,"name") or field(a,"debuff_name") or ""))
            if id==605 or name:find("mind control",1,true) then return true end
        end
    end
    return false
end
function M.mind_control(me,profile)
    if not profile.pvp or not C.get("pvp_purge") then return false end
    local spell=S.known(S.PURGE) and S.PURGE or S.known(S.GREATER_PURGE) and S.GREATER_PURGE or nil
    if not spell then return false end
    for _,unit in pairs(U.objects()) do
        if unit~=me and U.valid(unit) and U.call(unit,"is_player")==true
            and (U.call(unit,"is_party_member")==true or U.call(unit,"is_raid_member")==true)
            and U.call(unit,"is_enemy_with",me)==true and U.distance(me,unit)<=30
            and U.visible(me,unit) and mind_controlled(unit) then
            if S.cast(spell,unit,me) then
                C.status="PvP utility: purging Mind Control"
                C.purge_status="Mind-controlled teammate purged; Wind Shear preserved"
                C.pvp_status=C.purge_status
                return true
            end
        end
    end
    return false
end
function M.run(me,rows,profile,pressure)
    local context=require("rs_context").get()
    local pve=(context.dungeon or profile.delve) and C.get("pve_purge")
    local pvp=profile.pvp and C.get("pvp_purge")
    if not pve and not pvp then return false end
    if not rows[1] or rows[1].hp<(pvp and 97 or 95) then return false end
    pressure=pressure or {}
    if pvp and (pressure.burst or pressure.self_burst or pressure.swap) then return false end
    if pvp and core.time()-last_pvp_purge<3 then return false end
    local under_pressure=pvp and (pressure.attackers or 0)>0
    if under_pressure then
        if context.mode~="arena" or (pressure.attackers or 0)>1 or (pressure.self_attackers or 0)>0 then return false end
        for _,row in ipairs(rows)do if (row.velocity or 0)>2 or (row.targeted_casts or 0)>0 then return false end end
    end
    local mana=Mana.plan(me,profile)
    if pvp and (mana.saving or (mana.percent and mana.percent<mana.conserve+10)) then return false end
    if pve and mana.critical_state then
        C.purge_status="PvE Purge held for critical mana"
        return false
    end
    local focused={}
    for _,u in pairs(U.objects()) do
        if U.valid(u) and U.call(u,"is_player")==true and U.call(u,"is_enemy_with",me)~=true then
            local t=U.call(u,"get_target");local g=U.guid(t);if g then focused[g]=(focused[g] or 0)+1 end
        end
    end
    local best,best_score
    for _,enemy in pairs(U.objects()) do
        local buffs,priority=magic_buff(enemy)
        priority=priority or 0
        local correct_type=pvp and U.call(enemy,"is_player")==true or pve and U.call(enemy,"is_player")~=true
        if U.valid(enemy) and correct_type and U.call(enemy,"is_enemy_with",me)==true
            and U.call(enemy,"is_in_combat")==true and U.distance(me,enemy)<=30 and U.visible(me,enemy)
            and buffs>0 and (not under_pressure or (priority>0 and (focused[U.guid(enemy)] or 0)>0)) and (not pvp or P.pvp_call("is_crowd_controlled_weak",enemy,0)~=true) then
            local selected=U.call(me,"get_target")==enemy
            local score=priority+buffs*4+(focused[U.guid(enemy)] or 0)*10+(U.call(enemy,"get_group_role")==1 and 2 or 0)
                +(selected and 8 or 0)
            if not best_score or score>best_score then best,best_score=enemy,score end
        end
    end
    if best then
        local spell=S.known(S.GREATER_PURGE) and S.GREATER_PURGE or S.PURGE
        if S.cast(spell,best,me) then
            if pvp then last_pvp_purge=core.time() end
            C.status=pvp and "PvP utility: removing enemy Magic buff" or "PvE utility: purging enemy Magic buff"
            C.purge_status=pvp and ((focused[U.guid(best)] or 0)>0 and "Safe-window Purge on friendly kill target" or "Safe-window Purge requested")
                or "Safe PvE Purge requested"
            if pvp then C.pvp_status=C.purge_status end
            return true
        end
    end
    C.purge_status=pvp and "No safe PvP Magic buff target" or "No purgeable PvE Magic buff found"
    return false
end
return M
