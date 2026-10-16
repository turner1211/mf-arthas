local U,I,Modes=require('sm_util'),require('sm_identity'),require('sm_modes')
local C,E,N,Q,L=require('sm_settings'),require('sm_engine'),require('sm_snapshot'),require('sm_utility'),require('sm_log')
local Boss,Gui,PvpLines=require('sm_dps_boss_guides'),require('sm_gui'),require('sm_pvp_lines')
local rotations={[62]=require('sm_arcane'),[63]=require('sm_fire'),[64]=require('sm_frost')}
local engine=E.new();local current,next_tick,next_advice=nil,0,0
C.init();L.enabled=C.logging:get_state();L.start()
local function stop(reason,now,hide)
 local previous=current
 C.status=reason;engine:reset(nil,now);current=nil;Boss.active=nil;PvpLines.clear();C.recommendation=nil;C.gameplay=nil
 if hide then C.identity=nil;C.mode=nil end
 L.change('hold',previous,reason);L.flush(now,true)
end
local function tick()
 local now=U.number(U.fn(core.time)) or 0;if now<next_tick then return end;next_tick=now+0.1
 L.enabled=C.logging:get_state();L.flush(now)
 local player=U.fn(core.object_manager.get_local_player)
 if not U.valid(player) then return stop('Waiting for a living Mage',now,true) end
 local identity,why=I.read(player);if not identity then return stop(why,now,true) end
 local mode,reason=Modes.detect(player,U.call(player,'get_target'),C.dummy_test:get_state());if not mode then return stop(reason,now,true) end
 C.identity=identity;C.mode=mode
 C.poll_hotkeys(identity.id,mode)
 if engine:bind(identity,mode,now) then C.burst:set(false) end
 local cfg=C.get(identity.id,mode);if not cfg then return stop('Profile unavailable',now) end
 cfg.dummy_test=C.dummy_test:get_state()
 if U.call(player,'is_mounted')~=false then return stop('Mounted or mount state unavailable',now) end
 engine.burst_requested=C.burst:get_state();current=N.build(player,identity,mode,cfg,engine)
 L.capture(current,engine,C);Boss.update(current,identity,C.boss_guide:get_state());PvpLines.update(current)
 -- Gameplay prose is display-only. Rebuilding it every combat decision repeats
 -- aura and talent reads without improving spell reaction time.
 if not C.gameplay or now>=next_advice then C.gameplay=require('sm_gameplay').advice(current);next_advice=now+0.5 end
 if not C.enabled:get_state() or C.pause:get_state() or not cfg.enabled then
  if engine.pending or next(engine.history) then engine:reset(nil,now) end
  C.recommendation=nil;C.status='Mage paused';return
 end
 if identity.role_conflict then return stop('Assigned role conflicts with Mage DPS',now) end
 if not current.hp or not current.mana then C.status='Waiting for health or mana data';return end
 if now<(engine.transition_until or 0) or now<engine.manual_until then C.status='Yielding to transition or manual input';return end
 local hook=_G.SylvanasMageCombatHold
 if type(hook)=='function' and U.fn(hook,{spec=identity.id,mode=mode,role=identity.role})==true then C.status='Companion requests combat hold';return end
 if not current.combat then
  local maintenance=Q.maintenance(current,engine);C.recommendation=maintenance
  if maintenance then local _,outcome=engine:cast(current,maintenance);C.status=maintenance.key..' / '..tostring(outcome)
  else C.status='Waiting for combat' end
  return
 end
 if engine:channel_update(current) then C.status='Evocation ending at recovered mana';return end
 local pending=engine:expired(current)
 local action=Q.run(current,engine)
 if current.mode=='arena'then
  local cc=current.cc_status or(action and('not reached: higher-priority '..action.key)or'no eligible control action')
  L.change('cc_decision',current,cc)
 end
 if not action and current.target_valid and current.target_engaged then action=rotations[identity.id].decide(current,engine) end
 local row=action and require('sm_spells').rows[action.key]
 if pending and not (row and row.off and (row.defensive or row.interrupt or row.while_casting)) then C.status='Waiting for cast confirmation';return end
 C.recommendation=action
 if not action then C.status=identity.spec..': waiting for eligible action';return end
 local _,outcome=engine:cast(current,action)
 C.status=action.key..' / '..tostring(outcome)
