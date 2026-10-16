local V={}
function V.finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
function V.position(p)
 local ok,x,y,z=pcall(function() return p.x,p.y,p.z end)
 if ok and V.finite(x) and V.finite(y) and V.finite(z) then return {x=x,y=y,z=z} end
end
-- Validate and detach route geometry before a provider or graph can move us.
function V.route(route)
 if type(route)~="table" then return nil,"invalid_route" end
 local out={};local count=0
 for key,value in pairs(route) do
  if type(key)=="number" then
   if key%1~=0 or key<1 or key>512 then return nil,"invalid_route_index" end
   local position=V.position(value)
   if not position then return nil,"invalid_route_position" end
   out[key]=position;count=count+1
  elseif key~="direct" and key~="allow_direct_fallback" and key~="escape_priority" and key~="source" and key~="coordinate_source" and key~="route_quality" and key~="waypoint_radius" and key~="lock_id" and key~="avoid_mount" then
   return nil,"invalid_route_metadata"
  end
 end
 for i=1,count do if not out[i] then return nil,"sparse_route" end end
 for _,key in ipairs({"direct","allow_direct_fallback","avoid_mount","escape_priority"}) do
  if route[key]~=nil and type(route[key])~="boolean" then return nil,"invalid_route_boolean" end
  out[key]=route[key]
 end
 if route.source~=nil and type(route.source)~="string" then return nil,"invalid_route_source" end
 out.source=route.source
 if route.coordinate_source~=nil and type(route.coordinate_source)~="string" then return nil,"invalid_route_coordinate_source" end
 out.coordinate_source=route.coordinate_source
 if route.route_quality~=nil and type(route.route_quality)~="string" then return nil,"invalid_route_quality" end
 out.route_quality=route.route_quality
 if route.lock_id~=nil and type(route.lock_id)~="string" then return nil,"invalid_route_lock" end
 out.lock_id=route.lock_id
 if route.waypoint_radius~=nil then
  if not V.finite(route.waypoint_radius) or route.waypoint_radius<=0 then return nil,"invalid_route_radius" end
  out.waypoint_radius=math.max(2,math.min(18,route.waypoint_radius))
 end
 return out
end
local groups={"nodes","flags","orbs","carts","crystals","resources","objectives","graveyards","enemies","friendly_positions"}
local booleans={"valid","carrying","own_flag_home","carry_destination_valid","has_owned_node","carrier_in_danger","capture_in_progress",
 "active","destroyed","capturable","locked","threatened","proximity","dropped","carrier_enemy","available","pickup_allowed",
 "delivered","contested","near_depot","reachable","depleted","mineable","completed","requires_vehicle","vehicle_stalled","attackable","dead","is_battleground_opponent","enemy_capture_in_progress","fallback_advance","moving","stationary","trapped","urgent","moving_toward_objective","under_attack","objective_carrier"}
local counts={"enemies","defenders","friendly_count","enemy_count"}
local function fields(item,is_snapshot)
 for _,key in ipairs(booleans) do
  if item[key]~=nil and type(item[key])~="boolean" then return nil,"invalid_boolean:"..key end
 end
 if not is_snapshot then
  for _,key in ipairs(counts) do
   local n=item[key];if n~=nil and (not V.finite(n) or n<0 or n~=math.floor(n)) then return nil,"invalid_count:"..key end
  end
  if item.control_radius~=nil and (not V.finite(item.control_radius) or item.control_radius<=0) then return nil,"invalid_control_radius" end
  if item.carrier_pressure~=nil and (not V.finite(item.carrier_pressure) or item.carrier_pressure<0 or item.carrier_pressure>10 or item.carrier_pressure~=math.floor(item.carrier_pressure)) then return nil,"invalid_carrier_pressure" end
  if item.ready_at~=nil and not V.finite(item.ready_at) then return nil,"invalid_ready_time" end
  if item.next_wave_at~=nil and not V.finite(item.next_wave_at) then return nil,"invalid_wave_time" end
  for _,key in ipairs({"vehicle_health_ratio","vehicle_usefulness"}) do
   if item[key]~=nil and (not V.finite(item[key]) or item[key]<0 or item[key]>1) then return nil,"invalid_vehicle_value:"..key end
  end
  for _,key in ipairs({"capture_remaining","capture_ends_at","capture_started_at","capture_total_duration"}) do
   if item[key]~=nil and (not V.finite(item[key]) or (key=="capture_remaining" or key=="capture_total_duration") and item[key]<0) then
    return nil,"invalid_capture_time:"..key
   end
  end
 end
 for _,key in ipairs({"team","owner","previous_owner"}) do
  if item[key]~=nil and item[key]~=0 and item[key]~=1 and item[key]~=2 then return nil,"invalid_team:"..key end
 end
 return true
