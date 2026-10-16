local Modes=require('hh_modes')
local Runtime=require('hh_runtime')
local C={cells={},status='Hunter ready',identity=nil,mode=nil}
local specs={{253,'Beast Mastery'},{254,'Marksmanship'},{255,'Survival'}}
C.labels={enabled='Enable this profile',damage='Damage rotation',defensives='Defensive abilities',interrupts='Interrupts',
 cooldowns='Offensive cooldowns',aoe='Safe area damage',cc='DR-safe stun stops',automatic_burst='Automatic PvP kill windows',pvp_lines='Target and healer world lines',
 execute='Execute abilities',urgent_interrupts='Immediate dangerous-channel interrupts',cc_interrupt_fallback='CC fallback for critical casts',
 predictive_defensives='Predictive defensive timing',team_roar='Roar of Sacrifice for teammates',critical_pet_exhilaration='Exhilaration for critically injured pet',
 auto_kite='Automatic PvP slows and root removal',target_line='PvP target line',healer_line='PvP healer line',training_dummy='Training-dummy rotation mode',
 manual_pause='Pause briefly after manual casts',performance_telemetry='Performance timing in diagnostic logs',boss_world_cues='Boss direction lines and rings',boss_auto_popup='Open boss helper when combat begins',
 arena_control='Arena healer trap assistance',arena_scatter='Scatter Shot emergency off-target peel',arena_sting='Chimaeral Sting after healer Trap',pet_recovery='Call or safely revive pet',pet_heal='Mend injured pet',pet_hp='Pet healing health %',
 purge='Tranquilizing Shot dispels',misdirection='PvE tank or solo pet Misdirection',harpoon='Harpoon to engaged target',
 timer_defensives='Boss timer defensive preparation',low_hp='Fittest health %',turtle_hp='Turtle emergency health %',heal_hp='Exhilaration health %',
 feign='Feign Death incoming casts',roar='Roar of Sacrifice focused pressure',masters_healer="Master's Call rooted Arena healer",
 arena_cc_min='Minimum healer CC left for burst',arena_trinket_window='Enemy healer trinket window',
 interrupt_percent='Interrupt progress %',cooldown_min_ttd='Minimum target life for burst',cooldown_min_enemies='Mythic+ burst pack size'}
C.order={'enabled','damage','execute','training_dummy','manual_pause','cooldowns','aoe','automatic_burst','arena_cc_min','arena_trinket_window','pvp_lines','target_line','healer_line','auto_kite','defensives','predictive_defensives','feign','roar','team_roar','masters_healer','critical_pet_exhilaration','heal_hp','low_hp','turtle_hp','timer_defensives','boss_world_cues','boss_auto_popup','performance_telemetry',
 'interrupts','urgent_interrupts','cc_interrupt_fallback','interrupt_percent','cc','arena_control','arena_scatter','arena_sting','purge','misdirection','harpoon','pet_recovery','pet_heal','pet_hp','cooldown_min_ttd','cooldown_min_enemies'}
C.spec_order={[253]={'bm_barbed_setup','bm_cleave','bm_focus_pool','bm_dire_beast','bm_dark_ranger'},
 [254]={'mm_precise','mm_trick','mm_explosive','mm_volley','mm_chakram'},
 [255]={'sv_tip','sv_bombs','sv_boomstick','sv_chakram','sv_eagle'}}
if Runtime.family=='forever'then C.spec_order={[253]={'forever_hawk','forever_pet_first','forever_stings','forever_readiness','forever_mana_pool'},[254]={'forever_sniper','forever_lone_wolf','forever_stings','forever_readiness','forever_mana_pool'},[255]={'forever_melee','forever_lacerate','forever_traps','forever_stings','forever_pvp_tracking','forever_readiness','forever_mana_pool'}}end
local specific_labels={bm_barbed_setup='Barbed Shot burst preparation',bm_cleave='Beast Cleave upkeep',bm_focus_pool='Reserve Focus for Kill Command',
 bm_dire_beast='Dire Beast damage',bm_dark_ranger='Dark Ranger arrows',mm_precise='Spend Precise Shots',mm_trick='Trick Shots upkeep',
 mm_explosive='Explosive Shot damage',mm_volley='Volley cleave setup',mm_chakram='Sentinel Moonlight Chakram',
 sv_tip='Tip of the Spear preparation',sv_bombs='Wildfire Bomb damage',sv_boomstick='Empowered Boomstick',sv_chakram='Sentinel Moonlight Chakram',sv_eagle='Aspect of the Eagle at range'}
