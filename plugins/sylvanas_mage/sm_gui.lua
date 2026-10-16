local C,Modes,U=require('sm_settings'),require('sm_modes'),require('sm_util')
local Icons,Art,Buttons=require('sm_icons'),require('sm_art'),require('sm_buttons')
local G={page=1,offset=0,scope=nil,editing='world_pve',error=nil,f1_down=false,binding=nil};local window
local W,H=1000,760;local wx,wy=55,55;local dragging,mouse_was_down,last_wheel=nil,false,-math.huge
local VERSION=require('sm_version')
local themes={
 [62]={name='ARCANE',title='KEEPER OF THE VEIL',hero='MEDIVH — THE CORRUPTED GUARDIAN',tag='MANA  •  SALVO  •  TRANSCENDENCE',accent={192,144,255},dark={18,10,38},metal={178,151,230},hover={59,30,98},icon='arcane'},
 [63]={name='FIRE',title='SOVEREIGN OF FLAME',hero="KAEL'THAS — THE SUN KING",tag='IGNITE  •  COMBUSTION  •  REBIRTH',accent={255,166,73},dark={42,12,8},metal={223,147,71},hover={99,35,18},icon='fire'},
 [64]={name='FROST',title='WARDEN OF THE FROZEN TIDE',hero='JAINA — THE LORD ADMIRAL',tag='FREEZING  •  SHATTER  •  CONTROL',accent={116,222,255},dark={7,22,40},metal={153,206,235},hover={24,63,93},icon='frost'}
}
local nav={{'DASHBOARD','eye'},{'PLAYER','heal'},{'WORLD','rune','world_pve'},{'DUNGEONS','shield','dungeon'},{'MYTHIC+','burst','mythic_plus'},{'RAID','trophy','raid'},{'DELVES','projectile','delve'},{'ARENA','control','arena'},{'BATTLEGROUNDS','shield','battleground'},{'WORLD PVP','fire','world_pvp'},{'HOTKEYS','projectile'}}
local option_icons={enabled='rune',damage='projectile',cooldowns='burst',aoe='control',automatic_burst='fire',priority_interrupts='eye',pvp_target_lines='eye',pvp_roots='control',pvp_slow='frost',timer_defensives='trophy',arcane_salvo='projectile',arcane_prismatic='arcane',arcane_missiles='projectile',arcane_recovery='heal',arcane_reserve='burst',fire_hot_streak='burst',fire_blast='projectile',fire_pyroclasm='rune',fire_meteor='trophy',fire_flamestrike='fire',frost_freezing='frost',frost_orb='burst',frost_blizzard='rune',frost_spike='projectile',frost_ray='eye',frost_ice_nova='control',frost_cone='frost',frost_cold_snap='shield',temporal_defense='rune',invisibility_defense='eye',automatic_peeling='frost',arena_control='control',defensives='shield',interrupts='control',purge='rune',remove_curse='heal',intellect='arcane',forever_mana_shield='shield',forever_wards='rune',forever_recovery='heal'}
local notes={enabled='Enable this specialization and activity',damage='Run the complete damage priority',cooldowns='Use major offense in approved windows',aoe='Protect control and avoid fresh enemies',automatic_burst='Build automatic PvP kill windows',defensives='React to verified incoming danger',interrupts='Counterspell eligible dangerous casts',priority_interrupts='Reserve Counterspell for priority casts',arena_control='Polymorph clean off-target healers',automatic_peeling='Create distance from confirmed melee pressure',defensive_control='Control attackers threatening teammates',pvp_target_lines='Draw target and healer positioning lines',pvp_roots='Use DR-safe roots under pressure',pvp_slow='Arcane Slow on unslowed pressure',purge='Spellsteal confirmed valuable magic',remove_curse='Remove confirmed important curses',intellect='Maintain Arcane Intellect',forever_mana_shield='Absorb dangerous melee pressure when mana permits',forever_wards='Match Fire and Frost wards to incoming casts',forever_recovery='Channel Evocation below fifteen percent mana',timer_defensives='Prepare barriers for known boss pressure',temporal_defense='Use Alter Time before ranged burst',invisibility_defense='Emergency Greater Invisibility response',arcane_images='Refractive Images damage smoothing',arcane_salvo='Spend Barrage at the correct Salvo threshold',arcane_prismatic='Use verified Prismatic replacement procs',arcane_missiles='Spend Clearcasting without clipping',arcane_recovery='Recover mana outside burst windows',fire_hot_streak='Spend Hot Streak before another conversion',fire_blast='Convert Heating Up in proven windows',fire_pyroclasm='Use empowered Pyroblast or Flamestrike',fire_meteor='Place Meteor in safe damage windows',frost_freezing='Spend current Freezing stack thresholds',frost_orb='Use Orb only with a safe forward path',frost_blizzard='Use Blizzard at talent-aware counts',frost_spike='Use Glacial Spike from proc or five Icicles',frost_ray='Protect complete Ray of Frost channels'}
local function value(w)if not w then return nil end;if w.get_state then return w:get_state()end;if w.get then return w:get()end end
local function put(w,v)if w and w.set then w:set(v)end end
local function begin_binding(spec,mode,key)G.binding={spec=spec,mode=mode,key=key};C.hotkey_status='Press a key for '..C.label(spec,key)..' — ESC clears'end
local function capture_binding()
 if not G.binding or not core.input or type(core.input.is_key_pressed)~='function'then return end
 for code=8,255 do local ok,down=pcall(core.input.is_key_pressed,code);if ok and down then local b=G.binding
  if code==27 then C.assign_hotkey(b.spec,b.mode,b.key,0)elseif code==0x70 or code==0x76 then C.hotkey_status=C.key_name(code)..' is reserved for a Mage window'else C.assign_hotkey(b.spec,b.mode,b.key,code)end
  G.binding=nil;return end end
