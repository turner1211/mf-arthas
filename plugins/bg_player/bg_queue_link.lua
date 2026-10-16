-- Read-only local queue observations. Never evaluate addon text as Lua.
local Q={};Q.__index=Q
local states={N="none",Q="queued",C="confirm",A="active",L="locked",U="unknown"}
local modes={r="random",e="epic"}
local function integer(s,min,max)
 if type(s)~="string" or #s>20 or not s:match("^%d+$") then return nil end
 local n=tonumber(s)
 if not n or n~=math.floor(n) or n<min or n>max then return nil end
 return n
end
function Q.parse(text,guid)
 if type(text)~="string" or #text>768 then return nil end
 local owner,session,seq,r,e,rc,ec,count,records=text:match("^SBGQ1~([^~]+)~(%d+)~(%d+)~(%d+)~(%d+)~([012])~([012])~(%d+)~(.*)$")
 if not owner or owner~=guid or #owner>64 or #session>20 then return nil end
 seq=integer(seq,1,2147483647);r=integer(r,0,99999);e=integer(e,0,99999);count=integer(count,0,16)
 if not seq or not r or not e or not count then return nil end
 local packet={session=session,seq=seq,random_id=r,epic_id=e,can_random=rc=="1",can_epic=ec=="1",count=count,queues={}}
 local total=0
 for record in records:gmatch("[^,]+") do
  local slot,state,mode,id,suspended=record:match("^(%d+):([NQCALU]):([reau]):(%d+):([012])$")
  slot=integer(slot,1,count);id=integer(id,0,99999)
  if not slot or not id or packet.queues[slot] then return nil end
  if (mode=="r" and (id==0 or id~=r)) or (mode=="e" and (id==0 or id~=e)) or
    ((mode=="a" or mode=="u") and id~=0) or (state=="N" and (mode~="u" or id~=0)) then return nil end
  packet.queues[slot]={status=states[state],queue_mode=modes[mode],queue_id=id,
   kind=mode=="a" and "arena" or modes[mode] and "battleground" or "unknown",
   suspended=suspended~="0"}
  total=total+1
 end
 if total~=count or (count==0 and records~="") or (count>0 and records=="") or
   records:sub(1,1)=="," or records:sub(-1)=="," or records:find(",,",1,true) then return nil end
 packet.raw=text;return packet
end
function Q.new() return setmetatable({state="waiting_for_queue_data",receipts=0},Q) end
function Q:invalidate(reason)
 self.available=false;self.state=reason or "queue_data_unavailable"
end
function Q:observe(texts,now,guid)
 local packet,raw
 for _,text in ipairs(texts) do
  local candidate=Q.parse(text,guid)
  if candidate then
   if raw and raw~=text then self:invalidate("conflicting_queue_packets");return end
   packet,raw=candidate,text
  elseif type(text)=="string" and text:match("^SBGQ1~([^~]*)~")==guid then
   self:invalidate("malformed_queue_packet");return
  end
 end
 if not packet then self:invalidate("waiting_for_queue_data");return end
 if self.guid~=guid then self.packet=nil;self.guid=guid;self.available=false end
 local previous=self.packet
 if previous and packet.session==previous.session and packet.seq<previous.seq then self:invalidate("queue_packet_out_of_order");return end
 if previous and packet.session==previous.session and packet.seq==previous.seq and packet.raw~=previous.raw then self:invalidate("queue_packet_sequence_conflict");return end
 if not previous or packet.session~=previous.session then
  self.packet=packet;self.received_at=now;self:invalidate("warming_up_queue_data");return
 end
 if not previous or packet.session~=previous.session or packet.seq>previous.seq then
  local continuity=now-self.received_at<=2 and now>=self.received_at
  self.packet=packet;self.received_at=now;self.receipts=self.receipts+1
  if not continuity then self:invalidate("warming_up_queue_data");return end
  self.available=true
 end
 if self.available then self.state="queue_data_received" end
end
function Q:fresh(now)
 return self.available and self.packet~=nil and self.received_at~=nil and now>=self.received_at and now-self.received_at<=2
end
function Q:queue_count(now) return self:fresh(now) and self.packet.count or nil end
function Q:queue_status(slot,now)
 local p=self:fresh(now) and self.packet
 return p and p.queues[slot] and p.queues[slot].status or nil
end
function Q:queue_info(slot,now)
 local p=self:fresh(now) and self.packet;local value=p and p.queues[slot]
 if not value then return nil end
 return {kind=value.kind,queue_mode=value.queue_mode,queue_id=value.queue_id,suspended=value.suspended,observed_at=self.received_at}
end
function Q:catalog(mode,now)
 if not self:fresh(now) then return nil end
 local id=mode=="random" and self.packet.random_id or mode=="epic" and self.packet.epic_id
 local can=mode=="random" and self.packet.can_random or mode=="epic" and self.packet.can_epic
 return id and id>0 and id or nil,can==true
end
function Q:report(now)
 return {state=self.available and not self:fresh(now) and "queue_data_stale" or self.state,receipts=self.receipts,
  received_at=self.received_at,count=self:fresh(now) and self.packet.count or nil}
end
return Q
