local M={}
local function normalize(s)
 return (tostring(s or ""):lower():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$",""))
end
function M.find(destination,names)
 local wanted=normalize(destination);if wanted=="" then return nil,"missing_destination" end
 local exact,short={},{}
 for i,name in ipairs(names) do
  local n=normalize(name)
  if n==wanted then exact[#exact+1]=i
  elseif normalize(n:match("^([^,]+)"))==wanted then short[#short+1]=i end
 end
 local matches=#exact>0 and exact or short
 if #matches==1 then return matches[1] end
 return nil,#matches>1 and "ambiguous_destination" or "unmatched_destination"
end
return M
