-- Compact artwork-led panel patterned after the installed Rogue GUI.
local M={}
local Icons=require("rs_icons")
local color,vec2,enums,window
local art_texture,art_attempted=nil,false
local render_reported=false
local page,scroll=1,0
local win_x,win_y=45,45
local dragging,mouse_was_down,reported=nil,false,false
local slider_drag=nil
local position_loaded=false
local draw_scale,font_scale_pct=1,100
local fonts={}
local panel_w,panel_h=1000,760

pcall(function()
 color=require("common/color");vec2=require("common/geometry/vector_2");enums=require("common/enums")
 window=core.menu.window("rsm_tidal_command_381")
 window:set_initial_position(vec2.new(win_x,win_y));window:set_initial_size(vec2.new(panel_w,panel_h))
 if type(window.set_render_layer)=="function" then window:set_render_layer(1) end
 window:set_visibility(true)
end)
local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
local function rect(x1,y1,x2,y2,col,r)window:render_rect_filled(vec2.new(x1*draw_scale,y1*draw_scale),vec2.new(x2*draw_scale,y2*draw_scale),col,(r or 5)*draw_scale)end
local function outline(x1,y1,x2,y2,col,r,w)window:render_rect(vec2.new(x1*draw_scale,y1*draw_scale),vec2.new(x2*draw_scale,y2*draw_scale),col,(r or 5)*draw_scale,(w or 1)*draw_scale)end
local function font_for(f)
 if font_scale_pct>=115 then
  if f==fonts.FONT_VERY_SMALL then return fonts.FONT_SMALL or f end
  if f==fonts.FONT_SMALL then return fonts.FONT_SEMI_BIG or f end
  if f==fonts.FONT_SEMI_BIG then return fonts.FONT_BIG or f end
 elseif font_scale_pct<=90 then
  if f==fonts.FONT_BIG then return fonts.FONT_SEMI_BIG or f end
  if f==fonts.FONT_SEMI_BIG then return fonts.FONT_SMALL or f end
  if f==fonts.FONT_SMALL then return fonts.FONT_VERY_SMALL or f end
 end
 return f
end
local function text(v,x,y,f,col)window:render_text(font_for(f),vec2.new(x*draw_scale,y*draw_scale),col,tostring(v or ""))end
local function clicked(x1,y1,x2,y2)return window:is_rect_clicked(vec2.new(x1*draw_scale,y1*draw_scale),vec2.new(x2*draw_scale,y2*draw_scale))end
local function hovered(x1,y1,x2,y2)return window:is_mouse_hovering_rect(vec2.new(x1*draw_scale,y1*draw_scale),vec2.new(x2*draw_scale,y2*draw_scale))end
local function image(kind,x,y,w)Icons.draw(kind,x*draw_scale,y*draw_scale,w*draw_scale,window)end
local function compact(v,n)
 v=tostring(v or "")
 if font_scale_pct>100 then n=math.max(8,math.floor(n*100/font_scale_pct)) end
 return #v<=n and v or v:sub(1,n-3).."..."
end
local function button(label,x1,y1,x2,y2,action,active,icon)
 local over=hovered(x1,y1,x2,y2)
 rect(x1,y1,x2,y2,active and c(104,222,216,250) or (over and c(18,79,88,242) or c(5,35,48,225)),6)
 if icon then image(icon,x1+5,y1+4,27);outline(x1+4,y1+3,x1+33,y1+32,c(151,244,239,190),4) end
 text(label,x1+(icon and 39 or 12),y1+10,fonts.FONT_SMALL or 0,active and c(2,18,25) or c(237,247,248))
 if over then outline(x1,y1,x2,y2,c(151,244,239,235),6,1) end
 if clicked(x1,y1,x2,y2) then action() end
end
local function wheel_delta()
 for _,fn in ipairs({core.input and core.input.get_mouse_wheel_delta,core.get_mouse_wheel_delta,core.graphics and core.graphics.get_mouse_wheel_delta}) do
  if type(fn)=="function" then local ok,v=pcall(fn);if ok and type(v)=="number" and v~=0 then return v end end
 end
 return 0
end
local function clamp_window(x,y,w,h)
 if core.graphics and type(core.graphics.get_screen_size)=="function" then
  local ok,screen=pcall(core.graphics.get_screen_size)
  if ok and screen and tonumber(screen.x) and tonumber(screen.y) then
   return math.max(0,math.min(x,math.max(0,screen.x-w))),
    math.max(0,math.min(y,math.max(0,screen.y-h)))
  end
 end
 return math.max(0,x),math.max(0,y)
end

