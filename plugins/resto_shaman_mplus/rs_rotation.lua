local U,A,S,C,B = require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings"),require("rs_bigwigs")
local M={}
local T=require("rs_talents")
local D=require("rs_damage")
local H=require("rs_healing")
local L=require("rs_link")
local P=require("rs_profiles")
local PvP=require("rs_pvp")
local Dispel=require("rs_dispel")
local Totemic=require("rs_totemic")
local Interrupt=require("rs_interrupts")
local Trinkets=require("rs_trinkets")
local Ghost=require("rs_ghost_wolf")
local Mana=require("rs_mana")
local Projection=require("rs_projection")
local Purge=require("rs_purge")
local requested_major=-math.huge
local requested_major_id=nil
local was_combat=false
local pvp_settle_until=-math.huge
local shield_lock={guid=nil,unit=nil,since=-math.huge,candidate=nil,candidate_since=-math.huge}
local function stable_pvp_shield(candidate,rows,profile,pressure)
    if A.since(S.EARTH)>100000 then
        shield_lock={guid=nil,unit=nil,since=-math.huge,candidate=nil,candidate_since=-math.huge}
    end
    if not profile.pvp or not candidate then
        shield_lock={guid=nil,unit=nil,since=-math.huge,candidate=nil,candidate_since=-math.huge}
        return candidate
    end
    local now,guid=core.time(),U.guid(candidate)
    local candidate_hp=100
    for _,r in ipairs(rows) do if r.unit==candidate then candidate_hp=r.hp or 100;break end end
    local urgent=candidate_hp<=profile.effective_emergency or pressure.burst or pressure.swap
        or (pressure.target_attackers or 0)>=2
    -- Prefer direct aura/latch evidence when a confirmed shield is already on
    -- the team. This remains reliable if pressure tracking rebuilt its state.
    if not urgent and A.since(S.EARTH)<12 then
        for _,r in ipairs(rows) do
            if A.present(r.unit,S.EARTH) then return r.unit end
        end
    end
    if not shield_lock.guid or not U.valid(shield_lock.unit) then
        shield_lock={guid=guid,unit=candidate,since=now,candidate=guid,candidate_since=now}
        return candidate
    end
    if guid==shield_lock.guid then return shield_lock.unit end
    if not urgent and now-shield_lock.since<12 then return shield_lock.unit end
    if shield_lock.candidate~=guid then
        shield_lock.candidate=guid;shield_lock.candidate_since=now
        if not urgent then return shield_lock.unit end
    end
    if urgent or now-shield_lock.candidate_since>=1.5 then
        shield_lock.guid=guid;shield_lock.unit=candidate;shield_lock.since=now
    end
    return shield_lock.unit
end
local function major(id,target,me,ground,rescue)
    local now=core.time()
    -- Accepted ground-target input is not proof that the game cast the spell.
    -- If its pending request was cleared by a failure event, release the shared
    -- spacing immediately so another lifesaving cooldown can be attempted.
    if requested_major_id and now-requested_major<2
        and not A.pending[requested_major_id] and A.since(requested_major_id)>2 then
        requested_major=-math.huge;requested_major_id=nil
    end
    -- Cover separate damage events. These windows match the abilities' useful
    -- durations; only a critical Spirit Link redistribution may overlap them.
    local active=A.since(S.TIDE)<10 or A.since(S.LINK)<6 or A.since(S.ASCEND)<15
    if now-requested_major<2 or (active and not rescue) then
        if id==S.LINK then C.link_status="Waiting for healing cooldown spacing" end
        return false
    end
    if S.cast(id,target,me,ground) then requested_major=now;requested_major_id=S.resolve(id);return true end
    return false
