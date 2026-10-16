local Data=require("bg_route_data")
local Policy=require("bg_route_policy")
local R={}
local function dist2(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function nearest(nodes,p) local id,best;for k,n in pairs(nodes) do local d=dist2(n,p);if not best or d<best or d==best and tostring(k)<tostring(id) then id,best=k,d end end;return id,best end
local function edge_cost(a,b)
 local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z
 local length=math.sqrt(dx*dx+dy*dy+dz*dz)
 -- Long graph edges are where straight-line requests most often meet scenery.
 -- Penalize them and large height changes so Dijkstra chooses a denser, gentler
 -- authored corridor when one exists.
 return length+math.max(0,length-45)*2+math.max(0,math.abs(dz)-8)*4
end
R.edge_cost=edge_cost
-- Binary min-heap for A*. Order: lowest f, then deepest g (closest to goal),
-- then id text, so equal-cost ties stay deterministic between reloads.
local Heap={}
local function heap_less(a,b)
 if a.f~=b.f then return a.f<b.f end
 if a.g~=b.g then return a.g>b.g end
 return a.key<b.key
end
function Heap.push(h,item)
 local n=h.n+1;h.n=n;h[n]=item
 while n>1 do
  local parent=math.floor(n/2)
  if heap_less(h[n],h[parent]) then h[n],h[parent]=h[parent],h[n];n=parent else break end
 end
end
function Heap.pop(h)
 local n=h.n;if n==0 then return nil end
 local top=h[1];h[1]=h[n];h[n]=nil;n=n-1;h.n=n
 local i=1
 while true do
  local l,r,m=i*2,i*2+1,i
  if l<=n and heap_less(h[l],h[m]) then m=l end
  if r<=n and heap_less(h[r],h[m]) then m=r end
  if m==i then break end
  h[i],h[m]=h[m],h[i];i=m
 end
 return top
end
-- Soft avoidance (strength = summed penalty, capped at 1200): a failed corridor is made expensive, never deleted, so the
-- only available route is still returned when every alternative is also bad.
-- (Blocked edges are penalized rather than removed; see RESEARCH_ROUTING.md.)
local function node_penalties(nodes,avoid)
 if type(avoid)~="table" or #avoid==0 then return nil end
 local out;local any=false
 for id,node in pairs(nodes) do
  local total=0
  for _,a in ipairs(avoid) do
   if type(a)=="table" and type(a.x)=="number" and type(a.y)=="number" then
    local radius=tonumber(a.radius) or 5
    local dx,dy=node.x-a.x,node.y-a.y
    local near_z=type(a.z)~="number" or math.abs(node.z-a.z)<=8
    if near_z and dx*dx+dy*dy<=radius*radius then total=total+(tonumber(a.penalty) or 400) end
   end
  end
  if total>0 then out=out or {};out[id]=math.min(total,1200);any=true end
 end
 return any and out or nil
end
local function path_touches(path,penalties)
 if not penalties or not path then return false end
 for _,id in ipairs(path) do if penalties[id] then return true end end
 return false
end
-- A* with the Euclidean distance as heuristic. edge_cost() is never smaller than
-- the straight-line length and penalties only add cost, so the heuristic stays
-- admissible and consistent: the result is a true least-cost path, found by
-- expanding far fewer nodes than the previous O(V^2) Dijkstra scan.
local function graph_path(g,start,goal,max_endpoint_distance,penalties)
 local nodes,links=g.nodes,g.links
 local source,source_distance=nearest(nodes,start);local target,target_distance=nearest(nodes,goal)
 if not source or not target or max_endpoint_distance and
  (source_distance>max_endpoint_distance^2 or target_distance>max_endpoint_distance^2) then return nil end
 local goal_node=nodes[target]
 local function h(id)
  local n=nodes[id];local dx,dy,dz=n.x-goal_node.x,n.y-goal_node.y,n.z-goal_node.z
  return math.sqrt(dx*dx+dy*dy+dz*dz)
 end
 local best={[source]=0};local previous={};local closed={}
 local heap={n=0};Heap.push(heap,{f=h(source),g=0,id=source,key=tostring(source)})
 while heap.n>0 do
  local item=Heap.pop(heap);local current=item.id
  if not closed[current] then
   closed[current]=true
   if current==target then break end
   for _,next_id in ipairs(links[current] or {}) do
    local next_node=nodes[next_id]
    if next_node and not closed[next_id] then
     local step=edge_cost(nodes[current],next_node)
     local strength=penalties and penalties[next_id]
     -- Entering an avoided node costs proportionally more (a blacklisted leg is
     -- ~4x) plus a small flat amount, so the same setting works for sparse
     -- strategic graphs with 300-yard legs and for dense 5-yard recorded lanes.
     if strength then step=step*(1+strength/200)+strength*0.25 end
     local candidate=item.g+step
     local known=best[next_id]
     if known==nil or candidate<known or candidate==known and tostring(current)<tostring(previous[next_id]) then
      best[next_id]=candidate;previous[next_id]=current
      Heap.push(heap,{f=candidate+h(next_id),g=candidate,id=next_id,key=tostring(next_id)})
     end
    end
   end
  end
 end
 if best[target]==nil or not closed[target] then return nil end
 local path={target};local cursor=target
 while cursor~=source do cursor=previous[cursor];if not cursor then return nil end;table.insert(path,1,cursor) end
 return path,source_distance,target_distance,source,target,best[target]
end
local spawn_node_names={h=true,a=true,fh=true,db=true,horde=true,alliance=true,
 horde_spawn=true,alliance_spawn=true,west_spawn=true,beach=true}
function R.route(profile,start,goal,force_graph,role,damage_style,client_family,avoid)
 if not Policy.allowed(client_family,profile) then return nil end
 local g=Data[profile];if not g or not start or not goal then return nil end
 local offmesh_profile=profile=="eye_standard" or profile=="eye_blitz" or profile=="eye_blitz_legacy"
 -- Live ArthasNav telemetry proved the southwest lower-basin approach to the
 -- Blacksmith contains an unwalkable step. Approach from Stables instead; its
 -- native path has gradual elevation on both legs and remains mount-safe.
 if (profile=="arathi" or profile=="arathi_blitz" or profile=="arathi_training" or profile=="arathi_comp_stomp") and
  start.x>=900 and start.x<=990 and start.y>=1040 and start.y<=1135 and start.z<=-55 and
  dist2(goal,g.nodes.bs)<=625 then
  local out={
   {x=g.nodes.st.x,y=g.nodes.st.y,z=g.nodes.st.z},
   {x=g.nodes.bs.x,y=g.nodes.bs.y,z=g.nodes.bs.z},
   source="live_arathi_lower_basin_bs_detour",coordinate_source="live_arthasnav_2107",
   route_quality="live_custom",waypoint_radius=7,lock_id="arathi_lower_basin_via_stables",
   direct=false,avoid_mount=false,allow_direct_fallback=false
  }
  return out
 end
 local objective_role=role=="tank" and "tank" or role=="damage" and "damage" or "healer"
 -- Objective roles always stay on the authored corridor graph. DPS and tanks
 -- must reach flags, bases and vehicles; a short raw diagonal can cut through
 -- scenery even when the destination is nearby. Healers may still use a local
 -- support path when already beside their moving formation.
 if objective_role=="damage" or objective_role=="tank" then force_graph=true end
 local local_radius=tonumber(g.local_direct_radius)
 local local_z=tonumber(g.local_direct_z) or 15
 if not force_graph and local_radius and local_radius>0 and math.abs(start.z-goal.z)<=local_z and
  dist2(start,goal)<=local_radius*local_radius then
  -- Returning nil delegates to Sentinel for a normal path to the live support
  -- point. On open local terrain this avoids routing backward through a distant
  -- strategic landmark before approaching a nearby moving group.
  return nil
 end
 -- Prefer the high-resolution path learned from chronological live movement.
 -- Both endpoints must be close and belong to the same recorded component.
 -- Dedicated opening corridors handle enclosed spawn rooms. Keep the strategic
 -- gate node while still inside a spawn so a nearby telemetry branch cannot
 -- select an interior point behind the player. Fifty-five yards covers formation points beside a traveled lane
 -- while staying below the bounded local-fallback limit.
 local selected=g
 local path,source_distance,_,source,target
 -- Unpenalized search: it fixes the stable spawn/lock identity and, when no
 -- avoidance applies, doubles as the final path (previously searched twice).
 local base_path,base_distance,_,base_source,base_target=graph_path(g,start,goal)
 local base_spawn=(type(g.spawn_nodes)=="table" and g.spawn_nodes[base_source]==true) or spawn_node_names[base_source]==true
 if not base_spawn then
  for id,node in pairs(g.nodes) do
   if ((type(g.spawn_nodes)=="table" and g.spawn_nodes[id]==true) or spawn_node_names[id]==true) and dist2(start,node)<=10000 then
    base_spawn=true;break
   end
  end
 end
 if type(g.recorded)=="table" and not base_spawn then
  local recorded_penalties=node_penalties(g.recorded.nodes,avoid)
  path,source_distance,_,source,target=graph_path(g.recorded,start,goal,55,recorded_penalties)
  if path then
   selected=g.recorded
   -- A recorded run is one traversed lane: when it crosses a leg that has been
   -- failing there may be no alternative inside it. Prefer the strategic graph
   -- if it offers a route that stays clear of every avoided leg.
   if path_touches(path,recorded_penalties) then
    local strategic_penalties=node_penalties(g.nodes,avoid)
    local alt,alt_distance,_,alt_source,alt_target=graph_path(g,start,goal,nil,strategic_penalties)
    if alt and not path_touches(alt,strategic_penalties) then
     path,source_distance,source,target=alt,alt_distance,alt_source,alt_target;selected=g
    end
   end
  end
 end
 if not path then
  local penalties=node_penalties(g.nodes,avoid)
  if penalties then path,source_distance,_,source,target=graph_path(g,start,goal,nil,penalties)
  else path,source_distance,source,target=base_path,base_distance,base_source,base_target end
 end
 if not path then return nil end
 local role_radius=objective_role=="damage" and (damage_style=="ranged" and 8 or 5) or objective_role=="tank" and 7 or nil
 local radius=math.max(2,math.min(18,(selected.chronological==true and tonumber(selected.waypoint_radius)) or role_radius or tonumber(selected.waypoint_radius) or tonumber(g.waypoint_radius) or 18))
 -- The selected graph declares whether it requires local on-foot steering.
 -- Recorded field coordinates constrain ArthasNav one short leg at a time;
 -- they are evidence for the corridor, not evidence that a straight line is
 -- clear. Only profiles explicitly known to be off-mesh bypass the nav engine.
 local spawn_entry=selected==g and ((type(g.spawn_nodes)=="table" and g.spawn_nodes[source]==true) or spawn_node_names[source]==true)
 -- A verified custom graph is also a valid emergency corridor when ArthasNav
 -- is unavailable. The controller still steers one authored leg
 -- at a time; arbitrary live objectives never receive this permission.
 -- EOTS contract: its elevation-sensitive profile remains explicitly off-mesh.
 -- Every other recorded field graph is ArthasNav-first; short geometric
 -- distance is not proof that terrain between two anchors is walkable.
 local traversed=selected.chronological==true
 local out={allow_direct_fallback=traversed,direct=offmesh_profile,avoid_mount=selected.avoid_mount==true or offmesh_profile,
  escape_priority=spawn_entry,
  route_quality=selected.chronological==true and "live_traversed" or g.verified_custom==true and "live_custom" or "navmesh_anchor",
  source=g.source or "public_bgbuddy_profile",coordinate_source=selected.source or g.source or "authored_battleground_route",waypoint_radius=radius,
  lock_id=spawn_entry and ("spawn_egress_"..profile.."_"..tostring(source)) or
   ("role_corridor_"..objective_role.."_"..tostring(damage_style or "default").."_"..tostring(base_target or target))}
 -- When spawning away from the graph, the nearest node is the entry corridor.
 -- Skipping it sends the first request to the following node, often across a wall
 -- or graveyard ledge. A player already within its arrival radius can skip it.
 -- Spawn nodes describe where a route begins, not a destination to revisit.
 -- Once opening recovery has put the player outside the enclosure, including
 -- the nearest spawn node sends them backward into the room or graveyard.
 local first=spawn_entry and 2 or source_distance>radius*radius and 1 or 2
 -- Joining a sparse strategic graph mid-field must not send the character
 -- backward to the nearest objective before advancing. Skip only that entry
 -- node; Sentinel still owns the terrain path to the next authored anchor.
 if selected==g and not base_spawn and not spawn_entry and first==1 and #path>=2 then
  local entry=g.nodes[path[1]]
  local ex,ey=entry.x-start.x,entry.y-start.y
  local gx,gy=goal.x-start.x,goal.y-start.y
  if ex*gx+ey*gy<0 and ex*ex+ey*ey>100 then first=2 end
 end
 for i=first,#path do out[#out+1]=selected.nodes[path[i]] end
 -- dist2 is squared distance: 25 means a five-yard final-position tolerance.
 if #out==0 or dist2(out[#out],goal)>25 then out[#out+1]=goal end
 return out
end
function R.audit()
 local issues={}
 for profile,g in pairs(Data) do
  if type(g.nodes)~="table" or type(g.links)~="table" then issues[#issues+1]=profile..":missing_graph"
  else
   local first_id=next(g.nodes);local seen={};local queue=first_id and {first_id} or {};if first_id then seen[first_id]=true end
   local head=1
   while head<=#queue do
    local id=queue[head];head=head+1
    for _,next_id in ipairs(g.links[id] or {}) do
     if g.nodes[next_id] and not seen[next_id] then seen[next_id]=true;queue[#queue+1]=next_id end
    end
   end
   for id,node in pairs(g.nodes) do
    if type(node.x)~="number" or type(node.y)~="number" or type(node.z)~="number" then
     issues[#issues+1]=profile..":"..tostring(id)..":invalid_position"
    end
    for _,next_id in ipairs(g.links[id] or {}) do
     if not g.nodes[next_id] then issues[#issues+1]=profile..":"..tostring(id)..":missing_link:"..tostring(next_id) end
    end
    if not seen[id] and g.chronological~=true then issues[#issues+1]=profile..":"..tostring(id)..":disconnected" end
   end
   if g.local_direct_radius~=nil and (type(g.local_direct_radius)~="number" or g.local_direct_radius<=0) then
    issues[#issues+1]=profile..":invalid_local_direct_radius"
   end
   if g.local_direct_z~=nil and (type(g.local_direct_z)~="number" or g.local_direct_z<=0) then
    issues[#issues+1]=profile..":invalid_local_direct_z"
   end
  end
 end
 table.sort(issues);return issues
end
function R.quality()
 local rows={}
 for profile,g in pairs(Data) do
  local node_count,edge_count,max_xy,max_z=0,0,0,0
  for _ in pairs(g.nodes or {}) do node_count=node_count+1 end
  for id,links in pairs(g.links or {}) do
   local a=g.nodes and g.nodes[id]
   for _,next_id in ipairs(links) do
    local b=g.nodes and g.nodes[next_id]
    if a and b then
     local dx,dy=a.x-b.x,a.y-b.y
     max_xy=math.max(max_xy,math.sqrt(dx*dx+dy*dy));max_z=math.max(max_z,math.abs(a.z-b.z));edge_count=edge_count+1
    end
   end
  end
  rows[#rows+1]={profile=profile,quality=g.verified_custom==true and "custom" or "navmesh",
   nodes=node_count,edges=edge_count,max_leg=max_xy,max_elevation=max_z,
   has_recorded=type(g.recorded)=="table" or g.chronological==true}
 end
 table.sort(rows,function(a,b)return a.profile<b.profile end)
 return rows
end
-- Route-aware travel distance for objective scoring. Straight-line distance
-- ignores folded maps (Alterac, Deephaul, Isle). Cached by 10-yard cells because
-- the authored graphs never change at runtime. Always >= straight-line distance.
local travel_cache,travel_cache_size={},0
function R.travel_distance(profile,start,goal,client_family)
 if type(start)~="table" or type(goal)~="table" then return nil end
 local ok_x=type(start.x)=="number" and type(goal.x)=="number" and type(start.y)=="number" and
  type(goal.y)=="number" and type(start.z)=="number" and type(goal.z)=="number"
 if not ok_x then return nil end
 local key=table.concat({tostring(profile),tostring(client_family),math.floor(start.x/10),math.floor(start.y/10),
  math.floor(start.z/10),math.floor(goal.x/10),math.floor(goal.y/10),math.floor(goal.z/10)},":")
 local cached=travel_cache[key]
 if cached~=nil then return cached~=false and cached or nil end
 local path=R.route(profile,start,goal,true,"damage",nil,client_family)
 local total
 if path and #path>0 then
  total=0;local previous=start
  for _,point in ipairs(path) do
   local dx,dy,dz=point.x-previous.x,point.y-previous.y,point.z-previous.z
   total=total+math.sqrt(dx*dx+dy*dy+dz*dz);previous=point
  end
 end
 if travel_cache_size>=512 then travel_cache={};travel_cache_size=0 end
 travel_cache[key]=total or false;travel_cache_size=travel_cache_size+1
 return total
end
-- Advisory graph review; R.audit() above keeps its original blocking meaning.
-- Reports one-way links, duplicate positions, dead ends and strategic legs over
-- 450 yards (candidates for an extra recorded intermediate waypoint). Profiles
-- that alias another profile's table (arathi_blitz = arathi) are reported once.
function R.audit_extended()
 local warnings={};local seen_tables={}
 local names={};for profile in pairs(Data) do names[#names+1]=profile end;table.sort(names)
 for _,profile in ipairs(names) do
  local g=Data[profile]
  if type(g)=="table" and type(g.nodes)=="table" and type(g.links)=="table" and not seen_tables[g] then
   seen_tables[g]=true
   local seen_position,seen_pair={},{}
   for id,node in pairs(g.nodes) do
    local key=string.format("%.0f:%.0f:%.0f",node.x,node.y,node.z)
    if seen_position[key] then warnings[#warnings+1]=profile..":"..tostring(id)..":duplicate_position_of:"..tostring(seen_position[key]) else seen_position[key]=id end
    for _,next_id in ipairs(g.links[id] or {}) do
     local back=false
     for _,reverse in ipairs(g.links[next_id] or {}) do if reverse==id then back=true;break end end
     if not back and g.nodes[next_id] then warnings[#warnings+1]=profile..":"..tostring(id).."->"..tostring(next_id)..":one_way_link" end
     local other=g.nodes[next_id]
     local a,b=tostring(id),tostring(next_id);if b<a then a,b=b,a end
     if other and not seen_pair[a.."|"..b] then
      seen_pair[a.."|"..b]=true
      local dx,dy=node.x-other.x,node.y-other.y
      local length=math.sqrt(dx*dx+dy*dy)
      if length>450 then warnings[#warnings+1]=string.format("%s:%s<->%s:very_long_leg:%.0f_yards",profile,a,b,length) end
     end
    end
    if #(g.links[id] or {})==0 and g.chronological~=true then warnings[#warnings+1]=profile..":"..tostring(id)..":no_outgoing_links" end
   end
  end
 end
 table.sort(warnings);return warnings
end
function R.elevation_recovery(profile,start,client_family)
 if not Policy.allowed(client_family,profile) then return nil end
 if (profile~="eye_standard" and profile~="eye_blitz" and profile~="eye_blitz_legacy") or
  not start or type(start.z)~="number" or start.z>=1148 then return nil end
 -- Live 0.41.2 telemetry proved this continuous east-side slope from the
 -- Eye of the Storm center floor back to the upper objective platform.
 local out={
  {x=2154.0,y=1579.6,z=1130.4},
  {x=2124.2,y=1581.0,z=1140.6},
  {x=2119.3,y=1557.3,z=1157.7}
 }
 out.direct=true;out.avoid_mount=true;out.allow_direct_fallback=true;out.waypoint_radius=4;out.source="live_eye_center_elevation_recovery"
 out.lock_id="eye_center_lower_level_recovery";out.escape_priority=true
 return out
end
function R.opening_recovery(profile,start,client_family)
 if not Policy.allowed(client_family,profile) then return nil end
 if (profile=="deepwind_modern" or profile=="deepwind_blitz") and start and
  type(start.x)=="number" and type(start.y)=="number" and type(start.z)=="number" then
  -- Deepwind's elevated starting platforms and gates are not represented by
  -- the sparse strategic graph. These coordinates are the ordered positions
  -- observed in the Horde start descent plus the faction gate nodes. Keep the
  -- opening atomic and on foot so a missing Sentinel client cannot strand the
  -- player or let an objective refresh cut across the enclosure.
  local points,first,lock,source
  if start.x>=-140 and start.x<=-30 and start.y>=770 and start.y<=865 and start.z>=125 and start.z<=150 then
   points={{x=-67.1,y=821.1,z=139.2},{x=-87.9,y=811.5,z=133.6},
    {x=-70.3,y=781.3,z=132.3},{x=-35.0,y=755.0,z=126.0}}
   if start.y>=828 or start.z>=138 then first=1
   elseif start.y>=795 then first=2
   elseif start.y>=770 then first=3 end
   lock="deepwind_horde_spawn_egress";source="live_deepwind_horde_spawn_egress"
  elseif start.x>=-310 and start.x<=-190 and start.y>=140 and start.y<=245 and start.z>=125 and start.z<=145 then
   points={{x=-250.0,y=205.0,z=133.2},{x=-208.5,y=205.3,z=131.3}}
   first=start.x>=-240 and 2 or 1
   lock="deepwind_alliance_spawn_egress";source="deepwind_alliance_gate_egress"
  end
  if points and first then
   local out={source=source,waypoint_radius=5,lock_id=lock,direct=true,escape_priority=true,
    allow_direct_fallback=true,avoid_mount=true}
   for i=first,#points do out[#out+1]=points[i] end
   return out
  end
 end
 if profile=="twin_peaks" and start and type(start.x)=="number" and
  type(start.y)=="number" and type(start.z)=="number" then
  -- Twin Peaks bases have doors and sharp elevation transitions.  Hold a
  -- short, forward-only route until clear ground so moving objectives cannot
  -- retarget the character back through a wall or trigger a mount indoors.
  local points,first,lock,source
  if start.x>=1535 and start.x<=1630 and start.y>=280 and start.y<=390 and start.z>=-3 and start.z<=8 then
   points={{x=1557.4,y=309.8,z=0.1},{x=1577.6,y=297.9,z=0.1},{x=1600.3,y=287.5,z=0.1}}
   first=1
   if start.x>=1588 then first=3 elseif start.y<=304 or start.x>=1568 then first=2 end
   lock="twin_peaks_horde_base_egress";source="live_twin_peaks_horde_base_egress"
  elseif start.x>=2080 and start.x<=2170 and start.y>=125 and start.y<=275 and start.z>=28 and start.z<=52 then
   points={{x=2118.1,y=154.7,z=43.6},{x=2096.7,y=146.0,z=36.2},{x=2043.0,y=159.9,z=13.0}}
   first=1
   if start.x<=2060 or start.z<25 then first=3 elseif start.x<=2105 or start.z<40 then first=2 end
   lock="twin_peaks_alliance_base_egress";source="live_twin_peaks_alliance_base_egress"
  end
  if points then
   local out={source=source,waypoint_radius=5,lock_id=lock,direct=false,escape_priority=true,
    allow_direct_fallback=false,avoid_mount=true}
   for i=first,#points do out[#out+1]=points[i] end
   return out
  end
 end
 if (profile=="arathi" or profile=="arathi_blitz" or profile=="arathi_training" or profile=="arathi_comp_stomp") and
  start and type(start.x)=="number" and type(start.y)=="number" and type(start.z)=="number" and
  start.x>=650 and start.x<=825 and start.y>=650 and start.y<=900 and start.z>=-70 and start.z<=5 then
  -- Horde AB gate and road to Farm. Live v0.53.0 telemetry proved the spawn,
  -- gate and first exterior position; short continuations follow the graph's
  -- verified Farm endpoint and prevent the spawn node becoming the destination.
  local points={{x=708.1,y=708.8,z=-17.6},{x=716.0,y=720.0,z=-21.7},
   {x=735.0,y=752.0,z=-30.0},{x=758.0,y=793.0,z=-42.0},
   {x=780.0,y=835.0,z=-51.0},{x=817.0,y=880.0,z=-56.4}}
  local first=1
  while first<=#points and start.y>=points[first].y-5 do first=first+1 end
  if first>#points then return nil end
  local out={source="live_arathi_horde_spawn_egress",waypoint_radius=6,escape_priority=true,
   lock_id="arathi_horde_spawn_egress",direct=false,allow_direct_fallback=false,avoid_mount=true}
  for i=first,#points do out[#out+1]=points[i] end
  return out
 end
 if profile=="deephaul" and start and type(start.x)=="number" and type(start.y)=="number" and type(start.z)=="number" and
  start.x>=4070 and start.x<=4190 and start.y>=-2940 and start.y<=-2520 and start.z>=190 then
  -- Repeated live runs proved this complete north-spawn descent. The recorded
  -- graph has closely packed samples on both sides of the ramp, so nearest-node
  -- routing can select an already-passed uphill sample.
  local points={
   {x=4159.1,y=-2583.5,z=274.3},{x=4156.1,y=-2607.8,z=262.3},
   {x=4149.2,y=-2634.8,z=257.5},{x=4149.2,y=-2649.4,z=248.8},
   {x=4149.4,y=-2666.0,z=244.7},{x=4145.0,y=-2693.5,z=239.5},
   {x=4140.3,y=-2720.7,z=229.2},{x=4133.0,y=-2747.6,z=222.8},
   {x=4124.5,y=-2773.1,z=219.5},{x=4116.9,y=-2795.9,z=213.1},
   {x=4109.0,y=-2821.7,z=203.1},{x=4096.8,y=-2842.1,z=199.3},
   {x=4080.7,y=-2911.3,z=201.2}
  }
  local first=1
  while first<=#points and start.y<=points[first].y+5 do first=first+1 end
  if first>#points then return nil end
  local out={source="live_deephaul_north_spawn_egress",waypoint_radius=5,escape_priority=true,
   lock_id="deephaul_north_spawn_egress",direct=false,allow_direct_fallback=false,avoid_mount=true}
  for i=first,#points do out[#out+1]=points[i] end
  return out
 end
 if (profile=="eye_standard" or profile=="eye_blitz" or profile=="eye_blitz_legacy") and start and
  type(start.x)=="number" and type(start.y)=="number" and type(start.z)=="number" and
  start.x>=1780 and start.x<2000 and start.y>=1490 and start.y<=1585 and start.z>=1170 then
  -- The west EOTS spawn descends on a narrow elevated ramp. Live 0.48.12
  -- telemetry showed an objective refresh selecting a waypoint behind the
  -- player at x=1838, causing a turn at the edge and a fall. Keep this egress
  -- forward-only and locked until the lower platform is reached.
  local points={
   {x=1837.8,y=1540.9,z=1234.1},
   {x=1892.7,y=1542.6,z=1198.8},
   {x=1972.8,y=1545.1,z=1171.9},
   {x=2035.4,y=1545.2,z=1165.3}
  }
  local first=1
  if start.x>=1950 then first=4
  elseif start.x>=1875 then first=3
  elseif start.x>=1828 then first=2 end
  local out={source="live_eye_west_spawn_egress",waypoint_radius=5,escape_priority=true,
   lock_id="eye_west_spawn_egress",direct=true,allow_direct_fallback=true,avoid_mount=true}
  for i=first,#points do out[#out+1]=points[i] end
  return out
 end
 if profile=="warsong" and start and type(start.x)=="number" and type(start.y)=="number" and type(start.z)=="number" then
  -- WSG Horde flag room/tunnel. Return only forward points as the player
  -- advances so a refreshed healer target can never restart at the flag.
  -- Sentinel handles each short leg; direct steering would cut through walls.
  if start.x>=900 and start.x<1075 and start.y>=1350 and start.y<=1495 and start.z>=323 then
   local points={
    {x=975.0,y=1436.0,z=345.0},
    {x=1021.4,y=1411.0,z=341.4},
    {x=1058.2,y=1375.9,z=328.6},
    {x=1086.6,y=1390.4,z=319.8}
   }
   -- X alone cannot measure progress here: the room exit bends south before
   -- descending. Live v0.48.1 reached x=1007,y=1453,z=349 and incorrectly
   -- skipped the bend, producing an off-mesh request through the wall.
   local first=1
   if start.z<334 or start.y<1395 then first=4
   elseif start.z<343 or start.y<1420 then first=3
   elseif start.x>=965 then first=2 end
   local out={source="live_warsong_horde_flagroom_exit",waypoint_radius=6,escape_priority=true,
    lock_id="warsong_horde_flagroom_exit",direct=true,allow_direct_fallback=true,avoid_mount=true}
   for i=first,#points do out[#out+1]=points[i] end
   return out
  end
  -- The lower Horde tunnel mouth is also absent from Forever's Sentinel mesh.
  -- Live v0.79.0 stopped at 1085.0,1343.8,318.0 after clearing the room.
  -- Steer back through the proven field mouth and onto the first meshed field
  -- coordinate before combat or objective travel can take control.
  if start.x>=1040 and start.x<=1120 and start.y>=1320 and start.y<1410 and start.z>=310 and start.z<325 then
   local out={{x=1086.6,y=1390.4,z=319.8},{x=1174.2,y=1433.9,z=312.0}}
   out.source="live_warsong_horde_tunnel_mouth_exit";out.waypoint_radius=6
   out.lock_id="warsong_horde_tunnel_mouth_exit";out.direct=true
   out.allow_direct_fallback=true;out.avoid_mount=true;out.escape_priority=true
   return out
  end
  -- Alliance room: keep the stable known ramp-to-field corridor locked and
  -- omit the flag-object node. Its room geometry is covered by Sentinel.
  if start.x>1475 and start.x<=1585 and start.y>=1400 and start.y<=1545 and start.z>=338 then
   local out={{x=1492.7,y=1457.8,z=344.9},{x=1445.0,y=1490.0,z=330.0},{x=1395.0,y=1515.0,z=320.0}}
   out.source="warsong_alliance_flagroom_exit";out.waypoint_radius=6;out.lock_id="warsong_alliance_flagroom_exit"
   out.direct=true;out.allow_direct_fallback=true;out.avoid_mount=true;out.escape_priority=true
   return out
  end
 end
 if (profile~="gilneas" and profile~="gilneas_training") or not start or
  type(start.x)~="number" or type(start.y)~="number" or type(start.z)~="number" or
  start.x<=1235 or start.x>1450 or start.y<930 or start.y>1020 or start.z>12 then return nil end
 -- Live 0.41.3 Horde-start telemetry: lower ship interior, deck supplies,
 -- gate helper, then clear ground beyond the gate. Keep this locked and on
 -- foot: mounting inside the ship stalls, while an unlocked refresh can select
 -- a waypoint behind the player and walk back into the room.
 local out={
  {x=1422.2,y=983.6,z=4.3},
  {x=1410.0,y=980.5,z=6.2},
  {x=1399.5,y=978.4,z=7.4},
  {x=1389.3,y=973.3,z=5.7},
  {x=1368.0,y=970.0,z=5.5},
  {x=1343.3,y=980.0,z=3.5},
  {x=1325.6,y=981.1,z=3.8},
  {x=1300.0,y=972.0,z=4.6},
  {x=1263.0,y=955.1,z=5.7},
  {x=1249.6,y=959.3,z=6.2}
 }
 local first=1
 while first<=#out and start.x<=out[first].x+4 do first=first+1 end
 if first>#out then return nil end
 for i=1,first-1 do table.remove(out,1) end
 out.direct=true;out.avoid_mount=true;out.allow_direct_fallback=true;out.waypoint_radius=4
 out.escape_priority=true
 out.lock_id="gilneas_horde_ship_egress";out.source="live_gilneas_horde_ship_egress"
 return out
end
return R
