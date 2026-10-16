local U,A,S,C,Mana=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings"),require("rs_mana")
local P=require("rs_profiles")
local T=require("rs_talents")
local M={}
local last_cancel=-math.huge
local function chain_center(rows,hp,radius)
    local center,n=U.cluster(rows,hp,radius)
    if n<3 or not T.has(nil,"Flow of the Tides") then return center,n end
    -- Flow of the Tides rewards starting Chain Heal on an injured ally with
    -- Riptide. Preserve the required cluster size instead of trading bounces
    -- merely to obtain the talent bonus.
    for _,r in ipairs(rows) do
        if r.hp<=hp and A.present(r.unit,S.RIPTIDE)
            and U.count(rows,hp,r.unit,radius)>=n then return r.unit,n end
    end
    return center,n
end
function M.cancel_overheal(me,rows)
    if not C.get("overheal_cancel") or U.call(me,"is_casting_spell")~=true then return false end
    local active=U.call(me,"get_active_spell_id")
    local wave=S.resolve(S.WAVE)
    if active~=S.WAVE and active~=wave then return false end
    local guid=A.request_target(active) or A.request_target(S.WAVE)
    if not guid then return false end
    local target_row=nil
    for _,row in ipairs(rows) do
        if U.guid(row.unit)==guid then
            target_row=row
            if row.hp>=98 and (row.current or row.hp)>=95 and core.time()-last_cancel>=0.3 then
                last_cancel=core.time();S.cancel(me,"redundant heal: target recovered")
                C.status="Cancelling redundant direct heal"
                return true
            end
            break
        end
    end
    local worst=rows[1]
    local emergency=P.get().emergency
    local missing=target_row==nil
    local urgent_swap=target_row and worst and U.guid(worst.unit)~=guid
        and worst.hp<=emergency and target_row.hp>=worst.hp+20
    if (missing or urgent_swap) and core.time()-last_cancel>=0.3 then
        last_cancel=core.time();S.cancel(me,missing and "heal target unavailable" or "emergency heal retarget")
        C.status=missing and "Cancelling heal: target unavailable" or "Cancelling heal for emergency retarget"
        return true
    end
    return false
end
function M.direct(me,rows,free)
    local worst=rows[1]
    if not worst then return false end
    -- Healing Surge was removed in Midnight. Emergency speed comes from the
    -- instant setup above this function (Riptide, Unleash Life and Swiftness),
    -- while direct filler is the efficient Tidal-Waves-aware Healing Wave.
    return S.cast(S.WAVE,worst.unit,me,false,true)
end
function M.filler(me,rows,free,discounted)
    local worst=rows[1]
    if not worst then return false end
    -- A critically low individual takes precedence over aggregate healing, but
    -- do not donate a long cast into clearly committed PvP interrupts unless
    -- Swiftness makes it instant or Grounding protects the cast.
    local profile=P.get()
    if worst.hp<=profile.emergency then
        if profile.pvp and C.get("anti_kick") and not free and A.since(S.GROUNDING)>=2.5
            and P.hardcast_risk(me) then return false end
        return M.direct(me,rows,free)
    end
    local center,n=chain_center(rows,85,12.5)
    local grounding_window=A.since(S.GROUNDING)<2.5
    if profile.pvp and C.get("anti_kick") and not free and not grounding_window
        and not A.present(me,S.UNLEASH) and P.hardcast_risk(me) then
        C.status="Holding hardcast while an enemy interrupt is confirmed ready"
        return false
    end
    local discount=discounted and 0.25 or T.has(nil,"Current Control") and 0.15 or 0
    if center and n>=3 and Mana.allow_expensive(me,rows,profile,free,discount)
        and S.cast(S.CHAIN,center,me,false,true) then return true end
    return M.direct(me,rows,free)
end
function M.empowered(me,rows)
    local swift=A.present(me,S.NATURE) or A.present(me,S.ANCESTRAL)
    if swift or A.present(me,S.UNLEASH) then return M.filler(me,rows,swift) end
    return false
