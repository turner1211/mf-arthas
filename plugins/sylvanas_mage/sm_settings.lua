local Modes,U=require('sm_modes'),require('sm_util')
local C={cells={},status='Mage ready',hotkey_down={},hotkey_status='Hotkeys ready'}
local specs={{62,'Arcane'},{63,'Fire'},{64,'Frost'}}
C.labels={pause='Pause Mage',themed_gui='Mage command window',boss_guide='DPS overlay and boss coach',logging='Detailed combat logs',burst='PvP burst permission',hotkeys_enabled='Enable option hotkeys',dummy_test='Training dummy testing',arcane_images='Refractive Images defense',enabled='Enable this profile',damage='Damage rotation',defensives='Defensive abilities',interrupts='Counterspell interrupts',priority_interrupts='Save interrupts for dangerous casts',
 cooldowns='Offensive cooldowns',aoe='Safe area damage',automatic_burst='Automatic PvP kill windows',arena_control='Arena healer Polymorph',
 automatic_peeling='Automatic PvP melee peeling',defensive_control='Defensive Polymorph for teammates',pvp_target_lines='PvP target and healer lines',pvp_roots='DR-safe roots under pressure',pvp_slow='Arcane Slow under pressure',
 temporal_defense='Safe ranged Alter Time defense',
 invisibility_defense='Greater Invisibility emergency defense',
 purge='Confirmed Spellsteal',remove_curse='Remove confirmed curses',intellect='Arcane Intellect upkeep',
 timer_defensives='Boss timer barrier preparation',low_hp='Barrier health %',turtle_hp='Emergency immunity health %',heal_hp='Refractive Images health %',
 interrupt_percent='Interrupt progress %',cooldown_min_ttd='Minimum target life for burst',cooldown_min_enemies='Mythic+ burst pack size',
 arcane_salvo='Salvo-aware Barrage',arcane_prismatic='Prismatic Bolt procs',arcane_missiles='Clearcasting Missiles',arcane_recovery='Safe mana recovery',arcane_reserve='Conserve below mana %',
 fire_hot_streak='Hot Streak spending',fire_blast='Heating Up conversion',fire_pyroclasm='Pyroclasm casts',fire_meteor='Safe Meteor damage',fire_flamestrike='Flamestrike target count',
 frost_freezing='Freezing stack spending',frost_orb='Safe Frozen Orb',frost_blizzard='Safe Blizzard',frost_spike='Glacial Spike procs',frost_ray='Ray of Frost channels',
 frost_ice_nova='Cone of Frost Ice Nova',frost_cone='Cone of Frost directional damage',frost_cold_snap='Emergency Cold Snap recovery'}
C.order={'enabled','damage','cooldowns','aoe','automatic_burst','defensives','temporal_defense','invisibility_defense','arcane_images','heal_hp','low_hp','turtle_hp','timer_defensives',
 'interrupts','interrupt_percent','priority_interrupts','arena_control','automatic_peeling','defensive_control','pvp_target_lines','pvp_roots','pvp_slow','purge','remove_curse','intellect','cooldown_min_ttd','cooldown_min_enemies'}
C.spec_order={[62]={'arcane_salvo','arcane_prismatic','arcane_missiles','arcane_recovery','arcane_reserve'},
 [63]={'fire_hot_streak','fire_blast','fire_pyroclasm','fire_meteor','fire_flamestrike'},
 [64]={'frost_freezing','frost_orb','frost_blizzard','frost_spike','frost_ray','frost_ice_nova','frost_cone','frost_cold_snap'}}
function C.available(spec,mode,key)
 for owner,list in pairs(C.spec_order)do for _,specific in ipairs(list)do if specific==key then return owner==spec end end end
 if key=='heal_hp' or key=='arcane_images' then return spec==62 end
 if key=='arena_control' then return mode=='arena' end
 if key=='automatic_peeling' then return Modes.pvp[mode]==true end
 if key=='defensive_control' then return Modes.pvp[mode]==true end
 if key=='pvp_target_lines' then return Modes.pvp[mode]==true end
 if key=='temporal_defense' then return Modes.pvp[mode]==true end
 if key=='invisibility_defense' then return Modes.pvp[mode]==true end
 if key=='pvp_roots' then return Modes.pvp[mode]==true end
 if key=='pvp_slow' then return spec==62 and Modes.pvp[mode]==true end
 if key=='automatic_burst' then return Modes.pvp[mode]==true end
 if key=='timer_defensives' or key=='cooldown_min_ttd' then return not Modes.pvp[mode] end
 if key=='cooldown_min_enemies' then return mode=='mythic_plus' end
 return true
