local M={}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
function M.version_text()
    local probes={core and core.get_game_version,core and core.get_client_version,core and core.get_build_info,
        core and core.game and core.game.get_version,core and core.game and core.game.get_build_info}
    local out={}
    for _,fn in ipairs(probes) do
        local a,b,c=call(fn)
        for _,v in ipairs({a,b,c}) do if v~=nil then out[#out+1]=tostring(v) end end
    end
    return table.concat(out," "):lower()
end
function M.family()
    local text=M.version_text()
    if text:find("forever",1,true) or text:find("1.60.",1,true) then return "forever",text end
    if text:find("midnight",1,true) then return "midnight",text end
    return "unsupported",text
end
function M.level(player)
    local value=tonumber(call(player and player.get_level,player))
    return value and math.max(1,math.floor(value)) or nil
end
return M
