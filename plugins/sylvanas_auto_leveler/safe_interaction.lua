-- Borrowed from the battleground bot's objective dispatcher: revalidate the
-- native object at dispatch and treat only explicit false as refusal.
local M={}
function M.dispatch(input,object,mode)
 local ok,valid,is_unit=pcall(function()
  if not object or type(object.is_valid)~="function" or not object:is_valid() then return false end
  if type(object.is_unit)~="function" then return true,nil end
  return true,object:is_unit()
 end)
 if not ok or valid~=true then return false,"interaction_object_unavailable" end
 local operation
 if mode=="use" then operation=input and input.use_object
 elseif mode=="interact" then operation=input and input.interact_with_object
 elseif is_unit==false then operation=input and input.use_object
 else operation=input and input.interact_with_object end
 if type(operation)~="function" then return false,"interaction_api_unavailable" end
 local ran,result=pcall(operation,object)
 if not ran then return false,tostring(result) end
 if result==false then return false,"interaction_refused" end
 return true
end
return M
