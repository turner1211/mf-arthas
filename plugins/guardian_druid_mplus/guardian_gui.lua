-- Malfurion-themed Guardian panel using the same stable window formula as the Rogue GUI.
local Settings=require("guardian_settings")
local Log=require("guardian_log")
local color=require("common/color")
local vec2=require("common/geometry/vector_2")
local enums=require("common/enums")
local M={page=1,offset=0}
local window,texture,attempted,icon_texture,icons_attempted
local texture_errors={}
local win_x,win_y,panel_w,panel_h=20,20,1020,760
local dragging,mouse_was_down=nil,false
local last_scroll=-math.huge
local VERSION=require("guardian_version")
local tab_icons={1,5,4,8,2,6,7,3,1,3}
local pages={"TANKING","DUNGEONS","UTILITY","JOURNAL","DEFENSE","PARTY","DISPLAY","BUILD","PLAYER","HOTKEYS"}
local groups={
 {"combat","low_lag","auto_bear","cooldowns","spenders","interrupts","aoe_stop","soothe","auto_face","threat_switch","auto_taunt","rage_dump","threat_range","cooldown_min_enemies","cooldown_ttd","interrupt_percent"},
 {"route_map","route_lock","route_overview","draw_route_lines","draw_next_pack","draw_pull_labels","boss_guide","boss_helper_gui","danger_zones","boss_lines","boss_warning_lead","danger_margin"},
 {"auto_mark","looting","skinning","fishing","auto_repair","guild_repair"}, {"diagnostics"},
 {"defensives","prediction","pre_regen","bigwigs_defensives","regen_hp","barkskin_hp","survival_hp","ironfur_stacks","bigwigs_lead","prediction_window","prediction_regen","prediction_survival"},
 {"dream_heal","dream_ally","remove_corruption","combat_rebirth","dream_ally_hp","rebirth_min_hp"},
 {"route_overview","draw_route_lines","draw_next_pack","draw_pull_labels","diagnostics","boss_guide","boss_helper_gui","danger_zones","boss_lines","boss_overlay_x","boss_overlay_y","gui_scale"},
 {"hero","dummy_test","cooldowns","spenders","rage_dump"},
 {"enabled","combat","manual_yield","dummy_test","auto_bear","auto_mark","looting","skinning","fishing","auto_repair"},
 {}}
local row_icons={auto_bear=1,auto_taunt=1,threat_switch=1,defensives=2,prediction=2,pre_regen=4,regen_hp=4,dream_heal=4,dream_ally=4,remove_corruption=4,combat_rebirth=4,auto_mark=4,interrupts=3,aoe_stop=3,soothe=6,auto_face=3,route_map=5,route_lock=5,route_overview=5,draw_route_lines=5,draw_next_pack=5,draw_pull_labels=5,diagnostics=8,hero=2,dummy_test=3}
local function c(r,g,b,a) return color.new(r,g,b,a or 255) end
local function scale() return math.max(0.75,math.min(1,(Settings.value("gui_scale") or 95)/100)) end
local function p(v) return math.floor(v*scale()+0.5) end
local function small_font() return ((enums.window_enums or enums).font_id or {}).FONT_SMALL or 7 end
local function big_font() return ((enums.window_enums or enums).font_id or {}).FONT_BIG or 8 end
local function rect(x,y,w,h,col,r) window:render_rect_filled(vec2.new(p(x),p(y)),vec2.new(p(x+w),p(y+h)),col,p(r or 6)) end
local function outline(x,y,w,h,col,r,t) if window.render_rect then window:render_rect(vec2.new(p(x),p(y)),vec2.new(p(x+w),p(y+h)),col,p(r or 6),math.max(1,p(t or 1))) end end
local function text(v,x,y,big,col) window:render_text(big and big_font() or small_font(),vec2.new(p(x),p(y)),col or c(221,238,220),tostring(v)) end
local function hovered(x,y,w,h) return window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(vec2.new(p(x),p(y)),vec2.new(p(x+w),p(y+h))) or false end
local function clicked(x,y,w,h) return window:is_rect_clicked(vec2.new(p(x),p(y)),vec2.new(p(x+w),p(y+h))) end
local function compact(s,n) s=tostring(s or ""); return require('mf_i18n').clip(require('mf_i18n').text(s),n) end
local function icon(id,x,y,size)
 rect(x-2,y-2,size+4,size+4,c(171,169,98,235),4); rect(x,y,size,size,c(9,28,22),3)
 if icon_texture and core.graphics.draw_texture_rect then
  local pos=window:get_position(); local col=(id-1)%2; local row=math.floor((id-1)/2)
  local ok,err=pcall(core.graphics.draw_texture_rect,icon_texture,vec2.new(pos.x+p(x),pos.y+p(y)),p(size),p(size),col*0.5+0.125,row*0.25,col*0.5+0.375,(row+1)*0.25,c(255,255,255),true)
  if not ok and not texture_errors.icons then texture_errors.icons=true; Log.runtime_error("GUI_ICONS",err) end
 end
