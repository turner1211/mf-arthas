-- MasterArthasNav command center. Tab artwork is embedded in panel_art.lua;
-- every foreground surface stays translucent so the art remains visible.
local V=require('common/geometry/vector_2')
local C=require('common/color')
local E=require('common/enums')
local Combat=require('anav/combat_hub')
local L=require('anav/i18n')
local M={open=false,page=1,size=2,art=true,notice='Ready. Choose a module or navigation tab.'}
local win,art_data,art_attempted,ui_data,ui_attempted,queue,last_refresh,drag,was_down
local textures,ui_textures,snapshot,position={},{icons={},buttons={}},{},{x=58,y=46}
local sizes={{820,590},{1024,690},{1180,760}}
local tabs={
 {key='COMMAND',title='COMMAND CENTER',sub='Battleground and leveling launch controls'},
 {key='COMBAT',title='COMBAT LOADOUT',sub='Automatic class, specialization, plugin and hotkey control'},
 {key='ROUTE',title='ROUTE CONTROL',sub='Live path control and navigation state'},
 {key='SAFETY',title='SAFETY & RECOVERY',sub='Watchdogs, replans and learned hazards'},
 {key='LOGS',title='DIAGNOSTICS',sub='Recovery report and customer support export'},
 {key='METRICS',title='PERFORMANCE',sub='Planner, bridge and recovery measurements'},
 {key='SETUP',title='SETUP & HELP',sub='Local companion installation and health checks'}}
local we=E.window_enums or E
local font=(we.font_id or {}).FONT_SMALL or 0
local function color(r,g,b,a)return C.new(r,g,b,a or 255)end
local GOLD=color(244,190,83);local ICE=color(109,224,255);local WHITE=color(240,245,248)
local MUTED=color(169,190,204);local GREEN=color(86,229,151);local RED=color(246,91,83)
local function text(w,s,x,y,col,max_width)
 local available=max_width or ((sizes[M.size]or sizes[2])[1]-x-16)
 local use_font=L.font_for(font)
 w:render_text(use_font,V.new(x,y),col or WHITE,L.fit(s,available,use_font,13))
end
local function box(w,x,y,width,height,col,r)w:render_rect_filled(V.new(x,y),V.new(x+width,y+height),col,r or 5)end
local function line(w,x1,y1,x2,y2,col,width)w:render_line(V.new(x1,y1),V.new(x2,y2),col,width or 1)end
local function short(s,n)return L.clip(L.text(s or'Unknown'),n)end
local function request(fn)if not queue then queue=fn end end
local function click(w,x,y,width,height)return w.is_rect_clicked and w:is_rect_clicked(V.new(x,y),V.new(x+width,y+height))end
local function hover(w,x,y,width,height)return w.is_mouse_hovering_rect and w:is_mouse_hovering_rect(V.new(x,y),V.new(x+width,y+height))end
local function load_ui(kind,index)
 if not ui_attempted then ui_attempted=true;local ok,data=pcall(require,'anav/ui_art');if ok then ui_data=data end end
 local bank=ui_data and ui_data[kind];local cache=ui_textures[kind]
 if bank and bank[index]and not cache[index]then local ok,id=pcall(core.graphics.load_texture,bank[index]);if ok then cache[index]=id end end
 return cache[index]
end
local function image(w,id,x,y,width,height,alpha)
 if not id then return false end;local p=w:get_position();core.graphics.draw_texture(id,V.new(p.x+x,p.y+y),width,height,color(255,255,255,alpha or 255),true);return true
end
local function icon(w,kind,x,y,col)
 local id=load_ui('icons',math.max(1,math.min(9,tonumber(kind)or 1)))
 if image(w,id,x-2,y-2,29,29,245)then return end
 col=col or ICE;line(w,x+3,y+21,x+21,y+3,col,3);box(w,x+1,y+18,7,7,GOLD,3);box(w,x+18,y+1,7,7,GOLD,3)
end
local function button(w,label,x,y,width,fn,selected,kind)
 local h=38;local hot=hover(w,x,y,width,h)
 local theme=selected and 1 or kind==3 and 2 or 3;local art_id=load_ui('buttons',theme)
 if not image(w,art_id,x,y,width,h,selected and 172 or hot and 145 or 112)then box(w,x,y,width,h,color(10,25,35,82),4)end
 box(w,x+4,y+4,width-8,h-8,selected and color(8,35,34,28)or color(2,9,13,38),4)
 if kind then icon(w,kind,x+10,y+7,selected and GOLD or ICE);text(w,label,x+43,y+13,selected and GOLD or WHITE,width-54)else text(w,label,x+13,y+13,selected and GOLD or WHITE,width-26)end
 if click(w,x,y,width,h)then fn()end
