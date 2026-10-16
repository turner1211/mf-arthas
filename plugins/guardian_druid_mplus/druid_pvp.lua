local U=require("druid_shared")
local M={history={}}
local ok,H=pcall(require,"common/utility/pvp_helper")
if not ok or type(H)~="table" then H=nil end
local MELEE={[70]=true,[71]=true,[72]=true,[103]=true,[251]=true,[252]=true,[255]=true,[259]=true,[260]=true,[261]=true,[263]=true,[269]=true,[577]=true}
local HEALER={[65]=true,[105]=true,[256]=true,[257]=true,[264]=true,[270]=true,[1468]=true}
local CAST_PRIORITY={[118]=3,[605]=3,[2060]=3,[2061]=3,[5782]=3,[8004]=3,[8936]=3,[19750]=3,
    [33786]=3,[51514]=3,[77472]=3,[82326]=3,[116670]=3,[116858]=3,[124682]=3,[20066]=3,[305483]=3}
local CONTROL_CAST={[118]=true,[605]=true,[5782]=true,[33786]=true,[51514]=true,[20066]=true}
local DISPEL_CC={[118]=true,[605]=true,[5782]=true,[8122]=true,[33786]=true,[51514]=true,[20066]=true,[360806]=true,[2637]=true}
local UNSAFE_DISPEL={[1219045]=true,[30108]=true}
local CONTROL_IMMUNITY={473909,377362,377360} -- Ancient of Lore and Precognition
local function call(name,...)
    if not H or type(H[name])~="function" then return nil end
    return U.call(H[name],H,...)
end
local function role(u) return U.role(u) end
local function target_of(u) return U.call(u and u.get_target,u) end
local function player(u) return U.call(u and u.is_player,u)==true end
local function immune(u) return call("is_damage_immune",u,nil,250)==true end
local function reduced(u) return call("has_damage_reduction",u,55,nil,250)==true end
local function cycloned(u)
    local flags=H and H.cc_flags or {}
    local flag=flags.CYCLONE
    local value=flag and call("is_crowd_controlled",u,flag,0)
    return value==true or U.aura(u,33786,true)==true
end
local function controlled(u)
    local value=call("is_crowd_controlled",u,nil,500)
    return value==true or value==nil and U.protected(u)
end
local function cc_state(u)
    local active,_,remaining=call("is_crowd_controlled",u,nil,0)
    if active==nil then
        local cyclone,left=U.aura(u,33786,true)
        if cyclone then return true,(tonumber(left) or 0)*1000 end
    end
    return active==true,tonumber(remaining) or 0
end
local function control_immune(u)
    for _,id in ipairs(CONTROL_IMMUNITY) do if U.aura(u,id) then return true end end
    return false
end
local function cc_open(u,flag)
    if not U.valid(u) or control_immune(u) or controlled(u) or call("is_cc_immune",u,flag,250)==true then return false end
    local dr=call("get_unit_dr",u,flag,0)
    return dr==nil or dr>=0.5
end
local function chain_open(u,flag,remaining_ms)
    if not U.valid(u) or control_immune(u) or remaining_ms>1800 or call("is_cc_immune",u,flag,0)==true then return false end
    local dr=call("get_unit_dr",u,flag,0)
    return dr==nil or dr>=0.5
end
local function spec(u) return U.spec(u) end
local function is_healer(u) return role(u)=="HEALER" or HEALER[spec(u)]==true end
local function trend(spec_id,u)
    local key=tostring(spec_id)..":"..tostring(U.guid(u) or "none")
    local now=tonumber(U.call(core.time)) or 0;local hp=U.hp(u) or 100;local old=M.history[key]
    local loss=0
    if old and now>old.at and now-old.at<=3 then loss=math.max(0,(old.hp-hp)/(now-old.at)) end
    M.history[key]={hp=hp,at=now}
    return loss
