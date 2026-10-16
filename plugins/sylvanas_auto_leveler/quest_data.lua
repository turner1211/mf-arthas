-- Guide intent is separate from observed quest credit.
local M={}
local function call(api,name,...)
 if type(api)~="table" or type(api[name])~="function" then return nil end
 local ok,value=pcall(api[name],...);return ok and value or nil
end
function M.status(api)
 return {loaded=call(api,"is_loaded")==true,ready=call(api,"is_ready")==true,active=call(api,"has_current_step")==true}
end
local function normalize(rows,rxp)
 if type(rows)~="table" or #rows==0 then return nil end
 local out={}
 for i,row in ipairs(rows)do
  if type(row)~="table" then return nil end
  out[i]={text=row.text or "",type=row.type or "",finished=row.finished==true,
   fulfilled=tonumber(rxp and row.num_fulfilled or row.fulfilled) or 0,
   required=tonumber(rxp and row.num_required or row.required) or 0}
 end
 return out
end
function M.objectives(quests,rxp,snapshot,id,now)
 if type(id)~="number" or id<=0 then return nil,"unknown" end
 local direct=normalize(call(quests,"get_quest_objectives",id))
 if direct then return direct,"blizzard_live" end
 if snapshot and snapshot.at and now>=snapshot.at and now-snapshot.at<=10 then
  local rows=snapshot.objectives and snapshot.objectives[id]
  local bridged=normalize(rows)
  if bridged then return bridged,"blizzard_companion" end
 end
 if call(rxp,"is_loaded")==true then
  local rows=normalize(call(rxp,"get_objectives",id),true)
  if rows then return rows,"restedxp_live" end
 end
 return nil,"unknown"
end
return M
