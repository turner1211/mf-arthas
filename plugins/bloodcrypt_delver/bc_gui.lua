local Color=require("common/color")
local Vec=require("common/geometry/vector_2")
local Enums=require("common/enums")
local Plans=require("bc_story_plans")
local M={page=1,offset=0,art_status="Waiting"}
local window,texture;local attempts=0;local frames=0;local origin={x=100,y=90};local last_visibility
local W,H=1000,760
local function c(r,g,b,a) return Color.new(r,g,b,a or 255) end
local bone=c(238,218,188);local crimson=c(181,38,51);local muted=c(180,157,155)
local we=Enums.window_enums or Enums;local fonts=we.font_id or {};local small=fonts.FONT_SMALL or 0;local large=fonts.FONT_BIG or small
local function rect(x,y,w,h,col,r) window:render_rect_filled(Vec.new(x,y),Vec.new(x+w,y+h),col,r or 6) end
local function outline(x,y,w,h,col,r)
 if window.render_rect then window:render_rect(Vec.new(x,y),Vec.new(x+w,y+h),col,r or 6,1) end
end
local function compact(s,n) s=tostring(s or ""):gsub("[%c]"," ");return #s>n and s:sub(1,n-3).."..." or s end
local function text(s,x,y,col,font) window:render_text(font or small,Vec.new(x,y),col or bone,tostring(s)) end
local function skull(x,y,size)
 local u=size/32
 rect(x+5*u,y,22*u,17*u,bone,3);rect(x+9*u,y+16*u,14*u,9*u,bone,2)
 rect(x+8*u,y+6*u,6*u,6*u,c(19,8,13),2);rect(x+19*u,y+6*u,6*u,6*u,c(19,8,13),2)
 rect(x+15*u,y+13*u,3*u,4*u,crimson,1)
 for i=0,2 do rect(x+(11+i*4)*u,y+20*u,2*u,5*u,c(19,8,13),1) end
end
-- Button icons are crops of OUR crypt artwork, not Rogue class imagery.
local crops={skull={.09,.05,.36,.40},chest={.01,.57,.27,.87},bones={.18,.75,.43,.97},lantern={.40,.32,.54,.66}}
local function icon(name,x,y,size)
 rect(x-1,y-1,size+2,size+2,c(79,24,32),4);outline(x-1,y-1,size+2,size+2,c(210,145,112),4)
 local uv=crops[name] or crops.skull
 if texture and core.graphics.draw_texture_rect then
  core.graphics.draw_texture_rect(texture,Vec.new(origin.x+x,origin.y+y),size,size,uv[1],uv[2],uv[3],uv[4],c(255,255,255),true)
 else skull(x,y,size) end
end
local function button(label,x,y,w,fn,active,name,h)
 h=h or 38;local a,b=Vec.new(x,y),Vec.new(x+w,y+h);local hover=window:is_mouse_hovering_rect(a,b)
 rect(x,y,w,h,active and c(157,28,42,245) or hover and c(91,26,40,235) or c(42,16,25,210),5)
 outline(x,y,w,h,active and c(236,153,119) or c(114,38,49),5)
 -- Small carved edge and blood drips keep every control in the same theme.
 rect(x+6,y,w-12,1,c(191,84,74,180),0)
 rect(x+w-20,y+1,2,7,c(111,12,26,210),1);rect(x+w-14,y+1,2,4,c(111,12,26,210),1)
 local offset=12;if name then icon(name,x+5,y+4,h-8);offset=h+4 end
 text(compact(label,math.floor((w-offset)/7)),x+offset,y+math.floor((h-14)/2),active and c(255,237,206) or bone)
 if window:is_rect_clicked(a,b) then fn() end
end
local function panel(x,y,w,h,alpha)
 rect(x,y,w,h,c(19,10,17,alpha or 232),9);outline(x,y,w,h,c(104,37,47,210),9)
end
local function row(label,value,y,name,note,fn)
 panel(414,y,556,53,232);icon(name or "skull",421,y+7,38)
 text(label,470,y+8);text(compact(note,53),470,y+31,muted)
 button(value and "ON" or "OFF",888,y+12,70,fn,value,nil,29)
