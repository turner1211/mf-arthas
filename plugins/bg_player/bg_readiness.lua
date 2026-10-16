local M={};M.__index=M
local PATH="sylvanas_battleground_bot/readiness.txt"
local function flag(value) return value==true and 1 or 0 end
local function clean_scope(value) return tostring(value or "unknown"):gsub("[^%w_:%-%.]","_"):sub(1,160) end
function M.new(started,scope)
 return setmetatable({started=started or 0,scope=clean_scope(scope),sentinel=false,live_objectives=false,factions={},clean_matches=0,
  consecutive_clean=0,vehicle=false,siege=false,repair=false,preparation=false,mounted_navigation=false,active_seconds=0,persisted_active=0,last_tick=nil,last_enabled=false,
  loaded=false,dirty=false,error=nil,pending_matches=0,pending_all_clean=true},M)
end
function M:load(now)
 if self.loaded then return true end
 local ok,result=pcall(function()
  if type(core.read_data_file)~="function" then return "" end
  return core.read_data_file(PATH) or ""
 end)
 if not ok then self.error=tostring(result);return false end
 local schema,scope,started,sentinel,objectives,horde,alliance,clean,streak,vehicle,siege,repair,preparation,mounted_navigation,active_seconds=
  tostring(result):match("^(4)\t([^\t]+)\t([%d%.%-]+)\t([01])\t([01])\t([01])\t([01])\t(%d+)\t(%d+)\t([01])\t([01])\t([01])\t([01])\t([01])\t([%d%.]+)$")
 if not schema then
  schema,scope,started,sentinel,objectives,horde,alliance,clean,streak,vehicle,siege,repair,preparation,mounted_navigation=
  tostring(result):match("^(3)\t([^\t]+)\t([%d%.%-]+)\t([01])\t([01])\t([01])\t([01])\t(%d+)\t(%d+)\t([01])\t([01])\t([01])\t([01])\t([01])$")
 end
 if not schema then
  schema,scope,started,sentinel,objectives,horde,alliance,clean,streak,vehicle,siege,repair,preparation=
   tostring(result):match("^(2)\t([^\t]+)\t([%d%.%-]+)\t([01])\t([01])\t([01])\t([01])\t(%d+)\t(%d+)\t([01])\t([01])\t([01])\t([01])$")
 end
 if not schema then
  schema,scope,started,sentinel,objectives,horde,alliance,clean,streak,vehicle,siege,repair=
   tostring(result):match("^(1)\t([^\t]+)\t([%d%.%-]+)\t([01])\t([01])\t([01])\t([01])\t(%d+)\t(%d+)\t([01])\t([01])\t([01])$")
 end
 now=tonumber(now) or self.started
 if (schema=="1" or schema=="2" or schema=="3" or schema=="4") and scope==self.scope and tonumber(started) and tonumber(started)<=now then
  local current_clean=self.clean_matches;local current_streak=self.consecutive_clean;local current_active=self.active_seconds or 0
  self.started=tonumber(started);self.sentinel=self.sentinel or sentinel=="1";self.live_objectives=self.live_objectives or objectives=="1"
  self.factions[0]=self.factions[0] or horde=="1";self.factions[1]=self.factions[1] or alliance=="1"
  -- Schema four is the first version whose clean streak uses the current
  -- combat, objective, performance and multi-leg route acceptance rules.
  self.clean_matches=(schema=="4" and (tonumber(clean) or 0) or 0)+current_clean
  if self.pending_matches>0 then
   self.consecutive_clean=self.pending_all_clean and ((schema=="4" and (tonumber(streak) or 0) or 0)+current_streak) or current_streak
  else self.consecutive_clean=schema=="4" and (tonumber(streak) or 0) or 0 end
  self.vehicle=self.vehicle or vehicle=="1";self.siege=self.siege or siege=="1";self.repair=self.repair or repair=="1"
  self.preparation=self.preparation or preparation=="1"
  self.mounted_navigation=self.mounted_navigation or mounted_navigation=="1"
  self.active_seconds=(schema=="4" and (tonumber(active_seconds) or 0) or 0)+current_active
  self.persisted_active=self.active_seconds
  if self.pending_matches>0 or current_clean>0 then self.dirty=true end
 else
  self.dirty=true
 end
 self.pending_matches=0;self.pending_all_clean=true
 self.loaded=true;self.error=nil;return true
