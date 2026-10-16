local U=require('hh_util')
local Data=require('hh_dps_boss_data_forever')
local M={status='WoW Forever boss helper ready',active=nil,last_event=nil,window_enabled=true,f7_down=false}
local helper_window
local WIDTH,HEIGHT=440,184
local themes={
 [253]={name='BEAST MASTERY',icon='paw',accent={120,223,105},dark={11,22,16}},
 [254]={name='MARKSMANSHIP',icon='bow',accent={110,196,248},dark={12,18,32}},
 [255]={name='SURVIVAL',icon='spear',accent={244,176,70},dark={31,18,11}}
}
local Color=require('common/color')
local world_colors={red=Color.new(245,55,55,225),gold=Color.new(245,190,55,225),green=Color.new(65,230,115,225)}

local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function match(text)
 text=tostring(text or ''):lower()
 for label,row in pairs(Data.mechanics or {}) do
  if text:find(tostring(label):lower(),1,true) then return row,label end
 end
end
local function visible_boss(c)
 local target=c.target
 local name=call(target,'get_name')
 if name and Data.bosses[name] then return target,name end
 for _,row in ipairs(c.enemies or {}) do
  local u=row.unit or row;name=call(u,'get_name');if name and Data.bosses[name] then return u,name end
 end
 local frames=U.fn(core.object_manager.get_boss_frames) or {}
 for _,row in pairs(frames) do local u=type(row)=='table' and row.object or row;name=call(u,'get_name');if name and Data.bosses[name] then return u,name end end
 if call(target,'is_boss')==true then return target,call(target,'get_name') or 'Boss' end
 for _,row in ipairs(c.enemies or {}) do local u=row.unit or row;if call(u,'is_boss')==true then return u,call(u,'get_name') or 'Boss' end end
end
local function timer_text(c)
 local timer=c.upcoming or c.prediction and c.prediction.timer
 if timer and timer.text then return timer.text,timer.remaining end
 for _,provider in ipairs({'bigwigs','exboss','dbm','deadlybossmods'}) do
  local source=core[provider] or _G[provider]
  local bars=source and (U.fn(source.get_bars,source) or U.fn(source.get_timers,source)) or nil
  for _,bar in ipairs(bars or {}) do
   local text=bar.text or bar.name or bar.label
   if text then return text,bar.remaining or bar.time_left end
  end
 end
end
function M.update(c,identity,enabled)
 local had_boss=M.active~=nil
 M.active=nil
 if not enabled then M.status='DPS boss guide disabled';return end
 if not c or not identity or (identity.id~=253 and identity.id~=254 and identity.id~=255) then M.status='DPS coach isolated to Hunter';return end
 if c.pvp then M.status='DPS coach waiting for PvE';return end
 local boss,name=visible_boss(c)
 if not boss then M.status='Waiting for a WoW Forever boss';return end
 local text,remaining=timer_text(c);local row,label=match(text)
 if not row then
  for _,cast in ipairs(c.casts or {}) do
   if U.same(cast.unit,boss) then
    row,label=match(cast.name)
    if row then remaining=cast.left;break end
    if cast.interruptible then row={'INTERRUPT','Interrupt '..tostring(cast.name or cast.id)};remaining=cast.left;break end
   end
  end
 end
 local guide=Data.bosses[name];if type(guide)~='table'then guide={summary=guide}end
 local action=row and row[1] or 'GUIDE';local prompt=row and row[2] or guide.summary
 if not prompt then prompt='WoW Forever: avoid hazards, handle priority enemies, preserve mana, and interrupt confirmed dangerous casts.' end
 prompt=prompt..(identity.id==255 and ' | Melee: maintain safe flank position and preserve mana while closing.' or ' | Ranged: preserve distance, line of sight, mana and safe pet positioning.')
 M.active={boss=boss,name=name,action=action,prompt=prompt,mechanic=label,remaining=tonumber(remaining),tank=guide.tank,dps=guide.dps,direction=row and row[3]or guide.direction}
 if not had_boss and c.settings.boss_auto_popup~=false then M.window_enabled=true end
 M.status=name..' | '..action..' | '..prompt..(M.active.remaining and string.format(' (%.1fs)',M.active.remaining) or '')