for k,v in pairs(specific_labels)do C.labels[k]=v end
for k,v in pairs({forever_hawk='Summon Hawk upkeep',forever_pet_first='Pet-first engagement safety',forever_stings='Adaptive Forever sting selection',forever_traps='Survival Fire/Frost trap logic',forever_pvp_tracking='Track Humanoids for Improved Tracking',forever_readiness='Readiness reset planning',forever_mana_pool='Preserve mana reserve',forever_sniper='Sniper Shot priority',forever_lone_wolf='Lone Wolf petless mode',forever_melee='Survival melee rotation',forever_lacerate='Lacerating Strikes upkeep'})do C.labels[k]=v end
function C.available(spec,mode,key)
 if Runtime.family=='forever'and key=='forever_pvp_tracking'then return spec==255 and Modes.pvp[mode]==true end
 if Runtime.family=='forever' and (key=='interrupts'or key=='urgent_interrupts'or key=='cc_interrupt_fallback')then return spec==253 end
 if Runtime.family=='forever' and ({purge=true,misdirection=true,harpoon=true,team_roar=true,masters_healer=true,roar=true,critical_pet_exhilaration=true})[key]then return false end
 if key=='harpoon' then return spec==255 end
 if key=='arena_control' or key=='arena_scatter' or key=='arena_sting' or key=='arena_cc_min' or key=='arena_trinket_window' then return mode=='arena' end
 if key=='automatic_burst' then return Modes.pvp[mode]==true end
 if key=='pvp_lines' or key=='target_line' or key=='healer_line' or key=='auto_kite' then return Modes.pvp[mode]==true end
 if key=='feign' or key=='roar' then return Modes.pvp[mode]==true end
 if key=='masters_healer' then return mode=='arena' end
 if key=='misdirection' or key=='timer_defensives' or key=='cooldown_min_ttd' or key=='boss_world_cues' or key=='boss_auto_popup' then return not Modes.pvp[mode] end
 if key=='cooldown_min_enemies' then return mode=='mythic_plus' end
 return true
end
function C.label(spec,key)
 if Runtime.family=='forever'and key=='interrupts'then return 'Intimidation cast stops' end
 if Runtime.family=='forever'and key=='urgent_interrupts'then return 'Immediate Intimidation stops' end
 if Runtime.family=='forever'and key=='cc_interrupt_fallback'then return 'Pet-stun fallback for critical casts' end
 if key=='interrupts' then return spec==255 and 'Muzzle interrupts' or 'Counter Shot interrupts' end
 if key=='cc' then return spec==254 and 'DR-safe Ranger stun stops' or 'DR-safe Intimidation stops' end
 return C.labels[key] or key
