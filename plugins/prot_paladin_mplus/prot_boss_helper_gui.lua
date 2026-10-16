-- Compact, independent boss-mechanic panel. It detects the current class,
-- specialization and role every frame so the presentation cannot retain stale
-- character state after a reload or specialization change.
local M={}
local Guide,Host,color,vec2,enums,Settings,window
local R={x=40,y=180,w=590,h=408,reported=false,was_f7=false,boss_active=false,
 encounter_hidden=false,last_boss_active=false}
local class_names={[1]="WARRIOR",[2]="PALADIN",[3]="HUNTER",[4]="ROGUE",[5]="PRIEST",
 [6]="DEATH KNIGHT",[7]="SHAMAN",[8]="MAGE",[9]="WARLOCK",[10]="MONK",[11]="DRUID",
 [12]="DEMON HUNTER",[13]="EVOKER"}
local class_colors={[1]={198,155,109},[2]={245,140,186},[3]={171,212,115},[4]={255,245,105},
 [5]={235,235,235},[6]={196,31,59},[7]={0,112,222},[8]={105,204,240},[9]={135,136,238},
 [10]={0,255,152},[11]={255,125,10},[12]={163,48,201},[13]={51,147,127}}
local specs={[62]="ARCANE",[63]="FIRE",[64]="FROST",[65]="HOLY",[66]="PROTECTION",
 [70]="RETRIBUTION",[71]="ARMS",[72]="FURY",[73]="PROTECTION",[102]="BALANCE",
 [103]="FERAL",[104]="GUARDIAN",[105]="RESTORATION",[250]="BLOOD",[251]="FROST",
 [252]="UNHOLY",[253]="BEAST MASTERY",[254]="MARKSMANSHIP",[255]="SURVIVAL",
 [256]="DISCIPLINE",[257]="HOLY",[258]="SHADOW",[259]="ASSASSINATION",[260]="OUTLAW",
 [261]="SUBTLETY",[262]="ELEMENTAL",[263]="ENHANCEMENT",[264]="RESTORATION",
 [265]="AFFLICTION",[266]="DEMONOLOGY",[267]="DESTRUCTION",[268]="BREWMASTER",
 [269]="WINDWALKER",[270]="MISTWEAVER",[577]="HAVOC",[581]="VENGEANCE",
 [1467]="DEVASTATION",[1468]="PRESERVATION",[1473]="AUGMENTATION"}
local spec_roles={[65]="HEALER",[66]="TANK",[73]="TANK",[104]="TANK",[105]="HEALER",
 [250]="TANK",[256]="HEALER",[257]="HEALER",[264]="HEALER",[268]="TANK",
 [270]="HEALER",[581]="TANK",[1468]="HEALER"}
local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
local function clean(v)return tostring(v or ""):gsub("[%c]"," "):gsub("%s+"," ")end
local function short(v,n)v=clean(v);return require('mf_i18n').clip(require('mf_i18n').text(v),n) end
local function wrap(v,width,limit)
 v=clean(v);local out,line={},""
 for word in v:gmatch("%S+") do
  if #line>0 and #line+#word+1>width then out[#out+1]=line;line=word else line=line=="" and word or line.." "..word end
  if #out>=limit then break end
 end
 if #out<limit and line~="" then out[#out+1]=line end
 return out
