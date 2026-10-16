local C,Modes,U=require('sm_settings'),require('sm_modes'),require('sm_util')
local Icons,Art,Buttons=require('sm_icons'),require('sm_art'),require('sm_buttons')
local G={page=1,offset=0,scope=nil,editing=nil,error=nil,info_offset=0,f1_down=false,binding=nil};local window
local W,H=1000,760
local wx,wy=70,70;local dragging,mouse_was_down,last_wheel=nil,false,-math.huge
local VERSION=require('sm_version')
local themes={
 [62]={name='ARCANE',hero='MEDIVH — THE CORRUPTED GUARDIAN',tag='MANA / SALVO / TRANSCENDENCE',accent={192,144,255},dark={22,13,44},metal={178,151,230},hover={59,30,98},icon='arcane'},
 [63]={name='FIRE',hero="KAEL'THAS — THE SUN KING",tag='IGNITE / COMBUSTION / REBIRTH',accent={255,166,73},dark={40,14,12},metal={223,147,71},hover={99,35,18},icon='fire'},
 [64]={name='FROST',hero='JAINA — THE LORD ADMIRAL',tag='FREEZING / SHATTER / CONTROL',accent={116,222,255},dark={9,24,42},metal={153,206,235},hover={24,63,93},icon='frost'}
}
local pages={{'GENERAL','arcane'},{'BURST','burst'},{'CONTROL','control'},{'PEELING','frost'},{'DEFENSE','shield'},{'UTILITY','rune'},{'SPEC','fire'},{'HOTKEYS','projectile'},{'DISPLAY / LOGS','eye'},{'DPS GUIDE','trophy'},{'INFORMATION','rune'}}
local option_icons={arcane_salvo='projectile',arcane_prismatic='arcane',arcane_missiles='projectile',arcane_recovery='heal',arcane_reserve='burst',
 fire_hot_streak='burst',fire_blast='projectile',fire_pyroclasm='rune',fire_meteor='projectile',fire_flamestrike='fire',frost_freezing='frost',frost_orb='burst',frost_blizzard='rune',frost_spike='projectile',frost_ray='eye',frost_ice_nova='control',frost_cone='frost',frost_cold_snap='shield',temporal_defense='rune',invisibility_defense='eye'}
local notes={arcane_images='Arcane talent-based damage smoothing only',enabled='Only this specialization and activity',damage='Current mage priorities for this profile',
 cooldowns='Major offensive abilities in permitted windows',aoe='Protect crowd control and avoid fresh pulls',
 priority_interrupts='Reserve Counterspell for dangerous casts',automatic_burst='Automatic PvP kill windows for this profile',interrupts='Live cast identity checked before Counterspell',
 arena_control='Clean healer and known DR; Arena only',purge='Confirmed magic buff; never guess hidden auras',
 automatic_peeling='All PvP modes; roots and slows confirmed melee pressure',defensive_control='Clean disruptive DPS attacking a critical teammate',temporal_defense='Alter Time only before ranged burst; never during a close melee escape',invisibility_defense='All specs; critical confirmed PvP burst only',pvp_roots='Known DR and immunity for all nearby enemies',pvp_slow='Arcane only; confirmed unslowed opponent',
 remove_curse='Confirmed Curse; PvP healer and critical-target triage',intellect='Maintain Arcane Intellect with refresh throttle',
 timer_defensives='Known BigWigs or ExBoss pressure',heal_hp='Arcane only; requires Refractive Images talent',low_hp='Spec barrier health threshold',turtle_hp='Emergency immunity threshold',
 interrupt_percent='How far an enemy cast must progress',cooldown_min_ttd='Save burst on nearly defeated enemies',cooldown_min_enemies='Mythic+ pack threshold',
 arcane_salvo='Hero-specific Salvo thresholds for Barrage',arcane_prismatic='Only verified Arcane Blast replacement',arcane_missiles='Clearcasting only; preserve complete channels',arcane_recovery='Evocation outside Surge and Touch windows',arcane_reserve='Mana conservation threshold outside burst',
 fire_hot_streak='Spend before converting another Heating Up',fire_blast='Confirmed Heating Up; supports cast weaving',fire_pyroclasm='Use empowered Pyroblast or Flamestrike',fire_meteor='Safe Meteor during permitted PvP windows',fire_flamestrike='Minimum 3 targets; Fuel the Fire required',
 frost_freezing='6 Spellslinger / 12 Frostfire Freezing stacks',frost_orb='Clear path; hold PvP Orb for burst permission',frost_blizzard='Hero and talent dependent target thresholds',frost_spike='Current proc or 5 Icicles',frost_ray='Complete channels; avoid PvP focus pressure',
 frost_ice_nova='Safe target burst or known-DR PvP root fallback',frost_cone='Frost PvE only; face a safe close pack',frost_cold_snap='Reset Ice Block only in a verified Frost emergency'}
