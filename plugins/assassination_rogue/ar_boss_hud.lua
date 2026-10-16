local Text=require('ar_text')
local Icons=require('ar_icons')
local M={}
local ok,C=pcall(require,'common/color')
local vok,V=pcall(require,'common/geometry/vector_2')
local eok,E=pcall(require,'common/enums')
local window,saved_x,saved_y
local x,y=70,280
local drag,was_down,key_was_down
local manual_visible,boss_hidden,boss_was_active,last_visible=false,false,false,false
local class_names={[1]='WARRIOR',[2]='PALADIN',[3]='HUNTER',[4]='ROGUE',[5]='PRIEST',[6]='DEATH KNIGHT',[7]='SHAMAN',[8]='MAGE',[9]='WARLOCK',[10]='MONK',[11]='DRUID',[12]='DEMON HUNTER',[13]='EVOKER'}
local class_colors={
 [1]={199,156,110},[2]={245,140,186},[3]={171,212,115},[4]={255,245,105},[5]={235,235,235},[6]={196,31,59},
 [7]={0,112,222},[8]={63,199,235},[9]={135,136,238},[10]={0,255,152},[11]={255,125,10},[12]={163,48,201},[13]={51,147,127}}
local spec_names={
 [62]='Arcane',[63]='Fire',[64]='Frost',[65]='Holy',[66]='Protection',[70]='Retribution',[71]='Arms',[72]='Fury',[73]='Protection',
 [102]='Balance',[103]='Feral',[104]='Guardian',[105]='Restoration',[250]='Blood',[251]='Frost',[252]='Unholy',[253]='Beast Mastery',
 [254]='Marksmanship',[255]='Survival',[256]='Discipline',[257]='Holy',[258]='Shadow',[259]='Assassination',[260]='Outlaw',
 [261]='Subtlety',[262]='Elemental',[263]='Enhancement',[264]='Restoration',[265]='Affliction',[266]='Demonology',[267]='Destruction',
 [268]='Brewmaster',[269]='Windwalker',[270]='Mistweaver',[577]='Havoc',[581]='Vengeance',[1467]='Devastation',[1468]='Preservation',[1473]='Augmentation'}
local function call(o,k,...)
 if not o or type(o[k])~='function' then return nil end
 local success,value=pcall(o[k],o,...);if success then return value end
end
local function detect()
 local p=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
 local class_id=tonumber(call(p,'get_class')) or 0
 local spec_id=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or call(p,'get_specialization_id')
 spec_id=tonumber(spec_id) or 0
 local rgb=class_colors[class_id] or {163,233,149}
 return class_names[class_id] or ('CLASS '..class_id),spec_names[spec_id] or ('SPEC '..spec_id),rgb
end
function M.identity()
 local class_name,spec_name=detect()
 return class_name,spec_name
end
M.status='Initializing boss helper'
if ok and vok and eok then
 local initialized,init_error=pcall(function()
 local screen=core.graphics and core.graphics.get_screen_size and core.graphics.get_screen_size()
 if screen and type(screen.x)=='number' and type(screen.y)=='number' then x=math.max(0,screen.x-420);y=math.max(0,screen.y-380) end
 if core.menu.slider_int then
  saved_x=core.menu.slider_int(0,7680,x,'ar_boss_hud_x');saved_y=core.menu.slider_int(0,4320,y,'ar_boss_hud_y')
  x=saved_x:get();y=saved_y:get()
 end
 window=core.menu.window('ar_boss_helper')
 window:set_initial_position(V.new(x,y));window:set_initial_size(V.new(390,168))
 end)
 M.status=initialized and 'Boss helper ready' or ('Boss helper init failed: '..tostring(init_error))