end
local function button(label,x,y,w,h,fn,active,icon_id)
 local over=hovered(x,y,w,h)
 rect(x-1,y-1,w+2,h+2,active and c(218,198,122) or c(103,133,92),5)
 rect(x,y,w,h,active and c(54,117,75,245) or over and c(31,77,49,245) or c(13,35,30,235),5)
 if icon_id then icon(icon_id,x+5,y+4,h-8) end
 text(label,x+(icon_id and h+4 or 10),y+10,false,active and c(255,232,157) or nil)
 if clicked(x,y,w,h) then fn() end
end
local function load_textures()
 if not attempted then attempted=true; if core.graphics.load_texture then local ok,v=pcall(function() return core.graphics.load_texture(require("guardian_art")) end); if ok then texture=v end end end
 if not icons_attempted then icons_attempted=true; if core.graphics.load_texture then local ok,v=pcall(function() return core.graphics.load_texture(require("guardian_icons")) end); if ok then icon_texture=v end end end
end
local function update_drag()
 local down,cursor=false,nil
 if type(core.get_cursor_position)=="function" then cursor=core.get_cursor_position() end
 if core.input and type(core.input.is_key_pressed)=="function" then local ok,v=pcall(core.input.is_key_pressed,0x01); down=ok and v==true end
 if cursor and down and not mouse_was_down and cursor.x>=win_x and cursor.x<=win_x+p(panel_w) and cursor.y>=win_y and cursor.y<=win_y+p(96) then
  dragging={dx=cursor.x-win_x,dy=cursor.y-win_y}; if core.graphics.capture_next_mouse_input then pcall(core.graphics.capture_next_mouse_input) end
 end
 if dragging and down and cursor then
  win_x,win_y=math.max(0,cursor.x-dragging.dx),math.max(0,cursor.y-dragging.dy)
  if core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,true) end
 elseif dragging and not down then dragging=nil; if core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,false) end end
 mouse_was_down=down
end
local function mouse_wheel_delta()
 local candidates={core.input and core.input.get_mouse_wheel_delta,core.get_mouse_wheel_delta,core.graphics and core.graphics.get_mouse_wheel_delta}
 for _,fn in pairs(candidates) do if type(fn)=="function" then local ok,v=pcall(fn); if ok and type(v)=="number" and v~=0 then return v end end end
 return 0
