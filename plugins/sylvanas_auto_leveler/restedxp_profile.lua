-- Convert Sylvanas' documented live RestedXP bridge into executable steps.
-- RestedXP remains the authority for guide order and completion.
local M={}
local function point(w)
 if not w or w.wrong_continent or w.is_manual or type(w.map_id)~="number" or w.map_id<1
  or type(w.x)~="number" or type(w.y)~="number" or w.x<0 or w.x>1 or w.y<0 or w.y>1 then return end
 return w.map_id,{x=w.x*100,y=w.y*100}
end
local function target(step,goal)
 step.target_ids={};step.target_names={}
 for _,value in ipairs(goal.units or {}) do
  local id=tonumber(value)
  if id and id>0 then step.target_ids[#step.target_ids+1]=id
  elseif type(value)=="string" and value~="" then step.target_names[#step.target_names+1]=value end
 end
 step.npc_id=step.target_ids[1]
 step.target_name=step.target_names[1]
 if #step.target_ids==0 then step.target_ids=nil end
 if #step.target_names==0 then step.target_names=nil end
end
local function checkpoints(api,source)
 local result={}
 if type(api.get_step_waypoints)=="function" then
  for _,w in ipairs(api.get_step_waypoints() or {}) do
   local map,pos=point(w)
   if map and tonumber(w.goal_num)==tonumber(source.num) then
    local previous=result[#result]
    -- RestedXP may expose the same map point through both the active arrow
    -- and the step waypoint list. Keep its authored order without making the
    -- navigator visit an identical point twice.
    if not previous or previous.ui_map_id~=map or math.abs(previous.x-pos.x)>.01 or math.abs(previous.y-pos.y)>.01 then
     result[#result+1]={ui_map_id=map,x=pos.x,y=pos.y,title=w.title,type=w.type,dist=tonumber(w.dist)}
    end
   end
  end
 end
 -- RestedXP considers a waypoint complete inside its radius. The bridge only
 -- exposes distance, so discard reached leading points while retaining the
 -- final action anchor and every later authored point.
 while #result>1 and result[1].dist and result[1].dist>0 and result[1].dist<=3 do table.remove(result,1) end
 return result
end
local function quest_identity(step,goal)
 local ids={}
 for _,value in ipairs(goal.ids or {}) do
  local id=tonumber(value)
  if id and id>0 then ids[#ids+1]=id end
 end
 local direct=tonumber(goal.quest_id)
 if direct and direct>0 then
  local found=false;for _,id in ipairs(ids) do if id==direct then found=true;break end end
  if not found then table.insert(ids,1,direct) end
 end
 if #ids==1 then step.quest_id=ids[1]
 elseif #ids>1 then step.quest_ids=ids end
end
function M.available(api)
 return api and type(api.is_loaded)=="function" and api.is_loaded()
  and type(api.has_current_step)=="function" and api.has_current_step()
end
function M.build(api)
 if not M.available(api) then return nil,"restedxp_current_step_unavailable" end
 local source=api.get_current_step()
 if not source or source.is_complete or source.active==false then return nil,"restedxp_current_step_inactive" end
 local waypoint=api.get_current_waypoint and api.get_current_waypoint() or nil
 if waypoint and tonumber(waypoint.goal_num)~=tonumber(source.num) then waypoint=nil end
 local map,pos=point(waypoint)
 local points=checkpoints(api,source)
 if not map and points[#points] then map=points[#points].ui_map_id;pos={x=points[#points].x,y=points[#points].y} end
 local sources={source}
 if type(api.get_current_stickies)=="function" then
  for _,sticky in ipairs(api.get_current_stickies() or {}) do
   if sticky and sticky.active~=false and not sticky.is_complete and tonumber(sticky.num)~=tonumber(source.num) then
    sources[#sources+1]=sticky
   end
  end
 end
 local steps={}
 local route_assigned=false
 local signature={}
 for _,active_source in ipairs(sources) do
 signature[#signature+1]=tostring(active_source.num or 0)
 local source_points=checkpoints(api,active_source)
 for index,goal in ipairs(active_source.goals or {}) do
  if not goal.is_complete and not goal.text_only then
   local action=tostring(goal.action or ""):lower()
   local qid=tonumber(goal.quest_id)
   local step={source="restedxp_live",source_index=active_source.num,rxp_goal=index,title=goal.text,
    quest_id=qid and qid>0 and qid or nil,ui_map_id=map,map_position=pos and {x=pos.x,y=pos.y} or nil,
    restedxp_sticky=active_source~=source or nil}
   if action=="accept" then step.action="accept";step.auto_dialog=true;quest_identity(step,goal)
   elseif action=="turnin" then step.action="turnin";step.reward_choice=tonumber(goal.reward) or 0;step.auto_dialog=true;quest_identity(step,goal)
   elseif action=="complete" or action=="collect" or action=="kill" or action=="mob"
    or action=="target" or action=="unitscan" or action=="talk" or action=="click" or action=="use"
    or action=="gossipoption" then
    step.action="objective";step.handler="guide_objective"
    if tonumber(goal.objective) and tonumber(goal.objective)>0 then step.objective_index=tonumber(goal.objective) end
    target(step,goal)
   elseif action=="itemcount" and goal.ids and tonumber(goal.ids[1]) and tonumber(goal.item_total)>0 then
    -- RXP itemcount goals frequently have no quest id. Preserve them as
    -- inventory gates so the route waits for the authored quantity instead
    -- of silently dropping the entire guide step.
    step.action="collect";step.handler="guide_objective";step.item_goal={item_id=tonumber(goal.ids[1]),count=tonumber(goal.item_total),
     operator=tonumber(goal.item_operator) or 0,inclusive=goal.item_eq==true}
   elseif action=="money" and tonumber(goal.money) then
    step.action="money_gate";step.money=tonumber(goal.money);step.money_greater_than=goal.money_greater_than==true
   elseif action=="goto" or action=="walk" or action=="zone" then step.action="travel";step.travel_mode="ground"
   elseif action=="fly" then step.action="travel";step.travel_mode="taxi";step.taxi_destination=goal.text
   elseif action~="" then
    -- Never let an active RestedXP mechanic disappear from the automation.
    -- The controller will stop with the exact action name and permanent log,
    -- making missing bridge coverage explicit instead of skipping progression.
    step.action="unsupported";step.unsupported_reason="restedxp_goal_action_unsupported:"..action
   end
   if step.action and (step.action=="travel" or step.quest_id or step.quest_ids or step.item_goal
    or step.action=="money_gate" or step.action=="unsupported") then
    if #source_points>0 then
     if not route_assigned then step.coordinate_route={} end
     step.checkpoints={}
     for _,p in ipairs(source_points) do
      if step.coordinate_route then step.coordinate_route[#step.coordinate_route+1]={ui_map_id=p.ui_map_id,x=p.x,y=p.y,title=p.title,type=p.type,dist=p.dist} end
      if not step.ui_map_id or p.ui_map_id==step.ui_map_id then step.checkpoints[#step.checkpoints+1]={x=p.x,y=p.y} end
     end
     -- The final authored coordinate is the action anchor. Earlier entries
     -- are an ordered itinerary and are consumed one at a time by controller.
     local final=source_points[#source_points]
     step.ui_map_id=final.ui_map_id;step.map_position={x=final.x,y=final.y}
     step.coordinate_source="restedxp_ordered_waypoints"
     if step.coordinate_route then route_assigned=true end
    end
    steps[#steps+1]=step
    signature[#signature+1]=table.concat({tostring(active_source.num or 0),tostring(index),action,tostring(step.quest_id or ""),
     tostring(step.quest_ids and table.concat(step.quest_ids,",") or "")},":")
   end
  end
 end
 end
 if #steps==0 then return nil,"restedxp_step_has_no_executable_goals" end
 local game=core and core.get_game_version and core.get_game_version() or "Midnight"
 return {id="Sylvanas:RestedXP:"..tostring(source.num),name="Sylvanas Leveling Route",compiled=false,source="restedxp_live",
  rxp_step_num=source.num,rxp_signature=table.concat(signature,"|"),steps=steps,target_level=game=="Forever" and 60 or 90,max_retries=3,persistent_navigation=true,
  game_version=game,edition=game=="Forever" and "Vanilla" or "Retail"}
end
return M
