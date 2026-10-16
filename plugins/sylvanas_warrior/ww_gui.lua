-- Clean, spec-aware Warrior command window. All art and controls are rendered from Lua.
local C,M=require('ww_settings'),require('ww_modes')
local Log=require('ww_log')
local G={page=1,scroll=0,edit_mode=nil,open=true,f1_down=false,listening=nil}
local color,V,enums,window
local S=0.90;local BW,BH=1120,720;local W,H=math.floor(BW*S),math.floor(BH*S)
local wx,wy=34,34;local drag,mouse_old,reported,last_spec,last_mode,initialization_error
local pages={'CORE','ABILITIES','UTILITY','DEFENSE','PLAYERS','DUNGEONS','VISUALS','DIAGNOSTICS'}
local groups={
 ABILITIES={'damage','cooldowns','aoe','charge','stances','cooldown_min_enemies','cooldown_min_ttd'},
 UTILITY={'interrupts','interrupt_percent','cc','taunt','mplus_stops','timer_defensives'},
 DEFENSE={'defensives','low_hp','heal_hp','ignore_pain_hp','block_refresh'},
 PLAYERS={'automatic_burst','pvp_trinket_window','arena_peel','arena_control','pvp_lines'}
}
local themes={
 [71]={name='ARMS',title='MASTER OF ARMS',sub='PRECISION / PRESSURE / EXECUTION',a={190,55,67},g={244,128,135},d={12,13,17}},
 [72]={name='FURY',title='UNBOUND FURY',sub='MOMENTUM / RAGE / ONSLAUGHT',a={205,91,28},g={255,187,74},d={14,13,12}},
 [73]={name='PROTECTION',title='THE IRON WALL',sub='CONTROL / MITIGATION / COMMAND',a={48,116,184},g={111,199,250},d={10,14,19}}
}
local key_names={[0]='UNBOUND',[0x08]='BACKSPACE',[0x09]='TAB',[0x0D]='ENTER',[0x10]='SHIFT',[0x11]='CTRL',[0x12]='ALT',[0x1B]='ESC',[0x20]='SPACE',[0x21]='PAGE UP',[0x22]='PAGE DOWN',[0x23]='END',[0x24]='HOME',[0x25]='LEFT',[0x26]='UP',[0x27]='RIGHT',[0x28]='DOWN',[0x2D]='INSERT',[0x2E]='DELETE'}
for i=0,9 do key_names[0x30+i]=tostring(i);key_names[0x60+i]='NUM '..i end
for i=0,25 do key_names[0x41+i]=string.char(65+i)end
for i=1,12 do key_names[0x6F+i]='F'..i end
local function initialize_window()
 if window then return true end
 local ok,err=pcall(function()
  color=require('common/color');V=require('common/geometry/vector_2');enums=require('common/enums')
  window=core.menu.window('sylvanas_warrior_051');window:set_initial_position(V.new(wx,wy));window:set_initial_size(V.new(W,H))
  if window.set_render_layer then window:set_render_layer(1)end;window:set_visibility(false)
 end)
 if not ok then initialization_error=tostring(err);window=nil;return false end
 return true
end
local function value(w)return w and(w.get_state and w:get_state()or w:get())end
local function compact(v,n)v=tostring(v or'');return #v<=n and v or v:sub(1,n-3)..'...'end
local function wheel_delta()
 local list={core.input and core.input.get_mouse_wheel_delta,core.get_mouse_wheel_delta,core.graphics and core.graphics.get_mouse_wheel_delta}
 for _,fn in ipairs(list)do if type(fn)=='function'then local ok,v=pcall(fn);if ok and type(v)=='number'and v~=0 then return v end end end
 return 0
end
local function pressed(vk)
 if core.input and type(core.input.is_key_pressed)=='function'then local ok,v=pcall(core.input.is_key_pressed,vk);return ok and v==true end
 return false
end
local function capture_hotkey(mouse)
 local listen=G.listening;if not listen then return end
 if not listen.armed then if not mouse then listen.armed=true end;return end
 for vk=0x08,0xFE do if pressed(vk)then
  if vk==0x1B then G.notice='HOTKEY ASSIGNMENT CANCELLED'
  elseif vk==0x70 or vk==0x76 then G.notice='F1 AND F7 ARE RESERVED FOR THE TWO WARRIOR WINDOWS'
  elseif vk==0x08 or vk==0x2E then listen.hotkey:set_key(0);G.notice=listen.label..' HOTKEY CLEARED'
  else listen.hotkey:set_key(vk);G.notice=listen.label..' HOTKEY SET TO '..(key_names[vk]or string.format('KEY %02X',vk))end
  G.listening=nil;return
 end end
