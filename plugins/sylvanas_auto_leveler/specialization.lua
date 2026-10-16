-- Normalize clients that expose a class-local specialization index through the
-- spell-book reader.  Runtime catalogs use global ChrSpecialization IDs.
local M={}
local ids={
 [1]={71,72,73},[2]={65,66,70},[3]={253,254,255},[4]={259,260,261},
 [5]={256,257,258},[6]={250,251,252},[7]={262,263,264},[8]={62,63,64},
 [9]={265,266,267},[10]={268,270,269},[11]={102,103,104,105},
 [12]={577,581,1480},[13]={1467,1468,1473},
}
function M.resolve(class_id,reported,index)
 reported=tonumber(reported) or 0
 if reported>=50 then return reported end
 index=tonumber(index) or reported
 local row=ids[tonumber(class_id)]
 return row and row[index] or reported
end
return M
