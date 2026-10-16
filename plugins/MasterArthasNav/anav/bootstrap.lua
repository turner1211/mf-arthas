-- Fixed startup signals consumed by the MasterArthasNav tray app.
-- Writes scripts_data\arthas_nav_<id>.request with "start" or "stop"; the
-- tray app starts the server while the last word written is "start".
local M={last={},active={}}
M.ids={bg_player=true,auto_leveler=true,bloodcrypt_delver=true,master_farmer=true}
function M.tick(id,enabled)
    if not M.ids[id] then return false end
    local now=core.time()
    local nav=rawget(_G,"ArthasNavEnhancements")
    if nav then if enabled then nav.heartbeat(id) else nav.release(id);nav.cancel_transition(id) end end
    if M.active[id]==enabled and now-(M.last[id] or -100)<5 then return true end
    local ok=pcall(function()
        assert(core.create_data_file("arthas_nav_"..id..".request") ~= false,"ArthasNav startup signal could not be created")
        core.write_data_file("arthas_nav_"..id..".request",enabled and "start" or "stop")
    end)
    if ok then M.last[id]=now;M.active[id]=enabled end
    return ok
end
return M
