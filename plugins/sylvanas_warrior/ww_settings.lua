local Modes,R=require('ww_modes'),require('ww_runtime')
local C={cells={},hotkeys={},global_hotkeys={},status='Waiting for warrior',identity=nil,mode=nil}
local specs={{71,'Arms'},{72,'Fury'},{73,'Protection'}}
C.bounds={pvp_trinket_window={0,120},block_refresh={0,10}}
function C.bound(key)
 local row=C.bounds[key];return row and row[1]or 0,row and row[2]or 100
end
function C.defaults(spec,mode)
 local pvp=Modes.pvp[mode]==true
 return {enabled=true,damage=true,defensives=true,interrupts=true,cooldowns=true,
  aoe=true,cc=true,taunt=true,charge=true,stances=true,pvp_lines=true,
  arena_peel=true,arena_control=true,mplus_stops=true,cooldown_min_enemies=mode=='mythic_plus' and 3 or 1,
  pvp_trinket_window=120,
  cooldown_min_ttd=mode=='mythic_plus' and 10 or 5,
  timer_defensives=true,automatic_burst=true,low_hp=spec==73 and 45 or 40,heal_hp=70,
  interrupt_percent=pvp and 35 or 55,ignore_pain_hp=85,block_refresh=4}
end
function C.init()
 C.root=core.menu.tree_node()
 local ns=R.prefix
 C.enabled=core.menu.checkbox(true,ns..'warrior_enabled_v2')
 C.burst=core.menu.checkbox(true,ns..'warrior_pvp_burst_v2')
 C.logging=core.menu.checkbox(true,ns..'warrior_logging_v2')
 C.pause=core.menu.checkbox(false,ns..'warrior_pause_v2')
 C.themed_gui=core.menu.checkbox(true,ns..'warrior_themed_gui_v2')
 C.route_map=core.menu.checkbox(true,ns..'warrior_prot_route_v2')
 C.boss_guide=core.menu.checkbox(true,ns..'warrior_prot_boss_guide_v2')
 C.training_dummy=core.menu.checkbox(true,ns..'warrior_training_dummy_v2')
 local function hotkey(initial,tag)
  if type(core.menu.keybind)=='function'then return core.menu.keybind(0,initial,tag)end
  local h={key=0,state=initial};function h:get_key_code()return self.key end;function h:set_key(v)self.key=v end
  function h:get_toggle_state()return self.state end;function h:set_toggle_state(v)self.state=v end
  function h:render()end;return h
 end
 for _,key in ipairs({'enabled','pause','themed_gui','burst','logging','route_map','boss_guide','training_dummy'})do
  C.global_hotkeys[key]=hotkey(C[key]:get_state(),ns..'global_'..key..'_hotkey_v3')
 end
 C.spec_nodes={}
 for _,s in ipairs(specs) do
  C.spec_nodes[s[1]]=core.menu.tree_node();C.cells[s[1]]={};C.hotkeys[s[1]]={}
  for _,mode in ipairs(Modes.order) do
   local cell={node=core.menu.tree_node(),controls={}};C.hotkeys[s[1]][mode]={}
   for key,value in pairs(C.defaults(s[1],mode)) do
    local tag=ns..s[1]..'_'..mode..'_'..key..'_v2'
    local minimum,maximum=C.bound(key)
    cell.controls[key]=type(value)=='boolean' and core.menu.checkbox(value,tag)
     or core.menu.slider_int(minimum,maximum,value,tag)
    if type(value)=='boolean'then C.hotkeys[s[1]][mode][key]=hotkey(value,tag..'_hotkey')end
   end
   C.cells[s[1]][mode]=cell
  end
 end
end
local function sync(control,hotkey)
 if not control or not hotkey or type(hotkey.get_toggle_state)~='function'then return end
 local state=hotkey:get_toggle_state();if type(state)=='boolean'and control:get_state()~=state then control:set(state)end
end
function C.sync_hotkeys()
 for key,h in pairs(C.global_hotkeys)do sync(C[key],h)end
 for spec,modes in pairs(C.hotkeys)do for mode,keys in pairs(modes)do for key,h in pairs(keys)do
  sync(C.control(spec,mode,key),h)
 end end end
