-- Bounded plain-text diagnostics. Logging failures must not interrupt gameplay.
local M={}
M.entity_id="sylvanas_auto_leveler"
M.data_root="sylvanas_auto_leveler"
M.log_root="sylvanas_auto_leveler/logs"
local Snapshot=require("data_snapshot")
local function clean(value)
 return tostring(value):gsub("[%c]"," "):sub(1,500)
end
function M.new(api,limit)
 local self={rows={},limit=limit or 2000,sequence=0,dirty=false,next_flush=0,
  started=api.time(),error=nil,reported=false}
 if api.recover then
  local ok,old=pcall(api.recover)
  if ok and type(old)=="string" and #old>0 then self.recovered=old:sub(-1500000) end
 end
 function self:text()
  local omitted=self.sequence-#self.rows
  local current=(omitted>0 and ("[Earlier log entries omitted: "..omitted.."]\n") or "")..table.concat(self.rows,"\n").."\n"
  if self.recovered and self.recovered~="" then return self.recovered.."\n[RECOVERED_SESSION_END]\n"..current end
  return current
 end
 function self:snapshot_text(max_rows,max_recovered_bytes)
  -- latest.txt is a convenience/recovery snapshot. The permanent session log
  -- is appended above, so rewriting megabytes of old diagnostics here only
  -- creates avoidable main-thread disk stalls.
  max_rows=math.max(1,tonumber(max_rows) or 300)
  max_recovered_bytes=math.max(0,tonumber(max_recovered_bytes) or 100000)
  local first=math.max(1,#self.rows-max_rows+1);local rows={}
  for i=first,#self.rows do rows[#rows+1]=self.rows[i] end
  local omitted=self.sequence-#rows
  local current=(omitted>0 and ("[Earlier log entries available in permanent session.log: "..omitted.."]\n") or "")
   ..table.concat(rows,"\n").."\n"
  if self.recovered and self.recovered~="" and max_recovered_bytes>0 then
   local recovered=self.recovered:sub(-max_recovered_bytes)
   return recovered.."\n[RECOVERED_SESSION_END]\n"..current
  end
  return current
 end
 function self:failure()
  return self.error or self.append_error
 end
 function self:record(event,fields)
  local now=api.time()
  local keys={};for k in pairs(fields or {}) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local signature_parts={clean(event)}
  for _,k in ipairs(keys) do signature_parts[#signature_parts+1]=clean(k).."="..clean(fields[k]) end
  local signature=table.concat(signature_parts,"|")
  -- Failure loops can produce hundreds of identical records per second and
  -- turn permanent diagnostics into synchronous disk-I/O lag. Preserve the
  -- first and then at most two identical samples per second.
  if signature==self.last_signature and now-(self.last_signature_at or -math.huge)<0.5 then
   self.suppressed=(self.suppressed or 0)+1;return false,"duplicate_throttled"
  end
  self.last_signature=signature;self.last_signature_at=now
  self.sequence=self.sequence+1
  local parts={string.format("[%06d +%.1fs] %s",self.sequence,math.max(0,now-self.started),clean(event))}
  for i=2,#signature_parts do parts[#parts+1]=signature_parts[i] end
  local line=table.concat(parts," | ")
  self.rows[#self.rows+1]=line
  if #self.rows>self.limit then table.remove(self.rows,1) end
  self.dirty=true
  -- The core log writer appends immediately, so the record survives a client
  -- crash even when the five-second data snapshot has not run yet.
  local appended=false
  if api.append then
   local ok,result=pcall(api.append,line.."\n")
   if not ok or result==false then
    local reason=clean(ok and "log_append_returned_false" or result)
    if self.append_error~=reason and api.console then
     pcall(api.console,"Auto Leveler permanent log write failed: "..reason)
    end
    self.append_error=reason
   else self.append_error=nil;appended=true end
  end
  -- Project Sylvanas mirrors core.log into an initialized plugin log file.
  -- Sending the same event to both sinks therefore duplicates every line.
  -- Keep console output as the fallback when the permanent append sink is
  -- absent or rejected.
  if api.console and not appended then pcall(api.console,line) end
 end
 function self:flush(force)
  if not self.dirty or (not force and api.time()<self.next_flush) then return end
  self.next_flush=api.time()+10
  local ok,result=pcall(api.write,self:snapshot_text())
  if ok and result~=false then self.dirty=false;self.error=nil;self.reported=false;return true end
  self.error=clean(ok and "file_write_returned_false" or result)
  if not self.reported and api.console then pcall(api.console,"Auto Leveler log write failed: "..self.error);self.reported=true end
  return false
 end
 return self
end
function M.runtime_api()
 local path=M.log_root.."/latest.txt"
 local initialized=false;local log_initialized=false
 return {time=core.time,console=core.log,recover=function()
  if type(core.read_data_file)=="function" then return core.read_data_file(path) end
 end,write=function(text)
  if not initialized then
   core.create_data_folder(M.data_root)
   core.create_data_folder(M.log_root)
   if core.read_data_file then
    local old=core.read_data_file(path)
    if old and #old>0 then
     Snapshot.write(core,M.log_root.."/previous.txt",old:sub(-1500000))
    end
   end
   initialized=true
  end
  return Snapshot.write(core,path,text)
 end,append=function(text)
  if not log_initialized then
   if type(core.create_log_folder)~="function" or type(core.create_log_file)~="function"
    or type(core.write_log_file)~="function" then return false end
   core.create_log_folder(M.data_root)
   core.create_log_file(M.data_root.."/session.log")
   log_initialized=true
  end
  return core.write_log_file(M.data_root.."/session.log",text)
 end}
end
return M