end
function M.enrich(c)
    if not c.pvp then return c end
    local flags=H and H.cc_flags or {}
    local pressure,self_pressure,burst,self_burst,burst_unit,melee,self_melee=0,0,false,false,nil,nil,nil
    local healer,off,hibernate,kill_target=c.control,nil,nil,c.target
    local friendly_healer,ally_burst,ally_burst_target=c.spec==4 and c.player or nil,false,nil
    local focus,focus_score=c.lowest,100-(c.lowest_hp or 100)
    local friendly_flag_carrier=nil
    for _,r in ipairs(c.members or {}) do
        if r.role=="HEALER" then friendly_healer=r.unit end
        if r.unit~=c.player and call("has_burst_active",r.unit,400)==true then
            ally_burst=true
            local candidate=target_of(r.unit)
            if player(candidate) then ally_burst_target=candidate end
        end
        if U.call(r.unit.is_flag_carrier,r.unit)==true or U.call(r.unit.has_flag,r.unit)==true then
            friendly_flag_carrier=r.unit
            local score=100-r.hp+35
            if score>focus_score then focus,focus_score=r.unit,score end
        end
    end
    local lowest=c.lowest
    for _,u in ipairs(c.enemies or {}) do
        local on_team=false
        local victim=target_of(u)
        for _,r in ipairs(c.members or {}) do if victim==r.unit then on_team=true;break end end
        local b=call("has_burst_active",u,400)==true
        if on_team then pressure=pressure+1;burst=burst or b;if b then burst_unit=burst_unit or u end end
        if victim==c.player then self_pressure=self_pressure+1;self_burst=self_burst or b end
        if on_team then
            for _,r in ipairs(c.members or {}) do if victim==r.unit then
                local score=100-r.hp+18+(b and 25 or 0)
                if score>focus_score then focus,focus_score=r.unit,score end
            end end
        end
        if player(u) and is_healer(u) and u~=kill_target then healer=healer or u end
        if u~=kill_target and player(u) then off=off or u end
        local sid=spec(u)
        if u~=kill_target and (sid==103 or sid==104) and (U.aura(u,768) or U.aura(u,5487)) then hibernate=hibernate or u end
        if on_team and (call("is_melee",u)==true or MELEE[sid]) and U.distance(c.player,u)<=15 then
            melee=melee or u;if victim==c.player then self_melee=self_melee or u end
        end
    end
    if ally_burst_target and U.valid(ally_burst_target) and not immune(ally_burst_target)
        and not reduced(ally_burst_target) and not cycloned(ally_burst_target) then
        kill_target=ally_burst_target;c.target=ally_burst_target
    end
    if kill_target and (immune(kill_target) or reduced(kill_target) or cycloned(kill_target)) then
        local best,best_score=nil,-math.huge
        for _,u in ipairs(c.enemies or {}) do if player(u) and not immune(u) and not reduced(u) and not cycloned(u) then
            local score=100-(U.hp(u) or 100)+(call("trinket_used_within",u,20)==true and 20 or 0)
                +(is_healer(u) and -15 or 0)
            if score>best_score then best,best_score=u,score end
        end end
        if best then kill_target=best;c.target=best end
    end
    local healer_cc,healer_cc_ms=healer and cc_state(healer) or false,0
    if healer then healer_cc,healer_cc_ms=cc_state(healer) end
    local healer_trinket=healer and call("trinket_used_within",healer,20)==true or false
    local healer_far=healer and U.distance(healer,kill_target)>30 or false
    local healer_mana=healer and U.power_pct(healer,require("common/enums").power_type.MANA) or nil
    local healer_vulnerable=not healer or healer_cc and healer_cc_ms>=1200 or healer_trinket or healer_far
        or healer_mana and healer_mana<=15
    local loss=kill_target and trend(c.spec,kill_target) or 0
    local collapsing=loss>=4 and (U.hp(kill_target) or 100)<=60
    local dampening,_,dampening_stacks=U.aura(c.player,110310)
    local high_dampening=dampening and dampening_stacks>=30
    local kill=kill_target and player(kill_target) and not immune(kill_target) and not reduced(kill_target)
        and ((U.hp(kill_target) or 100)<=35 or call("trinket_used_within",kill_target,20)==true
            or collapsing or high_dampening and (U.hp(kill_target) or 100)<=55
            or healer_cc and healer_cc_ms>=1200 and (U.hp(kill_target) or 100)<=85
            or ally_burst and healer_vulnerable)
    local control=healer or off
    local control_contested=false
    for _,r in ipairs(c.members or {}) do
        if r.unit~=c.player and r.role~="HEALER" and target_of(r.unit)==control then control_contested=true;break end
    end
    local hibernate_contested=false
    for _,r in ipairs(c.members or {}) do
        if r.unit~=c.player and r.role~="HEALER" and target_of(r.unit)==hibernate then hibernate_contested=true;break end
    end
    c.pvp_helper=H;c.enemy_burst=burst;c.self_burst=self_burst;c.attackers=pressure;c.self_attackers=self_pressure
    c.melee_pressure=melee;c.self_melee_pressure=self_melee
    c.damage_safe=kill_target and not immune(kill_target) and not reduced(kill_target) and not cycloned(kill_target)
    c.kill_window=kill==true;c.control=control
    local friendly_cc=friendly_healer and (call("is_crowd_controlled",friendly_healer,nil,600)==true
        or U.protected(friendly_healer)) or false
    local friendly_healer_mana=friendly_healer and U.power_pct(friendly_healer,require("common/enums").power_type.MANA) or nil
    local friendly_healer_available=friendly_healer and U.valid(friendly_healer) and U.distance(c.player,friendly_healer)<=40
        and U.los(c.player,friendly_healer) and not friendly_cc or false
    local cyclone_flag=flags.CYCLONE or flags.INCAPACITATE or flags.DISORIENT
    c.control_open=control and not control_contested and ((control==healer and healer_cc and chain_open(control,cyclone_flag,healer_cc_ms))
        or cc_open(control,cyclone_flag))
    c.stun_open=control and cc_open(control,flags.STUN)
    c.healer_root_open=healer and cc_open(healer,flags.ROOT)
    c.root_open=melee and cc_open(melee,flags.ROOT)
    c.defensive_control=c.healer_cc_caster and cc_open(c.healer_cc_caster,flags.INCAPACITATE or flags.DISORIENT)
        and c.healer_cc_caster or burst_unit and cc_open(burst_unit,flags.INCAPACITATE or flags.DISORIENT) and burst_unit or nil
    local target_hp=kill_target and U.hp(kill_target) or 100
    c.stop_healing_control=kill_target and target_hp>=15 and target_hp<=35 and loss<2 and not ally_burst
        and not healer_cc and cc_open(kill_target,cyclone_flag) and kill_target or nil
    local player_flag=U.call(c.player.is_flag_carrier,c.player)==true or U.call(c.player.has_flag,c.player)==true
    c.team_danger=(c.lowest_hp or 100)<=65 or burst and (c.lowest_hp or 100)<=82 or pressure>=2
        or c.incoming_healer_cc and (c.lowest_hp or 100)<=88
        or friendly_healer_mana and friendly_healer_mana<=15 and (c.lowest_hp or 100)<=80
    c.setup_window=kill_target and player(kill_target) and not c.team_danger and (c.lowest_hp or 100)>=85
        and c.control_open and not immune(kill_target) and not reduced(kill_target)
        and (ally_burst or healer_trinket or healer_far or healer_mana and healer_mana<=30
            or loss>=1 and (U.hp(kill_target) or 100)<=95) or false
    c.self_reduced=call("has_damage_reduction",c.player,40,nil,250)==true
    c.focused_ally_reduced=focus and call("has_damage_reduction",focus,35,nil,250)==true or false
    c.friendly_healer_available=friendly_healer_available
    c.friendly_healer=friendly_healer
    c.friendly_healer_unavailable=friendly_healer~=nil and not friendly_healer_available
    c.friendly_healer_mana=friendly_healer_mana
    c.pre_defensive=(self_burst and c.hp<=90 or self_pressure>=2 and c.hp<=75
        or c.friendly_healer_unavailable and self_pressure>=1 and c.hp<=88
        or friendly_healer_mana and friendly_healer_mana<=25 and self_pressure>=1 and c.hp<=92
        or c.incoming_healer_cc and self_pressure>=1 and c.hp<=90
        or friendly_cc and c.hp<=75 or player_flag and pressure>=1 and c.hp<=92) and not c.self_reduced
    c.safe_to_cast=(not melee or U.distance(c.player,melee)>8) and not c.team_danger
    c.ally_burst=ally_burst
    c.ally_burst_target=ally_burst_target
    c.focused_ally=focus
    c.friendly_flag_carrier=friendly_flag_carrier
    c.enemy_healer=healer
    c.control_contested=control_contested
    c.hibernate_control=hibernate and not hibernate_contested and cc_open(hibernate,flags.INCAPACITATE or flags.DISORIENT) and hibernate or nil
    c.enemy_healer_cc=healer_cc
    c.enemy_healer_cc_remaining=healer_cc_ms/1000
    c.enemy_healer_cc_expiring=healer_cc and healer_cc_ms<=1800
    c.enemy_healer_trinket_down=healer_trinket
    c.enemy_healer_mana=healer_mana
    c.enemy_healer_exhausted=healer_mana and healer_mana<=15 or false
    c.healer_vulnerable=healer_vulnerable
    c.target_loss_rate=loss;c.target_collapse=collapsing
    c.dampening_stacks=dampening and dampening_stacks or nil;c.high_dampening=high_dampening
    c.player_flag_carrier=player_flag
    c.healer_cc=friendly_cc
    c.pvp_summary=string.format("burst=%s self_burst=%s attackers=%d self_attackers=%d danger=%s healer_available=%s friendly_mana=%s incoming_cc=%s healer_cc_threat=%s setup=%s kill=%s healer_cc=%.1f healer_mana=%s collapse=%s dampening=%s flag=%s",
        tostring(burst),tostring(self_burst),pressure,self_pressure,tostring(c.team_danger),tostring(c.friendly_healer_available),
        friendly_healer_mana and string.format("%.0f",friendly_healer_mana) or "unknown",tostring(c.incoming_cc),tostring(c.incoming_healer_cc),
        tostring(c.setup_window),tostring(c.kill_window),c.enemy_healer_cc_remaining or 0,
        healer_mana and string.format("%.0f",healer_mana) or "unknown",tostring(collapsing),
        tostring(c.dampening_stacks or "none"),tostring(c.player_flag_carrier))
    return c
