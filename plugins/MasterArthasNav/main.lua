-- Reload-safe loader for the unchanged ArthasNav upstream runtime (MasterArthasNav).
-- Project Sylvanas keeps registered callbacks after F6. Give every callback
-- created by this load a generation check so older runtimes become inert.
local GENERATION_KEY="__sylvanas_arthas_nav_runtime_generation"
local Locale=require('anav/i18n')
local restore_menu=Locale.scope_menu()
local generation=(tonumber(rawget(_G,GENERATION_KEY)) or 0)+1
rawset(_G,GENERATION_KEY,generation)

local registration_names={
 "register_on_update_callback",
 "register_on_render_callback",
 "register_on_render_menu_callback",
 "register_on_render_window_callback",
 "register_on_game_event_callback"
}
local originals={}
local function current() return rawget(_G,GENERATION_KEY)==generation end
for _,name in ipairs(registration_names) do
 local original=core and core[name]
 if type(original)=="function" then
  originals[name]=original
  core[name]=function(callback,...)
   if type(callback)~="function" then return original(callback,...) end
   local function guarded(...)
    if not current() then return end
    return callback(...)
   end
   return original(guarded,...)
  end
 end
end

-- MasterArthasNav: while it loads, the upstream runtime posts one line to a
-- hard-coded http://127.0.0.1:47110. Send load-time requests for that address
-- to base_url from anav/config.lua, so the port is set in one place.
local DEFAULT_URL="http://127.0.0.1:47110"
local cfg_ok,cfg=pcall(require,"anav/config")
local base_url=cfg_ok and type(cfg)=="table" and type(cfg.base_url)=="string" and cfg.base_url:gsub("/+$","") or nil
if base_url and base_url~=DEFAULT_URL then
 for _,name in ipairs({"http_get","http_post"}) do
  local original=core and core[name]
  if type(original)=="function" then
   originals[name]=original
   core[name]=function(url,...)
    if type(url)=="string" and url:sub(1,#DEFAULT_URL+1)==DEFAULT_URL.."/" then url=base_url..url:sub(#DEFAULT_URL+1) end
    return original(url,...)
   end
  end
 end
end

-- Force the preserved runtime to execute once for this generation even when
-- the host retains package.loaded across a soft reload.
if package and type(package.loaded)=="table" then package.loaded["anav/upstream_runtime"]=nil end
local before=rawget(_G,"AmeisenNav")
local ok,result=pcall(require,"anav/upstream_runtime")
restore_menu()
for name,original in pairs(originals) do core[name]=original end
if not ok then error(result) end

-- MasterArthasNav: the bundled client publishes _G.AmeisenNav while it loads.
-- Hand that table to the export, which keeps _G.AmeisenNav and _G.ArthasNav
-- pointing at it on every update tick (anav/export.lua).
local bundle=rawget(_G,"AmeisenNav")
local export=rawget(_G,"ArthasNavExport")
if bundle~=before and type(export)=="table" and type(export.adopt)=="function" then export.adopt(bundle) end
return result
