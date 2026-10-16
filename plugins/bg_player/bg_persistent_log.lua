local P={};P.__index=P
local LOG_PATH="sylvanas_battleground_bot/session.log"
local DATA_PATH="sylvanas_battleground_bot/logs/latest.txt"
local MAX_BUFFERED_LINES=800
local function clean(v,n) return tostring(v or "-"):gsub("[|\r\n]"," "):sub(1,n or 4096) end
function P.new(version)
 -- Hot reload runs on the game thread. Do not read the previous journal or
 -- create files here; either operation can block the client while OneDrive or
 -- antivirus has the file. Storage is initialized by the first timed flush.
 local self=setmetatable({lines={},pending_log={},previous="",dirty=false,next_flush=0,
  next_snapshot=0,initialized=false,error=nil,path="scripts_log/"..LOG_PATH},P)
 self:raw(string.format("[SESSION_START] version=%s game_time=%.1f",clean(version,40),core.time()))
 return self
end
function P:raw(line)
 line=clean(line,8192);self.lines[#self.lines+1]=line
 if #self.lines>800 then table.remove(self.lines,1) end
 self.pending_log[#self.pending_log+1]=line
 if #self.pending_log>MAX_BUFFERED_LINES then
  table.remove(self.pending_log,1)
  self.dropped_pending=(self.dropped_pending or 0)+1
 end
 self.dirty=true
 return true
end
function P:record(row)
 return self:raw(string.format("#%d [%s] %s: %s",row.sequence,tostring(row.time),clean(row.kind,40),clean(row.message)))
end
function P:text()
 local current=table.concat(self.lines,"\n")
 if self.previous~="" then return self.previous.."\n"..current end
 return current
end
function P:flush(now,force)
 if not self.dirty or not force and now<(self.next_flush or 0) then return true end
 self.next_flush=now+15
 local ok,err=pcall(function()
  if not self.initialized then
   if type(core.create_log_folder)=="function" then core.create_log_folder("sylvanas_battleground_bot") end
   if type(core.create_log_file)=="function" then core.create_log_file(LOG_PATH) end
   if type(core.create_data_folder)=="function" then
    core.create_data_folder("sylvanas_battleground_bot");core.create_data_folder("sylvanas_battleground_bot/logs")
   end
   self.initialized=true
  end
  assert(type(core.write_log_file)=="function","core.write_log_file unavailable")
  if #self.pending_log>0 then core.write_log_file(LOG_PATH,table.concat(self.pending_log,"\n").."\n") end
  if force or now>=(self.next_snapshot or 0) then
   self.next_snapshot=now+60
   local text=self:text():sub(-32000)
   assert(type(core.create_data_file)=="function" and type(core.write_data_file)=="function","data writer unavailable")
   if type(core.delete_data_file)=="function" then pcall(core.delete_data_file,DATA_PATH) end
   core.create_data_file(DATA_PATH);assert(core.write_data_file(DATA_PATH,text)~=false,"snapshot write failed")
  end
 end)
 if ok then self.pending_log={};self.dirty=false;self.error=nil else self.error=clean(err) end
 return ok
end
function P:clear()
 self.lines={};self.pending_log={};self.previous="";self.dirty=true
 pcall(function() if type(core.delete_log_file)=="function" then core.delete_log_file(LOG_PATH) end;if type(core.create_log_file)=="function" then core.create_log_file(LOG_PATH) end end)
 pcall(function() if type(core.delete_data_file)=="function" then core.delete_data_file(DATA_PATH) end end)
 self:raw("[LOG_CLEARED] recording_continues=true")
end
return P
