local Settings=require("guardian_settings")
local Aura=require("guardian_aura")
local Threat=require("guardian_threat")
local BigWigs=require("guardian_bigwigs")
local Prediction=require("guardian_prediction")
local PvP=require("guardian_pvp")
local Combat=require("guardian_combat")
local Mode=require("guardian_mode")
local Log=require("guardian_log")
local Dummy=require("guardian_dummy")
local Objects=require("guardian_objects")
local enums=require("common/enums")
local RAGE=enums.power_type.RAGE
local S={bear=5487, moonfire=8921, moonfire_dot=164812, thrash=77758,
    thrash_dot=192090, mangle=33917, swipe=213771, maul=6807, raze=400254,
    ravage=441605, ravage_talent=441583, galactic=213708, flashing=393427,
    ironfur=192081, regen=22842, natural_resilience=1278789, fount_strength=441675, barkskin=22812, survival=61336,
    berserk=50334, incarnation=102558, beam=204066, red_moon=1252871,
    skull_bash=106839, growl=6795, lunation=429539, dream=372152, regrowth=8936,
    soothe=2908, incap_roar=99, typhoon=132469, mark=1126, remove_corruption=2782, rebirth=20484}
local attempts={pre_regen_until=0}
local accepted_requests={}
local manual_yield_until=-math.huge
local failures,retry_until={},{}
local next_retry_cleanup=0
local failure_log_until={}
local last_gcd=-math.huge
local last_defensive_request=-math.huge
local growl_target,growl_pressure_until=nil,-math.huge
local combat_started_at=nil
local combat_landing=false
local function stop_combat_landing()
    if not combat_landing then return end
    pcall(core.input.descend_stop)
    pcall(core.input.move_down_stop)
    pcall(core.input.ascend_stop)
    combat_landing=false
end
local function valid(u) return u and u:is_valid() and not u:is_dead() end
local function npc_id(u)
    if not u or type(u.get_npc_id)~="function" then return 0 end
    local ok,value=pcall(u.get_npc_id,u)
    return ok and tonumber(value) or 0
end
local function known(id)
    local ok,value=pcall(core.spell_book.is_spell_known,id)
    return ok and value==true
end
local function resolved(id)
    if core.spell_book.get_override_spell_id then
        local ok,v=pcall(core.spell_book.get_override_spell_id,id)
        -- The client can expose a talent override before that replacement is
        -- actually learned. Never send an unavailable override to the caster.
        if ok and tonumber(v) and v>0 and (v==id or known(v)) then return v end
    end
    return id
end
local function usable(id)
    local ok,value=pcall(core.spell_book.is_usable_spell,id)
    return ok and value==true
end
local function cooldown(id)
    local ok,value=pcall(core.spell_book.get_spell_cooldown,id)
    return ok and (tonumber(value) or math.huge) or math.huge
end
local function cast(id,target,player,off_gcd)
    local now=core.time()
    if now>=next_retry_cleanup then
        next_retry_cleanup=now+30
        for stale,deadline in pairs(retry_until) do
            if now>deadline+60 then retry_until[stale]=nil; failures[stale]=nil end
        end
    end
    local base_known=known(id)
    local spell=resolved(id)
    local direct_damage=id==S.mangle or id==S.moonfire or id==S.red_moon or id==S.maul or id==S.raze or id==S.beam
    local area_damage=id==S.thrash or id==S.swipe or id==S.raze or id==S.beam or id==S.typhoon
    if direct_damage and target~=player and Combat.damage_blocked(target) then return false end
    if area_damage and Combat.control_nearby(player,10) then return false end

    local key=tostring(spell)..":"..tostring(Aura.guid(target) or "none")
    if not base_known and not known(spell) then return false end
    if core.time()<(retry_until[key] or 0) then return false end
    if core.time()-(attempts[spell] or -math.huge)<0.7 then return false end
    local charged=false
    if core.spell_book.get_spell_charge then
        local ok,value=pcall(core.spell_book.get_spell_charge,spell); charged=ok and (tonumber(value) or 0)>0
    end
    if not usable(spell) or not charged and cooldown(spell)>0.1 then return false end
    if not off_gcd and core.time()-last_gcd<0.2 then return false end
    if target~=player and core.spell_book.is_spell_in_range then
        local ok,in_range=pcall(core.spell_book.is_spell_in_range,spell,target,player)
        -- Missing or temporarily unreadable range data is unknown. Let the
        -- cast request decide; only explicit false proves the target is out.
        if ok and in_range==false then return false end
    end
    if target~=player and core.graphics and type(core.graphics.is_line_of_sight)=="function" then
        local ok,los=pcall(core.graphics.is_line_of_sight,player,target)
        if ok and los==false then return false end
    end
    attempts[spell]=core.time()
    local requested,accepted=pcall(core.input.cast_target_spell,spell,target)
    if requested and accepted then
        accepted_requests[spell]=core.time()
        failures[key]=0
        local utility_delay=(id==S.rebirth and 8) or ((id==S.remove_corruption or id==S.soothe) and 2) or 0.2
        retry_until[key]=core.time()+utility_delay
        if not off_gcd then last_gcd=core.time() end
        Settings.status="Cast "..tostring(spell)
        local category=spell==resolved(S.skull_bash) and "INTERRUPT" or spell==resolved(S.growl) and "TAUNT"
            or (spell==resolved(S.barkskin) or spell==resolved(S.survival) or spell==resolved(S.regen) or spell==resolved(S.ironfur)) and "DEFENSIVE"
            or spell==resolved(S.rebirth) and "RECOVERY" or nil
        if category then Log.record("ACTION",category,"cast_accepted",{spell=spell,target=Aura.guid(target) or "none"}) end
        return true
    end
    local streak=math.min(4,(failures[key] or 0)+1)
    local retry=math.min(3,0.4*2^(streak-1))
    failures[key]=streak; retry_until[key]=core.time()+retry
    if now>=(failure_log_until[spell] or -math.huge) then
        failure_log_until[spell]=now+5
        local maximum=player:get_max_health()
        Log.record("WARN","CAST","request_declined",{spell=spell,target=Aura.guid(target),streak=streak,retry_seconds=retry,
            hp=maximum>0 and math.floor(player:get_health()*100/maximum) or 0})
    end
    if Settings.on("auto_face") and target~=player then Combat.face_if_needed(player,target) end
    return false
