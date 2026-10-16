local Snapshot=require("bg_snapshot")
local Formation=require("bg_formation")
local RouteData=require("bg_route_data")
local Rules=require("bg_rules")
local Theme=require("bg_theme")
local Object=require("bg_object")
local Darkspear=require("bg_darkspear")
local Trinity=require("bg_trinitycore_forever")
local B={}
local kotmogu=Trinity.kotmogu.orbs
local carrier_auras={[121164]=true,[121175]=true,[121176]=true,[121177]=true}
local SILVERSHARD_CART_ENTRY=60140
local SEETHING_AZERITE_ENTRIES={[281306]=true,[281307]=true,[272471]=true}
local warsong_flags={
 [0]={id="horde_flag",entry=227740,position={x=917.3,y=1434.0,z=346.1}},
 [1]={id="alliance_flag",entry=227741,position={x=1540.4,y=1481.2,z=353.6}}
}
-- Live-observed corridors used to keep Sentinel requests on one connected section at a time.
local warsong_routes={
 -- Team 0 (Horde) crosses the field, climbs the verified Alliance exit in
 -- reverse, enters the room and reaches the Alliance flag stand.
 [0]={{x=975.0,y=1436.0,z=345.0},{x=1021.4,y=1411.0,z=341.4},{x=1058.2,y=1375.9,z=328.6},
  {x=1086.6,y=1390.4,z=319.8},{x=1144.8,y=1558.8,z=308.9},{x=1317.1,y=1551.7,z=315.3},
  {x=1395.0,y=1515.0,z=320.0},{x=1445.0,y=1490.0,z=330.0},{x=1492.7,y=1457.8,z=344.9},
  {x=1540.4,y=1481.2,z=353.6}},
 -- Team 1 (Alliance) enters the Horde tunnel through the proven field, ramp,
 -- bend and room points instead of aiming diagonally through the base wall.
 [1]={{x=1492.7,y=1457.8,z=344.9},{x=1445.0,y=1490.0,z=330.0},{x=1395.0,y=1515.0,z=320.0},
  {x=1317.1,y=1551.7,z=315.3},{x=1144.8,y=1558.8,z=308.9},{x=1086.6,y=1390.4,z=319.8},
  {x=1058.2,y=1375.9,z=328.6},{x=1021.4,y=1411.0,z=341.4},
  {x=975.0,y=1436.0,z=345.0},{x=917.3,y=1434.0,z=346.1}}
}
for team,route in pairs(warsong_routes) do
 route.direct=false;route.avoid_mount=true;route.allow_direct_fallback=false
 route.waypoint_radius=8;route.lock_id="warsong_flag_corridor_"..tostring(team)
 route.source="live_warsong_census"
end
local warsong_carrier_auras={[23333]=true,[23335]=true,[34976]=true,[34977]=true}
local darkspear_carrier_auras={[1284560]=true}
local flag_pressure_auras={[46392]=true,[46393]=true}
local function aura_id(a)
 if type(a)~="table" then return nil end
 return tonumber(a.spell_id or a.buff_id or a.debuff_id or a.id)
end
local function carrying(player)
 for _,method in ipairs({"get_auras","get_buffs","get_debuffs","get_all_buffs"}) do
  local ok,list=pcall(function() return type(player[method])=="function" and player[method](player) end)
  if ok and type(list)=="table" then
   for _,aura in pairs(list) do if carrier_auras[aura_id(aura)] then return true end end
  end
 end
 return false
end
local function carrying_warsong_flag(player)
 for _,method in ipairs({"get_auras","get_buffs","get_debuffs","get_all_buffs"}) do
  local ok,list=pcall(function() return type(player[method])=="function" and player[method](player) end)
  if ok and type(list)=="table" then
   for _,aura in pairs(list) do if warsong_carrier_auras[aura_id(aura)] then return true end end
  end
 end
 return false
end
local function carrying_darkspear_flag(player)
 for _,method in ipairs({"get_auras","get_buffs","get_debuffs","get_all_buffs"}) do
  local ok,list=pcall(function() return type(player[method])=="function" and player[method](player) end)
  if ok and type(list)=="table" then
   for _,aura in pairs(list) do if darkspear_carrier_auras[aura_id(aura)] then return true end end
  end
 end
 return false
