-- Isolated entrypoint test for sidebar registration and edge-triggered F9.
local down,focused,time=false,false,1;local shown=false;local label;local update,render,menu_render;local starts=0
local panel={set=function(_,v) shown=v end,get_state=function() return shown end,render=function() end}
local root={render=function(_,name,fn) label=name;fn() end}
_G.core={menu={checkbox=function() return panel end,tree_node=function() return root end,text=function() end},
 input={is_key_pressed=function(key) if key==0x78 then return down end return false end},is_textbox_focused=function() return focused end,time=function() return time end,
 register_on_update_callback=function(fn) update=fn end,register_on_render_callback=function(fn) render=fn end,register_on_render_menu_callback=function(fn) menu_render=fn end,register_on_game_event_callback=function() end}
package.loaded.bc_runtime={status=function() return "Ready" end,capabilities=function() return {} end,wigs=function() return "Ready",{} end,character=function() return {label="Rogue / Assassination / DAMAGE"} end,poll_bridge=function() end,heartbeat=function() end,snapshot=function() return {ready=true,inside=true,combat=false,complete=false,instance=3003} end,scenario=function() return nil end,bridge={status="Ready"}}
package.loaded.bc_auto={new=function() return {enabled=false,state="Stopped",options={},stop=function() end,start=function(self) starts=starts+1;self.enabled=true;return true end,switch=function() return true end,event=function() end,tick=function() end} end}
package.loaded.bc_settings={load=function() return {tier=8} end}
package.loaded.bc_store={load=function() return nil,"No route" end}
package.loaded.bc_gui={render=function(s) assert(s.open==shown) end}
local test_source=debug.getinfo(1,"S").source:gsub("^@","")
local test_dir=test_source:match("^(.*[/\\])") or ""
dofile(test_dir.."main.lua")
menu_render();assert(label=="Bloodcrypt Delver","Plugin must own a sidebar root")
down=true;update();assert(shown);assert(starts==1,"reload inside a recognized delve must auto-attach once");time=2;update();assert(shown,"Held key must not retrigger");assert(starts==1,"auto-attach must not restart every update")
down=false;update();down=true;update();assert(not shown)
down=false;update();focused=true;down=true;update();assert(not shown,"Typing must suppress hotkey")
render();print("PASS sidebar root, F9 controls, and one-time in-delve reload attachment")
