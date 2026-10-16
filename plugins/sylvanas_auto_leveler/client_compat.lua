-- Central client policy. Keep game-version branches out of quest/runtime code.
local M={}
function M.version()
 local ok,value=pcall(function() return core.get_game_version and core.get_game_version() end)
 return ok and type(value)=="string" and value~="" and value or "Midnight"
end
function M.exact_version()
 local ok,value=pcall(function() return core.get_exact_game_version and core.get_exact_game_version() end)
 return ok and type(value)=="string" and value or ""
end
function M.is_forever() return M.version()=="Forever" end
function M.guide_edition()
 local v=M.version()
 if v=="Forever" or v=="Vanilla" then return "Vanilla" end
 if v=="Tbc" then return "TBC" end
 if v=="Mop" then return "MoP" end
 return "Retail"
end
function M.supports_skyriding() return M.version()=="Midnight" end
function M.display_name() return M.is_forever() and "WoW Forever" or M.version() end
return M
