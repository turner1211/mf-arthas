-- Reconcile saved progress with authoritative live character state.
local M={}
function M.select(steps,saved,api,context)
 local index=math.max(1,math.min(#steps+1,tonumber(saved) or 1))
 local function satisfied(step)
  if step.completion_parent_quest_id and api.turned_in(step.completion_parent_quest_id)==true then return true end
  if step.resume_before_quest_id and step.resume_after_quest_id
   and api.turned_in(step.resume_before_quest_id)==true and api.turned_in(step.resume_after_quest_id)==true then return true end
  local id=step.quest_id
  if not id then
   if step.completion_quest_id then
    if api.turned_in(step.completion_quest_id)==true then return true end
    if step.completion_objective_index and api.on_quest(step.completion_quest_id)==true and api.objective_done then
     return api.objective_done(step.completion_quest_id,step.completion_objective_index)==true
    end
   end
   return false
  end
  if step.hidden_completion_watch and api.on_quest(id)~=true then return true end
  if api.turned_in(id)==true then return true end
  if step.action=="accept" then return api.on_quest(id)==true end
  if step.action=="objective" and api.on_quest(id)==true and api.objective_done then
   return api.objective_done(id,step.objective_index,step.objective_indices)==true
  end
  return false
 end
 local function premature_turnin(step)
  if step.action~='turnin' then return false end
  for _,candidate in ipairs(steps) do
   if candidate.quest_id==step.quest_id and candidate.action=='objective' and not satisfied(candidate) then return true end
  end
  return false
 end
 -- With a live startup snapshot, reconcile in both directions. Never mark
 -- skipped history complete: only choose an action proven active in the log.
 if context then
  local best,best_score
  for i,step in ipairs(steps) do
   if step.quest_id and (step.action=='objective' or step.action=='turnin')
    and api.on_quest(step.quest_id)==true and not satisfied(step) then
    local same_map=step.ui_map_id and step.ui_map_id==context.ui_map_id
    local score=(same_map and 100000 or 0)-i
    -- An unfinished objective precedes the turn-in for the same quest.
    if premature_turnin(step) then score=nil end
    if score and (not best_score or score>best_score) then best=i;best_score=score end
   end
  end
  if best then
   if api.log then api.log('quest_resume_live_selected',{saved=index,step=best,quest_id=steps[best].quest_id,map=context.ui_map_id,level=context.level}) end
   return best
  end
 end
 -- A persisted cursor cannot hide unfinished quests that are still in the
 -- live log. Rewind only to their actionable objective/turn-in, preserving
 -- unrelated required steps instead of jumping forward to an arbitrary quest.
 for prior=1,index-1 do
  local step=steps[prior]
  if step.quest_id and (step.action=="objective" or step.action=="turnin")
   and api.on_quest(step.quest_id)==true and not satisfied(step) and not premature_turnin(step) then
   if api.log then api.log("quest_resume_live_rewind",{saved=index,step=prior,quest_id=step.quest_id}) end
   index=prior;break
  end
 end
 -- Preserve unfinished turn-ins and nonquest travel/mechanics. Mere absence
 -- from the quest log is never proof that a quest was completed.
 while steps[index] and satisfied(steps[index]) do index=index+1 end
 -- Accepted steps can advance directly into an authored early turn-in. Apply
 -- the same readiness guard after forward skipping as before history rewind.
 if steps[index] and premature_turnin(steps[index]) then
  local id=steps[index].quest_id
  for candidate,step in ipairs(steps) do
   if step.quest_id==id and step.action=='objective' and not satisfied(step) then
    if api.log then api.log('quest_resume_unfinished_objective',{saved=saved,turnin=index,step=candidate,quest_id=id}) end
    return candidate
   end
  end
 end
 return index
end
return M
