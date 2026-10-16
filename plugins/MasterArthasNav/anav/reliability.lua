-- Bounded readiness checks, destination cooldowns, safety gates and reports.
local R={version='2.2.4',protocol=3,failures={},recent={},readiness={code='not_checked'},safety={},loading=false}
local RuntimeApi=require('anav/runtime_api')
local probe_id,next_probe,pending,inflight=0,0,nil,0
local function now() return core.time() end
local function context() return tostring(core.get_instance_id())..':'..tostring(core.get_map_id()) end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function clean(s) return tostring(s or ''):gsub('[\r\n]',' '):sub(1,180) end
local failure_codes={unreachable=true,no_path=true,end_off_mesh=true,start_off_mesh=true,progress_stalled=true,max_stuck_exceeded=true,max_repath_exceeded=true,arrival_unverified=true,danger_no_safe_path=true}
failure_codes.route_loop=true;failure_codes.recovery_ineffective=true
function R.cooldown(goal,start)
 local t=now()
 for i=#R.failures,1,-1 do
  local f=R.failures[i]
  if f.expires<=t then table.remove(R.failures,i)
  elseif start and f.context==context() and distance(goal,f.goal)<4 and distance(start,f.start)<12 and f.until_time>t then
   return math.ceil(f.until_time-t),f.reason
  end
 end