end

local function on_confirm(data,player)
    if type(data)~="table" or Aura.guid(data.caster)~=Aura.guid(player) then return end
    local spell=tonumber(data.spell_id)
    if not spell then return end
    local requested=accepted_requests[spell]
    if requested and core.time()-requested<=3 then
        accepted_requests[spell]=nil
        return
    end
    if Settings.on("manual_yield") then manual_yield_until=core.time()+0.6 end
end

local function manual_yielding()
    return Settings.on("manual_yield") and core.time()<manual_yield_until
end
local function emergency_stop(p,target)
    if cast(S.incap_roar,p,p) then return true end
    -- Typhoon is directional. Confirm facing before sending it when the
    -- client explicitly reports that the chosen caster is behind the player.
    if target and not Combat.ensure_facing(p,target,Settings.on("auto_face")) then return false end
    return cast(S.typhoon,p,p)
end
local function active(p,id,grace)
    return Aura.read(p,id) or Aura.since(id)<(grace or 0.7)
end
local function rage_cost(id,p)
    if not core.spell_book.get_spell_costs then return nil end
    local ok,costs=pcall(core.spell_book.get_spell_costs,resolved(id))
    if not ok or type(costs)~="table" or #costs==0 then return nil end
    local best=nil
    for _,entry in ipairs(costs) do
        local required=tonumber(entry.required_buff_id) or 0
        if tonumber(entry.cost_type)==RAGE and (required==0 or Aura.read(p,required)) then
            -- Zero absolute cost can also mean a percentage or channel drain.
            -- Only an applicable, absolute Rage entry proves a free proc.
            local percent,drain=tonumber(entry.cost_percent) or 0,tonumber(entry.cost_per_sec) or 0
            local amount=tonumber(entry.cost)
            if percent~=0 or drain~=0 then return nil end
            if amount and amount>=0 then
                amount=math.max(amount,tonumber(entry.min_cost) or 0)
                if not best or amount<best then best=amount end
            end
        end
    end
    return best
end
local function major_defensive(p,severe,catastrophic)
    local bark,survival=active(p,S.barkskin,8),active(p,S.survival,5)
    if survival or bark and not (catastrophic and severe)
        or core.time()-last_defensive_request<=3 and not catastrophic then return false end
    local success=severe and cast(S.survival,p,p,true) or false
    if not success then success=cast(S.barkskin,p,p,true) end
    if success then last_defensive_request=core.time() end
    return success
end
local EXTERNALS={102342,33206,6940} -- confirmed damage-reduction externals only
local ttd_samples={}
local function external_active(p)
    for _,id in ipairs(EXTERNALS) do if Aura.read(p,id) then return true end end
    return false
