local color=require("common/color")
local vec2=require("common/geometry/vector_2")
local enums=require("common/enums")
local Factory={}
function Factory.new(settings,log)
 local G={page=1,hotkey_offset=0};local window
 local palette={balance={28,36,84,144,104,255},feral={67,28,23,226,126,52},restoration={15,61,44,68,210,132}};local p=palette[settings.key]or palette.balance
 local pages={"DASHBOARD","PLAYER","WORLD","DUNGEONS","MYTHIC+","RAID","DELVES","ARENA","BATTLEGROUNDS","WORLD PVP","HOTKEYS"};local modes={nil,nil,"world_pve","dungeon","mythic_plus","raid","delve","arena","battleground","world_pvp",nil}
 local function c(r,g,b,a)return color.new(r,g,b,a or 255)end
 local function font(big)return(((enums.window_enums or enums).font_id or{})[big and"FONT_BIG"or"FONT_SMALL"])or(big and 8 or 7)end
 local function rect(x,y,w,h,col,r)window:render_rect_filled(vec2.new(x,y),vec2.new(x+w,y+h),col,r or 5)end
 local function text(v,x,y,big,col)window:render_text(font(big),vec2.new(x,y),col or c(224,236,229),tostring(v))end
 local function clicked(x,y,w,h)return window.is_rect_clicked and window:is_rect_clicked(vec2.new(x,y),vec2.new(x+w,y+h))or false end
 local function button(label,x,y,w,h,fn,active)rect(x,y,w,h,active and c(p[4],p[5],p[6],220)or c(17,31,35,238),5);text(label,x+8,y+9,false,active and c(20,25,25)or nil);if clicked(x,y,w,h)then fn()end end
 local function switch_row(id,label,note,y)
  rect(224,y,700,49,c(10,23,27,235),5);text(label,238,y+6,false);text(note,238,y+27,false,c(157,181,170))
  button(settings.value(id)and"ON"or"OFF",722,y+8,58,32,function()settings.toggle(id)end,settings.value(id));button(settings.hotkey_enabled(id)and settings.hotkey_name(id)or"HK OFF",790,y+8,76,32,function()settings.set_hotkey_enabled(id,not settings.hotkey_enabled(id))end,settings.hotkey_enabled(id));button("<",871,y+8,23,32,function()settings.cycle_hotkey(id,-1)end);button(">",899,y+8,23,32,function()settings.cycle_hotkey(id,1)end)
 end
 local function overview()for i,row in ipairs(settings.global_rows())do switch_row(row[1],row[2],row[3],178+(i-1)*57)end;text("Every switch has an optional edge-triggered hotkey.",224,421,false,c(p[4],p[5],p[6]));text("Use the mode pages for combat behavior and health thresholds.",224,446,false,c(157,181,170))end
 local function mode_page(mode)
  for i,row in ipairs(settings.mode_rows())do switch_row(mode.."."..row[1],row[2],row[3],160+(i-1)*54)end
  local cfg=settings.cells[mode];local hp=cfg.hp:get();local emergency=cfg.emergency:get();local y=548;rect(224,y,700,76,c(10,23,27,235),5);text(settings.key=="restoration"and"Proactive healing HP"or"Recovery HP",238,y+8,false);text("Emergency HP",238,y+42,false)
  text(hp.."%",745,y+8,false,c(p[4],p[5],p[6]));button("-",790,y+4,30,28,function()cfg.hp:set(math.max(10,hp-1))end);button("+",829,y+4,30,28,function()cfg.hp:set(math.min(95,hp+1))end);text(emergency.."%",745,y+42,false,c(p[4],p[5],p[6]));button("-",790,y+38,30,28,function()cfg.emergency:set(math.max(5,emergency-1))end);button("+",829,y+38,30,28,function()cfg.emergency:set(math.min(70,emergency+1))end)
 end
 local function hotkeys()
  local total=#settings.hotkey_order;local max=math.max(0,total-7);G.hotkey_offset=math.min(G.hotkey_offset,max);button("UP",812,130,52,28,function()G.hotkey_offset=math.max(0,G.hotkey_offset-1)end);button("DOWN",872,130,62,28,function()G.hotkey_offset=math.min(max,G.hotkey_offset+1)end)
  for i=1,7 do local id=settings.hotkey_order[G.hotkey_offset+i];if id then local h=settings.hotkeys[id];switch_row(id,h.label,"Enable the binding, then choose its key with the arrows.",166+(i-1)*57)end end;text(string.format("Bindings %d-%d of %d",G.hotkey_offset+1,math.min(total,G.hotkey_offset+7),total),224,582,false,c(157,181,170))
 end
 function G.render()
  if not window and core.menu.window then window=core.menu.window("druid_suite_"..settings.key);window:set_initial_position(vec2.new(70,70));window:set_initial_size(vec2.new(950,680))end;if not window then return end
  local player=core.object_manager.get_local_player();local spec=core.spell_book.get_specialization_id();local matched=player and player:is_valid()and player:get_class()==11 and spec==settings.spec;if matched then settings.poll_hotkeys()end;local visible=matched and settings.gui:get_state();window:set_visibility(visible);if not visible then return end
  local we=enums.window_enums or enums;window:begin((we.window_resizing_flags or{}).RESIZE_BOTH_AXIS or 0,false,c(p[1],p[2],p[3]),c(p[4],p[5],p[6]),(we.window_cross_visuals or{}).NO_CROSS or 9,function()
   rect(0,0,950,92,c(p[1],p[2],p[3]),8);text(settings.label:upper().." DRUID",24,18,true,c(p[4],p[5],p[6]));text("Arthas Druid Suite  •  12.1.5",24,50,false);text("Mode: "..tostring(settings.mode or"Waiting"),590,20,false);text("Status: "..tostring(settings.status),590,48,false,c(191,211,199));rect(14,104,190,548,c(8,19,23,238),7)
   for i,label in ipairs(pages)do button(label,25,112+(i-1)*47,168,37,function()G.page=i end,G.page==i)end;text(pages[G.page],224,112,true,c(p[4],p[5],p[6]));if G.page==1 then
    text(settings.label.." profile is "..(settings.enabled:get_state()and"active"or"paused")..".",224,174,true,c(p[4],p[5],p[6]));text("Current mode: "..tostring(settings.mode or"Waiting"),224,220,false);text("Current decision: "..tostring(settings.status),224,252,false);text("Runtime: "..tostring(settings.debug),224,284,false,c(157,181,170));text("Choose Player for global controls or a play-mode tab",224,352,false);text("to customize combat behavior for that activity.",224,378,false)
   elseif G.page==2 then overview()elseif G.page==11 then hotkeys()else mode_page(modes[G.page])end
   button(settings.enabled:get_state()and"PROFILE ACTIVE"or"PROFILE PAUSED",718,634,206,34,function()settings.toggle("enabled")end,settings.enabled:get_state());text("Log: "..log.path(),224,640,false,c(157,181,170))
  end)
 end
 return G
end
return Factory
