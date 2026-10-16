-- Additional navigation policy; no native movement input is generated here.
local A={persistent=false,dirty=false,loaded=false,objectives={},metrics={plans=0,queries=0,planning_total=0,planning_max=0,recoveries=0,recovery_verified=0,recovery_ineffective=0,loops=0,target_updates=0,preemptions=0}}
local outcomes={}
local next_save=0
local function now() return core.time() end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function utc()
 if not core.get_server_time then return nil end
 local ok,t=pcall(core.get_server_time);return ok and type(t)=='number' and t>0 and t or nil
end
function A.priority(opts)
 local p=opts and opts.priority or 0
 if type(p)~='number' or p~=p then return nil end
 return math.max(0,math.min(100,math.floor(p)))
end
function A.set_objective(owner,token,valid)
 if type(owner)~='string' or #owner>80 or type(token)~='string' or #token>120 then return false end
 local count=0;for _ in pairs(A.objectives) do count=count+1 end
 if count>=64 and not A.objectives[owner] then return false end
 A.objectives[owner]={token=token,valid=valid~=false};return true
end
function A.target(a,normalize,force)
 if not force and now()<(a.target_check_at or 0) then return end
 a.target_check_at=now()+1
 if a.opts.expires_at and now()>=a.opts.expires_at then return false,'destination_expired' end
 if a.opts.objective_token then
  local current=A.objectives[a.owner]
  if not current or not current.valid or current.token~=a.opts.objective_token then return false,'destination_stale' end
 end
 if a.opts.is_valid then
  local ok,value=pcall(a.opts.is_valid)
  if not ok or value~=true then return false,'destination_stale' end
 end
 if a.opts.destination_provider then
  local ok,value=pcall(a.opts.destination_provider)
  local goal=ok and normalize(value)
  if not goal then return false,'target_lost' end
  if distance(goal,a.goal)>=5 then return goal end
 end
