-- Pure Darkspear Islands strategy derived only from a validated live snapshot.
-- It never invents ownership or positions.
local M={}

local function distance(a,b)
 if not a or not b then return math.huge end
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end

local function usable(node,team)
 return node and node.owner==team and node.active~=false and node.reachable~=false and
  not node.destroyed and node.position~=nil
end

local function threatened(node)
 return node.threatened==true or node.enemy_capture_in_progress==true or
  node.state=="friendly_contested" or node.state=="enemy_contested"
end

function M.analyze(snapshot)
 local result={active_count=0,owned_count=0,safe_owned_count=0,last_owned_threatened=false}
 if type(snapshot)~="table" or snapshot.rule_profile~="darkspear_islands" then return result end
 local origin=snapshot.player_position
 local nearest,nearest_distance,nearest_safe,nearest_safe_distance
 for _,node in ipairs(snapshot.nodes or {}) do
  if node.active~=false and not node.destroyed then result.active_count=result.active_count+1 end
  if usable(node,snapshot.team) then
   result.owned_count=result.owned_count+1
   local d=distance(origin,node.position)
   if not nearest_distance or d<nearest_distance then nearest,nearest_distance=node,d end
   if not threatened(node) then
    result.safe_owned_count=result.safe_owned_count+1
    if not nearest_safe_distance or d<nearest_safe_distance then nearest_safe,nearest_safe_distance=node,d end
   end
  end
 end
 result.last_owned_threatened=result.owned_count==1 and result.safe_owned_count==0
 result.turnin=nearest_safe or nearest
 return result
end

function M.enrich_carrier(snapshot,analysis)
 if type(snapshot)~="table" or snapshot.rule_profile~="darkspear_islands" then return snapshot end
 analysis=analysis or M.analyze(snapshot)
 snapshot.has_owned_node=analysis.owned_count>0
 if snapshot.carrying and analysis.turnin then
  snapshot.carry_destination=analysis.turnin.position
  snapshot.carry_destination_node_id=analysis.turnin.id
  snapshot.carry_destination_valid=true
  if analysis.safe_owned_count>0 then snapshot.safe_position=analysis.turnin.position end
 elseif snapshot.carrying then
  snapshot.carry_destination_valid=false
 end
 return snapshot
end

function M.flag_pickup_value(analysis)
 if not analysis or analysis.owned_count==0 or analysis.last_owned_threatened then return nil end
 return analysis.owned_count==1 and 45 or 105
end

function M.node_bonus(node,team,analysis)
 if not analysis then return 0 end
 if analysis.owned_count==0 and node.owner~=team and node.capturable and not node.locked then return 65 end
 if analysis.owned_count==1 and node.owner==team then
  if threatened(node) then return 65 end
  if (node.defenders or 0)==0 then return 35 end
 end
 return 0
end

return M
