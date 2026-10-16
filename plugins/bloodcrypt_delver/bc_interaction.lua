-- Shared safe dispatcher adapted from the installed BG Player and 1-90 bot.
local M={}
function M.dispatch(input,object)
 local ok,valid,is_unit=pcall(function()
  if not object or type(object.is_valid)~="function" or not object:is_valid() then return false end
  if type(object.is_unit)~="function" then return true,nil end
  return true,object:is_unit()
 end)
 if not ok or valid~=true then return false,"interaction_object_unavailable" end
 if type(is_unit)~="boolean" then return false,"interaction_object_type_unavailable" end
 local method=is_unit and "interact_with_object" or "use_object";local operation=input and input[method]
 if type(operation)~="function" then return false,"interaction_api_unavailable" end
 local ran,result=pcall(operation,object)
 if not ran then return false,tostring(result) end
 if result==false then return false,"interaction_refused:"..method end
 return true,method
end
return M
