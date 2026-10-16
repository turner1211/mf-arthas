local Color=require("common/color")
local Vec=require("common/geometry/vector_2")
local Enums=require("common/enums")
-- Follow the Rogue GUI's image-backed presentation. Local class/spec art is the
-- primary source; the shared icon helper supplies newer or missing WoW assets.
local embedded_ok,EmbeddedIcons=pcall(require,"bg_icon_data")
if not embedded_ok then EmbeddedIcons={} end
local horror_ok,HorrorArt=pcall(require,"bg_horror_art")
if not horror_ok then HorrorArt={} end
local class_art_ok,ClassArt=pcall(require,"bg_class_art")
if not class_art_ok then ClassArt={} end
local icon_ok,IconHelper=pcall(require,"common/utility/icons_helper")
if not icon_ok then IconHelper=nil end
local icon_aliases={battle="achievement_bg_killxenemies_generalsroom",orb="spell_holy_powerinfusion",
 helm="inv_helmet_96",skull="ability_rogue_bloodyeye",shield="inv_shield_06"}
local Theme=require("bg_theme")
local theme=Theme.resolve(nil,nil)
-- Keep the optional command window cold during normal play. Constructing its
-- native windows during every F6 hot reload stalls the game client. The API
-- can still open it explicitly when diagnostics are needed.
local M={open=false,page=1,notice="",log_offset=0,debug_offset=0,queue_dropdown=false}
local block_controls=false
local main,hud,initialized;local positions={};local dragging,was_down
local textures={};local texture_attempts={}
local horror_textures={};local horror_attempted={}
local function c(r,g,b,a) return Color.new(math.floor(r),math.floor(g),math.floor(b),a or 255) end
local gold=c(219,177,94);local ink=c(234,230,220);local muted=c(155,164,178)
local red=c(130,39,44);local blue=c(42,66,106);local panel=c(26,31,43)
local backdrop=c(12,9,14);local surface=c(30,20,28);local blood=c(104,5,18)
local we=Enums.window_enums or Enums;local font=(we.font_id or {}).FONT_SMALL or 0
local function compact(s,n) s=tostring(s or "-"):gsub("[%c]"," ");return #s>n and s:sub(1,n-3).."..." or s end
local function rect(w,x,y,width,height,col) w:render_rect_filled(Vec.new(x,y),Vec.new(x+width,y+height),col,5) end
local function outline(w,x,y,width,height,col,thickness)
 if type(w.render_rect)=="function" then w:render_rect(Vec.new(x,y),Vec.new(x+width,y+height),col,5,thickness or 1) end
end
local function text(w,s,x,y,col) w:render_text(font,Vec.new(x,y),col or ink,s) end
local function asset_key(name)
 if name==theme.class_icon then return theme.class_asset end
 if name==theme.spec_icon then return theme.spec_asset end
 return name
end
local function local_texture(name)
 local key=asset_key(name);local texture=textures[key]
 if texture==false then return nil end
 if texture then return texture end
 if texture_attempts[key] then return nil end
 texture_attempts[key]=true
 local bytes=EmbeddedIcons[key]
 if bytes and core.graphics and type(core.graphics.load_texture)=="function" then
  local ok,result=pcall(core.graphics.load_texture,bytes)
  if ok and result then textures[key]=result;return result end
 end
 textures[key]=false;return nil
end
local function draw_art(w,name,x,y,width,height,tint)
 local texture=local_texture(name)
 if texture and core.graphics and type(core.graphics.draw_texture)=="function" then
  local p=w:get_position()
  local ok=pcall(core.graphics.draw_texture,texture,Vec.new(p.x+x,p.y+y),width,height,tint or c(255,255,255,255),true)
  return ok
 end
 return false
