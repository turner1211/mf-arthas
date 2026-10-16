local F={}
local function distance(a,b)
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function point(row) return row.position or row end
local function key(p) return string.format("%0.3f:%0.3f:%0.3f",p.x,p.y,p.z) end
function F.choose(rows,player_position,radius)
 if type(rows)~="table" or #rows==0 or not player_position then return nil end
 radius=tonumber(radius) or 55
 local best,best_score,best_key
 for _,candidate in ipairs(rows) do
  local p=point(candidate);local members,total_distance,injury=0,0,0
  for _,other in ipairs(rows) do
   local q=point(other);local d=distance(p,q)
   if d<=radius then
    members=members+1;total_distance=total_distance+d
    local health=tonumber(other.health_ratio)
    if health and health>=0 and health<=1 then injury=injury+(1-health) end
   end
  end
  -- Member count dominates. Injury breaks otherwise similar clusters, then
  -- medoid distance and healer travel choose a stable, reachable representative.
  local score=members*1000+injury*100-total_distance-distance(player_position,p)*0.05
  local candidate_key=key(p)
  if not best_score or score>best_score or score==best_score and candidate_key<best_key then
   best,best_score,best_key=p,score,candidate_key
  end
 end
 return best and {x=best.x,y=best.y,z=best.z} or nil
end
function F.choose_healer(rows,player_position,radius,enemies)
 if type(rows)~="table" or #rows==0 or not player_position then return nil end
 radius=tonumber(radius) or 45
 local best,best_score,best_key
 for _,candidate in ipairs(rows) do
  local p=point(candidate);local members,injured,injury,total_distance,enemy_count=0,0,0,0,0
  for _,other in ipairs(rows) do
   local q=point(other);local d=distance(p,q)
   if d<=radius then
    members=members+1;total_distance=total_distance+d
    local health=tonumber(other.health_ratio)
    if health and health>=0 and health<=1 then
     local missing=1-health;injury=injury+missing
     if health<0.85 then injured=injured+1 end
    end
   end
  end
  for _,enemy in ipairs(type(enemies)=="table" and enemies or {}) do
   local q=point(enemy)
   if q and distance(p,q)<=radius then enemy_count=enemy_count+1 end
  end
  -- Favor the part of the fight with the greatest recoverable damage while
  -- retaining enough group weight that one isolated ally cannot kite the
  -- healer away from the team. Travel and medoid distance keep the result
  -- stable when two clusters need similar help.
  local danger=math.min(1200,enemy_count*220+math.max(0,enemy_count-members)*300)
  local score=members*350+injured*275+injury*650-danger-total_distance-distance(player_position,p)*0.12
  if #rows>1 and members==1 then score=score-700 end
  local candidate_key=key(p)
  if not best_score or score>best_score or score==best_score and candidate_key<best_key then
   best,best_score,best_key=p,score,candidate_key
  end
 end
 return best and {x=best.x,y=best.y,z=best.z} or nil
end
return F