end
function C.gui_groups(spec,mode,page)
 local groups={{'enabled','training_dummy','manual_pause','performance_telemetry','boss_world_cues','boss_auto_popup'},
  {'damage','execute','aoe','cooldown_min_ttd','cooldown_min_enemies'},
  {'cooldowns','automatic_burst','arena_cc_min','arena_trinket_window'},
  {'interrupts','urgent_interrupts','cc_interrupt_fallback','interrupt_percent','cc','arena_control','arena_scatter','arena_sting','purge'},
  {'defensives','predictive_defensives','feign','roar','team_roar','masters_healer','heal_hp','low_hp','turtle_hp','timer_defensives'},
  {'pet_recovery','pet_heal','critical_pet_exhilaration','pet_hp','misdirection'},
  {'harpoon','auto_kite'},
  {'pvp_lines','target_line','healer_line'},
  C.spec_order[spec] or {}}
 local list=groups[page] or {};local out={}
 for _,key in ipairs(list)do if C.available(spec,mode,key)then out[#out+1]=key end end
 return out
end
function C.defaults(spec,mode)
 local pvp=Modes.pvp[mode]==true
 local out={enabled=true,damage=true,defensives=true,interrupts=true,cooldowns=true,aoe=true,cc=true,
 execute=true,training_dummy=true,manual_pause=true,performance_telemetry=true,urgent_interrupts=true,cc_interrupt_fallback=true,predictive_defensives=true,team_roar=true,critical_pet_exhilaration=true,auto_kite=true,target_line=true,healer_line=true,boss_world_cues=true,boss_auto_popup=true,
 automatic_burst=true,pvp_lines=true,arena_control=true,arena_scatter=true,arena_sting=true,feign=true,roar=true,masters_healer=true,pet_recovery=true,pet_heal=true,pet_hp=65,
 purge=true,misdirection=true,harpoon=true,timer_defensives=true,
 low_hp=45,turtle_hp=20,heal_hp=65,interrupt_percent=pvp and 35 or 55,
 cooldown_min_ttd=mode=='mythic_plus' and 10 or 5,cooldown_min_enemies=mode=='mythic_plus' and 3 or 1,
 arena_cc_min=1,arena_trinket_window=90}
 for _,key in ipairs(C.spec_order[spec] or {})do out[key]=true end
 return out
end
function C.init()
 C.root=core.menu.tree_node();C.spec_nodes={};C.hotkey_node=core.menu.tree_node();C.hotkeys={};C.hotkey_down={}
 for _,k in ipairs({'enabled','pause','themed_gui','boss_guide','logging','burst'}) do
  C[k]=core.menu.checkbox(k~='pause',Runtime.storage_prefix..'global_'..k..(k=='pause' and '_v1' or '_v2'))
 end
 for _,s in ipairs(specs) do
  C.spec_nodes[s[1]]=core.menu.tree_node();C.cells[s[1]]={}
  for _,mode in ipairs(Modes.order) do
   local cell={node=core.menu.tree_node(),controls={}}
   for key,v in pairs(C.defaults(s[1],mode)) do
    local tag=Runtime.storage_prefix..s[1]..'_'..mode..'_'..key..(type(v)=='boolean' and '_v2' or '_v1')
    cell.controls[key]=type(v)=='boolean' and core.menu.checkbox(v,tag) or core.menu.slider_int(0,100,v,tag)
   end
   C.cells[s[1]][mode]=cell
  end
 end
 local seen={};C.hotkey_order={}
 local function add_hotkey(key)
  if seen[key] then return end;seen[key]=true;C.hotkey_order[#C.hotkey_order+1]=key
  C.hotkeys[key]=core.menu.keybind and core.menu.keybind(7,false,Runtime.storage_prefix..'bind_'..key..'_v1') or nil
 end
 for _,key in ipairs({'enabled','pause','themed_gui','boss_guide','logging','burst'})do add_hotkey(key)end
 for _,key in ipairs(C.order)do
  for _,s in ipairs(specs)do for _,mode in ipairs(Modes.order)do
   if type(C.defaults(s[1],mode)[key])=='boolean'then add_hotkey(key)end
  end end
 end
 for _,list in pairs(C.spec_order)do for _,key in ipairs(list)do add_hotkey(key)end end
end
function C.hotkey(key)return C.hotkeys and C.hotkeys[key]end
function C.hotkey_options(spec,mode)
 local out={'enabled','pause','themed_gui','boss_guide','logging','burst'}
 for _,key in ipairs(C.order)do if C.available(spec,mode,key)and type(C.defaults(spec,mode)[key])=='boolean'then out[#out+1]=key end end
 for _,key in ipairs(C.spec_order[spec]or{})do out[#out+1]=key end
 return out
end
function C.key_code(key)local h=C.hotkey(key);return h and h.get_key_code and h:get_key_code()or 7 end
function C.key_name(code)
 code=tonumber(code)or 7;if code==7 then return 'UNBOUND' end
 if code>=48 and code<=57 or code>=65 and code<=90 then return string.char(code)end
 if code>=112 and code<=123 then return 'F'..tostring(code-111)end
 return ({[8]='BACKSPACE',[9]='TAB',[13]='ENTER',[16]='SHIFT',[17]='CTRL',[18]='ALT',[27]='ESC',[32]='SPACE',[45]='INSERT',[46]='DELETE'})[code]or('KEY '..code)
end
function C.start_bind(key,now)if C.hotkey(key)then C.binding=key;C.bind_after=(tonumber(now)or 0)+.2;C.bind_notice='Press a key; ESC clears the bind.'end end
local globals={enabled=true,pause=true,themed_gui=true,boss_guide=true,logging=true,burst=true}
function C.poll_hotkeys(spec,mode,now)
 local input=core.input;if not input or type(input.is_key_pressed)~='function'then return end
 now=tonumber(now)or 0
 if C.binding and now>=(C.bind_after or 0)then
  for code=8,255 do
   local ok,down=pcall(input.is_key_pressed,code)
   if ok and down then
    local chosen=code==27 and 7 or code
    if chosen==112 or chosen==118 then C.bind_notice='F1 and F7 are reserved for the two Hunter windows.';C.binding=nil;return end
    for key,h in pairs(C.hotkeys)do if key~=C.binding and h and h.get_key_code and h:get_key_code()==chosen and h.set_key_code then h:set_key_code(7)end end
    local h=C.hotkey(C.binding);if h and h.set_key_code then h:set_key_code(chosen)elseif h and h.set_key then h:set_key(chosen)end
    C.bind_notice=C.binding..' = '..C.key_name(chosen);C.binding=nil;return
   end
  end
  return
 end
 for _,key in ipairs(C.hotkey_order or {})do
  local code=C.key_code(key);local down=false
  if code>7 then local ok,v=pcall(input.is_key_pressed,code);down=ok and v==true end
  if down and not C.hotkey_down[key]then
   local control=globals[key]and C[key]or C.control(spec,mode,key)
   if control and control.get_state and control.set then control:set(not control:get_state());C.bind_notice=C.label(spec,key)..' toggled by '..C.key_name(code)end
  end
  C.hotkey_down[key]=down
 end
end
function C.control(spec,mode,key)return C.cells[spec] and C.cells[spec][mode] and C.cells[spec][mode].controls[key]end
function C.value(spec,mode,key)
 local x=C.control(spec,mode,key);if not x then return nil end
 if x.get_state then return x:get_state() end
 if x.get then return x:get() end
end
function C.set(spec,mode,key,value)local x=C.control(spec,mode,key);if x and x.set then x:set(value)end end
function C.get(spec,mode)
 if not C.cells[spec] or not C.cells[spec][mode] then return nil end
 local out={};for k in pairs(C.cells[spec][mode].controls) do out[k]=C.value(spec,mode,k)end;return out
end
function C.render()
 C.root:render('Hunter: BM / MM / Survival',function()
  C.enabled:render('Enable Hunter',C.status)
  C.pause:render('Pause Hunter');C.themed_gui:render('Show themed Hunter command window')
  C.boss_guide:render('DPS overlay and boss coach');C.burst:render('Allow PvP burst');C.logging:render('Diagnostics')
  for _,s in ipairs(specs) do C.spec_nodes[s[1]]:render(s[2],function()
   for _,mode in ipairs(Modes.order) do local cell=C.cells[s[1]][mode];cell.node:render(Modes.labels[mode],function()
    for _,key in ipairs(C.order) do if C.available(s[1],mode,key)then cell.controls[key]:render(C.label(s[1],key))end end
    for _,key in ipairs(C.spec_order[s[1]])do cell.controls[key]:render(C.label(s[1],key))end
   end)end
  end)end
  C.hotkey_node:render('Hunter hotkeys',function()
   for _,key in ipairs(C.hotkey_order or {})do local h=C.hotkey(key);if h then h:render(C.labels[key]or key,'Toggles the option for the active specialization and activity.')end end
  end)
 end)
end
return C
