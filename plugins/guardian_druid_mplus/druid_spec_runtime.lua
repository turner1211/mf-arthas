local U=require("druid_shared")
local Modes=require("druid_modes")
local Pvp=require("druid_pvp")
local Dummy=require("guardian_dummy")
local Factory={}
local function cast_remaining(unit)
    if U.call(unit.is_channelling_spell,unit)==true then return 0 end
    local finish=tonumber(U.call(unit.get_active_spell_cast_end_time,unit))
    if not finish or finish<=0 then return nil end
    local now=tonumber(U.call(core.game_time)) or 0
    if finish>100000 and now>100000 then return math.max(0,(finish-now)/1000) end
    return math.max(0,finish-(tonumber(U.call(core.time)) or 0))
end
local function build_context(spec,player,mode,settings)
    local target=U.call(player.get_target,player)
    if not U.valid(target) and mode=="arena" and core.object_manager.get_arena_target then target=U.call(core.object_manager.get_arena_target,1) end
    local members=U.members(player);local lowest,lowest_hp,tank,dead,injured=player,U.hp(player) or 100,nil,nil,0
    for _,row in ipairs(members) do
        if row.hp<lowest_hp then lowest,lowest_hp=row.unit,row.hp end
        if row.role=="TANK" then tank=row.unit end
        if row.hp<85 then injured=injured+1 end
    end
    local sources={core.object_manager.get_party_members,core.object_manager.get_party_frames,core.object_manager.get_raid_members,core.object_manager.get_raid_frames}
    for _,fn in ipairs(sources) do
        local rows=U.call(fn);if type(rows)=="table" then for _,entry in pairs(rows) do
            local unit=U.unwrap(entry)
            if unit and U.call(unit.is_dead,unit)==true then dead=unit;break end
        end end
        if dead then break end
    end
    local dispel,dispel_urgent,dispel_score=nil,false,-math.huge;local allowed=spec==4 and {poison=true,curse=true,magic=true} or {poison=true,curse=true}
    for _,row in ipairs(members) do
        local effect_score,urgent=Pvp.dispel_score(row.unit,allowed,Modes.pvp[mode]==true)
        if effect_score then
        local score=effect_score+(row.role=="HEALER" and 200 or 0)+(row.unit==player and 80 or 0)+(100-row.hp)
        if score>dispel_score then dispel,dispel_urgent,dispel_score=row.unit,urgent,score end
    end end
    local enemies=U.enemies(player,target,40,mode);local pvp_enemies=Modes.pvp[mode] and U.enemies(player,target,40,mode,true) or enemies
    local interrupt,control,enrage=nil,nil,nil
    local target_engaged=U.engaged(player,target,mode) and not U.protected(target)
    if not target_engaged then target=enemies[1] end
    local interrupt_score=-math.huge;local incoming_cc,incoming_healer_cc,healer_cc_caster=false,false,nil
    for _,unit in ipairs(enemies) do
        local casting=U.call(unit.is_casting_spell,unit)==true or U.call(unit.is_channelling_spell,unit)==true
        local can=U.call(unit.is_active_spell_interruptable or unit.is_cast_interruptible,unit)
        if casting and can~=false then
            local victim=U.call(unit.get_active_spell_target or unit.get_target,unit)
            local control_cast=Pvp.is_control_cast(unit)
            if victim==player and control_cast then incoming_cc=true end
            if control_cast then for _,row in ipairs(members) do
                if victim==row.unit and row.role=="HEALER" then incoming_healer_cc=true;healer_cc_caster=unit;break end
            end end
            local team=false
            for _,row in ipairs(members) do if victim==row.unit then team=true;break end end
            local priority=Pvp.cast_priority(unit)
            local enemy_healer=Pvp.is_healer(unit)
            local score=priority*100+(enemy_healer and 100 or 0)+(team and 60 or 0)-U.distance(player,unit)
            local remaining=cast_remaining(unit);local threshold=priority>=3 and 1.2 or enemy_healer and 0.9 or team and 0.7 or 0.35
            if (remaining==nil or remaining<=threshold) and score>interrupt_score then interrupt,interrupt_score=unit,score end
        end
        if not enrage and U.enraged(unit) then enrage=unit end
    end
    if Modes.pvp[mode] then
        local helper=U.call(require,"common/utility/pvp_helper")
        for _,unit in ipairs(pvp_enemies) do
            if unit~=target and U.call(unit.is_player,unit)==true and Pvp.is_healer(unit) then
                local immune=helper and U.call(helper.is_cc_immune,helper,unit)
                local controlled=helper and U.call(helper.is_crowd_controlled,helper,unit)
                if immune~=true and controlled~=true then control=unit;break end
            end
        end
    end
    local hp=U.hp(player) or 100
    return Pvp.enrich({spec=spec,player=player,target=target,mode=mode,pvp=Modes.pvp[mode]==true,settings=settings,combat=U.call(player.is_in_combat,player)==true,
        hp=hp,mana=U.power_pct(player,require("common/enums").power_type.MANA),members=members,lowest=lowest,lowest_hp=lowest_hp,tank=tank,dead=dead,injured=injured,dispel=dispel,dispel_urgent=dispel_urgent,interrupt=interrupt,
        enemies=pvp_enemies,damage_enemies=enemies,enemy_count=#enemies,aoe_safe=U.aoe_safe(player,12,mode),control=control,enrage=enrage,
        incoming_cc=incoming_cc,incoming_healer_cc=incoming_healer_cc,healer_cc_caster=healer_cc_caster,
        kill_window=U.hp(target) and U.hp(target)<=30 or false,group_safe=lowest_hp>=85,
        safe_rebirth=hp>=70 and lowest_hp>=45})
