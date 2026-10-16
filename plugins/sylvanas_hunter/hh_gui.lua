local C,Modes,U=require('hh_settings'),require('hh_modes'),require('hh_util');local Runtime=require('hh_runtime')
local Icons,Art,Buttons=require('hh_icons'),require('hh_art'),require('hh_buttons')
local G={page=1,offset=0,scope=nil,editing=nil,error=nil,colors={}};local window
local W,H=1000,760
local themes={
 [253]={name='MASTER OF THE PACK',spec='BEAST MASTERY',hero='REXXAR & MISHA',tag='COMMAND • HUNT • OVERWHELM',motto='THE PACK ANSWERS',accent={120,223,105},dark={18,29,19},metal={177,132,65},hover={41,76,39},icon='paw'},
 [254]={name="THE WINDRUNNER'S AIM",spec='MARKSMANSHIP',hero='ALLERIA WINDRUNNER',tag='PRECISION • PATIENCE • CONTROL',motto='ONE SHOT • ONE MARK',accent={110,196,248},dark={15,23,39},metal={151,168,214},hover={35,58,88},icon='bow'},
 [255]={name='SPEAR OF THE WILD',spec='SURVIVAL',hero='HULN HIGHMOUNTAIN',tag='SPEAR • TRAPS • PURSUIT',motto='CLOSE • STRIKE • ENDURE',accent={244,176,70},dark={39,23,15},metal={194,115,57},hover={91,51,25},icon='spear'}
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
 local panel=col(theme.dark[1],theme.dark[2],theme.dark[3],242)
 local row_color=col(math.min(255,theme.dark[1]+7),math.min(255,theme.dark[2]+10),math.min(255,theme.dark[3]+10),250)
 local function option_icon(key,spec)
  return option_icons[key] or (key=='interrupts' or key=='interrupt_percent')and(spec==255 and'spear'or'bow')
   or key:find('pet')and'paw'or(key=='cc'or key:find('arena'))and'trap'or key:find('hp')and'heal'
   or key:find('defensive')and'shield'or(key=='cooldowns'or key:find('burst'))and'skull'or theme.icon
 end
 local function toggle(widget,x,y)
  local on=value(widget)==true
  button(on and '●  ON' or '○  OFF',x,y,82,30,function()put(widget,not on)end,on)
 end
 local function global_row(label,note,key,y,icon)
  local widget=C[key];rect(310,y,656,56,row_color,6);outline(310,y,656,56,col(theme.metal[1],theme.metal[2],theme.metal[3],90),6,1)
  Icons.draw(icon,window,321,y+8,40,accent,C.identity.id);text(label,373,y+5,15);text(note,373,y+29,11,muted)
  toggle(widget,872,y+13)
 end
 window:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,col(9,13,17),accent,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  if not Art.draw(C.identity.id,window,W,H)then
   rect(0,0,W,H,dark,0);Icons.draw(theme.icon,window,74,234,218,accent,C.identity.id)
   text(theme.hero,40,520,22,accent);text('Character artwork unavailable',40,554,13,muted)
  end
  rect(0,0,W,H,col(5,10,13,118),0);outline(9,9,W-18,H-18,col(theme.metal[1],theme.metal[2],theme.metal[3],220),8,2)
  -- Strong title bar inspired by a premium class suite, with spec-owned identity.
  rect(18,16,964,101,panel,9);outline(18,16,964,101,accent,9,1)
  rect(31,27,76,76,col(7,13,16,245),38);outline(31,27,76,76,col(theme.metal[1],theme.metal[2],theme.metal[3],230),38,2)
  Icons.draw(theme.icon,window,45,41,48,accent,C.identity.id)
  text(theme.name,126,26,27,col(241,216,161));text(theme.spec..'  •  '..theme.hero..'  •  '..Runtime.version:upper()..'  •  v1.6.9',128,63,13,white)
  text(theme.tag,128,84,11,muted)
  button('MODE: '..(Modes.labels[C.mode]or C.mode):upper(),730,37,130,31,function()G.editing=C.mode;G.offset=0 end,true)
  button(C.enabled:get_state()and'● PROFILE ACTIVE'or'○ PROFILE OFF',868,37,101,31,function()C.enabled:set(not C.enabled:get_state())end,C.enabled:get_state())
  button(C.pause:get_state()and'RESUME'or'PAUSE',868,75,101,25,function()C.pause:set(not C.pause:get_state())end,C.pause:get_state())
  if Modes.pvp[C.mode]then
   local automatic=C.value(C.identity.id,C.mode,'automatic_burst')==true
   button(not C.burst:get_state()and'BURST HELD'or automatic and'BURST AUTO'or'BURST ON',730,75,130,25,function()C.burst:set(not C.burst:get_state())end,C.burst:get_state())
  end
  -- Vertical navigation keeps every destination visible without nested menus.
  rect(18,128,270,574,panel,8);outline(18,128,270,574,col(theme.metal[1],theme.metal[2],theme.metal[3],150),8,1)
  for i,page in ipairs(pages)do
   local y=140+(i-1)*43
   button(page[1],30,y,246,38,function()G.page=i;G.offset=0 end,G.page==i,i==9 and theme.icon or page[2])
  end
  text(theme.motto,52,668,11,accent)
  -- Main card and activity selector.
  rect(300,128,682,574,panel,8);outline(300,128,682,574,accent,8,1)
  text((G.page==9 and theme.spec..' ROTATION'or pages[G.page][1])..' CUSTOMIZATION',322,143,21,col(241,216,161))
  text('LIVE '..(Modes.labels[C.mode]or C.mode)..'  •  EDIT '..(Modes.labels[G.editing]or G.editing),322,173,11,muted)
  if G.page<=9 then
   local labels={world_pve='WORLD',delve='DELVES',dungeon='DUNGEON',mythic_plus='MYTHIC+',raid='RAID',arena='ARENA',battleground='BGS',world_pvp='WORLD PVP'}
   for i,mode in ipairs(Modes.order)do
    local x,y=312+((i-1)%4)*165,194+math.floor((i-1)/4)*32
    button(labels[mode],x,y,157,27,function()G.editing=mode;G.offset=0 end,G.editing==mode)
  end
   local spec,mode=C.identity.id,G.editing;local list=C.gui_groups(spec,mode,G.page);local booleans,numbers={},{}
   for _,key in ipairs(list)do local state=C.value(spec,mode,key);if type(state)=='boolean'then booleans[#booleans+1]=key else numbers[#numbers+1]=key end end
   for i=G.offset+1,math.min(#booleans,G.offset+5)do
    local key=booleans[i];local widget=C.control(spec,mode,key);local y=266+(i-G.offset-1)*60
    if widget then
     rect(312,y,658,54,row_color,6);outline(312,y,658,54,col(theme.metal[1],theme.metal[2],theme.metal[3],85),6,1)
     Icons.draw(option_icon(key,spec),window,322,y+7,40,accent,spec)
     text(C.label(spec,key):gsub(' health %%',' %%'),374,y+5,15);text((notes[key]or'Current activity only'):sub(1,43),374,y+29,11,muted)
     button(C.binding==key and'PRESS KEY'or C.key_name(C.key_code(key)),744,y+12,112,30,function()C.start_bind(key,U.fn(core.time)or 0)end,C.binding==key)
     toggle(widget,872,y+12)
     if window:is_rect_clicked(V.new(312,y),V.new(734,y+54))then put(widget,not value(widget))end
    end
   end
   local numeric_start=math.floor(G.offset/5)*2+1
   local page_count=math.max(math.ceil(#booleans/5),math.ceil(#numbers/2),1)
   local page_index=math.floor(G.offset/5)+1
   if page_count>1 then
    button('‹ PREVIOUS',312,572,120,27,function()G.offset=math.max(0,G.offset-5)end)
    button('MORE OPTIONS ›',440,572,148,27,function()if page_index<page_count then G.offset=G.offset+5 end end)
    text(page_index..' / '..page_count,922,578,11,muted)
   end
   -- Numeric settings use two clean cards like the reference threshold controls.
   for i=numeric_start,math.min(numeric_start+1,#numbers)do
    local key=numbers[i];local widget=C.control(spec,mode,key);local state=value(widget)or 0;local x=312+(i-numeric_start)*329
    rect(x,611,319,74,row_color,7);Icons.draw(option_icon(key,spec),window,x+11,620,31,accent,spec)
    text(C.label(spec,key):gsub(' health %%',' %%'),x+51,617,12);text(state..(key:find('hp')and'%'or''),x+257,617,14,accent)
    rect(x+16,655,287,5,col(54,68,67),2);rect(x+16,655,287*math.max(0,math.min(100,state))/100,5,accent,2)
    button('−',x+218,645,32,24,function()put(widget,math.max(0,state-1))end);button('+',x+270,645,32,24,function()put(widget,math.min(100,state+1))end)
   end
  elseif G.page==11 then
   global_row('Show themed command window','F1 also shows or hides this window','themed_gui',215,'eye')
   global_row('Persistent diagnostic logging','Save batches; preserve previous sessions','logging',279,'eye')
   text('LIVE STATUS',322,360,13,accent);text(C.status:sub(1,74),322,385,12)
   local log=require('hh_log')
   button('COPY CURRENT',312,430,198,35,function()log.copy(window,false)end)
   button('COPY PREVIOUS',520,430,198,35,function()log.copy(window,true)end)
   button('SAVE NOW',728,430,226,35,function()
    log.notice=log.flush(nil,true) and 'Queued records saved.' or log.status
   end)
   text(log.status:sub(1,82),322,492,12,muted);text(log.notice:sub(1,82),322,520,12,accent)
   text('scripts_data / '..(Runtime.family=='forever'and'sylvanas_hunter_forever'or'sylvanas_hunter')..' / logs',322,554,11,muted)
  elseif G.page==10 then
   global_row('PvP burst permission','Allow major offensive cooldowns in PvP','burst',215,'skull')
   global_row('DPS boss helper','All three specs; PvE activities only','boss_guide',279,'trophy')
   text('LIVE BOSS COACH',322,360,13,accent);local status=Runtime.module('hh_dps_boss_guides','hh_dps_boss_guides_forever').status
   for i=1,4 do text(status:sub((i-1)*74+1,i*74),322,388+(i-1)*23,12,i==1 and white or muted)end
   local hint=C.identity.id==253 and 'Protect charges. Use Bestial Wrath in permitted kill windows.' or C.identity.id==254 and 'Spend Precise Shots. Prepare Trick Shots before cleave.' or 'Empower attacks with Tip. Use Eagle during forced range.'
   text(hint,322,508,12,accent);text('Profile: '..theme.spec..' / '..Modes.labels[C.mode],322,540,11,muted)
  else
   local list=C.hotkey_options(C.identity.id,G.editing)
   text('Click a bind, then press a key. ESC clears it. F1 and F7 are reserved.',322,194,11,muted)
    for i=G.offset+1,math.min(#list,G.offset+5)do
     local key=list[i];local y=225+(i-G.offset-1)*64;local control=({enabled=C.enabled,pause=C.pause,themed_gui=C.themed_gui,boss_guide=C.boss_guide,logging=C.logging,burst=C.burst})[key]or C.control(C.identity.id,G.editing,key)
     rect(312,y,658,56,row_color,6);Icons.draw(option_icon(key,C.identity.id),window,322,y+8,40,accent,C.identity.id)
     text(C.label(C.identity.id,key),374,y+6,14);text(control and value(control)and'Enabled'or'Disabled',374,y+31,11,muted)
     button(C.binding==key and'PRESS KEY'or C.key_name(C.key_code(key)),778,y+13,176,30,function()C.start_bind(key,U.fn(core.time)or 0)end,C.binding==key)
    end
   if #list>5 then button('‹ PREVIOUS',312,558,120,27,function()G.offset=math.max(0,G.offset-5)end);button('MORE BINDS ›',440,558,140,27,function()if G.offset+5<#list then G.offset=G.offset+5 end end);text((G.offset+1)..'-'..math.min(#list,G.offset+5)..' / '..#list,910,564,11,muted)end
   text((C.bind_notice or'Unbound features continue using their ON/OFF state.'):sub(1,82),322,610,11,accent)
  end
  rect(18,710,964,33,col(7,12,15,248),5);text('F1 HIDE  •  F7 BOSS HELPER  •  '..theme.tag,31,718,11,muted)
  text(C.status:sub(1,58),430,718,11,white);button('v1.6.9',894,714,76,25,function()G.page=10 end,false)
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