end
function V.normalize(s)
 if type(s)~="table" then return nil,"objective_provider_invalid" end
 if s.objective_source~=nil and s.objective_source~="live_objective_reader" and
  s.objective_source~="team_formation_fallback" and s.objective_source~="static_objective_fallback" then
  return nil,"invalid_objective_source"
 end
 local ok,why=fields(s,true);if not ok then return nil,why end
 for _,key in ipairs({"team_score","enemy_score","score_limit"}) do
  if s[key]~=nil and (not V.finite(s[key]) or s[key]<0) then return nil,"invalid_score:"..key end
 end
 if s.carrier_speed_cap~=nil and (not V.finite(s.carrier_speed_cap) or s.carrier_speed_cap<=0 or s.carrier_speed_cap>1) then
  return nil,"invalid_carrier_speed_cap"
 end
 for _,key in ipairs({"friendly_respawn_wave_at","match_ends_at"}) do
  if s[key]~=nil and not V.finite(s[key]) then return nil,"invalid_match_time:"..key end
 end
 if s.score_limit~=nil and s.score_limit<=0 then return nil,"invalid_score_limit" end
 if s.damage_style~=nil and s.damage_style~="melee" and s.damage_style~="ranged" and s.damage_style~="unknown" then
  return nil,"invalid_damage_style"
 end
 local out={};for key,value in pairs(s) do out[key]=value end
 out.player_position=V.position(s.player_position)
 if not out.player_position then return nil,"player_position_invalid" end
 for _,key in ipairs({"carry_destination","safe_position","orb_scoring_position","friendly_group_position","friendly_flag_carrier_position","friendly_orb_carrier_position","healer_position","callout_position"}) do
  if s[key]~=nil then out[key]=V.position(s[key]);if not out[key] then return nil,"carrier_position_invalid" end end
 end
 for _,group in ipairs(groups) do
  if s[group]~=nil then
   if type(s[group])~="table" then return nil,"invalid_objective_group:"..group end
   local list={};local count=0
   for index,item in pairs(s[group]) do
    if type(index)~="number" or index<1 or index~=math.floor(index) or index>512 or type(item)~="table" then return nil,"invalid_objective_entry:"..group end
    count=count+1;local row={};for key,value in pairs(item) do row[key]=value end
    ok,why=fields(row,false);if not ok then return nil,why end
    for _,key in ipairs({"velocity_x","velocity_y"}) do
     if row[key]~=nil and (not V.finite(row[key]) or math.abs(row[key])>20) then return nil,"invalid_velocity:"..key end
    end
    if row.health_ratio~=nil and (not V.finite(row.health_ratio) or row.health_ratio<0 or row.health_ratio>1) then return nil,"invalid_health_ratio" end
    if row.confidence~=nil and (not V.finite(row.confidence) or row.confidence<0 or row.confidence>1) then return nil,"invalid_confidence" end
    if row.samples~=nil and (not V.finite(row.samples) or row.samples<0 or row.samples~=math.floor(row.samples)) then return nil,"invalid_samples" end
    if row.observed_at~=nil and not V.finite(row.observed_at) then return nil,"invalid_row_time" end
    if row.friendly_attackers~=nil and (not V.finite(row.friendly_attackers) or row.friendly_attackers<0 or row.friendly_attackers~=math.floor(row.friendly_attackers)) then return nil,"invalid_friendly_attackers" end
    if item.position~=nil then row.position=V.position(item.position);if not row.position then return nil,"objective_position_invalid" end end
    list[index]=row
   end
   for index=1,count do if list[index]==nil then return nil,"sparse_objective_group:"..group end end
   out[group]=list
  end
 end
 return out
end
return V
