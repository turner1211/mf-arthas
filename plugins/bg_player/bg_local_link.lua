-- Diagnostic candidate transport only. Does not certify invitations/objectives.
local QueueLink=require("bg_queue_link")
local FlagLink=require("bg_flag_link")
local RuntimeApi=require("bg_runtime_api")
local M={};M.__index=M
local function clean(err) return tostring(err):gsub("[%z\1-\8\11\12\14-\31]"," "):sub(1,500) end
function M.new() return setmetatable({state="not_tested",receipts=0,last_poll=-100,bars_observed=0,queues=QueueLink.new(),flags=FlagLink.new()},M) end
function M:poll(core,now)
 if now-self.last_poll<0.25 then return end
 self.last_poll=now
 local addon=core.addons and core.addons.bigwigs
 self.bars_observed=0;self.is_loaded=nil;self.labels_readable=0;self.candidate_packets=0
 if not addon or type(addon.is_loaded)~="function" or type(addon.get_bars)~="function" then self.state="reader_unavailable";self.queues:invalidate(self.state);return end
 local ok,loaded=pcall(addon.is_loaded)
 if not ok then self.state="reader_error";self.last_error=clean(loaded);self.queues:invalidate(self.state);return end
 if type(loaded)~="boolean" then self.state="reader_invalid_result";self.last_error="is_loaded did not return a boolean";self.queues:invalidate(self.state);return end
 self.is_loaded=loaded
 if not loaded then self.state="bigwigs_not_loaded";self.last_error=nil;self.queues:invalidate(self.state);return end
 local bars;ok,bars=pcall(addon.get_bars)
 if not ok then self.state="reader_error";self.last_error=clean(bars);self.queues:invalidate(self.state);return end
 if type(bars)~="table" then self.state="reader_invalid_result";self.last_error="get_bars did not return a table";self.queues:invalidate(self.state);return end
 self.last_error=nil
 self.state=self.receipts>0 and "local_data_received" or "waiting_for_local_bar"
 local got,guid=pcall(function()
  local p=RuntimeApi.player();return p and p:is_valid() and p:get_guid()
 end)
 if not got or type(guid)~="string" then
  self.state="player_identity_unavailable";self.last_error=not got and clean(guid) or nil;self.queues:invalidate(self.state);return
 end
 local queue_texts={};local flag_texts={}
 for _,bar in pairs(bars) do
  self.bars_observed=self.bars_observed+1
  if self.bars_observed>256 then self.bars_observed=256;break end
  local readable,text=pcall(function()
   if type(bar)=="table" or type(bar)=="userdata" then return bar.text end
  end)
  if not readable then self.last_error=clean(text);text=nil end
  if type(text)=="string" and #text<=768 then
   if text~="" then self.labels_readable=self.labels_readable+1 end
   if text:sub(1,6)=="SBGQ1~" then queue_texts[#queue_texts+1]=text end
   if text:sub(1,6)=="SBGF1~" then flag_texts[#flag_texts+1]=text end
   local owner,seq,random,epic=text:match("^SBGLOCAL3~([^~]+)~(%d+)~(%d+)~(%d+)$")
   if not owner then owner,seq,random,epic=text:match("^SBGLOCAL2|([^|]+)|(%d+)|(%d+)|(%d+)$") end
   if owner then self.candidate_packets=self.candidate_packets+1 end
   if owner==guid and #seq<=10 and #random<=5 and #epic<=5 then
    self.state="local_data_received"
    if self.last_packet~=text then
     self.last_packet=text;self.receipts=self.receipts+1;self.received_at=now
     self.random_id=tonumber(random);self.epic_id=tonumber(epic)
     core.log("[BG Local Link] Local addon data received. Random ID="..random.." / Epic ID="..epic..". Invitation and objective bridge still required.")
    end
   end
  end
 end
 self.queues:observe(queue_texts,now,guid)
 self.flags:observe(flag_texts,now,guid)
end
function M:report(now)
 return {state=self.state,receipts=self.receipts,random_id=self.random_id,epic_id=self.epic_id,received_at=self.received_at,
  is_loaded=self.is_loaded,bars_observed=self.bars_observed,last_error=self.last_error,
  labels_readable=self.labels_readable,candidate_packets=self.candidate_packets,flags=self.flags:report(tonumber(now) or self.last_poll or 0)}
end
return M
