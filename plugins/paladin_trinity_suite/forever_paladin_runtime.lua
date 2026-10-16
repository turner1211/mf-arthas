local Data=require("forever_paladin_data")
local Logger=require("forever_paladin_logger")
local R={instances={}}

local function call(owner,name,...)
    local fn=owner and owner[name];if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...);if ok then return v end
    ok,v=pcall(fn,owner,...);return ok and v or nil
end

local function player() return call(core and core.object_manager,"get_local_player") end
local function target() return call(core and core.object_manager,"get_current_target") or call(player(),"get_target") end
local function level(unit)
    local detected=tonumber(call(unit,"get_level")) or tonumber(call(unit,"get_character_level"))
    return detected and math.max(1,math.min(60,detected)) or nil
end
local function valid(unit) return unit and call(unit,"is_valid")==true end
local function hp(unit)
    local pct=tonumber(call(unit,"get_health_percentage"));if pct then return pct>1 and pct or pct*100 end
    local cur,max=tonumber(call(unit,"get_health")),tonumber(call(unit,"get_max_health"))
    return cur and max and max>0 and cur/max*100 or 100
end
local function dead(unit) return call(unit,"is_dead")==true or hp(unit)<=0 end
local function enemy(unit) return call(unit,"is_enemy")==true or call(unit,"is_hostile")==true end
local function combat(unit) return call(unit,"is_in_combat")==true end
local function mana(unit)
    local pct=tonumber(call(unit,"get_power_percentage",0)) or tonumber(call(unit,"get_mana_percentage"))
    if pct then return pct>1 and pct or pct*100 end
    local cur,max=tonumber(call(unit,"get_power",0)),tonumber(call(unit,"get_max_power",0))
    return cur and max and max>0 and cur/max*100 or 100
end
local function known(id) return call(core and core.spell_book,"is_spell_known",id)==true end
local function resolve(key)
    local ids=Data.spells[key] or {}
    for i=1,#ids do if known(ids[i]) then return ids[i] end end
