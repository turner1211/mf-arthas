-- Compact class/spec-aware boss helper. The Guardian loader still owns the
-- final class guard so this window can never leak into another plugin.
local Settings=require("guardian_settings")
local Encounters=require("guardian_encounters")
local BigWigs=require("guardian_bigwigs")
local Log=require("guardian_log")
local Color=require("common/color")
local vec2=require("common/geometry/vector_2")
local enums=require("common/enums")
local M={}
local window,f7_was_down,last_profile,hidden_profile
local classes={
 [1]="Warrior",[2]="Paladin",[3]="Hunter",[4]="Rogue",[5]="Priest",[6]="Death Knight",[7]="Shaman",
 [8]="Mage",[9]="Warlock",[10]="Monk",[11]="Druid",[12]="Demon Hunter",[13]="Evoker"}
local specs={
 [1]={"Arms","Fury","Protection"},[2]={"Holy","Protection","Retribution"},[3]={"Beast Mastery","Marksmanship","Survival"},
 [4]={"Assassination","Outlaw","Subtlety"},[5]={"Discipline","Holy","Shadow"},[6]={"Blood","Frost","Unholy"},
 [7]={"Elemental","Enhancement","Restoration"},[8]={"Arcane","Fire","Frost"},[9]={"Affliction","Demonology","Destruction"},
 [10]={"Brewmaster","Mistweaver","Windwalker"},[11]={"Balance","Feral","Guardian","Restoration"},
 [12]={"Havoc","Vengeance"},[13]={"Devastation","Preservation","Augmentation"}}
local themes={
 [1]={117,65,45},[2]={183,72,125},[3]={72,130,58},[4]={130,120,38},[5]={100,112,125},[6]={118,36,45},
 [7]={40,80,170},[8]={45,125,170},[9]={110,62,150},[10]={35,130,95},[11]={44,112,67},[12]={75,145,50},[13]={48,115,105}}
local function c(r,g,b,a) return Color.new(r,g,b,a or 255) end
local function font(big) local e=enums.window_enums or enums; return ((e.font_id or {})[big and "FONT_BIG" or "FONT_SMALL"]) or (big and 8 or 7) end
local function clip(v,n) v=tostring(v or ""); return require('mf_i18n').clip(require('mf_i18n').text(v),n) end
function M.identity()
 local player=core.object_manager.get_local_player(); if not player then return "Unknown","Unknown",0 end
 local ok,class=pcall(player.get_class,player); class=ok and tonumber(class) or 0
 local ready,spec=pcall(core.spell_book.get_specialization_id); spec=ready and tonumber(spec) or 0
 return classes[class] or "Unknown",(specs[class] and specs[class][spec]) or "Unknown",class
end
local function boss_active()
 local p=core.object_manager.get_local_player(); if not p or not Encounters.profile then return false end
 local ok,combat=pcall(p.is_in_combat,p)
 return ok and combat==true
end
local function visible()
 if Encounters.profile~=last_profile then hidden_profile=nil; last_profile=Encounters.profile end
 return Settings.is_guardian() and (Settings.on("boss_helper_gui")
  or boss_active() and hidden_profile~=Encounters.profile)
end
local function hide()
 Settings.set("boss_helper_gui",false)
 if boss_active() then hidden_profile=Encounters.profile end
end
local function poll_hotkey()
 if not core.input or type(core.input.is_key_pressed)~="function" then return end
 local ok,down=pcall(core.input.is_key_pressed,0x76); down=ok and down==true
 if down and not f7_was_down and Settings.is_guardian() then
  if visible() then hide() else Settings.set("boss_helper_gui",true); hidden_profile=nil end
 end
 f7_was_down=down
