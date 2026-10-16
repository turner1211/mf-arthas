local H={manual_open=false,suppress_auto=false,f7_down=false};local window
local themes={
 [62]={name='ARCANE',icon='arcane',accent={192,144,255},dark={19,10,39}},
 [63]={name='FIRE',icon='fire',accent={255,166,73},dark={42,13,10}},
 [64]={name='FROST',icon='frost',accent={116,222,255},dark={7,25,43}}
}
local function live_mage(C)
 local U=require('sm_util');local player=core and core.object_manager and U.fn(core.object_manager.get_local_player)
 return U.valid(player) and U.number(U.call(player,'get_class'))==8 and C.identity and themes[C.identity.id] and C.identity.id or nil
end
local function split(text,limit)
 text=tostring(text or ''):gsub('[\r\n]+',' ');local rows={}
 while #text>limit do
  local cut=limit
  while cut>25 and text:sub(cut,cut)~=' 'do cut=cut-1 end
  rows[#rows+1]=text:sub(1,cut):gsub('%s+$','');text=text:sub(cut+1):gsub('^%s+','')
 end
 if #text>0 then rows[#rows+1]=text end
 return rows
end
function H.render(C)
 local spec=live_mage(C)
 if not spec then H.f7_down=false;if window then window:set_visibility(false)end;return end
 local boss=require('sm_dps_boss_guides');local boss_active=boss.active~=nil and C.mode~='arena'and C.mode~='battleground'and C.mode~='world_pvp'
 if not boss_active then H.suppress_auto=false end
 local down=false
 if core.input and type(core.input.is_key_pressed)=='function'then local ok,value=pcall(core.input.is_key_pressed,0x76);down=ok and value==true end
 if down and not H.f7_down then
  local currently_open=H.manual_open or boss_active and not H.suppress_auto
  H.manual_open=not currently_open
  if currently_open and boss_active then H.suppress_auto=true elseif H.manual_open then H.suppress_auto=false end
 end
 H.f7_down=down
 local visible=C.boss_guide:get_state()and(H.manual_open or boss_active and not H.suppress_auto)
 if not visible or not core.menu.window then if window then window:set_visibility(false)end;return end
 local V=require('common/geometry/vector_2');local Color=require('common/color');local enums=require('common/enums')
 local t=themes[spec];local accent=Color.new(t.accent[1],t.accent[2],t.accent[3],255)
 local dark=Color.new(t.dark[1],t.dark[2],t.dark[3],242);local panel=Color.new(7,12,19,239)
 local white=Color.new(242,247,250,255);local muted=Color.new(174,192,204,255)
 if not window then
  window=core.menu.window('sylvanas_mage_boss_helper');window:set_initial_position(V.new(78,780));window:set_initial_size(V.new(520,160))
  if window.set_render_layer then window:set_render_layer(1)end
 end
 window:set_visibility(true);if window.force_window_size then window:force_window_size(V.new(520,160))end
 local we=enums.window_enums or enums
 window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,dark,accent,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  local function rect(x,y,w,h,c,r)window:render_rect_filled(V.new(x,y),V.new(x+w,y+h),c,r or 4)end
  local function text(s,x,y,c)window:render_text(7,V.new(x,y),c or white,tostring(s))end
  rect(5,5,510,150,panel,6)
  require('sm_icons').draw(t.icon,window,13,13,42,accent,spec)
  local mode=tostring(C.mode or 'waiting');text('MAGE / '..t.name,64,11,accent);text((mode=='mythic_plus'and'MYTHIC+'or mode:upper():gsub('_',' '))..' BOSS HELPER',64,31,muted)
  local active=boss.active
  local action=active and active.action or 'GUIDE';local name=active and active.name or 'Waiting for recognized boss'
  local badge=action=='DODGE'and Color.new(235,58,58,255)or action=='INTERRUPT'and Color.new(255,190,55,255)or action=='DEFENSIVE'and Color.new(255,110,72,255)or accent
  rect(334,13,110,30,badge,6);text(action,346,20,Color.new(8,14,20,255))
  rect(450,13,55,30,Color.new(55,65,75,245),6);text('HIDE',459,20,white)
  if window:is_rect_clicked(V.new(450,13),V.new(505,43))then H.manual_open=false;H.suppress_auto=boss_active;window:set_visibility(false)end
  text(name,14,62,white)
  local prompt=active and active.prompt or C.gameplay or boss.status
  local rows=split(prompt,72);text(rows[1]or'',14,83,muted);if rows[2]then text(rows[2],14,100,muted)end
  local position=active and active.position or 'Manual view; waiting for boss position data.';local posrows=split('POSITION: '..position,67)
  text(posrows[1]or'',14,119,accent);if posrows[2]then text(posrows[2],14,136,accent)end;text('F7',487,136,muted)
 end)
end
return H