end
local function call(obj,key,...)
 if not obj or type(obj[key])~='function'then return nil,'Not available. Load the matching plugin first.'end
 return obj[key](...)
end
local function action(fn)
 request(function()
  local ok,result,reason=pcall(fn)
  M.notice=not ok and short(result,110)or result==false and short(reason or'Action unavailable',110)or type(result)=='string'and short(result,110)or'Command sent.'
 end)
end
local function client_action(method)
 action(function()
  local e=rawget(_G,'ArthasNavEnhancements');local s=e and e.status()
  if not s or not s.owner then return false,'No navigation owner. Start BG Player or the Leveler first.'end
  local client=e.get_client(s.owner);if not client or type(client[method])~='function'then return false,'Navigation client unavailable.'end
  client[method](client,'command_panel');return'Navigation '..method..' requested.'
 end)
end
local function refresh()
 local e=rawget(_G,'ArthasNavEnhancements')
 snapshot.nav=e and e.status()or{};snapshot.config=e and e.config or{};snapshot.overlay=e and e.overlay or false
 local nav=rawget(_G,'ArthasNav');local c=nav and nav.client
 snapshot.server=c and c:is_server_available()or false;snapshot.state=c and c:get_state()or'Client not loaded'
 snapshot.bg=call(rawget(_G,'SylvanasBattlegroundBot'),'get_status')or'Not loaded'
 snapshot.level=call(rawget(_G,'SylvanasAutoLeveler'),'status')or'Not loaded'
 snapshot.combat=Combat.refresh()
 if M.page==5 then snapshot.report=e and e.export_logs()or'Enhancements not loaded.'end
end
function M.update()
 L.refresh()
 if queue then local fn=queue;queue=nil;fn()end;if not M.open then return end
 local now=core.time();if not last_refresh or now-last_refresh>=.8 then last_refresh=now;local ok,err=pcall(refresh);if not ok then M.notice='Status read: '..short(err,90)end end
end
local function art(w,width,height,page)
 if not M.art then return end
 if not art_attempted then art_attempted=true;local ok,data=pcall(require,'anav/panel_art');if ok then art_data=data end end
 local source=type(art_data)=='table'and(art_data[page]or art_data.backgrounds and art_data.backgrounds[page])or page==1 and art_data
 if source and not textures[page]then local ok,id=pcall(core.graphics.load_texture,source);if ok then textures[page]=id end end
 if textures[page]then local p=w:get_position();core.graphics.draw_texture(textures[page],V.new(p.x,p.y+44),width,height-44,color(255,255,255,232),true)end
end
local function panel(w,x,y,width,height,title)
 box(w,x,y,width,height,color(4,14,21,62),5);box(w,x,y,width,30,color(8,23,31,96),5);text(w,title,x+12,y+10,GOLD)
end
local function row(w,label,value,x,y,width,value_col)
 text(w,label,x,y,MUTED,158);text(w,short(value,math.max(12,math.floor((width-168)/7))),x+168,y,value_col or WHITE,width-168)
end
local function pill(w,label,value,x,y,width,good)
 box(w,x,y,width,50,color(5,20,28,68),5);text(w,label,x+12,y+10,MUTED,width-24);text(w,value,x+12,y+29,good==true and GREEN or good==false and RED or GOLD,width-24)
end
local function module_card(w,x,y,width,title,summary,kind,fn,accent)
 box(w,x,y,width,134,color(5,18,27,62),6);box(w,x,y,4,134,accent or ICE,3);icon(w,kind,x+18,y+19,accent or ICE)
 text(w,title,x+54,y+20,GOLD);text(w,short(summary,math.floor((width-32)/7)),x+18,y+58,MUTED)
 button(w,'OPEN MODULE',x+18,y+86,width-36,fn,false,kind)
end
local function render_command(w,x,y,width)
 local gap=12;local half=math.floor((width-gap)/2)
 module_card(w,x,y,half,'BATTLEGROUND PLAYER',snapshot.bg,3,function()action(function()return call(rawget(_G,'SylvanasBattlegroundBot'),'show_window',true)end)end,RED)
 module_card(w,x+half+gap,y,half,'1-90 LEVELING',snapshot.level,1,function()action(function()return call(rawget(_G,'SylvanasAutoLeveler'),'show_window',true)end)end,GREEN)
 panel(w,x,y+148,width,158,'LOCAL NAVIGATION LINK')
 row(w,'Companion server',snapshot.server and'ONLINE / LOCAL'or'OFFLINE / WAITING',x+16,y+190,width-32,snapshot.server and GREEN or RED)
 row(w,'Active owner',(snapshot.nav or{}).owner or'None',x+16,y+218,width-32)
 row(w,'Route state',snapshot.state or'Waiting',x+16,y+246,width-32)
 row(w,'Recovery phase',(snapshot.nav or{}).phase or'Idle',x+16,y+274,width-32)
