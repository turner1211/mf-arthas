local U,I,Modes=require('hh_util'),require('hh_identity'),require('hh_modes')
local me=U.fn(core.object_manager.get_local_player)
if not me or not I.read(me) then return end
local C,E,N,Q,L=require('hh_settings'),require('hh_engine'),require('hh_snapshot'),require('hh_utility'),require('hh_log')
local Boss,Gui,PvpOverlay=require('hh_dps_boss_guides'),require('hh_gui'),require('hh_pvp_overlay')
local rotations={[253]=require('hh_bm'),[254]=require('hh_mm'),[255]=require('hh_sv')}
local engine=E.new();local current,next_tick=nil,0
engine.perf={tick_avg=0,tick_max=0,snapshot_avg=0,snapshot_max=0,samples=0,serial=0}
local function perf_sample(kind,milliseconds)
 local p=engine.perf;milliseconds=math.max(0,U.number(milliseconds) or 0)
 local average=kind..'_avg';local maximum=kind..'_max'
 p[average]=p[average]==0 and milliseconds or p[average]*.9+milliseconds*.1
 p[maximum]=math.max(p[maximum] or 0,milliseconds)
end
C.init()
L.enabled=C.logging:get_state();L.emit('session_start',nil,'Hunter v1.4.64; previous files preserved; bounded batch logging with forced lifecycle saves')
local function stop(reason,now,hide)
 C.status=reason;engine:reset(nil,now);current=nil;Boss.active=nil;C.recommendation=nil
 if hide then C.identity=nil;C.mode=nil end
end
local function tick()
 local now=U.number(U.fn(core.time)) or 0;if now<next_tick then return end;next_tick=now+0.1
 engine.perf.serial=engine.perf.serial+1
 Gui.poll_hotkey()
 L.enabled=C.logging:get_state();L.flush(now)
 local player=U.fn(core.object_manager.get_local_player)
 if not U.valid(player) then return stop('Waiting for a living Hunter',now,true) end
 local identity,why=I.read(player);if not identity then return stop(why,now,true) end
 local mode,reason=Modes.detect(player,U.call(player,'get_target'));if not mode then return stop(reason,now,true) end
 C.identity=identity;C.mode=mode;engine:bind(identity,mode,now)
 C.poll_hotkeys(identity.id,mode,now)
 Boss.poll_hotkey(C)
 local cfg=C.get(identity.id,mode);if not cfg then return stop('Profile unavailable',now) end
 if U.call(player,'is_mounted')~=false then return stop('Mounted or mount state unavailable',now) end
 engine.burst_requested=C.burst:get_state();local snapshot_start=U.number(U.fn(core.time)) or now
 current=N.build(player,identity,mode,cfg,engine)
 perf_sample('snapshot',((U.number(U.fn(core.time)) or snapshot_start)-snapshot_start)*1000)
 local log_scope=identity.id..':'..mode..':'..identity.assigned
 if L.profile_scope~=log_scope then L.profile_scope=log_scope;L.profile_settings={};L.emit('profile',current,log_scope) end
 for key,value in pairs(cfg) do
  if L.profile_settings[key]~=value then L.profile_settings[key]=value;L.emit('setting',current,key..'='..tostring(value)) end
 end
 C.recommendation=nil
 Boss.update(current,identity,C.boss_guide:get_state())
 if not C.enabled:get_state() or C.pause:get_state() or not cfg.enabled then
  if engine.pending or next(engine.history) then engine:reset(nil,now) end
  C.recommendation=nil;C.status='Hunter paused';return
 end
 if identity.role_conflict then return stop('Assigned role conflicts with Hunter DPS',now) end
 if not current.hp or not current.focus then C.status='Waiting for health or focus data';return end
 if now<(engine.transition_until or 0) or now<engine.manual_until then C.status='Yielding to transition or manual input';return end
 local hook=_G.SylvanasHunterCombatHold
 if type(hook)=='function' and U.fn(hook,{spec=identity.id,mode=mode,role=identity.role})==true then C.status='Companion requests combat hold';return end
 if not current.combat and not (current.training_dummy and cfg.training_dummy~=false) then C.status='Waiting for combat';return end
 local pending=engine:expired(current)
 local action=Q.run(current,engine)
 local row=action and require('hh_spells').rows[action.key]
 if pending and not (row and row.off and (row.defensive or row.interrupt)) then C.status='Waiting for cast confirmation';return end
 if not action and current.target_valid and current.target_engaged then action=rotations[identity.id].decide(current,engine) end
 C.recommendation=action
 if not action then C.status=identity.spec..': waiting for eligible action';return end
 local _,outcome=engine:cast(current,action)
 C.status=action.key..' / '..tostring(outcome)
