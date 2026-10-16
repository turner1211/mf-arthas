-- Numeric WoW-Pro QO selectors are conjunctions, not whole-quest completion.
local M={}
function M.parse(expression)
 if not expression or expression=="" then return nil end
 local value=tostring(expression):gsub("%s","")
 if value=="" or value:sub(1,1)==";" or value:find(";;",1,true) or value:sub(-1)==";" then return nil,"objective_selector_mapping_required" end
 local indices,seen={rules={}},{}
 for token in value:gmatch("[^;]+") do
  local raw,operator,amount=token:match("^(%d+)([<=>]*)(%d*)$")
  local index=tonumber(raw)
  if not index or index<1 or index%1~=0 then return nil,"objective_selector_mapping_required" end
  if operator~="" then
   if not ({[">"]=true,[">="]=true,["<"]=true,["<="]=true,["="]=true})[operator] or amount=="" then return nil,"objective_selector_mapping_required" end
   operator=operator:gsub("=",operator=="=" and "=" or "")
   indices.rules[#indices.rules+1]={index=index,operator=operator,amount=tonumber(amount)}
  end
  if not seen[index] then indices[#indices+1]=index;seen[index]=true end
 end
 return indices
end
function M.includes(indices,index)
 if not indices then return true end
 for _,wanted in ipairs(indices) do if wanted==index then return true end end
 return false
end
function M.done(indices,count,read)
 if count<1 then return false end
 if indices then
  for _,index in ipairs(indices) do
   if index>count or index<1 then return false end
   local objective=read(index)
   if not objective then return false end
   local has_rule=false
   for _,rule in ipairs(indices.rules or {}) do
    if rule.index==index then
     has_rule=true
     local current=tonumber(objective.fulfilled)
      or tonumber(tostring(objective.description or ""):match("(%d+)%s*/%s*%d+"))
     if current==nil then return false end
     local passed=rule.operator==">" and current>=rule.amount or rule.operator=="<" and current<=rule.amount or rule.operator=="=" and current==rule.amount
     if not passed then return false end
    end
   end
   if not has_rule and objective.is_completed~=true then return false end
  end
  return #indices>0
 end
 for index=1,count do local objective=read(index);if not objective or objective.is_completed~=true then return false end end
 return true
end
return M
