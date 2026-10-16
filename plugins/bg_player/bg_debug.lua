-- Bounded diagnostics, not a Lua evaluator or game-action console.
local D={};D.__index=D
local function clean(v,n) return tostring(v or "-"):gsub("[%z\1-\8\11\12\14-\31]"," "):sub(1,n or 4096) end
function D.trace(err)
 local message=clean(err)
 if debug and type(debug.traceback)=="function" then return clean(debug.traceback(message,2),8192) end
 return message
end
function D.new(persistent) return setmetatable({events={},sequence=0,last_error=nil,persistent=persistent},D) end
function D:add(kind,message,now)
 self.sequence=self.sequence+1
 local row={sequence=self.sequence,time=now,kind=clean(kind,40),message=clean(message)}
 self.events[#self.events+1]=row
 if #self.events>2000 then table.remove(self.events,1) end
 if kind=="error" then self.last_error=row.message end
 if self.persistent then pcall(function() self.persistent:record(row) end) end
end
function D:clear() self.events={};self.last_error=nil;if self.persistent then pcall(function() self.persistent:clear() end) end end
function D:events_copy()
 local rows={};for i,row in ipairs(self.events) do rows[i]={sequence=row.sequence,time=row.time,kind=row.kind,message=row.message} end
 return rows
end
function D:export(rows)
 local out={"Sylvanas Battleground Debug Report"}
 for _,row in ipairs(rows or {}) do out[#out+1]=clean(row[1],80)..": "..clean(row[2]) end
 out[#out+1]=self.persistent and "Persistent diagnostic journal (recovered across reloads):" or "Diagnostic journal (max 2000):"
 if self.persistent then out[#out+1]=self.persistent:text()
 else for _,row in ipairs(self.events) do out[#out+1]=string.format("#%d [%s] %s: %s",row.sequence,tostring(row.time),row.kind,row.message) end end
 out[#out+1]="Last runtime error / traceback: "..tostring(self.last_error or "none")
 return table.concat(out,"\n")
end
return D
