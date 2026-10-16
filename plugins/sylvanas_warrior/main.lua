local U,I,Modes,Rt=require('ww_util'),require('ww_identity'),require('ww_modes'),require('ww_runtime')
local C,E,N,L=require('ww_settings'),require('ww_engine'),require('ww_snapshot'),require('ww_log')
local Q=Rt.module('ww_utility','ww_utility_forever')
local Routes,Boss,DpsBoss,Gui,BossHud,PvpLines=require('ww_routes'),require('ww_boss_guides'),require('ww_dps_boss_guides'),require('ww_gui'),require('ww_boss_hud'),require('ww_pvp_lines')
local rotations={[71]=Rt.module('ww_arms','ww_arms_forever'),[72]=Rt.module('ww_fury','ww_fury_forever'),[73]=Rt.module('ww_protection','ww_protection_forever')}
local engine=E.new()
local current,next_tick,last_prune=nil,0,0
local forever_identity_ready_at=nil
local function status(value,c)
 C.status=value
 L.change('status',c,value)
end
local function stop(why,now,hide)
 status(why,current)
 if engine.scope then engine:reset(nil,now) end
 current=nil;if hide then C.identity=nil;C.mode=nil end
end
local function tick()
 local now=U.number(U.fn(core.time)) or 0
 if now<next_tick then return end
 next_tick=now+0.10
 C.sync_hotkeys()
 L.enabled=C.logging:get_state();L.flush(now)
 local player=U.fn(core.object_manager.get_local_player)
 if not U.valid(player) then forever_identity_ready_at=nil;return stop('Waiting for a living player',now,true) end
 -- Forever can publish a valid player before specialization/spell DB2 data is
 -- loaded. Native assertions occur below Lua and cannot be caught with pcall.
 if Rt.family=='forever'then
  forever_identity_ready_at=forever_identity_ready_at or(now+8)
  if now<forever_identity_ready_at then C.status='Waiting for WoW Forever game data';return end
 end
 local identity,why=I.read(player)
 if not identity then return stop(why,now,true) end
 local mode,reason=Modes.detect(player,U.call(player,'get_target'))
 if not mode then return stop(reason,now) end
 C.identity=identity;C.mode=mode
 Routes.update(player,identity,mode,Rt.family=='midnight'and C.route_map:get_state())
 Boss.update(player,identity,mode,Rt.family=='midnight'and C.boss_guide:get_state())
 if engine:bind(identity,mode,now) then L.change('context',nil,engine.scope) end
 local cfg=C.get(identity.id,mode)
 if not cfg then DpsBoss.update(nil,identity,false);return stop('Warrior profile unavailable',now) end
 if U.call(player,'is_mounted')~=false then DpsBoss.update(nil,identity,false);return stop('Mounted or mount state unavailable',now) end
 engine.pvp_burst_allowed=C.burst:get_state()
 engine.dummy_allowed=C.training_dummy:get_state()
 current=N.build(player,identity,mode,cfg,engine)
 DpsBoss.update(current,identity,Rt.family=='midnight'and C.boss_guide:get_state())
 if identity.id==73 and Boss.active then
  current.mechanic_defensive=Boss.action=='defensive';current.mechanic_remaining=Boss.remaining
 elseif (identity.id==71 or identity.id==72) and DpsBoss.active then
  current.mechanic_defensive=DpsBoss.active.action=='DEFENSIVE';current.mechanic_remaining=DpsBoss.active.remaining
 end
 L.snapshot(current)
 if not C.enabled:get_state() or C.pause:get_state() then return stop('Warrior paused',now) end
 if not cfg.enabled then return stop('This spec and mode are disabled',now) end
 if not current.hp or not current.rage then status('Health or rage data unavailable',current);return end
 if current.now<(engine.transition_until or 0) then status('Settling spec, role, or mode change',current);return end
 if engine:expired(current) then status('Waiting for cast confirmation',current);return end
 local hook=_G.SylvanasWarriorCombatHold
 if type(hook)=='function' and U.fn(hook,{spec=identity.id,mode=mode,role=identity.role})==true then status('Companion plugin requests combat hold',current);return end
 if current.now<engine.manual_until then status('Yielding to manual input',current);return end
 if not current.combat and not current.training then
  local maintenance=Q.prepare(current,engine)
  if maintenance then
   local success,outcome=engine:cast(current,maintenance)
   status(maintenance.key..' — '..maintenance.why..' ('..tostring(outcome)..')',current)
   return success
  end
  status('Waiting for combat',current);return
 end
 local action=Q.run(current,engine)
 if not action and identity.id==73 then action=rotations[73].mitigation(current,engine) end
 if not action and current.target_valid and current.target_engaged then action=rotations[identity.id].decide(current,engine) end
 if not action then status(identity.spec..' / '..Modes.labels[mode]..': waiting for eligible action',current);return end
 local success,outcome=engine:cast(current,action)
 local outcome_status=action.key..' — '..action.why..' ('..tostring(outcome)..')'
 if identity.role_conflict then outcome_status=outcome_status..'; assigned role differs, Taunt held' end
 status(outcome_status,current)
 if now-last_prune>=10 then
  last_prune=now
  for key,until_time in pairs(engine.retry) do if now>until_time+30 then engine.retry[key]=nil;engine.failures[key]=nil end end
  for key,until_time in pairs(engine.defer) do if now>until_time then engine.defer[key]=nil end end
 end
 return success