end
function C.get(spec,mode)
 C.sync_hotkeys()
 local cell=C.cells[spec] and C.cells[spec][mode]
 if not cell then return nil end
 local out={}
 for k,c in pairs(cell.controls) do
  if c.get_state then out[k]=c:get_state() else out[k]=c:get() end
 end
 return out
end
local labels={enabled='Enable this spec and mode',damage='Damage rotation',defensives='Defensives',interrupts='Interrupts',
 cooldowns='Offensive cooldowns',aoe='Area damage',cc='Stun dangerous casts',taunt='Recover loose enemies with Taunt',stances='Automatic defensive stance',
 charge='Use Charge on engaged target',automatic_burst='Automatic PvP burst',low_hp='Major defensive health %',
 arena_peel='Arena ally peel and Intervene',mplus_stops='Mythic+ priority stops',
 arena_control='DR-safe enemy healer control during kill windows',
 pvp_lines='Draw lines to PvP target and enemy healer',
 pvp_trinket_window='Enemy PvP trinket cooldown seconds',
 timer_defensives='Use BigWigs or ExBoss timers for pre-mitigation',
 cooldown_min_enemies='Cooldown minimum enemies',cooldown_min_ttd='Cooldown minimum target life seconds',
 heal_hp='Victory healing health %',interrupt_percent='Interrupt cast progress %',ignore_pain_hp='Ignore Pain health %',block_refresh='Shield Block refresh seconds'}
local order={'enabled','damage','defensives','interrupts','cooldowns','aoe','cc','taunt','charge','pvp_lines','arena_peel','arena_control','mplus_stops','timer_defensives','stances','automatic_burst','pvp_trinket_window','cooldown_min_enemies','cooldown_min_ttd','low_hp','heal_hp','interrupt_percent','ignore_pain_hp','block_refresh'}
C.labels=labels;C.order=order
C.help={
 enabled='Master switch for this specialization and activity only.',damage='Run the selected specialization damage priority.',
 defensives='Trade personal defensives against confirmed pressure.',interrupts='Stop interruptible casts after the configured progress.',
 cooldowns='Spend major damage cooldowns only in valid windows.',aoe='Use multi-target attacks without pulling fresh enemies.',
 cc='Use spec-valid stuns on dangerous interruptible casts.',taunt='Protection PvE only: recover engaged loose enemies.',
 stances='Select the safe combat stance for this specialization.',charge='Close distance only to the current engaged target.',
 automatic_burst='Detect PvP kill windows without a manual request.',arena_peel='Arena only: Intervene allies under confirmed pressure.',
 pvp_lines='Arms and Fury PvP only: target line plus a healer line that turns red without line of sight.',
 arena_control='Arena only: DR-safe control on an exposed healer.',mplus_stops='Mythic+ only: prioritize dangerous casts and stops.',
 timer_defensives='Pre-mitigate known BigWigs or ExBoss pressure.',pvp_trinket_window='Treat a recently used enemy trinket as unavailable.',
 cooldown_min_enemies='Minimum engaged enemies before pack cooldowns.',cooldown_min_ttd='Hold cooldowns when the target will die too soon.',
 low_hp='Health threshold for a major defensive cooldown.',heal_hp='Health threshold for Victory Rush or Impending Victory.',
 interrupt_percent='Cast progress required before committing an interrupt.',ignore_pain_hp='Protection only: health threshold for Ignore Pain.',
 block_refresh='Protection only: refresh Shield Block below this time.'
}
C.units={pvp_trinket_window='s',cooldown_min_enemies=' targets',cooldown_min_ttd='s',low_hp='%',heal_hp='%',interrupt_percent='%',ignore_pain_hp='%',block_refresh='s'}
C.sections={
 rotation={'enabled','damage','cooldowns','aoe','automatic_burst','pvp_trinket_window','cooldown_min_enemies','cooldown_min_ttd'},
 defense={'defensives','low_hp','heal_hp','ignore_pain_hp','block_refresh','timer_defensives','stances'},
 utility={'interrupts','interrupt_percent','cc','charge','pvp_lines','taunt','arena_peel','arena_control','mplus_stops'}
}
C.global_options={
 {'PLUGIN ENABLED','enabled','Master switch for every Warrior profile.'},
 {'PAUSE ALL ACTIONS','pause','Stop casts while keeping the interface available.'},
 {'SHOW CUSTOM GUI','themed_gui','Show this compact F1 Warrior command window.'},
 {'ALLOW PVP BURST','burst','Permit automatic offensive cooldowns in PvP.'},
 {'RECORD DIAGNOSTICS','logging','Save crash-safe, copyable session diagnostics.'},
 {'ROUTE OVERLAY','route_map','Protection dungeon route and pull guidance.'},
 {'BOSS GUIDE','boss_guide','Role-specific tank or melee boss guidance.'}
 ,{'TRAINING DUMMIES','training_dummy','Run the active spec PvE rotation on selected city dummies.'}
}
function C.visible(spec,key,mode)
 if spec~=73 and(key=='taunt'or key=='ignore_pain_hp'or key=='block_refresh')then return false end
 if not mode then return true end
 if key=='taunt'then return spec==73 and not Modes.pvp[mode]and mode~='raid'end
 if key=='arena_peel'or key=='arena_control'or key=='pvp_trinket_window'then return mode=='arena'end
 if key=='mplus_stops'or key=='cooldown_min_enemies'then return mode=='mythic_plus'end
 if key=='automatic_burst'then return Modes.pvp[mode]==true end
 if key=='pvp_lines'then return(spec==71 or spec==72)and Modes.pvp[mode]==true end
 if key=='timer_defensives'then return mode=='dungeon'or mode=='mythic_plus'or mode=='raid'or mode=='delve'end
 return true
