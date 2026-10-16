-- Rogue panel's custom-window layout adapted to an expedition/map theme.
local Color=require("common/color")
local Vec=require("common/geometry/vector_2")
local Enums=require("common/enums")
local Build=require("header")
local M={open=true,page=1,notice="",profile_index=1,log_offset=0,profile_open=false,profile_offset=0}
local main,hud
local positions={};local dragging,was_down=nil,false
local function read(fn,fallback,...)
 if type(fn)~="function" then return fallback end
 local ok,value=pcall(fn,...);return ok and value or fallback
end
local function call(fn,...)
 if type(fn)~="function" then return false end
 return pcall(fn,...)
end
local function c(r,g,b,a) return Color.new(r,g,b,a or 255) end
local ink=c(231,237,222);local muted=c(162,183,175);local gold=c(224,184,91);local teal=c(39,96,88)
local good=c(92,205,139);local travel=c(92,177,214);local warn=c(236,174,74);local bad=c(228,92,92)
local we=Enums.window_enums or Enums
local font=(we.font_id or {}).FONT_SMALL or 0
local function compact(s,n) s=tostring(s or "-"):gsub("[%c]"," ");return #s>n and s:sub(1,n-3).."..." or s end
local function text(w,s,x,y,col) w:render_text(font,Vec.new(x,y),col or ink,s) end
local function rect(w,x,y,x2,y2,col) w:render_rect_filled(Vec.new(x,y),Vec.new(x2,y2),col,5) end
local function status_meta(state)
 local value=tostring(state.status or "idle"):lower()
 if value:find("error",1,true) or value:find("failed",1,true) or value:find("blocked",1,true) or value:find("unavailable",1,true) then return "ATTENTION",bad end
 if value:find("combat",1,true) or value:find("target",1,true) then return "COMBAT",warn end
 if value:find("navigat",1,true) or value:find("travel",1,true) or value:find("mount",1,true) or value:find("walk",1,true) or value:find("fly",1,true) then return "TRAVEL",travel end
 if value=="idle" or value=="stopped" or value=="disabled" then return "IDLE",muted end
 return "RUNNING",good
end
local function progress(w,x,y,width,index,total)
 total=tonumber(total) or 0;index=tonumber(index) or 0
 local ratio=total>0 and math.max(0,math.min(1,(index-1)/total)) or 0
 rect(w,x,y,x+width,y+9,c(25,43,39))
 if ratio>0 then rect(w,x,y,x+math.max(5,math.floor(width*ratio)),y+9,good) end
end
local function attention(state)
 local debug=state.debug or {};local status=tostring(state.status or "");local lower=status:lower()
 if state.log_error and state.log_error~="Recording" then return "LOGGER: "..compact(state.log_error,62),bad end
 if debug.arthas_nav_loaded==false then return "NEEDS ATTENTION: ArthasNav is not loaded",bad end
 if debug.navigation_available==false and (lower:find("navigat",1,true) or lower:find("travel",1,true) or lower:find("walk",1,true)) then return "NEEDS ATTENTION: navigation server is offline",bad end
 if lower:find("error",1,true) or lower:find("failed",1,true) or lower:find("blocked",1,true) then return "NEEDS ATTENTION: "..compact(status,57),bad end
 if debug.navigation_planning then return "ROUTE: ArthasNav is planning the next safe leg",travel end
 return "AUTOMATION HEALTH: ready",good
end
local function button(w,label,x,y,width,fn,selected)
 local hover=w:is_mouse_hovering_rect(Vec.new(x,y),Vec.new(x+width,y+32))
 rect(w,x,y,x+width,y+32,selected and teal or (hover and c(52,79,69) or c(31,49,44)))
 text(w,label,x+10,y+10,selected and gold or ink)
 if w:is_rect_clicked(Vec.new(x,y),Vec.new(x+width,y+32)) then fn() end
