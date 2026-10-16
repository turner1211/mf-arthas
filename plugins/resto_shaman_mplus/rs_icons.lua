-- Crisp Lua-native Shaman icons. No external PNG/JPEG files are required.
local M={}
local V=require("common/geometry/vector_2")
local C=require("common/color")
local Art=require("rs_icon_art")
local textures,attempted={},{}
local function col(r,g,b,a)return C.new(r,g,b,a or 255)end
local map={
 enabled="core",prediction="eye",adaptive_velocity="eye",totemic_prediction="totem",
 totemic_projection="totem",cooldowns="lightning",defensives="shield",elemental="earth",
 link="link",link_hp="link",mana_management="water",emergency="heal",
 delve_emergency="heal",spot="heal",heal="wave",group="chain",personal="shield",
 mana_conserve="water",mana_critical="water",overheal_cancel="wave",damage="lightning",
 training_dummy="dummy",dummy_damage="lightning",dummy_healing="water",dummy_aoe="chain",damage_aoe="chain",damage_hp="lightning",damage_mana="water",
 pvp_emergency="heal",pvp_burst="lightning",pvp_link="link",pvp_damage="lightning",
 pvp_peel="earth",pvp_peel_hp="earth",pvp_counterstrike="totem",pvp_cc="hex",
 pvp_lasso="lightning",pvp_purge="purify",anti_kick="shield",dampening_logic="eye",
 interrupts="lightning",pvp_interrupt_at="lightning",pvp_ground_cc_first="shield",
 pvp_ancient_lore="earth",arena_lines="link",dispels="purify",poison_cleansing="totem",
 resurrection="ancestral",pve_purge="purify",pve_trinkets="trinket",pvp_trinkets="trinket",
 trinket_13_mode="trinket",trinket_14_mode="trinket",trinket_heal_hp="trinket",
 trinket_defensive_hp="trinket",bigwigs="eye",profiles="scroll",preheal="heal",
 lead="eye",pve_stun_interrupt="totem",movement="wind",ghost_wolf="wolf",
 ghost_wolf_delay="wolf",avoidance="wind",danger_zones="danger",danger_radius="danger",
 boss_guide="scroll",boss_guide_lead="scroll",looting="bag",skinning="knife",
 boss_helper="dungeon",
 fishing="fish",fishing_recast="fish",gather_range="bag",gui_scale="display",font_scale="display",debug_log="scroll",hotkeys="lightning"
}
local tabs={"core","heal","water","totem","dungeon","shield","hex","wind","trinket","fish","lightning","scroll"}
function M.for_setting(key)return map[key] or "totem" end
function M.tab(index)return tabs[index] or "totem" end
local fallback={eye="water",ancestral="link",trinket="core",wolf="wind",danger="lightning",
 display="scroll",dummy="core",bag="scroll",knife="earth"}
local function texture(kind)
 kind=Art[kind] and kind or fallback[kind] or "totem"
 if textures[kind] then return textures[kind] end
 if attempted[kind] then return nil end
 attempted[kind]=true
 if core.graphics and type(core.graphics.load_texture)=="function" and Art[kind] then
  local ok,value=pcall(core.graphics.load_texture,Art[kind])
  if ok then textures[kind]=value end
 end
 return textures[kind]
end
local function line(w,x1,y1,x2,y2,color,width)
 if type(w.render_line)=="function" then w:render_line(V.new(x1,y1),V.new(x2,y2),color,width or 2) end
end
local function fill(w,x1,y1,x2,y2,color,r)w:render_rect_filled(V.new(x1,y1),V.new(x2,y2),color,r or 2)end
local function circle(w,x,y,r,color)
 if type(w.render_circle_filled)=="function" then w:render_circle_filled(V.new(x,y),r,color)
 else fill(w,x-r,y-r,x+r,y+r,color,r) end
end
local function tri(w,a,b,c,color)
 if type(w.render_triangle_filled)=="function" then w:render_triangle_filled(a,b,c,color) end