end
function M.run(me)
    local rows=U.group(me)
    local profile=P.get()
    local context=require("rs_context").get()
    local mana=Mana.plan(me,profile)
    C.profile=profile.name
    if #rows==0 then C.status="No reachable party health data"; return end
    if profile.delve then
        for i,r in ipairs(rows) do
            if r.unit==me and r.hp<=profile.emergency then table.remove(rows,i);table.insert(rows,1,r);break end
        end
    end
    local pressure=P.pressure(me,rows)
    local danger_emergency=profile.emergency
    local worst_row=rows[1]
    local ally_defensive=worst_row and P.defensive_active(worst_row.unit) or false
    if not profile.pvp then pressure.target_defensive=ally_defensive end
    if profile.pvp then
        if (pressure.target_attackers or 0)>=3 then danger_emergency=math.max(danger_emergency,60)
        elseif (pressure.target_attackers or 0)>=2 then danger_emergency=math.max(danger_emergency,55) end
        if worst_row and (worst_row.velocity or 0)>=30 then danger_emergency=math.max(danger_emergency,60) end
    end
    profile.effective_emergency=danger_emergency
    local shield=P.shield_target(me,rows,profile,pressure)
    shield=stable_pvp_shield(shield,rows,profile,pressure)
    -- Open-world PvE uses Earth Shield on the player and deliberately refreshes
    -- it every 60 seconds. Battleground targeting keeps its pressure-based logic.
    if context.mode=="world" then shield=me end
    local water_allowed=shield~=me or T.has(S.ORBIT,"Elemental Orbit") or not S.known(S.EARTH)
    local function maintain_shield()
        if not shield then return false end
        local since=A.since(S.EARTH)
        -- The aura list can lag behind spell events during login, reloads and
        -- zone changes. A confirmed cast is authoritative during that gap.
        if context.mode=="world" and shield==me then
            if since<60 then return false end
            return S.cast(S.EARTH,shield,me)
        end
        if since<3 then return false end
        return not A.present(shield,S.EARTH) and S.cast(S.EARTH,shield,me)
    end
    local function maintain_long_buffs()
        if S.known(S.EARTHLIVING) and not A.present(me,S.EARTHLIVING)
            and S.cast(S.EARTHLIVING,me,me) then return true end
        if S.known(S.SKYFURY) and not A.present(me,S.SKYFURY)
            and S.cast(S.SKYFURY,me,me) then return true end
        return false
    end
    local worst, hp=rows[1].unit, rows[1].hp
    local loss_rate=worst_row and ((worst_row.velocity or 0)
        +math.min(15,(worst_row.acceleration or 0)*0.5)) or 0
    local time_to_emergency=loss_rate>0 and math.max(0,(hp-danger_emergency)/loss_rate) or math.huge
    -- Begin the response early enough for an efficient Healing Wave to finish.
    -- Movement shortens the usable horizon because only instant setup is then
    -- reliable. A verified hostile cast near impact also opens preparation.
    local response_horizon=U.call(me,"is_moving")==true and 1.2 or 2.2
    local cast_threat=worst_row and (worst_row.targeted_casts or 0)>0
        and (not worst_row.cast_remaining or worst_row.cast_remaining<=response_horizon)
        and hp<=math.max(danger_emergency+15,80)
    local imminent_emergency=hp>danger_emergency
        and ((loss_rate>=5 and time_to_emergency<=response_horizon) or cast_threat)
    profile.imminent_emergency=imminent_emergency
    profile.time_to_emergency=time_to_emergency
    local danger_now=hp<=danger_emergency or imminent_emergency
    local b=B.scan()
    local selfhp=U.projected(me)
    local heal_at=b.party and 99 or profile.heal
    -- In arena, leave small deficits for efficient HoTs/totems once mana is
    -- pressured. Burst and emergency triage still use their dedicated gates.
    if profile.pvp and not profile.battleground then
        if mana.critical_state then heal_at=math.min(heal_at,90)
        elseif mana.saving then heal_at=math.min(heal_at,93) end
    end
    C.heal_threshold=heal_at
    require("rs_telemetry").snapshot(me,rows,profile,b,pressure)
    if PvP.yield_control(me,rows,profile,pressure) then return end
    if H.cancel_overheal(me,rows) then return end
    local wolf_danger=hp<heal_at or b.prepare or b.party or b.personal or pressure.burst or pressure.self_burst or pressure.swap
        or (profile.pvp and not profile.battleground and pressure.attackers>0)
    if wolf_danger then Ghost.leave_for_healing(me) end
    if D.cancel_for_healing(me,rows,heal_at,profile.pvp and pressure or nil) then return end
    local combat=U.call(me,"is_in_combat")==true
    for _,r in ipairs(rows) do combat=combat or U.call(r.unit,"is_in_combat")==true end
    local healing_dummy=false
    for _,r in ipairs(rows) do healing_dummy=healing_dummy or r.healing_dummy==true end
    local dummy_test=D.is_training_dummy(me)
    combat=combat or dummy_test or healing_dummy
    if was_combat and not combat and profile.pvp then
        pvp_settle_until=core.time()+1.5
        P.reset_pressure()
    end
    was_combat=combat
    C.status=healing_dummy and "Healing dummy test"
        or (dummy_test and "Damage dummy test" or (combat and "Healing" or "Waiting for combat"))
    if not combat then
        if profile.pvp and core.time()<pvp_settle_until then
            C.status="Arena round transition; holding maintenance"
            C.link_status="Waiting for combat"
            return
        end
        C.link_status="Waiting for combat"
        if hp<heal_at then
            C.status="Healing between pulls"
            if H.spot(me,rows) or H.spread(me,rows,heal_at,false) or H.filler(me,rows,false) then return end
            return
        end
        if water_allowed and not A.present(me,S.WATER) and S.cast(S.WATER,me,me) then return end
        if maintain_shield() then return end
        if maintain_long_buffs() then return end
        if T.has(S.ORBIT,"Elemental Orbit") and not A.present(me,S.EARTH) then S.cast(S.EARTH,me,me) end
        if Ghost.run(me,hp>=heal_at,profile,pressure) then return end
        return
    end
    -- Astral Shift cannot be activated while stunned. A verified enemy offensive
    -- cooldown aimed at the healer is therefore a predictive trigger, even at
    -- high health; waiting for the hit can remove the opportunity to wall it.
    -- Unverified multi-attacker pressure keeps the conservative health gate.
    if C.get("defensives") and selfhp and (selfhp<=C.get("personal") or b.personal
        or (profile.pvp and pressure.self_burst)
        or (profile.pvp and pressure.swap and pressure.target==me and (pressure.self_attackers or 0)>=2)
        or ((pressure.self_attackers or 0)>=2 and selfhp<=85)) then
        if not A.present(me,S.SHIFT) and S.cast(S.SHIFT,me,me,false,false,true) then return end
    end
    if profile.pvp and selfhp
        and (selfhp<=30 or (pressure.self_burst and selfhp<=55)
            or ((pressure.self_attackers or 0)>=4 and selfhp<=60)
            or ((pressure.self_attackers or 0)>=2 and selfhp<=45))
        and (not A.present(me,S.SHIFT) or selfhp<=15)
        and S.cast(S.BURROW,me,me,false,false,true) then
        C.status="PvP defense: Burrow"
        return
    elseif profile.pvp and selfhp and A.present(me,S.SHIFT) and selfhp>15
        and (selfhp<=30 or pressure.self_burst or (pressure.self_attackers or 0)>=2) then
        C.pvp_status="Holding Burrow while Astral Shift is active"
    end
    -- A PvP crowd-control break and a configured personal defensive must be
    -- available even when loss of control prevents normal spell casting.
    if Trinkets.run(me,rows,profile,b,"defensive",pressure) then return end
    if S.control_blocked(me) then
        C.status="Loss of control; waiting to resume casting"
        return
    end
    -- Swiftness is already paid for and exists to make the next heal immediate.
    -- Consume it before spending a Healing Tide/Ascendance global, especially
    -- during the fast focused damage seen in battleground logs.
    if danger_now and (A.present(me,S.NATURE) or A.present(me,S.ANCESTRAL)) then
        if H.filler(me,rows,true) then
            C.status="Emergency instant heal: consuming Swiftness"
            return
        end
    end
    -- Remove explicitly lethal effects after consuming an already-active
    -- instant rescue, but before spending major cooldowns healing through the
    -- effect. At extreme health, preserve the next global for immediate life
    -- support instead of assuming the cleanse will land in time.
    if danger_now and hp>math.max(10,danger_emergency*0.5)
        and Dispel.run(me,rows,profile,true) then return end
    local shift_unavailable=not S.known(S.SHIFT) or not S.ready(S.SHIFT)
    local burrow_unavailable=not profile.pvp or not S.known(S.BURROW) or not S.ready(S.BURROW)
    local planned_elemental=b.personal and selfhp and shift_unavailable
    local critical_elemental=selfhp and selfhp<=25
        and (burrow_unavailable or A.present(me,S.SHIFT) or selfhp<=15)
    if C.get("elemental") and (planned_elemental or critical_elemental)
        and A.since(S.ELEMENTAL)>30 and T.has(S.BOND,"Primordial Bond")
        and S.cast(S.ELEMENTAL,me,me) then
        C.status=planned_elemental and "Predictive defense: Primordial Bond Earth Elemental"
            or "Emergency defense: Primordial Bond Earth Elemental"
        return
    end
    local injured=U.count(rows,C.get("group"))
    local link_center,rescue=L.choose(rows,b,pressure)
    if link_center then
        if major(S.LINK,link_center,me,true,rescue) then C.link_status="Cast requested";return end
        if C.link_status~="Waiting for healing cooldown spacing" then C.link_status="Triggered; waiting for GCD/cast, range or accepted input" end
    end
    if C.get("cooldowns") and danger_now and (not ally_defensive or hp<=danger_emergency) then
        local minimum=(profile.delve or profile.pvp) and 1 or 2
        if U.distance(me,worst)<=20 and U.count(rows,70,me,20)>=minimum and major(S.ASCEND,me,me) then return end
        if (profile.delve or profile.pvp) and major(S.TIDE,me,me) then return end
    end
    if danger_now and ally_defensive and hp>danger_emergency then
        C.status="Predictive healing: ally defensive active; preserving major cooldown"
    end
    if not danger_now and Dispel.run(me,rows,profile,false) then return end
    -- Live arena mistake data favors spending saves before the pressured target reaches execute range.
    if profile.pvp and pressure.burst and hp<=profile.burst_hp and C.get("cooldowns")
        and (not pressure.target_defensive or hp<=danger_emergency) then
        if major(S.TIDE,me,me) then return end
        if U.distance(me,worst)<=20 and major(S.ASCEND,me,me) then return end
    end
    -- Never spend a preparation GCD while somebody needs emergency healing.
    if danger_now then
        if imminent_emergency then C.status="Predictive emergency: health falling toward critical" end
        if H.empowered(me,rows) then return end
        if S.cast(S.UNLEASH,worst,me) then return end
        if not A.present(worst,S.RIPTIDE) and S.cast(S.RIPTIDE,worst,me) then return end
        if S.resolve(S.STREAM)~=S.STREAM and S.cast(S.STREAM,me,me) then return end
        if S.cast(S.ANCESTRAL,me,me,false,false,true)
            or S.cast(S.NATURE,me,me,false,false,true) then return end
        local protected_cast=A.since(S.GROUNDING)<2.5 or not P.hardcast_risk(me)
        if protected_cast and H.direct(me,rows,false) then return end
    end
    -- Spirit Link redistributes health but does not finish recovery. Convert its
    -- protected six-second window into efficient group healing immediately.
    if A.since(S.LINK)<6 and hp<95 then
        if S.cast(S.STREAM,me,me) then return end
        if profile.battleground and H.battleground_group(me,rows) then return end
        if H.filler(me,rows,false) then return end
    end
    if Trinkets.run(me,rows,profile,b,"healing",pressure) then return end
    if profile.pvp and Purge.mind_control(me,profile) then return end
    -- Rotate anti-control tools. Tremor answers fear/sleep/charm, Grounding can
    -- absorb a high-value targeted CC cast, and Wind Shear remains available
    -- for the next cast. Emergency healing and personal saves stay above all.
    if profile.pvp and PvP.tremor(me,rows) then return end
    if profile.pvp and PvP.grounding(me,rows) then return end
    if Interrupt.run(me,profile.pvp) then return end
    if profile.pvp and PvP.counterstrike(me,rows,pressure) then return end
    if C.get("cooldowns") and (injured>=profile.group_count or b.soon or (b.party and U.count(rows,90)>=2)
        or (pressure.burst and hp<=C.get("group") and (not pressure.target_defensive or hp<=danger_emergency))) then
        if major(S.TIDE,me,me) then return end
        if U.count(rows,85,me,20)>=profile.group_count and major(S.ASCEND,me,me) then return end
    end
    -- Spend the active Ascendance window on its enhanced healing kit. Personal
    -- saves, dispels, interrupts, Tremor and Grounding remain above this block.
    if A.present(me,S.ASCEND) and hp<heal_at then
        if T.hero()=="Totemic" and S.cast(S.STREAM,me,me) then return end
        if H.filler(me,rows,false,true) then return end
    end
    -- Peeling is instant control used after emergency saves but before routine throughput.
    if profile.pvp and PvP.peel(me,rows,pressure,selfhp) then return end
    if profile.pvp and PvP.lasso(me,rows,pressure) then return end
    -- A safe Hex reduces incoming damage and future mana demand. It belongs
    -- ahead of routine topping, but never ahead of burst or low-health triage.
    if profile.pvp and PvP.control(me,rows,pressure) then return end
    if Projection.run(me,rows,profile,pressure) then return end
    if Totemic.run(me,rows,profile,b,pressure) then return end
    local predicted_targets=0
    for _,r in ipairs(rows) do if (r.current or r.hp)-r.hp>=3 then predicted_targets=predicted_targets+1 end end
    -- An emphasized BigWigs bar can be an unknown mechanic. Only configured
    -- party-damage bars or measured damage on multiple allies may spend mana.
    local verified_prepare=b.party or predicted_targets>=2
    local needed=hp<heal_at or verified_prepare
    if not needed then
        if maintain_shield() then return end
        if profile.name=="Mythic+ predictive healing" and Mana.allow_preparation(me,rows,profile,b.party or b.soon) then
            if Mana.allow_full_health_upkeep(me,profile,b.party or b.soon) and H.spread(me,rows,100,true) then return end
            if T.has(nil,"Swelling Tides") and H.riptide_count(rows)>=2
                and S.cast(S.STREAM,me,me) then return end
            local upkeep=H.ground(rows,true)
            if upkeep and H.ground_worth(rows,profile,b.party or b.soon) then
                if S.known(S.SURGING) and S.cast(S.SURGING,upkeep,me,true) then return end
                if not S.known(S.SURGING) and S.cast(S.RAIN,upkeep,me,true) then return end
            end
            if S.capped(S.STREAM) and S.cast(S.STREAM,me,me) then return end
        end
        if profile.delve and Mana.allow_preparation(me,rows,profile,false) then
            local companion=P.delve_companion_tanking(me,rows)
            if companion then
                if Mana.allow_full_health_upkeep(me,profile,false) and not A.present(companion,S.RIPTIDE)
                    and S.cast(S.RIPTIDE,companion,me) then return end
                if S.cast(S.STREAM,me,me) then return end
                local upkeep=H.ground(rows,true)
                if upkeep and H.ground_worth(rows,profile,false) then
                    if S.known(S.SURGING) and S.cast(S.SURGING,upkeep,me,true) then return end
                    if not S.known(S.SURGING) and S.cast(S.RAIN,upkeep,me,true) then return end
                end
            end
        end
        if profile.pvp and Mana.allow_preparation(me,rows,profile,pressure.burst) then
            if H.spread(me,rows,100,true) then return end
            if T.has(nil,"Swelling Tides") and H.riptide_count(rows)>=2
                and S.cast(S.STREAM,me,me) then return end
            -- Rain Dance makes Totemic's defining field instant and 60% cheaper.
            -- Keep it active in safe PvP downtime without repeatedly firing the
            -- live relocation override during the same 25-second window.
            if T.hero()=="Totemic" and T.has(290250,"Rain Dance") and S.known(S.SURGING)
                and A.since(S.SURGING)>=25 and Mana.allow_full_health_upkeep(me,profile,pressure.burst) then
                local upkeep=H.ground(rows,true)
                if upkeep and S.cast(S.SURGING,upkeep,me,true) then return end
            end
            if S.capped(S.STREAM) and S.cast(S.STREAM,me,me) then return end
        end
        if profile.pvp and PvP.control(me,rows,pressure) then return end
        if Purge.run(me,rows,profile,pressure) then return end
        if Trinkets.run(me,rows,profile,b,"offensive",pressure) then return end
        if T.has(S.ORBIT,"Elemental Orbit") and not A.present(me,S.EARTH) and S.cast(S.EARTH,me,me) then return end
        if water_allowed and not A.present(me,S.WATER) and S.cast(S.WATER,me,me) then return end
        if maintain_long_buffs() then return end
        if Ghost.run(me,not b.soon and not b.party and not b.personal and not pressure.burst and not pressure.self_burst,profile,pressure) then return end
        D.run(me,b)
        return
    end
    -- Prepare the buffs the current M+ priority expects before predictable party damage.
    if profile.name=="Mythic+ predictive healing" and verified_prepare and Mana.allow_preparation(me,rows,profile,b.party or b.soon) then
        if H.spread(me,rows,100,true) then return end
        local prep_center=H.ground(rows,true)
        if prep_center then
            if S.known(S.SURGING) and S.cast(S.SURGING,prep_center,me,true) then return end
            if not S.known(S.SURGING) and S.cast(S.RAIN,prep_center,me,true) then return end
        end
        if S.capped(S.STREAM) and S.cast(S.STREAM,me,me) then return end
        if S.cast(S.UNLEASH,worst,me) then return end
    end
    -- Earth Shield is exceptionally efficient in current M+ logs; refresh it during safe pressure.
    if profile.name=="Mythic+ predictive healing" and hp>C.get("spot") and maintain_shield() then return end
    if hp<heal_at and H.empowered(me,rows) then return end
    local shield_safe=not (profile.pvp and mana.critical_state)
        or pressure.burst or hp<90
    if (profile.pvp or profile.delve) and hp>danger_emergency and shield_safe and maintain_shield() then return end
    if H.spot(me,rows) then return end
    if profile.pvp then
        if H.spread(me,rows,heal_at,false) or S.cast(S.STREAM,me,me) then return end
        if profile.battleground and H.battleground_group(me,rows) then return end
    end
    if S.capped(S.RIPTIDE) and H.spread(me,rows,heal_at,verified_prepare) then return end
    if S.capped(S.STREAM) and S.cast(S.STREAM,me,me) then return end
    if T.hero()=="Farseer" and hp<heal_at then
        if S.cast(S.UNLEASH,worst,me) or S.cast(S.ANCESTRAL,me,me,false,false,true) then return end
    end
    if C.get("movement") and hp<heal_at and U.call(me,"is_moving") and not A.present(me,S.GRACE)
        and S.cast(S.GRACE,me,me,false,false,true) then return end
    local center=(Mana.allow_preparation(me,rows,profile,b.party or b.soon) or Mana.group_emergency(rows,profile))
        and H.ground_worth(rows,profile,b.party or b.soon) and H.ground(rows,verified_prepare) or nil
    if center then
        if S.known(S.SURGING) then
            if S.cast(S.SURGING,center,me,true) then return end
        elseif S.cast(S.RAIN,center,me,true,not (profile.pvp and T.has(290250,"Rain Dance"))) then return end
    end
    if S.cast(S.STREAM,me,me) then return end
    -- Downpour acts at the existing rain location. Prefer the closing portion of
    -- a confirmed Surging window; urgent group damage can still spend it sooner.
    local rain=require("rs_rain").window()
    local rain_rows,downpour_targets,rain_deficit=require("rs_rain").coverage(rows,rain,98)
    if (not mana.saving or Mana.group_emergency(rows,profile))
        and H.downpour_worth(rain_rows,profile,b.party or b.soon,rain_deficit)
        and downpour_targets>=(profile.delve and 1 or 2)
        and rain.active and (rain.closing or U.count(rain_rows,80)>=2 or b.soon)
        and S.cast(S.DOWNPOUR,me,me) then return end
    if profile.name=="Mythic+ predictive healing" and H.mplus_group(me,rows) then return end
    if H.spread(me,rows,heal_at,verified_prepare) then return end
    if hp<heal_at and S.cast(S.UNLEASH,worst,me) then return end
    if hp<heal_at and S.cast(S.NATURE,me,me,false,false,true) then return end
    if hp<heal_at and H.filler(me,rows,false) then return end
    -- Maintenance follows urgent throughput. Unknown aura state is backed by confirmed events.
    maintain_shield()
end
return M
