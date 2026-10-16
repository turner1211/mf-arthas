local Modes=require("druid_modes")
local Factory={}
local HOTKEYS={{"F1",0x70},{"F2",0x71},{"F3",0x72},{"F4",0x73},{"F5",0x74},{"F6",0x75},{"F7",0x76},{"F8",0x77},{"F9",0x78},{"F10",0x79},{"F11",0x7A},{"F12",0x7B},{"NUM 0",0x60},{"NUM 1",0x61},{"NUM 2",0x62},{"NUM 3",0x63},{"NUM 4",0x64},{"NUM 5",0x65},{"NUM 6",0x66},{"NUM 7",0x67},{"NUM 8",0x68},{"NUM 9",0x69}}
local MODE_ROWS={{"enabled","Enable this mode","Allow the profile to run in this play mode."},{"damage","Damage rotation","Use offensive spells when a valid target is safe."},{"cooldowns","Automatic cooldowns","Coordinate major damage or healing cooldowns."},{"defensives","Automatic defensives","React to current and predicted danger."},{"interrupts","Interrupts and stops","Use the specialization's interrupt and emergency stops."},{"utility","Dispel, control and support","Use dispels, crowd control and team utility."},{"aoe","Safe area actions","Use area spells only when nearby units are safe."}}
local GLOBAL_ROWS={{"enabled","Enable specialization","Master switch for this specialization."},{"gui","Show themed window","Show or hide this specialization's customer panel."},{"logging","Separate logging","Keep this specialization's independent persistent log."},{"dummy","Training dummy mode","Run the rotation on a selected city training dummy."}}
local HOTKEY_LABELS={};for _,row in ipairs(HOTKEYS) do HOTKEY_LABELS[#HOTKEY_LABELS+1]=row[1] end
local function state(cell)return cell and cell.get_state and cell:get_state() or false end
local function set_cell(cell,value)if cell and cell.set then cell:set(value==true)end end
function Factory.new(spec,key,label,theme,healer)
 local S={spec=spec,key=key,label=label,theme=theme,status="Starting",debug="Idle",cells={},hotkeys={},hotkey_order={}}
 local prefix="druid_suite_"..key.."_";S.root=core.menu.tree_node();S.hotkey_node=core.menu.tree_node();S.enabled=core.menu.checkbox(true,prefix.."enabled");S.gui=core.menu.checkbox(true,prefix.."gui");S.logging=core.menu.checkbox(true,prefix.."logging");S.dummy=core.menu.checkbox(false,prefix.."dummy");S.nodes={}
 local globals={enabled=S.enabled,gui=S.gui,logging=S.logging,dummy=S.dummy}
 for _,mode in ipairs(Modes.order) do local enabled=not(spec==3 and mode=="arena");S.nodes[mode]=core.menu.tree_node();S.cells[mode]={enabled=core.menu.checkbox(enabled,prefix..mode.."_enabled"),damage=core.menu.checkbox(true,prefix..mode.."_damage"),cooldowns=core.menu.checkbox(true,prefix..mode.."_cooldowns"),defensives=core.menu.checkbox(true,prefix..mode.."_defensives"),interrupts=core.menu.checkbox(true,prefix..mode.."_interrupts"),utility=core.menu.checkbox(true,prefix..mode.."_utility"),aoe=core.menu.checkbox(true,prefix..mode.."_aoe"),hp=core.menu.slider_int(10,95,healer and 82 or 55,prefix..mode.."_hp"),emergency=core.menu.slider_int(5,70,healer and 38 or 30,prefix..mode.."_emergency")}end
 local function register(id,text,cell,on,index)local safe=id:gsub("[^%w_]","_");S.hotkeys[id]={label=text,cell=cell,enabled=core.menu.checkbox(on==true,prefix.."hotkey_"..safe.."_enabled"),key=core.menu.combobox(index or 1,prefix.."hotkey_"..safe.."_key"),down=false};S.hotkey_order[#S.hotkey_order+1]=id end
 local gui_key=spec==1 and 2 or spec==2 and 3 or spec==4 and 4 or 1
 for _,row in ipairs(GLOBAL_ROWS)do register(row[1],row[2],globals[row[1]],row[1]=="gui",gui_key)end
 for _,mode in ipairs(Modes.order)do for _,row in ipairs(MODE_ROWS)do register(mode.."."..row[1],Modes.labels[mode].." — "..row[2],S.cells[mode][row[1]])end end
 function S.get(mode)local cell=S.cells[mode];if not cell then return end;local out={};for name,value in pairs(cell)do out[name]=value.get_state and value:get_state()or value:get()end;return out end
 function S.global_rows()return GLOBAL_ROWS end;function S.mode_rows()return MODE_ROWS end
 local function find(id)local cell=globals[id];if not cell then local mode,name=id:match("^([^.]+)%.(.+)$");cell=S.cells[mode]and S.cells[mode][name]end;return cell end
 function S.toggle(id)local cell=find(id);if cell and cell.get_state then set_cell(cell,not state(cell));return true end;return false end
 function S.value(id)local cell=find(id);if cell and cell.get_state then return state(cell)elseif cell and cell.get then return cell:get()end end
 function S.hotkey_name(id)local h=S.hotkeys[id];local i=h and tonumber(h.key:get())or 1;return HOTKEYS[i]and HOTKEYS[i][1]or"F1"end
 function S.hotkey_enabled(id)local h=S.hotkeys[id];return h and state(h.enabled)or false end
 function S.set_hotkey_enabled(id,value)local h=S.hotkeys[id];if h then set_cell(h.enabled,value)end end
 function S.cycle_hotkey(id,delta)local h=S.hotkeys[id];if not h then return end;local value=(tonumber(h.key:get())or 1)+(delta or 1);if value<1 then value=#HOTKEYS elseif value>#HOTKEYS then value=1 end;h.key:set(value)end
 function S.poll_hotkeys()
  if not core.input or type(core.input.is_key_pressed)~="function"then return end
  for _,id in ipairs(S.hotkey_order)do local h=S.hotkeys[id]
   if state(h.enabled)then local i=tonumber(h.key:get())or 1;local code=HOTKEYS[i]and HOTKEYS[i][2];local ok,down=pcall(core.input.is_key_pressed,code);down=ok and down==true;if down and not h.down then S.toggle(id)end;h.down=down else h.down=false end
  end
 end
 function S.render()
  S.root:render(label.." Druid 12.1.5",function()
   S.enabled:render("Enable "..label);S.gui:render(label.." themed window");S.logging:render("Separate "..label.." logging");S.dummy:render("Training dummy testing")
   for _,mode in ipairs(Modes.order)do S.nodes[mode]:render(Modes.labels[mode],function()local cell=S.cells[mode];for _,row in ipairs(MODE_ROWS)do cell[row[1]]:render(row[2],row[3])end;cell.hp:render(healer and"Proactive healing HP %"or"Recovery HP %");cell.emergency:render("Emergency HP %")end)end
   S.hotkey_node:render("Hotkeys",function()for _,id in ipairs(S.hotkey_order)do local h=S.hotkeys[id];h.enabled:render("Enable: "..h.label);h.key:render(h.label.." key",HOTKEY_LABELS)end end)
   core.menu.text("Mode: "..tostring(S.mode or"Waiting"));core.menu.text("Status: "..S.status);core.menu.text("Debugger: "..S.debug)
  end)
 end
 return S
end
return Factory
