-- Compact independent boss-helper window with automatic class/spec identity.
local M={}
local C=require("rs_settings")
local U=require("rs_units")
local Guide=require("rs_boss_guide")
local Position=require("rs_boss_position")
local Icons=require("rs_icons")
local ok_color,Color=pcall(require,"common/color")
local ok_vec,Vec=pcall(require,"common/geometry/vector_2")
local ok_enums,Enums=pcall(require,"common/enums")
local window,dragging,mouse_was_down=nil,nil,false
local f7_was_down=false
local manual_open,boss_hidden,was_boss_active=false,false,false
local active_boss_key=nil
local x,y,w,h=30,150,520,182
local classes={
 [1]={"Warrior",198,155,109},[2]={"Paladin",244,140,186},[3]={"Hunter",170,211,114},
 [4]={"Rogue",255,245,105},[5]={"Priest",245,245,245},[6]={"Death Knight",196,31,59},
 [7]={"Shaman",0,112,222},[8]={"Mage",63,199,235},[9]={"Warlock",135,136,238},
 [10]={"Monk",0,255,152},[11]={"Druid",255,125,10},[12]={"Demon Hunter",163,48,201},
 [13]={"Evoker",51,147,127},
}
local specs={
 [71]="Arms",[72]="Fury",[73]="Protection",[65]="Holy",[66]="Protection",[70]="Retribution",
 [253]="Beast Mastery",[254]="Marksmanship",[255]="Survival",[259]="Assassination",
 [260]="Outlaw",[261]="Subtlety",[256]="Discipline",[257]="Holy",[258]="Shadow",
 [250]="Blood",[251]="Frost",[252]="Unholy",[262]="Elemental",[263]="Enhancement",
 [264]="Restoration",[62]="Arcane",[63]="Fire",[64]="Frost",[265]="Affliction",
 [266]="Demonology",[267]="Destruction",[268]="Brewmaster",[269]="Windwalker",
 [270]="Mistweaver",[102]="Balance",[103]="Feral",[104]="Guardian",[105]="Restoration",
 [577]="Havoc",[581]="Vengeance",[1467]="Devastation",[1468]="Preservation",[1473]="Augmentation",
}
local function c(r,g,b,a)return Color.new(r,g,b,a or 255)end
local function compact(v,n)v=tostring(v or "");return #v<=n and v or v:sub(1,n-3).."..."end
local function identity(me)
 local class=tonumber(U.call(me,"get_class")) or 0
 local spec=core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or 0
 if class==7 and spec==3 then spec=264 end
 local info=classes[class] or {"Unknown",72,190,200}
 return (specs[spec] or "Unknown").." "..info[1],c(info[2],info[3],info[4])
end
local function kind(style)
 return style=="dispel" and "purify" or style=="heal" and "heal" or style=="move" and "wind"
  or style=="spread" and "danger" or style=="stack" and "link" or style=="soak" and "shield"
  or style=="interrupt" and "lightning" or "dungeon"
end
local function init()
 if window or not core.menu or type(core.menu.window)~="function" or not ok_color or not ok_vec or not ok_enums then return window~=nil end
 local ok=pcall(function()
  window=core.menu.window("rsm_boss_helper_396");window:set_initial_position(Vec.new(x,y));window:set_initial_size(Vec.new(w,h))
  if type(window.set_render_layer)=="function" then window:set_render_layer(1) end
 end)
 return ok and window~=nil
end
local function mouse()
 local cursor=type(core.get_cursor_position)=="function" and core.get_cursor_position() or nil
 local down=false;if core.input and type(core.input.is_key_pressed)=="function" then local ok,v=pcall(core.input.is_key_pressed,1);down=ok and v==true end
 if cursor and down and not mouse_was_down and cursor.x>=x and cursor.x<=x+w and cursor.y>=y and cursor.y<=y+38 then
  dragging={dx=cursor.x-x,dy=cursor.y-y}
  if core.graphics and type(core.graphics.capture_next_mouse_input)=="function" then pcall(core.graphics.capture_next_mouse_input) end
 end
 if dragging and core.graphics and type(core.graphics.set_mouse_capture_state)=="function" then pcall(core.graphics.set_mouse_capture_state,down) end
 if dragging and down and cursor then x,y=math.max(0,cursor.x-dragging.dx),math.max(0,cursor.y-dragging.dy)
 elseif dragging and not down then dragging=nil end
 mouse_was_down=down
