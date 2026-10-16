-- Learns observed incoming spell pressure per activity. Predictions require
-- repeated samples and remain capped so combat-log anomalies cannot force CDs.
local M={}
local learned={}
local data_path='assassination_rogue/threat_learning.lua'
local valid_modes={pve=true,mythic_plus=true,delve=true,arena=true,battleground=true,world_pvp=true}
local dirty,last_flush=false,-math.huge
local max_rows=256
local function key(mode,id) return tostring(mode or 'world')..':'..tostring(tonumber(id) or 0) end
function M.reset() learned={} end
function M.export()
 local rows={}
 for k,r in pairs(learned) do
  local mode,id=k:match('^([^:]+):(%d+)$')
  if valid_modes[mode] and id then
   rows[#rows+1]=table.concat({mode,id,math.max(0,math.min(200,tonumber(r.samples) or 0)),
    math.max(0,tonumber(r.average) or 0),math.max(0,tonumber(r.peak) or 0)},'|')
  end
 end
 table.sort(rows)
 while #rows>max_rows do table.remove(rows,1) end
 return table.concat(rows,'\n')
end
function M.import(text)
 if type(text)~='string' then return 0 end
 local loaded=0
 for line in text:gmatch('[^\r\n]+') do
  local mode,id,samples,average,peak=line:match('^([^|]+)|(%d+)|([%d%.]+)|([%d%.]+)|([%d%.]+)$')
  id=tonumber(id);samples=tonumber(samples);average=tonumber(average);peak=tonumber(peak)
  if loaded<max_rows and valid_modes[mode] and id and id>0 and samples and samples>=0 and samples<=200
     and average and average>=0 and peak and peak>=0 then
   learned[key(mode,id)]={samples=samples,average=average,peak=peak};loaded=loaded+1
  end
 end
 return loaded
end
function M.flush(force,n)
 if not dirty then return true end
 n=tonumber(n) or core.time()
 if not force and n-last_flush<2 then return false end
 local ok=pcall(function()
  assert(type(core.write_data_file)=='function','data writer unavailable')
  core.write_data_file(data_path,M.export())
 end)
 if ok then dirty=false;last_flush=n end
 return ok
end
function M.observe(mode,spell_id,amount,maximum,n)
 amount=tonumber(amount);maximum=tonumber(maximum);spell_id=tonumber(spell_id)
 if not spell_id or not amount or amount<=0 or not maximum or maximum<=0 then return end
 amount=math.min(amount,maximum*1.5)
 local k=key(mode,spell_id);local r=learned[k] or {samples=0,average=amount,peak=amount}
 r.samples=math.min(200,r.samples+1);r.average=r.average*0.75+amount*0.25
 r.peak=math.max(r.peak or 0,amount);r.last_seen=n;learned[k]=r;dirty=true
 M.flush(false,n)
end
function M.pressure(mode,spell_id,maximum)
 local r=learned[key(mode,spell_id)];maximum=tonumber(maximum)
 if not r or r.samples<3 or not maximum or maximum<=0 then return 0,r and r.samples or 0 end
 return math.min(35,r.average*100/maximum),r.samples
end
function M.on_event(event,args,player,guid,mode,n)
 if event~='COMBAT_LOG_EVENT_UNFILTERED' or type(args)~='table' or not player then return end
 local player_guid=tostring(guid(player) or '')
 if tostring(args[8] or '')~=player_guid or tostring(args[4] or '')==player_guid then return end
 local sub=tostring(args[2] or '');local spell_id,amount
 if sub=='SWING_DAMAGE' then spell_id,amount=6603,tonumber(args[12])
 elseif sub=='SPELL_DAMAGE' or sub=='SPELL_PERIODIC_DAMAGE' or sub=='RANGE_DAMAGE' or sub=='DAMAGE_SHIELD' then
  spell_id,amount=tonumber(args[12]),tonumber(args[15])
 end
 local maximum
 if type(player.get_max_health)=='function' then local ok,value=pcall(player.get_max_health,player);if ok then maximum=value end end
 M.observe(mode,spell_id,amount,maximum,n)
end
function M.summary(mode)
 local spells,samples=0,0;local prefix=tostring(mode or 'world')..':'
 for k,r in pairs(learned) do if k:sub(1,#prefix)==prefix then spells=spells+1;samples=samples+r.samples end end
 return {spells=spells,samples=samples,persistent=true,path='scripts_data/'..data_path,dirty=dirty}
end
pcall(function()
 if type(core.create_data_folder)=='function' then core.create_data_folder('assassination_rogue') end
 local size=type(core.get_data_file_size)=='function' and core.get_data_file_size(data_path) or 0
 if type(size)=='number' and size>0 and type(core.read_data_file)=='function' then M.import(core.read_data_file(data_path))
 elseif type(core.create_data_file)=='function' then core.create_data_file(data_path) end
end)
return M
