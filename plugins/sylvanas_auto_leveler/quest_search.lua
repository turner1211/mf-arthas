-- Search only locations supplied by the guide, with a pause between circuits.
local M={}
local spiral={{.15,0},{0,.15},{-.15,0},{0,-.15},{.3,.3},{-.3,.3},{-.3,-.3},{.3,-.3},{.6,0},{0,.6},{-.6,0},{0,-.6}}
local function clamp(value) return math.max(0.01,math.min(99.99,value)) end
function M.next(step,now)
 local points=step.checkpoints or {}
 if #points==0 then return nil end
 local state=step.search_state
 -- index records the last completed/attempted authored point. Start at zero
 -- so the first search leg uses the guide's primary anchor instead of
 -- silently skipping directly to its second coordinate.
 if not state then state={index=0,next_at=now+10};step.search_state=state end
 if state.pending or now<state.next_at then return nil end
 if #points==1 then
  local index=(state.micro_index or 0)%#spiral+1
  local offset=spiral[index];local base=points[1]
  return {x=clamp(base.x+offset[1]),y=clamp(base.y+offset[2])},index
 end
 local index=state.index%#points+1
 return points[index],index
end
function M.finish(step,index,ok,now)
 local state=step.search_state
 if not state then return end
 state.pending=nil
 if #(step.checkpoints or {})==1 then
  state.micro_index=index;state.next_at=now+(ok and 6 or 10);return
 end
 state.failures=state.failures or {}
 if ok then state.index=index;state.failures[index]=nil
 else
  state.failures[index]=(state.failures[index] or 0)+1
  -- One disconnected checkpoint must not prevent checking the others.
  if state.failures[index]>=2 then state.index=index;state.failures[index]=nil end
 end
 -- Pause for a full rescan only after completing the final authored point.
 -- Intermediate coordinates should advance promptly through the route.
 state.next_at=now+(ok and index==#(step.checkpoints or {}) and 60 or ok and 10 or 15)
end
function M.radius(step,signature,now)
 local scan=step.target_scan
 if not scan or scan.signature~=signature then
  scan={signature=signature,since=now};step.target_scan=scan
  step.search_state=nil;step.search_query=nil
 end
 return math.min(480,60*2^math.min(3,math.floor(math.max(0,now-scan.since)/30)))
end
function M.mode(step) return #(step.checkpoints or {})==1 and "local_spiral" or "authored_circuit" end
local function memory(step,signature)
 local state=step.target_memory
 if not state or state.signature~=signature then
  state={signature=signature,targets={}};step.target_memory=state
 end
 return state
end
function M.target_available(step,key,signature,now)
 local row=memory(step,signature).targets[tostring(key)]
 return not row or now>=(row.until_at or 0)
end
function M.target_attempt(step,key,signature,now,accepted)
 local state=memory(step,signature);key=tostring(key)
 local row=state.targets[key] or {attempts=0}
 row.attempts=row.attempts+1
 local cooldown
 if not accepted then cooldown=3
 elseif row.attempts==1 then cooldown=8
 elseif row.attempts==2 then cooldown=30
 else cooldown=120 end
 row.until_at=now+cooldown;state.targets[key]=row
 return cooldown,row.attempts
end
return M
