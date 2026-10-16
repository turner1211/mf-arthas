local Data=require('forever_contacts')
local M={}
function M.resolve(quest,action,map)
 local rows=Data[action] and Data[action][quest];local found
 for _,p in ipairs(rows or {}) do
  if (p.kind==1 or p.kind==2) and p.id>0 and (not map or p.map_id==map) then
   if found and (found.map_id~=p.map_id or found.id~=p.id or found.x~=p.x or found.y~=p.y) then return nil,'ambiguous_contact' end
   found=p
  end
 end
 return found
end
return M
