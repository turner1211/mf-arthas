-- Compact, automatically themed dungeon boss-helper window.
local Boss,Dps=require('ww_boss_guides'),require('ww_dps_boss_guides')
local H={open=true,f7_down=false};local color,V,enums,window
local wx,wy,W,HGT=70,280,430,164
local drag,mouse_old,init_error
local themes={
 [71]={name='ARMS',role='DPS',a={205,55,67},g={246,115,115},d={27,8,13}},
 [72]={name='FURY',role='DPS',a={225,103,28},g={255,190,61},d={34,13,4}},
 [73]={name='PROTECTION',role='TANK',a={48,130,205},g={108,203,255},d={4,17,34}}
}
local function initialize()
 if window then return true end
 local ok,err=pcall(function()
  color=require('common/color');V=require('common/geometry/vector_2');enums=require('common/enums')
  local screen=core.graphics and type(core.graphics.get_screen_size)=='function'and core.graphics.get_screen_size()or nil
  if screen and type(screen.x)=='number'and type(screen.y)=='number'then wx=math.max(0,screen.x-W-24);wy=math.max(0,math.min(280,screen.y-HGT-24))end
  window=core.menu.window('sylvanas_warrior_boss_hud_012');window:set_initial_position(V.new(wx,wy));window:set_initial_size(V.new(W,HGT))
  if window.set_render_layer then window:set_render_layer(1)end;window:set_visibility(false)
 end)
 if not ok then init_error=tostring(err);window=nil;return false end
 return true
end
local function compact(v,n)v=tostring(v or'');return #v<=n and v or v:sub(1,n-3)..'...'end
local function mechanic(identity)
 if identity.id==73 then return Boss.active==true,Boss.action or'MONITOR',Boss.instruction or Boss.status,Boss.remaining,Boss.active and Boss.position_text end
 local a=Dps.active
 return a~=nil,a and a.action or'MONITOR',a and a.prompt or Dps.status,a and a.remaining,a and a.position_text
end
local function paint(identity,mode)
 local t=themes[identity.id];local e=enums.window_enums or enums;local f=e.font_id or{}
 local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
 local function box(x,y,x2,y2,col,r)window:render_rect_filled(V.new(x,y),V.new(x2,y2),col,r or 5)end
 local function edge(x,y,x2,y2,col,r,w)if window.render_rect then window:render_rect(V.new(x,y),V.new(x2,y2),col,r or 5,w or 1)end end
 local function text(s,x,y,font,col)window:render_text(font or f.FONT_SMALL or 0,V.new(x,y),col,tostring(s or''))end
 local function hit(x,y,x2,y2)return window:is_rect_clicked(V.new(x,y),V.new(x2,y2))end
 local A,G,D=color.new(t.a[1],t.a[2],t.a[3]),color.new(t.g[1],t.g[2],t.g[3]),color.new(t.d[1],t.d[2],t.d[3])
 local active,action,prompt,remaining,position=mechanic(identity)
 box(0,0,W,HGT,D,9);edge(1,1,W-2,HGT-2,A,9,2)
 box(10,10,58,58,c(5,11,18,250),7);edge(10,10,58,58,G,7,2)
 if identity.id==71 then box(30,16,38,45,G,2);box(20,42,48,49,A,2)
 elseif identity.id==72 then box(20,18,27,48,A,2);box(40,18,47,48,A,2);box(16,14,31,24,G,3);box(36,14,51,24,G,3)
 else box(18,17,50,43,A,6);box(24,23,44,49,c(8,35,62),5);box(31,25,37,45,G,2)end
 text('WARRIOR BOSS HELPER',70,12,f.FONT_SEMI_BIG or 0,c(244,247,250));text(t.name..'  |  '..t.role..'  |  '..string.upper(tostring(mode)),70,38,f.FONT_SMALL or 0,G)
 box(365,12,418,48,c(t.a[1],t.a[2],t.a[3],230),6);edge(365,12,418,48,G,6,1);text('HIDE',375,23,f.FONT_SMALL or 0,c(244,247,250));if hit(365,12,418,48)then H.open=false;window:set_visibility(false)end
 box(10,68,W-10,147,c(7,15,24,246),7);edge(10,68,W-10,147,active and G or A,7,active and 2 or 1)
 box(20,80,112,111,active and G or c(57,68,80),6);text(active and action or'MONITOR',31,88,f.FONT_SMALL or 0,active and c(7,17,23)or c(230,236,242))
 text(compact(prompt,42),126,79,f.FONT_SMALL or 0,c(244,247,250));text(active and'LIVE MECHANIC'or'Watching supported boss casts and timers',126,103,f.FONT_SMALL or 0,c(188,205,220))
 if type(remaining)=='number'then text(string.format('%.1fs',remaining),354,88,f.FONT_SEMI_BIG or 0,G)end
 text(position or'AUTO SPEC POSITIONING',20,125,f.FONT_SMALL or 0,G);text('F7 SHOW/HIDE  |  DRAG',255,125,f.FONT_SMALL or 0,c(188,205,220))
end
function H.render(identity,mode,enabled)
 local f7=false;if core.input and type(core.input.is_key_pressed)=='function'then local ok,v=pcall(core.input.is_key_pressed,0x76);f7=ok and v==true end
 if f7 and not H.f7_down then H.open=not H.open end;H.f7_down=f7
 -- Remain visible as a preview on a supported Warrior so placement and F7 can
 -- be tested before entering an instance. Mechanic data still activates only
 -- through the role-isolated dungeon guide modules.
 local eligible=enabled==true and identity and themes[identity.id]
 if not eligible or not H.open then if window then window:set_visibility(false)end;return end
 if not initialize()then return false,init_error end;window:set_visibility(true)
 local cursor=type(core.get_cursor_position)=='function'and core.get_cursor_position()or nil;local mouse=false
 if core.input and type(core.input.is_key_pressed)=='function'then local ok,v=pcall(core.input.is_key_pressed,0x01);mouse=ok and v==true end
 if cursor and mouse and not mouse_old and cursor.x>=wx and cursor.x<=wx+W and cursor.y>=wy and cursor.y<=wy+64 then drag={x=cursor.x-wx,y=cursor.y-wy}end
 if drag and mouse and cursor then wx=math.max(0,cursor.x-drag.x);wy=math.max(0,cursor.y-drag.y)elseif drag and not mouse then drag=nil end;mouse_old=mouse
 local screen=core.graphics and type(core.graphics.get_screen_size)=='function'and core.graphics.get_screen_size()or nil
 if screen and type(screen.x)=='number'and type(screen.y)=='number'then wx=math.min(wx,math.max(0,screen.x-W));wy=math.min(wy,math.max(0,screen.y-HGT))end
 local e=enums.window_enums or enums;local flags=e.window_resizing_flags or{};local visuals=e.window_cross_visuals or{}
 if window.force_window_size then window:force_window_size(V.new(W,HGT))end;if window.force_next_begin_window_pos then window:force_next_begin_window_pos(V.new(wx,wy))end
 local t=themes[identity.id];window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,color.new(t.d[1],t.d[2],t.d[3]),color.new(t.a[1],t.a[2],t.a[3]),visuals.NO_CROSS or 9,function()paint(identity,mode)end)
 return true
end
return H
