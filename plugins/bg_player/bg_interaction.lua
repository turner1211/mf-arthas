-- Revalidate native objects at dispatch time; world-object use differs from unit interaction.
local M={}
function M.dispatch(core,object)
 local ok,valid,is_unit=pcall(function()
  if not object or type(object.is_valid)~="function" or not object:is_valid() then return false end
  if type(object.is_unit)~="function" then return true,nil end
  return true,object:is_unit()
 end)
 if not ok or valid~=true then return false,"objective_object_unavailable" end
 if type(is_unit)~="boolean" then return false,"objective_object_type_unavailable" end
 local input=core.input or {}
 local operation=is_unit and input.interact_with_object or input.use_object
 if type(operation)~="function" then return false,"objective_interaction_api_unavailable" end
 -- A refused use request must not dispatch a second, different interaction.
 local dispatched,result=pcall(operation,object)
 if not dispatched then return false,tostring(result) end
 -- Native input calls commonly return nil after accepting a request. Only an
 -- explicit false is a refusal.
 if result==false then return false,"objective_interaction_refused" end
 return true
end
return M