end
function M.draw(kind,x,y,size,window)
 if not window then return false end
 local loaded=texture(kind)
 if loaded and core.graphics and type(core.graphics.draw_texture)=="function" then
  local origin=type(window.get_position)=="function" and window:get_position() or V.new(0,0)
  local ok=pcall(core.graphics.draw_texture,loaded,V.new(origin.x+x,origin.y+y),size,size,C.new(255,255,255,255),true)
  if ok then
   if type(window.render_rect)=="function" then window:render_rect(V.new(x-1,y-1),V.new(x+size+1,y+size+1),C.new(151,244,239,230),4,1) end
   return true
  end
 end
 local k=size/32;local function p(a,b)return V.new(x+a*k,y+b*k)end
 local aqua=col(75,226,220);local blue=col(70,157,245);local green=col(91,232,143)
 local violet=col(190,132,255);local gold=col(229,183,79);local orange=col(255,132,54)
 local white=col(232,248,250);local dark=col(3,20,31,248)
 fill(window,x,y,x+size,y+size,dark,5*k)
 if type(window.render_rect)=="function" then window:render_rect(p(1,1),p(31,31),aqua,5*k,math.max(1,k)) end
 if kind=="water" or kind=="wave" then
  tri(window,p(16,4),p(7,19),p(25,19),blue);circle(window,x+16*k,y+19*k,9*k,blue)
  if kind=="wave" then line(window,x+7*k,y+25*k,x+25*k,y+25*k,white,2*k) end
 elseif kind=="heal" then fill(window,x+13*k,y+6*k,x+19*k,y+26*k,green,2*k);fill(window,x+6*k,y+13*k,x+26*k,y+19*k,green,2*k)
 elseif kind=="chain" or kind=="link" then
  circle(window,x+9*k,y+16*k,5*k,aqua);circle(window,x+23*k,y+16*k,5*k,aqua);line(window,x+12*k,y+13*k,x+20*k,y+19*k,white,3*k);line(window,x+12*k,y+19*k,x+20*k,y+13*k,white,3*k)
 elseif kind=="shield" or kind=="dungeon" then
  tri(window,p(5,7),p(27,7),p(16,28),blue);fill(window,x+9*k,y+9*k,x+23*k,y+15*k,dark,2*k);line(window,x+16*k,y+10*k,x+16*k,y+23*k,white,2*k)
 elseif kind=="lightning" then
  tri(window,p(18,3),p(7,18),p(15,18),gold);tri(window,p(14,15),p(25,13),p(11,29),orange)
 elseif kind=="hex" then
  local pts={p(16,3),p(27,10),p(27,22),p(16,29),p(5,22),p(5,10)}
  for i=1,6 do local q=pts[i%6+1];line(window,pts[i].x,pts[i].y,q.x,q.y,violet,2*k)end
  line(window,x+10*k,y+10*k,x+22*k,y+22*k,white,2*k);line(window,x+22*k,y+10*k,x+10*k,y+22*k,white,2*k)
 elseif kind=="purify" then
  circle(window,x+16*k,y+16*k,10*k,aqua);fill(window,x+14*k,y+8*k,x+18*k,y+24*k,white,2*k);fill(window,x+8*k,y+14*k,x+24*k,y+18*k,white,2*k)
 elseif kind=="totem" or kind=="earth" or kind=="core" then
  fill(window,x+10*k,y+7*k,x+22*k,y+26*k,kind=="earth" and gold or aqua,3*k);fill(window,x+6*k,y+4*k,x+26*k,y+10*k,white,3*k);circle(window,x+16*k,y+16*k,3*k,dark)
 elseif kind=="eye" then
  line(window,x+4*k,y+16*k,x+11*k,y+9*k,white,2*k);line(window,x+11*k,y+9*k,x+21*k,y+9*k,white,2*k);line(window,x+21*k,y+9*k,x+28*k,y+16*k,white,2*k);line(window,x+28*k,y+16*k,x+21*k,y+23*k,white,2*k);line(window,x+21*k,y+23*k,x+11*k,y+23*k,white,2*k);line(window,x+11*k,y+23*k,x+4*k,y+16*k,white,2*k);circle(window,x+16*k,y+16*k,4*k,blue)
 elseif kind=="wind" or kind=="wolf" then
  line(window,x+4*k,y+10*k,x+24*k,y+10*k,aqua,3*k);line(window,x+8*k,y+17*k,x+28*k,y+17*k,blue,3*k);line(window,x+4*k,y+24*k,x+21*k,y+24*k,white,2*k)
 elseif kind=="danger" then tri(window,p(16,3),p(3,28),p(29,28),orange);fill(window,x+14*k,y+10*k,x+18*k,y+21*k,dark,2*k);circle(window,x+16*k,y+25*k,2*k,dark)
 elseif kind=="fish" then
  tri(window,p(6,16),p(1,9),p(1,23),blue);circle(window,x+17*k,y+16*k,9*k,blue);circle(window,x+21*k,y+13*k,1.5*k,dark)
 elseif kind=="scroll" or kind=="display" then
  fill(window,x+7*k,y+5*k,x+25*k,y+27*k,white,3*k);for i=0,2 do line(window,x+11*k,y+(11+i*5)*k,x+22*k,y+(11+i*5)*k,blue,2*k)end
 elseif kind=="dummy" then
  circle(window,x+16*k,y+9*k,5*k,gold);fill(window,x+13*k,y+14*k,x+19*k,y+28*k,gold,2*k);line(window,x+6*k,y+18*k,x+26*k,y+18*k,white,2*k)
 elseif kind=="trinket" or kind=="ancestral" then
  circle(window,x+16*k,y+16*k,10*k,violet);circle(window,x+16*k,y+16*k,5*k,gold)
 elseif kind=="bag" then fill(window,x+6*k,y+11*k,x+26*k,y+27*k,gold,4*k);line(window,x+11*k,y+11*k,x+13*k,y+6*k,white,2*k);line(window,x+13*k,y+6*k,x+20*k,y+6*k,white,2*k)
 elseif kind=="knife" then line(window,x+7*k,y+25*k,x+24*k,y+7*k,white,4*k);line(window,x+5*k,y+27*k,x+12*k,y+20*k,gold,4*k)
 end
 return true
end
function M.reset()textures={};attempted={}end
return M