end
function M:flush()
 if not self.loaded or not self.dirty then return true end
 local row=table.concat({4,self.scope,self.started,flag(self.sentinel),flag(self.live_objectives),flag(self.factions[0]),flag(self.factions[1]),
  math.max(0,math.floor(self.clean_matches or 0)),math.max(0,math.floor(self.consecutive_clean or 0)),flag(self.vehicle),flag(self.siege),flag(self.repair),flag(self.preparation),flag(self.mounted_navigation),
  string.format("%.1f",math.max(0,tonumber(self.active_seconds) or 0))},"\t")
 local ok,err=pcall(function()
  if type(core.create_data_folder)=="function" then core.create_data_folder("sylvanas_battleground_bot") end
  if type(core.delete_data_file)=="function" then pcall(core.delete_data_file,PATH) end
  assert(type(core.create_data_file)=="function" and type(core.write_data_file)=="function","readiness data writer unavailable")
  core.create_data_file(PATH);assert(core.write_data_file(PATH,row)~=false,"readiness data write failed")
 end)
 if ok then self.dirty=false;self.persisted_active=self.active_seconds or 0;self.error=nil else self.error=tostring(err) end
 return ok
end
function M:tick(now,enabled)
 now=tonumber(now)
 if not now or now~=now then return end
 if self.last_tick and now>=self.last_tick then
  local delta=now-self.last_tick
  if self.last_enabled and delta<=5 then self.active_seconds=(self.active_seconds or 0)+delta end
 end
 self.last_tick=now;self.last_enabled=enabled==true
 if (self.active_seconds or 0)-(self.persisted_active or 0)>=60 then self.dirty=true end
end
function M:observe(kind,value)
 local changed=false
 if kind=="sentinel" and value==true and not self.sentinel then self.sentinel=true;changed=true
 elseif kind=="live_objectives" and value==true and not self.live_objectives then self.live_objectives=true;changed=true
 elseif kind=="faction" and (value==0 or value==1) and not self.factions[value] then self.factions[value]=true;changed=true
 elseif kind=="vehicle" and value==true and not self.vehicle then self.vehicle=true;changed=true
 elseif kind=="siege_gate" and value==true and not self.siege then self.siege=true;changed=true
 elseif kind=="repair" and value==true and not self.repair then self.repair=true;changed=true
 elseif kind=="preparation" and value==true and not self.preparation then self.preparation=true;changed=true
 elseif kind=="mounted_navigation" and value==true and not self.mounted_navigation then self.mounted_navigation=true;changed=true
 elseif kind=="match" then
  if value==true then self.clean_matches=self.clean_matches+1;self.consecutive_clean=self.consecutive_clean+1
  else self.consecutive_clean=0 end
  if not self.loaded then self.pending_matches=self.pending_matches+1;if value~=true then self.pending_all_clean=false end end
  changed=true
 end
 if changed then self.dirty=true end
end
function M:report(now)
 local uptime=math.max(0,tonumber(self.active_seconds) or 0)
 local checks={self.sentinel,self.live_objectives,self.factions[0]==true,self.factions[1]==true,
  self.vehicle,self.siege,self.repair,self.preparation,self.mounted_navigation,self.consecutive_clean>=5,uptime>=14400}
 local passed=0;for _,ok in ipairs(checks) do if ok then passed=passed+1 end end
 return {software=100,live=math.floor(passed/#checks*100+0.5),passed=passed,total=#checks,uptime=uptime,
  sentinel=self.sentinel,live_objectives=self.live_objectives,horde=self.factions[0]==true,alliance=self.factions[1]==true,
  vehicle=self.vehicle,siege=self.siege,repair=self.repair,preparation=self.preparation,mounted_navigation=self.mounted_navigation,consecutive_clean=self.consecutive_clean,
  overnight=uptime>=14400,loaded=self.loaded,dirty=self.dirty,error=self.error}
end
M.schema=4
return M
