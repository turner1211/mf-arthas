local U,C,X=require("rs_units"),require("rs_settings"),require("rs_context")
local M={}
local samples={}

function M.percent(me)
    local mana,maxmana=U.call(me,"get_power",0),U.call(me,"get_max_power",0)
    if type(mana)~="number" or type(maxmana)~="number" or maxmana<=0 then return nil end
    return math.max(0,math.min(100,100*mana/maxmana))
end

function M.thresholds(profile)
    local conserve,critical=C.get("mana_conserve"),C.get("mana_critical")
    local mode=X.get().mode
    if mode=="arena" or (profile and profile.pvp and not profile.battleground) then
        conserve,critical=conserve+20,critical+10
    elseif mode=="battleground" or (profile and profile.battleground) then
        conserve,critical=conserve+15,critical+8
    elseif mode=="delve" or (profile and profile.delve) then
        conserve,critical=conserve+5,critical
    elseif mode=="world" then
        conserve,critical=conserve,critical
    elseif mode=="mythic_plus" then
        conserve,critical=conserve+25,critical+5
    elseif mode=="dungeon" then
        conserve=conserve+10
    end
    critical=math.max(5,math.min(50,critical))
    conserve=math.max(critical+5,math.min(70,conserve))
    return conserve,critical
end
function M.allow_full_health_upkeep(me,profile,verified)
    if verified then return true end
    if not C.get("mana_management") then return true end
    local p=M.plan(me,profile)
    return p.state=="normal" and (not p.percent or p.percent>=80)
end

function M.plan(me,profile)
    local pct=M.percent(me)
    local conserve,critical=M.thresholds(profile)
    local mode=X.get().mode
    local guid=(type(U.guid)=="function" and U.guid(me)) or "player"
    local now=(type(core)=="table" and type(core.time)=="function" and core.time()) or 0
    local sample=samples[guid]
    local burn=sample and sample.burn or 0
    local combat=type(U.call)=="function" and U.call(me,"is_in_combat")==true
    local update_sample=not sample
    if pct and combat and sample and now>sample.time then
        local elapsed=now-sample.time
        if elapsed>=1 and elapsed<=6 then
            local instant=math.max(0,(sample.percent-pct)/elapsed)
            burn=burn*0.7+instant*0.3
            update_sample=true
        elseif elapsed>6 then
            -- Loading screens, deaths, and long callback gaps are not a
            -- continuous mana trend. Start a clean measurement window.
            burn=0;update_sample=true
        end
    elseif not combat then burn=0;update_sample=true end
    if pct and update_sample then samples[guid]={percent=pct,time=now,burn=burn} end
    local forecast=pct and math.max(0,pct-burn*15) or nil
    local time_to_critical=pct and burn>0.05 and math.max(0,(pct-critical)/burn) or math.huge
    local horizon=mode=="mythic_plus" and 45 or mode=="arena" and 45
        or mode=="battleground" and 35 or mode=="delve" and 30 or 25
    local state="normal"
    if C.get("mana_management") and pct then
        if pct<=critical then state="critical"
        elseif pct<=conserve or (forecast and forecast<=critical) or time_to_critical<=horizon then state="conserve" end
    end
    local label=pct and string.format("%.0f%%",pct) or "unknown"
    C.mana_status=label.." • "..state.." ("..critical.."/"..conserve..")"
    return {percent=pct,state=state,conserve=conserve,critical=critical,burn=burn,forecast=forecast,
        time_to_critical=time_to_critical,planning_horizon=horizon,
        saving=state~="normal",critical_state=state=="critical"}
end

function M.emergency(rows,profile)
    return rows[1] and rows[1].hp<=profile.emergency
end

function M.group_emergency(rows,profile)
    return M.emergency(rows,profile) or U.count(rows,70)>=2 or U.count(rows,80)>=3
end

function M.allow_expensive(me,rows,profile,free,discount)
    if free or not C.get("mana_management") then return true end
    local p=M.plan(me,profile)
    if p.state=="normal" then return true end
    if M.group_emergency(rows,profile) then return true end
    -- Current Control lowers Chain Heal's cost by 15%; Ascendance lowers it by
    -- 25%. Let those real discounts widen the conserve-state injury window,
    -- while critical mana still requires a free cast or genuine emergency.
    local threshold=(tonumber(discount) or 0)>=0.15 and 90 or 85
    return p.state=="conserve" and U.count(rows,threshold)>=3
end

function M.allow_preparation(me,rows,profile,verified)
    if not C.get("mana_management") then return true end
    local p=M.plan(me,profile)
    if p.state=="normal" then return true end
    return verified and p.state=="conserve" and U.count(rows,95)>=2
end

function M.damage_floor(me,profile)
    local floor=C.get("damage_mana")
    if not C.get("mana_management") then return floor end
    local conserve=M.thresholds(profile)
    return math.max(floor,conserve)
end

function M.reset() samples={} end

return M