end
local function draw_horror_background(w,width,height)
 local key=tonumber(theme.class_id) or 0
 if not horror_attempted[key] then
  horror_attempted[key]=true
  local bytes=ClassArt[key] or HorrorArt.background
  if bytes and core.graphics and type(core.graphics.load_texture)=="function" then
   local ok,result=pcall(core.graphics.load_texture,bytes)
   if ok and result then horror_textures[key]=result end
  end
 end
 local horror_texture=horror_textures[key]
 if horror_texture and core.graphics and type(core.graphics.draw_texture)=="function" then
  local p=w:get_position()
  return pcall(core.graphics.draw_texture,horror_texture,Vec.new(p.x,p.y),width,height,c(255,255,255,255),true)
 end
 return false
end
local function icon(w,name,x,y,size)
 rect(w,x-2,y-2,size+4,size+4,gold)
 local slug=icon_aliases[name] or name;local drawn=draw_art(w,name,x,y,size,size,c(255,255,255,255))
 if IconHelper and type(IconHelper.draw_icon)=="function" then
  local p=w:get_position()
  local ok,result=pcall(IconHelper.draw_icon,IconHelper,slug,Vec.new(p.x+x,p.y+y),size,size,c(255,255,255),true,
   {size=size>=40 and "large" or "medium",persist_to_disk=true})
  drawn=ok and result==true
 end
 if not drawn then rect(w,x,y,size,size,blue);text(w,tostring(name):sub(1,1):upper(),x+size/3,y+size/3,gold) end
end
local function button(w,label,x,y,width,fn,active,name,danger)
 if width>=98 then name=name or theme.spec_icon end
 local hover=w:is_mouse_hovering_rect(Vec.new(x,y),Vec.new(x+width,y+36))
 rect(w,x,y,width,36,danger and blood or active and blue or hover and c(theme.accent[1]*.32+24,theme.accent[2]*.32+18,theme.accent[3]*.32+20) or surface)
 outline(w,x,y,width,36,hover and gold or active and c(theme.accent[1],theme.accent[2],theme.accent[3],220) or c(theme.blood[1],theme.blood[2],theme.blood[3],150),hover and 2 or 1)
 if active then rect(w,x,y,4,36,gold) end
 if name then icon(w,name,x+8,y+7,22) end
 text(w,label,x+(name and 40 or 12),y+11,active and gold or ink)
 if not block_controls and w:is_rect_clicked(Vec.new(x,y),Vec.new(x+width,y+36)) then fn() end
end
local function init()
 if initialized then return end
 main=main or core.menu.window("sylvanas_bg_command_v1")
 hud=hud or core.menu.window("sylvanas_bg_hud_v1")
 positions[main]=positions[main] or {x=38,y=42,width=1000,height=660}
 positions[hud]=positions[hud] or {x=840,y=100,width=360,height=248}
 for w,p in pairs(positions) do w:set_initial_position(Vec.new(p.x,p.y));w:set_initial_size(Vec.new(p.width,p.height)) end
 initialized=true
