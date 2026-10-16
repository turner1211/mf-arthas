local U=require("druid_shared")
local enums=require("common/enums")
local S={moonkin=24858,moonfire=8921,sunfire=93402,wrath=190984,starfire=194153,starsurge=78674,starfall=191034,
    alignment=194223,incarnation=102560,force=205636,fury=202770,convoke=391528,barkskin=22812,solar_beam=78675,
    typhoon=132469,roots=339,mass_roots=102359,cyclone=33786,bash=5211,regrowth=8936,soothe=2908,remove=2782,mark=1126,bear=5487,renewal=108238,thorns=467,innervate=29166,hibernate=2637,prowl=5215}
local A={moonfire=164812,sunfire=164815,solar=48517,lunar=48518,touch=450360}
local M={spells=S}
local function act(key,id,target,delay,off) return {key=key,id=id,target=target,delay=delay,off=off} end
function M.decide(c)
    local p,t,cfg=c.player,c.target,c.settings
    if c.pvp and cfg.defensives and c.hp<=25 and U.available(S.renewal) then return act("Renewal",S.renewal,p,nil,true) end
    if cfg.defensives and (c.hp<=cfg.emergency or c.pvp and c.pre_defensive) and U.available(S.barkskin) and not U.aura(p,S.barkskin)
        then return act("Barkskin",S.barkskin,p,nil,true) end
    if c.pvp and cfg.defensives and c.self_melee_pressure and c.hp<=(c.self_burst and 75 or 55) and U.available(S.bear) and not U.aura(p,S.bear) then return act("Bear Form",S.bear,p) end
    if cfg.interrupts and c.interrupt and U.available(S.solar_beam) then return act("Solar Beam",S.solar_beam,c.interrupt,nil,true) end
    if c.pvp and cfg.utility and c.friendly_healer and c.friendly_healer_available and c.friendly_healer_mana
        and c.friendly_healer_mana<=30 and not c.kill_window and not c.setup_window and U.available(S.innervate) then
        return act("Innervate low-mana healer",S.innervate,c.friendly_healer)
    end
    if cfg.utility and c.dispel and (not c.pvp or c.dispel_urgent or not c.team_danger and not c.kill_window)
        and U.available(S.remove) then return act("Remove Corruption",S.remove,c.dispel,1.5) end
    if cfg.utility and c.enrage and U.available(S.soothe) then return act("Soothe",S.soothe,c.enrage,1.5) end
    if c.pvp and cfg.utility and c.melee_pressure and c.focused_ally and U.available(S.thorns)
        and not U.aura(c.focused_ally,S.thorns) then return act("Thorns focused ally",S.thorns,c.focused_ally) end
    if not c.combat then
        if not U.aura(p,S.mark) then return act("Mark of the Wild",S.mark,p) end
        if c.pvp and (c.mode=="arena" or c.mode=="battleground") then
            if not U.aura(p,S.prowl) and U.available(S.prowl) then return act("Prowl opener",S.prowl,p) end
            if U.aura(p,S.prowl) then return nil end
        end
        return nil
    end
    if c.pvp and cfg.utility and c.defensive_control and c.team_danger and U.available(S.cyclone) then return act("Defensive Cyclone",S.cyclone,c.defensive_control,2) end
    if c.pvp and cfg.utility and c.hibernate_control and c.team_danger and U.available(S.hibernate) then
        return act("Hibernate animal-form attacker",S.hibernate,c.hibernate_control,1.5)
    end
    if c.pvp and cfg.utility and c.stop_healing_control and c.safe_to_cast and U.available(S.cyclone) then return act("Cyclone low target to deny healing",S.cyclone,c.stop_healing_control,2) end
    if c.pvp and cfg.utility and c.root_open and U.available(S.roots) then return act("Entangling Roots peel",S.roots,c.melee_pressure,2) end
    if c.pvp and not c.team_danger and not U.aura(p,S.mark) and U.available(S.mark) then return act("Restore Mark of the Wild",S.mark,p) end
    if not cfg.damage or not U.valid(t) or c.pvp and c.damage_safe==false then return nil end
    if c.pvp and U.aura(p,S.bear) and (c.self_attackers or 0)>0 and c.hp<80 then return nil end
    if not U.aura(p,S.moonkin) and U.available(S.moonkin) then return act("Moonkin Form",S.moonkin,p) end
    if c.pvp and c.kill_window and c.healer_vulnerable and cfg.cooldowns then
        if U.available(S.incarnation) then return act("Incarnation",S.incarnation,p) end
        if U.available(S.alignment) then return act("Celestial Alignment",S.alignment,p) end
        if U.available(S.force) then return act("Force of Nature",S.force,t) end
        if U.available(S.fury) then return act("Fury of Elune",S.fury,t) end
        if U.available(S.convoke) then return act("Convoke the Spirits",S.convoke,t,4) end
    end
    if not U.aura(t,A.moonfire,true,p) then return act("Moonfire",S.moonfire,t) end
    if not U.aura(t,A.sunfire,true,p) then return act("Sunfire",S.sunfire,t) end
    if c.pvp and not c.kill_window then
        for _,unit in ipairs(c.damage_enemies or {}) do
            if unit~=t and not U.aura(unit,A.moonfire,true,p) then return act("Moonfire spread pressure",S.moonfire,unit) end
        end
    end
    local astral=U.power(p,enums.power_type.LUNARPOWER)
    local aoe=cfg.aoe and c.aoe_safe~=false and c.enemy_count>=2
    if c.pvp and cfg.utility and (c.setup_window or c.kill_window) and c.enemy_healer and c.healer_root_open
        and not U.aura(c.enemy_healer,S.roots,true,p) then
        if U.available(S.mass_roots) then return act("Mass Entanglement healer",S.mass_roots,c.enemy_healer) end
        if U.available(S.roots) then return act("Root healer for Solar Beam",S.roots,c.enemy_healer,2) end
    end
    if c.pvp and cfg.utility and (c.setup_window or c.kill_window) and c.control and c.stun_open and not c.enemy_healer_cc
        and U.distance(p,c.control)<=5 and U.available(S.bash) then return act("Mighty Bash healer setup",S.bash,c.control) end
    if c.pvp and cfg.utility and c.kill_window and c.enemy_healer and U.aura(c.enemy_healer,S.roots,true,p)
        and U.available(S.solar_beam) then return act("Solar Beam rooted healer",S.solar_beam,c.enemy_healer,nil,true) end
    if cfg.cooldowns and (not c.pvp or c.kill_window and c.healer_vulnerable) then
        if U.available(S.incarnation) then return act("Incarnation",S.incarnation,p) end
        if U.available(S.alignment) then return act("Celestial Alignment",S.alignment,p) end
        if U.available(S.force) then return act("Force of Nature",S.force,t) end
        if U.available(S.fury) then return act("Fury of Elune",S.fury,t) end
        if U.available(S.convoke) then return act("Convoke the Spirits",S.convoke,t,4) end
    end
    if c.pvp and cfg.utility and c.control and c.control_open and (c.setup_window or c.kill_window) and (not c.enemy_healer_cc or c.enemy_healer_cc_expiring)
        and c.safe_to_cast and U.available(S.cyclone) then return act("Cyclone healer",S.cyclone,c.control,2) end
    if U.aura(p,A.touch) then
        if aoe and U.available(S.starfall) then return act("Free Starfall",S.starfall,p) end
        if U.available(S.starsurge) then return act("Free Starsurge",S.starsurge,t) end
    end
    if astral>=(c.pvp and 40 or 80) then return aoe and act("Starfall",S.starfall,p) or act("Starsurge",S.starsurge,t) end
    local solar=U.aura(p,A.solar);local lunar=U.aura(p,A.lunar)
    if aoe or lunar then return act("Starfire",S.starfire,t) end
    if solar then return act("Wrath",S.wrath,t) end
    return c.enemy_count>=2 and act("Starfire",S.starfire,t) or act("Wrath",S.wrath,t)
end
return M
