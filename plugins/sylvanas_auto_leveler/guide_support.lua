-- Optional live RestedXP data, read through Sylvanas' documented addon API.
-- Only use a waypoint belonging to the same quest; never substitute arbitrary active/manual points.
local M={}
function M.enrich(step,api)
 if step.coordinate_source=="custom_restedxp_authored" then return false end
 if not step.quest_id or step.map_position then return false end
 if not api or type(api.is_loaded)~="function" or not api.is_loaded() then return false end
 local current=api.get_current_step();if not current or current.is_complete then return false end
 local matches=false
 for _,goal in ipairs(current.goals or {}) do
  if not goal.is_complete and not goal.text_only then
   if goal.quest_id==step.quest_id then matches=true end
   for _,id in ipairs(goal.ids or {}) do if id==step.quest_id then matches=true end end
  end
 end
 if not matches then return false end
 local waypoint=api.get_current_waypoint()
 if not waypoint or waypoint.wrong_continent or waypoint.is_manual or waypoint.goal_num~=current.num then return false end
 local x,y=waypoint.x,waypoint.y
 if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<0 or x>1 or y<0 or y>1
  or type(waypoint.map_id)~="number" or waypoint.map_id<1 then return false end
 step.ui_map_id=waypoint.map_id;step.map_position={x=x*100,y=y*100};step.coordinate_source="restedxp_live"
 return true
end
-- Read a locally installed Zygor guide through the supplied addon bridge.
-- Match quest AND action; unrelated current/sticky targets are never borrowed.
function M.zygor(step,api)
 if step.coordinate_source=="custom_restedxp_authored" then return false end
 if not step.quest_id or not api or type(api.is_loaded)~="function" or not api.is_loaded()
  or type(api.get_current_step)~="function" then return false end
 local current=api.get_current_step()
 if not current or current.is_complete then return false end
 local actions=step.action=="accept" and {accept=true} or step.action=="turnin" and {turnin=true}
  or step.action=="objective" and {kill=true,talk=true,click=true,clicknpc=true,collect=true,complete=true}
  or {}
 local selected
 for _,goal in ipairs(current.goals or {}) do
  if goal.quest_id==step.quest_id and not goal.is_complete and actions[goal.action] then
   if selected then return false end -- Multi-goal ambiguity needs an explicit mapping.
   selected=goal
  end
 end
 if not selected then return false end
 local changed=false
 if not step.npc_id and not step.target_name then
  local id=selected.npc_id
  if type(id)~="number" or id<=0 then id=selected.target_id end
  if type(id)=="number" and id>0 and id%1==0 then step.npc_id=id;changed=true
  else
   local name=selected.npc
   if type(name)~="string" or name=="" then name=selected.target end
   if type(name)=="string" and name~="" then step.target_name=name;changed=true end
  end
 end
 if not step.map_position and type(api.get_current_waypoint)=="function" then
  local w=api.get_current_waypoint()
  if w and not w.is_manual and not w.wrong_continent and w.goal_num==current.num
   and type(w.map_id)=="number" and w.map_id>0
   and type(w.x)=="number" and type(w.y)=="number" and w.x>=0 and w.x<=1 and w.y>=0 and w.y<=1 then
   step.ui_map_id=w.map_id;step.map_position={x=w.x*100,y=w.y*100};step.coordinate_source="zygor_live";changed=true
  end
 end
 if changed then step.support_source="zygor_live" end
 return changed
end
return M
