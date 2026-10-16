local M={}
function M.arrival(action,explicit,purpose)
 if explicit then return math.max(.5,math.min(8,explicit)) end
 if purpose=='object' then return 1.5 end
 if purpose=='item' then return 2 end
 if action=='accept' or action=='turnin' then return 4 end
 if action=='objective' or action=='collect' then return 3 end
 return 2
end
-- A generic kill/loot area checkpoint is not an object click destination.
-- Reaching this area starts target discovery; it never awards quest credit.
function M.objective_area_ready(step,here)
 if not here or not step.position or step.action~='objective' or step.handler~='guide_objective'
    or step.destination_pending or step.objective_mode=='explore' or step.target_name or step.npc_id
    or step.quest_action_mode or step.extra_action_spell_id or step.tags and (step.tags.NC or step.tags.U or step.tags.CHAT) then return false end
 local goal=step.position
 local dx,dy,dz=here.x-goal.x,here.y-goal.y,here.z-goal.z
 return dx*dx+dy*dy<=64 and math.abs(dz)<=4
end
function M.prefer_flight(distance,ground_speed,flight_speed,grounded)
 local ground=tonumber(ground_speed);local flying=tonumber(flight_speed)
 -- Grounded flight-speed fields describe the current movement mode, not
 -- the cruise speed after Skyriding takeoff. Use a conservative estimate.
 if grounded then flying=50 end
 if not ground or ground~=ground or ground<=0 or ground>1000 then ground=14 end
 if not flying or flying~=flying or flying<=0 or flying>1000 then flying=50 end
 return distance>75 and distance/ground>10+distance/flying
end
function M.owner(api)
 local self={name=nil,generation=0}
 function self:claim(name)
  if self.name==name then return false end
  local previous=self.name;self.generation=self.generation+1;self.name=name
  if previous then api.stop(previous,name) end
  if api.log then api.log('movement_owner_changed',{previous=previous,owner=name,generation=self.generation}) end
  return true
 end
 return self
end
function M.acceptance(steps,qid,on_quest,turned_in)
 if on_quest(qid) or turned_in(qid) then return nil end
 for i,s in ipairs(steps) do if s.quest_id==qid and s.action=='accept' then return i end end
end
return M
