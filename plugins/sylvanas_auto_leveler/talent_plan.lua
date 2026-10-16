-- Original reader for Blizzard's documented version-2 trait bit stream.
local M={}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function stream(text)
 local bits={}
 for i=1,#text do
  local c=text:sub(i,i);local at=alphabet:find(c,1,true)
  if not at then return nil end
  local value=at-1
  for j=0,5 do bits[#bits+1]=math.floor(value/2^j)%2 end
 end
 local index=1
 local function read(n)
  if index+n-1>#bits then error("truncated_talent_string") end
  local value=0;for j=0,n-1 do value=value+bits[index+j]*2^j end;index=index+n;return value
 end
 return read,function() return #bits-index+1 end
end
function M.header(code)
 local read=stream(code);if not read then return nil,"invalid_talent_string" end
 local ok,value=pcall(function()
  local v,s=read(8),read(16);local hash={};for i=1,16 do hash[i]=read(8) end
  return {version=v,spec_id=s,hash=hash}
 end)
 return ok and value or nil,not ok and tostring(value) or nil
end
function M.decode(code,spec,nodes,info,options)
 options=options or {}
 local read,left=stream(code);if not read then return nil,"invalid_talent_string" end
 local ok,plan=pcall(function()
  if read(8)~=2 then error("unsupported_talent_version") end
  if read(16)~=spec then error("talent_spec_mismatch") end
  local hash_nonzero=false;for i=1,16 do if read(8)~=0 then hash_nonzero=true end end
  local selected={hash_unverified=hash_nonzero,skipped={}}
  for _,id in ipairs(nodes) do
   if read(1)==1 then
    if read(1)==1 then
     local partial=read(1)==1;local rank=partial and read(6) or nil
     local choice=read(1)==1;local entry_index=choice and read(2)+1 or nil
     local node=info(id)
     if not node then
      if options.tolerant then selected.skipped[#selected.skipped+1]={node_id=id,reason="unavailable"}
      else error("talent_selected_node_unavailable:"..id) end
     end
     local cap=node and node.max_ranks or 0
     local valid=node and choice==(node.node_type==2 or node.node_type==3)
     if node and not valid then
      if options.tolerant then selected.skipped[#selected.skipped+1]={node_id=id,reason="node_layout_mismatch"}
      else error("talent_node_layout_mismatch:"..id) end
     end
     rank=rank or cap
     if node and (rank<1 or rank>cap) then
      valid=false
      if options.tolerant then selected.skipped[#selected.skipped+1]={node_id=id,reason="rank_layout_mismatch"}
      else error("talent_rank_layout_mismatch:"..id) end
     end
     local entry=entry_index and node and (node.entry_ids or {})[entry_index]
     if node and entry_index and not entry then
      valid=false
      if options.tolerant then selected.skipped[#selected.skipped+1]={node_id=id,reason="choice_layout_mismatch"}
      else error("talent_choice_layout_mismatch:"..id) end
     end
     if node and valid then selected[#selected+1]={node_id=id,entry_id=entry,target_rank=rank} end
    end
   end
  end
  if left()>5 then error("talent_tree_size_mismatch") end
  while left()>0 do if read(1)~=0 then error("talent_trailing_data") end end
  if #selected==0 then error("empty_talent_plan") end
  return selected
 end)
 return ok and plan or nil,not ok and tostring(plan) or nil
end
return M
