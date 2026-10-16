local M={}
local function read(name)
    local fn=core and core[name]
    if type(fn)~="function" then return "" end
    local ok,value=pcall(fn)
    return ok and type(value)=="string" and value or ""
end
function M.version() return read("get_game_version") end
function M.exact_version() return read("get_exact_game_version") end
function M.is_forever()
    local name=M.version():lower();local exact=M.exact_version():lower()
    return name=="forever" or name:find("forever",1,true)~=nil or exact:match("^1%.60%.")~=nil
end
function M.edition() return M.is_forever() and "forever" or "retail" end
function M.level(player)
    local probes={
        function() return player and player.get_level and player:get_level() end,
        function() return core.object_manager and core.object_manager.get_local_player_level and core.object_manager.get_local_player_level() end,
        function() return core.get_player_level and core.get_player_level() end
    }
    for _,probe in ipairs(probes)do
        local ok,value=pcall(probe);value=ok and tonumber(value)or nil
        if value and value>=1 and value<=80 then return math.floor(value)end
    end
end
return M