end
core.register_on_update_callback(function()
 local ok,err=pcall(tick)
 if not ok then
  local now=U.fn(core.time) or 0;stop('Warrior paused after an API error',now)
  L.change('runtime_error',nil,U.clean(err))
  L.flush(now,true)
 end
end)
core.register_on_render_menu_callback(function()
 if C.identity then C.render() end
end)
local render_window=core.register_on_render_window_callback or core.register_on_render_callback
if type(render_window)=='function'then
 render_window(function()
  Gui.render()
  local ok,err=pcall(BossHud.render,C.identity,C.mode,C.boss_guide and C.boss_guide:get_state())
  if not ok then L.change('boss_hud_error',current,U.clean(err))end
 end)
end
if core.register_on_render_callback then
 core.register_on_render_callback(function()
  local ok=pcall(function()
   local player=U.fn(core.object_manager.get_local_player)
   if not player or not C.identity then return end
   local live=C.enabled:get_state() and not C.pause:get_state()
   Routes.render(live and C.route_map:get_state())
   Boss.render(player,live and C.boss_guide:get_state())
   DpsBoss.render(live and C.boss_guide:get_state())
   PvpLines.render(current,live)
  end)
  if not ok then return end
 end)
end
if core.register_on_legit_spell_cast_callback then
 core.register_on_legit_spell_cast_callback(function() engine.manual_until=(U.fn(core.time) or 0)+0.65 end)
end
if core.register_on_spell_cast_callback then
 core.register_on_spell_cast_callback(function(data)
  if current then current.now=U.fn(core.time) or current.now;engine:observe_cast(data,current) end
 end)
end
if core.register_on_game_event_callback then
 core.register_on_game_event_callback(function(event,args)
  Boss.on_event(event,args);DpsBoss.on_event(event,args)
  L.event(event,args,current)
  if current then current.now=U.fn(core.time) or current.now;engine:event(event,args,current) end
  if event=='PLAYER_TALENT_UPDATE' or event=='SPELLS_CHANGED' or event=='GROUP_ROSTER_UPDATE'
   or event=='PLAYER_EQUIPMENT_CHANGED' or event=='PLAYER_REGEN_ENABLED' then
   engine:reset(nil,U.fn(core.time) or 0);current=nil
  end
 end)
end
C.init()
L.initialize('1.7.1')
-- Read-only coordination surface: no foreign rotation or setting is imported.
_G.SylvanasWarrior={version='1.7.1',status=function()
 return {status=C.status,spec=C.identity and C.identity.spec,role=C.identity and C.identity.role,
  assigned_role=C.identity and C.identity.assigned,mode=C.mode,epoch=engine.epoch}
end,diagnostics=function()
 local rows={};for i,r in ipairs(L.rows) do rows[i]=r end;return rows
end,log_paths=function()return L.paths()end,copy_log=function()return L.copy_text()end,snapshot=function()
 if not current then return nil end
 local casts={}
 for i,r in ipairs(current.casts or {}) do
  casts[i]={id=r.id,name=r.name,left=r.left,priority=r.priority,critical=r.critical,target=U.guid(r.target)}
 end
 return {spec=current.spec,mode=current.mode,level=current.level,level_band=current.level_band,training=current.training,hp=current.hp,predicted_hp=current.predicted_hp,rage=current.rage,
  target=current.target_guid,target_hp=current.target_hp,enemies=current.enemy_count,attackers=current.attackers,
  burst=current.burst,aoe_safe=current.aoe_safe,arena_healer=U.guid(current.arena_healer),
  healer_trinket_down=current.healer_trinket_down,upcoming=current.upcoming and
   {text=current.upcoming.text,remaining=current.upcoming.remaining,source=current.upcoming.source} or nil,casts=casts}
end}
L.emit('startup',nil,'Warrior-only 1.7.1; stable GUI input synchronization active')
