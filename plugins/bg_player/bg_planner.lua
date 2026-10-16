-- Pure objective policy. Positions and ownership must come from current match data.
local P={}
local Rules=require("bg_rules")
local Predictive=require("bg_predictive_logic")
local anchored={advance=true,regroup=true,retreat=true,guard=true,defend=true,recapture=true,hold_capture=true,occupy=true,capture=true,respond_callout=true,mine_resource=true,
 prepare_resource=true,escort=true,escort_cart=true,return_flag=true,take_flag=true,take_orb=true,take_crystal=true}
local function distance(a,b)
 if not a or not b then return math.huge end
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
P.distance=distance
local function escort_radius(s)
 if s.player_role=="healer" then return 20 end
 if s.player_role=="damage" and s.damage_style=="ranged" then return 18 end
 return 8
end
local function anchor_viable(s,pos)
 if not pos then return false end
 local friends,enemies=0,0
 for _,friend in ipairs(s.friendly_positions or {}) do
  local p=friend.position or friend;if p and distance(p,pos)<=25 then friends=friends+1 end
 end
 for _,enemy in ipairs(s.enemies or {}) do
  local p=enemy.position or enemy
  if enemy.dead~=true and enemy.reachable~=false and p and distance(p,pos)<=25 then enemies=enemies+1 end
 end
 return enemies<friends+2