end
function M.render()
 poll_hotkey()
 if not core.menu.window then return end
 if not window then
  window=core.menu.window("guardian_dungeon_boss_helper")
  window:set_initial_position(vec2.new(Settings.value("boss_overlay_x"),Settings.value("boss_overlay_y")))
  window:set_initial_size(vec2.new(430,292))
  -- Layer 2 is rejected by some Project Sylvanas builds and prevents the
  -- entire helper from rendering. Layer 1 is the compatible GUI layer.
  if window.set_render_layer then pcall(window.set_render_layer,window,1) end
 end
 local show=visible(); window:set_visibility(show); if not show then return end
 local class,spec,class_id=M.identity(); local t=themes[class_id] or themes[11]
 local we=enums.window_enums or enums
 window:begin((we.window_resizing_flags or {}).NO_RESIZE or 0,false,c(7,17,13),c(t[1],t[2],t[3]),(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  local function rect(x,y,w,h,col,r) window:render_rect_filled(vec2.new(x,y),vec2.new(x+w,y+h),col,r or 5) end
  local function text(v,x,y,big,col) window:render_text(font(big),vec2.new(x,y),col or c(225,236,220),tostring(v)) end
  local function clicked(x,y,w,h) return window:is_rect_clicked(vec2.new(x,y),vec2.new(x+w,y+h)) end
  rect(0,0,430,292,c(7,17,13,244),0); rect(0,0,430,42,c(t[1],t[2],t[3],245),0)
  text(spec.." "..class.."  •  BOSS HELPER",14,11,true,c(255,239,180))
  rect(356,7,64,28,c(30,45,36,245),4); text("HIDE",369,12,false,c(255,210,170)); if clicked(356,7,64,28) then hide() end
  local profile=Encounters.profile
  local boss=profile and profile.name or "Waiting for a supported dungeon boss"
  local role=Encounters.role or "TANK"
  local job=profile and (profile.roles[role] or profile.roles.TANK) or "F7 keeps this helper ready; mechanics appear when a boss is detected."
  text(clip(boss,42),14,51,true,profile and c(255,210,105) or c(143,220,166)); text("ROLE: "..role,320,55,false,c(143,220,166))
  rect(12,80,406,62,c(14,37,28,245),5); text(profile and "YOUR JOB" or "STANDBY",21,86,false,c(143,220,166)); text(clip(job,58),21,104,false)
  if profile and role=="TANK" and Encounters.position_hint then text("POSITION: "..clip(Encounters.position_hint,48),21,122,false,c(104,232,150)) end
  local warnings={}
  if profile then for _,entry in ipairs(Encounters.warnings) do warnings[#warnings+1]=entry end end
  -- The compact guide remains useful in emergency low-lag mode even between
  -- encounter scans by reading the already-throttled BigWigs status cache.
  if profile and BigWigs.next and #warnings<3 then
   local timer_name=BigWigs.next.text or "Upcoming mechanic"
   local duplicate=false
   for _,entry in ipairs(warnings) do if entry.name==timer_name then duplicate=true; break end end
   if not duplicate then warnings[#warnings+1]={name=timer_name,remaining=BigWigs.next.remaining,personal=false} end
  end
  if not Settings.on("boss_guide") then text("Boss guide is disabled in Dungeon settings",18,153,false,c(255,190,65))
  elseif #warnings==0 then text(profile and "No confirmed mechanic warning" or "Enter combat with a supported boss to begin",18,153,false,c(143,220,166)) end
  for i=1,math.min(3,#warnings) do
   local w=warnings[i]; local timer=w.remaining and string.format("%.1fs",w.remaining) or "NOW"
   local col=w.personal and c(255,85,75) or c(255,190,65)
   local row=150+(i-1)*38
   text((w.personal and "YOU • " or "")..clip(w.name,34),18,row,false,col); text(timer,371,row,false,col)
   text(clip(w.text or "Prepare for this mechanic",58),28,row+17,false,c(205,218,205))
  end
  text("F7: show/hide  •  Red: danger  •  Blue: soak  •  Green: clear",18,270,false,c(165,184,169))
 end)
end
function M.safe_render() local ok,err=pcall(M.render); if not ok then pcall(Log.runtime_error,"BOSS_GUI",err) end end
M.is_visible=visible
return M
