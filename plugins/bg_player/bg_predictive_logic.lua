-- Shared, bounded tactical evidence. It never invents map state or movement.
local L={};L.__index=L
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function dist(a,b)
 if not a or not b then return math.huge end
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
function L.new()
 return setmetatable({providers={},routes={},events={},last_event_at=0},L)
end
function L:provider_result(name,ok,latency,now)
 name=tostring(name or "unknown");local r=self.providers[name] or {success=0,failure=0,latency=0,samples=0,cooldown=0}
 r.samples=r.samples+1;r.latency=r.latency+(clamp(tonumber(latency) or 0,0,30)-r.latency)/math.min(r.samples,20)
 if ok then r.success=r.success+1;r.failure=math.max(0,r.failure-1);r.cooldown=0
 else r.failure=r.failure+1;if r.failure>=3 then r.cooldown=(tonumber(now) or 0)+math.min(30,2^math.min(4,r.failure-2)) end end
 self.providers[name]=r;return r
end
function L:provider_score(name,now)
 local r=self.providers[tostring(name or "unknown")];if not r then return 50 end
 if (r.cooldown or 0)>(tonumber(now) or 0) then return -100 end
 local total=r.success+r.failure
 return clamp(50+(total>0 and (r.success-r.failure)/total*35 or 0)-r.latency*2,0,100)
end
function L:route_key(scope,profile,team,spawn,id)
 -- Preserve the established scope/profile/team/objective prefix used by the
 -- route store and diagnostics; append spawn isolation as an extra dimension.
 return table.concat({tostring(scope or "shared"),tostring(profile or "unknown"),tostring(team or "unknown"),tostring(id or "route"),tostring(spawn or "unknown")},":")
end
function L:route_result(key,ok)
 local r=self.routes[key] or {success=0,failure=0}
 if ok then r.success=r.success+1;r.failure=math.max(0,r.failure-1) else r.failure=r.failure+1 end
 self.routes[key]=r;return r
end
function L:route_adjustment(key)
 local r=self.routes[key];if not r then return 0 end
 return clamp(r.success*2-r.failure*8,-40,16)
end
function L.route_length(origin,route,index)
 local total=0;local last=origin
 for i=math.max(1,index or 1),type(route)=="table" and #route or 0 do total=total+dist(last,route[i]);last=route[i] end
 return total
end
function L.shadow_switch(origin,current,current_index,candidate)
 if type(current)~="table" or type(candidate)~="table" or #candidate==0 or current.transition_lock or current.escape_priority then return false end
 local old=L.route_length(origin,current,current_index);local new=L.route_length(origin,candidate,1)
 return old>40 and new+15<old and new<=old*0.78,new,old
end
function L.layer_gate(origin,route,index)
 local p=type(route)=="table" and route[index or 1];if not p or not origin then return false end
 return math.abs((p.z or 0)-(origin.z or 0))>=6 or p.transition_gate==true
end
function L.team_flow(snapshot,position)
 local moving,stalled=0,0
 for _,row in ipairs(snapshot.friendly_positions or {}) do
  local p=row.position or row
  if p and dist(p,position)<=35 then
   if row.dead==true or row.stationary==true or row.trapped==true then stalled=stalled+1
   elseif row.moving==true then moving=moving+1 end
  end
 end
 return clamp(moving*5-stalled*7,-21,25),moving,stalled
end
function L.objective_key(kind,id,pos)
 if id~=nil and tostring(id)~="" then return tostring(kind)..":"..tostring(id) end
 return tostring(kind)..":"..tostring(pos and pos.x or "")..":"..tostring(pos and pos.y or "")..":"..tostring(pos and pos.z or "")
end
function L.fight_outlook(snapshot,position)
 local allies,enemies,ally_healers,enemy_healers=0,0,0,0
 for _,row in ipairs(snapshot.friendly_positions or {}) do local p=row.position or row;if p and dist(p,position)<=30 and row.dead~=true then allies=allies+1;if row.role=="healer" then ally_healers=ally_healers+1 end end end
 for _,row in ipairs(snapshot.enemies or {}) do local p=row.position or row;if p and dist(p,position)<=30 and row.dead~=true then enemies=enemies+1;if row.role=="healer" then enemy_healers=enemy_healers+1 end end end
 local value=(allies-enemies)*10+(ally_healers-enemy_healers)*8
 return value>=15 and "advantage" or value<=-15 and "disadvantage" or "even",clamp(value,-40,40)
end
function L.objective_handoff(snapshot,row,position)
 if not row or row.urgent==true or row.enemy_capture_in_progress==true then return false end
 local contributors=tonumber(row.friendly_count) or 0
 if contributors<1 then
  for _,friend in ipairs(snapshot.friendly_positions or {}) do local p=friend.position or friend;if p and dist(p,position)<=8 then contributors=contributors+1 end end
 end
 return contributors>=2 and (tonumber(row.enemy_count) or 0)==0