end
local function paint_backdrop(w,width,height)
 rect(w,0,0,width,height,backdrop)
 local illustrated=draw_horror_background(w,width,height)
 if illustrated then
  -- Class/spec color grading gives every detected identity its own version of
  -- the illustrated battlefield without flattening the source artwork.
  rect(w,0,0,width,height,c(theme.shadow[1],theme.shadow[2],theme.shadow[3],78))
  rect(w,0,0,18,height,c(theme.color[1],theme.color[2],theme.color[3],210))
 end
 -- Spec-specific battlefield scars. Motif changes spacing, density and side,
 -- producing forty distinct canvases without image decoding or reload cost.
 local motif=tonumber(theme.motif) or 1
 local bands=5+(motif%5)
 for i=0,bands do
  local bw=math.max(10,math.floor(width/(bands+1)))
  local x=(i*bw*2+motif*17)%math.max(1,width-20)
  rect(w,x,0,math.max(5,bw),height,c(theme.shadow[1]+i*2,theme.shadow[2]+i,theme.shadow[3]+i*2,illustrated and 35 or 115))
 end
 rect(w,0,0,width,8,blood);rect(w,0,height-5,width,5,blood)
 -- Blood drips and claw cuts mirror the Rogue panel's graphic fallback.
 for i=1,6 do
  local x=(motif*43+i*107)%(width-18)
  local h=10+((motif*13+i*19)%42)
  rect(w,x,8,8,h,c(theme.blood[1],theme.blood[2],theme.blood[3],175))
 end
 for i=1,3 do
  local x=18+i*16+(motif%4)*5
  rect(w,x,120+i*13,7,130,c(theme.accent[1],theme.accent[2],theme.accent[3],55))
 end
 -- Every class/spec has its own local heraldic art. Oversized, tinted crests
 -- create the same full-canvas character identity as the Rogue reference while
 -- leaving the operational panels readable.
 draw_art(w,theme.class_asset,18,112,270,270,c(theme.color[1],theme.color[2],theme.color[3],150))
 draw_art(w,theme.spec_asset,width-300,height-315,278,278,c(255,255,255,130))
 rect(w,8,102,292,5,c(theme.color[1],theme.color[2],theme.color[3],210))
 rect(w,width-308,height-326,300,5,c(theme.accent[1],theme.accent[2],theme.accent[3],210))
 if width>=900 then
  -- A dedicated war-banner column keeps the class/spec horror identity fully
  -- visible instead of burying the art beneath functional controls.
  rect(w,760,12,226,height-24,c(theme.shadow[1],theme.shadow[2],theme.shadow[3],190))
  outline(w,760,12,226,height-24,c(theme.blood[1],theme.blood[2],theme.blood[3],245),3)
  draw_art(w,theme.spec_asset,775,42,196,196,c(255,255,255,255))
  rect(w,775,242,196,6,c(theme.blood[1],theme.blood[2],theme.blood[3],255))
  draw_art(w,theme.class_asset,797,366,152,152,c(theme.color[1],theme.color[2],theme.color[3],235))
  icon(w,"skull",851,536,34)
  text(w,compact(theme.title or "BLOOD AND GLORY",27),776,274,c(theme.accent[1],theme.accent[2],theme.accent[3]))
  text(w,compact(theme.label or "UNKNOWN",28),776,300,ink)
  text(w,"PVP WAR BANNER",811,334,blood)
  for i=0,7 do
   local drip=8+((i*17+(theme.motif or 1)*11)%52)
   rect(w,766+i*28,18,8,drip,c(theme.blood[1],theme.blood[2],theme.blood[3],235))
  end
 end
 outline(w,1,1,width-2,height-2,c(theme.blood[1],theme.blood[2],theme.blood[3],235),2)
end
local function begin(w,fn)
 local p=positions[w];w:force_window_size(Vec.new(p.width,p.height))
 if w.force_next_begin_window_pos then w:force_next_begin_window_pos(Vec.new(p.x,p.y)) end
 w:begin(0,false,backdrop,gold,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  paint_backdrop(w,p.width,p.height);fn()
 end)
end
local function readable(status)
 local names={disabled="Stopped",queued="Waiting in queue",queueing="Joining queue",accepting="Accepting invitation",
 waiting_start="Waiting for battle to begin",finished="Battle complete",waiting_resurrection="Waiting for resurrection",
 mounting="Mounting while out of combat",collect_powerup="Collecting nearby battleground buff",preparing_healthstone="Moving to Soulwell",using_healthstone="Collecting Healthstone",
 preparing_feast="Moving to feast",using_feast="Eating feast",
 preparing_refreshments="Moving to refreshment table",using_refreshments="Collecting refreshments",preparation_interaction_hold="Waiting for supply interaction",using_objective="Claiming objective",
 preparing_cauldron="Moving to potion cauldron",using_cauldron="Collecting battle potions",
 objective_provider_required="Objective connection required",objective_state_unavailable="Waiting for live objective data",
 navigation_unavailable="Navigation connection required",navigation_reconnecting="Navigation reconnecting",navigation_path_timeout="Navigation path retry",casting_or_capturing="Casting or capturing",
 seething_leaving_airship="Leaving Seething Shore airship",seething_descending="Descending to Seething Shore",
 seething_reaching_landing="Reaching a safe Seething Shore landing"}
 names.seething_landing_recovery="Clearing the Seething Shore landing"
