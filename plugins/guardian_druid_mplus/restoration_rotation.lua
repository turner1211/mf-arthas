local U=require("druid_shared")
local S={rejuvenation=774,lifebloom=33763,regrowth=8936,swiftmend=18562,wild_growth=48438,tranquility=740,
    ironbark=102342,natures_swiftness=132158,cenarion=102351,grove=102693,flourish=197721,incarnation=33891,
    innervate=29166,remove=88423,rebirth=20484,mark=1126,moonfire=8921,sunfire=93402,wrath=5176,
    barkskin=22812,solar_beam=78675,cyclone=33786,bash=5211,roots=339,soothe=2908,bear=5487,renewal=108238,thorns=467,
    ancient=473909,blossom=473919,mass_bloom=474149,hibernate=2637,prowl=5215}
local A={rejuvenation=774,germination=155777,germination_talent=155675,lifebloom=33763,regrowth=8936,soul=114108,
    moonfire=164812,sunfire=164815,ancient=473909,natures_swiftness=132158}
local M={spells=S}
local function act(key,id,target,delay,off) return {key=key,id=id,target=target,delay=delay,off=off} end
local function due(unit,id,harmful,p,seconds)
    local active,remain=U.aura(unit,id,harmful,p);return not active or remain and remain<seconds
end
function M.decide(c)
    local p,cfg=c.player,c.settings;local lowest=c.lowest or p;local hp=c.lowest_hp or c.hp
    if c.pvp and cfg.defensives and c.hp<=25 and U.available(S.renewal) then return act("Renewal",S.renewal,p,nil,true) end
    if cfg.defensives and (c.hp<=cfg.emergency or c.pvp and c.pre_defensive) and U.available(S.barkskin) and not U.aura(p,S.barkskin)
        then return act("Barkskin",S.barkskin,p,nil,true) end
    if c.pvp and cfg.defensives and c.self_melee_pressure and c.hp<=(c.self_burst and 80 or 60) and U.available(S.bear) and not U.aura(p,S.bear) then return act("Bear Form",S.bear,p) end
    if cfg.utility and c.dispel and (c.dispel_urgent or hp>70) and U.available(S.remove) then return act("Nature's Cure",S.remove,c.dispel,1.5) end
    if cfg.utility and c.enrage and U.available(S.soothe) then return act("Soothe",S.soothe,c.enrage,1.5) end
    if c.pvp and cfg.utility and c.melee_pressure and c.focused_ally and U.available(S.thorns)
        and not U.aura(c.focused_ally,S.thorns) then return act("Thorns focused ally",S.thorns,c.focused_ally) end
    if c.dead and c.safe_rebirth and U.available(S.rebirth) then return act("Rebirth",S.rebirth,c.dead,8) end
    if not c.combat and not U.aura(p,S.mark) then return act("Mark of the Wild",S.mark,p) end
    if c.pvp and c.focused_ally then lowest=c.focused_ally;hp=U.hp(lowest) or hp end
    if not c.combat and c.pvp and (c.mode=="arena" or c.mode=="battleground") then
        if U.aura(p,S.prowl) then return nil end
        if due(lowest,A.rejuvenation,false,p,4) then return act("Rejuvenation gate preparation",S.rejuvenation,lowest) end
        if U.known(A.germination_talent) and due(lowest,A.germination,false,p,4) then
            return act("Germination gate preparation",S.rejuvenation,lowest)
        end
        if U.available(S.prowl) then return act("Prowl opener",S.prowl,p) end
    end
    if U.aura(p,A.natures_swiftness)
        and not (c.pvp and cfg.cooldowns and c.team_danger and hp<=72 and U.available(S.ancient))
        and U.available(S.regrowth) then
        return act("Nature's Swiftness Regrowth",S.regrowth,lowest)
    end
    if c.pvp and (c.enemy_burst and hp<=82 or c.incoming_cc and lowest~=p) and cfg.cooldowns and U.available(S.ironbark)
        and (not c.focused_ally_reduced or hp<=45)
        and not U.aura(lowest,S.ironbark) then return act(c.incoming_cc and "Ironbark before incoming crowd control" or "Predictive Ironbark",S.ironbark,lowest,nil,true) end
    if c.pvp and U.aura(p,A.ancient) then
        if c.injured>=3 and U.available(S.mass_bloom) then return act("Mass Blooming spread pressure",S.mass_bloom,lowest) end
        if hp<96 and U.available(S.blossom) then return act("Blossom Burst focused ally",S.blossom,lowest) end
    end
    if c.pvp and cfg.cooldowns and c.team_danger and hp<=72 and U.available(S.ancient) then
        if U.available(S.natures_swiftness) and not U.aura(p,A.natures_swiftness) then
            return act("Nature's Swiftness for Ancient of Lore",S.natures_swiftness,p,nil,true)
        end
        return act("Ancient of Lore pressure",S.ancient,p)
    end
    if hp<=cfg.emergency or c.pvp and c.enemy_burst and hp<=70 then
        if cfg.cooldowns and U.available(S.natures_swiftness) and not U.aura(p,A.natures_swiftness) then
            return act("Nature's Swiftness",S.natures_swiftness,p,nil,true)
        end
        if cfg.cooldowns and (not c.focused_ally_reduced or hp<=45) and U.available(S.ironbark) then
            return act("Ironbark",S.ironbark,lowest,nil,true)
        end
        if U.available(S.swiftmend) and not due(lowest,A.rejuvenation,false,p,0) then return act("Swiftmend",S.swiftmend,lowest) end
        return act("Emergency Regrowth",S.regrowth,lowest)
    end
    if c.pvp and hp<90 and U.available(S.cenarion) then return act("Cenarion Ward",S.cenarion,lowest) end
    if c.pvp and c.team_danger and hp<=85 and U.available(S.grove) then return act("Grove Guardian",S.grove,lowest) end
    if cfg.cooldowns and (c.mana or 100)<=75 and U.available(S.innervate) then return act("Innervate",S.innervate,p) end
    local bloom_target=c.pvp and lowest or p
    if due(bloom_target,A.lifebloom,false,p,4.5) then return act("Lifebloom",S.lifebloom,bloom_target) end
    if c.pvp and U.aura(p,A.soul) and (hp<95 or c.team_danger or c.enemy_burst) and U.available(S.rejuvenation) then
        return act("Soul of the Forest Rejuvenation",S.rejuvenation,lowest)
    end
    if (hp<cfg.hp or c.pvp and c.enemy_burst) and due(lowest,A.rejuvenation,false,p,4) then return act("Rejuvenation",S.rejuvenation,lowest) end
    if c.pvp and hp<95 and U.known(A.germination_talent) and due(lowest,A.germination,false,p,4) then return act("Germination",S.rejuvenation,lowest) end
    if c.pvp and c.combat and c.group_safe and not c.team_danger and (c.mana or 100)>30 then
        for _,row in ipairs(c.members or {}) do
            if due(row.unit,A.rejuvenation,false,p,4) then return act("Rejuvenation pre-HoT",S.rejuvenation,row.unit) end
        end
    end
    if c.pvp and hp<cfg.hp and U.aura(lowest,A.rejuvenation,false,p) and U.available(S.swiftmend) then return act("Swiftmend for Soul of the Forest",S.swiftmend,lowest) end
    if not c.pvp and c.injured>=2 and U.aura(p,A.soul) and U.available(S.wild_growth) then
        return act("Soul of the Forest Wild Growth",S.wild_growth,lowest)
    end
    if c.injured>=3 and U.available(S.wild_growth) then return act("Wild Growth",S.wild_growth,lowest) end
    if c.pvp and c.team_danger and c.injured>=2 and cfg.cooldowns then
        if U.available(S.flourish) then return act("PvP Flourish",S.flourish,p) end
        if U.available(S.tranquility) then return act("Tranquility bridge",S.tranquility,p,8) end
        if U.available(S.incarnation) then return act("Tree of Life pressure",S.incarnation,p) end
    end
    if cfg.cooldowns and c.injured>=4 then
        if U.available(S.flourish) then return act("Flourish",S.flourish,p) end
        if U.available(S.tranquility) then return act("Tranquility",S.tranquility,p,8) end
        if U.available(S.incarnation) then return act("Incarnation",S.incarnation,p) end
    end
    if c.pvp and c.group_safe and not c.team_danger and not U.aura(p,S.mark) and U.available(S.mark) then return act("Restore Mark of the Wild",S.mark,p) end
    if hp<cfg.hp-15 then return act("Regrowth",S.regrowth,lowest) end
    local t=c.target
    if c.pvp and cfg.utility and c.hibernate_control and U.available(S.hibernate) then
        return act("Hibernate animal-form attacker",S.hibernate,c.hibernate_control,1.5)
    end
    if c.pvp and cfg.utility and c.defensive_control and c.team_danger and U.available(S.cyclone) then return act("Defensive Cyclone",S.cyclone,c.defensive_control,2) end
    if c.pvp and cfg.utility and c.stop_healing_control and c.safe_to_cast and U.available(S.cyclone) then return act("Cyclone low target to deny healing",S.cyclone,c.stop_healing_control,2) end
    if c.pvp and cfg.utility and c.root_open and U.available(S.roots) then return act("Entangling Roots peel",S.roots,c.melee_pressure,2) end
    if c.pvp and cfg.utility and c.control and c.control_open and (not c.enemy_healer_cc or c.enemy_healer_cc_expiring)
        and c.group_safe and c.safe_to_cast then
        if c.stun_open and U.distance(p,c.control)<=5 and U.available(S.bash) then return act("Mighty Bash healer setup",S.bash,c.control) end
        if U.available(S.cyclone) then return act("Cyclone pressure",S.cyclone,c.control,2) end
    end
    if cfg.damage and U.valid(t) and c.group_safe and (not c.pvp or c.damage_safe~=false) then
        if due(t,A.moonfire,true,p,4) then return act("Moonfire",S.moonfire,t) end
        if due(t,A.sunfire,true,p,4) then return act("Sunfire",S.sunfire,t) end
        return act("Wrath",S.wrath,t)
    end
end
return M
