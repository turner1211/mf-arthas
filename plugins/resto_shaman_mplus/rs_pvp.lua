local U,A,S,C,P,T=require("rs_units"),require("rs_auras"),require("rs_spells"),require("rs_settings"),require("rs_profiles"),require("rs_talents")
local M={hex_dr={}}
local last_control_cancel=-math.huge
local ANCIENT_OF_LORE=473909
local FEAR_CASTS={ [5782]=true,[8122]=true,[5246]=true,[5484]=true,[6358]=true,[198909]=true,[360806]=true,[605]=true }
local HIGH_VALUE_CC={
    [118]=true,    -- Polymorph
    [33786]=true,  -- Cyclone
    [51514]=true,  -- Hex
    [20066]=true,  -- Repentance
    [605]=true,    -- Mind Control
    [5782]=true,   -- Fear
    [360806]=true, -- Sleep Walk
    [2637]=true,   -- Hibernate
    [9484]=true,   -- Shackle Undead
}
local function active_cast(enemy)
 local channel=U.call(enemy,"is_channelling_spell")==true
 if not channel and U.call(enemy,"is_casting_spell")~=true then return false end
 local ending=tonumber(U.call(enemy,channel and "get_active_channel_end_time" or "get_active_spell_cast_end_time"))
 if ending and ending>100000 then ending=ending/1000 end
 return not ending or ending>core.time(),ending and ending-core.time() or nil
end
local function team_target(me,target,rows)
 local guid=U.guid(target)
 if not guid then return false end
 if guid==U.guid(me) then return true end
 for _,row in ipairs(rows)do if U.guid(row.unit)==guid then return true end end
 return false
end
local function prune_hex_dr(now)
    now=now or core.time()
    for guid,expires in pairs(M.hex_dr) do
        if type(expires)~="number" or expires<=now then M.hex_dr[guid]=nil end
    end
