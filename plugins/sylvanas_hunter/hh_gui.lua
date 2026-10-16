local C,Modes,U=require('hh_settings'),require('hh_modes'),require('hh_util')
local Icons,Art,Buttons=require('hh_icons'),require('hh_art'),require('hh_buttons')
local G={page=1,offset=0,scope=nil,editing=nil,error=nil,colors={}};local window
local W,H=1000,760
local themes={
 [253]={name='BEAST MASTERY',hero='REXXAR & MISHA',tag='PACK / PRESSURE / PURSUIT',accent={120,223,105},dark={25,28,16},metal={177,132,65},hover={63,39,23},icon='paw'},
 [254]={name='MARKSMANSHIP',hero='ALLERIA WINDRUNNER',tag='PRECISION / SETUP / CONTROL',accent={110,196,248},dark={19,17,40},metal={151,168,214},hover={48,34,78},icon='bow'},
 [255]={name='SURVIVAL',hero='HULN HIGHMOUNTAIN',tag='SPEAR / TRAPS / SURVIVAL',accent={244,176,70},dark={39,21,15},metal={194,115,57},hover={82,31,22},icon='spear'}
}
local pages={{'CORE','eye'},{'DAMAGE','bow'},{'BURST','skull'},{'CONTROL','trap'},{'DEFENSE','shield'},{'PET','paw'},
 {'MOBILITY','spear'},{'PVP','trap'},{'SPEC','bow'},{'BOSS GUIDE','trophy'},{'DISPLAY / LOGS','eye'},{'HOTKEYS','spear'}}
local option_icons={bm_barbed_setup='bow',bm_cleave='paw',bm_focus_pool='eye',bm_dire_beast='paw',bm_dark_ranger='skull',
 mm_precise='spear',mm_trick='bow',mm_explosive='skull',mm_volley='bow',mm_chakram='spear',
 sv_tip='spear',sv_bombs='bow',sv_boomstick='skull',sv_chakram='spear',sv_eagle='eye'}
local notes={bm_barbed_setup='Prepare Barbed Shot before Bestial Wrath',bm_cleave='Safe Wild Thrash refreshes for the active pet',
 bm_focus_pool='Keep Focus for the next Kill Command',bm_dire_beast='Cast a learned and usable Dire Beast',bm_dark_ranger='Learned Black Arrow and Wailing Arrow only',
 mm_precise='Use empowered Arcane, Multi or Black Arrow',mm_trick='Prepare cleave before Aimed Shot and Rapid Fire',mm_explosive='Use learned Explosive Shot without wasting procs',
 mm_volley='Safe Volley on engaged targets',mm_chakram='Requires learned Sentinel Moonlight Chakram',
 sv_tip='Build Tip before empowered Survival attacks',sv_bombs='Manage Wildfire Bomb charges',sv_boomstick='Use Tip-empowered Boomstick',
 sv_chakram='Requires learned Sentinel Moonlight Chakram',sv_eagle='Use Eagle during forced range',
 execute='Allow Kill Shot and other execute-range priorities',training_dummy='Run the selected profile on city training dummies',manual_pause='Yield briefly after the player casts manually',performance_telemetry='Add tick and snapshot timing to five-second logs',
 urgent_interrupts='Stop dangerous channels without waiting for the slider',cc_interrupt_fallback='Use a DR-safe stun when the interrupt is unavailable',predictive_defensives='React to predicted incoming damage as well as current health',team_roar='Protect a focused Arena teammate with Roar of Sacrifice',critical_pet_exhilaration='Use Exhilaration when the active pet is critically low',auto_kite='Remove roots and apply slows under PvP pressure',target_line='Draw the spec-colored line to the current PvP target',healer_line='Draw the cyan or red line to the enemy healer',boss_world_cues='Draw encounter arrows, lines, and rings in the world',boss_auto_popup='Show the small guide automatically when a boss is detected',
 enabled='Only this specialization and activity',damage='Hunter damage priorities for this profile',
 cooldowns='Burst windows and major damage abilities',aoe='Protect crowd control and avoid fresh pulls',
 automatic_burst='Automatic PvP kill windows for this profile',interrupts='Counter Shot or Muzzle for the detected spec',
 cc='Known immunity and diminishing returns required',arena_control='Stationary healer Trap setups in Arena only',arena_scatter='Emergency off-target cast stop; preserves healer Trap DR',
 pet_heal='Mend your active companion',pet_recovery='Call Pet 1 or attempt a safe PvE revive',
 misdirection='Party tank or living solo pet; PvE only',purge='Confirmed purgeable enemy buffs',
 harpoon='Survival only; requires an engaged target',timer_defensives='Known BigWigs or ExBoss pressure',
 heal_hp='Exhilaration health threshold',low_hp='Survival of the Fittest health threshold',turtle_hp='Emergency Turtle health threshold',
 pet_hp='Mend Pet health threshold',interrupt_percent='How far an enemy cast must progress',
 cooldown_min_ttd='Save burst on nearly defeated enemies',cooldown_min_enemies='Mythic+ pack threshold'}
