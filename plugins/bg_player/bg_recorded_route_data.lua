-- Load only the active battleground's dense telemetry graph.
local names={"arathi","deephaul","deepwind_modern","eye_standard","gilneas","kotmogu","seething","silvershard","warsong"}
local known={};for _,name in ipairs(names) do known[name]=true end
local M={}
return setmetatable(M,{
 __index=function(t,key)
  if not known[key] then return nil end
  local value=require("bg_recorded_route_"..key);rawset(t,key,value);return value
 end,
 __pairs=function(t)
  local index=0
  return function() index=index+1;local key=names[index];if key then return key,t[key] end end
 end
})