end
local function load_art()
 if texture or attempts>=3 or frames%60~=1 then return end
 attempts=attempts+1
 local ok,t=pcall(function() return core.graphics.load_texture(require("bc_art").background) end)
 -- Match the working Rogue loader: zero is a valid Lua-truthy handle.
 if ok and type(t)=="number" and t==t then texture=t;M.art_status="Loaded"
 else M.art_status="Crypt artwork unavailable: "..compact(t,100);if attempts==3 and core.log_error then core.log_error("Bloodcrypt artwork: "..tostring(t)) end end
end
function M.render(s,action)
 if not window then
  window=core.menu.window("bloodcrypt_delver_command_v2");window:set_initial_position(Vec.new(100,90));window:set_initial_size(Vec.new(W,H))
  if window.set_render_layer then window:set_render_layer(1) end
 end
 if last_visibility~=s.open then window:set_visibility(s.open);last_visibility=s.open end;if not s.open then return end
 frames=frames+1;window:force_window_size(Vec.new(W,H))
 window:begin(0,false,c(16,8,14),crimson,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  origin=window:get_position();load_art()
  if texture then core.graphics.draw_texture(texture,Vec.new(origin.x,origin.y),W,H,c(255,255,255),true)
  else
   for i=0,19 do rect(i*50,0,50,H,c(math.max(14,47-i),8,16),0) end
   skull(80,190,180);text("CRYPT ARTWORK UNAVAILABLE",30,455,crimson)
   text(compact(M.art_status,51),30,482,muted)
  end
  outline(1,1,W-2,H-2,c(176,42,56),12)
  -- The left crypt, doorway and chest stay visible. Contrast surfaces sit right.
  panel(500,10,482,82,236);icon("skull",510,23,44)
  text("BLOODCRYPT DELVER",568,21,bone,large)
  text("MIDNIGHT  |  INTO THE CRYPT",569,51,c(222,106,102))
  text("F9 OPEN / CLOSE  |  DELVE EXPEDITIONS",569,73,muted)
  panel(402,100,580,64,214)
  text(s.bot.enabled and "EXPEDITION ACTIVE" or "EXPEDITION STOPPED",420,115,s.bot.enabled and bone or muted)
  text("Tier "..tostring(s.bot.options.tier or 8).."  /  External combat",420,140,muted)
  button("START",752,111,105,function() action("start") end,s.bot.enabled,"lantern",40)
  button("STOP",867,111,103,function() action("stop") end,false,"skull",40)
  for i,label in ipairs({"EXPEDITION","DELVE ATLAS","STORY PLANS","OPTIONS","CHRONICLE"}) do
   local page=i;local x=20+((i-1)%3)*320;local y=178+math.floor((i-1)/3)*44
   button(label,x,y,306,function() M.page=page end,M.page==i,({"skull","chest","bones","lantern","skull"})[i],38)
  end
  panel(402,270,580,410,238)
  local b=s.bot;local r=s.route
  if M.page==1 then
   text("THE EXPEDITION",420,286,crimson)
   panel(414,319,556,69,220);icon("skull",423,332,43)
   text(compact(s.catalog[s.selected].name,52),480,332)
   text(compact(s.catalog[s.selected].variants[s.variant or 1],52),480,358,muted)
   text(compact(b.state,65),420,412,b.enabled and bone or muted)
   text("Adaptive objective cycle "..tostring(b.index or 0).."   |   Runs "..tostring(b.runs or 0),420,444,muted)
   text("ArthasNav: "..compact(s.nav,57),420,477,muted)
   text("Bridge: "..compact(s.bridge_status or "Not connected",58),420,505,muted)
   button("PREVIOUS STORY",420,544,267,function() action("variant",-1) end,false,"bones")
   button("NEXT STORY",700,544,267,function() action("variant",1) end,false,"bones")
   text(compact(s.wigs_status or "BigWigs not checked",66),420,609,muted)
   local bar=s.wigs_bars and s.wigs_bars[1];if bar then text(compact(bar.text,52).."  /  "..string.format("%.1fs",bar.remaining),420,638,bone) end
  elseif M.page==2 then
   text("DELVE ATLAS",420,286,crimson)
   for i,v in ipairs(s.catalog) do local id=i;button(v.name,414+((i-1)%3)*184,315+math.floor((i-1)/3)*52,176,function() action("select",id) end,id==s.selected,v.nemesis and "skull" or "chest",38) end
   text("13 delves  /  2 Nemesis lairs",420,654,muted)
  elseif M.page==3 then
   text("BUILT-IN STORY PLANS",420,286,crimson)
   local plan=Plans.get(s.selected,s.variant or 1)
   text(compact(plan and plan.name or "Unknown story",64),420,323,bone)
   if plan then
    text(compact(plan.status,68),420,353,muted)
    for i,phase in ipairs(plan.phases) do text(compact(i..". "..phase,67),420,395+(i-1)*35,muted) end
    text("Final encounter: "..compact(plan.boss or "Scenario completion",48),420,607,bone)
   end
   text("Live objective pins drive verified adaptive execution.",420,640,muted)
  elseif M.page==4 then
   text("EXPEDITION OPTIONS",420,286,crimson)
   if M.tier_open then
    text("SELECT DELVE TIER",420,323,bone)
    local choices=s.catalog[s.selected].nemesis and {8,11} or {1,2,3,4,5,6,7,8,9,10,11}
    for i,tier in ipairs(choices) do local chosen=tier;button("TIER "..tier,420+((i-1)%3)*180,365+math.floor((i-1)/3)*55,165,function() M.tier_open=false;action("tier",chosen) end,tier==b.options.tier,"skull") end
    button("CLOSE",700,605,265,function() M.tier_open=false end,false,"bones")
   else
   row("Repeat expedition",b.options.repeat_run,317,"bones","Run the selected story again",function() action("repeat") end)
   row("Leave after completion",b.options.auto_exit,377,"skull","Wait for reward handling before exiting",function() action("exit") end)
   row("Collect reward chests",b.options.auto_loot,437,"chest","Confirm loot before leaving the crypt",function() action("loot") end)
   row("Use a coffer key",b.options.spend_key,497,"chest","Open the Bountiful Coffer when enabled",function() action("key") end)
    button("AUTO MOUNT: "..(b.options.auto_mount and "ON" or "OFF"),420,554,250,function() action("mount") end,not b.options.auto_mount,"bones")
    button("FLYING: "..(b.options.prefer_flying and "AUTO" or "GROUND"),690,554,275,function() action("fly") end,not b.options.prefer_flying,"lantern")
    button("TIER "..tostring(b.options.tier or 8).."  ▼",420,602,300,function() M.tier_open=true end,false,"skull")
    text("Runs: "..(b.options.max_runs==0 and "Until Stop" or tostring(b.options.max_runs)),735,614)
    button("RUN -",880,602,40,function() action("limit",-1) end);button("RUN +",925,602,40,function() action("limit",1) end)
    text("Logger: scripts_data/bloodcrypt_delver/run_report.lua",420,653,muted)
   end
  else
   text("CRYPT CHRONICLE",420,286,crimson)
   local first=math.max(1,#b.log-10);for i=first,#b.log do text(compact(b.log[i],67),420,324+(i-first)*29,muted) end
  end
  -- Small artwork dock keeps the existing skull, bones and chest theme visible.
  for i,name in ipairs({"skull","bones","chest","lantern","skull"}) do icon(name,28+(i-1)*68,635,54) end
  panel(20,697,362,46,203);text(compact(s.character and s.character.label or "PVE / EXTERNAL COMBAT / ARTHASNAV",45),33,713,muted)
  panel(402,692,580,56,236);text("STATUS: "..compact(s.notice or b.state,68),420,708,muted)
   text("v0.6.28  |  F9 TOGGLE",420,732,c(200,103,103))
 end)
end
return M