end
function M.on_spell(data) if H and type(H.on_spell)=="function" then U.call(H.on_spell,H,data) end end
function M.cast_priority(unit)
    local id=tonumber(U.call(unit and unit.get_active_spell_id,unit))
        or tonumber(U.call(unit and unit.get_active_channel_spell_id,unit))
    return CAST_PRIORITY[id] or 0,id
end
function M.is_control_cast(unit)
    local id=tonumber(U.call(unit and unit.get_active_spell_id,unit))
        or tonumber(U.call(unit and unit.get_active_channel_spell_id,unit))
    return CONTROL_CAST[id]==true,id
end
function M.dispel_score(unit,allowed,pvp)
    local rows=U.call(unit and unit.get_debuffs,unit)
    if type(rows)~="table" then return nil,false end
    local best,urgent=nil,false
    for _,row in pairs(rows) do if row.is_active~=false then
        local id=tonumber(row.spell_id or row.debuff_id or row.id)
        if pvp and UNSAFE_DISPEL[id] then return nil,false end
        local kind=tostring(row.dispel_type or row.type or ""):lower()
        if allowed[kind] then
            local cc=DISPEL_CC[id]==true
            local score=(cc and 400 or kind=="magic" and 20 or 10)+(tonumber(row.stacks or row.stack_count) or 0)
            if not best or score>best then best,urgent=score,cc end
        end
    end end
    return best,urgent
end
function M.is_healer(unit) return is_healer(unit) end
function M.reset(spec_id)
    local prefix=tostring(spec_id)..":"
    for key in pairs(M.history) do if key:sub(1,#prefix)==prefix then M.history[key]=nil end end
    if H and type(H.clear_all_trinket_history)=="function" then U.call(H.clear_all_trinket_history,H) end
end
return M
