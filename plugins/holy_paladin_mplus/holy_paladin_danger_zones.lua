local M = { status = "Waiting for PvE combat", active = false, unsafe = false, timer = nil }
local color = require("common/color")
local ok_evade, evade = pcall(require, "common/utility/evade_helper")
if not ok_evade then evade = nil end
local RED, RED_EDGE = color.new(255,45,45,95), color.new(255,55,55,245)
local GREEN, GREEN_EDGE = color.new(45,235,105,70), color.new(70,255,125,235)
local AMBER, AMBER_EDGE = color.new(255,185,45,70), color.new(255,205,75,235)
local exact = {
 ["blood sacrifice"]=true,["ravenous stomp"]=true,["rattle"]=true,["death rattle"]=true,
 ["toxic surge"]=true,["ritual of the fang"]=true,["ravenous bellow"]=true,
 ["hearty bellow"]=true,["overwhelming onslaught"]=true,["heavy slams"]=true,
 ["awakening slam"]=true,["quaking leap"]=true,["blade dance"]=true,
 ["demonic rage"]=true,["defiled slam"]=true,["inferno"]=true,["thunderstorm"]=true,
 ["caustic stomp"]=true,["toxic spew"]=true,["thundering storm"]=true,["insidious aura"]=true }
local keywords = {"stomp","slam","leap","surge","spew","storm","inferno","bellow",
 "onslaught","rage","dance","breath","eruption","blast","wave","nova","impact",
 "crash","shatter","explosion","detonation"}
local function call(o,k,...)
 if not o then return nil end
 local ok,f=pcall(function()return o[k]end);if not ok or type(f)~="function" then return nil end
 local good,v=pcall(f,o,...);if good then return v end;return nil
end
local function pve_content()
 local kind="";if type(core.get_instance_type)=="function" then local ok,v=pcall(core.get_instance_type);if ok and type(v)=="string" then kind=string.lower(v) end end
 if kind=="arena" or kind=="pvp" or kind=="battleground" then return false end
 if kind=="party" or kind=="raid" or kind=="scenario" then return true end
 if core.delves and type(core.delves.is_in_delve)=="function" then local ok,v=pcall(core.delves.is_in_delve);if ok and v==true then return true end end
 return false
end
local function dangerous(text)
 text=type(text)=="string" and string.lower(text):gsub(" %(%d+%)$","") or ""
 if exact[text] then return true end
 for _,word in ipairs(keywords) do if string.find(text,word,1,true) then return true end end
 return false
end
local function warning()
 local bw=core.addons and core.addons.bigwigs
 if not bw or type(bw.is_loaded)~="function" or type(bw.get_bars)~="function" then return false,nil end
 local ok,loaded=pcall(bw.is_loaded);if not ok or loaded~=true then return false,nil end
 local bars_ok,bars=pcall(bw.get_bars);if not bars_ok or type(bars)~="table" then return false,nil end
 local nearest
 for _,bar in pairs(bars) do
  if type(bar)=="table" and bar.active~=false and bar.paused~=true and bar.stopped~=true then
   local left=tonumber(bar.remaining)
   if left and left>0 and left<=4.5 and dangerous(bar.text) and (not nearest or left<nearest.remaining) then nearest={text=tostring(bar.text),remaining=left} end
  end
 end
 return nearest~=nil,nearest
end
local function unsafe(pos)
 if not evade or not pos then return nil end
 local safe=call(evade,"is_point_safe",pos)
 if safe==false then return true end
 if safe==true then
  local full=call(evade,"is_point_safe_full",pos,2)
  if full==false then return true end
  if full==true then return false end
 end
 return nil
end
function M.draw(player,enabled)
 M.active,M.unsafe,M.timer=false,false,nil
 if not enabled or not player or not pve_content() or call(player,"is_in_combat")~=true then M.status=enabled and "Waiting for PvE boss combat" or "Disabled";return end
 local pos=call(player,"get_position");if not pos or not core.graphics then M.status="Position or graphics unavailable";return end
 local warned,timer=warning();local hit=unsafe(pos)
 if hit~=true and not warned then M.status=evade and "No active danger" or "Evade unavailable; waiting for BigWigs";return end
 M.active,M.unsafe,M.timer=true,hit==true,timer
 local fill=M.unsafe and RED or (hit==false and GREEN or AMBER)
 local edge=M.unsafe and RED_EDGE or (hit==false and GREEN_EDGE or AMBER_EDGE)
 if type(core.graphics.circle_3d_filled)=="function" then pcall(core.graphics.circle_3d_filled,pos,2.5,fill) end
 if type(core.graphics.circle_3d)=="function" then pcall(core.graphics.circle_3d,pos,2.5,edge,4,1);pcall(core.graphics.circle_3d,pos,3.2,edge,2,1) end
 if M.unsafe then M.status=timer and ("DANGER: "..timer.text.." / "..string.format("%.1fs",timer.remaining)) or "DANGER: standing in a registered hazard"
 elseif hit==false then M.status="NO REGISTERED HAZARD: "..timer.text.." / "..string.format("%.1fs",timer.remaining)
 else M.status="SAFETY UNKNOWN: "..timer.text.." / "..string.format("%.1fs",timer.remaining) end
end
return M
