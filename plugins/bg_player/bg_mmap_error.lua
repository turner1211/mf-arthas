-- Normalize ArthasNav/Recast failures so permanent map-pack faults do not get
-- treated like transient path requests.
local M={}
local function contains(value,needles)
 for _,needle in ipairs(needles) do if value:find(needle,1,true) then return true end end
 return false
end
function M.classify(value)
 local raw=tostring(value or "unknown"):lower()
 local message=raw:gsub("[%s%-]+","_")
 if contains(message,{"map_not_loaded","map_missing","missing_mmap","mmap_missing","tile_not_loaded","missing_tile","tile_missing","could_not_load_map"}) then
  return {category="coverage",severe=true,retryable=false,message=message}
 end
 if contains(message,{"mmap_version","version_mismatch","invalid_mmap","invalid_tile","detour_version","header_mismatch"}) then
  return {category="format",severe=true,retryable=false,message=message}
 end
 if contains(message,{"max_stuck","422","height_projection_conflict","height_projection_unavailable",
  "destination_unreachable","not_on_navmesh","start_off_mesh","end_off_mesh","unreachable"}) or
  raw:find("no path",1,true) then
  return {category="path",severe=true,retryable=true,message=message}
 end
 return {category="transient",severe=false,retryable=true,message=message}
end
return M
