-- Mode names are stable integration keys; queue IDs are client-specific.
local M={labels={"Random Battleground","Brawl","Epic Battleground","Battleground Blitz"}}
local keys={"random","brawl","epic","blitz"}
-- Forever publicly documents battlemaster/entrance queues rather than the
-- modern Retail random/brawl/epic selector. Keep one configured queue surface
-- and describe it accurately; its ID comes from live data or user selection.
M.forever_labels={"Forever Battleground"}
M.tbc_labels={"TBC Battleground"}
local function is_forever(version)
 return tostring(version or ""):lower():find("forever",1,true)~=nil
end
local function is_tbc(version)
 local value=tostring(version or ""):lower():gsub("[^%w]+","_")
 return value=="tbc" or value:find("wow_tbc",1,true)~=nil
end
function M.resolve(index)
 if type(index)~="number" or index~=math.floor(index) or index<1 or index>#keys then index=1 end
 return {index=index,key=keys[index],label=M.labels[index]}
end
function M.for_client(version,index)
 if is_forever(version) then return {index=1,key="random",label=M.forever_labels[1]} end
 if is_tbc(version) then return {index=1,key="random",label=M.tbc_labels[1]} end
 return M.resolve(index)
end
function M.labels_for(version)
 if is_forever(version) then return M.forever_labels end
 if is_tbc(version) then return M.tbc_labels end
 return M.labels
end
return M
