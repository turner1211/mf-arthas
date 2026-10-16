local U=require("druid_shared")
local enums=require("common/enums")
local S={cat=768,rake=1822,rip=1079,shred=5221,swipe=106785,primal=285381,bite=22568,
    tiger=5217,berserk=106951,incarnation=102543,feral_frenzy=274837,convoke=391528,barkskin=22812,survival=61336,skull_bash=106839,
    maim=22570,bash=5211,cyclone=33786,roots=339,regrowth=8936,soothe=2908,remove=2782,mark=1126,bear=5487,renewal=108238,thorns=467,
    lunar_inspiration=155627,moonfire=155625,innervate=29166,prowl=5215}
local A={rake=155722,rip=1079,predatory=69369,moonfire=155625}
local M={spells=S}
local function act(key,id,target,delay,off) return {key=key,id=id,target=target,delay=delay,off=off} end
local function due(unit,id,p,seconds)
    local active,remain=U.aura(unit,id,true,p);return not active or remain and remain<seconds
end
function M.decide(c)
    local p,t,cfg=c.player,c.target,c.settings
    if c.pvp and cfg.defensives and c.hp<=25 and U.available(S.renewal) then return act("Renewal",S.renewal,p,nil,true) end
    if cfg.defensives and (c.hp<=cfg.emergency or c.pvp and c.self_burst and c.hp<=45) and U.available(S.survival) and not U.aura(p,S.survival)
        then return act("Survival Instincts",S.survival,p,nil,true) end
    if cfg.defensives and (c.hp<=cfg.emergency or c.pvp and c.pre_defensive) and U.available(S.barkskin) and not U.aura(p,S.barkskin)
        then return act("Barkskin",S.barkskin,p,nil,true) end
    if c.pvp and cfg.defensives and c.self_melee_pressure and c.hp<=(c.self_burst and 75 or 50) and U.available(S.bear) and not U.aura(p,S.bear) then return act("Bear Form",S.bear,p) end
    if cfg.interrupts and c.interrupt and U.available(S.skull_bash) then return act("Skull Bash",S.skull_bash,c.interrupt,nil,true) end
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
    if c.pvp and cfg.utility and c.defensive_control and c.team_danger and U.aura(p,A.predatory) and U.available(S.cyclone) then return act("Defensive Cyclone",S.cyclone,c.defensive_control,2) end
    if c.pvp and cfg.utility and c.stop_healing_control and c.safe_to_cast and U.aura(p,A.predatory) and U.available(S.cyclone) then return act("Cyclone low target to deny healing",S.cyclone,c.stop_healing_control,2) end
    if c.pvp and cfg.utility and c.root_open and c.hp<75 and U.available(S.roots) then return act("Entangling Roots peel",S.roots,c.melee_pressure,2) end
    if c.pvp and not c.team_danger and not U.aura(p,S.mark) and U.available(S.mark) then return act("Restore Mark of the Wild",S.mark,p) end
    if not cfg.damage or not U.valid(t) or c.pvp and c.damage_safe==false then return nil end
    if c.pvp and U.aura(p,S.bear) and (c.self_attackers or 0)>0 and c.hp<80 then return nil end
    if not U.aura(p,S.cat) then return act("Cat Form",S.cat,p) end
    local combo=U.power(p,enums.power_type.COMBOPOINTS);local energy=U.power(p,enums.power_type.ENERGY)
    local aoe=cfg.aoe and c.aoe_safe~=false and c.enemy_count>=2
    local short_ready=cfg.cooldowns and(not c.pvp or c.kill_window and c.healer_vulnerable)
    local burst_ready=short_ready and(c.pvp or c.durable)
    if c.pvp and cfg.utility and (c.setup_window or c.kill_window) and c.control and c.stun_open and not c.enemy_healer_cc
        and U.distance(p,c.control)<=5 and U.available(S.bash) then return act("Mighty Bash healer setup",S.bash,c.control) end
    if burst_ready then
        if U.available(S.incarnation) then return act("Incarnation",S.incarnation,p) end
        if U.available(S.berserk) then return act("Berserk",S.berserk,p) end
    end
    -- Tiger's Fury and Feral Frenzy are short cooldowns. Current Midnight
    -- guidance keeps both rolling even when longer burst is being held.
    if short_ready and U.available(S.tiger) then return act("Tiger's Fury",S.tiger,p,nil,true) end
    if due(t,A.rake,p,4) then return act("Rake",S.rake,t) end
    if c.pvp and U.known(S.lunar_inspiration) and due(t,A.moonfire,p,4) and U.available(S.moonfire) then
        return act("Lunar Inspiration Moonfire",S.moonfire,t)
    end
    if combo>=5 then
        if due(t,A.rip,p,7) then
            if aoe and U.available(S.primal) then return act("Primal Wrath",S.primal,p) end
            return act("Rip",S.rip,t)
        end
        if c.pvp and not c.kill_window then
            for _,unit in ipairs(c.damage_enemies or {}) do
                if unit~=t and U.distance(p,unit)<=5 and due(unit,A.rip,p,7) then return act("Rip spread pressure",S.rip,unit) end
            end
        end
        if c.pvp and (c.setup_window or c.kill_window) and c.control and c.stun_open and not c.enemy_healer_cc and U.available(S.maim)
            then return act("Maim healer setup",S.maim,c.control) end
        if c.pvp and c.kill_window and c.damage_safe~=false and U.available(S.maim) then return act("Maim kill window",S.maim,t) end
        return act("Ferocious Bite",S.bite,t)
    end
    if short_ready and combo<=2 and U.available(S.feral_frenzy) then return act("Feral Frenzy",S.feral_frenzy,t) end
    if burst_ready and combo<=2 and U.aura(t,A.rip,true,p) and U.aura(p,S.tiger)
        and (U.aura(p,S.berserk) or U.aura(p,S.incarnation)) and U.available(S.convoke) then
        return act("Convoke the Spirits",S.convoke,t,4)
    end
    if not c.pvp and aoe and c.enemy_count<=8 then
        for _,unit in ipairs(c.damage_enemies or{})do
            if unit~=t and U.distance(p,unit)<=5 and due(unit,A.rake,p,4)then return act("Rake secondary target",S.rake,unit)end
        end
    end
    if c.pvp and not c.kill_window then
        for _,unit in ipairs(c.damage_enemies or {}) do
            if unit~=t and U.distance(p,unit)<=5 and due(unit,A.rake,p,4) then return act("Rake spread pressure",S.rake,unit) end
        end
        if U.known(S.lunar_inspiration) and U.available(S.moonfire) then
            for _,unit in ipairs(c.damage_enemies or {}) do
                if unit~=t and due(unit,A.moonfire,p,4) then return act("Moonfire spread pressure",S.moonfire,unit) end
            end
        end
    end
    if c.pvp and cfg.utility and U.aura(p,A.predatory) and U.available(S.regrowth) then
        local ally=c.focused_ally;local ally_hp=ally and U.hp(ally) or 100
        if ally and ally~=p and ally_hp<cfg.hp then return act("Predatory Regrowth ally",S.regrowth,ally) end
        if c.hp<cfg.hp then return act("Predatory Regrowth",S.regrowth,p) end
    end
    if c.pvp and cfg.utility and c.control and c.control_open and (c.setup_window or c.kill_window) and (not c.enemy_healer_cc or c.enemy_healer_cc_expiring)
        and c.safe_to_cast and U.available(S.cyclone) then return act("Cyclone healer",S.cyclone,c.control,2) end
    if aoe then
        return act("Swipe",S.swipe,p)
    end
    return act("Shred",S.shred,t)
end
return M