end
Factory.build_context=build_context
function Factory.start(spec,key)
    local settings=require(key.."_settings");local log=require(key.."_log");local gui=require(key.."_gui")
    local rotation=require(key.."_rotation");local engine=require("druid_spec_engine").new(spec,log)
    local generation=_G.__druid_suite_generation;local next_tick=0;local was_active=false
    local pvp_signature,pvp_log_at=nil,-math.huge
    local arena={active=false}
    local function finish_arena(reason)
        if not arena.active then return end
        local elapsed=math.max(0,(tonumber(U.call(core.time)) or arena.started)-arena.started)
        local accepted=engine.stats.accepted-arena.accepted0
        local confirmed=engine.stats.confirmed-arena.confirmed0
        local declined=engine.stats.declined-arena.declined0
        local manual=engine.stats.manual-arena.manual0
        log.emit("ARENA_END",string.format("reason=%s duration=%.1f min_self=%.1f min_ally=%.1f actions=%d confirmed=%d unconfirmed=%d declined=%d manual=%d kill_windows=%d healer_cc_threats=%d healer_unavailable=%.1f",
            tostring(reason),elapsed,arena.min_self,arena.min_ally,accepted,confirmed,math.max(0,accepted-confirmed),declined,manual,
            arena.kill_windows,arena.healer_cc_threats,arena.healer_unavailable),settings.mode)
        log.flush(true);arena={active=false}
    end
    local function active() return generation==_G.__druid_suite_generation end
    local function tick()
        if not active() then return end
        local now=tonumber(U.call(core.time)) or 0;if now<next_tick then return end;next_tick=now+0.12
        local player=U.call(core.object_manager.get_local_player)
        local matched=U.valid(player) and U.call(player.get_class,player)==11 and U.call(core.spell_book.get_specialization_id)==spec
        if not matched then
            if was_active then finish_arena("profile inactive");engine.reset();log.flush(true) end
            was_active=false;settings.status="Waiting for "..settings.label;return
        end
        was_active=true
        local selected=U.call(player.get_target,player)
        local dummy_range=spec==2 and 5 or 40
        local practice=settings.dummy:get_state() and Dummy.selected(player,selected,dummy_range,spec==4)
        local mode,reason=Modes.detect(player,selected);settings.mode=practice and "Training Dummy" or mode and Modes.labels[mode] or reason
        if not mode or not Modes.allowed(spec,mode) then finish_arena("mode unavailable");settings.status=reason or "Mode disabled";return end
        local cfg=settings.get(mode)
        if not settings.enabled:get_state() or not cfg or not cfg.enabled then finish_arena("profile paused");settings.status="Profile paused";return end
        local context=build_context(spec,player,mode,cfg)
        if practice then
            context.practice=true;context.combat=true;context.pvp=false;context.mode="world_pve"
            if spec==4 and Dummy.is_healing(selected) then
                local hp=U.hp(selected) or 1;context.target=nil;context.lowest=selected;context.lowest_hp=hp
                context.members[#context.members+1]={unit=selected,role="DAMAGER",hp=hp};context.injured=context.injured+1;context.group_safe=false
            else
                context.target=selected;context.enemies={selected};context.damage_enemies={selected};context.enemy_count=1;context.aoe_safe=true
            end
        end
        if mode=="arena" and context.combat then
            if not arena.active then
                arena={active=true,started=now,min_self=context.hp,min_ally=context.lowest_hp,actions=0,kill_windows=0,
                    healer_cc_threats=0,healer_unavailable=0,last_kill=false,last_cc=false,
                    accepted0=engine.stats.accepted,confirmed0=engine.stats.confirmed,
                    declined0=engine.stats.declined,manual0=engine.stats.manual}
                log.emit("ARENA_START","rated evidence capture started",settings.mode)
            end
            arena.min_self=math.min(arena.min_self,context.hp);arena.min_ally=math.min(arena.min_ally,context.lowest_hp)
            if context.kill_window and not arena.last_kill then arena.kill_windows=arena.kill_windows+1 end
            if context.incoming_healer_cc and not arena.last_cc then arena.healer_cc_threats=arena.healer_cc_threats+1 end
            if context.friendly_healer_unavailable then arena.healer_unavailable=arena.healer_unavailable+0.12 end
            arena.last_kill=context.kill_window;arena.last_cc=context.incoming_healer_cc
        elseif arena.active then finish_arena(mode=="arena" and "combat ended" or "mode changed") end
        if context.pvp and context.pvp_summary and (context.pvp_summary~=pvp_signature or now-pvp_log_at>=5) then
            pvp_signature=context.pvp_summary;pvp_log_at=now;log.emit("PVP_STATE",context.pvp_summary,mode)
        end
        if context.pvp and context.pvp_summary then settings.debug=context.pvp_summary end
        if now<engine.manual_until then settings.status="Yielding to manual input";return end
        local action=rotation.decide(context)
        if action and engine.cast(action,player) then
            settings.status=action.key;if arena.active then arena.actions=arena.actions+1 end
        else settings.status=action and ("Waiting: "..action.key) or "No eligible action" end
        log.flush(false)
    end
    core.register_on_update_callback(function() local ok,err=pcall(tick);if not ok then settings.debug=tostring(err);log.error("UPDATE",err) end end)
    core.register_on_render_menu_callback(function()
        if not active() then return end
        local p=U.call(core.object_manager.get_local_player)
        if not U.valid(p) or U.call(p.get_class,p)~=11 or U.call(core.spell_book.get_specialization_id)~=spec then return end
        local ok,err=pcall(settings.render);if not ok then log.error("MENU",err) end
    end)
    local render=core.register_on_render_window_callback or core.register_on_render_callback
    if render then render(function() if active() then local ok,err=pcall(gui.render);if not ok then log.error("GUI",err) end end end) end
    core.register_on_spell_cast_callback(function(data)
        if not active() then return end
        local p=U.call(core.object_manager.get_local_player)
        if U.valid(p) and U.call(core.spell_book.get_specialization_id)==spec then Pvp.on_spell(data);engine.confirm(data,p) end
    end)
    if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event)
        if not active() then return end
        if event=="PLAYER_LOGOUT" or event=="PLAYER_LEAVING_WORLD" or event=="DISCONNECTED_FROM_SERVER" then finish_arena(event);log.flush(true) end
        if event=="PLAYER_SPECIALIZATION_CHANGED" or event=="PLAYER_ENTERING_WORLD" then engine.reset();Pvp.reset(spec);pvp_signature=nil;next_tick=0 end
    end) end
    return {settings=settings,rotation=rotation,engine=engine,log=log,tick=tick}
end
return Factory
