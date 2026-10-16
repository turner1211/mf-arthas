local M={}
local checks={
 {"is_stunned","stunned"},{"is_rooted","rooted"},{"is_feared","feared"},{"is_charmed","charmed"}
}
function M.reason(player)
 if type(player)~="table" and type(player)~="userdata" then return nil end
 for _,row in ipairs(checks) do
  local readable,method=pcall(function() return player[row[1]] end)
  if readable and type(method)=="function" then
   local ok,value=pcall(method,player)
   if ok and value==true then return row[2] end
  end
 end
 return nil
end
return M