local function value(w)
 if not w then return nil end
 if w.get_state then return w:get_state() end
 if w.get then return w:get() end
end
local function put(w,v)if w and w.set then w:set(v)end end
local function begin_binding(spec,mode,key)
 G.binding={spec=spec,mode=mode,key=key};C.hotkey_status='Press a key for '..C.label(spec,key)..' — ESC clears'
end
local function capture_binding()
 if not G.binding or not core.input or type(core.input.is_key_pressed)~='function'then return end
 for code=8,255 do local ok,down=pcall(core.input.is_key_pressed,code);if ok and down then
  local b=G.binding
  if code==27 then C.assign_hotkey(b.spec,b.mode,b.key,0)
  elseif code==0x70 or code==0x76 then C.hotkey_status=C.key_name(code)..' is reserved for a Mage window'
  else C.assign_hotkey(b.spec,b.mode,b.key,code)end
  G.binding=nil;return
 end end
end
local function mouse_wheel_delta()
 local candidates={core.input and core.input.get_mouse_wheel_delta,core.get_mouse_wheel_delta,core.graphics and core.graphics.get_mouse_wheel_delta}
 for _,fn in pairs(candidates)do if type(fn)=='function'then local ok,v=pcall(fn);if ok and type(v)=='number'and v~=0 then return v end end end
 return 0