end
local function wheel_delta()
 for _,fn in pairs({core.input and core.input.get_mouse_wheel_delta,core.get_mouse_wheel_delta,core.graphics and core.graphics.get_mouse_wheel_delta})do if type(fn)=='function'then local ok,v=pcall(fn);if ok and type(v)=='number'and v~=0 then return v end end end;return 0
end
local function mode_options(spec,mode)
 local out,seen={},{};local function add(key)if not seen[key]and C.available(spec,mode,key)and C.control(spec,mode,key)then seen[key]=true;out[#out+1]=key end end
 for _,key in ipairs({'enabled','damage','cooldowns','aoe','automatic_burst'})do add(key)end
 for _,key in ipairs(C.spec_order[spec]or{})do add(key)end
 for page=1,7 do for _,key in ipairs(C.gui_groups(spec,mode,page))do add(key)end end
 return out
end
local function render_window()
 if C.is_mage~=true then if window then window:set_visibility(false)end;dragging=nil;mouse_was_down=false;G.f1_down=false;return end
 if not C.themed_gui or not C.themed_gui:get_state()or not core.menu.window then if window then window:set_visibility(false)end;return end
 local Color,V,Enums=require('common/color'),require('common/geometry/vector_2'),require('common/enums')
 local live_id=C.identity and themes[C.identity.id]and C.identity.id or nil;if live_id then G.last_spec=live_id end
 local spec=live_id or G.last_spec or 62;local theme=themes[spec];local live_mode=Modes.labels[C.mode]and C.mode or nil
 local scope=tostring(live_id)..':'..tostring(live_mode);if G.scope~=scope then G.scope=scope;G.editing=live_mode or G.editing;G.offset=0;G.page=1 end
 local we=Enums.window_enums or Enums;local fonts=we.font_id or{};local small,big=fonts.FONT_SMALL or 7,fonts.FONT_BIG or 8
 local function col(r,g,b,a)return Color.new(r,g,b,a or 255)end;local accent=col(theme.accent[1],theme.accent[2],theme.accent[3]);local white=col(242,241,231);local muted=col(184,192,194);local gold=col(theme.metal[1],theme.metal[2],theme.metal[3])
 if not window then window=core.menu.window('sylvanas_mage_command');window:set_initial_position(V.new(wx,wy));window:set_initial_size(V.new(W,H));if window.set_render_layer then window:set_render_layer(1)end end
 local cursor=type(core.get_cursor_position)=='function'and core.get_cursor_position()or nil;local mouse=false;if core.input and type(core.input.is_key_pressed)=='function'then local ok,v=pcall(core.input.is_key_pressed,1);mouse=ok and v==true end
 if cursor and mouse and not mouse_was_down and cursor.x>=wx and cursor.x<=wx+W and cursor.y>=wy and cursor.y<=wy+105 then dragging={x=cursor.x-wx,y=cursor.y-wy};if core.graphics and core.graphics.capture_next_mouse_input then pcall(core.graphics.capture_next_mouse_input)end end
 if dragging and mouse and cursor then local sw,sh=1920,1080;if core.graphics and core.graphics.get_screen_size then local ok,s=pcall(core.graphics.get_screen_size);if ok and s then sw,sh=s.x or sw,s.y or sh end end;wx=math.max(0,math.min(sw-W,cursor.x-dragging.x));wy=math.max(0,math.min(sh-H,cursor.y-dragging.y))elseif dragging and not mouse then dragging=nil end;mouse_was_down=mouse
 window:set_visibility(true);if window.force_window_size then window:force_window_size(V.new(W,H))end;if window.force_next_begin_window_pos then window:force_next_begin_window_pos(V.new(wx,wy))end
 local function rect(x,y,w,h,c,r)window:render_rect_filled(V.new(x,y),V.new(x+w,y+h),c,r or 4)end
 local function outline(x,y,w,h,c,r,t)if window.render_rect then window:render_rect(V.new(x,y),V.new(x+w,y+h),c,r or 4,t or 1)end end
 local function text(s,x,y,size,c)if window.render_text_custom_size then window:render_text_custom_size(small,V.new(x,y),c or white,size or 14,tostring(s))else window:render_text(size and size>=20 and big or small,V.new(x,y),c or white,tostring(s))end end
 local function button(label,x,y,w,h,fn,active,icon)local hover=window.is_mouse_hovering_rect and window:is_mouse_hovering_rect(V.new(x,y),V.new(x+w,y+h));Buttons.draw(window,V,Color,theme,spec,x,y,w,h,active,hover);local off=10;if icon then Icons.draw(icon,window,x+7,y+5,h-10,accent,spec);off=h+7 end;text(label,x+off,y+(h-14)/2-1,w<90 and 12 or 14,active and w<110 and col(12,22,18)or white);if window:is_rect_clicked(V.new(x,y),V.new(x+w,y+h))then fn()end end
 local function hotkey(spec_id,mode,key,x,y)local hk=C.hotkey(spec_id,mode,key);if not hk then return end;local on=hk.enabled:get_state();button(on and C.key_name(hk.code:get())or'HK OFF',x,y,103,30,function()begin_binding(spec_id,mode,key)end,on,'projectile')end
 local function toggle(widget,x,y)
  local on=value(widget)==true;local bg=on and col(math.floor(theme.accent[1]*.34),math.floor(theme.accent[2]*.34),math.floor(theme.accent[3]*.34),255)or col(18,27,31,255)
  rect(x+2,y+3,98,30,col(0,0,0,145),15);rect(x,y,98,30,bg,15);outline(x,y,98,30,on and accent or col(110,120,124),15,on and 2 or 1)
  if window.render_circle_filled then window:render_circle_filled(V.new(x+17,y+15),10,on and col(210,255,190)or col(104,111,115))else rect(x+7,y+5,20,20,on and accent or muted,10)end
  text(on and'ON'or'OFF',x+47,y+6,14,on and white or muted);if window:is_rect_clicked(V.new(x,y),V.new(x+98,y+30))then put(widget,not on)end
 end
 local function row(label,note,widget,hk_spec,hk_mode,key,y,icon)
  rect(292,y,680,50,col(8,20,24,235),6);outline(292,y,680,50,col(theme.metal[1],theme.metal[2],theme.metal[3],75),6,1);Icons.draw(icon or theme.icon,window,304,y+8,34,gold,spec);text(label,350,y+7,15);text((note or'Customer option'):sub(1,49),350,y+28,11,muted)
  local state=value(widget);if type(state)=='boolean'then hotkey(hk_spec,hk_mode,key,748,y+10);toggle(widget,861,y+10)else button('-',824,y+8,31,30,function()put(widget,math.max(0,state-1))end);text(tostring(state),871,y+13,14,accent);button('+',928,y+8,31,30,function()put(widget,math.min(100,state+1))end);rect(824,y+42,135,3,col(65,75,78),2);rect(824,y+42,135*state/100,3,accent,2)end
 end
 window:begin((we.window_resizing_flags or{}).RESIZE_BOTH_AXIS or 0,false,col(5,12,16),accent,(we.window_cross_visuals or{}).NO_CROSS or 9,function()
  if not Art.draw(spec,window,W,H)then rect(0,0,W,H,col(theme.dark[1],theme.dark[2],theme.dark[3]),0)end
  rect(13,13,974,734,col(4,12,15,190),12);outline(13,13,974,734,gold,12,2)
  rect(24,22,952,91,col(5,17,20,238),10);outline(24,22,952,91,col(theme.metal[1],theme.metal[2],theme.metal[3],180),10,1);Icons.draw(theme.icon,window,42,31,70,accent,spec)
  text(theme.title,127,34,theme.name=='FROST'and 23 or 27,gold);text(theme.name..' MAGE SUITE  •  v'..VERSION,130,72,13,white);text(theme.hero,650,38,11,accent);text(theme.tag,650,70,9,muted)
  button('—',901,34,31,27,function()C.themed_gui:set(false)end,false);button('X',939,34,28,27,function()C.themed_gui:set(false)end,false)
  rect(24,122,248,568,col(5,17,20,239),8);outline(24,122,248,568,col(theme.metal[1],theme.metal[2],theme.metal[3],120),8,1)
  for i,item in ipairs(nav)do local y=132+(i-1)*48;button(item[1],34,y,228,42,function()G.page=i;G.offset=0;if item[3]then G.editing=item[3]end end,G.page==i,item[2])end
  text(theme.name..' MAGIC',53,665,11,accent);text('ADAPT  •  CONTROL  •  CONQUER',53,681,9,muted)
  rect(282,122,694,568,col(4,13,17,242),8);outline(282,122,694,568,col(theme.metal[1],theme.metal[2],theme.metal[3],120),8,1)
  local selected=nav[G.page]or nav[1];local page_mode=selected[3];text(page_mode and (Modes.labels[page_mode]or page_mode):upper()..' CUSTOMIZATION'or selected[1],304,142,22,gold)
  text('LIVE: '..(live_id and theme.name or'WAITING')..' / '..(live_mode and Modes.labels[live_mode]or'DETECTING'),304,175,11,muted)
  button(C.enabled:get_state()and'PROFILE ACTIVE'or'PROFILE OFF',806,139,151,31,function()C.enabled:set(not C.enabled:get_state())end,C.enabled:get_state(),'burst')
  if page_mode then
   local list=mode_options(spec,page_mode);G.offset=math.min(G.offset,math.max(0,#list-6));for i=G.offset+1,math.min(#list,G.offset+6)do local key=list[i];row(C.label(spec,key),notes[key],C.control(spec,page_mode,key),spec,page_mode,key,211+(i-G.offset-1)*57,option_icons[key]or theme.icon)end
   button('<',790,657,48,26,function()G.offset=math.max(0,G.offset-6)end,false);button('>',846,657,48,26,function()if G.offset+6<#list then G.offset=G.offset+6 end end,false);text((G.offset+1)..'-'..math.min(#list,G.offset+6)..' / '..#list,910,663,10,muted)
   local wheel=window:is_mouse_hovering_rect(V.new(282,122),V.new(976,690))and wheel_delta()or 0;local now=U.number(U.fn(core.time))or 0;if wheel~=0 and now-last_wheel>.08 then G.offset=math.max(0,math.min(math.max(0,#list-6),G.offset+(wheel<0 and 6 or-6)));last_wheel=now end
  elseif G.page==1 then
   row('Enable Mage','Master customer switch',C.enabled,nil,nil,'enabled',211,'burst');row('Pause Mage','Stop actions while keeping the GUI open',C.pause,nil,nil,'pause',268,'control');row('DPS boss helper','Separate compact encounter coach',C.boss_guide,nil,nil,'boss_guide',325,'trophy');row('Training dummy testing','All supported major-city practice targets',C.dummy_test,nil,nil,'dummy_test',382,'projectile');row('Detailed combat logs','Persistent current and recovered sessions',C.logging,nil,nil,'logging',439,'eye');row('PvP burst permission','Manual live kill-window override',C.burst,nil,nil,'burst',496,'fire')
   local logger=require('sm_log');button('COPY CURRENT LOG',304,568,240,34,function()logger.copy(window,false,C.log_copy)end,false,'eye');button('COPY PREVIOUS LOG',552,568,240,34,function()logger.copy(window,true,C.log_copy)end,false,'eye');text((logger.copy_status or logger.status):sub(1,78),304,615,11,muted);text(C.status:sub(1,78),304,645,11,accent)
  elseif G.page==2 then
   local mode=live_mode or G.editing;local keys={'defensives','low_hp','turtle_hp','interrupts','interrupt_percent','remove_curse'};for i,key in ipairs(keys)do if C.available(spec,mode,key)then row(C.label(spec,key),notes[key],C.control(spec,mode,key),spec,mode,key,211+(i-1)*57,option_icons[key]or(key:find('hp')and'heal'or'shield'))end end;text('PLAYER OPTIONS FOLLOW '..theme.name..' / '..(Modes.labels[mode]or mode):upper(),304,657,11,accent)
  elseif G.page==11 then
   row('Enable option hotkeys','Master switch for all saved feature hotkeys',C.hotkeys_enabled,nil,nil,'hotkeys_enabled',211,'projectile');text('HOW TO BIND',304,291,16,gold);text('Open an activity page and click HK OFF beside any switch.',304,322,13);text('Press a key to save it. ESC clears the selected binding.',304,348,13,muted);text('F1 opens this window. F7 controls the boss helper.',304,374,13,muted);text('Only the detected spec and activity receive profile hotkeys.',304,400,13,accent);rect(302,446,654,65,col(8,20,24,235),6);text('HOTKEY STATUS',318,457,11,muted);text(C.hotkey_status:sub(1,76),318,482,13,accent);if G.binding then text('WAITING FOR KEY: '..C.label(G.binding.spec,G.binding.key),304,548,15,gold)end
  end
  rect(282,700,694,37,col(5,17,20,240),6);text('F1 OPEN/CLOSE  •  F7 BOSS HELPER  •  DRAG HEADER',300,710,11,muted);text(C.status:sub(1,48),626,710,11,accent)
 end)
end
function G.render()
 local ok,err=pcall(function()if C.is_mage~=true then if window then window:set_visibility(false)end;return end;local input=core.input;if input and type(input.is_key_pressed)=='function'then local read,down=pcall(input.is_key_pressed,0x70);if read and type(down)=='boolean'then if down and not G.f1_down and C.themed_gui then C.themed_gui:set(not C.themed_gui:get_state())end;G.f1_down=down end end;capture_binding();render_window()end)
 G.error=not ok and tostring(err)or nil;if not ok then C.status='Mage GUI error: '..tostring(err):sub(1,90);if G.logged_error~=G.error then require('sm_log').emit('error',{spec=C.identity and C.identity.id,mode=C.mode,identity=C.identity},C.status);G.logged_error=G.error end end
end
return G
