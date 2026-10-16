local U,S,C=require("rs_units"),require("rs_spells"),require("rs_settings")
local M={}
function M.choose(rows,plan,pressure)
    -- Redistribution affects players, not the seasonal NPC companion.
    local players={}
    for _,r in ipairs(rows) do if U.call(r.unit,"is_player")==true then players[#players+1]=r end end
    rows=players
    table.sort(rows,function(a,b)return a.hp<b.hp end)
    local profile=require("rs_profiles").get()
    if not C.get("cooldowns") or not C.get("link") then C.link_status="Disabled in menu";return nil end
    if not S.known(S.LINK) then C.link_status="Not learned / not talented";return nil end
    if not S.ready(S.LINK) then C.link_status="Cooldown or spell unavailable";return nil end
    local worst=rows[1]
    if not worst then C.link_status="No reachable allies";return nil end
    local best,bestscore,reason,critical=nil,-math.huge,nil,false
    for _,r in ipairs(rows) do
        local center=r.unit
        local count,injured,donors,total,deficit,predicted_loss=0,0,0,0,0,0
        local covers_worst=false
        for _,v in ipairs(rows) do
            if U.distance(center,v.unit)<=13 then
                count=count+1
                if v.hp<=C.get("link_hp") then injured=injured+1 end
                if v.unit==worst.unit then covers_worst=true end
                if v.unit~=worst.unit and v.current>=worst.current+25 then donors=donors+1 end
                total=total+v.hp
                deficit=deficit+(100-v.hp)
                predicted_loss=predicted_loss+math.max(0,(v.current or v.hp)-v.hp)
            end
        end
        local average=count>0 and total/count or 100
        local gain=covers_worst and average-worst.hp or 0
        -- Link creates no health. A rescue therefore requires enough healthier
        -- players nearby to lift the endangered target by a meaningful amount.
        local rescue=worst.hp<=(profile.pvp and profile.link_hp or profile.emergency)
            and count>=2 and donors>=1 and gain>=12 and average>=40 and covers_worst
        if rescue and profile.pvp then
            rescue=worst.hp<=25 or (pressure and pressure.burst)
                or (pressure and pressure.target==worst.unit and pressure.target_attackers>=2)
        end
        -- Group Link is reserved for a genuinely depleted stacked group with
        -- continuing/projected pressure, rather than three harmless threshold crossings.
        local group=(not profile.pvp or profile.battleground) and count>=3 and injured>=3
            and deficit>=120 and (average<=55 or predicted_loss>=15 or plan.party)
        -- BigWigs alone prepares other healing. Link waits until health prediction
        -- confirms the hit or the stacked party is already injured.
        local planned=not profile.pvp and profile.name=="Mythic+ predictive healing"
            and plan.soon and plan.party and count>=3
            and (predicted_loss>=20 or U.count(rows,85,center,13)>=2)
        local score=(rescue and 150+gain or 0)+(group and 80+deficit/10 or 0)
            +(planned and 60+predicted_loss or 0)+count
        if (rescue or group or planned) and score>bestscore then
            best,bestscore=center,score
            critical=rescue and worst.hp<=20
            reason=rescue and string.format("Rescue: %.0f%% projected redistribution gain",gain)
                or group and string.format("Stacked group: %.0f%% average, %.0f%% deficit",average,deficit)
                or string.format("Confirmed incoming group loss: %.0f%%",predicted_loss)
        end
    end
    C.link_status=reason or "Held: needs redistribution value or confirmed stacked lethal damage"
    return best,critical
end
return M