end
local function flag_pressure(player)
 for _,method in ipairs({"get_auras","get_buffs","get_debuffs","get_all_buffs"}) do
  local ok,list=pcall(function() return type(player[method])=="function" and player[method](player) end)
  if ok and type(list)=="table" then
   for _,aura in pairs(list) do
    local name=type(aura)=="table" and tostring(aura.name or aura.spell_name or ""):lower() or ""
    if flag_pressure_auras[aura_id(aura)] or name=="focused assault" or name=="brutal assault" then
     local stacks=tonumber(aura.stacks or aura.stack_count or aura.count or aura.applications) or 1
     return math.max(1,math.min(10,math.floor(stacks)))
    end
   end
  end
 end
 return 0
end
local function distance(a,b)
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local snapshot_objects
local function read_objects(core)
 local getter=core.object_manager.get_all_objects or core.object_manager.get_visible_objects
 local ok,objects=pcall(function() return getter and getter() end)
 return ok and type(objects)=="table" and objects or {}
end
local function live_objects(core)
 return snapshot_objects or read_objects(core)
end
local function object_entry(object)
 for _,method in ipairs({"get_npc_id","get_entry_id","get_entry"}) do
  local ok,value=pcall(function() return type(object[method])=="function" and object[method](object) end)
  value=ok and tonumber(value) or nil
  if value and value>0 then return value end
 end
end
local function object_name(object)
 local ok,value=pcall(function() return type(object.get_name)=="function" and object:get_name() end)
 return ok and type(value)=="string" and value or ""
end
local function backline(anchor,enemies)
 -- An XY offset with the teammate's old Z is not an observed world position.
 -- On ramps it can land below the floor. Approach the measured support point.
 return anchor