end
core.register_on_update_callback(function()
 local started=U.number(U.fn(core.time)) or 0;local serial=engine.perf.serial
 local ok,err=pcall(tick)
 if engine.perf.serial~=serial then
  perf_sample('tick',((U.number(U.fn(core.time)) or started)-started)*1000)
  engine.perf.samples=engine.perf.samples+1
 end
 if not ok then L.change('error',current,U.clean(err));L.flush(nil,true);stop('Hunter paused after API error',U.fn(core.time) or 0) end
 L.change('state',current,C.status)
 local now=U.number(U.fn(core.time)) or 0
 if current and current.settings.performance_telemetry~=false and now-(L.last_heartbeat or -math.huge)>=5 then
  L.last_heartbeat=now
  L.emit('heartbeat',current,'status='..C.status..'; target_name='..U.clean(current.target_name)..'; training_dummy='..tostring(current.training_dummy==true)..'; dummy_source='..tostring(current.dummy_source)..'; player_in_control='..tostring(current.player_in_control)..'; global_enabled='..tostring(C.enabled:get_state())..'; profile_enabled='..tostring(current.settings.enabled)..'; paused='..tostring(C.pause:get_state())..'; pending='..tostring(engine.pending and engine.pending.key)..'; last_action='..tostring(engine.last_action)..'; trap_block='..tostring(current.trap_block)..string.format('; perf_tick_avg_ms=%.3f; perf_tick_max_ms=%.3f; perf_snapshot_avg_ms=%.3f; perf_snapshot_max_ms=%.3f; perf_samples=%d',engine.perf.tick_avg,engine.perf.tick_max,engine.perf.snapshot_avg,engine.perf.snapshot_max,engine.perf.samples))
  if L.enabled and current.combat and current.target_valid then
   local probe_ok,probe_error=pcall(engine.probe,engine,current,({[253]='bestial_wrath',[254]='trueshot',[255]='takedown'})[current.spec])
   if not probe_ok then L.change('diagnostic_error',current,U.clean(probe_error)) end
   local charge_ok,charge_error=pcall(engine.charge_probe,engine,current,({[253]='barbed_shot',[254]='aimed_shot',[255]='wildfire_bomb'})[current.spec])
   if not charge_ok then L.change('charge_diagnostic_error',current,U.clean(charge_error)) end
  end
 end
end)
core.register_on_render_menu_callback(function()if C.identity then C.render()end end)
-- Custom windows must be submitted every window frame, independently of the loader menu.
local render_window=core.register_on_render_window_callback or core.register_on_render_callback
if render_window then render_window(function()
 Gui.render()
 local ok,err=pcall(Boss.render_window,C)
 if not ok then L.change('boss_gui_error',current,U.clean(err)) end
end) end
if core.register_on_render_callback then core.register_on_render_callback(function()
 pcall(Boss.render,C.identity~=nil and C.boss_guide:get_state(),current and current.settings)
 pcall(PvpOverlay.render,current)
end)end
if core.register_on_legit_spell_cast_callback then core.register_on_legit_spell_cast_callback(function()
 if not current or current.settings.manual_pause~=false then engine.manual_until=(U.fn(core.time) or 0)+0.65 end
end)end
if core.register_on_spell_cast_callback then core.register_on_spell_cast_callback(function(data)if current then current.now=U.fn(core.time) or current.now;engine:record_cast(data,current)end end)end
if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event,args)
 if event=='PLAYER_LOGOUT' or event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_ENTERING_WORLD'
  or event=='PLAYER_DEAD' or event=='PLAYER_ALIVE' or event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_REGEN_ENABLED' then
  L.emit('lifecycle',current,event);L.flush(nil,true)
 end
 Boss.on_event(event,args);if current then current.now=U.fn(core.time) or current.now;engine:event(event,args,current)end
 if event=='PLAYER_TALENT_UPDATE' or event=='SPELLS_CHANGED' or event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD'
 or event=='PLAYER_SPECIALIZATION_CHANGED' or event=='PLAYER_EQUIPMENT_CHANGED' or event=='PLAYER_REGEN_ENABLED' then
  engine:reset(nil,U.fn(core.time) or 0);current=nil;Boss.active=nil;C.recommendation=nil
 end
end)end
_G.SylvanasHunterStatus=function()return {version='1.4.64',spec=C.identity and C.identity.id,mode=C.mode,status=C.status,enabled=C.enabled:get_state(),paused=C.pause:get_state()}end