end
function L.intercept_position(row,origin)
 local p=row and row.position;if not p then return nil end
 local vx,vy=tonumber(row.velocity_x),tonumber(row.velocity_y)
 if not vx or not vy or vx~=vx or vy~=vy or math.abs(vx)>20 or math.abs(vy)>20 then return p end
 local horizon=clamp(dist(origin,p)/7,0.5,3)
 return {x=p.x+vx*horizon,y=p.y+vy*horizon,z=p.z}
end
function L.respawn_modifier(snapshot,kind)
 local aggressive=kind=="fight" or kind=="capture" or kind=="occupy" or kind=="advance" or kind=="intercept"
 if not aggressive or type(snapshot.observed_at)~="number" or type(snapshot.friendly_respawn_wave_at)~="number" then return 0 end
 local remaining=snapshot.friendly_respawn_wave_at-snapshot.observed_at
 if remaining<0 or remaining>8 then return 0 end
 local nearby=0
 for _,row in ipairs(snapshot.friendly_positions or {}) do local p=row.position or row;if row.dead~=true and p and dist(p,snapshot.player_position)<=35 then nearby=nearby+1 end end
 return nearby<2 and -25 or 0
end
function L.congestion_modifier(snapshot,position)
 local blocked=0
 for _,row in ipairs(snapshot.friendly_positions or {}) do
  local p=row.position or row
  if p and dist(p,position)<=10 and (row.stationary==true or row.trapped==true) then blocked=blocked+1 end
 end
 return blocked>=3 and -35 or 0,blocked
end
function L.oscillation_penalty(history,key,now)
 if type(history)~="table" then return 0 end
 local switches,last=0
 for i=#history,1,-1 do
  local row=history[i];if now-(row.at or 0)>8 then break end
  if last and row.key~=last then switches=switches+1 end;last=row.key
 end
 if switches<3 then return 0 end
 local latest=history[#history]
 if latest and latest.key~=key then return switches>=5 and -60 or -35 end
 return 0
end
function L.evidence_confidence(row,now)
 if type(row)~="table" then return nil end
 local confidence=tonumber(row.confidence)
 if confidence and (confidence~=confidence or confidence<0 or confidence>1) then return 0 end
 local samples=tonumber(row.samples)
 if samples and (samples<0 or samples~=math.floor(samples)) then return 0 end
 local observed=tonumber(row.observed_at)
 if observed and now and (observed>now or now-observed>3) then return 0 end
 if confidence then return confidence end
 if samples then return clamp(samples/3,0,1) end
 return nil
end
function L.objective_confidence(row,now)
 local c=L.evidence_confidence(row,now)
 if c==nil then return 0 end
 return c<0.4 and -30 or c>=0.8 and 6 or 0
end
function L.focus_fire(row)
 if type(row)~="table" then return 0 end
 local attackers=math.max(0,math.floor(tonumber(row.friendly_attackers) or 0))
 local health=tonumber(row.health_ratio)
 if not health or health<0 or health>1 then return 0 end
 if row.objective_carrier==true or row.role=="healer" then return health<=0.35 and 18 or 0 end
 if health<=0.2 and attackers>=3 then return -22 end
 if health<=0.35 and attackers<=2 then return 15 end
 return 0
end
function L.incoming_pressure(snapshot,position)
 local count=0
 for _,row in ipairs(snapshot.enemies or {}) do
  local p=row.position or row
  if p and row.dead~=true and row.moving_toward_objective==true and dist(p,position)<=55 then count=count+1 end
 end
 return math.min(30,count*10),count
end
function L.mount_benefit(distance,mount_seconds,walk_speed,ride_speed)
 distance=tonumber(distance);if not distance or distance~=distance or distance<0 then return nil end
 mount_seconds=clamp(tonumber(mount_seconds) or 1.5,0,10);walk_speed=clamp(tonumber(walk_speed) or 5,1,20);ride_speed=clamp(tonumber(ride_speed) or 10,walk_speed,30)
 return distance/walk_speed-(mount_seconds+distance/ride_speed)
end
function L.recovery_stage(failures)
 failures=math.max(0,math.floor(tonumber(failures) or 0))
 if failures>=5 then return "strategic_replan" end
 return ({"micro_correction","alternate_waypoint","local_detour","provider_change","route_restart"})[failures+1]
end
function L:event(kind,detail,now)
 self.events[#self.events+1]={kind=kind,detail=detail,at=now};if #self.events>200 then table.remove(self.events,1) end
end
return L
