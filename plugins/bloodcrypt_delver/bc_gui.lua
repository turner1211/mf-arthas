local Color=require("common/color")
local Vec=require("common/geometry/vector_2")
local Enums=require("common/enums")
local Plans=require("bc_story_plans")
local Themes=require("bc_themes")
local M={page=1,art_status="Waiting"}
local window,texture;local attempts,frames=0,0;local origin={x=80,y=55};local last_visibility
local W,H=1240,760
local function c(r,g,b,a) return Color.new(r,g,b,a or 255) end
local bone=c(239,218,176);local muted=c(178,165,155);local pale=c(232,229,220)
local we=Enums.window_enums or Enums;local fonts=we.font_id or {};local small=fonts.FONT_SMALL or 0;local large=fonts.FONT_BIG or small
local accent={185,45,68};local glow={111,35,137}
local function ac(a) return c(accent[1],accent[2],accent[3],a) end
local function gc(a) return c(glow[1],glow[2],glow[3],a) end
local function rect(x,y,w,h,col,r) window:render_rect_filled(Vec.new(x,y),Vec.new(x+w,y+h),col,r or 5) end
local function outline(x,y,w,h,col,r) if window.render_rect then window:render_rect(Vec.new(x,y),Vec.new(x+w,y+h),col,r or 5,1) end end
local function compact(s,n) s=tostring(s or ""):gsub("[%c]"," ");return #s>n and s:sub(1,n-3).."..." or s end
local function text(s,x,y,col,font) window:render_text(font or small,Vec.new(x,y),col or bone,tostring(s)) end
local function panel(x,y,w,h,a) rect(x,y,w,h,c(7,14,15,a or 232),8);outline(x,y,w,h,ac(180),8) end
local function skull(x,y,size)
 local u=size/32;rect(x+5*u,y,22*u,17*u,bone,3);rect(x+9*u,y+16*u,14*u,9*u,bone,2)
 rect(x+8*u,y+6*u,6*u,6*u,c(12,16,15),2);rect(x+19*u,y+6*u,6*u,6*u,c(12,16,15),2);rect(x+15*u,y+13*u,3*u,4*u,ac(255),1)
 for i=0,2 do rect(x+(11+i*4)*u,y+20*u,2*u,5*u,c(12,16,15),1) end
end
local crops={skull={.43,.00,.57,.18},chest={.49,.75,.61,.96},bones={.00,.72,.17,.98},lantern={.01,.14,.10,.34}}
local function icon(name,x,y,size)
 rect(x-1,y-1,size+2,size+2,c(16,26,25,235),5);outline(x-1,y-1,size+2,size+2,ac(220),5)
 local uv=crops[name] or crops.skull
 if texture and core.graphics.draw_texture_rect then core.graphics.draw_texture_rect(texture,Vec.new(origin.x+x,origin.y+y),size,size,uv[1],uv[2],uv[3],uv[4],c(255,255,255),true) else skull(x,y,size) end
end
local function button(label,x,y,w,fn,active,name,h)
 h=h or 42;local a,b=Vec.new(x,y),Vec.new(x+w,y+h);local hover=window:is_mouse_hovering_rect(a,b)
 rect(x,y,w,h,active and ac(225) or hover and gc(210) or c(12,27,27,225),6);outline(x,y,w,h,active and c(235,201,126) or ac(150),6)
 if active then rect(x,y,5,h,ac(255),4) end
 local off=14;if name then icon(name,x+6,y+5,h-10);off=h+5 end
 text(compact(label,math.max(7,math.floor((w-off)/7))),x+off,y+math.floor((h-14)/2),active and pale or bone)
 if window:is_rect_clicked(a,b) then fn() end
