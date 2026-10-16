local M={path="bloodcrypt_delver/run_memory.md",instance=0,completed={},quarantined={},family={}}
local function valid_guid(guid)
 return type(guid)=="string" and #guid>0 and #guid<=160 and guid:match("^[A-Za-z0-9_%-]+$")~=nil
end
local function empty(instance)
 M.instance=tonumber(instance) or 0;M.completed={};M.quarantined={};M.family={}
end
function M.save()
 local rows={"BCMEM1|"..tostring(M.instance)}
 local function append(kind,values)
  local keys={};for guid in pairs(values) do if valid_guid(guid) then keys[#keys+1]=guid end end;table.sort(keys)
  for _,guid in ipairs(keys) do rows[#rows+1]=kind.."|"..guid end
 end
 append("completed",M.completed);append("quarantined",M.quarantined);append("family",M.family)
 local ok,result=pcall(function()
  core.create_data_folder("bloodcrypt_delver");core.create_data_file(M.path)
  return core.write_data_file(M.path,table.concat(rows,"\n"))
 end)
 return ok and result~=false
end
function M.reset(instance)
 empty(instance);return M.completed,M.quarantined,M.family,M.save()
end
function M.load(instance)
 empty(instance)
 local ok,text=pcall(core.read_data_file,M.path)
 if not ok or type(text)~="string" or #text>250000 then return M.completed,M.quarantined,M.family,false end
 local header=text:match("^([^\r\n]+)")
 local saved=header and tonumber(header:match("^BCMEM1|(%d+)$"))
 if saved~=(tonumber(instance) or 0) then return M.completed,M.quarantined,M.family,false end
 local count=0
 for line in text:gmatch("[^\r\n]+") do
  local kind,guid=line:match("^(%a+)|(.+)$")
  if (kind=="completed" or kind=="quarantined" or kind=="family") and valid_guid(guid) then
   count=count+1;if count>4000 then empty(instance);return M.completed,M.quarantined,M.family,false end
   M[kind][guid]=true
  end
 end
 return M.completed,M.quarantined,M.family,true
end
function M.mark(kind,guid)
 if (kind~="completed" and kind~="quarantined" and kind~="family") or not valid_guid(guid) then return false end
 M[kind][guid]=true;return M.save()
end
return M