end
local function target_ttd(target)
    if target and type(target.get_time_to_die)=="function" then
        local ok,value=pcall(target.get_time_to_die,target);value=ok and tonumber(value)or nil
        if value and value>0 and value<3600 then return value end
    end
    if not valid(target) then return nil end
    local id=Aura.guid(target)or tostring(target)
    local ok,health,maximum=pcall(function()return tonumber(target:get_health()),tonumber(target:get_max_health())end)
    if not ok or not health or not maximum or maximum<=0 or health<=0 then return nil end
    local now=core.time();local row=ttd_samples[id]
    if not row or row.maximum~=maximum or now-row.at>4 or health>row.health then
        local retained=0
        for key,sample in pairs(ttd_samples)do
            if now-(sample.at or 0)>30 then ttd_samples[key]=nil else retained=retained+1 end
        end
        if retained>80 then ttd_samples={}end
        ttd_samples[id]={at=now,health=health,maximum=maximum,loss=0};return nil
    end
    local elapsed=now-row.at
    if elapsed>=0.25 then
        local raw=math.max(0,(row.health-health)/elapsed)
        local weight=1-math.exp(-elapsed/1.25)
        row.loss=row.loss*(1-weight)+raw*weight;row.at,row.health=now,health
    end
    return row.loss>0 and health/row.loss or nil
end
local function target_classification(target)
    if target and type(target.get_classification)=="function" then
        local ok,value=pcall(target.get_classification,target)
        if ok then return tonumber(value) end
    end
end
local function should_burst(target,count,forecast,pack)
    -- Immediate pressure outranks saving resources for a future pull.
    if forecast and forecast.danger>=45 then return true,"high predicted pressure" end
    local ttd=target_ttd(target)
    local lifetime_reason="target expected to die soon"
    if count>1 then
        local longest,all_known=0,true
        for _,enemy in ipairs(pack or {}) do
            local value=target_ttd(enemy)
            if not value or value<=0 then all_known=false else longest=math.max(longest,value) end
        end
        ttd=all_known and longest>0 and longest or nil
        lifetime_reason="whole pack expected to die soon"
    end
    if ttd and ttd>0 and ttd<8 then return false,lifetime_reason end
    if Combat.is_boss(target) or count>=Settings.value("cooldown_min_enemies") then return true,"boss/large pull" end
    if ttd and ttd>=Settings.value("cooldown_ttd") then return true,"long-lived elite" end
    local route=Settings.route_context
    local belongs=route and (tonumber(route.confidence) or 0)>=70 and route.guids and route.guids[Aura.guid(target)]
    if belongs and route.cooldown_recommended then return true,"dangerous route pull" end
    if belongs and route.next_cooldown_recommended then return false,"saving for the next dangerous pull" end
    if Mode.is_delve() and count>=2 then return true,"delve elite/pack" end
    -- Respect the configured pack-size floor for an ordinary lone enemy when
    -- there is no stronger route or lifetime evidence. Elites still release.
    if not route and count<Settings.value("cooldown_min_enemies")
        and not Combat.is_boss(target) and target_classification(target)==0 and not ttd then
        return false,"holding burst for a larger pull"
    end
    return true,"maximizing cooldown uses"