end
local function toggle(label,value,y,note,fn,name,hotkey)
 panel(287,y,918,52,220);icon(name or "skull",297,y+7,37);text(label,346,y+8,pale);text(compact(note,61),346,y+30,muted)
 if hotkey then panel(985,y+11,83,30,235);text(hotkey,1010,y+19,bone) end
 local x=1085;rect(x,y+11,103,30,value and ac(235) or c(27,39,38,240),15);outline(x,y+11,103,30,value and c(228,194,117) or c(84,91,84),15)
 rect(value and x+75 or x+5,y+15,22,22,value and c(237,220,162) or c(124,128,121),11);text(value and "ON" or "OFF",value and x+17 or x+43,y+19,pale)
 if window:is_rect_clicked(Vec.new(x,y+11),Vec.new(x+103,y+41)) then fn() end
end
local function stepper(label,value,y,note,minus,plus,name)
 panel(287,y,918,52,220);icon(name or "bones",297,y+7,37);text(label,346,y+8,pale);text(compact(note,62),346,y+30,muted)
 button("<",1051,y+10,39,minus,false,nil,31);panel(1096,y+10,50,31,240);text(tostring(value),1113,y+19,pale);button(">",1152,y+10,39,plus,false,nil,31)
end
local function load_art()
 if texture or attempts>=3 or frames%60~=1 then return end;attempts=attempts+1
 local ok,t=pcall(function() return core.graphics.load_texture(require("bc_art").background) end)
 if ok and type(t)=="number" and t==t then texture=t;M.art_status="Loaded" else M.art_status="Crypt artwork unavailable: "..compact(t,100) end