else M.status='Boss helper dependencies unavailable' end
function M.render(s)
 if not window then return end
 local boss_active=s and s.active~=nil
 if boss_active and not boss_was_active then boss_hidden=false end
 if not boss_active then boss_hidden=false end
 boss_was_active=boss_active
 local visible=manual_visible or boss_active and not boss_hidden
 local key_down=core.input and core.input.is_key_pressed and core.input.is_key_pressed(0x76)==true
 if key_down and not key_was_down then
  if visible then manual_visible=false;boss_hidden=boss_active
  else manual_visible=true;boss_hidden=false end
 end
 key_was_down=key_down
 visible=s and s.enabled==true and (manual_visible or boss_active and not boss_hidden) or false
 last_visible=visible
 window:set_visibility(visible)
 if not visible then return end
 local active=s.active or {name='Waiting for boss',role='MELEE DPS',action='READY',mechanic='Boss detection',prompt=s.status or 'Select or approach the dungeon boss'}
 local rendered,render_error=pcall(function()
  local cursor=core.get_cursor_position and core.get_cursor_position()
  local down=core.input and core.input.is_key_pressed and core.input.is_key_pressed(0x01)==true
  if down and not was_down and cursor and cursor.x>=x and cursor.x<=x+390 and cursor.y>=y and cursor.y<=y+31 then drag={dx=cursor.x-x,dy=cursor.y-y} end
  if drag and down and cursor then x=math.max(0,cursor.x-drag.dx);y=math.max(0,cursor.y-drag.dy) elseif not down then drag=nil end
  if drag and saved_x then saved_x:set(math.floor(x));saved_y:set(math.floor(y)) end
  local screen=core.graphics and core.graphics.get_screen_size and core.graphics.get_screen_size()
  if screen and type(screen.x)=='number' and type(screen.y)=='number' then x=math.min(x,math.max(0,screen.x-390));y=math.min(y,math.max(0,screen.y-168)) end
  was_down=down
  if window.force_window_size then window:force_window_size(V.new(390,168)) end
  if window.force_next_begin_window_pos then window:force_next_begin_window_pos(V.new(x,y)) end
  local we=E.window_enums or E;local f=we.font_id and we.font_id.FONT_SMALL or 0
  local class_name,spec_name,rgb=detect()
  local accent=C.new(rgb[1],rgb[2],rgb[3],255);local white=C.new(238,244,239,255);local muted=C.new(185,202,190,255)
  window:begin(0,false,C.new(16,13,20,245),accent,we.window_cross_visuals and (we.window_cross_visuals.NO_CROSS or 9) or 9,function()
   local function line(value,yy,col,limit) window:render_text(f,V.new(52,yy),col,Text.compact(value,limit or 45)) end
   Icons.draw(Icons.for_label(class_name),12,10,30,x,y,window)
   line('DUNGEON BOSS HELPER',10,accent)
   window:render_rect_filled(V.new(326,7),V.new(381,30),C.new(88,25,38,245),4)
   window:render_rect(V.new(326,7),V.new(381,30),accent,4,1)
   window:render_text(f,V.new(336,11),white,'HIDE')
   if window:is_rect_clicked(V.new(326,7),V.new(381,30)) then
    manual_visible=false;boss_hidden=boss_active;last_visible=false;window:set_visibility(false)
   end
   line(spec_name:upper()..' '..class_name..' | '..tostring(active.role or 'DPS'),34,white)
   line(tostring(s.instance or 'Dungeon')..' | '..tostring(active.name or 'Boss'),60,accent)
   local timer=active.remaining and string.format(' | %.1fs',active.remaining) or ''
   line(tostring(active.action or 'GUIDE')..': '..tostring(active.mechanic or 'Current plan')..timer,87,white)
   line(tostring(active.prompt or s.status or 'Evaluate encounter'),113,accent,49)
   line('Auto detected | drag header | F7 show/hide',141,muted)
  end)
 end)
 M.status=rendered and (s.active and 'Showing live boss guidance' or 'Visible; waiting for boss detection') or ('Boss helper render failed: '..tostring(render_error))
 if not rendered and core.log_warning then pcall(core.log_warning,'[Assassination Boss Helper] '..tostring(render_error)) end
end
function M.is_hidden() return not last_visible end
return M