end
local function render_window()
 local player=core and core.object_manager and U.fn(core.object_manager.get_local_player)
 if not U.valid(player) or U.number(U.call(player,'get_class'))~=8 then
  if window then window:set_visibility(false)end
  if dragging and core.graphics and type(core.graphics.set_mouse_capture_state)=='function'then pcall(core.graphics.set_mouse_capture_state,false)end
  dragging=nil;mouse_was_down=false;G.f1_down=false
  return
 end
 if not C.themed_gui or not C.themed_gui:get_state() or not core.menu.window then if window then window:set_visibility(false)end;return end
 local Color,V,Enums=require('common/color'),require('common/geometry/vector_2'),require('common/enums')
 -- Visual fallback is never written into the combat identity or live mode.
 local live_id=C.identity and themes[C.identity.id] and C.identity.id or nil
 if live_id then G.last_spec=live_id end
 local visual_id=live_id or G.last_spec or 62
 local theme=themes[visual_id]
 local live_mode=Modes.labels[C.mode] and C.mode or nil
 local live_label=live_id and live_mode and Modes.labels[live_mode] or 'Waiting for detection'
 local scope=tostring(live_id)..':'..tostring(live_mode)
 if G.scope~=scope then
  G.scope=scope;G.editing=live_mode or G.editing or 'world_pve';G.edit_spec=live_id or G.edit_spec or visual_id
  G.offset=0;G.page=live_id and live_mode and 1 or 11;G.info_offset=0
 end
 -- The options panel is locked to the detected specialization. There is no
 -- cross-spec selector and an inactive spec can never be displayed or edited.
 G.edit_spec=live_id or visual_id
 local we=Enums.window_enums or Enums;local fonts=we.font_id or {};local small,big=fonts.FONT_SMALL or 7,fonts.FONT_BIG or 8
 local function col(r,g,b,a)return Color.new(r,g,b,a or 255)end
 local accent=col(theme.accent[1],theme.accent[2],theme.accent[3]);local muted=col(182,195,202)
 local dark=col(theme.dark[1],theme.dark[2],theme.dark[3],245);local white=col(240,246,245)
 if not window then
  window=core.menu.window('sylvanas_mage_command');window:set_initial_position(V.new(wx,wy));window:set_initial_size(V.new(W,H))
  if window.set_render_layer then window:set_render_layer(1)end
 end
 local cursor=type(core.get_cursor_position)=='function'and core.get_cursor_position()or nil
 local mouse=false;if core.input and type(core.input.is_key_pressed)=='function'then local ok,v=pcall(core.input.is_key_pressed,0x01);mouse=ok and v==true end
 if cursor and mouse and not mouse_was_down and cursor.x>=wx and cursor.x<=wx+W and cursor.y>=wy and cursor.y<=wy+104 then
  dragging={x=cursor.x-wx,y=cursor.y-wy}
  if core.graphics and type(core.graphics.capture_next_mouse_input)=='function'then pcall(core.graphics.capture_next_mouse_input)end
 end
 if dragging and mouse and cursor then
  local sw,sh=1920,1080;if core.graphics and type(core.graphics.get_screen_size)=='function'then local ok,s=pcall(core.graphics.get_screen_size);if ok and s then sw,sh=s.x or sw,s.y or sh end end
  wx=math.max(0,math.min(math.max(0,sw-W),cursor.x-dragging.x));wy=math.max(0,math.min(math.max(0,sh-H),cursor.y-dragging.y))
  if core.graphics and type(core.graphics.set_mouse_capture_state)=='function'then pcall(core.graphics.set_mouse_capture_state,true)end
 elseif dragging and not mouse then
  dragging=nil
  if core.graphics and type(core.graphics.set_mouse_capture_state)=='function'then pcall(core.graphics.set_mouse_capture_state,false)end
 end;mouse_was_down=mouse
 window:set_visibility(true);if window.force_window_size then window:force_window_size(V.new(W,H))end
 if window.set_next_window_min_size then window:set_next_window_min_size(V.new(W,H))end
 if window.force_next_begin_window_pos then window:force_next_begin_window_pos(V.new(wx,wy))end
 local function rect(x,y,w,h,c,r)window:render_rect_filled(V.new(x,y),V.new(x+w,y+h),c,r or 4)end
 local function outline(x,y,w,h,c,r,t)if window.render_rect then window:render_rect(V.new(x,y),V.new(x+w,y+h),c,r or 4,t or 1)end end
 local function text(s,x,y,size,c)
  if window.render_text_custom_size then window:render_text_custom_size(small,V.new(x,y),c or white,size or 14,tostring(s))
  else window:render_text(size and size>=20 and big or small,V.new(x,y),c or white,tostring(s))end
 end
 local function button(label,x,y,w,h,fn,active,icon)
  local hover=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(x,y),V.new(x+w,y+h))
  Buttons.draw(window,V,Color,theme,visual_id,x,y,w,h,active,hover)
  local offset=10;if icon then Icons.draw(icon,window,x+5,y+4,h-8,accent,visual_id);offset=h+5 end
  local size=(w<80 and #label>5) and 11 or w>=200 and 15 or 14
  text(label,x+offset,y+(h-size)/2-1,size,active and w<100 and col(12,24,16) or white)
  if window:is_rect_clicked(V.new(x,y),V.new(x+w,y+h))then fn()end
 end
 local function hotkey_button(spec,mode,key,x,y)
  local hk=C.hotkey(spec,mode,key);if not hk then return end
  local code=hk.code:get();local enabled=hk.enabled:get_state()
  button((enabled and C.key_name(code)or'HOTKEY'),x,y,100,27,function()begin_binding(spec,mode,key)end,enabled,'projectile')
 end
 local function global_row(label,note,key,y,icon)
  local widget=C[key];rect(414,y,558,52,col(17,24,31,255));Icons.draw(icon,window,423,y+7,38,accent,visual_id)
  text(label,473,y+6,15);text(note:sub(1,45),473,y+28,12,muted)
  hotkey_button(nil,nil,key,800,y+12)
  button(value(widget) and 'ON' or 'OFF',908,y+12,52,27,function()put(widget,not value(widget))end,value(widget))
 end
 window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,col(9,13,17),accent,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  if not Art.draw(visual_id,window,W,H)then
   rect(0,0,W,H,dark,0);Icons.draw(theme.icon,window,74,234,218,accent,visual_id)
   text(theme.hero,40,520,22,accent);text('Native mage emblems',40,554,13,muted)
  end
  outline(10,10,W-20,H-20,accent,6,1)
  rect(500,20,474,83,col(10,14,20,250),7);outline(500,20,474,83,col(theme.accent[1],theme.accent[2],theme.accent[3],150),7,1)
  text(live_id and theme.name..' MAGE' or 'MAGE / DETECTING',518,29,24);text(theme.hero,519,62,14,accent)
  text('F1 OPEN/CLOSE  |  DRAG HEADER  |  WHEEL TO PAGE',519,84,11,muted)
  rect(398,110,576,64,col(12,16,22,250))
  text('LIVE: '..live_label,414,119,14);text('EDIT: '..(Modes.labels[G.editing] or G.editing),626,119,14)
  text('Auto spec and activity',414,146,12,muted)
  button(C.enabled:get_state() and 'ON' or 'OFF',844,121,55,26,function()C.enabled:set(not C.enabled:get_state())end,C.enabled:get_state())
  button(C.pause:get_state() and 'RESUME' or 'PAUSE',908,121,55,26,function()C.pause:set(not C.pause:get_state())end,C.pause:get_state())
  if live_id and live_mode and Modes.pvp[live_mode]then
   local automatic=C.value(visual_id,C.mode,'automatic_burst')==true
   button(C.burst:get_state() and 'BURST ON' or automatic and 'BURST AUTO' or 'BURST HELD',844,150,119,21,function()C.burst:set(not C.burst:get_state())end,C.burst:get_state() or automatic)
  end
  rect(18,178,964,126,col(10,15,21,246))
  for i,page in ipairs(pages)do
   local x,y=22+((i-1)%4)*242,184+math.floor((i-1)/4)*39
   button(page[1],x,y,233,34,function()
    G.page=i;G.offset=0
   end,G.page==i,(i==1 or i==7) and theme.icon or page[2])
  end
  rect(402,312,572,390,col(7,11,17,249),7);text(G.page==7 and themes[G.edit_spec].name..' ROTATION' or pages[G.page][1],419,320,19,white)
  if G.page<=7 then
   local modes=Modes.order
   local labels={world_pve='WORLD PVE',dungeon='DUNGEON',mythic_plus='MYTHIC+',raid='RAID',delve='DELVE',arena='ARENA',battleground='BGS',world_pvp='WORLD PVP'}
   for i,mode in ipairs(modes)do
    local x,y=416+((i-1)%4)*137,351+math.floor((i-1)/4)*30
    button(labels[mode],x,y,130,25,function()G.editing=mode;G.offset=0 end,G.editing==mode)
   end
   text('EDIT '..themes[G.edit_spec].name..' / '..(Modes.labels[G.editing] or G.editing),419,412,13,accent)
   local spec,mode=G.edit_spec,G.editing;local list=C.gui_groups(spec,mode,G.page)
   for i=G.offset+1,math.min(#list,G.offset+5)do
    local key=list[i];local widget=C.control(spec,mode,key);local y=434+(i-G.offset-1)*48
    if widget then
     local row_hover=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(414,y),V.new(972,y+48))
     rect(414,y,558,44,row_hover and col(theme.hover[1],theme.hover[2],theme.hover[3],250)or col(17,24,31,255))
     local icon=option_icons[key] or (key=='interrupts' or key=='interrupt_percent') and 'rune' or (key=='arena_control') and 'control' or key:find('hp') and 'heal' or key:find('defensive') and 'shield' or key=='cooldowns' and 'rune' or theme.icon
     Icons.draw(icon,window,423,y+5,38,accent,visual_id)
     text(C.label(spec,key):gsub(' health %%',' %%'),473,y+3,14);text((notes[key] or 'This activity only'):sub(1,43),473,y+24,11,muted)
     if window.render_tooltip_default and window:is_mouse_hovering_rect(V.new(414,y),V.new(790,y+44))then window:render_tooltip_default(C.label(spec,key)..'\n'..(notes[key] or 'Only this specialization and activity'))end
     local state=value(widget)
     if type(state)=='boolean'then
      hotkey_button(spec,mode,key,800,y+8)
      button(state and 'ON' or 'OFF',908,y+8,52,27,function()put(widget,not value(widget))end,state)
      if window:is_rect_clicked(V.new(414,y),V.new(790,y+44))then put(widget,not value(widget))end
     else
      button('-',847,y+8,28,27,function()put(widget,math.max(0,value(widget)-1))end)
      text(state,884,y+14,13,accent);button('+',932,y+8,28,27,function()put(widget,math.min(100,value(widget)+1))end)
      rect(847,y+39,113,3,col(64,70,60),1);rect(847,y+39,113*state/100,3,accent,1)
      if window:is_rect_clicked(V.new(847,y+36),V.new(960,y+44)) and core.get_cursor_position and window.get_position then
       local cursor,origin=core.get_cursor_position(),window:get_position()
       if cursor and origin then put(widget,math.floor(math.max(0,math.min(100,(cursor.x-origin.x-847)/113*100))+0.5))end
      end
     end
    end
   end
   local wheel=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(402,312),V.new(974,702))and mouse_wheel_delta()or 0
   local tick=type(core.time)=='function'and core.time()or 0
   if wheel~=0 and tick-last_wheel>0.08 then G.offset=math.max(0,math.min(math.max(0,#list-5),G.offset+(wheel<0 and 5 or -5)));last_wheel=tick end
   if #list>5 then
    button('PREVIOUS',416,674,115,22,function()G.offset=math.max(0,G.offset-5)end)
    button('NEXT',538,674,86,22,function()if G.offset+5<#list then G.offset=G.offset+5 end end)
    text((G.offset+1)..'-'..math.min(#list,G.offset+5)..' / '..#list,900,679,11,muted)
   end
  elseif G.page==8 then
   global_row('Enable option hotkeys','Master switch for all saved feature hotkeys','hotkeys_enabled',350,'projectile')
   text('Every boolean option has its own HOTKEY button.',420,420,14,white)
   text('Open any feature tab, click HOTKEY, then press a key.',420,447,13,muted)
   text('ESC clears a binding. F1 and F7 remain reserved.',420,472,13,muted)
   text('Only the detected spec and activity can receive input.',420,497,13,accent)
   rect(414,538,548,58,col(17,24,31,255));text('STATUS',427,548,12,muted);text(C.hotkey_status:sub(1,67),427,570,13,accent)
   if G.binding then text('WAITING FOR KEY: '..C.label(G.binding.spec,G.binding.key),420,624,14,accent)end
  elseif G.page==9 then
   global_row('Mage command window','Show this custom Mage menu','themed_gui',344,'eye')
   global_row('DPS overlay and boss coach','Current decision and encounter guidance','boss_guide',400,'trophy')
   global_row('Detailed combat logs','Persistent sessions; errors always recorded','logging',456,'eye')
   global_row('Training dummy testing','Target a recognized city dummy to start','dummy_test',512,'trophy')
   local logger=require('sm_log');text(logger.status:sub(1,70),420,574,12,accent)
   button('COPY CURRENT LOG',416,602,260,32,function()logger.copy(window,false,C.log_copy)end,false,'eye')
   button('COPY PREVIOUS LOG',691,602,270,32,function()logger.copy(window,true,C.log_copy)end,false,'eye')
   text((logger.copy_status or 'Copy the log, then paste it into our chat.'):sub(1,75),420,642,12,muted)
   text(('Log file: scripts_log/'..tostring(logger.path or 'sylvanas_mage/')):sub(1,74),420,670,11,muted)
  elseif G.page==10 then
   global_row('PvP burst permission','Allow major offensive cooldowns in PvP','burst',350,'rune')
   global_row('DPS boss helper','All three specs; PvE activities only','boss_guide',406,'trophy')
   text('LIVE COACH',420,476,16,accent);local coach=require('sm_dps_boss_guides');local status=live_id and live_mode and (coach.active and coach.status or C.gameplay or coach.status) or 'Waiting for confirmed spec and activity. Combat coaching will resume after detection.'
   for i=1,3 do text(status:sub((i-1)*66+1,i*66),420,506+(i-1)*22,12)end
   local hint=visual_id==62 and 'Watch Salvo and mana. Align Surge with Touch.' or visual_id==63 and 'Spend Hot Streak. Convert Heating Up. Protect Combustion.' or 'Spend Freezing stacks. Preserve procs during movement.'
   text(hint,420,606,12,accent);text('Live profile: '..(live_id and theme.name or 'UNKNOWN')..' / '..live_label,420,645,11,muted)
  else
    text('PROJECT SYLVANAS MENU',420,348,16,accent)
    text('LIVE: '..(live_id and theme.name or 'UNKNOWN')..' / '..live_label,420,374,12)
    text('EDIT: '..themes[G.edit_spec].name..' / '..(Modes.labels[G.editing] or G.editing),420,394,12,muted)
   local info=C.information(G.edit_spec,G.editing);local page_size=6
   G.info_offset=math.min(G.info_offset or 0,math.max(0,#info-page_size))
   for i=G.info_offset+1,math.min(#info,G.info_offset+page_size)do
     local row=info[i];local y=420+(i-G.info_offset-1)*38
    rect(414,y,548,38,col(17,24,31,255));text(row[1]:sub(1,43),426,y+6,13)
    local active=row[2]=='ON';local value_color=active and accent or row[2]=='OFF' and muted or white
    text(row[2],900,y+6,13,value_color)
   end
    button('UP',416,660,72,28,function()G.info_offset=math.max(0,G.info_offset-page_size)end,false)
    button('DOWN',496,660,84,28,function()G.info_offset=math.min(math.max(0,#info-page_size),G.info_offset+page_size)end,false)
    local wheel=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(402,312),V.new(974,702))and mouse_wheel_delta()or 0
   local tick=type(core.time)=='function'and core.time()or 0
   if wheel~=0 and tick-last_wheel>0.08 then G.info_offset=math.max(0,math.min(math.max(0,#info-page_size),G.info_offset+(wheel<0 and page_size or -page_size)));last_wheel=tick end
    text((G.info_offset+1)..'-'..math.min(#info,G.info_offset+page_size)..' / '..#info,596,669,11,muted)
    text('STATUS: '..tostring(C.status):sub(1,47),720,669,11,accent)
   if window.render_tooltip_default and window:is_mouse_hovering_rect(V.new(700,650),V.new(970,687))then window:render_tooltip_default(tostring(C.status))end
  end
  for i,icon in ipairs({theme.icon,'control','rune','shield','heal','eye'})do
   local x=34+(i-1)*52;Icons.draw(icon,window,x,655,43,accent,visual_id)
   if window:is_rect_clicked(V.new(x,655),V.new(x+43,698))then G.page=({1,3,10,5,6,9})[i];G.offset=0 end
  end
  button('HIDE',34,712,91,31,function()C.themed_gui:set(false)end,true)
  rect(402,711,572,33,col(9,13,17,250));text(C.status:sub(1,58),414,719,12,muted)
  if window.render_tooltip_default and window:is_mouse_hovering_rect(V.new(402,711),V.new(892,744))then window:render_tooltip_default(tostring(C.status))end
  button('v'..VERSION,897,716,65,24,function()G.page=11;G.info_offset=0 end,false)
 end)
end
function G.render()
 local ok,err=pcall(function()
  local player=core and core.object_manager and U.fn(core.object_manager.get_local_player)
  if not U.valid(player) or U.number(U.call(player,'get_class'))~=8 then
   if window then window:set_visibility(false)end
   if dragging and core.graphics and type(core.graphics.set_mouse_capture_state)=='function'then pcall(core.graphics.set_mouse_capture_state,false)end
   dragging=nil;mouse_was_down=false;G.f1_down=false
   return
  end
  local input=core.input
  if input and type(input.is_key_pressed)=='function'then local read,down=pcall(input.is_key_pressed,0x70);if read and type(down)=='boolean'then
   if down and not G.f1_down and C.themed_gui then C.themed_gui:set(not C.themed_gui:get_state())end;G.f1_down=down
  end end
  capture_binding();render_window()
 end);G.error=not ok and tostring(err) or nil
 if not ok then C.status='Mage GUI error: '..tostring(err):sub(1,90);if G.logged_error~=G.error then require('sm_log').emit('error',{spec=C.identity and C.identity.id,mode=C.mode,identity=C.identity},C.status);if core.log then core.log(C.status)end;G.logged_error=G.error end end
end
return G
