-- Data-only persistence; wall clock expiry survives reloads.
local M={}
function M.new(api)
 local self={rows={}};local path='sylvanas_auto_leveler/routes/destination_failures.lua'
 local function key(p) return tostring(p.failure_context or api.context())..':'..math.floor(p.x/4)..':'..math.floor(p.y/4)..':'..math.floor(p.z/4) end
 if api.read then local ok,t=pcall(api.read,path);if ok and type(t)=='string' and #t<200000 then
  for k,n,until_at in t:gmatch('([^\n\t]+)\t(%d+)\t(%d+)') do self.rows[k]={count=tonumber(n),until_at=tonumber(until_at)} end
 end end
 local function save()
  if not api.write then return end
  local out={};for k,r in pairs(self.rows) do if r.until_at>api.time() then out[#out+1]=k..'\t'..r.count..'\t'..math.floor(r.until_at) end end
  table.sort(out);while #out>256 do table.remove(out,1) end;pcall(api.write,path,table.concat(out,'\n'))
 end
 function self:record(p,reason)
  if reason=='cancelled' or reason=='area_changed' then return end
  local k=key(p);local r=self.rows[k] or {count=0};r.count=r.count+1;r.until_at=api.time()+math.min(300,15*r.count);self.rows[k]=r;save()
 end
 function self:blocked(p) local r=self.rows[key(p)];return r and r.count>=2 and r.until_at>api.time() or false end
 function self:clear(p) self.rows[key(p)]=nil;save() end
 return self
end
return M
