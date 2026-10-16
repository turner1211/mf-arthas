-- A checkpoint belongs to one character and one exact compiled guide sequence.
local M={}
function M.read(api,character)
 local path="sylvanas_auto_leveler/progress_"..tostring(character):gsub("[^%w_-]","_")..".txt"
 local ok,text=pcall(api.read,path);local rows={}
 if ok and type(text)=="string" then
  for id,stamp,index in text:gmatch("([^\t\r\n]+)\t(%d+)\t(%d+)") do rows[id]={stamp=stamp,index=tonumber(index)} end
  local active
  for id in text:gmatch("@active\t([^\r\n]+)") do active=id end
  return rows,active
 end
 return rows
end
local function signature(steps)
 local hash=0
 for _,s in ipairs(steps) do
  local text=table.concat({s.source_index or "",s.action or "",s.quest_id or "",s.taxi_destination or ""},":")
  for i=1,#text do hash=(hash*31+text:byte(i))%2147483647 end
 end
 return tostring(hash)
end
function M.new(api,character,profile)
 local key=tostring(character):gsub("[^%w_-]","_")
 local path="sylvanas_auto_leveler/progress_"..key..".txt"
 local sig=signature(profile.steps);local state={}
 local ok,text=pcall(api.read,path)
 if ok and type(text)=="string" then
  for id,stamp,index in text:gmatch("([^\t\r\n]+)\t(%d+)\t(%d+)") do state[id]={stamp=stamp,index=tonumber(index)} end
 end
 local self={}
 function self:load()
  local row=state[profile.id]
  if row and row.stamp==sig and row.index>=1 and row.index<=#profile.steps+1 then return row.index end
  return 1
 end
 function self:save(id,index)
  if id~=profile.id then return false end
  state[id]={stamp=sig,index=index}
  local rows={};for name,row in pairs(state) do rows[#rows+1]=name.."\t"..row.stamp.."\t"..row.index end
  table.sort(rows);rows[#rows+1]="@active\t"..id
  local success,result=pcall(api.write,path,table.concat(rows,"\n").."\n")
  return success and result~=false
 end
 return self
end
return M