end
local function resolve_efficient(key,fraction)
    local learned={}
    for _,id in ipairs(Data.spells[key] or {}) do if known(id) then learned[#learned+1]=id end end
    if #learned==0 then return nil end
    fraction=tonumber(fraction) or 0.60
    return learned[math.min(#learned,math.max(2,math.ceil(#learned*fraction)))] or learned[1]
end
local function ready(id)
    if not id then return false end
    local cd=tonumber(call(core and core.spell_book,"get_spell_cooldown",id))
    return cd==nil or cd<=0.05
end
local function aura(unit,key)
    local ids=Data.spells[key] or {}
    for _,id in ipairs(ids) do
        if call(unit,"has_buff",id)==true or call(unit,"has_aura",id)==true then return true end
    end
    return false
end
local function any_aura(unit,keys)
    for _,key in ipairs(keys or {}) do if aura(unit,key) then return true end end
    return false
end
local function cast(key,unit,instance,efficient)
    local me=player()
    if call(me,"is_casting")==true or call(me,"is_channeling")==true then return false end
    local id=efficient and resolve_efficient(key,type(efficient)=="number" and efficient or nil) or resolve(key)
    if not ready(id) or not valid(unit) then return false end
    local required=Data.levels[key]
    if required and instance.level and instance.level<required then return false end
    local clock=tonumber(call(core,"time")) or 0
    instance.cast_backoff=instance.cast_backoff or {}
    if clock<(instance.cast_backoff[key] or -math.huge) then return false end
    if Data.hardcasts[key] and call(me,"is_moving")==true then
        local cast_time=tonumber(call(core and core.spell_book,"get_spell_cast_time",id))
            or tonumber(call(core and core.spell_book,"get_cast_time",id))
        if cast_time==nil or cast_time>0 then return false end
    end
    local accepted=call(core and core.input,"cast_target_spell",id,unit)
    if accepted==true then
        instance.cast_backoff[key]=clock+0.10
        instance.last_action=key;instance.logger.event("cast",key);return true
    end
    instance.cast_backoff[key]=clock+0.35
    return false
end

local function distance(a,b)
    return tonumber(call(a,"get_distance",b)) or tonumber(call(b,"get_distance",a)) or 999
end

local function weapon_speed(unit)
    local speed=tonumber(call(unit,"get_main_hand_attack_speed"))
        or tonumber(call(unit,"get_main_hand_speed"))
        or tonumber(call(unit,"get_weapon_speed"))
        or tonumber(call(unit,"get_attack_speed"))
    if speed and speed>20 then speed=speed/1000 end
    return speed and speed>0 and speed or nil
end

local function creature_kind(unit)
    return tostring(call(unit,"get_creature_type") or call(unit,"get_type_name") or ""):lower()
end

local function holy_target(unit)
    local kind=creature_kind(unit)
    return kind:find("undead",1,true)~=nil or kind:find("demon",1,true)~=nil
end

local function snapshot(instance)
    local now=tonumber(call(core,"time")) or 0
    if not instance.object_cache or now>=(instance.object_cache_at or -math.huge) then
        instance.object_cache=call(core and core.object_manager,"get_all_objects") or {}
        instance.object_cache_at=now+0.20
    end
    return instance.object_cache
end

local function nearby_enemies(instance,me,radius,kind_only)
    local objects=snapshot(instance)
    local count=0
    if type(objects)=="table" then for _,unit in pairs(objects) do
        local allowed=not kind_only or holy_target(unit)
        if allowed and valid(unit) and enemy(unit) and not dead(unit) and distance(me,unit)<=radius then count=count+1 end
    end end
    return count
end

local members

local function targets_group(unit)
    local victim=call(unit,"get_target")
    for _,ally in ipairs(members()) do
        if victim==ally or call(unit,"is_targeting",ally)==true then return true end
    end
    return false
end

local function loose_enemy(instance,me)
    local objects=snapshot(instance)
    local best,best_score=nil,-math.huge
    if type(objects)=="table" then for _,unit in pairs(objects) do
        if valid(unit) and enemy(unit) and combat(unit) and not dead(unit) and distance(me,unit)<=10
            and call(unit,"is_targeting_player")==false then
            local threat=call(me,"get_threat_situation",unit) or call(unit,"get_threat_situation",me)
            local tanking=type(threat)=="table" and threat.is_tanking==true
            local owned=targets_group(unit) or (type(threat)=="table" and ((tonumber(threat.status) or 0)>0
                or (tonumber(threat.threat_percent) or 0)>0))
            if owned and not tanking then
                local score=(targets_group(unit) and 100 or 0)+(100-(tonumber(threat and threat.threat_percent) or 0))
                if score>best_score then best,best_score=unit,score end
            end
        end
    end end
    return best
end

local function dispellable(unit)
    for _,kind in ipairs({"poison","disease","magic"}) do
        if call(unit,"has_debuff_type",kind)==true or call(unit,"has_dispellable_debuff",kind)==true then return true end
    end
    return false
end

local function state(unit,...)
    for i=1,select("#",...) do if call(unit,select(i,...))==true then return true end end
    return false
end

local function movement_impaired(unit)
    return state(unit,"is_rooted","is_slowed","is_snared","has_movement_impairing_effect")
end

local function has_debuff_kind(unit,...)
    for i=1,select("#",...) do
        local kind=select(i,...)
        if call(unit,"has_debuff_type",kind)==true or call(unit,"has_dispellable_debuff",kind)==true then return true end
    end
    return false
end

local function role(unit)
    return tostring(call(unit,"get_role") or call(unit,"get_group_role") or ""):lower()
end

members=function()
    local list=call(core and core.object_manager,"get_party_members")
        or call(core and core.object_manager,"get_group_members") or {}
    local me=player();local out={}
    if valid(me) then out[#out+1]=me end
    if type(list)=="table" then for _,unit in pairs(list) do if valid(unit) then out[#out+1]=unit end end end
    return out
end

local function group_has_aura(key)
    for _,unit in ipairs(members()) do if aura(unit,key) then return true end end
    return false
end
local function projected_hp(instance,unit)
    local current=hp(unit)
    local maximum=tonumber(call(unit,"get_max_health")) or 0
    local incoming=tonumber(call(unit,"get_incoming_damage",2))
        or tonumber(call(unit,"get_incoming_damage")) or 0
    local healing=tonumber(call(unit,"get_incoming_heals",2))
        or tonumber(call(unit,"get_incoming_heals")) or 0
    local absorbs=tonumber(call(unit,"get_absorb_amount")) or tonumber(call(unit,"get_absorbs")) or 0
    local predicted=current
    if maximum>0 then
        predicted=predicted-math.max(0,incoming-absorbs*0.75)/maximum*100
        predicted=predicted+math.min(15,math.max(0,healing)/maximum*100)
    end
    local now=tonumber(call(core,"time")) or 0
    instance.health_samples=instance.health_samples or setmetatable({},{__mode="k"})
    local prior=instance.health_samples[unit]
    if incoming<=0 and prior and now>prior.at then
        local elapsed=now-prior.at
        if elapsed>=0.15 and elapsed<=2 and current<prior.hp then
            predicted=math.min(predicted,current-(prior.hp-current)*math.min(2/elapsed,4))
        end
    end
    instance.health_samples[unit]={hp=current,at=now}
    return math.max(0,math.min(100,predicted))
end

local function lowest(instance)
    local best,best_hp=nil,101
    for _,unit in ipairs(members()) do
        local value=projected_hp(instance,unit)
        if not dead(unit) and value<best_hp then best,best_hp=unit,value end
    end
    return best,best_hp
end

local function settings(spec)
    local prefix="paladin_forever_"..spec.."_"
    local menu=core and core.menu
    if not menu then return {enabled=true,auto_def=true,utility=true,damage=true,auto_buffs=true,
        crowd_control=true,cooldowns=true,mana_conserve=true,racial_defensives=true,freedom_support=true,
        emergency_bop=false,adaptive_seals=true,predictive_health=true,resistance_auras=true,
        crusader_opener=true,auto_salvation=true,
        heal=75,emergency=25,mana_floor=18} end
    return {
        enabled=menu.checkbox(true,prefix.."enabled_v1"),
        damage=menu.checkbox(true,prefix.."damage_v1"),
        auto_def=menu.checkbox(true,prefix.."defensives_v1"),
        utility=menu.checkbox(true,prefix.."utility_v1"),
        auto_buffs=menu.checkbox(true,prefix.."buffs_v1"),
        crowd_control=menu.checkbox(true,prefix.."crowd_control_v1"),
        cooldowns=menu.checkbox(true,prefix.."cooldowns_v1"),
        mana_conserve=menu.checkbox(true,prefix.."mana_conserve_v1"),
        racial_defensives=menu.checkbox(true,prefix.."racial_defensives_v1"),
        freedom_support=menu.checkbox(true,prefix.."freedom_support_v1"),
        emergency_bop=menu.checkbox(false,prefix.."emergency_bop_v1"),
        adaptive_seals=menu.checkbox(true,prefix.."adaptive_seals_v1"),
        predictive_health=menu.checkbox(true,prefix.."predictive_health_v1"),
        resistance_auras=menu.checkbox(true,prefix.."resistance_auras_v1"),
        crusader_opener=menu.checkbox(true,prefix.."crusader_opener_v1"),
        auto_salvation=menu.checkbox(true,prefix.."auto_salvation_v1"),
        heal=menu.slider_int(35,95,spec=="holy" and 82 or 58,prefix.."heal_v1"),
        emergency=menu.slider_int(5,50,25,prefix.."emergency_v1"),
        mana_floor=menu.slider_int(5,40,18,prefix.."mana_floor_v1")
    }
end

local function value(setting,fallback)
    if type(setting)=="boolean" or type(setting)=="number" then return setting end
    local v=call(setting,"get");if v==nil then v=call(setting,"get_state") end
    if v==nil then v=call(setting,"get_value") end
    return v==nil and fallback or v
end

local function cancel_aura(key)
    local id=resolve(key);if not id then return false end
    return call(core and core.input,"cancel_buff",id)==true or call(core and core.input,"cancel_aura",id)==true
end

local function maintain_profile(instance,me)
    if instance.spec~="prot" and aura(me,"RIGHTEOUS_FURY") then cancel_aura("RIGHTEOUS_FURY") end
    if instance.spec=="prot" and aura(me,"SALVATION") then cancel_aura("SALVATION") end
    if combat(me) or not value(instance.config.auto_buffs,true) then return false end
    local desired_aura=instance.spec=="prot" and "DEVOTION_AURA"
        or (instance.spec=="holy" and "CONCENTRATION_AURA" or "RETRIBUTION_AURA")
    if not resolve(desired_aura) then desired_aura="DEVOTION_AURA" end
    -- Restore the profile aura after a temporary combat resistance aura.
    if not aura(me,desired_aura) and cast(desired_aura,me,instance) then return true end
    for _,ally in ipairs(members()) do
        if not any_aura(ally,Data.blessings) then
            local ally_role=role(ally)
            local blessing=(ally_role=="healer" and resolve("BLESSING_WISDOM")) and "BLESSING_WISDOM"
                or (resolve("BLESSING_KINGS") and "BLESSING_KINGS" or "BLESSING_MIGHT")
            if cast(blessing,ally,instance) then return true end
        end
    end
    -- As of the October 15 build, Salvation is independent of Blessings.  Keep
    -- it on non-tanks, but remove it immediately when Protection becomes active.
    if instance.spec~="prot" and value(instance.config.auto_salvation,true)
        and resolve("SALVATION") and not aura(me,"SALVATION")
        and cast("SALVATION",me,instance) then return true end
    return false
end

local function control_cast(instance,me,foe)
    if not value(instance.config.crowd_control,true) or not valid(foe) then return false end
    local casting=call(foe,"is_casting")==true or call(foe,"is_channeling")==true
    if call(foe,"is_stun_immune")==true or call(foe,"is_immune_to_stun")==true then return false end
    return casting and distance(me,foe)<=10 and cast("HAMMER_JUSTICE",foe,instance) or false
end

local function cast_school_aura(instance,me,foe)
    if not value(instance.config.resistance_auras,true) or not valid(foe)
        or (call(foe,"is_casting")~=true and call(foe,"is_channeling")~=true) then return false end
    local school=call(foe,"get_cast_spell_school") or call(foe,"get_cast_school")
        or call(foe,"get_spell_school")
    local text=tostring(school or ""):lower()
    local numeric=tonumber(school)
    local desired=(text:find("shadow",1,true) or (numeric and numeric%64>=32)) and "SHADOW_RESIST_AURA"
        or (text:find("frost",1,true) or (numeric and numeric%32>=16)) and "FROST_RESIST_AURA"
        or (text:find("fire",1,true) or (numeric and numeric%8>=4)) and "FIRE_RESIST_AURA" or nil
    if not desired or not resolve(desired) or aura(me,desired) then return false end
    local now=tonumber(call(core,"time")) or 0
    if now<(instance.next_resistance_swap or -math.huge) then return false end
    if cast(desired,me,instance) then instance.next_resistance_swap=now+8;return true end
    return false
end
local function common(instance,me)
    local cfg=instance.config
    if value(cfg.racial_defensives,true) then
        if state(me,"is_feared","is_charmed","is_asleep") and cast("WILL_FORSAKEN",me,instance) then return true end
        if state(me,"is_stunned") and cast("WILL_SURVIVE",me,instance) then return true end
        if (has_debuff_kind(me,"bleed","poison","disease") or (combat(me) and hp(me)<=30))
            and cast("STONEFORM",me,instance) then return true end
    end
    if value(cfg.auto_def,true) then
        local health=value(cfg.predictive_health,true) and projected_hp(instance,me) or hp(me)
        if health<=18 and cast("LAY_HANDS",me,instance) then return true end
        if not aura(me,"FORBEARANCE") then
            if instance.spec=="prot" and health<=35 and cast("TEMPLAR_BULWARK",me,instance) then return true end
            if health<=12 and cast("DIVINE_SHIELD",me,instance) then return true end
            if health<=45 and cast("DIVINE_PROTECTION",me,instance) then return true end
        end
    end
    if value(cfg.utility,true) then
        for _,ally in ipairs(members()) do
            if value(cfg.freedom_support,true) and movement_impaired(ally)
                and not aura(ally,"BLESSING_FREEDOM") and cast("BLESSING_FREEDOM",ally,instance) then return true end
            local magic=has_debuff_kind(ally,"magic")
            local poison_or_disease=has_debuff_kind(ally,"poison","disease")
            if magic and cast("CLEANSE",ally,instance) then return true end
            if poison_or_disease and (cast("CLEANSE",ally,instance) or cast("PURIFY",ally,instance)) then return true end
        end
        if value(cfg.emergency_bop,false) then
            for _,ally in ipairs(members()) do
                if ally~=me and hp(ally)<=12 and role(ally)~="tank" and not aura(ally,"FORBEARANCE")
                    and cast("BLESSING_PROTECTION",ally,instance) then return true end
            end
        end
    end
    return false
end

local function holy(instance,me)
    local ally,health=lowest(instance);if not ally then return false end
    if health<=value(instance.config.emergency,25) and cast("LAY_HANDS",ally,instance) then return true end
    if health<=value(instance.config.heal,82) then
        local pressured=0
        for _,unit in ipairs(members()) do
            local unit_hp=value(instance.config.predictive_health,true) and projected_hp(instance,unit) or hp(unit)
            if unit_hp<72 then pressured=pressured+1 end
        end
        if value(instance.config.cooldowns,true) and pressured>=3 and hp(me)>70
            and not aura(me,"FORBEARANCE") and cast("AVENGING_WRATH",me,instance) then return true end
        if value(instance.config.cooldowns,true) and (health<=42 or pressured>=3)
            and mana(me)>=35 and not group_has_aura("LIGHTS_VIGIL")
            and cast("LIGHTS_VIGIL",ally,instance) then return true end
        if health<=38 and cast("DIVINE_FAVOR",me,instance) then return true end
        -- Forever Infusion shortens Holy Light after a Holy Shock or Flash of
        -- Light critical. Spend it before another Holy Shock can overwrite it.
        if aura(me,"INFUSION_LIGHT") and health<=72
            and cast("HOLY_LIGHT",ally,instance) then return true end
        if cast("HOLY_SHOCK",ally,instance) then return true end
        if health<=58 then
            local conserve=value(instance.config.mana_conserve,true)
                and mana(me)<=value(instance.config.mana_floor,18) and health>42
            if cast("HOLY_LIGHT",ally,instance,conserve and 0.72 or false) then return true end
        end
        local conserve=value(instance.config.mana_conserve,true)
            and mana(me)<=value(instance.config.mana_floor,18) and health>value(instance.config.emergency,25)
        -- While levelling, down-rank more aggressively when the deficit is small;
        -- emergency healing always retains the highest learned rank.
        local rank_fraction=conserve and ((instance.level or 60)<40 and 0.75 or 0.60) or false
        if cast("FLASH_LIGHT",ally,instance,rank_fraction) then return true end
    end
    local foe=target()
    if value(instance.config.damage,true) and valid(foe) and enemy(foe) and combat(me) then
        return (hp(foe)<=20 and cast("HAMMER_WRATH",foe,instance))
            or cast("HOLY_SHOCK",foe,instance) or cast("JUDGEMENT",foe,instance)
            or cast("HOLY_STRIKE",foe,instance)
            or (holy_target(foe) and cast("EXORCISM",foe,instance))
            or (mana(me)>=55 and nearby_enemies(instance,me,8)>=3 and cast("CONSECRATION",me,instance))
    end
    return false
end

local function prot(instance,me)
    local foe=loose_enemy(instance,me) or target()
    if not aura(me,"RIGHTEOUS_FURY") and cast("RIGHTEOUS_FURY",me,instance) then return true end
    if not aura(me,"SEAL_FURY") and cast("SEAL_FURY",me,instance) then return true end
    if (combat(me) or (valid(foe) and enemy(foe) and distance(me,foe)<=12))
        and not aura(me,"HOLY_SHIELD") and cast("HOLY_SHIELD",me,instance) then return true end
    if not valid(foe) or not enemy(foe) then return false end
    if cast_school_aura(instance,me,foe) then return true end
    if control_cast(instance,me,foe) then return true end
    -- Judgement while Seal of Fury is active is the Forever taunt.
    if call(foe,"is_targeting_player")==false then
        if cast("JUDGEMENT",foe,instance) then
            instance.taunt_follow=foe;instance.taunt_follow_until=(tonumber(call(core,"time")) or 0)+2.5;return true
        end
        if cast("SWIFT_JUDGEMENT",me,instance) then instance.taunt_target=foe;return true end
    elseif instance.taunt_target and valid(instance.taunt_target) then
        if cast("JUDGEMENT",instance.taunt_target,instance) then
            instance.taunt_follow=instance.taunt_target
            instance.taunt_follow_until=(tonumber(call(core,"time")) or 0)+2.5
            instance.taunt_target=nil;return true
        end
    end
    if instance.taunt_follow and valid(instance.taunt_follow)
        and (tonumber(call(core,"time")) or 0)<(instance.taunt_follow_until or 0) then foe=instance.taunt_follow
    else instance.taunt_follow=nil end
    -- Improved Seal of Fury makes Holy Strike a six-second mitigation window;
    -- keep it ahead of throughput buttons whenever it is learned and ready.
    return cast("HOLY_STRIKE",foe,instance) or cast("HAMMER_RIGHTEOUS",foe,instance)
        or ((not instance.level or instance.level>=20) and nearby_enemies(instance,me,8)>=2
            and cast("CONSECRATION",me,instance))
        or (nearby_enemies(instance,me,20,true)>=2 and mana(me)>=45 and cast("HOLY_WRATH",me,instance))
        or cast("JUDGEMENT",foe,instance)
end

local function ret(instance,me)
    local foe=target();if not valid(foe) or not enemy(foe) then return false end
    if control_cast(instance,me,foe) then return true end
    if cast_school_aura(instance,me,foe) then return true end
    if value(instance.config.adaptive_seals,true) then
        local health,power=hp(me),mana(me)
        if instance.recovery_seal=="SEAL_LIGHT" and health>=55 then instance.recovery_seal=nil end
        if instance.recovery_seal=="SEAL_WISDOM" and power>=30 then instance.recovery_seal=nil end
        if not instance.recovery_seal then
            if health<=35 and resolve("SEAL_LIGHT") then instance.recovery_seal="SEAL_LIGHT"
            elseif power<=15 and resolve("SEAL_WISDOM") then instance.recovery_seal="SEAL_WISDOM" end
        end
        local desired=instance.recovery_seal
        if desired and not aura(me,desired) then
            local now=tonumber(call(core,"time")) or 0
            if now>=(instance.next_seal_swap or -math.huge) and cast(desired,me,instance) then
                instance.next_seal_swap=now+4;return true
            end
        end
    end
    local long_fight=call(foe,"is_boss")==true or call(foe,"is_elite")==true
    if (not instance.level or instance.level>=20) and value(instance.config.crusader_opener,true)
        and long_fight and not instance.recovery_seal
        and resolve("SEAL_CRUSADER") and mana(me)>=25 then
        local now=tonumber(call(core,"time")) or 0
        local needs_judgement=instance.crusader_target~=foe
            or (not resolve("SACRED_ARBITER") and now-(instance.crusader_judged_at or -math.huge)>=35)
        if instance.crusader_stage_target and instance.crusader_stage_target~=foe then
            instance.crusader_stage_target=nil
        end
        if needs_judgement and not instance.crusader_stage_target then
            if cast("SEAL_CRUSADER",me,instance) then instance.crusader_stage_target=foe;return true end
        elseif instance.crusader_stage_target==foe then
            if not aura(me,"SEAL_CRUSADER") then
                if cast("SEAL_CRUSADER",me,instance) then return true end
            elseif cast("JUDGEMENT",foe,instance) then
                instance.crusader_target=foe;instance.crusader_judged_at=now
                instance.crusader_stage_target=nil;instance.next_seal_swap=now+1.5;return true
            end
            -- Keep the Crusader seal until Judgement is ready; replacing it here
            -- would make the next Judgement use the wrong seal effect.
            return false
        end
    end
    if not instance.recovery_seal and not aura(me,"SEAL_COMMAND") and not aura(me,"SEAL_RIGHTEOUSNESS") then
        local speed=weapon_speed(me)
        local preferred=(speed and speed<3.0) and "SEAL_RIGHTEOUSNESS" or "SEAL_COMMAND"
        local fallback=preferred=="SEAL_COMMAND" and "SEAL_RIGHTEOUSNESS" or "SEAL_COMMAND"
        if cast(preferred,me,instance) or cast(fallback,me,instance) then return true end
    end
    if hp(foe)<=20 and cast("HAMMER_WRATH",foe,instance) then return true end
    if value(instance.config.cooldowns,true) and call(foe,"is_boss")==true and hp(me)>80
        and not aura(me,"FORBEARANCE") and cast("AVENGING_WRATH",me,instance) then return true end
    -- Establish Judgement first; Sacred Arbiter then lets Holy Strike refresh it.
    return cast("JUDGEMENT",foe,instance) or cast("HOLY_STRIKE",foe,instance)
        or cast("HOLY_SHOCK",foe,instance)
        or (mana(me)>=((instance.level or 60)<40 and 60 or 45)
            and nearby_enemies(instance,me,8)>=((instance.level or 60)<40 and 4 or 3)
            and cast("CONSECRATION",me,instance))
        or (nearby_enemies(instance,me,20,true)>=2 and mana(me)>=55 and cast("HOLY_WRATH",me,instance))
        or (holy_target(foe) and cast("EXORCISM",foe,instance))
end

local function tick(instance)
    local now=tonumber(call(core,"time")) or 0
    if now<(instance.next_tick or -math.huge) then return end
    instance.next_tick=now+0.05
    if not value(instance.config.enabled,true) then return end
    local me=player();if not valid(me) or dead(me) then return end
    instance.level=level(me)
    local in_combat=combat(me)
    if instance.was_in_combat and not in_combat then
        instance.taunt_target=nil;instance.taunt_follow=nil;instance.crusader_stage_target=nil
        instance.health_samples=setmetatable({},{__mode="k"})
    end
    instance.was_in_combat=in_combat
    if maintain_profile(instance,me) then return end
    if common(instance,me) then return end
    if instance.spec=="holy" then holy(instance,me)
    elseif instance.spec=="prot" then prot(instance,me) else ret(instance,me) end
    instance.logger.heartbeat("profile="..instance.spec.."; last_action="..instance.last_action)
end

local function render_menu(instance)
    local menu=core and core.menu;if not menu or type(menu.text)~="function" then return end
    menu.text("PALADIN TRINITY - WOW FOREVER")
    menu.text("Profile: "..string.upper(instance.spec).." | Level: "..tostring(instance.level or "?")
        .." | Data: "..Data.data_build)
    menu.text("Talent aware: only learned spell ranks are considered")
    menu.text("Last action: "..instance.last_action)
    for _,row in ipairs({{"Enabled",instance.config.enabled},{"Damage",instance.config.damage},
        {"Automatic defensives",instance.config.auto_def},{"Utility",instance.config.utility},
        {"Auras and blessings",instance.config.auto_buffs},{"Stun dangerous casts",instance.config.crowd_control},
        {"Major cooldowns",instance.config.cooldowns},{"Mana conservation",instance.config.mana_conserve},
        {"Racial defensives",instance.config.racial_defensives},{"Freedom support",instance.config.freedom_support},
        {"Emergency Blessing of Protection",instance.config.emergency_bop},{"Adaptive recovery seals",instance.config.adaptive_seals},
        {"Predictive health triage",instance.config.predictive_health},{"Cast-school resistance auras",instance.config.resistance_auras},
        {"Crusader Judgement boss opener",instance.config.crusader_opener},
        {"Automatic Salvation (non-tank)",instance.config.auto_salvation},
        {"Heal threshold",instance.config.heal},{"Emergency threshold",instance.config.emergency},
        {"Mana reserve",instance.config.mana_floor}}) do
        if type(row[2])~="boolean" and type(row[2])~="number" then call(row[2],"render",row[1]) end
    end
end

function R.start(spec)
    local instance={spec=spec,config=settings(spec),logger=Logger.new(spec),last_action="ready",
        next_tick=-math.huge,level=nil}
    R.instances[spec]=instance
    if type(core.register_on_update_callback)=="function" then core.register_on_update_callback(function() tick(instance) end) end
    if type(core.register_on_render_menu_callback)=="function" then
        core.register_on_render_menu_callback(function() render_menu(instance) end)
    end
    return instance
end
return R