names.waiting_for_stable_ground="Waiting to reach stable ground"
names.healer_casting_hold="Holding position while healing"
 names.combat_approaching="Closing on combat target"
 names.combat_holding="Holding attack range and facing target"
 names.combat_reacquiring="Reacquiring combat target"
 names.combat_path_escape_left="Stepping left around combat obstruction"
 names.combat_path_escape_right="Stepping right around combat obstruction"
 names.combat_path_replanning="Retrying combat approach"
 names.live_player_position_unavailable="Waiting for player location"
 names.movement_destination_invalid="Waiting for a valid destination"
 names.corpse_navigation_replanning="Replanning route to corpse"
 names.objective_provider_cooling_down="Objective connection recovering automatically"
 names.recovering_runtime_error="Recovering from a temporary error"
 names.recovery_attention_required="Repeated error — press START to retry"
 names.navigation_replanning="Replanning stalled movement"
 names.navigation_trackback_replanning="Correcting a predicted path loop"
 names.navigation_progress_replanning="Correcting a route that stopped advancing"
 names.navigation_destination_reclaiming="Restoring the battleground route"
 names.mounted_narrow_corridor_dismounting="Dismounting before a narrow corridor"
 names.navigation_wrong_way_recovery="Correcting movement away from destination"
 names.navigation_recovering="Resetting a blocked route"
 names.navigation_directional_escape="Sidestepping around an obstruction"
 names.navigation_rebound_left="Rebounding left around an obstruction"
 names.navigation_rebound_right="Rebounding right around an obstruction"
 names.navigation_reverse_rebound="Turning around to clear an obstruction"
 names.navigation_blacklist_detour="Taking a new angle around a failed path"
 names.respond_callout="Responding to a team incoming callout"
 names.advance="Advancing with the team"
 names.objective_interaction_retry="Refreshing an unavailable objective"
 names.objective_interaction_confirming="Confirming the objective capture"
 names.post_match_safety_wait="Checking for delayed match penalties"
 names.confirming_match_entry="Confirming battleground entry"
 names.finding_corpse="Returning to corpse"
 names.releasing_spirit="Releasing spirit"
 names.waiting_corpse_recovery="Waiting for corpse recovery"
 names.reclaiming_corpse="Reclaiming corpse"
 names.corpse_position_unavailable="Waiting for corpse location"
 names.corpse_navigation_retry="Retrying route to corpse"
 names.death_recovery_instance_unsupported="Death recovery unavailable in this instance"
 names.deserter_active="Waiting for Deserter to expire"
 names.navigation_retry_wait="Waiting before retrying navigation"
 names.battleground_team_mismatch="Objective data has the wrong PvP team"
 names["version_adapter_required:queue_info"]="Queue data connection required"
 names["version_adapter_required:join_brawl"]="Brawl join connection required"
 names["version_adapter_required:join_blitz"]="Blitz join connection required"
 return names[status] or tostring(status):gsub("_"," ")
end
local function status_style(status,enabled)
 status=tostring(status or "")
 if not enabled or status=="disabled" then return muted,"Press START when you are ready." end
 if status:find("attention_required",1,true) then return c(224,90,90),"Press START to retry after checking the Debug page." end
 if status:find("unavailable",1,true) or status:find("required",1,true) or status:find("mismatch",1,true) then
  return c(225,150,68),"Open Debug for the missing connection or data source."
 end
 if status:find("retry",1,true) or status:find("replanning",1,true) or status:find("recover",1,true) or status:find("reacquiring",1,true) then
  return c(225,190,78),"Automatic recovery is active."
 end
 return c(82,190,130),"Monitoring movement, objectives, and combat."