end
local function warsong_support_anchor(core,player,position,carrier_detector)
 carrier_detector=carrier_detector or carrying_warsong_flag
 local friends,friend_rows,enemies,carrier,enemy_carrier,friendly_pressure,enemy_pressure={},{},{},nil,nil,0,0
 for _,object in pairs(live_objects(core)) do
  local ok,is_player,valid,dead,ghost,attackable,p=pcall(function()
   return object:is_player(),object:is_valid(),object:is_dead(),object:is_ghost(),player:can_attack(object),Snapshot.position(object:get_position())
  end)
  if ok and not Object.same(object,player) and is_player and valid and not dead and not ghost and p then
   if attackable==false then
    friends[#friends+1]=p
    local health_ratio
    local health_ok,health,max_health=pcall(function() return object:get_health(),object:get_max_health() end)
    if health_ok and type(health)=="number" and type(max_health)=="number" and max_health>0 then
     health_ratio=math.max(0,math.min(1,health/max_health))
    end
    friend_rows[#friend_rows+1]={position=p,health_ratio=health_ratio}
    if carrier_detector(object) then carrier=p;friendly_pressure=flag_pressure(object) end
   else
    local row={position=p,target=object,id=Object.guid(object) or string.format("enemy_%.0f_%.0f",p.x,p.y),
     reachable=true,attackable=true,dead=false}
    enemies[#enemies+1]=row
    if carrier_detector(object) then enemy_carrier=row;enemy_pressure=flag_pressure(object) end
   end
  end
 end
 if carrier then return carrier,true,backline(carrier,enemies),enemy_carrier,enemies,friendly_pressure,enemy_pressure,friends end
 if #friends==0 then return nil,false,nil,enemy_carrier,enemies,friendly_pressure,enemy_pressure,friends end
 local anchor=Formation.choose(friend_rows,position,55) or friends[1]
 local healer_anchor=Formation.choose_healer(friend_rows,position,45,enemies) or anchor
 return anchor,false,backline(healer_anchor,enemies),enemy_carrier,enemies,friendly_pressure,enemy_pressure,friends
end
local function attach_objects(core,rows)
 local objects=live_objects(core)
 for _,row in ipairs(rows) do
  local best,best_distance
  for _,object in pairs(objects) do
   local ok,valid,is_unit,position=pcall(function()
    return object:is_valid(),object:is_unit(),Snapshot.position(object:get_position())
   end)
   if ok and valid and is_unit==false and position then
    local d=distance(position,row.position)
    if d<=5 and (not best_distance or d<best_distance) then best,best_distance=object,d end
   end
  end
  row.object=best;row.available=best~=nil;row.pickup_allowed=true;row.reachable=true
 end
end
function B.supports(profile) return profile~=nil and Rules.profiles[profile]~=nil end
local function formation(core,profile,player,match,now,team,position,player_role)
 local rule=Rules.profiles[profile]
 if not rule then return nil,"builtin_objectives_unavailable" end
 local anchor,best;local friends,enemies={},{}
 for _,object in pairs(live_objects(core)) do
  local ok,is_player,valid,dead,ghost,attackable,p=pcall(function()
   return object:is_player(),object:is_valid(),object:is_dead(),object:is_ghost(),player:can_attack(object),Snapshot.position(object:get_position())
  end)
  if ok and not Object.same(object,player) and is_player and valid and not dead and not ghost and p then
   if attackable==false then
    local d=distance(position,p);if d>5 and (not best or d<best) then anchor,best=p,d end
    if d>5 then
     local health_ratio
     local health_ok,health,max_health=pcall(function() return object:get_health(),object:get_max_health() end)
     if health_ok and type(health)=="number" and type(max_health)=="number" and max_health>0 then
      health_ratio=math.max(0,math.min(1,health/max_health))
     end
     friends[#friends+1]={position=p,health_ratio=health_ratio}
    end
   else enemies[#enemies+1]=p end
  end
 end
 if #friends>1 then
  if player_role=="healer" then anchor=Formation.choose_healer(friends,position,45,enemies) or anchor
  else anchor=Formation.choose(friends,position,55) or anchor end
 end
 if not anchor then return nil,"team_formation_unavailable" end
 if player_role=="damage" and (rule.kind=="bases" or rule.kind=="hybrid" or rule.kind=="reinforcements") then
  -- With no live ownership feed, DPS should advance to a real strategic map
  -- landmark instead of treating the nearest teammate as an empty friendly
  -- base and following them under the misleading "guard" objective.
  local formation_anchor=anchor
  local graph=RouteData[profile];local objective,objective_id,best_distance
  local spawn_ids={h=true,a=true,fh=true,db=true,horde=true,alliance=true,beach=true,west=true}
  for id,node in pairs(graph and graph.nodes or {}) do
   local name=tostring(id)
   local transit=name:find("spawn",1,true) or name:find("exit",1,true) or name:find("gate",1,true) or
    name:find("road",1,true) or name:find("ramp",1,true) or name:find("lane",1,true) or
    name:find("cross",1,true) or name:find("turn",1,true) or name:find("mid",1,true)
   if not spawn_ids[id] and not transit then
    -- Follow the team's battle direction, but never keep selecting the exact
    -- landmark the player has already reached. Without an ownership feed that
    -- produced an endless fake "capture" hold at EOTS Draenei Ruins.
    local d=distance(formation_anchor,node)
    if distance(position,node)<=8 then d=d+500 end
    if not best_distance or d<best_distance then objective,objective_id,best_distance=node,name,d end
   end
  end
  if objective then anchor=objective end
 end
 local s={valid=true,match_id=match,observed_at=now,team=team,rule_profile=profile,
  mode=rule.mode,kind=rule.kind,player_position=position,player_role=player_role,formation_fallback=true,
  objective_source="team_formation_fallback",
  friendly_positions=friends,
  friendly_group_position=anchor,healer_position=player_role=="healer" and backline(anchor,enemies) or nil,
  enemies=enemies}
 if rule.kind=="ctf" or rule.kind=="legacy_cart_bases" then
  s.flags={{id="team_formation",team=1-team,carrier=true,carrier_enemy=false,position=anchor,reachable=true}}
 elseif rule.kind=="bases" or rule.kind=="hybrid" or rule.kind=="reinforcements" then
  if player_role=="damage" then
   -- This is a verified route landmark, not verified live ownership. Give each
   -- landmark a stable identity so planner commitment prevents route thrashing.
   s.nodes={{id="strategic_advance:"..tostring(objective_id or "formation"),fallback_advance=true,
    position=anchor,active=true,reachable=true}}
  else
   s.nodes={{id="team_formation",owner=team,defenders=0,position=anchor,active=true,reachable=true}}
  end
 elseif rule.kind=="orbs" then
  s.orbs={{id="team_formation",carrier=true,carrier_enemy=false,position=anchor,reachable=true}}
 elseif rule.kind=="carts" or rule.kind=="cart_crystal" then
  s.carts={{id="team_formation",owner=team,active=true,position=anchor,reachable=true}}
 elseif rule.kind=="resources" then
  s.resources={{id="team_formation",active=true,mineable=false,position=anchor,reachable=true}}
 elseif rule.kind=="siege" or rule.kind=="frontline" then
  s.objectives={{id="team_formation",type="frontline",available=true,reachable=true,position=anchor}}
 elseif rule.kind=="deathmatch" then
  s.enemies={{id="team_formation",attackable=true,dead=false,reachable=true,position=anchor}}
 else return nil,"team_formation_profile_unsupported" end
 return s
end
local function deephaul(core,player,match,now,team,position,player_role)
 local carts,crystals={},{}
 for _,object in pairs(live_objects(core)) do
  local ok,valid,p=pcall(function() return object:is_valid(),Snapshot.position(object:get_position()) end)
  local entry=ok and valid and p and object_entry(object) or nil
  if entry and Trinity.deephaul.cart_entries[entry] then
   carts[#carts+1]={id="mine_cart_"..tostring(entry).."_"..tostring(#carts+1),entry=entry,object=object,
    position=p,active=true,reachable=true}
  elseif entry==Trinity.deephaul.crystal_entry then
   crystals[#crystals+1]={id="deephaul_crystal",entry=entry,object=object,position=p,available=true,reachable=true}
  end
 end
 if #carts==0 and #crystals==0 then return formation(core,"deephaul",player,match,now,team,position,player_role) end
 local support,_,healer_position=warsong_support_anchor(core,player,position)
 return {valid=true,match_id=match,observed_at=now,team=team,rule_profile="deephaul",kind="cart_crystal",
  player_position=position,player_role=player_role,carts=carts,crystals=crystals,friendly_group_position=support,
  healer_position=player_role=="healer" and healer_position or nil,objective_source="live_objective_reader"}
end
local function silvershard(core,player,match,now,team,position,player_role)
 local carts={}
 for _,object in pairs(live_objects(core)) do
  local ok,valid,is_unit,p=pcall(function()
   return object:is_valid(),object:is_unit(),Snapshot.position(object:get_position())
  end)
  if ok and valid and is_unit and p and object_entry(object)==SILVERSHARD_CART_ENTRY then
   carts[#carts+1]={id="mine_cart_"..tostring(#carts+1),entry=SILVERSHARD_CART_ENTRY,
    object=object,position=p,active=true,reachable=true}
  end
 end
 if #carts==0 then return nil,"silvershard_cart_data_unavailable" end
 local support,_,healer_position=warsong_support_anchor(core,player,position)
 return {valid=true,match_id=match,observed_at=now,team=team,rule_profile="silvershard",
  kind="carts",player_position=position,player_role=player_role,carts=carts,friendly_group_position=support,
  healer_position=player_role=="healer" and healer_position or nil,objective_source="live_objective_reader"}
end
local function seething(core,player,match,now,team,position,player_role)
 -- Healers support the live friendly formation; DPS and tanks can take freshly
 -- observed Azerite objectives. Unknown/absent objects fall back conservatively.
 if player_role=="healer" then return formation(core,"seething",player,match,now,team,position,player_role) end
 local resources={}
 for _,object in pairs(live_objects(core)) do
  local entry=object_entry(object);local name=object_name(object):lower()
  if SEETHING_AZERITE_ENTRIES[entry] or name=="azerite" then
   local ok,valid,is_unit,p=pcall(function()
    return object:is_valid(),object:is_unit(),Snapshot.position(object:get_position())
   end)
   if ok and valid and not is_unit and p then
    resources[#resources+1]={id=string.format("azerite_%s_%d_%d",tostring(entry or 0),math.floor(p.x/5),math.floor(p.y/5)),entry=entry,
     object=object,position=p,active=true,mineable=true,reachable=true}
   end
  end
 end
 if #resources==0 then return formation(core,"seething",player,match,now,team,position,player_role) end
 return {valid=true,match_id=match,observed_at=now,team=team,rule_profile="seething",kind="resources",
  player_position=position,player_role=player_role,resources=resources,objective_source="live_objective_reader"}
end
local function darkspear(core,player,match,now,team,position,player_role)
 local s,reason=formation(core,"darkspear_islands",player,match,now,team,position,player_role)
 if not s then return nil,reason end
 local support,friendly_carrier,healer_position,enemy_carrier,enemies,friendly_pressure,enemy_pressure=
  warsong_support_anchor(core,player,position,carrying_darkspear_flag)
 s.enemies=enemies or s.enemies
 s.friendly_group_position=support or s.friendly_group_position
 if player_role=="healer" then s.healer_position=healer_position or s.healer_position end
 if friendly_carrier then
  s.friendly_flag_carrier_position=support
  s.flags={{id="darkspear_flag",team=team,carrier=true,carrier_enemy=false,position=support,
   carrier_pressure=friendly_pressure,reachable=true}}
 elseif enemy_carrier then
  enemy_carrier.objective_carrier=true
  s.flags={{id="darkspear_flag",team=1-team,carrier=enemy_carrier.target,carrier_enemy=true,
   position=enemy_carrier.position,carrier_pressure=enemy_pressure,reachable=true}}
 end
 if carrying_darkspear_flag(player) then
  -- A legal turn-in requires a live, friendly-controlled base. The built-in
  -- reader cannot prove ownership, so fail closed at the friendly formation;
  -- an external live objective provider can replace this with an owned node.
  s.carrying=true;s.carrier_speed_cap=Darkspear.rules.carrier_speed_cap;s.has_owned_node=false;s.carry_destination_valid=false
  s.safe_position=s.friendly_group_position or position
 end
 s.score_limit=Darkspear.rules.score_to_win
 if player_role=="healer" then return s end
 local landmarks=Darkspear.landmarks(core,position.z)
 if not landmarks then return s end
 local anchor=s.friendly_group_position or position
 -- The central flag is actionable only after live data proves that our team
 -- owns a delivery base. Formation fallback uses a stable faction-aware patrol
 -- of the four published capture points and never invents a legal turn-in.
 local selected,selected_id=Darkspear.patrol_target(landmarks,position,anchor,team)
 if selected then
  s.nodes={{id="strategic_advance:"..selected_id,fallback_advance=true,active=true,reachable=true,
   position={x=selected.x,y=selected.y,z=selected.z}}}
 end
 return s
end
local function warsong(core,player,match,now,team,position,player_role)
 local observed={}
 for _,object in pairs(live_objects(core)) do
  local entry=object_entry(object);local row=entry and (entry==227740 and warsong_flags[0] or entry==227741 and warsong_flags[1])
  if row then
   local ok,valid,is_unit,p=pcall(function()
    return object:is_valid(),object:is_unit(),Snapshot.position(object:get_position())
   end)
   if ok and valid and not is_unit and p then observed[entry]={object=object,position=p} end
  end
 end
 local support,friendly_carrier,healer_position,enemy_carrier,enemies,friendly_pressure,enemy_pressure=warsong_support_anchor(core,player,position)
 local flags={}
 for flag_team,row in pairs(warsong_flags) do
  local live=observed[row.entry];local p=live and live.position or row.position
  local at_home=live and distance(p,row.position)<=20 or false
  local is_own=flag_team==team
  local active_carrier
  if is_own then active_carrier=enemy_carrier elseif friendly_carrier then active_carrier={position=support} end
  if active_carrier then p=active_carrier.position end
  local carrier_value
  if is_own and enemy_carrier then carrier_value=enemy_carrier.target elseif active_carrier then carrier_value=true end
  flags[#flags+1]={id=row.id,entry=row.entry,team=flag_team,object=live and live.object or nil,
   position=p,reachable=true,pickup_allowed=true,carrier_pressure=is_own and enemy_pressure or friendly_pressure,
   available=not is_own and not active_carrier and (not live or at_home),
   dropped=is_own and not active_carrier and live~=nil and not at_home,
   carrier=carrier_value,carrier_enemy=is_own and active_carrier~=nil,
   approach_route=flag_team~=team and warsong_routes[team] or nil}
 end
 local carrying_flag=carrying_warsong_flag(player)
 local own=warsong_flags[team]
 local own_live=observed[own.entry]
 local own_home=own_live~=nil and distance(own_live.position,own.position)<=20
 local observed_count=0;for _ in pairs(observed) do observed_count=observed_count+1 end
 local live_state_count=observed_count+(friendly_carrier and 1 or 0)+(enemy_carrier and 1 or 0)
 return {valid=true,match_id=match,observed_at=now,team=team,rule_profile="warsong",kind="ctf",
  player_position=position,player_role=player_role,flags=flags,enemies=enemies,carrying=carrying_flag,
  carrier_speed_cap=carrying_flag and .85 or nil,
  own_flag_home=own_home,carry_destination=own.position,safe_position=own.position,
  carry_route=warsong_routes[1-team],friendly_group_position=support,
  friendly_flag_carrier_position=friendly_carrier and support or nil,
  healer_position=player_role=="healer" and healer_position or nil,
  objective_source=live_state_count>=2 and "live_objective_reader" or "static_objective_fallback"}
end
local function build_snapshot(core,profile,player,match,now,player_role,team_override)
 player_role=player_role or Theme.detect(player).role
 local position=Snapshot.position(player:get_position())
 if not position then return nil,"player_position_invalid" end
 local team=team_override
 if team~=0 and team~=1 then team=core.game_ui.get_battlefield_arena_faction and core.game_ui.get_battlefield_arena_faction() end
 if team~=0 and team~=1 then return nil,"team_identity_unavailable" end
 if profile=="silvershard" then return silvershard(core,player,match,now,team,position,player_role) end
 if profile=="deephaul" then return deephaul(core,player,match,now,team,position,player_role) end
 if profile=="warsong" then return warsong(core,player,match,now,team,position,player_role) end
 if profile=="seething" then return seething(core,player,match,now,team,position,player_role) end
 if profile=="darkspear_islands" then return darkspear(core,player,match,now,team,position,player_role) end
 if profile~="kotmogu" then return formation(core,profile,player,match,now,team,position,player_role) end
 local has_orb=carrying(player)
 local rows={};for i,row in ipairs(kotmogu) do
  rows[i]={id=row.id,entry=row.entry,position={x=row.position.x,y=row.position.y,z=row.position.z}}
 end
 if not has_orb then attach_objects(core,rows) end
 local live_orb=has_orb
 if not live_orb then for _,row in ipairs(rows) do if row.object then live_orb=true;break end end end
 local support,friendly_orb_carrier,healer_position,_,enemies,_,_,friends=warsong_support_anchor(core,player,position,carrying)
 local scoring={x=1783.55,y=1333.42,z=13.25}
 return {valid=true,match_id=match,observed_at=now,team=team,rule_profile="kotmogu",
  kind="orbs",player_position=position,player_role=player_role,carrying=has_orb,orbs=rows,
  orb_scoring_position=scoring,safe_position=support or scoring,
  friendly_positions=friends,enemies=enemies,
  friendly_group_position=support,friendly_orb_carrier_position=friendly_orb_carrier and support or nil,
  healer_position=player_role=="healer" and healer_position or nil,
  objective_source=live_orb and "live_objective_reader" or "static_objective_fallback"}
end
function B.snapshot(core,profile,player,match,now,player_role,team_override,objects_override)
 -- Specialized readers often need both objective and formation views. Keep one
 -- detached object-list snapshot for the whole build so Warsong, Silvershard,
 -- Deephaul and Kotmogu do not enumerate the object manager repeatedly in the
 -- same combat update. Always clear it, including when a reader raises.
 snapshot_objects=type(objects_override)=="table" and objects_override or read_objects(core)
 local ok,result,reason=pcall(build_snapshot,core,profile,player,match,now,player_role,team_override)
 snapshot_objects=nil
 if not ok then error(result) end
 return result,reason
end
return B
