local U,A,S,C,H,T,P,Mana,Rain=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings"),require("rs_healing"),require("rs_talents"),require("rs_profiles"),require("rs_mana"),require("rs_rain")
local M={}
local function predicted(rows,threshold)
    local count=0
    for _,r in ipairs(rows) do
        local current=r.current or r.hp
        if r.hp<=threshold or current-r.hp>=3 then count=count+1 end
    end
    return count
end
local function riptide(target,me)
    return target and not A.present(target,S.RIPTIDE) and S.cast(S.RIPTIDE,target,me)
end
local function ground(me,rows,profile,urgent)
    if not H.ground_worth(rows,profile,urgent) then return false end
    local center=H.ground(rows,true)
    return center and S.cast(S.SURGING,center,me,true)
end
function M.run(me,rows,profile,b,pressure)
    if not C.get("totemic_prediction") or T.hero()~="Totemic" then
        C.totemic_status=T.hero()=="Totemic" and "Prediction disabled" or "Inactive: Totemic not detected"
        return false
    end
    local rain=Rain.window()
    local mana=Mana.plan(me,profile)
    local downpour_need=profile.delve and 1 or 2
    local rain_rows,rain_injured,rain_deficit=Rain.coverage(rows,rain,98)
    if (not mana.saving or Mana.group_emergency(rows,profile))
        and H.downpour_worth(rain_rows,profile,b.party or pressure.burst,rain_deficit)
        and rain.closing and rain_injured>=downpour_need
        and S.cast(S.DOWNPOUR,me,me) then
        C.totemic_status="Using Downpour before the active rain window expires"
        return true
    end
    local incoming=predicted(rows,94)
    if profile.name=="Mythic+ predictive healing" then
        local verified=b.party or incoming>=2
        if not verified then C.totemic_status="M+: monitoring verified party damage";return false end
        if not Mana.allow_preparation(me,rows,profile,b.party or b.soon) then C.totemic_status="M+: conserving mana";return false end
        C.totemic_status=b.party and "M+: preparing for configured BigWigs party damage" or "M+: preparing for predicted group damage"
        if H.spread(me,rows,100,true) then return true end
        if ground(me,rows,profile,b.party or b.soon) then return true end
        if (S.capped(S.STREAM) or b.soon or incoming>=2) and S.cast(S.STREAM,me,me) then return true end
        return false
    end
    if profile.delve then
        local tank=P.delve_companion_tanking(me,rows)
        if not tank then C.totemic_status="Delve: no companion actively tanking";return false end
        local tank_hp=100
        for _,r in ipairs(rows) do if r.unit==tank then tank_hp=r.hp;break end end
        if incoming==0 and tank_hp>97 then C.totemic_status="Delve: companion stable";return false end
        if mana.critical_state and tank_hp>profile.emergency then C.totemic_status="Delve: conserving critical mana";return false end
        C.totemic_status="Delve: preparing around tanking companion"
        if riptide(tank,me) then return true end
        if ground(me,rows,profile,false) then return true end
        if S.cast(S.STREAM,me,me) then return true end
        return false
    end
    if profile.pvp then
        local focused=pressure.target
        local focus_hp=100
        for _,r in ipairs(rows) do if r.unit==focused then focus_hp=r.hp;break end end
        local active=pressure.burst or pressure.swap or pressure.target_attackers>0 or incoming>0
        if not active then C.totemic_status="PvP: monitoring enemy targets and predicted damage";return false end
        if profile.battleground and mana.saving and not pressure.burst and incoming==0 and focus_hp>95 then
            C.totemic_status="Battleground: conserving mana during target-only pressure"
            return false
        end
        if mana.critical_state and not pressure.burst and focus_hp>profile.emergency then C.totemic_status="PvP: conserving critical mana";return false end
        C.totemic_status=profile.battleground and "Battleground: preparing clustered Totemic healing"
            or "Arena: preparing focused Totemic healing"
        if riptide(focused or rows[1].unit,me) then return true end
        -- Arena teams rarely remain stationary long enough for the PvE cluster
        -- proxy. During a verified go, anchor Surging Totem on the pressured ally.
        if not profile.battleground and focused and A.since(S.SURGING)>=12
            and (pressure.burst or focus_hp<=85 or incoming>=2)
            and S.cast(S.SURGING,focused,me,true) then
            C.totemic_status="Arena: Surging Totem on pressured ally"
            return true
        end
        -- Arena placement remains conservative: the normal ground helper requires
        -- two stationary allies. Battleground placement requires its larger cluster.
        if ground(me,rows,profile,pressure.burst) then return true end
        if pressure.burst or incoming>0 or focus_hp<=95 or (profile.battleground and pressure.target_attackers>0) then
            if S.cast(S.STREAM,me,me) then return true end
        end
    end
    return false
end
return M