end
function C.label(spec,key)return C.labels[key] or key end
function C.gui_groups(spec,mode,page)
 local groups={
  [1]={'enabled','damage','aoe'},
  [2]={'cooldowns','automatic_burst','cooldown_min_ttd','cooldown_min_enemies'},
  [3]={'interrupts','priority_interrupts','interrupt_percent','arena_control','defensive_control'},
  [4]={'automatic_peeling','pvp_roots','pvp_slow','pvp_target_lines'},
  [5]={'defensives','temporal_defense','invisibility_defense','arcane_images','heal_hp','low_hp','turtle_hp','timer_defensives'},
  [6]={'purge','remove_curse','intellect'},
 }
 local list=page==7 and C.spec_order[spec] or groups[page] or {};local out={}
 for _,key in ipairs(list)do if C.available(spec,mode,key)then out[#out+1]=key end end;return out
end
function C.defaults(spec,mode)
 local pvp=Modes.pvp[mode]==true
 local out={enabled=true,damage=true,defensives=true,interrupts=true,priority_interrupts=true,cooldowns=true,aoe=true,
 automatic_burst=true,arena_control=true,automatic_peeling=pvp,defensive_control=pvp,pvp_target_lines=pvp,temporal_defense=pvp,invisibility_defense=pvp,pvp_roots=pvp,pvp_slow=pvp and spec==62,purge=true,remove_curse=true,intellect=true,timer_defensives=not pvp,
 low_hp=75,turtle_hp=18,heal_hp=40,interrupt_percent=pvp and 35 or 55,
 cooldown_min_ttd=mode=='mythic_plus' and 10 or 5,cooldown_min_enemies=mode=='mythic_plus' and 3 or 1}
 for _,key in ipairs(C.spec_order[spec])do out[key]=true end
 if spec~=62 then out.heal_hp=nil end
 if spec==62 then out.arcane_images=true;out.arcane_reserve=20 elseif spec==63 then out.fire_flamestrike=3 end
 return out
end
function C.init()
 C.root=core.menu.tree_node();C.spec_nodes={};C.global_hotkeys={}
 for _,k in ipairs({'enabled','pause','themed_gui','boss_guide','logging','burst','dummy_test'})do
 C[k]=core.menu.checkbox(k~='pause','sm_global_'..k..'_v1') end
 C.hotkeys_enabled=core.menu.checkbox(true,'sm_global_hotkeys_enabled_v1')
 for _,key in ipairs({'enabled','pause','themed_gui','boss_guide','logging','burst','dummy_test'})do
  C.global_hotkeys[key]={enabled=core.menu.checkbox(false,'sm_global_hk_enabled_'..key..'_v1'),code=core.menu.slider_int(0,255,0,'sm_global_hk_code_'..key..'_v1')}
 end
 for _,s in ipairs(specs)do
 C.spec_nodes[s[1]]=core.menu.tree_node();C.cells[s[1]]={}
 for _,mode in ipairs(Modes.order)do local cell={node=core.menu.tree_node(),controls={},hotkeys={}}
 for key,v in pairs(C.defaults(s[1],mode))do local tag='sm_'..s[1]..'_'..mode..'_'..key..'_v1'
 cell.controls[key]=type(v)=='boolean' and core.menu.checkbox(v,tag) or core.menu.slider_int(0,100,v,tag)
 if type(v)=='boolean'then cell.hotkeys[key]={enabled=core.menu.checkbox(false,tag..'_hk_enabled_v1'),code=core.menu.slider_int(0,255,0,tag..'_hk_code_v1')}end end
 C.cells[s[1]][mode]=cell end end
 -- Apply the user's enable-all request once, including existing saved profiles.
 -- This marker is persisted; subsequent user choices remain untouched.
 C.enable_all_migration=core.menu.checkbox(false,'sm_enable_all_migration_v2')
 if not C.enable_all_migration:get_state()then
  for _,key in ipairs({'enabled','themed_gui','boss_guide','logging','burst','dummy_test'})do C[key]:set(true)end
  for _,entry in ipairs(specs)do for _,mode in ipairs(Modes.order)do
   for key,default in pairs(C.defaults(entry[1],mode))do
    if type(default)=='boolean' and C.available(entry[1],mode,key)then C.cells[entry[1]][mode].controls[key]:set(true)end
   end
  end end
  C.enable_all_migration:set(true)
 end
end
local key_names={[8]='BACKSPACE',[9]='TAB',[13]='ENTER',[16]='SHIFT',[17]='CTRL',[18]='ALT',[20]='CAPS',[27]='ESC',[32]='SPACE',[33]='PGUP',[34]='PGDN',[35]='END',[36]='HOME',[37]='LEFT',[38]='UP',[39]='RIGHT',[40]='DOWN',[45]='INSERT',[46]='DELETE'}
for n=1,12 do key_names[111+n]='F'..n end
function C.key_name(code)
 code=tonumber(code)or 0;if code==0 then return'UNBOUND'end
 if key_names[code]then return key_names[code]end
 if code>=48 and code<=57 or code>=65 and code<=90 then return string.char(code)end
 return'KEY '..code
end
function C.hotkey(spec,mode,key)
 if spec==nil then return C.global_hotkeys and C.global_hotkeys[key]end
 local cell=C.cells[spec]and C.cells[spec][mode];return cell and cell.hotkeys and cell.hotkeys[key]
end
function C.assign_hotkey(spec,mode,key,code)
 local hk=C.hotkey(spec,mode,key);if not hk then return end
 hk.code:set(code);hk.enabled:set(code>0);C.hotkey_down[code]=true
 C.hotkey_status=(code>0 and C.label(spec,key)..' bound to '..C.key_name(code)or C.label(spec,key)..' cleared')
end
function C.poll_hotkeys(spec,mode)
 if not C.hotkeys_enabled or not C.hotkeys_enabled:get_state()then return end
 if core.is_textbox_focused and U.fn(core.is_textbox_focused)==true then return end
 local input=core.input;if not input or type(input.is_key_pressed)~='function'then return end
 local actions={}
 local function add(scope,key,widget,hk)
  if widget and hk and hk.enabled:get_state()then local code=hk.code:get();if code and code>0 then
   local list=actions[code]or{};list[#list+1]={scope=scope,key=key,widget=widget};actions[code]=list
  end end
 end
 for key,hk in pairs(C.global_hotkeys or{})do add('global',key,C[key],hk)end
 local cell=C.cells[spec]and C.cells[spec][mode]
 if cell then for key,hk in pairs(cell.hotkeys)do if C.available(spec,mode,key)then add('profile',key,cell.controls[key],hk)end end end
 for code,list in pairs(actions)do
  local ok,down=pcall(input.is_key_pressed,code);down=ok and down==true
  if down and not C.hotkey_down[code]then
   if code==0x70 or code==0x76 then C.hotkey_status=C.key_name(code)..' is reserved for a Mage window'
   elseif #list>1 then C.hotkey_status='Conflict: '..C.key_name(code)..' has '..#list..' active actions'
   else local a=list[1];a.widget:set(not a.widget:get_state());C.hotkey_status=C.label(spec,a.key)..' '..(a.widget:get_state()and'ON'or'OFF')..' / '..C.key_name(code)end
  end
  C.hotkey_down[code]=down
 end
 for code in pairs(C.hotkey_down)do if not actions[code]then C.hotkey_down[code]=nil end end
end
function C.information(spec,mode)
 local function state(v)if type(v)=='boolean'then return v and 'ON' or 'OFF'end;return tostring(v)end
 local rows={
  {'Enable Mage',state(C.enabled and C.enabled:get_state())},
  {'Pause Mage',state(C.pause and C.pause:get_state())},
  {'Mage command window',state(C.themed_gui and C.themed_gui:get_state())},
  {'DPS overlay and boss coach',state(C.boss_guide and C.boss_guide:get_state())},
  {'Allow PvP burst',state(C.burst and C.burst:get_state())},
  {'Detailed combat logs',state(C.logging and C.logging:get_state())},
  {'Training dummy testing',state(C.dummy_test and C.dummy_test:get_state())},
 }
 if spec and mode and C.cells[spec] and C.cells[spec][mode]then
  for _,key in ipairs(C.order)do if C.available(spec,mode,key)then rows[#rows+1]={C.label(spec,key),state(C.value(spec,mode,key))}end end
  for _,key in ipairs(C.spec_order[spec] or {})do rows[#rows+1]={C.label(spec,key),state(C.value(spec,mode,key))}end
 end
 return rows
end
function C.control(spec,mode,key)return C.cells[spec] and C.cells[spec][mode] and C.cells[spec][mode].controls[key]end
function C.value(spec,mode,key)local x=C.control(spec,mode,key);if x then if x.get_state then return x:get_state()elseif x.get then return x:get()end end end
function C.set(spec,mode,key,v)local x=C.control(spec,mode,key);if x and x.set then x:set(v)end end
function C.get(spec,mode)if not C.cells[spec] or not C.cells[spec][mode]then return end;local out={};for k in pairs(C.cells[spec][mode].controls)do out[k]=C.value(spec,mode,k)end;return out end
function C.render()
 local player=core and core.object_manager and U.fn(core.object_manager.get_local_player)
 if not U.valid(player) or U.number(U.call(player,'get_class'))~=8 then return end
 C.root:render('Mage: Arcane / Fire / Frost',function()
 C.enabled:render('Enable Mage',C.status);C.pause:render('Pause Mage');C.themed_gui:render('Mage command window')
 C.boss_guide:render('DPS overlay and boss coach');C.burst:render('Allow PvP burst');C.logging:render('Detailed combat logs');C.dummy_test:render('Training dummy testing')
 -- Full per-spec and per-mode settings live in the custom Mage command GUI.
 -- Rendering all 24 nested profile trees makes this loader build throw an
 -- opaque native error table, so the standard menu stays a stable launcher.
 end)
end
return C