end
function M.render(s,action)
 block_controls=false
 init()
 theme=s.theme or Theme.resolve(nil,nil)
 gold=c(theme.color[1],theme.color[2],theme.color[3])
 blue=c(theme.accent[1]*0.45,theme.accent[2]*0.45,theme.accent[3]*0.45)
 blood=c(theme.blood[1],theme.blood[2],theme.blood[3])
 backdrop=c(theme.background[1],theme.background[2],theme.background[3])
 surface=c(theme.surface[1],theme.surface[2],theme.surface[3],210)
 panel=c(theme.surface[1],theme.surface[2],theme.surface[3],196)
 local cursor=core.get_cursor_position and core.get_cursor_position()
 local down=core.input.is_key_pressed and core.input.is_key_pressed(0x01)==true
 if cursor and down and not was_down then
  for _,w in ipairs({hud,main}) do
   local p=positions[w];local visible=w==main and M.open or w==hud and s.show_hud
   if visible and cursor.x>=p.x and cursor.x<=p.x+p.width and cursor.y>=p.y and cursor.y<=p.y+40 then
    dragging={w=w,dx=cursor.x-p.x,dy=cursor.y-p.y};break
   end
  end
 end
 if dragging and cursor and down then
  local p=positions[dragging.w];p.x=math.max(0,cursor.x-dragging.dx);p.y=math.max(0,cursor.y-dragging.dy)
  if core.graphics.capture_next_mouse_input then core.graphics.capture_next_mouse_input() end
 elseif not down then dragging=nil end
 was_down=down
 local screen=core.graphics.get_screen_size and core.graphics.get_screen_size()
 if screen then for _,p in pairs(positions) do p.x=math.min(p.x,math.max(0,screen.x-p.width));p.y=math.min(p.y,math.max(0,screen.y-p.height)) end end
 local cap=s.capabilities or {};local ctx=s.context or {};local plan=ctx.plan or {}
 main:set_visibility(M.open)
 if M.open then begin(main,function()
  rect(main,10,10,740,86,panel);rect(main,10,10,5,86,gold)
  icon(main,theme.class_icon,26,27,48)
  text(main,"BATTLEGROUND COMMAND",91,24,gold)
  text(main,compact(theme.title or theme.epithet,48),91,46,c(theme.accent[1],theme.accent[2],theme.accent[3]))
  text(main,compact(theme.label,48),91,65,muted)
  text(main,compact(cap.version or "Unknown client",20),536,28,gold)
  button(main,"HIDE",652,51,82,function() M.open=false end)
  for i,label in ipairs({"BATTLE","OPTIONS","WAR LOG","DEBUG"}) do
   local page=i;button(main,label,24+(i-1)*180,110,172,function() M.page=page end,M.page==i,({theme.class_icon,theme.spec_icon,"skull","helm"})[i])
  end
  if M.page==1 then
   local status_color,status_hint=status_style(s.status,s.enabled)
   rect(main,24,163,712,76,panel);icon(main,theme.spec_icon,40,181,36)
   text(main,s.enabled and "COMMAND ACTIVE" or "COMMAND STANDBY",92,177,gold)
   text(main,compact(readable(s.status),84),92,203,status_color)
   for i,row in ipairs({{"BATTLEGROUND",s.area or "Outside battleground","battle"},
    {"OBJECTIVE",plan.kind and plan.kind:gsub("_"," ") or "Waiting for objective","orb"},
    {"QUEUE",s.queue_label or "Random Battleground","helm"}}) do
    local x=24+(i-1)*241;rect(main,x,253,230,86,panel);icon(main,row[3],x+12,266,26)
    text(main,row[1],x+49,269,gold);text(main,compact(row[2],29),x+12,308)
   end
   text(main,"CONNECTIONS",24,358,gold)
   local function connection(label,ok,x,y)
    rect(main,x,y,9,9,ok and c(82,170,124) or c(210,125,66));text(main,label..(ok and "  Ready" or "  Needed"),x+18,y-2,muted)
   end
   connection("Client APIs",cap.ready,24,388);connection("Objectives",s.provider_ready,270,388);connection("ArthasNav",s.navigation_ready,512,388)
   local sentinel_detail=not s.sentinel_provider and "Provider not loaded" or not s.sentinel_client and "Provider loaded / creating client" or
    s.navigation_ready and ((s.sentinel_provider_kind or "ArthasNav").." / ready") or ((s.sentinel_provider_kind or "ArthasNav").." / "..tostring(s.sentinel_state or "checking provider"))
   text(main,"ArthasNav: "..compact(sentinel_detail,54).."  |  Combat: external plugin",24,417,muted)
   button(main,s.enabled and "RUNNING" or "START",24,450,224,function() action("start") end,s.enabled,"battle")
   button(main,"STOP",266,450,224,function() action("stop") end,false,"skull",true)
   button(main,"COPY STATUS",508,450,228,function() main:copy_to_clipboard(s.report());M.notice="Status copied." end,false,"shield")
   local readiness=s.readiness or {};local pct=tonumber(readiness.live) or 0
   text(main,"NEXT STEP",24,510,gold);text(main,compact(status_hint,73),122,510,status_color)
   text(main,"LIVE VALIDATION  "..pct.."%  ("..tostring(readiness.passed or 0).." / "..tostring(readiness.total or 0)..")",24,540,gold)
   rect(main,24,564,712,12,c(36,42,56));if pct>0 then rect(main,24,564,math.floor(712*math.min(100,pct)/100),12,status_color) end
   local route=s.route_total and s.route_total>0 and ("Waypoint "..tostring(s.route_index).." of "..tostring(s.route_total)) or "ArthasNav generated route"
   if s.route_distance then route=route.."  /  "..string.format("%.0f yd",s.route_distance) end
   text(main,"ROUTE  "..compact(route,78),24,590,muted)
  elseif M.page==2 then
   local function number(label,value,y,key,step,lo,hi)
    rect(main,24,y,712,57,panel);text(main,label,40,y+19);text(main,tostring(value),532,y+19,gold)
    button(main,"-",595,y+10,52,function() action(key,math.max(lo,value-step)) end)
    button(main,"+",660,y+10,52,function() action(key,math.min(hi,value+step)) end)
   end
   text(main,"QUEUE FOR",24,164,gold)
   button(main,(s.queue_label or "Random Battleground").."  v",24,184,712,function() M.queue_dropdown=not M.queue_dropdown end,true,"battle")
   block_controls=M.queue_dropdown
   number(s.queue_id==0 and ("Auto queue ID: "..tostring(s.resolved_queue_id or "Waiting")) or "Queue ID for selected mode",s.queue_id,230,"queue",1,0,2000)
   number("Combat positioning range",s.combat_range,300,"range",1,3,40)
   text(main,"QUEUE ROLE",24,370,gold)
   for i,row in ipairs({{"TANK",2,"shield"},{"HEALER",4,"orb"},{"DAMAGE",8,"battle"}}) do
    local flag=row[2];button(main,row[1],24+(i-1)*241,395,230,function() action("role",flag) end,s.role_flags==flag,row[3])
   end
   text(main,"ACTIVE ROLE POLICY",24,439,gold)
   text(main,compact(s.role_policy or "Automatic objective and combat support",88),24,459,muted)
   text(main,"DAMAGE STYLE  "..string.upper(s.damage_style or "unknown").." / "..string.upper(s.damage_style_source or "automatic"),24,482,gold)
   for i,label in ipairs({"AUTO","MELEE","RANGED"}) do
    local choice=i;button(main,label,24+(i-1)*241,500,230,function() action("damage_style",choice) end,s.damage_style_choice==choice,"battle")
   end
   button(main,(s.show_hud and "ON" or "OFF").."  BATTLE HUD",24,546,350,function() action("hud",not s.show_hud) end,s.show_hud,"helm")
   button(main,(s.show_path and "ON" or "OFF").."  PATH OVERLAY",386,546,350,function() action("path",not s.show_path) end,s.show_path,"battle")
   text(main,"ArthasNav: "..compact((s.sentinel_provider and (s.sentinel_client and (s.sentinel_provider_kind or "client loaded") or "creating client") or "provider not loaded").." / "..tostring(s.sentinel_state or "not checked"),70),24,582,muted)
   text(main,"Path overlay is visual only; navigation remains active when hidden.",24,604,muted)
  elseif M.page==4 then
   button(main,"COPY REPORT",24,163,230,function() main:copy_to_clipboard(s.debug_report());M.notice="Debug report copied." end,false,"shield")
   button(main,"PREVIOUS",266,163,140,function() M.debug_offset=math.max(0,M.debug_offset-13) end)
   button(main,"NEXT",418,163,140,function() M.debug_offset=M.debug_offset+13 end)
   button(main,"CLEAR",570,163,166,function() action("clear_debugger");M.notice="Debug history cleared; controller unchanged." end,false,"skull")
   rect(main,24,213,712,314,panel)
   local rows=s.debug_rows and s.debug_rows() or {{"Debugger","No diagnostics available"}}
   M.debug_offset=math.min(M.debug_offset,math.max(0,#rows-13))
   local first=M.debug_offset+1;local last=math.min(#rows,first+12)
   for i=first,last do local row=rows[i];local line=i-first
    text(main,row[1],38,225+line*23,gold);text(main,compact(row[2],65),220,225+line*23,ink)
   end
   text(main,string.format("Diagnostics %d-%d of %d",#rows>0 and first or 0,last,#rows),24,540,muted)
  else
   button(main,"COPY WAR LOG",24,163,230,function() main:copy_to_clipboard(s.log_text());M.notice="War log copied." end,false,"skull")
   button(main,"LATEST",266,163,160,function() M.log_offset=0 end)
   button(main,"OLDER",438,163,142,function() M.log_offset=M.log_offset+8 end)
   button(main,"NEWER",592,163,144,function() M.log_offset=math.max(0,M.log_offset-8) end)
   rect(main,24,215,712,292,panel)
   local rows=s.log_rows or {};M.log_offset=math.min(M.log_offset,math.max(0,#rows-10))
   local first=math.max(1,#rows-9-M.log_offset)
   for i=first,math.min(#rows,first+9) do text(main,compact(rows[i],94),40,231+(i-first)*25,i==#rows and gold or muted) end
   if #rows==0 then text(main,"No battle events yet.",40,235,muted) end
  end
  block_controls=false
  if M.page==2 and M.queue_dropdown then
   rect(main,24,224,712,168,panel)
   for i,label in ipairs(s.queue_options or {"Random Battleground","Brawl","Epic Battleground","Battleground Blitz"}) do
    local choice=i
    button(main,label,28,228+(i-1)*40,704,function() action("queue_mode",choice);M.queue_dropdown=false end,s.queue_mode==i,"battle")
   end
  end
  text(main,compact(M.notice,85),24,624,gold);text(main,"v"..s.version,667,624,muted)
 end) end
 hud:set_visibility(s.show_hud)
 if s.show_hud then begin(hud,function()
  local status_color=status_style(s.status,s.enabled)
  rect(hud,8,8,344,48,panel);icon(hud,theme.spec_icon,20,18,28);text(hud,compact(theme.label,31),62,28,gold)
  text(hud,compact(readable(s.status),44),18,75,status_color)
  text(hud,compact(s.area or "Outside battleground",44),18,103)
  text(hud,"Objective: "..compact(plan.kind or "Waiting",30),18,131,muted)
  local route=s.route_total and s.route_total>0 and ("Route "..tostring(s.route_index).."/"..tostring(s.route_total)) or "Route: ArthasNav"
  if s.route_distance then route=route.."  "..string.format("%.0f yd",s.route_distance) end
  text(hud,compact(route,26).."  /  "..(s.role_label or "Damage"),18,158,muted)
  button(hud,"OPEN",18,190,98,function() M.open=true end,false,"helm")
  button(hud,"START",125,190,102,function() action("start") end,s.enabled)
  button(hud,"STOP",236,190,106,function() action("stop") end,false,nil,true)
 end) end
end
return M