end
function A.observe(a,p)
 if now()<(a.sample_at or 0) then return end
 a.sample_at=now()+1
 local samples=a.samples or {};a.samples=samples
 local d=distance(p,a.goal);samples[#samples+1]={p={x=p.x,y=p.y,z=p.z},t=now(),d=d}
 while #samples>16 or (#samples>0 and now()-samples[1].t>16) do table.remove(samples,1) end
 if #samples<7 then return end
 local walked,reversals,revisits,best=0,0,0,samples[1].d
 for i=2,#samples do
  local q,r=samples[i-1].p,samples[i].p;local step=distance(q,r);walked=walked+step;best=math.min(best,samples[i].d)
  if now()-samples[i-1].t>=4 and distance(p,q)<2 then revisits=revisits+1 end
  if i>2 and step>1 then
   local old=samples[i-2].p;local ax,ay=q.x-old.x,q.y-old.y;local bx,by=r.x-q.x,r.y-q.y
   local denom=math.sqrt((ax*ax+ay*ay)*(bx*bx+by*by))
   if denom>1 and (ax*bx+ay*by)/denom<-.5 then reversals=reversals+1 end
  end
 end
 -- A loop must return near its starting area and fail to improve the goal.
 local closed_loop=walked>12 and distance(p,samples[1].p)<4 and samples[1].d-d<3 and samples[1].d-best<4 and (reversals>=4 or revisits>=2)
 local oscillating=walked>18 and reversals>=5 and samples[1].d-d<1 and samples[1].d-best<6
 if closed_loop or oscillating then
  A.metrics.loops=A.metrics.loops+1;a.samples={};return true
 end
end
function A.recovery_bias(ctx,via)
 local score=0
 for _,o in ipairs(outcomes) do
  if o.context==ctx and o.expires>now() and distance(via,o.via)<4 then score=score+math.min(8,o.successes*2)-math.min(12,o.failures*3) end
 end
 return score
end
function A.record_recovery(a,ok)
 local via=a.recovery_via;if not via then return end
 local found
 for i=#outcomes,1,-1 do
  local o=outcomes[i]
  if o.expires<=now() then table.remove(outcomes,i)
  elseif o.context==a.context and distance(via,o.via)<4 then found=o end
 end
 if not found then found={context=a.context,via={x=via.x,y=via.y,z=via.z},successes=0,failures=0};outcomes[#outcomes+1]=found end
 if ok then found.successes=math.min(20,found.successes+1) else found.failures=math.min(20,found.failures+1) end
 found.expires=now()+900
 if #outcomes>64 then table.remove(outcomes,1) end
 a.recovery_via=nil
end
function A.outcome_report()
 local rows={'## Verified recovery approach outcomes (session memory)'}
 for _,o in ipairs(outcomes) do if o.expires>now() then rows[#rows+1]=string.format('%s | %.1f %.1f %.1f | success=%d failure=%d',o.context,o.via.x,o.via.y,o.via.z,o.successes,o.failures) end end
 return table.concat(rows,'\n')
end
function A.start_recovery(a,p,reason)
 A.metrics.recoveries=A.metrics.recoveries+1
 a.recovery={origin=p,distance=distance(p,a.goal),until_time=now()+12,reason=reason}
 a.samples={}
end
function A.verify_recovery(a,p)
 local r=a.recovery;if not r then return end
 if r.distance-distance(p,a.goal)>2 and distance(p,r.origin)>2 then
  A.record_recovery(a,true);A.metrics.recovery_verified=A.metrics.recovery_verified+1;a.recovery=nil;return true
 end
 if now()>=r.until_time then
  A.record_recovery(a,false);A.metrics.recovery_ineffective=A.metrics.recovery_ineffective+1;a.recovery=nil;return false
 end
end
function A.query_started() A.metrics.queries=A.metrics.queries+1;return now() end
function A.query_finished(start)
 local elapsed=math.max(0,now()-start)
 A.metrics.planning_total=A.metrics.planning_total+elapsed;A.metrics.planning_max=math.max(A.metrics.planning_max,elapsed);A.metrics.planning_last=elapsed
end
function A.performance()
 local out={};for k,v in pairs(A.metrics) do out[k]=v end
 out.planning_mean=out.queries>0 and out.planning_total/out.queries or 0
 return out
end
function A.load_history()
 local t=utc();if not t then return nil end
 A.loaded=true
 if not core.read_data_file then return {} end
 local ok,body=pcall(core.read_data_file,'arthas_nav_history.md')
 if not ok or type(body)~='string' or #body>32768 or not body:find('persist=on',1,true) then return {} end
 A.persistent=true;local rows={}
 for line in body:gmatch('[^\r\n]+') do
  local ctx,x,y,z,hits,radius,expires=line:match('^area|([%d%-]+:[%d%-]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$')
  x,y,z,hits,radius,expires=tonumber(x),tonumber(y),tonumber(z),tonumber(hits),tonumber(radius),tonumber(expires)
  local valid=true
  for _,v in ipairs({x or false,y or false,z or false,hits or false,radius or false,expires or false}) do if type(v)~='number' or v~=v or math.abs(v)==math.huge then valid=false end end
  if ctx and valid and math.abs(x)<100000 and math.abs(y)<100000 and math.abs(z)<100000 and hits>=1 and hits<=100 and radius>=3 and radius<=7 and expires>t and expires<=t+900 then
   rows[#rows+1]={context=ctx,center={x=x,y=y,z=z},hits=math.floor(hits),radius=radius,expires=now()+expires-t}
   if #rows>=64 then break end
  end
 end
 return rows
end
function A.save_history(history,force)
 if not A.dirty or (not force and now()<next_save) then return true end
 local t=utc();if A.persistent and not t then return false,'Realm clock unavailable; history not saved.' end
 next_save=now()+10
 local rows={'# ArthasNav learned trouble spots','persist='..(A.persistent and 'on' or 'off')}
 if A.persistent then for _,h in ipairs(history) do
  if h.expires>now() then rows[#rows+1]=string.format('area|%s|%.3f|%.3f|%.3f|%d|%.1f|%d',h.context,h.center.x,h.center.y,h.center.z,math.min(100,h.hits),h.radius,math.floor(t+h.expires-now())) end
 end end
 local ok,err=pcall(function()
  assert(core.create_data_file('arthas_nav_history.md')~=false,'History file unavailable')
  assert(core.write_data_file('arthas_nav_history.md',table.concat(rows,'\n'))~=false,'History write failed')
 end)
 if ok then A.dirty=false end
 return ok,ok and 'History preference saved.' or tostring(err)
end
function A.set_persistent(value,history)
 A.persistent=value==true;A.dirty=true;return A.save_history(history,true)
end
return A
