-- Self-whisper data protocol. Never sends to party/guild or evaluates received code.
local M={};M.__index=M
local function fields(s) local r={};for v in (s.."|"):gmatch("(.-)|") do r[#r+1]=v end;return r end
local function integer(s,max) local n=tonumber(s);if n and n==n and n%1==0 and n>=0 and n<=(max or 10000000) then return n end end
local function same(a,b)
 if type(a)~="string" or type(b)~="string" then return false end
 a=a:lower():gsub("%s","");b=b:lower():gsub("%s","")
 return a==b or not b:find("-",1,true) and a:match("^([^-]+)")==b
end
function M.new(api) return setmetatable({api=api,status="Bridge not connected",serial=0},M) end
function M:request(tier,instance)
 local me=self.api.identity();if not me or not me:find("%S") then return false,"Local identity unavailable" end
 self.me=me;self.serial=self.serial+1;self.token=tostring(self.serial).."_"..math.floor(self.api.now()*1000)
 self.pending=nil;self.picker=nil;self.requested=self.api.now()
 local message=table.concat({"BCDV1",tier and "T" or "R",self.token,tier or 0,instance or 0},"|")
 local ok=self.api.send(message,"WHISPER",me);self.status=ok and "Waiting for bridge" or "Bridge request refused";return ok
end
function M:event(event,args)
 self.me=self.me or self.api.identity()
 if event~="CHAT_MSG_WHISPER_INFORM" or not args or not self.me or not same(args[2],self.me) then return false end
 local s=args[1];if type(s)~="string" or #s>255 or not s:match("^BCDV1|") then return false end
 local f=fields(s);local passive=f[3]=="push";if not passive and f[3]~=self.token then return false end
 self.last_message_at=self.api.now()
 local kind=f[2];local seq=integer(f[4]);if not seq then return false end
 if kind=="I" and (#f==9 or #f==10) then
  local class,spec=integer(f[5],100),integer(f[6],100000)
  local level=#f==10 and integer(f[10],1000) or nil
  if not class or not spec or class<1 or spec<1 or (#f==10 and (not level or level<1)) or (f[7]~="TANK" and f[7]~="HEALER" and f[7]~="DAMAGER" and f[7]~="NONE") then return false end
  self.character={class_id=class,spec_id=spec,role=f[7],class=f[8],spec=f[9],level=level,at=self.api.now()};return true
 elseif kind=="W" and #f==8 then
  local count=integer(f[7]);if not count then return false end
  self.wigs={bigwigs=f[5]=="1",littlewigs=f[6]=="1",events=count,last_event=f[8],at=self.api.now()};return true
 elseif kind=="U" and #f==7 then
  local id=integer(f[6]);if (f[5]~="gossip" and f[5]~="power") or not id or id<1 then return false end
  self.ui_action={kind=f[5],id=id,label=f[7],at=self.api.now()};return true
 elseif kind=="D" and (#f==9 or #f==10) then
  local tier,difficulty,season,companion=integer(f[6],100),integer(f[7]),integer(f[8],100),integer(f[9])
  if (f[5]~="0" and f[5]~="1") or not tier or not difficulty or not season or not companion or (#f==10 and f[10]~="0" and f[10]~="1") then return false end
  self.delve={active=f[5]=="1",tier=tier,difficulty_id=difficulty,season=season,companion_id=companion,reward_eligible=#f==10 and f[10]=="1",at=self.api.now()};return true
 elseif kind=="K" and #f==6 then
  local instance=integer(f[5]);if not instance or instance<1 or f[6]=="" then return false end
  self.story={instance=instance,name=f[6],at=self.api.now()};return true
 elseif kind=="J" and #f==6 then
  local currency,items=integer(f[5],10000),integer(f[6],10000);if not currency or not items then return false end
  self.resources={keys=currency+items,currency=currency,items=items,at=self.api.now()};return true
 elseif kind=="P" and #f==8 then
  local map,tier=integer(f[5]),integer(f[6],100);if not map or not tier then return false end
  self.picker={map=map,tier=tier,ready=f[7]=="1",reason=f[8],at=self.api.now()};self.status=self.picker.ready and "Tier selection confirmed" or f[8];return true
 elseif kind=="S" and #f==9 then
  local instance,scenario,step,count=integer(f[5]),integer(f[6]),integer(f[7]),integer(f[8],64)
  if not instance or instance<1 or not scenario or scenario<1 or not step or step<1 or not count then return false end
  self.pending={seq=seq,instance=instance,scenario_id=scenario,step_id=step,count=count,title=f[9],criteria={},pins={},spells={},received=0};return true
 elseif kind=="G" and #f==8 and self.pending and seq==self.pending.seq then
  local current,total,flags=integer(f[5],1000),integer(f[6],1000),integer(f[7],4294967295)
  if not current or not total or not flags then return false end
  self.pending.current_stage=current;self.pending.num_stages=total;self.pending.scenario_flags=flags;self.pending.scenario_name=f[8];return true
 elseif kind=="F" and #f==5 and self.pending and seq==self.pending.seq then
  local rows={};if f[5]~="" then for value in f[5]:gmatch("[^,]+") do local id=integer(value);if not id or id<1 or #rows>=32 then return false end;rows[#rows+1]=id end end
  self.pending.active_affixes=rows;return true
 elseif kind=="H" and #f==12 and self.pending and seq==self.pending.seq then
  local weighted=f[9]=="" and nil or tonumber(f[9]);local reward,widget=integer(f[10]),integer(f[11])
  if not reward or not widget or weighted and (weighted~=weighted or weighted<0 or weighted>1000000000) then return false end
  self.pending.step_failed=f[5]=="1";self.pending.bonus_step=f[6]=="1";self.pending.current_step_only=f[7]=="1";self.pending.show_bonus=f[8]=="1";self.pending.weighted_progress=weighted;self.pending.reward_quest_id=reward;self.pending.widget_set_id=widget;self.pending.description=f[12];return true
 elseif kind=="A" and #f==8 and self.pending and seq==self.pending.seq then
  local index,id,icon=integer(f[5],16),integer(f[6]),integer(f[7]);if not index or index<1 or not id or not icon then return false end
  self.pending.spells[index]={id=id,icon=icon,name=f[8]};return true
 elseif kind=="O" and #f==10 and self.pending and seq==self.pending.seq then
  local index,map=integer(f[5],32),integer(f[6]);local x,y=tonumber(f[7]),tonumber(f[8])
  if not index or index<1 or not map or map<1 or not x or not y or x~=x or y~=y or x<0 or x>1 or y<0 or y>1 then return false end
  self.pending.pins[index]={ui_map=map,x=x,y=y,atlas=f[9],description=f[10]};return true
 elseif kind=="C" and #f==11 and self.pending and seq==self.pending.seq then
  local index,id,q,total=integer(f[5],64),integer(f[6]),tonumber(f[7]),tonumber(f[8])
  if not index or index<1 or index>self.pending.count or not id or not q or not total or q~=q or total~=total or q<0 or total<0 or q>1000000000 or total>1000000000 then return false end
  if not self.pending.criteria[index] then self.pending.received=self.pending.received+1 end
  self.pending.criteria[index]={id=id,quantity=q,total=total,complete=f[9]=="1",failed=f[10]=="1",description=f[11]};return true
 elseif kind=="Q" and #f==13 and self.pending and seq==self.pending.seq then
  local index=integer(f[5],64);local row=index and self.pending.criteria[index]
  local criteria_type,flags,asset=integer(f[6]),integer(f[7],4294967295),integer(f[8]);local duration,elapsed=tonumber(f[9]),tonumber(f[10])
  if not row or not criteria_type or not flags or not asset or not duration or not elapsed or duration~=duration or elapsed~=elapsed or duration<0 or elapsed<0 then return false end
  row.criteria_type=criteria_type;row.flags=flags;row.asset_id=asset;row.duration=duration;row.elapsed=elapsed;row.weighted=f[11]=="1";row.formatted=f[12]=="1";row.quantity_string=f[13];return true
 elseif kind=="Z" and #f==4 and self.pending and seq==self.pending.seq and self.pending.received==self.pending.count then
  self.snapshot=self.pending;self.snapshot.at=self.api.now();self.pending=nil;self.status="Exact scenario snapshot received";return true
 elseif kind=="E" and #f==5 then self.status=f[5];self.pending=nil;return true end
 return false
end
function M:current(instance)
 local s=self.snapshot;if s and s.instance==instance and self.api.now()-s.at<=20 then return s end
 return nil
end
function M:tier_ready(instance,tier)
 local p=self.picker;return p and self.api.now()-p.at<=15 and p.map==instance and p.tier==tier and p.ready or false
end
function M:story_for(instance)
 local s=self.story;if s and s.instance==instance and self.api.now()-s.at<=30 then return s.name end
end
function M:delve_state()
 local d=self.delve;if d and self.api.now()-d.at<=20 then return d end
end
function M:criterion(instance,stage,id)
 local s=self:current(instance);if not s or s.step_id~=stage then return nil end
 for _,r in pairs(s.criteria) do if r.id==id then return r end end
end
return M
