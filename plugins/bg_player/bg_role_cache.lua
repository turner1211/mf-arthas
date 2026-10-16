-- Short-lived opponent role cache. Native class/spec reads are considerably
-- more expensive than table lookup and do not need repeating every logic tick.
local C={};C.__index=C
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e9 end
function C.new(ttl) return setmetatable({ttl=tonumber(ttl) or 2,rows={},size=0},C) end
function C:reset() self.rows={};self.size=0 end
function C:get(guid,now,detect)
 if type(detect)~="function" then return "unknown" end
 if guid==nil or not finite(now) then
  local ok,role=pcall(detect);return ok and tostring(role or "unknown") or "unknown"
 end
 guid=tostring(guid);local row=self.rows[guid]
 if row and now>=row.at and now-row.at<self.ttl then return row.role end
 local ok,role=pcall(detect);role=ok and tostring(role or "unknown") or "unknown"
 if not row then self.size=self.size+1 end
 self.rows[guid]={role=role,at=now}
 -- Bound stale GUID retention in long or consecutive matches.
 if self.size>160 then
  local kept={};local count=0
  for key,value in pairs(self.rows) do
   if finite(value.at) and now>=value.at and now-value.at<self.ttl then kept[key]=value;count=count+1 end
  end
  self.rows=kept;self.size=count
 end
 return role
end
return C