end
function C.gui_keys(spec,mode)
 local out={};for _,key in ipairs(order)do if C.visible(spec,key,mode)then out[#out+1]=key end end;return out
end
function C.control(spec,mode,key)return C.cells[spec]and C.cells[spec][mode]and C.cells[spec][mode].controls[key]end
function C.value(spec,mode,key)local x=C.control(spec,mode,key);if not x then return nil end;return x.get_state and x:get_state()or x:get()end
function C.set(spec,mode,key,value)
 local x=C.control(spec,mode,key);if not x or not x.set then return end
 if type(value)=='number'then local minimum,maximum=C.bound(key);value=math.max(minimum,math.min(maximum,value))end
 x:set(value)
 local h=C.hotkeys[spec]and C.hotkeys[spec][mode]and C.hotkeys[spec][mode][key]
 if type(value)=='boolean'and h and type(h.set_toggle_state)=='function'then h:set_toggle_state(value)end
end
function C.set_global(key,value)
 local x=C[key];if not x or type(value)~='boolean'then return end;x:set(value)
 local h=C.global_hotkeys[key];if h and type(h.set_toggle_state)=='function'then h:set_toggle_state(value)end
end
function C.hotkey(spec,mode,key)return C.hotkeys[spec]and C.hotkeys[spec][mode]and C.hotkeys[spec][mode][key]end
function C.render()
 C.root:render('Warrior: Arms / Fury / Protection',function()
  C.enabled:render('Enable warrior plugin',C.status)
  C.pause:render('Pause all warrior actions',C.status)
  C.themed_gui:render('Show Warrior command window','Code-rendered interface with automatic specialization pages.')
  C.route_map:render('Protection dungeon route overlay','Saved Season 2 pull guidance; Protection dungeon modes only.')
  C.boss_guide:render('Warrior boss helper overlay','Protection tank guidance or Arms/Fury DPS guidance; no image assets.')
  C.training_dummy:render('Enable training dummy testing','Run the active specialization on a selected attackable training dummy, even before combat starts.')
  C.burst:render('Allow PvP burst window','Turn off to hold major offensive cooldowns in PvP.')
  C.logging:render('Record warrior diagnostics',C.status)
  for _,row in ipairs(C.global_options)do local h=C.global_hotkeys[row[2]];if h then h:render(row[1]..' hotkey','Toggle '..row[1]:lower())end end
  for _,s in ipairs(specs) do
   C.spec_nodes[s[1]]:render(s[2],function()
    for _,mode in ipairs(Modes.order) do
     local cell=C.cells[s[1]][mode]
     cell.node:render(Modes.labels[mode],function()
      for _,key in ipairs(order) do
       if C.visible(s[1],key,mode) then
        cell.controls[key]:render(labels[key])
        local h=C.hotkeys[s[1]][mode][key];if h then h:render(labels[key]..' hotkey','Toggle this option')end
       end
      end
     end)
    end
   end)
  end
 end)
end
return C