end
local function enemies(p,target,radius)
    local result,seen={},{}
    local a=p:get_position()
    for _,u in pairs(Objects.get()) do
        local ok,engaged=pcall(function()
            if not valid(u) or not u:is_unit() or not p:can_attack(u) then return false end
            if Settings.on("dummy_test") and u==target and Dummy.selected(p,u,5) then return true end
            local victim=u.get_target and u:get_target()
            if Threat.same(victim,p) or victim and victim.is_party_member and victim:is_party_member() then return true end
            local threat=p.get_threat_situation and p:get_threat_situation(u)
            return type(threat)=="table" and (threat.is_tanking==true or (tonumber(threat.status) or 0)>0)
        end)
        local identity=Aura.guid(u) or tostring(u)
        if ok and engaged and not seen[identity] and npc_id(u)~=257846 then
            local b=u:get_position()
            if b and (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=(radius or 8)^2 then
                seen[identity]=true; result[#result+1]=u
            end
        end
    end
    return result
end
local function dot_due(target,id,spell,p,refresh)
    local has,remaining=Aura.read(target,id,true,p)
    if has then return remaining and remaining<refresh or false end
    -- A confirmed cast is a short fallback when aura values are hidden.
    -- Do not infer absence on every tick and starve the rest of the rotation.
    return Aura.since(spell,target)>8
end
local function update()
    if not Settings.allowed() then stop_combat_landing(); Settings.status="Off / waiting for Guardian"; return end
    if not Settings.on("combat") then stop_combat_landing(); Settings.status="Combat off"; return end
    local p=core.object_manager.get_local_player()
    local mode=Mode.update(p); Settings.mode_status=mode.label..(mode.dead>0 and (" ("..mode.dead.." down)") or "")
    local selected=p:get_target()
    local practice=Settings.on("dummy_test") and Dummy.selected(p,selected,5)
    if not p:is_in_combat() and not practice then
        stop_combat_landing(); combat_started_at=nil
        growl_target,growl_pressure_until=nil,-math.huge
        Prediction.reset(); Threat.reset()
        if Settings.on("auto_mark") and not p:is_casting_spell() and not p:is_channelling_spell()
            and not active(p,S.mark,60) and cast(S.mark,p,p) then Settings.status="Applied Mark of the Wild"; return end
        if Settings.on("remove_corruption") and not p:is_casting_spell() and not p:is_channelling_spell() then
            local dispel=Combat.select_dispel(p)
            if dispel and Aura.since(S.remove_corruption,dispel)>2 and cast(S.remove_corruption,dispel,p) then Combat.utility="Removed confirmed Poison/Curse"; return end
        end
        Settings.status="Ready"; return
    end
    -- Entering combat during flight must not cancel Travel/Flight Form in mid-air.
    -- Remove horizontal/ascending input and descend vertically.  Every combat
    -- action stays behind this gate until the client confirms we are grounded.
    if p:is_flying() then
        local maximum=tonumber(p:get_max_health()) or 0
        local airborne_hp=maximum>0 and p:get_health()*100/maximum or 100
        -- Barkskin is form-safe and off the global cooldown. Protect an
        -- injured descent without cancelling Flight Form in mid-air.
        if Settings.on("defensives") and airborne_hp<=Settings.value("barkskin_hp") then
            major_defensive(p,false)
        end
        combat_landing=true
        pcall(core.input.move_forward_stop)
        pcall(core.input.ascend_stop)
        pcall(core.input.descend_start)
        Settings.status="Combat: descending safely before Bear Form"
        return
    end
    if combat_landing then
        stop_combat_landing()
        Settings.status="Combat: grounded; entering Bear Form"
    end
    if not combat_started_at then combat_started_at=core.time() end
    if p:is_casting_spell() or p:is_channelling_spell() then
        -- Barkskin is usable in every form, off the global cooldown, and does
        -- not need the damage rotation to interrupt the player's current cast.
        local casting_hp=p:get_max_health()>0 and p:get_health()*100/p:get_max_health() or 100
        local casting_form=core.spell_book.get_shapeshift_form_id()
        local severe=casting_hp<=Settings.value("survival_hp") and (casting_form==5 or casting_form==8 or active(p,S.bear))
        local casting_timer=Settings.on("bigwigs_defensives") and BigWigs.scan(1.2) or nil
        local imminent_tank=casting_timer and casting_timer.kind=="tank" and casting_timer.remaining<=1.2
        if Settings.on("defensives") and (casting_hp<=Settings.value("barkskin_hp") or severe or imminent_tank)
            and major_defensive(p,severe) then
            Settings.status=imminent_tank and "Predictive Barkskin while casting" or "Emergency defensive while casting"
        end
        return
    end
    local form=core.spell_book.get_shapeshift_form_id()
    local bear=form==5 or form==8 or active(p,S.bear)
    if not bear then
        if Settings.on("auto_bear") then cast(S.bear,p,p) end
        Settings.status="Waiting for Bear Form"
        return
    end
    local hp=p:get_max_health()>0 and p:get_health()*100/p:get_max_health() or 100
    if Settings.on("defensives") and PvP.act(p,S,cast,hp) then Settings.status="PvP pressure response"; return end
    local rage=tonumber(p:get_power(RAGE)) or 0
    local target=selected
    local interrupted=false
    if npc_id(target)==257846 then
        for _,unit in pairs(Objects.get()) do
            if valid(unit) and npc_id(unit)==251600 then target=unit; break end
        end
    end
    if Settings.on("interrupts") then
        local caster=Combat.select_interrupt(p,target,13,Settings.value("interrupt_percent"))
        if caster then
            interrupted=cast(S.skull_bash,caster,p,true)
            if not interrupted then Combat.mark_interrupt_failed(caster) end
        end
    end
    local forecast=nil
    if Settings.on("defensives") then
        forecast=Settings.on("prediction") and Prediction.evaluate(p,Settings.value("prediction_window"),
            Settings.on("bigwigs_defensives"),Settings.value("bigwigs_lead")) or nil
        local timer=forecast and forecast.timer or BigWigs.scan(Settings.value("bigwigs_lead"))
        Settings.bigwigs_status=BigWigs.status
        local hazard_distance=forecast and forecast.encounter_add_distance
        local severe=hp<=Settings.value("survival_hp") or (forecast and (forecast.projected_pct<=Settings.value("prediction_survival")
            or forecast.time_to_die<=2.2 or forecast.danger>=55
            or hazard_distance and hazard_distance<=7 and hp<=60))
            or timer and timer.kind=="tank" and timer.remaining<=1.2 and hp<=70
        local elevated=timer or forecast and (forecast.projected_pct<=Settings.value("barkskin_hp")
            or forecast.danger>=28 or hazard_distance and hazard_distance<=15)
        local route_retry=Settings.route_context and (Settings.route_context.confidence or 0)>=70
            and (Settings.route_context.failures or 0)>0 and Settings.route_context.guids
            and Settings.route_context.guids[Aura.guid(target)]==true
        -- The opening seconds of a pack are dangerous before rage and Ironfur
        -- are established.  Use the short Barkskin cooldown on real packs.
        if forecast and forecast.enemy_count>=3 and core.time()-combat_started_at<=2 then
            elevated=true
        end
        -- A previously failed, confidently identified pull receives measured
        -- re-entry protection without affecting unrelated nearby enemies.
        if forecast and forecast.enemy_count>0 and route_retry and core.time()-combat_started_at<=3 then
            elevated=true
        end
        if external_active(p) and hp>Settings.value("survival_hp") and forecast
            and forecast.projected_pct>Settings.value("prediction_survival")
            and forecast.time_to_die>1.5 and forecast.danger<70 then severe=false end
        local catastrophic=forecast and (forecast.projected_pct<=10 or forecast.time_to_die<=0.9 or forecast.danger>=85)
        if (severe or elevated) and major_defensive(p,severe,catastrophic) then
            if timer then Settings.status=string.format("Predictive defense: %s in %.1fs",timer.text,timer.remaining)
            else Settings.status=string.format("Predictive defense: %.0f%% projected HP",forecast and forecast.projected_pct or hp) end
        end
        -- Request throttling is separate from confirmed aura evidence.
        if hp<=Settings.value("barkskin_hp") or hp<=Settings.value("survival_hp") then
            major_defensive(p,hp<=Settings.value("survival_hp"))
        end
        if forecast and forecast.healer_unavailable and forecast.enemy_count>0 and hp<=85 then major_defensive(p,false) end
        local regen_at=forecast and forecast.projected_pct or hp
        local recovery_margin=forecast and (forecast.healer_unavailable and 10 or forecast.healer_low and 5 or 0) or 0
        if (Settings.on("dream_heal") or Settings.on("dream_ally")) and Aura.read(p,S.dream)
            and core.spell_book.get_spell_cast_time then
            local ok,duration=pcall(core.spell_book.get_spell_cast_time,resolved(S.regrowth))
            if ok and duration==0 then
                local urgent_self=hp<=Settings.value("survival_hp") or forecast and forecast.projected_pct<=Settings.value("prediction_survival")
                if urgent_self and Settings.on("dream_heal") and cast(S.regrowth,p,p) then
                    Combat.utility="Emergency Dream self-heal"; return
                end
                local ally,ally_hp=Combat.lowest_ally(p,40)
                local dream_stacks=Aura.stacks(p,S.dream) or 1
                if Settings.on("dream_ally") and ally and ally~=p
                    and (ally_hp<=Settings.value("dream_ally_hp") or dream_stacks>=4 and ally_hp<90)
                    and cast(S.regrowth,ally,p) then Combat.utility="Dream Regrowth on injured ally"; return end
                if Settings.on("dream_heal") and hp<=Settings.value("regen_hp") and cast(S.regrowth,p,p) then return end
            end
        end
        -- Early regeneration is restricted to verified tank damage and supporting talents.
        if Settings.on("pre_regen") and timer and timer.kind=="tank" and timer.school~="unknown"
            and timer.remaining>0 and timer.remaining<=1.5 and hp>Settings.value("regen_hp")
            and (known(S.natural_resilience) or known(S.fount_strength))
            and core.time()>=(attempts.pre_regen_until or 0) and not active(p,S.regen,3)
            and cast(S.regen,p,p) then
            attempts.pre_regen_until=core.time()+8
            Combat.utility="Preparing regeneration for "..timer.text
            return
        end
        if (hp<=Settings.value("regen_hp") or regen_at<=math.min(90,Settings.value("prediction_regen")+recovery_margin)) and not active(p,S.regen,3)
            and cast(S.regen,p,p) then return end
    end
        local recovery_forecast=Settings.on("combat_rebirth") and Prediction.evaluate(p,3,Settings.on("bigwigs_defensives"),Settings.value("bigwigs_lead"))
        if Settings.on("combat_rebirth") and hp>=Settings.value("rebirth_min_hp")
            and recovery_forecast and recovery_forecast.danger<38 and recovery_forecast.projected_pct>55
            and recovery_forecast.targeted_casts==0 and not recovery_forecast.timer then
            local corpse=Combat.select_rebirth(p,40)
            if corpse and cast(S.rebirth,corpse,p) then Combat.utility="Rebirth on fallen party member"; return end
        end
    if Settings.on("remove_corruption") then
        local dispel=Combat.select_dispel(p)
        if dispel and Aura.since(S.remove_corruption,dispel)>2 and cast(S.remove_corruption,dispel,p) then Combat.utility="Removed confirmed Poison/Curse"; return end
    end
    local loose
    if not practice and (Settings.on("auto_taunt") or Settings.on("threat_switch")) then
        -- Growl's live range is 30 yd.  Its post-taunt threat bonus lasts six
        -- seconds, so keep attacking the recovered enemy for that full window.
        local selected
        selected,loose=Combat.select_damage_target(p,target,math.min(30,Settings.value("threat_range")))
        if Settings.on("threat_switch") and selected and not Threat.same(selected,target) then
            pcall(core.input.set_target,selected); target=selected
        end
        if Settings.on("auto_taunt") and loose and not Combat.damage_blocked(loose.object)
            and cast(S.growl,loose.object,p,true) then
            growl_target,growl_pressure_until=loose.object,core.time()+6
            Settings.status="Growl: recovered party aggro"
        end
        -- Keep producing threat on the loose enemy even when Growl is unavailable.
        if loose and valid(loose.object) and not Combat.damage_blocked(loose.object) then target=loose.object end
    end
    if not loose and Settings.on("auto_taunt") and Threat.group_active()
        and core.time()<growl_pressure_until and valid(growl_target)
        and p:can_attack(growl_target) and growl_target:is_in_combat() and not Combat.damage_blocked(growl_target) then
        target=growl_target
    elseif core.time()>=growl_pressure_until or not valid(growl_target) then
        growl_target,growl_pressure_until=nil,-math.huge
    end
    if not loose and Settings.on("threat_switch") then
        local risk=Threat.select_at_risk(p,target,math.min(30,Settings.value("threat_range")))
        if risk and valid(risk.object) and not Combat.damage_blocked(risk.object) then
            if not Threat.same(risk.object,target) then pcall(core.input.set_target,risk.object) end
            target=risk.object; Combat.utility="Stabilizing insecure threat"
        end
    end
    local fur,remaining=Aura.read(p,S.ironfur)
    local stacks=Aura.stacks(p,S.ironfur) or ((fur or Aura.since(S.ironfur)<4) and 1 or 0)
    local desired_fur=Settings.value("ironfur_stacks")
    if forecast and (forecast.enemy_count>=4 or forecast.physical) then
        desired_fur=math.min(8,desired_fur+1)
    end
    if forecast and (forecast.party_dead or 0)>0 or forecast and forecast.solo_delve then
        desired_fur=math.min(8,desired_fur+1)
    end
    local retry_route=Settings.route_context
    if retry_route and (retry_route.confidence or 0)>=70 and (retry_route.failures or 0)>0
        and retry_route.guids and retry_route.guids[Aura.guid(target)]==true then
        desired_fur=math.min(8,desired_fur+1)
    end
    local need_fur=Settings.on("defensives") and (stacks<desired_fur or remaining and remaining<1.5)
    local ironfur_cost=rage_cost(S.ironfur,p)
    local free_ironfur=ironfur_cost==0
    if Settings.on("defensives") and stacks<8 and rage>=(ironfur_cost or 40)
        and (need_fur or free_ironfur and stacks<8) then
        if cast(S.ironfur,p,p,true) then
            rage=math.max(0,rage-(ironfur_cost or 40))
            -- A successful request reserves only the stacks still missing.
            need_fur=stacks+1<desired_fur
        end
    end
    if not valid(target) or not p:can_attack(target) or not practice and not Combat.engaged(p,target) then Settings.status="Waiting for an engaged hostile target"; return end
    local enrage_target=Settings.on("soothe") and Combat.select_enrage(p,target,40) or nil
    if enrage_target and Aura.since(S.soothe,enrage_target)>2 and cast(S.soothe,enrage_target,p) then
        Combat.utility="Soothed confirmed Enrage"; return
    end
    if not interrupted and Settings.on("interrupts") and Settings.on("aoe_stop") then
        local caster_count,stop_target=Combat.interruptible_count(p,10)
        if caster_count>=2 and emergency_stop(p,stop_target) then Combat.utility="Emergency group cast stop"; return end
    end
    if not interrupted and Settings.on("interrupts") and Settings.on("aoe_stop") then
        local emergency=Combat.select_emergency_stop(p,target,10)
        if emergency and emergency_stop(p,emergency) then
            Combat.utility="Emergency party-target cast stop"; Log.record("ACTION","INTERRUPT","emergency_group_stop",{enemy=Aura.guid(emergency)}); return
        end
    end
    if Settings.on("auto_face") then Combat.face_if_needed(p,target) end
    local pack=enemies(p,target,8)
    local count=#pack
    local hero=Settings.value("hero")
    local elune=hero==2 or hero==1 and known(S.lunation)
    local moon=resolved(S.moonfire)
    local red=moon==S.red_moon or known(S.red_moon)
    local thrash_stacks=Aura.stacks(target,S.thrash_dot,true,p)
    local needed=known(S.flashing) and 5 or 3
    local thrash_due=count>0 and (dot_due(target,S.thrash_dot,S.thrash,p,3)
        or thrash_stacks and thrash_stacks<needed)
    if not thrash_due then
        for _,enemy in ipairs(pack) do
            local stacks=Aura.stacks(enemy,S.thrash_dot,true,p)
            if dot_due(enemy,S.thrash_dot,S.thrash,p,3) or stacks and stacks<needed then
                thrash_due=true; break
            end
        end
    end
    local spender=known(S.raze) and S.raze or S.maul
    local ravage=resolved(spender)==S.ravage
    local spender_cost=rage_cost(spender,p)
    local free_spender=spender_cost==0
    local moonfire_target=nil
    if not red then
        moonfire_target=dot_due(target,S.moonfire_dot,S.moonfire,p,3) and target or nil
        if not moonfire_target and count>1 then
            for _,enemy in ipairs(pack) do
                if dot_due(enemy,S.moonfire_dot,S.moonfire,p,3) then moonfire_target=enemy; break end
            end
        end
    end
    -- Pack entry needs immediate area threat before ranged DoT maintenance.
    if count>=2 and thrash_due and cast(S.thrash,p,p) then return end
    local burst,burst_reason=should_burst(target,count,forecast,pack)
    Settings.cooldown_status=burst and ("Using: "..burst_reason) or ("Held: "..burst_reason)
    if Settings.on("cooldowns") and count>0 and burst then
        if not active(p,S.incarnation,1) and not active(p,S.berserk,1) then
            cast(known(S.incarnation) and S.incarnation or S.berserk,p,p,true)
        end
        -- Establish Red Moon before spending Mangle's extension charges.
        if red and cast(S.red_moon,target,p) then return end
    end
    -- Moonfire maintenance is a defensive layer through Scintillating
    -- Moonlight for both hero trees. Elune's ordinary filler stays late, but
    -- a genuinely missing or expiring DoT must not wait behind generators.
    if moonfire_target and cast(S.moonfire,moonfire_target,p) then return end
    -- Red Moon is the exception: Mangle extends its window and moves ahead.
    local red_window=red and (Aura.read(target,S.red_moon,true,p) or Aura.since(S.red_moon,target)<8)
    if red_window and cast(S.mangle,target,p) then return end
    -- Current Druid of the Claw priority spends a Ravage proc above 60 Rage
    -- before ordinary Thrash. Initial multi-target contact still uses Thrash
    -- above this block, and active mitigation remains reserved.
    if ravage and rage>60 and not need_fur and cast(spender,target,p) then return end
    if thrash_due and cast(S.thrash,p,p) then return end
    -- Keep Elune's key cooldown ahead of ordinary spending, except when the
    -- resource is already close enough to the cap to waste the next gain.
    local expected_rage=(cooldown(resolved(S.mangle))<=1 and 10 or 0)
        +(count>0 and cooldown(resolved(S.thrash))<=1 and 4 or 0)
    local effective_rage=math.min(100,rage+expected_rage)
    if Settings.on("cooldowns") and burst and elune and rage<95 and cast(S.beam,target,p) then return end
    if Settings.on("spenders") and not need_fur and effective_rage>=Settings.value("rage_dump")
        and rage>=(spender_cost or 40) and cast(spender,target,p) then return end
    -- If a damage spender cannot run, use off-GCD mitigation near the cap.
    if Settings.on("defensives") and stacks<8 and rage>=90 and rage>=(ironfur_cost or 40)
        and cast(S.ironfur,p,p,true) then rage=math.max(0,rage-(ironfur_cost or 40)) end
    if Settings.on("cooldowns") and burst and elune and cast(S.beam,target,p) then return end
    if count>0 and cast(S.thrash,p,p) then return end
    if cast(S.mangle,target,p) then return end
    if Settings.on("cooldowns") and burst then
        if not elune and cast(S.beam,target,p) then return end
    end
    -- A confirmed zero-cost proc cannot consume rage reserved for mitigation.
    if Settings.on("spenders") and free_spender and cast(spender,target,p) then return end
    if not elune and not red and Aura.read(p,S.galactic) and cast(S.moonfire,target,p) then return end
    -- Raze replaces Maul when talented, including against a single enemy.
    if Settings.on("spenders") and not need_fur and rage>=(spender_cost or 40) and cast(spender,target,p) then return end
    if elune and not red then cast(S.moonfire,target,p)
    elseif count>0 then cast(S.swipe,p,p) end
end

-- Keep emergency mitigation alive during the runtime's fault-recovery pause.
-- This deliberately cannot target enemies, move, attack, or change forms.
local function failsafe()
    if not Settings.allowed() or not Settings.on("defensives") then return false end
    local p=core.object_manager.get_local_player()
    if not valid(p) or not p:is_in_combat() then return false end
    local maximum=tonumber(p:get_max_health()) or 0
    local hp=maximum>0 and p:get_health()*100/maximum or 100
    local form=core.spell_book.get_shapeshift_form_id()
    local bear=form==5 or form==8 or active(p,S.bear)
    -- Preserve verified tank-timer protection while the main rotation is
    -- paused. BigWigs.scan is bounded and does not require a world scan.
    local timer=Settings.on("bigwigs_defensives") and BigWigs.scan(1.2) or nil
    if timer and timer.kind=="tank" and timer.remaining>0 and timer.remaining<=1.2
        and major_defensive(p,bear and hp<=70) then return true end
    if hp<=Settings.value("survival_hp") and major_defensive(p,bear) then return true end
    if hp<=Settings.value("barkskin_hp") and major_defensive(p,false) then return true end
    if bear and hp<=Settings.value("regen_hp") and not active(p,S.regen,3)
        and cast(S.regen,p,p) then return true end
    return false
end

-- Manual spell input should yield the ordinary rotation without creating a
-- tanking blind spot. Keep this path small and reactive: no damage, movement,
-- facing, form changes, dispels, resurrection, or party healing.
local function manual_safety()
    if failsafe() then return true end
    if not Settings.allowed() or not Settings.on("combat") then return false end
    local p=core.object_manager.get_local_player()
    if not valid(p) or not p:is_in_combat() or p:is_flying()
        or p:is_casting_spell() or p:is_channelling_spell() then return false end
    local form=core.spell_book.get_shapeshift_form_id()
    local bear=form==5 or form==8 or active(p,S.bear)
    if not bear then return false end

    -- Preserve active mitigation when manual input lands near a rage cap.
    if Settings.on("defensives") then
        local rage=tonumber(p:get_power(RAGE)) or 0
        local stacks=Aura.stacks(p,S.ironfur) or ((Aura.read(p,S.ironfur) or Aura.since(S.ironfur)<4) and 1 or 0)
        local cost=rage_cost(S.ironfur,p)
        if stacks<Settings.value("ironfur_stacks") and rage>=(cost or 40)
            and cast(S.ironfur,p,p,true) then return true end
    end

    local target=p:get_target()
    if Settings.on("interrupts") then
        local caster=Combat.select_interrupt(p,target,13,Settings.value("interrupt_percent"))
        if caster then
            if cast(S.skull_bash,caster,p,true) then return true end
            Combat.mark_interrupt_failed(caster)
        end
    end
    if Settings.on("auto_taunt") and Threat.group_active() then
        local _,loose=Combat.select_damage_target(p,target,math.min(30,Settings.value("threat_range")))
        if loose and valid(loose.object) and not Combat.damage_blocked(loose.object)
            and cast(S.growl,loose.object,p,true) then
            growl_target,growl_pressure_until=loose.object,core.time()+6
            Settings.status="Growl: recovered party aggro during manual input"
            return true
        end
    end
    return false
end

return {update=update,failsafe=failsafe,manual_safety=manual_safety,on_confirm=on_confirm,manual_yielding=manual_yielding,spells=S,combat=Combat,reset=function() stop_combat_landing(); attempts={}; accepted_requests={}; manual_yield_until=-math.huge; failures={}; retry_until={}; failure_log_until={}; ttd_samples={}; next_retry_cleanup=0; last_gcd=-math.huge; last_defensive_request=-math.huge; growl_target,growl_pressure_until=nil,-math.huge; combat_started_at=nil; Combat.reset(); Threat.reset(); Prediction.reset(); PvP.reset() end}
