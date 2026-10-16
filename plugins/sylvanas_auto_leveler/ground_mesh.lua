-- Incremental ground graph: every edge is checked against live floor and collision.
local M={}
local function dist(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<100000 end
function M.new(api)
 local self={job=nil,path={},index=1}
 local function emit(event,fields) if api.log then api.log(event,fields) end end
 function self:is_server_available() return true end
 function self:get_current_path() return self.path end
 function self:get_path_index() return self.index end
 function self:get_height(p,cb) local floor=(api.destination_floor or api.floor)(p);cb(floor and floor.z or nil) end
 function self:stop()
  local owned=self.job~=nil
  self.job=nil;self.path={}
  -- An idle fallback must not clear another provider's shared movement.
  if owned then api.stop() end
 end
 local function fail(reason)
  local job=self.job;self:stop();emit("ground_navigation_failed",{reason=reason})
  if job then job.callback(false,reason) end
 end
 local function edge(a,b)
  if dist(a,b)>4 or math.abs(a.z-b.z)>1.5 then return false end
  local previous=a
  for i=1,4 do
   local t=i/4;local p={x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,z=a.z+(b.z-a.z)*t}
   local floor=api.floor(p)
   if not floor or math.abs(floor.z-p.z)>0.75 or math.abs(floor.z-previous.z)>1 then return false end
   previous=floor
  end
  return dist(a,b)<0.05 or api.clear(a,b)==true
 end
 local function begin(job)
  local pos=api.position();local start=(api.current_floor or api.floor)(pos)
  if not start or math.abs(start.z-pos.z)>2 then return fail("current_floor_unavailable") end
  local dx,dy=job.goal.x-start.x,job.goal.y-start.y
  local length=math.sqrt(dx*dx+dy*dy)
  local limit=job.segment_limit or 50
  local scale=length>limit and limit/length or 1
  local hint={x=start.x+dx*scale,y=start.y+dy*scale,z=start.z}
  -- Local segments must themselves reach measured terrain, never invented heights.
  local goal
  if scale==1 then goal=api.floor(job.goal)
  else goal=(api.destination_floor or api.floor)(hint) end
  if not goal and scale==1 and api.approach_clear then
   local best=math.huge
   for _,offset in ipairs({{2,0},{-2,0},{0,2},{0,-2},{1.4,1.4},{1.4,-1.4},{-1.4,1.4},{-1.4,-1.4}}) do
    local point=api.floor({x=job.goal.x+offset[1],y=job.goal.y+offset[2],z=job.goal.z})
    if point and dist(point,job.goal)<=2.5 and api.approach_clear(point,job.goal)==true and dist(start,point)<best then
     goal=point;best=dist(start,point)
    end
   end
   if goal then emit("destination_approach_floor",{x=goal.x,y=goal.y,z=goal.z}) end
  end
  if not goal then
   if scale<1 and limit>12.5 then
    job.segment_limit=limit/2
    emit("ground_segment_retry",{reason="segment_floor_unavailable",segment_length=job.segment_limit})
    return begin(job)
   end
   emit("ground_floor_probe_failed",{stage=scale==1 and "destination" or "segment",x=scale==1 and job.goal.x or hint.x,y=scale==1 and job.goal.y or hint.y,z=scale==1 and job.goal.z or hint.z})
   return fail("destination_floor_unavailable")
  end
  if scale==1 and math.abs(goal.z-job.goal.z)>2 then return fail("destination_floor_mismatch") end
  job.segment=goal;job.final=scale==1;job.origin=start
  job.grid=job.fine_grid and 0.5 or (length<=12.5 and 0.5 or 2)
  local first={x=start.x,y=start.y,z=start.z,g=0,ix=0,iy=0,key="0:0"}
  job.open={first};job.nodes={[first.key]=first};job.closed={};job.count=0;job.phase="planning"
  emit("ground_path_search",{map=job.map,x=goal.x,y=goal.y,z=goal.z,grid=job.grid})
 end
 local function search_failed(job,reason)
  local limit=job.segment_limit or 50
  local position=api.position()
  local remaining=math.sqrt((position.x-job.goal.x)^2+(position.y-job.goal.y)^2)
  if remaining>12.5 and limit>12.5 then
   job.segment_limit=limit/2
   emit("ground_segment_retry",{reason=reason,segment_length=job.segment_limit})
   begin(job);return
  end
  if job.grid>0.5 then
   job.fine_grid=true
   emit("ground_grid_refined",{reason=reason,grid=0.5})
   begin(job);return
  end
  fail(reason)
 end
 function self:move_to(goal,callback)
  self:stop()
  if not goal or not finite(goal.x) or not finite(goal.y) or not finite(goal.z) then callback(false,"invalid_destination");return end
  self.job={goal=goal,callback=callback,map=api.map(),instance=api.instance and api.instance(),last_position=api.position(),started=api.time()};begin(self.job)
 end
 function self:replan()
  local job=self.job;if not job then return false end
  api.stop();self.path={};begin(job);return true
 end
 local dirs={{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
 function self:update()
  local job=self.job;if not job then return end
  if api.instance and api.instance()~=job.instance then return fail("context_changed") end
  if api.map()~=job.map then
   local pos=api.position()
   if api.instance and api.instance()==job.instance and dist(pos,job.last_position)<=25 then
    job.map=api.map();job.last_position=pos
    emit("ground_zone_transition",{map=job.map,instance=job.instance});self:replan();return
   end
   return fail("area_changed")
  end
  job.last_position=api.position()
  local now=api.time()
  if api.paused and api.paused() then
   job.paused_at=job.paused_at or now;return
  end
  if job.paused_at then
   local elapsed=math.max(0,now-job.paused_at)
   job.started=job.started+elapsed
   if job.walk_progress_at then job.walk_progress_at=job.walk_progress_at+elapsed end
   job.paused_at=nil
  end
  if now-job.started>240 then return fail("ground_navigation_timeout") end
  if job.phase=="walking" then
   local pos=api.position();local point=self.path[self.index]
   if not point then return fail("path_empty") end
   if not job.walk_progress_position or dist(pos,job.walk_progress_position)>=0.5 then
    job.walk_progress_position={x=pos.x,y=pos.y,z=pos.z};job.walk_progress_at=now
   elseif now-job.walk_progress_at>=8 then
    return fail("progress_stalled")
   end
   -- Follow one validated edge at a time so library smoothing cannot cut corners.
   local horizontal=math.sqrt((pos.x-point.x)^2+(pos.y-point.y)^2)
   if horizontal<=math.min(0.8,(job.grid or 2)*0.4) and math.abs(pos.z-point.z)<=2 then
    api.stop();self.index=self.index+1
    if self.index>#self.path then
     if job.final and dist(pos,job.goal)<=3 then self.job=nil;self.path={};job.callback(true);return end
     begin(job);return
    end
    point=self.path[self.index]
    local measured=(api.current_floor or api.floor)(pos)
    if not measured or math.abs(measured.z-pos.z)>2 or not edge(measured,point) then return self:replan() end
    api.walk(point)
   else api.process() end
   return
  end
  for iteration=1,6 do
   if #job.open==0 then return search_failed(job,"no_verified_ground_path") end
   local best,bestScore=1,math.huge
   for i,node in ipairs(job.open) do local score=node.g+dist(node,job.segment);if score<bestScore then best,bestScore=i,score end end
   local current=table.remove(job.open,best);job.closed[current.key]=true;job.count=job.count+1
   if job.count>5000 then return search_failed(job,"ground_search_budget_exhausted") end
   local close=dist(current,job.segment)<=3
   local exact=close and edge(current,job.segment)
   local approach=job.final and close and dist(current,job.goal)<=2.5
       and api.approach_clear and api.approach_clear(current,job.goal)==true
   if exact or approach then
    -- A nearby reachable endpoint can serve an NPC whose exact footprint is blocked.
    -- The approach ray must be clear; proximity across a wall is never sufficient.
    local reverse=exact and {job.segment} or {};local cursor=current
    while cursor do reverse[#reverse+1]={x=cursor.x,y=cursor.y,z=cursor.z};cursor=cursor.parent end
    self.path={};for i=#reverse-1,1,-1 do self.path[#self.path+1]=reverse[i] end
    -- Join only collinear short edges, with the full combined edge verified again.
    local smooth={};local anchor=job.origin;local i=1
    while i<=#self.path do
     local point=self.path[i];local j=i+1
     while j<=#self.path do
      local next_point=self.path[j]
      local ax,ay=point.x-anchor.x,point.y-anchor.y
      local bx,by=next_point.x-anchor.x,next_point.y-anchor.y
      if dist(anchor,next_point)>3 or math.abs(ax*by-ay*bx)>0.01 or ax*bx+ay*by<=0 or not edge(anchor,next_point) then break end
      point=next_point;j=j+1
     end
     smooth[#smooth+1]=point;anchor=point;i=j
    end
    self.path=smooth
    self.index=1;job.phase="walking";job.walk_progress_position=nil;job.walk_progress_at=api.time();emit("ground_path_ready",{points=#self.path,expanded=job.count,nearby_approach=not exact})
    if #self.path==0 then
     if dist(api.position(),job.goal)<=3 then self.job=nil;job.callback(true);return end
     return fail("approach_position_mismatch")
    end
    local pos=api.position();local measured=(api.current_floor or api.floor)(pos)
    if not measured or math.abs(measured.z-pos.z)>2 or not edge(measured,self.path[1]) then
     emit("ground_start_edge_rejected",{x=pos.x,y=pos.y,z=pos.z,floor_z=measured and measured.z,
         target_x=self.path[1].x,target_y=self.path[1].y,target_z=self.path[1].z})
     return fail("start_edge_invalid")
    end
    api.walk(self.path[1]);return
   end
   for _,direction in ipairs(dirs) do
    local ix,iy=current.ix+direction[1],current.iy+direction[2];local key=ix..":"..iy
    if not job.closed[key] and math.abs(ix)<=100 and math.abs(iy)<=100 then
     local p=api.floor({x=job.origin.x+ix*job.grid,y=job.origin.y+iy*job.grid,z=current.z})
     if p and edge(current,p) then
      local cost=current.g+dist(current,p);local existing=job.nodes[key]
      if not existing then
       p.g=cost;p.ix=ix;p.iy=iy;p.key=key;p.parent=current;job.nodes[key]=p;job.open[#job.open+1]=p
      elseif cost<existing.g then existing.g=cost;existing.parent=current end
     end
    end
   end
  end
 end
 return self
end
return M
