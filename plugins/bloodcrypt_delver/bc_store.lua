local Routes=require("bc_routes")
local Catalog=require("bc_catalog")
local M={root="bloodcrypt_delver"}
local function path(id,variant)
 assert(type(id)=="number" and id%1==0 and Catalog[id]~=nil,"Invalid delve ID")
 variant=variant or 1;assert(type(variant)=="number" and variant%1==0 and variant>=1 and variant<=#Catalog[id].variants,"Invalid variant index")
 return M.root.."/route_"..id.."_v"..variant..".md"
end
function M.load(id,variant)
 local ok,s=pcall(core.read_data_file,path(id,variant));if not ok or not s or s=="" then return nil,"No recorded route for this story" end
 return Routes.decode(s)
end
function M.save(id,r,variant)
 local ok,why=Routes.validate(r);if not ok then return false,why end
 local ran,result=pcall(function()
  core.create_data_folder(M.root);local p=path(id,variant);core.create_data_file(p)
  return core.write_data_file(p,Routes.encode(r))
 end)
 return ran and result~=false,ran and (result==false and "Route write refused" or "Saved") or tostring(result)
end
return M