end
function M.reset() M.hex_dr={} end
local function enemies(me)
    local result={}
    for _,u in pairs(U.objects()) do
        if U.valid(u) and U.call(u,"is_player")==true and U.call(u,"is_enemy_with",me)==true
            and U.call(u,"is_in_combat")==true then result[#result+1]=u end
    end
    table.sort(result,function(a,b)return U.distance(me,a)<U.distance(me,b) end)
    return result
end
local function available_for_control(u)
    if C.get("pvp_ancient_lore") and A.present(u,ANCIENT_OF_LORE) then return false end
    -- Missing helper data must not permanently disable Hex. Positive immunity
    -- or crowd-control evidence still blocks it.
    return P.pvp_call("is_crowd_controlled_weak",u,500)~=true
        and P.pvp_call("is_cc_immune",u,nil,500)~=true
        and P.pvp_call("is_polymorph_immune",u,500)~=true
        and P.pvp_call("can_be_polymorphed",u,500)~=false
end
function M.hex_available(u)
    prune_hex_dr(core.time())
    local guid=U.guid(u)
    if guid then
        for _,method in ipairs({"get_auras","get_debuffs"}) do
            local list=U.call(u,method)
            if type(list)=="table" then for _,a in pairs(list)do
                local ok,id=pcall(function()return tonumber(a.spell_id or a.buff_id or a.id)end)
                if ok and (id==S.HEX or id==S.resolve(S.HEX)) then
                    M.hex_dr[tostring(guid)]=math.max(M.hex_dr[tostring(guid)] or 0,core.time()+20)
                    return false
                end
            end end
        end
    end
    return available_for_control(u)
        and (not guid or (M.hex_dr[tostring(guid)] or -math.huge)<=core.time())
end
function M.event(event,args)
    if type(args)~="table" or args[1]~="player" then return end
    local id=tonumber(args[3] or args[#args])
    if id==S.CAPACITOR and (event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED") then
        require("rs_projection").cancel_capacitor_setup("Capacitor setup cancelled after cast failure")
        return
    end
    if event~="UNIT_SPELLCAST_SUCCEEDED" then return end
    if id~=S.HEX and id~=S.resolve(S.HEX) then return end
    prune_hex_dr(core.time())
    local guid=A.request_target(S.HEX) or A.request_target(S.resolve(S.HEX))
    -- Fallback includes up to seven seconds of Hex plus the 20-second reset.
    if guid then M.hex_dr[tostring(guid)]=core.time()+27 end
end
function M.ancient_of_lore_active(me)
    if not C.get("pvp_ancient_lore") then return false end
    for _,enemy in ipairs(enemies(me)) do
        if A.present(enemy,ANCIENT_OF_LORE) then
            C.pvp_status="Enemy Ancient of Lore active: preserving crowd control"
            return true,enemy
        end
    end
    C.pvp_status="Ancient of Lore counter ready"
    return false,nil
end
local function friendly_targeting(me,target)
    local guid=U.guid(target)
    if not guid then return true end
    for _,u in pairs(U.objects()) do
        if U.valid(u) and U.call(u,"is_player")==true and U.call(u,"is_enemy_with",me)~=true
            and U.guid(U.call(u,"get_target"))==guid then return true end
    end
    return false
end
function M.peel(me,rows,pressure,selfhp)
    if not C.get("pvp_peel") or not selfhp then return false end
    local protected=me
    local protected_hp=selfhp
    if selfhp>C.get("pvp_peel_hp") and not pressure.self_burst then
        protected=pressure.target
        protected_hp=nil
        for _,r in ipairs(rows) do if r.unit==protected then protected_hp=r.hp;break end end
        if not protected or not protected_hp or protected_hp>C.get("pvp_burst") then return false end
    end
    local chasers={}
    for _,enemy in ipairs(enemies(me)) do
        if U.guid(U.call(enemy,"get_target"))==U.guid(protected) and U.distance(protected,enemy)<=10
            and P.pvp_call("is_melee",enemy)==true and available_for_control(enemy) then
            chasers[#chasers+1]=enemy
        end
    end
    local closest=chasers[1]
    if not closest then return false end
    local self_peel=protected==me and U.distance(me,closest)<=10
    -- Thunderstorm was removed from Restoration in Midnight. Keep attackers
    -- trapped by the confirmed Static Field, then layer Earthgrab instead of
    -- repeatedly trying to place Static or requesting a removed spell.
    if self_peel and #chasers>=2 and A.since(S.STATIC)>=6
        and S.cast(S.STATIC,me,me,true) then C.status="PvP peel: Static Field";return true end
    if self_peel and A.since(S.STATIC)<6
        and require("rs_projection").control_peel(me,P.get(),pressure,closest) then return true end
    if S.cast(S.EARTHGRAB,closest,me,true) then C.status="PvP peel: Earthgrab";return true end
    if S.cast(S.EARTHBIND,closest,me,true) then C.status="PvP peel: Earthbind";return true end
    if S.cast(S.CAPACITOR,closest,me,true) then C.status="PvP peel: Capacitor";return true end
    if S.cast(S.FROST,closest,me) then C.status="PvP peel: Frost Shock";return true end
    if U.call(me,"is_moving")==true and S.cast(S.WIND_RUSH,me,me,true) then C.status="PvP peel: Wind Rush";return true end
    return false
end
function M.grounding(me,rows)
    if not S.known(S.GROUNDING) or not S.ready(S.GROUNDING) then return false end
    local friendly={}
    for _,r in ipairs(rows) do friendly[tostring(U.guid(r.unit))]=true end
    local best,best_score
    for _,enemy in ipairs(enemies(me)) do
        local casting,remaining=active_cast(enemy)
        local target=U.call(enemy,"get_target")
        if casting and (not remaining or remaining<=2.5 or U.call(enemy,"is_channelling_spell")==true) and friendly[tostring(U.guid(target))] and U.distance(me,target)<=30 then
            local id=tonumber(U.call(enemy,"get_active_spell_id"))
            local shearable=U.call(enemy,"is_active_spell_interruptable")==true
                and U.distance(me,enemy)<=30 and S.ready(S.WIND_SHEAR)
            local preserve_shear=C.get("pvp_ground_cc_first") and HIGH_VALUE_CC[id]==true
            if not shearable or preserve_shear then
                local hp=U.projected(target) or 100
                local score=(100-hp)+(target==me and 20 or 0)+(preserve_shear and 40 or 0)
                    +(P.pvp_call("has_burst_active",enemy,500)==true and 30 or 0)
                if not best_score or score>best_score then best,best_score=enemy,score end
            end
        end
    end
    if best and S.cast(S.GROUNDING,me,me,false,false,true) then
        C.pvp_status="Grounding Totem protecting highest-risk cast; preserving Wind Shear when useful"
        C.status="PvP defense: Grounding Totem"
        return true
    end
    return false
end
function M.tremor(me,rows)
    if not S.known(S.TREMOR) or not S.ready(S.TREMOR) then return false end
    for _,r in ipairs(rows) do
        local control=U.call(r.unit,"get_loss_of_control_info")
        local kind=type(control)=="table" and string.lower(tostring(control.type or control.control_type or control.name or "")) or ""
        if U.distance(me,r.unit)<=30 and type(control)=="table" and control.valid~=false
            and (kind:find("fear",1,true) or kind:find("charm",1,true) or kind:find("sleep",1,true)) then
            if S.cast(S.TREMOR,me,me,false,false,true) then
                C.pvp_status="Tremor Totem breaking team crowd control";C.status="PvP defense: Tremor Totem";return true
            end
        end
    end
    for _,enemy in ipairs(enemies(me)) do
        local id=tonumber(U.call(enemy,"get_active_spell_id"))
        local casting,remaining=active_cast(enemy)
        local victim=U.call(enemy,"get_target")
        local in_team=team_target(me,victim,rows)
        if casting and (not remaining or remaining<=1.2 or U.call(enemy,"is_channelling_spell")==true) and FEAR_CASTS[id] and (in_team or not victim) and U.distance(me,enemy)<=40
            and (not victim or U.distance(me,victim)<=30) then
            if S.cast(S.TREMOR,me,me,false,false,true) then
                C.pvp_status="Tremor Totem prepared for incoming fear";C.status="PvP defense: Tremor Totem";return true
            end
        end
    end
    return false
end
function M.counterstrike(me,rows,pressure)
    if not C.get("pvp_counterstrike") or not S.known(S.COUNTERSTRIKE) or not S.ready(S.COUNTERSTRIKE) then return false end
    if not pressure or (pressure.target_attackers or 0)<2 or not pressure.target then return false end
    local target_hp=100
    for _,r in ipairs(rows) do if r.unit==pressure.target then target_hp=r.hp;break end end
    -- It is pressure relief, not an emergency heal. At critical health the
    -- rotation must spend throughput or a lifesaving cooldown first.
    if target_hp<=P.get().emergency then return false end
    if S.cast(S.COUNTERSTRIKE,me,me,false,false,true) then
        C.status="PvP defense: Counterstrike Totem"
        C.pvp_status="Counterstrike Totem into committed multi-attacker pressure"
        return true
    end
    return false
end
function M.lasso(me,rows,pressure)
    if not C.get("pvp_lasso") or not S.known(S.LASSO) or not S.ready(S.LASSO) then return false end
    if not rows[1] or rows[1].hp<97 or (U.projected(me) or 0)<97 then return false end
    if pressure and (pressure.burst or pressure.self_burst or (pressure.attackers or 0)>0) then return false end
    local grounding_protected=A.since(S.GROUNDING)<2.5
    local kick_threat=P.kick_threat(me)
    local sheared=require("rs_interrupts").recent_target(4)
    for _,enemy in ipairs(enemies(me)) do
        local dr=P.pvp_call("get_cc_reduction_mult",enemy)
        local protected=grounding_protected or sheared==enemy
        if (not kick_threat or protected) and U.distance(me,enemy)<=20 and U.visible(me,enemy) and available_for_control(enemy)
            and (dr==nil or dr>=0.75) and not friendly_targeting(me,enemy)
            and U.call(enemy,"get_group_role")==1 then
            if S.cast(S.LASSO,enemy,me,false,true) then
                C.status="PvP control: Lightning Lasso"
                C.pvp_status=protected and "Protected Lightning Lasso on enemy healer" or "Safe Lightning Lasso on enemy healer"
                return true
            end
        end
    end
    return false
end
function M.yield_control(me,rows,profile,pressure)
 if not profile.pvp or not rows[1] then return false end
 if U.call(me,"is_casting_spell")~=true and U.call(me,"is_channelling_spell")~=true then return false end
 local id=tonumber(U.call(me,"get_active_spell_id"))
 if id~=S.HEX and id~=S.resolve(S.HEX) and id~=S.LASSO and id~=S.resolve(S.LASSO) then return false end
 -- Only interrupt control that this routine has requested.
 if not A.request_target(id) then return false end
 local hp=rows[1].hp
 local danger=hp<=profile.emergency or profile.imminent_emergency
  or (pressure and pressure.burst and hp<=(profile.burst_hp or 80))
 if not danger then return false end
 if core.time()-last_control_cancel>=0.25 then
  last_control_cancel=core.time()
  if not S.cancel(me,"PvP control yielded to emergency healing") then return false end
  C.status="Stopping crowd control for emergency healing"
  C.pvp_status="Hex/Lasso cancelled: team survival takes priority"
 end
 return true
end
local function request_hex(me,target,status,detail)
    local instant=A.present(me,S.NATURE) or A.present(me,S.ANCESTRAL)
    if not instant and T.has(S.CALL_AKIR,"Call of Al'Akir") then
        if S.cast(S.ANCESTRAL,me,me,false,false,true)
            or S.cast(S.NATURE,me,me,false,false,true) then
            C.status="PvP control: preparing instant Hex"
            C.pvp_status="Call of Al'Akir: Swiftness prepared for Hex"
            return true
        end
    end
    local protected=instant or A.since(S.GROUNDING)<2.5
        or require("rs_interrupts").recent_target(4)==target
    if not protected and P.hardcast_risk(me) then
        C.pvp_status="Hex held: confirmed interrupt threat"
        return false
    end
    if S.cast(S.HEX,target,me,false,true) then
        C.status=status;C.pvp_status=detail;return true
    end
    return false
end
function M.control(me,rows,pressure)
    if not C.get("pvp_cc") then C.pvp_status="Hex disabled";return false end
    if not rows[1] then C.pvp_status="Hex held: no reachable team health";return false end
    if rows[1].hp<90 then C.pvp_status="Hex held: teammate below 90%";return false end
    local selfhp=U.projected(me) or 100
    if selfhp<95 then C.pvp_status="Hex held: healer below 95%";return false end
    if pressure and (pressure.burst or (pressure.attackers or 0)>=2) then
        C.pvp_status="Hex held: unsafe enemy pressure";return false
    end
    M.ancient_of_lore_active(me)
    local projection=require("rs_projection")
    local cap_followup=projection.capacitor_followup()
    if cap_followup and not friendly_targeting(me,cap_followup) and M.hex_available(cap_followup)
        and not A.own_debuff(cap_followup,S.FLAME,me)
        and request_hex(me,cap_followup,"PvP control: Capacitor into Hex",
            "Hex chained after projected Capacitor Totem") then
        projection.consume_capacitor_followup();return true
    end
    if projection.capacitor_pending() then
        C.pvp_status="Hex held: waiting for confirmed Capacitor Projection"
        return true
    end
    local sheared=require("rs_interrupts").recent_target(4)
    local fallback
    local seen,eligible=0,0
    for _,enemy in ipairs(enemies(me)) do
        seen=seen+1
        local distance=U.distance(me,enemy)
        local healer=U.call(enemy,"get_group_role")==1
        local attacking_me=U.guid(U.call(enemy,"get_target"))==U.guid(me)
        local dr=P.pvp_call("get_cc_reduction_mult",enemy)
        if distance<=30 and U.visible(me,enemy)
            and not A.own_debuff(enemy,S.FLAME,me) and M.hex_available(enemy)
            and (dr==nil or dr>=0.75) then
            eligible=eligible+1
            if enemy==sheared and not friendly_targeting(me,enemy) then
                if request_hex(me,enemy,"PvP control: Wind Shear into Hex",
                    "Hex chained on the recently interrupted caster") then return true end
            elseif healer and not friendly_targeting(me,enemy) then
                if not friendly_targeting(me,enemy) and projection.capacitor_control(me,enemy) then return true end
                if request_hex(me,enemy,"PvP control: Hex healer",
                    "Hex requested on enemy healer") then return true end
            elseif attacking_me and not friendly_targeting(me,enemy)
                and P.pvp_call("is_melee",enemy)==true then fallback=enemy end
        end
    end
    if fallback and request_hex(me,fallback,"PvP control: defensive Hex",
        "Defensive Hex requested") then return true end
    if seen==0 then C.pvp_status="Hex held: no engaged enemy"
    elseif eligible==0 then C.pvp_status="Hex held: range, line of sight, immunity, CC, DoT, or DR"
    else C.pvp_status="Hex held: no eligible healer or melee attacker" end
    return false
end
return M
