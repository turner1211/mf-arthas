-- Build-scoped observations. Data is parsed, never executed.
local M={path="bloodcrypt_delver/learning.lua",rows={},build="unknown",dirty=false}
local function clean(s) return tostring(s or ""):gsub("[^%w_:%-%.]",""):sub(1,120) end
function M.load(build)
 M.build=clean(build);M.rows={};local ok,text=pcall(core.read_data_file,M.path)
 if ok and type(text)=="string" then
  for b,key,yes,no in text:gmatch("ROW|([^|]+)|([^|]+)|(%d+)|(%d+)") do
   if b==M.build then M.rows[key]={yes=tonumber(yes),no=tonumber(no)} end
  end
 end
end
function M.key(instance,story,stage,kind,id)
 return table.concat({tonumber(instance) or 0,tonumber(story) or 0,tonumber(stage) or 0,clean(kind),clean(id)},":")
end
function M.record(key,success)
 key=clean(key);local r=M.rows[key] or {yes=0,no=0};M.rows[key]=r
 if success then r.yes=math.min(99,r.yes+1) else r.no=math.min(99,r.no+1) end;M.dirty=true
end
function M.score(key) local r=M.rows[clean(key)];return r and r.yes*12-r.no*18 or 0 end
function M.verified(key) local r=M.rows[clean(key)];return r and r.yes>=2 and r.no==0 or false end
function M.flush()
 if not M.dirty then return true end;local keys={};for k in pairs(M.rows) do keys[#keys+1]=k end;table.sort(keys)
 local out={"-- Bloodcrypt observations; parsed as data only.","return {"}
 for _,k in ipairs(keys) do local r=M.rows[k];out[#out+1]="-- "..table.concat({"ROW",M.build,k,r.yes,r.no},"|") end
 out[#out+1]="}";local ok,result=pcall(function() core.create_data_folder("bloodcrypt_delver");core.create_data_file(M.path);return core.write_data_file(M.path,table.concat(out,"\n")) end)
 if ok and result~=false then M.dirty=false;return true end;return false
end
return M
