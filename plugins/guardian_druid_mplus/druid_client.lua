local M={}
local function read(name,owner)
    owner=owner or core
    local fn=owner and owner[name]
    if type(fn)~="function" then return "" end
    local ok,a,b,c
    if owner==core then ok,a,b,c=pcall(fn)else ok,a,b,c=pcall(fn,owner)end
    if not ok then return "" end
    local out={}
    for _,value in pairs({a,b,c})do
        if type(value)=="string"or type(value)=="number"then out[#out+1]=tostring(value)end
    end
    return table.concat(out," ")
end
function M.version() return read("get_game_version") end
function M.exact_version() return read("get_exact_game_version") end
local family_cache=nil
function M.family()
    if family_cache then return family_cache end
    local values={M.version(),M.exact_version(),read("get_client_version"),read("get_build_info"),read("get_version",core and core.game)}
    local text=table.concat(values," "):lower()
    if text=="    "or not text:find("%S")then return nil end
    if text:find("forever",1,true)or text:match("1%.60%.[%d%.]+")then family_cache="forever"else family_cache="retail"end
    return family_cache
end
function M.is_forever() return M.family()=="forever" end
function M.edition() return M.family() end
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
