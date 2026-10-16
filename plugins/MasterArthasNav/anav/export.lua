-- MasterArthasNav export. _G.AmeisenNav is the primary API
-- ({VERSION, GAME_VERSION, client, query, follow}) and _G.ArthasNav the same
-- table. Both are published again on every update tick.
--
-- Reload safety: main.lua hands over the table the bundled client built for
-- this load (adopt). Tables published by an earlier load of this library are
-- replaced, because their callbacks are inert after F6. A table that another
-- plugin put in either global is left alone and reported once in the log.
local REGISTRY="__master_arthas_nav_published"
local M={bundle=nil,published=nil,foreign={}}
local function registry()
    local r=rawget(_G,REGISTRY)
    if type(r)~="table" then r=setmetatable({},{__mode="k"});rawset(_G,REGISTRY,r) end
    return r
end
local function usable(bundle)
    local client=type(bundle)=="table" and bundle.client or nil
    return type(client)=="table" and type(client.move_to)=="function"
        and type(client.stop)=="function" and type(client.is_server_available)=="function"
end
local function warn(name)
    if M.foreign[name] then return end
    M.foreign[name]=true
    if core and type(core.log_warning)=="function" then
        pcall(core.log_warning,"MasterArthasNav: _G."..name.." belongs to another plugin; left unchanged. Disable the other navigation library.")
    end
end
local function publish(name,bundle)
    local current=rawget(_G,name)
    if current==bundle then return true end
    if current==nil or registry()[current] then rawset(_G,name,bundle);M.foreign[name]=nil;return true end
    warn(name)
    return false
end
-- Takes the table the bundled client published while this load ran.
function M.adopt(bundle)
    if not usable(bundle) then return false end
    M.bundle=bundle;registry()[bundle]=true
    pcall(function() require("anav/height_fallback").wrap(bundle.client) end)
    return M.tick()
end
function M.current() return M.bundle end
function M.tick()
    local bundle=M.bundle
    if not usable(bundle) then return false end
    local primary=publish("AmeisenNav",bundle)
    local alias=publish("ArthasNav",bundle)
    M.published=(primary or alias) and bundle or nil
    return primary and alias
end
function M.setup()
    core.register_on_update_callback(M.tick)
end
return M
