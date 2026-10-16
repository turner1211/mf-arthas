local U,S,C,R=require('ui_util'),require('ui_state'),require('ui_settings'),require('ui_view')
C.init()
local PvP=require('ui_pvp')
if core.register_on_spell_cast_callback then core.register_on_spell_cast_callback(function(data)pcall(PvP.on_spell,data)end)end
local next_tick=0;local last_error;local last_clock;local update_error;local render_error;local updates=0
local last_sample;local last_log=0;local log_created=false
local function diagnostic(message)
 if C.diagnostics:get_state() and core.write_log_file then
  if not log_created then U.fn(core.create_log_file,'universal_ui_live.log');log_created=true end
  U.fn(core.write_log_file,'universal_ui_live.log',message..'\n')
 end
end
local function report(err)
 local message=U.text(err,140)
 if message~=last_error and C.diagnostics:get_state() and core.log_warning then core.log_warning('Universal UI: '..message)end
 last_error=message
 diagnostic('ERROR '..message)
end
core.register_on_update_callback(function()
 local now=U.num(U.fn(core.time))
 if now and last_clock and now<last_clock then next_tick=0 end
 last_clock=now
 if now and now<next_tick then return end
 next_tick=now and now+0.1 or 0
 local ok,err=pcall(function()S.update(C);R.prepare(S.snapshot)end)
 if not ok then S.snapshot=nil;S.status='Waiting for UI data';update_error=U.text(err,140);report(err)
 else
  update_error=nil;updates=updates+1
  local s=S.snapshot
  if s then
   local sample=string.format('class=%d spec=%d mode=%s combat=%s resources=%d cooldowns=%d group=%d encounters=%d',s.profile.class,s.profile.id,s.mode,tostring(s.combat),#s.resources,#s.cooldowns,#s.party,#s.encounters)
   if sample~=last_sample or (now and now-last_log>=30)then diagnostic(sample);last_sample=sample;last_log=now or 0 end
  elseif S.status~=last_sample then diagnostic('WAITING '..S.status);last_sample=S.status
  end
 end
end)
core.register_on_render_menu_callback(function()C.render(S)end)
local render=core.register_on_render_window_callback or core.register_on_render_callback
if render then render(function()
 local ok,err=pcall(R.render,S,C)
 if not ok then R.hide();render_error=U.text(err,140);report(err)else render_error=nil end
end)else report('This Sylvanas build has no window render callback')end
if core.register_on_game_event_callback then core.register_on_game_event_callback(function(event)
 if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_LEAVING_WORLD' then PvP.reset();S.reset_activity()end
 if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_SPECIALIZATION_CHANGED' or event=='PLAYER_TALENT_UPDATE' or event=='SPELLS_CHANGED' or event=='GROUP_ROSTER_UPDATE' then
  S.snapshot=nil;S.status='Refreshing class/spec';next_tick=0;S.invalidate();R.hide()
 end
end)end
_G.SylvanasUniversalUIStatus=function()
 local s=S.snapshot
 return {version='1.6.1',status=S.status,class=s and s.profile.class,spec=s and s.profile.id,role=s and s.profile.role,mode=s and s.mode,
  error=update_error or render_error,last_error=last_error,updates=updates,
  group_members=s and #s.party,partial_roster=s and s.partial_roster,cooldowns=s and #s.cooldowns}
end