end
local function poll_f7()
 local down=false
 if core.input and type(core.input.is_key_pressed)=="function" then local ok,v=pcall(core.input.is_key_pressed,0x76);down=ok and v==true end
 local hit=down and not f7_was_down
 f7_was_down=down
 return hit
end
function M.render()
 local f7_hit=poll_f7()
 if not C.get("boss_helper") then
  if f7_hit then C.set_setting("boss_helper",true);manual_open=false else M.hide();return end
 end
 local state=Guide.snapshot()
 local boss_active=state~=nil
 local boss_key=state and (U.call(state.boss_unit,"get_guid") or state.boss) or nil
 if boss_active and (not was_boss_active or boss_key~=active_boss_key) then boss_hidden=false end
 active_boss_key=boss_key
 if not boss_active then boss_hidden=false end
 was_boss_active=boss_active
 if f7_hit then
  if boss_active then boss_hidden=not boss_hidden else manual_open=not manual_open end
 end
 if not ((boss_active and not boss_hidden) or manual_open) then M.hide();return end
 if not state then
  local me=core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player() or nil
  if not me then M.hide();return end
  state={player=me,boss="Waiting for dungeon boss",title="HELPER READY",
   advice="Boss mechanics and your role instructions will appear automatically.",
   style="dungeon",remaining=nil,role="AUTO"}
 end
 if not init() then return end
 mouse();window:set_visibility(true)
 if window.force_window_size then window:force_window_size(Vec.new(w,h)) end
 if window.force_next_begin_window_pos then window:force_next_begin_window_pos(Vec.new(x,y)) end
 local we=Enums.window_enums or Enums;local fonts=we.font_id or {};local flags=we.window_resizing_flags or {};local visuals=we.window_cross_visuals or {}
 window:begin(flags.NO_RESIZE or 0,false,c(2,12,21,255),c(55,206,224,255),visuals.NO_CROSS or 9,function()
  local identity_name,accent=identity(state.player)
  window:render_rect_filled(Vec.new(0,0),Vec.new(w,h),c(2,12,21,252),8)
  window:render_rect_filled(Vec.new(0,0),Vec.new(w,38),c(4,31,47,255),8)
  window:render_rect(Vec.new(1,1),Vec.new(w-1,h-1),accent,8,2)
  Icons.draw(kind(state.style),10,48,48,window)
  window:render_text(fonts.FONT_SEMI_BIG or 0,Vec.new(14,10),accent,"DUNGEON BOSS HELPER")
  window:render_text(fonts.FONT_SMALL or 0,Vec.new(270,12),c(210,231,235),identity_name.." • "..state.role)
  window:render_text(fonts.FONT_SMALL or 0,Vec.new(72,48),c(151,244,239),compact(state.boss:upper(),42))
  local countdown=state.remaining and string.format("  %.1fs",state.remaining) or ""
  window:render_text(fonts.FONT_SEMI_BIG or 0,Vec.new(72,73),c(255,207,80),compact(state.title,35)..countdown)
  window:render_text(fonts.FONT_SMALL or 0,Vec.new(16,111),c(238,248,250),compact(state.advice,70))
  window:render_text(fonts.FONT_SMALL or 0,Vec.new(16,139),c(151,190,202),compact(Position.describe(state),62))
  window:render_rect_filled(Vec.new(432,7),Vec.new(508,32),c(66,25,34),5)
  window:render_text(fonts.FONT_SMALL or 0,Vec.new(444,11),c(255,190,190),"HIDE · F7")
  if window:is_rect_clicked(Vec.new(432,7),Vec.new(508,32)) then
   manual_open=false;if boss_active then boss_hidden=true end
   M.hide()
  end
 end)
end
function M.hide()
 dragging=nil;mouse_was_down=false
 if core.graphics and type(core.graphics.set_mouse_capture_state)=="function" then pcall(core.graphics.set_mouse_capture_state,false) end
 if window then window:set_visibility(false) end
end
return M