end
local nav={{"DASHBOARD","skull"},{"DELVE","lantern"},{"STORY","bones"},{"REWARDS","chest"},{"NAVIGATION","lantern"},{"COMBAT","skull"},{"RECOVERY","bones"},{"DIAGNOSTICS","chest"},{"HOTKEYS","skull"}}
function M.render(s,action)
 if not window then window=core.menu.window("bloodcrypt_delver_command_v3");window:set_initial_position(Vec.new(80,55));window:set_initial_size(Vec.new(W,H));if window.set_render_layer then window:set_render_layer(1) end end
 if last_visibility~=s.open then window:set_visibility(s.open);last_visibility=s.open end;if not s.open then return end
 frames=frames+1;window:force_window_size(Vec.new(W,H));local theme=Themes.get(s.selected);accent=theme.accent;glow=theme.glow
 window:begin(0,false,c(5,10,11),ac(255),(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  origin=window:get_position();load_art()
  if texture then core.graphics.draw_texture(texture,Vec.new(origin.x,origin.y),W,H,c(255,255,255),true) else rect(0,0,W,H,c(10,8,12),0);skull(30,260,180) end
  rect(0,0,W,H,c(3,10,11,158),0);outline(1,1,W-2,H-2,ac(240),11)
  panel(18,15,1204,105,238);icon("skull",35,31,70)
  text("BLOODCRYPT DELVER",122,29,bone,large);text(theme.title,122,62,ac(255));text("ARTHASNAV EXPEDITION SUITE  •  v0.6.30",122,88,muted)
  panel(850,31,170,34,235);text("THEME: "..compact(theme.motif,17),865,42,ac(255));panel(1034,31,169,34,235);text(s.bot.enabled and "●  ACTIVE" or "○  STOPPED",1050,42,s.bot.enabled and c(116,223,102) or muted)
  button("START",850,73,168,function() action("start") end,s.bot.enabled,"lantern",34);button("STOP",1034,73,169,function() action("stop") end,false,"skull",34)
  panel(18,132,246,610,235);for i,item in ipairs(nav) do local page=i;button(item[1],30,145+(i-1)*58,222,function() M.page=page end,M.page==i,item[2],48) end
  text("THE CRYPT REMEMBERS",50,685,ac(255));text("WE ADAPT • WE RETURN",50,711,muted)
  panel(276,132,946,610,238);local b=s.bot;local delve=s.catalog[s.selected];local variant=s.variant or 1
  text(nav[M.page][1],298,153,bone,large);text(compact(delve.name.."  •  "..delve.variants[variant],78),298,184,ac(255));text(compact(theme.hazard,75),298,207,muted)
  if M.page==1 then
   panel(287,240,918,76,225);icon("skull",300,255,45);text(compact(b.state,80),362,254,b.enabled and pale or muted);text("Cycle "..tostring(b.index or 0).."  •  Runs "..tostring(b.runs or 0).."  •  Tier "..tostring(b.options.tier or 8),362,282,muted)
   panel(287,328,448,104,225);text("ROUTE PROFILE",305,345,ac(255));text(theme.travel,305,374,pale);text("Recommended pull cap: "..theme.pull,305,400,muted)
   panel(747,328,458,104,225);text("LIVE SERVICES",765,345,ac(255));text("ArthasNav: "..compact(s.nav,42),765,374,pale);text("Bridge: "..compact(s.bridge_status or "Waiting",45),765,400,muted)
   panel(287,444,918,84,225);text("CURRENT MECHANIC",305,461,ac(255));local bar=s.wigs_bars and s.wigs_bars[1];text(bar and compact(bar.text,75).."  •  "..string.format("%.1fs",bar.remaining) or compact(s.wigs_status or "No active timer",80),305,492,pale)
   panel(287,540,918,73,225);text("STATUS",305,557,ac(255));text(compact(s.notice or b.state,105),305,586,muted)
  elseif M.page==2 then
   for i,v in ipairs(s.catalog) do local id=i;button(v.name,292+((i-1)%3)*300,239+math.floor((i-1)/3)*68,286,function() action("select",id) end,id==s.selected,v.nemesis and "skull" or "lantern",52) end
   text("Every delve has its own palette, motif, hazard note and route profile.",298,660,muted)
  elseif M.page==3 then
   local plan=Plans.get(s.selected,variant);panel(287,240,918,70,225);text(plan and plan.name or "Unknown story",305,257,pale);text(compact(plan and plan.status or "Waiting for live evidence",95),305,285,muted)
   if plan then for i,phase in ipairs(plan.phases) do panel(287,322+(i-1)*48,918,40,210);text(i.."  "..compact(phase,103),305,335+(i-1)*48,i==1 and ac(255) or pale) end end
   button("PREVIOUS STORY",287,623,290,function() action("variant",-1) end,false,"bones",42);button("NEXT STORY",915,623,290,function() action("variant",1) end,false,"bones",42)
  elseif M.page==4 then
   toggle("Collect reward containers",b.options.auto_loot,240,"Finish verified loot handling before exit",function() action("loot") end,"chest","F6")
   toggle("Spend Restored Coffer Keys",b.options.spend_key,300,"Eligibility and reserve checked before every coffer",function() action("key") end,"chest","F7")
   stepper("Key reserve",b.options.key_reserve or 1,360,"Never spend below this number",function() action("reserve",-1) end,function() action("reserve",1) end,"bones")
   toggle("Leave after rewards",b.options.auto_exit,420,"Exit only after the reward window settles",function() action("exit") end,"lantern")
   panel(287,490,918,92,225);text(theme.labyrinth and "KINDO'JAN: THREE-COFFER BUDGET" or theme.nemesis and "NEMESIS REWARD GUARD" or "STANDARD REWARD PROFILE",305,508,ac(255));text("Key spending fails closed without verified eligibility.",305,540,muted)
  elseif M.page==5 then
   toggle("Automatic mount selection",b.options.auto_mount,240,"Choose a usable collected mount",function() action("mount") end,"lantern","F11")
   toggle("Prefer flying",b.options.prefer_flying,300,"Fall back to ground travel when needed",function() action("fly") end,"lantern")
   toggle("Hazard avoidance",b.options.hazard_avoidance,360,"Reject unsafe goals and evade registered danger",function() action("hazards") end,"skull")
   toggle("Automatic story detection",b.options.auto_story,420,"Switch to the bridge-confirmed story after entry",function() action("storydetect") end,"bones")
   panel(287,490,918,92,225);text("TRAVEL: "..theme.travel,305,508,ac(255));text("ArthasNav is the exclusive owner; BG and questing navigation remain isolated.",305,540,muted)
  elseif M.page==6 then
   toggle("External combat handoff",b.options.combat_hold,240,"Let the rotation plugin own combat decisions",function() action("combat") end,"skull","F8")
   toggle("Level-aware combat profile",b.options.auto_level,300,"Scale pull size and combat range from level, spec and role",function() action("autolevel") end,"bones")
   toggle("Approach hostile targets",b.options.combat_approach,360,"Use melee, ranged or healer engagement distance",function() action("approach") end,"skull")
   toggle("Face combat targets",b.options.auto_face,420,"Continuously face the selected hostile",function() action("face") end,"skull")
   stepper("Maximum pull ceiling",b.options.max_pull or 5,480,"Level profile may choose a safer lower limit",function() action("pull",-1) end,function() action("pull",1) end,"skull")
   panel(287,545,918,62,225);text("AUTO-DETECTED: "..compact(s.character and s.character.label or "Detecting class / spec / role / level",95),305,558,ac(255));text("PROFILE: "..compact(b.level_profile and (b.level_profile.label.." / "..b.level_profile.rotation.." / pull "..b.level_profile.max_pull) or "Waiting for live character",90),305,582,muted)
  elseif M.page==7 then
   toggle("Recover after death",b.options.recover_death,240,"Return to corpse or checkpoint and rescan",function() action("recover") end,"bones","F10")
   toggle("Repeat selected expedition",b.options.repeat_run,300,"Continue until Stop or the run limit",function() action("repeat") end,"lantern","F12")
   toggle("Persist objective memory",b.options.objective_memory,360,"Retain completed objectives through reloads and recovery",function() action("memory") end,"bones")
   stepper("Run limit",b.options.max_runs==0 and "∞" or b.options.max_runs,420,"Zero means continue until Stop",function() action("limit",-1) end,function() action("limit",1) end,"bones")
   stepper("Delve tier",b.options.tier or 8,480,delve.nemesis and "Nemesis uses tier 8 or 11" or "Requires exact bridge acknowledgement",function() action("tier",(b.options.tier or 8)-1) end,function() action("tier",(b.options.tier or 8)+1) end,"skull")
  elseif M.page==8 then
   text("LIVE CHRONICLE",298,240,ac(255));local first=math.max(1,#b.log-11);for i=first,#b.log do panel(287,267+(i-first)*32,918,27,195);text(compact(b.log[i],113),300,274+(i-first)*32,muted) end;text("scripts_data/bloodcrypt_delver/run_report.lua",298,660,ac(255))
  else
   toggle("Enable action hotkeys",b.options.hotkeys_enabled,240,"F9 panel toggle always remains available",function() action("hotkeys") end,"skull")
   toggle("Start / Stop expedition",b.options.hk_master,300,"Toggle the selected expedition",function() action("hk_master") end,"lantern","F5")
   toggle("Reward collection",b.options.hk_loot,360,"Toggle automatic reward handling",function() action("hk_loot") end,"chest","F6")
   toggle("Coffer key spending",b.options.hk_key,420,"Toggle verified key spending",function() action("hk_key") end,"chest","F7")
   toggle("Combat handoff",b.options.hk_combat,480,"Toggle external combat handoff",function() action("hk_combat") end,"skull","F8")
   toggle("Death recovery",b.options.hk_recovery,540,"Toggle corpse and checkpoint recovery",function() action("hk_recovery") end,"bones","F10")
   toggle("Mount / Repeat hotkeys",b.options.hk_travel,600,"F11 toggles mounting; F12 toggles repetition",function() action("hk_travel") end,"lantern","F11/12")
  end
  text("BLOODCRYPT • "..theme.motif.." • ADAPT AND DESCEND",790,718,ac(210))
 end)
end
return M
