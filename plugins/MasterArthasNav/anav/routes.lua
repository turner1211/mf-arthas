-- Bounded route policy and query scheduling. Never remove navmesh corners.
local P={queue={},busy=false,serial=0,replay={},metrics={queued=0,discarded=0,confidence_rejected=0,callback_errors=0,query_timeouts=0,late_responses=0}}
local function now() return core.time() end
local function dist(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
function P.record(code,data)
 P.replay[#P.replay+1]={time=now(),code=tostring(code):sub(1,80),data=tostring(data or ''):gsub('[\r\n]',' '):sub(1,384)}
 if #P.replay>120 then table.remove(P.replay,1) end
end
function P.snapshot(code,a,p,reason)
 if not a or not a.goal or not p then return end
 local g=a.goal
 local function finite(v)return type(v)=="number" and v==v and math.abs(v)<1000000 end
 for _,key in ipairs({"x","y","z"}) do if not finite(p[key]) or not finite(g[key]) then return end end
 local owner=tostring(a.owner or "unknown"):gsub("[^%w_%-]","_"):sub(1,60)
 local ctx=tostring(a.context or "unknown"):gsub("[^%d:%-]",""):sub(1,40)
 local data=string.format("sample|%s|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%d|%g|%g|%s",ctx,owner,p.x,p.y,p.z,g.x,g.y,g.z,a.replans or 0,a.opts and a.opts.arrival_radius or 5,a.opts and a.opts.arrival_height or 3,tostring(reason or ""):gsub("[^%w_%-]","_"):sub(1,60))
 P.record(code,data)
end
function P.export()
 local rows={'# ArthasNav decision replay (relative times; no credentials)'}
 for _,e in ipairs(P.replay) do rows[#rows+1]=string.format('%.2f | %s | %s',e.time,e.code,e.data) end
 return table.concat(rows,'\n')
end
function P.inspect(path,goal,opts)
 opts=opts or {};if type(path)~='table' or #path<2 or #path>8192 then return nil,'bad_path',0 end
 if type(goal)~='table' then return nil,'bad_path',0 end
 for _,k in ipairs({'x','y','z'}) do local v=goal[k];if type(v)~='number' or v~=v or math.abs(v)>100000 then return nil,'bad_path',0 end end
 local length,rise=0,0;local normalized={}
 for i,p in ipairs(path) do
  local ok,value=pcall(function() return {x=p.x,y=p.y,z=p.z} end)
  if not ok then return nil,'bad_path',0 end;p=value;normalized[i]=p
  for _,k in ipairs({'x','y','z'}) do local v=p[k];if type(v)~='number' or v~=v or math.abs(v)>100000 then return nil,'bad_path',0 end end
  if i>1 then
   local q=normalized[i-1];local span=dist(q,p);length=length+span;rise=rise+math.abs(p.z-q.z)
   if not opts.allow_falling and q.z-p.z>(tonumber(opts.max_drop) or 8) then return nil,'unsafe_drop',0 end
  end
 end
 path=normalized
 local gap=dist(path[#path],goal)
 local confidence=math.max(0,100-math.min(35,rise/math.max(length,1)*35)-math.min(60,gap*4))
 if gap>5 and not opts.allow_partial then return nil,'unreachable',confidence end
 if confidence<(tonumber(opts.min_confidence) or 40) then P.metrics.confidence_rejected=P.metrics.confidence_rejected+1;return nil,'low_route_confidence',confidence end
 -- Subdivide existing segments, preserving every original corner and altitude.
 local out={path[1]}
 for i=2,#path do
  local a,b=path[i-1],path[i];local spacing=12
  if i<#path then local c=path[i+1];local ux,uy=b.x-a.x,b.y-a.y;local vx,vy=c.x-b.x,c.y-b.y;local d=math.sqrt((ux*ux+uy*uy)*(vx*vx+vy*vy));if d>0 and (ux*vx+uy*vy)/d<.8 then spacing=4 end end
  if math.abs(b.z-a.z)>2 then spacing=4 end
  local n=math.max(1,math.ceil(dist(a,b)/spacing))
  if #out+n>8192 then return nil,'waypoint_limit',confidence end
  for j=1,n do local t=j/n;out[#out+1]={x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,z=a.z+(b.z-a.z)*t} end
 end
 return out,nil,confidence
end
function P.submit(run,valid,priority,cb)
 if type(run)~='function' or type(valid)~='function' or type(cb)~='function' then return false end
 priority=tonumber(priority) or 0
 if priority~=priority or math.abs(priority)==math.huge then priority=0 end
 priority=math.max(0,math.min(100,priority))
 if #P.queue>=32 then pcall(cb,false,nil,{code='query_queue_full'});return false end
 P.serial=P.serial+1;P.queue[#P.queue+1]={run=run,valid=valid,priority=priority or 0,cb=cb,id=P.serial,submitted=now(),expires=now()+20}
 P.metrics.queued=P.metrics.queued+1;P.pump();return true
end
local function valid(q) local ok,result=pcall(q.valid);return ok and result==true end
local function notify(q,...)
 local ok=pcall(q.cb,...)
 if not ok then P.metrics.callback_errors=P.metrics.callback_errors+1;P.record('query_callback_error','Consumer callback failed; queue remains available') end
end
local function rank(q)
 if q.priority>=80 then return q.priority end
 return math.min(79,q.priority+math.floor(math.max(0,now()-q.submitted)*4))
end
function P.pump()
 if P.pumping then return end;P.pumping=true
 -- Synchronous callbacks can resubmit forever within the same game frame.
 -- Continue on the next normal update instead of recursing until Lua freezes.
 local window=math.floor(now()*4)
 if P.dispatch_window~=window then P.dispatch_window=window;P.dispatches=0 end
 -- A lost native response must not hold every consumer's queue forever.
 -- Retire the old token before notifying consumers so late responses cannot
 -- release a newer query or deliver stale movement instructions.
 local active=P.active
 if active and (not valid(active) or now()>=active.deadline) then
  P.active=nil;P.busy=false;active.retired=true
  if valid(active) then
   P.metrics.query_timeouts=P.metrics.query_timeouts+1
   P.record('query_timeout','Active native query retired; queued work continues')
   notify(active,false,nil,{code='query_timeout'})
  else P.metrics.discarded=P.metrics.discarded+1 end
 end
 for i=#P.queue,1,-1 do
  local q=P.queue[i];local alive=valid(q)
  if now()>=q.expires or not alive then
   table.remove(P.queue,i);P.metrics.discarded=P.metrics.discarded+1
   notify(q,false,nil,{code=alive and 'query_queue_timeout' or 'query_superseded'})
  end
 end
 if P.busy or #P.queue==0 then P.pumping=false;return end
 if P.dispatches>=16 then P.pumping=false;return end
 table.sort(P.queue,function(a,b) local x,y=rank(a),rank(b);return x>y or x==y and a.id<b.id end)
 local q=table.remove(P.queue,1);P.dispatches=P.dispatches+1;P.busy=true;P.active=q;q.deadline=now()+20;local done=false
 local function finish(...)
  if done then return end;done=true
  if q.retired or P.active~=q then P.metrics.late_responses=P.metrics.late_responses+1;return end
  P.active=nil;P.busy=false
  if valid(q) then notify(q,...) else P.metrics.discarded=P.metrics.discarded+1 end
  P.pump()
 end
 local ok,result=pcall(q.run,finish)
 if not ok or result==false then finish(false,nil,{code='query_error'}) end
 P.pumping=false
 if not P.busy and #P.queue>0 then P.pump() end
end
return P
