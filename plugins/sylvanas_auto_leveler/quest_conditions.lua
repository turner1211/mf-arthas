-- WoW-Pro signed quest lists: & means all, ^ means any, negative IDs negate.
-- Mixed operators are not defined by the source's split semantics.
local M={}
function M.parse(expression)
 local value=tostring(expression or ""):gsub("%s","")
 if value=="" or value:find("[^%d&%^%-]") or (value:find("&",1,true) and value:find("^",1,true)) then return nil,"unsupported_quest_condition" end
 local mode=value:find("^",1,true) and "any" or "all"
 local separator=mode=="any" and "^" or "&"
 local ids={}
 for token in (value..separator):gmatch("(.-)["..(separator=="^" and "%^" or "&").."]") do
  if not token:match("^%-?%d+$") or tonumber(token)==0 then return nil,"unsupported_quest_condition" end
  ids[#ids+1]=tonumber(token)
 end
 if #ids==0 then return nil,"unsupported_quest_condition" end
 return {mode=mode,ids=ids}
end
function M.evaluate(expression,predicate)
 local condition,reason=M.parse(expression)
 if not condition then return nil,reason end
 local passed,unknown,failed=0,false,false;local missing={}
 for _,id in ipairs(condition.ids) do
  local value=predicate(math.abs(id))
  if value==nil then unknown=true
  else
   value=value==true
   if id<0 then value=not value end
   if value then passed=passed+1
   else failed=true;if id>0 then missing[#missing+1]=id end end
  end
 end
 if condition.mode=="any" and passed>0 then return true,nil,{} end
 if condition.mode=="all" and failed then return false,nil,missing end
 if unknown then return nil,"quest_condition_state_unavailable",missing end
 return passed==#condition.ids and condition.mode=="all",nil,missing
end
return M