end
function P.choose(s,previous)
 if not s or not s.valid or not s.player_position then return nil,"objective_state_unavailable" end
 local reason;s,reason=Rules.resolve(s)
 if not s then return nil,reason end
 local best,score,best_priority,best_key
 local committed,committed_score,committed_priority
 local role_bias={
  healer={escort=45,escort_cart=40,defend=35,hold_capture=35,guard=15,intercept=-10,take_flag=-55,take_orb=-55,take_crystal=-40,fight=-15},
  tank={advance=25,regroup=20,guard=60,defend=45,hold_capture=35,return_flag=30,take_flag=50,take_orb=45,take_crystal=40,capture=20,occupy=20,escort=15},
  damage={advance=35,regroup=20,capture=30,occupy=30,recapture=30,intercept=35,fight=35,mine_resource=25,prepare_resource=15,return_flag=20,escort=10,guard=-20}
 }
 -- Folded maps (Alterac, Deephaul, Isle) make straight-line distance a poor
 -- proxy for travel time. Beyond 60 yards use the authored-graph distance the
 -- route layer already computes, capped at 2x so one long detour cannot
 -- overwhelm objective urgency. Falls back to straight-line when unavailable.
 local function travel(pos)
  local straight=distance(s.player_position,pos)
  if type(s.travel_distance)=="function" and straight>60 and straight<math.huge then
   local ok,routed=pcall(s.travel_distance,pos)
   if ok and type(routed)=="number" and routed==routed and routed>=straight then return math.min(routed,straight*2) end
  end
  return straight
 end
 local function offer(kind,pos,value,object,target,id,allow_npc,required_action)
  if not pos then return end
  local bias=role_bias[s.player_role] and role_bias[s.player_role][kind] or 0
  local route_distance=travel(pos)
  local weight=value+bias-route_distance*0.15
  local flow_bonus=Predictive.team_flow(s,pos)
  weight=weight+flow_bonus+Predictive.congestion_modifier(s,pos)+Predictive.respawn_modifier(s,kind)
  local aggressive=kind=="capture" or kind=="occupy" or kind=="advance" or kind=="fight" or
   kind=="take_flag" or kind=="take_orb" or kind=="take_crystal" or kind=="mine_resource" or kind=="siege_gate"
  if aggressive and type(s.aggression_modifier)=="number" then
   weight=weight+math.max(-30,math.min(20,s.aggression_modifier))
  end
  -- Only validated provider wave data can alter graveyard approach behavior.
  -- A wave that is about to spawn penalizes routine aggression near that enemy
  -- graveyard; defense and carrier return remain untouched.
  if aggressive and type(s.observed_at)=="number" then
   for _,yard in ipairs(s.graveyards or {}) do
    local remaining=type(yard.next_wave_at)=="number" and yard.next_wave_at-s.observed_at or nil
    if yard.position and yard.owner~=s.team and remaining and remaining>=0 and remaining<=10 and distance(pos,yard.position)<=55 then
     weight=weight-55;break
    end
   end
  end
  if s.endgame_mode=="all_in" then
   if kind=="capture" or kind=="occupy" or kind=="recapture" or kind=="intercept" or kind=="fight" then weight=weight+35 end
   if type(s.enemy_win_eta)=="number" and route_distance/5>s.enemy_win_eta then weight=weight-50 end
  elseif s.endgame_mode=="protect_lead" then
   if kind=="defend" or kind=="guard" or kind=="escort" or kind=="hold_capture" then weight=weight+30 end
   if kind=="capture" or kind=="advance" then weight=weight-15 end
  end
  -- Prefer fights where our arrival can reinforce teammates and avoid routine
  -- dives into a heavily outnumbered cluster. Counts are local observations,
  -- bounded so objective urgency always remains more important. Carrier
  -- interception and flag return keep their explicit priority below.
  if kind=="fight" or kind=="intercept" or kind=="defend" then
   local outlook,outlook_score=Predictive.fight_outlook(s,pos)
   -- Existing deficit and low-health gates already bound unsafe engagements.
   -- Add only corroborated advantage here so the predictor cannot double-count
   -- a temporary enemy cluster and suppress an otherwise actionable target.
   if outlook=="advantage" then weight=weight+math.min(20,outlook_score) end
   local allies,enemies=0,0
   for _,friend in ipairs(s.friendly_positions or {}) do
    local p=friend.position or friend
    if p and distance(p,pos)<=30 then allies=allies+1 end
   end
   for _,enemy in ipairs(s.enemies or {}) do
    local p=enemy.position or enemy
    if enemy.dead~=true and p and distance(p,pos)<=30 then enemies=enemies+1 end
   end
   local support=math.min(4,allies)*7
   local deficit=math.max(0,enemies-allies-1)
   local continuing=previous and previous.kind==kind and id~=nil and previous.id==id
   -- Do not begin an optional suicide chase while already hurt. Ongoing fights
   -- are retained to avoid target thrashing; carrier interception, confirmed
   -- defense and deathmatch remain governed by their dedicated policies.
   if kind=="fight" and s.kind~="deathmatch" and not continuing and
    type(s.player_health_ratio)=="number" and s.player_health_ratio<=0.35 and
    enemies>=allies+2 then return end
   weight=weight+support-math.min(42,deficit*12)
  end
  if s.match_pressure=="enemy_closing" and (kind=="capture" or kind=="occupy" or kind=="recapture" or kind=="defend" or kind=="intercept" or kind=="fight") then
   weight=weight+18
  elseif s.match_pressure=="team_closing" and (kind=="defend" or kind=="guard" or kind=="escort" or kind=="hold_capture") then
   weight=weight+14
  end
  -- Live capture timers can promote a defense before it is lost. An objective
  -- that cannot be reached before its deadline receives no speculative bonus.
  local flow_row
  for _,group in ipairs({s.nodes or {},s.objectives or {},s.flags or {}}) do
   for _,row in ipairs(group) do if id~=nil and row.id==id then flow_row=row;break end end
   if flow_row then break end
  end
  if flow_row and flow_row.arrival_feasible~=false then
   if flow_row.predicted_urgency=="critical" then weight=weight+40
   elseif flow_row.predicted_urgency=="high" then weight=weight+20 end
  end
  if flow_row then weight=weight+Predictive.objective_confidence(flow_row,tonumber(s.observed_at) or 0) end
  if kind=="defend" or kind=="guard" or kind=="recapture" then weight=weight+Predictive.incoming_pressure(s,pos) end
  if kind=="fight" or kind=="intercept" then
   for _,enemy in ipairs(s.enemies or {}) do if id~=nil and enemy.id==id then weight=weight+Predictive.focus_fire(enemy);break end end
  end
  if flow_row and Predictive.objective_handoff(s,flow_row,pos) and
   kind~="defend" and kind~="recapture" and kind~="return_flag" then weight=weight-45 end
  local defensive=kind=="return_flag" or kind=="defend" or kind=="recapture"
  local feasible=not flow_row or flow_row.arrival_feasible~=false
  if defensive and not feasible then weight=weight-60 end
  -- Only a currently offered objective may receive commitment preference.
  -- Urgent return/defense work always outranks routine travel and guarding.
  local priority=defensive and feasible and 1 or 0
  local same_objective=previous and id~=nil and previous.kind==kind and previous.id==id
  if same_objective then weight=weight+12 end
  local key=Predictive.objective_key(kind,id,pos)
  weight=weight+Predictive.oscillation_penalty(s.objective_history,key,tonumber(s.observed_at) or 0)
  if not score or priority>best_priority or priority==best_priority and
   (weight>score or weight==score and key<best_key) then
   best_priority=priority;best_key=key
   local engagement=anchored[kind] and (s.player_role=="damage" and s.damage_style=="ranged" and 28 or 10) or 35
   score=weight;best={kind=kind,position=pos,object=object,target=target,id=id,
    allow_npc=allow_npc,required_action=required_action,combat_anchor=anchored[kind]==true,
    arrival_eta=flow_row and flow_row.arrival_eta or nil,capture_remaining=flow_row and flow_row.capture_remaining or nil,
    match_pressure=s.match_pressure,
    engagement_radius=engagement,
    interaction_radius=object and 5 or nil}
   if kind=="escort" then best.arrival_radius=escort_radius(s);best.escort_spacing=true end
   if same_objective then committed,committed_score,committed_priority=best,weight,priority end
   return best
  end
  if same_objective then
   committed={kind=kind,position=pos,object=object,target=target,id=id,
    allow_npc=allow_npc,required_action=required_action,combat_anchor=anchored[kind]==true,
    engagement_radius=anchored[kind] and (s.player_role=="damage" and s.damage_style=="ranged" and 28 or 10) or 35,
    interaction_radius=object and 5 or nil}
   if kind=="escort" then committed.arrival_radius=escort_radius(s);committed.escort_spacing=true end
   committed_score,committed_priority=weight,priority
  end
 end
 if s.carrying then
  -- Never send a carrier into an unrelated fight or mount it.
  local pos=s.carry_destination
  if s.kind=="ctf" and s.own_flag_home~=true then pos=s.safe_position end
  if s.carry_destination_valid==false then pos=s.safe_position end
  if s.kind=="hybrid" then
   local valid=s.has_owned_node==true
   if s.carry_destination_node_id then
    valid=false
    for _,node in ipairs(s.nodes or {}) do
     if node.id==s.carry_destination_node_id and node.owner==s.team and node.active~=false and
      node.reachable~=false and not node.destroyed and
      node.state~="friendly_contested" and node.state~="enemy_contested" then valid=true;break end
    end
   end
   if not valid then pos=s.safe_position end
  elseif s.kind=="orbs" then
   local nearby_friends,nearby_enemies=0,0
   for _,friend in ipairs(s.friendly_positions or {}) do
    local p=friend.position or friend;if p and distance(s.player_position,p)<=30 then nearby_friends=nearby_friends+1 end
   end
   for _,enemy in ipairs(s.enemies or {}) do
    local p=enemy.position or enemy
    if enemy.dead~=true and p and distance(s.player_position,p)<=30 then nearby_enemies=nearby_enemies+1 end
   end
   -- An orb scores fastest in the center, but its holder takes increasing
   -- damage and reduced healing. Retreat only on a clear local disadvantage;
   -- the two-player margin prevents one transient object-list change from
   -- flipping the route every update.
   local outnumbered=nearby_enemies>=2 and nearby_enemies>nearby_friends+1
   if (s.carrier_in_danger or outnumbered) and s.safe_position then pos=s.safe_position
   elseif s.orb_scoring_position then pos=s.orb_scoring_position end
  end
  if not pos then return nil,"carrier_destination_unavailable" end
  local route=s.carry_route
  local threatened=0
  if type(route)=="table" and route.escape_priority~=true then
   for _,enemy in ipairs(s.enemies or {}) do
    local ep=enemy.position or enemy;local intersects=false
    if enemy.dead~=true and enemy.reachable~=false and ep then
     for _,waypoint in ipairs(route) do if distance(ep,waypoint)<=18 then intersects=true;break end end
    end
    if intersects then threatened=threatened+1 end
   end
  end
  local tolerance=s.player_role=="tank" and 4 or s.player_role=="damage" and s.damage_style=="melee" and 3 or 2
  local dynamic=threatened>=tolerance
  local selected_route=route;if dynamic then selected_route=nil end
  return {kind="carry",position=pos,id="carry",route=selected_route,
   carrier_threat_reroute=dynamic or nil,carrier_route_threat=threatened}
 end
 if (s.player_role=="damage" or s.player_role=="tank") and s.callout_position then
  local route_distance=travel(s.callout_position)
  local remaining=type(s.callout_expires_at)=="number" and type(s.observed_at)=="number" and
   s.callout_expires_at-s.observed_at or nil
  local speed=s.mounted and 10 or 5
  local arrival_eta=route_distance/speed
  local enemy_verified=false
  for _,enemy in ipairs(s.enemies or {}) do
   local p=enemy.position or enemy
   if enemy.dead~=true and enemy.reachable~=false and p and distance(p,s.callout_position)<=35 then
    enemy_verified=true;break
   end
  end
  local arrived=distance(s.player_position,s.callout_position)<=12
  -- Defensive calls describe a fight, so reaching a quiet location completes
  -- them early. Offensive push/capture calls remain useful even when clear.
  local locally_relevant=s.callout_intent~="defense" or not arrived or enemy_verified
  -- A chat call that will expire before arrival must not override productive
  -- live objectives. A small grace period absorbs normal travel variance.
  if locally_relevant and (not remaining or remaining>0 and arrival_eta<=remaining+3) then
   -- Treat chat as a strong tactical candidate instead of an unconditional
   -- command. This lets a nearby request beat routine travel while verified
   -- emergencies such as a dropped friendly flag or active enemy capture keep
   -- ownership of the player. Reported enemy count raises urgency, but is
   -- bounded because chat is less authoritative than live objective state.
   local reported=type(s.callout_enemy_count)=="number" and math.max(1,math.min(8,s.callout_enemy_count)) or 1
   local confirmed=type(s.callout_confirmations)=="number" and math.max(1,math.min(4,s.callout_confirmations)) or 1
   local candidate=offer("respond_callout",s.callout_position,125+reported*6+(confirmed-1)*8,nil,nil,
    "chat_"..tostring(s.callout_id or "objective"))
   if candidate then
    candidate.arrival_radius=8;candidate.engagement_radius=20
    candidate.arrival_eta=arrival_eta;candidate.callout_remaining=remaining
    candidate.enemy_count=s.callout_enemy_count;candidate.callout_intent=s.callout_intent
    candidate.callout_confirmations=confirmed
   end
  end
 end
 -- When the objective API is missing, live nearby enemies are still verified.
 -- DPS and tanks join that fight instead of following a synthetic moving cart.
 if s.formation_fallback and (s.player_role=="damage" or s.player_role=="tank") then
  for _,enemy in ipairs(s.enemies or {}) do
   if enemy.reachable~=false and enemy.position and distance(s.player_position,enemy.position)<=65 then
    offer("fight",enemy.position,145,nil,enemy.target,enemy.id)
   end
  end
 end
 -- After resurrection, DPS and tanks rejoin a viable friendly formation before
 -- taking routine solo work. A collapsing cluster is rejected in favor of a
 -- safe friendly node. Because this is offered through normal scoring, urgent
 -- flag returns, recaptures and verified defense still override it.
 if s.post_resurrection and (s.player_role=="damage" or s.player_role=="tank") and not s.carrying then
  local join=s.friendly_group_position
  if join then
   local friends,enemies=0,0
   for _,friend in ipairs(s.friendly_positions or {}) do
    local p=friend.position or friend;if p and distance(p,join)<=30 then friends=friends+1 end
   end
   for _,enemy in ipairs(s.enemies or {}) do
    local p=enemy.position or enemy
    if enemy.dead~=true and enemy.reachable~=false and p and distance(p,join)<=30 then enemies=enemies+1 end
   end
   if enemies>=friends+3 then join=nil end
  end
  if not join then
   local best_distance
   for _,node in ipairs(s.nodes or {}) do
    if node.owner==s.team and node.active~=false and node.reachable~=false and not node.destroyed and
     not node.threatened and not node.enemy_capture_in_progress and node.position then
     local d=distance(s.player_position,node.position)
     if not best_distance or d<best_distance then join,best_distance=node.position,d end
    end
   end
  end
  join=join or s.safe_position
  if join then
   local candidate=offer("regroup",join,190,nil,nil,"post_resurrection_rejoin")
   if candidate then candidate.arrival_radius=15;candidate.engagement_radius=25;candidate.post_resurrection=true end
  end
 end
 if s.player_role=="healer" then
  local retreating=previous and previous.kind=="retreat" and
   type(s.player_health_ratio)=="number" and s.player_health_ratio<0.40
  local critical=type(s.player_health_ratio)=="number" and s.player_health_ratio<=0.25
  if critical or retreating then
   local allies,enemies=0,0
   for _,friend in ipairs(s.friendly_positions or {}) do
    local p=friend.position or friend;if p and distance(s.player_position,p)<=30 then allies=allies+1 end
   end
   for _,enemy in ipairs(s.enemies or {}) do
    local p=enemy.position or enemy
    if enemy.dead~=true and enemy.reachable~=false and p and distance(s.player_position,p)<=30 then enemies=enemies+1 end
   end
   if retreating or enemies>=allies+2 then
    local safe,id,best_distance
    for _,node in ipairs(s.nodes or {}) do
     if node.owner==s.team and node.active~=false and node.reachable~=false and
      not node.destroyed and not node.threatened and not node.enemy_capture_in_progress and node.position then
      local d=distance(s.player_position,node.position)
      if not best_distance or d<best_distance then safe,id,best_distance=node.position,node.id,d end
     end
    end
    safe=safe or s.safe_position
    if safe then
     return {kind="retreat",position=safe,id="healer_safe_"..tostring(id or "fallback"),
      combat_anchor=true,engagement_radius=15,arrival_radius=10}
    end
   end
  end
  -- Low mana must not make a healer abandon a verified match-saving event.
  -- Personal critical-health retreat above remains first; after that, support
  -- a pressured friendly carrier or an owned base actively being captured.
  for _,flag in ipairs(s.flags or {}) do
   if flag.carrier and not flag.carrier_enemy and flag.position and flag.reachable~=false and
    type(flag.carrier_pressure)=="number" and flag.carrier_pressure>=2 then
    return {kind="escort",position=flag.position,id="emergency_carrier_"..tostring(flag.id or "flag"),
     combat_anchor=true,engagement_radius=40,arrival_radius=18,healer_emergency=true,escort_spacing=true}
   end
  end
  for _,node in ipairs(s.nodes or {}) do
   if node.owner==s.team and node.enemy_capture_in_progress==true and node.position and node.reachable~=false then
    return {kind="defend",position=node.position,id="emergency_base_"..tostring(node.id or "node"),
     target=node.assaulting_enemy or node.enemy,combat_anchor=true,engagement_radius=40,arrival_radius=12,
     healer_emergency=true}
   end
  end
  local mana_recovering=previous and previous.kind=="regroup" and previous.id=="healer_mana_recover" and
   type(s.player_mana_ratio)=="number" and s.player_mana_ratio<0.35
  local mana_depleted=type(s.player_mana_ratio)=="number" and s.player_mana_ratio<=0.15
  if mana_depleted or mana_recovering then
   local safe=anchor_viable(s,s.healer_position) and s.healer_position or nil
   if not safe then
    local best_distance
    for _,node in ipairs(s.nodes or {}) do
     if node.owner==s.team and node.active~=false and node.reachable~=false and not node.destroyed and
      not node.threatened and not node.enemy_capture_in_progress and node.position then
      local d=distance(s.player_position,node.position)
      if not best_distance or d<best_distance then safe,best_distance=node.position,d end
     end
    end
   end
   safe=safe or s.safe_position or s.friendly_group_position
   if safe then
    return {kind="regroup",position=safe,id="healer_mana_recover",combat_anchor=true,
     engagement_radius=30,arrival_radius=18,mana_recovery=true}
   end
  end
  local verified_backline=anchor_viable(s,s.healer_position) and s.healer_position or nil
  local support=verified_backline or s.friendly_flag_carrier_position or s.friendly_group_position
  if support then
   local carrier=s.friendly_flag_carrier_position~=nil
   local plan={kind="escort",position=support,id=carrier and "friendly_flag_carrier" or "friendly_group",
    combat_anchor=true,engagement_radius=40,arrival_radius=carrier and 20 or 12,escort_spacing=carrier or nil}
   -- Generic formation snapshots must use the battleground graph and Sentinel
   -- pathfinding. Directly chasing a moving teammate cuts corners into scenery
   -- and causes a new raw movement command every time that teammate shifts.
   if s.formation_fallback then
    -- Healers already inside normal support range should hold their ground.
    -- This prevents tiny moving-anchor paths from repeatedly entering the
    -- path server's awaiting state while the group shifts during combat.
    -- Stay comfortably inside normal healing range. A 35-yard edge hold leaves
    -- almost no allowance for cluster width, movement, or line-of-sight turns.
    plan.arrival_radius=25
   end
   -- The controller supplies the authored map graph for distant support.
   -- A raw moving teammate point is never an authored corridor.
   return plan
  end
  if s.safe_position then
   return {kind="guard",position=s.safe_position,id="friendly_flag_room",route=s.carry_route,
    combat_anchor=true,engagement_radius=40,arrival_radius=12}
  end
  return nil,"friendly_group_unavailable"
 end
 -- A damage dealer or tank should disengage when an ordinary skirmish has
 -- collapsed around it. This remains a scored candidate, so flag returns,
 -- live base defense and other priority-one work can still override it.
 if s.player_role=="damage" or s.player_role=="tank" then
  local allies,enemies=0,0
  for _,friend in ipairs(s.friendly_positions or {}) do
   local p=friend.position or friend
   if p and distance(s.player_position,p)<=30 then allies=allies+1 end
  end
  for _,enemy in ipairs(s.enemies or {}) do
   local p=enemy.position or enemy
   if enemy.dead~=true and enemy.reachable~=false and p and distance(s.player_position,p)<=30 then enemies=enemies+1 end
  end
  local recovering=previous and previous.kind=="regroup" and previous.id=="tactical_disengage" and
   type(s.player_health_ratio)=="number" and s.player_health_ratio<0.60 and enemies>=allies+2
  local collapsing=previous and previous.kind=="fight" and type(s.player_health_ratio)=="number" and
   s.player_health_ratio<=0.35 and enemies>=allies+3
  if recovering or collapsing then
   local safe,best_distance
   for _,node in ipairs(s.nodes or {}) do
    if node.owner==s.team and node.active~=false and node.reachable~=false and not node.destroyed and
     not node.threatened and not node.enemy_capture_in_progress and node.position then
     local d=distance(s.player_position,node.position)
     if not best_distance or d<best_distance then safe,best_distance=node.position,d end
    end
   end
   safe=safe or s.safe_position or s.friendly_group_position
   if safe then
    local candidate=offer("regroup",safe,180,nil,nil,"tactical_disengage")
    if candidate then candidate.arrival_radius=10;candidate.engagement_radius=15;candidate.tactical_disengage=true end
   end
  end
 end
 if s.kind=="ctf" or s.kind=="legacy_cart_bases" then
  if s.kind=="ctf" and s.player_role=="damage" then
   for _,enemy in ipairs(s.enemies or {}) do
    if enemy.reachable~=false and enemy.position and distance(s.player_position,enemy.position)<=70 then
     offer("fight",enemy.position,145,nil,enemy.target,enemy.id)
    end
   end
  end
  for _,flag in ipairs(s.flags or {}) do
   if flag.reachable~=false then
   if flag.team==s.team then
    if flag.dropped and flag.pickup_allowed~=false then offer("return_flag",flag.position,160,flag.object,nil,flag.id)
    elseif flag.carrier and flag.carrier_enemy then offer("intercept",Predictive.intercept_position(flag,s.player_position),150+math.min(60,(flag.carrier_pressure or 0)*8),nil,flag.carrier,flag.id) end
   elseif flag.available and flag.pickup_allowed~=false and not (s.kind=="ctf" and s.player_role=="damage") then
    local candidate=offer("take_flag",flag.position,95,flag.object,nil,flag.id)
    if candidate then candidate.route=flag.approach_route end
   elseif flag.carrier and not flag.carrier_enemy then
    -- Once the team has the flag, a tank's durable objective job is to escort
    -- it rather than start a second unsupported flag run. Live pressure still
    -- raises escort urgency for every role.
    local tank_bodyguard=s.player_role=="tank" and 45 or 0
    offer("escort",flag.position,110+tank_bodyguard+math.min(50,(flag.carrier_pressure or 0)*7),nil,nil,flag.id)
   end
   end
  end
  if s.kind=="ctf" and s.player_role=="damage" and s.friendly_group_position then
   offer("fight",s.friendly_group_position,70,nil,nil,"friendly_frontline")
  end
 end
 if s.kind=="bases" or s.kind=="hybrid" or s.kind=="legacy_cart_bases" or s.kind=="reinforcements" then
  local active_nodes,owned_nodes=0,0
  local blocked_assault=false
  local regroup_position,regroup_id,regroup_distance
  local chain_completed=false
  for _,node in ipairs(s.nodes or {}) do
   if node.active~=false and not node.destroyed then
    active_nodes=active_nodes+1;if node.owner==s.team then owned_nodes=owned_nodes+1 end
    if node.owner==s.team and node.position and (node.defenders or 0)>0 then
     local d=distance(s.player_position,node.position)
     if not regroup_distance or d<regroup_distance then
      regroup_position,regroup_id,regroup_distance=node.position,node.id,d
     end
    end
   end
  end
  if previous and previous.id~=nil and
   (previous.kind=="capture" or previous.kind=="occupy" or previous.kind=="recapture" or previous.kind=="hold_capture") then
   for _,node in ipairs(s.nodes or {}) do
    if node.id==previous.id and node.owner==s.team and node.position and node.active~=false and
     not node.destroyed and not node.threatened and not node.enemy_capture_in_progress and
     distance(s.player_position,node.position)<=40 then chain_completed=true;break end
   end
  end
  local defend_majority=s.kind=="bases" and s.mode~="blitz" and active_nodes>=3 and
   owned_nodes>=math.floor(active_nodes/2)+1
  for _,n in ipairs(s.nodes or {}) do
   if n.active~=false and n.reachable~=false and not n.destroyed then
   if n.fallback_advance==true then
    local candidate=offer("advance",n.position,90,nil,nil,n.id)
    if candidate then candidate.arrival_radius=8 end
   -- Locked Blitz nodes must never be treated as capturable.
   elseif n.owner==s.team and n.enemy_capture_in_progress==true then
    offer("defend",n.position,175,nil,n.assaulting_enemy or n.enemy,n.id)
   elseif n.state=="enemy_contested" and n.previous_owner==s.team and n.capturable and not n.locked then
    offer("recapture",n.position,155,n.object,n.enemy,n.id)
   elseif n.state=="friendly_contested" then
    offer("hold_capture",n.position,115,nil,n.enemy,n.id)
   elseif n.owner==s.team and n.threatened then
    -- Reinforce the owned base with the worst observed local balance. Missing
    -- counts preserve the original score; bounded bonuses prevent noisy object
    -- lists from overriding a confirmed capture-in-progress emergency.
    local attackers=type(n.enemies)=="number" and math.max(0,n.enemies) or nil
    local defenders=type(n.defenders)=="number" and math.max(0,n.defenders) or nil
    local danger=0
    if attackers and defenders then
     danger=math.min(45,math.max(0,attackers-defenders)*15)-math.min(20,math.max(0,defenders-attackers)*5)
    end
    offer("defend",n.position,140+danger,nil,n.enemy,n.id)
   elseif n.capturable and not n.locked and n.owner~=s.team then
    local nearby=n.proximity==true
    local clear=n.enemies==nil or n.enemies==0
    local friends=0
    for _,friend in ipairs(s.friendly_positions or {}) do
     local p=friend.position or friend;if p and distance(p,n.position)<=30 then friends=friends+1 end
    end
    local observed_enemies=0
    for _,enemy in ipairs(s.enemies or {}) do
     local p=enemy.position or enemy
     if enemy.dead~=true and enemy.reachable~=false and p and distance(p,n.position)<=30 then observed_enemies=observed_enemies+1 end
    end
    local enemies=math.max(type(n.enemies)=="number" and n.enemies or 0,observed_enemies)
    local continuing=previous and (previous.kind=="capture" or previous.kind=="occupy") and previous.id==n.id
    local overmatched=enemies>=friends+2
    -- Avoid piling more players onto a clear, distant assault that already has
    -- a large friendly advantage. This encourages useful map coverage without
    -- pulling a player away after it has committed or entered the capture area.
    local saturation=not nearby and not continuing and math.max(0,friends-enemies-2) or 0
    local saturation_penalty=math.min(45,saturation*12)
    local handoff_bonus=0
    if chain_completed and not continuing then
     local leg=travel(n.position)
     if leg<=180 then handoff_bonus=math.max(10,35-leg*0.10) end
    end
    if overmatched and not continuing and s.endgame_mode~="all_in" then blocked_assault=true end
    -- Reaching a capture circle must not discard its clickable flag. When the
    -- local ownership feed reports the area clear, claim it immediately;
    -- visible enemies still own combat before the controller can interact.
    -- Do not initiate a routine assault into a clearly superior defense.
    -- Existing captures and match-saving all-in pushes retain commitment.
    if not overmatched or continuing or s.endgame_mode=="all_in" then
     local candidate=offer(nearby and "occupy" or "capture",n.position,
      (nearby and clear and 145 or defend_majority and 55 or 90)-(n.enemies or 0)*12-saturation_penalty+handoff_bonus,
      clear and n.object or nil,nil,n.id)
     if candidate and handoff_bonus>0 then candidate.objective_handoff=true;candidate.handoff_bonus=handoff_bonus end
    end
   elseif n.owner==s.team and (n.defenders or 0)==0 then
    offer("guard",n.position,defend_majority and 135 or 60,nil,nil,n.id)
   end
   end
  end
  if blocked_assault and not best then
   -- When every useful assault is gated, assemble at a defended friendly node.
   -- If none exists, use a live friendly formation only when that formation is
   -- not itself outnumbered. This avoids replacing one suicide route with
   -- another and gives the next snapshot a chance to observe a viable push.
   if not regroup_position and s.friendly_group_position then
    local friends,enemies=0,0
    for _,friend in ipairs(s.friendly_positions or {}) do
     local p=friend.position or friend;if p and distance(p,s.friendly_group_position)<=30 then friends=friends+1 end
    end
    for _,enemy in ipairs(s.enemies or {}) do
     local p=enemy.position or enemy
     if enemy.dead~=true and enemy.reachable~=false and p and distance(p,s.friendly_group_position)<=30 then enemies=enemies+1 end
    end
    if enemies<=friends+1 then regroup_position,regroup_id=s.friendly_group_position,"friendly_formation" end
   end
   if regroup_position then
    local candidate=offer("regroup",regroup_position,80,nil,nil,"regroup_"..tostring(regroup_id or "team"))
    if candidate then candidate.arrival_radius=15;candidate.engagement_radius=25 end
   end
  end
  if s.kind=="hybrid" then
   local owned_nodes=0
   for _,node in ipairs(s.nodes or {}) do
    if node.owner==s.team and node.active~=false and not node.destroyed then owned_nodes=owned_nodes+1 end
   end
   for _,flag in ipairs(s.flags or {}) do
    if flag.reachable~=false then
    -- EOTS rewards a flag only at an owned tower, and Blizzard's strategy
    -- guidance gives tower control priority when the team holds just one.
    -- Keep the flag legal in that state, but score an open tower above it.
    if s.has_owned_node and flag.available and flag.pickup_allowed~=false then
     offer("take_flag",flag.position,owned_nodes<=1 and 55 or 100,flag.object,nil,flag.id)
   elseif flag.carrier_enemy then offer("intercept",Predictive.intercept_position(flag,s.player_position),120,nil,flag.carrier,flag.id)
    elseif flag.carrier then offer("escort",flag.position,95,nil,nil,flag.id) end
    end
   end
  end
 end
 if s.kind=="orbs" then
  for _,orb in ipairs(s.orbs or {}) do
   if orb.reachable~=false then
   if orb.available and orb.pickup_allowed~=false then offer("take_orb",orb.position,110,orb.object,nil,orb.id)
   elseif orb.carrier_enemy then offer("intercept",Predictive.intercept_position(orb,s.player_position),100,nil,orb.carrier,orb.id)
   elseif orb.carrier then offer("escort",orb.position,65,nil,nil,orb.id) end
   end
  end
 elseif s.kind=="carts" or s.kind=="cart_crystal" then
  for _,cart in ipairs(s.carts or {}) do
   if not cart.delivered and cart.active~=false and cart.reachable~=false then
    local value=85+(cart.contested and 30 or 0)+(cart.near_depot and 20 or 0)
    -- A depot arrival grants a large score bonus. Intercept an enemy cart that
    -- is about to score, and reinforce a friendly scoring cart, before choosing
    -- an otherwise equivalent cart farther from completion.
    if cart.near_depot and cart.owner~=nil then
     value=value+(cart.owner==s.team and 25 or 50)
    end
    -- Counts exclude this player: a tied circle can be won by joining it.
    local friends,enemies=cart.friendly_count,cart.enemy_count
    if type(friends)=="number" and type(enemies)=="number" and friends>=0 and enemies>=0 and
     friends==math.floor(friends) and enemies==math.floor(enemies) then
     if friends==enemies then value=value+35
     elseif friends>enemies and cart.owner==s.team then value=value-25 end
    end
    local candidate=offer("escort_cart",cart.position,value,nil,nil,cart.id)
    local radius=cart.control_radius
    if candidate and type(radius)=="number" and radius==radius and radius>0 and radius<100 then
     candidate.arrival_radius=math.min(3,radius*0.5)
     candidate.engagement_radius=math.min(10,radius*0.8)
    end
   end
  end
 end
 if s.kind=="cart_crystal" then
  for _,crystal in ipairs(s.crystals or {}) do
   if crystal.reachable~=false then
   if crystal.available and crystal.pickup_allowed~=false then
    offer("take_crystal",crystal.position,100,crystal.object,nil,crystal.id)
   elseif crystal.carrier_enemy then offer("intercept",Predictive.intercept_position(crystal,s.player_position),120,nil,crystal.carrier,crystal.id)
   elseif crystal.carrier then offer("escort",crystal.position,95,nil,nil,crystal.id) end
   end
  end
 elseif s.kind=="resources" then
  for _,vein in ipairs(s.resources or {}) do
   if vein.active and vein.reachable~=false and not vein.depleted then
    local ready=vein.mineable and (not vein.ready_at or type(s.observed_at)=="number" and s.observed_at>=vein.ready_at)
    offer(ready and "mine_resource" or "prepare_resource",vein.position,
     (ready and 110 or 65)-(vein.enemies or 0)*12,ready and vein.object or nil,nil,vein.id)
   end
  end
 end
 if s.kind=="reinforcements" or s.kind=="siege" or s.kind=="siege_rounds" or s.kind=="frontline" then
  if s.kind=="siege_rounds" and (s.round_role~="attack" and s.round_role~="defend") then
   return nil,"round_role_unavailable"
  end
  local values={defend=150,capture=95,commander=120,relic=160,
   intercept_vehicle=145,escort_siege=100,siege_gate=110,frontline=80}
  for _,o in ipairs(s.objectives or {}) do
   -- Provider verifies prerequisites, current round, access and live ownership.
   local vehicle_usable=not o.requires_vehicle or not o.vehicle_stalled and
    (type(o.vehicle_health_ratio)~="number" or o.vehicle_health_ratio>0.15) and
    (type(o.vehicle_usefulness)~="number" or o.vehicle_usefulness>0)
   if values[o.type] and o.available and o.reachable and not o.completed and vehicle_usable and
    (s.kind~="siege_rounds" or o.round_id==s.round_id and s.round_id~=nil) and
    (not o.role or o.role==s.round_role) then
    local special=o.type=="siege_gate" and "siege_gate" or o.type=="escort_siege" and o.requires_vehicle and "vehicle" or nil
    offer(o.type,o.position,values[o.type],special and nil or o.object,o.target,o.id,
     o.type=="commander" or o.type=="intercept_vehicle",special)
   end
  end
 elseif s.kind=="deathmatch" then
  -- No flag or base objective is invented for a deathmatch brawl.
  for _,enemy in ipairs(s.enemies or {}) do
   if enemy.reachable~=false and enemy.attackable and not enemy.dead then offer("fight",enemy.position,80,nil,enemy.target,enemy.id) end
  end
 end
 -- Keep a still-valid objective unless another objective of the same urgency is
 -- materially better. This prevents small distance/count fluctuations from
 -- rebuilding routes and sending the player back and forth between points.
 if committed and best and committed_priority==best_priority and committed_score+20>=score then best=committed end
 return best,best and nil or "no_verified_objective"
end
return P
