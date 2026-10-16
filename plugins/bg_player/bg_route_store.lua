local S={};S.__index=S
local PATH="sylvanas_battleground_bot/routes/memory.txt"
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function safe_key(v) return tostring(v or ""):gsub("[^%w_:%.%-]","_"):sub(1,220) end
function S.new()
 -- Route learning is session-local. Reading a OneDrive-backed data file in a
 -- top-level constructor blocks F6 reload before the plugin can yield. The
 -- authored routes remain the durable source of truth.
 return setmetatable({memory={},dirty=false,error=nil},S)
end
function S:event(_,leg,data)
 local key=safe_key(leg);if key=="" or type(data)~="table" then return end
 self.memory[key]={successes=math.max(0,math.floor(tonumber(data.successes) or 0)),
  failures=math.max(0,math.floor(tonumber(data.failures) or 0)),last_success=tonumber(data.last_success) or 0,
  opening_successes=math.max(0,math.floor(tonumber(data.opening_successes) or 0)),
  detour=data.detour and {x=data.detour.x,y=data.detour.y,z=data.detour.z} or nil}
 self.dirty=true
end
function S:flush()
 if not self.dirty then return true end
 local rows={};for key,row in pairs(self.memory) do rows[#rows+1]={key=key,row=row} end
 table.sort(rows,function(a,b) return (a.row.last_success or 0)>(b.row.last_success or 0) end)
 local out={};for i=1,math.min(500,#rows) do
  local item=rows[i];local d=item.row.detour
  out[#out+1]=table.concat({safe_key(item.key),item.row.successes or 0,item.row.failures or 0,item.row.last_success or 0,item.row.opening_successes or 0,
   d and d.x or "",d and d.y or "",d and d.z or ""},"\t")
 end
 local ok,err=pcall(function()
  if type(core.delete_data_file)=="function" then pcall(core.delete_data_file,PATH) end
  assert(type(core.create_data_file)=="function" and type(core.write_data_file)=="function","route data writer unavailable")
  core.create_data_file(PATH);assert(core.write_data_file(PATH,table.concat(out,"\n"))~=false,"route data write failed")
 end)
 if ok then self.dirty=false;self.error=nil else self.error=tostring(err) end
 return ok
end
return S