end
function M.spot(me,rows)
    if not rows[1] or rows[1].hp>C.get("spot") then return false end
    local target=rows[1].unit
    local swift=A.present(me,S.NATURE) or A.present(me,S.ANCESTRAL)
    if swift and M.filler(me,rows,true) then return true end
    -- Two confirmed Coalescing Water stacks represent the full 60% initial
    -- Riptide bonus. Weave that instant heal onto an injured uncovered target
    -- before an existing Unleash buff routes back into another filler cast.
    if A.stacks(me,S.COALESCING)>=2 and not A.present(target,S.RIPTIDE)
        and S.cast(S.RIPTIDE,target,me) then return true end
    if A.present(me,S.UNLEASH) and M.filler(me,rows,false) then return true end
    if S.cast(S.UNLEASH,target,me) then return true end
    -- Midnight 12.1 Riptide supplies immediate targeted healing and Swelling
    -- Tides can then extend it when Stormstream is dropped. Do not reverse
    -- that order and spend the totem before the injured target has Riptide.
    if not A.present(target,S.RIPTIDE) and S.cast(S.RIPTIDE,target,me) then return true end
    if S.resolve(S.STREAM)~=S.STREAM and S.cast(S.STREAM,me,me) then return true end
    if S.cast(S.ANCESTRAL,me,me,false,false,true) or S.cast(S.NATURE,me,me,false,false,true) then return true end
    if C.get("movement") and U.call(me,"is_moving") and not A.present(me,S.GRACE)
        and S.cast(S.GRACE,me,me,false,false,true) then return true end
    if require("rs_profiles").get().pvp and C.get("anti_kick")
        and A.since(S.GROUNDING)>=2.5 and P.hardcast_risk(me) then
        C.status="Holding non-emergency Healing Wave for confirmed kick threat"
        return false
    end
    return M.direct(me,rows,false)
end
function M.spread(me,rows,threshold,prepare)
    for _,r in ipairs(rows) do
        if (r.hp<threshold or prepare) and not A.present(r.unit,S.RIPTIDE)
            and S.cast(S.RIPTIDE,r.unit,me) then return true end
    end
    return false
end
function M.riptide_count(rows)
    local count=0
    for _,r in ipairs(rows) do if A.present(r.unit,S.RIPTIDE) then count=count+1 end end
    return count
end
function M.deficit(rows,center,radius)
    local total=0
    for _,r in ipairs(rows) do
        if not center or U.distance(center,r.unit)<=radius then total=total+(100-r.hp) end
    end
    return total
end
function M.predicted_loss(rows)
    local total=0
    for _,r in ipairs(rows) do total=total+math.max(0,(r.current or r.hp)-r.hp) end
    return total
end
function M.ground_worth(rows,profile,urgent)
    if urgent then return true end
    local required=profile.delve and 30 or profile.pvp and 55 or 50
    return M.deficit(rows)>=required or M.predicted_loss(rows)>=20 or U.count(rows,90)>=3
end
function M.downpour_worth(rows,profile,urgent,deficit)
    local required=profile.delve and 25 or profile.pvp and 45 or 60
    return (deficit or M.deficit(rows))>=required
        or U.count(rows,80)>=(profile.delve and 1 or 2) or urgent==true
end
function M.battleground_group(me,rows)
    local center,n=chain_center(rows,90,20)
    local discount=T.has(nil,"Current Control") and 0.15 or 0
    if center and n>=3 and Mana.allow_expensive(me,rows,require("rs_profiles").get(),false,discount) then
        return S.cast(S.CHAIN,center,me,false,true)
    end
    return false
end
function M.mplus_group(me,rows)
    local center,n=chain_center(rows,90,12.5)
    if not center or n<3 then return false end
    local discount=T.has(nil,"Current Control") and 0.15 or 0
    if not Mana.allow_expensive(me,rows,require("rs_profiles").get(),false,discount) then return false end
    return S.cast(S.CHAIN,center,me,false,true)
end
function M.ground(rows,prepare)
    local p=P.get()
    local threshold=prepare and 100 or 95
    local minimum=prepare and p.ground_count or p.ground_injured
    local best,best_deficit,best_count=nil,-1,0
    for _,candidate in ipairs(rows)do
        local center=candidate.unit
        local eligible,total,stationary,deficit=0,0,0,0
        for _,r in ipairs(rows)do
            if U.distance(center,r.unit)<=10 then
                total=total+1
                if r.hp<=threshold then eligible=eligible+1 end
                if U.call(r.unit,"is_moving")==false then stationary=stationary+1 end
                deficit=deficit+math.max(0,100-r.hp)
            end
        end
        if eligible>=minimum and total>=p.ground_count and stationary>=p.ground_count
            and (deficit>best_deficit or (deficit==best_deficit and total>best_count)) then
            best,best_deficit,best_count=center,deficit,total
        end
    end
    return best
end

return M
