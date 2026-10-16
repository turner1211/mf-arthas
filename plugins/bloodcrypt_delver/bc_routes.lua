-- Explicit world coordinates only. No guessed coordinates or executable imports.
local M={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1000000 end
function M.point(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) end
function M.validate(r)
 if type(r)~="table" or type(r.name)~="string" or #r.name>120 then return false,"Invalid route name" end
 if not finite(r.map) or r.map<1 or r.map%1~=0 or not finite(r.entrance_map) or r.entrance_map<1 or r.entrance_map%1~=0 or not M.point(r.entrance) then return false,"Map and entrance coordinates required" end
 if type(r.variant)~="string" or #r.variant<1 then return false,"Scenario variant required" end
 if #r.variant>120 or r.variant:find("[|\r\n]") or r.name:find("[|\r\n]") then return false,"Invalid route text" end
 if r.instance and (not finite(r.instance) or r.instance<=0 or r.instance%1~=0) then return false,"Invalid instance identity" end
 if r.scenario_id and (not finite(r.scenario_id) or r.scenario_id<=0 or r.scenario_id%1~=0) then return false,"Invalid scenario identity" end
 if type(r.steps)~="table" or #r.steps<1 or #r.steps>2000 then return false,"Route needs 1-2000 steps" end
 for _,s in ipairs(r.steps) do
  if type(s)~="table" or not M.point(s.position) then return false,"Invalid step coordinates" end
  if s.kind~="move" and s.kind~="interact" and s.kind~="kill" and s.kind~="wait" then return false,"Unknown step kind" end
  if (s.kind=="interact" or s.kind=="kill") and (not finite(s.object_id) or s.object_id<=0) then return false,"Object ID required" end
  if s.kind=="interact" and not s.event and s.confirm~="unusable" and s.confirm~="criterion" then return false,"Interaction confirmation required" end
  if s.kind=="interact" and (s.event=="SCENARIO_UPDATE" or s.event=="SCENARIO_CRITERIA_UPDATE") then return false,"Generic scenario changes do not prove this interaction" end
  if s.kind=="wait" and not s.event then return false,"Wait event required" end
  if s.confirm and s.confirm~="unusable" and s.confirm~="criterion" then return false,"Unknown confirmation mode" end
  if s.confirm=="criterion" and (not finite(s.stage_id) or s.stage_id<=0 or not finite(s.criterion_id) or s.criterion_id<=0 or not r.scenario_id) then return false,"Exact scenario, stage and criterion IDs required" end
  if s.event and (type(s.event)~="string" or not s.event:match("^[A-Z_]+$") or #s.event>80) then return false,"Invalid confirmation event" end
  if s.timeout and (not finite(s.timeout) or s.timeout<1 or s.timeout>900) then return false,"Invalid timeout" end
 end
 return true
end
-- Strict line format for data saved under scripts_data. Never load/execute Lua.
function M.encode(r)
 local function clean(s) return (tostring(s):gsub("[|\r\n]", " ")) end
 local p=r.entrance
 local rows={table.concat({"DVE3",clean(r.name),r.map,r.entrance_map,p.x,p.y,p.z,clean(r.variant),r.instance or 0,r.scenario_id or 0},"|")}
 for _,s in ipairs(r.steps) do local q=s.position;rows[#rows+1]=table.concat({s.kind,q.x,q.y,q.z,s.object_id or 0,clean(s.event or ""),s.timeout or 120,s.confirm or "",s.stage_id or 0,s.criterion_id or 0},"|") end
 return table.concat(rows,"\n")
end
function M.decode(text)
 if type(text)~="string" or #text>500000 then return nil,"Route file invalid" end
 local rows={};for line in text:gmatch("[^\r\n]+") do local f={};for v in (line.."|"):gmatch("(.-)|") do f[#f+1]=v end;rows[#rows+1]=f end
 local h=rows[1];if not h or not ((h[1]=="DVE1" and #h==8) or (h[1]=="DVE2" and #h==9) or (h[1]=="DVE3" and #h==10)) then return nil,"Invalid route header" end
 local r={name=h[2],map=tonumber(h[3]),entrance_map=tonumber(h[4]),entrance={x=tonumber(h[5]),y=tonumber(h[6]),z=tonumber(h[7])},variant=h[8],steps={}}
 if h[9] and tonumber(h[9]) and tonumber(h[9])>0 then r.instance=tonumber(h[9]) end
 if h[10] and tonumber(h[10]) and tonumber(h[10])>0 then r.scenario_id=tonumber(h[10]) end
 for i=2,#rows do local f=rows[i];if #f~=(h[1]=="DVE3" and 10 or h[1]=="DVE2" and 8 or 7) then return nil,"Invalid step row" end;r.steps[#r.steps+1]={kind=f[1],position={x=tonumber(f[2]),y=tonumber(f[3]),z=tonumber(f[4])},object_id=tonumber(f[5]),event=f[6]~="" and f[6] or nil,timeout=tonumber(f[7]),confirm=f[8]~="" and f[8] or nil,stage_id=tonumber(f[9]),criterion_id=tonumber(f[10])} end
 local ok,why=M.validate(r);if not ok then return nil,why end;return r
end
return M
