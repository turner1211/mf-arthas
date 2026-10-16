-- Arthas command panel. Artwork is loaded only when this window is opened.
local V=require('common/geometry/vector_2')
local C=require('common/color')
local E=require('common/enums')
local M={open=false,page=1,size=2,art=false,notice='Ready. Choose a mode to open its controls.'}
local win,texture,art_attempted,queue,last_refresh,drag,was_down
local snapshot={}
local position={x=70,y=70}
local sizes={{760,560},{960,650},{1120,730}}
local pages={'COMMAND','NAVIGATION','OPTIONS','DIAGNOSTICS','PERFORMANCE','SETUP'}
local we=E.window_enums or E
local font=(we.font_id or {}).FONT_SMALL or 0
local function color(r,g,b,a) return C.new(r,g,b,a or 255) end
local gold=color(235,192,95)
local ice=color(125,209,242)
local white=color(230,237,244)
local muted=color(154,174,192)
local function text(w,s,x,y,col) w:render_text(font,V.new(x,y),col or white,tostring(s)) end
local function box(w,x,y,width,height,col) w:render_rect_filled(V.new(x,y),V.new(x+width,y+height),col,6) end
local function short(s,n) s=tostring(s or 'Unknown');return #s>n and s:sub(1,n-3)..'...' or s end
local function request(fn) if not queue then queue=fn end end
local function button(w,label,x,y,width,fn,selected)
 local hover=w:is_mouse_hovering_rect(V.new(x,y),V.new(x+width,y+36))
 box(w,x,y,width,36,selected and color(38,76,101) or hover and color(44,65,83) or color(25,39,54))
 box(w,x,y,3,36,selected and gold or ice)
 text(w,label,x+12,y+12,selected and gold or white)
 if w:is_rect_clicked(V.new(x,y),V.new(x+width,y+36)) then fn() end
end
local function call(obj,key,...)
 if not obj or type(obj[key])~='function' then return nil,'Not available. Load the matching plugin first.' end
 return obj[key](...)
end
local function action(fn)
 request(function()
  local ok,result,reason=pcall(fn)
  M.notice=not ok and short(result,95) or result==false and short(reason or 'Action unavailable',95) or type(result)=='string' and short(result,95) or 'Command sent.'
 end)
end
local function client_action(method)
 action(function()
  local e=rawget(_G,'ArthasNavEnhancements');local s=e and e.status()
  if not s or not s.owner then return false,'No navigation owner. Start BG Player or the Leveler first.' end
  local client=e.get_client(s.owner)
  if not client or type(client[method])~='function' then return false,'Navigation client unavailable.' end
  client[method](client,'command_panel');return 'Navigation '..method..' requested.'
 end)
end
local function refresh()
 local e=rawget(_G,'ArthasNavEnhancements')
 snapshot.nav=e and e.status() or {}
 snapshot.config=e and e.config or {}
 snapshot.overlay=e and e.overlay or false
 local nav=rawget(_G,'ArthasNav');local c=nav and nav.client
 snapshot.server=c and c:is_server_available() or false
 snapshot.state=c and c:get_state() or 'Client not loaded'
 snapshot.bg=call(rawget(_G,'SylvanasBattlegroundBot'),'get_status') or 'Not loaded'
 snapshot.level=call(rawget(_G,'SylvanasAutoLeveler'),'status') or 'Not loaded'
 if M.page==4 then snapshot.report=e and e.export_logs() or 'Enhancements not loaded.' end
end
function M.update()
 if queue then local fn=queue;queue=nil;fn() end
 if not M.open then return end
 local now=core.time()
 if not last_refresh or now-last_refresh>=1.0 then
  last_refresh=now;local ok,err=pcall(refresh)
  if not ok then M.notice='Status read: '..short(err,85) end
 end
end
local function artwork(w,width)
 if not M.art then return end
 if not art_attempted then
  art_attempted=true
  local ok,data=pcall(require,'anav/panel_art')
  if ok then local loaded,id=pcall(core.graphics.load_texture,data);if loaded then texture=id end end
 end
 if texture then
  local p=w:get_position()
  core.graphics.draw_texture(texture,V.new(p.x,p.y+42),width,math.floor(width*0.562),color(255,255,255,110),true)
 end
end
local function icon(w,x,y,quest)
 if quest then
  box(w,x+12,y,7,20,gold);box(w,x+12,y+25,7,7,gold)
 else
  w:render_line(V.new(x+4,y+30),V.new(x+27,y+2),ice,3)
  w:render_line(V.new(x+3,y+18),V.new(x+19,y+31),gold,3)
 end
end
local function card(w,x,y,width,title,body,quest)
 box(w,x,y,width,100,color(12,24,37,238));icon(w,x+14,y+20,quest)
 text(w,title,x+54,y+20,gold);text(w,short(body,math.floor((width-70)/7)),x+54,y+48)
end
local function row(w,label,value,x,y,width)
 text(w,label,x,y,muted);text(w,short(value,math.floor((width-175)/7)),x+175,y,white)