end
local function render_combat(w,x,y,width)
 local a=snapshot.combat or Combat.refresh();panel(w,x,y,width,104,'LIVE CHARACTER DETECTION')
 local half=math.floor((width-42)/2)
 pill(w,'CHARACTER',tostring(a.class_name or'Waiting'),x+14,y+40,half,a.class_id and a.class_id>0)
 pill(w,'SPECIALIZATION',tostring(a.spec_name or'Waiting'),x+28+half,y+40,half,a.supported)
 panel(w,x,y+118,width,236,'ACTIVE COMBAT PLUGIN')
 row(w,'Selected automatically',a.name or'No installed combat plugin',x+15,y+160,width-30,a.supported and GREEN or RED)
 if a.error then text(w,short(a.error,math.floor((width-34)/7)),x+15,y+184,GOLD)end
 local controls=a.controls or{};local shown=math.min(4,#controls)
 if shown==0 then
  box(w,x+15,y+215,width-30,62,color(5,18,27,72),5)
  text(w,a.supported and'Load the matching class plugin to expose its live controls.'or'No combat suite is installed for this class.',x+29,y+239,MUTED)
 else
  local bw=math.floor((width-42)/2)
  for i=1,shown do local item=controls[i];local col=(i-1)%2;local rown=math.floor((i-1)/2);local bx=x+14+col*(bw+14);local by=y+207+rown*47;local on=Combat.value(item)==true
   button(w,item.label..'  '..(on and'ON'or'OFF'),bx,by,bw,function()action(function()local value=Combat.toggle(item);return item.label..' '..(value and'enabled'or'disabled')end)end,on,3)
  end
 end
 panel(w,x,y+368,width,92,'LIVE HOTKEYS')
 if controls[1]then local first=controls[1];text(w,first.label,x+15,y+406,WHITE);text(w,Combat.hotkey(first),x+math.floor(width*.55),y+406,ICE)
  button(w,'CHANGE HOTKEY',x+width-174,y+392,158,function()action(function()return Combat.edit_hotkey(first)end)end,false,4)
 else text(w,'Hotkeys appear when the matching combat plugin is loaded.',x+15,y+406,MUTED)end
 text(w,'Class and specialization are checked continuously. Spec swaps update this page automatically.',x+15,y+446,MUTED)
end
local function render_route(w,x,y,width)
 local n=snapshot.nav or{};panel(w,x,y,width,142,'LIVE ROUTE');local third=math.floor((width-52)/3)
 pill(w,'OWNER',n.owner or'None',x+14,y+43,third,n.owner~=nil);pill(w,'PHASE',n.phase or'Idle',x+26+third,y+43,third)
 pill(w,'READINESS',n.readiness or'Not checked',x+38+third*2,y+43,third,n.readiness=='ready');row(w,'Movement mode',n.movement_mode or'Idle',x+14,y+108,width-28)
 panel(w,x,y+156,width,154,'ROUTE COMMANDS');local bw=math.floor((width-44)/3)
 button(w,'PAUSE',x+12,y+198,bw,function()client_action('pause')end,false,2)
 button(w,'RESUME',x+22+bw,y+198,bw,function()client_action('resume')end,false,2)
 button(w,'REPLAN',x+32+bw*2,y+198,bw,function()client_action('replan')end,false,2)
 button(w,'CHECK LOCAL CONNECTION',x+12,y+250,width-24,function()action(function()
  local e=rawget(_G,'ArthasNavEnhancements');if e and e.check_readiness then e.check_readiness()end
  local a=rawget(_G,'ArthasNav');if not a or not a.client then return false,'Client not loaded.'end
  a.client:health_check(function(ok)M.notice=ok and'Server connection healthy.'or'Server unavailable. Check the companion.'end);return'Checking local server...'
 end)end,false,1)
end
local function render_safety(w,x,y,width)
 local n=snapshot.nav or{};local cfg=snapshot.config or{};panel(w,x,y,width,322,'RECOVERY OPTIONS')
 button(w,'WORLD ROUTE OVERLAY  '..(snapshot.overlay and'ON'or'OFF'),x+14,y+44,width-28,function()action(function()local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.'end;e.set_overlay(not e.overlay);return'Overlay updated.'end)end,snapshot.overlay,3)
 button(w,'STALL WATCHDOG  '..tostring(cfg.stall_seconds or 8)..' SECONDS',x+14,y+92,width-28,function()action(function()
  local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.'end;local choices={6,8,12,16};local nv=8
  for i,v in ipairs(choices)do if v==e.config.stall_seconds then nv=choices[i%#choices+1]end end;e.config.stall_seconds=nv;return'Watchdog timing updated.'
 end)end,false,2)
 button(w,'MAXIMUM REPLANS  '..tostring(cfg.max_replans or 3),x+14,y+140,width-28,function()action(function()local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.'end;local v=tonumber(e.config.max_replans)or 3;e.config.max_replans=v>=5 and 1 or v+1;return'Maximum replans updated.'end)end,false,5)
 button(w,'REMEMBER TROUBLE SPOTS  '..(n.persistent and'ON'or'OFF'),x+14,y+188,width-28,function()action(function()
  local e=rawget(_G,'ArthasNavEnhancements');if not e or not e.set_persistent_history then return false,'Persistence unavailable.'end
  local ok,why=e.set_persistent_history(not e.status().persistent);if not ok then return false,why end;return why
 end)end,n.persistent,4)
 button(w,'BACKGROUND ARTWORK  '..(M.art and'ON'or'OFF'),x+14,y+236,width-28,function()M.art=not M.art end,M.art,1)
 text(w,'Learned hazards expire automatically. Recovery never changes bot combat settings.',x+15,y+292,MUTED)
end
local function render_logs(w,x,y,width,height)
 panel(w,x,y,width,height,'RECOVERY & SUPPORT REPORT');local bw=math.floor((width-38)/2)
 button(w,'CLEAR HISTORY',x+14,y+42,bw,function()action(function()local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.'end;e.reset_history();return'Learned stall history cleared.'end)end,false,4)
 button(w,'EXPORT REPORT (.MD)',x+24+bw,y+42,bw,function()action(function()local e=rawget(_G,'ArthasNavEnhancements');if not e or not e.save_report then return false,'Report unavailable.'end;local ok,why=e.save_report();if not ok then return false,why end;return why end)end,false,4)
 local lines={};for s in tostring(snapshot.report or'Waiting for status'):gmatch('[^\r\n]+')do lines[#lines+1]=s end
 local start=math.max(1,#lines-math.max(5,math.floor((height-124)/20))+1);box(w,x+14,y+94,width-28,height-108,color(2,10,15,76),4)
 for i=start,#lines do text(w,short(lines[i],math.floor((width-52)/7)),x+26,y+108+(i-start)*20,MUTED)end
end
local function render_metrics(w,x,y,width)
 local n=snapshot.nav or{};local p=n.performance or{};local b=p.bridge or{};panel(w,x,y,width,322,'LIVE NAVIGATION TELEMETRY')
 local rows={{'Guarded path queries',p.queries or 0},{'Planning mean / max',string.format('%.3fs / %.3fs',p.planning_mean or 0,p.planning_max or 0)},{'Bridge path requests',b.path_requests or'Not measured'},{'Bridge mean RPC',b.rpc_mean_ms and tostring(b.rpc_mean_ms)..' ms'or'Not measured'},{'Recovery verified / failed',tostring(p.recovery_verified or 0)..' / '..tostring(p.recovery_ineffective or 0)},{'Loops / target updates',tostring(p.loops or 0)..' / '..tostring(p.target_updates or 0)},{'Tile cache hits / misses',tostring(b.tile_cache_hits or'?')..' / '..tostring(b.tile_cache_misses or'?')},{'Priority / queue / confidence',tostring(n.priority or 0)..' / '..tostring(p.queue_depth or 0)..' / '..tostring(n.confidence or'?')}}
 for i,r in ipairs(rows)do row(w,r[1],r[2],x+16,y+34+i*31,width-32,i<3 and ICE or nil)end
end
local function render_setup(w,x,y,width)
 panel(w,x,y,width,362,'ONE-TIME COMPANION SETUP')
 local steps={'Install the separate ArthasNav companion package.','Run Install-ArthasNav.cmd once as the customer.','Keep MasterArthasNav beside BG Player and the 1-90 Leveler.','Start the desired bot from its own module panel.','The local helper supplies maps and path calculations automatically.'}
 for i,s in ipairs(steps)do box(w,x+15,y+30+i*44,26,26,color(22,62,76,220),13);text(w,i,x+24,y+40+i*44,GOLD);text(w,s,x+52,y+40+i*44,WHITE)end
 text(w,'CUSTOMER FOLDER: LUA + MARKDOWN ONLY',x+15,y+278,GREEN)
 local bw=math.floor((width-44)/2)
 button(w,L.text('Interface language')..': '..L.display_name(),x+15,y+306,bw,function()L.cycle()end,false,6)
 button(w,'TEST LOCAL COMPANION',x+29+bw,y+306,bw,function()M.page=3;M.notice='Use Check Local Connection in Route Control.'end,false,6)
end
local function render_content(w,x,y,width,height)
 if M.page==1 then render_command(w,x,y,width)elseif M.page==2 then render_combat(w,x,y,width)elseif M.page==3 then render_route(w,x,y,width)elseif M.page==4 then render_safety(w,x,y,width)elseif M.page==5 then render_logs(w,x,y,width,height)elseif M.page==6 then render_metrics(w,x,y,width)else render_setup(w,x,y,width)end
end
function M.render()
 if not M.open then if win then win:set_visibility(false)end;return end
 if not win then win=core.menu.window('arthas_nav_command_panel_v3');win:set_initial_position(V.new(position.x,position.y));win:set_initial_size(V.new(1024,690))end
 local screen=core.graphics.get_screen_size();local s=sizes[M.size];local width=math.min(s[1],screen.x-12);local height=math.min(s[2],screen.y-12)
 position.x=math.max(0,math.min(position.x,screen.x-width));position.y=math.max(0,math.min(position.y,screen.y-height))
 local cursor=core.get_cursor_position();local down=core.input.is_key_pressed(0x01)
 if cursor and down and not was_down and cursor.x>=position.x and cursor.x<position.x+width-55 and cursor.y>=position.y and cursor.y<position.y+44 then drag={x=cursor.x-position.x,y=cursor.y-position.y}end
 if drag and down and cursor then position.x=math.max(0,math.min(screen.x-width,cursor.x-drag.x));position.y=math.max(0,math.min(screen.y-height,cursor.y-drag.y))elseif not down then drag=nil end;was_down=down
 win:set_visibility(true);win:force_window_size(V.new(width,height));win:force_next_begin_window_pos(V.new(position.x,position.y))
 win:begin(0,false,color(4,10,16),GOLD,(we.window_cross_visuals or{}).NO_CROSS or 9,function()
  local w=win;art(w,width,height,M.page);box(w,0,0,width,44,color(4,12,19,184));box(w,0,43,width,2,GOLD,1)
  text(w,'MASTER ARTHAS NAV',18,15,GOLD);text(w,'FOREVER PATHFINDING COMMAND',174,15,ICE);button(w,'X',width-46,3,38,function()M.open=false end)
  local side=184;box(w,0,45,side,height-45,color(3,12,18,92));text(w,'NAVIGATION MODULES',15,67,MUTED)
  for i,t in ipairs(tabs)do button(w,t.key,12,94+(i-1)*48,side-24,function()M.page=i end,M.page==i,i)end
  box(w,12,height-117,side-24,78,color(3,17,23,68),5);text(w,'LOCAL LINK',24,height-101,MUTED)
  text(w,snapshot.server and'ONLINE'or'OFFLINE',24,height-78,snapshot.server and GREEN or RED);text(w,'BG + LEVELER READY',24,height-55,ICE)
  local cx=side+18;local cw=width-cx-18;box(w,cx,59,cw,78,color(3,14,20,62),5);icon(w,M.page,cx+16,77,GOLD)
  text(w,tabs[M.page].title,cx+53,76,GOLD);text(w,tabs[M.page].sub,cx+53,101,WHITE);render_content(w,cx,151,cw,height-213)
  box(w,side,height-46,width-side,46,color(3,13,19,86));text(w,short(M.notice,math.floor((width-side-34)/7)),side+16,height-29,ICE)
 end)
end
function M.setup()
 local toggle=core.menu.checkbox(false,'arthas_nav_command_panel_visible_v3')
 core.register_on_update_callback(function()M.open=toggle:get_state();local ok,err=pcall(M.update);if not ok then M.notice=short(err,100)end end)
 core.register_on_render_window_callback(function()local before=M.open;local ok,err=pcall(M.render);if before and not M.open then toggle:set(false)end;if not ok then M.notice=short(err,100);if core.log_error then core.log_error('ArthasNav panel: '..tostring(err))end end end)
 core.register_on_render_menu_callback(function()L.refresh();toggle:render(L.text('Open MasterArthasNav Command Center'),L.text('Tabbed navigation and auto-detected combat controls.'));Combat.render_menu()end)
end
return M
