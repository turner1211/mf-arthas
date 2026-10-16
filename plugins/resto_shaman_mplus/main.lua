local me0=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not me0 or not me0.is_valid or not me0:is_valid() or me0:get_class()~=7 then return end

-- Rotation modules are loaded only after branch detection. This protects WoW
-- Forever from Retail spell/talent IDs and keeps the startup function far below
-- Lua's hard 200-local limit.
local RT={C=require("rs_settings"),U=require("rs_units"),X=require("rs_context"),
 Branch=require("rs_branch"),Gui=require("rs_gui_probe"),BossHud=require("rs_boss_hud"),
 last_tick=-math.huge,tick_interval=0.025,last_mode=nil,last_error=-math.huge,error_at={},loaded={}}
RT.C.set_setting("debug_log",true)
local function player()
 local me=core.object_manager.get_local_player()
 if not me or RT.U.call(me,"is_valid")~=true or RT.U.call(me,"get_class")~=7 then return nil end
 return me
end
local function module(name) if not RT.loaded[name] then RT.loaded[name]=require(name) end return RT.loaded[name] end
RT.safe=function(scope,fn,...)
 local ok,result=pcall(fn,...)
 if not ok and core.time()-(RT.error_at[scope] or -math.huge)>=10 then
  RT.error_at[scope]=core.time();pcall(require("rs_telemetry").error,scope,result);pcall(core.log_warning,"[Shaman Suite "..scope.."] "..tostring(result))
 end
 return ok,result
end
local function reset_retail()
 pcall(module("rs_units").reset_history)
 for _,name in ipairs({"rs_mana","rs_profiles","rs_ghost_wolf","rs_projection","rs_pvp"}) do local ok,m=pcall(module,name);if ok and type(m.reset)=="function" then pcall(m.reset) end end
end
local function tick()
 local me=player();if not me then return end
 local identity=RT.Branch.detect();local context=RT.X.get()
 RT.C.client_family=identity.family;RT.C.active_spec=identity.spec;RT.C.content=context.label
 RT.C.profile=(identity.family=="forever" and "WoW Forever " or "Retail / Midnight ")..identity.spec:gsub("^%l",string.upper)
  ..(identity.level and (" • Level "..tostring(identity.level)) or "")
 RT.C.poll_window()
 if not RT.C.get("enabled") then if identity.family=="retail" then module("rs_evade").stop("Routine paused") end RT.C.status="Paused";return end
 if not RT.C.mode_enabled(context.mode) then if identity.family=="retail" then module("rs_evade").stop("Content profile disabled") end RT.C.status=context.label.." profile disabled";return end
 if RT.U.call(me,"is_dead")==true or RT.U.call(me,"is_ghost")==true then if identity.family=="retail" then module("rs_evade").stop("Player dead") end RT.C.status="Dead; all actions stopped";return end
 if RT.U.call(me,"is_mounted")==true then RT.C.status="Mounted";return end
 if identity.spec=="unknown" then RT.C.status="Waiting for Shaman specialization/tree detection";return end
 if RT.last_mode and context.mode~=RT.last_mode and identity.family=="retail" then reset_retail() end
 RT.last_mode=context.mode
 if identity.family=="forever" then module("rs_forever").run(me,context,identity.spec);return end
 module("rs_evade").run(me)
 if identity.spec=="restoration" then
  module("rs_auras").prune()
  if module("rs_recovery").run(me) then return end
  if module("rs_gathering").run(me) then return end
  module("rs_rotation").run(me)
 else module("rs_retail_dps").run(me,context,identity.spec) end
end
core.register_on_update_callback(function()
 local now=core.time();if now>RT.last_tick and now-RT.last_tick<RT.tick_interval then return end
 RT.last_tick=now;RT.U.begin_object_snapshot();local ok,err=pcall(tick);RT.U.end_object_snapshot()
 if not ok then RT.C.status="API error; see debugger";pcall(require("rs_telemetry").error,"update",err);if core.time()-RT.last_error>=10 then pcall(core.log_warning,"[Shaman Suite] "..tostring(err));RT.last_error=core.time() end end
end)
core.register_on_render_menu_callback(function() if player() then RT.safe("menu_render",RT.C.render) end end)
core.register_on_render_callback(function()
 if not player() then return end
 local identity=RT.Branch.last or RT.Branch.detect()
 if identity.family=="retail" then
  RT.U.begin_object_snapshot();RT.safe("danger_zones_render",module("rs_danger_zones").draw);RT.safe("boss_guide_render",module("rs_boss_guide").draw)
  if identity.spec=="restoration" then RT.safe("arena_lines_render",module("rs_arena_lines").draw) end
  RT.U.end_object_snapshot()
 end
end)
if type(core.register_on_render_window_callback)=="function" then
 core.register_on_render_window_callback(function()
  if player() then
   RT.U.begin_object_snapshot();RT.safe("main_gui_render",RT.Gui.render);RT.safe("boss_hud_window_render",RT.BossHud.render);RT.U.end_object_snapshot()
  else RT.safe("main_gui_hide",RT.Gui.hide);RT.safe("boss_hud_hide",RT.BossHud.hide) end
 end)
end
core.register_on_game_event_callback(function(event,args)
 if not player() then return end
 local identity=RT.Branch.last or RT.Branch.detect()
 if identity.family=="forever" then RT.safe("forever_event",module("rs_forever").event,event,args);return end
 RT.safe("spell_event",module("rs_spells").event,event,args)
 if identity.spec=="restoration" then
  for _,row in ipairs({{"rs_interrupts","interrupt_event"},{"rs_pvp","pvp_event"},{"rs_projection","projection_event"}}) do
   RT.safe(row[2],module(row[1]).event,event,args)
  end
 end
 RT.safe("aura_event",module("rs_auras").event,event,args);RT.safe("telemetry_event",module("rs_telemetry").event,event,args)
 RT.last_tick=-math.huge
end)
core.log("[Shaman Suite] 5.12.0 loaded: current imbues, Totemic timing, and Forever healer damage.")