local function value(w)
 if not w then return nil end
 if w.get_state then return w:get_state() end
 if w.get then return w:get() end
end
local function put(w,v)if w and w.set then w:set(v)end end
local function render_window()
 if not C.identity or not C.themed_gui or not C.themed_gui:get_state() or not core.menu.window then if window then window:set_visibility(false)end;return end
 local Color,V,Enums=require('common/color'),require('common/geometry/vector_2'),require('common/enums')
 local theme=themes[C.identity.id];if not theme then return end
 local scope=tostring(C.identity.id)..':'..tostring(C.mode)
 if G.scope~=scope then G.scope=scope;G.editing=C.mode;G.offset=0;G.page=1 end
 local we=Enums.window_enums or Enums;local fonts=we.font_id or {};local small,big=fonts.FONT_SMALL or 7,fonts.FONT_BIG or 8
 local function col(r,g,b,a)
  a=a or 255;local key=((r*256+g)*256+b)*256+a
  local paint=G.colors[key]
  if not paint then paint=Color.new(r,g,b,a);G.colors[key]=paint end
  return paint
 end
 local accent=col(theme.accent[1],theme.accent[2],theme.accent[3]);local muted=col(182,195,202)
 local dark=col(theme.dark[1],theme.dark[2],theme.dark[3],245);local white=col(240,246,245)
 if not window then
  window=core.menu.window('sylvanas_hunter_command');window:set_initial_position(V.new(70,70));window:set_initial_size(V.new(W,H))
  if window.set_render_layer then window:set_render_layer(1)end
 end
 window:set_visibility(true);if window.force_window_size then window:force_window_size(V.new(W,H))end
 if window.set_next_window_min_size then window:set_next_window_min_size(V.new(W,H))end
 local function rect(x,y,w,h,c,r)window:render_rect_filled(V.new(x,y),V.new(x+w,y+h),c,r or 4)end
 local function outline(x,y,w,h,c,r,t)if window.render_rect then window:render_rect(V.new(x,y),V.new(x+w,y+h),c,r or 4,t or 1)end end
 local function text(s,x,y,size,c)
  if window.render_text_custom_size then window:render_text_custom_size(small,V.new(x,y),c or white,size or 14,tostring(s))
  else window:render_text(size and size>=20 and big or small,V.new(x,y),c or white,tostring(s))end
 end
 local function button(label,x,y,w,h,fn,active,icon)
  local hover=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(x,y),V.new(x+w,y+h))
  Buttons.draw(window,V,Color,theme,C.identity.id,x,y,w,h,active,hover)
  local offset=10;if icon then Icons.draw(icon,window,x+5,y+4,h-8,accent,C.identity.id);offset=h+5 end
  local size=(w<80 and #label>5) and 11 or w>=200 and 15 or 14
  text(label,x+offset,y+(h-size)/2-1,size,active and w<100 and col(12,24,16) or white)
  if window:is_rect_clicked(V.new(x,y),V.new(x+w,y+h))then fn()end
 end
 local function global_row(label,note,key,y,icon)
  local widget=C[key];rect(414,y,558,52,col(17,24,31,255));Icons.draw(icon,window,423,y+7,38,accent,C.identity.id)
  text(label,473,y+6,15);text(note,473,y+28,12,muted)
  button(value(widget) and 'ON' or 'OFF',908,y+12,52,27,function()put(widget,not value(widget))end,value(widget))
 end
 window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,col(9,13,17),accent,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  if not Art.draw(C.identity.id,window,W,H)then
   rect(0,0,W,H,dark,0);Icons.draw(theme.icon,window,74,234,218,accent,C.identity.id)
   text(theme.hero,40,520,22,accent);text('Character artwork unavailable',40,554,13,muted)
  end
  outline(10,10,W-20,H-20,accent,6,1)
  rect(500,20,474,83,col(10,14,20,250),7);outline(500,20,474,83,col(theme.accent[1],theme.accent[2],theme.accent[3],150),7,1)
  text(theme.name..' HUNTER',518,29,24);text(theme.hero,519,62,14,accent)
  text('F1: show / hide  |  Drag header to move',519,84,11,muted)
  rect(398,110,576,64,col(12,16,22,250))
  text('LIVE: '..(Modes.labels[C.mode] or C.mode),414,119,14);text('EDIT: '..(Modes.labels[G.editing] or G.editing),626,119,14)
  text('Auto spec and activity',414,146,12,muted)
  button(C.enabled:get_state() and 'ON' or 'OFF',844,121,55,26,function()C.enabled:set(not C.enabled:get_state())end,C.enabled:get_state())
  button(C.pause:get_state() and 'RESUME' or 'PAUSE',908,121,55,26,function()C.pause:set(not C.pause:get_state())end,C.pause:get_state())
  if Modes.pvp[C.mode]then
   local automatic=C.value(C.identity.id,C.mode,'automatic_burst')==true
   button(not C.burst:get_state() and 'BURST HELD' or automatic and 'BURST AUTO' or 'BURST ON',844,150,119,21,function()C.burst:set(not C.burst:get_state())end,C.burst:get_state())
  end
  rect(18,178,964,88,col(10,15,21,246))
   for i,page in ipairs(pages)do
    local x,y=22+((i-1)%6)*160,184+math.floor((i-1)/6)*40
    button(page[1],x,y,153,35,function()
    G.page=i;G.offset=0
    end,G.page==i,i==9 and theme.icon or page[2])
  end
   rect(402,276,572,426,col(7,11,17,249),7);text(G.page==9 and theme.name..' ROTATION' or pages[G.page][1],419,285,19,white)
   if G.page<=9 then
   local modes=Modes.order
   local labels={world_pve='WORLD PVE',dungeon='DUNGEON',mythic_plus='MYTHIC+',raid='RAID',delve='DELVE',arena='ARENA',battleground='BGS',world_pvp='WORLD PVP'}
   for i,mode in ipairs(modes)do
    local x,y=416+((i-1)%4)*137,318+math.floor((i-1)/4)*30
    button(labels[mode],x,y,130,25,function()G.editing=mode;G.offset=0 end,G.editing==mode)
   end
   text((Modes.labels[G.editing] or G.editing)..' settings',419,379,13,accent)
   local spec,mode=C.identity.id,G.editing;local list=C.gui_groups(spec,mode,G.page)
   for i=G.offset+1,math.min(#list,G.offset+5)do
    local key=list[i];local widget=C.control(spec,mode,key);local y=404+(i-G.offset-1)*52
    if widget then
     rect(414,y,558,48,col(17,24,31,255))
     local icon=option_icons[key] or (key=='interrupts' or key=='interrupt_percent') and (spec==255 and 'spear' or 'bow') or key:find('pet') and 'paw' or (key=='cc' or key=='arena_control') and 'trap' or key:find('hp') and 'heal' or key:find('defensive') and 'shield' or key=='cooldowns' and 'skull' or theme.icon
     Icons.draw(icon,window,423,y+5,38,accent,C.identity.id)
     text(C.label(spec,key):gsub(' health %%',' %%'),473,y+4,15);text((notes[key] or 'This activity only'):sub(1,55),473,y+27,12,muted)
     if window.render_tooltip_default and window:is_mouse_hovering_rect(V.new(414,y),V.new(830,y+48))then window:render_tooltip_default(C.label(spec,key)..'\n'..(notes[key] or 'Only this specialization and activity'))end
     local state=value(widget)
     if type(state)=='boolean'then
       button(C.binding==key and 'PRESS KEY' or C.key_name(C.key_code(key)),806,y+10,94,28,function()C.start_bind(key,U.fn(core.time)or 0)end,C.binding==key)
      button(state and 'ON' or 'OFF',908,y+10,52,28,function()put(widget,not value(widget))end,state)
       if window:is_rect_clicked(V.new(414,y),V.new(798,y+48))then put(widget,not value(widget))end
     else
      button('-',847,y+10,28,28,function()put(widget,math.max(0,value(widget)-1))end)
      text(state,884,y+17,13,accent);button('+',932,y+10,28,28,function()put(widget,math.min(100,value(widget)+1))end)
      rect(847,y+41,113,3,col(64,70,60),1);rect(847,y+41,113*state/100,3,accent,1)
      if window:is_rect_clicked(V.new(847,y+38),V.new(960,y+48)) and core.get_cursor_position and window.get_position then
       local cursor,origin=core.get_cursor_position(),window:get_position()
       if cursor and origin then put(widget,math.floor(math.max(0,math.min(100,(cursor.x-origin.x-847)/113*100))+0.5))end
      end
     end
    end
   end
   if #list>5 then
    button('PREVIOUS',416,669,115,25,function()G.offset=math.max(0,G.offset-5)end)
    button('MORE OPTIONS',538,669,155,25,function()if G.offset+5<#list then G.offset=G.offset+5 end end)
    text((G.offset+1)..'-'..math.min(#list,G.offset+5)..' / '..#list,900,675,11,muted)
   end
   elseif G.page==11 then
    global_row('Show themed command window','F1 also shows or hides this window','themed_gui',325,'eye')
    global_row('Persistent diagnostic logging','Save batches; preserve previous sessions','logging',383,'eye')
   text('Live status',420,466,16,accent);text(C.status:sub(1,66),420,499,12)
   local log=require('hh_log')
   button('COPY CURRENT',416,538,174,32,function()log.copy(window,false)end)
   button('COPY PREVIOUS',600,538,174,32,function()log.copy(window,true)end)
   button('SAVE NOW',784,538,174,32,function()
    log.notice=log.flush(nil,true) and 'Queued records saved.' or log.status
   end)
   text(log.status:sub(1,76),420,588,12,muted)
   text(log.notice:sub(1,72),420,614,12,accent)
   text('Files: scripts_data / sylvanas_hunter / logs',420,648,12,muted)
   elseif G.page==10 then
   global_row('PvP burst permission','Allow major offensive cooldowns in PvP','burst',325,'skull')
   global_row('DPS boss helper','All three specs; PvE activities only','boss_guide',383,'trophy')
   text('DPS GUIDE',420,464,16,accent);local status=require('hh_dps_boss_guides').status
   for i=1,3 do text(status:sub((i-1)*66+1,i*66),420,494+(i-1)*22,12)end
   local hint=C.identity.id==253 and 'Protect charges. Use Bestial Wrath in permitted kill windows.' or C.identity.id==254 and 'Spend Precise Shots. Prepare Trick Shots before cleave.' or 'Empower attacks with Tip. Use Eagle during forced range.'
   text(hint,420,594,12,accent);text('Profile: '..theme.name..' / '..Modes.labels[C.mode],420,633,11,muted)
   else
    local list=C.hotkey_options(C.identity.id,G.editing)
    text('Click a bind, then press a key. ESC clears it. F1 and F7 are reserved.',419,318,11,muted)
    for i=G.offset+1,math.min(#list,G.offset+5)do
     local key=list[i];local y=350+(i-G.offset-1)*56;local control=({enabled=C.enabled,pause=C.pause,themed_gui=C.themed_gui,boss_guide=C.boss_guide,logging=C.logging,burst=C.burst})[key]or C.control(C.identity.id,G.editing,key)
     rect(414,y,548,49,col(17,24,31,255));text(C.label(C.identity.id,key),426,y+6,14);text(control and value(control)and'Enabled' or 'Disabled',426,y+28,11,muted)
     button(C.binding==key and 'PRESS KEY' or C.key_name(C.key_code(key)),806,y+10,146,28,function()C.start_bind(key,U.fn(core.time)or 0)end,C.binding==key)
    end
    if #list>5 then button('PREVIOUS',416,650,115,25,function()G.offset=math.max(0,G.offset-5)end);button('MORE BINDS',538,650,140,25,function()if G.offset+5<#list then G.offset=G.offset+5 end end);text((G.offset+1)..'-'..math.min(#list,G.offset+5)..' / '..#list,882,657,11,muted)end
    text((C.bind_notice or 'Unbound options continue using their ON/OFF state.'):sub(1,76),420,687,11,accent)
  end
  for i,icon in ipairs({theme.icon,'trap','skull','shield','heal','eye'})do
   local x=34+(i-1)*52;Icons.draw(icon,window,x,655,43,accent,C.identity.id)
    if window:is_rect_clicked(V.new(x,655),V.new(x+43,698))then G.page=({2,4,10,5,6,11})[i];G.offset=0 end
  end
  button('HIDE',34,712,91,31,function()C.themed_gui:set(false)end,true)
  rect(402,711,572,33,col(9,13,17,250));text(C.status:sub(1,58),414,719,12,muted)
  button('v1.4.64',897,716,65,24,function()G.page=10 end,false)
 end)
end
function G.poll_hotkey()
 -- Shared edge state makes update-loop and render-frame polling safe together.
 local input=core.input
 if input and type(input.is_key_pressed)=='function' then
  local read,down=pcall(input.is_key_pressed,0x70)
  if read and type(down)=='boolean' then
   if down and not G.f1_down and C.identity and C.themed_gui then C.themed_gui:set(not C.themed_gui:get_state())end
   G.f1_down=down
  end
 end
end
function G.render()
 local ok,err=pcall(function()
  G.poll_hotkey()
  render_window()
 end);G.error=not ok and tostring(err) or nil
 if not ok then C.status='Hunter GUI error: '..tostring(err):sub(1,90);if core.log and G.logged_error~=G.error then core.log(C.status);G.logged_error=G.error end end
end
return G


