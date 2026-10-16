-- MasterArthasNav plugin header. Plain replacement for the upstream ArthasNav
-- header, which returned the same table under the name "ArthasNav" and posted
-- a boot line to a hard-coded http://127.0.0.1:47110.
local plugin = {
    name = "MasterArthasNav",
    version = "2.0.4",
    author = "BLIZZ",
    short_tag = "ANAV",
    load = true,
}

-- Tell the server the library is loading. The address comes from
-- anav/config.lua so the port is set in one place; nothing is sent when the
-- config cannot be read here.
pcall(function()
    if type(core) ~= "table" or type(core.http_post) ~= "function" then return end
    local ok, cfg = pcall(require, "anav/config")
    if not ok or type(cfg) ~= "table" or type(cfg.base_url) ~= "string" then return end
    local function read(name)
        local fn = core[name]
        if type(fn) ~= "function" then return "unknown" end
        local got, value = pcall(fn)
        return got and tostring(value) or "unknown"
    end
    local line = string.format("MasterArthasNav %s header: load=true game_version=%s exact=%s\n",
        plugin.version, read("get_game_version"), read("get_exact_game_version"))
    core.http_post(cfg.base_url:gsub("/+$", "") .. "/log?src=boot", line, function() end)
end)

return plugin