end
local function begin(w,width,height,fn)
 w:set_visibility(true);w:force_window_size(Vec.new(width,height))
 local position=positions[w]
 if position and type(w.force_next_begin_window_pos)=="function" then w:force_next_begin_window_pos(Vec.new(position.x,position.y)) end
 w:begin(0,false,c(15,28,25),gold,
  (we.window_cross_visuals or {}).NO_CROSS or 9,fn)
end
local function init()
 if main then return end
 main=core.menu.window("sylvanas_leveling_main_04")
 main:set_initial_position(Vec.new(60,60));main:set_initial_size(Vec.new(720,550))
 hud=core.menu.window("sylvanas_leveling_hud_04")
 hud:set_initial_position(Vec.new(805,100));hud:set_initial_size(Vec.new(390,305))
 positions[main]={x=60,y=60,width=720,height=550};positions[hud]={x=805,y=100,width=390,height=305}
end
local labels={auto_talents="Spend available talent points",auto_skyriding="Skyriding on checked flight corridors",built_in_combat="Basic leveling combat (disable other rotations)",auto_mount="Automatic ground mounting",auto_equip="Equip observed gear upgrades",auto_repair="Repair at vendors",auto_sell="Sell grey junk when bags fill",show_path="Path lines and waypoint circles",show_hud="Small progress window"}
function M.render(state,action)
 init()
 local cursor=read(core.get_cursor_position,nil)
 local down=read(core.input and core.input.is_key_pressed,false,0x01)==true
 if cursor and down and not was_down then
  for _,w in ipairs({hud,main}) do
   local p=positions[w];local visible=w==main and M.open or w==hud and state.settings.show_hud
   if visible and cursor.x>=p.x and cursor.x<=p.x+p.width and cursor.y>=p.y and cursor.y<=p.y+40 then
    dragging={window=w,dx=cursor.x-p.x,dy=cursor.y-p.y};break
   end
  end
 end
 if dragging and cursor and down then
  local p=positions[dragging.window];p.x=math.max(0,cursor.x-dragging.dx);p.y=math.max(0,cursor.y-dragging.dy)
  call(core.graphics and core.graphics.capture_next_mouse_input)
 elseif not down then dragging=nil end
 was_down=down
 local screen=read(core.graphics and core.graphics.get_screen_size,nil)
 if screen then for _,p in pairs(positions) do p.x=math.min(p.x,math.max(0,screen.x-p.width));p.y=math.min(p.y,math.max(0,screen.y-p.height)) end end
 main:set_visibility(M.open)
 if M.open then begin(main,720,550,function()
  rect(main,8,8,712,91,c(26,56,47))
  text(main,"LEVELING EXPEDITION",24,23,gold)
  text(main,"Quest journal / travel / supplies",24,49,muted)
  text(main,state.game_version=="Forever" and "Forever 1 - 60" or "Retail 1 - 90",565,23,gold)
  button(main,"HIDE WINDOW",585,51,110,function() M.open=false end)
  for i,label in ipairs({"JOURNAL","OPTIONS","LOGS","DEBUG"}) do
   button(main,label,24+(i-1)*168,105,158,function() M.page=i end,M.page==i)
  end
  if M.page==1 then
   local badge,badge_color=status_meta(state)
   text(main,"Now: "..compact(state.status,58),24,158,gold)
   rect(main,570,151,688,177,c(24,43,39));text(main,badge,582,160,badge_color)
   text(main,"Character level: "..tostring(state.level or "-").."   Area: "..compact(state.area,55),24,183)
   progress(main,24,205,664,state.index,state.total)
   text(main,"Step "..tostring(state.index or 0).." / "..tostring(state.total or 0).."   "..compact(state.step_title,65),24,220)
   text(main,"Action: "..compact(state.action,30).."   Quest: "..tostring(state.quest_id or "-"),24,241,muted)
   local health,health_color=attention(state);text(main,health,24,260,health_color)
   local list=state.profiles or {};M.profile_index=math.max(1,math.min(M.profile_index,#list))
   local selected=list[M.profile_index]
   text(main,"LEVELING PROFILE   "..tostring(#list).." AVAILABLE",24,278,gold)
   button(main,(selected and (tostring(M.profile_index).." / "..tostring(#list).."   "..compact(selected.label or selected.id,62)) or "No leveling profiles installed").."   v",24,300,665,function()
    M.profile_open=not M.profile_open;M.profile_offset=math.max(0,M.profile_index-1)
   end)
   if M.profile_open then
    local wheel=read(core.get_mouse_wheel_delta,0)
    if wheel~=0 and main:is_mouse_hovering_rect(Vec.new(24,300),Vec.new(689,505)) then
     M.profile_offset=M.profile_offset+(wheel<0 and 5 or -5)
     call(core.graphics and core.graphics.capture_next_mouse_input)
    end
    M.profile_offset=math.max(0,math.min(M.profile_offset,math.max(0,#list-5)))
    for row=1,5 do
     local index=M.profile_offset+row;local item=list[index]
     if item then button(main,compact(item.label or item.id,84),24,337+(row-1)*33,665,function()
      M.profile_index=index;M.profile_open=false
     end,index==M.profile_index) end
    end
    text(main,"Scroll to browse profiles; click one to select.",24,507,muted)
   else
   button(main,"START SELECTED",24,337,200,function()
    if selected then action("start",selected.id) else M.notice="A leveling profile is needed before starting." end
   end)
   button(main,"AUTO START",24,394,200,function() action("auto_start") end)
   button(main,"PREVIOUS STEP",235,337,145,function() action("previous_step") end)
   button(main,"NEXT STEP",391,337,145,function() action("next_step") end)
   button(main,"RESUME",547,337,140,function() action("resume") end)
   button(main,"STOP",235,394,120,function() action("stop") end)
   button(main,"COPY LOGS",366,394,190,function() main:copy_to_clipboard(state.log_text());M.notice="Logs copied. Paste them into our chat." end)
   button(main,"TEACH PATH",24,441,200,function() action("teach_path") end)
   text(main,"Auto-save and resume after 5 seconds still.",235,455,muted)
   end
  elseif M.page==2 then
   local y=159
   for _,key in ipairs({"auto_mount","auto_equip","auto_repair","auto_sell","show_path","show_hud","built_in_combat","auto_talents","auto_skyriding"}) do
    local setting_key=key
    button(main,(state.settings[key] and "ON   " or "OFF  ")..labels[key],24,y,665,
     function() action("setting",setting_key,not state.settings[setting_key]) end,state.settings[key]);y=y+35
   end
   text(main,"Travel and supplies changes apply on the next Start.",24,489,muted)
  elseif M.page==3 then
   button(main,"COPY ALL LOGS",24,155,220,function() main:copy_to_clipboard(state.log_text());M.notice="Logs copied. Paste them into our chat." end)
   button(main,"SAVE LOG FILE",255,155,200,function() action("save_log") end)
   text(main,"Current: scripts_data/sylvanas_auto_leveler/logs/latest.txt",24,202,muted)
   text(main,"Permanent: scripts_log/sylvanas_auto_leveler/session.log",24,218,muted)
   text(main,"Logger: "..compact(state.log_error or "Recording",70),24,240,gold)
   local rows=state.log_rows or {};local count=#rows
   M.log_offset=math.max(0,math.min(M.log_offset,math.max(0,count-7)))
   local first=math.max(1,count-6-M.log_offset)
   for i=first,math.min(count,first+6) do text(main,compact(rows[i],92),24,270+(i-first)*24) end
   button(main,"OLDER",24,439,110,function() M.log_offset=M.log_offset+7 end)
   button(main,"NEWER",145,439,110,function() M.log_offset=math.max(0,M.log_offset-7) end)
   button(main,"LATEST",266,439,110,function() M.log_offset=0 end)
  else
   text(main,"LIVE DEBUGGER",24,158,gold)
   text(main,"State: "..compact(state.debug.state,24).."   Move: "..compact(state.debug.move,18),24,187)
   text(main,"Profile: "..compact(state.debug.profile,75),24,212,muted)
   text(main,"Step "..tostring(state.debug.step or 0).." / "..tostring(state.debug.total or 0).."   Action: "..compact(state.debug.action,28),24,237)
   text(main,"Quest: "..tostring(state.debug.quest_id or "-").."   Source: "..tostring(state.debug.source_index or "-"),24,262)
   text(main,"Map "..tostring(state.debug.map or "-").." / Instance "..tostring(state.debug.instance or "-").."   XYZ "..
    compact(tostring(state.debug.x or "-")..", "..tostring(state.debug.y or "-")..", "..tostring(state.debug.z or "-"),42),24,287)
   text(main,"Combat "..tostring(state.debug.combat).."   Mounted "..tostring(state.debug.mounted).."   Flying "..tostring(state.debug.flying),24,312)
   text(main,"Target: "..compact(state.debug.target,45).." ("..tostring(state.debug.target_id or "-")..")",24,337)
   text(main,"ArthasNav "..tostring(state.debug.arthas_nav_loaded).."   Server "..tostring(state.debug.navigation_available)..
    "   Planning "..tostring(state.debug.navigation_planning),24,362,gold)
   text(main,"Retries "..tostring(state.debug.retries or 0).."   Self repairs "..tostring(state.debug.self_repairs or 0)..
    "   Nav job "..tostring(state.debug.navigation_job),24,387,muted)
   button(main,"COPY DEBUG SNAPSHOT",24,424,250,function() main:copy_to_clipboard(state.debug_text());M.notice="Debug snapshot copied." end)
   button(main,"SAVE DEBUG SNAPSHOT",286,424,250,function() action("save_debug") end)
   button(main,"COPY FULL LOG",548,424,140,function() main:copy_to_clipboard(state.log_text());M.notice="Full log copied." end)
   text(main,"Snapshot includes the latest 40 diagnostic events.",24,468,muted)
  end
  text(main,compact(M.notice,66),24,506,gold)
  text(main,"v"..Build.version,626,523,muted)
 end) end
 hud:set_visibility(state.settings.show_hud)
 if state.settings.show_hud then begin(hud,390,305,function()
  rect(hud,8,8,382,49,c(26,56,47));text(hud,"LEVELING / LIVE JOURNAL",18,22,gold)
  button(hud,"HIDE",302,12,70,function() action("setting","show_hud",false) end)
  local badge,badge_color=status_meta(state)
  text(hud,compact(state.status,35),18,65,gold);text(hud,badge,310,65,badge_color)
  text(hud,"Level "..tostring(state.level or "-").."   Step "..tostring(state.index or 0).." / "..tostring(state.total or 0),18,91)
  text(hud,compact(state.step_title,49),18,117)
  text(hud,"Quest "..tostring(state.quest_id or "-").." / "..compact(state.action,27),18,143,muted)
  progress(hud,18,169,352,state.index,state.total)
  text(hud,compact(state.area,49),18,184,muted)
  local health,health_color=attention(state);text(hud,compact(health,49),18,203,health_color)
  button(hud,"OPTIONS",18,231,110,function() M.open=true end)
  button(hud,"COPY LOGS",139,231,135,function() hud:copy_to_clipboard(state.log_text());M.notice="Logs copied. Paste them into our chat." end)
  button(hud,"STOP",285,231,85,function() action("stop") end)
  button(hud,"PREVIOUS",18,270,110,function() action("previous_step") end)
  button(hud,"NEXT",139,270,110,function() action("next_step") end)
  button(hud,"RESUME",260,270,110,function() action("resume") end)
 end) end
end
return M

