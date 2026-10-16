-- Recovery requires observed quest credit; state changes are not progress.
local M={}
function M.new(api)
 local self={rows={},observations={}}
 local path="sylvanas_auto_leveler/routes/quest_recovery.lua"
 local function key(s)return api.context()..":"..tostring(s.quest_id)..":"..tostring(s.action)..":"..tostring(s.source_index or s.objective_index or "all") end
 if api.read then
  local ok,text=pcall(api.read,path)
  if ok and type(text)=="string" and #text<200000 then
   for k,n,next_at in text:gmatch("([^\n\t]+)\t(%d+)\t(%d+)") do self.rows[k]={attempts=tonumber(n),next_at=tonumber(next_at)} end
  end
 end
 local function save()
  local lines={};for k,r in pairs(self.rows) do lines[#lines+1]=k.."\t"..r.attempts.."\t"..math.floor(r.next_at or 0) end
  table.sort(lines);while #lines>256 do table.remove(lines,1) end
  local ok,result=pcall(api.write,path,table.concat(lines,"\n"))
  if not ok or result==false then api.log("quest_recovery_save_failed",{}) end
 end
 function self:observe(s,token,value,protected)
  if not s or not s.quest_id or s.action~="objective" and s.action~="accept" and s.action~="turnin" then return nil end
  local k=key(s);local now=api.time();local o=self.observations[k]
  if not o then self.observations[k]={token=token,value=value,at=now};return false end
  local changed=token~=nil and token~=o.token
  local advanced=changed and (type(value)=="number" and type(o.value)=="number" and value>o.value or value==nil and o.value==nil)
  o.token=token;o.value=value
  if advanced then
   o.at=now;if self.rows[k] then self.rows[k]=nil;save();api.log("quest_recovery_credit_confirmed",{quest_id=s.quest_id}) end
  elseif protected then o.at=now end
  local r=self.rows[k]
  return not protected and now-o.at>=45 and (not r or now>=(r.next_at or 0))
 end
 function self:attempt(s)
  local k=key(s);local now=api.time();local r=self.rows[k] or {attempts=0,next_at=0}
  if now<r.next_at then return nil,"backoff" end
  r.attempts=r.attempts+1
  local stages={"refresh_dialogue","refresh_targets","alternate_approach","discard_learned_action"}
  local stage=stages[(r.attempts-1)%#stages+1]
  local delay=r.attempts%4==0 and 120 or 45
  r.next_at=now+delay;self.rows[k]=r
  if self.observations[k] then self.observations[k].at=now end
  save();api.log("quest_recovery_sequence",{quest_id=s.quest_id,stage=stage,attempt=r.attempts,retry_seconds=delay})
  return stage,r.attempts
 end
 return self
end
return M