end
function R.record(a,ok,reason,start,detail)
 local goal=a.goal;if not goal then return end
 local item={owner=a.owner,goal=goal,context=a.context,time=now(),result=clean(reason),replans=a.replans or 0,score=a.route_score}
 local fields=type(detail)=='table' and detail or {}
 for _,k in ipairs({'message','detail','raw','tile','name','code'}) do
  if type(fields[k])=='string' then item.tile=fields[k]:match('(%d+%.mmtile)');if item.tile then break end end
 end
 item.tile=item.tile or tostring(reason):match('(%d+%.mmtile)')
 R.recent[#R.recent+1]=item;if #R.recent>20 then table.remove(R.recent,1) end
 local entry
 for i=#R.failures,1,-1 do
  local f=R.failures[i]
  if f.context==a.context and distance(f.goal,goal)<4 and start and distance(f.start,start)<12 then
   if ok then table.remove(R.failures,i) else entry=f end;break
  end
 end
 if not ok and failure_codes[reason] and start then
  if not entry then entry={goal=goal,start=start,context=a.context,hits=0,until_time=0};R.failures[#R.failures+1]=entry end
  entry.hits=entry.hits+1;entry.reason=reason;entry.expires=now()+300
  if entry.hits>=3 then entry.until_time=now()+math.min(120,45*(entry.hits-2)) end
  if #R.failures>64 then table.remove(R.failures,1) end
 end
end
function R.reset() R.failures={};R.recent={} end
function R.set_safety_state(key,value)
 if key~='vehicle' and key~='loading' and key~='manual_hold' then return false end
 R.safety[key]=value==true;return true
end
function R.safety_reason(opts)
 if R.loading or R.safety.loading then return 'loading_screen' end
 if R.safety.vehicle then return 'vehicle' end
 if R.safety.manual_hold then return 'manual_hold' end
 local ok,reason=pcall(function()
  local p=RuntimeApi.player()
  if not p or not p:is_valid() then return 'player_unavailable' end
  if not (opts and opts.allow_dead_navigation) and ((p.is_dead and p:is_dead()) or (p.is_ghost and p:is_ghost())) then return 'player_dead' end
  -- Feature-probed only: not every supported PS build exposes vehicle state.
  if p.is_in_vehicle and p:is_in_vehicle() then return 'vehicle' end
 end)
 if ok then return reason end
 return 'player_unavailable'
end
function R.invalidate() probe_id=probe_id+1;pending=nil;next_probe=0;R.readiness={code='not_checked'} end
function R.poll()
 local t=now();local key=context();local requested_map=core.get_instance_id()
 if R.readiness.context and R.readiness.context~=key then R.invalidate() end
 if pending and t>=pending.expires then
  pending=nil;probe_id=probe_id+1;R.readiness={code='readiness_timeout',context=key,checked_at=t};next_probe=t+2
 end
 if pending or t<next_probe then return end
 -- PS does not expose HTTP cancellation. Bound stale requests as well as the
 -- current probe; otherwise a stalled bridge could accumulate HTTP workers.
 if inflight>=2 then R.readiness={code='readiness_timeout',context=key,checked_at=t};next_probe=t+5;return end
 if type(core.http_get)~='function' then R.readiness={code='http_unavailable',context=key,checked_at=t};next_probe=t+5;return end
 next_probe=t+5;probe_id=probe_id+1;local serial=probe_id
 pending={expires=t+8};R.readiness={code='checking',context=key,checked_at=t};inflight=inflight+1
 local consumed=false
 local url='http://127.0.0.1:47110'
 -- Respect the existing server configuration; never include tokens in reports.
 local cfg_ok,cfg=pcall(require,'anav/config')
 if cfg_ok and type(cfg)=='table' and type(cfg.base_url)=='string' then url=cfg.base_url:gsub('/+$','') end
 local function reply(status,_,body)
  if consumed then return end
  consumed=true;inflight=math.max(0,inflight-1)
  if serial~=probe_id or context()~=key then return end
  pending=nil
  local r={code='server_down',context=key,checked_at=now()}
  if status==404 then r.code='bridge_upgrade_required'
  elseif status==200 and type(body)=='string' and #body<2048 then
   local protocol=tonumber(body:match('protocol=(%d+)'))
   r.protocol=protocol;r.bridge=body:match('bridge=([%w%.%-]+)');r.map=body:match('map=([%w_]+)')
   r.performance={}
   for _,key in ipairs({'rpc_count','rpc_mean_ms','path_requests','tile_failures','tile_cache_hits','tile_cache_misses'}) do r.performance[key]=tonumber(body:match(key..'=([%d%.]+)')) end
   r.tile_checks=body:match('tile_checks=([%w_]+)')
   r.map_id=tonumber(body:match('map_id=(%d+)'))
   if r.map_id and r.map_id~=requested_map then r.code='map_context_mismatch'
   elseif protocol~=R.protocol then r.code='version_mismatch'
   elseif body:match('engine_api=antcp1832')==nil or body:match('map_schema=1')==nil then r.code='version_mismatch'
   elseif body:match('engine_up=1')==nil then r.code='server_down'
   elseif r.map=='missing' then r.code='map_not_loaded'
   elseif r.map=='tiles_missing' then r.code='map_tiles_missing'
   elseif r.map~='ready' then r.code='map_status_unknown'
   else r.code='ready' end
  end
  R.readiness=r
 end
 local ok=pcall(function()
  if cfg_ok and type(cfg)=='table' and type(cfg.token)=='string' and cfg.token~='' then
   core.http_get(url..'/readiness?map='..tostring(core.get_map_id())..'&world_map='..tostring(core.get_instance_id()),{Authorization='Bearer '..cfg.token},reply)
  else core.http_get(url..'/readiness?map='..tostring(core.get_map_id())..'&world_map='..tostring(core.get_instance_id()),reply) end
 end)
 if not ok then
  if not consumed then consumed=true;inflight=math.max(0,inflight-1) end
  pending=nil;R.readiness={code='http_unavailable',context=key,checked_at=t}
 end
end
function R.ready()
 local r=R.readiness
 return r.code=='ready' and r.context==context() and now()-(r.checked_at or -100)<10
end
function R.score(path,history)
 if type(path)~='table' or #path<2 then return math.huge end
 local total=0
 for i=2,#path do
  local a,b=path[i-1],path[i]
  if not a or not b or not tonumber(a.x) or not tonumber(a.y) or not tonumber(a.z) or not tonumber(b.x) or not tonumber(b.y) or not tonumber(b.z) then return math.huge end
  total=total+distance(a,b)+math.abs(b.z-a.z)*2
  if i>2 then
   local p=path[i-2];local ax,ay=a.x-p.x,a.y-p.y;local bx,by=b.x-a.x,b.y-a.y
   local n=math.sqrt((ax*ax+ay*ay)*(bx*bx+by*by))
   if n>0 then total=total+(1-math.max(-1,math.min(1,(ax*bx+ay*by)/n)))*4 end
  end
  for _,h in ipairs(history or {}) do
   if h.context==context() and h.expires>now() and distance(b,h.center)<h.radius+3 then total=total+h.hits*10 end
  end
 end
 return total
end
function R.repair(code)
 if code=='map_tile_missing' or code=='map_tiles_missing' or code=='map_not_loaded' then return 'Restore the matching map pack with Install-MapPack.ps1 in the external companion; do not add maps to the PS scripts folder.' end
 if code=='version_mismatch' or code=='bridge_upgrade_required' then return 'Install the matching ArthasNav companion and library release, then restart the server and reload the bots.' end
 if code=='map_context_mismatch' then return 'Reload the navigation request after zoning; verify the requested and reported map IDs.' end
 if code=='server_down' then return 'Check the installed local companion and loopback ports 47110/47111.' end
 return 'Attach this report in the arthas channel on PS Discord.'
end
function R.report(status,events)
 local r=R.readiness
 local rows={'# ArthasNav diagnostic report','Library: '..R.version..' / protocol '..R.protocol,
  'Context: '..context(),'Physical requested/reported map: '..tostring(core.get_instance_id())..' / '..tostring(r.map_id or 'unknown'),'Readiness: '..clean(r.code)..' / map '..clean(r.map or 'unknown'),
  'Repair: '..R.repair(r.code),
  'Bridge: '..clean(r.bridge or 'unknown')..' / protocol '..clean(r.protocol or 'unknown'),
  'Owner: '..clean(status.owner or 'none')..' / phase '..clean(status.phase),
  'Safety hold: '..clean(status.safety or 'none'),'Replans: '..tostring(status.replans or 0),
  'Destination cooldown entries: '..#R.failures,'','## Recent destinations'}
 local perf=status.performance or {};local bridge=perf.bridge or {}
 table.insert(rows,10,string.format('Performance: queries=%d mean=%.3fs max=%.3fs loops=%d recoveries=%d verified=%d ineffective=%d',perf.queries or 0,perf.planning_mean or 0,perf.planning_max or 0,perf.loops or 0,perf.recoveries or 0,perf.recovery_verified or 0,perf.recovery_ineffective or 0))
 table.insert(rows,11,string.format('Bridge: RPCs=%s mean=%sms tile-cache hits=%s misses=%s tile failures=%s coverage=%s',bridge.rpc_count or 'unknown',bridge.rpc_mean_ms or 'unknown',bridge.tile_cache_hits or 'unknown',bridge.tile_cache_misses or 'unknown',bridge.tile_failures or 'unknown',r.tile_checks or 'unknown'))
 table.insert(rows,12,'Persistent trouble spots: '..tostring(status.persistent==true)..' / priority '..tostring(status.priority or 0))
 local scheduler=perf.scheduler or {}
 table.insert(rows,13,string.format('Query queue: pending=%d discarded=%d callback errors=%d',perf.queue_depth or 0,scheduler.discarded or 0,scheduler.callback_errors or 0))
 table.insert(rows,14,string.format('Query recovery: timeouts=%d ignored late replies=%d',scheduler.query_timeouts or 0,scheduler.late_responses or 0))
 if status.destination then
  table.insert(rows,7,string.format('Active destination: %.1f,%.1f,%.1f',status.destination.x,status.destination.y,status.destination.z))
 end
 for _,a in ipairs(R.recent) do
  rows[#rows+1]=string.format('%.2f %s %s goal=%.1f,%.1f,%.1f result=%s replans=%d score=%s',a.time,clean(a.owner),a.context,a.goal.x,a.goal.y,a.goal.z,a.result,a.replans,a.score and string.format('%.1f',a.score) or 'not_scored')
  if a.tile then rows[#rows+1]='Missing tile: '..a.tile..' / '..R.repair('map_tile_missing') end
 end
 rows[#rows+1]='';rows[#rows+1]='## Recovery events'
 for _,e in ipairs(events or {}) do rows[#rows+1]=string.format('%.2f %s %s',e.time,clean(e.code),clean(e.detail)) end
 rows[#rows+1]='';rows[#rows+1]='Report this file in the arthas channel on the PS Discord with a description of the issue.'
 return table.concat(rows,'\n')
end
function R.save(report)
 local ok,err=pcall(function()
  assert(core.create_data_file('arthas_nav_diagnostics.md')~=false,'Could not create diagnostic file')
  assert(core.write_data_file('arthas_nav_diagnostics.md',report)~=false,'Could not save diagnostic file')
 end)
 return ok,ok and 'Saved scripts_data/arthas_nav_diagnostics.md' or tostring(err)
end
function R.setup()
 if core.register_on_game_event_callback then core.register_on_game_event_callback(function(name,args)
  if name=='PLAYER_LEAVING_WORLD' then R.loading=true;R.invalidate()
  elseif name=='PLAYER_ENTERING_WORLD' then R.loading=false;R.safety.vehicle=false;R.invalidate()
  elseif name=='UNIT_ENTERED_VEHICLE' and args and args[1]=='player' then R.safety.vehicle=true
  elseif name=='UNIT_EXITED_VEHICLE' and args and args[1]=='player' then R.safety.vehicle=false end
 end) end
end
return R
