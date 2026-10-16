-- Safe identity helpers for native game objects. Their equality metamethod may
-- throw after despawn, so gameplay code must compare copied GUIDs instead.
local O={}
function O.guid(object)
 local ok,value=pcall(function()
  if not object or type(object.get_guid)~="function" then return nil end
  if type(object.is_valid)=="function" and not object:is_valid() then return nil end
  return object:get_guid()
 end)
 if ok and (type(value)=="string" or type(value)=="number") and tostring(value)~="" then return tostring(value) end
end
function O.same(a,b)
 if not a or not b then return false end
 local ga,gb=O.guid(a),O.guid(b)
 if ga and gb then return ga==gb end
 local ok,equal=pcall(function() return a==b end)
 return ok and equal==true
end
return O
