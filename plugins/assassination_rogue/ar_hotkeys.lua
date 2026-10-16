-- Persistent customer hotkeys for every switch exposed by the Rogue GUI.
-- Unbound entries are excluded from the polling loop to keep the hot path small.
local M={capture=nil,status='Click a key pill, then press a keyboard key'}
local option_order={
 'enabled','damage','defensives','interrupt','cc','poisons','stealth','offensive_vanish',
 'auto_target','auto_face','fishing','looting','skinning','logging','predictive','bigwigs',
 'danger_zones','boss_coach','dummy_test','auto_dummy_target','auto_kill','step_cc','world_visuals',
 'spread_bleeds','combat_intel','replay_analysis','adaptive_performance'}
local profile_order={'damage','opener','cooldowns','cc','defensives'}
local profile_modes={'pve','mythic_plus','delve','arena','battleground','world_pvp'}
local binds,meta,assigned,down={},{},{},{}
local controls,profile_controls,profiles
local last_refresh=-math.huge
local helper_ok,KeyHelper=pcall(require,'common/utility/key_helper')
local names={
 [8]='BACKSPACE',[9]='TAB',[13]='ENTER',[16]='SHIFT',[17]='CTRL',[18]='ALT',[20]='CAPS',
 [27]='ESC / CLEAR',[32]='SPACE',[33]='PAGE UP',[34]='PAGE DOWN',[35]='END',[36]='HOME',
 [37]='LEFT',[38]='UP',[39]='RIGHT',[40]='DOWN',[45]='INSERT',[46]='DELETE',
 [186]=';',[187]='=',[188]=',',[189]='-',[190]='.',[191]='/',[192]='`',[219]='[',[220]='\\',[221]=']',[222]="'"}
local function title(value)
 value=tostring(value or ''):gsub('_',' ')
 return (value:gsub('(%a)([%w]*)',function(a,b)return a:upper()..b end))
end
local function make(id,label,kind,mode,field)
 local bind=core.menu.keybind(0,false,'ar_192_hotkey_'..id:gsub('[^%w]','_'))
 binds[id]=bind;meta[id]={id=id,label=label,kind=kind,mode=mode,field=field,bind=bind}
end
function M.attach(c,pc,p)
 if controls then return end
 controls,profile_controls,profiles=c,pc,p
 for _,key in ipairs(option_order) do make('toggle_'..key,title(key),'option',nil,key) end
 for _,mode in ipairs(profile_modes) do for _,field in ipairs(profile_order) do
  make('profile_'..mode..'_'..field,(profiles[mode] and profiles[mode].label or title(mode))..' / '..title(field),'profile',mode,field)
 end end
end
local function key_code(bind)
 local ok,v=pcall(bind.get_key_code,bind);return ok and tonumber(v) or 0
end
function M.key_name(code)
 code=tonumber(code) or 0
 if code==0 or code==7 or code==999 then return 'UNBOUND' end
 if helper_ok and KeyHelper then
  local ok,v=pcall(function()return KeyHelper:get_key_name(code)end)
  if ok and type(v)=='string' and v~='' then return v end
 end
 if code>=48 and code<=57 or code>=65 and code<=90 then return string.char(code) end
 if code>=112 and code<=123 then return 'F'..tostring(code-111) end
 return names[code] or 'KEY '..tostring(code)
end
function M.label(id)
 local bind=binds[id];return bind and M.key_name(key_code(bind)) or 'UNBOUND'
end
function M.begin_capture(id)
 if not binds[id] then return end
 M.capture=id;M.status='Listening for '..meta[id].label..' (ESC clears)'
end
local function set_key(id,code)
 local bind=binds[id];if not bind then return end
 local fn=bind.set_key_code or bind.set_key
 if type(fn)=='function' then pcall(fn,bind,code) end
 M.capture=nil;last_refresh=-math.huge
 M.status=(code==0 and 'Cleared ' or 'Bound '..M.key_name(code)..' to ')..meta[id].label
end
local function pressed(code)
 if not core.input or type(core.input.is_key_pressed)~='function' then return false end
 local ok,v=pcall(core.input.is_key_pressed,code);return ok and v==true
end
local function typing()
 if type(core.is_textbox_focused)=='function' then local ok,v=pcall(core.is_textbox_focused);return ok and v==true end
 return false
end
local function rebuild(n)
 if n-last_refresh<1 then return end
 last_refresh=n;assigned={}
 for id,bind in pairs(binds) do local code=key_code(bind)
  if code>7 and code~=999 then assigned[#assigned+1]={id=id,code=code} end
 end
end
local function flip(row)
 if row.kind=='option' then
  local control=controls and controls[row.field]
  if control then control:set(not control:get_state());return row.label..' '..(control:get_state() and 'ON' or 'OFF') end
 else
  local control=profile_controls and profile_controls[row.mode] and profile_controls[row.mode][row.field]
  if control then
   control:set(not control:get_state())
   if profiles and profiles[row.mode] then profiles[row.mode][row.field]=control:get_state()==true end
   return row.label..' '..(control:get_state() and 'ON' or 'OFF')
  end
 end
end
function M.poll(n)
 if typing() then return end
 if M.capture then
  -- Ignore mouse buttons that initiated capture. Escape intentionally clears.
  for code=8,254 do if pressed(code) then
   if not down['capture_'..code] then set_key(M.capture,code==27 and 0 or code) end
   down['capture_'..code]=true;return
  else down['capture_'..code]=false end end
  return
 end
 rebuild(n)
 local notice
 for i=1,#assigned do local item=assigned[i];local active=pressed(item.code);local token=item.id..':'..item.code
  if active and not down[token] then notice=flip(meta[item.id]) or notice end
  down[token]=active
 end
 return notice
end
function M.rows(filter)
 local rows={}
 for _,key in ipairs(option_order) do local id='toggle_'..key;local row=meta[id]
  if row and (not filter or filter(row)) then rows[#rows+1]=row end
 end
 for _,mode in ipairs(profile_modes) do for _,field in ipairs(profile_order) do local row=meta['profile_'..mode..'_'..field]
  if row and (not filter or filter(row)) then rows[#rows+1]=row end
 end end
 return rows
end
function M.toggle(id)
 local row=meta[id];if row then return flip(row) end
end
function M.binding(id) return binds[id] end
return M