function M.render()
 if not window then return end
 local C=require("rs_settings")
 if not position_loaded then win_x,win_y=C.window_position();position_loaded=true end
 local requested=math.max(70,math.min(132,C.get("gui_scale") or 115))
 if core.graphics and type(core.graphics.get_screen_size)=="function" then
  local fit_ok,screen=pcall(core.graphics.get_screen_size)
  if fit_ok and screen and tonumber(screen.x) and tonumber(screen.y) then
   local fit=math.max(70,math.min(132,math.floor(math.min((screen.x-10)/panel_w,(screen.y-10)/panel_h)*100)))
   if requested>fit then requested=fit;C.set_setting("gui_scale",fit);C.set_notice("GUI size fitted to current screen") end
  end
 end
 draw_scale=requested/100;font_scale_pct=math.max(85,math.min(125,C.get("font_scale") or 100))
 local pw,ph=panel_w*draw_scale,panel_h*draw_scale
 local clamped_x,clamped_y=clamp_window(win_x,win_y,pw,ph)
 if clamped_x~=win_x or clamped_y~=win_y then win_x,win_y=C.set_window_position(clamped_x,clamped_y) end
 window:set_visibility(C.is_window_open());if not C.is_window_open() then return end
 local ok,err=pcall(function()
  local cursor=type(core.get_cursor_position)=="function" and core.get_cursor_position() or nil
  local mouse=false
  if core.input and type(core.input.is_key_pressed)=="function" then local mok,v=pcall(core.input.is_key_pressed,0x01);mouse=mok and v==true end
  local mouse_pressed=mouse and not mouse_was_down
  if cursor and mouse_pressed and cursor.x>=win_x and cursor.x<=win_x+pw and cursor.y>=win_y and cursor.y<=win_y+78*draw_scale then
   dragging={dx=cursor.x-win_x,dy=cursor.y-win_y};if core.graphics and core.graphics.capture_next_mouse_input then pcall(core.graphics.capture_next_mouse_input) end
  end
  if dragging and mouse and cursor then
   win_x,win_y=clamp_window(cursor.x-dragging.dx,cursor.y-dragging.dy,pw,ph)
   if core.graphics and core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,true) end
  elseif dragging and not mouse then
   dragging=nil;win_x,win_y=C.set_window_position(win_x,win_y);C.set_notice("Panel position saved")
   if core.graphics and core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,false) end
  end
  if not mouse and slider_drag then
   slider_drag=nil
   if core.graphics and core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,false) end
  end
  mouse_was_down=mouse
  local we=enums.window_enums or enums;local flags=we.window_resizing_flags or {};local visuals=we.window_cross_visuals or {};fonts=we.font_id or {}
  if not art_attempted then
   art_attempted=true
   if core.graphics and type(core.graphics.load_texture)=="function" then
    local loaded,texture=pcall(function()return core.graphics.load_texture(require("rs_art"))end)
    if loaded and texture then
     art_texture=texture;require("rs_telemetry").debug("GUI_ART","embedded Thrall/totem texture loaded")
    else
     require("rs_telemetry").error("gui_art",loaded and "load_texture returned no texture" or texture)
    end
   else
    require("rs_telemetry").error("gui_art","core.graphics.load_texture unavailable")
   end
  end
  if window.set_next_window_min_size then window:set_next_window_min_size(vec2.new(pw,ph)) end
  if window.force_window_size then window:force_window_size(vec2.new(pw,ph)) end
  if window.force_next_begin_window_pos then window:force_next_begin_window_pos(vec2.new(win_x,win_y)) end
  window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,c(1,8,15),c(49,211,202),visuals.NO_CROSS or 9,function()
   if art_texture and core.graphics and type(core.graphics.draw_texture)=="function" then
    local position=type(window.get_position)=="function" and window:get_position() or vec2.new(win_x,win_y)
    local drawn=pcall(core.graphics.draw_texture,art_texture,vec2.new(position.x,position.y),pw,ph,c(255,255,255,255),true)
    if not drawn then art_texture=nil;require("rs_telemetry").error("gui_art_draw","draw_texture rejected embedded artwork") end
   end
   if not art_texture then
   rect(0,0,1000,760,c(1,8,15),0)
   -- Lua-only shaman artwork: an opaque waterfall field, elemental totems,
   -- and a readable orc-shaman silhouette keep the left side alive without
   -- external PNG/JPEG dependencies.
   rect(0,0,382,760,c(3,24,40,255),0);rect(0,520,382,760,c(4,49,65,255),0)
   rect(35,470,76,700,c(82,54,33,255),6);rect(41,445,70,475,c(202,166,88,255),7);text("E",48,457,fonts.FONT_BIG or 0,c(3,18,25))
   rect(89,430,130,700,c(31,74,88,255),6);rect(95,405,124,435,c(49,211,202,255),7);text("W",100,417,fonts.FONT_BIG or 0,c(3,18,25))
   rect(143,490,184,700,c(74,50,92,255),6);rect(149,465,178,495,c(187,143,255,255),7);text("S",154,477,fonts.FONT_BIG or 0,c(3,18,25))
   rect(197,445,238,700,c(79,47,30,255),6);rect(203,420,232,450,c(255,143,73,255),7);text("C",208,432,fonts.FONT_BIG or 0,c(3,18,25))
   rect(251,475,292,700,c(28,78,57,255),6);rect(257,450,286,480,c(105,239,156,255),7);text("G",262,462,fonts.FONT_BIG or 0,c(3,18,25))
   rect(305,425,346,700,c(43,57,89,255),6);rect(311,400,340,430,c(140,194,255,255),7);text("U",316,412,fonts.FONT_BIG or 0,c(3,18,25))
   rect(359,470,382,700,c(55,59,82,255),6)
   rect(124,180,258,350,c(28,45,50,255),25);rect(145,135,237,220,c(83,119,98,255),24);rect(157,112,225,165,c(105,153,125,255),22)
   rect(102,218,145,323,c(83,119,98,255),18);rect(237,218,280,323,c(83,119,98,255),18);rect(171,320,211,458,c(83,119,98,255),14)
   -- Readable Thrall-like orc silhouette built entirely from native shapes.
   rect(151,104,231,130,c(12,22,28,255),12);rect(142,126,239,150,c(17,28,32,255),16)
   rect(163,150,221,190,c(105,153,125,255),12);rect(176,157,184,165,c(8,24,28,255),3);rect(201,157,209,165,c(8,24,28,255),3)
   rect(151,188,234,214,c(20,35,42,255),8);rect(137,196,160,230,c(116,137,117,255),8);rect(225,196,248,230,c(116,137,117,255),8)
   rect(154,208,230,260,c(38,66,70,255),8);rect(166,214,218,273,c(26,43,48,255),6);rect(181,220,203,272,c(83,119,98,255),4)
   rect(118,230,142,340,c(83,119,98,255),10);rect(242,230,266,340,c(83,119,98,255),10)
   rect(111,322,151,338,c(18,30,35,255),5);rect(233,322,273,338,c(18,30,35,255),5)
   rect(275,210,282,490,c(61,45,34,255),3);rect(268,200,289,226,c(202,166,88,255),6);rect(274,183,283,205,c(49,211,202,255),4)
   rect(164,272,220,300,c(105,153,125,255),8);rect(172,294,212,320,c(16,29,35,255),6)
   text("WATER",28,58,fonts.FONT_SMALL or 0,c(151,244,239,210));text("EARTH",28,82,fonts.FONT_SMALL or 0,c(202,166,88,210));text("SPIRIT",28,106,fonts.FONT_SMALL or 0,c(187,143,255,210))
   text("RESTORATION",64,365,fonts.FONT_SEMI_BIG or 0,c(151,244,239,255));text("SHAMAN",90,397,fonts.FONT_BIG or 0,c(239,250,250,255))
   end
   rect(398,8,990,88,c(3,25,43,242),8);outline(398,8,990,88,c(49,211,202,235),8,2)
   text("SHAMAN TOOLS",430,18,fonts.FONT_BIG or 0,c(239,250,250))
   text("ELEMENTS IN BALANCE",431,49,fonts.FONT_SMALL or 0,c(151,244,239))
   text("F1 OPEN/CLOSE  |  CLICK CONTROLS  |  DRAG HEADER",431,70,fonts.FONT_SMALL or 0,c(205,225,229))
   rect(398,96,978,164,c(3,23,36,242),8)
   text("State: "..compact(C.status,24),415,105,fonts.FONT_SMALL or 0,c(244,250,250));text("Build: "..require("rs_talents").hero(),415,134,fonts.FONT_SMALL or 0,c(151,244,239))
   text("Content: "..compact(C.content or "Detecting",22),645,105,fonts.FONT_SMALL or 0,c(244,250,250));text("Last: "..compact(C.last,25),645,134,fonts.FONT_SMALL or 0,c(177,205,211))
   button(C.get("enabled") and "ON" or "PAUSED",875,109,968,151,function()C.set_setting("enabled",not C.get("enabled"))end,C.get("enabled"),"core")
   rect(18,172,982,260,c(2,26,39,180),8)
   local gap,tabw=5,154
   for i=1,C.group_count() do
    local label=C.group_title(i);local row=math.floor((i-1)/6);local col=(i-1)%6;local x1=22+col*(tabw+gap);local y1=178+row*40
    button(compact(label,17),x1,y1,x1+tabw,y1+35,function()page=i;scroll=0;C.set_notice(label.." tab opened")end,page==i,Icons.tab(i))
   end
   local shortcuts={{"wave","Healing",2},{"hex","PvP",6},{"purify","PvE",5},{"wind","Movement",8},{"fish","Gathering",10},{"lightning","Hotkeys",11},{"scroll","Logs",12}}
   for i,s in ipairs(shortcuts) do
    local ix=20+(i-1)*51;rect(ix,665,ix+44,709,c(3,28,42,235),5);outline(ix,665,ix+44,709,hovered(ix,665,ix+44,709) and c(151,244,239) or c(49,211,202,175),5)
    image(s[1],ix+5,670,34);if hovered(ix,665,ix+44,709) then text(s[2],20,720,fonts.FONT_SMALL or 0,c(244,250,250)) end
    if clicked(ix,665,ix+44,709) then page=s[3];scroll=0;C.set_notice(s[2].." settings opened") end
   end
   rect(398,270,978,690,c(2,20,32,242),9);image(Icons.tab(page),414,279,34);text(C.group_title(page),458,280,fonts.FONT_SEMI_BIG or 0,c(105,239,226));text(compact(C.group_help(page),34),458,303,fonts.FONT_VERY_SMALL or 0,c(177,205,211))
   local keys=C.group_keys(page);local hotkeys=C.is_hotkey_group(page);local visible_rows=hotkeys and 5 or 6
   local max_scroll=math.max(0,#keys-visible_rows);scroll=math.max(0,math.min(scroll,max_scroll))
   button("UP",780,278,865,313,function()scroll=math.max(0,scroll-1)end,false);button("DOWN",875,278,960,313,function()scroll=math.min(max_scroll,scroll+1)end,false)
   local wheel=hovered(398,315,978,685) and wheel_delta() or 0;if wheel~=0 then scroll=math.max(0,math.min(max_scroll,scroll+(wheel<0 and 1 or -1))) end
   if hotkeys then
    local enabled=C.get("hotkeys");rect(416,322,960,365,c(6,35,48,238),5);image("lightning",423,327,32)
    text("ENABLE CUSTOMER HOTKEYS",467,335,fonts.FONT_SMALL or 0,c(239,247,248));rect(710,330,810,356,c(62,36,45),6);text("CLEAR ALL",724,336,fonts.FONT_SMALL or 0,c(255,190,190));if clicked(700,322,820,365) then C.clear_hotkeys() end
    rect(870,330,944,356,enabled and c(105,239,156) or c(67,49,59),7)
    text(enabled and "ON" or "OFF",892,336,fonts.FONT_SMALL or 0,enabled and c(5,30,25) or c(239,247,248));if clicked(416,322,960,365) then C.set_setting("hotkeys",not enabled) end
    for i=1,5 do
     local key=keys[scroll+i]
     if key then
      local d=C.definition(key);local y=375+(i-1)*53;local binding=C.hotkey_binding()==key;local over=hovered(416,y,960,y+46)
      rect(416,y,960,y+46,over and c(14,66,74,245) or c(6,35,48,238),5);outline(416,y,960,y+46,binding and c(255,207,80) or c(38,100,111,175),5,binding and 2 or 1)
      image(Icons.for_setting(key),423,y+6,34);text(compact(d[2],35),467,y+14,fonts.FONT_SMALL or 0,c(239,247,248))
      local bind_label=binding and "PRESS KEY" or C.hotkey_name(C.hotkey_code(key));rect(820,y+8,944,y+38,binding and c(111,75,24) or c(4,47,61),6)
      text(compact(bind_label,15),832,y+16,fonts.FONT_SMALL or 0,binding and c(255,228,156) or c(151,244,239))
      if clicked(805,y,960,y+46) then C.begin_hotkey_capture(key) end
     end
    end
    text("Click a binding, then press a key. Escape clears it. F1 and F7 stay reserved.",425,650,fonts.FONT_SMALL or 0,c(177,205,211))
   else
   for i=1,6 do
    local key=keys[scroll+i]
    if key then
     local d=C.definition(key);local value=C.get(key);local y=322+(i-1)*53;local over=hovered(416,y,960,y+46)
     rect(416,y,960,y+46,over and c(14,66,74,245) or c(6,35,48,238),5)
     outline(416,y,960,y+46,over and c(151,244,239,235) or c(38,100,111,175),5,over and 2 or 1)
     image(Icons.for_setting(key),423,y+6,34)
     if type(d[3])=="boolean" then
      text(compact(d[2],38),467,y+14,fonts.FONT_SMALL or 0,c(239,247,248));rect(870,y+10,944,y+36,value and c(105,239,156) or c(67,49,59),7)
      outline(870,y+10,944,y+36,value and c(151,255,203) or c(121,87,101),7,1)
      text(value and "ON" or "OFF",892,y+16,fonts.FONT_SMALL or 0,value and c(5,30,25) or c(239,247,248));if clicked(416,y,960,y+46) then C.set_setting(key,not value) end
     else
      text(compact(d[2],29),467,y+7,fonts.FONT_SMALL or 0,c(239,247,248));local bx1,bx2=670,880;rect(bx1,y+29,bx2,y+36,c(166,194,201),2)
      local ratio=(value-d[4])/math.max(1,d[5]-d[4]);rect(bx1,y+29,bx1+(bx2-bx1)*ratio,y+36,c(49,211,202),2);text(C.value_label(key,value),894,y+18,fonts.FONT_SMALL or 0,c(151,244,239))
      for step=0,39 do local sx1=bx1+(bx2-bx1)*step/40;local sx2=bx1+(bx2-bx1)*(step+1)/40;if clicked(sx1,y+15,sx2,y+44) then C.set_setting(key,d[4]+(d[5]-d[4])*(step+1)/40) end end
      local local_x=cursor and (cursor.x-win_x)/draw_scale or -1
      local local_y=cursor and (cursor.y-win_y)/draw_scale or -1
      if mouse_pressed and local_x>=bx1 and local_x<=bx2 and local_y>=y+15 and local_y<=y+44 then
       slider_drag=key;if core.graphics and core.graphics.capture_next_mouse_input then pcall(core.graphics.capture_next_mouse_input) end
      end
      if mouse and slider_drag==key and cursor then
       local drag_ratio=math.max(0,math.min(1,(local_x-bx1)/(bx2-bx1)))
       C.set_setting(key,d[4]+(d[5]-d[4])*drag_ratio)
       if core.graphics and core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,true) end
      end
     end
    end
   end
   end
   if C.group_title(page)=="DISPLAY & LOGS" then
    local T=require("rs_telemetry")
    button("COPY PATH",416,500,585,534,function()if window.copy_to_clipboard then window:copy_to_clipboard(T.path());C.set_notice("Log path copied") end end,false)
    button("COPY THIS RUN",595,500,775,534,function()if window.copy_to_clipboard then window:copy_to_clipboard(T.current_run());C.set_notice("Current encounter copied") end end,false)
    button("COPY SAVED LOG",785,500,960,534,function()if window.copy_to_clipboard then window:copy_to_clipboard(T.saved_history());C.set_notice("Saved log copied") end end,false)
    button("CLEAR LOG",416,545,585,579,function()C.set_notice(T.clear() and "Saved logs cleared; recording continues" or "Log clear failed")end,false)
    button("COPY DEBUG",595,545,775,579,function()if window.copy_to_clipboard then window:copy_to_clipboard(T.debug_text());C.set_notice("GUI and runtime debug copied") end end,false)
    button("CLEAR DEBUG",785,545,960,579,function()T.clear_debug();C.set_notice("Debugger cleared")end,false)
    button("RESET DISPLAY",416,590,960,624,function()win_x,win_y=C.reset_display() end,false)
   end
   rect(398,702,978,746,c(3,25,38,232),6);rect(20,703,120,746,c(105,239,226),6);text("F1  HIDE",35,717,fonts.FONT_SMALL or 0,c(3,24,28))
   text("STATUS: "..compact(C.notice(),46),415,717,fonts.FONT_SMALL or 0,c(244,250,250));rect(884,708,968,740,c(105,239,226),6);text("v4.5.1",900,717,fonts.FONT_SMALL or 0,c(3,24,28));outline(1,1,998,758,c(49,211,202),10,2)
   if not render_reported then render_reported=true;require("rs_telemetry").debug("GUI_READY","native window rendered at "..math.floor(win_x)..","..math.floor(win_y).." scale="..string.format("%.2f",draw_scale)) end
  end)
 end)
 if not ok and not reported then reported=true;pcall(core.log_warning,"[Resto M+ GUI] "..tostring(err));pcall(function()require("rs_telemetry").error("gui_render",err)end) end
end
function M.hide()
 dragging=nil;slider_drag=nil;mouse_was_down=false
 if core.graphics and type(core.graphics.set_mouse_capture_state)=="function" then
  pcall(core.graphics.set_mouse_capture_state,false)
 end
 if window then window:set_visibility(false) end
end
return M
