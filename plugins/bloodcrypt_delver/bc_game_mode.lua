local M={}
function M.current(host)
 host=host or core or {}
 if type(host.get_game_version)~="function" then return "Unknown" end
 local ok,value=pcall(host.get_game_version)
 if not ok or value==nil then return "Unknown" end
 return tostring(value)
end
function M.supported(host) return M.current(host)~="Forever" end
return M
