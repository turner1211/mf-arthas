-- Persist only observations with authoritative quest-state progress.
local M={}
function M.quest_spell(id)
 return tonumber(id)~=358733 and tonumber(id)~=369536
end
function M.new(api)
 local self={rows={}};local path='sylvanas_auto_leveler/routes/manual_actions.lua'
 local function key(s)
  local index=s.objective_index or 'all'
  if s.objective_indices then local ids={};for _,id in ipairs(s.objective_indices) do ids[#ids+1]=tostring(id) end;table.sort(ids);index=table.concat(ids,',') end
  return api.context()..':'..tostring(s.quest_id)..':'..tostring(s.action or 'objective')..':'..tostring(index)
 end
 if api.read then local ok,t=pcall(api.read,path);if ok and type(t)=='string' and #t<200000 then
  for k,id,x,y,z,spell,item in t:gmatch('([^\n\t]+)\t(%d+)\t([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),?(%d*),?(%d*)') do
   self.rows[k]={id=tonumber(id),x=tonumber(x),y=tonumber(y),z=tonumber(z),spell_id=tonumber(spell) or 0,item_id=tonumber(item) or 0}
  end
 end end
 function self:begin(s,state) self.pending=s and s.quest_id and {step=s,state=state} or nil end
 function self:observe(state,contact)
  local p=self.pending;if not p or not contact then return false end
  local advanced=(state.accepted and not p.state.accepted) or (state.turned_in and not p.state.turned_in)
   or (type(state.progress)=='number' and type(p.state.progress)=='number' and state.progress>p.state.progress)
  if not advanced then return false end
  local row={id=contact.id or 0,x=contact.x,y=contact.y,z=contact.z,spell_id=contact.spell_id or 0,item_id=contact.item_id or 0}
  if not M.quest_spell(row.spell_id) then row.spell_id=0 end
  for _,k in ipairs({'x','y','z'}) do if type(row[k])~='number' or row[k]~=row[k] or math.abs(row[k])>100000 then return false end end
  self.rows[key(p.step)]=row
  local out={};for k,r in pairs(self.rows) do out[#out+1]=k..'\t'..r.id..'\t'..string.format('%.6f,%.6f,%.6f,%d,%d',r.x,r.y,r.z,r.spell_id or 0,r.item_id or 0) end
  table.sort(out);while #out>256 do table.remove(out,1) end
  local ok,result=pcall(api.write,path,table.concat(out,'\n'))
  if api.log then api.log(ok and result~=false and 'manual_action_auto_saved' or 'manual_action_save_failed',{quest_id=p.step.quest_id,npc_id=row.id,action=p.step.action}) end
  if ok and result~=false then p.state=state end
  return ok and result~=false
 end
 function self:succeeded(s) local row=self.rows[key(s)];if row then row.failures=nil end end
 function self:failed(s)
  local k=key(s);local row=self.rows[k];if not row then return false end
  row.failures=(row.failures or 0)+1;if row.failures<3 then return false end
  self.rows[k]=nil
  local out={};for id,r in pairs(self.rows) do out[#out+1]=id..'\t'..r.id..'\t'..string.format('%.6f,%.6f,%.6f,%d,%d',r.x,r.y,r.z,r.spell_id or 0,r.item_id or 0) end
  table.sort(out);local ok,result=pcall(api.write,path,table.concat(out,'\n'))
  if not ok or result==false then self.rows[k]=row;return false end
  return true
 end
 function self:lookup(s)
  local row=s.quest_id and self.rows[key(s)]
  if row and not M.quest_spell(row.spell_id) then row.spell_id=0 end
  return row
 end
 function self:finish() self.pending=nil end
 return self
end
return M
