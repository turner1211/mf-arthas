-- Read-only CTF map hints published by the companion addon. Normalized map
-- coordinates are telemetry only and never become movement destinations.
local M={};M.__index=M
local function number(text,minimum,maximum,integer)
 if type(text)~="string" or #text>24 then return nil end
 local value=tonumber(text)
 if not value or value~=value or value<minimum or value>maximum or integer and value~=math.floor(value) then return nil end
 return value
end
local function parse(text,guid)
 if type(text)~="string" or #text>768 then return nil end
 local owner,session,seq,map_id,count,records=text:match("^SBGF1~([^~]+)~(%d+)~(%d+)~(%d+)~(%d+)~(.*)$")
 if not owner or owner~=guid or #owner>64 or #session>20 then return nil end
 seq=number(seq,1,2147483647,true);map_id=number(map_id,1,100000,true);count=number(count,0,8,true)
 if not seq or not map_id or not count then return nil end
 local flags={};local seen={}
 if count==0 then if records~="" then return nil end
 else
  if records=="" or records:sub(1,1)=="," or records:sub(-1)=="," or records:find(",,",1,true) then return nil end
  local parsed=0
  for record in records:gmatch("[^,]+") do
   local index,x,y,token=record:match("^(%d+):([%d%.]+):([%d%.]+):([%w_%-]+)$")
   index=number(index or "",1,8,true);x=number(x or "",0,1,false);y=number(y or "",0,1,false)
   if not index or not x or not y or not token or #token>64 or seen[index] then return nil end
   seen[index]=true;flags[#flags+1]={index=index,x=x,y=y,token=token};parsed=parsed+1
  end
  if parsed~=count then return nil end
 end
 return {owner=owner,session=session,sequence=seq,map_id=map_id,count=count,flags=flags,raw=text}
end
function M.new() return setmetatable({state="waiting_for_flag_data",available=false},M) end
function M:invalidate(reason) self.available=false;self.packet=nil;self.received_at=nil;self.state=reason or "flag_data_unavailable" end
function M:observe(texts,now,guid)
 local owned={};local malformed=false
 for _,text in ipairs(type(texts)=="table" and texts or {}) do
  if type(text)=="string" and text:match("^SBGF1~([^~]*)~")==guid then
   local packet=parse(text,guid);if packet then owned[#owned+1]=packet else malformed=true end
  end
 end
 if malformed then self:invalidate("malformed_flag_packet");return end
 if #owned==0 then self:invalidate("waiting_for_flag_data");return end
 if #owned~=1 then self:invalidate("conflicting_flag_packets");return end
 local packet=owned[1]
 if self.owner~=packet.owner or self.session~=packet.session then self.owner=packet.owner;self.session=packet.session;self.sequence=nil
 elseif self.sequence and packet.sequence<self.sequence then self:invalidate("flag_packet_out_of_order");return
 elseif self.sequence==packet.sequence and self.packet and self.packet.raw~=packet.raw then self:invalidate("flag_packet_sequence_conflict");return end
 if self.sequence~=packet.sequence then self.sequence=packet.sequence;self.packet=packet;self.received_at=now end
 self.available=true;self.state="flag_data_received"
end
function M:fresh(now) return self.available and self.received_at and now>=self.received_at and now-self.received_at<=3 end
function M:snapshot(now)
 if not self:fresh(now) then return nil end
 local out={map_id=self.packet.map_id,sequence=self.packet.sequence,flags={}}
 for i,row in ipairs(self.packet.flags) do out.flags[i]={index=row.index,x=row.x,y=row.y,token=row.token} end
 return out
end
function M:report(now)
 return {state=self:fresh(now) and self.state or self.available and "flag_data_stale" or self.state,
  available=self:fresh(now),map_id=self.packet and self.packet.map_id or nil,count=self.packet and self.packet.count or 0,
  received_at=self.received_at,sequence=self.sequence}
end
M.parse=parse
return M