end
local callback_errors,callback_retry={},{}
local function error_text(err)
 if type(err)~='table'then return tostring(err)end
 local out={};for k,v in pairs(err)do out[#out+1]=tostring(k)..'='..tostring(v)end;table.sort(out)
 return #out>0 and table.concat(out,', ')or'<empty error table>'
end
local function guarded(label,fn,pause_combat)
 return function(...)
  local now=U.number(U.fn(core.time))or 0
  if now<(callback_retry[label]or-math.huge)then return end
  local ok,err=pcall(fn,...)
  if ok then return end
  local detail=label..': '..error_text(err)
  local prior=callback_errors[label]
  if not prior or prior.detail~=detail or now-(prior.time or-math.huge)>=30 then
   pcall(L.emit,'error',current,detail);callback_errors[label]={detail=detail,time=now}
  end
  -- The native PS menu is optional because every setting is available in the
  -- custom Mage GUI. A bridge failure gets a 30-second circuit breaker instead
  -- of being retried and synchronously logged on every menu frame.
  if label=='menu'then callback_retry[label]=now+30 end
  if pause_combat then
   C.pause:set(true);C.burst:set(false)
   pcall(stop,'Mage paused after '..label..' error',U.fn(core.time) or 0)
  end
 end
end
core.register_on_update_callback(guarded('update',tick,true))
core.register_on_render_menu_callback(guarded('menu',function()
 local player=U.fn(core.object_manager.get_local_player)
 if U.valid(player) and U.number(U.call(player,'get_class'))==8 then C.render()end
end,false))
-- Custom windows must be submitted every window frame, independently of the loader menu.
local render_window=core.register_on_render_window_callback or core.register_on_render_callback
local render_hud=guarded('hud',function()require('sm_hud').render(C)end,false)
if render_window then render_window(guarded('window',function()Gui.render();render_hud()end,false))end
if core.register_on_render_callback then
 core.register_on_render_callback(guarded('world_overlay',function()
  Boss.render(C.identity~=nil and C.boss_guide:get_state());PvpLines.render()
 end,false))
end
if core.register_on_legit_spell_cast_callback then core.register_on_legit_spell_cast_callback(guarded('manual_input',function()engine:manual(U.fn(core.time) or 0);L.emit('manual_hold',current,'Manual spell input observed')end,true))end
if core.register_on_spell_cast_callback then core.register_on_spell_cast_callback(guarded('spell_cast',function(data)if current then current.now=U.fn(core.time) or current.now;engine:record_cast(data,current)end end,true))end
if core.register_on_game_event_callback then core.register_on_game_event_callback(guarded('game_event',function(event,args)
 L.lifecycle(event,current)
 if event=='PLAYER_LOGOUT' or event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_DEAD'
 or event=='DISCONNECTED_FROM_SERVER' or event=='PLAYER_DISCONNECTED' then
  C.burst:set(false);stop('Waiting after '..event,U.fn(core.time) or 0,true);return
 end
 Boss.on_event(event,args);if current then current.now=U.fn(core.time) or current.now;engine:event(event,args,current)end
 if event=='PLAYER_REGEN_ENABLED' then
  L.emit('marker',current,'Combat ended; pending combat state cleared')
  engine:reset(engine.scope,U.fn(core.time) or 0,true);C.burst:set(false);current=nil;Boss.active=nil;PvpLines.clear();C.recommendation=nil;C.gameplay=nil
 end
 if event=='PLAYER_TALENT_UPDATE' or event=='SPELLS_CHANGED' or event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD'
 or event=='PLAYER_SPECIALIZATION_CHANGED' or event=='PLAYER_EQUIPMENT_CHANGED' then
  engine:reset(nil,U.fn(core.time) or 0);C.burst:set(false);current=nil;Boss.active=nil;PvpLines.clear();C.recommendation=nil;C.gameplay=nil;C.identity=nil;C.mode=nil
 end
end,true))end
_G.SylvanasMageStatus=function()return {version=require('sm_version'),spec=C.identity and C.identity.id,mode=C.mode,status=C.status,enabled=C.enabled:get_state(),paused=C.pause:get_state()}end

_G.SylvanasMageExportLog=function(previous)L.flush(U.fn(core.time) or 0,true);return L.export(previous==true)end