end
local function render_content(w,x,y,width,height)
 local nav=snapshot.nav or {};local config=snapshot.config or {}
 if M.page==1 then
  local half=math.floor((width-14)/2)
  card(w,x,y,half,'BATTLEGROUND COMMAND',snapshot.bg,false)
  card(w,x+half+14,y,half,'1-90 QUESTING',snapshot.level,true)
  button(w,'Open BG Player',x,y+110,half,function() action(function() return call(rawget(_G,'SylvanasBattlegroundBot'),'show_window',true) end) end)
  button(w,'Open 1-90 Leveler',x+half+14,y+110,half,function() action(function() return call(rawget(_G,'SylvanasAutoLeveler'),'show_window',true) end) end)
  box(w,x,y+166,width,144,color(12,24,37,240))
  text(w,'LOCAL NAVIGATION LINK',x+18,y+184,ice)
  row(w,'Server',snapshot.server and 'Online / local only' or 'Offline / awaiting companion',x+18,y+214,width-36)
  row(w,'Active owner',nav.owner or 'None',x+18,y+240,width-36)
  row(w,'Route state',snapshot.state or 'Waiting',x+18,y+266,width-36)
  text(w,'Start your bot from its own panel; navigation starts automatically.',x+4,y+330,muted)
 elseif M.page==2 then
  text(w,'ROUTE CONTROL',x,y,ice)
  row(w,'Owner',nav.owner or 'None',x,y+40,width)
  row(w,'Recovery phase',nav.phase or 'Idle',x,y+68,width)
  row(w,'Readiness',nav.readiness or 'Not checked',x,y+96,width)
  local bw=math.floor((width-20)/3)
  button(w,'Pause route',x,y+140,bw,function() client_action('pause') end)
  button(w,'Resume route',x+bw+10,y+140,bw,function() client_action('resume') end)
  button(w,'Replan route',x+2*(bw+10),y+140,bw,function() client_action('replan') end)
  button(w,'Check connection',x,y+194,width,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if e and e.check_readiness then e.check_readiness() end
   local n=rawget(_G,'ArthasNav');if not n or not n.client then return false,'Client not loaded.' end
   n.client:health_check(function(ok) M.notice=ok and 'Server connection healthy.' or 'Server unavailable. Check the companion installer.' end)
   return 'Checking local server...'
  end) end)
  text(w,'Route controls affect the current navigation owner.',x,y+256,muted)
  text(w,'Use the bot panel to stop automation completely.',x,y+282,muted)
  row(w,'Safety / route score',tostring(nav.safety or 'Clear')..' / '..(nav.route_score and string.format('%.1f',nav.route_score) or 'Pending'),x,y+312,width)
 elseif M.page==3 then
  text(w,'DISPLAY & RECOVERY',x,y,ice)
  button(w,'Window: '..({'Compact','Standard','Large'})[M.size],x,y+42,width,function() M.size=M.size%3+1 end)
  button(w,'Background artwork: '..(M.art and 'ON' or 'OFF'),x,y+90,width,function() M.art=not M.art end)
  button(w,'Navigation overlay: '..(snapshot.overlay and 'ON' or 'OFF'),x,y+138,width,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.' end
   e.set_overlay(not e.overlay);return 'Overlay updated.'
  end) end)
  button(w,'Stall watchdog: '..tostring(config.stall_seconds or 8)..' seconds',x,y+186,width,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.' end
   local choices={8,12,16};local current=e.config.stall_seconds;local next_value=8
   for i,v in ipairs(choices) do if v==current then next_value=choices[i%#choices+1] end end
   e.config.stall_seconds=next_value;return 'Watchdog timing updated.'
  end) end)
  button(w,'Remember trouble spots: '..(nav.persistent and 'ON' or 'OFF'),x,y+234,width,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if not e or not e.set_persistent_history then return false,'Persistence unavailable.' end
   local ok,why=e.set_persistent_history(not e.status().persistent);if not ok then return false,why end;return why
  end) end)
  text(w,'Saved trouble spots expire; display settings reset on reload.',x,y+290,muted)
 elseif M.page==4 then
  text(w,'RECOVERY REPORT',x,y,ice)
  local bw=math.floor((width-12)/2)
  button(w,'Clear failure history',x,y+36,bw,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if not e then return false,'Enhancements unavailable.' end
   e.reset_history();return 'Learned stall history cleared.'
  end) end)
  button(w,'Export bug report (.md)',x+bw+12,y+36,bw,function() action(function()
   local e=rawget(_G,'ArthasNavEnhancements');if not e or not e.save_report then return false,'Report unavailable.' end
   local ok,why=e.save_report();if not ok then return false,why end;return why
  end) end)
  local lines={};for line in tostring(snapshot.report or 'Waiting for status'):gmatch('[^\r\n]+') do lines[#lines+1]=line end
  local count=math.max(1,math.floor((height-126)/22))
  for i=math.max(1,#lines-count+1),#lines do text(w,short(lines[i],math.floor(width/7)),x,y+92+(i-math.max(1,#lines-count+1))*22,muted) end
 elseif M.page==5 then
  text(w,'NAVIGATION PERFORMANCE',x,y,ice)
  local p=nav.performance or {};local bridge=p.bridge or {}
  local rows={
   {'Guarded path queries',p.queries or 0},
   {'Planning mean / max',string.format('%.3fs / %.3fs',p.planning_mean or 0,p.planning_max or 0)},
   {'Bridge path requests',bridge.path_requests or 'Not measured yet'},
   {'Bridge mean RPC time',bridge.rpc_mean_ms and tostring(bridge.rpc_mean_ms)..' ms' or 'Not measured yet'},
   {'Recovery verified / failed',tostring(p.recovery_verified or 0)..' / '..tostring(p.recovery_ineffective or 0)},
   {'Loops / target updates',tostring(p.loops or 0)..' / '..tostring(p.target_updates or 0)},
   {'Tile-cache hits / misses',tostring(bridge.tile_cache_hits or '?')..' / '..tostring(bridge.tile_cache_misses or '?')},
   {'Priority / queued / confidence',tostring(nav.priority or 0)..' / '..tostring(p.queue_depth or 0)..' / '..tostring(nav.confidence or '?')}}
  for i,r in ipairs(rows) do row(w,r[1],r[2],x,y+25+i*29,width) end
  text(w,'Bridge samples refresh during navigation, about every 10 seconds.',x,y+300,muted)
 else
  text(w,'ONE-TIME COMPANION SETUP',x,y,gold)
  local lines={
   '1. Extract the separate ArthasNav companion installer package.',
   '2. Run Install-ArthasNav.cmd and complete its installation.',
   '3. Install this Lua library in PS alongside BG Player / Leveler.',
   '4. Start the desired bot from its own command panel.',
   '5. The installed helper starts the local server automatically.',
   '',
   'PS upload: Lua and Markdown only.',
   'The native server and map files belong to the companion installer.',
   'If offline: verify the helper is running and maps are installed.',
   'Report bugs in the arthas channel on the PS Discord.',
   'Use Diagnostics > Export bug report; attach it in arthas.'}
  for i,line in ipairs(lines) do text(w,short(line,math.floor(width/7)),x,y+34+i*25,muted) end
 end
end
function M.render()
 if not M.open then if win then win:set_visibility(false) end;return end
 if not win then
  win=core.menu.window('arthas_nav_command_panel_v2')
  win:set_initial_position(V.new(position.x,position.y));win:set_initial_size(V.new(960,650))
 end
 local screen=core.graphics.get_screen_size();local s=sizes[M.size]
 local width=math.min(s[1],screen.x-12);local height=math.min(s[2],screen.y-12)
 position.x=math.max(0,math.min(position.x,screen.x-width));position.y=math.max(0,math.min(position.y,screen.y-height))
 local cursor=core.get_cursor_position();local down=core.input.is_key_pressed(0x01)
 if cursor and down and not was_down and cursor.x>=position.x and cursor.x<position.x+width-65 and cursor.y>=position.y and cursor.y<position.y+42 then drag={x=cursor.x-position.x,y=cursor.y-position.y} end
 if drag and down and cursor then position.x=math.max(0,math.min(screen.x-width,cursor.x-drag.x));position.y=math.max(0,math.min(screen.y-height,cursor.y-drag.y)) elseif not down then drag=nil end
 was_down=down
 win:set_visibility(true);win:force_window_size(V.new(width,height));win:force_next_begin_window_pos(V.new(position.x,position.y))
 win:begin(0,false,color(9,17,28),gold,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  local w=win
  artwork(w,width)
  box(w,0,0,width,42,color(10,20,32));text(w,'ARTHAS NAV  /  BATTLEFIELD & QUEST COMMAND',18,15,gold)
  button(w,'X',width-48,3,40,function() M.open=false end)
  box(w,0,42,176,height-42,color(10,19,30,245))
  text(w,'PROJECT SYLVANAS',16,68,ice)
  for i,label in ipairs(pages) do button(w,label,12,106+(i-1)*50,152,function() M.page=i end,M.page==i) end
  text(w,'BG PLAYER',18,height-95,gold);text(w,'1-90 LEVELER',18,height-70,ice)
  box(w,190,168,width-204,height-218,color(10,20,31,232))
  text(w,'FOR THE BATTLE. FOR THE JOURNEY.',208,115,gold)
  render_content(w,208,184,width-240,height-240)
  box(w,176,height-42,width-176,42,color(10,20,32));text(w,short(M.notice,math.floor((width-208)/7)),192,height-27,ice)
 end)
end
function M.setup()
 local toggle=core.menu.checkbox(false,'arthas_nav_command_panel_visible')
 core.register_on_update_callback(function()
  M.open=toggle:get_state();local ok,err=pcall(M.update);if not ok then M.notice=short(err,95) end
 end)
 core.register_on_render_window_callback(function()
  local before=M.open;local ok,err=pcall(M.render)
  if before and not M.open then toggle:set(false) end
  if not ok then M.notice=short(err,95);if core.log_error then core.log_error('ArthasNav panel: '..tostring(err)) end end
 end)
 core.register_on_render_menu_callback(function() toggle:render('Open ArthasNav Command Panel','Battleground / 1-90 themed navigation controls, options and setup.') end)
end
return M
