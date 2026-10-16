-- Replace only plugin-owned data snapshots. Some native cores append writes.
local M={}
function M.write(api,path,text)
 if type(path)~="string" or path:sub(1,22)~="sylvanas_auto_leveler/"
  or path:find("..",1,true) or path:find("\\",1,true) then
  error("invalid_snapshot_path")
 end
 if api.delete_data_file and api.read_data_file then
  local previous=api.read_data_file(path)
  if type(previous)=="string" and #previous>0 and api.delete_data_file(path)~=true then
   error("snapshot_replace_refused:"..path)
  end
 end
 api.create_data_file(path)
 return api.write_data_file(path,text)
end
return M
