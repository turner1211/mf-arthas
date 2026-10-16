local U=require('ui_util')
local V,Color,E=require('common/geometry/vector_2'),require('common/color'),require('common/enums')
local R={windows={}}
local textures={};local attempted={}
local function image(w,key,x,y,width,height)
 if not core.graphics or not core.graphics.load_texture or not core.graphics.draw_texture or not w.get_position then return end
 if not attempted[key]then
  attempted[key]=true
  local ok,bytes=pcall(function()return key=='background' and require('ui_art') or require('ui_icon_art')[key]end)
  if ok then textures[key]=U.fn(core.graphics.load_texture,bytes)end
 end
 if textures[key]then
  local pos=w:get_position()
  U.fn(core.graphics.draw_texture,textures[key],V.new(pos.x+x,pos.y+y),width,height,Color.new(255,255,255,255),true)
 end
end
function R.prepare(s)
 if not R.switch and core.menu.window then
  local factory=core.menu.window
  R.switch=type(factory)=='table' and factory.new('suu_show_hide') or factory('suu_show_hide')
  R.switch:set_initial_position(V.new(20,650));R.switch:set_initial_size(V.new(124,38))
 end
 if not s or not core.menu.window or R.windows[s.profile.id] then return end
 local factory=core.menu.window;local tag='sylvanas_universal_ui_'..s.profile.id
 if type(factory)=='table' and type(factory.new)=='function' then R.windows[s.profile.id]=factory.new(tag)
 else R.windows[s.profile.id]=factory(tag)end
end
function R.toggle(C)
 if not R.switch then return end
 local w=R.switch;w:set_visibility(true)
 if w.force_window_size then w:force_window_size(V.new(124,38))end
 local we=E.window_enums or E
 w:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,Color.new(33,14,24,250),Color.new(215,57,76,255),(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  w:render_rect_filled(V.new(0,0),V.new(124,38),Color.new(80,24,34,250),5)
  image(w,'poison',4,4,30,30)
  local label=C.enabled:get_state() and 'HIDE UI' or 'SHOW UI'
  if w.render_text_custom_size then w:render_text_custom_size(7,V.new(40,10),Color.new(255,255,255,255),14,label)
  else w:render_text(7,V.new(40,10),Color.new(255,255,255,255),label)end
  if w.is_rect_clicked and w:is_rect_clicked(V.new(0,0),V.new(124,38))then
   local show=not C.enabled:get_state();C.enabled:set(show)
   if show then C.combat_only:set(false);R.layouts={}end
  end
 end)
end
function R.hide()
 for _,w in pairs(R.windows)do w:set_visibility(false)end
end
function R.render(S,C)require('ui_tabs').render(R,S,C,image)end
return R
