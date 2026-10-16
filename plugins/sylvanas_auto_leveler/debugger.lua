-- Read-only live diagnostics. Capturing a snapshot must never alter gameplay.
local M={}
M.entity_id="sylvanas_auto_leveler"
local function call(default,fn,...)
 local ok,value=pcall(fn,...);if ok and value~=nil then return value end;return default
end
local function scalar(value)
 if value==nil then return "-" end
 if type(value)=="number" then return string.format("%.3f",value) end
 return tostring(value):gsub("[%c]"," ")
end
function M.capture(context)
 local active=context.active
 local player=context.player
 local step=active and active.profile and active.profile.steps and active.profile.steps[active.index] or {}
 local position=player and call(nil,function() return player:get_position() end)
 local target=player and call(nil,function() return player:get_target() end)
 local area=context.area and call(nil,context.area) or nil
 local navigation=context.navigation
 local client=navigation and call(nil,navigation.client)
 local destination=client and client.job and client.job.destination or step.position
 local server_available=client and client.is_server_available and call(nil,function()return client:is_server_available()end)
 local learning=active and active.adapter and active.adapter.quest_route_status
  and call(nil,active.adapter.quest_route_status,step) or nil
 local adapter=active and active.adapter
 local progress=adapter and adapter.progress_token and call(nil,adapter.progress_token,step)
 local ready=step.quest_id and adapter and adapter.objective_done and call(nil,adapter.objective_done,step.quest_id)
 local accepted=step.quest_id and adapter and adapter.on_quest and call(nil,adapter.on_quest,step.quest_id)
 return {
  quest_progress=progress,quest_ready=ready,quest_accepted=accepted,
  navigation_state=navigation and navigation.state and call(nil,navigation.state),navigation_request_age=client and client.job and context.captured_at and client.job.started and math.max(0,context.captured_at-client.job.started),
  navigation_server_available=server_available,destination_x=destination and destination.x,destination_y=destination and destination.y,destination_z=destination and destination.z,
  entity_id=M.entity_id,version=context.version,captured_at=context.captured_at,arthas_nav_loaded=context.arthas_nav_loaded,profile=active and active.profile and active.profile.id,
  enabled=active and active.enabled or false,state=active and active.state or "not_started",
  step=active and active.index,total=active and active.profile and #active.profile.steps,
  action=step.action,quest_id=step.quest_id,source_index=step.source_index,title=step.title,
  move=active and active.move,retries=active and active.retries,self_repairs=active and active.self_repairs,
  map=context.map and call(nil,context.map),instance=context.instance and call(nil,context.instance),
  area=area and area.name,x=position and position.x,y=position and position.y,z=position and position.z,
  level=player and call(nil,function() return player:get_level() end),
  combat=player and call(false,function() return player:is_in_combat() end) or false,
  mounted=player and call(false,function() return player:is_mounted() end) or false,
  flying=player and call(false,function() return player:is_flying() end) or false,
  target=target and call("-",function() return target:get_name() end) or "-",
  target_id=target and call(nil,function() return target:get_npc_id() end),
  sentinel_loaded=context.sentinel_loaded,navlib_loaded=context.navlib_loaded,
  navigation_available=navigation and call(false,navigation.available) or false,
  navigation_planning=navigation and call(false,navigation.is_planning) or false,
  navigation_job=client and client.job~=nil or false,
  learned_checkpoint=learning and learning.checkpoint,
  checkpoint_successes=learning and learning.successes,
  checkpoint_failures=learning and learning.failures,
  log_error=context.log_error,
 }
end
function M.text(snapshot,rows,limit)
 local keys={"entity_id","version","captured_at","arthas_nav_loaded","profile","enabled","state","step","total","action","quest_id","quest_progress","quest_ready","quest_accepted","source_index","title",
  "move","retries","self_repairs","map","instance","area","x","y","z","level","combat","mounted","flying",
  "target","target_id","sentinel_loaded","navlib_loaded","navigation_available","navigation_server_available","navigation_state","navigation_request_age","navigation_planning","navigation_job","destination_x","destination_y","destination_z",
  "learned_checkpoint","checkpoint_successes","checkpoint_failures","log_error"}
 local out={"SYLVANAS AUTO LEVELER DEBUG SNAPSHOT"}
 for _,key in ipairs(keys) do out[#out+1]=key.."="..scalar(snapshot[key]) end
 out[#out+1]="recent_events="
 local first=math.max(1,#(rows or {})-(limit or 40)+1)
 for index=first,#(rows or {}) do out[#out+1]=rows[index] end
 return table.concat(out,"\n").."\n"
end
return M
