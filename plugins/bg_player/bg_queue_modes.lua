-- Mode names are stable integration keys; queue IDs are client-specific.
local M={labels={"Random Battleground","Brawl","Epic Battleground","Battleground Blitz"}}
local keys={"random","brawl","epic","blitz"}
M.forever_labels={"Random Battleground"}
local function is_forever(version)
 return tostring(version or ""):lower():find("forever",1,true)~=nil
end
function M.resolve(index)
 if type(index)~="number" or index~=math.floor(index) or index<1 or index>#keys then index=1 end
 return {index=index,key=keys[index],label=M.labels[index]}
end
function M.for_client(version,index)
 if is_forever(version) then return {index=1,key="random",label=M.forever_labels[1]} end
 return M.resolve(index)
end
function M.labels_for(version)
 return is_forever(version) and M.forever_labels or M.labels
end
return M