end
local function step_lines(value)
 local out={};for part in clean(value):gmatch("%d+[^%d]+") do out[#out+1]=part:gsub("^%s+","") end
 if #out==0 then out=wrap(value,72,3) end
 return out
end
local function call(o,m,...)
 local f=o and o[m];if type(f)~="function" then return nil end
 local ok,v=pcall(f,o,...);return ok and v or nil
end
local function identity()
 local player=Host.manager("get_local_player");if not player then return nil end
 local class_id=tonumber(call(player,"get_class")) or 0
 local raw=tonumber(Host.static(core and core.spell_book,"get_specialization_id")) or 0
 local spec=raw
 if enums.class_spec_id and type(enums.class_spec_id.get_specialization_enum)=="function" then
  local ok,value=pcall(enums.class_spec_id.get_specialization_enum,class_id,raw)
  if ok and tonumber(value) then spec=tonumber(value) end
 end
 local role=string.upper(tostring(call(player,"get_role") or call(player,"get_assigned_role") or ""))
 if role=="DAMAGER" then role="DPS" end
 if role~="TANK" and role~="HEALER" and role~="DPS" then role=spec_roles[spec] or "DPS" end
 return class_names[class_id] or "CLASS",specs[spec] or ("SPEC "..tostring(spec)),role,class_colors[class_id] or {210,170,75}
end
function M.configure(settings)
 Settings=settings
 local ok,value=pcall(function()
  Guide=require("prot_boss_guides");Host=require("prot_host");color=require("common/color")
  vec2=require("common/geometry/vector_2");enums=require("common/enums")
  local w=core.menu.window("prot_paladin_boss_helper_61340")
  w:set_initial_position(vec2.new(R.x,R.y));w:set_initial_size(vec2.new(R.w,R.h))
  if type(w.set_render_layer)=="function" then w:set_render_layer(2) end
  w:set_visibility(true);return w
 end)
 if ok then window=value end
end
local function poll_hotkey()
 if not Host or not core.input or type(core.input.is_key_pressed)~="function" then return end
 local down=Host.static(core.input,"is_key_pressed",0x76)==true
 if down and not R.was_f7 then
  local showing=Settings.global_on("boss_helper_gui")
      or (Settings.global_on("boss_helper_auto") and R.boss_active and not R.encounter_hidden)
  Settings.global_set("boss_helper_gui",not showing)
  R.encounter_hidden=showing and R.boss_active or false
 end
 R.was_f7=down
end
function M.render()
 poll_hotkey()
 local visible=Settings and (Settings.global_on("boss_helper_gui")
  or (Settings.global_on("boss_helper_auto") and R.boss_active and not R.encounter_hidden))
 if not visible then
  if window then window:set_visibility(false) end;return true
 end
 local class_name,spec_name,role,tint=identity();if not class_name then
  if window then window:set_visibility(false) end;return true
 end
 if not window then return false,"boss helper window unavailable" end
 window:set_visibility(true)
 local success,failure=pcall(function()
  local we=enums.window_enums or enums;local flags=we.window_resizing_flags or {}
  local visuals=we.window_cross_visuals or {};local font=we.font_id or {}
  if type(window.set_next_window_min_size)=="function" then window:set_next_window_min_size(vec2.new(R.w,R.h)) end
  if type(window.force_window_size)=="function" then window:force_window_size(vec2.new(R.w,R.h)) end
  window:begin(flags.RESIZE_BOTH_AXIS or flags.RESIZE_BOTH or 0,false,c(5,14,24,238),
   c(tint[1],tint[2],tint[3]),visuals.NO_CROSS or 9,function()
    local accent=c(tint[1],tint[2],tint[3]);local active=Guide.active==true
    local action=string.upper(tostring(Guide.action or (active and "ACT" or "WATCH")))
    local title=class_name.." | "..spec_name.." | "..role
    window:render_rect_filled(vec2.new(8,8),vec2.new(582,48),c(8,24,39,245),7)
    window:render_rect(vec2.new(8,8),vec2.new(582,48),accent,7,2)
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,17),accent,"DUNGEON BOSS HELPER")
    window:render_text(font.FONT_SMALL or 7,vec2.new(188,17),c(225,235,244),short(title,48))
    window:render_rect_filled(vec2.new(521,13),vec2.new(573,43),c(41,28,22,245),5)
    window:render_rect(vec2.new(521,13),vec2.new(573,43),accent,5,1)
    window:render_text(font.FONT_SMALL or 7,vec2.new(532,21),c(245,231,205),"HIDE")
    if type(window.is_rect_clicked)=="function"
     and window:is_rect_clicked(vec2.new(521,13),vec2.new(573,43)) then
      Settings.global_set("boss_helper_gui",false);R.encounter_hidden=R.boss_active
    end
    window:render_rect_filled(vec2.new(8,56),vec2.new(582,395),c(7,20,33,242),7)
    window:render_rect(vec2.new(8,56),vec2.new(582,395),active and accent or c(69,91,108),7,1)
    local countdown=Guide.countdown and string.format("%.1fs",Guide.countdown) or "READY"
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,67),active and accent or c(145,167,184),action.."  "..countdown)
    window:render_text(font.FONT_SMALL or 7,vec2.new(150,67),c(241,244,247),short(Guide.mechanic or Guide.status,58))
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,94),c(133,164,188),"DO NOW")
    local do_lines=wrap(Guide.instruction or "Monitoring the current dungeon boss for your next job.",72,2)
    for i,line in ipairs(do_lines) do window:render_text(font.FONT_SMALL or 7,vec2.new(96,94+(i-1)*20),c(235,241,246),line) end
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,142),c(133,164,188),"YOUR STEPS")
    local steps=step_lines(Guide.steps or "Watch the cast bar and keep a safe lane open.")
    for i=1,math.min(3,#steps) do window:render_text(font.FONT_SMALL or 7,vec2.new(116,142+(i-1)*20),c(205,224,238),short(steps[i],72)) end
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,214),c(133,164,188),"POSITION")
    local pos_lines=wrap(Guide.position or "Keep clean floor behind the boss.",72,2)
    for i,line in ipairs(pos_lines) do window:render_text(font.FONT_SMALL or 7,vec2.new(116,214+(i-1)*20),c(232,204,138),line) end
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,266),c(133,164,188),"UP NEXT")
    local next_text=Guide.next_mechanic and (string.upper(tostring(Guide.next_action or "PREP")).." • "..Guide.next_mechanic
      .." • "..string.format("%.1fs",Guide.next_countdown or 0)) or "Waiting for the next recognized boss timer"
    window:render_text(font.FONT_SMALL or 7,vec2.new(116,266),c(224,187,93),short(next_text,72))
    if Guide.next_position then
     window:render_text(font.FONT_SMALL or 7,vec2.new(116,286),c(189,176,132),short(Guide.next_position,72))
    end
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,304),c(133,164,188),"ENCOUNTER")
    window:render_text(font.FONT_SMALL or 7,vec2.new(116,304),c(180,204,221),short(Guide.context or Guide.status,72))
    window:render_text(font.FONT_SMALL or 7,vec2.new(20,362),c(145,167,184),
     "Auto guide: boss casts + BigWigs/LittleWigs timers | F7 show/hide")
   end)
 end)
 if not success and not R.reported then R.reported=true
  if type(core.log_warning)=="function" then pcall(core.log_warning,"[Boss Helper GUI] "..tostring(failure)) end
 end
 return success,failure
end
function M.update(player)
 if not Guide or not Settings then return end
 local boss=false
 if player and call(player,"is_in_combat")==true then
  local frames=Host.manager("get_boss_frames")
  if type(frames)=="table" then for _,unit in pairs(frames) do
   if unit and call(unit,"is_valid")~=false and call(unit,"is_dead")~=true then boss=true;break end
  end end
 end
 R.boss_active=boss
 if boss and not R.last_boss_active then R.encounter_hidden=false end
 if not boss then R.encounter_hidden=false end
 R.last_boss_active=boss
 if Settings.global_on("boss_helper_gui") or Settings.global_on("boss_helper_auto") then
  Guide.update(player,true)
 end
end
return M
