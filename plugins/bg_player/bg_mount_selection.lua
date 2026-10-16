local M={name="Grizzly Hills Packmaster"}
function M.select(book)
 local ok,count=pcall(book.get_mount_count)
 if not ok or type(count)~="number" or count~=count or count<0 or count>10000 or count%1~=0 then return nil,"collection_unavailable" end
 local found=false
 for i=1,count do
  local got,m=pcall(book.get_mount_info,i)
  if got and type(m)=="table" and m.mount_name==M.name then
   found=true;if m.is_usable==true then return i,"preferred" end
  end
 end
 return nil,found and "preferred_mount_unusable" or "preferred_mount_not_found"
end
return M