end
local function point_away(player,boss,distance)
 local dx,dy=player.x-boss.x,player.y-boss.y;local length=math.sqrt(dx*dx+dy*dy)
 if length<0.1 then return end
 local V=require('common/geometry/vector_3')
 return V.new(player.x+dx/length*distance,player.y+dy/length*distance,player.z)
end
local function arrow(g,from,to,paint)
 if not from or not to or type(g.line_3d)~='function'then return end
 pcall(g.line_3d,from,to,paint,5,2.5,false)
 local dx,dy=to.x-from.x,to.y-from.y;local length=math.sqrt(dx*dx+dy*dy);if length<0.1 then return end
 local V=require('common/geometry/vector_3');dx,dy=dx/length,dy/length
 local left=V.new(to.x-dx*2-dy*1.15,to.y-dy*2+dx*1.15,to.z)
 local right=V.new(to.x-dx*2+dy*1.15,to.y-dy*2-dx*1.15,to.z)
 pcall(g.line_3d,to,left,paint,5,2.5,false);pcall(g.line_3d,to,right,paint,5,2.5,false)
end
function M.render(enabled,settings)
 local a=M.active;local g=core.graphics;if not enabled or not a or not g then return end
 if settings and settings.boss_world_cues==false then return end
 local player=U.fn(core.object_manager.get_local_player)
 local pp=call(player,'get_position');local bp=call(a.boss,'get_position');if not pp then return end
 local red,gold,green=world_colors.red,world_colors.gold,world_colors.green
 local direction=a.direction
 if direction=='AWAY'and bp then arrow(g,pp,point_away(pp,bp,9),green)
 elseif (direction=='TO_BOSS'or direction=='FLANK')and bp then arrow(g,pp,bp,direction=='FLANK'and gold or green)
 elseif direction=='EDGE'and type(g.circle_3d)=='function'then pcall(g.circle_3d,pp,5,gold,32,.2)
 elseif direction=='COVER'and type(g.circle_3d)=='function'then pcall(g.circle_3d,pp,3,green,32,.2)
 elseif (a.action=='SPREAD' or a.action=='DODGE' or a.action=='KITE') and type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,5,red,32,.2)
 elseif (a.action=='STACK' or a.action=='SOAK') then
  -- The text card identifies the mechanic; no guessed destination marker.
  if type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,2,green,32,.2) end
 elseif (a.action=='INTERRUPT' or a.action=='SWAP' or a.action=='PRIORITY') and bp and type(g.line_3d)=='function' then pcall(g.line_3d,pp,bp,gold,4,2.5,false)
 elseif a.action=='DEFENSIVE' and type(g.circle_3d)=='function' then pcall(g.circle_3d,pp,3,red,32,.2) end
end
local function lines(text,limit,count)
 local out,current={},''
 for word in tostring(text or ''):gmatch('%S+') do
  if #current>0 and #current+#word+1>limit then out[#out+1]=current;current=word
  else current=current=='' and word or current..' '..word end
  if #out>=count then break end
 end
 if #out<count and current~='' then out[#out+1]=current end
 return out
end
function M.poll_hotkey(C)
 local input=core.input
 if input and type(input.is_key_pressed)=='function' then
  local ok,down=pcall(input.is_key_pressed,0x76)
  if ok and type(down)=='boolean' then
   if down and not M.f7_down and C and C.identity then M.window_enabled=not M.window_enabled end
   M.f7_down=down
  end
 end
