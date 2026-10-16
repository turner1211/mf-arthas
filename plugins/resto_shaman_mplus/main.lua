-- STRICT_CLASS_GUI_GUARD: do not initialize this plugin or its GUI on another class/spec.
local _guard_player=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
local _guard_class=_guard_player and _guard_player.is_valid and _guard_player:is_valid() and _guard_player:get_class() or nil
local _guard_spec=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or nil
if _guard_class~=7 or (_guard_spec~=3 and _guard_spec~=264) then return end
-- Keep runtime dependencies and mutable state in one table. Besides making the
-- ownership explicit, this prevents incremental features from exhausting the
-- Lua compiler's hard 200-local limit in the startup function.
local RT={
    C=require("rs_settings"),U=require("rs_units"),A=require("rs_auras"),
    R=require("rs_rotation"),E=require("rs_evade"),G=require("rs_gathering"),
    Recovery=require("rs_recovery"),ArenaLines=require("rs_arena_lines"),
    Danger=require("rs_danger_zones"),
    BossGuide=require("rs_boss_guide"),
    BossHud=require("rs_boss_hud"),
    GuiProbe=require("rs_gui_probe"),X=require("rs_context"),
    enums=require("common/enums"),last_error=-math.huge,last_mode=nil,error_at={},
    last_tick=-math.huge,tick_interval=0.025,
}
RT.C.set_setting("debug_log",true)
RT.safe=function(scope,fn,...)
    local ok,result=pcall(fn,...)
    if not ok and core.time()-(RT.error_at[scope] or -math.huge)>=10 then
        RT.error_at[scope]=core.time()
        pcall(require("rs_telemetry").error,scope,result)
        pcall(core.log_warning,"[Resto M+ "..scope.."] "..tostring(result))
    end
    return ok,result
end
local function restoration_player()
    local me=core.object_manager.get_local_player()
    if not me or RT.U.call(me,"is_valid")~=true or me:get_class()~=7 then return nil end
    local ok,spec=pcall(core.spell_book.get_specialization_id)
    if not ok or RT.enums.class_spec_id.get_specialization_enum(7,spec)~=RT.enums.class_spec_id.spec_enum.RESTORATION_SHAMAN then return nil end
    return me
end
local function tick()
    local me=restoration_player()
    if not me then RT.E.stop("Wrong specialization");return end
    local context=RT.X.get()
    if RT.last_mode and context.mode~=RT.last_mode then
        require("rs_telemetry").mode_transition(RT.last_mode,context.mode)
        RT.U.reset_history()
        require("rs_mana").reset()
        require("rs_profiles").reset_pressure()
        require("rs_ghost_wolf").reset()
        require("rs_projection").reset()
        require("rs_pvp").reset()
    end
    RT.last_mode=context.mode
    RT.C.poll_window()
    RT.C.content=context.label
    RT.C.profile=require("rs_profiles").get().name
    if not RT.C.get("enabled") then RT.E.stop("Routine paused");RT.C.status="Paused"; return end
    if RT.U.call(me,"is_dead")==true or RT.U.call(me,"is_ghost")==true then
        RT.E.stop("Player dead");RT.A.reset();RT.U.reset_history();RT.C.status="Dead; all actions stopped";return
    end
    if not RT.U.valid(me) then RT.E.stop("Player unavailable");RT.A.reset(); return end
    if RT.U.call(me,"is_mounted") then RT.E.stop("Mounted");return end
    RT.E.run(me)
    RT.A.prune()
    if RT.Recovery.run(me) then return end
    if RT.G.run(me) then return end
    RT.R.run(me)
end
core.register_on_update_callback(function()
    local now=core.time()
    -- Forty decisions per second keep emergency latency below 25 ms while
    -- avoiding a full healing evaluation on every frame of high-refresh clients.
    -- Equal timestamps are allowed for deterministic hosts and test harnesses.
    if now>RT.last_tick and now-RT.last_tick<RT.tick_interval then return end
    RT.last_tick=now
    RT.U.begin_object_snapshot()
    local ok,err=pcall(tick)
    RT.U.end_object_snapshot()
    if not ok then
        RT.E.stop("Routine error")
        RT.C.status="API error; see console"
        pcall(require("rs_telemetry").error,"update",err)
        if core.time()-RT.last_error>=10 then core.log_warning("[Resto M+] "..tostring(err)); RT.last_error=core.time() end
    end
end)
core.register_on_render_menu_callback(function() if restoration_player() then RT.C.render() end end)
core.register_on_render_callback(function()
    if restoration_player() then
        RT.U.begin_object_snapshot()
        RT.safe("arena_lines_render",RT.ArenaLines.draw)
        RT.safe("danger_zones_render",RT.Danger.draw)
        RT.safe("boss_guide_render",RT.BossGuide.draw)
        RT.U.end_object_snapshot()
    end
end)
if type(core.register_on_render_window_callback)=="function" then
    -- Independent recovery surface: no texture, custom drawing, mouse capture,
    -- F1 state, or dependency on the full settings overlay.
    core.register_on_render_window_callback(function()
        if restoration_player() then
            RT.U.begin_object_snapshot();RT.GuiProbe.render();RT.BossHud.render();RT.U.end_object_snapshot()
        else RT.GuiProbe.hide();RT.BossHud.hide() end
    end)
else
    -- Compatibility fallback for older clients without the dedicated 2D layer.
    core.register_on_render_callback(function()
        if restoration_player() then RT.safe("compat_gui_render",RT.C.render_overlay) end
    end)
end
core.register_on_game_event_callback(function(event,args)
    if not restoration_player() then return end
    RT.safe("spell_event",require("rs_spells").event,event,args)
    RT.safe("interrupt_event",require("rs_interrupts").event,event,args)
    RT.safe("pvp_event",require("rs_pvp").event,event,args)
    RT.safe("projection_event",require("rs_projection").event,event,args)
    RT.safe("aura_event",RT.A.event,event,args)
    RT.safe("telemetry_event",require("rs_telemetry").event,event,args)
    -- A spell, aura or combat event may change the correct action immediately.
    RT.last_tick=-math.huge
end)
core.log("[Resto M+] 4.5.1 loaded. Exactly two native GUI windows enabled.")