end
local function paint(spec)
 local identity=G.identity;local t=themes[spec];local e=enums.window_enums or enums;local f=e.font_id or{}
 local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
 local A,GLOW=c(t.a[1],t.a[2],t.a[3]),c(t.g[1],t.g[2],t.g[3])
 local TEXT,MUTED,PANEL,ROW=c(238,241,245),c(151,159,169),c(14,16,21,248),c(22,24,30,246)
 local function p(x)return math.floor(x*S+.5)end
 local function box(x,y,x2,y2,col,r)window:render_rect_filled(V.new(p(x),p(y)),V.new(p(x2),p(y2)),col,p(r or 3))end
 local function edge(x,y,x2,y2,col,r,w)if window.render_rect then window:render_rect(V.new(p(x),p(y)),V.new(p(x2),p(y2)),col,p(r or 3),math.max(1,p(w or 1)))end end
 local function text(s,x,y,font,col)window:render_text(font or f.FONT_SMALL or 0,V.new(p(x),p(y)),col or TEXT,tostring(s or''))end
 local function hit(x,y,x2,y2)return window:is_rect_clicked(V.new(p(x),p(y)),V.new(p(x2),p(y2)))end
 local function over(x,y,x2,y2)return window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(p(x),p(y)),V.new(p(x2),p(y2)))end
 local function button(label,x,y,x2,y2,on,fn)
  local hover=over(x,y,x2,y2);box(x,y,x2,y2,on and GLOW or(hover and c(t.a[1],t.a[2],t.a[3],180)or ROW),3);edge(x,y,x2,y2,on and c(252,245,229)or(hover and GLOW or c(65,68,76)),3,1)
  text(label,x+10,y+8,f.FONT_SMALL or 0,on and c(12,14,18)or TEXT);if hit(x,y,x2,y2)then fn()end
 end
 local function key_button(label,hotkey,x,y)
  local key=hotkey and hotkey.get_key_code and hotkey:get_key_code()or 0;local listening=G.listening and G.listening.hotkey==hotkey
  button(listening and'PRESS A KEY...'or('KEY: '..(key_names[key]or string.format('%02X',key))),x,y,x+137,y+31,listening,function()G.listening={hotkey=hotkey,label=label,armed=false}end)
 end
 local function bool_row(label,help,state,hotkey,y,setter)
  local hover=over(286,y,1095,y+58);box(286,y,1095,y+58,hover and c(31,33,40,250)or ROW,3);box(286,y,290,y+58,A,1)
  text(compact(label,46),307,y+8,f.FONT_SMALL or 0,TEXT);text(compact(help,76),307,y+31,f.FONT_SMALL or 0,MUTED)
  key_button(label,hotkey,824,y+13);button(state and'ON'or'OFF',972,y+13,1080,y+44,state,function()setter(not state)end)
 end
 local function number_row(key,y)
  local w=C.control(spec,G.edit_mode,key);local v=value(w);box(286,y,1095,y+58,ROW,3);box(286,y,290,y+58,A,1)
  text(C.labels[key]or key,307,y+8,f.FONT_SMALL or 0,TEXT);text(compact(C.help[key]or'',76),307,y+31,f.FONT_SMALL or 0,MUTED)
  button('-',881,y+13,923,y+44,false,function()C.set(spec,G.edit_mode,key,v-1)end);text(tostring(v)..(C.units[key]or''),937,y+21,f.FONT_SMALL or 0,GLOW);button('+',1038,y+13,1080,y+44,false,function()C.set(spec,G.edit_mode,key,v+1)end)
 end
 box(0,0,BW,BH,c(t.d[1],t.d[2],t.d[3],255),0);box(0,0,BW,88,c(17,18,23,252),0);box(0,88,BW,89,A,0)
 text(t.name..' WARRIOR',20,17,f.FONT_BIG or 0,TEXT);text(t.title..'  /  '..t.sub,20,49,f.FONT_SMALL or 0,GLOW)
 text('F1 SHOW / HIDE  •  DRAG HEADER',744,49,f.FONT_SMALL or 0,MUTED);button('X',1065,16,1101,50,false,function()G.open=false end)
 local tabw=135
 for i,name in ipairs(pages)do local x=20+(i-1)*tabw;local active=G.page==i;box(x,96,x+124,130,active and c(t.a[1],t.a[2],t.a[3],80)or c(15,17,22),2);text(name,x+10,105,f.FONT_SMALL or 0,active and GLOW or MUTED);if active then box(x,128,x+124,131,GLOW,0)end;if hit(x,96,x+124,130)then G.page=i;G.scroll=0 end end
 box(20,142,1100,190,PANEL,4);text('DETECTED: '..string.upper(M.labels[G.mode]or tostring(G.mode)),35,153,f.FONT_SMALL or 0,TEXT);text('EDITING: '..string.upper(M.labels[G.edit_mode]or tostring(G.edit_mode)),260,153,f.FONT_SMALL or 0,GLOW);text('STATUS: '..compact(C.status,55),500,153,f.FONT_SMALL or 0,MUTED);button(value(C.enabled)and'PLUGIN ON'or'PLUGIN OFF',970,150,1085,181,value(C.enabled),function()C.set_global('enabled',not value(C.enabled))end)
 box(20,202,268,681,PANEL,4);text('ACTIVITY PROFILE',36,218,f.FONT_SEMI_BIG or 0,TEXT);text('Choose any mode to edit',36,244,f.FONT_SMALL or 0,MUTED)
 for i,mode in ipairs(M.order)do local y=275+(i-1)*43;button(string.upper(M.labels[mode]or mode),35,y,253,y+34,G.edit_mode==mode,function()G.edit_mode=mode;G.scroll=0 end)end
 box(282,202,1100,681,PANEL,4);text(pages[G.page],302,218,f.FONT_SEMI_BIG or 0,GLOW);text('Every ON/OFF setting has an independent persistent hotkey.',302,244,f.FONT_SMALL or 0,MUTED)
 local rows={}
 local function profile(key,label)if C.visible(spec,key,G.edit_mode)and C.control(spec,G.edit_mode,key)then rows[#rows+1]={kind=type(value(C.control(spec,G.edit_mode,key)))=='boolean'and'bool'or'number',key=key,label=label}end end
 local function global(key,label,help,condition)if condition==nil or condition then rows[#rows+1]={kind='global',key=key,label=label,help=help}end end
 local page=pages[G.page]
 if page=='CORE'then global('enabled','PLUGIN ENABLED','Master switch for every Warrior profile.');global('pause','PAUSE ALL ACTIONS','Stop casting while keeping both interfaces available.');profile('enabled','ENABLE THIS SPEC AND MODE');profile('damage');profile('cooldowns')
 elseif groups[page]then for _,key in ipairs(groups[page])do profile(key)end
 elseif page=='DUNGEONS'then global('route_map','PROTECTION ROUTE OVERLAY','Automatic dungeon position, route, and next-pull guidance.',spec==73);global('boss_guide','BOSS HELPER WINDOW','Role-specific boss guidance in the separate F7 window.');profile('mplus_stops');profile('timer_defensives')
 elseif page=='VISUALS'then global('themed_gui','SHOW MAIN GUI','Show this F1 Warrior command window.');global('route_map','SHOW ROUTE OVERLAY','Protection dungeon route and pull guidance.',spec==73);global('boss_guide','SHOW BOSS HELPER','Show the class and spec themed F7 helper.');profile('pvp_lines')
 else global('logging','RECORD DIAGNOSTICS','Save crash-safe logs that can be pasted into chat.');global('training_dummy','TRAINING DUMMY MODE','Run the active PvE rotation against selected city dummies.')end
 local max=math.max(0,#rows-6);G.scroll=math.max(0,math.min(G.scroll,max))
 for i=1,6 do local row=rows[G.scroll+i];if row then local y=276+(i-1)*63
  if row.kind=='global'then bool_row(row.label,row.help,value(C[row.key]),C.global_hotkeys[row.key],y,function(v)C.set_global(row.key,v)end)
  elseif row.kind=='bool'then local key=row.key;bool_row(row.label or C.labels[key],C.help[key]or'',value(C.control(spec,G.edit_mode,key)),C.hotkey(spec,G.edit_mode,key),y,function(v)C.set(spec,G.edit_mode,key,v)end)
  else number_row(row.key,y)end
 end end
 if max>0 then button('UP',930,226,996,258,false,function()G.scroll=math.max(0,G.scroll-1)end);button('DOWN',1005,226,1085,258,false,function()G.scroll=math.min(max,G.scroll+1)end)end
 if page=='DUNGEONS'and spec==73 then local R=require('ww_routes');text(compact(R.status,62),302,658,f.FONT_SMALL or 0,MUTED);button('PREVIOUS PULL',700,643,818,674,false,R.actions.previous);button('NEXT PULL',827,643,927,674,false,R.actions.next);button('RESET ROUTE',936,643,1085,674,false,R.actions.reset)
 elseif page=='DIAGNOSTICS'then button('COPY SAVED LOG',302,643,475,674,false,function()if type(window.copy_to_clipboard)=='function'then local ok=pcall(window.copy_to_clipboard,window,Log.copy_text());G.notice=ok and'LOG COPIED — PASTE IT INTO CHAT'or'COPY FAILED'end end);button('COPY LOG PATHS',486,643,655,674,false,function()local a,b=Log.paths();if type(window.copy_to_clipboard)=='function'then local ok=pcall(window.copy_to_clipboard,window,a..'\n'..b);G.notice=ok and'LOG PATHS COPIED'or'COPY FAILED'end end);text(compact(G.notice or'Crash-safe log checkpoints remain after a disconnect.',48),674,651,f.FONT_SMALL or 0,MUTED)end
 box(0,698,BW,720,c(16,17,22),0);text('SYLVANAS WARRIOR  v0.9.54',20,702,f.FONT_SMALL or 0,MUTED);text(G.listening and'RELEASE THE MOUSE, THEN PRESS THE DESIRED KEY  •  ESC CANCELS'or'F1 MAIN GUI  •  F7 BOSS HELPER  •  F1/F7 RESERVED',653,702,f.FONT_SMALL or 0,G.listening and GLOW or MUTED)
 edge(1,1,BW-2,BH-2,A,5,1)
end
local function render()
 if C.identity then G.identity=C.identity;G.mode=C.mode or G.mode;if last_spec~=C.identity.id then G.edit_mode=G.mode;G.page=1;G.scroll=0 elseif last_mode~=G.mode and(G.edit_mode==nil or G.edit_mode==last_mode)then G.edit_mode=G.mode;G.scroll=0 end;last_spec,last_mode=C.identity.id,G.mode end
 local f1=pressed(0x70);if f1 and not G.f1_down then G.open=not G.open end;G.f1_down=f1
 if not G.identity or not C.themed_gui or not value(C.themed_gui)or not G.open then if window then window:set_visibility(false)end;return end
 if not initialize_window()then return false,initialization_error end;window:set_visibility(true)
 local cursor=type(core.get_cursor_position)=='function'and core.get_cursor_position()or nil;local mouse=pressed(0x01);capture_hotkey(mouse)
 if cursor and mouse and not mouse_old and not G.listening and cursor.x>=wx and cursor.x<=wx+W and cursor.y>=wy and cursor.y<=wy+82*S then drag={x=cursor.x-wx,y=cursor.y-wy}end
 if drag and mouse and cursor then wx=math.max(0,cursor.x-drag.x);wy=math.max(0,cursor.y-drag.y)elseif drag and not mouse then drag=nil end;mouse_old=mouse
 if cursor and cursor.x>=wx+282*S and cursor.x<=wx+1100*S and cursor.y>=wy+202*S and cursor.y<=wy+681*S then local wheel=wheel_delta();if wheel~=0 then G.scroll=math.max(0,G.scroll+(wheel<0 and 1 or-1))end end
 local e=enums.window_enums or enums;local flags=e.window_resizing_flags or{};local visuals=e.window_cross_visuals or{};if window.force_window_size then window:force_window_size(V.new(W,H))end;if window.force_next_begin_window_pos then window:force_next_begin_window_pos(V.new(wx,wy))end;local t=themes[G.identity.id];window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,color.new(t.d[1],t.d[2],t.d[3]),color.new(t.a[1],t.a[2],t.a[3]),visuals.NO_CROSS or 9,function()paint(G.identity.id)end)
end
function G.render()local ok,err=pcall(render);if not ok and not reported then reported=true;if core.log_warning then pcall(core.log_warning,'[Warrior GUI] '..tostring(err))end end end
return G