end
function M.render_window(C)
 M.poll_hotkey(C)
 local visible=C and C.identity and C.boss_guide and C.boss_guide:get_state()
  and M.window_enabled and core.menu and core.menu.window
 if not visible then if helper_window then helper_window:set_visibility(false) end;return end
 local a=M.active or {name='BOSS HELPER READY',action='WAITING',prompt=M.status,tank='Boss placement appears here when detected.',dps='Your safe position appears here when detected.',remaining=nil}
 local theme=themes[C.identity.id];if not theme then return end
 local V=require('common/geometry/vector_2');local Color=require('common/color');local enums=require('common/enums')
 local accent=Color.new(theme.accent[1],theme.accent[2],theme.accent[3],255)
 local dark=Color.new(theme.dark[1],theme.dark[2],theme.dark[3],244);local white=Color.new(240,246,245,255)
 local muted=Color.new(180,193,201,255);local warning=Color.new(255,104,87,255)
 if not helper_window then
  helper_window=core.menu.window('sylvanas_hunter_boss_helper')
  helper_window:set_initial_position(V.new(555,780));helper_window:set_initial_size(V.new(WIDTH,HEIGHT))
 end
 helper_window:set_visibility(true)
 if helper_window.force_window_size then helper_window:force_window_size(V.new(WIDTH,HEIGHT))end
 if helper_window.set_next_window_min_size then helper_window:set_next_window_min_size(V.new(WIDTH,HEIGHT))end
 local we=enums.window_enums or enums;local font=(we.font_id or {}).FONT_SMALL or 7
 local function text(value,x,y,size,color)
  if helper_window.render_text_custom_size then helper_window:render_text_custom_size(font,V.new(x,y),color or white,size or 12,tostring(value))
  else helper_window:render_text(font,V.new(x,y),color or white,tostring(value))end
 end
 helper_window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,dark,accent,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  helper_window:render_rect_filled(V.new(0,0),V.new(WIDTH,HEIGHT),dark,6)
  if helper_window.render_rect then helper_window:render_rect(V.new(1,1),V.new(WIDTH-1,HEIGHT-1),accent,6,1)end
  require('hh_icons').draw(theme.icon,helper_window,12,12,38,accent,C.identity.id)
  text('HUNTER / '..theme.name,59,9,13,accent)
  text(a.name,59,29,16,white)
  local timer=a.remaining and string.format('  %.1fs',math.max(0,a.remaining)) or ''
  text(a.action..timer,300,35,14,(a.action=='DODGE' or a.action=='DEFENSIVE' or a.action=='INTERRUPT') and warning or accent)
  helper_window:render_rect_filled(V.new(377,8),V.new(428,31),accent,4)
  text('HIDE',386,11,11,dark)
  if helper_window:is_rect_clicked(V.new(377,8),V.new(428,31)) then
   M.window_enabled=false;helper_window:set_visibility(false)
  end
  local prompt=lines(a.prompt,58,2)
  for index,line in ipairs(prompt)do text(line,14,58+(index-1)*17,11,index==1 and white or muted)end
  text('TANK:',14,96,10,accent);text((lines(a.tank,54,1)[1]or''),59,95,10,muted)
  text('DPS:',14,116,10,accent);text((lines(a.dps,55,1)[1]or''),51,115,10,white)
  local cue=({AWAY='GREEN ARROW: MOVE OUT',TO_BOSS='GREEN ARROW: MOVE IN',FLANK='GOLD LINE: USE FLANK',EDGE='GOLD RING: USE EDGE',COVER='GREEN RING: FIND COVER',CENTER='HOLD CENTER',HOLD='HOLD CLEAN FLOOR'})[a.direction]
  if cue then text(cue,14,139,10,accent)end
  text('Auto: '..tostring(require('hh_modes').labels[C.mode] or C.mode)..'  |  F7: show / hide',14,164,10,accent)
 end)
end
function M.on_event(event,args)
 M.last_event={event=event,args=args}
 if event=='ENCOUNTER_END' or event=='PLAYER_DEAD' or event=='PLAYER_LEAVING_WORLD' then M.active=nil;M.status='Encounter ended' end
end
return M