end
function M.render()
 if not Settings.is_guardian() then
  if window then window:set_visibility(false) end
  if dragging and core.graphics.set_mouse_capture_state then pcall(core.graphics.set_mouse_capture_state,false) end
  dragging=nil; mouse_was_down=false
  return
 end
 Settings.poll_hotkeys()
 if not core.menu.window then return end
 if not window then
  window=core.menu.window("guardian_druid_emerald_dream"); window:set_initial_position(vec2.new(win_x,win_y)); window:set_initial_size(vec2.new(p(panel_w),p(panel_h)))
  if window.set_render_layer then window:set_render_layer(1) end
 end
 window:set_visibility(Settings.on("themed_gui")); if not Settings.on("themed_gui") then return end
 update_drag()
 if window.set_next_window_min_size then window:set_next_window_min_size(vec2.new(p(panel_w),p(panel_h))) end
 if window.force_window_size then window:force_window_size(vec2.new(p(panel_w),p(panel_h))) end
 if window.force_next_begin_window_pos then window:force_next_begin_window_pos(vec2.new(win_x,win_y)) end
 local we=enums.window_enums or enums
 window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,c(8,22,19),c(153,174,108),(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  load_textures()
  if texture and core.graphics.draw_texture then
   local pos=window:get_position(); local ok,err=pcall(core.graphics.draw_texture,texture,vec2.new(pos.x,pos.y),p(panel_w),p(panel_h),c(255,255,255),true)
   if not ok then rect(0,0,panel_w,panel_h,c(8,22,19),0); if not texture_errors.backdrop then texture_errors.backdrop=true; Log.runtime_error("GUI_BACKDROP",err) end end
  else rect(0,0,panel_w,panel_h,c(8,22,19),0) end

  rect(500,10,490,82,c(6,20,17,232),8); outline(500,10,490,82,c(171,169,98,220),8,1)
  text("GUARDIAN OF THE DREAM",520,20,true,c(229,213,154)); text("MALFURION'S VIGIL  |  MYTHIC+ / PVE / DELVES",520,51,false)
  text("F1 SHOW/HIDE  |  DRAG HEADER  |  MOUSE WHEEL",520,73,false,c(149,183,161)); button("CLOSE",904,22,82,32,function() Settings.set("themed_gui",false) end)

  rect(398,101,592,62,c(6,20,17,232),8); text("Mode: "..compact(Settings.mode_status,42),414,111,false)
  text("Combat: "..compact(Settings.status,39),414,138,false,c(149,183,161))
  button(Settings.on("enabled") and "ACTIVE" or "PAUSED",826,112,150,39,function() Settings.set("enabled",not Settings.on("enabled")) end,Settings.on("enabled"),1)

  rect(18,172,972,128,c(22,56,40,150),8); local gap,tabw=9,233
  for i,label in ipairs(pages) do local row=math.floor((i-1)/4); local col=(i-1)%4; button(label,22+col*(tabw+gap),178+row*40,tabw,35,function() M.page=i; M.offset=0 end,M.page==i,tab_icons[i]) end

  rect(398,304,592,386,c(6,20,17,232),9); text(pages[M.page],416,306,true,c(229,213,154))
  local list=M.page==10 and Settings.hotkey_order or groups[M.page]; local max_offset=math.max(0,#list-5); M.offset=math.min(M.offset,max_offset)
  local wheel=hovered(398,270,592,420) and mouse_wheel_delta() or 0
  if wheel~=0 and core.time()-last_scroll>0.08 then M.offset=math.max(0,math.min(max_offset,M.offset+(wheel<0 and 1 or -1))); last_scroll=core.time() end
  if #list>5 then button("UP",790,279,82,35,function() M.offset=math.max(0,M.offset-1) end); button("DOWN",882,279,94,35,function() M.offset=math.min(max_offset,M.offset+1) end) end
  for visible=1,5 do
   local key=list[M.offset+visible]
   if key then
    local row=M.page==10 and {kind="hotkey",label=Settings.hotkeys[key].label,note=Settings.hotkeys[key].kind=="action" and "Runs this action once when pressed." or "Toggles this option when pressed."} or Settings.describe(key); local y=325+(visible-1)*59
    rect(416,y,560,51,c(11,34,27,235),5); icon(row_icons[key] or (M.page==4 and 8 or M.page==5 and 2 or M.page==6 and 4 or M.page==8 and 3 or 7),423,y+8,35)
    text(compact(row.label,43),470,y+6,false); text(compact(row.note,48),470,y+28,false,c(149,183,161))
    if row.kind=="hotkey" then
     button(Settings.hotkey_enabled(key) and Settings.hotkey_name(key) or "HK OFF",835,y+9,72,34,function() Settings.set_hotkey_enabled(key,not Settings.hotkey_enabled(key)) end,Settings.hotkey_enabled(key))
     button("<",913,y+9,24,34,function() Settings.cycle_hotkey(key,-1) end); button(">",942,y+9,24,34,function() Settings.cycle_hotkey(key,1) end)
    elseif row.kind=="check" then button(Settings.on(key) and "ON" or "OFF",900,y+9,66,34,function() Settings.set(key,not Settings.on(key)) end,Settings.on(key))
    else
     text(key=="hero" and ({"Auto","Elune","Claw"})[Settings.value(key)] or Settings.value(key),846,y+17,false,c(229,213,154))
     button("-",804,y+9,34,34,function() Settings.set(key,Settings.value(key)-1) end); button("+",932,y+9,34,34,function() Settings.set(key,Settings.value(key)+1) end)
    end
   end
  end
  if #list>5 then text(string.format("%d-%d / %d",M.offset+1,math.min(#list,M.offset+5),#list),416,634,false,c(149,183,161)) end
  if M.page==2 then
   text(compact(Settings.route_status,67),416,617,false,c(229,213,154))
   for i,key in ipairs({"previous","next","reset"}) do button(({"PREVIOUS PULL","SKIP PULL","RESTART ROUTE"})[i],416+(i-1)*187,646,176,35,function() if Settings.actions[key] then Settings.actions[key]() end end) end
  elseif M.page==4 then
   button("COPY SAVED LOG PATH",416,484,260,39,function() if window.copy_to_clipboard then window:copy_to_clipboard(Log.copy_path) end end,false,8)
   button("COPY SESSION LOG",690,484,276,39,function() if window.copy_to_clipboard then window:copy_to_clipboard(Log.text()) end end,false,8)
   text("BigWigs: "..compact(Settings.bigwigs_status,36),416,617,false); text("Logs: "..compact(Settings.log_status,39),416,643,false,c(149,183,161))
  elseif M.page==7 then
   button("RESET WINDOW POSITION",416,646,250,35,function() win_x,win_y=20,20 end,false,7)
  end

  rect(20,304,350,248,c(6,20,17,185),9); text("MALFURION'S VIGIL",42,316,true,c(229,213,154))
  text("Protect the party.",42,333,false); text("Control the pull.",42,360,false); text("Endure what others cannot.",42,387,false)
  text("The wilds endure through you.",42,428,false,c(149,183,161))
  button(Settings.on("enabled") and "GUARDIAN ACTIVE" or "GUARDIAN PAUSED",42,474,306,48,function() Settings.set("enabled",not Settings.on("enabled")) end,Settings.on("enabled"),1)

  rect(398,702,592,44,c(6,20,17,225),6); text("STATUS: "..compact(Settings.status,36),416,717,false)
  rect(884,708,84,32,c(54,117,75,248),6); outline(884,708,84,32,c(218,198,122),6,2); text("v"..VERSION,898,717,false,c(255,232,157))
  outline(1,1,1017,757,c(153,174,108),10,2)
 end)
end
function M.safe_render() local ok,err=pcall(M.render); if not ok then Log.runtime_error("GUI",err) end end
return M
