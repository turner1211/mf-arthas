-- Bounded diagnostic export. Values are serialized as inert Lua literals.
local M={rows={},path="bloodcrypt_delver/run_report.lua",last_flush=0,session=0}
local function clean(v)
 if type(v)=="number" then if v==v and math.abs(v)<1000000000 then return v end;return nil end
 if type(v)=="boolean" then return v end
 if type(v)=="string" then return v:gsub("DVE%d?[%w|:_%-]+","[bridge-redacted]"):sub(1,240) end
 return tostring(v):sub(1,240)
end
local function literal(v) if type(v)=="string" then return string.format("%q",v) end;return tostring(v) end
function M.start(now,version)
 M.rows={};M.session=(M.session or 0)+1;M.record(now,"session",{version=version,session=M.session})
end
function M.record(now,kind,fields)
 local row={t=tonumber(now) or 0,kind=clean(kind) or "unknown"}
 for k,v in pairs(fields or {}) do if type(k)=="string" and k:match("^[%a_][%w_]*$") then row[k]=clean(v) end end
 if row.kind=="heartbeat" then
  local previous=M.rows[#M.rows]
  if previous and previous.kind=="heartbeat" and previous.state==row.state and previous.inside==row.inside and previous.dead==row.dead and previous.moving==row.moving and previous.combat==row.combat and previous.instance==row.instance and previous.scenario==row.scenario and previous.step==row.step and previous.current_stage==row.current_stage and previous.num_stages==row.num_stages and previous.active_tier==row.active_tier and previous.delve_difficulty==row.delve_difficulty and previous.reward_eligible==row.reward_eligible and previous.active_affixes==row.active_affixes and previous.scenario_spells==row.scenario_spells and previous.timed_criteria==row.timed_criteria and previous.wigs_event==row.wigs_event then
   row.repeats=(tonumber(previous.repeats) or 1)+1;M.rows[#M.rows]=row;return
  end
 end
 M.rows[#M.rows+1]=row;if #M.rows>400 then table.remove(M.rows,1) end
end
function M.encode()
 local out={"-- Bloodcrypt Delver diagnostic report; data only.","return {"}
 for _,row in ipairs(M.rows) do
  local keys={};for k in pairs(row) do keys[#keys+1]=k end;table.sort(keys)
  local parts={};for _,k in ipairs(keys) do if row[k]~=nil then parts[#parts+1]="["..string.format("%q",k).."]="..literal(row[k]) end end
  out[#out+1]=" {"..table.concat(parts,",").."},"
 end
 out[#out+1]="}";return table.concat(out,"\n")
end
function M.flush(now,force)
 now=tonumber(now) or 0;if not force and now-M.last_flush<15 then return true end;M.last_flush=now
 local ok,result=pcall(function()
  core.create_data_folder("bloodcrypt_delver");core.create_data_file(M.path)
  return core.write_data_file(M.path,M.encode())
 end)
 return ok and result~=false,ok and nil or tostring(result)
end
return M
